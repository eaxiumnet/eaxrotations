-- test_sod_rotation_matrix.lua -- Complete Season of Discovery role matrix.
-- WHAT: loads and exercises all 20 real SoD role modules through the class loader.
-- WHEN: run in the rotation suite or standalone from EaxRotations.
-- WHY: locks source priority, registration, rune/phase gates, and nil safety.
-- SAFETY: deterministic local units and no production/API mutations.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual), 2)
    end
end

local function assert_true(value, label)
    assert_eq(value, true, label)
end

local function copy_table(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local target, me, pet, heal_target = {}, {}, {}, {}
local registered = {}
local captured_actions = {}
local registry = {}

function registry:register(name, strategies, options)
    assert_eq(registered[name], nil, "duplicate registry key " .. name)
    registered[name] = { strategies = strategies, options = options }
end

_G.EaxRotations = {
    is_sod = function() return true end,
    rotation_registry = registry,
    PLAYER_UNIT = me,
    spell_action = function(ids, label)
        local id = type(ids) == "table" and ids[1] or ids
        captured_actions[#captured_actions + 1] = { id = id, label = label }
        return { _meta = { id = id, label = label } }
    end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
}

local class_loader = require("shared/class_loader_sylvanas")
local roles = {
    { class = "druid", key = "sod_druid_balance", path = "classes/druid/balance_sod",
        order = { "Starsurge", "Moonfire", "Sunfire", "Starfall", "InsectSwarm", "Starfire", "Wrath" },
        context = { in_combat = true, target = target, sod_runes = { [417157] = true } } },
    { class = "druid", key = "sod_druid_feral", path = "classes/druid/feral_sod", first_index = 2,
        order = { "Interrupt", "CatForm", "TigersFury", "Berserk", "OmenShred", "SavageRoar", "Mangle", "Rip", "Rake", "Shred", "Swipe", "FaerieFireFeral" },
        context = { in_combat = true, target = target, me = me, in_cat_form = false } },
    { class = "druid", key = "sod_druid_restoration", path = "classes/druid/restoration_sod",
        order = { "NaturesSwiftness", "NaturesSwiftnessHealingTouch", "Rebirth", "Innervate", "WildGrowth", "SurvivalInstincts", "Nourish", "Swiftmend", "Lifebloom", "Rejuvenation", "HealingTouch" },
        context = { heal_target = heal_target, heal_target_hp_pct = 70, injured_count = 3,
            player_hp = 20, sod_runes = { [408120] = true, [17116] = true, [18562] = true, [29166] = true, [20748] = true } } },
    { class = "druid", key = "sod_druid_tank", path = "classes/druid/tank_sod", first_index = 2,
        order = { "Interrupt", "Barkskin", "SurvivalInstincts", "DemoralizingRoar", "BearForm", "Growl", "LacerateRefresh", "Mangle", "Lacerate", "Berserk", "Swipe", "Maul", "Enrage" },
        context = { in_combat = true, target = target, me = me, hp_pct = 15, in_bear_form = true, threat_pct = 0 } },
    { class = "hunter", key = "sod_hunter_dps", path = "classes/hunter/dps_hunter_sod",
        order = { "MendPet", "CallPet", "RevivePet", "AspectHawk", "HuntersMark", "SerpentSting", "ChimeraShot", "KillShot", "MultiShot", "Volley", "ArcaneShot", "RapidFire" },
        context = { pet = pet, pet_alive = true, pet_hp_pct = 20 } },
    { class = "mage", key = "sod_mage_dps", path = "classes/mage/dps_mage_sod", first_index = 2,
        order = { "Interrupt", "Evocation", "FrozenOrb", "LivingBomb", "BalefireBolt", "SpellfrostBolt", "FrostfireBolt", "IcyVeins", "Frostbolt" },
        context = { in_combat = true, target = target, me = me, mana_pct = 10 } },
    { class = "paladin", key = "sod_paladin_protection", path = "classes/paladin/protection_sod", first_index = 2,
        order = { "Interrupt", "SealMartyr", "LayOnHands", "DivineProtection", "HolyShield", "Judgement", "AvengersShield", "HammerOfTheRighteous", "Exorcism", "ShieldOfRighteousness" },
        context = { in_combat = true, target = target, me = me, hp_pct = 100 } },
    { class = "paladin", key = "sod_paladin_retribution", path = "classes/paladin/retribution_sod", first_index = 2,
        order = { "Interrupt", "LayOnHands", "DivineShield", "SealMartyr", "AvengingWrath", "Judgement", "DivineStorm", "Exorcism", "CrusaderStrike", "HammerOfWrath", "Consecration" },
        context = { in_combat = true, target = target, hp_pct = 10, sod_runes = { [407778] = true } } }, -- hp 10: fires the LayOnHands emergency lead,
    { class = "priest", key = "sod_priest_healing", path = "classes/priest/healing_sod",
        order = { "Penance", "PowerWordShield", "CircleOfHealing", "PrayerOfMending", "FlashHeal", "Renew" },
        context = { lowest = { unit = heal_target, effective_hp = 20 }, sod_runes = { [402174] = true } } },
    { class = "priest", key = "sod_priest_shadow", path = "classes/priest/shadow_sod", first_index = 2,
        order = { "Interrupt", "VoidPlague", "ShadowWordPain", "VampiricTouch", "DevouringPlague", "MindBlast", "Homunculi", "Shadowfiend", "MindFlay", "MindSpike" },
        context = { in_combat = true, target = target, sod_runes = { [425204] = true } } },
    { class = "rogue", key = "sod_rogue_combat", path = "classes/rogue/combat_sod", first_index = 2,
        order = { "Interrupt", "BladeFlurry", "AdrenalineRush", "FanOfKnives", "CrimsonTempest", "SliceAndDice", "Envenom", "PoisonedKnife", "Mutilate", "SaberSlash" },
        context = { target = target, enemy_count = 2, sod_runes = { [409240] = true }, target_ttd = 60, settings = { use_cooldowns = true } } },
    { class = "rogue", key = "sod_rogue_tank", path = "classes/rogue/tank_sod", first_index = 2,
        order = { "Interrupt", "BladeDance", "MainGauche", "CrimsonTempest", "Envenom", "Eviscerate", "SaberSlash", "SinisterStrike" },
        context = { target = target, combo_points = 1, sod_runes = { [400014] = true, [400012] = true } } },
    { class = "shaman", key = "sod_shaman_elemental", path = "classes/shaman/elemental_sod", first_index = 2,
        order = { "Interrupt", "ShamanisticRage", "FeralSpirit", "FlameShock", "ChainLightning", "LavaBurst", "EarthShockMoving", "FireNova", "LightningBolt" },
        context = { mana_pct = 50 } },
    { class = "shaman", key = "sod_shaman_enhancement", path = "classes/shaman/enhancement_sod", first_index = 2,
        order = { "Interrupt", "FeralSpirit", "ShamanisticRage", "LavaBurst", "MaelstromChainLightning", "MaelstromLightningBolt", "Stormstrike", "LavaLash", "LightningShield", "FlameShock", "EarthShock" },
        context = { in_combat = true, target = target, sod_runes = { [440580] = true } } },
    { class = "shaman", key = "sod_shaman_restoration", path = "classes/shaman/restoration_sod", first_index = 2,
        order = { "Interrupt", "NaturesSwiftness", "NaturesSwiftnessHealingWave", "ShamanisticRage", "WaterShield", "ManaTideTotem", "EarthShield", "Riptide", "HealingRain", "ChainHeal", "LesserHealingWave", "HealingWave", "HealingStreamTotem" },
        context = { mana_pct = 50, lowest = { unit = heal_target, hp = 70 }, player_hp = 20,
            sod_runes = { [408521] = true, [415236] = true, [408514] = true, [16188] = true } } },
    { class = "shaman", key = "sod_shaman_warden", path = "classes/shaman/warden_sod", first_index = 2,
        order = { "Interrupt", "ShamanisticRage", "FlameShock", "MaelstromChainLightning", "MoltenBlast", "Stormstrike", "EarthShock", "MaelstromLightningBolt", "FrostShock", "MagmaTotem", "SearingTotem" },
        -- build_state reads context.mainhand_imbue (not rockbiter_imbued), and
        -- the first strategy (ShamanisticRage) gates on WardenGate rune 408531.
        context = { mana_pct = 50, mainhand_imbue = "rockbiter", sod_runes = { [408531] = true } } },
    { class = "warlock", key = "sod_warlock_dps", path = "classes/warlock/dps_sod",
        order = { "MendPet", "CallPet", "RevivePet", "HealthFunnel", "CurseOfRecklessness", "Shadowburn", "ChaosBolt", "Incinerate", "Conflagrate", "Immolate", "Corruption", "LifeTap", "ShadowBolt" },
        context = { pet = pet, pet_alive = true, pet_hp_pct = 20 } },
    { class = "warlock", key = "sod_warlock_tank", path = "classes/warlock/tank_sod",
        order = { "Metamorphosis", "DemonicGrace", "HealthFunnel", "CurseOfRecklessness", "ShadowCleave", "Incinerate", "Immolate", "Corruption", "LifeTap", "DrainLife", "SearingPain" },
        context = { in_combat = true, target = target, me = me, sod_runes = { [403789] = true } } },
    { class = "warrior", key = "sod_warrior_dps", path = "classes/warrior/dps_warrior_sod", first_index = 2,
        order = { "Interrupt", "Bloodrage", "BerserkerRage", "SweepingStrikes", "Rampage", "Execute", "MortalStrike", "Bloodthirst", "RagingBlow", "QuickStrike", "Whirlwind", "HeroicStrike", "Slam" },
        context = { in_combat = true, target = target, me = me, stance = "berserker", rage = 10 } },
    { class = "warrior", key = "sod_warrior_tank", path = "classes/warrior/tank_warrior_sod", first_index = 2,
        order = { "Interrupt", "LastStand", "Rampage", "SweepingStrikes", "Shockwave", "Cleave", "ShieldSlam", "Revenge", "ThunderClap", "Devastate", "DemoralizingShout", "Bloodrage" },
        context = { in_combat = true, target = target, me = me, stance = "defensive", hp_pct = 40, rage = 20 } },
}

local function with_sod_context(context)
    local result = copy_table(context)
    result.is_sod = true
    result.sod_phase = result.sod_phase or 8
    return result
end

local total_loaded = 0
local loaded_classes = {}
for _, role in ipairs(roles) do
    if not loaded_classes[role.class] then
        loaded_classes[role.class] = true
        total_loaded = total_loaded + class_loader.load_sod_specs(role.class, role.class)
    end
end
assert_eq(total_loaded, 20, "real loader SoD count")
assert_eq(#captured_actions > 0, true, "real modules resolved actions")

for _, role in ipairs(roles) do
    local registration = registered[role.key]
    assert_eq(type(registration), "table", role.key .. " registration")
    local rotation = package.loaded[role.path]
    assert_eq(type(rotation), "table", role.path .. " module")
    assert_eq(type(rotation.build_state), "function", role.key .. " build_state")
    assert_eq(type(rotation.actions), "table", role.key .. " actions")
    assert_eq(type(registration.options), "table", role.key .. " registration options")
    assert_eq(type(registration.options.get_state), "function", role.key .. " registered get_state")
    assert_eq(#rotation.strategies, #role.order, role.key .. " strategy count")
    for index, name in ipairs(role.order) do
        assert_eq(rotation.strategies[index].name, name, role.key .. " strategy order " .. index)
    end
    assert_eq(registration.strategies, rotation.strategies, role.key .. " loader registration identity")

    local context = with_sod_context(role.context)
    local state = rotation.build_state(context)
    -- first_index: the manager Interrupt lane (strategy 1) holds without
    -- interrupt APIs in this harness; the first SPEC lane leads instead.
    local first_idx = role.first_index or 1
    assert_true(rotation.strategies[first_idx].matches(context, state), role.key .. " first source priority")

    local nil_state = rotation.build_state(nil)
    assert_eq(type(nil_state), "table", role.key .. " nil state table")
    for index, strategy in ipairs(rotation.strategies) do
        local ok, matched = pcall(strategy.matches, nil, nil_state)
        assert_true(ok, role.key .. " nil strategy " .. index .. " does not throw")
        assert_eq(matched, false, role.key .. " nil strategy " .. index .. " fails closed")
    end

    local legacy = copy_table(context)
    legacy.is_sod = false
    assert_eq(rotation.strategies[1].matches(legacy, rotation.build_state(legacy)), false,
        role.key .. " legacy gate")
    local stale = copy_table(context)
    stale.sod_phase = "phase-8"
    assert_eq(rotation.strategies[1].matches(stale, rotation.build_state(stale)), false,
        role.key .. " stale phase gate")

    for action_name, descriptor in pairs(rotation.actions or {}) do
        assert_eq(type(descriptor), "table", role.key .. " action " .. action_name)
        assert_eq(type(descriptor.action), "table", role.key .. " action descriptor " .. action_name)
        if descriptor.rune_id then
            local equipped = with_sod_context({ sod_runes = { [descriptor.rune_id] = true } })
            assert_true(require("shared/spec_kit_sylvanas").sod_action_available(equipped, descriptor),
                role.key .. " rune gate opens " .. action_name)
            -- W4.2 contract: a KNOWN non-empty rune table without the rune
            -- still closes the gate (strict); unknown/empty state fails open.
            local absent = with_sod_context({ sod_runes = { [999999] = true } })
            assert_eq(require("shared/spec_kit_sylvanas").sod_action_available(absent, descriptor), false,
                role.key .. " rune gate closes " .. action_name)
        end
        if descriptor.min_phase and descriptor.min_phase > 1 then
            local before = with_sod_context({ sod_phase = descriptor.min_phase - 1 })
            assert_eq(require("shared/spec_kit_sylvanas").sod_action_available(before, descriptor), false,
                role.key .. " phase gate closes " .. action_name)
        end
    end
end

print("PASS test_sod_rotation_matrix (20 real SoD roles; ordering, source priorities, gates, nil, legacy)")
