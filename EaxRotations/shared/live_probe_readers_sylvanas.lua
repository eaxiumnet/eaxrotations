-- live_probe_readers_sylvanas.lua — Block 0.4 external-reader inventory.
-- WHAT:  reader_report(): the external-reader surfaces this build exposes (the
--        built-in damage meter, the cooldown readers our CD lanes use, the
--        engine CD modules) reported PRESENT/ABSENT with the members and value
--        types each carries, plus a name scan over the engine table's own keys
--        so a differently-named surface is still found.
-- WHEN:  run from the Diagnostics "Probe: Reader Surfaces (0.4)" entry.
-- WHY:   0.4 asks what the built-in damage meter and cooldown surfaces expose to
--        external readers; that verdict must not depend on hand-inspection.
-- SAFETY: names come only from surfaces this tree already reads, every lookup is
--        a runtime index, nothing is written to the engine, and the output is
--        bounded per table.
local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end
local type = type
local pcall = pcall
local tostring = tostring
local string_format = string.format
local table_sort = table.sort
local kit = require("shared/live_probe_kit_sylvanas")
local out, lookup = kit.out, kit.lookup
local M = {}
-- ---------------------------------------------------------------------------
-- External-reader surfaces (Block 0.4)
--
-- 0.4 asks what the built-in damage meter and the cooldown surfaces expose to
-- EXTERNAL READERS. The candidates below are names this tree already reads --
-- never invented: core.damage_meter.{is_available,get_session_duration}
-- (core_sylvanas.lua), core.spell_book.{get_spell_cooldown,
-- get_spell_cooldown_information}, core.game_ui.get_talent_info (main_sylvanas),
-- and the engine modules core_sylvanas adapts:
-- common/utility/cooldown_tracker.{has_any_relevant_defensive_up,is_spell_ready,
-- get_remaining_cooldown} and common/utility/spell_helper.{is_spell_castable,
-- get_remaining_charge_cooldown}. Each is resolved at RUNTIME by name, reported
-- PRESENT with the members and value types it carries, or ABSENT. A discovery
-- scan over the real engine table's own keys then reports any key whose name
-- looks meter/cooldown-ish, so a surface this build names differently is found
-- from the build's own inventory instead of being missed -- which is also the
-- only honest way to answer "is there a cooldown manager surface at all".
-- ---------------------------------------------------------------------------
local READER_MEMBER_LIMIT = 16  -- members listed per table (output bound)
local READER_SCAN_LIMIT = 24    -- discovery-scan lines (output bound)
local READER_SCAN_NEEDLES = { "meter", "cooldown", "tracker", "dps", "damage", "cd" }

local READER_TARGETS = {
    {
        root = "core", name = "damage_meter",
        label = "core.damage_meter (built-in damage meter)",
        reads = { "is_available", "get_session_duration" },
        -- The two reads our tree already makes (NS.damage_meter_session_duration):
        -- the availability flag and the current session length, in seconds.
        live = {
            { name = "is_available", args = {} },
            { name = "get_session_duration", args = { 1 } },
        },
    },
    {
        root = "core", name = "spell_book",
        label = "core.spell_book (cooldown readers)",
        reads = { "get_spell_cooldown", "get_spell_cooldown_information" },
    },
    {
        root = "core", name = "game_ui",
        label = "core.game_ui (game UI readers)",
        reads = { "get_talent_info" },
    },
}

local READER_MODULES = {
    {
        path = "common/utility/cooldown_tracker",
        label = "engine cooldown_tracker (enemy cooldown observation)",
        reads = { "has_any_relevant_defensive_up", "is_spell_ready", "get_remaining_cooldown" },
    },
    {
        path = "common/utility/spell_helper",
        label = "engine spell_helper (native readiness: cooldown/range/resource/facing/LoS)",
        reads = { "is_spell_castable", "get_remaining_charge_cooldown" },
    },
}

local function sorted_keys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        keys[#keys + 1] = key
    end
    table_sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

-- What the table carries: every member with its value type, bounded. Sorted so
-- two sessions (or two builds) diff cleanly.
local function describe_table(tbl)
    local keys = sorted_keys(tbl)
    for i = 1, #keys do
        if i > READER_MEMBER_LIMIT then
            out(string_format("[LiveProbe]     ... %d more member(s)", #keys - READER_MEMBER_LIMIT))
            break
        end
        out(string_format("[LiveProbe]     member %s = %s", tostring(keys[i]), type(tbl[keys[i]])))
    end
    out(string_format("[LiveProbe]     members: %d", #keys))
end

-- The specific reads our lanes make: present (with the value type a session
-- would have to handle) or ABSENT.
local function describe_reads(tbl, reads)
    local absent = 0
    for i = 1, #reads do
        local name = reads[i]
        local kind = type(tbl) == "table" and type(tbl[name]) or "nil"
        if kind == "nil" then
            absent = absent + 1
            out(string_format("[LiveProbe]     read %s: ABSENT", name))
        else
            out(string_format("[LiveProbe]     read %s = %s", name, kind))
        end
    end
    return absent
end

-- Live values for the reads our tree already calls, so the verdict carries the
-- actual numbers and not just the member names.
local function describe_live(tbl, live)
    for i = 1, #live do
        local entry = live[i]
        local fn = type(tbl) == "table" and tbl[entry.name] or nil
        if type(fn) ~= "function" then
            out(string_format("[LiveProbe]     live %s: not callable", entry.name))
        else
            local args = entry.args or {}
            local ok, value = pcall(fn, tbl, args[1])
            if ok then
                out(string_format("[LiveProbe]     live %s = %s", entry.name, tostring(value)))
            else
                out(string_format("[LiveProbe]     live %s: ERROR %s", entry.name, tostring(value)))
            end
        end
    end
end

function M.reader_report()
    kit.reset_lines()
    out("[LiveProbe] 0.4 external readers -- what this build exposes to readers")
    local present, absent, absent_reads = 0, 0, 0
    for i = 1, #READER_TARGETS do
        local target = READER_TARGETS[i]
        local surface = lookup(target.root, target.name)
        if type(surface) == "table" then
            present = present + 1
            out(string_format("[LiveProbe] reader %s: PRESENT", target.label))
            describe_table(surface)
        else
            absent = absent + 1
            out(string_format("[LiveProbe] reader %s: ABSENT", target.label))
        end
        absent_reads = absent_reads + describe_reads(surface, target.reads)
        describe_live(surface, target.live or {})
    end
    for i = 1, #READER_MODULES do
        local module = READER_MODULES[i]
        local ok, loaded = pcall(require, module.path)
        if not ok or type(loaded) ~= "table" then
            absent = absent + 1
            out(string_format("[LiveProbe] reader %s: ABSENT (module did not load)", module.label))
        else
            present = present + 1
            out(string_format("[LiveProbe] reader %s: PRESENT", module.label))
            describe_table(loaded)
            absent_reads = absent_reads + describe_reads(loaded, module.reads)
        end
    end
    -- Discovery: the build's own key inventory is the source of truth for a
    -- surface whose name we were never told.
    local hits = 0
    local engine = _G["core"]
    if type(engine) == "table" then
        local keys = sorted_keys(engine)
        for i = 1, #keys do
            local name = tostring(keys[i])
            local lower = name:lower()
            local matched = false
            for n = 1, #READER_SCAN_NEEDLES do
                if lower:find(READER_SCAN_NEEDLES[n], 1, true) then
                    matched = true
                    break
                end
            end
            if matched then
                hits = hits + 1
                if hits <= READER_SCAN_LIMIT then
                    local value = engine[keys[i]]
                    local extra = ""
                    if type(value) == "table" then
                        local members = 0
                        for _ in pairs(value) do
                            members = members + 1
                        end
                        extra = string_format(" (%d member(s))", members)
                    end
                    out(string_format("[LiveProbe]     scan core.%s = %s%s", name, type(value), extra))
                end
            end
        end
        if hits > READER_SCAN_LIMIT then
            out(string_format("[LiveProbe]     ... %d more matching key(s)", hits - READER_SCAN_LIMIT))
        end
    else
        out("[LiveProbe]     scan: core is ABSENT -- no engine table to inventory")
    end
    out(string_format(
        "[LiveProbe] 0.4 summary: %d surface(s) present, %d absent, %d read(s) our lanes make missing, %d name-scan hit(s)",
        present, absent, absent_reads, hits))
    return {
        lines = kit.lines(), present = present, absent = absent,
        absent_reads = absent_reads, scan_hits = hits,
    }
end
return M
