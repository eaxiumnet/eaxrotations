-- test_boss_count.lua -- boss logic boss counting tests.
-- WHAT:  boss logic boss counting tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Unit tests for M.is_boss_fight() in targeting_sylvanas.lua
--
-- Exercises: core.object_manager.get_boss_count() (primary path)
--            core.object_manager.get_boss_frames() (fallback path)
--            Nil-guard when both APIs unavailable
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Helper: reset module cache and load targeting with mocked core API
local function load_targeting(mock_core)
    package.loaded["shared/targeting_sylvanas"] = nil
    package.preload["shared/targeting_sylvanas"] = nil

    _G.core = mock_core

    _G.EaxRotations = {
        GetPlayer = function() return nil end,
        Targeting = {},
    }

    local ok, mod = pcall(require, "shared/targeting_sylvanas")
    if not ok or type(mod) ~= "table" then
        error("failed to load targeting_sylvanas: " .. tostring(mod))
    end
    return mod
end

-- ============================================================================
-- Scenario A: get_boss_count returns 2 → is_boss_fight is true
-- (Happy path: count API available, 2 active boss frames)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {
            get_boss_count = function() return 2 end,
        }
    })
    assert_true(targeting.is_boss_fight(),
        "S-A: is_boss_fight should be true when get_boss_count()=2")
end

-- ============================================================================
-- Scenario B: get_boss_count returns 0 → is_boss_fight is false
-- (Edge: no boss frames active)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {
            get_boss_count = function() return 0 end,
        }
    })
    assert_false(targeting.is_boss_fight(),
        "S-B: is_boss_fight should be false when get_boss_count()=0")
end

-- ============================================================================
-- Scenario C: get_boss_count is nil → falls back to get_boss_frames
-- (Backward compatibility: API unavailable, uses frame iteration)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {
            get_boss_frames = function() return { { name = "Gruul" } } end,
        }
    })
    assert_true(targeting.is_boss_fight(),
        "S-C: is_boss_fight should fall back to frames when count API nil (1 boss frame)")
end

-- ============================================================================
-- Scenario D: Both APIs unavailable → is_boss_fight is false
-- (Edge: no boss detection possible, safe nil path)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {}
    })
    assert_false(targeting.is_boss_fight(),
        "S-D: is_boss_fight should be false when both APIs unavailable")
end

-- ============================================================================
-- Scenario E: get_boss_count nil, get_boss_frames returns empty → false
-- (Edge: fallback path with no bosses)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {
            get_boss_frames = function() return {} end,
        }
    })
    assert_false(targeting.is_boss_fight(),
        "S-E: is_boss_fight should be false when fallback frames is empty")
end

-- ============================================================================
-- Scenario F: get_boss_count returns 1 → is_boss_fight is true (boundary)
-- (Boundary: single boss frame = still a boss fight)
-- ============================================================================
do
    local targeting = load_targeting({
        object_manager = {
            get_boss_count = function() return 1 end,
        }
    })
    assert_true(targeting.is_boss_fight(),
        "S-F: is_boss_fight should be true when get_boss_count()=1")
end

-- ============================================================================
-- Targeting layer (2026-09-13): smart auto-targeting, the seven priority
-- override slots and the party_combat pull mode. Same harness shape as above
-- (fresh module load against a mocked namespace) so every assertion drives the
-- real shared/targeting_sylvanas.lua.
-- ============================================================================

local function mock_unit(name, opts)
    opts = opts or {}
    return {
        _name = name,
        is_valid = function() return opts.valid ~= false end,
        is_alive = function() return opts.alive ~= false end,
        get_name = function(self) return self._name end,
        can_attack = function() return opts.attack ~= false end,
        get_distance = function() return opts.dist or 5 end,
        is_in_combat = function() return opts.combat == true end,
        get_target = function() return opts.target end,
        get_guid = function() return "guid-" .. name end,
    }
end

local function load_targeting_ext(opts)
    package.loaded["shared/targeting_sylvanas"] = nil
    package.preload["shared/targeting_sylvanas"] = nil
    opts = opts or {}
    local clock = 1000
    local set_target_calls = {}
    _G.core = {
        time = function() return clock end,
        input = {
            set_target = function(u) set_target_calls[#set_target_calls + 1] = u end,
        },
    }
    -- Declared before the table so the accessor closures capture THIS local.
    local ns = {}
    ns.settings_store = opts.settings or {}
    ns.get_setting = function(key, default)
        local v = ns.settings_store[key]
        if v == nil then return default end
        return v
    end
    ns.set_setting = function(key, value) ns.settings_store[key] = value end
    ns.GetPlayer = function() return opts.me end
    ns.GetPartyMembers = function() return opts.party or {} end
    ns.GetEnemiesInRange = function() return opts.enemies or {} end
    ns.Targeting = {}
    _G.EaxRotations = ns
    local ok, mod = pcall(require, "shared/targeting_sylvanas")
    if not ok or type(mod) ~= "table" then
        error("failed to load targeting_sylvanas: " .. tostring(mod))
    end
    return mod, ns, set_target_calls, clock
end

-- G: party_combat pull mode
do
    local me = mock_unit("Me", { combat = false })
    local ally = mock_unit("Ally", { combat = true })
    local mid = mock_unit("Mid", { combat = false })
    local mod = load_targeting_ext({ me = me, party = { me, ally } })
    assert_true(mod.should_engage("party_combat", { me = me, in_combat = false }),
        "G-1: party_combat engages when a party member is already fighting")
    mod = load_targeting_ext({ me = me, party = { me, mid } })
    assert_false(mod.should_engage("party_combat", { me = me, in_combat = false }),
        "G-2: party_combat holds when nobody in the group has pulled")
    assert_true(mod.should_engage("party_combat", { me = me, in_combat = true }),
        "G-3: party_combat still engages on our own pull")
    assert_true(mod.should_engage("combat_only", { me = me, in_combat = true }),
        "G-4: combat_only unchanged when we are in combat")
end

-- H: seven override slots (priority order, stale pins skipped)
do
    local me = mock_unit("Me")
    local enemies = { mock_unit("Add"), mock_unit("Boss") }
    local settings = { eax_override_target_1 = "Boss", eax_override_target_2 = "Add" }
    local mod = load_targeting_ext({ me = me, enemies = enemies, settings = settings })
    assert_eq(mod.OVERRIDE_SLOTS, 7, "H-1: seven override slots are exposed")
    assert_eq(mod.override_slot_name(1), "Boss", "H-2: slot 1 reads its pinned name")
    assert_eq(mod.override_slot_name(8), nil, "H-3: slot 8 is out of range")
    assert_true(mod.has_override(), "H-4: has_override sees the pins")
    assert_true(mod.override_target({ me = me }) == enemies[2],
        "H-5: slot 1 (Boss) outranks slot 2 (Add)")
    settings.eax_override_target_1 = "Gone"
    mod.reset_override_cache()
    assert_true(mod.override_target({ me = me }) == enemies[1],
        "H-6: a pin that is not present falls through to the next slot")
    settings.eax_override_target_1 = nil
    settings.eax_override_target_2 = nil
    mod.reset_override_cache()
    assert_eq(mod.override_target({ me = me }), nil, "H-7: no pins resolves to nil")
    assert_false(mod.has_override(), "H-8: has_override is false with no pins")
end

-- I: smart auto-targeting gates
do
    local me = mock_unit("Me")
    local enemies = { mock_unit("Near", { dist = 8 }), mock_unit("Far", { dist = 25 }) }
    local mod, ns, set_target_calls = load_targeting_ext({ me = me, enemies = enemies })
    assert_eq(mod.auto_target_mode(), "off", "I-1: auto-target defaults to off")
    assert_eq(mod.pull_mode(), "combat_only", "I-2: pull mode defaults to combat_only")
    mod.reset_auto_target_state()
    assert_false(mod.update({ me = me, in_combat = true }), "I-3: off never selects")
    assert_eq(#set_target_calls, 0, "I-4: off never calls set_target")

    ns.settings_store.eax_auto_target = "assist"
    mod.reset_auto_target_state()
    assert_false(mod.update({ me = me, in_combat = false }), "I-5: assist holds out of combat")
    assert_eq(#set_target_calls, 0, "I-6: assist never starts a fight")

    ns.settings_store.eax_auto_target = "assist"
    mod.reset_auto_target_state()
    assert_true(mod.update({ me = me, in_combat = true }), "I-7: assist selects in combat")
    assert_true(set_target_calls[#set_target_calls] == enemies[1],
        "I-8: assist picks the nearest enemy")

    ns.settings_store.eax_auto_target = "auto"
    ns.settings_store.eax_pull_mode = "combat_only"
    mod.reset_auto_target_state()
    local before = #set_target_calls
    assert_false(mod.update({ me = me, in_combat = false }), "I-9: auto + combat_only holds OOC")
    assert_eq(#set_target_calls, before, "I-10: no surprise pull for a combat_only player")

    ns.settings_store.eax_pull_mode = "party_combat"
    local ally = mock_unit("Ally", { combat = true })
    ns.GetPartyMembers = function() return { me, ally } end
    mod.reset_auto_target_state()
    assert_true(mod.update({ me = me, in_combat = false }), "I-11: auto + party_combat selects OOC")

    ns.settings_store.eax_auto_target = "assist"
    ns.settings_store.eax_pull_mode = "combat_only"
    mod.reset_auto_target_state()
    before = #set_target_calls
    assert_false(mod.update({ me = me, in_combat = true, is_casting = true }),
        "I-12: never selects mid-cast")
    assert_eq(#set_target_calls, before, "I-13: the cast path is untouched")
end

print("PASS test_boss_count")
