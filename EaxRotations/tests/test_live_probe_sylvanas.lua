-- test_live_probe_sylvanas.lua — unit tests for the live-probe capture harness.
-- WHAT:  mocks the engine surfaces the probe reads and proves the three
--        contracts the Block 0/1 session depends on: report() distinguishes
--        present from absent surfaces, sample() is nil-safe with no player, and
--        the armed CLEU ring classifies form/tick/incoming events, computes the
--        tick interval, respects its fixed capacity, and stops on disarm().
-- WHEN:  rotation suite (and standalone).
-- WHY:   the probe runs in the live client, where a wrong classification or an
--        unbounded ring silently corrupts the very measurement the session is
--        there to take. A suite is the only place that can be checked.
-- SAFETY: fully mocked; no unit, spell or game state is touched.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

-- The harness is one concern per file, so a "fresh load" means all of them:
-- the capture ring's armed state lives in its own part, and clearing only the
-- facade would leave a previous test's capture behind.
local function unload_probe()
    for _, name in ipairs({
        "shared/live_probe_kit_sylvanas", "shared/live_probe_truth_sylvanas",
        "shared/live_probe_sample_sylvanas", "shared/live_probe_capture_sylvanas",
        "shared/live_probe_readers_sylvanas", "shared/live_probe_integrity_sylvanas",
        "shared/live_probe_menu_sylvanas", "shared/live_probe_sylvanas",
    }) do
        package.loaded[name] = nil
    end
end
unload_probe()

local logs = {}
local registrations = {}

local player = {
    guid = "Player-1-2",
    is_mounted = function() return false end,
    get_buffs = function()
        return { { buff_id = 25218, buff_name = "Power Word: Shield", count = 1, remaining = 20 } }
    end,
    get_auras = function() return {} end,
    get_debuffs = function() return {} end,
    get_power = function(self, power_type)
        if power_type == 3 then return 42 end
        if power_type == 1 then return 7 end
        return nil
    end,
    get_guid = function(self) return self.guid end,
    get_race = function() return 3 end,
    get_form = function() return 1 end,
    get_attack_power = function() return 1234 end,
    get_haste = function() return 12 end,
}

_G.core = {
    log = function(message) logs[#logs + 1] = message end,
    object_manager = { get_local_player = function() return player end },
}

_G.EaxRotations = {
    log = function(message) logs[#logs + 1] = message end,
    time_now = function() return 100.0 end,
    POWER_RAGE = 1,
    POWER_ENERGY = 3,
    GetPlayer = function() return player end,
    buff_points = function() return { 1265, 20 } end,
    debuff_points = function() return { 5 } end,
    has_player_buff = function() return true end,
    spell_ready = function() return true end,
    cooldown_remains = function() return 0 end,
    unit_mana_pct = function() return 88 end,
    AuraProbe = {
        collect_player_auras = function()
            return { { source = "unit:get_buffs", id = 25218, name = "Power Word: Shield" } }
        end,
    },
    register_on_game_event = function(event_name, callback)
        registrations[#registrations + 1] = { event_name, callback }
        return true
    end,
}

local probe = require("shared/live_probe_sylvanas")
assert(type(probe) == "table", "module must load")
assert(_G.EaxRotations.LiveProbe == probe, "module must install NS.LiveProbe")

-- 1. Nothing is registered until arm() -- the module costs nothing at rest.
assert(#registrations == 0, "module must not register before arm()")

-- 2. report(): present surfaces, aura points, race.
local report = probe.report()
assert(type(report) == "table" and report.present > 0, "report must count present surfaces")
local function has(lines, needle)
    for i = 1, #lines do
        if tostring(lines[i]):find(needle, 1, true) then return true end
    end
    return false
end
assert(has(report.lines, "NS.buff_points"), "report must list the buff_points surface")
assert(has(report.lines, "points id=25218") and has(report.lines, "points[1]=1265"),
    "report must print the Pattern-11 points value for the absorb row")
assert(has(report.lines, "race = 3"), "report must read the race surface")

-- 3. report(): an absent surface is reported as absent, never fabricated.
local saved = _G.EaxRotations.buff_points
_G.EaxRotations.buff_points = nil
local sparse = probe.report()
assert(has(sparse.lines, "buff_points") and has(sparse.lines, "ABSENT"),
    "report must mark absent surfaces")
assert(has(sparse.lines, "Pattern-11 reads unavailable"),
    "report must state the consequence of an absent points surface")
_G.EaxRotations.buff_points = saved

-- 4. sample(): nil-safe with no player, and reads the player when present.
player.get_power = nil
local no_power = probe.sample("no-power")
assert(type(no_power) == "table", "sample must return a snapshot table")
player.get_power = function(self, power_type)
    if power_type == 3 then return 42 end
    if power_type == 1 then return 7 end
    return nil
end
local snap = probe.sample("before-shift")
assert(snap.form == 1, "sample must read the form surface")
assert(snap.energy == 42, "sample must read energy through get_power")

-- 5. arm(): registers CLEU once and reports the watch sets.
assert(probe.arm({ forms = { 768 }, spells = { 172 }, raw_events = 1 }) == true,
    "arm must succeed with a working registrar")
assert(#registrations == 1, "arm must register exactly one CLEU handler")
assert(registrations[1][1] == "COMBAT_LOG_EVENT_UNFILTERED", "handler must be the CLEU event")
local handler = registrations[1][2]

-- CLEU fixed prefix: args[4] = source guid, args[8] = destination guid. The
-- handler records only events sourced by (or landing on) this player, so the
-- helper passes the player's guid as the source by default.
local function cleu(sub, spell_id, dest_guid, amount, stamp, source_guid)
    local args = { stamp or 1.0, sub }
    args[4] = source_guid == nil and "Player-1-2" or source_guid
    args[8] = dest_guid
    args[12] = spell_id
    args[15] = amount
    handler("COMBAT_LOG_EVENT_UNFILTERED", args)
end

cleu("SPELL_AURA_APPLIED", 768)                 -- form shift (Furor energy read)
cleu("SPELL_PERIODIC_DAMAGE", 172, nil, 90, 3.0) -- first DoT tick
cleu("SPELL_PERIODIC_DAMAGE", 172, nil, 91, 5.0) -- second tick -> interval
cleu("SWING_DAMAGE", nil, "Player-1-2", 250, 6.0) -- incoming damage (rage read)
-- Another unit's aura/tick is not a probe of this character: it must be ignored.
cleu("SPELL_AURA_APPLIED", 768, nil, nil, 7.0, "Creature-0-1")
cleu("SPELL_PERIODIC_DAMAGE", 172, nil, 92, 8.0, "Creature-0-1")

local status = probe.status()
assert(status.scope == "all", "status must report the capture scope, got " .. tostring(status.scope))
assert(status.captured == 4, "four armed events must be captured, got " .. tostring(status.captured))
local captured, lines = probe.flush()
assert(captured == 4, "flush must report the captured count")
assert(has(lines, "FORM id=768 energy=42"), "form slot must carry the energy snapshot")
assert(has(lines, "TICK id=172 interval=2.00s"), "tick interval must be computed from stamps")
assert(has(lines, "INCOMING spell=0 amount=250 rage=7"), "incoming slot must carry rage")
assert(has(lines, "raw first-event args"), "raw mode must dump the CLEU layout once")

-- 6. disarm(): capture stops immediately.
probe.disarm()
cleu("SPELL_PERIODIC_DAMAGE", 172, nil, 92, 9.0)
assert(probe.status().captured == 4, "no event may be captured after disarm()")

-- 7. The ring is fixed-size: overflow is counted, never grown.
assert(probe.arm({ spells = { 172 } }) == true, "re-arm must reset the ring")
for i = 1, 200 do
    cleu("SPELL_PERIODIC_DAMAGE", 172, nil, 1, 10 + i)
end
local bounded = probe.status()
assert(bounded.captured == 64, "ring must cap at 64 slots, got " .. tostring(bounded.captured))
assert(bounded.dropped == 136, "overflow must be counted, got " .. tostring(bounded.dropped))
probe.disarm()

-- 8. Scopes: what a menu action arms decides what gets recorded.
assert(probe.action_arm("dots", 0) == true, "action_arm(dots) must arm")
assert(probe.status().scope == "dots", "dots scope must be reported")
cleu("SPELL_AURA_APPLIED", 768, nil, nil, 20.0) -- own aura: not part of dots
cleu("SPELL_PERIODIC_DAMAGE", 900, nil, 10, 21.0) -- own tick: no id filter in dots
cleu("SWING_DAMAGE", nil, "Player-1-2", 100, 22.0) -- incoming: not part of dots
assert(probe.status().captured == 1,
    "dots scope must record own ticks only, got " .. tostring(probe.status().captured))
probe.disarm()

assert(probe.action_arm("rage", 1) == true, "action_arm(rage) must arm")
cleu("SPELL_PERIODIC_DAMAGE", 900, nil, 10, 23.0)
cleu("SWING_DAMAGE", nil, "Player-1-2", 100, 24.0)
assert(probe.status().captured == 1,
    "rage scope must record incoming damage only, got " .. tostring(probe.status().captured))
assert(probe.action_arm(nil, 0) == true, "an unknown scope must fall back, not fail")
assert(probe.status().scope == "all", "an unknown scope must arm as scope=all")
probe.disarm()

-- 9. Form ids resolve BY NAME from the class spell map -- the module never
--    carries a spell id -- and a class with no form list degrades to scope=all
--    instead of arming an empty capture.
_G.plugin_info = { player_class_name = "Druid" }
_G.EaxRotations.DruidSpells = {
    CatForm = { _meta = { ids = { 768 } } },
    BearForm = { _meta = { ids = { 5487 } } },
    TravelForm = { _meta = { ids = { 783 } } },
}
assert(probe.action_arm("forms", 1) == true, "action_arm(forms) must arm for a Druid")
assert(probe.status().forms == 3,
    "form ids must resolve by name, got " .. tostring(probe.status().forms))
cleu("SPELL_AURA_REMOVED", 768, nil, nil, 30.0)
assert(probe.status().captured == 1, "a resolved form id must be captured")
probe.disarm()
_G.EaxRotations.DruidSpells = nil
assert(probe.action_arm("forms", 0) == true, "an unknown class must still arm")
assert(probe.status().scope == "all", "an unknown class must degrade to scope=all")
probe.disarm()
_G.plugin_info = nil

-- 10. reader_report() (Block 0.4): inventory the external-reader surfaces the
--     build exposes -- PRESENT/ABSENT per surface, the members and value types
--     each carries, the specific reads our lanes make, live values, and a name
--     scan so a differently-named surface still shows up.
_G.core.damage_meter = {
    is_available = function() return true end,
    get_session_duration = function(self, session) return 42.5 end,
    hidden_extra = "a-member-only-the-build-knows-about",
}
_G.core.spell_book = { get_spell_cooldown = function() return 0 end }
local readers = probe.reader_report()
assert(type(readers) == "table" and type(readers.lines) == "table",
    "reader_report must return the formatted lines")
assert(has(readers.lines, "core.damage_meter (built-in damage meter): PRESENT"),
    "reader_report must mark an exposed surface PRESENT")
assert(has(readers.lines, "member hidden_extra = string"),
    "reader_report must list the members the build actually carries, not a fixed list")
assert(has(readers.lines, "members: 3"), "reader_report must count the members")
assert(has(readers.lines, "read get_session_duration = function"),
    "reader_report must report a named read our lanes make")
assert(has(readers.lines, "live is_available = true"),
    "reader_report must read the live availability value")
assert(has(readers.lines, "live get_session_duration = 42.5"),
    "reader_report must read the live session duration")
assert(has(readers.lines, "read get_spell_cooldown_information: ABSENT"),
    "reader_report must mark a named read the build lacks ABSENT")
assert(has(readers.lines, "core.game_ui (game UI readers): ABSENT"),
    "reader_report must mark a missing surface ABSENT")
assert(has(readers.lines, "engine cooldown_tracker"), "reader_report must probe the cooldown tracker module")
assert(has(readers.lines, "engine spell_helper"), "reader_report must probe the spell helper module")

-- ...and the module PRESENT path, which is a different branch: when the engine
-- module really loads (a table), its members and the reads our lanes make must
-- be inventoried -- not merely reported missing.
package.loaded["common/utility/cooldown_tracker"] = {
    has_any_relevant_defensive_up = function() return true end,
    is_spell_ready = function() return false end,
}
local loaded = probe.reader_report()
assert(has(loaded.lines, "engine cooldown_tracker (enemy cooldown observation): PRESENT"),
    "reader_report must mark a loaded engine module PRESENT")
assert(has(loaded.lines, "read is_spell_ready = function"),
    "reader_report must list a named read the loaded module carries")
assert(has(loaded.lines, "read has_any_relevant_defensive_up = function"),
    "reader_report must list every named read the loaded module carries")
assert(has(loaded.lines, "engine spell_helper (native readiness"),
    "the unloaded module must still be probed in the same run")
package.loaded["common/utility/cooldown_tracker"] = nil
assert(readers.absent_reads >= 2,
    "reader_report must count the reads our lanes make that the build lacks, got "
    .. tostring(readers.absent_reads))

-- A surface whose name the probe was never told must still be found, from the
-- build's own key inventory: that is how "is there a cooldown manager?" is
-- answered without inventing a name.
_G.core.cooldown_manager = { begin_cooldown = function() end }
local scanned = probe.reader_report()
assert(has(scanned.lines, "scan core.cooldown_manager = table (1 member(s))"),
    "reader_report must discover a matching engine key it was never told about")
assert(has(scanned.lines, "scan core.damage_meter = table (3 member(s))"),
    "reader_report must scan the whole engine table, not only the known targets")
assert(has(scanned.lines, "0.4 summary:"), "reader_report must print a summary line")
assert(type(scanned.scan_hits) == "number" and scanned.scan_hits >= 1,
    "reader_report must report the scan hit count")
_G.core.cooldown_manager = nil
_G.core.damage_meter = nil
_G.core.spell_book = nil

-- 11. integrity_report() + the arm -> flush comparison (Block 0.5): the
--     client's own surface state, read at both ends, so "nothing reacted" is
--     evidence rather than an assumption.
_G.core.runtime_generation = 7
_G.EaxRotations.runtime_generation = 3
_G.EaxRotations.is_api_health_broken = function() return false end
_G.core.time = function() return 123.5 end
local integrity = probe.integrity_report()
assert(type(integrity) == "table" and type(integrity.lines) == "table",
    "integrity_report must return the formatted lines")
assert(has(integrity.lines, "core.runtime_generation = number 7"),
    "integrity_report must carry the runtime generation by value")
assert(has(integrity.lines, "NS.runtime_generation = number 3"),
    "integrity_report must carry our mirrored generation")
assert(has(integrity.lines, "NS.is_api_health_broken() = callable -> false"),
    "integrity_report must call the API-health surface and report its value")
assert(has(integrity.lines, "core.log = function"), "integrity_report must report the log sinks by type")
assert(has(integrity.lines, "core.object_manager = table"), "integrity_report must report the engine tables by type")
assert(has(integrity.lines, "core.time live read = ok (number)"),
    "integrity_report must prove the engine still answers with a live read")

-- The canary accepts either shape the engine exposes for core.time: a callable,
-- or a table carrying get()/now(). Both are asserted because a build that ships
-- the table shape would otherwise read as "not callable" and be missed.
_G.core.time = { get = function() return 55.5 end }
assert(has(probe.integrity_report().lines, "core.time live read = ok (number)"),
    "integrity_report must read a table-shaped core.time through get()")
_G.core.time = { now = function() return 55.5 end }
assert(has(probe.integrity_report().lines, "core.time live read = ok (number)"),
    "integrity_report must read a table-shaped core.time through now()")
_G.core.time = function() return 123.5 end
assert(has(integrity.lines, "core.damage_meter = ABSENT"),
    "integrity_report must mark an absent engine surface ABSENT")
assert(has(integrity.lines, "0.5 state:"), "integrity_report must print the surface count")
assert(has(integrity.lines, "0.5 comparison (arm -> now):"),
    "integrity_report must pair the current state with the arm snapshot once a capture exists")

-- A client that reacts mid-capture is caught, named, and marked untrustworthy.
logs = {}
probe.arm({ raw_events = 0 })
_G.core.runtime_generation = 8
_G.core.log = nil
probe.flush()
assert(has(logs, "0.5 integrity: 2 surface(s) CHANGED"),
    "flush must count the changed surfaces, got: " .. table.concat(logs, " / "))
assert(has(logs, "0.5 integrity CHANGED core.runtime_generation: number 7 -> number 8"),
    "flush must name the bumped generation with both values")
assert(has(logs, "0.5 integrity CHANGED core.log: function -> ABSENT"),
    "flush must name a surface that disappeared")
assert(has(logs, "re-run before trusting this capture"),
    "flush must say the capture is untrustworthy when the client reacted")
probe.disarm()

-- A quiet capture says so, and an empty capture still carries the comparison:
-- that is the whole 0.5 session (arm, provoke nothing, flush).
logs = {}
probe.arm({ raw_events = 0 })
local captured = probe.flush()
assert(captured == 0, "an empty capture must still be a valid capture")
assert(has(logs, "flush: no events captured"), "an empty capture must say so")
assert(has(logs, "0.5 integrity: UNCHANGED across the capture"),
    "an unchanged capture must report UNCHANGED, got: " .. table.concat(logs, " / "))
probe.disarm()
_G.core.log = function(message) logs[#logs + 1] = message end

-- 12. menu_buttons(): the single operation list both menus iterate.
local actions = probe.menu_buttons()
assert(type(actions) == "table" and #actions >= 8,
    "menu_buttons must publish the operation list, got " .. tostring(actions and #actions))
local seen_ids = {}
local saw = {}
for i = 1, #actions do
    local entry = actions[i]
    assert(type(entry.id) == "string" and entry.id ~= "", "every button needs an id")
    assert(type(entry.label) == "string" and entry.label ~= "", "every button needs a label")
    assert(type(entry.run) == "function", "every button needs a run function: " .. tostring(entry.id))
    assert(not seen_ids[entry.id], "button ids must be unique: " .. tostring(entry.id))
    seen_ids[entry.id] = true
    saw[entry.id] = true
end
for _, wanted in ipairs({ "eax_probe_report", "eax_probe_readers", "eax_probe_integrity",
    "eax_probe_sample", "eax_probe_arm_all",
    "eax_probe_arm_forms", "eax_probe_arm_dots", "eax_probe_arm_rage",
    "eax_probe_flush", "eax_probe_disarm" }) do
    assert(saw[wanted], "menu_buttons must expose " .. wanted)
end

-- 13. A failed registrar is reported, not silently armed.
_G.EaxRotations.register_on_game_event = nil
unload_probe()
local fresh = require("shared/live_probe_sylvanas")
assert(has(fresh.integrity_report().lines, "nothing armed yet"),
    "a freshly loaded probe must report that nothing is armed yet")
assert(fresh.arm() == false, "arm must fail when the event API is absent")
assert(_G.EaxRotations.LiveProbe ~= nil, "module must still install NS.LiveProbe")

print("PASS test_live_probe_sylvanas")
