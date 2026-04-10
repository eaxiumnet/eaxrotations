-- EAXPriestSmite main.lua
-- Holy DPS rotation with Shadow Weaving/Misery utility via SW:P
-- Holy Fire weave optimization, Surge of Light proc handling

-- Load header first to check if we should load at all
local header = require("header")
if not header.load then
    return
end

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local buff_manager = require("common/modules/buff_manager")
local middleware_manager = require("libraries/middleware_manager")
local dashboard = require("libraries/dashboard")
local ooc_manager = require("libraries/ooc_manager")
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")

-- Hot-path API caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown

-- Constants
local SMITE_CAST_TIME = 2.0  -- Base cast time with Divine Fury
local HOLY_FIRE_CAST_TIME = 3.0
local SWP_MIN_TTD = 6.0      -- Minimum time-to-death to cast SW:P
local SWP_REFRESH_THRESHOLD = 3.0  -- Refresh SW:P when less than this remains
local HF_WEAVE_THRESHOLD_LOW = SMITE_CAST_TIME   -- Lower bound for weave window
local HF_WEAVE_THRESHOLD_HIGH = HOLY_FIRE_CAST_TIME  -- Upper bound for weave window
local SPELL_QUEUE_INTERVAL_S = 0.25

-- Runtime spell storage
local runtime = {
    smite_id = nil,
    holy_fire_id = nil,
    mind_blast_id = nil,
    shadow_word_pain_id = nil,
    shadow_word_death_id = nil,
    flash_heal_id = nil,
    renew_id = nil,
    inner_focus_id = nil,
    power_infusion_id = nil,
    shadowfiend_id = nil,
    power_word_shield_id = nil,
    binding_heal_id = nil,
    inner_fire_id = nil,
    fear_ward_id = nil,
    starshards_id = nil,
    fortitude_id = nil,
    divine_spirit_id = nil,
    resurrection_id = nil,
}

-- Spell specs for resolution at load
local RUNTIME_SPELL_SPECS = {
    { field = "smite_id", ranks = spells.SMITE },
    { field = "holy_fire_id", ranks = spells.HOLY_FIRE },
    { field = "mind_blast_id", ranks = spells.MIND_BLAST },
    { field = "shadow_word_pain_id", ranks = spells.SHADOW_WORD_PAIN },
    { field = "shadow_word_death_id", ranks = spells.SHADOW_WORD_DEATH },
    { field = "flash_heal_id", ranks = spells.FLASH_HEAL },
    { field = "renew_id", ranks = spells.RENEW },
    { field = "inner_focus_id", ranks = spells.INNER_FOCUS },
    { field = "power_infusion_id", ranks = spells.POWER_INFUSION },
    { field = "shadowfiend_id", ranks = spells.SHADOWFIEND },
    { field = "power_word_shield_id", ranks = spells.POWER_WORD_SHIELD },
    { field = "binding_heal_id", ranks = spells.BINDING_HEAL },
    { field = "inner_fire_id", ranks = spells.INNER_FIRE },
    { field = "fear_ward_id", ranks = spells.FEAR_WARD },
    { field = "starshards_id", ranks = spells.STARSHARDS },
    { field = "fortitude_id", ranks = spells.POWER_WORD_FORTITUDE },
    { field = "divine_spirit_id", ranks = spells.DIVINE_SPIRIT },
    { field = "shadow_protection_id", ranks = spells.SHADOW_PROTECTION },
    { field = "resurrection_id", ranks = spells.RESURRECTION },
}

-- Throttle tracking
local throttle_data = {}
local queue_request_timestamps = {}

-- Combat time tracking for burst manager
local combat_start_time = 0
local combat_time = 0

-- Resolve spells at load
local function resolve_spells()
    for i = 1, #RUNTIME_SPELL_SPECS do
        local spec = RUNTIME_SPELL_SPECS[i]
        runtime[spec.field] = utils.resolve_spell_id(spec.ranks)
    end
end

-- Throttle helper
local function throttle(key, interval)
    local now = _core_time()
    if not throttle_data[key] or (now - throttle_data[key]) >= interval then
        throttle_data[key] = now
        return true
    end
    return false
end

-- Queue request throttling
local function can_issue_queue_request(kind, spell_id, target, interval_s)
    local key = kind .. ":" .. tostring(spell_id) .. ":" .. tostring(target)
    local now = _core_time()
    local last = queue_request_timestamps[key] or 0
    if (now - last) < interval_s then return false end
    queue_request_timestamps[key] = now
    return true
end

-- Surge of Light detection (buff IDs: 33152, 33151, 33150)
local function has_surge_of_light(me)
    if not me or not me:is_valid() then return false end
    return utils.has_buff(me, spells.BUFF_SURGE_OF_LIGHT)
end

-- Get mana percentage
local function get_mana_pct(me)
    if not me or not me:is_valid() then return 0 end
    return utils.mana_pct(me)
end

-- Get target time-to-death estimate (simplified)
local function get_target_ttd(target)
    if not target or not target:is_valid() then return 999 end
    local ok_hp, hp = pcall(function() return target:get_health() end)
local ok_max, max_hp = pcall(function() return target:get_max_health() end)
local hp_pct = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
    -- Rough estimate: assume target dies when HP reaches 0
    -- In practice, this would need more sophisticated tracking
    return hp_pct > 0 and (hp_pct / 10) or 0  -- Rough 10% per second assumption
end

-- Check if we should be in healing mode
local function should_heal_mode(me)
    if not me or not me:is_valid() then return false end
    local ok_hp, hp = pcall(function() return me:get_health() end)
local ok_max, max_hp = pcall(function() return me:get_max_health() end)
local hp_pct = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
    local threshold = (menu.self_heal_threshold and menu.self_heal_threshold:get()) or 30
    local balance = (menu.dps_heal_balance and menu.dps_heal_balance:get()) or 80
    
    -- If balance is 0, full DPS mode (never heal)
    if balance <= 0 then return false end
    
    -- If balance is 100, full heal mode
    if balance >= 100 then return true end
    
    -- Otherwise, check if HP is below threshold
    return hp_pct < threshold
end

-- Get remaining duration of debuff on target
local function get_debuff_remaining(target, debuff_table)
    if not target or not target:is_valid() then return 0 end
    local data = buff_manager:get_debuff_data(target, debuff_table)
    if data and data.remaining then
        return data.remaining
    end
    return 0
end

-- Try cast with IZI SDK
local function try_cast_izi(spell_id, target, label)
    if not spell_id or not target then return false end
    if not can_issue_queue_request("spell", spell_id, target, SPELL_QUEUE_INTERVAL_S) then return false end
    
    local izi = require("common/izi_sdk")
    local izi_spell = izi.spell(spell_id)
    
    if izi_spell:is_learned() and izi_spell:is_castable_to_unit(target) then
        local ok, result = pcall(function()
            return izi_spell:cast_safe(target, label or "[Cast]")
        end)
        if ok and result then
            return true
        end
    end
    return false
end

-- Try Shadow Word: Pain (maintain for Shadow Weaving + Misery)
local function try_shadow_word_pain(me, target)
    local use_swp = (menu.use_shadow_word_pain and menu.use_shadow_word_pain:get_state()) or false
    if not use_swp then return false end
    if not runtime.shadow_word_pain_id then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end
    
    -- Check if debuff already active
    local remaining = get_debuff_remaining(target, spells.DEBUFF_SHADOW_WORD_PAIN)
    if remaining > SWP_REFRESH_THRESHOLD then return false end
    
    -- Check time-to-death (don't cast on dying targets)
    local ttd = get_target_ttd(target)
    if ttd < SWP_MIN_TTD then return false end
    
    -- Check if we can cast
    if not utils.can_cast_hostile(runtime.shadow_word_pain_id, me, target) then return false end
    
    if try_cast_izi(runtime.shadow_word_pain_id, target, "[Smite] SW:P") then
        utils.log_debug(menu, "Shadow Word: Pain")
        return true
    end
    return false
end

-- Try Holy Fire (with weave optimization)
local function try_holy_fire(me, target)
    local use_hf = (menu.use_holy_fire and menu.use_holy_fire:get_state()) or false
    if not use_hf then return false end
    if not runtime.holy_fire_id then return false end
    
    -- Check if debuff already active and has sufficient duration
    local remaining = get_debuff_remaining(target, spells.DEBUFF_HOLY_FIRE)
    if remaining > 1.0 then return false end  -- Don't clip existing DoT
    
    -- Check if we can cast
    if not utils.can_cast_hostile(runtime.holy_fire_id, me, target) then return false end
    
    -- Weave optimization: Check if we're in the weave window
    local swp_remaining = get_debuff_remaining(target, spells.DEBUFF_SHADOW_WORD_PAIN)
    local in_weave_window = swp_remaining > HF_WEAVE_THRESHOLD_LOW and swp_remaining < HF_WEAVE_THRESHOLD_HIGH
    
    if in_weave_window then
        if try_cast_izi(runtime.holy_fire_id, target, "[Smite] Holy Fire (Weave)") then
            utils.log_debug(menu, "Holy Fire (Weave)")
            return true
        end
    else
        -- Normal cast when off cooldown and no active debuff
        if remaining <= 0 then
            if try_cast_izi(runtime.holy_fire_id, target, "[Smite] Holy Fire") then
                utils.log_debug(menu, "Holy Fire")
                return true
            end
        end
    end
    return false
end

-- Try Smite (primary filler, instant with Surge of Light)
local function try_smite(me, target)
    local use_smite = (menu.use_smite and menu.use_smite:get_state()) or false
    if not use_smite then return false end
    if not runtime.smite_id then return false end
    
    -- Check if we can cast
    if not utils.can_cast_hostile(runtime.smite_id, me, target) then return false end
    
    local has_surge = has_surge_of_light(me)
    local label = has_surge and "[Smite] Smite (Surge of Light)" or "[Smite] Smite"
    
    if try_cast_izi(runtime.smite_id, target, label) then
        utils.log_debug(menu, has_surge and "Smite (Surge of Light - Instant)" or "Smite")
        return true
    end
    return false
end

-- Try Mind Blast (if Shadow hybrid enabled)
local function try_mind_blast(me, target)
    local use_mb = (menu.use_mind_blast and menu.use_mind_blast:get_state()) or false
    if not use_mb then return false end
    if not runtime.mind_blast_id then return false end
    
    -- Check if we can cast
    if not utils.can_cast_hostile(runtime.mind_blast_id, me, target) then return false end
    
    if try_cast_izi(runtime.mind_blast_id, target, "[Smite] Mind Blast") then
        utils.log_debug(menu, "Mind Blast")
        return true
    end
    return false
end

-- Try Shadow Word: Death (execute, HP check)
local function try_shadow_word_death(me, target)
    local use_swd = (menu.use_shadow_word_death and menu.use_shadow_word_death:get_state()) or false
    if not use_swd then return false end
    if not runtime.shadow_word_death_id then return false end
    
    -- Check target HP threshold
    local threshold = (menu.swd_hp_threshold and menu.swd_hp_threshold:get()) or 40
    local ok_hp2, hp2 = pcall(function() return target:get_health() end)
local ok_max2, max_hp2 = pcall(function() return target:get_max_health() end)
local target_hp = (ok_hp2 and ok_max2 and hp2 and max_hp2 and max_hp2 > 0) and ((hp2 / max_hp2) * 100) or 100
    if target_hp > threshold then return false end
    
    -- Check if we can cast
    if not utils.can_cast_hostile(runtime.shadow_word_death_id, me, target) then return false end
    
    if try_cast_izi(runtime.shadow_word_death_id, target, "[Smite] SW:D") then
        utils.log_debug(menu, "Shadow Word: Death (Execute)")
        return true
    end
    return false
end

-- Try Starshards (Night Elf racial)
local function try_starshards(me, target)
    local use_starshards = (menu.use_starshards and menu.use_starshards:get_state()) or false
    if not use_starshards then return false end
    if not runtime.starshards_id then return false end
    
    -- Check if we can cast
    if not utils.can_cast_hostile(runtime.starshards_id, me, target) then return false end
    
    if try_cast_izi(runtime.starshards_id, target, "[Smite] Starshards") then
        utils.log_debug(menu, "Starshards")
        return true
    end
    return false
end

-- Try Inner Focus (off-GCD, pair with big spells)
local function try_inner_focus(me, target)
    local use_if = (menu.use_inner_focus and menu.use_inner_focus:get_state()) or false
    if not use_if then return false end
    if not runtime.inner_focus_id then return false end

    -- Check if already active
    if utils.has_buff(me, spells.BUFF_INNER_FOCUS) then return false end

    -- Check cooldown
    if core.spell_book.get_spell_cooldown(runtime.inner_focus_id) > 0 then return false end

    -- Check auto-burst settings
    local auto_burst = (menu.auto_burst_enabled and menu.auto_burst_enabled:get_state()) or false
    if auto_burst then
        local should_burst, _ = burst_manager.should_auto_burst(me, target, combat_time, menu)
        if not should_burst then return false end
    else
        -- Manual mode: TTD gating for burst CDs
        local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
        if min_ttd > 0 and target then
            ---@type combat_forecast
            local forecast = require("libraries/combat_forecast")
            if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
                return false
            end
        end
    end

    -- Only use if we have a big spell coming up (Holy Fire or Mind Blast)
    local hf_cd = runtime.holy_fire_id and core.spell_book.get_spell_cooldown(runtime.holy_fire_id) or math.huge
    local mb_cd = runtime.mind_blast_id and core.spell_book.get_spell_cooldown(runtime.mind_blast_id) or math.huge

    if hf_cd > 2 and mb_cd > 2 then return false end  -- No big spell ready soon

    if utils.can_cast_self(runtime.inner_focus_id, me) then
        if try_cast_izi(runtime.inner_focus_id, me, "[Smite] Inner Focus") then
            utils.log_debug(menu, "Inner Focus")
            return true
        end
    end
    return false
end

-- Try Power Infusion (offensive CD)
local function try_power_infusion(me, target)
    local use_pi = (menu.use_power_infusion and menu.use_power_infusion:get_state()) or false
    if not use_pi then return false end
    if not runtime.power_infusion_id then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end

    -- Check if already active
    if utils.has_buff(me, spells.BUFF_POWER_INFUSION) then return false end

    -- Check cooldown
    if core.spell_book.get_spell_cooldown(runtime.power_infusion_id) > 0 then return false end

    -- Check auto-burst settings
    local auto_burst = (menu.auto_burst_enabled and menu.auto_burst_enabled:get_state()) or false
    if auto_burst then
        local should_burst, _ = burst_manager.should_auto_burst(me, target, combat_time, menu)
        if not should_burst then return false end
    else
        -- Manual mode: TTD gating for burst CDs
        local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
        if min_ttd > 0 and target then
            ---@type combat_forecast
            local forecast = require("libraries/combat_forecast")
            if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
                return false
            end
        end
    end

    if utils.can_cast_self(runtime.power_infusion_id, me) then
        if try_cast_izi(runtime.power_infusion_id, me, "[Smite] Power Infusion") then
            utils.log_debug(menu, "Power Infusion")
            return true
        end
    end
    return false
end

-- Try Shadowfiend (mana recovery)
local function try_shadowfiend(me, target)
    local use_sf = (menu.use_shadowfiend and menu.use_shadowfiend:get_state()) or false
    if not use_sf then return false end
    if not runtime.shadowfiend_id then return false end
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then return false end
    
    -- Check mana threshold
    local mana_pct = get_mana_pct(me)
    if mana_pct > 30 then return false end  -- Only use when mana is low
    
    -- Check cooldown
    if core.spell_book.get_spell_cooldown(runtime.shadowfiend_id) > 0 then return false end
    
    if utils.can_cast_hostile(runtime.shadowfiend_id, me, target) then
        if try_cast_izi(runtime.shadowfiend_id, target, "[Smite] Shadowfiend") then
            utils.log_debug(menu, "Shadowfiend")
            return true
        end
    end
    return false
end

-- Try Flash Heal (emergency self-heal)
local function try_flash_heal(me)
    local use_fh = (menu.use_flash_heal and menu.use_flash_heal:get_state()) or false
    if not use_fh then return false end
    if not runtime.flash_heal_id then return false end
    
    -- Check if we actually need healing
    local ok_hp, hp = pcall(function() return me:get_health() end)
local ok_max, max_hp = pcall(function() return me:get_max_health() end)
local hp_pct = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
    local threshold = (menu.self_heal_threshold and menu.self_heal_threshold:get()) or 30
    if hp_pct >= threshold then return false end
    
    if utils.can_cast_self(runtime.flash_heal_id, me) then
        if try_cast_izi(runtime.flash_heal_id, me, "[Smite] Flash Heal") then
            utils.log_debug(menu, "Flash Heal (Self)")
            return true
        end
    end
    return false
end

-- Try Renew (sustained self-heal)
local function try_renew(me)
    local use_renew = (menu.use_renew and menu.use_renew:get_state()) or false
    if not use_renew then return false end
    if not runtime.renew_id then return false end
    
    -- Check if already has Renew
    if utils.has_buff(me, spells.BUFF_RENEW) then return false end
    
    -- Check if we need healing
    local ok_hp, hp = pcall(function() return me:get_health() end)
local ok_max, max_hp = pcall(function() return me:get_max_health() end)
local hp_pct = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
    local threshold = (menu.self_heal_threshold and menu.self_heal_threshold:get()) or 30
    if hp_pct >= threshold + 10 then return false end  -- Slightly higher threshold for HoT
    
    if utils.can_cast_self(runtime.renew_id, me) then
        if try_cast_izi(runtime.renew_id, me, "[Smite] Renew") then
            utils.log_debug(menu, "Renew (Self)")
            return true
        end
    end
    return false
end

-- Try Power Word: Shield (defensive)
local function try_power_word_shield(me)
    local use_pws = (menu.use_power_word_shield and menu.use_power_word_shield:get_state()) or false
    if not use_pws then return false end
    if not runtime.power_word_shield_id then return false end
    
    -- Check if already has shield or Weakened Soul
    if utils.has_buff(me, spells.BUFF_POWER_WORD_SHIELD) then return false end
    if utils.has_debuff(me, spells.DEBUFF_WEAKENED_SOUL) then return false end
    
    -- Check if we need shield (low HP or in combat)
    local ok_hp, hp = pcall(function() return me:get_health() end)
local ok_max, max_hp = pcall(function() return me:get_max_health() end)
local hp_pct = (ok_hp and ok_max and hp and max_hp and max_hp > 0) and ((hp / max_hp) * 100) or 100
    if hp_pct > 50 and not me:is_in_combat() then return false end
    
    if utils.can_cast_self(runtime.power_word_shield_id, me) then
        if try_cast_izi(runtime.power_word_shield_id, me, "[Smite] PW:S") then
            utils.log_debug(menu, "Power Word: Shield (Self)")
            return true
        end
    end
    return false
end

-- Try Inner Fire (buff maintenance)
local function try_inner_fire(me)
    local use_if = (menu.use_inner_fire and menu.use_inner_fire:get_state()) or false
    if not use_if then return false end
    if not runtime.inner_fire_id then return false end
    
    -- Check if already has buff
    if utils.has_buff(me, spells.BUFF_INNER_FIRE) then return false end
    
    if utils.can_cast_self(runtime.inner_fire_id, me) then
        if try_cast_izi(runtime.inner_fire_id, me, "[Smite] Inner Fire") then
            utils.log_debug(menu, "Inner Fire")
            return true
        end
    end
    return false
end

-- Try Fear Ward (buff maintenance)
local function try_fear_ward(me)
    local use_fw = (menu.use_fear_ward and menu.use_fear_ward:get_state()) or false
    if not use_fw then return false end
    if not runtime.fear_ward_id then return false end
    
    -- Check if already has buff
    if utils.has_buff(me, spells.BUFF_FEAR_WARD) then return false end
    
    if utils.can_cast_self(runtime.fear_ward_id, me) then
        if try_cast_izi(runtime.fear_ward_id, me, "[Smite] Fear Ward") then
            utils.log_debug(menu, "Fear Ward")
            return true
        end
    end
    return false
end

-- Find best target for DPS
local function find_best_target(me)
    -- Check focus first if enabled
    local use_focus = (menu.focus_priority and menu.focus_priority:get_state()) or false
    if use_focus then
        local focus = nil
        if core.input and core.input.get_focus then
            focus = core.input.get_focus()
        end
        if focus and focus:is_valid() and not focus:is_dead() and me:can_attack(focus) then
            return focus
        end
    end
    
    -- Check current target
    local ok, target = pcall(function() return me:get_target() end)
    if not ok or not target then return nil end
    if target and target:is_valid() and not target:is_dead() and me:can_attack(target) then
        return target
    end
    
    return nil
end

-- Main rotation update function
local function on_update()
    -- Check if enabled
    local enabled = (menu.enabled and menu.enabled:get_state()) or false
    if not enabled then return end
    
    -- Get player
    local me = _get_local_player()
    if not me or not me:is_valid() then return end
    
    -- Crowd Control check - return early if stunned/silenced/feared etc.
    if utils.is_cced and utils.is_cced(me) then return end
    
    -- Resolve spells (in case talents changed)
    resolve_spells()
    
    -- Initialize middleware on first run
    if not middleware_manager.is_initialized() then
        middleware_manager.initialize(menu)
    end
    
    -- Sync dashboard settings
    local ok_show, show_dashboard = pcall(function() return menu.show_dashboard:get_state() end)
    if ok_show then
        dashboard.set_enabled(show_dashboard)
    end
    
    local ok_opacity, opacity = pcall(function() return menu.dashboard_opacity:get() end)
    if ok_opacity then
        dashboard.set_opacity(opacity)
    end
    
    local ok_scale, scale = pcall(function() return menu.dashboard_scale:get() end)
    if ok_scale then
        dashboard.set_scale(scale)
    end
    
    local ok_x, pos_x = pcall(function() return menu.dashboard_x:get() end)
    local ok_y, pos_y = pcall(function() return menu.dashboard_y:get() end)
    if ok_x and ok_y then
        dashboard.set_position(pos_x, pos_y)
    end
    
    -- Get target
    local target = find_best_target(me)
    
    -- Build middleware context
    local settings = {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get_state()) or false,
        use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get_state()) or false,
        use_racial = (menu.use_racial and menu.use_racial:get_state()) or false,
    }
    local ctx = middleware_manager.build_context(me, target, settings)
    
    -- Execute middleware (healthstones, potions, racials)
    local mw_result, mw_msg = middleware_manager.execute(nil, ctx)
    if mw_result then
        return
    end
    
    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    if should_stop then
        return  -- Stop rotation while CC'd
    end

    -- Combat time tracking for burst manager
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and is_combat then
        if combat_start_time == 0 then
            combat_start_time = _core_time()
        end
        combat_time = _core_time() - combat_start_time
    else
        combat_start_time = 0
        combat_time = 0
    end

    -- Sample combat forecast for TTD tracking
    if combat_forecast and target and target:is_valid() then
        combat_forecast:sample(target)
    end

    -- Burst and Trinket management
    if me:is_in_combat() and target then
        local should_burst, burst_reason = burst_manager.should_auto_burst(me, target, combat_time, menu)
        trinket_manager.check_trinkets_v2(me, target, should_burst, force_commands, combat_forecast, menu)
    end

    -- Out of Combat management (buffs + resurrection)
    local ok_combat, is_combat = pcall(function() return me:is_in_combat() end)
    if ok_combat and not is_combat then
        local resolved = {
            inner_fire = runtime.inner_fire_id,
            fortitude = runtime.fortitude_id,
            divine_spirit = runtime.divine_spirit_id,
            shadow_protection = runtime.shadow_protection_id,
            fear_ward = runtime.fear_ward_id,
            resurrection = runtime.resurrection_id,
        }
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
                    toggle = menu.use_fortitude
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
                    toggle = menu.use_fear_ward
                },
            }
        })
        return  -- Exit after OOC buffs to prevent combat rotation
    end
    
    -- Buff maintenance (out of combat or in combat)
    if try_inner_fire(me) then return end
    if try_fear_ward(me) then return end
    
    -- If no valid target, skip DPS rotation
    if not target then return end
    
    -- Check if we should be in healing mode
    local heal_mode = should_heal_mode(me)
    
    if heal_mode then
        -- Healing priority
        if try_power_word_shield(me) then return end
        if try_renew(me) then return end
        if try_flash_heal(me) then return end
    else
        -- DPS Rotation Priority:
        -- 1. Shadow Word: Pain (maintain)
        -- 2. Holy Fire (maintain DoT, weave optimization)
        -- 3. Surge of Light Smite (instant proc)
        -- 4. Mind Blast (if enabled)
        -- 5. Shadow Word: Death (execute)
        -- 6. Starshards (racial)
        -- 7. Smite (filler)
        
        -- Off-GCD cooldowns first
        if try_inner_focus(me, target) then return end
        if try_power_infusion(me, target) then return end
        
        -- Mana recovery
        if try_shadowfiend(me, target) then return end
        
        -- Main rotation
        if try_shadow_word_pain(me, target) then return end
        if try_holy_fire(me, target) then return end
        
        -- Surge of Light proc (instant Smite)
        if has_surge_of_light(me) then
            if try_smite(me, target) then return end
        end
        
        if try_mind_blast(me, target) then return end
        if try_shadow_word_death(me, target) then return end
        if try_starshards(me, target) then return end
        if try_smite(me, target) then return end
    end
end

-- Control panel callback
local function on_control_panel()
    local elements = {}
    local toggle_key_code = (menu.toggle_key and menu.toggle_key:get_key_code()) or 7
    local display_name = "[EAX] Priest Smite"
    
    table.insert(elements, {
        type = "checkbox",
        id = "enabled",
        label = display_name,
        value = (menu.enabled and menu.enabled:get_state()) or false,
        on_change = function(new_val) if menu.enabled then menu.enabled:set(new_val) end end,
    })
    table.insert(elements, {
        type = "keybind",
        id = "toggle_key",
        label = "Toggle Key",
        value = toggle_key_code,
        on_change = function(new_val) if menu.toggle_key then menu.toggle_key:set_key_code(new_val) end end,
    })
    return elements
end

-- Initialize
resolve_spells()
force_commands:init()

-- Register callbacks
core.register_on_update_callback(on_update)
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)

-- Initialize dashboard
local dashboard_config = require("libraries/dashboard_config")
dashboard.init(dashboard_config)
dashboard.set_enabled((menu.show_dashboard and menu.show_dashboard:get_state()) or true)
dashboard.register_render_callback()

-- Export toggle settings for external access
if header.load then
    local NS = _G.EAXPriestSmite and _G.EAXPriestSmite.NS or {}
    _G.EAXPriestSmite = _G.EAXPriestSmite or {}
    _G.EAXPriestSmite.NS = NS
    NS.toggle_menu = menu.toggle_menu
end
