-- Eax Mage Frost | main.lua

local menu = require("libraries/menu")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local spell_downrank = require("libraries/spell_downrank")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end
local eax_utils = require("libraries/eax_utils")
local color     = require("libraries/color")
local buff_manager = require("common/modules/buff_manager")

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")

---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")

---@type leveling_manager
local leveling_manager = require("libraries/leveling_manager")
local pull_optimizer = require("eax_shared/pull_optimizer")
local pvp_manager = require("eax_shared/pvp_manager")
---@type creature_utils
local creature_utils = require("libraries/creature_utils")

---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil

-- BigWigs integration: check for upcoming boss abilities
local function is_bigwigs_danger_window()
    local ok, bw = pcall(function() return core.addons.bigwigs end)
    if not ok or not bw then return false end
    local bars = bw.get_bars and bw:get_bars() or {}
    for _, bar in ipairs(bars) do
        if bar and bar.remaining and bar.remaining < 3.0 then
            return true
        end
    end
    return false
end

-- Dynamic encounter detection from API
local function get_current_encounter_info()
    local ok, encounters = pcall(function() return core.world.get_encounters_on_map() end)
    if not ok or not encounters then return nil end
    return encounters
end

-- CC awareness: check if target can be CC'd (Polymorph)
local function can_cc_target(target)
    local ok, cc = pcall(function() return require("common/utility/cc_data_helper") end)
    if not ok or not cc then return false end
    return cc.can_cc and cc.can_cc(target) or false
end


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("frost", "Mage Frost")
-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("libraries/smart_cast_manager")
-- Phase 04 visual telemetry wiring
local dps_meter = require("libraries/dps_meter")
local cooldown_tracker = require("libraries/cooldown_tracker")
local visual_state = require("libraries/visual_state")
local reactive_runtime = require("libraries/reactive_runtime")
local dps_risk = require("libraries/dps_risk")
local dps_runtime = require("libraries/dps_runtime")

-- Hot-path local caching (performance critical)
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

smart_cast_manager.init({
    core_time = _core_time,
    get_gcd = _get_gcd,
    get_spell_cd = _get_spell_cd,
})

local _visual_ttd_tracker = nil
local _visual_ttd_ok, _visual_ttd_mod = pcall(require, "libraries/ttd_tracker")
if _visual_ttd_ok and _visual_ttd_mod then
    _visual_ttd_tracker = _visual_ttd_mod
end

local _visual_runtime = {
    in_combat = false,
    last_me_hp_pct = nil,
    last_target_hp_pct = nil,
    reactive_state = {},
}

local reactive_adapter = {}

local _visual_on_cast = esp_renderer.on_cast
function esp_renderer.on_cast(spell_id, name, col, target_name)
    if spell_id and core and core.time and core.spell_book and core.spell_book.get_spell_cooldown then
        local now_s = _core_time()
        local cd_s = tonumber(_get_spell_cd(spell_id)) or 0
        cooldown_tracker.set_next_spell(spell_id, now_s, cd_s)
    end
    return _visual_on_cast(spell_id, name, col, target_name)
end

local function visual_get_ttd_seconds(target)
    if not _visual_ttd_tracker or not _visual_ttd_tracker.get then return "--" end
    local ok, value = pcall(function() return _visual_ttd_tracker.get(target) end)
    if not ok then return "--" end
    local ttd_value = tonumber(value)
    if not ttd_value then return "--" end
    return ttd_value
end

local _visual_tracked_auras = { n = 0 }

local function visual_build_tracked_auras(me, target)
    _visual_tracked_auras.n = 0
    if me and me:is_in_combat() then
        _visual_tracked_auras.n = _visual_tracked_auras.n + 1
        _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Combat", active = true }
    end
    if target and target:is_valid() and not target:is_dead() then
        if target:is_casting_spell() then
            _visual_tracked_auras.n = _visual_tracked_auras.n + 1
            _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Cast", active = true }
        end
        if target:is_channelling_spell() then
            _visual_tracked_auras.n = _visual_tracked_auras.n + 1
            _visual_tracked_auras[_visual_tracked_auras.n] = { label = "Channel", active = true }
        end
    end
    for i = _visual_tracked_auras.n + 1, 4 do
        _visual_tracked_auras[i] = nil
    end
    return _visual_tracked_auras
end

local function visual_update_snapshot(me, target)
    if not me then return end
    local in_combat = me:is_in_combat()
    if in_combat and not _visual_runtime.in_combat then
        dps_meter.on_combat_start()
        _visual_runtime.in_combat = true
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        smart_cast_manager.clear_all_pending()
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        smart_cast_manager.reset()
    end

    local me_hp_pct = tonumber(me:get_health_percentage())
    if in_combat and _visual_runtime.last_me_hp_pct and me_hp_pct and me_hp_pct > _visual_runtime.last_me_hp_pct then
        dps_meter.on_heal(me_hp_pct - _visual_runtime.last_me_hp_pct)
    end
    _visual_runtime.last_me_hp_pct = me_hp_pct

    local target_hp_pct = nil
    if target and target:is_valid() and not target:is_dead() then
        target_hp_pct = tonumber(target:get_health_percentage())
    end
    if in_combat and _visual_runtime.last_target_hp_pct and target_hp_pct and target_hp_pct < _visual_runtime.last_target_hp_pct then
        dps_meter.on_damage(_visual_runtime.last_target_hp_pct - target_hp_pct)
    end
    _visual_runtime.last_target_hp_pct = target_hp_pct

    reactive_runtime.update_tick(me, target, {
        adapter = reactive_adapter,
        encounter_manager = encounter_manager,
        state = _visual_runtime.reactive_state,
        spec = "EAXMageFrost",
    })

    local snapshot = visual_state.build_snapshot({
        now_s = _core_time(),
        ttd_seconds = visual_get_ttd_seconds(target),
        tracked_auras = visual_build_tracked_auras(me, target),
    })

    if esp_renderer.update_visual_snapshot then
        esp_renderer.update_visual_snapshot(snapshot)
    elseif esp_renderer.set_visual_snapshot then
        esp_renderer.set_visual_snapshot(snapshot)
    end
end

core.register_on_update_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    local me = _get_local_player()
    if not me or me:is_dead() then return end
    local target = me:get_target()
    visual_update_snapshot(me, target)
end)
---@type ttd_tracker
local ttd_tracker = require("libraries/ttd_tracker")
---@type racial_manager
local racial_manager = require("libraries/racial_manager")
---@type defensive_manager
local defensive_manager = require("libraries/defensive_manager")

---@type mana_conservator
local mana_conservator = require("libraries/mana_conservator")
---@type threat_manager
local threat_manager = require("libraries/threat_manager")
---@type swing_timer
local swing_timer = require("libraries/swing_timer")
---@type mana_manager
local mana_manager = require("libraries/mana_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    frostbolt_id = nil,
    ice_lance_id = nil,
    icy_veins_id = nil,
    water_elemental_id = nil,
    arcane_explosion_id = nil,
    remove_curse_id = nil,
    ice_block_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    pending_casts = {},
    set_multiplier = 1.0,
    ooc_arcane_intellect_id = nil,
    cold_snap_id = nil,
    winters_chill_stacks = 0,
}

local ctx_cache = rotation_context.new({
    important_buffs = {
        spells.BUFF_ICY_VEINS,
        spells.BUFF_ICE_BARRIER,
    },
    important_debuffs = {
        spells.DEBUFF_FROZEN,
    },
})

local GCD_CAST_INTERVAL = 1.5  -- TBC GCD
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

local is_valid_hostile_target
local try_frostbolt

local function resolve_spells()
    runtime.ice_barrier_id  = utils.resolve_spell_id(spells.ICE_BARRIER)
    runtime.cone_of_cold_id = utils.resolve_spell_id(spells.CONE_OF_COLD)
    runtime.arcane_explosion_id = utils.resolve_spell_id(spells.ARCANE_EXPLOSION)
    runtime.frostbolt_id = utils.resolve_spell_id(spells.FROSTBOLT)
    runtime.ice_lance_id = utils.resolve_spell_id(spells.ICE_LANCE)
    runtime.icy_veins_id = utils.resolve_spell_id(spells.ICY_VEINS)
    runtime.water_elemental_id = utils.resolve_spell_id(spells.WATER_ELEMENTAL)
    runtime.cold_snap_id = utils.resolve_spell_id(spells.COLD_SNAP)
    runtime.arcane_intellect_id = utils.resolve_spell_id(spells.ARCANE_INTELLECT)
    runtime.ooc_arcane_intellect_id = runtime.arcane_intellect_id
end

local function get_target_ttd_seconds(target)
    if not target or not ttd_tracker or not ttd_tracker.get then return nil end
    local ok, value = pcall(function() return ttd_tracker.get(target) end)
    if not ok then return nil end
    return tonumber(value)
end

local function get_spell_cast_time_seconds(spell_id)
    if not spell_id or not mana_manager or not mana_manager.get_spell_cast_time_ms then return nil end
    local ok, value = pcall(function() return mana_manager.get_spell_cast_time_ms(spell_id) end)
    if not ok then return nil end
    local ms = tonumber(value)
    return ms and ms > 0 and (ms / 1000) or nil
end

local function target_will_die_before_cast_finishes(me, target, spell_id, buffer_s)
    local ttd_s = get_target_ttd_seconds(target)
    local cast_s = get_spell_cast_time_seconds(spell_id)
    if not ttd_s or not cast_s then return false end
    return ttd_s <= (cast_s + (buffer_s or 0.25))
end

local function get_debuff_state(unit, id_table)
    if not unit or not unit:is_valid() or not id_table then return nil end
    local ok, data = pcall(function()
        return buff_manager:get_debuff_data(unit, id_table)
    end)
    if not ok then return nil end
    return data
end

local function get_debuff_stacks_and_remaining(unit, id_table)
    local data = get_debuff_state(unit, id_table)
    if not data or not data.is_active then return 0, nil end
    local stacks = tonumber(data.stack_count or data.stacks or data.stack or data.application_count) or 1
    local remaining = tonumber(data.remaining_time or data.remaining or data.time_left or data.duration_remaining)
    return stacks, remaining
end

local function update_winters_chill(target)
    if not target or not target:is_valid() then
        runtime.winters_chill_stacks = 0
        return
    end
    runtime.winters_chill_stacks = utils.get_debuff_stacks(target, spells.DEBUFF_WINTERS_CHILL) or 0
end

local function should_refresh_winters_chill(target)
    if not menu.use_winters_chill:get_state() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    local stacks, remaining = get_debuff_stacks_and_remaining(target, spells.DEBUFF_WINTERS_CHILL)
    if stacks <= 0 then return false end
    if stacks < 5 then return true end
    local refresh_s = menu.winters_chill_refresh:get()
    return remaining ~= nil and remaining <= refresh_s
end

local function try_winters_chill_frostbolt(me, target)
    if not menu.use_winters_chill:get_state() then return false end
    if not runtime.frostbolt_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end
    if not should_refresh_winters_chill(target) then return false end
    return try_frostbolt(me, target)
end

local function should_use_ice_lance_for_winters_chill(me, target)
    if not menu.use_winters_chill:get_state() then return false end
    if not me or not me:is_moving() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end

    local stacks, remaining = get_debuff_stacks_and_remaining(target, spells.DEBUFF_WINTERS_CHILL)
    if stacks <= 0 then return false end

    if stacks < 5 then return true end

    local refresh_s = menu.winters_chill_refresh:get()
    return remaining ~= nil and remaining <= refresh_s
end

local function should_abort_frostbolt_commit(me, target)
    if not target or not target:is_valid() or target:is_dead() then
        return true
    end
    return target_will_die_before_cast_finishes(me, target, runtime.frostbolt_id, 0.35)
end

local function log_resolved_spells()
    core.log("[Eax Mage Frost] Resolved: FBolt=" .. tostring(runtime.frostbolt_id)
        .. " Lance=" .. tostring(runtime.ice_lance_id)
        .. " Icy=" .. tostring(runtime.icy_veins_id)
        .. " AE=" .. tostring(runtime.arcane_explosion_id)
        .. " WE=" .. tostring(runtime.water_elemental_id))
end

resolve_spells()
log_resolved_spells()

local function update_set_bonus()
    local me = _get_local_player()
    if not me then return end
    
    local aldor_mult = utils.get_set_multiplier(me, "Aldor")
    local aldor_regalia_mult = utils.get_set_multiplier(me, "AldorRegalia")
    local aldor_nethers_mult = utils.get_set_multiplier(me, "AldorNethers")
    
    runtime.set_multiplier = aldor_mult
    if aldor_regalia_mult > runtime.set_multiplier then
        runtime.set_multiplier = aldor_regalia_mult
    end
    if aldor_nethers_mult > runtime.set_multiplier then
        runtime.set_multiplier = aldor_nethers_mult
    end
    
    if runtime.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(runtime.set_multiplier))
    end
end

local function refresh_mode_cache()
    local me = _get_local_player()
    runtime.cached_mode = me and utils.detect_mode(me) or runtime.cached_mode
end

local function note_cast()
    runtime.last_cast_time = _core_time()
    rotation_context.invalidate(ctx_cache)
end

local function invalidate_ctx()
    rotation_context.invalidate(ctx_cache)
end

local function is_gcd_ready()
    return smart_cast_manager.is_gcd_ready()
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    return smart_cast_manager.is_pending(spell_id)
end

local function mark_pending_cast(spell_id, timeout_s, options)
    if not spell_id then return end
    options = options or {}
    smart_cast_manager.on_cast_attempt(spell_id, options.action_key or "unknown", {
        triggers_gcd = true,
        category = options.category,
        cast_time = options.cast_time,
    })
end

-- Intelligent throttling for specific ability categories
local function should_throttle_dot(action_key)
    return smart_cast_manager.should_throttle(action_key, "dots")
end
local function should_throttle_filler(action_key)
    return smart_cast_manager.should_throttle(action_key, "filler")
end
local function should_throttle_aoe(action_key)
    return smart_cast_manager.should_throttle(action_key, "aoe")
end

is_valid_hostile_target = function(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function is_within_range(a, b, max_range)
    if not a or not b or not max_range then
        return false
    end

    local ok_a, pos_a = pcall(function() return a:get_position() end)
    local ok_b, pos_b = pcall(function() return b:get_position() end)
    if not ok_a or not ok_b or not pos_a or not pos_b then
        return false
    end

    local dx = pos_a.x - pos_b.x
    local dy = pos_a.y - pos_b.y
    local dz = pos_a.z - pos_b.z
    return (dx * dx + dy * dy + dz * dz) <= (max_range * max_range)
end

local function try_water_elemental(me, target)
    if not menu.use_water_elemental:get_state() then return false end
    if not runtime.water_elemental_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if is_pending_cast(runtime.water_elemental_id) or utils.is_spell_already_queued(runtime.water_elemental_id) then return false end
    if not utils.can_cast_self(runtime.water_elemental_id, me) then return false end

    if utils.cast_self_fast(runtime.water_elemental_id, me, "Water Elemental") then
        mark_pending_cast(runtime.water_elemental_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Summon Water Elemental")
        note_cast()
        return true
    end

    return false
end

local function try_icy_veins(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_icy_veins:get_state() then return false end
    if not runtime.icy_veins_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_ICY_VEINS) then return false end
    if is_pending_cast(runtime.icy_veins_id) or utils.is_spell_already_queued(runtime.icy_veins_id) then return false end
    if not utils.can_cast_self(runtime.icy_veins_id, me) then return false end

    if utils.cast_self_fast(runtime.icy_veins_id, me, "Icy Veins") then
        mark_pending_cast(runtime.icy_veins_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Icy Veins")
        note_cast()
                esp_renderer.on_cast(runtime.icy_veins_id, "Icy Veins", color.white(220))
        return true
    end

    return false
end

local function try_trinkets(me)
    if not menu.use_trinkets:get_state() then return false end
    if not me:is_in_combat() then return false end
    if runtime.cached_mode == "solo" and not utils.has_buff(me, spells.BUFF_ICY_VEINS) then
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

local function try_ice_lance(me, target)
    if not menu.use_ice_lance:get_state() then return false end
    if not runtime.ice_lance_id then return false end
    if not is_valid_hostile_target(me, target) then return false end

    local frozen = utils.has_debuff(target, spells.DEBUFF_FROZEN)
    local winters_chill_refresh = should_use_ice_lance_for_winters_chill(me, target)
    if not me:is_moving() and not frozen and not winters_chill_refresh then
        return false
    end
    if me:is_moving() and not winters_chill_refresh and not frozen then
        return false
    end

    if is_pending_cast(runtime.ice_lance_id) or utils.is_spell_already_queued(runtime.ice_lance_id) then return false end
    if not utils.can_cast_hostile(runtime.ice_lance_id, me, target) then return false end

    if utils.cast_target(runtime.ice_lance_id, target, "Ice Lance") then
        mark_pending_cast(runtime.ice_lance_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Ice Lance")
        note_cast()
                esp_renderer.on_cast(runtime.ice_lance_id, "Ice Lance", color.blue(220))
        return true
    end

    return false
end

try_frostbolt = function(me, target)
    if not menu.use_frostbolt:get_state() then return false end
    if not runtime.frostbolt_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if me:is_moving() then return false end
    -- Pull speed: skip Frostbolt on trivial targets (use instant spells instead)
    if pull_optimizer.should_use_instant_only(me, target) then return false end
    -- Leveling: use appropriate spell rank
    local frostbolt_id = runtime.frostbolt_id
    if menu.leveling_conserve_mana and menu.leveling_conserve_mana:get_state() then
        local player_level = me.get_level and me:get_level() or 70
        local target_level = target.get_level and target:get_level() or 70
        local mana_pct = utils.get_mana_pct(me)
        frostbolt_id = spell_downrank.select_dps_rank(spells.FROSTBOLT, target_level, player_level, mana_pct) or frostbolt_id
    end
    if is_pending_cast(frostbolt_id) or utils.is_spell_already_queued(frostbolt_id) then return false end
    if not utils.can_cast_hostile(frostbolt_id, me, target) then return false end

    -- FSCT timing: only cast if we can finish before next swing (cast time < swing time)
    local cast_time_ms = mana_manager.get_spell_cast_time_ms(frostbolt_id)
    local cast_time_s = cast_time_ms / 1000
    local ttd_s = nil
    if ttd_tracker and ttd_tracker.get then
        local ok, value = pcall(function() return ttd_tracker.get(target) end)
        if ok then ttd_s = tonumber(value) end
    end
    if ttd_s and ttd_s > 0 and ttd_s < (cast_time_s + 0.5) then
        return false
    end
    if not swing_timer.can_cast_before_swing(me, cast_time_s + 0.10) then
        return false
    end

    if utils.cast_target(frostbolt_id, target, "Frostbolt") then
        mark_pending_cast(frostbolt_id, PENDING_CAST_TIMEOUT_S)
        note_cast()
                esp_renderer.on_cast(frostbolt_id, "Frostbolt", color.cyan(220))
        return true
    end

    return false
end


-- --- Frost Nova - kite tool (v1.4) ---------------------------------------

local function try_frost_nova(me)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_frost_nova or not menu.use_frost_nova:get_state() then return false end
    if not runtime.frost_nova_id then return false end
    -- Use when a melee enemy is within 8 yards
    local objects = core.object_manager.get_all_objects()
    local melee_attacker = false
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
           and me:can_attack(obj) and is_within_range(me, obj, 8) then
            melee_attacker = true
            break
        end
    end
    if not melee_attacker then return false end
    if not utils.can_cast_self(runtime.frost_nova_id, me) then return false end
    if utils.cast_self(runtime.frost_nova_id, me) then
        utils.log_debug(menu, "Frost Nova (kite)")
        return true
    end
    return false
end

-- --- Presence of Mind - instant cast proc (Arcane talent) (v1.4) ---------

local function try_presence_of_mind(me)
    if not menu.use_presence_of_mind or not menu.use_presence_of_mind:get_state() then return false end
    if not runtime.presence_of_mind_id then return false end
    if utils.has_buff(me, spells.BUFF_PRESENCE_OF_MIND) then return false end
    if not me:is_in_combat() then return false end
    -- Only pop PoM when Arcane Power is active or as opener
    if runtime.arcane_power_id and not utils.has_buff(me, spells.BUFF_ARCANE_POWER) then return false end
    if not utils.can_cast_self(runtime.presence_of_mind_id, me) then return false end
    if utils.cast_self_fast(runtime.presence_of_mind_id, me) then
        utils.log_debug(menu, "Presence of Mind")
        return true
    end
    return false
end



local function try_ice_barrier(me)
    if not menu.use_ice_barrier or not menu.use_ice_barrier:get_state() then return false end
    if not runtime.ice_barrier_id then return false end
    if utils.has_buff(me, spells.BUFF_ICE_BARRIER) then return false end
    local hp = me:get_health_percentage() / 100
    if hp > 0.80 then return false end
    if not utils.can_cast_self(runtime.ice_barrier_id, me) then return false end
    if utils.cast_self(runtime.ice_barrier_id, me) then
        invalidate_ctx()
        utils.log_debug(menu, "Ice Barrier")
        return true
    end
    return false
end

local function try_cone_of_cold_frost(me, target)
    if not menu.use_cone_of_cold or not menu.use_cone_of_cold:get_state() then return false end
    if not runtime.cone_of_cold_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not utils.can_cast_hostile(runtime.cone_of_cold_id, me, target) then return false end
    if utils.cast_target(runtime.cone_of_cold_id, target) then
        utils.log_debug(menu, "Cone of Cold")
        return true
    end
    return false
end

local function try_cold_snap(me, target)
    if not menu.use_cold_snap:get_state() then return false end
    if not runtime.cold_snap_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_ICY_VEINS) then return false end
    if is_pending_cast(runtime.cold_snap_id) or utils.is_spell_already_queued(runtime.cold_snap_id) then return false end
    if not utils.can_cast_self(runtime.cold_snap_id, me) then return false end

    local iv_cd = runtime.icy_veins_id and (tonumber(_get_spell_cd(runtime.icy_veins_id)) or 0) or 999
    local we_cd = runtime.water_elemental_id and (tonumber(_get_spell_cd(runtime.water_elemental_id)) or 0) or 999
    if iv_cd < 8 and we_cd < 8 then return false end

    if utils.cast_self_fast(runtime.cold_snap_id, me, "Cold Snap") then
        mark_pending_cast(runtime.cold_snap_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Cold Snap")
        note_cast()
        return true
    end
    return false
end

local function try_remove_curse(me)
    if not menu.use_remove_curse or not menu.use_remove_curse:get_state() then return false end
    if not runtime.remove_curse_id then runtime.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE) end
    if not runtime.remove_curse_id then return false end
    if not me or not me:is_in_combat() then return false end
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and not me:can_attack(obj) then
            if utils.has_debuff(obj, spells.REMOVE_CURSE) and utils.can_cast_target(runtime.remove_curse_id, me, obj) then
                if utils.cast_target(runtime.remove_curse_id, obj, "Remove Curse") then return true end
            end
        end
    end
    return false
end

local function try_arcane_explosion(me, target)
    if not menu.use_arcane_explosion or not menu.use_arcane_explosion:get_state() then return false end
    if not runtime.arcane_explosion_id then return false end
    if not me or not me:is_in_combat() then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if utils.get_mana_pct(me) < 20 then return false end
    local count = 0
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and me:can_attack(obj) and is_within_range(me, obj, 10) then
            count = count + 1
            if count >= 3 then break end
        end
    end
    if count < 3 then return false end
    return utils.cast_target_fast(runtime.arcane_explosion_id, target, "Arcane Explosion")
end

local function do_rotation(me, target)
    if mana_conservator.on_update(me, target, menu, utils) then return end
    if not is_gcd_ready() then return false end

    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)


    -- Wanding / mana conservation (leveling 1-70)
    if leveling_manager.try_wand(me, target, menu) then return true end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Interrupt
    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "mage", utils) then
            return true
        end
    end

    -- Racial CDs
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense then
        if racial_manager.try_offensive(me) then return true end
    end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end
    if try_remove_curse(me) then return true end

    -- Defensive abilities
    ttd_tracker.update(target)

    if try_arcane_explosion(me, target) then return true end

    if (me:is_casting_spell() or me:is_channelling_spell()) and should_abort_frostbolt_commit(me, target) then
        if SpellStopCasting then
            SpellStopCasting()
            return true
        end
    end

    if defensive_manager.try_defensive(me, "mage", utils) then
        return true
    end

    -- Threat fade protection - don't pull aggro from tank
    local current_target = me:get_target()
    local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
    if ok and should_fade and dps_risk.should_drop_threat(dps_runtime.build_snapshot(me, current_target, encounter_manager, ttd_tracker)) then
        pcall(function() threat_manager.try_fade(me) end)
        return true
    end

    -- Mana potion check (before main damage spells)
    if mana_manager.should_use_mana_potion(me, 30) then
        if mana_manager.use_mana_potion() then
            return true
        end
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) and try_cold_snap(me, target) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) and try_water_elemental(me, target) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_ice_barrier(me) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) and try_cone_of_cold_frost(me, target) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and not hold_offense and try_icy_veins(me, target) then return true end
    if not hold_offense and try_trinkets(me) then return true end

    -- Update Winters Chill tracking
    update_winters_chill(target)

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_winters_chill_frostbolt(me, target) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.05) and try_ice_lance(me, target) then return true end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_frostbolt(me, target) then return true end

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


-- --- Ice Block - emergency freeze (v1.8.2) -------------------------------
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
        invalidate_ctx()
        utils.log_debug(menu, "Ice Block")
        return true
    end
    return false
end

reactive_adapter = {
    spec = "EAXMageFrost",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "mage", utils)
            end,
        },
        life_save_ally = { noop = "unsupported" },
        interrupt_control = {
            handler = function(_, action_deps)
                local interrupt_target = action_deps.target or action_deps.current_target
                if not interrupt_target or not interrupt_target:is_valid() then
                    return false
                end

                if not interrupt_manager.should_interrupt(interrupt_target) then
                    return false
                end

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "mage", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = {
            handler = function(_, action_deps)
                local snapshot = dps_runtime.build_snapshot(action_deps.me, action_deps.current_target, encounter_manager, ttd_tracker)
                if not dps_risk.should_drop_threat(snapshot) then
                    return false
                end
                local ok, faded = pcall(function()
                    return threat_manager.try_fade(action_deps.me)
                end)
                if not ok then
                    return false
                end
                return faded ~= false
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
}

local function on_render()
    return
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(function()
    local me = _get_local_player()
    if not me then return end
    if me:is_dead() then return end

    if utils.throttle("mode_refresh", 5.0) then
        refresh_mode_cache()
    end
    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end

    handle_toggle()

    if not menu.enabled:get_state() then return end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = runtime.ooc_arcane_intellect_id,
               buff_ids = spells.BUFF_ARCANE_INTELLECT,
               name = "Arcane Intellect",
               toggle = menu.ooc_group_buff },
        },
    })
    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    if me:is_in_combat() then
        if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
            consumables_manager.try_use_combat_consumable(me, menu, utils)
        end
        if menu.auto_flask and menu.auto_flask:get_state() then
            consumables_manager.try_maintain_flask(me, menu, utils)
        end
    end

    if eax_utils.is_eating_or_drinking(me) then return end

    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    -- PvP: prioritize enemy players in arena/BG/world PvP
    local target = focus_target or utils.find_best_target(me)
    local pvp_instance = pvp_manager.is_in_pvp_instance()
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        local enemy_players = pvp_manager.find_enemy_players(me, 40)
        if #enemy_players > 0 then
            -- Arena: focus fire lowest HP target
            if pvp_instance == "arena" then
                local focus = pvp_manager.get_arena_focus_target(me, enemy_players)
                if focus then target = focus end
            -- BG: prioritize flag carriers
            elseif pvp_instance == "battleground" then
                local fc = pvp_manager.get_flag_carrier_target(me, enemy_players)
                if fc then target = fc end
            else
                local priority = pvp_manager.priority_target(me, enemy_players)
                if priority then target = priority end
            end
        end
    end
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.30, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_ice_block then try_ice_block(me) end
    end

    -- PvP cooldowns: trinket, ice block, blink
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        if pvp_manager.should_use_pvp_trinket(me) then
            local trinket_ids = { 40426, 40427, 40428, 40429, 40430, 40431 }
            for _, tid in ipairs(trinket_ids) do
                if core.inventory and core.inventory.get_item_count and core.inventory.get_item_count(tid) > 0 then
                    core.input.use_item(tid)
                    break
                end
            end
        end
        pvp_manager.try_mage_pvp_cooldowns(me, target)
    end

    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxmagefrost_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(function()
    menu.render()
end)

if control_panel_utility then
    core.register_on_render_control_panel_callback(function()
        local elements = {}
        local function add_cb(label, item, uid)
            if not item then return end
            local cur = item:get_state()
            local nxt = control_panel_utility:insert_key_checkbox_(elements, label, cur, 0, false, uid)
            if nxt ~= cur then item:set(nxt) end
        end
        local toggle_key = menu.toggle_key:get_key_code()
        local label = "Eax Mage Frost] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxmagefrost_enabled_cp")
        return elements
    end)
end


-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Mage"
    local _eax_spec  = "Frost"
    -- Register this spec for its class (last-loaded wins for tracking)
    if not _G.__EAX_LOADED[_eax_class] then
        _G.__EAX_LOADED[_eax_class] = {}
    end
    _G.__EAX_LOADED[_eax_class][_eax_spec] = function()
        return menu and menu.enabled and menu.enabled:get_state()
    end
    -- Runtime conflict check: fires on render, only warns when 2+ specs enabled
    local _conflict_last_warn = 0
    local _orig_render = on_render
    on_render = function()
        if _orig_render then _orig_render() end
        local specs = _G.__EAX_LOADED[_eax_class]
        if not specs then return end
        local enabled_specs = {}
        for spec_name, is_enabled_fn in pairs(specs) do
            if is_enabled_fn and is_enabled_fn() then
                table.insert(enabled_specs, spec_name)
            end
        end
        if #enabled_specs < 2 then return end
        local now = _core_time()
        if (now - _conflict_last_warn) < 10 then return end
        _conflict_last_warn = now
        local names = table.concat(enabled_specs, " + ")
        core.log("[Eax WARNING] Multiple " .. _eax_class .. " specs enabled: "
            .. names .. ". Disable all but one.")
        core.graphics.add_notification(
            "eax_conflict_" .. _eax_class,
            "[EAX] Conflict!",
            "Multiple " .. _eax_class .. " specs enabled: " .. names .. " - Disable all but one in the bot menu.",
            8.0,
            require("common/color").new(255, 80, 80, 255)
        )
    end
end

local _pi = pcall(require, "plugin_info") and require("plugin_info") or nil
core.log("[Eax Mage Frost] Loaded " .. (_pi and _pi.plugin_version or "?"))
