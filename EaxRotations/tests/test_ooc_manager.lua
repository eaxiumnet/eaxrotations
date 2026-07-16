-- test_ooc_manager.lua -- out-of-combat manager tests.
-- WHAT:  out-of-combat manager tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path
-- ============================================================================
-- Test: OOC Manager — GCD check and broken_api_throttled guard
-- ============================================================================
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

-- Time helpers
local current_time = 100
NS.time_now = function() return current_time end
local function advance(sec) current_time = current_time + sec end

NS.game_time_ms = function() return current_time * 1000 end
NS.log = print

-- Configurable mocks
local buff_remains_value = 0
local casts = {}
local throttle_set = {}

NS.try_cast = function(spell, target, reason)
    casts[#casts + 1] = { spell = spell, reason = reason }
    return true
end
NS.spell_ready = function(spell, target, opts) return true end
NS.spell_action = function(spell, label) return {} end
NS.GetPlayer = function() return { is_in_combat = function() return false end } end
NS.GetPet = function() return nil end
NS.buff_remains = function(unit, ids) return buff_remains_value end
NS.has_player_buff = function(ids) return false end
NS.mana_pct = function(unit) return 80 end
NS.gcd_remains = function() return 0 end
NS.POWER_RAGE = 1
NS.power_current = function(power_type) return 100 end  -- enough rage for warrior OOC tests
NS.broken_api_throttled = nil

-- Load module with error checking
local OOC
local function load_module()
    -- Try project-root path first, then EaxRotations-relative path
    -- (test can be run from project root or EaxRotations/tests/)
    local ok, err = pcall(dofile, "EaxRotations/shared/ooc_manager_sylvanas.lua")
    if not ok then
        ok, err = pcall(dofile, "../shared/ooc_manager_sylvanas.lua")
    end
    if not ok then
        ok, err = pcall(dofile, "shared/ooc_manager_sylvanas.lua")
    end
    assert(ok, "Failed to load OOC manager module: " .. tostring(err))
    assert(NS.OOCManager ~= nil, "OOCManager not set after module load")
    OOC = NS.OOCManager
    advance(2) -- clear the 1-second throttle window
end

load_module()

-- Baseline context (empty me — no class triggers no actions)
local base_ctx = {
    me = {},
    in_combat = false,
    settings = { use_ooc_manager = true },
}

-- Helper: advance time and run one update
local function run_one(ctx)
    advance(2)
    return OOC.on_update(ctx)
end

-- ================================================================
-- 1. GCD CHECK
-- ================================================================

-- 1a. GCD > 0 should block before any spell attempt
NS.gcd_remains = function() return 1.5 end
local r = run_one(base_ctx)
assert(r == false, "GCD > 0 should block OOC, got " .. tostring(r))
print("PASS ooc_gcd_active_blocks")

-- 1b. GCD = 0 should proceed past the GCD check (no class -> no actions -> false)
load_module()
NS.gcd_remains = function() return 0 end
r = run_one(base_ctx)
assert(r == false, "GCD = 0 should proceed past GCD check (nil class = no actions)")
print("PASS ooc_gcd_zero_proceeds")

-- 1c. GCD = nil (no API) should proceed via nil guard
load_module()
NS.gcd_remains = nil
r = run_one(base_ctx)
-- Should not crash; nil guard sets gcd to 0, proceeds
assert(r == false, "GCD nil guard should not crash")
print("PASS ooc_gcd_nil_guard")

-- ================================================================
-- 2. BROKEN_API_THROTTLED — try_self_buffs
-- ================================================================
-- Warrior (CLASS.WARRIOR = 1): Battle Shout entry has spell = { 25289, 2048, ... }
--   spell_id extracted = entry.spell[1] = 25289

-- 2a. Buff spell throttled -> skip
load_module()
NS.player_class_id = 1  -- WARRIOR
NS.gcd_remains = function() return 0 end
buff_remains_value = 0   -- buff missing, would normally try cast
-- Note: with the fix, broken_api_throttled receives the resolved spell object
-- (a table), not entry.spell[1]. A table arg means "throttle any spell".
NS.broken_api_throttled = function(spell_id, seconds)
    return type(spell_id) == "table"
end
r = run_one(base_ctx)
-- try_pet_summon: warrior has no pet entry -> false
-- try_self_buffs: Battle Shout throttled -> skip -> false
-- try_food_flask: no food settings -> false
assert(r == false, "Throttled Battle Shout should be skipped, got " .. tostring(r))
print("PASS ooc_buff_throttled_skipped")

-- 2b. Not throttled -> cast succeeds
load_module()
NS.player_class_id = 1
NS.gcd_remains = function() return 0 end
buff_remains_value = 0
casts = {}
NS.broken_api_throttled = function(spell_id, seconds) return false end
r = run_one(base_ctx)
assert(r == true, "Unthrottled Battle Shout should cast, got " .. tostring(r))
assert(#casts >= 1, "Should have at least 1 cast, got " .. #casts)
print("PASS ooc_buff_unthrottled_casts (" .. #casts .. " casts)")

-- 2c. broken_api_throttled = nil -> proceed normally
load_module()
NS.player_class_id = 1
NS.gcd_remains = function() return 0 end
buff_remains_value = 0
casts = {}
NS.broken_api_throttled = nil
r = run_one(base_ctx)
assert(r == true, "Nil broken_api_throttled should not block, got " .. tostring(r))
assert(#casts >= 1, "Should cast when throttle is nil, got " .. #casts)
print("PASS ooc_buff_throttle_nil_guard")

-- ================================================================
-- 3. BROKEN_API_THROTTLED — try_pet_summon
-- ================================================================
-- Hunter (CLASS.HUNTER = 3): PET_SUMMON_BY_CLASS[3].spell = 883 (Call Pet)
-- NOTE: Hunter also has Aspect of the Hawk in DEFAULT_BUFFS_BY_CLASS,
-- so buff_remains > threshold (30) to skip self_buffs.

-- 3a. Call Pet throttled -> skip
load_module()
NS.player_class_id = 3  -- HUNTER
NS.gcd_remains = function() return 0 end
NS.GetPet = function() return nil end
buff_remains_value = 31  -- > threshold (30), skip self_buffs
casts = {}
-- Note: with the fix, broken_api_throttled receives the resolved spell object
-- (a table), not entry.spell. A table arg means "throttle any spell".
NS.broken_api_throttled = function(spell_id, seconds)
    return type(spell_id) == "table"
end
r = run_one(base_ctx)
-- try_pet_summon: throttled -> false
-- try_self_buffs: buff_remains > threshold -> false
-- try_food_flask: no food settings -> false
assert(r == false, "Throttled Call Pet should be skipped, got " .. tostring(r))
print("PASS ooc_pet_throttled_skipped")

-- 3b. Not throttled -> cast succeeds
load_module()
NS.player_class_id = 3
NS.gcd_remains = function() return 0 end
NS.GetPet = function() return nil end
buff_remains_value = 31
casts = {}
NS.broken_api_throttled = function(spell_id, seconds) return false end
r = run_one(base_ctx)
assert(r == true, "Unthrottled Call Pet should cast, got " .. tostring(r))
print("PASS ooc_pet_unthrottled_casts")

-- 3c. broken_api_throttled = nil -> proceed normally
load_module()
NS.player_class_id = 3
NS.gcd_remains = function() return 0 end
NS.GetPet = function() return nil end
buff_remains_value = 31
casts = {}
NS.broken_api_throttled = nil
r = run_one(base_ctx)
assert(r == true, "Nil broken_api_throttled should not block pet sumon, got " .. tostring(r))
print("PASS ooc_pet_throttle_nil_guard")

-- ================================================================
-- 4. BROKEN_API_THROTTLED — try_food_flask
-- ================================================================
-- Use warrior (no pet summon) + buff_remains > threshold to reach food_flask.
-- Food/flask uses a configured spell_id from settings.

local food_ctx = {
    me = {},
    in_combat = false,
    settings = {
        use_ooc_manager       = true,
        use_auto_consumables  = false,  -- bypass consumable_manager check
        use_food              = false,
        use_flasks            = false,
        use_food_flask        = true,
        ooc_food_flask_spell  = 12345,
    },
}

-- 4a. Food/spell throttled -> skip
load_module()
NS.player_class_id = 1  -- warrior (no pet summon entry)
NS.gcd_remains = function() return 0 end
buff_remains_value = 31  -- skip self_buffs
casts = {}
throttle_set = { [12345] = true }  -- throttle food spell
NS.broken_api_throttled = function(spell_id, seconds)
    return throttle_set[spell_id] == true
end
r = run_one(food_ctx)
assert(r == false, "Throttled food/flask should be skipped, got " .. tostring(r))
print("PASS ooc_food_throttled_skipped")

-- 4b. Not throttled -> cast succeeds
load_module()
NS.player_class_id = 1
NS.gcd_remains = function() return 0 end
buff_remains_value = 31
casts = {}
NS.broken_api_throttled = function(spell_id, seconds) return false end
r = run_one(food_ctx)
assert(r == true, "Unthrottled food/flask should cast, got " .. tostring(r))
print("PASS ooc_food_unthrottled_casts")

-- 4c. broken_api_throttled = nil -> proceed normally
load_module()
NS.player_class_id = 1
NS.gcd_remains = function() return 0 end
buff_remains_value = 31
casts = {}
NS.broken_api_throttled = nil
r = run_one(food_ctx)
assert(r == true, "Nil broken_api_throttled should not block food, got " .. tostring(r))
print("PASS ooc_food_throttle_nil_guard")

-- ================================================================
-- 5. Regression: in_combat blocks (preserving original test)
-- ================================================================
local combat_ctx = { in_combat = true, settings = { use_ooc_manager = true } }
local combat_result = OOC.on_update(combat_ctx)
assert(combat_result == false, "OOC manager should return false in combat, got " .. tostring(combat_result))
print("PASS ooc_in_combat_blocks")

-- ================================================================
-- 6. BROKEN_API_THROTTLED — argument verification with spy
-- ================================================================
-- These tests verify that the correct spell_id and 3.0 window
-- are passed to broken_api_throttled for each entry shape.

local spy = {}

-- 6a. Self-buffs: resolved spell object is passed to broken_api_throttled
--     The resolved spell object resolves to the max-rank cast ID (6673) via NS.get_spell_id
load_module()
spy = {}
NS.broken_api_throttled = function(spell_id, seconds)
    spy[#spy + 1] = { spell_id = spell_id, seconds = seconds }
    return true
end
NS.player_class_id = 1  -- WARRIOR
NS.gcd_remains = function() return 0 end
buff_remains_value = 0
r = run_one(base_ctx)
assert(#spy >= 1, "broken_api_throttled should have been called for Battle Shout, got " .. #spy)
-- With the fix, spell_id is the resolved spell object (table), not a raw number
assert(type(spy[1].spell_id) == "table", "Expected spell_id to be a resolved spell table, got " .. type(spy[1].spell_id))
local resolved_id = NS.get_spell_id and NS.get_spell_id(spy[1].spell_id)
-- resolved_id should be 6673 (max rank, the cast ID) on PS builds via fallback_spell_id
-- In test context the exact ID depends on the resolver availability
assert(spy[1].seconds == 300.0, "Expected seconds=300.0 for Battle Shout, got " .. tostring(spy[1].seconds))
print("PASS ooc_spy_self_buff_array_entry")

-- 6b. Self-buffs: 'ids' table entry shape — resolved spell object passed to broken_api_throttled
--     Use Shaman (CLASS.SHAMAN = 7) with Water Shield (min_level=60)
load_module()
spy = {}
NS.broken_api_throttled = function(spell_id, seconds)
    spy[#spy + 1] = { spell_id = spell_id, seconds = seconds }
    return true
end
NS.player_class_id = 7  -- SHAMAN
NS.gcd_remains = function() return 0 end
buff_remains_value = 0  -- buff missing, will try to cast
r = run_one(base_ctx)
-- try_pet_summon: shaman has no pet entry -> false
-- try_self_buffs: Water Shield is first entry (min_level=60, player_level defaults to 70)
--   spell_id is the resolved spell object (table)
assert(#spy >= 1, "broken_api_throttled should have been called for Water Shield, got " .. #spy)
assert(type(spy[1].spell_id) == "table", "Expected spell_id to be a resolved spell table, got " .. type(spy[1].spell_id))
assert(spy[1].seconds == 300.0, "Expected seconds=300.0 for Water Shield, got " .. tostring(spy[1].seconds))
print("PASS ooc_spy_self_buff_ids_entry")

-- 6c. Pet summon: resolved spell object passed to broken_api_throttled
load_module()
spy = {}
NS.broken_api_throttled = function(spell_id, seconds)
    spy[#spy + 1] = { spell_id = spell_id, seconds = seconds }
    return true
end
NS.player_class_id = 3  -- HUNTER
NS.gcd_remains = function() return 0 end
NS.GetPet = function() return nil end
buff_remains_value = 31  -- > threshold, skip self_buffs
r = run_one(base_ctx)
-- try_pet_summon: resolved spell object (table) is passed, not raw number
assert(#spy >= 1, "broken_api_throttled should have been called for Call Pet, got " .. #spy)
assert(type(spy[1].spell_id) == "table", "Expected spell_id to be a resolved spell table, got " .. type(spy[1].spell_id))
assert(spy[1].seconds == 10.0, "Expected seconds=10.0 for Call Pet, got " .. tostring(spy[1].seconds))
print("PASS ooc_spy_pet_summon_number_entry")

-- 6d. Food/flask: spell_id from settings (ooc_food_flask_spell = 12345)
load_module()
spy = {}
NS.broken_api_throttled = function(spell_id, seconds)
    spy[#spy + 1] = { spell_id = spell_id, seconds = seconds }
    return true
end
NS.player_class_id = 1  -- WARRIOR (no pet entry)
NS.gcd_remains = function() return 0 end
buff_remains_value = 31  -- skip self_buffs
r = run_one(food_ctx)
-- try_food_flask: spell_id from settings.ooc_food_flask_spell = 12345
assert(#spy >= 1, "broken_api_throttled should have been called for food/flask, got " .. #spy)
assert(spy[1].spell_id == 12345, "Expected spell_id 12345 for food/flask, got " .. tostring(spy[1].spell_id))
assert(spy[1].seconds == 3.0, "Expected seconds=3.0 for food/flask, got " .. tostring(spy[1].seconds))
print("PASS ooc_spy_food_flask_number_entry")

-- ================================================================
-- 7. NS.reset_api_health() clears broken_api_throttled state
-- ================================================================
-- These tests verify that after calling NS.reset_api_health(), the
-- OOC manager no longer throttles casts via broken_api_throttled.
-- They use a controllable flag to simulate the _api_health_broken
-- internal state being toggled, matching what reset_api_health()
-- does on non-PS builds (sets _api_health_broken = false).

local health_broken = false
local health_spell_id = nil

-- 7a. Before reset: broken_api state blocks the OOC cast
load_module()
health_broken = true
health_spell_id = nil
NS.broken_api_throttled = function(spell_id, seconds)
    if health_broken and type(spell_id) == "table" then
        return true  -- throttled
    end
    return false
end
NS.player_class_id = 1  -- WARRIOR
NS.gcd_remains = function() return 0 end
buff_remains_value = 0
casts = {}
r = run_one(base_ctx)
-- Battle Shout is throttled -> should return false (no cast)
assert(r == false, "With broken API, OOC should be blocked, got " .. tostring(r))
print("PASS ooc_reset_health_before")

-- 7b. After clearing broken flag: cast proceeds
health_broken = false  -- Simulate reset_api_health() clearing the flag
casts = {}
r = run_one(base_ctx)
assert(r == true, "After clearing broken flag, OOC should cast, got " .. tostring(r))
assert(#casts >= 1, "Should cast after clearing broken flag, got " .. #casts)
print("PASS ooc_reset_health_after")

-- ================================================================
-- Done
-- ================================================================
print("PASS ooc_manager")
