-- Eax Paladin Retribution | main.lua
-- Rotation logic for Seal twists, Crusader Strike, and Judgement.

local menu = require("libraries/menu")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")
local spells = require("libraries/spells")
local utils = require("libraries/utils")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end
local eax_utils = require("libraries/eax_utils")
local color     = require("libraries/color")
local dispel_engine = require("libraries/dispel_engine")

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")
---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
---@type leveling_manager
local leveling_manager = require("libraries/leveling_manager")
---@type creature_utils
local creature_utils = require("libraries/creature_utils")

---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
local pvp_manager = require("eax_shared/pvp_manager")
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


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("pret", "Paladin Ret")
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
        spec = "EAXPaladinRetribution",
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

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    divine_shield_id = nil,
    redemption_id = nil,
    crusader_strike_id = nil,
    divine_storm_id = nil,
    avenging_wrath_id = nil,
    seal_command_id = nil,
    consecration_id = nil,
    divine_favor_id = nil,
    exorcism_id = nil,
    seal_righteousness_id = nil,
    seal_blood_id = nil,
    seal_wisdom_id = nil,
    seal_light_id = nil,
    seal_crusader_id = nil,
    holy_light_id = nil,
    judgement_ids = {
        wisdom = nil,
        crusader = nil,
        light = nil,
    },
    judgement_spell_id = nil,
    last_cast_time = 0,
    cached_mode = "solo",
    last_toggle_state = false,
    last_twist_at = 0,
    last_twist_key_state = false,
    last_consecration_key_state = false,
    last_exorcism_key_state = false,
    last_freedom_key_state = false,
    twist_state = "idle",
    twist_state_changed_at = 0,
    twist_seal_id = nil,
    twist_seal_name = nil,
    twist_target_guid = nil,
    ooc_blessing_of_might_id = nil,
    ooc_blessing_of_wisdom_id = nil,
    hand_of_freedom_id = nil,
    cleanse_id = nil,
    purify_id = nil,
    judgement_id = nil,
    pending_judgement_until = 0,
    pending_baseline_reseal_until = 0,
    pre_pull_state = "idle",
    pre_pull_state_changed_at = 0,
    pre_pull_target_guid = nil,
    last_aura_cast_at = 0,
    last_blessing_retry_at = {},
    last_ooc_blessing_at = 0,
    vengeance_stacks = 0,
    last_vengeance_check = 0,
}

local ctx_cache = rotation_context.new({
    important_buffs = {
        spells.BUFF_SEAL_OF_COMMAND,
        spells.BUFF_SEAL_OF_BLOOD,
        spells.BUFF_SEAL_OF_RIGHTEOUSNESS,
        spells.BUFF_AVENGING_WRATH,
    },
    important_debuffs = {},
})

local GCD_CAST_INTERVAL = 1.5  -- TBC GCD
local MODE_REFRESH_INTERVAL = 3.0
local RET_AOE_RADIUS = 8
local SEAL_TWIST_INPUT_DELAY_MS = 100
local SEAL_TWIST_MANA_RESERVE = 0.20
local SEAL_TWIST_CONFIRM_TIMEOUT_S = 0.75
local BASELINE_RESEAL_DELAY_S = 1.5
local POST_JUDGEMENT_RESEAL_DELAY_S = 1.75
local PRE_PULL_CONFIRM_TIMEOUT_S = 1.0
local AURA_RETRY_WINDOW = 12.0
local BLESSING_RETRY_WINDOW = 6.0

local function count_nearby_enemies(me)
    local ok_count, count = pcall(function()
        return utils.count_enemies_within_radius(me, RET_AOE_RADIUS)
    end)
    if ok_count and type(count) == "number" then
        return count
    end
    local ok_enemy_count, alt_count = pcall(function()
        return utils.enemy_count_in_radius(me, RET_AOE_RADIUS)
    end)
    if ok_enemy_count and type(alt_count) == "number" then
        return alt_count
    end
    return 1
end

local function resolve_spells()
    runtime.hammer_of_wrath_id = utils.resolve_spell_id(spells.HAMMER_OF_WRATH)
    runtime.lay_on_hands_id    = utils.resolve_spell_id(spells.LAY_ON_HANDS)
    runtime.crusader_strike_id = utils.resolve_spell_id(spells.CRUSADER_STRIKE)
    runtime.avenging_wrath_id    = utils.resolve_spell_id(spells.AVENGING_WRATH)
    runtime.seal_command_id = utils.resolve_spell_id(spells.SEAL_OF_COMMAND)
    runtime.seal_righteousness_id = utils.resolve_spell_id(spells.SEAL_OF_RIGHTEOUSNESS)
    runtime.seal_blood_id = utils.resolve_spell_id(spells.SEAL_OF_BLOOD)
    runtime.seal_wisdom_id = utils.resolve_spell_id(spells.SEAL_OF_WISDOM)
    runtime.seal_light_id = utils.resolve_spell_id(spells.SEAL_OF_LIGHT)
    runtime.seal_crusader_id = utils.resolve_spell_id(spells.SEAL_OF_THE_CRUSADER)
    runtime.consecration_id = utils.resolve_spell_id(spells.CONSECRATION)
    runtime.divine_favor_id  = utils.resolve_spell_id(spells.DIVINE_FAVOR)
    runtime.exorcism_id      = utils.resolve_spell_id(spells.EXORCISM)
    runtime.redemption_id  = utils.resolve_spell_id(spells.REDEMPTION)
    runtime.holy_light_id = utils.resolve_spell_id(spells.HOLY_LIGHT)
    runtime.hand_of_freedom_id = utils.resolve_spell_id(spells.HAND_OF_FREEDOM)
    runtime.cleanse_id = utils.resolve_spell_id(spells.CLEANSE)
    runtime.purify_id = utils.resolve_spell_id(spells.PURIFY)
    runtime.ooc_blessing_of_might_id = utils.resolve_spell_id(spells.BLESSING_OF_MIGHT)
    runtime.ooc_blessing_of_wisdom_id = utils.resolve_spell_id(spells.BLESSING_OF_WISDOM)
    runtime.judgement_spell_id = utils.resolve_spell_id(spells.JUDGEMENT)
    runtime.judgement_ids.wisdom = utils.resolve_spell_id(spells.JUDGEMENT_OF_WISDOM)
    runtime.judgement_ids.crusader = utils.resolve_spell_id(spells.JUDGEMENT_OF_THE_CRUSADER)
    runtime.judgement_ids.light = utils.resolve_spell_id(spells.JUDGEMENT_OF_LIGHT)
    runtime.divine_shield_id = utils.resolve_spell_id(spells.DIVINE_SHIELD)
end

local function log_resolved_spells()
    core.log("[Eax Paladin Retribution] Resolved spells: CS=" .. tostring(runtime.crusader_strike_id))
end

local function refresh_mode_cache(me)
    runtime.cached_mode = utils.detect_mode(me)
end

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 1 then
        return runtime.cached_mode
    end
    if idx == 2 then
        return "solo"
    end
    if idx == 3 then
        return "dungeon"
    end
    return "raid"
end

local function handle_toggle()
    local pressed = menu.toggle_key:get_state()
    if pressed and not runtime.last_toggle_state then
        local new_state = not menu.enabled:get_state()
        menu.enabled:set(new_state)
        utils.log_debug(menu, "Toggled -> " .. tostring(new_state))
    end
    runtime.last_toggle_state = pressed
end

local function handle_checkbox_keybind(keybind, checkbox, state_key, label)
    if not keybind or not checkbox then
        return
    end
    if keybind:get_key_code() == 7 then
        runtime[state_key] = false
        return
    end

    local pressed = keybind:get_state()
    if pressed and not runtime[state_key] then
        local new_state = not checkbox:get_state()
        checkbox:set(new_state)
        utils.log_debug(menu, label .. " -> " .. tostring(new_state))
    end
    runtime[state_key] = pressed
end

local function handle_rotation_hotkeys()
    handle_checkbox_keybind(menu.use_seal_twist_key, menu.use_seal_twist, "last_twist_key_state", "Seal Twist")
    handle_checkbox_keybind(menu.use_consecration_key, menu.use_consecration, "last_consecration_key_state", "Consecration")
    handle_checkbox_keybind(menu.use_exorcism_key, menu.use_exorcism, "last_exorcism_key_state", "Exorcism")
    handle_checkbox_keybind(menu.use_hand_of_freedom_key, menu.use_hand_of_freedom, "last_freedom_key_state", "Hand of Freedom")
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

local function note_cast()
    runtime.last_cast_time = _core_time()
    rotation_context.invalidate(ctx_cache)
end

local function update_vengeance_stacks(target)
    if not target or not target:is_valid() then
        runtime.vengeance_stacks = 0
        return
    end
    local stacks = utils.get_debuff_stack_count(target, spells.DEBUFF_HOLY_VENGEANCE) or 0
    runtime.vengeance_stacks = stacks
    runtime.last_vengeance_check = _core_time()
end

local MAGIC_DISPEL_TYPE = 1
local DISEASE_DISPEL_TYPE = 3
local POISON_DISPEL_TYPE = 4

local function target_has_dispellable_debuff(unit)
    if not unit then return false end
    local type_defs = {
        { numeric = MAGIC_DISPEL_TYPE, name = "magic" },
        { numeric = DISEASE_DISPEL_TYPE, name = "disease" },
        { numeric = POISON_DISPEL_TYPE, name = "poison" },
    }
    for i = 1, #type_defs do
        if dispel_engine.unit_has_type(unit, type_defs[i], nil) then
            return true
        end
    end
    return false
end

local function unit_has_any_paladin_blessing(unit)
    if not unit or not unit:is_valid() or unit:is_dead() then
        return false
    end
    local blessing_ids = {
        spells.BUFF_BLESSING_OF_MIGHT,
        spells.BUFF_BLESSING_OF_WISDOM,
        spells.BUFF_BLESSING_OF_KINGS,
        spells.BUFF_BLESSING_OF_SANCTUARY,
        spells.BUFF_BLESSING_OF_LIGHT,
    }
    for i = 1, #blessing_ids do
        if utils.has_buff(unit, blessing_ids[i]) then
            return true
        end
    end
    return false
end

local function try_holy_light(me)
    if not runtime.holy_light_id or not me or not me:is_in_combat() then return false end
    if not is_gcd_ready() then return false end
    if utils.get_health_pct(me) > 0.42 then return false end
    if not utils.can_cast_self(runtime.holy_light_id, me) then return false end
    if utils.cast_self(runtime.holy_light_id, me) then
        note_cast()
        utils.log_debug(menu, "Holy Light")
        return true
    end
    return false
end

local function try_ooc_blessing(me)
    if not me or me:is_in_combat() or eax_utils.is_eating_or_drinking(me) then return false end
    if (_core_time() - (runtime.last_ooc_blessing_at or 0)) < 8.0 then return false end
    if unit_has_any_paladin_blessing(me) then return false end
    if not runtime.ooc_blessing_of_wisdom_id then return false end
    if utils.can_cast_self(runtime.ooc_blessing_of_wisdom_id, me) and utils.cast_self(runtime.ooc_blessing_of_wisdom_id, me) then
        runtime.last_ooc_blessing_at = _core_time()
        note_cast()
        utils.log_debug(menu, "OOC: Blessing of Wisdom")
        return true
    end
    return false
end

local function invalidate_ctx()
    rotation_context.invalidate(ctx_cache)
end

local function twists_allowed_in_mode(mode)
    if mode == "solo" then
        return true
    elseif mode == "dungeon" then
        return menu.allow_twist_dungeon:get_state()
    elseif mode == "raid" then
        return menu.allow_twist_raid:get_state()
    end
    return true
end

local function get_current_seal(me)
    if utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD) then
        return "blood"
    end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
        return "command"
    end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then
        return "righteous"
    end
    return "none"
end

local function get_preferred_seal()
    if runtime.seal_blood_id and core.spell_book.is_spell_learned(runtime.seal_blood_id) then
        return runtime.seal_blood_id, "Blood", "blood"
    end
    if runtime.seal_command_id and core.spell_book.is_spell_learned(runtime.seal_command_id) then
        return runtime.seal_command_id, "Command", "command"
    end
    if runtime.seal_righteousness_id and core.spell_book.is_spell_learned(runtime.seal_righteousness_id) then
        return runtime.seal_righteousness_id, "Righteousness", "righteous"
    end
    -- Low mana: switch to SoW
    local me = _get_local_player()
    if me and utils.get_mana_pct(me) < 0.20 and runtime.seal_wisdom_id then
        return runtime.seal_wisdom_id, "Wisdom", "wisdom"
    end
    return nil, nil, nil
end

local function get_twist_seal_choice()
    if runtime.seal_blood_id and core.spell_book.is_spell_learned(runtime.seal_blood_id) then
        return runtime.seal_command_id, "Command", "command"
    end
    if runtime.seal_command_id and core.spell_book.is_spell_learned(runtime.seal_command_id) then
        return runtime.seal_righteousness_id, "Righteousness", "righteous"
    end
    return nil, nil, nil
end

local function ensure_aura_upkeep(me)
    if not menu.use_aura or not menu.use_aura:get_state() then return false end
    if utils.has_buff(me, spells.BUFF_CRUSADER_AURA)
        or utils.has_buff(me, spells.BUFF_RETRIBUTION_AURA)
        or utils.has_buff(me, spells.BUFF_DEVOTION_AURA)
        or utils.has_buff(me, spells.BUFF_CONCENTRATION_AURA)
    then
        return false
    end
    if (_core_time() - (runtime.last_aura_cast_at or 0)) < AURA_RETRY_WINDOW then return false end
    local aura_id = utils.resolve_spell_id(spells.RETRIBUTION_AURA)
    if not aura_id then return false end
    if utils.can_cast_self(aura_id, me) and utils.cast_self(aura_id, me) then
        runtime.last_aura_cast_at = _core_time()
        note_cast()
        utils.log_debug(menu, "Retribution Aura")
        return true
    end
    return false
end

local function reset_twist_state()
    runtime.twist_state = "idle"
    runtime.twist_state_changed_at = 0
    runtime.twist_seal_id = nil
    runtime.twist_seal_name = nil
    runtime.twist_target_guid = nil
end

local function get_unit_guid(unit)
    if not unit or not unit.is_valid or not unit:is_valid() or type(unit.get_guid) ~= "function" then
        return nil
    end
    local ok, guid = pcall(function() return unit:get_guid() end)
    if not ok or guid == nil then
        return nil
    end
    return tostring(guid)
end

local function can_consider_seal_twist(me, target)
    if not menu.use_seal_twist:get_state() then
        return nil, nil
    end

    local effective_mode = get_effective_mode()
    if not twists_allowed_in_mode(effective_mode) then
        return nil, nil
    end
    if not target or not target:is_valid() or target:is_dead() then
        return nil, nil
    end
    if not utils.is_melee_target(me, target) then
        return nil, nil
    end

    local twist_seal_id, twist_seal_name = get_twist_seal_choice()
    local baseline_seal_id, baseline_seal_name, baseline_seal_key = get_preferred_seal()
    if not baseline_seal_id or not twist_seal_id then
        return nil, nil
    end
    if baseline_seal_key == "blood" and not utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD) then
        return nil, nil
    end
    if baseline_seal_key == "command" and not utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
        return nil, nil
    end
    if baseline_seal_key == "righteous" and not utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then
        return nil, nil
    end
    if twist_seal_name == "Command" and utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
        return nil, nil
    end
    if twist_seal_name == "Righteousness" and utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then
        return nil, nil
    end
    if utils.get_mana_pct(me) < SEAL_TWIST_MANA_RESERVE then
        return nil, nil
    end

    -- Don't twist away from SoV if stacks >= 3 and target will live long enough
    if baseline_seal_key == "command" then
        local vengeance_stacks = runtime.vengeance_stacks
        if vengeance_stacks >= 3 then
            local ttd = ttd_tracker and ttd_tracker.get and ttd_tracker.get(target) or 999
            if ttd >= 15 then return nil, nil end
        end
    end

    return twist_seal_id, twist_seal_name
end

local function has_active_twist_seal(me)
    if not me or not me:is_valid() then
        return false
    end

    if runtime.twist_seal_name == "Command" then
        return utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND)
    end
    if runtime.twist_seal_name == "Righteousness" then
        return utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS)
    end

    return false
end

local function should_hold_for_crusader_strike(me, target)
    if not menu.use_crusader_strike:get_state() then
        return false
    end
    if not runtime.crusader_strike_id or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not utils.is_melee_target(me, target) then
        return false
    end

    local cooldown_ms = (tonumber(_get_spell_cd(runtime.crusader_strike_id)) or 0) * 1000
    if cooldown_ms <= 0 then
        return false
    end

    return cooldown_ms <= (menu.seal_twist_window:get() + SEAL_TWIST_INPUT_DELAY_MS)
end

local function should_hold_for_seal_twist(me, target)
    if runtime.twist_state ~= "idle" then
        return false
    end

    local twist_seal_id = can_consider_seal_twist(me, target)
    if not twist_seal_id then
        return false
    end
    if should_hold_for_crusader_strike(me, target) then
        return false
    end

    return utils.would_new_gcd_cross_swing_window(
        me,
        menu.seal_twist_window:get(),
        SEAL_TWIST_INPUT_DELAY_MS
    )
end

local function should_start_seal_twist(me, target)
    if runtime.twist_state ~= "idle" then
        return false
    end

    local twist_seal_id, twist_seal_name = can_consider_seal_twist(me, target)
    if not twist_seal_id then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    if should_hold_for_crusader_strike(me, target) then
        return false
    end
    if not utils.is_next_swing_within_ms(me, menu.seal_twist_window:get(), SEAL_TWIST_INPUT_DELAY_MS) then
        return false
    end
    local required_cooldown = menu.seal_twist_cooldown:get() / 1000
    if (_core_time() - runtime.last_twist_at) < required_cooldown then
        return false
    end

    runtime.twist_seal_id = twist_seal_id
    runtime.twist_seal_name = twist_seal_name
    return true
end

local function begin_seal_twist(me, target)
    if not should_start_seal_twist(me, target) then
        return false
    end
    if utils.cast_self_fast(runtime.twist_seal_id, me) then
        runtime.twist_state = "twist_pending"
        runtime.twist_state_changed_at = _core_time()
        runtime.last_twist_at = _core_time()
        runtime.twist_target_guid = get_unit_guid(target)
        utils.log_debug(menu, "Seal twist -> " .. tostring(runtime.twist_seal_name))
        note_cast()
        return true
    end
    return false
end

local function continue_seal_twist(me, target)
    if runtime.twist_state == "idle" then
        return false
    end

    if not me or not me:is_valid() or not me:is_in_combat() then
        reset_twist_state()
        return false
    end

    local twist_target_guid = runtime.twist_target_guid
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        reset_twist_state()
        return false
    end
    if twist_target_guid and twist_target_guid ~= get_unit_guid(target) then
        reset_twist_state()
        return false
    end

    if runtime.twist_state == "twist_pending" then
        if has_active_twist_seal(me) then
            runtime.twist_state = "twist_active"
            runtime.twist_state_changed_at = _core_time()
        elseif (_core_time() - runtime.twist_state_changed_at) > SEAL_TWIST_CONFIRM_TIMEOUT_S then
            reset_twist_state()
        end
        return false
    end

    if runtime.twist_state == "twist_active" then
        if not is_gcd_ready() then
            return false
        end
        local baseline_seal_id, baseline_seal_name = get_preferred_seal()
        if baseline_seal_id and utils.cast_self_fast(baseline_seal_id, me) then
            runtime.twist_state = "baseline_pending"
            runtime.twist_state_changed_at = _core_time()
            utils.log_debug(menu, "Seal twist -> " .. tostring(baseline_seal_name))
            note_cast()
            return true
        end
        return false
    end

    if runtime.twist_state == "baseline_pending" then
        if has_baseline_seal(me) then
            reset_twist_state()
        elseif should_reseal_baseline_now(me, target) then
            local baseline_seal_id, baseline_seal_name = get_preferred_seal()
            if baseline_seal_id and utils.cast_self_fast(baseline_seal_id, me) then
                runtime.twist_state_changed_at = _core_time()
                utils.log_debug(menu, "Seal twist -> " .. tostring(baseline_seal_name))
                note_cast()
                return true
            end
        elseif (_core_time() - runtime.twist_state_changed_at) > SEAL_TWIST_CONFIRM_TIMEOUT_S then
            reset_twist_state()
        end
    end

    return false
end

local function reset_pre_pull_state()
    runtime.pre_pull_state = "idle"
    runtime.pre_pull_state_changed_at = 0
    runtime.pre_pull_target_guid = nil
end

local function ensure_baseline_seal(me)
    if runtime.twist_state ~= "idle" then
        return false
    end
    local seal_id, seal_name, seal_key = get_preferred_seal()
    if not seal_id then
        return false
    end
    if seal_key == "blood" and utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD) then return false end
    if seal_key == "command" and utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then return false end
    if seal_key == "righteous" and utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then return false end
    if not is_gcd_ready() then return false end
    if utils.cast_self(seal_id, me) then
        note_cast()
        utils.log_debug(menu, "Seal baseline -> " .. tostring(seal_name))
        return true
    end
    return false
end

local function has_baseline_seal(me)
    local _, _, baseline_seal_key = get_preferred_seal()
    return (baseline_seal_key == "blood" and utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD))
        or (baseline_seal_key == "command" and utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND))
        or (baseline_seal_key == "righteous" and utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS))
end

local function should_reseal_baseline_now(me, target)
    if runtime.twist_state ~= "idle" then
        return false
    end
    if not me or not me:is_valid() or not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if has_baseline_seal(me) then
        return false
    end
    if should_hold_for_crusader_strike(me, target) then
        return false
    end
    return utils.is_next_swing_within_ms(me, menu.seal_twist_window:get(), SEAL_TWIST_INPUT_DELAY_MS)
end

local function selected_judgement_key(me)
    if menu.judgement_choice:get() == 2 then
        return "crusader"
    end
    if menu.judgement_choice:get() == 3 then
        return "light"
    end
    return "wisdom"
end

local function get_requested_judgement_profile(me)
    local key = selected_judgement_key(me)
    if key == "crusader" and runtime.judgement_ids.crusader and runtime.seal_crusader_id then
        return {
            key = key,
            debuff_ids = spells.DEBUFF_JUDGEMENT_OF_THE_CRUSADER,
            seal_id = runtime.seal_crusader_id,
            seal_buff = spells.BUFF_SEAL_OF_THE_CRUSADER,
            seal_label = "Seal of the Crusader",
            judgement_label = "Judgement of the Crusader",
        }
    end
    if key == "light" and runtime.judgement_ids.light and runtime.seal_light_id then
        return {
            key = key,
            debuff_ids = spells.DEBUFF_JUDGEMENT_OF_LIGHT,
            seal_id = runtime.seal_light_id,
            seal_buff = spells.BUFF_SEAL_OF_LIGHT,
            seal_label = "Seal of Light",
            judgement_label = "Judgement of Light",
        }
    end
    if key == "wisdom" and runtime.judgement_ids.wisdom and runtime.seal_wisdom_id then
        return {
            key = key,
            debuff_ids = spells.DEBUFF_JUDGEMENT_OF_WISDOM,
            seal_id = runtime.seal_wisdom_id,
            seal_buff = spells.BUFF_SEAL_OF_WISDOM,
            seal_label = "Seal of Wisdom",
            judgement_label = "Judgement of Wisdom",
        }
    end
    return nil
end

local function can_consider_pre_pull_judgement(me, target)
    if not menu.use_judgement:get_state() then
        return nil
    end
    if not me or not me:is_valid() or me:is_in_combat() then
        return nil
    end
    if not target or not target:is_valid() or target:is_dead() or not me:can_attack(target) then
        return nil
    end
    if selected_judgement_key(me) ~= "crusader" then
        return nil
    end
    local profile = get_requested_judgement_profile(me)
    if not profile or not profile.seal_id or not profile.seal_buff then
        return nil
    end
    if utils.has_buff(me, profile.seal_buff) then
        return nil
    end
    return profile
end

local function continue_pre_pull_judgement(me, target)
    if runtime.pre_pull_state == "idle" then
        return false
    end
    if not me or not me:is_valid() or me:is_in_combat() then
        reset_pre_pull_state()
        return false
    end
    if not target or not target:is_valid() or target:is_dead() or not me:can_attack(target) then
        reset_pre_pull_state()
        return false
    end
    if runtime.pre_pull_target_guid and runtime.pre_pull_target_guid ~= get_unit_guid(target) then
        reset_pre_pull_state()
        return false
    end
    if runtime.pre_pull_state == "seal_pending" then
        if utils.has_buff(me, spells.BUFF_SEAL_OF_THE_CRUSADER) then
            runtime.pre_pull_state = "judgement_pending"
            runtime.pre_pull_state_changed_at = _core_time()
        elseif (_core_time() - runtime.pre_pull_state_changed_at) > PRE_PULL_CONFIRM_TIMEOUT_S then
            reset_pre_pull_state()
        end
        return false
    end
    if runtime.pre_pull_state == "judgement_pending" then
        if utils.get_debuff_remaining_ms(target, spells.DEBUFF_JUDGEMENT_OF_THE_CRUSADER) > 0 then
            runtime.pre_pull_state = "baseline_pending"
            runtime.pre_pull_state_changed_at = _core_time()
        elseif (_core_time() - runtime.pre_pull_state_changed_at) > PRE_PULL_CONFIRM_TIMEOUT_S then
            reset_pre_pull_state()
        end
        return false
    end
    if runtime.pre_pull_state == "baseline_pending" then
        local seal_id, seal_name, seal_key = get_preferred_seal()
        local has_baseline = (seal_key == "blood" and utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD))
            or (seal_key == "command" and utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND))
            or (seal_key == "righteous" and utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS))
        if is_gcd_ready() and seal_id and not has_baseline then
            if utils.cast_self(seal_id, me) then
                note_cast()
                utils.log_debug(menu, "Pre-pull -> " .. tostring(seal_name))
                reset_pre_pull_state()
                return true
            end
        end
        if (_core_time() - runtime.pre_pull_state_changed_at) > PRE_PULL_CONFIRM_TIMEOUT_S then
            reset_pre_pull_state()
        end
    end
    return false
end

local function maybe_start_pre_pull_judgement(me, target)
    local profile = can_consider_pre_pull_judgement(me, target)
    if not profile then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    if utils.get_mana_pct(me) < 0.20 then
        return false
    end
    if runtime.pre_pull_state ~= "idle" then
        return false
    end
    if utils.cast_self(profile.seal_id, me) then
        runtime.pre_pull_state = "seal_pending"
        runtime.pre_pull_state_changed_at = _core_time()
        runtime.pre_pull_target_guid = get_unit_guid(target)
        note_cast()
        utils.log_debug(menu, "Pre-pull -> Seal of the Crusader")
        return true
    end
    return false
end


-- --- Consecration (v1.6) ------------------------------------------------------
-- AoE threat + DPS; also used in single-target as filler when everything else is on CD

local function try_hand_of_freedom(me)
    if not menu.use_hand_of_freedom:get_state() then return false end
    if not runtime.hand_of_freedom_id then return false end
    if not utils.can_cast_self(runtime.hand_of_freedom_id, me) then return false end

    local include_slows = menu.hof_include_slows:get_state()
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local unit = objects[i]
        if unit and unit:is_valid() and unit:is_unit() and not unit:is_dead()
            and (utils.same_unit(me, unit) or unit:is_party_member()) then
            local is_root = unit:is_rooted(500)
            local is_slow = include_slows and unit:is_slowed(0.30, 500)
            if is_root or is_slow then
                if not utils.has_buff(unit, spells.BUFF_HAND_OF_FREEDOM) then
                    if utils.cast_unit(runtime.hand_of_freedom_id, me, unit) then
                        note_cast()
                        utils.log_debug(menu, "Hand of Freedom -> " .. (unit.get_name and unit:get_name() or "ally"))
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function try_cleanse(me)
    if not menu.use_cleanse or not menu.use_cleanse:get_state() then return false end
    local cleanse_id = runtime.cleanse_id or runtime.purify_id
    if not cleanse_id then return false end
    local units = { me }
    local party_units = utils.get_party_units and utils.get_party_units(me) or {}
    for i = 1, #party_units do
        units[#units + 1] = party_units[i]
    end
    local best_target = select(1, dispel_engine.find_best_target({
        candidates = units,
        priorities = {
            { type_def = { numeric = MAGIC_DISPEL_TYPE, name = "magic" }, label = "Cleanse" },
            { type_def = { numeric = DISEASE_DISPEL_TYPE, name = "disease" }, label = "Cleanse" },
            { type_def = { numeric = POISON_DISPEL_TYPE, name = "poison" }, label = "Cleanse" },
        },
        get_hp = function(unit) return utils.get_health_pct(unit) end,
    }))
    if best_target and utils.can_cast_target(cleanse_id, me, best_target) and utils.cast_target(cleanse_id, best_target) then
        note_cast()
        utils.log_debug(menu, "Cleanse -> " .. (best_target.get_name and best_target:get_name() or "ally"))
        return true
    end
    return false
end

local function try_consecration(me, target)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_consecration or not menu.use_consecration:get_state() then return false end
    if not runtime.consecration_id then return false end
    if not utils.is_melee_target(me, target) then return false end
    if should_hold_for_seal_twist(me, target) then return false end
    if not utils.can_cast_self(runtime.consecration_id, me) then return false end
    if utils.cast_self(runtime.consecration_id, me) then
        note_cast()
        utils.log_debug(menu, "Consecration")
        return true
    end
    return false
end

-- --- Divine Favor (v1.6) - Holy Shock guaranteed crit -------------------------

local function try_divine_favor(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_divine_favor or not menu.use_divine_favor:get_state() then return false end
    if not runtime.divine_favor_id then return false end
    if not me:is_in_combat() then return false end
    if not utils.can_cast_self(runtime.divine_favor_id, me) then return false end
    if utils.cast_self_fast(runtime.divine_favor_id, me) then
        note_cast()
        utils.log_debug(menu, "Divine Favor")
        return true
    end
    return false
end

-- --- Exorcism (v1.6) - Undead / Demon only ------------------------------------

local function try_exorcism(me, target)
    if not menu.use_exorcism or not menu.use_exorcism:get_state() then return false end
    if not runtime.exorcism_id then return false end
    if should_hold_for_seal_twist(me, target) then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    -- TBC: Exorcism only works on undead and demons
    local target_type = target.get_creature_type and target:get_creature_type() or 0
    local UNDEAD, DEMON = 5, 2  -- creature type IDs
    if target_type ~= UNDEAD and target_type ~= DEMON then return false end
    if not utils.can_cast_hostile(runtime.exorcism_id, me, target) then return false end
    if utils.cast_target(runtime.exorcism_id, target, "Exorcism") then
        note_cast()
        utils.log_debug(menu, "Exorcism (undead/demon)")
        return true
    end
    return false
end

local function try_hammer_of_wrath(me, target)
    if not menu.use_hammer_of_wrath or not menu.use_hammer_of_wrath:get_state() then return false end
    if not runtime.hammer_of_wrath_id or not target or not target:is_valid() or target:is_dead() then return false end
    if should_hold_for_seal_twist(me, target) then return false end
    if utils.get_health_pct(target) > 0.20 then return false end
    if not utils.can_cast_hostile(runtime.hammer_of_wrath_id, me, target) then return false end
    if utils.cast_target(runtime.hammer_of_wrath_id, target, "Hammer of Wrath") then
        note_cast()
        utils.log_debug(menu, "Hammer of Wrath")
        esp_renderer.on_cast(runtime.hammer_of_wrath_id, "Hammer of Wrath", color.orange(220))
        return true
    end
    return false
end

local function try_divine_shield_emergency(me)
    if not menu.use_divine_shield:get_state() or not runtime.divine_shield_id then
        return false
    end
    if not me or not me:is_valid() or me:is_dead() then
        return false
    end

    local hp_threshold = menu.use_divine_shield_hp_pct:get() / 100
    if utils.get_health_pct(me) > hp_threshold then
        return false
    end
    if not utils.can_cast_self(runtime.divine_shield_id, me) then
        return false
    end
    if utils.cast_self(runtime.divine_shield_id, me) then
        invalidate_ctx()
        utils.log_debug(menu, "Divine Shield")
        return true
    end
    return false
end


local function maybe_cast_judgement(me, target)
    if not menu.use_judgement:get_state() then
        return false
    end
    if not me:is_in_combat() and selected_judgement_key(me) == "crusader" then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        return false
    end
    if should_hold_for_seal_twist(me, target) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end

    local profile = get_requested_judgement_profile(me)
    if not profile or not runtime.judgement_spell_id then
        return false
    end
    if profile.debuff_ids and utils.get_debuff_remaining_ms(target, profile.debuff_ids) > 4000 then
        return false
    end
    local has_required_seal = profile.seal_buff and utils.has_buff(me, profile.seal_buff)
    if not has_required_seal then
        if profile.seal_id and utils.can_cast_self(profile.seal_id, me) and utils.cast_self(profile.seal_id, me) then
            note_cast()
            utils.log_debug(menu, profile.seal_label)
            runtime.pending_judgement_until = _core_time() + POST_JUDGEMENT_RESEAL_DELAY_S
            return true
        end
        return false
    end
    if not utils.can_cast_hostile(runtime.judgement_spell_id, me, target) then
        return false
    end
    if utils.cast_target(runtime.judgement_spell_id, target) then
        runtime.pending_judgement_until = 0
        runtime.pending_baseline_reseal_until = _core_time() + POST_JUDGEMENT_RESEAL_DELAY_S
        note_cast()
        utils.log_debug(menu, profile.judgement_label)
        esp_renderer.on_cast(runtime.judgement_spell_id, profile.judgement_label, color.yellow(220))
        return true
    end
    return false
end

local function maybe_cast_crusader_strike(me, target)
    if not menu.use_crusader_strike:get_state() then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        return false
    end
    if should_hold_for_seal_twist(me, target) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    if not runtime.crusader_strike_id then
        return false
    end
    if not utils.can_cast_hostile(runtime.crusader_strike_id, me, target) then
        return false
    end
    if utils.cast_target(runtime.crusader_strike_id, target) then
        note_cast()
        utils.log_debug(menu, "Crusader Strike")
                esp_renderer.on_cast(runtime.crusader_strike_id, "Crusader Strike", color.gold(220))
        return true
    end
    return false
end

local function is_aoe_rotation(enemy_count)
    return enemy_count >= 3 and (not enc or enc.aoe_safe)
end

resolve_spells()
log_resolved_spells()


-- --- Offensive CDs (v1.1) -------------------------------------------------

local function try_avenging_wrath(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_avenging_wrath or not menu.use_avenging_wrath:get_state() then return false end
    if not runtime.avenging_wrath_id then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_AVENGING_WRATH) then return false end
    if not utils.can_cast_self(runtime.avenging_wrath_id, me) then return false end
    if utils.cast_self_fast(runtime.avenging_wrath_id, me) then
        note_cast()
        utils.log_debug(menu, "Avenging Wrath")
        return true
    end
    return false
end

reactive_adapter = {
    spec = "EAXPaladinRetribution",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "paladin", utils)
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

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "paladin", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = { noop = "unsupported" },
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
    handle_toggle()
    handle_rotation_hotkeys()
    if not menu.enabled:get_state() then
        return
    end

    local me = _get_local_player()
    if not me or me:is_dead() then
        return
    end
        ooc_manager.on_update(me, menu, utils, {})
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

    if ensure_aura_upkeep(me) then return end

    if utils.throttle("eaxpr:mode", MODE_REFRESH_INTERVAL) then
        refresh_mode_cache(me)
    end

    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    local target = focus_target or utils.find_best_target(me)
    -- PvP: prioritize enemy players in arena/BG/world PvP
    local pvp_instance = pvp_manager.is_in_pvp_instance()
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        local enemy_players = pvp_manager.find_enemy_players(me, 40)
        if #enemy_players > 0 then
            local priority = pvp_manager.priority_target(me, enemy_players)
            if priority then target = priority end
        end
    end
    -- Update Vengeance stacks for Seal of Vengeance tracking
    update_vengeance_stacks(target)
    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)
    local enemy_count = count_nearby_enemies(me)
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_holy_light(me) then return true end
    end
    
    if me:is_in_combat() then
        utils.ensure_melee_auto_attack(me, target)
    end

    if try_ooc_blessing(me) then return true end


    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Interrupt
    if target and target:is_valid() and me:can_attack(target) and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "paladin", utils) then
            return
        end
    end

    -- Racial CDs
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense then
        if racial_manager.try_offensive(me) then return true end
    end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end

    -- PvP cooldowns: trinket, divine shield, blessing of protection
    local pvp_instance = pvp_manager.is_in_pvp_instance()
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
        if pvp_manager.try_paladin_pvp_cooldowns(me, target) then return true end
    end

    -- Defensive abilities
    ttd_tracker.update(target)

    if try_divine_shield_emergency(me) then return true end
    if defensive_manager.try_defensive(me, "paladin", utils) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.06) and try_hand_of_freedom(me) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.06) and try_cleanse(me) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and continue_seal_twist(me, target) then
        return
    end
    if runtime.pending_judgement_until <= _core_time() and ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and ensure_baseline_seal(me) then
        return
    end
    if runtime.pending_baseline_reseal_until <= _core_time() and ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and should_reseal_baseline_now(me, target) and ensure_baseline_seal(me) then
        return
    end
    if not me:is_in_combat() and ctx and resource_gate.common.has_mana_pct(ctx, 0.20) then
        if continue_pre_pull_judgement(me, target) then
            return
        end
        if maybe_start_pre_pull_judgement(me, target) then
            return
        end
    end
    
    -- Offensive CDs
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and not hold_offense then try_avenging_wrath(me) end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and not hold_offense and try_divine_favor(me) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_hammer_of_wrath(me, target) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_exorcism(me, target) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.06) and maybe_cast_crusader_strike(me, target) then return end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.05) and maybe_cast_judgement(me, target) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.20) and try_consecration(me, target) then return end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and begin_seal_twist(me, target) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) then
        ensure_baseline_seal(me)
    end
end)


-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxpaladinretribution_space_win")
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
        local label = "Eax Paladin Ret"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        add_cb(label, menu.enabled, "eax_paladin_ret_enabled_cp")
        return elements
    end)
end


-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Paladin"
    local _eax_spec  = "Retribution"
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
core.log("[Eax Paladin Retribution] Loaded " .. (_pi and _pi.plugin_version or "?"))
