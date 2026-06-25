-- What: Quest state machine coordinator — holds shared state, dispatches to handlers
-- When: update() called each on_pre_tick by quest_state_sylvanas.lua; render_debug() each on_render
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
-- Cached Module References — loaded at require time or first use
-- ============================================================================

local _object_scanner = nil
local _safe_api = nil
local _death_tracker = nil

local function ensure_object_scanner()
    if not _object_scanner then
        local ok, s = pcall(require, "object_scanner")
        if ok then _object_scanner = s end
    end
    return _object_scanner
end

local function ensure_safe_api()
    if not _safe_api then
        local ok, s = pcall(require, "safe_api_wrapper")
        if ok then _safe_api = s end
    end
    return _safe_api
end

local function ensure_death_tracker()
    if not _death_tracker then
        local ns = _G.EaxAutoQuester
        if ns and ns.death_tracker then
            _death_tracker = ns.death_tracker
        else
            local ok, dt = pcall(require, "death_tracker_sylvanas")
            if ok then _death_tracker = dt end
        end
    end
    return _death_tracker
end

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
-- Shared State — all mutable state variables (nil-guarded defaults)
-- ============================================================================

local shared = {
    _state = "IDLE",                -- current state: IDLE, NAV, INTERACT, DO_ACTION, WAITING
    _nav_destination = nil,         -- vec3 destination for NAV state
    _nav_retries = 0,               -- consecutive nav failure count (max 3)
    _nav_retry_timer = 0,           -- core_time when retry becomes allowed
    _nav_wp_fallback = false,      -- tried waypoint fallback yet?
    _nav_mesh_fallback = false,    -- tried navmesh probe fallback yet?
    _nav_fallback_pending = false, -- waiting for async navmesh probe callback
    _action_pause_timer = 0,        -- core_time when action pause expires (0.5s after DO_ACTION)
    _area_wait_timer = 0,           -- core_time when area wait expires (2s)
    _last_goal_type = nil,          -- cached goal type for DO_ACTION state
    _last_step_num = 0,             -- last seen step number (detect step changes)
    _debug = false,                 -- cached debug flag from menu
    _last_target_valid = false,     -- combat tracking: was in combat last tick
    _just_arrived = false,          -- set true when NAV arrives, IDLE skips dist check
    _last_hp_warning = 0,           -- throttle HP warnings to once per 10s
    _last_mana_warning = 0,         -- throttle mana warnings to once per 5s
    _last_cooldown_log = 0,         -- throttle cooldown log spam
    _area_fail_count = 0,           -- consecutive area interaction failures
    _area_last_target_guid = nil,   -- GUID of last brute-force target (detect loops)
    _interact_start_time = 0,       -- when INTERACT state was entered (timeout safety net)
    _interact_cooldown = 0,         -- don't re-enter INTERACT until this time
    _loot_cooldown = 0,             -- don't re-loot until this time
    _faced_target_guid = nil,       -- GUID of last target we faced toward (avoid re-facing every tick)
    _faced_target_pos = nil,        -- last position we faced toward (re-face if target moved > 5yd)
    _last_face_time = 0,            -- core_time of last face call (throttle to every 0.3s)
    _post_interact_timer = 0,      -- core_time when post-interact pause expires (0.3s after click)
    _at_quest_object_timer = 0,     -- core_time when "stay at quest object" flag expires (30s after click)
    _questie_fallback_time = 0,     -- core_time when Questie fallback last fired (5s cooldown to prevent spam)
    _questie_last_guid = nil,       -- GUID of last Questie fallback target (reserved for future GUID-based cooldown)
    _visited_waypoints = {},        -- indices of visited waypoints for movement-only area goals
    _was_alive_last_tick = true,    -- tracks alive→dead transitions for death counting (prevents per-tick spam)
}
local INTERACT_TIMEOUT = 15        -- max seconds in INTERACT before force-exit

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

--- Conditional debug log — only logs when shared._debug flag is true.
--- @param msg string Message to log
local function debug_log(msg)
    if not shared._debug then return end
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
-- State Handler Modules — loaded once at require time
-- ============================================================================

local idle_state = require("quest_state/idle_state")
local nav_state = require("quest_state/nav_state")
local interact_state_mod = require("quest_state/interact_state")
local do_action_state = require("quest_state/do_action_state")
local waiting_state = require("quest_state/waiting_state")
local dead_state = require("quest_state/dead_state")

-- ============================================================================
-- Context Builder — assembles per-tick context for state handlers
-- ============================================================================

--- Build the context object passed to all state handlers each tick.
--- Contains submodules, me, cached time, helper functions.
--- @return table context
local _probed_apis = nil

local function ensure_probed_apis()
    if _probed_apis then return _probed_apis end
    local safe_api = ensure_safe_api()
    if not safe_api then return nil end
    _probed_apis = safe_api.probe_batch({
        get_local_player = core.object_manager.get_local_player,
        get_loot_item_count = core.game_ui.get_loot_item_count,
        get_vendor_item_count = core.game_ui.get_vendor_item_count,
        is_gossip_frame_shown = core.quests.is_gossip_frame_shown,
        get_num_trainer_services = core.quests.get_num_trainer_services,
        set_target = core.input.set_target,
        look_at = core.input.look_at,
        loot_object = core.input.loot_object,
        close_loot = core.input.close_loot,
        interact_with_object = core.input.interact_with_object,
        use_object = core.input.use_object,
    })
    return _probed_apis
end

local function build_context()
    return {
        zygor = ensure_zygor(),
        nav = ensure_navigation(),
        quest_interaction = ensure_quest_interaction(),
        npc_manager = ensure_npc_manager(),
        combat_helper = ensure_combat_helper(),
        utils = ensure_utils(),
        menu = ensure_menu(),
        me = _get_local_player(),
        now = _core_time(),
        debug_log = debug_log,
        log = log,
        safe = safe,
        detect_open_frame = idle_state.detect_open_frame,
        object_scanner = ensure_object_scanner(),
        safe_api = ensure_safe_api(),
        probed = ensure_probed_apis(),
        death_tracker = ensure_death_tracker(),
    }
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
    shared._debug = menu and menu.get("debug") or false

    -- Invalidate object scanner cache at start of tick (single scan per tick)
    local scanner = ensure_object_scanner()
    if scanner and scanner.invalidate then scanner.invalidate() end

    -- Build context for this tick
    local ctx = build_context()

    local in_combat = false
    if ctx.me then
        local ok, combat = pcall(function() return ctx.me:is_in_combat() end)
        in_combat = ok and combat == true
    end
    if in_combat then
        -- Never override DEAD state with combat idle override.
        -- Dead players may retain lingering combat flags; overriding
        -- DEAD → IDLE breaks the corpse-run resurrection pipeline.
        if shared._state == "DEAD" then
            debug_log("Coordinator: combat while dead — keeping DEAD state")
        else
            local nav = ctx.nav
            if nav and nav.is_navigating and nav.is_navigating() then
                nav.stop()
                if nav.dismount then nav.dismount() end
                debug_log("Coordinator: combat — stopped navigation")
            end
            if ctx.me then
                -- In combat: stop navigation, then acquire an enemy target
                -- if none is already set. EaxRotations needs a target to cast
                -- spells. If the player has no target (e.g. enemy attacked from
                -- behind while bot was navigating), we find the nearest enemy
                -- and set it as target.
                local current_target = nil
                local ok, ct = pcall(function() return ctx.me:get_target() end)
                if ok then current_target = ct end
                if not current_target then
                    local helper = ensure_combat_helper()
                    if helper and helper.target_and_tag_nearest then
                        local tagged = helper.target_and_tag_nearest(30, scanner)
                        if tagged then
                            debug_log("Coordinator: combat — acquired enemy target")
                        end
                    end
                end
            end
            if next_state ~= "IDLE" then
                if not shared._combat_override_logged then
                    shared._combat_override_logged = true
                    debug_log("Coordinator: combat override → IDLE")
                end
                shared._state = "IDLE"
            end
        end
        return
    end

    -- ============================================================================
    -- Death detection — before state dispatch, record deaths and check blacklist
    -- ============================================================================
    if ctx.me then
        local dead = false

        -- Check is_dead() first
        local is_dead_ok, is_dead_v = pcall(function() return ctx.me:is_dead() end)
        if is_dead_ok and is_dead_v then
            dead = true
        end

        -- Check ghost form buff (8326) — Wrath client ghost: is_dead()=false, HP>0
        if not dead then
            local ghost_ok, ghost = pcall(function()
                local aura_methods = { "get_buffs", "get_auras", "get_debuffs" }
                for _, m in ipairs(aura_methods) do
                    if ctx.me[m] then
                        local data = ctx.me[m](ctx.me)
                        if data then
                            for i = 1, #data do
                                local b = data[i]
                                if b then
                                    local id = b.buff_id or b.id or b.spell_id or b.aura_id
                                    if id == 8326 or id == "8326" then return true end
                                end
                            end
                        end
                    end
                end
                return false
            end)
            if ghost_ok and ghost then dead = true end
        end

        -- Check HP <= 0 as fallback
        if not dead then
            local hp_ok, hp = pcall(function() return ctx.me:get_health() end)
            if hp_ok and (hp == nil or hp <= 0) then dead = true end
        end

        if dead then
            if shared._was_alive_last_tick then
                shared._was_alive_last_tick = false
                -- Get map_id (pcall-guarded) and record death
                local map_ok, map_id = pcall(core.get_map_id)
                local safe_map_id = (map_ok and map_id) or nil

                if safe_map_id then
                    local dt = ctx.death_tracker
                    if dt then
                        local new_count = dt.record_death(safe_map_id)
                        debug_log("Coordinator: death in zone " .. tostring(safe_map_id) .. " (count=" .. tostring(new_count) .. ")")

                        -- Check blacklist: if >= 3 deaths, go to WAITING, hearth, warn
                        if dt.should_blacklist(safe_map_id) then
                            log("DEATH LOOP DETECTED in zone " .. tostring(safe_map_id) .. " (" .. tostring(new_count) .. " deaths) — blacklisting, hearthing")
                            local nav = ctx.nav
                            if nav then
                                -- Use nav's built-in hearthstone mechanism (item 6948)
                                pcall(function()
                                    for bag = 0, 4 do
                                        local ok_items, items = pcall(core.inventory.get_items_in_bag, bag)
                                        if ok_items and items then
                                            for _, item in ipairs(items) do
                                                if item and item.object and item.object.get_item_id then
                                                    local iid = item.object:get_item_id()
                                                    if iid == 6948 then
                                                        pcall(core.input.use_container_item, bag, item.slot_id)
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end)
                            end
                            local ns = _G.EaxAutoQuester
                            if ns and ns.set_warning then
                                ns.set_warning("Death loop in zone " .. tostring(safe_map_id) .. " - hearthing", 8.0)
                            end
                            shared._state = "WAITING"
                            return
                        end
                    end
                end
            end
        else
            shared._was_alive_last_tick = true
        end
    end

    -- Dispatch current state with transition tracking
    local next_state = shared._state

    if shared._state == "IDLE" then
        next_state = idle_state.run(shared, ctx)
    elseif shared._state == "NAV" then
        next_state = nav_state.run(shared, ctx)
    elseif shared._state == "INTERACT" then
        next_state = interact_state_mod.run(shared, ctx)
    elseif shared._state == "DO_ACTION" then
        next_state = do_action_state.run(shared, ctx)
    elseif shared._state == "WAITING" then
        next_state = waiting_state.run(shared, ctx)
    elseif shared._state == "DEAD" then
        next_state = dead_state.run(shared, ctx)
    end

    -- Force vendor check: if bags are full and we're idle, navigate to nearest vendor
    if next_state == "IDLE" and shared._state ~= "INTERACT" then
        local ns = _G.EaxAutoQuester
        if ns and ns._force_vendor_soon then
            local npc_db_ok, npc_db = pcall(require, "EaxAutoQuester.npc_db_sylvanas")
            if npc_db_ok and npc_db and npc_db.find_transport_npc then
                local vendor_pos = npc_db.find_transport_npc("vendor")
                if vendor_pos then
                    shared._nav_destination = vendor_pos
                    next_state = "NAV"
                    debug_log("Coordinator: force vendor — bags > 80% full")
                end
            end
        end
    end

    -- Log transitions
    if next_state ~= shared._state then
        debug_log("State: " .. shared._state .. " → " .. next_state)
        shared._state = next_state
    end
end

--- Hard stop: called from main.lua when plugin is disabled.
--- Immediately stops all navigation and resets state.
function M.stop_navigation()
    local nav = ensure_navigation()
    if nav then
        nav.stop()
        if nav.dismount then nav.dismount() end
        debug_log("Hard stop: navigation cancelled")
    end
    shared._nav_destination = nil
    shared._nav_retries = 0
    shared._nav_retry_timer = 0
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
    _t[_t.n] = "State: " .. shared._state
    _t.n = _t.n + 1
    _t[_t.n] = "Nav Retries: " .. tostring(safe(shared._nav_retries, 0)) .. "/3"
    _t.n = _t.n + 1
    _t[_t.n] = "Step: " .. tostring(safe(shared._last_step_num, 0))

    if shared._nav_destination then
        _t.n = _t.n + 1
        _t[_t.n] = "Dest: (" ..
            tostring(safe(shared._nav_destination.x, 0)) .. ", " ..
            tostring(safe(shared._nav_destination.y, 0)) .. ", " ..
            tostring(safe(shared._nav_destination.z, 0)) .. ")"
    end

    if shared._last_goal_type then
        _t.n = _t.n + 1
        _t[_t.n] = "Goal: " .. tostring(shared._last_goal_type)
    end

    -- Render as on-screen text via core.graphics
    local text = table.concat(_t, "\n", 1, _t.n)
    pcall(function()
        core.graphics.draw_text(10, 10, text)
    end)
end

-- ============================================================================
-- Exports — thin loader (quest_state_sylvanas.lua) delegates to this module
-- ============================================================================

-- Test accessor: returns current state and nav destination (for unit tests)
function M._test_inspect()
    return shared._state, shared._nav_destination
end

return M
