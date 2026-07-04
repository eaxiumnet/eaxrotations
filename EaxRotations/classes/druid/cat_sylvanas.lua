-- cat_sylvanas.lua — Druid Feral Cat (melee DPS) rotation for TBC Anniversary (2.5.5).
-- WHAT:  cat-form DPS rotation (Rake / Shred builders, Rip FB bite-window gating,
--         Mangle + SR cycle, Berserk / Tiger's Fury cooldowns, Powershift).
-- WHEN:  combat, in cat form, energy and target valid.
-- WHY:   TBC feral cat consensus: maintain Mangle + SR debuffs, pool energy
--         for FB when Rip is up at 5 CP, otherwise Shred > Rake as builders.
--         Bite gates on CP >= 5 and target HP < 25%.
-- SAFETY: pattern 14 nil-guards. Energy / CP default to 0 to avoid bite skipping.
--          snapshot_sylvanas handles Rip / Rake snapshot capture.


local NS = _G.EaxRotations
if not NS then return nil end
local _same_unit = NS.same_unit or function(a, b) return a == b end
local _not_same_unit = NS.not_same_unit or function(a, b) return a ~= b end
local potion_helper = require("shared/potion_helper_sylvanas")

local BASE_SPELLS = NS.DruidSpells or {}
local SPELLS = BASE_SPELLS
-- Form detection diagnostic: logs all detection methods once at startup (debug only)
local _form_diag_logged = false
local function dump_form_detection()
    if _form_diag_logged then return end
    _form_diag_logged = true
    if not NS.debug then return end
    local me = NS.GetPlayer and NS.GetPlayer()
    if not me or not NS.log then return end
    local cat_form_buff_id = 768
    local bear_form_buff_ids = { 5487, 9634 }
    local moonkin_form_buff_id = 24858
    -- Method 1: engine-level get_shapeshift_form_id
    local form_id = -1
    if core and core.spell_book and core.spell_book.get_shapeshift_form_id then
        local ok, id = pcall(core.spell_book.get_shapeshift_form_id)
        if ok then form_id = id end
    end
    NS.log("[FORM_DIAG] 1. get_shapeshift_form_id() = " .. tostring(form_id) .. " (0=caster,1=bear,3=cat,4=travel)")
    -- Method 2-4: NS.has_form by name
    NS.log("[FORM_DIAG] 2. NS.has_form('cat') = " .. tostring(NS.has_form and NS.has_form("cat")))
    NS.log("[FORM_DIAG] 3. NS.has_form('bear') = " .. tostring(NS.has_form and NS.has_form("bear")))
    NS.log("[FORM_DIAG] 4. NS.has_form('moonkin') = " .. tostring(NS.has_form and NS.has_form("moonkin")))
    -- Method 5: NS.get_player_stance
    if NS.get_player_stance then
        NS.log("[FORM_DIAG] 5. NS.get_player_stance() = " .. tostring(NS.get_player_stance()))
    end
    -- Method 6-8: NS.buff_up with raw buff IDs
    NS.log("[FORM_DIAG] 6. NS.buff_up(me, " .. cat_form_buff_id .. ") [CatForm buff] = " .. tostring(NS.buff_up and NS.buff_up(me, cat_form_buff_id)))
    local bear_buff = false
    if NS.buff_up then
        for _, id in ipairs(bear_form_buff_ids) do
            if NS.buff_up(me, id) then bear_buff = true; break end
        end
    end
    NS.log("[FORM_DIAG] 7. NS.buff_up(me, bear_form_buffs) = " .. tostring(bear_buff))
    NS.log("[FORM_DIAG] 8. NS.buff_up(me, moonkin=" .. moonkin_form_buff_id .. ") = " .. tostring(NS.buff_up and NS.buff_up(me, moonkin_form_buff_id)))
    -- Method 9: has_player_buff wrapper
    NS.log("[FORM_DIAG] 9. NS.has_player_buff(" .. cat_form_buff_id .. ") = " .. tostring(NS.has_player_buff and NS.has_player_buff(cat_form_buff_id)))
    -- Method 10: power type detection
    local energy = 0
    if me.get_power then
        local ok, e = pcall(me.get_power, me, 3)
        if ok and type(e) == "number" then energy = e end
    end
    NS.log("[FORM_DIAG] 10. power_type=energy value=" .. tostring(energy) .. " (energy>0 implies cat form)")
end


local POUNCE = BASE_SPELLS.Pounce or (NS.spell_action and NS.spell_action({ 27006, 9827, 9005 }, "Pounce"))
local MAIM = BASE_SPELLS.Maim or (NS.spell_action and NS.spell_action({ 22570 }, "Maim"))
local TRACK_HUMANOIDS = BASE_SPELLS.TrackHumanoids or (NS.spell_action and NS.spell_action({ 5225 }, "TrackHumanoids"))

local STANCE_CAT = 3
local ENERGY_CAP = 100
local ENERGY_TICK_INTERVAL = 2.0
local ENERGY_PER_TICK = 20
local EnergyTickTracker = require("shared/energy_tick_tracker_sylvanas")
local _energy_state = EnergyTickTracker.new_state()
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

-- IZI SDK cache for energy prediction (optional, falls back to manual)
local _izi = nil
do
    local ok, mod = pcall(require, "common/izi_sdk")
    if ok and type(mod) == "table" then _izi = mod end
end

local RIP_DEBUFF = { 27008, 1079 }
local RAKE_DEBUFF = { 27003, 9904, 1824, 1823, 1822 }
local MANGLE_DEBUFF = { 33876, 33983, 33982, 33878, 33986, 33987 }
local FAERIE_FIRE_DEBUFF = { 27011, 17392, 17391, 17390, 16857, 26993, 9907, 9749, 778, 770 }
local BLOODLUST_BUFFS = { 2825, 32182, 27641 }
local PROWL_BUFF = { 9913, 6783, 5215 }
local POUNCE_DEBUFF = { 27006, 9827, 9005 }
local MAIM_DEBUFF = { 22570 }
local OMEN_OF_CLARITY_BUFF = { 16864 }
local TIGERS_FURY_BUFF = { 9846, 9845, 6793, 5217 }
local DASH_BUFF = { 33357, 9821, 1850 }
local BARKSKIN_BUFF = { 22812 }
local TRACK_HUMANOIDS_BUFF = { 5225 }
local WOLFSHEAD_BUFF = { 29940, 17770 }
local WOLFSHEAD_HELM_ID = 8345
local CLEARCASTING_COST_FLOOR = 0
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
    target_ttd = 999,
    target_ttd_known = false,
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

-- Form-switch throttle: prevent rapid cat↔travel form oscillation when OOC.
-- Any form cast sets this; subsequent form casts are blocked for FORM_SWITCH_COOLDOWN seconds.
local _last_form_shift_time = -100
local FORM_SWITCH_COOLDOWN = 5.0

-- Throttle build_state to once per frame to avoid rebuilding state N times
-- per frame (once per strategy match function). Uses context.now when
-- available (real game); falls back to no caching in test environments.
local _last_build_state_time = -1

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



local function spell_exists(spell)
    if spell == nil then return false end
    if not NS.spell_exists then return true end
    return NS.spell_exists(spell)
end

local function spell_ready(spell, target, opts)
    if not spell_exists(spell) then return false end
    return NS.spell_ready and NS.spell_ready(spell, target, opts) or false
end



local function get_attack_power(context, me)
    if context and type(context.attack_power) == "number" then return context.attack_power end
    -- Defensive fallback: query the unit object directly if context didn't provide it
    if me and type(me.get_attack_power) == "function" then
        local ok, ap = pcall(function() return me:get_attack_power() end)
        if ok and type(ap) == "number" then return ap end
    end
    return 0
end

---Check if Wolfshead Helm (8345, item_id=8345) is equipped using NS.get_equipped_item_id.
---@param me game_object|nil Local player
---@return boolean
local function has_wolfshead_equipped(me)
    if not me then
        if NS.GetPlayer then me = NS.GetPlayer() end
        if not me then return false end
    end
    -- Use documented Sylvanas API: get_item_at_inventory_slot, exposed via NS.get_equipped_item_id
    if NS.get_equipped_item_id and NS.EQUIPMENT_SLOTS then
        local id = NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.HEAD)
        return id == WOLFSHEAD_HELM_ID
    end
    -- Fallback: direct unit method
    if type(me.get_equipped_item) == "function" then
        local ok, item_id = pcall(function() return me:get_equipped_item(1) end)
        return ok and type(item_id) == "number" and item_id == WOLFSHEAD_HELM_ID
    end
    if type(me.get_item_at_inventory_slot) == "function" then
        local ok, slot_info = pcall(function() return me:get_item_at_inventory_slot(1) end)
        if ok and slot_info then
            if type(slot_info) == "number" then return slot_info == WOLFSHEAD_HELM_ID end
            local id = slot_info.item_id or slot_info.entry or (slot_info.object and slot_info.object.get_item_id and slot_info.object:get_item_id())
            return type(id) == "number" and id == WOLFSHEAD_HELM_ID
        end
    end
    return false
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
    if NS.setting_bool(settings, "cat_shred_positional", true) == false then return true end
    if context and context.is_behind ~= nil then return context.is_behind == true end
    -- IZI SDK fast path: native behind check
    local me = NS.GetPlayer and NS.GetPlayer()
    if me and target and type(target.is_behind) == "function" then
        local ok, behind = pcall(target.is_behind, target, me)
        if ok then return behind end
    end
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
    local me = state.me
    -- IZI SDK fast path: use native energy prediction when available
    if me and type(me.energy_predicted) == "function" then
        state.projected_energy = me:energy_predicted(ENERGY_TICK_INTERVAL) or
            math.min(ENERGY_CAP, state.energy + ENERGY_PER_TICK)
        state.tick_confident = true
        -- Try to get time-to-next-tick from IZI
        if type(me.energy_time_to_x) == "function" then
            state.next_tick_in = me:energy_time_to_x(
                math.min(ENERGY_CAP, state.energy + ENERGY_PER_TICK)
            ) or ENERGY_TICK_INTERVAL
        else
            state.next_tick_in = estimate_next_tick(state)
        end
    else
        -- Shared energy tick tracker (with powershift window guard)
        local delta = state.energy - state.last_energy
        if delta > 0 and delta <= 25 and (state.now - state.last_shift_time) > POWERSHIFT_IGNORE_WINDOW then
            _energy_state.last_tick_time = state.now
            _energy_state.tick_confident = true
        end
        _energy_state.last_energy = state.energy
        state.next_tick_in = EnergyTickTracker.estimate_next_tick(_energy_state, state.now)
        state.projected_energy = EnergyTickTracker.predicted_energy(_energy_state, state.energy, ENERGY_TICK_INTERVAL)
    end
end

local function should_wait_for_tick(state, required_energy)
    if (state.energy or 0) >= required_energy then return false end
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
    -- Pattern 14: nil target_ttd -> treat as 0 -> return true (lives).
    -- Unknown TTD = assume long-lived (don't skip DoTs/finishers).
    if (state.target_ttd or 0) <= 0 then return true end
    return (state.target_ttd or 999) >= seconds
end

local function prevent_cp_waste(state, added_cp)
    -- (state.combo_points or 0): nil combo_points -> arithmetic crash guard.
    return (state.combo_points or 0) + (added_cp or 1) <= 5
end

local function has_valid_target(context)
    return context.has_valid_enemy_target ~= false and context.target ~= nil
end

local function base_matches(context, action)
    if action.spell == nil and NS.spell_exists then return false end
    if action.matches then return action.matches(context, action) end
    return true
end

local function execute_action(context, action)
    local target
    if action.target == "self" or action.requires_target == false then
        target = context.me or NS.GetPlayer()
    else
        target = context.target
    end
    local opts = {}
    if action.cooldown then opts.expected_cooldown = action.cooldown end
    if action.skip_gcd then opts.skip_gcd = true end
    return NS.try_cast(action.spell, target, "[CAT] " .. (action.name or ""), opts)
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
        if action.kind == "form" then _last_form_shift_time = get_now() end
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

    local now = context.now
    if now and now == _last_build_state_time then return state end
    now = now or get_now()
    if context.now then _last_build_state_time = now end

    state.is_group = context.is_group or false
    state.now = now
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
    state.target_ttd = context.ttd or context.target_ttd or 999
    state.target_ttd_known = (context.ttd ~= nil) or (context.target_ttd ~= nil)
    state.target_range = get_target_range(me, target, context)
    state.in_combat = context.in_combat == true
    state.is_pvp = context.is_pvp == true or (settings and settings.pvp_mode == true)
    state.is_player_target = is_target_player(target, context)
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(22812, 3.0) or false
    if not skip_aura then
        state.is_stealthed = context.is_stealthed == true or NS.buff_up(me, PROWL_BUFF) or false
        state.clearcasting = NS.buff_up(me, OMEN_OF_CLARITY_BUFF) or false
        state.has_tigers_fury = NS.buff_up(me, TIGERS_FURY_BUFF) or false
        state.has_dash = NS.buff_up(me, DASH_BUFF) or false
        state.has_barkskin = NS.buff_up(me, BARKSKIN_BUFF) or false
        state.has_track_humanoids = NS.buff_up(me, TRACK_HUMANOIDS_BUFF) or false
        state.has_wolfshead = has_wolfshead_equipped(me) or NS.buff_up(me, WOLFSHEAD_BUFF) or NS.setting_bool(settings, "cat_wolfshead_helm", false)
        state.has_bloodlust = NS.buff_up(me, BLOODLUST_BUFFS) or false
        state.rip_remains = NS.debuff_remains(target, RIP_DEBUFF) or 0
        state.rake_remains = NS.debuff_remains(target, RAKE_DEBUFF) or 0
        state.mangle_remains = NS.debuff_remains(target, MANGLE_DEBUFF) or 0
        state.faerie_fire_remains = NS.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
        state.pounce_remains = NS.debuff_remains(target, POUNCE_DEBUFF) or 0
        state.maim_remains = NS.debuff_remains(target, MAIM_DEBUFF) or 0
    end
    state.is_cat = NS.has_form and NS.has_form("cat") or context.stance == STANCE_CAT
    state.is_behind = is_behind_target(target, context, settings)
    state.attack_power = get_attack_power(context, me)
    if _not_same_unit(snapshot_state.rip_target, target) or state.rip_remains <= 0 then snapshot_state.rip_ap = 0 end
    if _not_same_unit(snapshot_state.rake_target, target) or state.rake_remains <= 0 then snapshot_state.rake_ap = 0 end
    state.rip_ap = snapshot_state.rip_ap
    state.rake_ap = snapshot_state.rake_ap
    state.has_high_ap_window = state.has_bloodlust or (state.attack_power > 0 and state.rip_ap > 0 and state.attack_power >= state.rip_ap * AP_UPGRADE_RATIO) or (state.attack_power > 0 and state.rake_ap > 0 and state.attack_power >= state.rake_ap * AP_UPGRADE_RATIO)
    update_energy_tick(state)
    state.should_execute = state.target_hp <= NS.setting_number(settings, "cat_execute_hp", EXECUTE_HP)
    state.should_aoe = state.enemy_count >= (settings.aoe_threshold or 3)
    state.should_tab_rake = state.enemy_count >= 2 and state.enemy_count <= 3
    state.should_pool_for_rip = (state.combo_points or 0) >= NS.setting_number(settings, "cat_rip_cp", 5) and (state.energy or 0) < RIP_COST and target_lives(state, MIN_RIP_TTD)
    state.should_pool_for_shred = (state.combo_points or 0) < 5 and (state.energy or 0) < SHRED_COST and (state.energy or 0) + ENERGY_PER_TICK >= SHRED_COST
    state.pooling = state.should_pool_for_rip or state.should_pool_for_shred
    state.should_powershift = false
    if NS.setting_bool(settings, "cat_powershift_enabled", true) and state.is_cat and state.in_combat then
        local shift_energy = NS.setting_number(settings, "cat_powershift_energy", 20)
        local shift_gain = state.has_wolfshead and POWERSHIFT_GAIN_WOLFSHEAD or POWERSHIFT_GAIN_FUROR
        local useful_after = (state.energy or 0) + shift_gain >= math.min(ENERGY_CAP, SHRED_COST)
        state.should_powershift = state.energy <= shift_energy and state.combo_points <= POWERSHIFT_SAFE_CP and state.mana_pct >= POWERSHIFT_MIN_MANA and useful_after
    end
    return state
end

local function cat_form_matches(context, action)
    if NS.has_form and NS.has_form("cat") then return false end
    if context.stance == STANCE_CAT then return false end
    if _last_form_shift_time > 0 and (get_now() - _last_form_shift_time) < FORM_SWITCH_COOLDOWN then return false end
    -- Respect travel form for movement: if we're in travel form, OOC,
    -- moving toward a distant target, stay in travel form until closer.
    if not context.in_combat and context.is_moving and (context.target_range or 0) >= TRAVEL_FORM_RANGE then
        if NS.has_form and NS.has_form("travel") then return false end
        if context.stance == 4 then return false end
    end
    return true
end

local function prowl_matches(context, action)
    local state = build_state(context)
    if state.in_combat then return false end
    if state.is_stealthed then return false end
    if state.target and state.target_range > 0 and state.target_range > 18 then return false end
    return true
end

local function track_humanoids_matches(context, action)
    local state = build_state(context)
    if state.in_combat then return false end
    if state.has_track_humanoids then return false end
    if not state.is_pvp and not state.is_player_target then return false end
    return true
end

local function pounce_matches(context, action)
    local state = build_state(context)
    if not state.is_stealthed then return false end
    if not state.is_pvp and not state.is_player_target then return false end
    if state.energy < POUNCE_COST then return false end
    return true
end

local function ravage_matches(context, action)
    local state = build_state(context)
    if not state.is_stealthed then return false end
    if not state.is_behind then return false end
    if state.energy < RAVAGE_COST then return false end
    if not prevent_cp_waste(state, 1) then return false end
    return true
end

local function stealth_shred_matches(context, action)
    local state = build_state(context)
    if not state.is_stealthed then return false end
    if state.mangle_remains <= 0 then return false end
    if not state.is_behind then return false end
    return true
end

local function stealth_mangle_matches(context, action)
    local state = build_state(context)
    if not state.is_stealthed then return false end
    if state.energy < MANGLE_COST then return false end
    return true
end

local function barkskin_matches(context, action)
    local state = build_state(context)
    local threshold = NS.setting_number(state.settings, "cat_barkskin_hp", 85)
    if (state.hp or 100) > threshold then return false end
    if state.has_barkskin then return false end
    return true
end

local function dash_matches(context, action)
    local state = build_state(context)
    if state.has_dash then return false end
    if not state.target or state.target_range < DASH_RANGE then return false end
    if not state.is_pvp and state.target_range < TRAVEL_FORM_RANGE then return false end
    return true
end

local function travel_form_matches(context, action)
    local state = build_state(context)
    -- Default off — users opt-in via setting to prevent surprise form spam.
    if not NS.setting_bool(state.settings, "cat_auto_travel_form", false) then return false end
    if state.in_combat then return false end
    if NS.has_form and NS.has_form("travel") then return false end
    if context.stance == 4 then return false end
    if _last_form_shift_time > 0 and (get_now() - _last_form_shift_time) < FORM_SWITCH_COOLDOWN then return false end
    -- Only useful when actually moving; stationary players don't need it.
    if not context.is_moving then return false end
    if not state.target or state.target_range < TRAVEL_FORM_RANGE then return false end
    return true
end

local function faerie_fire_matches(context, action)
    local state = build_state(context)
    if not state.target then return false end
    -- Skip if target has no armor (API unavailable or already fully reduced)
    if (context.target_armor or 0) <= 0 then return false end
    if state.faerie_fire_remains > MANGLE_REFRESH_WINDOW then return false end
    if state.target_ttd > 0 and state.target_ttd < 10 then return false end
    if state.is_pvp and state.is_player_target then return true end
    return target_lives(state, LONG_TTD)
end

local function faerie_fire_stealth_matches(context, action)
    local state = build_state(context)
    if not state.is_pvp and not state.is_player_target then return false end
    -- Skip if target has no armor (API unavailable or already fully reduced)
    if (context.target_armor or 0) <= 0 then return false end
    if state.faerie_fire_remains > FAERIE_FIRE_REFRESH then return false end
    local creature_type = safe_method(state.target, "get_creature_type", nil)
    if creature_type and not STEALTH_PREVENT_TYPES[creature_type] then return false end
    return true
end

local function mangle_debuff_matches(context, action)
    local state = build_state(context)
    if state.mangle_remains > MANGLE_REFRESH_WINDOW then return false end
    if should_wait_for_tick(state, MANGLE_COST) then return false end
    return true
end

local function rip_matches(context, action)
    local state = build_state(context)
    local required_cp = NS.setting_number(state.settings, "cat_rip_cp", 5)
    if not state.target then return false end
    if context.combo_points ~= nil and state.combo_points < required_cp then return false end
    if not target_lives(state, MIN_RIP_TTD) then return false end
    -- TTD gate: skip Rip if target dying soon (needs time to tick)
    if state.target_ttd > 0 and state.target_ttd < 6 then return false end
    if should_wait_for_tick(state, RIP_COST) then return false end
    if not should_snapshot_upgrade(state.attack_power, state.rip_ap, state.rip_remains, RIP_REFRESH_WINDOW, AP_UPGRADE_RATIO) then return false end
    return true
end

-- ============================================================================
-- Rip Trick (advanced micro-optimization from wowsims feral rotation)
-- Casts Rip at 1+ CP when energy is in the narrow [RIP_COST, MANGLE_COST)
-- window -- you can afford Rip but not Mangle, so Rip now > waiting.
-- Only fires when powershifting mana is available. Opt-in (default off).
-- Source: wowsims_classic/sim/druid/feral/rotation.go canRipTrick
local function rip_trick_matches(context, action)
    local state = build_state(context)
    if not NS.setting_bool(state.settings, "cat_use_rip_trick", false) then return false end
    if not state.target then return false end
    if not state.is_cat or not state.in_combat then return false end
    if (state.mana_pct or 100) < POWERSHIFT_MIN_MANA then return false end
    if (state.combo_points or 0) < 1 then return false end
    if (state.rip_remains or 0) > 0 then return false end
    if not target_lives(state, MIN_RIP_TTD) then return false end
    if (state.target_ttd or 999) > 0 and (state.target_ttd or 999) < 6 then return false end
    local energy = (state.energy or 0)
    local next_energy = energy + ENERGY_PER_TICK
    local in_window_now = energy >= RIP_COST and energy < MANGLE_COST
    local in_window_next = next_energy >= RIP_COST and next_energy < MANGLE_COST
    if not in_window_now and not in_window_next then return false end
    if not in_window_now then
        if should_wait_for_tick(state, RIP_COST) then return false end
    end
    return true
end

-- ============================================================================
-- Shred Trick (advanced micro-optimization from wowsims feral rotation)
-- Prefers Shred over Mangle as builder when a bleed is active, energy
-- >= SHRED_COST, next tick >1s away, and Mangle affordable after Shred.
-- Only fires with ample powershifting mana. Opt-in (default off).
-- Source: wowsims_classic/sim/druid/feral/rotation.go canShredTrick
local function shred_trick_matches(context, action)
    local state = build_state(context)
    if not NS.setting_bool(state.settings, "cat_use_shred_trick", false) then return false end
    if not state.target then return false end
    if not state.is_cat or not state.in_combat then return false end
    if not state.is_behind then return false end
    local bleed_active = (state.mangle_remains or 0) > 0 or (state.rip_remains or 0) > 0 or (state.rake_remains or 0) > 0
    if not bleed_active then return false end
    if (state.mana_pct or 100) < (POWERSHIFT_MIN_MANA * 2) then return false end
    if (state.energy or 0) < SHRED_COST then return false end
    if (state.next_tick_in or 0) <= 1.0 then return false end
    local energy_after_shred = (state.energy or 0) - SHRED_COST + ENERGY_PER_TICK
    if energy_after_shred < MANGLE_COST and (state.next_tick_in or 0) <= 1.5 then return false end
    if (state.combo_points or 0) >= 5 then return false end
    return true
end

local function rip_snapshot_matches(context, action)
    local state = build_state(context)
    local required_cp = NS.setting_number(state.settings, "cat_rip_cp", 5)
    if state.combo_points < required_cp then return false end
    if state.rip_remains <= RIP_REFRESH_WINDOW then return false end
    if not target_lives(state, MIN_RIP_TTD) then return false end
    if state.rip_ap <= 0 then return false end
    -- Use lower threshold during bloodlust/high-AP windows to catch the snapshot opportunity
    local ratio = state.has_high_ap_window and HIGH_AP_UPGRADE_RATIO or STRONG_AP_UPGRADE_RATIO
    if state.attack_power < state.rip_ap * ratio then return false end
    return true
end

local function bite_matches(context, action)
    local state = build_state(context)
    local required_cp = NS.setting_number(state.settings, "cat_ferocious_bite_cp", 5)
    if state.combo_points < required_cp then return false end
    if state.rip_remains <= RIP_REFRESH_WINDOW and target_lives(state, MIN_RIP_TTD) then return false end
    -- TTD awareness: prefer Ferocious Bite when target dying soon (instant > DoT)
    local short_ttd = state.target_ttd > 0 and state.target_ttd < 6
    if not state.should_execute and not short_ttd and state.target_ttd_known and state.target_ttd > SHORT_TTD then return false end
    if should_wait_for_tick(state, BITE_COST) then return false end
    return true
end

local function bite_trick_matches(context, action)
    local state = build_state(context)
    if not state.in_combat then return false end
    if NS.setting_bool and NS.setting_bool(state.settings, "cat_use_ferocious_bite", true) == false then return false end
    if (state.combo_points or 0) < 5 then return false end
    local bite_max_energy = NS.setting_number and NS.setting_number(state.settings, "cat_bite_max_energy", 39) or 39
    if (state.energy or 0) > bite_max_energy then return false end
    if (state.energy or 0) < BITE_COST then return false end
    if state.next_tick_in <= 0.1 then return false end
    if state.rip_remains <= 2 and target_lives(state, MIN_RIP_TTD) then return false end
    return true
end

local function emergency_bite_matches(context, action)
    local state = build_state(context)
    if (state.combo_points or 0) < 3 then return false end
    if state.target_ttd <= 0 or state.target_ttd > 4 then return false end
    return true
end

local function maim_interrupt_matches(context, action)
    local state = build_state(context)
    if (state.combo_points or 0) < 1 then return false end
    if state.maim_remains > 0 then return false end
    if not state.is_pvp and not state.is_player_target then return false end
    local casting = safe_method(state.target, "is_casting", false) or safe_method(state.target, "is_channeling", false)
    if not casting then return false end
    if NS.is_interruptible and not NS.is_interruptible(state.target) then return false end
    return true
end

local function maim_control_matches(context, action)
    local state = build_state(context)
    if (state.combo_points or 0) < 3 then return false end
    if state.maim_remains > 0 then return false end
    if not state.is_pvp and not state.is_player_target then return false end
    if state.target_hp <= HARD_EXECUTE_HP then return false end
    return true
end

local function rake_matches(context, action)
    local state = build_state(context)
    if not state.target then return false end
    if not target_lives(state, MIN_RAKE_TTD) then return false end
    if context.combo_points ~= nil and (state.combo_points or 0) >= 5 then return false end
    if should_wait_for_tick(state, RAKE_COST) then return false end
    if not should_snapshot_upgrade(state.attack_power, state.rake_ap, state.rake_remains, RAKE_REFRESH_WINDOW, AP_UPGRADE_RATIO) then return false end
    return true
end

local function rake_snapshot_matches(context, action)
    local state = build_state(context)
    if state.rake_remains <= RAKE_REFRESH_WINDOW then return false end
    if state.rake_ap <= 0 then return false end
    if (state.combo_points or 0) >= 5 then return false end
    -- Use lower threshold during bloodlust/high-AP windows to catch the snapshot opportunity
    local ratio = state.has_high_ap_window and HIGH_AP_UPGRADE_RATIO or STRONG_AP_UPGRADE_RATIO
    if state.attack_power < state.rake_ap * ratio then return false end
    return true
end

local function rake_tab_matches(context, action)
    local state = build_state(context)
    if not state.should_tab_rake then return false end
    if (state.combo_points or 0) >= 5 then return false end
    return rake_matches(context, action)
end

local function clearcasting_shred_matches(context, action)
    local state = build_state(context)
    if not state.clearcasting then return false end
    if state.target and not state.is_behind then return false end
    if context.combo_points ~= nil and (state.combo_points or 0) >= 5 then return false end
    action.min_energy = CLEARCASTING_COST_FLOOR
    return true
end

local function shred_matches(context, action)
    local state = build_state(context)
    if (state.combo_points or 0) >= 5 then return false end
    if state.pooling and (state.energy or 0) < SHRED_COST then return false end
    if not state.is_behind then return false end
    if state.mangle_remains <= MANGLE_REFRESH_WINDOW and target_lives(state, MIN_RAKE_TTD) then return false end
    if should_wait_for_tick(state, SHRED_COST) then return false end
    return true
end

local function mangle_filler_matches(context, action)
    local state = build_state(context)
    if (state.combo_points or 0) >= 5 then return false end
    if state.is_behind and spell_ready(SPELLS.Shred, state.target, nil) and (state.energy or 0) >= SHRED_COST then return false end
    if should_wait_for_tick(state, MANGLE_COST) then return false end
    return true
end

local function claw_matches(context, action)
    local state = build_state(context)
    if (state.combo_points or 0) >= 5 then return false end
    if spell_exists(SPELLS.MangleCat) then return false end
    if should_wait_for_tick(state, 45) then return false end
    return true
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
    if (state.combo_points or 0) >= 5 and (state.energy or 0) >= RIP_COST then return false end
    return true
end

local function powershift_matches(context, action)
    local state = build_state(context)
    if not state.should_powershift then return false end
    if state.clearcasting then return false end
    if state.next_tick_in <= 0.35 and state.energy + ENERGY_PER_TICK <= ENERGY_CAP then return false end
    if (state.combo_points or 0) >= 5 and (state.energy or 0) >= RIP_COST then return false end
    return true
end

local function emergency_powershift_matches(context, action)
    local state = build_state(context)
    if not NS.setting_bool(state.settings, "cat_powershift_enabled", true) then return false end
    if not state.is_cat or not state.in_combat then return false end
    if (state.energy or 0) > 10 then return false end
    if (state.mana_pct or 100) < POWERSHIFT_MIN_MANA then return false end
    if (state.combo_points or 0) >= 5 then return false end
    if state.next_tick_in <= 0.2 then return false end
    return true
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
    if state.combo_points < NS.setting_number(state.settings, "cat_ferocious_bite_cp", 5) then return false end
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
    { name = "FeralChargeCat", spell = SPELLS.FeralCharge, target = "self", required_form = "cat", requires_target = false, matches = function(context) return context.in_combat and context.target and context.target_range and context.target_range >= 8 and context.target_range <= 25 end },

    { name = "MaimInterrupt", spell = MAIM, required_form = "cat", min_energy = MAIM_COST, min_combo = 1, matches = maim_interrupt_matches },
    { name = "FaerieFireStealthLock", spell = SPELLS.FaerieFireFeral, required_form = "cat", matches = faerie_fire_stealth_matches },
    { name = "FaerieFireFeral", spell = SPELLS.FaerieFireFeral, required_form = "cat", debuff = FAERIE_FIRE_DEBUFF, refresh = FAERIE_FIRE_REFRESH, matches = faerie_fire_matches },
    { name = "MangleDebuff", spell = SPELLS.MangleCat, required_form = "cat", min_energy = MANGLE_COST, debuff = MANGLE_DEBUFF, refresh = MANGLE_REFRESH_WINDOW, matches = mangle_debuff_matches },

    { name = "RipSnapshot", spell = SPELLS.Rip, required_form = "cat", min_energy = RIP_COST, min_combo = 5, matches = rip_snapshot_matches },
    { name = "RipTrick", spell = SPELLS.Rip, required_form = "cat", min_energy = RIP_COST, min_combo = 1, matches = rip_trick_matches },
    { name = "Rip", spell = SPELLS.Rip, required_form = "cat", min_energy = RIP_COST, min_combo = 3, matches = rip_matches },
    { name = "FerociousBiteExecute", spell = SPELLS.FerociousBite, required_form = "cat", min_energy = BITE_COST, min_combo = 3, target_max_hp = EXECUTE_HP, matches = bite_matches },
    { name = "FerociousBiteTtd", spell = SPELLS.FerociousBite, required_form = "cat", min_energy = BITE_COST, min_combo = 3, matches = emergency_bite_matches },
    { name = "BiteTrick", spell = SPELLS.FerociousBite, required_form = "cat", min_energy = BITE_COST, min_combo = 5, matches = bite_trick_matches },
    { name = "MaimControl", spell = MAIM, required_form = "cat", min_energy = MAIM_COST, min_combo = 3, matches = maim_control_matches },

    { name = "TigersFury", spell = SPELLS.TigersFury, target = "self", required_form = "cat", requires_target = false, cooldown = 30, matches = tigers_fury_matches },
    { name = "Powershift", spell = SPELLS.CatForm, target = "self", skip_gcd = true, requires_target = false, matches = powershift_matches },
    { name = "EmergencyPowershift", spell = SPELLS.CatForm, target = "self", skip_gcd = true, requires_target = false, matches = emergency_powershift_matches },

    { name = "RakeSnapshot", spell = SPELLS.Rake, required_form = "cat", min_energy = RAKE_COST, matches = rake_snapshot_matches },
    { name = "RakeTab", spell = SPELLS.Rake, required_form = "cat", min_energy = RAKE_COST, matches = rake_tab_matches },
    { name = "Rake", spell = SPELLS.Rake, required_form = "cat", min_energy = RAKE_COST, matches = rake_matches },
    { name = "ShredOmen", spell = SPELLS.Shred, required_form = "cat", requires_behind = true, matches = clearcasting_shred_matches },
    { name = "ShredTrick", spell = SPELLS.Shred, required_form = "cat", requires_behind = true, min_energy = SHRED_COST, matches = shred_trick_matches },
    { name = "Shred", spell = SPELLS.Shred, required_form = "cat", requires_behind = true, min_energy = SHRED_COST, matches = shred_matches },
    { name = "MangleFiller", spell = SPELLS.MangleCat, required_form = "cat", min_energy = MANGLE_COST, matches = mangle_filler_matches },
    { name = "ClawFallback", spell = SPELLS.Claw, required_form = "cat", min_energy = 45, matches = claw_matches },
}

local strategies = {
    { name = "HealthPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end },
    { name = "ManaPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_mana_potion then return false end
          if (context.mana_pct or 100) > 20 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
    { name = "RemoveCurse",
      matches = function(context)
          if not (context.settings and context.settings.cat_auto_dispel) then return false end
          return NS.spell_ready(SPELLS.RemoveCurse, NS.PLAYER_UNIT, { skip_range = true })
      end,
      execute = function() return NS.try_cast(SPELLS.RemoveCurse, NS.PLAYER_UNIT, "[CAT] Remove Curse self", { skip_range = true }) end },
    { name = "PoolForRip", matches = pool_for_builder_matches, execute = wait_execute_execute },
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

table.insert(strategies, { name = "Healthstone",
    matches = function(context)
        local state = build_state(context)
        if not state.in_combat then return false end
        if (state.hp or 100) > 28 then return false end
        return (state.healthstone_ready or 0) > 0
    end,
    execute = function(context)
        local item_id = first_ready_item(HEALTHSTONE_IDS)
        if item_id > 0 and NS.use_item_by_id then
            return NS.use_item_by_id(item_id, context.me) and true or false
        end
        return false
    end,
})

NS.rotation_registry:register("cat", strategies, { get_state = build_state })
-- Druid cat rotation registered (production TBC: powershift, bleeds, openers, PvP, movement, snapshotting)
return strategies
