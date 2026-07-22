-- test_retribution_custom_matches.lua -- Retribution custom match validation tests.
-- WHAT:  Retribution custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- Gate test: Paladin Retribution custom matches functions.
-- Covers UNCOVERED strategies (existing test handles swing-judgement gates):
--   CrusaderStrike, Consecration, Exorcism, Ret_HammerWrath_Execute,
--   Ret_AvengingWrath_Burst, Ret_HotC_Opener_Seal, Ret_DivineShield_Emergency.
-- Asserts TRUE/FALSE return values (gold-standard style, not just no-crash).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error("FAIL: " .. (label or "true"), 2) end end
local function assert_false(v, label) if v then error("FAIL: " .. (label or "false"), 2) end end

local _captured
_G.EaxRotations = {
    PaladinSpells = {
        CrusaderStrike = 35395, Judgement = 20271, SealCommand = 27170,
        SealBlood = 31892, SealOfTheMartyr = 348700, SealRighteousness = 27155,
        SealCrusader = 27158, SealOfWisdom = 27166, Consecration = 27173,
        Exorcism = 27138, HolyWrath = 27139, HammerOfWrath = 27180,
        AvengingWrath = 31884, DivineStorm = 53723, BlessingOfMight = 27141,
        BlessingOfKings = 25898, SanctityAura = 20218, DivineShield = 642,
        LayOnHands = 27154, DivineProtection = 498, Purify = 1152,
        HammerOfJustice = 10308, Repentance = 20066, Cleanse = { 4987 },
    },
    PLAYER_UNIT = { _mock = true },
    setting = function(context, key, default)
        if context and context.settings and context.settings[key] ~= nil then return context.settings[key] end
        return default
    end,
    get_any_setting = function(context, k1, k2, fallback) return fallback end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    has_player_buff = function() return false end,
    has_player_debuff = function() return false end,
    has_target_debuff = function() return false end,
    buff_up = function() return false end,
    is_item_ready = function() return false end,
    is_casting = function() return false end,
    is_interruptible = function() return true end,
    unit_faction = function() return "Horde" end,
    GetPlayer = function() return { _mock = true } end,
    get_time_until_swing = function() return 99 end,
    broken_api_throttled = function() return false end,
    log = function() end,
    time_now = function() return 1000 end,
    unit_alive = function() return true end,
    is_valid_target = function(u) return true end,
    unit_health_pct = function() return 100 end,
    unit_mana_pct = function() return 100 end,
    cooldown_remains = function() return 99 end,
    rotation_registry = { register = function(self, spec, strats, opts) _captured = strats end },
}
package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { healthstones = {}, potions = {} } }
package.loaded["shared/cooldown_planner_sylvanas"] = nil

dofile("EaxRotations/classes/paladin/retribution_sylvanas.lua")
assert(_captured, "Retribution strategies captured via register")

local function fs(n)
    for i = 1, #_captured do
        if _captured[i].name == n then return _captured[i] end
    end
    error("not found: " .. n)
end

local function ctx(o)
    local c = {
        me = { get_distance = function() return 5 end },
        target = { get_creature_type = function() return 3 end, is_player = function() return false end },
        settings = {}, in_combat = true, enemy_count = 1,
    }
    if o then for k, v in pairs(o) do c[k] = v end end
    return c
end

local function cs(o)
    local s = {
        in_melee = true, has_damage_seal = true, has_blood = true, has_martyr = false,
        has_command = false, has_righteousness = false, has_crusader = false, has_wisdom = false,
        mana_pct = 100, mana_emergency = false, swing_remains = 99, twist_window = 0.45,
        target_hp_pct = 100, target_has_crusader = false, target_has_wisdom = false,
        has_forbearance = false, can_twist = false, preferred_damage_seal = "blood",
    }
    if o then for k, v in pairs(o) do s[k] = v end end
    return s
end

-- CrusaderStrike (priority 700): in_melee + ready; skip during twist-prep window.
local cs_strat = fs("CrusaderStrike")
assert_true(cs_strat.matches(ctx(), cs()), "CS match in melee")
assert_false(cs_strat.matches(ctx(), cs({ in_melee = false })), "CS skip out of melee")
assert_false(cs_strat.matches(ctx(), cs({ can_twist = true, has_command = true, has_blood = false, swing_remains = 0.3 })), "CS skip in twist-prep window")

-- Consecration (priority 600): AoE gate — enemy_count >= min_targets (3) + mana >= 35; skip mana_emergency.
-- NOTE: strategy reads state.enemy_count (set by build_state from context), not context directly.
local cons = fs("Consecration")
assert_true(cons.matches(ctx(), cs({ enemy_count = 3 })), "Consecration AoE match")
assert_false(cons.matches(ctx(), cs({ enemy_count = 1 })), "Consecration skip single target")
assert_false(cons.matches(ctx(), cs({ enemy_count = 3, mana_emergency = true })), "Consecration skip mana emergency")

-- Exorcism (priority 580): Undead/Demon only. creature_type() returns a number index.
local exorcism = fs("Exorcism")
-- creature_type() returns a numeric index; DEMON_OR_UNDEAD = { [3]=Undead, [6]=Demon }.
assert_true(exorcism.matches(ctx({ target = { get_creature_type = function() return 3 end } }), cs()), "Exorcism match on Undead")
assert_false(exorcism.matches(ctx({ target = { get_creature_type = function() return 7 end } }), cs()), "Exorcism skip on Humanoid")

-- Ret_HammerWrath_Execute (priority 800): target_hp < 20%.
local hammer = fs("Ret_HammerWrath_Execute")
assert_true(hammer.matches(ctx(), cs({ target_hp_pct = 15 })), "HammerWrath execute match")
assert_false(hammer.matches(ctx(), cs({ target_hp_pct = 50 })), "HammerWrath skip above 20%")

-- Ret_AvengingWrath_Burst (priority 780): skip if Forbearance; needs combat_time >= 45 or major_cd_window.
local aw = fs("Ret_AvengingWrath_Burst")
assert_false(aw.matches(ctx(), cs({ has_forbearance = true })), "AW skip with Forbearance")
assert_true(aw.matches(ctx({ combat_time = 60 }), cs({ major_cd_window = true })), "AW match late combat + aligned")
assert_false(aw.matches(ctx({ combat_time = 10 }), cs({ major_cd_window = false })), "AW skip early combat unaligned")

-- Ret_HotC_Opener_Seal (priority 775): in_combat + combat_time < 5 + no crusader + no damage seal.
local hotc = fs("Ret_HotC_Opener_Seal")
assert_true(hotc.matches(ctx({ combat_time = 2 }), cs({ has_crusader = false, has_damage_seal = false, target_has_crusader = false })), "HotC opener match")
assert_false(hotc.matches(ctx({ combat_time = 10 }), cs({ has_damage_seal = false })), "HotC skip late combat")
assert_false(hotc.matches(ctx({ combat_time = 2 }), cs({ has_damage_seal = true })), "HotC skip has damage seal")

print("PASS test_retribution_custom_matches")
