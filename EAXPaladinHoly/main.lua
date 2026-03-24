-- EAX Paladin Holy | main.lua
-- Callback registration, menu wiring, and healing logic for Holy Paladin.
-- APIs verified via docs/eax-family/API_LOOKUP_PLAYBOOK.md and existing EAX addons.

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


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("pholy", "Paladin Holy")
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
        spec = "EAXPaladinHoly",
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

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")

local CLEANSE_SPELL_IDS = spells.CLEANSE
local PURIFY_SPELL_IDS = spells.PURIFY

local DISPELABLE_DEBUFF_IDS = {
    16470, -- Infected Wounds (disease)
    16472, -- Putrid Physical (disease)
    16473, -- Corrupting Disease (disease)
    28169, -- Paralyze (poison-like)
}

local MODE_SOLO = "solo"
local MODE_DUNGEON = "dungeon"
local MODE_RAID = "raid"
local MODE_REFRESH_INTERVAL = 1.0

local runtime = {
    divine_shield_id = nil,
    redemption_id = nil,
    divine_illumination_id = nil,
    avenging_wrath_id = nil,
    lay_on_hands_id = nil,
    holy_light_id = nil,
    flash_of_light_id = nil,
    holy_shock_id = nil,
    blessing_wisdom_id = nil,
    blessing_might_id = nil,
    cleanse_id = nil,
    purify_id = nil,
    hand_of_freedom_id = nil,
    mode_cache = MODE_SOLO,
    mode_cache_refreshed_at = 0,
    last_toggle_state = false,
    last_auto_blessings_key_state = false,
    last_cleanse_key_state = false,
    last_freedom_key_state = false,
    ooc_blessing_of_might_id = nil,
    ooc_blessing_of_wisdom_id = nil,
}

local ctx_cache = rotation_context.new({
    important_buffs = {
        spells.BUFF_DIVINE_ILLUMINATION,
        spells.BUFF_AVENGING_WRATH,
    },
    important_debuffs = {},
})

local function note_cast()
    rotation_context.invalidate(ctx_cache)
end

local function invalidate_ctx()
    rotation_context.invalidate(ctx_cache)
end

local HOLY_AOE_RADIUS = 20

local function resolve_spells()
    runtime.holy_light_id = utils.resolve_spell_id(spells.HOLY_LIGHT)
    runtime.flash_of_light_id = utils.resolve_spell_id(spells.FLASH_OF_LIGHT)
    runtime.holy_shock_id = utils.resolve_spell_id(spells.HOLY_SHOCK)
    runtime.blessing_wisdom_id = utils.resolve_spell_id(spells.BLESSING_OF_WISDOM)
    runtime.blessing_might_id = utils.resolve_spell_id(spells.BLESSING_OF_MIGHT)
    runtime.ooc_blessing_of_wisdom_id = runtime.blessing_wisdom_id
    runtime.ooc_blessing_of_might_id = runtime.blessing_might_id
    runtime.cleanse_id = utils.resolve_spell_id(CLEANSE_SPELL_IDS)
    runtime.purify_id = utils.resolve_spell_id(PURIFY_SPELL_IDS)
    runtime.divine_illumination_id = utils.resolve_spell_id(spells.DIVINE_ILLUMINATION)
    runtime.avenging_wrath_id = utils.resolve_spell_id(spells.AVENGING_WRATH)
    runtime.lay_on_hands_id = utils.resolve_spell_id(spells.LAY_ON_HANDS)
    runtime.redemption_id = utils.resolve_spell_id(spells.REDEMPTION)
    runtime.hand_of_freedom_id = utils.resolve_spell_id(spells.HAND_OF_FREEDOM)
    runtime.divine_shield_id = utils.resolve_spell_id(spells.DIVINE_SHIELD)
end

local function log_resolved_spells()
    

-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Paladin"
    local _eax_spec  = "Holy"
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

core.log("[EAX Paladin Holy] Spells resolved: HL=" .. tostring(runtime.holy_light_id)
        .. " FoL=" .. tostring(runtime.flash_of_light_id)
        .. " HS=" .. tostring(runtime.holy_shock_id)
        .. " DI=" .. tostring(runtime.divine_illumination_id)
        .. " Cleanse=" .. tostring(runtime.cleanse_id or runtime.purify_id))
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

local function refresh_mode_cache()
    local now = _core_time()
    if (now - runtime.mode_cache_refreshed_at) < MODE_REFRESH_INTERVAL then
        return
    end
    runtime.mode_cache_refreshed_at = now
    runtime.mode_cache = utils.detect_mode(core.object_manager.get_local_player())
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
    return runtime.mode_cache
end

local function handle_toggle()
    local pressed = menu.toggle_key:get_state()
    if pressed and not runtime.last_toggle_state then
        local new_state = not menu.enabled:get_state()
        menu.enabled:set(new_state)
        utils.log_debug(menu, "Addon toggled -> " .. tostring(new_state))
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
    handle_checkbox_keybind(menu.auto_blessings_key, menu.auto_blessings, "last_auto_blessings_key_state", "Auto Blessings")
    handle_checkbox_keybind(menu.use_cleanse_key, menu.use_cleanse, "last_cleanse_key_state", "Cleanse")
    handle_checkbox_keybind(menu.use_hand_of_freedom_key, menu.use_hand_of_freedom, "last_freedom_key_state", "Hand of Freedom")
end

local function gather_heal_candidates(me)
    local candidates = {}
    local seen = {}

    local function add(unit)
        if not unit or not unit:is_valid() or unit:is_dead() then
            return
        end
        if seen[unit] then
            return
        end
        seen[unit] = true
        candidates[#candidates + 1] = unit
    end

    add(me)
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
            and obj:is_party_member()
        then
            add(obj)
        end
    end

    return candidates
end

local function find_heal_target(me, mode)
    if mode == MODE_SOLO or not me then
        return me, utils.get_health_pct(me)
    end

    local candidates = gather_heal_candidates(me)
    local best = me
    local best_pct = utils.get_health_pct(me)

    for _, unit in ipairs(candidates) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local pct = utils.get_health_pct(unit)
            if pct < best_pct then
                best_pct = pct
                best = unit
            end
        end
    end

    return best, best_pct
end

local function count_injured_allies(me, hp_threshold)
    local count = 0
    local threshold = hp_threshold or 0.85
    local candidates = gather_heal_candidates(me)
    for _, unit in ipairs(candidates) do
        if unit and unit:is_valid() and not unit:is_dead() then
            local hp_pct = utils.get_health_pct(unit)
            if hp_pct <= threshold then
                local in_range = true
                if me.get_distance then
                    local ok, dist = pcall(function() return me:get_distance(unit) end)
                    if ok and type(dist) == "number" then
                        in_range = dist <= HOLY_AOE_RADIUS
                    end
                end
                if in_range then
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function safe_unit_name(unit)
    if unit and unit.get_name then
        local ok, name = pcall(function() return unit:get_name() end)
        if ok and name and name ~= "" then
            return name
        end
    end
    return "unknown"
end

local function safe_unit_class(unit)
    if not unit or not unit.get_class then
        return ""
    end
    local ok, class_name = pcall(function() return string.lower(unit:get_class() or "") end)
    if ok and class_name then
        return class_name
    end
    return ""
end

local function safe_group_role(unit)
    if not unit or not unit.get_group_role then
        return nil
    end
    local ok, role_id = pcall(function() return unit:get_group_role() end)
    if ok then
        return role_id
    end
    return nil
end

local function unit_uses_mana(unit)
    if not unit or not unit.get_max_power then
        return false
    end
    local ok, max_mana = pcall(function() return unit:get_max_power(0) end)
    return ok and type(max_mana) == "number" and max_mana > 0
end

local function is_probable_tank(unit, me)
    if not unit or not unit:is_valid() then
        return false
    end

    local role_id = safe_group_role(unit)
    if role_id and role_id == 0 then
        return true
    end

    if me and utils.same_unit and utils.same_unit(unit, me) then
        return false
    end

    local class_name = safe_unit_class(unit)
    return class_name == "warrior" or class_name == "paladin" or class_name == "druid"
end

local function should_use_holy_light(target, hp_pct)
    if not target or not hp_pct then
        return false
    end
    local base_threshold = menu.holy_light_hp_pct:get() / 100
    if is_probable_tank(target) then
        base_threshold = math.max(base_threshold, 0.78)
    end
    return hp_pct <= base_threshold
end

local function should_use_divine_illumination(target, hp_pct, injured_allies)
    if not target or not hp_pct then
        return false
    end
    if not menu.use_divine_illumination:get_state() then
        return false
    end
    if injured_allies >= 2 and hp_pct <= 0.75 then
        return true
    end
    return should_use_holy_light(target, hp_pct) and hp_pct <= 0.60
end

local function should_use_avenging_wrath(target, hp_pct, injured_allies)
    if not menu.use_avenging_wrath:get_state() then
        return false
    end
    if injured_allies >= 3 then
        return true
    end
    if target and hp_pct and hp_pct <= 0.35 then
        return true
    end
    return false
end

local function has_dispellable_debuff(unit)
    if not unit or not unit:is_valid() then
        return false
    end
    for i = 1, #DISPELABLE_DEBUFF_IDS do
        local data = buff_manager:get_debuff_data(unit, DISPELABLE_DEBUFF_IDS[i])
        if data and data.is_active then
            return true
        end
    end
    return false
end

local function try_cast_spell(spell_id, me, target, label)
    if not spell_id or not me then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end
    if not utils.can_cast_target(spell_id, me, target) then
        return false
    end
    if not utils.cast_target(spell_id, target) then
        return false
    end
    note_cast()
    local target_name = safe_unit_name(target)
    utils.log_debug(menu, label .. " -> " .. target_name)
    return true
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

local function build_paladin_triage_members(me)
    local candidates = gather_heal_candidates(me)
    local members = {}
    for i = 1, #candidates do
        local unit = candidates[i]
        if unit and unit:is_valid() and not unit:is_dead() then
            local guid = unit_guid(unit) or ("candidate-" .. i)
            local is_tank = is_probable_tank(unit, me)
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
    return members
end

local function resolve_paladin_triage(me)
    local summary = healer_triage.select_target(me, build_paladin_triage_members(me), {})
    if not summary or not summary.target or not summary.target.is_valid or not summary.target:is_valid() then
        return nil, nil
    end
    return summary, summary.target
end

local function should_cancel_paladin_cast(me, target)
    if not eax_utils.should_stopcasting(me, menu) then
        return false
    end
    local summary = healer_triage.select_target(me, build_paladin_triage_members(me), {})
    local snapshot = {
        hp_pct = target and utils.get_health_pct(target) or utils.get_health_pct(me),
        incoming_heal_pct = target and unit_incoming_heal_pct(target) or unit_incoming_heal_pct(me),
        collapse_risk = summary and summary.collapse_risk == true,
        group_count = summary and summary.group_count or 0,
    }
    return healer_triage.should_cancel_overheal(snapshot, {})
end

local function try_hand_of_freedom(me)
    if not menu.use_hand_of_freedom:get_state() then return false end
    if not runtime.hand_of_freedom_id then return false end
    if not utils.can_cast_self(runtime.hand_of_freedom_id, me) then return false end

    local include_slows = menu.hof_include_slows:get_state()
    local candidates = gather_heal_candidates(me)

    for _, unit in ipairs(candidates) do
        if unit and unit:is_valid() and not unit:is_dead() then
            -- Root check (always)
            local is_root = unit:is_rooted(500)
            -- Slow check (optional)
            local is_slow = include_slows and unit:is_slowed(0.30, 500)

            if is_root or is_slow then
                -- Don't waste if unit already has Hand of Freedom
                if not utils.has_buff(unit, spells.BUFF_HAND_OF_FREEDOM) then
                    if try_cast_spell(runtime.hand_of_freedom_id, me, unit, "Hand of Freedom") then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function try_lay_on_hands(me, target, hp_pct)
    if not menu.use_lay_on_hands:get_state() or not runtime.lay_on_hands_id then
        return false
    end
    if not target or not target:is_valid() or target:is_dead() or not hp_pct then
        return false
    end
    if hp_pct > (menu.use_lay_on_hands_hp_pct:get() / 100) then
        return false
    end
    return try_cast_spell(runtime.lay_on_hands_id, me, target, "Lay on Hands")
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

local function try_divine_illumination(me, target, hp_pct, injured_allies)
    if not runtime.divine_illumination_id then
        return false
    end
    if not should_use_divine_illumination(target, hp_pct, injured_allies) then
        return false
    end
    if not utils.can_cast_self(runtime.divine_illumination_id, me) then
        return false
    end
    if not utils.cast_self(runtime.divine_illumination_id, me) then
        return false
    end
    note_cast()
    utils.log_debug(menu, "Divine Illumination")
    return true
end

local function try_avenging_wrath(me, target, hp_pct, injured_allies)
    if not runtime.avenging_wrath_id then
        return false
    end
    if utils.has_buff(me, spells.BUFF_AVENGING_WRATH) then
        return false
    end
    if not should_use_avenging_wrath(target, hp_pct, injured_allies) then
        return false
    end
    if not utils.can_cast_self(runtime.avenging_wrath_id, me) then
        return false
    end
    if not utils.cast_self(runtime.avenging_wrath_id, me) then
        return false
    end
    note_cast()
    utils.log_debug(menu, "Avenging Wrath")
    return true
end

local function try_cleanse(me, target)
    local cleanse_id = runtime.cleanse_id or runtime.purify_id
    if not cleanse_id or not menu.use_cleanse:get_state() then
        return false
    end
    if has_dispellable_debuff(target) then
        return try_cast_spell(cleanse_id, me, target, "Cleanse")
    end
    return false
end

local function desired_blessing_for_unit(unit)
    if not unit or not unit:is_valid() or unit:is_dead() then
        return nil, nil, nil
    end

    if is_probable_tank(unit) and runtime.blessing_might_id then
        if not utils.has_buff(unit, spells.BUFF_BLESSING_OF_MIGHT) then
            return runtime.blessing_might_id, spells.BUFF_BLESSING_OF_MIGHT, "Blessing of Might"
        end
        return nil, nil, nil
    end

    if unit_uses_mana(unit) and runtime.blessing_wisdom_id then
        if not utils.has_buff(unit, spells.BUFF_BLESSING_OF_WISDOM) then
            return runtime.blessing_wisdom_id, spells.BUFF_BLESSING_OF_WISDOM, "Blessing of Wisdom"
        end
    end

    return nil, nil, nil
end

local function ensure_blessings(me)
    if not menu.auto_blessings:get_state() then
        return false
    end
    if not me or not me:is_valid() then
        return false
    end

    local candidates = gather_heal_candidates(me)
    for i = 1, #candidates do
        local unit = candidates[i]
        local blessing_id, _, label = desired_blessing_for_unit(unit)
        if blessing_id and try_cast_spell(blessing_id, me, unit, label) then
            return true
        end
    end

    return false
end

local function try_cast_heal(me, target, hp_pct, injured_allies, ctx)
    if not target or not hp_pct then
        return false
    end

    local emergency_flash_threshold = math.min(menu.flash_of_light_hp_pct:get() / 100, 0.40)
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08)
        and menu.use_flash_of_light:get_state() and runtime.flash_of_light_id and hp_pct <= emergency_flash_threshold then
        if try_cast_spell(runtime.flash_of_light_id, me, target, "Flash of Light") then
            return true
        end
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10)
        and menu.use_holy_shock:get_state() and runtime.holy_shock_id then
        local threshold = menu.holy_shock_hp_pct:get() / 100
        if hp_pct <= threshold and try_cast_spell(runtime.holy_shock_id, me, target, "Holy Shock") then
            esp_renderer.on_cast(runtime.holy_shock_id, "Holy Shock", color.yellow(220))
            return true
        end
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10)
        and try_divine_illumination(me, target, hp_pct, injured_allies or 0) then
        return true
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.18)
        and menu.use_holy_light:get_state() and runtime.holy_light_id and should_use_holy_light(target, hp_pct) then
        if try_cast_spell(runtime.holy_light_id, me, target, "Holy Light") then
            return true
        end
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.08)
        and menu.use_flash_of_light:get_state() and runtime.flash_of_light_id then
        local threshold = menu.flash_of_light_hp_pct:get() / 100
        if hp_pct <= threshold and try_cast_spell(runtime.flash_of_light_id, me, target, "Flash of Light") then
            return true
        end
    end

    return false
end


local function on_update()
    handle_toggle()
    handle_rotation_hotkeys()
    if not menu.enabled:get_state() then
        return
    end

    local me = _get_local_player()
    if not me or not me:is_valid() or me:is_dead() then
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

    -- Stopcast on overheal risk for slow heals
    if menu.overheal_protection:get_state() and eax_utils.should_stopcasting(me, menu) then
        if SpellStopCasting then SpellStopCasting() end
    end

    -- Interrupt (PVP)
    local target = me:get_target()
    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)
    if target and target:is_valid() and me:can_attack(target) and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "paladin", utils) then
            return
        end
    end


    -- Mana conservation (leveling 1-70)
    if leveling_manager.is_conserving_mana(me, menu) then
        leveling_manager.ensure_melee(me, target)
    end
    -- Encounter policy (boss-specific rotation adjustments)
    local enc = encounter_manager.get_policy(me)

    -- Defensive abilities
    -- Racial abilities
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    if try_divine_shield_emergency(me) then return true end
    if defensive_manager.try_defensive(me, "paladin", utils) then
        return
    end

    ttd_tracker.update(target)

    -- Focus Target Priority - heal focus target first
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target then
        local focus_hp = (focus_target:get_health_percentage() or 100) / 100
        local focus_flash_threshold = (menu.flash_of_light_hp_pct:get() or 0) / 100
        if focus_hp <= focus_flash_threshold then
            local focus_injured = count_injured_allies(me, 0.80)
            if try_lay_on_hands(me, focus_target, focus_hp) then
                return
            end
            if try_cast_heal(me, focus_target, focus_hp, focus_injured, ctx) then
                return
            end
        end
    end

    -- Combat-aware self HP threshold
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_lay_on_hands(me, me, my_hp) then
            return
        end
        if try_cast_heal(me, me, my_hp, count_injured_allies(me, 0.80), ctx) then
            return
        end
    end

    refresh_mode_cache()
    local mode = get_effective_mode()

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.06) and ensure_blessings(me) then
        return
    end

    if not me:is_in_combat() then return end

    if _get_gcd() > 0 then
        return
    end

    local target, hp_pct = find_heal_target(me, mode)
    local injured_allies = count_injured_allies(me, 0.80)

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.06) and try_hand_of_freedom(me) then return end
    if ctx and resource_gate.common.has_mana_pct(ctx, 0.06) and try_cleanse(me, target) then
        return
    end

    if try_lay_on_hands(me, target, hp_pct) then
        return
    end

    if ctx and resource_gate.common.has_mana_pct(ctx, 0.10) and try_avenging_wrath(me, target, hp_pct, injured_allies) then
        return
    end

    try_cast_heal(me, target, hp_pct, injured_allies, ctx)
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

    local title = "Eax Paladin Holy"
    local toggle_key_code = menu.toggle_key:get_key_code()
    if toggle_key_code ~= 7 then
        title = title .. " (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end

    add_cb(title, menu.enabled, "eax_paladin_holy_enabled_cp")
    if menu.enabled:get_state() then
        add_cb("  PHo Focus", menu.focus_priority, "eax_paladin_holy_focus_cp")
        add_cb("  PHo Racial", menu.use_racial, "eax_paladin_holy_racial_cp")
        add_cb("  PHo Blessings", menu.auto_blessings, "eax_paladin_holy_blessings_cp")
        add_cb("  PHo Cleanse", menu.use_cleanse, "eax_paladin_holy_cleanse_cp")
        add_cb("  PHo Freedom", menu.use_hand_of_freedom, "eax_paladin_holy_freedom_cp")
    end

    return elements
end

resolve_spells()
log_resolved_spells()


reactive_adapter = {
    spec = "EAXPaladinHoly",
    actions = {
        life_save_self = {
            handler = function(ctx, action_deps)
                local me_hp = utils.get_health_pct(action_deps.me)
                if try_lay_on_hands(action_deps.me, action_deps.me, me_hp) then
                    return true
                end
                return try_cast_heal(action_deps.me, action_deps.me, me_hp, count_injured_allies(action_deps.me, 0.80), ctx)
            end,
        },
        life_save_ally = {
            handler = function(ctx, action_deps)
                local summary, ally_target = resolve_paladin_triage(action_deps.me)
                local ally_hp = ally_target and utils.get_health_pct(ally_target) or nil
                if not ally_target or not ally_hp then
                    return false
                end

                if try_lay_on_hands(action_deps.me, ally_target, ally_hp) then
                    return true
                end

                if summary and healer_triage.should_spend_emergency(summary, {}) then
                    if try_avenging_wrath(action_deps.me, ally_target, ally_hp, summary.group_count or 0) then
                        return true
                    end
                end
                return try_cast_heal(action_deps.me, ally_target, ally_hp, summary and summary.group_count or 0, ctx)
            end,
        },
        interrupt_control = { noop = "unsupported" },
        anti_overheal = {
            handler = function(_, action_deps)
                if not should_cancel_paladin_cast(action_deps.me, action_deps.current_target) then
                    return false
                end

                if SpellStopCasting then
                    SpellStopCasting()
                    return true
                end

                return false
            end,
        },
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
core.register_on_update_callback(on_update)

-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxpaladinholy_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)
