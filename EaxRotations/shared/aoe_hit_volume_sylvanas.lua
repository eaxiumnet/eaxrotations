-- aoe_hit_volume_sylvanas.lua
-- WHAT: Hit-volume enemy counts for multi-target damage gates (not 40yd fight density).
-- WHEN: Required by core and by specs that gate AoE/cleave; safe in unit tests without core.
-- WHY:  Prevent false multi when enemies are only in the global 40yd scan.
-- SAFETY: Pure counting; no casts. Falls back to context.enemy_count only when
--         spatial APIs return no units at all (empty OM / unit tests).

local M = {}
local NS = _G.EaxRotations
if not NS then return M end

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

local function dist(a, b)
    if not a or not b then return 999 end
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
    if NS.GetEnemiesCount then
        local ok, n = pcall(NS.GetEnemiesCount, r)
        if ok then return n or 0 end
    end
    return 0
end

function M.count_enemies_around_unit(unit, radius)
    if not unit then return 0 end
    local r = type(radius) == "number" and radius or 8
    local me = safe_player()
    local n = 0

    local get_eir = unit.get_enemies_in_range
    if type(get_eir) == "function" then
        local ok, list = pcall(get_eir, unit, r, false)
        if ok and type(list) == "table" then
            for i = 1, #list do
                if list[i] and (not me or list[i] ~= me) then n = n + 1 end
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
            if e then
                local d = dist(e, unit)
                if type(d) == "number" and d < 100 and d <= r then
                    n = n + 1
                    if e == unit or (NS.same_unit and NS.same_unit(e, unit)) then seen = true end
                end
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
            -- Density fallback for empty OM / unit tests. Take the best available
            -- signal (state.target_count often mirrors multi-target for shaman, etc.).
            local best = nil
            local function consider(v)
                if type(v) == "number" and (best == nil or v > best) then best = v end
            end
            if st then
                consider(st.enemy_count)
                consider(st.target_count)
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

--- Install helpers onto NS (idempotent). Safe to call from specs and core.
function M.install(ns)
    ns = ns or NS
    if not ns then return M end
    ns.AOE_RADIUS = ns.AOE_RADIUS or M.AOE_RADIUS
    for k, v in pairs(M.AOE_RADIUS) do
        if ns.AOE_RADIUS[k] == nil then ns.AOE_RADIUS[k] = v end
    end
    ns.count_enemies_around_me = ns.count_enemies_around_me or M.count_enemies_around_me
    ns.count_enemies_around_unit = ns.count_enemies_around_unit or M.count_enemies_around_unit
    ns.aoe_count_meets = ns.aoe_count_meets or M.aoe_count_meets
    ns.aoe_self_meets = ns.aoe_self_meets or M.aoe_self_meets
    ns.aoe_target_meets = ns.aoe_target_meets or M.aoe_target_meets
    return M
end

M.install(NS)

return M
