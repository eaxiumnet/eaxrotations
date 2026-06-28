-- flight_path_sylvanas.lua — Flight path automation for EaxAutoQuester
-- WHAT:  Detects "fly to <destination>" steps, navigates to flight master,
--        selects matching gossip option.
-- WHEN:  idle/do_action states when step text indicates travel.
-- WHY:   eliminates manual flight path travel, the #1 multi-zone bottleneck.
-- SAFETY: pcall on all API calls; gossip_type guard; nil-safe on all tables.

local M = {}

-- ============================================================================
-- Constants
-- ============================================================================

local _FLY_PATTERNS = {
    "[Ff]ly to (.+)",
    "[Gg]et the flight path to (.+)",
    "[Tt]ake the flight path to (.+)",
    "[Ff]ly path to (.+)",
    "[Uu]se the flight path to (.+)",
}

-- Gossip option name patterns that indicate a destination (not a service)
local _DEST_EXCLUDE = {
    "^I would like to check my deposit box",  -- bank
    "^I would like to browse your goods",     -- vendor
    "^Train me",                              -- trainer
    "^Make this inn your home",               -- innkeeper
    "^I'd like to browse your goods",
    "^I want to browse your goods",
}

-- ============================================================================
-- Helpers
-- ============================================================================

local function normalize_name(name)
    if not name then return "" end
    return name:lower():gsub("[^%w%s]", ""):gsub("%s+", " "):gsub("^%s*", ""):gsub("%s*$", "")
end

--- Extract destination name from step text.
-- @param step_text string The Zygor step text.
-- @return string|nil The destination name, or nil if no flight keyword found.
function M.extract_destination(step_text)
    if not step_text then return nil end
    for _, pattern in ipairs(_FLY_PATTERNS) do
        local dest = step_text:match(pattern)
        if dest then
            -- Strip trailing punctuation
            dest = dest:gsub("[%.!,]$", ""):gsub("^%s*", ""):gsub("%s*$", "")
            if #dest > 1 then
                return dest
            end
        end
    end
    return nil
end

--- Check if a gossip option looks like a destination (not a service menu).
-- @param option_name string
-- @return boolean
local function is_destination_option(option_name)
    if not option_name then return false end
    local lower = option_name:lower()
    for _, excl in ipairs(_DEST_EXCLUDE) do
        if lower:find(excl:lower()) then return false end
    end
    -- Flight destinations are usually short place names or "<name> (<cost>g)"
    -- We exclude very long strings which are likely service descriptions
    if #option_name > 60 then return false end
    return true
end

--- Score how well a gossip option name matches a destination.
-- @param option_name string
-- @param destination string
-- @return number 0–1 (higher = better match)
local function match_score(option_name, destination)
    local opt_norm = normalize_name(option_name)
    local dest_norm = normalize_name(destination)
    if opt_norm == dest_norm then return 1.0 end
    if opt_norm:find(dest_norm, 1, true) then return 0.9 end
    if dest_norm:find(opt_norm, 1, true) then return 0.8 end
    -- Word overlap
    local opt_words = {}
    for w in opt_norm:gmatch("%w+") do opt_words[w] = true end
    local dest_words = {}
    for w in dest_norm:gmatch("%w+") do dest_words[w] = true end
    local common = 0
    for w in pairs(dest_words) do
        if opt_words[w] then common = common + 1 end
    end
    local total = 0
    for _ in pairs(dest_words) do total = total + 1 end
    if total > 0 then return (common / total) * 0.7 end
    return 0
end

-- ============================================================================
-- Core Logic
-- ============================================================================

--- Find the best matching gossip option for a destination.
-- Must be called when gossip frame is open at a flight master.
-- @param destination string The destination name from step text.
-- @return number|nil The gossip_option_id to select, or nil if no match.
function M.find_gossip_option_for_destination(destination)
    if not destination then return nil end

    local ok, options = pcall(core.quests.get_gossip_options)
    if not ok or not options or #options == 0 then return nil end

    local best_id = nil
    local best_score = 0.5  -- threshold

    for _, opt in ipairs(options) do
        if opt and opt.name and is_destination_option(opt.name) then
            local score = match_score(opt.name, destination)
            if score > best_score then
                best_score = score
                best_id = opt.gossip_option_id
            end
        end
    end

    return best_id
end

--- Select the gossip option for the given destination.
-- @param destination string
-- @return boolean True if an option was selected.
function M.select_flight_destination(destination)
    local id = M.find_gossip_option_for_destination(destination)
    if not id then return false end

    local ok = pcall(function() core.quests.select_gossip_option(id) end)
    if ok then
        if core.log then core.log("[EaxAutoQuester] Selected flight: " .. tostring(destination)) end
        return true
    end
    return false
end

--- Determine if current gossip frame is from a flight master.
-- Heuristic: NPC name keywords + gossip options look like destinations.
-- @param npc_name string|nil Name of the currently targeted/interacted NPC.
-- @return boolean
function M.is_flight_master_gossip(npc_name)
    local ok, shown = pcall(core.quests.is_gossip_frame_shown)
    if not ok or not shown then return false end

    -- Check NPC name for flight master keywords
    if npc_name then
        local lower = npc_name:lower()
        local flight_keywords = { "flight master", "wind rider", "hippogryph",
                                   "gryphon", "bat handler", "wind rider master",
                                   "hippogryph master", "gryphon master" }
        for _, kw in ipairs(flight_keywords) do
            if lower:find(kw, 1, true) then return true end
        end
    end

    -- Fallback: check if gossip options look like flight destinations
    local ok2, options = pcall(core.quests.get_gossip_options)
    if ok2 and options and #options > 0 then
        local dest_count = 0
        for _, opt in ipairs(options) do
            if opt and opt.name and is_destination_option(opt.name) then
                dest_count = dest_count + 1
            end
        end
        -- If most options look like destinations, it's probably a flight master
        if dest_count >= 2 and dest_count >= (#options * 0.5) then
            return true
        end
    end

    return false
end

--- Full flight handling: call when gossip frame is open.
-- @param step_text string Current Zygor step text (to extract destination).
-- @param npc_name string|nil Current NPC name.
-- @return string|nil Result token: "flight_selected" or nil.
function M.handle_flight_gossip(step_text, npc_name)
    if not M.is_flight_master_gossip(npc_name) then return nil end

    local dest = M.extract_destination(step_text)
    if not dest then return nil end

    if M.select_flight_destination(dest) then
        return "flight_selected"
    end
    return nil
end

-- ============================================================================
-- Navigation Integration
-- ============================================================================

--- Check if current step requires flight travel.
-- @param step_text string
-- @return boolean
function M.step_requires_flight(step_text)
    return M.extract_destination(step_text) ~= nil
end

return M
