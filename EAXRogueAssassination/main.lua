-- Eax Rogue Assassination | main.lua

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

-- CC awareness: check if target can be CC'd (Sap, Gouge, Blind)
local function can_cc_target(target)
    local ok, cc = pcall(function() return require("common/utility/cc_data_helper") end)
    if not ok or not cc then return false end
    return cc.can_cc and cc.can_cc(target) or false
end

local force_apply_poisons_cp = false


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("assa", "Rogue Assa")
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
        spec = "EAXRogueAssassination",
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
---@type threat_manager
local threat_manager = require("libraries/threat_manager")

-- Guard to init threat_manager only once at startup
local threat_initialized = false

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")

local runtime = {
    mutilate_id = nil,
    sinister_strike_id = nil,
    envenom_id = nil,
    eviscerate_id = nil,
    slice_and_dice_id = nil,
    rupture_id = nil,
    expose_armor_id = nil,
    kick_id = nil,
    cold_blood_id = nil,
    shiv_id = nil,
    evasion_id = nil,
    vanish_id = nil,
    sprint_id = nil,
    blind_id = nil,
    feint_id = nil,
    garrote_id = nil,
    riposte_id = nil,
    combo_points = 0,
    combo_target = nil,
    cached_mode = "solo",
    prev_toggle_state = false,
    last_cast_time = 0,
    set_multiplier = 1.0,
}

-- Rotation context cache for resource-aware decisions
local ctx_cache = rotation_context.new({
    important_buffs = {
        slice_and_dice = spells.BUFF_SLICE_AND_DICE,
        cold_blood = spells.BUFF_COLD_BLOOD,
        blade_flurry = spells.BUFF_BLADE_FLURRY,
        stealth = spells.BUFF_STEALTH,
        evasion = spells.BUFF_EVASION,
    },
    important_debuffs = {
        rupture = spells.DEBUFF_RUPTURE,
        deadly_poison = spells.DEBUFF_DEADLY_POISON,
        expose_armor = spells.DEBUFF_EXPOSE_ARMOR,
        garrote = spells.DEBUFF_GARROTE,
    },
})

local GCD_CAST_INTERVAL = 1.0  -- TBC GCD
local KICK_ENERGY_RESERVE = 20
local ASSA_FINISHER_COMBO_POINTS = 5
local SND_REFRESH_CRITICAL_MS = 2000
local SND_CLIP_GUARD_MS = 10000
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

local function resolve_spells()
    runtime.mutilate_id = utils.resolve_spell_id(spells.MUTILATE)
    runtime.sinister_strike_id = utils.resolve_spell_id(spells.SINISTER_STRIKE)
    runtime.envenom_id = utils.resolve_spell_id(spells.ENVENOM)
    runtime.eviscerate_id = utils.resolve_spell_id(spells.EVISCERATE)
    runtime.slice_and_dice_id = utils.resolve_spell_id(spells.SLICE_AND_DICE)
    runtime.rupture_id = utils.resolve_spell_id(spells.RUPTURE)
    runtime.expose_armor_id = utils.resolve_spell_id(spells.EXPOSE_ARMOR)
    runtime.kick_id  = utils.resolve_spell_id(spells.KICK)
    runtime.shiv_id  = utils.resolve_spell_id(spells.SHIV)
    runtime.cold_blood_id = utils.resolve_spell_id(spells.COLD_BLOOD)
    runtime.vanish_id = utils.resolve_spell_id(spells.VANISH)
    runtime.sprint_id = utils.resolve_spell_id(spells.SPRINT)
    runtime.blind_id = utils.resolve_spell_id(spells.BLIND)
    runtime.feint_id = utils.resolve_spell_id(spells.FEINT)
    runtime.garrote_id = utils.resolve_spell_id(spells.GARROTE)
    runtime.riposte_id = utils.resolve_spell_id(spells.RIPOSTE)
    runtime.evasion_id = utils.resolve_spell_id(spells.EVASION)
end

local function log_resolved_spells()
    core.log(
        "[Eax Rogue Assassination] Resolved: Mut=" .. tostring(runtime.mutilate_id)
            .. " SS=" .. tostring(runtime.sinister_strike_id)
            .. " Env=" .. tostring(runtime.envenom_id)
            .. " SnD=" .. tostring(runtime.slice_and_dice_id)
            .. " Rupt=" .. tostring(runtime.rupture_id)
            .. " Expose=" .. tostring(runtime.expose_armor_id)
    )
end

resolve_spells()
log_resolved_spells()

local function current_mode()
    return utils.get_selected_mode(menu)
end

local assa_rotation_suspended_logged = false

local function is_assassination_rotation_available()
    local available = runtime.mutilate_id ~= nil
    if not available and not assa_rotation_suspended_logged then
        assa_rotation_suspended_logged = true
        core.log("[Eax Rogue Assassination] Mutilate not detected; suspending Assassination rotation to avoid off-spec conflicts.")
    end
    return available
end

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

local function get_combo_point_target(me)
    if not me or type(me.get_combo_points_target) ~= "function" then
        return nil
    end

    local ok, cp_target = pcall(me.get_combo_points_target, me)
    if not ok or not cp_target or not cp_target.is_valid or not cp_target:is_valid() or cp_target:is_dead() then
        return nil
    end

    return cp_target
end

local function combo_points_match_target(me, target)
    if runtime.combo_points <= 0 then
        return true
    end
    if not target or not target:is_valid() or target:is_dead() then
        return false
    end

    local cp_target = get_combo_point_target(me) or runtime.combo_target
    if not cp_target then
        return false
    end

    return utils.same_unit(cp_target, target)
end

local function consume_combo_points()
    runtime.combo_points = 0
    runtime.combo_target = nil
end


local function reset_combo_points_if_needed(me, target)
    local cp = get_current_combo_points(me)
    if cp == nil then return end

    runtime.combo_points = math.max(0, math.min(ASSA_FINISHER_COMBO_POINTS, cp))
    if runtime.combo_points <= 0 then
        runtime.combo_target = nil
        return
    end

    local cp_target = get_combo_point_target(me)
    if cp_target then
        runtime.combo_target = cp_target
        return
    end

    if runtime.combo_target and runtime.combo_target.is_valid and runtime.combo_target:is_valid() and not runtime.combo_target:is_dead() then
        return
    end

    runtime.combo_target = (target and target:is_valid() and not target:is_dead()) and target or nil
end

local function get_snd_refresh_window_ms()
    local refresh_seconds = menu.snd_refresh_seconds and menu.snd_refresh_seconds:get() or 3
    return math.max(SND_REFRESH_CRITICAL_MS, refresh_seconds * 1000)
end


local function try_vanish(me, target)
    if not menu.use_vanish or not menu.use_vanish:get_state() then return false end
    if not runtime.vanish_id then return false end
    local hp = me:get_health_percentage() / 100
    if hp > 0.30 then return false end  -- emergency only
    if not utils.can_cast_self(runtime.vanish_id, me) then return false end
    if utils.cast_self(runtime.vanish_id, me) then
        utils.log_debug(menu, "Vanish (emergency)")
        return true
    end
    return false
end

local function try_sprint_rogue(me, target)
    if not menu.use_sprint or not menu.use_sprint:get_state() then return false end
    if not runtime.sprint_id then return false end
    if not target or not target:is_valid() then return false end
    if utils.has_buff(me, spells.BUFF_SPRINT) then return false end
    -- Use sprint when target is out of melee range
    if utils.is_melee_target(me, target) then return false end
    if not utils.can_cast_self(runtime.sprint_id, me) then return false end
    if utils.cast_self(runtime.sprint_id, me) then
        utils.log_debug(menu, "Sprint")
        return true
    end
    return false
end

local function try_blind(me, target)
    if not menu.use_blind or not menu.use_blind:get_state() then return false end
    if not runtime.blind_id then return false end
    if not target or not target:is_valid() or target:is_dead() then return false end
    if current_mode() ~= "solo" then return false end
    local target_target = target:get_target()
    if not target_target or not utils.same_unit(target_target, me) then return false end
    local hp = me:get_health_percentage() / 100
    if hp > 0.35 then return false end  -- defensive use when low
    if not utils.can_cast_hostile(runtime.blind_id, me, target) then return false end
    if utils.cast_target(runtime.blind_id, target) then
        utils.log_debug(menu, "Blind (defensive)")
        return true
    end
    return false
end

local function try_kick(me, target)
    if not menu.use_kick:get_state() then
        return false
    end
    if not runtime.kick_id or not utils.can_attack(me, target) then
        return false
    end
    local ok_energy, energy = pcall(function() return me:get_power(3) end)
    if ok_energy and tonumber(energy) and tonumber(energy) < KICK_ENERGY_RESERVE then
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

local function try_cold_blood(me, target)
    local mode = current_mode()
    if enc and enc.hold_cooldowns then return false end
    if not menu.use_cold_blood:get_state() then
        return false
    end
    if mode == "solo" then
        return false
    end
    if not runtime.cold_blood_id then
        return false
    end
    if utils.get_buff_remaining_ms(me, spells.BUFF_COLD_BLOOD) > 0 then
        return false
    end
    -- Only use Cold Blood when Envenom is about to fire (DP stacks >= 3, CP >= 4)
    if target and target:is_valid() then
        local dp_stacks = utils.get_debuff_stacks(target, spells.DEBUFF_DEADLY_POISON) or 0
        if dp_stacks < 3 then return false end  -- wait for DP stacks
    end
    if runtime.combo_points < 4 then return false end  -- wait for CP
    if not utils.can_cast_self(runtime.cold_blood_id, me) then
        return false
    end

    if utils.cast_self_fast(runtime.cold_blood_id, me, "Cold Blood") then
        utils.log_debug(menu, "Cold Blood")
        note_cast()
        return true
    end

    return false
end

local function try_slice_and_dice(me, target, ctx)
    if not menu.use_slice_and_dice:get_state() then
        return false
    end
    if not runtime.slice_and_dice_id or runtime.combo_points <= 0 or not utils.can_attack(me, target) then
        return false
    end
    if not combo_points_match_target(me, target) then
        return false
    end

    local remaining_ms = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    local refresh_window_ms = get_snd_refresh_window_ms()
    if remaining_ms > SND_CLIP_GUARD_MS then
        return false
    end
    if remaining_ms > refresh_window_ms and remaining_ms > 0 then
        return false
    end

    local policy = encounter_manager.get_policy(me)
    local enemy_count = encounter_manager.enemy_count_in_range(me, 8)
    local regular_min_combo_points = math.min(menu.rupture_combo_points:get(), 4)
    if enemy_count >= 2 or (policy and policy.burn_phase) then
        regular_min_combo_points = 2
    end
    local min_combo_points = remaining_ms > 0 and regular_min_combo_points or 2
    if runtime.combo_points < min_combo_points or runtime.combo_points > ASSA_FINISHER_COMBO_POINTS then
        return false
    end
    if not utils.can_cast_target(runtime.slice_and_dice_id, me, target) then
        return false
    end

    if ctx then
        local can_cast = resource_gate.rogue.can_finisher(ctx, 25, runtime.combo_points, min_combo_points)
        if not can_cast then
            return false
        end
    end

    if utils.cast_target(runtime.slice_and_dice_id, target, "Slice and Dice") then
        utils.log_debug(menu, "Slice and Dice")
        consume_combo_points()
        note_cast()
        return true
    end

    return false
end

local function try_envenom(me, target, ctx)
    if not menu.use_envenom:get_state() then
        return false
    end
    if not runtime.envenom_id or not runtime.mutilate_id or not utils.can_attack(me, target) then
        return false
    end
    if not combo_points_match_target(me, target) then
        return false
    end
    -- Only Envenom when DP stacks >= 3
    local dp_stacks = utils.get_debuff_stacks(target, spells.DEBUFF_DEADLY_POISON) or 0
    if dp_stacks < 3 then return false end
    local required_combo_points = menu.envenom_combo_points:get()
    -- Execute phase: lower CP threshold for Envenom
    local execute_phase = utils.get_health_pct(target) < 0.35
    local min_cp = execute_phase and 3 or 4
    if runtime.set_multiplier > 1.0 then
        required_combo_points = math.max(4, required_combo_points - 1)
    end
    if runtime.combo_points < min_cp then
        return false
    end
    if runtime.combo_points < ASSA_FINISHER_COMBO_POINTS and runtime.set_multiplier <= 1.0 then
        return false
    end
    local ttd_s, snd_ms, poison_stacks = get_assa_finisher_windows(me, target)
    if ttd_s < 4 then
        return false
    end
    if snd_ms < get_snd_refresh_window_ms() then
        return false
    end

    if poison_stacks < menu.poison_stack_threshold:get() then
        return false
    end
    if ttd_s >= 16 and runtime.combo_points < ASSA_FINISHER_COMBO_POINTS then
        return false
    end
    local ok_energy, energy = pcall(function() return me:get_power(3) end)
    if (target:is_casting_spell() or target:is_channelling_spell()) and ok_energy and tonumber(energy) and tonumber(energy) <= (KICK_ENERGY_RESERVE + 10) then
        return false
    end
    if not utils.can_cast_hostile(runtime.envenom_id, me, target) then
        return false
    end

    -- Resource gate: need energy AND combo points for envenom
    if ctx then
        local can_cast, reason = resource_gate.rogue.can_finisher(ctx, 35, runtime.combo_points, required_combo_points)
        if not can_cast then
            return false
        end
    end

    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense and try_cold_blood(me, target) then
                esp_renderer.on_cast(nil, "Envenom", color.green(220))
        return true
    end

    if utils.cast_target(runtime.envenom_id, target, "Envenom") then
        utils.log_debug(menu, "Envenom at " .. tostring(poison_stacks) .. " stacks")
        consume_combo_points()
        note_cast()
        return true
    end

    return false
end

local function try_expose_armor(me, target)
    if current_mode() == "solo" then
        return false
    end
    if not runtime.expose_armor_id or not utils.can_attack(me, target) then
        return false
    end
    if not combo_points_match_target(me, target) then
        return false
    end
    if runtime.combo_points < ASSA_FINISHER_COMBO_POINTS then
        return false
    end
    if utils.has_debuff(target, spells.DEBUFF_EXPOSE_ARMOR) or utils.has_debuff(target, spells.DEBUFF_SUNDER_ARMOR) then
        return false
    end
    if not utils.can_cast_hostile(runtime.expose_armor_id, me, target) then
        return false
    end

    if utils.cast_target(runtime.expose_armor_id, target, "Expose Armor") then
        utils.log_debug(menu, "Expose Armor")
        consume_combo_points()
        note_cast()
        return true
    end

    return false
end

local function get_assa_finisher_windows(me, target)
    local ttd_s = tonumber(ttd_tracker.get(target)) or 0
    local snd_ms = utils.get_buff_remaining_ms(me, spells.BUFF_SLICE_AND_DICE)
    local poison_stacks = utils.get_debuff_stacks(target, spells.DEBUFF_DEADLY_POISON) or 0
    return ttd_s, snd_ms, poison_stacks
end

local function try_rupture(me, target, ctx)
    if not menu.use_rupture:get_state() then
        return false
    end
    if not runtime.rupture_id or not utils.can_attack(me, target) then
        return false
    end
    if not combo_points_match_target(me, target) then
        return false
    end
    local rupture_min_combo_points = math.max(menu.rupture_combo_points:get(), 4)
    if runtime.combo_points < rupture_min_combo_points then
        return false
    end
    local ttd_s, snd_ms = get_assa_finisher_windows(me, target)
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_RUPTURE) > 3000 then return false end
    if snd_ms < get_snd_refresh_window_ms() then
        return false
    end
    -- TTD gate: only spend on Rupture when it is likely to fully pay back.
    if ttd_s < 12 then return false end
    if ttd_s < 16 and runtime.combo_points < ASSA_FINISHER_COMBO_POINTS then
        return false
    end
    if not utils.can_cast_hostile(runtime.rupture_id, me, target) then
        return false
    end

    -- Resource gate: need energy for rupture
    if ctx then
        local can_cast, reason = resource_gate.rogue.can_finisher(ctx, 25, runtime.combo_points, menu.rupture_combo_points:get())
        if not can_cast then
            return false
        end
    end

    if utils.cast_target(runtime.rupture_id, target, "Rupture") then
        utils.log_debug(menu, "Rupture")
        consume_combo_points()
        note_cast()
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
    if not combo_points_match_target(me, target) then
        return false
    end
    local ttd_s, snd_ms, poison_stacks = get_assa_finisher_windows(me, target)
    if runtime.combo_points < 4 then
        return false
    end
    if snd_ms < get_snd_refresh_window_ms() then
        return false
    end
    if ttd_s >= 14 and poison_stacks >= menu.poison_stack_threshold:get() then
        return false
    end
    local ok_energy, energy = pcall(function() return me:get_power(3) end)
    if (target:is_casting_spell() or target:is_channelling_spell()) and ok_energy and tonumber(energy) and tonumber(energy) <= (KICK_ENERGY_RESERVE + 10) then
        return false
    end
    if not utils.can_cast_hostile(runtime.eviscerate_id, me, target) then
        return false
    end

    -- Resource gate: need energy for eviscerate
    if ctx then
        local can_cast, reason = resource_gate.rogue.can_finisher(ctx, 35, runtime.combo_points, 4)
        if not can_cast then
            return false
        end
    end

    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense and try_cold_blood(me, target) then
        return true
    end

    if utils.cast_target(runtime.eviscerate_id, target, "Eviscerate") then
        utils.log_debug(menu, "Eviscerate")
        consume_combo_points()
        note_cast()
        return true
    end

    return false
end

local function try_mutilate(me, target, ctx)
    if not menu.use_mutilate:get_state() then
        return false
    end
    if not runtime.mutilate_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points > 0 and not combo_points_match_target(me, target) then
        return false
    end
    if runtime.combo_points >= 5 then
        return false
    end
    local poison_stacks = utils.get_debuff_stacks(target, spells.DEBUFF_DEADLY_POISON) or 0
    if runtime.set_multiplier > 1.0 and runtime.combo_points >= 4 and poison_stacks >= menu.poison_stack_threshold:get() then
        return false
    end
    if not utils.can_cast_hostile(runtime.mutilate_id, me, target) then
        return false
    end

    -- Resource gate: need energy for mutilate builder
    if ctx then
        local can_cast, reason = resource_gate.rogue.can_builder(ctx, 60, runtime.combo_points, 5)
        if not can_cast then
            return false
        end
    end

    if utils.cast_target(runtime.mutilate_id, target, "Mutilate") then
        utils.log_debug(menu, "Mutilate")
        note_cast()
                esp_renderer.on_cast(runtime.mutilate_id, "Mutilate", color.purple(220))
        return true
    end

    return false
end

local function try_sinister_strike(me, target, ctx)
    if not runtime.sinister_strike_id or not utils.can_attack(me, target) then
        return false
    end
    if runtime.combo_points > 0 and not combo_points_match_target(me, target) then
        return false
    end
    if runtime.combo_points >= ASSA_FINISHER_COMBO_POINTS then
        return false
    end
    if ctx then
        local can_cast = resource_gate.rogue.can_builder(ctx, 45, runtime.combo_points, ASSA_FINISHER_COMBO_POINTS)
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


-- --- Feint - threat drop (v1.3) ------------------------------------------

local function try_feint(me)
    if not menu.use_feint or not menu.use_feint:get_state() then return false end
    if not runtime.feint_id then return false end
    local mode = utils.get_selected_mode and utils.get_selected_mode(menu) or "solo"
    if mode == "solo" then return false end
    if not utils.can_cast_self(runtime.feint_id, me) then return false end
    if utils.cast_self(runtime.feint_id, me, "Feint") then
        utils.log_debug(menu, "Feint")
        return true
    end
    return false
end



local function try_shiv(me, target, ctx)
    if not menu.use_shiv or not menu.use_shiv:get_state() then return false end
    if not runtime.shiv_id then return false end
    if not target or not target:is_valid() then return false end
    -- Check Deadly Poison duration
    local dp_remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_DEADLY_POISON)
    if dp_remaining > 2000 or dp_remaining <= 0 then return false end
    if ctx then
        local ok, energy = pcall(function() return me:get_power(3) end)
        if ok and type(energy) == "number" and energy < 20 then return false end
    end
    if not utils.can_cast_hostile(runtime.shiv_id, me, target) then return false end
    if utils.cast_target(runtime.shiv_id, target, "Shiv") then
        utils.log_debug(menu, "Shiv (DP refresh)")
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


local function do_rotation(me, target)
    if not is_gcd_ready() then
        return false
    end

    -- Get rotation context for resource-aware decisions
    local deps = {
        now_s = _core_time,
        get_gcd = _get_gcd,
    }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)

    -- Interrupt
    enc = encounter_manager.get_policy(me)
    if target and interrupt_manager.should_interrupt(target) and not enc.hold_cooldowns then
        if interrupt_manager.try_interrupt(me, target, "rogue", utils) then
            return true
        end
    end

    -- Racial CDs
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense and racial_manager.try_offensive(me) then
        return true
    end
    if racial_manager.try_utility(me, target) then return true end
    if racial_manager.try_defensive(me) then return true end

    -- Defensive abilities
    ttd_tracker.update(target)

    if defensive_manager.try_defensive(me, "rogue", utils) then
        return true
    end

    if try_vanish(me, target) then invalidate_ctx() return true end
    if try_sprint_rogue(me, target) then invalidate_ctx() return true end
    if try_blind(me, target) then invalidate_ctx() return true end
    if try_kick(me, target) then
        invalidate_ctx()
        return true
    end

    if not utils.can_attack(me, target) then
        return false
    end

    reset_combo_points_if_needed(me, target)

    if try_slice_and_dice(me, target, ctx) then invalidate_ctx() return true end
    if try_feint(me) then invalidate_ctx() return true end
    if try_expose_armor(me, target) then invalidate_ctx() return true end
    if try_envenom(me, target, ctx) then
        invalidate_ctx()
        return true
    end
    if try_rupture(me, target, ctx) then
        invalidate_ctx()
        return true
    end
    if try_eviscerate(me, target, ctx) then
        invalidate_ctx()
        return true
    end
    if try_garrote(me, target) then invalidate_ctx() return true end
    if try_shiv(me, target, ctx) then invalidate_ctx() return true end
    if try_mutilate(me, target, ctx) then invalidate_ctx() return true end
    if try_sinister_strike(me, target, ctx) then invalidate_ctx() return true end

    -- Auto-attack fallback for leveling 1-70
    -- (ensure_melee_auto_attack is called in the core combat lanes above)

    return false
end

-- --- Evasion - emergency dodge CD (v1.8.2) -------------------------------

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


local function update_set_bonus(me)
    local max_mult = 1.0
    local sets = { "Assassination", "Netherblade", "Deathmantle", "Slayers" }
    for _, set_name in ipairs(sets) do
        local set_mult = set_bonus.get_multiplier(me, set_name)
        if set_mult and set_mult > max_mult then
            max_mult = set_mult
        end
    end
    runtime.set_multiplier = max_mult
end

reactive_adapter = {
    spec = "EAXRogueAssassination",
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
                return try_vanish(action_deps.me, action_deps.current_target)
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
}

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
    register_cp_spell_set(CP_BUILDERS, spells.MUTILATE)
    register_cp_spell_set(CP_BUILDERS, spells.SINISTER_STRIKE)
    register_cp_spell_set(CP_BUILDERS, spells.BACKSTAB)
    register_cp_spell_set(CP_BUILDERS, spells.HEMORRHAGE)
    register_cp_spell_set(CP_BUILDERS, spells.AMBUSH)
    register_cp_spell_set(CP_BUILDERS, spells.GARROTE)
    register_cp_spell_set(CP_FINISHERS, spells.SLICE_AND_DICE)
    register_cp_spell_set(CP_FINISHERS, spells.RUPTURE)
    register_cp_spell_set(CP_FINISHERS, spells.EVISCERATE)
    register_cp_spell_set(CP_FINISHERS, spells.ENVENOM)
    register_cp_spell_set(CP_FINISHERS, spells.EXPOSE_ARMOR)
end

build_cp_spell_sets()

local _last_cp_event_at = 0
local CP_EVENT_DEDUP_WINDOW_S = 0.15

local function get_builder_combo_gain(spell_id)
    if runtime.mutilate_id and spell_id == runtime.mutilate_id then
        return 2
    end
    return 1
end

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
            runtime.combo_points = math.max(0, math.min(ASSA_FINISHER_COMBO_POINTS, api_cp))
        else
            runtime.combo_points = math.min(ASSA_FINISHER_COMBO_POINTS, runtime.combo_points + get_builder_combo_gain(sid))
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
    if (not runtime.mutilate_id or not runtime.sinister_strike_id) and utils.throttle("assa_spell_resolve", 2.0) then
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
        core.log("[Eax Rogue Assassination] Force reapply poisons requested")
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
    do_rotation(me, target)
    
    -- Self-emergency (Rogue has Sprint, Evasion, etc)
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.35, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_evasion then try_evasion(me) end
    end
end)



-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxrogueassassination_space_win")
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
        local label = "Eax Rogue Assa] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxrogueassassination_enabled_cp")
        return elements
    end)
end


-- -- Eax Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Rogue"
    local _eax_spec  = "Assassination"
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
core.log("[Eax Rogue Assassination] Loaded " .. (_pi and _pi.plugin_version or "?"))
