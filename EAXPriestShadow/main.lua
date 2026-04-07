require("libraries/path_bootstrap")
-- EAX Port) | main.lua
-- Shadow DPS rotation with DoT maintenance (VT, SW:P, DP), Mind Blast CD, SW:Death execute.
-- Source: /rotation/source/aio/priest/shadow.lua

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

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
}

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
    fear_ward = utils.resolve_spell_id(spells.FEAR_WARD),
    fade = utils.resolve_spell_id(spells.FADE),
    dispel_magic = utils.resolve_spell_id(spells.DISPEL_MAGIC),
    devouring_plague = utils.resolve_spell_id(spells.DEVOURING_PLAGUE),
    starshards = utils.resolve_spell_id(spells.STARSHARDS),
    desperate_prayer = utils.resolve_spell_id(spells.DESPERATE_PRAYER),
    berserking = utils.resolve_spell_id(spells.BERSERKING),
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
    
    if not is_mind_blast_ready() then return false end
    
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
    
    -- HP safety check
    local swd_hp_threshold = (menu.shadow_swd_hp and menu.shadow_swd_hp:get() or 40) / 100
    local my_hp = utils.get_health_pct(me)
    if my_hp < swd_hp_threshold then return false end
    
    if not is_sw_death_ready() then return false end
    
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
    
    if resolved.berserking and _get_spell_cd(resolved.berserking) == 0 then
        if utils.cast_self(resolved.berserking, me) then
            note_cast()
            utils.log_debug(menu, "Berserking")
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
local function try_shadowfiend(me)
    if not resolved.shadowfiend then return false end
    if not (menu.use_shadowfiend and menu.use_shadowfiend:get_state()) then return false end
    if not me:is_in_combat() then return false end
    
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

-- Try Inner Fire (self-buff)
local function try_inner_fire(me)
    if not resolved.inner_fire then return false end
    if not (menu.use_inner_fire and menu.use_inner_fire:get_state()) then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_INNER_FIRE) then return false end
    
    if utils.cast_self(resolved.inner_fire, me) then
        note_cast()
        utils.log_debug(menu, "Inner Fire")
        return true
    end
    return false
end

-- Try Fear Ward (pre-pull buff)
local function try_fear_ward(me)
    if not resolved.fear_ward then return false end
    if not (menu.use_fear_ward and menu.use_fear_ward:get_state()) then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_FEAR_WARD) then return false end
    
    if utils.cast_self(resolved.fear_ward, me) then
        note_cast()
        utils.log_debug(menu, "Fear Ward (self)")
        return true
    end
    return false
end

-- Try Fortitude buff
local function try_fortitude(me)
    if not resolved.fortitude then return false end
    if not (menu.use_fortitude and menu.use_fortitude:get_state()) then return false end
    if me:is_in_combat() then return false end
    -- Skip if already has fortitude buff
    if utils.has_buff(me, spells.BUFF_POWER_WORD_FORT) then return false end
    
    if utils.cast_self(resolved.fortitude, me) then
        note_cast()
        utils.log_debug(menu, "Power Word: Fortitude")
        return true
    end
    return false
end

-- Try Divine Spirit buff
local function try_divine_spirit(me)
    if not resolved.divine_spirit then return false end
    if not (menu.use_divine_spirit and menu.use_divine_spirit:get_state()) then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_DIVINE_SPIRIT) then return false end
    
    if utils.cast_self(resolved.divine_spirit, me) then
        note_cast()
        utils.log_debug(menu, "Divine Spirit")
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
    
    local mode = utils.get_effective_mode(menu, runtime)
    log_mode(mode)
    
    -- OOC buffs
    if not me:is_in_combat() then
        if try_inner_fire(me) then return end
        if try_fear_ward(me) then return end
        if try_fortitude(me) then return end
        if try_divine_spirit(me) then return end
    end
    
    -- Ensure Shadowform
    if ensure_shadowform(me) then return end
    
    -- Get target
    local target = me:get_target()
    
    -- Pre-combat pull
    if try_precombat_pull(me, target) then return end
    
    if not me:is_in_combat() then return end
    
    -- Emergency: Desperate Prayer
    if try_desperate_prayer(me) then return end
    
    -- Off-GCD: Inner Focus
    if try_inner_focus(me) then return end
    
    -- Cooldowns
    if try_racial(me) then return end
    
    -- Threat management
    if try_fade(me) then return end
    
    -- Mana recovery
    if try_shadowfiend(me) then return end
    
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


