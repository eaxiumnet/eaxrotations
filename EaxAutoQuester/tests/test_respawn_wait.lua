-- test_respawn_wait.lua — Unit tests for respawn wait logic in idle_state + do_action_state

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- ============================================================================
-- Mock helpers
-- ============================================================================

local function make_ctx(now_val, has_enemy)
    mock.set_time(now_val)
    local me = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    mock._player = me

    local enemy_list = {}
    if has_enemy then
        enemy_list[#enemy_list + 1] = mock.create_object({
            name = "Test Boar", pos = { x = 5, y = 0, z = 0 },
            enemy = true, attackable = true,
        })
    end
    mock._objects = enemy_list

    return {
        now = now_val,
        me = me,
        debug_log = function(msg) end,
        utils = {
            squared_distance = function(a, b)
                local dx = (a.x or 0) - (b.x or 0)
                local dy = (a.y or 0) - (b.y or 0)
                local dz = (a.z or 0) - (b.z or 0)
                return dx*dx + dy*dy + dz*dz
            end,
            throttle = function(key, interval) return true end,
        },
        zygor = {
            get_current_step_info = function()
                return { text = "Kill 10 Test Boars", is_complete = false, step_num = 1, goals = { { type = "kill", target = "Test Boar", text = "Kill 10 Test Boars" } } }
            end,
            get_current_waypoint_world = function() return nil end,
            has_current_step = function() return true end,
        },
        npc_manager = {
            get_nearest_enemy = function(range, scanner)
                for _, obj in ipairs(mock._objects) do
                    if obj._enemy then return obj end
                end
                return nil
            end,
            find_nearest_quest_unit = function() return nil end,
        },
        object_scanner = {
            get_visible_objects = function() return mock._objects end,
        },
        nav = { is_navigating = function() return false end, stop = function() end },
        quest_interaction = { handle_any_frame = function() return nil end },
        combat_helper = {},
        detect_open_frame = function() return false end,
        safe = function(v, f) return v or f end,
    }
end

-- ============================================================================
-- S1: kill goal with no enemy → sets respawn wait timer
-- ============================================================================
local do_action = require("quest_state/do_action_state")
mock.reset()
mock.set_time(10.0)
local shared_s1 = { _area_wait_timer = 0, _action_pause_timer = 0 }
local ctx = make_ctx(10.0, false)
local result = do_action.run(shared_s1, ctx)
assert(shared_s1._respawn_wait_until > 10.0, "S1a FAIL: respawn timer should be set")
assert(result == "IDLE", "S1b FAIL: should return IDLE, got " .. tostring(result))
print("  S1 PASS: no enemy → respawn wait set")

-- ============================================================================
-- S2: idle during respawn wait → stays IDLE, scans every 5s
-- ============================================================================
local idle = require("quest_state/idle_state")
mock.reset()
mock.set_time(10.0)
local shared_s2 = { _area_wait_timer = 0, _action_pause_timer = 0, _loot_cooldown = 0, _interact_cooldown = 0, _last_step_num = 1, _respawn_wait_until = 100.0, _respawn_target_name = "Test Boar", _respawn_last_scan = 0 }
ctx = make_ctx(10.0, false)
result = idle.run(shared_s2, ctx)
assert(result == "IDLE", "S2a FAIL: should stay IDLE during wait, got " .. tostring(result))
assert(shared_s2._respawn_last_scan >= 10.0, "S2b FAIL: scan timestamp should update")

-- Second call within 5s should not scan again
local last_scan = shared_s2._respawn_last_scan
ctx = make_ctx(12.0, false)
result = idle.run(shared_s2, ctx)
assert(result == "IDLE", "S2c FAIL: should stay IDLE")
assert(shared_s2._respawn_last_scan == last_scan, "S2d FAIL: should not scan again within 5s")
print("  S2 PASS: idle respawn wait — throttled scans")

-- ============================================================================
-- S3: respawn appears during wait → exits wait and resumes DO_ACTION
-- ============================================================================
mock.reset()
mock.set_time(20.0)
local shared_s3 = { _area_wait_timer = 0, _action_pause_timer = 0, _loot_cooldown = 0, _interact_cooldown = 0, _last_step_num = 1, _respawn_wait_until = 100.0, _respawn_target_name = "Test Boar", _respawn_last_scan = 0 }
ctx = make_ctx(20.0, true)  -- enemy now present
result = idle.run(shared_s3, ctx)
assert(result == "DO_ACTION", "S3a FAIL: enemy respawned → should return DO_ACTION, got " .. tostring(result))
assert(shared_s3._respawn_wait_until == 0, "S3b FAIL: timer should be cleared")
print("  S3 PASS: respawn detected → resumes DO_ACTION")

-- ============================================================================
-- S4: step complete → respawn wait cleared
-- ============================================================================
mock.reset()
mock.set_time(30.0)
local shared_s4 = { _area_wait_timer = 0, _action_pause_timer = 0, _loot_cooldown = 0, _interact_cooldown = 0, _last_step_num = 1, _respawn_wait_until = 100.0, _respawn_target_name = "Test Boar" }
ctx = make_ctx(30.0, false)
ctx.zygor.get_current_step_info = function()
    return { text = "Kill 10 Test Boars", is_complete = true, step_num = 1, goals = {} }
end
result = idle.run(shared_s4, ctx)
assert(result == "WAITING", "S4a FAIL: step complete → WAITING")
assert(shared_s4._respawn_wait_until == 0, "S4b FAIL: respawn timer should clear on step complete")
print("  S4 PASS: step complete clears respawn wait")

-- ============================================================================
-- S5: timer expires → retries objective
-- ============================================================================
mock.reset()
mock.set_time(200.0)
local shared_s5 = { _area_wait_timer = 0, _action_pause_timer = 0, _loot_cooldown = 0, _interact_cooldown = 0, _last_step_num = 1, _respawn_wait_until = 190.0, _respawn_target_name = "Test Boar", _respawn_last_scan = 0 }
ctx = make_ctx(200.0, false)
result = idle.run(shared_s5, ctx)
assert(shared_s5._respawn_wait_until == 0, "S5a FAIL: expired timer should be cleared")
print("  S5 PASS: expired respawn timer → retry")

-- ============================================================================
-- S9 — a live goal target ends the wait even when the enemy probe sees nothing
-- The enemy probe only answers for hostiles it can attack, and reads at most the first 50 visible
-- objects; a freshly spawned mob of the goal's own name is the thing being waited for.
-- ============================================================================
do
    local function live_mob(dead)
        return mock.create_object({ name = "Lesser Rock Elemental", pos = { x = 20, y = 0, z = 0 },
            unit = true, dead = dead, enemy = true, attackable = true })
    end

    mock.reset()
    mock.set_time(900.0)
    local shared_s9 = { _area_wait_timer = 0, _action_pause_timer = 0, _loot_cooldown = 0,
        _interact_cooldown = 0, _last_step_num = 47, _respawn_wait_until = 1000.0,
        _respawn_target_name = "Lesser Rock Elementals", _respawn_last_scan = 0 }
    local ctx9 = make_ctx(900.0, false)
    ctx9.zygor.get_current_step_info = function()
        return { text = "Kill Lesser Rock Elementals", is_complete = false, step_num = 47,
                 goals = { { type = "kill", target = "Lesser Rock Elementals", npc_id = 0 } } }
    end
    local found = { live_mob(false) }
    ctx9.npc_manager.find_interactable_objects = function() return found end
    -- A corpse under the same name is NOT a respawn. The wait continues — whether it spends the
    -- tick walking to the next spawn point (NAV) or standing (IDLE) is S6/S7's business, so what
    -- is asserted here is that it does not resume as if the objective were present.
    found[1].is_dead = function() return true end
    local res9a = idle.run(shared_s9, ctx9)
    assert(res9a ~= "DO_ACTION",
        "S9a FAIL: a corpse of the goal's own mob must not end the wait, got " .. tostring(res9a))
    assert(shared_s9._respawn_wait_until > 0,
        "S9b FAIL: the wait must still be armed after a corpse was found")
    -- The live one does, even though the enemy probe answers nothing.
    found[1] = live_mob(false)
    shared_s9._respawn_last_scan = 0
    local res9 = idle.run(shared_s9, ctx9)
    assert(res9 == "DO_ACTION",
        "S9c FAIL: a live goal target must end the respawn wait, got " .. tostring(res9))
    assert(shared_s9._respawn_wait_until == 0, "S9d FAIL: the wait must be cleared")
    print("  S9 PASS: a live goal target ends the wait; a corpse of the same name does not")
end

-- ============================================================================
-- S11 — the wait ends for the mob the GOAL names, not for a lookalike
-- Live: on the guide's `kill Rock Elemental##92+` / `collect 3 Large Stone Slab##4627 |q 711/1`,
-- the bot killed LESSER Rock Elementals — a different creature (2735) that drops nothing on this
-- objective. The name lookup matches substrings, and "Lesser Rock Elemental" contains
-- "Rock Elemental"; the goal itself carries the id (Zygor's targetid), which is the identity.
-- ============================================================================
do
    local function rock_mob(name, npc_id)
        return mock.create_object({ name = name, pos = { x = 20, y = 0, z = 0 }, npc_id = npc_id,
            unit = true, dead = false, enemy = true, attackable = true })
    end

    mock.reset()
    mock.set_time(1200.0)
    local shared_s11 = { _area_wait_timer = 0, _action_pause_timer = 0, _loot_cooldown = 0,
        _interact_cooldown = 0, _last_step_num = 50, _respawn_wait_until = 1300.0,
        _respawn_target_name = "Rock Elementals", _respawn_last_scan = 0 }
    local ctx11 = make_ctx(1200.0, false)
    ctx11.zygor.get_current_step_info = function()
        return { text = "Kill Rock Elementals", is_complete = false, step_num = 50,
                 goals = { { type = "kill", target = "Rock Elementals", npc_id = 0, target_id = 92 } } }
    end

    -- A live LESSER Rock Elemental is present: not the objective, so the wait stands.
    local lesser = rock_mob("Lesser Rock Elemental", 2735)
    ctx11.npc_manager.find_interactable_objects = function() return { lesser } end
    local res11a = idle.run(shared_s11, ctx11)
    assert(res11a ~= "DO_ACTION",
        "S11a FAIL: a Lesser Rock Elemental is not the Rock Elemental the goal names, got " ..
        tostring(res11a) .. " — the objective (and its drop) cannot advance from it")
    assert(shared_s11._respawn_wait_until > 0,
        "S11b FAIL: the wait must stay armed while only a lookalike is present")

    -- The goal's own mob ends it.
    local rock = rock_mob("Rock Elemental", 92)
    ctx11.npc_manager.find_interactable_objects = function() return { lesser, rock } end
    shared_s11._respawn_last_scan = 0
    local res11 = idle.run(shared_s11, ctx11)
    assert(res11 == "DO_ACTION",
        "S11c FAIL: the goal's own mob must end the wait, got " .. tostring(res11))
    assert(shared_s11._respawn_wait_until == 0, "S11d FAIL: the wait must be cleared")
    print("  S11 PASS: a lookalike does not end the wait; the goal's own mob does")
end
print("PASS test_respawn_wait")
os.exit(0)
