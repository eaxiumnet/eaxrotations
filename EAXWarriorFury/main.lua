-- EAX Warrior Fury | main.lua
-- Callback registration, control-panel wiring, and documented EAX Warrior Fury logic.
-- APIs validated against .api/core.lua, .api/game_object.lua,
-- sylvanas-dev-docs-llm/pages/dev/api/auto-attack-helper.md,
-- sylvanas-dev-docs-llm/pages/dev/api/game-object.md,
-- sylvanas-dev-docs-llm/pages/dev/api/object-manager.md,
-- and sylvanas-dev-docs-llm/pages/dev/api/spellbook.md.

local menu = require("menu")
local spells = require("spells")
local utils = require("utils")
local eax_utils = require("eax_utils")

---@type interrupt_manager
local interrupt_manager = require("common/eax_shared/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("common/eax_shared/ooc_manager")
---@type vendor_automation
local vendor_automation = require("common/eax_shared/vendor_automation")
---@type consumables_manager
local consumables_manager = require("common/eax_shared/consumables_manager")
---@type mount_manager
local mount_manager = require("common/eax_shared/mount_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type encounter_manager
local encounter_manager = require("common/eax_shared/encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("fury", "Warrior Fury")


-- Phase 04 visual telemetry wiring
local dps_meter = require("common/eax_shared/dps_meter")
local cooldown_tracker = require("common/eax_shared/cooldown_tracker")
local visual_state = require("common/eax_shared/visual_state")
local reactive_runtime = require("eax_shared/reactive_runtime")

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
        local now_s = core.time()
        local cd_s = tonumber(core.spell_book.get_spell_cooldown(spell_id)) or 0
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

local function visual_build_tracked_auras(me, target)
    local tracked_auras = {}
    if me and me:is_in_combat() then
        tracked_auras[#tracked_auras + 1] = { label = "Combat", active = true }
    end
    if target and target:is_valid() and not target:is_dead() then
        if target:is_casting_spell() then
            tracked_auras[#tracked_auras + 1] = { label = "Cast", active = true }
        end
        if target:is_channelling_spell() then
            tracked_auras[#tracked_auras + 1] = { label = "Channel", active = true }
        end
    end
    return tracked_auras
end

local function visual_update_snapshot(me, target)
    if not me then return end
    local in_combat = me:is_in_combat()
    if in_combat and not _visual_runtime.in_combat then
        dps_meter.on_combat_start()
        _visual_runtime.in_combat = true
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
    elseif (not in_combat) and _visual_runtime.in_combat then
        dps_meter.on_combat_end()
        _visual_runtime.in_combat = false
        _visual_runtime.last_me_hp_pct = nil
        _visual_runtime.last_target_hp_pct = nil
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
        now_s = core.time(),
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
    local me = core.object_manager.get_local_player()
    if not me or me:is_dead() then return end
    local target = me:get_target()
    visual_update_snapshot(me, target)
end)
---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")
---@type racial_manager
local racial_manager = require("common/eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("common/eax_shared/defensive_manager")

---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")
---@type color
local color = require("color")
---@type vec2
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type swing_timer
local swing_timer = require("common/eax_shared/swing_timer")

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

local BATTLE_SHOUT_REFRESH_MS = 5000
local DEMO_SHOUT_REFRESH_MS = 5000
local RAMPAGE_REFRESH_MS = 1500
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
local HAMSTRING_MIN_RAGE = 15
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
    core.log("[EAX Warrior Fury] Resolved: BT=" .. tostring(runtime.bloodthirst_id)
        .. " WW=" .. tostring(runtime.whirlwind_id)
        .. " EX=" .. tostring(runtime.execute_id)
        .. " HS=" .. tostring(runtime.heroic_strike_id)
        .. " stance_ret=" .. tostring(runtime.stance_swap_retention))
end

resolve_spells()
log_resolved_spells()

-- -- mode detection ----------------------------------------------------------

local function detect_mode()
    local objects = core.object_manager.get_visible_objects()
    local party_count = 0
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() 
           and obj:is_party_member() then
            party_count = party_count + 1
        end
    end

    if party_count == 0 then
        return "solo"
    elseif party_count <= 4 then
        return "dungeon"
    else
        return "raid"
    end
end

local function has_shaman_in_party()
    local objects = core.object_manager.get_visible_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead()
            and obj:is_party_member()
            and obj:get_class() == SHAMAN_CLASS_ID
        then
            return true
        end
    end
    return false
end

local function refresh_mode_cache()
    runtime.cached_mode = detect_mode()
    runtime.cached_has_shaman = has_shaman_in_party()
end

local function update_set_bonus(me)
    if not me then return end
    local best_multiplier = 1.0
    local set_names = { "Warbringer", "WarbringerBattlegear", "Ymirjar" }
    for _, set_name in ipairs(set_names) do
        local multiplier = utils.get_set_multiplier(me, set_name)
        if multiplier > best_multiplier then
            best_multiplier = multiplier
        end
    end
    runtime.set_multiplier = best_multiplier
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

--- Find the closest hostile unit that is targeting (attacking) us.
---@param me game_object
---@return game_object|nil
local function find_nearest_attacker(me)
    local my_pos = me:get_position()
    local best = nil
    local best_dist = math.huge
    local objects = core.object_manager.get_visible_objects()

    for i = 1, #objects do
        local obj = objects[i]
        if obj
            and obj:is_valid()
            and obj:is_unit()
            and not obj:is_dead()
            and me:can_attack(obj)
            and obj:is_in_combat()
        then
            local obj_target = obj:get_target()
            if obj_target and obj_target:is_valid() and obj_target == me then
                local obj_pos = obj:get_position()
                local sq_dist = my_pos:squared_dist_to_ignore_z(obj_pos)
                if sq_dist < best_dist then
                    best = obj
                    best_dist = sq_dist
                end
            end
        end
    end

    return best
end

local function note_cast()
    runtime.last_cast_time = core.time()
end

local function is_gcd_lane_ready()
    if (core.time() - runtime.last_cast_time) < GCD_CAST_INTERVAL then
        return false
    end

    return core.spell_book.get_global_cooldown() <= 0
end

local function reset_burst_state()
    runtime.burst_window_active = false
    runtime.burst_window_started_at = 0
    runtime.burst_attempted = {}
end

local function reset_charge_stance_request()
    runtime.charge_stance_swap_pending = false
    runtime.charge_stance_swap_requested_at = 0
end

local function reset_on_next_attack_queue_state()
    runtime.last_on_next_attack_queue_at = 0
    runtime.queued_on_next_attack_spell_id = nil
end

local function reset_proc_tracking()
    runtime.proc_debug_next_log_at = 0
    runtime.flurry_uptime_start = 0
    runtime.enrage_uptime_start = 0
    runtime.flurry_accumulated_ms = 0
    runtime.enrage_accumulated_ms = 0
    runtime.last_proc_sample_game_time = 0
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end
    local pending = runtime.pending_casts[spell_id]
    if not pending then return false end

    if (core.time() - pending.requested_at) >= pending.timeout_s then
        runtime.pending_casts[spell_id] = nil
        return false
    end

    return true
end

local function mark_pending_cast(spell_id, timeout_s, on_confirm)
    if not spell_id then return end
    runtime.pending_casts[spell_id] = {
        requested_at = core.time(),
        timeout_s = timeout_s or PENDING_CAST_TIMEOUT_S,
        on_confirm = on_confirm,
    }
end

local function clear_pending_cast(spell_id)
    if not spell_id then return end
    runtime.pending_casts[spell_id] = nil
end

local function refresh_pending_casts()
    local now = core.time()

    for spell_id, pending in pairs(runtime.pending_casts) do
        if core.spell_book.get_spell_cooldown(spell_id) > 0 then
            runtime.pending_casts[spell_id] = nil
        elseif (now - pending.requested_at) >= pending.timeout_s then
            runtime.pending_casts[spell_id] = nil
            utils.log_debug(menu, "Pending cast expired: " .. tostring(spell_id))
        end
    end
end

local function is_pending_or_current(spell_id)
    return is_pending_cast(spell_id) or utils.is_spell_already_queued(spell_id)
end

--- Return the best "home" stance based on what the character has learned.
--- At 30+ with Berserker Stance this returns "berserker"; below 30 it returns "battle".
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

local function update_stance_return_requests(me, target)
    if runtime.charge_queue_requested_at > 0 then
        local charge_confirmed = me:is_in_combat()
            or (runtime.charge_id and core.spell_book.get_spell_cooldown(runtime.charge_id) > 0)
            or (target and utils.is_melee_target(me, target))

        if charge_confirmed then
            runtime.charge_queue_requested_at = 0
            runtime.charge_pending_return = true
        elseif (core.time() - runtime.charge_queue_requested_at) > 1.25 then
            runtime.charge_queue_requested_at = 0
        end
    end

    if runtime.overpower_queue_requested_at > 0 then
        local overpower_confirmed = runtime.overpower_id
            and core.spell_book.get_spell_cooldown(runtime.overpower_id) > 0

        if overpower_confirmed then
            runtime.overpower_queue_requested_at = 0
            runtime.overpower_pending_return = true
        elseif (core.time() - runtime.overpower_queue_requested_at) > 0.75 then
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

    return core.spell_book.get_spell_cooldown(spell_id)
end

local function get_nearby_hostiles(me, radius)
    local targets = {}
    local my_pos = me:get_position()
    local objects = core.object_manager.get_visible_objects()

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
            "[EAX Fury] Proc uptime %.0fs: Flurry %.1f%% | Enrage %.1f%%",
            divisor / 1000,
            flurry_pct,
            enrage_pct
        ))
        runtime.proc_debug_next_log_at = runtime.proc_debug_next_log_at + PROC_DEBUG_INTERVAL_MS
    end
end

local function should_cast_execute(target_hp_pct, rage)
    if not menu.use_execute:get_state() then return false end
    if not runtime.execute_id then return false end
    if target_hp_pct >= EXECUTE_HP_THRESHOLD then return false end
    if rage < EXECUTE_MIN_RAGE then return false end

    local bt_cd = get_spell_cooldown_or_large(runtime.bloodthirst_id)
    return bt_cd > 1.5
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
    if remaining >= RAMPAGE_REFRESH_MS then
        return false
    end

    if is_pending_or_current(runtime.rampage_id) then
        return false
    end

    if utils.can_cast_self(runtime.rampage_id, me) and utils.cast_self(runtime.rampage_id, me) then
        mark_pending_cast(runtime.rampage_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Rampage refresh (" .. remaining .. "ms)")
        note_cast()
        return true
    end

    return false
end

local function do_self_only_upkeep(me)
    if try_shout(me) then return true end
    if try_rampage(me) then return true end
    return false
end

local function try_sunder_armor(me, target, target_hp_pct)
    if not menu.use_sunder_armor:get_state() or not runtime.sunder_armor_id then return false end
    if target_hp_pct < EXECUTE_HP_THRESHOLD then return false end
    if not utils.is_melee_target(me, target) then return false end

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
    if try_shout(me) then return true end
    if try_demo_shout(me, target) then return true end
    if try_sunder_armor(me, target, target_hp_pct) then return true end
    if try_bloodrage(me, rage) then return true end
    if try_berserker_rage(me) then return true end
    if try_rampage(me) then return true end
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

local function try_heroic_strike(me, target, rage, target_hp_pct, is_aoe)
    -- Only consider heroic strike in execute phase (below 20% HP)
    if target_hp_pct >= EXECUTE_HP_THRESHOLD then
        return false
    end
    if not menu.use_heroic_strike:get_state() or not runtime.heroic_strike_id then
        return false
    end
    if rage < menu.heroic_strike_rage:get() then
        return false
    end
    if not utils.can_cast_melee(runtime.heroic_strike_id, me) then
        return false
    end
    if utils.is_spell_already_queued(runtime.heroic_strike_id) then
        return false
    end
    if utils.cast_target(runtime.heroic_strike_id, target) then
        runtime.last_on_next_attack_queue_at = core.time()
        runtime.queued_on_next_attack_spell_id = runtime.heroic_strike_id
        utils.log_debug(menu, "Queue: Heroic Strike")
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

local function on_render()
    esp_renderer.on_render(menu)
    if not menu.show_notifications:get_state() or not menu.track_procs:get_state() then
        return
    end

    local me = core.object_manager.get_local_player()
    if not me then return end

    local flurry_data = buff_manager:get_buff_data(me, spells.BUFF_FLURRY)
    local enrage_data = buff_manager:get_buff_data(me, spells.BUFF_ENRAGE)
    local flurry_active = flurry_data and flurry_data.is_active or false
    local enrage_active = enrage_data and enrage_data.is_active or false

    core.graphics.rect_2d_filled(
        vec2.new(PROC_HUD_X, PROC_HUD_Y),
        PROC_HUD_WIDTH,
        PROC_HUD_HEIGHT,
        color.new(12, 14, 18, 145),
        6
    )
    core.graphics.rect_2d(
        vec2.new(PROC_HUD_X, PROC_HUD_Y),
        PROC_HUD_WIDTH,
        PROC_HUD_HEIGHT,
        color.new(70, 78, 88, 180),
        1,
        6
    )

    draw_proc_status_line(PROC_HUD_Y + 10, "Flurry", flurry_active, color.green(220))
    draw_proc_status_line(PROC_HUD_Y + 10 + PROC_HUD_LINE_HEIGHT, "Enrage", enrage_active, color.cyan(220))
end

-- -- control panel callback --------------------------------------------------

local function on_control_panel()
    local elements = {}
    local toggle_key_code = menu.toggle_key:get_key_code()
    local display_name = "[EAX Fury] Enabled"
    if toggle_key_code ~= 7 then
        display_name = "[EAX Fury] Enabled (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end

    local current_state = menu.enabled:get_state()
    local new_state = control_panel_utility:insert_key_checkbox_(
        elements,
        display_name,
        current_state,
        0,
        false,
        "simplefury_enabled_control_panel"
    )

    if new_state ~= current_state then
        menu.enabled:set(new_state)
    end

    return elements
end

local function on_spell_cast(data)
    if not data or not data.spell_id then
        return
    end

    -- pending_casts only contains spell IDs we queued ourselves, so the table
    -- lookup acts as a natural filter.  Cooldown/timeout polling in
    -- refresh_pending_casts() remains as fallback.
    local pending = runtime.pending_casts[data.spell_id]
    if not pending then
        return
    end

    if pending.on_confirm then
        pending.on_confirm()
    end
    clear_pending_cast(data.spell_id)
end

-- -- register callbacks ------------------------------------------------------
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
