-- test_live_probe_menu_wiring.lua — the live-probe harness must be REACHABLE.
-- WHAT:  RUNS each menu's own probe block. The block is extracted from the menu
--        file between explicit markers and executed here against stub menu/core
--        objects, so a Diagnostics section that builds no widget from the
--        published list (NS.LiveProbe.menu_buttons()), that registers a widget
--        under a different id, or whose click never reaches the operation fails.
--        Every published entry's click is then driven through BOTH menus' code
--        paths and its effect asserted (report/reader/integrity log, snapshot
--        does not arm, arm flips status().armed and scope, flush keeps it armed,
--        disarm stops it).
-- WHEN:  rotation suite (and standalone).
-- WHY:   the harness is inert by design, so a missing menu registration leaves a
--        module that loads and does nothing -- the dead-scaffolding failure this
--        repo's gates exist to catch, and exactly what the audit found: the
--        smoke-checklist RUN lines named calls no session could type. An earlier
--        version of this suite only GREPPED the menu sources for the tokens
--        `menu_buttons` / `entry.id`, so deleting both menus' real consumption
--        and leaving those words in a comment still exited 0 -- a hollow gate.
--        The block is now executed, so only widget registration that really
--        happens can pass.
-- SAFETY: fully mocked; no unit, spell or game state is touched. The menu files
--         are never loaded (their engine API does not exist outside the client):
--         only the marked probe block is extracted, and it runs in this file's
--         environment with `core.menu` / the Diagnostics section stubbed.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path
package.loaded["shared/live_probe_sylvanas"] = nil

local MENUS = {
    { path = "EaxRotations/main.lua", anchor = 'diagnostics_tree:render("Diagnostics"' },
    { path = "EaxRotations/shared/declarative_menu_sylvanas.lua",
      anchor = 'page.section, page, "Diagnostics"' },
}

local function read_file(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end

-- 1. Locate each menu's probe block. These markers are only a place to look:
--    section 5 RUNS what is between them, which is what makes a deleted
--    registration fail. The assertions here are the supplements -- the
--    Diagnostics section still exists and neither menu hardcodes a probe id.
local START_MARK = "-- >>> probe menu block (executed with stub menu objects by test_live_probe_menu_wiring.lua)"
local END_MARK = "-- <<< probe menu block"
local BLOCK = {}

-- The suite runs on Lua 5.1 (the version CI pins) and on 5.2+, which moved the
-- chunk-string form of loadstring to load. Both spellings must work here.
local function load_chunk(source, chunkname)
    if type(loadstring) == "function" then return loadstring(source, chunkname) end
    return load(source, chunkname)
end

for i = 1, #MENUS do
    local menu = MENUS[i]
    local text = read_file(menu.path)
    assert(text ~= nil, "menu file must exist: " .. menu.path)
    assert(text:find(menu.anchor, 1, true) ~= nil,
        menu.path .. " must keep its Diagnostics section")
    assert(text:find("eax_probe_", 1, true) == nil,
        menu.path .. " must not hardcode probe button ids (the module owns them)")
    local start_at = text:find(START_MARK, 1, true)
    local end_at = text:find(END_MARK, 1, true)
    assert(start_at ~= nil, menu.path .. " must carry the probe-block start marker")
    assert(end_at ~= nil and end_at > start_at,
        menu.path .. " must carry the probe-block end marker after the start one")
    BLOCK[menu.path] = text:sub(start_at + #START_MARK, end_at - 1)
end

-- 2. The module publishes the list and every entry is wired to real work.
local logs = {}
local registrations = {}

local player = {
    guid = "Player-1-2",
    get_buffs = function() return {} end,
    get_auras = function() return {} end,
    get_debuffs = function() return {} end,
    get_power = function() return 42 end,
    get_guid = function(self) return self.guid end,
    get_race = function() return 3 end,
    get_form = function() return 1 end,
    get_attack_power = function() return 1234 end,
    get_haste = function() return 12 end,
}

-- The class spell map the form ids resolve BY NAME through, plus plugin_info
-- (the surface the engine publishes the class name on).
_G.plugin_info = { player_class_name = "Druid" }
_G.core = { log = function(message) logs[#logs + 1] = message end }
_G.EaxRotations = {
    log = function(message) logs[#logs + 1] = message end,
    time_now = function() return 100.0 end,
    POWER_RAGE = 1,
    POWER_ENERGY = 3,
    GetPlayer = function() return player end,
    buff_points = function() return { 1265, 20 } end,
    register_on_game_event = function(event_name, callback)
        registrations[#registrations + 1] = { event_name, callback }
        return true
    end,
    DruidSpells = {
        CatForm = { _meta = { ids = { 768 } } },
        BearForm = { _meta = { ids = { 5487 } } },
        TravelForm = { _meta = { ids = { 783 } } },
    },
}

local probe = require("shared/live_probe_sylvanas")
assert(type(probe) == "table", "module must load")
assert(_G.EaxRotations.LiveProbe == probe, "module must install NS.LiveProbe")

local buttons = probe.menu_buttons()
assert(type(buttons) == "table" and #buttons > 0, "menu_buttons must publish the operation list")

-- Every published entry needs an expectation here, and every expectation needs
-- an entry: a new button with no proven effect (or a stale expectation) fails.
local EFFECT = {
    eax_probe_report = function(p)
        local view = p.get_last_report()
        return type(view) == "table" and type(view.lines) == "table" and #view.lines > 0,
            "run() must leave a report with lines"
    end,
    eax_probe_readers = function(p)
        local _report, lines = p.get_last_report()
        local found = false
        for i = 1, #lines do
            if tostring(lines[i]):find("0.4 summary:", 1, true) then found = true end
        end
        return found, "run() must leave the 0.4 reader inventory in the log"
    end,
    eax_probe_integrity = function(p)
        local _report, lines = p.get_last_report()
        local found = false
        for i = 1, #lines do
            if tostring(lines[i]):find("0.5 engine integrity", 1, true) then found = true end
        end
        return found, "run() must leave the 0.5 integrity state in the log"
    end,
    eax_probe_sample = function(p)
        return p.status().armed == false, "run() must not arm the capture"
    end,
    eax_probe_arm_all = function(p)
        local s = p.status()
        return s.armed == true and s.scope == "all", "run() must arm scope=all"
    end,
    eax_probe_arm_forms = function(p)
        local s = p.status()
        return s.armed == true and s.scope == "forms" and s.forms >= 3,
            "run() must arm scope=forms with by-name form ids"
    end,
    eax_probe_arm_dots = function(p)
        local s = p.status()
        return s.armed == true and s.scope == "dots", "run() must arm scope=dots"
    end,
    eax_probe_arm_rage = function(p)
        local s = p.status()
        return s.armed == true and s.scope == "rage", "run() must arm scope=rage"
    end,
    eax_probe_flush = function(p)
        return p.status().armed == true, "run() must leave the capture armed (flush is non-destructive)"
    end,
    eax_probe_disarm = function(p)
        return p.status().armed == false, "run() must stop the capture"
    end,
}

local proven = 0
for i = 1, #buttons do
    local entry = buttons[i]
    assert(type(entry.run) == "function", "entry needs a run function: " .. tostring(entry.id))
    local expectation = EFFECT[entry.id]
    assert(expectation ~= nil, "menu entry has no proven effect in this suite: " .. tostring(entry.id))
    local before = #logs
    local ok, err = pcall(entry.run)
    assert(ok, "entry run() must not error (" .. tostring(entry.id) .. "): " .. tostring(err))
    assert(#logs > before, "entry run() must log to the same sink as the spell dump: " .. tostring(entry.id))
    local holds, message = expectation(probe)
    assert(holds, tostring(entry.id) .. ": " .. tostring(message))
    proven = proven + 1
end
assert(proven == #buttons, "every published menu entry must be exercised")

-- A published entry that no menu can reach is the failure this exists to stop:
-- the count is asserted against the ids the suites know about.
assert(#buttons == 10, "menu_buttons must publish 10 operations, got " .. tostring(#buttons))

-- 3. Arming through a menu entry registers the CLEU handler exactly once: the
--    click path really starts the capture rather than only flipping a flag.
assert(#registrations == 1, "arming via a menu entry must register one CLEU handler")
assert(registrations[1][1] == "COMBAT_LOG_EVENT_UNFILTERED", "handler must be the CLEU event")

-- 4. And the capture a click armed is readable: flush logs the recorded lines.
logs = {}
probe.action_arm("all", 0)
registrations[1][2]("COMBAT_LOG_EVENT_UNFILTERED", {
    1.0, "SPELL_AURA_APPLIED", false, "Player-1-2", "Tester", 0, 0, "Player-1-2", "Tester", 0, 0, 768, "Cat Form", 0,
})
local captured, lines = probe.action_flush()
assert(captured == 1, "the entry-armed capture must hold the event, got " .. tostring(captured))
assert(type(lines) == "table" and #lines > 0, "flush must return the formatted lines")
local saw_form = false
for i = 1, #lines do
    if tostring(lines[i]):find("FORM id=768", 1, true) then saw_form = true end
end
assert(saw_form, "flushed lines must include the captured form event")
probe.action_disarm()

-- 5. BEHAVIORAL -- the menus' own blocks, run. Each block is wrapped in a chunk
--    whose only inputs are the stub objects a menu supplies in the client, so
--    what executes below IS the menu's widget-registration code.

-- 5a. Legacy tree (EaxRotations/main.lua): core.menu.button(id) builds the
--     widget and widget:render(label, description) returning true IS the click,
--     so only the widget named in CLICK fires and each entry can be exercised
--     on its own -- through the tree's own loop, not by calling run() directly.
local built = {}
local CLICK = { id = nil }
local core_stub = {
    menu = {
        button = function(id)
            local widget = {}
            function widget:render(label, description)
                built[id] = { label = label, description = description }
                return id == CLICK.id
            end
            return widget
        end,
    },
}
local elements_stub = {}
local legacy = assert(load_chunk(
    "local menu_elements, NS, core = ...\n" .. BLOCK["EaxRotations/main.lua"],
    "probe-block:main.lua"))
legacy(elements_stub, _G.EaxRotations, core_stub)
local cached = elements_stub.probe_buttons
assert(type(cached) == "table" and #cached == #buttons,
    "the legacy Diagnostics tree must build one probe widget per published entry, got "
    .. tostring(type(cached) == "table" and #cached or "no widget list"))

for i = 1, #buttons do
    local entry = buttons[i]
    CLICK.id = entry.id
    built = {}
    local before = #logs
    legacy(elements_stub, _G.EaxRotations, core_stub)
    local seen = built[entry.id]
    assert(seen ~= nil,
        "legacy tree must build a widget under the published id: " .. tostring(entry.id))
    assert(seen.label == entry.label,
        "legacy widget label must be the published label for " .. tostring(entry.id))
    assert(seen.description == entry.description,
        "legacy widget description must come from the published entry for " .. tostring(entry.id))
    assert(#logs > before,
        "a legacy click must reach the operation: " .. tostring(entry.id))
    local holds, message = EFFECT[entry.id](probe)
    assert(holds, "legacy click " .. tostring(entry.id) .. ": " .. tostring(message))
end

-- 5b. Declarative page (shared/declarative_menu_sylvanas.lua): the page's
--     Diagnostics section receives one button per published entry, and its
--     on_click is the click path.
local declared = {}
local section_stub = {}
function section_stub:button(id, label, opts)
    declared[#declared + 1] = {
        id = id, label = label,
        description = opts and opts.description,
        on_click = opts and opts.on_click,
    }
end
local declarative = assert(load_chunk(
    "local diag_section = ...\n"
        .. BLOCK["EaxRotations/shared/declarative_menu_sylvanas.lua"],
    "probe-block:declarative_menu_sylvanas.lua"))
declarative(section_stub)
assert(#declared == #buttons,
    "the declarative Diagnostics page must register one button per published entry, got "
    .. tostring(#declared))

for i = 1, #buttons do
    local entry = buttons[i]
    local widget = declared[i]
    assert(widget.id == entry.id,
        "declarative button " .. tostring(i) .. " must carry the published id, got "
        .. tostring(widget.id))
    assert(widget.label == entry.label,
        "declarative button " .. tostring(entry.id) .. " must carry the published label")
    assert(widget.description == entry.description,
        "declarative button " .. tostring(entry.id) .. " must carry the published description")
    assert(type(widget.on_click) == "function",
        "declarative button " .. tostring(entry.id) .. " must have an on_click")
    local before = #logs
    widget.on_click()
    assert(#logs > before,
        "a declarative click must reach the operation: " .. tostring(entry.id))
    local holds, message = EFFECT[entry.id](probe)
    assert(holds, "declarative click " .. tostring(entry.id) .. ": " .. tostring(message))
end
probe.action_disarm()

_G.plugin_info = nil
print("PASS test_live_probe_menu_wiring")
