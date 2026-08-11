-- test_aoe_hit_volume_gates.lua
-- WHAT: Proves shipped NS.aoe_self_meets / aoe_target_meets / aoe_count_meets
--       reject packs outside hit radius and accept packs inside (real core path).
-- WHEN: rotation suite / standalone.
-- WHY:  AoE multi gates must use spell hit volume, not 40yd enemy_count alone.
-- SAFETY: fully mocked units; no engine.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/shared/?.lua;./?.lua;api/?.lua;"
    .. package.path

-- Preload executable vec2/vec3 on the real API require path (engine stubs are type-only).
do
    local ok_rt, rt = pcall(require, "shared/geometry_vec_runtime_sylvanas")
    if ok_rt and rt and rt.ensure_package_loaded then
        rt.ensure_package_loaded()
    end
end

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
all_ok = assert_true(type(NS.squared_dist_xy) == "function", "NS.squared_dist_xy installed (vec path)") and all_ok

-- Prove shipped gates use shared module (force-install), not leftover core distance() stubs
do
    package.loaded["shared/aoe_hit_volume_sylvanas"] = nil
    local ok_m, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    all_ok = assert_true(ok_m and type(AoeHV) == "table", "shared aoe_hit_volume loads") and all_ok
    if ok_m and AoeHV and AoeHV.install then
        AoeHV.install(NS)
        all_ok = assert_true(NS.count_enemies_around_unit == AoeHV.count_enemies_around_unit,
            "NS.count_enemies_around_unit is shared vec implementation") and all_ok
        all_ok = assert_true(NS.count_enemies_around_me == AoeHV.count_enemies_around_me,
            "NS.count_enemies_around_me is shared vec implementation") and all_ok
        all_ok = assert_true(NS.aoe_target_meets == AoeHV.aoe_target_meets,
            "NS.aoe_target_meets is shared vec implementation") and all_ok
        all_ok = assert_true(NS.aoe_self_meets == AoeHV.aoe_self_meets,
            "NS.aoe_self_meets is shared vec implementation") and all_ok
    end
end

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
-- Prove in-radius filter invokes vec squared_dist_xy / squared_dist_to_ignore_z (not distance() only).
do
    local sq_calls = 0
    local save_sq = NS.squared_dist_xy
    NS.squared_dist_xy = function(a, b)
        sq_calls = sq_calls + 1
        return save_sq(a, b)
    end
    local around_target = NS.count_enemies_around_unit(far_c, 8)
    all_ok = assert_true(around_target >= 2, "count around far target includes target+pack (>=2)") and all_ok
    all_ok = assert_true(sq_calls > 0,
        "count_enemies_around_unit uses NS.squared_dist_xy (vec3 horizontal) for radius filter") and all_ok

    sq_calls = 0
    local ok_tgt = NS.aoe_target_meets(2, 8, far_c, {})
    all_ok = assert_true(ok_tgt, "aoe_target_meets(2,8,far_target) true for clustered far pack") and all_ok
    all_ok = assert_true(sq_calls > 0,
        "aoe_target_meets path calls squared_dist_xy for target-centered radius") and all_ok
    NS.squared_dist_xy = save_sq
end

-- Self-centered: when player has position, count uses vec squared_dist on each enemy
do
    local sq_calls = 0
    local save_sq = NS.squared_dist_xy
    NS.squared_dist_xy = function(a, b)
        sq_calls = sq_calls + 1
        return save_sq(a, b)
    end
    local n = NS.count_enemies_around_me(10)
    all_ok = assert_eq(n, 2, "count_enemies_around_me(10) still 2 with vec filter") and all_ok
    all_ok = assert_true(sq_calls >= 2,
        "count_enemies_around_me uses squared_dist_xy per enemy with positions") and all_ok
    NS.squared_dist_xy = save_sq
end

-- get_enemies_in_range must NOT skip vec re-filter when positions exist
-- (audit gap: previously trusted OM list blindly).
do
    local sq_calls = 0
    local save_sq = NS.squared_dist_xy
    NS.squared_dist_xy = function(a, b)
        sq_calls = sq_calls + 1
        return save_sq(a, b)
    end
    -- Lie: native list returns far_d (~38yd from me, ~3yd from far_c? far_d at 38,0 and far_c at 35,0 → 3yd)
    -- Attach get_enemies_in_range on far_c that returns near_a (at me 5yd) which is ~30yd from far_c
    far_c.get_enemies_in_range = function(self, r, _flag)
        return { near_a, far_c } -- near_a is NOT within 8 of far_c
    end
    local n_eir = NS.count_enemies_around_unit(far_c, 8)
    -- near_a should be rejected by vec; far_c is origin (included); far packmate not in list
    -- Result should be 1 (origin only) or 1+ if far_c counted once — not 2 from blind list trust
    all_ok = assert_true(n_eir <= 1,
        "get_enemies_in_range path re-filters with vec (rejects near_a ~30yd from far_c)") and all_ok
    all_ok = assert_true(sq_calls > 0,
        "get_enemies_in_range path still calls squared_dist_xy when positions exist") and all_ok
    far_c.get_enemies_in_range = nil
    NS.squared_dist_xy = save_sq
end

-- Prove squared_dist_xy uses real vec3:squared_dist_to_ignore_z under the hood
do
    local rt_ok, rt = pcall(require, "shared/geometry_vec_runtime_sylvanas")
    all_ok = assert_true(rt_ok and rt and rt.ensure_package_loaded ~= nil, "vec runtime available") and all_ok
    if rt_ok and rt then rt.ensure_package_loaded() end
    local v3 = package.loaded["common/geometry/vector_3"]
    all_ok = assert_true(type(v3) == "table" and type(v3.new) == "function", "vector_3.new on require path") and all_ok
    local a = v3.new(0, 0, 10)
    local b = v3.new(3, 4, 99) -- 3-4-5 triangle XY; z ignored
    local d2 = a:squared_dist_to_ignore_z(b)
    all_ok = assert_eq(d2, 25, "vec3:squared_dist_to_ignore_z(3,4)=25 ignores z") and all_ok
    local via = NS.squared_dist_xy({ x = 0, y = 0, z = 10 }, { x = 3, y = 4, z = 99 })
    all_ok = assert_eq(via, 25, "NS.squared_dist_xy matches vec3 ignore-z (high-accuracy path)") and all_ok
end

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

-- Ensure shared cone/ground helpers are installed (core may not redefine them)
do
    local ok_m, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if ok_m and AoeHV and AoeHV.install then AoeHV.install(NS) end
end
all_ok = assert_true(type(NS.offset_in_facing_cone) == "function", "NS.offset_in_facing_cone exists") and all_ok
all_ok = assert_true(type(NS.count_enemies_in_cone) == "function", "NS.count_enemies_in_cone exists") and all_ok
all_ok = assert_true(type(NS.aoe_cone_meets) == "function", "NS.aoe_cone_meets exists") and all_ok
all_ok = assert_true(type(NS.cast_ground_aoe) == "function", "NS.cast_ground_aoe exists") and all_ok
all_ok = assert_true(type(NS.as_vec3) == "function" or type(NS.squared_dist_xy) == "function",
    "vec helpers installed on NS") and all_ok

-- Structural: shipped cone path must require vector_2/vector_3 and must not gate via math.atan2 alone
do
    local f = io.open("EaxRotations/shared/aoe_hit_volume_sylvanas.lua", "rb")
    local src = f and f:read("*a") or ""
    if f then f:close() end
    all_ok = assert_true(src:find('common/geometry/vector_2', 1, true) ~= nil
        or src:find("vector_2", 1, true) ~= nil, "aoe_hit_volume references vector_2") and all_ok
    all_ok = assert_true(src:find('common/geometry/vector_3', 1, true) ~= nil
        or src:find("vector_3", 1, true) ~= nil, "aoe_hit_volume references vector_3") and all_ok
    all_ok = assert_true(src:find("length_squared", 1, true) ~= nil
        or src:find("squared_dist_to_ignore_z", 1, true) ~= nil,
        "uses vec squared length / dist") and all_ok
    all_ok = assert_true(src:find(":dot", 1, true) ~= nil or src:find("dot_product", 1, true) ~= nil,
        "uses vec dot for cone sector") and all_ok
    -- Gate decision must not rely solely on atan2 (yaw→forward may still use sin/cos once)
    local atan_only_gate = src:find("math.atan2", 1, true) ~= nil
        and src:find("offset_in_facing_cone", 1, true) ~= nil
    if atan_only_gate then
        -- allow atan2 only if cos(ha) / :dot path also present
        all_ok = assert_true(src:find("math.cos(ha)", 1, true) ~= nil or src:find(":dot", 1, true) ~= nil,
            "if atan2 appears, dot/cos sector path must also exist") and all_ok
    end
    all_ok = assert_true(src:find("math.atan2", 1, true) == nil,
        "cone gate does not use math.atan2 (vec2 :dot + cos half-angle)") and all_ok
end

-- ESP-style cone: facing +Y (rotation 0 → forward +Y via sin/cos yaw → vec2)
-- Facing 0: world +Y is forward. Place front enemy at (0,5), rear at (0,-5).
local front = make_unit("front", 0, 5)
local rear = make_unit("rear", 0, -5)
local side = make_unit("side", 8, 0) -- ~90° off facing 0 → outside ±45° half-angle
me.get_rotation = function() return 0 end
all_enemies = { front, rear, side }

local n_cone = NS.count_enemies_in_cone(10, NS.CONE_HALF_ANGLE or (math.pi / 4), {
    me = me,
    facing = 0,
    me_pos = { x = 0, y = 0 },
    enemies = all_enemies,
})
all_ok = assert_eq(n_cone, 1, "cone counts only frontal enemy (front, not rear/side)") and all_ok

all_ok = assert_true(NS.offset_in_facing_cone(0, 5, 0, math.pi / 4), "offset front in cone") and all_ok
all_ok = assert_true(not NS.offset_in_facing_cone(0, -5, 0, math.pi / 4), "offset rear not in cone") and all_ok
all_ok = assert_true(not NS.offset_in_facing_cone(8, 0, 0, math.pi / 4), "offset pure side not in 90° cone") and all_ok

-- aoe_cone_meets with explicit facing + enemies: front only → need 2 fails; need 1 passes
local ok_cone1 = NS.aoe_cone_meets(1, 10, nil, { facing = 0, enemies = all_enemies }, nil, {
    facing = 0, me = me, me_pos = { x = 0, y = 0 }, enemies = all_enemies,
})
local ok_cone2 = NS.aoe_cone_meets(2, 10, nil, { facing = 0, enemies = all_enemies }, nil, {
    facing = 0, me = me, me_pos = { x = 0, y = 0 }, enemies = all_enemies,
})
all_ok = assert_true(ok_cone1, "aoe_cone_meets(1) true with one frontal") and all_ok
all_ok = assert_true(not ok_cone2, "aoe_cone_meets(2) false when only 1 frontal (rear ignored)") and all_ok

-- Two front enemies → multi cone passes
local front2 = make_unit("front2", 1, 6)
all_enemies = { front, front2, rear }
local ok_cone_multi = NS.aoe_cone_meets(2, 10, nil, { facing = 0 }, nil, {
    facing = 0, me = me, me_pos = { x = 0, y = 0 }, enemies = all_enemies,
})
all_ok = assert_true(ok_cone_multi, "aoe_cone_meets(2) true with two frontals") and all_ok

all_enemies = save

-- ---------------------------------------------------------------------------
-- cast_ground_aoe: real helper path must pass gate radius into get_aoe_cast_position
-- Flamestrike path → 5; Blizzard/Volley/RoF path → 8.
-- ---------------------------------------------------------------------------
do
    local captured = {}
    local save_get = NS.get_aoe_cast_position
    local save_try_pos = NS.try_cast_position
    local save_try = NS.try_cast
    local save_get_id = NS.get_spell_id

    NS.get_spell_id = function(spell)
        if type(spell) == "number" then return spell end
        if type(spell) == "table" and spell.id then return spell.id end
        return 27086 -- Flamestrike max rank placeholder for stubs
    end
    NS.get_aoe_cast_position = function(spell_id, target, radius, max_range, min_hits)
        captured[#captured + 1] = {
            spell_id = spell_id,
            target = target,
            radius = radius,
            max_range = max_range,
            min_hits = min_hits,
        }
        return { x = 1, y = 2, z = 3 }, 2
    end
    NS.try_cast_position = function(spell, pos, target, message, opts)
        captured.last_pos = pos
        captured.last_message = message
        return true
    end
    NS.try_cast = function()
        error("try_cast must not be used when get_aoe_cast_position returns a pos")
    end

    local tgt = far_c
    local ok_fs = NS.cast_ground_aoe(27086, tgt, NS.AOE_RADIUS.GROUND_5 or 5, 35, "[TEST] Flamestrike")
    all_ok = assert_true(ok_fs, "cast_ground_aoe Flamestrike path returns true") and all_ok
    all_ok = assert_true(#captured >= 1, "get_aoe_cast_position invoked for Flamestrike") and all_ok
    all_ok = assert_eq(captured[1].radius, 5, "Flamestrike cast_ground_aoe passes radius 5 to get_aoe_cast_position") and all_ok
    all_ok = assert_eq(captured[1].max_range, 35, "Flamestrike cast max_range 35") and all_ok
    all_ok = assert_true(captured.last_pos ~= nil and captured.last_pos.x == 1, "try_cast_position got predicted pos") and all_ok
    all_ok = assert_true(type(captured.last_pos.y) == "number" and type(captured.last_pos.z) == "number",
        "cast position is vec3-shaped (x/y/z)") and all_ok

    captured = {}
    NS.get_spell_id = function() return 27085 end -- Blizzard
    NS.get_aoe_cast_position = function(spell_id, target, radius, max_range, min_hits)
        captured[#captured + 1] = { radius = radius, max_range = max_range, spell_id = spell_id }
        return { x = 4, y = 5, z = 6 }, 3
    end
    NS.try_cast_position = function() return true end

    local ok_bliz = NS.cast_ground_aoe(27085, tgt, NS.AOE_RADIUS.GROUND_8 or 8, 35, "[TEST] Blizzard")
    all_ok = assert_true(ok_bliz, "cast_ground_aoe Blizzard path returns true") and all_ok
    all_ok = assert_eq(captured[1].radius, 8, "Blizzard cast_ground_aoe passes radius 8 to get_aoe_cast_position") and all_ok
    all_ok = assert_eq(captured[1].max_range, 35, "Blizzard cast max_range 35") and all_ok

    -- Ensure 5 and 8 are distinct on the same helper (no accidental hardcode collapse)
    all_ok = assert_true(NS.AOE_RADIUS.GROUND_5 ~= NS.AOE_RADIUS.GROUND_8,
        "GROUND_5 != GROUND_8 (Flamestrike vs Blizzard)") and all_ok

    NS.get_aoe_cast_position = save_get
    NS.try_cast_position = save_try_pos
    NS.try_cast = save_try
    NS.get_spell_id = save_get_id
end

if all_ok then
    print("OK aoe_hit_volume_gates")
else
    print("FAIL aoe_hit_volume_gates")
    os.exit(1)
end
