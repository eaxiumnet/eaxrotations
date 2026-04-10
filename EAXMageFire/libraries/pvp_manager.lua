-- pvp_manager.lua
-- PvP context manager stub.
-- Returns safe defaults so PvP branches in the rotation are skipped
-- gracefully until a full implementation is available.

local pvp_manager = {}

--- Returns true if the player is inside a BG/arena instance.
---@return boolean
function pvp_manager.is_in_pvp_instance()
    if not core or not core.object_manager then return false end
    local ok, zone = pcall(function() return core.object_manager.get_zone_type and core.object_manager.get_zone_type() end)
    if not ok or not zone then return false end
    -- zone type 4 = arena, zone type 6 = battleground (common enum values)
    return zone == 4 or zone == 6
end

--- Returns true if the player is flagged for world PvP.
---@param me userdata
---@return boolean
function pvp_manager.is_world_pvp(me)
    return false  -- conservative: don't activate world-PvP logic by default
end

--- Find nearby enemy players within range yards.
---@param me userdata
---@param range number
---@return table list of enemy player units (may be empty)
function pvp_manager.find_enemy_players(me, range)
    local enemies = {}
    if not core or not core.object_manager then return enemies end
    local ok, units = pcall(function() return core.object_manager.get_units_around(me, range) end)
    if not ok or not units then return enemies end
    for _, unit in ipairs(units) do
        local is_player_ok, is_player = pcall(function() return unit:is_player() end)
        local is_enemy_ok, is_enemy  = pcall(function() return unit:is_enemy(me) end)
        if is_player_ok and is_player and is_enemy_ok and is_enemy then
            enemies[#enemies + 1] = unit
        end
    end
    return enemies
end

--- Select the highest-priority target from a list of enemy players.
---@param me userdata
---@param players table
---@return userdata|nil
function pvp_manager.priority_target(me, players)
    if not players or #players == 0 then return nil end
    -- Simple fallback: pick the player with lowest health
    local best, best_hp = nil, math.huge
    for _, p in ipairs(players) do
        local ok, hp = pcall(function() return p:get_health_percentage() end)
        if ok and hp < best_hp then
            best    = p
            best_hp = hp
        end
    end
    return best
end

return pvp_manager
