-- arms_sylvanas -- warrior arms_sylvanas rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies for arms_sylvanas gameplay.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no manual nil-guards; no on_update() allocs.

-- Warrior Arms priority list for TBC Sylvanas rotations.
local NS = _G.EaxRotations
if not NS then return nil end
local _cleu = NS.SwingDiagnostics
if _cleu then
    _cleu.register_seals({
        1464, 8820, 11604, 11605, 25241, 25242,                              -- Slam ranks
        78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 29707, 30324,  -- Heroic Strike ranks
    })
end

local potion_helper = require("shared/potion_helper_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")
local HitCap = require("shared/hit_cap_tracker_sylvanas")
local WH = require("classes/warrior/shared_helpers_sylvanas") or {}
local _eng_ok, engineering = pcall(require, "shared/engineering_helper_sylvanas")
if not _eng_ok or type(engineering) ~= "table" then engineering = nil end
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }
local PLAYER_UNIT = NS.PLAYER_UNIT

-- Centralized spell resolver via spec_kit (replaces the per-spec spell() helper).
local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    BattleShout = define("BattleShout", { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
    BattleStance = define("BattleStance", 2457, "BattleStance"),
    BerserkerRage = define("BerserkerRage", 18499, "BerserkerRage"),
    BerserkerStance = define("BerserkerStance", 2458, "BerserkerStance"),
    Bloodrage = define("Bloodrage", 2687, "Bloodrage"),
    Charge = define("Charge", { 11578, 6178, 100 }, "Charge"),
    Cleave = define("Cleave", { 25231, 20569, 11609, 11608, 7369, 845 }, "Cleave"),
    CommandingShout = define("CommandingShout", 469, "CommandingShout"),
    DeathWish = SPELLS.DeathWish,  -- uses expansion-aware IDs from class_sylvanas.lua
    DefensiveStance = define("DefensiveStance", 71, "DefensiveStance"),
    DemoralizingShout = define("DemoralizingShout", { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }, "DemoralizingShout"),
    Disarm = define("Disarm", 676, "Disarm"),
    Execute = define("Execute", { 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
    Hamstring = define("Hamstring", { 25212, 7373, 7372, 1715 }, "Hamstring"),
    HeroicStrike = define("HeroicStrike", { 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    Intercept = define("Intercept", { 25275, 20617, 20616, 20252 }, "Intercept"),
    IntimidatingShout = define("IntimidatingShout", 5246, "IntimidatingShout"),
    MortalStrike = define("MortalStrike", { 30330, 25248, 21553, 21552, 21551, 12294 }, "MortalStrike"),
    Overpower = define("Overpower", { 11585, 11584, 7887, 7384 }, "Overpower"),  -- 11584 = Rank 3 (was missing; levels 44-59 couldn't resolve Overpower)
    PiercingHowl = define("PiercingHowl", 12323, "PiercingHowl"),
    Pummel = NS.spell_action and NS.spell_action({ 6554, 6552 }, "Pummel") or 6554,
    Recklessness = define("Recklessness", 1719, "Recklessness"),
    Rend = define("Rend", { 25208, 11574, 11573, 6548, 6547, 772 }, "Rend"),
    Retaliation = define("Retaliation", 20230, "Retaliation"),
    ShieldWall = define("ShieldWall", 871, "ShieldWall"),
    Slam = define("Slam", { 25242, 25241, 11605, 11604, 8820, 1464 }, "Slam"),
    SpellReflection = define("SpellReflection", 23920, "SpellReflection"),
    SunderArmor = define("SunderArmor", { 25225, 11597, 11596, 8380, 7405, 7386 }, "SunderArmor"),
    SweepingStrikes = SPELLS.SweepingStrikes,  -- uses expansion-aware IDs from class_sylvanas.lua
    ThunderClap = define("ThunderClap", { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
    VictoryRush = define("VictoryRush", 34428, "VictoryRush"),
    Whirlwind = define("Whirlwind", 1680, "Whirlwind"),
}

local BATTLE_SHOUT_BUFF = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
local BLEED_IMMUNE_TYPES = { [4]=true, [6]=true, [9]=true }  -- Elemental, Undead, Mechanical
local BERSERKER_RAGE_BUFF = { 18499 }
local COMMANDING_SHOUT_BUFF = CONSTANTS.COMMANDING_SHOUT_BUFF or { 469 }
local DEMO_SHOUT_DEBUFF = CONSTANTS.DEMO_SHOUT_DEBUFF or { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
local HAMSTRING_DEBUFF = { 25212, 7373, 7372, 1715 }
local MORTAL_STRIKE_DEBUFF = { 30330, 25248, 21553, 21552, 21551, 12294 }
local REND_DEBUFF = { 25208, 11574, 11573, 6548, 6547, 772 }
local SUNDER_DEBUFF = CONSTANTS.SUNDER_DEBUFF or { 25225, 11597, 11596, 8380, 7405, 7386 }
local SWEEPING_STRIKES_BUFF = { 12328 }
local THUNDER_CLAP_DEBUFF = CONSTANTS.THUNDER_CLAP_DEBUFF or { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
local VICTORY_RUSH_BUFF = { 34428 }

-- Crowd-control debuff IDs for fear-break detection (Berserker Rage / Death Wish)
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

-- Healthstone item IDs (TBC, best to worst)
local HEALTHSTONE_IDS = (TBC and TBC.ITEMS and TBC.ITEMS.healthstones) or { 22116, 22105, 22104, 22103, 22102, 22101 }


local HEALTHSTONE_HP_THRESHOLD = 35
local EXECUTE_DEFAULT_RAGE = 25
local HEROIC_STRIKE_RAGE = 70
local CLEAVE_RAGE = 55
local MORTAL_STRIKE_RAGE = 30
local OVERPOWER_RAGE = 5
local SLAM_RAGE = 15
local SLAM_CAST_TIME = 0.5
local SLAM_SAFETY = 0.2
local SWEEPING_STRIKES_COUNT = 2
local TACTICAL_MASTERY_CAP = 25
local HAMSTRING_SPAM_RAGE = 55
local STANCE_CAST_LOCKOUT = 2.0
local RAGE_CAP = 90
-- Sweeping Strikes rage pooling (from kebab pattern)
local SS_RESERVE_FLOOR = 60
local SS_POOL_WINDOW = 2.0
local last_stance_cast_at = 0  -- fallback only; WH tracks its own copy when loaded

-- Configure shared module with spec-specific constants
WH.CAST_TAG = "[ARMS]"
WH.TACTICAL_MASTERY_CAP = TACTICAL_MASTERY_CAP
WH.STANCE_CAST_LOCKOUT = STANCE_CAST_LOCKOUT

local stance_lockout_active = WH.stance_lockout_active or function()
    return (NS.time_now and NS.time_now() or 0) < last_stance_cast_at + STANCE_CAST_LOCKOUT
end

-- Action specs referenced via build_action() in strategy specs

local arms_state = {
    rage = 0,
    hp = 100,
    target_hp = 100,
    stance = STANCE.BATTLE,
    enemy_count = 1,
    is_pvp = false,
    in_combat = false,
    is_moving = false,
    target_distance = 0,
    target_is_player = false,
    target_is_pet = false,
    target_is_casting = false,
    target_casting_interruptible = false,
    target_is_melee = false,
    ttd = 0,
    has_battle_shout = false,
    has_berserker_rage = false,
    berserker_rage_ready = false,
    has_commanding_shout = false,
    has_sweeping_strikes = false,
    victory_rush_ready = false,
    ms_remains = 0,
    rend_remains = 0,
    hamstring_remains = 0,
    demo_remains = 0,
    tclap_remains = 0,
    sunder_stacks = 0,
    ms_cd = 99,
    ww_cd = 99,
    overpower_ready = false,
    execute_ready = false,
    ms_ready = false,
    ww_ready = false,
    slam_ready = false,
    sweeping_ready = false,
    heroic_ready = false,
    cleave_ready = false,
    pummel_ready = false,
    intercept_ready = false,
    charge_ready = false,
    hamstring_ready = false,
    piercing_ready = false,
    spell_reflect_ready = false,
    disarm_ready = false,
    intimidating_ready = false,
    thunder_ready = false,
    demo_ready = false,
    bloodrage_ready = false,
    death_wish_ready = false,
    recklessness_ready = false,
    retaliation_ready = false,
    shield_wall_ready = false,
    execute_phase = false,
    
    target_in_combat = false,
    mh_until = 999,
    mh_progress = 0,
    healthstone_ready = false,
    healthstone_id = nil,
}

-- Helper functions (extracted to shared_helpers_sylvanas; fallbacks kept if module missing)
-- settings now delegated to spec_kit.setting_*() (Pattern 8)

local function player_target(context, action)
    if action and action.target == "self" then return context.me or NS.GetPlayer() end
    return context.target
end

local bool_call = WH.bool_call or function(unit, method)
    if not unit or type(unit[method]) ~= "function" then return false end
    local ok, value = pcall(unit[method], unit)
    return ok and value == true
end

local function is_player_or_pet(target)
    return bool_call(target, "is_player") or bool_call(target, "is_pet")
end

local function target_is_melee(target)
    if not target then return false end
    if bool_call(target, "is_melee") then return true end
    if bool_call(target, "is_warrior") or bool_call(target, "is_rogue") then return true end
    return false
end

local execute_phase = WH.execute_phase or function(context, state)
    if NS.is_execute_phase then return NS.is_execute_phase(context.target_hp, 20) end
    if (state.target_hp or context.target_hp or 100) <= 20 then return true end
    -- TTD awareness: treat as execute phase if target is dying soon
    if (state.ttd or 0) > 0 and (state.ttd or 0) < 15 then return true end
    return false
end

local desired_stance = WH.desired_stance or function(context)
    local preference = spec_kit.setting(context, "stance_preference", "auto")
    if preference == "battle" or preference == STANCE.BATTLE then return STANCE.BATTLE end
    if preference == "defensive" or preference == STANCE.DEFENSIVE then return STANCE.DEFENSIVE end
    if preference == "berserker" or preference == STANCE.BERSERKER then return STANCE.BERSERKER end
    return nil
end

local preserved_rage_after_swap = WH.preserved_rage_after_swap or function(rage)
    if NS.get_tactical_mastery_cap then return NS.get_tactical_mastery_cap() end
    local cap = TACTICAL_MASTERY_CAP or 25
    local r = rage or 0
    return r < cap and r or cap
end

local stance_swap_safe = WH.stance_swap_safe or function(state, cost)
    local effective_cost = math.min(cost or 0, 15)
    if state.stance == nil then return true end
    return preserved_rage_after_swap(state.rage or 0) >= effective_cost
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
    local ok = NS.try_cast(row.spell, target, "[ARMS]", opts)
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

-- Schema for safe_state: mirrors arms_state defaults. Fields NOT listed here
-- use spec_kit.SAFE_STATE_DEFAULTS (rage→0, hp→100, enemy_count→0, etc.).
-- Custom defaults (e.g. enemy_count=1, stance=BATTLE, mh_until=999) override the kit defaults.
local ARMS_SCHEMA = {
    stance = STANCE.BATTLE,
    enemy_count = 1,
    is_pvp = false,
    in_combat = false,
    is_moving = false,
    target_is_player = false,
    target_is_pet = false,
    target_is_casting = false,
    target_casting_interruptible = false,
    target_is_melee = false,
    target_in_combat = false,
    has_battle_shout = false,
    has_berserker_rage = false,
    berserker_rage_ready = false,
    has_commanding_shout = false,
    has_sweeping_strikes = false,
    victory_rush_ready = false,
    ms_remains = 0,
    rend_remains = 0,
    hamstring_remains = 0,
    demo_remains = 0,
    tclap_remains = 0,
    sunder_stacks = 0,
    ms_cd = 99,
    ww_cd = 99,
    ss_cd = 99,
    overpower_ready = false,
    execute_ready = false,
    ms_ready = false,
    ww_ready = false,
    slam_ready = false,
    sweeping_ready = false,
    heroic_ready = false,
    cleave_ready = false,
    pummel_ready = false,
    intercept_ready = false,
    charge_ready = false,
    hamstring_ready = false,
    piercing_ready = false,
    spell_reflect_ready = false,
    disarm_ready = false,
    intimidating_ready = false,
    thunder_ready = false,
    demo_ready = false,
    bloodrage_ready = false,
    death_wish_ready = false,
    recklessness_ready = false,
    retaliation_ready = false,
    shield_wall_ready = false,
    execute_phase = false,
    is_boss = false,            -- [#fix-2] Death Wish boss-burst gate
    target_hp_pct = 100,       -- [#fix-2] Death Wish boss-burst gate (>20%)
    mh_until = 999,
    mh_progress = 0,
    healthstone_ready = false,
    aoe_cc_nearby = false,
    hit_cap_pct = 9,
    hit_cap_rating_needed = 142,
    expertise_soft_cap = 26,
    expertise_hard_cap = 56,
}

local _last_build_state_time = -1
local function build_state(context)
    local state = arms_state
    local now = context.now
    if now and now == _last_build_state_time then return state end
    now = now or (NS.time_now and NS.time_now() or 0)
    if context.now then _last_build_state_time = now end
    state.now = now
    local is_group = context.is_group or false
    local target = context.target
    local me = context.me or NS.GetPlayer()

    arms_state.is_group = is_group
    arms_state.rage = context.rage or 0
    arms_state.hp = context.hp or 100
    arms_state.target_hp = context.target_hp or 100
    arms_state.stance = context.stance or STANCE.BATTLE
    arms_state.enemy_count = context.enemy_count or context.enemies_count or 1
    arms_state.is_pvp = context.is_pvp or spec_kit.setting_bool(context, "pvp_mode", false)
    arms_state.in_combat = context.in_combat or false
    arms_state.is_moving = context.is_moving or false
    arms_state.target_distance = context.target_distance or context.target_range or context.distance or 0
    arms_state.target_is_player = target and bool_call(target, "is_player") or false
    arms_state.target_is_pet = target and bool_call(target, "is_pet") or false
    arms_state.target_is_casting = context.target_is_casting or bool_call(target, "is_casting") or false
    arms_state.target_casting_interruptible = arms_state.target_is_casting and (NS.is_interruptible and NS.is_interruptible(target) or false)
    arms_state.target_is_melee = target_is_melee(target)
    arms_state.ttd = context.ttd or 999
    arms_state.target_in_combat = target and bool_call(target, "is_in_combat") or false

    arms_state.has_battle_shout = NS.buff_up(me, BATTLE_SHOUT_BUFF) or false
    arms_state.has_berserker_rage = NS.buff_up(me, BERSERKER_RAGE_BUFF) or false
    arms_state.berserker_rage_ready = NS.spell_ready(ACTION.BerserkerRage, me, { skip_range = true }) or false
    arms_state.has_commanding_shout = NS.buff_up(me, COMMANDING_SHOUT_BUFF) or false
    arms_state.has_sweeping_strikes = NS.buff_up(me, SWEEPING_STRIKES_BUFF) or false
    arms_state.victory_rush_ready = NS.buff_up(me, VICTORY_RUSH_BUFF) or false

    arms_state.ms_remains = NS.debuff_remains(target, MORTAL_STRIKE_DEBUFF) or 0
    arms_state.rend_remains = NS.debuff_remains(target, REND_DEBUFF) or 0
    arms_state.hamstring_remains = NS.debuff_remains(target, HAMSTRING_DEBUFF) or 0
    arms_state.demo_remains = NS.debuff_remains(target, DEMO_SHOUT_DEBUFF) or 0
    arms_state.tclap_remains = NS.debuff_remains(target, THUNDER_CLAP_DEBUFF) or 0
    arms_state.sunder_stacks = (NS.get_debuff_stacks and NS.get_debuff_stacks(target, SUNDER_DEBUFF)) or (NS.debuff_stacks and NS.debuff_stacks(target, SUNDER_DEBUFF)) or 0

    arms_state.ms_cd = NS.cooldown_remains(ACTION.MortalStrike, 6) or 0
    arms_state.ww_cd = NS.cooldown_remains(ACTION.Whirlwind, 10) or 0
    arms_state.overpower_ready = NS.spell_ready(ACTION.Overpower, target) or false
    arms_state.execute_ready = NS.spell_ready(ACTION.Execute, target) or false
    arms_state.ms_ready = NS.spell_ready(ACTION.MortalStrike, target, { expected_cooldown = 6 }) or false
    arms_state.ww_ready = NS.spell_ready(ACTION.Whirlwind, target, { expected_cooldown = 10 }) or false
    arms_state.slam_ready = NS.spell_ready(ACTION.Slam, target) or false
    arms_state.sweeping_ready = NS.spell_ready(ACTION.SweepingStrikes, me, { skip_range = true }) or false
    arms_state.ss_cd = NS.cooldown_remains(ACTION.SweepingStrikes, 30) or 0
    arms_state.heroic_ready = NS.spell_ready(ACTION.HeroicStrike, target) or false
    arms_state.cleave_ready = NS.spell_ready(ACTION.Cleave, target) or false
    arms_state.pummel_ready = NS.spell_ready(ACTION.Pummel, target) or false
    arms_state.intercept_ready = NS.spell_ready(ACTION.Intercept, target) or false
    arms_state.charge_ready = NS.spell_ready(ACTION.Charge, target) or false
    arms_state.hamstring_ready = NS.spell_ready(ACTION.Hamstring, target) or false
    arms_state.piercing_ready = NS.spell_ready(ACTION.PiercingHowl, me, { skip_range = true }) or false
    arms_state.spell_reflect_ready = NS.spell_ready(ACTION.SpellReflection, me, { skip_range = true }) or false
    arms_state.disarm_ready = NS.spell_ready(ACTION.Disarm, target) or false
    arms_state.intimidating_ready = NS.spell_ready(ACTION.IntimidatingShout, me, { skip_range = true }) or false
    arms_state.thunder_ready = NS.spell_ready(ACTION.ThunderClap, me, { skip_range = true, expected_cooldown = 4 }) or false
    arms_state.demo_ready = NS.spell_ready(ACTION.DemoralizingShout, me, { skip_range = true }) or false
    arms_state.bloodrage_ready = NS.spell_ready(ACTION.Bloodrage, me, { skip_range = true }) or false
    arms_state.death_wish_ready = NS.spell_ready(ACTION.DeathWish, me, { skip_range = true }) or false
    arms_state.recklessness_ready = NS.spell_ready(ACTION.Recklessness, me, { skip_range = true }) or false
    arms_state.retaliation_ready = NS.spell_ready(ACTION.Retaliation, me, { skip_range = true }) or false
    arms_state.shield_wall_ready = NS.spell_ready(ACTION.ShieldWall, me, { skip_range = true }) or false

    -- [#fix-2] boss flag + target HP pct for Death Wish boss-burst gate
    arms_state.is_boss = context.target_is_boss == true or (NS.unit_is_boss and NS.unit_is_boss(target)) or false
    arms_state.target_hp_pct = arms_state.target_hp or context.target_hp or 100
    arms_state.execute_phase = execute_phase(context, arms_state)

    -- Healthstone: find first available healthstone in bags
    arms_state.healthstone_id = nil
    arms_state.healthstone_ready = false
    if NS.is_item_ready then
        for i = 1, #HEALTHSTONE_IDS do
            local id = HEALTHSTONE_IDS[i]
            if NS.is_item_ready(id) then
                arms_state.healthstone_id = id
                arms_state.healthstone_ready = true
                break
            end
        end
    end

    -- Prefer CLEU-backed swing timer; fallback to native prediction
    local cleu_remains = (_cleu and _cleu.get_swing_remains and _cleu.get_swing_remains()) or nil
    arms_state.mh_until = cleu_remains or (me and NS.swing_time_until and NS.swing_time_until(me)) or 999
    arms_state.mh_progress = (me and NS.swing_progress and NS.swing_progress(me)) or 0

    arms_state.aoe_cc_nearby = context.warrior_aoe_cc_nearby or false
    -- Hit cap / expertise awareness
    if HitCap then
        local hit_info = HitCap.get_hit_cap("warrior_melee")
        if hit_info then
            arms_state.hit_cap_pct = hit_info.pct_needed
            arms_state.hit_cap_rating_needed = hit_info.rating_needed
        end
        local exp_info = HitCap.get_expertise_cap()
        if exp_info then
            arms_state.expertise_soft_cap = exp_info.soft_expertise
            arms_state.expertise_hard_cap = exp_info.hard_expertise
        end
    end
    -- safe_state proxy: structural nil-guard elimination (Pattern 14)
    -- Once wrapped, all match() functions can read state.X without nil-guards.
    return spec_kit.safe_state(arms_state, ARMS_SCHEMA)
end

local function battle_stance_action()
    return build_action("BattleStance", ACTION.BattleStance, { target = "self", kind = "form", form = "battle", requires_target = false })
end

local function berserker_stance_action()
    return build_action("BerserkerStance", ACTION.BerserkerStance, { target = "self", kind = "form", form = "berserker", requires_target = false })
end

local function defensive_stance_action()
    return build_action("DefensiveStance", ACTION.DefensiveStance, { target = "self", kind = "form", form = "defensive", requires_target = false })
end

local function battle_shout_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.BattleShout, 3.0) then return false end
    if state.has_battle_shout or state.has_commanding_shout then return false end
    return action(context, build_action("BattleShout", ACTION.BattleShout, { target = "self", kind = "buff", buff = BATTLE_SHOUT_BUFF, requires_target = false, min_rage = 10 }))
end

local function victory_rush_matches(context, state)
    if not (context.me or NS.GetPlayer()) then return false end
    if not state.victory_rush_ready then return false end
    return action(context, build_action("VictoryRush", ACTION.VictoryRush, {}))
end

local function execute_matches(context, state)
    if not execute_phase(context, state) then return false end
    local min_rage = spec_kit.setting_number(context, "execute_phase_rage", EXECUTE_DEFAULT_RAGE)
    if context.rage ~= nil and state.rage < min_rage then return false end
    return action(context, build_action("Execute", ACTION.Execute, { min_rage = 15 }))
end

local function mortal_strike_matches(context, state)
    -- Rage cap: bypass min_rage gate to prevent rage waste when capped
    if state.rage >= RAGE_CAP then return action(context, build_action("MortalStrike", ACTION.MortalStrike, { required_stance = STANCE.BATTLE, cooldown = 6 })) end
    return action(context, build_action("MortalStrike", ACTION.MortalStrike, { required_stance = STANCE.BATTLE, min_rage = MORTAL_STRIKE_RAGE, cooldown = 6 }))
end

local function overpower_matches(context, state)
    if not state.overpower_ready then return false end
    -- Overpower is proc-gated: only usable for 5s after the player's attack is dodged.
    -- When CLEU diagnostics are active, require a recent dodge proc so the rotation
    -- doesn't burn a tick attempting a non-castable Overpower. Falls back to
    -- spell_ready-only when CLEU is unavailable (legacy behavior).
    if _cleu and _cleu.is_active and _cleu.is_active() and _cleu.is_overpower_proc_active then
        if not _cleu.is_overpower_proc_active() then return false end
    end
    -- Rage protection: skip Overpower if MS is imminent and rage is too low for both
    local ms_cd = state.ms_cd or 99
    if ms_cd <= 1.5 and state.rage < MORTAL_STRIKE_RAGE then return false end
    return action(context, build_action("Overpower", ACTION.Overpower, { required_stance = STANCE.BATTLE, min_rage = OVERPOWER_RAGE }))
end

local function rend_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Rend, 2.0) then return false end
    if execute_phase(context, state) then return false end
    if state.rend_remains > 3 then return false end
    if state.target_hp < 25 then return false end
    -- TTD gate: skip Rend if target dying soon (bleed won't tick enough).
    -- (state.ttd or 999): TTD unknown -> assume target lives long (allow Rend).
    if (state.ttd or 999) > 0 and (state.ttd or 999) < 15 then return false end
    -- Skip Rend on bleed-immune creature types (Elemental, Undead, Mechanical)
    local target = context.target
    if target and target.get_creature_type then
        local ok, ctype = pcall(function() return target:get_creature_type() end)
        if ok and ctype and BLEED_IMMUNE_TYPES[ctype] then return false end
    end
    return action(context, build_action("Rend", ACTION.Rend, { required_stance = STANCE.BATTLE, min_rage = 10, debuff = REND_DEBUFF, refresh = 3 }))
end

local function slam_matches(context, state)
    if spec_kit.setting_bool(context, "slam_weave_enabled", true) == false then return false end
    if state.is_moving then return false end
    local rage = state.rage or 0
    if rage < SLAM_RAGE then return false end
    -- Rage cap: bypass swing timer and MS/Overpower timing to dump rage
    if rage >= RAGE_CAP then return action(context, build_action("Slam", ACTION.Slam, { required_stance = STANCE.BATTLE, min_rage = SLAM_RAGE, not_moving = true })) end
    if state.ms_cd <= 1.0 or state.overpower_ready then return false end
    if state.mh_until <= SLAM_CAST_TIME + SLAM_SAFETY then return false end
    if state.mh_until > 1.5 then return false end
    return action(context, build_action("Slam", ACTION.Slam, { required_stance = STANCE.BATTLE, min_rage = SLAM_RAGE, not_moving = true }))
end

local function sweeping_strikes_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.SweepingStrikes, 3.0) then return false end
    if state.aoe_cc_nearby then return false end  -- don't break nearby CC
    local min_count = spec_kit.setting_number(context, "sweeping_strikes_count", SWEEPING_STRIKES_COUNT)
    if state.enemy_count < min_count then return false end
    if state.has_sweeping_strikes then return false end
    -- TTD gate: don't waste AoE CD if target is about to die
    if state.ttd > 0 and state.ttd < 5 then return false end
    return action(context, build_action("SweepingStrikes", ACTION.SweepingStrikes, { target = "self", required_stance = STANCE.BATTLE, min_rage = 30, requires_target = false, enemy_count = min_count, cooldown = 30 }))
end

local function commanding_shout_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.CommandingShout, 3.0) then return false end
    if not spec_kit.setting_bool(context, "use_commanding_shout", false) then return false end
    if state.has_commanding_shout then return false end
    if state.rage < 10 then return false end
    return action(context, build_action("CommandingShout", ACTION.CommandingShout, { target = "self", kind = "buff", buff = COMMANDING_SHOUT_BUFF, requires_target = false, min_rage = 10 }))
end

local function sunder_armor_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.SunderArmor, 2.0) then return false end
    if (context.target_armor or 0) <= 0 then return false end
    if not spec_kit.setting_bool(context, "use_sunder_armor", false) then return false end
    if state.sunder_stacks >= 5 then return false end
    if state.rage < 15 then return false end
    if state.execute_phase then return false end
    return action(context, build_action("SunderArmor", ACTION.SunderArmor, { required_stance = STANCE.DEFENSIVE, min_rage = 15, debuff = SUNDER_DEBUFF, refresh = 28 }))
end

local function whirlwind_matches(context, state)
    if not state.ww_ready then return false end
    if state.aoe_cc_nearby then return false end  -- don't break nearby CC
    local rage = state.rage or 0
    -- Rage cap: bypass enemy count gate to prevent rage waste
    if rage >= RAGE_CAP then return action(context, build_action("Whirlwind", ACTION.Whirlwind, { required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10 })) end
    if state.enemy_count < 2 and rage < 45 then return false end
    return action(context, build_action("Whirlwind", ACTION.Whirlwind, { required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10 }))
end

-- Sweep Strikes rage pooling: hold rage when SS cooldown is near
local function should_reserve_for_sweeping(context, state)
    if (context.enemy_count or 0) < 2 then return false end
    if state.has_sweeping_strikes then return false end
    local ss_cd = state.ss_cd or 99
    if ss_cd <= SS_POOL_WINDOW and (context.rage or 0) < SS_RESERVE_FLOOR then return true end
    return false
end

-- HS/Cleave starvation: don't queue if it would starve MS, Overpower, Execute, or Slam
local function would_starve_arms(context, state, cost)
    cost = cost or 15
    local rage = state.rage or 0
    local ms_cd = state.ms_cd or 99
    if ms_cd >= 0 and ms_cd <= 1.5 then
        if (rage - cost) < MORTAL_STRIKE_RAGE then return true end
    end
    if state.overpower_ready then
        if (rage - cost) < OVERPOWER_RAGE then return true end
    end
    if state.execute_phase then
        local execute_min = spec_kit.setting_number(context, "execute_phase_rage", EXECUTE_DEFAULT_RAGE)
        if (rage - cost) < execute_min then return true end
    end
    local mh_until = state.mh_until or 999
    if mh_until <= 1.5 then
        if (rage - cost) < SLAM_RAGE then return true end
    end
    return false
end

local function heroic_strike_matches(context, state)
    if state and should_reserve_for_sweeping(context, state) then return false end
    if would_starve_arms(context, state, 15) then return false end
    return action(context, build_action("HeroicStrike", ACTION.HeroicStrike, { min_rage = HEROIC_STRIKE_RAGE }))
end

local function cleave_matches(context, state)
    if state.aoe_cc_nearby then return false end  -- don't break nearby CC
    if state and should_reserve_for_sweeping(context, state) then return false end
    if state.enemy_count < 2 then return false end
    if state.rage < CLEAVE_RAGE then return false end
    return action(context, build_action("Cleave", ACTION.Cleave, { min_rage = CLEAVE_RAGE, enemy_count = 2, is_aoe = true }))
end

local function hamstring_matches(context, state)
    -- PvP snare maintenance (highest priority in PvP)
    if state.is_pvp then
        if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Hamstring, 2.0) then return false end
        if state.hamstring_remains > 3 then return false end
        return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }))
    end
    -- Tactician fishing — spam Hamstring when MS is on CD and rage is high
    local tactician_enabled = spec_kit.setting_bool(context, "hamstring_tactician_weave", true)
    local weave_rage = spec_kit.setting_number(context, "hamstring_weave_rage", HAMSTRING_SPAM_RAGE)
    if tactician_enabled and not state.execute_phase and state.rage >= weave_rage and state.ms_cd > 1.5 then
        return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10 }))
    end
    -- Fleeing mobs (snare utility)
    if spec_kit.setting_bool(context, "hamstring_fleeing_mobs", true) and state.hamstring_remains <= 3 then
        if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Hamstring, 2.0) then return false end
        return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }))
    end
    return false
end

local function piercing_howl_matches(context, state)
    if not state.is_pvp and state.enemy_count < 3 then return false end
    if state.rage < 10 then return false end
    return action(context, build_action("PiercingHowl", ACTION.PiercingHowl, { target = "self", min_rage = 10, requires_target = false, enemy_count = 2, is_aoe = true }))
end

local function demo_shout_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.DemoralizingShout, 2.0) then return false end
    if state.demo_remains > 5 then return false end
    if not state.is_pvp and state.enemy_count < 2 and state.hp > 70 then return false end
    return action(context, build_action("DemoralizingShout", ACTION.DemoralizingShout, { target = "self", min_rage = 10, requires_target = false, debuff = DEMO_SHOUT_DEBUFF, refresh = 5 }))
end

local function thunder_clap_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.ThunderClap, 2.0) then return false end
    if state.aoe_cc_nearby then return false end  -- don't break nearby CC
    if state.tclap_remains > 5 then return false end
    if not state.is_pvp and state.hp > 65 and state.enemy_count < 2 then return false end
    return action(context, build_action("ThunderClap", ACTION.ThunderClap, { target = "self", required_stance = STANCE.BATTLE, min_rage = 20, requires_target = false, debuff = THUNDER_CLAP_DEBUFF, refresh = 5, cooldown = 4 }))
end

local function spell_reflect_matches(context, state)
    if not state.is_pvp then return false end
    if not state.target_is_casting then return false end
    return action(context, build_action("SpellReflection", ACTION.SpellReflection, { target = "self", required_stance = STANCE.DEFENSIVE, min_rage = 15, requires_target = false }))
end

local function disarm_matches(context, state)
    if not state.is_pvp then return false end
    if not state.target_is_melee and not is_player_or_pet(context.target) then return false end
    return action(context, build_action("Disarm", ACTION.Disarm, { required_stance = STANCE.DEFENSIVE, min_rage = 20 }))
end

local function intercept_matches(context, state)
    if state.target_distance < 8 or state.target_distance > 25 then return false end
    -- Respect auto_charge toggle (When auto_charge is off, Intercept is disabled)
    local auto_charge = spec_kit.setting_bool(context, "auto_charge", true)
    if not auto_charge then return false end
    -- v2.1.7/v2.1.8: Charge opener protection — don't Intercept if we just Charged
    if not (NS.spell_ready(ACTION.Intercept, context.target) or false) then return false end
    return action(context, build_action("Intercept", ACTION.Intercept, { required_stance = STANCE.BERSERKER, min_rage = 10, cooldown = 30 }))
end

local function charge_matches(context, state)
    local auto_charge = spec_kit.setting_bool(context, "auto_charge", true)
    if not auto_charge then return false end
    if state.in_combat then return false end
    if state.target_distance < 8 or state.target_distance > 25 then return false end
    -- Charge Only OOC Mobs: skip if target is already in combat with someone else
    local charge_only_ooc = spec_kit.setting_bool(context, "charge_only_ooc", true)
    if charge_only_ooc and (context.target and bool_call(context.target, "is_in_combat")) then return false end
    if not (NS.spell_ready(ACTION.Charge, context.target) or false) then return false end
    return action(context, build_action("Charge", ACTION.Charge, { required_stance = STANCE.BATTLE, cooldown = 15 }))
end

local function intimidating_shout_matches(context, state)
    if not state.is_pvp and state.hp > 35 and state.enemy_count < 3 then return false end
    return action(context, build_action("IntimidatingShout", ACTION.IntimidatingShout, { target = "self", min_rage = 25, requires_target = false, cooldown = 180 }))
end

local function pummel_matches(context, state)
    if not state.target_is_casting then return false end
    if not (state.target_casting_interruptible or false) then return false end
    if not state.pummel_ready then return false end
    return action(context, build_action("Pummel", ACTION.Pummel, { required_stance = STANCE.BERSERKER, min_rage = 10 }))
end

local function battle_stance_matches(context, state)
    if state.stance == STANCE.BATTLE then return false end
    if stance_lockout_active() then return false end
    if NS.has_form and NS.has_form("battle") then return false end
    if desired_stance(context) == STANCE.BATTLE then return action(context, battle_stance_action()) end
    if state.overpower_ready and stance_swap_safe(state, OVERPOWER_RAGE) then return action(context, battle_stance_action()) end
    if state.ms_cd <= 0.3 and stance_swap_safe(state, MORTAL_STRIKE_RAGE) then return action(context, battle_stance_action()) end
    return false
end

local function berserker_stance_matches(context, state)
    if state.stance == STANCE.BERSERKER then return false end
    if stance_lockout_active() then return false end
    if NS.has_form and NS.has_form("berserker") then return false end
    if desired_stance(context) == STANCE.BERSERKER then return action(context, berserker_stance_action()) end
    -- Execute requires Berserker Stance in TBC — swap if execute is ready and we have rage to use it
    if state.execute_phase and state.rage >= 15 and stance_swap_safe(state, 15) then
        return action(context, berserker_stance_action())
    end
    if state.ww_ready and stance_swap_safe(state, 25) and (state.enemy_count >= 2 or state.rage >= 45) then return action(context, berserker_stance_action()) end
    if state.is_pvp and state.target_distance >= 8 and stance_swap_safe(state, 10) then return action(context, berserker_stance_action()) end
    return false
end

local function defensive_stance_matches(context, state)
    if state.stance == STANCE.DEFENSIVE then return false end
    if stance_lockout_active() then return false end
    if NS.has_form and NS.has_form("defensive") then return false end
    if desired_stance(context) == STANCE.DEFENSIVE then return action(context, defensive_stance_action()) end
    if state.hp <= 30 and stance_swap_safe(state, 0) then return action(context, defensive_stance_action()) end
    if state.is_pvp and state.target_is_casting and stance_swap_safe(state, 15) then return action(context, defensive_stance_action()) end
    if state.is_pvp and state.target_is_melee and stance_swap_safe(state, 20) then return action(context, defensive_stance_action()) end
    return false
end

local function cooldowns_allowed(context, state)
    local setting_use = spec_kit.setting_bool(context, "use_cooldowns", true)
    if not setting_use then return false end
    return true
end

local function bloodrage_matches(context, state)
    if state.rage >= 20 then return false end
    if not state.in_combat and state.hp < 90 then return false end
    if not cooldowns_allowed(context, state) then return false end
    return action(context, build_action("Bloodrage", ACTION.Bloodrage, { target = "self", requires_target = false, skip_gcd = true, cooldown = 60 }))
end

local function death_wish_matches(context, state)
    if not state.death_wish_ready then return false end
    -- Fear break: Death Wish enrage breaks fear (any stance, unlike Berserker Rage)
    local me = context.me or NS.GetPlayer()
    local is_cc, cc_type = is_feared_sapped_or_incapacitated(me)
    if is_cc and cc_type == "fear" then return true end
    -- Normal: burst CD usage
    if not state.in_combat then return false end
    if state.execute_phase then return true end
    if state.is_pvp then return true end
    if state.is_boss then
        if state.target_hp_pct and state.target_hp_pct > 20 then return true end
    end
    return false
end

local function berserker_rage_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.BerserkerRage, 3.0) then return false end
    if not state.berserker_rage_ready then return false end
    if state.has_berserker_rage then return false end
    -- Fear break: cast immediately if feared/sapped/incapacitated
    local me = context.me or NS.GetPlayer()
    local is_cc = is_feared_sapped_or_incapacitated(me)
    if is_cc then return true end
    -- Normal usage: only in combat, not just for rage gen on CD
    if not state.in_combat then return false end
    return true
end

local function recklessness_matches(context, state)
    if not cooldowns_allowed(context, state) then return false end
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    if state.hp < 50 then return false end
    if not execute_phase(context, state) and state.target_hp > 35 then return false end
    return action(context, build_action("Recklessness", ACTION.Recklessness, { target = "self", required_stance = STANCE.BERSERKER, requires_target = false, cooldown = 1800 }))
end

local function retaliation_matches(context, state)
    if state.hp > 45 and state.enemy_count < 2 then return false end
    if not cooldowns_allowed(context, state) then return false end
    return action(context, build_action("Retaliation", ACTION.Retaliation, { target = "self", required_stance = STANCE.BATTLE, requires_target = false, cooldown = 1800 }))
end

local function shield_wall_matches(context, state)
    local threshold = state.is_group and 40 or 25
    if state.hp > threshold then return false end
    return action(context, build_action("ShieldWall", ACTION.ShieldWall, { target = "self", required_stance = STANCE.DEFENSIVE, requires_target = false, cooldown = 1800 }))
end

-- Healthstone auto-use (item-based, off-GCD, OOC only)
local function healthstone_matches(context, state)
    if not state.healthstone_ready then return false end
    if state.hp > HEALTHSTONE_HP_THRESHOLD then return false end
    -- Respect menu setting
    local hs_hp = spec_kit.setting_number(context, "healthstone_hp", HEALTHSTONE_HP_THRESHOLD)
    if state.hp > hs_hp then return false end
    return true
end

local STRATEGY_SPECS = {
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
    { "SpellReflection", spell_reflect_matches, build_action("SpellReflection", ACTION.SpellReflection, { target = "self", required_stance = STANCE.DEFENSIVE, min_rage = 15, requires_target = false }) },
    { "ShieldWall", shield_wall_matches, build_action("ShieldWall", ACTION.ShieldWall, { target = "self", required_stance = STANCE.DEFENSIVE, requires_target = false }) },
    { "IntimidatingShout", intimidating_shout_matches, build_action("IntimidatingShout", ACTION.IntimidatingShout, { target = "self", min_rage = 25, requires_target = false }) },
    { "Pummel", pummel_matches, build_action("Pummel", ACTION.Pummel, { required_stance = STANCE.BERSERKER, min_rage = 10 }) },
    { "Intercept", intercept_matches, build_action("Intercept", ACTION.Intercept, { required_stance = STANCE.BERSERKER, min_rage = 10 }) },
    { "Disarm", disarm_matches, build_action("Disarm", ACTION.Disarm, { required_stance = STANCE.DEFENSIVE, min_rage = 20 }) },
    { "Charge", charge_matches, build_action("Charge", ACTION.Charge, { required_stance = STANCE.BATTLE }) },
    { "DefensiveStance", defensive_stance_matches, defensive_stance_action() },
    { "BattleStance", battle_stance_matches, battle_stance_action() },
    { "BerserkerStance", berserker_stance_matches, berserker_stance_action() },
    { "CommandingShout", commanding_shout_matches, build_action("CommandingShout", ACTION.CommandingShout, { target = "self", kind = "buff", buff = COMMANDING_SHOUT_BUFF, requires_target = false, min_rage = 10 }) },
    { "BattleShout", battle_shout_matches, build_action("BattleShout", ACTION.BattleShout, { target = "self", kind = "buff", buff = BATTLE_SHOUT_BUFF, requires_target = false }) },
    { "SunderArmor", sunder_armor_matches, build_action("SunderArmor", ACTION.SunderArmor, { required_stance = STANCE.BATTLE, min_rage = 15, debuff = SUNDER_DEBUFF, refresh = 28 }) },
    { "Bloodrage", bloodrage_matches, build_action("Bloodrage", ACTION.Bloodrage, { target = "self", requires_target = false, skip_gcd = true }) },
    { "VictoryRush", victory_rush_matches, build_action("VictoryRush", ACTION.VictoryRush, {}) },
    { "Retaliation", retaliation_matches, build_action("Retaliation", ACTION.Retaliation, { target = "self", required_stance = STANCE.BATTLE, requires_target = false }) },
    { "Recklessness", recklessness_matches, build_action("Recklessness", ACTION.Recklessness, { target = "self", required_stance = STANCE.BERSERKER, requires_target = false }) },
    { "DeathWish", death_wish_matches, build_action("DeathWish", ACTION.DeathWish, { target = "self", requires_target = false }) },
    { "BerserkerRage", berserker_rage_matches, build_action("BerserkerRage", ACTION.BerserkerRage, { target = "self", required_stance = STANCE.BERSERKER, requires_target = false }) },
    { "Execute", execute_matches, build_action("Execute", ACTION.Execute, { min_rage = 15 }) },
    { "MortalStrike", mortal_strike_matches, build_action("MortalStrike", ACTION.MortalStrike, { required_stance = STANCE.BATTLE, min_rage = MORTAL_STRIKE_RAGE, cooldown = 6 }) },
    { "Overpower", overpower_matches, build_action("Overpower", ACTION.Overpower, { required_stance = STANCE.BATTLE, min_rage = OVERPOWER_RAGE }) },
    { "Slam", slam_matches, build_action("Slam", ACTION.Slam, { required_stance = STANCE.BATTLE, min_rage = SLAM_RAGE, not_moving = true }) },
    { "Whirlwind", whirlwind_matches, build_action("Whirlwind", ACTION.Whirlwind, { required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10 }) },
    { "SweepingStrikes", sweeping_strikes_matches, build_action("SweepingStrikes", ACTION.SweepingStrikes, { target = "self", required_stance = STANCE.BATTLE, min_rage = 30, requires_target = false }) },
    { "Rend", rend_matches, build_action("Rend", ACTION.Rend, { required_stance = STANCE.BATTLE, min_rage = 10, debuff = REND_DEBUFF, refresh = 3, creature_types = BLEED_IMMUNE_TYPES }) },
    { "PiercingHowl", piercing_howl_matches, build_action("PiercingHowl", ACTION.PiercingHowl, { target = "self", min_rage = 10, requires_target = false, enemy_count = 2 }) },
    { "Hamstring", hamstring_matches, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }) },
    { "DemoralizingShout", demo_shout_matches, build_action("DemoralizingShout", ACTION.DemoralizingShout, { target = "self", min_rage = 10, requires_target = false }) },
    { "ThunderClap", thunder_clap_matches, build_action("ThunderClap", ACTION.ThunderClap, { target = "self", required_stance = STANCE.BATTLE, min_rage = 20, requires_target = false, cooldown = 4 }) },
    { "Cleave", cleave_matches, build_action("Cleave", ACTION.Cleave, { min_rage = CLEAVE_RAGE, enemy_count = 2, is_aoe = true }) },
    { "HeroicStrike", heroic_strike_matches, build_action("HeroicStrike", ACTION.HeroicStrike, { min_rage = HEROIC_STRIKE_RAGE }) },
    { "Healthstone", healthstone_matches, build_action("Healthstone", nil, { target = "self", requires_target = false }), function(context)
        local s = build_state(context or {})
        if s.healthstone_id and NS.use_item_by_id then
            return NS.use_item_by_id(s.healthstone_id, context.me or context.target)
        end
        return false
    end },
    -- Engineering bombs (wowsims APL "Engineering" group)
    { "EngineeringBomb", function(context)
          if not engineering then return false end
          return engineering.should_use_bomb(context)
      end, build_action("EngineeringBomb", nil, { target = "self", requires_target = false }), function(context)
          if not engineering then return false end
          return engineering.use_best_bomb(context)
      end },
}

local strategies = {}
local _build = build_state

for i = 1, #STRATEGY_SPECS do
    local spec = STRATEGY_SPECS[i]
    local name = spec[1]
    local matches = spec[2]
    local row = spec[3]

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
        execute = spec[4] or function(context)
            return cast(context or {}, row)
        end,
    }
end

-- Hit-cap awareness: gate missable abilities when significantly below cap
strategies[#strategies + 1] = {
    name = "HitCapPriority",
    matches = function(context)
        local state = _build(context or {})
        if not state.hit_cap_rating_needed then return false end
        local hit_rating = context.hit_rating
        if not hit_rating then return false end
        local deficit = state.hit_cap_rating_needed - hit_rating
        if deficit <= 30 then return false end
        if NS.log then NS.log(string.format("[ARMS] Hit cap deficit %d — gating missable abilities", deficit)) end
        return true
    end,
    execute = function() return true end,
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("arms", strategies, { get_state = build_state })
end
-- Warrior arms rotation registered (deep TBC enhanced)
return { strategies = strategies, build_state = build_state }
