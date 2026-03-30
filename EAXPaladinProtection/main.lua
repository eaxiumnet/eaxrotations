-- Eax PaladinProtection | main.lua
-- Core rotation wiring for Protection Paladin survival and threat management.

local menu = require("menu")
local rotation_context = require("rotation_context")
local resource_gate = require("resource_gate")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")
local dispel_engine = require("dispel_engine")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type key_helper
local key_helper = require("common/utility/key_helper")

if not utils.same_unit then
    function utils.same_unit(a, b)
        return a ~= nil and a == b
    end
end

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
esp_renderer.init("pprot", "Paladin Prot")
-- Smart Cast Manager - addresses spam/sluggishness
local smart_cast_manager = require("smart_cast_manager")

-- Phase 04 visual telemetry wiring
local dps_meter = require("dps_meter")
local cooldown_tracker = require("cooldown_tracker")
local visual_state = require("visual_state")
local reactive_runtime = require("reactive_runtime")
local tank_recovery = require("tank_recovery")

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
        spec = "EAXPaladinProtection",
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

---@type color
local color = require("color")

local MODE_AUTO = "auto"
local MODE_SOLO = "solo"
local MODE_DUNGEON = "dungeon"
local MODE_RAID = "raid"
local MODE_DETECT_INTERVAL = 1.5
local UPDATE_INTERVAL = 0.12
local NOTIFICATION_LABEL = "Eax Paladin Protection"

local runtime = {
    divine_shield_id = nil,
    redemption_id = nil,
    hammer_of_justice_id = nil,
    righteous_fury_id = nil,
    holy_shield_id = nil,
    consecration_id = nil,
    avengers_shield_id = nil,
    judgement_id = nil,
    seal_of_righteousness_id = nil,
    seal_of_wisdom_id = nil,
    seal_of_the_crusader_id = nil,
    seal_of_light_id = nil,
    exorcism_id = nil,
    cached_mode = MODE_SOLO,
    mode_checked_at = 0,
    last_update_at = 0,
    prev_toggle_state = false,
    last_blessings_key_state = false,
    last_holy_shield_key_state = false,
    last_consecration_key_state = false,
    last_avengers_key_state = false,
    last_freedom_key_state = false,
    ooc_blessing_of_might_id = nil,
    ooc_blessing_of_wisdom_id = nil,
    ooc_blessing_of_sanctuary_id = nil,
    hand_of_freedom_id = nil,
    cleanse_id = nil,
    purify_id = nil,
    holy_wrath_id = nil,
    lay_on_hands_id = nil,
    pending_reseal_until = 0,
    last_blessing_target_guid = nil,
    last_blessing_name = nil,
    last_blessing_at = 0,
    last_blessing_retry_at = {},
    last_aura_cast_at = 0,
}

local ctx_cache = rotation_context.new({
    important_buffs = {
        spells.BUFF_RIGHTEOUS_FURY,
        spells.BUFF_HOLY_SHIELD,
        spells.BUFF_SEAL_OF_RIGHTEOUSNESS,
        spells.BUFF_SEAL_OF_WISDOM,
        spells.BUFF_SEAL_OF_THE_CRUSADER,
        spells.BUFF_SEAL_OF_LIGHT,
    },
    important_debuffs = {},
})

local function note_cast()
    rotation_context.invalidate(ctx_cache)
end

local MAGIC_DISPEL_TYPE = 1
local DISEASE_DISPEL_TYPE = 3
local POISON_DISPEL_TYPE = 4
local JUDGEMENT_REFRESH_MS = 4000
local BLESSING_RETRY_WINDOW = 6.0
local AURA_RETRY_WINDOW = 12.0

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

local function invalidate_ctx()
    rotation_context.invalidate(ctx_cache)
end

local GROUP_ROLE_TANK = 0
local GROUP_ROLE_HEALER = 1
local GROUP_ROLE_DAMAGER = 2

local function resolve_spells()
    runtime.righteous_fury_id = utils.resolve_spell_id(spells.RIGHTEOUS_FURY)
    runtime.holy_shield_id = utils.resolve_spell_id(spells.HOLY_SHIELD)
    runtime.divine_shield_id = utils.resolve_spell_id(spells.DIVINE_SHIELD)
    runtime.holy_wrath_id = utils.resolve_spell_id(spells.HOLY_WRATH)
    runtime.consecration_id = utils.resolve_spell_id(spells.CONSECRATION)
    runtime.avengers_shield_id = utils.resolve_spell_id(spells.AVENGERS_SHIELD)
    runtime.judgement_id = utils.resolve_spell_id(spells.JUDGEMENT)
    runtime.seal_of_righteousness_id = utils.resolve_spell_id(spells.SEAL_OF_RIGHTEOUSNESS)
    runtime.seal_of_wisdom_id = utils.resolve_spell_id(spells.SEAL_OF_WISDOM)
    runtime.seal_of_the_crusader_id = utils.resolve_spell_id(spells.SEAL_OF_THE_CRUSADER)
    runtime.seal_of_light_id = utils.resolve_spell_id(spells.SEAL_OF_LIGHT)
    runtime.exorcism_id = utils.resolve_spell_id(spells.EXORCISM)
    runtime.hammer_of_justice_id = utils.resolve_spell_id(spells.HAMMER_OF_JUSTICE)
    runtime.lay_on_hands_id = utils.resolve_spell_id(spells.LAY_ON_HANDS)
    runtime.redemption_id  = utils.resolve_spell_id(spells.REDEMPTION)
    runtime.hand_of_freedom_id = utils.resolve_spell_id(spells.HAND_OF_FREEDOM)
    runtime.ooc_blessing_of_might_id = utils.resolve_spell_id(spells.BLESSING_OF_MIGHT)
    runtime.ooc_blessing_of_wisdom_id = utils.resolve_spell_id(spells.BLESSING_OF_WISDOM)
    runtime.ooc_blessing_of_sanctuary_id = utils.resolve_spell_id(spells.BLESSING_OF_SANCTUARY)
    runtime.cleanse_id = utils.resolve_spell_id(spells.CLEANSE)
    runtime.purify_id = utils.resolve_spell_id(spells.PURIFY)
end

local function refresh_mode_cache(now)
    if (now - runtime.mode_checked_at) < MODE_DETECT_INTERVAL then
        return
    end
    local me = _get_local_player()
    runtime.cached_mode = me and utils.detect_mode(me) or runtime.cached_mode or MODE_SOLO
    runtime.mode_checked_at = now
end

local function get_effective_mode()
    local selection = menu.mode:get()
    if selection == 2 then
        return MODE_SOLO
    elseif selection == 3 then
        return MODE_DUNGEON
    elseif selection == 4 then
        return MODE_RAID
    end
    return runtime.cached_mode or MODE_SOLO
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

local function notify_cast(unique_id, message, notification_color)
    if not menu.show_notifications:get_state() then
        return
    end

    if core.graphics.is_notification_active(unique_id) then
        return
    end

    core.graphics.add_notification(
        unique_id,
        NOTIFICATION_LABEL,
        message,
        0.8,
        notification_color or color.gold(220)
    )
end

local function ensure_righteous_fury(me)
    if not menu.use_righteous_fury:get_state() or not runtime.righteous_fury_id then
        return false
    end

    if utils.has_buff(me, spells.BUFF_RIGHTEOUS_FURY) then
        return false
    end

    if utils.can_cast_self(runtime.righteous_fury_id, me) and utils.cast_self(runtime.righteous_fury_id, me) then
        note_cast()
        utils.log_debug(menu, "Cast Righteous Fury")
        notify_cast("paladin:rf", "Righteous Fury", color.gold(220))
        return true
    end

    return false
end

local function ensure_holy_shield(me, target)
    if not menu.use_holy_shield:get_state() or not runtime.holy_shield_id then
        return false
    end

    if not target or not target:is_valid() or target:is_dead() then
        return false
    end

    if me:is_in_combat() and not utils.is_melee_target(me, target) then
        return false
    end

    if utils.has_buff(me, spells.BUFF_HOLY_SHIELD) then
        return false
    end

    if utils.can_cast_self(runtime.holy_shield_id, me) and utils.cast_self(runtime.holy_shield_id, me) then
        note_cast()
        utils.log_debug(menu, "Cast Holy Shield")
        notify_cast("paladin:holy_shield", "Holy Shield", color.blue(220))
        return true
    end

    return false
end

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

local function try_cleanse(me, target)
    if not menu.use_dispels:get_state() then return false end
    local cleanse_id = runtime.cleanse_id or runtime.purify_id
    if not cleanse_id then return false end
    local units = { me }
    local party_units = utils.get_party_units and utils.get_party_units(me) or {}
    for i = 1, #party_units do
        units[#units + 1] = party_units[i]
    end
    local preferred = (target and target:is_valid() and not target:is_dead() and (utils.same_unit(me, target) or (target.is_party_member and target:is_party_member()))) and target or nil
    local best_target = select(1, dispel_engine.find_best_target({
        candidates = units,
        preferred_target = preferred,
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

local function ensure_aura_upkeep(me)
    if not menu.use_aura or not menu.use_aura:get_state() then
        return false
    end
    if not runtime.last_aura_cast_at then
        runtime.last_aura_cast_at = 0
    end
    if utils.has_buff(me, spells.BUFF_DEVOTION_AURA)
        or utils.has_buff(me, spells.BUFF_RETRIBUTION_AURA)
        or utils.has_buff(me, spells.BUFF_CONCENTRATION_AURA)
    then
        return false
    end
    if (_core_time() - runtime.last_aura_cast_at) < AURA_RETRY_WINDOW then
        return false
    end
    local aura_id = utils.resolve_spell_id(spells.DEVOTION_AURA)
    if not aura_id then
        return false
    end
    if utils.can_cast_self(aura_id, me) and utils.cast_self(aura_id, me) then
        runtime.last_aura_cast_at = _core_time()
        note_cast()
        utils.log_debug(menu, "Devotion Aura")
        return true
    end
    return false
end

local function try_consecration(me, enemy_count)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_consecration:get_state() or not runtime.consecration_id then
        return false
    end

    local consecration_enemy_count = menu.consecration_enemy_count:get()
    local mana_pct = utils.get_mana_pct(me)

    if enemy_count < consecration_enemy_count then
        if enemy_count ~= 1 then
            return false
        end

        if mana_pct < 0.60 then
            return false
        end

        if not utils.is_melee_target(me, me:get_target()) then
            return false
        end
    end

    if mana_pct < 0.20 then
        return false
    end

    if utils.can_cast_self(runtime.consecration_id, me) and utils.cast_self(runtime.consecration_id, me) then
        note_cast()
        utils.log_debug(menu, "Cast Consecration")
        notify_cast("paladin:consecration", "Consecration", color.red(220))
                esp_renderer.on_cast(nil, "Consecration", color.yellow(220))
        return true
    end

	return false
end

local function get_target_ttd_s(target)
	local ttd = tonumber(ttd_tracker.get(target))
	return ttd or 0
end

local function is_durable_judgement_target(target)
	if not target or not target:is_valid() or target:is_dead() then
		return false
	end
	local min_ttd = menu.judgement_target_ttd and menu.judgement_target_ttd:get() or 10
	local ttd = get_target_ttd_s(target)
	return ttd == 999 or ttd >= min_ttd
end

local function get_active_seal_key(me)
	if utils.has_buff(me, spells.BUFF_SEAL_OF_THE_CRUSADER) then
		return "crusader"
	end
	if utils.has_buff(me, spells.BUFF_SEAL_OF_WISDOM) then
		return "wisdom"
	end
	if utils.has_buff(me, spells.BUFF_SEAL_OF_RIGHTEOUSNESS) then
		return "righteous"
	end
	return nil
end

local function get_judgement_assignment_key(me)
	local assignment = menu.judgement_assignment and menu.judgement_assignment:get() or 1
	if assignment == 2 then
		return "wisdom"
	end
	if assignment == 3 then
		return "crusader"
	end

	local mode = get_effective_mode()
	if mode == MODE_SOLO and utils.get_mana_pct(me) >= 0.35 and runtime.seal_of_the_crusader_id then
		return "crusader"
	end
	return "wisdom"
end

local function get_judgement_debuff_ids(key)
	if key == "crusader" then
		return spells.DEBUFF_JUDGEMENT_OF_THE_CRUSADER
	end
	if key == "wisdom" then
		return spells.DEBUFF_JUDGEMENT_OF_WISDOM
	end
	return nil
end

local function get_assigned_seal_profile(me, target)
	if not menu.use_judgement:get_state() or not runtime.judgement_id then
		return nil, nil, nil
	end
	if not is_durable_judgement_target(target) then
		return nil, nil, nil
	end

	local assignment_key = get_judgement_assignment_key(me)
	local assignment_debuff = get_judgement_debuff_ids(assignment_key)
	if assignment_debuff and utils.get_debuff_remaining_ms(target, assignment_debuff) > JUDGEMENT_REFRESH_MS then
		return nil, nil, nil
	end

	if assignment_key == "crusader" and runtime.seal_of_the_crusader_id then
		return runtime.seal_of_the_crusader_id, spells.BUFF_SEAL_OF_THE_CRUSADER, "Seal of the Crusader"
	end
	if assignment_key == "wisdom" and runtime.seal_of_wisdom_id then
		return runtime.seal_of_wisdom_id, spells.BUFF_SEAL_OF_WISDOM, "Seal of Wisdom"
	end

	return nil, nil, nil
end

local function get_desired_seal_profile(me, target)
	local assignment_seal_id, assignment_buff_ids, assignment_label = get_assigned_seal_profile(me, target)
	if assignment_seal_id then
		return assignment_seal_id, assignment_buff_ids, assignment_label
	end

	local mana_pct = utils.get_mana_pct(me)
	local hp_pct = (me and me.get_health_percentage and me:get_health_percentage() or 100) / 100
	local defensive_sustain = me and me:is_in_combat() and (hp_pct <= 0.45 or mana_pct <= 0.12)

	if defensive_sustain and runtime.seal_of_light_id then
		return runtime.seal_of_light_id, spells.BUFF_SEAL_OF_LIGHT, "Seal of Light"
	end

	if mana_pct <= 0.18 and runtime.seal_of_wisdom_id then
        return runtime.seal_of_wisdom_id, spells.BUFF_SEAL_OF_WISDOM, "Seal of Wisdom"
    end

    if runtime.seal_of_righteousness_id then
        return runtime.seal_of_righteousness_id, spells.BUFF_SEAL_OF_RIGHTEOUSNESS, "Seal of Righteousness"
    end

	return nil, nil, nil
end

local function ensure_active_seal(me, target)
	local seal_id, seal_buff_ids, seal_label = get_desired_seal_profile(me, target)
	if not seal_id then
		return false
	end

    local now = _core_time()
    if runtime.pending_reseal_until > 0 and now >= runtime.pending_reseal_until then
        runtime.pending_reseal_until = 0
    end

    if seal_buff_ids and utils.has_buff(me, seal_buff_ids) then
        runtime.pending_reseal_until = 0
        return false
    end

    if utils.can_cast_self(seal_id, me) and utils.cast_self(seal_id, me) then
        runtime.pending_reseal_until = 0
        note_cast()
        utils.log_debug(menu, seal_label)
        notify_cast("paladin:active_seal", seal_label, color.gold(220))
        return true
    end

    return false
end

local function try_avengers_shield(me, target, mode)
    if not menu.use_avengers_shield:get_state() or not runtime.avengers_shield_id then
        return false
    end

    if not target then
        return false
    end

    if me:is_in_combat() and utils.is_melee_target(me, target) then
        return false
    end

    if utils.can_cast_hostile(runtime.avengers_shield_id, me, target) then
        if utils.cast_target(runtime.avengers_shield_id, target) then
            note_cast()
            utils.log_debug(menu, "Cast Avenger's Shield")
            notify_cast("paladin:avengers_shield", "Avenger's Shield", color.green(220))
                    esp_renderer.on_cast(nil, "Avenger's Shield", color.gold(220))
        return true
        end
    end

    return false
end

local function try_judgement(me, target)
	if not menu.use_judgement:get_state() or not runtime.judgement_id or not target then
		return false
	end

	local mana_pct = utils.get_mana_pct(me)
	local active_seal = get_active_seal_key(me)
	local judgement_label = "Judgement"
	local should_cast = false

	if is_durable_judgement_target(target) then
		local assignment_key = get_judgement_assignment_key(me)
		local assignment_debuff = get_judgement_debuff_ids(assignment_key)
		local assignment_remaining = assignment_debuff and utils.get_debuff_remaining_ms(target, assignment_debuff) or 0

		if assignment_remaining <= JUDGEMENT_REFRESH_MS and active_seal == assignment_key then
			should_cast = true
			judgement_label = assignment_key == "crusader" and "Judgement of the Crusader" or "Judgement of Wisdom"
		end
	end

	if not should_cast then
		if me:is_in_combat() and mana_pct >= 0.55 then
			return false
		end
		if active_seal == "wisdom" and utils.get_debuff_remaining_ms(target, spells.DEBUFF_JUDGEMENT_OF_WISDOM) > JUDGEMENT_REFRESH_MS then
			return false
		end
		if active_seal == "crusader" and utils.get_debuff_remaining_ms(target, spells.DEBUFF_JUDGEMENT_OF_THE_CRUSADER) > JUDGEMENT_REFRESH_MS then
			return false
		end
		if active_seal ~= "righteous" and active_seal ~= "wisdom" and active_seal ~= "crusader" then
			return false
		end
		if active_seal == "righteous" then
			judgement_label = "Judgement of Righteousness"
		end
	end

	if not utils.can_cast_hostile(runtime.judgement_id, me, target) then
		return false
	end

	if utils.cast_target(runtime.judgement_id, target) then
		runtime.pending_reseal_until = _core_time() + 2.0
		note_cast()
		utils.log_debug(menu, judgement_label)
		notify_cast("paladin:judgement", judgement_label, color.gold(220))
		return true
	end

    return false
end

local function try_holy_wrath(me, target)
    if not runtime.holy_wrath_id then
        return false
    end
    if enc and not enc.aoe_safe then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not (creature_utils.is_undead(target) or creature_utils.is_demon(target)) then
        return false
    end
    if utils.get_mana_pct(me) < 0.20 then
        return false
    end
    if not utils.can_cast_self(runtime.holy_wrath_id, me) then
        return false
    end
    if utils.cast_self(runtime.holy_wrath_id, me) then
        note_cast()
        utils.log_debug(menu, "Holy Wrath")
        return true
    end
    return false
end

local function try_exorcism(me, target)
    if not runtime.exorcism_id then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not (creature_utils.is_undead(target) or creature_utils.is_demon(target)) then
        return false
    end
    if not utils.can_cast_hostile(runtime.exorcism_id, me, target) then
        return false
    end
    if utils.cast_target(runtime.exorcism_id, target) then
        note_cast()
        utils.log_debug(menu, "Exorcism")
        notify_cast("paladin:exorcism", "Exorcism", color.yellow(220))
        return true
    end
    return false
end

local function try_lay_on_hands_emergency(me)
    if not menu.use_lay_on_hands:get_state() or not runtime.lay_on_hands_id then
        return false
    end
    local hp_threshold = menu.use_lay_on_hands_hp_pct:get() / 100
    if (me:get_health_percentage() / 100) > hp_threshold then
        return false
    end
    if not utils.can_cast_self(runtime.lay_on_hands_id, me) then
        return false
    end
    if utils.cast_self(runtime.lay_on_hands_id, me) then
        note_cast()
        utils.log_debug(menu, "Lay on Hands")
        return true
    end
    return false
end

local function try_divine_shield_emergency(me)
    if not menu.use_divine_shield:get_state() or not runtime.divine_shield_id then
        return false
    end
    if me:is_in_combat() then
        local mode = get_effective_mode()
        if mode ~= MODE_SOLO then
            return false
        end
    end
    local hp_threshold = menu.use_divine_shield_hp_pct:get() / 100
    if (me:get_health_percentage() / 100) > hp_threshold then
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

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        local was_enabled = menu.enabled:get_state()
        menu.enabled:set(not was_enabled)
        utils.log_debug(menu, "Toggled -> " .. tostring(not was_enabled))
    end
    runtime.prev_toggle_state = current
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
    handle_checkbox_keybind(menu.ooc_group_buff_key, menu.ooc_group_buff, "last_blessings_key_state", "Group Blessings")
    handle_checkbox_keybind(menu.use_holy_shield_key, menu.use_holy_shield, "last_holy_shield_key_state", "Holy Shield")
    handle_checkbox_keybind(menu.use_consecration_key, menu.use_consecration, "last_consecration_key_state", "Consecration")
    handle_checkbox_keybind(menu.use_avengers_shield_key, menu.use_avengers_shield, "last_avengers_key_state", "Avenger's Shield")
    handle_checkbox_keybind(menu.use_hand_of_freedom_key, menu.use_hand_of_freedom, "last_freedom_key_state", "Hand of Freedom")
end


-- --- Hammer of Justice - interrupt/stun (v1.4) ---------------------------

local function try_hammer_of_justice(me, target)
    if not runtime.hammer_of_justice_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if not interrupt_manager.should_interrupt(target) then return false end
    if not utils.can_cast_hostile(runtime.hammer_of_justice_id, me, target) then return false end
    if utils.cast_target_fast(runtime.hammer_of_justice_id, target) then
        note_cast()
        utils.log_debug(menu, "Hammer of Justice (interrupt)")
        return true
    end
    return false
end

local try_ooc_group_blessings

local function on_update()
    if not menu.enabled:get_state() then
        handle_toggle()
        handle_rotation_hotkeys()
        return
    end

    local now = _core_time()
    if (now - runtime.last_update_at) < UPDATE_INTERVAL then
        handle_toggle()
        handle_rotation_hotkeys()
        return
    end

    runtime.last_update_at = now
    handle_toggle()
    handle_rotation_hotkeys()
    if not menu.enabled:get_state() then
        return
    end

    local me = _get_local_player()
    if not me or not me:is_valid() or me:is_dead() then
        return
    end
    ooc_manager.on_update(me, menu, utils, {})
    if ensure_aura_upkeep(me) then
        return
    end
    if try_ooc_group_blessings(me) then
        return
    end
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

    refresh_mode_cache(now)
    local mode = get_effective_mode()
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    local target = focus_target or utils.find_best_target(me)
    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)

	if try_cleanse(me, target) then return true end

	if me:is_in_combat() and runtime.pending_reseal_until > now and utils.get_mana_pct(me) >= 0.08 then
		if ensure_active_seal(me, target) then
			return
		end
	end
    
    if not target or not me:can_attack(target) then
        return
    end

    -- Interrupt
    if interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "paladin", utils) then
            return
        end
    end


    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Racial CDs
    if racial_manager.try_offensive(me) then return true end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end

    -- Defensive abilities
    if try_divine_shield_emergency(me, get_effective_mode()) then return true end
    if try_lay_on_hands_emergency(me) then return true end
    if defensive_manager.try_defensive(me, "paladin", utils) then
        return
    end

    ttd_tracker.update(target)

    -- Self-emergency healing
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_hammer_of_justice(me, target) then return true end
        if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and ensure_holy_shield(me, target) then return true end
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.06) and try_hand_of_freedom(me) then return end
    if me:is_in_combat() then
        utils.ensure_melee_attack(me, target)
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and ensure_righteous_fury(me) then
        return
    end

	if ctx and resource_gate.common.has_mana_pct(ctx, 0.08) and ensure_active_seal(me, target) then
		return
	end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and ensure_holy_shield(me, target) then
        return
    end

	if ctx and resource_gate.common.has_mana_pct(ctx, 0.05) and try_judgement(me, target) then
		ensure_active_seal(me, target)
		return
	end

    local enemy_count = utils.count_enemies_within_radius(me, menu.consecration_radius:get())

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.20) and try_consecration(me, enemy_count) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_exorcism(me, target) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.20) and try_holy_wrath(me, target) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.15) and try_avengers_shield(me, target, mode) then
        return
    end
end

local function on_control_panel()
    local elements = {}

    if not control_panel_utility then
        return elements
    end

    local function add_cb(label, item, uid)
        if not item then return end
        local cur = item:get_state()
        local nxt = control_panel_utility:insert_key_checkbox_(elements, label, cur, 0, false, uid)
        if nxt ~= cur then
            item:set(nxt)
        end
    end

    local title = "Eax Paladin Prot"
    local toggle_key = menu.toggle_key:get_key_code()
    if toggle_key ~= 7 then
        title = title .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
    end

    add_cb(title, menu.enabled, "eax_paladin_prot_enabled_cp")
    return elements
end

resolve_spells()

local function safe_get_guid(unit)
    if not unit or type(unit.get_guid) ~= "function" then
        return nil
    end

    local ok, guid = pcall(function() return unit:get_guid() end)
    if not ok or guid == nil then
        return nil
    end

    return tostring(guid)
end

local function get_cast_progress_pct(unit)
    if not unit or not unit:is_valid() then
        return 0
    end

    if type(unit.get_channeling_or_casting_pct) == "function" then
        local ok, pct = pcall(function() return unit:get_channeling_or_casting_pct() end)
        if ok and pct then
            return math.max(0, math.min((tonumber(pct) or 0) / 100, 1))
        end
    end

    return 0
end

local function classify_recovery_victim(me, victim)
    if not victim or not victim:is_valid() or utils.same_unit(me, victim) or not victim:is_party_member() then
        return nil
    end

    local ok, role_id = pcall(function() return victim:get_group_role() end)
    if not ok then
        return nil
    end

    if role_id == GROUP_ROLE_HEALER then
        return "healer"
    end
    if role_id == GROUP_ROLE_DAMAGER then
        return "damager"
    end

    return nil
end

local function get_group_blessing_assignment(me, unit)
    if not me or not unit or not unit:is_valid() or unit:is_dead() then
        return nil, nil, nil
    end

    local role_id = -1
    if type(unit.get_group_role) == "function" then
        local ok, value = pcall(function() return unit:get_group_role() end)
        if ok and type(value) == "number" then
            role_id = value
        end
    end

    if utils.same_unit and utils.same_unit(me, unit) then
        role_id = GROUP_ROLE_TANK
    end

    if role_id == GROUP_ROLE_TANK and runtime.ooc_blessing_of_sanctuary_id then
        return runtime.ooc_blessing_of_sanctuary_id, spells.BUFF_BLESSING_OF_SANCTUARY, "Blessing of Sanctuary"
    end

    if role_id == GROUP_ROLE_HEALER and runtime.ooc_blessing_of_wisdom_id then
        return runtime.ooc_blessing_of_wisdom_id, spells.BUFF_BLESSING_OF_WISDOM, "Blessing of Wisdom"
    end

    if runtime.ooc_blessing_of_might_id then
        return runtime.ooc_blessing_of_might_id, spells.BUFF_BLESSING_OF_MIGHT, "Blessing of Might"
    end

    if runtime.ooc_blessing_of_wisdom_id then
        return runtime.ooc_blessing_of_wisdom_id, spells.BUFF_BLESSING_OF_WISDOM, "Blessing of Wisdom"
    end

    if runtime.ooc_blessing_of_sanctuary_id then
        return runtime.ooc_blessing_of_sanctuary_id, spells.BUFF_BLESSING_OF_SANCTUARY, "Blessing of Sanctuary"
    end

    return nil, nil, nil
end

local function unit_has_any_paladin_blessing(unit)
    if not unit or not unit:is_valid() or unit:is_dead() then
        return false
    end

    local blessing_ids = {
        spells.BUFF_BLESSING_OF_SANCTUARY,
        spells.BUFF_BLESSING_OF_KINGS,
        spells.BUFF_BLESSING_OF_MIGHT,
        spells.BUFF_BLESSING_OF_WISDOM,
    }
    for i = 1, #blessing_ids do
        if utils.has_buff(unit, blessing_ids[i]) then
            return true
        end
    end

    local ok, buffs = pcall(function() return unit:get_buffs() end)
    if not ok or not buffs then return false end
    local blessing_names = {
        ["blessing of might"] = true, ["greater blessing of might"] = true,
        ["blessing of wisdom"] = true, ["greater blessing of wisdom"] = true,
        ["blessing of sanctuary"] = true, ["greater blessing of sanctuary"] = true,
        ["blessing of kings"] = true, ["greater blessing of kings"] = true,
        ["blessing of salvation"] = true, ["greater blessing of salvation"] = true,
        ["blessing of light"] = true, ["greater blessing of light"] = true,
    }
    for _, buff in ipairs(buffs) do
        local name = buff and buff.name
        if type(name) == "string" and blessing_names[string.lower(name)] then return true end
    end
    return false
end

try_ooc_group_blessings = function(me)
    if not menu.ooc_group_buff or not menu.ooc_group_buff:get_state() then
        return false
    end
    if not me or not me:is_valid() or me:is_dead() then
        return false
    end
    if me:is_in_combat() or me:is_moving() then
        return false
    end

    local ok_cast, is_casting = pcall(function() return me:is_casting_spell() end)
    if ok_cast and is_casting then
        return false
    end

    local ok_chan, is_channelling = pcall(function() return me:is_channelling_spell() end)
    if ok_chan and is_channelling then
        return false
    end

    local units = { me }
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and obj:is_player()
           and obj:is_party_member() and not obj:is_dead()
           and not (utils.same_unit and utils.same_unit(me, obj))
        then
            table.insert(units, obj)
        end
    end

    for _, unit in ipairs(units) do
        local spell_id, buff_ids, buff_name = get_group_blessing_assignment(me, unit)
        local unit_guid = safe_get_guid(unit)
        local retry_key = unit_guid or buff_name or "unknown"
        local recently_blessed_same_target = unit_guid
            and runtime.last_blessing_target_guid == unit_guid
            and runtime.last_blessing_name == buff_name
            and (_core_time() - runtime.last_blessing_at) < 6.0
        local last_retry = runtime.last_blessing_retry_at[retry_key] or 0

        if spell_id and buff_ids and not recently_blessed_same_target and not unit_has_any_paladin_blessing(unit) and not utils.has_buff(unit, buff_ids) and (_core_time() - last_retry) >= BLESSING_RETRY_WINDOW then
            local is_self = utils.same_unit and utils.same_unit(me, unit)
            local can_cast = is_self and utils.can_cast_self(spell_id, me) or utils.can_cast_target(spell_id, me, unit)
            if can_cast then
                local cast_ok = is_self and utils.cast_self(spell_id, me) or utils.cast_target(spell_id, unit)
                if cast_ok then
                    runtime.last_blessing_retry_at[retry_key] = _core_time()
                    runtime.last_blessing_target_guid = unit_guid
                    runtime.last_blessing_name = buff_name
                    runtime.last_blessing_at = _core_time()
                    utils.log_debug(menu, "OOC: " .. buff_name)
                    return true
                end
            end
        end
    end

    return false
end

local function is_interruptible_enemy(unit)
    if not unit or not unit:is_valid() then
        return false
    end
    if unit:is_casting_spell() then
        return unit:is_active_spell_interruptable()
    end
    return unit:is_channelling_spell()
end

local function build_tank_recovery_state(me, ctx)
    local candidates = {}
    local helper_candidates = {}
    local by_guid = {}
    local off_me_count = 0
    local dangerous_count = 0
    local objects = core.object_manager.get_all_objects()

    for i = 1, #objects do
        local unit = objects[i]
        if unit and unit:is_valid() and unit:is_unit() and not unit:is_dead() and me:can_attack(unit) and unit:is_in_combat() then
            local victim = unit:get_target()
            local victim_role = classify_recovery_victim(me, victim)
            if victim_role then
                local guid = safe_get_guid(unit)
                if guid then
                    local dangerous = unit:is_casting_spell() or unit:is_channelling_spell()
                    off_me_count = off_me_count + 1
                    if dangerous then
                        dangerous_count = dangerous_count + 1
                    end
                    local candidate = {
                        guid = guid,
                        unit = unit,
                        victim_role = victim_role,
                        dangerous_caster = dangerous,
                        interruptible = is_interruptible_enemy(unit),
                        cast_progress_pct = get_cast_progress_pct(unit),
                    }
                    candidates[#candidates + 1] = candidate
                    helper_candidates[#helper_candidates + 1] = candidate
                    by_guid[guid] = candidate
                end
            end
        end
    end

    local snapshot = {
        self = {
            hp_pct = (((ctx or {}).self or {}).hp_pct) or (me:get_health_percentage() / 100),
            incoming_damage_pct_2s = (((ctx or {}).self or {}).incoming_damage_pct_2s) or 0,
            incoming_heal_pct = (((ctx or {}).self or {}).incoming_heal_pct) or 0,
        },
        party = {
            group_collapse_risk = (((ctx or {}).party or {}).group_collapse_risk) or 0,
            threat_instability = math.min(1, (off_me_count * 0.45) + (dangerous_count > 0 and 0.20 or 0)),
        },
    }

    local choice = tank_recovery.select_recovery_target(me, {
        snapshot = snapshot,
        candidates = helper_candidates,
    })

    return {
        snapshot = snapshot,
        candidates = candidates,
        target = choice and by_guid[choice.guid] and by_guid[choice.guid].unit or nil,
    }
end

reactive_adapter = {
    spec = "EAXPaladinProtection",
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
        anti_aggro = {
            handler = function(ctx, action_deps)
                local recovery_state = build_tank_recovery_state(action_deps.me, ctx)
                if tank_recovery.should_prioritize_defensive(recovery_state.snapshot, {
                    candidates = recovery_state.candidates,
                }) then
                    return defensive_manager.try_defensive(action_deps.me, "paladin", utils)
                end

                local recovery_target = action_deps.target or recovery_state.target or action_deps.current_target
                if not recovery_target or not recovery_target:is_valid() then
                    return false
                end

                if try_hammer_of_justice(action_deps.me, recovery_target) then return true end
                if try_avengers_shield(action_deps.me, recovery_target, get_effective_mode()) then return true end
                if try_holy_wrath(action_deps.me, recovery_target) then return true end
                return false
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
    resolve_target = function(action_id, ctx, action_deps)
        if action_id == "interrupt_control" then
            local current = action_deps.current_target
            if current and current:is_valid() and interrupt_manager.should_interrupt(current) then
                return current
            end
        end

        if action_id == "interrupt_control" or action_id == "anti_aggro" then
            local recovery_state = build_tank_recovery_state(action_deps.me, ctx)
            return recovery_state.target
        end

        return nil
    end,
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
core.register_on_update_callback(on_update)

-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxpaladinprotection_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)

-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Paladin"
    local _eax_spec  = "Protection"
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


