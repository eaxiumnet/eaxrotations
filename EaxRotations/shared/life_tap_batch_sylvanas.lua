-- life_tap_batch_sylvanas.lua -- Consecutive Life Tap batching engine (TBC destruction warlock).
-- WHAT:  Owns the "tap in a batch" state for the destruction Life Tap lane.
--        Once mana drops below the entry threshold the lane keeps claiming the
--        GCD until mana reaches (entry + buffer), so the filler lanes cannot
--        slot a cast between two taps.
-- WHY:   Without it the lane tapped, the very next filler cast knocked mana
--        back under the same threshold, and the lane tapped again -- the live
--        tap/cast ping-pong every GCD (one tap bought exactly one GCD of mana
--        because the entry threshold was also the exit threshold).
-- WHEN:  destruction_sylvanas.lua only (TBC). Matchers read the engine
--        read-only; only the Life Tap execute and build_state mutate it.
-- SAFETY: Pure Lua, no game API, no allocation. Every function is nil-safe.
--        A batch can never stall the rotation: wants() self-heals a batch that
--        has not landed a tap inside STALL_SECONDS (read-only), and observe()
--        drops it for good. MAX_SECONDS is a hard ceiling on one batch.
local M = {}

local STALL_SECONDS = 3.0   -- no landed tap for this long -> the batch is dead
local MAX_SECONDS   = 12.0  -- hard ceiling on a single batch (defensive)

local st = {
    active = false,
    target = 0,
    started_at = 0,
    last_tap_at = 0,
    taps = 0,
}

local function num(v, d)
    if type(v) == "number" then return v end
    return d
end

--- Clear all batch state. Called at spec load (so a reload in the same Lua
--- state can never inherit a stale batch) and by tests.
function M.reset()
    st.active = false
    st.target = 0
    st.started_at = 0
    st.last_tap_at = 0
    st.taps = 0
end

function M.is_active() return st.active end
function M.target() return st.target end
function M.taps() return st.taps end

--- Open a batch aimed at `recover` mana percent. Called on the first tap.
function M.start(now, recover)
    st.active = true
    st.target = num(recover, st.target)
    st.started_at = num(now, 0)
    st.last_tap_at = st.started_at
    st.taps = 1
end

--- Record a landed tap inside an active batch (resets the stall clock).
function M.note_tap(now)
    st.last_tap_at = num(now, st.last_tap_at)
    st.taps = st.taps + 1
end

function M.stop()
    st.active = false
    st.target = 0
    st.taps = 0
end

--- Read-only: should the Life Tap lane run at all this tick?
---   idle  -> true only when mana is at or below the entry threshold
---   batch -> true while mana is still under the recover target (this is what
---            lets the lane hold the GCD between two consecutive taps)
function M.wants(now, mana_pct, hp, entry, recover, min_hp)
    mana_pct = num(mana_pct, 100)
    hp       = num(hp, 100)
    entry    = num(entry, 20)
    recover  = num(recover, entry)
    min_hp   = num(min_hp, 50)
    if hp < min_hp then return false end
    if st.active then
        local n = num(now, st.last_tap_at)
        if st.last_tap_at > 0 and (n - st.last_tap_at) > STALL_SECONDS then return false end
        if st.started_at > 0 and (n - st.started_at) > MAX_SECONDS then return false end
        return mana_pct < recover
    end
    return mana_pct <= entry
end

--- Once-per-tick housekeeping: drop a batch that has reached the recover
--- target, become unsafe, or stalled. Read-only callers never depend on this
--- for correctness (wants() self-heals); it only re-arms the entry threshold.
function M.observe(now, mana_pct, hp, entry, recover, min_hp)
    if not st.active then return false end
    if not M.wants(now, mana_pct, hp, entry, recover, min_hp) then
        M.stop()
        return true
    end
    return false
end

return M
