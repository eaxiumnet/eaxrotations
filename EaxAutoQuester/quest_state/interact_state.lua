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
-- Lazy-load optional handlers
local _static_popup = nil
local function ensure_static_popup()
    if _static_popup then return _static_popup end
    local ok, sp = pcall(require, "static_popup_sylvanas")
    if ok and sp then _static_popup = sp end
    return _static_popup
end

local _flight_path = nil
local function ensure_flight_path()
    if _flight_path then return _flight_path end
    local ok, fp = pcall(require, "flight_path_sylvanas")
    if ok and fp then _flight_path = fp end
    return _flight_path
end

function M.run(shared, ctx)
    -- Check for detectable popups first (dungeon proposals, battlefield ports)
    -- These can appear while other frames are open and block interaction
    local sp = ensure_static_popup()
    if sp then
        local popup_result = sp.handle_any_popup()
        if popup_result then
            ctx.debug_log("INTERACT: handled popup (" .. tostring(popup_result) .. ")")
        end
    end

    -- Flight path gossip: auto-select destination if gossip frame is from flight master
    local fp = ensure_flight_path()
    if fp then
        local step_text = nil
        if ctx.zygor and ctx.zygor.get_current_step_info then
            local ok, st = pcall(ctx.zygor.get_current_step_info)
            if ok and st then step_text = st.text end
        end
        local npc_name = nil
        if ctx.me and ctx.me.get_target then
            local t = ctx.me:get_target()
            if t and t.get_name then npc_name = t:get_name() end
        end
        local fp_result = fp.handle_flight_gossip(step_text, npc_name)
        if fp_result then
            ctx.debug_log("INTERACT: flight path handled (" .. tostring(fp_result) .. ")")
            -- Gossip option selected; flight taxi will appear after server round-trip
            -- Stay in INTERACT briefly, then frame will close naturally
            shared._interact_start_time = ctx.now
            return "INTERACT"
        end
    end

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

    -- Handle open frames (pass step text for service gossip detection)
    local step_text = nil
    if ctx.zygor and ctx.zygor.get_current_step_info then
        local ok, st = pcall(ctx.zygor.get_current_step_info)
        if ok and st then step_text = st.text end
    end
    local result = interaction.handle_any_frame(step_text)

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
