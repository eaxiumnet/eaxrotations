-- periodic_cycler_sylvanas.lua -- one owner for "which unit gets the next periodic effect".
--
-- WHAT:  picks the next target for a periodic effect and rotates across equally
--        valid candidates so consecutive spreads move on instead of re-picking
--        the unit that was just covered. Two sides, one engine:
--          enemy    a DoT on an engaged hostile (SW:P, VT, Corruption, ...)
--          friendly a HoT on an injured ally (Rejuvenation, Regrowth, ...)
--
-- WHEN:  called from spec build_state / match functions -- enemy side from a
--        spec's own spread picker (cursor/advance), friendly side from the
--        resto HoT lanes (friendly()).
--
-- WHY:   the two sides were asymmetric. Enemy spread pickers returned the single
--        "best" mob every call, so a two-mob spread could hammer the same mob
--        forever. Friendly HoTs only ever targeted context.lowest, so when the
--        lowest ally already carried the HoT no second injured ally was ever
--        covered -- the classic "two people at 60% and only one gets a HoT"
--        deficit.
--
-- OWNERSHIP: the cursor (cursor/advance) is the shared piece for BOTH sides.
--        Enemy candidate discovery stays with the spec -- each spec has its own
--        engagement/CC/snapshot gates -- so it reads the cursor while scanning
--        and advances it after a cast lands. Friendly discovery is uniform (the
--        party scan), so friendly() owns it end to end.
--
-- SAFETY: FAIL-OPEN and nil-safe. No party API / no buff reader / no candidate
--         => nil, and the caller keeps whatever it did before. The namespace is
--         read LAZILY at call time (never captured at require time), so the
--         mock-based suites bind correctly and the battery's shared-virgin
--         guard is untouched. No per-frame allocation: the only writes are the
--         per-key last-pick record.
--
-- DECISION: "cycling" = a sticky last-pick per key. The avoided unit is only
--         skipped while another equal-or-better candidate exists, so a solo
--         target is still covered -- a cycle must never starve the only unit
--         that needs the effect.

local M = {}

-- Cap on candidates examined per call (bounds the scan, never allocates).
local MAX_CANDIDATES = 40

local _last_pick = {}   -- key -> unit chosen last time (round-robin cursor)

local function ns()
    return _G.EaxRotations
end

--- The player unit, tolerating both engine idioms the specs/tests use:
--- a published `NS.me` field, or a `NS.GetPlayer` that may be defined either
--- as `function()` or as `function(self)` (the pure-mock spec-load suites stub
--- `GetPlayer = function(self) return self.me end`, so calling it with no
--- argument would raise). Never raises: an absent/broken accessor returns nil
--- and the caller falls back to its previous behavior.
local function player_unit(N)
    if N == nil then return nil end
    if N.me ~= nil then return N.me end
    local fn = N.GetPlayer
    if type(fn) ~= "function" then return nil end
    local ok, unit = pcall(fn, N)
    if ok then return unit end
    return nil
end

--- Health percentage of a unit, or the given default when the API is absent.
local function health_pct(unit, default)
    local N = ns()
    if N and type(N.unit_health_pct) == "function" then
        local ok, hp = pcall(N.unit_health_pct, unit)
        if ok and type(hp) == "number" then return hp end
    end
    local get = unit and unit.get_health_percentage
    if type(get) == "function" then
        local ok, hp = pcall(get, unit)
        if ok and type(hp) == "number" then return hp end
    end
    return default
end

--- True when the unit is alive; unknown units count as alive (fail-open).
local function is_alive(unit)
    local fn = unit and unit.is_alive
    if type(fn) ~= "function" then return true end
    local ok, alive = pcall(fn, unit)
    if not ok then return true end
    return alive ~= false
end

--- Remaining seconds of the first listed effect on the unit, 0 when down.
local function remains_of(unit, ids)
    local N = ns()
    if not (N and type(N.buff_remains) == "function") then return 0 end
    local ok, remains = pcall(N.buff_remains, unit, ids)
    if ok and type(remains) == "number" then return remains end
    return 0
end

-- ---------------------------------------------------------------------------
-- Cursor: which unit got the last periodic effect of a given kind.
-- ---------------------------------------------------------------------------
-- One bucket per effect set (key defaults to the first effect id), so Moonfire
-- and Insect Swarm cycle independently. The caller advances the cursor only
-- after the effect actually landed, so a mere candidate LOOKUP never rotates --
-- otherwise a throttled picker would spin the cursor with nothing applied.

--- The unit this key covered last time (nil before the first pick).
function M.cursor(key)
    if key == nil then return nil end
    return _last_pick[key]
end

--- Record the unit a periodic effect was applied to.
-- @param key  string
-- @param unit unit|nil  nil is ignored (a failed cast must not rotate)
function M.advance(key, unit)
    if key ~= nil and unit ~= nil then _last_pick[key] = unit end
end

-- ---------------------------------------------------------------------------
-- Friendly side: a HoT on an injured ally.
-- ---------------------------------------------------------------------------
--- Pick the next ally that still needs the HoT.
-- Candidates are the player plus the party list (the frames API excludes self).
-- The chosen unit is the most injured one that still needs the effect; when
-- none needs it, the one whose effect expires soonest wins (refresh cycling).
-- @param context    table
-- @param buff_ids   table  Effect ids that count as "already covered".
-- @param opts       table|nil
--   hp_below      number  only consider allies at or below this hp% (default 100)
--   refresh_below number  treat "remains <= this" as needing it (default 0)
--   refresh       boolean also return the soonest-expiring ally when nobody
--                 needs the effect (default false)
--   include_self  boolean candidate list includes the player (default true)
--   avoid_unit    unit    overrides the cycle cursor for this call
-- @param key        string|nil Cycle bucket; defaults to the first effect id.
-- @return unit|nil, number hp_pct, number remains
function M.friendly(context, buff_ids, opts, key)
    local N = ns()
    if not N then return nil end
    opts = opts or {}
    local pick_key = key or (buff_ids and buff_ids[1]) or "friendly"
    local avoid = opts.avoid_unit
    if avoid == nil then avoid = _last_pick[pick_key] end

    local hp_below = opts.hp_below or 100
    local refresh_below = opts.refresh_below or 0
    local me = player_unit(N)

    -- Primary bucket: a candidate that still needs the effect. Alt bucket: any
    -- candidate passing the hp gate. The avoided unit only wins the primary
    -- bucket when no other candidate does, so a lone target is never starved.
    local best, best_hp, best_rem, best_avoid = nil, 101, 0, false
    local alt, alt_hp, alt_rem = nil, 101, 0
    local seen = 0

    local function consider(unit)
        if not unit or seen >= MAX_CANDIDATES then return end
        seen = seen + 1
        if not is_alive(unit) then return end
        local hp = health_pct(unit, 100)
        if hp > hp_below then return end
        local rem = remains_of(unit, buff_ids)
        if hp < alt_hp or (hp == alt_hp and rem < alt_rem) then
            alt, alt_hp, alt_rem = unit, hp, rem
        end
        if rem > refresh_below then return end
        local is_avoid = (unit == avoid)
        -- A NON-cursor candidate always outranks the cursor one, so the next
        -- spread moves on; among equals (both cursor or both not) the most
        -- injured -- then the soonest-expiring -- wins. The cursor unit still
        -- wins when it is the only candidate, so a cycle never starves it.
        local better = (not best)
            or (best_avoid and not is_avoid)
            or (is_avoid == best_avoid and (hp < best_hp or (hp == best_hp and rem < best_rem)))
        if better then
            best, best_hp, best_rem, best_avoid = unit, hp, rem, is_avoid
        end
    end

    if opts.include_self ~= false then consider(me) end
    local members = nil
    if type(N.GetPartyMembers) == "function" then
        -- Same two idioms as GetPlayer: pass the namespace so a
        -- `function(self)` stub works, and never let a broken accessor raise.
        local ok, list = pcall(N.GetPartyMembers, N)
        if ok and type(list) == "table" then members = list end
    end
    if members then
        for i = 1, #members do consider(members[i]) end
    end

    local unit, hp, rem = best, best_hp, best_rem
    if not unit and opts.refresh then
        unit, hp, rem = alt, alt_hp, alt_rem
    end
    if not unit then return nil end
    _last_pick[pick_key] = unit
    return unit, hp, rem
end

--- Clear one bucket, or every bucket when key is nil.
function M.reset(key)
    if key == nil then _last_pick = {} else _last_pick[key] = nil end
end

return M
