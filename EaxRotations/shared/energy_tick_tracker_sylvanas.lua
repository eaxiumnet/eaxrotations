-- energy_tick_tracker_sylvanas.lua -- project next-tick energy based on observed tick cadence.
-- WHAT:   project next-tick energy based on observed tick cadence
-- WHEN:   rogue + feral druid combat
-- WHY:    lets Rip/Shred/Evis energy-gate decisions use projected (not just current) energy
-- SAFETY: no allocations in tick path; bounded observation window
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- Tracks energy tick timing for energy-based classes (Rogue, Cat Druid, Feral)

local M = {}

-- TBC energy tick is 2.0 seconds, 20 energy per tick
M.TICK_INTERVAL = 2.0
M.TICK_ENERGY = 20

--- Create a new tracker state table
---@return table
function M.new_state()
    return {
        last_energy = 0,
        last_tick_time = 0,
        tick_confident = false,
    }
end

--- Update tracker with current energy and timestamp
---@param state table Tracker state from new_state()
---@param energy number Current energy value
---@param now number Current timestamp (seconds)
function M.update(state, energy, now)
    if not state then return end
    local delta = energy - state.last_energy
    if delta > 0 and delta <= 25 then
        state.last_tick_time = now
        state.tick_confident = true
    end
    state.last_energy = energy
end

--- Estimate seconds until next energy tick
---@param state table Tracker state
---@param now number Current timestamp (seconds)
---@return number seconds Until next tick (0 to TICK_INTERVAL)
function M.estimate_next_tick(state, now)
    if not state then return M.TICK_INTERVAL end
    if not state.tick_confident or (state.last_tick_time or 0) <= 0 then
        return M.TICK_INTERVAL
    end
    local elapsed = now - state.last_tick_time
    if elapsed < 0 or elapsed > M.TICK_INTERVAL * 3 then
        return M.TICK_INTERVAL
    end
    local ticks = math.floor(elapsed / M.TICK_INTERVAL)
    local since_last = elapsed - (ticks * M.TICK_INTERVAL)
    return math.max(0, M.TICK_INTERVAL - since_last)
end


return M

