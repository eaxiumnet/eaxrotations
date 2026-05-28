-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/telemetry_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- stores compact telemetry for recent encounters.

local _G = _G
local core = _G.core or {}
local NS = _G.EaxRotations
if not NS then return nil end

local combat_log_parser = require("shared/combat_log_parser_sylvanas")

local M = {}

local MAX_ENTRIES = 100
local EMPTY = {}

local history = {}
local history_count = 0
local history_write_index = 1

local active_spell_counts = {}
local combat_started_at = 0
local telemetry_enabled = false

local function now_seconds()
    if type(NS.time_now) == "function" then
        local ok, value = pcall(NS.time_now)
        if ok and type(value) == "number" then
            return value
        end
    end

    if type(core.time) == "function" then
        local ok, value = pcall(core.time)
        if ok and type(value) == "number" then
            return value
        end
    end

    return os.clock()
end

local function get_telemetry_enabled(context)
    local settings = nil
    if type(context) == "table" then
        settings = context.settings or context
        if settings.telemetry_enabled ~= nil then
            return settings.telemetry_enabled == true
        end
    end

    if type(NS.get_setting) == "function" then
        local ok, value = pcall(NS.get_setting, "telemetry_enabled", false)
        if ok then
            return value == true
        end
    end

    return false
end

local function refresh_enabled(context)
    telemetry_enabled = get_telemetry_enabled(context)
    return telemetry_enabled
end

local function copy_spell_counts(source)
    local counts = {}
    if type(source) ~= "table" then
        return counts
    end

    for spell_id, count in pairs(source) do
        local n = tonumber(count)
        if n and n > 0 then
            counts[spell_id] = n
        end
    end

    return counts
end

local function push_entry(entry)
    history[history_write_index] = entry
    history_write_index = history_write_index + 1
    if history_write_index > MAX_ENTRIES then
        history_write_index = 1
    end

    if history_count < MAX_ENTRIES then
        history_count = history_count + 1
    end
end

local function iter_history()
    local index = 0
    local start_index = history_count < MAX_ENTRIES and 1 or history_write_index

    return function()
        if index >= history_count then
            return nil
        end

        index = index + 1
        local slot = start_index + index - 1
        if slot > MAX_ENTRIES then
            slot = slot - MAX_ENTRIES
        end

        return history[slot]
    end
end

local function resolve_player_dps(duration_seconds)
    if not combat_log_parser or type(combat_log_parser.get_dps_hps_per_unit) ~= "function" then
        return 0
    end

    local player = NS.GetPlayer and NS.GetPlayer() or nil
    if not player or type(player.get_guid) ~= "function" then
        return 0
    end

    local ok_guid, guid = pcall(function()
        return player:get_guid()
    end)
    if not ok_guid or guid == nil then
        return 0
    end

    local by_unit = combat_log_parser.get_dps_hps_per_unit(duration_seconds or 0) or EMPTY
    local bucket = by_unit[guid] or by_unit[tostring(guid)] or by_unit[string.lower(tostring(guid))]
    if bucket and type(bucket.dps) == "number" then
        return bucket.dps
    end

    return 0
end

local function increment_spell_count(spell_id)
    local key = tonumber(spell_id)
    if not key then
        return
    end

    active_spell_counts[key] = (active_spell_counts[key] or 0) + 1
end

local function build_record(playstyle_name, duration_seconds, avg_dps, spell_counts_table)
    return {
        timestamp = now_seconds(),
        playstyle = tostring(playstyle_name or (NS.current_playstyle or "unknown")),
        duration = tonumber(duration_seconds) or 0,
        dps = tonumber(avg_dps) or 0,
        spell_counts = copy_spell_counts(spell_counts_table),
    }
end

local function format_spell_name(spell_id)
    if type(core.spell_book and core.spell_book.get_spell_name) ~= "function" then
        return tostring(spell_id)
    end

    local ok, name = pcall(core.spell_book.get_spell_name, spell_id)
    if ok and name then
        return tostring(name)
    end

    return tostring(spell_id)
end

function M.record_encounter(data, duration_seconds, avg_dps, spell_counts_table)
    local payload = data
    if type(data) ~= "table" then
        payload = {
            playstyle_name = data,
            duration_seconds = duration_seconds,
            avg_dps = avg_dps,
            spell_counts_table = spell_counts_table,
        }
    end

    local entry = build_record(
        payload.playstyle_name or payload.playstyle,
        payload.duration_seconds or payload.duration,
        payload.avg_dps or payload.dps,
        payload.spell_counts_table or payload.spell_counts
    )

    push_entry(entry)
    return entry
end

function M.get_average_dps()
    if history_count <= 0 then
        return 0
    end

    local total = 0
    for entry in iter_history() do
        total = total + (entry.dps or 0)
    end

    return total / history_count
end

function M.get_spell_usage_stats()
    local stats = {}
    for entry in iter_history() do
        local counts = entry.spell_counts or EMPTY
        for spell_id, count in pairs(counts) do
            stats[spell_id] = (stats[spell_id] or 0) + (tonumber(count) or 0)
        end
    end

    return stats
end

function M.export_summary()
    local lines = {}
    lines[#lines + 1] = "EaxRotations Telemetry"
    lines[#lines + 1] = string.format("Encounters: %d", history_count)
    lines[#lines + 1] = string.format("Average DPS: %.1f", M.get_average_dps())

    local stats = M.get_spell_usage_stats()
    local items = {}
    for spell_id, count in pairs(stats) do
        items[#items + 1] = { spell_id = spell_id, count = count }
    end

    table.sort(items, function(a, b)
        if a.count == b.count then
            return tostring(a.spell_id) < tostring(b.spell_id)
        end
        return a.count > b.count
    end)

    lines[#lines + 1] = "Spell usage:"
    for i = 1, #items do
        local item = items[i]
        lines[#lines + 1] = string.format("- %s: %d", format_spell_name(item.spell_id), item.count)
    end

    return table.concat(lines, "\n")
end

function M.reset_telemetry()
    for i = 1, MAX_ENTRIES do
        history[i] = nil
    end
    history_count = 0
    history_write_index = 1
    active_spell_counts = {}
    combat_started_at = 0
end

function M.render_telemetry_line(x, y)
    if not refresh_enabled() then
        return false
    end

    if not (core.graphics and type(core.graphics.draw_text) == "function") then
        return false
    end

    local text = string.format("Avg DPS: %.1f over %d encounters", M.get_average_dps(), history_count)
    pcall(core.graphics.draw_text, text, x, y)
    return true
end

local function on_combat_start(context)
    if not refresh_enabled(context) then
        return
    end

    active_spell_counts = {}
    combat_started_at = now_seconds()
end

local function on_spell_cast(spell_id)
    if not refresh_enabled() then
        return
    end

    increment_spell_count(spell_id)
end

local function on_combat_end(context)
    if not refresh_enabled(context) then
        return
    end

    local playstyle_name = nil
    local duration_seconds = nil
    local avg_dps = nil
    local spell_counts_table = nil

    if type(context) == "table" then
        playstyle_name = context.playstyle_name or context.active_playstyle or context.playstyle
        duration_seconds = context.duration_seconds or context.duration or context.combat_duration
        avg_dps = context.avg_dps or context.dps
        spell_counts_table = context.spell_counts or context.spell_counts_table
    end

    if not duration_seconds or duration_seconds <= 0 then
        local started_at = combat_started_at > 0 and combat_started_at or now_seconds()
        duration_seconds = math.max(0, now_seconds() - started_at)
    end

    if not avg_dps or avg_dps <= 0 then
        avg_dps = resolve_player_dps(duration_seconds)
    end

    if type(spell_counts_table) ~= "table" then
        spell_counts_table = active_spell_counts
    end

    M.record_encounter(playstyle_name, duration_seconds, avg_dps, spell_counts_table)
    active_spell_counts = {}
    combat_started_at = 0
end

if NS.register_on_spell_cast then
    NS.register_on_spell_cast(function(spell_id)
        on_spell_cast(spell_id)
    end)
end

if NS.register_on_combat_start then
    NS.register_on_combat_start(on_combat_start)
end

if NS.register_on_combat_end then
    NS.register_on_combat_end(on_combat_end)
end

telemetry_enabled = get_telemetry_enabled()

NS.TelemetrySylvanas = M

return M
