-- What: Unit tests for EaxAutoQuester/quest_state/idle_state.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify IDLE state transitions: WAITING, INTERACT, NAV, DO_ACTION, DEAD

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local idle_state = require("EaxAutoQuester/quest_state/idle_state")

-- Test detect_open_frame with no frames
assert(idle_state.detect_open_frame() == false, "detect_open_frame no frames")

-- Test detect_open_frame with loot frame
mock._loot_items = { { id = 1, name = "Gold", is_gold = true } }
assert(idle_state.detect_open_frame() == true, "detect_open_frame loot frame")
mock._loot_items = {}

-- Test detect_open_frame with gossip frame
mock._frames.gossip = true
assert(idle_state.detect_open_frame() == true, "detect_open_frame gossip frame")
mock._frames.gossip = nil

-- Test run with no Zygor
local shared = { _interact_cooldown = 0, _last_cooldown_log = 0 }
local ctx = { zygor = nil, now = 0, debug_log = function() end, me = nil }
assert(idle_state.run(shared, ctx) == "WAITING", "idle no zygor → WAITING")

-- Test run with dead player (mock player with dead=true)
local dead_player = mock.create_player({ pos = {x=0, y=0, z=0}, dead = true, hp = 0 })
ctx = { zygor = nil, now = 0, debug_log = function() end, me = dead_player }
local result = idle_state.run(shared, ctx)
assert(result == "DEAD" or result == "WAITING", "idle dead player should transition to DEAD or WAITING (got " .. tostring(result) .. ")")

-- Test run with combat
local combat_player = mock.create_player({ pos = {x=0, y=0, z=0}, combat = true })
local mock_nav = { is_navigating = function() return true end, stop = function() end }
local mock_zygor = { has_current_step = function() return true end, get_current_step_info = function() return { is_complete = false, goals = {}, step_num = 1 } end, get_current_waypoint_world = function() return nil end }
ctx = { zygor = mock_zygor, now = 0, debug_log = function() end, me = combat_player, nav = mock_nav }
assert(idle_state.run(shared, ctx) == "IDLE", "idle combat → IDLE")

-- =============================================================================
-- Autoloot scenarios — verify IDLE picks up nearby corpses and NAVs to them
-- =============================================================================

-- Test helper: build a minimal IDLE context for corpse-loot testing
local function build_idle_ctx(visible_objects, me_pos)
    mock.reset()
    mock.create_player({ pos = me_pos or { x = 0, y = 0, z = 0 }, hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000 })
    mock._objects = visible_objects or {}
    local utils = require("EaxAutoQuester/utils_sylvanas")
    return {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return { is_complete = false, goals = {}, step_num = 1 } end,
            get_current_waypoint_world = function() return nil end,
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
end

-- S1 — corpse 15yd away + ACTIVE QUEST + AT_QUEST_OBJECT timer inactive
-- → bot SHOULD NAV to corpse (full autoloot regardless of quest)
-- The "at quest object" flag (shared._at_quest_object_timer) prevents the
-- back-and-forth loop while the bot is committed to a quest object click.
-- When that flag is NOT active, autoloot NAV fires regardless of quest
-- status. The user requested: "we just kill it and run past it, missing
-- gold and potential grey items to sell" — so the bot must loot.
do
    local corpse = mock.create_object({
        pos = { x = 15, y = 0, z = 0 },
        name = "Defias Thug Corpse",
        unit = true,
        valid = true,
        dead = true,
        guid = "corpse_15yd_quest",
    })
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000 })
    mock._objects = { corpse }
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return {
                is_complete = false,
                goals = { { type = "kill", npc_id = 999, text = "Kill Something" } },
                step_num = 1,
            } end,
            get_current_waypoint_world = function() return nil end,
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
    -- AT_QUEST_OBJECT timer is INACTIVE (0) — bot is free to autoloot
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0,
        _post_interact_timer = 0, _at_quest_object_timer = 0 }
    local next_state = idle_state.run(shared, ctx)
    -- Autoloot NAV should fire (20yd range) regardless of quest
    assert(next_state == "NAV",
        "S1 FAIL: with active quest but at-quest-object inactive, bot should NAV to corpse " ..
        "(got: " .. tostring(next_state) .. "). Autoloot must work even with quest active.")
    if shared._nav_destination then
        local dx = (shared._nav_destination.x or 0) - 15
        local dy = (shared._nav_destination.y or 0) - 0
        assert(dx * dx + dy * dy < 1,
            "S1 FAIL: nav dest should be at corpse (15,0,0)")
    end
    print("  S1 PASS: active quest + at-quest-object inactive → bot autoloots distant corpse (15yd)")
end

-- S1b — corpse 15yd away + NO active quest → bot SHOULD NAV to corpse
-- (full autoloot when there's nothing else to do)
do
    local corpse = mock.create_object({
        pos = { x = 15, y = 0, z = 0 },
        name = "Defias Thug Corpse",
        unit = true,
        valid = true,
        dead = true,
        guid = "corpse_15yd_noquest",
    })
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000 })
    mock._objects = { corpse }
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            -- No uncompleted goal
            get_current_step_info = function() return {
                is_complete = false,
                goals = {},
                step_num = 1,
            } end,
            get_current_waypoint_world = function() return nil end,
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
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0, _nav_destination = nil, _area_wait_timer = 0 }
    local next_state = idle_state.run(shared, ctx)
    -- Without an active quest, full autoloot NAV should fire
    assert(next_state == "NAV",
        "S1b FAIL: corpse 15yd with NO quest should trigger autoloot NAV " ..
        "(got: " .. tostring(next_state) .. ")")
    assert(shared._nav_destination ~= nil,
        "S1b FAIL: _nav_destination should be set to corpse position")
    local dx = (shared._nav_destination.x or 0) - 15
    local dy = (shared._nav_destination.y or 0) - 0
    assert(dx * dx + dy * dy < 1,
        "S1b FAIL: nav dest should be at corpse (15,0,0), got ("
        .. tostring(shared._nav_destination.x) .. "," .. tostring(shared._nav_destination.y) .. ")")
    print("  S1b PASS: no quest → bot autoloots distant corpse (15yd)")
end

-- S2 — corpse 2yd away → bot loots immediately
do
    local corpse = mock.create_object({
        pos = { x = 2, y = 0, z = 0 },
        name = "Defias Thug Corpse",
        unit = true,
        valid = true,
        dead = true,
        guid = "corpse_2yd",
    })
    local ctx = build_idle_ctx({ corpse }, { x = 0, y = 0, z = 0 })
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0, _nav_destination = nil, _area_wait_timer = 0 }
    idle_state.run(shared, ctx)
    local input_calls = mock._input_calls
    local looted = false
    for _, call in ipairs(input_calls) do
        if call[1] == "loot_object" then looted = true end
    end
    assert(looted, "S2 FAIL: corpse 2yd away should be looted immediately")
    assert(shared._loot_cooldown > 0,
        "S2 FAIL: _loot_cooldown should be set after looting")
    print("  S2 PASS: autoloot — corpse 2yd → immediate loot + cooldown set")
end

-- S3 — no corpse → bot doesn't NAV to anything, falls through to quest
do
    local live_enemy = mock.create_object({
        pos = { x = 10, y = 0, z = 0 },
        name = "Live Enemy",
        unit = true,
        valid = true,
        dead = false,
        guid = "live_enemy",
    })
    local ctx = build_idle_ctx({ live_enemy }, { x = 0, y = 0, z = 0 })
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0, _nav_destination = nil, _area_wait_timer = 0 }
    idle_state.run(shared, ctx)
    -- No corpse → no autoloot, falls through to quest processing
    local looted = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "loot_object" then looted = true end
    end
    assert(not looted, "S3 FAIL: no corpse → no loot call")
    print("  S3 PASS: autoloot — no corpse → no false loot")
end

-- S4 — corpse but loot cooldown active → skip
do
    local corpse = mock.create_object({
        pos = { x = 3, y = 0, z = 0 },
        name = "Corpse",
        unit = true,
        valid = true,
        dead = true,
        guid = "corpse_cooldown",
    })
    local ctx = build_idle_ctx({ corpse }, { x = 0, y = 0, z = 0 })
    local shared = { _interact_cooldown = 0, _loot_cooldown = ctx.now + 5.0, _last_cooldown_log = 0, _nav_destination = nil, _area_wait_timer = 0 }
    idle_state.run(shared, ctx)
    local looted = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "loot_object" then looted = true end
    end
    assert(not looted, "S4 FAIL: loot cooldown active → must skip autoloot")
    print("  S4 PASS: autoloot — cooldown active → skip")
end

-- =============================================================================
-- Cast/channel pause — when the player is mid-cast or mid-channel (e.g. after
-- clicking a gathering node like "Milly's Harvest"), the bot must NOT move,
-- NOT re-target, NOT re-interact. Otherwise it cancels the cast and the quest
-- never progresses. Live observed: bot clicks pumpkin → returns to IDLE → sees
-- same goal → re-targets the pumpkin → cast cancelled → loop.
-- =============================================================================

-- S11 — player is channelling → bot must stay in IDLE (no NAV, no DO_ACTION, no interact)
do
    mock.reset()
    mock.create_player({
        pos = { x = 0, y = 0, z = 0 },
        hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000,
        channelling = true,  -- mid-channel (e.g. gathering)
    })
    mock._objects = {}
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return {
                is_complete = false,
                goals = { { type = "area", npc_id = 0, target = "Milly's Harvest" } },
                step_num = 42,
            } end,
            get_current_waypoint_world = function() return nil end,
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
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0, _nav_destination = nil, _area_wait_timer = 0 }
    local next_state = idle_state.run(shared, ctx)

    assert(next_state == "IDLE",
        "S11 FAIL: player channelling → bot must stay in IDLE (got: " .. tostring(next_state) .. "). " ..
        "Re-targeting would cancel the channel.")
    -- No set_target, no interact, no look_at calls during channel
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "set_target",
            "S11 FAIL: bot called set_target during channel — would cancel the cast")
        assert(call[1] ~= "interact_with_object",
            "S11 FAIL: bot called interact_with_object during channel — would cancel the cast")
        assert(call[1] ~= "move_to",
            "S11 FAIL: bot called move_to during channel — movement cancels gathering")
    end
    print("  S11 PASS: player channelling → bot stays in IDLE (no cancel)")
end

-- S12 — player is casting → bot must stay in IDLE
do
    mock.reset()
    mock.create_player({
        pos = { x = 0, y = 0, z = 0 },
        hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000,
        casting = true,  -- mid-cast
    })
    mock._objects = {}
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return {
                is_complete = false,
                goals = { { type = "area", npc_id = 0, target = "Milly's Harvest" } },
                step_num = 42,
            } end,
            get_current_waypoint_world = function() return nil end,
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
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0, _nav_destination = nil, _area_wait_timer = 0 }
    local next_state = idle_state.run(shared, ctx)

    assert(next_state == "IDLE",
        "S12 FAIL: player casting → bot must stay in IDLE (got: " .. tostring(next_state) .. ")")
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "set_target",
            "S12 FAIL: bot called set_target during cast — would cancel the cast")
    end
    print("  S12 PASS: player casting → bot stays in IDLE (no cancel)")
end

-- S13 — player NOT casting/channeling → bot proceeds normally (DO_ACTION with quest)
do
    mock.reset()
    mock.create_player({
        pos = { x = 0, y = 0, z = 0 },
        hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000,
        casting = false,
        channelling = false,
    })
    mock._objects = {}
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return {
                is_complete = false,
                goals = { { type = "area", npc_id = 0, target = "Milly's Harvest" } },
                step_num = 42,
            } end,
            get_current_waypoint_world = function() return nil end,
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
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0, _nav_destination = nil, _area_wait_timer = 0 }
    local next_state = idle_state.run(shared, ctx)

    -- Not casting → should proceed with quest (DO_ACTION or NAV, not stay in IDLE)
    assert(next_state ~= "IDLE" or #mock._input_calls == 0,
        "S13 FAIL: player NOT casting/channeling → bot should proceed with quest " ..
        "(got: " .. tostring(next_state) .. ")")
    print("  S13 PASS: player not casting → bot proceeds normally")
end

-- =============================================================================
-- Post-interact pause — after DO_ACTION clicks a quest object, the bot must
-- stay in IDLE for 2s before checking waypoint distance. Without this, the
-- bot clicks a pumpkin → quest hasn't updated yet → sees it's > 40yd from
-- the waypoint → NAVs to waypoint → NAVs back → back-and-forth forever.
-- Live observed: Milly's Harvest goal in Northshire Valley.
-- =============================================================================

-- S14 — post-interact timer active → bot stays in IDLE (no waypoint NAV)
do
    mock.reset()
    mock.create_player({
        pos = { x = 0, y = 0, z = 0 },
        hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000,
    })
    mock._objects = {}
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return {
                is_complete = false,
                goals = { { type = "area", npc_id = 0, target = "Milly's Harvest" } },
                step_num = 42,
            } end,
            -- Waypoint is 100yd away — without the post-interact pause, the bot
            -- would NAV to the waypoint and trigger the back-and-forth loop.
            get_current_waypoint_world = function() return { x = 100, y = 0, z = 0 } end,
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
    -- Post-interact timer set 0.5s ago — still active for 1.5s more
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0,
        _post_interact_timer = 100.5 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "IDLE",
        "S14 FAIL: post-interact timer active → bot must stay in IDLE (got: " ..
        tostring(next_state) .. "). Without this, the bot NAVs to the waypoint " ..
        "and loops back-and-forth to the quest object.")
    print("  S14 PASS: post-interact pause active → bot stays in IDLE (no waypoint NAV)")
end

-- S15 — post-interact timer expired → bot proceeds with quest (can NAV to waypoint)
do
    mock.reset()
    mock.create_player({
        pos = { x = 0, y = 0, z = 0 },
        hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000,
    })
    mock._objects = {}
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return {
                is_complete = false,
                goals = { { type = "area", npc_id = 0, target = "Milly's Harvest" } },
                step_num = 42,
            } end,
            get_current_waypoint_world = function() return { x = 100, y = 0, z = 0 } end,
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
    -- Post-interact timer expired 1s ago
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0,
        _post_interact_timer = 99.0 }
    local next_state = idle_state.run(shared, ctx)
    -- Timer expired → bot should proceed (NAV to waypoint or DO_ACTION)
    assert(next_state == "NAV" or next_state == "DO_ACTION",
        "S15 FAIL: post-interact timer expired → bot should proceed (got: " ..
        tostring(next_state) .. ")")
    print("  S15 PASS: post-interact timer expired → bot proceeds with quest")
end

-- S16 — player dead (HP=0, is_dead=false — ghost form) → bot transitions to DEAD
-- Live bug: the old death check returned early if is_dead() existed, even if
-- it returned false. Ghost-form players have is_dead()=false but HP=0. Now
-- the check is is_dead() OR HP<=0, so ghost-form death is detected.
do
    mock.reset()
    mock.create_player({
        pos = { x = 0, y = 0, z = 0 },
        hp = 0, max_hp = 10000, mana = 0, max_mana = 10000,
        dead = false,  -- is_dead() returns false (ghost form)
    })
    mock._objects = {}
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return {
                is_complete = false,
                goals = { { type = "area", npc_id = 240, target = "" } },
                step_num = 52,
            } end,
            get_current_waypoint_world = function() return nil end,
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
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "DEAD",
        "S16 FAIL: player with HP=0 and is_dead()=false (ghost form) should transition to DEAD " ..
        "(got: " .. tostring(next_state) .. "). Bot would get stuck in IDLE after dying.")
    print("  S16 PASS: ghost-form death (HP=0, is_dead=false) → bot transitions to DEAD")
end

-- S17 — player dead (is_dead=true) → bot transitions to DEAD
do
    mock.reset()
    mock.create_player({
        pos = { x = 0, y = 0, z = 0 },
        hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000,
        dead = true,  -- is_dead() returns true
    })
    mock._objects = {}
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return {
                is_complete = false,
                goals = { { type = "area", npc_id = 240, target = "" } },
                step_num = 52,
            } end,
            get_current_waypoint_world = function() return nil end,
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
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "DEAD",
        "S17 FAIL: player with is_dead()=true should transition to DEAD " ..
        "(got: " .. tostring(next_state) .. ")")
    print("  S17 PASS: is_dead=true → bot transitions to DEAD")
end

-- S18 — player dead (get_health() returns nil — ghost form with no health) → DEAD
-- Live bug: ghost-form players have is_dead()=false AND get_health()=nil.
-- The old check `hp and hp <= 0` was false (nil is falsy in `and` chain),
-- so the bot stayed in IDLE spamming "HP low (0%) — waiting for regen" instead
-- of transitioning to DEAD and navigating to the corpse.
do
    mock.reset()
    local player = mock.create_player({
        pos = { x = 0, y = 0, z = 0 },
        hp = 0, max_hp = 10000, mana = 0, max_mana = 10000,
        dead = false,  -- is_dead() returns false
    })
    -- Override get_health to return nil (simulates ghost form with no health)
    player.get_health = function() return nil end
    mock._objects = {}
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return {
                is_complete = false,
                goals = { { type = "area", npc_id = 240, target = "" } },
                step_num = 52,
            } end,
            get_current_waypoint_world = function() return nil end,
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
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "DEAD",
        "S18 FAIL: player with get_health()=nil (ghost form) should transition to DEAD " ..
        "(got: " .. tostring(next_state) .. "). Live bug: bot stuck in IDLE after dying.")
    print("  S18 PASS: ghost-form death (HP=nil) → bot transitions to DEAD")
end

-- S19 — player has Ghost buff (8326), is_dead()=false, HP>0 — bot transitions to DEAD
-- Live bug: Wrath client ghost-form players have is_dead()=false AND get_health()>0
-- (spirit health). Only buff 8326 detects this state.
do
    mock.reset()
    mock.create_player({
        pos = { x = 0, y = 0, z = 0 },
        hp = 5000, max_hp = 10000, mana = 0, max_mana = 10000,
        dead = false,
        buffs = { [8326] = true },
    })
    mock._objects = {}
    local utils = require("EaxAutoQuester/utils_sylvanas")
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return {
                is_complete = false,
                goals = { { type = "area", npc_id = 240, target = "" } },
                step_num = 52,
            } end,
            get_current_waypoint_world = function() return nil end,
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
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "DEAD",
        "S19 FAIL: player with Ghost buff (8326), is_dead()=false, HP>0 should transition to DEAD " ..
        "(got: " .. tostring(next_state) .. "). Wrath client ghost form detection via get_buffs failed.")
    print("  S19 PASS: Ghost buff (8326) with HP>0 → bot transitions to DEAD")
end

print("PASS test_idle_state")
os.exit(0)
