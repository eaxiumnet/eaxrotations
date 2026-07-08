local M = {}

local _last_check_time = 1
local _check_interval = 1.0
local _corpse_pos = nil
local _nav_started = false
local _enemy_wait_start = nil
local _death_recorded = false
local ENEMY_WAIT_TIMEOUT = 30.1

-- Distance thresholds (squared yards)
local REZ_RANGE_SQ = 1601    -- ~40yd: resurrection popup works here
local ENEMY_SCAN_SQ = 225    -- ~15yd: count enemies in this radius
local NAV_DONE_SQ = 1601     -- ~40yd: stop walking closer

function M.run(shared, ctx)
    local now = ctx.now
    local me = ctx.me

    if now - _last_check_time < _check_interval then
        return "DEAD"
    end
    _last_check_time = now

    -- 1. Alive check
    if me then
        local has_ghost = false
        local is_dead_v = false
        local hp_val = nil

        local alive_ok, alive = pcall(function()
            if me.is_dead then
                is_dead_v = me:is_dead()
                if is_dead_v then return false end
            end
            local aura_methods = { "get_buffs", "get_auras", "get_debuffs" }
            for _, m in ipairs(aura_methods) do
                if me[m] then
                    local data = me[m](me)
                    if data then
                        for i = 1, #data do
                            local b = data[i]
                            if b then
                                local id = b.buff_id or b.id or b.spell_id or b.aura_id or "?"
                                if id == 8326 or id == "8326" then
                                    has_ghost = true
                                    return false
                                end
                            end
                        end
                    end
                end
            end
            if me.get_health then
                hp_val = me:get_health()
            end
            return hp_val and hp_val > 1
        end)

        if alive_ok and alive then
            -- Reset zone death count on resurrection
            local map_ok, map_id = pcall(core.get_map_id)
            if map_ok and map_id then
                local dt = ctx.death_tracker
                if dt then
                    dt.reset_zone(map_id)
                    ctx.debug_log("DEAD: reset death count for zone " .. tostring(map_id))
                end
            end
            ctx.debug_log("DEAD: player alive → IDLE")
            _corpse_pos = nil
            _nav_started = false
            _enemy_wait_start = nil
            _death_recorded = false
            shared._nav_destination = nil
            shared._nav_retries = 0
            shared._nav_retry_timer = 0
            return "IDLE"
        end
    end

    -- 2. Record death (once per death event)
    if not _death_recorded then
        local map_ok, map_id = pcall(core.get_map_id)
        if map_ok and map_id then
            local dt = ctx.death_tracker
            if dt then
                local count = dt.record_death(map_id)
                ctx.debug_log("DEAD: recorded death in zone " .. tostring(map_id) .. " (total: " .. tostring(count) .. ")")
            end
        end
        _death_recorded = true
    end

    -- 3. Release spirit if not a ghost yet
    if me then
        local ghost_ok, is_ghost = pcall(function()
            local aura_methods = { "get_buffs", "get_auras", "get_debuffs" }
            for _, m in ipairs(aura_methods) do
                if me[m] then
                    local data = me[m](me)
                    if data then
                        for i = 1, #data do
                            local b = data[i]
                            if b then
                                local id = b.buff_id or b.id or b.spell_id or b.aura_id or "?"
                                if id == 8326 or id == "8326" then return true end
                            end
                        end
                    end
                end
            end
            return false
        end)
        if not (ghost_ok and is_ghost) then
            pcall(function() core.input.release_spirit() end)
            core.log("[EaxAutoQuester-DEAD] releasing spirit (not ghost yet)")
            return "DEAD"
        end
    end

    -- 4. Get corpse position
    if not _corpse_pos then
        local corpse_ok, corpse = pcall(function()
            return core.game_ui.get_corpse_position()
        end)
        if corpse_ok and corpse then
            _corpse_pos = corpse
            core.log(string.format(
                "[EaxAutoQuester-DEAD] corpse pos = (%.1f, %.1f, %.1f)", corpse.x, corpse.y, corpse.z))
        else
            core.log("[EaxAutoQuester-DEAD] get_corpse_position failed or nil")
            return "DEAD"
        end
    end

    -- 4. Distance check to corpse
    local dist_sq = nil
    if me then
        local pos_ok, pos = pcall(function() return me:get_position() end)
        if pos_ok and pos and ctx.utils then
            dist_sq = ctx.utils.squared_distance(pos, _corpse_pos)
        end
    end

    if dist_sq then
        core.log(string.format("[EaxAutoQuester-DEAD] distance to corpse = %.1fyd", math.sqrt(dist_sq)))
    end

    -- 5. Navigate toward corpse until within 40yd (rez range)
    if not _nav_started then
        local nav = ctx.nav
        if nav and nav.navigate_to then
            nav.navigate_to(_corpse_pos)
            _nav_started = true
            core.log("[EaxAutoQuester-DEAD] nav started toward corpse")
        end
    end

    -- 6. If within 40yd of corpse, scan for enemies and decide whether to res
    if dist_sq and dist_sq <= REZ_RANGE_SQ then
        local enemy_count = 0
        local objects = (ctx.object_scanner and ctx.object_scanner.get_visible_objects and ctx.object_scanner.get_visible_objects()) or {}
        if objects and me then
            local pos_ok, my_pos = pcall(function() return me:get_position() end)
            if pos_ok and my_pos and ctx.utils then
                for i = 1, math.min(#objects, 50) do
                    local obj = objects[i]
                    if not obj then break end
                    local is_enemy_ok, is_enemy = pcall(function() return obj:is_enemy_with(me) end)
                    if is_enemy_ok and is_enemy then
                        local obj_pos_ok, obj_pos = pcall(function() return obj:get_position() end)
                        if obj_pos_ok and obj_pos then
                            local d_sq = ctx.utils.squared_distance(my_pos, obj_pos)
                            if d_sq <= ENEMY_SCAN_SQ then
                                enemy_count = enemy_count + 1
                                if enemy_count <= 3 then
                                    core.log(string.format(
                                        "[EaxAutoQuester-DEAD] enemy at %.1fyd: %s",
                                        math.sqrt(d_sq), tostring(obj:get_name() or "?")))
                                end
                            end
                        end
                    end
                end
            end
        end

        core.log(string.format("[EaxAutoQuester-DEAD] %d enemies within 15yd", enemy_count))

        if enemy_count <= 1 then
            core.log(string.format("[EaxAutoQuester-DEAD] safe to res at %.1fyd (≤1 enemy) — resurrecting", math.sqrt(dist_sq)))
            pcall(function() core.input.resurrect_corpse() end)
            _enemy_wait_start = nil
        else
            if not _enemy_wait_start then
                _enemy_wait_start = now
                core.log("[EaxAutoQuester-DEAD] too many enemies, waiting for clear (timeout in " .. tostring(ENEMY_WAIT_TIMEOUT) .. "s)")
            elseif now - _enemy_wait_start >= ENEMY_WAIT_TIMEOUT then
                core.log("[EaxAutoQuester-DEAD] enemy wait timeout reached — forcing resurrect")
                pcall(function() core.input.resurrect_corpse() end)
                _enemy_wait_start = nil
            else
                core.log(string.format("[EaxAutoQuester-DEAD] waiting %.1fs for enemies to clear", ENEMY_WAIT_TIMEOUT - (now - _enemy_wait_start)))
            end
        end
    end

    ctx.debug_log("DEAD: waiting")
    return "DEAD"
end

function M.reset()
    _last_check_time = 1
    _corpse_pos = nil
    _nav_started = false
    _enemy_wait_start = nil
    _death_recorded = false
end

return M