-- hunter_clip_tracker.lua | Hunter Auto Shot Clip Tracker | TBC
-- Ported from Flux AIO - tracks auto shot clipping with severity analysis
--
-- Features:
--   - Real-time auto-shot clip detection
--   - Severity analysis (green/yellow/orange/red)
--   - Combat summaries with export
--   - Categorizes clips by cause (movement, melee, casts)

local hunter_clip_tracker = {}

-- ============================================================================
-- API CACHING (Sylvanas API)
-- ============================================================================
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_spell_info = core.spell_book.get_spell_info
local _get_spell_cast_count = core.spell_book.get_spell_cast_count
local _format = string.format

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local AUTO_SHOT_SPELL_ID = 75
local AUTO_SHOT_SPELL_NAME = "Auto Shot"

-- Melee-only spells that prove the player was in melee range
local MELEE_SPELL_NAMES = {
    ["Raptor Strike"] = true,
    ["Mongoose Bite"] = true,
    ["Wing Clip"] = true,
    ["Counterattack"] = true,
}

-- Spells always worth clipping for
local ALWAYS_WORTH_SPELLS = {
    ["Kill Command"] = true,
    ["Bestial Wrath"] = true,
    ["Rapid Fire"] = true,
    ["Intimidation"] = true,
    ["Mend Pet"] = true,
}

-- Severity colors for display
local SEVERITY_COLORS = {
    GREEN  = { 0, 1, 0 },
    YELLOW = { 1, 1, 0 },
    ORANGE = { 1, 0.54, 0 },
    RED    = { 1, 0, 0 },
}

-- ============================================================================
-- MODULE STATE
-- ============================================================================
local _state = {
    -- Timing state
    last_auto_shot_time = nil,
    last_expected_speed = nil,
    is_first_shot = true,

    -- Cast tracking
    current_cast_spell = nil,
    current_cast_start_time = nil,
    last_cast_spell = nil,
    last_cast_time = nil,

    -- Movement tracking
    was_moving_in_interval = false,
    move_start_time = nil,
    is_currently_moving = false,

    -- Melee tracking
    was_in_melee_interval = false,
    melee_spells_during_interval = {},

    -- Log buffer
    clip_log = {},
    clip_log_max = 500,

    -- Combat session stats
    combat_stats = {
        total_clips = 0,
        total_clip_time = 0,
        worst_clip = 0,
        worst_clip_cause = "",
        clips_by_spell = {},
        clips_by_severity = { GREEN = 0, YELLOW = 0, ORANGE = 0, RED = 0 },
        auto_shot_count = 0,
        combat_start_time = 0,
    },

    -- Settings (populated from menu)
    enabled = false,
    print_summary = true,
    threshold_1 = 0.125,  -- 125ms - green/yellow boundary
    threshold_2 = 0.250,  -- 250ms - yellow/orange boundary
    threshold_3 = 0.500,  -- 500ms - orange/red boundary
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function get_timestamp()
    local game_time = _core_time()
    local ms = _format("%.2f", game_time % 1)
    local date_str = os and os.date and os.date("%H:%M:%S") or "00:00:00"
    return _format("%s.%s", date_str, ms:sub(3))
end

local function get_severity(delay)
    if delay <= _state.threshold_1 then return "GREEN"
    elseif delay <= _state.threshold_2 then return "YELLOW"
    elseif delay <= _state.threshold_3 then return "ORANGE"
    else return "RED"
    end
end

local function get_spell_cast_time(spell_name)
    if not spell_name then return 0 end
    -- In Sylvanas, we don't have direct cast time API
    -- Use known cast times for TBC Hunter spells
    local known_cast_times = {
        ["Steady Shot"] = 1.5,
        ["Aimed Shot"] = 2.5,
        ["Multi-Shot"] = 0.5,
        ["Cobra Shot"] = 2.0,
    }
    return known_cast_times[spell_name] or 0
end

local function evaluate_worth(clip_duration, cause_spell, was_moving)
    -- Movement is always necessary
    if was_moving and (not cause_spell or cause_spell == "Movement") then
        return "NECESSARY"
    end

    -- Melee interlude: can't auto shot while in melee range
    if cause_spell and cause_spell:find("^Melee") then
        return "NECESSARY"
    end

    -- Trivial clips (within latency)
    if clip_duration <= 0.05 then
        return "TRIVIAL"
    end

    if cause_spell and cause_spell ~= "Unknown" and cause_spell ~= "Movement" then
        -- Check always-worth spells
        if ALWAYS_WORTH_SPELLS[cause_spell] then
            return "WORTH_IT"
        end

        local cast_time = get_spell_cast_time(cause_spell)
        if cast_time <= 0 then
            -- Instant cast spell with significant clip
            if clip_duration > 0.2 then
                return "NOT_WORTH"
            else
                return "TRIVIAL"
            end
        end

        -- Overhead ratio: clip time as fraction of cast time
        local ratio = clip_duration / cast_time
        if ratio < 0.15 then
            return "WORTH_IT"
        elseif ratio < 0.30 then
            return "MARGINAL"
        else
            return "NOT_WORTH"
        end
    end

    return "UNKNOWN"
end

local function reset_interval_state()
    _state.was_in_melee_interval = false
    _state.was_moving_in_interval = false
    _state.melee_spells_during_interval = {}
end

-- ============================================================================
-- CORE CLIP DETECTION
-- ============================================================================

function hunter_clip_tracker.on_auto_shot_fired()
    if not _state.enabled then return end

    local now = _core_time()
    _state.combat_stats.auto_shot_count = _state.combat_stats.auto_shot_count + 1

    if _state.is_first_shot or not _state.last_auto_shot_time or not _state.last_expected_speed then
        _state.last_auto_shot_time = now
        _state.last_expected_speed = 3.0  -- Default ranged weapon speed
        _state.is_first_shot = false
        reset_interval_state()
        return
    end

    local elapsed = now - _state.last_auto_shot_time
    local delay = elapsed - _state.last_expected_speed

    -- Discard unreasonable values (target swap, death, etc.)
    if delay > 10 or delay < -1 then
        _state.last_auto_shot_time = now
        _state.last_expected_speed = 3.0
        reset_interval_state()
        return
    end

    -- Record speed at this shot for next comparison
    local prev_speed = _state.last_expected_speed
    _state.last_auto_shot_time = now
    _state.last_expected_speed = 3.0  -- Will be updated by caller if available

    -- Only record clips above threshold
    if delay <= 0.01 then
        reset_interval_state()
        return
    end

    -- Determine cause (priority: melee > cast-bar spell > movement > instant cast > unknown)
    local cause_spell = nil
    local cause_cast_time = 0
    local had_melee = #_state.melee_spells_during_interval > 0

    -- Priority 1: Melee spells were cast during interval
    if had_melee or _state.was_in_melee_interval then
        if had_melee then
            cause_spell = "Melee (" .. _state.melee_spells_during_interval[1].name .. ")"
        else
            cause_spell = "Melee"
        end
        cause_cast_time = 0
    end

    -- Priority 2: Cast-bar spell (Steady Shot, etc.)
    if not cause_spell and _state.current_cast_spell and _state.current_cast_start_time then
        local cast_age = now - _state.current_cast_start_time
        if cast_age < 5 then
            cause_spell = _state.current_cast_spell
            cause_cast_time = get_spell_cast_time(_state.current_cast_spell)
        end
    end

    -- Priority 3: Movement during interval
    local was_moving = false
    if _state.was_moving_in_interval then
        was_moving = true
    elseif _state.is_currently_moving and _state.move_start_time and (now - _state.move_start_time) >= 0.25 then
        was_moving = true
    end

    if not cause_spell and was_moving then
        cause_spell = "Movement"
        cause_cast_time = 0
    end

    -- Priority 4: Last cast (instant spells like Arcane Shot)
    if not cause_spell and _state.last_cast_spell then
        local cast_age = now - (_state.last_cast_time or 0)
        if cast_age < 3 then
            cause_spell = _state.last_cast_spell
            cause_cast_time = get_spell_cast_time(cause_spell)
        end
    end

    if was_moving and not cause_spell then
        cause_spell = "Movement"
        cause_cast_time = 0
    end

    if not cause_spell then
        cause_spell = "Unknown"
    end

    local severity = get_severity(delay)
    local verdict = evaluate_worth(delay, cause_spell, was_moving)

    -- Record clip event
    local entry = {
        timestamp = get_timestamp(),
        raw_time = now,
        clip_duration = delay,
        expected_speed = prev_speed,
        actual_interval = elapsed,
        cause_spell = cause_spell,
        cause_cast_time = cause_cast_time,
        severity = severity,
        was_moving = was_moving,
        verdict = verdict,
    }

    table.insert(_state.clip_log, entry)
    while #_state.clip_log > _state.clip_log_max do
        table.remove(_state.clip_log, 1)
    end

    -- Update stats
    local stats = _state.combat_stats
    stats.total_clips = stats.total_clips + 1
    stats.total_clip_time = stats.total_clip_time + delay
    stats.clips_by_severity[severity] = (stats.clips_by_severity[severity] or 0) + 1

    if delay > stats.worst_clip then
        stats.worst_clip = delay
        stats.worst_clip_cause = cause_spell
    end

    if not stats.clips_by_spell[cause_spell] then
        stats.clips_by_spell[cause_spell] = { count = 0, total_time = 0 }
    end
    stats.clips_by_spell[cause_spell].count = stats.clips_by_spell[cause_spell].count + 1
    stats.clips_by_spell[cause_spell].total_time = stats.clips_by_spell[cause_spell].total_time + delay

    -- Print clip info if debug enabled
    if _state.debug then
        local color = SEVERITY_COLORS[severity]
        print(_format("[ClipTracker] |cff%02x%02x%02x%s|r %s: +%.3fs (%s)",
            color[1] * 255, color[2] * 255, color[3] * 255,
            severity, cause_spell, delay, verdict))
    end

    -- Reset interval tracking for next auto shot
    reset_interval_state()
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

function hunter_clip_tracker.on_spell_cast(spell_name, is_melee)
    if not _state.enabled then return end
    if not spell_name then return end

    local now = _core_time()

    -- Track melee spells
    if is_melee or MELEE_SPELL_NAMES[spell_name] then
        table.insert(_state.melee_spells_during_interval, {
            name = spell_name,
            time = now,
        })
        _state.was_in_melee_interval = true
    end

    -- Track cast-bar spells
    local cast_time = get_spell_cast_time(spell_name)
    if cast_time > 0 then
        _state.current_cast_spell = spell_name
        _state.current_cast_start_time = now
    else
        -- Instant cast - record as last cast
        _state.last_cast_spell = spell_name
        _state.last_cast_time = now
    end
end

function hunter_clip_tracker.on_auto_shot_cast(spell_id)
    if not _state.enabled then return end
    if spell_id == AUTO_SHOT_SPELL_ID then
        hunter_clip_tracker.on_auto_shot_fired()
    end
end

function hunter_clip_tracker.on_melee_attack()
    if not _state.enabled then return end
    _state.was_in_melee_interval = true
end

function hunter_clip_tracker.on_start_moving()
    if not _state.enabled then return end
    _state.move_start_time = _core_time()
    _state.is_currently_moving = true
end

function hunter_clip_tracker.on_stop_moving()
    if not _state.enabled then return end
    _state.is_currently_moving = false
    -- Only flag as real movement if we moved for >= 0.25s
    if _state.move_start_time and (_core_time() - _state.move_start_time) >= 0.25 then
        _state.was_moving_in_interval = true
    end
    _state.move_start_time = nil
end

-- ============================================================================
-- COMBAT SUMMARY
-- ============================================================================

function hunter_clip_tracker.print_combat_summary()
    if not _state.enabled then return end
    if not _state.print_summary then return end

    local stats = _state.combat_stats
    if stats.auto_shot_count == 0 then return end

    local combat_duration = _core_time() - stats.combat_start_time
    if combat_duration < 3 then return end

    local clip_rate = stats.total_clips > 0 and (stats.total_clips / stats.auto_shot_count * 100) or 0
    local avg_per_shot = stats.total_clip_time / stats.auto_shot_count
    local avg_per_clip = stats.total_clips > 0 and (stats.total_clip_time / stats.total_clips) or 0

    print(_format("|cffFF8000[ClipTracker]|r Combat Summary (%.1fs)", combat_duration))
    print(_format("  Auto Shots: %d | Clips: %d (%.1f%%) | Total Clip Time: %.2fs",
        stats.auto_shot_count, stats.total_clips, clip_rate, stats.total_clip_time))
    print(_format("  Avg Clip/Shot: %.3fs | Avg Clip (clipped only): %.3fs | Worst: %.3fs (%s)",
        avg_per_shot, avg_per_clip, stats.worst_clip, stats.worst_clip_cause ~= "" and stats.worst_clip_cause or "N/A"))
    print(_format("  Green: %d | Yellow: %d | Orange: %d | Red: %d",
        stats.clips_by_severity.GREEN or 0, stats.clips_by_severity.YELLOW or 0,
        stats.clips_by_severity.ORANGE or 0, stats.clips_by_severity.RED or 0))

    -- Clips by cause
    local causes = {}
    for spell, data in pairs(stats.clips_by_spell) do
        table.insert(causes, { spell = spell, count = data.count, total_time = data.total_time })
    end
    if #causes > 0 then
        table.sort(causes, function(a, b) return a.total_time > b.total_time end)
        print("  Clips by cause:")
        for _, c in ipairs(causes) do
            local avg = c.count > 0 and (c.total_time / c.count) or 0
            print(_format("    %s: %dx (%.2fs total, %.3fs avg)", c.spell, c.count, c.total_time, avg))
        end
    end
end

-- ============================================================================
-- COMBAT STATE MANAGEMENT
-- ============================================================================

function hunter_clip_tracker.on_combat_start()
    if not _state.enabled then return end
    hunter_clip_tracker.reset_combat_stats()
end

function hunter_clip_tracker.on_combat_end()
    if not _state.enabled then return end
    hunter_clip_tracker.print_combat_summary()
end

function hunter_clip_tracker.reset_combat_stats()
    _state.combat_stats = {
        total_clips = 0,
        total_clip_time = 0,
        worst_clip = 0,
        worst_clip_cause = "",
        clips_by_spell = {},
        clips_by_severity = { GREEN = 0, YELLOW = 0, ORANGE = 0, RED = 0 },
        auto_shot_count = 0,
        combat_start_time = _core_time(),
    }
    _state.is_first_shot = true
    _state.last_auto_shot_time = nil
    _state.last_expected_speed = nil
    _state.current_cast_spell = nil
    _state.current_cast_start_time = nil
    _state.last_cast_spell = nil
    _state.last_cast_time = nil
    reset_interval_state()
end

-- ============================================================================
-- SETTINGS MANAGEMENT
-- ============================================================================

function hunter_clip_tracker.set_enabled(enabled)
    _state.enabled = enabled
end

function hunter_clip_tracker.is_enabled()
    return _state.enabled
end

function hunter_clip_tracker.set_print_summary(enabled)
    _state.print_summary = enabled
end

function hunter_clip_tracker.set_thresholds(green_yellow, yellow_orange, orange_red)
    _state.threshold_1 = (green_yellow or 125) / 1000
    _state.threshold_2 = (yellow_orange or 250) / 1000
    _state.threshold_3 = (orange_red or 500) / 1000
end

function hunter_clip_tracker.set_debug(enabled)
    _state.debug = enabled
end

-- ============================================================================
-- EXPORT DATA
-- ============================================================================

function hunter_clip_tracker.get_csv_export()
    local lines = {}
    -- CSV header
    table.insert(lines, "timestamp,clip_duration,expected_speed,actual_interval,cause_spell,cause_cast_time,severity,was_moving,verdict")

    for _, entry in ipairs(_state.clip_log) do
        table.insert(lines, _format("%s,%.4f,%.4f,%.4f,%s,%.4f,%s,%s,%s",
            entry.timestamp, entry.clip_duration, entry.expected_speed, entry.actual_interval,
            entry.cause_spell, entry.cause_cast_time or 0, entry.severity,
            tostring(entry.was_moving), entry.verdict))
    end

    -- Append summary block
    local stats = _state.combat_stats
    if stats.auto_shot_count > 0 then
        local combat_duration = _core_time() - stats.combat_start_time
        local clip_rate = stats.total_clips / stats.auto_shot_count * 100
        local avg_per_shot = stats.total_clip_time / stats.auto_shot_count
        local avg_per_clip = stats.total_clips > 0 and (stats.total_clip_time / stats.total_clips) or 0

        table.insert(lines, "")
        table.insert(lines, "--- COMBAT SUMMARY ---")
        table.insert(lines, _format("Combat Duration: %.1fs", combat_duration))
        table.insert(lines, _format("Auto Shots: %d", stats.auto_shot_count))
        table.insert(lines, _format("Clips: %d (%.1f%%)", stats.total_clips, clip_rate))
        table.insert(lines, _format("Total Clip Time: %.3fs", stats.total_clip_time))
        table.insert(lines, _format("Avg Clip/Shot: %.4fs", avg_per_shot))
        table.insert(lines, _format("Avg Clip (clipped only): %.4fs", avg_per_clip))
        table.insert(lines, _format("Worst Clip: %.4fs (%s)", stats.worst_clip, stats.worst_clip_cause))
        table.insert(lines, _format("Green: %d | Yellow: %d | Orange: %d | Red: %d",
            stats.clips_by_severity.GREEN or 0, stats.clips_by_severity.YELLOW or 0,
            stats.clips_by_severity.ORANGE or 0, stats.clips_by_severity.RED or 0))

        for spell, data in pairs(stats.clips_by_spell) do
            local avg = data.count > 0 and (data.total_time / data.count) or 0
            table.insert(lines, _format("  %s: %dx (%.3fs total, %.4fs avg)", spell, data.count, data.total_time, avg))
        end
    end

    return table.concat(lines, "\n")
end

-- ============================================================================
-- GETTERS FOR DASHBOARD INTEGRATION
-- ============================================================================

function hunter_clip_tracker.get_stats()
    return _state.combat_stats
end

function hunter_clip_tracker.get_recent_clips(count)
    count = count or 10
    local recent = {}
    local start_idx = math.max(1, #_state.clip_log - count + 1)
    for i = start_idx, #_state.clip_log do
        table.insert(recent, _state.clip_log[i])
    end
    return recent
end

function hunter_clip_tracker.get_severity_color(severity)
    return SEVERITY_COLORS[severity] or SEVERITY_COLORS.GREEN
end

-- ============================================================================
-- UPDATE LOOP (call from main.lua on_update)
-- ============================================================================

function hunter_clip_tracker.update(me)
    if not _state.enabled then return end
    if not me or not me:is_valid() then return end

    -- Check movement state (pcall protected for Sylvanas compatibility)
    local ok_moving, is_moving_now = pcall(function() return me:is_moving() end)
    if not ok_moving then is_moving_now = false end
    if is_moving_now and not _state.is_currently_moving then
        hunter_clip_tracker.on_start_moving()
    elseif not is_moving_now and _state.is_currently_moving then
        hunter_clip_tracker.on_stop_moving()
    end
end

return hunter_clip_tracker
