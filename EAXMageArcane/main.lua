-- EAX Mage Arcane | main.lua

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
    arcane_blast_id = nil,
    arcane_missiles_id = nil,
    arcane_power_id = nil,
    evocation_id = nil,
    fire_blast_id = nil,
    ice_block_id = nil,
    counterspell_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    pending_casts = {},
}

local GCD_CAST_INTERVAL = 0.05
local PENDING_CAST_TIMEOUT_S = 1.25
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

local function resolve_spells()
    runtime.arcane_blast_id = utils.resolve_spell_id(spells.ARCANE_BLAST)
    runtime.arcane_missiles_id = utils.resolve_spell_id(spells.ARCANE_MISSILES)
    runtime.arcane_power_id = utils.resolve_spell_id(spells.ARCANE_POWER)
    runtime.evocation_id = utils.resolve_spell_id(spells.EVOCATION)
    runtime.fire_blast_id = utils.resolve_spell_id(spells.FIRE_BLAST)
    runtime.counterspell_id = utils.resolve_spell_id(spells.COUNTERSPELL)
end

local function log_resolved_spells()
    core.log("[EAX Mage Arcane] Resolved: AB=" .. tostring(runtime.arcane_blast_id)
        .. " AM=" .. tostring(runtime.arcane_missiles_id)
        .. " AP=" .. tostring(runtime.arcane_power_id)
        .. " Evo=" .. tostring(runtime.evocation_id))
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

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then return "solo" end
    if idx == 3 then return "dungeon" end
    if idx == 4 then return "raid" end
    return runtime.cached_mode
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

local function try_mana_gem(me)
    if not menu.use_mana_gem:get_state() then return false end
    if not me:is_in_combat() then return false end
    if utils.get_mana_pct(me) > menu.mana_gem_pct:get() then return false end

    for i = 1, #spells.MANA_GEM_ITEMS do
        if utils.use_consumable_if_ready(me, spells.MANA_GEM_ITEMS[i]) then
            utils.log_debug(menu, "Mana Gem")
            note_cast()
            return true
        end
    end

    return false
end

local function try_evocation(me)
    if not menu.use_evocation:get_state() then return false end
    if not runtime.evocation_id then return false end
    if not me:is_in_combat() then return false end
    if me:is_channelling_spell() then return false end
    if utils.get_mana_pct(me) > menu.evocation_pct:get() then return false end
    if is_pending_cast(runtime.evocation_id) or utils.is_spell_already_queued(runtime.evocation_id) then return false end
    if not utils.can_cast_self(runtime.evocation_id, me) then return false end

    if utils.cast_self(runtime.evocation_id, me, "Evocation") then
        mark_pending_cast(runtime.evocation_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Evocation")
        note_cast()
        return true
    end

    return false
end

local function try_arcane_power(me, target)
    if not menu.use_arcane_power:get_state() then return false end
    if not runtime.arcane_power_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_ARCANE_POWER) then return false end

    local min_mana = menu.burn_mana_pct:get()
    if get_effective_mode() == "raid" then
        min_mana = math.max(50, min_mana)
    elseif get_effective_mode() == "solo" then
        min_mana = math.max(35, min_mana - 10)
    end

    if utils.get_mana_pct(me) < min_mana then return false end
    if is_pending_cast(runtime.arcane_power_id) or utils.is_spell_already_queued(runtime.arcane_power_id) then return false end
    if not utils.can_cast_self(runtime.arcane_power_id, me) then return false end

    if utils.cast_self_fast(runtime.arcane_power_id, me, "Arcane Power") then
        mark_pending_cast(runtime.arcane_power_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Arcane Power")
        note_cast()
        return true
    end

    return false
end

local function try_trinkets(me)
    if not menu.use_trinkets:get_state() then return false end
    if not me:is_in_combat() then return false end
    if get_effective_mode() == "solo" and not utils.has_buff(me, spells.BUFF_ARCANE_POWER) then
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

local function try_arcane_missiles(me, target)
    if not menu.use_arcane_missiles:get_state() then return false end
    if not runtime.arcane_missiles_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end

    local ab_stacks = utils.get_buff_stacks(me, spells.BUFF_ARCANE_BLAST)
    local dump_stacks = menu.arcane_blast_dump_stacks:get()
    local clearcasting = utils.has_buff(me, spells.BUFF_CLEARCASTING)
    local low_mana = utils.get_mana_pct(me) <= (menu.evocation_pct:get() + 15)
    if not clearcasting and not low_mana and ab_stacks < dump_stacks then
        return false
    end

    if is_pending_cast(runtime.arcane_missiles_id) or utils.is_spell_already_queued(runtime.arcane_missiles_id) then return false end
    if not utils.can_cast_target(runtime.arcane_missiles_id, me, target) then return false end

    if utils.cast_target(runtime.arcane_missiles_id, target, "Arcane Missiles") then
        mark_pending_cast(runtime.arcane_missiles_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Arcane Missiles")
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

local function try_arcane_blast(me, target)
    if not menu.use_arcane_blast:get_state() then return false end
    if not runtime.arcane_blast_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end
    if is_pending_cast(runtime.arcane_blast_id) or utils.is_spell_already_queued(runtime.arcane_blast_id) then return false end
    if not utils.can_cast_target(runtime.arcane_blast_id, me, target) then return false end

    if utils.cast_target(runtime.arcane_blast_id, target, "Arcane Blast") then
        mark_pending_cast(runtime.arcane_blast_id, PENDING_CAST_TIMEOUT_S)
        note_cast()
        return true
    end

    return false
end

local function try_ice_block(me)
    if not menu.use_ice_block:get_state() then return false end
    if not runtime.ice_block_id then
        runtime.ice_block_id = utils.resolve_spell_id(spells.ICE_BLOCK)
    end
    if not runtime.ice_block_id then return false end
    local hp_pct = me:get_health_percentage() / 100
    if hp_pct > (menu.ice_block_hp_pct:get() / 100) then return false end
    if utils.has_buff(me, spells.BUFF_ICE_BLOCK) then return false end
    if not utils.can_cast_self(runtime.ice_block_id, me) then return false end
    if utils.cast_self(runtime.ice_block_id, me) then
        utils.log_debug(menu, "Ice Block")
        return true
    end
    return false
end

local function do_rotation(me, target)
    if not is_gcd_ready() then return false end

    -- Interrupt
    if target:is_casting_spell() and target:is_active_spell_interruptable() then
        if runtime.counterspell_id and utils.can_cast_target(runtime.counterspell_id, me, target) then
            if utils.cast_target(runtime.counterspell_id, me, target) then
                utils.log_debug(menu, "Counterspell interrupt")
                return true
            end
        end
    end

    -- Defensive abilities
    if defensive_manager.try_defensive(me, "mage", utils) then
        return true
    end

    if try_mana_gem(me) then return true end
    if try_evocation(me) then return true end
    if try_arcane_power(me, target) then return true end
    if try_trinkets(me) then return true end
    if try_fire_blast_move(me, target) then return true end
    if try_arcane_missiles(me, target) then return true end
    if try_arcane_blast(me, target) then return true end

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
    
    -- Self-emergency (Mage has Ice Block)
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.30, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        try_ice_block(me)
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
        "[EAX Mage Arcane] Enable (" .. key_helper:get_key_name(menu.toggle_key:get_key_code()) .. ")",
        menu.toggle_key
    )
    return elements
end)

core.log("[EAX Mage Arcane] Loaded v1.0.0")
