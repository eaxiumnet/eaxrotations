-- What: Quest state machine for EaxAutoQuester — ties all submodules together
-- When: update() called each on_pre_tick by main.lua; render_debug() each on_render
-- Why: Centralize state transitions: IDLE→NAV/INTERACT/DO_ACTION/WAITING with retry/backoff
-- Safety: All submodules lazy-loaded via pcall; nil-guarded state fields; no math.sqrt()
-- Decision: Standalone state machine (not EaxRotations), uses submodule APIs

-- ============================================================================
-- Hot-path API Caching at Module Load (Pattern 2 from AGENTS.md)
-- ============================================================================

local _core_time = core.time
local _core_log = core.log
local _get_local_player = core.object_manager.get_local_player

-- ============================================================================
-- Static Table Reuse (Pattern 4 from AGENTS.md)
-- ============================================================================

local _t = { n = 0 }

-- ============================================================================
-- Module Table (defined first, exported at end)
-- ============================================================================

local M = {}

-- ============================================================================
-- Submodule References — lazy-loaded via pcall at runtime (not module init)
-- ============================================================================

local _utils = nil
local _menu = nil
local _zygor_reader = nil
local _navigation = nil
local _quest_interaction = nil
local _npc_manager = nil
local _combat_helper = nil

-- ============================================================================
-- State Machine State — nil-guarded defaults
-- ============================================================================

local _state = "IDLE"               -- current state: IDLE, NAV, INTERACT, DO_ACTION, WAITING
local _nav_destination = nil         -- vec3 destination for NAV state
local _nav_retries = 0               -- consecutive nav failure count (max 3)
local _nav_retry_timer = 0           -- core_time when retry becomes allowed
local _action_pause_timer = 0        -- core_time when action pause expires (0.5s after DO_ACTION)
local _area_wait_timer = 0           -- core_time when area wait expires (2s)
local _last_goal_type = nil          -- cached goal type for DO_ACTION state
local _last_step_num = 0             -- last seen step number (detect step changes)
local _debug = false                 -- cached debug flag from menu
local _last_target_valid = false     -- combat tracking: was in combat last tick
local _just_arrived = false          -- set true when NAV arrives, IDLE skips dist check
local _last_hp_warning = 0           -- throttle HP warnings to once per 10s
local _area_fail_count = 0           -- consecutive area interaction failures
local _area_last_target_guid = nil   -- GUID of last brute-force target (detect loops)
local _interact_start_time = 0       -- when INTERACT state was entered (timeout safety net)
local INTERACT_TIMEOUT = 15          -- max seconds in INTERACT before force-exit

-- ============================================================================
-- Nil-Guard Helper (Pattern 14 from AGENTS.md) — safe default for any field
-- ============================================================================

--- @param v any Value to check
--- @param fallback any Default if v is nil
--- @return any v or fallback
local function safe(v, fallback)
    return v or fallback
end

-- ============================================================================
-- Lazy-Load Helpers — all submodules loaded on first use via pcall
-- ============================================================================

local function ensure_utils()
    if not _utils then
        local ok, u = pcall(require, "utils_sylvanas")
        if ok then _utils = u end
    end
    return _utils
end

local function ensure_menu()
    if not _menu then
        local ok, m = pcall(require, "menu_sylvanas")
        if ok then _menu = m end
    end
    return _menu
end

local function ensure_zygor()
    if not _zygor_reader then
        local ok, z = pcall(require, "zygor_reader_sylvanas")
        if ok then _zygor_reader = z end
    end
    return _zygor_reader
end

local function ensure_navigation()
    if not _navigation then
        local ok, n = pcall(require, "navigation_sylvanas")
        if ok then _navigation = n end
    end
    return _navigation
end

local function ensure_quest_interaction()
    if not _quest_interaction then
        local ok, q = pcall(require, "quest_interaction_sylvanas")
        if ok then _quest_interaction = q end
    end
    return _quest_interaction
end

local function ensure_npc_manager()
    if not _npc_manager then
        local ok, n = pcall(require, "npc_manager_sylvanas")
        if ok then _npc_manager = n end
    end
    return _npc_manager
end

local function ensure_combat_helper()
    if not _combat_helper then
        local ok, c = pcall(require, "combat_helper_sylvanas")
        if ok then _combat_helper = c end
    end
    return _combat_helper
end

-- ============================================================================
-- Logging
-- ============================================================================

--- Conditional debug log — only logs when _debug flag is true.
--- @param msg string Message to log
local function debug_log(msg)
    if not _debug then return end
    local utils = ensure_utils()
    if utils then
        utils.debug_log(msg, true)
    end
end

--- Info log with EaxAutoQuester prefix.
--- @param msg string Message to log
local function log(msg)
    local utils = ensure_utils()
    if utils then
        utils.log(msg)
    end
end

-- ============================================================================
-- Frame Detection — lightweight probe without handling
-- Used by IDLE state to detect open UI frames before transitioning to INTERACT
-- ============================================================================

--- Check if any UI frame (loot, gossip, quest detail, trainer, vendor) is open.
--- @return boolean true if any frame is open
local function detect_open_frame()
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
--- @return string next_state
local function state_idle()
    local zygor = ensure_zygor()
    if not zygor then
        debug_log("IDLE: Zygor not available → WAITING")
        return "WAITING"
    end

    -- No active step → WAITING
    if not zygor.has_current_step() then
        debug_log("IDLE: no step → WAITING")
        return "WAITING"
    end

    -- Open UI frame → INTERACT (detect without handling)
    if detect_open_frame() then
        debug_log("IDLE: open frame detected → INTERACT")
        return "INTERACT"
    end

    -- Get current step info
    local step = zygor.get_current_step_info()
    if not step then
        debug_log("IDLE: nil step info → WAITING")
        return "WAITING"
    end

    -- Step already complete → WAITING (wait for next step)
    if step.is_complete then
        debug_log("IDLE: step complete → WAITING")
        return "WAITING"
    end

    -- Track step number changes — reset retries on step transition
    local step_num = safe(step.step_num, 0)
    if step_num ~= _last_step_num then
        _last_step_num = step_num
        _nav_retries = 0
        _last_goal_type = nil
        debug_log("IDLE: new step " .. tostring(step_num))
    end

    -- Find first uncompleted goal
    local goals = safe(step.goals, {})
    local current_goal = nil

    for i = 1, #goals do
        local g = goals[i]
        local complete = false
        if type(g) == "table" then
            complete = safe(g.is_complete, false)
        end
        if not complete then
            current_goal = g
            break
        end
    end

    -- Combat check: if in combat, stop navigation and let EaxRotations handle
    local me = _get_local_player()
    local in_combat = false
    if me then
        local ok, combat = pcall(function() return me:is_in_combat() end)
        in_combat = ok and combat == true
    end

    if in_combat then
        -- Stop any active navigation during combat
        local nav = ensure_navigation()
        if nav and nav.is_navigating and nav.is_navigating() then
            nav.stop()
            debug_log("IDLE: combat detected — stopped navigation")
        end

        -- Target nearest enemy if no target or invalid target
        local combat_h = ensure_combat_helper()
        if combat_h and not combat_h.is_current_target_valid() then
            combat_h.target_and_tag_nearest(30)
        end

        -- Stay in IDLE during combat — EaxRotations handles rotation
        if _last_target_valid ~= in_combat then
            debug_log("IDLE: waiting for combat to end")
        end
        _last_target_valid = in_combat
        return "IDLE"
    end
    _last_target_valid = false

    -- Low HP pause: if out of combat and HP below 30%, wait until regen
    if me then
        local hp_ok, hp_pct = pcall(function()
            local max_hp = me:get_max_health()
            local cur_hp = me:get_health()
            if max_hp and max_hp > 0 and cur_hp then
                return (cur_hp / max_hp) * 100
            end
            return 100
        end)
        if hp_ok and hp_pct and hp_pct < 30 then
            debug_log("IDLE: HP low (" .. math.floor(hp_pct) .. "%) — waiting for regen")
            if not _last_hp_warning or _last_hp_warning + 10.0 < _core_time() then
                _last_hp_warning = _core_time()
                local ns = _G.EaxAutoQuester
                if ns and ns.set_warning then
                    ns.set_warning("HP low (" .. math.floor(hp_pct) .. "%) - waiting for regen", 4.0)
                end
            end
            return "IDLE"
        end
    end

    -- Determine if player needs to move to goal position first
    local wp = zygor.get_current_waypoint_world()

    if current_goal then
        -- Goal found — determine action type
        local action_type = "area"
        if type(current_goal) == "table" then
            action_type = safe(current_goal.type, safe(current_goal.action_type, "area"))
        end
        _last_goal_type = action_type

        -- Check distance to waypoint using :get_position() (game_object has no .x/.y)
        -- Skip check if we just arrived (tolerance mismatch with navigator)
        if not _just_arrived and wp and me then
            local utils = ensure_utils()
            local pos_ok, pos = pcall(function() return me:get_position() end)
            if pos_ok and pos and utils then
                local dist_sq = utils.squared_distance(pos, wp)
                if dist_sq > 625 then  -- 25 yards squared — far enough to re-navigate
                    _nav_destination = wp
                    debug_log("IDLE: goal type=" .. action_type .. ", far from wp → NAV")
                    return "NAV"
                end
            end
        end
        _just_arrived = false

        -- Player at position (or no waypoint) — execute action
        _action_pause_timer = 0
        debug_log("IDLE: goal type=" .. action_type .. " → DO_ACTION")
        return "DO_ACTION"
    end

    -- No uncompleted goal found — navigate to waypoint if available
    if wp then
        _nav_destination = wp
        debug_log("IDLE: nav to wp → NAV")
        return "NAV"
    end

    -- No goal, no waypoint — wait
    debug_log("IDLE: no goal/wp → WAITING")
    return "WAITING"
end

-- ============================================================================
-- State: NAV — Navigate to destination with retry logic
-- ============================================================================

--- Manage navigation to _nav_destination.
--- Calls navigation.update() each tick for stuck detection.
--- Retries up to 3 times (2s pause on stuck, immediate retry on fail).
--- @return string next_state
local function state_nav()
    -- Combat check: stop navigation and let EaxRotations handle
    local me = _get_local_player()
    if me then
        local ok, combat = pcall(function() return me:is_in_combat() end)
        if ok and combat then
            local nav = ensure_navigation()
            if nav then nav.stop() end
            debug_log("NAV: combat detected — stopped navigation")
            return "IDLE"
        end
    end

    local nav = ensure_navigation()
    if not nav then return "IDLE" end

    -- Per-tick update for stuck detection (Pattern 5 from AGENTS.md)
    nav.update()

    local nav_state = nav.get_state()
    local now = _core_time()

    -- Check if retry timer is active and waiting
    if _nav_retry_timer > 0 and now < _nav_retry_timer then
        return "NAV"
    end

    -- Timer expired — restart navigation if needed
    if _nav_retry_timer > 0 and now >= _nav_retry_timer then
        _nav_retry_timer = 0
        if _nav_destination then
            debug_log("NAV: retrying navigation")
            nav.navigate_to(_nav_destination, nil)
        end
        return "NAV"
    end

    -- Check for catastrophic navigation failure — warn and stop
    if nav_state == "FAILED" and _nav_retries == 0 then
        local nav_type = nav.get_nav_type and nav.get_nav_type() or "unknown"
        if nav_type == "simple" or nav_type == nil then
            local ns = _G.EaxAutoQuester
            if ns and ns.set_warning then
                ns.set_warning("Navigation unavailable - check SentinelNavClient", 8.0)
            end
        end
    end

    -- Handle terminal navigation states
    if nav_state == "ARRIVED" then
        debug_log("NAV: arrived")
        _nav_destination = nil
        _nav_retries = 0
        _just_arrived = true
        return "IDLE"
    end

    if nav_state == "FAILED" then
        _nav_retries = _nav_retries + 1
        debug_log("NAV: failed (retry " .. safe(_nav_retries, 0) .. "/3)")

        if _nav_retries >= 3 then
            log("Navigation failed after 3 retries — giving up")
            local ns = _G.EaxAutoQuester
            if ns and ns.set_warning then
                ns.set_warning("Navigation failed repeatedly - check path", 8.0)
            end
            _nav_destination = nil
            _nav_retries = 0
            return "IDLE"
        end

        -- Immediate retry on failure — schedule restart next tick
        _nav_retry_timer = now + 0.1
        return "NAV"
    end

    if nav_state == "STUCK" then
        _nav_retries = _nav_retries + 1
        debug_log("NAV: stuck (retry " .. safe(_nav_retries, 0) .. "/3)")

        if _nav_retries >= 3 then
            log("Navigation stuck after 3 retries — giving up")
            local ns = _G.EaxAutoQuester
            if ns and ns.set_warning then
                ns.set_warning("Character stuck - manual input needed", 10.0)
            end
            _nav_destination = nil
            _nav_retries = 0
            return "IDLE"
        end

        -- 2s pause on stuck
        _nav_retry_timer = now + 2.0
        return "NAV"
    end

    -- Start navigation if not already navigating and destination set
    if nav_state == "IDLE" and _nav_destination then
        debug_log("NAV: starting navigation")
        nav.navigate_to(_nav_destination, nil)
    end

    return "NAV"
end

-- ============================================================================
-- State: INTERACT — Handle open UI frames
-- ============================================================================

--- Process open UI frames via quest_interaction.handle_any_frame().
--- Stays in INTERACT if frame remains open after handling.
--- Force-exits after 15s to prevent infinite frame loops.
--- @return string next_state
local function state_interact()
    -- Safety timeout: force exit INTERACT after 15 seconds
    local now = _core_time()
    if _interact_start_time == 0 then
        _interact_start_time = now
    elseif now - _interact_start_time > INTERACT_TIMEOUT then
        _interact_start_time = 0
        core.log_warning("[EaxAutoQuester] Frame stuck open for 15s - force exiting")
        return "IDLE"
    end

    local interaction = ensure_quest_interaction()
    if not interaction then return "IDLE" end

    -- Handle open frames
    local result = interaction.handle_any_frame()

    if result then
        -- Throttled: frame still being processed, stay in INTERACT
        if result == "quest_throttled" then
            _interact_start_time = _core_time()  -- reset timeout, we're making progress
            return "INTERACT"
        end

        debug_log("INTERACT: handled (" .. tostring(result) .. ")")

        -- Recheck if frame still open
        if detect_open_frame() then
            debug_log("INTERACT: frame still open")
            return "INTERACT"
        end

        -- Frame closed by handling
        debug_log("INTERACT: frame closed → IDLE")
        _interact_start_time = 0
        return "IDLE"
    end

    -- No frame to handle
    _interact_start_time = 0
    debug_log("INTERACT: no frame → IDLE")
    return "IDLE"
end

-- ============================================================================
-- State: DO_ACTION — Execute Zygor goal based on action type
-- ============================================================================

--- Execute a single goal action based on its type.
--- Types: loot/click/use, kill, talk/gossip, area
--- @param action_type string Goal action type
--- @param goal table|number Goal data from Zygor
--- @return boolean true if action was attempted
local function execute_goal_action(action_type, goal)
    local npc = ensure_npc_manager()
    local combat = ensure_combat_helper()

    if action_type == "loot" or action_type == "click" or action_type == "use" then
        -- Find and target interactable object by name
        local obj_name = nil
        if type(goal) == "table" then
            obj_name = safe(goal.text, safe(goal.name, nil))
        end

        if obj_name and npc then
            local objects = npc.find_interactable_objects(obj_name)
            if objects and #objects > 0 then
                local ok = pcall(core.input.set_target, objects[1])
                if ok then
                    debug_log("DO_ACTION: targeted '" .. tostring(obj_name) .. "'")
                end
                return true
            end
        end

        -- Fallback: try to find by goal NPC ID
        if type(goal) == "table" and npc then
            local npc_id = safe(goal.npc_id, safe(goal.id, nil))
            if npc_id then
                local nearest = npc.find_nearest_npc({ npc_id }, 20)
                if nearest then
                    pcall(core.input.set_target, nearest)
                    debug_log("DO_ACTION: targeted NPC " .. tostring(npc_id))
                    return true
                end
            end
        end

        -- No target found
        debug_log("DO_ACTION: no target for " .. action_type)
        return true -- still count as done (will re-evaluate next cycle)
    end

    if action_type == "kill" then
        if combat then
            local tagged = combat.target_and_tag_nearest(50)
            if tagged then
                debug_log("DO_ACTION: tagged enemy for kill")
                return true
            end
        end
        debug_log("DO_ACTION: no enemy to tag")
        return true
    end

    if action_type == "talk" or action_type == "gossip" then
        if npc then
            local npc_ids = npc.find_quest_npcs()
            if npc_ids then
                local nearest = npc.find_nearest_npc(npc_ids, 20)
                if nearest then
                    pcall(core.input.set_target, nearest)
                    debug_log("DO_ACTION: targeted quest NPC for talk")
                    return true
                end
            end
        end
        debug_log("DO_ACTION: no quest NPC to talk to")
        return true
    end

    if action_type == "area" then
        -- Area goal: at the waypoint — check if step advanced, else wait
        local zygor = ensure_zygor()
        if zygor then
            -- Check if step is now complete (Zygor auto-advances on area enter)
            local step = zygor.get_current_step_info()
            if step and step.is_complete then
                debug_log("DO_ACTION: area — step complete, re-evaluating")
                return true
            end
            -- Check if step number changed (Zygor advanced)
            if step and step.step_num and step.step_num ~= _last_step_num then
                _last_step_num = step.step_num
                debug_log("DO_ACTION: area — new step " .. tostring(step.step_num))
                return true
            end
        end

        -- Try to find NPC from goal data (npc_id, target_id, target name)
        local goal_npc_id = nil
        local goal_target = nil
        if type(goal) == "table" then
            goal_npc_id = safe(goal.npc_id, safe(goal.target_id, nil))
            goal_target = safe(goal.target, safe(goal.npc, nil))
        end

        if goal_npc_id then
            -- Look up NPC spawn from database, navigate there
            local npc_db_ok, npc_db = pcall(require, "npc_db_sylvanas")
            if npc_db_ok and npc_db.find_npc_spawn then
                local me = _get_local_player()
                local map_id = nil
                if me then
                    local _, mid = pcall(function() return core.get_map_id() end)
                    if mid then map_id = mid end
                end
                local spawn = npc_db.find_npc_spawn(goal_npc_id, map_id)
                if spawn then
                    local utils = ensure_utils()
                    local _, pos = pcall(function() return me:get_position() end)
                    if pos and utils then
                        local dist_sq = utils.squared_distance(pos, spawn)
                        if dist_sq > 100 then
                            -- NPC is >10yd away — navigate to spawn
                            _nav_destination = { x = spawn.x, y = spawn.y, z = spawn.z }
                            debug_log("DO_ACTION: navigatng to NPC " .. tostring(goal_npc_id) .. " spawn")
                            return false  -- false = not done yet, re-evaluate next cycle
                        end
                    end
                end
            end
            -- At NPC spawn — find and interact
            if npc then
                local nearest = npc.find_nearest_npc({ goal_npc_id }, 15)
                if nearest then
                    pcall(core.input.set_target, nearest)
                    pcall(core.input.interact_with_object, nearest)
                    debug_log("DO_ACTION: area — targeted NPC " .. tostring(goal_npc_id))
                    return true
                end
            end
        end

        if npc and goal_target then
            local objects = npc.find_interactable_objects(goal_target)
            if objects and #objects > 0 then
                pcall(core.input.set_target, objects[1])
                pcall(core.input.interact_with_object, objects[1])
                debug_log("DO_ACTION: area — targeted '" .. tostring(goal_target) .. "'")
                return true
            end
        end

        -- Brute-force scan for nearby NPCs
        local me = _get_local_player()
        if me then
            local _, pos = pcall(function() return me:get_position() end)
            local _, me_guid = pcall(function() return me:get_guid() end)
            if pos then
                local _, objects = pcall(core.object_manager.get_visible_objects)
                if objects and #objects > 0 then
                    local best, best_sq = nil, math.huge
                    local best_guid = nil
                    local limit = #objects > 50 and 50 or #objects
                    for i = 1, limit do
                        local obj = objects[i]
                        if not obj then break end
                        local skip = false
                        if me_guid then
                            local _, guid = pcall(function() return obj:get_guid() end)
                            if guid and guid == me_guid then skip = true end
                        end
                        if not skip then
                            local ok2, unit = pcall(function() return obj:is_unit() end)
                            if not (ok2 and unit) then skip = true end
                        end
                        if not skip then
                            local ok5, is_player = pcall(function() return obj:is_player() end)
                            if ok5 and is_player then skip = true end
                        end
                        if not skip then
                            local ok3, dead = pcall(function() return obj:is_dead() end)
                            if ok3 and dead then skip = true end
                        end
                        if not skip then
                            local ok1, valid = pcall(function() return obj:is_valid() end)
                            if ok1 and valid then
                                local ok4, opos = pcall(function() return obj:get_position() end)
                                if ok4 and opos then
                                    local dx = (opos.x or 0) - (pos.x or 0)
                                    local dy = (opos.y or 0) - (pos.y or 0)
                                    local d_sq = dx * dx + dy * dy
                                    if d_sq < best_sq and d_sq < 100 then
                                        best, best_sq = obj, d_sq
                                        local _, g = pcall(function() return obj:get_guid() end)
                                        if g then best_guid = g end
                                    end
                                end
                            end
                        end
                    end
                    if best then
                        -- Track same-target loops: if we keep targeting the same unit without progress, halt
                        if best_guid and best_guid == _area_last_target_guid then
                            _area_fail_count = _area_fail_count + 1
                        else
                            _area_fail_count = 0
                            _area_last_target_guid = best_guid
                        end
                        if _area_fail_count >= 5 then
                            _area_fail_count = 0
                            _area_last_target_guid = nil
                            core.log_warning("[EaxAutoQuester] Cannot interact with target - manual help required")
                            local ns = _G.EaxAutoQuester
                            if ns and ns.set_warning then
                                ns.set_warning("Stuck - cannot interact with NPC here", 0)
                            end
                            debug_log("DO_ACTION: area — giving up after 5 failed attempts")
                            return true
                        end
                        pcall(core.input.set_target, best)
                        pcall(core.input.interact_with_object, best)
                        debug_log("DO_ACTION: area — targeting nearest unit (attempt " .. _area_fail_count .. ")")
                        return true
                    end
                    -- No target found in scan — reset counter
                    _area_fail_count = 0
                    _area_last_target_guid = nil
                end
            end
        end
        -- Also reset if we fall through to here (no NPC at all)
        _area_fail_count = 0
        _area_last_target_guid = nil
        _area_wait_timer = _core_time() + 3.0
        debug_log("DO_ACTION: area goal — no NPC, waiting")
        return true
    end

    -- Unknown action type — skip
    debug_log("DO_ACTION: unknown type '" .. tostring(action_type) .. "' — skip")
    return true
end

--- Execute the current goal and determine next state.
--- After action, pause 0.5s then transition to IDLE for re-evaluation.
--- Area type waits 2s before returning to IDLE.
--- @return string next_state
local function state_do_action()
    local now = _core_time()

    -- Area wait: hold in DO_ACTION until timer expires
    if _area_wait_timer > 0 then
        if now < _area_wait_timer then
            return "DO_ACTION"
        end
        -- Timer done — proceed
        _area_wait_timer = 0
        debug_log("DO_ACTION: area wait done → IDLE")
        return "IDLE"
    end

    -- General action pause (0.5s after non-area actions)
    if _action_pause_timer > 0 and now < _action_pause_timer then
        return "DO_ACTION"
    end
    _action_pause_timer = 0

    -- Get current step info to find the goal to execute
    local zygor = ensure_zygor()
    if not zygor then return "IDLE" end

    local step = zygor.get_current_step_info()
    if not step then return "IDLE" end

    -- Find first uncompleted goal
    local goals = safe(step.goals, {})
    local current_goal = nil

    for i = 1, #goals do
        local g = goals[i]
        local complete = false
        if type(g) == "table" then
            complete = safe(g.is_complete, false)
        end
        if not complete then
            current_goal = g
            break
        end
    end

    -- No uncompleted goal — back to IDLE to re-evaluate
    if not current_goal then
        debug_log("DO_ACTION: no uncompleted goal → IDLE")
        return "IDLE"
    end

    -- Determine action type from goal or cached value
    local action_type = safe(_last_goal_type, "area")
    if type(current_goal) == "table" then
        action_type = safe(current_goal.type, safe(current_goal.action_type, action_type))
    end

    -- Execute action
    execute_goal_action(action_type, current_goal)

    -- Set 0.5s pause after action before re-evaluating in IDLE
    _action_pause_timer = now + 0.5
    return "IDLE"
end

-- ============================================================================
-- State: WAITING — Poll for Zygor step to appear
-- ============================================================================

--- Recheck Zygor every 3s (throttled via utils.throttle).
--- Transitions to IDLE when a step appears.
--- @return string next_state
local function state_waiting()
    local utils = ensure_utils()

    -- 3s throttle between checks
    if not utils or not utils.throttle("quest_state_waiting", 3.0) then
        return "WAITING"
    end

    local zygor = ensure_zygor()
    if zygor and zygor.has_current_step() then
        debug_log("WAITING: step appeared → IDLE")
        _last_step_num = 0 -- force fresh evaluation
        return "IDLE"
    end

    return "WAITING"
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Called each on_pre_tick — runs current state logic.
--- Reads debug flag from menu each tick.
function M.update()
    -- Ensure utils loaded (needed by most state functions)
    ensure_utils()

    -- Refresh debug flag from menu each tick
    local menu = ensure_menu()
    _debug = menu and menu.get("debug") or false

    -- Dispatch current state with transition tracking
    local next_state = _state

    if _state == "IDLE" then
        next_state = state_idle()
    elseif _state == "NAV" then
        next_state = state_nav()
    elseif _state == "INTERACT" then
        next_state = state_interact()
    elseif _state == "DO_ACTION" then
        next_state = state_do_action()
    elseif _state == "WAITING" then
        next_state = state_waiting()
    end

    -- Log transitions
    if next_state ~= _state then
        debug_log("State: " .. _state .. " → " .. next_state)
        _state = next_state
    end
end

--- Render debug overlay when debug mode is enabled.
--- Shows current state, nav retries, step number, destination, goal type.
function M.render_debug()
    -- Always render navigation visual marker (destination + path)
    local nav = ensure_navigation()
    if nav and nav.render_visual then
        pcall(function() nav.render_visual() end)
    end

    -- Debug text overlay (only when debug log enabled)
    local menu = ensure_menu()
    local debug_enabled = menu and menu.get("debug") or false
    if not debug_enabled then return end

    -- Build debug text using static table (Pattern 4)
    _t.n = 0

    _t.n = _t.n + 1
    _t[_t.n] = "EaxAutoQuester"
    _t.n = _t.n + 1
    _t[_t.n] = "State: " .. _state
    _t.n = _t.n + 1
    _t[_t.n] = "Nav Retries: " .. tostring(safe(_nav_retries, 0)) .. "/3"
    _t.n = _t.n + 1
    _t[_t.n] = "Step: " .. tostring(safe(_last_step_num, 0))

    if _nav_destination then
        _t.n = _t.n + 1
        _t[_t.n] = "Dest: (" ..
            tostring(safe(_nav_destination.x, 0)) .. ", " ..
            tostring(safe(_nav_destination.y, 0)) .. ", " ..
            tostring(safe(_nav_destination.z, 0)) .. ")"
    end

    if _last_goal_type then
        _t.n = _t.n + 1
        _t[_t.n] = "Goal: " .. tostring(_last_goal_type)
    end

    -- Render as on-screen text via core.graphics
    local text = table.concat(_t, "\n", 1, _t.n)
    pcall(function()
        core.graphics.draw_text(10, 10, text)
    end)
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.quest_state = M

return M
