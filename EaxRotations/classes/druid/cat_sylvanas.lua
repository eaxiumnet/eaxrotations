-- cat_sylvanas.lua — Druid Feral Cat (melee DPS) rotation for TBC Anniversary (2.5.5).
-- WHAT:  cat-form DPS rotation (Rake / Shred builders, Rip FB bite-window gating,
--         Mangle + SR cycle, Tiger's Fury cooldowns, Powershift).
-- WHEN:  combat, in cat form, energy and target valid.
-- WHY:   mirrors wowsims/tbc-new feralcat APL + Icy Veins/Wowhead TBC Feral: maintain Mangle + SR, Rip at 5CP long TTD, FB otherwise, Mangle/Shred builder, powershift, TF CDs.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no manual nil-guards; no on_update allocs.
--          snapshot_sylvanas handles Rip / Rake snapshot capture.


local NS = _G.EaxRotations
if not NS then return nil end
local _same_unit = NS.same_unit or function(a, b) return a == b end
local _not_same_unit = NS.not_same_unit or function(a, b) return a ~= b end
local potion_helper = require("shared/potion_helper_sylvanas")
local _eng_ok, engineering = pcall(require, "shared/engineering_helper_sylvanas")
if not _eng_ok or type(engineering) ~= "table" then engineering = nil end
local _cm_ok, CombatMode = pcall(require, "shared/combat_mode_sylvanas")
if not _cm_ok or type(CombatMode) ~= "table" then CombatMode = nil end
local _snap_ok, Snapshot = pcall(require, "shared/snapshot_sylvanas")
if not _snap_ok or type(Snapshot) ~= "table" then Snapshot = nil end
local spec_kit = require("shared/spec_kit_sylvanas")
local _ok_cp_reader, _read_combo_points = pcall(require, "shared/combo_points_reader_sylvanas")
local leveling_helpers = require("shared/leveling_helpers_sylvanas")

-- Wrapper so low-level helper failures don't crash finisher matches.
local function is_low_level(level)
    local ok, result = pcall(function() return leveling_helpers.is_low_level(level) end)
    if ok then return result end
    return false
end
local dsl = require("shared/strategy_dsl_sylvanas")

-- Static reusable opts table to avoid per-frame allocation in hot path (Pattern 4)
local _opts = {}

local BASE_SPELLS = NS.DruidSpells or {}
local SPELLS = BASE_SPELLS

-- Centralized spell resolver via spec_kit (replaces per-spec spell() helper).
local define = spec_kit.define_action_for_class(SPELLS)
-- Form detection diagnostic: logs all detection methods once at startup (debug only)
local _get_shapeshift_form_id = (core and core.spell_book and core.spell_book.get_shapeshift_form_id) or nil
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
    -- Method 1: engine-level get_shapeshift_form_id (cached at module load per Pattern 2)
    local form_id = -1
    if _get_shapeshift_form_id then
        local ok, id = pcall(_get_shapeshift_form_id)
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


-- Action table via spec_kit (replaces per-spec spell() helper + POUNCE/MAIM/TRACK_HUMANOIDS locals).
-- Rank IDs from class_sylvanas.lua (verified against DBC for TBC Anniversary 2.5.5).
local ACTION = {
    Barkskin        = define("Barkskin",        { 22812 }, "Barkskin"),
    CatForm         = define("CatForm",         { 768 }, "CatForm"),
    Claw            = define("Claw",            { 27000, 9850, 9849, 5201, 3029, 1082 }, "Claw"),
    Dash            = define("Dash",            { 33357, 9821, 1850 }, "Dash"),
    FaerieFireFeral = define("FaerieFireFeral", { 27011, 17392, 17391, 17390, 16857 }, "FaerieFireFeral"),
    FeralCharge     = define("FeralCharge",     { 16979 }, "FeralCharge"),
    FerociousBite   = define("FerociousBite",   { 24248, 31018, 22829, 22828, 22827, 22568 }, "FerociousBite"),
    Maim            = define("Maim",            { 22570 }, "Maim"),
    MangleCat       = define("MangleCat",       { 33983, 33982, 33876 }, "MangleCat"),
    Pounce          = define("Pounce",          { 27006, 9827, 9823, 9005 }, "Pounce"),
    Prowl           = define("Prowl",           { 9913, 6783, 5215 }, "Prowl"),
    Rake            = define("Rake",            { 27003, 9904, 1824, 1823, 1822 }, "Rake"),
    Ravage          = define("Ravage",          { 27005, 9867, 9866, 6787, 6785 }, "Ravage"),
    RemoveCurse     = define("RemoveCurse",     { 2782 }, "RemoveCurse"),
    Rip             = define("Rip",             { 27008, 9896, 9894, 9752, 9493, 9492, 1079 }, "Rip"),
    Shred           = define("Shred",           { 27002, 27001, 9830, 9829, 8992, 6800, 5221 }, "Shred"),
    TigersFury      = define("TigersFury",      { 9846, 9845, 6793, 5217 }, "TigersFury"),
    TrackHumanoids  = define("TrackHumanoids",  { 5225 }, "TrackHumanoids"),
    TravelForm      = define("TravelForm",      { 783 }, "TravelForm"),
}

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
-- Below level 32 Ferocious Bite (rank 1) is unlearned, leaving Rip as the only CP
-- dump; the endgame 10s floor would suppress it on every leveling mob and strand CP.
local FEROCIOUS_BITE_LEVEL = 32
local MIN_RIP_TTD_NO_BITE = 4.0
local MIN_RAKE_TTD = 6.0
local SNAPSHOT_RESET_GRACE = 1.5  -- seconds after cast before recasting when debuff API lags
local POST_CAST_GRACE = 1.5  -- seconds to suppress Rip/Rake recast while debuff API still reads 0
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

local RIP_DEBUFF = { 27008, 9896, 9894, 9752, 9493, 9492, 1079 }
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
local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }

local function first_ready_item(item_ids)
    if not NS.is_item_ready then return 0 end
    for i = 1, #item_ids do
        local id = item_ids[i]
        if id and NS.is_item_ready(id) then
            local ok, count = pcall(NS.get_item_count, id)
            if ok and (count or 0) > 0 then return id end
        end
    end
    return 0
end
local BARKSKIN_BUFF = { 22812 }
local TRACK_HUMANOIDS_BUFF = { 5225 }
local WOLFSHEAD_BUFF = { 29940, 17770 }
local WOLFSHEAD_HELM_ID = 8345
local CLEARCASTING_COST_FLOOR = 0
-- Numeric creature-type IDs (matches the codebase convention, e.g.
-- protection DEMON_OR_UNDEAD = { [3]=true, [6]=true }): 7=Humanoid, 1=Beast.
-- Was string-keyed ("Humanoid"/"Beast") while get_creature_type() returns a
-- number, so the lookup always missed and FaerieFireStealthLock never fired.
local STEALTH_PREVENT_TYPES = { [7] = true, [1] = true }

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
    healthstone_ready = 0,
    combat_time = 0,
    should_burst = false,
}

local snapshot_state = {
    rip_target = nil,
    rake_target = nil,
    rip_ap = 0,
    rake_ap = 0,
    rip_cast_time = -99999,
    rake_cast_time = -99999,
}

-- Target-independent post-cast timestamps for the recast grace window. Unlike
-- snapshot_state.*_cast_time (which build_state resets on target change), these
-- persist so a freshly-cast Rip/Rake isn't double-cast while the debuff API
-- still reads 0 (application latency).
local _rip_recast_time = -99999
local _rake_recast_time = -99999

-- Form-switch throttle: prevent rapid cat↔travel form oscillation when OOC.
-- Any form cast sets this; subsequent form casts are blocked for FORM_SWITCH_COOLDOWN seconds.
local _last_form_shift_time = -100
local FORM_SWITCH_COOLDOWN = 5.0

-- Schema for safe_state: mirrors cat_state defaults. Fields NOT listed here
-- use spec_kit.SAFE_STATE_DEFAULTS (energy→0, combo_points→0, enemy_count→0, etc.).
-- Custom defaults override the kit defaults where cat needs different behavior.
local CAT_SCHEMA = {
    now = 0,
    now_ms = 0,
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
    healthstone_ready = 0,
    combat_time = 0,
    should_burst = false,
}

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
    local me = context.me or (NS.GetPlayer and NS.GetPlayer())
    if me then
        if _ok_cp_reader and type(_read_combo_points) == "function" then
            local cp = _read_combo_points(me, NS.POWER_COMBO)
            if type(cp) == "number" and cp >= 0 and cp <= 5 then return cp end
        end
    end

    local context_cp = context.combo_points
    if type(context_cp) ~= "number" then context_cp = context.cp end
    local has_context_cp = type(context_cp) == "number"
    if has_context_cp then return context_cp end

    if me then
        if type(me.get_combo_points) == "function" then
            local ok, cp = pcall(me.get_combo_points, me)
            if ok and type(cp) == "number" then return cp end
            ok, cp = pcall(me.get_combo_points, me, target)
            if ok and type(cp) == "number" then return cp end
        end
    end

    -- NS helpers (pcall-guarded; some builds expose a global combo-point reader)
    if NS.combo_points then
        local ok, cp = pcall(NS.combo_points)
        if ok and type(cp) == "number" then return cp end
        ok, cp = pcall(NS.combo_points, target)
        if ok and type(cp) == "number" then return cp end
    end
    if NS.get_combo_points then
        local ok, cp = pcall(NS.get_combo_points)
        if ok and type(cp) == "number" then return cp end
        ok, cp = pcall(NS.get_combo_points, target)
        if ok and type(cp) == "number" then return cp end
    end
    -- Global NS helpers and target-bound combo point fallbacks for builds where
    -- the player object does not expose the values directly.
    if NS.get_combo_points then
        local ok, cp = pcall(NS.get_combo_points, me, target)
        if ok and type(cp) == "number" then return cp end
        ok, cp = pcall(NS.get_combo_points)
        if ok and type(cp) == "number" then return cp end
    end
    if NS.combo_points then
        local ok, cp = pcall(NS.combo_points, target)
        if ok and type(cp) == "number" then return cp end
        ok, cp = pcall(NS.combo_points)
        if ok and type(cp) == "number" then return cp end
    end
    return 0
end

local function probe_combo_sources(me, context, resolved)
    if not NS._DEBUG_COMBO_POINTS or not NS.cp_debug then return end
    local parts = {}
    parts[#parts + 1] = "resolved=" .. tostring(resolved)
    parts[#parts + 1] = "context.combo_points=" .. tostring(context.combo_points)
    parts[#parts + 1] = "POWER_COMBO=" .. tostring(NS.POWER_COMBO)
    if me and type(me.combo_points_current) == "function" then
        local ok, cp = pcall(me.combo_points_current, me)
        parts[#parts + 1] = "combo_points_current=" .. (ok and tostring(cp) or "ERR")
    else
        parts[#parts + 1] = "combo_points_current=absent"
    end
    if me and type(me.get_power) == "function" then
        for _, idx in ipairs({ 3, 4, 5, 14 }) do
            local ok, cp = pcall(me.get_power, me, idx)
            parts[#parts + 1] = "get_power(" .. idx .. ")=" .. (ok and tostring(cp) or "ERR")
        end
    else
        parts[#parts + 1] = "get_power=absent"
    end
    NS.cp_debug(table.concat(parts, " "))
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

local function is_behind_target(target, context)
    if spec_kit.setting_bool(context, "cat_shred_positional", true) == false then return true end
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
    -- Delegate to shared helper (preserves cat behavior: no-snapshot -> skip, extra_window 1.5)
    if Snapshot then
        return Snapshot.should_upgrade(current_ap, snapshotted_ap, remains, refresh_window, ratio,
            { no_snapshot_refresh = false, extra_window = 1.5 })
    end
    -- Inline fallback (identical to prior behavior)
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

local function rip_ttd_floor(state)
    if (state.level or 70) < FEROCIOUS_BITE_LEVEL then return MIN_RIP_TTD_NO_BITE end
    return MIN_RIP_TTD
end

-- Determine whether Rip is intended for this target, accounting for user
-- settings that disable Rip or restrict it to elite/boss targets.
local function would_rip_fire(state, context)
    if not spec_kit.setting_bool(context, "cat_use_rip", true) then return false end
    if not target_lives(state, rip_ttd_floor(state)) then return false end
    if spec_kit.setting_bool(context, "cat_rip_elites_only", false) then
        if state.target_is_boss then return true end
        if (state.target_classification or 0) >= 1 then return true end
        return false
    end
    return true
end

local function prevent_cp_waste(state, added_cp)
    -- (state.combo_points or 0): nil combo_points -> arithmetic crash guard.
    return (state.combo_points or 0) + (added_cp or 1) <= 5
end

local function has_valid_target(context)
    return context.has_valid_enemy_target ~= false and context.target ~= nil
end

local function base_matches(context, action)
    if not action then return false end
    -- Generic action prerequisite checks. Individual match functions still own
    -- complex logic; this layer catches the simple declarative guards.
    if action.spell ~= nil and NS.spell_exists and not NS.spell_exists(action.spell) then
        return false
    end
    if action.min_energy then
        if get_energy(context) < action.min_energy then return false end
    end
    if action.min_combo then
        if get_combo_points(context, context.target) < action.min_combo then return false end
    end
    if action.requires_behind then
        if not is_behind_target(context.target, context) then return false end
    end
    if action.required_form == "cat" then
        if not ((NS.has_form and NS.has_form("cat")) or context.stance == STANCE_CAT or context.is_cat == true) then
            return false
        end
    end
    if action.requires_target == false then
        -- no target required; continue
    elseif action.target ~= "self" and action.requires_target ~= false then
        if not context.target then return false end
    end
    if action.matches and type(action.matches) == "function" then
        return action.matches(context, action)
    end
    return true
end

local function execute_action(context, action)
    local target
    if action.target == "self" or action.requires_target == false then
        target = context.me or NS.GetPlayer()
    else
        target = context.target
    end
    _opts.expected_cooldown = action.cooldown or nil
    _opts.skip_gcd = action.skip_gcd or nil
    return NS.try_cast(action.spell, target, "[CAT] " .. (action.name or ""), _opts)
end

local function record_shift(state)
    state.last_shift_time = state.now
    state.last_energy = 0
end

local function record_bleed_snapshot(action_name, state)
    if action_name == "Rip" or action_name == "RipSnapshot" or action_name == "RipExecute" then
        snapshot_state.rip_target = state.target
        snapshot_state.rip_ap = state.attack_power or 0
        snapshot_state.rip_cast_time = state.now
        _rip_recast_time = state.now
    elseif action_name == "Rake" or action_name == "RakeSnapshot" or action_name == "RakeTab" then
        snapshot_state.rake_target = state.target
        snapshot_state.rake_ap = state.attack_power or 0
        snapshot_state.rake_cast_time = state.now
        _rake_recast_time = state.now
    end
end

local build_state

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

build_state = function(context)
    local state = cat_state
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
    state.settings = context.settings or {}

    state.hp = context.hp or (NS.health_pct and NS.health_pct(me)) or 100
    state.mana_pct = get_mana_pct(context)
    state.energy = has_energy_context and get_energy(context) or ENERGY_CAP
    state.combo_points = get_combo_points(context, target)
    probe_combo_sources(me, context, state.combo_points)
    state.enemy_count = context.enemy_count or 1
    state.target_hp = context.target_hp or (NS.health_pct and NS.health_pct(target)) or 100
    state.target_ttd = context.ttd or context.target_ttd or 999
    state.target_ttd_known = (context.ttd ~= nil) or (context.target_ttd ~= nil)
    state.target_range = get_target_range(me, target, context)
    state.in_combat = context.in_combat == true
    state.is_pvp = context.is_pvp == true or spec_kit.setting_bool(context, "pvp_mode", false)
    state.is_player_target = is_target_player(target, context)
    state.is_mounted = context.is_mounted or false
    state.is_stealthed = context.is_stealthed == true or NS.buff_up(me, PROWL_BUFF) or false
    state.clearcasting = NS.buff_up(me, OMEN_OF_CLARITY_BUFF) or false
    state.has_tigers_fury = NS.buff_up(me, TIGERS_FURY_BUFF) or false
    state.has_dash = NS.buff_up(me, DASH_BUFF) or false
    state.has_barkskin = NS.buff_up(me, BARKSKIN_BUFF) or false
    state.has_track_humanoids = NS.buff_up(me, TRACK_HUMANOIDS_BUFF) or false
    state.has_wolfshead = has_wolfshead_equipped(me) or NS.buff_up(me, WOLFSHEAD_BUFF) or spec_kit.setting_bool(context, "cat_wolfshead_helm", false)
    state.has_bloodlust = NS.buff_up(me, BLOODLUST_BUFFS) or false
    state.rip_remains = NS.debuff_remains(target, RIP_DEBUFF) or 0
    state.rake_remains = NS.debuff_remains(target, RAKE_DEBUFF) or 0
    state.mangle_remains = NS.debuff_remains(target, MANGLE_DEBUFF) or 0
    state.faerie_fire_remains = NS.debuff_remains(target, FAERIE_FIRE_DEBUFF) or 0
    state.pounce_remains = NS.debuff_remains(target, POUNCE_DEBUFF) or 0
    state.maim_remains = NS.debuff_remains(target, MAIM_DEBUFF) or 0
    state.is_cat = NS.has_form and NS.has_form("cat") or context.stance == STANCE_CAT
    state.is_behind = is_behind_target(target, context)
    state.level = context.level or context.player_level or 70
    state.target_is_boss = context.target_is_boss == true or safe_method(target, "is_boss", false) == true
    state.target_classification = context.target_classification or safe_method(target, "get_classification", 0) or 0
    state.attack_power = get_attack_power(context, me)
    if _not_same_unit(snapshot_state.rip_target, target) then
        snapshot_state.rip_ap = 0
        snapshot_state.rip_cast_time = -99999
    elseif (state.rip_remains or 0) <= 0 and ((state.now or 0) - (snapshot_state.rip_cast_time or -99999)) > SNAPSHOT_RESET_GRACE then
        snapshot_state.rip_ap = 0
    end
    if _not_same_unit(snapshot_state.rake_target, target) then
        snapshot_state.rake_ap = 0
        snapshot_state.rake_cast_time = -99999
    elseif (state.rake_remains or 0) <= 0 and ((state.now or 0) - (snapshot_state.rake_cast_time or -99999)) > SNAPSHOT_RESET_GRACE then
        snapshot_state.rake_ap = 0
    end
    state.rip_ap = snapshot_state.rip_ap or 0
    state.rake_ap = snapshot_state.rake_ap or 0
    local ap = state.attack_power or 0
    state.has_high_ap_window = state.has_bloodlust or (ap > 0 and state.rip_ap > 0 and ap >= state.rip_ap * AP_UPGRADE_RATIO) or (ap > 0 and state.rake_ap > 0 and ap >= state.rake_ap * AP_UPGRADE_RATIO)
    update_energy_tick(state)
    state.should_execute = state.target_hp <= spec_kit.setting_number(context, "cat_execute_hp", EXECUTE_HP)
    local aoe_threshold = spec_kit.setting_number(context, "aoe_threshold", 3)
    state.should_aoe = (CombatMode and CombatMode.is_aoe(context.settings or {}, state.enemy_count, aoe_threshold))
        or (state.enemy_count >= aoe_threshold)
    state.should_tab_rake = state.enemy_count >= 2 and state.enemy_count <= 3
    state.should_pool_for_rip = (state.combo_points or 0) >= spec_kit.setting_number(context, "cat_rip_cp", 5) and (state.energy or 0) < RIP_COST and target_lives(state, MIN_RIP_TTD)
    state.should_pool_for_shred = (state.combo_points or 0) < 5 and (state.energy or 0) < SHRED_COST and (state.energy or 0) + ENERGY_PER_TICK >= SHRED_COST
    state.pooling = state.should_pool_for_rip or state.should_pool_for_shred
    state.should_powershift = false
    state.combat_time = context.combat_time or 0
    state.should_burst = context.should_burst == true or spec_kit.setting_bool(context, "cat_burst_mode", false)
    state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS) or 0
    if spec_kit.setting_bool(context, "cat_powershift_enabled", true) and state.is_cat and state.in_combat then
        -- Wowsims-aligned: powershift at <=25 energy (APL uses <=30; 25 is conservative for live play)
        local shift_energy = spec_kit.setting_number(context, "cat_powershift_energy", 25)
        local shift_gain = state.has_wolfshead and POWERSHIFT_GAIN_WOLFSHEAD or POWERSHIFT_GAIN_FUROR
        local useful_after = (state.energy or 0) + shift_gain >= math.min(ENERGY_CAP, SHRED_COST)
        state.should_powershift = state.energy <= shift_energy and state.combo_points <= POWERSHIFT_SAFE_CP and state.mana_pct >= POWERSHIFT_MIN_MANA and useful_after
    end
    -- safe_state proxy: structural nil-guard elimination (Pattern 14)
    return spec_kit.safe_state(state, CAT_SCHEMA)
end

-- ============================================================================
-- Declarative strategy DSL definitions
-- Replaces 8 imperative strategies with compiled DSL equivalents while preserving
-- the existing priority order via name-based substitution after the strategies
-- table is fully built.
-- ============================================================================
local DSL_DEFS = {
    {
        name = "HealthPotion",
        conditions = {
            { type = "custom", fn = function(context, state)
                -- Never break cat form to drink — using an item drops us out of
                -- form (lost DPS + re-shift mana). Only consume when un-shifted.
                return not state.is_cat
            end },
            { type = "in_combat" },
            { type = "setting", key = "use_auto_potions", op = "truthy", default = true },
            { type = "context", field = "has_health_potion", op = "truthy" },
            { type = "hp_threshold", op = "<=", value = 35 },
        },
        action = { type = "custom", fn = function(context)
            return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS)
        end },
    },
    {
        name = "ManaPotion",
        conditions = {
            { type = "custom", fn = function(context, state)
                -- Never break cat form to drink — using an item drops us out of
                -- form (lost DPS + re-shift mana). Only consume when un-shifted.
                return not state.is_cat
            end },
            { type = "in_combat" },
            { type = "setting", key = "use_auto_potions", op = "truthy", default = true },
            { type = "context", field = "has_mana_potion", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<=", value = 20 },
        },
        action = { type = "custom", fn = function(context)
            return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS)
        end },
    },
    {
        name = "RemoveCurse",
        conditions = {
            { type = "setting", key = "cat_auto_dispel", op = "truthy" },
            { type = "custom", fn = function(context, state)
                -- Remove Curse cannot be cast while shapeshifted (TBC, spell 2782).
                -- In cat form the client rejects it; a real druid shifts to caster,
                -- dispels, then shifts back. Only offer it out of form.
                if state.is_cat then return false end
                return NS.spell_ready(ACTION.RemoveCurse, NS.PLAYER_UNIT, { skip_range = true })
            end },
        },
        action = { type = "custom", fn = function()
            return NS.try_cast(ACTION.RemoveCurse, NS.PLAYER_UNIT, "[CAT] Remove Curse self", { skip_range = true })
        end },
    },
    {
        name = "Barkskin",
        conditions = {
            { type = "custom", fn = function(context, state)
                -- Barkskin cannot be cast while shapeshifted (TBC, spell 22812) — in
                -- cat form the client rejects the cast, so has_barkskin never becomes
                -- true and this would re-fire every frame below the HP threshold.
                -- Gate on caster form (mirrors bear_sylvanas.lua's is_bear guard).
                if state.is_cat then return false end
                local threshold = spec_kit.setting_number(context, "cat_barkskin_hp", 85)
                return (state.hp or 100) <= threshold and not state.has_barkskin
            end },
        },
        action = { type = "cast", spell = ACTION.Barkskin, target = "self" },
    },
    {
        name = "Dash",
        conditions = {
            { type = "custom", fn = function(context, state)
                if state.has_dash then return false end
                if not state.target or state.target_range <= MELEE_RANGE then return false end
                if state.target_range > 25 then return false end
                if not state.is_pvp and state.target_range < TRAVEL_FORM_RANGE then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Dash, target = "self" },
    },
    {
        name = "TigersFury",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not state.me and not NS.GetPlayer then return false end
                if state.has_tigers_fury then return false end
                -- Cooldown check: buff lasts 6s but CD is 30s; don't spam after buff expires
                if type(ACTION.TigersFury) == "table" and ACTION.TigersFury.cooldown_remaining then
                    local ok, cd = pcall(ACTION.TigersFury.cooldown_remaining, ACTION.TigersFury)
                    if ok and type(cd) == "number" and cd > 0 then return false end
                end
                if not state.in_combat then return false end
                if state.is_stealthed then return false end
                if state.target_ttd > 0 and state.target_ttd < SHORT_TTD then return false end
                local max_energy = safe_method_arg(state.me, "get_max_power", NS.POWER_ENERGY or 3, ENERGY_CAP) or ENERGY_CAP
                local fury_gain = TIGERS_FURY_ENERGY
                if not NS.spell_exists then fury_gain = POWERSHIFT_GAIN_WOLFSHEAD end
                if state.energy + fury_gain > max_energy then return false end
                if state.energy > ENERGY_CAP - TIGERS_FURY_ENERGY - 5 and state.next_tick_in <= 0.6 then return false end
                if (state.combo_points or 0) >= 5 and (state.energy or 0) >= RIP_COST then return false end
                if NS.debug and NS.log then
                    NS.log(string.format("[CAT-DIAG] TigersFury: in_combat=%s is_stealthed=%s has_tigers_fury=%s energy=%s cp=%s",
                        tostring(state.in_combat), tostring(state.is_stealthed), tostring(state.has_tigers_fury),
                        tostring(state.energy), tostring(state.combo_points)))
                end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.TigersFury, target = "self" },
    },
    {
        name = "CatForm",
        conditions = {
            { type = "custom", fn = function(context, state)
                if state.is_mounted then return false end
                if NS.has_form and NS.has_form("cat") then return false end
                if context.stance == STANCE_CAT then return false end
                if _last_form_shift_time > 0 and (get_now() - _last_form_shift_time) < FORM_SWITCH_COOLDOWN then return false end
                -- Avoid shifting OOC with no target or at a distant target (prevents no-target form spam)
                if not context.in_combat then
                    if not spec_kit.setting_bool(context, "cat_auto_cat_form", true) then return false end
                    if not state.target then return false end
                    local max_range = spec_kit.setting_number(context, "cat_form_target_range", 30)
                    if (state.target_range or 99) > max_range then return false end
                end
                -- Respect travel form for movement: if we're in travel form, OOC,
                -- moving toward a distant target, stay in travel form until closer.
                if not context.in_combat and context.is_moving and (context.target_range or 0) >= TRAVEL_FORM_RANGE then
                    if NS.has_form and NS.has_form("travel") then return false end
                    if context.stance == 4 then return false end
                end
                return true
            end },
        },
        action = { type = "custom", fn = function(context)
            local ok = NS.try_cast(ACTION.CatForm, context.me or NS.GetPlayer(), "[CAT] Cat Form", { skip_range = true })
            if ok then _last_form_shift_time = get_now() end
            return ok
        end },
    },
    {
        name = "Prowl",
        conditions = {
            { type = "in_combat", invert = true },
            { type = "state", field = "is_stealthed", op = "!=", value = true },
            { type = "custom", fn = function(context, state)
                if not spec_kit.setting_bool(context, "cat_auto_prowl", true) then return false end
                if state.target and state.target_range > 18 then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Prowl, target = "self", label = "[CAT] Prowl", opts = {} },
    },
}

local function track_humanoids_matches(context, action)
    local state = build_state(context)
    if state.in_combat then return false end
    if state.has_track_humanoids then return false end
    if state.is_player_target then return false end
    if not state.is_pvp then return false end
    return true
end

local function pounce_matches(context, action)
    local state = build_state(context)
    if not state.is_stealthed then return false end
    if state.in_combat then return false end
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
    if not state.is_behind then return false end
    if spell_exists(ACTION.MangleCat) and state.mangle_remains <= 0 then return false end
    return true
end

local function stealth_mangle_matches(context, action)
    -- Soft-gate: Mangle talent (~50); do not match when unlearned.
    if not spell_exists(ACTION.MangleCat) then return false end
    local state = build_state(context)
    if not state.is_stealthed then return false end
    if state.energy < MANGLE_COST then return false end
    return true
end

local function travel_form_matches(context, action)
    local state = build_state(context)
    -- Default off — users opt-in via setting to prevent surprise form spam.
    if not spec_kit.setting_bool(context, "cat_auto_travel_form", false) then return false end
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
    if state.is_stealthed then return false end
    if state.faerie_fire_remains > FAERIE_FIRE_REFRESH then return false end
    if is_low_level(state.level) then return true end
    -- Use on players or long living targets even if armor check fails (for level 42+)
    if state.is_pvp or state.is_player_target or target_lives(state, LONG_TTD) then
        return true
    end
    -- Skip if target has no armor (API unavailable or already fully reduced)
    if (context.target_armor or 0) <= 0 then return false end
    return target_lives(state, LONG_TTD)
end

local function faerie_fire_stealth_matches(context, action)
    local state = build_state(context)
    if not state.is_stealthed then return false end
    if not state.is_pvp and not state.is_player_target then return false end
    -- Skip if target has no armor (API unavailable or already fully reduced)
    if (context.target_armor or 0) <= 0 then return false end
    if state.faerie_fire_remains > FAERIE_FIRE_REFRESH then return false end
    local creature_type = safe_method(state.target, "get_creature_type", nil)
    if creature_type and not STEALTH_PREVENT_TYPES[creature_type] then return false end
    return true
end

local function mangle_debuff_matches(context, action)
    -- Soft-gate: Mangle is a talent (learn ~50); do not hard-require before learned.
    if not spell_exists(ACTION.MangleCat) then return false end
    local state = build_state(context)
    if state.mangle_remains > MANGLE_REFRESH_WINDOW then return false end
    if should_wait_for_tick(state, MANGLE_COST) then return false end
    return true
end

-- Returns true if Rip would match right now, without side effects. Used by
-- Ferocious Bite strategies to decide whether to defer to Rip.
-- Always returns false so gate call sites can `return rip_reject(...)` inline.
local function rip_reject(reason, extra)
    if not NS._DEBUG_COMBO_POINTS or not NS.cp_debug then return false end
    NS.cp_debug("[Rip] BLOCKED by " .. reason .. (extra and (" " .. extra) or ""))
    return false
end

local function rip_matches_now(context, state)
    if not state then state = build_state(context) end
    if NS._DEBUG_COMBO_POINTS and NS.cp_debug then
        local rip_id
        if ACTION.Rip and type(ACTION.Rip.id) == "function" then
            local ok, v = pcall(ACTION.Rip.id, ACTION.Rip)
            rip_id = ok and v or "ERR"
        end
        NS.cp_debug("[Rip] resolved_spell_id=" .. tostring(rip_id))
    end
    if not would_rip_fire(state, context) then
        return rip_reject("would_rip_fire",
            "use_rip=" .. tostring(spec_kit.setting_bool(context, "cat_use_rip", true)) ..
            " ttd=" .. tostring(state.target_ttd) .. " (needs >=" .. rip_ttd_floor(state) .. " or 0/nil)" ..
            " level=" .. tostring(state.level) ..
            " elites_only=" .. tostring(spec_kit.setting_bool(context, "cat_rip_elites_only", false)) ..
            " boss=" .. tostring(state.target_is_boss) ..
            " classification=" .. tostring(state.target_classification))
    end
    local required_cp = spec_kit.setting_number(context, "cat_rip_cp", 5)
    if is_low_level(state.level) then required_cp = math.min(required_cp, 4) end
    if not state.target then return rip_reject("no-target") end
    if (state.combo_points or 0) < required_cp then
        return rip_reject("combo_points", "cp=" .. tostring(state.combo_points) .. " required=" .. tostring(required_cp) .. " level=" .. tostring(state.level))
    end
    -- Post-cast grace: don't recast Rip while the debuff API still reads 0 right
    -- after a cast (application latency); wait out POST_CAST_GRACE first.
    if (state.rip_remains or 0) <= 0 and ((state.now or 0) - _rip_recast_time) < POST_CAST_GRACE then
        return rip_reject("post-cast-grace", "since_cast=" .. tostring((state.now or 0) - _rip_recast_time) .. " grace=" .. POST_CAST_GRACE)
    end
    -- TTD gating is already enforced by would_rip_fire -> target_lives(MIN_RIP_TTD=10);
    -- no separate < 6s re-check is reachable when would_rip_fire passed with a known TTD.
    if should_wait_for_tick(state, RIP_COST) then
        return rip_reject("energy-tick-pooling", "energy=" .. tostring(state.energy) .. " cost=" .. RIP_COST)
    end
    if not should_snapshot_upgrade(state.attack_power, state.rip_ap, state.rip_remains, RIP_REFRESH_WINDOW, AP_UPGRADE_RATIO) then
        return rip_reject("snapshot-upgrade", "ap=" .. tostring(state.attack_power) .. " rip_ap=" .. tostring(state.rip_ap) .. " remains=" .. tostring(state.rip_remains))
    end
    if NS._DEBUG_COMBO_POINTS and NS.cp_debug then NS.cp_debug("[Rip] ALL GATES PASS -> should cast") end
    return true
end

local function rip_matches(context, action)
    local state = build_state(context)
    return rip_matches_now(context, state)
end

-- ============================================================================
-- Rip Trick (advanced micro-optimization from wowsims feral rotation)
-- Casts Rip at 1+ CP when energy is in the narrow [RIP_COST, MANGLE_COST)
-- window -- you can afford Rip but not Mangle, so Rip now > waiting.
-- Only fires when powershifting mana is available. Opt-in (default off).
-- Source: wowsims_classic/sim/druid/feral/rotation.go canRipTrick
local function rip_trick_matches(context, action)
    local state = build_state(context)
    if not spec_kit.setting_bool(context, "cat_use_rip_trick", false) then return false end
    if not would_rip_fire(state, context) then return false end
    if not state.target then return false end
    if not state.is_cat or not state.in_combat then return false end
    if (state.mana_pct or 100) < POWERSHIFT_MIN_MANA then return false end
    if (state.combo_points or 0) < 1 then return false end
    if (state.rip_remains or 0) > 0 then return false end
    -- TTD gating is already enforced by would_rip_fire -> target_lives(MIN_RIP_TTD=10);
    -- no separate < 6s re-check is reachable when would_rip_fire passed with a known TTD.
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
    if not spec_kit.setting_bool(context, "cat_use_shred_trick", false) then return false end
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
    if not would_rip_fire(state, context) then return false end
    local required_cp = spec_kit.setting_number(context, "cat_rip_cp", 5)
    if state.combo_points < required_cp then return false end
    if state.rip_remains <= RIP_REFRESH_WINDOW then return false end
    if state.rip_ap <= 0 then return false end
    -- Use lower threshold during bloodlust/high-AP windows to catch the snapshot opportunity
    local ratio = state.has_high_ap_window and HIGH_AP_UPGRADE_RATIO or STRONG_AP_UPGRADE_RATIO
    if state.attack_power < state.rip_ap * ratio then return false end
    return true
end

local function bite_matches(context, action)
    local state = build_state(context)
    local required_cp = spec_kit.setting_number(context, "cat_ferocious_bite_cp", 5)
    if is_low_level(state.level) then required_cp = math.min(required_cp, 4) end
    if (state.combo_points or 0) < required_cp then return false end
    -- Only defer to Rip if Rip will actually be cast right now. When Rip is
    -- disabled, elites-only on a non-elite, or not ready, spend CP on Ferocious Bite.
    if rip_matches_now(context, state) then return false end
    if should_wait_for_tick(state, BITE_COST) then return false end
    return true
end

local function bite_trick_matches(context, action)
    local state = build_state(context)
    if not state.in_combat then return false end
    if spec_kit.setting_bool(context, "cat_use_ferocious_bite", true) == false then return false end
    if (state.combo_points or 0) < 5 then return false end
    local bite_max_energy = spec_kit.setting_number(context, "cat_bite_max_energy", 100)
    if (state.energy or 0) > bite_max_energy then return false end
    if (state.energy or 0) < BITE_COST then return false end
    if state.next_tick_in <= 0.1 then return false end
    if rip_matches_now(context, state) then return false end
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
    if (state.combo_points or 0) >= 5 then return false end
    -- Post-cast grace: don't recast Rake while the debuff API still reads 0 right
    -- after a cast (application latency); wait out POST_CAST_GRACE first.
    if (state.rake_remains or 0) <= 0 and ((state.now or 0) - _rake_recast_time) < POST_CAST_GRACE then return false end
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
    if (state.combo_points or 0) >= 5 then return false end
    action.min_energy = CLEARCASTING_COST_FLOOR
    return true
end

local function shred_matches(context, action)
    local state = build_state(context)
    if (state.combo_points or 0) >= 5 then return false end
    if not state.is_behind then return false end
    if state.pooling and (state.energy or 0) < SHRED_COST then return false end
    if spell_exists(ACTION.MangleCat) and state.mangle_remains <= MANGLE_REFRESH_WINDOW and target_lives(state, MIN_RAKE_TTD) then return false end
    if should_wait_for_tick(state, SHRED_COST) then return false end
    return true
end

local function mangle_filler_matches(context, action)
    -- Soft-gate: Mangle talent (~50); ClawFallback covers builders when unlearned.
    if not spell_exists(ACTION.MangleCat) then return false end
    local state = build_state(context)
    if (state.combo_points or 0) >= 5 then return false end
    if state.is_behind and spell_ready(ACTION.Shred, state.target, nil) and (state.energy or 0) >= SHRED_COST then return false end
    if should_wait_for_tick(state, MANGLE_COST) then return false end
    return true
end

local function claw_matches(context, action)
    local state = build_state(context)
    if (state.combo_points or 0) >= 5 then return false end
    if spell_exists(ACTION.MangleCat) then return false end
    if should_wait_for_tick(state, 45) then return false end
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
    if not spec_kit.setting_bool(context, "cat_powershift_enabled", true) then return false end
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
    if state.combo_points < spec_kit.setting_number(context, "cat_ferocious_bite_cp", 5) then return false end
    -- Only pool when an energy tick is about to give us enough energy for FB.
    -- When energy is well below BITE_COST with no imminent tick, return false so
    -- the lower-priority FerociousBite strategy can attempt the cast (and fail
    -- gracefully) instead of being blocked by this no-op strategy.
    return should_wait_for_tick(state, BITE_COST)
end

local function execute_bite(context)
    -- Execute phase: target is dying — spend combo points on FerociousBite immediately.
    local target = context.target
    _opts.expected_cooldown = nil
    _opts.skip_gcd = nil
    return NS.try_cast(ACTION.FerociousBite, target, "[CAT] PoolForExecuteBite", _opts)
end

local ACTIONS = {
    { name = "CatForm", spell = ACTION.CatForm, target = "self", kind = "form", form = "cat", requires_target = false, matches = function() return false end },
    { name = "TravelForm", spell = ACTION.TravelForm, target = "self", kind = "form", form = "travel", requires_target = false, matches = travel_form_matches },
    { name = "TrackHumanoids", spell = ACTION.TrackHumanoids, target = "self", kind = "buff", buff = TRACK_HUMANOIDS_BUFF, required_form = "cat", requires_target = false, matches = track_humanoids_matches },
    { name = "Prowl", spell = ACTION.Prowl, target = "self", kind = "buff", buff = PROWL_BUFF, ooc = true, required_form = "cat", requires_target = false, matches = function() return false end },

    { name = "Barkskin", spell = ACTION.Barkskin, target = "self", required_form = "cat", requires_target = false, matches = function() return false end },

    { name = "PounceOpener", spell = ACTION.Pounce, requires_buff = PROWL_BUFF, required_form = "cat", min_energy = POUNCE_COST, matches = pounce_matches },
    { name = "RavageOpener", spell = ACTION.Ravage, requires_buff = PROWL_BUFF, required_form = "cat", requires_behind = true, min_energy = RAVAGE_COST, matches = ravage_matches },
    { name = "StealthShred", spell = ACTION.Shred, requires_buff = PROWL_BUFF, required_form = "cat", requires_behind = true, min_energy = SHRED_COST, matches = stealth_shred_matches },
    { name = "StealthMangle", spell = ACTION.MangleCat, requires_buff = PROWL_BUFF, required_form = "cat", min_energy = MANGLE_COST, matches = stealth_mangle_matches },

    { name = "Dash", spell = ACTION.Dash, target = "self", required_form = "cat", requires_target = false, matches = function() return false end },
    { name = "FeralChargeCat", spell = ACTION.FeralCharge, target = "self", required_form = "cat", requires_target = false, matches = function(context) return context.in_combat and context.target and context.target_range and context.target_range >= 8 and context.target_range <= 25 end },

    { name = "MaimInterrupt", spell = ACTION.Maim, required_form = "cat", min_energy = MAIM_COST, min_combo = 1, matches = maim_interrupt_matches },
    { name = "FaerieFireStealthLock", spell = ACTION.FaerieFireFeral, required_form = "cat", matches = faerie_fire_stealth_matches },
    { name = "FaerieFireFeral", spell = ACTION.FaerieFireFeral, required_form = "cat", debuff = FAERIE_FIRE_DEBUFF, refresh = FAERIE_FIRE_REFRESH, matches = faerie_fire_matches },
    { name = "MangleDebuff", spell = ACTION.MangleCat, required_form = "cat", min_energy = MANGLE_COST, debuff = MANGLE_DEBUFF, refresh = MANGLE_REFRESH_WINDOW, matches = mangle_debuff_matches },

    { name = "RipSnapshot", spell = ACTION.Rip, required_form = "cat", min_energy = RIP_COST, min_combo = 5, matches = rip_snapshot_matches },
    { name = "RipTrick", spell = ACTION.Rip, required_form = "cat", min_energy = RIP_COST, min_combo = 1, matches = rip_trick_matches },
    { name = "Rip", spell = ACTION.Rip, required_form = "cat", min_energy = RIP_COST, min_combo = 3, matches = rip_matches },
    { name = "FerociousBite", spell = ACTION.FerociousBite, required_form = "cat", min_energy = BITE_COST, min_combo = 3, matches = bite_matches },
    { name = "FerociousBiteTtd", spell = ACTION.FerociousBite, required_form = "cat", min_energy = BITE_COST, min_combo = 3, matches = emergency_bite_matches },
    { name = "BiteTrick", spell = ACTION.FerociousBite, required_form = "cat", min_energy = BITE_COST, min_combo = 5, matches = bite_trick_matches },
    { name = "MaimControl", spell = ACTION.Maim, required_form = "cat", min_energy = MAIM_COST, min_combo = 3, matches = maim_control_matches },

    { name = "TigersFury", spell = ACTION.TigersFury, target = "self", required_form = "cat", requires_target = false, cooldown = 30, matches = function() return false end },
    { name = "Powershift", spell = ACTION.CatForm, target = "self", skip_gcd = true, requires_target = false, matches = powershift_matches },
    { name = "EmergencyPowershift", spell = ACTION.CatForm, target = "self", skip_gcd = true, requires_target = false, matches = emergency_powershift_matches },

    { name = "RakeSnapshot", spell = ACTION.Rake, required_form = "cat", min_energy = RAKE_COST, matches = rake_snapshot_matches },
    { name = "RakeTab", spell = ACTION.Rake, required_form = "cat", min_energy = RAKE_COST, matches = rake_tab_matches },
    { name = "Rake", spell = ACTION.Rake, required_form = "cat", min_energy = RAKE_COST, matches = rake_matches },
    { name = "ShredOmen", spell = ACTION.Shred, required_form = "cat", requires_behind = true, matches = clearcasting_shred_matches },
    { name = "ShredTrick", spell = ACTION.Shred, required_form = "cat", requires_behind = true, min_energy = SHRED_COST, matches = shred_trick_matches },
    { name = "Shred", spell = ACTION.Shred, required_form = "cat", requires_behind = true, min_energy = SHRED_COST, matches = shred_matches },
    { name = "MangleFiller", spell = ACTION.MangleCat, required_form = "cat", min_energy = MANGLE_COST, matches = mangle_filler_matches },
    { name = "ClawFallback", spell = ACTION.Claw, required_form = "cat", min_energy = 45, matches = claw_matches },
}

local strategies = {
    { name = "HealthPotion" },
    { name = "ManaPotion" },
    { name = "EngineeringBomb",
      matches = function(context, s)
          if not engineering then return false end
          if not engineering.should_use_bomb(context) then return false end
          -- Wowsims feral cat: engineering at energy <= 30 (filler during downtime)
          if (s.energy or 100) > 30 then return false end
          return true
      end,
      execute = function(context) return engineering.use_best_bomb(context) end },
    { name = "RemoveCurse",
      matches = function(context)
          if not spec_kit.setting_bool(context, "cat_auto_dispel", false) then return false end
          return NS.spell_ready(ACTION.RemoveCurse, NS.PLAYER_UNIT, { skip_range = true })
      end,
      execute = function() return NS.try_cast(ACTION.RemoveCurse, NS.PLAYER_UNIT, "[CAT] Remove Curse self", { skip_range = true }) end },
    { name = "PoolForRip",
      matches = function(context)
          local state = build_state(context)
          return state.should_pool_for_rip == true and should_wait_for_tick(state, RIP_COST)
      end,
      execute = function() return true end },  -- no-op: just wait for energy tick
    { name = "PoolForBuilderTick",
      matches = pool_for_builder_matches,
      execute = function() return true end },  -- no-op: just wait for energy tick
    { name = "PoolForExecuteBite", matches = wait_execute, execute = execute_bite },
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
        -- Never break cat form to use a healthstone — it drops us out of form.
        if state.is_cat then return false end
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

-- Replace the 6 imperative strategies with compiled DSL equivalents by name.
-- Name-based substitution keeps the priority order intact even though the
-- strategies table is built partly by looping over the ACTIONS table.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("cat", strategies, { get_state = build_state })
end
if NS.log then NS.log("Druid cat rotation registered") end
return { strategies = strategies, build_state = build_state }
