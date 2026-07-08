-- test_rogue_vanilla_nil_guards.lua -- Rogue Vanilla-era compatibility nil-guard tests.
-- WHAT:  Rogue Vanilla-era compatibility nil-guard tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Validates nil-guard safety on all numeric state reads (Pattern 14).
-- SAFETY: Must pass after any state table change.

-- Regression test: rogue vanilla specs Pattern 14 nil-guards.
-- Covers: combat_vanilla, assassination_vanilla, leveling_vanilla.
-- subtlety_vanilla has its own dedicated test file.
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local failures, total_tests, total_passed = {}, 0, 0

local function expect_no_crash(label, fn)
    total_tests = total_tests + 1
    local ok, err = pcall(fn)
    if ok then total_passed = total_passed + 1
    else failures[#failures + 1] = { label = label, error = err } end
end

_G.EaxRotations = {
    action_matches = function() return true end,
    action_execute = function() return true end,
    RogueSpells = {
        AdrenalineRush = 13750, Ambush = 8676, Backstab = 53, Blind = 2094,
        BladeFlurry = 13877, CheapShot = 1833, ColdBlood = 14177, DeadenPoison = 27866,
        Evasion = 5277, Eviscerate = 2098, ExposeArmor = 8647, Feint = 1966,
        Garrote = 703, GhostlyStrike = 14278, Gouge = 1776, Hemorrhage = 16511,
        Kick = { 1766 }, KidneyShot = 408, Premeditation = 14183, Preparation = 14185,
        Rupture = 1943, Sap = 6770, SinisterStrike = 1752, SliceAndDice = 5171,
        Sprint = 2983, Stealth = 1784, ThistleTea = 7676, Vanish = 1856,
        Riposte = 14251,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return nil end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    debuff_stacks = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    has_player_buff = function() return false end,
    buff_stacks = function() return 0 end,
    has_form = function() return false end,
    is_vanilla = function() return true end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    time_now = function() return 0 end,
    setting = function(ctx, key, default)
        local s = ctx and ctx.settings
        if s and s[key] ~= nil then return s[key] end return default end,
    same_unit = function() return false end,
    energy_pct = function() return 100 end,
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {}, MANA_POTION_IDS = {} }
package.loaded["shared/tbc_data_sylvanas"] =
    { ITEMS = { healthstones = {}, potions = {} }, SPELLS = {} }
package.loaded["shared/leveling_sylvanas"] = {
    create_context_guard = function() return function() return true end end,
    build_common_state = function() end,
    create_wand_matches = function() return function() return false end end,
    execute_wand = function() return false end,
}

print("=== test_rogue_vanilla_nil_guards ===")

local function find_in(strats, name)
    for i = 1, #strats do if strats[i].name == name then return strats[i] end end
    return nil
end

local function test_spec(path, spec_name, strategy_names, ctx, mock_state)
    local strats = dofile(path)
    if type(strats) == "table" and strats.strategies then strats = strats.strategies end
    assert_true(type(strats) == "table", spec_name .. " should load")
    local st = mock_state or {}
    for _, name in ipairs(strategy_names) do
        local s = find_in(strats, name)
        if s then
            expect_no_crash(spec_name .. ": " .. name .. " with minimal context", function()
                return s.matches(ctx, st)
            end)
        end
    end
end

local base_ctx = { in_combat = true, target = { is_casting = function() return false end }, me = {}, settings = {}, hp = 80 }
local rogue_state = { energy = 60, combo = 3, combo_points = 3, hp = 80,
    rupture_remains = 0, energy_pool_finisher = false,
    slice_dice_active = false, snd_needs_refresh = false, snd_remains = 0 }

-- Combat
test_spec("EaxRotations/classes/rogue/combat_vanilla.lua", "combat_vanilla",
    { "HealthPotion", "DamagePotion", "Stealth", "AdrenalineRush", "BladeFlurry", "SliceAndDice", "Rupture", "Eviscerate", "Kick", "Gouge", "Sprint", "Vanish", "Feint", "Hemorrhage", "GhostlyStrike", "Backstab", "KidneyShot", "ExposeArmor", "SinisterStrike" },
    base_ctx, rogue_state)

-- Assassination
test_spec("EaxRotations/classes/rogue/assassination_vanilla.lua", "assassination_vanilla",
    { "HealthPotion", "DamagePotion", "EvasionDefense", "HealingItem", "VanishReopen", "KickInterrupt", "ColdBloodEviscerate", "SliceAndDice", "RuptureBleed", "KidneyShotCC", "ThistleTea", "LevelingSinisterStrike", "EviscerateFallback", "ExposeArmor", "Stealth", "GarroteOpen", "FeintAoE" },
    base_ctx, rogue_state)

-- Leveling
test_spec("EaxRotations/classes/rogue/leveling_vanilla.lua", "leveling_vanilla",
    { "Stealth", "Ambush", "Garrote", "Kick", "Gouge", "Vanish", "Evasion", "Sprint", "Blind", "ThistleTea", "ColdBlood", "AdrenalineRush", "BladeFlurry", "SliceAndDice", "Rupture", "Sap", "Eviscerate", "ExposeArmor", "KidneyShot", "SinisterStrike" },
    base_ctx, rogue_state)

-- REPORT
print()
if #failures == 0 then
    print(string.format("PASS test_rogue_vanilla_nil_guards — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_rogue_vanilla_nil_guards — %d/%d passed, %d failures:", total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do print(string.format("  %d. [%s] %s", i, f.label, f.error)) end
    error(string.format("test_rogue_vanilla_nil_guards: %d failure(s)", #failures))
end
