-- What: NPC spawn position database from creature_spawn_index.json
-- When: Lazy-loaded by quest_state when Zygor goal has npc_id
-- Why: Look up exact NPC spawn coordinates instead of brute-force scanning
-- Safety: Read-only JSON cache; nil-return on missing data; no I/O after load

local M = {}

local _spawn_data = nil

-- Lazy-load spawn index JSON from scripts_data/tbc_db/ via json_loader
local function ensure_data()
    if _spawn_data then return true end
    local ok, loader = pcall(require, "json_loader")
    if not ok or not loader or not loader.load_data_file then return false end

<<<<<<< Updated upstream
    local ok, raw = pcall(core.read_data_file, "tbc_db/creature_spawn_index.json")
    if not ok or not raw or raw == "" then return false end

    local ok2, parsed = pcall(function()
        -- Convert JSON to valid Lua table syntax (keys need brackets, arrays need braces)
        local lua = raw:gsub('%[', '{'):gsub('%]', '}')
        lua = lua:gsub('("[^"]-")%s*:%s*', '[%1] = ')
        local chunk = loadstring or load
        local f = chunk("return " .. lua)
        if f then return f() end
        return nil
    end)
    if not ok2 or not parsed then return false end
    if not parsed.by_entry then return false end
=======
    local parsed = loader.load_data_file("tbc_db/creature_spawn_index.json")
    if not parsed or type(parsed) ~= "table" then return false end
    if not parsed.by_entry or type(parsed.by_entry) ~= "table" then return false end
>>>>>>> Stashed changes

    _spawn_data = parsed.by_entry
    local count = 0
    for _ in pairs(_spawn_data) do count = count + 1 end
    core.log("[EaxAutoQuester] NPC DB loaded (" .. tostring(count) .. " entries)")
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

-- ============================================================================
-- find_transport_npc: Find nearest vendor / repair / flight / inn NPC
-- ============================================================================

local TRANSPORT_KEYWORDS = {
    vendor  = { "vendor", "merchant", "trader", "supplier", "general goods" },
    repair  = { "blacksmith", "armorer", "weaponsmith", "repair" },
    flight  = { "flight master", "wind rider", "hippogryph", "gryphon", "bat handler", "hippogryph master", "wind rider master" },
    inn     = { "innkeeper", "barkeep", "bartender" },
}

--- Find the nearest NPC of a given transport type on the current map.
--- @param type_hint string One of: "vendor", "repair", "flight", "inn"
--- @param player_map_id integer|nil Current map ID for filtering
--- @return table|nil { x, y, z, map_id, name, npc_id } or nil
function M.find_transport_npc(type_hint, player_map_id)
    if not ensure_data() or not type_hint then return nil end

    local keywords = TRANSPORT_KEYWORDS[type_hint:lower()]
    if not keywords then return nil end

    local best = nil
    local best_dist_sq = math.huge

    for id_str, entry in pairs(_spawn_data) do
        if entry.name then
            local name_lower = entry.name:lower()
            local matched = false
            for _, kw in ipairs(keywords) do
                if name_lower:find(kw, 1, true) then
                    matched = true
                    break
                end
            end
            if matched and entry.maps and #entry.maps > 0 then
                for i = 1, #entry.maps do
                    local m = entry.maps[i]
                    if m and m.x and m.y then
                        local on_map = (not player_map_id) or (m.map_id == player_map_id)
                        -- Prefer same-map; if none found, allow cross-map fallback
                        if on_map or not best then
                            local dist_sq = 0
                            if player_map_id and m.map_id == player_map_id then
                                -- Same-map: compute rough distance if we had player pos;
                                -- we don't here, so just prefer same-map and first match
                                dist_sq = 0
                            else
                                dist_sq = math.huge
                            end
                            if not best or dist_sq < best_dist_sq then
                                best = {
                                    npc_id = tonumber(id_str),
                                    name = entry.name,
                                    map_id = m.map_id,
                                    x = m.x,
                                    y = m.y,
                                    z = m.z or 0,
                                }
                                best_dist_sq = dist_sq
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.npc_db = M
return M
