-- main.lua
-- EAX Shaman Elemental | Rotation driver
-- APIs validated against core, object_manager, and spellbook docs

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type color
local color = require("common/color")

local GCD_INTERVAL = 0.05
local MODE_REFRESH_INTERVAL = 4.5
local PENDING_CAST_TIMEOUT_S = 1.25

local MODE_PROFILE = {
    solo = {
        aoe_threshold = 2,
        mana_floor = 10,
        chain_lightning_mana = 35,
        range_min = 22,
        range_max = 32,
        execute_hp = 0,
    },
    dungeon = {
        aoe_threshold = 3,
        mana_floor = 18,
        chain_lightning_mana = 45,
        range_min = 20,
        range_max = 33,
        execute_hp = 40,
    },
    raid = {
        aoe_threshold = 4,
        mana_floor = 22,
        chain_lightning_mana = 55,
        range_min = 18,
        range_max = 34,
        execute_hp = 50,
    },
}

local runtime = {
    lightning_bolt_id = nil,
    chain_lightning_id = nil,
    flame_shock_id = nil,
    elemental_mastery_id = nil,
    natures_swiftness_id = nil,
    totem_of_wrath_id = nil,
    mana_spring_id = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
    totem_last_apply = {},
    last_ns_at = 0,
}

local TOTEM_ROTATION = {
    { name = "wrath", id_field = "totem_of_wrath_id", toggle = menu.auto_totem_wrath, label = "Totem of Wrath" },
    { name = "mana_spring", id_field = "mana_spring_id", toggle = menu.auto_totem_mana, label = "Mana Spring Totem" },
}

local function resolve_spells()
    runtime.lightning_bolt_id = utils.resolve_spell_id(spells.LIGHTNING_BOLT)
    runtime.chain_lightning_id = utils.resolve_spell_id(spells.CHAIN_LIGHTNING)
    runtime.flame_shock_id = utils.resolve_spell_id(spells.FLAME_SHOCK)
    runtime.elemental_mastery_id = utils.resolve_spell_id(spells.ELEMENTAL_MASTERY)
    runtime.natures_swiftness_id = utils.resolve_spell_id(spells.NATURES_SWIFTNESS)
    runtime.totem_of_wrath_id = utils.resolve_spell_id(spells.TOTEM_OF_WRATH)
    runtime.mana_spring_id = utils.resolve_spell_id(spells.MANA_SPRING_TOTEM)
end

local function log_resolved_spells()
    utils.log_debug(menu, "Spells resolved: LB=" .. tostring(runtime.lightning_bolt_id)
        .. " CL=" .. tostring(runtime.chain_lightning_id)
        .. " FS=" .. tostring(runtime.flame_shock_id)
        .. " EM=" .. tostring(runtime.elemental_mastery_id))
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
    local selection = menu.mode:get()
    if selection == 2 then
        return "solo"
    elseif selection == 3 then
        return "dungeon"
    elseif selection == 4 then
        return "raid"
    end
    return runtime.cached_mode
end

local function get_mode_profile()
    local mode = get_effective_mode()
    return MODE_PROFILE[mode] or MODE_PROFILE.solo
end

local function mark_pending_cast(spell_id, timeout)
    if not spell_id then return end
    runtime.pending_casts[spell_id] = {
        requested_at = core.time(),
        timeout_s = timeout or PENDING_CAST_TIMEOUT_S,
    }
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

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_ready()
    if (core.time() - runtime.last_cast_time) < GCD_INTERVAL then
        return false
    end
    return core.spell_book.get_global_cooldown() <= 0
end

local function try_cast_target(me, target, spell_id, label)
    if not spell_id or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not utils.is_valid_hostile(me, target) then
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not utils.cast_target(spell_id, me, target) then
        return false
    end
    mark_pending_cast(spell_id)
    note_cast()
    utils.log_debug(menu, label .. " cast")
    return true
end

local function try_cast_self(me, spell_id, label)
    if not spell_id or not me or not me:is_valid() then
        return false
    end
    if is_pending_cast(spell_id) then
        return false
    end
    if not utils.can_cast_self(spell_id, me) then
        return false
    end
    if not utils.cast_self(spell_id, me) then
        return false
    end
    mark_pending_cast(spell_id)
    note_cast()
    utils.log_debug(menu, label .. " cast")
    return true
end

local function ensure_totems(me)
    if not menu.auto_totems:get_state() then
        return
    end
    local now = core.time()
    local interval = menu.totem_twist_interval:get()
    for _, entry in ipairs(TOTEM_ROTATION) do
        if entry.toggle:get_state() then
            local spell_id = runtime[entry.id_field]
            if spell_id and utils.can_cast_self(spell_id, me) then
                local last = runtime.totem_last_apply[entry.name] or 0
                if (now - last) >= interval then
                    if try_cast_self(me, spell_id, entry.label) then
                        runtime.totem_last_apply[entry.name] = now
                    end
                end
            end
        end
    end
end

local function try_burst(me, target)
    if not menu.use_cooldowns:get_state() then
        return false
    end
    local profile = get_mode_profile()
    local mode = get_effective_mode()
    local target_hp = target and target:is_valid() and not target:is_dead() and utils.get_health_pct(target) or 0
    if runtime.elemental_mastery_id and (target and (target:is_boss() or mode == "raid" or target_hp >= 0.9)) then
        if try_cast_self(me, runtime.elemental_mastery_id, "Elemental Mastery") then
            return true
        end
    end
    local now = core.time()
    if runtime.natures_swiftness_id and (now - runtime.last_ns_at) > 10 and target_hp > (profile.execute_hp or 0) / 100 then
        if try_cast_self(me, runtime.natures_swiftness_id, "Nature's Swiftness") then
            runtime.last_ns_at = now
            return true
        end
    end
    return false
end

local function try_flame_shock(me, target)
    if not menu.use_flame_shock:get_state() or not runtime.flame_shock_id then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if target:is_moving() then
        return false
    end
    if utils.has_debuff(target, spells.BUFF_FLAME_SHOCK) then
        return false
    end
    local target_hp = utils.get_health_pct(target)
    local stop_pct = math.max(menu.flame_shock_stop_hp:get(), get_mode_profile().execute_hp) / 100
    if target_hp <= stop_pct then
        return false
    end
    return try_cast_target(me, target, runtime.flame_shock_id, "Flame Shock")
end

local function try_chain_lightning(me, target)
    if not runtime.chain_lightning_id or not target then
        return false
    end
    local profile = get_mode_profile()
    local threshold = math.max(menu.aoe_threshold:get(), profile.aoe_threshold)
    local enemy_count = utils.count_enemies_in_range(me, spells.CHAIN_LIGHTNING_RADIUS)
    if enemy_count < threshold then
        return false
    end
    local mana_pct = utils.get_mana_pct(me)
    local mana_cutoff = math.max(menu.chain_lightning_mana:get(), profile.chain_lightning_mana) / 100
    if mana_pct < mana_cutoff then
        return false
    end
    return try_cast_target(me, target, runtime.chain_lightning_id, "Chain Lightning")
end

local function try_lightning_bolt(me, target)
    if not runtime.lightning_bolt_id or not target then
        return false
    end
    local profile = get_mode_profile()
    local mana_pct = utils.get_mana_pct(me)
    local mana_floor = math.max(menu.mana_floor:get(), profile.mana_floor) / 100
    if mana_pct < mana_floor then
        return false
    end
    local target_hp = utils.get_health_pct(target)
    local execute_cutoff = math.max(menu.execute_hp:get(), profile.execute_hp) / 100
    if target_hp <= execute_cutoff then
        return false
    end
    local distance = utils.get_distance(me, target)
    local min_range = math.max(menu.range_min:get(), profile.range_min)
    local max_range = math.max(menu.range_max:get(), profile.range_max)
    if distance < min_range or distance > max_range then
        return false
    end
    return try_cast_target(me, target, runtime.lightning_bolt_id, "Lightning Bolt")
end

local function do_rotation(me, target)
    if not is_gcd_ready() then
        return false
    end
    ensure_totems(me)
    if try_burst(me, target) then
        return true
    end
    if try_flame_shock(me, target) then
        return true
    end
    if try_chain_lightning(me, target) then
        return true
    end
    if try_lightning_bolt(me, target) then
        return true
    end
    return false
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local enabled = menu.enabled:get_state()
        menu.enabled:set(not enabled)
        utils.log_debug(menu, "Toggle -> " .. tostring(not enabled))
    end
    runtime.prev_toggle_state = current
end

resolve_spells()
log_resolved_spells()

core.register_on_update_callback(function()
    if utils.throttle("mode_refresh", MODE_REFRESH_INTERVAL) then
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
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    local target = focus_target or me:get_target()
    
    -- Self-emergency healing
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_healing_surge(me, me) then return end
    end
    
    do_rotation(me, target)
end)

core.register_on_render_menu_callback(function()
    menu.render()
end)

core.register_on_render_control_panel_callback(function()
    local elements = {}
    local toggle_key = menu.toggle_key:get_key_code()
    local name = "[EAX Shaman Elemental] Toggle (" .. key_helper:get_key_name(toggle_key) .. ")"
    control_panel_utility:insert_toggle_(elements, name, menu.toggle_key)
    return elements
end)

core.log("[EAX Shaman Elemental] Loaded")
