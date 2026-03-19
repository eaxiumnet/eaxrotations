-- =============================================================================
-- Core State Module - Single source of truth for all runtime state
-- Eliminates Lua's 60 upvalue limit by consolidating state into one table
-- NOTE: Bite detection state lives as module-level locals in fishing/engine.lua
--       for hot-path performance. state.bite was removed to avoid dual-state confusion.
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
            look_at_delay_end = 0.0,
            stand_still_since = 0.0,  -- Track when player started standing still
            no_lure_warned = false,   -- Track if we already warned about no lures
            bobber_last_seen = 0,
            last_bobber_obj = nil,
        },
        
        -- NOTE: Bite detection state is intentionally kept as module-level locals
        -- inside fishing/engine.lua for performance (avoids table indirection on
        -- the hot per-tick path). The state.bite table has been removed to avoid
        -- confusion from having two parallel bite-state systems.
        
        -- Loot handling state
        loot = {
            last_time = 0.0,
            slot_index = 0,
            start_time = 0.0,
            reverse = false,
        },
        
        -- Equipment state
        equip = {
            pole_delay_end = 0.0,
            pole_equip_delay_end = 0.0,
            lure_delay_end = 0.0,
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
            cached_free_slots = nil,
            last_helper_free = nil,
            last_fallback_free = nil,
            last_total_slots = 0,
            last_used_slots = 0,
            last_slot_data_unreliable = false,
            next_slot_warn_time = 0.0,
        },
        
        -- Anti-AFK state
        anti_afk = {
            next_pulse_time = 0.0,
        },
        
        -- Auto-delete state
        auto_delete = {
            next_scan_time = 0.0,
            next_api_warn_time = 0.0,
            blacklist_cache = "",
            blacklist_ids = {},
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
            lure_apply_delay_end = 0.0,
        },
        
        -- Vendor state
        vendor = {
            next_repair_time = 0.0,
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
            stats = {
                fish_count   = 0,       -- total fish items looted
                gray_count   = 0,       -- total gray items looted
                item_counts  = {},      -- [item_name] = count
                vendor_copper = 0,      -- confirmed vendor value (Goldenscale Vendorfish only)
                gold_start   = nil,     -- gold at session start (set on first tick)
            },
        },
    }
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
-- @param state table
function M.reset_fishing(state)
    state.fishing.status = "Idle"
    state.fishing.awaiting_bobber = false
    state.fishing.failed_cast_count = 0
    state.fishing.no_bobber_count = 0
    state.fishing.consecutive_catches = 0
    state.fishing.next_cast_time = 0.0
    state.fishing.next_break_time = 0.0
    state.fishing.stand_still_since = 0.0
    state.fishing.no_lure_warned = false
    state.safety.hard_stop = false  -- Reset safety stop on manual disable
    -- Note: bite state is module-level in fishing/engine.lua and resets via its own reset_bite()
    state.loot.last_time = 0.0
    state.loot.slot_index = 0
    state.loot.start_time = 0.0
end

return M
