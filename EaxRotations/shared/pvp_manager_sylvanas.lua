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
    local list = nil
    if NS.get_visible_units then
        local ok, units, count = pcall(NS.get_visible_units)
        if ok and type(units) == "table" then list = units end
    end
    if type(list) ~= "table" then return {} end
    for i = 1, #list do
        local unit = list[i]
        if unit then
            local ok, is_player = pcall(unit.is_player, unit)
            if ok and is_player then
                enemies[#enemies + 1] = unit
            end
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
        local ok, class_id = pcall(unit.get_class, unit)
        if not ok then class_id = nil end

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
            local ok, id = pcall(item.get_item_id, item)
            if not ok then id = 0 end
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

-- Battleground detection
local _bg_cache = { map_id = 0, bg_type = nil }
function M.get_battleground_type()
    local map_id = core.get_map_id and core.get_map_id() or 0
    if map_id == _bg_cache.map_id and _bg_cache.bg_type then return _bg_cache.bg_type end
    _bg_cache.map_id = map_id

    -- Warsong Gulch
    if map_id == 489 then _bg_cache.bg_type = "wsg"; return "wsg" end
    -- Arathi Basin
    if map_id == 529 then _bg_cache.bg_type = "ab"; return "ab" end
    -- Alterac Valley
    if map_id == 30 then _bg_cache.bg_type = "av"; return "av" end
    -- Eye of the Storm
    if map_id == 566 then _bg_cache.bg_type = "eots"; return "eots" end
    -- Strand of the Ancients
    if map_id == 607 then _bg_cache.bg_type = "sota"; return "sota" end

    _bg_cache.bg_type = nil
    return nil
end

-- Flag carrier detection (WSG/EotS)
function M.is_flag_carrier(context)
    if not context then return false end
    local me = context.me
    if not me then return false end
    -- Check for flag buff (WSG flag = 23333/23335, EotS flag = 34976)
    local ok1, has_flag1 = pcall(function() return me:has_buff(23333) or me:has_buff(23335) or me:has_buff(34976) end)
    return ok1 and has_flag1 == true
end

-- Node defense check (AB/EotS)
function M.should_defend_node(context)
    if not context then return false end
    local bg = M.get_battleground_type()
    if bg ~= "ab" and bg ~= "eots" then return false end
    -- In AB/EotS, defend if we're near a flag and enemies are close
    local me = context.me
    if not me then return false end
    local enemy_count = context.enemy_count or 0
    return enemy_count > 0 and enemy_count <= 3
end

return M
