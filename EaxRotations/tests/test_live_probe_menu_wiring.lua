-- test_live_probe_menu_wiring.lua — the live-probe harness must be REACHABLE.
-- WHAT:  proves the Diagnostics entries that run the probe exist in BOTH menu
--        implementations, that each menu builds its widgets from the module's
--        single published list (NS.LiveProbe.menu_buttons()) instead of a copied
--        id list, and that every published entry actually lands in the module
--        when clicked (arm flips status().armed and scope, sample/report/flush
--        log, disarm stops the capture).
-- WHEN:  rotation suite (and standalone).
-- WHY:   the harness is inert by design, so a missing menu registration leaves a
--        module that loads and does nothing -- the dead-scaffolding failure this
--        repo's gates exist to catch, and exactly what the audit found: the
--        smoke-checklist RUN lines named calls no session could type. Deleting a
--        registration now fails here instead of silently.
-- SAFETY: fully mocked; no unit, spell or game state is touched. The two menu
--         files are read as text only (the wiring is source-level by nature:
--         the legacy tree and the declarative page build widgets through the
--         engine's menu API, which is not loadable outside the client).

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

-- 1. Both menu implementations build their probe widgets from the published
--    list -- not from a copied id list, which is what would drift.
for i = 1, #MENUS do
    local menu = MENUS[i]
    local text = read_file(menu.path)
    assert(text ~= nil, "menu file must exist: " .. menu.path)
    assert(text:find(menu.anchor, 1, true) ~= nil,
        menu.path .. " must keep its Diagnostics section")
    assert(text:find("menu_buttons", 1, true) ~= nil,
        menu.path .. " must consume NS.LiveProbe.menu_buttons()")
    assert(text:find("entry.id", 1, true) ~= nil,
        menu.path .. " must register a widget per published entry id")
    assert(text:find("eax_probe_", 1, true) == nil,
        menu.path .. " must not hardcode probe button ids (the module owns them)")
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

_G.plugin_info = nil
print("PASS test_live_probe_menu_wiring")
