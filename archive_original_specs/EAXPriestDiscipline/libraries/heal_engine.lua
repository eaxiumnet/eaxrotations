-- heal_engine.lua
-- Shared healer friend scan with effective HP scoring for Project Sylvanas.

---@type unit_helper
local unit_helper = require("common/utility/unit_helper")
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

local heal_engine = {}

local ABSORB_SCALAR = 0.25
local SCAN_RANGE = 60.0
local BUILD_INTERVAL = 0.10

heal_engine.friends = {}

local last_build_time = 0
local tank_priority_weight = 0.08

local function clamp01(value)
    local n = tonumber(value) or 0
    if n < 0 then
        return 0
    end
    if n > 1 then
        return 1
    end
    return n
end

local function safe_number(unit, method_name)
    if not unit then
        return 0
    end

    local method = unit[method_name]
    if type(method) ~= "function" then
        return 0
    end

    local ok, value = pcall(method, unit)
    if not ok then
        return 0
    end

    return tonumber(value) or 0
end

local function safe_position(unit)
    if not unit then
        return nil
    end

    local method = unit.get_position
    if type(method) ~= "function" then
        return nil
    end

    local ok, value = pcall(method, unit)
    if ok then
        return value
    end

    return nil
end

function heal_engine.get_raw_hp_pct(unit)
    local max_hp = safe_number(unit, "get_max_health")
    if max_hp <= 0 then
        return 1.0
    end

    return clamp01(safe_number(unit, "get_health") / max_hp)
end

function heal_engine.get_incoming_heal_pct(unit)
    local max_hp = safe_number(unit, "get_max_health")
    if max_hp <= 0 then
        return 0
    end

    return clamp01(safe_number(unit, "get_incoming_heals") / max_hp)
end

function heal_engine.get_effective_hp_pct(unit)
    local max_hp = safe_number(unit, "get_max_health")
    if max_hp <= 0 then
        return 1.0
    end

    local current_hp = safe_number(unit, "get_health")
    local incoming_heals = safe_number(unit, "get_incoming_heals")
    local shields = safe_number(unit, "get_total_shield") * ABSORB_SCALAR
    local heal_absorbs = safe_number(unit, "get_total_heal_absorbs")
    local effective_hp = current_hp + incoming_heals + shields - heal_absorbs

    return clamp01(effective_hp / max_hp)
end

function heal_engine.get_priority_hp_pct(unit, is_tank)
    local effective_hp_pct = heal_engine.get_effective_hp_pct(unit)
    if is_tank then
        return clamp01(effective_hp_pct - tank_priority_weight)
    end
    return effective_hp_pct
end

function heal_engine.make_member(unit, opts)
    if not unit or not unit.is_valid or not unit:is_valid() or unit:is_dead() then
        return nil
    end

    opts = opts or {}
    local is_tank = opts.is_tank == true
    local raw_hp_pct = heal_engine.get_raw_hp_pct(unit)
    local eff_hp_pct = heal_engine.get_effective_hp_pct(unit)
    local priority_hp_pct = heal_engine.get_priority_hp_pct(unit, is_tank)

    return {
        guid = opts.guid,
        unit = unit,
        hp_pct = eff_hp_pct,
        raw_hp_pct = raw_hp_pct,
        eff_hp_pct = eff_hp_pct,
        priority_hp_pct = priority_hp_pct,
        incoming_heal_pct = heal_engine.get_incoming_heal_pct(unit),
        role = opts.role or (is_tank and "tank") or "damager",
        is_tank = is_tank,
    }
end

function heal_engine.make_snapshot(unit, opts)
    opts = opts or {}
    local is_tank = opts.is_tank == true
    return {
        hp_pct = heal_engine.get_effective_hp_pct(unit),
        raw_hp_pct = heal_engine.get_raw_hp_pct(unit),
        eff_hp_pct = heal_engine.get_effective_hp_pct(unit),
        priority_hp_pct = heal_engine.get_priority_hp_pct(unit, is_tank),
        incoming_heal_pct = heal_engine.get_incoming_heal_pct(unit),
        collapse_risk = opts.collapse_risk == true,
        group_count = tonumber(opts.group_count) or 0,
    }
end

local function compare_friends(a, b)
    local a_priority = tonumber(a and a.priority_hp_pct) or 1
    local b_priority = tonumber(b and b.priority_hp_pct) or 1
    if a_priority ~= b_priority then
        return a_priority < b_priority
    end

    local a_effective = tonumber(a and a.eff_hp_pct) or 1
    local b_effective = tonumber(b and b.eff_hp_pct) or 1
    if a_effective ~= b_effective then
        return a_effective < b_effective
    end

    local a_incoming = tonumber(a and a.incoming_heal_pct) or 0
    local b_incoming = tonumber(b and b.incoming_heal_pct) or 0
    return a_incoming < b_incoming
end

function heal_engine.update(me, opts)
    opts = opts or {}

    local now = core.time()
    local build_interval = tonumber(opts.build_interval_s) or BUILD_INTERVAL
    if opts.force ~= true and (now - last_build_time) < build_interval then
        return
    end
    last_build_time = now

    if opts.tank_priority_weight ~= nil then
        tank_priority_weight = (tonumber(opts.tank_priority_weight) or tank_priority_weight)
    end

    local friends = heal_engine.friends
    for i = #friends, 1, -1 do
        friends[i] = nil
    end

    if not me or type(me.get_position) ~= "function" then
        return
    end

    local allies = unit_helper:get_ally_list_around(
        me:get_position(),
        tonumber(opts.scan_range) or SCAN_RANGE,
        true,
        true
    ) or {}

    local count = 0
    for _, ally in ipairs(allies) do
        if ally and ally:is_valid() and not ally:is_dead() then
            local is_tank = unit_helper:is_tank(ally) == true
            local raw_hp_pct = heal_engine.get_raw_hp_pct(ally)
            local incoming_heal_pct = heal_engine.get_incoming_heal_pct(ally)
            local effective_hp_pct = heal_engine.get_effective_hp_pct(ally)
            local priority_hp_pct = heal_engine.get_priority_hp_pct(ally, is_tank)

            count = count + 1
            friends[count] = {
                unit = ally,
                hp_pct = raw_hp_pct,
                raw_hp_pct = raw_hp_pct,
                incoming_heal_pct = incoming_heal_pct,
                eff_hp_pct = effective_hp_pct,
                priority_hp_pct = priority_hp_pct,
                eff_pct = priority_hp_pct,
                is_tank = is_tank,
                role = is_tank and "tank" or "damager",
                pos = safe_position(ally),
            }
        end
    end

    table.sort(friends, compare_friends)
end

function heal_engine.lowest_friend()
    local entry = heal_engine.friends[1]
    return entry and entry.unit or nil
end

function heal_engine.lowest_tank()
    for _, entry in ipairs(heal_engine.friends) do
        if entry.is_tank then
            return entry.unit
        end
    end
    return nil
end

function heal_engine.count_below(threshold)
    threshold = clamp01(threshold or 1)
    local count = 0
    for _, entry in ipairs(heal_engine.friends) do
        if (entry.eff_pct or 1) <= threshold then
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
    if not unit then
        return 1.0
    end

    for _, entry in ipairs(heal_engine.friends) do
        if entry.unit == unit then
            return entry.eff_pct or 1.0
        end
    end

    return heal_engine.get_priority_hp_pct(unit, unit_helper:is_tank(unit) == true)
end

function heal_engine.find_without_buff(buff_id_table, max_pct, skip_tanks)
    max_pct = clamp01(max_pct or 1.0)
    for _, entry in ipairs(heal_engine.friends) do
        if (entry.eff_pct or 1) > max_pct then
            break
        end

        if not (skip_tanks and entry.is_tank) then
            local data = buff_manager:get_buff_data(entry.unit, buff_id_table)
            if not (data and data.is_active) then
                return entry.unit
            end
        end
    end
    return nil
end

function heal_engine.has_critical(threshold)
    local entry = heal_engine.friends[1]
    return entry ~= nil and (entry.eff_pct or 1) < clamp01(threshold or 0)
end

function heal_engine.cluster_center(n_targets)
    n_targets = n_targets or 3
    local sum_x, sum_y, sum_z, count = 0, 0, 0, 0
    for i, entry in ipairs(heal_engine.friends) do
        if i > n_targets then
            break
        end

        local pos = entry.pos
        if pos then
            sum_x = sum_x + pos.x
            sum_y = sum_y + pos.y
            sum_z = sum_z + pos.z
            count = count + 1
        end
    end

    if count == 0 then
        return nil
    end

    local cx, cy, cz = sum_x / count, sum_y / count, sum_z / count
    local vec3_g = rawget(_G, "vec3")
    if vec3_g and type(vec3_g.new) == "function" then
        local ok, result = pcall(vec3_g.new, cx, cy, cz)
        if ok and result then
            return result
        end
    end

    return { x = cx, y = cy, z = cz }
end

function heal_engine.set_tank_priority(weight_pct)
    tank_priority_weight = (tonumber(weight_pct) or 0) / 100.0
end

return heal_engine
