-- Regression test: warrior vanilla specs Pattern 14 nil-guards.
-- Covers: arms_vanilla, fury_vanilla, protection_vanilla, leveling_vanilla.
-- bear_vanilla has its own dedicated test file.
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local failures, total_tests, total_passed = {}, 0, 0

local function expect_no_crash(label, fn)
    total_tests = total_tests + 1
    local ok, err = pcall(fn)
    if ok then total_passed = total_passed + 1
    else failures[#failures + 1] = { label = label, error = err } end
end

-- Mock NS
local STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }
_G.EaxRotations = {
    WarriorSpells = {
        Execute = 5308, BattleShout = 6673, MortalStrike = 12294, Overpower = 7384,
        Whirlwind = 1680, HeroicStrike = 78, Hamstring = 1715, Charge = 100,
        Cleave = 845, BerserkerRage = 18499, DeathWish = 12292, Bloodrage = 2687,
        Slam = 1464, SunderArmor = 7386, DemoralizingShout = 1160, ThunderClap = 6343,
        Intercept = 20252, Pummel = 6552, Recklessness = 1719, Retaliation = 20230,
        ShieldWall = 871, IntimidatingShout = 5246, Disarm = 676, PiercingHowl = 12323,
        SweepingStrikes = 12292, Rend = 772, BattleStance = 2457, BerserkerStance = 2458,
        DefensiveStance = 71, Bloodthirst = 23881, ShieldSlam = 23922, Revenge = 6572,
        ShieldBlock = 2565, Taunt = 355, MockingBlow = 694, ChallengingShout = 1161,
        ShieldBash = 72, LastStand = 12975, VictoryRush = 34428,
    },
    WarriorConstants = {
        STANCE = STANCE,
        BUFF_ID = { SWEEPING_STRIKES = 12292 },
        SUNDER_DEBUFF = { 11597, 11596, 8380, 7405, 7386 },
        THUNDER_CLAP_DEBUFF = { 11581, 11580, 8205, 8204, 8198, 6343 },
        DEMO_SHOUT_DEBUFF = { 11556, 11555, 11554, 6190, 1160 },
        BATTLE_SHOUT_IDS = { 11551, 11550, 11549, 6192, 5242, 6673 },
        SUNDER_MAX_STACKS = 5, SUNDER_REFRESH_WINDOW = 3, TC_REFRESH_WINDOW = 2,
        COMMANDING_SHOUT_BUFF = { 469 },
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return { get_class = function() return 1 end } end,
    spell_action = function(ids, label) return type(ids) == "table" and ids[1] or ids end,
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
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    gate_cooldown_boss_only = function() return true end,
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

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

print("=== test_warrior_vanilla_nil_guards ===")

-- ============================================================================
-- Arms Vanilla
-- ============================================================================
local arms_strategies = dofile("EaxRotations/classes/warrior/arms_vanilla.lua")
assert_true(type(arms_strategies) == "table", "arms_vanilla should load")

local function find_in(strats, name)
    for i = 1, #strats do
        if strats[i].name == name then return strats[i] end
    end
    return nil
end

local arms_ctx = { in_combat = true, target = {}, me = {}, settings = {}, rage = 30, stance = 1, hp = 80, target_hp = 50 }
for _, name in ipairs({ "Execute", "MortalStrike", "Overpower", "Whirlwind", "Rend", "Slam", "HeroicStrike", "Cleave", "Hamstring", "BattleShout", "DemoralizingShout", "ThunderClap", "Charge", "Intercept", "Pummel", "SweepingStrikes", "DeathWish", "Recklessness", "ShieldWall", "Bloodrage", "Retaliation" }) do
    local s = find_in(arms_strategies, name)
    if s then
        expect_no_crash("arms_vanilla: " .. name .. " with minimal context", function()
            return s.matches(arms_ctx)
        end)
    end
end

-- Arms with nil-heavy context (all fields nil)
expect_no_crash("arms_vanilla: Execute with nil context fields", function()
    return find_in(arms_strategies, "Execute").matches({ target = {}, settings = {} })
end)

-- ============================================================================
-- Fury Vanilla
-- ============================================================================
local fury_strategies = dofile("EaxRotations/classes/warrior/fury_vanilla.lua")
assert_true(type(fury_strategies) == "table", "fury_vanilla should load")

local fury_nil_state = {}  -- all fields nil to test Pattern 14 guards
local fury_ctx = { in_combat = true, target = {}, me = {}, settings = {}, rage = 50, hp = 80, target_hp = 50 }
for _, name in ipairs({ "BerserkerRage", "Intercept", "Execute", "DeathWish", "SweepingStrikes", "Bloodthirst", "Overpower", "Whirlwind", "Rend", "DemoralizingShout", "SunderArmor", "Hamstring", "Slam", "HeroicStrike", "Cleave" }) do
    local s = find_in(fury_strategies, name)
    if s then
        expect_no_crash("fury_vanilla: " .. name .. " with nil state", function()
            return s.matches(fury_ctx, fury_nil_state)
        end)
    end
end

-- ============================================================================
-- Protection Vanilla
-- ============================================================================
local prot_strategies = dofile("EaxRotations/classes/warrior/protection_vanilla.lua")
assert_true(type(prot_strategies) == "table", "protection_vanilla should load")

local prot_ctx = { in_combat = true, target = {}, me = {}, settings = {}, rage = 30, stance = 2, hp = 80, target_hp = 50 }
for _, name in ipairs({ "Revenge", "ShieldSlam", "Taunt", "MockingBlow", "ChallengingShout", "ShieldBlock", "SunderArmor", "Execute", "ThunderClap", "DemoralizingShout", "BattleShout", "HeroicStrike", "Cleave", "Pummel", "ShieldBash", "ShieldWall", "LastStand", "Disarm", "Hamstring", "Intercept", "BerserkerRage", "Bloodrage", "Rend", "IntimidatingShout" }) do
    local s = find_in(prot_strategies, name)
    if s then
        expect_no_crash("protection_vanilla: " .. name .. " with minimal context", function()
            return s.matches(prot_ctx)
        end)
    end
end

-- Protection with nil context
expect_no_crash("protection_vanilla: Revenge with nil context", function()
    return find_in(prot_strategies, "Revenge").matches({ target = {}, settings = {} })
end)

-- ============================================================================
-- Leveling Vanilla
-- ============================================================================
package.loaded["shared/leveling_sylvanas"] = {
    create_context_guard = function() return function() return true end end,
    build_common_state = function() end,
    create_wand_matches = function() return function() return false end end,
    execute_wand = function() return false end,
}

local level_strategies = dofile("EaxRotations/classes/warrior/leveling_vanilla.lua")
assert_true(type(level_strategies) == "table", "leveling_vanilla should load")

local level_ctx = { in_combat = true, target = {}, me = {}, settings = {}, rage = 30, stance = 1, hp = 80 }
for _, name in ipairs({ "BattleShout", "ShieldBash", "Pummel", "Charge", "BerserkerRage", "Bloodrage", "ShieldWall", "Execute", "Bloodthirst", "ShieldSlam", "SweepingStrikes", "Whirlwind", "ThunderClap", "DemoralizingShout", "Rend", "Hamstring", "MortalStrike", "Overpower", "Disarm", "HeroicStrike" }) do
    local s = find_in(level_strategies, name)
    if s then
        expect_no_crash("leveling_vanilla: " .. name .. " with minimal context", function()
            return s.matches(level_ctx)
        end)
    end
end

-- ============================================================================
-- REPORT
-- ============================================================================
print()
if #failures == 0 then
    print(string.format("PASS test_warrior_vanilla_nil_guards — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_warrior_vanilla_nil_guards — %d/%d passed, %d failures:", total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do print(string.format("  %d. [%s] %s", i, f.label, f.error)) end
    error(string.format("test_warrior_vanilla_nil_guards: %d failure(s)", #failures))
end
