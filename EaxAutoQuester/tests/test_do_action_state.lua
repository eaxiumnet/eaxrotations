-- What: Unit tests for EaxAutoQuester/quest_state/do_action_state.lua area-branch
--       questgiver fallback (Questie union when goal has no npc_id)
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify the bot targets and interacts with friendly questgiver NPCs when
--       Zygor supplies a goal stripped of NPC identity (npc_id=0, target="").
--       Reproduces goal[38] shape from the live debug logs.

-- Path setup for standalone run (run_quester_tests.lua also sets this)
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- ============================================================================
-- Helpers — build a do_action_state runnable context
-- ============================================================================

local function build_ctx(zygor_step, questie_ids, visible_objects)
    mock.reset()
    mock._addon_loaded.zygor = true
    mock._addon_loaded.questie = (questie_ids ~= nil)
    mock._zygor_step = zygor_step
    mock._questie_npcs = questie_ids or {}
    mock._objects = visible_objects or {}
    if not mock._player then
        mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    else
        mock._player._pos = { x = 0, y = 0, z = 0 }
    end
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local npc_manager = require("EaxAutoQuester/npc_manager_sylvanas")
    return {
        zygor = require("EaxAutoQuester/zygor_reader_sylvanas"),
        npc_manager = npc_manager,
        combat_helper = nil,
        utils = utils,
        menu = { get = function() return false end },
        me = mock._player,
        now = mock.get_time(),
        debug_log = function() end,
        log = function() end,
        safe = function(v, fb) if v == nil then return fb end return v end,
        detect_open_frame = function() return false end,
    }
end

-- ============================================================================
-- S1 — Happy path: Questie-known questgiver 30yd away → targeted + interacted
-- ============================================================================
do
    local questgiver = mock.create_object({
        pos = { x = 30, y = 0, z = 0 },
        name = "Marshal Dughan",
        npc_id = 7000,
        unit = true,
        valid = true,
        guid = "qg_7000",
    })
    -- The reproduction step: npc_id=0, text=nil, target="" — exactly like goal[38]
    local step = {
        num = 38,
        is_complete = false,
        waypoint = { map_id = 0, x = 0.30, y = 0.50 },
        goals = { { type = "area", npc_id = 0, text = nil, target = "" } },
    }
    local ctx = build_ctx(step, { 7000 }, { questgiver })
    local do_action = require("EaxAutoQuester/quest_state/do_action_state")

    -- Run twice: first pass should set nav destination or target
    local shared = {
        _area_wait_timer = 0,
        _action_pause_timer = 0,
        _area_fail_count = 0,
        _area_last_target_guid = nil,
        _last_step_num = 38,
        _last_goal_type = "area",
        _nav_destination = nil,
    }
    do_action.run(shared, ctx)

    -- Assert: bot must have targeted the questgiver OR set nav destination toward it
    local input_calls = mock._input_calls
    local targeted = false
    local interacted = false
    local nav_set = false
    for _, call in ipairs(input_calls) do
        if call[1] == "set_target" and call[2] == questgiver then targeted = true end
        if call[1] == "interact_with_object" and call[2] == questgiver then interacted = true end
    end
    if shared._nav_destination then
        local dx = (shared._nav_destination.x or 0) - 30
        local dy = (shared._nav_destination.y or 0) - 0
        if dx * dx + dy * dy < 1 then nav_set = true end
    end
    assert(targeted or nav_set,
        "S1 FAIL: area goal with no npc_id must target questgiver (30yd) or set nav dest, " ..
        "but got: targeted=" .. tostring(targeted) .. " nav_set=" .. tostring(nav_set) ..
        " input_calls=" .. tostring(#input_calls))
    print("  S1 PASS: area-no-npc_id → bot targets/navigates to Questie-known questgiver (30yd)")
end

-- ============================================================================
-- S2 — Edge: questgiver at 60yd → set nav destination, return IDLE for re-NAV
-- ============================================================================
do
    local questgiver = mock.create_object({
        pos = { x = 60, y = 0, z = 0 },
        name = "Marshal Dughan",
        npc_id = 7000,
        unit = true,
        valid = true,
        guid = "qg_7000_far",
    })
    local step = {
        num = 38,
        is_complete = false,
        waypoint = { map_id = 0, x = 0.30, y = 0.50 },
        goals = { { type = "area", npc_id = 0, text = nil, target = "" } },
    }
    local ctx = build_ctx(step, { 7000 }, { questgiver })
    local do_action = require("EaxAutoQuester/quest_state/do_action_state")
    local shared = {
        _area_wait_timer = 0,
        _action_pause_timer = 0,
        _area_fail_count = 0,
        _area_last_target_guid = nil,
        _last_step_num = 38,
        _last_goal_type = "area",
        _nav_destination = nil,
    }
    do_action.run(shared, ctx)
    local nav_dest = shared._nav_destination
    assert(nav_dest ~= nil, "S2 FAIL: far questgiver (60yd) should set nav destination")
    local dx = (nav_dest.x or 0) - 60
    local dy = (nav_dest.y or 0) - 0
    assert(dx * dx + dy * dy < 1,
        "S2 FAIL: nav dest should be at questgiver position (60,0,0), got ("
        .. tostring(nav_dest.x) .. "," .. tostring(nav_dest.y) .. "," .. tostring(nav_dest.z) .. ")")
    print("  S2 PASS: area-no-npc_id + far questgiver (60yd) → nav destination set")
end

-- ============================================================================
-- S3 — Edge: Questie not loaded → no crash, falls through gracefully
-- ============================================================================
do
    local step = {
        num = 38,
        is_complete = false,
        waypoint = { map_id = 0, x = 0.30, y = 0.50 },
        goals = { { type = "area", npc_id = 0, text = nil, target = "" } },
    }
    local ctx = build_ctx(step, nil, {})  -- questie_ids=nil → Questie not loaded
    local do_action = require("EaxAutoQuester/quest_state/do_action_state")
    local shared = {
        _area_wait_timer = 0,
        _action_pause_timer = 0,
        _area_fail_count = 0,
        _area_last_target_guid = nil,
        _last_step_num = 38,
        _last_goal_type = "area",
        _nav_destination = nil,
    }
    -- Should not raise
    local ok, err = pcall(do_action.run, shared, ctx)
    assert(ok, "S3 FAIL: do_action.run must not crash when Questie is not loaded: " .. tostring(err))
    -- No quest NPC targeted because Questie wasn't loaded
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "interact_with_object",
            "S3 FAIL: should not interact when Questie is not loaded")
    end
    print("  S3 PASS: area-no-npc_id + Questie-not-loaded → no crash, no false interact")
end

-- ============================================================================
-- S4 — Adjacent regression: existing area path with goal.npc_id set still works
-- ============================================================================
do
    local step = {
        num = 39,
        is_complete = false,
        waypoint = { map_id = 0, x = 0.05, y = 0.50 },
        -- Goal HAS a valid npc_id — must use the existing fast path, not Questie
        goals = { { type = "area", npc_id = 5500, text = nil, target = "" } },
    }
    local ctx = build_ctx(step, { 9999 }, {})  -- Questie lists 9999, no local 5500 NPC
    local do_action = require("EaxAutoQuester/quest_state/do_action_state")
    local shared = {
        _area_wait_timer = 0,
        _action_pause_timer = 0,
        _area_fail_count = 0,
        _area_last_target_guid = nil,
        _last_step_num = 39,
        _last_goal_type = "area",
        _nav_destination = nil,
    }
    do_action.run(shared, ctx)
    -- The existing path uses npc_db_sylvanas spawn lookup. NPC 5500 (Tel'Athir)
    -- spawns far from (0,0,0), so the path sets _nav_destination to the spawn.
    -- What matters here: it did NOT use the Questie fallback for NPC 9999.
    local nav_dest = shared._nav_destination
    assert(nav_dest ~= nil,
        "S4 FAIL: goal.npc_id=5500 path should set nav destination to npc_db spawn")
    local spawn = ctx.utils and (function()
        local npc_db = require("EaxAutoQuester/npc_db_sylvanas")
        return npc_db.find_npc_spawn(5500, 0)
    end)()
    assert(spawn ~= nil, "S4 FAIL: test setup error — NPC 5500 not in spawn DB")
    local dx = (nav_dest.x or 0) - (spawn.x or 0)
    local dy = (nav_dest.y or 0) - (spawn.y or 0)
    local dz = (nav_dest.z or 0) - (spawn.z or 0)
    local dist_sq = dx * dx + dy * dy + dz * dz
    assert(dist_sq < 1,
        "S4 FAIL: nav destination should match npc_db spawn (NPC 5500), got dist_sq=" .. tostring(dist_sq))
    -- Verify the Questie NPC 9999 was NOT used (would have set nav to origin since no 9999 in scene)
    print("  S4 PASS: regression — goal.npc_id=5500 path uses npc_db spawn, not Questie fallback")
end

-- S16 — ENEMY SCAN: must skip dead+lootable corpses, only target ALIVE units.
-- Live observed: bot was attacking "Stonetusk Boars" at 2yd repeatedly,
-- but the 8 "matching targets" included both live boars AND dead boar
-- corpses. The is_dead() check alone wasn't enough — the API reports
-- dead mobs as still alive when they have loot. The fix: also check
-- can_be_looted() — a dead mob with loot is a corpse, not a live target.
do
    mock.reset()
    local live_boar = mock.create_object({
        pos = { x = 2, y = 0, z = 0 },
        name = "Stonetusk Boar",
        npc_id = 0,
        unit = true,
        valid = true,
        dead = false,
        attackable = true,
        guid = "boar_alive",
    })
    live_boar.is_dead = function() return false end
    live_boar.can_be_looted = function() return false end

    local dead_boar_corpse = mock.create_object({
        pos = { x = 2, y = 0, z = 0 },
        name = "Stonetusk Boar",
        npc_id = 0,
        unit = true,
        valid = true,
        dead = true,
        attackable = true,
        guid = "boar_dead",
    })
    dead_boar_corpse.is_dead = function() return false end
    dead_boar_corpse.can_be_looted = function() return true end

    mock._objects = { live_boar, dead_boar_corpse }
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = false })

    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return {
                is_complete = false,
                goals = { { type = "area", target = "Stonetusk Boars", npc_id = 0 } },
                step_num = 71,
            } end,
            get_current_waypoint_world = function() return { x = 0, y = 0, z = 0 } end,
        },
        nav = { is_navigating = function() return false end, stop = function() end },
        utils = utils,
        me = mock._player,
        now = 100.0,
        debug_log = function() end,
        log = function() end,
        safe = function(v, fb) if v == nil then return fb end return v end,
        detect_open_frame = function() return false end,
    }
    local npc_manager = require("EaxAutoQuester/npc_manager_sylvanas")
    ctx.npc_manager = npc_manager
    ctx.combat_helper = nil
    local NS = _G.EaxRotations
    local orig_start = NS and NS.start_auto_attack
    if NS then NS.start_auto_attack = function() end end

    local do_action = require("EaxAutoQuester/quest_state/do_action_state")
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0,
        _post_interact_timer = 0, _at_quest_object_timer = 0,
        _action_pause_timer = 0, _last_step_num = 71 }
    do_action.run(shared, ctx)

    if NS and orig_start then NS.start_auto_attack = orig_start end

    local targeted_live = false
    local targeted_corpse = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "set_target" then
            local target = call[2]
            if target == live_boar then targeted_live = true end
            if target == dead_boar_corpse then targeted_corpse = true end
        end
    end
    assert(not targeted_corpse,
        "S16 FAIL: bot targeted the DEAD CORPSE (can_be_looted=true) " ..
        "instead of skipping it. Causes the back-and-forth loop.")
    assert(targeted_live,
        "S16 FAIL: bot did NOT target the live boar. It should target the " ..
        "ALIVE enemy and skip the dead+lootable corpse.")
    print("  S16 PASS: enemy scan skips dead+lootable corpses, targets live units")
end

-- S17 — REGRESSION: hostile quest NPC at 3yd → set target only, NO interact_with_object
-- Live observed: the Questie fallback fired every 0.5s targeting the same
-- hostile mob (Kobold Miner, id 327 mapped wrong by Questie to a non-quest
-- entity). interact_with_object on a hostile mob is a no-op in WoW — the
-- game silently rejects the right-click. The bot thought the action
-- succeeded (returned true) and the state machine looped:
--   IDLE → DO_ACTION → IDLE → DO_ACTION → IDLE … every 0.5s
-- The fix: if the NPC is hostile (can_attack=true), do NOT call
-- interact_with_object — just set target. Combat (EaxRotations) handles
-- the attack via auto_attack. interact_with_object is for friendly
-- questgivers only.
do
    mock.reset()
    local kobold = mock.create_object({
        pos = { x = 3, y = 0, z = 0 },
        name = "Kobold Miner",
        npc_id = 327,
        unit = true,
        valid = true,
        attackable = true,
        guid = "kobold_miner_327",
    })
    local step = {
        num = 77,
        is_complete = false,
        waypoint = { map_id = 0, x = 0.30, y = 0.50 },
        goals = { { type = "area", npc_id = 0, text = nil, target = "" } },
    }
    local ctx = build_ctx(step, { 327 }, { kobold })
    local do_action = require("EaxAutoQuester/quest_state/do_action_state")
    local NS = _G.EaxRotations
    local orig_start = NS and NS.start_auto_attack
    if NS then NS.start_auto_attack = function() end end

    local shared = {
        _area_wait_timer = 0,
        _action_pause_timer = 0,
        _area_fail_count = 0,
        _area_last_target_guid = nil,
        _last_step_num = 77,
        _last_goal_type = "area",
        _nav_destination = nil,
    }
    do_action.run(shared, ctx)

    if NS and orig_start then NS.start_auto_attack = orig_start end

    local targeted = false
    local interacted = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "set_target" and call[2] == kobold then targeted = true end
        if call[1] == "interact_with_object" and call[2] == kobold then interacted = true end
    end
    assert(targeted,
        "S17 FAIL: hostile quest NPC must be set as target (combat will attack). " ..
        "Found: targeted=" .. tostring(targeted))
    assert(not interacted,
        "S17 FAIL: hostile mob must NOT receive interact_with_object (no-op, " ..
        "causes spam loop). Found: interacted=" .. tostring(interacted))
    print("  S17 PASS: hostile mob → set target only, no interact_with_object (stops loop)")
end

-- S18 — REGRESSION: 3 rapid DO_ACTION runs targeting same NPC → only 1 set_target
-- Live observed: the Questie fallback fired every action_pause (0.5s) and
-- re-targeted the same NPC, which is what the user called "this shit spamming"
-- in the debug log. The cooldown (5s) makes the second/third calls within
-- that window skip the action entirely. After 5s, the cooldown expires and
-- a new attempt is allowed (in case the NPC moved or the state changed).
do
    mock.reset()
    local questgiver = mock.create_object({
        pos = { x = 3, y = 0, z = 0 },
        name = "Marshal Dughan",
        npc_id = 7000,
        unit = true,
        valid = true,
        guid = "qg_7000_close",
    })
    local step = {
        num = 38,
        is_complete = false,
        waypoint = { map_id = 0, x = 0.30, y = 0.50 },
        goals = { { type = "area", npc_id = 0, text = nil, target = "" } },
    }
    local ctx = build_ctx(step, { 7000 }, { questgiver })
    local do_action = require("EaxAutoQuester/quest_state/do_action_state")

    local shared = {
        _area_wait_timer = 0,
        _action_pause_timer = 0,
        _area_fail_count = 0,
        _area_last_target_guid = nil,
        _last_step_num = 38,
        _last_goal_type = "area",
        _nav_destination = nil,
    }
    do_action.run(shared, ctx)
    do_action.run(shared, ctx)
    do_action.run(shared, ctx)

    local set_target_count = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "set_target" and call[2] == questgiver then
            set_target_count = set_target_count + 1
        end
    end
    assert(set_target_count == 1,
        "S18 FAIL: 3 rapid DO_ACTION runs at the same ctx.now should result in 1 set_target. " ..
        "Got " .. tostring(set_target_count) .. " — this is the spam-loop bug.")
    print("  S18 PASS: cooldown prevents spam — 3 rapid runs → 1 set_target (loop stopped)")
end

print("PASS test_do_action_state")
os.exit(0)
