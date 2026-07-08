-- service_gossip_sylvanas.lua — Non-quest gossip automation for EaxAutoQuester
-- WHAT:  Handles innkeeper hearth-set, bank, and repair gossip options.
-- WHEN:  INTERACT state when gossip frame is open but no quest actions remain.
-- WHY:   eliminates manual clicks for "set hearth" steps, bank deposits, repairs.
-- SAFETY: pcall on all API calls; service patterns matched case-insensitively;
--          only triggers when explicitly needed (Zygor step text or menu flags).

local M = {}

-- ============================================================================
-- Constants
-- ============================================================================

local _HEARTH_STEP_PATTERNS = {
    "[Ss]et [Yy]our [Hh]earthstone to",
    "[Ss]et [Hh]earth to",
    "[Mm]ake .- [Yy]our [Hh]ome",
    "[Hh]ome [Pp]oint:",
    "[Bb]ind [Hh]earthstone",
}

local _INN_PATTERNS = {
    "[Mm]ake this inn your home",
    "[Ii]'d like to make this my home",
    "[Bb]ind my hearthstone here",
    "[Ss]et [Hh]earthstone",
}

local _BANK_PATTERNS = {
    "[Ii] would like to check my deposit box",
    "[Bb]ank",
    "[Dd]eposit box",
}

local _REPAIR_PATTERNS = {
    "[Rr]epair",
    "[Ff]ix my gear",
}

local _SERVICE_PRIORITY = {
    { name = "inn",   patterns = _INN_PATTERNS },
    { name = "bank",  patterns = _BANK_PATTERNS },
    { name = "repair", patterns = _REPAIR_PATTERNS },
}

-- ============================================================================
-- Helpers
-- ============================================================================

--- Check if current Zygor step text indicates a hearth-set action.
-- @param step_text string|nil
-- @return boolean
function M.step_requires_hearth(step_text)
    if not step_text then return false end
    for _, pattern in ipairs(_HEARTH_STEP_PATTERNS) do
        if step_text:find(pattern) then return true end
    end
    return false
end

--- Score how well a gossip option name matches service patterns.
-- @param option_name string
-- @param patterns table Array of Lua patterns.
-- @return number 1 if matched, 0 otherwise
local function match_option_patterns(option_name, patterns)
    if not option_name then return 0 end
    local lower = option_name:lower()
    for _, pattern in ipairs(patterns) do
        if lower:find(pattern) then return 1 end
    end
    return 0
end

--- Find the best service gossip option from a list of options.
-- @param options table Array of gossip_option tables.
-- @param wanted_services table|nil Array of service names to look for ("inn", "bank", "repair").
-- @return number|nil gossip_option_id to select.
function M.find_service_option(options, wanted_services)
    if not options or #options == 0 then return nil end
    wanted_services = wanted_services or { "inn", "bank", "repair" }

    for _, svc in ipairs(_SERVICE_PRIORITY) do
        for _, wanted in ipairs(wanted_services) do
            if svc.name == wanted then
                for _, opt in ipairs(options) do
                    if opt and opt.name and match_option_patterns(opt.name, svc.patterns) > 0 then
                        return opt.gossip_option_id
                    end
                end
            end
        end
    end
    return nil
end

-- ============================================================================
-- Core Logic
-- ============================================================================

--- Handle service gossip at the current NPC.
-- Call when gossip frame is open and quest handling returned nil.
-- @param step_text string|nil Current Zygor step text for context.
-- @param wanted_services table|nil E.g., {"inn"} if step says "set hearth".
-- @return string|nil Result token: "service:<name>" or nil.
function M.handle_service_gossip(step_text, wanted_services)
    local ok, shown = pcall(core.quests.is_gossip_frame_shown)
    if not ok or not shown then return nil end

    local ok2, options = pcall(core.quests.get_gossip_options)
    if not ok2 or not options or #options == 0 then return nil end

    -- Default wanted services based on step text
    if not wanted_services then
        wanted_services = {}
        if M.step_requires_hearth(step_text) then
            wanted_services[#wanted_services + 1] = "inn"
        end
        -- Bank/repair could be added via menu flags or step text in future
    end

    if #wanted_services == 0 then return nil end

    local option_id = M.find_service_option(options, wanted_services)
    if not option_id then return nil end

    local ok3 = pcall(function() core.quests.select_gossip_option(option_id) end)
    if ok3 then
        if core.log then
            core.log("[EaxAutoQuester] Selected service gossip: " .. table.concat(wanted_services, ","))
        end
        return "service:" .. table.concat(wanted_services, ",")
    end
    return nil
end

return M
