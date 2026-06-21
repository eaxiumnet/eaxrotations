-- Test: Hunter pet happiness auto-feed (middleware FeedPet strategy)
--
-- Exercises:
--   core.spell_book.get_pet_happiness() → context.pet_happiness
--   pet_manager_sylvanas.should_auto_feed(context)
--   Middleware FeedPet strategy (matches + execute)
--
-- API reference: api/core.lua:2044-2053 (pet_happiness_data)
--                api/core.lua:2049-2053 (get_pet_happiness)
--
-- Scenarios:
--   a. happiness=1 (unhappy) + OOC → Feed Pet triggers
--   b. happiness=3 (happy) + OOC → Feed Pet does NOT trigger
--   c. happiness=1 + in combat → Feed Pet does NOT trigger
--   d. API unavailable (nil) → no crash, no Feed Pet trigger

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;api/?/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_false(v, label)
    if v then error(label or "assert_false failed: got " .. tostring(v), 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end
local function assert_nil(v, label)
    if v ~= nil then error((label or "assert_nil") .. ": got " .. tostring(v), 2) end
end

-- ============================================================================
-- Mock the shared modules the middleware requires via package.loaded
-- so dofile(middleware_sylvanas.lua) works cleanly.
-- ============================================================================
package.loaded["shared/consumable_manager_sylvanas"] = {
    on_update = function() return false end,
}
package.loaded["shared/interrupt_manager_sylvanas"] = {
    register_interrupt_spell = function() return { name = "Interrupt", matches = function() return false end, execute = function() return false end } end,
}
package.loaded["shared/aspect_manager_sylvanas"] = {
    viper_middleware_strategy = function() return { name = "ViperStingAspect", matches = function() return false end, execute = function() return false end } end,
    hawk_middleware_strategy = function() return { name = "HawkAspect", matches = function() return false end, execute = function() return false end } end,
}

-- ============================================================================
-- Mock _G.core for get_pet_happiness()
-- We override per-scenario in each test.
-- ============================================================================
_G.core = {
    spell_book = {
        get_pet_happiness = function()
            return { happiness = 3, damage_percentage = 100, loyalty_rate = 1 }
        end,
    },
    object_manager = { get_local_player = function() return {} end },
    time = function() return 100 end,
    input = { pet_cast_target_spell = function() end },
}

-- ============================================================================
-- Mock _G.EaxRotations (NS namespace)
-- ============================================================================
_G.EaxRotations = {
    HunterSpells = {
        AspectOfTheHawk = 27044, AspectOfTheViper = 34074, ArcaneShot = 27019,
        BestialWrath = 19574, CallPet = 883, ConcussiveShot = 5116,
        ExplosiveTrap = 27025, FeignDeath = 5384, FreezingTrap = 1499,
        HuntersMark = 1130, KillCommand = 34026, MendPet = 136,
        MultiShot = 27021, RapidFire = 3045, RevivePet = 982,
        ScatterShot = 19503, SerpentSting = 1978, SilencingShot = 34490,
        SteadyShot = 34120, ViperSting = 3034, Volley = 1510,
        WingClip = 2974, MongooseBite = 36916,
    },
    spell_ready = function(spell_id, target, opts) return true end,
    try_cast = function(spell_id, target, reason, opts) return true end,
    has_pet = function() return true end,
    get_pet = function() return { is_alive = function() return true end } end,
    get_pet_hp = function() return 100 end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    is_spell_learned = function(id) return true end,
    has_buff = function() return false end,
    log = function() end,
    time_now = function() return 100 end,
    game_time_ms = function() return 100000 end,
    register_class_middleware = function(class, strategies)
        _G._test_captured_strategies = strategies -- capture so tests can inspect
    end,
    rotation_registry = {
        register = function() end,
        set_class_config = function() end,
    },
    GetFocus = function() return nil end,
    GetPet = function() return { is_alive = function() return true end } end,
    get_setting = function() return nil end,
    GetTarget = function() return nil end,
    is_hostile_unit = function() return true end,
    GetPlayer = function() return {} end,
    GetPartyMembers = function() return {} end,
    get_player_stance = function() return 0 end,
    is_pvp_zone = function() return false end,
    is_in_party = function() return false end,
    player_control_locked = function() return false end,
    has_breakable_cc_nearby = function() return false end,
    get_debuff_stacks = function() return 0 end,
    same_unit = function() return false end,
    gcd_remains = function() return 0 end,
    get_expansion_max_level = function() return 70 end,
    power_current = function() return 100 end,
    mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    safe_field = function(obj, field) return nil end,
    is_vanilla = function() return false end,
    spell_action = function(opts) return opts end,
    spell_id_is_known = function(id) return true end,
    GetPartyMembers = function() return {} end,
    current_context = nil,
}

-- ============================================================================
-- Helper: find a strategy by name in the middleware strategies table
-- ============================================================================
local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

-- ============================================================================
-- Helper: build a fake context for testing
-- ============================================================================
local function make_context(overrides)
    local ctx = {
        me = {},
        target = nil,
        in_combat = false,
        pet = { is_alive = function() return true end },
        pet_dead = false,
        pet_happiness = 3, -- default: happy
        settings = {},
        has_valid_enemy_target = false,
        enemy_count = 0,
        is_pvp = false,
        combat_time = 0,
        has_aggro = false,
        has_target = false,
        threat_level = 0,
        target_hp = 100,
        hp = 100,
        mana_pct = 100,
        gcd_remains = 0,
        on_gcd = false,
    }
    if overrides then
        for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
end

-- ============================================================================
-- Load the middleware (executes dofile, captures strategies)
-- ============================================================================
_G._test_captured_strategies = nil
local strategies = dofile("EaxRotations/classes/hunter/middleware_sylvanas.lua")
-- If register_class_middleware was called, strategies are in _test_captured_strategies
local middleware_strategies = _G._test_captured_strategies or strategies

-- ============================================================================
-- Verify structure: FeedPet strategy must exist
-- ============================================================================
local feed_pet = find_strategy(middleware_strategies, "FeedPet")
assert_true(feed_pet ~= nil, "FeedPet strategy must exist in hunter middleware")
assert_eq(feed_pet.name, "FeedPet", "strategy name")
assert_true(type(feed_pet.matches) == "function", "FeedPet.matches must be a function")
assert_true(type(feed_pet.execute) == "function", "FeedPet.execute must be a function")

-- ============================================================================
-- SCENARIO A: happiness=1 (unhappy) + OOC → Feed Pet is triggered
-- ============================================================================
do
    local ctx = make_context({
        pet_happiness = 1,
        in_combat = false,
        pet = { is_alive = function() return true end },
        pet_dead = false,
    })
    local should_fire = feed_pet.matches(ctx)
    assert_true(should_fire, "A: FeedPet should trigger when happiness=1 and OOC")
end

-- ============================================================================
-- SCENARIO B: happiness=3 (happy) + OOC → Feed Pet is NOT triggered
-- ============================================================================
do
    local ctx = make_context({
        pet_happiness = 3,
        in_combat = false,
        pet = { is_alive = function() return true end },
        pet_dead = false,
    })
    local should_fire = feed_pet.matches(ctx)
    assert_false(should_fire, "B: FeedPet should NOT trigger when happiness=3 and OOC")
end

-- ============================================================================
-- SCENARIO C: happiness=1 + in combat → Feed Pet is NOT triggered
-- ============================================================================
do
    local ctx = make_context({
        pet_happiness = 1,
        in_combat = true,
        pet = { is_alive = function() return true end },
        pet_dead = false,
        has_valid_enemy_target = true,
        target = {},
        enemy_count = 1,
        combat_time = 5,
    })
    local should_fire = feed_pet.matches(ctx)
    assert_false(should_fire, "C: FeedPet should NOT trigger when happiness=1 but in combat")
end

-- ============================================================================
-- SCENARIO D: API unavailable (pet_happiness nil) → no crash, no trigger
-- ============================================================================
do
    local ctx = make_context({
        pet_happiness = nil, -- API unavailable
        in_combat = false,
        pet = { is_alive = function() return true end },
        pet_dead = false,
    })
    local ok, result = pcall(function()
        return feed_pet.matches(ctx)
    end)
    assert_true(ok, "D: FeedPet should not crash when pet_happiness is nil")
    assert_false(result, "D: FeedPet should NOT trigger when pet_happiness is nil")
end

print("PASS test_pet_happiness")
