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
local _last_cooldown_log = 0         -- throttle cooldown log spam
local _area_fail_count = 0           -- consecutive area interaction failures
local _area_last_target_guid = nil   -- GUID of last brute-force target (detect loops)
local _interact_start_time = 0       -- when INTERACT state was entered (timeout safety net)
local INTERACT_TIMEOUT = 15          -- max seconds in INTERACT before force-exit
local _last_wait_log_time = 0        -- throttle IDLE waiting log spam
local _interact_cooldown = 0         -- don't re-enter INTERACT until this time
local _action_loop_count = 0         -- consecutive DO_ACTION cycles (progressive backoff)
local _last_action_type = ""         -- previous action type (loop detection)
local _death_location = nil          -- where player died (vec3), for ghost run-back
local _death_location_saved = false  -- flag: death location saved this death
local GHOST_BUFF_ID = 8326           -- Ghost aura

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
    if ok2 and gossip then
        _core_log("[EaxAutoQuester-DEBUG] detect_open_frame: gossip frame detected")
        return true
    end

    -- Quest detail/reward frame: probe reward link
    local ok3, link = pcall(core.quests.get_quest_item_link, "choice", 1)
    if ok3 and link and link ~= "" then
        _core_log("[EaxAutoQuester-DEBUG] detect_open_frame: quest reward frame detected")
        return true
    end

    -- Also check for reward money (alternative quest frame indicator)
    local ok3b, reward_money = pcall(core.quests.get_reward_money)
    if ok3b and reward_money and reward_money > 0 then
        _core_log("[EaxAutoQuester-DEBUG] detect_open_frame: quest money frame detected")
        return true
    end

    -- Quest gossip frame: check if there are available or active quests
    local ok4a, available = pcall(core.quests.get_gossip_available_quests)
    if ok4a and available and #available > 0 then
        _core_log("[EaxAutoQuester-DEBUG] detect_open_frame: quest gossip available detected (" .. #available .. " quests)")
        return true
    end
    local ok4b, active = pcall(core.quests.get_gossip_active_quests)
    if ok4b and active and #active > 0 then
        _core_log("[EaxAutoQuester-DEBUG] detect_open_frame: quest gossip active detected (" .. #active .. " quests)")
        return true
    end

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

    -- Combat check first: if in combat, skip frame handling
    local me = _get_local_player()
    local in_combat = false
    if me then
        local ok, combat = pcall(function() return me:is_in_combat() end)
        in_combat = ok and combat == true
    end
    if in_combat then
        local nav = ensure_navigation()
        if nav and nav.is_navigating and nav.is_navigating() then
            nav.stop()
            debug_log("IDLE: combat — stopped navigation")
        end
        _interact_cooldown = 0  -- reset cooldown during combat
        return "IDLE"
    end
    _last_target_valid = false

    -- Open UI frame → INTERACT (detect without handling)
    -- Skip if cooldown active (prevents immediate re-entry after timeout)
    if _interact_cooldown > 0 then
        if _core_time() < _interact_cooldown then
            -- throttle log to once per 5s
            if not _last_cooldown_log or _core_time() - _last_cooldown_log > 5.0 then
                _last_cooldown_log = _core_time()
                debug_log("IDLE: frame cooldown active (" .. tostring(math.floor(_interact_cooldown - _core_time())) .. "s left)")
            end
        else
            _interact_cooldown = 0
        end
    elseif detect_open_frame() then
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
        _action_loop_count = 0
        _last_action_type = ""
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

    -- Low HP pause: if out of combat and HP below threshold, wait until regen
    if me then
        local hp_ok, hp_pct = pcall(function()
            local max_hp = me:get_max_health()
            local cur_hp = me:get_health()
            if max_hp and max_hp > 0 and cur_hp then
                return (cur_hp / max_hp) * 100
            end
            return 100
        end)
        local menu = ensure_menu()
        local min_hp = menu and menu.get("min_hp", 80) or 80
        if hp_ok and hp_pct and hp_pct < min_hp then
            -- Reset death recovery state when alive (HP>0, not ghost)
            if hp_pct > 0 then
                local _, ghost = pcall(function() return me:has_buff(GHOST_BUFF_ID) end)
                if not ghost and (_death_location or _death_location_saved) then
                    log("Resurrected — resuming questing")
                    _death_location = nil
                    _death_location_saved = false
                end
            end

            -- Death recovery: triggers on hp=0 OR ghost state (ghost has ~1 HP, not 0)
            local _, is_death_ghost = pcall(function() return me:has_buff(GHOST_BUFF_ID) end)
            if hp_pct == 0 or is_death_ghost then
                -- Save death location once per death
                if not _death_location_saved then
                    local _, dpos = pcall(function() return me:get_position() end)
                    if dpos then
                        _death_location = { x = dpos.x, y = dpos.y, z = dpos.z }
                        _death_location_saved = true
                        local utils = ensure_utils()
                        log("Died at " .. (utils and utils.vec3_to_string(_death_location) or tostring(_death_location.x .. "," .. _death_location.y)))
                    end
                end

                if is_death_ghost then
                    -- Ghost mode: navigate to corpse, then safe-resurrect
                    local _, gpos = pcall(function() return me:get_position() end)
                    if gpos and _death_location then
                        local utils = ensure_utils()
                        if utils then
                            local dist_sq = utils.squared_distance(gpos, _death_location)
                            if dist_sq > 25 then
                                local nav = ensure_navigation()
                                if nav and not nav.is_navigating() then
                                    _nav_destination = { x = _death_location.x, y = _death_location.y, z = _death_location.z }
                                    debug_log("DEATH: ghost — running to corpse (" .. math.floor(math.sqrt(dist_sq)) .. "yd)")
                                    return "NAV"
                                end
                            else
                                -- Near corpse — check safety before resurrecting
                                local safe = true
                                local _, objs = pcall(core.object_manager.get_visible_objects)
                                if objs then
                                    local limit = #objs > 50 and 50 or #objs
                                    for i = 1, limit do
                                        local obj = objs[i]
                                        if obj then
                                            local uok, is_unit = pcall(function() return obj:is_unit() end)
                                            if uok and is_unit then
                                                local dok, dead = pcall(function() return obj:is_dead() end)
                                                if not (dok and dead) then
                                                    local eok, is_enemy = pcall(function() return obj:is_enemy_with(me) end)
                                                    if eok and is_enemy then
                                                        local pok, opos = pcall(function() return obj:get_position() end)
                                                        if pok and opos then
                                                            local dsq = utils.squared_distance(gpos, opos)
                                                            if dsq < 2025 then
                                                                safe = false
                                                                break
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                if safe then
                                    pcall(core.input.retrieve_corpse)
                                    debug_log("DEATH: ghost — resurrecting (safe)")
                                else
                                    debug_log("DEATH: ghost — enemies near corpse, waiting")
                                    if not _last_hp_warning or _core_time() - _last_hp_warning > 5.0 then
                                        _last_hp_warning = _core_time()
                                        log("Enemies near corpse — waiting for them to move")
                                    end
                                end
                            end
                        end
                    end
                else
                    -- At corpse, not yet released — release spirit
                    pcall(core.input.release_spirit)
                    debug_log("DEATH: releasing spirit")
                end

                local ns = _G.EaxAutoQuester
                if ns and ns.set_warning and (not _last_hp_warning or _core_time() - _last_hp_warning > 10.0) then
                    _last_hp_warning = _core_time()
                    ns.set_warning("Died — auto-recovering", 4.0)
                end
                return "IDLE"
            end

            -- HP low but alive (>0%) — wait for regen
            if not _last_hp_warning or _core_time() - _last_hp_warning > 5.0 then
                _last_hp_warning = _core_time()
                debug_log("IDLE: HP low (" .. math.floor(hp_pct) .. "%) — waiting for regen (min: " .. math.floor(min_hp) .. "%)")
                local ns = _G.EaxAutoQuester
                if ns and ns.set_warning then
                    ns.set_warning("HP low (" .. math.floor(hp_pct) .. "%) - waiting (min: " .. math.floor(min_hp) .. "%)", 4.0)
                end
            end
            return "IDLE"
        end

        -- Mana check: DISABLED for questing. At 76% mana the bot would wait
        -- indefinitely for regen instead of gathering Bundle of Wood nodes.
        -- Gathering/collecting quests do not require mana. Re-enable only if
        -- combat rotations prove unreliable at low mana.
        if false then
        local min_mana = menu and menu.get("min_mana", 80) or 80
        local mana_ok, mana_pct = pcall(function()
            local max_mp = me:get_max_power(0)
            local cur_mp = me:get_power(0)
            if max_mp and max_mp > 0 and cur_mp then
                return (cur_mp / max_mp) * 100
            end
            return nil
        end)
        if mana_ok and mana_pct and mana_pct < min_mana then
            debug_log("IDLE: Mana low (" .. math.floor(mana_pct) .. "%) — waiting for regen (min: " .. math.floor(min_mana) .. "%)")
            return "IDLE"
        end
        end
    end

    -- Determine if player needs to move to goal position first
    local wp = zygor.get_current_waypoint_world()

    -- Fix Z on waypoint: map→world conversion often returns z=0 (underground).
    -- SentinelNavClient can't path to z=0 — it returns "Position not on navmesh".
    -- Use player Z as fallback when waypoint Z is 0 or near 0.
    if wp then
        local wf_ok, wf = pcall(require, "waypoint_fixer_sylvanas")
        if wf_ok and wf and wf.fix_z then
            wp = wf.fix_z(wp) or wp
        end
    end
    if wp and (wp.z or 0) == 0 and me then
        local _, pos = pcall(function() return me:get_position() end)
        if pos and pos.z and math.abs(pos.z) > 5 then
            wp = { x = wp.x, y = wp.y, z = pos.z }
            debug_log("IDLE: waypoint Z was 0, using player Z fallback (z=" .. tostring(math.floor(pos.z)) .. ")")
        end
    end

    if current_goal then
        -- Goal found — determine action type (Zygor uses .action, .type, or .action_type)
        local action_type = "area"
        if type(current_goal) == "table" then
            action_type = safe(current_goal.type, safe(current_goal.action_type, safe(current_goal.action, "area")))
        end
        _last_goal_type = action_type

        -- Objective-first: before walking to the waypoint, scan for quest objects
        -- by name within 50yd. If found, navigate directly to the closest object.
        -- This avoids the "walk to waypoint, then look for objects" loop.
        local goal_target = nil
        if type(current_goal) == "table" then
            goal_target = safe(current_goal.target, safe(current_goal.npc, safe(current_goal.text, nil)))
        end
        if goal_target and me then
            local npc = ensure_npc_manager()
            if npc then
                -- Plural→singular fallback: Zygor pluralizes names ("Bundles of Wood")
                local names_to_try = {}
                for name in goal_target:gmatch("[^,]+") do
                    local trimmed = name:match("^%s*(.-)%s*$")
                    if trimmed and trimmed ~= "" then
                        names_to_try[#names_to_try + 1] = trimmed
                    end
                end
                local n = #names_to_try
                for i = 1, n do
                    local name = names_to_try[i]
                    local first_word = name:match("^(%S+)")
                    if first_word and first_word:sub(-1) == "s" then
                        local singular_first = name:gsub("^" .. first_word, first_word:sub(1, -2), 1)
                        names_to_try[#names_to_try + 1] = singular_first
                    end
                    if name:sub(-1) == "s" then
                        local singular = name:sub(1, -2)
                        if singular ~= "" then
                            names_to_try[#names_to_try + 1] = singular
                        end
                    end
                end

                local utils = ensure_utils()
                local _, pos = pcall(function() return me:get_position() end)
                local best_obj = nil
                local best_dist_sq = 2500  -- 50yd squared
                for _, name in ipairs(names_to_try) do
                    local objects = npc.find_interactable_objects(name)
                    if objects then
                        for _, obj in ipairs(objects) do
                            local _, opos = pcall(function() return obj:get_position() end)
                            if opos and pos and utils then
                                local dsq = utils.squared_distance(pos, opos)
                                if dsq < best_dist_sq then
                                    best_dist_sq = dsq
                                    best_obj = obj
                                end
                            end
                        end
                    end
                end

                if best_obj then
                    local dist_yds = math.floor(math.sqrt(best_dist_sq))
                    local _, opos = pcall(function() return best_obj:get_position() end)
                    if opos then
                        -- Fix Z on object position too (game objects can have z=0)
                        if (opos.z or 0) == 0 and pos and pos.z then
                            opos = { x = opos.x, y = opos.y, z = pos.z }
                        end
                        _nav_destination = opos
                        debug_log("IDLE: objective-first '" .. tostring(goal_target) .. "' found at " .. tostring(dist_yds) .. "yd → NAV")
                        return "NAV"
                    end
                end
            end
        end

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

        -- Kill goal: if already have a valid target, stay IDLE for EaxRotations
        if action_type == "kill" then
            local combat_helper = ensure_combat_helper()
            if combat_helper and combat_helper.is_current_target_valid(50) then
                return "IDLE"
            end
        end

        -- Player at position (or no waypoint) — decide next action
        -- Respect DO_ACTION pause timer: don't re-enter before it expires
        if _action_pause_timer > 0 and _core_time() < _action_pause_timer then
            local remain_ms = math.floor((_action_pause_timer - _core_time()) * 1000)
            -- Throttle log spam: only log once per second
            if not _last_wait_log_time or _core_time() - _last_wait_log_time >= 1.0 then
                _last_wait_log_time = _core_time()
                debug_log("IDLE: waiting (" .. tostring(remain_ms) .. "ms) before next action")
            end
            return "IDLE"
        end
        _last_wait_log_time = 0
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

    -- Continuous side scan: pre-tag quest mobs while navigating (every 1.5s)
    local utils = ensure_utils()
    if utils and utils.throttle("nav_target_scan", 1.5) then
        local zygor = ensure_zygor()
        local me2 = _get_local_player()
        if zygor and me2 then
            local _, combat = pcall(function() return me2:is_in_combat() end)
            if not combat and zygor.has_current_step and zygor.has_current_step() then
                local step = zygor.get_current_step_info()
                if step and step.goals then
                    for _, g in ipairs(step.goals) do
                        if not g.is_complete then
                            local nid = (g.npc_id and g.npc_id > 0) and g.npc_id or ((g.target_id and g.target_id > 0) and g.target_id or nil)
                            if nid then
                                local npc = ensure_npc_manager()
                                if npc then
                                    local nearest = npc.find_nearest_npc({ nid }, 50)
                                    if nearest then
                                        pcall(core.input.set_target, nearest)
                                        pcall(core.input.interact_with_object, nearest)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Anti-cheat: random jump every 10-25s while navigating
    if utils and utils.throttle("random_jump_nav", math.random(10, 25)) then
        pcall(core.input.jump)
    end

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
            _nav_destination = nil  -- pending dest consumed; next ARRIVED/FAILED handled below
        end
        return "NAV"
    end

    -- Handle terminal navigation states.
    -- SentinelNavClient's on_sentinel_arrived leaves the nav module in ARRIVED
    -- indefinitely after the first arrival. If a NEW destination is pending,
    -- reset the module and re-arm ONCE; the pending dest is consumed so a
    -- subsequent ARRIVED (e.g. already at the spot) falls through to IDLE
    -- instead of re-arming every tick (the awaiting_path->arrived->idle spin).
    if nav_state == "ARRIVED" then
        if _nav_destination then
            nav.stop()
            nav.navigate_to(_nav_destination, nil)
            _nav_destination = nil  -- consumed; next ARRIVED -> IDLE
            debug_log("NAV: re-arming after stale ARRIVED")
        else
            debug_log("NAV: arrived")
            _nav_destination = nil
            _nav_retries = 0
            _just_arrived = true
            _action_pause_timer = _core_time() + 1.5  -- brief pause so NPC can render
            return "IDLE"
        end
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

        -- Progressive stuck recovery (escalating actions)
        if _nav_retries == 1 then
            pcall(core.input.jump)
        elseif _nav_retries == 2 then
            pcall(core.input.jump)
            if math.random(2) == 1 then
                pcall(core.input.turn_left_start)
                pcall(core.input.turn_left_stop)  -- brief tap
            else
                pcall(core.input.turn_right_start)
                pcall(core.input.turn_right_stop)
            end
        end

        _nav_retry_timer = now + 2.0
        return "NAV"
    end

    -- Start navigation if not already navigating and destination set
    if nav_state == "IDLE" and _nav_destination then
        debug_log("NAV: starting navigation")
        nav.navigate_to(_nav_destination, nil)
        _nav_destination = nil  -- pending dest consumed; ARRIVED/FAILED handled above
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
        _interact_cooldown = now + 5.0
        -- Force close all frames before exiting
        pcall(function() core.quests.close_quest() end)
        pcall(function() core.quests.close_gossip() end)
        pcall(core.input.close_loot)
        pcall(core.log_warning, "[EaxAutoQuester] Frame stuck - manual intervention may be needed")
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
        -- Permanently gave up on this frame — force exit with cooldown
        if result == "quest_giveup" then
            _interact_start_time = 0
            _interact_cooldown = _core_time() + 10.0
            debug_log("INTERACT: gave up on quest frame → IDLE (10s cooldown)")
            return "IDLE"
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
            -- Skip re-tagging if already in combat with a valid target
            if combat.is_current_target_valid(50) then
                debug_log("DO_ACTION: already fighting — target valid, skip re-tag")
                return true
            end
            -- Prefer quest-specific mob by NPC ID (e.g. Elder Stranglethorn Tiger over generic tiger)
            local goal_npc_id = nil
            if type(goal) == "table" then
                local raw_id = goal.npc_id or goal.target_id
                goal_npc_id = (raw_id and raw_id > 0) and raw_id or nil
            end
            if npc and goal_npc_id then
                local nearest = npc.find_nearest_npc({ goal_npc_id }, 50)
                if nearest then
                    pcall(core.input.set_target, nearest)
                    pcall(core.input.interact_with_object, nearest)
                    local _, npos = pcall(function() return nearest:get_position() end)
                    if npos then pcall(core.input.look_at_3d, npos) end
                    debug_log("DO_ACTION: kill — targeted quest NPC " .. tostring(goal_npc_id))
                    return true
                end
            end
            -- Last resort: any nearest enemy
            local tagged = combat.target_and_tag_nearest(50)
            if tagged then
                debug_log("DO_ACTION: tagged enemy for kill (generic)")
                return true
            end
        end
        debug_log("DO_ACTION: no enemy to tag")
        return true
    end

    if action_type == "talk" or action_type == "gossip" then
        if npc then
            -- DEBUG: log full goal structure
            _core_log("[EaxAutoQuester-DEBUG] talk: goal type=" .. type(goal) .. " keys=" .. (type(goal)=="table" and table.concat((function() local k={} for a,b in pairs(goal) do k[#k+1]=tostring(a) end return k end)(),",") or "nil"))
            -- Try 1: find by quest NPC IDs (Questie/Zygor data)
            local npc_ids = npc.find_quest_npcs()
            if npc_ids then
                _core_log("[EaxAutoQuester-DEBUG] talk: found " .. tostring(#npc_ids) .. " quest NPC IDs")
                local nearest = npc.find_nearest_npc(npc_ids, 50)
                if nearest then
                    local _, nname = pcall(function() return nearest:get_name() end)
                    -- Check distance before interacting (squared, no math.sqrt)
                    local me_pos_ok, me_pos = pcall(function() return me:get_position() end)
                    local npc_pos_ok, npc_pos = pcall(function() return nearest:get_position() end)
                    local dist_yds = nil
                    if me_pos_ok and me_pos and npc_pos_ok and npc_pos then
                        local dx = (me_pos.x or 0) - (npc_pos.x or 0)
                        local dy = (me_pos.y or 0) - (npc_pos.y or 0)
                        dist_yds = math.floor(math.sqrt(dx*dx + dy*dy))
                        if dist_yds > 6 then
                            _core_log("[EaxAutoQuester-DEBUG] talk: NPC '" .. tostring(nname or "?") .. "' at " .. tostring(dist_yds) .. "yd — too far, navigating closer")
                            local utils = ensure_utils()
                            if utils and utils.move_to then
                                pcall(function() utils.move_to(npc_pos) end)
                            end
                            return true
                        end
                    end
                    local st_ok, st_err = pcall(core.input.set_target, nearest)
                    local int_ok, int_err = pcall(core.input.interact_with_object, nearest)
                    _core_log("[EaxAutoQuester-DEBUG] talk: set_target=" .. tostring(st_ok) .. " interact=" .. tostring(int_ok) .. " dist=" .. tostring(dist_yds) .. "yd name='" .. tostring(nname or "?") .. "'")
                    if int_ok then
                        local qi = ensure_quest_interaction()
                        if qi and qi.handle_any_frame then
                            local result = qi.handle_any_frame()
                            if result then
                                _core_log("[EaxAutoQuester-DEBUG] talk: quest frame handled [ID]: " .. tostring(result))
                            else
                                _core_log("[EaxAutoQuester-DEBUG] talk: quest frame NOT detected after interact [ID]")
                            end
                        else
                            _core_log("[EaxAutoQuester-DEBUG] talk: ensure_quest_interaction returned nil")
                        end
                    else
                        _core_log("[EaxAutoQuester-DEBUG] talk: interact failed: " .. tostring(int_err))
                    end
                    debug_log("DO_ACTION: targeted quest NPC '" .. tostring(nname or "?") .. "' by ID for talk")
                    return true
                else
                    _core_log("[EaxAutoQuester-DEBUG] talk: find_nearest_npc returned nil for all " .. tostring(#npc_ids) .. " IDs")
                end
            else
                _core_log("[EaxAutoQuester-DEBUG] talk: find_quest_npcs returned nil")
            end

            -- Try 1.5: find by goal name (e.g. "Marshal Dughan") when IDs don't match
            -- Zygor uses .target or .npc for the NPC name, NOT .text/.name
            -- CRITICAL: goal.target may be "" (empty string, truthy in Lua), so we must check ~= ""
            local goal_name = nil
            if type(goal) == "table" then
                local function nonempty(s) return (s and s ~= "") and s or nil end
                goal_name = nonempty(goal.npc) or nonempty(goal.target) or nonempty(goal.npc_name) or nonempty(goal.text) or nonempty(goal.name) or nil
                _core_log("[EaxAutoQuester-DEBUG] talk: goal_name extracted='" .. tostring(goal_name or "nil") .. "' from target='" .. tostring(goal.target or "nil") .. "' npc='" .. tostring(goal.npc or "nil") .. "'")
            end
            if goal_name and goal_name ~= "" and npc.find_interactable_objects then
                local objects = npc.find_interactable_objects(goal_name)
                if objects and #objects > 0 then
                    local nearest = objects[1]
                    local _, nname = pcall(function() return nearest:get_name() end)
                    local me_pos_ok, me_pos = pcall(function() return me:get_position() end)
                    local npc_pos_ok, npc_pos = pcall(function() return nearest:get_position() end)
                    local dist_yds = nil
                    if me_pos_ok and me_pos and npc_pos_ok and npc_pos then
                        local dx = (me_pos.x or 0) - (npc_pos.x or 0)
                        local dy = (me_pos.y or 0) - (npc_pos.y or 0)
                        dist_yds = math.floor(math.sqrt(dx*dx + dy*dy))
                        if dist_yds > 6 then
                            _core_log("[EaxAutoQuester-DEBUG] talk: name-match NPC '" .. tostring(nname or "?") .. "' at " .. tostring(dist_yds) .. "yd — too far, navigating closer")
                            local utils = ensure_utils()
                            if utils and utils.move_to then
                                pcall(function() utils.move_to(npc_pos) end)
                            end
                            return true
                        end
                    end
                    local st_ok = pcall(core.input.set_target, nearest)
                    local int_ok = pcall(core.input.interact_with_object, nearest)
                    _core_log("[EaxAutoQuester-DEBUG] talk: set_target=" .. tostring(st_ok) .. " interact=" .. tostring(int_ok) .. " dist=" .. tostring(dist_yds) .. "yd name='" .. tostring(nname or "?") .. "' [name-match]")
                    debug_log("DO_ACTION: targeted quest NPC '" .. tostring(nname or "?") .. "' by name for talk")
                    return true
                else
                    _core_log("[EaxAutoQuester-DEBUG] talk: name-match fallback returned nil for '" .. tostring(goal_name) .. "'")
                end
            end

            -- Try 2: find any unit flagged as a quest unit (engine's own flag)
            if npc.find_nearest_quest_unit then
                local nearest = npc.find_nearest_quest_unit(50, true)
                if nearest then
                    local _, nname = pcall(function() return nearest:get_name() end)
                    local me_pos_ok, me_pos = pcall(function() return me:get_position() end)
                    local npc_pos_ok, npc_pos = pcall(function() return nearest:get_position() end)
                    local dist_yds = nil
                    if me_pos_ok and me_pos and npc_pos_ok and npc_pos then
                        local dx = (me_pos.x or 0) - (npc_pos.x or 0)
                        local dy = (me_pos.y or 0) - (npc_pos.y or 0)
                        dist_yds = math.floor(math.sqrt(dx*dx + dy*dy))
                        if dist_yds > 6 then
                            _core_log("[EaxAutoQuester-DEBUG] talk: quest unit '" .. tostring(nname or "?") .. "' at " .. tostring(dist_yds) .. "yd — too far, navigating closer")
                            local utils = ensure_utils()
                            if utils and utils.move_to then
                                pcall(function() utils.move_to(npc_pos) end)
                            end
                            return true
                        end
                    end
                    local st_ok = pcall(core.input.set_target, nearest)
                    local int_ok = pcall(core.input.interact_with_object, nearest)
                    _core_log("[EaxAutoQuester-DEBUG] talk: set_target=" .. tostring(st_ok) .. " interact=" .. tostring(int_ok) .. " dist=" .. tostring(dist_yds) .. "yd name='" .. tostring(nname or "?") .. "'")
                    if int_ok then
                        local qi = ensure_quest_interaction()
                        if qi and qi.handle_any_frame then
                            local result = qi.handle_any_frame()
                            if result then
                                _core_log("[EaxAutoQuester-DEBUG] talk: quest frame handled [quest_unit]: " .. tostring(result))
                            else
                                _core_log("[EaxAutoQuester-DEBUG] talk: quest frame NOT detected after interact [quest_unit]")
                            end
                        end
                    end
                    debug_log("DO_ACTION: targeted quest unit '" .. tostring(nname or "?") .. "' by is_quest_unit for talk")
                    return true
                else
                    _core_log("[EaxAutoQuester-DEBUG] talk: find_nearest_quest_unit returned nil")
                end
            else
                _core_log("[EaxAutoQuester-DEBUG] talk: npc.find_nearest_quest_unit is nil")
            end

            -- Try 3: brute-force scan for quest-relevant objects only (is_quest_unit or known quest NPC ID)
            local me = _get_local_player()
            if me then
                local _, pos = pcall(function() return me:get_position() end)
                if pos then
                    local _, objects = pcall(core.object_manager.get_visible_objects)
                    if objects and #objects > 0 then
                        -- Build ID set from quest NPC IDs if available
                        local id_set = {}
                        if npc_ids then
                            for j = 1, #npc_ids do
                                local id = npc_ids[j]
                                if id then id_set[id] = true end
                            end
                        end
                        local best = nil
                        local best_sq = 1e9
                        local scanned = 0
                        local valid_quest = 0
                        local limit = #objects > 50 and 50 or #objects
                        for i = 1, limit do
                            local obj = objects[i]
                            if obj then
                                scanned = scanned + 1
                                local skip = false
                                -- Exclude player
                                local ok_player, is_player = pcall(function() return obj:is_player() end)
                                if ok_player and is_player then skip = true end
                                -- Exclude dead
                                if not skip then
                                    local ok_dead, is_dead = pcall(function() return obj:is_dead() end)
                                    if ok_dead and is_dead then skip = true end
                                end
                                -- Only accept quest-relevant objects
                                if not skip then
                                    local ok_quest, quest_flag = pcall(function() return obj:is_quest_unit() end)
                                    if ok_quest and quest_flag then
                                        valid_quest = valid_quest + 1
                                    elseif next(id_set) then
                                        -- Fallback: match against known quest NPC IDs
                                        local ok_id, obj_npc_id = pcall(function() return obj:get_npc_id() end)
                                        if ok_id and obj_npc_id and id_set[obj_npc_id] then
                                            valid_quest = valid_quest + 1
                                        else
                                            skip = true
                                        end
                                    else
                                        skip = true
                                    end
                                end
                                -- Check distance and track best
                                if not skip then
                                    local _, opos = pcall(function() return obj:get_position() end)
                                    if opos then
                                        local dx = (opos.x or 0) - (pos.x or 0)
                                        local dy = (opos.y or 0) - (pos.y or 0)
                                        local d_sq = dx * dx + dy * dy
                                        if d_sq < 900 and d_sq < best_sq then  -- 30yd squared
                                            best_sq = d_sq
                                            best = obj
                                        end
                                    end
                                end
                            end
                        end
                        _core_log("[EaxAutoQuester-DEBUG] talk brute-force: scanned=" .. tostring(scanned) .. " valid_quest=" .. tostring(valid_quest) .. " best=" .. tostring(best and "yes" or "nil"))
                        if best then
                            local _, nname = pcall(function() return best:get_name() end)
                            local dist_yds = math.floor(math.sqrt(best_sq))
                            if dist_yds > 6 then
                                _core_log("[EaxAutoQuester-DEBUG] talk: brute-force NPC '" .. tostring(nname or "?") .. "' at " .. tostring(dist_yds) .. "yd — too far, navigating closer")
                                local best_pos_ok, best_pos = pcall(function() return best:get_position() end)
                                if best_pos_ok and best_pos then
                                    local utils = ensure_utils()
                                    if utils and utils.move_to then
                                        pcall(function() utils.move_to(best_pos) end)
                                    end
                                end
                                return true
                            end
                            local st_ok = pcall(core.input.set_target, best)
                            local int_ok = pcall(core.input.interact_with_object, best)
                            _core_log("[EaxAutoQuester-DEBUG] talk: set_target=" .. tostring(st_ok) .. " interact=" .. tostring(int_ok) .. " dist=" .. tostring(dist_yds) .. "yd name='" .. tostring(nname or "?") .. "'")
                            debug_log("DO_ACTION: targeted '" .. tostring(nname or "?") .. "' at " .. tostring(dist_yds) .. "yd for talk [brute-force quest-relevant]")
                            return true
                        end
                    else
                        _core_log("[EaxAutoQuester-DEBUG] talk: no visible objects at all")
                    end
                else
                    _core_log("[EaxAutoQuester-DEBUG] talk: could not get player position")
                end
            else
                _core_log("[EaxAutoQuester-DEBUG] talk: could not get local player")
            end
            -- Try 3.5: wide name-based unit scan (100yd) — for NPCs like "Marshal Dughan"
            -- that don't match quest IDs or is_quest_unit but are named in the goal
            if goal_name and goal_name ~= "" then
                local me3 = _get_local_player()
                if me3 then
                    local _, ppos3 = pcall(function() return me3:get_position() end)
                    if ppos3 then
                        local _, objects3 = pcall(core.object_manager.get_visible_objects)
                        if objects3 and #objects3 > 0 then
                            local best3 = nil
                            local best3_sq = 10000  -- 100yd squared
                            local best3_name = nil
                            local limit3 = #objects3 > 100 and 100 or #objects3
                            local glower = goal_name:lower()
                            for k = 1, limit3 do
                                local obj3 = objects3[k]
                                if obj3 then
                                    local ok_p3, is_p3 = pcall(function() return obj3:is_player() end)
                                    if ok_p3 and is_p3 then
                                        -- skip player
                                    else
                                        local ok_u3, is_u3 = pcall(function() return obj3:is_unit() end)
                                        if ok_u3 and is_u3 then
                                            local ok_n3, n3 = pcall(function() return obj3:get_name() end)
                                            if ok_n3 and n3 then
                                                local n3lower = n3:lower()
                                                if n3lower:find(glower, 1, true) or glower:find(n3lower, 1, true) then
                                                    local _, opos3 = pcall(function() return obj3:get_position() end)
                                                    if opos3 then
                                                        local dx3 = (opos3.x or 0) - (ppos3.x or 0)
                                                        local dy3 = (opos3.y or 0) - (ppos3.y or 0)
                                                        local d3_sq = dx3*dx3 + dy3*dy3
                                                        if d3_sq < best3_sq then
                                                            best3_sq = d3_sq
                                                            best3 = obj3
                                                            best3_name = n3
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if best3 then
                                local dist3_yds = math.floor(math.sqrt(best3_sq))
                                if dist3_yds > 6 then
                                    _core_log("[EaxAutoQuester-DEBUG] talk: wide-scan NPC '" .. tostring(best3_name) .. "' at " .. tostring(dist3_yds) .. "yd — navigating closer")
                                    local bp_ok, bp = pcall(function() return best3:get_position() end)
                                    if bp_ok and bp then
                                        local utils = ensure_utils()
                                        if utils and utils.move_to then pcall(function() utils.move_to(bp) end) end
                                    end
                                    return true
                                end
                                local st_ok = pcall(core.input.set_target, best3)
                                local int_ok = pcall(core.input.interact_with_object, best3)
                                _core_log("[EaxAutoQuester-DEBUG] talk: set_target=" .. tostring(st_ok) .. " interact=" .. tostring(int_ok) .. " dist=" .. tostring(dist3_yds) .. "yd name='" .. tostring(best3_name) .. "' [wide-scan]")
                                -- After interacting, try to handle any quest dialog immediately
                                local qi = ensure_quest_interaction()
                                if qi and qi.handle_any_frame then
                                    local result = qi.handle_any_frame()
                                    if result then
                                        _core_log("[EaxAutoQuester-DEBUG] talk: quest frame handled: " .. tostring(result))
                                    end
                                end
                                debug_log("DO_ACTION: targeted '" .. tostring(best3_name) .. "' by wide name scan")
                                return true
                            else
                                _core_log("[EaxAutoQuester-DEBUG] talk: wide name scan found nothing for '" .. tostring(goal_name) .. "'")
                            end
                        end
                    end
                end
            end

            -- Try 4: proximity fallback — we're at the destination but the NPC
            -- doesn't match IDs or is_quest_unit. Accept any non-player target
            -- within range. Two-pass: prefer name match, then closest valid.
            local me2 = _get_local_player()
            if me2 then
                local _, ppos = pcall(function() return me2:get_position() end)
                if ppos then
                    local _, objects2 = pcall(core.object_manager.get_visible_objects)
                    if objects2 and #objects2 > 0 then
                        local best2 = nil
                        local best2_sq = 900  -- 30yd squared
                        local best2_name = nil
                        local limit2 = #objects2 > 50 and 50 or #objects2
                        if type(goal) == "table" and not goal_name then
                            goal_name = goal.text or goal.name or goal.npc_name or nil
                        end
                        -- Pass 1: name-aware closest match
                        for k = 1, limit2 do
                            local obj2 = objects2[k]
                            if obj2 then
                                local skip2 = false
                                local ok_p2, is_p2 = pcall(function() return obj2:is_player() end)
                                if ok_p2 and is_p2 then skip2 = true end
                                if not skip2 then
                                    local ok_d2, is_d2 = pcall(function() return obj2:is_dead() end)
                                    if ok_d2 and is_d2 then skip2 = true end
                                end
                                if not skip2 then
                                    local _, opos2 = pcall(function() return obj2:get_position() end)
                                    if opos2 then
                                        local dx2 = (opos2.x or 0) - (ppos.x or 0)
                                        local dy2 = (opos2.y or 0) - (ppos.y or 0)
                                        local d2_sq = dx2 * dx2 + dy2 * dy2
                                        if d2_sq < best2_sq then
                                            local ok_n2, n2 = pcall(function() return obj2:get_name() end)
                                            if ok_n2 and n2 then
                                                local n2lower = n2:lower()
                                                if goal_name and goal_name ~= "" then
                                                    local glower = goal_name:lower()
                                                    if n2lower:find(glower, 1, true) or glower:find(n2lower, 1, true) then
                                                        best2_sq = d2_sq
                                                        best2 = obj2
                                                        best2_name = n2
                                                    end
                                                end
                                                -- Always track closest valid for pass-2 fallback
                                                if not best2 then
                                                    best2 = obj2
                                                    best2_sq = d2_sq
                                                    best2_name = n2
                                                end
                                            elseif not best2 then
                                                best2 = obj2
                                                best2_sq = d2_sq
                                                best2_name = "?"
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if best2 then
                            local dist2_yds = math.floor(math.sqrt(best2_sq))
                            if dist2_yds > 6 then
                                _core_log("[EaxAutoQuester-DEBUG] talk: proximity NPC '" .. tostring(best2_name or "?") .. "' at " .. tostring(dist2_yds) .. "yd — too far, navigating closer")
                                local best2_pos_ok, best2_pos = pcall(function() return best2:get_position() end)
                                if best2_pos_ok and best2_pos then
                                    local utils = ensure_utils()
                                    if utils and utils.move_to then
                                        pcall(function() utils.move_to(best2_pos) end)
                                    end
                                end
                                return true
                            end
                            local st_ok = pcall(core.input.set_target, best2)
                            local int_ok = pcall(core.input.interact_with_object, best2)
                            _core_log("[EaxAutoQuester-DEBUG] talk: set_target=" .. tostring(st_ok) .. " interact=" .. tostring(int_ok) .. " dist=" .. tostring(dist2_yds) .. "yd name='" .. tostring(best2_name or "?") .. "'")
                            if int_ok then
                                local qi = ensure_quest_interaction()
                                if qi and qi.handle_any_frame then
                                    local result = qi.handle_any_frame()
                                    if result then _core_log("[EaxAutoQuester-DEBUG] talk: quest frame handled [proximity]: " .. tostring(result)) end
                                end
                            end
                            debug_log("DO_ACTION: targeted '" .. tostring(best2_name or "?") .. "' at " .. tostring(dist2_yds) .. "yd for talk [proximity fallback, goal='" .. tostring(goal_name or "?") .. "']")
                            return true
                        else
                            _core_log("[EaxAutoQuester-DEBUG] talk: proximity fallback found nothing within 30yd (goal='" .. tostring(goal_name or "nil") .. "', objects=" .. tostring(#objects2) .. ")")
                        end
                    else
                        _core_log("[EaxAutoQuester-DEBUG] talk: proximity fallback — no visible objects")
                    end
                else
                    _core_log("[EaxAutoQuester-DEBUG] talk: proximity fallback — no player position")
                end
            else
                _core_log("[EaxAutoQuester-DEBUG] talk: proximity fallback — no local player")
            end
        else
            _core_log("[EaxAutoQuester-DEBUG] talk: npc manager is nil")
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
            local raw_id = goal.npc_id or goal.target_id
            goal_npc_id = (raw_id and raw_id > 0) and raw_id or nil
            goal_target = goal.target or goal.npc or nil
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
            -- Build list of names to try, including plural→singular fallback
            local names_to_try = {}
            for name in goal_target:gmatch("[^,]+") do
                local trimmed = name:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then
                    names_to_try[#names_to_try + 1] = trimmed
                end
            end
            local n = #names_to_try
            for i = 1, n do
                local name = names_to_try[i]
                local first_word = name:match("^(%S+)")
                if first_word and first_word:sub(-1) == "s" then
                    local singular_first = name:gsub("^" .. first_word, first_word:sub(1, -2), 1)
                    names_to_try[#names_to_try + 1] = singular_first
                end
                if name:sub(-1) == "s" then
                    local singular = name:sub(1, -2)
                    if singular ~= "" then
                        names_to_try[#names_to_try + 1] = singular
                    end
                end
            end

            for _, name in ipairs(names_to_try) do
                local objects = npc.find_interactable_objects(name)
                if objects and #objects > 0 then
                    -- Pick closest object by distance
                    local me = _get_local_player()
                    local utils = ensure_utils()
                    local best_obj = nil
                    local best_dist_sq = 1e9
                    if me and utils then
                        local _, me_pos = pcall(function() return me:get_position() end)
                        if me_pos then
                            for _, candidate in ipairs(objects) do
                                local _, cpos = pcall(function() return candidate:get_position() end)
                                if cpos then
                                    local dsq = utils.squared_distance(me_pos, cpos)
                                    if dsq < best_dist_sq then
                                        best_dist_sq = dsq
                                        best_obj = candidate
                                    end
                                end
                            end
                        end
                    end
                    if not best_obj then best_obj = objects[1] end

                    -- Determine if it's a unit or game object
                    local is_unit_obj = false
                    local ok_unit, is_unit_val = pcall(function() return best_obj:is_unit() end)
                    if ok_unit and is_unit_val then is_unit_obj = true end

                    local dist_yds = math.floor(math.sqrt(best_dist_sq))

                    -- Game objects need to be within ~5yd; navigate if too far
                    if not is_unit_obj and best_dist_sq > 25 then
                        local _, opos = pcall(function() return best_obj:get_position() end)
                        if opos then
                            -- Fix Z on object position (game objects can have z=0)
                            if (opos.z or 0) == 0 then
                                local _, me_pos = pcall(function() return me:get_position() end)
                                if me_pos and me_pos.z then
                                    opos = { x = opos.x, y = opos.y, z = me_pos.z }
                                end
                            end
                            _nav_destination = opos
                            debug_log("DO_ACTION: area — '" .. tostring(name) .. "' at " .. tostring(dist_yds) .. "yd, navigating closer")
                            return false
                        end
                    end

                    -- Face the object before interacting
                    local _, opos = pcall(function() return best_obj:get_position() end)
                    if opos then
                        pcall(core.input.look_at, opos)
                    end
                    pcall(core.input.set_target, best_obj)

                    if is_unit_obj then
                        pcall(core.input.interact_with_object, best_obj)
                        debug_log("DO_ACTION: area — interacted with unit '" .. tostring(name) .. "' (" .. tostring(dist_yds) .. "yd)")
                    else
                        pcall(core.input.use_object, best_obj)
                        debug_log("DO_ACTION: area — used game object '" .. tostring(name) .. "' (" .. tostring(dist_yds) .. "yd)")
                    end
                    return true
                end
            end
            debug_log("DO_ACTION: area — no interactable objects for '" .. tostring(goal_target) .. "'")
        end

        -- Brute-force scan for nearby NPCs (skip if permanently blocked)
        if _area_fail_count >= 999 then
            debug_log("DO_ACTION: area — brute-force blocked")
            return true
        else
        local me = _get_local_player()
        if me then
            local _, pos = pcall(function() return me:get_position() end)
            if pos then
                local _, objects = pcall(core.object_manager.get_visible_objects)
                if objects and #objects > 0 then
                    local best, best_sq = nil, math.huge
                    local best_guid = nil
                    local limit = #objects > 50 and 50 or #objects
                    for i = 1, limit do
                        local obj = objects[i]
                        if not obj then break end
                        local ok2, unit = pcall(function() return obj:is_unit() end)
                        if ok2 and unit then
                            local ok5, is_player = pcall(function() return obj:is_player() end)
                            if ok5 and not is_player then
                                local ok3, dead = pcall(function() return obj:is_dead() end)
                                if ok3 and not dead then
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
                            _area_fail_count = 999  -- permanent block
                            _area_last_target_guid = nil
                            pcall(core.log_warning, "[EaxAutoQuester] Cannot interact with target - manual help required")
                            local ns = _G.EaxAutoQuester
                            if ns and ns.set_warning then
                                ns.set_warning("Stuck - cannot interact with NPC here", 0)
                            end
                            debug_log("DO_ACTION: area — giving up after 5 failed attempts")
                            return true
                        end
                        -- Verify object is still valid before interacting
                        local _, valid = pcall(function() return best:is_valid() end)
                        if not valid then
                            debug_log("DO_ACTION: area — target became invalid")
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
    end

    -- Fallback: if area goal couldn't find any interactable NPC, try killing nearby enemies
    if combat then
        local tagged = combat.target_and_tag_nearest(50)
        if tagged then
            debug_log("DO_ACTION: area fallback — tagged enemy for kill")
            return true
        end
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

    -- Determine action type from goal or cached value (Zygor uses .action, .type, or .action_type)
    local action_type = safe(_last_goal_type, "area")
    if type(current_goal) == "table" then
        action_type = safe(current_goal.type, safe(current_goal.action_type, safe(current_goal.action, action_type)))
    end

    -- Execute action
    execute_goal_action(action_type, current_goal)

    -- After talk/gossip: immediately check for open frames (quest dialog)
    -- instead of waiting for the full pause timer
    if action_type == "talk" or action_type == "gossip" then
        -- Give the server 0.3s to open the frame, then check
        _action_pause_timer = now + 0.3
        return "IDLE"
    end

    -- Progressive backoff: same action type → increase pause (0.5s → 1s → 2s → 4s → capped 5s)
    local pause = 0.5
    if action_type == _last_action_type then
        _action_loop_count = _action_loop_count + 1
        pause = math.min(0.5 * math.pow(2, _action_loop_count), 2.0)
    else
        _action_loop_count = 0
    end
    _last_action_type = action_type

    -- Add random jitter (±10%) to avoid robotic timing patterns
    _action_pause_timer = now + pause + math.random() * 0.1 * pause - 0.05 * pause
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

--- Hard stop: called from main.lua when plugin is disabled.
--- Immediately stops all navigation and resets state.
function M.stop_navigation()
    local nav = ensure_navigation()
    if nav then
        nav.stop()
        debug_log("Hard stop: navigation cancelled")
    end
    _nav_destination = nil
    _nav_retries = 0
    _nav_retry_timer = 0
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
