-- Debug v3: Patch rip_snapshot_matches with trace prints
-- Load the original cat_sylvanas.lua, then override rip_snapshot_matches with a debug version

_G.EaxRotations = {}
local NS = _G.EaxRotations

NS.action_matches = function(ctx, act)
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

local action_calls = {}

-- Helpers
local assert_true = function(v, msg) if not v then error("FAIL: " .. msg) end end
local assert_eq = function(a, b, msg) if a ~= b then error(string.format("FAIL: %s (expected %s, got %s)", msg or "", tostring(b), tostring(a))) end end

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

print("rip.name: " .. tostring(rip and rip.name))
print("rip_snapshot.name: " .. tostring(rip_snapshot and rip_snapshot.name))

-- Override rip_snapshot.matches with debug version
local original_matches = rip_snapshot.matches
rip_snapshot.matches = function(context, action)
    print("\n--- Debugging rip_snapshot.matches ---")
    print("context.attack_power: " .. tostring(context.attack_power))
    print("context.combo_points: " .. tostring(context.combo_points))
    print("context.target._debuff_remains: " .. tostring(context.target and context.target._debuff_remains))
    print("context.ttd: " .. tostring(context.ttd))
    
    -- Call original matches (which calls rip_snapshot_matches -> build_state)
    local result = original_matches(context, action)
    print("result: " .. tostring(result))
    return result
end

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
print("\n=== Case 13 ===")
action_calls = {}
local t = {}
record_snapshot(rip, 2000, t)
action_calls = {}

local ctx = base_context({ target = t, _debuff_remains = 6, attack_power = 2200 })

print("\nCalling overridden rip_snapshot.matches...")
local result = rip_snapshot.matches(ctx)
print("\nFinal result: " .. tostring(result))
print("action_calls: " .. tostring(#action_calls))
