-- targeting_sylvanas.lua -- shared Targeting System: enemy scoring + multi-target selection..
-- WHAT:   shared Targeting System: enemy scoring + multi-target selection.
-- WHEN:   called per-frame in spec build_state
-- WHY:    centralises threat/distance/HP-anomaly-based target scoring
-- SAFETY: bounded enemy scan; nil-guarded targets; static scoring table
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- Sticky target, raid marker priority, pull modes, enemy counting

local M = {}
local _G = _G
local NS = _G.EaxRotations
local _core_time = type(core) == "table" and type(core.time) == "function" and core.time or function() return 0 end
local _get_local_player = NS.GetPlayer or function()
    local om = core and core.object_manager
    if om and type(om.get_local_player) == "function" then
        local ok, p = pcall(om.get_local_player)
        if ok then return p end
    end
    return nil
end

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
    elseif mode == "party_combat" then
        -- A tank/party member has pulled: open up without being the puller.
        -- party_in_combat() excludes us, so ctx.in_combat covers our own pull.
        return ctx.in_combat or M.party_in_combat(ctx)
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
local _last_enemy_scan = 0
local _enemy_scan_interval = 0.5
local _cached_enemies = {}
local _cached_count = 0
local function get_enemies(range)
    if NS.GetEnemiesInRange then
        local list = NS.GetEnemiesInRange(range)
        if type(list) == "table" then return list, list.n or #list end
    end
    -- Fallback: scan visible objects (throttled to avoid per-frame API thrash)
    local now = _core_time()
    if now - _last_enemy_scan < _enemy_scan_interval then
        return _cached_enemies, _cached_count
    end
    if core and core.object_manager and type(core.object_manager.get_visible_objects) == "function" then
        local ok, list = pcall(core.object_manager.get_visible_objects)
        if ok and type(list) == "table" then
            _last_enemy_scan = now
            _cached_enemies = list
            _cached_count = #list
            return list, #list
        end
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
    local cap = math.min(#enemies, 50)
    for i = 1, cap do
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
-- AoE / Cleave target caps (TBC spell limits)
-- Closes parent become-1 Phase 2 item: "Cleave / AoE target caps (TBC-specific soft caps)"
-- Examples: Chain Heal (3), Prayer of Healing (5), Multi-Shot (3), many cleaves ~3-10.
-- Use in specs for accurate multi-target selection matching APL/sim behavior.
-- ============================================================================

local SPELL_AOE_CAPS = {
    -- Shaman
    [25423] = 3,   -- Chain Heal (max 3 hops)
    [25422] = 3,
    [10623] = 3,
    -- Priest
    [25308] = 5,   -- Prayer of Healing (5)
    [25316] = 5,
    [10961] = 5,
    [34866] = 5,   -- Circle of Healing (5)
    -- Hunter / others
    [14288] = 3,   -- Multi-Shot example ranks
    -- Warrior cleave etc. default to 10 or caller choice
}

--- Returns up to the TBC spell-specific cap of targets from a scored list.
--- @param entries table[] scored healing/enemy entries (sorted best first)
--- @param spell_id number|nil spell to look up cap for
--- @param fallback_max number|nil default if no specific cap (e.g. 10)
--- @return table capped_entries, number capped_count
function M.get_aoe_targets_with_cap(entries, spell_id, fallback_max)
    if not entries or #entries == 0 then return {}, 0 end
    local cap = SPELL_AOE_CAPS[spell_id] or fallback_max or 10
    local out = {}
    local n = math.min(#entries, cap)
    for i = 1, n do
        out[i] = entries[i]
    end
    return out, n
end

--- Convenience for common healer AoE (uses known caps).
function M.get_healer_aoe_capped(entries, spell_name_or_id)
    local id = type(spell_name_or_id) == "number" and spell_name_or_id or nil
    -- Fallback name map for convenience
    if not id and type(spell_name_or_id) == "string" then
        if spell_name_or_id:lower():find("chain") then id = 25423 end
        if spell_name_or_id:lower():find("prayer") then id = 25308 end
    end
    return M.get_aoe_targets_with_cap(entries, id, 5)
end


-- ============================================================================
-- Pull modes: party-combat aware
-- ============================================================================

--- True when anyone in our party/raid is fighting, even if we are not.
-- This is the signal the "party_combat" pull mode keys off: a tank has pulled
-- and the rotation should open up without us being the puller. Fail-closed when
-- no party list is available (solo play keeps the combat_only behavior).
--@param ctx table|nil
--@return boolean
function M.party_in_combat(ctx)
    -- context.party is produced by build_context every tick, so prefer it and
    -- fall back to a direct query outside a tick (tests / menu helpers).
    local members = ctx and ctx.party
    if type(members) ~= "table" then
        if NS.GetPartyMembers then
            local ok, list = pcall(NS.GetPartyMembers)
            if ok and type(list) == "table" then members = list end
        end
    end
    if type(members) ~= "table" then
        if NS.GetRaidMembers then
            local ok, list = pcall(NS.GetRaidMembers)
            if ok and type(list) == "table" then members = list end
        end
    end
    if type(members) ~= "table" then return false end
    local me = ctx and ctx.me or _get_local_player()
    for i = 1, #members do
        local member = members[i]
        if member and member ~= me and type(member.is_in_combat) == "function" then
            local ok, in_combat = pcall(member.is_in_combat, member)
            if ok and in_combat then return true end
        end
    end
    return false
end

-- ============================================================================
-- Override slots: seven user-pinned priority targets
-- ============================================================================
-- A player pins up to seven unit NAMES in settings (eax_override_target_1..7).
-- Slot order is priority order: slot 1 beats slot 2. A slot whose unit is not
-- currently visible/attackable is skipped, so a stale pin never blinds the
-- rotation. Resolution is name -> unit, cached briefly because a scan is not
-- cheap and the pin changes far less often than the tick rate.

M.OVERRIDE_SLOTS = 7

local _override_cache = {}        -- slot index -> { unit = unit, guid = guid, at = time }
local _OVERRIDE_TTL = 1.0

--- Name pinned in a given override slot, or nil when the slot is empty.
--@param index integer 1..M.OVERRIDE_SLOTS
--@return string|nil
function M.override_slot_name(index)
    if type(index) ~= "number" or index < 1 or index > M.OVERRIDE_SLOTS then return nil end
    if type(NS.get_setting) ~= "function" then return nil end
    local name = NS.get_setting("eax_override_target_" .. index, nil)
    if type(name) ~= "string" or name == "" then return nil end
    return name
end

--- True when at least one override slot is pinned.
function M.has_override()
    for i = 1, M.OVERRIDE_SLOTS do
        if M.override_slot_name(i) then return true end
    end
    return false
end

local function unit_name(unit)
    if not unit then return nil end
    if type(unit.get_name) == "function" then
        local ok, name = pcall(unit.get_name, unit)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return nil
end

--- Unit currently occupying the highest-priority occupied override slot.
-- Slots are scanned in priority order and the first one that resolves to a
-- live, attackable unit wins. Returns nil when nothing is pinned or nothing
-- pinned is reachable, so callers can fall through to normal selection.
--@param ctx table|nil
--@param range number|nil Scan range (default 40)
--@return game_object|nil
function M.override_target(ctx, range)
    if not M.has_override() then return nil end
    local me = ctx and ctx.me or _get_local_player()
    if not me then return nil end
    local now = _core_time()
    local enemies, enemy_count = get_enemies(range or 40)
    if enemy_count == 0 then return nil end
    for slot = 1, M.OVERRIDE_SLOTS do
        local wanted = M.override_slot_name(slot)
        if wanted then
            local hit = _override_cache[slot]
            if hit and hit.unit and type(hit.unit.is_valid) == "function" then
                local ok_valid, valid = pcall(hit.unit.is_valid, hit.unit)
                if ok_valid and valid and (now - hit.at) < _OVERRIDE_TTL then
                    return hit.unit
                end
            end
            for i = 1, enemy_count do
                local enemy = enemies[i]
                if enemy and unit_name(enemy) == wanted then
                    local ok_alive, alive = pcall(enemy.is_alive, enemy)
                    if not ok_alive or alive then
                        _override_cache[slot] = { unit = enemy, at = now }
                        return enemy
                    end
                end
            end
            _override_cache[slot] = nil
        end
    end
    return nil
end

--- Clear the override resolution cache (tests / settings change).
function M.reset_override_cache()
    _override_cache = {}
end


-- ============================================================================
-- Smart auto-targeting
-- ============================================================================
-- WHY:  the rotation can only act on a target the player selected. A player who
--       has not clicked anything gets a dead rotation, and a target that dies
--       mid-fight leaves the next cast targetless. This selects one.
-- MODES (setting eax_auto_target):
--   "off"    default -- never touch the player's selection: byte-for-byte the
--                       pre-existing behavior.
--   "assist" -- only while already in combat and only when the current target
--                       is missing or dead: rescues a fight, never starts one.
--   "auto"   -- also selects out of combat, but gated by the resolved pull mode
--                       so a "combat_only" player never gets a surprise pull.
-- SAFETY: opt-in (default off), one cached setting read per tick when off, a
--       throttled scan + set_target, never runs while casting/channelling,
--       never picks a tapped mob while leveling, and fails open when the engine
--       target API is absent (mock/older clients).

local _AUTO_TARGET_TTL = 0.5
local _auto_mode_cache = nil
local _auto_mode_at = 0
local _last_set_target = 0
local _SET_TARGET_MIN_INTERVAL = 0.5

local function cached_setting(key, default)
    if type(NS.get_setting) ~= "function" then return default end
    local ok, value = pcall(NS.get_setting, key, default)
    if not ok then return default end
    return value
end

--- Resolved auto-target mode ("off"/"assist"/"auto"), cached for 0.5s.
function M.auto_target_mode()
    local now = _core_time()
    if _auto_mode_cache ~= nil and (now - _auto_mode_at) < _AUTO_TARGET_TTL then
        return _auto_mode_cache
    end
    local mode = cached_setting("eax_auto_target", nil)
    if mode == true then mode = "assist" end
    if mode ~= "assist" and mode ~= "auto" then mode = "off" end
    _auto_mode_cache = mode
    _auto_mode_at = now
    return mode
end

--- Resolved pull mode, default "combat_only" (the pre-existing behavior).
function M.pull_mode()
    local mode = cached_setting("eax_pull_mode", "combat_only")
    if type(mode) ~= "string" then return "combat_only" end
    return mode
end

--- The player's current target when it is still valid and alive, else nil.
--@return game_object|nil
local function valid_current_target(ctx, me)
    local unit = ctx and ctx.target
    if not unit and me and type(me.get_target) == "function" then
        local ok, value = pcall(me.get_target, me)
        if ok then unit = value end
    end
    if not unit then return nil end
    local ok_valid, valid = pcall(unit.is_valid, unit)
    if ok_valid and valid == false then return nil end
    local ok_alive, alive = pcall(unit.is_alive, unit)
    if ok_alive and alive == false then return nil end
    return unit
end

--- Best target for the player right now, WITHOUT changing the selection.
-- Order: pinned override slot (priority 1..7), then the highest-priority raid
-- marker, then the nearest attackable enemy. Pure -- no engine writes.
--@param ctx table
--@param opts table|nil  max_distance
--@return game_object|nil
function M.select_target(ctx, opts)
    if not ctx then return nil end
    opts = opts or {}
    local pinned = M.override_target(ctx, opts.max_distance)
    if pinned then return pinned end
    return M.resolve_target(ctx, { prefer_marked = true, max_distance = opts.max_distance or 40 })
end

--- Per-tick hook. Selects a target when the mode allows it.
-- @return boolean true when the player's target was changed this tick.
function M.update(ctx)
    local mode = M.auto_target_mode()
    if mode == "off" then return false end
    if not ctx or not ctx.me then return false end
    if ctx.is_casting or ctx.is_channeling then return false end
    local me = ctx.me
    local in_combat = ctx.in_combat == true
    if mode == "assist" and not in_combat then return false end

    -- Out of combat, "auto" still respects the pull mode: a combat_only player
    -- must never have us grab a target for them.
    if mode == "auto" and not in_combat and not M.should_engage(M.pull_mode(), ctx) then
        return false
    end

    local chosen = M.select_target(ctx)
    if not chosen then return false end

    local current = valid_current_target(ctx, me)
    if current then
        -- Keep the player's own selection: only a pinned override outranks it.
        local pinned = M.override_target(ctx)
        local same = NS.same_unit or function(a, b) return a == b end
        if not (pinned and not same(pinned, current)) then return false end
        chosen = pinned
    end

    local now = _core_time()
    if (now - _last_set_target) < _SET_TARGET_MIN_INTERVAL then return false end
    local setter = core and core.input and core.input.set_target
    if type(setter) ~= "function" then return false end
    local ok = pcall(setter, chosen)
    if not ok then return false end
    _last_set_target = now
    return true
end

--- Reset the auto-target throttle/cache (tests, settings changes).
function M.reset_auto_target_state()
    _auto_mode_cache = nil
    _auto_mode_at = 0
    _last_set_target = 0
end

-- ============================================================================
-- Export
-- ============================================================================

NS.Targeting = M

return M
