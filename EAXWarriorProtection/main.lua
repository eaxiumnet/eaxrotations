-- EAX Warrior Protection | main.lua
-- Callback registration, control-panel wiring, and documented EAX Warrior Protection logic.

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


---@type esp_renderer
local esp_renderer = require("esp_renderer")
esp_renderer.init("wprot", "Warrior Prot")


-- Phase 04 visual telemetry wiring
local dps_meter = require("eax_shared/dps_meter")
local cooldown_tracker = require("eax_shared/cooldown_tracker")
local visual_state = require("eax_shared/visual_state")
local reactive_runtime = require("eax_shared/reactive_runtime")
local tank_recovery = require("eax_shared/tank_recovery")

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
        spec = "EAXWarriorProtection",
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
---@type racial_manager
local racial_manager = require("eax_shared/racial_manager")
---@type defensive_manager
local defensive_manager = require("eax_shared/defensive_manager")

---@type color
local color = require("color")
---@type key_helper
local key_helper = require("common/utility/key_helper")
---@type control_panel_helper
local control_panel_utility = require("common/utility/control_panel_helper")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

---@type ttd_tracker
local ttd_tracker = require("ttd_tracker")

local runtime = {
    shield_slam_id = nil,
    revenge_id = nil,
    devastate_id = nil,
    heroic_strike_id = nil,
    cleave_id = nil,
    execute_id = nil,
    thunder_clap_id = nil,
    shield_block_id = nil,
    last_stand_id = nil,
    shield_wall_id = nil,
    spell_reflection_id = nil,
    shield_bash_id = nil,
    concussion_blow_id = nil,
    battle_shout_id = nil,
    commanding_shout_id = nil,
    bloodrage_id = nil,
    demoralizing_shout_id = nil,
    taunt_id = nil,
    challenging_shout_id = nil,
    mocking_blow_id = nil,
    sunder_armor_id = nil,
    rend_id = nil,
    hamstring_id = nil,
    intercept_id = nil,
    charge_id = nil,
    blood_fury_id = nil,
    berserking_id = nil,
    death_wish_id = nil,
    recklessness_id = nil,
    intimidating_shout_id = nil,
    stoneform_id = nil,
    war_stomp_id = nil,
    battle_stance_id = nil,
    berserker_stance_id = nil,
    defensive_stance_id = nil,
    disarm_id = nil,
    berserker_rage_id = nil,
    retaliation_id = nil,
    prev_toggle_state = false,
    prev_intimidating_shout_state = false,
    pending_stance_action = nil,
    pending_stance_action_started_at = 0,
    pending_casts = {},
    auto_intercept_target = nil,
    auto_intercept_retry_target = nil,
    auto_intercept_retry_until = 0,
    stance_swap_retention = 10,
    last_cast_time = 0,
    last_core_action_at = 0,
    combat_entered_at = 0,
    cached_mode = "solo",
    last_mode_debug_at = 0,
    recovery_target = nil,
    recovery_target_hold_until = 0,
    recovery_target_score = 0,
    burst_window_active = false,
    burst_window_started_at = 0,
    burst_attempted = {},
    set_multiplier = 1.0,
}

-- Constants
local SHIELD_SLAM_COST = 20
local REVENGE_COST = 5
local DEVASTATE_COST = 15
local HEROIC_STRIKE_COST = 15
local THUNDER_CLAP_COST = 20
local HAMSTRING_COST = 10
local INTERCEPT_COST = 10
local EXECUTE_HP_THRESHOLD = 0.20
local SHIELD_BLOCK_COST = 10
local QUEUE_SWING_WINDOW_MS = 350
local BLOODRAGE_MAX_RAGE = 60
local BLOODRAGE_MIN_HP_PCT = 0.70
local AOE_RADIUS = 8
local GCD_CAST_INTERVAL = 1.0  -- TBC GCD
local MODE_DEBUG_INTERVAL_MS = 10000
local BURST_WINDOW_MS = 10000
local PENDING_CAST_TIMEOUT_S = 2.5
local FAST_PENDING_CAST_TIMEOUT_S = 0.75
local STANCE_PENDING_CAST_TIMEOUT_S = 3.0
local INTERCEPT_RETRY_BACKOFF_S = 1.5
local STANCE_ACTION_TIMEOUT_S = 4.0
local UTILITY_DEBUFF_REFRESH_MS = 5000
local NOTIFICATION_LABEL = "EAX Warrior Protection"
local SHIELD_BLOCK_SOLO_HP_PCT = 0.60
local SHIELD_BLOCK_SOLO_EMERGENCY_HP_PCT = 0.25
local SHIELD_BLOCK_SOLO_NON_ELITE_HP_PCT = 0.35
local SHIELD_BLOCK_GROUP_HP_PCT = 0.85
local BURST_SAFE_HP_PCT = 0.70
local RECOVERY_TARGET_HOLD_S = 2.0
local RECOVERY_TARGET_DANGEROUS_OVERRIDE = 25
local CORE_STARVATION_TIMEOUT_S = 2.0
local GROUP_ROLE_TANK = 0
local GROUP_ROLE_HEALER = 1
local GROUP_ROLE_DAMAGER = 2
local CLASSIFICATION_ELITE = 1
local CLASSIFICATION_RARE_ELITE = 2
local CLASSIFICATION_WORLD_BOSS = 3

local function resolve_spells()
    runtime.shield_slam_id = utils.resolve_spell_id(spells.SHIELD_SLAM)
    runtime.revenge_id = utils.resolve_spell_id(spells.REVENGE)
    runtime.devastate_id = utils.resolve_spell_id(spells.DEVASTATE)
    runtime.heroic_strike_id = utils.resolve_spell_id(spells.HEROIC_STRIKE)
    runtime.cleave_id = utils.resolve_spell_id(spells.CLEAVE)
    runtime.execute_id = utils.resolve_spell_id(spells.EXECUTE)
    runtime.thunder_clap_id = utils.resolve_spell_id(spells.THUNDER_CLAP)
    runtime.shield_block_id = utils.resolve_spell_id(spells.SHIELD_BLOCK)
    runtime.last_stand_id = utils.resolve_spell_id(spells.LAST_STAND)
    runtime.shield_wall_id = utils.resolve_spell_id(spells.SHIELD_WALL)
    runtime.spell_reflection_id = utils.resolve_spell_id(spells.SPELL_REFLECTION)
    runtime.shield_bash_id = utils.resolve_spell_id(spells.SHIELD_BASH)
    runtime.concussion_blow_id = utils.resolve_spell_id(spells.CONCUSSION_BLOW)
    runtime.battle_shout_id = utils.resolve_spell_id(spells.BATTLE_SHOUT)
    runtime.commanding_shout_id = utils.resolve_spell_id(spells.COMMANDING_SHOUT)
    runtime.bloodrage_id = utils.resolve_spell_id(spells.BLOODRAGE)
    runtime.demoralizing_shout_id = utils.resolve_spell_id(spells.DEMORALIZING_SHOUT)
    runtime.taunt_id = utils.resolve_spell_id(spells.TAUNT)
    runtime.challenging_shout_id = utils.resolve_spell_id(spells.CHALLENGING_SHOUT)
    runtime.mocking_blow_id = utils.resolve_spell_id(spells.MOCKING_BLOW)
    runtime.sunder_armor_id = utils.resolve_spell_id(spells.SUNDER_ARMOR)
    runtime.rend_id = utils.resolve_spell_id(spells.REND)
    runtime.hamstring_id = utils.resolve_spell_id(spells.HAMSTRING)
    runtime.intercept_id = utils.resolve_spell_id(spells.INTERCEPT)
    runtime.charge_id = utils.resolve_spell_id(spells.CHARGE)
    runtime.blood_fury_id = utils.resolve_spell_id(spells.BLOOD_FURY)
    runtime.berserking_id = utils.resolve_spell_id(spells.BERSERKING)
    runtime.death_wish_id = utils.resolve_spell_id(spells.DEATH_WISH)
    runtime.recklessness_id = utils.resolve_spell_id(spells.RECKLESSNESS)
    runtime.intimidating_shout_id = utils.resolve_spell_id(spells.INTIMIDATING_SHOUT)
    runtime.stoneform_id = utils.resolve_spell_id(spells.STONEFORM)
    runtime.war_stomp_id = utils.resolve_spell_id(spells.WAR_STOMP)
    runtime.battle_stance_id = utils.resolve_spell_id(spells.BATTLE_STANCE)
    runtime.berserker_stance_id = utils.resolve_spell_id(spells.BERSERKER_STANCE)
    runtime.defensive_stance_id = utils.resolve_spell_id(spells.DEFENSIVE_STANCE)
    runtime.disarm_id = utils.resolve_spell_id(spells.DISARM)
    runtime.berserker_rage_id = utils.resolve_spell_id(spells.BERSERKER_RAGE)
    runtime.retaliation_id = utils.resolve_spell_id(spells.RETALIATION)
    runtime.stance_swap_retention = utils.get_stance_swap_retention()
end

local function log_resolved_spells()
    core.log("[EAX Warrior Protection] Resolved: SS=" .. tostring(runtime.shield_slam_id)
        .. " REV=" .. tostring(runtime.revenge_id)
        .. " DEV=" .. tostring(runtime.devastate_id)
        .. " TAUNT=" .. tostring(runtime.taunt_id)
        .. " SBASH=" .. tostring(runtime.shield_bash_id)
        .. " stance_ret=" .. tostring(runtime.stance_swap_retention)
        .. " build=1.3.1-recklessness_fix"
        .. " solo_recovery=interrupts_only"
        .. " solo_order=rotation_first"
        .. " fixes=stance_gate,shield_wall_order,sunder_stacks,execute_rage_slider,hs_rage_cap,demo_shout_aoe,disarm,berserker_rage,retaliation,spell_reflect_progress")
end

resolve_spells()
log_resolved_spells()
-- Seed stance tracker to home stance so the nil-fallback has a value
-- before the engine has a chance to confirm it at runtime.
utils.set_tracked_stance("defensive")

-- mode detection
local function detect_mode()
    local objects = core.object_manager.get_visible_objects()
    local party_count = 0
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() and obj:is_party_member() then
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

local function refresh_mode_cache()
    runtime.cached_mode = detect_mode()
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
    return runtime.cached_mode
end

local function is_valid_hostile_target(me, target)
    return target and target:is_valid() and not target:is_dead() and me:can_attack(target)
end

local function get_mode_policy()
    local mode = get_effective_mode()
    if mode == "solo" then
        return {
            name = mode,
            auto_peel = false,
            recovery_delta = math.huge,
            dangerous_recovery_delta = math.huge,
            allow_hamstring = menu.use_hamstring:get_state(),
            allow_intercept = menu.use_intercept:get_state(),
            allow_peel_intercept = false,
            allow_risky_burst = true,
            allow_safe_burst = true,
        }
    end

    if mode == "raid" then
        return {
            name = mode,
            auto_peel = menu.auto_peel:get_state(),
            recovery_delta = 25,
            dangerous_recovery_delta = 10,
            allow_hamstring = false,
            allow_intercept = false,
            allow_peel_intercept = false,
            allow_risky_burst = false,
            allow_safe_burst = true,
        }
    end

    return {
        name = "dungeon",
        auto_peel = menu.auto_peel:get_state(),
        recovery_delta = 15,
        dangerous_recovery_delta = 5,
        allow_hamstring = false,
        allow_intercept = false,
        allow_peel_intercept = menu.use_peel_intercept:get_state(),
        allow_risky_burst = false,
        allow_safe_burst = true,
    }
end

local function clear_recovery_target()
    runtime.recovery_target = nil
    runtime.recovery_target_hold_until = 0
    runtime.recovery_target_score = 0
end

local function is_elite_or_boss(target)
    if not target or not target:is_valid() then return false end

    if target.is_boss and target:is_boss() then
        return true
    end

    if target.get_classification then
        local classification = target:get_classification()
        return classification == CLASSIFICATION_ELITE
            or classification == CLASSIFICATION_RARE_ELITE
            or classification == CLASSIFICATION_WORLD_BOSS
    end

    return false
end

local function safe_get_threat_situation(target, me)
    if not target or not me or not target.get_threat_situation then
        return nil
    end

    local ok, threat = pcall(function() return target:get_threat_situation(me) end)
    if ok and type(threat) == "table" then
        return threat
    end

    return nil
end

local function safe_get_guid(unit)
    if not unit then
        return nil
    end

    if type(unit.get_guid) ~= "function" then
        return nil
    end

    local ok, guid = pcall(function() return unit:get_guid() end)
    if not ok or guid == nil then
        return nil
    end

    return tostring(guid)
end

local function same_unit(a, b)
    if not a or not b then
        return false
    end

    if type(a.is_valid) ~= "function" or type(b.is_valid) ~= "function" then
        return false
    end

    if not a:is_valid() or not b:is_valid() then
        return false
    end

    local a_guid = safe_get_guid(a)
    local b_guid = safe_get_guid(b)
    if a_guid and b_guid then
        return a_guid == b_guid
    end

    if a == b then
        return true
    end

    local a_is_player = type(a.is_player) == "function" and a:is_player() or false
    local b_is_player = type(b.is_player) == "function" and b:is_player() or false
    if not a_is_player or not b_is_player then
        return false
    end

    local a_name = type(a.get_name) == "function" and a:get_name() or ""
    local b_name = type(b.get_name) == "function" and b:get_name() or ""
    if a_name == "" or b_name == "" then
        return false
    end

    return a_name == b_name
end

local function same_target_unit(owner, other)
    if not owner or not other then
        return false
    end

    if type(owner.is_valid) ~= "function" or not owner:is_valid() then
        return false
    end

    if type(owner.get_target) ~= "function" then
        return false
    end

    local ok, owner_target = pcall(function() return owner:get_target() end)
    if not ok or not owner_target or type(owner_target.is_valid) ~= "function" or not owner_target:is_valid() then
        return false
    end

    return same_unit(owner_target, other)
end

local function get_active_cast_progress_pct(unit)
    if not unit or not unit:is_valid() then return 0 end

    local start_time = 0
    local end_time = 0
    if unit:is_casting_spell() then
        start_time = unit:get_active_spell_cast_start_time() or 0
        end_time = unit:get_active_spell_cast_end_time() or 0
    elseif unit:is_channelling_spell() then
        start_time = unit:get_active_channel_cast_start_time() or 0
        end_time = unit:get_active_channel_cast_end_time() or 0
    end

    if end_time <= start_time then
        return 0
    end

    local pct = ((core.game_time() - start_time) / (end_time - start_time)) * 100
    if pct < 0 then return 0 end
    if pct > 100 then return 100 end
    return pct
end

local function is_dangerous_caster(unit)
    return unit
        and unit:is_valid()
        and (unit:is_casting_spell() or unit:is_channelling_spell())
end

local function is_interruptible_caster(unit)
    if not unit or not unit:is_valid() then return false end
    if unit:is_casting_spell() then
        return unit:is_active_spell_interruptable()
    end
    return unit:is_channelling_spell()
end

local function is_healer_or_dps_party_member(unit)
    if not unit or not unit:is_valid() or not unit:is_party_member() then
        return false
    end

    local role_id = unit.get_group_role and unit:get_group_role() or -1
    return role_id == GROUP_ROLE_HEALER or role_id == GROUP_ROLE_DAMAGER
end

local function describe_unit(unit)
    if not unit or not unit.is_valid or not unit:is_valid() then
        return "unknown"
    end

    local name = unit.get_name and unit:get_name() or ""
    if name == "" then
        return "unknown"
    end

    return name
end

local function describe_victim_role(me, victim)
    if not victim or not victim:is_valid() then
        return nil, nil
    end

    if same_unit(victim, me) then
        return 0, "self"
    end

    if not victim:is_party_member() then
        return nil, nil
    end

    local role_id = victim.get_group_role and victim:get_group_role() or -1
    if role_id == GROUP_ROLE_HEALER then
        return 100, "healer"
    end
    if role_id == GROUP_ROLE_DAMAGER then
        return 70, "damager"
    end
    return 40, "party"
end

local function can_intercept_target(me, target)
    if not runtime.intercept_id or not target or not target:is_valid() then return false end
    if utils.is_melee_target(me, target) then return false end

    local distance = utils.get_distance_to_target(me, target)
    if distance < menu.intercept_min_range:get() then return false end

    local max_range = core.spell_book.get_spell_max_range(runtime.intercept_id)
    if max_range and max_range > 0 then
        local max_distance = max_range + (target:get_bounding_radius() or 0)
        if distance > max_distance then
            return false
        end
    end

    return true
end

local function build_recovery_candidate(me, enemy)
    if not is_valid_hostile_target(me, enemy) or not enemy:is_in_combat() then
        return nil
    end

    local victim = enemy:get_target()
    if not victim or not victim:is_valid() then
        return nil
    end

    local victim_bonus, victim_role = describe_victim_role(me, victim)
    if victim_bonus == nil then
        return nil
    end

    local score = victim_bonus
    local dangerous = is_dangerous_caster(enemy)
    local progress_pct = get_active_cast_progress_pct(enemy)
    if dangerous then
        score = score + 30
        if progress_pct >= 30 then
            score = score + 15
        end
    end

    if is_elite_or_boss(enemy) then
        score = score + 15
    end

    if utils.is_melee_target(me, enemy) then
        score = score + 10
    elseif can_intercept_target(me, enemy) then
        score = score + 5
    end

    if same_unit(runtime.recovery_target, enemy) then
        score = score + 25
    end

    return {
        target = enemy,
        victim = victim,
        victim_role = victim_role,
        score = score,
        dangerous = dangerous,
        interruptible = is_interruptible_caster(enemy),
        progress_pct = progress_pct,
        off_me = not same_unit(victim, me),
        party_dangerous = dangerous and (victim_role == "healer" or victim_role == "damager"),
    }
end

local function is_recovery_target_secured(me, target)
    if not is_valid_hostile_target(me, target) then
        return true
    end

    if same_target_unit(target, me) and not is_dangerous_caster(target) then
        return true
    end

    local threat = safe_get_threat_situation(target, me)
    return threat and threat.is_tanking and not is_dangerous_caster(target) or false
end

local function select_recovery_target(me, primary_target, mode_policy)
    local recovery = {
        target = nil,
        score = 0,
        active_candidates = 0,
        off_me_count = 0,
    }

    if not mode_policy.auto_peel then
        clear_recovery_target()
        return recovery
    end

    if runtime.recovery_target and is_recovery_target_secured(me, runtime.recovery_target) then
        clear_recovery_target()
    end

    local best = nil
    local helper_candidates = {}
    local helper_by_guid = {}
    local dangerous_count = 0
    local objects = core.object_manager.get_visible_objects()
    for i = 1, #objects do
        local candidate = build_recovery_candidate(me, objects[i])
        if candidate then
            if candidate.off_me then
                recovery.active_candidates = recovery.active_candidates + 1
                recovery.off_me_count = recovery.off_me_count + 1
            end
            if candidate.dangerous then
                dangerous_count = dangerous_count + 1
            end
            local guid = safe_get_guid(candidate.target)
            if guid then
                helper_candidates[#helper_candidates + 1] = {
                    guid = guid,
                    victim_role = candidate.victim_role,
                    dangerous_caster = candidate.dangerous,
                    interruptible = candidate.interruptible,
                    cast_progress_pct = candidate.progress_pct / 100,
                    elite = is_elite_or_boss(candidate.target),
                }
                helper_by_guid[guid] = candidate
            end
            if not best or candidate.score > best.score then
                best = candidate
            end
        end
    end

    local threat_instability = math.min(1, (recovery.off_me_count * 0.40) + (dangerous_count > 0 and 0.20 or 0))
    local shared_choice = tank_recovery.select_recovery_target(me, {
        snapshot = {
            self = {
                hp_pct = utils.get_health_pct(me),
                incoming_damage_pct_2s = 0,
                incoming_heal_pct = 0,
            },
            party = {
                group_collapse_risk = recovery.off_me_count > 0 and 0.50 or 0,
                threat_instability = threat_instability,
            },
        },
        candidates = helper_candidates,
    })
    if shared_choice and shared_choice.guid then
        best = helper_by_guid[shared_choice.guid] or best
    elseif recovery.off_me_count > 0 then
        best = nil
    end

    local current = nil
    if runtime.recovery_target then
        current = build_recovery_candidate(me, runtime.recovery_target)
    end

    if current and runtime.recovery_target_hold_until > core.time() then
        if not best
            or same_unit(best.target, current.target)
            or not (best.party_dangerous and best.score >= (current.score + RECOVERY_TARGET_DANGEROUS_OVERRIDE))
        then
            recovery.target = current.target
            recovery.score = current.score
            recovery.victim = current.victim
            recovery.victim_role = current.victim_role
            recovery.party_dangerous = current.party_dangerous
            return recovery
        end
    end

    if not best or same_unit(best.target, primary_target) then
        clear_recovery_target()
        return recovery
    end

    local primary_candidate = build_recovery_candidate(me, primary_target)
    local primary_score = primary_candidate and primary_candidate.score or 0
    local delta_required = best.party_dangerous and mode_policy.dangerous_recovery_delta or mode_policy.recovery_delta
    if (best.score - primary_score) < delta_required then
        clear_recovery_target()
        return recovery
    end

    runtime.recovery_target = best.target
    runtime.recovery_target_hold_until = core.time() + RECOVERY_TARGET_HOLD_S
    runtime.recovery_target_score = best.score
    recovery.target = best.target
    recovery.score = best.score
    recovery.victim = best.victim
    recovery.victim_role = best.victim_role
    recovery.party_dangerous = best.party_dangerous
    return recovery
end

local function count_melee_attackers_on_me(me)
    local count = 0
    local objects = core.object_manager.get_visible_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if is_valid_hostile_target(me, obj)
            and obj:is_in_combat()
            and same_target_unit(obj, me)
            and utils.is_melee_target(me, obj)
        then
            count = count + 1
        end
    end
    return count
end

local function has_melee_auto_started(me, target)
    if not is_valid_hostile_target(me, target) then
        return false
    end

    if type(me.is_auto_attacking) == "function" and me:is_auto_attacking() then
        return true
    end

    return utils.get_next_swing_ms(me, 1) < math.huge
end

local function has_melee_pressure(me, target)
    if not is_valid_hostile_target(me, target) or not utils.is_melee_target(me, target) then
        return false
    end

    -- If target is confirmed targeting us, that's definitive pressure.
    if same_target_unit(target, me) then return true end

    -- Multiple attackers in melee range = pressure regardless of target data.
    if count_melee_attackers_on_me(me) >= 2 then return true end

    -- Solo fallback: if target is in melee range, in combat, and we're auto-attacking,
    -- treat it as pressure. Engine may not always return clean target data on solo mobs.
    if target:is_in_combat() and has_melee_auto_started(me, target) then return true end

    return false
end

local function is_tanking_target(me, target)
    if not is_valid_hostile_target(me, target) then return false end
    if same_target_unit(target, me) then
        return true
    end

    local threat = safe_get_threat_situation(target, me)
    return threat and threat.is_tanking or false
end

local function log_recovery_blocked(key, message)
    if menu.debug:get_state() and utils.throttle("simpleprot:debug:" .. key, 1.0) then
        core.log("[EAX Warrior Protection] " .. message)
    end
end

local function is_safe_group_burst_window(me, target)
    if runtime.recovery_target then return false end
    if utils.get_health_pct(me) <= BURST_SAFE_HP_PCT then return false end
    return is_elite_or_boss(target)
end

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
            if obj_target and obj_target:is_valid() and same_unit(obj_target, me) then
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

local function note_core_action()
    runtime.last_core_action_at = core.time()
end

local function log_lane_reason(key, message)
    if not menu.debug:get_state() then
        return
    end

    if not utils.throttle("simpleprot:lane_reason:" .. key, 1.0) then
        return
    end

    core.log("[EAX Warrior Protection] " .. message)
end

local function is_pending_cast(spell_id)
    if not spell_id then return false end

    local pending = runtime.pending_casts[spell_id]
    if not pending then
        return false
    end

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

local function get_solo_core_rage_reserve()
    if menu.use_shield_slam:get_state() and runtime.shield_slam_id then
        return SHIELD_SLAM_COST
    end

    if menu.use_devastate:get_state() and runtime.devastate_id then
        return DEVASTATE_COST
    end

    if menu.use_revenge:get_state() and runtime.revenge_id then
        return REVENGE_COST
    end

    return 0
end

local function maybe_log_core_starvation(me, target, action_target_valid, rage, mode_policy)
    if not menu.debug:get_state() then
        return
    end

    if not me:is_in_combat() or not action_target_valid or runtime.last_core_action_at <= 0 then
        return
    end

    -- Only fire if stuck for a meaningful time AND rage is genuinely exhausted (0),
    -- not just the normal between-swing wait at 11-19 rage.
    if (core.time() - runtime.last_core_action_at) < CORE_STARVATION_TIMEOUT_S then
        return
    end

    if rage > 0 then
        return
    end

    if not utils.throttle("simpleprot:core_starvation", 2.0) then
        return
    end

    local melee_started = has_melee_auto_started(me, target)
    local in_melee = is_valid_hostile_target(me, target) and utils.is_melee_target(me, target) or false
    local shield_block_active = utils.has_buff(me, spells.BUFF_SHIELD_BLOCK)
    local shield_block_pending = is_pending_or_current(runtime.shield_block_id)
    local revenge_usable = runtime.revenge_id and core.spell_book.is_usable_spell(runtime.revenge_id) or false
    local target_hp = is_valid_hostile_target(me, target) and utils.get_health_pct(target) or 0

    core.log("[EAX Warrior Protection] Core starvation: mode=" .. tostring(mode_policy.name)
        .. " rage=" .. tostring(rage)
        .. " auto=" .. tostring(melee_started)
        .. " melee=" .. tostring(in_melee)
        .. " sbuff=" .. tostring(shield_block_active)
        .. " spending=" .. tostring(shield_block_pending)
        .. " revenge=" .. tostring(revenge_usable)
        .. " target_hp=" .. string.format("%.2f", target_hp))
end

local function add_notification_once(unique_id, label, message, duration_s, notification_color)
    if not menu.show_notifications:get_state() then
        return false
    end

    if core.graphics.is_notification_active(unique_id) then
        return false
    end

    return core.graphics.add_notification(
        unique_id,
        label,
        message,
        duration_s or 0.9,
        notification_color or color.gold(220)
    )
end

local function notify_cast(unique_id, message, notification_color, duration_s)
    return add_notification_once(
        unique_id,
        NOTIFICATION_LABEL,
        message,
        duration_s,
        notification_color
    )
end

local function is_gcd_lane_ready()
    if (core.time() - runtime.last_cast_time) < GCD_CAST_INTERVAL then
        return false
    end
    return core.spell_book.get_global_cooldown() <= 0
end

local function get_home_stance()
    return "defensive"
end

local function get_home_stance_id()
    return runtime.defensive_stance_id
end

local function get_stance_label(stance_name)
    if stance_name == "battle" then
        return "Battle Stance"
    elseif stance_name == "berserker" then
        return "Berserker Stance"
    end
    return "Defensive Stance"
end

local function clear_pending_stance_action(reason)
    if runtime.pending_stance_action
        and runtime.pending_stance_action.key == "intercept"
        and (reason == "timeout" or reason == "intercept range invalid" or reason == "target invalid")
    then
        runtime.auto_intercept_retry_target = runtime.pending_stance_action.target
        runtime.auto_intercept_retry_until = core.time() + INTERCEPT_RETRY_BACKOFF_S
    end

    if reason and runtime.pending_stance_action then
        utils.log_debug(
            menu,
            "Clearing staged action " .. runtime.pending_stance_action.action_label .. ": " .. reason
        )
    end

    runtime.pending_stance_action = nil
    runtime.pending_stance_action_started_at = 0
end

local function stage_stance_action(me, action, rage, ability_cost)
    if runtime.pending_stance_action then return false end
    if not action or not action.action_id then return false end
    if not action.required_stance or not action.required_stance_id then return false end

    local current_stance = utils.get_current_stance(me)
    if current_stance ~= action.required_stance then
        if not utils.can_stance_dance_for_cost(
            rage,
            ability_cost or 0,
            0,
            runtime.stance_swap_retention
        ) then
            return false
        end

        if is_pending_or_current(action.required_stance_id) then
            return false
        end

        if not utils.can_cast_self(action.required_stance_id, me) then
            return false
        end

        if utils.cast_self(action.required_stance_id, me) then
            runtime.pending_stance_action = action
            runtime.pending_stance_action_started_at = core.time()
            mark_pending_cast(action.required_stance_id, STANCE_PENDING_CAST_TIMEOUT_S, function()
                runtime.pending_stance_action_started_at = core.time()
            end)
            utils.set_tracked_stance(action.required_stance)
            utils.log_debug(menu, "Stance -> " .. action.required_stance .. " (" .. action.action_label .. ")")
            notify_cast(
                "simpleprot:stance:" .. action.required_stance,
                "Stance -> " .. get_stance_label(action.required_stance),
                color.blue(220),
                0.9
            )
            note_cast()
            return true
        end

        return false
    end

    runtime.pending_stance_action = action
    runtime.pending_stance_action_started_at = core.time()
    utils.log_debug(menu, "Queued staged action: " .. action.action_label)
    return true
end

local function process_pending_stance_action(me)
    local action = runtime.pending_stance_action
    if not action then return false end

    if (core.time() - runtime.pending_stance_action_started_at) >= STANCE_ACTION_TIMEOUT_S then
        clear_pending_stance_action("timeout")
        return false
    end

    if action.cast_mode == "target" then
        local target = action.target
        if not is_valid_hostile_target(me, target) then
            clear_pending_stance_action("target invalid")
            return false
        end

        if action.key == "hamstring" then
            if utils.get_debuff_remaining_ms(target, spells.DEBUFF_HAMSTRING) >= UTILITY_DEBUFF_REFRESH_MS then
                clear_pending_stance_action("hamstring already refreshed")
                return false
            end

            if not utils.is_melee_target(me, target) then
                clear_pending_stance_action("hamstring target out of melee range")
                return false
            end
        elseif action.key == "intercept" then
            local distance = utils.get_distance_to_target(me, target)
            local max_range = core.spell_book.get_spell_max_range(action.action_id)
            local max_distance = math.huge
            if max_range and max_range > 0 then
                max_distance = max_range + (target:get_bounding_radius() or 0)
            end

            if utils.is_melee_target(me, target)
                or distance < menu.intercept_min_range:get()
                or distance > max_distance
            then
                clear_pending_stance_action("intercept range invalid")
                return false
            end
        end
    elseif action.key == "recklessness" and utils.has_buff(me, spells.BUFF_RECKLESSNESS) then
        clear_pending_stance_action("recklessness already active")
        return false
    end

    -- After casting a stance we set _tracked_stance immediately.
    -- Give the engine one extra frame grace before rechecking via get_current_stance,
    -- which may still return the old value on the tick immediately after the cast fires.
    local detected_stance = utils.get_current_stance(me)
    local effective_stance = detected_stance or utils._tracked_stance
    if effective_stance ~= action.required_stance then
        if is_pending_or_current(action.required_stance_id) then
            return false
        end

        if not utils.can_cast_self(action.required_stance_id, me) then
            return false
        end

        if utils.cast_self(action.required_stance_id, me) then
            mark_pending_cast(action.required_stance_id, STANCE_PENDING_CAST_TIMEOUT_S, function()
                runtime.pending_stance_action_started_at = core.time()
            end)
            utils.set_tracked_stance(action.required_stance)
            utils.log_debug(menu, "Stance -> " .. action.required_stance .. " (" .. action.action_label .. ")")
            notify_cast(
                "simpleprot:stance:" .. action.required_stance,
                "Stance -> " .. get_stance_label(action.required_stance),
                color.blue(220),
                0.9
            )
            note_cast()
            return true
        end

        return false
    end

    local cast_success = false
    if action.cast_mode == "self" then
        -- Skip is_usable_spell check here - some spells (e.g. Recklessness) briefly
        -- return unusable for a frame or two after a stance swap even though the stance
        -- is now correct. We've already confirmed the stance, so only check cooldown.
        local cd = action.action_id and core.spell_book.get_spell_cooldown(action.action_id) or -1
        local spell_ready = cd <= 0
        if spell_ready then
            if action.use_fast_queue then
                cast_success = utils.cast_self_fast(action.action_id, me)
            else
                cast_success = utils.cast_self(action.action_id, me)
            end
        end
    elseif action.key == "hamstring" then
        if utils.can_cast_melee(action.action_id, me) and utils.cast_target(action.action_id, action.target) then
            cast_success = true
        end
    elseif utils.can_cast_hostile(action.action_id, me, action.target) and utils.cast_target(action.action_id, action.target) then
        cast_success = true
    end

    if not cast_success then
        return false
    end

    if action.key == "intercept" then
        runtime.auto_intercept_target = action.target
    end

    if action.cast_mode == "self" then
        mark_pending_cast(
            action.action_id,
            action.use_fast_queue and FAST_PENDING_CAST_TIMEOUT_S or PENDING_CAST_TIMEOUT_S
        )
    end

    utils.log_debug(menu, action.log_message or action.action_label)
    if action.notify_id then
        notify_cast(
            action.notify_id,
            action.notify_message or action.action_label,
            action.notify_color,
            action.notify_duration_s
        )
    end
    clear_pending_stance_action()
    note_cast()
    return true
end

local function try_return_home_stance(me)
    local home = get_home_stance()
    local current = utils.get_current_stance(me)
    -- If stance detection returns nil we cannot confirm we're in the wrong stance,
    -- so don't attempt a swap - let the rotation proceed assuming home stance.
    if current == nil then return false end
    if current == home then return false end

    local home_id = get_home_stance_id()
    if not home_id then return false end

    if is_pending_or_current(home_id) then
        return false
    end

    if utils.can_cast_self(home_id, me) and utils.cast_self(home_id, me) then
        mark_pending_cast(home_id, PENDING_CAST_TIMEOUT_S)
        utils.set_tracked_stance(home)
        utils.log_debug(menu, "Stance -> " .. home)
        notify_cast("simpleprot:stance:return", "Return -> " .. get_stance_label(home), color.blue(220), 0.9)
        note_cast()
        return true
    end

    return false
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

-- Shouts
local function try_shout(me)
    local use_commanding = menu.use_commanding_shout:get_state() and runtime.commanding_shout_id
    local use_battle = menu.use_battle_shout:get_state() and runtime.battle_shout_id
    if not use_commanding and not use_battle then return false end

    local shout_id = nil
    local shout_buff = nil
    local shout_name = nil

    if use_commanding then
        shout_id = runtime.commanding_shout_id
        shout_buff = spells.BUFF_COMMANDING_SHOUT
        shout_name = "Commanding Shout"
    elseif use_battle then
        shout_id = runtime.battle_shout_id
        shout_buff = spells.BUFF_BATTLE_SHOUT
        shout_name = "Battle Shout"
    end

    if not shout_id then return false end

    local remaining = utils.get_buff_remaining_ms(me, shout_buff)
    if remaining >= 5000 then return false end
    if is_pending_or_current(shout_id) then return false end

    if utils.can_cast_self(shout_id, me) and utils.cast_self(shout_id, me) then
        mark_pending_cast(shout_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, shout_name .. " refresh")
        note_cast()
        return true
    end

    return false
end

-- Demo shout
local function try_demo_shout(me, target)
    if not menu.use_demo_shout:get_state() or not runtime.demoralizing_shout_id then return false end
    if not target or not utils.is_melee_target(me, target) then return false end

    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_DEMORALIZING_SHOUT)
    if remaining >= 5000 then return false end

    if utils.can_cast_self(runtime.demoralizing_shout_id, me) and utils.cast_self(runtime.demoralizing_shout_id, me) then
        utils.log_debug(menu, "Demo Shout")
        note_cast()
        return true
    end

    return false
end

-- Bloodrage
local function try_bloodrage(me, rage)
    if not menu.use_bloodrage:get_state() or not runtime.bloodrage_id then return false end
    if not me:is_in_combat() then return false end
    if rage > BLOODRAGE_MAX_RAGE then return false end
    if utils.get_health_pct(me) < BLOODRAGE_MIN_HP_PCT then return false end
    if utils.has_buff(me, spells.BUFF_BLOODRAGE) then return false end
    if is_pending_or_current(runtime.bloodrage_id) then return false end

    if utils.can_cast_self(runtime.bloodrage_id, me) and utils.cast_self_fast(runtime.bloodrage_id, me) then
        mark_pending_cast(runtime.bloodrage_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Bloodrage")
        notify_cast("simpleprot:cast:bloodrage", "Bloodrage", color.red(220), 0.9)
        note_cast()
        return true
    end

    return false
end

-- Thunder Clap
local function try_thunder_clap(me, target, rage)
    if enc and not enc.aoe_safe then return false end
    if not menu.use_thunder_clap:get_state() or not runtime.thunder_clap_id then return false end
    if not target or not utils.is_melee_target(me, target) then return false end
    if rage < THUNDER_CLAP_COST then return false end

    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_THUNDER_CLAP)
    if remaining >= 5000 then return false end

    if utils.can_cast_melee(runtime.thunder_clap_id, me) and utils.cast_target(runtime.thunder_clap_id, target) then
        utils.log_debug(menu, "Thunder Clap")
        note_cast()
        note_core_action()
        return true
    end

    return false
end

local try_ironshield_potion
local try_intercept
local try_rend
local try_hamstring_filler
local try_healthstone
local try_health_potion
local try_stoneform

local function should_use_shield_block(me, target, rage, mode_policy)
    if not is_valid_hostile_target(me, target) or not utils.is_melee_target(me, target) then
        return false, nil
    end

    if not has_melee_pressure(me, target) then
        return false, "Shield Block blocked: no melee pressure"
    end

    if rage < SHIELD_BLOCK_COST then
        return false, nil
    end

    if utils.has_buff(me, spells.BUFF_SHIELD_BLOCK) then
        return false, "Shield Block blocked: buff already active"
    end

    if is_pending_or_current(runtime.shield_block_id) then
        return false, "Shield Block blocked: pending/current"
    end

    local hp_pct = utils.get_health_pct(me)
    if mode_policy.name == "solo" then
        if hp_pct <= SHIELD_BLOCK_SOLO_EMERGENCY_HP_PCT then
            return true, "Shield Block: solo emergency"
        end

        if not has_melee_auto_started(me, target) then
            return false, "Shield Block blocked: auto attack not started"
        end

        if is_elite_or_boss(target) then
            if hp_pct <= SHIELD_BLOCK_SOLO_HP_PCT or count_melee_attackers_on_me(me) >= 2 then
                return true, "Shield Block: solo elite mitigation"
            end
            return false, nil
        end

        if hp_pct <= SHIELD_BLOCK_SOLO_NON_ELITE_HP_PCT then
            return true, "Shield Block: solo emergency"
        end

        return false, nil
    end

    if not has_melee_auto_started(me, target) then
        return false, "Shield Block blocked: auto attack not started"
    end

    if is_elite_or_boss(target) and is_tanking_target(me, target) then
        return true, "Shield Block: group boss mitigation"
    end

    if count_melee_attackers_on_me(me) >= 2 then
        return true, "Shield Block: group multi-melee mitigation"
    end

    if hp_pct <= SHIELD_BLOCK_GROUP_HP_PCT and is_tanking_target(me, target) then
        return true, "Shield Block: group low-hp mitigation"
    end

    return false, nil
end

local function do_emergency_defensive_lane(me, target, hp_pct)
    if try_healthstone(me) then return true end
    if try_health_potion(me) then return true end
    if try_stoneform(me) then return true end

    -- Berserker Rage: break fear/incapacitate as soon as detected
    if menu.use_berserker_rage:get_state()
        and runtime.berserker_rage_id
        and not utils.has_buff(me, spells.BUFF_BERSERKER_RAGE)
        and not is_pending_or_current(runtime.berserker_rage_id)
        and me:is_in_combat()
        and (type(me.is_feared) == "function" and me:is_feared()
            or type(me.is_incapacitated) == "function" and me:is_incapacitated())
        and utils.can_cast_self(runtime.berserker_rage_id, me)
    then
        if utils.cast_self_fast(runtime.berserker_rage_id, me) then
            mark_pending_cast(runtime.berserker_rage_id, FAST_PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "Defensive: Berserker Rage (fear break)")
            note_cast()
            return true
        end
    end

    -- Shield Wall first: damage reduction keeps you alive for heals
    if menu.use_shield_wall:get_state()
        and runtime.shield_wall_id
        and hp_pct < (menu.shield_wall_hp_pct:get() / 100)
        and not is_pending_or_current(runtime.shield_wall_id)
        and not utils.has_buff(me, spells.BUFF_SHIELD_WALL)
        and utils.can_cast_self(runtime.shield_wall_id, me)
    then
        if utils.cast_self_fast(runtime.shield_wall_id, me) then
            mark_pending_cast(runtime.shield_wall_id, FAST_PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "Defensive: Shield Wall")
            note_cast()
            return true
        end
    end

    -- Last Stand second: HP buffer after damage is reduced
    if menu.use_last_stand:get_state()
        and runtime.last_stand_id
        and hp_pct < (menu.last_stand_hp_pct:get() / 100)
        and not is_pending_or_current(runtime.last_stand_id)
        and not utils.has_buff(me, spells.BUFF_LAST_STAND)
        and utils.can_cast_self(runtime.last_stand_id, me)
    then
        if utils.cast_self_fast(runtime.last_stand_id, me) then
            mark_pending_cast(runtime.last_stand_id, FAST_PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "Defensive: Last Stand")
            note_cast()
            return true
        end
    end

    -- Spell Reflection: wait until cast is past configured progress threshold
    if menu.use_spell_reflection:get_state()
        and runtime.spell_reflection_id
        and target
        and is_dangerous_caster(target)
        and not is_pending_or_current(runtime.spell_reflection_id)
        and not utils.has_buff(me, spells.BUFF_SPELL_REFLECTION)
        and utils.can_cast_self(runtime.spell_reflection_id, me)
        and get_active_cast_progress_pct(target) >= menu.spell_reflection_progress_pct:get()
    then
        if utils.cast_self_fast(runtime.spell_reflection_id, me) then
            mark_pending_cast(runtime.spell_reflection_id, FAST_PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "Defensive: Spell Reflection")
            note_cast()
            return true
        end
    end

    return false
end

local function do_mitigation_lane(me, target, rage, mode_policy, hp_pct)
    if menu.use_shield_block:get_state()
        and runtime.shield_block_id
        and utils.can_cast_self(runtime.shield_block_id, me)
    then
        local should_cast, reason = should_use_shield_block(me, target, rage, mode_policy)
        if should_cast then
            if utils.cast_self_fast(runtime.shield_block_id, me) then
                mark_pending_cast(runtime.shield_block_id, FAST_PENDING_CAST_TIMEOUT_S)
                utils.log_debug(menu, "Defensive: Shield Block")
                log_lane_reason("shield_block_cast", reason)
                note_cast()
                return true
            end
        elseif reason then
            log_lane_reason("shield_block_blocked", reason)
        end
    end

    if try_ironshield_potion(me, target, mode_policy, hp_pct) then
        return true
    end

    return false
end

-- Healthstone
try_healthstone = function(me)
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

-- Health Potion
try_health_potion = function(me)
    if not menu.use_health_potion:get_state() then return false end
    if not me:is_in_combat() then return false end
    if utils.get_health_pct(me) >= (menu.health_potion_hp_pct:get() / 100) then return false end

    for i = 1, #spells.HEALING_POTION_ITEMS do
        local item_id = spells.HEALING_POTION_ITEMS[i]
        if utils.use_consumable_if_ready(me, item_id) then
            utils.log_debug(menu, "Defensive: Health Potion")
            note_cast()
            return true
        end
    end

    return false
end

-- Stoneform
try_stoneform = function(me)
    if not menu.use_stoneform:get_state() or not runtime.stoneform_id then return false end
    if not me:is_in_combat() then return false end
    if utils.get_health_pct(me) >= (menu.stoneform_hp_pct:get() / 100) then return false end
    if is_pending_or_current(runtime.stoneform_id) then return false end
    if utils.has_buff(me, spells.BUFF_STONEFORM) then return false end

    if utils.can_cast_self(runtime.stoneform_id, me) and utils.cast_self_fast(runtime.stoneform_id, me) then
        mark_pending_cast(runtime.stoneform_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Defensive: Stoneform")
        note_cast()
        return true
    end

    return false
end

try_ironshield_potion = function(me, target, mode_policy, hp_pct)
    if not menu.use_ironshield_potion:get_state() then return false end
    if not me:is_in_combat() then return false end
    if utils.has_buff(me, spells.BUFF_IRONSHIELD_POTION) then return false end

    local under_pressure = count_melee_attackers_on_me(me) >= 2
    local elite_tank_window = is_valid_hostile_target(me, target)
        and is_elite_or_boss(target)
        and is_tanking_target(me, target)

    if mode_policy.name == "solo" then
        if hp_pct > SHIELD_BLOCK_SOLO_HP_PCT then
            return false
        end

        if not under_pressure and not elite_tank_window then
            return false
        end
    elseif not under_pressure and not elite_tank_window then
        return false
    end

    for i = 1, #spells.IRONSHIELD_POTION_ITEMS do
        local item_id = spells.IRONSHIELD_POTION_ITEMS[i]
        if utils.use_consumable_if_ready(me, item_id) then
            utils.log_debug(menu, "Defensive: Ironshield Potion")
            note_cast()
            return true
        end
    end

    return false
end

-- Prepull Bloodrage
local function try_prepull_bloodrage(me, target)
    if not menu.use_prepull_bloodrage:get_state() or not runtime.bloodrage_id then return false end
    if me:is_in_combat() then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if utils.has_buff(me, spells.BUFF_BLOODRAGE) then return false end
    if not utils.throttle("simpleprot:prepull_bloodrage", 2.0) then return false end
    if is_pending_or_current(runtime.bloodrage_id) then return false end

    if utils.can_cast_self(runtime.bloodrage_id, me) and utils.cast_self_fast(runtime.bloodrage_id, me) then
        mark_pending_cast(runtime.bloodrage_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Pre-pull Bloodrage")
        notify_cast("simpleprot:cast:bloodrage", "Bloodrage", color.red(220), 0.9)
        note_cast()
        return true
    end

    return false
end

local function reset_burst_state()
    runtime.burst_window_active = false
    runtime.burst_window_started_at = 0
    runtime.burst_attempted = {}
end

-- Burst window management
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
    notify_cast("simpleprot:burst:open", "Burst window open", color.gold(220), 1.1)
end

local function can_use_direct_self_burst(me, spell_id, buff_table)
    return spell_id
        and not utils.has_buff(me, buff_table)
        and not is_pending_or_current(spell_id)
        and utils.can_cast_self(spell_id, me)
end

local function can_stage_recklessness(me, rage)
    if not menu.use_recklessness:get_state() or not runtime.recklessness_id then return false end
    if utils.has_buff(me, spells.BUFF_RECKLESSNESS) then return false end
    if is_pending_or_current(runtime.recklessness_id) then return false end

    if utils.get_current_stance(me) == "berserker" then
        return utils.can_cast_self(runtime.recklessness_id, me)
    end

    if not runtime.berserker_stance_id then return false end
    if core.spell_book.get_spell_cooldown(runtime.recklessness_id) > 0 then return false end
    if not utils.can_cast_self(runtime.berserker_stance_id, me) then return false end

    return utils.can_stance_dance_for_cost(rage, 0, 0, runtime.stance_swap_retention)
end

local function should_open_burst_window(me, target, rage, mode_policy)
    if runtime.burst_window_active then return false end
    if runtime.burst_attempted._completed then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not me:is_in_combat() then return false end
    if not mode_policy.allow_risky_burst and not mode_policy.allow_safe_burst then return false end
    if mode_policy.name ~= "solo" and not is_safe_group_burst_window(me, target) then return false end
    -- Don't open burst until we have enough rage to actually complete stance-dance actions.
    -- Recklessness needs a Berserker Stance swap; opening on 15 rage causes timeout.
    if rage < runtime.stance_swap_retention then return false end

    local burst_opportunity_count = 0

    if mode_policy.allow_risky_burst
        and not runtime.burst_attempted.death_wish
        and menu.use_death_wish:get_state()
        and can_use_direct_self_burst(me, runtime.death_wish_id, spells.BUFF_DEATH_WISH)
    then
        burst_opportunity_count = burst_opportunity_count + 1
    end

    if mode_policy.allow_risky_burst
        and not runtime.burst_attempted.recklessness
        and can_stage_recklessness(me, rage)
    then
        burst_opportunity_count = burst_opportunity_count + 1
    end

    if mode_policy.allow_safe_burst
        and not runtime.burst_attempted.blood_fury
        and menu.use_blood_fury:get_state()
        and can_use_direct_self_burst(me, runtime.blood_fury_id, spells.BUFF_BLOOD_FURY)
    then
        burst_opportunity_count = burst_opportunity_count + 1
    end

    if mode_policy.allow_safe_burst
        and not runtime.burst_attempted.berserking
        and menu.use_berserking:get_state()
        and can_use_direct_self_burst(me, runtime.berserking_id, spells.BUFF_BERSERKING)
    then
        burst_opportunity_count = burst_opportunity_count + 1
    end

    if mode_policy.allow_safe_burst and menu.use_trinkets:get_state() then
        local ready_trinkets = utils.get_self_cast_trinket_ids(me)
        for i = 1, #ready_trinkets do
            local key = "trinket_" .. tostring(ready_trinkets[i].slot_id)
            if not runtime.burst_attempted[key] then
                burst_opportunity_count = burst_opportunity_count + 1
            end
        end
    end

    return burst_opportunity_count >= 2
end

local function all_enabled_burst_actions_attempted(me, rage, mode_policy)
    if mode_policy.allow_risky_burst
        and menu.use_death_wish:get_state()
        and not runtime.burst_attempted.death_wish
        and can_use_direct_self_burst(me, runtime.death_wish_id, spells.BUFF_DEATH_WISH)
    then
        return false
    end

    if mode_policy.allow_risky_burst
        and not runtime.burst_attempted.recklessness
        and can_stage_recklessness(me, rage)
    then
        return false
    end

    if mode_policy.allow_safe_burst
        and menu.use_blood_fury:get_state()
        and not runtime.burst_attempted.blood_fury
        and can_use_direct_self_burst(me, runtime.blood_fury_id, spells.BUFF_BLOOD_FURY)
    then
        return false
    end

    if mode_policy.allow_safe_burst
        and menu.use_berserking:get_state()
        and not runtime.burst_attempted.berserking
        and can_use_direct_self_burst(me, runtime.berserking_id, spells.BUFF_BERSERKING)
    then
        return false
    end

    if mode_policy.allow_safe_burst and menu.use_trinkets:get_state() then
        local ready_trinkets = utils.get_self_cast_trinket_ids(me)
        for i = 1, #ready_trinkets do
            local key = "trinket_" .. tostring(ready_trinkets[i].slot_id)
            if not runtime.burst_attempted[key] then
                return false
            end
        end
    end

    return true
end

-- Burst attempt functions
local function attempt_death_wish(me, mode_policy)
    if not menu.use_death_wish:get_state() or runtime.burst_attempted.death_wish then return false end
    if not mode_policy.allow_risky_burst then return false end

    runtime.burst_attempted.death_wish = true
    if not runtime.death_wish_id
        or utils.has_buff(me, spells.BUFF_DEATH_WISH)
        or is_pending_or_current(runtime.death_wish_id)
    then
        return false
    end

    utils.log_debug(menu, "Burst: Death Wish")
    if utils.can_cast_self(runtime.death_wish_id, me) and utils.cast_self_fast(runtime.death_wish_id, me) then
        mark_pending_cast(runtime.death_wish_id, FAST_PENDING_CAST_TIMEOUT_S)
        note_cast()
        return true
    end
    return false
end

local function attempt_recklessness(me, rage, mode_policy)
    if not menu.use_recklessness:get_state() or runtime.burst_attempted.recklessness then return false end
    if not mode_policy.allow_risky_burst then return false end
    if not runtime.recklessness_id
        or utils.has_buff(me, spells.BUFF_RECKLESSNESS)
        or core.spell_book.get_spell_cooldown(runtime.recklessness_id) > 0
    then
        runtime.burst_attempted.recklessness = true
        return false
    end

    local result = stage_stance_action(me, {
        key = "recklessness",
        action_id = runtime.recklessness_id,
        action_label = "Recklessness",
        required_stance = "berserker",
        required_stance_id = runtime.berserker_stance_id,
        cast_mode = "self",
        use_fast_queue = true,
        notify_id = "simpleprot:cast:recklessness",
        notify_message = "Recklessness",
        notify_color = color.gold(220),
        notify_duration_s = 1.0,
        log_message = "Burst: Recklessness",
    }, rage, 0)
    if result then
        runtime.burst_attempted.recklessness = true
    end
    return result
end

local function attempt_blood_fury(me, mode_policy)
    if not menu.use_blood_fury:get_state() or runtime.burst_attempted.blood_fury then return false end
    if not mode_policy.allow_safe_burst then return false end

    runtime.burst_attempted.blood_fury = true
    if not runtime.blood_fury_id
        or utils.has_buff(me, spells.BUFF_BLOOD_FURY)
        or is_pending_or_current(runtime.blood_fury_id)
    then
        return false
    end

    utils.log_debug(menu, "Burst: Blood Fury")
    if utils.can_cast_self(runtime.blood_fury_id, me) and utils.cast_self_fast(runtime.blood_fury_id, me) then
        mark_pending_cast(runtime.blood_fury_id, FAST_PENDING_CAST_TIMEOUT_S)
        note_cast()
        return true
    end
    return false
end

local function attempt_berserking(me, mode_policy)
    if not menu.use_berserking:get_state() or runtime.burst_attempted.berserking then return false end
    if not mode_policy.allow_safe_burst then return false end

    runtime.burst_attempted.berserking = true
    if not runtime.berserking_id
        or utils.has_buff(me, spells.BUFF_BERSERKING)
        or is_pending_or_current(runtime.berserking_id)
    then
        return false
    end

    utils.log_debug(menu, "Burst: Berserking")
    if utils.can_cast_self(runtime.berserking_id, me) and utils.cast_self_fast(runtime.berserking_id, me) then
        mark_pending_cast(runtime.berserking_id, FAST_PENDING_CAST_TIMEOUT_S)
        note_cast()
        return true
    end
    return false
end

local function attempt_trinket(trinket)
    local key = "trinket_" .. tostring(trinket.slot_id)
    if runtime.burst_attempted[key] then return false end

    runtime.burst_attempted[key] = true
    if utils.use_item_if_ready(trinket.item_id) then
        utils.log_debug(menu, "Burst: Trinket slot " .. tostring(trinket.slot_id))
        note_cast()
        return true
    end

    return false
end

local function attempt_retaliation(me, rage, mode_policy)
    if not menu.use_retaliation:get_state() or runtime.burst_attempted.retaliation then return false end
    if not mode_policy.allow_risky_burst then return false end

    runtime.burst_attempted.retaliation = true
    if not runtime.retaliation_id or utils.has_buff(me, spells.BUFF_RETALIATION) then return false end

    return stage_stance_action(me, {
        key = "retaliation",
        action_id = runtime.retaliation_id,
        action_label = "Retaliation",
        required_stance = "battle",
        required_stance_id = runtime.battle_stance_id,
        cast_mode = "self",
        use_fast_queue = true,
        notify_id = "simpleprot:cast:retaliation",
        notify_message = "Retaliation",
        notify_color = color.gold(220),
        notify_duration_s = 1.0,
        log_message = "Burst: Retaliation",
    }, rage, 0)
end

local function do_burst_lane(me, target, rage, mode_policy)
    if not runtime.burst_window_active and should_open_burst_window(me, target, rage, mode_policy) then
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

    if attempt_death_wish(me, mode_policy) then return true end
    if attempt_recklessness(me, rage, mode_policy) then return true end
    if attempt_retaliation(me, rage, mode_policy) then return true end
    if attempt_blood_fury(me, mode_policy) then return true end
    if attempt_berserking(me, mode_policy) then return true end

    -- Berserker Rage: proactive during burst for extra rage on crits
    if mode_policy.allow_safe_burst
        and menu.use_berserker_rage:get_state()
        and runtime.berserker_rage_id
        and not utils.has_buff(me, spells.BUFF_BERSERKER_RAGE)
        and not is_pending_or_current(runtime.berserker_rage_id)
        and utils.can_cast_self(runtime.berserker_rage_id, me)
    then
        if utils.cast_self_fast(runtime.berserker_rage_id, me) then
            mark_pending_cast(runtime.berserker_rage_id, FAST_PENDING_CAST_TIMEOUT_S)
            utils.log_debug(menu, "Burst: Berserker Rage")
            note_cast()
            return true
        end
    end

    if mode_policy.allow_safe_burst and menu.use_trinkets:get_state() then
        local ready_trinkets = utils.get_self_cast_trinket_ids(me)
        for i = 1, #ready_trinkets do
            if attempt_trinket(ready_trinkets[i]) then
                return true
            end
        end
    end

    if all_enabled_burst_actions_attempted(me, rage, mode_policy) then
        close_burst_window("all actions attempted", true)
    end

    return false
end

-- Single target core lane
local function try_sunder_armor(me, target, target_hp_pct)
    if not menu.use_sunder_armor:get_state() or not runtime.sunder_armor_id then return false end
    if target_hp_pct < EXECUTE_HP_THRESHOLD then return false end
    if not target or not utils.is_melee_target(me, target) then return false end

    if menu.use_devastate:get_state() and runtime.devastate_id then
        return false
    end

    local data = buff_manager:get_debuff_data(target, spells.DEBUFF_SUNDER_ARMOR)
    local stack_count = 0
    if data and data.is_active then
        stack_count = data.count or data.stack_count or data.stacks or 0
    end

    if stack_count >= menu.sunder_max_stacks:get() then
        return false
    end

    if utils.can_cast_melee(runtime.sunder_armor_id, me) and utils.cast_target(runtime.sunder_armor_id, target) then
        utils.log_debug(
            menu,
            "Sunder Armor (" .. tostring(stack_count) .. " -> " .. tostring(stack_count + 1) .. ")"
        )
        notify_cast("simpleprot:cast:sunder_armor", "Sunder Armor", color.orange(220), 0.9)
        note_cast()
        note_core_action()
        return true
    end

    return false
end

local function do_single_target_core_lane(me, target, rage, target_hp_pct)
    -- Shield Block synergy: Shield Slam crits guaranteed under Shield Block - rush it first
    if menu.use_shield_slam:get_state()
        and runtime.shield_slam_id
        and rage >= SHIELD_SLAM_COST
        and utils.has_buff(me, spells.BUFF_SHIELD_BLOCK)
        and utils.can_cast_hostile(runtime.shield_slam_id, me, target)
    then
        if utils.cast_target(runtime.shield_slam_id, target) then
            utils.log_debug(menu, "ST: Shield Slam (Shield Block synergy)")
            note_cast()
            note_core_action()
            return true
        end
    end

    if menu.use_shield_slam:get_state()
        and runtime.shield_slam_id
        and rage >= SHIELD_SLAM_COST
        and utils.can_cast_hostile(runtime.shield_slam_id, me, target)
    then
        if utils.cast_target(runtime.shield_slam_id, target) then
            utils.log_debug(menu, "ST: Shield Slam")
            esp_renderer.on_cast(nil, "Shield Slam", color.red(220))
            note_cast()
            note_core_action()
            return true
        end
    end

    if menu.use_revenge:get_state()
        and runtime.revenge_id
        and rage >= REVENGE_COST
        and core.spell_book.is_usable_spell(runtime.revenge_id)
        and utils.can_cast_melee(runtime.revenge_id, me)
    then
        if utils.cast_target(runtime.revenge_id, target) then
            utils.log_debug(menu, "ST: Revenge")
            esp_renderer.on_cast(nil, "Revenge", color.orange(220))
            note_cast()
            note_core_action()
            return true
        end
    end

    if menu.use_devastate:get_state()
        and runtime.devastate_id
        and rage >= DEVASTATE_COST
        and utils.can_cast_hostile(runtime.devastate_id, me, target)
    then
        if utils.cast_target(runtime.devastate_id, target) then
            utils.log_debug(menu, "ST: Devastate")
            esp_renderer.on_cast(nil, "Devastate", color.yellow(220))
            note_cast()
            note_core_action()
            return true
        end
    end

    if try_sunder_armor(me, target, target_hp_pct) then
        return true
    end

    if menu.use_execute:get_state()
        and target_hp_pct < EXECUTE_HP_THRESHOLD
        and rage >= menu.execute_min_rage:get()
        and runtime.execute_id
        and utils.can_cast_hostile(runtime.execute_id, me, target)
    then
        if utils.cast_target(runtime.execute_id, target) then
            utils.log_debug(menu, "ST: Execute")
            note_cast()
            note_core_action()
            return true
        end
    end

    -- Disarm: solo mitigation vs melee enemies
    if menu.use_disarm:get_state()
        and runtime.disarm_id
        and utils.is_melee_target(me, target)
        and not is_pending_or_current(runtime.disarm_id)
        and utils.can_cast_hostile(runtime.disarm_id, me, target)
    then
        if utils.cast_target(runtime.disarm_id, target) then
            utils.log_debug(menu, "ST: Disarm")
            notify_cast("simpleprot:cast:disarm", "Disarm", color.orange(220), 0.9)
            note_cast()
            return true
        end
    end

    return false
end

-- AoE core lane
local function do_aoe_core_lane(me, target, rage)
    local primary_target = utils.find_best_aoe_target(me, target, AOE_RADIUS) or target

    if try_thunder_clap(me, primary_target, rage) then
        return true
    end

    -- Shield Block synergy: rush Shield Slam for guaranteed crit threat
    if menu.use_shield_slam:get_state()
        and runtime.shield_slam_id
        and rage >= SHIELD_SLAM_COST
        and utils.has_buff(me, spells.BUFF_SHIELD_BLOCK)
        and utils.can_cast_hostile(runtime.shield_slam_id, me, primary_target)
    then
        if utils.cast_target(runtime.shield_slam_id, primary_target) then
            utils.log_debug(menu, "AoE: Shield Slam (Shield Block synergy)")
            note_cast()
            note_core_action()
            return true
        end
    end

    if menu.use_shield_slam:get_state()
        and runtime.shield_slam_id
        and rage >= SHIELD_SLAM_COST
        and utils.can_cast_hostile(runtime.shield_slam_id, me, primary_target)
    then
        if utils.cast_target(runtime.shield_slam_id, primary_target) then
            utils.log_debug(menu, "AoE: Shield Slam")
            note_cast()
            note_core_action()
            return true
        end
    end

    if menu.use_revenge:get_state()
        and runtime.revenge_id
        and rage >= REVENGE_COST
        and core.spell_book.is_usable_spell(runtime.revenge_id)
        and utils.can_cast_melee(runtime.revenge_id, me)
    then
        if utils.cast_target(runtime.revenge_id, primary_target) then
            utils.log_debug(menu, "AoE: Revenge")
            note_cast()
            note_core_action()
            return true
        end
    end

    if menu.use_devastate:get_state()
        and runtime.devastate_id
        and rage >= DEVASTATE_COST
        and utils.can_cast_hostile(runtime.devastate_id, me, primary_target)
    then
        if utils.cast_target(runtime.devastate_id, primary_target) then
            utils.log_debug(menu, "AoE: Devastate")
            note_cast()
            note_core_action()
            return true
        end
    end

    if try_sunder_armor(me, primary_target, utils.get_health_pct(primary_target)) then
        return true
    end

    return false
end

local function do_core_lane(me, target, rage, target_hp_pct, is_aoe)
    if is_aoe then
        return do_aoe_core_lane(me, target, rage)
    end

    return do_single_target_core_lane(me, target, rage, target_hp_pct)
end

local function do_utility_lane(me, target, rage, target_hp_pct, is_aoe, mode_policy)
    -- Demo Shout: use AoE primary target in AoE mode so it picks the right enemy
    local demo_target = is_aoe and (utils.find_best_aoe_target(me, target, AOE_RADIUS) or target) or target
    if try_demo_shout(me, demo_target) then
        return true
    end

    if is_aoe then
        return false
    end

    if try_rend(me, target, rage, target_hp_pct) then
        return true
    end

    if mode_policy.allow_hamstring and try_hamstring_filler(me, target, rage, target_hp_pct) then
        return true
    end

    return false
end

local function try_shield_bash(me, target, context_label)
    if not menu.use_shield_bash:get_state() or not runtime.shield_bash_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if not is_interruptible_caster(target) then return false end
    if is_pending_or_current(runtime.shield_bash_id) then return false end

    if utils.can_cast_hostile(runtime.shield_bash_id, me, target)
        and utils.cast_target_fast(runtime.shield_bash_id, target)
    then
        mark_pending_cast(runtime.shield_bash_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, (context_label or "Recovery") .. ": Shield Bash -> " .. describe_unit(target))
        notify_cast("simpleprot:cast:shield_bash", "Shield Bash", color.orange(220), 1.0)
        note_cast()
        return true
    end

    return false
end

local function try_taunt(me, target, context_label)
    if not menu.use_taunt:get_state() or not runtime.taunt_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if is_pending_or_current(runtime.taunt_id) then return false end
    if get_effective_mode() == "solo" then
        log_recovery_blocked(
            "taunt:solo:" .. describe_unit(target),
            "Recovery: Taunt blocked -> solo mode interrupts-only"
        )
        return false
    end

    local threat = safe_get_threat_situation(target, me)
    local threat_pct = threat and threat.threat_percent or 0
    local victim = target:get_target()
    local victim_valid = victim and victim:is_valid() or false
    local on_me = victim_valid and same_unit(victim, me) or false

    if not victim_valid then
        log_recovery_blocked(
            "taunt:" .. describe_unit(target),
            "Recovery: Taunt blocked -> victim unavailable on "
                .. describe_unit(target)
                .. " (threat="
                .. tostring(threat_pct)
                .. ")"
        )
        return false
    end

    if on_me then
        log_recovery_blocked(
            "taunt:" .. describe_unit(target),
            "Recovery: Taunt blocked -> victim already self on "
                .. describe_unit(target)
                .. " (victim="
                .. describe_unit(victim)
                .. ", threat="
                .. tostring(threat_pct)
                .. ")"
        )
        return false
    end

    if utils.can_cast_hostile(runtime.taunt_id, me, target) and utils.cast_target(runtime.taunt_id, target) then
        mark_pending_cast(runtime.taunt_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(
            menu,
            (context_label or "Recovery")
                .. ": Taunt -> "
                .. describe_unit(target)
                .. " (victim="
                .. describe_unit(victim)
                .. ", threat="
                .. tostring(threat_pct)
                .. ")"
        )
        notify_cast("simpleprot:cast:taunt", "Taunt", color.orange(220), 0.9)
        note_cast()
        return true
    end

    return false
end

local function try_concussion_blow(me, target, context_label)
    if not menu.use_concussion_blow:get_state() or not runtime.concussion_blow_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if not is_dangerous_caster(target) then return false end
    if is_pending_or_current(runtime.concussion_blow_id) then return false end

    if utils.can_cast_hostile(runtime.concussion_blow_id, me, target)
        and utils.cast_target_fast(runtime.concussion_blow_id, target)
    then
        mark_pending_cast(runtime.concussion_blow_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, (context_label or "Recovery") .. ": Concussion Blow -> " .. describe_unit(target))
        notify_cast("simpleprot:cast:concussion_blow", "Concussion Blow", color.orange(220), 0.9)
        note_cast()
        return true
    end

    return false
end

local function try_mocking_blow(me, target, context_label)
    if not menu.use_mocking_blow:get_state() or not runtime.mocking_blow_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if is_pending_or_current(runtime.mocking_blow_id) then return false end
    if get_effective_mode() == "solo" then
        log_recovery_blocked(
            "mocking_blow:solo:" .. describe_unit(target),
            "Recovery: Mocking Blow blocked -> solo mode interrupts-only"
        )
        return false
    end

    local threat = safe_get_threat_situation(target, me)
    local threat_pct = threat and threat.threat_percent or 0
    local victim = target:get_target()
    local victim_valid = victim and victim:is_valid() or false
    local on_me = victim_valid and same_unit(victim, me) or false

    if not victim_valid then
        log_recovery_blocked(
            "mocking_blow:" .. describe_unit(target),
            "Recovery: Mocking Blow blocked -> victim unavailable on "
                .. describe_unit(target)
                .. " (threat="
                .. tostring(threat_pct)
                .. ")"
        )
        return false
    end

    if on_me then
        log_recovery_blocked(
            "mocking_blow:" .. describe_unit(target),
            "Recovery: Mocking Blow blocked -> victim already self on "
                .. describe_unit(target)
                .. " (victim="
                .. describe_unit(victim)
                .. ", threat="
                .. tostring(threat_pct)
                .. ")"
        )
        return false
    end

    if utils.can_cast_hostile(runtime.mocking_blow_id, me, target)
        and utils.cast_target(runtime.mocking_blow_id, target)
    then
        mark_pending_cast(runtime.mocking_blow_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, (context_label or "Recovery") .. ": Mocking Blow -> " .. describe_unit(target))
        notify_cast("simpleprot:cast:mocking_blow", "Mocking Blow", color.orange(220), 0.9)
        note_cast()
        return true
    end

    return false
end

local function try_challenging_shout(me, active_candidates, off_me_count)
    if not menu.use_challenging_shout:get_state() or not runtime.challenging_shout_id then return false end
    if is_pending_or_current(runtime.challenging_shout_id) then return false end
    if get_effective_mode() == "solo" then
        log_recovery_blocked(
            "challenging_shout:solo",
            "Recovery: Challenging Shout blocked -> solo mode interrupts-only"
        )
        return false
    end

    local active_hostiles = utils.enemy_count_in_radius(me, AOE_RADIUS)
    local should_cast = active_candidates >= 2 or (active_hostiles >= 4 and off_me_count >= 2)
    if not should_cast then return false end

    if utils.can_cast_self(runtime.challenging_shout_id, me)
        and utils.cast_self(runtime.challenging_shout_id, me)
    then
        mark_pending_cast(runtime.challenging_shout_id, PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, "Recovery: Challenging Shout")
        notify_cast("simpleprot:cast:challenging_shout", "Challenging Shout", color.orange(220), 1.0)
        note_cast()
        return true
    end

    return false
end

local function try_war_stomp_interrupt(me, target, context_label)
    if not menu.use_war_stomp_interrupt:get_state() or not runtime.war_stomp_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if is_pending_or_current(runtime.war_stomp_id) then return false end

    local is_casting = target:is_casting_spell() and target:is_active_spell_interruptable()
    local is_channeling = target:is_channelling_spell()
    if not is_casting and not is_channeling then
        return false
    end

    if utils.can_cast_self(runtime.war_stomp_id, me) and utils.cast_self_fast(runtime.war_stomp_id, me) then
        mark_pending_cast(runtime.war_stomp_id, FAST_PENDING_CAST_TIMEOUT_S)
        utils.log_debug(menu, (context_label or "Recovery") .. ": War Stomp -> " .. describe_unit(target))
        notify_cast("simpleprot:cast:war_stomp", "War Stomp interrupt", color.orange(220), 1.0)
        note_cast()
        return true
    end

    return false
end

local function try_interrupt_action_on_target(me, target, context_label)
    if try_shield_bash(me, target, context_label) then return true end
    if try_war_stomp_interrupt(me, target, context_label) then return true end
    if try_concussion_blow(me, target, context_label) then return true end
    return false
end

local function try_threat_recovery_action_on_target(me, target, context_label)
    if try_taunt(me, target, context_label) then return true end
    if try_mocking_blow(me, target, context_label) then return true end
    return false
end

local function try_recovery_lane(me, primary_target, recovery, rage, mode_policy)
    if try_interrupt_action_on_target(me, primary_target, "Current Target") then
        return true
    end

    if mode_policy.name == "solo" then
        return false
    end

    if try_threat_recovery_action_on_target(me, primary_target, "Current Target") then
        return true
    end

    if recovery.target and not same_unit(recovery.target, primary_target) then
        if try_interrupt_action_on_target(me, recovery.target, "Recovery Target") then
            return true
        end

        if try_threat_recovery_action_on_target(me, recovery.target, "Recovery Target") then
            return true
        end
    end

    if try_challenging_shout(me, recovery.active_candidates, recovery.off_me_count) then
        return true
    end

    if recovery.target
        and not same_unit(recovery.target, primary_target)
        and mode_policy.allow_peel_intercept
        and recovery.victim
        and not same_unit(recovery.victim, me)
        and is_healer_or_dps_party_member(recovery.victim)
    then
        if try_intercept(me, recovery.target, rage, "Recovery Target") then
            return true
        end
    end

    return false
end

local function resolve_reactive_interrupt_target(me, current_target)
    if is_valid_hostile_target(me, current_target) and is_interruptible_caster(current_target) then
        return current_target
    end

    local mode_policy = get_mode_policy()
    local recovery = select_recovery_target(me, current_target, mode_policy)
    local recovery_target = recovery and recovery.target or nil
    if is_valid_hostile_target(me, recovery_target) and is_interruptible_caster(recovery_target) then
        return recovery_target
    end

    return nil
end

reactive_adapter = {
    spec = "EAXWarriorProtection",
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
                if not is_valid_hostile_target(action_deps.me, interrupt_target) then
                    return false
                end

                if interrupt_manager.should_interrupt(interrupt_target)
                    and interrupt_manager.try_interrupt(action_deps.me, interrupt_target, "warrior", utils)
                then
                    return true
                end

                return try_interrupt_action_on_target(action_deps.me, interrupt_target, "Reactive")
            end,
        },
        anti_overheal = { noop = "unsupported" },
        anti_aggro = {
            handler = function(ctx, action_deps)
                if tank_recovery.should_prioritize_defensive(ctx) then
                    return defensive_manager.try_defensive(action_deps.me, "warrior", utils)
                end

                local recovery_target = action_deps.target or action_deps.current_target
                if not is_valid_hostile_target(action_deps.me, recovery_target) then
                    return false
                end

                if try_threat_recovery_action_on_target(action_deps.me, recovery_target, "Reactive Recovery") then
                    return true
                end

                return try_interrupt_action_on_target(action_deps.me, recovery_target, "Reactive Recovery")
            end,
        },
        throughput_resume = { noop = "unsupported" },
    },
    resolve_target = function(action_id, _, action_deps)
        if action_id == "interrupt_control" then
            return resolve_reactive_interrupt_target(action_deps.me, action_deps.current_target)
        end

        if action_id == "anti_aggro" then
            local recovery = select_recovery_target(action_deps.me, action_deps.current_target, get_mode_policy())
            return recovery and recovery.target or nil
        end

        return nil
    end,
}

local function try_intimidating_shout_keybind(me, target)
    local is_pressed = menu.intimidating_shout_key:get_state()
    local was_pressed = runtime.prev_intimidating_shout_state
    runtime.prev_intimidating_shout_state = is_pressed

    if menu.intimidating_shout_key:get_key_code() == 7 then return false end
    if not is_pressed or was_pressed then return false end
    if not runtime.intimidating_shout_id then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not utils.is_melee_target(me, target) then return false end

    if utils.can_cast_melee(runtime.intimidating_shout_id, me) and utils.cast_target(runtime.intimidating_shout_id, target) then
        utils.log_debug(menu, "Manual: Intimidating Shout")
        notify_cast(
            "simpleprot:cast:intimidating_shout",
            "Manual Intimidating Shout",
            color.yellow(220),
            1.0
        )
        note_cast()
        return true
    end

    return false
end

try_rend = function(me, target, rage, target_hp_pct)
    if not menu.use_rend:get_state() or not runtime.rend_id then return false end
    if target_hp_pct < EXECUTE_HP_THRESHOLD then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not utils.is_melee_target(me, target) then return false end
    if utils.get_debuff_remaining_ms(target, spells.DEBUFF_REND) > 0 then return false end

    if utils.can_cast_melee(runtime.rend_id, me) and utils.cast_target(runtime.rend_id, target) then
        utils.log_debug(menu, "ST: Rend")
        notify_cast("simpleprot:cast:rend", "Rend", color.red(220), 0.9)
        note_cast()
        return true
    end

    return false
end

try_hamstring_filler = function(me, target, rage, target_hp_pct)
    if not menu.use_hamstring:get_state() or not runtime.hamstring_id then return false end
    if target_hp_pct < EXECUTE_HP_THRESHOLD then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if not utils.is_melee_target(me, target) then return false end

    local remaining = utils.get_debuff_remaining_ms(target, spells.DEBUFF_HAMSTRING)
    if remaining >= UTILITY_DEBUFF_REFRESH_MS then
        return false
    end

    return stage_stance_action(me, {
        key = "hamstring",
        action_id = runtime.hamstring_id,
        action_label = "Hamstring",
        required_stance = "battle",
        required_stance_id = runtime.battle_stance_id,
        cast_mode = "target",
        target = target,
        notify_id = "simpleprot:cast:hamstring",
        notify_message = "Hamstring",
        notify_color = color.blue(220),
        notify_duration_s = 0.9,
        log_message = "ST: Hamstring (" .. tostring(remaining) .. "ms)",
    }, rage, HAMSTRING_COST)
end

try_intercept = function(me, target, rage, context_label)
    if not runtime.intercept_id then return false end
    if not me:is_in_combat() then return false end
    if not is_valid_hostile_target(me, target) then return false end
    if same_unit(runtime.auto_intercept_retry_target, target) and core.time() < runtime.auto_intercept_retry_until then
        return false
    end
    if same_unit(runtime.auto_intercept_target, target) then return false end
    if utils.is_melee_target(me, target) then return false end

    local distance = utils.get_distance_to_target(me, target)
    if distance < menu.intercept_min_range:get() then return false end

    local max_range = core.spell_book.get_spell_max_range(runtime.intercept_id)
    if max_range and max_range > 0 then
        local max_distance = max_range + (target:get_bounding_radius() or 0)
        if distance > max_distance then
            return false
        end
    end

    return stage_stance_action(me, {
        key = "intercept",
        action_id = runtime.intercept_id,
        action_label = "Intercept",
        required_stance = "berserker",
        required_stance_id = runtime.berserker_stance_id,
        cast_mode = "target",
        target = target,
        notify_id = "simpleprot:cast:intercept",
        notify_message = "Intercept",
        notify_color = color.cyan(220),
        notify_duration_s = 1.0,
        log_message = (context_label or "Utility")
            .. ": Intercept ("
            .. string.format("%.1f", distance)
            .. " yd)",
    }, rage, INTERCEPT_COST)
end

-- Heroic Strike/Cleave queue
local function do_queue_lane(me, target, rage, is_aoe)
    if not target or not utils.is_melee_target(me, target) then return false end
    if utils.is_spell_already_queued(runtime.heroic_strike_id) or utils.is_spell_already_queued(runtime.cleave_id) then
        return false
    end

    local reserve_rage = 0
    if runtime.shield_slam_id then reserve_rage = math.max(reserve_rage, SHIELD_SLAM_COST) end

    local rage_cap = menu.heroic_strike_rage_cap:get()
    local at_rage_cap = rage >= rage_cap

    local next_swing_ms = utils.get_next_swing_ms(me, 2)
    local in_swing_window = next_swing_ms > 0 and next_swing_ms <= QUEUE_SWING_WINDOW_MS

    -- Only queue if in swing window OR rage is at cap (dump to avoid wasting generation)
    if not in_swing_window and not at_rage_cap then
        return false
    end

    if is_aoe then
        if not menu.use_cleave:get_state() or not runtime.cleave_id then return false end
        if rage < menu.cleave_rage:get() or rage <= (reserve_rage + 5) then return false end

        if utils.can_cast_melee(runtime.cleave_id, me) and utils.cast_target_fast(runtime.cleave_id, target) then
            utils.log_debug(menu, at_rage_cap and "Queue: Cleave (rage cap dump)" or "Queue: Cleave")
            return true
        end
        return false
    end

    if not menu.use_heroic_strike:get_state() or not runtime.heroic_strike_id then return false end
    if rage < menu.heroic_strike_rage:get() or rage <= (reserve_rage + 5) then return false end

    if utils.can_cast_melee(runtime.heroic_strike_id, me) and utils.cast_target_fast(runtime.heroic_strike_id, target) then
        utils.log_debug(menu, at_rage_cap and "Queue: Heroic Strike (rage cap dump)" or "Queue: Heroic Strike")
        return true
    end

    return false
end

-- Main update callback
local function on_spell_cast(data)
    if not data or not data.spell_id then
        return
    end

    local me = core.object_manager.get_local_player()
    if data.caster and (not me or not same_unit(data.caster, me)) then
        return
    end

    local pending = runtime.pending_casts[data.spell_id]
    if not pending then
        return
    end

    if pending.on_confirm then
        pending.on_confirm()
    end

    clear_pending_cast(data.spell_id)
end

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

    refresh_pending_casts()
    local mode_policy = get_mode_policy()

    if menu.debug:get_state() then
        local now_ms = core.game_time()
        if now_ms - runtime.last_mode_debug_at >= MODE_DEBUG_INTERVAL_MS then
            runtime.last_mode_debug_at = now_ms
            

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
        local label = "EAX Warrior Prot] Enabled"
        if toggle_key ~= 7 then
            label = label .. " (" .. key_helper:get_key_name(toggle_key) .. ")"
        end
        label = "[" .. label
        add_cb(label, menu.enabled, "eax_eaxwarriorprotection_enabled_cp")
        if menu.enabled:get_state() then
        if menu.use_cooldowns then
            local cur_wpr_cds = menu.use_cooldowns:get_state()
            local nxt_wpr_cds = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX WPr] Cooldowns", cur_wpr_cds, 0, false, "eax_wpr_cds_cp")
            if nxt_wpr_cds ~= cur_wpr_cds then menu.use_cooldowns:set(nxt_wpr_cds) end
        end
        if menu.use_racial then
            local cur_wpr_racial = menu.use_racial:get_state()
            local nxt_wpr_racial = control_panel_utility:insert_key_checkbox_(
                elements, "[EAX WPr] Use Racial", cur_wpr_racial, 0, false, "eax_wpr_racial_cp")
            if nxt_wpr_racial ~= cur_wpr_racial then menu.use_racial:set(nxt_wpr_racial) end
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

core.log("[EAX Warrior Protection] Mode: " .. mode_policy.name)
        end
    end

    if utils.is_casting_or_channeling(me) then return end

    local primary_target = utils.find_best_target(me)
    
    -- Interrupt
    if primary_target and primary_target:is_valid() and me:can_attack(primary_target) and interrupt_manager.should_interrupt(primary_target) then
        if interrupt_manager.try_interrupt(me, primary_target, "warrior", utils) then
            return
        end
    end

    -- Defensive abilities
    -- Racial abilities
    racial_manager.try_offensive(me)
    racial_manager.try_utility(me, target)
    racial_manager.try_defensive(me)

    if defensive_manager.try_defensive(me, "warrior", utils) then
        return
    end

    ttd_tracker.update(target)
    
    -- Focus Target Priority
    local focus_target = eax_utils.get_focus_target(menu)
    if focus_target and focus_target:is_valid() and me:can_attack(focus_target) then
        primary_target = focus_target
    end
    
    if me:is_in_combat() and not is_valid_hostile_target(me, primary_target) then
        local attacker = find_nearest_attacker(me)
        if attacker then primary_target = attacker end
    end

    local primary_target_valid = is_valid_hostile_target(me, primary_target)

    -- Self-emergency healing
    local self_threshold = eax_utils.get_self_heal_threshold(me, 0.40, menu)
    local my_hp = me:get_health_percentage() / 100
    if my_hp < self_threshold and primary_target_valid then
        if try_last_stand(me, my_hp) then return end
        if try_shield_wall(me, my_hp) then return end
    end

    if not me:is_in_combat() then
        if runtime.burst_window_active or next(runtime.burst_attempted) ~= nil then
            reset_burst_state()
        end
        if runtime.pending_stance_action then
            clear_pending_stance_action("left combat")
        end
        runtime.auto_intercept_target = nil
        runtime.auto_intercept_retry_target = nil
        runtime.auto_intercept_retry_until = 0
        runtime.last_core_action_at = core.time()
        runtime.combat_entered_at = 0
        clear_recovery_target()
    else
        if runtime.combat_entered_at == 0 then
            runtime.combat_entered_at = core.time()
        end
        if not primary_target_valid and runtime.burst_window_active and not runtime.recovery_target then
            close_burst_window("target invalid", false)
        end
    end

    local recovery = {
        target = nil,
        score = 0,
        active_candidates = 0,
        off_me_count = 0,
    }
    if me:is_in_combat() then
        recovery = select_recovery_target(me, primary_target, mode_policy)
    end

    local action_target = recovery.target or primary_target
    local action_target_valid = is_valid_hostile_target(me, action_target)
    if not action_target_valid and primary_target_valid then
        action_target = primary_target
        action_target_valid = true
    end

    if me:is_in_combat() and action_target_valid then
        utils.ensure_melee_auto_attack(me, action_target)
    end

    local panic_target = primary_target_valid and primary_target or action_target
    if try_intimidating_shout_keybind(me, panic_target) then return end

    local rage = utils.get_rage(me)
    if me:is_in_combat() and try_recovery_lane(me, primary_target, recovery, rage, mode_policy) then
        maybe_log_core_starvation(me, action_target, action_target_valid, rage, mode_policy)
        return
    end

    if me:is_in_combat() then
        local hp_pct = utils.get_health_pct(me)
        if do_emergency_defensive_lane(me, action_target, hp_pct) then
            maybe_log_core_starvation(me, action_target, action_target_valid, rage, mode_policy)
            return
        end
    end

    if process_pending_stance_action(me) then return end
    if runtime.pending_stance_action then return end

    if me:is_in_combat() then
        -- Don't return home if we're mid-way through a staged stance action
        -- (e.g. swapped to Berserker for Recklessness but haven't cast it yet).
        if not runtime.pending_stance_action then
            if try_return_home_stance(me) then return end
            local current_stance = utils.get_current_stance(me)
            if current_stance ~= nil and current_stance ~= get_home_stance() then return end
        end
    end

    if not action_target_valid then
        if try_shout(me) then return end
        return
    end

    if not me:is_in_combat() then
        if try_prepull_bloodrage(me, action_target) then return end
    end

    if mode_policy.allow_intercept and menu.use_intercept:get_state() then
        -- In solo mode, don't intercept during the opening 2 seconds of combat
        -- (target closes to melee before the stance swap resolves, causing wasted swaps).
        local combat_age = runtime.combat_entered_at > 0 and (core.time() - runtime.combat_entered_at) or 0
        if combat_age >= 2.0 or not me:is_in_combat() then
            if try_intercept(me, action_target, rage, "Utility") then return end
        end
    end

    if try_shout(me) then return end

    rage = utils.get_rage(me)
    if try_bloodrage(me, rage) then return end

    local target_hp_pct = utils.get_health_pct(action_target)
    local aoe_count = utils.enemy_count_in_radius(me, AOE_RADIUS)
    local is_aoe = aoe_count >= menu.aoe_enemy_count:get()
    local gcd_lane_ready = is_gcd_lane_ready()
    if mode_policy.name == "solo" then
        if gcd_lane_ready and do_core_lane(me, action_target, rage, target_hp_pct, is_aoe) then
            return
        end

        if gcd_lane_ready and do_utility_lane(me, action_target, rage, target_hp_pct, is_aoe, mode_policy) then
            return
        end

        if do_mitigation_lane(me, action_target, rage, mode_policy, utils.get_health_pct(me)) then
            maybe_log_core_starvation(me, action_target, action_target_valid, rage, mode_policy)
            return
        end
    else
        if do_mitigation_lane(me, action_target, rage, mode_policy, utils.get_health_pct(me)) then
            maybe_log_core_starvation(me, action_target, action_target_valid, rage, mode_policy)
            return
        end

        if gcd_lane_ready and do_core_lane(me, action_target, rage, target_hp_pct, is_aoe) then
            return
        end

        if gcd_lane_ready and do_utility_lane(me, action_target, rage, target_hp_pct, is_aoe, mode_policy) then
            return
        end
    end

    if do_burst_lane(me, action_target, rage, mode_policy) then
        maybe_log_core_starvation(me, action_target, action_target_valid, rage, mode_policy)
        return
    end

    if do_queue_lane(me, action_target, rage, is_aoe) then
        maybe_log_core_starvation(me, action_target, action_target_valid, rage, mode_policy)
        return
    end

    maybe_log_core_starvation(me, action_target, action_target_valid, rage, mode_policy)
end

-- Control panel callback
local function on_control_panel()
    local elements = {}
    local toggle_key_code = menu.toggle_key:get_key_code()
    local display_name = "[EAX Warrior Protection] Enabled"
    if toggle_key_code ~= 7 then
        display_name = "[EAX Warrior Protection] Enabled (" .. key_helper:get_key_name(toggle_key_code) .. ")"
    end

    local current_state = menu.enabled:get_state()
    local new_state = control_panel_utility:insert_key_checkbox_(
        elements,
        display_name,
        current_state,
        0,
        false,
        "simpleprot_enabled_control_panel"
    )

    if new_state ~= current_state then
        menu.enabled:set(new_state)
    end

    return elements
end

-- Register callbacks

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
core.register_on_spell_cast_callback(on_spell_cast)

-- -- Space theme: create menu window and inject into menu ---------------------
local _vec2 = require("common/geometry/vector_2")
local _space_win = core.menu.window("eaxwarriorprotection_space_win")
_space_win:set_initial_size(_vec2.new(460, 580))
_space_win:set_next_window_min_size(_vec2.new(320, 300))
_space_win:set_next_window_padding(_vec2.new(10, 8))
menu.set_window(_space_win)
-- -----------------------------------------------------------------------------
core.register_on_render_menu_callback(menu.render)
core.register_on_render_control_panel_callback(on_control_panel)

-- Public interface
local function cleanup()
end

return { cleanup = cleanup, state = runtime }
