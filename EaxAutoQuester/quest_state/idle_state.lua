-- What: IDLE state handler — evaluates Zygor step, detects frames, decides next state
-- When: Called by coordinator when shared._state == "IDLE"
-- Why: Centralize all IDLE logic including frame detection, HP/mana gates, distance checks
-- API: exports detect_open_frame() and run(shared, ctx) → next_state string

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

local corpse_loot = require("shared/corpse_loot")
local goal_resolver_ok, goal_resolver = pcall(require, "EaxAutoQuester/goal_resolver_sylvanas")
local goal_filter_ok, goal_filter = pcall(require, "EaxAutoQuester/goal_filter_sylvanas")

-- ============================================================================
-- Frame Detection — lightweight probe without handling
-- Used by IDLE state to detect open UI frames before transitioning to INTERACT
-- Also used by INTERACT state (via ctx.detect_open_frame) to check if frame closed
-- ============================================================================

--- Check if any UI frame (loot, gossip, quest detail, trainer, vendor) is open.
--- @return boolean true if any frame is open
function M.detect_open_frame()
    -- Loot frame: check item count
    local ok, loot_count = pcall(core.game_ui.get_loot_item_count)
    if ok and loot_count and loot_count > 0 then return true end

    -- Gossip frame: check if gossip is shown
    local ok2, gossip = pcall(core.quests.is_gossip_frame_shown)
    if ok2 and gossip then return true end

    -- Quest detail/reward frame: probe reward link
    local ok3, link = pcall(core.quests.get_quest_item_link, "choice", 1)
    if ok3 and link and link ~= "" then return true end

    -- Also check for reward money (alternative quest frame indicator)
    local ok3b, reward_money = pcall(core.quests.get_reward_money)
    if ok3b and reward_money and reward_money > 0 then return true end

    -- Trainer frame: check service count
    local ok4, num = pcall(core.quests.get_num_trainer_services)
    if ok4 and num and num > 0 then return true end

    -- Vendor frame: check vendor item count
    local ok5, vendor = pcall(core.game_ui.get_vendor_item_count)
    if ok5 and vendor and vendor > 0 then return true end

    return false
end

-- ============================================================================
-- State: IDLE — Evaluate current Zygor step and decide next state
-- ============================================================================

--- Read Zygor step info and determine transition.
--- Transitions: WAITING (no step), INTERACT (open frame),
---              NAV (waypoint far), DO_ACTION (goal at position)
--- @param shared table Shared state variables
--- @param ctx table Per-tick context with submodules, me, helpers
--- @return string next_state
function M.run(shared, ctx)
    local zygor = ctx.zygor
    if not zygor then
        ctx.debug_log("IDLE: Zygor not available → WAITING")
        return "WAITING"
    end

    -- No active step → WAITING
    if not zygor.has_current_step() then
        ctx.debug_log("IDLE: no step → WAITING")
        return "WAITING"
    end

    -- Cast/channel pause: if the player is mid-cast or mid-channel (e.g. after
    -- clicking a gathering node like "Milly's Harvest"), the bot must stay in
    -- IDLE and NOT move, re-target, or re-interact. Any of those would cancel
    -- the cast/channel and break the quest. Live observed: Milly's Harvest
    -- pumpkins in Northshire Valley require a 2-3s channel to gather the
    -- quest item. Re-targeting the pumpkin cancels the channel and the quest
    -- never progresses.
    if ctx.me then
        local casting_ok, is_casting = pcall(function() return ctx.me:is_casting_spell() end)
        local channelling_ok, is_channelling = pcall(function() return ctx.me:is_channelling_spell() end)
        if (casting_ok and is_casting) or (channelling_ok and is_channelling) then
            return "IDLE"
        end
    end

    -- Death check: if player is dead, transition to DEAD state.
    -- Checks is_dead() AND HP. Handles ghost-form: ghost players have
    -- is_dead()=false but get_health() returns nil (no body, no health).
    -- The old logic missed ghost-form deaths because `hp and hp <= 0`
    -- is false when hp is nil. Now: is_dead() OR HP<=0 OR HP=nil OR
    -- get_health() throws → DEAD. Live bug: bot stuck in IDLE for 100+
    -- ticks after dying (ghost form), spamming "HP low (0%) — waiting for
    -- regen" instead of navigating to corpse.
    if ctx.me then
        local dead = false
        local is_dead_v = nil
        local hp_v = nil
        local buff_api = "none"
        local ghost_found = false

        if ctx.me.is_dead then
            local ok, result = pcall(function() return ctx.me:is_dead() end)
            is_dead_v = (ok and tostring(result)) or "err"
            if ok and result then dead = true end
        end

        if not dead then
            local hp_ok, hp = pcall(function() return ctx.me:get_health() end)
            hp_v = (hp_ok and tostring(hp)) or "err"
            if hp_ok then
                if hp == nil or hp <= 0 then dead = true end
            else
                dead = true
            end
        end

        if not dead then
            local aura_methods = { "get_buffs", "get_auras", "get_debuffs" }
            for _, m in ipairs(aura_methods) do
                if ctx.me[m] then
                    local ok, data = pcall(function() return ctx.me[m](ctx.me) end)
                    if ok and data then
                        for i = 1, #data do
                            local b = data[i]
                            if b then
                                local id = b.buff_id or b.id or b.spell_id or b.aura_id or "?"
                                if id == 8326 or id == "8326" then
                                    ghost_found = true
                                    dead = true
                                    buff_api = m
                                end
                            end
                        end
                    end
                end
            end
        end

        if dead then
            ctx.debug_log("IDLE: player dead → DEAD")
            return "DEAD"
        end
    end

    -- Combat check first: if in combat, skip frame handling
    local in_combat = false
    if ctx.me then
        local ok, combat = pcall(function() return ctx.me:is_in_combat() end)
        in_combat = ok and combat == true
    end
    if in_combat then
        local nav = ctx.nav
        if nav and nav.is_navigating and nav.is_navigating() then
            nav.stop()
            ctx.debug_log("IDLE: combat — stopped navigation")
        end
        shared._interact_cooldown = 0
        if ctx.me then
            local target = nil
            local _, t = pcall(function() return ctx.me:get_target() end)
            if t then target = t end
            if target then
                -- Close distance if enemy is attacking from range (prevents desync death)
                local ok_att, can_att = pcall(function() return target:can_attack(ctx.me) end)
                if ok_att and can_att then
                    local _, me_pos = pcall(function() return ctx.me:get_position() end)
                    local _, t_pos = pcall(function() return target:get_position() end)
                    if me_pos and t_pos and ctx.utils then
                        local d_sq = ctx.utils.squared_distance(me_pos, t_pos)
                        if d_sq > 100 then  -- 10 yards squared
                            shared._nav_destination = t_pos
                            ctx.debug_log("IDLE: combat — closing distance to enemy (" .. tostring(math.floor(math.sqrt(d_sq))) .. "yd)")
                            return "NAV"
                        end
                    end
                end
                local mh_ok, mh = pcall(require, "common/utility/movement_handler")
                if mh_ok and mh and mh.look_at_target then
                    if mh.pause_movement_light then
                        pcall(function() mh:pause_movement_light(0.5) end)
                    end
                    pcall(function() mh:look_at_target(0.5, 0, target) end)
                end
            end
        end
        return "IDLE"
    end
    shared._last_target_valid = false

    -- Quest log maintenance: auto-abandon grey quests when log is bloated
    do
        local qm_ok, qm = pcall(require, "quest_log_manager_sylvanas")
        if qm_ok and qm and qm.maintenance_check then
            pcall(qm.maintenance_check)
        end
    end

    -- Check for an active quest goal early — determines autoloot behavior.
    -- When a quest is active, the bot should only loot corpses it passes by
    -- (within 5yd), not chase distant corpses. Chasing distant corpses while a
    -- quest is active causes loops: loot corpse A → approach quest → find corpse
    -- B → loot B → approach quest → find corpse C → ... (live observed with
    -- Milly's Harvest goal in Northshire Valley).
    local has_active_goal = false
    do
        local zygor = ctx.zygor
        if zygor and zygor.has_current_step and zygor.has_current_step() then
            local step = zygor.get_current_step_info and zygor.get_current_step_info()
            if step and not step.is_complete then
                local goals = ctx.safe(step.goals, {})
                for i = 1, #goals do
                    local g = goals[i]
                    local complete = false
                    if type(g) == "table" then
                        complete = ctx.safe(g.is_complete, false)
                    end
                    if not complete then
                        has_active_goal = true
                        break
                    end
                end
            end
        end
    end

    -- Autoloot: check for nearby corpses (up to 20yd). Even with an active quest,
    -- auto-loot corpses that are close by. The "stay near quest object" flag
    -- (shared._at_quest_object_timer) prevents deviation from just-clicked quest
    -- objects, so autoloot NAV won't fight the quest objective.
    if not in_combat then
        local result = corpse_loot.try_loot_nearest_corpse(shared, ctx, 400, "[autoloot]")
        if result then return result end
    end

    -- Open UI frame → INTERACT (detect without handling)
    -- Skip if cooldown active (prevents immediate re-entry after timeout)
    if shared._interact_cooldown > 0 then
        if ctx.now < shared._interact_cooldown then
            -- throttle log to once per 5s
            if (not shared._last_cooldown_log) or ctx.now - shared._last_cooldown_log > 5.0 then
                shared._last_cooldown_log = ctx.now
                ctx.debug_log("IDLE: frame cooldown active (" .. tostring(math.floor(shared._interact_cooldown - ctx.now)) .. "s left)")
            end
        else
            shared._interact_cooldown = 0
        end
    elseif ctx.detect_open_frame() then
        ctx.debug_log("IDLE: open frame detected → INTERACT")
        return "INTERACT"
    end

    -- Get current step info
    local step = zygor.get_current_step_info()
    if not step then
        ctx.debug_log("IDLE: nil step info → WAITING")
        return "WAITING"
    end

    -- Step already complete → WAITING (wait for next step)
    if step.is_complete then
        shared._respawn_wait_until = 0
        shared._respawn_target_name = nil
        ctx.debug_log("IDLE: step complete → WAITING")
        return "WAITING"
    end

    -- Track step number changes — reset retries on step transition
    local step_num = ctx.safe(step.step_num, 0)
    if step_num ~= shared._last_step_num then
        shared._last_step_num = step_num
        shared._nav_retries = 0
        shared._last_goal_type = nil
        shared._area_fail_count = 0
        shared._area_last_target_guid = nil
        shared._visited_waypoints = {}
        shared._respawn_wait_until = 0
        shared._respawn_target_name = nil
        -- Reset progress tracking on step change
        do
            local pt_ok, pt = pcall(require, "progress_tracker_sylvanas")
            if pt_ok and pt and pt.clear_all then pt.clear_all() end
        end
        ctx.debug_log("IDLE: new step " .. tostring(step_num))
    end

    -- Find first uncompleted goal
    local goals = ctx.safe(step.goals, {})
    local current_goal = nil

    for i = 1, #goals do
        local g = goals[i]
        local complete = false
        if type(g) == "table" then
            complete = ctx.safe(g.is_complete, false)
        end
        if not complete then
            -- Item C: class/level/faction filter
            local passes = true
            if goal_filter_ok and goal_filter and goal_filter.passes then
                local ok, result = pcall(goal_filter.passes, g, ctx.me)
                if ok then passes = result end
            end
            if passes then
                current_goal = g
                break
            end
        end
    end

    -- Debug: log current goal details
    if current_goal and type(current_goal) == "table" then
        local g_text = tostring(current_goal.text or current_goal.name or "nil")
        local g_npc = tostring(current_goal.npc_id or current_goal.target_id or "nil")
        local g_target = tostring(current_goal.target or current_goal.npc or "nil")
        ctx.debug_log("IDLE: goal[" .. tostring(step_num) .. "] text=" .. g_text .. " npc_id=" .. g_npc .. " target=" .. g_target)
    end

    -- Low HP / Mana pause: DISABLED. The user reported the HP check was
    -- preventing the bot from dying naturally — at 76% HP, the bot would
    -- wait for regen instead of fighting, and could never reach the
    -- death state. The death check at the top of this function handles
    -- the 0% case. Now the bot fights at any HP/mana level. Disabled
    -- via `if false and ...` so the original logic is preserved as a
    -- reference but never executes.
    if false and ctx.me then
        local hp_ok, hp_pct = pcall(function()
            local max_hp = ctx.me:get_max_health()
            local cur_hp = ctx.me:get_health()
            if max_hp and max_hp > 0 and cur_hp then
                return (cur_hp / max_hp) * 100
            end
            return 100
        end)
        if hp_ok and hp_pct and hp_pct < 80 then
            if (not shared._last_hp_warning) or ctx.now - shared._last_hp_warning > 5.0 then
                shared._last_hp_warning = ctx.now
                if hp_pct == 0 then
                    ctx.debug_log("IDLE: player dead — waiting for resurrection")
                else
                    ctx.debug_log("IDLE: HP low (" .. math.floor(hp_pct) .. "%) — waiting for regen")
                end
                local ns = _G.EaxAutoQuester
                if ns and ns.set_warning then
                    ns.set_warning("HP low (" .. math.floor(hp_pct) .. "%) - waiting", 4.0)
                end
            end
            return "IDLE"
        end

        -- Mana check: wait until > 80% (use power type 0 = MANA)
        local mana_ok, mana_pct = pcall(function()
            local max_mp = ctx.me:get_max_power(0)
            local cur_mp = ctx.me:get_power(0)
            if max_mp and max_mp > 0 and cur_mp then
                return (cur_mp / max_mp) * 100
            end
            return nil
        end)
        if mana_ok and mana_pct and mana_pct < 80 then
            if (not shared._last_mana_warning) or ctx.now - shared._last_mana_warning > 5.0 then
                shared._last_mana_warning = ctx.now
                ctx.debug_log("IDLE: Mana low (" .. math.floor(mana_pct) .. "%) — waiting for regen")
            end
            return "IDLE"
        end
    end

    -- Post-interact pause: after clicking a quest object (set by DO_ACTION),
    -- stay in IDLE briefly (0.3s) for the server round-trip before the next
    -- state evaluation. Longer interaction waits (gather channel, etc.) are
    -- handled by the cast/channel pause at the top of this function.
    if shared._post_interact_timer and shared._post_interact_timer > ctx.now then
        return "IDLE"
    end

    -- "At quest object" flag: after clicking a quest object, for 30s the bot
    -- ignores the waypoint distance check. This prevents the back-and-forth
    -- loop (click → NAV to waypoint → NAV back → click) that occurred when
    -- the waypoint check fired immediately after the click. The bot commits
    -- to the quest object for 30s, giving the interaction time to complete
    -- (gather channel, server round-trip, etc.). After 30s, if the quest
    -- still hasn't progressed, the click genuinely failed and the bot will
    -- try again.
    if shared._at_quest_object_timer and shared._at_quest_object_timer > ctx.now then
        return "IDLE"
    end

    -- Flight path step detection: if step says "Fly to X", find nearest
    -- flight master and navigate there instead of the normal waypoint.
    do
        local fp_ok, fp = pcall(require, "flight_path_sylvanas")
        if fp_ok and fp and step and step.text then
            local dest = fp.extract_destination(step.text)
            if dest then
                local npc_db_ok, npc_db = pcall(require, "npc_db_sylvanas")
                if npc_db_ok and npc_db and npc_db.find_transport_npc then
                    local map_id = 0
                    local ok_map, mid = pcall(core.get_map_id)
                    if ok_map then map_id = mid or 0 end
                    local fm = npc_db.find_transport_npc("flight", map_id)
                    if fm then
                        local wf_ok, wf = pcall(require, "waypoint_fixer_sylvanas")
                        if wf_ok and wf and wf.fix_z then
                            fm = wf.fix_z(fm) or fm
                        end
                        wp = fm
                        ctx.debug_log("IDLE: flight step to " .. dest .. " → NAV to flight master " .. tostring(fm.name or "?"))
                        shared._nav_destination = wp
                        return "NAV"
                    end
                end
            end
        end
    end

    -- Hearth-set step detection: if step says "Set your Hearthstone to X",
    -- find nearest innkeeper and navigate there.
    do
        local svc_ok, svc = pcall(require, "service_gossip_sylvanas")
        if svc_ok and svc and step and step.text and svc.step_requires_hearth(step.text) then
            local npc_db_ok, npc_db = pcall(require, "npc_db_sylvanas")
            if npc_db_ok and npc_db and npc_db.find_transport_npc then
                local map_id = 0
                local ok_map, mid = pcall(core.get_map_id)
                if ok_map then map_id = mid or 0 end
                local inn = npc_db.find_transport_npc("inn", map_id)
                if inn then
                    local wf_ok, wf = pcall(require, "waypoint_fixer_sylvanas")
                    if wf_ok and wf and wf.fix_z then
                        inn = wf.fix_z(inn) or inn
                    end
                    wp = inn
                    ctx.debug_log("IDLE: hearth-set step → NAV to innkeeper " .. tostring(inn.name or "?"))
                    shared._nav_destination = wp
                    return "NAV"
                end
            end
        end
    end

    -- Respawn wait: if DO_ACTION set a respawn timer, stay near the spawn
    -- point and periodically scan.  Prevents 100fps spam-scans and stuck loops.
    if shared._respawn_wait_until > ctx.now then
        -- Scan every 5 seconds for early respawn
        if ctx.now - (shared._respawn_last_scan or 0) >= 5.0 then
            shared._respawn_last_scan = ctx.now
            local npc = ctx.npc_manager
            if npc and npc.get_nearest_enemy then
                local enemy = npc.get_nearest_enemy(50, ctx.object_scanner)
                if enemy then
                    shared._respawn_wait_until = 0
                    shared._respawn_target_name = nil
                    ctx.debug_log("IDLE: respawn detected — resuming")
                    return "DO_ACTION"
                end
            end
        end
        ctx.debug_log("IDLE: waiting for respawn" .. (shared._respawn_target_name and " (" .. shared._respawn_target_name .. ")" or ""))
        return "IDLE"
    elseif shared._respawn_wait_until > 0 and shared._respawn_wait_until <= ctx.now then
        -- Timer expired — retry
        shared._respawn_wait_until = 0
        shared._respawn_target_name = nil
        ctx.debug_log("IDLE: respawn wait expired — retrying objective")
    end

    -- Determine if player needs to move to goal position first
    local wp = zygor.get_current_waypoint_world()

    -- Fix Z on waypoint: map→world conversion often returns z=0 (underground).
    -- Use waypoint_fixer to raycast the real terrain height.
    if wp then
        local wf_ok, wf = pcall(require, "waypoint_fixer_sylvanas")
        if wf_ok and wf and wf.fix_z then
            wp = wf.fix_z(wp) or wp
        end
    end

    -- Item A: goal_resolver integration - use NPC DB position if available
    if current_goal and goal_resolver_ok and goal_resolver and goal_resolver.resolve_goal then
        local ok, res = pcall(goal_resolver.resolve_goal, current_goal, step_num, ctx.me)
        if ok and res and res.position then
            wp = res.position
            ctx.debug_log("IDLE: using resolved position from " .. tostring(res.source))
        end
    end

    -- Z sanity check: if destination Z is 0 (likely underground) and player is
    -- at a non-zero Z, the waypoint is probably broken. Use player Z as fallback.
    -- This is a last-chance guard before navigation; waypoint_fixer already
    -- attempted terrain-height correction, but raycasts can still return 0.
    if wp and (wp.z or 0) == 0 then
        local me_ok, me = pcall(core.object_manager.get_local_player)
        if me_ok and me then
            local pos_ok, me_pos = pcall(me.get_position, me)
            if pos_ok and me_pos and me_pos.z and math.abs(me_pos.z) > 5 then
                wp = { x = wp.x, y = wp.y, z = me_pos.z }
                ctx.debug_log("IDLE: waypoint Z was 0, using player Z fallback")
            end
        end
    end

    if current_goal then
        -- Goal found — determine action type
        local action_type = "area"
        if type(current_goal) == "table" then
            action_type = ctx.safe(current_goal.type, ctx.safe(current_goal.action_type, "area"))
        end
        shared._last_goal_type = action_type

        if shared._nav_destination and ctx.me then
            local pos_ok, pos = pcall(function() return ctx.me:get_position() end)
            if pos_ok and pos and ctx.utils then
                local dist_sq = ctx.utils.squared_distance(pos, shared._nav_destination)
                if dist_sq > 25 then
                    ctx.debug_log("IDLE: goal type=" .. action_type .. ", approaching target → NAV")
                    return "NAV"
                end
            end
            shared._nav_destination = nil
        end

        -- Check distance to waypoint using :get_position() (game_object has no .x/.y)
        -- Skip check if we just arrived (tolerance mismatch with navigator)
        if not shared._just_arrived and wp and ctx.me then
            local pos_ok, pos = pcall(function() return ctx.me:get_position() end)
            if pos_ok and pos and ctx.utils then
                local dist_sq = ctx.utils.squared_distance(pos, wp)
                if dist_sq > 1600 then
                    shared._nav_destination = wp
                    ctx.debug_log("IDLE: goal type=" .. action_type .. ", far from wp → NAV")
                    return "NAV"
                end
            end
        end
        shared._just_arrived = false

        -- Player at position (or no waypoint) — execute action
        if action_type == "area" and shared._area_wait_timer > 0 and ctx.now < shared._area_wait_timer then
            ctx.debug_log("IDLE: area wait active, staying in IDLE")
            return "IDLE"
        end
        -- Movement-only area goal: no target to interact with, just need to be here.
        -- Use Zygor step waypoints to walk through them sequentially.
        if action_type == "area" then
            local has_target = false
            if type(current_goal) == "table" then
                local npc_id = ctx.safe(current_goal.npc_id, 0)
                local target = ctx.safe(current_goal.target, "")
                local text = ctx.safe(current_goal.text, "")
                if npc_id and npc_id ~= 0 then has_target = true end
                if target and target ~= "" then has_target = true end
                if text and text ~= "" then has_target = true end
            end
            if not has_target then
                local zygor_module = ctx.zygor
                local all_wps = zygor_module and zygor_module.get_step_waypoints_world and zygor_module.get_step_waypoints_world()
                if all_wps and #all_wps > 0 and ctx.me then
                    local visited = shared._visited_waypoints or {}
                    local pos_ok, pos = pcall(function() return ctx.me:get_position() end)
                    if pos_ok and pos and ctx.utils then
                        local best_wp = nil
                        local best_dist_sq = 1e9
                        local best_idx = nil
                        for i = 1, #all_wps do
                            if not visited[i] then
                                local d_sq = ctx.utils.squared_distance(pos, all_wps[i])
                                if d_sq < best_dist_sq then
                                    best_dist_sq = d_sq
                                    best_wp = all_wps[i]
                                    best_idx = i
                                end
                            end
                        end
                        if best_wp then
                            if best_dist_sq > 100 then
                                shared._nav_destination = best_wp
                                ctx.debug_log("IDLE: area goal — navigating to wp " .. tostring(best_idx) .. "/" .. tostring(#all_wps) .. " (" .. tostring(math.floor(math.sqrt(best_dist_sq))) .. "yd)")
                                return "NAV"
                            else
                                visited[best_idx] = true
                                shared._visited_waypoints = visited
                                ctx.debug_log("IDLE: area goal - reached wp " .. tostring(best_idx) .. "/" .. tostring(#all_wps))
                                return "IDLE"
                            end
                        else
                            ctx.debug_log("IDLE: area goal — all " .. tostring(#all_wps) .. " waypoints visited")
                            shared._visited_waypoints = {}
                            return "DO_ACTION"
                        end
                    end
                elseif wp and ctx.me then
                    local pos_ok, pos = pcall(function() return ctx.me:get_position() end)
                    if pos_ok and pos and ctx.utils then
                        local dist_sq = ctx.utils.squared_distance(pos, wp)
                        if dist_sq > 1600 then
                            shared._nav_destination = wp
                            ctx.debug_log("IDLE: area goal with no target, far from wp → NAV")
                            return "NAV"
                        end
                    end
                end
                ctx.debug_log("IDLE: area goal with no target - waiting for Zygor to mark complete")
                return "WAITING"
            end
        end

        shared._action_pause_timer = 0
        shared._area_fail_count = 0
        shared._area_last_target_guid = nil
        ctx.debug_log("IDLE: goal type=" .. action_type .. " → DO_ACTION")
        return "DO_ACTION"
    end

    -- No uncompleted goal — check for lootable corpses (any distance)
    if not in_combat then
        local result = corpse_loot.try_loot_nearest_corpse(shared, ctx)
        if result then return result end
    end

    -- No uncompleted goal found — navigate to waypoint if available
    if wp then
        shared._nav_destination = wp
        -- Attempt to mount before long-distance travel
        do
            local mm_ok, mm = pcall(require, "mount_manager_sylvanas")
            if mm_ok and mm and mm.try_mount then
                mm.try_mount(ctx.me, wp)
            end
        end
        ctx.debug_log("IDLE: nav to wp → NAV")
        return "NAV"
    end

    -- No goal, no waypoint — wait
    ctx.debug_log("IDLE: no goal/wp → WAITING")
    return "WAITING"
end

return M
