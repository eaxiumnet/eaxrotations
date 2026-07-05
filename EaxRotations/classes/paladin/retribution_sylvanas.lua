-- retribution_sylvanas.lua -- Paladin Retribution DPS for TBC Anniversary (2.5.5).
-- WHAT:  melee DPS spec (Crusader Strike, Judgement, seal twisting SoB/SoM/SoC).
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors wowsims APL: CS > Judgement > Consecration > Exorcism.
-- SAFETY: seal-twist timing native-backed; all state fields nil-guarded.
local NS = _G.EaxRotations
if not NS then return nil end

local SPELLS = NS.PaladinSpells or {}
local PLAYER = NS.PLAYER_UNIT
local _planner_ok, planner = pcall(require, "shared/cooldown_planner_sylvanas")
if not _planner_ok or type(planner) ~= "table" then planner = nil end

local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { healthstones = {}, potions = {} } } end
local TBC_ITEMS = TBC.ITEMS or {}
local TBC_POTIONS = TBC_ITEMS.potions or {}
local BLOODLUST_HEROISM_BUFFS = { 2825, 32182 }

local function action(ids, label)
    if NS.spell_action then return NS.spell_action(ids, label) end
    return type(ids) == "table" and ids[1] or ids
end

-- Spell IDs are TBC 2.4.3 ranks only, newest-to-oldest where ranks exist.
local SealCrusader = SPELLS.SealCrusader or action({ 27158, 20308, 20307, 20306, 20305, 20162, 21082 }, "SealCrusader")
local SealWisdom = SPELLS.SealOfWisdom or SPELLS.SealWisdom or action({ 27166, 20357, 20356, 20166 }, "SealOfWisdom")
local BlessingFreedom = SPELLS.BlessingOfFreedom or action({ 1044 }, "BlessingOfFreedom")
local BlessingProtection = SPELLS.BlessingOfProtection or action({ 10278, 5599, 1022 }, "BlessingOfProtection")
local DivineProtection = SPELLS.DivineProtection or action({ 498 }, "DivineProtection")
local Purify = SPELLS.Purify or action({ 1152 }, "Purify")
local HammerWrath = SPELLS.HammerOfWrath or action({ 27180, 24275, 24274, 24239 }, "HammerOfWrath")
local HammerJustice = SPELLS.HammerOfJustice or action({ 10308, 5589, 5588, 853 }, "HammerOfJustice")
local Repentance = SPELLS.Repentance or action({ 20066 }, "Repentance")

local SEAL_COMMAND_BUFF = { 27170, 20920, 20919, 20918, 20915, 20375 }
local SEAL_COMMAND_RANK1_BUFF = { 20375 }
local SEAL_BLOOD_BUFF = { 31892 }
local SEAL_MARTYR_BUFF = { 348700 }
local SEAL_RIGHTEOUSNESS_BUFF = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084 }
local SEAL_CRUSADER_BUFF = { 27158, 20308, 20307, 20306, 20305, 21082, 20162 }
local SEAL_WISDOM_BUFF = { 27166, 20357, 20356, 20166 }
local JUDGEMENT_CRUSADER_DEBUFF = { 27159, 20303, 20302, 20301, 20300, 20188, 21183 }
local JUDGEMENT_WISDOM_DEBUFF = { 27164, 20355, 20354, 20186 }
local SANCTITY_AURA_GATE_BUFF = { 20218 }
local BLESSING_MIGHT_BUFF = { 27141, 27140, 25916, 25782, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }
local BLESSING_KINGS_BUFF = { 25898, 20217 }
local FORBEARANCE_DEBUFF = { 25771 }
local COMMON_SNARES = { 122, 116, 120, 339, 5116, 3409, 3600, 12494, 13099, 23694, 2974, 8056 }
local COMMON_CLEANSE = { 1330, 1714, 2818, 3409, 6358, 6788, 8122, 11831, 12579, 16856, 17928, 25368, 27087, 27218, 30414, 30443, 30466, 30980, 33786 }
local DEMON_OR_UNDEAD = { [3] = true, [6] = true }

local MANA_POTIONS = {
    TBC_POTIONS.crystal_mana or 33935,
    TBC_POTIONS.auchenai_mana or 32948,
    TBC_POTIONS.super_mana or 22832,
    TBC_POTIONS.super_rejuvenation or 22850,
    TBC_POTIONS.major_mana or 13444,
    TBC_POTIONS.superior_mana or 13443,
}
local HEALING_ITEMS = {
    TBC_POTIONS.crystal_healing or 33934,
    TBC_POTIONS.auchenai_healing or 32947,
    TBC_POTIONS.super_healing or 22829,
    TBC_POTIONS.super_rejuvenation or 22850,
    TBC_POTIONS.major_healing or 13446,
    TBC_POTIONS.greater_healing or 1710,
    TBC_POTIONS.healing or 929,
    TBC_POTIONS.lesser_healing or 858,
}
for i = 1, #(TBC_ITEMS.healthstones or {}) do
    HEALING_ITEMS[#HEALING_ITEMS + 1] = TBC_ITEMS.healthstones[i]
end

local TWIST_WINDOW = 0.45
local TWIST_PREP_WINDOW = 1.20
local MELEE_RANGE = 8

-- ============================================================================
-- CLEU swing diagnostics integration
-- ============================================================================
local _cleu = NS.SwingDiagnostics
if _cleu then
    _cleu.register_seals({
        31892, 348700,
        27170, 20920, 20919, 20918, 20915, 20375,
        27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084,
    })
end

-- ============================================================================
-- Seal twist diagnostics
-- ============================================================================
local _last_twist_result = nil
local _last_twist_log_time = 0
local _last_expected_swing_time = 0

local function log_twist_result(result)
    _last_twist_result = result
    local now = (NS.time_now and NS.time_now()) or 0
    if (now - _last_twist_log_time) < 5.0 then return end
    _last_twist_log_time = now
    local diag_enabled = false
    -- get_any_setting handles both old and new key names safely
    if type(NS.get_any_setting) == "function" then
        diag_enabled = NS.get_any_setting(nil, "retri_twist_diagnostics", nil, false)
    end
    if not diag_enabled then return end
    -- CLEU provides authoritative twist logging; skip client-side guess when active.
    if _cleu and _cleu.is_active() then return end
    local ok, has_core = pcall(function() return core and core.log and core.log.info end)
    if ok and has_core then
        pcall(core.log.info, string.format("[RET] Seal twist: %s", result))
    end
end

local ret_state = {
    hp_pct = 100,
    mana_pct = 100,
    target_hp_pct = 100,
    enemy_count = 1,
    swing_remains = 99,
    seal_preference = "auto",
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
    in_melee = true,
    can_twist = false,
    can_use_blood = false,
}

local get_setting = NS.setting

local function has_player_buff(ids)
    return NS.has_player_buff and NS.has_player_buff(ids) or false
end

local function post_swing_judge_gate(context, state)
    if not get_setting(context, "retri_post_swing_judge", true) then return true end
    local swing_remains = state.swing_remains or 99
    if swing_remains < 0.3 then return false end -- too close to swing, wait
    if swing_remains > 1.5 then return true end   -- just swung, safe to judge
    return true -- in the middle of swing cycle, allow
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
    return context.party_members or context.group_members or (context.enemy_count or 1)
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
    if preference == "blood" then return true end
    if preference == "command" then return false end
    return SPELLS.SealBlood ~= nil
end

local function damage_seal_spell(state)
    if state.preferred_damage_seal == "martyr" then return SPELLS.SealOfTheMartyr end
    if state.preferred_damage_seal == "blood" then return SPELLS.SealBlood end
    return SPELLS.SealCommand
end

local function build_state(context)
    local is_group = context.is_group or false
    ret_state.is_group = is_group
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(27170, 3.0) or false
    ret_state.hp_pct = context.hp or health_pct(context.me, 100)
    ret_state.mana_pct = context.mana_pct or context.mana or 100
    ret_state.enemy_count = context.enemy_count or context.enemies_nearby or 1
    ret_state.target_hp_pct = health_pct(context.target, context.target_hp or 100)
    -- Prefer CLEU-authoritative swing timer when available; fallback to native prediction
    local cleu_remains = (_cleu and _cleu.get_swing_remains and _cleu.get_swing_remains()) or nil
    ret_state.swing_remains = cleu_remains or (NS.get_time_until_swing and NS.get_time_until_swing()) or (context.time_to_swing or 0)
    ret_state.seal_preference = get_setting(context, "seal_preference", get_setting(context, "retri_seal_preference", "auto"))
    ret_state.can_use_blood = should_use_blood(context)
    ret_state.preferred_damage_seal = ret_state.can_use_blood and "blood" or "command"
    -- [ARTISTRY] Improved: Dynamic Twist Window from settings (ms to seconds)
    local twist_ms = get_setting(context, "retri_twist_window", 450)
    ret_state.twist_window = twist_ms / 1000
    -- Alliance faction override: Seal of the Martyr replaces Seal of Blood
    if SPELLS.SealOfTheMartyr and NS.unit_faction and NS.GetPlayer() then
        local faction = NS.unit_faction(NS.GetPlayer())
        if faction == "Alliance" and ret_state.preferred_damage_seal == "blood" then
            ret_state.preferred_damage_seal = "martyr"
        end
    end
    if not skip_aura then
        ret_state.has_blood = has_player_buff(SEAL_BLOOD_BUFF)
        ret_state.has_command = has_player_buff(SEAL_COMMAND_BUFF)
        ret_state.has_command_rank1 = has_player_buff(SEAL_COMMAND_RANK1_BUFF)
        ret_state.has_crusader = has_player_buff(SEAL_CRUSADER_BUFF)
        ret_state.has_righteousness = has_player_buff(SEAL_RIGHTEOUSNESS_BUFF)
        ret_state.has_wisdom = has_player_buff(SEAL_WISDOM_BUFF)
        ret_state.has_martyr = has_player_buff(SEAL_MARTYR_BUFF)
        ret_state.has_damage_seal = ret_state.has_blood or ret_state.has_command or ret_state.has_righteousness or ret_state.has_martyr
        ret_state.has_might = has_player_buff(BLESSING_MIGHT_BUFF)
        ret_state.has_kings = has_player_buff(BLESSING_KINGS_BUFF)
        ret_state.has_forbearance = has_player_debuff(FORBEARANCE_DEBUFF)
        ret_state.target_has_crusader = unit_has_debuff(context.target, JUDGEMENT_CRUSADER_DEBUFF)
        ret_state.target_has_wisdom = unit_has_debuff(context.target, JUDGEMENT_WISDOM_DEBUFF)
    end
    ret_state.target_casting = is_casting(context.target)
    ret_state.target_casting_interruptible = ret_state.target_casting and (NS.is_interruptible and NS.is_interruptible(context.target) or false)
    ret_state.target_player = is_player(context.target)
    ret_state.target_fleeing = context.target_fleeing == true or context.target_is_fleeing == true
    ret_state.in_melee = distance_to(context, context.target) <= MELEE_RANGE
    ret_state.can_twist = NS.get_any_setting(context, "seal_twisting_enabled", "retri_seal_twisting", false) and ret_state.mana_pct >= get_setting(context, "retri_twist_mana_floor", 20)
    ret_state.utility_target = nil
    ret_state.secondary_target = find_secondary_enemy(context)
    ret_state.mana_item = first_ready_item(MANA_POTIONS)
    ret_state.healing_item = first_ready_item(HEALING_ITEMS)
    -- Low-mana emergency: strip to essentials when mana critically low
    local mana_floor_pct = get_setting(context, "retri_mana_floor_pct", 15)
    ret_state.mana_emergency = (ret_state.mana_pct or 100) <= mana_floor_pct
    -- Major power-window awareness for cooldown alignment
    ret_state.bloodlust_active = has_player_buff(BLOODLUST_HEROISM_BUFFS)
    ret_state.major_cd_active = planner and planner.is_major_offensive_cd_active(context) or false
    ret_state.major_cd_window = ret_state.bloodlust_active or ret_state.major_cd_active
    return ret_state
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
    -- Group: preventative at higher HP; solo: emergency only
    local default_threshold = state.is_group and 25 or 15
    local threshold = get_setting(context, "divine_shield_hp", get_setting(context, "retri_ds_hp", default_threshold))
    return (state.hp_pct or 100) <= threshold and not state.has_forbearance and NS.spell_ready(SPELLS.DivineShield, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.DivineShield, PLAYER, "[RET] Divine Shield emergency", { skip_range = true }) end)

add_strategy(strategies, "Ret_LayOnHands_LastResort", 990, function(context, state)
    local default_threshold = state.is_group and 15 or 8
    local threshold = get_setting(context, "lay_on_hands_hp", default_threshold)
    return (state.hp_pct or 100) <= threshold and NS.spell_ready(SPELLS.LayOnHands, PLAYER, { skip_range = true, expected_cooldown = 3600 }) or false
end, function() return cast(SPELLS.LayOnHands, PLAYER, "[RET] Lay on Hands last resort", { skip_range = true, expected_cooldown = 3600 }) end)

add_strategy(strategies, "Ret_SanctityAura", 550, function(context, state)
    if not get_setting(context, "sanctity_aura_enabled", get_setting(context, "retri_aura_enabled", true)) then return false end
    if has_player_buff(SANCTITY_AURA_GATE_BUFF) then return false end
    return NS.spell_ready(SPELLS.SanctityAura, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SanctityAura, PLAYER, "[RET] Sanctity Aura", { skip_range = true }) end)

add_strategy(strategies, "Ret_DivineProtection_Physical", 980, function(context, state)
    local default_threshold = state.is_group and 35 or 22
    local threshold = get_setting(context, "divine_protection_hp", default_threshold)
    return (state.hp_pct or 100) <= threshold and not state.has_forbearance and NS.spell_ready(DivineProtection, PLAYER, { skip_range = true }) or false
end, function() return cast(DivineProtection, PLAYER, "[RET] Divine Protection", { skip_range = true }) end)

add_strategy(strategies, "Ret_HealthstoneOrPotion", 970, function(context, state)
    local default_threshold = state.is_group and 45 or 35
    local threshold = get_setting(context, "healing_item_hp", default_threshold)
    return (state.hp_pct or 100) <= threshold and state.healing_item ~= nil
end, function(_, state) return use_item(state.healing_item) end)

add_strategy(strategies, "Ret_BlessingProtection_FocusedAlly", 930, function(context, state)
    state.utility_target = find_ally(context, function(unit) return unit ~= PLAYER and health_pct(unit, 100) <= 28 and not (NS.debuff_up and NS.debuff_up(unit, {25771})) end)
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
    if NS.DRTracker and NS.DRTracker.is_dr_immune and context.target and NS.DRTracker.is_dr_immune(context.target, "disorient") then return false end
    if NS.pvp_trinket_used_recently(context.target) then return false end
    if not get_setting(context, "repentance_pvp_usage", true) then return false end
    return context.is_pvp and state.target_player and NS.spell_ready(Repentance, context.target, {}) or false
end, function(context) return cast(Repentance, context.target, "[RET PvP] Repentance opener") end)

add_strategy(strategies, "Ret_PvP_HammerJustice_Burst", 820, function(context, state)
    if NS.DRTracker and NS.DRTracker.is_dr_immune and context.target and NS.DRTracker.is_dr_immune(context.target, "stun") then return false end
    if NS.pvp_trinket_used_recently(context.target) then return false end
    return context.is_pvp and state.target_player and NS.spell_ready(HammerJustice, context.target, { expected_cooldown = 60 }) or false
end, function(context) return cast(HammerJustice, context.target, "[RET PvP] Hammer of Justice burst", { expected_cooldown = 60 }) end)

add_strategy(strategies, "Ret_HammerWrath_Execute", 800, function(context, state)
    return (state.target_hp_pct or 100) < 20 and NS.spell_ready(HammerWrath, context.target, { expected_cooldown = 6 }) or false
end, function(context) return cast(HammerWrath, context.target, "[RET] Hammer of Wrath execute", { expected_cooldown = 6 }) end)

add_strategy(strategies, "Ret_HammerWrath_FleeingPvP", 790, function(context, state)
    return context.is_pvp and state.target_fleeing and (state.target_hp_pct or 100) < 25 and NS.spell_ready(HammerWrath, context.target, { expected_cooldown = 6 }) or false
end, function(context) return cast(HammerWrath, context.target, "[RET PvP] Hammer of Wrath fleeing target", { expected_cooldown = 6 }) end)

add_strategy(strategies, "Ret_AvengingWrath_Burst", 780, function(context, state)
    if not get_setting(context, "use_avenging_wrath", get_setting(context, "retri_aw_enabled", true)) then return false end
    if state.has_forbearance then return false end
    if not (NS.spell_ready(SPELLS.AvengingWrath, PLAYER, { skip_range = true, expected_cooldown = 180 }) or false) then return false end
    -- TTD gate: don't waste 3min CD on a dying target
    if context.ttd_known and context.ttd > 0 and context.ttd < 15 then return false end
    -- Align with major power windows (Bloodlust/Drums/other CDs) or burn late fight
    local align = state.major_cd_window or false
    local combat_time = context.combat_time or 0
    local ttd = context.ttd or 999
    if not align and combat_time < 45 and ttd > 15 then return false end
    return true
end, function() return cast(SPELLS.AvengingWrath, PLAYER, "[RET] Avenging Wrath burst", { skip_range = true, expected_cooldown = 180 }) end, 180)

-- HotC Opener: Apply Judgement of the Crusader on pull for +3% raid crit.
-- Skips if another paladin already has the debuff on the target.
add_strategy(strategies, "Ret_HotC_Opener_Seal", 775, function(context, state)
    return context.in_combat and (context.combat_time or 0) < 5
        and not state.target_has_crusader and not state.has_crusader and not state.has_damage_seal
and NS.spell_ready(SealCrusader, PLAYER, { skip_range = true }) or false
end, function() return cast(SealCrusader, PLAYER, "[RET] HotC Opener - Seal of the Crusader", { skip_range = true }) end)

add_strategy(strategies, "Ret_HotC_Opener_Judge", 770, function(context, state)
    return context.in_combat and (context.combat_time or 0) < 8
        and not state.target_has_crusader and state.has_crusader
and NS.spell_ready(SPELLS.Judgement, context.target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(context) return cast(SPELLS.Judgement, context.target, "[RET] HotC Opener - Judge Crusader", { skip_gcd = true, expected_cooldown = 10 }) end)

strategies[#strategies + 1] = {
    name = "SealTwistBlood",
    priority = 760,
    matches = function(context, state)
        -- [ARTISTRY] Improved: Use dynamic twist_window instead of hardcoded 0.45s
        local twist_window = state.twist_window or TWIST_WINDOW
        local swing_remains = state.swing_remains or 99
        if not (state.can_twist and state.has_command and not state.has_blood and swing_remains <= twist_window and NS.spell_ready(SPELLS.SealBlood, PLAYER, { skip_range = true })) then
            -- Diagnostic: if we're in twist window but didn't attempt, log NO-TWIST
            if state.can_twist and swing_remains <= twist_window and not state.has_blood then
                log_twist_result("NO-TWIST")
            end
            return false
        end
        _last_expected_swing_time = (NS.time_now and NS.time_now() or 0) + swing_remains
        return true
    end,
    execute = function()
        if _cleu then _cleu.mark_twist_attempt(SPELLS.SealBlood) end
        local ok = cast(SPELLS.SealBlood, PLAYER, "[RET] Seal twist: Blood", { skip_range = true })
        if ok then
            log_twist_result("PERFECT")
        else
            log_twist_result("PHANTOM")
        end
        return ok
    end,
}

strategies[#strategies + 1] = {
    name = "SealTwistPrepCommand",
    priority = 750,
    matches = function(context, state)
        -- [ARTISTRY] Improved: Sync prep window with dynamic twist_window
        local twist_window = state.twist_window or TWIST_WINDOW
        local prep_start = twist_window + 0.75 -- Give enough time for GCD + Reaction
        local swing_remains = state.swing_remains or 99
        -- If Judgement is about to come off CD (≤1.5s), skip prep and let Judgement fire first
        local judge_cd = NS.cooldown_remains and NS.cooldown_remains(SPELLS.Judgement) or 0
        if judge_cd <= 1.5 then return false end
        if not (state.can_twist and state.can_use_blood and not state.has_command_rank1 and swing_remains <= prep_start and swing_remains > twist_window and NS.spell_ready(SPELLS.SealCommandRank1 or SPELLS.SealCommand, PLAYER, { skip_range = true })) then
            return false
        end
        _last_expected_swing_time = (NS.time_now and NS.time_now() or 0) + swing_remains
        return true
    end,
    execute = function()
        local ok = cast(SPELLS.SealCommandRank1 or SPELLS.SealCommand, PLAYER, "[RET] Seal twist prep: Rank 1 Command", { skip_range = true })
        if not ok then
            log_twist_result("PHANTOM")
        end
        return ok
    end,
}

add_strategy(strategies, "Ret_CrusaderStrike_AfterJudgement", 730, function(context, state)
    return state.in_melee and not state.has_damage_seal and NS.spell_ready(SPELLS.CrusaderStrike, context.target, { expected_cooldown = 6 }) or false
end, function(context) return cast(SPELLS.CrusaderStrike, context.target, "[RET] Crusader Strike after Judgement", { expected_cooldown = 6 }) end)

add_strategy(strategies, "Ret_JudgeCrusader", 720, function(context, state)
    if not post_swing_judge_gate(context, state) then return false end
    return not state.target_has_crusader and state.has_crusader and NS.spell_ready(SPELLS.Judgement, context.target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(context) return cast(SPELLS.Judgement, context.target, "[RET] Judge Seal of the Crusader", { skip_gcd = true, expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_ApplyCrusaderSeal", 710, function(_, state)
    return not state.target_has_crusader and not state.has_crusader and not state.has_damage_seal and NS.spell_ready(SealCrusader, PLAYER, { skip_range = true }) or false
end, function() return cast(SealCrusader, PLAYER, "[RET] Seal of the Crusader", { skip_range = true }) end)

strategies[#strategies + 1] = {
    name = "CrusaderStrike",
    priority = 700,
    cooldown = 6,
    matches = function(context, state)
        local prep_start = (state.twist_window or TWIST_WINDOW) + 0.75
        if state.can_twist and (state.has_command or state.has_command_rank1) and not state.has_blood and (state.swing_remains or 99) <= prep_start then return false end
        return state.in_melee and NS.spell_ready(SPELLS.CrusaderStrike, context.target, { expected_cooldown = 6 }) or false
    end,
    execute = function(context)
        return cast(SPELLS.CrusaderStrike, context.target, "[RET] Crusader Strike", { expected_cooldown = 6 })
    end,
}

add_strategy(strategies, "Ret_JudgeDamageSeal", 690, function(context, state)
    if not post_swing_judge_gate(context, state) then return false end
    return state.has_damage_seal and (state.mana_pct or 100) >= 12 and NS.spell_ready(SPELLS.Judgement, context.target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(context) return cast(SPELLS.Judgement, context.target, "[RET] Judgement damage seal", { skip_gcd = true, expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_SealBlood_Primary", 670, function(_, state)
    return state.preferred_damage_seal == "blood" and not state.has_blood and NS.spell_ready(SPELLS.SealBlood, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealBlood, PLAYER, "[RET] Seal of Blood primary", { skip_range = true }) end)

add_strategy(strategies, "Ret_SealMartyr_Primary", 665, function(_, state)
    return state.preferred_damage_seal == "martyr" and not state.has_martyr and NS.spell_ready(SPELLS.SealOfTheMartyr, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealOfTheMartyr, PLAYER, "[RET] Seal of the Martyr primary", { skip_range = true }) end)

add_strategy(strategies, "Ret_SealCommand_Primary", 660, function(_, state)
    return state.preferred_damage_seal == "command" and not state.has_command and NS.spell_ready(SPELLS.SealCommand, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealCommand, PLAYER, "[RET] Seal of Command primary", { skip_range = true }) end)

add_strategy(strategies, "Ret_JudgementWisdom_LowMana", 640, function(context, state)
    if not post_swing_judge_gate(context, state) then return false end
    local threshold = get_setting(context, "retri_judge_wisdom_mana", 45)
    return (state.mana_pct or 100) <= threshold and state.has_wisdom and not state.target_has_wisdom and NS.spell_ready(SPELLS.Judgement, context.target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(context) return cast(SPELLS.Judgement, context.target, "[RET] Judge Wisdom for mana", { skip_gcd = true, expected_cooldown = 10 }) end)

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
        local prep_start = (state.twist_window or TWIST_WINDOW) + 0.75
        if state.can_twist and (state.has_command or state.has_command_rank1) and not state.has_blood and (state.swing_remains or 99) <= prep_start then return false end
        if state.mana_emergency then return false end
        local min_targets = get_setting(context, "consecration_min_targets", get_setting(context, "retri_consecration_targets", 3))
        return (state.enemy_count or 0) >= min_targets and (state.mana_pct or 100) >= 35 and NS.spell_ready(SPELLS.Consecration, PLAYER, { skip_range = true, expected_cooldown = 8 }) or false
    end,
    execute = function()
        return cast(SPELLS.Consecration, PLAYER, "[RET] Consecration AoE", { skip_range = true, expected_cooldown = 8 })
    end,
}

add_strategy(strategies, "Ret_Consecration_ManaDump", 590, function(context, state)
    if state.mana_emergency then return false end
    return get_setting(context, "consecration_single_target", false) and (state.mana_pct or 0) >= 75 and NS.spell_ready(SPELLS.Consecration, PLAYER, { skip_range = true, expected_cooldown = 8 }) or false
end, function() return cast(SPELLS.Consecration, PLAYER, "[RET] Consecration mana dump", { skip_range = true, expected_cooldown = 8 }) end, 8)

add_strategy(strategies, "Exorcism", 580, function(context, state)
    local prep_start = (state.twist_window or TWIST_WINDOW) + 0.75
    if state.can_twist and (state.has_command or state.has_command_rank1) and not state.has_blood and (state.swing_remains or 99) <= prep_start then return false end
    if state.mana_emergency then return false end
    -- [ARTISTRY] Improved: TBC Exorcism only works on Undead and Demons.
    if not context.target then return false end
    local type = creature_type(context.target)
    return (DEMON_OR_UNDEAD[type] and NS.spell_ready(SPELLS.Exorcism, context.target, { expected_cooldown = 15 }) or false) or false
end, function(context) return NS.try_cast(SPELLS.Exorcism, context.target, "[RET] Exorcism", { expected_cooldown = 15 }) end, 15)

add_strategy(strategies, "Ret_HolyWrath_AoE", 575, function(context, state)
    local prep_start = (state.twist_window or TWIST_WINDOW) + 0.75
    if state.can_twist and (state.has_command or state.has_command_rank1) and not state.has_blood and (state.swing_remains or 99) <= prep_start then return false end
    if state.mana_emergency then return false end
    -- [ARTISTRY] Improved: TBC Holy Wrath works on Undead/Demon groups.
    if (state.enemy_count or 0) < 2 or (state.mana_pct or 100) < 40 then return false end
    if not (NS.spell_ready(SPELLS.HolyWrath, PLAYER, { skip_range = true }) or false) then return false end
    -- Check if target is undead/demon
    local type = creature_type(context.target)
    return DEMON_OR_UNDEAD[type] or false
end, function() return cast(SPELLS.HolyWrath, PLAYER, "[RET] Holy Wrath AoE", { skip_range = true, expected_cooldown = 60 }) end, 60)

add_strategy(strategies, "Ret_JudgeSecondary_CommandCleave", 570, function(context, state)
    if not post_swing_judge_gate(context, state) then return false end
    return state.secondary_target ~= nil and state.has_command and (state.mana_pct or 0) >= 30 and NS.spell_ready(SPELLS.Judgement, state.secondary_target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(_, state) return cast(SPELLS.Judgement, state.secondary_target, "[RET] Judgement secondary cleave", { skip_gcd = true, expected_cooldown = 10 }) end)

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
    if state.mana_emergency then return false end
    local min_targets = get_setting(context, "command_cleave_min_targets", 2)
    return (state.enemy_count or 0) >= min_targets and not state.has_command and NS.spell_ready(SPELLS.SealCommand, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealCommand, PLAYER, "[RET] Seal of Command cleave", { skip_range = true }) end)

add_strategy(strategies, "Ret_SealRighteousness_Filler", 470, function(_, state)
    return not state.has_damage_seal and not state.has_wisdom and NS.spell_ready(SPELLS.SealRighteousness, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealRighteousness, PLAYER, "[RET] Seal of Righteousness filler", { skip_range = true }) end)

add_strategy(strategies, "Ret_Judgement_RighteousnessFiller", 460, function(context, state)
    if not post_swing_judge_gate(context, state) then return false end
    return state.has_righteousness and (state.mana_pct or 0) >= 25 and NS.spell_ready(SPELLS.Judgement, context.target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(context) return cast(SPELLS.Judgement, context.target, "[RET] Judge Righteousness filler", { skip_gcd = true, expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_SealCommand_Fallback", 450, function(_, state)
    return not state.has_damage_seal and NS.spell_ready(SPELLS.SealCommand, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealCommand, PLAYER, "[RET] Seal of Command fallback", { skip_range = true }) end)

add_strategy(strategies, "Ret_SealBlood_Fallback", 440, function(_, state)
    return not state.has_damage_seal and NS.spell_ready(SPELLS.SealBlood, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealBlood, PLAYER, "[RET] Seal of Blood fallback", { skip_range = true }) end)

add_strategy(strategies, "Ret_SealMartyr_Fallback", 435, function(_, state)
    return not state.has_damage_seal and NS.spell_ready(SPELLS.SealOfTheMartyr, PLAYER, { skip_range = true }) or false
end, function() return cast(SPELLS.SealOfTheMartyr, PLAYER, "[RET] Seal of the Martyr fallback", { skip_range = true }) end)

NS.rotation_registry:register("retribution", strategies, { get_state = build_state })
return { strategies = strategies, build_state = build_state }

