-- =============================================================================
-- Fishing/Engine Module - Sylvanas-conformant rewrite
-- REPLACED: bobber.is_animating (removed - animation heuristic not reliable)
-- REPLACED: me.does_bobber_have_fish with APISurface.does_bobber_have_fish
-- REPLACED: core.object_manager.get_visible_objects with get_all_objects
-- REPLACED: Hardcoded spell 7620 with APISurface.resolve_fishing_spell
-- REMOVED: Debug spam (heartbeat, excessive logging)
-- =============================================================================

local State = require("core/state")
local Behavior = require("core/behavior")
local Gear = require("fishing/gear")
local Lures = require("fishing/lures")
local Loot = require("fishing/loot")
local Bags = require("inventory/bags")
local Client = require("navigation/client")
local ShorelineSolver = require("navigation/shoreline_solver")
local APISurface = require("core/api_surface")

local M = {}

-- Forward declarations
local reset_bite

-- Bite state (module level)
local bite_pending = false
local bite_detected_time = 0
local bite_reaction_deadline = 0
local bite_escape_deadline = 0
local bite_should_miss = false

--- Reset bite state
reset_bite = function()
    bite_pending = false
    bite_detected_time = 0
    bite_reaction_deadline = 0
    bite_escape_deadline = 0
    bite_should_miss = false
end

--- Main update tick
function M.tick(ctx)
    local state = ctx.state
    local deps = ctx.deps
    local now = APISurface.now()
    
    -- Sync control panel
    local cp_helper = APISurface.get_control_panel_helper()
    if cp_helper and cp_helper.on_update then
        local ok = pcall(cp_helper.on_update, cp_helper, deps.config.menu)
    end
    
    -- Check if enabled
    local enabled = false
    if deps.config.menu.enabled and deps.config.menu.enabled.get_state then
        enabled = deps.config.menu.enabled:get_state()
    end
    
    -- Reset hard_stop when manually disabled then re-enabled
    if not enabled and state.safety.hard_stop then
        state.safety.hard_stop = false
    end
    
    -- Hard safety stop
    if state.safety.hard_stop then
        if state.profile.was_enabled then
            state.profile.was_enabled = false
        end
        return
    end
    
    if not enabled then
        if state.profile.was_enabled then
            local me = APISurface.get_local_player()
            if me and APISurface.is_valid(me) and Gear.is_fishing_pole_equipped(me) then
                Gear.try_reequip_weapons(ctx, me, now)
            end
            Client.stop(ctx)
            State.reset_fishing(state)
            state.profile.was_enabled = false
        end
        return
    end
    
    -- Track enable state
    if not state.profile.was_enabled then
        APISurface.print("[EaxFishing] First enable - initializing")
        state.profile.enabled_since_time = now
        Bags.reset_full_confirm(ctx)
        reset_bite()
    end
    state.profile.was_enabled = true

    -- Keep behavior profile fresh (re-rolls every 15-25 min automatically)
    Behavior.ensure_profile(state, now)

    -- ===== ANTI-AFK — runs every tick, before everything else =====
    -- Must fire even mid-channel. Jumping while fishing does not cancel the cast.
    -- The is_busy guard was removed — it caused the timer to never fire.
    if deps.config.menu.anti_afk_enabled and deps.config.menu.anti_afk_enabled:get_state() then
        local afk_min = 60
        local afk_max = 180
        if deps.config.menu.anti_afk_interval_min and deps.config.menu.anti_afk_interval_min.get then
            afk_min = deps.config.menu.anti_afk_interval_min:get()
        end
        if deps.config.menu.anti_afk_interval_max and deps.config.menu.anti_afk_interval_max.get then
            afk_max = deps.config.menu.anti_afk_interval_max:get()
        end
        if afk_min > afk_max then afk_min, afk_max = afk_max, afk_min end

        if state.anti_afk.next_pulse_time <= 0.0 then
            state.anti_afk.next_pulse_time = now + math.random(afk_min, afk_max)
        end

        if now >= state.anti_afk.next_pulse_time then
            -- Only jump when NOT actively fishing - jumping cancels the fishing channel
            if not state.fishing.awaiting_bobber then
                APISurface.jump()
            end
            -- Always advance the timer so it does not fire immediately after the bobber is pulled
            state.anti_afk.next_pulse_time = now + math.random(afk_min, afk_max)
        end
    end
    -- ===== END ANTI-AFK =====
    
    -- Action throttle — applies to casting, equipping, navigating, etc.
    -- NOTE: bobber bite-detection runs OUTSIDE this throttle further below,
    -- because fish bites can be shorter than 0.75s and we cannot miss them.
    local action_throttle = 0.75 + math.random() * 0.6
    local throttled = now - state.fishing.last_action_time < action_throttle

    -- ===== FAST PATH: Bobber bite detection (runs every tick, ignores throttle) =====
    -- Uses documented API: game_object:does_bobber_have_fish()
    -- NOTE: This is currently broken on Sylvanas (always returns false).
    -- Bug report submitted. When Sylvanas fixes it, this will work as intended.
    if state.fishing.awaiting_bobber then
        local me_fast = APISurface.get_local_player()
        if me_fast and APISurface.is_valid(me_fast) then
            local p_fast = APISurface.get_object_position(me_fast)
            if p_fast then
                local bobber = APISurface.find_bobber(ctx, me_fast, p_fast.x, p_fast.y, p_fast.z)
                if bobber then
                    state.fishing.failed_cast_count = 0

                    -- Documented bite detection
                    local has_fish = APISurface.does_bobber_have_fish(bobber)

                    if has_fish then
                        if not bite_pending then
                            bite_pending = true
                            bite_detected_time = now
                            local catch_min_ms = 150
                            local catch_max_ms = 400
                            if deps.config.menu.catch_delay_min_ms and deps.config.menu.catch_delay_min_ms.get then
                                catch_min_ms = deps.config.menu.catch_delay_min_ms:get()
                            end
                            if deps.config.menu.catch_delay_max_ms and deps.config.menu.catch_delay_max_ms.get then
                                catch_max_ms = deps.config.menu.catch_delay_max_ms:get()
                            end
                            -- Scale by behavior profile so reaction time varies naturally over session
                            local reaction_s = Behavior.scaled_delay(state, now, catch_min_ms, catch_max_ms, "reaction", deps.config)
                            bite_reaction_deadline = bite_detected_time + reaction_s
                            local allow_escape = deps.config.menu.enable_fish_escape
                                and deps.config.menu.enable_fish_escape:get_state()
                            if allow_escape then
                                -- Scale escape window by behavior too
                                local escape_extra = Behavior.scaled_delay(state, now, 800, 1800, "reaction", deps.config)
                                bite_escape_deadline = bite_reaction_deadline + escape_extra
                            end
                            local allow_miss = deps.config.menu.enable_missed_catches
                                and deps.config.menu.enable_missed_catches:get_state()
                            if allow_miss and state.fishing.consecutive_catches >= 5 then
                                bite_should_miss = math.random() < 0.04
                            end
                            state.fishing.status = "Splash!"
                        end

                        if bite_escape_deadline > 0 and now >= bite_escape_deadline then
                            APISurface.print("[EaxFishing] Fish got away...")
                            state.fishing.status = "Fish got away..."
                            state.session.escaped = state.session.escaped + 1
                            reset_bite()
                            state.fishing.consecutive_catches = 0
                            state.fishing.awaiting_bobber = false
                            state.fishing.next_cast_time = now + (1.5 + math.random() * 1.0)
                            return
                        end

                        if bite_should_miss and now >= bite_reaction_deadline then
                            APISurface.print("[EaxFishing] ~~~ Deliberate miss (humanizer) ~~~")
                            state.fishing.status = "Deliberate miss..."
                            state.session.misses = state.session.misses + 1
                            reset_bite()
                            state.fishing.consecutive_catches = 0
                            state.fishing.awaiting_bobber = false
                            state.fishing.next_cast_time = now + (2.0 + math.random() * 1.5)
                            return
                        end

                        if now < bite_reaction_deadline then
                            local wait_ms = (bite_reaction_deadline - now) * 1000
                            state.fishing.status = "Splash! (" .. string.format("%.0f", wait_ms) .. "ms)..."
                            return
                        end

                        -- CLICK
                        local success = APISurface.use_object(bobber)
                        if success then
                            state.fishing.last_action_time = now
                            state.fishing.awaiting_bobber = false
                            reset_bite()
                            state.fishing.consecutive_catches = state.fishing.consecutive_catches + 1
                            state.session.catches = state.session.catches + 1
                            state.fishing.status = "Caught! (" .. state.session.catches .. ")"
                            state.fishing.next_cast_time = now + (1.0 + math.random() * 1.5)
                        end
                        return
                    else
                        if bite_pending then reset_bite() end
                        state.fishing.status = "Fishing..."
                        return
                    end
                end
            end
        end
    end
    -- ===== END FAST PATH =====

    if throttled then return end
    
    -- Get player
    local me = APISurface.get_local_player()
    if not me then
        state.fishing.status = "No player"
        return
    end
    if not APISurface.is_valid(me) then
        state.fishing.status = "Invalid"
        return
    end
    if APISurface.is_dead(me) or APISurface.is_ghost(me) then
        state.fishing.status = "Dead"
        return
    end
    
    -- Handle navigation
    if Client.is_moving(ctx) then
        local dest = Client.get_destination(ctx)
        if dest then
            local p = APISurface.get_object_position(me)
            if p then
                local dx = p.x - dest.x
                local dy = p.y - dest.y
                local dist = math.sqrt(dx*dx + dy*dy)
                
                if dist <= state.navigation.stop_distance then
                    Client.stop(ctx)
                    state.navigation.stop_distance = 15.0
                else
                    state.fishing.status = "Navigating"
                    return
                end
            end
        end
    end
    
    -- Check bag full
    if now >= state.bag.next_space_check_time then
        state.bag.next_space_check_time = now + 2.0
        local should_auto_stop = true
        if deps.config.menu.auto_stop_full and deps.config.menu.auto_stop_full.get_state then
            should_auto_stop = deps.config.menu.auto_stop_full:get_state()
        end
        
        if should_auto_stop and Bags.is_bags_full(ctx) then
            Bags.increment_full_confirm(ctx)
            if Bags.get_full_confirm_count(ctx) >= 3 then
                state.fishing.status = "Bags Full - Stopped"
                state.safety.hard_stop = true
                -- Disable via menu
                if deps.config.menu.enabled and deps.config.menu.enabled.set_state then
                    deps.config.menu.enabled:set_state(false)
                end
                Client.stop(ctx)
                return
            end
        else
            Bags.reset_full_confirm(ctx)
        end
    end
    
    -- Handle combat
    if APISurface.is_in_combat(me) then
        if Gear.is_fishing_pole_equipped(me) and Gear.try_reequip_weapons(ctx, me, now) then
            state.fishing.status = "In Combat: Re-equipping"
            return
        end
        state.fishing.status = "In Combat"
        return
    end
    
    -- Handle fishing pole equipping
    if not Gear.is_fishing_pole_equipped(me) then
        state.lure.assumed_expire_time = 0.0
        Gear.snapshot_weapons(ctx, me)

        if deps.config.menu.auto_equip:get_state() then
            if Gear.try_equip_fishing_pole(ctx, me, now) then
                state.fishing.status = "Equipping pole..."
                state.fishing.last_action_time = now
                return
            else
                state.fishing.status = "Waiting to equip pole..."
                return
            end
        else
            state.fishing.status = "No pole equipped (auto-equip disabled)"
            return
        end
    end

    -- Upgrade check: a pole is equipped but a better one may be in bags.
    if deps.config.menu.auto_equip:get_state() then
        local best_id     = Gear.get_owned_fishing_pole(ctx)
        local equipped_id = Gear.get_equipped_item_id(me, 16)
        if best_id and equipped_id and best_id ~= equipped_id then

            -- First detection: pick delay once and announce once
            if not state.equip.upgrade_announced then
                state.equip.upgrade_announced = true
                local use_delay = deps.config.menu.enable_equip_delays
                    and deps.config.menu.enable_equip_delays:get_state()
                if use_delay then
                    local delay = math.random(300, 800) / 1000
                    state.equip.pole_equip_delay_end = now + delay
                    APISurface.print("[EaxFishing] Better pole available - equipping in "
                        .. string.format("%.1f", delay) .. "s")
                else
                    state.equip.pole_equip_delay_end = 0
                    APISurface.print("[EaxFishing] Better pole available - equipping now")
                end
            end

            -- Wait out the delay, show countdown in status
            if state.equip.pole_equip_delay_end > now then
                local ms = math.floor((state.equip.pole_equip_delay_end - now) * 1000)
                state.fishing.status = "Upgrading pole in " .. ms .. "ms..."
                return
            end

            -- Delay done - equip directly
            state.equip.last_equip_time = now
            state.equip.pole_equip_delay_end = 0
            local success = APISurface.use_item_self_safe(best_id)
            if success then
                state.equip.upgrade_announced = false
                state.fishing.status = "Upgrading pole..."
                state.fishing.last_action_time = now
            else
                APISurface.print("[EaxFishing] Failed to equip better pole")
                state.equip.upgrade_announced = false
            end
            return
        else
            state.equip.upgrade_announced = false
        end
    end

    
    -- Check if can cast
    if now < state.fishing.next_cast_time then
        state.fishing.status = "Waiting to cast..."
        return
    end
    
    -- Handle loot
    if Loot.get_count(ctx) > 0 then
        Loot.process(ctx, me, now)
        return
    end
    
    -- Apply lure if needed
    if deps.config.menu.auto_lure and deps.config.menu.auto_lure:get_state() then
        if not Lures.has_active_lure(ctx, me, now) then
            if Lures.try_apply_lure(ctx, me, now) then
                state.fishing.status = "Applying lure..."
                state.fishing.last_action_time = now
                return
            else
                local lure, _, _ = Lures.find_best_lure(ctx)
                if not lure and state.lure.lure_apply_delay_end <= 0 then
                    if not state.fishing.no_lure_warned then
                        APISurface.print("[EaxFishing] No lure in bags - fishing without lure")
                        state.fishing.no_lure_warned = true
                    end
                elseif state.lure.lure_apply_delay_end > now then
                    state.fishing.status = "Preparing to apply lure..."
                    return
                end
            end
        else
            -- Lure is active � reset the warning flag so it fires again next time lures run out
            state.fishing.no_lure_warned = false
        end
    end
    
    -- Micro-breaks (humanization)
    -- Only take breaks if humanizer_enabled is true
    local humanizer_active = true
    if deps.config.menu.humanizer_enabled and deps.config.menu.humanizer_enabled.get_state then
        humanizer_active = deps.config.menu.humanizer_enabled:get_state()
    end
    
    if humanizer_active and deps.config.menu.break_frequency and deps.config.menu.break_frequency.get then
        local break_freq = deps.config.menu.break_frequency:get()
        if break_freq > 0 then
            -- Initialize next break time if needed
            if state.fishing.next_break_time <= 0.0 then
                -- Schedule first break - use math.floor to ensure integers for math.random
                local base_interval = 600 - (break_freq * 5)
                state.fishing.next_break_time = now + math.random(
                    math.floor(base_interval * 0.8),
                    math.floor(base_interval * 1.2)
                )
            end
            
            -- Check if it's time for a micro-break
            if now >= state.fishing.next_break_time then
                -- Take a 10-30 second break
                state.fishing.status = "Taking a short break..."
                state.fishing.next_cast_time = now + math.random(10, 30)
                -- Schedule next break - use math.floor to ensure integers for math.random
                local base_interval = 600 - (break_freq * 5)
                state.fishing.next_break_time = now + math.random(
                    math.floor(base_interval * 0.8),
                    math.floor(base_interval * 1.2)
                )
                return
            end
        end
    end
    
    -- ========== POOL NAVIGATION ==========
    -- If pool tracking is enabled and nav client is available, find the nearest
    -- fish pool and navigate to a shoreline standoff position before casting.
    local pool_tracking_on = deps.config.menu.pool_tracking
        and deps.config.menu.pool_tracking:get_state()
    
    if pool_tracking_on and Client.has_client(ctx) and not Client.is_moving(ctx) then
        local p = APISurface.get_object_position(me)
        if p then
            -- Find nearest fish pool in range
            local search_range = 250
            if deps.config.menu.pool_search_range and deps.config.menu.pool_search_range.get then
                search_range = deps.config.menu.pool_search_range:get()
            end
            local search_range_sq = search_range * search_range

            local desired_dist = 15
            if deps.config.menu.pool_standoff_distance and deps.config.menu.pool_standoff_distance.get then
                desired_dist = deps.config.menu.pool_standoff_distance:get()
            end
            local depth_tol = 0
            if deps.config.menu.pool_shore_depth_tolerance and deps.config.menu.pool_shore_depth_tolerance.get then
                depth_tol = deps.config.menu.pool_shore_depth_tolerance:get()
            end
            local only_wreckage = deps.config.menu.only_pools_wreckage
                and deps.config.menu.only_pools_wreckage:get_state()

            -- Scan objects for the nearest fish pool
            local nearest_pool = nil
            local nearest_pool_dist_sq = math.huge
            local objects = APISurface.get_all_objects()
            for _, obj in ipairs(objects) do
                if APISurface.is_valid(obj) then
                    local name = APISurface.get_object_name(obj)
                    local is_pool = type(name) == "string"
                        and (string.find(name, "Pool", 1, true)
                            or string.find(name, "School", 1, true)
                            or string.find(name, "Wreckage", 1, true))
                    if is_pool then
                        if not only_wreckage or string.find(name, "Wreckage", 1, true) then
                            local pos = APISurface.get_object_position(obj)
                            if pos then
                                local dx = p.x - pos.x
                                local dy = p.y - pos.y
                                local dist_sq = dx*dx + dy*dy
                                if dist_sq < search_range_sq and dist_sq < nearest_pool_dist_sq then
                                    nearest_pool_dist_sq = dist_sq
                                    nearest_pool = obj
                                end
                            end
                        end
                    end
                end
            end

            if nearest_pool then
                local pool_pos = APISurface.get_object_position(nearest_pool)
                if pool_pos then
                    -- Check if player is already close enough to cast at pool
                    local dx = p.x - pool_pos.x
                    local dy = p.y - pool_pos.y
                    local dist_to_pool = math.sqrt(dx*dx + dy*dy)

                    if dist_to_pool > (desired_dist + 5) then
                        -- Solve a shoreline standoff position
                        local standoff, _, throttled = ShorelineSolver.solve_shoreline_cached(
                            ctx, now, p, pool_pos,
                            desired_dist, depth_tol, search_range
                        )

                        if standoff and not throttled then
                            APISurface.print("[EaxFishing] Navigating to pool: " .. APISurface.get_object_name(nearest_pool))
                            state.navigation.stop_distance = desired_dist
                            Client.move(ctx, standoff, desired_dist)
                            state.fishing.status = "Moving to pool..."
                            return
                        elseif not standoff and not throttled then
                            state.navigation.shoreline_no_route_count = state.navigation.shoreline_no_route_count + 1
                            if state.navigation.shoreline_no_route_count >= 3 then
                                APISurface.print("[EaxFishing] Could not find shoreline route to pool - fishing in place")
                                state.navigation.shoreline_no_route_count = 0
                            end
                        end
                    else
                        -- In range — face pool to improve cast direction
                        local face_now = now
                        if face_now > (state.navigation.pool_face_update + 2.0) then
                            APISurface.look_at(pool_pos)
                            state.navigation.pool_face_update = face_now
                            state.navigation.pool_face_pos = pool_pos
                        end
                        state.navigation.shoreline_no_route_count = 0
                    end
                end
            end
        end
    end

    -- ========== FISHING LOOP ==========
    local is_active = APISurface.is_casting_spell(me) or APISurface.is_channelling_spell(me)
    local elapsed = now - state.fishing.cast_start_time

    -- Cast if not active and not awaiting bobber (or timeout)
    -- NOTE: timeout raised to 7.0s (above the 6s no-bobber threshold) to prevent
    -- a brief is_active=false lag spike from triggering a double-cast
    if not is_active and (not state.fishing.awaiting_bobber or elapsed > 7.0) then
        state.fishing.awaiting_bobber = false
        reset_bite()

        -- Resolve fishing spell ID using documented API
        if not state.fishing.id then
            state.fishing.id = APISurface.resolve_fishing_spell(deps.constants.SPELLS.FISHING_RANKS)
        end

        -- Cast
        if state.fishing.id then
            local success = APISurface.cast_target_spell(state.fishing.id, me)
            if success then
                state.fishing.cast_start_time = now
                state.fishing.awaiting_bobber = true
                state.session.attempts = state.session.attempts + 1
                state.fishing.last_action_time = now
                state.fishing.status = "Casting..."
                Behavior.apply_random_wait(ctx, 1.0, 2.5)
            else
                state.fishing.failed_cast_count = state.fishing.failed_cast_count + 1
                local retry_delay = 1.5 + math.random() * 1.0
                state.fishing.next_cast_time = now + retry_delay
                state.fishing.last_action_time = now
                state.fishing.status = "Cast failed (retry in " .. string.format("%.1f", retry_delay) .. "s)..."
                APISurface.print("[EaxFishing] Cast failed for spell " .. tostring(state.fishing.id)
                    .. " (attempt " .. state.fishing.failed_cast_count .. ")")
                if state.fishing.failed_cast_count >= 3 then
                    APISurface.print("[EaxFishing] 3 consecutive cast failures - re-resolving spell ID")
                    state.fishing.id = nil
                    state.fishing.failed_cast_count = 0
                end
            end
        else
            state.fishing.status = "No fishing spell found"
        end
        return
    end

    -- Safety: if awaiting bobber but none found after timeout.
    -- Bobber needs time to spawn — give it a generous window before assuming
    -- the cast landed outside water.
    if state.fishing.awaiting_bobber then
        local p = APISurface.get_object_position(me)
        if p then
            local bobber = APISurface.find_bobber(ctx, me, p.x, p.y, p.z)
            if not bobber and elapsed > 6.0 then
                reset_bite()
                state.fishing.awaiting_bobber = false
                state.fishing.no_bobber_count = (state.fishing.no_bobber_count or 0) + 1
                APISurface.print("[EaxFishing] No bobber found after 6s ("
                    .. state.fishing.no_bobber_count .. "/5) — not near water?")
                state.fishing.status = "No bobber — retrying..."

                if state.fishing.no_bobber_count >= 5 then
                    APISurface.print("[EaxFishing] 5 consecutive casts with no bobber — stopping.")
                    state.fishing.no_bobber_count = 0
                    state.fishing.consecutive_catches = 0
                    state.safety.stop_id = state.safety.stop_id + 1
                    state.safety.hard_stop = true
                    if deps.config.menu.enabled and deps.config.menu.enabled.set_state then
                        deps.config.menu.enabled:set_state(false)
                    end
                    Client.stop(ctx)
                end

                Behavior.apply_random_wait(ctx, 2.0, 4.0)
            elseif bobber then
                -- Bobber found — reset the no-bobber counter
                state.fishing.no_bobber_count = 0
            end
        end
    end
end

return M
