-- What: Non-rotation combat helper for EaxAutoQuester
-- When: Required by auto-questing logic to tag enemies for EaxRotations to kill
-- Why: Plugin-independent target acquisition — only sets target, never casts spells
-- Safety: No rotation API (no izi.spell); all functions nil-guarded via pcall
-- Decision: Standalone module (not EaxRotations), caches core API at load

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _get_local_player = core.object_manager.get_local_player
local _get_visible_objects = core.object_manager.get_visible_objects
local _set_target = core.input.set_target
local _use_item_target = core.input.use_item_target

-- Static table reuse for enemy scan (Pattern 4 from AGENTS.md)
local _enemies = { n = 0 }

-- Hoisted unit probes. Every one of these was an inline `pcall(function() ... end)`, which built
-- a closure on each call: two of them on every frame (auto_face_enemy's no-target path, which
-- main.lua's on_pre_tick reaches) and the rest on each combat scan.
local function unit_get_target(u) return u:get_target() end
local function unit_is_alive(u) return u:is_alive() end
local function unit_is_player(u) return u:is_player() end
local function unit_is_enemy_with(u, other) return u:is_enemy_with(other) end
local function unit_get_position(u) return u:get_position() end
local function unit_is_in_combat(u) return u:is_in_combat() end
local function unit_get_class(u) return u:get_class() end

-- ============================================================================
-- Squared Distance — local copy avoids cross-module dep (Pattern 3)
-- ============================================================================

--- Compute squared 3D distance between two vec3 points.
--- @param a table|nil Point A with fields x, y, z
--- @param b table|nil Point B with fields x, y, z
--- @return number Squared distance (0 if either point is nil)
local function squared_distance(a, b)
    if not a or not b then return 0 end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    local dz = (a.z or 0) - (b.z or 0)
    return dx * dx + dy * dy + dz * dz
end

-- ============================================================================
-- Target Acquisition
-- ============================================================================

--- Find and target the nearest enemy within range.
--- Returns true if a target was set, false otherwise.
--- Scan capped at 50 objects. Uses squared distance (no math.sqrt).
--- @param range number Maximum distance in yards
--- @return boolean target_set
local function target_and_tag_nearest(range)
    local me = _get_local_player()
    if not me then return false end

    local range_sq = (range or 10) * (range or 10)
    local me_pos = me.get_position and me:get_position()
    if not me_pos then return false end

    local ok, objects = pcall(_get_visible_objects)
    if not ok or not objects then return false end

    -- Reuse static table for enemy list
    _enemies.n = 0

    -- Numeric loop rather than ipairs: the visible-objects list is sparse, and
    -- ipairs stops at the first nil hole, silently hiding every enemy after it.
    local limit = #objects
    if limit > 50 then limit = 50 end

    for i = 1, limit do
        local obj = objects[i]

        -- Must be a unit, not dead, not the player
        if obj and obj.is_unit and obj:is_unit() then
            if not obj.is_dead or not obj:is_dead() then
                if obj.is_enemy_with and obj:is_enemy_with(me) then
                    -- Pull prevention: only skip a mob CONFIRMED to be fighting
                    -- another player. obj:get_target() is not present on every
                    -- build, and the old code read the pcall FAILURE as "this mob
                    -- has a target" and then never added it — so no target was
                    -- ever acquired whenever that call was unavailable.
                    local engaged_by_other = false
                    local tgt_ok, e_target = pcall(unit_get_target, obj)
                    if tgt_ok and e_target and e_target ~= me then
                        local e_ok, e_is_player = pcall(unit_is_player, e_target)
                        if e_ok and e_is_player then
                            engaged_by_other = true
                        end
                    end

                    if not engaged_by_other then
                        _enemies.n = _enemies.n + 1
                        _enemies[_enemies.n] = obj
                    end
                end
            end
        end
    end

    -- Find nearest valid enemy
    local nearest = nil
    local nearest_sq = range_sq

    for i = 1, _enemies.n do
        local obj = _enemies[i]
        local pos = obj.get_position and obj:get_position()
        if pos then
            local dist_sq = squared_distance(me_pos, pos)
            if dist_sq < nearest_sq then
                nearest = obj
                nearest_sq = dist_sq
            end
        end
    end

    if not nearest then return false end

    -- Set as target, interact to start combat, and face it
    local ok, result = pcall(_set_target, nearest)
    if not ok then return false end
    pcall(core.input.interact_with_object, nearest)
    local _, npos = pcall(unit_get_position, nearest)
    if npos then pcall(core.input.look_at_3d, npos) end
    return result == true
end

-- ============================================================================
-- Target Validity
-- ============================================================================

--- Check if the current target is valid for combat (alive, enemy, in range).
--- Health percentage computed from raw values (no API call for hp_pct).
--- @param range number|nil Maximum distance in yards (default: 30)
--- @return boolean is_valid
local function is_current_target_valid(range)
    local me = _get_local_player()
    if not me then return false end

    local target = me.get_target and me:get_target()
    if not target then return false end

    -- Must be alive (not dead)
    if target.is_dead and target:is_dead() then return false end

    -- Must be an enemy
    if not target.is_enemy_with or not target:is_enemy_with(me) then return false end

    -- Must be in range (optional check)
    if range and range > 0 then
        local me_pos = me.get_position and me:get_position()
        local t_pos = target.get_position and target:get_position()
        if me_pos and t_pos then
            local range_sq = range * range
            if squared_distance(me_pos, t_pos) > range_sq then return false end
        end
    end

    return true
end

-- ============================================================================
-- Quest Item Usage
-- ============================================================================

--- Use a quest item on the current target.
--- Returns true if the item was used, false otherwise.
--- @param item_id number The item ID to use
--- @return boolean used
local function use_quest_item_on_target(item_id)
    if not item_id then return false end

    local me = _get_local_player()
    if not me then return false end

    local target = me.get_target and me:get_target()
    if not target then return false end

    -- Must be alive (can't use item on corpse)
    if target.is_dead and target:is_dead() then return false end

    -- Use item on target
    local ok, result = pcall(_use_item_target, item_id, target)
    if not ok then return false end
    return result == true
end

-- ============================================================================
-- Auto-Face Enemy — face nearest attackable enemy when in combat
-- ============================================================================

--- Auto-face the nearest enemy targeting the player when in combat.
--- Sets the nearest attackable enemy as target (client auto-faces on target change).
--- Uses the same scan pattern as target_and_tag_nearest.
--- @return boolean true if an enemy was targeted
local function auto_face_enemy()
    local me = _get_local_player()
    if not me then return false end

    -- Face any valid enemy target, even before combat starts (kill goal may have tagged it)
    local target_ok, target = pcall(unit_get_target, me)
    if target_ok and target then
        local alive_ok, alive = pcall(unit_is_alive, target)
        if alive_ok and alive then
            local enemy_ok, is_enemy = pcall(unit_is_enemy_with, target, me)
            if enemy_ok and is_enemy then
                local _, tpos = pcall(unit_get_position, target)
                if tpos then
                    pcall(core.input.look_at_3d, tpos)
                    -- NO turn-key jitter here. core.input.turn_left_start / turn_right_start START a
                    -- turn that only the matching *_stop ends (scraped_docs_md/dev/api/input.md), and
                    -- this call had no matching stop anywhere in the plugin: it began rotating the
                    -- player on a random 1-in-3 roll at the first enemy contact and never stopped
                    -- (live: "I'm spinning around in circles"). If robotic precision ever needs
                    -- hiding, jitter the look TARGET; never hold a turn key.
                end
                return true
            end
        end
    end

    -- No target — find and tag nearest enemy only if in combat
    local combat_ok, in_combat = pcall(unit_is_in_combat, me)
    if not combat_ok or not in_combat then return false end

    return target_and_tag_nearest(30)
end

-- ============================================================================
-- Engagement Distance — where the bot stops walking and lets the rotation fight
-- ============================================================================

-- The quester does not know a class's spells, so it decides the stand-off distance from
-- the class: classes whose damage comes from range stop OUTSIDE melee reach and initiate
-- at that distance, everything else keeps closing as before.
--
-- Why this exists: the approach code walked every class to melee (3yd) and then called
-- NS.start_auto_attack(target) with no attack type, which selects AUTO_ATTACK_MELEE — so a
-- priest questing was walked into the mob's face and made to auto-attack it, instead of
-- stopping at casting range and letting the priest rotation (which wants the target at
-- range, and wands as its own fallback) fight.
local ENGAGE_RANGED_YDS = 28   -- casters: inside a 30yd cast reach, outside mob melee reach (~5yd)
local ENGAGE_HUNTER_YDS = 35   -- hunter ranged attacks reach 35yd; its dead zone is 5-8yd, not 30
local ENGAGE_MELEE_YDS = 3

-- Stand-off per ranged class, in yards. Hunter is the only class whose weapon reaches past 30yd,
-- so it is the only one that may stand outside a caster's reach — the point is to fight at the
-- class's OWN maximum range, not at one number for everyone. Priest/mage/warlock stop short of
-- their 30yd casts: standing further out would mean never being able to cast at all (a 36yd
-- stand-off leaves a caster with nothing in range), which is why the caster value is 28 and not
-- the 36 a hunter-style range would suggest.
-- Hybrids (shaman, druid) stay melee: their melee forms and auto-attacks need contact, and the
-- quester cannot see which spec the rotation is running.
local RANGED_CLASS_YDS = {
    [3] = ENGAGE_HUNTER_YDS,  -- HUNTER
    [5] = ENGAGE_RANGED_YDS,  -- PRIEST
    [8] = ENGAGE_RANGED_YDS,  -- MAGE
    [9] = ENGAGE_RANGED_YDS,  -- WARLOCK
}

--- Stand-off distance for this player's class, or nil when the class fights in melee.
--- @param me game_object|nil
--- @return number|nil yards
local function ranged_engage_yds(me)
    if not me then return nil end
    local ok, class_id = pcall(unit_get_class, me)
    if not ok or not class_id then return nil end
    return RANGED_CLASS_YDS[class_id]
end

--- Is this player's class one that fights from range?
--- @param me game_object|nil
--- @return boolean ranged
local function is_ranged_class(me)
    return ranged_engage_yds(me) ~= nil
end

--- Squared distance at which the bot should stop approaching an enemy.
--- Ranged classes stop at their own attack range; everyone else keeps walking to melee.
--- @param me game_object|nil
--- @return number squared_yards
local function engage_distance_sq(me)
    local yds = ranged_engage_yds(me)
    if yds then return yds * yds end
    return ENGAGE_MELEE_YDS * ENGAGE_MELEE_YDS
end

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {
    target_and_tag_nearest = target_and_tag_nearest,
    is_current_target_valid = is_current_target_valid,
    use_quest_item_on_target = use_quest_item_on_target,
    auto_face_enemy = auto_face_enemy,
    is_ranged_class = is_ranged_class,
    ranged_engage_yds = ranged_engage_yds,
    engage_distance_sq = engage_distance_sq,
    ENGAGE_RANGED_YDS = ENGAGE_RANGED_YDS,
    ENGAGE_HUNTER_YDS = ENGAGE_HUNTER_YDS,
}

-- Expose globally for cross-module access without re-require
_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.combat_helper = M

return M
