-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/pvp_manager_sylvanas.lua"
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
-- ============================================================================
-- Shared Helper: PvP Manager
-- ============================================================================
-- ============================================================================

local NS = _G.EaxRotations
local M = {}

local ENUMS = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4,
    PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

local HEALER_CLASS_IDS = {
    [ENUMS.PRIEST] = true,
    [ENUMS.SHAMAN] = true,
    [ENUMS.PALADIN] = true,
    [ENUMS.DRUID] = true,
}

local _last_map_check = 0
local _cached_pvp_type = nil

function M.is_in_pvp_instance()
    local now = NS.time_now and NS.time_now() or 0
    if now - _last_map_check < 5 then return _cached_pvp_type end
    _last_map_check = now

    local map_id = core.get_map_id and core.get_map_id() or 0
    local map_name = core.get_map_name and core.get_map_name() or ""

    -- Arena maps
    if map_id == 559 or map_id == 562 or map_id == 572 or map_id == 617 then
        _cached_pvp_type = "arena"
        return "arena"
    end

    -- Battleground maps
    if map_id == 30 or map_id == 489 or map_id == 566 or map_id == 529 or map_id == 607 then
        _cached_pvp_type = "battleground"
        return "battleground"
    end

    -- Check map name for other PvP zones
    if map_name then
        local lower = map_name:lower()
        if lower:find("arena") then
            _cached_pvp_type = "arena"
            return "arena"
        end
    end

    _cached_pvp_type = nil
    return nil
end

function M.is_world_pvp(context)
    if not context then return false end
    if M.is_in_pvp_instance() then return true end
    local me = context.me
    if not me then return false end
    local ok, is_pvp = pcall(function() return me:is_pvp() end)
    return ok and is_pvp == true
end

function M.get_enemy_players(context)
    if not context then return {} end
    local me = context.me
    if not me then return {} end
    local enemies = {}
    local list = core.object_manager and core.object_manager.get_enemy_list()
    if type(list) ~= "table" then return {} end
    for i = 1, #list do
        local unit = list[i]
        if unit and pcall(unit.is_player, unit) then
            enemies[#enemies + 1] = unit
        end
    end
    return enemies
end

function M.pick_priority_target(context)
    local enemies = M.get_enemy_players(context)
    if #enemies == 0 then return nil end

    local healer, caster, melee
    for i = 1, #enemies do
        local unit = enemies[i]
        local class_id = pcall(unit.get_class, unit) and unit:get_class() or nil

        if HEALER_CLASS_IDS[class_id] then
            healer = unit
            break
        end

        if class_id == ENUMS.MAGE or class_id == ENUMS.WARLOCK or class_id == ENUMS.PRIEST then
            if not caster then caster = unit end
        else
            if not melee then melee = unit end
        end
    end

    return healer or caster or melee or enemies[1]
end

function M.has_pvp_trinket()
    local trinket_ids = { 33831, 42244, 42245 }
    local inventory = core and core.inventory
    if not inventory then return false end
    local ok, items = pcall(inventory.get_equipped_items)
    if not ok then return false end
    for i = 1, #items do
        local item = items[i]
        if item then
            local id = pcall(item.get_item_id, item) and item:get_item_id() or 0
            for j = 1, #trinket_ids do
                if id == trinket_ids[j] then return true end
            end
        end
    end
    return false
end

function M.get_arena_teams()
    local arena = core.object_manager and core.object_manager.get_arena_frames
    if not arena then return nil end
    local ok, frames = pcall(arena)
    if not ok or type(frames) ~= "table" then return nil end
    return frames
end

return M
