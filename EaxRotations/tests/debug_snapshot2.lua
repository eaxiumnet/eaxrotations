-- Debug script v2: deeper tracing into rip_snapshot_matches
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

local action_calls = {}
_G.EaxRotations = {}
local NS = _G.EaxRotations

-- Mock functions
NS.action_matches = function(ctx, act)
    print("  [DBG] action_matches called")
    table.insert(action_calls, { ctx = ctx, act = act })
    return true
end
NS.action_execute = function(ctx, act, prefix)
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

local function find_strategy(name)
    for i, s in ipairs(strategies) do
        if s.name == name then return s end
    end
    return nil
end

local rip = find_strategy("Rip")
local rip_snapshot = find_strategy("RipSnapshot")

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

local function record_snapshot(strategy, ap_value, target_obj)
    local ctx = base_context({ attack_power = ap_value, target = target_obj, _debuff_remains = 10 })
    local ok = strategy.execute(ctx)
    assert_true(ok, "execute should succeed for " .. strategy.name)
end

-- Run the failing case
print("=== Running Case 13 ===")
action_calls = {}
local t = {}
record_snapshot(rip, 2000, t)
action_calls = {}

local ctx = base_context({ target = t, _debuff_remains = 6, attack_power = 2200 })

-- Manually trace through build_state and rip_snapshot_matches
-- First, let's call the original matches to see what happens
print("\nCalling rip_snapshot.matches(ctx)...")
local result = rip_snapshot.matches(ctx)
print("rip_snapshot.matches result: " .. tostring(result))
print("action_calls count: " .. tostring(#action_calls))

print("\n--- Now manually trace build_state ---")

-- Inspect the state after record_snapshot
print("snapshot_state.rip_ap = " .. tostring(_G.EaxRotations.snapshot_state and _G.EaxRotations.snapshot_state.rip_ap))

-- Replicate build_state logic manually to see state values
local me = ctx.me
local target = ctx.target
print("target == t: " .. tostring(target == t))
print("target._debuff_remains: " .. tostring(target._debuff_remains))

-- Check debuff_remains call
local rip_remains = NS.debuff_remains(target, NS.DruidSpells.Rip)
print("rip_remains (via NS.debuff_remains): " .. tostring(rip_remains))
