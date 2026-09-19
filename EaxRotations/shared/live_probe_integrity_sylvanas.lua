-- live_probe_integrity_sylvanas.lua — Block 0.5 integrity / error surfaces.
-- WHAT:  integrity_report() prints the client's own surface state (the log
--        sinks, the engine tables our code depends on, the runtime generations,
--        our API-health stub, a live-read canary); note_arm() and
--        emit_flush_comparison() are the capture hooks that diff that state
--        arm -> flush.
-- WHEN:  note_arm/emit_flush_comparison run inside arm()/flush() through the
--        facade wiring; integrity_report() runs from the Diagnostics 0.5 entry.
-- WHY:   0.5 asks whether anything in the client reacts to the engine running;
--        a diff of the client's own surfaces is the evidence a session can paste.
-- SAFETY: these reads WRITE nothing to the engine (no log lines, no state), and a
--        surface that vanished mid-capture is named with both values, never
--        swallowed.
local NS = _G.EaxRotations
if not NS then return nil end
local type = type
local pcall = pcall
local ipairs = ipairs
local tostring = tostring
local string_format = string.format
local table_sort = table.sort
local table_concat = table.concat
local kit = require("shared/live_probe_kit_sylvanas")
local out, lookup = kit.out, kit.lookup
local M = {}
local _integrity_at_arm = nil   -- 0.5: engine surface state when armed


-- ---------------------------------------------------------------------------
-- Engine integrity / error surfaces (Block 0.5)
--
-- 0.5 asks whether anything in the client reacts to the engine running (the
-- memory-reads/no-addon-API posture), and the only honest evidence a plugin can
-- gather without a console is the client's own surface state, read at both ends
-- of a capture:
--   * the surface snapshot -- every engine/framework surface this tree depends
--     on (the log sinks, spell_book, object_manager, input, menu, time, game_ui,
--     damage_meter), the runtime generations, and our API-health stub, each by
--     value or type, resolved at RUNTIME by name. A capture diffs arm -> flush:
--     a surface that vanished or changed type, or a bumped generation, IS the
--     integrity reaction this block is looking for.
--   * a liveness canary -- one real engine read (core.time, callable or as a
--     table with get/now) called at both ends, so "the API still answers" is
--     observed rather than assumed.
-- These reads WRITE nothing to the engine: no log lines, no state changes.
-- ---------------------------------------------------------------------------
local INTEGRITY_DIFF_LIMIT = 16     -- changed surfaces listed per comparison
local INTEGRITY_SURFACES = {
    { root = "core", name = "runtime_generation", label = "core.runtime_generation", mode = "value" },
    { root = "ns", name = "runtime_generation", label = "NS.runtime_generation", mode = "value" },
    { root = "ns", name = "is_api_health_broken", label = "NS.is_api_health_broken()", mode = "call" },
    { root = "ns", name = "reset_api_health", label = "NS.reset_api_health", mode = "type" },
    { root = "core", name = "log", label = "core.log", mode = "type" },
    { root = "core", name = "log_warning", label = "core.log_warning", mode = "type" },
    { root = "core", name = "log_error", label = "core.log_error", mode = "type" },
    { root = "core", name = "spell_book", label = "core.spell_book", mode = "type" },
    { root = "core", name = "object_manager", label = "core.object_manager", mode = "type" },
    { root = "core", name = "input", label = "core.input", mode = "type" },
    { root = "core", name = "menu", label = "core.menu", mode = "type" },
    { root = "core", name = "time", label = "core.time", mode = "type" },
    { root = "core", name = "game_ui", label = "core.game_ui", mode = "type" },
    { root = "core", name = "damage_meter", label = "core.damage_meter", mode = "type" },
}

local function integrity_value(entry)
    local value = lookup(entry.root, entry.name)
    if entry.mode == "call" then
        if type(value) ~= "function" then return "ABSENT" end
        local ok, result = pcall(value)
        if ok then return "callable -> " .. tostring(result) end
        return "callable -> ERROR " .. tostring(result)
    end
    if value == nil then return "ABSENT" end
    if entry.mode == "type" then return type(value) end
    return type(value) .. " " .. tostring(value)
end

-- One real engine read, called at both ends of the capture.
local function integrity_canary()
    local time_surface = lookup("core", "time")
    local fn = nil
    if type(time_surface) == "function" then
        fn = time_surface
    elseif type(time_surface) == "table" then
        for _, key in ipairs({ "get", "now" }) do
            if type(time_surface[key]) == "function" then
                fn = time_surface[key]
                break
            end
        end
    end
    if type(fn) ~= "function" then return "not callable" end
    local ok, result = pcall(fn)
    if not ok then return "ERROR " .. tostring(result) end
    return "ok (" .. type(result) .. ")"
end

local function integrity_snapshot()
    local snapshot = {}
    local labels = {}
    for i = 1, #INTEGRITY_SURFACES do
        local entry = INTEGRITY_SURFACES[i]
        snapshot[entry.label] = integrity_value(entry)
        labels[#labels + 1] = entry.label
    end
    snapshot["core.time live read"] = integrity_canary()
    labels[#labels + 1] = "core.time live read"
    table_sort(labels, function(a, b) return a < b end)
    local parts = {}
    for i = 1, #labels do
        parts[#parts + 1] = labels[i] .. "=" .. snapshot[labels[i]]
    end
    return snapshot, table_concat(parts, " | "), labels
end

-- The arm -> flush diff: a capture carries its own integrity evidence.
local function integrity_lines(before, after, labels)
    if not before then
        out("[LiveProbe] 0.5 integrity: nothing was armed, so there is no arm -> flush comparison")
        return 0
    end
    local changed = 0
    for i = 1, #labels do
        local label = labels[i]
        if before[label] ~= after[label] then
            changed = changed + 1
            if changed <= INTEGRITY_DIFF_LIMIT then
                out(string_format("[LiveProbe] 0.5 integrity CHANGED %s: %s -> %s",
                    label, tostring(before[label]), tostring(after[label])))
            end
        end
    end
    if changed == 0 then
        out(string_format(
            "[LiveProbe] 0.5 integrity: UNCHANGED across the capture (%d surface(s), arm signature matches) -- no integrity/error reaction",
            #labels))
    else
        out(string_format(
            "[LiveProbe] 0.5 integrity: %d surface(s) CHANGED -- the client reacted or an engine surface went away; re-run before trusting this capture",
            changed))
    end
    return changed
end

function M.integrity_report()
    kit.reset_lines()
    out("[LiveProbe] 0.5 engine integrity -- surface state (nothing is written to the engine)")
    local snapshot, signature, labels = integrity_snapshot()
    for i = 1, #labels do
        out(string_format("[LiveProbe]   %s = %s", labels[i], snapshot[labels[i]]))
    end
    out(string_format("[LiveProbe] 0.5 state: %d surface(s) reported (signature length %d)",
        #labels, #signature))
    if _integrity_at_arm then
        out("[LiveProbe] 0.5 comparison (arm -> now):")
        integrity_lines(_integrity_at_arm, snapshot, labels)
    else
        out("[LiveProbe] 0.5 comparison: nothing armed yet -- arm a capture (any scope), run normally, then Flush to read the arm -> flush line")
    end
    return { lines = kit.lines(), labels = labels, signature = signature, snapshot = snapshot }
end

-- Capture hooks: the ring owns the moments, this probe owns the meaning.
function M.note_arm()
    _integrity_at_arm = integrity_snapshot()
end

function M.emit_flush_comparison()
    local snapshot, _signature, labels = integrity_snapshot()
    integrity_lines(_integrity_at_arm, snapshot, labels)
end
return M
