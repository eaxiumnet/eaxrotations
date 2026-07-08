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
local Cook = require("fishing/cook")
local Bags = require("inventory/bags")
local Client = require("navigation/client")
local ShorelineSolver = require("navigation/shoreline_solver")
local Stealth = require("core/stealth")
local APISurface = require("core/api_surface")
local Containers = require("fishing/containers")
local MrPinchy   = require("fishing/mr_pinchy")
local AutoSell   = require("inventory/auto_sell")
local AutoDelete = require("inventory/auto_delete")
local QuestTracker = require("fishing/quest_tracker")
local Responder   = require("core/responder")
local Hearth      = require("navigation/hearth")
local Relog       = require("core/relog")
local Conditions  = require("core/conditions")
local SoundMgr    = require("core/sound_manager")
local WaterWalking = require("fishing/water_walking")
local HumanBehaviors = require("core/human_behaviors")

local M = {}

-- Bite state lives in ctx.state.bite and is reset via State.reset_bite(state)

-- =============================================================================
-- Z-DIP BITE-DETECTION FALLBACK
-- =============================================================================
-- Sylvanas' game_object:does_bobber_have_fish() currently always returns false,
-- which leaves the bot looping on a found bobber forever (no catch). The classic
-- reliable WoW fishing-bot signal is the bobber SPLASH: when a fish bites, the
-- bobber dips below its resting water-line. We baseline the bobber's resting Z
-- after it settles post-cast and confirm a bite when it dips past a threshold
-- for a few consecutive ticks. A max bite-window timeout clicks once as a
-- last resort so we never get stuck on a dead bobber.
-- =============================================================================

local DIP_SETTLE_S       = 1.2   -- let the bobber settle before baselining
local DIP_CONFIRM_TICKS  = 2     -- consecutive dip samples to confirm (filters jitter)
local BITE_WINDOW_MAX_S  = 22.0  -- last-resort click window after the bobber appears

--- Z-dip splash fallback. Returns true when a bite is detected (dip confirmed
--- OR max bite window elapsed). Sticky: once confirmed, stays true for this
--- bobber until dip_triggered is cleared on reel-in / new cast.
function M.check_z_dip(state, bobber, now, deps)
    local dip_on = true
    if deps.config.menu.dip_bite_fallback and deps.config.menu.dip_bite_fallback.get_state then
        dip_on = deps.config.menu.dip_bite_fallback:get_state()
    end
    if not dip_on then return false end

    -- Sticky: a bite is already confirmed for this bobber — keep reporting it
    -- so the reaction-window click completes even if the bobber momentarily
    -- rises back toward baseline between ticks.
    if state.fishing.dip_triggered then return true end

    local pos = APISurface.get_object_position(bobber)
    if not pos or type(pos.z) ~= "number" then return false end

    local threshold = 0.10
    if deps.config.menu.dip_threshold and deps.config.menu.dip_threshold.get then
        threshold = (deps.config.menu.dip_threshold:get() or 10) / 100.0
    end

    local debug_on = deps.config.menu.debug and deps.config.menu.debug.get_state
        and deps.config.menu.debug:get_state()

    -- Establish baseline after the bobber settles post-cast.
    if state.fishing.bobber_z_baseline == nil then
        if state.fishing.bobber_found_time == 0 then
            state.fishing.bobber_found_time = now
        end
        if (now - state.fishing.bobber_found_time) < DIP_SETTLE_S then
            return false
        end
        state.fishing.bobber_z_baseline = pos.z
        state.fishing.dip_confirm_count = 0
        if debug_on then
            APISurface.print("[EaxFishing] dip baseline z=" .. string.format("%.3f", pos.z))
        end
        return false
    end

    local delta = state.fishing.bobber_z_baseline - pos.z  -- positive = dipped down

    if delta >= threshold then
        state.fishing.dip_confirm_count = state.fishing.dip_confirm_count + 1
        if debug_on then
            APISurface.print("[EaxFishing] dip sample delta=" .. string.format("%.3f", delta)
                .. " count=" .. state.fishing.dip_confirm_count)
        end
        if state.fishing.dip_confirm_count >= DIP_CONFIRM_TICKS then
            state.fishing.dip_triggered = true
            state.fishing.bobber_z_baseline = nil  -- consume; next cast re-baselines
            if debug_on then APISurface.print("[EaxFishing] Z-dip bite confirmed") end
            return true
        end
    else
        if state.fishing.dip_confirm_count > 0 then
            state.fishing.dip_confirm_count = 0
        end
    end

    -- Last resort: max bite window elapsed with no confirmed dip. Click once to
    -- reel in (catch or empty) so we never loop forever on a dead bobber.
    if state.fishing.bobber_found_time > 0 and not state.fishing.bite_window_timeout_click then
        if (now - state.fishing.bobber_found_time) >= (DIP_SETTLE_S + BITE_WINDOW_MAX_S) then
            state.fishing.bite_window_timeout_click = true
            state.fishing.dip_triggered = true
            if debug_on then
                APISurface.print("[EaxFishing] dip: max bite window elapsed — last-resort click")
            end
            return true
        end
    end

    return false
end

--- Main update tick
function M.tick(ctx)
    local state = ctx.state
    local deps = ctx.deps
    local now = APISurface.now()
    
    -- Sync control panel
    local cp_helper = APISurface.get_control_panel_helper()
    if cp_helper and cp_helper.on_update then
        pcall(cp_helper.on_update, cp_helper, deps.config.menu)
    end
    
    -- Check if enabled
    local enabled = false
    if deps.config.menu.enabled and deps.config.menu.enabled.get_state then
        enabled = deps.config.menu.enabled:get_state()
    end
    
    -- v2.4.1: QoL pause check — skip all fishing if paused via hotkey
    if state.qol and state.qol.paused then
        state.fishing.status = "Paused"
        return
    end

    -- Reset hard_stop when manually disabled then re-enabled
    if not enabled and state.safety.hard_stop then
        state.safety.hard_stop = false
    end
    
    -- v2.4.0: Hearth return check (if hearthing state is active)
    if state.hearth.state == "hearth" or state.hearth.state == "returning" then
        local me_h = APISurface.get_local_player()
        if me_h and APISurface.is_valid(me_h) and not APISurface.is_in_combat(me_h) then
            Hearth.try_return(ctx, me_h, now)
        end
    end

    -- v2.4.0: Disconnect detection (throttled, alert-only)
    if deps.config.menu.auto_relog and deps.config.menu.auto_relog:get_state() then
        Relog.check_disconnect(ctx, now)
    end

    -- v2.4.0: Conditions check (time-of-day window)
    Conditions.update(ctx, now)
    if deps.config.menu.night_fishing_only and deps.config.menu.night_fishing_only:get_state() then
        if not state.conditions.in_fishing_window then
            state.fishing.status = "Waiting for night..."
            return
        end
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
        State.reset_bite(state)
        -- Reset session timer and gold baseline so stats track THIS fishing session
        state.session.start_time = now
        state.session.stats.gold_start = nil
        -- Calculate session end time if a limit is configured (slider in minutes)
        local limit_mins = 0
        if deps.config.menu.session_time_limit and deps.config.menu.session_time_limit.get then
            limit_mins = deps.config.menu.session_time_limit:get()
        end
        if limit_mins > 0 then
            state.session.end_time = now + (limit_mins * 60)
            APISurface.print("[EaxFishing] Session limit: " .. limit_mins .. " min")
        else
            state.session.end_time = 0.0
        end
    end
    state.profile.was_enabled = true

    -- v2.5.0: Auto-loot corpses (runs in parallel with fishing)
    local AutoLoot = require("inventory/auto_loot")
    AutoLoot.update(ctx)

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
    local stealth_mult = Stealth.get_delay_multiplier(ctx, now)
    local action_throttle = (0.75 + math.random() * 0.6) * stealth_mult
    local throttled = now - state.fishing.last_action_time < action_throttle

    -- v2.5.1: verbose status logging gated by the master Debug Logging toggle
    -- (throttled ~1.5s). Prints the values that cause stalls — stealth
    -- multiplier, suspicion, encounters, action throttle — so users can see
    -- why the bot paused.
    local _debug_log = deps and deps.config and deps.config.menu and deps.config.menu.debug
        and deps.config.menu.debug.get_state
        and deps.config.menu.debug:get_state()
    if _debug_log and now >= (state.verbose.next_log_time or 0) then
        state.verbose.next_log_time = now + 1.5
        local thr_rem = state.fishing.last_action_time + action_throttle - now
        APISurface.print(string.format(
            "[EaxFishing][dbg] t=%.1f status=%s stealth=%.2fx susp=%d/5 enc=%d thr=%.2fs await=%s",
            now, tostring(state.fishing.status), stealth_mult,
            state.stealth.suspicion_level or 0, state.stealth.total_encounters or 0,
            thr_rem, tostring(state.fishing.awaiting_bobber)))
    end

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

                    -- Documented bite detection (currently broken on Sylvanas:
                    -- always returns false). Fall back to Z-dip splash detection.
                    local has_fish = APISurface.does_bobber_have_fish(bobber)
                    if not has_fish then
                        has_fish = M.check_z_dip(state, bobber, now, deps)
                    end

                    if has_fish then
                        if not state.bite.pending then
                            state.bite.pending = true
                            state.bite.detected_time = now
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
                            state.bite.reaction_deadline = state.bite.detected_time + reaction_s
                            local allow_escape = deps.config.menu.enable_fish_escape
                                and deps.config.menu.enable_fish_escape:get_state()
                            if allow_escape then
                                -- Scale escape window by behavior too
                                local escape_extra = Behavior.scaled_delay(state, now, 800, 1800, "reaction", deps.config)
                                state.bite.escape_deadline = state.bite.reaction_deadline + escape_extra
                            end
                            local allow_miss = deps.config.menu.enable_missed_catches
                                and deps.config.menu.enable_missed_catches:get_state()
                            if allow_miss and state.fishing.consecutive_catches >= 5 then
                                state.bite.should_miss = math.random() < 0.04
                            end
                            state.fishing.status = "Splash!"
                        end

                        if state.bite.escape_deadline > 0 and now >= state.bite.escape_deadline then
                            APISurface.print("[EaxFishing] Fish got away...")
                            state.fishing.status = "Fish got away..."
                            state.session.escaped = state.session.escaped + 1
                            State.reset_bite(state)
                            state.fishing.consecutive_catches = 0
                            -- v2.4.1: reset catch streak on escape
                            state.qol.catch_streak = 0
                            state.fishing.awaiting_bobber = false
                            state.fishing.next_cast_time = now + (1.5 + math.random() * 1.0)
                            return
                        end

                        if state.bite.should_miss and now >= state.bite.reaction_deadline then
                            APISurface.print("[EaxFishing] ~~~ Deliberate miss (humanizer) ~~~")
                            state.fishing.status = "Deliberate miss..."
                            state.session.misses = state.session.misses + 1
                            State.reset_bite(state)
                            state.fishing.consecutive_catches = 0
                            -- v2.4.1: reset catch streak on miss
                            state.qol.catch_streak = 0
                            state.fishing.awaiting_bobber = false
                            state.fishing.next_cast_time = now + (2.0 + math.random() * 1.5)
                            return
                        end

                        if now < state.bite.reaction_deadline then
                            local wait_ms = (state.bite.reaction_deadline - now) * 1000
                            state.fishing.status = "Splash! (" .. string.format("%.0f", wait_ms) .. "ms)..."
                            return
                        end

                        -- v2.4.3: Human behavior — gaze at bobber before clicking
                        if deps.config.menu.human_behaviors_enabled
                           and deps.config.menu.human_behaviors_enabled:get_state() then
                            if HumanBehaviors.gaze_at_bobber(ctx, me_fast, now) then
                                return
                            end
                        end

                        -- CLICK
                        local success = APISurface.use_object(bobber)
                        if success then
                            state.fishing.last_action_time = now
                            state.fishing.awaiting_bobber = false
                            State.reset_bite(state)
                            state.fishing.consecutive_catches = state.fishing.consecutive_catches + 1
                            state.session.catches = state.session.catches + 1
                            -- v2.4.1: catch streak tracking
                            state.qol.catch_streak = state.qol.catch_streak + 1
                            if state.qol.catch_streak > state.qol.best_catch_streak then
                                state.qol.best_catch_streak = state.qol.catch_streak
                            end
                            -- v2.4.1: play catch sound (if enabled)
                            SoundMgr.play_for_event(ctx, "catch")
                            -- v2.4.0: pool depletion tracking — count catches at current pool
                            state.pool_depletion.catches_at_pool = state.pool_depletion.catches_at_pool + 1
                            state.fishing.status = "Caught! (" .. state.session.catches .. ")"
                            state.fishing.next_cast_time = now + (1.0 + math.random() * 1.5)
                        end
                        return
                    else
                        if state.bite.pending then State.reset_bite(state) end
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

    -- v2.4.1: Auto-pause if HP below threshold (don't fish while dying)
    if deps.config.menu.auto_pause_low_hp and deps.config.menu.auto_pause_low_hp:get_state() then
        local hp_threshold = 20
        if deps.config.menu.auto_pause_hp_threshold and deps.config.menu.auto_pause_hp_threshold.get then
            hp_threshold = deps.config.menu.auto_pause_hp_threshold:get()
        end
        if me and type(me.get_health_percentage) == "function" then
            local ok, hp_pct = pcall(me.get_health_percentage, me)
            if ok and hp_pct and hp_pct < hp_threshold then
                state.fishing.status = "Low HP — paused"
                return
            end
        end
    end

    -- v2.4.3: Face away from nearby player (stealth anti-detection)
    if Stealth.should_face_away(ctx, now) then
        local nearest = Stealth.get_nearest_player(ctx)
        if nearest then
            local my_pos = APISurface.get_object_position(me)
            local their_pos = APISurface.get_object_position(nearest)
            if my_pos and their_pos then
                -- Look in the opposite direction of the player
                local away = {
                    x = my_pos.x - (their_pos.x - my_pos.x),
                    y = my_pos.y - (their_pos.y - my_pos.y),
                    z = my_pos.z,
                }
                APISurface.look_at(away)
            end
        end
    end
    
    -- Handle navigation
    if Client.is_moving(ctx) then
        local dest = Client.get_destination(ctx)
        if dest then
            local p = APISurface.get_object_position(me)
            if p then
                local dx = p.x - dest.x
                local dy = p.y - dest.y
                local stop_dist = state.navigation.stop_distance
                
                if dx*dx + dy*dy <= stop_dist*stop_dist then
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
            -- v2.4.0: Try auto-delete junk before hard-stopping
            if deps.config.menu.auto_delete_junk and deps.config.menu.auto_delete_junk:get_state() then
                if AutoDelete.try_delete_junk(ctx, me, now) then
                    state.fishing.status = "Deleting junk..."
                    Bags.reset_full_confirm(ctx)
                    return
                end
            end
            -- v2.4.0: Try auto-sell junk if vendor is open
            if deps.config.menu.auto_sell_junk and deps.config.menu.auto_sell_junk:get_state() then
                if AutoSell.try_sell_junk(ctx, me, now) then
                    state.fishing.status = "Selling junk..."
                    Bags.reset_full_confirm(ctx)
                    return
                end
            end
            -- v2.4.0: Try auto-hearth if enabled (before hard stop)
            if deps.config.menu.auto_hearth_full and deps.config.menu.auto_hearth_full:get_state() then
                if Hearth.try_hearth(ctx, me, now) then
                    Bags.reset_full_confirm(ctx)
                    return
                end
            end
            Bags.increment_full_confirm(ctx)
            if Bags.get_full_confirm_count(ctx) >= 3 then
                state.fishing.status = "Bags Full - Stopped"
                -- v2.4.1: play bags-full sound
                SoundMgr.play_for_event(ctx, "bags_full")
                state.safety.hard_stop = true
                state.bag.safety_lock_active = true
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

        local auto_equip_on = true
        if deps.config.menu.auto_equip and deps.config.menu.auto_equip.get_state then
            auto_equip_on = deps.config.menu.auto_equip:get_state()
        end
        if auto_equip_on then
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
    local auto_equip_on = true
    if deps.config.menu.auto_equip and deps.config.menu.auto_equip.get_state then
        auto_equip_on = deps.config.menu.auto_equip:get_state()
    end
    if auto_equip_on then
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

    -- v2.4.0: Open containers (clams, chests) between casts to free bag space
    if not state.fishing.awaiting_bobber then
        if deps.config.menu.auto_open_containers and deps.config.menu.auto_open_containers:get_state() then
            if Containers.try_open_one(ctx, me, now) then
                state.fishing.status = "Opening container..."
                state.fishing.last_action_time = now
                return
            end
        end
    end

    -- v2.4.0: Use Mr. Pinchy charge if available (rare TBC catch)
    if not state.fishing.awaiting_bobber then
        if deps.config.menu.auto_pinchy and deps.config.menu.auto_pinchy:get_state() then
            if MrPinchy.try_use(ctx, me, now) then
                state.fishing.status = "Using Mr. Pinchy..."
                state.fishing.last_action_time = now
                return
            end
        end
    end

    -- Try cooking raw fish into buff food (if fire nearby + recipe learned)
    if not state.fishing.awaiting_bobber then
        local cooked = Cook.try_cook(ctx, me, now)
        if cooked then
            state.fishing.last_action_time = now
            return
        end
    end

    -- Apply lure if needed
    if deps.config.menu.auto_lure and deps.config.menu.auto_lure:get_state() then
        if not Lures.has_active_lure(ctx, me, now) then
            if Lures.try_apply_lure(ctx, me, now) then
                state.fishing.status = "Applying lure..."
                state.fishing.last_action_time = now
                return
            else
                local lure, _, _, count = Lures.find_best_lure(ctx)
                state.session.stats.lure_count = count or 0
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
            -- Lure is active — reset the warning flag so it fires again next time lures run out
            state.fishing.no_lure_warned = false
            -- Refresh lure count for HUD while active
            local _, _, _, count = Lures.find_best_lure(ctx)
            state.session.stats.lure_count = count or 0
            -- v2.4.1: Lure expiration warning
            if deps.config.menu.show_lure_timer and deps.config.menu.show_lure_timer:get_state() then
                local remaining = state.lure.assumed_expire_time - now
                if remaining > 0 then
                    local warn_secs = 60
                    if deps.config.menu.lure_expiry_warn_secs and deps.config.menu.lure_expiry_warn_secs.get then
                        warn_secs = deps.config.menu.lure_expiry_warn_secs:get()
                    end
                    if remaining <= warn_secs and not state.qol.lure_expiry_warned then
                        SoundMgr.play_for_event(ctx, "lure_expiring")
                        APISurface.print("[EaxFishing] Lure expiring in " .. math.floor(remaining) .. "s")
                        state.qol.lure_expiry_warned = true
                    end
                end
            end
        end
    end

    -- v2.4.2: Water walking buff (before casting from water)
    if deps.config.menu.auto_water_walking and deps.config.menu.auto_water_walking:get_state() then
        if not state.fishing.awaiting_bobber then
            if WaterWalking.try_apply(ctx, me, now) then
                state.fishing.status = "Applying water walking..."
                state.fishing.last_action_time = now
                return
            end
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
    
    -- v2.4.0: Update quest tracking (throttled, passive)
    QuestTracker.update(ctx, now)

    -- ========== POOL NAVIGATION ==========
    -- If pool tracking is enabled and nav client is available, find the nearest
    -- fish pool and navigate to a shoreline standoff position before casting.
    -- Skip pool navigation when stealth mode detects a nearby player —
    -- pathing like a bot while someone is watching is a dead giveaway.
    local pool_tracking_on = deps.config.menu.pool_tracking
        and deps.config.menu.pool_tracking:get_state()
    local stealth_active = Stealth.get_delay_multiplier(ctx, now) > 1.0

    if pool_tracking_on and not stealth_active and Client.has_client(ctx) and not Client.is_moving(ctx) then
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

            -- Scan objects for the best pool.
            -- Smart ranking: value-weighted scorer when enabled; nearest-pool fallback when disabled.
            local smart_ranking_on = deps.config.menu.smart_pool_ranking
                and deps.config.menu.smart_pool_ranking:get_state()
            local nearest_pool = nil
            if smart_ranking_on then
                local PoolRanker = require("fishing/pool_ranker")
                nearest_pool = PoolRanker.find_best_pool(
                    ctx, me, p, search_range_sq, only_wreckage
                )
            else
                -- Legacy: nearest pool by distance only
                local nearest_dist_sq = math.huge
                local objects = APISurface.get_all_objects()
                for _, obj in ipairs(objects) do
                    if APISurface.is_valid(obj) then
                        local name = APISurface.get_object_name(obj)
                        local is_pool = false
                        if type(name) == "string" then
                            if deps.constants.OBJECTS.POOLS and deps.constants.OBJECTS.POOLS[name] then
                                is_pool = true
                            else
                                is_pool = string.find(name, "Pool", 1, true)
                                    or string.find(name, "School", 1, true)
                                    or string.find(name, "Wreckage", 1, true)
                            end
                        end
                        if is_pool then
                            if not only_wreckage or string.find(name, "Wreckage", 1, true) then
                                -- v2.4.0: quest fish targeting — prefer quest pools
                                local quest_preferred = false
                                if state.quest.quest_fish_id then
                                    quest_preferred = QuestTracker.is_quest_pool(name, state.quest.quest_fish_id)
                                end
                                local pos = APISurface.get_object_position(obj)
                                if pos then
                                    local dx = p.x - pos.x
                                    local dy = p.y - pos.y
                                    local dist_sq = dx*dx + dy*dy
                                    if dist_sq < search_range_sq then
                                        -- Quest pools get a 10x distance bonus (prefer them)
                                        local effective_dist = quest_preferred and (dist_sq / 10) or dist_sq
                                        if effective_dist < nearest_dist_sq then
                                            nearest_dist_sq = effective_dist
                                            nearest_pool = obj
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if nearest_pool then
                -- v2.4.0: Pool depletion detection
                -- Track which pool we're fishing and how many casts we've made.
                -- If casts exceed threshold without catches, skip this pool.
                local pool_guid = nil
                if type(nearest_pool.get_guid) == "function" then
                    local ok, guid = pcall(nearest_pool.get_guid, nearest_pool)
                    if ok and guid then pool_guid = guid end
                end
                if pool_guid ~= state.pool_depletion.current_pool_guid then
                    state.pool_depletion.current_pool_guid = pool_guid
                    state.pool_depletion.casts_at_pool = 0
                    state.pool_depletion.catches_at_pool = 0
                end
                local depl_thresh = 5
                if deps.config.menu.pool_depletion_threshold and deps.config.menu.pool_depletion_threshold.get then
                    depl_thresh = deps.config.menu.pool_depletion_threshold:get()
                end
                if state.pool_depletion.casts_at_pool >= depl_thresh
                   and state.pool_depletion.catches_at_pool == 0
                then
                    APISurface.print("[EaxFishing] Pool appears depleted — skipping to next")
                    -- v2.4.1: play pool-depleted sound
                    SoundMgr.play_for_event(ctx, "pool_depleted")
                    state.pool_depletion.depleted_count = state.pool_depletion.depleted_count + 1
                    state.pool_depletion.current_pool_guid = nil
                    state.pool_depletion.casts_at_pool = 0
                    state.pool_depletion.catches_at_pool = 0
                    state.fishing.status = "Pool depleted, waiting for next..."
                    state.fishing.next_cast_time = now + 3.0
                    return
                end
                local pool_pos = APISurface.get_object_position(nearest_pool)
                if pool_pos then
                    -- Check if player is already close enough to cast at pool
                    local dx = p.x - pool_pos.x
                    local dy = p.y - pool_pos.y
                    local desired_dist_plus_5 = desired_dist + 5

                    if dx*dx + dy*dy > desired_dist_plus_5 * desired_dist_plus_5 then
                        -- Solve a shoreline standoff position (pass pool object for bounding-radius safety)
                        local standoff, _, throttled = ShorelineSolver.solve_shoreline_cached(
                            ctx, now, p, pool_pos, nearest_pool,
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
        State.reset_bite(state)

        -- Resolve fishing spell ID using documented API
        if not state.fishing.id then
            state.fishing.id = APISurface.resolve_fishing_spell(deps.constants.SPELLS.FISHING_RANKS)
        end

        -- Session time limit check (before every cast)
        if state.session.end_time > 0 and now >= state.session.end_time then
            if not state.session.time_limit_warned then
                APISurface.print("[EaxFishing] Session time limit reached — stopping")
                state.session.time_limit_warned = true
            end
            state.fishing.status = "Session limit reached"
            state.safety.hard_stop = true
            state.bag.safety_lock_active = true
            if deps.config.menu.enabled and deps.config.menu.enabled.set_state then
                deps.config.menu.enabled:set_state(false)
            end
            Client.stop(ctx)
            return
        end

        -- Apply a small random yaw jitter so the bobber doesn't land in the exact same spot.
        -- FIXED (v2.3.2): old code treated jitter_deg as YARDS of position offset in a full
        -- 360° circle, which could swing the player all the way around to face the beach.
        -- Now we apply a small ANGULAR offset (±jitter_deg) to the current facing, so the
        -- bobber always goes forward (into the water) with only a small spread.
        if deps.config.menu.cast_jitter_enabled and deps.config.menu.cast_jitter_enabled:get_state() then
            local jitter_deg = 5
            if deps.config.menu.cast_jitter_degrees and deps.config.menu.cast_jitter_degrees.get then
                jitter_deg = deps.config.menu.cast_jitter_degrees:get()
            end
            if jitter_deg > 0 then
                local me_pos = APISurface.get_object_position(me)
                local yaw    = APISurface.get_rotation(me)
                if me_pos and yaw then
                    -- ±jitter_deg converted to radians, applied to current facing
                    local delta_rad = (math.random() * 2 - 1) * math.rad(jitter_deg)
                    local new_yaw   = yaw + delta_rad
                    -- Project 15 yards forward along the new facing
                    local cast_dist = 15.0
                    local target = {
                        x = me_pos.x + math.cos(new_yaw) * cast_dist,
                        y = me_pos.y + math.sin(new_yaw) * cast_dist,
                        z = me_pos.z,
                    }
                    APISurface.look_at(target)
                end
            end
        end

        -- v2.4.3: Human behavior — look around before casting
        if deps.config.menu.human_behaviors_enabled
           and deps.config.menu.human_behaviors_enabled:get_state() then
            if HumanBehaviors.look_around_before_cast(ctx, me, now) then
                return
            end
        end

        -- v2.4.3: Human behavior — idle stare after catch
        if deps.config.menu.human_behaviors_enabled
           and deps.config.menu.human_behaviors_enabled:get_state() then
            if HumanBehaviors.idle_stare_after_catch(ctx, me, now) then
                return
            end
        end

        -- Cast
        if state.fishing.id then
            state.session.attempts = state.session.attempts + 1
            local success = APISurface.cast_target_spell(state.fishing.id, me)
            if success then
                state.fishing.cast_start_time = now
                state.fishing.awaiting_bobber = true
                state.fishing.last_action_time = now
                state.fishing.status = "Casting..."
                -- v2.4.0: cast reliability telemetry
                state.cast_telemetry.success_count = state.cast_telemetry.success_count + 1
                state.cast_telemetry.fail_streak = 0
                -- v2.4.0: pool depletion tracking — increment casts at current pool
                state.pool_depletion.casts_at_pool = state.pool_depletion.casts_at_pool + 1
                -- Fresh cast: clear all Z-dip fallback state so the new bobber
                -- baselines cleanly and a stale dip_triggered doesn't fire a
                -- phantom bite on the new (splash-less) bobber.
                state.fishing.dip_triggered = false
                state.fishing.bobber_z_baseline = nil
                state.fishing.dip_confirm_count = 0
                state.fishing.bobber_found_time = 0.0
                state.fishing.bite_window_timeout_click = false
                Behavior.apply_random_wait(ctx, 1.0, 2.5)
            else
                state.fishing.failed_cast_count = state.fishing.failed_cast_count + 1
                -- v2.4.0: cast reliability telemetry
                state.cast_telemetry.fail_count = state.cast_telemetry.fail_count + 1
                state.cast_telemetry.fail_streak = state.cast_telemetry.fail_streak + 1
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
                State.reset_bite(state)
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
