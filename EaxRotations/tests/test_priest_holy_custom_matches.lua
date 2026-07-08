-- test_priest_holy_custom_matches.lua -- Holy Priest custom match validation tests.
-- WHAT:  Holy Priest custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- unit tests for priest_holy_sylvanas custom matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local action_calls = {}
local spell_ready_calls = {}
_G.EaxRotations = {
    PriestSpells = {
        PowerWordShield = 17,
        CircleofHealing = 34861,
        InnerFocus = 14751,
        ShadowWordPain = 589,
    },
    PLAYER_UNIT = {},
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    spell_ready = function(spell, target, opts)
        spell_ready_calls[#spell_ready_calls + 1] = { spell = spell, target = target, opts = opts }
        return true
    end,
    spell_exists = function(spell)
        return true
    end,
    has_player_buff = function(buff_list)
        return false
    end,
    debuff_remains = function(target, debuff_list)
        return 0
    end,
    import_helpers = function(...)
        local n = select("#", ...)
        local f = function() return true end
        if n >= 7 then return f, f, f, f, f, f, f end
        if n == 6 then return f, f, f, f, f, f end
        if n == 5 then return f, f, f, f, f end
        if n == 4 then return f, f, f, f end
        if n == 3 then return f, f, f end
        if n == 2 then return f, f end
        return f
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
    GetPlayer = function()
        return {
            get_class = function() return 5 end,
            is_moving = function() return false end,
            mana_pct = function() return 100 end,
        }
    end,
}

-- Mock healing module
local mock_healing = {
    scan_healing_targets = function()
        return {}, 0
    end,
}
package.loaded["classes/priest/healing_sylvanas"] = mock_healing

-- Mock enums
package.loaded["common/enums"] = { class_id = { PRIEST = 5 } }

local strategies = dofile("EaxRotations/classes/priest/holy_sylvanas.lua")
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- EmergencyPWS: only when lowest HP <= threshold and not weakened_soul
-- ============================================================================

local pws = find_strategy("EmergencyPWS")

-- High HP -> should NOT match
action_calls = {}
local ctx_pws_high = {
    player_control_locked = false,
    settings = { holy_use_pws = true, holy_pws_hp = 30 },
}
assert_false(pws.matches(ctx_pws_high, { lowest = { effective_hp = 60, has_weakened_soul = false, unit = {} } }), "EmergencyPWS should not match when HP > threshold")
assert_eq(#action_calls, 0, "action_matches should not be called when HP high")

-- Low HP but weakened soul -> should NOT match
action_calls = {}
local ctx_pws_ws = {
    player_control_locked = false,
    settings = { holy_use_pws = true, holy_pws_hp = 30 },
}
assert_false(pws.matches(ctx_pws_ws, { lowest = { effective_hp = 20, has_weakened_soul = true, unit = {} } }), "EmergencyPWS should not match when weakened soul")
assert_eq(#action_calls, 0, "action_matches should not be called when weakened soul")

-- Low HP, no weakened soul -> should match
action_calls = {}
local ctx_pws_ok = {
    player_control_locked = false,
    settings = { holy_use_pws = true, holy_pws_hp = 30 },
}
assert_true(pws.matches(ctx_pws_ok, { lowest = { effective_hp = 20, has_weakened_soul = false, unit = {} } }), "EmergencyPWS should match when HP <= threshold and no weakened soul")

-- Player control locked -> should NOT match
action_calls = {}
local ctx_pws_lock = {
    player_control_locked = true,
    settings = { holy_use_pws = true, holy_pws_hp = 30 },
}
assert_false(pws.matches(ctx_pws_lock, { lowest = { effective_hp = 20, has_weakened_soul = false, unit = {} } }), "EmergencyPWS should not match when control locked")

-- No lowest -> should NOT match
action_calls = {}
assert_false(pws.matches({ settings = { holy_use_pws = true, holy_pws_hp = 30 } }, { lowest = nil }), "EmergencyPWS should not match without lowest")

-- ============================================================================
-- CircleOfHealing: only in combat with enough damaged group members
-- ============================================================================

local coh = find_strategy("CircleOfHealing")

-- Not in combat -> should NOT match
action_calls = {}
local ctx_coh_ooc = {
    in_combat = false,
    player_control_locked = false,
    settings = { holy_use_coh = true, holy_aoe_count = 3 },
}
assert_false(coh.matches(ctx_coh_ooc, { group_damaged_count = 5 }), "CircleOfHealing should not match when OOC")

-- Too few damaged -> should NOT match
action_calls = {}
local ctx_coh_few = {
    in_combat = true,
    player_control_locked = false,
    settings = { holy_use_coh = true, holy_aoe_count = 3 },
}
assert_false(coh.matches(ctx_coh_few, { group_damaged_count = 2 }), "CircleOfHealing should not match with < threshold damaged")

-- Enough damaged -> should match
action_calls = {}
local ctx_coh_ok = {
    in_combat = true,
    player_control_locked = false,
    settings = { holy_use_coh = true, holy_aoe_count = 3 },
}
assert_true(coh.matches(ctx_coh_ok, { group_damaged_count = 4, coh_ready = true }), "CircleOfHealing should match with >= threshold damaged")

-- Player control locked -> should NOT match
action_calls = {}
assert_false(coh.matches({ player_control_locked = true }, { group_damaged_count = 4 }), "CircleOfHealing should not match when control locked")

-- ============================================================================
-- InnerFocus: only in combat, not already buffed
-- ============================================================================

local inner_focus = find_strategy("InnerFocus")

-- Not in combat -> should NOT match
action_calls = {}
local ctx_if_ooc = {
    in_combat = false,
    player_control_locked = false,
    settings = { holy_use_inner_focus = true },
}
assert_false(inner_focus.matches(ctx_if_ooc, { has_inner_focus = false, lowest = { effective_hp = 80 } }), "InnerFocus should not match when OOC")

-- Already has buff -> should NOT match
action_calls = {}
local ctx_if_buff = {
    in_combat = true,
    player_control_locked = false,
    settings = { holy_use_inner_focus = true },
}
assert_false(inner_focus.matches(ctx_if_buff, { has_inner_focus = true, lowest = { effective_hp = 80 } }), "InnerFocus should not match when already buffed")

-- In combat, no buff -> should match
action_calls = {}
local ctx_if_ok = {
    in_combat = true,
    player_control_locked = false,
    settings = { holy_use_inner_focus = true },
}
assert_true(inner_focus.matches(ctx_if_ok, { has_inner_focus = false, lowest = { effective_hp = 80 }, lowest_hp = 80 }), "InnerFocus should match in combat without buff")

-- ============================================================================
-- IdleSWP: only in combat, dps_when_idle enabled, valid enemy target, group stable
-- ============================================================================

local idle_swp = find_strategy("IdleSWP")

-- Not in combat -> should NOT match
action_calls = {}
local ctx_swp_ooc = {
    in_combat = false,
    player_control_locked = false,
    settings = { holy_dps_when_idle = true, holy_renew_hp = 90 },
    has_valid_enemy_target = true,
    target = {},
}
assert_false(idle_swp.matches(ctx_swp_ooc, { lowest_hp = 95, swp_remaining = 0 }), "IdleSWP should not match when OOC")

-- DPS disabled -> should NOT match
action_calls = {}
local ctx_swp_no = {
    in_combat = true,
    player_control_locked = false,
    settings = { holy_dps_when_idle = false, holy_renew_hp = 90 },
    has_valid_enemy_target = true,
    target = {},
}
assert_false(idle_swp.matches(ctx_swp_no, { lowest_hp = 95, swp_remaining = 0 }), "IdleSWP should not match when dps_when_idle disabled")

-- No valid enemy target -> should NOT match
action_calls = {}
local ctx_swp_no_target = {
    in_combat = true,
    player_control_locked = false,
    settings = { holy_dps_when_idle = true, holy_renew_hp = 90 },
    has_valid_enemy_target = false,
    target = {},
}
assert_false(idle_swp.matches(ctx_swp_no_target, { lowest_hp = 95, swp_remaining = 0 }), "IdleSWP should not match without valid enemy target")

-- Group needs healing -> should NOT match
action_calls = {}
local ctx_swp_heal = {
    in_combat = true,
    player_control_locked = false,
    settings = { holy_dps_when_idle = true, holy_renew_hp = 90 },
    has_valid_enemy_target = true,
    target = {},
}
assert_false(idle_swp.matches(ctx_swp_heal, { lowest_hp = 80, swp_remaining = 0 }), "IdleSWP should not match when group needs healing")

-- SWP already active -> should NOT match
action_calls = {}
local ctx_swp_active = {
    in_combat = true,
    player_control_locked = false,
    settings = { holy_dps_when_idle = true, holy_renew_hp = 90 },
    has_valid_enemy_target = true,
    target = {},
    mana_pct = 100,
}
assert_false(idle_swp.matches(ctx_swp_active, { lowest_hp = 95, swp_remaining = 10 }), "IdleSWP should not match when SWP already active")

-- All conditions met -> should match
action_calls = {}
local ctx_swp_ok = {
    in_combat = true,
    player_control_locked = false,
    settings = { holy_dps_when_idle = true, holy_renew_hp = 90 },
    has_valid_enemy_target = true,
    target = {},
    mana_pct = 100,
}
assert_true(idle_swp.matches(ctx_swp_ok, { lowest_hp = 95, swp_remaining = 0 }), "IdleSWP should match when all conditions met")

print("PASS test_priest_holy_custom_matches")
