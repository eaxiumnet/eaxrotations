-- arms_vanilla.lua — Warrior Arms for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  PvP/leveling DPS (Mortal Strike, Overpower, Whirlwind, Rend).
-- WHEN:  combat, when NS.is_vanilla() is true.
-- WHY:   non-meta PvE in Vanilla; viable for PvP and leveling.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }
local PLAYER_UNIT = NS.PLAYER_UNIT


local function spell(field, ids, label)
    if SPELLS[field] ~= nil then return SPELLS[field] end
    if NS.spell_action then return NS.spell_action(ids, label or field) end
    if type(ids) == "table" then return ids[1] end
    return ids
end

local ACTION = {
    BattleShout = spell("BattleShout", { 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
    BattleStance = spell("BattleStance", 2457, "BattleStance"),
    BerserkerRage = spell("BerserkerRage", 18499, "BerserkerRage"),
    BerserkerStance = spell("BerserkerStance", 2458, "BerserkerStance"),
    Bloodrage = spell("Bloodrage", 2687, "Bloodrage"),
    Charge = spell("Charge", { 11578, 6178, 100 }, "Charge"),
    Cleave = spell("Cleave", { 20569, 11609, 11608, 7369, 845 }, "Cleave"),
    DeathWish = SPELLS.DeathWish,  -- uses expansion-aware IDs from class_sylvanas.lua (Vanilla: 12328)
    DefensiveStance = spell("DefensiveStance", 71, "DefensiveStance"),
    DemoralizingShout = spell("DemoralizingShout", { 11556, 11555, 11554, 6190, 1160 }, "DemoralizingShout"),
    Disarm = spell("Disarm", 676, "Disarm"),
    Execute = spell("Execute", { 20662, 20661, 20660, 20658, 5308 }, "Execute"),
    Hamstring = spell("Hamstring", { 7373, 7372, 1715 }, "Hamstring"),
    HeroicStrike = spell("HeroicStrike", { 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    Intercept = spell("Intercept", { 20617, 20616, 20252 }, "Intercept"),
    IntimidatingShout = spell("IntimidatingShout", 5246, "IntimidatingShout"),
    MortalStrike = spell("MortalStrike", { 21553, 21552, 21551, 12294 }, "MortalStrike"),
    Overpower = spell("Overpower", { 11585, 7887, 7384 }, "Overpower"),
    PiercingHowl = spell("PiercingHowl", 12323, "PiercingHowl"),
    Pummel = NS.spell_action and NS.spell_action({ 6554, 6552 }, "Pummel") or 6554,
    Recklessness = spell("Recklessness", 1719, "Recklessness"),
    Rend = spell("Rend", { 11574, 11573, 6548, 6547, 772 }, "Rend"),
    Retaliation = spell("Retaliation", 20230, "Retaliation"),
    ShieldWall = spell("ShieldWall", 871, "ShieldWall"),
    Slam = spell("Slam", { 11605, 11604, 8820, 1464 }, "Slam"),
    SunderArmor = spell("SunderArmor", { 11597, 11596, 8380, 7405, 7386 }, "SunderArmor"),
    SweepingStrikes = SPELLS.SweepingStrikes,  -- uses expansion-aware IDs from class_sylvanas.lua (Vanilla: 12292)
    ThunderClap = spell("ThunderClap", { 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
    Whirlwind = spell("Whirlwind", 1680, "Whirlwind"),
}

local BATTLE_SHOUT_BUFF = { 11551, 11550, 11549, 6192, 5242, 6673 }
local BERSERKER_RAGE_BUFF = { 18499 }
local DEMO_SHOUT_DEBUFF = { 11556, 11555, 11554, 6190, 1160 }
local HAMSTRING_DEBUFF = { 7373, 7372, 1715 }
local MORTAL_STRIKE_DEBUFF = { 21553, 21552, 21551, 12294 }
local REND_DEBUFF = { 11574, 11573, 6548, 6547, 772 }
local SUNDER_DEBUFF = { 11597, 11596, 8380, 7405, 7386 }
local SWEEPING_STRIKES_BUFF = { 12292 }  -- Vanilla ID (TBC=12328; different ID per expansion)
local THUNDER_CLAP_DEBUFF = { 11581, 11580, 8205, 8204, 8198, 6343 }

local HEALTHSTONE_IDS = (TBC and TBC.ITEMS and TBC.ITEMS.healthstones) or { 22116, 22105, 22104, 22103, 22102, 22101 }

local HEALTHSTONE_HP_THRESHOLD = 35
local EXECUTE_DEFAULT_RAGE = 25
local HEROIC_STRIKE_RAGE = 60
local CLEAVE_RAGE = 55
local MORTAL_STRIKE_RAGE = 30
local OVERPOWER_RAGE = 5
local SLAM_RAGE = 15
local RAGE_CAP = 90
local SLAM_CAST_TIME = 0.5
local SLAM_SAFETY = 0.2
local SWEEPING_STRIKES_COUNT = 2
local TACTICAL_MASTERY_CAP = 25
local HAMSTRING_SPAM_RAGE = 55
-- Sweeping Strikes rage pooling (from kebab pattern)
local SS_RESERVE_FLOOR = 60
local SS_POOL_WINDOW = 2.0

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
    has_battle_shout = false,
    has_berserker_rage = false,
    has_sweeping_strikes = false,
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

local setting = spec_kit.setting

local function player_target(context, action_row)
    if action_row and action_row.target == "self" then return context.me or NS.GetPlayer() end
    return context.target
end

local function bool_call(unit, method)
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

local function execute_phase(context, state)
    if NS.is_execute_phase then return NS.is_execute_phase(context.target_hp, 20) end
    return (state.target_hp or context.target_hp or 100) <= 20
end

local function desired_stance(context)
    local preference = setting(context, "stance_preference", "auto")
    if preference == "battle" or preference == STANCE.BATTLE then return STANCE.BATTLE end
    if preference == "defensive" or preference == STANCE.DEFENSIVE then return STANCE.DEFENSIVE end
    if preference == "berserker" or preference == STANCE.BERSERKER then return STANCE.BERSERKER end
    return nil
end

local function preserved_rage_after_swap(rage)
    if NS.get_tactical_mastery_cap then return NS.get_tactical_mastery_cap() end
    return rage < TACTICAL_MASTERY_CAP and rage or TACTICAL_MASTERY_CAP
end

local function stance_swap_safe(state, cost)
    local effective_cost = math.min(cost or 0, 15)
    if state.stance == nil then return true end
    return preserved_rage_after_swap(state.rage or 0) >= effective_cost
end

local function action(context, row)
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

local function cast(context, row)
    if not context or not row then return false end
    if not row.spell then return false end
    local target = (row.target == "self" or row.requires_target == false) and (context.me or NS.GetPlayer()) or context.target
    if not target then return false end
    local opts = {}
    if row.requires_target == false then opts.skip_range = true end
    if row.cooldown then opts.expected_cooldown = row.cooldown end
    return NS.try_cast(row.spell, target, "[ARMS]", opts)
end

local function build_action(name, spell_value, opts)
    local row = opts or {}
    row.name = name
    row.spell = spell_value
    return row
end

local _last_build_state_time = -1
local function build_state(context)
    local state = arms_state
    local now = context.now
    if now and now == _last_build_state_time then return state end
    now = now or (NS.time_now and NS.time_now() or 0)
    if context.now then _last_build_state_time = now end
    state.now = now
    local target = context.target
    local me = context.me or NS.GetPlayer()

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
    arms_state.target_in_combat = target and bool_call(target, "is_in_combat") or false

    arms_state.has_battle_shout = NS.buff_up(me, BATTLE_SHOUT_BUFF) or false
    arms_state.has_berserker_rage = NS.buff_up(me, BERSERKER_RAGE_BUFF) or false
    arms_state.has_sweeping_strikes = NS.buff_up(me, SWEEPING_STRIKES_BUFF) or false

    arms_state.ms_remains = NS.debuff_remains(target, MORTAL_STRIKE_DEBUFF) or 0
    arms_state.rend_remains = NS.debuff_remains(target, REND_DEBUFF) or 0
    arms_state.hamstring_remains = NS.debuff_remains(target, HAMSTRING_DEBUFF) or 0
    arms_state.demo_remains = NS.debuff_remains(target, DEMO_SHOUT_DEBUFF) or 0
    arms_state.tclap_remains = NS.debuff_remains(target, THUNDER_CLAP_DEBUFF) or 0
    arms_state.sunder_stacks = NS.debuff_stacks(target, SUNDER_DEBUFF) or 0

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
    arms_state.disarm_ready = NS.spell_ready(ACTION.Disarm, target) or false
    arms_state.intimidating_ready = NS.spell_ready(ACTION.IntimidatingShout, me, { skip_range = true }) or false
    arms_state.thunder_ready = NS.spell_ready(ACTION.ThunderClap, me, { skip_range = true, expected_cooldown = 4 }) or false
    arms_state.demo_ready = NS.spell_ready(ACTION.DemoralizingShout, me, { skip_range = true }) or false
    arms_state.bloodrage_ready = NS.spell_ready(ACTION.Bloodrage, me, { skip_range = true }) or false
    arms_state.death_wish_ready = NS.spell_ready(ACTION.DeathWish, me, { skip_range = true }) or false
    arms_state.recklessness_ready = NS.spell_ready(ACTION.Recklessness, me, { skip_range = true }) or false
    arms_state.retaliation_ready = NS.spell_ready(ACTION.Retaliation, me, { skip_range = true }) or false
    arms_state.shield_wall_ready = NS.spell_ready(ACTION.ShieldWall, me, { skip_range = true }) or false

    arms_state.execute_phase = execute_phase(context, arms_state)

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

    arms_state.mh_until = me and NS.swing_time_until(me) or 999
    arms_state.mh_progress = me and NS.swing_progress(me) or 0

    return arms_state
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
    if state.has_battle_shout then return false end
    return action(context, build_action("BattleShout", ACTION.BattleShout, { target = "self", kind = "buff", buff = BATTLE_SHOUT_BUFF, requires_target = false, min_rage = 10 }))
end

local function execute_matches(context, state)
    if not execute_phase(context, state) then return false end
    local min_rage = setting(context, "execute_phase_rage", EXECUTE_DEFAULT_RAGE)
    if context.rage ~= nil and (state.rage or 0) < min_rage then return false end
    return action(context, build_action("Execute", ACTION.Execute, { min_rage = 15 }))
end

local function mortal_strike_matches(context, state)
    if (state.rage or 0) >= RAGE_CAP then return action(context, build_action("MortalStrike", ACTION.MortalStrike, { required_stance = STANCE.BATTLE, min_rage = MORTAL_STRIKE_RAGE, cooldown = 6 })) end
    return action(context, build_action("MortalStrike", ACTION.MortalStrike, { required_stance = STANCE.BATTLE, min_rage = MORTAL_STRIKE_RAGE, cooldown = 6 }))
end

local function overpower_matches(context, state)
    if not state.overpower_ready then return false end
    -- Rage protection: skip Overpower if MS is imminent and rage is too low for both
    local ms_cd = state.ms_cd or 99
    if ms_cd <= 1.5 and (state.rage or 0) < MORTAL_STRIKE_RAGE then return false end
    return action(context, build_action("Overpower", ACTION.Overpower, { required_stance = STANCE.BATTLE, min_rage = OVERPOWER_RAGE }))
end

local function target_creature_type(unit)
    if not unit or not unit.get_creature_type then return nil end
    local ok, value = pcall(unit.get_creature_type, unit)
    return ok and value or nil
end
local BLEED_IMMUNE_TYPES = { [4]=true, [6]=true, [9]=true }  -- Elemental, Undead, Mechanical

local function rend_matches(context, state)
    if execute_phase(context, state) then return false end
    if (state.rend_remains or 0) > 3 then return false end
    if (state.target_hp or 100) < 25 then return false end
    -- Skip Rend on bleed-immune creatures (Elemental, Undead, Mechanical)
    local ctype = target_creature_type(context.target)
    if ctype and BLEED_IMMUNE_TYPES[ctype] then return false end
    return action(context, build_action("Rend", ACTION.Rend, { required_stance = STANCE.BATTLE, min_rage = 10, debuff = REND_DEBUFF, refresh = 3 }))
end

local function slam_matches(context, state)
    if setting(context, "slam_weave_enabled", true) == false then return false end
    if state.is_moving then return false end
    -- Rage cap: bypass rage gate to prevent waste when capped
    if (state.rage or 0) >= RAGE_CAP then return action(context, build_action("Slam", ACTION.Slam, { required_stance = STANCE.BATTLE, min_rage = SLAM_RAGE, not_moving = true })) end
    if (state.rage or 0) < SLAM_RAGE then return false end
    if (state.ms_cd or 99) <= 1.0 or state.overpower_ready then return false end
    if (state.mh_until or 999) <= SLAM_CAST_TIME + SLAM_SAFETY then return false end
    if (state.mh_until or 999) > 1.5 then return false end
    return action(context, build_action("Slam", ACTION.Slam, { required_stance = STANCE.BATTLE, min_rage = SLAM_RAGE, not_moving = true }))
end

local function sweeping_strikes_matches(context, state)
    local min_count = setting(context, "sweeping_strikes_count", SWEEPING_STRIKES_COUNT)
    if (state.enemy_count or 0) < min_count then return false end
    if state.has_sweeping_strikes then return false end
    return action(context, build_action("SweepingStrikes", ACTION.SweepingStrikes, { target = "self", required_stance = STANCE.BATTLE, min_rage = 30, requires_target = false, enemy_count = min_count, cooldown = 30 }))
end

local function sunder_armor_matches(context, state)
    if not setting(context, "use_sunder_armor", false) then return false end
    -- Skip if target has no armor (API unavailable or already fully reduced)
    if (context.target_armor or 0) <= 0 then return false end
    if (state.sunder_stacks or 0) >= 5 then return false end
    if (state.rage or 0) < 15 then return false end
    if state.execute_phase then return false end
    return action(context, build_action("SunderArmor", ACTION.SunderArmor, { required_stance = STANCE.DEFENSIVE, min_rage = 15, debuff = SUNDER_DEBUFF, refresh = 28 }))
end

local function whirlwind_matches(context, state)
    if not state.ww_ready then return false end
    local rage = state.rage or 0
    -- Rage cap: bypass multi gate to prevent rage waste
    if rage >= RAGE_CAP then
        return action(context, build_action("Whirlwind", ACTION.Whirlwind, {
            required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10,
            hit_radius = 8, hit_origin = "me",
        }))
    end
    -- Whirlwind: 8yd self PBAoE (DBC) — not 40yd enemy_count
    if rage < 45 and not (NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)) then
        return false
    end
    return action(context, build_action("Whirlwind", ACTION.Whirlwind, {
        required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10,
        enemy_count = 2, hit_radius = 8, hit_origin = "me",
    }))
end

-- Sweep Strikes rage pooling: hold rage when SS cooldown is near
local function should_reserve_for_sweeping(context, state)
    -- SS needs a second melee target near primary — target-centered 8yd
    if not (NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context.target, context, state)) then
        return false
    end
    if state.has_sweeping_strikes then return false end
    local ss_cd = state.ss_cd or 99
    if ss_cd <= SS_POOL_WINDOW and (context.rage or 0) < SS_RESERVE_FLOOR then return true end
    return false
end

local function heroic_strike_matches(context, state)
    if state and should_reserve_for_sweeping(context, state) then return false end
    return action(context, build_action("HeroicStrike", ACTION.HeroicStrike, { min_rage = HEROIC_STRIKE_RAGE }))
end

local function cleave_matches(context, state)
    if state and should_reserve_for_sweeping(context, state) then return false end
    -- Cleave: primary + nearest ally near target (TARGET_8)
    if not (NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context.target, context, state)) then
        return false
    end
    if (state.rage or 0) < CLEAVE_RAGE then return false end
    return action(context, build_action("Cleave", ACTION.Cleave, {
        min_rage = CLEAVE_RAGE, enemy_count = 2, is_aoe = true,
        hit_radius = 8, hit_origin = "target",
    }))
end

local function hamstring_matches(context, state)
    if state.is_pvp then
        if (state.hamstring_remains or 0) > 3 then return false end
        return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }))
    end
    local tactician_enabled = setting(context, "hamstring_tactician_weave", true)
    local weave_rage = setting(context, "hamstring_weave_rage", HAMSTRING_SPAM_RAGE)
    if tactician_enabled and not state.execute_phase and (state.rage or 0) >= weave_rage and (state.ms_cd or 99) > 1.5 then
        return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10 }))
    end
    if setting(context, "hamstring_fleeing_mobs", true) and (state.hamstring_remains or 0) <= 3 then
        return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }))
    end
    return false
end

local function piercing_howl_matches(context, state)
    -- Piercing Howl: 10yd self PBAoE (DBC)
    if not state.is_pvp and not (NS.aoe_self_meets and NS.aoe_self_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, state)) then
        return false
    end
    if (state.rage or 0) < 10 then return false end
    return action(context, build_action("PiercingHowl", ACTION.PiercingHowl, {
        target = "self", min_rage = 10, requires_target = false,
        enemy_count = 2, is_aoe = true, hit_radius = 10, hit_origin = "me",
    }))
end

local function demo_shout_matches(context, state)
    if (state.demo_remains or 0) > 5 then return false end
    if not state.is_pvp and (state.hp or 100) > 70
        and not (NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, state)) then
        return false
    end
    return action(context, build_action("DemoralizingShout", ACTION.DemoralizingShout, {
        target = "self", min_rage = 10, requires_target = false,
        debuff = DEMO_SHOUT_DEBUFF, refresh = 5, hit_radius = 10, hit_origin = "me",
    }))
end

local function thunder_clap_matches(context, state)
    if (state.tclap_remains or 0) > 5 then return false end
    -- Thunder Clap: 8yd self PBAoE
    if not state.is_pvp and (state.hp or 100) > 65
        and not (NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)) then
        return false
    end
    return action(context, build_action("ThunderClap", ACTION.ThunderClap, {
        target = "self", required_stance = STANCE.BATTLE, min_rage = 20, requires_target = false,
        debuff = THUNDER_CLAP_DEBUFF, refresh = 5, cooldown = 4,
        hit_radius = 8, hit_origin = "me",
    }))
end

local function pummel_matches(context, state)
    if not state.target_is_casting then return false end
    if not (state.target_casting_interruptible or false) then return false end
    return action(context, build_action("Pummel", ACTION.Pummel, { required_stance = STANCE.BERSERKER, min_rage = 10 }))
end

local function disarm_matches(context, state)
    if not state.is_pvp then return false end
    if not state.target_is_melee and not is_player_or_pet(context.target) then return false end
    return action(context, build_action("Disarm", ACTION.Disarm, { required_stance = STANCE.DEFENSIVE, min_rage = 20 }))
end

local function intercept_matches(context, state)
    if (state.target_distance or 0) < 8 or (state.target_distance or 0) > 25 then return false end
    local auto_charge = setting(context, "auto_charge", true)
    if not auto_charge then return false end
    if not (NS.spell_ready(ACTION.Intercept, context.target) or false) then return false end
    return action(context, build_action("Intercept", ACTION.Intercept, { required_stance = STANCE.BERSERKER, min_rage = 10, cooldown = 30 }))
end

local function charge_matches(context, state)
    local auto_charge = setting(context, "auto_charge", true)
    if not auto_charge then return false end
    if state.in_combat then return false end
    if (state.target_distance or 0) < 8 or (state.target_distance or 0) > 25 then return false end
    local charge_only_ooc = setting(context, "charge_only_ooc", true)
    if charge_only_ooc and (context.target and bool_call(context.target, "is_in_combat")) then return false end
    if not (NS.spell_ready(ACTION.Charge, context.target) or false) then return false end
    return action(context, build_action("Charge", ACTION.Charge, { required_stance = STANCE.BATTLE, cooldown = 15 }))
end

local function intimidating_shout_matches(context, state)
    if not state.is_pvp and (state.hp or 100) > 35 and (state.enemy_count or 0) < 3 then return false end
    return action(context, build_action("IntimidatingShout", ACTION.IntimidatingShout, { target = "self", min_rage = 25, requires_target = false, cooldown = 180 }))
end

local function battle_stance_matches(context, state)
    if state.stance == STANCE.BATTLE then return false end
    if desired_stance(context) == STANCE.BATTLE then return action(context, battle_stance_action()) end
    if state.overpower_ready and stance_swap_safe(state, OVERPOWER_RAGE) then return action(context, battle_stance_action()) end
    if (state.ms_cd or 99) <= 0.3 and stance_swap_safe(state, MORTAL_STRIKE_RAGE) then return action(context, battle_stance_action()) end
    return false
end

local function berserker_stance_matches(context, state)
    if state.stance == STANCE.BERSERKER then return false end
    if desired_stance(context) == STANCE.BERSERKER then return action(context, berserker_stance_action()) end
    if state.execute_phase and (state.rage or 0) >= 15 and stance_swap_safe(state, 15) then
        return action(context, berserker_stance_action())
    end
    if state.ww_ready and stance_swap_safe(state, 25) and ((state.enemy_count or 0) >= 2 or (state.rage or 0) >= 45) then return action(context, berserker_stance_action()) end
    if state.is_pvp and (state.target_distance or 0) >= 8 and stance_swap_safe(state, 10) then return action(context, berserker_stance_action()) end
    return false
end

local function defensive_stance_matches(context, state)
    if state.stance == STANCE.DEFENSIVE then return false end
    if desired_stance(context) == STANCE.DEFENSIVE then return action(context, defensive_stance_action()) end
    if (state.hp or 100) <= 30 and stance_swap_safe(state, 0) then return action(context, defensive_stance_action()) end
    if state.is_pvp and state.target_is_casting and stance_swap_safe(state, 15) then return action(context, defensive_stance_action()) end
    if state.is_pvp and state.target_is_melee and stance_swap_safe(state, 20) then return action(context, defensive_stance_action()) end
    return false
end

local function cooldowns_allowed(context, state)
    local setting_use = setting(context, "use_cooldowns", true)
    if not setting_use then return false end
    return true
end

local function bloodrage_matches(context, state)
    if (state.rage or 0) >= 20 then return false end
    if not state.in_combat and (state.hp or 100) < 90 then return false end
    if not cooldowns_allowed(context, state) then return false end
    return action(context, build_action("Bloodrage", ACTION.Bloodrage, { target = "self", requires_target = false, skip_gcd = true, cooldown = 60 }))
end

local function death_wish_matches(context, state)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    if not cooldowns_allowed(context, state) then return false end
    if not NS.gate_cooldown_boss_only(context) then return false end
    if (state.hp or 100) < 45 then return false end
    if (state.target_hp or 100) < 20 and (state.rage or 0) < 25 then return false end
    return action(context, build_action("DeathWish", ACTION.DeathWish, { target = "self", requires_target = false, cooldown = 180 }))
end

local function recklessness_matches(context, state)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 1800) then return false end
    if not cooldowns_allowed(context, state) then return false end
    if not NS.gate_cooldown_boss_only(context) then return false end
    if (state.hp or 100) < 50 then return false end
    if not execute_phase(context, state) and (state.target_hp or 100) > 35 then return false end
    return action(context, build_action("Recklessness", ACTION.Recklessness, { target = "self", required_stance = STANCE.BERSERKER, requires_target = false, cooldown = 1800 }))
end

local function retaliation_matches(context, state)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 1800) then return false end
    if (state.hp or 100) > 45 and (state.enemy_count or 0) < 2 then return false end
    if not cooldowns_allowed(context, state) then return false end
    return action(context, build_action("Retaliation", ACTION.Retaliation, { target = "self", required_stance = STANCE.BATTLE, requires_target = false, cooldown = 1800 }))
end

local function shield_wall_matches(context, state)
    if (state.hp or 100) > 25 then return false end
    return action(context, build_action("ShieldWall", ACTION.ShieldWall, { target = "self", required_stance = STANCE.DEFENSIVE, requires_target = false, cooldown = 1800 }))
end

local function healthstone_matches(context, state)
    if not state.healthstone_ready then return false end
    if (state.hp or 100) > HEALTHSTONE_HP_THRESHOLD then return false end
    local hs_hp = setting(context, "healthstone_hp", HEALTHSTONE_HP_THRESHOLD)
    if (state.hp or 100) > hs_hp then return false end
    return true
end

local STRATEGY_SPECS = {
    { "HealthPotion", function(context)
          if not context.in_combat then return false end
          if spec_kit.setting_bool(context, "use_auto_potions", true) == false then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end, build_action("HealthPotion", nil, { target = "self", requires_target = false }), function(context)
          return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS)
      end },
    { "DamagePotion", function(context)
          if not context.in_combat then return false end
          if spec_kit.setting_bool(context, "use_auto_potions", true) == false then return false end
          if not context.has_damage_potion then return false end
          if not context.should_burst then return false end
          return true
      end, build_action("DamagePotion", nil, { target = "self", requires_target = false }), function(context)
          return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS)
      end },
    { "Pummel", pummel_matches, build_action("Pummel", ACTION.Pummel, { required_stance = STANCE.BERSERKER, min_rage = 10 }) },
    { "ShieldWall", shield_wall_matches, build_action("ShieldWall", ACTION.ShieldWall, { target = "self", required_stance = STANCE.DEFENSIVE, requires_target = false }) },
    { "IntimidatingShout", intimidating_shout_matches, build_action("IntimidatingShout", ACTION.IntimidatingShout, { target = "self", min_rage = 25, requires_target = false }) },
    { "Intercept", intercept_matches, build_action("Intercept", ACTION.Intercept, { required_stance = STANCE.BERSERKER, min_rage = 10 }) },
    { "Disarm", disarm_matches, build_action("Disarm", ACTION.Disarm, { required_stance = STANCE.DEFENSIVE, min_rage = 20 }) },
    { "Charge", charge_matches, build_action("Charge", ACTION.Charge, { required_stance = STANCE.BATTLE }) },
    { "DefensiveStance", defensive_stance_matches, defensive_stance_action() },
    { "BattleStance", battle_stance_matches, battle_stance_action() },
    { "BerserkerStance", berserker_stance_matches, berserker_stance_action() },
    { "BattleShout", battle_shout_matches, build_action("BattleShout", ACTION.BattleShout, { target = "self", kind = "buff", buff = BATTLE_SHOUT_BUFF, requires_target = false }) },
    { "Bloodrage", bloodrage_matches, build_action("Bloodrage", ACTION.Bloodrage, { target = "self", requires_target = false, skip_gcd = true }) },
    { "Retaliation", retaliation_matches, build_action("Retaliation", ACTION.Retaliation, { target = "self", required_stance = STANCE.BATTLE, requires_target = false }) },
    { "Recklessness", recklessness_matches, build_action("Recklessness", ACTION.Recklessness, { target = "self", required_stance = STANCE.BERSERKER, requires_target = false }) },
    { "DeathWish", death_wish_matches, build_action("DeathWish", ACTION.DeathWish, { target = "self", requires_target = false }) },
    -- Vanilla Arms APL: Execute is THE top GCD in execute phase (<20% HP).
    -- Rend applied early + maintained (Blood Frenzy raid buff + Taste-for-Blood procs).
    -- MS > Overpower > WW > Slam filler per Icy Veins / Wowhead Classic guides.
    { "Execute", execute_matches, build_action("Execute", ACTION.Execute, { min_rage = 15 }) },
    { "MortalStrike", mortal_strike_matches, build_action("MortalStrike", ACTION.MortalStrike, { required_stance = STANCE.BATTLE, min_rage = MORTAL_STRIKE_RAGE, cooldown = 6 }) },
    { "Overpower", overpower_matches, build_action("Overpower", ACTION.Overpower, { required_stance = STANCE.BATTLE, min_rage = OVERPOWER_RAGE }) },
    { "SweepingStrikes", sweeping_strikes_matches, build_action("SweepingStrikes", ACTION.SweepingStrikes, { target = "self", required_stance = STANCE.BATTLE, min_rage = 30, requires_target = false }) },
    { "Whirlwind", whirlwind_matches, build_action("Whirlwind", ACTION.Whirlwind, { required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10 }) },
    { "Rend", rend_matches, build_action("Rend", ACTION.Rend, { required_stance = STANCE.BATTLE, min_rage = 10, debuff = REND_DEBUFF, refresh = 3, creature_types = { [1]=true, [2]=true, [3]=true, [5]=true, [7]=true, [8]=true, [10]=true } }) },
    { "Slam", slam_matches, build_action("Slam", ACTION.Slam, { required_stance = STANCE.BATTLE, min_rage = SLAM_RAGE, not_moving = true }) },
    { "PiercingHowl", piercing_howl_matches, build_action("PiercingHowl", ACTION.PiercingHowl, { target = "self", min_rage = 10, requires_target = false, enemy_count = 2 }) },
    { "Hamstring", hamstring_matches, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }) },
    { "DemoralizingShout", demo_shout_matches, build_action("DemoralizingShout", ACTION.DemoralizingShout, { target = "self", min_rage = 10, requires_target = false }) },
    { "ThunderClap", thunder_clap_matches, build_action("ThunderClap", ACTION.ThunderClap, { target = "self", required_stance = STANCE.BATTLE, min_rage = 20, requires_target = false, cooldown = 4 }) },
    { "Cleave", cleave_matches, build_action("Cleave", ACTION.Cleave, { min_rage = CLEAVE_RAGE, enemy_count = 2, is_aoe = true }) },
    { "HeroicStrike", heroic_strike_matches, build_action("HeroicStrike", ACTION.HeroicStrike, { min_rage = HEROIC_STRIKE_RAGE }) },
    { "SunderArmor", sunder_armor_matches, build_action("SunderArmor", ACTION.SunderArmor, { required_stance = STANCE.DEFENSIVE, min_rage = 15, debuff = SUNDER_DEBUFF, refresh = 28 }) },
    { "Healthstone", healthstone_matches, build_action("Healthstone", nil, { target = "self", requires_target = false }), function(context)
        local s = build_state(context or {})
        if s.healthstone_id and NS.use_item_by_id then
            return NS.use_item_by_id(s.healthstone_id, context.me or context.target)
        end
        return false
    end },
}

local strategies = {}

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
        creature_types = row.creature_types,
        matches = function(context)
            local state = build_state(context or {})
            return matches(context or {}, state)
        end,
        execute = spec[4] or function(context)
            return cast(context or {}, row)
        end,
    }
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("arms", strategies, { get_state = build_state })
end
-- Warrior arms_vanilla rotation registered (Classic Vanilla)
return strategies
