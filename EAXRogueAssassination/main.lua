-- EAX Rogue Assassination | main.lua

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")
---@type ttd_tracker
local ttd_tracker = require("common/eax_shared/ttd_tracker")
---@type racial_manager
local racial_manager = require("common/eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    mutilate_id = nil,
    envenom_id = nil,
    eviscerate_id = nil,
    slice_and_dice_id = nil,
    rupture_id = nil,
    kick_id = nil,
    cold_blood_id = nil,
    combo_points = 0,
    combo_target = nil,
    cached_mode = "solo",
    prev_toggle_state = false,
    last_cast_time = 0,
}

local GCD_CAST_INTERVAL = 0.05

local function resolve_spells()
    runtime.mutilate_id = utils.resolve_spell_id(spells.MUTILATE)
    runtime.envenom_id = utils.resolve_spell_id(spells.ENVENOM)
    runtime.eviscerate_id = utils.resolve_spell_id(spells.EVISCERATE)
    runtime.slice_and_dice_id = utils.resolve_spell_id(spells.SLICE_AND_DICE)
    runtime.rupture_id = utils.resolve_spell_id(spells.RUPTURE)
    runtime.kick_id = utils.resolve_spell_id(spells.KICK)
    runtime.cold_blood_id = utils.resolve_spell_id(spells.COLD_BLOOD)
end

local function log_resolved_spells()
    core.log(
        "[EAX Rogue Assassination] Resolved: Mut=" .. tostring(runtime.mutilate_id)
            .. " Env=" .. tostring(runtime.envenom_id)
            .. " SnD=" .. tostring(runtime.slice_and_dice_id)
            .. " Rupt=" .. tostring(runtime.rupture_id)
    )
end

resolve_spells()
log_resolved_spells()

local function current_mode()
    return utils.get_selected_mode(menu)
end

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_CAST_INTERVAL then
        return false
    end

    return core.spell_book.get_global_cooldown() <= 0
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
    end
    runtime.prev_toggle_state = current
end

local function reset_combo_points_if_needed(target)
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

local function try_cold_blood(me)
    local mode = current_mode()
    if not menu.use_cold_blood:get_state() then
        return false
    end
    if mode == "solo" then
        return false
    end
    if not runtime.cold_blood_id then
        return false
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_COLD_BLOOD) > 0 then
        return false
    end
    if not utils.can_cast_self(runtime.cold_blood_id, me) then
        return false
    end

    if utils.cast_self_fast(runtime.cold_blood_id, me, "Cold Blood") then
        utils.log_debug(menu, "Cold Blood")
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

local function try_envenom(me, target)
    if not menu.use_envenom:get_state() then
        return false
    end
    if not runtime.envenom_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points < menu.envenom_combo_points:get() then
        return false
    end

    local poison_stacks = utils.get_debuff_stacks(target, spells.DEBUFF_DEADLY_POISON)
    if poison_stacks < menu.poison_stack_threshold:get() then
        return false
    end
    if not utils.can_cast_target(runtime.envenom_id, me, target) then
        return false
    end

    if try_cold_blood(me) then
        return true
    end

    if utils.cast_target(runtime.envenom_id, target, "Envenom") then
        utils.log_debug(menu, "Envenom at " .. tostring(poison_stacks) .. " stacks")
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
    if runtime.combo_points < menu.rupture_combo_points:get() then
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
    if runtime.combo_points < 4 then
        return false
    end
    if not utils.can_cast_target(runtime.eviscerate_id, me, target) then
        return false
    end

    if try_cold_blood(me) then
        return true
    end

    if utils.cast_target(runtime.eviscerate_id, target, "Eviscerate") then
        utils.log_debug(menu, "Eviscerate")
        note_cast()
        return true
    end

    return false
end

local function try_mutilate(me, target)
    if not menu.use_mutilate:get_state() then
        return false
    end
    if not runtime.mutilate_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points >= 5 then
        return false
    end
    if not utils.can_cast_target(runtime.mutilate_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.mutilate_id, target, "Mutilate") then
        utils.log_debug(menu, "Mutilate")
        note_cast()
        return true
    end

    return false
end

local function do_rotation(me, target)
    if not is_gcd_ready() then
        return false
    end

    -- Interrupt
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "rogue", utils) then
            return true
        end
    end

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)

    -- Defensive abilities
    ttd_tracker.update(target)

    if defensive_manager.try_defensive(me, "rogue", utils) then
        return true
    end

    if try_kick(me, target) then
        return true
    end

    if not utils.can_attack(me, target) then
        return false
    end

    reset_combo_points_if_needed(target)

    if try_slice_and_dice(me) then
        return true
    end
    if try_envenom(me, target) then
        return true
    end
    if try_rupture(me, target) then
        return true
    end
    if try_eviscerate(me, target) then
        return true
    end
    if try_mutilate(me, target) then
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
    
    -- Self-emergency (Rogue has Sprint, Evasion, etc)
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.35, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_evasion then try_evasion(me) end
    end
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)

core.register_on_render_control_panel_callback(function()
    local elements = {}
    local key_name = key_helper:get_key_name(menu.toggle_key:get_key_code())
    control_panel_utility:insert_toggle_(elements, "[EAX Rogue Assassination] Enable (" .. key_name .. ")", menu.toggle_key)
    return elements
end)

core.register_on_spell_cast_callback(function(data)
    if not data or not data.spell_id then
        return
    end

    if data.spell_id == runtime.mutilate_id then
        runtime.combo_points = math.min(runtime.combo_points + 2, 5)
        runtime.combo_target = data.target or runtime.combo_target
    elseif data.spell_id == runtime.envenom_id
        or data.spell_id == runtime.eviscerate_id
        or data.spell_id == runtime.slice_and_dice_id
        or data.spell_id == runtime.rupture_id then
        runtime.combo_points = 0
        runtime.combo_target = data.target or runtime.combo_target
    end
end)

core.log("[EAX Rogue Assassination] Loaded v1.0.0")
