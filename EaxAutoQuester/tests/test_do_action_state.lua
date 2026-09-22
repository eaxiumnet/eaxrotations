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

-- Required after mock.install(): the module caches core.time at load.
local pull_safety = require("shared/pull_safety")

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
    local utils = require("utils_sylvanas")
    local npc_manager = require("npc_manager_sylvanas")
    return {
        zygor = require("zygor_reader_sylvanas"),
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
    local do_action = require("quest_state/do_action_state")

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
    local do_action = require("quest_state/do_action_state")
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
    local do_action = require("quest_state/do_action_state")
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
-- (Owner moved: the spawn destination comes from the spawn index sweep
--  (shared/spawn_patrol.lua over npc_spawns), not from npc_db_sylvanas.find_npc_spawn.
--  The old single-point mechanism parked the bot on one spawn forever, so this scenario now
--  pins the sweep's source: the point must be one of NPC 5500's OWN spawn coordinates.)
-- ============================================================================
do
    local step = {
        num = 39,
        is_complete = false,
        waypoint = { map_id = 0, x = 0.05, y = 0.50 },
        -- Goal HAS a valid npc_id — must use the existing fast path, not Questie
        goals = { { type = "area", npc_id = 5500, text = nil, target = "" } },
    }
    -- The npc_db stub stays: the area path still consults it for the Questie fallback, and this
    -- scenario asserts that its single point is NOT what the bot walks to any more.
    local mock_npc_db = {
        find_npc_spawn = function(npc_id, map_id)
            if npc_id == 5500 then
                return { x = 500, y = 600, z = 0, map_id = map_id or 0, name = "Test NPC 5500", npc_id = 5500 }
            end
            return nil
        end,
        search_npc_by_name = function() return {} end,
        find_transport_npc = function() return nil end,
    }
    package.loaded["npc_db_sylvanas"] = mock_npc_db

    local ctx = build_ctx(step, { 9999 }, {})  -- Questie lists 9999, no local 5500 NPC
    local do_action = require("quest_state/do_action_state")
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
    local nav_dest = shared._nav_destination
    assert(nav_dest ~= nil,
        "S4 FAIL: goal.npc_id=5500 path should set a nav destination")

    -- The destination must be one of the mob's own spawn points from the tracked spawn index.
    local spawns = require("npc_spawns")
    local maps = spawns.find_npc_spawns(5500)
    assert(maps and #maps > 0, "S4 FAIL: test setup error — NPC 5500 not in the spawn index")
    local matched = false
    for i = 1, #maps do
        local m = maps[i]
        local dx = (nav_dest.x or 0) - (m.x or 0)
        local dy = (nav_dest.y or 0) - (m.y or 0)
        if dx * dx + dy * dy < 1 then matched = true break end
    end
    assert(matched,
        "S4 FAIL: nav destination must be an npc_spawns spawn point for NPC 5500, got " ..
        tostring(nav_dest.x) .. "," .. tostring(nav_dest.y))

    -- And it must NOT be the npc_db_sylvanas point (500, 600) — that is the mechanism this
    -- scenario used to pin, and it is the one that parked the bot on a single spawn.
    local dx_stub = (nav_dest.x or 0) - 500
    local dy_stub = (nav_dest.y or 0) - 600
    assert(dx_stub * dx_stub + dy_stub * dy_stub > 1,
        "S4 FAIL: destination must not be the npc_db single-spawn point")

    -- Verify the Questie NPC 9999 was NOT used (would have set nav to origin since no 9999 in scene)
    print("  S4 PASS: goal.npc_id=5500 sweeps its own spawn index point, not the npc_db single point")
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

    local utils = require("utils_sylvanas")
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
    local npc_manager = require("npc_manager_sylvanas")
    ctx.npc_manager = npc_manager
    ctx.combat_helper = nil
    local NS = _G.EaxRotations
    local orig_start = NS and NS.start_auto_attack
    if NS then NS.start_auto_attack = function() end end

    local do_action = require("quest_state/do_action_state")
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
    local do_action = require("quest_state/do_action_state")
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
    local do_action = require("quest_state/do_action_state")

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

-- ============================================================================
-- Phase 1 ports — kill preference (item 8), talk ladder (item 9), progressive
-- pacing (item 10). Moved from the deleted monolith; the contract lives here.
-- ============================================================================

local do_action = require("quest_state/do_action_state")

local function new_shared(goal_type)
    return {
        _area_wait_timer = 0,
        _action_pause_timer = 0,
        _area_fail_count = 0,
        _area_last_target_guid = nil,
        _last_step_num = 1,
        _last_goal_type = goal_type,
        _nav_destination = nil,
    }
end

local function count_calls(kind, obj)
    local n = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == kind and (obj == nil or call[2] == obj) then n = n + 1 end
    end
    return n
end

-- P8a — a kill goal targets the goal's own quest mob, not the closer generic enemy
do
    local quest_mob = mock.create_object({ pos = { x = 30, y = 0, z = 0 },
        name = "Elder Stranglethorn Tiger", npc_id = 4242, unit = true, valid = true,
        guid = "qm_4242" })
    local generic = mock.create_object({ pos = { x = 5, y = 0, z = 0 },
        name = "Stranglethorn Tiger", npc_id = 999, unit = true, valid = true,
        attackable = true, guid = "gen_999" })
    local step = { num = 1, is_complete = false, waypoint = { map_id = 0, x = 0, y = 0 },
        goals = { { type = "kill", npc_id = 4242 } } }
    local ctx = build_ctx(step, nil, { generic, quest_mob })
    ctx.combat_helper = { is_current_target_valid = function() return false end }
    local shared = new_shared("kill")
    do_action.run(shared, ctx)
    assert(count_calls("set_target", quest_mob) == 1,
        "P8a FAIL: kill goal should target its own quest NPC (npc_id 4242)")
    assert(count_calls("set_target", generic) == 0,
        "P8a FAIL: the nearer generic tiger must not win over the quest mob")
    print("  P8a PASS: kill goal — quest NPC preferred over the closer generic enemy")
end

-- P8b — already fighting a valid target → no re-tag at all
do
    local step = { num = 1, is_complete = false, waypoint = { map_id = 0, x = 0, y = 0 },
        goals = { { type = "kill", npc_id = 4242 } } }
    local enemy = mock.create_object({ pos = { x = 3, y = 0, z = 0 }, name = "Tiger",
        npc_id = 999, unit = true, valid = true, attackable = true, guid = "tg" })
    local ctx = build_ctx(step, nil, { enemy })
    ctx.combat_helper = { is_current_target_valid = function() return true end }
    local shared = new_shared("kill")
    assert(do_action.run(shared, ctx) == "IDLE", "P8b: kill run returns IDLE")
    assert(count_calls("set_target", nil) == 0,
        "P8b FAIL: a valid current target must not be re-tagged")
    print("  P8b PASS: kill goal + valid target → no re-tag")
end

-- P9a — talk ladder rung 2: goal names an NPC that no Questie id knows
do
    local dugan = mock.create_object({ pos = { x = 4, y = 0, z = 0 },
        name = "Marshal Dughan", npc_id = 7000, unit = true, valid = true, guid = "dugan" })
    local step = { num = 1, is_complete = false, waypoint = { map_id = 0, x = 0, y = 0 },
        goals = { { type = "talk", npc_id = 0, target = "Marshal Dughan" } } }
    local ctx = build_ctx(step, nil, { dugan })   -- Questie OFF: ids cannot help
    local shared = new_shared("talk")
    local next_state = do_action.run(shared, ctx)
    assert(count_calls("set_target", dugan) == 1,
        "P9a FAIL: a goal-named NPC must be found without Questie ids")
    assert(count_calls("interact_with_object", dugan) == 1,
        "P9a FAIL: the goal-named NPC must be interacted with")
    assert(next_state == "INTERACT",
        "P9a FAIL: talk must route dialog handling through the INTERACT state (got " ..
        tostring(next_state) .. ")")
    print("  P9a PASS: talk ladder — goal-name rung reaches an NPC with no Questie id")
end

-- P9b — talk ladder rung 6: proximity fallback for a goal naming nobody
do
    -- 4yd: inside the 6yd interaction range, so this exercises the interact path
    -- of the proximity rung rather than its "navigate closer" hand-off.
    local stranger = mock.create_object({ pos = { x = 4, y = 0, z = 0 },
        name = "Generic Questgiver", npc_id = 1234, unit = true, valid = true, guid = "stranger" })
    local step = { num = 1, is_complete = false, waypoint = { map_id = 0, x = 0, y = 0 },
        goals = { { type = "talk", npc_id = 0, target = "Turn In Here" } } }
    local ctx = build_ctx(step, nil, { stranger })
    local shared = new_shared("talk")
    local next_state = do_action.run(shared, ctx)
    assert(count_calls("set_target", stranger) == 1,
        "P9b FAIL: proximity rung should accept a living unit within 30yd")
    assert(next_state == "INTERACT",
        "P9b FAIL: proximity talk must hand dialog to INTERACT (got " .. tostring(next_state) .. ")")
    print("  P9b PASS: talk ladder — proximity rung catches an unidentified questgiver")
end

-- P9c — a talk target out of interaction range hands the walk to IDLE/NAV
do
    local far = mock.create_object({ pos = { x = 30, y = 0, z = 0 },
        name = "Marshal Dughan", npc_id = 7000, unit = true, valid = true, guid = "far_dugan" })
    local step = { num = 1, is_complete = false, waypoint = { map_id = 0, x = 0, y = 0 },
        goals = { { type = "talk", npc_id = 0, target = "Marshal Dughan" } } }
    local ctx = build_ctx(step, nil, { far })
    local shared = new_shared("talk")
    do_action.run(shared, ctx)
    assert(count_calls("interact_with_object", nil) == 0,
        "P9c FAIL: an NPC 30yd away must not be interacted with")
    assert(shared._nav_destination ~= nil and math.abs(shared._nav_destination.x - 30) < 1,
        "P9c FAIL: out-of-range talk target should set the nav destination to the NPC")
    print("  P9c PASS: talk target out of range → NAV to the NPC (no remote interact)")
end

-- P10a — repeating the same action type doubles the pause (0.5s → 1s)
do
    local step = { num = 1, is_complete = false, waypoint = { map_id = 0, x = 0, y = 0 },
        goals = { { type = "kill", npc_id = 0 } } }
    local ctx = build_ctx(step, nil, {})
    ctx.combat_helper = { is_current_target_valid = function() return false end }
    local shared = new_shared("kill")

    do_action.run(shared, ctx)
    local first = shared._action_pause_timer - ctx.now
    assert(first >= 0.475 and first <= 0.55,
        "P10a FAIL: first repetition should pause ~0.5s (got " .. tostring(first) .. ")")

    ctx.now = ctx.now + 5.0   -- let the pause expire, same action type again
    do_action.run(shared, ctx)
    local second = shared._action_pause_timer - ctx.now
    assert(second >= 0.95 and second <= 1.1,
        "P10a FAIL: repeated action type should back off to ~1s (got " .. tostring(second) .. ")")
    assert(shared._action_loop_count == 1, "P10a FAIL: loop counter should be 1")
    print("  P10a PASS: progressive pacing — 0.5s then 1.0s for repeated action types")
end

-- P10b — talk/gossip uses the short 0.3s frame wait, not the general pause
do
    local step = { num = 1, is_complete = false, waypoint = { map_id = 0, x = 0, y = 0 },
        goals = { { type = "talk", npc_id = 0, target = "Nobody Here" } } }
    local ctx = build_ctx(step, nil, {})
    local shared = new_shared("talk")
    do_action.run(shared, ctx)
    assert(shared._action_pause_timer == ctx.now + 0.3,
        "P10b FAIL: talk should wait 0.3s for the dialog frame (got " ..
        tostring(shared._action_pause_timer - ctx.now) .. ")")
    print("  P10b PASS: talk pacing — 0.3s frame wait")
end

do
    local combat_helper = require("combat_helper_sylvanas")
    local do_action = require("quest_state/do_action_state")

    -- NOTE: no `type` — this is the live shape.
    local function live_ctx(enemy, class_id)
        local step = {
            num = 91, is_complete = false,
            waypoint = { map_id = 0, x = 0.30, y = 0.50 },
            goals = { { npc_id = 0, text = nil, target = "Stonevault Shaman" } },
        }
        local ctx = build_ctx(step, nil, { enemy })
        ctx.combat_helper = combat_helper
        mock._player._class = class_id
        return ctx
    end

    local function fresh_shared()
        return { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
            _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
            _at_quest_object_timer = 0, _action_pause_timer = 0, _last_step_num = 91,
            _respawn_wait_until = 0 }
    end

    _G.EaxRotations = _G.EaxRotations or {}
    local NS = _G.EaxRotations
    NS.AUTO_ATTACK_WAND = 5019
    NS.AUTO_ATTACK_MELEE = 6603
    local wand_calls = {}
    local orig_start = NS.start_auto_attack
    NS.start_auto_attack = function(target, attack_type)
        wand_calls[#wand_calls + 1] = { target = target, attack_type = attack_type }
        return attack_type == 5019
    end

    -- S21 — only a corpse matches the goal's name: nothing may be attacked or targeted.
    do
        local corpse = mock.create_object({
            pos = { x = 2, y = 0, z = 0 }, name = "Stonevault Shaman",
            unit = true, valid = true, dead = true, lootable = false,
            attackable = true, enemy = true, guid = "da_corpse_2",
        })
        local ctx = live_ctx(corpse, 5)   -- PRIEST
        local logs = {}
        ctx.debug_log = function(msg) logs[#logs + 1] = msg end
        local shared = fresh_shared()
        local calls_before = #wand_calls
        do_action.run(shared, ctx)
        assert(#wand_calls == calls_before,
            "S21 FAIL: an already-looted corpse must never be auto-attacked")
        assert(mock._player._target ~= corpse,
            "S21 FAIL: the corpse must not be set as the target")
        for _, msg in ipairs(logs) do
            assert(not msg:find("targeted enemy", 1, true),
                "S21 FAIL: reported targeting a corpse as an enemy: " .. tostring(msg))
        end
        local skipped = false
        for _, msg in ipairs(logs) do
            if msg:find("matched only corpses", 1, true) then skipped = true end
        end
        assert(skipped, "S21 FAIL: a corpse-only name match must be reported as skipped")
        print("  S21 PASS: live goal shape + corpse-only match → no pull, corpse not targeted")
    end

    -- S22 — priest, live mob 20yd: inside cast range, open with the wand, do not close.
    do
        local mob = mock.create_object({
            pos = { x = 20, y = 0, z = 5 }, name = "Stonevault Shaman",
            unit = true, valid = true, attackable = true, enemy = true, guid = "da_live_20",
        })
        local ctx = live_ctx(mob, 5)   -- PRIEST
        local shared = fresh_shared()
        local calls_before = #wand_calls
        do_action.run(shared, ctx)
        assert(#wand_calls == calls_before + 1 and wand_calls[#wand_calls].attack_type == 5019,
            "S22 FAIL: a priest in range must open with AUTO_ATTACK_WAND on the live goal lane")
        assert(wand_calls[#wand_calls].target == mob, "S22 FAIL: the pull must target the mob")
        assert(shared._nav_destination == nil,
            "S22 FAIL: an enemy already in cast range must not be walked to")
        print("  S22 PASS: live goal shape + priest in range → wand pull, no walk-in")
    end

    -- S23 — priest, live mob 40yd: approach, carrying the 28yd stand-off.
    do
        local mob = mock.create_object({
            pos = { x = 40, y = 0, z = 5 }, name = "Stonevault Shaman",
            unit = true, valid = true, attackable = true, enemy = true, guid = "da_live_40",
        })
        local ctx = live_ctx(mob, 5)   -- PRIEST
        local shared = fresh_shared()
        local calls_before = #wand_calls
        do_action.run(shared, ctx)
        assert(shared._nav_destination == mob:get_position(),
            "S23 FAIL: an out-of-range enemy must become the nav destination")
        assert(shared._nav_engage_sq == 784 and shared._nav_engage_dest == mob:get_position(),
            "S23 FAIL: the approach must stop at 28yd, not walk onto the mob")
        assert(#wand_calls == calls_before,
            "S23 FAIL: out of range there is nothing to pull yet")
        print("  S23 PASS: live goal shape + priest out of range → NAV with a 28yd stand-off")
    end

    -- S24 — warrior on the live lane: melee classes still close, no ranged pull.
    do
        local mob = mock.create_object({
            pos = { x = 20, y = 0, z = 5 }, name = "Stonevault Shaman",
            unit = true, valid = true, attackable = true, enemy = true, guid = "da_live_melee",
        })
        local ctx = live_ctx(mob, 1)   -- WARRIOR
        local shared = fresh_shared()
        local calls_before = #wand_calls
        do_action.run(shared, ctx)
        assert(#wand_calls == calls_before,
            "S24 FAIL: melee classes must not attempt a ranged pull")
        assert(shared._nav_destination == mob:get_position(),
            "S24 FAIL: a melee class 20yd out must keep closing")
        assert(shared._nav_engage_sq == nil,
            "S24 FAIL: melee classes take no stand-off")
        print("  S24 PASS: live goal shape + melee class → closes to melee, no pull")
    end

    NS.start_auto_attack = orig_start
end

-- S19 — the kill lane must kill the mob the GOAL names, not the nearest one.
-- Live: on the guide's `kill Rock Elemental##92+` / `collect 3 Large Stone Slab##4627 |q 711/1`
-- the bot killed LESSER Rock Elementals. Two defects met: the goal's id was dropped (the bridge
-- leaves npc_id at 0 and `goal.npc_id or goal.target_id` returns 0, because 0 is truthy in Lua),
-- and the name lookup matched substrings, so "Lesser Rock Elemental" satisfied "Rock Elementals"
-- (it contains it). The slab drops from creature 92 only. This scenario is the regression test:
-- the LESSER one is nearer and must not be touched.
do
    mock.reset()
    local rock = mock.create_object({
        pos = { x = 30, y = 0, z = 0 },
        name = "Rock Elemental",
        npc_id = 92,
        unit = true, valid = true, enemy = true, attackable = true,
        guid = "rock_92",
    })
    local lesser = mock.create_object({
        pos = { x = 5, y = 0, z = 0 },
        name = "Lesser Rock Elemental",
        npc_id = 2735,
        unit = true, valid = true, enemy = true, attackable = true,
        guid = "lesser_2735",
    })
    -- Zygor's raw goal for that step: the trailing + pluralises the name, and the id is the mob
    -- that drops the item. npc_id is the bridge's zero, target_id carries the identity.
    local step = {
        num = 50,
        is_complete = false,
        waypoint = { map_id = 0, x = 0.30, y = 0.50 },
        goals = { { type = "kill", target = "Rock Elementals", npc_id = 0, target_id = 92, quest_id = 711 } },
    }
    local ctx = build_ctx(step, nil, { lesser, rock })
    local NS = _G.EaxRotations
    local orig_start = NS and NS.start_auto_attack
    if NS then NS.start_auto_attack = function() end end

    local do_action = require("quest_state/do_action_state")
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0,
        _post_interact_timer = 0, _at_quest_object_timer = 0,
        _action_pause_timer = 0, _last_step_num = 50, _last_goal_type = "kill",
        _respawn_wait_until = 12345 }
    do_action.run(shared, ctx)

    if NS and orig_start then NS.start_auto_attack = orig_start end

    local targeted_rock, targeted_lesser = false, false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "set_target" then
            if call[2] == rock then targeted_rock = true end
            if call[2] == lesser then targeted_lesser = true end
        end
    end
    assert(not targeted_lesser,
        "S19 FAIL: the nearer LESSER Rock Elemental was targeted — it does not drop Large Stone " ..
        "Slab (creature 92 does), so the objective cannot advance")
    assert(targeted_rock,
        "S19 FAIL: the goal's own mob (Rock Elemental, id 92) was not targeted — the id was " ..
        "dropped again (a zero npc_id hides target_id) or the name won over the id")
    print("  S19 PASS: the kill lane targets the goal's own mob (id), never the nearer lookalike")
end
-- S25 — the AREA lane must act on the goal's own mob too.
-- The same step reaches this lane whenever Zygor's goal type is "area" (the live logs are full of
-- `DO_ACTION: area — approaching '<name>'`), and it picks by name. With the LESSER lookalike nearer,
-- "Rock Elementals" matched it — the name lookup is a substring test and the Lesser contains the
-- Rock. This goal carries no id, so the name is the only evidence there is, and it must be exact.
do
    mock.reset()
    local rock = mock.create_object({ pos = { x = 45, y = 0, z = 0 }, name = "Rock Elemental",
        npc_id = 92, unit = true, valid = true, enemy = true, attackable = true, guid = "rock_92" })
    local lesser = mock.create_object({ pos = { x = 3, y = 0, z = 0 }, name = "Lesser Rock Elemental",
        npc_id = 2735, unit = true, valid = true, enemy = true, attackable = true, guid = "lesser_2735" })
    local step = {
        num = 51,
        is_complete = false,
        waypoint = { map_id = 0, x = 0.30, y = 0.50 },
        goals = { { type = "area", target = "Rock Elementals", npc_id = 0 } },
    }
    local ctx = build_ctx(step, nil, { lesser, rock })
    local NS = _G.EaxRotations
    local orig_start = NS and NS.start_auto_attack
    if NS then NS.start_auto_attack = function() end end

    local do_action = require("quest_state/do_action_state")
    local shared = { _nav_destination = nil, _area_wait_timer = 0, _action_pause_timer = 0,
        _last_step_num = 51, _last_goal_type = "area", _interact_cooldown = 0, _loot_cooldown = 0,
        _post_interact_timer = 0, _at_quest_object_timer = 0 }
    do_action.run(shared, ctx)

    if NS and orig_start then NS.start_auto_attack = orig_start end

    local targeted_lesser = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "set_target" and call[2] == lesser then targeted_lesser = true end
    end
    assert(not targeted_lesser,
        "S25a FAIL: the area lane targeted the nearer LESSER Rock Elemental — it drops nothing on " ..
        "this objective (Rock Elemental, id 92, does)")
    local dest = shared._nav_destination
    assert(dest ~= nil, "S25b FAIL: the area lane should be heading somewhere")
    local dx, dy = (dest.x or 0) - 45, (dest.y or 0) - 0
    assert(dx * dx + dy * dy < 1,
        "S25c FAIL: the area lane must walk to the goal's own mob at 45yd, got " ..
        tostring(dest.x) .. "," .. tostring(dest.y))
    print("  S25 PASS: the area lane ignores the nearer lookalike and heads for the goal's mob")
end

-- ============================================================================
-- S26-S29 — EVERY door into a fight is gated, not just the one the area lane's name path uses.
-- ============================================================================
-- Live report that produced these: "the wait before going to next mob still is not honored
-- correctly, it still tries to engage mobs on low health/mana". The gate's own rules were never the
-- problem — the problem was the doors it was not standing in. Four of them start a fight on the
-- bot's main leveling paths with no gate consulted at all:
--   * the KILL lane's goal-mob path (the goal's own npc_id, i.e. every kill objective) — S26
--   * the AREA lane's name path, which WALKS to the mob before the in-range gate can fire — S27
--   * the AREA lane's last resort, "nothing of the goal's is here, kill what is nearest" — S28
-- and one door that must stay open: a friendly goal NPC (a turn-in) is not a fight, whatever the
-- player's health — S29. Each scenario carries its own control at full mana, so a refusal can only
-- be the gate: a lane that engages nothing for some other reason fails the control.

-- Every fixture below goes through this: a low-mana caster, one run of the lane, then the control.
-- The menu stub matters: build_ctx's `menu.get` answers false to everything, which switches the whole
-- gate off (M.enabled reads the eaxaq_pull_gate row through it). A scenario that forgot this would
-- prove nothing at all — it would be testing the switch, not the rule.
local function gate_on(ctx, rows)
    rows = rows or {}
    ctx.menu = {
        get = function(key, fallback)
            if rows[key] ~= nil then return rows[key] end
            if key == "pull_gate" then return true end
            return fallback
        end,
    }
    return ctx
end
local function mana_bar(player_obj, mana, max_mana)
    player_obj._mana = mana
    player_obj._max_mana = max_mana or 100
end

-- S26

do
    pull_safety.reset()
    local quest_mob = mock.create_object({ pos = { x = 25, y = 0, z = 0 }, name = "Stonevault Shaman",
        npc_id = 701, unit = true, valid = true, enemy = true, attackable = true,
        guid = "shaman_701" })
    local step = { num = 34, is_complete = false, waypoint = { map_id = 0, x = 0, y = 0 },
        goals = { { type = "kill", npc_id = 701 } } }
    local ctx = gate_on(build_ctx(step, nil, { quest_mob }))
    ctx.combat_helper = { is_current_target_valid = function() return false end }
    ctx.now = 500.0
    mana_bar(mock._player, 5)

    local NS = _G.EaxRotations
    local orig_start = NS and NS.start_auto_attack
    local attacked = 0
    if NS then NS.start_auto_attack = function() attacked = attacked + 1 end end

    local do_action = require("quest_state/do_action_state")
    local function fresh_shared()
        return { _nav_destination = nil, _respawn_wait_until = 0, _action_pause_timer = 0,
            _last_step_num = 34, _last_goal_type = "kill", _interact_cooldown = 0,
            _loot_cooldown = 0, _post_interact_timer = 0, _area_wait_timer = 0 }
    end

    mock._input_calls = {}
    do_action.run(fresh_shared(), ctx)
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "set_target",
            "S26a FAIL: the kill lane targeted the goal's own mob on 5% mana — the path every kill " ..
            "objective takes must consult pull_safety.gate before it tags anything")
    end
    assert(attacked == 0, "S26b FAIL: no auto-attack may be opened on an empty bar")
    assert(tostring(pull_safety.last_reason()):find("mana") ~= nil,
        "S26c FAIL: the reason should name mana, got " .. tostring(pull_safety.last_reason()))

    pull_safety.reset()
    mana_bar(mock._player, 100)
    ctx.now = 600.0
    mock._input_calls = {}
    do_action.run(fresh_shared(), ctx)
    local targeted = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "set_target" and call[2] == quest_mob then targeted = true end
    end
    assert(targeted,
        "S26d FAIL: with mana back the kill lane must tag its goal mob — otherwise S26 proves " ..
        "nothing about the gate")

    if NS and orig_start then NS.start_auto_attack = orig_start end
    print("  S26 PASS: the kill lane's goal-mob path is gated, and engages again on a full bar")
end

-- S27 — the area lane's name path: the WALK is gated, not only the swing

do
    pull_safety.reset()
    local rock = mock.create_object({ pos = { x = 45, y = 0, z = 0 }, name = "Rock Elemental",
        npc_id = 92, unit = true, valid = true, enemy = true, attackable = true, guid = "rock_92" })
    local step = { num = 51, is_complete = false, waypoint = { map_id = 0, x = 0.30, y = 0.50 },
        goals = { { type = "area", target = "Rock Elementals", npc_id = 0 } } }
    local ctx = gate_on(build_ctx(step, nil, { rock }))
    ctx.now = 700.0
    mana_bar(mock._player, 5)

    local NS = _G.EaxRotations
    local orig_start = NS and NS.start_auto_attack
    if NS then NS.start_auto_attack = function() end end

    local do_action = require("quest_state/do_action_state")
    local function fresh_shared()
        return { _nav_destination = nil, _area_wait_timer = 0, _action_pause_timer = 0,
            _last_step_num = 51, _last_goal_type = "area", _interact_cooldown = 0,
            _loot_cooldown = 0, _post_interact_timer = 0, _at_quest_object_timer = 0 }
    end

    mock._input_calls = {}
    do_action.run(fresh_shared(), ctx)
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "set_target", "S27a FAIL: a 45yd hostile must not be tagged on 5% mana")
    end
    local dest = ctx and nil
    local sh = fresh_shared()
    do_action.run(sh, ctx)
    dest = sh._nav_destination
    if dest then
        local dx, dy = (dest.x or 0) - 45, (dest.y or 0) - 0
        assert(dx * dx + dy * dy > 25,
            "S27b FAIL: the area lane walked toward the mob it would refuse to fight — the walk is " ..
            "half the pull, and on an empty bar the bot must hold where it is")
    end
    assert(pull_safety.destination(ctx) ~= nil,
        "S27c FAIL: refusing the pull must leave the state machine somewhere to stand")

    pull_safety.reset()
    mana_bar(mock._player, 100)
    ctx.now = 800.0
    local sh2 = fresh_shared()
    do_action.run(sh2, ctx)
    local dest2 = sh2._nav_destination
    assert(dest2 ~= nil and math.abs((dest2.x or 0) - 45) < 1,
        "S27d FAIL: with mana back the same lane must walk to the mob (got " ..
        tostring(dest2 and dest2.x) .. ")")

    if NS and orig_start then NS.start_auto_attack = orig_start end
    print("  S27 PASS: the area lane's walk to a hostile is gated, and resumes on a full bar")
end

-- S28 — the area lane's nearest-enemy fallback

do
    pull_safety.reset()
    local boar = mock.create_object({ pos = { x = 2, y = 0, z = 0 }, name = "Stonetusk Boar",
        npc_id = 0, unit = true, valid = true, enemy = true, attackable = true, guid = "boar_fb" })
    local step = { num = 71, is_complete = false, waypoint = { map_id = 0, x = 0, y = 0 },
        goals = { { type = "area", target = "", npc_id = 0 } } }
    local ctx = gate_on(build_ctx(step, nil, { boar }))
    ctx.now = 900.0
    mana_bar(mock._player, 5)

    local NS = _G.EaxRotations
    local orig_start = NS and NS.start_auto_attack
    local attacked = 0
    local attacked_obj = nil
    if NS then
        NS.start_auto_attack = function(obj) attacked = attacked + 1; attacked_obj = obj end
    end

    local do_action = require("quest_state/do_action_state")
    local function fresh_shared()
        return { _nav_destination = nil, _area_wait_timer = 0, _action_pause_timer = 0,
            _last_step_num = 71, _last_goal_type = "area", _interact_cooldown = 0,
            _loot_cooldown = 0, _post_interact_timer = 0, _at_quest_object_timer = 0 }
    end

    mock._input_calls = {}
    do_action.run(fresh_shared(), ctx)
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "set_target",
            "S28a FAIL: the area lane's nearest-enemy fallback targeted a mob on 5% mana — this is " ..
            "the widest door into a fight and it must be gated")
    end
    assert(attacked == 0, "S28b FAIL: no attack may be opened on an empty bar")

    pull_safety.reset()
    mana_bar(mock._player, 100)
    ctx.now = 1000.0
    mock._input_calls = {}
    do_action.run(fresh_shared(), ctx)
    assert(attacked == 1 and attacked_obj == boar,
        "S28c FAIL: with mana back the fallback must open the fight (attacked=" ..
        tostring(attacked) .. ") — otherwise S28 proves nothing about the gate")

    if NS and orig_start then NS.start_auto_attack = orig_start end
    print("  S28 PASS: the area lane's nearest-enemy fallback is gated")
end

-- S29 — the door that must stay OPEN: a friendly goal NPC is not a fight

do
    pull_safety.reset()
    local giver = mock.create_object({ pos = { x = 3, y = 0, z = 0 }, name = "Marshal Dughan",
        npc_id = 7000, unit = true, valid = true, attackable = false, guid = "giver_7000" })
    local step = { num = 38, is_complete = false, waypoint = { map_id = 0, x = 0.30, y = 0.50 },
        goals = { { type = "area", target = "Marshal Dughan", npc_id = 0 } } }
    local ctx = gate_on(build_ctx(step, nil, { giver }))
    ctx.now = 1100.0
    mana_bar(mock._player, 5)
    assert(pull_safety.enabled(ctx), "S29a FAIL: the gate should be on for this scenario")

    local do_action = require("quest_state/do_action_state")
    local shared = { _nav_destination = nil, _area_wait_timer = 0, _action_pause_timer = 0,
        _last_step_num = 38, _last_goal_type = "area", _interact_cooldown = 0,
        _loot_cooldown = 0, _post_interact_timer = 0, _at_quest_object_timer = 0 }
    mock._input_calls = {}
    do_action.run(shared, ctx)

    local targeted = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "set_target" and call[2] == giver then targeted = true end
    end
    assert(targeted,
        "S29b FAIL: a quest giver was refused on 5% mana — the gate is about starting fights, and " ..
        "blocking a turn-in is a worse bug than the pull it was meant to prevent")
    assert(pull_safety.last_reason() == nil,
        "S29c FAIL: nothing about turning a quest in is a pull, got " ..
        tostring(pull_safety.last_reason()))
    print("  S29 PASS: a friendly goal NPC is still interacted with on an empty bar")
end

print("PASS test_do_action_state")
os.exit(0)
