-- active_fight_tracker_sylvanas.lua — Active fight / engagement tracker (GUID-only) for multi-DoT and general DoT/bleed users (shadow, affliction, hunter, etc.).
-- WHAT:  Throttled (0.5s) GUID tracking of engaged enemies via Engagement filter; fresh live units + strict missing-debuff finder.
-- WHEN:  Called from build_state/match in multi-dot and DoT specs.
-- WHY:   Reusable single source of truth to avoid dotting non-fights; GUID-only + fresh-units contract.
-- SAFETY: pcall everywhere, static tables, no long-lived refs, nil-guards; PR1 standalone reuses filter.

local M = {}
local NS = _G.EaxRotations
if not NS then return M end

-- Re-use the engagement filter (pcall for robustness)
local _eng_ok, Engagement = pcall(require, "shared/multidot_engagement_filter_sylvanas")
if not _eng_ok then Engagement = nil end

-- Core data model: GUID-only (Pattern from design)
local _active = {}  -- [guid] = { last_seen = number }

local _last_scan = -1
local SCAN_INTERVAL = 0.5

-- Cached API at load (Pattern 2) — getters for Get* resolved at call time (tests may override fields post-require)
local _time_now = NS.time_now or function() return 0 end
local _same_unit = NS.same_unit or function(a, b) return a == b end
local _debuff_up = NS.debuff_up or function() return false end

-- Static reusable tables (Pattern 4) — no per-call allocs
local _out_fights = { n = 0 }
local _seen_guids = { n = 0 }

local function _now()
    local ok, t = pcall(_time_now)
    return (ok and type(t) == "number" and t) or 0
end

local function _get_guid(unit)
    if not unit then return nil end
    local ok, g = pcall(function()
        local fn = unit.get_guid or unit.guid or unit.GetGUID
        if type(fn) == "function" then return fn(unit) end
        return unit.guid or unit.id or tostring(unit)
    end)
    if ok and g and g ~= "" then return tostring(g) end
    return tostring(unit)
end

-- Update _active GUID set from a fresh engaged unit list (prune absent)
local function _update_from_engaged(engaged)
    local now = _now()
    -- reset seen static (collect to avoid pairs() mutation)
    _seen_guids.n = 0
    local ks = {}
    for k in pairs(_seen_guids) do if k ~= "n" then ks[#ks + 1] = k end end
    for _, k in ipairs(ks) do _seen_guids[k] = nil end

    local cnt = (type(engaged) == "table" and (engaged.n or #engaged)) or 0
    for i = 1, cnt do
        local u = engaged[i]
        local g = _get_guid(u)
        if g then
            _seen_guids.n = _seen_guids.n + 1
            _seen_guids[g] = true
            if not _active[g] then
                _active[g] = { last_seen = now }
            else
                _active[g].last_seen = now
            end
        end
    end

    -- Prune GUIDs no longer present in this engaged set
    local to_del = {}
    for g in pairs(_active) do if not _seen_guids[g] then to_del[#to_del + 1] = g end end
    for _, g in ipairs(to_del) do _active[g] = nil end
end

local function _internal_scan_and_update(range)
    local now = _now()
    if (now - _last_scan) < SCAN_INTERVAL then return end
    _last_scan = now

    local getp = (NS and NS.GetPlayer) or function() return nil end
    local ok, me = pcall(getp)
    me = ok and me or nil

    local gete = (NS and NS.GetEnemiesInRange) or function() return {} end
    local r = range or 40
    local ok2, raw = pcall(gete, r)
    raw = (ok2 and type(raw) == "table") and raw or {}

    local engaged = raw
    if Engagement and Engagement.filter_engaged_enemies then
        local ok3, eng = pcall(Engagement.filter_engaged_enemies, raw, me, { strictness = "strict" })
        if ok3 and eng then engaged = eng end
    end

    _update_from_engaged(engaged)
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Return current active fights as fresh live units (re-filter every call for liveness contract).
-- Callers must not retain the table across frames.
function M.get_active_fights(range)
    range = range or 40
    -- Always produce fresh units via current filter (contract)
    local getp = (NS and NS.GetPlayer) or function() return nil end
    local ok, me = pcall(getp)
    me = ok and me or nil

    local gete = (NS and NS.GetEnemiesInRange) or function() return {} end
    local ok2, raw = pcall(gete, range)
    raw = (ok2 and type(raw) == "table") and raw or {}

    local engaged = raw
    if Engagement and Engagement.filter_engaged_enemies then
        local ok3, eng = pcall(Engagement.filter_engaged_enemies, raw, me, { strictness = "strict" })
        if ok3 and eng then engaged = eng end
    end

    -- Still run throttled scan to keep _active GUIDs in sync + prune (use caller's range for consistency)
    _internal_scan_and_update(range)

    -- Copy to static output (no alloc churn; collect to avoid pairs mutation)
    _out_fights.n = 0
    local ks = {}
    for k in pairs(_out_fights) do if k ~= "n" then ks[#ks + 1] = k end end
    for _, k in ipairs(ks) do _out_fights[k] = nil end
    local cnt = (engaged.n or #engaged) or 0
    for i = 1, cnt do
        _out_fights.n = _out_fights.n + 1
        _out_fights[_out_fights.n] = engaged[i]
    end
    return _out_fights
end

--- Number of currently tracked active fights (from GUID set, after throttle scan).
function M.count()
    _internal_scan_and_update()
    local c = 0
    for _ in pairs(_active) do c = c + 1 end
    return c
end

--- Find a target strictly missing the debuff(s), preferring non-current target.
-- Uses fresh active fights; strict = !debuff_up (no fuzzy remains).
-- @param context table with .me, .target optional
-- @param debuff_ids table
-- @param range number|nil
-- @return game_object|nil
function M.find_undotted_target(context, debuff_ids, range)
    if not context or not debuff_ids then return nil end
    range = range or 30

    local fights = M.get_active_fights(range)
    local curr = context.target
    local cnt = fights.n or #fights
    if cnt == 0 then return nil end

    local best = nil
    local best_hp = 101

    for i = 1, cnt do
        local u = fights[i]
        if u then
            local has = false
            local okd, h = pcall(_debuff_up, u, debuff_ids)
            if okd then has = h end
            if not has then
                local is_curr = false
                if curr then
                    local ok, same = pcall(_same_unit, u, curr)
                    is_curr = ok and same
                end
                if not is_curr then
                    local hp = 100
                    local okh, val = pcall(function()
                        return u.get_health_percentage and u:get_health_percentage() or 100
                    end)
                    if okh and type(val) == "number" then hp = val end
                    if hp < best_hp then
                        best = u
                        best_hp = hp
                    end
                end
            end
        end
    end

    -- Fallback to current if it is the only undotted (strict missing on it)
    if not best then
        for i = 1, cnt do
            local u = fights[i]
            if u then
                local has = false
                local okd, h = pcall(_debuff_up, u, debuff_ids)
                if okd then has = h end
                if not has then
                    best = u
                    break
                end
            end
        end
    end

    return best
end

--- Force prune of stale GUIDs (for tests / explicit).
function M.prune()
    local now = _now()
    local to_del = {}
    for g, meta in pairs(_active) do
        if not meta or (now - (meta.last_seen or 0)) > 60 then
            to_del[#to_del + 1] = g
        end
    end
    for _, g in ipairs(to_del) do _active[g] = nil end
end

--- Reset all tracked fights (e.g. on combat end).
function M.reset()
    local to_del = {}
    for k in pairs(_active) do to_del[#to_del + 1] = k end
    for _, k in ipairs(to_del) do _active[k] = nil end
    _last_scan = -1
    -- clear statics (collect first to avoid pairs mutation)
    _out_fights.n = 0
    local ks = {}
    for k in pairs(_out_fights) do if k ~= "n" then ks[#ks + 1] = k end end
    for _, k in ipairs(ks) do _out_fights[k] = nil end
    _seen_guids.n = 0
    ks = {}
    for k in pairs(_seen_guids) do if k ~= "n" then ks[#ks + 1] = k end end
    for _, k in ipairs(ks) do _seen_guids[k] = nil end
end

--- Debug helper.
function M.debug_dump()
    local parts = {}
    for g in pairs(_active) do parts[#parts+1] = tostring(g) end
    return "active_fight_tracker GUIDs(" .. #parts .. "): " .. table.concat(parts, ",")
end

--- on_update stub (future wiring point; no-op for PR1 standalone).
function M.on_update(context)
    -- Intentionally empty in PR1. Future: may call _internal... or context hooks.
end

-- Expose (consistent with Engagement module)
if NS then
    NS.ActiveFightTracker = M
end

return M
