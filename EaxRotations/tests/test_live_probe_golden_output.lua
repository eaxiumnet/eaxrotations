-- test_live_probe_golden_output.lua — freeze what a probe SESSION sees.
-- WHAT:  re-runs every published probe operation against the same mock engine and
--        compares the session-visible output line by line against the committed
--        baseline in tests/fixtures/live_probe_golden/session_output.txt.
-- WHEN:  rotation suite (and standalone: `lua EaxRotations/tests/test_live_probe_golden_output.lua`).
-- WHY:   the six-concern split and the prune were both proven behavior-neutral by
--        diffing this exact output by hand, and a hand-run instrument dies with
--        the temp directory it was written in. This comparison is the only thing
--        that catches a refactor of the harness silently changing what a session
--        sees, so it lives in the tree next to the other fixtures.
--        Deliberate regeneration: `lua EaxRotations/tests/test_live_probe_golden_output.lua --update`
--        rewrites the baseline AFTER printing the diff; review that diff as part
--        of the commit that changes the output.
-- SAFETY: fully mocked (no engine, no unit, spell or game state is touched) and it
--         reads only its own committed fixture. Compare is EOL-insensitive.
-- INTERPRETER-INVARIANT: CI pins Lua 5.1 while a dev shell may be 5.4, and
--         `tostring(1.0)` is "1" on 5.1 but "1.0" on 5.4. Every payload value
--         below is therefore an integer or a non-integral float, so this
--         comparison can only fail on a real output change, never on the
--         interpreter. The baseline is authoritative as produced under 5.1.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path
package.loaded["shared/live_probe_sylvanas"] = nil

local UPDATE = false
if type(_G.arg) == "table" and _G.arg[1] == "--update" then UPDATE = true end
local BASELINE = "EaxRotations/tests/fixtures/live_probe_golden/session_output.txt"

-- The output a session sees: everything the probe writes to the console log, plus
-- the structured values the operations hand back. The harness's own introspection
-- (its member list) is deliberately NOT part of this contract.
local SESSION = {}
local lines_seen = 0

local function emit(line)
    lines_seen = lines_seen + 1
    SESSION[lines_seen] = tostring(line)
end

local function dump(tag, lines)
    emit("### " .. tag .. " (" .. #lines .. " lines)")
    for i = 1, #lines do emit(lines[i]) end
end

-- ---------------------------------------------------------------------------
-- Mock engine: the same surfaces the live-probe suites use, so this suite also
-- pins nothing the others do not already assume.
-- ---------------------------------------------------------------------------
local sink = {}
local registrations = {}

local player = {
    guid = "Player-1-2",
    get_buffs = function() return { { buff_id = 25218, buff_name = "Power Word: Shield", count = 1, remaining = 20 } } end,
    get_auras = function() return {} end,
    get_debuffs = function() return {} end,
    get_power = function(self, power_type) if power_type == 3 then return 42 end if power_type == 1 then return 7 end return nil end,
    get_guid = function(self) return self.guid end,
    get_race = function() return 3 end,
    get_form = function() return 1 end,
    get_attack_power = function() return 1234 end,
    get_haste = function() return 12 end,
}

_G.core = {
    log = function(message) sink[#sink + 1] = message end,
    log_warning = function() end,
    log_error = function() end,
    time = function() return 3312.5 end,
    runtime_generation = 4,
    damage_meter = {
        is_available = function() return true end,
        get_session_duration = function(self, session) return 37.4 end,
        hidden_extra = "a-member-only-the-build-knows-about",
    },
    spell_book = { get_spell_cooldown = function() return 0 end },
    object_manager = { get_local_player = function() return player end },
    input = {}, menu = {},
}
_G.plugin_info = { player_class_name = "Druid" }
_G.EaxRotations = {
    log = function(message) sink[#sink + 1] = message end,
    time_now = function() return 100 end,
    POWER_RAGE = 1,
    POWER_ENERGY = 3,
    GetPlayer = function() return player end,
    buff_points = function() return { 1265, 20 } end,
    debuff_points = function() return { 5 } end,
    has_player_buff = function() return true end,
    spell_ready = function() return true end,
    cooldown_remains = function() return 0 end,
    unit_mana_pct = function() return 88 end,
    runtime_generation = 3,
    is_api_health_broken = function() return false end,
    reset_api_health = function() end,
    register_on_game_event = function(event_name, callback)
        registrations[#registrations + 1] = { event_name, callback }
        return true
    end,
    AuraProbe = {
        collect_player_auras = function()
            return { { source = "unit:get_buffs", id = 25218, name = "Power Word: Shield" } }
        end,
    },
    DruidSpells = {
        CatForm = { _meta = { ids = { 768 } } },
        BearForm = { _meta = { ids = { 5487 } } },
        TravelForm = { _meta = { ids = { 783 } } },
    },
}

local probe = require("shared/live_probe_sylvanas")

-- ---------------------------------------------------------------------------
-- The capture: one pass over every operation, in the order the checklist runs
-- them, with the same values the field session would see.
-- ---------------------------------------------------------------------------
emit("== load state ==")
emit("registrations before any call: " .. #registrations)

local report = probe.report()
dump("report", report.lines)
emit("report counters: present=" .. report.present)

local snapshot = probe.sample("golden")
emit("sample: form=" .. tostring(snapshot.form) .. " energy=" .. tostring(snapshot.energy)
    .. " rage=" .. tostring(snapshot.rage) .. " mana=" .. tostring(snapshot.mana_pct)
    .. " ap=" .. tostring(snapshot.ap) .. " haste=" .. tostring(snapshot.haste))

dump("reader_report", probe.reader_report().lines)
dump("integrity_report (unarmed)", probe.integrity_report().lines)

-- The published contract: one probe per operation, same ids, labels, order.
local buttons = probe.menu_buttons()
emit("== menu_buttons: " .. #buttons .. " entries ==")
for i = 1, #buttons do
    emit(i .. " id=" .. buttons[i].id .. " | label=" .. buttons[i].label
        .. " | desc=" .. buttons[i].description)
end

-- Every arm scope, including one the module does not know (it must degrade).
for _, scope in ipairs({ "all", "forms", "dots", "rage", "bogus" }) do
    probe.action_arm(scope, 1)
    local status = probe.status()
    emit("arm scope=" .. scope .. " -> armed=" .. tostring(status.armed)
        .. " scope=" .. tostring(status.scope) .. " forms=" .. status.forms
        .. " spells=" .. status.spells .. " captured=" .. status.captured)
end
probe.disarm()
emit("disarm -> armed=" .. tostring(probe.status().armed))

-- A real CLEU round trip through the armed ring: an own form change, two ticks
-- of one DoT (the interval read), incoming damage, and a foreign unit's aura
-- (which must be ignored).
sink = {}
probe.action_arm("all", 1)
local handler = registrations[1][2]

local function cleu(sub_event, spell_id, dest, amount, stamp, source)
    local args = { stamp or 1, sub_event }
    args[4] = source == nil and "Player-1-2" or source
    args[8] = dest
    args[12] = spell_id
    args[15] = amount
    handler("COMBAT_LOG_EVENT_UNFILTERED", args)
end

cleu("SPELL_AURA_APPLIED", 768)
cleu("SPELL_PERIODIC_DAMAGE", 172, nil, 90, 3)
cleu("SPELL_PERIODIC_DAMAGE", 172, nil, 91, 5)
cleu("SWING_DAMAGE", nil, "Player-1-2", 250, 6)
cleu("SPELL_AURA_APPLIED", 768, nil, nil, 7, "Creature-0-1")
local captured, flush_lines = probe.flush()
emit("flush count=" .. captured)
dump("flush (armed, unchanged)", flush_lines)

-- A client that reacts mid-capture: the 0.5 diff names it and calls the capture
-- untrustworthy.
sink = {}
probe.action_arm("rage", 0)
_G.core.runtime_generation = 5
_G.core.log = nil
local captured2, flush_lines2 = probe.flush()
emit("flush count=" .. captured2)
dump("flush (client reacted)", flush_lines2)
_G.core.log = function(message) sink[#sink + 1] = message end

-- The realistic quiet session: arm, provoke nothing, flush.
sink = {}
probe.action_arm("all", 0)
local captured3, flush_lines3 = probe.flush()
emit("flush count=" .. captured3)
dump("flush (empty, unchanged)", flush_lines3)
probe.disarm()

-- ---------------------------------------------------------------------------
-- Compare with the committed baseline.
-- ---------------------------------------------------------------------------
local function read_baseline()
    local handle = io.open(BASELINE, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    local rows = {}
    local normalized = (text:gsub("\r\n", "\n"))
    local start = 1
    while true do
        local at = normalized:find("\n", start, true)
        if not at then
            if normalized:sub(start) ~= "" then rows[#rows + 1] = normalized:sub(start) end
            break
        end
        rows[#rows + 1] = normalized:sub(start, at - 1)
        start = at + 1
    end
    while #rows > 0 and rows[#rows] == "" do rows[#rows] = nil end
    return rows
end

if UPDATE then
    local handle = assert(io.open(BASELINE, "wb"), "cannot write " .. BASELINE)
    handle:write(table.concat(SESSION, "\n") .. "\n")
    handle:close()
    print("UPDATED " .. BASELINE .. " with " .. #SESSION .. " session line(s).")
    print("Review the diff before committing: this file IS the session contract.")
    os.exit(0)
end

local baseline = read_baseline()
assert(baseline ~= nil, "missing baseline fixture: " .. BASELINE
    .. " (regenerate with --update and commit the result)")

local mismatches = 0
local limit = math.max(#baseline, #SESSION)
for i = 1, limit do
    local expected, actual = baseline[i], SESSION[i]
    if expected ~= actual then
        mismatches = mismatches + 1
        if mismatches <= 8 then
            print(string.format("line %d differs:\n  baseline: %s\n  current : %s",
                i, tostring(expected), tostring(actual)))
        end
    end
end

if mismatches > 0 then
    print(string.format(
        "FAIL test_live_probe_golden_output: %d session line(s) differ (baseline %d, current %d)",
        mismatches, #baseline, #SESSION))
    print("A session would see different output. If the change is deliberate, run"
        .. " --update, review the diff, and commit the fixture with it.")
    os.exit(1)
end

print(string.format("PASS test_live_probe_golden_output (%d session lines identical)", #SESSION))
