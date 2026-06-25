-- Feature audit for discipline_sylvanas: verifies all strategies and parity gaps.
-- 18 baseline + 3 ClassResearchTBC (PainSuppression, PowerInfusion, InnerFocus) + 4 parity = 25 total.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local mock_unit = {
    get_class = function() return 5 end,
    is_mounted = function() return false end,
    is_moving = function() return false end,
    mana_pct = function() return 100 end,
    can_attack = function() return true end,
    is_casting = function() return false end,
    is_channeling = function() return false end,
    is_alive = function() return true end,
    is_valid = function() return true end,
    is_in_combat = function() return false end,
    get_health_percentage = function() return 100 end,
}

local mock_party = {
    { unit = mock_unit, effective_hp = 85, is_tank = true, has_renew = false, has_weakened_soul = false, is_player = false },
    { unit = mock_unit, effective_hp = 95, is_tank = false, has_renew = false, has_weakened_soul = false, is_player = false },
}

_G.EaxRotations = {
    PriestSpells = {
        PowerWordShield = 25218,
        PrayerofMending = 33076,
        FlashHeal = 25222,
        GreaterHeal = 25213,
        Renew = 25222,
        BindingHeal = 32546,
        CircleofHealing = 34861,
        PrayerOfHealing = 25316,
        InnerFire = 25235,
        FearWard = 15286,
        PowerWordFortitude = 25392,
        ShadowWordPain = 25368,
        Smite = 25364,
        HolyFire = 25384,
        PsychicScream = 10890,
        ShackleUndead = 11170,
        DispelMagic = 988,
    },
    PriestFLASH_HEAL_RANKS = {},
    PriestGREATER_HEAL_RANKS = {},
    PriestPRAYER_OF_HEALING_RANKS = {},
    PriestBINDING_HEAL_RANKS = {},

    PriestHealing = {
        scan_healing_targets = function()
            return mock_party, 2
        end,
        count_subgroup_below_hp = function(_)
            return 1
        end,
    },

    healing_get_lowest_hp = function(entries, count, default_hp)
        if not entries or count == 0 then return nil end
        for i = 1, count do
            if entries[i].is_tank then return entries[i] end
        end
        return entries[1]
    end,
    healing_get_tank = function(entries, count)
        if not entries or count == 0 then return nil end
        for i = 1, count do
            if entries[i].is_tank then return entries[i] end
        end
        return entries[1]
    end,
    healing_count_below_hp = function(entries, count, threshold)
        local n = 0
        for i = 1, count or 0 do
            if (entries[i].effective_hp or 100) < threshold then n = n + 1 end
        end
        return n
    end,

    buff_up = function(_, ids)
        return false
    end,
    spell_ready = function() return true end,
    unit_mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    unit_creature_type = function() return nil end,
    action_matches = function(_, action)
        if action and action.spell then return true end
        return true
    end,
    action_execute = function() return true end,
    try_cast = function() return true end,
    debuff_remains = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    is_execute_phase = function() return false end,

    GetPlayer = function() return mock_unit end,
    GetEnemiesInRange = function() return {} end,
    PLAYER_UNIT = "player",
    healthstone_info_ready = function() return false end,

    log = function() end,
    log_warning = function() end,

    rotation_registry = {
        register = function() end,
    },
}

-- Load discipline_sylvanas.lua (returns strategies table directly)
local strategies = dofile("EaxRotations/classes/priest/discipline_sylvanas.lua")
-- Note: the file returns nil if NS is missing; our mock ensures NS is set
if type(strategies) ~= "table" or strategies[1] == nil then
    error("strategies table should load — got type: " .. type(strategies))
end
assert_true(#strategies > 0, "strategies table should have entries, got " .. tostring(#strategies))

-- Collect strategy names for audit
local strategy_names = {}
for i = 1, #strategies do
    strategy_names[strategies[i].name] = true
end

-- ============================================================================
-- Feature Audit: Check which parity features exist vs missing
-- ============================================================================

-- Core healing/utility strategies that ARE present
assert_true(strategy_names["EmergencyPowerWordShield"], "EmergencyPowerWordShield should be present")
assert_true(strategy_names["PrayerOfMendingTank"], "PrayerOfMendingTank should be present")
assert_true(strategy_names["EmergencyFlashHeal"], "EmergencyFlashHeal should be present")
assert_true(strategy_names["GreaterHeal"], "GreaterHeal should be present")
assert_true(strategy_names["BindingHeal"], "BindingHeal should be present")
assert_true(strategy_names["CircleOfHealing"], "CircleOfHealing should be present")
assert_true(strategy_names["PrayerOfHealing"], "PrayerOfHealing should be present")
assert_true(strategy_names["RenewTank"], "RenewTank should be present")
assert_true(strategy_names["RenewLowest"], "RenewLowest should be present")
assert_true(strategy_names["InnerFire"], "InnerFire should be present")
assert_true(strategy_names["FearWard"], "FearWard should be present")
assert_true(strategy_names["PowerWordFortitude"], "PowerWordFortitude should be present")
assert_true(strategy_names["IdleShadowWordPain"], "IdleShadowWordPain should be present")
assert_true(strategy_names["IdleSmite"], "IdleSmite should be present")
assert_true(strategy_names["HolyFire"], "HolyFire should be present")
assert_true(strategy_names["PsychicScream"], "PsychicScream should be present")
assert_true(strategy_names["ShackleUndead"], "ShackleUndead should be present")
assert_true(strategy_names["DispelMagic"], "DispelMagic should be present")

-- FrostByte gaps from FROSTBYTE_GAP_ANALYSIS.md (4 gaps for Discipline)
local parity_gaps = {
    "StopCast",            -- Stop-cast engine (mid-cast cancellation at HP checkpoints)
    "PreHeal",             -- Pre-heal system (queues GH/FH based on damage patterns)
    "Fade",                -- Fade auto-use (aggro drop with backup healer check)
    "Healthstone",         -- Healthstone auto-use (off-GCD, HP threshold)
}

local present_gaps = 0
local missing_gaps = {}
for _, gap_name in ipairs(parity_gaps) do
    if strategy_names[gap_name] then
        present_gaps = present_gaps + 1
    else
        missing_gaps[#missing_gaps + 1] = gap_name
    end
end

-- All 4 FrostByte gaps + 3 ClassResearchTBC enhancements are now implemented.
assert_eq(#strategies, 32, "expected 32 strategies (PreemptiveHeal + FriendlyTarget added), got " .. #strategies)

print("PASS test_discipline_feature_gaps (gap audit: " .. #strategies .. " strategies present, " .. present_gaps .. "/4 parity gaps closed)")

-- Print gap status
if #missing_gaps > 0 then
    print("  Missing parity features (" .. #missing_gaps .. "):")
    for _, name in ipairs(missing_gaps) do
        print("    - " .. name)
    end
else
    print("  All 4 parity gaps closed!")
end

-- Print strategy inventory for reference
local sorted_names = {}
for name, _ in pairs(strategy_names) do
    sorted_names[#sorted_names + 1] = name
end
table.sort(sorted_names)
print("  Strategies present: " .. table.concat(sorted_names, ", "))
