-- aura_probe_sylvanas.lua -- runtime aura probe used by tests + validators to confirm Sylvanas aura IDs.
-- WHAT:   runtime aura probe used by tests + validators to confirm Sylvanas aura IDs.
-- WHEN:   called when tests need to assert aura data; not used in production
-- WHY:    single source for aura validation across all specs
-- SAFETY: PCalled around api; nil-guarded unit
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.


-- Runtime aura probe for validating Sylvanas aura IDs against TBC data.

local _G = _G
local core = _G.core
local NS = _G.EaxRotations

local M = {}

local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then
    TBC = { SPELLS = {}, BUFFS = {} }
end

local _buff_ok, buff_manager = pcall(require, "common/modules/buff_manager")
if not _buff_ok then buff_manager = nil end

local last_report = nil

local function log(message)
    if NS and NS.log then
        NS.log(message)
    elseif core and core.log then
        core.log(message)
    end
end

local function safe_call(fn, ...)
    if type(fn) ~= "function" then return false, nil end
    return pcall(fn, ...)
end

local function get_player()
    if NS and NS.GetPlayer then
        local ok, player = safe_call(NS.GetPlayer)
        if ok and player then return player end
    end
    if core and core.object_manager and core.object_manager.get_local_player then
        local ok, player = safe_call(core.object_manager.get_local_player)
        if ok then return player end
    end
    return nil
end

local function aura_id(row)
    if type(row) ~= "table" then return nil end
    return row.buff_id or row.spell_id or row.aura_id or row.id
end

local function aura_name(row)
    if type(row) ~= "table" then return "" end
    return row.buff_name or row.name or row.aura_name or ""
end

local function aura_stacks(row)
    if type(row) ~= "table" then return 0 end
    return row.stacks or row.count or row.stack_count or 0
end

local function aura_remaining(row)
    if type(row) ~= "table" then return 0 end
    return row.remaining or row.remains or row.duration or 0
end

local function collect_rows_from_method(player, method_name, label, out, seen)
    local method = player and player[method_name]
    if type(method) ~= "function" then return 0 end
    local ok, rows = safe_call(method, player)
    if not ok or type(rows) ~= "table" then return 0 end

    local count = 0
    for _, row in pairs(rows) do
        local id = aura_id(row)
        if id and not seen[label .. ":" .. tostring(id)] then
            seen[label .. ":" .. tostring(id)] = true
            out[#out + 1] = {
                source = label,
                id = id,
                name = aura_name(row),
                stacks = aura_stacks(row),
                remaining = aura_remaining(row),
            }
            count = count + 1
        end
    end
    return count
end

local function collect_rows_from_buff_manager(player, method_name, label, out, seen)
    local method = buff_manager and buff_manager[method_name]
    if type(method) ~= "function" then return 0 end
    local ok, rows = safe_call(method, buff_manager, player, 50)
    if not ok or type(rows) ~= "table" then return 0 end

    local count = 0
    for _, row in pairs(rows) do
        local id = aura_id(row)
        if id and not seen[label .. ":" .. tostring(id)] then
            seen[label .. ":" .. tostring(id)] = true
            out[#out + 1] = {
                source = label,
                id = id,
                name = aura_name(row),
                stacks = aura_stacks(row),
                remaining = aura_remaining(row),
            }
            count = count + 1
        end
    end
    return count
end

function M.collect_player_auras(player)
    local rows = {}
    local seen = {}
    player = player or get_player()
    if not player then return rows end

    collect_rows_from_method(player, "get_buffs", "unit:get_buffs", rows, seen)
    collect_rows_from_method(player, "get_auras", "unit:get_auras", rows, seen)
    collect_rows_from_method(player, "get_debuffs", "unit:get_debuffs", rows, seen)

    collect_rows_from_buff_manager(player, "get_buff_cache", "buff_manager:get_buff_cache", rows, seen)
    collect_rows_from_buff_manager(player, "get_aura_cache", "buff_manager:get_aura_cache", rows, seen)
    collect_rows_from_buff_manager(player, "get_debuff_cache", "buff_manager:get_debuff_cache", rows, seen)

    table.sort(rows, function(a, b)
        if a.source == b.source then return tostring(a.id) < tostring(b.id) end
        return a.source < b.source
    end)
    return rows
end

local function flatten_group(prefix, value, out)
    if type(value) ~= "table" then return end
    local is_array = true
    for k in pairs(value) do
        if type(k) ~= "number" then
            is_array = false
            break
        end
    end

    if is_array then
        out[#out + 1] = { name = prefix, ids = value }
        return
    end

    for k, v in pairs(value) do
        local child = prefix ~= "" and (prefix .. "." .. tostring(k)) or tostring(k)
        flatten_group(child, v, out)
    end
end

local function id_in_rows(rows, ids)
    local row_ids = {}
    for i = 1, #rows do
        row_ids[tonumber(rows[i].id)] = true
    end
    for i = 1, #ids do
        if row_ids[tonumber(ids[i])] then return true end
    end
    return false
end

local function query_player(player, method_name, ids)
    local method = player and player[method_name]
    if type(method) ~= "function" then return nil end
    local ok, result = safe_call(method, player, ids)
    if ok then return result == true end
    return nil
end

local function query_manager(player, method_name, ids)
    local method = buff_manager and buff_manager[method_name]
    if type(method) ~= "function" then return nil end
    local ok, result = safe_call(method, buff_manager, player, ids, 50)
    if ok and type(result) == "table" then return result.is_active == true end
    return nil
end

function M.compare_player_auras(player)
    player = player or get_player()
    local rows = M.collect_player_auras(player)
    local groups = {}

    flatten_group("spells", TBC.SPELLS or {}, groups)
    flatten_group("buffs", TBC.BUFFS or {}, groups)

    local checks = {}
    for i = 1, #groups do
        local group = groups[i]
        local ids = group.ids
        local raw = id_in_rows(rows, ids)
        local unit_buff = query_player(player, "has_buff", ids)
        local unit_aura = query_player(player, "has_aura", ids)
        local bm_buff = query_manager(player, "get_buff_data", ids)
        local bm_aura = query_manager(player, "get_aura_data", ids)

        if raw or unit_buff or unit_aura or bm_buff or bm_aura then
            checks[#checks + 1] = {
                name = group.name,
                raw = raw,
                unit_buff = unit_buff,
                unit_aura = unit_aura,
                bm_buff = bm_buff,
                bm_aura = bm_aura,
            }
        end
    end

    return rows, checks
end

local function fmt_bool(value)
    if value == nil then return "n/a" end
    return value and "yes" or "no"
end

function M.dump_player_auras()
    local player = get_player()
    if not player then
        log("[AuraProbe] no local player")
        return false
    end

    local rows, checks = M.compare_player_auras(player)
    log("[AuraProbe] player aura rows: " .. tostring(#rows))
    for i = 1, #rows do
        local row = rows[i]
        log(string.format(
            "[AuraProbe] %s id=%s name=%s stacks=%s remaining=%s",
            tostring(row.source),
            tostring(row.id),
            tostring(row.name),
            tostring(row.stacks),
            tostring(row.remaining)
        ))
    end

    log("[AuraProbe] matched TBC groups: " .. tostring(#checks))
    for i = 1, #checks do
        local c = checks[i]
        log(string.format(
            "[AuraProbe] match %s raw=%s unit_buff=%s unit_aura=%s bm_buff=%s bm_aura=%s",
            c.name,
            fmt_bool(c.raw),
            fmt_bool(c.unit_buff),
            fmt_bool(c.unit_aura),
            fmt_bool(c.bm_buff),
            fmt_bool(c.bm_aura)
        ))
    end

    last_report = { rows = rows, checks = checks }
    return true
end

function M.get_last_report()
    return last_report
end

if NS then
    NS.AuraProbe = M
    NS.get_aura_probe_report = M.get_last_report
end

return M
