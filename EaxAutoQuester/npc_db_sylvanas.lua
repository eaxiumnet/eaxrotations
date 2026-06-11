-- What: NPC spawn position database from creature_spawn_index.json
-- When: Lazy-loaded by quest_state when Zygor goal has npc_id
-- Why: Look up exact NPC spawn coordinates instead of brute-force scanning
-- Safety: Read-only JSON cache; nil-return on missing data; no I/O after load

local M = {}

local _spawn_data = nil

-- Lazy-load spawn index JSON from scripts_data/tbc_db/
local function ensure_data()
    if _spawn_data then return true end
    if not core.read_data_file then return false end

    local ok, raw = pcall(core.read_data_file, "tbc_db/creature_spawn_index.json")
    if not ok or not raw or raw == "" then return false end

    local ok2, parsed = pcall(function() 
        local obj = nil
        local f = load("return " .. raw)
        if f then obj = f() end
        return obj
    end)
    if not ok2 or not parsed then return false end
    if not parsed.by_entry then return false end

    _spawn_data = parsed.by_entry
    core.log("[EaxAutoQuester] NPC DB loaded (" .. tostring(#_spawn_data or "?") .. " entries)")
    return true
end

--- Find the closest spawn position for an NPC ID to the player's current map.
--- @param npc_id integer The NPC ID (entry) to look up
--- @param player_map_id integer|nil Current map ID for filtering
--- @return table|nil { x, y, z, map_id, name, distance } or nil
function M.find_npc_spawn(npc_id, player_map_id)
    if not ensure_data() then return nil end

    local entry = _spawn_data[tostring(npc_id)]
    if not entry or not entry.maps or #entry.maps == 0 then return nil end

    local maps = entry.maps
    local name = entry.name or "Unknown"

    -- Prefer same-map spawns, otherwise take first available
    local best = nil
    for i = 1, #maps do
        local m = maps[i]
        if m and m.x and m.y then
            if player_map_id and m.map_id == player_map_id then
                return {
                    npc_id = npc_id,
                    name = name,
                    map_id = m.map_id,
                    x = m.x,
                    y = m.y,
                    z = m.z or 0,
                }
            end
            if not best then best = m end
        end
    end

    if best then
        return {
            npc_id = npc_id,
            name = name,
            map_id = best.map_id,
            x = best.x,
            y = best.y,
            z = best.z or 0,
        }
    end
    return nil
end

--- Search for NPCs by name substring.
--- @param search string Name to search for
--- @return table[] Array of { npc_id, name, map_id, x, y, z }
function M.search_npc_by_name(search)
    if not ensure_data() or not search then return {} end
    local results = {}
    local search_lower = search:lower()

    for id_str, entry in pairs(_spawn_data) do
        if entry.name and entry.name:lower():find(search_lower, 1, true) then
            local id = tonumber(id_str)
            if id and entry.maps and #entry.maps > 0 then
                local m = entry.maps[1]
                results[#results + 1] = {
                    npc_id = id,
                    name = entry.name,
                    map_id = m.map_id,
                    x = m.x,
                    y = m.y,
                    z = m.z or 0,
                }
            end
        end
    end
    return results
end

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.npc_db = M
return M
