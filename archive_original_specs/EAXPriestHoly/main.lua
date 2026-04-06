-- Eax Priest Holy | main.lua
-- FIXED: Complete 6-step audit - API compliance, nil guards, rotation priority
-- Healing rotation that keeps Renew, Greater Heal, and Prayer of Healing prioritized.

local menu = require("libraries/menu")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local key_helper = require("common/utility/key_helper")
local control_panel_utility = require("common/utility/control_panel_helper")
local spells = require("libraries/spells")
local spell_downrank = require("libraries/spell_downrank")
local utils = require("libraries/utils")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end

-- Menu aliases for backward compatibility
if not menu.focus_pri and menu.focus_priority then menu.focus_pri = menu.focus_priority end

local eax_utils = require("libraries/eax_utils")
local color     = require("libraries/color")

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")

---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
local leveling_manager
local leveling_manager = require("libraries/leveling_manager")
---@type creature_utils
local creature_utils = require("libraries/creature_utils")

---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
local pvp_manager = require("libraries/pvp_manager")
local dispel_engine = require("libraries/dispel_engine")

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


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("pholy2", "Priest Holy")
-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("libraries/smart_cast_manager")

-- Phase 04 visual telemetry wiring
local dps_meter = require("libraries/dps_meter")
local cooldown_tracker = require("libraries/cooldown_tracker")
local visual_state = require("libraries/visual_state")
local reactive_runtime = require("libraries/reactive_runtime")
local healer_triage = require("libraries/healer_triage")
local heal_engine = require("libraries/heal_engine")

-- ============================================================================
-- FLUX-INSPIRED HEALING SYSTEM (ported from Flux AIO)
-- ============================================================================

-- Hot-path local caching (performance critical) - MUST be defined before use
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_gcd = core.spell_book.get_global_cooldown
local _get_spell_cd = core.spell_book.get_spell_cooldown

-- Party/Raid unit IDs for precise target scanning
local PARTY_UNITS = {"player", "party1", "party2", "party3", "party4"}
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

-- Per-frame state cache (Flux pattern)
local holy_state = {
    lowest = nil,           -- lowest HP entry {unit, hp, effective_hp, is_player, is_tank}
    lowest_hp = 100,
    tank = nil,             -- tank entry
    group_damaged_count = 0,  -- count below threshold
    surge_of_light = false,
    clearcasting = false,
    pom_ready = false,
    coh_ready = false,
    inner_focus_ready = false,
    last_scan_frame = 0,
}

-- ============================================================================
-- EFFECTIVE HP PREDICTION (accounts for incoming heals, HoTs, absorbs)
-- ============================================================================

-- Check if unit has aggro (for damage prediction)
local function unit_has_aggro(unit_obj)
    -- In Sylvanas, check if unit is tanking using threat table or role
    -- For now, use group role as proxy for aggro detection
    if unit_obj and unit_obj.get_group_role then
        local ok, role = pcall(function() return unit_obj:get_group_role() end)
        if ok and role == 0 then  -- TANK role
            return true
        end
    end
    return false
end

-- Predict effective HP after cast_time_seconds
-- Uses Sylvanas game_object methods
-- Returns: effective_deficit (health missing after predictions)
local function predict_effective_deficit(unit_obj, cast_time_seconds)
    if not unit_obj or not unit_obj:is_valid() then return 0 end
    
    local max_hp = 1
    local current_hp = 1
    local ok, result = pcall(function() return unit_obj:get_max_health() end)
    if ok and result then max_hp = result end
    ok, result = pcall(function() return unit_obj:get_health() end)
    if ok and result then current_hp = result end
    
    if max_hp <= 0 then return 0 end
    
    local current_deficit = max_hp - current_hp
    
    -- Subtract incoming heals (from other healers) - not available in Sylvanas, set to 0
    local incoming_heals = 0
    -- Estimate from effective HP vs raw HP
    local raw_hp_pct = utils.get_health_pct(unit_obj)
    local effective_hp_pct = heal_engine.get_effective_hp_pct(unit_obj)
    incoming_heals = math.max(0, (raw_hp_pct - effective_hp_pct) / 100 * max_hp)
    
    -- Subtract HoT ticks we'll receive during cast time
    -- Simplified: assume Renew healing during typical cast
    local hot_healing = 0
    local renew_remaining = utils.get_buff_remaining_ms(unit_obj, spells.RENEW) / 1000
    if renew_remaining > 0 then
        -- Estimate ~450 healing per tick
        hot_healing = math.min(renew_remaining, cast_time_seconds) * 300  -- ~300/sec from HoTs
    end
    
    -- Add expected damage (simplified: check if tank has aggro)
    local expected_damage = 0
    if unit_has_aggro(unit_obj) then
        -- Estimate damage during cast time
        expected_damage = cast_time_seconds * 200  -- ~200 dmg/sec tanking
    end
    
    local effective_deficit = current_deficit - incoming_heals - hot_healing + expected_damage
    return math.max(0, effective_deficit)
end

-- Get effective HP percentage (Flux pattern)
local function get_effective_hp_pct(unit_obj)
    if not unit_obj or not unit_obj:is_valid() then return 100 end
    
    local max_hp = 1
    local ok, result = pcall(function() return unit_obj:get_max_health() end)
    if ok and result then max_hp = result end
    
    if max_hp <= 0 then return 100 end
    
    -- Predict effective HP 1.5 seconds from now (typical cast time)
    local deficit = predict_effective_deficit(unit_obj, 1.5)
    local effective_hp = ((max_hp - deficit) / max_hp) * 100
    return math.max(0, effective_hp)
end

-- ============================================================================
-- PARTY HEALING TARGET SCANNER (Flux pattern)
-- ============================================================================

local healing_targets = {}
local healing_targets_count = 0

-- Pre-allocate entries
for i = 1, 40 do healing_targets[i] = {} end

local function is_in_raid()
    -- In Sylvanas, we check if we have raid members beyond party size
    local objects = core.object_manager.get_all_objects()
    local raid_count = 0
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and obj:is_party_member() then
            raid_count = raid_count + 1
            if raid_count > 5 then
                return true
            end
        end
    end
    return false
end

local function is_in_party()
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and obj:is_party_member() then
            return true
        end
    end
    return false
end

-- Scan party/raid and return sorted targets (lowest effective HP first)
-- Uses Sylvanas API: core.object_manager.get_all_objects() and game_object methods
local function scan_healing_targets()
    local now = _core_time()
    
    -- Once-per-frame cache
    if now == holy_state.last_scan_frame and healing_targets_count > 0 then
        return healing_targets, healing_targets_count
    end
    holy_state.last_scan_frame = now
    
    healing_targets_count = 0
    
    -- Get all objects and filter for party members (Sylvanas API pattern)
    local objects = core.object_manager.get_all_objects()
    local me = core.object_manager.get_local_player()
    
    -- Get player position for range checks
    local pos_me = nil
    if me and me:is_valid() then
        local ok, pos = pcall(function() return me:get_position() end)
        if ok then pos_me = pos end
    end
    
    for i = 1, #objects do
        local obj = objects[i]
        -- Check if valid unit, not dead, and is party member (or self)
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            if obj == me or obj:is_party_member() then
                -- Range check: 40 yards for healing
                local in_range = false
                if obj == me then
                    in_range = true
                elseif pos_me then
                    local ok_pos, pos_obj = pcall(function() return obj:get_position() end)
                    if ok_pos and pos_obj then
                        local dx = pos_me.x - pos_obj.x
                        local dy = pos_me.y - pos_obj.y
                        local dz = pos_me.z - pos_obj.z
                        local dist_sq = dx*dx + dy*dy + dz*dz
                        in_range = dist_sq <= (40 * 40)
                    else
                        in_range = true -- Include if position unavailable
                    end
                else
                    in_range = true -- Include if no position data
                end
                
                if in_range then
                    healing_targets_count = healing_targets_count + 1
                    local entry = healing_targets[healing_targets_count]
                    if not entry then
                        entry = {}
                        healing_targets[healing_targets_count] = entry
                    end
                    
                    entry.unit_obj = obj
                    entry.is_player = (obj == me)
                    
                    -- Get health using Sylvanas game_object methods
                    local max_hp = 1
                    local current_hp = 1
                    local ok, result = pcall(function() return obj:get_max_health() end)
                    if ok and result then max_hp = result end
                    ok, result = pcall(function() return obj:get_health() end)
                    if ok and result then current_hp = result end
                    
                    entry.max_hp = max_hp
                    entry.hp = max_hp > 0 and (current_hp / max_hp) * 100 or 100
                    
                    -- Calculate effective HP (Flux pattern)
                    -- FIX: predict_effective_deficit returns (unit_obj, effective_pct)
                    local _, effective_pct = predict_effective_deficit(obj, 1.5)
                    entry.effective_hp = effective_pct or entry.hp
                    entry.effective_hp = math.max(0, math.min(100, entry.effective_hp))
                    
                    -- Check for existing HoTs/buffs
                    entry.has_renew = utils.has_buff(obj, spells.RENEW)
                    entry.has_pws = utils.has_buff(obj, spells.BUFF_POWER_WORD_SHIELD)
                    entry.has_weakened_soul = utils.has_debuff(obj, spells.BUFF_WEAKENED_SOUL)
                    
                    -- Role detection (tank has aggro)
                    entry.has_aggro = unit_has_aggro(obj)
                    entry.is_tank = entry.has_aggro
                end
            end
        end
    end
    
    -- Sort by effective HP (lowest first)
    if healing_targets_count > 1 then
        table.sort(healing_targets, function(a, b)
            if not a or not a.effective_hp then return false end
            if not b or not b.effective_hp then return true end
            return a.effective_hp < b.effective_hp
        end)
    end
    
    return healing_targets, healing_targets_count
end

-- Get lowest HP target below threshold
local function get_lowest_hp_target(threshold)
    threshold = threshold or 100
    for i = 1, healing_targets_count do
        local entry = healing_targets[i]
        if entry and entry.effective_hp < threshold then
            return entry
        end
    end
    return nil
end

-- Count targets below HP threshold
local function count_below_hp(threshold)
    threshold = threshold or 100
    local count = 0
    for i = 1, healing_targets_count do
        local entry = healing_targets[i]
        if entry and entry.effective_hp < threshold then
            count = count + 1
        end
    end
    return count
end

-- Get tank target
local function get_tank_target()
    for i = 1, healing_targets_count do
        local entry = healing_targets[i]
        if entry and entry.is_tank then
            return entry
        end
    end
    return nil
end

-- Update holy_state from scanned targets
local function update_holy_state()
    local targets, count = scan_healing_targets()
    
    holy_state.lowest = (count > 0) and targets[1] or nil
    holy_state.lowest_hp = holy_state.lowest and holy_state.lowest.effective_hp or 100
    holy_state.tank = get_tank_target()
    holy_state.group_damaged_count = count_below_hp(80)  -- configurable threshold
    
    return holy_state
end

-- ============================================================================
-- OFF-GCD ABILITY FLAGS
-- ============================================================================

-- MOVED: check_offgcd_abilities function is now at line ~560 (after resolved table)

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
    -- FIXED: Use is_dead() instead of is_dead_or_ghost()
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
    -- FIXED: Use is_dead() instead of is_dead_or_ghost()
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
        spec = "EAXPriestHoly",
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
    -- FIXED: Proper nil guard
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    local me = _get_local_player()
    if not me or me:is_dead() then return end
    local target = me:get_target()
    visual_update_snapshot(me, target)
end)
---@type racial_manager
local racial_manager = require("libraries/racial_manager")
---@type defensive_manager
local defensive_manager = require("libraries/defensive_manager")

---@type mana_conservator
local mana_conservator = require("libraries/mana_conservator")
---@type threat_manager
local threat_manager = require("libraries/threat_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type ttd_tracker
local ttd_tracker = require("libraries/ttd_tracker")

local runtime = {
    last_cast_time = 0,
    resurrection_id = nil,
    mode_cache = "solo",
    last_mode_check = 0,
    last_mode_log = nil,
    set_multiplier = 1.0,
    last_set_check = 0,
    spiritual_guidance_active = false,
}

local ctx_cache = rotation_context.new({})

local resolved = {
    inner_focus = utils.resolve_spell_id(spells.INNER_FOCUS),
    shield = utils.resolve_spell_id(spells.POWER_WORD_SHIELD),  -- FIX: Added missing shield
    renew = utils.resolve_spell_id(spells.RENEW),
    flash_heal = utils.resolve_spell_id(spells.FLASH_HEAL),
    greater_heal = utils.resolve_spell_id(spells.GREATER_HEAL),
    binding_heal = utils.resolve_spell_id(spells.BINDING_HEAL),
    prayer_of_healing = utils.resolve_spell_id(spells.PRAYER_OF_HEALING),
    prayer_of_mending = utils.resolve_spell_id(spells.PRAYER_OF_MENDING),
    circle_of_healing = utils.resolve_spell_id(spells.CIRCLE_OF_HEALING),
    dispel_magic = utils.resolve_spell_id(spells.DISPEL_MAGIC),
    abolish_disease = utils.resolve_spell_id(spells.ABOLISH_DISEASE),
    cure_disease = utils.resolve_spell_id(spells.CURE_DISEASE),
    holy_nova = utils.resolve_spell_id(spells.HOLY_NOVA),  -- Added
    lightwell = utils.resolve_spell_id(spells.LIGHTWELL),  -- Added
    smite = utils.resolve_spell_id(spells.SMITE),  -- FIX: Added for Surge of Light
    ooc_power_word_fortitude_id = nil,
    ooc_divine_spirit_id = nil,
    ooc_shadow_protection_id = nil,
}

resolved.ooc_power_word_fortitude_id = utils.resolve_spell_id(spells.POWER_WORD_FORTITUDE)
resolved.ooc_divine_spirit_id = utils.resolve_spell_id(spells.DIVINE_SPIRIT)
resolved.ooc_shadow_protection_id = utils.resolve_spell_id(spells.SHADOW_PROTECTION)

-- OFF-GCD ABILITY FLAGS (defined here to access resolved table)
local function check_offgcd_abilities(me)
    -- Use resolved spell IDs (single number) instead of spell tables
    holy_state.inner_focus_ready = resolved.inner_focus and core.spell_book.is_spell_learned(resolved.inner_focus) and _get_spell_cd(resolved.inner_focus) == 0
    holy_state.surge_of_light = utils.has_buff(me, spells.BUFF_SURGE_OF_LIGHT)
    holy_state.clearcasting = utils.has_buff(me, spells.BUFF_CLEARCASTING)
    holy_state.pom_ready = resolved.prayer_of_mending and _get_spell_cd(resolved.prayer_of_mending) == 0
    holy_state.coh_ready = resolved.circle_of_healing and _get_spell_cd(resolved.circle_of_healing) == 0
end

local function log_mode(mode)
    -- FIXED: Proper nil guard
    if menu.debug and menu.debug:get_state() and runtime.last_mode_log ~= mode then
        utils.log_debug(menu, "Mode=" .. mode)
        runtime.last_mode_log = mode
    end
end

local SET_UPDATE_INTERVAL_MS = 5000
local PRIEST_SET_NAMES = { "Vestments", "Absolution", "AbsolutionRegalia" }

local function update_set_bonus(me)
    local now = core.game_time()
    if not runtime.last_set_check or (now - runtime.last_set_check) >= SET_UPDATE_INTERVAL_MS then
        runtime.last_set_check = now
        local best_multiplier = 1.0
        for _, set_name in ipairs(PRIEST_SET_NAMES) do
            local mult = utils.get_set_multiplier(me, set_name)
            if mult > best_multiplier then
                best_multiplier = mult
            end
        end
        runtime.set_multiplier = best_multiplier
    end
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

local function is_tank_unit(unit)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return false
    end
    if unit.get_group_role then
        local ok, role_id = pcall(function() return unit:get_group_role() end)
        if ok and role_id == 0 then
            return true
        end
    end
    if unit.get_class then
        local ok, class_name = pcall(function() return string.lower(unit:get_class() or "") end)
        if ok and (class_name == "warrior" or class_name == "paladin" or class_name == "druid") then
            return true
        end
    end
    return false
end

local function has_urgent_direct_heal_target(me)
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    if heal_engine.get_effective_hp_pct(me) < self_threshold then
        return true
    end

    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() and not focus_target:is_dead() then
        -- FIXED: Proper nil guard
        if heal_engine.get_effective_hp_pct(focus_target) < ((menu.flash_heal_hp_pct and menu.flash_heal_hp_pct:get()) or 70) / 100 then
            return true
        end
    end

    -- FIXED: Proper nil guard
    local tank_threshold = ((menu.greater_heal_hp_pct and menu.greater_heal_hp_pct:get()) or 60) / 100
    local units = utils.get_party_units(me)
    for i = 1, #units do
        local unit = units[i]
        if unit and unit:is_valid() and not unit:is_dead() and is_tank_unit(unit) then
            if heal_engine.get_effective_hp_pct(unit) < tank_threshold then
                return true
            end
        end
    end

    return false
end

-- Helper: find ally with lowest effective HP (ignores threshold, just finds lowest)
local function find_lowest_effective_ally(me, threshold, skip_self)
    local units = utils.get_party_units(me)
    local candidate = nil
    local lowest_pct = 1.0  -- Start at 100%, find anyone below this

    if not skip_self and me and me:is_valid() and not me:is_dead() then
        local self_pct = heal_engine.get_effective_hp_pct(me)
        if self_pct < lowest_pct then
            candidate = me
            lowest_pct = self_pct
        end
    end

    for i = 1, #units do
        local unit = units[i]
        if unit and unit:is_valid() and not unit:is_dead() and unit ~= me then
            local pct = heal_engine.get_effective_hp_pct(unit)
            if pct < lowest_pct then
                candidate = unit
                lowest_pct = pct
            end
        end
    end

    return candidate
end

local function try_renew(me)
    if not resolved.renew then
        return false
    end

    -- FIXED: Proper nil guard
    local threshold = (menu.renew_threshold and menu.renew_threshold:get() or 50) / 100
    -- FIXED: Proper nil guard
    local window_ms = (menu.renew_refresh_seconds and menu.renew_refresh_seconds:get() or 3) * 1000
    local units = utils.get_party_units(me)
    local candidate = nil
    local lowest_pct = threshold

    for i = 1, #units do
        local unit = units[i]
        if unit then
            local pct = heal_engine.get_effective_hp_pct(unit)
            if pct <= threshold and pct <= lowest_pct then
                local remaining = utils.get_buff_remaining_ms(unit, spells.RENEW)
                local renew_refresh_ms = math.max(3000, window_ms)
                if remaining <= renew_refresh_ms and remaining > 0 then
                    candidate = unit
                    lowest_pct = pct
                end
            end
        end
    end

    if not candidate then
        candidate = find_lowest_effective_ally(me, threshold, true)
    end

    if candidate and not utils.has_buff(candidate, spells.RENEW) then
        esp_renderer.on_cast(nil, "Renew", color.green(220))
    if utils.cast_target(resolved.renew, me, candidate) then note_cast() return true end
    return false
    end

    return false
end

local function try_inner_focus(me)
    -- FIXED: Proper nil guard
    if not (menu.use_inner_focus and menu.use_inner_focus:get_state()) then
        return false
    end
    if not resolved.inner_focus then return false end
    if utils.has_buff(me, spells.INNER_FOCUS) then return false end
    if not utils.can_cast_self(resolved.inner_focus, me) then return false end
    if utils.cast_self(resolved.inner_focus, me) then note_cast() return true end
    return false
end

local function unit_guid(unit)
    if not unit or not unit.get_guid then
        return nil
    end
    local ok, guid = pcall(function() return unit:get_guid() end)
    if ok and guid ~= nil then
        return tostring(guid)
    end
    return nil
end

local function unit_incoming_heal_pct(unit)
    -- FIXED: Use heal_engine instead of unit.get_incoming_heals (not in valid API)
    if not unit or not unit:is_valid() then
        return 0
    end
    -- Estimate from effective HP vs raw HP
    local raw_hp = utils.get_health_pct(unit)
    local effective_hp = heal_engine.get_effective_hp_pct(unit)
    return math.max(0, raw_hp - effective_hp)
end

local function build_triage_members(me)
    local members = {}
    local self_member = heal_engine.make_member(me, {
        guid = unit_guid(me) or "self",
        role = "healer",
        is_tank = false,
    })
    if self_member then
        members[#members + 1] = self_member
    end
    local seen = { [unit_guid(me) or "self"] = true }
    local units = utils.get_party_units(me)
    for i = 1, #units do
        local unit = units[i]
        if unit and unit:is_valid() and not unit:is_dead() then
            local guid = unit_guid(unit) or ("party-" .. i)
            if not seen[guid] then
                seen[guid] = true
                local is_tank = is_tank_unit(unit)
                local member = heal_engine.make_member(unit, {
                    guid = guid,
                    role = is_tank and "tank" or "damager",
                    is_tank = is_tank,
                })
                if member then
                    members[#members + 1] = member
                end
            end
        end
    end
    return members
end

local function try_prayer_of_healing(me)
    if not resolved.prayer_of_healing or not (menu.prayer_of_healing_enabled and menu.prayer_of_healing_enabled:get_state()) then
        return false
    end

    -- FIXED: Proper nil guard
    local threshold = (menu.prayer_of_healing_threshold and menu.prayer_of_healing_threshold:get() or 40) / 100
    local count = 0
    local units = utils.get_party_units(me)
    local missing = 0

    for i = 1, #units do
        local unit = units[i]
        if unit and heal_engine.get_effective_hp_pct(unit) <= threshold then
            count = count + 1
            missing = missing + math.max(0, threshold - heal_engine.get_effective_hp_pct(unit))
        end
    end

    -- FIXED: Proper nil guard
    if count >= (menu.prayer_of_healing_count and menu.prayer_of_healing_count:get() or 3) and missing >= 0.14 and not has_urgent_direct_heal_target(me) then
        -- FIXED: Proper nil guard
        if menu.use_cooldowns and menu.use_cooldowns:get_state() then
            if try_inner_focus(me) then
                return true
            end
        end
        esp_renderer.on_cast(nil, "Prayer of Healing", color.cyan(220))
        local mana_pct = utils.get_mana_pct(me)
        local spell_id = spell_downrank.select_heal_rank(spells.PRAYER_OF_HEALING, threshold, mana_pct, {
            emergency_hp_threshold = 0.45,
            sustain_hp_threshold = 0.75,
            mana_threshold = 0.25,
            emergency_rank_index = 1,
            sustain_rank_index = 2,
            efficient_rank_index = 3,
        }) or resolved.prayer_of_healing
        if utils.cast_self(spell_id, me) then
            note_cast()
            return true
        end
        return false
    end

    return false
end

local function resolve_reactive_triage(me)
    local summary = healer_triage.select_target(me, build_triage_members(me), {})
    if not summary or not summary.target or not summary.target.is_valid or not summary.target:is_valid() then
        return nil, nil
    end
    return summary, summary.target
end

local MAGIC_DISPEL_TYPE = 1
local DISEASE_DISPEL_TYPE = 3

local function get_dispel_target(me)
    local candidates = { me }
    local party_units = utils.get_party_units(me)
    for i = 1, #party_units do
        candidates[#candidates + 1] = party_units[i]
    end
    local current = me and me.get_target and me:get_target() or nil
    local best_target = select(1, dispel_engine.find_best_target({
        candidates = candidates,
        preferred_target = current,
        priorities = {
            { type_def = { numeric = MAGIC_DISPEL_TYPE, name = "magic" }, label = "Dispel Magic" },
            { type_def = { numeric = DISEASE_DISPEL_TYPE, name = "disease" }, label = "Disease" },
        },
        get_hp = function(unit) return heal_engine.get_effective_hp_pct(unit) end,
    }))
    if best_target then return best_target end
    local _, triage_target = resolve_reactive_triage(me)
    return triage_target
end

local function try_dispel_magic(me)
    -- FIXED: Proper nil guard
    if not resolved.dispel_magic or not (menu.use_dispels and menu.use_dispels:get_state()) then
        return false
    end
    local target = get_dispel_target(me)
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not dispel_engine.unit_has_type(target, { numeric = MAGIC_DISPEL_TYPE, name = "magic" }, nil) then return false end
    return utils.cast_target(resolved.dispel_magic, me, target) and true or false
end

local function try_cure_disease(me)
    -- FIXED: Proper nil guard
    if not (menu.use_dispels and menu.use_dispels:get_state()) then
        return false
    end
    local target = get_dispel_target(me)
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not dispel_engine.unit_has_type(target, { numeric = DISEASE_DISPEL_TYPE, name = "disease" }, nil) then return false end

    local spell_id = resolved.abolish_disease or resolved.cure_disease
    if not spell_id then return false end
    return utils.cast_target(spell_id, me, target) and true or false
end

local function try_greater_heal(me)
    if not resolved.greater_heal then
        return false
    end

    -- FIXED: Proper nil guard
    local threshold = (menu.greater_heal_hp_pct and menu.greater_heal_hp_pct:get() or 60) / 100
    local candidate = find_lowest_effective_ally(me, threshold, true)

    if candidate then
        local hp_pct = heal_engine.get_effective_hp_pct(candidate)
        local mana_pct = utils.get_mana_pct(me)
        local spell_id = spell_downrank.select_heal_rank(spells.GREATER_HEAL, hp_pct, mana_pct, {
            emergency_hp_threshold = 0.45,
            sustain_hp_threshold = 0.72,
            mana_threshold = 0.28,
            emergency_rank_index = 1,
            sustain_rank_index = 2,
            efficient_rank_index = 4,
        }) or resolved.greater_heal
        esp_renderer.on_cast(nil, "Greater Heal", color.gold(220))
    if utils.cast_target(spell_id, me, candidate) then 
        note_cast() 
        return true 
    end
    -- FIXED: Proper nil guard
    if menu.debug and menu.debug:get_state() then
        utils.log_debug(menu, "Flash Heal: cast_target failed")
    end
    return false
    end

    return false
end

-- Helper: analyze group damage profile for Prayer of Mending decision
local function get_group_damage_profile(me, threshold)
    local units = utils.get_party_units(me)
    local wounded = 0
    local missing = 0
    for i = 1, #units do
        local unit = units[i]
        if unit and unit:is_valid() and not unit:is_dead() then
            local hp = heal_engine.get_effective_hp_pct(unit)
            if hp <= threshold then
                wounded = wounded + 1
                missing = missing + math.max(0, threshold - hp)
            end
        end
    end
    return wounded, missing
end

local function try_prayer_of_mending(me)
    if not resolved.prayer_of_mending or not (menu.use_prayer_of_mending and menu.use_prayer_of_mending:get_state()) then
        return false
    end

    -- FIXED: Proper nil guard
    local threshold = (menu.prayer_of_mending_threshold and menu.prayer_of_mending_threshold:get() or 80) / 100
    if has_urgent_direct_heal_target(me) then
        return false
    end
    local wounded, missing = get_group_damage_profile(me, threshold)
    if wounded < 2 and missing < 0.12 then
        return false
    end
    local candidate = find_lowest_effective_ally(me, threshold, true)

    if candidate and not utils.has_buff(candidate, spells.BUFF_PRAYER_OF_MENDING) then
        if utils.cast_target(resolved.prayer_of_mending, me, candidate) then note_cast() return true end
    end

    return false
end

-- FIXED: Circle of Healing on CD priority per README
local function try_circle_of_healing(me)
    if not resolved.circle_of_healing then return false end
    -- FIXED: Proper nil guard
    if not (menu.circle_of_healing_enabled and menu.circle_of_healing_enabled:get_state()) then return false end

    -- FIXED: Proper nil guard
    local threshold = (menu.circle_of_healing_threshold and menu.circle_of_healing_threshold:get() or 80) / 100
    -- FIXED: Proper nil guard
    local min_count = (menu.circle_of_healing_count and menu.circle_of_healing_count:get() or 3)
    if has_urgent_direct_heal_target(me) then return false end

    local units = utils.get_party_units(me)
    local wounded = 0
    local best_target = nil
    local best_hp = 1.0
    local missing = 0

    for _, unit in ipairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local hp = heal_engine.get_effective_hp_pct(unit)
            if hp <= threshold then
                wounded = wounded + 1
                missing = missing + math.max(0, threshold - hp)
                if hp < best_hp then
                    best_hp = hp
                    best_target = unit
                end
            end
        end
    end

    if wounded < min_count or missing < 0.10 then return false end
    if not best_target then return false end

    if utils.cast_target(resolved.circle_of_healing, me, best_target) then
        note_cast()
        esp_renderer.on_cast(resolved.circle_of_healing, "Circle of Healing", color.green(220))
        return true
    end
    return false
end

local function get_normalized_hp(unit)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return 1.0
    end
    return heal_engine.get_effective_hp_pct(unit)
end

local function find_lowest_effective_ally(me, threshold, skip_self)
    local units = utils.get_party_units(me)
    local candidate = nil
    local lowest_pct = 1.0  -- Start at 100%, find lowest regardless of threshold

    -- Check self first (unless skipped)
    if not skip_self and me and me:is_valid() and not me:is_dead() then
        local self_pct = heal_engine.get_effective_hp_pct(me)
        -- FIXED: Proper nil guard
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, string.format("find_lowest: [SELF] HP=%.1f%%", self_pct * 100))
        end
        if self_pct < lowest_pct then
            candidate = me
            lowest_pct = self_pct
        end
    end

    -- Check party members
    for i = 1, #units do
        local unit = units[i]
        if unit and unit:is_valid() and not unit:is_dead() and unit ~= me then
            local pct = heal_engine.get_effective_hp_pct(unit)
            -- FIXED: Proper nil guard
            if menu.debug and menu.debug:get_state() then
                utils.log_debug(menu, string.format("find_lowest: [ALLY-%d] HP=%.1f%%", i, pct * 100))
            end
            if pct < lowest_pct then
                candidate = unit
                lowest_pct = pct
            end
        end
    end

    -- FIXED: Proper nil guard
    if menu.debug and menu.debug:get_state() then
        if candidate then
            local is_self = (candidate == me)
            utils.log_debug(menu, string.format("find_lowest: WINNER is %s with HP=%.1f%%", is_self and "SELF" or "ALLY", lowest_pct * 100))
        else
            utils.log_debug(menu, "find_lowest: NO CANDIDATE FOUND")
        end
    end

    return candidate
end

local function get_lowest_effective_party_unit(me, threshold)
    local units = utils.get_party_units(me)
    local candidate = nil
    local lowest_pct = threshold or 1.0

    if me and me:is_valid() and not me:is_dead() then
        local self_pct = heal_engine.get_effective_hp_pct(me)
        if self_pct <= lowest_pct then
            candidate = me
            lowest_pct = self_pct
        end
    end

    for i = 1, #units do
        local unit = units[i]
        if unit and unit:is_valid() and not unit:is_dead() and unit ~= me then
            local pct = heal_engine.get_effective_hp_pct(unit)
            if pct <= lowest_pct then
                candidate = unit
                lowest_pct = pct
            end
        end
    end

    return candidate
end

local function select_flash_heal_id(target_hp_pct, mana_pct)
    return spell_downrank.select_heal_rank(spells.FLASH_HEAL, target_hp_pct, mana_pct, {
        emergency_hp_threshold = 0.30,
        sustain_hp_threshold = 0.55,
        mana_threshold = 0.28,
        emergency_rank_index = 1,
        sustain_rank_index = 2,
        efficient_rank_index = 4,
    }) or resolved.flash_heal
end

local function try_flash_heal(me, target)
    if not resolved.flash_heal then
        -- FIXED: Proper nil guard
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, "Flash Heal: resolved.flash_heal is nil!")
        end
        return false
    end

    -- FIXED: Proper nil guard
    local threshold = (menu.flash_heal_hp_pct and menu.flash_heal_hp_pct:get() or 70) / 100
    local candidate = target
    
    -- If no target specified, find the lowest HP ally (including self)
    if not candidate then
        candidate = find_lowest_effective_ally(me, threshold, false)  -- false = include self
    end
    
    if not candidate or not candidate:is_valid() or candidate:is_dead() then
        -- FIXED: Proper nil guard
        if menu.debug and menu.debug:get_state() then
            local valid = candidate and candidate:is_valid()
            local dead = candidate and candidate:is_dead()
            utils.log_debug(menu, string.format("Flash Heal: no valid candidate (valid=%s, dead=%s)", tostring(valid), tostring(dead)))
        end
        return false
    end

    local hp_pct = get_normalized_hp(candidate)
    if hp_pct > threshold then
        -- FIXED: Proper nil guard
        if menu.debug and menu.debug:get_state() then
            utils.log_debug(menu, string.format("Flash Heal: %s HP %.1f%% > threshold %.1f%%", candidate == me and "SELF" or "ALLY", hp_pct * 100, threshold * 100))
        end
        return false
    end

    local spell_id = select_flash_heal_id(hp_pct, utils.get_mana_pct(me))
    esp_renderer.on_cast(spell_id, "Flash Heal", color.yellow(220))
    if candidate == me then
        if utils.cast_self(spell_id, me) then note_cast() return true end
        return false
    end
    local success, reason = utils.cast_target(spell_id, me, candidate)
    if success then 
        note_cast() 
        return true 
    end
    -- FIXED: Proper nil guard
    if menu.debug and menu.debug:get_state() then
        utils.log_debug(menu, "Flash Heal: cast_target failed - " .. tostring(reason))
    end
    return false
end

local function try_binding_heal(me, target)
    if not resolved.binding_heal or not (menu.binding_heal_enabled and menu.binding_heal_enabled:get_state()) then
        return false
    end

    local self_hp = get_normalized_hp(me)
    -- FIXED: Proper nil guard
    local self_threshold = (menu.binding_heal_self_threshold and menu.binding_heal_self_threshold:get() or 40) / 100
    if self_hp > self_threshold then
        return false
    end

    -- FIXED: Proper nil guard
    local target_threshold = (menu.binding_heal_target_threshold and menu.binding_heal_target_threshold:get() or 40) / 100
    local candidate = target
    if candidate == me then
        candidate = nil
    end
    if not candidate then
        candidate = find_lowest_effective_ally(me, target_threshold, true)
    end
    if not candidate or not candidate:is_valid() or candidate:is_dead() or candidate == me then
        return false
    end

    local target_hp = get_normalized_hp(candidate)
    if target_hp > target_threshold then
        return false
    end

    local combined_hp = math.min(self_hp, target_hp)
    local spell_id = spell_downrank.select_heal_rank(spells.BINDING_HEAL, combined_hp, utils.get_mana_pct(me), {
        emergency_hp_threshold = 0.35,
        sustain_hp_threshold = 0.70,
        mana_threshold = 0.25,
        emergency_rank_index = 1,
        sustain_rank_index = 1,
        efficient_rank_index = 2,
    }) or resolved.binding_heal
    esp_renderer.on_cast(spell_id, "Binding Heal", color.cyan(220))
    if utils.cast_target(spell_id, me, candidate) then note_cast() return true end
    return false
end

local function try_surge_of_light(me)
    -- Surge of Light: free instant Smite when buff active
    -- FIXED: Proper nil guard
    if not (menu.use_smite and menu.use_smite:get_state()) then return false end
    if not resolved.smite then return false end
    if not me:is_in_combat() then return false end
    
    -- Check for Surge of Light buff
    if not utils.has_buff(me, spells.BUFF_SURGE_OF_LIGHT) then return false end
    
    -- Need a valid enemy target
    local target = me:get_target()
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    
    -- Cast free Smite (Surge of Light makes it instant and free)
    esp_renderer.on_cast(resolved.smite, "Surge of Light Smite", color.yellow(255))
    if utils.cast_target(resolved.smite, me, target) then note_cast() return true end
    return false
end

-- Holy Nova - instant AoE heal + damage (TBC Holy talent)
local function try_holy_nova(me)
    if not resolved.holy_nova then return false end
    -- FIXED: Proper nil guard
    if not (menu.use_holy_nova and menu.use_holy_nova:get_state()) then return false end
    
    -- FIXED: Proper nil guard
    local threshold = (menu.holy_aoe_hp and menu.holy_aoe_hp:get() or 80)
    -- FIXED: Proper nil guard
    local min_count = (menu.holy_aoe_count and menu.holy_aoe_count:get() or 3)
    
    -- Count wounded allies within range
    local wounded = 0
    local units = utils.get_party_units(me)
    
    for _, unit in ipairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local hp = utils.get_health_pct(unit)
            if hp < threshold then
                wounded = wounded + 1
            end
        end
    end
    
    -- Also count self
    local self_hp = utils.get_health_pct(me)
    if self_hp < threshold then
        wounded = wounded + 1
    end
    
    if wounded < min_count then return false end
    
    -- Holy Nova is self-cast AoE
    esp_renderer.on_cast(resolved.holy_nova, "Holy Nova", color.yellow(220))
    if utils.cast_self(resolved.holy_nova, me) then
        note_cast()
        return true
    end
    return false
end

-- Lightwell - place Lightwell for raid members to click
local function try_lightwell(me)
    if not resolved.lightwell then return false end
    -- FIXED: Proper nil guard
    if not (menu.use_lightwell and menu.use_lightwell:get_state()) then return false end
    
    -- Only cast if in combat and multiple allies are wounded
    if not me:is_in_combat() then return false end
    
    -- FIXED: Proper nil guard
    local threshold = (menu.lightwell_hp_pct and menu.lightwell_hp_pct:get() or 60)
    local min_count = 2
    
    -- Count wounded allies
    local wounded = 0
    local units = utils.get_party_units(me)
    
    for _, unit in ipairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local hp = utils.get_health_pct(unit)
            if hp < threshold then
                wounded = wounded + 1
            end
        end
    end
    
    if wounded < min_count then return false end
    
    -- Don't cast if Lightwell already exists nearby
    -- (Simplified check - in real implementation would scan for existing Lightwell object)
    
    -- Lightwell is self-cast
    esp_renderer.on_cast(resolved.lightwell, "Lightwell", color.gold(220))
    if utils.cast_self(resolved.lightwell, me) then
        note_cast()
        return true
    end
    return false
end

local function get_tank_unit(me)
    local units = utils.get_party_units(me)
    for i = 1, #units do
        local unit = units[i]
        if unit and unit:is_valid() and not unit:is_dead() and is_tank_unit(unit) then
            return unit
        end
    end
    return nil
end

local function try_prepull_pom(me)
    -- Pre-pull Prayer of Mending: cast before combat starts
    -- FIXED: Proper nil guard
    if not (menu.prepull_pom and menu.prepull_pom:get_state()) then return false end
    if not resolved.prayer_of_mending then return false end
    if me:is_in_combat() then return false end  -- Must be OOC
    
    -- CRITICAL FIX: Only cast pre-pull if someone is actually damaged (<95% HP)
    -- This prevents wasting mana casting on full HP targets
    local function is_damaged_target(unit)
        if not unit or not unit:is_valid() or unit:is_dead() then return false end
        local hp_pct = heal_engine.get_effective_hp_pct(unit) * 100
        return hp_pct < 95  -- Only consider damaged targets
    end
    
    -- Find tank first
    local tank = get_tank_unit(me)
    local candidate = nil
    
    -- Only use tank as candidate if tank exists AND is damaged
    if tank and is_damaged_target(tank) then
        candidate = tank
    end
    
    -- If no damaged tank, find lowest HP ally that is actually damaged
    if not candidate then
        candidate = find_lowest_effective_ally(me, 0.95, false)
        -- Double-check: if the "lowest" ally is still at 100% HP, don't cast
        if candidate and not is_damaged_target(candidate) then
            return false
        end
    end
    
    if not candidate then return false end
    
    -- Don't cast if already has Prayer of Mending buff
    if utils.has_buff(candidate, spells.BUFF_PRAYER_OF_MENDING) then return false end
    
    -- Check range
    if not core.spell_book.is_spell_in_range(resolved.prayer_of_mending, candidate, me) then return false end
    
    esp_renderer.on_cast(resolved.prayer_of_mending, "Pre-pull PoM", color.green(220))
    if utils.cast_target(resolved.prayer_of_mending, me, candidate) then note_cast() return true end
    return false
end

-- Pre-pull Renew: cast Renew on tank before combat starts
local function try_prepull_renew(me)
    -- FIXED: Proper nil guard
    if not (menu.holy_prepull_renew and menu.holy_prepull_renew:get_state()) then return false end
    if not resolved.renew then return false end
    if me:is_in_combat() then return false end  -- Must be OOC
    
    -- CRITICAL FIX: Only cast pre-pull if tank is actually damaged (<95% HP)
    local tank = get_tank_unit(me)
    if not tank or not tank:is_valid() or tank:is_dead() then return false end
    
    local hp_pct = heal_engine.get_effective_hp_pct(tank) * 100
    if hp_pct >= 95 then return false end  -- Skip if tank is full HP
    
    -- Don't cast if already has Renew
    if utils.has_buff(tank, spells.RENEW) then return false end
    
    -- Check range
    if not core.spell_book.is_spell_in_range(resolved.renew, tank, me) then return false end
    
    esp_renderer.on_cast(resolved.renew, "Pre-pull Renew", color.green(220))
    if utils.cast_target(resolved.renew, me, tank) then note_cast() return true end
    return false
end

-- --- try_cast_spell - generic target-cast helper for focus/self priority --
local function try_cast_spell(me, target, spell_id)
    if not spell_id then return false end
    if not target or not target:is_valid() then return false end
    -- FIXED: Proper nil guard
    if menu.use_cooldowns and menu.use_cooldowns:get_state() and spell_id == resolved.greater_heal then
        if try_inner_focus(me) then
            return true
        end
    end
    if target == me then
        if utils.can_cast_self(spell_id, me) then
            if utils.cast_self(spell_id, me) then
                note_cast()
                return true
            end
    return false
        end
    else
        if utils.can_cast_target(spell_id, me, target) then
            if utils.cast_target(spell_id, me, target) then
                note_cast()
                return true
            end
    return false
        end
    end
    return false
end

local function resolve_reactive_heal_target(me)
    local _, target = resolve_reactive_triage(me)
    return target
end

local function should_cancel_reactive_cast(me, target)
    if not eax_utils.should_stopcasting(me, menu) then
        return false
    end
    local summary = healer_triage.select_target(me, build_triage_members(me), {})
    local snapshot = heal_engine.make_snapshot(target or me, {
        collapse_risk = summary and summary.collapse_risk == true,
        group_count = summary and summary.group_count or 0,
        is_tank = summary and summary.is_tank == true,
    })
    return healer_triage.should_cancel_overheal(snapshot, {})
end

local function cancel_holy_overheal_cast(me, target)
    if not should_cancel_reactive_cast(me, target) then
        return false
    end

    if SpellStopCasting then
        SpellStopCasting()
        return true
    end

    return false
end

reactive_adapter = {
    spec = "EAXPriestHoly",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return try_flash_heal(action_deps.me, action_deps.me)
                    or try_cast_spell(action_deps.me, action_deps.me, resolved.greater_heal)
            end,
        },
        life_save_ally = {
            handler = function(action_ctx, action_deps)
                local summary, ally_target = resolve_reactive_triage(action_deps.me)
                if summary and summary.reason == "group_stabilize" and try_prayer_of_healing(action_deps.me) then
                    return true
                end
                ally_target = action_deps.target or ally_target
                if not ally_target or not ally_target:is_valid() then
                    return false
                end

                return try_binding_heal(action_deps.me, ally_target)
                    or try_flash_heal(action_deps.me, ally_target)
                    or try_cast_spell(action_deps.me, ally_target, resolved.greater_heal)
            end,
        },
        interrupt_control = { noop = "unsupported" },
        anti_overheal = {
            handler = function(_, action_deps)
                return cancel_holy_overheal_cast(action_deps.me, action_deps.current_target)
            end,
        },
        anti_aggro = {
            handler = function(_, action_deps)
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
    resolve_target = function(action_id, _, action_deps)
        if action_id == "life_save_self" then
            return action_deps.me
        end

        if action_id == "life_save_ally" then
            return resolve_reactive_heal_target(action_deps.me)
        end

        return nil
    end,
}

local function on_render()
    return
end

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    -- FIXED: Proper nil guard
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(function()
    -- FIXED: Proper nil guard
    if not menu or not (menu.enabled and menu.enabled:get_state()) then
        return
    end

    local me = _get_local_player()
    if not me or not me:is_valid() or me:is_dead() then
        return
    end
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end
    ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = resolved.ooc_power_word_fortitude_id,
               buff_ids = spells.BUFF_POWER_WORD_FORT,
               name = "Power Word: Fortitude",
               -- FIXED: Proper nil guard
               toggle = menu.ooc_group_buff and menu.ooc_group_buff or nil },
            { spell_id = resolved.ooc_divine_spirit_id,
               buff_ids = spells.BUFF_DIVINE_SPIRIT,
               name = "Divine Spirit",
               toggle = menu.ooc_group_buff and menu.ooc_group_buff or nil },
            { spell_id = resolved.ooc_shadow_protection_id,
               buff_ids = spells.BUFF_SHADOW_PROTECTION,
               name = "Shadow Protection",
               toggle = menu.ooc_group_buff and menu.ooc_group_buff or nil },
        },
    })
    -- FIXED: Proper nil guard
    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    -- Healing now works both in and out of combat
    local in_combat = me:is_in_combat()

    if in_combat then
        -- FIXED: Proper nil guard
        if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
            consumables_manager.try_use_combat_consumable(me, menu, utils)
        end
        -- FIXED: Proper nil guard
        if menu.auto_flask and menu.auto_flask:get_state() then
            consumables_manager.try_maintain_flask(me, menu, utils)
        end
    end

    if eax_utils.is_eating_or_drinking(me) then return end

    -- Pacify check: don't attempt to cast if pacified (e.g., Mechanar's Pacifying Dust)
    if utils.is_pacified(me) then return end

    update_set_bonus(me)

    local target = utils.find_best_target(me)
    -- PvP: prioritize enemy players in arena/BG/world PvP
    local pvp_instance = pvp_manager.is_in_pvp_instance()
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        local enemy_players = pvp_manager.find_enemy_players(me, 40)
        if #enemy_players > 0 then
            local priority = pvp_manager.priority_target(me, enemy_players)
            if priority then target = priority end
        end
    end

    if mana_conservator.on_update(me, target, menu, utils) then return end

    -- Overheal Protection - cancel slow heals if target is healthy
    if cancel_holy_overheal_cast(me, target) then
        return
    end

    -- Interrupt (PVP)
    if target and target:is_valid() and me:can_attack(target) and interrupt_manager.should_interrupt(target) then
        -- FIXED: Proper nil guard
        if menu.use_interrupt and menu.use_interrupt:get_state() and interrupt_manager.try_interrupt(me, target, "priest", utils) then
            return
        end
    end


    -- Wanding / mana conservation (leveling 1-70)
    if leveling_manager.try_wand(me, target, menu) then return true end
    if not leveling_manager.has_enough_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
        return false
    end
    -- Encounter policy (boss-specific rotation adjustments)
    local enc = encounter_manager.get_policy(me)

    -- Defensive abilities
    -- Racial abilities
    if racial_manager.try_offensive(me) then return true end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end

    if defensive_manager.try_defensive(me, "priest", utils) then
        return
    end

    if try_dispel_magic(me) then return end
    if try_cure_disease(me) then return end

    -- Threat fade protection - don't pull aggro from tank
    local current_target = me:get_target()
    local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
    if ok and should_fade then
        pcall(function() threat_manager.try_fade(me) end)
        return
    end

    ttd_tracker.update(target)

    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)
    
    -- Debug: Log party status
    -- FIXED: Proper nil guard
    if menu.debug and menu.debug:get_state() then
        local units = utils.get_party_units(me)
        local wounded_count = 0
        for i = 1, #units do
            local unit = units[i]
            if unit and unit:is_valid() and not unit:is_dead() then
                local hp = heal_engine.get_effective_hp_pct(unit) * 100
                if hp < 100 then
                    wounded_count = wounded_count + 1
                    utils.log_debug(menu, string.format("Party member %d: %.1f%% HP", i, hp))
                end
            end
        end
        utils.log_debug(menu, string.format("Party size: %d, Wounded: %d, ctx: %s", #units, wounded_count, tostring(ctx ~= nil)))
    end

    -- Focus Target Priority - heal focus target first
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target then
        local focus_hp = heal_engine.get_effective_hp_pct(focus_target) * 100
        -- FIXED: Proper nil guard
        if focus_hp < ((menu.flash_heal_hp_pct and menu.flash_heal_hp_pct:get()) or 70) then
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_flash_heal(me, focus_target) then
                return
            end
        -- FIXED: Proper nil guard
        elseif focus_hp < ((menu.greater_heal_hp_pct and menu.greater_heal_hp_pct:get()) or 60) then
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) and try_cast_spell(me, focus_target, resolved.greater_heal) then
                return
            end
        end
    end

    -- Combat-aware self HP threshold
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = heal_engine.get_effective_hp_pct(me)
    if my_hp < self_threshold then
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_flash_heal(me, me) then
            return
        end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) and try_cast_spell(me, me, resolved.greater_heal) then
            return
        end
    end

    local mode = utils.get_effective_mode(menu, runtime)
    log_mode(mode)
    
    -- ============================================================================
    -- FLUX-INSPIRED HEALING PRIORITY SYSTEM
    -- Order: [1] Emergency > [2] Instant > [3] HoTs > [4] Sustained > [5] Emergency
    -- ============================================================================
    
    -- Update healing state cache (once per frame)
    update_holy_state()
    check_offgcd_abilities(me)
    
    -- ============================================================================
    -- PRE-PULL (OOC) CASTING - Cast before combat starts
    -- ============================================================================
    if not me:is_in_combat() then
        -- Pre-pull Prayer of Mending
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) then
            if try_prepull_pom(me) then return end
        end
        
        -- Pre-pull Renew on tank
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) then
            if try_prepull_renew(me) then return end
        end
    end
    
    -- ============================================================================
    -- COMBAT ROTATION - Priority [1] to [12]
    -- ============================================================================
    
    -- [1] Emergency PW:S (instant shield on critically low target, <30%)
    -- FIXED: Proper nil guard
    local pws_emergency_threshold = (menu.holy_pws_hp and menu.holy_pws_hp:get() or 30)
    if holy_state.lowest and holy_state.lowest_hp < pws_emergency_threshold then
        if not holy_state.lowest.has_weakened_soul and not holy_state.lowest.has_pws then
            -- FIX: Use proper API instead of undefined A and PLAYER_UNIT
            if resolved.shield and _get_spell_cd(resolved.shield) == 0 then  -- Shield ready
                -- Check GCD using core API
                local gcd_ready = smart_cast_manager.is_gcd_ready()
                if gcd_ready then
                    esp_renderer.on_cast(resolved.shield, "EMERGENCY PW:S", color.white(220))
                    -- FIX: Use unit_obj directly instead of non-existent get_player_by_name
                    local target_unit = holy_state.lowest.unit_obj
                    if target_unit and utils.cast_target(resolved.shield, me, target_unit) then 
                        note_cast() 
                        return 
                    end
                end
            end
        end
    end
    
    -- [2] Emergency Flash Heal (critically low target, <30%)
    -- FIXED: Proper nil guard
    local emergency_threshold = (menu.holy_emergency_hp and menu.holy_emergency_hp:get() or 30)
    if holy_state.lowest and holy_state.lowest_hp < emergency_threshold then
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) then
            if try_flash_heal(me, holy_state.lowest.unit_obj) then return end
        end
    end
    
    -- Surge of Light: free instant Smite (only if no urgent healing needed)
    if holy_state.surge_of_light and me:is_in_combat() then
        local target = me:get_target()
        if target and target:is_valid() and me:can_attack(target) then
            -- FIXED: Proper nil guard
            local flash_threshold = (menu.flash_heal_hp_pct and menu.flash_heal_hp_pct:get() or 50)
            if holy_state.lowest_hp >= flash_threshold then
                if try_surge_of_light(me) then return end
            end
        end
    end
    
    -- [3] Clearcasting Greater Heal (free heal from Holy Concentration procs) - Priority after emergency
    if me:is_in_combat() and holy_state.clearcasting and holy_state.lowest then
        if holy_state.lowest_hp < 95 then
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) then
                if try_greater_heal(me, holy_state.lowest.unit_obj) then return end
            end
        end
    end
    
    -- [4] Prayer of Mending (instant, on CD - bouncing heal)
    if holy_state.pom_ready then
        local target = holy_state.tank or holy_state.lowest
        if target then
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) then
                if try_prayer_of_mending(me) then return end
            end
        end
    end
    
    -- FIXED: [5] Circle of Healing on CD priority per README
    if me:is_in_combat() and holy_state.coh_ready then
        -- FIXED: Proper nil guard
        local min_count = (menu.holy_aoe_count and menu.holy_aoe_count:get() or 3)
        if holy_state.group_damaged_count >= min_count then
            local target = holy_state.lowest or holy_state.tank
            if target and ctx and resource_gate.common.has_mana_pct(ctx, 0.14) then
                if try_circle_of_healing(me) then return end
            end
        end
    end
    
    -- [6] Holy Nova (instant AoE heal + damage, lower priority than CoH)
    if me:is_in_combat() and ctx and resource_gate.common.has_mana_pct(ctx, 0.12) then
        if try_holy_nova(me) then return end
    end
    
    -- [7] Prayer of Healing (channeled AoE heal, 3+ injured)
    -- FIXED: Proper nil guard
    if me:is_in_combat() and holy_state.group_damaged_count >= ((menu.holy_aoe_count and menu.holy_aoe_count:get()) or 3) then
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.18) then
            if try_prayer_of_healing(me) then return end
        end
    end
    
    -- [8] Lightwell (maintain uptime for raid members to click)
    if me:is_in_combat() and ctx and resource_gate.common.has_mana_pct(ctx, 0.25) then
        if try_lightwell(me) then return end
    end
    
    -- [9] Binding Heal (self + target both damaged)
    if me:is_in_combat() and holy_state.lowest and not holy_state.lowest.is_player then
        local self_hp = me:get_health_percentage()
        -- FIXED: Proper nil guard
        local binding_threshold = (menu.binding_heal_self_threshold and menu.binding_heal_self_threshold:get() or 80)
        if self_hp < binding_threshold and holy_state.lowest_hp < 80 then
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.14) then
                if try_binding_heal(me, holy_state.lowest.unit_obj) then return end
            end
        end
    end
    
    -- [10] Renew on tank (maintain HoT - 90% threshold, pre-pull capable)
    if holy_state.tank then
        -- FIXED: Proper nil guard
        local threshold = (menu.renew_threshold and menu.renew_threshold:get() or 90)
        -- FIX: Only cast Renew if tank is below threshold (respect pre-pull setting when OOC)
        if holy_state.tank.effective_hp < threshold then
            local in_combat = me:is_in_combat()
            -- FIXED: Proper nil guard
            if not in_combat and not (menu.holy_prepull_renew and menu.holy_prepull_renew:get_state()) then
                -- Skip OOC - pre-pull disabled
            else
                if not holy_state.tank.has_renew then
                    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) then
                        if try_renew(me, holy_state.tank.unit_obj) then return end
                    end
                end
            end
        end
    end
    
    -- [11] Renew on injured (HoT spread - 90% threshold, instant before cast-time)
    if me:is_in_combat() and holy_state.lowest then
        -- FIXED: Proper nil guard
        local threshold = (menu.renew_threshold and menu.renew_threshold:get() or 90)
        if holy_state.lowest_hp < threshold and not holy_state.lowest.has_renew then
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) then
                if try_renew(me, holy_state.lowest.unit_obj) then return end
            end
        end
    end
    
    -- [13] Inner Focus (off-GCD, fire before big heals)
    if me:is_in_combat() and holy_state.inner_focus_ready and not holy_state.has_inner_focus then
        -- FIXED: Proper nil guard
        if menu.use_cooldowns and menu.use_cooldowns:get_state() then
            -- FIXED: Proper nil guard
            if holy_state.lowest and holy_state.lowest_hp < ((menu.renew_threshold and menu.renew_threshold:get()) or 90) then
                -- Fire Inner Focus (off-GCD)
                if resolved.inner_focus and _get_spell_cd(resolved.inner_focus) == 0 then
                    utils.cast_self(resolved.inner_focus, me)
                    note_cast()
                end
            end
        end
    end
    
    -- [14] Greater Heal (sustained healing, 50-90% gap filler)
    if me:is_in_combat() and holy_state.lowest then
        -- FIXED: Proper nil guard
        local flash_threshold = (menu.flash_heal_hp_pct and menu.flash_heal_hp_pct:get() or 50)
        -- FIXED: Proper nil guard
        local renew_threshold = (menu.renew_threshold and menu.renew_threshold:get() or 90)
        -- Only cast GH if HP is between flash and renew thresholds
        if holy_state.lowest_hp < renew_threshold and holy_state.lowest_hp >= flash_threshold then
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) then
                if try_greater_heal(me, holy_state.lowest.unit_obj) then return end
            end
        end
    end
    
    -- [15] Flash Heal (urgent healing, <50% - emergency efficiency)
    if me:is_in_combat() and holy_state.lowest then
        -- FIXED: Proper nil guard
        local flash_threshold = (menu.flash_heal_hp_pct and menu.flash_heal_hp_pct:get() or 50)
        if holy_state.lowest_hp < flash_threshold then
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) then
                if try_flash_heal(me, holy_state.lowest.unit_obj) then return end
            end
        end
    end
    
    -- Debug logging when no action taken
    -- FIXED: Proper nil guard
    if menu.debug and menu.debug:get_state() then
        -- FIXED: Proper nil guard
        local renew_threshold = (menu.renew_threshold and menu.renew_threshold:get() or 90)
        -- FIXED: Proper nil guard
        local flash_threshold = (menu.flash_heal_hp_pct and menu.flash_heal_hp_pct:get() or 50)
        utils.log_debug(menu, string.format("No heal: lowest=%.1f%%, renew_threshold=%d, flash_threshold=%d", 
            holy_state.lowest_hp, renew_threshold, flash_threshold))
    end
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxpriestholy_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(function()
    menu.render()
end)


-- -- control panel callback --------------------------------------------------

local function on_control_panel()
    local elements = {}
    local function add_toggle(label, item, uid)
        if not item then return end
        local current = item:get_state()
        local next_state = control_panel_utility:insert_key_checkbox_(elements, label, current, 0, false, uid)
        if next_state ~= current then
            item:set(next_state)
        end
    end

    -- FIXED: Proper nil guard
    local toggle_key_code = menu.toggle_key and menu.toggle_key:get_key_code() or 7
    local display_name = "[Eax Priest Holy] Enabled"
    if toggle_key_code ~= 7 then
        display_name = "[Eax Priest Holy] Enabled (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end

    add_toggle(display_name, menu.enabled, "eax_priestholy_enabled_cp")

    if menu.enabled and menu.enabled:get_state() then
        add_toggle("[Eax PrH] Use Cooldowns", menu.use_cooldowns, "eax_prh_cds_cp")
        add_toggle("[Eax PrH] Focus Priority", menu.focus_priority, "eax_prh_focus_cp")
        add_toggle("[Eax PrH] Use Racial", menu.use_racial, "eax_prh_racial_cp")
    end

    return elements
end

-- -- register callbacks ------------------------------------------------------

core.register_on_render_control_panel_callback(on_control_panel)

-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Priest"
    local _eax_spec  = "Holy"
    -- Register this spec for its class (last-loaded wins for tracking)
    if not _G.__EAX_LOADED[_eax_class] then
        _G.__EAX_LOADED[_eax_class] = {}
    end
    _G.__EAX_LOADED[_eax_class][_eax_spec] = function()
        -- FIXED: Proper nil guard
        return menu and menu.enabled and (menu.enabled and menu.enabled:get_state())
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

