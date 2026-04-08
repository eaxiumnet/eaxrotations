-- EAX Rogue Subtlety | main.lua | Project Sylvanas
-- Subtlety rotation: Backstab/Hemorrhage builder, maintain Slice and Dice, Shadowstep burst

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local dashboard = require("libraries/dashboard")
local dashboard_config = require("libraries/dashboard_config")
local ooc_manager = require("../libraries/ooc_manager")
local anti_fake_manager = require("libraries/anti_fake_manager")
local burst_manager = require("libraries/burst_manager")
local trinket_manager = require("libraries/trinket_manager")

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

-- Flux libraries integration
local energy_tick = require("libraries/energy_tick")
local combat_forecast = require("libraries/combat_forecast")
local force_commands = require("libraries/force_commands")
local swing_manager = require("libraries/swing_manager")

-- Runtime spell cache
local runtime = {
    backstab_id = nil,
    hemorrhage_id = nil,
    sinister_strike_id = nil,
    ghostly_strike_id = nil,
    slice_and_dice_id = nil,
    rupture_id = nil,
    eviscerate_id = nil,
    expose_armor_id = nil,
    kidney_shot_id = nil,
    cheap_shot_id = nil,
    ambush_id = nil,
    garrote_id = nil,
    gouge_id = nil,
    kick_id = nil,
    shadowstep_id = nil,
    premeditation_id = nil,
    vanish_id = nil,
    evasion_id = nil,
    cloak_of_shadows_id = nil,
    blind_id = nil,
    cold_blood_id = nil,
    preparation_id = nil,
    sap_id = nil,
    feint_id = nil,
    stealth_id = nil,
    combo_points = 0,
    energy = 0,
    combat_start_time = 0,
}

-- Resolve spell IDs on load
local function resolve_spells()
    runtime.backstab_id = utils.resolve_spell_id(spells.BACKSTAB)
    runtime.hemorrhage_id = utils.resolve_spell_id(spells.HEMORRHAGE)
    runtime.sinister_strike_id = utils.resolve_spell_id(spells.SINISTER_STRIKE)
    runtime.ghostly_strike_id = utils.resolve_spell_id(spells.GHOSTLY_STRIKE)
    runtime.slice_and_dice_id = utils.resolve_spell_id(spells.SLICE_AND_DICE)
    runtime.rupture_id = utils.resolve_spell_id(spells.RUPTURE)
    runtime.eviscerate_id = utils.resolve_spell_id(spells.EVISCERATE)
    runtime.expose_armor_id = utils.resolve_spell_id(spells.EXPOSE_ARMOR)
    runtime.kidney_shot_id = utils.resolve_spell_id(spells.KIDNEY_SHOT)
    runtime.cheap_shot_id = utils.resolve_spell_id(spells.CHEAP_SHOT)
    runtime.ambush_id = utils.resolve_spell_id(spells.AMBUSH)
    runtime.garrote_id = utils.resolve_spell_id(spells.GARROTE)
    runtime.gouge_id = utils.resolve_spell_id(spells.GOUGE)
    runtime.kick_id = utils.resolve_spell_id(spells.KICK)
    runtime.shadowstep_id = utils.resolve_spell_id(spells.SHADOWSTEP)
    runtime.premeditation_id = utils.resolve_spell_id(spells.PREMEDITATION)
    runtime.vanish_id = utils.resolve_spell_id(spells.VANISH)
    runtime.evasion_id = utils.resolve_spell_id(spells.EVASION)
    runtime.cloak_of_shadows_id = utils.resolve_spell_id(spells.CLOAK_OF_SHADOWS)
    runtime.blind_id = utils.resolve_spell_id(spells.BLIND)
    runtime.cold_blood_id = utils.resolve_spell_id(spells.COLD_BLOOD)
    runtime.preparation_id = utils.resolve_spell_id(spells.PREPARATION)
    runtime.sap_id = utils.resolve_spell_id(spells.SAP)
    runtime.feint_id = utils.resolve_spell_id(spells.FEINT)
    runtime.stealth_id = utils.resolve_spell_id(spells.STEALTH)
end

resolve_spells()

-- Initialize Flux libraries
force_commands:init()

-- Hot-path local caching
local _core_time = core.time

-- Pending cast tracking
local _pending_casts = {}
local function is_pending_cast(spell_id)
    if not spell_id then return false end
    local expire_time = _pending_casts[spell_id]
    if not expire_time then return false end
    if _core_time() > expire_time then
        _pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function mark_pending_cast(spell_id, timeout)
    if not spell_id then return end
    _pending_casts[spell_id] = _core_time() + (timeout or 1.5)
end

-- GCD check
local function is_gcd_ready()
    local gcd = core.spell_book.get_global_cooldown()
    return gcd <= 0
end

-- Target validation
local function is_valid_hostile_target(me, target)
    if not me or not target then return false end
    if not target:is_valid() then return false end
    if target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    return true
end

-- Try cast helpers
local function try_cast_target(spell_id, me, target, name)
    if not spell_id or is_pending_cast(spell_id) then return false end
    if not utils.can_cast_hostile(spell_id, me, target) then return false end
    if utils.cast_target(spell_id, me, target) then
        mark_pending_cast(spell_id, 1.5)
        utils.log_debug(menu, name)
        return true
    end
    return false
end

local function try_cast_self(spell_id, me, name)
    if not spell_id or is_pending_cast(spell_id) then return false end
    if not utils.can_cast_self(spell_id, me) then return false end
    if utils.cast_self(spell_id, me) then
        mark_pending_cast(spell_id, 1.5)
        utils.log_debug(menu, name)
        return true
    end
    return false
end

-- Rotation abilities
local function try_kick(me, target)
    if not (menu.use_interrupt and menu.use_interrupt:get_state()) then return false end
    if not target:is_casting_spell() and not target:is_channelling_spell() then return false end
    
    -- PvP anti-fake interrupt delay
    if target:is_player() then
        local delay = anti_fake_manager.get_interrupt_delay(target, true)
        if delay > 0 then
            local cast_rem = target:get_cast_remaining_time() or 0
            if cast_rem > delay then
                -- Wait for delay before interrupting
                return false
            end
        end
    end
    
    return try_cast_target(runtime.kick_id, me, target, "Kick")
end

local function try_cheap_shot(me, target)
    if not (menu.use_cheap_shot and menu.use_cheap_shot:get_state()) then return false end
    if not runtime.cheap_shot_id then return false end
    if not utils.has_buff(me, spells.BUFF_STEALTH) then return false end
    return try_cast_target(runtime.cheap_shot_id, me, target, "Cheap Shot")
end

local function try_ambush(me, target)
    if not (menu.use_ambush and menu.use_ambush:get_state()) then return false end
    if not runtime.ambush_id then return false end
    if not utils.has_buff(me, spells.BUFF_STEALTH) then return false end
    if not utils.is_behind_target(me, target) then return false end
    return try_cast_target(runtime.ambush_id, me, target, "Ambush")
end

local function try_garrote(me, target)
    if not (menu.use_garrote and menu.use_garrote:get_state()) then return false end
    if not runtime.garrote_id then return false end
    if not utils.has_buff(me, spells.BUFF_STEALTH) then return false end
    if not utils.is_behind_target(me, target) then return false end
    return try_cast_target(runtime.garrote_id, me, target, "Garrote")
end

local function try_premeditation(me, target)
    if not (menu.use_premeditation and menu.use_premeditation:get_state()) then return false end
    if not runtime.premeditation_id then return false end
    if not utils.has_buff(me, spells.BUFF_STEALTH) then return false end
    return try_cast_target(runtime.premeditation_id, me, target, "Premeditation")
end

local function try_slice_and_dice(me, target)
    if not (menu.use_slice_and_dice and menu.use_slice_and_dice:get_state()) then return false end
    if not runtime.slice_and_dice_id then return false end
    if utils.has_buff(me, spells.BUFF_SLICE_AND_DICE) then return false end
    local required_cp = (menu.snd_combo_points and menu.snd_combo_points:get()) or 1
    if runtime.combo_points < required_cp then return false end
    return try_cast_target(runtime.slice_and_dice_id, me, target, "Slice and Dice")
end

local function try_rupture(me, target)
    if not (menu.use_rupture and menu.use_rupture:get_state()) then return false end
    if not runtime.rupture_id then return false end
    local required_cp = (menu.rupture_combo_points and menu.rupture_combo_points:get()) or 5
    if runtime.combo_points < required_cp then return false end
    local rupture_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RUPTURE)
    local refresh_seconds = (menu.rupture_refresh_seconds and menu.rupture_refresh_seconds:get()) or 3
    if rupture_rem > (refresh_seconds * 1000) then return false end
    return try_cast_target(runtime.rupture_id, me, target, "Rupture")
end

local function try_eviscerate(me, target)
    if not (menu.use_eviscerate and menu.use_eviscerate:get_state()) then return false end
    if not runtime.eviscerate_id then return false end
    local required_cp = (menu.eviscerate_combo_points and menu.eviscerate_combo_points:get()) or 5
    if runtime.combo_points < required_cp then return false end
    local rupture_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RUPTURE)
    if rupture_rem <= 3000 then return false end
    return try_cast_target(runtime.eviscerate_id, me, target, "Eviscerate")
end

local function try_expose_armor(me, target)
    if not (menu.use_expose_armor and menu.use_expose_armor:get_state()) then return false end
    if not runtime.expose_armor_id then return false end
    local required_cp = (menu.expose_armor_combo_points and menu.expose_armor_combo_points:get()) or 5
    if runtime.combo_points < required_cp then return false end
    if utils.has_debuff(target, spells.DEBUFF_EXPOSE_ARMOR) then return false end
    return try_cast_target(runtime.expose_armor_id, me, target, "Expose Armor")
end

local function try_kidney_shot(me, target)
    if not (menu.use_kidney_shot and menu.use_kidney_shot:get_state()) then return false end
    if not runtime.kidney_shot_id then return false end
    local required_cp = (menu.kidney_shot_combo_points and menu.kidney_shot_combo_points:get()) or 5
    if runtime.combo_points < required_cp then return false end
    return try_cast_target(runtime.kidney_shot_id, me, target, "Kidney Shot")
end

local function try_backstab(me, target)
    if not (menu.use_backstab and menu.use_backstab:get_state()) then return false end
    if not runtime.backstab_id then return false end
    if not utils.is_behind_target(me, target) then return false end
    if runtime.energy < 60 then return false end
    return try_cast_target(runtime.backstab_id, me, target, "Backstab")
end

local function try_hemorrhage(me, target)
    if not (menu.use_hemorrhage and menu.use_hemorrhage:get_state()) then return false end
    if not runtime.hemorrhage_id then return false end
    if runtime.energy < 35 then return false end
    return try_cast_target(runtime.hemorrhage_id, me, target, "Hemorrhage")
end

local function try_ghostly_strike(me, target)
    if not (menu.use_ghostly_strike and menu.use_ghostly_strike:get_state()) then return false end
    if not runtime.ghostly_strike_id then return false end
    if runtime.energy < 40 then return false end
    return try_cast_target(runtime.ghostly_strike_id, me, target, "Ghostly Strike")
end

local function try_sinister_strike(me, target)
    if not (menu.use_sinister_strike and menu.use_sinister_strike:get_state()) then return false end
    if not runtime.sinister_strike_id then return false end
    if runtime.energy < 45 then return false end
    return try_cast_target(runtime.sinister_strike_id, me, target, "Sinister Strike")
end

local function try_shadowstep(me, target)
    if not (menu.use_shadowstep and menu.use_shadowstep:get_state()) then return false end
    if not runtime.shadowstep_id then return false end
    if utils.has_buff(me, spells.BUFF_SHADOWSTEP) then return false end
    return try_cast_target(runtime.shadowstep_id, me, target, "Shadowstep")
end

local function try_cold_blood(me, target, should_burst)
    if not (menu.use_cold_blood and menu.use_cold_blood:get_state()) then return false end
    if not runtime.cold_blood_id then return false end
    if runtime.combo_points < 5 then return false end
    -- TTD check
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd > 0 and target then
        ---@type combat_forecast
        local forecast = require("common/modules/combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
            return false
        end
    end
    -- Burst window check - if auto_burst enabled, only use during burst
    local auto_burst = (menu.auto_burst_enabled and menu.auto_burst_enabled:get()) or false
    if auto_burst and not should_burst then
        return false
    end
    return try_cast_self(runtime.cold_blood_id, me, "Cold Blood")
end

local function try_preparation(me, target, should_burst)
    if not (menu.use_preparation and menu.use_preparation:get_state()) then return false end
    if not runtime.preparation_id then return false end
    -- Only use if major cooldowns are on cooldown
    local vanish_cd = core.spell_book.get_spell_cooldown(runtime.vanish_id)
    local evasion_cd = core.spell_book.get_spell_cooldown(runtime.evasion_id)
    if vanish_cd <= 0 and evasion_cd <= 0 then return false end
    -- TTD check
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd > 0 and target then
        ---@type combat_forecast
        local forecast = require("common/modules/combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
            return false
        end
    end
    -- Burst window check - if auto_burst enabled, only use during burst
    local auto_burst = (menu.auto_burst_enabled and menu.auto_burst_enabled:get()) or false
    if auto_burst and not should_burst then
        return false
    end
    return try_cast_self(runtime.preparation_id, me, "Preparation")
end

local function try_evasion(me)
    if not (menu.use_evasion and menu.use_evasion:get_state()) then return false end
    if not runtime.evasion_id then return false end
    local hp_pct = utils.get_health_pct(me)
    local threshold = ((menu.evasion_hp_pct and menu.evasion_hp_pct:get()) or 30) / 100
    if hp_pct > threshold then return false end
    return try_cast_self(runtime.evasion_id, me, "Evasion")
end

local function try_feint(me)
    if not (menu.use_feint and menu.use_feint:get_state()) then return false end
    if not runtime.feint_id then return false end
    local enemy_count = 0
    local objects = core.object_manager.get_all_objects()
    local me_player = core.object_manager.get_local_player()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            if me_player and me_player:can_attack(obj) and utils.is_melee_target(me_player, obj) then
                enemy_count = enemy_count + 1
            end
        end
    end
    local threshold = (menu.feint_aoe_threshold and menu.feint_aoe_threshold:get()) or 3
    if enemy_count < threshold then return false end
    return try_cast_self(runtime.feint_id, me, "Feint")
end

-- Main rotation function
local function on_update()
    if not (menu.enabled and menu.enabled:get_state()) then return end

    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return end

    -- Flux library updates
    energy_tick:update(me:get_power(3))
    swing_manager:update_swing(me)

    -- OOC handling (drink/eat only for rogues)
    if not me:is_in_combat() then
        ooc_manager.on_update(me, menu, utils, {})
    end

    -- Crowd Control check - return early if stunned/silenced/feared etc.
    if utils.is_cced and utils.is_cced(me) then return end

    local target = me:get_target()
    if not is_valid_hostile_target(me, target) then
        target = utils.find_best_target(me)
        if not target then return end
    end

    -- Flux combat forecast sampling
    if combat_forecast and target and target:is_valid() then
        combat_forecast:sample(target)
    end

    -- Energy tick delay check before expensive abilities
    if (menu.use_energy_tick and menu.use_energy_tick:get()) then
        if energy_tick:should_delay_action() then return end
    end

    -- Swing delay check
    if (menu.use_swing_delay and menu.use_swing_delay:get()) then
        if swing_manager:is_swing_landing_soon(0.15) then return end
    end

    -- CC Detection: Stop rotation if crowd controlled
    local cc_detector = require("libraries/cc_detector")
    local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

    -- Rogue special: Try Cloak of Shadows for magic CC before stopping
    if should_stop then
        -- Cloak only breaks magic-based CC (not physical stuns)
        if cc_reason ~= "STUN" and cc_reason ~= "SAP" and 
           cc_reason ~= "GOUGE" and cc_reason ~= "DISARM" then
            if utils.try_cloak_of_shadows_cc_break(me, menu) then
                return  -- Successfully broke CC
            end
        end
    end

    if should_stop then
        if (menu.debug and menu.debug:get_state()) then
            print(string.format("[CC] Rotation paused: %s", cc_reason or "CC"))
        end
        return  -- Stop rotation while CC'd
    end

    runtime.combo_points = utils.get_combo_points(me)
    runtime.energy = utils.get_energy(me)

    -- Track combat time for burst windows
    if me:is_in_combat() then
        if runtime.combat_start_time == 0 then
            runtime.combat_start_time = _core_time()
        end
    else
        runtime.combat_start_time = 0
    end
    local combat_time = (runtime.combat_start_time > 0) and (_core_time() - runtime.combat_start_time) or 0

    -- Check burst window and use trinkets
    local should_burst, burst_reason = burst_manager.should_auto_burst(me, target, combat_time, menu)
    trinket_manager.check_trinkets_v2(me, target, should_burst, force_commands, combat_forecast, menu)

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

    if not utils.is_melee_target(me, target) then return end

    -- Defensive cooldowns
    if try_evasion(me) then return end
    if try_feint(me) then return end

    -- Shadowstep for positioning
    if try_shadowstep(me, target) then return end

    -- Interrupt
    if try_kick(me, target) then return end

    -- Stealth openers
    if utils.has_buff(me, spells.BUFF_STEALTH) then
        try_premeditation(me, target)
        if try_ambush(me, target) then return end
        if try_garrote(me, target) then return end
        if try_cheap_shot(me, target) then return end
    end

    -- Cold Blood before finisher
    if runtime.combo_points >= 5 then
        try_cold_blood(me, target, should_burst)
    end

    -- Preparation for cooldown reset
    try_preparation(me, target, should_burst)

    -- Priority 1: Maintain Slice and Dice
    if try_slice_and_dice(me, target) then return end

    -- Priority 2: Rupture at 5 CP
    if try_rupture(me, target) then return end

    -- Priority 3: Eviscerate at 5 CP
    if try_eviscerate(me, target) then return end

    -- Priority 4: Expose Armor
    if try_expose_armor(me, target) then return end

    -- Priority 5: Kidney Shot
    if try_kidney_shot(me, target) then return end

    -- Priority 6: Build combo points
    if try_backstab(me, target) then return end
    if try_hemorrhage(me, target) then return end
    if try_ghostly_strike(me, target) then return end
    if try_sinister_strike(me, target) then return end
end

-- Toggle function for unified menu
local NS = _G.EAXRogueSubtlety and _G.EAXRogueSubtlety.NS or {}
NS.toggle_menu = menu.toggle_menu
_G.EAXRogueSubtlety = _G.EAXRogueSubtlety or {}
_G.EAXRogueSubtlety.NS = NS

-- Initialize dashboard
dashboard.init(dashboard_config)
dashboard.register_render_callback()

-- Register update callback
core.register_on_update_callback(on_update)


