-- What: IDLE state handler — evaluates Zygor step, detects frames, decides next state
-- When: Called by coordinator when shared._state == "IDLE"
-- Why: Centralize all IDLE logic including frame detection, HP/mana gates, distance checks
-- API: exports detect_open_frame() and run(shared, ctx) → next_state string

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

local corpse_loot = require("shared/corpse_loot")
local goal_resolver_ok, goal_resolver = pcall(require, "goal_resolver_sylvanas")
local goal_filter_ok, goal_filter = pcall(require, "goal_filter_sylvanas")
-- Shared owners IDLE asks rather than reimplements:
--   objective_match  — "is this unit the goal's objective?" (ids first, whole names second)
--   nav_destination  — who owns where the bot walks next, incl. the pull gate's claim
--   spawn_patrol     — the spawn-point sweep a respawn wait walks
--   facing           — the one place that may issue a look-at lock
--   pull_safety      — is the bot allowed to start this fight at all (the hold)
local objective_match = require("shared/objective_match")
local nav_destination = require("shared/nav_destination")
local spawn_patrol = require("shared/spawn_patrol")
local facing = require("shared/facing")
local pull_safety = require("shared/pull_safety")

-- Hoisted unit probes (perf pass): every one of these was an inline `pcall(function() ... end)`
-- on the tick path, which built a closure per call — the death check alone cost three per tick,
-- plus one per ghost-aura method it scanned. The probes are module-level, handed their unit as
-- the pcall argument, so the pcall protection and every return value are unchanged.
local function unit_is_dead(u) return u:is_dead() end
local function unit_get_health(u) return u:get_health() end
local function unit_aura_read(u, method) return u[method](u) end
local function unit_is_casting(u) return u:is_casting_spell() end
local function unit_is_channelling(u) return u:is_channelling_spell() end
local function unit_is_in_combat(u) return u:is_in_combat() end
local function unit_get_target(u) return u:get_target() end
local function unit_can_attack(u, other) return u:can_attack(other) end
local function unit_get_position(u) return u:get_position() end
-- (The movement_handler look-at/pause probes that used to live here are gone: shared/facing.lua
--  owns the look-at lock, and a second caller issuing its own was the spin it exists to stop.)

-- The ghost-aura method list was rebuilt as a table literal on every tick; it never changes.
local AURA_METHODS = { "get_buffs", "get_auras", "get_debuffs" }

-- Shared empty-goals default (perf pass): `ctx.safe(step.goals, {})` built a fresh table on every
-- tick in the two places below — the has-active-goal probe and the goal loop — which measured
-- 32.00 B each on the goal-evaluation path. `safe()` only ever RETURNS its default (it never
-- writes to it, coordinator.lua:127), and both call sites only iterate the result, so one shared
-- table is correct as well as cheaper.
local EMPTY_GOALS = {}

-- How long a goal whose targets are all corpses underfoot is left alone. Same value do_action_state
-- uses when the kill lane finds nothing to kill: one wait, two producers.
local RESPAWN_WAIT_SECONDS = 60

-- How long a covered pass over a movement-only step's waypoints is left alone before the sweep
-- starts another one. Without it a completed pass re-issued its whole path on the next tick.
local SWEEP_RELAP_SECONDS = 60

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
    -- Death check FIRST — before the guidance/step gate. A dead or ghosted
    -- player must enter DEAD even when there is no current step, or Zygor is
    -- absent entirely; otherwise the machine parks in WAITING and the corpse
    -- run never starts. (The retired monolith also checked death before its
    -- guidance logic.)
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
            local ok, result = pcall(unit_is_dead, ctx.me)
            is_dead_v = (ok and tostring(result)) or "err"
            if ok and result then dead = true end
        end

        if not dead then
            local hp_ok, hp = pcall(unit_get_health, ctx.me)
            hp_v = (hp_ok and tostring(hp)) or "err"
            if hp_ok then
                if hp == nil or hp <= 0 then dead = true end
            else
                dead = true
            end
        end

        if not dead then
            for _, m in ipairs(AURA_METHODS) do
                if ctx.me[m] then
                    local ok, data = pcall(unit_aura_read, ctx.me, m)
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
        local casting_ok, is_casting = pcall(unit_is_casting, ctx.me)
        local channelling_ok, is_channelling = pcall(unit_is_channelling, ctx.me)
        if (casting_ok and is_casting) or (channelling_ok and is_channelling) then
            return "IDLE"
        end
    end

    -- Combat check first: if in combat, skip frame handling
    local in_combat = false
    if ctx.me then
        local ok, combat = pcall(unit_is_in_combat, ctx.me)
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
            local _, t = pcall(unit_get_target, ctx.me)
            if t then target = t end
            if target then
                -- Close distance if enemy is attacking from range (prevents desync death)
                local ok_att, can_att = pcall(unit_can_attack, target, ctx.me)
                if ok_att and can_att then
                    local _, me_pos = pcall(unit_get_position, ctx.me)
                    local _, t_pos = pcall(unit_get_position, target)
                    if me_pos and t_pos and ctx.utils then
                        local d_sq = ctx.utils.squared_distance(me_pos, t_pos)
                        if d_sq > 100 then  -- 10 yards squared
                            shared._nav_destination = t_pos
                            ctx.debug_log("IDLE: combat — closing distance to enemy (" .. tostring(math.floor(math.sqrt(d_sq))) .. "yd)")
                            return "NAV"
                        end
                    end
                end
                -- Face the enemy through the single owner of facing (shared/facing.lua): one lock
                -- per interval, never at a corpse, and no second writer of the movement handler's
                -- look-at. This used to be an inline pause+look_at every tick, which is the spin.
                facing.ensure(ctx.me, target)
            end
        end
        return "IDLE"
    end
    shared._last_target_valid = false

    -- Pull-safety hold: the gate refused a pull and armed a back-off. IDLE must not undo that by
    -- walking at the mob on the next tick, and when the player is still standing where the refusal
    -- happened it walks the retreat out. `nav_destination.claim` is what applies the gate's intent —
    -- the gate writes no navigation field — and settling it HERE is what stops a destination written
    -- later in the same tick from winning the walk.
    if ctx.me and pull_safety.holding(ctx) then
        if not nav_destination.claim(shared, ctx) then
            -- Holding with nowhere published to back off to: wait the hold out rather than walk on.
            ctx.debug_log("IDLE: pull safety hold — no retreat published, waiting")
            return "IDLE"
        end
        local point = shared._nav_destination
        local pos_ok, pos = pcall(unit_get_position, ctx.me)
        if not (pos_ok and pos and point and ctx.utils) then
            ctx.debug_log("IDLE: pull safety hold — cannot measure the retreat, waiting")
            return "IDLE"
        end
        if ctx.utils.squared_distance(pos, point) <= 25 then
            ctx.debug_log("IDLE: pull safety hold — parked at the retreat")
            return "IDLE"
        end
        ctx.debug_log("IDLE: pull safety hold — walking the retreat out")
        return "NAV"
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
                local goals = ctx.safe(step.goals, EMPTY_GOALS)
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
    elseif ctx.detect_open_frame() or ctx.frame_signalled then
        -- The polling probe, or a quest frame the client announced with a game event
        -- (GOSSIP_SHOW / QUEST_DETAIL / QUEST_PROGRESS / QUEST_COMPLETE / QUEST_GREETING).
        -- The event adds an entry reason only; the polling probe remains the exit check in
        -- INTERACT, so a frame that has closed is still left.
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
        -- A new step is a new path: a waypoint of the old one that the client could not reach says
        -- nothing about the new one, and the sweep starts from scratch (cleared through the owner,
        -- so the retirement stays one field).
        nav_destination.clear_retired(shared)
        shared._sweep_lap_at = 0
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
    local goals = ctx.safe(step.goals, EMPTY_GOALS)
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

    -- Debug: log current goal details. Guarded by the debug flag (perf pass): the concatenation
    -- builds a string on every tick and `debug_log` then discards it when debug is off, which is
    -- the normal case (0.34 B/tick measured even for a short message). Same output when on.
    if shared._debug and current_goal and type(current_goal) == "table" then
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
                        -- Straight to the destination record: the `wp` local is declared much
                        -- further down this function, so this used to write and read a global
                        -- `wp` (a leak that also collided with any sibling plugin using the name).
                        ctx.debug_log("IDLE: flight step to " .. dest .. " → NAV to flight master " .. tostring(fm.name or "?"))
                        shared._nav_destination = fm
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
                    ctx.debug_log("IDLE: hearth-set step → NAV to innkeeper " .. tostring(inn.name or "?"))
                    shared._nav_destination = inn
                    return "NAV"
                end
            end
        end
    end

    -- Respawn wait: if DO_ACTION set a respawn timer, stay near the spawn
    -- point and periodically scan.  Prevents 100fps spam-scans and stuck loops.
    if shared._respawn_wait_until > ctx.now then
        -- Scan every 5 seconds for early respawn. Everything the wait says, it says here: the live
        -- log had "waiting for respawn" four times a second for minutes because the line was outside
        -- the throttle, which is a per-tick concatenation to be discarded.
        local scanned = false
        if ctx.now - (shared._respawn_last_scan or 0) >= 5.0 then
            shared._respawn_last_scan = ctx.now
            scanned = true
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
            -- The enemy probe answers only for attackable hostiles, and it reads one list: a mob
            -- that has come back is the thing being waited for even when that probe is blind to it.
            -- Identity decides — the goal's OWN mobs, never a lookalike under a longer name (live:
            -- waiting on Rock Elemental 92 while killing Lesser Rock Elementals).
            if npc and npc.find_interactable_objects and type(current_goal) == "table" then
                local probe = ctx.safe(current_goal.target, ctx.safe(current_goal.npc, nil))
                if probe and probe ~= "" then
                    local objects = npc.find_interactable_objects(probe, ctx.object_scanner)
                    local matches = objects and objective_match.only(current_goal, objects)
                    for i = 1, #(matches or EMPTY_GOALS) do
                        local ok_dead, dead = pcall(unit_is_dead, matches[i])
                        if not (ok_dead and dead == true) then
                            shared._respawn_wait_until = 0
                            shared._respawn_target_name = nil
                            ctx.debug_log("IDLE: respawn detected — resuming")
                            return "DO_ACTION"
                        end
                    end
                end
            end
        end
        -- The wait is a SEARCH, not a park: it walks the goal mob's own spawn points instead of
        -- standing at one of them. Live, the wait sat at a single point for twelve minutes while
        -- the mob's other seventeen spawns (from the shipped cAoNGOS index) were outside its only
        -- sensor — a 50yd enemy probe fired every 5s. shared/spawn_patrol.lua owns the sweep, and
        -- returns nil while the pull gate holds, so a refused camp is never searched.
        local leg = spawn_patrol.next_point(shared, ctx, current_goal)
        if leg then
            shared._nav_destination = leg
            if scanned then
                ctx.debug_log("IDLE: respawn wait — walking the camp's spawn points")
            end
            return "NAV"
        end
        if scanned then
            ctx.debug_log("IDLE: waiting for respawn" .. (shared._respawn_target_name and " (" .. shared._respawn_target_name .. ")" or ""))
        end
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

        -- Objective-first scan (ported from the monolith's live IDLE path; see
        -- docs/phase1_port_list.md item 1). When the goal names an interactable,
        -- look for it within 50yd BEFORE walking to the step waypoint. In range
        -- (<= 5yd) the waypoint check below is skipped entirely: navigating to a
        -- destination the player is already standing on spins
        -- IDLE->NAV->ARRIVED->IDLE forever, because SentinelNavClient resolves it
        -- instantly and this block re-fires every tick.
        local objective_in_range = false
        -- What the scan saw, for the goal-type branches below: a goal whose only matches are corpses
        -- underfoot is a respawn wait, and a live match is the objective itself.
        local corpse_underfoot = false
        local living_match = false
        if type(current_goal) == "table" and ctx.me and ctx.npc_manager
            and ctx.npc_manager.find_interactable_objects then
            local goal_target = ctx.safe(current_goal.target, ctx.safe(current_goal.npc, nil))
            if goal_target and goal_target ~= "" then
                -- Zygor pluralizes names ("Bundles of Wood"), so try the singular
                -- of the first word and of the whole string too.
                local names_to_try = {}
                for name in goal_target:gmatch("[^,]+") do
                    local trimmed = name:match("^%s*(.-)%s*$")
                    if trimmed and trimmed ~= "" then
                        names_to_try[#names_to_try + 1] = trimmed
                    end
                end
                local name_count = #names_to_try
                for i = 1, name_count do
                    local name = names_to_try[i]
                    local first_word = name:match("^(%S+)")
                    if first_word and first_word:sub(-1) == "s" then
                        names_to_try[#names_to_try + 1] =
                            name:gsub("^" .. first_word, first_word:sub(1, -2), 1)
                    end
                    if name:sub(-1) == "s" then
                        local singular = name:sub(1, -2)
                        if singular ~= "" then
                            names_to_try[#names_to_try + 1] = singular
                        end
                    end
                end

                local pos_ok, pos = pcall(unit_get_position, ctx.me)
                local best_obj = nil
                local best_dist_sq = 2500  -- 50yd squared
                if pos_ok and pos and ctx.utils then
                    for _, name in ipairs(names_to_try) do
                        local objects = ctx.npc_manager.find_interactable_objects(name, ctx.object_scanner)
                        if objects then
                            -- IDENTITY, not similarity: the name lookup is a substring match, so
                            -- "Lesser Rock Elemental" answers for "Rock Elemental". The scan must
                            -- not call a lookalike "my objective", and it must not act on a corpse:
                            -- a dead match underfoot used to report the objective "in range (0yd)"
                            -- forever while the bot stood in the corpse pile it had just made.
                            local matches = objective_match.only(current_goal, objects)
                            if matches then
                                for i = 1, #matches do
                                    local obj = matches[i]
                                    local ok_opos, opos = pcall(unit_get_position, obj)
                                    if ok_opos and opos then
                                        local dsq = ctx.utils.squared_distance(pos, opos)
                                        local ok_dead, dead = pcall(unit_is_dead, obj)
                                        dead = ok_dead and dead == true
                                        if dead then
                                            if dsq <= 100 then corpse_underfoot = true end
                                        else
                                            living_match = true
                                            if dsq < best_dist_sq then
                                                best_dist_sq = dsq
                                                best_obj = obj
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if best_obj then
                    local ok_opos, opos = pcall(unit_get_position, best_obj)
                    if ok_opos and opos then
                        -- Game objects often report z=0, which is off the navmesh;
                        -- fall back to the player's own Z.
                        if (opos.z or 0) == 0 and pos and pos.z then
                            opos = { x = opos.x, y = opos.y, z = pos.z }
                        end
                        -- Stop where this class fights from, not at melee range: combat_helper owns
                        -- the band (28yd for a caster, 3yd for everyone else). The band rides along
                        -- as the destination's stand-off so nav_state stops the walk there.
                        local in_range_sq = 25
                        local ch = ctx.combat_helper
                        if ch and ch.engage_distance_sq then
                            local ok_band, band = pcall(ch.engage_distance_sq, ctx.me)
                            if ok_band and type(band) == "number" and band > 0 then
                                in_range_sq = band
                            end
                        end
                        if best_dist_sq <= in_range_sq then
                            objective_in_range = true
                            ctx.debug_log("IDLE: objective-first '" .. tostring(goal_target) ..
                                "' in range (" .. tostring(math.floor(math.sqrt(best_dist_sq))) ..
                                "yd) - skip NAV")
                        else
                            shared._nav_destination = opos
                            if in_range_sq > 9 then
                                shared._nav_engage_sq = in_range_sq
                                shared._nav_engage_dest = opos
                            end
                            ctx.debug_log("IDLE: objective-first '" .. tostring(goal_target) ..
                                "' found at " .. tostring(math.floor(math.sqrt(best_dist_sq))) .. "yd -> NAV")
                            return "NAV"
                        end
                    end
                end
            end
        end

        -- Check distance to waypoint using :get_position() (game_object has no .x/.y)
        -- Skip check if we just arrived (tolerance mismatch with navigator) or if
        -- the objective is already in interaction range.
        if not objective_in_range and not shared._just_arrived and wp and ctx.me then
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
            if has_target and corpse_underfoot and not living_match then
                -- Everything this goal names is a corpse where the bot is standing: there is nothing
                -- here to kill or use, so acting again would only re-enter DO_ACTION once a tick
                -- (the freeze). Wait for the mobs to come back instead.
                if (shared._respawn_wait_until or 0) == 0 then
                    shared._respawn_wait_until = ctx.now + RESPAWN_WAIT_SECONDS
                    shared._respawn_target_name = ctx.safe(current_goal.target, nil)
                    if shared._debug then
                        ctx.debug_log("IDLE: '" .. tostring(shared._respawn_target_name) ..
                            "' is a corpse underfoot and nothing alive matches — waiting for respawn")
                    end
                end
                return "IDLE"
            end

            if not has_target then
                local zygor_module = ctx.zygor
                local all_wps = zygor_module and zygor_module.get_step_waypoints_world and zygor_module.get_step_waypoints_world()
                if all_wps and #all_wps > 0 and ctx.me then
                    local visited = shared._visited_waypoints or {}
                    local pos_ok, pos = pcall(unit_get_position, ctx.me)
                    if pos_ok and pos and ctx.utils then
                        local best_wp = nil
                        local best_dist_sq = 1e9
                        local best_idx = nil
                        for i = 1, #all_wps do
                            local candidate = all_wps[i]
                            -- A waypoint the client could not walk to is skipped and retired FOR THE
                            -- STEP (shared/nav_destination.lua owns the set) instead of being offered
                            -- again. Without this the producer re-issued the same coordinates every
                            -- second — IDLE -> NAV -> "arrived but still 13yd away" -> IDLE — and the
                            -- step's other waypoints were never covered, so the bot appeared to walk
                            -- between the one or two points the navmesh actually reaches. The 60s
                            -- memory behind it expires; the retirement is what keeps the skip alive
                            -- for this pass, and a new step (or a new pass) clears it.
                            if not visited[i] and not nav_destination.place_retired(shared, candidate) then
                                if nav_destination.recently_unreachable(shared, ctx.now, candidate) then
                                    -- The refusal is recorded against the PLACE and nothing else:
                                    -- `visited` is keyed by the slot the reader happened to return, and
                                    -- a refusal does not say anything about whatever waypoint ends up
                                    -- in that slot later in the pass.
                                    if nav_destination.retire_place(shared, candidate) then
                                        ctx.debug_log("IDLE: area goal — wp " .. tostring(i) .. "/" ..
                                            tostring(#all_wps) .. " is unreachable — retiring it for this step")
                                    end
                                else
                                    local d_sq = ctx.utils.squared_distance(pos, candidate)
                                    if d_sq < best_dist_sq then
                                        best_dist_sq = d_sq
                                        best_wp = candidate
                                        best_idx = i
                                    end
                                end
                            end
                        end
                        -- Persist the marks: the sweep is read back from shared next tick, and an
                        -- expired memory must not resurrect a waypoint this pass already refused.
                        shared._visited_waypoints = visited
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
                        elseif (shared._sweep_lap_at or 0) == 0 then
                            -- The pass is over: nothing left to walk to. Two ways to get here —
                            -- every reachable waypoint was covered, or every waypoint was refused by
                            -- the client — and they answer differently, because only the first has
                            -- something for the guide to do at these coordinates.
                            shared._sweep_lap_at = ctx.now
                            if nav_destination.retired_count(shared) >= #all_wps then
                                ctx.debug_log("IDLE: area goal — none of the " .. tostring(#all_wps) ..
                                    " step waypoints is reachable — waiting for the retry")
                                return "WAITING"
                            end
                            ctx.debug_log("IDLE: area goal — all " .. tostring(#all_wps) ..
                                " waypoints covered — handing over to the guide")
                            return "DO_ACTION"
                        elseif ctx.now - shared._sweep_lap_at < SWEEP_RELAP_SECONDS then
                            -- Between passes the state waits instead of marching. This is the other
                            -- half of "moves between 2 waypoints": a covered pass used to re-issue
                            -- its whole path on the very next tick, so a step the guide had not
                            -- finished became an endless march over the same points.
                            return "WAITING"
                        else
                            -- A new pass. The marks go with it, so a waypoint the client refused is
                            -- retried once per pass — at most once a minute — rather than never: a
                            -- transient refusal of a real part of the path must not retire it for
                            -- the whole step.
                            shared._visited_waypoints = {}
                            nav_destination.clear_retired(shared)
                            shared._sweep_lap_at = 0
                            ctx.debug_log("IDLE: area goal — re-patrolling the step's waypoints")
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

        -- Kill goal with a valid target already engaged: stay in IDLE and let the
        -- rotation fight. Re-entering DO_ACTION re-tags every cycle, which thrashes
        -- the target and can pull extra mobs. (Ported: docs/phase1_port_list.md item 2.)
        if action_type == "kill" and ctx.combat_helper
            and ctx.combat_helper.is_current_target_valid
            and ctx.combat_helper.is_current_target_valid(50) then
            ctx.debug_log("IDLE: kill goal — target already valid, holding")
            return "IDLE"
        end

        -- Respect the pause DO_ACTION set for the previous action. The modular path
        -- used to zero it here, which quietly bypassed the 0.5s pacing entirely.
        -- (Ported: docs/phase1_port_list.md item 3.)
        local action_pause_until = shared._action_pause_timer or 0
        if action_pause_until > 0 and ctx.now < action_pause_until then
            return "IDLE"
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
