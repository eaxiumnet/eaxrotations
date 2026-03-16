-- EAX Mage Fire | main.lua

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
    scorch_id = nil,
    fireball_id = nil,
    pyroblast_id = nil,
    combustion_id = nil,
    fire_blast_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    pending_casts = {},
}

local GCD_CAST_INTERVAL = 0.05
local PENDING_CAST_TIMEOUT_S = 1.25
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

local function resolve_spells()
    runtime.scorch_id = utils.resolve_spell_id(spells.SCORCH)
    runtime.fireball_id = utils.resolve_spell_id(spells.FIREBALL)
    runtime.pyroblast_id = utils.resolve_spell_id(spells.PYROBLAST)
    runtime.combustion_id = utils.resolve_spell_id(spells.COMBUSTION)
    runtime.fire_blast_id = utils.resolve_spell_id(spells.FIRE_BLAST)
end

local function log_resolved_spells()
    core.log("[EAX Mage Fire] Resolved: Scorch=" .. tostring(runtime.scorch_id)
        .. " Fireball=" .. tostring(runtime.fireball_id)
        .. " Pyro=" .. tostring(runtime.pyroblast_id)
        .. " Comb=" .. tostring(runtime.combustion_id))
end

resolve_spells()
log_resolved_spells()

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

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function try_combustion(me, target)
    if not menu.use_combustion:get_state() then return false end
    if not runtime.combustion_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_COMBUSTION) then return false end
    if is_pending_cast(runtime.combustion_id) or utils.is_spell_already_queued(runtime.combustion_id) then return false end
    if not utils.can_cast_self(runtime.combustion_id, me) then return false end

    if utils.cast_self_fast(runtime.combustion_id, me, "Combustion") then
        mark_pending_cast(runtime.combustion_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Combustion")
        note_cast()
        return true
    end

    return false
end

local function try_trinkets(me)
    if not menu.use_trinkets:get_state() then return false end
    if not me:is_in_combat() then return false end
    if not utils.has_buff(me, spells.BUFF_COMBUSTION) and runtime.cached_mode == "solo" then
        return false
    end

    local trinkets = utils.get_self_cast_trinket_ids(me)
    for i = 1, #trinkets do
        if utils.use_item_if_ready(trinkets[i].item_id) then
            utils.log_debug(menu, "Trinket slot " .. tostring(trinkets[i].slot_id))
            note_cast()
            return true
        end
    end

    return false
end

local function try_pyroblast(me, target)
    if not menu.use_pyroblast:get_state() then return false end
    if not runtime.pyroblast_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end

    local hot_streak = utils.has_buff(me, spells.BUFF_HOT_STREAK)
    local combustion_window = utils.has_buff(me, spells.BUFF_COMBUSTION)
    if not hot_streak and not combustion_window then return false end
    if is_pending_cast(runtime.pyroblast_id) or utils.is_spell_already_queued(runtime.pyroblast_id) then return false end
    if not utils.can_cast_target(runtime.pyroblast_id, me, target) then return false end

    if utils.cast_target(runtime.pyroblast_id, target, "Pyroblast") then
        mark_pending_cast(runtime.pyroblast_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Pyroblast")
        note_cast()
        return true
    end

    return false
end

local function try_scorch(me, target)
    if not menu.use_scorch:get_state() then return false end
    if not runtime.scorch_id then return false end
    if not is_valid_hostile_target(me, target) then return false end

    local stacks = utils.get_debuff_stacks(target, spells.DEBUFF_FIRE_VULNERABILITY)
    local remaining_ms = utils.get_debuff_remaining_ms(target, spells.DEBUFF_FIRE_VULNERABILITY)
    if stacks >= menu.scorch_stack_target:get() and remaining_ms > menu.scorch_refresh_ms:get() then
        return false
    end

    if is_pending_cast(runtime.scorch_id) or utils.is_spell_already_queued(runtime.scorch_id) then return false end
    if not utils.can_cast_target(runtime.scorch_id, me, target) then return false end

    if utils.cast_target(runtime.scorch_id, target, "Scorch") then
        mark_pending_cast(runtime.scorch_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Scorch")
        note_cast()
        return true
    end

    return false
end

local function try_fire_blast_move(me, target)
    if not menu.use_fire_blast_move:get_state() then return false end
    if not runtime.fire_blast_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_moving() then return false end
    if not utils.can_cast_target(runtime.fire_blast_id, me, target) then return false end

    if utils.cast_target_fast(runtime.fire_blast_id, target, "Fire Blast") then
        mark_pending_cast(runtime.fire_blast_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Fire Blast (move)")
        note_cast()
        return true
    end

    return false
end

local function try_fireball(me, target)
    if not menu.use_fireball:get_state() then return false end
    if not runtime.fireball_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end
    if is_pending_cast(runtime.fireball_id) or utils.is_spell_already_queued(runtime.fireball_id) then return false end
    if not utils.can_cast_target(runtime.fireball_id, me, target) then return false end

    if utils.cast_target(runtime.fireball_id, target, "Fireball") then
        mark_pending_cast(runtime.fireball_id, PENDING_CAST_TIMEOUT_S)
        note_cast()
        return true
    end

    return false
end

local function do_rotation(me, target)
    if not is_gcd_ready() then return false end

    -- Interrupt
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "mage", utils) then
            return true
        end
    end

    if try_combustion(me, target) then return true end
    if try_trinkets(me) then return true end
    if try_pyroblast(me, target) then return true end
    if try_scorch(me, target) then return true end
    if try_fire_blast_move(me, target) then return true end
    if try_fireball(me, target) then return true end

    return false
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
        utils.log_debug(menu, "Toggle -> " .. tostring(menu.enabled:get_state()))
    end
    runtime.prev_toggle_state = current
end

core.register_on_update_callback(function()
    if utils.throttle("mode_refresh", 5.0) then
        refresh_mode_cache()
    end

    handle_toggle()

    if not menu.enabled:get_state() then return end

    local me = core.object_manager.get_local_player()
    if not me then return end
    if me:is_dead() then return end

    local target = me:get_target()
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        target = focus_target
    end
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.30, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_ice_block then try_ice_block(me) end
    end
    
    do_rotation(me, target)
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)

core.register_on_render_control_panel_callback(function()
    local elements = {}
    control_panel_utility:insert_toggle_(
        elements,
        "[EAX Mage Fire] Enable (" .. key_helper:get_key_name(menu.toggle_key:get_key_code()) .. ")",
        menu.toggle_key
    )
    return elements
end)

core.log("[EAX Mage Fire] Loaded v1.0.0")
