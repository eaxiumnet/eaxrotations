-- Regression test: warlock vanilla specs Pattern 14 nil-guards.
-- Covers: affliction_vanilla, demonology_vanilla, destruction_vanilla, leveling_vanilla.
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
    WarlockSpells = {
        AmplifyCurse = 18288, BacklashShadowBolt = 34936, Conflagrate = 17962,
        Corruption = 172, CreateHealthstone = 6201, CreateSoulstone = 693,
        CurseOfAgony = 980, CurseOfDoom = 603, CurseOfElements = 1490,
        CurseOfExhaustion = 18223, CurseOfTongues = 1714, CurseOfWeakness = 702,
        DarkPact = 18220, DeathCoil = 6789, DemonArmor = 706,
        DrainLife = 689, DrainSoul = 1120, Fear = 5782, FelDomination = 18708,
        HealthFunnel = 755, Healthstone = 6201, Hellfire = 1949,
        HowlOfTerror = 5484, Immolate = 348, LifeTap = 1454,
        RainOfFire = 5740, SearingPain = 17935, ShadowWard = 6229,
        Shadowburn = 17877, ShadowBolt = 686, SiphonLife = 18265,
        SoulFire = 6353, SpellLock = 19244, SummonFelhunter = 691,
        SummonImp = 688, SummonSuccubus = 712, SummonVoidwalker = 697,
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
    mana_pct = function() return 80 end,
    has_pet = function() return false end,
    pet_health_pct = function() return 100 end,
    GetPet = function() return nil end,
    unit_health_pct = function() return 100 end,
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

print("=== test_warlock_vanilla_nil_guards ===")

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

local base_ctx = { in_combat = true, target = {}, me = {}, settings = {}, hp = 80, mana_pct = 80 }

-- Affliction
test_spec("EaxRotations/classes/warlock/affliction_vanilla.lua", "affliction_vanilla",
    { "DamagePotion", "PetDefensive", "PetPassive", "PetAggressive", "DeathCoilSurvival", "Healthstone", "NightfallProc", "DrainLife", "CorruptionDoT", "SiphonLife", "CurseOfDoom", "CurseOfAgony", "ImmolateDoT", "AmplifyCurse", "DrainSoulExecute", "PreCombatPull", "ShadowBoltFiller", "LifeTap", "DarkPact", "ManaPotion", "RacialBerserking", "RacialBloodFury", "PvP_Fear", "PvP_HowlOfTerror" },
    base_ctx)

-- Demonology
test_spec("EaxRotations/classes/warlock/demonology_vanilla.lua", "demonology_vanilla",
    { "DamagePotion", "PetDefensive", "PetPassive", "PetAggressive", "DeathCoilSurvival", "Healthstone", "FelDomination", "HealthFunnel", "CorruptionDoT", "SiphonLife", "CurseOfDoom", "CurseOfAgony", "CurseOfElements", "ImmolateDoT", "DrainSoulExecute", "ShadowBoltFiller", "LifeTap", "DarkPact", "DrainLife", "ManaPotion", "PvP_Fear", "PvP_HowlOfTerror", "PvP_CurseExhaustion" },
    base_ctx)

-- Destruction
test_spec("EaxRotations/classes/warlock/destruction_vanilla.lua", "destruction_vanilla",
    { "DemonArmor", "ShadowWard", "CreateHealthstone", "LifeTap", "DrainLife", "HealthFunnel", "CurseOfDoom", "CurseOfAgony", "Corruption", "Immolate", "BacklashShadowBolt", "Conflagrate", "SoulFire", "Shadowburn", "SearingPain", "ShadowBolt", "RainOfFire", "Hellfire", "DeathCoil", "Fear", "SummonImp", "SummonVoidwalker", "SummonSuccubus", "SummonFelhunter", "FelDomination" },
    base_ctx)

-- Leveling
test_spec("EaxRotations/classes/warlock/leveling_vanilla.lua", "leveling_vanilla",
    { "DemonArmor", "CreateHealthstone", "CreateSoulstone", "SpellLock", "HealthFunnel", "Fear", "HowlOfTerror", "DeathCoil", "LifeTap", "Corruption", "Immolate", "CurseOfAgony", "SiphonLife", "DrainLife", "DrainSoul", "SearingPain", "ShadowBolt", "Wand" },
    base_ctx)

-- REPORT
print()
if #failures == 0 then
    print(string.format("PASS test_warlock_vanilla_nil_guards — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_warlock_vanilla_nil_guards — %d/%d passed, %d failures:", total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do print(string.format("  %d. [%s] %s", i, f.label, f.error)) end
    error(string.format("test_warlock_vanilla_nil_guards: %d failure(s)", #failures))
end
