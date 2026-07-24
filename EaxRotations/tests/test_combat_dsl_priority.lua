-- test_combat_dsl_priority.lua — Regression test for combat rogue DSL strategy priority order.
-- WHAT:  Verifies that declarative DSL strategies replace imperative entries
--        at the same list positions, preserving rotation priority, and that
--        DSL conditions behave equivalently for representative state inputs.
-- WHEN:  Run via EaxRotations/tests/run_rotation_tests.lua.
-- WHY:   Combat rogue is the third DSL adopter (after arms + fury) and the
--        first NON-WARRIOR spec; this guards that the DSL generalizes beyond
--        rage mechanics to energy/combo-point resources.
-- SAFETY: Self-contained; only inspects the returned strategy table.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local pass_count, test_count = 0, 0

local function assert_true(v, label)
    test_count = test_count + 1
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
    pass_count = pass_count + 1
end

local function assert_false(v, label)
    test_count = test_count + 1
    if v then error("FAIL: " .. (label or "assert_false"), 2) end
    pass_count = pass_count + 1
end

local function assert_eq(a, b, label)
    test_count = test_count + 1
    if a ~= b then error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
    pass_count = pass_count + 1
end

-- Minimal NS namespace so combat_sylvanas.lua loads without the engine.
_G.EaxRotations = {
    log = function() end,
    log_warning = function() end,
    GetPlayer = function() return {} end,
    get_setting = function(_, default) return default end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    debuff_stacks = function() return 0 end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    is_spell_learned = function() return true end,
    broken_api_throttled = function() return false end,
    is_interruptible = function() return true end,
    rotation_registry = { register = function() end },
    PLAYER_UNIT = {},
    RogueSpells = {},
}

-- Mock shared modules that combat_sylvanas requires.
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {},
    DAMAGE_POTION_IDS = {},
}
package.loaded["shared/hit_cap_tracker_sylvanas"] = {
    get_hit_cap = function() return { pct_needed = 9, rating_needed = 142 } end,
    get_expertise_cap = function() return { soft_expertise = 26, hard_expertise = 56 } end,
}
package.loaded["shared/leveling_helpers_sylvanas"] = {
    level_from_context = function(context, default) return context and context.level or default or 70 end,
    is_low_level = function(level) return level and level < 20 or false end,
}
package.loaded["shared/spec_kit_sylvanas"] = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
    define_action_for_class = function(SPELLS)
        return function(name, ids, label)
            local id = type(ids) == "table" and ids[1] or ids
            return { id = id, name = label or name, _meta = { id = id, ids = type(ids) == "table" and ids or { ids }, label = label or name },
                cast_safe = function() return true end, cooldown_remaining = function() return 0 end,
                can_cast = function() return true end, is_learned = function() return true end }
        end
    end,
    safe_state = function(raw) return raw end,
    setting = function(context, key, default) return default end,
    setting_bool = function(context, key, default) return default end,
    setting_number = function(context, key, default) return default end,
}
package.loaded["shared/stealth_helper_sylvanas"] = {
    is_stealthed_for_class = function() return false end,
    try = function() return false end,
}
package.loaded["shared/offensive_dispel_sylvanas"] = {
    find_best_dispel_target = function() return nil end,
}

local combat = require("classes/rogue/combat_sylvanas")

-- ============================================================================--
-- Priority order: the 6 DSL-converted names must sit at their original indices.
-- The full strategy list (in order) from combat_sylvanas.lua is:
--   1 HealthPotion, 2 DamagePotion, 3 Kick, 4 Stealth, 5 CheapShot, 6 Garrote,
--   7 SliceAndDice, 8 AdrenalineRush, 9 BladeFlurry, 10 Rupture,
--   11 Eviscerate, 12 Envenom, 13 ShivPurge, 14 Gouge, 15 Sprint,
--   16 Vanish, 17 Feint, 18 Blind, 19 Hemorrhage, 20 GhostlyStrike, 21 Backstab,
--   22 KidneyShot, 23 ExposeArmor, 24 SinisterStrike, 25 HitCapPriority
-- ============================================================================--
local expected_order = {
    "HealthPotion", "DamagePotion", "Kick", "Stealth", "CheapShot", "Garrote",
    "SliceAndDice", "AdrenalineRush", "BladeFlurry", "Rupture",
    "Eviscerate", "Envenom", "ShivPurge", "Gouge", "Sprint",
    "Vanish", "Feint", "Blind", "Hemorrhage", "GhostlyStrike", "Backstab",
    "KidneyShot", "ExposeArmor", "SinisterStrike", "HitCapPriority",
}

local actual_order = {}
for i = 1, #combat.strategies do
    actual_order[#actual_order + 1] = combat.strategies[i].name
end

assert_eq(#actual_order, #expected_order, "strategy count matches expected")

for i = 1, #expected_order do
    assert_eq(actual_order[i], expected_order[i], "strategy at index " .. i .. " is " .. expected_order[i])
end

-- Explicitly verify the 6 DSL-converted names sit at their original indices.
local dsl_positions = {
    SliceAndDice = 7,
    Eviscerate = 11,
    Envenom = 12,
    Gouge = 14,
    Sprint = 15,
    SinisterStrike = 24,
}

for name, expected_index in pairs(dsl_positions) do
    assert_eq(actual_order[expected_index], name, name .. " is at expected index " .. expected_index)
end

local function find_strategy(name)
    for i = 1, #combat.strategies do
        if combat.strategies[i].name == name then return combat.strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- DSL condition equivalence checks (explicit state → no build_state needed)
-- ============================================================================

-- SliceAndDice: ready + (missing OR needs refresh) + >= 2 CP
local snd = find_strategy("SliceAndDice")
assert_false(snd.matches({}, { slice_and_dice_ready = false, has_snd = false, snd_needs_refresh = false, combo_points = 3 }),
    "SliceAndDice does not match when not ready")
assert_false(snd.matches({}, { slice_and_dice_ready = true, has_snd = false, snd_needs_refresh = false, combo_points = 1 }),
    "SliceAndDice does not match below 2 combo points")
assert_true(snd.matches({}, { slice_and_dice_ready = true, has_snd = false, snd_needs_refresh = false, combo_points = 3 }),
    "SliceAndDice matches when missing with 2+ CP")
assert_true(snd.matches({}, { slice_and_dice_ready = true, has_snd = true, snd_needs_refresh = true, combo_points = 3 }),
    "SliceAndDice matches when refresh needed")
assert_false(snd.matches({}, { slice_and_dice_ready = true, has_snd = true, snd_needs_refresh = false, combo_points = 3 }),
    "SliceAndDice does not match when SnD fresh")

-- Eviscerate: ready + not pooling + energy >= 35 + CP threshold + no Envenom deferral
local evisc = find_strategy("Eviscerate")
assert_false(evisc.matches({}, { eviscerate_ready = false, energy_pool_finisher = false, energy = 50, combo_points = 5, deadly_poison_stacks = 0, envenom_ready = false }),
    "Eviscerate does not match when not ready")
assert_false(evisc.matches({ level = 70 }, { eviscerate_ready = true, energy_pool_finisher = true, energy = 20, combo_points = 5, deadly_poison_stacks = 0, envenom_ready = false }),
    "Eviscerate does not match when pooling energy")
assert_false(evisc.matches({ level = 70 }, { eviscerate_ready = true, energy_pool_finisher = false, energy = 30, combo_points = 5, deadly_poison_stacks = 0, envenom_ready = false }),
    "Eviscerate does not match below 35 energy")
assert_false(evisc.matches({ level = 70 }, { eviscerate_ready = true, energy_pool_finisher = false, energy = 50, combo_points = 4, deadly_poison_stacks = 0, envenom_ready = false }),
    "Eviscerate does not match below 5 CP at endgame level")
assert_true(evisc.matches({ level = 70 }, { eviscerate_ready = true, energy_pool_finisher = false, energy = 50, combo_points = 5, deadly_poison_stacks = 0, envenom_ready = false }),
    "Eviscerate matches at 5 CP with energy and no poison deferral")
assert_false(evisc.matches({ level = 70 }, { eviscerate_ready = true, energy_pool_finisher = false, energy = 50, combo_points = 5, deadly_poison_stacks = 5, envenom_ready = true }),
    "Eviscerate defers to Envenom when 5 deadly poison stacks up")
-- Leveling: 4 CP is enough
assert_true(evisc.matches({ level = 15, is_leveling = true }, { eviscerate_ready = true, energy_pool_finisher = false, energy = 50, combo_points = 4, deadly_poison_stacks = 0, envenom_ready = false }),
    "Eviscerate matches at 4 CP when leveling")

-- Envenom: ready + not pooling + energy >= 35 + 5 CP + 5 deadly poison stacks
local env = find_strategy("Envenom")
assert_false(env.matches({}, { envenom_ready = false, energy_pool_finisher = false, energy = 50, combo_points = 5, deadly_poison_stacks = 5 }),
    "Envenom does not match when not ready")
assert_false(env.matches({}, { envenom_ready = true, energy_pool_finisher = false, energy = 50, combo_points = 4, deadly_poison_stacks = 5 }),
    "Envenom does not match below 5 CP")
assert_false(env.matches({}, { envenom_ready = true, energy_pool_finisher = false, energy = 50, combo_points = 5, deadly_poison_stacks = 4 }),
    "Envenom does not match below 5 deadly poison stacks")
assert_true(env.matches({}, { envenom_ready = true, energy_pool_finisher = false, energy = 50, combo_points = 5, deadly_poison_stacks = 5 }),
    "Envenom matches with all conditions met")

-- SinisterStrike: ready + not energy_low + energy spending gate
local ss = find_strategy("SinisterStrike")
assert_false(ss.matches({ energy = 40 }, { sinister_strike_ready = false, energy_low = false }),
    "SinisterStrike does not match when not ready")
assert_false(ss.matches({ energy = 40 }, { sinister_strike_ready = true, energy_low = true }),
    "SinisterStrike does not match when energy_low flag set")
assert_true(ss.matches({ energy = 90 }, { sinister_strike_ready = true, energy_low = false }),
    "SinisterStrike matches at high energy (spend gate passes)")

-- Gouge: readiness only
local gouge = find_strategy("Gouge")
assert_false(gouge.matches({}, { gouge_ready = false }),
    "Gouge does not match when not ready")
assert_true(gouge.matches({}, { gouge_ready = true }),
    "Gouge matches when ready")

-- Sprint: in combat + ready
local sprint = find_strategy("Sprint")
assert_false(sprint.matches({}, { in_combat = false, sprint_ready = true }),
    "Sprint does not match out of combat")
assert_false(sprint.matches({}, { in_combat = true, sprint_ready = false }),
    "Sprint does not match when not ready")
assert_true(sprint.matches({}, { in_combat = true, sprint_ready = true }),
    "Sprint matches in combat when ready")

-- Kick: interrupt gated on setting + combat + target + kick_ready + interruptible.
-- (InterruptManager is absent in this harness, so it uses the state fallback path;
-- the spec_kit mock always returns the setting default, so use_interrupt stays on.)
local kick = find_strategy("Kick")
assert_false(kick.matches({ target = {} }, { in_combat = false, kick_ready = true, target_casting_interruptible = true }),
    "Kick does not match out of combat")
assert_false(kick.matches({ target = nil }, { in_combat = true, kick_ready = true, target_casting_interruptible = true }),
    "Kick does not match without a target")
assert_false(kick.matches({ target = {} }, { in_combat = true, kick_ready = false, target_casting_interruptible = true }),
    "Kick does not match when not ready")
assert_false(kick.matches({ target = {} }, { in_combat = true, kick_ready = true, target_casting_interruptible = false }),
    "Kick does not match when target cast is not interruptible")
assert_true(kick.matches({ target = {} }, { in_combat = true, kick_ready = true, target_casting_interruptible = true }),
    "Kick matches when ready and target is casting an interruptible spell")

print(string.format("PASS test_combat_dsl_priority (%d/%d assertions passed)", pass_count, test_count))
