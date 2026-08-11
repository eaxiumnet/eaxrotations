-- test_sod_mage_paladin_priest.lua -- Focused Task 5 SoD rotation coverage.
-- WHAT: verifies five native Mage, Paladin, and Priest registrations and priorities.
-- WHEN: run after the shared SoD descriptor/runtime contracts are available.
-- WHY: locks pinned-source DPS, tank, and healer behavior at the production boundary.
-- SAFETY: deterministic context and cast spies; no game client or external writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local function strategy(rotation, name)
    for i = 1, #rotation.strategies do
        if rotation.strategies[i].name == name then return rotation.strategies[i] end
    end
    error("missing strategy " .. name, 2)
end

local rune_ids = {
    400610, 400573, 425124, 428878, 428739, 440802, 412532, 401502,
    458318, 407669, 407632, 440658, 407778, 407676,
    402174, 425204, 402668, 402799, 401977, 431655,
}
local equipped = {}
for i = 1, #rune_ids do equipped[rune_ids[i]] = true end

local fixture = require("tests/sod_runtime_fixture")
local NS, context, ok = fixture.boot("Vanilla", {
    runtime_mode = "sod",
    sod_phase = 8,
}, function() return equipped end)
assert_eq(ok, true, "SoD context must build")

context.is_sod = true
context.in_combat = true
context.target = {}
context.hp = 100
context.mana_pct = 100

local modules = {
    mage = { path = "classes/mage/dps_mage_sod", registry = "dps_mage" },
    protection = { path = "classes/paladin/protection_sod", registry = "protection" },
    retribution = { path = "classes/paladin/retribution_sod", registry = "retribution" },
    healing = { path = "classes/priest/healing_sod", registry = "healing" },
    shadow = { path = "classes/priest/shadow_sod", registry = "shadow" },
}

for _, entry in pairs(modules) do
    package.loaded[entry.path] = nil
    entry.rotation = require(entry.path)
    assert_eq(type(entry.rotation), "table", entry.path .. " loads")
    assert_eq(NS.rotation_registry.playstyles[entry.registry], entry.rotation.strategies,
        entry.registry .. " registers")
end

assert_eq(modules.mage.rotation.strategies[1].name, "Evocation", "Mage source priority starts with mana recovery")
context.mana_pct = 10
assert_eq(strategy(modules.mage.rotation, "Evocation").matches(context, modules.mage.rotation.build_state(context)), true,
    "Mage Evocation at low mana")
context.mana_pct = 100
assert_eq(strategy(modules.mage.rotation, "FrozenOrb").matches(context, modules.mage.rotation.build_state(context)), true,
    "Mage equipped Frozen Orb")

-- The dispatcher now produces context.hp_pct (SoD context wiring unit
-- 2026-08-11, shared/sod_context_sylvanas.lua aliases hp_pct <- hp), so
-- hand-mutated hp must keep hp_pct in sync (same as mana_pct below).
context.hp = 8
context.hp_pct = 8
assert_eq(modules.protection.rotation.strategies[1].name, "LayOnHands", "tank emergency is first")
assert_eq(strategy(modules.protection.rotation, "LayOnHands").matches(context,
    modules.protection.rotation.build_state(context)), true, "tank Lay on Hands gate")
context.hp = 35
context.hp_pct = 35
assert_eq(strategy(modules.protection.rotation, "DivineProtection").matches(context,
    modules.protection.rotation.build_state(context)), true, "tank mitigation gate")
context.hp = 100
context.hp_pct = 100
assert_eq(strategy(modules.protection.rotation, "HolyShield").matches(context,
    modules.protection.rotation.build_state(context)), true, "tank Holy Shield refresh")
local original_buff_points = NS.buff_points
NS.buff_points = function() return { 4 } end
assert_eq(strategy(modules.protection.rotation, "HolyShield").matches(context,
    modules.protection.rotation.build_state(context)), false, "tank preserves healthy Holy Shield charges")
NS.buff_points = original_buff_points

assert_eq(modules.retribution.rotation.strategies[1].name, "DivineStorm", "Retribution p8 Exodin priority")
assert_eq(strategy(modules.retribution.rotation, "DivineStorm").matches(context,
    modules.retribution.rotation.build_state(context)), true, "Retribution Divine Storm rune")

local ally = {}
context.lowest = { unit = ally, effective_hp = 32, has_weakened_soul = false }
local healing_state = modules.healing.rotation.build_state(context)
assert_eq(modules.healing.rotation.strategies[1].name, "Penance", "healer emergency Penance is first")
assert_eq(strategy(modules.healing.rotation, "Penance").matches(context, healing_state), true,
    "healer selects injured ally")
assert_eq(modules.healing.rotation.actions.Penance.rune_id, 402174, "Penance uses the engraved rune ID")
assert_eq(modules.protection.rotation.actions.DivineProtection.rune_id, 458318,
    "Divine Protection uses Malleable Protection rune ID")

context.void_plague_remains = 0
context.shadow_word_pain_remains = 0
assert_eq(modules.shadow.rotation.strategies[1].name, "VoidPlague", "Shadow phase 6 DoT priority")
assert_eq(strategy(modules.shadow.rotation, "VoidPlague").matches(context,
    modules.shadow.rotation.build_state(context)), true, "Shadow applies Void Plague")
local original_debuff_remains = NS.debuff_remains
NS.debuff_remains = function(_, ids) return ids[1] == 425204 and 12 or 0 end
context.void_plague_remains = nil
context.shadow_word_pain_remains = nil
assert_eq(strategy(modules.shadow.rotation, "VoidPlague").matches(context,
    modules.shadow.rotation.build_state(context)), false, "Shadow preserves active Void Plague")
NS.debuff_remains = original_debuff_remains

local cast_action
local cast_target
local original_try_cast = NS.try_cast
NS.try_cast = function(action, target)
    cast_action = action
    cast_target = target
    return true
end
assert_eq(strategy(modules.healing.rotation, "Penance").execute(context), true,
    "healer execute succeeds")
assert_eq(cast_action, modules.healing.rotation.actions.Penance.action, "execute uses resolved Penance action")
assert_eq(cast_target, ally, "execute uses selected healer target")
NS.try_cast = original_try_cast

print("PASS test_sod_mage_paladin_priest (five registrations, DPS/tank/healer priorities, execute target)")
