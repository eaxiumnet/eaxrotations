-- test_discipline_healer_mode.lua — Validate discipline healer-mode strategy paths.
-- WHAT:  mocks a priest player and validates that healer-mode strategies fire under expected conditions.
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   discipline has dual DPS/healer paths; tests ensure the healer branch is reachable.
-- SAFETY: fully mocked player/target/context; no casting.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local casts = 0
local strategies_fired = {}

local player = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power = function() return 1000 end,
    get_class = function() return 5 end,
    get_target = function()
        return {
            is_alive = function() return true end,
            is_valid = function() return true end,
            is_enemy_with = function() return true end,
            get_health_percentage = function() return 80 end,
            get_distance = function() return 15 end,
        }
    end,
    is_in_combat = function() return true end,
    gcd_remains = function() return 0 end,
    is_moving = function() return false end,
    is_casting = function() return false end,
    is_channeling = function() return false end,
}

_G.core = {
    time = function() return 100 end,
    game_time = function() return 100000 end,
    log = function(...) end,
    log_warning = function(...) end,
    log_error = function(...) end,
    object_manager = {
        get_local_player = function() return player end,
        get_visible_objects = function() return {} end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 0, 0 end,
        get_spell_cooldown = function() return 0 end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return true end,
    },
    input = {},
}

package.loaded.core_sylvanas = nil
package.loaded.main_sylvanas = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")

NS.izi = {
    spell = function(spell_id)
        return {
            is_castable_to_unit = function(_, unit, opts)
                return true, nil
            end,
            cast_safe = function(_, unit, reason)
                casts = casts + 1
                return true
            end,
        }
    end,
}

local dispatcher = require("main_sylvanas")

local function reset()
    casts = 0
    strategies_fired = {}
end

local function track(name, category)
    return {
        name = name,
        category = category,
        matches = function() return true end,
        execute = function()
            strategies_fired[#strategies_fired + 1] = { name = name, category = category }
            return true
        end,
    }
end

NS.class_middleware = {}

NS.rotation_registry = {
    class_config = { class_key = "priest", default_playstyle = "discipline" },
    playstyles = {
        discipline = {
            track("Heal_Greater", "healing"),
            track("IdleShadowWordPain", "damage"),
            track("IdleSmite", "damage"),
        },
    },
    options = {
        discipline = { get_state = function(ctx) return ctx end },
    },
}

NS.set_setting("playstyle", "discipline")

reset()
dispatcher.on_rotation_update()

assert_eq(#strategies_fired, 1, "Healer playstyle must emit exactly ONE strategy")
assert_eq(strategies_fired[1].name, "Heal_Greater", "Healer mode must only evaluate healing strategies (fired=" .. tostring(strategies_fired[1].name) .. ")")

print("PASS test_discipline_healer_mode")
