-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_cat_snapshot_upgrade.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- unit tests for cat_sylvanas bleed snapshot upgrade logic & high-AP window detection.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local pass_count = 0
local test_count = 0

local function assert_true(v, label)
    test_count = test_count + 1
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
    pass_count = pass_count + 1
end

local function assert_false(v, label)
    test_count = test_count + 1
    if v then error("FAIL: " .. (label or "assert_false"), 2) end
    pass_count = pass_count + 1
end

local function assert_eq(a, b, label)
    test_count = test_count + 1
    if a ~= b then error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
    pass_count = pass_count + 1
end

-- ============================================================================
-- Mock NS namespace
-- ============================================================================

local action_calls = {}
_G.EaxRotations = {
    DruidSpells = {
        Shred = 5221,
        Rip = 27008,
        Rake = 1822,
    },
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    action_execute = function(ctx, act, prefix)
        action_calls[#action_calls + 1] = { fn = "action_execute", ctx = ctx, act = act }
        return true
    end,
    debuff_remains = function(target, debuff_list)
        return target and target._debuff_remains or 0
    end,
    buff_up = function(me, buff_list)
        return me and me._buff_up or false
    end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    has_form = function() return true end,
    log = function() end,
    time_now = function() return 0 end,
    try_cast = function() return true end,
    setting_number = function(settings, key, default)
        return type(settings) == "table" and type(settings[key]) == "number" and settings[key] or default
    end,
    setting_bool = function(settings, key, default)
        local value = settings and settings[key]
        if value == nil then return default end
        return value ~= false
    end,
    rotation_registry = { register = function() end },
}

-- ============================================================================
-- Load strategies
-- ============================================================================

local strategies = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Helper: create a base context for snapshot tests
-- ============================================================================

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
        -- Set target and me FIRST so _debuff_remains and _buff_up always find the right object
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

-- ============================================================================
-- Helper: record a snapshot by executing a bleed strategy
-- This sets the module-level snapshot_state for subsequent matches tests
-- ============================================================================

local function record_snapshot(strategy, ap_value, target_obj, overrides)
    local ctx = base_context({ attack_power = ap_value, target = target_obj, _debuff_remains = 10 })
    if overrides then
        for k, v in pairs(overrides) do ctx[k] = v end
    end
    local ok = strategy.execute(ctx)
    assert_true(ok, "execute should succeed for " .. strategy.name .. " snapshot recording")
end

-- ============================================================================
-- Section 1: should_snapshot_upgrade via rip_matches
-- ============================================================================

local rip = find_strategy("Rip")

-- Case 1: Debuff expired (remains=0) -> should match unconditionally
do
    action_calls = {}
    local t = {}
    local ctx = base_context({ target = t, _debuff_remains = 0, attack_power = 1000 })
    assert_true(
        rip.matches(ctx),
        "Rip should match when debuff expired (remains=0), regardless of AP"
    )
end

-- Case 2: Debuff about to expire (remains=2, refresh_window=2) -> should match unconditionally
do
    action_calls = {}
    local t = {}
    local ctx = base_context({ target = t, _debuff_remains = 2, attack_power = 1000 })
    assert_true(
        rip.matches(ctx),
        "Rip should match when debuff about to expire (remains=2 <= refresh_window=2)"
    )
end

-- Case 3: Debuff partially expired, snapshot exists, AP upgrade justifies -> should match
do
    action_calls = {}
    local t = {}
    -- Record a snapshot at 2000 AP
    record_snapshot(rip, 2000, t)
    -- Now current AP is 2500, which is > 2000 * 1.08 = 2160, and remains=3.5 <= 2+1.5=3.5
    action_calls = {}
    local ctx = base_context({ target = t, _debuff_remains = 3.5, attack_power = 2500 })
    assert_true(
        rip.matches(ctx),
        "Rip should match when AP upgrade from 2000 to 2500 (>1.08x) justifies refresh at remains=3.5"
    )
end

-- Case 4: Debuff partially expired, snapshot exists, NO AP upgrade -> should NOT match
do
    action_calls = {}
    local t = {}
    record_snapshot(rip, 2000, t)
    action_calls = {}
    -- current AP = 2000, which is < 2000 * 1.08 = 2160
    local ctx = base_context({ target = t, _debuff_remains = 3.5, attack_power = 2000 })
    assert_false(
        rip.matches(ctx),
        "Rip should not match when current AP (2000) < snapshotted (2000) * 1.08"
    )
end

-- Case 5: Debuff fresh, no snapshot (rip_ap=0) -> should NOT match
do
    action_calls = {}
    local t = {}
    -- No snapshot recorded, debuff fresh (remains=10)
    local ctx = base_context({ target = t, _debuff_remains = 10, attack_power = 2000 })
    assert_false(
        rip.matches(ctx),
        "Rip should not match when debuff fresh (remains=10) and no snapshot (rip_ap=0)"
    )
end

-- Case 6: Debuff fresh, snapshot exists, AP upgrade present but too early -> should NOT match
do
    action_calls = {}
    local t = {}
    record_snapshot(rip, 2000, t)
    action_calls = {}
    -- remains=10 > refresh_window(2) + 1.5 = 3.5, so upgrade won't trigger even with higher AP
    local ctx = base_context({ target = t, _debuff_remains = 10, attack_power = 3000 })
    assert_false(
        rip.matches(ctx),
        "Rip should not match when debuff still fresh (remains=10 > 2+1.5), even with huge AP upgrade"
    )
end

-- ============================================================================
-- Section 2: should_snapshot_upgrade via rake_matches (same logic, different constants)
-- ============================================================================

local rake = find_strategy("Rake")

-- Case 7: Rake debuff expired -> should match unconditionally
do
    action_calls = {}
    local t = {}
    local ctx = base_context({ target = t, _debuff_remains = 0, attack_power = 1000, combo_points = 4 })
    assert_true(
        rake.matches(ctx),
        "Rake should match when debuff expired (remains=0)"
    )
end

-- Case 8: Rake partially expired, snapshot exists, AP upgrade -> should match
do
    action_calls = {}
    local t = {}
    record_snapshot(rake, 2000, t)
    action_calls = {}
    local ctx = base_context({ target = t, _debuff_remains = 4, attack_power = 2500, combo_points = 4 })
    assert_true(
        rake.matches(ctx),
        "Rake should match when AP upgrade from 2000 to 2500 justifies refresh"
    )
end

-- ============================================================================
-- Section 3: has_high_ap_window detection via rip_snapshot_matches
-- ============================================================================

local rip_snapshot = find_strategy("RipSnapshot")

-- Case 9: No snapshot recorded (rip_ap=0) -> should NOT match
do
    action_calls = {}
    local t = {}
    -- No snapshot, fresh debuff
    local ctx = base_context({ target = t, _debuff_remains = 8, attack_power = 3000 })
    assert_false(
        rip_snapshot.matches(ctx),
        "RipSnapshot should not match when no snapshot recorded (rip_ap=0)"
    )
    assert_eq(#action_calls, 0, "action_matches should not be called with no snapshot")
end

-- Case 10: Strong AP upgrade (1.15x), no high-AP window -> should match
--    2500 >= 2000 * 1.15 = 2300 -> yes
do
    action_calls = {}
    local t = {}
    record_snapshot(rip, 2000, t)
    action_calls = {}
    -- remains=6 > RIP_REFRESH_WINDOW=2, so this goes through rip_snapshot path
    -- has_high_ap_window: attack_power=2500, rip_ap=2000: 2500 < 2000*1.08=2160 -> false
    -- So ratio = STRONG_AP_UPGRADE_RATIO = 1.15. 2500 >= 2000*1.15=2300 -> true
    local ctx = base_context({ target = t, _debuff_remains = 6, attack_power = 2500 })
    assert_true(
        rip_snapshot.matches(ctx),
        "RipSnapshot should match with strong AP upgrade (2500 >= 2000*1.15)"
    )
end

-- Case 11: Strong AP upgrade not met, no high-AP window -> should NOT match
--    2100 < 2000 * 1.15 = 2300 -> no
do
    action_calls = {}
    local t = {}
    record_snapshot(rip, 2000, t)
    action_calls = {}
    local ctx = base_context({ target = t, _debuff_remains = 6, attack_power = 2100 })
    assert_false(
        rip_snapshot.matches(ctx),
        "RipSnapshot should not match when AP (2100) < snapshotted (2000) * 1.15 (2300), no high-AP window"
    )
end

-- Case 12: High-AP window via bloodlust -> uses lower threshold (1.05x)
--    2200 >= 2000 * 1.05 = 2100 -> yes (but would fail at 1.15x: 2200 < 2300)
do
    action_calls = {}
    local t = {}
    record_snapshot(rip, 2000, t)
    action_calls = {}
    -- Activate bloodlust via _buff_up on me
    local ctx = base_context({
        target = t,
        _debuff_remains = 6,
        attack_power = 2200,
        _buff_up = true,  -- This makes buff_up return true for ANY buff, including BLOODLUST_BUFFS
    })
    assert_true(
        rip_snapshot.matches(ctx),
        "RipSnapshot should match with bloodlust (2200 >= 2000*1.05) — uses lower ratio"
    )
end

-- Case 13: High-AP window via high AP ratio (attack_power >= rip_ap * 1.08) -> uses lower threshold
--    2200 >= 2000 * 1.08 = 2160 -> yes, triggers high_ap_window
--    Then uses 1.05 ratio: 2200 >= 2000 * 1.05 = 2100 -> matches
do
    action_calls = {}
    local t = {}
    record_snapshot(rip, 2000, t)
    action_calls = {}
    -- AP=2200 triggers has_high_ap_window via attack_power >= rip_ap * 1.08 (2200 >= 2160)
    local ctx = base_context({ target = t, _debuff_remains = 6, attack_power = 2200 })
    assert_true(
        rip_snapshot.matches(ctx),
        "RipSnapshot should match during high-AP window (2200 >= 2000*1.08) with lower 1.05 ratio"
    )
end

-- Case 13b: High-AP window via Berserk buff -> uses lower threshold (1.05x)
--    AP=2100 < 2000*1.08=2160 -> would NOT trigger high-AP window via ratio alone
--    AP=2100 < 2000*1.15=2300 -> would NOT match strong ratio
--    With Berserk: has_high_ap_window=true -> uses 1.05: 2100 >= 2000*1.05=2100 -> matches
--    (This uniquely proves Berserk alone enables the match — AP=2100 is too low for any other path)
do
    action_calls = {}
    local t = {}
    record_snapshot(rip, 2000, t)
    action_calls = {}
    -- Activate Berserk via _buff_up on me
    local ctx = base_context({
        target = t,
        _debuff_remains = 6,
        attack_power = 2100,
        _buff_up = true,  -- Makes buff_up return true for ANY buff, including BERSERK_BUFFS
    })
    assert_true(
        rip_snapshot.matches(ctx),
        "RipSnapshot should match with Berserk buff (2100 >= 2000*1.05) — ratio-based high-AP window alone wouldn't suffice (2100 < 2160)"
    )
end

-- Case 14: Middle ground: high-AP window but AP only passes at 1.05, not 1.08
--    2100 >= 2000 * 1.08 = 2160? No, 2100 < 2160 -> no high_ap_window
--    2100 >= 2000 * 1.15 = 2300? No -> doesn't match
do
    action_calls = {}
    local t = {}
    record_snapshot(rip, 2000, t)
    action_calls = {}
    local ctx = base_context({ target = t, _debuff_remains = 6, attack_power = 2100 })
    assert_false(
        rip_snapshot.matches(ctx),
        "RipSnapshot should not match: no high-AP window (2100<2160), fails strong ratio (2100<2300)"
    )
end

-- ============================================================================
-- Section 4: rake_snapshot_matches (same high-AP window logic, rake bleed)
-- ============================================================================

local rake_snapshot = find_strategy("RakeSnapshot")

-- Case 15: RakeSnapshot with strong AP upgrade, no high-AP window -> should match
do
    action_calls = {}
    local t = {}
    record_snapshot(rake, 2000, t)
    action_calls = {}
    -- combo_points must be < 5 for rake_snapshot
    -- AP=2500 >= 2000*1.15=2300 -> yes
    local ctx = base_context({ target = t, _debuff_remains = 6, attack_power = 2500, combo_points = 4 })
    assert_true(
        rake_snapshot.matches(ctx),
        "RakeSnapshot should match with strong AP upgrade (2500 >= 2000*1.15)"
    )
end

-- Case 16: RakeSnapshot, high-AP window via bloodlust -> uses lower threshold
--    2150 >= 2000*1.05=2100 -> yes (but 2150 < 2000*1.15=2300, so only passes with lower ratio)
do
    action_calls = {}
    local t = {}
    record_snapshot(rake, 2000, t)
    action_calls = {}
    local ctx = base_context({
        target = t,
        _debuff_remains = 6,
        attack_power = 2150,
        combo_points = 4,
        _buff_up = true,  -- Bloodlust active via buff_up mock
    })
    assert_true(
        rake_snapshot.matches(ctx),
        "RakeSnapshot should match with bloodlust window (2150 >= 2000*1.05)"
    )
end

-- Case 17: RakeSnapshot at max combo points (5) -> should NOT match
do
    action_calls = {}
    local t = {}
    record_snapshot(rake, 2000, t)
    action_calls = {}
    local ctx = base_context({ target = t, _debuff_remains = 6, attack_power = 3000, combo_points = 5 })
    assert_false(
        rake_snapshot.matches(ctx),
        "RakeSnapshot should not match at 5 combo points (cap guard)"
    )
end

-- ============================================================================
-- Section 5: Record bleed snapshot behavior (cast_and_record -> record_bleed_snapshot)
-- ============================================================================

-- Case 18: Executing Rip records snapshot AP
do
    action_calls = {}
    local t = {}
    local ctx = base_context({ target = t, _debuff_remains = 10, attack_power = 1800 })
    local ok = rip.execute(ctx)
    assert_true(ok, "Rip execute should return true")
    -- Now verify the snapshot was recorded by checking rip_matches on a new context
    action_calls = {}
    -- With debuff in upgrade window, snapshot at 1800, current AP=1800 < 1800*1.08=1944 -> should NOT match
    local ctx2 = base_context({ target = t, _debuff_remains = 3, attack_power = 1800 })
    assert_false(
        rip.matches(ctx2),
        "After Rip execute at 1800 AP, matching at 1800 should not trigger (below 1.08x upgrade)"
    )
    -- But matching at 2000 AP (>= 1800*1.08=1944) should trigger
    action_calls = {}
    local ctx3 = base_context({ target = t, _debuff_remains = 3, attack_power = 2000 })
    assert_true(
        rip.matches(ctx3),
        "After Rip execute at 1800 AP, matching at 2000 (>= 1800*1.08=1944) should trigger"
    )
end

-- ============================================================================
-- Section 6: Edge cases - should_snapshot_upgrade boundaries
-- ============================================================================

-- Case 19: Snapshotted AP exactly at upgrade threshold
do
    action_calls = {}
    local t = {}
    record_snapshot(rip, 2000, t)
    action_calls = {}
    -- AP=2160 is exactly 2000*1.08. has_high_ap_window: 2160 >= 2160 -> yes
    -- So uses 1.05 ratio on rip_snapshot match. 2160 >= 2000*1.05=2100 -> matches
    local ctx = base_context({ target = t, _debuff_remains = 6, attack_power = 2160 })
    assert_true(
        rip_snapshot.matches(ctx),
        "RipSnapshot should match at boundary (2160 >= 2000*1.08 triggers high-AP, 2160 >= 2000*1.05)"
    )
end

-- Case 20: Just below high-AP window threshold
--    2159 < 2000*1.08=2160 -> no high_ap_window
--    2159 >= 2000*1.15=2300? No -> doesn't match
do
    action_calls = {}
    local t = {}
    record_snapshot(rip, 2000, t)
    action_calls = {}
    local ctx = base_context({ target = t, _debuff_remains = 6, attack_power = 2159 })
    assert_false(
        rip_snapshot.matches(ctx),
        "RipSnapshot should not match: 2159 < 2160 (high-AP threshold), 2159 < 2300 (strong ratio)"
    )
end

-- ============================================================================
-- Summary
-- ============================================================================

print(string.format("PASS test_cat_snapshot_upgrade (%d/%d assertions passed)", pass_count, test_count))
