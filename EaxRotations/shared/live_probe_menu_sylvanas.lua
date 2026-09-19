-- live_probe_menu_sylvanas.lua — the published probe operations.
-- WHAT:  menu_buttons(): the single operation list both menu implementations
--        iterate, the action_* wrappers those buttons call (report, snapshot,
--        reader inventory, integrity state, arm by scope, flush, disarm), and
--        the arm-scope resolution that turns a scope into watch ids BY NAME from
--        the class spell map.
-- WHEN:  built at load; only a Diagnostics button calls the actions.
-- WHY:   the engine exposes no console, so a menu entry is the only way a session
--        runs a probe, and one published list is what keeps the legacy tree and
--        the declarative page from drifting apart.
-- SAFETY: every id resolves by name (a miss is a logged fallback, never a guessed
--        literal) and arming is explicit -- the module is inert until clicked.
local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end
local type = type
local tonumber = tonumber
local tostring = tostring
local kit = require("shared/live_probe_kit_sylvanas")
local out, lookup = kit.out, kit.lookup
local truth = require("shared/live_probe_truth_sylvanas")
local sample = require("shared/live_probe_sample_sylvanas")
local capture = require("shared/live_probe_capture_sylvanas")
local readers = require("shared/live_probe_readers_sylvanas")
local integrity = require("shared/live_probe_integrity_sylvanas")
local M = {}
-- ---------------------------------------------------------------------------
-- Menu-facing operations (single owner)
--
-- The engine has no console, so the only way a session runs a probe is a menu
-- action. Both menu implementations therefore own WIDGETS only and call these
-- operations; menu_buttons() is the one list they both iterate, so the legacy
-- tree and the declarative page cannot drift. Everything stays disarmed until
-- an action arms it, and no id is ever guessed: form ids resolve BY NAME from
-- the class spell map the spec files publish (NS.<Class>Spells).
-- ---------------------------------------------------------------------------
local FORM_ACTIONS = {
    Druid  = { "CatForm", "BearForm", "TravelForm" },
    Shaman = { "GhostWolf" },
}

local function class_spell_map()
    local name = lookup("ns", "player_class_name")
    if type(name) ~= "string" or name == "" then
        local plugin = _G["plugin_info"]
        if type(plugin) == "table" then name = plugin["player_class_name"] end
    end
    if type(name) ~= "string" or name == "" then return nil, nil end
    name = name:sub(1, 1):upper() .. name:sub(2):lower()
    local map = lookup("ns", name .. "Spells")
    if type(map) ~= "table" then return nil, name end
    return map, name
end

local function resolve_ids(map, action_name)
    local ids = {}
    if type(map) ~= "table" then return ids end
    local action = map[action_name]
    if type(action) ~= "table" then return ids end
    local meta = action["_meta"]
    local candidates = meta and (meta["ids"] or meta["id"]) or action["ids"]
    if type(candidates) == "number" then candidates = { candidates } end
    if type(candidates) ~= "table" then return ids end
    local seen = {}
    for i = 1, #candidates do
        local id = tonumber(candidates[i])
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    return ids
end

local function resolve_form_ids()
    local map, name = class_spell_map()
    local ids = {}
    local list = name and FORM_ACTIONS[name] or nil
    if type(list) == "table" then
        local seen = {}
        for i = 1, #list do
            local sub = resolve_ids(map, list[i])
            for j = 1, #sub do
                local id = sub[j]
                if not seen[id] then
                    seen[id] = true
                    ids[#ids + 1] = id
                end
            end
        end
    end
    return ids, name
end

local ARM_SCOPES = { all = true, forms = true, dots = true, rage = true }

-- action_arm(scope, raw_events): scope is what the capture records --
--   all   -> own aura changes + incoming damage (with the rage it produced)
--   forms -> own aura changes only, ids resolved from the class spell map
--   dots  -> own periodic-damage ticks (and the interval between them)
--   rage  -> incoming damage only (the rage-from-damage curve)
-- raw_events dumps the first CLEU event's args, which is how a session confirms
-- the layout this build sends instead of assuming one.
function M.action_arm(scope, raw_events)
    if type(scope) ~= "string" or not ARM_SCOPES[scope] then scope = "all" end
    local forms = {}
    if scope == "forms" then
        local class_name
        forms, class_name = resolve_form_ids()
        if #forms == 0 then
            out("[LiveProbe] arm(forms): no form id resolved for class "
                .. tostring(class_name or "unknown")
                .. " -- falling back to scope=all (every own aura)")
            scope = "all"
        end
    end
    return capture.arm({ forms = forms, raw_events = raw_events, scope = scope })
end

local MENU_BUTTONS = {
    {
        id = "eax_probe_report", label = "Probe: Engine Report",
        description = "Log the expansion/version surface, race, capability matrix and aura points (Block 0.1-0.3)",
        run = function() return truth.report() end,
    },
    {
        id = "eax_probe_readers", label = "Probe: Reader Surfaces (0.4)",
        description = "Inventory the external-reader surfaces this build exposes: the built-in damage meter, the cooldown readers our lanes use, the engine CD modules, and a name scan of the engine table",
        run = function() return readers.reader_report() end,
    },
    {
        id = "eax_probe_integrity", label = "Probe: Engine Integrity (0.5)",
        description = "Show the client's integrity/error surface state (log sinks, engine tables, runtime generations, a live-read canary) and the arm -> flush comparison, so Block 0.5 is evidence from the log",
        run = function() return integrity.integrity_report() end,
    },
    {
        id = "eax_probe_sample", label = "Probe: Snapshot Now",
        description = "Log one line of form/energy/rage/mana/hp/combo/AP/haste at this moment",
        run = function() return sample.sample("menu") end,
    },
    {
        id = "eax_probe_arm_all", label = "Probe: Arm Capture (all)",
        description = "Record own aura changes + incoming damage (with rage) + one raw CLEU event, then Flush",
        run = function() M.action_arm("all", 1) end,
    },
    {
        id = "eax_probe_arm_forms", label = "Probe: Arm Capture (forms)",
        description = "Record own form/buff changes with the energy snapshot -- shift form after arming, then Flush",
        run = function() M.action_arm("forms", 1) end,
    },
    {
        id = "eax_probe_arm_dots", label = "Probe: Arm Capture (ticks)",
        description = "Record own DoT ticks and their interval -- apply the DoT after arming, then Flush",
        run = function() M.action_arm("dots", 0) end,
    },
    {
        id = "eax_probe_arm_rage", label = "Probe: Arm Capture (rage)",
        description = "Record incoming damage with the rage it produced -- take the hit after arming, then Flush",
        run = function() M.action_arm("rage", 0) end,
    },
    {
        id = "eax_probe_flush", label = "Probe: Flush Capture",
        description = "Log the capture: every recorded event, plus the raw CLEU arg dump when armed with it",
        run = function() return capture.flush() end,
    },
    {
        id = "eax_probe_disarm", label = "Probe: Disarm Capture",
        description = "Stop recording; the capture stays readable until the next arm",
        run = function() return capture.disarm() end,
    },
}

-- menu_buttons(): the operation list both menu implementations iterate. One
-- owner means the two Diagnostics sections cannot drift apart, and the wiring
-- suite fails if either menu stops consuming it.
function M.menu_buttons()
    return MENU_BUTTONS
end

return M
