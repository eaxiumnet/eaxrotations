-- ============================================================================
-- Shared Helper: In-Combat Buff Refresh with Urgency Colors
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Default urgency thresholds (seconds remaining)
M.thresholds = {
    critical = 10,   -- Red: buff about to expire, refresh immediately
    warning = 30,    -- Yellow: buff expiring soon, plan refresh
    notice = 60,     -- White/Blue: buff fine, no action needed
}

-- Urgency color mapping
M.colors = {
    critical = "|cffff0000",  -- Red
    warning = "|cffffff00",   -- Yellow
    notice = "|cff00ff00",    -- Green
    missing = "|cffff0000",   -- Red (missing buff)
}

-- ============================================================================
-- Core Helpers
-- ============================================================================

function M.get_urgency(remains, thresholds)
    thresholds = thresholds or M.thresholds
    if not remains or remains <= 0 then
        return "critical", 0
    end
    if remains <= thresholds.critical then
        return "critical", remains
    end
    if remains <= thresholds.warning then
        return "warning", remains
    end
    return "notice", remains
end

function M.urgency_color(urgency)
    return M.colors[urgency] or "|cffffffff"
end

function M.format_time(seconds)
    if not seconds or seconds <= 0 then
        return "0s"
    end
    if seconds < 60 then
        return string.format("%.0fs", seconds)
    end
    return string.format("%.1fm", seconds / 60)
end

-- ============================================================================
-- Buff Refresh Decision
-- ============================================================================

function M.should_refresh_buff(remains, refresh_window, ttd, buff_duration)
    -- If buff is missing, always refresh (if we can afford it)
    if not remains or remains <= 0 then
        return true
    end
    -- If buff expires before refresh window, refresh now
    if remains <= refresh_window then
        -- Only refresh if target will live long enough to benefit
        if ttd and buff_duration then
            return ttd >= (buff_duration * 0.5)
        end
        return true
    end
    return false
end

-- ============================================================================
-- Player Buff Urgency Check
-- ============================================================================

function M.get_buff_urgency(player_unit, buff_ids, thresholds)
    if not player_unit or not buff_ids then
        return "missing", 0
    end
    local remains = NS.buff_remains(player_unit, buff_ids) or 0
    return M.get_urgency(remains, thresholds)
end

-- ============================================================================
-- Multiple Buff Tracking (for OOC or in-combat buff bars)
-- ============================================================================

function M.get_most_urgent_buff(player_unit, buff_list, thresholds)
    if not player_unit or not buff_list then
        return nil
    end
    local most_urgent = nil
    local highest_priority = 0
    for _, entry in ipairs(buff_list) do
        local remains = NS.buff_remains(player_unit, entry.buff) or 0
        local urgency, time_left = M.get_urgency(remains, thresholds)
        local priority = (entry.priority or 1)
        -- Critical urgency gets +10 priority boost
        if urgency == "critical" then
            priority = priority + 10
        elseif urgency == "warning" then
            priority = priority + 5
        end
        if priority > highest_priority then
            highest_priority = priority
            most_urgent = {
                name = entry.name,
                urgency = urgency,
                remains = time_left,
                color = M.urgency_color(urgency),
                spell = entry.spell,
            }
        end
    end
    return most_urgent
end

-- ============================================================================
-- TBC-Specific Buff Durations (for accurate pandemic calculations)
-- ============================================================================

M.TBC_BUFF_DURATIONS = {
    battle_shout = 120,
    mage_armor = 1800,
    molten_armor = 1800,
    inner_fire = 600,
    mark_of_the_wild = 1800,
    thorns = 600,
    power_word_fortitude = 1800,
    fel_armor = 1800,
    demon_armor = 1800,
    arcane_intellect = 1800,
    water_shield = 600,
    lightning_shield = 600,
}

-- ============================================================================
-- ============================================================================

if NS then
    NS.get_buff_urgency = M.get_buff_urgency
    NS.get_most_urgent_buff = M.get_most_urgent_buff
    NS.should_refresh_buff = M.should_refresh_buff
    NS.urgency_color = M.urgency_color
    NS.format_buff_time = M.format_time
    NS.BuffRefreshHelper = M
end

_G.BuffRefreshHelper = M
return M
