-- Warrior Arms priority list ? Classic Vanilla
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }
local PLAYER_UNIT = NS.PLAYER_UNIT

local _swing_ok, SwingTimer = pcall(require, "shared/swing_timer_sylvanas")
if not _swing_ok or type(SwingTimer) ~= "table" then SwingTimer = nil end

local function spell(field, ids, label)
    if SPELLS[field] ~= nil then return SPELLS[field] end
    if NS.spell_action then return NS.spell_action(ids, label or field) end
    if type(ids) == "table" then return ids[1] end
    return ids
end

local ACTION = {
    BattleShout = spell("BattleShout", { 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
    BattleStance = spell("BattleStance", 2457, "BattleStance"),
    BerserkerRage = spell("BerserkerRage", 18499, "BerserkerRage"),
    BerserkerStance = spell("BerserkerStance", 2458, "BerserkerStance"),
    Bloodrage = spell("Bloodrage", 2687, "Bloodrage"),
    Charge = spell("Charge", { 11578, 6178, 100 }, "Charge"),
    Cleave = spell("Cleave", { 20569, 11609, 11608, 7369, 845 }, "Cleave"),
    DeathWish = spell("DeathWish", 12292, "DeathWish"),
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
    SweepingStrikes = spell("SweepingStrikes", 12328, "SweepingStrikes"),
    ThunderClap = spell("ThunderClap", { 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
    Whirlwind = spell("Whirlwind", 1680, "Whirlwind"),
}

local BATTLE_SHOUT_BUFF = { 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
local BERSERKER_RAGE_BUFF = { 18499 }
local DEMO_SHOUT_DEBUFF = { 11556, 11555, 11554, 6190, 1160 }
local HAMSTRING_DEBUFF = { 7373, 7372, 1715 }
local MORTAL_STRIKE_DEBUFF = { 21553, 21552, 21551, 12294 }
local REND_DEBUFF = { 11574, 11573, 6548, 6547, 772 }
local SUNDER_DEBUFF = { 11597, 11596, 8380, 7405, 7386 }
local SWEEPING_STRIKES_BUFF = { 12328 }
local THUNDER_CLAP_DEBUFF = { 11581, 11580, 8205, 8204, 8198, 6343 }

local HEALTHSTONE_IDS = (TBC and TBC.ITEMS and TBC.ITEMS.healthstones) or { 22116, 22105, 22104, 22103, 22102, 22101 }

local HEALTHSTONE_HP_THRESHOLD = 35
local EXECUTE_DEFAULT_RAGE = 25
local HEROIC_STRIKE_RAGE = 60
local CLEAVE_RAGE = 55
local MORTAL_STRIKE_RAGE = 30
local OVERPOWER_RAGE = 5
local SLAM_RAGE = 15
local SLAM_CAST_TIME = 0.5
local SLAM_SAFETY = 0.2
local SWEEPING_STRIKES_COUNT = 2
local TACTICAL_MASTERY_CAP = 25
local HAMSTRING_SPAM_RAGE = 55

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

local setting = NS.setting

local function player_unit(context)
    return context.me or (NS.GetPlayer and NS.GetPlayer()) or PLAYER_UNIT
end

local function player_target(context, action_row)
    if action_row and action_row.target == "self" then return player_unit(context) end
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

local function debuff_remains(unit, ids)
    if NS.debuff_remains then return NS.debuff_remains(unit, ids) or 0 end
    return 0
end

local function debuff_stacks(unit, ids)
    if NS.debuff_stacks then return NS.debuff_stacks(unit, ids) or 0 end
    if NS.get_debuff_stacks then return NS.get_debuff_stacks(unit, ids) or 0 end
    return 0
end

local function buff_up(unit, ids)
    if NS.buff_up then return NS.buff_up(unit, ids) or false end
    return false
end

local function cooldown(spell_value, fallback)
    if NS.cooldown_remains then return NS.cooldown_remains(spell_value, fallback) or 0 end
    return 0
end

local function ready(spell_value, target, opts)
    if NS.spell_ready then return NS.spell_ready(spell_value, target, opts) or false end
    return true
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
    if state.stance == nil then return true end
    return preserved_rage_after_swap(state.rage or 0) >= (cost or 0)
end

local function action(context, row)
    if not context or not row then return false end
    if not row.spell then return true end
    local target = (row.target == "self" or row.requires_target == false) and (context.me or NS.GetPlayer()) or context.target
    if not target then return false end
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

local function build_state(context)
    local target = context.target
    local me = player_unit(context)

    arms_state.rage = context.rage or 0
    arms_state.hp = context.hp or 100
    arms_state.target_hp = context.target_hp or 100
    arms_state.stance = context.stance or STANCE.BATTLE
    arms_state.enemy_count = context.enemy_count or context.enemies_count or 1
    arms_state.is_pvp = context.is_pvp or (context.settings and context.settings.pvp_mode) or false
    arms_state.in_combat = context.in_combat or false
    arms_state.is_moving = context.is_moving or false
    arms_state.target_distance = context.target_distance or context.distance or 0
    arms_state.target_is_player = target and bool_call(target, "is_player") or false
    arms_state.target_is_pet = target and bool_call(target, "is_pet") or false
    arms_state.target_is_casting = context.target_is_casting or bool_call(target, "is_casting") or false
    arms_state.target_is_melee = target_is_melee(target)
    arms_state.target_in_combat = target and bool_call(target, "is_in_combat") or false

    arms_state.has_battle_shout = buff_up(me, BATTLE_SHOUT_BUFF)
    arms_state.has_berserker_rage = buff_up(me, BERSERKER_RAGE_BUFF)
    arms_state.has_sweeping_strikes = buff_up(me, SWEEPING_STRIKES_BUFF)

    arms_state.ms_remains = debuff_remains(target, MORTAL_STRIKE_DEBUFF)
    arms_state.rend_remains = debuff_remains(target, REND_DEBUFF)
    arms_state.hamstring_remains = debuff_remains(target, HAMSTRING_DEBUFF)
    arms_state.demo_remains = debuff_remains(target, DEMO_SHOUT_DEBUFF)
    arms_state.tclap_remains = debuff_remains(target, THUNDER_CLAP_DEBUFF)
    arms_state.sunder_stacks = debuff_stacks(target, SUNDER_DEBUFF)

    arms_state.ms_cd = cooldown(ACTION.MortalStrike, 6)
    arms_state.ww_cd = cooldown(ACTION.Whirlwind, 10)
    arms_state.overpower_ready = ready(ACTION.Overpower, target)
    arms_state.execute_ready = ready(ACTION.Execute, target)
    arms_state.ms_ready = ready(ACTION.MortalStrike, target, { expected_cooldown = 6 })
    arms_state.ww_ready = ready(ACTION.Whirlwind, target, { expected_cooldown = 10 })
    arms_state.slam_ready = ready(ACTION.Slam, target)
    arms_state.sweeping_ready = ready(ACTION.SweepingStrikes, me, { skip_range = true })
    arms_state.heroic_ready = ready(ACTION.HeroicStrike, target)
    arms_state.cleave_ready = ready(ACTION.Cleave, target)
    arms_state.pummel_ready = ready(ACTION.Pummel, target)
    arms_state.intercept_ready = ready(ACTION.Intercept, target)
    arms_state.charge_ready = ready(ACTION.Charge, target)
    arms_state.hamstring_ready = ready(ACTION.Hamstring, target)
    arms_state.piercing_ready = ready(ACTION.PiercingHowl, me, { skip_range = true })
    arms_state.disarm_ready = ready(ACTION.Disarm, target)
    arms_state.intimidating_ready = ready(ACTION.IntimidatingShout, me, { skip_range = true })
    arms_state.thunder_ready = ready(ACTION.ThunderClap, me, { skip_range = true, expected_cooldown = 4 })
    arms_state.demo_ready = ready(ACTION.DemoralizingShout, me, { skip_range = true })
    arms_state.bloodrage_ready = ready(ACTION.Bloodrage, me, { skip_range = true })
    arms_state.death_wish_ready = ready(ACTION.DeathWish, me, { skip_range = true })
    arms_state.recklessness_ready = ready(ACTION.Recklessness, me, { skip_range = true })
    arms_state.retaliation_ready = ready(ACTION.Retaliation, me, { skip_range = true })
    arms_state.shield_wall_ready = ready(ACTION.ShieldWall, me, { skip_range = true })

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

    if SwingTimer and SwingTimer.update then SwingTimer.update() end
    arms_state.mh_until = SwingTimer and SwingTimer.get_mh_time_until and SwingTimer.get_mh_time_until() or 999
    arms_state.mh_progress = SwingTimer and SwingTimer.get_mh_progress and SwingTimer.get_mh_progress() or 0

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
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.BattleShout, 3.0) then return false end
    if state.has_battle_shout then return false end
    return action(context, build_action("BattleShout", ACTION.BattleShout, { target = "self", kind = "buff", buff = BATTLE_SHOUT_BUFF, requires_target = false, min_rage = 10 }))
end

local function execute_matches(context, state)
    if not execute_phase(context, state) then return false end
    local min_rage = setting(context, "execute_phase_rage", EXECUTE_DEFAULT_RAGE)
    if context.rage ~= nil and (state.rage or 0) < min_rage then return false end
    return action(context, build_action("Execute", ACTION.Execute, { min_rage = 15 }))
end

local function mortal_strike_matches(context)
    return action(context, build_action("MortalStrike", ACTION.MortalStrike, { required_stance = STANCE.BATTLE, min_rage = MORTAL_STRIKE_RAGE, cooldown = 6 }))
end

local function overpower_matches(context, state)
    if not state.overpower_ready then return false end
    return action(context, build_action("Overpower", ACTION.Overpower, { required_stance = STANCE.BATTLE, min_rage = OVERPOWER_RAGE }))
end

local function rend_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Rend, 2.0) then return false end
    if execute_phase(context, state) then return false end
    if (state.rend_remains or 0) > 3 then return false end
    if (state.target_hp or 100) < 25 then return false end
    return action(context, build_action("Rend", ACTION.Rend, { required_stance = STANCE.BATTLE, min_rage = 10, debuff = REND_DEBUFF, refresh = 3 }))
end

local function slam_matches(context, state)
    if setting(context, "slam_weave_enabled", true) == false then return false end
    if not SwingTimer then return false end
    if state.is_moving then return false end
    if (state.rage or 0) < SLAM_RAGE then return false end
    if (state.ms_cd or 99) <= 1.0 or state.overpower_ready then return false end
    if (state.mh_until or 999) <= SLAM_CAST_TIME + SLAM_SAFETY then return false end
    if (state.mh_until or 999) > 1.5 then return false end
    return action(context, build_action("Slam", ACTION.Slam, { required_stance = STANCE.BATTLE, min_rage = SLAM_RAGE, not_moving = true }))
end

local function sweeping_strikes_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.SweepingStrikes, 3.0) then return false end
    local min_count = setting(context, "sweeping_strikes_count", SWEEPING_STRIKES_COUNT)
    if (state.enemy_count or 0) < min_count then return false end
    if state.has_sweeping_strikes then return false end
    return action(context, build_action("SweepingStrikes", ACTION.SweepingStrikes, { target = "self", required_stance = STANCE.BATTLE, min_rage = 30, requires_target = false, enemy_count = min_count, cooldown = 30 }))
end

local function sunder_armor_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.SunderArmor, 2.0) then return false end
    if not setting(context, "use_sunder_armor", false) then return false end
    if (state.sunder_stacks or 0) >= 5 then return false end
    if (state.rage or 0) < 15 then return false end
    if state.execute_phase then return false end
    return action(context, build_action("SunderArmor", ACTION.SunderArmor, { required_stance = STANCE.DEFENSIVE, min_rage = 15, debuff = SUNDER_DEBUFF, refresh = 28 }))
end

local function whirlwind_matches(context, state)
    if not state.ww_ready then return false end
    if (state.enemy_count or 0) < 2 and (state.rage or 0) < 45 then return false end
    return action(context, build_action("Whirlwind", ACTION.Whirlwind, { required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10 }))
end

local function heroic_strike_matches(context)
    return action(context, build_action("HeroicStrike", ACTION.HeroicStrike, { min_rage = HEROIC_STRIKE_RAGE }))
end

local function cleave_matches(context, state)
    if (state.enemy_count or 0) < 2 then return false end
    if (state.rage or 0) < CLEAVE_RAGE then return false end
    return action(context, build_action("Cleave", ACTION.Cleave, { min_rage = CLEAVE_RAGE, enemy_count = 2, is_aoe = true }))
end

local function hamstring_matches(context, state)
    if state.is_pvp then
        if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Hamstring, 2.0) then return false end
        if (state.hamstring_remains or 0) > 3 then return false end
        return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }))
    end
    local tactician_enabled = setting(context, "hamstring_tactician_weave", true)
    local weave_rage = setting(context, "hamstring_weave_rage", HAMSTRING_SPAM_RAGE)
    if tactician_enabled and not state.execute_phase and (state.rage or 0) >= weave_rage and (state.ms_cd or 99) > 1.5 then
        return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10 }))
    end
    if setting(context, "hamstring_fleeing_mobs", true) and (state.hamstring_remains or 0) <= 3 then
        if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Hamstring, 2.0) then return false end
        return action(context, build_action("Hamstring", ACTION.Hamstring, { min_rage = 10, debuff = HAMSTRING_DEBUFF, refresh = 3 }))
    end
    return false
end

local function piercing_howl_matches(context, state)
    if not state.is_pvp and (state.enemy_count or 0) < 3 then return false end
    if (state.rage or 0) < 10 then return false end
    return action(context, build_action("PiercingHowl", ACTION.PiercingHowl, { target = "self", min_rage = 10, requires_target = false, enemy_count = 2, is_aoe = true }))
end

local function demo_shout_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.DemoralizingShout, 2.0) then return false end
    if (state.demo_remains or 0) > 5 then return false end
    if not state.is_pvp and (state.enemy_count or 0) < 2 and (state.hp or 100) > 70 then return false end
    return action(context, build_action("DemoralizingShout", ACTION.DemoralizingShout, { target = "self", min_rage = 10, requires_target = false, debuff = DEMO_SHOUT_DEBUFF, refresh = 5 }))
end

local function thunder_clap_matches(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.ThunderClap, 2.0) then return false end
    if (state.tclap_remains or 0) > 5 then return false end
    if not state.is_pvp and (state.hp or 100) > 65 and (state.enemy_count or 0) < 2 then return false end
    return action(context, build_action("ThunderClap", ACTION.ThunderClap, { target = "self", required_stance = STANCE.BATTLE, min_rage = 20, requires_target = false, debuff = THUNDER_CLAP_DEBUFF, refresh = 5, cooldown = 4 }))
end

local function pummel_matches(context, state)
    if not state.target_is_casting then return false end
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
    if not ready(ACTION.Intercept, context.target) then return false end
    return action(context, build_action("Intercept", ACTION.Intercept, { required_stance = STANCE.BERSERKER, min_rage = 10, cooldown = 30 }))
end

local function charge_matches(context, state)
    local auto_charge = setting(context, "auto_charge", true)
    if not auto_charge then return false end
    if state.in_combat then return false end
    if (state.target_distance or 0) < 8 or (state.target_distance or 0) > 25 then return false end
    local charge_only_ooc = setting(context, "charge_only_ooc", true)
    if charge_only_ooc and context.target_in_combat then return false end
    if not ready(ACTION.Charge, context.target) then return false end
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
    if not cooldowns_allowed(context, state) then return false end
    if (state.hp or 100) < 45 then return false end
    if (state.target_hp or 100) < 20 and (state.rage or 0) < 25 then return false end
    return action(context, build_action("DeathWish", ACTION.DeathWish, { target = "self", requires_target = false, cooldown = 180 }))
end

local function recklessness_matches(context, state)
    if not cooldowns_allowed(context, state) then return false end
    if (state.hp or 100) < 50 then return false end
    if not execute_phase(context, state) and (state.target_hp or 100) > 35 then return false end
    return action(context, build_action("Recklessness", ACTION.Recklessness, { target = "self", required_stance = STANCE.BERSERKER, requires_target = false, cooldown = 1800 }))
end

local function retaliation_matches(context, state)
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
    if state.in_combat then return false end
    if (state.hp or 100) > HEALTHSTONE_HP_THRESHOLD then return false end
    local hs_hp = setting(context, "healthstone_hp", HEALTHSTONE_HP_THRESHOLD)
    if (state.hp or 100) > hs_hp then return false end
    return true
end

local STRATEGY_SPECS = {
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
    { "Overpower", overpower_matches, build_action("Overpower", ACTION.Overpower, { required_stance = STANCE.BATTLE, min_rage = OVERPOWER_RAGE }) },
    { "MortalStrike", mortal_strike_matches, build_action("MortalStrike", ACTION.MortalStrike, { required_stance = STANCE.BATTLE, min_rage = MORTAL_STRIKE_RAGE, cooldown = 6 }) },
    { "Execute", execute_matches, build_action("Execute", ACTION.Execute, { min_rage = 15 }) },
    { "SweepingStrikes", sweeping_strikes_matches, build_action("SweepingStrikes", ACTION.SweepingStrikes, { target = "self", required_stance = STANCE.BATTLE, min_rage = 30, requires_target = false }) },
    { "Whirlwind", whirlwind_matches, build_action("Whirlwind", ACTION.Whirlwind, { required_stance = STANCE.BERSERKER, min_rage = 25, cooldown = 10 }) },
    { "Rend", rend_matches, build_action("Rend", ACTION.Rend, { required_stance = STANCE.BATTLE, min_rage = 10, debuff = REND_DEBUFF, refresh = 3 }) },
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
if NS.log then NS.log("Warrior arms_vanilla rotation registered (Classic Vanilla)") end
return strategies
