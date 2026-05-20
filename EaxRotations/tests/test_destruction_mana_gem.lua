-- Feature audit for destruction_sylvanas: Mana Gem auto-use.
-- Mana Gem auto-use at configurable threshold is a FrostByte feature gap.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
_G.EaxRotations = {
    WarlockSpells = {
        Shadowburn = 17877,
        Immolate = 348,
        Conflagrate = 17962,
        Incinerate = 29722,
        ShadowBolt = 27209,
        Corruption = 172,
        CurseOfAgony = 27218,
        CurseOfDoom = 27214,
        SearingPain = 27215,
        SoulFire = 29858,
        DeathCoil = 2894,
        Fear = 6215,
        RainOfFire = 27211,
        Hellfire = 27213,
        SeedOfCorruption = 27243,
        DrainLife = 27217,
        LifeTap = 1454,
        DarkPact = 27220,
        HealthFunnel = 30656,
        FelArmor = 28176,
        DemonArmor = 27299,
        ShadowWard = 28648,
        CreateHealthstone = 6201,
        SummonImp = 688,
        SummonVoidwalker = 697,
        SummonSuccubus = 712,
        SummonFelhunter = 691,
        SummonFelguard = 30146,
        FelDomination = 19028,
        Soulshatter = 29858,
    },
    has_item = function() return false end,
    is_execute_phase = function() return false end,
    is_item_ready = function() return false end,
    use_item_by_id = function() end,
    spell_ready = function() return false end,
    try_cast = function() return false end,
    action_matches = function(ctx, act)
        return true
    end,
    spell_action = function(spell_ids, name)
        return { spell = spell_ids, name = name }
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/warlock/destruction_sylvanas.lua")
assert_true(strategies, "strategies table should load")
assert_true(#strategies > 0, "strategies table should have entries")

-- Collect strategy names for audit
local strategy_names = {}
for i = 1, #strategies do
    strategy_names[strategies[i].name] = true
end

-- ============================================================================
-- Feature Audit: Check which FrostByte features exist vs missing
-- ============================================================================

-- Confirm core Destruction spells are present
assert_true(strategy_names["ShadowBolt"], "ShadowBolt should be present")
assert_true(strategy_names["Immolate"], "Immolate should be present")
assert_true(strategy_names["Conflagrate"], "Conflagrate should be present")
assert_true(strategy_names["Incinerate"], "Incinerate should be present")
assert_true(strategy_names["Corruption"], "Corruption should be present")
assert_true(strategy_names["CurseOfAgony"], "CurseOfAgony should be present")
assert_true(strategy_names["Shadowburn"], "Shadowburn should be present")
assert_true(strategy_names["SearingPain"], "SearingPain should be present")
assert_true(strategy_names["LifeTap"], "LifeTap should be present")
assert_true(strategy_names["DeathCoil"], "DeathCoil should be present")
assert_true(strategy_names["RainOfFire"], "RainOfFire should be present")
assert_true(strategy_names["SeedOfCorruption"], "SeedOfCorruption should be present")    -- FrostByte features now implemented
    assert_true(strategy_names["ManaGem"], "ManaGem should be present - FrostByte feature: auto-use mana items at threshold")
    assert_true(strategy_names["Soulshatter"], "Soulshatter should be present - FrostByte feature: threat management")
    
    print("PASS test_destruction_mana_gem (gap audit: " .. #strategies .. " strategies present, ManaGem + Soulshatter implemented)")
