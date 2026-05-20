-- Debug script for the failing RipSnapshot test case
-- This sets up the exact same environment as test_cat_snapshot_upgrade.lua

local assert_eq = function(a, b, msg)
    if a ~= b then
        error(string.format("FAIL: %s (expected %s, got %s)", msg or "", tostring(b), tostring(a)))
    end
end
local assert_true = function(v, msg)
    if not v then
        error(string.format("FAIL: %s", msg or "assertion failed"))
    end
end
local assert_false = function(v, msg)
    if v then
        error(string.format("FAIL: %s", msg or "assertion failed"))
    end
end

local action_calls = {}
_G.EaxRotations = {}

local NS = _G.EaxRotations

-- Mock the exact functions from the test
NS.action_matches = function(ctx, act)
    print("  [DEBUG] action_matches called: attack_power=" .. tostring(ctx.attack_power) .. ", combo_points=" .. tostring(ctx.combo_points) .. ", target._debuff_remains=" .. tostring(ctx.target and ctx.target._debuff_remains))
    table.insert(action_calls, { ctx = ctx, act = act })
    return true
end
NS.action_execute = function(ctx, act, prefix)
    print("  [DEBUG] action_execute called: attack_power=" .. tostring(ctx.attack_power))
    table.insert(action_calls, { ctx = ctx, act = act })
    return true
end
NS.debuff_remains = function(target, debuff_list)
    return target and target._debuff_remains or 0
end
NS.buff_up = function(me, buff_list)
    return me and me._buff_up or false
end
NS.spell_ready = function() return true end
NS.spell_exists = function() return true end
NS.has_form = function() return true end
NS.log = function() end
NS.time_now = function() return 0 end
NS.rotation_registry = { register = function() end }
NS.DruidSpells = { Shred = 5221, Rip = 27008, Rake = 1822 }

-- Load cat strategy
local strategies = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
print("Loaded strategies: " .. tostring(strategies))

local function find_strategy(name)
    for i, s in ipairs(strategies) do
        if s.name == name then return s end
    end
    print("  [WARN] Strategy '" .. name .. "' not found!")
    return nil
end

local rip = find_strategy("Rip")
local rip_snapshot = find_strategy("RipSnapshot")
print("rip: " .. tostring(rip and rip.name))
print("rip_snapshot: " .. tostring(rip_snapshot and rip_snapshot.name))

-- base_context (with fix)
local function base_context(overrides)
    local ctx = {
        target = {},
        attack_power = 2000,
        combo_points = 5,
        energy = 60,
        ttd = 60,
        target_hp = 100,
        in_combat = true,
        me = {},
    }
    if overrides then
        if overrides.target ~= nil then ctx.target = overrides.target end
        if overrides.me ~= nil then ctx.me = overrides.me end
        for k, v in pairs(overrides) do
            if k == "target" or k == "me" then
                -- already handled above
            elseif k == "_debuff_remains" then
                ctx.target._debuff_remains = v
            elseif k == "_buff_up" then
                ctx.me._buff_up = v
            else
                ctx[k] = v
            end
        end
    end
    if ctx.target._debuff_remains == nil then ctx.target._debuff_remains = 10 end
    return ctx
end

local function record_snapshot(strategy, ap_value, target_obj, overrides)
    local ctx = base_context({ attack_power = ap_value, target = target_obj, _debuff_remains = 10 })
    if overrides then
        for k, v in pairs(overrides) do ctx[k] = v end
    end
    print("  [DEBUG] record_snapshot ctx: attack_power=" .. tostring(ctx.attack_power) .. ", target._debuff_remains=" .. tostring(ctx.target._debuff_remains))
    local ok = strategy.execute(ctx)
    assert_true(ok, "execute should succeed for " .. strategy.name .. " snapshot recording")
    print("  [DEBUG] record_snapshot OK")
end

-- =============================================
-- Test Case 13: The failing case
-- =============================================
print("\n=== Case 13: High-AP window via high AP ratio ===")
action_calls = {}
local t = {}
record_snapshot(rip, 2000, t)
action_calls = {}

-- Verify t._debuff_remains wasn't left over from record_snapshot
print("t._debuff_remains after record_snapshot: " .. tostring(t._debuff_remains))

local ctx = base_context({ target = t, _debuff_remains = 6, attack_power = 2200 })
print("ctx.target == t: " .. tostring(ctx.target == t))
print("ctx.target._debuff_remains: " .. tostring(ctx.target._debuff_remains))
print("ctx.attack_power: " .. tostring(ctx.attack_power))
print("ctx.combo_points: " .. tostring(ctx.combo_points))
print("ctx.me._buff_up: " .. tostring(ctx.me._buff_up))

print("Calling rip_snapshot.matches(ctx)...")
local result = rip_snapshot.matches(ctx)
print("rip_snapshot.matches result: " .. tostring(result))
print("action_calls count: " .. tostring(#action_calls))

assert_true(
    result,
    "RipSnapshot should match during high-AP window (2200 >= 2000*1.08) with lower 1.05 ratio"
)
print("PASS: Case 13")
