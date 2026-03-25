-- EAX Druid Restoration | main.lua
-- Group-aware healing rotation with Lifebloom, HoT, and cooldown management.

local menu = require("menu")
local rotation_context = require("rotation_context")
local resource_gate = require("resource_gate")
local spells = require("spells")
local utils = require("utils")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end
local eax_utils = require("eax_utils")
local color     = require("color")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
local enums = (function()
    local ok, e = pcall(require, "common/enums")
    return ok and e or nil
end)()

---@type interrupt_manager
local interrupt_manager = require("interrupt_manager")
---@type ooc_manager
local ooc_manager = require("ooc_manager")
---@type vendor_automation
local vendor_automation = require("vendor_automation")
---@type consumables_manager
local consumables_manager = require("consumables_manager")
---@type mount_manager
local mount_manager = require("mount_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type creature_utils
local creature_utils = require("creature_utils")

---@type encounter_manager
local encounter_manager = require("encounter_manager")


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("resto", "Druid Resto")
-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("smart_cast_manager")

-- Phase 04 visual telemetry wiring
local dps_meter = require("dps_meter")
local cooldown_tracker = require("cooldown_tracker")
local visual_state = require("visual_state")
local reactive_runtime = require("reactive_runtime")
local healer_triage = require("healer_triage")

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
local _visual_ttd_ok, _visual_ttd_mod = pcall(require, "ttd_tracker")
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
        spec = "EAXDruidRestoration",
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
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type dot_manager
local dot_manager = require("dot_manager")
---@type threat_manager
local threat_manager = require("threat_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    barkskin_id = nil,
    rebirth_id = nil,
    mark_of_the_wild_id = nil,
    rejuvenation_id = nil,
    regrowth_id = nil,
    healing_touch_id = nil,
    swiftmend_id = nil,
    lifebloom_id = nil,
    innervate_id = nil,
    tranquility_id = nil,
    natures_swiftness_id = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    pending_casts = {},
    set_multiplier = 1.0,
    ooc_mark_of_the_wild_id = nil,
    remove_curse_id = nil,
    -- DPS fallback
    moonfire_id = nil,
    insect_swarm_id = nil,
    wrath_id = nil,
    starfire_id = nil,
    faerie_fire_id = nil,
}

local ctx_cache = rotation_context.new({
    important_buffs = {
        spells.BUFF_INNERVATE,
        spells.BUFF_REJUVENATION,
        spells.BUFF_REGROWTH,
        spells.BUFF_LIFEBLOOM,
        spells.BUFF_NATURES_SWIFTNESS,
    },
    important_debuffs = {
        spells.DEBUFF_FAERIE_FIRE,
        spells.DEBUFF_MOONFIRE,
        spells.DEBUFF_INSECT_SWARM,
    },
})

local GROUP_ROLE_TANK = 0
local GCD_CAST_INTERVAL = 1.5  -- TBC GCD
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75

local function resolve_spells()
    runtime.mark_of_the_wild_id = utils.resolve_spell_id(spells.MARK_OF_THE_WILD)
    runtime.rejuvenation_id = utils.resolve_spell_id(spells.REJUVENATION)
    runtime.regrowth_id = utils.resolve_spell_id(spells.REGROWTH)
    runtime.swiftmend_id = utils.resolve_spell_id(spells.SWIFTMEND)
    runtime.lifebloom_id = utils.resolve_spell_id(spells.LIFEBLOOM)
    runtime.innervate_id = utils.resolve_spell_id(spells.INNERVATE)
    runtime.tranquility_id = utils.resolve_spell_id(spells.TRANQUILITY)
    runtime.natures_swiftness_id = utils.resolve_spell_id(spells.NATURES_SWIFTNESS)
    runtime.healing_touch_id = utils.resolve_spell_id(spells.HEALING_TOUCH)
    runtime.rebirth_id  = utils.resolve_spell_id(spells.REBIRTH)
    runtime.remove_curse_id = utils.resolve_spell_id(spells.REMOVE_CURSE)
    runtime.barkskin_id = utils.resolve_spell_id(spells.BARKSKIN)
    -- DPS fallback
    runtime.moonfire_id    = utils.resolve_spell_id(spells.MOONFIRE)
    runtime.insect_swarm_id = utils.resolve_spell_id(spells.INSECT_SWARM)
    runtime.wrath_id       = utils.resolve_spell_id(spells.WRATH)
    runtime.starfire_id    = utils.resolve_spell_id(spells.STARFIRE)
    runtime.faerie_fire_id = utils.resolve_spell_id(spells.FAERIE_FIRE)
end

local function log_resolved_spells()
    core.log("[EAX Druid Restoration] Resolved: Rejuvenation=" .. tostring(runtime.rejuvenation_id)
        .. " Regrowth=" .. tostring(runtime.regrowth_id)
        .. " HealingTouch=" .. tostring(runtime.healing_touch_id)
        .. " Swiftmend=" .. tostring(runtime.swiftmend_id)
        .. " Tranquility=" .. tostring(runtime.tranquility_id))
end

local function update_set_bonus(me)
    local nordrassil_mult = utils.get_set_multiplier(me, "Nordrassil")
    local nordrassil_harness_mult = utils.get_set_multiplier(me, "NordrassilHarness")
    local malorne_mult = utils.get_set_multiplier(me, "Malorne")
    runtime.set_multiplier = math.max(nordrassil_mult, nordrassil_harness_mult, malorne_mult)
end

resolve_spells()
log_resolved_spells()

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

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then return "solo" end
    if idx == 3 then return "dungeon" end
    if idx == 4 then return "raid" end
    return runtime.cached_mode
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

local function pick_tank_unit(me, units, mode)
    if mode == "solo" then
        return me
    end

    local best_tank = nil
    local best_health = -1

    for i = 1, #units do
        local unit = units[i]
        local role_id = unit.get_group_role and unit:get_group_role() or -1
        if role_id == GROUP_ROLE_TANK then
            local max_health = unit:get_max_health()
            if max_health > best_health then
                best_tank = unit
                best_health = max_health
            end
        end
    end

    if best_tank then
        return best_tank
    end

    return me
end

local function pick_priority_heal_target(me, tank, lowest, lowest_hp_pct)
    if lowest and lowest_hp_pct <= 0.75 then
        return lowest, lowest_hp_pct
    end

    if tank and tank:is_valid() then
        return tank, utils.get_health_pct(tank)
    end

    return me, utils.get_health_pct(me)
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
    if not unit or not unit.get_incoming_heals or not unit.get_max_health then
        return 0
    end
    local ok_heals, incoming = pcall(function() return unit:get_incoming_heals() end)
    local ok_max, max_health = pcall(function() return unit:get_max_health() end)
    if not ok_heals or not ok_max or not max_health or max_health <= 0 then
        return 0
    end
    return math.max(0, math.min((tonumber(incoming) or 0) / max_health, 1))
end

local function build_druid_triage(me)
    local units = utils.get_group_units(me, true)
    local tank = pick_tank_unit(me, units, get_effective_mode())
    local tank_guid = unit_guid(tank)
    local members = {}
    for i = 1, #units do
        local unit = units[i]
        if unit and unit:is_valid() and not unit:is_dead() then
            local guid = unit_guid(unit) or ("group-" .. i)
            local is_tank = guid == tank_guid
            members[#members + 1] = {
                guid = guid,
                unit = unit,
                hp_pct = utils.get_health_pct(unit),
                incoming_heal_pct = unit_incoming_heal_pct(unit),
                role = is_tank and "tank" or (unit == me and "healer" or "damager"),
                is_tank = is_tank,
            }
        end
    end
    return healer_triage.select_target(me, members, {}), units, tank
end

local function should_cancel_druid_cast(me, target)
    if not eax_utils.should_stopcasting(me, menu) then
        return false
    end
    local summary = select(1, build_druid_triage(me))
    local snapshot = {
        hp_pct = target and utils.get_health_pct(target) or utils.get_health_pct(me),
        incoming_heal_pct = target and unit_incoming_heal_pct(target) or unit_incoming_heal_pct(me),
        collapse_risk = summary and summary.collapse_risk == true,
        group_count = summary and summary.group_count or 0,
    }
    return healer_triage.should_cancel_overheal(snapshot, {})
end

local function try_mark_of_the_wild(me)
    if not menu.use_mark_of_the_wild or not menu.use_mark_of_the_wild:get_state() then return false end
    if not runtime.mark_of_the_wild_id then return false end
    if me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_MARK_OF_THE_WILD) then return false end
    if is_pending_cast(runtime.mark_of_the_wild_id) then return false end
    if not utils.can_cast_self(runtime.mark_of_the_wild_id, me) then return false end

    if utils.cast_self(runtime.mark_of_the_wild_id, me) then
        mark_pending_cast(runtime.mark_of_the_wild_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Mark of the Wild")
        note_cast()
        return true
    end

    return false
end

local function try_innervate(me, mana_pct)
    if not menu.use_innervate or not menu.use_innervate:get_state() then return false end
    if not runtime.innervate_id then return false end
    if mana_pct >= ((menu.innervate_mana_pct and menu.innervate_mana_pct:get() or 30) / 100) then return false end
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

local function try_tranquility(me, injured_count, lowest_hp_pct, mode)
    if not menu.use_tranquility or not menu.use_tranquility:get_state() then return false end
    if not runtime.tranquility_id then return false end
    if mode == "solo" then return false end
    if injured_count < (menu.tranquility_injured_count and menu.tranquility_injured_count:get() or 3) then return false end
    if lowest_hp_pct > 0.70 then return false end
    if is_pending_cast(runtime.tranquility_id) then return false end
    if not utils.can_cast_self(runtime.tranquility_id, me) then return false end

    if utils.cast_self_fast(runtime.tranquility_id, me) then
        mark_pending_cast(runtime.tranquility_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Tranquility")
        note_cast()
        return true
    end

    return false
end

-- Lifebloom — TBC Resto Druid's primary tank HoT (added patch 2.1)
-- Stack 3x on the tank and let it roll; re-apply before it blooms if tank is low,
-- or let it bloom intentionally if tank needs the burst heal.
local LIFEBLOOM_DURATION_MS = 7000  -- 7s per stack (TBC 2.4.3)
local LIFEBLOOM_REFRESH_THRESHOLD_MS = 2000  -- refresh when < 2s remaining

local function try_lifebloom(me, tank, tank_hp_pct)
    if not menu.use_lifebloom or not menu.use_lifebloom:get_state() then return false end
    if not runtime.lifebloom_id then return false end
    if not tank or not tank:is_valid() or tank:is_dead() then return false end

    local remaining_ms = utils.get_buff_remaining_ms(tank, spells.BUFF_LIFEBLOOM)
    local stack_count = utils.get_buff_stacks(tank, spells.BUFF_LIFEBLOOM) or 0
    local desired_stacks = menu.lifebloom_stacks and menu.lifebloom_stacks:get() or 3

    -- Don't refresh if tank is healthy and we have a full stack — let it bloom
    local bloom_threshold = (menu.lifebloom_bloom_hp and menu.lifebloom_bloom_hp:get() or 70) / 100
    if stack_count >= desired_stacks and tank_hp_pct > bloom_threshold and remaining_ms > LIFEBLOOM_REFRESH_THRESHOLD_MS then
        return false
    end

    -- Apply or refresh: always re-apply if < 2s left or not at max stacks
    local needs_refresh = (remaining_ms <= LIFEBLOOM_REFRESH_THRESHOLD_MS) or (stack_count < desired_stacks)
    if not needs_refresh then return false end

    if is_pending_cast(runtime.lifebloom_id) then return false end
    if not utils.can_cast_hostile(runtime.lifebloom_id, me, tank) then return false end

    if utils.cast_target(runtime.lifebloom_id, tank) then
        mark_pending_cast(runtime.lifebloom_id, PENDING_CAST_TIMEOUT_S)
        note_cast()
        esp_renderer.on_cast(runtime.lifebloom_id, "Lifebloom (" .. (stack_count + 1) .. ")", color.green(240))
        return true
    end
    return false
end

local function try_swiftmend(me, target, target_hp_pct)
    if not menu.use_swiftmend or not menu.use_swiftmend:get_state() then return false end
    if not runtime.swiftmend_id then return false end
    if target_hp_pct >= ((menu.swiftmend_hp_pct and menu.swiftmend_hp_pct:get() or 50) / 100) then return false end
    local has_rejuv    = utils.has_buff(target, spells.BUFF_REJUVENATION)
    local has_regrowth = utils.has_buff(target, spells.BUFF_REGROWTH)
    if not has_rejuv and not has_regrowth then return false end
    if is_pending_cast(runtime.swiftmend_id) then return false end
    if not utils.can_cast_hostile(runtime.swiftmend_id, me, target) then return false end
    if utils.cast_target(runtime.swiftmend_id, target) then
        mark_pending_cast(runtime.swiftmend_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Swiftmend on " .. (target.get_name and target:get_name() or "target"))
        note_cast()
        esp_renderer.on_cast(runtime.swiftmend_id, "Swiftmend", color.gold(240))
        return true
    end
    return false
end

local function try_natures_swiftness_healing_touch(me, target, target_hp_pct)
    if not menu.use_natures_swiftness or not menu.use_natures_swiftness:get_state() then return false end
    if not runtime.natures_swiftness_id or not runtime.healing_touch_id then return false end
    if target_hp_pct > ((menu.emergency_hp_pct and menu.emergency_hp_pct:get() or 50) / 100) then return false end

    if utils.has_buff(me, spells.BUFF_NATURES_SWIFTNESS) then
        if is_pending_cast(runtime.healing_touch_id) then return false end
        if not utils.can_cast_hostile(runtime.healing_touch_id, me, target) then return false end
        if utils.cast_target(runtime.healing_touch_id, target) then
            mark_pending_cast(runtime.healing_touch_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "NS -> Healing Touch on " .. (target.get_name and target:get_name() or "target"))
            note_cast()
            esp_renderer.on_cast(runtime.healing_touch_id, "NS Healing Touch", color.gold(240))
            return true
        end
        return false
    end

    if is_pending_cast(runtime.natures_swiftness_id) then return false end
    if not utils.can_cast_self(runtime.natures_swiftness_id, me) then return false end
    if utils.cast_self_fast(runtime.natures_swiftness_id, me) then
        mark_pending_cast(runtime.natures_swiftness_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Nature's Swiftness")
        note_cast()
        return true
    end
    return false
end

-- Multi-target Rejuvenation: spread to all injured party members, not just one.
-- Returns true if any cast fired.
local function try_rejuvenation(me, target, target_hp_pct)
    if not menu.use_rejuvenation or not menu.use_rejuvenation:get_state() then return false end
    if not runtime.rejuvenation_id then return false end
    if target_hp_pct >= 0.95 then return false end
    local refresh_ms = (menu.rejuvenation_refresh_seconds and menu.rejuvenation_refresh_seconds:get() or 3) * 1000
    if utils.get_buff_remaining_ms(target, spells.BUFF_REJUVENATION) > refresh_ms then return false end
    if is_pending_cast(runtime.rejuvenation_id) then return false end
    if not utils.can_cast_hostile(runtime.rejuvenation_id, me, target) then return false end
    if utils.cast_target(runtime.rejuvenation_id, target) then
        mark_pending_cast(runtime.rejuvenation_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Rejuvenation on " .. (target.get_name and target:get_name() or "target"))
        note_cast()
        esp_renderer.on_cast(runtime.rejuvenation_id, "Rejuvenation", color.green(220))
        return true
    end
    return false
end

-- Spread Rejuvenation across all injured party members.
-- Fires one cast per tick (GCD limited), prioritised by lowest HP.
local function try_spread_rejuvenation(me, units, mana_pct)
    if not menu.use_rejuvenation or not menu.use_rejuvenation:get_state() then return false end
    if not runtime.rejuvenation_id then return false end
    if menu.mana_saver:get_state() and mana_pct < 0.50 then return false end
    if is_pending_cast(runtime.rejuvenation_id) then return false end
    local refresh_ms = (menu.rejuvenation_refresh_seconds and menu.rejuvenation_refresh_seconds:get() or 3) * 1000
    -- Sort by HP ascending so lowest HP gets Rejuv first
    local candidates = {}
    for _, unit in ipairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local hp = utils.get_health_pct(unit)
            local rem = utils.get_buff_remaining_ms(unit, spells.BUFF_REJUVENATION)
            if hp < 0.95 and rem <= refresh_ms then
                candidates[#candidates+1] = { unit = unit, hp = hp }
            end
        end
    end
    table.sort(candidates, function(a, b) return a.hp < b.hp end)
    for _, c in ipairs(candidates) do
        if utils.can_cast_hostile(runtime.rejuvenation_id, me, c.unit) then
            if utils.cast_target(runtime.rejuvenation_id, c.unit) then
                mark_pending_cast(runtime.rejuvenation_id, PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "Rejuvenation spread -> " .. (c.unit.get_name and c.unit:get_name() or "ally"))
                note_cast()
                esp_renderer.on_cast(runtime.rejuvenation_id, "Rejuv", color.green(220))
                return true
            end
        end
    end
    return false
end

local function try_regrowth(me, target, target_hp_pct, mana_pct)
    if not menu.use_regrowth or not menu.use_regrowth:get_state() then return false end
    if not runtime.regrowth_id then return false end
    if target_hp_pct >= 0.60 then return false end
    if menu.mana_saver:get_state() and mana_pct < 0.45 and target_hp_pct > 0.60 then return false end
    if utils.get_buff_remaining_ms(target, spells.BUFF_REGROWTH) > ((menu.regrowth_refresh_seconds and menu.regrowth_refresh_seconds:get() or 3) * 1000) then return false end
    if is_pending_cast(runtime.regrowth_id) then return false end
    if not utils.can_cast_hostile(runtime.regrowth_id, me, target) then return false end
    if utils.cast_target(runtime.regrowth_id, target) then
        mark_pending_cast(runtime.regrowth_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Regrowth on " .. (target.get_name and target:get_name() or "target"))
        note_cast()
        esp_renderer.on_cast(runtime.regrowth_id, "Regrowth", color.gold(220))
        return true
    end
    return false
end

-- Healing Touch: direct heal fallback when all HoTs are running and HP is critical.
local function try_healing_touch(me, target, target_hp_pct, mana_pct)
    if not menu.use_healing_touch or not menu.use_healing_touch:get_state() then return false end
    if not runtime.healing_touch_id then return false end
    if target_hp_pct >= ((menu.healing_touch_hp_pct and menu.healing_touch_hp_pct:get() or 75) / 100) then return false end
    if menu.mana_saver:get_state() and mana_pct < 0.30 then return false end
    if is_pending_cast(runtime.healing_touch_id) then return false end
    if not utils.can_cast_hostile(runtime.healing_touch_id, me, target) then return false end
    if utils.cast_target(runtime.healing_touch_id, target) then
        mark_pending_cast(runtime.healing_touch_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Healing Touch on " .. (target.get_name and target:get_name() or "target"))
        note_cast()
        esp_renderer.on_cast(runtime.healing_touch_id, "Healing Touch", color.green(240))
        return true
    end
    return false
end

local function try_remove_curse_resto(me)
    if not menu.use_remove_curse or not menu.use_remove_curse:get_state() then return false end
    if not runtime.remove_curse_id then return false end
    if is_pending_cast(runtime.remove_curse_id) then return false end
    local units = utils.get_group_units(me, true)
    for _, unit in ipairs(units) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local cache = buff_manager:get_debuff_cache(unit, 100)
            for _, aura in ipairs(cache) do
                if aura.is_active and enums and enums.buff_type
                   and aura.buff_type == enums.buff_type.CURSE then
                    if utils.can_cast_hostile(runtime.remove_curse_id, me, unit) then
                        if utils.cast_target(runtime.remove_curse_id, unit) then
                            mark_pending_cast(runtime.remove_curse_id, PENDING_CAST_TIMEOUT_S)
                            utils.log_debug(menu, "Remove Curse -> " .. (unit.get_name and unit:get_name() or "ally"))
                            note_cast()
                            return true
                        end
                    end
                    break
                end
            end
        end
    end
    return false
end

local function try_barkskin_defensive(me)
    if not menu.use_barkskin or not menu.use_barkskin:get_state() then return false end
    if not runtime.barkskin_id then return false end
    if utils.has_buff(me, spells.BUFF_BARKSKIN) then return false end
    local hp = me:get_health_percentage() / 100
    local threshold = menu.use_barkskin_hp_pct and ((menu.use_barkskin_hp_pct and menu.use_barkskin_hp_pct:get() or 40) / 100) or 0.40
    if hp > threshold then return false end
    if not utils.can_cast_self(runtime.barkskin_id, me) then return false end
    if utils.cast_self(runtime.barkskin_id, me) then
        invalidate_ctx()
        utils.log_debug(menu, "Barkskin (defensive)")
        return true
    end
    return false
end
-- ─────────────────────────────────────────────────────────────────────────────
-- DPS FALLBACK  (solo only – fires when no healing action was taken)
-- Priority: Faerie Fire > Insect Swarm > Moonfire > Starfire/Wrath filler
-- ─────────────────────────────────────────────────────────────────────────────
local function do_dps_fallback(me, target)
    if not menu.dps_fallback_enabled or not menu.dps_fallback_enabled:get_state() then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not me:can_attack(target) then return false end
    if not is_gcd_ready() then return false end

    -- Faerie Fire (armor debuff, no DoT to track, just check if active)
    if menu.dps_use_faerie_fire:get_state() and runtime.faerie_fire_id then
        local ff_rem = utils.get_debuff_remaining_ms and utils.get_debuff_remaining_ms(target, spells.DEBUFF_FAERIE_FIRE) or 0
        if ff_rem <= 0 and not is_pending_cast(runtime.faerie_fire_id) then
            if utils.can_cast_unit(runtime.faerie_fire_id, me, target) then
                if utils.cast_unit(runtime.faerie_fire_id, me, target) then
                    mark_pending_cast(runtime.faerie_fire_id, PENDING_CAST_TIMEOUT_S)
                    utils.log_debug(menu, "DPS: Faerie Fire")
                    note_cast()
                    esp_renderer.on_cast(nil, "Faerie Fire", color.cyan(200))
                    return true
                end
            end
        end
    end

    -- Insect Swarm DoT
    if menu.dps_use_insect_swarm:get_state() and runtime.insect_swarm_id then
        local is_rem = utils.get_debuff_remaining_ms and utils.get_debuff_remaining_ms(target, spells.DEBUFF_INSECT_SWARM) or 0
        if is_rem <= 1500 and not is_pending_cast(runtime.insect_swarm_id) then
            if utils.can_cast_unit(runtime.insect_swarm_id, me, target) then
                if utils.cast_unit(runtime.insect_swarm_id, me, target) then
                    mark_pending_cast(runtime.insect_swarm_id, PENDING_CAST_TIMEOUT_S)
                    utils.log_debug(menu, "DPS: Insect Swarm")
                    note_cast()
                    esp_renderer.on_cast(nil, "Insect Swarm", color.green(200))
                    return true
                end
            end
        end
    end

    -- Moonfire DoT
    if menu.dps_use_moonfire:get_state() and runtime.moonfire_id then
        local mf_rem = utils.get_debuff_remaining_ms and utils.get_debuff_remaining_ms(target, spells.DEBUFF_MOONFIRE) or 0
        if mf_rem <= 1500 and not is_pending_cast(runtime.moonfire_id) then
            if utils.can_cast_unit(runtime.moonfire_id, me, target) then
                if utils.cast_unit(runtime.moonfire_id, me, target) then
                    mark_pending_cast(runtime.moonfire_id, PENDING_CAST_TIMEOUT_S)
                    utils.log_debug(menu, "DPS: Moonfire")
                    note_cast()
                    esp_renderer.on_cast(nil, "Moonfire", color.gold(200))
                    return true
                end
            end
        end
    end

    -- Filler nuke: Starfire or Wrath
    local prefer_starfire = menu.dps_starfire_over_wrath:get_state()
    local primary_id   = prefer_starfire and runtime.starfire_id   or runtime.wrath_id
    local primary_key  = prefer_starfire and "dps_use_starfire"     or "dps_use_wrath"
    local fallback_id  = prefer_starfire and runtime.wrath_id      or runtime.starfire_id
    local fallback_key = prefer_starfire and "dps_use_wrath"       or "dps_use_starfire"
    local primary_name  = prefer_starfire and "Starfire"           or "Wrath"
    local fallback_name = prefer_starfire and "Wrath"              or "Starfire"

    if menu[primary_key]:get_state() and primary_id and not is_pending_cast(primary_id) then
        if utils.can_cast_unit(primary_id, me, target) then
            if utils.cast_unit(primary_id, me, target) then
                mark_pending_cast(primary_id, PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "DPS: " .. primary_name)
                note_cast()
                esp_renderer.on_cast(nil, primary_name, color.cyan(200))
                return true
            end
        end
    end

    if menu[fallback_key]:get_state() and fallback_id and not is_pending_cast(fallback_id) then
        if utils.can_cast_unit(fallback_id, me, target) then
            if utils.cast_unit(fallback_id, me, target) then
                mark_pending_cast(fallback_id, PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "DPS: " .. fallback_name)
                note_cast()
                esp_renderer.on_cast(nil, fallback_name, color.cyan(200))
                return true
            end
        end
    end

    return false
end

local function do_rotation(me, target)
    if not is_gcd_ready() then return false end

    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)

    -- OOC: only allow buffs
    if not me:is_in_combat() then
        try_mark_of_the_wild(me)
        return false
    end

    local mana_pct = utils.get_mana_pct(me)
    local units    = utils.get_group_units(me, true)
    local mode     = get_effective_mode()

    -- Focus target override — always heal focus first
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() and not focus_target:is_dead() then
        local focus_hp = focus_target:get_health_percentage() / 100
        if focus_hp < 0.95 then
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_swiftmend(me, focus_target, focus_hp) then return true end
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_natures_swiftness_healing_touch(me, focus_target, focus_hp) then return true end
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_regrowth(me, focus_target, focus_hp, mana_pct) then return true end
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_rejuvenation(me, focus_target, focus_hp) then return true end
            if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) and try_healing_touch(me, focus_target, focus_hp, mana_pct) then return true end
        end
    end

    -- Self-preservation
    local my_hp = me:get_health_percentage() / 100
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    if my_hp < self_threshold then
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_swiftmend(me, me, my_hp) then return true end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_natures_swiftness_healing_touch(me, me, my_hp) then return true end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_regrowth(me, me, my_hp, mana_pct) then return true end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_rejuvenation(me, me, my_hp) then return true end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) and try_healing_touch(me, me, my_hp, mana_pct) then return true end
    end

    -- Gather group state
    local lowest, lowest_hp_pct = utils.get_lowest_health_unit(units)
    local tank = pick_tank_unit(me, units, mode)
    local heal_target, heal_hp = pick_priority_heal_target(me, tank, lowest, lowest_hp_pct)
    local injured_count = utils.count_injured_units(units, 0.85)

    -- Dispel
    if try_remove_curse_resto(me) then return true end

    -- Emergency single-target: Swiftmend -> NS + HT
    if heal_target then
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_swiftmend(me, heal_target, heal_hp) then return true end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_natures_swiftness_healing_touch(me, heal_target, heal_hp) then return true end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_regrowth(me, heal_target, heal_hp, mana_pct) then return true end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_rejuvenation(me, heal_target, heal_hp) then return true end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) and try_healing_touch(me, heal_target, heal_hp, mana_pct) then return true end
    end

    -- Tank maintenance: keep HoTs refreshed before relying on filler casts
    if tank then
        local tank_hp = utils.get_health_pct(tank)
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.06) and try_lifebloom(me, tank, tank_hp) then return true end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_regrowth(me, tank, tank_hp, mana_pct) then return true end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and try_rejuvenation(me, tank, tank_hp) then return true end
    end

    -- Spread Rejuvenation to all injured party members (priority sorted by HP)
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_spread_rejuvenation(me, units, mana_pct) then return true end

    -- Raid emergency and mana recovery come after immediate single-target stabilisation
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.25) and try_tranquility(me, injured_count, lowest_hp_pct, mode) then return true end
    if try_innervate(me, mana_pct) then return true end

    -- Leveling fallback: wand at enemy target when mana is low
    if me:is_in_combat() and target and target:is_valid()
       and not target:is_dead() and me:can_attack(target) then
        leveling_manager.try_wand(me, target, menu)
    end

    -- Solo DPS fallback
    if mode == "solo" and me:is_in_combat() and (not lowest_hp_pct or lowest_hp_pct >= 0.85) then
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.05) then
            do_dps_fallback(me, target)
        end
    end

    return false
end


reactive_adapter = {
    spec = "EAXDruidRestoration",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                local my_hp = utils.get_health_pct(action_deps.me)
                local mana_pct = utils.get_mana_pct(action_deps.me)
                return try_swiftmend(action_deps.me, action_deps.me, my_hp)
                    or try_natures_swiftness_healing_touch(action_deps.me, action_deps.me, my_hp)
                    or try_regrowth(action_deps.me, action_deps.me, my_hp, mana_pct)
                    or try_rejuvenation(action_deps.me, action_deps.me, my_hp)
                    or try_healing_touch(action_deps.me, action_deps.me, my_hp, mana_pct)
            end,
        },
        life_save_ally = {
            handler = function(_, action_deps)
                local summary = build_druid_triage(action_deps.me)
                local mana_pct = utils.get_mana_pct(action_deps.me)
                local heal_target = summary and summary.target or nil
                local heal_hp = summary and summary.hp_pct or nil
                if not heal_target or not heal_target:is_valid() then
                    return false
                end
                if summary and summary.reason == "group_stabilize" then
                    if try_tranquility(action_deps.me, summary.group_count, heal_hp, get_effective_mode()) then return true end
                end
                return try_swiftmend(action_deps.me, heal_target, heal_hp)
                    or try_natures_swiftness_healing_touch(action_deps.me, heal_target, heal_hp)
                    or try_regrowth(action_deps.me, heal_target, heal_hp, mana_pct)
                    or try_rejuvenation(action_deps.me, heal_target, heal_hp)
                    or try_healing_touch(action_deps.me, heal_target, heal_hp, mana_pct)
            end,
        },
        interrupt_control = { noop = "unsupported" },
        anti_overheal = {
            handler = function(_, action_deps)
                if not should_cancel_druid_cast(action_deps.me, action_deps.current_target) then
                    return false
                end

                if SpellStopCasting then
                    SpellStopCasting()
                    return true
                end

                return false
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
}

local function on_render()
    esp_renderer.on_render(menu)
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
    if not threat_initialized then threat_manager.init(me); threat_initialized = true end

    if utils.throttle("eaxdruidrestoration_mode_refresh", 5.0) then
        runtime.cached_mode = utils.detect_mode(me)
    end

    if utils.throttle("eaxdruidrestoration_set_bonus", 10.0) then
        update_set_bonus(me)
    end

    handle_toggle()

    if not menu.enabled or not menu.enabled:get_state() then return end

    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils, {
        rez_spell_id = runtime.rebirth_id,
        group_buffs = {
            { spell_id = runtime.ooc_mark_of_the_wild_id,
               buff_ids = spells.BUFF_MARK_OF_THE_WILD,
               name = "Mark Of The Wild",
               toggle = menu.ooc_group_buff },
        },
    })
    if me:is_dead() then return end
    if (menu.auto_mount and menu.auto_mount:get_state()) or (menu.auto_dismount and menu.auto_dismount:get_state()) then
        mount_manager.update_mount_state(me, menu, utils)
    end

    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        consumables_manager.try_use_ooc_food_drink(me, menu, utils)
    end

    if menu.auto_repair and menu.auto_repair:get_state() then
        vendor_automation.try_auto_repair(me, menu, utils)
    end

    if menu.auto_sell_greys and menu.auto_sell_greys:get_state() then
        vendor_automation.try_auto_sell_greys(me, menu, utils)
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

    -- Overheal Protection - cancel slow heals if target is healthy
    if eax_utils.should_stopcasting(me, menu) then
        if SpellStopCasting then SpellStopCasting() end
    end

    -- Use smart target for wanding/interrupts (prefers units attacking us/party)
    local target = utils.find_best_target(me)

    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end

    -- Interrupt (PVP)
    if target and target:is_valid() and me:can_attack(target) and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "druid", utils) then
            return
        end
    end

    -- Encounter policy (boss-specific rotation adjustments)
    local enc = encounter_manager.get_policy(me)

    -- Defensive abilities
    -- Racial abilities
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    if try_barkskin_defensive(me) then return true end
    if defensive_manager.try_defensive(me, "druid", utils) then
        return
    end

    -- Threat fade protection — don't pull aggro from tank
    local current_target = me:get_target()
    local ok, should_fade = pcall(function() return threat_manager.should_fade(me, current_target) end)
    if ok and should_fade then
        pcall(function() threat_manager.try_fade(me) end)
        return
    end

    ttd_tracker.update(target)

    do_rotation(me, target)
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxdruidrestoration_space_win")
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
        local label = "EAX Druid Resto] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxdruidrestoration_enabled_cp")
        return elements
    end)
end


-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Druid"
    local _eax_spec  = "Restoration"
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
        core.log("[EAX WARNING] Multiple " .. _eax_class .. " specs enabled: "
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
core.log("[EAX Druid Restoration] Loaded " .. (_pi and _pi.plugin_version or "?"))
