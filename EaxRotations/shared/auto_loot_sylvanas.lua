-- =============================================================================
-- shared/auto_loot_sylvanas.lua — Auto-Loot for EaxRotations (v1.0)
-- WHAT:  Automatically loots nearby corpses between combat casts.
-- WHEN:  Enabled via menu; runs during on_rotation_update when not casting.
-- WHY:   Grinding/leveling specs spend significant time looting. Automating it
--        with humanized timing improves XP/hr without robotic patterns.
-- SAFETY: pcall-wrapped all API calls; respects OOC-only mode; won't cast during
--         GCD or channeling; bag-full pause; player-corpse skip. No banned APIs.
-- =============================================================================

local M = {}

-- ── Static tables (reused every tick) ───────────────────────────────────────
local _nearby_corpses = { n = 0 }
local _corpse_blacklist = {} -- guid -> blacklist_until_time
local _loot_window = { start = 0, count = 0 }

-- ── Config defaults ─────────────────────────────────────────────────────────
M.DEFAULTS = {
    enabled = false,
    combat_mode = 1,        -- 1 = OOC only, 2 = always
    grace_period = 2,       -- seconds after combat ends
    delay_min_ms = 50,      -- min random delay before loot
    delay_max_ms = 200,     -- max random delay before loot
    max_per_10s = 5,        -- burst protection cap
    skip_players = true,    -- skip player corpses
    stop_bags_full = true,  -- pause when bags near full
    min_free_slots = 2,     -- pause threshold
    range = 30,             -- scan range in yards
}

-- ── Menu IDs (for NS.get_setting) ──────────────────────────────────────────
M.SETTINGS = {
    enabled = "eax_autoloot_enabled",
    combat_mode = "eax_autoloot_combat_mode",
    grace_period = "eax_autoloot_grace",
    delay_min = "eax_autoloot_delay_min",
    delay_max = "eax_autoloot_delay_max",
    max_per_10s = "eax_autoloot_max_burst",
    skip_players = "eax_autoloot_skip_players",
    stop_bags_full = "eax_autoloot_stop_full",
    min_free = "eax_autoloot_min_free",
    range = "eax_autoloot_range",
}

-- ── Helpers ─────────────────────────────────────────────────────────────────

local function get_setting(key, fallback)
    if NS and NS.get_setting then
        local ok, val = pcall(NS.get_setting, key, fallback)
        if ok and val ~= nil then return val end
    end
    return fallback
end

local function is_player_corpse(obj)
    if not obj then return false end
    local ok_type, utype = pcall(function()
        if obj.get_unit_type then return obj:get_unit_type() end
        if obj.unit_type then return obj:unit_type() end
        return nil
    end)
    if ok_type and utype == "player" then return true end
    return false
end

local function can_loot(obj)
    if not obj then return false end
    local ok, lootable = pcall(function()
        if obj.is_lootable then return obj:is_lootable() end
        if obj.lootable then return obj:lootable() end
        return nil
    end)
    if ok and lootable == true then return true end
    -- Fallback: dead units are potentially lootable
    local ok_dead, dead = pcall(function()
        if obj.is_dead then return obj:is_dead() end
        return nil
    end)
    return ok_dead and dead == true
end

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

-- ── Session state (persisted across ticks) ──────────────────────────────────
M.stats = {
    corpses_looted = 0,
    last_loot_time = 0,
    last_corpse_name = nil,
    paused_bags_full = false,
    last_combat_end = nil,
    loot_deadline = 0,
    close_loot_deadline = 0,
}

-- ── Core: scan for lootable corpses ─────────────────────────────────────────
function M.find_corpses(me, me_pos, range)
    _nearby_corpses.n = 0
    if not me or not me_pos then return _nearby_corpses, 0 end

    local range_sq = range * range
    local now = NS.time_now and NS.time_now() or 0
    local skip_players = get_setting(M.SETTINGS.skip_players, M.DEFAULTS.skip_players)

    local objects = nil
    if core and core.object_manager and core.object_manager.get_all_objects then
        local ok, result = pcall(core.object_manager.get_all_objects)
        if ok then objects = result end
    end
    if not objects then return _nearby_corpses, 0 end

    for _, obj in ipairs(objects) do
        if obj then
            local valid = false
            local ok_v = pcall(function()
                if obj.is_valid then valid = obj:is_valid() end
            end)
            if ok_v and valid then
                -- Blacklist check
                local guid = nil
                pcall(function()
                    if obj.get_guid then guid = obj:get_guid() end
                    if not guid and obj.guid then guid = obj:guid() end
                end)
                if guid then
                    local until_time = _corpse_blacklist[guid]
                    if until_time and now < until_time then
                        -- skip blacklisted
                    else
                        local dsq = dist_sq_to_corpse(me_pos, obj)
                        if dsq <= range_sq then
                            if not (skip_players and is_player_corpse(obj)) then
                                if can_loot(obj) then
                                    _nearby_corpses.n = _nearby_corpses.n + 1
                                    _nearby_corpses[_nearby_corpses.n] = { obj = obj, guid = guid, dist_sq = dsq }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return _nearby_corpses, _nearby_corpses.n
end

-- ── Core: loot a single corpse ──────────────────────────────────────────────
function M.loot_corpse(entry, now)
    local obj = entry.obj
    local min_d = get_setting(M.SETTINGS.delay_min, M.DEFAULTS.delay_min_ms)
    local max_d = get_setting(M.SETTINGS.delay_max, M.DEFAULTS.delay_max_ms)
    local delay = min_d + math.random() * (max_d - min_d)

    if delay > 0 and now < M.stats.loot_deadline then
        return false -- waiting for delay
    end
    M.stats.loot_deadline = 0

    local ok = false
    if core and core.input and core.input.loot_object then
        ok = pcall(core.input.loot_object, obj)
    end

    if ok then
        M.stats.corpses_looted = M.stats.corpses_looted + 1
        M.stats.last_loot_time = now
        _loot_window.count = _loot_window.count + 1
        pcall(function()
            if obj.get_name then M.stats.last_corpse_name = obj:get_name() end
        end)
        M.stats.close_loot_deadline = now + 0.3 + math.random() * 0.5
        return true
    else
        if entry.guid then
            _corpse_blacklist[entry.guid] = now + 5
        end
        return false
    end
end

-- ── Main: called from main_sylvanas.lua on_rotation_update ──────────────────
function M.on_tick(context)
    if not get_setting(M.SETTINGS.enabled, M.DEFAULTS.enabled) then
        return
    end

    local now = NS.time_now and NS.time_now() or 0
    local me = context and context.me
    if not me then return end

    -- Don't loot while casting/channeling (combat priority)
    if context.is_casting or context.is_channeling then return end
    if context.on_gcd then return end

    -- Bag space check
    if get_setting(M.SETTINGS.stop_bags_full, M.DEFAULTS.stop_bags_full) then
        local min_free = get_setting(M.SETTINGS.min_free, M.DEFAULTS.min_free_slots)
        local free = nil
        if core and core.inventory and core.inventory.get_total_free_slots then
            local ok, result = pcall(core.inventory.get_total_free_slots)
            if ok then free = result end
        end
        if free and free <= min_free then
            if not M.stats.paused_bags_full then
                M.stats.paused_bags_full = true
                if NS.log then NS.log("[AutoLoot] Paused: bags full (" .. free .. " free)") end
            end
            return
        else
            M.stats.paused_bags_full = false
        end
    end

    -- Combat mode check
    local combat_mode = get_setting(M.SETTINGS.combat_mode, M.DEFAULTS.combat_mode)
    if combat_mode == 1 then -- OOC only
        if context.in_combat then
            M.stats.last_combat_end = nil
            return
        end
        -- Post-combat grace
        if M.stats.last_combat_end then
            local grace = get_setting(M.SETTINGS.grace_period, M.DEFAULTS.grace_period)
            if now < M.stats.last_combat_end + grace then
                return
            end
            M.stats.last_combat_end = nil
        end
    end

    -- Burst protection: sliding 10s window
    local max_10s = get_setting(M.SETTINGS.max_per_10s, M.DEFAULTS.max_per_10s)
    if now - _loot_window.start >= 10 then
        _loot_window.start = now
        _loot_window.count = 0
    end
    if _loot_window.count >= max_10s then
        return
    end

    -- Close loot window deadline
    if M.stats.close_loot_deadline > 0 and now >= M.stats.close_loot_deadline then
        if core and core.input and core.input.close_loot then
            pcall(core.input.close_loot)
        end
        M.stats.close_loot_deadline = 0
    end

    -- Delay deadline
    if M.stats.loot_deadline > 0 and now < M.stats.loot_deadline then
        return
    end
    M.stats.loot_deadline = 0

    -- Get position
    local me_pos = nil
    pcall(function()
        if me.get_position then me_pos = me:get_position() end
    end)
    if not me_pos then return end

    -- Find corpses
    local range = get_setting(M.SETTINGS.range, M.DEFAULTS.range)
    local corpses, count = M.find_corpses(me, me_pos, range)
    if count == 0 then return end

    -- Sort by distance
    table.sort(corpses, function(a, b) return a.dist_sq < b.dist_sq end)

    -- Try closest corpse
    for i = 1, count do
        local entry = corpses[i]
        local guid = entry.guid
        if guid then
            -- 500ms retry guard
            local last_try = M.stats[guid .. "_retry"]
            if last_try and now - last_try < 0.5 then
                -- skip
            else
                M.stats[guid .. "_retry"] = now
                local success = M.loot_corpse(entry, now)
                if success then break end
            end
        else
            local success = M.loot_corpse(entry, now)
local spec_kit = require("shared/spec_kit_sylvanas")
            if success then break end
        end
    end
end

-- ── Reset (called on disable / reload) ──────────────────────────────────────
function M.reset()
    M.stats.corpses_looted = 0
    M.stats.last_loot_time = 0
    M.stats.last_corpse_name = nil
    M.stats.paused_bags_full = false
    M.stats.last_combat_end = nil
    M.stats.loot_deadline = 0
    M.stats.close_loot_deadline = 0
    _loot_window.start = 0
    _loot_window.count = 0
    for k in pairs(_corpse_blacklist) do _corpse_blacklist[k] = nil end
    for k in pairs(M.stats) do
        if type(k) == "string" and k:find("_retry$") then
            M.stats[k] = nil
        end
    end
end

-- ── Export ──────────────────────────────────────────────────────────────────
return M