-- retribution_vanilla.lua — Paladin Retribution for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  melee DPS (Seal of Command, Judgement, Crusader Strike).
-- WHEN:  combat, when NS.is_vanilla() is true.
-- WHY:   expansion-aware loader selects _vanilla suffix for Classic Era.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.


local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")

local SPELLS = NS.PaladinSpells or {}
local PLAYER = NS.PLAYER_UNIT
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { healthstones = {}, potions = {} } } end
local TBC_ITEMS = (TBC and TBC.ITEMS) or {}
local TBC_POTIONS = TBC_ITEMS.potions or {}

local function action(ids, label)
    if NS.spell_action then return NS.spell_action(ids, label) end
    return type(ids) == "table" and ids[1] or ids
end

-- Spell IDs are Classic Vanilla 2.4.3 ranks only, newest-to-oldest where ranks exist.
local SealCrusader = SPELLS.SealCrusader or action({ 20308, 20307, 20306, 20305, 21082, 20162 }, "SealCrusader")
local SealWisdom = SPELLS.SealOfWisdom or SPELLS.SealWisdom or action({ 20357, 20356, 20166 }, "SealOfWisdom")
local BlessingFreedom = SPELLS.BlessingOfFreedom or action({ 1044 }, "BlessingOfFreedom")
local BlessingProtection = SPELLS.BlessingOfProtection or action({ 10278, 5599, 1022 }, "BlessingOfProtection")
local DivineProtection = SPELLS.DivineProtection or action({ 498 }, "DivineProtection")
local Purify = SPELLS.Purify or action({ 1152 }, "Purify")
local HammerWrath = SPELLS.HammerOfWrath or action({ 24239, 24274, 24275 }, "HammerOfWrath")
local HammerJustice = SPELLS.HammerOfJustice or action({ 10308, 5589, 5588, 853 }, "HammerOfJustice")
local Repentance = SPELLS.Repentance or action({ 20066 }, "Repentance")

local SEAL_COMMAND_BUFF = { 20920, 20919, 20918, 20915, 20375 }
local SEAL_COMMAND_RANK1_BUFF = { 20375 }
-- Seal of Blood (31892) and Seal of the Martyr are TBC-only; never active in Vanilla.
local SEAL_RIGHTEOUSNESS_BUFF = { 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084 }
local SEAL_CRUSADER_BUFF = { 20308, 20307, 20306, 20305, 21082, 20162 }
local SEAL_WISDOM_BUFF = { 20357, 20356, 20166 }
local JUDGEMENT_CRUSADER_DEBUFF = { 20303, 20302, 20301, 20300, 20188 }
local JUDGEMENT_WISDOM_DEBUFF = { 20354, 20353, 20352, 20186 }
local SANCTITY_AURA_GATE_BUFF = { 20218 }  --  removed (TBC-only)
local BLESSING_MIGHT_BUFF = { 19838, 19837, 19836, 19835, 19834, 19832, 19831, 19830, 19740 }
local BLESSING_KINGS_BUFF = { 20217 }
local FORBEARANCE_DEBUFF = { 25771 }
local COMMON_SNARES = { 122, 116, 120, 339, 5116, 3409, 3600, 12494, 13099, 23694, 2974, 8056 }
local COMMON_CLEANSE = { 1330, 1714, 2818, 3409, 6358, 6788, 8122, 11831, 12579, 16856, 17928, 10894 }
local DEMON_OR_UNDEAD = { [3] = true, [6] = true }

local MANA_POTIONS = {
    TBC_POTIONS.major_mana or 13444,
    TBC_POTIONS.superior_mana or 13443,
}
local HEALING_ITEMS = {
    TBC_POTIONS.major_healing or 13446,
    TBC_POTIONS.greater_healing or 1710,
    TBC_POTIONS.healing or 929,
    TBC_POTIONS.lesser_healing or 858,
}
for i = 1, #(TBC_ITEMS.healthstones or {}) do
    HEALING_ITEMS[#HEALING_ITEMS + 1] = TBC_ITEMS.healthstones[i]
end

-- ============================================================================
-- Schema (Pattern 14 nil-guard defaults via spec_kit.safe_state)
-- ============================================================================
local RET_VANILLA_SCHEMA = {
    -- Resources: assume full → skip defensives (Pattern 14)
    hp_pct = 100,  mana_pct = 100,  target_hp_pct = 100,  enemy_count = 1,
    swing_remains = 99,  in_melee = true,  can_twist = false,  can_use_blood = false,
    -- Seals
    has_blood = false,  has_command = false,  has_command_rank1 = false,
    has_crusader = false,  has_righteousness = false,  has_wisdom = false,
    has_martyr = false,  has_damage_seal = false,
    -- Blessings / debuffs
    has_might = false,  has_kings = false,  has_forbearance = false,
    target_has_crusader = false,  target_has_wisdom = false,
    -- Target
    target_casting = false,  target_casting_interruptible = false,
    target_player = false,  target_fleeing = false,
}

local TWIST_WINDOW = 0.45
local MELEE_RANGE = 8


local ret_state = {
    hp_pct = 100,
    mana_pct = 100,
    target_hp_pct = 100,
    enemy_count = 1,
    swing_remains = 99,
    preferred_damage_seal = nil,
    utility_target = nil,
    secondary_target = nil,
    mana_item = nil,
    healing_item = nil,
    has_blood = false,
    has_command = false,
    has_command_rank1 = false,
    has_crusader = false,
    has_righteousness = false,
    has_wisdom = false,
    has_martyr = false,
    has_damage_seal = false,
    has_might = false,
    has_kings = false,
    has_forbearance = false,
    target_has_crusader = false,
    target_has_wisdom = false,
    target_casting = false,
    target_casting_interruptible = false,
    target_player = false,
    target_fleeing = false,
    can_twist = false,
    can_use_blood = false,
}

local get_setting = spec_kit.setting

-- Out-of-combat seal refresh gate. When seal_refresh_ooc is false,
-- seal re-application strategies are skipped while not in combat.
-- In-combat seal casts are always allowed. Default true preserves
-- legacy "always keep seal up" behaviour.
local function seal_refresh_allowed(context)
    if context and context.in_combat then return true end
    local val = get_setting(context, "seal_refresh_ooc", true)
    return val ~= false
end

local function has_player_buff(ids)
    return NS.has_player_buff and NS.has_player_buff(ids) or false
end

local function has_player_debuff(ids)
    return NS.has_player_debuff and NS.has_player_debuff(ids) or false
end

local function unit_has_debuff(unit, ids)
    if not unit then return false end
    if NS.has_target_debuff then return NS.has_target_debuff(unit, ids) end
    return false
end

local function unit_has_buff(unit, ids)
    return NS.buff_up(unit, ids)
end

local function health_pct(unit, fallback)
    if not unit or not unit.get_health_percentage then return fallback or 100 end
    return unit:get_health_percentage() or fallback or 100
end

local function is_casting(unit)
    if not unit then return false end
    if unit.is_casting and unit:is_casting() then return true end
    return unit.is_channeling and unit:is_channeling() or false
end

local function is_player(unit)
    if not unit or not unit.is_player then return false end
    return unit:is_player() == true
end

local function creature_type(unit)
    if not unit or not unit.get_creature_type then return nil end
    local ok, value = pcall(unit.get_creature_type, unit)
    return ok and value or nil
end

local function distance_to(context, unit)
    if not unit then return 0 end
    if context.me and context.me.get_distance then return context.me:get_distance(unit) or 0 end
    if unit.get_distance then return unit:get_distance(context.me or PLAYER) or 0 end
    return 0
end

local function first_ready_item(ids)
    if not NS.is_item_ready then return nil end
    for i = 1, #ids do
        if NS.is_item_ready(ids[i]) then return ids[i] end
    end
    return nil
end

local function candidate_members(context)
    return context.party_members or context.group_members or context.friends or context.allies
end

local function find_ally(context, predicate)
    local members = candidate_members(context)
    if type(members) == "table" and #members > 0 then
        for i = 1, #members do
            local member = members[i]
            if member and predicate(member) then return member end
        end
    end
    local me = context.me or PLAYER
    if me and predicate(me) then return me end
    return nil
end

local function find_secondary_enemy(context)
    local enemies = context.enemies or context.enemy_list or context.targets
    if not enemies then return nil end
    for i = 1, #enemies do
        local enemy = enemies[i]
        if enemy and enemy ~= context.target and health_pct(enemy, 100) > 0 and distance_to(context, enemy) <= MELEE_RANGE then
            return enemy
        end
    end
    return nil
end

local function should_use_blood(context)
    local preference = get_setting(context, "seal_preference", get_setting(context, "retri_seal_preference", "auto"))
    if preference == "blood" then return false end
    if preference == "command" then return false end
    return false  -- Seal of Blood is TBC-only
end

local function damage_seal_spell(state)
    if state.preferred_damage_seal == "martyr" then return nil end
    if state.preferred_damage_seal == "blood" then return nil end
    return SPELLS.SealCommand
end

local function build_state(context)
    ret_state.hp_pct = context.hp or health_pct(context.me, 100)
    ret_state.mana_pct = context.mana_pct or context.mana or 100
    ret_state.enemy_count = context.enemy_count or context.enemies_nearby or 1
    ret_state.target_hp_pct = health_pct(context.target, context.target_hp or 100)
    ret_state.swing_remains = (NS.get_time_until_swing and NS.get_time_until_swing()) or context.time_to_swing or 99
    ret_state.can_use_blood = should_use_blood(context)
    ret_state.preferred_damage_seal = ret_state.can_use_blood and "blood" or "command"
    -- [ARTISTRY] Improved: Dynamic Twist Window from settings (ms to seconds)
    local twist_ms = get_setting(context, "retri_twist_window", 450)
    ret_state.twist_window = twist_ms / 1000
    ret_state.has_blood = false  -- TBC-only
    ret_state.has_command = has_player_buff(SEAL_COMMAND_BUFF)
    ret_state.has_command_rank1 = has_player_buff(SEAL_COMMAND_RANK1_BUFF)
    ret_state.has_crusader = has_player_buff(SEAL_CRUSADER_BUFF)
    ret_state.has_righteousness = has_player_buff(SEAL_RIGHTEOUSNESS_BUFF)
    ret_state.has_wisdom = has_player_buff(SEAL_WISDOM_BUFF)
    ret_state.has_martyr = false  -- TBC-only
    ret_state.has_damage_seal = ret_state.has_blood or ret_state.has_command or ret_state.has_righteousness or ret_state.has_martyr
    ret_state.has_might = has_player_buff(BLESSING_MIGHT_BUFF)
    ret_state.has_kings = has_player_buff(BLESSING_KINGS_BUFF)
    ret_state.has_forbearance = has_player_debuff(FORBEARANCE_DEBUFF)
    ret_state.target_has_crusader = unit_has_debuff(context.target, JUDGEMENT_CRUSADER_DEBUFF)
    ret_state.target_has_wisdom = unit_has_debuff(context.target, JUDGEMENT_WISDOM_DEBUFF)
    ret_state.target_casting = is_casting(context.target)
    ret_state.target_casting_interruptible = ret_state.target_casting and (NS.is_interruptible and NS.is_interruptible(context.target) or false)
    ret_state.target_player = is_player(context.target)
    ret_state.target_fleeing = context.target_fleeing == true or context.target_is_fleeing == true
    ret_state.can_twist = NS.get_any_setting(context, "seal_twisting_enabled", "retri_seal_twisting", false) and ret_state.mana_pct >= get_setting(context, "retri_twist_mana_floor", 20)
    ret_state.utility_target = nil
    ret_state.secondary_target = find_secondary_enemy(context)
    ret_state.mana_item = first_ready_item(MANA_POTIONS)
    ret_state.healing_item = first_ready_item(HEALING_ITEMS)
    return spec_kit.safe_state(ret_state, RET_VANILLA_SCHEMA)
end

local function cast(spell, target, reason, opts)
    return spell ~= nil and NS.try_cast and NS.try_cast(spell, target, reason, opts) or false
end

local function use_item(id)
    if not id then return false end
    if NS.use_item_by_id then return NS.use_item_by_id(id) ~= false end
    return false
end

local function add_strategy(list, name, priority, matches, execute, cooldown)
    list[#list + 1] = { name = name, priority = priority, matches = matches, execute = execute, cooldown = cooldown }
end

local strategies = {}

add_strategy(strategies, "Ret_DivineShield_Emergency", 1000, function(context, state)
    local threshold = get_setting(context, "divine_shield_hp", get_setting(context, "retri_ds_hp", 15))
    return (state.hp_pct or 100) <= threshold and not state.has_forbearance and NS.spell_ready(SPELLS.DivineShield, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.DivineShield, PLAYER, "[RET] Divine Shield emergency", { skip_range = true }) end)

add_strategy(strategies, "Ret_LayOnHands_LastResort", 990, function(context, state)
    local threshold = get_setting(context, "lay_on_hands_hp", 8)
    return (state.hp_pct or 100) <= threshold and NS.spell_ready(SPELLS.LayOnHands, PLAYER, { skip_range = true, expected_cooldown = 3600 }) or false
end, function() return cast(SPELLS.LayOnHands, PLAYER, "[RET] Lay on Hands last resort", { skip_range = true, expected_cooldown = 3600 }) end)

add_strategy(strategies, "Ret_SanctityAura", 550, function(context, state)
    if not get_setting(context, "sanctity_aura_enabled", get_setting(context, "retri_aura_enabled", true)) then return false end
    if has_player_buff(SANCTITY_AURA_GATE_BUFF) then return false end
    return NS.spell_ready(SPELLS.SanctityAura, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SanctityAura, PLAYER, "[RET] Sanctity Aura", { skip_range = true }) end)

add_strategy(strategies, "Ret_DivineProtection_Physical", 980, function(context, state)
    local threshold = get_setting(context, "divine_protection_hp", 22)
    return (state.hp_pct or 100) <= threshold and not state.has_forbearance and NS.spell_ready(DivineProtection, PLAYER, { skip_range = true }) or false
end, function() return cast(DivineProtection, PLAYER, "[RET] Divine Protection", { skip_range = true }) end)

add_strategy(strategies, "Ret_HealthstoneOrPotion", 970, function(context, state)
    local threshold = get_setting(context, "healing_item_hp", 35)
    return (state.hp_pct or 100) <= threshold and state.healing_item ~= nil
end, function(_, state) return use_item(state.healing_item) end)

add_strategy(strategies, "Ret_BlessingProtection_FocusedAlly", 930, function(context, state)
    state.utility_target = find_ally(context, function(unit) return unit ~= PLAYER and health_pct(unit, 100) <= 28 end)
    return state.utility_target ~= nil and NS.spell_ready(BlessingProtection, state.utility_target, {}) or false
end, function(_, state) return cast(BlessingProtection, state.utility_target, "[RET] Blessing of Protection ally") end)

add_strategy(strategies, "Ret_BlessingFreedom_Self", 920, function(context)
    if not get_setting(context, "blessing_of_freedom_self", true) then return false end
    local snared = context.self_rooted_snared or has_player_debuff(COMMON_SNARES)
    return snared and NS.spell_ready(BlessingFreedom, PLAYER, { skip_range = true }) or false
end, function() return cast(BlessingFreedom, PLAYER, "[RET] Blessing of Freedom self", { skip_range = true }) end)

add_strategy(strategies, "Ret_BlessingFreedom_Ally", 910, function(context, state)
    if not get_setting(context, "blessing_of_freedom_allies", true) then return false end
    state.utility_target = find_ally(context, function(unit) return unit_has_debuff(unit, COMMON_SNARES) end)
    return state.utility_target ~= nil and NS.spell_ready(BlessingFreedom, state.utility_target, {}) or false
end, function(_, state) return cast(BlessingFreedom, state.utility_target, "[RET] Blessing of Freedom ally") end)

add_strategy(strategies, "Ret_Cleanse_Self", 900, function(context)
    if not get_setting(context, "use_cleanse", get_setting(context, "retri_auto_cleanse", true)) then return false end
    return has_player_debuff(COMMON_CLEANSE) and NS.spell_ready(SPELLS.Cleanse, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.Cleanse, PLAYER, "[RET] Cleanse self", { skip_range = true }) end)

add_strategy(strategies, "Ret_Purify_SelfFallback", 890, function(context)
    if not get_setting(context, "use_purify", true) then return false end
    return has_player_debuff(COMMON_CLEANSE) and NS.spell_ready(Purify, PLAYER, { skip_range = true }) or false
end, function() return cast(Purify, PLAYER, "[RET] Purify self", { skip_range = true }) end)

add_strategy(strategies, "Ret_Cleanse_Ally", 880, function(context, state)
    if not get_setting(context, "cleanse_allies", true) then return false end
    state.utility_target = find_ally(context, function(unit) return unit_has_debuff(unit, COMMON_CLEANSE) end)
    return state.utility_target ~= nil and NS.spell_ready(SPELLS.Cleanse, state.utility_target, {}) or false
end, function(_, state) return cast(SPELLS.Cleanse, state.utility_target, "[RET] Cleanse ally") end)

add_strategy(strategies, "Ret_PvP_Repentance_Opener", 850, function(context, state)
    if not get_setting(context, "repentance_pvp_usage", true) then return false end
    return context.is_pvp and state.target_player and NS.spell_ready(Repentance, context.target, {}) or false
end, function(context) return cast(Repentance, context.target, "[RET PvP] Repentance opener") end)

add_strategy(strategies, "Ret_PvP_Repentance_EmergencyInterrupt", 840, function(context, state)
    if not get_setting(context, "repentance_pvp_usage", true) then return false end
    return context.is_pvp and (state.target_casting_interruptible or false) and NS.spell_ready(Repentance, context.target, {}) or false
end, function(context) return cast(Repentance, context.target, "[RET PvP] Repentance interrupt") end)

add_strategy(strategies, "Ret_HammerJustice_Interrupt", 830, function(context, state)
    return (state.target_casting_interruptible or false) and NS.spell_ready(HammerJustice, context.target, { expected_cooldown = 60 }) or false
end, function(context) return cast(HammerJustice, context.target, "[RET] Hammer of Justice interrupt", { expected_cooldown = 60 }) end)

add_strategy(strategies, "Ret_PvP_HammerJustice_Burst", 820, function(context, state)
    return context.is_pvp and state.target_player and NS.spell_ready(HammerJustice, context.target, { expected_cooldown = 60 }) or false
end, function(context) return cast(HammerJustice, context.target, "[RET PvP] Hammer of Justice burst", { expected_cooldown = 60 }) end)

add_strategy(strategies, "Ret_HammerWrath_Execute", 800, function(context, state)
    return (state.target_hp_pct or 100) < 20 and NS.spell_ready(HammerWrath, context.target, { expected_cooldown = 6 }) or false
end, function(context) return cast(HammerWrath, context.target, "[RET] Hammer of Wrath execute", { expected_cooldown = 6 }) end)

add_strategy(strategies, "Ret_HammerWrath_FleeingPvP", 790, function(context, state)
    return context.is_pvp and state.target_fleeing and (state.target_hp_pct or 100) < 25 and NS.spell_ready(HammerWrath, context.target, { expected_cooldown = 6 }) or false
end, function(context) return cast(HammerWrath, context.target, "[RET PvP] Hammer of Wrath fleeing target", { expected_cooldown = 6 }) end)

strategies[#strategies + 1] = {
    name = "SealTwistPrepCommand",
    priority = 750,
    matches = function(context, state)
        -- [ARTISTRY] Improved: Sync prep window with dynamic twist_window
        local twist_window = state.twist_window or TWIST_WINDOW
        local prep_start = twist_window + 0.75 -- Give enough time for GCD + Reaction
        local swing_remains = state.swing_remains or 99
        return state.can_twist and not state.has_command_rank1 and swing_remains <= prep_start and swing_remains > twist_window and NS.spell_ready(SPELLS.SealCommandRank1 or SPELLS.SealCommand, PLAYER, { skip_range = true }) or false
    end,
    execute = function()
        return cast(SPELLS.SealCommandRank1 or SPELLS.SealCommand, PLAYER, "[RET] Seal twist prep: Rank 1 Command", { skip_range = true })
    end,
}

add_strategy(strategies, "Ret_JudgeCrusader", 720, function(context, state)
    return not state.target_has_crusader and state.has_crusader and NS.spell_ready(SPELLS.Judgement, context.target, { expected_cooldown = 10 }) or false
end, function(context) return cast(SPELLS.Judgement, context.target, "[RET] Judge Seal of the Crusader", { expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_ApplyCrusaderSeal", 710, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return not state.target_has_crusader and not state.has_crusader and not state.has_damage_seal and NS.spell_ready(SealCrusader, PLAYER, { skip_range = true }) or false
end, function() return cast(SealCrusader, PLAYER, "[RET] Seal of the Crusader", { skip_range = true }) end)

add_strategy(strategies, "Ret_JudgeDamageSeal", 690, function(context, state)
    return state.has_damage_seal and (state.mana_pct or 100) >= 12 and NS.spell_ready(SPELLS.Judgement, context.target, { expected_cooldown = 10 }) or false
end, function(context) return cast(SPELLS.Judgement, context.target, "[RET] Judgement damage seal", { expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_SealCommand_Primary", 660, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return state.preferred_damage_seal == "command" and not state.has_command and NS.spell_ready(SPELLS.SealCommand, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealCommand, PLAYER, "[RET] Seal of Command primary", { skip_range = true }) end)

add_strategy(strategies, "Ret_JudgementWisdom_LowMana", 640, function(context, state)
    local threshold = get_setting(context, "retri_judge_wisdom_mana", 45)
    return (state.mana_pct or 100) <= threshold and state.has_wisdom and not state.target_has_wisdom and NS.spell_ready(SPELLS.Judgement, context.target, { expected_cooldown = 10 }) or false
end, function(context) return cast(SPELLS.Judgement, context.target, "[RET] Judge Wisdom for mana", { expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_SealWisdom_Emergency", 630, function(_, state)
    return (state.mana_pct or 100) <= 18 and not state.has_wisdom and NS.spell_ready(SealWisdom, PLAYER, { skip_range = true }) or false
end, function() return cast(SealWisdom, PLAYER, "[RET] Seal of Wisdom emergency", { skip_range = true }) end)

add_strategy(strategies, "Ret_ManaPotion", 620, function(context, state)
    local threshold = get_setting(context, "mana_potion_pct", get_setting(context, "retri_mana_potion", 20))
    return (state.mana_pct or 100) <= threshold and state.mana_item ~= nil
end, function(_, state) return use_item(state.mana_item) end)

strategies[#strategies + 1] = {
    name = "Consecration",
    priority = 600,
    cooldown = 8,
    matches = function(context, state)
        local min_targets = get_setting(context, "consecration_min_targets", get_setting(context, "retri_consecration_targets", 3))
        return (state.enemy_count or 0) >= min_targets and (state.mana_pct or 100) >= 35 and NS.spell_ready(SPELLS.Consecration, PLAYER, { skip_range = true, expected_cooldown = 8 }) or false
    end,
    execute = function()
        return cast(SPELLS.Consecration, PLAYER, "[RET] Consecration AoE", { skip_range = true, expected_cooldown = 8 })
    end,
}

add_strategy(strategies, "Ret_Consecration_ManaDump", 590, function(context, state)
    return get_setting(context, "consecration_single_target", false) and (state.mana_pct or 0) >= 75 and NS.spell_ready(SPELLS.Consecration, PLAYER, { skip_range = true, expected_cooldown = 8 }) or false
end, function() return cast(SPELLS.Consecration, PLAYER, "[RET] Consecration mana dump", { skip_range = true, expected_cooldown = 8 }) end, 8)

add_strategy(strategies, "Exorcism", 580, function(context)
    -- [ARTISTRY] Improved: Classic Vanilla Exorcism only works on Undead and Demons.
    if not context.target then return false end
    local type = creature_type(context.target)
    return (DEMON_OR_UNDEAD[type] and NS.spell_ready(SPELLS.Exorcism, context.target, { expected_cooldown = 15 }) or false) or false
end, function(context) return NS.try_cast(SPELLS.Exorcism, context.target, "[RET] Exorcism", { expected_cooldown = 15 }) end, 15)

add_strategy(strategies, "Ret_HolyWrath_AoE", 575, function(context, state)
    -- [ARTISTRY] Improved: Classic Vanilla Holy Wrath works on Undead/Demon groups.
    if (state.enemy_count or 0) < 2 or (state.mana_pct or 100) < 40 then return false end
    if not (NS.spell_ready(SPELLS.HolyWrath, PLAYER, { skip_range = true }) or false) then return false end
    -- Check if target is undead/demon
    local type = creature_type(context.target)
    return DEMON_OR_UNDEAD[type] or false
end, function() return cast(SPELLS.HolyWrath, PLAYER, "[RET] Holy Wrath AoE", { skip_range = true, expected_cooldown = 60 }) end, 60)

add_strategy(strategies, "Ret_JudgeSecondary_CommandCleave", 570, function(context, state)
    return state.secondary_target ~= nil and state.has_command and (state.mana_pct or 0) >= 30 and NS.spell_ready(SPELLS.Judgement, state.secondary_target, { expected_cooldown = 10 }) or false
end, function(_, state) return cast(SPELLS.Judgement, state.secondary_target, "[RET] Judgement secondary cleave", { expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_BlessingMight_Self", 540, function(context, state)
    if not get_setting(context, "blessing_of_might_self", get_setting(context, "retri_bless_might", true)) then return false end
    return not state.has_might and NS.spell_ready(SPELLS.BlessingOfMight, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.BlessingOfMight, PLAYER, "[RET] Blessing of Might self", { skip_range = true }) end)

add_strategy(strategies, "Ret_BlessingKings_Self", 530, function(context, state)
    if not get_setting(context, "blessing_of_kings_self", false) then return false end
    return not state.has_kings and NS.spell_ready(SPELLS.BlessingOfKings, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.BlessingOfKings, PLAYER, "[RET] Blessing of Kings self", { skip_range = true }) end)

add_strategy(strategies, "Ret_BlessingMight_MeleeAlly", 520, function(context, state)
    if not get_setting(context, "blessing_of_might_melee", true) then return false end
    state.utility_target = find_ally(context, function(unit) return not unit_has_buff(unit, BLESSING_MIGHT_BUFF) end)
    return state.utility_target ~= nil and NS.spell_ready(SPELLS.BlessingOfMight, state.utility_target, {}) or false
end, function(_, state) return cast(SPELLS.BlessingOfMight, state.utility_target, "[RET] Blessing of Might melee") end)

add_strategy(strategies, "Ret_BlessingKings_Party", 510, function(context, state)
    if not get_setting(context, "blessing_of_kings_party", false) then return false end
    state.utility_target = find_ally(context, function(unit) return not unit_has_buff(unit, BLESSING_KINGS_BUFF) end)
    return state.utility_target ~= nil and NS.spell_ready(SPELLS.BlessingOfKings, state.utility_target, {}) or false
end, function(_, state) return cast(SPELLS.BlessingOfKings, state.utility_target, "[RET] Blessing of Kings party") end)

add_strategy(strategies, "Ret_SealCommand_AoE", 490, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    local min_targets = get_setting(context, "command_cleave_min_targets", 2)
    return (state.enemy_count or 0) >= min_targets and not state.has_command and NS.spell_ready(SPELLS.SealCommand, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealCommand, PLAYER, "[RET] Seal of Command cleave", { skip_range = true }) end)

add_strategy(strategies, "Ret_SealRighteousness_Filler", 470, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return not state.has_damage_seal and not state.has_wisdom and NS.spell_ready(SPELLS.SealRighteousness, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealRighteousness, PLAYER, "[RET] Seal of Righteousness filler", { skip_range = true }) end)

add_strategy(strategies, "Ret_Judgement_RighteousnessFiller", 460, function(context, state)
    return state.has_righteousness and (state.mana_pct or 0) >= 25 and NS.spell_ready(SPELLS.Judgement, context.target, { expected_cooldown = 10 }) or false
end, function(context) return cast(SPELLS.Judgement, context.target, "[RET] Judge Righteousness filler", { expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_SealCommand_Fallback", 450, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return not state.has_damage_seal and NS.spell_ready(SPELLS.SealCommand, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealCommand, PLAYER, "[RET] Seal of Command fallback", { skip_range = true }) end)

NS.rotation_registry:register("retribution", strategies, { get_state = build_state })
return { strategies = strategies, build_state = build_state }

