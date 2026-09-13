-- cast_reject_guard_sylvanas.lua -- engine-confirmed rejected-cast hold.
-- WHAT:  remembers abilities the game itself just refused (UNIT_SPELLCAST_FAILED
--        / UNIT_SPELLCAST_FAILED_QUIET for the local player) and holds them for
--        a short window so the central cast guard stops re-queueing a cast the
--        client is actively rejecting.
-- WHEN:  installed once by main_sylvanas (M.install(NS)); consulted once per
--        NS.evaluate_cast().
-- WHY:   a lane that matches but cannot be cast -- invalid target, wrong weapon,
--        missing reagent, immune target -- re-matched on the very next frame and
--        re-queued the same spell forever. That is the "Feint / Slice and Dice
--        invalid target" spam and the same class as the earlier Backstab /
--        Mortal Strike reports: the rotation never learns the client refused.
--        Only the engine knows a cast failed, so the hold is driven by the
--        engine's own failure event rather than by a guessed precondition.
-- SAFETY: FAIL-OPEN. No installed namespace, no time source, or no failure event
--         (old client) => is_held() is always false and the cast path behaves
--         exactly as it did before this module existed. Allocates only on a
--         rejection (rare), never per frame: the hot-path read is one table
--         index plus a comparison. HOLD_SEC is deliberately short -- it only has
--         to outlive the dispatcher's 0.05s re-match cadence, not the ability.
-- DECISION: holds the offered SPELL ID only (not spell+target). The client
--         refuses the ability in that state, so a different valid target is not
--         a reason to trust the same ability within the same GCD window. The
--         guard is opt-outable per call via opts.skip_reject_hold.

local M = {}

-- How long an engine refusal keeps the ability out of the offer loop. The
-- dispatcher runs at 20Hz (0.05s), so this is ~12 frames: long enough to break
-- the re-request loop and hand the GCD to the next lane, short enough that a
-- transient refusal (moving, target switched) resolves on its own.
M.HOLD_SEC = 0.6

-- Safety valve: rejections are pruned as they expire, but a pathological burst
-- of distinct refused ids must not grow the table without bound.
M.MAX_TRACKED = 256

-- Injected by M.install -- never captured at require time (the battery's
-- shared-virgin guard forbids require-time binding to the live namespace).
local _NS = nil
local _time_now = nil
local _rejected = {}   -- spell_id -> time of the engine's refusal
local _size = 0
local _writes = 0
local PRUNE_EVERY = 16

--- Current time, or nil when no clock is available (which makes the guard a
--- no-op rather than holding forever).
local function current_time()
    local fn = _time_now
    if not fn then return nil end
    local ok, t = pcall(fn)
    if ok and type(t) == "number" then return t end
    return nil
end

--- Drop every entry that has already expired. Returns the surviving count.
-- Iterating with pairs() while clearing the current key is legal in Lua 5.1.
local function prune(t)
    local live = 0
    for id, ts in pairs(_rejected) do
        if (t - ts) >= M.HOLD_SEC then
            _rejected[id] = nil
        else
            live = live + 1
        end
    end
    return live
end

--- Record that the engine refused this spell id.
-- @param spell_id number  Ability the client rejected.
-- @param t number|nil     Refusal time; defaults to the injected clock.
-- @return boolean true when the refusal was recorded.
function M.note_reject(spell_id, t)
    if type(spell_id) ~= "number" or spell_id <= 0 then return false end
    if t == nil then t = current_time() end
    if type(t) ~= "number" then return false end
    if _rejected[spell_id] == nil then
        _size = _size + 1
    end
    _rejected[spell_id] = t
    _writes = _writes + 1
    if _writes >= PRUNE_EVERY or _size > M.MAX_TRACKED then
        _writes = 0
        _size = prune(t)
    end
    return true
end

--- Seconds still to go on the hold for this spell, 0 when it is not held.
-- @param spell_id number
-- @param t number|nil  Time to evaluate against; defaults to the injected clock.
-- @return number
function M.remaining(spell_id, t)
    if type(spell_id) ~= "number" or spell_id <= 0 then return 0 end
    local ts = _rejected[spell_id]
    if not ts then return 0 end
    if t == nil then t = current_time() end
    if type(t) ~= "number" then return 0 end
    local left = M.HOLD_SEC - (t - ts)
    if left > 0 then return left end
    return 0
end

--- True while the engine's refusal of this spell is still fresh.
-- @param spell_id number
-- @param t number|nil
-- @return boolean
function M.is_held(spell_id, t)
    return M.remaining(spell_id, t) > 0
end

--- Number of tracked refusals (diagnostics / audits).
function M.count()
    local n = 0
    for _ in pairs(_rejected) do n = n + 1 end
    return n
end

--- Clear every tracked refusal (tests and the per-generation reset).
function M.reset()
    _rejected = {}
    _size = 0
    _writes = 0
end

-- ---------------------------------------------------------------------------
-- Engine events
-- ---------------------------------------------------------------------------
-- args[1] is the CASTER'S UNIT TOKEN ("player", "target", "nameplate7"), never
-- a GUID, and args[3] is the spell id -- see the UNIT_SPELLCAST_* contract in
-- .api/core.lua. Only the local player's refusals may hold OUR offers; a refused
-- cast by any other unit must never hold our spell, so the token filter is
-- load-bearing rather than defensive.
local function on_game_event(event_name, args)
    if event_name ~= "UNIT_SPELLCAST_FAILED"
        and event_name ~= "UNIT_SPELLCAST_FAILED_QUIET" then return end
    if type(args) ~= "table" then return end
    if args[1] ~= "player" then return end
    M.note_reject(args[3])
end

local _registered = false

--- Subscribe to the engine's refusal events. Idempotent; called by install()
--- and re-callable so a late-loaded namespace still binds.
-- @return boolean true when at least one subscription landed.
function M.try_register()
    if _registered then return true end
    if type(_NS) ~= "table" or type(_NS.register_on_game_event) ~= "function" then
        return false
    end
    local ok_failed = pcall(_NS.register_on_game_event, "UNIT_SPELLCAST_FAILED", on_game_event)
    local ok_quiet = pcall(_NS.register_on_game_event, "UNIT_SPELLCAST_FAILED_QUIET", on_game_event)
    if ok_failed or ok_quiet then
        _registered = true
        return true
    end
    return false
end

--- Bind the guard to a live namespace. Called once by the dispatcher loader.
-- @param ns table  The EaxRotations namespace.
-- @return boolean true when the namespace was accepted.
function M.install(ns)
    if type(ns) ~= "table" then return false end
    _NS = ns
    if type(ns.time_now) == "function" then _time_now = ns.time_now end
    ns.CastRejectGuard = M
    M.try_register()
    return true
end

return M
