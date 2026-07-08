-- quest_tracker.lua — Daily fishing quest tracker + fish-specific targeting.
-- WHAT:  detects active fishing daily quests by checking for quest items in bags,
--        tracks progress, and can filter pool selection to target specific fish.
-- WHEN:  checked during pool selection and after each catch.
-- WHY:   TBC has daily fishing quests (e.g., "Bait Bandits" for Blacktail).
--        Users want the bot to prioritize pools that drop quest fish and stop
--        when the quest is complete.
-- SAFETY: all API calls pcall-guarded; quest detection is passive (read-only).

local APISurface = require("core/api_surface")

local M = {}

-- TBC daily fishing quest fish (item_id -> quest name)
-- These are the turn-in items for TBC cooking/fishing dailies.
local QUEST_FISH = {
    [27437] = "Bloodtooth Frenzy",       -- Shattrath daily
    [27438] = "Feltail",                 -- Terokkar daily
    [27439] = "Zangarian Sporefish",     -- Zangarmarsh daily
    [27440] = "Enormous Barbed Gill Trout", -- Nagrand daily
    [27441] = "Misty Reed Mahi Mahi",    -- Shadowmoon daily
    [27442] = "Greater Sagefish",        -- Old world daily
    [27443] = "Large Raw Mightfish",     -- Tanaris daily
}

-- Quest fish -> pool name mapping (which pools drop which quest fish)
-- This is approximate — TBC pools have mixed drops, but some are more likely.
local QUEST_FISH_POOLS = {
    [27437] = { "Bloodtooth Frenzy School", "School of Bloodtooth Frenzy" },
    [27438] = { "Feltail School", "School of Feltail", "Sporefish School" },
    [27439] = { "Zangarian Sporefish School", "Sporefish School" },
    [27440] = { "Barbed Gill Trout School", "School of Barbed Gill Trout" },
    [27441] = { "Misty Reed Mahi Mahi School", "Highland Muddy Water" },
    [27442] = { "Sagefish School", "Greater Sagefish School" },
    [27443] = { "Mightfish School", "Raw Mightfish School" },
}

--- Detect active fishing quest by scanning bags for quest fish items
-- @param ctx table
-- @return number|nil quest_fish_id if a quest fish is found
function M.detect_quest_fish(ctx)
    for item_id, _ in pairs(QUEST_FISH) do
        local count = APISurface.get_item_count(item_id)
        if count and count > 0 then
            return item_id
        end
    end
    return nil
end

--- Get the pool names that drop a specific quest fish
-- @param quest_fish_id number
-- @return table|nil list of pool names
function M.get_quest_pools(quest_fish_id)
    return QUEST_FISH_POOLS[quest_fish_id]
end

--- Check if a pool name matches the current quest target
-- @param pool_name string
-- @param quest_fish_id number
-- @return boolean
function M.is_quest_pool(pool_name, quest_fish_id)
    if not pool_name or not quest_fish_id then return false end
    local pools = QUEST_FISH_POOLS[quest_fish_id]
    if not pools then return false end
    for _, quest_pool in ipairs(pools) do
        if pool_name == quest_pool then return true end
        -- Partial match (pool names can vary slightly)
        if string.find(pool_name, quest_pool, 1, true) then return true end
    end
    return false
end

--- Update quest tracking state
-- @param ctx table
-- @param now number
function M.update(ctx, now)
    local state = ctx.state

    -- Throttle quest detection (every 10s)
    if now - state.quest.last_check_time < 10.0 then return end
    state.quest.last_check_time = now

    -- Detect quest fish in bags
    local quest_fish_id = M.detect_quest_fish(ctx)
    if quest_fish_id then
        if state.quest.quest_fish_id ~= quest_fish_id then
            state.quest.quest_fish_id = quest_fish_id
            state.quest.quest_fish_name = QUEST_FISH[quest_fish_id] or "Unknown"
            APISurface.print("[EaxFishing] Fishing daily detected: " .. state.quest.quest_fish_name)
        end
    else
        -- No quest fish in bags — clear quest tracking
        if state.quest.quest_fish_id then
            APISurface.print("[EaxFishing] Fishing daily complete or turned in")
            state.quest.quest_fish_id = nil
            state.quest.quest_fish_name = nil
        end
    end
end

--- Reset quest state
function M.reset(state)
    if not state.quest then return end
    state.quest.active_quest_id = nil
    state.quest.quest_fish_id = nil
    state.quest.quest_fish_name = nil
    state.quest.quest_fish_needed = 0
    state.quest.quest_fish_count = 0
    state.quest.quest_complete = false
    state.quest.last_check_time = 0.0
end

return M
