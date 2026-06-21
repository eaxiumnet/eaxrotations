-- ============================================================================
-- Unit tests for M.is_boss_fight() in targeting_sylvanas.lua
--
-- Exercises: core.object_manager.get_boss_count() (primary path)
--            core.object_manager.get_boss_frames() (fallback path)
--            Nil-guard when both APIs unavailable
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Helper: reset module cache and load targeting with mocked core API
local function load_targeting(mock_core)
    package.loaded["shared/targeting_sylvanas"] = nil
    package.preload["shared/targeting_sylvanas"] = nil

    _G.core = mock_core

    _G.EaxRotations = {
        GetPlayer = function() return nil end,
        Targeting = {},
    }

    local ok, mod = pcall(require, "shared/targeting_sylvanas")
    if not ok or type(mod) ~= "table" then
        error("failed to load targeting_sylvanas: " .. tostring(mod))
    end
    return mod
end

-- ============================================================================
-- Scenario A: get_boss_count returns 2 → is_boss_fight is true
-- (Happy path: count API available, 2 active boss frames)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {
            get_boss_count = function() return 2 end,
        }
    })
    assert_true(targeting.is_boss_fight(),
        "S-A: is_boss_fight should be true when get_boss_count()=2")
end

-- ============================================================================
-- Scenario B: get_boss_count returns 0 → is_boss_fight is false
-- (Edge: no boss frames active)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {
            get_boss_count = function() return 0 end,
        }
    })
    assert_false(targeting.is_boss_fight(),
        "S-B: is_boss_fight should be false when get_boss_count()=0")
end

-- ============================================================================
-- Scenario C: get_boss_count is nil → falls back to get_boss_frames
-- (Backward compatibility: API unavailable, uses frame iteration)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {
            get_boss_frames = function() return { { name = "Gruul" } } end,
        }
    })
    assert_true(targeting.is_boss_fight(),
        "S-C: is_boss_fight should fall back to frames when count API nil (1 boss frame)")
end

-- ============================================================================
-- Scenario D: Both APIs unavailable → is_boss_fight is false
-- (Edge: no boss detection possible, safe nil path)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {}
    })
    assert_false(targeting.is_boss_fight(),
        "S-D: is_boss_fight should be false when both APIs unavailable")
end

-- ============================================================================
-- Scenario E: get_boss_count nil, get_boss_frames returns empty → false
-- (Edge: fallback path with no bosses)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {
            get_boss_frames = function() return {} end,
        }
    })
    assert_false(targeting.is_boss_fight(),
        "S-E: is_boss_fight should be false when fallback frames is empty")
end

-- ============================================================================
-- Scenario F: get_boss_count returns 1 → is_boss_fight is true (boundary)
-- (Boundary: single boss frame = still a boss fight)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {
            get_boss_count = function() return 1 end,
        }
    })
    assert_true(targeting.is_boss_fight(),
        "S-F: is_boss_fight should be true when get_boss_count()=1")
end

print("PASS test_boss_count")
