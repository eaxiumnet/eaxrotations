-- What: INTERACT state handler — process open UI frames (loot, gossip, quest, trainer, vendor)
-- When: Called by coordinator when shared._state == "INTERACT"
-- Why: Centralize frame handling with 15s safety timeout, cooldown on give-up, throttled re-processing
-- API: exports run(shared, ctx) → next_state string

-- ============================================================================
-- Constants
-- ============================================================================

local INTERACT_TIMEOUT = 15  -- max seconds in INTERACT before force-exit

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

-- ============================================================================
-- State: INTERACT — Handle open UI frames
-- ============================================================================

--- Process open UI frames via quest_interaction.handle_any_frame().
--- Stays in INTERACT if frame remains open after handling.
--- Force-exits after 15s to prevent infinite frame loops.
--- @param shared table Shared state variables
--- @param ctx table Per-tick context with submodules, me, helpers
--- @return string next_state
function M.run(shared, ctx)
    -- Safety timeout: force exit INTERACT after 15 seconds
    if shared._interact_start_time == 0 then
        shared._interact_start_time = ctx.now
    elseif ctx.now - shared._interact_start_time > INTERACT_TIMEOUT then
        shared._interact_start_time = 0
        shared._interact_cooldown = ctx.now + 5.0
        -- Force close all frames before exiting
        pcall(function() core.quests.close_quest() end)
        pcall(function() core.quests.close_gossip() end)
        pcall(core.input.close_loot)
        core.log_warning("[EaxAutoQuester] Frame stuck - manual intervention may be needed")
        return "IDLE"
    end

    local interaction = ctx.quest_interaction
    if not interaction then return "IDLE" end

    -- Handle open frames
    local result = interaction.handle_any_frame()

    if result then
        -- Throttled: frame still being processed, stay in INTERACT
        if result == "quest_throttled" then
            shared._interact_start_time = ctx.now  -- reset timeout, we're making progress
            return "INTERACT"
        end
        -- Permanently gave up on this frame — force exit with cooldown
        if result == "quest_giveup" then
            shared._interact_start_time = 0
            shared._interact_cooldown = ctx.now + 10.0
            ctx.debug_log("INTERACT: gave up on quest frame → IDLE (10s cooldown)")
            return "IDLE"
        end

        ctx.debug_log("INTERACT: handled (" .. tostring(result) .. ")")

        -- Recheck if frame still open
        if ctx.detect_open_frame() then
            ctx.debug_log("INTERACT: frame still open")
            return "INTERACT"
        end

        -- Frame closed by handling
        ctx.debug_log("INTERACT: frame closed → IDLE")
        shared._interact_start_time = 0
        return "IDLE"
    end

    -- No frame to handle
    shared._interact_start_time = 0
    ctx.debug_log("INTERACT: no frame → IDLE")
    return "IDLE"
end

return M
