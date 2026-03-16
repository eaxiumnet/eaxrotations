-- EAX Rogue Combat | main.lua

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    sinister_strike_id = nil,
    slice_and_dice_id = nil,
    eviscerate_id = nil,
    rupture_id = nil,
    kick_id = nil,
    blade_flurry_id = nil,
    adrenaline_rush_id = nil,
    evasion_id = nil,
    combo_points = 0,
    combo_target = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
}

local GCD_CAST_INTERVAL = 0.05

local function resolve_spells()
    runtime.sinister_strike_id = utils.resolve_spell_id(spells.SINISTER_STRIKE)
    runtime.slice_and_dice_id = utils.resolve_spell_id(spells.SLICE_AND_DICE)
    runtime.eviscerate_id = utils.resolve_spell_id(spells.EVISCERATE)
    runtime.rupture_id = utils.resolve_spell_id(spells.RUPTURE)
    runtime.kick_id = utils.resolve_spell_id(spells.KICK)
    runtime.blade_flurry_id = utils.resolve_spell_id(spells.BLADE_FLURRY)
    runtime.adrenaline_rush_id = utils.resolve_spell_id(spells.ADRENALINE_RUSH)
    runtime.evasion_id = utils.resolve_spell_id(spells.EVASION)
end

local function log_resolved_spells()
    core.log(
        "[EAX Rogue Combat] Resolved: SS=" .. tostring(runtime.sinister_strike_id)
            .. " SnD=" .. tostring(runtime.slice_and_dice_id)
            .. " EV=" .. tostring(runtime.eviscerate_id)
            .. " RUP=" .. tostring(runtime.rupture_id)
    )
end

resolve_spells()
log_resolved_spells()

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_CAST_INTERVAL then
        return false
    end

    return core.spell_book.get_global_cooldown() <= 0
end

local function current_mode()
    return utils.get_selected_mode(menu)
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
    end
    runtime.prev_toggle_state = current
end

local function track_target(target)
    if not target or not target:is_valid() then
        runtime.combo_points = 0
        runtime.combo_target = nil
        return
    end

    if runtime.combo_target and runtime.combo_target ~= target then
        runtime.combo_points = 0
    end

    runtime.combo_target = target
end

local function should_use_major_cooldowns(me)
    if not me or not me:is_in_combat() then
        return false
    end

    local mode = current_mode()
    if mode == "solo" then
        return false
    elseif mode == "dungeon" then
        return runtime.combo_points >= 3
    end

    return runtime.combo_points >= 4
end

local function try_kick(me, target)
    if not menu.use_kick:get_state() then
        return false
    end
    if not runtime.kick_id or not utils.can_attack(me, target) then
        return false
    end
    if not target:is_casting_spell() and not target:is_channelling_spell() then
        return false
    end
    if target:is_casting_spell() and not target:is_active_spell_interruptable() then
        return false
    end
    if not utils.can_cast_target(runtime.kick_id, me, target) then
        return false
    end

    if utils.cast_target_fast(runtime.kick_id, target, "Kick") then
        utils.log_debug(menu, "Kick")
        note_cast()
        return true
    end

    return false
end

local function try_blade_flurry(me, target)
    if not menu.use_blade_flurry:get_state() then
        return false
    end
    if not runtime.blade_flurry_id or not me:is_in_combat() then
        return false
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_BLADE_FLURRY) > 0 then
        return false
    end
    if utils.enemy_count_in_radius(me, 8) < menu.aoe_enemy_count:get() and current_mode() == "solo" then
        return false
    end
    if not utils.can_cast_self(runtime.blade_flurry_id, me) then
        return false
    end

    if utils.cast_self_fast(runtime.blade_flurry_id, me, "Blade Flurry") then
        utils.log_debug(menu, "Blade Flurry")
        note_cast()
        return true
    end

    return false
end

local function try_adrenaline_rush(me)
    if not menu.use_adrenaline_rush:get_state() then
        return false
    end
    if not runtime.adrenaline_rush_id or not should_use_major_cooldowns(me) then
        return false
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_ADRENALINE_RUSH) > 0 then
        return false
    end
    if not utils.can_cast_self(runtime.adrenaline_rush_id, me) then
        return false
    end

    if utils.cast_self_fast(runtime.adrenaline_rush_id, me, "Adrenaline Rush") then
        utils.log_debug(menu, "Adrenaline Rush")
        note_cast()
        return true
    end

    return false
end

local function try_slice_and_dice(me)
    if not menu.use_slice_and_dice:get_state() then
        return false
    end
    if not runtime.slice_and_dice_id or runtime.combo_points <= 0 then
        return false
    end

    local remaining_ms = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    if remaining_ms > (menu.snd_refresh_seconds:get() * 1000) then
        return false
    end
    if not utils.can_cast_self(runtime.slice_and_dice_id, me) then
        return false
    end

    if utils.cast_self(runtime.slice_and_dice_id, me, "Slice and Dice") then
        utils.log_debug(menu, "Slice and Dice")
        note_cast()
        return true
    end

    return false
end

local function try_rupture(me, target)
    if not menu.use_rupture:get_state() then
        return false
    end
    if not runtime.rupture_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points < menu.finish_combo_points:get() then
        return false
    end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_RUPTURE) > 3000 then
        return false
    end
    if not utils.can_cast_target(runtime.rupture_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.rupture_id, target, "Rupture") then
        utils.log_debug(menu, "Rupture")
        note_cast()
        return true
    end

    return false
end

local function try_eviscerate(me, target)
    if not menu.use_eviscerate:get_state() then
        return false
    end
    if not runtime.eviscerate_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points < menu.finish_combo_points:get() then
        return false
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE) < 2000 then
        return false
    end
    if not utils.can_cast_target(runtime.eviscerate_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.eviscerate_id, target, "Eviscerate") then
        utils.log_debug(menu, "Eviscerate")
        note_cast()
        return true
    end

    return false
end

local function try_sinister_strike(me, target)
    if not menu.use_sinister_strike:get_state() then
        return false
    end
    if not runtime.sinister_strike_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points >= 5 then
        return false
    end
    if not utils.can_cast_target(runtime.sinister_strike_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.sinister_strike_id, target, "Sinister Strike") then
        utils.log_debug(menu, "Sinister Strike")
        note_cast()
        return true
    end

    return false
end

local function try_evasion(me)
    if not menu.use_evasion:get_state() then return false end
    if not runtime.evasion_id then
        runtime.evasion_id = utils.resolve_spell_id(spells.EVASION)
    end
    if not runtime.evasion_id then return false end
    local hp_pct = me:get_health_percentage() / 100
    if hp_pct > (menu.evasion_hp_pct:get() / 100) then return false end
    if utils.has_buff(me, spells.BUFF_EVASION) then return false end
    if not utils.can_cast_self(runtime.evasion_id, me) then return false end
    if utils.cast_self(runtime.evasion_id, me) then
        utils.log_debug(menu, "Evasion")
        return true
    end
    return false
end

local function do_rotation(me, target)
    if not is_gcd_ready() then
        return false
    end

    if try_kick(me, target) then
        return true
    end

    if should_use_major_cooldowns(me) then
        if try_blade_flurry(me, target) then
            return true
        end
        if try_adrenaline_rush(me) then
            return true
        end
    end

    if not utils.can_attack(me, target) then
        return false
    end

    track_target(target)

    if try_slice_and_dice(me) then
        return true
    end
    if try_rupture(me, target) then
        return true
    end
    if try_eviscerate(me, target) then
        return true
    end
    if try_sinister_strike(me, target) then
        return true
    end

    return false
end

core.register_on_update_callback(function()
    if utils.throttle("mode_refresh", 2.0) then
        runtime.cached_mode = current_mode()
    end

    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end

    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then
        return
    end

    do_rotation(me, me:get_target())
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        core.input.set_target(focus_target)
    end
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.35, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        try_evasion(me)
    end
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)

core.register_on_render_control_panel_callback(function()
    local elements = {}
    local key_name = key_helper:get_key_name(menu.toggle_key:get_key_code())
    control_panel_utility:insert_toggle_(elements, "[EAX Rogue Combat] Enable (" .. key_name .. ")", menu.toggle_key)
    return elements
end)

core.register_on_spell_cast_callback(function(data)
    if not data or not data.spell_id then
        return
    end

    if data.spell_id == runtime.sinister_strike_id then
        runtime.combo_points = math.min(runtime.combo_points + 1, 5)
        runtime.combo_target = data.target or runtime.combo_target
    elseif data.spell_id == runtime.slice_and_dice_id
        or data.spell_id == runtime.rupture_id
        or data.spell_id == runtime.eviscerate_id then
        runtime.combo_points = 0
        runtime.combo_target = data.target or runtime.combo_target
    end
end)

core.log("[EAX Rogue Combat] Loaded v1.0.0")
