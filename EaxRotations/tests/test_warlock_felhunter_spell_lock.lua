-- test_warlock_felhunter_spell_lock.lua — Unit tests for the FelhunterSpellLock middleware strategy.
-- WHAT:  Validates that Felhunter Spell Lock only matches when use_interrupt is true,
--        the target is casting, and a Felhunter is active; and that it casts via the pet.
-- WHEN:  Run via run_rotation_tests.lua or standalone.
-- WHY:   Prevents wasted casts and ensures the interrupt is issued by the pet.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_false(v, label)
    if v then error(label or "assert_false failed", 2) end
end

local function assert_eq(a, b, label)
    if a ~= b then
        error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

-- Spell IDs used by pet_manager_sylvanas.lua for type detection.
local FELHUNTER_BITE = 54053
local SPELL_LOCK_ID = 19647

-- Build a fresh middleware module with the provided core mock and NS namespace.
local function load_middleware(core_mock, ns)
    package.loaded["classes/warlock/middleware_sylvanas"] = nil
    package.loaded["shared/pet_manager_sylvanas"] = nil
    _G.core = core_mock or {}
    _G.EaxRotations = ns
    local ok, mod = pcall(require, "classes/warlock/middleware_sylvanas")
    if not ok then
        error("Failed to load warlock middleware: " .. tostring(mod), 2)
    end
    return mod
end

-- Mock pet object with optional spell list.
local _pet_counter = 0
local function make_pet(spells)
    _pet_counter = _pet_counter + 1
    return {
        _guid = "pet-guid-" .. _pet_counter,
        _spells = spells or {},
        get_guid = function(self) return self._guid end,
        is_dead = function(self) return false end,
        get_health_percentage = function(self) return 100 end,
        get_spells = function(self) return self._spells end,
    }
end

-- Mock player with optional pet.
local function make_player(pet)
    return {
        get_pet = function() return pet end,
    }
end

-- Mock target with optional casting state.
local function make_target(is_casting, is_channeling)
    return {
        is_casting = function() return is_casting or false end,
        is_channeling = function() return is_channeling or false end,
    }
end

-- ============================================================================
-- FelhunterSpellLock strategy tests
-- ============================================================================

local function test_felhunter_spell_lock_gating()
    local pet_casts = {}
    local player_casts = {}

    local core_mock = {
        spell_book = {
            -- Rely on pet:get_spells() so each mock pet can report its own spells.
            get_spell_cooldown = function(id) return 0 end,
            get_pet_action_info = function(id)
                return { checks_range = true, in_range = true }
            end,
        },
        input = {
            pet_cast_target_spell = function(spell_id, target)
                pet_casts[#pet_casts + 1] = { spell_id = spell_id, target = target }
                return true
            end,
            cast_target_spell = function(spell_id, target)
                player_casts[#player_casts + 1] = { spell_id = spell_id, target = target }
                return true
            end,
        },
    }

    local NS = {
        GetPlayer = function() return make_player(make_pet({ FELHUNTER_BITE })) end,
        get_spell_id = function(spell)
            if type(spell) == "table" and spell._meta then
                return spell._meta.id[1]
            end
            return SPELL_LOCK_ID
        end,
        is_spell_learned = function(id)
            return id == SPELL_LOCK_ID
        end,
        time_now = function() return 0 end,
        register_class_middleware = function(class_key, strategies) end,
    }

    local strategies = load_middleware(core_mock, NS)
    local strategy = nil
    for _, s in ipairs(strategies) do
        if s.name == "FelhunterSpellLock" then
            strategy = s
            break
        end
    end
    assert_true(strategy ~= nil, "FelhunterSpellLock strategy exists")

    local base_context = {
        in_combat = true,
        target = make_target(true, false),
        settings = { use_interrupt = true, interrupt_humanize_enabled = false },
        me = make_player(make_pet({ FELHUNTER_BITE })),
    }

    -- Should match with use_interrupt=true, target casting, Felhunter active
    assert_true(strategy.matches(base_context), "matches when use_interrupt=true, target casting, Felhunter active")

    -- Should cast via pet_cast_target_spell, not cast_target_spell
    pet_casts = {}
    player_casts = {}
    local executed = strategy.execute(base_context)
    assert_true(executed, "execute returns true")
    assert_eq(#pet_casts, 1, "exactly one pet cast attempted")
    assert_eq(pet_casts[1].spell_id, SPELL_LOCK_ID, "pet cast uses Spell Lock ID")
    assert_eq(#player_casts, 0, "no player cast attempted")

    -- Should not match when use_interrupt=false
    local ctx_disabled = {
        in_combat = true,
        target = make_target(true, false),
        settings = { use_interrupt = false, interrupt_humanize_enabled = false },
        me = make_player(make_pet({ FELHUNTER_BITE })),
    }
    assert_false(strategy.matches(ctx_disabled), "does not match when use_interrupt=false")

    -- Should not match when target not casting
    local ctx_not_casting = {
        in_combat = true,
        target = make_target(false, false),
        settings = { use_interrupt = true, interrupt_humanize_enabled = false },
        me = make_player(make_pet({ FELHUNTER_BITE })),
    }
    assert_false(strategy.matches(ctx_not_casting), "does not match when target not casting")

    -- Should not match when out of combat
    local ctx_ooc = {
        in_combat = false,
        target = make_target(true, false),
        settings = { use_interrupt = true, interrupt_humanize_enabled = false },
        me = make_player(make_pet({ FELHUNTER_BITE })),
    }
    assert_false(strategy.matches(ctx_ooc), "does not match out of combat")

    -- Should not match when pet is Imp
    local pet_imp = make_pet({ 3110 }) -- Imp Firebolt
    local ctx_imp = {
        in_combat = true,
        target = make_target(true, false),
        settings = { use_interrupt = true, interrupt_humanize_enabled = false },
        me = make_player(pet_imp),
    }
    assert_false(strategy.matches(ctx_imp), "does not match with Imp pet")

    -- Should not match when no pet
    local ctx_no_pet = {
        in_combat = true,
        target = make_target(true, false),
        settings = { use_interrupt = true, interrupt_humanize_enabled = false },
        me = make_player(nil),
    }
    assert_false(strategy.matches(ctx_no_pet), "does not match without pet")

    -- Should not match when Spell Lock is on cooldown
    core_mock.spell_book.get_spell_cooldown = function(id) return 5 end
    strategies = load_middleware(core_mock, NS)
    for _, s in ipairs(strategies) do
        if s.name == "FelhunterSpellLock" then
            strategy = s
            break
        end
    end
    assert_false(strategy.matches(base_context), "does not match when Spell Lock is on cooldown")
end

-- ============================================================================
-- Run tests
-- ============================================================================

local ok, err = pcall(test_felhunter_spell_lock_gating)
if not ok then
    print("FAIL test_warlock_felhunter_spell_lock: " .. tostring(err))
    return
end
print("PASS test_warlock_felhunter_spell_lock")
