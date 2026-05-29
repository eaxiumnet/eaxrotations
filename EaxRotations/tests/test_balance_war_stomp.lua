-- Feature audit for balance_sylvanas: War Stomp AoE stun and other missing FrostByte features.
-- Documents gaps in utility spells compared to FrostByte reference.

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
    DruidSpells = {
        Starfire = 25298,
        Wrath = 26986,
        Moonfire = 26988,
        InsectSwarm = 26989,
        FaerieFire = 770,
        FaerieFireFeral = 16857,
        Hurricane = 27030,
        ForceOfNature = 33831,
        Innervate = 29166,
        Rebirth = 26900,
        Thorns = 26992,
        MarkOfTheWild = 26991,
        MoonkinForm = 24858,
        Barkskin = 22812,
        RemoveCurse = 2782,
        NaturesGrasp = 26902,
        EntanglingRoots = 26986,
        Cyclone = 33786,
        WarStomp = 20549,
    },
    SPF_NAMES = {},
    debuff_remains = function(unit, debuff_id) return 0 end,
    spell_ready = function(spell, target) return true end,
    action_matches = function(ctx, act) return true end,
    spell_action = function(spell_ids, name)
        return { spell = spell_ids, name = name }
    end,
    has_player_buff = function() return false end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local result = dofile("EaxRotations/classes/druid/balance_sylvanas.lua")
assert_true(result, "strategies table should load")
local strategies = result.strategies or result
assert_true(type(strategies) == "table", "strategies table exists")

-- Collect strategy names for audit
local strategy_names = {}
for k, v in pairs(strategies) do
    if type(v) == "table" and v.name then
        strategy_names[v.name] = true
    end
end

-- ============================================================================
-- Feature Audit: Check which FrostByte features exist vs missing
-- ============================================================================

-- Present features
assert_true(strategy_names["StarfirePrimary"], "StarfirePrimary should be present")
assert_true(strategy_names["WrathFiller"], "WrathFiller should be present")
assert_true(strategy_names["MoonfireDoT"], "MoonfireDoT should be present")
assert_true(strategy_names["InsectSwarmDoT"], "InsectSwarmDoT should be present")
assert_true(strategy_names["FaerieFireDebuff"], "FaerieFireDebuff should be present")
assert_true(strategy_names["MoonkinForm"], "MoonkinForm should be present")
assert_true(strategy_names["HurricaneAoE"], "HurricaneAoE should be present")
assert_true(strategy_names["ForceOfNature"], "ForceOfNature should be present")
assert_true(strategy_names["InnervateSelf"], "InnervateSelf should be present")
assert_true(strategy_names["BarkskinDefense"], "BarkskinDefense should be present")
assert_true(strategy_names["RemoveCurse"], "RemoveCurse should be present")
assert_true(strategy_names["ManaPotion"], "ManaPotion should be present")
assert_true(strategy_names["ThornsBuff"], "ThornsBuff should be present")

-- FrostByte features (now implemented)
assert_true(strategy_names["WarStomp"], "WarStomp should be present - FrostByte feature: AoE stun on 4+ melee enemies")
assert_true(strategy_names["MarkOfTheWild"], "MarkOfTheWild should be present - FrostByte feature: party/raid buff")

print("PASS test_balance_war_stomp (gap audit: " .. #strategies .. " strategies present, 2 FrostByte gaps closed)")
