-- What: Unit tests for EaxAutoQuester/goal_resolver_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify goal resolution chain: Zygor passthrough → NPC DB → Inventory → Questie → Unresolved
-- Scenarios: S1 npc_id passthrough, S2 NPC DB name match, S3 inventory search, S4 Questie fallback, S5 cache

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- =============================================================================
-- Mutable mock state — closures capture these so scenarios can change behavior
-- without requiring mock.reset()
-- =============================================================================

local _mock_npc_db_search = function(name)
    local db = {
        ["Milly Osworth"] = {
            { npc_id = 523, name = "Milly Osworth", map_id = 0, x = -8940.5, y = -140.3, z = 82.1 },
        },
    }
    return db[name] or {}
end

local _mock_questie_log = {}
local _mock_questie_locs = {}

-- Register mocks BEFORE loading goal_resolver so load-time caching works

-- NPC DB: register in global (goal_resolver's ensure_npc_db reads from here)
_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.npc_db = {
    search_npc_by_name = function(self, name)
        return _mock_npc_db_search(name)
    end,
}

-- Questie: add extra functions to the mock's questie table
core.addons.questie.get_quest_log_title = function(idx)
    local entry = _mock_questie_log[idx]
    if entry then return entry.title, entry.id end
    return nil
end
core.addons.questie.get_quest_locations = function(quest_id)
    return _mock_questie_locs[quest_id] or {}
end

-- Load module under test (load-time caching will capture our mock references)
local goal_resolver = require("EaxAutoQuester/goal_resolver_sylvanas")

-- =============================================================================
-- S1 — goal.npc_id = 999 → passthrough with source='zyg'
-- =============================================================================

do
    local result = goal_resolver.resolve_goal(
        { npc_id = 999, text = "Talk to Magistrate Solomon" },
        1, nil, nil
    )
    assert(result.source == "zyg",
        "S1 FAIL: source should be 'zyg' (got: " .. tostring(result.source) .. ")")
    assert(result.npc_id == 999,
        "S1 FAIL: npc_id should be 999 (got: " .. tostring(result.npc_id) .. ")")
    print("  S1 PASS: npc_id=999 → source=zyg, npc_id=999")
end

-- =============================================================================
-- S2 — goal.npc_id = 0, goal.text = "Talk to Milly Osworth" → NPC DB lookup
-- =============================================================================

do
    _mock_npc_db_search = function(name)
        local db = {
            ["Milly Osworth"] = {
                { npc_id = 523, name = "Milly Osworth", map_id = 0, x = -8940.5, y = -140.3, z = 82.1 },
            },
        }
        return db[name] or {}
    end

    local result = goal_resolver.resolve_goal(
        { npc_id = 0, text = "Milly Osworth" },
        1, nil, nil
    )
    assert(result.source == "npc_db",
        "S2 FAIL: source should be 'npc_db' (got: " .. tostring(result.source) .. ")")
    assert(result.npc_id == 523,
        "S2 FAIL: npc_id should be 523 (got: " .. tostring(result.npc_id) .. ")")
    assert(result.name == "Milly Osworth",
        "S2 FAIL: name should be 'Milly Osworth' (got: " .. tostring(result.name) .. ")")
    assert(result.position ~= nil,
        "S2 FAIL: position should not be nil")
    print("  S2 PASS: text='Milly Osworth' → source=npc_db, npc_id=523")
end

-- =============================================================================
-- S3 — goal.npc_id = 0, goal.text = "Use the Red Bracers" → Inventory search
-- =============================================================================

do
    -- Disable NPC DB resolution for this scenario
    _mock_npc_db_search = function(name) return {} end
    -- Disable Questie resolution
    _mock_questie_log = {}

    mock._bag_items = {}
    mock._bag_items[0] = {
        { name = "Something Else", id = 111 },
    }
    mock._bag_items[4] = {
        { name = "Red Bracers", id = 12345 },
    }

    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local result = goal_resolver.resolve_goal(
        { npc_id = 0, text = "Use the Red Bracers" },
        1, player, nil
    )
    assert(result.source == "inventory",
        "S3 FAIL: source should be 'inventory' (got: " .. tostring(result.source) .. ")")
    assert(result.item_id == 12345,
        "S3 FAIL: item_id should be 12345 (got: " .. tostring(result.item_id) .. ")")
    assert(result.name == "Red Bracers",
        "S3 FAIL: name should be 'Red Bracers' (got: " .. tostring(result.name) .. ")")
    print("  S3 PASS: text='Red Bracers' → source=inventory, item_id=12345")
end

-- =============================================================================
-- S4 — goal.npc_id = 0, text = "Find the Gilded Brass Armor" → Questie
-- =============================================================================

do
    _mock_npc_db_search = function(name) return {} end
    _mock_questie_log = {}
    _mock_questie_locs = {}

    -- Set up Questie to return a matching quest
    _mock_questie_log[1] = { title = "Gilded Brass Armor", id = 100 }
    _mock_questie_locs[100] = { { x = 100.5, y = 200.3, z = 30.1 } }

    local result = goal_resolver.resolve_goal(
        { npc_id = 0, text = "Gilded Brass Armor" },
        1, nil, nil
    )
    assert(result.source == "questie",
        "S4 FAIL: source should be 'questie' (got: " .. tostring(result.source) .. ")")
    assert(result.position ~= nil,
        "S4 FAIL: position should not be nil")
    assert(result.position.x == 100.5,
        "S4 FAIL: position.x should be 100.5 (got: " .. tostring(result.position.x) .. ")")
    assert(result.name == "Gilded Brass Armor" or result.name:find("Gilded"),
        "S4 FAIL: name should contain 'Gilded' (got: " .. tostring(result.name) .. ")")
    print("  S4 PASS: text='Gilded Brass Armor' → source=questie, position=(100.5,200.3,30.1)")
end

-- =============================================================================
-- S5 — Cache: same step_num → cache hit (within 60s); step_num change → miss
-- =============================================================================

do
    _mock_npc_db_search = function(name) return {} end
    _mock_questie_log = {}

    mock.set_time(100.0)

    -- Call 1: step_num=1, npc_id=999 → resolves to source='zyg'
    local r1 = goal_resolver.resolve_goal(
        { npc_id = 999, text = "Talk to Magistrate Solomon" },
        1, nil, nil
    )
    assert(r1.source == "zyg",
        "S5 FAIL: call 1 should resolve to source='zyg' (got: " .. tostring(r1.source) .. ")")

    -- Call 2: same step_num=1, npc_id=0 (won't resolve without cache), 30s later
    mock.set_time(130.0)
    local r2 = goal_resolver.resolve_goal(
        { npc_id = 0, text = "Talk to Magistrate Solomon" },
        1, nil, nil
    )
    -- Cache hit: should return the cached result with source='zyg', not re-resolve
    assert(r2.source == "zyg",
        "S5 FAIL: call 2 should be cache hit → source='zyg' (got: " .. tostring(r2.source) .. ")")
    assert(r2.npc_id == 999,
        "S5 FAIL: call 2 cached result should have npc_id=999 (got: " .. tostring(r2.npc_id) .. ")")

    -- Call 3: step_num=2, new step → cache expired, npc_id=0 → 'unresolved'
    mock.set_time(135.0)
    local r3 = goal_resolver.resolve_goal(
        { npc_id = 0, text = "Talk to Magistrate Solomon" },
        2, nil, nil
    )
    assert(r3.source == "unresolved",
        "S5 FAIL: call 3 step_num changed → cache miss, should be 'unresolved' (got: " .. tostring(r3.source) .. ")")

    -- Call 4: same step_num=2, npc_id=0 → should cache the 'unresolved' result
    mock.set_time(150.0)
    local r4 = goal_resolver.resolve_goal(
        { npc_id = 0, text = "Talk to Magistrate Solomon" },
        2, nil, nil
    )
    assert(r4.source == "unresolved",
        "S5 FAIL: call 4 should be cached 'unresolved' (got: " .. tostring(r4.source) .. ")")

    print("  S5 PASS: cache hit within 60s same step, miss on step_num change, re-cache works")
end

print("PASS test_goal_resolver")
os.exit(0)
