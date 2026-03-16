-- EAX Druid Balance | main.lua
-- Callback registration, mode handling, and balance rotation logic.

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    moonkin_form_id = nil,
    faerie_fire_id = nil,
    moonfire_id = nil,
    insect_swarm_id = nil,
    wrath_id = nil,
    starfire_id = nil,
    force_of_nature_id = nil,
    starfall_id = nil,
    innervate_id = nil,
    tranquility_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    pending_casts = {},
}

local GCD_CAST_INTERVAL = 0.05
local PENDING_CAST_TIMEOUT_S = 1.25
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

local function resolve_spells()
    runtime.moonkin_form_id = utils.resolve_spell_id(spells.MOONKIN_FORM)
    runtime.faerie_fire_id = utils.resolve_spell_id(spells.FAERIE_FIRE)
    runtime.moonfire_id = utils.resolve_spell_id(spells.MOONFIRE)
    runtime.insect_swarm_id = utils.resolve_spell_id(spells.INSECT_SWARM)
    runtime.wrath_id = utils.resolve_spell_id(spells.WRATH)
    runtime.starfire_id = utils.resolve_spell_id(spells.STARFIRE)
    runtime.force_of_nature_id = utils.resolve_spell_id(spells.FORCE_OF_NATURE)
    runtime.starfall_id = utils.resolve_spell_id(spells.STARFALL)
    runtime.innervate_id = utils.resolve_spell_id(spells.INNERVATE)
    runtime.tranquility_id = utils.resolve_spell_id(spells.TRANQUILITY)
end

local function log_resolved_spells()
    core.log("[EAX Druid Balance] Resolved: Moonfire=" .. tostring(runtime.moonfire_id)
        .. " InsectSwarm=" .. tostring(runtime.insect_swarm_id)
        .. " Wrath=" .. tostring(runtime.wrath_id)
        .. " Starfire=" .. tostring(runtime.starfire_id)
        .. " ForceOfNature=" .. tostring(runtime.force_of_nature_id)
        .. " Starfall=" .. tostring(runtime.starfall_id))
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

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    local pending = runtime.pending_casts[spell_id]
    if not pending then return false end
    if (core.time() - pending.requested_at) >= pending.timeout_s then
        runtime.pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function mark_pending_cast(spell_id, timeout_s)
    if not spell_id then return end
    runtime.pending_casts[spell_id] = {
        requested_at = core.time(),
        timeout_s = timeout_s or PENDING_CAST_TIMEOUT_S,
    }
end

local function detect_mode(me)
    local objects = core.object_manager.get_all_objects()
    local party_count = 0

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and utils.is_group_member(me, obj) then
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

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then return "solo" end
    if idx == 3 then return "dungeon" end
    if idx == 4 then return "raid" end
    return runtime.cached_mode
end

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local was_enabled = menu.enabled:get_state()
        menu.enabled:set(not was_enabled)
        utils.log_debug(menu, "Toggle -> " .. tostring(not was_enabled))
    end
    runtime.prev_toggle_state = current
end

local function try_moonkin_form(me)
    if not menu.force_moonkin:get_state() then return false end
    if not runtime.moonkin_form_id then return false end
    if utils.has_buff(me, spells.BUFF_MOONKIN_FORM) then return false end
    if is_pending_cast(runtime.moonkin_form_id) then return false end
    if not utils.can_cast_self(runtime.moonkin_form_id, me) then return false end

    if utils.cast_self(runtime.moonkin_form_id, me) then
        mark_pending_cast(runtime.moonkin_form_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Moonkin Form")
        note_cast()
        return true
    end

    return false
end

local function try_innervate(me, mana_pct)
    if not menu.use_innervate:get_state() then return false end
    if not runtime.innervate_id then return false end
    if mana_pct >= (menu.innervate_mana_pct:get() / 100) then return false end
    if utils.has_buff(me, spells.BUFF_INNERVATE) then return false end
    if is_pending_cast(runtime.innervate_id) then return false end
    if not utils.can_cast_self(runtime.innervate_id, me) then return false end

    if utils.cast_self(runtime.innervate_id, me) then
        mark_pending_cast(runtime.innervate_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Innervate")
        note_cast()
        return true
    end

    return false
end

local function try_tranquility(me)
    if not menu.use_tranquility:get_state() then return false end
    if not runtime.tranquility_id then return false end
    if utils.get_health_pct(me) >= (menu.tranquility_hp_pct:get() / 100) then return false end
    if is_pending_cast(runtime.tranquility_id) then return false end
    if not utils.can_cast_self(runtime.tranquility_id, me) then return false end

    if utils.cast_self_fast(runtime.tranquility_id, me) then
        mark_pending_cast(runtime.tranquility_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Emergency Tranquility")
        note_cast()
        return true
    end

    return false
end

local function try_faerie_fire(me, target)
    if not menu.use_faerie_fire:get_state() then return false end
    if not runtime.faerie_fire_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_FAERIE_FIRE) >= 3000 then return false end
    if is_pending_cast(runtime.faerie_fire_id) then return false end
    if not utils.can_cast_target(runtime.faerie_fire_id, me, target) then return false end

    if utils.cast_target(runtime.faerie_fire_id, me, target) then
        mark_pending_cast(runtime.faerie_fire_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Faerie Fire refresh")
        note_cast()
        return true
    end

    return false
end

local function try_moonfire(me, target)
    if not menu.use_moonfire:get_state() then return false end
    if not runtime.moonfire_id then return false end
    if not is_valid_hostile_target(me, target) then return false end

    local refresh_ms = menu.dot_refresh_seconds:get() * 1000
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_MOONFIRE) > refresh_ms then return false end
    if is_pending_cast(runtime.moonfire_id) then return false end
    if not utils.can_cast_target(runtime.moonfire_id, me, target) then return false end

    if utils.cast_target(runtime.moonfire_id, me, target) then
        mark_pending_cast(runtime.moonfire_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Moonfire refresh")
        note_cast()
        return true
    end

    return false
end

local function try_insect_swarm(me, target)
    if not menu.use_insect_swarm:get_state() then return false end
    if not runtime.insect_swarm_id then return false end
    if not is_valid_hostile_target(me, target) then return false end

    local refresh_ms = menu.dot_refresh_seconds:get() * 1000
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_INSECT_SWARM) > refresh_ms then return false end
    if is_pending_cast(runtime.insect_swarm_id) then return false end
    if not utils.can_cast_target(runtime.insect_swarm_id, me, target) then return false end

    if utils.cast_target(runtime.insect_swarm_id, me, target) then
        mark_pending_cast(runtime.insect_swarm_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Insect Swarm refresh")
        note_cast()
        return true
    end

    return false
end

local function try_force_of_nature(me, target, mana_pct)
    if not menu.use_force_of_nature:get_state() then return false end
    if not runtime.force_of_nature_id then return false end
    if not me:is_in_combat() then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if mana_pct < 0.20 then return false end
    if not utils.has_debuff(target, spells.DEBUFF_MOONFIRE) then return false end
    if not utils.has_debuff(target, spells.DEBUFF_INSECT_SWARM) then return false end
    if is_pending_cast(runtime.force_of_nature_id) then return false end
    if not utils.can_cast_self(runtime.force_of_nature_id, me) then return false end

    if utils.cast_self(runtime.force_of_nature_id, me) then
        mark_pending_cast(runtime.force_of_nature_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Force of Nature")
        note_cast()
        return true
    end

    return false
end

local function try_starfall(me, enemy_count, mode)
    if not menu.use_starfall:get_state() then return false end
    if not runtime.starfall_id then return false end
    if not me:is_in_combat() then return false end
    if enemy_count < menu.starfall_aoe_targets:get() and mode == "solo" then return false end
    if is_pending_cast(runtime.starfall_id) then return false end
    if not utils.can_cast_self(runtime.starfall_id, me) then return false end

    if utils.cast_self(runtime.starfall_id, me) then
        mark_pending_cast(runtime.starfall_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Starfall")
        note_cast()
        return true
    end

    return false
end

local function get_primary_nuke_id(me)
    if menu.wrath_during_lunar:get_state() and utils.has_buff(me, spells.BUFF_LUNAR_ECLIPSE) and runtime.wrath_id then
        return runtime.wrath_id, "Wrath"
    end

    if utils.has_buff(me, spells.BUFF_SOLAR_ECLIPSE) and runtime.starfire_id then
        return runtime.starfire_id, "Starfire"
    end

    if runtime.starfire_id then
        return runtime.starfire_id, "Starfire"
    end

    return runtime.wrath_id, "Wrath"
end

local function try_primary_nuke(me, target)
    if not is_valid_hostile_target(me, target) then return false end

    local spell_id, spell_name = get_primary_nuke_id(me)
    if not spell_id then return false end
    if is_pending_cast(spell_id) then return false end
    if not utils.can_cast_target(spell_id, me, target) then return false end

    if utils.cast_target(spell_id, me, target) then
        mark_pending_cast(spell_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, spell_name)
        note_cast()
        return true
    end

    return false
end

local function do_rotation(me, target)
    if not is_gcd_ready() then return false end

    local mode = get_effective_mode()
    local mana_pct = utils.get_mana_pct(me)
    local enemy_count = utils.enemy_count_in_radius(me, 12)

    if try_innervate(me, mana_pct) then return true end
    if try_moonkin_form(me) then return true end
    if try_tranquility(me) then return true end

    if not is_valid_hostile_target(me, target) then
        return false
    end

    if try_faerie_fire(me, target) then return true end
    if try_moonfire(me, target) then return true end
    if try_insect_swarm(me, target) then return true end
    if try_force_of_nature(me, target, mana_pct) then return true end
    if try_starfall(me, enemy_count, mode) then return true end
    if try_primary_nuke(me, target) then return true end

    return false
end

core.register_on_update_callback(function()
    local me = core.object_manager.get_local_player()
    if not me then return end

    if utils.throttle("eaxdruidbalance_mode_refresh", 5.0) then
        runtime.cached_mode = detect_mode(me)
    end

    handle_toggle()

    if not menu.enabled:get_state() then return end
    if me:is_dead() then return end

    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    local target = focus_target or me:get_target()

    -- Interrupt
    if target and target:is_valid() and target:is_enemy() and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "druid", utils) then
            return
        end
    end

    -- Self-emergency healing
    local self_threshold = eax_utils.get_self_heal_threshold(me, menu.tranquility_hp_pct:get() / 100.0, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_tranquility(me) then return end
    end

    do_rotation(me, target)
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)

core.register_on_render_control_panel_callback(function()
    local control_panel_elements = {}
    local enable_toggle_key = menu.toggle_key:get_key_code()
    local enable_toggle_name = "[EAX Druid Balance] Enable (" .. key_helper:get_key_name(enable_toggle_key) .. ")"
    control_panel_utility:insert_toggle_(control_panel_elements, enable_toggle_name, menu.toggle_key)
    return control_panel_elements
end)

core.log("[EAX Druid Balance] Loaded v1.0.0")
