-- test_warrior_arms_wotlk.lua — WotLK Arms warrior registration and nil-guard tests.
-- WHAT:  Validates the WotLK Arms prototype spec loads, registers, and handles nil state safely.
-- WHEN:  During WotLK test suite execution.
-- WHY:   Regression guard for the first WotLK spec.
-- SAFETY: Must pass after any state table change.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
local failures, total_tests, total_passed = {}, 0, 0

local function expect_no_crash(label, fn)
    total_tests = total_tests + 1
    local ok, err = pcall(fn)
    if ok then total_passed = total_passed + 1
    else failures[#failures + 1] = { label = label, error = err } end
end

local STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

local registered = {}

local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

_G.EaxRotations = {
    WarriorSpells = {
        BattleStance = make_action(2457, "BattleStance"),
        BerserkerStance = make_action(2458, "BerserkerStance"),
        BattleShout = make_action(47436, "BattleShout"),
        CommandingShout = make_action(47439, "CommandingShout"),
        Charge = make_action(11578, "Charge"),
        Rend = make_action(47465, "Rend"),
        MortalStrike = make_action(47486, "MortalStrike"),
        Overpower = make_action(11585, "Overpower"),
        Execute = make_action(47498, "Execute"),
        Bladestorm = make_action(46924, "Bladestorm"),
        SweepingStrikes = make_action(12328, "SweepingStrikes"),
        Slam = make_action(47498, "Slam"),
        HeroicStrike = make_action(47498, "HeroicStrike"),
        ThunderClap = make_action(47502, "ThunderClap"),
        DemoralizingShout = make_action(47437, "DemoralizingShout"),
        Hamstring = make_action(25212, "Hamstring"),
        Pummel = make_action(6554, "Pummel"),
    },
    WarriorConstants = {
        STANCE = STANCE,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return { get_class = function() return 1 end, get_rage = function() return 50 end, get_health_percentage = function() return 80 end, get_stance = function() return 1 end } end,
    me = { get_rage = function() return 50 end, get_health_percentage = function() return 80 end, get_stance = function() return 1 end },
    spell_action = make_action,
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
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered[name] = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

print("=== test_warrior_arms_wotlk ===")

local arms = dofile("EaxRotations/classes/warrior/arms_wotlk.lua")
assert_true(type(arms) == "table", "arms_wotlk should return a table")
assert_true(type(arms.strategies) == "table", "arms_wotlk should expose strategies")
assert_true(type(arms.build_state) == "function", "arms_wotlk should expose build_state")

local function find_in(strats, name)
    for i = 1, #strats do
        if strats[i].name == name then return strats[i] end
    end
    return nil
end

assert_true(registered["arms"] ~= nil, "arms_wotlk should register under 'arms'")
assert_true(registered["arms"].options ~= nil and type(registered["arms"].options.get_state) == "function", "registration options should include get_state")

local ctx = { in_combat = true, target = { get_health_percentage = function() return 50 end }, me = {}, settings = {}, rage = 30, stance = 1, hp = 80, target_hp = 50, enemy_count = 1 }
local state = arms.build_state(ctx)
for _, name in ipairs({ "BattleShout", "Rend", "MortalStrike", "Overpower", "Execute", "Bladestorm", "SweepingStrikes", "ThunderClap", "DemoralizingShout", "Hamstring", "Slam", "HeroicStrike" }) do
    local s = find_in(arms.strategies, name)
    if s then
        expect_no_crash("arms_wotlk: " .. name .. " with minimal context", function()
            return s.matches(ctx, state)
        end)
    end
end

expect_no_crash("arms_wotlk: Execute with nil context fields", function()
    local nil_state = arms.build_state({ target = {}, settings = {} })
    return find_in(arms.strategies, "Execute").matches({ target = {}, settings = {} }, nil_state)
end)

expect_no_crash("arms_wotlk: build_state with empty context", function()
    return arms.build_state({})
end)

-- ============================================================================
-- Execute gating: target HP < 20% and rage threshold
-- ============================================================================

local NS = _G.EaxRotations

local execute = find_in(arms.strategies, "Execute")
assert_true(execute ~= nil, "Execute strategy should exist")

-- Target HP high -> should NOT match
local execute_state_high_hp = arms.build_state({ in_combat = true, target = { get_health_percentage = function() return 50 end }, settings = {}, rage = 30 })
assert_false(execute.matches({}, execute_state_high_hp), "Execute should not match when target HP >= 20%")

-- Target HP low + sufficient rage -> should match
local execute_state_low_hp = arms.build_state({ in_combat = true, target = { get_health_percentage = function() return 15 end }, settings = {}, rage = 30 })
assert_true(execute.matches({}, execute_state_low_hp), "Execute should match when target HP < 20% and rage >= 10")

-- Target HP low but insufficient rage -> should NOT match
local original_get_rage = NS.me.get_rage
NS.me.get_rage = function() return 5 end
local execute_state_low_rage = arms.build_state({ in_combat = true, target = { get_health_percentage = function() return 15 end }, settings = {} })
assert_false(execute.matches({}, execute_state_low_rage), "Execute should not match when rage < 10")
NS.me.get_rage = original_get_rage

-- ============================================================================
-- Rend refresh behavior: refresh when remaining duration < 3s
-- ============================================================================

local rend = find_in(arms.strategies, "Rend")
assert_true(rend ~= nil, "Rend strategy should exist")

-- Rend debuff healthy -> should NOT match
local original_debuff_remains = NS.debuff_remains
NS.debuff_remains = function(unit, ids) return 5 end
local rend_state_healthy = arms.build_state({ in_combat = true, target = {}, settings = {} })
assert_false(rend.matches({}, rend_state_healthy), "Rend should not match when debuff remains >= 3s")

-- Rend debuff about to expire -> should match
NS.debuff_remains = function(unit, ids) return 2 end
local rend_state_refresh = arms.build_state({ in_combat = true, target = {}, settings = {} })
assert_true(rend.matches({}, rend_state_refresh), "Rend should match when debuff remains < 3s")

-- Restore mock
NS.debuff_remains = original_debuff_remains

print("Tests: " .. total_passed .. "/" .. total_tests .. " passed")
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
