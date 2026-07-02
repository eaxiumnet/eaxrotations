-- test_holy_lg_chaining.lua — Holy Paladin Light's Grace Chain validation.
-- WHAT:  verifies LightGraceChain strategy gating.
-- WHEN:  regression guard after holy_sylvanas.lua LG chain refactor.
-- WHY:   LG chain must fire <2.5s, skip >2.5s, skip OOC, skip without tank.
-- SAFETY: mocks NS minimally; bypasses build_state with crafted state tables.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local _captured_strategies
_G.EaxRotations = {
    PaladinSpells = {
        DivineFavor = 20216,
        HolyShock = 20473,
        FlashOfLight = 19750,
        HolyLight = 635,
        AvengingWrath = 31884,
    },
    PLAYER_UNIT = {},
    spell_ready = function() return true end,
    has_player_buff = function() return false end,
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
        register = function(self, spec, strategies, opts)
            _captured_strategies = strategies
        end,
    },
}

local mock_healing = {
    scan_healing_targets = function()
        return {}, 0
    end,
    select_heal = function(context, state, target)
        return { spell = 19750, label = "FlashOfLight" }
    end,
}
package.loaded["classes/paladin/healing_sylvanas"] = mock_healing
package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS = {} }

local function safe_setting(context, key, fallback)
    local ctx_settings = context and context.settings
    if type(ctx_settings) == "table" and ctx_settings[key] ~= nil then return ctx_settings[key] end
    return fallback
end

dofile("EaxRotations/classes/paladin/holy_sylvanas.lua")

local function find_strategy(name)
    for i = 1, #_captured_strategies do
        if _captured_strategies[i].name == name then return _captured_strategies[i] end
    end
    return nil
end

local lg = find_strategy("LightGraceChain")
assert_true(lg, "LightGraceChain strategy should exist")

-- C1: LG at 2.0s, in combat, tank with deficit -> match
assert_true(lg.matches({ in_combat = true, settings = {} }, {
    lights_grace_remains = 2.0,
    tank = { unit = {}, deficit = 1000 },
}), "C1: LG 2.0s in combat with tank deficit -> match")
print("  [ PASS ] C1: LG 2.0s in combat matches")

-- C2: LG at 3.0s (>2.5 threshold) -> no match
assert_false(lg.matches({ in_combat = true, settings = {} }, {
    lights_grace_remains = 3.0,
    tank = { unit = {}, deficit = 1000 },
}), "C2: LG 3.0s >= 2.5 -> no match")
print("  [ PASS ] C2: LG 3.0s does not match")

-- C3: OOC -> no match
assert_false(lg.matches({ in_combat = false, settings = {} }, {
    lights_grace_remains = 2.0,
    tank = { unit = {}, deficit = 1000 },
}), "C3: out of combat -> no match")
print("  [ PASS ] C3: OOC does not match")

-- C4: No tank -> no match
assert_false(lg.matches({ in_combat = true, settings = {} }, {
    lights_grace_remains = 2.0,
    tank = nil,
}), "C4: no tank -> no match")
print("  [ PASS ] C4: no tank does not match")

-- C5: Tank with zero deficit -> no match
assert_false(lg.matches({ in_combat = true, settings = {} }, {
    lights_grace_remains = 2.0,
    tank = { unit = {}, deficit = 0 },
}), "C5: tank full -> no match")
print("  [ PASS ] C5: tank full does not match")

-- C6: Setting disabled -> no match
assert_false(lg.matches({ in_combat = true, settings = { holy_lg_chain_enabled = false } }, {
    lights_grace_remains = 2.0,
    tank = { unit = {}, deficit = 1000 },
}), "C6: setting disabled -> no match")
print("  [ PASS ] C6: setting disabled does not match")

-- C7: LG at 0.1s edge -> match
assert_true(lg.matches({ in_combat = true, settings = {} }, {
    lights_grace_remains = 0.1,
    tank = { unit = {}, deficit = 500 },
}), "C7: LG 0.1s in combat with tank deficit -> match")
print("  [ PASS ] C7: LG 0.1s edge matches")

-- C8: LG absent (remains = 0) -> no match
assert_false(lg.matches({ in_combat = true, settings = {} }, {
    lights_grace_remains = 0,
    tank = { unit = {}, deficit = 1000 },
}), "C8: LG absent -> no match")
print("  [ PASS ] C8: LG absent does not match")

print("PASS test_holy_lg_chaining")
