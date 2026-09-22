-- NPC Spawn Database Index - cMaNGOS tbc-db
-- Auto-generated from TBCDB_1.10.0_ReturnOfTheVengeance.sql
-- 12265 unique NPCs across 7 chunks
local M = {}
local _loaded_chunks = {}

M.chunk_count = 7
M.chunk_size = 2000

local function load_chunk(chunk_idx)
  if _loaded_chunks[chunk_idx] then return _loaded_chunks[chunk_idx] end
  -- Slash-separated module path on purpose: it resolves through the package.path
  -- entry "./EaxAutoQuester/?.lua", so it works wherever the plugin tree is mounted.
  -- The dotted form "EaxAutoQuester.npc_spawns.chunk_000" only resolves when the
  -- plugin's PARENT directory is on package.path, which made every spawn lookup
  -- silently return nil under a differently-rooted checkout.
  local path = "npc_spawns/chunk_" .. string.format("%03d", chunk_idx)
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

-- Cache of name -> { {npc_id=, name=} ... }. The search itself walks every loaded chunk, and
-- callers ask the same question once per step while the same mob is the objective.
local _name_ids_cache = {}
local MAX_NAME_IDS = 32

--- Resolve a name to the NPC entry IDs that carry it.
--- Exact case-insensitive equality wins: a substring-only search would answer
--- "Lesser Rock Elemental" with "Greater Rock Elemental" as well, and the spawn points of the
--- wrong mob are worse than none. Substring matches are returned only when nothing matches
--- exactly, which is what makes Zygor's pluralized or partial names still resolvable.
--- @param name string|nil World name to resolve
--- @return table[] Read-only array of { npc_id, name }
function M.find_npc_ids_by_name(name)
  if not name or name == '' then return {} end
  local cached = _name_ids_cache[name]
  if cached then return cached end

  ensure_all_loaded()
  local search_lower = string.lower(name)
  local exact = {}
  local partial = {}
  for i = 0, 6 do
    local chunk_data = _loaded_chunks[i]
    for id_str, entry in pairs(chunk_data) do
      if entry.name then
        local entry_lower = string.lower(entry.name)
        local id = tonumber(id_str)
        if id then
          if entry_lower == search_lower then
            exact[#exact + 1] = { npc_id = id, name = entry.name }
          elseif string.find(entry_lower, search_lower, 1, true) then
            partial[#partial + 1] = { npc_id = id, name = entry.name }
          end
        end
      end
    end
  end

  local result = #exact > 0 and exact or partial
  if #result > MAX_NAME_IDS then
    local trimmed = {}
    for i = 1, MAX_NAME_IDS do trimmed[i] = result[i] end
    result = trimmed
  end
  _name_ids_cache[name] = result
  return result
end

--- Every spawn point recorded for an NPC, across every map.
--- Lazy per chunk (an ID lives in exactly one chunk), and the array is the module's own data:
--- READ-ONLY, do not mutate. Callers filter by map and distance themselves — they need both.
--- @param npc_id integer|nil NPC entry ID
--- @return table[]|nil Read-only array of { map_id, x, y, z }, or nil when unknown
function M.find_npc_spawns(npc_id)
  if not npc_id then return nil end
  local id_key = tostring(npc_id)
  for i = 0, 6 do
    local chunk = load_chunk(i)
    local data = chunk[id_key]
    if data then
      if data.maps and #data.maps > 0 then return data.maps end
      return nil
    end
  end
  return nil
end

--- Drop the name cache. Only for tests that need a cold start; production never calls it.
function M.clear_name_cache()
  _name_ids_cache = {}
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