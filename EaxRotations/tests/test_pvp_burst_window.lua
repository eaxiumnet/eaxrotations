-- test_pvp_burst_window.lua -- PvP logic burst window tests.
-- WHAT:  PvP logic burst window tests
-- WHEN:  During PvP balance validation.
-- WHY:   Ensures PvP-specific priority shifts and burst windows function correctly.
-- SAFETY: Synthetic arena context.

-- Test: shared/pvp_burst_window_sylvanas.lua DR-immunity + enemy-defensive wiring.
-- Verifies the two formerly-stubbed helpers now delegate to the native pvp_helper /
-- EnemyCDTracker bridges, and degrade to safe defaults (false / "unknown") when those
-- bridges are unavailable (no regression vs. the prior stubs).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
local function contains(str, sub) return str and tostring(str):find(sub, 1, true) ~= nil end

-- Sentinel units so has_buff can distinguish me (offensive ready) from target (no bubble).
local me, target = {}, {}

-- Fresh NS mock captured by the module on require.
local NS = {
    has_buff = function(unit, id) return unit == me end,  -- me: offensive ready; target: no bubble
}
_G.EaxRotations = NS

-- Force a fresh load so the module captures our NS (avoid package.loaded cross-test contamination).
package.loaded["shared/pvp_burst_window_sylvanas"] = nil
local M = require("shared/pvp_burst_window_sylvanas")
assert_true(M ~= nil, "pvp_burst_window should load")

local function make_ctx()
    return { me = me, target = target, target_hp = 100, player_hp = 100 }
end

-- Reset native bridge mocks between cases.
local function reset_bridges()
    NS.pvp_is_cc_immune = nil
    NS.PVP_DR_CATEGORIES = nil
    NS.EnemyCDTracker = nil
    NS.pvp_is_player = nil
    NS.pvp_trinket_used_recently = nil
end

-- Baseline score with no native bridges: offensive ready (+15) + health safe (+10) = 25.
local function baseline_score()
    reset_bridges()
    return M.score(make_ctx())
end

-- ---------------------------------------------------------------------------
-- 1. No native bridges -> safe defaults (no "DR immune" / "defensive down" reasons).
-- ---------------------------------------------------------------------------
do
    reset_bridges()
    local ctx = make_ctx()
    local s = M.score(ctx)
    local r = M.reason(ctx)
    assert_false(contains(r, "target DR immune"), "no bridge -> no DR-immune reason")
    assert_false(contains(r, "enemy defensive down"), "no bridge -> no defensive-down reason")
    assert_true(s >= 0, "score clamped >= 0")
end

-- ---------------------------------------------------------------------------
-- 2. DR-immune in a burst-relevant category (Stun) -> reason includes "target DR immune".
-- ---------------------------------------------------------------------------
do
    reset_bridges()
    NS.PVP_DR_CATEGORIES = { [0x1] = "Stun", [0x2] = "Root" }
    NS.pvp_is_cc_immune = function(unit, flag) return unit == target and flag == 0x1 end
    local ctx = make_ctx()
    M.score(ctx)
    assert_true(contains(M.reason(ctx), "target DR immune"), "stun DR-immune -> reason fired")
end

-- ---------------------------------------------------------------------------
-- 3. Not DR-immune -> no "target DR immune" reason.
-- ---------------------------------------------------------------------------
do
    reset_bridges()
    NS.PVP_DR_CATEGORIES = { [0x1] = "Stun" }
    NS.pvp_is_cc_immune = function(unit, flag) return false end
    local ctx = make_ctx()
    M.score(ctx)
    assert_false(contains(M.reason(ctx), "target DR immune"), "not immune -> no reason")
end

-- ---------------------------------------------------------------------------
-- 5. Enemy defensive down (on cooldown) -> reason + score +20 (TARGET_NO_DEFENSIVE).
-- ---------------------------------------------------------------------------
do
    local base_s = baseline_score()
    reset_bridges()
    NS.EnemyCDTracker = { has_defensive_available = function(unit) return false end }
    local ctx = make_ctx()
    local s = M.score(ctx)
    local r = M.reason(ctx)
    assert_true(contains(r, "enemy defensive down"), "defensives on CD -> reason fired")
    assert_eq(s, base_s + 20, "defensive down -> score +20 (TARGET_NO_DEFENSIVE)")
end

-- ---------------------------------------------------------------------------
-- 6. Enemy defensive ready -> no "defensive down" reason.
-- ---------------------------------------------------------------------------
do
    reset_bridges()
    NS.EnemyCDTracker = { has_defensive_available = function(unit) return true end }
    local ctx = make_ctx()
    M.score(ctx)
    assert_false(contains(M.reason(ctx), "enemy defensive down"), "defensive ready -> no down reason")
end

-- ---------------------------------------------------------------------------
-- 7. PvP trinket on cooldown (player target) -> "defensive down" even if a defensive is ready.
-- ---------------------------------------------------------------------------
do
    reset_bridges()
    NS.EnemyCDTracker = { has_defensive_available = function(unit) return true end }
    NS.pvp_is_player = function(unit) return unit == target end
    NS.pvp_trinket_used_recently = function(unit, w) return unit == target end
    local ctx = make_ctx()
    M.score(ctx)
    assert_true(contains(M.reason(ctx), "enemy defensive down"), "trinket blown + player -> down")
end

-- ---------------------------------------------------------------------------
-- 8. Trinket on cooldown but NON-player target -> trinket signal ignored.
-- ---------------------------------------------------------------------------
do
    reset_bridges()
    NS.EnemyCDTracker = { has_defensive_available = function(unit) return true end }
    NS.pvp_is_player = function(unit) return false end
    NS.pvp_trinket_used_recently = function(unit, w) return true end
    local ctx = make_ctx()
    M.score(ctx)
    assert_false(contains(M.reason(ctx), "enemy defensive down"), "non-player + defensive ready -> not down")
end

-- ---------------------------------------------------------------------------
-- 9. should_burst threshold + analyze shape (sanity, no crash).
-- ---------------------------------------------------------------------------
do
    reset_bridges()
    local ctx = make_ctx()
    ctx.target_hp = 10  -- very low target -> high score
    local s = M.score(ctx)
    local should = M.should_burst(ctx, 0)  -- threshold 0 -> always true
    assert_true(should, "should_burst threshold 0 -> true")
    local info = M.analyze(ctx)
    assert_true(type(info) == "table" and info.score == s, "analyze returns score matching score()")
end

print("PASS test_pvp_burst_window")

-- ---------------------------------------------------------------------------
-- 4. Only an irrelevant category immune (Root) -> not treated as burst DR-immune.
-- ---------------------------------------------------------------------------
do
    reset_bridges()
    NS.PVP_DR_CATEGORIES = { [0x2] = "Root" }
    NS.pvp_is_cc_immune = function(unit, flag) return unit == target and flag == 0x2 end
    local ctx = make_ctx()
    M.score(ctx)
    assert_false(contains(M.reason(ctx), "target DR immune"), "root-only immune -> not burst-relevant")
end