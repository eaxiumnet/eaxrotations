-- =============================================================================
-- Core State Module - Single source of truth for all runtime state
-- Eliminates Lua's 60 upvalue limit by consolidating state into one table
-- =============================================================================

local M = {}

--- Create a new state instance
-- @param now number? current timestamp
-- @return table state
function M.create(now)
    now = now or 0
    return {
        -- Core fishing state
        fishing = {
            status = "Idle",
            id = nil,
            cast_start_time = 0.0,
            awaiting_bobber = false,
            last_action_time = 0.0,
            failed_cast_count = 0,
            no_bobber_count = 0,
            next_cast_time = 0.0,
            next_break_time = 0.0,
            consecutive_catches = 0,
            no_lure_warned = false,   -- Track if we already warned about no lures
            -- Z-dip bite-detection fallback (Sylvanas does_bobber_have_fish
            -- is broken — always false). Baseline the bobber's resting Z after
            -- a cast; a splash dips it below baseline.
            bobber_z_baseline = nil,
            dip_confirm_count = 0,
            bobber_found_time = 0.0,
            bite_window_timeout_click = false,
            -- Sticky: once a Z-dip bite is confirmed for THIS bobber, keep
            -- reporting a bite until the click reels it in (prevents a
            -- transient dip-recovery frame from aborting a real bite
            -- mid-reaction-window).
            dip_triggered = false,
        },
        
        -- Bite detection state
        bite = {
            detected_time = 0.0,
            pending = false,
            reaction_deadline = 0.0,
            escape_deadline = 0.0,
            should_miss = false,
        },
        
        -- Loot handling state
        loot = {
            last_time = 0.0,
            slot_index = 0,
            start_time = 0.0,
            reverse = false,
        },
        
        -- Equipment state
        equip = {
            pole_equip_delay_end = 0.0,
            pre_main_hand_id = nil,
            pre_off_hand_id = nil,
            last_reequip_time = 0.0,
            last_equip_time = 0.0,
            upgrade_announced = false,
        },
        
        -- Navigation state
        navigation = {
            stop_distance = 15.0,
            shoreline_no_route_count = 0,
            pool_face_pos = nil,
            pool_face_update = 0.0,
            shoreline_solver_cache = {
                key = nil,
                next_retry_time = 0.0,
                result = nil,
                result_radius = nil,
            },
        },
        
        -- Bag/inventory state
        bag = {
            full_confirm_count = 0,
            next_alert_time = 0.0,
            next_space_check_time = 0.0,
            safety_lock_active = false,
            _last_debug_log = 0.0,
        },
        
        -- Anti-AFK state
        anti_afk = {
            next_pulse_time = 0.0,
        },
        
        -- Profile/behavior state
        profile = {
            was_enabled = false,
            enabled_since_time = 0.0,
            behavior = nil,
            next_reroll = 0,
        },
        
        -- Lure tracking state
        lure = {
            assumed_expire_time = 0.0,
            next_dbg_time = 0.0,
            lure_apply_delay_end = 0.0,
        },
        
        -- Cooking state
        cook = {
            last_cook_time = 0.0,
            cooked_count = 0,
            queued = nil,
            status = "Idle",
            cook_delay_end = 0.0,
        },

        -- Vendor state
        vendor = {
            next_repair_time = 0.0,
        },
        
        -- Stealth mode state (v2.4.3 — advanced anti-detection)
        stealth = {
            player_nearby = false,
            last_scan_time = 0,
            nearest_dist_sq = nil,
            nearest_player = nil,
            consecutive_detections = 0,
            suspicion_level = 0,
            total_encounters = 0,
            last_player_seen_time = 0.0,
            nervous_pause_end = nil,
            cooldown_end = nil,
        },

        -- Container opening state (v2.4.0)
        containers = {
            last_open_time = 0.0,
            opened_count   = 0,
        },

        -- Mr. Pinchy handler state (v2.4.0)
        pinchy = {
            last_use_time = 0.0,
            uses_total    = 0,
            crawdad_won   = false,
        },

        -- Auto-sell junk state (v2.4.0)
        autosell = {
            last_sell_time = 0.0,
            sold_count     = 0,
        },

        -- Auto-delete junk state (v2.4.0)
        autodelete = {
            last_delete_time = 0.0,
            deleted_count    = 0,
        },

        -- Pool depletion state (v2.4.0)
        pool_depletion = {
            current_pool_guid = nil,
            casts_at_pool     = 0,
            catches_at_pool   = 0,
            depleted_count    = 0,
        },

        -- Cast reliability telemetry (v2.4.0)
        cast_telemetry = {
            success_count  = 0,
            fail_count     = 0,
            fail_streak    = 0,
        },

        -- Quest tracker state (v2.4.0)
        quest = {
            active_quest_id   = nil,
            quest_fish_id      = nil,
            quest_fish_name    = nil,
            quest_fish_needed  = 0,
            quest_fish_count   = 0,
            quest_complete     = false,
            last_check_time    = 0.0,
        },

        -- Whisper responder state (v2.4.0)
        responder = {
            last_response_time = 0.0,
            responses_total    = 0,
            last_sender        = "",
        },

        -- Hearth/return state (v2.4.0)
        hearth = {
            state              = "idle", -- idle|hearth|vendoring|returning
            hearth_time        = 0.0,
            return_position    = nil,
        },

        -- Relog state (v2.4.0)
        relog = {
            disconnected_at    = 0.0,
            relog_attempts     = 0,
            last_relog_time    = 0.0,
        },

        -- Conditions (time/weather) state (v2.4.0)
        conditions = {
            in_fishing_window  = true,
            window_checked_at  = 0.0,
        },

        -- v2.4.1: QoL state
        qol = {
            lure_expiry_warned    = false,
            catch_streak          = 0,
            best_catch_streak     = 0,
            last_lure_expire_time = 0.0,
            paused                = false,
        },

        -- v2.4.2: Water walking buff state
        water_walking = {
            last_try_time    = 0.0,
            reaction_deadline = nil,
        },

        -- Rare catch alert state
        alert = {
            active = false,
            text = "",
            fade_start = 0,
            fade_end = 0,
            quality = 2,
        },

        -- Safety system state
        safety = {
            stop_id = 0,
            hard_stop = false,
            last_position = nil,
            last_position_check = 0,
            standing_since = 0,
            warn_yellow_at = nil,
            warn_red_at = nil,
            warn_red_acked = false,
        },
        
        -- Session statistics
        session = {
            start_time   = now,
            attempts     = 0,
            catches      = 0,
            misses       = 0,   -- deliberate misses (humanizer)
            escaped      = 0,   -- fish that got away
            end_time     = 0.0, -- calculated on first enable if session limit is set
            time_limit_warned = false,
            stats = {
                fish_count   = 0,       -- total fish items looted
                gray_count   = 0,       -- total gray items looted
                item_counts  = {},      -- [item_name] = count
                vendor_copper = 0,      -- confirmed vendor value (Goldenscale Vendorfish only)
                gold_start   = nil,     -- gold at session start (set on first tick)
                lure_count   = 0,       -- total lures remaining in bags (for HUD)
            },
        },
    }
end

--- Reset bite state to default
-- @param state table
function M.reset_bite(state)
    state.bite.detected_time = 0.0
    state.bite.pending = false
    state.bite.reaction_deadline = 0.0
    state.bite.escape_deadline = 0.0
    state.bite.should_miss = false
end

--- Reset shoreline solver cache
-- @param state table
function M.reset_shoreline_solver_cache(state)
    local cache = state.navigation.shoreline_solver_cache
    cache.key = nil
    cache.next_retry_time = 0.0
    cache.result = nil
    cache.result_radius = nil
end

--- Reset all fishing state (for disable/stop)
-- Clears timers and flags so re-enable starts from a clean slate.
-- @param state table
function M.reset_fishing(state)
    state.fishing.status = "Idle"
    state.fishing.awaiting_bobber = false
    state.fishing.failed_cast_count = 0
    state.fishing.no_bobber_count = 0
    state.fishing.consecutive_catches = 0
    state.fishing.next_cast_time = 0.0
    state.fishing.next_break_time = 0.0
    state.fishing.no_lure_warned = false
    -- Clear Z-dip fallback tracking so the next cast re-baselines fresh.
    state.fishing.bobber_z_baseline = nil
    state.fishing.dip_confirm_count = 0
    state.fishing.bobber_found_time = 0.0
    state.fishing.bite_window_timeout_click = false
    state.fishing.dip_triggered = false
    state.safety.hard_stop = false
    state.session.time_limit_warned = false
    -- Clear stale equip / lure delays so they don't block re-enable
    state.equip.upgrade_announced = false
    state.equip.pole_equip_delay_end = 0.0
    state.lure.lure_apply_delay_end = 0.0
    -- Clear navigation stale state
    state.navigation.shoreline_no_route_count = 0
    state.navigation.pool_face_update = 0.0
    state.navigation.pool_face_pos = nil
    M.reset_shoreline_solver_cache(state)
    -- Clear cooking state
    if state.cook then
        state.cook.last_cook_time = 0.0
        state.cook.cooked_count = 0
        state.cook.queued = nil
        state.cook.status = "Idle"
        state.cook.cook_delay_end = 0.0
    end
    -- Clear bag confirmation count
    state.bag.full_confirm_count = 0
    -- Clear lure count so HUD doesn't show stale data
    state.session.stats.lure_count = 0
    -- Clear rare catch alert so it doesn't persist across re-enable
    state.alert.active = false
    state.alert.text = ""
    state.alert.fade_start = 0
    state.alert.fade_end = 0
    M.reset_bite(state)
    state.loot.last_time = 0.0
    state.loot.slot_index = 0
    state.loot.start_time = 0.0
    -- v2.4.0: reset new feature states
    if state.containers then
        state.containers.last_open_time = 0.0
        state.containers.opened_count = 0
    end
    if state.pinchy then
        state.pinchy.last_use_time = 0.0
        state.pinchy.uses_total = 0
        state.pinchy.crawdad_won = false
    end
    if state.autosell then
        state.autosell.last_sell_time = 0.0
        state.autosell.sold_count = 0
    end
    if state.autodelete then
        state.autodelete.last_delete_time = 0.0
        state.autodelete.deleted_count = 0
    end
    if state.pool_depletion then
        state.pool_depletion.current_pool_guid = nil
        state.pool_depletion.casts_at_pool = 0
        state.pool_depletion.catches_at_pool = 0
        state.pool_depletion.depleted_count = 0
    end
    if state.cast_telemetry then
        state.cast_telemetry.success_count = 0
        state.cast_telemetry.fail_count = 0
        state.cast_telemetry.fail_streak = 0
    end
    if state.quest then
        state.quest.active_quest_id = nil
        state.quest.quest_fish_id = nil
        state.quest.quest_fish_needed = 0
        state.quest.quest_fish_count = 0
        state.quest.quest_complete = false
    end
    if state.responder then
        state.responder.last_response_time = 0.0
        state.responder.responses_total = 0
        state.responder.last_sender = ""
    end
    if state.hearth then
        state.hearth.state = "idle"
        state.hearth.hearth_time = 0.0
        state.hearth.return_position = nil
    end
    if state.relog then
        state.relog.disconnected_at = 0.0
        state.relog.relog_attempts = 0
        state.relog.last_relog_time = 0.0
    end
    if state.conditions then
        state.conditions.in_fishing_window = true
        state.conditions.window_checked_at = 0.0
    end
    -- v2.4.1: reset QoL state
    if state.qol then
        state.qol.lure_expiry_warned = false
        state.qol.catch_streak = 0
        state.qol.best_catch_streak = 0
        state.qol.last_lure_expire_time = 0.0
        state.qol.paused = false
    end
    -- v2.4.2: reset water walking state
    if state.water_walking then
        state.water_walking.last_try_time = 0.0
        state.water_walking.reaction_deadline = nil
    end
end

return M
