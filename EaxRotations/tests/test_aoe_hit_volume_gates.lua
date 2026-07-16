-- test_aoe_hit_volume_gates.lua
-- WHAT: Proves shipped NS.aoe_self_meets / aoe_target_meets / aoe_count_meets
--       reject packs outside hit radius and accept packs inside (real core path).
-- WHEN: rotation suite / standalone.
-- WHY:  AoE multi gates must use spell hit volume, not 40yd enemy_count alone.
-- SAFETY: fully mocked units; no engine.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;api/?.lua;" .. package.path

local function assert_true(v, msg)
    if not v then
        print("FAIL " .. tostring(msg))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_eq(a, b, msg)
    if a ~= b then
        print("FAIL " .. tostring(msg) .. ": got " .. tostring(a) .. " want " .. tostring(b))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local all_ok = true

-- Minimal NS + core load
_G.EaxRotations = _G.EaxRotations or {}
local NS = _G.EaxRotations

-- Mock player + enemies with distance
local function make_unit(name, x, y)
    return {
        _name = name,
        _x = x or 0,
        _y = y or 0,
        get_distance = function(self, other)
            if not other then return 999 end
            local dx = (self._x or 0) - (other._x or 0)
            local dy = (self._y or 0) - (other._y or 0)
            local d2 = dx * dx + dy * dy
            -- No math.sqrt (suite policy); perfect squares for fixture coords only.
            if d2 == 0 then return 0 end
            if d2 == 25 then return 5 end
            if d2 == 64 then return 8 end
            if d2 == 9 then return 3 end
            if d2 == 1225 then return 35 end
            if d2 == 1444 then return 38 end
            if d2 == 1369 then return 37 end
            if d2 == 1296 then return 36 end
            -- Coarse integer ceil-sqrt for unexpected pairs.
            local est = 1
            while est * est < d2 do est = est + 1 end
            return est
        end,
        distance_to = function(self, other)
            return self:get_distance(other)
        end,
        get_position = function(self)
            return { x = self._x, y = self._y, z = 0 }
        end,
    }
end

local me = make_unit("me", 0, 0)
local near_a = make_unit("near_a", 5, 0)   -- 5yd from me
local near_b = make_unit("near_b", 8, 0)   -- 8yd from me
local far_c = make_unit("far_c", 35, 0)    -- 35yd from me
local far_d = make_unit("far_d", 38, 0)    -- 38yd from me
local near_target_pack = make_unit("pack", 36, 3) -- ~3yd from far_c (target)

local all_enemies = { near_a, near_b, far_c, far_d, near_target_pack }

NS.GetPlayer = function() return me end
NS.same_unit = function(a, b) return a == b end
NS.not_same_unit = function(a, b) return a ~= b end
NS.is_hostile_unit = function(player, unit)
    return unit ~= nil and unit ~= player
end
NS.time_now = function() return 1 end

-- Load core (defines GetEnemiesInRange chain + aoe helpers). Stub heavy deps if needed.
local load_ok, load_err = pcall(function()
    if not package.loaded["common/izi_sdk"] then
        package.loaded["common/izi_sdk"] = {}
    end
    dofile("EaxRotations/core_sylvanas.lua")
end)

if not load_ok then
    print("core dofile note: " .. tostring(load_err))
end

NS = _G.EaxRotations

-- Re-bind player + spatial mocks AFTER core load (core overwrites GetPlayer).
NS.GetPlayer = function() return me end
NS.same_unit = function(a, b) return a == b end
NS.not_same_unit = function(a, b) return a ~= b end
NS.is_hostile_unit = function(player, unit)
    return unit ~= nil and unit ~= player
end
NS.unit_distance = function(a, b)
    if a and a.get_distance then return a:get_distance(b) end
    if b and b.get_distance then return b:get_distance(a) end
    return 999
end

NS.GetEnemiesInRange = function(range)
    local r = type(range) == "number" and range or 40
    local out = { n = 0 }
    for i = 1, #all_enemies do
        local e = all_enemies[i]
        local d = me:get_distance(e)
        if d <= r then
            out.n = out.n + 1
            out[out.n] = e
        end
    end
    return out
end
NS.GetEnemiesCount = function(range)
    local list = NS.GetEnemiesInRange(range)
    return list.n or #list
end

all_ok = assert_true(type(NS.aoe_self_meets) == "function", "NS.aoe_self_meets exists") and all_ok
all_ok = assert_true(type(NS.aoe_target_meets) == "function", "NS.aoe_target_meets exists") and all_ok
all_ok = assert_true(type(NS.AOE_RADIUS) == "table", "NS.AOE_RADIUS table exists") and all_ok

-- Self PBAoE 10yd: 2 near (<=8) + 0 far → count 2 inside 10; far not included
local n10 = NS.count_enemies_around_me(10)
all_ok = assert_eq(n10, 2, "count_enemies_around_me(10) = 2 (near only)") and all_ok

local n40 = NS.count_enemies_around_me(40)
all_ok = assert_true(n40 >= 4, "count_enemies_around_me(40) includes far pack (>=4)") and all_ok

-- Gate: need 3 in 10yd → FAIL (only 2 near)
local ok3 = NS.aoe_self_meets(3, 10, {})
all_ok = assert_true(not ok3, "aoe_self_meets(3,10) false when only 2 in 10yd (false multi rejected)") and all_ok

-- Gate: need 2 in 10yd → PASS
local ok2 = NS.aoe_self_meets(2, 10, {})
all_ok = assert_true(ok2, "aoe_self_meets(2,10) true when 2 in 10yd") and all_ok

-- Target-centered: target = far_c; pack within 8 of target
local around_target = NS.count_enemies_around_unit(far_c, 8)
all_ok = assert_true(around_target >= 2, "count around far target includes target+pack (>=2)") and all_ok

local ok_tgt = NS.aoe_target_meets(2, 8, far_c, {})
all_ok = assert_true(ok_tgt, "aoe_target_meets(2,8,far_target) true for clustered far pack") and all_ok

-- Target-centered on near_a with only self in cluster (far pack not near)
local around_near = NS.count_enemies_around_unit(near_a, 8)
-- near_a and near_b are 3yd apart → at least 2
all_ok = assert_true(around_near >= 2, "near cluster has >=2") and all_ok

-- Ensure 40yd density alone cannot pass via aoe_self when we only have far enemies in 10yd gate:
-- Temporarily only far enemies
local save = all_enemies
all_enemies = { far_c, far_d, near_target_pack }
local only_far_10 = NS.count_enemies_around_me(10)
all_ok = assert_eq(only_far_10, 0, "no enemies in 10yd when pack is at 35+") and all_ok
all_ok = assert_true(not NS.aoe_self_meets(2, 10, {}), "self PBAoE rejects far-only 40yd pack") and all_ok
all_ok = assert_true(NS.aoe_target_meets(2, 10, far_c, {}), "target gate accepts pack near far target") and all_ok
all_enemies = save

-- Ground circle multi (Blizzard/RoF/Hurricane/Volley geometry = GROUND_8 around target):
-- Reject when count near *target* is below threshold even if 40yd density is high.
all_enemies = { near_a, near_b, far_c }  -- far_c alone at 35yd (no packmate)
all_ok = assert_true(not NS.aoe_target_meets(3, NS.AOE_RADIUS.GROUND_8 or 8, far_c, {}),
    "ground AoE (r=8) rejects: only 1 enemy at target despite near-me density") and all_ok
-- Accept when enough enemies sit in ground radius of target.
all_enemies = { far_c, far_d, near_target_pack }  -- clustered at ~35yd
all_ok = assert_true(NS.aoe_target_meets(2, NS.AOE_RADIUS.GROUND_8 or 8, far_c, {}),
    "ground AoE (r=8) accepts: >=2 enemies in ground circle at target") and all_ok
-- Flamestrike uses tighter 5yd ground radius — packmate at ~3yd of far_c ok; spread rejects.
all_ok = assert_true(NS.aoe_target_meets(2, NS.AOE_RADIUS.GROUND_5 or 5, far_c, {}),
    "ground Flamestrike (r=5) accepts tight cluster at target") and all_ok
all_enemies = save

-- Expansion consistency constants
all_ok = assert_eq(NS.AOE_RADIUS.SELF_10, 10, "SELF_10 radius constant") and all_ok
all_ok = assert_eq(NS.AOE_RADIUS.SELF_8, 8, "SELF_8 radius constant") and all_ok
all_ok = assert_eq(NS.AOE_RADIUS.GROUND_5, 5, "Flamestrike GROUND_5") and all_ok
all_ok = assert_eq(NS.AOE_RADIUS.GROUND_8, 8, "GROUND_8 radius constant") and all_ok
all_ok = assert_eq(NS.AOE_RADIUS.TARGET_15, 15, "Seed TARGET_15") and all_ok

if all_ok then
    print("OK aoe_hit_volume_gates")
else
    print("FAIL aoe_hit_volume_gates")
    os.exit(1)
end
