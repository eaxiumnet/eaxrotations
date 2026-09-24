-- service_gossip_sylvanas.lua — Non-quest gossip automation for EaxAutoQuester
-- WHAT:  Handles innkeeper hearth-set, bank, and repair gossip options.
-- WHEN:  INTERACT state when gossip frame is open but no quest actions remain.
-- WHY:   eliminates manual clicks for "set hearth" steps, bank deposits, repairs.
-- SAFETY: pcall on all API calls; service patterns matched case-insensitively;
--          only triggers when explicitly needed (Zygor step text or menu flags).
-- API shapes (item 14): the innkeeper bind option is what raises the client's CONFIRM_BINDER
--          prompt, and core.input.confirm_binder() is the documented answer. This module only
--          answers a prompt IT raised, and only for a bounded window afterwards, so a prompt
--          the player opened at an innkeeper by hand is left for the player.

local _core_time = core and core.time

local M = {}

-- How long after selecting the bind option a CONFIRM_BINDER prompt is still ours to answer.
local _BIND_CONFIRM_WINDOW = 15.0

-- Timestamp of the last bind-option selection this module made; nil when there is no prompt
-- of ours outstanding.
local _bind_selected_at = nil

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

--- Derive the existing service selection from the current Zygor step.
--- This does not add a service action: it only supplies the wanted-service list that
--- handle_service_gossip already knows how to resolve against its existing patterns.
--- @param step_text string|nil
--- @return table Array containing any of "inn", "bank", and "repair"
function M.wanted_services_for_step(step_text)
    local wanted = {}
    if not step_text then return wanted end
    if M.step_requires_hearth(step_text) then
        wanted[#wanted + 1] = "inn"
    end
    local function mentions(patterns)
        for _, pattern in ipairs(patterns) do
            if step_text:find(pattern) then return true end
        end
        return false
    end
    if mentions(_BANK_PATTERNS) then
        wanted[#wanted + 1] = "bank"
    end
    if mentions(_REPAIR_PATTERNS) then
        wanted[#wanted + 1] = "repair"
    end
    return wanted
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

--- Whether the option just selected is the innkeeper's bind option, i.e. the one whose
--- prompt is CONFIRM_BINDER.
-- @param options table|nil Array of gossip_option tables.
-- @param option_id number|nil The option id that was selected.
-- @return boolean
local function is_bind_option(options, option_id)
    if not options or not option_id then return false end
    for _, opt in ipairs(options) do
        if opt and opt.gossip_option_id == option_id and opt.name then
            return match_option_patterns(opt.name, _INN_PATTERNS) > 0
        end
    end
    return false
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

    -- Default wanted services based on the existing step-text patterns. Explicit callers
    -- (including tests and future step-specific callers) still retain full control.
    if not wanted_services then
        wanted_services = M.wanted_services_for_step(step_text)
    end

    if #wanted_services == 0 then return nil end

    local option_id = M.find_service_option(options, wanted_services)
    if not option_id then return nil end

    local ok3 = pcall(function() core.quests.select_gossip_option(option_id) end)
    if ok3 then
        if is_bind_option(options, option_id) then
            -- The prompt this raises is CONFIRM_BINDER - "Accept an innkeeper's 'make this your
            -- home' prompt ... Fires after using a hearthstone bind gossip option"
            -- (.api/core.lua:1841-1845). Remembering that WE raised it is what keeps
            -- answer_bind_confirm from answering a prompt the player opened themselves.
            local ok_t, now = pcall(_core_time)
            if ok_t and type(now) == "number" then _bind_selected_at = now end
        end
        if core.log then
            core.log("[EaxAutoQuester] Selected service gossip: " .. table.concat(wanted_services, ","))
        end
        return "service:" .. table.concat(wanted_services, ",")
    end
    return nil
end

-- ============================================================================
-- Confirm input — the prompt our own bind selection raises
-- ============================================================================

--- Answer the client's CONFIRM_BINDER prompt when this plugin raised it.
---
--- Called on every tick from the coordinator, because the prompt outlives the gossip frame:
--- selecting the bind option closes the gossip frame, so no INTERACT tick runs while the
--- prompt is up. The recorded prompt comes from the quest frame event bridge (the plugin has
--- one game-event registration and this is not it), and the answer is the documented
--- core.input.confirm_binder(). A prompt nobody here raised is never answered.
--- @return boolean answered True when the client's confirm call was made
function M.answer_bind_confirm()
    if not _bind_selected_at then return false end

    local ok_t, now = pcall(_core_time)
    if not ok_t or type(now) ~= "number" then return false end
    if now - _bind_selected_at > _BIND_CONFIRM_WINDOW then
        _bind_selected_at = nil
        return false
    end

    local bridge_ok, bridge = pcall(require, "quest_frame_events_sylvanas")
    if not bridge_ok or type(bridge) ~= "table" or type(bridge.take_confirm) ~= "function" then
        return false
    end
    local ok_rec, record = pcall(bridge.take_confirm, "CONFIRM_BINDER")
    if not ok_rec or not record then return false end

    local ok, ran = pcall(core.input.confirm_binder)
    if ok and ran then
        _bind_selected_at = nil
        if core.log then
            core.log("[EaxAutoQuester] Confirmed innkeeper bind prompt (CONFIRM_BINDER)")
        end
        return true
    end
    return false
end

--- Test/inspection accessor: is a prompt of ours still outstanding?
--- @return boolean
function M._bind_confirm_pending()
    return _bind_selected_at ~= nil
end

return M
