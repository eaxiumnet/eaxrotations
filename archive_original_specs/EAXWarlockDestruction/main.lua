-- main.lua
-- Eax Warlock Destruction | Rotation logic

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

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")

---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")

---@type leveling_manager
local leveling_manager = require("libraries/leveling_manager")
local pull_optimizer = require("libraries/pull_optimizer")
---@type creature_utils
local creature_utils = require("libraries/creature_utils")

---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
local pvp_manager = require("libraries/pvp_manager")
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

-- CC awareness: check if target can be CC'd (Fear, Banish)
local function can_cc_target(target)
    local ok, cc = pcall(function() return require("common/utility/cc_data_helper") end)
    if not ok or not cc then return false end
    return cc.can_cc and cc.can_cc(target) or false
end


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("destro", "Warlock Destro")
-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("libraries/smart_cast_manager")

-- Phase 04 visual telemetry wiring
local dps_meter = require("libraries/dps_meter")
local cooldown_tracker = require("libraries/cooldown_tracker")
local visual_state = require("libraries/visual_state")
local reactive_runtime = require("libraries/reactive_runtime")
local dps_risk = require("libraries/dps_risk")
local dps_runtime = require("libraries/dps_runtime")
local set_bonus = require("libraries/set_bonus")

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
        spec = "EAXWarlockDestruction",
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
    -- FIXED: Added proper nil guard for menu.enabled:get_state() (line 205)
    if not menu or not menu.enabled or not (menu.enabled and menu.enabled:get_state()) or false then return end
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
---@type dot_manager
local dot_manager = require("libraries/dot_manager")
local _mana_manager_ok, mana_manager = pcall(require, "mana_manager")
if not _mana_manager_ok then mana_manager = nil end
---@type threat_manager
local threat_manager = require("libraries/threat_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    fel_armor_id = nil,
    drain_life_id = nil,
    immolate_id = nil,
    soul_fire_id = nil,
    shadowburn_id = nil,
    shadow_bolt_id = nil,
    drain_soul_id = nil,
    seed_of_corruption_id = nil,
    incinerate_id = nil,
    conflagrate_id = nil,
    shadowfury_id = nil,
    life_tap_id = nil,
    curse_of_agony_id = nil,
    curse_of_doom_id = nil,
    curse_of_elements_id = nil,
    curse_of_recklessness_id = nil,
    curse_of_tongues_id = nil,
    curse_of_weakness_id = nil,
    last_cast_time = 0,
    pending_casts = {},
    cached_mode = "solo",
    prev_toggle_state = false,
    current_curse_type = "none",
    set_multiplier = 1.0,
    last_immolate_cast_s = 0,
    soul_shards_cache = {
        count = 0,
        updated_s = 0,
    },
    backlash_active = false,
    -- Warlock utility
    soulstone_id = nil,
    create_healthstone_id = nil,
    create_soulstone_id = nil,
    last_healthstone_create = 0,
    last_soulstone_apply = 0,
}

local ctx_cache = rotation_context.new({})

local GCD_INTERVAL_S = 0.05
local PENDING_CAST_TIMEOUT_S = 2.5
local SOUL_SHARD_CACHE_TTL_S = 0.5
local LIFE_TAP_MANA_PCT = 0.40
local DRAIN_SOUL_HP_PCT = 0.25
local SHADOWBURN_HP_PCT = 0.25
local SOUL_FIRE_MIN_HP_PCT = 0.25
local SEED_AOE_THRESHOLD = 3
local IMMOLATE_RECAST_GUARD_S = 8.0
local AOE_SNAPSHOT_TTL_S = 0.10

local aoe_snapshot_cache = {
    updated_s = 0,
    me = nil,
    target = nil,
    radius = 0,
    objects = {},
    count = 0,
    me_pos = nil,
}

local function resolve_spells()
    runtime.fel_armor_id = utils.resolve_spell_id(spells.FEL_ARMOR)
    runtime.drain_life_id = utils.resolve_spell_id(spells.DRAIN_LIFE)
    runtime.immolate_id = utils.resolve_spell_id(spells.IMMOLATE)
    runtime.soul_fire_id = utils.resolve_spell_id(spells.SOUL_FIRE)
    runtime.shadowburn_id = utils.resolve_spell_id(spells.SHADOWBURN)
    runtime.shadow_bolt_id = utils.resolve_spell_id(spells.SHADOW_BOLT)
    runtime.drain_soul_id = utils.resolve_spell_id(spells.DRAIN_SOUL)
    runtime.seed_of_corruption_id = utils.resolve_spell_id(spells.SEED_OF_CORRUPTION)
    runtime.incinerate_id = utils.resolve_spell_id(spells.INCINERATE)
    runtime.conflagrate_id = utils.resolve_spell_id(spells.CONFLAGRATE)
    runtime.shadowfury_id = utils.resolve_spell_id(spells.SHADOWFURY)
    runtime.life_tap_id = utils.resolve_spell_id(spells.LIFE_TAP)
    runtime.curse_of_agony_id = utils.resolve_spell_id(spells.CURSE_OF_AGONY)
    runtime.curse_of_doom_id = utils.resolve_spell_id(spells.CURSE_OF_DOOM)
    runtime.curse_of_elements_id = utils.resolve_spell_id(spells.CURSE_OF_ELEMENTS)
    runtime.curse_of_recklessness_id = utils.resolve_spell_id(spells.CURSE_OF_RECKLESSNESS)
    runtime.curse_of_tongues_id = utils.resolve_spell_id(spells.CURSE_OF_TONGUES)
    runtime.curse_of_weakness_id = utils.resolve_spell_id(spells.CURSE_OF_WEAKNESS)
    runtime.soulstone_id = utils.resolve_spell_id(spells.SOULSTONE)
    runtime.create_healthstone_id = utils.resolve_spell_id(spells.CREATE_HEALTHSTONE)
    runtime.create_soulstone_id = utils.resolve_spell_id(spells.CREATE_SOULSTONE)
end

local function log_spells()
    core.log("[Eax Warlock Destruction] Resolved spells: Curse=" .. tostring(runtime.curse_of_elements_id or runtime.curse_of_agony_id)
        .. " Immolate=" .. tostring(runtime.immolate_id)
        .. " Conflag=" .. tostring(runtime.conflagrate_id)
        .. " Incinerate=" .. tostring(runtime.incinerate_id)
        .. " Shadowburn=" .. tostring(runtime.shadowburn_id)
        .. " Soul Fire=" .. tostring(runtime.soul_fire_id))
end

resolve_spells()
log_spells()

-- Backlash proc tracking: +30% spell crit, +25% spell haste for 10s after melee crit
local function check_backlash(me)
    runtime.backlash_active = utils.has_buff(me, spells.BUFF_BACKLASH)
    return runtime.backlash_active
end

local function update_set_bonus()
    local me = _get_local_player()
    if not me then return end
    local best_multiplier = 1.0
    local set_names = { "Voidheart", "VoidheartRegalia", "OblivionRaiment", "CorruptorRaiment", "Malefic" }
    for _, set_name in ipairs(set_names) do
        local set_mult = set_bonus.get_multiplier(me, set_name)
        if set_mult and set_mult > best_multiplier then
            best_multiplier = set_mult
        end
    end
    runtime.set_multiplier = best_multiplier

    if runtime.set_multiplier > 1.0 then
        utils.log_debug(menu, "Set bonus: " .. tostring(runtime.set_multiplier))
    end
end

local function set_adjusted_mana_pct(base_pct, damage_weight)
    local mult = (runtime.set_multiplier or 1.0) * (damage_weight or 1.0)
    if mult <= 1.0 then
        return base_pct
    end
    return math.max(0.04, base_pct / mult)
end

local function note_cast()
    runtime.last_cast_time = _core_time()
    runtime.soul_shards_cache.updated_s = 0
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

local function get_effective_mode()
    -- FIXED: Added proper nil guard for menu.mode:get() (line 406)
    local idx = (menu.mode and menu.mode:get()) or 1
    if idx == 2 then
        return "solo"
    elseif idx == 3 then
        return "dungeon"
    elseif idx == 4 then
        return "raid"
    end
    return runtime.cached_mode
end

local function refresh_mode_cache()
    local me = _get_local_player()
    if not me then
        return
    end
    runtime.cached_mode = utils.detect_mode(me) or runtime.cached_mode or "solo"
end

local function get_profile()
    -- FIXED: Added proper nil guard for menu.profile:get() (line 426)
    local profile_idx = (menu.profile and menu.profile:get()) or 1
    if profile_idx == 2 then
        return "fire"
    elseif profile_idx == 3 then
        return "shadow"
    end
    if runtime.incinerate_id and runtime.conflagrate_id then
        return "fire"
    end
    if runtime.shadow_bolt_id then
        return "shadow"
    end
    if runtime.incinerate_id then
        return "fire"
    end
    return "shadow"
end

local function should_refresh_debuff(target, debuff_ids, spell_id)
    return dot_manager.can_refresh_dot(target, debuff_ids, spell_id, utils.get_debuff_remaining_ms)
end

local function handle_toggle()
    -- FIXED: Added proper nil guard for menu.toggle_key:get_state() (line 449)
    local current = (menu.toggle_key and menu.toggle_key:get_state()) or false
    if current and not runtime.prev_toggle_state then
        -- FIXED: Added proper nil guard for menu.enabled:get_state() (line 451)
        local was_enabled = (menu.enabled and menu.enabled:get_state()) or false
        menu.enabled:set(not was_enabled)
        utils.log_debug(menu, "Toggle -> " .. tostring(not was_enabled))
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
    if not utils.can_cast_hostile(spell_id, me, target) then
        return false
    end
    if utils.cast_target(spell_id, target) then
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

local function get_target_ttd_seconds(target)
    if not target or not ttd_tracker then return nil end
    local ok, value = pcall(function() return ttd_tracker.get(target) end)
    if not ok then return nil end
    return tonumber(value)
end

local function get_spell_cast_time_seconds(spell_id, me)
    if not spell_id then return nil end
    if mana_manager and mana_manager.get_spell_cast_time_ms then
        local ok, value = pcall(function() return mana_manager.get_spell_cast_time_ms(spell_id, me) end)
        if ok then
            local ms = tonumber(value)
            if ms and ms > 0 then return ms / 1000 end
        end
    end
    return nil
end

local function target_will_die_before_cast_finishes(me, target, spell_id, buffer_s)
    local ttd_s = get_target_ttd_seconds(target)
    local cast_s = get_spell_cast_time_seconds(spell_id, me)
    if not ttd_s or not cast_s then return false end
    return ttd_s <= (cast_s + (buffer_s or 0.25))
end

local function get_immolate_remaining_ms(target)
    if not target or not target:is_valid() or target:is_dead() then return 0 end
    return utils.get_debuff_remaining_ms(target, spells.DEBUFF_IMMOLATE) or 0
end

local is_conflagrate_proc_ready

local function get_nearby_hostiles_snapshot(me, target, radius)
    local now_s = _core_time()
    local cache = aoe_snapshot_cache
    if cache.updated_s > 0
        and (now_s - cache.updated_s) <= AOE_SNAPSHOT_TTL_S
        and cache.me == me
        and cache.target == target
        and cache.radius >= radius then
        return cache
    end

    cache.updated_s = now_s
    cache.me = me
    cache.target = target
    cache.radius = radius
    cache.count = 0
    cache.me_pos = me and me.get_position and me:get_position() or nil

    local objects = cache.objects
    for i = 1, #objects do
        objects[i] = nil
    end

    local me_pos = cache.me_pos
    local radius_sq = radius * radius
    local all_objects = core.object_manager.get_all_objects()
    for i = 1, #all_objects do
        local obj = all_objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and me:can_attack(obj) then
            local ok_pos, obj_pos = pcall(function() return obj:get_position() end)
            if me_pos and ok_pos and obj_pos then
                local dx = me_pos.x - obj_pos.x
                local dy = me_pos.y - obj_pos.y
                local dz = me_pos.z - obj_pos.z
                if (dx * dx + dy * dy + dz * dz) <= radius_sq then
                    cache.count = cache.count + 1
                    objects[cache.count] = obj
                end
            elseif is_within_range(me, obj, radius) then
                cache.count = cache.count + 1
                objects[cache.count] = obj
            end
        end
    end

    return cache
end

local function try_fel_armor(me)
    -- FIXED: Added proper nil guard for menu.use_fel_armor:get_state() (line 600)
    if not menu.use_fel_armor or not menu.use_fel_armor:get_state() then
        return false
    end
    if not runtime.fel_armor_id then
        return false
    end
    if utils.has_buff(me, spells.BUFF_FEL_ARMOR) then
        return false
    end
    return try_cast_self(me, runtime.fel_armor_id, "Fel Armor")
end

local function try_immolate(me, target)
    -- FIXED: Added proper nil guard for menu.use_immolate:get_state() (line 613)
    if not (menu.use_immolate and menu.use_immolate:get_state()) or not runtime.immolate_id then
        return false
    end
    local now_s = _core_time()
    if runtime.last_immolate_cast_s > 0 and (now_s - runtime.last_immolate_cast_s) < IMMOLATE_RECAST_GUARD_S then
        return false
    end
    if get_profile() == "fire" and get_immolate_remaining_ms(target) > 0 and is_conflagrate_proc_ready(me, target) then
        return false
    end
    -- Use dot_manager for safe refresh timing (never clips final tick)
    if utils.has_debuff(target, spells.DEBUFF_IMMOLATE) then
        if not dot_manager.can_refresh_dot(target, spells.DEBUFF_IMMOLATE, runtime.immolate_id, utils.get_debuff_remaining_ms) then
            return false
        end
    end
    if try_cast_spell(me, runtime.immolate_id, target, "Immolate") then
        runtime.last_immolate_cast_s = now_s
        return true
    end
    return false
end

local function try_shadowfury(me, target, snapshot)
    if enc and enc.hold_cooldowns then return false end
    -- FIXED: Added proper nil guard for menu.use_shadowfury:get_state() (line 638)
    if not (menu.use_shadowfury and menu.use_shadowfury:get_state()) or not runtime.shadowfury_id then
        return false
    end
    snapshot = snapshot or get_nearby_hostiles_snapshot(me, target, 10)
    local enemy_count = snapshot.count
    if not target:is_casting_spell() and enemy_count < SEED_AOE_THRESHOLD then
        return false
    end
    return try_cast_spell(me, runtime.shadowfury_id, target, "Shadowfury")
end

is_conflagrate_proc_ready = function(me, target)
    -- FIXED: Added proper nil guard for menu.use_conflagrate:get_state() (line 650)
    if not (menu.use_conflagrate and menu.use_conflagrate:get_state()) or not runtime.conflagrate_id then
        return false
    end
    if not is_valid_target(me, target) then
        return false
    end
    if is_pending_cast(runtime.conflagrate_id) then
        return false
    end
    if _get_gcd() > 0 then
        return false
    end

    local has_immolate_proc_window = utils.has_debuff(target, spells.DEBUFF_IMMOLATE)
    if not has_immolate_proc_window then
        return false
    end

    return utils.can_cast_hostile(runtime.conflagrate_id, me, target)
end

local function try_conflagrate(me, target, profile)
    if enc and enc.hold_cooldowns then return false end
    if not is_conflagrate_proc_ready(me, target) then
        return false
    end
    return try_cast_spell(me, runtime.conflagrate_id, target, "Conflagrate")
end

local function count_close_hostiles(me, radius, snapshot)
    snapshot = snapshot or get_nearby_hostiles_snapshot(me, nil, radius)
    return snapshot.count
end

local function count_seeded_targets(me, radius, snapshot)
    snapshot = snapshot or get_nearby_hostiles_snapshot(me, nil, radius)
    local count = 0
    for i = 1, snapshot.count do
        local obj = snapshot.objects[i]
        if obj and utils.has_debuff(obj, spells.DEBUFF_SEED_OF_CORRUPTION) then
            count = count + 1
        end
    end
    return count
end

local function count_soul_shards()
    if not core or not core.inventory or not core.inventory.get_items_in_bag then
        return 0
    end

    local now_s = _core_time()
    local me = _get_local_player()
    local in_combat = me and me:is_in_combat()
    local cache = runtime.soul_shards_cache
    if in_combat and cache.updated_s > 0 and (now_s - cache.updated_s) <= SOUL_SHARD_CACHE_TTL_S then
        return cache.count
    end

    local total = 0
    for bag = 0, 4 do
        local ok, items = pcall(function()
            return core.inventory.get_items_in_bag(bag)
        end)
        if ok and items then
            for _, slot in ipairs(items) do
                local item = slot and slot.object
                if item and item.is_valid and item:is_valid() and item.get_item_id and item:get_item_id() == 6265 then
                    if item.get_item_stack_count then
                        total = total + (item:get_item_stack_count() or 1)
                    else
                        total = total + 1
                    end
                end
            end
        end
    end
    cache.count = total
    cache.updated_s = in_combat and now_s or 0
    return total
end

local function try_seed_of_corruption(me, target, enemy_count, snapshot)
    if enc and not enc.aoe_safe then return false end
    -- FIXED: Added proper nil guard for menu.use_seed_of_corruption:get_state() (line 734)
    if not menu.use_seed_of_corruption or not menu.use_seed_of_corruption:get_state() then return false end
    if not runtime.seed_of_corruption_id or enemy_count < SEED_AOE_THRESHOLD then return false end
    if me:is_moving() then return false end

    snapshot = snapshot or get_nearby_hostiles_snapshot(me, target, 12)
    local seeded_targets = count_seeded_targets(me, 12, snapshot)
    if seeded_targets >= math.min(enemy_count, 3) and utils.has_debuff(target, spells.DEBUFF_SEED_OF_CORRUPTION) then
        return false
    end

    return try_cast_spell(me, runtime.seed_of_corruption_id, target, "Seed of Corruption")
end

local function get_selected_curse(me, target, mode)
    -- FIXED: Added proper nil guard for menu.curse_mode:get() (line 748)
    local idx = (menu.curse_mode and menu.curse_mode:get()) or 1
    local auto_curse = idx == 1

    if auto_curse then
        local in_group_content = mode == "dungeon" or mode == "raid"
        if in_group_content then
            if target and target:is_valid() and not target:is_dead() then
                if ((target.is_casting_spell and target:is_casting_spell()) or (target.is_channelling_spell and target:is_channelling_spell())) and runtime.curse_of_tongues_id then
                    return runtime.curse_of_tongues_id, spells.DEBUFF_CURSE_OF_TONGUES, "Curse of Tongues", "tongues"
                end
            end
            if runtime.curse_of_elements_id then
                return runtime.curse_of_elements_id, spells.DEBUFF_CURSE_OF_ELEMENTS, "Curse of Elements", "elements"
            end
            if runtime.curse_of_weakness_id and utils.is_melee_target(me, target) then
                return runtime.curse_of_weakness_id, spells.DEBUFF_CURSE_OF_WEAKNESS, "Curse of Weakness", "weakness"
            end
        end

        local ttd = visual_get_ttd_seconds(target)
        if runtime.curse_of_doom_id and type(ttd) == "number" and ttd >= 60 then
            return runtime.curse_of_doom_id, spells.DEBUFF_CURSE_OF_DOOM, "Curse of Doom", "doom"
        end
        if runtime.curse_of_agony_id then
            return runtime.curse_of_agony_id, spells.DEBUFF_CURSE_OF_AGONY, "Curse of Agony", "agony"
        end
        if runtime.curse_of_elements_id then
            return runtime.curse_of_elements_id, spells.DEBUFF_CURSE_OF_ELEMENTS, "Curse of Elements", "elements"
        end
        if runtime.curse_of_doom_id then
            return runtime.curse_of_doom_id, spells.DEBUFF_CURSE_OF_DOOM, "Curse of Doom", "doom"
        end
        return nil, nil, nil, nil
    elseif idx == 2 then
        return runtime.curse_of_elements_id, spells.DEBUFF_CURSE_OF_ELEMENTS, "Curse of Elements", "elements"
    elseif idx == 3 then
        return runtime.curse_of_agony_id, spells.DEBUFF_CURSE_OF_AGONY, "Curse of Agony", "agony"
    elseif idx == 4 then
        return runtime.curse_of_doom_id, spells.DEBUFF_CURSE_OF_DOOM, "Curse of Doom", "doom"
    elseif idx == 5 then
        return runtime.curse_of_recklessness_id, spells.DEBUFF_CURSE_OF_RECKLESSNESS, "Curse of Recklessness", "recklessness"
    elseif idx == 6 then
        return runtime.curse_of_tongues_id, spells.DEBUFF_CURSE_OF_TONGUES, "Curse of Tongues", "tongues"
    end

    return runtime.curse_of_weakness_id, spells.DEBUFF_CURSE_OF_WEAKNESS, "Curse of Weakness", "weakness"
end

local function target_has_utility_curse(target)
    return target and (
        utils.has_debuff(target, spells.DEBUFF_CURSE_OF_ELEMENTS)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_WEAKNESS)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_TONGUES)
        or utils.has_debuff(target, spells.DEBUFF_CURSE_OF_RECKLESSNESS)
    )
end

local function try_apply_curse(me, target, mode)
    -- FIXED: Added proper nil guard for menu.use_curse:get_state() (line 806)
    if not menu.use_curse or not menu.use_curse:get_state() then
        return false
    end

    local curse_id, curse_debuffs, label, curse_type = get_selected_curse(me, target, mode)
    if not curse_id or not curse_debuffs then
        return false
    end
    local selected_is_utility = curse_debuffs ~= spells.DEBUFF_CURSE_OF_AGONY and curse_debuffs ~= spells.DEBUFF_CURSE_OF_DOOM
    local active_utility = target_has_utility_curse(target)
    if selected_is_utility then
        if active_utility and not utils.has_debuff(target, curse_debuffs) then
            return false
        end
    elseif active_utility then
        return false
    end
    if not should_refresh_debuff(target, curse_debuffs, curse_id) then
        runtime.current_curse_type = curse_type or runtime.current_curse_type
        return false
    end
    if try_cast_spell(me, curse_id, target, label) then
        runtime.current_curse_type = curse_type or "unknown"
        return true
    end
    return false
end

local function try_shadowburn(me, target)
    -- FIXED: Added proper nil guard for menu.use_shadow_burn:get_state() (line 835)
    if not menu.use_shadow_burn or not menu.use_shadow_burn:get_state() then
        return false
    end
    if not runtime.shadowburn_id then
        return false
    end
    -- Only use Shadowburn when we have enough shards (save for rez/summons)
    local shards = count_soul_shards()
    if shards < 2 then
        return false
    end
    if utils.get_health_pct(target) > SHADOWBURN_HP_PCT then
        return false
    end
    local profile = get_profile()
    local primary_nuke_id = (profile == "fire" and runtime.incinerate_id) or runtime.shadow_bolt_id or runtime.incinerate_id
    local target_hp = utils.get_health_pct(target)
    if target_hp > 0.10 and primary_nuke_id and not target_will_die_before_cast_finishes(me, target, primary_nuke_id, 0.35) then
        return false
    end
    return try_cast_spell(me, runtime.shadowburn_id, target, "Shadowburn")
end

local function try_soul_fire(me, target)
    -- FIXED: Added proper nil guard for menu.use_soul_fire:get_state() (line 859)
    if not menu.use_soul_fire or not menu.use_soul_fire:get_state() then
        return false
    end
    if not runtime.soul_fire_id or me:is_moving() then
        return false
    end
    -- Only use Soul Fire when we have enough shards (save for rez/summons)
    local shards = count_soul_shards()
    if shards < 2 then
        return false
    end
    if utils.get_health_pct(target) <= SOUL_FIRE_MIN_HP_PCT then
        return false
    end
    if target_will_die_before_cast_finishes(me, target, runtime.soul_fire_id, 0.35) then
        return false
    end
    return try_cast_spell(me, runtime.soul_fire_id, target, "Soul Fire")
end

local function try_drain_soul(me, target)
    -- FIXED: Added proper nil guard for menu.use_drain_soul:get_state() (line 880)
    if not menu.use_drain_soul or not menu.use_drain_soul:get_state() then
        return false
    end
    if not runtime.drain_soul_id then
        return false
    end
    if utils.get_health_pct(target) > DRAIN_SOUL_HP_PCT then
        return false
    end
    return try_cast_spell(me, runtime.drain_soul_id, target, "Drain Soul")
end

local function try_nuke(me, target, profile)
    -- Check Backlash proc: prioritize Shadow Bolt/Incinerate when active (higher crit chance)
    local backlash = check_backlash(me)
    -- Leveling: use appropriate spell rank
    local shadow_bolt_id = runtime.shadow_bolt_id
    local incinerate_id = runtime.incinerate_id
    -- FIXED: Added proper nil guard for menu.leveling_conserve_mana:get_state() (line 898)
    if menu.leveling_conserve_mana and menu.leveling_conserve_mana:get_state() then
        local player_level = me.get_level and me:get_level() or 70
        local target_level = target.get_level and target:get_level() or 70
        local mana_pct = utils.get_mana_pct(me)
        shadow_bolt_id = spell_downrank.select_dps_rank(spells.SHADOW_BOLT, target_level, player_level, mana_pct) or shadow_bolt_id
        incinerate_id = spell_downrank.select_dps_rank(spells.INCINERATE, target_level, player_level, mana_pct) or incinerate_id
    end
    if target_will_die_before_cast_finishes(me, target, profile == "fire" and incinerate_id or shadow_bolt_id, 0.35) then
        return false
    end
    -- FIXED: Added proper nil guard for menu.use_immolate:get_state() (line 908)
    if profile == "fire" and menu.use_immolate and menu.use_immolate:get_state() and get_immolate_remaining_ms(target) <= 2500 then
        return false
    end
    -- Fire profile: Immolate -> Conflagrate -> Incinerate cycle
    -- Shadow Bolt (filler) only when not in fire profile or Backlash active
    if profile == "fire" and not backlash then
        -- Fire profile: prefer Incinerate as main nuke (unless Backlash prioritizes it)
        -- FIXED: Added proper nil guard for menu.use_incinerate:get_state() (line 915)
        if menu.use_incinerate and menu.use_incinerate:get_state() and incinerate_id then
            if try_cast_spell(me, incinerate_id, target, "Incinerate") then
                esp_renderer.on_cast(nil, "Incinerate", color.red(220))
                return true
            end
        end
    else
        -- Shadow profile or Backlash active: use Shadow Bolt
        -- FIXED: Added proper nil guard for menu.use_shadow_bolt:get_state() (line 923)
        if menu.use_shadow_bolt and menu.use_shadow_bolt:get_state() and shadow_bolt_id then
            if try_cast_spell(me, shadow_bolt_id, target, "Shadow Bolt") then
                return true
            end
        end
        -- Fallback to Incinerate in shadow profile if Shadow Bolt unavailable
        -- FIXED: Added proper nil guard for menu.use_incinerate:get_state() (line 929)
        if profile ~= "fire" and menu.use_incinerate and menu.use_incinerate:get_state() and incinerate_id then
            return try_cast_spell(me, incinerate_id, target, "Incinerate")
        end
    end
    return false
end

local function try_life_tap(me, mode)
    -- FIXED: Added proper nil guard for menu.use_life_tap:get_state() (line 937)
    if not (menu.use_life_tap and menu.use_life_tap:get_state()) or not runtime.life_tap_id then
        return false
    end
    local health_pct = utils.get_health_pct(me)
    local mana_pct = utils.get_mana_pct(me)
    if mana_pct >= LIFE_TAP_MANA_PCT then
        return false
    end
    if me:is_in_combat() and not utils.has_buff(me, spells.BUFF_FEL_ARMOR) then
        return false
    end
    -- FIXED: Added proper nil guard for menu.life_tap_threshold:get() (line 948)
    local threshold = ((menu.life_tap_threshold and menu.life_tap_threshold:get()) or 20) / 100
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


-- --- Pet selection + management (v1.4) ------------------------------------

local PET_NPC_IDS = {
    imp = 416,
    voidwalker = 1860,
    succubus = 1863,
    felhunter = 417,
    felguard = 17252,
}

local SUMMON_SPELLS = {
    imp        = spells.SUMMON_IMP,
    voidwalker = spells.SUMMON_VOIDWALKER,
    succubus   = spells.SUMMON_SUCCUBUS,
    felhunter  = spells.SUMMON_FELHUNTER,
    felguard   = spells.SUMMON_FELGUARD,
}

local PET_REQUIRES_SHARD = {
    imp = false,
    voidwalker = true,
    succubus = true,
    felhunter = true,
    felguard = true,
}

local function get_pet_npc_id()
    local me = _get_local_player()
    if not me then return 0 end
    local pet = me.get_pet and me:get_pet() or nil
    if not pet or not pet:is_valid() or pet:is_dead() then return 0 end
    return pet.get_npc_id and pet:get_npc_id() or 0
end

local function current_pet_name()
    local npc = get_pet_npc_id()
    for name, id in pairs(PET_NPC_IDS) do
        if npc == id then return name end
    end
    return "none"
end

local function desired_pet_name(mode)
    -- FIXED: Added proper nil guard for menu.preferred_pet:get() (line 1004)
    local pet_mode = (menu.preferred_pet and menu.preferred_pet:get()) or 1
    if pet_mode == 2 then return "imp" end
    if pet_mode == 3 then return "voidwalker" end
    if pet_mode == 4 then return "succubus" end
    if pet_mode == 5 then return "felhunter" end
    if pet_mode == 6 then return "felguard" end
    return nil
end

local function try_summon_correct_pet(me, mode)
    if me:is_in_combat() then return false end  -- never summon mid-combat
    if not utils.throttle("warlock_pet_check", 5.0) then return false end

    local current = current_pet_name()
    local desired = desired_pet_name(mode)
    if not desired then return false end

    if current == desired then return false end  -- already correct

    local spell_table = SUMMON_SPELLS[desired]
    if not spell_table then return false end
    local spell_id = utils.resolve_spell_id(spell_table)
    if not spell_id then return false end
    if PET_REQUIRES_SHARD[desired] and count_soul_shards() < 1 then
        if utils.throttle("eax_destruction_pet_shard_warning", 10.0) then
            core.log("[Eax Warlock Destruction] Cannot summon " .. desired .. ": need at least 1 Soul Shard.")
            core.graphics.add_notification(
                "eax_destruction_pet_shard_warning",
                "[EAX] Pet Summon Blocked",
                "Cannot summon " .. desired .. ": need at least 1 Soul Shard.",
                6.0,
                require("common/color").new(255, 180, 80, 255)
            )
        end
        return false
    end
    if not utils.can_cast_self(spell_id, me) then return false end

    utils.cast_self(spell_id, me)
    invalidate_ctx()
    utils.log_debug(menu, "Summoning " .. desired)
    return true
end

-- --- Soul Shard farming (v1.4) --------------------------------------------
-- Use Drain Soul on targets below 10% HP to collect shards

local SHARD_FARM_HP_PCT = 0.10
local SHARD_ITEM_IDS = { 6265 }  -- Soul Shard (stacks, any version)

local function try_soul_shard_farm(me, target, drain_soul_id)
    -- FIXED: Added proper nil guard for menu.auto_shard_farm:get_state() (line 1055)
    if not menu.auto_shard_farm or not menu.auto_shard_farm:get_state() then return false end
    if not drain_soul_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    local hp = utils.get_health_pct(target)
    if hp > SHARD_FARM_HP_PCT then return false end
    -- Only farm if below the shard threshold set in menu
    -- FIXED: Added proper nil guard for menu.min_shards:get() (line 1061)
    local min_shards = (menu.min_shards and menu.min_shards:get()) or 3
    if count_soul_shards() >= min_shards then return false end
    if not utils.can_cast_hostile(drain_soul_id, me, target) then return false end
    if utils.cast_target(drain_soul_id, target, "Drain Soul (shard)") then
        mark_pending_cast(drain_soul_id)
        note_cast()
        utils.log_debug(menu, "Drain Soul for shard farm")
        return true
    end
    return false
end
local function try_drain_life_defensive(me, target)
    -- FIXED: Added proper nil guard for menu.use_drain_life_def:get_state() (line 1073)
    if not (menu.use_drain_life_def and menu.use_drain_life_def:get_state()) then return false end
    if not runtime.drain_life_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    local hp = me:get_health_percentage() / 100
    -- FIXED: Added proper nil guard for menu.use_drain_life_def_hp_pct:get() (line 1077)
    local threshold = menu.use_drain_life_def_hp_pct and (menu.use_drain_life_def_hp_pct:get() / 100) or 0.35
    if hp > threshold then return false end
    if not utils.can_cast_hostile(runtime.drain_life_id, me, target) then return false end
    if utils.cast_target(runtime.drain_life_id, target) then
        invalidate_ctx()
        utils.log_debug(menu, "Drain Life (defensive)")
        return true
    end
    return false
end

-- --- Warlock Utility: Soulstone, Healthstone, Self-Soulstone (v1.0) --------

local SOULSTONE_COOLDOWN_S = 1800
local HEALTHSTONE_COOLDOWN_S = 120
local HEALTHSTONE_USE_HP = 0.50

local function try_create_healthstone(me)
    -- FIXED: Added proper nil guard for menu.use_create_healthstone:get_state() (line 1095)
    if not menu.use_create_healthstone or not menu.use_create_healthstone:get_state() then return false end
    if not runtime.create_healthstone_id then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    local now = _core_time()
    if (now - runtime.last_healthstone_create) < HEALTHSTONE_COOLDOWN_S then return false end
    local has_healthstone = false
    for _, item_id in ipairs(spells.HEALTHSTONE_ITEMS) do
        if core.inventory and core.inventory.get_item_count then
            local count = core.inventory.get_item_count(item_id)
            if count and count > 0 then has_healthstone = true; break end
        end
    end
    if has_healthstone then return false end
    if not utils.can_cast_self(runtime.create_healthstone_id, me) then return false end
    if utils.cast_self(runtime.create_healthstone_id, me) then
        runtime.last_healthstone_create = now
        utils.log_debug(menu, "Create Healthstone")
        return true
    end
    return false
end

local function try_use_healthstone(me)
    -- FIXED: Added proper nil guard for menu.use_create_healthstone:get_state() (line 1119)
    if not menu.use_create_healthstone or not menu.use_create_healthstone:get_state() then return false end
    if not me:is_in_combat() then return false end
    local hp = utils.get_health_pct(me)
    if hp > HEALTHSTONE_USE_HP then return false end
    for _, item_id in ipairs(spells.HEALTHSTONE_ITEMS) do
        if core.inventory and core.inventory.get_item_count then
            local count = core.inventory.get_item_count(item_id)
            if count and count > 0 then
                if core.input.use_item(item_id) then
                    utils.log_debug(menu, "Use Healthstone (HP=" .. math.floor(hp * 100) .. "%)")
                    return true
                end
            end
        end
    end
    return false
end

local function try_soulstone_dead_ally(me)
    -- FIXED: Added proper nil guard for menu.use_soulstone:get_state() (line 1138)
    if not menu.use_soulstone or not menu.use_soulstone:get_state() then return false end
    if not runtime.soulstone_id then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    local now = _core_time()
    if (now - runtime.last_soulstone_apply) < 30 then return false end
    local objects = core.object_manager.get_all_objects()
    for _, obj in ipairs(objects) do
        if obj and obj:is_valid() and obj:is_unit() and obj:is_player()
            and obj:is_party_member() and obj:is_dead() and not obj:is_ghost() then
            if not utils.has_buff(obj, spells.SOULSTONE) then
                if utils.can_cast_target(runtime.soulstone_id, me, obj) then
                    if utils.cast_target(runtime.soulstone_id, obj, "Soulstone") then
                        runtime.last_soulstone_apply = now
                        utils.log_debug(menu, "Soulstone on " .. (obj.get_name and obj:get_name() or "party member"))
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function try_self_soulstone(me)
    -- FIXED: Added proper nil guard for menu.use_soulstone:get_state() (line 1163)
    if not menu.use_soulstone or not menu.use_soulstone:get_state() then return false end
    if not runtime.soulstone_id then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    if utils.has_buff(me, spells.SOULSTONE) then return false end
    local now = _core_time()
    if (now - runtime.last_soulstone_apply) < 30 then return false end
    if not utils.can_cast_self(runtime.soulstone_id, me) then return false end
    if utils.cast_self(runtime.soulstone_id, me) then
        runtime.last_soulstone_apply = now
        utils.log_debug(menu, "Soulstone (self)")
        return true
    end
    return false
end

local function do_rotation(me, target)
    if mana_conservator.on_update(me, target, menu, utils) then return end
    if not is_gcd_ready() then
        return
    end
    
    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)

    -- Interrupt (Shadowfury)
    -- FIXED: Added proper nil guard for menu.use_interrupt:get_state() (line 1189)
    if target and menu.use_interrupt and menu.use_interrupt:get_state() and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "warlock", utils) then
            return
        end
    end


    -- Wanding / mana conservation (leveling 1-70)
    if leveling_manager.try_wand(me, target, menu) then return true end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Racial CDs
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense and racial_manager.try_offensive(me) then return end
    if racial_manager.try_utility(me, target) then return end
    if racial_manager.try_defensive(me) then return end

    -- Defensive abilities
    ttd_tracker.update(target)

    if (me:is_casting_spell() or me:is_channelling_spell()) and dps_risk.should_abort_commit(
        dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker),
        {
            kind = me:is_channelling_spell() and "channel" or "cast",
            progress_pct = 0.20,
            remaining_s = 1.0,
            projected_damage_pct = 0.06,
        }
    ) then
        if SpellStopCasting then
            SpellStopCasting()
            return true
        end
    end

    if try_drain_life_defensive(me, target) then return true end
    if defensive_manager.try_defensive(me, "warlock", utils) then
        return
    end

    -- Threat fade protection - don't pull aggro from tank
    if me:is_in_combat() then
        local current_target = me:get_target()
        local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
        if ok and should_fade and dps_risk.should_drop_threat(dps_runtime.build_snapshot(me, current_target, encounter_manager, ttd_tracker)) then
            pcall(function() threat_manager.try_fade(me) end)
            return
        end
    end
    
    local effective_mode = get_effective_mode()
    local profile = get_profile()
    local nearby_snapshot = get_nearby_hostiles_snapshot(me, target, 12)
    local enemy_count = count_close_hostiles(me, 12, nearby_snapshot)

    if try_summon_correct_pet(me, effective_mode) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.04) and try_fel_armor(me) then
        return
    end
    if ctx and resource_gate.common.has_mana_pct(ctx, set_adjusted_mana_pct(0.18, 1.05)) and try_seed_of_corruption(me, target, enemy_count, nearby_snapshot) then
        return
    end
    if ctx and resource_gate.common.has_mana_pct(ctx, set_adjusted_mana_pct(0.10, 1.00)) and try_shadowfury(me, target, nearby_snapshot) then
        return
    end
    if ctx and resource_gate.common.has_mana_pct(ctx, set_adjusted_mana_pct(0.08, 0.95)) and try_apply_curse(me, target, effective_mode) then
        return
    end
    if ctx and resource_gate.common.has_mana_pct(ctx, set_adjusted_mana_pct(0.12, 1.10)) and try_immolate(me, target) then
        return
    end
    if ctx and resource_gate.common.has_mana_pct(ctx, set_adjusted_mana_pct(0.12, 1.20)) then
        -- Execute phase: Drain Soul first (highest DPS), then Shadowburn, then Soul Fire
        if try_drain_soul(me, target) then
            return
        end
        if try_shadowburn(me, target) then
            return
        end
        if (not ctx.self) or (not ctx.self.soul_shards) or ctx.self.soul_shards >= 1 then
            if try_soul_fire(me, target) then
                return
            end
        end
    end
    if profile == "fire" then
        if ctx and resource_gate.common.has_mana_pct(ctx, set_adjusted_mana_pct(0.10, 1.15)) and try_conflagrate(me, target, profile) then
            return
        end
        if ctx and resource_gate.common.has_mana_pct(ctx, set_adjusted_mana_pct(0.08, 1.10)) and try_nuke(me, target, profile) then
            return
        end
    else
        if ctx and resource_gate.common.has_mana_pct(ctx, set_adjusted_mana_pct(0.08, 1.05)) and try_nuke(me, target, profile) then
            return
        end
        if ctx and resource_gate.common.has_mana_pct(ctx, set_adjusted_mana_pct(0.10, 1.15)) and try_conflagrate(me, target, profile) then
            return
        end
    end
    if try_soul_shard_farm(me, target, runtime.drain_soul_id) then
        return
    end
    try_life_tap(me, effective_mode)
end


reactive_adapter = {
    spec = "EAXWarlockDestruction",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "warlock", utils)
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

                -- FIXED: Added proper nil guard for menu.use_interrupt:get_state() (line 1320)
                return (menu.use_interrupt and menu.use_interrupt:get_state()) and interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "warlock", utils)
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
    -- FIXED: Added proper nil guard for menu.enabled:get_state() (line 1349)
    if not menu or not menu.enabled or not (menu.enabled and menu.enabled:get_state()) or false then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(function()
    if utils.throttle("mode_refresh", 5.0) then
        refresh_mode_cache()
    end
    if utils.throttle("set_bonus", 5.0) then
        update_set_bonus()
    end
    handle_toggle()
    -- FIXED: Added proper nil guard for menu.enabled:get_state() (line 1361)
    if not menu.enabled or not (menu.enabled and menu.enabled:get_state()) or false then
        return
    end
    local me = _get_local_player()
    if not me or me:is_dead() then
        return
    end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
        ooc_manager.on_update(me, menu, utils)
    -- FIXED: Added proper nil guard for menu.auto_ooc_food_drink:get_state() (line 1370)
    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    -- Warlock utility: healthstone, soulstone
    if try_create_healthstone(me) then return end
    if try_soulstone_dead_ally(me) then return end
    if try_self_soulstone(me) then return end
    if try_use_healthstone(me) then return end

    if me:is_in_combat() then
        -- FIXED: Added proper nil guard for menu.auto_combat_potions:get_state() (line 1381)
        if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
            consumables_manager.try_use_combat_consumable(me, menu, utils)
        end
        -- FIXED: Added proper nil guard for menu.auto_flask:get_state() (line 1384)
        if menu.auto_flask and menu.auto_flask:get_state() then
            consumables_manager.try_maintain_flask(me, menu, utils)
        end
    end

    if eax_utils.is_eating_or_drinking(me) then return end

    -- Pacify check: don't attempt to cast if pacified (e.g., Mechanar's Pacifying Dust)
    if utils.is_pacified(me) then return end

    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    local effective_mode = get_effective_mode()
    if not focus_target and try_summon_correct_pet(me, effective_mode) then return end
    local target = focus_target or utils.find_best_target(me)
    -- PvP: prioritize enemy players in arena/BG/world PvP
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
    if not target then return end

    if focus_target and focus_target:is_valid() then
        target = focus_target
    end

    -- PvP cooldowns: trinket, death coil, fear
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
        pvp_manager.try_warlock_pvp_cooldowns(me, target)
    end

    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxwarlockdestruction_space_win")
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
        local label = "Eax Warlock Dest] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxwarlockdestruction_enabled_cp")
        return elements
    end)
end


-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Warlock"
    local _eax_spec  = "Destruction"
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
core.log("[Eax Warlock Destruction] Loaded " .. (_pi and _pi.plugin_version or "?"))
