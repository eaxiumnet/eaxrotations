-- Regression test: mage vanilla specs Pattern 14 nil-guards.
-- Covers: arcane_vanilla, fire_vanilla, frost_vanilla, leveling_vanilla.
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
    MageSpells = {
        ArcaneExplosion = 1449, ArcaneIntellect = 1459, ArcaneMissiles = 5143,
        ArcanePower = 12042, Blink = 1953, Blizzard = 44572,
        ColdSnap = 12472, Combustion = 11129, ConeOfCold = 120,
        Counterspell = 2139, Evocation = 12051, FireBlast = 2136,
        Fireball = 133, FireWard = 21310, Flamestrike = 2120,
        FrostArmor = 7302, FrostNova = 122, FrostWard = 6103,
        Frostbolt = 116, IceBarrier = 11426, IceBlock = 45438,
        ManaShield = 543, Polymorph = 118, PresenceOfMind = 12043,
        Pyroblast = 11366, RemoveCurse = 475, Scorch = 2948,
        WintersChill = 12579, ManaGem = 5514, ConjureManaGem = 759,
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
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {}, MANA_POTION_IDS = {} }
package.loaded["shared/tbc_data_sylvanas"] =
    { ITEMS = { healthstones = {}, potions = {} }, SPELLS = { mage = {} } }
package.loaded["shared/leveling_sylvanas"] = {
    create_context_guard = function() return function() return true end end,
    build_common_state = function() end,
    create_wand_matches = function() return function() return false end end,
    execute_wand = function() return false end,
}

print("=== test_mage_vanilla_nil_guards ===")

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

-- Arcane
test_spec("EaxRotations/classes/mage/arcane_vanilla.lua", "arcane_vanilla",
    { "IceBarrier", "ManaShield", "Counterspell", "Polymorph", "FrostNova", "PresenceOfMind", "ArcanePower", "Evocation", "ManaGem", "FireBlast", "Frostbolt", "ArcaneMissiles", "FireballLeveling", "FrostboltLeveling" },
    base_ctx)

-- Fire
test_spec("EaxRotations/classes/mage/fire_vanilla.lua", "fire_vanilla",
    { "ManaPotion", "IceBarrier", "ManaShield", "Counterspell", "PresenceOfMind", "Combustion", "Pyroblast", "Scorch", "Fireball", "FireBlast", "Flamestrike", "FlamestrikeRank6", "ArcaneExplosion", "Blizzard", "Polymorph", "RemoveCurse", "ManaGemConjure", "ManaGem", "Evocation" },
    base_ctx)

-- Frost
test_spec("EaxRotations/classes/mage/frost_vanilla.lua", "frost_vanilla",
    { "ManaPotion", "ArcaneIntellect", "IceBarrier", "IceBlock", "ColdSnap", "FrostbiteFrostbolt", "PresenceOfMind", "Evocation", "ManaGemConjure", "ManaGem", "ManaShield", "FrostWard", "Counterspell", "RemoveCurse", "WintersChill", "FrostNova", "ConeOfCold", "Polymorph", "ArcaneExplosion", "Blizzard", "FireBlast", "Frostbolt", "Scorch", "ArcaneMissiles" },
    base_ctx)

-- Leveling
test_spec("EaxRotations/classes/mage/leveling_vanilla.lua", "leveling_vanilla",
    { "ArcaneIntellect", "FrostArmor", "FireWard", "RemoveCurse", "ConjureManaGem", "Polymorph", "Counterspell", "ManaShield", "IceBarrier", "FrostNova", "ConeOfCold", "Blink", "Blizzard", "Evocation", "FireBlast", "Fireball", "Frostbolt", "Scorch", "ArcaneMissiles", "UseManaGem", "Wand" },
    base_ctx)

-- REPORT
print()
if #failures == 0 then
    print(string.format("PASS test_mage_vanilla_nil_guards — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_mage_vanilla_nil_guards — %d/%d passed, %d failures:", total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do print(string.format("  %d. [%s] %s", i, f.label, f.error)) end
    error(string.format("test_mage_vanilla_nil_guards: %d failure(s)", #failures))
end
