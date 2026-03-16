-- main.lua
-- EAX Warlock Destruction | Rotation logic

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    immolate_id = nil,
    shadow_bolt_id = nil,
    incinerate_id = nil,
    conflagrate_id = nil,
    shadowfury_id = nil,
    life_tap_id = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
}

local GCD_INTERVAL_S = 0.05
local PENDING_CAST_TIMEOUT_S = 1.25
local LIFE_TAP_MANA_PCT = 0.38

local function resolve_spells()
    runtime.immolate_id = utils.resolve_spell_id(spells.IMMOLATE)
    runtime.shadow_bolt_id = utils.resolve_spell_id(spells.SHADOW_BOLT)
    runtime.incinerate_id = utils.resolve_spell_id(spells.INCINERATE)
    runtime.conflagrate_id = utils.resolve_spell_id(spells.CONFLAGRATE)
    runtime.shadowfury_id = utils.resolve_spell_id(spells.SHADOWFURY)
    runtime.life_tap_id = utils.resolve_spell_id(spells.LIFE_TAP)
end

local function log_spells()
    core.log("[EAX Warlock Destruction] Resolved: Immolate=" .. tostring(runtime.immolate_id)
        .. " Conflag=" .. tostring(runtime.conflagrate_id)
        .. " Profile Fire=" .. tostring(runtime.incinerate_id)
        .. " Shadow=" .. tostring(runtime.shadow_bolt_id))
end

resolve_spells()
log_spells()

local function is_pending_cast(spell_id)
    if not spell_id then
        return false
    end
    local pending = runtime.pending_casts[spell_id]
    if not pending then
        return false
    end
    if (core.time() - pending) >= PENDING_CAST_TIMEOUT_S then
        runtime.pending_casts[spell_id] = nil
        return false
    end
    return true
end

local function mark_pending_cast(spell_id)
    if not spell_id then
        return
    end
    runtime.pending_casts[spell_id] = core.time()
end

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_INTERVAL_S then
        return false
    end
    return core.spell_book.get_global_cooldown() <= 0
end

local function detect_mode()
    local objects = core.object_manager.get_all_objects()
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
    if idx == 2 then
        return "solo"
    elseif idx == 3 then
        return "dungeon"
    elseif idx == 4 then
        return "raid"
    end
    return runtime.cached_mode
end

local function get_profile()
    local profile_idx = menu.profile:get()
    if profile_idx == 2 then
        return "fire"
    elseif profile_idx == 3 then
        return "shadow"
    end
    if runtime.incinerate_id and not runtime.shadow_bolt_id then
        return "fire"
    end
    if runtime.shadow_bolt_id then
        return "shadow"
    end
    return "fire"
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
        utils.log_debug(menu, "Toggle -> " .. tostring(menu.enabled:get_state()))
    end
    runtime.prev_toggle_state = current
end

local function is_valid_target(me, target)
    if not me or not target then
        return false
    end
    if not target:is_valid() or target:is_dead() then
        return false
    end
    return me:can_attack(target)
end

local function try_cast_spell(me, spell_id, target, label)
    if not spell_id or not target then
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not utils.can_cast_target(spell_id, me, target) then
        return false
    end
    if utils.cast_target(spell_id, me, target) then
        mark_pending_cast(spell_id)
        note_cast()
        utils.log_debug(menu, label .. " cast")
        return true
    end
    return false
end

local function try_cast_self(me, spell_id, label)
    if not spell_id or not me then
        return false
    end
    if not utils.can_cast_self(spell_id, me) then
        return false
    end
    if utils.cast_self(spell_id, me) then
        note_cast()
        utils.log_debug(menu, label .. " cast")
        return true
    end
    return false
end

local function try_immolate(me, target)
    if not menu.use_immolate:get_state() or not runtime.immolate_id then
        return false
    end
    if utils.has_debuff(target, spells.IMMOLATE) then
        local remaining = utils.get_debuff_remaining_ms(target, spells.IMMOLATE)
        if remaining > 3000 then
            return false
        end
    end
    return try_cast_spell(me, runtime.immolate_id, target, "Immolate")
end

local function try_shadowfury(me, target)
    if not menu.use_shadowfury:get_state() or not runtime.shadowfury_id then
        return false
    end
    if not target:is_casting_spell() then
        return false
    end
    return try_cast_spell(me, runtime.shadowfury_id, target, "Shadowfury")
end

local function try_conflagrate(me, target)
    if not menu.use_conflagrate:get_state() or not runtime.conflagrate_id then
        return false
    end
    return try_cast_spell(me, runtime.conflagrate_id, target, "Conflagrate")
end

local function try_nuke(me, target, profile)
    if profile == "fire" and menu.use_incinerate:get_state() and runtime.incinerate_id then
        if try_cast_spell(me, runtime.incinerate_id, target, "Incinerate") then
            return true
        end
    end
    if profile == "shadow" and menu.use_shadow_bolt:get_state() and runtime.shadow_bolt_id then
        if try_cast_spell(me, runtime.shadow_bolt_id, target, "Shadow Bolt") then
            return true
        end
    end
    if profile ~= "shadow" and menu.use_shadow_bolt:get_state() and runtime.shadow_bolt_id then
        return try_cast_spell(me, runtime.shadow_bolt_id, target, "Shadow Bolt")
    end
    if profile ~= "fire" and menu.use_incinerate:get_state() and runtime.incinerate_id then
        return try_cast_spell(me, runtime.incinerate_id, target, "Incinerate")
    end
    return false
end

local function try_life_tap(me, mode)
    if not menu.use_life_tap:get_state() or not runtime.life_tap_id then
        return false
    end
    local health_pct = utils.get_health_pct(me)
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct >= LIFE_TAP_MANA_PCT then
        return false
    end
    local threshold = menu.life_tap_threshold:get() / 100
    if mode == "raid" then
        threshold = math.max(threshold, 0.55)
    elseif mode == "dungeon" then
        threshold = math.max(threshold, 0.5)
    end
    if health_pct < threshold then
        return false
    end
    return try_cast_self(me, runtime.life_tap_id, "Life Tap")
end

local function do_rotation(me, target)
    if not is_gcd_ready() then
        return
    end
    
    -- Interrupt (Shadowfury)
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "warlock", utils) then
            return
        end
    end

    -- Defensive abilities
    if defensive_manager.try_defensive(me, "warlock", utils) then
        return
    end
    
    local effective_mode = get_effective_mode()
    if try_immolate(me, target) then
        return
    end
    if try_shadowfury(me, target) then
        return
    end
    if try_conflagrate(me, target) then
        return
    end
    local profile = get_profile()
    if try_nuke(me, target, profile) then
        return
    end
    try_life_tap(me, effective_mode)
end

core.register_on_update_callback(function()
    if utils.throttle("mode_refresh", 5.0) then
        refresh_mode_cache()
    end
    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end
    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then
        return
    end
    local target = me:get_target()
    if not is_valid_target(me, target) then
        return
    end

    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        target = focus_target
    end

    do_rotation(me, target)
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)

core.register_on_render_control_panel_callback(function()
    local control_panel_elements = {}
    local label = "[EAX Warlock Destruction] Enabled (" .. key_helper:get_key_name(menu.toggle_key:get_key_code()) .. ")"
    control_panel_utility:insert_toggle_(control_panel_elements, label, menu.toggle_key)
    return control_panel_elements
end)

core.log("[EAX Warlock Destruction] Loaded v1.0.0")
