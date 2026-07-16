-- test_protection_vanilla_strategies.lua — Protection Vanilla strategy match coverage.
-- WHAT:  Exercises Execute stance gate / ShieldWall HP gate / Revenge stance gate.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for warrior protection vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    WarriorSpells = {
        Execute = 5308, BattleShout = 6673, ShieldSlam = 23922, Revenge = 6572,
        ShieldBlock = 2565, Taunt = 355, MockingBlow = 694, ChallengingShout = 1161,
        ShieldBash = 72, LastStand = 12975, ShieldWall = 871, SunderArmor = 7386,
        DemoralizingShout = 1160, ThunderClap = 6343, HeroicStrike = 78, Cleave = 845,
        Pummel = 6552, Disarm = 676, Hamstring = 1715, Intercept = 20252,
        BerserkerRage = 18499, Bloodrage = 2687, Rend = 772, IntimidatingShout = 5246,
        BattleStance = 2457, BerserkerStance = 2458, DefensiveStance = 71,
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
        BATTLE_SHOUT_IDS = { 11551, 11550, 11549, 6192, 5242, 6673 },
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {} end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    debuff_remains = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    is_execute_phase = function(hp, t) return (hp or 100) <= (t or 20) end,
    is_interruptible = function() return true end,
    broken_api_throttled = function() return false end,
    time_now = function() return 0 end,
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/spec_kit_sylvanas"] = {
    setting = function(_, _, d) return d end,
    setting_bool = function(_, _, d) return d end,
    setting_number = function(_, _, d) return d end,
    define_action_for_class = function()
        return function(name, ids) return type(ids) == "table" and ids[1] or ids end
    end,
    safe_state = function(s) return s end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
}

local strategies = dofile("EaxRotations/classes/warrior/protection_vanilla.lua")
if type(strategies) == "table" and strategies.strategies then strategies = strategies.strategies end
assert_true(type(strategies) == "table" and #strategies > 0, "protection_vanilla strategies load")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local execute = find("Execute")
local shield_wall = find("ShieldWall")
local revenge = find("Revenge")

-- Execute: requires Battle/Berserker stance + execute HP
assert_false(execute.matches({ target = {}, target_hp = 50, stance = 1, settings = {} }),
    "Prot Execute must not match above 20% HP")
assert_false(execute.matches({ target = {}, target_hp = 15, stance = 2, settings = {} }),
    "Prot Execute must not match in Defensive stance")
assert_true(execute.matches({ target = {}, target_hp = 15, stance = 1, settings = {} }),
    "Prot Execute matches in Battle stance at execute HP")
assert_true(execute.matches({ target = {}, target_hp = 10, stance = 3, settings = {} }),
    "Prot Execute matches in Berserker stance at execute HP")

-- ShieldWall: only at low HP (LOW_HP_LIMIT = 35)
assert_false(shield_wall.matches({ target = {}, hp = 80, me = {}, settings = {} }),
    "ShieldWall must not match at high HP")
assert_true(shield_wall.matches({ target = {}, hp = 20, me = {}, settings = {} }),
    "ShieldWall matches at low HP")

-- Revenge: defensive stance + ready (build_state sets revenge_ready via spell_ready)
assert_true(revenge.matches({ target = {}, stance = 2, me = {}, settings = {} }),
    "Revenge matches in Defensive stance when ready")
assert_false(revenge.matches({ target = {}, stance = 1, me = {}, settings = {} }),
    "Revenge must not match outside Defensive stance")

print("PASS test_protection_vanilla_strategies")
