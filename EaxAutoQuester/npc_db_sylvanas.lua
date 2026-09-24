-- What: NPC spawn position database from creature_spawn_index.json
-- When: Lazy-loaded by quest_state when Zygor goal has npc_id
-- Why: Look up exact NPC spawn coordinates instead of brute-force scanning
-- Safety: Read-only JSON cache; nil-return on missing data; no I/O after load

local M = {}

local _spawn_data = nil
local _get_local_player = core and core.object_manager and core.object_manager.get_local_player
local _get_map_id = core and core.get_map_id

-- Lazy-load spawn index JSON from scripts_data/tbc_db/ via json_loader
local function ensure_data()
    if _spawn_data then return true end
    local ok, loader = pcall(require, "json_loader")
    if not ok or not loader or not loader.load_data_file then return false end

    local parsed = loader.load_data_file("tbc_db/creature_spawn_index.json")
    if not parsed or type(parsed) ~= "table" then return false end
    if not parsed.by_entry or type(parsed.by_entry) ~= "table" then return false end

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

local function normalize_position(pos)
    if type(pos) ~= "table" then return nil end
    local x = tonumber(pos.x)
    local y = tonumber(pos.y)
    if x == nil or y == nil then return nil end
    return { x = x, y = y, z = tonumber(pos.z) or 0 }
end

local function resolve_map_id(player_map_id)
    if player_map_id ~= nil then return tonumber(player_map_id) end
    if _get_map_id then
        local ok, current_map = pcall(_get_map_id)
        if ok then return tonumber(current_map) end
    end
    return nil
end

local function resolve_player_position(player_pos)
    local position = normalize_position(player_pos)
    if position then return position end
    if _get_local_player then
        local ok, player = pcall(_get_local_player)
        if ok and player then
            local pos_ok, current_pos = pcall(player.get_position, player)
            if pos_ok then return normalize_position(current_pos) end
        end
    end
    return nil
end

--- Find the nearest NPC of a given transport type on the player's current map.
--- Another-map spawns are unreachable and are never used as a fallback. If a position is
--- unavailable, the first valid local spawn is retained for compatibility with older callers.
--- @param type_hint string One of: "vendor", "repair", "flight", "inn"
--- @param player_map_id integer|nil Current map ID; resolved from core when omitted
--- @param player_pos table|nil Optional player position used for nearest selection
--- @return table|nil { x, y, z, map_id, name, npc_id } or nil
function M.find_transport_npc(type_hint, player_map_id, player_pos)
    if not ensure_data() or not type_hint then return nil end

    local keywords = TRANSPORT_KEYWORDS[type_hint:lower()]
    if not keywords then return nil end

    local map_id = resolve_map_id(player_map_id)
    if map_id == nil then return nil end
    local origin = resolve_player_position(player_pos)
    local best = nil
    local best_dist_sq = origin and math.huge or nil

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
                    local x = tonumber(m and m.x)
                    local y = tonumber(m and m.y)
                    if tonumber(m and m.map_id) == map_id and x and y then
                        local z = tonumber(m.z) or 0
                        local dist_sq = nil
                        if origin then
                            local dx = x - origin.x
                            local dy = y - origin.y
                            local dz = z - origin.z
                            dist_sq = dx * dx + dy * dy + dz * dz
                        end
                        if not best or (origin and dist_sq < best_dist_sq) then
                            best = {
                                npc_id = tonumber(id_str),
                                name = entry.name,
                                map_id = map_id,
                                x = x,
                                y = y,
                                z = z,
                            }
                            best_dist_sq = dist_sq
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
