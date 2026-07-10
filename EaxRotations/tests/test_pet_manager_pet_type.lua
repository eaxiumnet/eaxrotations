-- test_pet_manager_pet_type.lua — Unit tests for pet type detection and Felguard ability gating.
-- WHAT:  Validates M.get_pet_type and that Felguard Intercept/Anguish only fire for Felguard in combat.
-- WHEN:  Run via run_rotation_tests.lua or standalone.
-- WHY:   Prevents Felguard-only abilities from firing with the wrong pet or out of combat.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_eq(a, b, label)
    if a ~= b then
        error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

local function assert_false(v, label)
    if v then error(label or "assert_false failed", 2) end
end

local function assert_nil(v, label)
    if v ~= nil then error(label or "assert_nil failed", 2) end
end

-- Spell IDs used by pet_manager_sylvanas.lua for type detection.
local TYPE_SPELLS = {
    imp        = 3110,
    voidwalker = 17735,
    succubus   = 7814,
    felhunter  = 54053,
    felguard   = 30213,
}

-- Build a fresh pet_manager module with the provided core mock.
local function load_manager(core_mock)
    package.loaded["shared/pet_manager_sylvanas"] = nil
    _G.core = core_mock or {}
    _G.EaxRotations = _G.EaxRotations or {}
    _G.EaxRotations.time_now = _G.EaxRotations.time_now or function() return 0 end
    _G.EaxRotations.spell_id_is_known = _G.EaxRotations.spell_id_is_known or function(id) return true end
    local ok, mod = pcall(require, "shared/pet_manager_sylvanas")
    if not ok then
        error("Failed to load pet_manager_sylvanas: " .. tostring(mod), 2)
    end
    if type(mod) ~= "table" then
        error("pet_manager_sylvanas did not return a table (got " .. tostring(mod) .. ")", 2)
    end
    return mod
end

-- Mock pet object with optional spell list.
local _pet_counter = 0
local function make_pet(spells, guid)
    _pet_counter = _pet_counter + 1
    return {
        _guid = guid or ("pet-guid-" .. _pet_counter),
        _spells = spells or {},
        get_guid = function(self) return self._guid end,
        is_dead = function(self) return false end,
        get_health_percentage = function(self) return 100 end,
        get_spells = function(self) return self._spells end,
    }
end

-- ============================================================================
-- Pet type detection tests
-- ============================================================================

local function test_get_pet_type()
    -- No global get_pet_spells; rely on pet object fallback.
    local core_mock = {
        spell_book = {},
    }
    local M = load_manager(core_mock)

    for type_name, spell_id in pairs(TYPE_SPELLS) do
        local pet = make_pet({ spell_id })
        -- Provide spells via pet object (global get_pet_spells returns empty)
        assert_eq(M.get_pet_type(pet), type_name, "get_pet_type detects " .. type_name)
    end

    -- Unknown pet type returns nil
    local unknown = make_pet({ 99999 })
    assert_nil(M.get_pet_type(unknown), "get_pet_type returns nil for unknown pet")

    -- Nil pet returns nil
    assert_nil(M.get_pet_type(nil), "get_pet_type returns nil for nil pet")
end

-- ============================================================================
-- Felguard Intercept/Anguish gating tests
-- ============================================================================

local function test_felguard_abilities_gated_by_type_and_combat()
    local me = {
        get_distance = function(self, target) return 15 end,
    }
    local target = {
        get_guid = function() return "target-guid" end,
        get_position = function() return { x = 0, y = 0, z = 0 } end,
        get_target = function() return me end,
    }

    -- Helper: load manager with a whitelist of known spell IDs.
    local function load_for_spells(known_ids)
        local known = {}
        for _, id in ipairs(known_ids) do known[id] = true end
        _G.EaxRotations.spell_id_is_known = function(id) return known[id] == true end
        -- Use a large timestamp so throttle windows are open.
        _G.EaxRotations.time_now = function() return 100 end
        local core_mock = {
            spell_book = {
                get_pet_spells = function() return known_ids end,
                get_spell_cooldown = function(id) return 0 end,
                get_pet_action_info = function(id)
                    return { checks_range = true, in_range = true }
                end,
            },
            input = {
                pet_cast_target_spell = function(spell_id, target)
                    return true
                end,
                pet_attack = function(target) return true end,
            },
        }
        return load_manager(core_mock)
    end

    -- Helper to run on_update with a given combat state and return cast count.
    -- The first call sends the pet to attack; the second call casts abilities.
    local function run(M, in_combat)
        local casts = {}
        -- Wrap the cast function to capture this run's casts.
        local original = _G.core.input.pet_cast_target_spell
        _G.core.input.pet_cast_target_spell = function(spell_id, target)
            casts[#casts + 1] = { spell_id = spell_id, target = target }
            return true
        end
        local ctx = {
            in_combat = in_combat,
            is_group = false,
            player_class_name = "warlock",
        }
        -- First tick: pet attack (and possibly cast if already on target).
        M.on_update(me, target, "test", ctx)
        -- Second tick: pet is on target, abilities can fire.
        M.on_update(me, target, "test", ctx)
        _G.core.input.pet_cast_target_spell = original
        return casts
    end

    -- In combat with Felguard -> Intercept should fire (distance > 8)
    local M_felguard = load_for_spells({ TYPE_SPELLS.felguard, 30198, 33698 })
    local casts = run(M_felguard, true)
    print("DEBUG casts count: " .. #casts)
    for _, c in ipairs(casts) do print("  cast: " .. c.spell_id) end
    assert_true(#casts > 0, "Felguard Intercept fires in combat with Felguard pet")
    local intercept_fired = false
    for _, c in ipairs(casts) do
        if c.spell_id == 30198 then intercept_fired = true; break end
    end
    assert_true(intercept_fired, "Felguard Intercept spell ID was cast")

    -- Out of combat with Felguard -> no Felguard abilities
    casts = run(M_felguard, false)
    assert_eq(#casts, 0, "Felguard abilities do not fire out of combat")

    -- In combat but pet is Imp -> no Felguard abilities
    local M_imp = load_for_spells({ TYPE_SPELLS.imp })
    casts = run(M_imp, true)
    assert_eq(#casts, 0, "Felguard abilities do not fire with Imp pet")
end

-- ============================================================================
-- Run all tests
-- ============================================================================

local ok1, err1 = pcall(test_get_pet_type)
if not ok1 then
    print("FAIL test_get_pet_type: " .. tostring(err1))
    return
end
print("PASS test_get_pet_type")

local ok2, err2 = pcall(test_felguard_abilities_gated_by_type_and_combat)
if not ok2 then
    print("FAIL test_felguard_abilities_gated_by_type_and_combat: " .. tostring(err2))
    return
end
print("PASS test_felguard_abilities_gated_by_type_and_combat")

print("PASS test_pet_manager_pet_type")
