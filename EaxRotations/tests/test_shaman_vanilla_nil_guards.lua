-- Regression test: shaman vanilla specs Pattern 14 nil-guards.
-- Covers: elemental_vanilla, enhancement_vanilla, restoration_vanilla, leveling_vanilla.
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
    ShamanSpells = {
        BloodFury = 20572, Berserking = 26297, ChainHeal = 1064,
        ChainLightning = 421, CureDisease = 528, CurePoison = 526,
        DiseaseCleansingTotem = 8170, EarthbindTotem = 2484,
        EarthShock = 8042, ElementalMastery = 16166, FlameShock = 8050,
        FireNovaTotem = 15499, FlametongueWeapon = 8024, FrostShock = 8056,
        GhostWolf = 2645, GiftOfTheNaaru = 59547, GraceOfAirTotem = 8835,
        GroundingTotem = 8177, HealingWave = 331, LesserHealingWave = 8004,
        LightningBolt = 403, LightningShield = 324, MagmaTotem = 8190,
        ManaSpringTotem = 5675, ManaTideTotem = 16190, NaturesSwiftness = 16166,
        PoisonCleansingTotem = 8166, Purge = 370, RockbiterWeapon = 8017,
        SearingTotem = 3599, StrengthOfEarthTotem = 8075, Stormstrike = 17364,
        StoneclawTotem = 5730, TremorTotem = 8143, WindfuryTotem = 8512,
        WindfuryWeapon = 8232, WrathOfAirTotem = 3738, TotemicCall = 36936,
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
    CLASS_ID = { PALADIN = 2, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, WARRIOR = 1, ROGUE = 4, HUNTER = 3, DRUID = 11 },
    healing_entries = function() return {} end,
    healing_lowest = function() return nil end,
    has_dispel_type_debuff = function() return false end,
    get_setting = function(key, default) return default end,
    get_friendly_target_entry = function() return nil end,
    is_auto_attacking = function() return false end,
    start_auto_attack = function() end,
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

print("=== test_shaman_vanilla_nil_guards ===")

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

local mock_target = { is_valid = function() return true end, is_dead = function() return false end,
    is_casting = function() return false end, get_health = function() return 50 end,
    get_max_health = function() return 100 end }
local base_ctx = { in_combat = true, target = mock_target, me = {}, settings = {}, hp = 80, mana_pct = 80 }
local shaman_state = { now_ms = 0, mana_emergency = false, lightning_shield_up = false }
local heal_ctx = { in_combat = true, target = mock_target, me = {}, settings = {}, hp = 80, mana_pct = 80,
    lowest = { unit = {}, hp_pct = 50 }, party = {} }

-- Elemental
test_spec("EaxRotations/classes/shaman/elemental_vanilla.lua", "elemental_vanilla",
    { "ManaPotion", "ManaEmergencyWand", "LightningShield", "GhostWolf", "TremorTotem", "EarthbindTotem", "ManaTideTotem", "ElementalMastery", "NaturesSwiftness", "ChainLightning", "LightningBolt", "FlameShock", "EarthShock", "ChainHeal", "FlameShockMoving", "EarthShockMoving", "FrostShockMoving", "WrathOfAirTotem", "ManaSpringTotem", "FireNovaTotem", "MagmaTotem", "FlametongueWeapon", "WindfuryWeapon", "RockbiterWeapon", "HealingWave" },
    base_ctx, shaman_state)

-- Enhancement
test_spec("EaxRotations/classes/shaman/enhancement_vanilla.lua", "enhancement_vanilla",
    { "ManaPotion", "ManaEmergencyWand", "AutoAttack", "GhostWolf", "TotemicCall", "FireNovaReplacement", "EarthTotem", "WaterTotem", "FireTotem", "WindfuryTotemTwist", "GraceOfAirTotemTwist", "WindfuryTotemMaintain", "MHWeaponBuff", "OHWeaponBuff", "LightningShield", "ManaTideTotem", "NaturesSwiftness", "TremorTotem", "GroundingTotem", "BloodFury", "Berserking", "GiftOfTheNaaru", "LesserHealingWave", "ChainHeal", "Stormstrike" },
    base_ctx, shaman_state)

-- Restoration
test_spec("EaxRotations/classes/shaman/restoration_vanilla.lua", "restoration_vanilla",
    { "ManaPotion", "ManaEmergencyWand", "LightningShield", "NaturesSwiftness", "ManaTideTotem", "FriendlyTarget", "HealingWay", "ChainHeal", "SmartHeal", "Purge", "TremorTotem", "GroundingTotem", "StrengthOfEarthTotem", "ManaSpringTotem", "GraceOfAirTotem", "WindfuryTotem", "CurePoison", "CureDisease", "PoisonCleansingTotem", "DiseaseCleansingTotem", "EarthShock", "FlameShock", "ChainLightning", "LightningBolt" },
    heal_ctx, shaman_state)

-- Leveling
test_spec("EaxRotations/classes/shaman/leveling_vanilla.lua", "leveling_vanilla",
    { "WeaponImbue", "LightningShield", "EarthShockInterrupt", "HealingWave", "LesserHealingWave", "SearingTotem", "StrengthOfEarthTotem", "WaterTotem", "Stormstrike", "GroundingTotem", "TremorTotem", "ChainLightning", "FlameShock", "EarthShock", "Purge", "FrostShock", "EarthbindTotem", "StoneclawTotem", "LightningBolt", "GhostWolf", "Wand" },
    base_ctx, shaman_state)

-- REPORT
print()
if #failures == 0 then
    print(string.format("PASS test_shaman_vanilla_nil_guards — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_shaman_vanilla_nil_guards — %d/%d passed, %d failures:", total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do print(string.format("  %d. [%s] %s", i, f.label, f.error)) end
    error(string.format("test_shaman_vanilla_nil_guards: %d failure(s)", #failures))
end
