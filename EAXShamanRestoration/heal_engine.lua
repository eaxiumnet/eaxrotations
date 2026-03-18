-- heal_engine.lua
-- EAX Shaman Restoration | Pre-sorted friend table with effective HP scoring
--
-- Builds one cached list per tick. All rotation decisions query this module
-- instead of calling unit_helper:get_ally_list_around independently.
--
-- Effective HP formula (from BadRotations CalcHP):
--   eff_hp  = raw_hp + incoming_heals + (absorb_shield * ABSORB_SCALAR) - heal_absorbs
--   eff_pct = eff_hp / max_hp                              (clamped 0–1)
--   Tanks get a configurable priority weight subtracted from eff_pct so they
--   sort toward the top of the list even when tied with DPS at equal raw HP.
--
-- Derived queries (all O(1) after the build pass):
--   heal_engine.friends             -- sorted table, index 1 = most critical
--   heal_engine.lowest_friend()     -- unit with lowest eff_pct
--   heal_engine.lowest_tank()       -- tank with lowest eff_pct, or nil
--   heal_engine.count_below(pct)    -- number of friends with eff_pct <= pct
--   heal_engine.size()              -- total healable friends
--   heal_engine.get_eff_pct(unit)   -- eff_pct for a specific unit, or 1.0

---@type unit_helper
local unit_helper = require("common/utility/unit_helper")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local ABSORB_SCALAR = 0.25    -- count 25% of absorb shield (can be stripped)
local SCAN_RANGE    = 60.0    -- yards; covers 40-man raid spread

local heal_engine   = {}

-- ─── Internal state ──────────────────────────────────────────────────────────

heal_engine.friends = {}          -- pre-allocated, reused each tick
local last_build_time = 0
local BUILD_INTERVAL  = 0.1       -- rebuild at most every 100 ms

local tank_priority_weight = 0.08 -- set dynamically from menu slider

-- ─── Effective HP calculation ────────────────────────────────────────────────
--
-- Uses the three Sylvanas game_object accessors:
--   unit:get_incoming_heals()     → heals already in flight
--   unit:get_total_shield()       → absorb shield total
--   unit:get_total_heal_absorbs() → negative modifier on incoming heals

local function calc_eff_pct(unit, is_tank)
    local hp     = unit:get_health()
    local max_hp = unit:get_max_health()
    if not max_hp or max_hp <= 0 then return 0 end

    local incoming    = unit:get_incoming_heals()   or 0
    local shield      = (unit:get_total_shield()    or 0) * ABSORB_SCALAR
    local heal_absorb = unit:get_total_heal_absorbs() or 0

    local eff_pct = (hp + incoming + shield - heal_absorb) / max_hp

    if is_tank then
        eff_pct = eff_pct - tank_priority_weight
    end

    if eff_pct < 0 then eff_pct = 0 end
    if eff_pct > 1 then eff_pct = 1 end
    return eff_pct
end

-- ─── Build pass ──────────────────────────────────────────────────────────────

function heal_engine.update(me)
    local now = core.time()
    if (now - last_build_time) < BUILD_INTERVAL then return end
    last_build_time = now

    local friends = heal_engine.friends
    for i = #friends, 1, -1 do friends[i] = nil end

    local allies = unit_helper:get_ally_list_around(
        me:get_position(), SCAN_RANGE, true, true)

    local n = 0
    for _, ally in ipairs(allies) do
        if ally and ally:is_valid() and not ally:is_dead() then
            local is_tank = unit_helper:is_tank(ally)
            n = n + 1
            friends[n] = {
                unit    = ally,
                eff_pct = calc_eff_pct(ally, is_tank),
                is_tank = is_tank,
                pos     = ally:get_position(),
            }
        end
    end

    table.sort(friends, function(a, b)
        return a.eff_pct < b.eff_pct
    end)
end

-- ─── Derived queries ─────────────────────────────────────────────────────────

function heal_engine.lowest_friend()
    local entry = heal_engine.friends[1]
    return entry and entry.unit or nil
end

function heal_engine.lowest_tank()
    for _, entry in ipairs(heal_engine.friends) do
        if entry.is_tank then return entry.unit end
    end
    return nil
end

function heal_engine.count_below(threshold)
    local count = 0
    for _, entry in ipairs(heal_engine.friends) do
        if entry.eff_pct <= threshold then
            count = count + 1
        else
            break
        end
    end
    return count
end

function heal_engine.size()
    return #heal_engine.friends
end

function heal_engine.get_eff_pct(unit)
    if not unit then return 1.0 end
    for _, entry in ipairs(heal_engine.friends) do
        if entry.unit == unit then return entry.eff_pct end
    end
    return 1.0
end

-- Returns the first friend that does NOT have the given buff (by id_table),
-- with eff_pct <= max_pct.  skip_tanks = true to skip over tank entries.
function heal_engine.find_without_buff(buff_id_table, max_pct, skip_tanks)
    max_pct = max_pct or 1.0
    for _, entry in ipairs(heal_engine.friends) do
        if entry.eff_pct > max_pct then break end
        if not (skip_tanks and entry.is_tank) then
            local data = entry.buff_manager:get_buff_data(unit, buff_id_table)
            if not (data and data.is_active) then
                return entry.unit
            end
        end
    end
    return nil
end

-- Returns true if any friend is below eff_pct < threshold.
function heal_engine.has_critical(threshold)
    local entry = heal_engine.friends[1]
    return entry ~= nil and entry.eff_pct < threshold
end

-- Returns the centroid position of the N most-injured friends as a vec3.
-- Used for Healing Rain placement.
-- vec3 is a Sylvanas runtime global - accessed via rawget to avoid errors
-- if it isn't available on a given server build.
function heal_engine.cluster_center(n_targets)
    n_targets = n_targets or 3
    local sum_x, sum_y, sum_z, count = 0, 0, 0, 0
    for i, entry in ipairs(heal_engine.friends) do
        if i > n_targets then break end
        local p = entry.pos
        if p then
            sum_x = sum_x + p.x
            sum_y = sum_y + p.y
            sum_z = sum_z + p.z
            count = count + 1
        end
    end
    if count == 0 then return nil end
    local cx, cy, cz = sum_x / count, sum_y / count, sum_z / count
    -- vec3 is injected as a global by the Sylvanas runtime
    local vec3_g = rawget(_G, "vec3")
    if vec3_g and type(vec3_g.new) == "function" then
        local ok, result = pcall(vec3_g.new, cx, cy, cz)
        if ok and result then return result end
    end
    -- Fallback: plain table with .x/.y/.z fields (accepted by queue_spell_position)
    return { x = cx, y = cy, z = cz }
end

-- Set tank priority weight from the menu slider (0–25%)
function heal_engine.set_tank_priority(weight_pct)
    tank_priority_weight = weight_pct / 100.0
end

return heal_engine
