-- aoe_hit_volume_sylvanas.lua
-- WHAT: Hit-volume enemy counts for multi-target damage gates (not 40yd fight density).
-- WHEN: Required by core and by specs that gate AoE/cleave; safe in unit tests without core.
-- WHY:  Prevent false multi when enemies are only in the global 40yd scan.
-- SAFETY: Pure counting; no casts. Spatial math via common/geometry vector_2 / vector_3
--         (squared_dist_to_ignore_z, length_squared, dot) for high-accuracy positions.
--         Falls back to context.enemy_count only when spatial APIs return no units.

local M = {}
local NS = _G.EaxRotations
if not NS then return M end

-- ---------------------------------------------------------------------------
-- Geometry: prefer Project Sylvanas vec2/vec3; ensure executable methods under tests
-- ---------------------------------------------------------------------------
local vec2, vec3
do
    local ok_rt, rt = pcall(require, "shared/geometry_vec_runtime_sylvanas")
    if ok_rt and type(rt) == "table" and rt.ensure_package_loaded then
        vec2, vec3 = rt.ensure_package_loaded()
    end
    if type(vec2) ~= "table" or type(vec2.new) ~= "function" then
        local ok, mod = pcall(require, "common/geometry/vector_2")
        if ok and type(mod) == "table" and type(mod.new) == "function" then vec2 = mod end
    end
    if type(vec3) ~= "table" or type(vec3.new) ~= "function" then
        local ok, mod = pcall(require, "common/geometry/vector_3")
        if ok and type(mod) == "table" and type(mod.new) == "function" then vec3 = mod end
    end
end

M.AOE_RADIUS = {
    SELF_8 = 8,
    SELF_10 = 10,
    GROUND_5 = 5,
    GROUND_8 = 8,
    GROUND_10 = 10,
    TARGET_8 = 8,
    TARGET_10 = 10,
    TARGET_15 = 15,
}

-- Frontal cone half-angle (radians). Full opening ~90° (π/2).
-- Facing yaw → forward unit via (sin θ, cos θ) so facing=0 is +Y (matches prior ESP radar).
-- Sector test: unit offset · forward >= cos(half_angle) (vec2 :dot / length_squared).
M.CONE_HALF_ANGLE = math.pi / 4  -- ±45° from facing → 90° cone
M.GROUND_MAX_RANGE = 35           -- default cast max range for ground circles

--- Build a vec3 from a position table / unit get_position result.
function M.as_vec3(pos)
    if not pos then return nil end
    if type(pos.x) ~= "number" or type(pos.y) ~= "number" then return nil end
    local z = type(pos.z) == "number" and pos.z or 0
    if vec3 and vec3.new then
        return vec3.new(pos.x, pos.y, z)
    end
    return { x = pos.x, y = pos.y, z = z }
end

local function unit_pos_raw(unit)
    if not unit then return nil end
    if type(unit.get_position) == "function" then
        local ok, p = pcall(unit.get_position, unit)
        if ok and type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then
            return p
        end
    end
    if type(unit.x) == "number" and type(unit.y) == "number" then
        return unit
    end
    return nil
end

--- Horizontal (ignore-z) squared distance between two world positions via vec3 when available.
function M.squared_dist_xy(a, b)
    if not a or not b then return math.huge end
    local va = M.as_vec3(a)
    local vb = M.as_vec3(b)
    if not va or not vb then return math.huge end
    if type(va.squared_dist_to_ignore_z) == "function" then
        return va:squared_dist_to_ignore_z(vb)
    end
    local dx = (va.x or 0) - (vb.x or 0)
    local dy = (va.y or 0) - (vb.y or 0)
    return dx * dx + dy * dy
end

local function dist(a, b)
    if not a or not b then return 999 end
    -- Prefer vec3 horizontal distance when both units expose positions
    local pa = unit_pos_raw(a)
    local pb = unit_pos_raw(b)
    if pa and pb then
        local va, vb = M.as_vec3(pa), M.as_vec3(pb)
        if va and vb and type(va.dist_to_ignore_z) == "function" then
            return va:dist_to_ignore_z(vb)
        end
        local d2 = M.squared_dist_xy(pa, pb)
        if d2 < math.huge then return math.sqrt(d2) end
    end
    if NS.unit_distance then
        local d = NS.unit_distance(a, b)
        if type(d) == "number" then return d end
    end
    if a.get_distance then
        local ok, d = pcall(a.get_distance, a, b)
        if ok and type(d) == "number" then return d end
    end
    if a.distance_to then
        local ok, d = pcall(a.distance_to, a, b)
        if ok and type(d) == "number" then return d end
    end
    return 999
end

local function safe_player()
    if not NS.GetPlayer then return nil end
    local ok, me = pcall(NS.GetPlayer, NS)
    if ok and me then return me end
    ok, me = pcall(NS.GetPlayer)
    if ok then return me end
    return nil
end

function M.count_enemies_around_me(radius)
    local r = type(radius) == "number" and radius or 8
    local r2 = r * r
    local me = safe_player()

    -- IZI SDK fast-path: get_enemies_in_splash_range_count on player object
    if me and type(me.get_enemies_in_splash_range_count) == "function" then
        local ok, count = pcall(me.get_enemies_in_splash_range_count, me, r)
        if ok and type(count) == "number" then return count end
    end

    local me_p = me and unit_pos_raw(me) or nil

    -- Prefer live list + vec3 horizontal squared distance when player position is known.
    -- Call through NS.squared_dist_xy when installed so tests can spy the shipped path.
    local sq_xy = (NS and type(NS.squared_dist_xy) == "function" and NS.squared_dist_xy) or M.squared_dist_xy
    if me_p and NS.GetEnemiesInRange then
        local ok_list, list = pcall(NS.GetEnemiesInRange, r)
        if ok_list and type(list) == "table" then
            local n = 0
            local limit = list.n or #list
            for i = 1, limit do
                local e = list[i]
                if e and e ~= me then
                    local ep = unit_pos_raw(e)
                    if ep then
                        if sq_xy(me_p, ep) <= r2 then n = n + 1 end
                    else
                        -- No enemy pos: keep list membership (OM already range-filtered)
                        n = n + 1
                    end
                end
            end
            return n
        end
    end

    if NS.GetEnemiesCount then
        local ok, n = pcall(NS.GetEnemiesCount, r)
        if ok then return n or 0 end
    end
    return 0
end

--- True if enemy is inside horizontal radius of origin when both have positions (vec3 path).
--- When positions missing, falls back to unit dist() API.
local function enemy_in_radius(origin_unit, origin_pos, enemy, r, r2)
    if not enemy then return false end
    local ep = unit_pos_raw(enemy)
    if origin_pos and ep then
        local sq_xy = (NS and type(NS.squared_dist_xy) == "function" and NS.squared_dist_xy) or M.squared_dist_xy
        return sq_xy(origin_pos, ep) <= r2
    end
    local d = dist(enemy, origin_unit)
    return type(d) == "number" and d < 100 and d <= r
end

function M.count_enemies_around_unit(unit, radius)
    if not unit then return 0 end
    local r = type(radius) == "number" and radius or 8
    local r2 = r * r
    local me = safe_player()
    local n = 0
    local origin_pos = unit_pos_raw(unit)

    -- IZI SDK fast-path: get_enemies_in_splash_range_count is a native O(1) API
    -- that counts enemies within (meters + target_radius) of this unit, PvP-aware.
    -- Prefer this over manual spatial math whenever available.
    if type(unit.get_enemies_in_splash_range_count) == "function" then
        local ok, count = pcall(unit.get_enemies_in_splash_range_count, unit, r)
        if ok and type(count) == "number" then return count end
    end

    -- Unit-native list: still re-filter with vec3 horizontal distance when positions exist
    -- (never treat get_enemies_in_range as sole authority if we can do accurate math).
    local get_eir = unit.get_enemies_in_range
    if type(get_eir) == "function" then
        local ok, list = pcall(get_eir, unit, r, false)
        if ok and type(list) == "table" then
            local has_any_pos = origin_pos ~= nil
            for i = 1, #list do
                local e = list[i]
                if e and (not me or e ~= me) then
                    if has_any_pos then
                        if enemy_in_radius(unit, origin_pos, e, r, r2) then n = n + 1 end
                    else
                        n = n + 1
                    end
                end
            end
            -- Include origin unit if hostile and positions say it is the cluster center
            if origin_pos and me and unit ~= me then
                local seen = false
                for i = 1, #list do
                    if list[i] == unit or (NS.same_unit and NS.same_unit(list[i], unit)) then
                        seen = true
                        break
                    end
                end
                if not seen then
                    -- Origin is the radius center → distance 0, always inside
                    n = n + 1
                end
            end
            return n
        end
    end

    local d_me = me and dist(unit, me) or nil
    local scan = 40
    if type(d_me) == "number" and d_me < 100 then
        scan = d_me + r + 2
        if scan > 45 then scan = 45 end
        if scan < r then scan = r end
    end

    local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(scan) or nil
    if type(enemies) == "table" and (#enemies > 0 or (enemies.n and enemies.n > 0)) then
        local limit_n = enemies.n or #enemies
        local seen = false
        for i = 1, limit_n do
            local e = enemies[i]
            if e and enemy_in_radius(unit, origin_pos, e, r, r2) then
                n = n + 1
                if e == unit or (NS.same_unit and NS.same_unit(e, unit)) then seen = true end
            end
        end
        if not seen and me and unit ~= me then
            local d_origin = dist(unit, me)
            if type(d_origin) == "number" and d_origin < 100 then
                n = n + 1
            end
        end
        return n
    end

    -- Empty list → 0 (allows density fallback in tests; never invent 1 from Attack-range).
    return 0
end

function M.aoe_count_meets(min_count, radius, opts)
    opts = opts or {}
    local need = type(min_count) == "number" and min_count or 1
    local r = type(radius) == "number" and radius or 8
    local ctx = opts.context
    if ctx and type(ctx._aoe_hit_count) == "number" then
        return ctx._aoe_hit_count >= need, ctx._aoe_hit_count
    end

    local n
    if (opts.around == "target") and opts.target then
        n = M.count_enemies_around_unit(opts.target, r)
    else
        n = M.count_enemies_around_me(r)
    end
    n = n or 0

    if n == 0 and ctx then
        local wide = 0
        if NS.GetEnemiesCount then
            local ok_w, w = pcall(NS.GetEnemiesCount, 40)
            if ok_w then wide = w or 0 end
        end
        if wide == 0 then
            local st = opts.state
            local best = nil
            local function consider(v)
                if type(v) == "number" and (best == nil or v > best) then best = v end
            end
            if st then
                consider(st.enemy_count)
                consider(st.target_count)
                consider(st.enemies)
            end
            consider(ctx.enemy_count)
            consider(ctx.enemies_count)
            if type(ctx.enemies) == "table" then consider(#ctx.enemies) end
            if best ~= nil then n = best end
        end
    end

    n = n or 0
    return n >= need, n
end

function M.aoe_self_meets(min_count, radius, context, state)
    return M.aoe_count_meets(min_count, radius, { around = "me", context = context, state = state })
end

function M.aoe_target_meets(min_count, radius, target, context, state)
    return M.aoe_count_meets(min_count, radius, { around = "target", target = target, context = context, state = state })
end

--- Read unit facing (yaw). Returns nil if unavailable.
local function unit_facing(unit)
    if not unit then return nil end
    if type(unit.get_rotation) == "function" then
        local ok, r = pcall(unit.get_rotation, unit)
        if ok and type(r) == "number" then return r end
    end
    if type(unit.get_facing) == "function" then
        local ok, r = pcall(unit.get_facing, unit)
        if ok and type(r) == "number" then return r end
    end
    return nil
end

local function unit_pos(unit)
    local p = unit_pos_raw(unit)
    return p and M.as_vec3(p) or nil
end

--- Forward unit vector (XY) from player yaw. facing=0 → +Y (ESP/radar convention).
--- Only yaw→vector conversion uses sin/cos; sector test is vec2 :dot after that.
function M.facing_forward_vec2(facing)
    if type(facing) ~= "number" then return nil end
    local fx = math.sin(facing)
    local fy = math.cos(facing)
    if vec2 and vec2.new then
        return vec2.new(fx, fy)
    end
    return { x = fx, y = fy }
end

--- True if world offset (dx,dy) from player is inside facing cone.
--- Uses vec2 length_squared + unit :dot with forward (not atan2 for the gate decision).
function M.offset_in_facing_cone(dx, dy, facing, half_angle)
    if type(dx) ~= "number" or type(dy) ~= "number" then return false end
    if type(facing) ~= "number" then return false end
    local ha = type(half_angle) == "number" and half_angle or M.CONE_HALF_ANGLE

    local offset
    if vec2 and vec2.new then
        offset = vec2.new(dx, dy)
    else
        offset = { x = dx, y = dy }
    end

    local d2
    if type(offset.length_squared) == "function" then
        d2 = offset:length_squared()
    else
        d2 = dx * dx + dy * dy
    end
    if d2 <= 1e-12 then return true end -- on top of caster

    local unit_off
    if type(offset.get_unit_vector) == "function" then
        unit_off = offset:get_unit_vector()
    elseif type(offset.normalize) == "function" then
        unit_off = offset:normalize()
    else
        local inv = 1 / math.sqrt(d2)
        unit_off = { x = dx * inv, y = dy * inv }
    end

    local forward = M.facing_forward_vec2(facing)
    if not forward then return false end

    local cos_a
    if type(unit_off.dot) == "function" then
        cos_a = unit_off:dot(forward)
    elseif vec2 and type(vec2.dot_product) == "function" then
        cos_a = vec2.dot_product(unit_off, forward)
    else
        cos_a = (unit_off.x or 0) * (forward.x or 0) + (unit_off.y or 0) * (forward.y or 0)
    end
    -- |angle| <= ha  ⇔  cos(angle) >= cos(ha) for ha in (0, π]
    return cos_a >= math.cos(ha)
end

--- True if point (vec3) is inside player-centered frontal sector of radius.
--- Radius: vec3 squared_dist_to_ignore_z via squared_dist_xy. Sector: vec2 :dot.
function M.point_in_facing_cone(origin, point, facing, half_angle, radius)
    if not origin or not point or type(facing) ~= "number" then return false end
    local r = type(radius) == "number" and radius or 10
    local sq_xy = (NS and type(NS.squared_dist_xy) == "function" and NS.squared_dist_xy) or M.squared_dist_xy
    local d2 = sq_xy(origin, point)
    if d2 > (r * r) then return false end
    -- Prefer vec2/vec3 subtraction for the offset when available
    local dx, dy
    if vec3 and vec3.new and type(origin.x) == "number" then
        local o = M.as_vec3(origin)
        local p = M.as_vec3(point)
        if o and p and getmetatable(o) and getmetatable(o).__sub then
            local delta = p - o
            dx, dy = delta.x, delta.y
        else
            dx = (point.x or 0) - (origin.x or 0)
            dy = (point.y or 0) - (origin.y or 0)
        end
    else
        dx = (point.x or 0) - (origin.x or 0)
        dy = (point.y or 0) - (origin.y or 0)
    end
    return M.offset_in_facing_cone(dx, dy, facing, half_angle)
end

--- Count hostiles in a player-facing sector (radius + half_angle).
--- opts: { me=, facing=, half_angle=, radius=, enemies=, me_pos= }
function M.count_enemies_in_cone(radius, half_angle, opts)
    opts = opts or {}
    local r = type(radius) == "number" and radius or 10
    local ha = type(half_angle) == "number" and half_angle or M.CONE_HALF_ANGLE
    local me = opts.me or safe_player()
    local facing = opts.facing
    if facing == nil and me then facing = unit_facing(me) end
    if type(facing) ~= "number" then return 0 end -- fail closed: no facing → no cone hits

    local me_p = opts.me_pos and M.as_vec3(opts.me_pos) or unit_pos(me)
    if not me_p then return 0 end

    local list = opts.enemies
    if type(list) ~= "table" then
        list = NS.GetEnemiesInRange and NS.GetEnemiesInRange(r) or nil
    end
    if type(list) ~= "table" then return 0 end

    local n = 0
    local limit = list.n or #list
    for i = 1, limit do
        local e = list[i]
        if e and (not me or e ~= me) then
            local ep = unit_pos(e)
            if ep and M.point_in_facing_cone(me_p, ep, facing, ha, r) then
                n = n + 1
            end
        end
    end
    return n
end

--- True when min_count enemies sit in the frontal cone.
function M.aoe_cone_meets(min_count, radius, half_angle, context, state, opts)
    opts = opts or {}
    local need = type(min_count) == "number" and min_count or 1
    local r = type(radius) == "number" and radius or 10
    local ha = type(half_angle) == "number" and half_angle or M.CONE_HALF_ANGLE
    local ctx = context or opts.context

    if ctx and type(ctx._aoe_cone_hit_count) == "number" then
        return ctx._aoe_cone_hit_count >= need, ctx._aoe_cone_hit_count
    end
    if ctx and type(ctx._aoe_hit_count) == "number" and opts.use_generic_hit_count then
        return ctx._aoe_hit_count >= need, ctx._aoe_hit_count
    end

    local me = (ctx and ctx.me) or safe_player()
    local facing = opts.facing
    if facing == nil and me then facing = unit_facing(me) end
    if facing == nil and ctx and type(ctx.facing) == "number" then facing = ctx.facing end
    if facing == nil and ctx and type(ctx.player_rotation) == "number" then facing = ctx.player_rotation end

    -- No facing API: fall back to self-circle of same radius (unit tests / missing get_rotation).
    if type(facing) ~= "number" then
        return M.aoe_self_meets(need, r, ctx, state or opts.state)
    end

    local n = M.count_enemies_in_cone(r, ha, {
        me = me,
        facing = facing,
        me_pos = opts.me_pos,
        enemies = opts.enemies or (ctx and ctx.enemies) or nil,
    })
    n = n or 0

    -- Empty cone + empty wide OM → density fallback for unit tests that set enemy_count
    if n == 0 and ctx then
        local wide = 0
        if NS.GetEnemiesCount then
            local ok_w, w = pcall(NS.GetEnemiesCount, 40)
            if ok_w then wide = w or 0 end
        end
        if wide == 0 then
            local st = state or opts.state
            local best = nil
            local function consider(v)
                if type(v) == "number" and (best == nil or v > best) then best = v end
            end
            if st then consider(st.enemy_count); consider(st.enemies) end
            consider(ctx.enemy_count)
            if type(ctx.enemies) == "table" then consider(#ctx.enemies) end
            if best ~= nil then n = best end
        end
    end

    return n >= need, n
end

--- Normalize a world position to a vec3-shaped table for ground casts.
function M.ensure_vec3_position(pos)
    if not pos then return nil end
    local v = M.as_vec3(pos)
    if not v then return nil end
    -- Always return a plain-compatible vec3 with x/y/z (engine cast APIs accept both).
    if vec3 and vec3.new then
        return vec3.new(v.x or 0, v.y or 0, v.z or 0)
    end
    return { x = v.x or 0, y = v.y or 0, z = v.z or 0 }
end

--- Place + cast a ground-circle AoE using the same radius as the multi gate.
--- Cast position is vec3-shaped (from prediction / target get_position).
function M.cast_ground_aoe(spell, target, radius, max_range, message, opts)
    if not spell or not target then return false end
    local r = type(radius) == "number" and radius or (M.AOE_RADIUS.GROUND_8 or 8)
    local mr = type(max_range) == "number" and max_range or M.GROUND_MAX_RANGE
    opts = opts or {}
    local min_hits = opts.min_hits or 1
    local spell_id = nil
    if NS.get_spell_id then
        local ok, id = pcall(NS.get_spell_id, spell)
        if ok then spell_id = id end
    end
    if not spell_id and type(spell) == "number" then spell_id = spell end
    if not spell_id and type(spell) == "table" and spell.id then spell_id = spell.id end

    if spell_id and NS.get_aoe_cast_position then
        local pos, hits = NS.get_aoe_cast_position(spell_id, target, r, mr, min_hits)
        pos = M.ensure_vec3_position(pos)
        if pos and NS.try_cast_position then
            return NS.try_cast_position(spell, pos, target, message, opts) and true or false
        end
    end
    if NS.try_cast then
        return NS.try_cast(spell, target, message, opts) and true or false
    end
    return false
end

--- Install helpers onto NS.
--- Geometry helpers ALWAYS replace prior NS bindings so core hand-rolled
--- distance()/GetEnemiesCount-only paths cannot shadow vec2/vec3 math.
function M.install(ns)
    ns = ns or NS
    if not ns then return M end
    ns.AOE_RADIUS = ns.AOE_RADIUS or M.AOE_RADIUS
    for k, v in pairs(M.AOE_RADIUS) do
        if ns.AOE_RADIUS[k] == nil then ns.AOE_RADIUS[k] = v end
    end
    ns.CONE_HALF_ANGLE = M.CONE_HALF_ANGLE
    ns.GROUND_MAX_RANGE = M.GROUND_MAX_RANGE
    -- Force shared hit-volume implementations (vec2/vec3) over any core stubs.
    ns.count_enemies_around_me = M.count_enemies_around_me
    ns.count_enemies_around_unit = M.count_enemies_around_unit
    ns.aoe_count_meets = M.aoe_count_meets
    ns.aoe_self_meets = M.aoe_self_meets
    ns.aoe_target_meets = M.aoe_target_meets
    ns.offset_in_facing_cone = M.offset_in_facing_cone
    ns.count_enemies_in_cone = M.count_enemies_in_cone
    ns.aoe_cone_meets = M.aoe_cone_meets
    ns.cast_ground_aoe = M.cast_ground_aoe
    ns.as_vec3 = M.as_vec3
    ns.ensure_vec3_position = M.ensure_vec3_position
    ns.squared_dist_xy = M.squared_dist_xy
    ns.point_in_facing_cone = M.point_in_facing_cone
    ns.facing_forward_vec2 = M.facing_forward_vec2
    return M
end

M.install(NS)

return M
