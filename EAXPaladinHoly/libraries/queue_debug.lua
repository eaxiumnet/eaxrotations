-- EAX Paladin Holy - queue_debug.lua
-- Debug and monitor spell queue state
-- Provides introspection into spell queue for debugging and optimization

local queue_debug = {}

-- Hot-path API caching
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player

---@type spell_queue
local spell_queue = require("common/modules/spell_queue")

---@type izi_sdk
local izi = require("common/izi_sdk")

-- ============================================================================
-- QUEUE MONITORING STATE
-- ============================================================================

local queue_state = {
    history = {},
    max_history = 100,
    current_queue = {},
    stats = {
        total_queued = 0,
        total_cast = 0,
        total_failed = 0,
        total_cancelled = 0,
    },
    performance = {
        avg_queue_time = 0,
        max_queue_time = 0,
        min_queue_time = 999,
    },
    last_update = 0,
    update_interval = 0.1, -- 100ms
}

-- ============================================================================
-- QUEUE ENTRY TRACKING
-- ============================================================================

local function track_queue_entry(spell_id, target, priority, reason)
    local entry = {
        spell_id = spell_id,
        target = target,
        priority = priority,
        reason = reason,
        timestamp = _core_time(),
        status = "queued",
        cast_time = nil,
        fail_reason = nil,
    }
    
    table.insert(queue_state.current_queue, entry)
    queue_state.stats.total_queued = queue_state.stats.total_queued + 1
    
    -- Add to history
    table.insert(queue_state.history, 1, entry)
    if #queue_state.history > queue_state.max_history then
        table.remove(queue_state.history)
    end
    
    return entry
end

local function update_queue_entry(spell_id, status, data)
    for _, entry in ipairs(queue_state.current_queue) do
        if entry.spell_id == spell_id and entry.status == "queued" then
            entry.status = status
            
            if status == "cast" then
                entry.cast_time = _core_time()
                queue_state.stats.total_cast = queue_state.stats.total_cast + 1
                
                -- Calculate queue time
                local queue_time = entry.cast_time - entry.timestamp
                
                -- Update performance stats
                queue_state.performance.avg_queue_time = 
                    (queue_state.performance.avg_queue_time * (queue_state.stats.total_cast - 1) + queue_time) 
                    / queue_state.stats.total_cast
                
                queue_state.performance.max_queue_time = 
                    math.max(queue_state.performance.max_queue_time, queue_time)
                
                queue_state.performance.min_queue_time = 
                    math.min(queue_state.performance.min_queue_time, queue_time)
                    
            elseif status == "failed" then
                entry.fail_reason = data and data.reason or "unknown"
                queue_state.stats.total_failed = queue_state.stats.total_failed + 1
            elseif status == "cancelled" then
                queue_state.stats.total_cancelled = queue_state.stats.total_cancelled + 1
            end
            
            return true
        end
    end
    
    return false
end

local function cleanup_completed_entries()
    local active_entries = {}
    local now = _core_time()
    
    for _, entry in ipairs(queue_state.current_queue) do
        -- Keep entries that are still queued or recently completed
        if entry.status == "queued" then
            table.insert(active_entries, entry)
        elseif entry.cast_time and (now - entry.cast_time) < 5 then
            -- Keep completed entries for 5 seconds
            table.insert(active_entries, entry)
        end
    end
    
    queue_state.current_queue = active_entries
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

local function on_spell_cast_success(data)
    if not data or not data.spell_id then return end
    
    update_queue_entry(data.spell_id, "cast", {
        target = data.target,
        time = _core_time(),
    })
end

-- NOTE: on_spell_cast_fail() removed - izi.on_spell_fail() does not exist in IZI SDK
-- Spell failure tracking is not available. Only spell success events are supported.

local function init_event_listeners()
    -- Use IZI SDK for spell event tracking
    izi.on_spell_success(on_spell_cast_success)
    -- NOTE: izi.on_spell_fail() does not exist in IZI SDK - removed to prevent nil error
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function queue_debug.init()
    init_event_listeners()
end

function queue_debug.update()
    local now = _core_time()
    
    -- Throttle updates
    if (now - queue_state.last_update) < queue_state.update_interval then
        return
    end
    queue_state.last_update = now
    
    -- Cleanup old entries
    cleanup_completed_entries()
end

function queue_debug.track_spell(spell_id, target, priority, reason)
    return track_queue_entry(spell_id, target, priority, reason)
end

function queue_debug.get_current_queue()
    return queue_state.current_queue
end

function queue_debug.get_queue_count()
    local count = 0
    for _, entry in ipairs(queue_state.current_queue) do
        if entry.status == "queued" then
            count = count + 1
        end
    end
    return count
end

function queue_debug.is_queue_empty()
    return queue_debug.get_queue_count() == 0
end

function queue_debug.get_next_spell()
    for _, entry in ipairs(queue_state.current_queue) do
        if entry.status == "queued" then
            return entry
        end
    end
    return nil
end

function queue_debug.get_queue_stats()
    return {
        total_queued = queue_state.stats.total_queued,
        total_cast = queue_state.stats.total_cast,
        total_failed = queue_state.stats.total_failed,
        total_cancelled = queue_state.stats.total_cancelled,
        success_rate = queue_state.stats.total_queued > 0 
            and (queue_state.stats.total_cast / queue_state.stats.total_queued) * 100 
            or 0,
        current_size = queue_debug.get_queue_count(),
    }
end

function queue_debug.get_performance_stats()
    return {
        avg_queue_time = queue_state.performance.avg_queue_time,
        max_queue_time = queue_state.performance.max_queue_time,
        min_queue_time = queue_state.performance.min_queue_time ~= 999 
            and queue_state.performance.min_queue_time 
            or 0,
    }
end

function queue_debug.get_history(max_entries)
    max_entries = max_entries or 20
    local result = {}
    
    for i = 1, math.min(max_entries, #queue_state.history) do
        table.insert(result, queue_state.history[i])
    end
    
    return result
end

function queue_debug.get_recent_failures(count)
    count = count or 5
    local failures = {}
    
    for _, entry in ipairs(queue_state.history) do
        if entry.status == "failed" then
            table.insert(failures, entry)
            if #failures >= count then
                break
            end
        end
    end
    
    return failures
end

function queue_debug.get_spells_by_priority(priority)
    local result = {}
    
    for _, entry in ipairs(queue_state.current_queue) do
        if entry.priority == priority then
            table.insert(result, entry)
        end
    end
    
    return result
end

function queue_debug.get_queue_analysis()
    local analysis = {
        by_priority = {},
        by_status = {},
        by_reason = {},
    }
    
    for _, entry in ipairs(queue_state.current_queue) do
        -- By priority
        local p = entry.priority or 0
        analysis.by_priority[p] = (analysis.by_priority[p] or 0) + 1
        
        -- By status
        analysis.by_status[entry.status] = (analysis.by_status[entry.status] or 0) + 1
        
        -- By reason
        if entry.reason then
            analysis.by_reason[entry.reason] = (analysis.by_reason[entry.reason] or 0) + 1
        end
    end
    
    return analysis
end

function queue_debug.reset_stats()
    queue_state.stats = {
        total_queued = 0,
        total_cast = 0,
        total_failed = 0,
        total_cancelled = 0,
    }
    
    queue_state.performance = {
        avg_queue_time = 0,
        max_queue_time = 0,
        min_queue_time = 999,
    }
end

function queue_debug.clear_history()
    queue_state.history = {}
end

function queue_debug.clear_queue()
    queue_state.current_queue = {}
end

function queue_debug.get_spell_status(spell_id)
    for _, entry in ipairs(queue_state.current_queue) do
        if entry.spell_id == spell_id then
            return entry.status, entry
        end
    end
    
    return nil, nil
end

function queue_debug.is_spell_queued(spell_id)
    local status = queue_debug.get_spell_status(spell_id)
    return status == "queued"
end

function queue_debug.get_queue_depth_by_priority()
    local depths = {}
    
    for _, entry in ipairs(queue_state.current_queue) do
        if entry.status == "queued" then
            local p = entry.priority or 0
            depths[p] = (depths[p] or 0) + 1
        end
    end
    
    return depths
end

function queue_debug.get_average_priority()
    local total = 0
    local count = 0
    
    for _, entry in ipairs(queue_state.current_queue) do
        if entry.status == "queued" then
            total = total + (entry.priority or 0)
            count = count + 1
        end
    end
    
    if count == 0 then return 0 end
    return total / count
end

function queue_debug.generate_report()
    local stats = queue_debug.get_queue_stats()
    local perf = queue_debug.get_performance_stats()
    local analysis = queue_debug.get_queue_analysis()
    
    return {
        timestamp = _core_time(),
        stats = stats,
        performance = perf,
        analysis = analysis,
        current_queue_size = queue_debug.get_queue_count(),
        recent_failures = queue_debug.get_recent_failures(3),
    }
end

function queue_debug.log_report()
    local report = queue_debug.generate_report()
    
    core.log("[Queue Debug] Report at " .. tostring(report.timestamp))
    core.log("[Queue Debug] Stats - Queued: " .. report.stats.total_queued .. 
             ", Cast: " .. report.stats.total_cast .. 
             ", Failed: " .. report.stats.total_failed)
    core.log("[Queue Debug] Success Rate: " .. string.format("%.1f%%", report.stats.success_rate))
    core.log("[Queue Debug] Avg Queue Time: " .. string.format("%.3fs", report.performance.avg_queue_time))
    core.log("[Queue Debug] Current Queue Size: " .. report.current_queue_size)
    
    if #report.recent_failures > 0 then
        core.log("[Queue Debug] Recent Failures:")
        for _, failure in ipairs(report.recent_failures) do
            core.log("  - Spell " .. failure.spell_id .. ": " .. (failure.fail_reason or "unknown"))
        end
    end
end

function queue_debug.set_update_interval(interval)
    queue_state.update_interval = interval
end

function queue_debug.get_update_interval()
    return queue_state.update_interval
end

return queue_debug
