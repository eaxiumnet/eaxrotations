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
local interrupt_manager = require("eax_shared/interrupt_manager")
---@type ooc_manager
local ooc_manager = require("eax_shared/ooc_manager")
---@type vendor_automation
local vendor_automation = require("eax_shared/vendor_automation")
---@type consumables_manager
local consumables_manager = require("eax_shared/consumables_manager")
---@type mount_manager
local mount_manager = require("eax_shared/mount_manager")
---@type leveling_manager
local leveling_manager = require("leveling_manager")
---@type encounter_manager
local encounter_manager = require("eax_shared/encounter_manager")
-- Module-level encounter policy cache (updated each tick)
local enc = nil


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("fury", "Warrior Fury")


-- Phase 04 visual telemetry wiring
local dps_meter = require("eax_shared/dps_meter")
local cooldown_tracker = require("eax_shared/cooldown_tracker")
local visual_state = require("eax_shared/visual_state")
local reactive_runtime = require("eax_shared/reactive_runtime")
local dps_risk = require("eax_shared/dps_risk")
local dps_runtime = require("eax_shared/dps_runtime")

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
local racial_manager = require("eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("eax_shared/defensive_manager")

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
local swing_timer = require("eax_shared/swing_timer")

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

local function try_overpower_dance(me, target, rage)
    if not menu.use_overpower:get_state() or not runtime.overpower_id then return false end
    if not target or not utils.is_melee_target(me, target) then return false end
    if not utils.can_stance_dance_for_cost(rage, OVERPOWER_COST, 0, runtime.stance_swap_retention) then return false end
    if not core.spell_book.is_spell_learned(runtime.overpower_id) then return false end
    if not core.spell_book.is_usable_spell(runtime.overpower_id) then return false end

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
        runtime.overpower_queue_requested_at = core.time()
        mark_pending_cast(runtime.overpower_id, PENDING_CAST_TIMEOUT_S, function()
            runtime.overpower_queue_requested_at = 0
            runtime.overpower_pending_return = true
        end)
        utils.log_debug(menu, "Overpower")
        note_cast()
        return true
    end

    return false
end

local function try_rend_in_battle_stance(me, target, rage)
    if not menu.use_rend:get_state() or not runtime.rend_id then return false end
    if not target or not utils.is_melee_target(me, target) then return false end
    if utils.get_current_stance(me) ~= "battle" then return false end
    if rage < REND_COST then return false end
    if utils.has_debuff(target, spells.DEBUFF_REND) then return false end

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
    local item_id = utils.get_equipped_item_id_in_slot(core.object_manager.get_local_player(), slot_id)
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

local function try_slam_or_hamstring_filler(me, target, rage, target_hp_pct, label, is_aoe)
    -- If we are in execute phase, try to queue Heroic Strike (single target) or Cleave (AoE)
    if target_hp_pct < EXECUTE_HP_THRESHOLD then
        if try_heroic_strike(me, target, rage, target_hp_pct, is_aoe) then
            return true
        end
    end

    if not target or not utils.is_melee_target(me, target) then return false end

    local bt_cd = get_spell_cooldown_or_large(runtime.bloodthirst_id)
    local ww_cd = get_spell_cooldown_or_large(runtime.whirlwind_id)
    if bt_cd <= 1.5 or ww_cd <= 1.5 then
        return false
    end

    if menu.use_slam_weave:get_state()
        and runtime.slam_id
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
        and rage >= HAMSTRING_MIN_RAGE
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
        add_notification_once(NOTIFICATION_BURST_ID, "EAX Fury", "Burst window active", 1.5, color.gold(220))
    end

    if overpower_usable and not runtime.last_overpower_usable and is_valid_hostile_target(me, target) then
        add_notification_once(NOTIFICATION_OVERPOWER_ID, "EAX Fury", "Overpower available", 1.5, color.orange(220))
    end

    if runtime.last_slam_cast_game_time > 0 and (now_ms - runtime.last_slam_cast_game_time) <= 1000 then
        add_notification_once(NOTIFICATION_SLAM_ID, "EAX Fury", "Slam weave", 1.0, color.cyan(220))
    end

    if runtime.last_return_to_berserker_at > 0 and (now_ms - runtime.last_return_to_berserker_at) <= 1000 then
        add_notification_once(NOTIFICATION_RETURN_ID, "EAX Fury", "Returned to Berserker", 1.0, color.blue(220))
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

local function do_single_target_core_lane(me, target, rage, target_hp_pct)
    if try_tc_dance_return(me) then return true end
    local execute_phase_active = target_hp_pct <= 0.20
    local fast_one_hand_execute = execute_phase_active and is_fast_one_hand_execute_setup(me)
    local execute_swing_safe = (not execute_phase_active) or is_execute_swing_safe(me)
    local bt_can_cast = runtime.bloodthirst_id
        and rage >= BLOODTHIRST_COST
        and utils.can_cast_hostile_no_usable(runtime.bloodthirst_id, me, target)
        or false
    local ww_can_cast = runtime.whirlwind_id
        and utils.is_melee_target(me, target)
        and rage >= WHIRLWIND_COST
        and core.spell_book.get_spell_cooldown(runtime.whirlwind_id) <= 0
        or false
    local ex_can_cast = should_cast_execute(target_hp_pct, rage)
        and utils.can_cast_hostile_no_usable(runtime.execute_id, me, target)
        or false

    if execute_phase_active and fast_one_hand_execute then
        -- Fast-1H execute lane: explicit execute-first behavior with queue support.
        if execute_swing_safe and ex_can_cast and not is_pending_or_current(runtime.execute_id) then
            if utils.cast_target(runtime.execute_id, target) then
                mark_pending_cast(runtime.execute_id, PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "ST Execute (fast-1H): Execute")
                note_cast()
                return true
            end
        end

        if try_heroic_strike(me, target, rage, target_hp_pct, false) then
            return true
        end
    end

    if bt_can_cast and not is_pending_or_current(runtime.bloodthirst_id) then
        if utils.cast_target(runtime.bloodthirst_id, target) then
            mark_pending_cast(runtime.bloodthirst_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "ST: Bloodthirst")
            note_cast()
            return true
        end
    end

    if ww_can_cast and not is_pending_or_current(runtime.whirlwind_id) then
        if utils.cast_target(runtime.whirlwind_id, target) then
            mark_pending_cast(runtime.whirlwind_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "ST: Whirlwind")
            note_cast()
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
            return true
        end
    end

    if try_slam_or_hamstring_filler(me, target, rage, target_hp_pct, "ST") then
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



local function do_aoe_core_lane(me, target, rage)
    if enc and not enc.aoe_safe then return false end
    local primary_target = utils.find_best_aoe_target(me, target, AOE_RADIUS) or target
    local execute_target = get_aoe_execute_target(me, primary_target)

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
            and rage >= WHIRLWIND_COST
            and core.spell_book.get_spell_cooldown(runtime.whirlwind_id) <= 0
        then
            if not is_pending_or_current(runtime.whirlwind_id)
                and utils.cast_target(runtime.whirlwind_id, primary_target)
            then
                mark_pending_cast(runtime.whirlwind_id, PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "AoE: Whirlwind")
                note_cast()
                return true
            end
        end
    end

    if primary_target and runtime.bloodthirst_id
        and utils.can_cast_hostile(runtime.bloodthirst_id, me, primary_target)
    then
        if not is_pending_or_current(runtime.bloodthirst_id)
            and utils.cast_target(runtime.bloodthirst_id, primary_target)
        then
            mark_pending_cast(runtime.bloodthirst_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "AoE: Bloodthirst")
            note_cast()
            return true
        end
    end

    if execute_target and should_cast_execute(utils.get_health_pct(execute_target), rage)
        and utils.can_cast_hostile_no_usable(runtime.execute_id, me, execute_target)
    then
        if not is_pending_or_current(runtime.execute_id)
            and utils.cast_target(runtime.execute_id, execute_target)
        then
            mark_pending_cast(runtime.execute_id, PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "AoE: Execute")
            note_cast()
            return true
        end
    end

    if primary_target and try_slam_or_hamstring_filler(
            me,
            primary_target,
            rage,
            utils.get_health_pct(primary_target),
            "AoE"
        ) then
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
    if core.spell_book.get_spell_cooldown(runtime.charge_id) > 0 then
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
            and (core.time() - runtime.charge_stance_swap_requested_at) < CHARGE_STANCE_RETRY_DELAY
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
            runtime.charge_stance_swap_requested_at = core.time()
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
        runtime.charge_queue_requested_at = core.time()
        mark_pending_cast(runtime.charge_id, PENDING_CAST_TIMEOUT_S, function()
            runtime.charge_queue_requested_at = 0
            runtime.charge_pending_return = true
            reset_charge_stance_request()
        end)
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

local function get_reserve_rage(me, target, is_aoe)
    local reserve_rage = 0
    local execute_target = target
    local execute_target_hp_pct = target and utils.get_health_pct(target) or 1.0

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

    if should_cast_execute(execute_target_hp_pct, EXECUTE_MIN_RAGE) then
        reserve_rage = math.max(reserve_rage, EXECUTE_MIN_RAGE)
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

local function do_queue_lane(me, target, rage, target_hp_pct, is_aoe)
    -- Avoid burning rage on queued attacks while a stance return is still pending.
    if runtime.charge_pending_return or runtime.overpower_pending_return then
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
        and (core.time() - runtime.last_on_next_attack_queue_at) < ON_NEXT_ATTACK_QUEUE_INTERVAL
    then
        return false
    end

    if target_hp_pct <= 0.20 and not is_execute_swing_safe(me) then
        return false
    end

    if runtime.queued_on_next_attack_spell_id then
        if core.spell_book.is_current_spell(runtime.queued_on_next_attack_spell_id) then
            return false
        end

        if (core.time() - runtime.last_on_next_attack_queue_at) < ON_NEXT_ATTACK_QUEUE_INTERVAL then
            return false
        end
    end

    local next_swing_ms = utils.get_next_swing_ms(me, 2)
    if next_swing_ms <= 0 or next_swing_ms > QUEUE_SWING_WINDOW_MS then
        reset_on_next_attack_queue_state()
        return false
    end

    local reserve_rage = get_reserve_rage(me, target, is_aoe)

    if is_aoe then
        if not menu.use_cleave:get_state() or not runtime.cleave_id then return false end
        if rage < menu.cleave_rage:get() or rage <= (reserve_rage + 5) then return false end

        if utils.can_cast_melee(runtime.cleave_id, me)
            and utils.cast_target_fast(runtime.cleave_id, target)
        then
            runtime.last_on_next_attack_queue_at = core.time()
            runtime.queued_on_next_attack_spell_id = runtime.cleave_id
            utils.log_debug(menu, "Queue: Cleave (" .. next_swing_ms .. "ms)")
            return true
        end

        return false
    end

    if not menu.use_heroic_strike:get_state() or not runtime.heroic_strike_id then return false end
    if rage < menu.heroic_strike_rage:get() or rage <= (reserve_rage + 5) then return false end

    if utils.can_cast_melee(runtime.heroic_strike_id, me)
        and utils.cast_target_fast(runtime.heroic_strike_id, target)
    then
        runtime.last_on_next_attack_queue_at = core.time()
        runtime.queued_on_next_attack_spell_id = runtime.heroic_strike_id
        utils.log_debug(menu, "Queue: Heroic Strike (" .. next_swing_ms .. "ms)")
        return true
    end

    return false
end

-- -- main update callback ----------------------------------------------------

local function on_update()
    control_panel_utility:on_update(menu)
    handle_toggle()

    if not menu.enabled:get_state() then return end

    -- OOC management (drink/eat/rez/group buffs)
    ooc_manager.on_update(me, menu, utils)
    local me = core.object_manager.get_local_player()
    if not me then return end

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
    if me:is_mounted() then return end

    refresh_mode_cache()

    if utils.throttle("update_set_bonus", 5.0) then
        update_set_bonus(me)
    end

    if menu.debug:get_state() then
        local now_ms = core.game_time()
        if now_ms - runtime.last_mode_debug_at >= MODE_DEBUG_INTERVAL_MS then
            runtime.last_mode_debug_at = now_ms
            local eff = get_effective_mode()
            local sham = runtime.cached_has_shaman and "yes" or "no"
            

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
        local label = "EAX Warrior Fury] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxwarriorfury_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_wfu_cds = menu.use_cooldowns:get_state()
            local nxt_wfu_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX WFu] Cooldowns", cur_wfu_cds, 0, false, "eax_wfu_cds_cp")
            if nxt_wfu_cds ~= cur_wfu_cds then menu.use_cooldowns:set(nxt_wfu_cds) end
        end
        if menu.focus_priority then
            local cur_wfu_focus = menu.focus_priority:get_state()
            local nxt_wfu_focus = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX WFu] Focus Priority", cur_wfu_focus, 0, false, "eax_wfu_focus_cp")
            if nxt_wfu_focus ~= cur_wfu_focus then menu.focus_priority:set(nxt_wfu_focus) end
        end
        if menu.use_racial then
            local cur_wfu_racial = menu.use_racial:get_state()
            local nxt_wfu_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX WFu] Use Racial", cur_wfu_racial, 0, false, "eax_wfu_racial_cp")
            if nxt_wfu_racial ~= cur_wfu_racial then menu.use_racial:set(nxt_wfu_racial) end
        end
        end
        return elements
    end)
end

-- -- EAX Conflict Detection -------------------------------------------------
-- Registers this spec at load time; warns at runtime only if both are enabled.
do
    if not _G.__EAX_LOADED then _G.__EAX_LOADED = {} end
    local _eax_class = "Warrior"
    local _eax_spec  = "Fury"
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
        local now = core.time()
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

core.log("[EAX Fury] Mode: " .. eff .. " (auto=" .. runtime.cached_mode .. ") | Shaman: " .. sham)
        end
    end

    if not runtime.bloodthirst_id or not runtime.whirlwind_id then
        local previous_bt = runtime.bloodthirst_id
        local previous_ww = runtime.whirlwind_id
        resolve_spells()
        if runtime.bloodthirst_id ~= previous_bt or runtime.whirlwind_id ~= previous_ww then
            log_resolved_spells()
        end
    end

    if me:is_casting_spell() and me:get_active_spell_id() == runtime.slam_id then
        if utils.get_next_swing_ms(me, 2) < SLAM_CANCEL_WINDOW_MS then
            core.input.cancel_spells()
        end
        return
    end

    if utils.is_casting_or_channeling(me) then return end

    local rage = utils.get_rage(me)
    local target = utils.find_best_target(me)
    
    -- Encounter policy (boss-specific rotation adjustments)
    enc = encounter_manager.get_policy(me)

    -- Interrupt
    if target and target:is_valid() and me:can_attack(target) and interrupt_manager.should_interrupt(target) then
        if interrupt_manager.try_interrupt(me, target, "warrior", utils) then
            return
        end
    end

    -- Defensive abilities
    -- Racial abilities
    local hold_offense = dps_risk.should_hold_offense(dps_runtime.build_snapshot(me, target, encounter_manager, ttd_tracker))
    if not hold_offense then
        racial_manager.try_offensive(me)
    end
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    if defensive_manager.try_defensive(me, "warrior", utils) then
        return
    end

    ttd_tracker.update(target)
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() then
        target = focus_target
    end
    
    -- Self-emergency
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold then
        if try_battle_shout then try_battle_shout(me) end
    end

    -- Auto-target: if we are in combat but have no valid hostile target, pick the
    -- nearest mob that is attacking us so the rotation can react.
    if me:is_in_combat() and not is_valid_hostile_target(me, target) then
        local attacker = find_nearest_attacker(me)
        if attacker then
            target = attacker
        end
    end

    if not me:is_in_combat() then
        if runtime.burst_window_active or next(runtime.burst_attempted) ~= nil then
            reset_burst_state()
        end
        reset_on_next_attack_queue_state()
        reset_proc_tracking()

        if runtime.charge_pending_return and utils.get_current_stance(me) == get_home_stance() then
            runtime.charge_pending_return = false
        end
    end

    local target_valid = is_valid_hostile_target(me, target)
    refresh_pending_casts()
    update_stance_return_requests(me, target_valid and target or nil)

    update_notifications(me, target)
    sample_proc_states(me)

    if try_healthstone(me) then
        return
    end

    if try_health_potion(me) then
        return
    end

    if try_stoneform(me) then
        return
    end

    if try_intimidating_shout_keybind(me, target) then
        return
    end

    local gcd_lane_ready = is_gcd_lane_ready()

    if not target_valid then
        if runtime.burst_window_active then
            close_burst_window("target invalid", false)
        end
        runtime.charge_queue_requested_at = 0
        runtime.overpower_queue_requested_at = 0
        reset_charge_stance_request()
        reset_on_next_attack_queue_state()

        if gcd_lane_ready then
            if try_return_after_charge(me) then
                return
            end
            if try_return_to_berserker(me) then
                return
            end
            if do_self_only_upkeep(me) then
                return
            end
        end
        return
    end

    if not me:is_in_combat() then
        if gcd_lane_ready and runtime.charge_pending_return and try_return_after_charge(me) then
            return
        end

        if gcd_lane_ready and try_charge_opener(me, target) then
            return
        end

        if try_prepull_bloodrage(me, target) then
            return
        end
    end

    if runtime.charge_queue_requested_at > 0 then
        return
    end

    utils.ensure_melee_auto_attack(me, target)

    if try_intercept(me, target) then
        return
    end

    if try_pummel(me, target) then
        return
    end

    if try_war_stomp_interrupt(me, target) then
        return
    end

    local aoe_count = utils.enemy_count_in_radius(me, AOE_RADIUS)
    local is_aoe = aoe_count >= menu.aoe_enemy_count:get()
    local target_hp_pct = utils.get_health_pct(target)

    if runtime.overpower_queue_requested_at > 0 then
        return
    end

    if gcd_lane_ready then
        if try_return_after_charge(me) then
            return
        end

        if try_return_to_berserker(me) then
            return
        end

        rage = utils.get_rage(me)

        if do_utility_upkeep(me, target, rage, target_hp_pct) then
            return
        end

        if try_rend_in_battle_stance(me, target, rage) then
            return
        end

        if try_overpower_dance(me, target, rage) then
            return
        end

        if do_burst_lane(me, target) then
            return
        end

        if not runtime.burst_window_active and do_consumable_lane(me) then
            return
        end

        if is_aoe then
            if do_aoe_core_lane(me, target, rage) then
                return
            end
        else
            if do_single_target_core_lane(me, target, rage, target_hp_pct) then
                return
            end
        end

        if try_piercing_howl(me, target, rage, aoe_count) then
            return
        end
    end

    do_queue_lane(me, target, rage, target_hp_pct, is_aoe)
end

local function draw_proc_status_line(y_offset, label, is_active, active_color)
    local dot_color = is_active and active_color or color.gray(170)
    local text_color = is_active and color.white(230) or color.red_pale(210)
    local status_text = is_active and "UP" or "DOWN"

    core.graphics.circle_2d_filled(vec2.new(PROC_HUD_X + 12, y_offset + 7), 5, dot_color)
    core.graphics.text_2d(label .. ": " .. status_text, vec2.new(PROC_HUD_X + 24, y_offset), 13, text_color, false)
end

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
