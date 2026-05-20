-- Druid Cat priority list for TBC melee DPS.

local NS = _G.EaxRotations
if not NS then return nil end

local BASE_SPELLS = NS.DruidSpells or {}
local SPELLS = BASE_SPELLS

local POUNCE = BASE_SPELLS.Pounce or (NS.spell_action and NS.spell_action({ 27006, 9827, 9005 }, "Pounce"))
local MAIM = BASE_SPELLS.Maim or (NS.spell_action and NS.spell_action({ 22570 }, "Maim"))
local TRACK_HUMANOIDS = BASE_SPELLS.TrackHumanoids or (NS.spell_action and NS.spell_action({ 5225 }, "TrackHumanoids"))

local STANCE_CAT = 3
local ENERGY_CAP = 100
local ENERGY_TICK_INTERVAL = 2.0
local ENERGY_PER_TICK = 20
local POWERSHIFT_GAIN_FUROR = 40
local POWERSHIFT_GAIN_WOLFSHEAD = 60
local POWERSHIFT_IGNORE_WINDOW = 0.8
local POWERSHIFT_MIN_MANA = 8
local POWERSHIFT_SAFE_CP = 4
local SHRED_COST = 42
local MANGLE_COST = 40
local RAKE_COST = 35
local RIP_COST = 30
local BITE_COST = 35
local RAVAGE_COST = 60
local POUNCE_COST = 50
local MAIM_COST = 35
local TIGERS_FURY_ENERGY = 30
local RIP_REFRESH_WINDOW = 2.0
local RAKE_REFRESH_WINDOW = 3.0
local MANGLE_REFRESH_WINDOW = 3.0
local FAERIE_FIRE_REFRESH = 6.0
local MIN_RIP_TTD = 10.0
local MIN_RAKE_TTD = 6.0
local EXECUTE_HP = 25
local HARD_EXECUTE_HP = 20
local MELEE_RANGE = 5.0
local DASH_RANGE = 12.0
local TRAVEL_FORM_RANGE = 25.0
local LONG_TTD = 20.0
local SHORT_TTD = 8.0
local AP_UPGRADE_RATIO = 1.08
local STRONG_AP_UPGRADE_RATIO = 1.15
local HIGH_AP_UPGRADE_RATIO = 1.05

local RIP_DEBUFF = { 27008, 1079 }
local RAKE_DEBUFF = { 27003, 9904, 1824, 1823, 1822 }
local MANGLE_DEBUFF = { 33876, 33983, 33982, 33878, 33986, 33987 }
local FAERIE_FIRE_DEBUFF = { 27011, 17392, 17391, 17390, 16857, 26993, 9907, 9749, 778, 770 }
local PROWL_BUFF = { 9913, 6783, 5215 }
local POUNCE_DEBUFF = { 27006, 9827, 9005 }
local MAIM_DEBUFF = { 22570 }
local OMEN_OF_CLARITY_BUFF = { 16864 }
local TIGERS_FURY_BUFF = { 9846, 9845, 6793, 5217 }
local DASH_BUFF = { 33357, 9821, 1850 }
local BARKSKIN_BUFF = { 22812 }
local TRACK_HUMANOIDS_BUFF = { 5225 }
local WOLFSHEAD_BUFF = { 29940, 17770 }
local STEALTH_PREVENT_TYPES = { ["Humanoid"] = true, ["Beast"] = true }

local cat_state = {
    now = 0,
    now_ms = 0,
    me = nil,
    target = nil,
    settings = nil,
    hp = 100,
    mana_pct = 100,
    energy = 0,
    projected_energy = 0,
    combo_points = 0,
    enemy_count = 1,
    target_hp = 100,
    target_ttd = 0,
    target_range = 0,
    in_combat = false,
    is_pvp = false,
    is_player_target = false,
    is_stealthed = false,
    is_cat = false,
    is_behind = false,
    clearcasting = false,
    has_tigers_fury = false,
    has_dash = false,
    has_barkskin = false,
    has_track_humanoids = false,
    has_wolfshead = false,
    has_bloodlust = false,
    rip_remains = 0,
    rake_remains = 0,
    mangle_remains = 0,
    faerie_fire_remains = 0,
    pounce_remains = 0,
    maim_remains = 0,
    rip_ap = 0,
    rake_ap = 0,
    attack_power = 0,
    next_tick_in = ENERGY_TICK_INTERVAL,
    last_energy = 0,
    last_tick_time = 0,
    last_shift_time = -100,
    tick_confident = false,
    pooling = false,
    should_powershift = false,
    should_pool_for_rip = false,
    should_pool_for_shred = false,
    should_execute = false,
    should_tab_rake = false,
    should_aoe = false,
}

local snapshot_state = {
    rip_target = nil,
    rake_target = nil,
    rip_ap = 0,
    rake_ap = 0,
    rip_cast_time = 0,
    rake_cast_time = 0,
}

local function safe_method(object, method_name, fallback)
    if not object then return fallback end
    local method = object[method_name]
    if type(method) ~= "function" then return fallback end
    local ok, value = pcall(method, object)
    if not ok or value == nil then return fallback end
    return value
end

local function safe_method_arg(object, method_name, arg, fallback)
    if not object then return fallback end
    local method = object[method_name]
    if type(method) ~= "function" then return fallback end
    local ok, value = pcall(method, object, arg)
    if not ok or value == nil then return fallback end
    return value
end

local function setting_bool(settings, key, default)
    if not settings or settings[key] == nil then return default end
    return settings[key] == true
end

local function setting_number(settings, key, default)
    local value = settings and settings[key]
    if type(value) ~= "number" then return default end
    return value
end

local function spell_exists(spell)
    if spell == nil then return false end
    if not NS.spell_exists then return true end
    return NS.spell_exists(spell)
end

local function spell_ready(spell, target, opts)
    if not spell_exists(spell) then return false end
    return NS.spell_ready and NS.spell_ready(spell, target, opts) or false
end

local function buff_up(unit, buff)
    return unit ~= nil and NS.buff_up and NS.buff_up(unit, buff) or false
end

local function debuff_up(unit, debuff)
    return unit ~= nil and NS.debuff_up and NS.debuff_up(unit, debuff) or false
end

local function debuff_remains(unit, debuff)
    return unit ~= nil and NS.debuff_remains and NS.debuff_remains(unit, debuff) or 0
end

local function get_attack_power(context, me)
    if context and type(context.attack_power) == "number" then return context.attack_power end
    if NS.attack_power then return NS.attack_power() or 0 end
    if NS.get_attack_power then return NS.get_attack_power() or 0 end
    local ap = safe_method(me, "get_attack_power", nil)
    if type(ap) == "number" then return ap end
    return 0
end

---Check if Wolfshead Helm (8345) is equipped via item-based detection.
---Falls back to checking me:get_equipped_item for the head slot (inventory slot 1).
local function has_wolfshead_equipped(me)
    if not me then
        if NS.GetPlayer then me = NS.GetPlayer() end
        if not me then return false end
    end
    if type(me.get_equipped_item) ~= "function" then return false end
    local ok, item_id = pcall(function() return me:get_equipped_item(1) end)
    return ok and type(item_id) == "number" and item_id == WOLFSHEAD_HELM_ID
end

local function get_combo_points(context, target)
    if type(context.combo_points) == "number" then return context.combo_points end
    if type(context.cp) == "number" then return context.cp end
    if NS.combo_points then return NS.combo_points(target) or 0 end
    if NS.get_combo_points then return NS.get_combo_points(target) or 0 end
    return 0
end

local function get_energy(context)
    if type(context.energy) == "number" then return context.energy end
    local me = context.me or (NS.GetPlayer and NS.GetPlayer())
    local from_unit = safe_method_arg(me, "get_power", NS.POWER_ENERGY or 3, nil)
    if type(from_unit) == "number" then return from_unit end
    if NS.power_current and NS.POWER_ENERGY then return NS.power_current(NS.POWER_ENERGY) or 0 end
    if NS.energy then return NS.energy() or 0 end
    return 0
end

local function get_mana_pct(context)
    if type(context.mana_pct) == "number" then return context.mana_pct end
    if NS.power_pct and NS.POWER_MANA then return NS.power_pct(NS.POWER_MANA) or 100 end
    return 100
end

local function get_now()
    return NS.time_now and NS.time_now() or 0
end

local function get_now_ms()
    if NS.game_time_ms then return NS.game_time_ms() end
    return get_now() * 1000
end

local function is_target_player(target, context)
    if context and context.is_target_player ~= nil then return context.is_target_player == true end
    if context and context.target_is_player ~= nil then return context.target_is_player == true end
    return safe_method(target, "is_player", false) == true
end

local function get_target_range(me, target, context)
    if type(context.target_range) == "number" then return context.target_range end
    if type(context.range) == "number" then return context.range end
    return safe_method_arg(me, "get_distance", target, 0)
end

local function is_behind_target(target, context, settings)
    if setting_bool(settings, "cat_shred_positional", true) == false then return true end
    if context and context.is_behind ~= nil then return context.is_behind == true end
    if NS.is_behind_target then return NS.is_behind_target(target) == true end
    return false
end

local function estimate_next_tick(state)
    if not state.tick_confident or state.last_tick_time <= 0 then return ENERGY_TICK_INTERVAL end
    local elapsed = state.now - state.last_tick_time
    if elapsed < 0 or elapsed > ENERGY_TICK_INTERVAL * 3 then return ENERGY_TICK_INTERVAL end
    local ticks = math.floor(elapsed / ENERGY_TICK_INTERVAL)
    local since_last = elapsed - (ticks * ENERGY_TICK_INTERVAL)
    return math.max(0, ENERGY_TICK_INTERVAL - since_last)
end

local function update_energy_tick(state)
    local delta = state.energy - state.last_energy
    if delta > 0 and delta <= 25 and (state.now - state.last_shift_time) > POWERSHIFT_IGNORE_WINDOW then
        state.last_tick_time = state.now
        state.tick_confident = true
    end
    state.last_energy = state.energy
    state.next_tick_in = estimate_next_tick(state)
    state.projected_energy = math.min(ENERGY_CAP, state.energy + ENERGY_PER_TICK)
end

local function should_wait_for_tick(state, required_energy)
    if state.energy >= required_energy then return false end
    if state.next_tick_in > 0.45 then return false end
    return state.energy + ENERGY_PER_TICK >= required_energy
end

local function should_snapshot_upgrade(current_ap, snapshotted_ap, remains, refresh_window, ratio)
    if remains <= 0 then return true end
    if remains <= refresh_window then return true end
    if snapshotted_ap <= 0 then return false end
    return current_ap >= snapshotted_ap * ratio and remains <= refresh_window + 1.5
end

local function target_lives(state, seconds)
    if state.target_ttd <= 0 then return true end
    return state.target_ttd >= seconds
end

local function prevent_cp_waste(state, added_cp)
    return state.combo_points + (added_cp or 1) <= 5
end

local function has_valid_target(context)
    return context.has_valid_enemy_target ~= false and context.target ~= nil
end

local function base_matches(context, action)
    if action.spell == nil and NS.spell_exists then return false end
    if action.matches then return action.matches(context, action) end
    return NS.action_matches(context, action)
end

local function execute_action(context, action)
    return NS.action_execute(context, action, "[CAT]")
end

local function record_shift(state)
    state.last_shift_time = state.now
    state.last_energy = 0
end

local function record_bleed_snapshot(action_name, state)
    if action_name == "Rip" or action_name == "RipSnapshot" or action_name == "RipExecute" then
        snapshot_state.rip_target = state.target
        snapshot_state.rip_ap = state.attack_power
        snapshot_state.rip_cast_time = state.now
    elseif action_name == "Rake" or action_name == "RakeSnapshot" or action_name == "RakeTab" then
        snapshot_state.rake_target = state.target
        snapshot_state.rake_ap = state.attack_power
        snapshot_state.rake_cast_time = state.now
    end
end

local function cast_and_record(context, action)
    local state = build_state(context)
    local ok = execute_action(context, action)
    if ok then
        if action.name == "Powershift" or action.name == "EmergencyPowershift" then record_shift(state) end
        record_bleed_snapshot(action.name, state)
    end
    return ok
end

function build_state(context)
    local state = cat_state
    local settings = context.settings or {}
    local me = context.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context.target
    local has_energy_context = context.energy ~= nil or context.me ~= nil or NS.power_current ~= nil or NS.energy ~= nil

    state.now = get_now()
    state.now_ms = get_now_ms()
    state.me = me
    state.target = target
    state.settings = settings
    state.hp = context.hp or (NS.health_pct and NS.health_pct(me)) or 100
    state.mana_pct = get_mana_pct(context)
    state.energy = has_energy_context and get_energy(context) or ENERGY_CAP
    state.combo_points = get_combo_points(context, target)
    state.enemy_count = context.enemy_count or 1
    state.target_hp = context.target_hp or (NS.health_pct and NS.health_pct(target)) or 100
    state.target_ttd = context.ttd or context.target_ttd or 0
    state.target_range = get_target_range(me, target, context)
    state.in_combat = context.in_combat == true
    state.is_pvp = context.is_pvp == true or (settings and settings.pvp_mode == true)
    state.is_player_target = is_target_player(target, context)
    state.is_stealthed = context.is_stealthed == true or buff_up(me, PROWL_BUFF)
    state.is_cat = NS.has_form and NS.has_form("cat") or context.stance == STANCE_CAT
    state.is_behind = is_behind_target(target, context, settings)
    state.clearcasting = buff_up(me, OMEN_OF_CLARITY_BUFF)
    state.has_tigers_fury = buff_up(me, TIGERS_FURY_BUFF)
    state.has_dash = buff_up(me, DASH_BUFF)
    state.has_barkskin = buff_up(me, BARKSKIN_BUFF)
    state.has_track_humanoids = buff_up(me, TRACK_HUMANOIDS_BUFF)
    state.has_wolfshead = has_wolfshead_equipped(me) or buff_up(me, WOLFSHEAD_BUFF) or setting_bool(settings, "cat_wolfshead_helm", false)
    state.has_bloodlust = buff_up(me, BLOODLUST_BUFFS)
    state.rip_remains = debuff_remains(target, RIP_DEBUFF)
    state.rake_remains = debuff_remains(target, RAKE_DEBUFF)
    state.mangle_remains = debuff_remains(target, MANGLE_DEBUFF)
    state.faerie_fire_remains = debuff_remains(target, FAERIE_FIRE_DEBUFF)
    state.pounce_remains = debuff_remains(target, POUNCE_DEBUFF)
    state.maim_remains = debuff_remains(target, MAIM_DEBUFF)
    state.attack_power = get_attack_power(context, me)
    if snapshot_state.rip_target ~= target or state.rip_remains <= 0 then snapshot_state.rip_ap = 0 end
    if snapshot_state.rake_target ~= target or state.rake_remains <= 0 then snapshot_state.rake_ap = 0 end
    state.rip_ap = snapshot_state.rip_ap
    state.rake_ap = snapshot_state.rake_ap
    state.has_high_ap_window = state.has_bloodlust or (state.attack_power > 0 and state.rip_ap > 0 and state.attack_power >= state.rip_ap * AP_UPGRADE_RATIO) or (state.attack_power > 0 and state.rake_ap > 0 and state.attack_power >= state.rake_ap * AP_UPGRADE_RATIO)
    update_energy_tick(state)
    state.should_execute = state.target_hp <= setting_number(settings, "cat_execute_hp", EXECUTE_HP)
    state.should_aoe = state.enemy_count >= (settings.aoe_threshold or 3)
    state.should_tab_rake = state.enemy_count >= 2 and state.enemy_count <= 3
    state.should_pool_for_rip = state.combo_points >= setting_number(settings, "cat_rip_cp", 5) and state.energy < RIP_COST and target_lives(state, MIN_RIP_TTD)
    state.should_pool_for_shred = state.combo_points < 5 and state.energy < SHRED_COST and state.energy + ENERGY_PER_TICK >= SHRED_COST
    state.pooling = state.should_pool_for_rip or state.should_pool_for_shred
    state.should_powershift = false
    if setting_bool(settings, "cat_powershift_enabled", true) and state.is_cat and state.in_combat then
        local shift_energy = setting_number(settings, "cat_powershift_energy", 20)
        local shift_gain = state.has_wolfshead and POWERSHIFT_GAIN_WOLFSHEAD or POWERSHIFT_GAIN_FUROR
        local useful_after = state.energy + shift_gain >= math.min(ENERGY_CAP, SHRED_COST)
        state.should_powershift = state.energy <= shift_energy and state.combo_points <= POWERSHIFT_SAFE_CP and state.mana_pct >= POWERSHIFT_MIN_MANA and useful_after
    end
    return state
end

local function cat_form_matches(context, action)
    if NS.has_form and NS.has_form("cat") then return false end
    return NS.action_matches(context, action)
end

local function prowl_matches(context, action)
    local state = build_state(context)
    if state.in_combat then return false end
    if state.is_stealthed then return false end
    if state.target and state.target_range > 0 and state.target_range > 18 then return false end
    return NS.action_matches(context, action)
end

local function track_humanoids_matches(context, action)
    local state = build_state(context)
    if state.in_combat then return false end
    if state.has_track_humanoids then return false end
    if not state.is_pvp and not state.is_player_target then return false end
    return NS.action_matches(context, action)
end

local function pounce_matches(context, action)
    local state = build_state(context)
    if not state.is_stealthed then return false end
    if not state.is_pvp and not state.is_player_target then return false end
    if state.energy < POUNCE_COST then return false end
    return NS.action_matches(context, action)
end

local function ravage_matches(context, action)
    local state = build_state(context)
    if not state.is_stealthed then return false end
    if not state.is_behind then return false end
    if state.energy < RAVAGE_COST then return false end
    if not prevent_cp_waste(state, 1) then return false end
    return NS.action_matches(context, action)
end

local function stealth_shred_matches(context, action)
    local state = build_state(context)
    if not state.is_stealthed then return false end
    if state.mangle_remains <= 0 then return false end
    if not state.is_behind then return false end
    return NS.action_matches(context, action)
end

local function stealth_mangle_matches(context, action)
    local state = build_state(context)
    if not state.is_stealthed then return false end
    if state.energy < MANGLE_COST then return false end
    return NS.action_matches(context, action)
end

local function barkskin_matches(context, action)
    local state = build_state(context)
    local threshold = setting_number(state.settings, "cat_barkskin_hp", 85)
    if state.hp > threshold then return false end
    if state.has_barkskin then return false end
    return NS.action_matches(context, action)
end

local function dash_matches(context, action)
    local state = build_state(context)
    if state.has_dash then return false end
    if not state.target or state.target_range < DASH_RANGE then return false end
    if not state.is_pvp and state.target_range < TRAVEL_FORM_RANGE then return false end
    return NS.action_matches(context, action)
end

local function travel_form_matches(context, action)
    local state = build_state(context)
    if state.in_combat then return false end
    if not state.target or state.target_range < TRAVEL_FORM_RANGE then return false end
    return NS.action_matches(context, action)
end

local function faerie_fire_matches(context, action)
    local state = build_state(context)
    if not state.target then return false end
    if state.faerie_fire_remains > MANGLE_REFRESH_WINDOW then return false end
    if state.target_ttd > 0 and state.target_ttd < 10 then return false end
    if state.is_pvp and state.is_player_target then return NS.action_matches(context, action) end
    return target_lives(state, LONG_TTD) and NS.action_matches(context, action)
end

local function faerie_fire_stealth_matches(context, action)
    local state = build_state(context)
    if not state.is_pvp and not state.is_player_target then return false end
    if state.faerie_fire_remains > FAERIE_FIRE_REFRESH then return false end
    local creature_type = safe_method(state.target, "get_creature_type", nil)
    if creature_type and not STEALTH_PREVENT_TYPES[creature_type] then return false end
    return NS.action_matches(context, action)
end

local function mangle_debuff_matches(context, action)
    local state = build_state(context)
    if state.mangle_remains > MANGLE_REFRESH_WINDOW then return false end
    if should_wait_for_tick(state, MANGLE_COST) then return false end
    return NS.action_matches(context, action)
end

local function rip_matches(context, action)
    local state = build_state(context)
    local required_cp = setting_number(state.settings, "cat_rip_cp", 5)
    if not state.target then return false end
    if context.combo_points ~= nil and state.combo_points < required_cp then return false end
    if not target_lives(state, MIN_RIP_TTD) then return false end
    if should_wait_for_tick(state, RIP_COST) then return false end
    if not should_snapshot_upgrade(state.attack_power, state.rip_ap, state.rip_remains, RIP_REFRESH_WINDOW, AP_UPGRADE_RATIO) then return false end
    return NS.action_matches(context, action)
end

local function rip_snapshot_matches(context, action)
    local state = build_state(context)
    local required_cp = setting_number(state.settings, "cat_rip_cp", 5)
    if state.combo_points < required_cp then return false end
    if state.rip_remains <= RIP_REFRESH_WINDOW then return false end
    if not target_lives(state, MIN_RIP_TTD) then return false end
    if state.rip_ap <= 0 then return false end
    -- Use lower threshold during bloodlust/high-AP windows to catch the snapshot opportunity
    local ratio = state.has_high_ap_window and HIGH_AP_UPGRADE_RATIO or STRONG_AP_UPGRADE_RATIO
    if state.attack_power < state.rip_ap * ratio then return false end
    return NS.action_matches(context, action)
end

local function bite_matches(context, action)
    local state = build_state(context)
    local required_cp = setting_number(state.settings, "cat_ferocious_bite_cp", 5)
    if state.combo_points < required_cp then return false end
    if state.rip_remains <= RIP_REFRESH_WINDOW and target_lives(state, MIN_RIP_TTD) then return false end
    if not state.should_execute and state.target_ttd > SHORT_TTD then return false end
    if should_wait_for_tick(state, BITE_COST) then return false end
    return NS.action_matches(context, action)
end

local function emergency_bite_matches(context, action)
    local state = build_state(context)
    if state.combo_points < 3 then return false end
    if state.target_ttd <= 0 or state.target_ttd > 4 then return false end
    return NS.action_matches(context, action)
end

local function maim_interrupt_matches(context, action)
    local state = build_state(context)
    if state.combo_points < 1 then return false end
    if state.maim_remains > 0 then return false end
    if not state.is_pvp and not state.is_player_target then return false end
    local casting = safe_method(state.target, "is_casting", false) or safe_method(state.target, "is_channeling", false)
    if not casting then return false end
    return NS.action_matches(context, action)
end

local function maim_control_matches(context, action)
    local state = build_state(context)
    if state.combo_points < 3 then return false end
    if state.maim_remains > 0 then return false end
    if not state.is_pvp and not state.is_player_target then return false end
    if state.target_hp <= HARD_EXECUTE_HP then return false end
    return NS.action_matches(context, action)
end

local function rake_matches(context, action)
    local state = build_state(context)
    if not state.target then return false end
    if not target_lives(state, MIN_RAKE_TTD) then return false end
    if context.combo_points ~= nil and state.combo_points >= 5 then return false end
    if should_wait_for_tick(state, RAKE_COST) then return false end
    if not should_snapshot_upgrade(state.attack_power, state.rake_ap, state.rake_remains, RAKE_REFRESH_WINDOW, AP_UPGRADE_RATIO) then return false end
    return NS.action_matches(context, action)
end

local function rake_snapshot_matches(context, action)
    local state = build_state(context)
    if state.rake_remains <= RAKE_REFRESH_WINDOW then return false end
    if state.rake_ap <= 0 then return false end
    if state.combo_points >= 5 then return false end
    -- Use lower threshold during bloodlust/high-AP windows to catch the snapshot opportunity
    local ratio = state.has_high_ap_window and HIGH_AP_UPGRADE_RATIO or STRONG_AP_UPGRADE_RATIO
    if state.attack_power < state.rake_ap * ratio then return false end
    return NS.action_matches(context, action)
end

local function rake_tab_matches(context, action)
    local state = build_state(context)
    if not state.should_tab_rake then return false end
    if state.combo_points >= 5 then return false end
    return rake_matches(context, action)
end

local function clearcasting_shred_matches(context, action)
    local state = build_state(context)
    if not state.clearcasting then return false end
    if state.target and not state.is_behind then return false end
    if context.combo_points ~= nil and state.combo_points >= 5 then return false end
    action.min_energy = CLEARCASTING_COST_FLOOR
    return NS.action_matches(context, action)
end

local function shred_matches(context, action)
    local state = build_state(context)
    if state.combo_points >= 5 then return false end
    if state.pooling and state.energy < SHRED_COST then return false end
    if not state.is_behind then return false end
    if state.mangle_remains <= MANGLE_REFRESH_WINDOW and target_lives(state, MIN_RAKE_TTD) then return false end
    if should_wait_for_tick(state, SHRED_COST) then return false end
    return NS.action_matches(context, action)
end

local function mangle_filler_matches(context, action)
    local state = build_state(context)
    if state.combo_points >= 5 then return false end
    if state.is_behind and spell_ready(SPELLS.Shred, state.target, nil) and state.energy >= SHRED_COST then return false end
    if should_wait_for_tick(state, MANGLE_COST) then return false end
    return NS.action_matches(context, action)
end

local function claw_matches(context, action)
    local state = build_state(context)
    if state.combo_points >= 5 then return false end
    if spell_exists(SPELLS.MangleCat) then return false end
    if should_wait_for_tick(state, 45) then return false end
    return NS.action_matches(context, action)
end

local function tigers_fury_matches(context, action)
    local state = build_state(context)
    if not state.me and not NS.GetPlayer then return false end
    if state.has_tigers_fury then return false end
    if state.target_ttd > 0 and state.target_ttd < SHORT_TTD then return false end
    local max_energy = safe_method_arg(state.me, "get_max_power", NS.POWER_ENERGY or 3, ENERGY_CAP) or ENERGY_CAP
    local fury_gain = TIGERS_FURY_ENERGY
    if not NS.spell_exists then fury_gain = POWERSHIFT_GAIN_WOLFSHEAD end
    if state.energy + fury_gain > max_energy then return false end
    if state.energy > ENERGY_CAP - TIGERS_FURY_ENERGY - 5 and state.next_tick_in <= 0.6 then return false end
    if state.combo_points >= 5 and state.energy >= RIP_COST then return false end
    return NS.action_matches(context, action)
end

local function powershift_matches(context, action)
    local state = build_state(context)
    if not state.should_powershift then return false end
    if state.clearcasting then return false end
    if state.next_tick_in <= 0.35 and state.energy + ENERGY_PER_TICK <= ENERGY_CAP then return false end
    if state.combo_points >= 5 and state.energy >= RIP_COST then return false end
    return NS.action_matches(context, action)
end

local function emergency_powershift_matches(context, action)
    local state = build_state(context)
    if not setting_bool(state.settings, "cat_powershift_enabled", true) then return false end
    if not state.is_cat or not state.in_combat then return false end
    if state.energy > 10 then return false end
    if state.mana_pct < POWERSHIFT_MIN_MANA then return false end
    if state.combo_points >= 5 then return false end
    if state.next_tick_in <= 0.2 then return false end
    return NS.action_matches(context, action)
end

local function pool_for_builder_matches(context)
    local state = build_state(context)
    if state.combo_points >= 5 then return false end
    if state.energy >= MANGLE_COST then return false end
    if state.next_tick_in > 0.6 then return false end
    return true
end

local function wait_execute(context)
    local state = build_state(context)
    if not state.should_execute then return false end
    if state.combo_points < setting_number(state.settings, "cat_ferocious_bite_cp", 5) then return false end
    if state.energy >= BITE_COST then return false end
    return true
end

local function wait_execute_execute()
    return false
end

local ACTIONS = {
    { name = "CatForm", spell = SPELLS.CatForm, target = "self", kind = "form", form = "cat", requires_target = false, matches = cat_form_matches },
    { name = "TravelForm", spell = SPELLS.TravelForm, target = "self", kind = "form", form = "travel", requires_target = false, matches = travel_form_matches },
    { name = "TrackHumanoids", spell = TRACK_HUMANOIDS, target = "self", kind = "buff", buff = TRACK_HUMANOIDS_BUFF, required_form = "cat", requires_target = false, matches = track_humanoids_matches },
    { name = "Prowl", spell = SPELLS.Prowl, target = "self", kind = "buff", buff = PROWL_BUFF, ooc = true, required_form = "cat", requires_target = false, matches = prowl_matches },

    { name = "Barkskin", spell = SPELLS.Barkskin, target = "self", required_form = "cat", requires_target = false, matches = barkskin_matches },

    { name = "PounceOpener", spell = POUNCE, requires_buff = PROWL_BUFF, required_form = "cat", min_energy = POUNCE_COST, matches = pounce_matches },
    { name = "RavageOpener", spell = SPELLS.Ravage, requires_buff = PROWL_BUFF, required_form = "cat", requires_behind = true, min_energy = RAVAGE_COST, matches = ravage_matches },
    { name = "StealthShred", spell = SPELLS.Shred, requires_buff = PROWL_BUFF, required_form = "cat", requires_behind = true, min_energy = SHRED_COST, matches = stealth_shred_matches },
    { name = "StealthMangle", spell = SPELLS.MangleCat, requires_buff = PROWL_BUFF, required_form = "cat", min_energy = MANGLE_COST, matches = stealth_mangle_matches },

    { name = "Dash", spell = SPELLS.Dash, target = "self", required_form = "cat", requires_target = false, matches = dash_matches },
    { name = "FeralChargeCat", spell = FERAL_CHARGE_CAT, required_form = "cat", matches = feral_charge_cat_matches },

    { name = "MaimInterrupt", spell = MAIM, required_form = "cat", min_energy = MAIM_COST, min_combo = 1, matches = maim_interrupt_matches },
    { name = "FaerieFireStealthLock", spell = SPELLS.FaerieFireFeral, required_form = "cat", matches = faerie_fire_stealth_matches },
    { name = "FaerieFireFeral", spell = SPELLS.FaerieFireFeral, required_form = "cat", debuff = FAERIE_FIRE_DEBUFF, refresh = FAERIE_FIRE_REFRESH, matches = faerie_fire_matches },
    { name = "MangleDebuff", spell = SPELLS.MangleCat, required_form = "cat", min_energy = MANGLE_COST, debuff = MANGLE_DEBUFF, refresh = MANGLE_REFRESH_WINDOW, matches = mangle_debuff_matches },

    { name = "RipSnapshot", spell = SPELLS.Rip, required_form = "cat", min_energy = RIP_COST, min_combo = 5, matches = rip_snapshot_matches },
    { name = "Rip", spell = SPELLS.Rip, required_form = "cat", min_energy = RIP_COST, min_combo = 3, matches = rip_matches },
    { name = "FerociousBiteExecute", spell = SPELLS.FerociousBite, required_form = "cat", min_energy = BITE_COST, min_combo = 3, target_max_hp = EXECUTE_HP, matches = bite_matches },
    { name = "FerociousBiteTtd", spell = SPELLS.FerociousBite, required_form = "cat", min_energy = BITE_COST, min_combo = 3, matches = emergency_bite_matches },
    { name = "MaimControl", spell = MAIM, required_form = "cat", min_energy = MAIM_COST, min_combo = 3, matches = maim_control_matches },

    { name = "TigersFury", spell = SPELLS.TigersFury, target = "self", required_form = "cat", requires_target = false, cooldown = 30, matches = tigers_fury_matches },
    { name = "Powershift", spell = SPELLS.CatForm, target = "self", skip_gcd = true, requires_target = false, matches = powershift_matches },
    { name = "EmergencyPowershift", spell = SPELLS.CatForm, target = "self", skip_gcd = true, requires_target = false, matches = emergency_powershift_matches },

    { name = "RakeSnapshot", spell = SPELLS.Rake, required_form = "cat", min_energy = RAKE_COST, matches = rake_snapshot_matches },
    { name = "RakeTab", spell = SPELLS.Rake, required_form = "cat", min_energy = RAKE_COST, matches = rake_tab_matches },
    { name = "Rake", spell = SPELLS.Rake, required_form = "cat", min_energy = RAKE_COST, matches = rake_matches },
    { name = "ShredOmen", spell = SPELLS.Shred, required_form = "cat", requires_behind = true, matches = clearcasting_shred_matches },
    { name = "Shred", spell = SPELLS.Shred, required_form = "cat", requires_behind = true, min_energy = SHRED_COST, matches = shred_matches },
    { name = "MangleFiller", spell = SPELLS.MangleCat, required_form = "cat", min_energy = MANGLE_COST, matches = mangle_filler_matches },
    { name = "ClawFallback", spell = SPELLS.Claw, required_form = "cat", min_energy = 45, matches = claw_matches },
}

local strategies = {
    { name = "PoolForRip", matches = pool_for_finisher_matches, execute = wait_execute_execute },
    { name = "PoolForBuilderTick", matches = pool_for_builder_matches, execute = wait_execute_execute },
    { name = "PoolForExecuteBite", matches = wait_execute, execute = wait_execute_execute },
}

for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context) return base_matches(context, action) end,
        execute = function(context) return cast_and_record(context, action) end,
    }
end

NS.rotation_registry:register("cat", strategies, { get_state = build_state })
NS.log("Druid cat rotation registered (production TBC: powershift, bleeds, openers, PvP, movement, snapshotting)")
return strategies
