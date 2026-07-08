-- test_hunter_vanilla_nil_guards.lua -- Hunter Vanilla-era compatibility nil-guard tests.
-- WHAT:  Hunter Vanilla-era compatibility nil-guard tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Validates nil-guard safety on all numeric state reads (Pattern 14).
-- SAFETY: Must pass after any state table change.

-- Regression test: hunter vanilla specs Pattern 14 nil-guards.
-- Covers: beast_mastery_vanilla, marksmanship_vanilla, survival_vanilla, leveling_vanilla.
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
    HunterSpells = {
        AimedShot = 19434, ArcaneShot = 3044, AspectOfTheCheetah = 13159,
        AspectOfTheHawk = 13165, BestialWrath = 19574, CallPet = 883,
        ConcussiveShot = 5116, FeignDeath = 5384, FreezingTrap = 1499,
        HuntersMark = 1430, MendPet = 136, MongooseBite = 36916,
        MultiShot = 2643, PetAggressive = 1742, PetDefensive = 1742,
        PetPassive = 1742, RapidFire = 3045, RaptorStrike = 2973,
        RevivePet = 982, ScareBeast = 1513, ScorpidSting = 3043,
        SerpentSting = 1978, TrueshotAura = 19506, ViperSting = 3034,
        Volley = 1510, WingClip = 2974, ExplosiveTrap = 8294,
        Intimidation = 19577, FeignDeathAction = 5384,
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

print("=== test_hunter_vanilla_nil_guards ===")

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

-- Beast Mastery
test_spec("EaxRotations/classes/hunter/beast_mastery_vanilla.lua", "beast_mastery_vanilla",
    { "HealthPotion", "ManaPotion", "CallPet", "RevivePet", "PetDefensive", "PetPassive", "PetAggressive", "AspectOfTheHawk_OOC", "MendPet", "HuntersMark", "FreezingTrap", "BestialWrath", "RapidFire", "FeignDeath", "MultiShot", "SerpentStingRefresh", "ArcaneShot", "SerpentSting", "Trinket", "ConcussiveShot" },
    base_ctx)

-- Marksmanship
test_spec("EaxRotations/classes/hunter/marksmanship_vanilla.lua", "marksmanship_vanilla",
    { "HealthPotion", "ManaPotion", "MendPet", "CallPet", "RevivePet", "PetDefensive", "PetPassive", "PetAggressive", "AspectOfTheHawk", "FreezingTrap", "HuntersMark", "RapidFire", "InCombatAimedShot", "AimedShotPrepull", "FeignDeath", "LevelingArcaneShot", "LevelingSting", "MultiShot", "ArcaneShot", "ViperSting" },
    base_ctx)

-- Survival
test_spec("EaxRotations/classes/hunter/survival_vanilla.lua", "survival_vanilla",
    { "HealthPotion", "ManaPotion", "PetDefensive", "PetPassive", "PetAggressive", "MendPet", "CallPet", "RevivePet", "AspectOfTheHawk", "FreezingTrap", "HuntersMark", "RapidFire", "ExplosiveTrap", "FeignDeath", "ConcussiveShot", "ScorpidSting", "Volley", "RaptorStrike", "WingClip", "LevelingArcaneShot" },
    base_ctx)

-- Leveling
test_spec("EaxRotations/classes/hunter/leveling_vanilla.lua", "leveling_vanilla",
    { "AspectHawk", "AspectCheetah", "CallPet", "HuntersMark", "RapidFire", "AimedShot", "MendPet", "MongooseBite", "RaptorStrike", "ConcussiveShot", "WingClip", "ScareBeast", "FreezingTrap", "FeignDeath", "SerpentSting", "ArcaneShot", "MultiShot" },
    base_ctx)

-- REPORT
print()
if #failures == 0 then
    print(string.format("PASS test_hunter_vanilla_nil_guards — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_hunter_vanilla_nil_guards — %d/%d passed, %d failures:", total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do print(string.format("  %d. [%s] %s", i, f.label, f.error)) end
    error(string.format("test_hunter_vanilla_nil_guards: %d failure(s)", #failures))
end
