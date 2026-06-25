-- NPC Spawn Database Index - cMaNGOS tbc-db
-- Auto-generated from TBCDB_1.10.0_ReturnOfTheVengeance.sql
-- 12265 unique NPCs across 7 chunks
local M = {}
local _loaded_chunks = {}

M.chunk_count = 7
M.chunk_size = 2000

local function load_chunk(chunk_idx)
  if _loaded_chunks[chunk_idx] then return _loaded_chunks[chunk_idx] end
  local path = "EaxAutoQuester.npc_spawns.chunk_" .. string.format("%03d", chunk_idx)
  local ok, chunk = pcall(require, path)
  if ok and chunk and chunk.by_entry then
    _loaded_chunks[chunk_idx] = chunk.by_entry
    return chunk.by_entry
  end
  return {}
end

local function ensure_all_loaded()
  for i = 0, 6 do load_chunk(i) end
end

function M.find_npc_spawn(npc_id, player_map_id)
  if not npc_id then return nil end
  local id_key = tostring(npc_id)
  local data = nil
  for i = 0, 6 do
    local chunk = load_chunk(i)
    data = chunk[id_key]
    if data then break end
  end
  if not data or not data.maps or #data.maps == 0 then return nil end

  local maps = data.maps
  local name = data.name or 'Unknown'

  local best = nil
  for i = 1, #maps do
    local m = maps[i]
    if m and m.x and m.y then
      if player_map_id and m.map_id == player_map_id then
        return { npc_id = npc_id, name = name, map_id = m.map_id, x = m.x, y = m.y, z = m.z or 0 }
      end
      if not best then best = m end
    end
  end
  if best then
    return { npc_id = npc_id, name = name, map_id = best.map_id, x = best.x, y = best.y, z = best.z or 0 }
  end
  return nil
end

function M.search_npc_by_name(search)
  if not search or search == '' then return {} end
  local results = {}
  local search_lower = string.lower(search)
  ensure_all_loaded()
  for i = 0, 6 do
    local chunk_data = _loaded_chunks[i]
    for id_str, entry in pairs(chunk_data) do
      if entry.name and string.find(string.lower(entry.name), search_lower, 1, true) then
        local id = tonumber(id_str)
        if id and entry.maps and #entry.maps > 0 then
          local m = entry.maps[1]
          results[#results + 1] = {
            npc_id = id, name = entry.name, map_id = m.map_id, x = m.x, y = m.y, z = m.z or 0,
          }
        end
      end
    end
  end
  return results
end

return M