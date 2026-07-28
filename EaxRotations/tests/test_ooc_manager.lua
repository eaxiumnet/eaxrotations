-- test_ooc_manager.lua -- out-of-combat manager tests.
-- WHAT:  out-of-combat manager tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path
-- ============================================================================
-- Test: OOC Manager — GCD check, pure API gates, and min_interval lockout
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
local has_food_buff = false
local casts = {}
local last_cast_time = {}

-- Mock try_cast that respects opts.min_interval, expected_cooldown, skip_range.
NS.try_cast = function(spell, target, reason, opts)
    local now = current_time
    local min_interval = opts and opts.min_interval or 0
    -- Respect min_interval based on the spell object identity.
    if min_interval and min_interval > 0 then
        local last = last_cast_time[spell]
        if last and (now - last) < min_interval then
            return false
        end
    end
    casts[#casts + 1] = { spell = spell, target = target, reason = reason, opts = opts }
    last_cast_time[spell] = now
    return true
end
NS.spell_ready = function(spell, target, opts) return true end
NS.spell_action = function(spell, label) return {} end
NS.GetPlayer = function() return { is_in_combat = function() return false end } end
NS.GetPet = function() return nil end
NS.buff_remains = function(unit, ids) return buff_remains_value end
NS.has_player_buff = function(ids) return has_food_buff end
NS.mana_pct = function(unit) return 80 end
NS.gcd_remains = function() return 0 end
NS.POWER_RAGE = 1
NS.power_current = function(power_type) return 100 end  -- enough rage for warrior OOC tests
NS.buff_would_downgrade = nil
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

-- Helper: reset per-test cast tracking (cast history remains for min_interval tests)
local function reset_casts()
    casts = {}
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
-- 2. SELF-BUFFS — pure aura gate and min_interval
-- ================================================================
-- Warrior (CLASS.WARRIOR = 1): Battle Shout entry

-- 2a. Buff missing -> cast with min_interval = 300
load_module()
reset_casts()
last_cast_time = {}
NS.player_class_id = 1  -- WARRIOR
NS.gcd_remains = function() return 0 end
buff_remains_value = 0   -- buff missing, would normally try cast
has_food_buff = false
r = run_one(base_ctx)
assert(r == true, "Battle Shout should cast when buff missing, got " .. tostring(r))
assert(#casts >= 1, "Should have at least 1 cast, got " .. #casts)
assert(casts[1].opts and casts[1].opts.min_interval == 300.0,
    "Expected self-buff min_interval=300.0, got " .. tostring(casts[1].opts and casts[1].opts.min_interval))
print("PASS ooc_self_buff_casts_with_min_interval")

-- 2b. Second attempt within 300s is suppressed by min_interval
-- (Do not clear last_cast_time; the previous cast should still be in history.)
r = run_one(base_ctx)
assert(r == false, "Second Battle Shout within min_interval should be suppressed, got " .. tostring(r))
assert(#casts == 1, "No second cast should happen while min_interval active, got " .. #casts)
print("PASS ooc_self_buff_min_interval_suppresses")

-- 2c. Buff already active -> no cast
load_module()
reset_casts()
last_cast_time = {}
NS.player_class_id = 1
NS.gcd_remains = function() return 0 end
buff_remains_value = 60  -- above threshold? threshold is 30; active -> skip
r = run_one(base_ctx)
assert(r == false, "Battle Shout should skip when buff active, got " .. tostring(r))
assert(#casts == 0, "No cast when buff active")
print("PASS ooc_self_buff_active_skips")

-- ================================================================
-- 3. PET SUMMON — pure pet-existence gate and min_interval
-- ================================================================
-- Hunter (CLASS.HUNTER = 3): PET_SUMMON_BY_CLASS[3].spell = 883 (Call Pet)
-- NOTE: Hunter also has Aspect of the Hawk in DEFAULT_BUFFS_BY_CLASS,
-- so buff_remains > threshold (30) to skip self_buffs.

-- 3a. No pet -> cast with expected_cooldown and min_interval = 10
load_module()
reset_casts()
last_cast_time = {}
NS.player_class_id = 3  -- HUNTER
NS.gcd_remains = function() return 0 end
NS.GetPet = function() return nil end
buff_remains_value = 31  -- > threshold (30), skip self_buffs
r = run_one(base_ctx)
assert(r == true, "Call Pet should cast when no pet, got " .. tostring(r))
assert(#casts >= 1, "Should have at least 1 pet cast, got " .. #casts)
assert(casts[1].opts and casts[1].opts.min_interval == 10.0,
    "Expected pet min_interval=10.0, got " .. tostring(casts[1].opts and casts[1].opts.min_interval))
assert(casts[1].opts and casts[1].opts.expected_cooldown == 10,
    "Expected pet expected_cooldown=10, got " .. tostring(casts[1].opts and casts[1].opts.expected_cooldown))
print("PASS ooc_pet_casts_with_min_interval")

-- 3b. Second attempt within 10s suppressed
-- (Keep cast history from 3a.)
r = run_one(base_ctx)
assert(r == false, "Second Call Pet within min_interval should be suppressed, got " .. tostring(r))
assert(#casts == 1, "No second cast should happen while pet min_interval active")
print("PASS ooc_pet_min_interval_suppresses")

-- 3c. Pet already exists -> pure gate skips before try_cast
load_module()
reset_casts()
last_cast_time = {}
NS.player_class_id = 3
NS.gcd_remains = function() return 0 end
NS.GetPet = function() return {} end  -- pet exists
buff_remains_value = 31
r = run_one(base_ctx)
assert(r == false, "Call Pet should skip when pet already exists, got " .. tostring(r))
assert(#casts == 0, "No cast when pet exists")
print("PASS ooc_pet_present_skips")

-- ================================================================
-- 4. FOOD/FLASK — pure buff gate and min_interval
-- ================================================================

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

-- 4a. No food buff -> cast with min_interval = 3
load_module()
reset_casts()
last_cast_time = {}
NS.player_class_id = 1  -- warrior (no pet summon entry)
NS.gcd_remains = function() return 0 end
buff_remains_value = 31  -- skip self_buffs
has_food_buff = false
r = run_one(food_ctx)
assert(r == true, "Food/flask should cast when no buff, got " .. tostring(r))
assert(#casts >= 1, "Should have at least 1 food cast, got " .. #casts)
assert(casts[1].opts and casts[1].opts.min_interval == 3.0,
    "Expected food/flask min_interval=3.0, got " .. tostring(casts[1].opts and casts[1].opts.min_interval))
print("PASS ooc_food_casts_with_min_interval")

-- 4b. Second attempt within 3s suppressed
-- (Keep cast history from 4a.)
r = run_one(food_ctx)
assert(r == false, "Second food/flask within min_interval should be suppressed, got " .. tostring(r))
assert(#casts == 1, "No second cast should happen while food min_interval active")
print("PASS ooc_food_min_interval_suppresses")

-- 4c. Food buff already active -> pure gate skips before try_cast
load_module()
reset_casts()
last_cast_time = {}
NS.player_class_id = 1
NS.gcd_remains = function() return 0 end
buff_remains_value = 31
has_food_buff = true
r = run_one(food_ctx)
assert(r == false, "Food/flask should skip when buff active, got " .. tostring(r))
assert(#casts == 0, "No cast when food buff active")
print("PASS ooc_food_buff_active_skips")

-- ================================================================
-- 5. Regression: in_combat blocks
-- ================================================================
local combat_ctx = { in_combat = true, settings = { use_ooc_manager = true } }
local combat_result = OOC.on_update(combat_ctx)
assert(combat_result == false, "OOC manager should return false in combat, got " .. tostring(combat_result))
print("PASS ooc_in_combat_blocks")

-- ================================================================
-- 6. Nil-guard: broken_api_throttled no longer required
-- ================================================================
load_module()
reset_casts()
last_cast_time = {}
NS.player_class_id = 1
NS.gcd_remains = function() return 0 end
buff_remains_value = 0
NS.broken_api_throttled = nil  -- should be ignored entirely
r = run_one(base_ctx)
assert(r == true, "Nil broken_api_throttled should not block, got " .. tostring(r))
assert(#casts >= 1, "Should cast when broken_api_throttled is nil, got " .. #casts)
print("PASS ooc_broken_api_throttled_nil_guard")

-- ================================================================
-- Done
-- ================================================================
print("PASS ooc_manager")
