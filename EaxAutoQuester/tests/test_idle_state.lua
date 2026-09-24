-- What: Unit tests for EaxAutoQuester/quest_state/idle_state.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify IDLE state transitions: WAITING, INTERACT, NAV, DO_ACTION, DEAD

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local idle_state = require("quest_state/idle_state")
local pull_safety = require("shared/pull_safety")

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
    local utils = require("utils_sylvanas")
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
        lootable = true,  -- can_be_looted(): a fresh kill, not a body already emptied
        guid = "corpse_15yd_quest",
    })
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000 })
    mock._objects = { corpse }
    local utils = require("utils_sylvanas")
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
        lootable = true,
        guid = "corpse_15yd_noquest",
    })
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000 })
    mock._objects = { corpse }
    local utils = require("utils_sylvanas")
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

-- S1c — a corpse that is NOT lootable (already emptied) is never approached or looted.
-- The live Stonevault Shaman loop: is_dead() stays true on a body the player has already
-- looted, and the scan recognised the corpse by that flag alone, so the bot walked back to
-- it and "looted" it every two minutes until the step changed. can_be_looted() is what
-- separates a fresh kill from a body already emptied.
do
    local emptied = mock.create_object({
        pos = { x = 15, y = 0, z = 0 },
        name = "Stonevault Shaman",
        unit = true,
        valid = true,
        dead = true,
        lootable = false,  -- already looted
        guid = "corpse_emptied",
    })
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000 })
    mock._objects = { emptied }
    local utils = require("utils_sylvanas")
    local ctx = {
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
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0, _nav_destination = nil, _area_wait_timer = 0 }
    local next_state = idle_state.run(shared, ctx)
    assert(shared._nav_destination == nil,
        "S1c FAIL: the bot navigated to a corpse that cannot be looted")
    assert(next_state ~= "NAV",
        "S1c FAIL: an already-looted corpse must not drive NAV (got: " .. tostring(next_state) .. ")")
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= "loot_object",
            "S1c FAIL: loot_object was called on an already-looted corpse")
    end
    print("  S1c PASS: already-looted corpse ignored → no NAV, no loot_object")
end

-- S2 — corpse 2yd away → bot loots immediately
do
    local corpse = mock.create_object({
        pos = { x = 2, y = 0, z = 0 },
        name = "Defias Thug Corpse",
        unit = true,
        valid = true,
        dead = true,
        lootable = true,
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
        lootable = true,
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
    local utils = require("utils_sylvanas")
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
    local utils = require("utils_sylvanas")
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
    local utils = require("utils_sylvanas")
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
    local utils = require("utils_sylvanas")
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
    local utils = require("utils_sylvanas")
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
    local utils = require("utils_sylvanas")
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
    local utils = require("utils_sylvanas")
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
    local utils = require("utils_sylvanas")
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
    local utils = require("utils_sylvanas")
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

-- =============================================================================
-- Phase 1 ports — objective-first scan, kill-goal hold, action-pause respect
-- (docs/phase1_port_list.md items 1-3). These behaviours moved from the deleted
-- monolith into this handler, so the contract is pinned here.
-- =============================================================================

-- Helper: IDLE context with a single goal and a minimal npc_manager stub.
local function build_goal_ctx(goal, objects, opts)
    opts = opts or {}
    mock.reset()
    mock.create_player({ pos = opts.me_pos or { x = 0, y = 0, z = 0 },
        hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000 })
    mock._objects = objects or {}
    local utils = require("utils_sylvanas")
    return {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function()
                return { is_complete = false, goals = { goal }, step_num = 7 }
            end,
            get_current_waypoint_world = function() return opts.waypoint end,
        },
        nav = { is_navigating = function() return false end, stop = function() end },
        utils = utils,
        me = mock._player,
        now = 100.0,
        debug_log = function() end,
        log = function() end,
        safe = function(v, fb) if v == nil then return fb end return v end,
        detect_open_frame = function() return false end,
        npc_manager = opts.npc_manager or {
            find_interactable_objects = function() return mock._objects end,
        },
        combat_helper = opts.combat_helper,
        object_scanner = { get_visible_objects = function() return mock._objects end },
    }
end

-- P1a — objective 30yd away with NO waypoint → bot NAVs to the objective itself
-- (not to the step waypoint, which does not exist in this scenario)
do
    local node = mock.create_object({ pos = { x = 30, y = 0, z = 0 }, name = "Milly's Harvest",
        unit = false, valid = true, guid = "obj_far" })
    local ctx = build_goal_ctx({ type = "area", npc_id = 0, target = "Milly's Harvest" }, { node })
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "NAV",
        "P1a FAIL: objective at 30yd should NAV to the objective (got " .. tostring(next_state) .. ")")
    assert(shared._nav_destination ~= nil and math.abs((shared._nav_destination.x or 0) - 30) < 1,
        "P1a FAIL: nav destination should be the objective position (30,0,0)")
    print("  P1a PASS: objective-first — distant objective → NAV to the object")
end

-- P1b — objective in range (3yd) → skip the waypoint check, go straight to DO_ACTION
-- Without this, the waypoint check NAVs to a waypoint the player is standing on and
-- the state machine spins IDLE→NAV→ARRIVED→IDLE.
do
    local node = mock.create_object({ pos = { x = 3, y = 0, z = 0 }, name = "Milly's Harvest",
        unit = false, valid = true, guid = "obj_near" })
    -- Waypoint 100yd away: the old code would NAV to it and loop back.
    local ctx = build_goal_ctx({ type = "area", npc_id = 0, target = "Milly's Harvest" },
        { node }, { waypoint = { x = 100, y = 0, z = 0 } })
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "DO_ACTION",
        "P1b FAIL: in-range objective must skip the waypoint check and act (got " ..
        tostring(next_state) .. ")")
    print("  P1b PASS: objective-first — in-range objective → DO_ACTION (no waypoint NAV)")
end

-- P1c/P1d — a priest's combat band must not make a friendly quest object look
-- ready for DO_ACTION. The real combat helper is used so the 28yd band is the
-- one that previously overrode the fixed 5yd interaction gate.
do
    local combat_helper = require("combat_helper_sylvanas")
    local far_node = mock.create_object({ pos = { x = 20, y = 0, z = 0 }, name = "Milly's Harvest",
        unit = false, valid = true, guid = "priest_friendly_far" })
    local ctx = build_goal_ctx({ type = "area", npc_id = 0, target = "Milly's Harvest" },
        { far_node })
    ctx.combat_helper = combat_helper
    mock._player._class = 5   -- PRIEST
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "NAV",
        "P1c FAIL: a friendly objective at 20yd must NAV for a priest (got " .. tostring(next_state) .. ")")
    assert(shared._nav_destination ~= nil and math.abs(shared._nav_destination.x - 20) < 0.01,
        "P1c FAIL: friendly objective NAV destination must be the object position")
    assert(shared._nav_engage_sq == 25,
        "P1c FAIL: a friendly objective must keep the fixed 5yd NAV stand-off")
    print("  P1c PASS: priest + friendly objective at 20yd → NAV with a 5yd stand-off")

    local near_node = mock.create_object({ pos = { x = 4, y = 0, z = 0 }, name = "Milly's Harvest",
        unit = false, valid = true, guid = "priest_friendly_near" })
    ctx = build_goal_ctx({ type = "area", npc_id = 0, target = "Milly's Harvest" },
        { near_node }, { waypoint = { x = 100, y = 0, z = 0 } })
    ctx.combat_helper = combat_helper
    mock._player._class = 5   -- PRIEST
    shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0 }
    next_state = idle_state.run(shared, ctx)
    assert(next_state == "DO_ACTION",
        "P1d FAIL: a friendly objective within 5yd must hand to DO_ACTION (got " ..
        tostring(next_state) .. ")")
    print("  P1d PASS: priest + friendly objective within 5yd → DO_ACTION")
end

-- P2 — kill goal with a valid current target → stay IDLE (let the rotation fight)
do
    local ctx = build_goal_ctx({ type = "kill", npc_id = 999, text = "Kill Something" }, {},
        { combat_helper = { is_current_target_valid = function() return true end } })
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "IDLE",
        "P2 FAIL: kill goal with a valid target must hold in IDLE (got " .. tostring(next_state) .. ")")
    print("  P2 PASS: kill goal + valid target → IDLE (no re-tag thrash)")
end

-- P3 — post-action pause still running → stay IDLE instead of re-entering DO_ACTION
do
    local ctx = build_goal_ctx({ type = "area", npc_id = 0, target = "Milly's Harvest" }, {})
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _action_pause_timer = 100.5 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "IDLE",
        "P3 FAIL: active action pause must gate DO_ACTION (got " .. tostring(next_state) .. ")")
    print("  P3 PASS: action pause active → IDLE")
end

-- =============================================================================
-- P4-P7 — objective-first must not confuse a corpse for the objective, and must stop
-- at the class's engagement distance. Live bug: a kill goal whose mobs were all dead
-- matched a CORPSE under the player's feet and reported "in range (0yd) - skip NAV"
-- forever, so the bot stood in the corpse pile instead of moving on. The same scan is
-- what walked a priest to melee range (5yd) before this.
-- =============================================================================
do
    local combat_helper = require("combat_helper_sylvanas")

    -- P4 — only a corpse matches the goal name → NOT the objective. The corpse sits ON the
    -- player and the class is ranged, so counting it would put the goal "in range (0yd)" and
    -- the bot would act on nothing (the live symptom); the waypoint must drive NAV instead.
    -- Autoloot is left on cooldown so the objective scan is what runs: otherwise IDLE loots
    -- the corpse first, which is correct behaviour but proves nothing about the scan.
    local corpse = mock.create_object({
        pos = { x = 0, y = 0, z = 0 }, name = "Stonevault Shaman",
        unit = true, valid = true, dead = true, attackable = true, enemy = true, guid = "corpse_1",
    })
    local wp = { x = 500, y = 0, z = 5 }
    local ctx = build_goal_ctx({ type = "kill", npc_id = 0, target = "Stonevault Shaman" }, { corpse },
        { waypoint = wp })
    ctx.combat_helper = combat_helper
    mock._player._class = 5   -- PRIEST: a 28yd engagement band makes the corpse "in range" if counted
    local shared = { _interact_cooldown = 0, _loot_cooldown = 200.0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _action_pause_timer = 0, _respawn_wait_until = 0 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "NAV",
        "P4 FAIL: a corpse must not satisfy a kill objective (got " .. tostring(next_state) .. ")")
    assert(shared._nav_destination ~= corpse:get_position(),
        "P4 FAIL: the bot navigated to the corpse as if it were the objective")
    assert(shared._nav_engage_sq == nil,
        "P4 FAIL: no live objective was found, so no engagement stand-off should be set")
    print("  P4 PASS: corpse ignored → waypoint NAV, not 'in range (0yd)'")

    -- P4b — the same goal with a LIVE mob on top of the player is genuinely in range: proves
    -- the scan still works, so P4's NAV really comes from skipping the corpse.
    local live_mob = mock.create_object({
        pos = { x = 0, y = 0, z = 0 }, name = "Stonevault Shaman",
        unit = true, valid = true, attackable = true, enemy = true, guid = "live_0",
    })
    ctx = build_goal_ctx({ type = "kill", npc_id = 0, target = "Stonevault Shaman" }, { live_mob },
        { waypoint = wp })
    ctx.combat_helper = combat_helper
    mock._player._class = 5
    shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _action_pause_timer = 0, _respawn_wait_until = 0 }
    next_state = idle_state.run(shared, ctx)
    assert(next_state == "DO_ACTION",
        "P4b FAIL: a live mob in range must be acted on (got " .. tostring(next_state) .. ")")
    print("  P4b PASS: live objective on top of the player → DO_ACTION (scan still finds it)")

    -- P5 — priest, live mob at 20yd: inside cast range → act, do not walk closer.
    local mob = mock.create_object({
        pos = { x = 20, y = 0, z = 5 }, name = "Stonevault Shaman",
        unit = true, valid = true, attackable = true, enemy = true, guid = "shaman_20",
    })
    ctx = build_goal_ctx({ type = "kill", npc_id = 0, target = "Stonevault Shaman" }, { mob },
        { waypoint = { x = 500, y = 0, z = 5 } })
    ctx.combat_helper = combat_helper
    mock._player._class = 5   -- PRIEST
    shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _action_pause_timer = 0, _respawn_wait_until = 0 }
    next_state = idle_state.run(shared, ctx)
    assert(next_state == "DO_ACTION",
        "P5 FAIL: a mob 20yd away is in a priest's 28yd range and must be engaged, not approached (got "
        .. tostring(next_state) .. ")")
    print("  P5 PASS: priest in cast range at 20yd → DO_ACTION")

    -- P6 — priest, live mob at 40yd: approach, but stop at the stand-off.
    local far_mob = mock.create_object({
        pos = { x = 40, y = 0, z = 5 }, name = "Stonevault Shaman",
        unit = true, valid = true, attackable = true, enemy = true, guid = "shaman_40",
    })
    ctx = build_goal_ctx({ type = "kill", npc_id = 0, target = "Stonevault Shaman" }, { far_mob },
        { waypoint = { x = 500, y = 0, z = 5 } })
    ctx.combat_helper = combat_helper
    mock._player._class = 5   -- PRIEST
    shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _action_pause_timer = 0, _respawn_wait_until = 0 }
    next_state = idle_state.run(shared, ctx)
    assert(next_state == "NAV",
        "P6 FAIL: a mob 40yd away is out of range and must be approached (got " .. tostring(next_state) .. ")")
    assert(shared._nav_destination == far_mob:get_position(),
        "P6 FAIL: NAV should head for the mob")
    assert(shared._nav_engage_sq == 784 and shared._nav_engage_dest == far_mob:get_position(),
        "P6 FAIL: the approach must carry a 28yd stand-off so it stops at cast range")
    print("  P6 PASS: priest out of range at 40yd → NAV with a 28yd stand-off")

    -- P7 — warrior, live mob at 20yd: melee class keeps closing to 3yd.
    local melee_mob = mock.create_object({
        pos = { x = 20, y = 0, z = 5 }, name = "Stonevault Shaman",
        unit = true, valid = true, attackable = true, enemy = true, guid = "shaman_melee",
    })
    ctx = build_goal_ctx({ type = "kill", npc_id = 0, target = "Stonevault Shaman" }, { melee_mob },
        { waypoint = { x = 500, y = 0, z = 5 } })
    ctx.combat_helper = combat_helper
    mock._player._class = 1   -- WARRIOR
    shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _action_pause_timer = 0, _respawn_wait_until = 0 }
    next_state = idle_state.run(shared, ctx)
    assert(next_state == "NAV",
        "P7 FAIL: a melee class must still close on a mob 20yd away (got " .. tostring(next_state) .. ")")
    assert(shared._nav_engage_sq == nil,
        "P7 FAIL: melee classes take no stand-off; the destination is the mob itself")
    print("  P7 PASS: melee class unchanged → closes to melee")

    -- P8 — the live Stonevault Shaman shape, and the goal table here is the one the client
    -- really sends: a named target and NO `type` field, so IDLE classifies it as "area" (the
    -- goal[34] the player's log showed). The player has killed (and looted) those mobs, Zygor's
    -- step has not advanced, and the bot is standing where the objective is — its waypoint is in
    -- range, so nothing drives NAV. A corpse underfoot with no living match means there is
    -- nothing here to kill or use, so the goal must stay out of DO_ACTION — that re-entry, once
    -- per tick, was the freeze — and wait for the mobs on the existing bounded respawn timer,
    -- which resumes the kill the moment an enemy appears.
    local underfoot = mock.create_object({
        pos = { x = 0, y = 0, z = 0 }, name = "Stonevault Shaman",
        unit = true, valid = true, dead = true, lootable = false,
        attackable = true, enemy = true, guid = "corpse_underfoot",
    })
    ctx = build_goal_ctx({ npc_id = 0, target = "Stonevault Shaman" }, { underfoot },
        { waypoint = { x = 5, y = 0, z = 0 } })
    ctx.combat_helper = combat_helper
    mock._player._class = 5   -- PRIEST
    shared = { _interact_cooldown = 0, _loot_cooldown = 200.0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _action_pause_timer = 0, _respawn_wait_until = 0, _debug = true }
    next_state = idle_state.run(shared, ctx)
    assert(next_state == "IDLE",
        "P8 FAIL: a goal whose targets are all corpses underfoot must not re-enter DO_ACTION " ..
        "(got " .. tostring(next_state) .. ")")
    assert(shared._respawn_wait_until > ctx.now,
        "P8 FAIL: the goal must wait for its mobs to respawn")
    assert(shared._nav_destination == nil,
        "P8 FAIL: nothing should be navigated to — the only match was a corpse")
    print("  P8 PASS: all targets dead underfoot → respawn wait, not a DO_ACTION loop")

    -- P8b — the same shape with a LIVE mob underfoot must still act, so P8's IDLE really comes
    -- from there being nothing alive rather than from the goal being skipped blindly.
    local respawned = mock.create_object({
        pos = { x = 0, y = 0, z = 0 }, name = "Stonevault Shaman",
        unit = true, valid = true, attackable = true, enemy = true, guid = "shaman_back",
    })
    ctx = build_goal_ctx({ npc_id = 0, target = "Stonevault Shaman" }, { underfoot, respawned },
        { waypoint = { x = 5, y = 0, z = 0 } })
    ctx.combat_helper = combat_helper
    mock._player._class = 5
    shared = { _interact_cooldown = 0, _loot_cooldown = 200.0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _action_pause_timer = 0, _respawn_wait_until = 0, _debug = true }
    next_state = idle_state.run(shared, ctx)
    assert(next_state == "DO_ACTION",
        "P8b FAIL: one live target among the corpses must be acted on (got " .. tostring(next_state) .. ")")
    print("  P8b PASS: a respawned target beside the corpse → DO_ACTION (gate is not blind)")
end

-- =============================================================================
-- P9 — pull safety hold: IDLE must not walk back into the group it just backed out of
-- =============================================================================

do
    pull_safety.reset()
    -- A live quest mob, and a caster whose bar is empty. The gate is consulted by DO_ACTION's
    -- engage sites; IDLE's job is to not undo it in between.
    local buzzard = mock.create_object({
        pos = { x = 20, y = 0, z = 0 }, name = "Buzzard",
        unit = true, valid = true, attackable = true, enemy = true, guid = "buzzard_1",
    })
    local ctx = build_goal_ctx({ type = "area", npc_id = 0, target = "Buzzard" }, { buzzard },
        { waypoint = { x = 40, y = 0, z = 0 } })
    local logs = {}
    ctx.debug_log = function(msg) logs[#logs + 1] = tostring(msg) end
    mock._player._mana = 0

    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _action_pause_timer = 0, _respawn_wait_until = 0 }

    assert(pull_safety.gate(ctx, shared, buzzard) == true,
        "P9a FAIL: an empty mana bar must refuse the pull before IDLE is even reached")
    -- The retreat is the gate's published intent; shared/nav_destination.lua applies it and
    -- nav_state is what consumes it (the gate writes no navigation field — see test_pull_safety R1).
    local dest = pull_safety.destination(ctx)
    assert(dest, "P9b FAIL: the refusal must produce somewhere to back off to")
    -- Stand where it was sent: that is what NAV did with the destination. The player has to be AT
    -- the point — writing a stand-in into the destination field is undone by the nav owner, which
    -- re-asserts the gate's claim every tick, and that re-assertion is the point of the change.
    mock._player._pos = { x = dest.x, y = dest.y, z = dest.z }

    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "IDLE",
        "P9c FAIL: with a live pull refused and the player already backed off, IDLE must park " ..
        "rather than navigate back in (got " .. tostring(next_state) .. ")")
    local said = false
    for _, m in ipairs(logs) do
        if m:find("pull safety hold") then said = true end
    end
    assert(said, "P9d FAIL: the hold should say why it is waiting (logs: " ..
        tostring(#logs) .. " lines)")
    print("  P9 PASS: IDLE parks on a pull-safety hold instead of re-approaching")

    -- P9e — control: release the hold and the same scene must not be parked by it.
    pull_safety.reset()
    assert(pull_safety.holding(ctx) == false, "P9e FAIL: the hold must be gone after a reset")
    logs = {}
    local control = idle_state.run(shared, ctx)
    for _, m in ipairs(logs) do
        assert(not tostring(m):find("pull safety hold"),
            "P9f FAIL: nothing may report a hold that is not live (control returned " ..
            tostring(control) .. ")")
    end
    -- P9g — a destination written AFTER the retreat must not win. This is the measured defect: the
    -- destination fields had four writers, so a walk onto the mob (live-unit link and all) could
    -- replace the back-off between the refusal and the tick that acts on it. IDLE now resolves the
    -- destination through its owner before deciding, so the retreat is what the walk follows.
    pull_safety.reset()
    mock._player._pos = { x = 0, y = 0, z = 0 }
    local shared2 = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _action_pause_timer = 0, _respawn_wait_until = 0 }
    assert(pull_safety.gate(ctx, shared2, buzzard) == true, "P9g FAIL: expected a refusal")
    local retreat = pull_safety.destination(ctx)
    assert(retreat, "P9h FAIL: the gate must publish the retreat it wants")
    local mob_dest = { x = 20, y = 0, z = 0 }
    shared2._nav_destination = mob_dest
    shared2._nav_unit_dest = buzzard
    shared2._nav_unit_dest_key = mob_dest

    local walked = idle_state.run(shared2, ctx)
    assert(walked == "NAV",
        "P9i FAIL: with a live hold IDLE must walk out (got " .. tostring(walked) .. ")")
    assert(shared2._nav_destination == retreat,
        "P9j FAIL: the retreat must win over a destination written after it (got x=" ..
        tostring(shared2._nav_destination and shared2._nav_destination.x) .. ", expected x=" ..
        tostring(retreat.x) .. ")")
    assert(shared2._nav_unit_dest == nil,
        "P9k FAIL: the live-unit link must be dropped, or nav_state would re-issue walks to the mob")
    print("  P9g PASS: a later destination writer does not replace the retreat while the hold is live")

    print("  P9e PASS: with no hold, IDLE's own logic is back in charge (got " ..
        tostring(control) .. ")")
end

-- P1c — the objective scan must not call a lookalike "my objective".
-- Live: on the guide's `kill Rock Elemental##92+` the bot stood at a Lesser Rock Elemental and
-- reported the objective as reached, because the name lookup matches substrings and "Lesser Rock
-- Elemental" contains "Rock Elemental". The lookalike is 2yd away and the goal's own mob is 40yd
-- away: the state must still hand the walk over.
do
    local lesser = mock.create_object({ pos = { x = 2, y = 0, z = 0 }, name = "Lesser Rock Elemental",
        npc_id = 2735, unit = true, valid = true, enemy = true, attackable = true, guid = "lesser_2735" })
    local rock = mock.create_object({ pos = { x = 40, y = 0, z = 0 }, name = "Rock Elemental",
        npc_id = 92, unit = true, valid = true, enemy = true, attackable = true, guid = "rock_92" })
    local goal = { type = "kill", target = "Rock Elementals", npc_id = 0, target_id = 92 }
    local ctx = build_goal_ctx(goal, { lesser, rock })
    -- A step number of its own: idle_state treats a step it has already seen differently, and this
    -- scenario is about the scan, not about step transitions.
    ctx.zygor.get_current_step_info = function()
        return { is_complete = false, goals = { goal }, step_num = 99 }
    end
    -- A hold armed by an earlier scenario outranks the scan (it is module state, and this suite
    -- runs everything in one process), so start from a clean gate.
    require("shared/pull_safety").reset()
    -- The scene itself: the goal's mob must be recognised by its id, or the rest of this scenario
    -- would be asserting nothing.
    local objective_match = require("shared/objective_match")
    assert(objective_match.is_objective(goal, rock),
        "P1c FAIL: scene error — the goal's own mob must be recognised as its objective")
    assert(not objective_match.is_objective(goal, lesser),
        "P1c FAIL: scene error — the lookalike must not be recognised as the objective")
    local _dbg = {}
    ctx.debug_log = function(m) _dbg[#_dbg + 1] = tostring(m) end
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _last_step_num = 98, _respawn_wait_until = 0 }
    local next_state = idle_state.run(shared, ctx)
    assert(next_state == "NAV",
        "P1c FAIL: a lookalike 2yd away must not count as the objective (got " ..
        tostring(next_state) .. ") — the goal's own mob is 40yd out")
    assert(shared._nav_destination ~= nil,
        "P1c FAIL: the state must have a destination for the goal's own mob")
    local dx = (shared._nav_destination.x or 0) - 40
    assert(math.abs(dx) < 1,
        "P1c FAIL: the destination must be the goal's own mob at 40yd, got " ..
        tostring(shared._nav_destination.x) .. "," .. tostring(shared._nav_destination.y) ..
        "," .. tostring(shared._nav_destination.z) .. " | logs: " .. table.concat(_dbg, " || "))
    print("  P1c PASS: the objective scan ignores a lookalike and navigates to the goal's own mob")
end

-- =============================================================================
-- P12/P13 — the movement-only sweep must not re-offer a waypoint the client could not
-- walk to. Live: the client reported "arrived" 13yd short of the step's waypoint, the
-- retry ladder gave up, IDLE offered the SAME coordinates one second later, and the bot
-- looped IDLE -> NAV -> "arrived callback but still 13yd away" for minutes without ever
-- covering the other waypoints of the step (or the goal the step was about).
-- =============================================================================
do
    local nav_destination = require("shared/nav_destination")
    -- A hold armed by an earlier scenario outranks the destination (module state, one process).
    require("shared/pull_safety").reset()

    local near_wp = { x = 30, y = 0, z = 5 }
    local far_wp = { x = 50, y = 0, z = 5 }

    -- A movement-only area goal (no target, no text, npc_id 0) with two step waypoints and
    -- nothing in the world: the branch that walks the guide's own path. Step number 7 matches
    -- build_goal_ctx, so the state does not treat this as a step transition and reset its marks.
    local function sweep_ctx()
        local ctx = build_goal_ctx({ type = "area", npc_id = 0 }, {})
        ctx.zygor.get_step_waypoints_world = function() return { near_wp, far_wp } end
        return ctx
    end
    local function fresh_shared()
        return { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
            _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
            _at_quest_object_timer = 0, _last_step_num = 7,
            _respawn_wait_until = 0, _action_pause_timer = 0 }
    end

    -- Control: with no memory of a failed walk, the nearest waypoint is the one offered.
    local plain = fresh_shared()
    local ctx = sweep_ctx()
    assert(idle_state.run(plain, ctx) == "NAV", "P12a FAIL: scene error — the sweep must walk")
    assert(plain._nav_destination == near_wp,
        "P12a FAIL: with nothing remembered, the nearest waypoint is offered")

    -- The same scene, with the nearest waypoint just reported unreachable: the sweep moves on to
    -- the next one instead of offering the same coordinates again.
    local skipped = fresh_shared()
    nav_destination.mark_unreachable(skipped, ctx.now, near_wp)
    local ctx_b = sweep_ctx()
    assert(idle_state.run(skipped, ctx_b) == "NAV",
        "P12b FAIL: the sweep must still walk — just not to the unreachable waypoint")
    assert(skipped._nav_destination == far_wp,
        "P12b FAIL: an unreachable waypoint must be skipped for the next one, got " ..
        tostring(skipped._nav_destination and skipped._nav_destination.x))
    assert(nav_destination.place_retired(skipped, near_wp),
        "P12b FAIL: the skip must be recorded against the place it was refused at, or the next " ..
        "tick re-offers the same waypoint")

    -- Standing still, the pin holds: the next tick does not reconsider it either.
    local ctx_c = sweep_ctx()
    assert(idle_state.run(skipped, ctx_c) == "NAV",
        "P12c FAIL: the sweep continues to the same next waypoint")
    assert(skipped._nav_destination == far_wp,
        "P12c FAIL: a recorded skip must survive into the next tick")

    -- Expiry, not a latch: once the memory's window passes, the waypoint is offered again.
    local expired = fresh_shared()
    nav_destination.mark_unreachable(expired, ctx.now, near_wp)
    local ctx_d = sweep_ctx()
    ctx_d.now = ctx.now + 61
    assert(idle_state.run(expired, ctx_d) == "NAV",
        "P12d FAIL: the memory is a window, not a latch — the waypoint must come back")
    assert(expired._nav_destination == near_wp,
        "P12d FAIL: after the window expires the nearest waypoint is offered again")
    print("  P12 PASS: an unreachable waypoint is skipped and the sweep moves on, until the window expires")
end

-- P13 — when every remaining waypoint is one the client just could not reach, the state waits
-- instead of bouncing. Falling through to DO_ACTION (or resetting the marks, which re-offers the
-- same waypoint) is the loop P12 exists to break, so the no-progress case has to be named.
do
    local nav_destination = require("shared/nav_destination")
    require("shared/pull_safety").reset()
    local only_wp = { x = 30, y = 0, z = 5 }

    local function single_wp_ctx()
        local ctx = build_goal_ctx({ type = "area", npc_id = 0 }, {})
        ctx.zygor.get_step_waypoints_world = function() return { only_wp } end
        return ctx
    end
    local function fresh_shared()
        return { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
            _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
            _at_quest_object_timer = 0, _last_step_num = 7,
            _respawn_wait_until = 0, _action_pause_timer = 0 }
    end

    -- Control: the only waypoint, no memory — it is walked.
    local plain = fresh_shared()
    local ctx = single_wp_ctx()
    assert(idle_state.run(plain, ctx) == "NAV",
        "P13a FAIL: scene error — a single walkable waypoint must be walked")

    -- The only waypoint is unreachable-recent: nothing to walk to and nothing to act on, so the
    -- state waits for the window to pass rather than acting or re-offering it.
    local held = fresh_shared()
    nav_destination.mark_unreachable(held, ctx.now, only_wp)
    local ctx_b = single_wp_ctx()
    local next_state = idle_state.run(held, ctx_b)
    assert(next_state == "WAITING",
        "P13b FAIL: with nothing reachable left the state must wait, not " .. tostring(next_state))
    assert(held._nav_destination == nil, "P13b FAIL: no destination may be offered for it")
    assert(nav_destination.place_retired(held, only_wp),
        "P13b FAIL: the skipped waypoint must stay retired, or the next tick re-offers it")

    -- The record is what the loop would consume: the following ticks make the same decision,
    -- unchanged. An alternating WAITING/DO_ACTION pair would pass here on every other tick, so
    -- this runs the decision more than once.
    for tick = 1, 3 do
        local ctx_c = single_wp_ctx()
        assert(idle_state.run(held, ctx_c) == "WAITING",
            "P13c FAIL: tick " .. tostring(tick) ..
            " of the no-progress case must be stable, not alternate with another state")
        assert(nav_destination.place_retired(held, only_wp),
            "P13c FAIL: tick " .. tostring(tick) .. " must keep the refused place retired")
    end

    -- P13d — the retry is BOUNDED, not never: once the cooldown has passed a new pass starts (the
    -- waypoint is offered again, which is what gives a transient refusal a second chance), and it is
    -- the cooldown that keeps that from happening every tick.
    local ctx_d = single_wp_ctx()
    ctx_d.now = ctx.now + 61
    local relaunched = idle_state.run(held, ctx_d)
    assert(relaunched == "DO_ACTION",
        "P13d FAIL: after the cooldown a new pass must start (got " .. tostring(relaunched) .. ")")
    assert(nav_destination.retired_count(held) == 0,
        "P13d FAIL: the new pass must clear the retirement so the waypoint gets its retry")
    local ctx_e = single_wp_ctx()
    ctx_e.now = ctx.now + 62
    local retried = idle_state.run(held, ctx_e)
    assert(retried == "NAV" and held._nav_destination == only_wp,
        "P13d FAIL: the new pass must walk the refused waypoint again — once per pass, not never " ..
        "(got " .. tostring(retried) .. ")")
    print("  P13 PASS: nothing reachable left → WAITING, marks kept (no re-offer, no DO_ACTION bounce)")
end

-- =============================================================================
-- P14/P15 — a pass over the step's waypoints must cover the path, then stop.
-- Live: "my character just moves between 2 waypoints instead of routing/patrolling all the
-- objective waypoints". Two rules produce that: a waypoint the client cannot walk to comes
-- back as soon as its 60s memory expires (so the pass keeps spending itself on the same
-- couple of points), and a completed pass re-issues the whole path on the very next tick
-- (so a step the guide has not finished yet becomes an endless march).
-- =============================================================================
do
    local nav_destination = require("shared/nav_destination")
    require("shared/pull_safety").reset()

    local w1 = { x = 20, y = 0, z = 5 }
    local w2 = { x = 60, y = 0, z = 5 }
    local w3 = { x = 100, y = 0, z = 5 }
    local wps = { w1, w2, w3 }

    local function index_of(p)
        if not p then return nil end
        for i = 1, #wps do
            if math.abs((p.x or 0) - wps[i].x) < 0.01 and math.abs((p.y or 0) - wps[i].y) < 0.01 then
                return i
            end
        end
        return nil
    end

    -- One scenario: a movement-only area goal whose step has the three waypoints above.
    local function sweep_scene()
        local ctx = build_goal_ctx({ type = "area", npc_id = 0 }, {})
        ctx.zygor.get_step_waypoints_world = function() return wps end
        local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
            _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
            _at_quest_object_timer = 0, _last_step_num = 7, _respawn_wait_until = 0,
            _action_pause_timer = 0 }
        return shared, ctx
    end

    -- One tick: hand the walk back as nav_state would on arrival, i.e. the player ends up on the
    -- destination it was given.
    local function tick(shared, ctx, now)
        ctx.now = now
        local state = idle_state.run(shared, ctx)
        local chosen = shared._nav_destination
        if chosen then
            ctx.me._pos = { x = chosen.x, y = chosen.y, z = chosen.z }
        end
        shared._nav_destination = nil
        shared._just_arrived = false
        return state, index_of(chosen)
    end

    -- Control: with nothing remembered, the nearest waypoint is walked first.
    local plain, ctx_plain = sweep_scene()
    local _, first_plain = tick(plain, ctx_plain, 100.0)
    assert(first_plain == 1, "P14a FAIL: scene error — the nearest waypoint must be walked first (got "
        .. tostring(first_plain) .. ")")

    -- The same scene where wp1 is a place the client could not reach. The pass skips it for the
    -- WHOLE pass — including after the 60s memory expires, which is the part that kept the bot
    -- circling — and spends itself on the waypoints it can cover.
    -- 45s between ticks, so the last ticks run PAST the 60s memory window: if the retirement did
    -- not exist, wp1 would come back into play exactly there and the pass would never finish.
    -- Reaching a waypoint costs a tick of its own (the arrival tick marks it covered), so the
    -- five ticks below are: walk wp2, wp2 reached, walk wp3, wp3 reached, pass over.
    local shared, ctx = sweep_scene()
    nav_destination.mark_unreachable(shared, 100.0, w1)
    local order, navs = {}, {}
    for i = 0, 4 do
        local state, idx = tick(shared, ctx, 100.0 + i * 45)
        order[#order + 1] = state .. ":" .. tostring(idx)
        if state == "NAV" then navs[#navs + 1] = idx end
    end
    assert(navs[1] == 2, "P14b FAIL: wp1 is unreachable — the pass must move to wp2 (got "
        .. tostring(order[1]) .. ")")
    assert(navs[2] == 3, "P14c FAIL: the pass must then cover wp3 (got " .. tostring(order[3]) .. ")")
    assert(#navs == 2, "P14d FAIL: wp1 was never retired — the pass walked " .. tostring(#navs)
        .. " waypoints, and the memory had expired before the last one")
    assert(nav_destination.place_retired(shared, w1),
        "P14e FAIL: the refusal must be remembered for the pass")
    assert(not nav_destination.place_retired(shared, w2),
        "P14e FAIL: only the refused place may be retired")
    -- The pass is over: the path has been covered and the guide is handed the tick rather than the
    -- path being re-walked (P15 pins the timing of the next pass).
    assert(order[5] == "DO_ACTION:nil", "P15a FAIL: a completed pass must hand over, not re-walk (got "
        .. tostring(order[5]) .. ")")

    -- P15b — no immediate re-lap: for the next stretch of ticks no walk is issued at all.
    local walks = 0
    for i = 1, 10 do
        local state, idx = tick(shared, ctx, 285.0 + i * 0.2)
        if state == "NAV" or idx ~= nil then walks = walks + 1 end
    end
    assert(walks == 0, "P15b FAIL: the covered path was re-issued " .. tostring(walks) .. " time(s)")

    -- P15c — and it does come back: after the cooldown a new pass starts (which is also the retry
    -- the refused waypoint gets — one per pass, not never).
    local relaunched = false
    for i = 1, 6 do
        local state, idx = tick(shared, ctx, 350.0 + i)
        if state == "NAV" and idx ~= nil then relaunched = true break end
    end
    assert(relaunched, "P15c FAIL: after the cooldown the pass must start again")
    assert(shared._sweep_lap_at == 0, "P15c FAIL: the new pass must clear the lap clock")
    assert(nav_destination.retired_count(shared) == 0,
        "P15c FAIL: the new pass must clear the retire marks so the refused waypoint is retried")

    -- P15d — a new STEP clears the retirement: the sweep starts from scratch on a step change.
    local shared2, ctx2 = sweep_scene()
    nav_destination.mark_unreachable(shared2, 100.0, w1)
    local s1, i1 = tick(shared2, ctx2, 100.0)
    assert(nav_destination.place_retired(shared2, w1),
        "P15d FAIL: scene error — wp1 must retire first")
    assert(s1 == "NAV" and i1 == 2, "P15d FAIL: scene error — the refused wp1 must be walked past")
    ctx2.zygor.get_current_step_info = function()
        return { is_complete = false, goals = { { type = "area", npc_id = 0 } }, step_num = 8 }
    end
    -- The step change happens after the 60s memory of the refusal has expired, so what is left to
    -- test is the retirement alone.
    tick(shared2, ctx2, 200.0)
    assert(nav_destination.retired_count(shared2) == 0,
        "P15d FAIL: a new step must clear the retired waypoints")
    local s3, i3 = tick(shared2, ctx2, 201.0)
    assert(s3 == "NAV" and i3 == 1,
        "P15d FAIL: on the new step the refused waypoint is offered again (got " .. tostring(s3)
        .. ":" .. tostring(i3) .. ")")
    print("  P14/P15 PASS: the pass retires what the client cannot reach, covers the rest, and re-pats only after the cooldown")
end

-- =============================================================================
-- P16 — the retirement is a PLACE, not a slot in whatever list the reader returned.
-- The reader rebuilds the step's waypoint list every tick and drops any waypoint it cannot convert,
-- and the guide's list itself changes as goals complete. A retirement keyed by INDEX would then skip
-- whichever waypoint now sits where the refused one used to — a walkable part of the path lost for
-- the rest of the step, which is the same "does not route all the objective waypoints" symptom.
-- =============================================================================
do
    local nav_destination = require("shared/nav_destination")
    require("shared/pull_safety").reset()

    local w1 = { x = 20, y = 0, z = 5 }   -- refused by the client
    local w2 = { x = 60, y = 0, z = 5 }
    local w3 = { x = 100, y = 0, z = 5 }
    -- A waypoint the list gains in front of the refused one: farther than the sweep's "reached"
    -- tolerance (so it is walked, not counted as arrived), nearer than the next good waypoint.
    local wX = { x = 30, y = 0, z = 5 }

    local list = nil
    local ctx = build_goal_ctx({ type = "area", npc_id = 0 }, {})
    ctx.zygor.get_step_waypoints_world = function() return list end
    local shared = { _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _nav_destination = nil, _area_wait_timer = 0, _post_interact_timer = 0,
        _at_quest_object_timer = 0, _last_step_num = 7, _respawn_wait_until = 0,
        _action_pause_timer = 0 }

    list = { w1, w2, w3 }
    ctx.now = 100.0
    nav_destination.mark_unreachable(shared, ctx.now, w1)
    assert(idle_state.run(shared, ctx) == "NAV" and shared._nav_destination == w2,
        "P16a FAIL: scene error — the pass must walk past the refused wp1")
    assert(nav_destination.place_retired(shared, w1), "P16a FAIL: scene error — wp1 must retire")

    -- The list changes under the sweep: a new waypoint is added in front, so index 1 — the slot the
    -- refusal was recorded against — now names a place the client never refused. The refused place
    -- is still refused, the new one is walkable. Nothing is reset between the ticks: this is the
    -- same pass, and the 60s memory has EXPIRED by now (the refusal was at t=100), so the only thing
    -- still holding the skip is the retirement. If it were keyed by the slot, index 1 would be
    -- skipped and the bot would walk back to the refused w1 — the live symptom.
    list = { wX, w1, w2, w3 }
    shared._nav_destination = nil
    ctx.now = 200.0
    local state = idle_state.run(shared, ctx)
    assert(state == "NAV" and shared._nav_destination == wX,
        "P16b FAIL: a walkable waypoint added to the step must be walked, not skipped for the slot "
        .. "the refused one used to occupy (got " .. tostring(state) .. " to "
        .. tostring(shared._nav_destination and shared._nav_destination.x))
    assert(not nav_destination.place_retired(shared, wX), "P16b FAIL: the new place was never refused")
    assert(nav_destination.place_retired(shared, w1), "P16b FAIL: the refused place stays retired")
    print("  P16 PASS: retirement follows the place — a shifting waypoint list cannot retire a walkable waypoint")
end

print("PASS test_idle_state")
os.exit(0)
