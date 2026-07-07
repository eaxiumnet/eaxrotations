-- test_paladin_retribution_seal_ooc.lua — Out-of-combat seal refresh gate.
-- WHAT: verifies the seal_refresh_ooc option gates seal-applying strategies out of combat
--       (town/traveling) when unchecked, while preserving in-combat + default behaviour.
-- SAFETY: bypasses build_state with crafted state tables; mocks NS minimally.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end

local F = function() return false end
local T = function() return true end
local _captured_strategies
_G.EaxRotations = {
    PaladinSpells = {
        CrusaderStrike = 35395, Judgement = 20271, SealCommand = 27170,
        SealBlood = 31892, SealOfTheMartyr = 348700, SealRighteousness = 27155,
        SealCrusader = 27158, SealOfWisdom = 27166, Consecration = 27173,
        Exorcism = 27138, HolyWrath = 27139, HammerOfWrath = 27180,
        AvengingWrath = 31884, DivineStorm = 53723, BlessingOfMight = 27141,
        BlessingOfKings = 25898, SanctityAura = 20218, DivineShield = 642,
        LayOnHands = 27154, DivineProtection = 498, Purify = 1152,
        HammerOfJustice = 10308, Repentance = 20066, Cleanse = {4987},
    },
    PLAYER_UNIT = { _mock = true },
    setting = function(context, key, default)
        if context and context.settings and context.settings[key] ~= nil then return context.settings[key] end
        return default
    end,
    get_any_setting = function(context, k1, k2, fallback)
        local s = context and context.settings or {}
        if k1 and s[k1] ~= nil then return s[k1] end
        if k2 and s[k2] ~= nil then return s[k2] end
        return fallback
    end,
    spell_ready = T, try_cast = T, is_interruptible = T, unit_alive = T,
    has_player_buff = F, has_player_debuff = F, has_target_debuff = F,
    buff_up = F, is_item_ready = F, is_casting = F, broken_api_throttled = F,
    unit_faction = function() return "Horde" end,
    GetPlayer = function() return { _mock = true } end,
    get_time_until_swing = function() return 99 end,
    log = function() end,
    time_now = function() return 1000 end,
    unit_health_pct = function() return 100 end,
    unit_mana_pct = function() return 100 end,
    cooldown_remains = function() return 99 end,
    rotation_registry = { register = function(self, spec, strategies, opts) _captured_strategies = strategies end },
}

package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { healthstones = {}, potions = {} } }
dofile("EaxRotations/classes/paladin/retribution_sylvanas.lua")

local function find_strategy(name)
    for i = 1, #_captured_strategies do
        if _captured_strategies[i].name == name then return _captured_strategies[i] end
    end
    return nil
end

local SEAL_STRATEGIES = {
    "SealTwistBlood", "SealTwistPrepCommand", "Ret_ApplyCrusaderSeal",
    "Ret_SealCommand_Primary", "Ret_SealCommand_AoE", "Ret_SealRighteousness_Filler",
    "Ret_SealCommand_Fallback", "Ret_SealMartyr_Fallback",
}

-- Per-strategy state that makes the NON-gate conditions TRUE, so the only variable
-- under test is the seal_refresh_allowed() gate.
local function matching_state(name)
    local s = {
        has_damage_seal = false, has_blood = false, has_martyr = false,
        has_command = false, has_command_rank1 = false, has_crusader = false,
        has_righteousness = false, has_wisdom = false, has_might = false, has_kings = false,
        target_has_crusader = false, target_has_wisdom = false,
        preferred_damage_seal = "command", can_use_blood = true,
        in_melee = true, mana_pct = 100, mana_emergency = false,
        enemy_count = 3, swing_remains = 99, twist_window = 0.45, can_twist = true,
    }
    if name == "SealTwistBlood" then s.has_command = true; s.has_blood = false; s.swing_remains = 0.3
    elseif name == "SealTwistPrepCommand" then s.swing_remains = 0.8; s.can_use_blood = true end
    return s
end

local function ctx(settings_tbl, in_combat)
    return {
        me = { get_distance = function() return 5 end },
        target = { get_creature_type = function() return 3 end, is_player = function() return false end },
        settings = settings_tbl or {}, in_combat = in_combat, enemy_count = 3,
    }
end

print("--- Ret out-of-combat seal refresh gate (seal_refresh_ooc) ---")
for _, name in ipairs(SEAL_STRATEGIES) do
    assert_true(find_strategy(name) ~= nil, name .. " strategy should exist")
end
print("  [ PASS ] all gated seal strategies registered")

-- C1: in combat -> seals maintained regardless of option.
local c1 = ctx({ seal_refresh_ooc = false }, true)
for _, name in ipairs(SEAL_STRATEGIES) do
    assert_true(find_strategy(name).matches(c1, matching_state(name)),
        "C1: " .. name .. " should match in combat even with seal_refresh_ooc=false")
end
print("  [ PASS ] C1: in combat, seals maintained even when option off")

-- C2: out of combat + option OFF -> every seal strategy blocked.
local c2 = ctx({ seal_refresh_ooc = false }, false)
for _, name in ipairs(SEAL_STRATEGIES) do
    assert_false(find_strategy(name).matches(c2, matching_state(name)),
        "C2: " .. name .. " should NOT match out of combat when seal_refresh_ooc=false")
end
print("  [ PASS ] C2: out of combat + option off -> no seal recast")

-- C3: out of combat + default (true) -> seals maintained (backward compatible).
local c3 = ctx({}, false)
for _, name in ipairs(SEAL_STRATEGIES) do
    assert_true(find_strategy(name).matches(c3, matching_state(name)),
        "C3: " .. name .. " should match out of combat by default")
end
print("  [ PASS ] C3: out of combat + default -> seals maintained (backward compatible)")

-- C4: out of combat + option ON -> seals maintained.
local c4 = ctx({ seal_refresh_ooc = true }, false)
for _, name in ipairs(SEAL_STRATEGIES) do
    assert_true(find_strategy(name).matches(c4, matching_state(name)),
        "C4: " .. name .. " should match out of combat when seal_refresh_ooc=true")
end
print("  [ PASS ] C4: out of combat + option on -> seals maintained")

print("PASS test_paladin_retribution_seal_ooc")
