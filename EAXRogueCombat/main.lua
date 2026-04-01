-- Eax Rogue Combat | main.lua

local menu = require("libraries/menu")
local enums = (function()
    local ok, e = pcall(require, "common/enums")
    return ok and e or nil
end)()
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local rotation_context = require("libraries/rotation_context")
local resource_gate = require("libraries/resource_gate")

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
local poison_manager = require("libraries/poison_manager")

---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
---@type leveling_manager
local leveling_manager = require("libraries/leveling_manager")
---@type encounter_manager
local encounter_manager = require("libraries/encounter_manager")
local pvp_manager = require("eax_shared/pvp_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil
local force_apply_poisons_cp = false

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

-- CC awareness: check if target can be CC'd (Sap, Gouge, Blind)
local function can_cc_target(target)
    local ok, cc = pcall(function() return require("common/utility/cc_data_helper") end)
    if not ok or not cc then return false end
    return cc.can_cc and cc.can_cc(target) or false
end


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("combat", "Rogue Combat")
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
local KICK_ENERGY_RESERVE = 20
local POISON_OPTION_KEYS = { "disabled", "instant", "deadly", "wound", "crippling", "mind_numbing" }
local POISON_ITEM_TABLES = {
    instant = spells.POISON_ITEMS_INSTANT,
    deadly = spells.POISON_ITEMS_DEADLY,
    wound = spells.POISON_ITEMS_WOUND,
    crippling = spells.POISON_ITEMS_CRIPPLING,
    mind_numbing = spells.POISON_ITEMS_MIND_NUMBING,
}
local POISON_FALLBACK_ORDER = { "instant", "deadly", "wound", "crippling", "mind_numbing" }

local function build_poison_priority(selected_key)
    if selected_key == "disabled" then
        return nil
    end

    local items = {}
    local seen = {}
    local function append_category(key)
        if seen[key] then
            return
        end
        seen[key] = true
        local item_list = POISON_ITEM_TABLES[key]
        if not item_list then
            return
        end
        for _, item_id in ipairs(item_list) do
            table.insert(items, item_id)
        end
    end

    append_category(selected_key)
    for _, key in ipairs(POISON_FALLBACK_ORDER) do
        append_category(key)
    end

    return #items > 0 and items or nil
end

local function current_poison_loadout()
    local main_idx = menu.main_hand_poison and menu.main_hand_poison:get() or 2
    local off_idx = menu.off_hand_poison and menu.off_hand_poison:get() or 3
    return {
        main_hand_items = build_poison_priority(POISON_OPTION_KEYS[main_idx] or "instant"),
        off_hand_items = build_poison_priority(POISON_OPTION_KEYS[off_idx] or "deadly"),
    }
end

local function current_energy(me)
    if not me then return 0 end
    local ok, value = pcall(function() return me:get_power(3) end)
    return (ok and tonumber(value)) or 0
end

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
        spec = "EAXRogueCombat",
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
    cloak_id = nil,
    sinister_strike_id = nil,
    slice_and_dice_id = nil,
    eviscerate_id = nil,
    rupture_id = nil,
    kick_id = nil,
    blade_flurry_id = nil,
    adrenaline_rush_id = nil,
    evasion_id = nil,
    feint_id = nil,
    garrote_id = nil,
    riposte_id = nil,
    expose_armor_id = nil,
    shiv_id = nil,
    combo_points = 0,
    combo_target = nil,
    prev_toggle_state = false,
    last_cast_time = 0,
    cached_mode = "solo",
    set_multiplier = 1.0,
}

local ctx_cache = rotation_context.new({
    important_buffs = {
        slice_and_dice = spells.BUFF_SLICE_AND_DICE,
        blade_flurry = spells.BUFF_BLADE_FLURRY,
        stealth = spells.BUFF_STEALTH,
    },
    important_debuffs = {
        rupture = spells.DEBUFF_RUPTURE,
        deadly_poison = spells.DEBUFF_DEADLY_POISON,
    },
})

local GCD_CAST_INTERVAL = 1.0  -- TBC GCD
local COMBAT_FINISHER_COMBO_POINTS = 5
local SND_REFRESH_CRITICAL_MS = 2000
local SND_CLIP_GUARD_MS = 10000
local SND_PREDICT_RANGE = 8
local UNKNOWN_TTD_SENTINEL = 7777
local SND_BASE_DURATIONS_S = {
    [1] = 9,
    [2] = 12,
    [3] = 15,
    [4] = 18,
    [5] = 21,
}

local function resolve_spells()
    runtime.sinister_strike_id = utils.resolve_spell_id(spells.SINISTER_STRIKE)
    runtime.slice_and_dice_id = utils.resolve_spell_id(spells.SLICE_AND_DICE)
    runtime.eviscerate_id = utils.resolve_spell_id(spells.EVISCERATE)
    runtime.rupture_id = utils.resolve_spell_id(spells.RUPTURE)
    runtime.kick_id = utils.resolve_spell_id(spells.KICK)
    runtime.blade_flurry_id = utils.resolve_spell_id(spells.BLADE_FLURRY)
    runtime.adrenaline_rush_id = utils.resolve_spell_id(spells.ADRENALINE_RUSH)
    runtime.garrote_id = utils.resolve_spell_id(spells.GARROTE)
    runtime.riposte_id = utils.resolve_spell_id(spells.RIPOSTE)
    runtime.evasion_id        = utils.resolve_spell_id(spells.EVASION)
    runtime.feint_id   = utils.resolve_spell_id(spells.FEINT)
    runtime.shiv_id    = utils.resolve_spell_id(spells.SHIV)
    runtime.expose_armor_id   = utils.resolve_spell_id(spells.EXPOSE_ARMOR)
    runtime.cloak_id = utils.resolve_spell_id({ 31224 })
end

local function log_resolved_spells()
    core.log(
        "[Eax Rogue Combat] Resolved: SS=" .. tostring(runtime.sinister_strike_id)
            .. " SnD=" .. tostring(runtime.slice_and_dice_id)
            .. " EV=" .. tostring(runtime.eviscerate_id)
            .. " RUP=" .. tostring(runtime.rupture_id)
    )
end

resolve_spells()
log_resolved_spells()

local function note_cast()
    runtime.last_cast_time = _core_time()
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

local function current_mode()
    return utils.get_selected_mode(menu)
end

local combat_rotation_suspended_logged = false

local function is_combat_rotation_available()
    local available = runtime.blade_flurry_id ~= nil or runtime.adrenaline_rush_id ~= nil or runtime.riposte_id ~= nil
    if not available and not combat_rotation_suspended_logged then
        combat_rotation_suspended_logged = true
        core.log("[Eax Rogue Combat] Blade Flurry / Adrenaline Rush / Riposte not detected; suspending Combat rotation to avoid off-spec conflicts.")
    end
    return available
end

local function handle_toggle()
    local current = menu.toggle_key:get_state()
    if current and not runtime.prev_toggle_state then
        menu.enabled:set(not menu.enabled:get_state())
    end
    runtime.prev_toggle_state = current
end

-- Read combo points using native game_object API on ME (the player).
-- Key fix: get_power() must be called on the PLAYER, not on cp_obj (the target mob).
-- Calling it on cp_obj always returned 0 because mobs have no combo points.
local function get_current_combo_points(me)
    if not me then
        return nil
    end

    if enums and enums.power_type and enums.power_type.COMBOPOINTS_TBC ~= nil then
        local ok1, v1 = pcall(function() return me:get_power(enums.power_type.COMBOPOINTS_TBC) end)
        if ok1 and type(v1) == "number" and v1 >= 0 then
            return v1
        end
    end

    if enums and enums.power_type and enums.power_type.COMBOPOINTS ~= nil then
        local ok2, v2 = pcall(function() return me:get_power(enums.power_type.COMBOPOINTS) end)
        if ok2 and type(v2) == "number" and v2 >= 0 then
            return v2
        end
    end

    if type(me.combo_points_current) == "function" then
        local ok3, v3 = pcall(function() return me:combo_points_current() end)
        if ok3 and type(v3) == "number" and v3 >= 0 then
            return v3
        end
    end

    return nil
end


local function track_target(me, target)
    local cp = get_current_combo_points(me)
    if cp == nil then return end

    runtime.combo_points = math.max(0, math.min(COMBAT_FINISHER_COMBO_POINTS, cp))
    if runtime.combo_points <= 0 then
        runtime.combo_target = nil
        return
    end

    local ok_cp_target, cp_target = pcall(function()
        return me and me.get_combo_points_target and me:get_combo_points_target() or nil
    end)
    if ok_cp_target and cp_target and cp_target:is_valid() then
        runtime.combo_target = cp_target
    end
end

local function combo_points_match_target(target)
    if (runtime.combo_points or 0) <= 0 then
        return true
    end
    return runtime.combo_target and target and utils.same_unit(runtime.combo_target, target)
end

local function get_snd_refresh_window_ms()
    local refresh_seconds = menu.snd_refresh_seconds and menu.snd_refresh_seconds:get() or 3
    return math.max(SND_REFRESH_CRITICAL_MS, refresh_seconds * 1000)
end

local function get_known_ttd_seconds(target)
    if not target or not target:is_valid() or target:is_dead() then
        return nil
    end

    local ok, value = pcall(function() return ttd_tracker.get(target) end)
    if not ok then
        return nil
    end

    value = tonumber(value)
    if not value or value <= 0 or value >= UNKNOWN_TTD_SENTINEL then
        return nil
    end

    return value
end

local function get_largest_nearby_ttd_seconds(me, target, range)
    local largest_ttd = get_known_ttd_seconds(target)
    if not me then
        return largest_ttd
    end

    local ok_me, me_pos = pcall(function() return me:get_position() end)
    if not ok_me or not me_pos then
        return largest_ttd
    end

    local radius = tonumber(range) or SND_PREDICT_RANGE
    local radius_sq = radius * radius
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and not obj:is_dead() and me:can_attack(obj) then
            local ok_pos, obj_pos = pcall(function() return obj:get_position() end)
            if ok_pos and obj_pos then
                local dx = me_pos.x - obj_pos.x
                local dy = me_pos.y - obj_pos.y
                local dz = me_pos.z - obj_pos.z
                local dist_sq = (dx * dx) + (dy * dy) + (dz * dz)
                if dist_sq <= radius_sq then
                    local obj_ttd = get_known_ttd_seconds(obj)
                    if obj_ttd and (not largest_ttd or obj_ttd > largest_ttd) then
                        largest_ttd = obj_ttd
                    end
                end
            end
        end
    end

    return largest_ttd
end

local function get_slice_and_dice_full_duration_seconds(combo_points)
    combo_points = tonumber(combo_points) or 0
    combo_points = math.max(0, math.min(COMBAT_FINISHER_COMBO_POINTS, combo_points))
    if combo_points == 0 then
        return 0
    end

    return SND_BASE_DURATIONS_S[combo_points] or 0
end

local function get_predictive_snd_combo_points(me, target)
    if not menu.use_predictive_snd or not menu.use_predictive_snd:get_state() then
        return nil
    end

    local largest_ttd = get_largest_nearby_ttd_seconds(me, target, SND_PREDICT_RANGE)
    if not largest_ttd then
        return nil
    end

    local snd_remaining_s = math.max(0, utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE) / 1000)
    local expiry_buffer_s = menu.snd_predictive_buffer_seconds and menu.snd_predictive_buffer_seconds:get() or 5
    local target_duration = (largest_ttd - snd_remaining_s) - expiry_buffer_s
    if target_duration <= 0 then
        return 1
    end

    for cp = 1, COMBAT_FINISHER_COMBO_POINTS do
        if get_slice_and_dice_full_duration_seconds(cp) >= target_duration then
            return cp
        end
    end

    return COMBAT_FINISHER_COMBO_POINTS
end

local function should_use_major_cooldowns(me)
    if not me or not me:is_in_combat() then
        return false
    end

    local mode = current_mode()
    if mode == "solo" then
        return false
    elseif mode == "dungeon" then
        return runtime.combo_points >= 3
    end

    return runtime.combo_points >= 4
end

local function try_kick(me, target)
    if not menu.use_kick:get_state() then
        return false
    end
    if not runtime.kick_id or not utils.can_attack(me, target) then
        return false
    end
    if current_energy(me) < KICK_ENERGY_RESERVE then
        return false
    end
    if not target:is_casting_spell() and not target:is_channelling_spell() then
        return false
    end
    if target:is_casting_spell() and not target:is_active_spell_interruptable() then
        return false
    end
    if not utils.can_cast_hostile(runtime.kick_id, me, target) then
        return false
    end

    if utils.cast_target_fast(runtime.kick_id, target, "Kick") then
        utils.log_debug(menu, "Kick")
        note_cast()
        return true
    end

    return false
end

local function try_blade_flurry(me, target)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_blade_flurry:get_state() then
        return false
    end
    if not runtime.blade_flurry_id or not me:is_in_combat() then
        return false
    end
    local enemy_count = encounter_manager.enemy_count_in_range(me, 8)
    local blade_flurry_active = utils.get_buff_remaining_ms(me, spells.BUFF_BLADE_FLURRY) > 0

    if blade_flurry_active and enemy_count < 2 then
        if not utils.can_cast_self(runtime.blade_flurry_id, me) then
            return false
        end
        if utils.cast_self_fast(runtime.blade_flurry_id, me, "Blade Flurry Off") then
            utils.log_debug(menu, "Blade Flurry Off")
            note_cast()
            return true
        end
        return false
    end

    if blade_flurry_active then
        return false
    end
    if enemy_count < 2 then
        return false
    end
    if not utils.can_cast_self(runtime.blade_flurry_id, me) then
        return false
    end

    if utils.cast_self_fast(runtime.blade_flurry_id, me, "Blade Flurry") then
        utils.log_debug(menu, "Blade Flurry")
        note_cast()
        esp_renderer.on_cast(runtime.blade_flurry_id, "Blade Flurry", color.cyan(220))
        return true
    end

    return false
end

local function try_adrenaline_rush(me)
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_adrenaline_rush:get_state() then
        return false
    end
    if not runtime.adrenaline_rush_id or not should_use_major_cooldowns(me) then
        return false
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_ADRENALINE_RUSH) > 0 then
        return false
    end
    -- Blade Flurry is already checked/fired in the rotation before AR (see do_rotation)
    -- so if BF is available and not active, it will be cast first automatically
    if not utils.can_cast_self(runtime.adrenaline_rush_id, me) then
        return false
    end

    if utils.cast_self_fast(runtime.adrenaline_rush_id, me, "Adrenaline Rush") then
        utils.log_debug(menu, "Adrenaline Rush")
        note_cast()
        esp_renderer.on_cast(runtime.adrenaline_rush_id, "Adrenaline Rush", color.cyan(220))
        return true
    end

    return false
end

local function expose_armor_due(me, target)
    if not menu.use_expose_armor or not menu.use_expose_armor:get_state() then
        return false
    end
    if not runtime.expose_armor_id or not target or not target:is_valid() then
        return false
    end
    if current_mode() == "solo" then
        return false
    end
    if utils.has_debuff(target, spells.DEBUFF_EXPOSE_ARMOR) then
        return false
    end
    if utils.has_debuff(target, spells.DEBUFF_SUNDERED_ARMOR) then
        return false
    end
    return true
end

local function should_pool_for_finisher(me, target)
    if not me or not target or not target:is_valid() then
        return false
    end

    local cp = runtime.combo_points or 0
    if cp < (menu.finish_combo_points:get() - 1) then
        return false
    end

    local energy = current_energy(me)
    local snd_remaining_ms = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    local snd_due = menu.use_slice_and_dice:get_state() and snd_remaining_ms <= get_snd_refresh_window_ms()
    local rupture_due = menu.use_rupture:get_state()
        and cp >= menu.finish_combo_points:get()
        and utils.get_debuff_remaining_ms(target, spells.DEBUFF_RUPTURE) <= 3000
        and ((get_known_ttd_seconds(target) or UNKNOWN_TTD_SENTINEL) >= 12)
    local damage_finisher_due = menu.use_eviscerate:get_state()
        and cp >= menu.finish_combo_points:get()
        and snd_remaining_ms >= 2000
        and not rupture_due
        and not expose_armor_due(me, target)

    if cp >= COMBAT_FINISHER_COMBO_POINTS then
        if snd_due and energy < 25 then return true end
        if expose_armor_due(me, target) and energy < 25 then return true end
        if rupture_due and energy < 25 then return true end
        if damage_finisher_due and energy < 35 then return true end
        return false
    end

    if snd_due and energy < 70 then return true end
    if expose_armor_due(me, target) and energy < 70 then return true end
    if rupture_due and energy < 70 then return true end
    if damage_finisher_due and energy < 80 then return true end
    return false
end

local function try_slice_and_dice(me, target, ctx)
    if not menu.use_slice_and_dice:get_state() then
        return false
    end
    if not runtime.slice_and_dice_id or not utils.can_attack(me, target) then
        return false
    end
    if not combo_points_match_target(target) then
        return false
    end

    -- SnD at ANY CP count when critical (wowsims pattern)
    local remaining_ms = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    local refresh_window_ms = get_snd_refresh_window_ms()
    if remaining_ms > SND_CLIP_GUARD_MS then
        return false
    end
    if remaining_ms > SND_REFRESH_CRITICAL_MS and remaining_ms > 0 then
        return false
    end
    -- Allow SnD at 1+ CP when critical
    if runtime.combo_points < 1 then
        return false
    end

    local policy = encounter_manager.get_policy(me)
    local enemy_count = encounter_manager.enemy_count_in_range(me, 8)
    local regular_min_combo_points = math.min(menu.finish_combo_points:get(), 3)
    if enemy_count >= 2 or (policy and policy.burn_phase) then
        regular_min_combo_points = 2
    end
    local min_combo_points = remaining_ms > 0 and regular_min_combo_points or 1
    if remaining_ms > 0 and remaining_ms <= 1000 then
        local predictive_combo_points = get_predictive_snd_combo_points(me, target)
        if predictive_combo_points then
            min_combo_points = math.max(1, math.min(COMBAT_FINISHER_COMBO_POINTS, predictive_combo_points))
        end
    end
    if runtime.combo_points < min_combo_points or runtime.combo_points > COMBAT_FINISHER_COMBO_POINTS then
        return false
    end
    -- Energy pooling: wait if SnD/Rupture have > 2s remaining and energy < 50
    local energy = current_energy(me)
    local snd_rem = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    local rupture_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RUPTURE)
    if snd_rem > 2000 and energy < 50 then return false end
    if rupture_rem > 2000 and energy < 50 then return false end
    if ctx then
        local can_cast = resource_gate.rogue.can_finisher(ctx, 25, runtime.combo_points, min_combo_points)
        if not can_cast then
            return false
        end
    end
    if not utils.can_cast_target(runtime.slice_and_dice_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.slice_and_dice_id, target, "Slice and Dice") then
        utils.log_debug(menu, "Slice and Dice")
        note_cast()
        return true
    end

    return false
end

local function try_rupture(me, target, ctx)
    if not menu.use_rupture:get_state() then
        return false
    end
    if not runtime.rupture_id or not utils.can_attack(me, target) then
        return false
    end
    if not combo_points_match_target(target) then
        return false
    end
    local min_combo_points = menu.finish_combo_points:get()
    if runtime.combo_points < min_combo_points then
        return false
    end
    if (target:is_casting_spell() or target:is_channelling_spell()) and current_energy(me) <= (KICK_ENERGY_RESERVE + 10) then
        return false
    end
    -- Energy pooling: wait if SnD/Rupture have > 2s remaining and energy < 50
    local energy = current_energy(me)
    local snd_rem = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    local rupture_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RUPTURE)
    if snd_rem > 2000 and energy < 50 then return false end
    if rupture_rem > 2000 and energy < 50 then return false end
    if ctx then
        local can_cast = resource_gate.rogue.can_finisher(ctx, 25, runtime.combo_points, min_combo_points)
        if not can_cast then
            return false
        end
    end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_RUPTURE) > 3000 then return false end
    -- TTD gate: don't Rupture if fight ending before it expires (v1.3)
    if ttd_tracker.get(target) < 12 then return false end
    if not utils.can_cast_hostile(runtime.rupture_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.rupture_id, target, "Rupture") then
        utils.log_debug(menu, "Rupture")
        note_cast()
                esp_renderer.on_cast(runtime.rupture_id, "Rupture", color.orange(220))
        return true
    end

    return false
end

local function try_eviscerate(me, target, ctx)
    if not menu.use_eviscerate:get_state() then
        return false
    end
    if not runtime.eviscerate_id or not utils.can_attack(me, target) then
        return false
    end
    if not combo_points_match_target(target) then
        return false
    end
    local min_combo_points = menu.finish_combo_points:get()
    -- Execute phase: lower CP threshold for Eviscerate
    local execute_phase = utils.get_health_pct(target) < 0.35
    local min_cp = execute_phase and 3 or 4
    if utils.get_buff_remaining_ms(me, spells.BUFF_BLADE_FLURRY) > 0 then
        min_combo_points = COMBAT_FINISHER_COMBO_POINTS
    end
    if runtime.combo_points < min_cp then
        return false
    end
    if (target:is_casting_spell() or target:is_channelling_spell()) and current_energy(me) <= (KICK_ENERGY_RESERVE + 10) then
        return false
    end
    -- Energy pooling: wait if SnD/Rupture have > 2s remaining and energy < 50
    local energy = current_energy(me)
    local snd_rem = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    local rupture_rem = utils.get_debuff_remaining_ms(target, spells.DEBUFF_RUPTURE)
    if snd_rem > 2000 and energy < 50 then return false end
    if rupture_rem > 2000 and energy < 50 then return false end
    if ctx then
        local can_cast = resource_gate.rogue.can_finisher(ctx, 35, runtime.combo_points, min_combo_points)
        if not can_cast then
            return false
        end
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE) < 2000 then
        return false
    end
    if not utils.can_cast_hostile(runtime.eviscerate_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.eviscerate_id, target, "Eviscerate") then
        utils.log_debug(menu, "Eviscerate")
        note_cast()
                esp_renderer.on_cast(runtime.eviscerate_id, "Eviscerate", color.red(220))
        return true
    end

    return false
end

local function try_sinister_strike(me, target, ctx)
    if not menu.use_sinister_strike:get_state() then
        return false
    end
    if not runtime.sinister_strike_id or not utils.can_attack(me, target) then
        return false
    end
    if (runtime.combo_points or 0) > 0 and not combo_points_match_target(target) then
        return false
    end
    if runtime.combo_points >= 5 then
        return false
    end
    if should_pool_for_finisher(me, target) then
        return false
    end
    if ctx then
        local can_cast = resource_gate.rogue.can_builder(ctx, 45, runtime.combo_points, 5)
        if not can_cast then
            return false
        end
    end
    if not utils.can_cast_hostile(runtime.sinister_strike_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.sinister_strike_id, target, "Sinister Strike") then
        utils.log_debug(menu, "Sinister Strike")
        note_cast()
                esp_renderer.on_cast(runtime.sinister_strike_id, "Sinister Strike", color.yellow(220))
        return true
    end

    return false
end

local function try_evasion(me)
    if not menu.use_evasion:get_state() then return false end
    if not runtime.evasion_id then
        runtime.evasion_id = utils.resolve_spell_id(spells.EVASION)
    end
    if not runtime.evasion_id then return false end
    local hp_pct = me:get_health_percentage() / 100
    if hp_pct > (menu.evasion_hp_pct:get() / 100) then return false end
    if utils.has_buff(me, spells.BUFF_EVASION) then return false end
    if not utils.can_cast_self(runtime.evasion_id, me) then return false end
    if utils.cast_self(runtime.evasion_id, me) then
        utils.log_debug(menu, "Evasion")
        return true
    end
    return false
end


-- --- Killing Spree (v1.1) -------------------------------------------------

local function try_killing_spree(me, target)
    -- Killing Spree (51690) is a WotLK spell - not available in TBC. No-op.
    return false
end



-- --- Feint - threat drop (v1.3) ------------------------------------------


-- --- Shiv - Deadly Poison refresh (v1.4) ---------------------------------
-- Use Shiv when Deadly Poison has < 2s remaining on target to refresh it
-- without consuming a combo point (costs energy, not CP).

local DEADLY_POISON_REFRESH_MS = 2000

local function try_shiv(me, target)
    if not menu.use_shiv or not menu.use_shiv:get_state() then return false end
    if not runtime.shiv_id then return false end
    -- Only worth using when Deadly Poison active and about to expire
    local dp_remain = utils.get_debuff_remaining_ms(target, spells.DEBUFF_DEADLY_POISON)
    if dp_remain <= 0 then return false end          -- not active
    if dp_remain > DEADLY_POISON_REFRESH_MS then return false end  -- not expiring yet
    if not utils.can_cast_hostile(runtime.shiv_id, me, target) then return false end
    if utils.cast_target(runtime.shiv_id, target, "Shiv") then
        utils.log_debug(menu, "Shiv (Deadly Poison refresh)")
        note_cast()
        return true
    end
    return false
end


local function try_feint(me)
    if not menu.use_feint or not menu.use_feint:get_state() then return false end
    if not runtime.feint_id then return false end
    -- Use Feint when threat is dangerously high (approximated by boss target)
    -- or when HP is low in solo as a damage-reduction tool
    local mode = current_mode()
    if mode == "raid" or mode == "dungeon" then
        if not utils.can_cast_self(runtime.feint_id, me) then return false end
        if utils.cast_self(runtime.feint_id, me, "Feint") then
            utils.log_debug(menu, "Feint")
            note_cast()
            return true
        end
    end
    return false
end

-- --- Expose Armor - boss-only debuff (v1.3) -------------------------------
-- Use as 5-CP finisher on bosses when Sunder Armor is not present.
-- Only in dungeon/raid mode where it matters.

local function try_expose_armor(me, target)
    if not menu.use_expose_armor or not menu.use_expose_armor:get_state() then return false end
    if not runtime.expose_armor_id then return false end
    local mode = current_mode()
    if mode == "solo" then return false end
    if not combo_points_match_target(target) then return false end
    -- Only use if Expose Armor not active AND Sunder Armor not active
    if utils.has_debuff(target, spells.DEBUFF_EXPOSE_ARMOR) then return false end
    if utils.has_debuff(target, spells.DEBUFF_SUNDERED_ARMOR) then return false end
    if runtime.combo_points < COMBAT_FINISHER_COMBO_POINTS then return false end
    if not utils.can_cast_hostile(runtime.expose_armor_id, me, target) then return false end
    if utils.cast_target(runtime.expose_armor_id, target, "Expose Armor") then
        utils.log_debug(menu, "Expose Armor")
        note_cast()
        return true
    end
    return false
end



-- --- Garrote opener (stealth) (v1.6) -----------------------------------------
-- Apply Garrote from stealth: strong bleed, silences for 3s, no CD.
-- Higher DPS than Ambush for Assassination; used for openers.

local function try_garrote(me, target)
    if not menu.use_garrote or not menu.use_garrote:get_state() then return false end
    if not runtime.garrote_id then return false end
    if not utils.has_buff(me, spells.BUFF_STEALTH) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if utils.has_debuff(target, spells.DEBUFF_GARROTE) then return false end
    if not utils.can_cast_hostile(runtime.garrote_id, me, target) then return false end
    if utils.cast_target(runtime.garrote_id, target, "Garrote") then
        utils.log_debug(menu, "Garrote (stealth opener)")
        note_cast()
        return true
    end
    return false
end

-- --- Riposte (v1.6) - after parry --------------------------------------------
-- Free attack that disarms target for 6s; Combat talent. Use immediately after parry.

local function try_riposte(me, target)
    if not menu.use_riposte or not menu.use_riposte:get_state() then return false end
    if not runtime.riposte_id then return false end
    -- Riposte is only usable after a parry (the game makes it usable automatically)
    if not utils.can_cast_hostile(runtime.riposte_id, me, target) then return false end
    if utils.cast_target(runtime.riposte_id, target, "Riposte") then
        utils.log_debug(menu, "Riposte")
        note_cast()
        return true
    end
    return false
end


local function try_cloak_of_shadows(me)
    if not menu.use_cloak or not menu.use_cloak:get_state() then return false end
    if not runtime.cloak_id then return false end
    local hp = me:get_health_percentage() / 100
    local threshold = menu.use_cloak_hp_pct and (menu.use_cloak_hp_pct:get() / 100) or 0.60
    if hp > threshold then return false end
    if not utils.can_cast_self(runtime.cloak_id, me) then return false end
    if utils.cast_self(runtime.cloak_id, me) then
        utils.log_debug(menu, "Cloak of Shadows")
        return true
    end
    return false
end
local function do_rotation(me, target)
    if not is_gcd_ready() then
        return false
    end

    if not utils.can_attack(me, target) then
        return false
    end

    if ttd_tracker and ttd_tracker.update then
        ttd_tracker.update(target)
    end

    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)
    local risk_snapshot = dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker)
    local hold_offense = dps_risk.should_hold_offense(risk_snapshot)
    local abort_finisher_commit = dps_risk.should_abort_commit(risk_snapshot, {
        kind = "melee_commit",
        progress_pct = 0.10,
        remaining_s = 0.30,
        projected_damage_pct = 0.05,
    })

    if target and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "rogue", utils) then
            return true
        end
    end

    if try_kick(me, target) then
        return true
    end

    track_target(me, target)

    if try_slice_and_dice(me, target, ctx) then invalidate_ctx() return true end
    -- Stack BF + AR together for maximum burst: fire BF first if available, then AR
    if (not hold_offense) then
        local bf_active = utils.has_buff(me, spells.BUFF_BLADE_FLURRY)
        local bf_available = runtime.blade_flurry_id and (_get_spell_cd(runtime.blade_flurry_id) or 0) <= 0
        if not bf_active and bf_available then
            if try_blade_flurry(me, target) then return true end
        end
        if try_adrenaline_rush(me) then return true end
    end
    if try_riposte(me, target) then invalidate_ctx() return true end
    if try_shiv(me, target) then invalidate_ctx() return true end
    if (not hold_offense) and (not abort_finisher_commit) then
        if try_expose_armor(me, target) then invalidate_ctx() return true end
        if try_rupture(me, target, ctx) then
            invalidate_ctx()
            return true
        end
        if try_eviscerate(me, target, ctx) then
            invalidate_ctx()
            return true
        end
    end
    if try_sinister_strike(me, target, ctx) then invalidate_ctx() return true end

    -- Auto-attack fallback for leveling 1-70
    -- (ensure_melee_auto_attack is called in the core combat lanes above)

    return false
end


local function update_set_bonus(me)
    local max_mult = 1.0
    local sets = { "Deathmantle", "DeathmantleBattlegear", "Terror" }
    for _, set_name in ipairs(sets) do
        local mult = utils.get_set_multiplier(me, set_name)
        if mult > max_mult then
            max_mult = mult
        end
    end
    runtime.set_multiplier = max_mult
end

reactive_adapter = {
    spec = "EAXRogueCombat",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "rogue", utils)
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

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "rogue", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = {
            handler = function(_, action_deps)
                local snapshot = dps_runtime.build_snapshot(action_deps.me, action_deps.current_target, encounter_manager, ttd_tracker)
                if not dps_risk.should_drop_threat(snapshot) then
                    return false
                end
                return try_feint and try_feint(action_deps.me) or false
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
}

local function on_render()
    return
end

local CP_BUILDERS = {}
local CP_FINISHERS = {}

local function register_cp_spell_set(dst, spell_list)
    if not spell_list then
        return
    end
    for _, id in ipairs(spell_list) do
        dst[id] = true
    end
end

local function build_cp_spell_sets()
    register_cp_spell_set(CP_BUILDERS, spells.SINISTER_STRIKE)
    register_cp_spell_set(CP_BUILDERS, spells.GARROTE)
    register_cp_spell_set(CP_BUILDERS, spells.AMBUSH)
    register_cp_spell_set(CP_FINISHERS, spells.SLICE_AND_DICE)
    register_cp_spell_set(CP_FINISHERS, spells.RUPTURE)
    register_cp_spell_set(CP_FINISHERS, spells.EVISCERATE)
    register_cp_spell_set(CP_FINISHERS, spells.EXPOSE_ARMOR)
end

build_cp_spell_sets()

local _last_cp_event_at = 0
local CP_EVENT_DEDUP_WINDOW_S = 0.15

local function on_spell_cast(data)
    if not data or not data.spell_id then return end

    local me = _get_local_player()
    if not me then return end
    if data.caster and data.caster:is_valid() and not utils.same_unit(data.caster, me) then
        return
    end

    local sid = data.spell_id
    if not CP_BUILDERS[sid] and not CP_FINISHERS[sid] then
        return
    end

    local now = _core_time()
    if (now - _last_cp_event_at) < CP_EVENT_DEDUP_WINDOW_S then
        return
    end
    _last_cp_event_at = now

    if CP_BUILDERS[sid] then
        local api_cp = get_current_combo_points(me)
        if api_cp ~= nil then
            runtime.combo_points = math.max(0, math.min(COMBAT_FINISHER_COMBO_POINTS, api_cp))
        else
            runtime.combo_points = math.min(COMBAT_FINISHER_COMBO_POINTS, runtime.combo_points + 1)
        end
        if data.target and data.target:is_valid() then
            runtime.combo_target = data.target
        end
        return
    end

    runtime.combo_points = 0
    runtime.combo_target = nil
end

core.register_on_spell_cast_callback(on_spell_cast)

-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD
core.register_on_update_callback(function()
    if not runtime.sinister_strike_id and utils.throttle("combat_spell_resolve", 2.0) then
        resolve_spells()
    end
    if utils.throttle("mode_refresh", 2.0) then
        runtime.cached_mode = current_mode()
    end

    if utils.throttle("set_bonus_check", 5.0) then
        local me = _get_local_player()
        if me then
            update_set_bonus(me)
        end
    end

    handle_toggle()
    if not menu.enabled:get_state() then
        return
    end

    local me = _get_local_player()
    if not me or me:is_dead() then
        return
    end
    if force_apply_poisons_cp then
        poison_manager.force_reapply()
        force_apply_poisons_cp = false
        core.log("[Eax Rogue Combat] Force reapply poisons requested")
    end
    if poison_manager.try_apply_poisons(me, menu, utils, current_poison_loadout()) then
        return
    end
        ooc_manager.on_update(me, menu, utils, { show_enchant_warning = true })

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

    enc = encounter_manager.get_policy(me)
    local current_target = me:get_target()
    local has_current_target = current_target and current_target:is_valid() and me:can_attack(current_target)
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and (not focus_target:is_valid() or not me:can_attack(focus_target)) then
        focus_target = nil
    end
    if me:is_in_combat() and focus_target and not has_current_target then
        core.input.set_target(focus_target)
    end
    local target = has_current_target and current_target or focus_target
    if not target or not target:is_valid() or not me:can_attack(target) then
        target = utils.find_best_target(me)
    end
    -- PvP: prioritize enemy players in arena/BG/world PvP
    local pvp_instance = pvp_manager.is_in_pvp_instance()
    if pvp_instance or pvp_manager.is_world_pvp(me) then
        local enemy_players = pvp_manager.find_enemy_players(me, 40)
        if #enemy_players > 0 then
            local priority = pvp_manager.priority_target(me, enemy_players)
            if priority then target = priority end
        end
    end
    do_rotation(me, target)
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.35, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        try_evasion(me)
    end
end)



-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxroguecombat_space_win")
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
        local label = "Eax Rogue Combat] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxroguecombat_enabled_cp")
        return elements
    end)
end


-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Rogue"
    local _eax_spec  = "Combat"
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
core.log("[Eax Rogue Combat] Loaded " .. (_pi and _pi.plugin_version or "?"))
