-- main.lua
-- EAX Warlock Demonology | Rotation logic

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
    soul_link_id = nil,
    soul_fire_id = nil,
    shadow_bolt_id = nil,
    shadowfury_id = nil,
    felguard_id = nil,
    life_tap_id = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
    last_felguard_attempt = 0,
}

local GCD_INTERVAL_S = 0.05
local PENDING_CAST_TIMEOUT_S = 1.25
local LIFE_TAP_MANA_PCT = 0.40

local function resolve_spells()
    runtime.soul_link_id = utils.resolve_spell_id(spells.SOUL_LINK)
    runtime.soul_fire_id = utils.resolve_spell_id(spells.SOUL_FIRE)
    runtime.shadow_bolt_id = utils.resolve_spell_id(spells.SHADOW_BOLT)
    runtime.shadowfury_id = utils.resolve_spell_id(spells.SHADOWFURY)
    runtime.felguard_id = utils.resolve_spell_id(spells.SUMMON_FELGUARD)
    runtime.life_tap_id = utils.resolve_spell_id(spells.LIFE_TAP)
end

local function log_spells()
    core.log("[EAX Warlock Demonology] Modes: Soul Fire=" .. tostring(runtime.soul_fire_id)
        .. " Shadow Fury=" .. tostring(runtime.shadowfury_id)
        .. " Felguard=" .. tostring(runtime.felguard_id))
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

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
        runtime.prev_toggle_state = current
        utils.log_debug(menu, "Toggle -> " .. tostring(menu.enabled:get_state()))
        return
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

local function ensure_soul_link(me)
    if not menu.maintain_soul_link:get_state() or not runtime.soul_link_id then
        return false
    end
    if utils.has_buff(me, spells.SOUL_LINK) then
        return false
    end
    return try_cast_self(me, runtime.soul_link_id, "Soul Link")
end

local function ensure_felguard(me)
    if not menu.ensure_felguard:get_state() or not runtime.felguard_id then
        return false
    end
    local now = core.time()
    local interval = menu.pet_check_interval:get()
    if (now - runtime.last_felguard_attempt) < interval then
        return false
    end
    runtime.last_felguard_attempt = now
    return try_cast_self(me, runtime.felguard_id, "Summon Felguard")
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

local function try_soul_fire(me, target)
    if not menu.use_soul_fire:get_state() or not runtime.soul_fire_id then
        return false
    end
    return try_cast_spell(me, runtime.soul_fire_id, target, "Soul Fire")
end

local function try_shadow_bolt(me, target)
    if not menu.use_shadow_bolt:get_state() or not runtime.shadow_bolt_id then
        return false
    end
    return try_cast_spell(me, runtime.shadow_bolt_id, target, "Shadow Bolt")
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

    -- Racial CDs
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)

    -- Defensive abilities
    ttd_tracker.update(target)

    if defensive_manager.try_defensive(me, "warlock", utils) then
        return
    end
    
    local effective_mode = get_effective_mode()
    if ensure_felguard(me) then
        return
    end
    if ensure_soul_link(me) then
        return
    end
    if try_shadowfury(me, target) then
        return
    end
    if try_soul_fire(me, target) then
        return
    end
    if try_shadow_bolt(me, target) then
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
    local label = "[EAX Warlock Demonology] Enabled (" .. key_helper:get_key_name(menu.toggle_key:get_key_code()) .. ")"
    control_panel_utility:insert_toggle_(control_panel_elements, label, menu.toggle_key)
    return control_panel_elements
end)

core.log("[EAX Warlock Demonology] Loaded v1.0.0")
