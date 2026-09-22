-- shared/nav_destination.lua — who owns "where the bot walks next".
-- WHAT:  owns shared._nav_destination / _nav_unit_dest / _nav_unit_dest_key / _nav_engage_dest /
--        _nav_engage_sq, and settles what happens when more than one source wants to say where the
--        bot goes this tick. `claim()` asserts the pull gate's retreat over everything else;
--        `clear()` drops the destination and everything describing it.
-- WHEN:  nav_state resolves it at the top of every travelling tick (the state that issues the walk
--        and owns these fields); idle_state resolves it before it decides to hand the walk over;
--        pull_safety publishes the retreat it wants without writing anything here.
-- WHY:   The destination had four writers and no owner. pull_safety wrote the five fields itself,
--        so a retreat it armed could be silently replaced by whoever wrote last in the same tick —
--        and the bot would walk back into the group it had just backed away from. Precedence was
--        convention, spread over four files that each assumed they were the last writer.
--
--        Precedence, in one place:
--          1. The pull gate's retreat, while its hold is armed. It outranks every other source,
--             whoever wrote last, because it is re-asserted at the moment the destination is
--             consumed rather than once when it was decided.
--          2. A live-unit destination (a mob to close on) — a moving point, refreshed from the
--             unit by nav_state. It is only honoured while shared._nav_unit_dest_key still matches
--             the current destination, which is how a newer assignment invalidates it.
--          3. A plain point (waypoint, corpse, quest object, NPC spawn). Last writer wins, which
--             is correct: none of them moves.
--        A destination the gate's retreat replaces is CLEARED rather than left behind, so a stale
--        live-unit link cannot make nav_state re-issue a walk to the mob the retreat is fleeing.
-- SAFETY: table manipulation of the caller's shared table only; every probe nil-guarded; the
--        retreat is re-read from the gate (never cached), so an expired hold stops claiming at once;
--        `recently_unreachable` is asked per candidate per tick, so it allocates nothing.
-- DECISION: shared module rather than a state, so nav_state and idle_state can resolve the same
--        answer without a state -> state require. The gate keeps its own bookkeeping keys
--        (_pull_warned_at / _pull_overwait_at) — they are not navigation state.
-- NOTE:   The remaining writers (idle_state, do_action_state) still write the two main fields
--        directly. They are last-writer-wins sources like any other point, and the claim above
--        beats them at read time; migrating them onto this module is its own pass.

local M = {}

-- Hoisted require: this module is resolved on the travelling tick, and pull_safety is a pure
-- module with no load-time side effects. Cached after the first success only, so a test that
-- installs a stub later still gets it.
local _pull_safety = nil
local function pull_safety()
    if not _pull_safety then
        local ok, ps = pcall(require, "shared/pull_safety")
        if ok and ps then _pull_safety = ps end
    end
    return _pull_safety
end

--- The retreat the pull gate wants the bot to walk to right now, or nil when it wants nothing.
--- This is the gate's INTENT — it does not write the fields, this module does.
--- @param ctx table Per-tick context
--- @return table|nil vec3
function M.retreat(ctx)
    local ps = pull_safety()
    if not ps or not ps.destination then return nil end
    local ok, point = pcall(ps.destination, ctx)
    if ok then return point end
    return nil
end

--- Assert the gate's claim over the destination. Returns true when it applied.
--- The point is the one the gate already published (it remembers it), so re-asserting it while
--- the hold lives cannot turn a back-off into pacing.
--- @param shared table Shared state variables
--- @param ctx table Per-tick context
--- @return boolean claimed
function M.claim(shared, ctx)
    if not shared then return false end
    local point = M.retreat(ctx)
    if not point then return false end

    shared._nav_destination = point
    -- No live unit to follow and no stand-off to stop at: this is a place to stand, not something
    -- to approach. Leaving a stale link here is what would make nav_state re-issue walks toward
    -- the mob the retreat is leaving.
    shared._nav_unit_dest = nil
    shared._nav_unit_dest_key = nil
    shared._nav_engage_dest = nil
    shared._nav_engage_sq = nil
    return true
end

--- Drop the destination and every field describing it, so a later destination cannot inherit
--- state from this one. The caller's own travel bookkeeping (issued coordinates, re-issue clock)
--- is not this module's business and stays with whoever owns it.
--- @param shared table Shared state variables
function M.clear(shared)
    if not shared then return end
    shared._nav_destination = nil
    shared._nav_engage_dest = nil
    shared._nav_unit_dest = nil
    shared._nav_unit_dest_key = nil
end

-- ============================================================================
-- The unreachable memory — which places the client recently could not walk to
-- ============================================================================

-- How long a destination the client could not reach is left alone. It belongs here because it is a
-- fact about a PLACE, and three different files have to agree on which place it was: nav_state
-- (which discovers it), and the producers that would otherwise hand the same coordinates straight
-- back (idle_state's waypoint walk, and nav_state itself at the moment it issues a walk).
local UNREACHABLE_FOR = 60.0

--- Remember that this PLACE could not be reached. Must be called before the destination is
--- cleared, or with the point passed explicitly (a producer that has already replaced it).
---
--- The place is identified by its coordinates and nothing else: the PLACE is what the client
--- failed to reach, not how the destination was classified. Keying on the kind (a live unit, a
--- waypoint, a plain point) meant a destination that failed while nav_state was walking its
--- waypoint fallback was remembered under a name the producer could not reproduce, so the producer
--- handed the same coordinates straight back and the bot re-walked them forever.
---
--- One field holds the place and its window together, so nothing can copy or clear half of it.
--- @param shared table Shared state variables
--- @param now number
--- @param point table|nil vec3 that failed (defaults to the current destination)
function M.mark_unreachable(shared, now, point)
    if not shared then return end
    local d = point or shared._nav_destination
    if not d then
        shared._nav_unreachable = nil
        return
    end
    shared._nav_unreachable = {
        -- Tenths of a yard, as whole numbers: the question below is asked once per candidate per
        -- tick, and comparing integers costs no string and no table per call.
        x = math.floor((d.x or 0) * 10),
        y = math.floor((d.y or 0) * 10),
        expires = (now or 0) + UNREACHABLE_FOR,
    }
end

--- Is this point one the client recently could not reach?
--- @param shared table|nil Shared state variables
--- @param now number
--- @param point table|nil vec3 to ask about (defaults to the current destination)
--- @return boolean
function M.recently_unreachable(shared, now, point)
    if not shared then return false end
    local memory = shared._nav_unreachable
    if not memory or (now or 0) >= (memory.expires or 0) then return false end
    local d = point or shared._nav_destination
    if not d then return false end
    return math.floor((d.x or 0) * 10) == memory.x and math.floor((d.y or 0) * 10) == memory.y
end

-- ============================================================================
-- The retirement set — places refused often enough to give up on for this step
-- ============================================================================

-- A step's path is walked as a pass over its waypoints (idle_state's sweep). A waypoint the client
-- refuses is retired FOR THE STEP rather than re-offered every tick: otherwise a lap spends itself
-- on the one or two points the navmesh actually reaches and the rest of the objective's path is
-- never covered — live, "moves between 2 waypoints instead of routing all the objective
-- waypoints". The marks are cleared when the step changes (a new path says nothing about the old
-- refusals) and when a new pass starts (a transient refusal must not retire a real part of the
-- path for the whole step).
--
-- Keyed by the PLACE, for the same reason the memory above is: a producer reads the step's waypoint
-- list fresh every tick, and that list can SHIFT — the reader drops a waypoint whose map conversion
-- fails — so an index-keyed skip would retire a point other than the one the client refused, and
-- the sweep would then skip good waypoints while re-walking the bad one.
local EMPTY_SET = { n = 0 }

--- Retire a place for the rest of the step. Idempotent.
--- @param shared table Shared state variables
--- @param point table|nil vec3
--- @return boolean newly_retired
function M.retire_place(shared, point)
    if not shared or not point then return false end
    local set = shared._step_wp_retired
    if not set or set == EMPTY_SET then
        set = { n = 0 }
        shared._step_wp_retired = set
    end
    local x10, y10 = math.floor((point.x or 0) * 10), math.floor((point.y or 0) * 10)
    for i = 1, set.n do
        local e = set[i]
        if e.x == x10 and e.y == y10 then return false end
    end
    set.n = set.n + 1
    set[set.n] = { x = x10, y = y10 }
    return true
end

--- Has this place been retired for the current step?
--- @param shared table|nil Shared state variables
--- @param point table|nil vec3
--- @return boolean
function M.place_retired(shared, point)
    if not shared or not point then return false end
    local set = shared._step_wp_retired
    if not set then return false end
    local x10, y10 = math.floor((point.x or 0) * 10), math.floor((point.y or 0) * 10)
    for i = 1, set.n do
        local e = set[i]
        if e.x == x10 and e.y == y10 then return true end
    end
    return false
end

--- How many places are retired for the current step.
--- @param shared table|nil Shared state variables
--- @return number
function M.retired_count(shared)
    local set = shared and shared._step_wp_retired
    return (set and set.n) or 0
end

--- Forget every retirement (a new step, or a new pass over the same one).
--- @param shared table|nil Shared state variables
function M.clear_retired(shared)
    if not shared then return end
    -- The shared empty set is READ-ONLY: it is handed out here, so writing to it would retire a
    -- place on every shared table at once. Callers must never append to a set they did not create;
    -- retire_place makes its own when it is given this one.
    shared._step_wp_retired = EMPTY_SET
end

return M
