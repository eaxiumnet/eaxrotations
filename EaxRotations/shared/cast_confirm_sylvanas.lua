-- cast_confirm_sylvanas.lua -- engine-confirmed cast state machine.
--
-- WHAT:  the single owner of "what the engine said about the casts WE issued".
--        Every cast the addon queues is recorded (M.note_queued) and then
--        resolved against the engine's own cast events. A spell id is HELD --
--        kept out of the offer loop for HOLD_SEC -- when the engine either
--        (a) refused it (UNIT_SPELLCAST_FAILED / _FAILED_QUIET), or (b) never
--        said anything about it at all inside the confirmation window.
--
-- WHEN:  installed once by main_sylvanas (M.install(NS)). note_queued is called
--        from the central cast path (core_sylvanas mark_spell_cast) and is_held
--        from NS.evaluate_cast step 2b. Nothing else touches it.
--
-- WHY:   a lane that matches but cannot be cast re-matched on the very next
--        frame and re-queued the same spell forever -- the live "invalid target"
--        Feint / Slice and Dice spam. A queued cast dies without being cast in
--        two ways, and only the engine can say which:
--          loud  the client refuses it  -> FAILED / FAILED_QUIET (player token)
--          quiet the offer is swallowed -> no event of any kind ever arrives
--        Holding on both turns a 20Hz re-request loop into one attempt per hold;
--        the dispatcher falls through to the next lane while held.
--
-- SAFETY: FAIL-OPEN, twice over.
--         1. No installed namespace, no clock, or a client that emits none of
--            these events => is_held() is always false and the cast path is
--            byte-for-byte what it was before this module existed.
--         2. The quiet hold is DISARMED (M.armed() == false) until the engine
--            has proved it reports the player's casts at all, so a host that
--            never delivers them -- the battery harness, an older client --
--            can never see a timeout hold. Only a client that has already
--            spoken can be distrusted for going silent.
--         Allocates only when a cast is issued or an event arrives, never per
--         frame: the hot-path read of a non-held id is one table index and one
--         comparison, and does not touch the clock.
--
-- DECISION: holds the offered SPELL ID, not spell+target. The client refused the
--         ability in that state, so a different valid target is not a reason to
--         trust the same ability inside the same window. Opt-out stays per call
--         via opts.skip_reject_hold (the name carried over from the module this
--         one supersedes -- shared/cast_reject_guard_sylvanas.lua).
--
-- RESOURCE CHANNEL (UI_ERROR_MESSAGE) -- added 2026-09-14: the FAILED family
--         covers the client refusing a queued cast, but the other refusal class
--         arrives as a bare UI error with NO spell id: "Not enough rage",
--         "Ability is not ready yet", "Spell not learned". No handler was ever
--         registered for that event (live: the message repeated in the log
--         while Battle Shout re-queued every ~0.5s at 0 rage), so these
--         refusals never held anything. The error string is a Lua 5.1 vararg
--         and never carries the spell, so attribution goes through the
--         outstanding offer (_pending_id): an error arriving while WE have an
--         unresolved cast in flight holds THAT cast for RESOURCE_HOLD_SEC (1.5s
--         -- the 0.6s default just re-attempts an impossible cast at every GCD
--         boundary). Every UI error is treated as player-scoped; engine-event
--         attribution (SENT/START/SUCCEEDED) still wins on the spell id. This
--         channel is NOT an acknowledgement: it must never clear the pending
--         offer, and it does not arm the never-confirmed hold (an error alone
--         is not proof the client reports cast events).
--
-- EVENT CONTRACT (.api/core.lua, UNIT_SPELLCAST_* family):
--   { unit, cast_guid, spell_id }               START, SUCCEEDED, INTERRUPTED,
--                                               CHANNEL_START, FAILED, _QUIET
--   { unit, target_name, cast_guid, spell_id }  SENT  <- spell_id at index 4
--   unit is a TOKEN ("player"), never a GUID; the channel events leave a HOLE at
--   cast_guid but keep spell_id at index 3. A hard cast is SENT -> START ->
--   SUCCEEDED and an instant is SENT -> SUCCEEDED, so SENT alone proves the
--   client took the offer. STOP is deliberately NOT registered: it fires on
--   completion, self-cancel and kick alike, so it cannot resolve anything.

local M = {}

-- How long a verdict keeps an ability out of the offer loop. The dispatcher
-- runs at 20Hz (0.05s), so this is ~12 frames: long enough to break the
-- re-request loop and hand the GCD to the next lane, short enough that a
-- transient verdict (moving, target switched) resolves on its own.
M.HOLD_SEC = 0.6

-- How long a queued cast may wait for ANY engine acknowledgement before it
-- counts as never-confirmed. Bounded below by the cast queue: queue_spell_target
-- may hold an offer until the next GCD boundary (1.5s), so the window is one
-- full GCD plus slack. This is the slow safety net; the refusal hold above is
-- the fast one.
M.CONFIRM_SEC = 1.6

-- Public read for diagnostics/tests: the resource-class hold duration. Longer
-- than HOLD_SEC because a 0.6s hold on "Not enough rage" just re-attempts the
-- same impossible cast at every GCD boundary (the live Battle Shout spam).
M.RESOURCE_HOLD_SEC = 1.5

-- Safety valve: verdicts are pruned as they expire, but a pathological burst of
-- distinct refused ids must not grow the table without bound.
M.MAX_TRACKED = 256

-- Engine events this machine listens to. Everything here except the two
-- refusals is an ACKNOWLEDGEMENT: the client took the offer, so the pending
-- cast is resolved and the lane may be offered again.
local REGISTERED = {
    "UNIT_SPELLCAST_SENT",           -- the request left the client (player only)
    "UNIT_SPELLCAST_START",          -- hard cast began
    "UNIT_SPELLCAST_SUCCEEDED",      -- completion signal
    "UNIT_SPELLCAST_INTERRUPTED",    -- accepted, then kicked/cancelled/moved
    "UNIT_SPELLCAST_CHANNEL_START",  -- channel began
    "UNIT_SPELLCAST_FAILED",         -- the client refused it
    "UNIT_SPELLCAST_FAILED_QUIET",   -- the client refused it, quietly
    "UI_ERROR_MESSAGE",              -- resource-class refusal, NO spell id
}

local REFUSALS = {
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_FAILED_QUIET = true,
}

-- spell_id index per event. SENT is the odd one: { unit, target_name,
-- cast_guid, spell_id } pushes it to 4; every other event carries
-- { unit, cast_guid, spell_id }.
local SPELL_ID_INDEX = {
    UNIT_SPELLCAST_SENT = 4,
}
local DEFAULT_SPELL_ID_INDEX = 3

local PRUNE_EVERY = 16

-- Window comparisons are float subtractions, and 100 + 1.6 - 100 is not 1.6 on
-- a binary clock, so "has the window elapsed?" needs a tolerance far below the
-- clock's real resolution (the engine reports milliseconds) to stay exact.
local TIME_EPS = 1e-9

-- Injected by M.install -- never captured at require time (the battery's
-- shared-virgin guard forbids require-time binding to the live namespace).
local _NS = nil
local _held = {}        -- spell_id -> verdict EXPIRY time
local _size = 0
local _writes = 0
local _pending_id = nil -- the most recent cast we issued and have not resolved
local _pending_t = nil
local _armed = false    -- has the engine ever reported a player cast event?

--- Current time, or nil when no clock is available (which makes the machine a
--- no-op rather than holding forever). Read off the live namespace so a host
--- that swaps NS.time_now is honoured.
local function current_time()
    local ns = _NS
    if type(ns) ~= "table" then return nil end
    local fn = ns.time_now
    if type(fn) ~= "function" then return nil end
    local ok, t = pcall(fn)
    if ok and type(t) == "number" then return t end
    return nil
end

--- Drop every verdict that has already expired. Returns the surviving count.
-- Iterating with pairs() while clearing the current key is legal in Lua 5.1.
local function prune(t)
    local live = 0
    for id, expire in pairs(_held) do
        if expire <= t then
            _held[id] = nil
        else
            live = live + 1
        end
    end
    return live
end

--- Record an engine verdict against a spell id (refusal or never-confirmed).
-- @param spell_id number
-- @param t number|nil  Verdict time; defaults to the injected clock.
-- @param hold number|nil  Hold duration override (resource refusals hold longer).
-- @return boolean true when the verdict was recorded.
local function remember_hold(spell_id, t, hold)
    if type(spell_id) ~= "number" or spell_id <= 0 then return false end
    if t == nil then t = current_time() end
    if type(t) ~= "number" then return false end
    if _held[spell_id] == nil then
        _size = _size + 1
    end
    _held[spell_id] = t + (hold or M.HOLD_SEC)
    _writes = _writes + 1
    if _writes >= PRUNE_EVERY or _size > M.MAX_TRACKED then
        _writes = 0
        _size = prune(t)
    end
    return true
end

--- Close out a pending offer that the engine never acknowledged. Only a client
--- that has already reported a player cast may be distrusted for silence, so an
--- unarmed machine never holds here.
local function expire_pending(t)
    if not _pending_id then return end
    if (t - _pending_t) + TIME_EPS < M.CONFIRM_SEC then return end
    local stale = _pending_id
    _pending_id, _pending_t = nil, nil
    if _armed then
        remember_hold(stale, t)
    end
end

--- Seconds still to go on the hold for this spell, 0 when it is not held.
-- @param spell_id number
-- @param t number|nil  Time to evaluate against; defaults to the live clock.
-- @return number
function M.remaining(spell_id, t)
    if type(spell_id) ~= "number" or spell_id <= 0 then return 0 end
    -- Fast path: nothing recorded for this id and it is not the outstanding
    -- offer, so there is nothing to expire and the clock is never read.
    if _held[spell_id] == nil and _pending_id ~= spell_id then return 0 end
    if t == nil then t = current_time() end
    if type(t) ~= "number" then return 0 end
    expire_pending(t)
    local expire = _held[spell_id]
    if not expire then return 0 end
    local left = expire - t
    if left > 0 then return left end
    return 0
end

--- True while the engine's verdict on this spell is still fresh.
-- @param spell_id number
-- @param t number|nil
-- @return boolean
function M.is_held(spell_id, t)
    return M.remaining(spell_id, t) > 0
end

--- Record that the addon just issued this cast, so the engine's next word about
--- it can resolve the offer. Called from the central cast path only.
-- @param spell_id number
-- @param t number|nil  Issue time; defaults to the live clock.
-- @return boolean true when the offer was recorded.
function M.note_queued(spell_id, t)
    if type(spell_id) ~= "number" or spell_id <= 0 then return false end
    if t == nil then t = current_time() end
    if type(t) ~= "number" then return false end
    -- Close out the previous offer before replacing it: if the engine has been
    -- silent about it for the whole window, that silence is the verdict.
    expire_pending(t)
    _pending_id, _pending_t = spell_id, t
    return true
end

--- Number of tracked verdicts (diagnostics / audits).
function M.count()
    local n = 0
    for _ in pairs(_held) do n = n + 1 end
    return n
end

--- The outstanding offer, or nil when the engine has resolved the last one.
function M.pending_id()
    return _pending_id
end

--- True once the engine has reported a player cast event (which arms the
--- never-confirmed hold). False on any host that never speaks.
function M.armed()
    return _armed
end

--- Clear every verdict and the outstanding offer (tests and per-generation
--- reset). Disarms the machine, since the evidence that the engine speaks is
--- per-session too. RESOURCE_HOLD_SEC (module constant, not per-session state)
--- deliberately survives.
function M.reset()
    _held = {}
    _size = 0
    _writes = 0
    _pending_id, _pending_t = nil, nil
    _armed = false
end

-- ---------------------------------------------------------------------------
-- Engine events
-- ---------------------------------------------------------------------------
-- args[1] is the CASTER'S UNIT TOKEN, never a GUID, so the filter is
-- load-bearing rather than defensive: another unit's cast must never resolve or
-- hold OUR offers.
local function on_game_event(event_name, args)
    -- UI_ERROR_MESSAGE arrives first: it is the one event whose payload is NOT
    -- a player-scoped cast record (Lua 5.1 varargs of error strings, no spell
    -- id, no unit token), so none of the machinery below applies to it. The
    -- only fact it carries is "a cast was just refused"; attribute it to the
    -- outstanding offer and return. It must not arm the machine (an error alone
    -- is not proof the client reports cast events) and must never clear the
    -- pending offer (a resource refusal is not an acknowledgement).
    if event_name == "UI_ERROR_MESSAGE" then
        if _pending_id ~= nil then
            remember_hold(_pending_id, nil, M.RESOURCE_HOLD_SEC)
        end
        return
    end
    if type(args) ~= "table" then return end
    if args[1] ~= "player" then return end
    _armed = true
    local spell_id = args[SPELL_ID_INDEX[event_name] or DEFAULT_SPELL_ID_INDEX]
    if type(spell_id) ~= "number" or spell_id <= 0 then return end
    if REFUSALS[event_name] then
        remember_hold(spell_id)
    end
    if _pending_id == spell_id then
        _pending_id, _pending_t = nil, nil
    end
end

local _registered = false

--- Subscribe to the engine's cast events. Idempotent; called by install() and
--- re-callable so a late-loaded namespace still binds.
-- @return boolean true when at least one subscription landed.
function M.try_register()
    if _registered then return true end
    if type(_NS) ~= "table" or type(_NS.register_on_game_event) ~= "function" then
        return false
    end
    local any = false
    for i = 1, #REGISTERED do
        local ok = pcall(_NS.register_on_game_event, REGISTERED[i], on_game_event)
        if ok then any = true end
    end
    if any then
        _registered = true
    end
    return _registered
end

--- Bind the machine to a live namespace. Called once by the dispatcher loader.
-- @param ns table  The EaxRotations namespace.
-- @return boolean true when the namespace was accepted.
function M.install(ns)
    if type(ns) ~= "table" then return false end
    _NS = ns
    ns.CastConfirm = M
    M.try_register()
    return true
end

return M
