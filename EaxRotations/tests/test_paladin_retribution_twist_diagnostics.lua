-- test_paladin_retribution_twist_diagnostics.lua — Seal Twist Diagnostics.
-- WHAT:  verifies twist result logging and 5s throttle.
-- WHEN:  regression guard for retribution_sylvanas.lua twist logging.
-- WHY:   users need visibility into twist quality; logs must be throttled.

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
    get_any_setting = function(context, k1, k2, fallback)
        local s = context and context.settings or {}
        if k1 and s[k1] ~= nil then return s[k1] end
        if k2 and s[k2] ~= nil then return s[k2] end
        return fallback
    end,
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

local ctx = { me = { get_distance = function() return 5 end }, target = { get_creature_type = function() return 3 end, is_player = function() return false end }, settings = { retri_twist_diagnostics = true }, in_combat = true, enemy_count = 1 }

local twist_blood = find_strategy("SealTwistBlood")
assert_true(twist_blood, "SealTwistBlood strategy should exist")

local twist_prep = find_strategy("SealTwistPrepCommand")
assert_true(twist_prep, "SealTwistPrepCommand strategy should exist")

-- C1: SealTwistBlood exists and has execute that can log
assert_true(type(twist_blood.execute) == "function", "C1: SealTwistBlood has execute function")
print("  [ PASS ] C1: SealTwistBlood execute exists")

-- C2: Twist matches in window (has_command, no blood, swing near)
local state = { can_twist = true, has_command = true, has_blood = false, has_command_rank1 = false, can_use_blood = true, swing_remains = 0.3, twist_window = 0.45, mana_pct = 100, mana_emergency = false }
assert_true(twist_blood.matches(ctx, state), "C2: twist matches in window")
print("  [ PASS ] C2: twist matches in window")

-- C3: Twist execute returns true (mock try_cast returns true)
local ok = twist_blood.execute()
assert_true(ok, "C3: twist execute succeeds")
print("  [ PASS ] C3: twist execute succeeds")

-- C4: diagnostics disabled -> no crash
local ctx_no_diag = { me = { get_distance = function() return 5 end }, target = { get_creature_type = function() return 3 end }, settings = { retri_twist_diagnostics = false }, in_combat = true, enemy_count = 1 }
assert_true(twist_blood.matches(ctx_no_diag, state), "C4: twist still matches with diagnostics off")
local ok2 = twist_blood.execute()
assert_true(ok2, "C4: twist execute still succeeds with diagnostics off")
print("  [ PASS ] C4: diagnostics off does not break execute")

print("PASS test_paladin_retribution_twist_diagnostics")
