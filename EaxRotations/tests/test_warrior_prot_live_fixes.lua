-- test_warrior_prot_live_fixes.lua — Warrior Protection live-correctness regression tests.
-- WHAT:  pins the 2026-08-12 live-fix campaign for protection_sylvanas.lua:
--        (1) build_state frame-cache (context.now keyed, safe_state-wrapped),
--        (2) swing_remains populated via NS.get_time_until_swing so the
--            swing_timer_gate is live, (3) LastStand expected cooldown 180
--            (agrees with class_sylvanas.lua), (4) WhirlwindMulti requires
--            Berserker Stance (no silent try_cast failure in Defensive),
--        (5) Taunt stays elite-only (intentional smart-taunt design).
-- WHEN:  standalone (lua EaxRotations/tests/test_warrior_prot_live_fixes.lua);
--        also registered in run_rotation_tests.lua.
-- WHY:   performance + silent-failure fixes must not regress.
-- SAFETY: Pure unit tests with a mocked NS; no real game API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": got " .. tostring(a) .. " expected " .. tostring(b), 2) end
end

local ready_calls = 0        -- spy: NS.spell_ready invocation count (build cost)
local mock_swing = 0.5       -- spy: NS.get_time_until_swing return value
local captured_try_cast = nil

local mock_me = {
    is_casting_spell = function() return false end,
    get_position = function() return { x = 0, y = 0, z = 0 } end,
    get_class = function() return 1 end,
    is_enemy_with = function() return true end,
    distance_to = function() return 5 end,
    get_target = function() return nil end,
    is_dead = function() return false end,
}

local mock_target = {
    is_casting_spell = function() return false end,
    get_position = function() return { x = 5, y = 0, z = 0 } end,
    get_class = function() return 1 end,
    is_enemy_with = function() return true end,
    get_target = function() return mock_me end,
    get_threat_situation = function() return { is_tanking = false } end,
    get_classification = function() return 0 end,
    is_valid = function() return true end,
    is_damage_immune = function() return false end,
    is_player = function() return false end,
}

_G.EaxRotations = {
    WarriorSpells = { Taunt = { ids = { 355 }, name = "Taunt" } },
    WarriorConstants = {},
    GetPlayer = function() return mock_me end,
    log = function() end,
    time_now = function() return 0 end,
    spell_ready = function() ready_calls = ready_calls + 1; return true end,
    try_cast = function(spell, unit, label, opts)
        captured_try_cast = { spell = spell, unit = unit, label = label, opts = opts }
        return true
    end,
    buff_up = function() return false end,
    debuff_remains = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    is_interruptible = function() return false end,
    not_same_unit = function() return true end,
    same_unit = function() return false end,
    unit_health_pct = function() return 100 end,
    get_time_until_swing = function() return mock_swing end,
    has_target_debuff = function() return false end,
    use_item_by_id = function() return true end,
    rotation_registry = { register = function() end },
}

local module = dofile("EaxRotations/classes/warrior/protection_sylvanas.lua")
assert_true(module ~= nil, "protection module must load")
local strategies = module.strategies
assert_true(type(strategies) == "table", "strategies table missing")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function base_ctx(o)
    local c = {
        target = mock_target, me = mock_me, in_combat = true, rage = 80,
        stance = 2, enemy_count = 3, has_valid_enemy_target = true, settings = {},
    }
    if o then for k, v in pairs(o) do c[k] = v end end
    return c
end

-- ============================================================================
-- 1) build_state frame-cache: same tick builds once, new tick rebuilds.
-- ============================================================================
ready_calls = 0
local s1 = module.build_state(base_ctx({ now = 1000 }))
local c1 = ready_calls
assert_true(c1 > 5, "first build must run the spell_ready block (got " .. c1 .. " calls)")
assert_eq(s1.rage, 80, "first build carries context rage")

local s2 = module.build_state(base_ctx({ now = 1000 })) -- same tick -> cache hit
assert_eq(ready_calls, c1, "cache hit must not rebuild state (spell_ready calls grew: " .. ready_calls .. ")")
assert_eq(s2.rage, 80, "cache-hit state must carry the built values")
assert_true(getmetatable(s2) ~= nil, "cache-hit state must still be a safe_state proxy")

local s3 = module.build_state(base_ctx({ now = 1001, rage = 55 })) -- new tick -> rebuild
assert_true(ready_calls > c1, "new tick must rebuild (spell_ready calls grew: " .. ready_calls .. ")")
assert_eq(s3.rage, 55, "new tick must carry the fresh rage")

-- ============================================================================
-- 2) swing_timer_gate is live: swing_remains comes from NS.get_time_until_swing.
-- ============================================================================
local hs = find_strategy("HeroicStrike")
mock_swing = 0.1 -- swing lands within 0.3s -> casting now would delay the swing
assert_false(hs.matches(base_ctx(), { ss_ready = false, revenge_ready = false, rage = 80 }),
    "HeroicStrike must NOT fire when the swing lands within 0.3s (swing gate live)")
mock_swing = 0.5 -- swing window open -> safe to queue HS
assert_true(hs.matches(base_ctx(), { ss_ready = false, revenge_ready = false, rage = 80 }),
    "HeroicStrike must fire when the swing window is open")

-- ============================================================================
-- 3) LastStand expected cooldown agrees with class_sylvanas.lua (180).
-- ============================================================================
captured_try_cast = nil
local ls = find_strategy("LastStand")
ls.execute({ me = mock_me }, nil)
assert_true(captured_try_cast ~= nil, "LastStand execute must call NS.try_cast")
assert_true(captured_try_cast.opts ~= nil, "LastStand try_cast must carry opts")
assert_eq(captured_try_cast.opts.expected_cooldown, 180,
    "LastStand expected_cooldown must be 180 (class table), got "
        .. tostring(captured_try_cast.opts.expected_cooldown))

-- ============================================================================
-- 4) WhirlwindMulti requires Berserker Stance (no silent failure in Defensive).
-- ============================================================================
local ww = find_strategy("WhirlwindMulti")
assert_false(ww.matches(base_ctx({ stance = 2, _aoe_hit_count = 3 }), { stance = 2 }),
    "Whirlwind must NOT fire in Defensive Stance (tank default)")
assert_true(ww.matches(base_ctx({ stance = 3, _aoe_hit_count = 3 }), { stance = 3 }),
    "Whirlwind must fire in Berserker Stance")

-- ============================================================================
-- 5) Taunt stays elite-only (intentional smart-taunt design; pinned by
--    test_opener_elite_regression.lua).
-- ============================================================================
local taunt = find_strategy("Taunt")
assert_false(taunt.matches(base_ctx({ target_classification = 0 }), {}),
    "Taunt must stay elite-only (classification < 1)")
mock_target.get_classification = function() return 1 end
assert_true(taunt.matches(base_ctx({ target_classification = 1 }), {}),
    "Taunt must fire on elites (classification >= 1)")

print("PASS test_warrior_prot_live_fixes")
