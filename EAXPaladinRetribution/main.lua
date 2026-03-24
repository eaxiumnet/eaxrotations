-- EAX Paladin Retribution | main.lua
-- Rotation logic for Seal twists, Crusader Strike, and Judgement.

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
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("pret", "Paladin Ret")
-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("smart_cast_manager")

-- Phase 04 visual telemetry wiring
local dps_meter = require("dps_meter")
local cooldown_tracker = require("cooldown_tracker")
local visual_state = require("visual_state")
local reactive_runtime = require("reactive_runtime")
local dps_risk = require("dps_risk")
local dps_runtime = require("dps_runtime")

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
        smart_cast_manager.clear_all_pending()
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
        smart_cast_manager.reset()
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
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("racial_manager")
---@type defensive_manager
local defensive_manager = require("defensive_manager")

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
    judgement_ids = {
        wisdom = nil,
        crusader = nil,
    },
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
    ooc_blessing_of_might_id = nil,
    ooc_blessing_of_wisdom_id = nil,
    hand_of_freedom_id = nil,
    divine_illumination_id = nil,
    judgement_id = nil,
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
    runtime.divine_illumination_id = utils.resolve_spell_id(spells.DIVINE_ILLUMINATION)
    runtime.lay_on_hands_id    = utils.resolve_spell_id(spells.LAY_ON_HANDS)
    runtime.crusader_strike_id = utils.resolve_spell_id(spells.CRUSADER_STRIKE)
    runtime.divine_storm_id      = utils.resolve_spell_id(spells.DIVINE_STORM)
    runtime.avenging_wrath_id    = utils.resolve_spell_id(spells.AVENGING_WRATH)
    runtime.seal_command_id = utils.resolve_spell_id(spells.SEAL_OF_COMMAND)
    runtime.seal_righteousness_id = utils.resolve_spell_id(spells.SEAL_OF_RIGHTEOUSNESS)
    runtime.seal_blood_id = utils.resolve_spell_id(spells.SEAL_OF_BLOOD)
    runtime.consecration_id = utils.resolve_spell_id(spells.CONSECRATION)
    runtime.divine_favor_id  = utils.resolve_spell_id(spells.DIVINE_FAVOR)
    runtime.exorcism_id      = utils.resolve_spell_id(spells.EXORCISM)
    runtime.redemption_id  = utils.resolve_spell_id(spells.REDEMPTION)
    runtime.hand_of_freedom_id = utils.resolve_spell_id(spells.HAND_OF_FREEDOM)
    runtime.ooc_blessing_of_might_id = utils.resolve_spell_id(spells.BLESSING_OF_MIGHT)
    runtime.ooc_blessing_of_wisdom_id = utils.resolve_spell_id(spells.BLESSING_OF_WISDOM)
    runtime.judgement_ids.wisdom = utils.resolve_spell_id(spells.JUDGEMENT_OF_WISDOM)
    runtime.judgement_ids.crusader = utils.resolve_spell_id(spells.JUDGEMENT_OF_THE_CRUSADER)
    runtime.divine_shield_id = utils.resolve_spell_id(spells.DIVINE_SHIELD)
end

local function log_resolved_spells()
    core.log("[EAX Paladin Retribution] Resolved spells: CS=" .. tostring(runtime.crusader_strike_id))
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

local function reset_twist_state()
    runtime.twist_state = "idle"
    runtime.twist_state_changed_at = 0
    runtime.twist_seal_id = nil
    runtime.twist_seal_name = nil
end

local function get_twist_seal_choice()
    if runtime.seal_blood_id and core.spell_book.is_spell_learned(runtime.seal_blood_id) then
        return runtime.seal_blood_id, "Blood"
    end
    if runtime.seal_righteousness_id and core.spell_book.is_spell_learned(runtime.seal_righteousness_id) then
        return runtime.seal_righteousness_id, "Righteousness"
    end
    return nil, nil
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
    if not runtime.seal_command_id or not twist_seal_id then
        return nil, nil
    end
    if not utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
        return nil, nil
    end
    if twist_seal_name == "Blood" and utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD) then
        return nil, nil
    end
    if twist_seal_name == "Righteousness" and utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then
        return nil, nil
    end
    if utils.get_mana_pct(me) < SEAL_TWIST_MANA_RESERVE then
        return nil, nil
    end

    return twist_seal_id, twist_seal_name
end

local function has_active_twist_seal(me)
    if not me or not me:is_valid() then
        return false
    end

    if runtime.twist_seal_name == "Blood" then
        return utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD)
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
        utils.log_debug(menu, "Seal twist -> " .. tostring(runtime.twist_seal_name))
        note_cast()
        return true
    end
    return false
end

local function continue_seal_twist(me)
    if runtime.twist_state == "idle" then
        return false
    end

    if not me or not me:is_valid() or not me:is_in_combat() then
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
        if utils.cast_self_fast(runtime.seal_command_id, me) then
            runtime.twist_state = "command_pending"
            runtime.twist_state_changed_at = _core_time()
            utils.log_debug(menu, "Seal twist -> Command")
            note_cast()
            return true
        end
        return false
    end

    if runtime.twist_state == "command_pending" then
        if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
            reset_twist_state()
        elseif (_core_time() - runtime.twist_state_changed_at) > SEAL_TWIST_CONFIRM_TIMEOUT_S then
            reset_twist_state()
        end
    end

    return false
end

local function ensure_command_active(me)
    if runtime.twist_state ~= "idle" then
        return false
    end
    if not runtime.seal_command_id then
        return false
    end
    if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end
    if utils.cast_self(runtime.seal_command_id, me) then
        note_cast()
        utils.log_debug(menu, "Seal: Command baseline")
        return true
    end
    return false
end

local function selected_judgement_key()
    if menu.judgement_choice:get() == 2 then
        return "crusader"
    end
    return "wisdom"
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

local function try_divine_illumination(me)
    if not menu.use_divine_illumination or not menu.use_divine_illumination:get_state() then return false end
    if not runtime.divine_illumination_id then return false end
    if not me:is_in_combat() then return false end
    if utils.get_mana_pct(me) > 0.30 then return false end
    if not utils.can_cast_self(runtime.divine_illumination_id, me) then return false end
    if utils.cast_self_fast(runtime.divine_illumination_id, me) then
        note_cast()
        utils.log_debug(menu, "Divine Illumination")
        return true
    end
    return false
end

-- --- Exorcism (v1.6) - Undead / Demon only ------------------------------------

local function try_exorcism(me, target)
    if not menu.use_exorcism or not menu.use_exorcism:get_state() then return false end
    if not runtime.exorcism_id then return false end
    if should_hold_for_seal_twist(me, target) then return false end
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
    if not target or not target:is_valid() or target:is_dead() or not utils.is_melee_target(me, target) then
        return false
    end
    if should_hold_for_seal_twist(me, target) then
        return false
    end
    if not is_gcd_ready() then
        return false
    end

    local mode_key = selected_judgement_key()
    local spell_id = runtime.judgement_id or runtime.judgement_ids[mode_key]
    if not spell_id then
        return false
    end
    if not utils.can_cast_hostile(spell_id, me, target) then
        return false
    end
    if utils.cast_target(spell_id, target) then
        note_cast()
        utils.log_debug(menu, "Judgement -> " .. (mode_key == "crusader" and "Crusader" or "Wisdom"))
                esp_renderer.on_cast(spell_id, "Judgement", color.yellow(220))
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

local function try_divine_storm(me, target, enemy_count)
    -- Divine Storm (53385) is a WotLK spell — not available in TBC. No-op.
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
    esp_renderer.on_render(menu)
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
        ooc_manager.on_update(me, menu, utils, {
        group_buffs = {
            { spell_id = runtime.ooc_blessing_of_might_id,
               buff_ids = spells.BUFF_BLESSING_OF_MIGHT,
               name = "Blessing of Might",
               toggle = menu.ooc_group_buff },
            { spell_id = runtime.ooc_blessing_of_wisdom_id,
               buff_ids = spells.BUFF_BLESSING_OF_WISDOM,
               name = "Blessing of Wisdom",
               toggle = menu.ooc_group_buff },
        },
    })
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

    if utils.throttle("eaxpr:mode", MODE_REFRESH_INTERVAL) then
        refresh_mode_cache(me)
    end

    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and not me:can_attack(focus_target) then focus_target = nil end
    local target = focus_target or utils.find_best_target(me)
    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)
    local enemy_count = count_nearby_enemies(me)
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_holy_light then try_holy_light(me, me) end
    end
    
    if me:is_in_combat() then
        utils.ensure_melee_auto_attack(me, target)
    end


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
        racial_manager.try_offensive(me)
    end
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    -- Defensive abilities
    ttd_tracker.update(target)

    if try_divine_shield_emergency(me) then return true end
    if defensive_manager.try_defensive(me, "paladin", utils) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.06) and try_hand_of_freedom(me) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and continue_seal_twist(me) then
        return
    end

    -- Offensive CDs
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and not hold_offense then try_avenging_wrath(me) end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.20) and try_divine_illumination(me) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and not hold_offense and try_divine_favor(me) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) and is_aoe_rotation(enemy_count) and try_divine_storm(me, target, enemy_count) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_hammer_of_wrath(me, target) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.12) and try_exorcism(me, target) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.06) and maybe_cast_crusader_strike(me, target) then return end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.05) and maybe_cast_judgement(me, target) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) and is_aoe_rotation(enemy_count) and try_divine_storm(me, target, enemy_count) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.20) and try_consecration(me, target) then return end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and begin_seal_twist(me, target) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) then
        ensure_command_active(me)
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
        if menu.enabled:get_state() then
            if menu.focus_priority then
                add_cb("  PRt Focus", menu.focus_priority, "eax_paladin_ret_focus_cp")
            end
            if menu.use_racial then
                add_cb("  PRt Racial", menu.use_racial, "eax_paladin_ret_racial_cp")
            end
            if menu.use_seal_twist then
                add_cb("  PRt Twist", menu.use_seal_twist, "eax_paladin_ret_twist_cp")
            end
            if menu.use_consecration then
                add_cb("  PRt Consecration", menu.use_consecration, "eax_paladin_ret_consecration_cp")
            end
            if menu.use_exorcism then
                add_cb("  PRt Exorcism", menu.use_exorcism, "eax_paladin_ret_exorcism_cp")
            end
            if menu.use_hand_of_freedom then
                add_cb("  PRt Freedom", menu.use_hand_of_freedom, "eax_paladin_ret_freedom_cp")
            end
        end
        return elements
    end)
end


-- -- EAX Conflict Detection -------------------------------------------------
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
core.log("[EAX Paladin Retribution] Loaded " .. (_pi and _pi.plugin_version or "?"))
