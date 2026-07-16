-- test_discipline_predictive_pws.lua — Test for health_prediction-based PW:S pre-shielding.
-- WHAT:  proves pws_tank_matches shields when current HP > threshold but predicted HP < threshold.
-- WHEN:  regression gate for discipline priest health_prediction integration.
-- WHY:   prior dead-code bug placed HealthPred check after current-HP gate, making it unreachable.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local test = {}

if not _G.EaxRotations then _G.EaxRotations = {} end
local NS = _G.EaxRotations

-- Set up NS mocks needed for discipline_sylvanas.lua to load
NS.PriestSpells = NS.PriestSpells or {
    PowerWordShield = 17, PrayerofMending = 33076, FlashHeal = 2061,
    GreaterHeal = 2060, Renew = 139, ShadowWordPain = 589, Smite = 585,
    PrayerOfHealing = 596, BindingHeal = 32546, AbolishDisease = 552,
    DispelMagic = 527, MassDispel = 32375, InnerFocus = 14751,
    PowerInfusion = 10060, Shadowfiend = 34433,
}
NS.PLAYER_UNIT = NS.PLAYER_UNIT or {}
NS.spell_ready = NS.spell_ready or function() return true end
NS.spell_exists = NS.spell_exists or function() return true end
NS.debuff_remains = NS.debuff_remains or function() return 0 end
NS.buff_up = NS.buff_up or function() return false end
NS.buff_points = NS.buff_points or function() return nil end
NS.debuff_up = NS.debuff_up or function() return false end
NS.has_player_buff = NS.has_player_buff or function() return false end
NS.has_target_debuff = NS.has_target_debuff or function() return false end
NS.cooldown_remains = NS.cooldown_remains or function() return 0 end
NS.gate_overheal = NS.gate_overheal or function() return false end
NS.gate_cooldown_boss_only = NS.gate_cooldown_boss_only or function() return true end
NS.should_use_long_cd = NS.should_use_long_cd or function() return true end
NS.try_cast = NS.try_cast or function() return true end
NS.log = NS.log or function() end
NS.rotation_registry = NS.rotation_registry or { register = function() end }
NS.import_helpers = NS.import_helpers or function(...) return nil end
NS.GetPlayer = NS.GetPlayer or function() return nil end
NS.same_unit = NS.same_unit or function(a, b) return a == b end
NS.unit_is_boss = NS.unit_is_boss or function() return false end
NS.unit_is_tank = NS.unit_is_tank or function() return false end

-- Mock healing module
local mock_healing = {
    scan_healing_targets = function() return {}, 0 end,
    pws_absorb_remaining = function() return 0 end,
    has_weakened_soul = function() return false end,
    has_renew = function() return false end,
    renew_remains = function() return 0 end,
    has_pws = function() return false end,
    predict_effective_deficit = function() return 0 end,
}
package.loaded["classes/priest/healing_sylvanas"] = mock_healing
NS.PriestHealing = mock_healing

-- Mock preemptive_heal module
package.loaded["shared/preemptive_heal_sylvanas"] = {
    match = function() return false end,
    execute = function() return false end,
    DEFAULT_THRESHOLD = 40,
}

-- Mock FSR manager
package.loaded["shared/fsr_manager_sylvanas"] = {
    get_state = function() return { in_fsr = false, remains = 0 } end,
    update = function() end,
}

-- Mock spec_kit
package.loaded["shared/spec_kit_sylvanas"] = package.loaded["shared/spec_kit_sylvanas"] or {
    define_action_for_class = function(SPELLS)
        return function(field, ids, label)
            if type(ids) == "table" then return ids[1] end
            return ids
        end
    end,
    safe_state = function(state) return state end,
    setting_bool = function(ctx, key, default) return default end,
    setting_number = function(ctx, key, default) return default end,
    setting = function(ctx, key, default) return default end,
}

-- Mock health_pred_helper with controllable predicted_hp_pct
local mock_pred_hp = 100
package.loaded["shared/health_pred_helper_sylvanas"] = {
    incoming_damage = function(unit, deadline) return 0 end,
    predicted_hp_pct = function(unit, deadline) return mock_pred_hp end,
    is_tank_role = function(unit) return false end,
    get_damage_types = function(unit, deadline) return { physical_damage = {}, magical_damage = {} } end,
}

-- Load discipline spec
local result = dofile("EaxRotations/classes/priest/discipline_sylvanas.lua")
local strategies = result and result.strategies or {}
local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local pws_tank = find_strategy("PowerWordShieldTank")

function test.test_strategy_exists()
    assert(pws_tank ~= nil, "PowerWordShieldTank strategy should exist in discipline spec")
end

function test.test_predictive_shield_when_current_high_predicted_low()
    if not pws_tank then return end
    mock_pred_hp = 25
    local context = { settings = { discipline_pws_hp = 35 } }
    local state = {
        tank = {
            effective_hp = 60,
            has_weakened_soul = false,
            unit = { get_health_percentage = function() return 60 end, get_health = function() return 6000 end, get_max_health = function() return 10000 end },
        },
        pws_ready = true,
    }
    local result = pws_tank.matches(context, state)
    assert(result == true, "should shield when current HP=60 > threshold=35 but predicted HP=25 < 35")
end

function test.test_no_shield_when_both_current_and_predicted_high()
    if not pws_tank then return end
    mock_pred_hp = 75
    local context = { settings = { discipline_pws_hp = 35 } }
    local state = {
        tank = {
            effective_hp = 80,
            has_weakened_soul = false,
            unit = { get_health_percentage = function() return 80 end, get_health = function() return 8000 end, get_max_health = function() return 10000 end },
        },
        pws_ready = true,
    }
    local result = pws_tank.matches(context, state)
    assert(result == false, "should NOT shield when current HP=80 > 35 and predicted HP=75 >= 35")
end

function test.test_shield_when_current_low_regardless_of_pred()
    if not pws_tank then return end
    mock_pred_hp = 90
    local context = { settings = { discipline_pws_hp = 35 } }
    local state = {
        tank = {
            effective_hp = 25,
            has_weakened_soul = false,
            unit = { get_health_percentage = function() return 25 end, get_health = function() return 2500 end, get_max_health = function() return 10000 end },
        },
        pws_ready = true,
    }
    local result = pws_tank.matches(context, state)
    assert(result == true, "should shield when current HP=25 <= 35 regardless of predicted HP")
end

function test.test_no_shield_when_weakened_soul()
    if not pws_tank then return end
    mock_pred_hp = 20
    local context = { settings = { discipline_pws_hp = 35 } }
    local state = {
        tank = {
            effective_hp = 25,
            has_weakened_soul = true,
            unit = { get_health_percentage = function() return 25 end, get_health = function() return 2500 end, get_max_health = function() return 10000 end },
        },
        pws_ready = true,
    }
    local result = pws_tank.matches(context, state)
    assert(result == false, "should NOT shield when weakened soul is active")
end

function test.test_no_shield_when_pws_not_ready()
    if not pws_tank then return end
    mock_pred_hp = 20
    local context = { settings = { discipline_pws_hp = 35 } }
    local state = {
        tank = {
            effective_hp = 25,
            has_weakened_soul = false,
            unit = { get_health_percentage = function() return 25 end, get_health = function() return 2500 end, get_max_health = function() return 10000 end },
        },
        pws_ready = false,
    }
    local result = pws_tank.matches(context, state)
    assert(result == false, "should NOT shield when PW:S is not ready")
end

-- Helper module unit tests
function test.test_predicted_hp_pct_returns_current_when_no_damage()
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    local orig_hp = NS.health_prediction
    NS.health_prediction = nil
    local M = require("shared/health_pred_helper_sylvanas")
    local unit = {
        get_health_percentage = function() return 75 end,
        get_health = function() return 7500 end,
        get_max_health = function() return 10000 end,
    }
    local result = M.predicted_hp_pct(unit, 3.0)
    NS.health_prediction = orig_hp
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    assert(result == 75, "predicted HP should equal current HP when no incoming damage. Got: " .. tostring(result))
end

function test.test_predicted_hp_pct_reduces_with_damage()
    local orig_hp = NS.health_prediction
    NS.health_prediction = {
        get_incoming_damage = function(self, tgt, deadline) return 3000 end,
    }
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    local M = require("shared/health_pred_helper_sylvanas")
    local unit = {
        get_health_percentage = function() return 75 end,
        get_health = function() return 7500 end,
        get_max_health = function() return 10000 end,
    }
    local result = M.predicted_hp_pct(unit, 3.0)
    NS.health_prediction = orig_hp
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    assert(result < 75, "predicted HP should be less than current when incoming damage exists. Got: " .. tostring(result))
    assert(result >= 0, "predicted HP should not be negative. Got: " .. tostring(result))
end

function test.test_incoming_damage_returns_zero_without_module()
    local orig_hp = NS.health_prediction
    NS.health_prediction = nil
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    local M = require("shared/health_pred_helper_sylvanas")
    local result = M.incoming_damage({ get_health = function() return 100 end }, 3.0)
    NS.health_prediction = orig_hp
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    assert(result == 0, "incoming_damage should return 0 when health_prediction unavailable. Got: " .. tostring(result))
end

function test.test_is_tank_role_returns_false_without_module()
    local orig_hp = NS.health_prediction
    NS.health_prediction = nil
    local orig_ut = NS.unit_is_tank
    NS.unit_is_tank = nil
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    local M = require("shared/health_pred_helper_sylvanas")
    local result = M.is_tank_role({ get_health = function() return 100 end })
    NS.health_prediction = orig_hp
    NS.unit_is_tank = orig_ut
    package.loaded["shared/health_pred_helper_sylvanas"] = nil
    assert(result == false, "is_tank_role should return false when no module or fallback. Got: " .. tostring(result))
end

-- Run all tests
local failures = 0
local passed = 0
for name, fn in pairs(test) do
    local ok, err = pcall(fn)
    if ok then
        print(string.format("  [ PASS ] %s", name))
        passed = passed + 1
    else
        print(string.format("  [ FAIL ] %s: %s", name, err))
        failures = failures + 1
    end
end

print(string.format("\n  discipline_predictive_pws: %d passed, %d failed", passed, failures))
if failures > 0 then os.exit(1) end
