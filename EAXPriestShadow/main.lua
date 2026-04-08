-- EAX Port) | main.lua
-- Shadow DPS rotation with DoT maintenance (VT, SW:P, DP), Mind Blast CD, SW:Death execute.
-- Source: /rotation/source/aio/priest/shadow.lua

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local ooc_manager = require("../libraries/ooc_manager")

local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")
local dashboard_config = require("libraries/dashboard_config")

local mana_manager = require("../libraries/mana_manager")
local burst_manager = require("../libraries/burst_manager")
local trinket_manager = require("../libraries/trinket_manager")
local combat_forecast = require("../libraries/combat_forecast")
local force_commands = require("../libraries/force_commands")

local buff_manager = require("common/modules/buff_manager")
local spell_queue = require("common/modules/spell_queue")

-- Hot-path local caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

-- Runtime state
local runtime = {
    last_cast_time = 0,
    shadowfiend_last = 0,
    mode_cache = "solo",
    last_mode_check = 0,
    last_mode_log = nil,
    _initialized = false,
    -- Channel protection state
    channel_state = {
        is_channeling = false,
        channel_spell = nil,
        channel_start_time = 0,
        channel_duration = 0,
    },
}

-- ============================================================================

-- ============================================================================

local function init_()
    if runtime._initialized then return end
    
    -- Setup middleware (healthstones, potions, racials)
    middleware_manager.setup(menu, spells)
    
    -- Initialize force commands
    force_commands:init()
    
    -- Initialize dashboard
    dashboard.init(dashboard_config)
    local dashboard_enabled = true
    if menu.dashboard_enabled and menu.dashboard_enabled.get_state then
        dashboard_enabled = menu.dashboard_enabled:get_state()
    end
    dashboard.set_enabled(dashboard_enabled)
    dashboard.set_position(
        (menu.dashboard_x and menu.dashboard_x:get()) or 20,
        (menu.dashboard_y and menu.dashboard_y:get()) or 200
    )
    dashboard.set_scale((menu.dashboard_scale and menu.dashboard_scale:get()) or 1.0)
    dashboard.register_render_callback()
    
    runtime._initialized = true
    print("[EAX Shadow] integration initialized")
end

-- Resolved spell IDs
local resolved = {
    vampiric_touch = utils.resolve_spell_id(spells.VAMPIRIC_TOUCH),
    shadow_word_pain = utils.resolve_spell_id(spells.SHADOW_WORD_PAIN),
    mind_blast = utils.resolve_spell_id(spells.MIND_BLAST),
    mind_flay = utils.resolve_spell_id(spells.MIND_FLAY),
    shadow_word_death = utils.resolve_spell_id(spells.SHADOW_WORD_DEATH),
    vampiric_embrace = utils.resolve_spell_id(spells.VAMPIRIC_EMBRACE),
    shadowform = utils.resolve_spell_id(spells.SHADOWFORM),
    shadowfiend = utils.resolve_spell_id(spells.SHADOWFIEND),
    inner_focus = utils.resolve_spell_id(spells.INNER_FOCUS),
    power_word_shield = utils.resolve_spell_id(spells.POWER_WORD_SHIELD),
    inner_fire = utils.resolve_spell_id(spells.INNER_FIRE),
    fortitude = utils.resolve_spell_id(spells.POWER_WORD_FORTITUDE),
    divine_spirit = utils.resolve_spell_id(spells.DIVINE_SPIRIT),
    shadow_protection = utils.resolve_spell_id(spells.SHADOW_PROTECTION),
    fear_ward = utils.resolve_spell_id(spells.FEAR_WARD),
    fade = utils.resolve_spell_id(spells.FADE),
    dispel_magic = utils.resolve_spell_id(spells.DISPEL_MAGIC),
    devouring_plague = utils.resolve_spell_id(spells.DEVOURING_PLAGUE),
    starshards = utils.resolve_spell_id(spells.STARSHARDS),
    desperate_prayer = utils.resolve_spell_id(spells.DESPERATE_PRAYER),
    berserking = utils.resolve_spell_id(spells.BERSERKING),
    resurrection = utils.resolve_spell_id(spells.RESURRECTION),
    power_infusion = utils.resolve_spell_id(spells.POWER_INFUSION),
}

-- Helper functions
local function note_cast()
    runtime.last_cast_time = _core_time()
end

local function log_mode(mode)
    if menu and menu.debug and menu.debug:get_state() and runtime.last_mode_log ~= mode then
        utils.log_debug(menu, "Mode=" .. mode)
        runtime.last_mode_log = mode
    end
end

-- Check if Mind Blast is ready
local function is_mind_blast_ready()
    if not resolved.mind_blast then return false end
    return _get_spell_cd(resolved.mind_blast) == 0
end

-- Check if SW:Death is ready
local function is_sw_death_ready()
    if not resolved.shadow_word_death then return false end
    return _get_spell_cd(resolved.shadow_word_death) == 0
end

-- Check if Inner Focus is ready
local function is_inner_focus_ready()
    if not resolved.inner_focus then return false end
    return _get_spell_cd(resolved.inner_focus) == 0
end

-- ============================================================================
-- CHANNEL PROTECTION (Mind Flay anti-clipping)
-- ============================================================================

-- Start tracking a channel spell
local function start_channel(spell_name, duration)
    runtime.channel_state.is_channeling = true
    runtime.channel_state.channel_spell = spell_name
    runtime.channel_state.channel_start_time = _core_time()
    runtime.channel_state.channel_duration = duration or 3.0 -- Mind Flay = 3s
end

-- Stop tracking channel (called when channel ends or is interrupted)
local function stop_channel()
    runtime.channel_state.is_channeling = false
    runtime.channel_state.channel_spell = nil
    runtime.channel_state.channel_start_time = 0
    runtime.channel_state.channel_duration = 0
end

-- Get remaining channel time
local function get_channel_remaining()
    if not runtime.channel_state.is_channeling then return 0 end
    local elapsed = _core_time() - runtime.channel_state.channel_start_time
    return math.max(0, runtime.channel_state.channel_duration - elapsed)
end

-- Check if we should allow a new cast (don't clip channels)
-- emergency_only = true: only allow if target dying or emergency situation
local function should_allow_cast(emergency_only)
    if not runtime.channel_state.is_channeling then return true end
    
    local remaining = get_channel_remaining()
    if remaining <= 0 then
        stop_channel()
        return true
    end
    
    -- If not emergency, never clip a channel
    if not emergency_only then
        if menu.debug and menu.debug:get_state() then
            print(string.format("[Shadow] Channel active (%.1fs remaining), waiting...", remaining))
        end
        return false
    end
    
    -- Emergency mode: only clip if significant time remains (>0.5s left)
    -- This saves at least some ticks
    if remaining > 0.5 then
        if menu.debug and menu.debug:get_state() then
            print(string.format("[Shadow] Emergency clip (%.1fs remaining)", remaining))
        end
        return true
    end
    
    return false
end

-- Check if Mind Flay channel should continue (don't restart if already channeling)
local function should_cast_mind_flay()
    if not runtime.channel_state.is_channeling then return true end
    -- Already channeling Mind Flay - don't restart, let it complete
    if runtime.channel_state.channel_spell == "mind_flay" then
        return false
    end
    return true
end

-- Ensure Shadowform
local function ensure_shadowform(me)
    if not resolved.shadowform then return false end
    if not (menu.keep_shadowform and menu.keep_shadowform:get_state()) then return false end
    if utils.has_buff(me, spells.BUFF_SHADOWFORM) then return false end
    if me:is_mounted() then return false end
    
    if utils.cast_self(resolved.shadowform, me) then
        note_cast()
        utils.log_debug(menu, "Shadowform")
        return true
    end
    return false
end

-- Try Pre-Combat Pull (VT or MB)
local function try_precombat_pull(me, target)
    if not target or not target:is_valid() or target:is_dead() then return false end
    if me:is_in_combat() then return false end
    if not me:can_attack(target) then return false end
    if not utils.has_buff(me, spells.BUFF_SHADOWFORM) then return false end
    
    -- Check if VT already on target
    local vt_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_VAMPIRIC_TOUCH)
    if vt_remaining > 0 then return false end
    
    -- Prefer VT for pull
    if resolved.vampiric_touch then
        if utils.cast_target(resolved.vampiric_touch, me, target) then
            note_cast()
            utils.log_debug(menu, "Pull: Vampiric Touch")
            return true
        end
    end
    
    -- Fallback to Mind Blast
    if is_mind_blast_ready() then
        if utils.cast_target(resolved.mind_blast, me, target) then
            note_cast()
            utils.log_debug(menu, "Pull: Mind Blast")
            return true
        end
    end
    
    return false
end

-- Try Vampiric Embrace (maintain debuff on target)
local function try_vampiric_embrace(me, target)
    if not resolved.vampiric_embrace then return false end
    if not (menu.shadow_ve_maintain and menu.shadow_ve_maintain:get_state()) then return false end
    if not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- Don't apply on dying targets
    local ttd = utils.get_health_pct(target) * 100
    if ttd < 6 then return false end
    
    -- Check if VE already on target
    local ve_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_VAMPIRIC_EMBRACE)
    if ve_remaining >= 3000 then return false end
    
    if utils.cast_target(resolved.vampiric_embrace, me, target) then
        note_cast()
        utils.log_debug(menu, "Vampiric Embrace")
        return true
    end
    return false
end

-- Try Vampiric Touch (refresh when remaining <= ~1.5s cast time)
local function try_vampiric_touch(me, target)
    if not resolved.vampiric_touch then return false end
    if not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- Don't apply on dying targets
    local ttd = utils.get_health_pct(target) * 100
    if ttd < 5 then return false end
    
    local vt_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_VAMPIRIC_TOUCH)
    
    -- Refresh when: VT missing entirely OR (VT expiring AND MB on CD)
    if vt_remaining > 1800 then return false end -- Still plenty of time
    if vt_remaining > 0 and is_mind_blast_ready() then return false end -- Wait for MB if it's ready
    
    if utils.cast_target(resolved.vampiric_touch, me, target) then
        note_cast()
        utils.log_debug(menu, "Vampiric Touch (rem: " .. math.floor(vt_remaining / 1000) .. "s)")
        return true
    end
    return false
end

-- Try Shadow Word: Pain (reapply only when it falls off)
local function try_shadow_word_pain(me, target)
    if not resolved.shadow_word_pain then return false end
    if not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- Don't apply if already active
    if utils.has_debuff(target, spells.DEBUFF_SHADOW_WORD_PAIN) then return false end
    
    -- Don't apply on dying targets
    local ttd = utils.get_health_pct(target) * 100
    if ttd < 6 then return false end
    
    -- Only apply when MB on CD (don't waste GCD when MB is ready)
    if is_mind_blast_ready() then return false end
    
    if utils.cast_target(resolved.shadow_word_pain, me, target) then
        note_cast()
        utils.log_debug(menu, "Shadow Word: Pain")
        return true
    end
    return false
end

-- Try Devouring Plague (Undead racial)
local function try_devouring_plague(me, target)
    if not resolved.devouring_plague then return false end
    if not (menu.shadow_use_devouring_plague and menu.shadow_use_devouring_plague:get_state()) then return false end
    if not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- Don't waste 3min CD on dying targets
    local ttd = utils.get_health_pct(target) * 100
    if ttd < 8 then return false end
    
    -- Don't reapply if already active
    local dp_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_DEVOURING_PLAGUE)
    if dp_remaining > 3000 then return false end
    
    if utils.cast_target(resolved.devouring_plague, me, target) then
        note_cast()
        utils.log_debug(menu, "Devouring Plague")
        return true
    end
    return false
end

-- Try Starshards (Night Elf racial)
local function try_starshards(me, target)
    if not resolved.starshards then return false end
    if not (menu.shadow_use_starshards and menu.shadow_use_starshards:get_state()) then return false end
    if not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- Night Elf only (race ID 4)
    local race_ok = false
    if me.get_race then
        local ok, race = pcall(function() return me:get_race() end)
        if ok and race == 4 then race_ok = true end
    end
    if not race_ok then return false end
    
    -- Don't waste on dying targets
    local ttd = utils.get_health_pct(target) * 100
    if ttd < 6 then return false end
    
    if utils.cast_target(resolved.starshards, me, target) then
        note_cast()
        utils.log_debug(menu, "Starshards")
        return true
    end
    return false
end

-- Try Inner Focus (off-GCD, fire before Mind Blast)
local function try_inner_focus(me)
    if not resolved.inner_focus then return false end
    if not (menu.shadow_use_inner_focus and menu.shadow_use_inner_focus:get_state()) then return false end
    if not is_inner_focus_ready() then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_INNER_FOCUS) then return false end
    
    -- Only use if MB is also ready (pair them)
    if not is_mind_blast_ready() then return false end
    
    if utils.cast_self(resolved.inner_focus, me) then
        note_cast()
        utils.log_debug(menu, "Inner Focus")
        return true
    end
    return false
end

-- Try Mind Blast (on cooldown)
local function try_mind_blast(me, target)
    if not resolved.mind_blast then return false end
    if not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- CHANNEL PROTECTION: Check if we should clip current channel
    -- Mind Blast is high priority, so allow emergency clip
    if not should_allow_cast(true) then return false end
    
    if not is_mind_blast_ready() then return false end
    
    -- Stop any active channel before casting
    stop_channel()
    
    if utils.cast_target(resolved.mind_blast, me, target) then
        note_cast()
        utils.log_debug(menu, "Mind Blast")
        return true
    end
    return false
end

-- Try Shadow Word: Death (execute)
local function try_shadow_word_death(me, target)
    if not resolved.shadow_word_death then return false end
    if not (menu.shadow_use_swd and menu.shadow_use_swd:get_state()) then return false end
    if not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- CHANNEL PROTECTION: SW:Death is execute priority, allow emergency clip
    if not should_allow_cast(true) then return false end
    
    -- HP safety check
    local swd_hp_threshold = (menu.shadow_swd_hp and menu.shadow_swd_hp:get() or 40) / 100
    local my_hp = utils.get_health_pct(me)
    if my_hp < swd_hp_threshold then return false end
    
    if not is_sw_death_ready() then return false end
    
    -- Stop any active channel before casting
    stop_channel()
    
    if utils.cast_target(resolved.shadow_word_death, me, target) then
        note_cast()
        utils.log_debug(menu, "Shadow Word: Death (HP: " .. math.floor(my_hp * 100) .. "%)")
        return true
    end
    return false
end

-- Try Racial (Berserking)
local function try_racial(me)
    if not me:is_in_combat() then return false end
    if not (menu.use_racial and menu.use_racial:get_state()) then return false end
    
    -- TTD gating for major CDs
    local ttd = utils.get_time_to_die and utils.get_time_to_die(target)
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if ttd and ttd < min_ttd then return false end
    
    if resolved.berserking and _get_spell_cd(resolved.berserking) == 0 then
        if utils.cast_self(resolved.berserking, me) then
            note_cast()
            utils.log_debug(menu, "Berserking")
            return true
        end
    end
    
    return false
end

-- Try Power Infusion (burst CD)
local function try_power_infusion(me)
    if not resolved.power_infusion then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_POWER_INFUSION) then return false end
    
    if _get_spell_cd(resolved.power_infusion) == 0 then
        if utils.cast_self(resolved.power_infusion, me) then
            note_cast()
            utils.log_debug(menu, "Power Infusion")
            return true
        end
    end
    return false
end

-- Try AoE SW:P Spread
local function try_aoe_swp_spread(me, target)
    if not resolved.shadow_word_pain then return false end
    if not me:is_in_combat() then return false end
    
    local min_count = (menu.shadow_aoe_count and menu.shadow_aoe_count:get() or 4)
    local hostiles = utils.get_nearby_hostiles(me, 40, 10)
    if #hostiles < min_count then return false end
    
    -- Find a target without SW:P
    for _, hostile in ipairs(hostiles) do
        if hostile:is_valid() and not hostile:is_dead() and not utils.has_debuff(hostile, spells.DEBUFF_SHADOW_WORD_PAIN) then
            if utils.cast_target(resolved.shadow_word_pain, me, hostile) then
                note_cast()
                utils.log_debug(menu, "AoE SW:P")
                return true
            end
        end
    end
    return false
end

-- Try AoE VT Spread
local function try_aoe_vt_spread(me, target)
    if not resolved.vampiric_touch then return false end
    if not me:is_in_combat() then return false end
    
    local min_count = (menu.shadow_aoe_count and menu.shadow_aoe_count:get() or 4)
    local hostiles = utils.get_nearby_hostiles(me, 40, 10)
    if #hostiles < min_count then return false end
    
    -- Find a target without VT
    for _, hostile in ipairs(hostiles) do
        if hostile:is_valid() and not hostile:is_dead() then
            local vt_remaining = utils.get_debuff_remaining_ms(hostile, spells.DEBUFF_VAMPIRIC_TOUCH)
            if vt_remaining <= 0 then
                if utils.cast_target(resolved.vampiric_touch, me, hostile) then
                    note_cast()
                    utils.log_debug(menu, "AoE VT")
                    return true
                end
            end
        end
    end
    return false
end

-- Try Mind Flay (filler)
local function try_mind_flay(me, target)
    if not resolved.mind_flay then return false end
    if not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- CHANNEL PROTECTION: Don't cast if already channeling Mind Flay
    if not should_cast_mind_flay() then
        return false
    end
    
    -- Yield to LowManaMode: don't waste mana on MF when conserving
    local low_mana_threshold = (menu.shadow_low_mana_pct and menu.shadow_low_mana_pct:get() or 50) / 100
    local mana_pct = utils.get_mana_pct(me)
    
    local swp_active = utils.has_debuff(target, spells.DEBUFF_SHADOW_WORD_PAIN)
    local vt_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_VAMPIRIC_TOUCH)
    
    if mana_pct <= low_mana_threshold and swp_active and vt_remaining >= 1800 then
        return false
    end
    
    if utils.cast_target(resolved.mind_flay, me, target) then
        note_cast()
        -- Start tracking the channel
        start_channel("mind_flay", 3.0)
        utils.log_debug(menu, "Mind Flay")
        return true
    end
    return false
end

-- Try Low Mana PW:S (defensive when conserving)
local function try_low_mana_pws(me, target)
    if not resolved.power_word_shield then return false end
    if not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    local low_mana_threshold = (menu.shadow_low_mana_pct and menu.shadow_low_mana_pct:get() or 50) / 100
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct > low_mana_threshold then return false end
    
    -- Only activate if DoTs are already up
    local swp_active = utils.has_debuff(target, spells.DEBUFF_SHADOW_WORD_PAIN)
    local vt_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_VAMPIRIC_TOUCH)
    if not swp_active or vt_remaining < 1800 then return false end
    
    -- Check not already shielded or weakened
    if utils.has_buff(me, spells.BUFF_POWER_WORD_SHIELD) then return false end
    if utils.has_debuff(me, spells.DEBUFF_WEAKENED_SOUL) then return false end
    
    if utils.cast_self(resolved.power_word_shield, me) then
        note_cast()
        utils.log_debug(menu, "Low Mana: PW:S")
        return true
    end
    return false
end

-- Try Fade (threat reduction)
local function try_fade(me)
    if not resolved.fade then return false end
    if not (menu.use_fade and menu.use_fade:get_state()) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_FADE) then return false end
    
    local hp = utils.get_health_pct(me)
    if hp > 0.50 then return false end
    
    if utils.cast_self(resolved.fade, me) then
        note_cast()
        utils.log_debug(menu, "Fade")
        return true
    end
    return false
end

-- Try Shadowfiend (mana recovery)
local function try_shadowfiend(me, target)
    if not resolved.shadowfiend then return false end
    if not (menu.use_shadowfiend and menu.use_shadowfiend:get_state()) then return false end
    if not me:is_in_combat() then return false end
    
    -- TTD gating for major CDs
    local ttd = utils.get_time_to_die and utils.get_time_to_die(target)
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if ttd and ttd < min_ttd then return false end
    
    local threshold = (menu.shadowfiend_pct and menu.shadowfiend_pct:get() or 50) / 100
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct > threshold then return false end
    
    local now = _core_time()
    if runtime.shadowfiend_last and (now - runtime.shadowfiend_last) < 300 then return false end
    
    local target = me:get_target()
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    if utils.cast_target(resolved.shadowfiend, me, target) then
        runtime.shadowfiend_last = now
        note_cast()
        utils.log_debug(menu, "Shadowfiend (mana: " .. math.floor(mana_pct * 100) .. "%)")
        return true
    end
    return false
end

-- Try Desperate Prayer (emergency self-heal)
local function try_desperate_prayer(me)
    if not resolved.desperate_prayer then return false end
    if not me:is_in_combat() then return false end
    
    local hp = utils.get_health_pct(me)
    if hp > 0.30 then return false end
    
    if utils.cast_self(resolved.desperate_prayer, me) then
        note_cast()
        utils.log_debug(menu, "Desperate Prayer (" .. math.floor(hp * 100) .. "%)")
        return true
    end
    return false
end

-- Main rotation logic
local function on_update()
    -- Menu nil guard
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    
    local me = _get_local_player()
    if not me or not me:is_valid() or me:is_dead() then return end
    
    -- Crowd Control check - return early if stunned/silenced/feared etc.
    if utils.is_cced and utils.is_cced(me) then return end
    
    
    if not runtime._initialized then
        init_()
    end
    
    local mode = utils.get_effective_mode(menu, runtime)
    log_mode(mode)
    
    -- Execute middleware (healthstones, potions, racials)
    local target = me:get_target()
    local mw_result, mw_msg = middleware_manager.execute_middleware(nil, me, target)
    if mw_result then
        note_cast()
        utils.log_debug(menu, mw_msg or "Middleware executed")
        return
    end
    
    -- Mana recovery check
    if (menu.use_mana_manager and menu.use_mana_manager:get()) then
        local used_mana, mana_type = mana_manager.check_and_recover(me, menu, mana_manager.CLASS_RECOVERY.PRIEST)
    end
    
    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    if should_stop then
        if (menu.debug and menu.debug:get_state()) then
            print(string.format("[CC] Rotation paused: %s", cc_reason or "CC"))
        end
        return  -- Stop rotation while CC'd
    end
    
    -- OOC handling via shared ooc_manager
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {
            rez_spell_id = resolved.resurrection,
            group_buffs = {
                {
                    spell_id = resolved.inner_fire,
                    buff_ids = spells.BUFF_INNER_FIRE,
                    name = "Inner Fire",
                    toggle = menu.use_inner_fire
                },
                {
                    spell_id = resolved.fortitude,
                    buff_ids = spells.BUFF_FORTITUDE,
                    name = "Fortitude",
                    toggle = menu.use_power_word_fortitude
                },
                {
                    spell_id = resolved.divine_spirit,
                    buff_ids = spells.BUFF_DIVINE_SPIRIT,
                    name = "Divine Spirit",
                    toggle = menu.use_divine_spirit
                },
                {
                    spell_id = resolved.shadow_protection,
                    buff_ids = spells.BUFF_SHADOW_PROTECTION,
                    name = "Shadow Protection",
                    toggle = menu.use_shadow_protection
                },
                {
                    spell_id = resolved.fear_ward,
                    buff_ids = spells.BUFF_FEAR_WARD,
                    name = "Fear Ward",
                    toggle = menu.pvp_use_fear_ward
                },
            }
        })
    end
    
    -- Ensure Shadowform
    if ensure_shadowform(me) then return end
    
    -- Get target
    local target = me:get_target()
    
    -- Sample combat forecast for TTD tracking
    if combat_forecast and target and target:is_valid() then
        combat_forecast:sample(target)
    end
    
    -- Pre-combat pull
    if try_precombat_pull(me, target) then return end
    
    if not me:is_in_combat() then return end
    
    -- Emergency: Desperate Prayer
    if try_desperate_prayer(me) then return end
    
    -- Off-GCD: Inner Focus
    if try_inner_focus(me) then return end
    
    -- Cooldowns
    if try_racial(me) then return end
    
    -- Burst & Trinket Automation
    local ctx = utils.get_cached_combat_context and utils.get_cached_combat_context(me) or { combat_start_time = runtime.last_cast_time }
    local combat_time = _core_time() - (ctx.combat_start_time or _core_time())
    local is_burst_window = burst_manager.should_auto_burst(me, target, combat_time, menu)
    if is_burst_window then
        -- Shadow Priest burst: Power Infusion (if available), Trinkets
        if try_power_infusion(me) then return end
    end
    trinket_manager.check_trinkets_v2(me, target, is_burst_window, force_commands, combat_forecast, menu)
    
    -- Threat management
    if try_fade(me) then return end
    
    -- Mana recovery
    if try_shadowfiend(me, target) then return end
    
    if not target or not target:is_valid() or target:is_dead() then return end
    if not me:can_attack(target) then return end
    
    -- Vampiric Embrace maintenance
    if try_vampiric_embrace(me, target) then return end
    
    -- DoT maintenance (VT first, then SW:P)
    if try_vampiric_touch(me, target) then return end
    if try_shadow_word_pain(me, target) then return end
    
    -- Devouring Plague (Undead racial)
    if try_devouring_plague(me, target) then return end
    
    -- AoE multi-dotting
    if try_aoe_vt_spread(me, target) then return end
    if try_aoe_swp_spread(me, target) then return end
    
    -- Starshards (Night Elf racial)
    if try_starshards(me, target) then return end
    
    -- Execute: SW:Death
    if try_shadow_word_death(me, target) then return end
    
    -- Mind Blast on CD
    if try_mind_blast(me, target) then return end
    
    -- Mind Flay filler
    if try_mind_flay(me, target) then return end
    
    -- Low mana defensive
    if try_low_mana_pws(me, target) then return end
end

-- Register update callback
core.register_on_update_callback(on_update)

-- Menu rendering is now handled by simple_ui in libraries/menu.lua
-- The menu system registers its own render callbacks

-- Control panel integration with simple_ui menu
local control_panel_utility = require("common/utility/control_panel_helper")
local key_helper = require("common/utility/key_helper")

local function on_control_panel()
    local elements = {}
    local function add_toggle(label, item, uid)
        if not item then return end
        local current = item:get_state()
        local next_state = control_panel_utility:insert_key_checkbox_(elements, label, current, 0, false, uid)
        if next_state ~= current then
            item:set(next_state)
        end
    end

    -- NUMPAD MULTIPLY (106) is the default toggle key for simple_ui menu
    local toggle_key_code = 106
    local display_name = "[EAX] Enabled"
    if toggle_key_code ~= 7 then
        display_name = "[EAX] Enabled (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end

    add_toggle(display_name, menu.enabled, "eax_priestshadowenabled_cp")

    if menu and menu.enabled and menu.enabled:get_state() then
        add_toggle("[EAX Shadow] VE", menu.shadow_ve_maintain, "eax_shadow_ve_cp")
        add_toggle("[EAX Shadow] SW:D", menu.shadow_use_swd, "eax_shadow_swd_cp")
        add_toggle("[EAX Shadow] Inner Focus", menu.shadow_use_inner_focus, "eax_shadow_if_cp")
    end

    return elements
end

core.register_on_render_control_panel_callback(on_control_panel)

-- Export toggle settings for external access
local NS = _G.EAXPriestShadow and _G.EAXPriestShadow.NS or {}
_G.EAXPriestShadow = _G.EAXPriestShadow or {}
_G.EAXPriestShadow.NS = NS
NS.toggle_menu = menu.toggle_menu


