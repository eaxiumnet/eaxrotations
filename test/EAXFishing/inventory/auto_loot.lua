-- =============================================================================
-- inventory/auto_loot.lua — Auto-Loot Module (v2.5.0)
-- WHAT:  Automatically loots nearby corpses with humanized timing,
--        burst protection, combat awareness, and bag-full safety.
-- WHEN:  Enabled via menu; respects combat mode, bag space, and player-corpses settings.
-- WHY:   Fishing sessions generate many mob kills (self-defense, nearby mobs).
--        Auto-looting prevents missed drops without robotic patterns.
-- SAFETY: pcall-wrapped all API calls; respects OOC-only mode; bag-full pause;
--         max-loots-per-10s cap prevents burst detection. No banned APIs.
-- =============================================================================

local M = {}

local APISurface = require("core/api_surface")
local LootDB     = require("fishing/loot_db")

-- ── Static tables (reused every frame) ──────────────────────────────────────
local _nearby_corpses = { n = 0 }
local _corpse_blacklist = {} -- corpse_guid -> blacklist_until_time

-- ── Helpers ─────────────────────────────────────────────────────────────────

--- Check if a unit is a player corpse (skip if configured)
local function is_player_corpse(obj)
    if not obj then return false end
    -- Try multiple methods to detect player corpses
    local ok_type, utype = pcall(function()
        if obj.get_unit_type then return obj:get_unit_type() end
        if obj.unit_type then return obj:unit_type() end
        return nil
    end)
    if ok_type and utype == "player" then return true end

    local ok_name, name = pcall(function()
        if obj.get_name then return obj:get_name() end
        if obj.name then return obj:name() end
        return nil
    end)
    if ok_name and name then
        -- Player corpses often have specific naming patterns
        -- This is heuristic but catches most cases
        if name:find("^Player ") or name:find("'s Corpse$") then
            return true
        end
    end

    return false
end

--- Check if a corpse is lootable (has loot window available)
local function can_loot_corpse(obj)
    if not obj then return false end
    -- Method 1: Direct lootable check
    local ok_lootable, is_lootable = pcall(function()
        if obj.is_lootable then return obj:is_lootable() end
        if obj.lootable then return obj:lootable() end
        return nil
    end)
    if ok_lootable and is_lootable == true then return true end

    -- Method 2: Check if corpse is still valid and recently died
    local ok_dead, is_dead = pcall(function()
        if obj.is_dead then return obj:is_dead() end
        return nil
    end)
    if ok_dead and is_dead == true then
        -- Dead units are potentially lootable if we haven't tried yet
        return true
    end

    return false
end

--- Get distance squared to a corpse
local function dist_sq_to_corpse(me_pos, obj)
    local ok, ox, oy, oz = pcall(function()
        local p = nil
        if obj.get_position then p = obj:get_position() end
        if not p and obj.position then p = obj:position() end
        if p then return p.x, p.y, p.z end
        return nil, nil, nil
    end)
    if ok and ox and me_pos then
        local dx = me_pos.x - ox
        local dy = me_pos.y - oy
        local dz = (me_pos.z or 0) - (oz or 0)
        return dx*dx + dy*dy + dz*dz
    end
    return math.huge
end

--- Check if we're in combat (or recently were)
local function is_in_combat_or_grace(ctx, now)
    local state = ctx.state
    local deps = ctx.deps

    -- Check current combat state
    local me = APISurface.get_local_player()
    if me then
        local ok, in_combat = pcall(function()
            if me.is_in_combat then return me:is_in_combat() end
            return false
        end)
        if ok and in_combat then
            state.autoloot.last_combat_end = nil
            return true
        end
    end

    -- Post-combat grace period
    if state.autoloot.last_combat_end then
        local grace = 0
        if deps.config.menu.autoloot_grace_period then
            grace = deps.config.menu.autoloot_grace_period:get() or 0
        end
        if now < state.autoloot.last_combat_end + grace then
            return true
        end
        state.autoloot.last_combat_end = nil
    end

    return false
end

-- ── Core Functions ──────────────────────────────────────────────────────────

--- Scan for nearby lootable corpses
-- @param ctx table context
-- @param me_pos table player position
-- @param range number scan range in yards
-- @return table corpses array, number count
function M.find_lootable_corpses(ctx, me_pos, range)
    _nearby_corpses.n = 0

    local deps = ctx.deps
    local state = ctx.state
    local now = APISurface.now()
    local range_sq = range * range
    local skip_players = false
    if deps.config.menu.autoloot_skip_players then
        skip_players = deps.config.menu.autoloot_skip_players:get_state()
    end

    local objects = APISurface.get_all_objects()
    if not objects then return _nearby_corpses, 0 end

    for _, obj in ipairs(objects) do
        -- Lua 5.1 compatibility: use nested if instead of goto
        if APISurface.is_valid(obj) then
            -- Skip if blacklisted (recently tried and failed)
            local guid = nil
            local ok_guid, g = pcall(function()
                if obj.get_guid then return obj:get_guid() end
                if obj.guid then return obj:guid() end
                return nil
            end)
            local skip = false
            if ok_guid and g then
                guid = g
                local blacklist_until = _corpse_blacklist[g]
                if blacklist_until and now < blacklist_until then
                    skip = true
                end
            end

            if not skip then
                -- Distance check
                local dsq = dist_sq_to_corpse(me_pos, obj)
                if dsq <= range_sq then
                    -- Skip player corpses if configured
                    if not (skip_players and is_player_corpse(obj)) then
                        -- Check if lootable
                        if can_loot_corpse(obj) then
                            _nearby_corpses.n = _nearby_corpses.n + 1
                            _nearby_corpses[_nearby_corpses.n] = { obj = obj, guid = guid, dist_sq = dsq }
                        end
                    end
                end
            end
        end
    end

    return _nearby_corpses, _nearby_corpses.n
end

--- Attempt to loot a single corpse
-- @param ctx table context
-- @param corpse_entry table {obj, guid}
-- @param now number current time
-- @return boolean success
function M.loot_corpse(ctx, corpse_entry, now)
    local obj = corpse_entry.obj
    local guid = corpse_entry.guid
    local state = ctx.state

    -- Humanized delay: random wait before looting
    local deps = ctx.deps
    local min_delay = 0
    local max_delay = 200
    if deps.config.menu.autoloot_delay_min_ms then
        min_delay = deps.config.menu.autoloot_delay_min_ms:get() or 0
    end
    if deps.config.menu.autoloot_delay_max_ms then
        max_delay = deps.config.menu.autoloot_delay_max_ms:get() or 200
    end
    local delay = min_delay + math.random() * (max_delay - min_delay)

    if delay > 0 then
        -- We can't block the main thread, so we set a deadline
        state.autoloot.loot_deadline = now + (delay / 1000)
        return false -- Will retry next tick
    end

    -- Actually loot
    local ok = false
    if core and core.input and core.input.loot_object then
        ok = pcall(core.input.loot_object, obj)
    end

    if ok then
        state.autoloot.corpses_looted = state.autoloot.corpses_looted + 1
        state.autoloot.last_corpse_name = nil
        local ok_name, name = pcall(function()
            if obj.get_name then return obj:get_name() end
            return nil
        end)
        if ok_name then state.autoloot.last_corpse_name = name end
        state.autoloot.last_loot_time = now
        state.autoloot.loots_in_window = state.autoloot.loots_in_window + 1

        -- Close loot window after a short delay (humanized)
        state.autoloot.close_loot_deadline = now + 0.3 + math.random() * 0.5

        return true
    else
        -- Blacklist this corpse for 5 seconds (maybe someone else looted it)
        if guid then
            _corpse_blacklist[guid] = now + 5
        end
        return false
    end
end

--- Main update tick
-- @param ctx table context
function M.update(ctx)
    local state = ctx.state
    local deps = ctx.deps
    local now = APISurface.now()

    -- Check enabled
    if not deps.config.menu.autoloot_enabled then return end
    if not deps.config.menu.autoloot_enabled:get_state() then return end

    -- Check bag space
    if deps.config.menu.autoloot_stop_bags_full then
        if deps.config.menu.autoloot_stop_bags_full:get_state() then
            local min_free = 2
            if deps.config.menu.autoloot_min_free_slots then
                min_free = deps.config.menu.autoloot_min_free_slots:get() or 2
            end
            local free_slots = APISurface.get_total_free_slots()
            if free_slots and free_slots <= min_free then
                if not state.autoloot.paused_bags_full then
                    state.autoloot.paused_bags_full = true
                    if deps.config.menu.debug and deps.config.menu.debug:get_state() then
                        print("[AutoLoot] Paused: bags full (" .. free_slots .. " free)")
                    end
                end
                return
            else
                state.autoloot.paused_bags_full = false
            end
        end
    end

    -- Check combat mode
    local combat_mode = 1 -- 1 = OOC only
    if deps.config.menu.autoloot_combat_mode then
        combat_mode = deps.config.menu.autoloot_combat_mode:get() or 1
    end
    if combat_mode == 1 then -- OOC only
        if is_in_combat_or_grace(ctx, now) then
            return
        end
    end
    -- combat_mode == 2 means "always" — no combat check

    -- Check burst protection: max loots per 10s window
    local max_loots_10s = 5
    if deps.config.menu.autoloot_max_per_10s then
        max_loots_10s = deps.config.menu.autoloot_max_per_10s:get() or 5
    end
    -- Reset sliding window
    if now - state.autoloot.window_start >= 10 then
        state.autoloot.window_start = now
        state.autoloot.loots_in_window = 0
    end
    if state.autoloot.loots_in_window >= max_loots_10s then
        return
    end

    -- Check retry deadline (waiting for loot delay)
    if state.autoloot.loot_deadline and now < state.autoloot.loot_deadline then
        return
    end
    state.autoloot.loot_deadline = nil

    -- Check close-loot deadline
    if state.autoloot.close_loot_deadline and now >= state.autoloot.close_loot_deadline then
        if core and core.input and core.input.close_loot then
            pcall(core.input.close_loot)
        end
        state.autoloot.close_loot_deadline = nil
    end

    -- Get player position
    local me = APISurface.get_local_player()
    if not me then return end
    local me_pos = APISurface.get_object_position(me)
    if not me_pos then return end

    -- Find lootable corpses
    local range = 30 -- Default loot range
    if deps.config.menu.autoloot_range then
        range = deps.config.menu.autoloot_range:get() or 30
    end
    local corpses, count = M.find_lootable_corpses(ctx, me_pos, range)
    if count == 0 then return end

    -- Sort by distance (closest first)
    table.sort(corpses, function(a, b) return a.dist_sq < b.dist_sq end)

    -- Try to loot the closest corpse
    for i = 1, count do
        local entry = corpses[i]
        -- Retry guard: don't try the same corpse too frequently
        local guid = entry.guid
        local should_skip = false
        if guid then
            local last_try = state.autoloot.retry_tracker[guid]
            if last_try and now - last_try < 0.5 then
                should_skip = true
            else
                state.autoloot.retry_tracker[guid] = now
            end
        end

        if not should_skip then
            local success = M.loot_corpse(ctx, entry, now)
            if success then
                break -- One corpse per tick
            end
        end
    end
end

return M
