-- test_arms_vanilla_strategies.lua — Arms Vanilla strategy match coverage.
-- WHAT:  Exercises Execute / Rend / MortalStrike match gates on arms_vanilla.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for warrior arms vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    WarriorSpells = {
        Execute = 5308, BattleShout = 6673, MortalStrike = 12294, Overpower = 7384,
        Whirlwind = 1680, HeroicStrike = 78, Hamstring = 1715, Charge = 100,
        Cleave = 845, BerserkerRage = 18499, DeathWish = 12292, Bloodrage = 2687,
        Slam = 1464, SunderArmor = 7386, DemoralizingShout = 1160, ThunderClap = 6343,
        Intercept = 20252, Pummel = 6552, Recklessness = 1719, Retaliation = 20230,
        ShieldWall = 871, IntimidatingShout = 5246, Disarm = 676, PiercingHowl = 12323,
        SweepingStrikes = 12292, Rend = 772, BattleStance = 2457, BerserkerStance = 2458,
        DefensiveStance = 71,
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
        BUFF_ID = { SWEEPING_STRIKES = 12292 },
        SUNDER_DEBUFF = { 11597, 11596, 8380, 7405, 7386 },
        THUNDER_CLAP_DEBUFF = { 11581, 11580, 8205, 8204, 8198, 6343 },
        DEMO_SHOUT_DEBUFF = { 11556, 11555, 11554, 6190, 1160 },
        BATTLE_SHOUT_IDS = { 11551, 11550, 11549, 6192, 5242, 6673 },
        SUNDER_MAX_STACKS = 5, SUNDER_REFRESH_WINDOW = 3, TC_REFRESH_WINDOW = 2,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return { get_class = function() return 1 end } end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    debuff_stacks = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    cooldown_remains = function() return 0 end,
    is_execute_phase = function(hp, t) return (hp or 100) <= (t or 20) end,
    is_interruptible = function() return true end,
    broken_api_throttled = function() return false end,
    swing_time_until = function() return 999 end,
    swing_progress = function() return 0 end,
    time_now = function() return 0 end,
    setting = function(ctx, key, default)
        local s = ctx and ctx.settings
        if s and s[key] ~= nil then return s[key] end
        return default
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/spec_kit_sylvanas"] = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
    setting = function(ctx, key, default)
        local s = ctx and ctx.settings
        if s and s[key] ~= nil then return s[key] end
        return default
    end,
    setting_bool = function(ctx, key, default)
        local s = ctx and ctx.settings
        if s and s[key] ~= nil then return s[key] end
        return default
    end,
    setting_number = function(ctx, key, default)
        local s = ctx and ctx.settings
        if s and s[key] ~= nil then return s[key] end
        return default
    end,
    define_action_for_class = function()
        return function(name, ids) return type(ids) == "table" and ids[1] or ids end
    end,
    safe_state = function(s) return s end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
}

local strategies = dofile("EaxRotations/classes/warrior/arms_vanilla.lua")
if type(strategies) == "table" and strategies.strategies then strategies = strategies.strategies end
assert_true(type(strategies) == "table" and #strategies > 0, "arms_vanilla strategies load")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local execute = find("Execute")
local rend = find("Rend")
local ms = find("MortalStrike")

-- Execute: only in execute phase with enough rage
assert_false(execute.matches({ target = {}, target_hp = 50, rage = 50, stance = 1, settings = {} }),
    "Execute must not match above 20% HP")
assert_false(execute.matches({ target = {}, target_hp = 15, rage = 10, stance = 1, settings = {} }),
    "Execute must not match with rage below execute_phase_rage default")
assert_true(execute.matches({ target = {}, target_hp = 15, rage = 40, stance = 1, settings = {} }),
    "Execute matches in execute with sufficient rage")

-- Rend: skipped in execute and when remains high
assert_false(rend.matches({ target = {}, target_hp = 15, rage = 40, stance = 1, settings = {} }),
    "Rend must not match in execute phase")
assert_true(rend.matches({ target = {}, target_hp = 80, rage = 40, stance = 1, settings = {} }),
    "Rend matches outside execute with target present")

-- Mortal Strike present and callable without crash under combat context
assert_true(ms.matches({ target = {}, target_hp = 80, rage = 40, stance = 1, settings = {} }) == true
    or ms.matches({ target = {}, target_hp = 80, rage = 40, stance = 1, settings = {} }) == false,
    "MortalStrike matches returns boolean")

print("PASS test_arms_vanilla_strategies")
