-- retribution_sylvanas.lua — Paladin Retribution DPS for TBC Anniversary (2.5.5).
-- WHAT:  melee DPS spec (Crusader Strike, Judgement, seal twisting SoB/SoM/SoC,
--          post-swing Judgement gate, CLEU twist diagnostics, PvP utility).
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors wowsims APL: CS > Judgement > Consecration > Exorcism.
-- SAFETY: state.* reads nil-guarded via spec_kit.safe_state(); seal-twist timing
--          native-backed; registration guarded.
local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local SPELLS = NS.PaladinSpells or {}

-- spec_kit migration #24
local spec_kit = require("shared/spec_kit_sylvanas")

-- Fallback merge_state for test environments that mock an older spec_kit
-- without the shared helper. Production uses spec_kit.merge_state.
local merge_state = spec_kit.merge_state or function(build_state, context, state_override)
    local s = build_state(context)
    if not state_override or next(state_override) == nil then return s end
    local merged = {}
    for k, v in pairs(s) do merged[k] = v end
    for k, v in pairs(state_override) do merged[k] = v end
    local mt = getmetatable(s)
    if mt then
        local mt_copy = {}
        for k, v in pairs(mt) do mt_copy[k] = v end
        mt_copy.__newindex = nil
        setmetatable(merged, mt_copy)
    end
    return merged
end
local dsl = require("shared/strategy_dsl_sylvanas")
local HitCap = require("shared/hit_cap_tracker_sylvanas")
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    AvengingWrath        = define("AvengingWrath",        { 31884 }, "AvengingWrath"),
    BlessingOfFreedom    = define("BlessingOfFreedom",    { 1044 }, "BlessingOfFreedom"),
    BlessingOfKings      = define("BlessingOfKings",      { 20217 }, "BlessingOfKings"),
    BlessingOfMight      = define("BlessingOfMight",      { 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }, "BlessingOfMight"),
    BlessingOfProtection = define("BlessingOfProtection", { 10278, 5599, 1022 }, "BlessingOfProtection"),
    Cleanse              = define("Cleanse",              { 4987 }, "Cleanse"),
    Consecration         = define("Consecration",         { 27173, 20924, 20923, 20922, 20116, 26573 }, "Consecration"),
    CrusaderStrike       = define("CrusaderStrike",       { 35395 }, "CrusaderStrike"),
    DivineProtection     = define("DivineProtection",     { 5573, 498 }, "DivineProtection"),
    DivineShield         = define("DivineShield",         { 1020, 642 }, "DivineShield"),
    Exorcism             = define("Exorcism",             { 27138, 10314, 10313, 10312, 5615, 5614, 879 }, "Exorcism"),
    HammerOfJustice      = define("HammerOfJustice",      { 10308, 5589, 5588, 853 }, "HammerOfJustice"),
    HammerOfWrath        = define("HammerOfWrath",        { 27180, 24275, 24274, 24239 }, "HammerOfWrath"),
    HolyWrath            = define("HolyWrath",            { 27139, 10318, 2812 }, "HolyWrath"),
    Judgement            = define("Judgement",            { 20271 }, "Judgement"),
    LayOnHands           = define("LayOnHands",           { 27154, 10310, 2800, 633 }, "LayOnHands"),
    Purify               = define("Purify",               { 1152 }, "Purify"),
    Repentance           = define("Repentance",           { 20066, 5164 }, "Repentance"),
    SanctityAura         = define("SanctityAura",         { 20218 }, "SanctityAura"),
    SealBlood            = define("SealBlood",            { 31892 }, "SealBlood"),
    SealCommand          = define("SealCommand",          { 27170, 20920, 20919, 20918, 20915, 20375 }, "SealCommand"),
    SealCrusader         = define("SealCrusader",         { 27158, 20308, 20307, 20306, 20305, 20162, 21082 }, "SealCrusader"),
    SealOfTheMartyr      = define("SealOfTheMartyr",      { 348700 }, "SealOfTheMartyr"),
    SealOfWisdom         = define("SealOfWisdom",         { 27166, 20357, 20356, 20166 }, "SealOfWisdom"),
    SealRighteousness    = define("SealRighteousness",    { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154 }, "SealRighteousness"),
    SealWisdom           = define("SealWisdom",           { 27166, 20357, 20356, 20166 }, "SealWisdom"),
    -- SealCommandRank1 is a rank-1-only variant used for prep twist; nil-safe fallback to SealCommand
    SealCommandRank1     = define("SealCommandRank1",     { 20375 }, "SealCommandRank1"),
    TurnEvil             = define("TurnEvil",             { 10326 }, "TurnEvil"),
}
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
local SealCrusader = ACTION.SealCrusader or action({ 27158, 20308, 20307, 20306, 20305, 20162, 21082 }, "SealCrusader")
local SealWisdom = ACTION.SealOfWisdom or ACTION.SealWisdom or action({ 27166, 20357, 20356, 20166 }, "SealOfWisdom")
local BlessingFreedom = ACTION.BlessingOfFreedom or action({ 1044 }, "BlessingOfFreedom")
local BlessingProtection = ACTION.BlessingOfProtection or action({ 10278, 5599, 1022 }, "BlessingOfProtection")
local DivineProtection = ACTION.DivineProtection or action({ 498 }, "DivineProtection")
local Purify = ACTION.Purify or action({ 1152 }, "Purify")
local HammerWrath = ACTION.HammerOfWrath or action({ 27180, 24275, 24274, 24239 }, "HammerOfWrath")
local HammerJustice = ACTION.HammerOfJustice or action({ 10308, 5589, 5588, 853 }, "HammerOfJustice")
local Repentance = ACTION.Repentance or action({ 20066 }, "Repentance")

local SEAL_COMMAND_BUFF = { 27170, 20920, 20919, 20918, 20915, 20375 }
local SEAL_COMMAND_RANK1_BUFF = { 20375 }
local SEAL_BLOOD_BUFF = { 31892 }
local SEAL_MARTYR_BUFF = { 348700 }
local SEAL_RIGHTEOUSNESS_BUFF = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154 }
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
-- State schema (nil-guard defaults for spec_kit.safe_state)
-- ============================================================================
local RET_SCHEMA = {
    hp_pct = 100,  mana_pct = 100,  target_hp_pct = 100,  enemy_count = 1,
    swing_remains = 99,  in_melee = true,  can_twist = false,  can_use_blood = false,
    mana_emergency = false,  is_group = false,
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
    -- Power windows
    bloodlust_active = false,  major_cd_active = false,  major_cd_window = false,
    hit_cap_pct = 9,
    hit_cap_rating_needed = 142,
    expertise_soft_cap = 26,
    expertise_hard_cap = 56,
}

-- ============================================================================
local _cleu = NS.SwingDiagnostics
if _cleu then
    _cleu.register_seals({
        31892, 348700,
        27170, 20920, 20919, 20918, 20915, 20375,
        27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154,
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
    has_valid_enemy_target = false,
    in_combat = false,
    target_creature_type = nil,
    turn_evil_ready = false,
}

-- get_setting now delegated to spec_kit.setting_*() (Pattern 8)

-- Out-of-combat seal refresh gate. When the "Refresh Seals Out of Combat" option is
-- unchecked, the rotation will NOT recast any seal while out of combat (e.g. standing
-- in town or traveling); the active seal simply expires instead of being re-applied
-- every ~30s. In combat the seal is always maintained. Default true preserves the
-- original "always keep a seal up" behaviour.
local function seal_refresh_allowed(context)
    if context and context.in_combat then return true end
    return spec_kit.setting_bool(context, "seal_refresh_ooc", true)
end

local function has_player_buff(ids)
    return NS.has_player_buff and NS.has_player_buff(ids) or false
end

local function post_swing_judge_gate(context, state)
    if not spec_kit.setting_bool(context, "retri_post_swing_judge", true) then return true end
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
    local preference = spec_kit.setting(context, "seal_preference", spec_kit.setting(context, "retri_seal_preference", "auto"))
    if preference == "blood" then return true end
    if preference == "command" then return false end
    return ACTION.SealBlood ~= nil
end

local function damage_seal_spell(state)
    if state.preferred_damage_seal == "martyr" then return ACTION.SealOfTheMartyr end
    if state.preferred_damage_seal == "blood" then return ACTION.SealBlood end
    return ACTION.SealCommand
end

local function build_state(context)
    local is_group = context.is_group or false
    ret_state.is_group = is_group
    ret_state.hp_pct = context.hp or health_pct(context.me, 100)
    ret_state.mana_pct = context.mana_pct or context.mana or 100
    ret_state.enemy_count = context.enemy_count or context.enemies_nearby or 1
    ret_state.target_hp_pct = health_pct(context.target, context.target_hp or 100)
    -- Prefer CLEU-authoritative swing timer when available; fallback to native prediction
    local cleu_remains = (_cleu and _cleu.get_swing_remains and _cleu.get_swing_remains()) or nil
    ret_state.swing_remains = cleu_remains or (NS.get_time_until_swing and NS.get_time_until_swing()) or (context.time_to_swing or 0)
    ret_state.seal_preference = spec_kit.setting(context, "seal_preference", spec_kit.setting(context, "retri_seal_preference", "auto"))
    ret_state.can_use_blood = should_use_blood(context)
    ret_state.preferred_damage_seal = ret_state.can_use_blood and "blood" or "command"
    -- [ARTISTRY] Improved: Dynamic Twist Window from settings (ms to seconds)
    local twist_ms = spec_kit.setting_number(context, "retri_twist_window", 450)
    ret_state.twist_window = twist_ms / 1000
    -- Alliance faction override: Seal of the Martyr replaces Seal of Blood
    if ACTION.SealOfTheMartyr and NS.unit_faction and NS.GetPlayer and NS.GetPlayer() then
        local faction = NS.unit_faction(NS.GetPlayer())
        if faction == "Alliance" and ret_state.preferred_damage_seal == "blood" then
            ret_state.preferred_damage_seal = "martyr"
        end
    end
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
    ret_state.target_casting = is_casting(context.target)
    ret_state.target_casting_interruptible = ret_state.target_casting and (NS.is_interruptible and NS.is_interruptible(context.target) or false)
    ret_state.target_player = is_player(context.target)
    ret_state.target_fleeing = context.target_fleeing == true or context.target_is_fleeing == true
    ret_state.target_creature_type = creature_type(context.target)
    ret_state.turn_evil_ready = NS.spell_ready(ACTION.TurnEvil, context.me or PLAYER, { expected_cooldown = 1.5 }) or false
    ret_state.in_combat = context.in_combat == true
    ret_state.in_melee = distance_to(context, context.target) <= MELEE_RANGE
    local twist_enabled = true
    if type(NS.get_any_setting) == "function" then
        twist_enabled = NS.get_any_setting(context, "seal_twisting_enabled", "retri_seal_twisting", true)
    end
    ret_state.can_twist = twist_enabled and ret_state.mana_pct >= spec_kit.setting_number(context, "retri_twist_mana_floor", 20)
    ret_state.utility_target = nil
    ret_state.secondary_target = find_secondary_enemy(context)
    ret_state.mana_item = first_ready_item(MANA_POTIONS)
    ret_state.healing_item = first_ready_item(HEALING_ITEMS)
    -- Low-mana emergency: strip to essentials when mana critically low
    local mana_floor_pct = spec_kit.setting_number(context, "retri_mana_floor_pct", 15)
    ret_state.mana_emergency = (ret_state.mana_pct or 100) <= mana_floor_pct
    -- Major power-window awareness for cooldown alignment
    ret_state.bloodlust_active = has_player_buff(BLOODLUST_HEROISM_BUFFS)
    ret_state.major_cd_active = planner and planner.is_major_offensive_cd_active(context) or false
    ret_state.major_cd_window = ret_state.bloodlust_active or ret_state.major_cd_active
    if HitCap then
        local hit_info = HitCap.get_hit_cap("paladin_melee")
        if hit_info then
            ret_state.hit_cap_pct = hit_info.pct_needed
            ret_state.hit_cap_rating_needed = hit_info.rating_needed
        end
        local exp_info = HitCap.get_expertise_cap()
        if exp_info then
            ret_state.expertise_soft_cap = exp_info.soft_expertise
            ret_state.expertise_hard_cap = exp_info.hard_expertise
        end
    end
    -- Centralized target validity gate used by base_matches guards
    local t = context.target
    if t ~= nil then
        local is_valid = false
        if NS.is_valid_target then
            is_valid = NS.is_valid_target(t)
        elseif t.is_valid then
            is_valid = t:is_valid()
        end
        if is_valid and not (t.is_dead and t:is_dead()) then
            ret_state.has_valid_enemy_target = true
        end
    end
    return spec_kit.safe_state(ret_state, RET_SCHEMA)
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

-- ============================================================================
-- Centralized base_matches guards
-- ============================================================================
-- Merge a caller-provided state override into the state built from context.
-- This keeps tests ergonomic (callers can pass partial states) without
-- mutating the static cached state table (Pattern 4).

local function base_guard_passes(action_def, s)
    if not action_def then return true end
    if action_def.requires_in_combat and not s.in_combat then return false end
    if action_def.requires_not_in_combat and s.in_combat then return false end
    if action_def.requires_target and not s.has_valid_enemy_target then return false end
    if action_def.requires_melee and not s.in_melee then return false end
    if action_def.mana_emergency_ok == false and s.mana_emergency then return false end
    if action_def.requires_no_forbearance and s.has_forbearance then return false end
    return true
end

local function apply_base_matches(strategies, actions)
    for i = 1, #strategies do
        local action = actions[strategies[i].name]
        local original_matches = strategies[i].matches
        strategies[i].matches = function(context, state)
            local s = merge_state(build_state, context, state)
            if not base_guard_passes(action, s) then return false end
            return original_matches(context, s)
        end
    end
end

-- Strategy metadata for centralized guards. Keys correspond to strategy.name.
local ACTIONS = {
    Ret_DivineShield_Emergency         = { requires_target = false, mana_emergency_ok = true },
    Ret_LayOnHands_LastResort          = { requires_target = false, mana_emergency_ok = true },
    Ret_SanctityAura                   = { requires_target = false, mana_emergency_ok = true },
    Ret_DivineProtection_Physical      = { requires_target = false, requires_in_combat = true, mana_emergency_ok = true, requires_no_forbearance = true },
    Ret_HealthstoneOrPotion            = { requires_target = false, mana_emergency_ok = true },
    Ret_BlessingProtection_FocusedAlly = { requires_target = false, mana_emergency_ok = true },
    Ret_BlessingFreedom_Self           = { requires_target = false, mana_emergency_ok = true },
    Ret_BlessingFreedom_Ally           = { requires_target = false, mana_emergency_ok = true },
    Ret_Cleanse_Self                   = { requires_target = false, mana_emergency_ok = true },
    Ret_Purify_SelfFallback            = { requires_target = false, mana_emergency_ok = true },
    Ret_Cleanse_Ally                   = { requires_target = false, mana_emergency_ok = true },
    Ret_PvP_Repentance_Opener          = { requires_target = true,  requires_in_combat = true, mana_emergency_ok = false },
    Ret_PvP_HammerJustice_Burst        = { requires_target = true,  requires_in_combat = true, mana_emergency_ok = false },
    Ret_HammerWrath_Execute            = { requires_target = true,  mana_emergency_ok = false },
    Ret_HammerWrath_FleeingPvP         = { requires_target = true,  mana_emergency_ok = false },
    Ret_AvengingWrath_Burst            = { requires_target = true,  requires_in_combat = true, requires_no_forbearance = true, mana_emergency_ok = false },
    Ret_HotC_Opener_Seal               = { requires_target = true,  requires_in_combat = true, mana_emergency_ok = false },
    Ret_HotC_Opener_Judge              = { requires_target = true,  requires_in_combat = true, mana_emergency_ok = false },
    SealTwistBlood                     = { requires_target = false, requires_melee = true,     mana_emergency_ok = false },
    SealTwistPrepCommand               = { requires_target = false, requires_melee = true,     mana_emergency_ok = false },
    Ret_CrusaderStrike_AfterJudgement  = { requires_target = true,  requires_melee = true,     mana_emergency_ok = false },
    Ret_JudgeCrusader                  = { requires_target = true,  mana_emergency_ok = false },
    Ret_ApplyCrusaderSeal              = { requires_target = false, mana_emergency_ok = false },
    CrusaderStrike                     = { requires_target = true,  requires_melee = true,     mana_emergency_ok = false },
    Ret_JudgeDamageSeal                = { requires_target = true,  mana_emergency_ok = false },
    Ret_SealBlood_Primary              = { requires_target = false, mana_emergency_ok = false },
    Ret_SealMartyr_Primary             = { requires_target = false, mana_emergency_ok = false },
    Ret_SealCommand_Primary            = { requires_target = false, mana_emergency_ok = false },
    Ret_JudgementWisdom_LowMana        = { requires_target = true,  mana_emergency_ok = true },
    Ret_SealWisdom_Emergency           = { requires_target = false, mana_emergency_ok = true },
    Ret_ManaPotion                     = { requires_target = false, mana_emergency_ok = true },
    Consecration                       = { requires_target = false, requires_in_combat = true, mana_emergency_ok = false },
    Ret_Consecration_ManaDump          = { requires_target = false, requires_in_combat = true, mana_emergency_ok = false },
    TurnEvil                           = { requires_target = true,  mana_emergency_ok = false },
    Exorcism                           = { requires_target = true,  mana_emergency_ok = false },
    Ret_HolyWrath_AoE                  = { requires_target = false, requires_in_combat = true, mana_emergency_ok = false },
    Ret_JudgeSecondary_CommandCleave   = { requires_target = true,  mana_emergency_ok = false },
    Ret_BlessingMight_Self             = { requires_target = false, mana_emergency_ok = true },
    Ret_BlessingKings_Self             = { requires_target = false, mana_emergency_ok = true },
    Ret_BlessingMight_MeleeAlly        = { requires_target = false, mana_emergency_ok = true },
    Ret_BlessingKings_Party            = { requires_target = false, mana_emergency_ok = true },
    Ret_SealCommand_AoE                = { requires_target = false, mana_emergency_ok = false },
    Ret_SealRighteousness_Filler       = { requires_target = false, mana_emergency_ok = false },
    Ret_Judgement_RighteousnessFiller  = { requires_target = true,  mana_emergency_ok = false },
    Ret_SealCommand_Fallback           = { requires_target = false, mana_emergency_ok = false },
    Ret_SealBlood_Fallback             = { requires_target = false, mana_emergency_ok = false },
    Ret_SealMartyr_Fallback            = { requires_target = false, mana_emergency_ok = false },
}

local strategies = {}

add_strategy(strategies, "Ret_DivineShield_Emergency", 1000, function(context, state)
    -- Group: preventative at higher HP; solo: emergency only
    local group_aware = spec_kit.setting_bool(context, "paladin_group_aware_defensives", true)
    local default_threshold = (group_aware and state.is_group) and 25 or 15
    local threshold = spec_kit.setting_number(context, "divine_shield_hp", spec_kit.setting_number(context, "retri_ds_hp", default_threshold))
    return (state.hp_pct or 100) <= threshold and not state.has_forbearance and NS.spell_ready(ACTION.DivineShield, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.DivineShield, PLAYER, "[RET] Divine Shield emergency", { skip_range = true }) end)

add_strategy(strategies, "Ret_LayOnHands_LastResort", 990, function(context, state)
    local group_aware = spec_kit.setting_bool(context, "paladin_group_aware_defensives", true)
    local default_threshold = (group_aware and state.is_group) and 15 or 8
    local threshold = spec_kit.setting_number(context, "lay_on_hands_hp", default_threshold)
    return (state.hp_pct or 100) <= threshold and NS.spell_ready(ACTION.LayOnHands, PLAYER, { skip_range = true, expected_cooldown = 3600 }) or false
end, function() return cast(ACTION.LayOnHands, PLAYER, "[RET] Lay on Hands last resort", { skip_range = true, expected_cooldown = 3600 }) end)

add_strategy(strategies, "Ret_SanctityAura", 550, function(context, state)
    if not spec_kit.setting_bool(context, "sanctity_aura_enabled", spec_kit.setting_bool(context, "retri_aura_enabled", true)) then return false end
    if has_player_buff(SANCTITY_AURA_GATE_BUFF) then return false end
    return NS.spell_ready(ACTION.SanctityAura, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.SanctityAura, PLAYER, "[RET] Sanctity Aura", { skip_range = true }) end)

add_strategy(strategies, "Ret_DivineProtection_Physical", 980, function(context, state)
    local group_aware = spec_kit.setting_bool(context, "paladin_group_aware_defensives", true)
    local default_threshold = (group_aware and state.is_group) and 35 or 22
    local threshold = spec_kit.setting_number(context, "divine_protection_hp", default_threshold)
    return (state.hp_pct or 100) <= threshold and not state.has_forbearance and NS.spell_ready(DivineProtection, PLAYER, { skip_range = true }) or false
end, function() return cast(DivineProtection, PLAYER, "[RET] Divine Protection", { skip_range = true }) end)

add_strategy(strategies, "Ret_HealthstoneOrPotion", 970, function(context, state)
    local group_aware = spec_kit.setting_bool(context, "paladin_group_aware_defensives", true)
    local default_threshold = (group_aware and state.is_group) and 45 or 35
    local threshold = spec_kit.setting_number(context, "healing_item_hp", default_threshold)
    return (state.hp_pct or 100) <= threshold and state.healing_item ~= nil
end, function(_, state) return use_item(state.healing_item) end)

add_strategy(strategies, "Ret_BlessingProtection_FocusedAlly", 930, function(context, state)
    state.utility_target = find_ally(context, function(unit) return unit ~= PLAYER and health_pct(unit, 100) <= 28 and not (NS.debuff_up and NS.debuff_up(unit, {25771})) end)
    return state.utility_target ~= nil and NS.spell_ready(BlessingProtection, state.utility_target, {}) or false
end, function(_, state) return cast(BlessingProtection, state.utility_target, "[RET] Blessing of Protection ally") end)

add_strategy(strategies, "Ret_BlessingFreedom_Self", 920, function(context)
    if not spec_kit.setting_bool(context, "blessing_of_freedom_self", true) then return false end
    local snared = context.self_rooted_snared or has_player_debuff(COMMON_SNARES)
    return snared and NS.spell_ready(BlessingFreedom, PLAYER, { skip_range = true }) or false
end, function() return cast(BlessingFreedom, PLAYER, "[RET] Blessing of Freedom self", { skip_range = true }) end)

add_strategy(strategies, "Ret_BlessingFreedom_Ally", 910, function(context, state)
    if not spec_kit.setting_bool(context, "blessing_of_freedom_allies", true) then return false end
    state.utility_target = find_ally(context, function(unit) return unit_has_debuff(unit, COMMON_SNARES) end)
    return state.utility_target ~= nil and NS.spell_ready(BlessingFreedom, state.utility_target, {}) or false
end, function(_, state) return cast(BlessingFreedom, state.utility_target, "[RET] Blessing of Freedom ally") end)

add_strategy(strategies, "Ret_Cleanse_Self", 900, function(context)
    if not spec_kit.setting_bool(context, "use_cleanse", spec_kit.setting_bool(context, "retri_auto_cleanse", true)) then return false end
    return has_player_debuff(COMMON_CLEANSE) and NS.spell_ready(ACTION.Cleanse, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.Cleanse, PLAYER, "[RET] Cleanse self", { skip_range = true }) end)

add_strategy(strategies, "Ret_Purify_SelfFallback", 890, function(context)
    if not spec_kit.setting_bool(context, "use_purify", true) then return false end
    return has_player_debuff(COMMON_CLEANSE) and NS.spell_ready(Purify, PLAYER, { skip_range = true }) or false
end, function() return cast(Purify, PLAYER, "[RET] Purify self", { skip_range = true }) end)

add_strategy(strategies, "Ret_Cleanse_Ally", 880, function(context, state)
    if not spec_kit.setting_bool(context, "cleanse_allies", true) then return false end
    state.utility_target = find_ally(context, function(unit) return unit_has_debuff(unit, COMMON_CLEANSE) end)
    return state.utility_target ~= nil and NS.spell_ready(ACTION.Cleanse, state.utility_target, {}) or false
end, function(_, state) return cast(ACTION.Cleanse, state.utility_target, "[RET] Cleanse ally") end)

add_strategy(strategies, "Ret_PvP_Repentance_Opener", 850, function(context, state)
    if NS.DRTracker and NS.DRTracker.is_dr_immune and context.target and NS.DRTracker.is_dr_immune(context.target, "disorient") then return false end
    if NS.pvp_trinket_used_recently(context.target) then return false end
    if not spec_kit.setting_bool(context, "repentance_pvp_usage", true) then return false end
    -- IZI SDK: skip if target is already CC'd
    local target = context.target
    if target and type(target.is_cc) == "function" then
        local ok, cc = pcall(target.is_cc, target)
        if ok and cc then return false end
    end
    return context.is_pvp and state.target_player and NS.spell_ready(Repentance, context.target, {}) or false
end, function(context) return cast(Repentance, context.target, "[RET PvP] Repentance opener") end)

add_strategy(strategies, "Ret_PvP_HammerJustice_Burst", 820, function(context, state)
    if NS.DRTracker and NS.DRTracker.is_dr_immune and context.target and NS.DRTracker.is_dr_immune(context.target, "stun") then return false end
    if NS.pvp_trinket_used_recently(context.target) then return false end
    -- IZI SDK: skip if target is already CC'd
    local target = context.target
    if target and type(target.is_cc) == "function" then
        local ok, cc = pcall(target.is_cc, target)
        if ok and cc then return false end
    end
    return context.is_pvp and state.target_player and NS.spell_ready(HammerJustice, context.target, { expected_cooldown = 60 }) or false
end, function(context) return cast(HammerJustice, context.target, "[RET PvP] Hammer of Justice burst", { expected_cooldown = 60 }) end)

add_strategy(strategies, "Ret_HammerWrath_Execute", 800, function(context, state)
    return (state.target_hp_pct or 100) < 20 and NS.spell_ready(HammerWrath, context.target, { expected_cooldown = 6 }) or false
end, function(context) return cast(HammerWrath, context.target, "[RET] Hammer of Wrath execute", { expected_cooldown = 6 }) end)

add_strategy(strategies, "Ret_HammerWrath_FleeingPvP", 790, function(context, state)
    return context.is_pvp and state.target_fleeing and (state.target_hp_pct or 100) < 25 and NS.spell_ready(HammerWrath, context.target, { expected_cooldown = 6 }) or false
end, function(context) return cast(HammerWrath, context.target, "[RET PvP] Hammer of Wrath fleeing target", { expected_cooldown = 6 }) end)

add_strategy(strategies, "Ret_AvengingWrath_Burst", 780, function(context, state)
    if not spec_kit.setting_bool(context, "use_avenging_wrath", spec_kit.setting_bool(context, "retri_aw_enabled", true)) then return false end
    if state.has_forbearance then return false end
    if not (NS.spell_ready(ACTION.AvengingWrath, PLAYER, { skip_range = true, expected_cooldown = 180 }) or false) then return false end
    -- TTD gate: don't waste 3min CD on a dying target
    if context.ttd_known and context.ttd > 0 and context.ttd < 15 then return false end
    -- Align with major power windows (Bloodlust/Drums/other CDs) or burn late fight
    local align = state.major_cd_window or false
    local combat_time = context.combat_time or 0
    local ttd = context.ttd or 999
    if not align and combat_time < 45 and ttd > 15 then return false end
    return true
end, function() return cast(ACTION.AvengingWrath, PLAYER, "[RET] Avenging Wrath burst", { skip_range = true, expected_cooldown = 180 }) end, 180)

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
and NS.spell_ready(ACTION.Judgement, context.target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(context) return cast(ACTION.Judgement, context.target, "[RET] HotC Opener - Judge Crusader", { skip_gcd = true, expected_cooldown = 10 }) end)

strategies[#strategies + 1] = {
    name = "SealTwistBlood",
    priority = 760,
    matches = function(context, state)
        if not seal_refresh_allowed(context) then return false end
        -- [ARTISTRY] Improved: Use dynamic twist_window instead of hardcoded 0.45s
        local twist_window = state.twist_window or TWIST_WINDOW
        local swing_remains = state.swing_remains or 99
        if not (state.can_twist and state.has_command and not state.has_blood and swing_remains <= twist_window and NS.spell_ready(ACTION.SealBlood, PLAYER, { skip_range = true })) then
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
        if _cleu then _cleu.mark_twist_attempt(ACTION.SealBlood) end
        local ok = cast(ACTION.SealBlood, PLAYER, "[RET] Seal twist: Blood", { skip_range = true })
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
        if not seal_refresh_allowed(context) then return false end
        -- [ARTISTRY] Improved: Sync prep window with dynamic twist_window
        local twist_window = state.twist_window or TWIST_WINDOW
        local prep_start = twist_window + 0.75 -- Give enough time for GCD + Reaction
        local swing_remains = state.swing_remains or 99
        -- If Judgement is about to come off CD (≤1.5s), skip prep and let Judgement fire first
        local judge_cd = NS.cooldown_remains and NS.cooldown_remains(ACTION.Judgement) or 0
        if judge_cd <= 1.5 then return false end
        if not (state.can_twist and state.can_use_blood and not state.has_command_rank1 and swing_remains <= prep_start and swing_remains > twist_window and NS.spell_ready(ACTION.SealCommandRank1 or ACTION.SealCommand, PLAYER, { skip_range = true })) then
            return false
        end
        _last_expected_swing_time = (NS.time_now and NS.time_now() or 0) + swing_remains
        return true
    end,
    execute = function()
        local ok = cast(ACTION.SealCommandRank1 or ACTION.SealCommand, PLAYER, "[RET] Seal twist prep: Rank 1 Command", { skip_range = true })
        if not ok then
            log_twist_result("PHANTOM")
        end
        return ok
    end,
}

add_strategy(strategies, "Ret_CrusaderStrike_AfterJudgement", 730, function(context, state)
    return state.in_melee and not state.has_damage_seal and NS.spell_ready(ACTION.CrusaderStrike, context.target, { expected_cooldown = 6 }) or false
end, function(context) return cast(ACTION.CrusaderStrike, context.target, "[RET] Crusader Strike after Judgement", { expected_cooldown = 6 }) end)

add_strategy(strategies, "Ret_JudgeCrusader", 720, function(context, state)
    if not post_swing_judge_gate(context, state) then return false end
    return not state.target_has_crusader and state.has_crusader and NS.spell_ready(ACTION.Judgement, context.target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(context) return cast(ACTION.Judgement, context.target, "[RET] Judge Seal of the Crusader", { skip_gcd = true, expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_ApplyCrusaderSeal", 710, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return not state.target_has_crusader and not state.has_crusader and not state.has_damage_seal and NS.spell_ready(SealCrusader, PLAYER, { skip_range = true }) or false
end, function() return cast(SealCrusader, PLAYER, "[RET] Seal of the Crusader", { skip_range = true }) end)

strategies[#strategies + 1] = {
    name = "CrusaderStrike",
    priority = 700,
    cooldown = 6,
    matches = function(context, state)
        local prep_start = (state.twist_window or TWIST_WINDOW) + 0.75
        if state.can_twist and (state.has_command or state.has_command_rank1) and not state.has_blood and (state.swing_remains or 99) <= prep_start then return false end
        return state.in_melee and NS.spell_ready(ACTION.CrusaderStrike, context.target, { expected_cooldown = 6 }) or false
    end,
    execute = function(context)
        return cast(ACTION.CrusaderStrike, context.target, "[RET] Crusader Strike", { expected_cooldown = 6 })
    end,
}

add_strategy(strategies, "Ret_JudgeDamageSeal", 690, function(context, state)
    if not post_swing_judge_gate(context, state) then return false end
    return state.has_damage_seal and (state.mana_pct or 100) >= 12 and NS.spell_ready(ACTION.Judgement, context.target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(context) return cast(ACTION.Judgement, context.target, "[RET] Judgement damage seal", { skip_gcd = true, expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_SealBlood_Primary", 670, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return state.preferred_damage_seal == "blood" and not state.has_blood and NS.spell_ready(ACTION.SealBlood, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.SealBlood, PLAYER, "[RET] Seal of Blood primary", { skip_range = true }) end)

add_strategy(strategies, "Ret_SealMartyr_Primary", 665, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return state.preferred_damage_seal == "martyr" and not state.has_martyr and NS.spell_ready(ACTION.SealOfTheMartyr, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.SealOfTheMartyr, PLAYER, "[RET] Seal of the Martyr primary", { skip_range = true }) end)

add_strategy(strategies, "Ret_SealCommand_Primary", 660, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return state.preferred_damage_seal == "command" and not state.has_command and NS.spell_ready(ACTION.SealCommand, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.SealCommand, PLAYER, "[RET] Seal of Command primary", { skip_range = true }) end)

add_strategy(strategies, "Ret_JudgementWisdom_LowMana", 640, function(context, state)
    if not post_swing_judge_gate(context, state) then return false end
    local threshold = spec_kit.setting_number(context, "retri_judge_wisdom_mana", 45)
    return (state.mana_pct or 100) <= threshold and state.has_wisdom and not state.target_has_wisdom and NS.spell_ready(ACTION.Judgement, context.target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(context) return cast(ACTION.Judgement, context.target, "[RET] Judge Wisdom for mana", { skip_gcd = true, expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_SealWisdom_Emergency", 630, function(_, state)
    return (state.mana_pct or 100) <= 18 and not state.has_wisdom and NS.spell_ready(SealWisdom, PLAYER, { skip_range = true }) or false
end, function() return cast(SealWisdom, PLAYER, "[RET] Seal of Wisdom emergency", { skip_range = true }) end)

add_strategy(strategies, "Ret_ManaPotion", 620, function(context, state)
    local threshold = spec_kit.setting_number(context, "mana_potion_pct", spec_kit.setting_number(context, "retri_mana_potion", 20))
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
        local min_targets = spec_kit.setting_number(context, "consecration_min_targets", spec_kit.setting_number(context, "retri_consecration_targets", 3))
        return (state.mana_pct or 100) >= 35 and NS.spell_ready(ACTION.Consecration, PLAYER, { skip_range = true, expected_cooldown = 8 })
            and NS.aoe_self_meets and NS.aoe_self_meets(min_targets, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state) or false
    end,
    execute = function()
        return cast(ACTION.Consecration, PLAYER, "[RET] Consecration AoE", { skip_range = true, expected_cooldown = 8 })
    end,
}

add_strategy(strategies, "Ret_Consecration_ManaDump", 590, function(context, state)
    if state.mana_emergency then return false end
    return spec_kit.setting_bool(context, "consecration_single_target", false) and (state.mana_pct or 0) >= 75 and NS.spell_ready(ACTION.Consecration, PLAYER, { skip_range = true, expected_cooldown = 8 }) or false
end, function() return cast(ACTION.Consecration, PLAYER, "[RET] Consecration mana dump", { skip_range = true, expected_cooldown = 8 }) end, 8)

add_strategy(strategies, "TurnEvil", 585, function(context, state)
    if not spec_kit.setting_bool(context, "retri_auto_turn_evil", true) then return false end
    if not state.turn_evil_ready then return false end
    if not context.has_valid_enemy_target then return false end
    local ct = state.target_creature_type
    if not ct or not DEMON_OR_UNDEAD[ct] then return false end
    if context.target and NS.debuff_up and NS.debuff_up(context.target, {10326}) then return false end
    return true
end, function(context) return NS.try_cast(ACTION.TurnEvil, context.target, "[RET] TurnEvil") end, 30)

add_strategy(strategies, "Exorcism", 580, function(context, state)
    local prep_start = (state.twist_window or TWIST_WINDOW) + 0.75
    if state.can_twist and (state.has_command or state.has_command_rank1) and not state.has_blood and (state.swing_remains or 99) <= prep_start then return false end
    if state.mana_emergency then return false end
    -- [ARTISTRY] Improved: TBC Exorcism only works on Undead and Demons.
    if not context.target then return false end
    local type = state.target_creature_type
    return (DEMON_OR_UNDEAD[type] and NS.spell_ready(ACTION.Exorcism, context.target, { expected_cooldown = 15 }) or false) or false
end, function(context) return NS.try_cast(ACTION.Exorcism, context.target, "[RET] Exorcism", { expected_cooldown = 15 }) end, 15)

add_strategy(strategies, "Ret_HolyWrath_AoE", 575, function(context, state)
    local prep_start = (state.twist_window or TWIST_WINDOW) + 0.75
    if state.can_twist and (state.has_command or state.has_command_rank1) and not state.has_blood and (state.swing_remains or 99) <= prep_start then return false end
    if state.mana_emergency then return false end
    -- [ARTISTRY] Improved: TBC Holy Wrath works on Undead/Demon groups.
    if (state.enemy_count or 0) < 2 or (state.mana_pct or 100) < 40 then return false end
    if not (NS.spell_ready(ACTION.HolyWrath, PLAYER, { skip_range = true }) or false) then return false end
    -- Check if target is undead/demon
    local type = state.target_creature_type
    return DEMON_OR_UNDEAD[type] or false
end, function() return cast(ACTION.HolyWrath, PLAYER, "[RET] Holy Wrath AoE", { skip_range = true, expected_cooldown = 60 }) end, 60)

add_strategy(strategies, "Ret_JudgeSecondary_CommandCleave", 570, function(context, state)
    if not post_swing_judge_gate(context, state) then return false end
    return state.secondary_target ~= nil and state.has_command and (state.mana_pct or 0) >= 30 and NS.spell_ready(ACTION.Judgement, state.secondary_target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(_, state) return cast(ACTION.Judgement, state.secondary_target, "[RET] Judgement secondary cleave", { skip_gcd = true, expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_BlessingMight_Self", 540, function(context, state)
    if not spec_kit.setting_bool(context, "blessing_of_might_self", spec_kit.setting_bool(context, "retri_bless_might", true)) then return false end
    return not state.has_might and NS.spell_ready(ACTION.BlessingOfMight, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.BlessingOfMight, PLAYER, "[RET] Blessing of Might self", { skip_range = true }) end)

add_strategy(strategies, "Ret_BlessingKings_Self", 530, function(context, state)
    if not spec_kit.setting_bool(context, "blessing_of_kings_self", false) then return false end
    return not state.has_kings and NS.spell_ready(ACTION.BlessingOfKings, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.BlessingOfKings, PLAYER, "[RET] Blessing of Kings self", { skip_range = true }) end)

add_strategy(strategies, "Ret_BlessingMight_MeleeAlly", 520, function(context, state)
    if not spec_kit.setting_bool(context, "blessing_of_might_melee", true) then return false end
    state.utility_target = find_ally(context, function(unit) return not unit_has_buff(unit, BLESSING_MIGHT_BUFF) end)
    return state.utility_target ~= nil and NS.spell_ready(ACTION.BlessingOfMight, state.utility_target, {}) or false
end, function(_, state) return cast(ACTION.BlessingOfMight, state.utility_target, "[RET] Blessing of Might melee") end)

add_strategy(strategies, "Ret_BlessingKings_Party", 510, function(context, state)
    if not spec_kit.setting_bool(context, "blessing_of_kings_party", false) then return false end
    state.utility_target = find_ally(context, function(unit) return not unit_has_buff(unit, BLESSING_KINGS_BUFF) end)
    return state.utility_target ~= nil and NS.spell_ready(ACTION.BlessingOfKings, state.utility_target, {}) or false
end, function(_, state) return cast(ACTION.BlessingOfKings, state.utility_target, "[RET] Blessing of Kings party") end)

add_strategy(strategies, "Ret_SealCommand_AoE", 490, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    if state.mana_emergency then return false end
    local min_targets = spec_kit.setting_number(context, "command_cleave_min_targets", 2)
    return (state.enemy_count or 0) >= min_targets and not state.has_command and NS.spell_ready(ACTION.SealCommand, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.SealCommand, PLAYER, "[RET] Seal of Command cleave", { skip_range = true }) end)

add_strategy(strategies, "Ret_SealRighteousness_Filler", 470, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return not state.has_damage_seal and not state.has_wisdom and NS.spell_ready(ACTION.SealRighteousness, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.SealRighteousness, PLAYER, "[RET] Seal of Righteousness filler", { skip_range = true }) end)

add_strategy(strategies, "Ret_Judgement_RighteousnessFiller", 460, function(context, state)
    if not post_swing_judge_gate(context, state) then return false end
    return state.has_righteousness and (state.mana_pct or 0) >= 25 and NS.spell_ready(ACTION.Judgement, context.target, { skip_gcd = true, expected_cooldown = 10 }) or false
end, function(context) return cast(ACTION.Judgement, context.target, "[RET] Judge Righteousness filler", { skip_gcd = true, expected_cooldown = 10 }) end)

add_strategy(strategies, "Ret_SealCommand_Fallback", 450, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return not state.has_damage_seal and NS.spell_ready(ACTION.SealCommand, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.SealCommand, PLAYER, "[RET] Seal of Command fallback", { skip_range = true }) end)

add_strategy(strategies, "Ret_SealBlood_Fallback", 440, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return not state.has_damage_seal and NS.spell_ready(ACTION.SealBlood, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.SealBlood, PLAYER, "[RET] Seal of Blood fallback", { skip_range = true }) end)

add_strategy(strategies, "Ret_SealMartyr_Fallback", 435, function(context, state)
    if not seal_refresh_allowed(context) then return false end
    return not state.has_damage_seal and NS.spell_ready(ACTION.SealOfTheMartyr, PLAYER, { skip_range = true }) or false
end, function() return cast(ACTION.SealOfTheMartyr, PLAYER, "[RET] Seal of the Martyr fallback", { skip_range = true }) end)

add_strategy(strategies, "HitCapPriority", 430, function(context, state)
    if not state.hit_cap_rating_needed then return false end
    local hit_rating = context.hit_rating
    if not hit_rating then return false end
    local deficit = state.hit_cap_rating_needed - hit_rating
    if deficit <= 30 then return false end
    if NS.log then NS.log(string.format("[RET] Hit cap deficit %d — gating missable abilities", deficit)) end
    return true
end, function() return true end)

-- ============================================================================
-- Declarative Strategy DSL
-- ============================================================================
local DSL_DEFS = {
    {
        name = "Ret_DivineShield_Emergency",
        conditions = {
            { type = "custom", fn = function(context, state)
                local group_aware = spec_kit.setting_bool(context, "paladin_group_aware_defensives", true)
                local default_threshold = (group_aware and state.is_group) and 25 or 15
                local threshold = spec_kit.setting_number(context, "divine_shield_hp", spec_kit.setting_number(context, "retri_ds_hp", default_threshold))
                return (state.hp_pct or 100) <= threshold
            end },
            { type = "state", field = "has_forbearance", op = "==", value = false },
            { type = "spell_ready", spell = ACTION.DivineShield, target = "self", opts = { skip_range = true } },
        },
        action = { type = "cast", spell = ACTION.DivineShield, target = "self", opts = { skip_range = true }, label = "[RET] Divine Shield emergency" },
    },
    {
        name = "Ret_LayOnHands_LastResort",
        conditions = {
            { type = "custom", fn = function(context, state)
                local group_aware = spec_kit.setting_bool(context, "paladin_group_aware_defensives", true)
                local default_threshold = (group_aware and state.is_group) and 15 or 8
                local threshold = spec_kit.setting_number(context, "lay_on_hands_hp", default_threshold)
                return (state.hp_pct or 100) <= threshold
            end },
            { type = "spell_ready", spell = ACTION.LayOnHands, target = "self", opts = { skip_range = true, expected_cooldown = 3600 } },
        },
        action = { type = "cast", spell = ACTION.LayOnHands, target = "self", opts = { skip_range = true, expected_cooldown = 3600 }, label = "[RET] Lay on Hands last resort" },
    },
    {
        name = "Ret_SanctityAura",
        conditions = {
            { type = "custom", fn = function(context, state)
                return spec_kit.setting_bool(context, "sanctity_aura_enabled", spec_kit.setting_bool(context, "retri_aura_enabled", true))
            end },
            { type = "custom", fn = function(context, state) return not has_player_buff(SANCTITY_AURA_GATE_BUFF) end },
            { type = "spell_ready", spell = ACTION.SanctityAura, target = "self", opts = { skip_range = true } },
        },
        action = { type = "cast", spell = ACTION.SanctityAura, target = "self", opts = { skip_range = true }, label = "[RET] Sanctity Aura" },
    },
    {
        name = "Ret_HealthstoneOrPotion",
        conditions = {
            { type = "custom", fn = function(context, state)
                local group_aware = spec_kit.setting_bool(context, "paladin_group_aware_defensives", true)
                local default_threshold = (group_aware and state.is_group) and 45 or 35
                local threshold = spec_kit.setting_number(context, "healing_item_hp", default_threshold)
                return (state.hp_pct or 100) <= threshold
            end },
            { type = "custom", fn = function(context, state) return state.healing_item ~= nil end },
        },
        execute = function(context, state) return use_item(state.healing_item) end,
    },
    {
        name = "Ret_HammerWrath_Execute",
        conditions = {
            { type = "state", field = "target_hp_pct", op = "<", value = 20 },
            { type = "spell_ready", spell = HammerWrath, target = "target", opts = { expected_cooldown = 6 } },
        },
        action = { type = "cast", spell = HammerWrath, target = "target", opts = { expected_cooldown = 6 }, label = "[RET] Hammer of Wrath execute" },
    },
    {
        name = "Ret_Cleanse_Self",
        conditions = {
            { type = "custom", fn = function(context, state)
                return spec_kit.setting_bool(context, "use_cleanse", spec_kit.setting_bool(context, "retri_auto_cleanse", true))
            end },
            { type = "custom", fn = function(context, state) return has_player_debuff(COMMON_CLEANSE) end },
            { type = "spell_ready", spell = ACTION.Cleanse, target = "self", opts = { skip_range = true } },
        },
        action = { type = "cast", spell = ACTION.Cleanse, target = "self", opts = { skip_range = true }, label = "[RET] Cleanse self" },
    },
    {
        name = "Ret_SealCommand_Primary",
        conditions = {
            { type = "custom", fn = function(context, state) return seal_refresh_allowed(context) end },
            { type = "state", field = "preferred_damage_seal", op = "==", value = "command" },
            { type = "state", field = "has_command", op = "==", value = false },
            { type = "spell_ready", spell = ACTION.SealCommand, target = "self", opts = { skip_range = true } },
        },
        action = { type = "cast", spell = ACTION.SealCommand, target = "self", opts = { skip_range = true }, label = "[RET] Seal of Command primary" },
    },
}

-- Replace imperative strategies with DSL-compiled equivalents.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

apply_base_matches(strategies, ACTIONS)

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("retribution", strategies, { get_state = build_state })
end
if NS.log then NS.log("Paladin retribution rotation registered") end
return { strategies = strategies, build_state = build_state }

