-- EAX Paladin Retribution | main.lua
-- Rotation logic for Seal twists, Crusader Strike, and Judgement.

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
    crusader_strike_id = nil,
    divine_storm_id = nil,
    avenging_wrath_id = nil,
    seal_command_id = nil,
    seal_righteousness_id = nil,
    seal_blood_id = nil,
    judgement_ids = {
        wisdom = nil,
        crusader = nil,
    },
    last_cast_time = 0,
    cached_mode = "solo",
    last_twist_at = 0,
    twist_state = "idle",
}

local GCD_CAST_INTERVAL = 0.05
local MODE_REFRESH_INTERVAL = 3.0

local function resolve_spells()
    runtime.crusader_strike_id = utils.resolve_spell_id(spells.CRUSADER_STRIKE)
    runtime.divine_storm_id      = utils.resolve_spell_id(spells.DIVINE_STORM)
    runtime.avenging_wrath_id    = utils.resolve_spell_id(spells.AVENGING_WRATH)
    runtime.seal_command_id = utils.resolve_spell_id(spells.SEAL_OF_COMMAND)
    runtime.seal_righteousness_id = utils.resolve_spell_id(spells.SEAL_OF_RIGHTEOUSNESS)
    runtime.seal_blood_id = utils.resolve_spell_id(spells.SEAL_OF_BLOOD)
    runtime.judgement_ids.wisdom = utils.resolve_spell_id(spells.JUDGEMENT_OF_WISDOM)
    runtime.judgement_ids.crusader = utils.resolve_spell_id(spells.JUDGEMENT_OF_THE_CRUSADER)
end

local function log_resolved_spells()
    core.log("[EAX Paladin Retribution] Resolved spells: CS=" .. tostring(runtime.crusader_strike_id))
end

local function detect_mode()
    local objects = core.object_manager.get_visible_objects()
    local party_count = 0
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() 
           and obj:is_party_member() then
            party_count = party_count + 1
        end
    end

    if party_count == 0 then
        return "solo"
    elseif party_count <= 4 then
        return "dungeon"
    end
    return "raid"
end

local function refresh_mode_cache()
    runtime.cached_mode = detect_mode()
end

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 1 then
        return runtime.cached_mode
    end
    if idx == 2 then
        return "solo"
    end
    if idx == 3 then
        return "dungeon"
    end
    return "raid"
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_CAST_INTERVAL then
        return false
    end
    return core.spell_book.get_global_cooldown() <= 0
end

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function twists_allowed_in_mode(mode)
    if mode == "solo" then
        return true
    elseif mode == "dungeon" then
        return menu.allow_twist_dungeon:get_state()
    elseif mode == "raid" then
        return menu.allow_twist_raid:get_state()
    end
    return true
end

local function get_current_seal(me)
    if utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD) then
        return "blood"
    end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
        return "command"
    end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then
        return "righteous"
    end
    return "none"
end

local function should_start_seal_twist(me, target)
    if runtime.twist_state ~= "idle" then
        return false
    end
    if not menu.use_seal_twist:get_state() then
        return false
    end
    local effective_mode = get_effective_mode()
    if not twists_allowed_in_mode(effective_mode) then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not utils.is_melee_target(me, target) then
        return false
    end
    if not runtime.seal_command_id or not runtime.seal_blood_id or not runtime.seal_righteousness_id then
        return false
    end
    if not utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    local next_swing_ms = utils.get_next_swing_ms(me)
    if next_swing_ms < menu.seal_twist_window:get() then
        return false
    end
    local required_cooldown = menu.seal_twist_cooldown:get() / 1000
    if (core.time() - runtime.last_twist_at) < required_cooldown then
        return false
    end
    return true
end

local function begin_seal_twist(me, target)
    if not should_start_seal_twist(me, target) then
        return false
    end
    if utils.cast_self(runtime.seal_blood_id, me) then
        runtime.twist_state = "blood"
        runtime.last_twist_at = core.time()
        utils.log_debug(menu, "Seal twist → Blood")
        note_cast()
        return true
    end
    return false
end

local function continue_seal_twist(me)
    if runtime.twist_state == "idle" then
        return false
    end
    if not is_gcd_ready() then
        return false
    end

    if runtime.twist_state == "blood" then
        if utils.cast_self(runtime.seal_righteousness_id, me) then
            runtime.twist_state = "righteous"
            utils.log_debug(menu, "Seal twist → Righteousness")
            note_cast()
            return true
        end
        return false
    end

    if runtime.twist_state == "righteous" then
        if utils.cast_self(runtime.seal_command_id, me) then
            runtime.twist_state = "command"
            utils.log_debug(menu, "Seal twist → Command")
            note_cast()
            return true
        end
        return false
    end

    if runtime.twist_state == "command" then
        if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
            runtime.twist_state = "idle"
            runtime.last_twist_at = core.time()
        end
    end

    return false
end

local function ensure_command_active(me)
    if runtime.twist_state ~= "idle" then
        return false
    end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    if utils.cast_self(runtime.seal_command_id, me) then
        note_cast()
        utils.log_debug(menu, "Seal: Command baseline")
        return true
    end
    return false
end

local function selected_judgement_key()
    if menu.judgement_choice:get() == 2 then
        return "crusader"
    end
    return "wisdom"
end

local function maybe_cast_judgement(me, target)
    if not menu.use_judgement:get_state() then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end

    local mode_key = selected_judgement_key()
    local debuff = mode_key == "crusader" and spells.DEBUFF_JUDGEMENT_OF_THE_CRUSADER or spells.DEBUFF_JUDGEMENT_OF_WISDOM
    if utils.has_debuff(target, debuff) then
        return false
    end
    local spell_id = runtime.judgement_ids[mode_key]
    if not spell_id then
        return false
    end
    if utils.cast_target(spell_id, me, target) then
        note_cast()
        utils.log_debug(menu, "Judgement → " .. (mode_key == "crusader" and "Crusader" or "Wisdom"))
        return true
    end
    return false
end

local function maybe_cast_crusader_strike(me, target)
    if not menu.use_crusader_strike:get_state() then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    if not runtime.crusader_strike_id then
        return false
    end
    if utils.cast_target(runtime.crusader_strike_id, me, target) then
        note_cast()
        utils.log_debug(menu, "Crusader Strike")
        return true
    end
    return false
end

resolve_spells()
log_resolved_spells()


-- ─── Offensive CDs (v1.1) ─────────────────────────────────────────────────

local function try_avenging_wrath(me)
    if not menu.use_avenging_wrath or not menu.use_avenging_wrath:get_state() then return false end
    if not runtime.avenging_wrath_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_AVENGING_WRATH) then return false end
    if not utils.can_cast_self(runtime.avenging_wrath_id, me) then return false end
    if utils.cast_self_fast(runtime.avenging_wrath_id, me) then
        utils.log_debug(menu, "Avenging Wrath")
        return true
    end
    return false
end

local function try_divine_storm(me, target)
    if not menu.use_divine_storm or not menu.use_divine_storm:get_state() then return false end
    if not runtime.divine_storm_id then return false end
    if not utils.can_cast_target(runtime.divine_storm_id, me, target) then return false end
    if utils.cast_target(runtime.divine_storm_id, target, "Divine Storm") then
        utils.log_debug(menu, "Divine Storm")
        return true
    end
    return false
end


core.register_on_update_callback(function()
    if not menu.enabled:get_state() then
        return
    end

    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then
        return
    end

    if utils.throttle("eaxpr:mode", MODE_REFRESH_INTERVAL) then
        refresh_mode_cache()
    end

    local target = me:get_target()
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        target = focus_target
    end
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_holy_light then try_holy_light(me, me) end
    end
    
    utils.ensure_melee_auto_attack(me, target)

    -- Interrupt
    if target and target:is_valid() and target:is_enemy() and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "paladin", utils) then
            return
        end
    end

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)

    -- Defensive abilities
    ttd_tracker.update(target)

    if defensive_manager.try_defensive(me, "paladin", utils) then
        return
    end

    if continue_seal_twist(me) then
        return
    end

    -- Offensive CDs
    try_avenging_wrath(me)
    if try_divine_storm(me, target) then return end

    if maybe_cast_judgement(me, target) then
        return
    end

    if maybe_cast_crusader_strike(me, target) then
        return
    end

    if begin_seal_twist(me, target) then
        return
    end

    ensure_command_active(me)
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)

core.register_on_render_control_panel_callback(function()
    local elements = {}
    local key_name = key_helper:get_key_name(menu.toggle_key:get_key_code())
    local entry = {
        name = "[EAX Paladin Retribution] Enable (" .. key_name .. ")",
        keybind = menu.toggle_key,
    }
    control_panel_utility:insert_toggle_(elements, entry.name, menu.toggle_key)
    return elements
end)

core.log("[EAX Paladin Retribution] Loaded v1.0.0")
