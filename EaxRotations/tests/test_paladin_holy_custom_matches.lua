-- unit tests for paladin_holy_sylvanas custom matches functions.

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
_G.EaxRotations = {
    PaladinSpells = {
        DivineFavor = 20216,
        HolyShock = 20473,
        FlashOfLight = 19750,
        HolyLight = 635,
        AvengingWrath = 31884,
    },
    PLAYER_UNIT = {},
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    spell_ready = function(spell, target, opts)
        return true
    end,
    has_player_buff = function(buff_list)
        return false
    end,
    healing_get_lowest_hp = function(entries, count, threshold)
        return entries and entries[1] or nil
    end,
    healing_get_tank = function(entries, count)
        return nil
    end,
    log = function() end,
    gate_overheal = function() return false end,
    buff_remains = function(unit, ids) return 0 end,
    rotation_registry = {
        register = function() end,
    },
}

-- Mock healing module
local mock_healing = {
    scan_healing_targets = function()
        return {}, 0
    end,
    select_heal = function(context, state, target)
        return { spell = 19750, label = "FlashOfLight" }
    end,
}
package.loaded["classes/paladin/healing_sylvanas"] = mock_healing

local strategies = dofile("EaxRotations/classes/paladin/holy_sylvanas.lua")
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
-- DivineFavor: only when lowest HP <= 45%
-- ============================================================================

local divine_favor = find_strategy("DivineFavor")

-- High HP -> should NOT match
action_calls = {}
local ctx_df_high = {
    settings = {},
}
assert_false(divine_favor.matches(ctx_df_high, { lowest = { effective_hp = 60 } }), "DivineFavor should not match when lowest HP > 45%")

-- Low HP -> should match
action_calls = {}
local ctx_df_low = {
    settings = {},
}
assert_true(divine_favor.matches(ctx_df_low, { lowest = { effective_hp = 30, unit = {} } }), "DivineFavor should match when lowest HP <= 45%")

-- No lowest -> should NOT match
action_calls = {}
assert_false(divine_favor.matches({}, { lowest = nil }), "DivineFavor should not match without lowest")

-- ============================================================================
-- HolyShock: only when lowest HP <= emergency_hp OR moving
-- ============================================================================

local holy_shock = find_strategy("HolyShock")

-- High HP, not moving -> should NOT match
action_calls = {}
local ctx_hs_high = {
    settings = { holy_shock_hp = 40 },
    is_moving = false,
}
assert_false(holy_shock.matches(ctx_hs_high, { lowest = { effective_hp = 60, unit = {} } }), "HolyShock should not match when HP > threshold and not moving")

-- Low HP -> should match
action_calls = {}
local ctx_hs_low = {
    settings = { holy_shock_hp = 40 },
    is_moving = false,
}
assert_true(holy_shock.matches(ctx_hs_low, { lowest = { effective_hp = 30, unit = {} } }), "HolyShock should match when HP <= threshold")

-- Moving, high HP -> should match
action_calls = {}
local ctx_hs_move = {
    settings = { holy_shock_hp = 40 },
    is_moving = true,
}
assert_true(holy_shock.matches(ctx_hs_move, { lowest = { effective_hp = 60, unit = {} } }), "HolyShock should match when moving")

-- No lowest -> should NOT match
action_calls = {}
assert_false(holy_shock.matches({}, { lowest = nil }), "HolyShock should not match without lowest")

-- ============================================================================
-- SmartHeal: only when a heal is selected and spell ready
-- ============================================================================

local smart_heal = find_strategy("SmartHeal")

-- No lowest -> should NOT match
action_calls = {}
assert_false(smart_heal.matches({}, { lowest = nil }), "SmartHeal should not match without lowest")

-- Lowest exists, heal selected -> should match
action_calls = {}
local ctx_sh = {
    settings = {},
}
assert_true(smart_heal.matches(ctx_sh, { lowest = { effective_hp = 50, unit = {} } }), "SmartHeal should match when lowest exists and heal selected")

-- ============================================================================
-- AvengingWrathHeavyHealing: +20% healing burst (3-min CD). Only in combat + a
-- heavy-healing window + setting enabled + target not about to die.
-- ============================================================================

local aw = find_strategy("AvengingWrathHeavyHealing")

-- Setting disabled -> should NOT match
assert_false(aw.matches({ in_combat = true, settings = { holy_avenging_wrath = false } }, { heavy_healing = true }), "AvengingWrath should not match when setting disabled")

-- Out of combat -> should NOT match (even with heavy_healing)
assert_false(aw.matches({ in_combat = false, settings = {} }, { heavy_healing = true }), "AvengingWrath should not match out of combat")

-- In combat but no heavy-healing window -> should NOT match
assert_false(aw.matches({ in_combat = true, settings = {} }, { heavy_healing = false }), "AvengingWrath should not match without a heavy-healing window")

-- In combat + heavy_healing + setting default + no ttd -> should match
assert_true(aw.matches({ in_combat = true, settings = {} }, { heavy_healing = true }), "AvengingWrath should match in combat + heavy_healing (setting default true)")

-- Target about to die (ttd < 15) -> should NOT match (don't waste 3-min CD)
assert_false(aw.matches({ in_combat = true, settings = {}, ttd_known = true, ttd = 10 }, { heavy_healing = true }), "AvengingWrath should not match when ttd < 15")

-- ============================================================================
-- LightGraceChain: refresh LG before it expires
-- ============================================================================

local lg_chain = find_strategy("LightGraceChain")

-- Setting disabled -> should NOT match
assert_false(lg_chain.matches({ in_combat = true, settings = { holy_lg_chain_enabled = false } }, { lights_grace_remains = 2, tank = { unit = {}, deficit = 1000 } }), "LGChain should not match when disabled")

-- LG not active -> should NOT match
assert_false(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 0, tank = { unit = {}, deficit = 1000 } }), "LGChain should not match without LG")

-- LG expires in >=2.5s -> should NOT match
assert_false(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 3, tank = { unit = {}, deficit = 1000 } }), "LGChain should not match when LG >= 2.5s")

-- Out of combat -> should NOT match
assert_false(lg_chain.matches({ in_combat = false, settings = {} }, { lights_grace_remains = 2, tank = { unit = {}, deficit = 1000 } }), "LGChain should not match out of combat")

-- No tank -> should NOT match
assert_false(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 2, tank = nil }), "LGChain should not match without tank")

-- Tank with zero deficit -> should NOT match
assert_false(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 2, tank = { unit = {}, deficit = 0 } }), "LGChain should not match when tank full")

-- Valid: LG active, <2.5s, in combat, tank with deficit -> should match
assert_true(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 2, tank = { unit = {}, deficit = 1000 } }), "LGChain should match in valid conditions")

-- Valid edge: LG at 0.1s -> should match
assert_true(lg_chain.matches({ in_combat = true, settings = {} }, { lights_grace_remains = 0.1, tank = { unit = {}, deficit = 500 } }), "LGChain should match at 0.1s remaining")

print("PASS test_paladin_holy_custom_matches")
