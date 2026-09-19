-- live_probe_truth_sylvanas.lua — Block 0.1-0.3 engine-truth report.
-- WHAT:  report(): every version/expansion surface this build exposes, the
--        capability matrix (SURFACES), the local race, and each aura's points[1]
--        (the Pattern-11 absorb read, via aura_rows/report_aura_points).
-- WHEN:  run from the Diagnostics "Probe: Engine Report" entry; inert at load.
-- WHY:   the Block-0 engine reads a session must paste are one call, so a
--        verdict costs a click rather than a notebook.
-- SAFETY: reads are pcall-guarded; an absent surface prints ABSENT instead of a
--        fabricated value, and no spell id is hardcoded here.
local NS = _G.EaxRotations
if not NS then return nil end
local type = type
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local kit = require("shared/live_probe_kit_sylvanas")
local out, lookup, safe, player = kit.out, kit.lookup, kit.safe, kit.player
local M = {}
local SURFACES = {
    { "NS.buff_points", "ns", "buff_points" },
    { "NS.debuff_points", "ns", "debuff_points" },
    { "NS.has_player_buff", "ns", "has_player_buff" },
    { "NS.spell_ready", "ns", "spell_ready" },
    { "NS.cooldown_remains", "ns", "cooldown_remains" },
    { "NS.unit_mana_pct", "ns", "unit_mana_pct" },
    { "NS.GetPlayer", "ns", "GetPlayer" },
    { "core.register_on_game_event_callback", "core", "register_on_game_event_callback" },
    { "NS.register_on_game_event", "ns", "register_on_game_event" },
    { "player:get_buffs", "player", "get_buffs" },
    { "player:get_auras", "player", "get_auras" },
    { "player:get_debuffs", "player", "get_debuffs" },
    { "player:get_power", "player", "get_power" },
    { "player:get_form", "player", "get_form" },
    { "player:get_shapeshift_form", "player", "get_shapeshift_form" },
    { "player:get_attack_power", "player", "get_attack_power" },
    { "player:get_haste", "player", "get_haste" },
    { "player:is_mounted", "player", "is_mounted" },
    { "player:get_race", "player", "get_race" },
}

local EXPANSION_SURFACES = {
    { "NS.expansion_key", "ns", "expansion_key" },
    { "NS.get_expansion_key", "ns", "get_expansion_key" },
    { "NS.expansion", "ns", "expansion" },
    { "core.get_game_version", "core", "get_game_version" },
    { "core.game_version", "core", "game_version" },
    { "core.expansion_key", "core", "expansion_key" },
}


-- ---------------------------------------------------------------------------
-- Aura points (Block 0.3): points[1] is the Pattern-11 variable value -- for an
-- absorb that is the remaining shield. Rows come from the aura surface; ids from
-- the row, values from NS.buff_points, so nothing is hardcoded.
-- ---------------------------------------------------------------------------
local function aura_rows(p)
    if not p then return nil end
    local probe = NS.AuraProbe
    if probe and type(probe.collect_player_auras) == "function" then
        local rows = safe(probe.collect_player_auras, p)
        if type(rows) == "table" then return rows end
    end
    return nil
end

local function report_aura_points(p)
    local points_fn = NS.buff_points
    if type(points_fn) ~= "function" then
        out("[LiveProbe] points: NS.buff_points ABSENT -- Pattern-11 reads unavailable on this build")
        return 0
    end
    local rows = aura_rows(p)
    if not rows then
        out("[LiveProbe] points: no aura surface (get_buffs/get_auras/debuffs absent)")
        return 0
    end
    local shown = 0
    for i = 1, #rows do
        local row = rows[i]
        local id = row and tonumber(row.id)
        if id then
            local pts = safe(points_fn, p, { id })
            local first = type(pts) == "table" and tonumber(pts[1]) or nil
            if first then
                shown = shown + 1
                out(string_format("[LiveProbe] points id=%s name=%s points[1]=%s (%s)",
                    tostring(id), tostring(row.name or "?"), tostring(first),
                    tostring(row.source or "aura")))
            end
        end
    end
    out(string_format("[LiveProbe] points: %d aura row(s) exposed a points value", shown))
    return shown
end

-- ---------------------------------------------------------------------------
-- M.report(): Block 0 truth dump
-- ---------------------------------------------------------------------------
function M.report()
    kit.reset_lines()
    out("[LiveProbe] === engine-truth report ===")

    for i = 1, #EXPANSION_SURFACES do
        local entry = EXPANSION_SURFACES[i]
        local value = lookup(entry[2], entry[3])
        local shown = value == nil and "absent" or tostring(value)
        if type(value) == "function" then shown = "present (callable)" end
        out(string_format("[LiveProbe] version %s = %s", entry[1], shown))
    end

    local p = player()
    out(string_format("[LiveProbe] player = %s", p and "resolved" or "NIL (no local player)"))

    local matrix = {}
    local present = 0
    for i = 1, #SURFACES do
        local entry = SURFACES[i]
        local value = lookup(entry[2], entry[3])
        local state = value == nil and "ABSENT" or "present"
        if value ~= nil then present = present + 1 end
        matrix[#matrix + 1] = { name = entry[1], state = state }
        out(string_format("[LiveProbe] surface %-42s %s", entry[1], state))
    end
    out(string_format("[LiveProbe] capability matrix: %d/%d surfaces present",
        present, #SURFACES))

    if p then
        local race = safe(p.get_race, p)
        if race == nil then race = p.race end
        out(string_format("[LiveProbe] race = %s", tostring(race or "unreadable")))
        report_aura_points(p)
    end

    local report = { lines = kit.lines(), matrix = matrix, player = p ~= nil, present = present }
    M._last_report = report
    out("[LiveProbe] === end report ===")
    return report
end

function M.last_report()
    return M._last_report
end
return M
