-- Eax Warrior Fury | main.lua
-- Callback registration, control-panel wiring, and documented Eax Warrior Fury logic.
-- APIs validated against .api/core.lua, .api/game_object.lua,
-- sylvanas-dev-docs-llm/pages/dev/api/auto-attack-helper.md,
-- sylvanas-dev-docs-llm/pages/dev/api/game-object.md,
-- sylvanas-dev-docs-llm/pages/dev/api/object-manager.md,
-- and sylvanas-dev-docs-llm/pages/dev/api/spellbook.md.

local menu = require("libraries/menu")
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

---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("libraries/ooc_manager")
---@type consumables_manager
local consumables_manager = require("libraries/consumables_manager")
---@type leveling_manager
local leveling_manager = require("libraries/leveling_manager")
local pvp_manager = require("libraries/pvp_manager")
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

-- CC awareness: check if target can be CC'd (Intimidating Shout)
local function can_cc_target(target)
    local ok, cc = pcall(function() return require("common/utility/cc_data_helper") end)
    if not ok or not cc then return false end
    return cc.can_cc and cc.can_cc(target) or false
end


---@type esp_renderer
local esp_renderer = require("libraries/esp_renderer")
esp_renderer.init("fury", "Warrior Fury")
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
        spec = "EAXWarriorFury",
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
---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")
---@type color
local color = require("libraries/color")
---@type vec2
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type swing_timer
local swing_timer = require("libraries/swing_timer")

local runtime = {
    bloodthirst_id = nil,
    whirlwind_id = nil,
    execute_id = nil,
    heroic_strike_id = nil,
    cleave_id = nil,
    sunder_armor_id = nil,
    hamstring_id = nil,
    intercept_id = nil,
    charge_id = nil,
    battle_shout_id = nil,
    bloodrage_id = nil,
    berserker_rage_id = nil,
    rampage_id = nil,
    pummel_id = nil,
    demoralizing_shout_id = nil,
    sweeping_strikes_id = nil,
    piercing_howl_id = nil,
    thunder_clap_id = nil,
    rend_id = nil,
    battle_stance_id = nil,
    berserker_stance_id = nil,
    death_wish_id = nil,
    recklessness_id = nil,
    blood_fury_id = nil,
    berserking_id = nil,
    slam_id = nil,
    overpower_id = nil,
    commanding_shout_id = nil,
    intimidating_shout_id = nil,
    stoneform_id = nil,
    war_stomp_id = nil,
    stance_swap_retention = 10,
    prev_toggle_state = false,
    prev_intimidating_shout_state = false,
    last_cast_time = 0,
    burst_window_active = false,
    burst_window_started_at = 0,
    burst_attempted = {},
    overpower_pending_return = false,
    overpower_queue_requested_at = 0,
    charge_pending_return = false,
    charge_queue_requested_at = 0,
    charge_stance_swap_pending = false,
    charge_stance_swap_requested_at = 0,
    last_on_next_attack_queue_at = 0,
    queued_on_next_attack_spell_id = nil,
    tc_dance_pending = false,
    tc_dance_return = false,
    last_overpower_usable = false,
    last_burst_window_active = false,
    last_slam_cast_game_time = 0,
    last_return_to_berserker_at = 0,
    returned_from_overpower_at = 0,
    proc_debug_next_log_at = 0,
    flurry_uptime_start = 0,
    enrage_uptime_start = 0,
    flurry_accumulated_ms = 0,
    enrage_accumulated_ms = 0,
    last_proc_sample_game_time = 0,
    cached_mode = "solo",
    cached_has_shaman = false,
    last_mode_debug_at = 0,
    pending_casts = {},
    set_multiplier = 1.0,
}

local ctx_cache = rotation_context.new({
    important_buffs = {},
    important_debuffs = {},
})

local BATTLE_SHOUT_REFRESH_MS = 5000
local DEMO_SHOUT_REFRESH_MS = 5000
local RAMPAGE_REFRESH_MS = 5000
local BLOODRAGE_MAX_RAGE = 60
local BLOODRAGE_MIN_HP_PCT = 0.70
local EXECUTE_HP_THRESHOLD = 0.20
local EXECUTE_MIN_RAGE = 31
local QUEUE_SWING_WINDOW_MS = 350
local BURST_LUST_WAIT_MS = 10000
local BURST_WINDOW_MS = 2500
local STANCE_BUFFER_RAGE = 5
local GCD_CAST_INTERVAL = 1.0  -- TBC GCD
local AOE_RADIUS = 8
local TRINKET_SLOT_1 = 13
local TRINKET_SLOT_2 = 14
local BLOODTHIRST_COST = 30
local WHIRLWIND_COST = 25
local SWEEPING_STRIKES_COST = 30
local THUNDER_CLAP_COST = 20
local REND_COST = 10
local OVERPOWER_COST = 5
local PIERCING_HOWL_COST = 10
local HAMSTRING_MIN_RAGE = 20
local HASTE_POTION_ITEM_ID = 22838
local DESTRUCTION_POTION_ITEM_ID = 22839
local DRUMS_OF_BATTLE_ITEM_ID = 29529
local DRUMS_OF_WAR_ITEM_ID = 29528
local SLAM_CANCEL_WINDOW_MS = 100
local NOTIFICATION_BURST_ID = "simplefury_burst_active"
local NOTIFICATION_OVERPOWER_ID = "simplefury_overpower_proc"
local NOTIFICATION_SLAM_ID = "simplefury_slam_weave"
local NOTIFICATION_RETURN_ID = "simplefury_return_berserker"
local PROC_DEBUG_INTERVAL_MS = 10000
local PROC_HUD_X = 20
local PROC_HUD_Y = 20
local PROC_HUD_WIDTH = 148
local PROC_HUD_HEIGHT = 54
local PROC_HUD_LINE_HEIGHT = 20
local CHARGE_STANCE_RETRY_DELAY = 0.75
local ON_NEXT_ATTACK_QUEUE_INTERVAL = 0.30
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75
local EXECUTE_SWING_SAFETY_BUFFER_S = 0.10
local SHAMAN_CLASS_ID = 7
local MODE_OPTIONS = { "Auto", "Solo", "Dungeon", "Raid" }
local MODE_DEBUG_INTERVAL_MS = 10000

local function resolve_spells()
    runtime.bloodthirst_id = utils.resolve_spell_id(spells.BLOODTHIRST)
    runtime.whirlwind_id = utils.resolve_spell_id(spells.WHIRLWIND)
    runtime.execute_id = utils.resolve_spell_id(spells.EXECUTE)
    runtime.heroic_strike_id = utils.resolve_spell_id(spells.HEROIC_STRIKE)
    runtime.cleave_id = utils.resolve_spell_id(spells.CLEAVE)
    runtime.sunder_armor_id = utils.resolve_spell_id(spells.SUNDER_ARMOR)
    runtime.hamstring_id = utils.resolve_spell_id(spells.HAMSTRING)
    runtime.intercept_id = utils.resolve_spell_id(spells.INTERCEPT)
    runtime.charge_id = utils.resolve_spell_id(spells.CHARGE)
    runtime.battle_shout_id = utils.resolve_spell_id(spells.BATTLE_SHOUT)
    runtime.bloodrage_id = utils.resolve_spell_id(spells.BLOODRAGE)
    runtime.berserker_rage_id = utils.resolve_spell_id(spells.BERSERKER_RAGE)
    runtime.rampage_id = utils.resolve_spell_id(spells.RAMPAGE)
    runtime.pummel_id = utils.resolve_spell_id(spells.PUMMEL)
    runtime.demoralizing_shout_id = utils.resolve_spell_id(spells.DEMORALIZING_SHOUT)
    runtime.sweeping_strikes_id = utils.resolve_spell_id(spells.SWEEPING_STRIKES)
    runtime.piercing_howl_id = utils.resolve_spell_id(spells.PIERCING_HOWL)
    runtime.thunder_clap_id = utils.resolve_spell_id(spells.THUNDER_CLAP)
    runtime.rend_id = utils.resolve_spell_id(spells.REND)
    runtime.battle_stance_id = utils.resolve_spell_id(spells.BATTLE_STANCE)
    runtime.berserker_stance_id = utils.resolve_spell_id(spells.BERSERKER_STANCE)
    runtime.death_wish_id = utils.resolve_spell_id(spells.DEATH_WISH)
    runtime.recklessness_id = utils.resolve_spell_id(spells.RECKLESSNESS)
    runtime.blood_fury_id = utils.resolve_spell_id(spells.BLOOD_FURY)
    runtime.berserking_id = utils.resolve_spell_id(spells.BERSERKING)
    runtime.slam_id = utils.resolve_spell_id(spells.SLAM)
    runtime.overpower_id = utils.resolve_spell_id(spells.OVERPOWER)
    runtime.commanding_shout_id = utils.resolve_spell_id(spells.COMMANDING_SHOUT)
    runtime.intimidating_shout_id = utils.resolve_spell_id(spells.INTIMIDATING_SHOUT)
    runtime.stoneform_id = utils.resolve_spell_id(spells.STONEFORM)
    runtime.war_stomp_id = utils.resolve_spell_id(spells.WAR_STOMP)
    runtime.stance_swap_retention = utils.get_stance_swap_retention()
end

local function log_resolved_spells()
    core.log("[Eax Warrior Fury] Resolved: BT=" .. tostring(runtime.bloodthirst_id)
        .. " WW=" .. tostring(runtime.whirlwind_id)
        .. " EX=" .. tostring(runtime.execute_id)
        .. " HS=" .. tostring(runtime.heroic_strike_id)
        .. " stance_ret=" .. tostring(runtime.stance_swap_retention))
end

local function validate_fury_spec()
    if runtime.bloodthirst_id then
        return true
    end

    if menu and menu.enabled and menu.enabled:get_state() then
        menu.enabled:set(false)
    end

    core.log("[Eax Warrior Fury] Bloodthirst not found; disabling addon to avoid interfering with non-Fury warrior specs.")
    return false
end

resolve_spells()
log_resolved_spells()
validate_fury_spec()

-- -- mode detection ----------------------------------------------------------

local function has_shaman_in_party()
    local me = _get_local_player()
    if not me then return false end

    local members = core.object_manager.get_party_members and core.object_manager.get_party_members() or nil
    if type(members) ~= "table" then
        return false
    end

    for _, unit in ipairs(members) do
        if unit and unit.is_valid and unit:is_valid() and not unit:is_dead() then
            local class_id = type(unit.get_class) == "function" and unit:get_class() or nil
            if class_id == 7 then
                return true
            end
        end
    end

    return false
end

local function refresh_mode_cache()
    local me = _get_local_player()
    runtime.cached_mode = utils.detect_mode(me)
    runtime.cached_has_shaman = has_shaman_in_party()
end

local function update_set_bonus(me)
    if not me then return end
    local best_multiplier = 1.0
    local set_names = { "WarbringerBattlegear", "DestroyerArmor", "OnslaughtArmor", "Ymirjar" }
    for _, set_name in ipairs(set_names) do
        local set_mult = set_bonus.get_multiplier(me, set_name)
        if set_mult and set_mult > best_multiplier then
            best_multiplier = set_mult
        end
    end
    runtime.set_multiplier = best_multiplier
end

local function get_set_rage_discount()
    if runtime.set_multiplier <= 1.0 then
        return 0
    end
    if runtime.set_multiplier >= 1.10 then
        return 2
    end
    return 1
end

local function get_effective_mode()
    local idx = menu.mode:get()
    if idx == 2 then return "solo" end
    if idx == 3 then return "dungeon" end
    if idx == 4 then return "raid" end
    return runtime.cached_mode -- Auto
end

local function should_sync_burst_with_lust()
    return get_effective_mode() == "raid" and runtime.cached_has_shaman
end

local function should_sync_consumables_with_burst()
    return get_effective_mode() == "raid"
end

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function get_battlefield_snapshot(me)
    local now_ms = _core_time()
    local snapshot = runtime.battlefield_snapshot
    if snapshot and snapshot.tick_ms == now_ms and snapshot.me == me then
        return snapshot
    end

    local my_pos = me and me:get_position() or nil
    local objects = core.object_manager.get_visible_objects()
    local hostiles = {}
    local nearest_attacker = nil
    local nearest_attacker_dist = math.huge

    for i = 1, #objects do
        local obj = objects[i]
        if obj
            and obj:is_valid()
            and obj:is_unit()
            and not obj:is_dead()
            and me:can_attack(obj)
        then
            hostiles[#hostiles + 1] = obj
            if my_pos and obj:is_in_combat() then
                local obj_target = obj:get_target()
                if obj_target and obj_target:is_valid() and obj_target == me then
                    local sq_dist = my_pos:squared_dist_to_ignore_z(obj:get_position())
                    if sq_dist < nearest_attacker_dist then
                        nearest_attacker = obj
                        nearest_attacker_dist = sq_dist
                    end
                end
            end
        end
    end

    snapshot = {
        tick_ms = now_ms,
        me = me,
        hostiles = hostiles,
        nearest_attacker = nearest_attacker,
    }
    runtime.battlefield_snapshot = snapshot
    return snapshot
end

--- Find the closest hostile unit that is targeting (attacking) us.
---@param me game_object
---@return game_object|nil
local function find_nearest_attacker(me)
    return get_battlefield_snapshot(me).nearest_attacker
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

local function clear_pending_cast(spell_id)
    if not spell_id then return end
    smart_cast_manager.clear_pending(spell_id)
end

local function refresh_pending_casts()
end

local function is_pending_or_current(spell_id)
    return is_pending_cast(spell_id) or utils.is_spell_already_queued(spell_id)
end

local function is_gcd_lane_ready()
    return is_gcd_ready()
end

local function get_home_stance()
    if runtime.berserker_stance_id
        and core.spell_book.is_spell_learned(runtime.berserker_stance_id)
    then
        return "berserker"
    end
    return "battle"
end

local function get_home_stance_id()
    if get_home_stance() == "berserker" then
        return runtime.berserker_stance_id
    end
    return runtime.battle_stance_id
end

local function reset_on_next_attack_queue_state()
    runtime.queued_on_next_attack_spell_id = nil
end

local function update_stance_return_requests(me, target)
    if runtime.charge_queue_requested_at > 0 then
        local charge_confirmed = me:is_in_combat()
            or (runtime.charge_id and _get_spell_cd(runtime.charge_id) > 0)
            or (target and utils.is_melee_target(me, target))

        if charge_confirmed then
            runtime.charge_queue_requested_at = 0
            runtime.charge_pending_return = true
        elseif (_core_time() - runtime.charge_queue_requested_at) > 1.25 then
            runtime.charge_queue_requested_at = 0
        end
    end

    if runtime.overpower_queue_requested_at > 0 then
        local overpower_confirmed = runtime.overpower_id
            and _get_spell_cd(runtime.overpower_id) > 0

        if overpower_confirmed then
            runtime.overpower_queue_requested_at = 0
            runtime.overpower_pending_return = true
        elseif (_core_time() - runtime.overpower_queue_requested_at) > 0.75 then
            runtime.overpower_queue_requested_at = 0
        end
    end
end

local function is_spell_group_learned(id_table)
    for i = 1, #id_table do
        if core.spell_book.is_spell_learned(id_table[i]) then
            return true
        end
    end

    return false
end

local function close_burst_window(reason, completed)
    if runtime.burst_window_active then
        utils.log_debug(menu, "Burst window closed: " .. reason)
    end

    runtime.burst_window_active = false
    runtime.burst_window_started_at = 0
    if completed then
        runtime.burst_attempted._completed = true
    end
end

local function open_burst_window()
    runtime.burst_window_active = true
    runtime.burst_window_started_at = core.game_time()
    runtime.burst_attempted = {}
    utils.log_debug(menu, "Burst window opened")
end

local function get_spell_cooldown_or_large(spell_id)
    if not spell_id then
        return 99
    end

    return _get_spell_cd(spell_id)
end

local function get_nearby_hostiles(me, radius)
    local targets = {}
    local snapshot = get_battlefield_snapshot(me)
    local my_pos = me:get_position()
    local objects = snapshot.hostiles

    for i = 1, #objects do
        local obj = objects[i]
        if obj
            and obj:is_valid()
            and obj:is_unit()
            and not obj:is_dead()
            and me:can_attack(obj)
            and utils.is_melee_target(me, obj)
        then
            local obj_pos = obj:get_position()
            local threshold = radius + obj:get_bounding_radius()
            local sq_dist = my_pos:squared_dist_to_ignore_z(obj_pos)
            if sq_dist <= (threshold * threshold) then
                targets[#targets + 1] = obj
            end
        end
    end

    return targets
end

local function sample_proc_states(me)
    local now_ms = core.game_time()
    if not me:is_in_combat() then
        return
    end

    if runtime.last_proc_sample_game_time <= 0 then
        runtime.last_proc_sample_game_time = now_ms
        runtime.proc_debug_next_log_at = PROC_DEBUG_INTERVAL_MS
        return
    end

    local delta_ms = math.max(0, now_ms - runtime.last_proc_sample_game_time)
    runtime.last_proc_sample_game_time = now_ms

    local flurry_active = utils.has_buff(me, spells.BUFF_FLURRY)
    if flurry_active then
        if runtime.flurry_uptime_start <= 0 then
            runtime.flurry_uptime_start = now_ms
        end
        runtime.flurry_accumulated_ms = runtime.flurry_accumulated_ms + delta_ms
    else
        runtime.flurry_uptime_start = 0
    end

    local enrage_active = utils.has_buff(me, spells.BUFF_ENRAGE)
    if enrage_active then
        if runtime.enrage_uptime_start <= 0 then
            runtime.enrage_uptime_start = now_ms
        end
        runtime.enrage_accumulated_ms = runtime.enrage_accumulated_ms + delta_ms
    else
        runtime.enrage_uptime_start = 0
    end

    local combat_elapsed = auto_attack:get_current_combat_game_time()
    if runtime.proc_debug_next_log_at <= 0 then
        runtime.proc_debug_next_log_at = PROC_DEBUG_INTERVAL_MS
    end

    if menu.track_procs:get_state()
        and menu.show_notifications:get_state()
        and combat_elapsed >= runtime.proc_debug_next_log_at
    then
        local divisor = math.max(1, combat_elapsed)
        local flurry_pct = (runtime.flurry_accumulated_ms / divisor) * 100
        local enrage_pct = (runtime.enrage_accumulated_ms / divisor) * 100
        core.log(string.format(
            "[Eax Fury] Proc uptime %.0fs: Flurry %.1f%% | Enrage %.1f%%",
            divisor / 1000,
            flurry_pct,
            enrage_pct
        ))
        runtime.proc_debug_next_log_at = runtime.proc_debug_next_log_at + PROC_DEBUG_INTERVAL_MS
    end
end

local function should_cast_execute(target_hp_pct, ctx)
    if not menu.use_execute:get_state() then return false end
    if not runtime.execute_id then return false end
    if target_hp_pct >= EXECUTE_HP_THRESHOLD then return false end
    local can_cast = resource_gate.warrior.has_rage(ctx, EXECUTE_MIN_RAGE)
    if not can_cast then return false end

    local bt_cd = get_spell_cooldown_or_large(runtime.bloodthirst_id)
    return bt_cd > 1.5
end

local function execute_reserve_rage(extra_cost, rage_discount)
    return EXECUTE_MIN_RAGE + math.max(0, extra_cost - (rage_discount or 0))
end

local function get_weapon_speed_seconds(me, hand)
    if not me then return nil end

    local speed_getter = nil
    if hand == "mainhand" and me.get_attack_time then
        speed_getter = me.get_attack_time
    elseif hand == "offhand" and me.get_offhand_attack_time then
        speed_getter = me.get_offhand_attack_time
    end

    if not speed_getter then
        return nil
    end

    local ok, speed = pcall(function()
        return speed_getter(me)
    end)

    if not ok or type(speed) ~= "number" or speed <= 0 then
        return nil
    end

    return speed
end

local function is_fast_one_hand_execute_setup(me)
    local mainhand_speed = get_weapon_speed_seconds(me, "mainhand")
    local offhand_speed = get_weapon_speed_seconds(me, "offhand")
    if not mainhand_speed or not offhand_speed then
        return false
    end

    return mainhand_speed <= 2.0 and offhand_speed <= 2.0
end

local function is_execute_swing_safe(me)
    if swing_timer.is_swing_safe(me, EXECUTE_SWING_SAFETY_BUFFER_S) then
        return true
    end

    return swing_timer.can_cast_before_swing(me, 0.25, EXECUTE_SWING_SAFETY_BUFFER_S)
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

local function add_notification_once(unique_id, label, message, duration_s, notification_color)
    if not menu.show_notifications:get_state() then
        return false
    end

    if core.graphics.is_notification_active(unique_id) then
        return false
    end

    return core.graphics.add_notification(unique_id, label, message, duration_s, notification_color)
end

local function try_shout(me)
    if not menu.use_battle_shout:get_state() then return false end

    local shout_id = runtime.battle_shout_id
    local shout_buff = spells.BUFF_BATTLE_SHOUT
    local shout_name = "Battle Shout"

    if menu.use_commanding_shout:get_state()
        and runtime.commanding_shout_id
        and core.spell_book.is_spell_learned(runtime.commanding_shout_id)
    then
        shout_id = runtime.commanding_shout_id
        shout_buff = spells.BUFF_COMMANDING_SHOUT
        shout_name = "Commanding Shout"
    end

    if not shout_id then return false end

    local remaining = utils.get_buff_remaining_ms(me, shout_buff)
    if remaining >= BATTLE_SHOUT_REFRESH_MS then
        return false
    end

    if is_pending_or_current(shout_id) then
        return false
    end

    if utils.can_cast_self(shout_id, me) and utils.cast_self(shout_id, me) then
        mark_pending_cast(shout_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, shout_name .. " refresh (" .. remaining .. "ms)")
        note_cast()
        return true
    end

    return false
end

-- try_battle_shout is an alias for try_shout (handles both Battle/Commanding Shout)
local try_battle_shout = try_shout

local function try_demo_shout(me, target)
    if not menu.use_demo_shout:get_state() or not runtime.demoralizing_shout_id then return false end
    if not target or not utils.is_melee_target(me, target) then return false end

    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_DEMORALIZING_SHOUT)
    if remaining >= DEMO_SHOUT_REFRESH_MS then
        return false
    end

    if utils.can_cast_self(runtime.demoralizing_shout_id, me)
        and utils.cast_self(runtime.demoralizing_shout_id, me)
    then
        utils.log_debug(menu, "Demoralizing Shout refresh (" .. remaining .. "ms)")
        note_cast()
        return true
    end

    return false
end

local function try_bloodrage(me, rage)
    if not menu.use_bloodrage:get_state() or not runtime.bloodrage_id then return false end
    if not me:is_in_combat() then return false end
    if rage > BLOODRAGE_MAX_RAGE then return false end
    if utils.get_health_pct(me) < BLOODRAGE_MIN_HP_PCT then return false end

    if is_pending_or_current(runtime.bloodrage_id) then
        return false
    end

    if utils.can_cast_self(runtime.bloodrage_id, me) and utils.cast_self_fast(runtime.bloodrage_id, me) then
        mark_pending_cast(runtime.bloodrage_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Bloodrage (" .. rage .. " rage)")
        note_cast()
        return true
    end

    return false
end

local function try_berserker_rage(me)
    if not menu.use_berserker_rage:get_state() or not runtime.berserker_rage_id then return false end
    if not me:is_in_combat() then return false end
    if utils.get_current_stance(me) ~= "berserker" then return false end

    if is_pending_or_current(runtime.berserker_rage_id) then
        return false
    end

    if utils.can_cast_self(runtime.berserker_rage_id, me) and utils.cast_self_fast(runtime.berserker_rage_id, me) then
        mark_pending_cast(runtime.berserker_rage_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Berserker Rage")
        note_cast()
        return true
    end

    return false
end

local function try_rampage(me)
    if not menu.use_rampage:get_state() or not runtime.rampage_id then return false end
    if not core.spell_book.is_spell_learned(runtime.rampage_id) then return false end

    local remaining = utils.get_buff_remaining_ms(me, spells.BUFF_RAMPAGE)
    local rampage_stacks = utils.get_buff_stacks(me, spells.BUFF_RAMPAGE) or 0
    -- Refresh when stacks < 5 OR duration < threshold
    if rampage_stacks >= 5 and remaining >= RAMPAGE_REFRESH_MS then
        return false
    end

    if is_pending_or_current(runtime.rampage_id) then
        return false
    end

    if utils.can_cast_self(runtime.rampage_id, me) and utils.cast_self(runtime.rampage_id, me) then
        mark_pending_cast(runtime.rampage_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Rampage refresh (" .. remaining .. "ms, " .. rampage_stacks .. " stacks)")
        note_cast()
        return true
    end

    return false
end

local function do_self_only_upkeep(me)
    if try_rampage(me) then return true end
    if try_shout(me) then return true end
    return false
end

local function try_sunder_armor(me, target, target_hp_pct)
    if not menu.use_sunder_armor:get_state() or not runtime.sunder_armor_id then return false end
    if target_hp_pct < EXECUTE_HP_THRESHOLD then return false end
    if not utils.is_melee_target(me, target) then return false end

    if not should_do_noncore_upkeep() then
        return false
    end

    local data = buff_manager:get_debuff_data(target, spells.DEBUFF_SUNDER_ARMOR)
    local stack_count = 0
    if data and data.is_active then
        stack_count = data.count or 0
    end

    if stack_count >= menu.sunder_max_stacks:get() then
        return false
    end

    if utils.can_cast_melee(runtime.sunder_armor_id, me)
        and utils.cast_target(runtime.sunder_armor_id, target)
    then
        utils.log_debug(menu, "Sunder Armor (" .. tostring(stack_count) .. " -> " .. tostring(stack_count + 1) .. ")")
        note_cast()
        return true
    end

    return false
end

local function do_utility_upkeep(me, target, rage, target_hp_pct)
    if try_rampage(me) then return true end
    if not should_do_noncore_upkeep() then return false end
    if try_shout(me) then return true end
    if try_demo_shout(me, target) then return true end
    if try_sunder_armor(me, target, target_hp_pct) then return true end
    if try_bloodrage(me, rage) then return true end
    if try_berserker_rage(me) then return true end
    return false
end

local function try_pummel(me, target)
    if not menu.use_pummel:get_state() or not runtime.pummel_id then return false end
    if not utils.is_melee_target(me, target) then return false end

    local is_casting = target:is_casting_spell() and target:is_active_spell_interruptable()
    local is_channeling = target:is_channelling_spell()
    if not is_casting and not is_channeling then
        return false
    end

    if utils.can_cast_melee(runtime.pummel_id, me) and utils.cast_target_fast(runtime.pummel_id, target) then
        utils.log_debug(menu, "Pummel")
        note_cast()
        return true
    end

    return false
end

local function try_heroic_strike(me, target, ctx, rage, target_hp_pct, is_aoe)
    -- HS is disabled during execute phase - dump all rage into Execute instead
    if target_hp_pct < EXECUTE_HP_THRESHOLD then
        return false
    end
    if not menu.use_heroic_strike:get_state() or not runtime.heroic_strike_id then
        return false
    end
    local can_queue = resource_gate.warrior.can_queue_dump(ctx, 10, 60)
    if not can_queue then
        return false
    end
    if rage < menu.heroic_strike_rage:get() then
        return false
    end
    local rage_discount = get_set_rage_discount()
    local bt_cd = get_spell_cooldown_or_large(runtime.bloodthirst_id)
    local ww_cd = get_spell_cooldown_or_large(runtime.whirlwind_id)
    local bt_reserve = math.max(15, BLOODTHIRST_COST - rage_discount) + 5
    local ww_reserve = math.max(20, WHIRLWIND_COST - rage_discount) + 5
    if bt_cd <= 1.5 and rage < math.max(menu.heroic_strike_rage:get(), bt_reserve) then
        return false
    end
    if ww_cd <= 1.5 and rage < math.max(menu.heroic_strike_rage:get(), ww_reserve) then
        return false
    end
    if not utils.can_cast_melee(runtime.heroic_strike_id, me) then
        return false
    end
    if utils.is_spell_already_queued(runtime.heroic_strike_id) then
        return false
    end
    if utils.cast_target(runtime.heroic_strike_id, target) then
        runtime.last_on_next_attack_queue_at = _core_time()
        runtime.queued_on_next_attack_spell_id = runtime.heroic_strike_id
        utils.log_debug(menu, "Queue: Heroic Strike")
        invalidate_ctx()
        return true
    end
    return false
end

local function offensive_potion_is_available(me)
    if not me then return false end

    if menu.use_haste_potion:get_state()
        and utils.is_consumable_ready(me, HASTE_POTION_ITEM_ID)
    then
        return true
    end

    if menu.use_destruction_potion:get_state()
        and utils.is_consumable_ready(me, DESTRUCTION_POTION_ITEM_ID)
    then
        return true
    end

    return false
end

local function try_healthstone(me)
    if not menu.use_healthstone:get_state() then return false end
    if not me:is_in_combat() then return false end
    if utils.get_health_pct(me) >= (menu.healthstone_hp_pct:get() / 100) then return false end

    for i = 1, #spells.HEALTHSTONE_ITEMS do
        local item_id = spells.HEALTHSTONE_ITEMS[i]
        if utils.use_consumable_if_ready(me, item_id) then
            utils.log_debug(menu, "Defensive: Healthstone")
            note_cast()
            return true
        end
    end

    return false
end

local function try_health_potion(me)
    if not menu.use_health_potion:get_state() then return false end
    if not me:is_in_combat() then return false end
    if utils.get_health_pct(me) >= (menu.health_potion_hp_pct:get() / 100) then return false end

    -- Skip if we still have an offensive potion available (shared cooldown).
    if offensive_potion_is_available(me) then return false end

    for i = 1, #spells.HEALING_POTION_ITEMS do
        local item_id = spells.HEALING_POTION_ITEMS[i]
        if utils.use_consumable_if_ready(me, item_id) then
            utils.log_debug(menu, "Defensive: Healing Potion")
            note_cast()
            return true
        end
    end

    return false
end

local function try_stoneform(me)
    if not menu.use_stoneform:get_state() or not runtime.stoneform_id then return false end
    if not me:is_in_combat() then return false end
    if utils.get_health_pct(me) >= (menu.stoneform_hp_pct:get() / 100) then return false end
    if utils.has_buff(me, spells.BUFF_STONEFORM) then return false end
    if not core.spell_book.is_spell_learned(runtime.stoneform_id) then return false end

    if utils.can_cast_self(runtime.stoneform_id, me) and utils.cast_self(runtime.stoneform_id, me) then
        utils.log_debug(menu, "Defensive: Stoneform")
        note_cast()
        return true
    end

    return false
end

local function try_war_stomp_interrupt(me, target)
    if not menu.use_war_stomp_interrupt:get_state() or not runtime.war_stomp_id then return false end
    if not target or not utils.is_melee_target(me, target) then return false end
    if not target:is_valid() or target:is_dead() or not me:can_attack(target) then return false end

    local is_casting = target:is_casting_spell() and target:is_active_spell_interruptable()
    local is_channeling = target:is_channelling_spell()
    if not is_casting and not is_channeling then
        return false
    end

    if not core.spell_book.is_spell_learned(runtime.war_stomp_id) then return false end
    if utils.can_cast_self(runtime.war_stomp_id, me) and utils.cast_self_fast(runtime.war_stomp_id, me) then
        utils.log_debug(menu, "War Stomp interrupt")
        note_cast()
        return true
    end

    return false
end

reactive_adapter = {
    spec = "EAXWarriorFury",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "warrior", utils)
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

                return interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "warrior", utils)
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = { noop = "unsupported" },
        throughput_resume = { noop = "unsupported" },
    },
}

local function try_return_to_berserker(me)
    if not runtime.overpower_pending_return then return false end
    local home = get_home_stance()
    local home_id = get_home_stance_id()
    if not home_id then return false end
    if utils.get_current_stance(me) == home then
        runtime.overpower_pending_return = false
        runtime.overpower_queue_requested_at = 0
        return false
    end

    if utils.can_cast_self(home_id, me)
        and utils.cast_self(home_id, me)
    then
        runtime.overpower_pending_return = false
        runtime.overpower_queue_requested_at = 0
        runtime.returned_from_overpower_at = core.game_time()
        runtime.last_return_to_berserker_at = core.game_time()
        utils.set_tracked_stance(home)
        utils.log_debug(menu, "Stance -> " .. home .. " (Overpower return)")
        note_cast()
        return true
    end

    return false
end

local function try_return_after_charge(me)
    if not runtime.charge_pending_return then return false end
    local home = get_home_stance()
    local home_id = get_home_stance_id()
    if not home_id then return false end
    if utils.get_current_stance(me) == home then
        runtime.charge_pending_return = false
        runtime.charge_queue_requested_at = 0
        return false
    end

    if utils.can_cast_self(home_id, me)
        and utils.cast_self(home_id, me)
    then
        runtime.charge_pending_return = false
        runtime.charge_queue_requested_at = 0
        runtime.last_return_to_berserker_at = core.game_time()
        utils.set_tracked_stance(home)
        utils.log_debug(menu, "Stance -> " .. home .. " (Charge return)")
        note_cast()
        return true
    end

    return false
end

--[[ DISABLED: Overpower is Battle Stance only (Arms), not Fury
local function try_overpower_dance(me, target, rage)
    if not menu.use_overpower:get_state() or not runtime.overpower_id then return false end
    if not target or not utils.is_melee_target(me, target) then return false end
    if not utils.can_stance_dance_for_cost(rage, OVERPOWER_COST, 0, runtime.stance_swap_retention) then return false end
    if not core.spell_book.is_spell_learned(runtime.overpower_id) then return false end
    if not core.spell_book.is_usable_spell(runtime.overpower_id) then return false end
    if rage < (OVERPOWER_COST + runtime.stance_swap_retention + 10) then return false end

    local bt_cd = get_spell_cooldown_or_large(runtime.bloodthirst_id)
    local ww_cd = get_spell_cooldown_or_large(runtime.whirlwind_id)
    if bt_cd <= 4.0 or ww_cd <= 4.0 then
        return false
    end

    if utils.get_current_stance(me) ~= "battle" then
        if runtime.battle_stance_id
            and utils.can_cast_self(runtime.battle_stance_id, me)
            and not is_pending_or_current(runtime.battle_stance_id)
            and utils.cast_self(runtime.battle_stance_id, me)
        then
            mark_pending_cast(runtime.battle_stance_id, PENDING_CAST_TIMEOUT_S)
            utils.set_tracked_stance("battle")
            utils.log_debug(menu, "Stance -> battle (Overpower)")
            note_cast()
                    esp_renderer.on_cast(runtime.battle_stance_id, "Overpower", color.red(220))
        return true
        end

        return false
    end

    if not is_pending_or_current(runtime.overpower_id)
        and utils.can_cast_melee(runtime.overpower_id, me)
        and utils.cast_target(runtime.overpower_id, target)
    then
        runtime.overpower_queue_requested_at = _core_time()
        mark_pending_cast(runtime.overpower_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Overpower")
        note_cast()
        return true
    end

    return false
end
--]]

local function is_bt_ww_window_open(bt_cd, ww_cd)
    return bt_cd > 3.0 and ww_cd > 3.0
end

local function should_do_noncore_upkeep()
    local bt_cd = get_spell_cooldown_or_large(runtime.bloodthirst_id)
    local ww_cd = get_spell_cooldown_or_large(runtime.whirlwind_id)
    return is_bt_ww_window_open(bt_cd, ww_cd)
end

--[[ DISABLED: Rend is Arms-only, not Fury
local function try_rend_in_battle_stance(me, target, rage)
    if not menu.use_rend:get_state() or not runtime.rend_id then return false end
    if not target or not utils.is_melee_target(me, target) then return false end
    if utils.get_current_stance(me) ~= "battle" then return false end
    if rage < (REND_COST + 10) then return false end
    if utils.has_debuff(target, spells.DEBUFF_REND) then return false end

    local bt_cd = get_spell_cooldown_or_large(runtime.bloodthirst_id)
    local ww_cd = get_spell_cooldown_or_large(runtime.whirlwind_id)
    if bt_cd <= 5.5 or ww_cd <= 5.5 then
        return false
    end

    if runtime.overpower_id
        and core.spell_book.is_spell_learned(runtime.overpower_id)
        and core.spell_book.is_usable_spell(runtime.overpower_id)
    then
        return false
    end

    if utils.can_cast_melee(runtime.rend_id, me) and utils.cast_target(runtime.rend_id, target) then
        utils.log_debug(menu, "Rend")
        note_cast()
        return true
    end

    return false
end
--]]

local function death_wish_is_unavailable(me)
    if not menu.use_death_wish:get_state() then return true end
    if not runtime.death_wish_id then return true end
    if utils.has_buff(me, spells.BUFF_DEATH_WISH) then return false end
    return runtime.burst_attempted.death_wish == true
end

local function recklessness_is_unavailable(me)
    if not menu.use_recklessness:get_state() then return true end
    if not runtime.recklessness_id then return true end
    if utils.has_buff(me, spells.BUFF_RECKLESSNESS) then return false end
    return runtime.burst_attempted.recklessness == true
end

local function has_available_burst_action(me)
    if menu.use_death_wish:get_state()
        and runtime.death_wish_id
        and not utils.has_buff(me, spells.BUFF_DEATH_WISH)
        and utils.can_cast_self(runtime.death_wish_id, me)
    then
        return true
    end

    if menu.use_recklessness:get_state()
        and runtime.recklessness_id
        and not utils.has_buff(me, spells.BUFF_RECKLESSNESS)
        and utils.can_cast_self(runtime.recklessness_id, me)
    then
        return true
    end

    if menu.use_blood_fury:get_state()
        and runtime.blood_fury_id
        and not utils.has_buff(me, spells.BUFF_BLOOD_FURY)
        and utils.can_cast_self(runtime.blood_fury_id, me)
    then
        return true
    end

    if menu.use_berserking:get_state()
        and runtime.berserking_id
        and not utils.has_buff(me, spells.BUFF_BERSERKING)
        and utils.can_cast_self(runtime.berserking_id, me)
    then
        return true
    end

    if menu.use_trinkets:get_state() and #utils.get_self_cast_trinket_ids(me) > 0 then
        return true
    end

    return false
end

local function should_open_burst_window(me, target)
    if runtime.burst_window_active then return false end
    if runtime.burst_attempted._completed then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if not has_available_burst_action(me) then return false end

    if should_sync_burst_with_lust() then
        if utils.has_buff(me, spells.BUFF_BLOODLUST_HEROISM) then
            return true
        end

        return auto_attack:get_current_combat_game_time() >= BURST_LUST_WAIT_MS
    end

    return true
end

local function all_enabled_burst_actions_attempted()
    if menu.use_death_wish:get_state() and runtime.death_wish_id and not runtime.burst_attempted.death_wish then
        return false
    end

    if menu.use_recklessness:get_state() and runtime.recklessness_id and not runtime.burst_attempted.recklessness then
        return false
    end

    if menu.use_blood_fury:get_state() and runtime.blood_fury_id and not runtime.burst_attempted.blood_fury then
        return false
    end

    if menu.use_berserking:get_state() and runtime.berserking_id and not runtime.burst_attempted.berserking then
        return false
    end

    if menu.use_trinkets:get_state() then
        if not runtime.burst_attempted.trinket_13 then return false end
        if not runtime.burst_attempted.trinket_14 then return false end
    end

    return true
end

local function attempt_death_wish(me)
    if not menu.use_death_wish:get_state() or runtime.burst_attempted.death_wish then return false end

    runtime.burst_attempted.death_wish = true
    if not runtime.death_wish_id or utils.has_buff(me, spells.BUFF_DEATH_WISH) then return false end

    if is_pending_or_current(runtime.death_wish_id) then
        return false
    end

    if utils.can_cast_self(runtime.death_wish_id, me) and utils.cast_self_fast(runtime.death_wish_id, me) then
        mark_pending_cast(runtime.death_wish_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Burst: Death Wish")
        note_cast()
        return true
    end

    return false
end

local function attempt_recklessness(me)
    if not menu.use_recklessness:get_state() or runtime.burst_attempted.recklessness then return false end
    if not utils.has_buff(me, spells.BUFF_DEATH_WISH) and not death_wish_is_unavailable(me) then return false end

    runtime.burst_attempted.recklessness = true
    if not runtime.recklessness_id or utils.has_buff(me, spells.BUFF_RECKLESSNESS) then return false end

    if is_pending_or_current(runtime.recklessness_id) then
        return false
    end

    if utils.can_cast_self(runtime.recklessness_id, me) and utils.cast_self_fast(runtime.recklessness_id, me) then
        mark_pending_cast(runtime.recklessness_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Burst: Recklessness")
        note_cast()
        return true
    end

    return false
end

local function attempt_blood_fury(me)
    if not menu.use_blood_fury:get_state() or runtime.burst_attempted.blood_fury then return false end

    local lust_active = utils.has_buff(me, spells.BUFF_BLOODLUST_HEROISM)
    local burst_buff_active = utils.has_buff(me, spells.BUFF_DEATH_WISH) or utils.has_buff(me, spells.BUFF_RECKLESSNESS)
    local burst_prereq_failed = death_wish_is_unavailable(me) and recklessness_is_unavailable(me)
    if not lust_active and not burst_buff_active and not burst_prereq_failed then return false end

    runtime.burst_attempted.blood_fury = true
    if not runtime.blood_fury_id or utils.has_buff(me, spells.BUFF_BLOOD_FURY) then return false end

    if is_pending_or_current(runtime.blood_fury_id) then
        return false
    end

    if utils.can_cast_self(runtime.blood_fury_id, me) and utils.cast_self_fast(runtime.blood_fury_id, me) then
        mark_pending_cast(runtime.blood_fury_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Burst: Blood Fury")
        note_cast()
        return true
    end

    return false
end

local function attempt_berserking(me)
    if not menu.use_berserking:get_state() or runtime.burst_attempted.berserking then return false end

    local lust_active = utils.has_buff(me, spells.BUFF_BLOODLUST_HEROISM)
    local burst_buff_active = utils.has_buff(me, spells.BUFF_DEATH_WISH) or utils.has_buff(me, spells.BUFF_RECKLESSNESS)
    local burst_prereq_failed = death_wish_is_unavailable(me) and recklessness_is_unavailable(me)
    if not lust_active and not burst_buff_active and not burst_prereq_failed then return false end

    runtime.burst_attempted.berserking = true
    if not runtime.berserking_id or utils.has_buff(me, spells.BUFF_BERSERKING) then return false end

    if is_pending_or_current(runtime.berserking_id) then
        return false
    end

    if utils.can_cast_self(runtime.berserking_id, me) and utils.cast_self_fast(runtime.berserking_id, me) then
        mark_pending_cast(runtime.berserking_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Burst: Berserking")
        note_cast()
        return true
    end

    return false
end

local function has_active_potion_buff(me)
    return utils.has_buff(me, spells.BUFF_HASTE_POTION)
        or utils.has_buff(me, spells.BUFF_DESTRUCTION_POTION)
end

local function do_consumable_lane(me)
    if not me:is_in_combat() then return false end
    if should_sync_consumables_with_burst() and not runtime.burst_window_active then
        return false
    end

    if not has_active_potion_buff(me) then
        if menu.use_haste_potion:get_state()
            and utils.use_consumable_if_ready(me, HASTE_POTION_ITEM_ID)
        then
            utils.log_debug(menu, "Consumable: Haste Potion")
            note_cast()
            return true
        end

        if menu.use_destruction_potion:get_state()
            and utils.use_consumable_if_ready(me, DESTRUCTION_POTION_ITEM_ID)
        then
            utils.log_debug(menu, "Consumable: Destruction Potion")
            note_cast()
            return true
        end
    end

    if menu.use_drums:get_state() then
        if not utils.has_buff(me, spells.BUFF_DRUMS_OF_BATTLE)
            and utils.use_consumable_if_ready(me, DRUMS_OF_BATTLE_ITEM_ID)
        then
            utils.log_debug(menu, "Consumable: Drums of Battle")
            note_cast()
            return true
        end

        if not utils.has_buff(me, spells.BUFF_DRUMS_OF_WAR)
            and utils.use_consumable_if_ready(me, DRUMS_OF_WAR_ITEM_ID)
        then
            utils.log_debug(menu, "Consumable: Drums of War")
            note_cast()
            return true
        end
    end

    return false
end

local function attempt_trinket(slot_id, key)
    if not menu.use_trinkets:get_state() or runtime.burst_attempted[key] then return false end

    runtime.burst_attempted[key] = true
    local item_id = utils.get_equipped_item_id_in_slot(_get_local_player(), slot_id)
    if not item_id then return false end

    if utils.use_item_if_ready(item_id) then
        utils.log_debug(menu, "Burst: Trinket slot " .. tostring(slot_id))
        note_cast()
        return true
    end

    return false
end

local function do_burst_lane(me, target)
    if should_open_burst_window(me, target) then
        open_burst_window()
    end

    if not runtime.burst_window_active then return false end
    if not is_valid_hostile_target(me, target) then
        close_burst_window("target invalid", false)
        return false
    end

    if (core.game_time() - runtime.burst_window_started_at) > BURST_WINDOW_MS then
        close_burst_window("window elapsed", true)
        return false
    end

    if attempt_death_wish(me) then return true end
    if attempt_recklessness(me) then return true end
    if attempt_blood_fury(me) then return true end
    if attempt_berserking(me) then return true end
    if do_consumable_lane(me) then return true end
    if attempt_trinket(TRINKET_SLOT_1, "trinket_13") then return true end
    if attempt_trinket(TRINKET_SLOT_2, "trinket_14") then return true end

    if all_enabled_burst_actions_attempted() then
        close_burst_window("all actions attempted", true)
    end

    return false
end

local function get_aoe_execute_target(me, fallback_target)
    if not menu.use_execute_sniping:get_state() then
        return fallback_target
    end

    return utils.find_execute_snipe_target(me, fallback_target, AOE_RADIUS)
end

local function try_slam_or_hamstring_filler(me, target, ctx, rage, target_hp_pct, label, is_aoe)
    -- If we are in execute phase, try to queue Heroic Strike (single target) or Cleave (AoE)
    if target_hp_pct < EXECUTE_HP_THRESHOLD then
        if try_heroic_strike(me, target, ctx, rage, target_hp_pct, is_aoe) then
            return true
        end
    end

    if not target or not utils.is_melee_target(me, target) then return false end

    local bt_cd = get_spell_cooldown_or_large(runtime.bloodthirst_id)
    local ww_cd = get_spell_cooldown_or_large(runtime.whirlwind_id)
    if not is_bt_ww_window_open(bt_cd, ww_cd) then
        return false
    end

    if menu.use_slam_weave:get_state()
        and runtime.slam_id
        and resource_gate.warrior.has_rage(ctx, 25)
        and rage >= HAMSTRING_MIN_RAGE
        and target_hp_pct >= EXECUTE_HP_THRESHOLD
        and utils.can_cast_melee(runtime.slam_id, me)
        and utils.can_slam_without_clipping(me, runtime.slam_id, menu.slam_safety_buffer_ms:get())
        and utils.cast_target(runtime.slam_id, target)
    then
        runtime.last_slam_cast_game_time = core.game_time()
        utils.log_debug(menu, label .. ": Slam filler")
        note_cast()
                esp_renderer.on_cast(runtime.slam_id, "Slam", color.orange(220))
        return true
    end

    if menu.use_hamstring_filler:get_state()
        and runtime.hamstring_id
        and rage >= (HAMSTRING_MIN_RAGE + 10)
        and target_hp_pct >= EXECUTE_HP_THRESHOLD
        and utils.can_cast_melee(runtime.hamstring_id, me)
        and utils.cast_target(runtime.hamstring_id, target)
    then
        utils.log_debug(menu, label .. ": Hamstring filler")
        note_cast()
        return true
    end

    return false
end

local function update_notifications(me, target)
    if not menu.show_notifications:get_state() then
        runtime.last_burst_window_active = runtime.burst_window_active
        runtime.last_overpower_usable = runtime.overpower_id
            and core.spell_book.is_spell_learned(runtime.overpower_id)
            and core.spell_book.is_usable_spell(runtime.overpower_id)
            or false
        return
    end

    local now_ms = core.game_time()
    local overpower_usable = runtime.overpower_id
        and core.spell_book.is_spell_learned(runtime.overpower_id)
        and core.spell_book.is_usable_spell(runtime.overpower_id)
        or false

    if runtime.burst_window_active and not runtime.last_burst_window_active then
        add_notification_once(NOTIFICATION_BURST_ID, "Eax Warrior Fury", "Burst window active", 1.5, color.gold(220))
    end

    if overpower_usable and not runtime.last_overpower_usable and is_valid_hostile_target(me, target) then
        add_notification_once(NOTIFICATION_OVERPOWER_ID, "Eax Warrior Fury", "Overpower available", 1.5, color.orange(220))
    end

    if runtime.last_slam_cast_game_time > 0 and (now_ms - runtime.last_slam_cast_game_time) <= 1000 then
        add_notification_once(NOTIFICATION_SLAM_ID, "Eax Warrior Fury", "Slam weave", 1.0, color.cyan(220))
    end

    if runtime.last_return_to_berserker_at > 0 and (now_ms - runtime.last_return_to_berserker_at) <= 1000 then
        add_notification_once(NOTIFICATION_RETURN_ID, "Eax Warrior Fury", "Returned to Berserker", 1.0, color.blue(220))
    end

    runtime.last_burst_window_active = runtime.burst_window_active
    runtime.last_overpower_usable = overpower_usable
end

local function try_tc_dance_return(me)
    if not runtime.tc_dance_return then return false end
    local home = get_home_stance()
    local home_id = get_home_stance_id()
    if not home_id then return false end
    if utils.get_current_stance(me) == home then
        runtime.tc_dance_return = false
        return false
    end
    if utils.can_cast_self(home_id, me) and utils.cast_self(home_id, me) then
        mark_pending_cast(home_id, PENDING_CAST_TIMEOUT_S)
        utils.set_tracked_stance(home)
        runtime.tc_dance_return = false
        utils.log_debug(menu, "Stance -> " .. home .. " (TC dance return)")
        note_cast()
        return true
    end
    return false
end

local function do_single_target_core_lane(me, target, ctx, rage, target_hp_pct)
    if try_tc_dance_return(me) then return true end
    local execute_phase_active = target_hp_pct <= 0.20
    local fast_one_hand_execute = execute_phase_active and is_fast_one_hand_execute_setup(me)
    local execute_swing_safe = (not execute_phase_active) or is_execute_swing_safe(me)
    local rage_discount = get_set_rage_discount()
    local bt_can_cast = runtime.bloodthirst_id
        and resource_gate.warrior.has_rage(ctx, math.max(15, BLOODTHIRST_COST - rage_discount))
        and utils.can_cast_hostile_no_usable(runtime.bloodthirst_id, me, target)
        or false
    local ww_can_cast = runtime.whirlwind_id
        and utils.is_melee_target(me, target)
        and resource_gate.warrior.has_rage(ctx, math.max(20, WHIRLWIND_COST - rage_discount))
        and _get_spell_cd(runtime.whirlwind_id) <= 0
        or false
    local ex_can_cast = should_cast_execute(target_hp_pct, ctx)
        and utils.can_cast_hostile_no_usable(runtime.execute_id, me, target)
        or false

    if execute_phase_active then
        local bt_reserve = execute_reserve_rage(BLOODTHIRST_COST, rage_discount)
        local ww_reserve = execute_reserve_rage(WHIRLWIND_COST, rage_discount)
        if rage < bt_reserve then
            bt_can_cast = false
        end
        if rage < ww_reserve then
            ww_can_cast = false
        end
    end

    if execute_phase_active and fast_one_hand_execute then
        -- Fast-1H execute lane: explicit execute-first behavior with queue support.
        if execute_swing_safe and ex_can_cast and not is_pending_or_current(runtime.execute_id) then
            if utils.cast_target(runtime.execute_id, target) then
                mark_pending_cast(runtime.execute_id, PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "ST Execute (fast-1H): Execute")
                note_cast()
                invalidate_ctx()
                return true
            end
        end

        if try_heroic_strike(me, target, ctx, rage, target_hp_pct, false) then
            return true
        end
    end

    -- Flurry-aware decision making: prioritize Bloodthirst when Flurry is about to expire
    local flurry_about_to_expire = false
    if runtime.flurry_uptime_start > 0 then
        local remaining_flurry = utils.get_buff_remaining_ms(me, spells.BUFF_FLURRY)
        if remaining_flurry <= 1000 then  -- <= 1 swing remaining
            flurry_about_to_expire = true
        end
    end

    if bt_can_cast and not is_pending_or_current(runtime.bloodthirst_id) then
        -- If Flurry is about to expire, prioritize BT to refresh it
        if flurry_about_to_expire or not ww_can_cast then
            if utils.cast_target(runtime.bloodthirst_id, target) then
                mark_pending_cast(runtime.bloodthirst_id, PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "ST: Bloodthirst (Flurry priority)")
                note_cast()
                invalidate_ctx()
                return true
            end
        end
    end

    if ww_can_cast and not is_pending_or_current(runtime.whirlwind_id) then
        if utils.cast_target(runtime.whirlwind_id, target) then
            mark_pending_cast(runtime.whirlwind_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "ST: Whirlwind")
            note_cast()
            invalidate_ctx()
            return true
        end
    end

    if execute_swing_safe and ex_can_cast and not is_pending_or_current(runtime.execute_id) then
        if utils.cast_target(runtime.execute_id, target) then
            mark_pending_cast(runtime.execute_id, PENDING_CAST_TIMEOUT_S)
            if execute_phase_active and not fast_one_hand_execute then
                utils.log_debug(menu, "ST Execute (non-fast): Execute")
            else
                utils.log_debug(menu, "ST: Execute")
            end
            note_cast()
            invalidate_ctx()
            return true
        end
    end

    if try_slam_or_hamstring_filler(me, target, ctx, rage, target_hp_pct, "ST") then
        invalidate_ctx()
        return true
    end

    -- Low-level fallback: when core abilities (BT/WW) are not yet learned,
    -- use basic abilities so the rotation always has something to press.
    if not runtime.bloodthirst_id and not runtime.whirlwind_id then
        if runtime.rend_id
            and not utils.has_debuff(target, spells.DEBUFF_REND)
            and utils.is_melee_target(me, target)
            and rage >= REND_COST
            and utils.can_cast_melee(runtime.rend_id, me)
            and utils.cast_target(runtime.rend_id, target)
        then
            utils.log_debug(menu, "ST: Rend (leveling)")
            note_cast()
            return true
        end

        if runtime.thunder_clap_id
            and utils.is_melee_target(me, target)
            and rage >= THUNDER_CLAP_COST
            and not utils.has_debuff(target, spells.DEBUFF_THUNDER_CLAP)
            and utils.can_cast_melee(runtime.thunder_clap_id, me)
            and utils.cast_target(runtime.thunder_clap_id, target)
        then
            utils.log_debug(menu, "ST: Thunder Clap (leveling)")
            note_cast()
            return true
        end
    end

    return false
end

local function try_switch_to_stance(me, spell_id, stance_name, rage, ability_cost)
    if not spell_id then return false end
    if utils.get_current_stance(me) == stance_name then return false end
    if not utils.can_stance_dance_for_cost(rage, ability_cost, STANCE_BUFFER_RAGE, runtime.stance_swap_retention) then
        return false
    end

    if is_pending_or_current(spell_id) then
        return false
    end

    if utils.can_cast_self(spell_id, me) and utils.cast_self(spell_id, me) then
        mark_pending_cast(spell_id, PENDING_CAST_TIMEOUT_S)
        utils.set_tracked_stance(stance_name)
        utils.log_debug(menu, "Stance -> " .. stance_name)
        note_cast()
        return true
    end

    return false
end


-- --- Thunder Clap debuff maintenance (Battle Stance dance) (v1.6) -------------
-- Pattern from tbc/ warrior/dps/rotation.go tryMaintainDebuffs.
-- Swap to Battle, apply TC, swap back. Only in dungeons/raid where it matters.

local function try_thunder_clap_dance(me, target, rage)
    if not menu.use_thunder_clap_aoe:get_state() then return false end
    if not runtime.thunder_clap_id then return false end
    if not target or not utils.is_melee_target(me, target) then return false end
    if utils.has_debuff(target, spells.DEBUFF_THUNDER_CLAP) then return false end

    local mode = get_effective_mode()
    if mode == "solo" then return false end  -- not worth the GCD loss in solo

    -- We need rage for the stance swap + TC (20 rage)
    if not utils.can_stance_dance_for_cost(rage, 20, 0, runtime.stance_swap_retention) then
        return false
    end

    local current = utils.get_current_stance(me)
    if current ~= "battle" then
        -- Swap to Battle first
        if runtime.battle_stance_id
           and not is_pending_or_current(runtime.battle_stance_id)
           and utils.can_cast_self(runtime.battle_stance_id, me)
           and utils.cast_self(runtime.battle_stance_id, me)
        then
            mark_pending_cast(runtime.battle_stance_id, PENDING_CAST_TIMEOUT_S)
            utils.set_tracked_stance("battle")
            runtime.tc_dance_pending = true
            utils.log_debug(menu, "Stance -> Battle (TC dance)")
            note_cast()
            return true
        end
        return false
    end

    -- Already in Battle: cast TC
    if runtime.tc_dance_pending or current == "battle" then
        if utils.can_cast_melee(runtime.thunder_clap_id, me)
           and utils.cast_target(runtime.thunder_clap_id, target)
        then
            utils.log_debug(menu, "Thunder Clap (debuff dance)")
            note_cast()
            runtime.tc_dance_pending = false
            -- Schedule immediate return to Berserker/home stance
            runtime.tc_dance_return = true
            return true
        end
    end
    return false
end



local function do_aoe_core_lane(me, target, ctx, rage)
    if enc and not enc.aoe_safe then return false end
    local primary_target = utils.find_best_aoe_target(me, target, AOE_RADIUS) or target
    local execute_target = get_aoe_execute_target(me, primary_target)
    local rage_discount = get_set_rage_discount()
    local execute_phase_active = execute_target and utils.get_health_pct(execute_target) < EXECUTE_HP_THRESHOLD
    local ww_reserve = execute_reserve_rage(WHIRLWIND_COST, rage_discount)
    local bt_reserve = execute_reserve_rage(BLOODTHIRST_COST, rage_discount)

    if menu.use_sweeping_strikes:get_state()
        and runtime.sweeping_strikes_id
        and not utils.has_buff(me, spells.BUFF_SWEEPING_STRIKES)
    then
        if utils.get_current_stance(me) ~= "battle" then
            if try_switch_to_stance(me, runtime.battle_stance_id, "battle", rage, SWEEPING_STRIKES_COST) then
                return true
            end
        elseif utils.can_cast_self(runtime.sweeping_strikes_id, me)
            and utils.cast_self(runtime.sweeping_strikes_id, me)
        then
            utils.log_debug(menu, "AoE: Sweeping Strikes")
            note_cast()
            return true
        end
    end

    if menu.use_thunder_clap_aoe:get_state()
        and runtime.thunder_clap_id
        and utils.get_current_stance(me) == "battle"
        and utils.has_buff(me, spells.BUFF_SWEEPING_STRIKES)
        and primary_target
        and utils.is_melee_target(me, primary_target)
        and rage >= THUNDER_CLAP_COST
        and not utils.has_debuff(primary_target, spells.DEBUFF_THUNDER_CLAP)
        and utils.can_cast_melee(runtime.thunder_clap_id, me)
        and utils.cast_target(runtime.thunder_clap_id, primary_target)
    then
        utils.log_debug(menu, "AoE: Thunder Clap (Sweeping window)")
        note_cast()
        return true
    end

    if runtime.whirlwind_id and runtime.berserker_stance_id then
        if utils.get_current_stance(me) ~= "berserker" then
            if try_switch_to_stance(me, runtime.berserker_stance_id, "berserker", rage, WHIRLWIND_COST) then
                return true
            end
        elseif primary_target and utils.is_melee_target(me, primary_target)
            and resource_gate.warrior.has_rage(ctx, math.max(20, WHIRLWIND_COST - rage_discount))
            and ((not execute_phase_active) or rage >= ww_reserve)
            and _get_spell_cd(runtime.whirlwind_id) <= 0
        then
            if not is_pending_or_current(runtime.whirlwind_id)
                and utils.cast_target(runtime.whirlwind_id, primary_target)
            then
                mark_pending_cast(runtime.whirlwind_id, PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "AoE: Whirlwind")
                note_cast()
                invalidate_ctx()
                return true
            end
        end
    end

    if primary_target and runtime.bloodthirst_id
        and resource_gate.warrior.has_rage(ctx, math.max(15, BLOODTHIRST_COST - rage_discount))
        and ((not execute_phase_active) or rage >= bt_reserve)
        and utils.can_cast_hostile(runtime.bloodthirst_id, me, primary_target)
    then
        if not is_pending_or_current(runtime.bloodthirst_id)
            and utils.cast_target(runtime.bloodthirst_id, primary_target)
        then
            mark_pending_cast(runtime.bloodthirst_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "AoE: Bloodthirst")
            note_cast()
            invalidate_ctx()
            return true
        end
    end

    if execute_target and should_cast_execute(utils.get_health_pct(execute_target), ctx)
        and utils.can_cast_hostile_no_usable(runtime.execute_id, me, execute_target)
    then
        if not is_pending_or_current(runtime.execute_id)
            and utils.cast_target(runtime.execute_id, execute_target)
        then
            mark_pending_cast(runtime.execute_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "AoE: Execute")
            note_cast()
            invalidate_ctx()
            return true
        end
    end

    if primary_target and try_slam_or_hamstring_filler(
            me,
            primary_target,
            ctx,
            rage,
            utils.get_health_pct(primary_target),
            "AoE"
        ) then
        invalidate_ctx()
        return true
    end

    return false
end

local function try_intercept(me, target)
    if not menu.use_intercept:get_state() or not runtime.intercept_id then return false end
    if not me:is_in_combat() then return false end
    if utils.get_current_stance(me) ~= "berserker" then return false end
    if utils.is_melee_target(me, target) then return false end

    local distance = utils.get_distance_to_target(me, target)
    if distance < menu.intercept_min_range:get() then
        return false
    end

    if utils.can_cast_hostile(runtime.intercept_id, me, target) and utils.cast_target(runtime.intercept_id, target) then
        utils.log_debug(menu, "Intercept (" .. string.format("%.1f", distance) .. " yd)")
        note_cast()
        return true
    end

    return false
end

local function try_charge_opener(me, target)
    if not menu.use_charge_opener:get_state() then
        reset_charge_stance_request()
        runtime.charge_queue_requested_at = 0
        return false
    end
    if not runtime.charge_id then
        reset_charge_stance_request()
        runtime.charge_queue_requested_at = 0
        return false
    end
    if runtime.charge_queue_requested_at > 0 then
        return true
    end
    if me:is_in_combat() then return false end
    if not is_valid_hostile_target(me, target) then
        reset_charge_stance_request()
        runtime.charge_queue_requested_at = 0
        return false
    end
    if utils.is_melee_target(me, target) then
        reset_charge_stance_request()
        runtime.charge_queue_requested_at = 0
        return false
    end
    if not core.spell_book.is_spell_learned(runtime.charge_id) then
        reset_charge_stance_request()
        runtime.charge_queue_requested_at = 0
        return false
    end
    if _get_spell_cd(runtime.charge_id) > 0 then
        reset_charge_stance_request()
        runtime.charge_queue_requested_at = 0
        return false
    end

    local distance = utils.get_distance_to_target(me, target)
    local min_range = math.max(8, core.spell_book.get_spell_min_range(runtime.charge_id) or 0)
    local max_range = core.spell_book.get_spell_max_range(runtime.charge_id) or 25
    if distance < min_range or distance > max_range then
        reset_charge_stance_request()
        runtime.charge_queue_requested_at = 0
        return false
    end

    local stance = utils.get_current_stance(me)
    if stance ~= "battle" then
        if runtime.charge_stance_swap_pending
            and (_core_time() - runtime.charge_stance_swap_requested_at) < CHARGE_STANCE_RETRY_DELAY
        then
            return true
        end

        if runtime.battle_stance_id
            and utils.can_cast_self(runtime.battle_stance_id, me)
            and not is_pending_or_current(runtime.battle_stance_id)
            and utils.cast_self(runtime.battle_stance_id, me)
        then
            mark_pending_cast(runtime.battle_stance_id, PENDING_CAST_TIMEOUT_S)
            runtime.charge_stance_swap_pending = true
            runtime.charge_stance_swap_requested_at = _core_time()
            utils.set_tracked_stance("battle")
            utils.log_debug(menu, "Stance -> battle (Charge opener)")
            note_cast()
            return true
        end

        return false
    end

    if runtime.charge_stance_swap_pending then
        reset_charge_stance_request()
    end

    if not is_pending_or_current(runtime.charge_id) and utils.cast_target(runtime.charge_id, target) then
        runtime.charge_queue_requested_at = _core_time()
        mark_pending_cast(runtime.charge_id, PENDING_CAST_TIMEOUT_S)
        reset_charge_stance_request()
        utils.log_debug(menu, "Charge opener (" .. string.format("%.1f", distance) .. " yd)")
        note_cast()
        return true
    end

    return false
end

local function try_prepull_bloodrage(me, target)
    if not menu.use_prepull_bloodrage:get_state() or not runtime.bloodrage_id then return false end
    if me:is_in_combat() then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if utils.has_buff(me, spells.BUFF_BLOODRAGE) then return false end
    if not utils.throttle("prepull_bloodrage", 2.0) then return false end

    if utils.can_cast_self(runtime.bloodrage_id, me) and utils.cast_self_fast(runtime.bloodrage_id, me) then
        utils.log_debug(menu, "Pre-pull Bloodrage")
        note_cast()
        return true
    end

    return false
end

local function try_intimidating_shout_keybind(me, target)
    local is_pressed = menu.intimidating_shout_key:get_state()
    local was_pressed = runtime.prev_intimidating_shout_state
    runtime.prev_intimidating_shout_state = is_pressed

    if menu.intimidating_shout_key:get_key_code() == 7 then return false end
    if not is_pressed or was_pressed then return false end
    if not runtime.intimidating_shout_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if not core.spell_book.is_spell_learned(runtime.intimidating_shout_id) then return false end
    if not core.spell_book.is_usable_spell(runtime.intimidating_shout_id) then return false end

    if utils.can_cast_melee(runtime.intimidating_shout_id, me)
        and utils.cast_target(runtime.intimidating_shout_id, target)
    then
        utils.log_debug(menu, "Manual: Intimidating Shout")
        note_cast()
        return true
    end

    return false
end

local function get_reserve_rage(me, target, is_aoe, ctx)
    local reserve_rage = 0
    local execute_target = target
    local execute_target_hp_pct = target and utils.get_health_pct(target) or 1.0
    local rage_discount = get_set_rage_discount()
    local bt_cd = get_spell_cooldown_or_large(runtime.bloodthirst_id)
    local ww_cd = get_spell_cooldown_or_large(runtime.whirlwind_id)

    if runtime.bloodthirst_id then
        reserve_rage = math.max(reserve_rage, BLOODTHIRST_COST)
    end

    if runtime.whirlwind_id then
        reserve_rage = math.max(reserve_rage, WHIRLWIND_COST)
    end

    if is_aoe then
        execute_target = get_aoe_execute_target(me, target)
        execute_target_hp_pct = execute_target and utils.get_health_pct(execute_target) or 1.0
    end

    if should_cast_execute(execute_target_hp_pct, ctx) then
        reserve_rage = math.max(reserve_rage, 20)
    end

    if bt_cd <= 1.5 then
        reserve_rage = math.max(reserve_rage, math.max(15, BLOODTHIRST_COST - rage_discount) + 5)
    end

    if ww_cd <= 1.5 then
        reserve_rage = math.max(reserve_rage, math.max(20, WHIRLWIND_COST - rage_discount) + 5)
    end

    if is_aoe and menu.use_sweeping_strikes:get_state() and runtime.sweeping_strikes_id
        and not utils.has_buff(me, spells.BUFF_SWEEPING_STRIKES)
        and get_spell_cooldown_or_large(runtime.sweeping_strikes_id) <= 1.5
    then
        reserve_rage = math.max(reserve_rage, SWEEPING_STRIKES_COST)
    end

    return reserve_rage
end

local function try_piercing_howl(me, target, rage, aoe_count)
    if not menu.use_piercing_howl:get_state() or not runtime.piercing_howl_id then return false end
    if aoe_count < menu.aoe_enemy_count:get() then return false end
    if not target or not utils.is_melee_target(me, target) then return false end
    if rage < PIERCING_HOWL_COST then return false end
    if not core.spell_book.is_spell_learned(runtime.piercing_howl_id) then return false end

    local bt_cd = get_spell_cooldown_or_large(runtime.bloodthirst_id)
    local ww_cd = get_spell_cooldown_or_large(runtime.whirlwind_id)
    if bt_cd <= 1.5 or ww_cd <= 1.5 then
        return false
    end

    local nearby_targets = get_nearby_hostiles(me, AOE_RADIUS)
    for i = 1, #nearby_targets do
        if utils.has_debuff(nearby_targets[i], spells.PIERCING_HOWL) then
            return false
        end
    end

    if utils.can_cast_self(runtime.piercing_howl_id, me) and utils.cast_self(runtime.piercing_howl_id, me) then
        utils.log_debug(menu, "AoE: Piercing Howl")
        note_cast()
        return true
    end

    return false
end

local function do_queue_lane(me, target, ctx, rage, target_hp_pct, is_aoe)
    -- Avoid burning rage on queued attacks while a stance return is still pending.
    if runtime.charge_pending_return or runtime.overpower_pending_return or runtime.tc_dance_pending or runtime.tc_dance_return then
        return false
    end

    if not target or not utils.is_melee_target(me, target) then
        reset_on_next_attack_queue_state()
        return false
    end
    if utils.is_spell_already_queued(runtime.heroic_strike_id) or utils.is_spell_already_queued(runtime.cleave_id) then
        return false
    end

    if runtime.last_on_next_attack_queue_at > 0
        and (_core_time() - runtime.last_on_next_attack_queue_at) < ON_NEXT_ATTACK_QUEUE_INTERVAL
    then
        return false
    end

    if target_hp_pct <= 0.20 and not is_execute_swing_safe(me) then
        return false
    end

    if should_cast_execute(target_hp_pct, ctx) then
        return false
    end

    if runtime.queued_on_next_attack_spell_id then
        if core.spell_book.is_current_spell(runtime.queued_on_next_attack_spell_id) then
            return false
        end

        if (_core_time() - runtime.last_on_next_attack_queue_at) < ON_NEXT_ATTACK_QUEUE_INTERVAL then
            return false
        end
    end

    local next_swing_ms = utils.get_next_swing_ms(me, 2)
    if next_swing_ms <= 0 or next_swing_ms > QUEUE_SWING_WINDOW_MS then
        reset_on_next_attack_queue_state()
        return false
    end

    local reserve_rage = get_reserve_rage(me, target, is_aoe, ctx)

    if is_aoe then
        if not menu.use_cleave:get_state() or not runtime.cleave_id then return false end
        if rage < menu.cleave_rage:get() or rage <= (reserve_rage + 10) then return false end

        if utils.can_cast_melee(runtime.cleave_id, me)
            and utils.cast_target_fast(runtime.cleave_id, target)
        then
            runtime.last_on_next_attack_queue_at = _core_time()
            runtime.queued_on_next_attack_spell_id = runtime.cleave_id
            utils.log_debug(menu, "Queue: Cleave (" .. next_swing_ms .. "ms)")
            return true
        end

        return false
    end

    if not menu.use_heroic_strike:get_state() or not runtime.heroic_strike_id then return false end
    if not resource_gate.warrior.can_queue_dump(ctx, 10, 60) then return false end
    if rage < menu.heroic_strike_rage:get() or rage <= (reserve_rage + 10) then return false end

    if utils.can_cast_melee(runtime.heroic_strike_id, me)
        and utils.cast_target_fast(runtime.heroic_strike_id, target)
    then
        runtime.last_on_next_attack_queue_at = _core_time()
        runtime.queued_on_next_attack_spell_id = runtime.heroic_strike_id
        utils.log_debug(menu, "Queue: Heroic Strike (" .. next_swing_ms .. "ms)")
        invalidate_ctx()
        return true
    end

    return false
end

-- -- main update callback ----------------------------------------------------

local on_update_ctx = {
    AOE_RADIUS = AOE_RADIUS,
    MODE_DEBUG_INTERVAL_MS = MODE_DEBUG_INTERVAL_MS,
    SLAM_CANCEL_WINDOW_MS = SLAM_CANCEL_WINDOW_MS,
    _get_local_player = _get_local_player,
    close_burst_window = close_burst_window,
    consumables_manager = consumables_manager,
    control_panel_utility = control_panel_utility,
    core = core,
    defensive_manager = defensive_manager,
    do_aoe_core_lane = do_aoe_core_lane,
    do_burst_lane = do_burst_lane,
    do_consumable_lane = do_consumable_lane,
    do_queue_lane = do_queue_lane,
    do_self_only_upkeep = do_self_only_upkeep,
    do_single_target_core_lane = do_single_target_core_lane,
    do_utility_upkeep = do_utility_upkeep,
    dps_risk = dps_risk,
    dps_runtime = dps_runtime,
    eax_utils = eax_utils,
    encounter_manager = encounter_manager,
    find_nearest_attacker = find_nearest_attacker,
    get_effective_mode = get_effective_mode,
    get_home_stance = get_home_stance,
    handle_toggle = handle_toggle,
    interrupt_manager = interrupt_manager,
    is_gcd_lane_ready = is_gcd_lane_ready,
    is_valid_hostile_target = is_valid_hostile_target,
    log_resolved_spells = log_resolved_spells,
    menu = menu,
    ooc_manager = ooc_manager,
    pvp_manager = pvp_manager,
    racial_manager = racial_manager,
    refresh_mode_cache = refresh_mode_cache,
    refresh_pending_casts = refresh_pending_casts,
    reset_burst_state = reset_burst_state,
    reset_charge_stance_request = reset_charge_stance_request,
    reset_on_next_attack_queue_state = reset_on_next_attack_queue_state,
    reset_proc_tracking = reset_proc_tracking,
    resolve_spells = resolve_spells,
    sample_proc_states = sample_proc_states,
    try_battle_shout = try_battle_shout,
    try_charge_opener = try_charge_opener,
    try_health_potion = try_health_potion,
    try_healthstone = try_healthstone,
    try_intercept = try_intercept,
    try_intimidating_shout_keybind = try_intimidating_shout_keybind,
    try_piercing_howl = try_piercing_howl,
    try_pprep_bloodrage = try_prepull_bloodrage,
    try_prepull_bloodrage = try_prepull_bloodrage,
    try_pummel = try_pummel,
    try_rend_in_battle_stance = try_rend_in_battle_stance,
    try_return_after_charge = try_return_after_charge,
    try_return_to_berserker = try_return_to_berserker,
    try_tc_dance_return = try_tc_dance_return,
    try_stoneform = try_stoneform,
    try_war_stomp_interrupt = try_war_stomp_interrupt,
    try_overpower_dance = try_overpower_dance,
    ttd_tracker = ttd_tracker,
    update_notifications = update_notifications,
    update_set_bonus = update_set_bonus,
    update_stance_return_requests = update_stance_return_requests,
    utils = utils,
}

local function on_update()
    local d = on_update_ctx
    local menu = d.menu

    d.control_panel_utility:on_update(menu)
    d.handle_toggle()

    if not menu.enabled:get_state() then return end

    local me = d._get_local_player()
    if not me then return end
    if me:is_dead() then return end
    d.ooc_manager.on_update(me, menu, d.utils, { show_enchant_warning = true })

    if menu.auto_ooc_food_drink and menu.auto_ooc_food_drink:get_state() then
        d.consumables_manager.try_use_ooc_food_drink(me, menu, d.utils)
    end

    if me:is_in_combat() then
        if menu.auto_combat_potions and menu.auto_combat_potions:get_state() then
            d.consumables_manager.try_use_combat_consumable(me, menu, d.utils)
        end
        if menu.auto_flask and menu.auto_flask:get_state() then
            d.consumables_manager.try_maintain_flask(me, menu, d.utils)
        end
    end

    if d.eax_utils.is_eating_or_drinking(me) then return end
    if me:is_mounted() then return end

    d.refresh_mode_cache()

    if d.utils.throttle("update_set_bonus", 5.0) then
        d.update_set_bonus(me)
    end

    if menu.debug:get_state() then
        local now_ms = d.core.game_time()
        if now_ms - runtime.last_mode_debug_at >= d.MODE_DEBUG_INTERVAL_MS then
            runtime.last_mode_debug_at = now_ms
            local eff = d.get_effective_mode()
            local sham = runtime.cached_has_shaman and "yes" or "no"
            d.core.log("[Eax Fury] Mode: " .. eff .. " (auto=" .. runtime.cached_mode .. ") | Shaman: " .. sham)
        end
    end

    if not runtime.bloodthirst_id or not runtime.whirlwind_id then
        local previous_bt = runtime.bloodthirst_id
        local previous_ww = runtime.whirlwind_id
        d.resolve_spells()
        if runtime.bloodthirst_id ~= previous_bt or runtime.whirlwind_id ~= previous_ww then
            d.log_resolved_spells()
        end
    end

    if me:is_casting_spell() and me:get_active_spell_id() == runtime.slam_id then
        if d.utils.get_next_swing_ms(me, 2) < d.SLAM_CANCEL_WINDOW_MS then
            d.core.input.cancel_spells()
        end
        return
    end

    if d.utils.is_casting_or_channeling(me) then return end

    local rage = d.utils.get_rage(me)
    local target = d.utils.find_best_target(me)
    -- PvP: prioritize enemy players in arena/BG/world PvP
    local pvp_instance = d.pvp_manager.is_in_pvp_instance()
    if pvp_instance or d.pvp_manager.is_world_pvp(me) then
        local enemy_players = d.pvp_manager.find_enemy_players(me, 40)
        if #enemy_players > 0 then
            -- Arena: focus fire lowest HP target
            if pvp_instance == "arena" then
                local focus = d.pvp_manager.get_arena_focus_target(me, enemy_players)
                if focus then target = focus end
            -- BG: prioritize flag carriers
            elseif pvp_instance == "battleground" then
                local fc = d.pvp_manager.get_flag_carrier_target(me, enemy_players)
                if fc then target = fc end
            else
                local priority = d.pvp_manager.priority_target(me, enemy_players)
                if priority then target = priority end
            end
        end
    end

    local battlefield_snapshot = get_battlefield_snapshot(me)

    enc = d.encounter_manager.get_policy(me)

    if target and target:is_valid() and me:can_attack(target) and d.interrupt_manager.should_interrupt(target) then
        if d.interrupt_manager.try_interrupt(me, target, "warrior", d.utils) then
            return
        end
    end

    local hold_offense = d.dps_risk.should_hold_offense(d.dps_runtime.build_snapshot(me, target, d.encounter_manager, d.ttd_tracker))
    if not hold_offense and d.racial_manager.try_offensive(me) then return end
    if d.racial_manager.try_utility(me, target) then return end
    if d.racial_manager.try_defensive(me) then return end

    if d.defensive_manager.try_defensive(me, "warrior", d.utils) then
        return
    end

    -- PvP cooldowns: trinket, berserker rage, shield wall, last stand
    if pvp_instance or d.pvp_manager.is_world_pvp(me) then
        if d.pvp_manager.should_use_pvp_trinket(me) then
            local trinket_ids = { 40426, 40427, 40428, 40429, 40430, 40431 }
            for _, tid in ipairs(trinket_ids) do
                if core.inventory and core.inventory.get_item_count and core.inventory.get_item_count(tid) > 0 then
                    core.input.use_item(tid)
                    break
                end
            end
        end
        if d.pvp_manager.try_warrior_pvp_cooldowns(me, target) then return end
    end

    d.ttd_tracker.update(target)

    local focus_target = d.eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        target = focus_target
    end

    local self_threshold = d.eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold and d.try_battle_shout and d.try_battle_shout(me) then
        return
    end

    if me:is_in_combat() and not d.is_valid_hostile_target(me, target) then
        local attacker = battlefield_snapshot.nearest_attacker or d.find_nearest_attacker(me)
        if attacker then
            target = attacker
        end
    end

    if not me:is_in_combat() then
        if runtime.burst_window_active or next(runtime.burst_attempted) ~= nil then
            d.reset_burst_state()
        end
        d.reset_on_next_attack_queue_state()
        d.reset_proc_tracking()

        if runtime.charge_pending_return and d.utils.get_current_stance(me) == d.get_home_stance() then
            runtime.charge_pending_return = false
        end
    end

    local target_valid = d.is_valid_hostile_target(me, target)
    d.refresh_pending_casts()
    d.update_stance_return_requests(me, target_valid and target or nil)

    d.update_notifications(me, target)
    d.sample_proc_states(me)

    if d.try_healthstone(me) then return end
    if d.try_health_potion(me) then return end
    if d.try_stoneform(me) then return end
    if d.try_intimidating_shout_keybind(me, target) then return end

    local gcd_lane_ready = d.is_gcd_lane_ready()
    local deps = { now_s = _core_time, get_gcd = _get_gcd }
    local ctx = rotation_context.get(ctx_cache, me, target, deps)

    if not target_valid then
        if runtime.burst_window_active then
            d.close_burst_window("target invalid", false)
        end
        runtime.charge_queue_requested_at = 0
        runtime.overpower_queue_requested_at = 0
        d.reset_charge_stance_request()
        d.reset_on_next_attack_queue_state()

        if gcd_lane_ready then
            if d.try_return_after_charge(me) then return end
            if d.try_return_to_berserker(me) then return end
            if d.do_self_only_upkeep(me) then return end
        end
        return
    end

    if not me:is_in_combat() then
        if gcd_lane_ready and runtime.charge_pending_return and d.try_return_after_charge(me) then
            return
        end
        if gcd_lane_ready and d.try_charge_opener(me, target) then
            return
        end
        if d.try_prepull_bloodrage(me, target) then
            return
        end
    end

    if runtime.charge_queue_requested_at > 0 then
        return
    end

    d.utils.ensure_melee_auto_attack(me, target)

    if d.try_intercept(me, target) then return end
    if d.try_pummel(me, target) then return end
    if d.try_war_stomp_interrupt(me, target) then return end

    local aoe_count = d.utils.enemy_count_in_radius(me, d.AOE_RADIUS)
    local is_aoe = aoe_count >= menu.aoe_enemy_count:get()
    local target_hp_pct = d.utils.get_health_pct(target)

    if runtime.overpower_queue_requested_at > 0 then
        return
    end

    if gcd_lane_ready then
        if d.try_return_after_charge(me) then return end
        if d.try_return_to_berserker(me) then return end
        if d.try_tc_dance_return(me) then return end

        rage = d.utils.get_rage(me)

        if d.try_overpower_dance(me, target, rage) then return end

        if d.do_utility_upkeep(me, target, rage, target_hp_pct) then return end
        if d.do_burst_lane(me, target) then return end
        if not runtime.burst_window_active and d.do_consumable_lane(me) then return end

        if is_aoe then
            if d.do_aoe_core_lane(me, target, ctx, rage) then return end
        else
            if d.do_single_target_core_lane(me, target, ctx, rage, target_hp_pct) then return end
        end

        if d.try_rend_in_battle_stance(me, target, rage) then return end
        if d.try_piercing_howl(me, target, rage, aoe_count) then return end
    end

    d.do_queue_lane(me, target, ctx, rage, target_hp_pct, is_aoe)
end

local function draw_proc_status_line(y_offset, label, is_active, active_color)
    local dot_color = is_active and active_color or color.gray(170)
    local text_color = is_active and color.white(230) or color.red_pale(210)
    local status_text = is_active and "UP" or "DOWN"

    core.graphics.circle_2d_filled(vec2.new(PROC_HUD_X + 12, y_offset + 7), 5, dot_color)
    core.graphics.text_2d(label .. ": " .. status_text, vec2.new(PROC_HUD_X + 24, y_offset), 13, text_color, false)
end

local function on_render()
    return
end

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

    local toggle_key_code = menu.toggle_key:get_key_code()
    local display_name = "[Eax Warrior Fury] Enabled"
    if toggle_key_code ~= 7 then
        display_name = "[Eax Warrior Fury] Enabled (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end

    add_toggle(display_name, menu.enabled, "simplefury_enabled_control_panel")

    if menu.enabled:get_state() then
        add_toggle("[Eax WFu] Cooldowns", menu.use_cooldowns, "eax_wfu_cds_cp")
        add_toggle("[Eax WFu] Focus Priority", menu.focus_priority, "eax_wfu_focus_cp")
        add_toggle("[Eax WFu] Use Racial", menu.use_racial, "eax_wfu_racial_cp")
    end

    return elements
end

local function on_spell_cast(data)
    if not data or not data.spell_id then
        return
    end
    smart_cast_manager.on_cast_success(data.spell_id)
    clear_pending_cast(data.spell_id)
end

-- -- register callbacks ------------------------------------------------------

-- -- Eax Conflict Detection (runs once at load) ------------------------------
-- Registers this spec; warns at render time only if 2+ specs of same class enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Warrior"
    local _eax_spec  = "Fury"
    if not _G.__EAX_LOADED[_eax_class] then
        _G.__EAX_LOADED[_eax_class] = {}
    end
    _G.__EAX_LOADED[_eax_class][_eax_spec] = function()
        return menu and menu.enabled and menu.enabled:get_state()
    end
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

core.register_on_update_callback(on_update)
core.register_on_spell_cast_callback(on_spell_cast)
-- ESP only renders when this spec is enabled
core.register_on_render_callback(function()
    if not menu or not menu.enabled or not menu.enabled:get_state() then return end
    on_render()
end)
-- __EAX_ESP_GUARD

-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxwarriorfury_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)

-- -- public interface --------------------------------------------------------
local function cleanup()
end

return { cleanup = cleanup, state = runtime }
