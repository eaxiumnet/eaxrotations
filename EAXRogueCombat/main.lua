require("libraries/path_bootstrap")
-- EAX Rogue Combat | main.lua | Project Sylvanas
-- Combat rotation: Sinister Strike builder, maintain Slice and Dice, Blade Flurry cleave

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

-- Runtime spell cache
local runtime = {
    sinister_strike_id = nil,
    backstab_id = nil,
    shiv_id = nil,
    slice_and_dice_id = nil,
    rupture_id = nil,
    eviscerate_id = nil,
    expose_armor_id = nil,
    kidney_shot_id = nil,
    cheap_shot_id = nil,
    gouge_id = nil,
    kick_id = nil,
    blade_flurry_id = nil,
    adrenaline_rush_id = nil,
    riposte_id = nil,
    vanish_id = nil,
    evasion_id = nil,
    cloak_of_shadows_id = nil,
    blind_id = nil,
    preparation_id = nil,
    feint_id = nil,
    stealth_id = nil,
    combo_points = 0,
    energy = 0,
}

-- Resolve spell IDs on load
local function resolve_spells()
    runtime.sinister_strike_id = utils.resolve_spell_id(spells.SINISTER_STRIKE)
    runtime.backstab_id = utils.resolve_spell_id(spells.BACKSTAB)
    runtime.shiv_id = utils.resolve_spell_id(spells.SHIV)
    runtime.slice_and_dice_id = utils.resolve_spell_id(spells.SLICE_AND_DICE)
    runtime.rupture_id = utils.resolve_spell_id(spells.RUPTURE)
    runtime.eviscerate_id = utils.resolve_spell_id(spells.EVISCERATE)
    runtime.expose_armor_id = utils.resolve_spell_id(spells.EXPOSE_ARMOR)
    runtime.kidney_shot_id = utils.resolve_spell_id(spells.KIDNEY_SHOT)
    runtime.cheap_shot_id = utils.resolve_spell_id(spells.CHEAP_SHOT)
    runtime.gouge_id = utils.resolve_spell_id(spells.GOUGE)
    runtime.kick_id = utils.resolve_spell_id(spells.KICK)
    runtime.blade_flurry_id = utils.resolve_spell_id(spells.BLADE_FLURRY)
    runtime.adrenaline_rush_id = utils.resolve_spell_id(spells.ADRENALINE_RUSH)
    runtime.riposte_id = utils.resolve_spell_id(spells.RIPOSTE)
    runtime.vanish_id = utils.resolve_spell_id(spells.VANISH)
    runtime.evasion_id = utils.resolve_spell_id(spells.EVASION)
    runtime.cloak_of_shadows_id = utils.resolve_spell_id(spells.CLOAK_OF_SHADOWS)
    runtime.blind_id = utils.resolve_spell_id(spells.BLIND)
    runtime.preparation_id = utils.resolve_spell_id(spells.PREPARATION)
    runtime.feint_id = utils.resolve_spell_id(spells.FEINT)
    runtime.stealth_id = utils.resolve_spell_id(spells.STEALTH)
end

resolve_spells()

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
    return try_cast_target(runtime.kick_id, me, target, "Kick")
end

local function try_cheap_shot(me, target)
    if not (menu.use_cheap_shot and menu.use_cheap_shot:get_state()) then return false end
    if not runtime.cheap_shot_id then return false end
    if not utils.has_buff(me, spells.BUFF_STEALTH) then return false end
    return try_cast_target(runtime.cheap_shot_id, me, target, "Cheap Shot")
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

local function try_sinister_strike(me, target)
    if not (menu.use_sinister_strike and menu.use_sinister_strike:get_state()) then return false end
    if not runtime.sinister_strike_id then return false end
    if runtime.energy < 45 then return false end
    return try_cast_target(runtime.sinister_strike_id, me, target, "Sinister Strike")
end

local function try_backstab(me, target)
    if not (menu.use_backstab and menu.use_backstab:get_state()) then return false end
    if not runtime.backstab_id then return false end
    if not utils.is_behind_target(me, target) then return false end
    if runtime.energy < 60 then return false end
    return try_cast_target(runtime.backstab_id, me, target, "Backstab")
end

local function try_shiv(me, target)
    if not (menu.use_shiv and menu.use_shiv:get_state()) then return false end
    if not runtime.shiv_id then return false end
    if runtime.energy < 40 then return false end
    return try_cast_target(runtime.shiv_id, me, target, "Shiv")
end

local function try_blade_flurry(me)
    if not (menu.use_blade_flurry and menu.use_blade_flurry:get_state()) then return false end
    if not runtime.blade_flurry_id then return false end
    if utils.has_buff(me, spells.BUFF_BLADE_FLURRY) then return false end
    -- Count enemies
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
    local threshold = (menu.blade_flurry_min_enemies and menu.blade_flurry_min_enemies:get()) or 2
    if enemy_count < threshold then return false end
    return try_cast_self(runtime.blade_flurry_id, me, "Blade Flurry")
end

local function try_adrenaline_rush(me)
    if not (menu.use_adrenaline_rush and menu.use_adrenaline_rush:get_state()) then return false end
    if not runtime.adrenaline_rush_id then return false end
    if utils.has_buff(me, spells.BUFF_ADRENALINE_RUSH) then return false end
    return try_cast_self(runtime.adrenaline_rush_id, me, "Adrenaline Rush")
end

local function try_riposte(me, target)
    if not (menu.use_riposte and menu.use_riposte:get_state()) then return false end
    if not runtime.riposte_id then return false end
    return try_cast_target(runtime.riposte_id, me, target, "Riposte")
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
    if not menu.is_enabled() then return end

    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return end

    runtime.combo_points = utils.get_combo_points(me)
    runtime.energy = utils.get_energy(me)

    local target = me:get_target()
    if not is_valid_hostile_target(me, target) then
        target = utils.find_best_target(me)
        if not target then return end
    end

    if not utils.is_melee_target(me, target) then return end

    -- Defensive cooldowns
    if try_evasion(me) then return end
    if try_feint(me) then return end

    -- Combat cooldowns
    if try_blade_flurry(me) then return end
    if try_adrenaline_rush(me) then return end

    -- Interrupt
    if try_kick(me, target) then return end

    -- Stealth opener
    if utils.has_buff(me, spells.BUFF_STEALTH) then
        if try_cheap_shot(me, target) then return end
    end

    -- Riposte (after parry)
    if try_riposte(me, target) then return end

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
    if try_sinister_strike(me, target) then return end
    if try_backstab(me, target) then return end
    if try_shiv(me, target) then return end
end

-- Register callbacks
core.register_on_update_callback(on_update)

-- Toggle function for unified menu
local NS = _G.EAXRogueCombat and _G.EAXRogueCombat.NS or {}
NS.toggle_menu = menu.toggle_menu
_G.EAXRogueCombat = _G.EAXRogueCombat or {}
_G.EAXRogueCombat.NS = NS


