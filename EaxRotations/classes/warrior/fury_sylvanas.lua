-- fury_sylvanas.lua — Warrior Fury rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies (BT → WW → Rampage → Execute → Slam → rage dumps).
-- WHEN:  combat with valid enemy target, dual-wield or 2H.
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.
-- SAFETY: state.* reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

-- Warrior Fury priority list — parity v1.0.6+ parity (auto-charge, rampage stacks, sunder, rend, overpower, defensives)
local NS = _G.EaxRotations
if not NS then return nil end
local _cleu = NS.SwingDiagnostics
if _cleu then
    _cleu.register_seals({
        1464, 8820, 11604, 11605, 25241, 25242,
        78, 284, 285, 1608, 11584, 11585, 25286,
    })
end
local potion_helper = require("shared/potion_helper_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")
local HitCap = require("shared/hit_cap_tracker_sylvanas")
local WH = require("classes/warrior/shared_helpers_sylvanas") or {}
local _planner_ok, planner = pcall(require, "shared/cooldown_planner_sylvanas")
local _eng_ok, engineering = pcall(require, "shared/engineering_helper_sylvanas")
if not _eng_ok or type(engineering) ~= "table" then engineering = nil end
if not _planner_ok or type(planner) ~= "table" then planner = nil end
local BLOODLUST_BUFFS = { 2825, 32182 }
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }
local PLAYER_UNIT = NS.PLAYER_UNIT


-- Centralized spell resolver via spec_kit (replaces the per-spec spell() helper).
local define = spec_kit.define_action_for_class(SPELLS)

-- Spell actions — resolved via spec_kit.define_action_for_class (rank IDs from DBC).
-- Spells with expansion-aware IDs in class_sylvanas.lua (DeathWish, SweepingStrikes)
-- use SPELLS.X directly; all others use define() with explicit rank ID arrays.
local ACTION = {
    BattleShout = define("BattleShout", { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
    BattleStance = define("BattleStance", 2457, "BattleStance"),
    BerserkerRage = define("BerserkerRage", 18499, "BerserkerRage"),
    BerserkerStance = define("BerserkerStance", 2458, "BerserkerStance"),
    Bloodrage = define("Bloodrage", 2687, "Bloodrage"),
    Bloodthirst = define("Bloodthirst", { 30335, 25251, 23894, 23893, 23892, 23881 }, "Bloodthirst"),
    Charge = define("Charge", { 11578, 6178, 100 }, "Charge"),
    Cleave = define("Cleave", { 25231, 20569, 11609, 11608, 7369, 845 }, "Cleave"),
    CommandingShout = define("CommandingShout", 469, "CommandingShout"),
    DeathWish = SPELLS.DeathWish,  -- expansion-aware IDs from class_sylvanas.lua
    DefensiveStance = define("DefensiveStance", 71, "DefensiveStance"),
    DemoralizingShout = define("DemoralizingShout", { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }, "DemoralizingShout"),
    Execute = define("Execute", { 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
    Hamstring = define("Hamstring", { 25212, 7373, 7372, 1715 }, "Hamstring"),
    HeroicStrike = define("HeroicStrike", { 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    Intercept = define("Intercept", { 25275, 20617, 20616, 20252 }, "Intercept"),
    Overpower = define("Overpower", { 11585, 11584, 7887, 7384 }, "Overpower"),
    Pummel = NS.spell_action and NS.spell_action({ 6554, 6552 }, "Pummel") or 6554,
    Rampage = define("Rampage", { 30033, 30030, 29801 }, "Rampage"),
    Recklessness = define("Recklessness", 1719, "Recklessness"),
    Rend = define("Rend", { 25208, 11574, 11573, 6548, 6547, 772 }, "Rend"),
    Slam = define("Slam", { 25242, 25241, 11605, 11604, 8820, 1464 }, "Slam"),
    SunderArmor = define("SunderArmor", { 25225, 11597, 11596, 8380, 7405, 7386 }, "SunderArmor"),
    SweepingStrikes = SPELLS.SweepingStrikes,  -- expansion-aware IDs from class_sylvanas.lua
    ThunderClap = define("ThunderClap", { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
    VictoryRush = define("VictoryRush", 34428, "VictoryRush"),
    Whirlwind = define("Whirlwind", 1680, "Whirlwind"),
}

-- Buff/debuff ID tables
local BATTLE_SHOUT_BUFF = CONSTANTS.BATTLE_SHOUT_IDS or { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
local COMMANDING_SHOUT_BUFF = CONSTANTS.COMMANDING_SHOUT_BUFF or { 469 }
local BERSERKER_RAGE_BUFF = { 18499 }
local SWEEPING_STRIKES_BUFF = { 12328 }
local VICTORY_RUSH_BUFF = { 34428 }
local RAMPAGE_BUFF = { 30029, 30031, 30032, 29801, 30030, 30033 }
-- Rampage AURAS (the buff applied by each rank): r1=30029, r2=30031, r3=30032.
-- The cast spell IDs (29801/30030/30033) are NOT the buff; included for safety so
-- buff_up/buff_stacks match regardless of which ID the runtime tracks.
local SUNDER_DEBUFF = CONSTANTS.SUNDER_DEBUFF or { 25225, 11597, 11596, 8380, 7405, 7386 }
local REND_DEBUFF = { 25208, 11574, 11573, 6548, 6547, 772 }
local DEMO_SHOUT_DEBUFF = CONSTANTS.DEMO_SHOUT_DEBUFF or { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
local THUNDER_CLAP_DEBUFF = CONSTANTS.THUNDER_CLAP_DEBUFF or { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
local HAMSTRING_DEBUFF = { 25212, 7373, 7372, 1715 }

-- Crowd-control debuff IDs for fear-break detection (Berserker Rage)
local FEAR_DEBUFF_IDS = {
    [5782] = true, [6215] = true, [5484] = true,   -- Warlock Fear / Howl
    [8122] = true, [10888] = true, [10890] = true, -- Psychic Scream
    [5246] = true,                                  -- Intimidating Shout
    [33111] = true,                                 -- Bellowing Roar (Nightbane)
    [39415] = true,                                 -- Fear (Skyriss)
    [19134] = true,                                 -- Frightening Shout (Fel Overseer)
    [46561] = true,                                 -- Fear (Sunblade Dusk Priest SWP)
    [34984] = true,                                 -- Psychic Horror (Fen Ray Underbog)
    [38660] = true,                                 -- Fear (Coilfang Siren Steamvault)
    [32830] = true,                                 -- Possess (Auchenai Crypts MC)
}
local SAP_DEBUFF_IDS = {
    [6770] = true, [2070] = true, [11297] = true,  -- Sap
}
local INCAP_DEBUFF_IDS = {
    [1776] = true, [1777] = true, [8629] = true,   -- Gouge
    [20066] = true,                                 -- Repentance
    [3355] = true,                                  -- Freezing Trap
}

local function is_feared_sapped_or_incapacitated(unit)
    if not unit then return false end
    for id in pairs(FEAR_DEBUFF_IDS) do
        if NS.debuff_up and NS.debuff_up(unit, id) then return true, "fear" end
    end
    for id in pairs(SAP_DEBUFF_IDS) do
        if NS.debuff_up and NS.debuff_up(unit, id) then return true, "sap" end
    end
    for id in pairs(INCAP_DEBUFF_IDS) do
        if NS.debuff_up and NS.debuff_up(unit, id) then return true, "incapacitate" end
    end
    return false
end

-- Healthstone and health potion item IDs (TBC, best to worst)
local HEALTHSTONE_IDS = { 22116, 22105, 22104, 22103, 22102, 22101 }
local HEALTH_POTION_IDS = { 22829, 28102, 13446, 13442, 3928, 1710 }

-- Constants
local EXECUTE_DEFAULT_RAGE = 25
local BLOODTHIRST_RESERVE = 30
local WHIRLWIND_RESERVE = 25
local CORE_POOL_WINDOW = 2.0
local SLAM_RAGE_COST = 15
local SLAM_CAST_TIME = 0.5
local SLAM_SAFETY = 0.2
local HEROIC_STRIKE_RAGE = 60
local CLEAVE_RAGE = 55
local STANCE_CAST_LOCKOUT = 2.0
local TACTICAL_MASTERY_CAP = 25
local last_stance_cast_at = 0  -- fallback only; WH tracks its own copy when loaded

-- Configure shared module with spec-specific constants
WH.CAST_TAG = "[FURY]"
WH.TACTICAL_MASTERY_CAP = TACTICAL_MASTERY_CAP
WH.STANCE_CAST_LOCKOUT = STANCE_CAST_LOCKOUT

-- Schema for safe_state: custom defaults override kit defaults.
local FURY_SCHEMA = {
    stance = STANCE.BERSERKER,
    enemy_count = 1,
    is_pvp = false,
    in_combat = false,
    is_moving = false,
    target_is_casting = false,
    target_casting_interruptible = false,
    ttd = 0,
    has_battle_shout = false,
    has_commanding_shout = false,
    has_berserker_rage = false,
    berserker_rage_ready = false,
    has_sweeping_strikes = false,
    has_rampage = false,
    rampage_stacks = 0,
    victory_rush_ready = false,
    sunder_stacks = 0,
    rend_remains = 0,
    hamstring_remains = 0,
    demo_remains = 0,
    tclap_remains = 0,
    bt_cd = 99,
    ww_cd = 99,
    bt_ready = false,
    ww_ready = false,
    execute_ready = false,
    slam_ready = false,
    sweeping_ready = false,
    heroic_ready = false,
    cleave_ready = false,
    pummel_ready = false,
    intercept_ready = false,
    charge_ready = false,
    hamstring_ready = false,
    overpower_ready = false,
    execute_phase = false,
    death_wish_ready = false,
    recklessness_ready = false,
    bloodrage_ready = false,
    victory_ready = false,
    sunder_ready = false,
    rend_ready = false,
    demo_ready = false,
    healthstone_ready = false,
    healthstone_id = nil,
    health_potion_ready = false,
    health_potion_id = nil,
    has_offhand = false,
    mh_until = 999,
    mh_progress = 0,
    oh_until = 999,
    ss_cd = 99,
    target_in_combat = false,
    charge_lock_until = 0,
    intercept_fired_at = 0,
    aoe_cc_nearby = false,
    hit_cap_pct = 9,
    hit_cap_rating_needed = 142,
    expertise_soft_cap = 26,
    expertise_hard_cap = 56,
}

local stance_lockout_active = WH.stance_lockout_active or function()
    return (NS.time_now and NS.time_now() or 0) < last_stance_cast_at + STANCE_CAST_LOCKOUT
end


-- Test assertion strings (preserved for regression tests)
-- Action fields referenced via build_action() in strategy specs

-- State table
local fury_state = {
    rage = 0,
    hp = 100,
    target_hp = 100,
    stance = STANCE.BERSERKER,
    enemy_count = 1,
    is_pvp = false,
    in_combat = false,
    is_moving = false,
    target_distance = 0,
    target_is_casting = false,
    target_casting_interruptible = false,
    ttd = 0,
    has_battle_shout = false,
    has_commanding_shout = false,
    has_berserker_rage = false,
    berserker_rage_ready = false,
    has_sweeping_strikes = false,
    has_rampage = false,
    rampage_stacks = 0,
    victory_rush_ready = false,
    sunder_stacks = 0,
    rend_remains = 0,
    hamstring_remains = 0,
    demo_remains = 0,
    tclap_remains = 0,
    bt_cd = 99,
    ww_cd = 99,
    bt_ready = false,
    ww_ready = false,
    execute_ready = false,
    slam_ready = false,
    sweeping_ready = false,
    heroic_ready = false,
    cleave_ready = false,
    pummel_ready = false,
    intercept_ready = false,
    charge_ready = false,
    hamstring_ready = false,
    overpower_ready = false,
    execute_phase = false,
    death_wish_ready = false,
    recklessness_ready = false,
    bloodrage_ready = false,
    victory_ready = false,
    sunder_ready = false,
    rend_ready = false,
    demo_ready = false,
    -- Charge/Intercept protection
    charge_lock_until = 0,
    intercept_fired_at = 0,
    
    healthstone_ready = false,
    healthstone_id = nil,
    health_potion_ready = false,
    health_potion_id = nil,
}

-- Helper functions (extracted to shared_helpers_sylvanas; fallbacks kept if module missing)
-- settings now delegated to spec_kit.setting_*() (Pattern 8)

local bool_call = WH.bool_call or function(unit, method)
    if not unit or type(unit[method]) ~= "function" then return false end
    local ok, value = pcall(unit[method], unit)
    return ok and value == true
end

local execute_phase = WH.execute_phase or function(context, state)
    if NS.is_execute_phase then return NS.is_execute_phase(context.target_hp, 20) end
    if (state.target_hp or context.target_hp or 100) <= 20 then return true end
    -- TTD awareness: treat as execute phase if target is dying soon
    if (state.ttd or 0) > 0 and (state.ttd or 0) < 15 then return true end
    return false
end

local preserved_rage_after_swap = WH.preserved_rage_after_swap or function(rage)
    if NS.get_tactical_mastery_cap then return NS.get_tactical_mastery_cap() end
    local cap = TACTICAL_MASTERY_CAP or 25
    return (rage or 0) < cap and (rage or 0) or cap
end

local stance_swap_safe = WH.stance_swap_safe or function(state, cost)
    local effective_cost = math.min(cost or 0, 15)
    if state.stance == nil then return true end
    return preserved_rage_after_swap(state.rage or 0) >= effective_cost
end

local desired_stance = WH.desired_stance or function(context)
    local preference = spec_kit.setting(context, "stance_preference", "auto")
    if preference == "battle" or preference == STANCE.BATTLE then return STANCE.BATTLE end
    if preference == "defensive" or preference == STANCE.DEFENSIVE then return STANCE.DEFENSIVE end
    if preference == "berserker" or preference == STANCE.BERSERKER then return STANCE.BERSERKER end
    return nil
end

local action = WH.action or function(context, row)
    if not context or not row then return false end
    if not row.spell then return true end
    local target = (row.target == "self" or row.requires_target == false) and (context.me or NS.GetPlayer()) or context.target
    if not target then return false end
        if row.min_rage and context.rage and context.rage < row.min_rage then return false end
    if row.required_stance and context.stance ~= row.required_stance then return false end
    local opts = {}
    if row.requires_target == false then opts.skip_range = true end
    if row.cooldown then opts.expected_cooldown = row.cooldown end
    return NS.spell_ready(row.spell, target, opts)
end

local cast = WH.cast or function(context, row)
    if not context or not row then return false end
    if not row.spell then return false end
    local target = (row.target == "self" or row.requires_target == false) and (context.me or NS.GetPlayer()) or context.target
    if not target then return false end
    local opts = {}
    if row.requires_target == false then opts.skip_range = true end
    if row.cooldown then opts.expected_cooldown = row.cooldown end
    local ok = NS.try_cast(row.spell, target, "[FURY]", opts)
    if ok and row.kind == "form" then
        last_stance_cast_at = NS.time_now and NS.time_now() or 0
    end
    return ok
end

local build_action = WH.build_action or function(name, spell_value, opts)
    local row = opts or {}
    row.name = name
    row.spell = spell_value
    return row
end

-- ============================================================================
-- State builder
-- ============================================================================
local _last_build_state_time = -1
local function build_state(context)
    local state = fury_state
    local now = context.now
    if now and now == _last_build_state_time then return state end
    now = now or (NS.time_now and NS.time_now() or 0)
    if context.now then _last_build_state_time = now end
    state.now = now

    local is_group = context.is_group or false
    state.is_group = is_group
    local target = context.target
    local me = context.me or NS.GetPlayer()

    fury_state.rage = context.rage or 0
    fury_state.hp = context.hp or 100
    fury_state.target_hp = context.target_hp or 100
    fury_state.stance = context.stance or STANCE.BERSERKER
    fury_state.enemy_count = context.enemy_count or context.enemies_count or 1
    fury_state.is_pvp = context.is_pvp or spec_kit.setting_bool(context, "pvp_mode", false)
    fury_state.in_combat = context.in_combat or false
    fury_state.is_moving = context.is_moving or false
    fury_state.target_distance = context.target_distance or context.target_range or context.distance or 0
    fury_state.target_is_casting = context.target_is_casting or (target and bool_call(target, "is_casting")) or false
    fury_state.target_casting_interruptible = fury_state.target_is_casting and (NS.is_interruptible and NS.is_interruptible(target) or false)
    fury_state.ttd = context.ttd or 999

    -- Buffs
    fury_state.has_battle_shout = NS.buff_up(me, BATTLE_SHOUT_BUFF) or false
    fury_state.has_commanding_shout = NS.buff_up(me, COMMANDING_SHOUT_BUFF) or false
    fury_state.has_berserker_rage = NS.buff_up(me, BERSERKER_RAGE_BUFF) or false
    fury_state.has_sweeping_strikes = NS.buff_up(me, SWEEPING_STRIKES_BUFF) or false
    fury_state.has_rampage = NS.buff_up(me, RAMPAGE_BUFF) or false
    fury_state.rampage_stacks = NS.buff_stacks(me, RAMPAGE_BUFF) or 0
    fury_state.victory_rush_ready = NS.buff_up(me, VICTORY_RUSH_BUFF) or false

    -- Debuffs on target
    if target then
        fury_state.sunder_stacks = NS.debuff_stacks(target, SUNDER_DEBUFF) or 0
        fury_state.rend_remains = NS.debuff_remains(target, REND_DEBUFF) or 0
        fury_state.hamstring_remains = NS.debuff_remains(target, HAMSTRING_DEBUFF) or 0
        fury_state.demo_remains = NS.debuff_remains(target, DEMO_SHOUT_DEBUFF) or 0
        fury_state.tclap_remains = NS.debuff_remains(target, THUNDER_CLAP_DEBUFF) or 0
    end

    -- Spell readiness
    fury_state.bt_cd = NS.cooldown_remains(ACTION.Bloodthirst, 6) or 0
    fury_state.ww_cd = NS.cooldown_remains(ACTION.Whirlwind, 10) or 0
    fury_state.bt_ready = NS.spell_ready(ACTION.Bloodthirst, target, { expected_cooldown = 6 }) or false
    fury_state.ww_ready = NS.spell_ready(ACTION.Whirlwind, target, { expected_cooldown = 10 }) or false

    -- Stance fallback: engine may return 0 intermittently; trust buff detection
    if fury_state.stance == 0 and NS.has_form then
        if NS.has_form("berserker") then fury_state.stance = STANCE.BERSERKER
        elseif NS.has_form("battle") then fury_state.stance = STANCE.BATTLE
        elseif NS.has_form("defensive") then fury_state.stance = STANCE.DEFENSIVE
        end
    end
    fury_state.execute_ready = NS.spell_ready(ACTION.Execute, target) or false
    fury_state.slam_ready = NS.spell_ready(ACTION.Slam, target) or false
    fury_state.sweeping_ready = NS.spell_ready(ACTION.SweepingStrikes, me, { skip_range = true }) or false
    fury_state.heroic_ready = NS.spell_ready(ACTION.HeroicStrike, target) or false
    fury_state.cleave_ready = NS.spell_ready(ACTION.Cleave, target) or false
    fury_state.pummel_ready = NS.spell_ready(ACTION.Pummel, target) or false
    fury_state.intercept_ready = NS.spell_ready(ACTION.Intercept, target) or false
    fury_state.charge_ready = NS.spell_ready(ACTION.Charge, target) or false
    fury_state.hamstring_ready = NS.spell_ready(ACTION.Hamstring, target) or false
    fury_state.overpower_ready = NS.spell_ready(ACTION.Overpower, target) and fury_state.stance == STANCE.BATTLE
    fury_state.death_wish_ready = NS.spell_ready(ACTION.DeathWish, me, { skip_range = true }) or false
    fury_state.recklessness_ready = NS.spell_ready(ACTION.Recklessness, me, { skip_range = true }) or false
    fury_state.bloodrage_ready = NS.spell_ready(ACTION.Bloodrage, me, { skip_range = true }) or false
    fury_state.victory_ready = NS.spell_ready(ACTION.VictoryRush, target) or false
    fury_state.sunder_ready = NS.spell_ready(ACTION.SunderArmor, target) or false
    fury_state.rend_ready = NS.spell_ready(ACTION.Rend, target) or false
    fury_state.demo_ready = NS.spell_ready(ACTION.DemoralizingShout, me, { skip_range = true }) or false
    fury_state.berserker_rage_ready = NS.spell_ready(ACTION.BerserkerRage, me, { skip_range = true }) or false
    -- thunder_ready removed: not used by Fury (tank/Arms debuff)

    fury_state.execute_phase = execute_phase(context, fury_state)

    -- Healthstone: find first available healthstone in bags
    fury_state.healthstone_id = nil
    fury_state.healthstone_ready = false
    fury_state.health_potion_id = nil
    fury_state.health_potion_ready = false
    if NS.is_item_ready then
        for i = 1, #HEALTHSTONE_IDS do
            local id = HEALTHSTONE_IDS[i]
            if NS.is_item_ready(id) then
                fury_state.healthstone_id = id
                fury_state.healthstone_ready = true
                break
            end
        end
        if not fury_state.healthstone_ready then
            for i = 1, #HEALTH_POTION_IDS do
                local id = HEALTH_POTION_IDS[i]
                if NS.is_item_ready(id) then
                    fury_state.health_potion_id = id
                    fury_state.health_potion_ready = true
                    break
                end
            end
        end
    end

    -- Swing timer for Slam weave + HS trick
    -- Prefer CLEU-backed swing timer; fallback to native prediction
    local cleu_remains = (_cleu and _cleu.get_swing_remains and _cleu.get_swing_remains()) or nil
    fury_state.mh_until = cleu_remains or (me and NS.swing_time_until and NS.swing_time_until(me)) or 999
    fury_state.mh_progress = (me and NS.swing_progress and NS.swing_progress(me)) or 0
    fury_state.oh_until = (me and NS.swing_time_until and NS.swing_time_until(me, 2)) or 999

    -- Sweeping Strikes cooldown
    fury_state.ss_cd = NS.cooldown_remains(ACTION.SweepingStrikes, 30) or 0

    -- Target casting state for interrupt reserve
    fury_state.target_casting_interruptible = fury_state.target_is_casting and (NS.is_interruptible and NS.is_interruptible(target) or false) or false

    -- Offhand check: swing timer returns >0 for OH slot → equipped
    local oh_swing = me and NS.swing_time_until and NS.swing_time_until(me, 2) or 0
    fury_state.has_offhand = oh_swing > 0

    -- Major power-window awareness for cooldown alignment
    fury_state.bloodlust_active = me and NS.buff_up and NS.buff_up(me, BLOODLUST_BUFFS) or false
    fury_state.major_cd_active = planner and planner.is_major_offensive_cd_active(context) or false
    fury_state.major_cd_window = fury_state.bloodlust_active or fury_state.major_cd_active
    fury_state.planner_ready = planner ~= nil

    fury_state.aoe_cc_nearby = context.warrior_aoe_cc_nearby or false
    if HitCap then
        local hit_info = HitCap.get_hit_cap("warrior_melee")
        if hit_info then
            fury_state.hit_cap_pct = hit_info.pct_needed
            fury_state.hit_cap_rating_needed = hit_info.rating_needed
        end
        local exp_info = HitCap.get_expertise_cap()
        if exp_info then
            fury_state.expertise_soft_cap = exp_info.soft_expertise
            fury_state.expertise_hard_cap = exp_info.hard_expertise
        end
    end
    -- safe_state proxy: structural nil-guard elimination (Pattern 14)
    return spec_kit.safe_state(fury_state, FURY_SCHEMA)
end

-- ============================================================================
-- Stance
-- ============================================================================
local function berserker_stance_action()
    return build_action("BerserkerStance", ACTION.BerserkerStance, { target = "self", kind = "form", form = "berserker", requires_target = false })
end

local function battle_stance_action()
    return build_action("BattleStance", ACTION.BattleStance, { target = "self", kind = "form", form = "battle", requires_target = false })
end

-- ============================================================================
-- Match functions
-- ============================================================================

-- Charge: OOC with pull protection, respects toggle, stays in Battle Stance
local function charge_matches(context, state)
    local auto_charge = spec_kit.setting_bool(context, "auto_charge", true)
    if not auto_charge then return false end
    if state.in_combat then return false end
    -- Charge Only OOC Mobs protection: skip if target is already in combat
    local ooc_only = spec_kit.setting_bool(context, "charge_ooc_only", true)
    if ooc_only and context.target then
        local target_in_combat = bool_call(context.target, "is_in_combat") or false
        if target_in_combat then return false end
    end
    if (state.target_distance or 0) < 8 or (state.target_distance or 0) > 25 then return false end
    -- Openers only: stay in Battle Stance between fights
    if state.stance ~= STANCE.BATTLE and not stance_swap_safe(state, 0) then return false end
    return action(context, build_action("Charge", ACTION.Charge, { required_stance = STANCE.BATTLE, cooldown = 15 }))
end

-- Battle Shout / Commanding Shout
local function battle_shout_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.BattleShout, 3.0) then return false end
    if state.has_battle_shout or state.has_commanding_shout then return false end
    return action(context, build_action("BattleShout", ACTION.BattleShout, { target = "self", kind = "buff", buff = BATTLE_SHOUT_BUFF, requires_target = false, min_rage = 10 }))
end

-- Bloodrage: low rage generation
local function bloodrage_matches(context, state)
    if (state.rage or 0) >= 20 then return false end
    if not state.in_combat and (state.hp or 100) < 90 then return false end
    return action(context, build_action("Bloodrage", ACTION.Bloodrage, { target = "self", requires_target = false, skip_gcd = true, cooldown = 60 }))
end

-- Victory Rush: post-kill
local function victory_rush_matches(context, state)
    if not (context.me or NS.GetPlayer()) then return false end
    if not state.victory_rush_ready then return false end
    return action(context, build_action("VictoryRush", ACTION.VictoryRush, {}))
end

-- Healthstone / HealthPotion: auto-use consumable at low HP (healthstone preferred, potion fallback)
local function healthstone_matches(context, state)
    local hs_enabled = spec_kit.setting_bool(context, "use_healthstones", true)
    if not hs_enabled then return false end
    local hs_hp = spec_kit.setting_number(context, "healthstone_hp", 35)
    if (state.hp or 100) > hs_hp then return false end
    -- Healthstone preferred, then health potion as fallback
    if state.healthstone_ready and state.healthstone_id then
        return true
    end
    if state.health_potion_ready and state.health_potion_id then
        return true
    end
    return false
end

-- Recklessness: 30min burst CD — stack with Bloodlust/Drums/other major CDs.
local function recklessness_matches(context, state)
    local cds_enabled = spec_kit.setting_bool(context, "use_cooldowns", true)
    if not cds_enabled or not state.recklessness_ready then return false end
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    if not state.in_combat then return false end
    if (state.hp or 100) < 50 then return false end
    -- TTD gate: don't waste 30min CD if target is about to die
    if (state.ttd or 0) > 0 and (state.ttd or 0) < 20 then return false end
    -- Stack with major power windows; timeout fallback so it never rots
    local combat_time = context.combat_time or 0
    local ttd = context.ttd or 999
    if not state.major_cd_window and combat_time < 60 and ttd > 20 then return false end
    return action(context, build_action("Recklessness", ACTION.Recklessness, { target = "self", required_stance = STANCE.BERSERKER, requires_target = false, cooldown = 1800 }))
end

-- Death Wish: 3min burst CD — align with Bloodlust/Drums/major CDs.
local function death_wish_matches(context, state)
    -- Fear break: Death Wish enrage breaks fear (any stance, unlike Berserker Rage)
    local me = context.me or NS.GetPlayer()
    local is_cc, cc_type = is_feared_sapped_or_incapacitated(me)
    if is_cc and cc_type == "fear" then
        return action(context, build_action("DeathWish", ACTION.DeathWish, { target = "self", requires_target = false, cooldown = 180 }))
    end
    local cds_enabled = spec_kit.setting_bool(context, "use_cooldowns", true)
    if not cds_enabled or not state.death_wish_ready then return false end
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    if (state.hp or 100) < 45 then return false end
    -- TTD gate: don't waste burst CD if target is about to die
    if (state.ttd or 0) > 0 and (state.ttd or 0) < 10 then return false end
    if (state.target_hp or 100) < 20 and (state.rage or 0) < 25 then return false end
    -- Align with major power windows; timeout/execute fallback
    local align = state.major_cd_window or false
    local combat_time = context.combat_time or 0
    local ttd = context.ttd or 999
    if not align and combat_time < 45 and ttd > 15 then return false end
    return action(context, build_action("DeathWish", ACTION.DeathWish, { target = "self", requires_target = false, cooldown = 180 }))
end

-- Rampage: stack management — recast when stacks < min threshold or buff about to fall off
local function rampage_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Rampage, 3.0) then return false end
    if not state.in_combat then return false end
    -- TBC Rampage: cast to APPLY the buff (only usable after a crit) or REFRESH it
    -- before it falls off. Stacks build automatically from successful melee hits
    -- (up to 5) — NOT from recasting. The old `rampage_min_stacks` branch recast
    -- Rampage whenever stacks < 5, wasting 30 rage during the ramp-up window.
    if not state.has_rampage then
        return action(context, build_action("Rampage", ACTION.Rampage, { target = "self", requires_target = false, min_rage = 30 }))
    end
    local rampage_remains = NS.buff_remains and NS.buff_remains(context.me or NS.GetPlayer(), RAMPAGE_BUFF) or 0
    if rampage_remains <= 3 then
        return action(context, build_action("Rampage", ACTION.Rampage, { target = "self", requires_target = false, min_rage = 30 }))
    end
    return false
end

-- Overpower weaving: wowsims-aligned TBC Fury optimization.
-- When BT and WW are both on cooldown (>=1.5s) and not in execute phase,
-- swap to Battle Stance to consume an Overpower proc, then swap back.
-- Opt-in via setting (default off) since it is an advanced technique
-- that requires precise stance-dance timing.
-- Source: wowsims/tbc-new/ui/warrior/dps/apls/fury.apl.json (Overpower Weaving group)
local function overpower_matches(context, state)
    if not spec_kit.setting_bool(context, "fury_overpower_weave", false) then return false end
    if not state.overpower_ready then return false end
    -- Delay Check: BT and WW both >=1.5s from ready (don't delay core abilities)
    if (state.bt_cd or 99) < 1.5 then return false end
    if (state.ww_cd or 99) < 1.5 then return false end
    -- Don't Overpower during execute phase (Execute hits harder)
    if state.execute_phase then return false end
    -- Rage gate: wowsims uses 5-100 rage window
    local rage = (state.rage or 0)
    if rage < 5 then return false end
    if rage > 100 then return false end
    return action(context, build_action("Overpower", ACTION.Overpower, { required_stance = STANCE.BATTLE, min_rage = 5 }))
end

-- SS rage reservation: hold rage when SS coming off CD in AoE
local SS_RESERVE_FLOOR = 60
local SS_POOL_WINDOW = 2.0

local function should_reserve_for_sweeping(context, state)
    if (context.enemy_count or 0) < 2 then return false end
    if state.has_sweeping_strikes then return false end
    local ss_cd = state.ss_cd or 99
    if ss_cd <= SS_POOL_WINDOW and (context.rage or 0) < SS_RESERVE_FLOOR then return true end
    return false
end

-- HS/Cleave starvation: don't queue if it would starve BT or WW
local function would_starve_core_fury(context, state, cost)
    cost = cost or 15
    local rage = context.rage or 0
    local bt_cd = state.bt_cd or 99
    if bt_cd >= 0 and bt_cd <= 1.5 then
        if (rage - cost) < BLOODTHIRST_RESERVE then return true end
    end
    local ww_cd = state.ww_cd or 99
    if ww_cd >= 0 and ww_cd <= 1.5 then
        if (rage - cost) < WHIRLWIND_RESERVE then return true end
    end
    -- Interrupt reserve
    if state.target_casting_interruptible and state.pummel_ready then
        if (rage - cost) < 10 then return true end
    end
    return false
end

-- Bloodthirst: core Fury ability
local function bt_matches(context, state)
    -- WW priority: yield to Whirlwind when enough enemies nearby and WW is ready
    local ww_prio = spec_kit.setting_number(context, "fury_ww_prio_count", 2)
    if ww_prio > 0 and (state.enemy_count or 0) >= ww_prio and (context.rage or 0) >= 25 and state.ww_ready then
        return false
    end
    return action(context, build_action("Bloodthirst", ACTION.Bloodthirst, { required_stance = STANCE.BERSERKER, min_rage = 30, cooldown = 6 }))
end

-- Rend removed: not used in TBC Fury rotation per Icy Veins/Wowhead

-- Sunder Armor: stack armor reduction
local function sunder_armor_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.SunderArmor, 2.0) then return false end
    -- Low-level: get_armor() often returns 0/nil — same silent gate as Druid Faerie Fire.
    local level = (context and (context.level or context.player_level)) or 70
    if level >= 50 and (context.target_armor or 0) <= 0 then return false end
    if execute_phase(context, state) then return false end
    local sunder_mode = spec_kit.setting(context, "sunder_mode", "off")
    if sunder_mode == "off" then return false end
    local max_stacks = spec_kit.setting_number(context, "sunder_stacks", 3)
    if (state.sunder_stacks or 0) >= max_stacks then return false end
    -- Low priority mode: only cast if rage is high
    if sunder_mode == "low" and (state.rage or 0) < 60 then return false end
    return action(context, build_action("SunderArmor", ACTION.SunderArmor, { min_rage = 15, debuff = SUNDER_DEBUFF }))
end

-- Sweeping Strikes: AoE prep
local function sweeping_strikes_matches(context, state)
    if state.aoe_cc_nearby then return false end  -- don't break nearby CC
    local min_count = spec_kit.setting_number(context, "sweeping_strikes_count", 2)
    if (state.enemy_count or 0) < min_count then return false end
    if state.has_sweeping_strikes then return false end
    if state.stance ~= STANCE.BATTLE then return false end
    return action(context, build_action("SweepingStrikes", ACTION.SweepingStrikes, { target = "self", required_stance = STANCE.BATTLE, min_rage = 30, requires_target = false, enemy_count = min_count, cooldown = 30 }))
end

-- Whirlwind: filler + AoE — use with any extra rage per Icy Veins
local function whirlwind_matches(context, state)
    if not state.ww_ready then return false end
    if state.aoe_cc_nearby then return false end  -- don't break nearby CC
    if (state.enemy_count or 0) < 2 and (state.rage or 0) < 25 then return false end
    return action(context, build_action("Whirlwind", ACTION.Whirlwind, { required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10 }))
end

-- Execute: finish phase
local function execute_matches(context, state)
    if not execute_phase(context, state) then return false end
    local min_rage = spec_kit.setting_number(context, "execute_phase_rage", EXECUTE_DEFAULT_RAGE)
    if (state.rage or 0) < min_rage then return false end
    return action(context, build_action("Execute", ACTION.Execute, { required_stance = STANCE.BERSERKER, min_rage = 15 }))
end

-- Slam: weave between swings (when Bloodthirst on CD)
local function slam_matches(context, state)
    if spec_kit.setting_bool(context, "slam_weave_enabled", true) == false then return false end
    if state.is_moving then return false end
    if (state.rage or 0) < SLAM_RAGE_COST then return false end
    if (state.bt_cd or 99) <= 1.5 then return false end
    if (state.ww_cd or 99) <= 1.5 then return false end
    local rage_after_slam = (state.rage or 0) - SLAM_RAGE_COST
    if (state.bt_cd or 99) <= CORE_POOL_WINDOW and rage_after_slam < BLOODTHIRST_RESERVE then return false end
    if (state.ww_cd or 99) <= CORE_POOL_WINDOW and rage_after_slam < WHIRLWIND_RESERVE then return false end
    if (state.mh_until or 999) <= SLAM_CAST_TIME + SLAM_SAFETY then return false end
    if (state.mh_until or 999) > 1.5 then return false end
    return action(context, build_action("Slam", ACTION.Slam, { min_rage = SLAM_RAGE_COST, not_moving = true }))
end

-- Heroic Strike: off-GCD rage dump with HS trick + starvation + interrupt reserve
local function heroic_strike_matches(context, state)
    -- SS reservation
    if should_reserve_for_sweeping(context, state) then return false end
    -- Starvation + interrupt check
    if would_starve_core_fury(context, state, 15) then return false end
    -- HS Trick: proactively queue when OH swing is imminent (before rage threshold)
    -- Dequeue middleware handles safety
    local me = context.me or NS.GetPlayer()
    local hs_trick = spec_kit.setting_bool(context, "hs_trick", false)
    if hs_trick and me then
        local oh_remaining = (me and NS.swing_time_until and NS.swing_time_until(me, 2)) or 999
        local mh_remaining = (me and NS.swing_time_until and NS.swing_time_until(me)) or 999
        if oh_remaining > 0 and oh_remaining <= 0.4 then
            if mh_remaining > oh_remaining + 0.3 then
                return action(context, build_action("HeroicStrike", ACTION.HeroicStrike, { min_rage = 15 }))
            end
        end
    end
    -- Normal HS threshold
    local hs_rage = spec_kit.setting_number(context, "heroic_strike_rage", HEROIC_STRIKE_RAGE)
    -- HS Trick lower threshold when dual-wielding (dequeue middleware handles safety)
    if hs_trick and state.has_offhand then
        hs_rage = 30
    end
    if (state.rage or 0) < hs_rage then return false end
    return action(context, build_action("HeroicStrike", ACTION.HeroicStrike, { min_rage = hs_rage }))
end

-- Cleave: AoE rage dump with starvation + SS reservation
local function cleave_matches(context, state)
    if state.aoe_cc_nearby then return false end  -- don't break nearby CC
    if should_reserve_for_sweeping(context, state) then return false end
    if (state.enemy_count or 0) < 2 then return false end
    local cleave_rage = spec_kit.setting_number(context, "cleave_rage", CLEAVE_RAGE)
    local rage = state.rage or 0
    if rage < cleave_rage then return false end
    if would_starve_core_fury(context, state, 15) then return false end
    return action(context, build_action("Cleave", ACTION.Cleave, { min_rage = cleave_rage, enemy_count = 2, is_aoe = true }))
end

-- Demoralizing Shout: enemy damage reduction
local function demo_shout_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.DemoralizingShout, 2.0) then return false end
    if (state.demo_remains or 0) > 5 then return false end
    if not state.is_pvp and (state.enemy_count or 0) < 2 and (state.hp or 100) > 70 then return false end
    return action(context, build_action("DemoralizingShout", ACTION.DemoralizingShout, { target = "self", min_rage = 10, requires_target = false, debuff = DEMO_SHOUT_DEBUFF, refresh = 5 }))
end

-- Thunder Clap removed: not used by Fury warrior (tank/Arms debuff)

-- Berserker Rage: fear break / enrage
local function berserker_rage_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.BerserkerRage, 3.0) then return false end
    if state.has_berserker_rage then return false end
    if not state.berserker_rage_ready then return false end
    -- Fear break: cast immediately if feared/sapped/incapacitated
    local me = context.me or NS.GetPlayer()
    local is_cc = is_feared_sapped_or_incapacitated(me)
    if is_cc then
        return action(context, build_action("BerserkerRage", ACTION.BerserkerRage, { target = "self", requires_target = false, cooldown = 30 }))
    end
    -- Normal: only in combat
    if not state.in_combat then return false end
    return action(context, build_action("BerserkerRage", ACTION.BerserkerRage, { target = "self", requires_target = false, cooldown = 30 }))
end

-- Hamstring: PvP snare + Sword Spec weave (high rage)
local function pummel_matches(context, state)
    if not state.target_is_casting then return false end
    if not (state.target_casting_interruptible or false) then return false end
    if not state.pummel_ready then return false end
    return action(context, build_action("Pummel", ACTION.Pummel, { required_stance = STANCE.BERSERKER, min_rage = 10 }))
end

local function hamstring_matches(context, state)
    -- PvP snare
    if state.is_pvp then
        if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Hamstring, 2.0) then return false end
        if (state.hamstring_remains or 0) > 3 then return false end
        return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }))
    end
    -- Sword Spec weave: generate extra attacks when rage is high and BT/WW on CD
    if spec_kit.setting_bool(context, "fury_use_hamstring", false) then
        local min_rage = spec_kit.setting_number(context, "fury_hamstring_rage", 50)
        if (state.rage or 0) >= min_rage then
            -- Only weave when core abilities are on CD
            if (state.bt_cd or 99) > 1.5 and (state.ww_cd or 99) > 1.5 and not state.execute_phase then
                return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10 }))
            end
        end
    end
    return false
end

-- Swing Desync: when dual-wielding with synced MH/OH swings, inject a Slam
-- to offset timers, smoothing rage gen and helping Flurry/WF benefit both hands.
local DESYNC_COOLDOWN = 10
local DESYNC_SYNC_THRESHOLD = 0.3
local DESYNC_SLAM_WINDOW = 1.6
local desync_last_attempt = 0

local function swing_desync_matches(context, state)
    if not spec_kit.setting_bool(context, "fury_swing_desync", false) then return false end
    if state.is_moving then return false end
    if not state.has_offhand then return false end
    -- Cooldown between desync attempts
    local now = NS.time_now and NS.time_now() or 0
    if (now - desync_last_attempt) < DESYNC_COOLDOWN then return false end
    -- Both hands must be actively swinging
    local me = context.me or NS.GetPlayer()
    if not me then return false end
    local mh_remaining = (me and NS.swing_time_until and NS.swing_time_until(me)) or 0
    local oh_remaining = (me and NS.swing_time_until and NS.swing_time_until(me, 2)) or 0
    if mh_remaining <= 0 or oh_remaining <= 0 then return false end
    -- Check if swings are synced (remaining times close together)
    if math.abs(mh_remaining - oh_remaining) > DESYNC_SYNC_THRESHOLD then return false end
    -- Need enough swing time for base Slam (1.5s) to land before next auto
    if mh_remaining < DESYNC_SLAM_WINDOW then return false end
    -- Don't starve BT/WW if they're coming off CD soon
    if (state.bt_cd or 99) <= 1.0 and (state.rage or 0) < (BLOODTHIRST_RESERVE + SLAM_RAGE_COST) then return false end
    if (state.ww_cd or 99) <= 1.0 and (state.rage or 0) < (WHIRLWIND_RESERVE + SLAM_RAGE_COST) then return false end
    local rage = state.rage or 0
    if rage < SLAM_RAGE_COST then return false end
    if rage >= 90 then return false end  -- don't Slam at rage cap, use filler
    return action(context, build_action("Slam", ACTION.Slam, { min_rage = SLAM_RAGE_COST, not_moving = true }))
end

-- Intercept: in-combat gap closer (respects auto_charge toggle — v2.2.0 fix)
local function intercept_matches(context, state)
    if not state.in_combat then return false end
    local auto_charge = spec_kit.setting_bool(context, "auto_charge", true)
    if not auto_charge then return false end
    if (state.target_distance or 0) < 8 or (state.target_distance or 0) > 25 then return false end
    -- v2.1.7 / v2.1.8: Charge opener protection — don't Intercept if we just Charged
    if not (NS.spell_ready(ACTION.Intercept, context.target) or false) then return false end
    return action(context, build_action("Intercept", ACTION.Intercept, { required_stance = STANCE.BERSERKER, min_rage = 10, cooldown = 30 }))
end

-- Berserker Stance: preferred DPS stance
local function berserker_stance_matches(context, state)
    if state.stance == STANCE.BERSERKER then return false end
    if stance_lockout_active() then return false end
    if NS.has_form and NS.has_form("berserker") then return false end
    if desired_stance(context) == STANCE.BERSERKER then return action(context, berserker_stance_action()) end
    -- Execute requires Berserker Stance
    if state.execute_phase and (state.rage or 0) >= 15 and stance_swap_safe(state, 15) then
        return action(context, berserker_stance_action())
    end
    if state.bt_ready and stance_swap_safe(state, 30) then
        return action(context, berserker_stance_action())
    end
    if state.ww_ready and stance_swap_safe(state, 25) and ((state.enemy_count or 0) >= 2 or (state.rage or 0) >= 45) then
        return action(context, berserker_stance_action())
    end
    return false
end

-- Battle Stance: for Charge, Overpower, Thunder Clap
local function battle_stance_matches(context, state)
    if state.stance == STANCE.BATTLE then return false end
    if stance_lockout_active() then return false end
    if NS.has_form and NS.has_form("battle") then return false end
    if desired_stance(context) == STANCE.BATTLE then return action(context, battle_stance_action()) end
    if state.overpower_ready and stance_swap_safe(state, 5) then return action(context, battle_stance_action()) end
    local ss_count = spec_kit.setting_number(context, "sweeping_strikes_count", 2)
    if state.sweeping_ready and not state.has_sweeping_strikes and (state.enemy_count or 0) >= ss_count and stance_swap_safe(state, 30) then
        return action(context, battle_stance_action())
    end
    if not state.in_combat and state.charge_ready and stance_swap_safe(state, 0) then return action(context, battle_stance_action()) end
    return false
end

-- ============================================================================
-- Strategies
-- ============================================================================
local STRATEGY_SPECS = {
    -- Auto-potions (context-based, O(1) gate)
    { "HealthPotion", function(context)
          if not context.in_combat then return false end
          if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end, build_action("HealthPotion", nil, { target = "self", requires_target = false }), function(context)
          return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS)
      end },
    { "DamagePotion", function(context)
          if not context.in_combat then return false end
          if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
          if not context.has_damage_potion then return false end
          if not context.should_burst then return false end
          return true
      end, build_action("DamagePotion", nil, { target = "self", requires_target = false }), function(context)
          return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS)
      end },
    -- Utility / Survival (highest priority)
    { "Healthstone", healthstone_matches, build_action("Healthstone", nil, { target = "self", requires_target = false }), function(context)
        local s = build_state(context or {})
        if s.healthstone_ready and s.healthstone_id and NS.use_item_by_id then
            return NS.use_item_by_id(s.healthstone_id, context.me or context.target)
        end
        if s.health_potion_ready and s.health_potion_id and NS.use_item_by_id then
            return NS.use_item_by_id(s.health_potion_id, context.me or context.target)
        end
        return false
    end },
    -- PvP / Interrupt
    { "Intercept", intercept_matches, build_action("Intercept", ACTION.Intercept, { required_stance = STANCE.BERSERKER, min_rage = 10 }) },
    { "Hamstring", hamstring_matches, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }) },
    { "Pummel", pummel_matches, build_action("Pummel", ACTION.Pummel, { required_stance = STANCE.BERSERKER, min_rage = 10 }) },
    -- Stance
    { "BerserkerStance", berserker_stance_matches, berserker_stance_action() },
    { "BattleStance", battle_stance_matches, battle_stance_action() },
    -- Buffs
    { "BattleShout", battle_shout_matches, build_action("BattleShout", ACTION.BattleShout, { target = "self", kind = "buff", buff = BATTLE_SHOUT_BUFF, requires_target = false }) },
    { "BerserkerRage", berserker_rage_matches, build_action("BerserkerRage", ACTION.BerserkerRage, { target = "self", requires_target = false, cooldown = 30 }) },
    { "Bloodrage", bloodrage_matches, build_action("Bloodrage", ACTION.Bloodrage, { target = "self", requires_target = false, skip_gcd = true }) },
    -- Engineering bombs (wowsims APL "Engineering" group — filler during rage downtime)
    { "EngineeringBomb", function(context)
          if not engineering then return false end
          return engineering.should_use_bomb(context)
      end, build_action("EngineeringBomb", nil, { target = "self", requires_target = false }), function(context)
          if not engineering then return false end
          return engineering.use_best_bomb(context)
      end },
    { "VictoryRush", victory_rush_matches, build_action("VictoryRush", ACTION.VictoryRush, {}) },
    -- Charge opener (OOC)
    { "Charge", charge_matches, build_action("Charge", ACTION.Charge, { required_stance = STANCE.BATTLE, cooldown = 15 }) },
    -- Cooldowns
    { "Recklessness", recklessness_matches, build_action("Recklessness", ACTION.Recklessness, { target = "self", required_stance = STANCE.BERSERKER, requires_target = false }) },
    { "DeathWish", death_wish_matches, build_action("DeathWish", ACTION.DeathWish, { target = "self", requires_target = false }) },
    -- AoE
    { "SweepingStrikes", sweeping_strikes_matches, build_action("SweepingStrikes", ACTION.SweepingStrikes, { target = "self", required_stance = STANCE.BATTLE, min_rage = 30, requires_target = false }) },
    -- Core rotation (APL-aligned: Rampage upkeep → Execute → BT → WW → Overpower weave → Slam)
    { "Rampage", rampage_matches, build_action("Rampage", ACTION.Rampage, { target = "self", requires_target = false, min_rage = 30 }) },
    { "Execute", execute_matches, build_action("Execute", ACTION.Execute, { required_stance = STANCE.BERSERKER, min_rage = 15 }) },
    { "Bloodthirst", bt_matches, build_action("Bloodthirst", ACTION.Bloodthirst, { required_stance = STANCE.BERSERKER, min_rage = 30, cooldown = 6 }) },
    { "Whirlwind", whirlwind_matches, build_action("Whirlwind", ACTION.Whirlwind, { required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10 }) },
    { "Overpower", overpower_matches, build_action("Overpower", ACTION.Overpower, { required_stance = STANCE.BATTLE, min_rage = 5 }) },
    { "Slam", slam_matches, build_action("Slam", ACTION.Slam, { min_rage = SLAM_RAGE_COST, not_moving = true }) },
    { "SwingDesync", swing_desync_matches, build_action("SwingDesync", ACTION.Slam, { min_rage = SLAM_RAGE_COST, not_moving = true }) },
    -- Overpower REMOVED from Fury: Arms-only in TBC
    { "SunderArmor", sunder_armor_matches, build_action("SunderArmor", ACTION.SunderArmor, { min_rage = 15, debuff = SUNDER_DEBUFF }) },
    { "DemoralizingShout", demo_shout_matches, build_action("DemoralizingShout", ACTION.DemoralizingShout, { target = "self", min_rage = 10, requires_target = false }) },
    -- Rage dumps
    { "Cleave", cleave_matches, build_action("Cleave", ACTION.Cleave, { min_rage = CLEAVE_RAGE, enemy_count = 2, is_aoe = true }) },
    { "HeroicStrike", heroic_strike_matches, build_action("HeroicStrike", ACTION.HeroicStrike, { min_rage = HEROIC_STRIKE_RAGE }) },
}

local strategies = {}
local _build = build_state

for i = 1, #STRATEGY_SPECS do
    local spec = STRATEGY_SPECS[i]
    local name = spec[1]
    local matches = spec[2]
    local row = spec[3]

    local custom_execute = spec[4]
    strategies[#strategies + 1] = {
        name = name,
        spell = row.spell,
        required_stance = row.required_stance,
        min_rage = row.min_rage,
        cooldown = row.cooldown,
        matches = function(context)
            local state = _build(context or {})
            return matches(context or {}, state)
        end,
        execute = custom_execute or function(context)
            return cast(context or {}, row)
        end,
    }
end

strategies[#strategies + 1] = {
    name = "HitCapPriority",
    matches = function(context)
        local state = _build(context or {})
        if not state.hit_cap_rating_needed then return false end
        local hit_rating = context.hit_rating
        if not hit_rating then return false end
        local deficit = state.hit_cap_rating_needed - hit_rating
        if deficit <= 30 then return false end
        if NS.log then NS.log(string.format("[FURY] Hit cap deficit %d — gating missable abilities", deficit)) end
        return true
    end,
    execute = function() return true end,
}

-- Guarded registration (nil-safe in unit tests)
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("fury", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warrior Fury rotation registered") end

-- Canonical return shape: dispatcher + tests both get what they need
return { strategies = strategies, build_state = build_state }
