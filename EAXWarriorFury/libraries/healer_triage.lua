local healer_triage = {}

local DEFAULTS = {
    tank_hp_threshold = 0.55,
    tank_incoming_cover_pct = 0.25,
    triage_hp_threshold = 0.35,
    covered_total_pct = 0.60,
    covered_incoming_pct = 0.30,
    group_hp_threshold = 0.55,
    group_count_threshold = 3,
    cancel_hp_threshold = 0.85,
    cancel_incoming_cover_pct = 0.50,
    emergency_hp_threshold = 0.25,
}

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

local function options(opts)
    local merged = {}
    for key, value in pairs(DEFAULTS) do
        merged[key] = value
    end
    for key, value in pairs(opts or {}) do
        merged[key] = value
    end
    return merged
end

local function snapshot(member, index)
    if type(member) ~= "table" then
        return nil
    end

    local raw_hp_pct = clamp01(member.raw_hp_pct or member.hp_pct)
    local eff_hp_pct = clamp01(member.eff_hp_pct or raw_hp_pct)
    local priority_hp_pct = clamp01(member.priority_hp_pct or eff_hp_pct)
    local incoming_heal_pct = clamp01(member.incoming_heal_pct)

    return {
        raw = member,
        index = index,
        guid = member.guid or tostring(index),
        target = member.unit or member,
        hp_pct = eff_hp_pct,
        raw_hp_pct = raw_hp_pct,
        eff_hp_pct = eff_hp_pct,
        priority_hp_pct = priority_hp_pct,
        incoming_heal_pct = incoming_heal_pct,
        role = member.role or (member.is_tank and "tank") or "unknown",
        is_tank = member.is_tank == true or member.role == "tank",
    }
end

local function compare_priority(a, b)
    if a.priority_hp_pct ~= b.priority_hp_pct then
        return a.priority_hp_pct < b.priority_hp_pct
    end
    if a.eff_hp_pct ~= b.eff_hp_pct then
        return a.eff_hp_pct < b.eff_hp_pct
    end
    if a.raw_hp_pct ~= b.raw_hp_pct then
        return a.raw_hp_pct < b.raw_hp_pct
    end
    if a.incoming_heal_pct ~= b.incoming_heal_pct then
        return a.incoming_heal_pct < b.incoming_heal_pct
    end
    if a.is_tank ~= b.is_tank then
        return a.is_tank == true
    end
    return tostring(a.guid) < tostring(b.guid)
end

local function is_covered(member, opts)
    return member.incoming_heal_pct >= opts.covered_incoming_pct
        or math.max(member.eff_hp_pct, member.raw_hp_pct + member.incoming_heal_pct) >= opts.covered_total_pct
end

local function build_summary(target, reason, group_count, opts)
    if not target then
        return {
            target = nil,
            target_guid = nil,
            reason = "covered_hold",
            emergency = false,
            covered_hold = true,
            group_count = group_count or 0,
            collapse_risk = (group_count or 0) >= opts.group_count_threshold,
        }
    end

    local collapse_risk = (group_count or 0) >= opts.group_count_threshold
    local emergency = reason == "tank_save"
        or reason == "group_stabilize"
        or target.hp_pct <= opts.emergency_hp_threshold

    return {
        target = target.target,
        target_guid = target.guid,
        target_snapshot = target.raw,
        reason = reason,
        emergency = emergency,
        covered_hold = false,
        group_count = group_count or 0,
        collapse_risk = collapse_risk,
        hp_pct = target.eff_hp_pct,
        raw_hp_pct = target.raw_hp_pct,
        eff_hp_pct = target.eff_hp_pct,
        priority_hp_pct = target.priority_hp_pct,
        incoming_heal_pct = target.incoming_heal_pct,
        is_tank = target.is_tank,
    }
end

function healer_triage.select_target(_, units, opts)
    opts = options(opts)
    units = units or {}

    local snapshots = {}
    local tank = nil
    local group_count = 0

    for index, member in ipairs(units) do
        local entry = snapshot(member, index)
        if entry then
            snapshots[#snapshots + 1] = entry
            if entry.is_tank and not tank then
                tank = entry
            end
            if entry.eff_hp_pct < opts.group_hp_threshold then
                group_count = group_count + 1
            end
        end
    end

    table.sort(snapshots, compare_priority)

    local lowest_uncovered = nil
    for _, member in ipairs(snapshots) do
        if member.eff_hp_pct < opts.triage_hp_threshold and not is_covered(member, opts) then
            lowest_uncovered = member
            break
        end
    end

    if tank
        and tank.eff_hp_pct <= opts.tank_hp_threshold
        and tank.incoming_heal_pct < opts.tank_incoming_cover_pct
    then
        if not lowest_uncovered or tank == lowest_uncovered then
            return build_summary(tank, "tank_save", group_count, opts)
        end
    end

    if group_count >= opts.group_count_threshold and lowest_uncovered then
        return build_summary(lowest_uncovered, "group_stabilize", group_count, opts)
    end

    if lowest_uncovered then
        return build_summary(lowest_uncovered, "triage_save", group_count, opts)
    end

    return build_summary(nil, "covered_hold", group_count, opts)
end

function healer_triage.should_cancel_overheal(target_snapshot, opts)
    opts = options(opts)
    target_snapshot = target_snapshot or {}
    local raw_hp_pct = clamp01(target_snapshot.raw_hp_pct or target_snapshot.hp_pct)
    local eff_hp_pct = clamp01(target_snapshot.eff_hp_pct or raw_hp_pct)
    local incoming_heal_pct = clamp01(target_snapshot.incoming_heal_pct)
    local collapse_risk = target_snapshot.collapse_risk == true or target_snapshot.group_count and target_snapshot.group_count >= opts.group_count_threshold

    return math.max(eff_hp_pct, raw_hp_pct + incoming_heal_pct) >= opts.cancel_hp_threshold
        and incoming_heal_pct >= opts.cancel_incoming_cover_pct
        and collapse_risk ~= true
end

function healer_triage.should_spend_emergency(summary, opts)
    opts = options(opts)
    summary = summary or {}
    if summary.reason == "group_stabilize" or summary.reason == "tank_save" then
        return true
    end

    local hp_pct = clamp01(summary.hp_pct or ((summary.target_snapshot or {}).hp_pct))
    local collapse_risk = summary.collapse_risk == true or (tonumber(summary.group_count) or 0) >= opts.group_count_threshold
    return collapse_risk or hp_pct <= opts.emergency_hp_threshold
end

return healer_triage
