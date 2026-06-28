-- test_paladin_retribution_post_swing_judge.lua — Post-Swing Judgement gate.
-- WHAT:  verifies that Judgement strategies are gated by swing timer to avoid clipping.
-- WHEN:  regression guard for retribution_sylvanas.lua post_swing_judge logic.
-- WHY:   judging before a swing delays the auto-attack; we wait until after swing.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

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
    get_any_setting = function(context, k1, k2, fallback) return fallback end,
    spell_ready = function(spell, target, opts) return true end,
    try_cast = function(spell, target, tag, opts) return true end,
    has_player_buff = function(ids) return false end,
    has_player_debuff = function(ids) return false end,
    has_target_debuff = function(unit, ids) return false end,
    buff_up = function(unit, ids) return false end,
    is_item_ready = function(id) return false end,
    is_casting = function(unit) return false end,
    is_interruptible = function(unit) return true end,
    unit_faction = function(unit) return "Horde" end,
    GetPlayer = function() return { _mock = true } end,
    get_time_until_swing = function() return 99 end,
    broken_api_throttled = function() return false end,
    log = function() end,
    time_now = function() return 1000 end,
    unit_alive = function(u) return true end,
    unit_health_pct = function(u) return 100 end,
    unit_mana_pct = function(u) return 100 end,
    cooldown_remains = function(spell) return 99 end,
    rotation_registry = { register = function(self, spec, strategies, opts)
        _captured_strategies = strategies
    end },
}

package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { healthstones = {}, potions = {} } }

dofile("EaxRotations/classes/paladin/retribution_sylvanas.lua")

local function find_strategy(name)
    for i = 1, #_captured_strategies do
        if _captured_strategies[i].name == name then return _captured_strategies[i] end
    end
    return nil
end

local function ctx()
    return { me = { get_distance = function() return 5 end }, target = { get_creature_type = function() return 3 end, is_player = function() return false end }, settings = {}, in_combat = true, enemy_count = 1 }
end

local function base_state(overrides)
    local s = { has_damage_seal = true, has_blood = true, has_martyr = false, has_command = false, has_righteousness = false, has_crusader = false, has_wisdom = false, in_melee = true, mana_pct = 100, mana_emergency = false, swing_remains = 99, twist_window = 0.45, target_has_crusader = false, target_has_wisdom = false }
    if overrides then for k, v in pairs(overrides) do s[k] = v end end
    return s
end

local judge_ds = find_strategy("Ret_JudgeDamageSeal")
assert_true(judge_ds, "Ret_JudgeDamageSeal should exist")

-- C1: swing_remains < 0.3s -> blocked
assert_false(judge_ds.matches(ctx(), base_state({ swing_remains = 0.1 })),
    "C1: swing 0.1s -> blocked")
print("  [ PASS ] C1: swing < 0.3s blocks judgement")

-- C2: swing_remains > 1.5s -> allowed
assert_true(judge_ds.matches(ctx(), base_state({ swing_remains = 2.0 })),
    "C2: swing 2.0s -> allowed")
print("  [ PASS ] C2: swing > 1.5s allows judgement")

-- C3: post_swing disabled -> always allowed (setting = false)
local ctx_disabled = { me = { get_distance = function() return 5 end }, target = { get_creature_type = function() return 3 end, is_player = function() return false end }, settings = { retri_post_swing_judge = false }, in_combat = true, enemy_count = 1 }
local c3_state = base_state({ swing_remains = 0.1 })
-- Verify mock works
local NS2 = _G.EaxRotations
local mock_val = NS2.setting(ctx_disabled, "retri_post_swing_judge", true)
assert_false(mock_val, "mock should return false for retri_post_swing_judge=false")
local c3_result = judge_ds.matches(ctx_disabled, c3_state)
assert_true(c3_result, "C3: post-swing disabled -> allowed even at 0.1s")
print("  [ PASS ] C3: disabled gate allows judgement near swing")

-- C4: JudgeCrusader also gated
local judge_crusader = find_strategy("Ret_JudgeCrusader")
assert_true(judge_crusader, "Ret_JudgeCrusader should exist")
assert_false(judge_crusader.matches(ctx(), base_state({ swing_remains = 0.2, has_crusader = true })),
    "C4: JudgeCrusader blocked near swing")
print("  [ PASS ] C4: JudgeCrusader blocked near swing")

-- C5: JudgeWisdom also gated
local judge_wisdom = find_strategy("Ret_JudgementWisdom_LowMana")
assert_true(judge_wisdom, "Ret_JudgementWisdom_LowMana should exist")
assert_false(judge_wisdom.matches(ctx(), base_state({ swing_remains = 0.2, has_wisdom = true, mana_pct = 10 })),
    "C5: JudgeWisdom blocked near swing")
print("  [ PASS ] C5: JudgeWisdom blocked near swing")

print("PASS test_paladin_retribution_post_swing_judge")
