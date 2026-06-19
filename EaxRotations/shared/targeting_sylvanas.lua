-- ============================================================================
-- Shared Helper: Targeting System
-- Sticky target, raid marker priority, pull modes, enemy counting
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations
local _core_time = type(core) == "table" and type(core.time) == "function" and core.time or function() return 0 end
local _get_local_player = NS.GetPlayer or (core.object_manager and core.object_manager.get_local_player) or function() return nil end

-- ============================================================================
-- Internal state
-- ============================================================================

local _sticky = {
    guid = nil,
    set_time = 0,
}

-- ============================================================================
-- Pull mode helpers
-- ============================================================================

---@param mode string "combat_only"|"full_auto"|"hud_target"|"pet_first"|"engage_target"
---@param ctx table Combat context
---@return boolean should_engage True if the script should initiate combat
function M.should_engage(mode, ctx)
    if not ctx or not ctx.me then return false end
    if ctx.is_mounted then return false end

    if mode == "combat_only" then
        return ctx.in_combat or ctx.me:is_in_combat()
    elseif mode == "full_auto" then
        return true
    elseif mode == "hud_target" or mode == "engage_target" then
        -- Engage only if target is already selected
        local target = ctx.target or ctx.me:get_target()
        return target and target:is_valid() and target:is_alive()
    elseif mode == "pet_first" then
        return true
    end
    return ctx.in_combat
end

---@param ctx table Combat context
---@return boolean should_pet_attack True if pet should engage
function M.should_pet_engage(mode, ctx)
    if not ctx or not ctx.me then return false end
    if ctx.is_mounted then return false end

    if mode == "combat_only" then
        return ctx.in_combat
    elseif mode == "pet_first" then
        return true
    elseif mode == "full_auto" then
        return true
    end
    return ctx.in_combat
end

-- ============================================================================
-- Sticky target
-- ============================================================================

--- Sets the sticky target GUID
---@param guid string Target GUID
function M.set_sticky(guid)
    _sticky.guid = guid
    _sticky.set_time = _core_time()
end

--- Clears sticky target
function M.clear_sticky()
    _sticky.guid = nil
    _sticky.set_time = 0
end

--- Checks if a unit should be kept as sticky target
---@param unit game_object The current target
---@param opts table|nil Options: max_distance, max_age
---@return boolean keep
function M.should_keep_sticky(unit, opts)
    if not unit or not unit:is_valid() then
        M.clear_sticky()
        return false
    end
    if not unit:is_alive() then
        M.clear_sticky()
        return false
    end

    local guid = tostring(unit:get_guid())
    if _sticky.guid and _sticky.guid ~= guid then
        return false
    end

    opts = opts or {}
    local max_dist = opts.max_distance or 40
    local max_age = opts.max_age or 300

    if max_age > 0 and (_core_time() - _sticky.set_time) > max_age then
        M.clear_sticky()
        return false
    end

    if max_dist > 0 then
        local me = _get_local_player()
        if me and me:is_valid() then
            local dist = me:get_distance(unit)
            if dist and dist > max_dist then
                M.clear_sticky()
                return false
            end
        end
    end

    return true
end

-- ============================================================================
-- Raid marker priority
-- ============================================================================

--- Priority mapping for raid markers (lower = higher priority).
--- API returns get_target_marker_index(): 0=none, 1=Star, 2=Circle, 3=Diamond,
--- 4=Triangle, 5=Moon, 6=Square, 7=Cross, 8=Skull.
--- Map numeric index directly to priority (skull = highest priority).
local MARKER_PRIORITY = {
    [8] = 1,  -- Skull
    [7] = 2,  -- Cross
    [1] = 3,  -- Star
    [2] = 4,  -- Circle
    [5] = 5,  -- Moon
    [6] = 6,  -- Square
    [3] = 7,  -- Diamond
    [4] = 8,  -- Triangle
}

--- Safely get the raid marker index from a unit using documented API.
---@param unit game_object
---@return integer marker_index 0-8, 0 = no marker
local function get_marker_index(unit)
    if not unit then return 0 end
    if type(unit.get_target_marker_index) == "function" then
        local ok, val = pcall(unit.get_target_marker_index, unit)
        if ok and type(val) == "number" then return val end
    end
    -- Fallback: undocumented get_raid_marker returning string names
    if type(unit.get_raid_marker) == "function" then
        local ok, val = pcall(unit.get_raid_marker, unit)
        if ok and type(val) == "string" then
            local str_to_idx = { skull = 8, cross = 7, star = 1, circle = 2, diamond = 3, triangle = 4, moon = 5, square = 6 }
            return str_to_idx[val] or 0
        end
    end
    return 0
end

--- Get enemies list using documented API (NS.GetEnemiesInRange) with fallback.
---@param range number
---@return table enemies, number count
local function get_enemies(range)
    if NS.GetEnemiesInRange then
        local list = NS.GetEnemiesInRange(range)
        if type(list) == "table" then return list, list.n or #list end
    end
    -- Fallback: scan visible objects
    if core and core.object_manager and type(core.object_manager.get_visible_objects) == "function" then
        local list = core.object_manager.get_visible_objects()
        if type(list) == "table" then return list, #list end
    end
    return {}, 0
end

--- Sorts enemies by raid marker priority (Skull > X > Star > ...)
---@param enemies game_object[] List of enemy units
---@return game_object[] Sorted copy of the list
function M.sort_by_marker_priority(enemies)
    if not enemies or #enemies == 0 then return enemies or {} end

    -- Build scored table
    local scored = {}
    for i = 1, #enemies do
        local unit = enemies[i]
        local marker = get_marker_index(unit)
        local priority = MARKER_PRIORITY[marker] or 999
        scored[i] = { unit = unit, priority = priority }
    end

    -- Sort by priority (lower = first)
    table.sort(scored, function(a, b)
        return a.priority < b.priority
    end)

    -- Extract sorted units
    local result = {}
    for i = 1, #scored do
        result[i] = scored[i].unit
    end
    return result
end

--- Finds the highest-priority marker target from a list
---@param enemies game_object[]
---@return game_object|nil best Highest priority marked enemy, or nil
function M.find_best_marked(enemies)
    if not enemies or #enemies == 0 then return nil end

    local best = nil
    local best_priority = 999

    for i = 1, #enemies do
        local unit = enemies[i]
        if unit and unit:is_valid() and unit:is_alive() then
            local marker = get_marker_index(unit)
            local priority = MARKER_PRIORITY[marker] or 999
            if priority < best_priority then
                best_priority = priority
                best = unit
            end
        end
    end

    return best
end

-- ============================================================================
-- Enemy counting
-- ============================================================================

--- Counts enemies within a radius around a position/unit
---@param center unit|table Center position or unit
---@param radius number Radius in yards
---@param opts table|nil Options: include_current (bool)
---@return integer count
function M.count_enemies_around(center, radius, opts)
    if not center then return 0 end

    opts = opts or {}
    local count = 0
    local cx, cy, cz

    -- Get center coordinates
    if type(center) == "table" and center.x then
        cx, cy, cz = center.x, center.y, center.z
    elseif center.get_position then
        local pos = center:get_position()
        if pos then
            cx, cy, cz = pos.x, pos.y, pos.z
        end
    end

    if not cx then return 0 end

    -- Use documented API to get enemies near player (scan at 2x radius to capture everything)
    local enemies, enemy_count = get_enemies(radius * 2 + 5)
    if enemy_count == 0 then return 0 end

    local radius_sq = radius * radius

    for i = 1, enemy_count do
        local enemy = enemies[i]
        if enemy and enemy:is_valid() and enemy:is_alive() then
            local epos = enemy:get_position()
            if epos then
                local dx = epos.x - cx
                local dy = epos.y - cy
                local dz = (epos.z or 0) - (cz or 0)
                local dist_sq = dx * dx + dy * dy + dz * dz
                if dist_sq <= radius_sq then
                    count = count + 1
                end
            end
        end
    end

    return count
end

--- Counts enemies within melee range (8 yards)
---@param center unit|nil Center unit (defaults to player)
---@return integer count
function M.count_melee_enemies(center)
    local me = center or _get_local_player()
    if not me then return 0 end
    return M.count_enemies_around(me, 8)
end

-- ============================================================================
-- Boss fight detection
-- ============================================================================

function M.is_boss_fight()
    if core and core.object_manager then
        local count_fn = core.object_manager.get_boss_count
        if type(count_fn) == "function" then
            local ok, count = pcall(count_fn)
            if ok and type(count) == "number" then
                return count >= 1
            end
        end
    end

    if core and core.object_manager then
        local frames_fn = core.object_manager.get_boss_frames
        if type(frames_fn) == "function" then
            local ok, frames = pcall(frames_fn)
            if ok and type(frames) == "table" then
                return #frames >= 1
            end
        end
    end

    return false
end

-- ============================================================================
-- Tap-denied check (leveling mob filtering)
-- ============================================================================

--- Check if a mob is tapped by another player (gray health bar).
---@param unit game_object|nil
---@return boolean
function M.is_tapped(unit)
    if not unit then return false end
    if type(unit.is_tap_denied) ~= "function" then return false end
    local ok, result = pcall(unit.is_tap_denied, unit)
    return ok and result and result ~=  0 and result ~= false
end

-- ============================================================================
-- Target resolution
-- ============================================================================

--- Resolves the best target based on mode and context
---@param ctx table Combat context
---@param opts table|nil Options: prefer_marked (bool), sticky (bool), max_distance
---@return game_object|nil target
function M.resolve_target(ctx, opts)
    if not ctx then return nil end

    opts = opts or {}
    local me = ctx.me or _get_local_player()
    if not me then return nil end

    -- Check current target first
    local current = ctx.target or me:get_target()
    if current and current:is_valid() and current:is_alive() then
        -- Sticky target check
        if opts.sticky and _sticky.guid then
            local guid = tostring(current:get_guid())
            if guid == _sticky.guid then
                return current
            end
        end

        -- Raid marker priority: check if higher priority marked target exists
        if opts.prefer_marked then
            local max_range = opts.max_distance or 40
            local enemies, _ = get_enemies(max_range)
            local marked = M.find_best_marked(enemies)
            if marked then
                local mark = get_marker_index(marked)
                local cur_mark = get_marker_index(current)
                local mark_prio = MARKER_PRIORITY[mark] or 999
                local cur_prio = MARKER_PRIORITY[cur_mark] or 999
                if mark_prio < cur_prio then
                    return marked
                end
            end
        end

        -- Max distance check
        if opts.max_distance then
            local dist = me:get_distance(current)
            if dist and dist > opts.max_distance then
                -- Try to find closer target
            else
                return current
            end
        else
            return current
        end
    end

    -- Fallback: find nearest enemy
    local enemies, enemy_count = get_enemies(opts.max_distance or 40)
    if enemy_count == 0 then return nil end

    if opts.prefer_marked then
        local marked = M.find_best_marked(enemies)
        if marked then return marked end
    end

    local best = nil
    local best_dist = math.huge

    for i = 1, enemy_count do
        local enemy = enemies[i]
        if enemy and enemy:is_valid() and enemy:is_alive() and enemy:can_attack(me) then
            -- Leveling context: skip tap-denied (gray-bar) mobs
            if ctx.is_leveling and M.is_tapped(enemy) then
                -- Skip tapped mob in leveling
            else
                local dist = me:get_distance(enemy)
                if dist and dist < best_dist then
                    best_dist = dist
                    best = enemy
                end
            end
        end
    end

    return best
end

-- ============================================================================
-- Export
-- ============================================================================

NS.Targeting = M

return M
