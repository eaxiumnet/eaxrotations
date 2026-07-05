-- =============================================================================
-- Core/Stealth Module v2.4.3 — Advanced player detection & anti-detection
-- WHAT:  Scans for nearby players with false-positive filtering, proximity
--        scaling, suspicion memory, and session-wide paranoia.
-- WHEN:  every tick when stealth_mode is enabled.
-- WHY:   Binary on/off detection is robotic. Real humans build suspicion over
--        time, react differently to close vs distant players, and stay cautious
--        after a player leaves. This module models all of that.
-- SAFETY: pcall on all API calls; never crashes on missing object fields.
-- =============================================================================

local APISurface = require("core/api_surface")

local M = {}

-- How often to re-scan for players (seconds)
local SCAN_INTERVAL = 1.5
-- Default range if menu value is unreadable (yards squared)
local DEFAULT_RANGE_YD = 30
local DEFAULT_RANGE_SQ = DEFAULT_RANGE_YD * DEFAULT_RANGE_YD

--- Internal: get distance-squared to nearest player, plus the player object
-- @param ctx table
-- @param me game_object
-- @return number|nil dist_sq (nil if no player in range)
-- @return table|nil nearest_player object
local function get_nearest_player_dist(ctx, me)
    local config = ctx.deps.config
    local range_yds = DEFAULT_RANGE_YD
    if config.menu.stealth_range and config.menu.stealth_range.get then
        range_yds = config.menu.stealth_range:get() or DEFAULT_RANGE_YD
    end
    local range_sq = range_yds * range_yds

    local my_pos = APISurface.get_object_position(me)
    if not my_pos then return nil, nil end

    local objects = APISurface.get_all_objects()
    local best_dist = math.huge
    local best_obj = nil

    for _, obj in ipairs(objects) do
        if APISurface.is_valid(obj) and obj ~= me then
            local is_player = false
            if type(obj.is_player) == "function" then
                local ok, result = pcall(obj.is_player, obj)
                if ok then is_player = result end
            end
            if is_player then
                local pos = APISurface.get_object_position(obj)
                if pos then
                    local dx = my_pos.x - pos.x
                    local dy = my_pos.y - pos.y
                    local dist_sq = dx*dx + dy*dy
                    if dist_sq < best_dist and dist_sq <= range_sq then
                        best_dist = dist_sq
                        best_obj = obj
                    end
                end
            end
        end
    end

    if best_dist == math.huge then return nil, nil end
    return best_dist, best_obj
end

--- Main stealth update — called every tick
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean player_is_nearby
function M.update(ctx, me, now)
    local state = ctx.state
    local st = state.stealth

    -- Throttle scan
    if st.last_scan_time > 0 and (now - st.last_scan_time) < SCAN_INTERVAL then
        return st.player_nearby
    end
    st.last_scan_time = now

    local dist_sq, nearest = get_nearest_player_dist(ctx, me)
    local detected = dist_sq ~= nil

    -- v2.4.3: False-positive filtering — require 2 consecutive detections
    if detected then
        st.consecutive_detections = st.consecutive_detections + 1
        if st.consecutive_detections < 2 then
            detected = false  -- First sighting might be a phantom
        end
    else
        st.consecutive_detections = 0
    end

    -- v2.4.3: Proximity tracking (for scaled delays)
    if detected and dist_sq then
        st.nearest_dist_sq = dist_sq
        st.nearest_player = nearest
    else
        st.nearest_dist_sq = nil
        st.nearest_player = nil
    end

    -- v2.4.3: Suspicion system — encounter memory
    if detected and not st.player_nearby then
        -- Player just appeared — increment suspicion
        st.suspicion_level = math.min(st.suspicion_level + 1, 5)
        st.total_encounters = st.total_encounters + 1
        st.last_player_seen_time = now

        -- v2.4.3: "Nervous pause" — random 2-5s pause on first sighting
        local nervous_pause = 2.0 + math.random() * 3.0
        st.nervous_pause_end = now + nervous_pause
        APISurface.print("[EaxFishing] Stealth: player detected (suspicion " .. st.suspicion_level .. "/5) — pausing " .. string.format("%.1f", nervous_pause) .. "s")

    elseif not detected and st.player_nearby then
        -- Player just left — enter cooldown, don't immediately resume normal pace
        st.cooldown_end = now + (15.0 + math.random() * 30.0)  -- 15-45s cooldown
        APISurface.print("[EaxFishing] Stealth: player left — staying cautious for cooldown")
    end

    st.player_nearby = detected
    return detected
end

--- Get the current stealth multiplier for delays.
-- v2.4.3: Proximity-scaled + suspicion-scaled + cooldown-scaled.
-- Returns 1.0 when safe, up to 3.5 when highly suspicious with player close.
-- @param ctx table context
-- @param now number current time
-- @return number multiplier (≥1.0)
function M.get_delay_multiplier(ctx, now)
    local state = ctx.state
    local config = ctx.deps.config
    local st = state.stealth

    -- Stealth mode disabled
    local stealth_on = false
    if config.menu.stealth_mode and config.menu.stealth_mode.get_state then
        stealth_on = config.menu.stealth_mode:get_state()
    end
    if not stealth_on then return 1.0 end

    local me = APISurface.get_local_player()
    if not me or not APISurface.is_valid(me) then return 1.0 end

    -- Update detection state
    M.update(ctx, me, now)

    -- v2.4.3: Nervous pause — block everything during initial panic
    if st.nervous_pause_end and now < st.nervous_pause_end then
        return 5.0  -- Massive delay = effectively paused
    end
    st.nervous_pause_end = nil

    local multiplier = 1.0

    -- v2.4.3: Proximity scaling — closer player = more delay
    if st.player_nearby and st.nearest_dist_sq then
        local range_yds = DEFAULT_RANGE_YD
        if config.menu.stealth_range and config.menu.stealth_range.get then
            range_yds = config.menu.stealth_range:get() or DEFAULT_RANGE_YD
        end
        local max_sq = range_yds * range_yds
        -- Normalize distance: 0 (at max range) → 1 (right next to us)
        local proximity = math.max(0, math.min(1, 1 - (st.nearest_dist_sq / max_sq)))
        -- Scale: at max range = +0.2x, at point blank = +1.5x
        multiplier = multiplier + (0.2 + proximity * 1.3)
    end

    -- v2.4.3: Suspicion scaling — more encounters = more cautious
    -- Each encounter adds 0.1x permanently (session-wide paranoia)
    multiplier = multiplier + (st.total_encounters * 0.1)

    -- v2.4.3: Active suspicion level — recent encounters boost more
    multiplier = multiplier + (st.suspicion_level * 0.15)

    -- v2.4.3: Cooldown — stay cautious after player leaves
    if st.cooldown_end and now < st.cooldown_end then
        local remaining = st.cooldown_end - now
        -- Fade from +0.5x down to 0 as cooldown expires
        local cooldown_boost = 0.5 * (remaining / 45.0)
        multiplier = multiplier + cooldown_boost
    end

    -- v2.4.3: Ultra-safe mode caps the multiplier
    local ultra_safe = false
    if config.menu.ultra_safe_mode and config.menu.ultra_safe_mode.get_state then
        ultra_safe = config.menu.ultra_safe_mode:get_state()
    end
    if ultra_safe then
        multiplier = multiplier * 1.3  -- Additional 30% on top
    end

    -- Cap at reasonable maximum
    if multiplier > 5.0 then multiplier = 5.0 end

    return multiplier
end

--- Check if we should face away from the nearest player
-- @param ctx table
-- @param now number
-- @return boolean should_face_away
function M.should_face_away(ctx, now)
    local state = ctx.state
    local config = ctx.deps.config
    local st = state.stealth

    if not st.player_nearby then return false end
    if not st.nearest_player then return false end

    local face_away = false
    if config.menu.stealth_face_away and config.menu.stealth_face_away.get_state then
        face_away = config.menu.stealth_face_away:get_state()
    end
    if not face_away then return false end

    -- Only face away if player is very close (< 10 yards)
    if st.nearest_dist_sq and st.nearest_dist_sq <= 100 then
        return true
    end
    return false
end

--- Get the nearest player object (for face-away)
-- @param ctx table
-- @return table|nil player object
function M.get_nearest_player(ctx)
    return ctx.state.stealth.nearest_player
end

--- Reset stealth state
-- @param state table
function M.reset(state)
    if not state.stealth then return end
    state.stealth.last_scan_time = 0.0
    state.stealth.player_nearby = false
    state.stealth.nearest_dist_sq = nil
    state.stealth.nearest_player = nil
    state.stealth.consecutive_detections = 0
    state.stealth.suspicion_level = 0
    state.stealth.total_encounters = 0
    state.stealth.last_player_seen_time = 0.0
    state.stealth.nervous_pause_end = nil
    state.stealth.cooldown_end = nil
end

return M
