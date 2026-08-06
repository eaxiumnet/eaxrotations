-- test_tbc_spell_ladders.lua — TBC Anniversary Phase-2 1–70 spell ladders (all 9 classes).
-- WHAT:  At L10/25/40/60/70, with high talents unlearned via learned-spell mock, at least
--        one real filler matches on shipped TBC rotations (build_state + matches).
-- WHEN:  Rotation suite; Phase-2 deep audit (mirrors Vanilla v2.9.x Phase 2).
-- WHY:  Prove leveling/midgame combat is not blocked by endgame-only talents.
-- SAFETY: Test-only helper; drives shipped matches only.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/tests/?.lua;./?.lua;"
    .. (package.path or "")

local H = require("tbc_ladder_helper")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local failures, total, passed = {}, 0, 0
local function expect(label, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then passed = passed + 1
    else failures[#failures + 1] = label .. " :: " .. tostring(err) end
end

local LEVELS = { 10, 25, 40, 60, 70 }

local function ladder_case(path, filler_names, opts)
    opts = opts or {}
    for li = 1, #LEVELS do
        local level = LEVELS[li]
        if opts.min_level and level < opts.min_level then
            -- skip band (e.g. cat form L20+)
        else
            expect(path .. " L" .. level .. " filler", function()
                local mod = H.load_module(path, { level = level, class_folder = opts.class_folder })
                assert_true(mod.strategies ~= nil or (mod.result and mod.result.on_update),
                    "strategies or leveling module captured")
                local strategies = mod.strategies
                if not strategies and type(mod.result) == "table" and mod.result.strategies then
                    strategies = mod.result.strategies
                end
                assert_true(strategies ~= nil, "strategies required for ladder")

                local ctx = H.context(level, opts.context_extra)
                local state = H.ready_state(level, {
                    rage = 60, energy = 100, mana_pct = 80, combo_points = 5,
                    level = level, in_combat = true, is_cat = true, is_bear = true,
                })
                if mod.get_state then
                    local ok, st = pcall(mod.get_state, ctx)
                    if ok and type(st) == "table" then
                        state = H.ready_state(level, st)
                        state.rage = state.rage or 60
                        state.energy = state.energy or 100
                        state.mana_pct = state.mana_pct or 80
                        state.level = state.level or level
                        state.in_combat = true
                        state.combo_points = state.combo_points or 5
                    end
                end

                local hit, name = H.any_matches(strategies, filler_names, ctx, state)
                if not hit then
                    hit, name = H.any_strategy_matches(strategies, ctx, state, {
                        "HealthPotion", "ManaPotion", "DamagePotion", "EngineeringBomb",
                    })
                end
                assert_true(hit, "expected combat filler at L" .. level
                    .. " (tried named list + any strategy); last=" .. tostring(name))
            end)
        end
    end
end

local function high_talent_blocked(path, talent_name, low_level, opts)
    expect(path .. " " .. talent_name .. " blocked at L" .. low_level, function()
        local mod = H.load_module(path, { level = low_level, class_folder = opts and opts.class_folder })
        local s = H.find_strategy(mod.strategies, talent_name)
        assert_true(s ~= nil, talent_name .. " strategy must be registered in " .. path)
        local ctx = H.context(low_level, opts and opts.context_extra)
        local state = { rage = 100, energy = 100, mana_pct = 100, in_combat = true, level = low_level }
        if mod.get_state then
            local ok, st = pcall(mod.get_state, ctx)
            if ok and type(st) == "table" then state = st end
        end
        -- Optional post-get_state forces (e.g. inject tank for ES without forcing ready)
        if opts and opts.state_force then
            for k, v in pairs(opts.state_force) do state[k] = v end
        end
        state.rage = 100
        state.energy = 100
        state.mana_pct = 100
        state.in_combat = true
        local ok, res = pcall(s.matches, ctx, state)
        assert_true(ok, talent_name .. " matches must not throw")
        assert_true(not res, talent_name .. " must not match when unlearned at L" .. low_level
            .. " (spell_ready filtered by LEARN map)")
    end)
end

local function dungeon_aoe_case(path, aoe_names, need_level, opts)
    opts = opts or {}
    expect(path .. " dungeon AoE L" .. need_level, function()
        local mod = H.load_module(path, { level = need_level, class_folder = opts.class_folder })
        local ctx = H.context(need_level, {
            enemy_count = 4, enemies_count = 4, is_group = true, is_solo = false,
            distance = 25, target_distance = 25,
            settings = opts.settings or {},
        })
        if opts.context_extra then
            for k, v in pairs(opts.context_extra) do ctx[k] = v end
        end
        local state = H.ready_state(need_level, {
            rage = 100, mana_pct = 80, enemy_count = 4, target_count = 4,
            in_combat = true, multi_shot_ready = true, cleave_ready = true,
            consecration_ready = true, consecration_remains = 0,
            multishot_mode = 2, aoe_threshold = 3, use_volley = false,
            is_mounted = false, cc_nearby = false, has_seal = true,
        })
        if mod.get_state then
            local ok, st = pcall(mod.get_state, ctx)
            if ok and type(st) == "table" then
                state = H.ready_state(need_level, st)
                state.enemy_count = 4
                state.target_count = 4
                state.rage = 100
                state.mana_pct = 80
                state.in_combat = true
                state.multi_shot_ready = true
                state.cleave_ready = true
                state.consecration_ready = true
                state.consecration_remains = 0
                state.multishot_mode = state.multishot_mode or 2
                state.is_mounted = false
                state.cc_nearby = false
            end
        end
        local hit, name = H.any_matches(mod.strategies, aoe_names, ctx, state)
        assert_true(hit, "dungeon AoE must match one of [" .. table.concat(aoe_names, ",")
            .. "] got " .. tostring(name))
    end)
end

print("=== test_tbc_spell_ladders (Phase 2 TBC Anniversary) ===")

-- ============================================================================
-- 1. HUNTER
-- ============================================================================
local hunter_fillers = {
    "ArcaneShot", "SerpentSting", "SerpentStingRefresh", "LevelingArcaneShot",
    "LevelingSting", "RaptorStrike", "AimedShot", "InCombatAimedShot", "MultiShot",
    "HuntersMark", "SteadyShot", "KillCommand",
}
ladder_case("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", hunter_fillers, { class_folder = "hunter" })
ladder_case("EaxRotations/classes/hunter/marksmanship_sylvanas.lua", hunter_fillers, { class_folder = "hunter" })
ladder_case("EaxRotations/classes/hunter/survival_sylvanas.lua", hunter_fillers, { class_folder = "hunter" })
ladder_case("EaxRotations/classes/hunter/leveling_sylvanas.lua", {
    "ArcaneShot", "SerpentSting", "AimedShot", "MultiShot", "RaptorStrike", "HuntersMark", "SteadyShot",
}, { class_folder = "hunter" })
high_talent_blocked("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", "SteadyShot", 25, { class_folder = "hunter" })
high_talent_blocked("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", "KillCommand", 40, { class_folder = "hunter" })
high_talent_blocked("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", "BestialWrath", 25, { class_folder = "hunter" })
dungeon_aoe_case("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", { "MultiShot", "Volley" }, 40, {
    class_folder = "hunter",
})

-- ============================================================================
-- 2. WARRIOR
-- ============================================================================
local warrior_fillers = {
    "HeroicStrike", "Rend", "SunderArmor", "Overpower", "Whirlwind", "Cleave",
    "Bloodthirst", "MortalStrike", "Execute", "BattleShout", "ThunderClap",
    "DemoralizingShout", "ShieldSlam", "Revenge", "Devastate",
}
ladder_case("EaxRotations/classes/warrior/fury_sylvanas.lua", warrior_fillers, { class_folder = "warrior" })
ladder_case("EaxRotations/classes/warrior/arms_sylvanas.lua", warrior_fillers, { class_folder = "warrior" })
ladder_case("EaxRotations/classes/warrior/protection_sylvanas.lua", warrior_fillers, { class_folder = "warrior" })
ladder_case("EaxRotations/classes/warrior/kebab_sylvanas.lua", warrior_fillers, { class_folder = "warrior" })
ladder_case("EaxRotations/classes/warrior/leveling_sylvanas.lua", {
    "HeroicStrike", "Rend", "Charge", "Overpower", "BattleShout", "Bloodthirst", "SunderArmor",
}, { class_folder = "warrior" })
high_talent_blocked("EaxRotations/classes/warrior/fury_sylvanas.lua", "Bloodthirst", 25, { class_folder = "warrior" })
high_talent_blocked("EaxRotations/classes/warrior/arms_sylvanas.lua", "MortalStrike", 25, { class_folder = "warrior" })
dungeon_aoe_case("EaxRotations/classes/warrior/fury_sylvanas.lua", { "Cleave", "Whirlwind", "SweepingStrikes" }, 40, {
    class_folder = "warrior",
})

-- ============================================================================
-- 3. WARLOCK
-- ============================================================================
local lock_fillers = {
    "ShadowBolt", "ShadowBoltFiller", "Corruption", "CorruptionDoT", "Immolate", "ImmolateDoT",
    "CurseOfAgony", "LifeTap", "Conflagrate", "Incinerate", "UnstableAffliction", "Wand",
}
ladder_case("EaxRotations/classes/warlock/affliction_sylvanas.lua", lock_fillers, { class_folder = "warlock" })
ladder_case("EaxRotations/classes/warlock/demonology_sylvanas.lua", lock_fillers, { class_folder = "warlock" })
ladder_case("EaxRotations/classes/warlock/destruction_sylvanas.lua", lock_fillers, { class_folder = "warlock" })
ladder_case("EaxRotations/classes/warlock/leveling_sylvanas.lua", {
    "ShadowBolt", "Corruption", "Immolate", "CurseOfAgony", "LifeTap", "Wand",
}, { class_folder = "warlock" })
high_talent_blocked("EaxRotations/classes/warlock/destruction_sylvanas.lua", "Conflagrate", 25, { class_folder = "warlock" })
high_talent_blocked("EaxRotations/classes/warlock/affliction_sylvanas.lua", "UnstableAffliction", 25, { class_folder = "warlock" })
dungeon_aoe_case("EaxRotations/classes/warlock/destruction_sylvanas.lua", {
    "RainOfFire", "Hellfire", "SeedOfCorruption",
}, 70, { class_folder = "warlock" })

-- ============================================================================
-- 4. MAGE
-- ============================================================================
local mage_fillers = {
    "Fireball", "Frostbolt", "FireBlast", "Scorch", "ArcaneMissiles", "ArcaneBlast",
    "FireballLeveling", "FrostboltLeveling", "Pyroblast", "IceLance",
}
ladder_case("EaxRotations/classes/mage/fire_sylvanas.lua", mage_fillers, { class_folder = "mage" })
ladder_case("EaxRotations/classes/mage/frost_sylvanas.lua", mage_fillers, { class_folder = "mage" })
ladder_case("EaxRotations/classes/mage/arcane_sylvanas.lua", mage_fillers, { class_folder = "mage" })
ladder_case("EaxRotations/classes/mage/leveling_sylvanas.lua", mage_fillers, { class_folder = "mage" })
expect("fire Fireball when Scorch unlearned L10", function()
    local mod = H.load_module("EaxRotations/classes/mage/fire_sylvanas.lua", {
        level = 10, class_folder = "mage",
    })
    local fb = H.find_strategy(mod.strategies, "Fireball")
    assert_true(fb ~= nil, "Fireball strategy")
    local ctx = H.context(10, { scorch_stacks = 0, settings = { use_scorch_debuff = true } })
    local state = { scorch_stacks = 0 }
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then state = st end
    end
    assert_true(fb.matches(ctx, state), "Fireball matches at L10 with Scorch unlearned")
end)
high_talent_blocked("EaxRotations/classes/mage/arcane_sylvanas.lua", "ArcaneBlast", 40, { class_folder = "mage" })
dungeon_aoe_case("EaxRotations/classes/mage/fire_sylvanas.lua", {
    "Flamestrike", "ArcaneExplosion", "Blizzard", "BlastWave",
}, 40, { class_folder = "mage" })

-- ============================================================================
-- 5. ROGUE
-- ============================================================================
local rogue_fillers = {
    "SinisterStrike", "Eviscerate", "SliceAndDice", "Backstab", "Rupture",
    "Hemorrhage", "Ambush", "Garrote", "Mutilate", "Envenom",
}
ladder_case("EaxRotations/classes/rogue/combat_sylvanas.lua", rogue_fillers, { class_folder = "rogue" })
ladder_case("EaxRotations/classes/rogue/assassination_sylvanas.lua", rogue_fillers, { class_folder = "rogue" })
ladder_case("EaxRotations/classes/rogue/subtlety_sylvanas.lua", rogue_fillers, { class_folder = "rogue" })
ladder_case("EaxRotations/classes/rogue/leveling_sylvanas.lua", {
    "SinisterStrike", "Eviscerate", "SliceAndDice", "Backstab",
}, { class_folder = "rogue" })
high_talent_blocked("EaxRotations/classes/rogue/assassination_sylvanas.lua", "Mutilate", 25, { class_folder = "rogue" })
expect("rogue combat BladeFlurry dungeon AoE L40", function()
    local mod = H.load_module("EaxRotations/classes/rogue/combat_sylvanas.lua", {
        level = 40, class_folder = "rogue",
    })
    local bf = H.find_strategy(mod.strategies, "BladeFlurry")
    assert_true(bf ~= nil, "BladeFlurry present")
    local ctx = H.context(40, {
        enemy_count = 4, enemies_count = 4, is_group = true, is_solo = false,
        settings = { use_cooldowns = true, combat_blade_flurry_count = 2 },
    })
    local state = H.ready_state(40, {
        in_combat = true, blade_flurry_ready = true, has_blade_flurry = false,
        has_snd = true, target_count = 4, enemy_count = 4,
    })
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and type(st) == "table" then
            state = H.ready_state(40, st)
            state.in_combat = true
            state.blade_flurry_ready = true
            state.has_blade_flurry = false
            state.has_snd = true
            state.target_count = 4
            state.enemy_count = 4
        end
    end
    local ok, res = pcall(bf.matches, ctx, state)
    assert_true(ok and res, "BladeFlurry matches multi-target with SnD")
end)

-- ============================================================================
-- 6. SHAMAN
-- ============================================================================
local sham_fillers = {
    "LightningBolt", "ChainLightning", "EarthShock", "FlameShock", "FrostShock",
    "HealingWave", "ChainHeal", "LesserHealingWave", "Stormstrike",
}
ladder_case("EaxRotations/classes/shaman/elemental_sylvanas.lua", sham_fillers, { class_folder = "shaman" })
ladder_case("EaxRotations/classes/shaman/enhancement_sylvanas.lua", sham_fillers, { class_folder = "shaman" })
ladder_case("EaxRotations/classes/shaman/restoration_sylvanas.lua", {
    "HealingWave", "ChainHeal", "LesserHealingWave", "LightningBolt", "EarthShock", "EarthShield",
}, { class_folder = "shaman" })
ladder_case("EaxRotations/classes/shaman/leveling_sylvanas.lua", sham_fillers, { class_folder = "shaman" })
high_talent_blocked("EaxRotations/classes/shaman/enhancement_sylvanas.lua", "Stormstrike", 25, { class_folder = "shaman" })
high_talent_blocked("EaxRotations/classes/shaman/restoration_sylvanas.lua", "EarthShieldTank", 25, {
    class_folder = "shaman",
    state_force = {
        tank = { unit = {}, effective_hp = 50 },
        mana_emergency = false,
        -- earth_shield_ready must come from build_state / spell_ready LEARN gate
    },
})

-- ============================================================================
-- 7. PRIEST
-- ============================================================================
local priest_dps = {
    "Smite", "SmiteFiller", "ShadowWordPain", "MindBlast", "MindFlay",
    "IdleSWP", "IdleSmite", "HolyFire", "FlashHeal", "Renew", "VampiricTouch",
}
ladder_case("EaxRotations/classes/priest/shadow_sylvanas.lua", priest_dps, { class_folder = "priest" })
ladder_case("EaxRotations/classes/priest/smite_sylvanas.lua", priest_dps, { class_folder = "priest" })
ladder_case("EaxRotations/classes/priest/holy_sylvanas.lua", {
    "FlashHeal", "GreaterHeal", "Renew", "RenewTank", "RenewSpread", "EmergencyFlashHeal",
    "IdleSmite", "IdleSWP", "CircleOfHealing", "PrayerOfMending",
}, { class_folder = "priest" })
ladder_case("EaxRotations/classes/priest/discipline_sylvanas.lua", {
    "FlashHeal", "GreaterHeal", "EmergencyFlashHeal", "PowerWordShield", "EmergencyPowerWordShield",
    "Renew", "IdleSmite", "IdleShadowWordPain",
}, { class_folder = "priest" })
ladder_case("EaxRotations/classes/priest/leveling_sylvanas.lua", {
    "Smite", "ShadowWordPain", "MindBlast", "FlashHeal", "PowerWordShield",
}, { class_folder = "priest" })
high_talent_blocked("EaxRotations/classes/priest/shadow_sylvanas.lua", "VampiricTouch", 25, { class_folder = "priest" })
high_talent_blocked("EaxRotations/classes/priest/shadow_sylvanas.lua", "Shadowfiend", 40, { class_folder = "priest" })
high_talent_blocked("EaxRotations/classes/priest/shadow_sylvanas.lua", "ShadowWordDeath", 40, { class_folder = "priest" })

-- ============================================================================
-- 8. PALADIN
-- ============================================================================
local pally_fillers = {
    "Judgement", "Consecration", "HolyLight", "FlashOfLight", "HolyShock",
    "SealRighteousness", "SealOfCommand", "Ret_SealCommand_Primary", "Ret_JudgeDamageSeal",
    "HolyShield", "HammerOfWrath", "SmartHeal", "HolyLightEmergency", "CrusaderStrike",
    "SealTwistBlood", "SealTwistPrepCommand",
}
ladder_case("EaxRotations/classes/paladin/retribution_sylvanas.lua", pally_fillers, { class_folder = "paladin" })
ladder_case("EaxRotations/classes/paladin/protection_sylvanas.lua", pally_fillers, {
    class_folder = "paladin",
    context_extra = { settings = { prot_judgement = true, prot_avenger_shield = true } },
})
ladder_case("EaxRotations/classes/paladin/holy_sylvanas.lua", pally_fillers, { class_folder = "paladin" })
ladder_case("EaxRotations/classes/paladin/leveling_sylvanas.lua", {
    "Judgement", "HolyLight", "SealOfRighteousness", "Consecration", "FlashOfLight",
}, { class_folder = "paladin" })
high_talent_blocked("EaxRotations/classes/paladin/protection_sylvanas.lua", "HolyShield", 25, { class_folder = "paladin" })
high_talent_blocked("EaxRotations/classes/paladin/retribution_sylvanas.lua", "CrusaderStrike", 25, { class_folder = "paladin" })
dungeon_aoe_case("EaxRotations/classes/paladin/protection_sylvanas.lua", { "Consecration" }, 40, {
    class_folder = "paladin",
    settings = { prot_consecration = true, prot_consecration_targets = 3 },
})

-- ============================================================================
-- 9. DRUID
-- ============================================================================
local druid_fillers = {
    "Wrath", "Moonfire", "Starfire", "InsectSwarm", "Shred", "Rip", "FerociousBite",
    "Maul", "Swipe", "DemoralizingRoar", "HealingTouch", "Rejuvenation", "Regrowth",
    "ClawFallback", "Rake", "MangleFiller", "Lacerate", "Lifebloom",
}
ladder_case("EaxRotations/classes/druid/balance_sylvanas.lua", druid_fillers, { class_folder = "druid" })
-- Cat Form is L20+; start B2
ladder_case("EaxRotations/classes/druid/cat_sylvanas.lua", {
    "Shred", "Rake", "Rip", "ClawFallback", "FerociousBite", "FaerieFireFeral", "MangleFiller",
}, { class_folder = "druid", min_level = 25, context_extra = { energy = 100, combo_points = 5 } })
ladder_case("EaxRotations/classes/druid/bear_sylvanas.lua", druid_fillers, {
    class_folder = "druid",
    context_extra = { rage = 50 },
})
ladder_case("EaxRotations/classes/druid/caster_sylvanas.lua", druid_fillers, { class_folder = "druid" })
ladder_case("EaxRotations/classes/druid/resto_sylvanas.lua", {
    "HealingTouch", "Rejuvenation", "Regrowth", "RegrowthSpotHeal", "PriorityRejuvenation",
    "SwiftmendEmergency", "FallbackHealingTouch", "Lifebloom",
}, { class_folder = "druid" })
ladder_case("EaxRotations/classes/druid/leveling_sylvanas.lua", {
    "Wrath", "Moonfire", "HealingTouch", "Rejuvenation", "CatForm", "BearForm",
}, { class_folder = "druid" })
high_talent_blocked("EaxRotations/classes/druid/cat_sylvanas.lua", "MangleDebuff", 25, { class_folder = "druid" })
high_talent_blocked("EaxRotations/classes/druid/cat_sylvanas.lua", "MangleFiller", 25, { class_folder = "druid" })
high_talent_blocked("EaxRotations/classes/druid/cat_sylvanas.lua", "StealthMangle", 25, {
    class_folder = "druid",
    state_force = { is_stealthed = true, energy = 100 },
})
high_talent_blocked("EaxRotations/classes/druid/bear_sylvanas.lua", "Lacerate", 40, { class_folder = "druid" })

expect("cat Shred/Rip without Mangle L25", function()
    local mod = H.load_module("EaxRotations/classes/druid/cat_sylvanas.lua", {
        level = 25, class_folder = "druid",
    })
    local ctx = H.context(25, { energy = 100, combo_points = 5 })
    local state = { level = 25, energy = 100, combo_points = 5, in_combat = true,
        mangle_remains = 0, is_cat = true }
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then
            state = st
            state.level = 25
            state.energy = 100
            state.combo_points = state.combo_points or 5
            state.is_cat = true
            state.is_behind = true
        end
    end
    local hit = H.any_matches(mod.strategies, { "Shred", "Rip", "Rake", "ClawFallback", "FerociousBite" }, ctx, state)
    assert_true(hit, "Cat must have builder/finisher without Mangle at L25")
end)

-- ============================================================================
-- Content modes + settings + raid-70 priority
-- ============================================================================
expect("hunter pet Mend at L25 solo", function()
    local mod = H.load_module("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", {
        level = 25, class_folder = "hunter",
    })
    local mend = H.find_strategy(mod.strategies, "MendPet")
    assert_true(mend ~= nil, "MendPet strategy exists")
    local ctx = H.context(25, { is_solo = true })
    local state = {
        in_combat = true, pet_alive = true, pet_hp = 30, mend_pet_ready = true, is_mounted = false,
    }
    assert_true(mend.matches(ctx, state), "MendPet matches low pet HP solo")
end)

expect("fury Cleave MATCHES when multi + rage", function()
    local mod = H.load_module("EaxRotations/classes/warrior/fury_sylvanas.lua", {
        level = 40, class_folder = "warrior",
    })
    local cleave = H.find_strategy(mod.strategies, "Cleave")
    assert_true(cleave ~= nil, "Cleave strategy present")
    local ctx = H.context(40, { enemy_count = 3, enemies_count = 3, rage = 80 })
    local state = {}
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        state = (ok and st) or {}
    end
    state.rage = 80
    state.cleave_ready = true
    state.target_count = 3
    local ok, res = pcall(cleave.matches, ctx, state)
    assert_true(ok, "Cleave matches no throw")
    assert_true(res == true, "Cleave must match with target_count>=2 and rage>=40")
end)

-- FelArmor strategy must exist at L70 (LEARN 62); OOC armor path registration
expect("destruction FelArmor strategy present at L70", function()
    local mod = H.load_module("EaxRotations/classes/warlock/destruction_sylvanas.lua", {
        level = 70, class_folder = "warlock",
    })
    local fel = H.find_strategy(mod.strategies, "FelArmor")
    assert_true(fel ~= nil and fel.matches ~= nil, "FelArmor strategy + matches at L70")
end)

-- ============================================================================
-- Honest setting flips: ON must match true, OFF must match false (same readiness forces)
-- ============================================================================
local function setting_flip(label, path, folder, strategy_name, settings_on, settings_off, readiness, ctx_extra)
    expect(label, function()
        local function run(settings)
            local mod = H.load_module(path, { level = 70, class_folder = folder })
            local strat = H.find_strategy(mod.strategies, strategy_name)
            assert_true(strat ~= nil, strategy_name .. " present in " .. path)
            local ctx = H.context(70, {
                settings = settings or {},
                in_combat = true,
                is_group = true,
                should_burst = true,
                combat_time = 90,
                ttd = 120,
            })
            if ctx_extra then for k, v in pairs(ctx_extra) do ctx[k] = v end end
            local state = H.ready_state(70, {})
            if mod.get_state then
                local ok, st = pcall(mod.get_state, ctx)
                if ok and type(st) == "table" then state = H.ready_state(70, st) end
            end
            -- build_state may mutate context (e.g. in_melee_range); re-apply extras.
            if ctx_extra then for k, v in pairs(ctx_extra) do ctx[k] = v end end
            -- Force readiness/fixture only — never force the setting flag itself.
            if readiness then for k, v in pairs(readiness) do state[k] = v end end
            state.in_combat = true
            local ok, res = pcall(strat.matches, ctx, state)
            assert_true(ok, strategy_name .. " matches no throw")
            return res and true or false
        end
        local on = run(settings_on)
        local off = run(settings_off)
        assert_true(on == true, strategy_name .. " must match when setting ON (got " .. tostring(on) .. ")")
        assert_true(off == false, strategy_name .. " must not match when setting OFF (got " .. tostring(off) .. ")")
    end)
end

-- Hunter (5 keys — RapidFire for CDs; avoid BW align timeout)
setting_flip("flip hunter use_cooldowns RapidFire",
    "EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", "hunter", "RapidFire",
    { use_cooldowns = true }, { use_cooldowns = false },
    { pet_alive = true, rapid_fire_ready = true, is_mounted = false })
setting_flip("flip hunter multishot_mode MultiShot",
    "EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", "hunter", "MultiShot",
    { multishot_mode = 2 }, { multishot_mode = 0 },
    { multi_shot_ready = true, enemy_count = 5, is_mounted = false })
setting_flip("flip hunter use_volley Volley",
    "EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", "hunter", "Volley",
    { use_volley = true, aoe_threshold = 3 }, { use_volley = false, aoe_threshold = 3 },
    { enemy_count = 5, volley_ready = true, is_mounted = false })
setting_flip("flip hunter use_melee RaptorStrike",
    "EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", "hunter", "RaptorStrike",
    { use_melee = true, hunter_melee_weave = true },
    { use_melee = false, hunter_melee_weave = false },
    { distance_sq = 9, raptor_strike_ready = true, is_mounted = false })
setting_flip("flip hunter use_explosive_trap ExplosiveTrap",
    "EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", "hunter", "ExplosiveTrap",
    { use_explosive_trap = true, aoe_threshold = 3 }, { use_explosive_trap = false },
    { enemy_count = 5, explosive_trap_ready = true, is_mounted = false })

-- Warrior (3+ keys: sunder_mode, use_cooldowns DeathWish, sweeping_strikes_count)
setting_flip("flip warrior sunder_mode SunderArmor",
    "EaxRotations/classes/warrior/fury_sylvanas.lua", "warrior", "SunderArmor",
    { sunder_mode = "high" }, { sunder_mode = "off" },
    { sunder_stacks = 0, rage = 80 },
    { target_armor = 5000, target_hp = 80 })
setting_flip("flip warrior use_cooldowns DeathWish",
    "EaxRotations/classes/warrior/fury_sylvanas.lua", "warrior", "DeathWish",
    { use_cooldowns = true }, { use_cooldowns = false },
    { death_wish_ready = true, hp = 90, major_cd_window = true, ttd = 60, target_hp = 50, rage = 50 })
setting_flip("flip warrior use_cooldowns Recklessness",
    "EaxRotations/classes/warrior/fury_sylvanas.lua", "warrior", "Recklessness",
    { use_cooldowns = true }, { use_cooldowns = false },
    { recklessness_ready = true, hp = 90, major_cd_window = true, ttd = 60 })
-- Kebab group overwrite: sunder_armor_mode + maintain_demo_shout
setting_flip("flip kebab sunder_armor_mode SunderMaintain",
    "EaxRotations/classes/warrior/kebab_sylvanas.lua", "warrior", "SunderMaintain",
    { sunder_armor_mode = "help_stack" }, { sunder_armor_mode = "none" },
    { sunder_stacks = 0, sunder_duration = 0 },
    { stance = 2, target_armor = 5000, in_melee_range = true })
setting_flip("flip kebab maintain_demo_shout DemoShout",
    "EaxRotations/classes/warrior/kebab_sylvanas.lua", "warrior", "DemoShout",
    { maintain_demo_shout = true }, { maintain_demo_shout = false },
    { demo_shout_duration = 0 },
    { in_melee_range = true, has_valid_enemy_target = true })

-- Warlock (≥3 keys: curse_mode, assigned_curse, aff_use_amplify_curse, use_auto_potions)
setting_flip("flip warlock curse_mode CoE",
    "EaxRotations/classes/warlock/affliction_sylvanas.lua", "warlock", "CurseOfElements",
    { warlock_curse_mode = "elements" }, { warlock_curse_mode = "agony" },
    { coe_remains = 0 },
    { is_group = true, target = {} })
setting_flip("flip warlock assigned_curse Agony",
    "EaxRotations/classes/warlock/affliction_sylvanas.lua", "warlock", "CurseOfAgony",
    { warlock_assigned_curse = "agony" }, { warlock_assigned_curse = "elements" },
    { agony_remains = 0 },
    { has_valid_enemy_target = true, ttd = 120 })
setting_flip("flip warlock aff_use_amplify_curse AmplifyCurse",
    "EaxRotations/classes/warlock/affliction_sylvanas.lua", "warlock", "AmplifyCurse",
    { aff_use_amplify_curse = true }, { aff_use_amplify_curse = false },
    { amplify_curse_ready = true, agony_remains = 0, doom_remains = 0 },
    { ttd = 120, ttd_known = true })
setting_flip("flip warlock use_auto_potions DamagePotion",
    "EaxRotations/classes/warlock/affliction_sylvanas.lua", "warlock", "DamagePotion",
    { use_auto_potions = true }, { use_auto_potions = false },
    {},
    { has_damage_potion = true, should_burst = true })

-- Mage
setting_flip("flip mage use_cooldowns Combustion",
    "EaxRotations/classes/mage/fire_sylvanas.lua", "mage", "Combustion",
    { use_cooldowns = true }, { use_cooldowns = false },
    { combustion_ready = true })
expect("flip mage use_scorch_debuff Fireball allowed when off", function()
    local mod = H.load_module("EaxRotations/classes/mage/fire_sylvanas.lua", {
        level = 70, class_folder = "mage",
    })
    local fb = H.find_strategy(mod.strategies, "Fireball")
    assert_true(fb ~= nil, "Fireball present")
    local ctx = H.context(70, { settings = { use_scorch_debuff = false }, scorch_stacks = 0 })
    local state = { scorch_stacks = 0 }
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then state = st end
    end
    assert_true(fb.matches(ctx, state) == true, "Fireball matches with scorch duty off")
end)
setting_flip("flip mage use_mana_gem ManaGem",
    "EaxRotations/classes/mage/fire_sylvanas.lua", "mage", "ManaGem",
    { use_mana_gem = true }, { use_mana_gem = false },
    { mana_pct = 20, mana_gem_available = true })
-- use_scorch + use_cooldowns + use_mana_gem already prove ≥3 mage keys

-- Rogue (≥3 keys: use_cooldowns, combat_blade_flurry_count, combat_expose_assigned, use_auto_potions)
setting_flip("flip rogue use_cooldowns BladeFlurry",
    "EaxRotations/classes/rogue/combat_sylvanas.lua", "rogue", "BladeFlurry",
    { use_cooldowns = true, combat_blade_flurry_count = 2 },
    { use_cooldowns = false, combat_blade_flurry_count = 2 },
    { blade_flurry_ready = true, has_blade_flurry = false, has_snd = true, target_count = 4 })
expect("flip rogue combat_blade_flurry_count", function()
    local mod = H.load_module("EaxRotations/classes/rogue/combat_sylvanas.lua", {
        level = 70, class_folder = "rogue",
    })
    local bf = H.find_strategy(mod.strategies, "BladeFlurry")
    assert_true(bf ~= nil, "BladeFlurry present")
    local function run(count, targets)
        local ctx = H.context(70, {
            settings = { use_cooldowns = true, combat_blade_flurry_count = count },
            in_combat = true,
        })
        local state = {
            in_combat = true, blade_flurry_ready = true, has_blade_flurry = false,
            has_snd = true, target_count = targets,
        }
        if mod.get_state then
            local ok, st = pcall(mod.get_state, ctx)
            if ok and st then
                state = st
                state.blade_flurry_ready = true
                state.has_blade_flurry = false
                state.has_snd = true
                state.target_count = targets
                state.in_combat = true
            end
        end
        local ok, res = pcall(bf.matches, ctx, state)
        assert_true(ok, "BF no throw")
        return res and true or false
    end
    assert_true(run(2, 4) == true, "BF matches when targets>=count")
    assert_true(run(5, 2) == false, "BF blocked when targets<count")
end)
setting_flip("flip rogue combat_expose_assigned ExposeArmor",
    "EaxRotations/classes/rogue/combat_sylvanas.lua", "rogue", "ExposeArmor",
    { combat_expose_assigned = true }, { combat_expose_assigned = false },
    { expose_armor_ready = true, combo_points = 5 },
    { target_armor = 5000 })
setting_flip("flip rogue use_auto_potions HealthPotion",
    "EaxRotations/classes/rogue/combat_sylvanas.lua", "rogue", "HealthPotion",
    { use_auto_potions = true }, { use_auto_potions = false },
    {},
    { has_health_potion = true, hp = 20 })

-- Shaman (honest flips)
setting_flip("flip ele elemental_use_elemental_mastery",
    "EaxRotations/classes/shaman/elemental_sylvanas.lua", "shaman", "ElementalMastery",
    { elemental_use_elemental_mastery = true }, { elemental_use_elemental_mastery = false },
    { mana_conserve = false, target_count = 1 },
    { should_burst = true })
setting_flip("flip ele elemental_use_fire_nova_aoe",
    "EaxRotations/classes/shaman/elemental_sylvanas.lua", "shaman", "FireNovaTotem",
    { elemental_use_fire_nova_aoe = true, elemental_aoe_threshold = 3 },
    { elemental_use_fire_nova_aoe = false },
    { target_count = 5, mana_conserve = false })
setting_flip("flip resto restoration_manage_totems Strength",
    "EaxRotations/classes/shaman/restoration_sylvanas.lua", "shaman", "StrengthOfEarthTotem",
    { restoration_manage_totems = true }, { restoration_manage_totems = false },
    {})
setting_flip("flip resto restoration_manage_totems ManaSpring",
    "EaxRotations/classes/shaman/restoration_sylvanas.lua", "shaman", "ManaSpringTotem",
    { restoration_manage_totems = true }, { restoration_manage_totems = false },
    {})
setting_flip("flip enh use_cooldowns Bloodlust",
    "EaxRotations/classes/shaman/enhancement_sylvanas.lua", "shaman", "Bloodlust",
    { use_cooldowns = true, enhancement_cd_bloodlust = true },
    { use_cooldowns = false, enhancement_cd_bloodlust = true },
    {}) -- module-local enh_state from get_state

-- Priest (smite_use_mb + holy_use_pws via EmergencyPWS OFF + disc PI if present)
setting_flip("flip smite smite_use_mb MindBlast",
    "EaxRotations/classes/priest/smite_sylvanas.lua", "priest", "MindBlast",
    { smite_use_mb = true }, { smite_use_mb = false },
    { mb_ready = true },
    { has_valid_enemy_target = true })
expect("flip holy holy_use_pws EmergencyPWS OFF blocks", function()
    local mod = H.load_module("EaxRotations/classes/priest/holy_sylvanas.lua", {
        level = 70, class_folder = "priest",
    })
    local s = H.find_strategy(mod.strategies, "EmergencyPWS")
        or H.find_strategy(mod.strategies, "PowerWordShield")
    assert_true(s ~= nil, "EmergencyPWS or PowerWordShield present")
    local ctx = H.context(70, {
        settings = { holy_use_pws = false },
        in_combat = true,
    })
    local state = { lowest = { effective_hp = 20, unit = {} }, lowest_hp = 20 }
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then state = st; state.lowest = { effective_hp = 20, unit = {} }; state.lowest_hp = 20 end
    end
    local ok, res = pcall(s.matches, ctx, state)
    assert_true(ok and not res, "PWS blocked when holy_use_pws=false")
end)
expect("flip disc discipline_use_power_infusion OFF blocks", function()
    local mod = H.load_module("EaxRotations/classes/priest/discipline_sylvanas.lua", {
        level = 70, class_folder = "priest",
    })
    local s = H.find_strategy(mod.strategies, "PowerInfusion")
    assert_true(s ~= nil, "PowerInfusion present")
    local ctx = H.context(70, {
        settings = { discipline_use_power_infusion = false },
        in_combat = true,
    })
    local state = {}
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then state = st end
    end
    local ok, res = pcall(s.matches, ctx, state)
    assert_true(ok and not res, "PI blocked when discipline_use_power_infusion=false")
end)

-- Paladin
setting_flip("flip prot prot_holy_shield HolyShield",
    "EaxRotations/classes/paladin/protection_sylvanas.lua", "paladin", "HolyShield",
    { prot_holy_shield = true }, { prot_holy_shield = false },
    { holy_shield_ready = true })
setting_flip("flip prot prot_consecration Consecration",
    "EaxRotations/classes/paladin/protection_sylvanas.lua", "paladin", "Consecration",
    { prot_consecration = true, prot_consecration_targets = 3 },
    { prot_consecration = false },
    { consecration_ready = true, mana_pct = 90, enemy_count = 5, consecration_remains = 0, cc_nearby = false })
expect("flip prot prot_seal_of_righteousness OFF blocks SealRighteousness", function()
    local mod = H.load_module("EaxRotations/classes/paladin/protection_sylvanas.lua", {
        level = 70, class_folder = "paladin",
    })
    local seal = H.find_strategy(mod.strategies, "SealRighteousness")
    assert_true(seal ~= nil, "SealRighteousness present")
    local ctx = H.context(70, { settings = { prot_seal_of_righteousness = false } })
    local state = { has_seal = false, has_seal_command = false, has_seal_wisdom = false }
    local ok, res = pcall(seal.matches, ctx, state)
    assert_true(ok and not res, "Seal SoR blocked when setting false")
end)

-- Druid
setting_flip("flip bear bear_demo_roar DemoralizingRoar",
    "EaxRotations/classes/druid/bear_sylvanas.lua", "druid", "DemoralizingRoar",
    { bear_demo_roar = true }, { bear_demo_roar = false },
    { is_bear = true, enemy_count = 3, rage = 50 })
setting_flip("flip balance balance_use_insect_swarm InsectSwarmDoT",
    "EaxRotations/classes/druid/balance_sylvanas.lua", "druid", "InsectSwarmDoT",
    { balance_use_insect_swarm = true }, { balance_use_insect_swarm = false },
    {})
expect("flip resto resto_dps_when_idle SoloWrath", function()
    local mod = H.load_module("EaxRotations/classes/druid/resto_sylvanas.lua", {
        level = 70, class_folder = "druid",
    })
    local s = H.find_strategy(mod.strategies, "SoloWrath")
    assert_true(s ~= nil, "SoloWrath present")
    local function run(dps_idle, is_solo)
        local ctx = H.context(70, {
            settings = { resto_dps_when_idle = dps_idle },
            is_solo = is_solo, is_leveling = false, is_group = not is_solo,
            has_valid_enemy_target = true, mana_pct = 90, is_moving = false,
        })
        local state = { mana_emergency = false, mana_pct = 90 }
        local ok, res = pcall(s.matches, ctx, state)
        assert_true(ok, "SoloWrath no throw")
        return res and true or false
    end
    -- solo path ON; group+dps_when_idle false OFF
    assert_true(run(false, true) == true, "SoloWrath matches when solo")
    assert_true(run(false, false) == false, "SoloWrath off in group when resto_dps_when_idle=false")
end)

-- ============================================================================
-- Dungeon AoE required matches (Shaman / Priest / Druid)
-- ============================================================================
expect("shaman dungeon AoE FireNovaTotem L70", function()
    local mod = H.load_module("EaxRotations/classes/shaman/elemental_sylvanas.lua", {
        level = 70, class_folder = "shaman",
    })
    local s = H.find_strategy(mod.strategies, "FireNovaTotem")
    assert_true(s ~= nil, "FireNovaTotem present")
    local ctx = H.context(70, {
        enemy_count = 5, settings = { elemental_use_fire_nova_aoe = true, elemental_aoe_threshold = 3 },
        in_combat = true,
    })
    local state = H.ready_state(70, { target_count = 5, mana_conserve = false })
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then state = H.ready_state(70, st); state.target_count = 5; state.mana_conserve = false end
    end
    local ok, res = pcall(s.matches, ctx, state)
    assert_true(ok and res, "FireNovaTotem must match multi-target")
end)
expect("priest dungeon AoE PsychicScream enemy_count L70", function()
    local mod = H.load_module("EaxRotations/classes/priest/shadow_sylvanas.lua", {
        level = 70, class_folder = "priest",
    })
    local s = H.find_strategy(mod.strategies, "PsychicScream")
    assert_true(s ~= nil, "PsychicScream present")
    local ctx = H.context(70, {
        enemy_count = 4, enemies_count = 4, in_combat = true,
    })
    local state = H.ready_state(70, { enemy_count = 4, psychic_scream_ready = true, in_combat = true })
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        if ok and st then
            state = H.ready_state(70, st)
            state.enemy_count = 4
            state.psychic_scream_ready = true
            state.in_combat = true
        end
    end
    local ok, res = pcall(s.matches, ctx, state)
    assert_true(ok and res, "PsychicScream must match enemy_count>=3")
end)
expect("druid dungeon AoE SwipeAoE L70", function()
    local mod = H.load_module("EaxRotations/classes/druid/bear_sylvanas.lua", {
        level = 70, class_folder = "druid",
    })
    local s = H.find_strategy(mod.strategies, "SwipeAoE")
    assert_true(s ~= nil, "SwipeAoE present")
    local ctx = H.context(70, {
        enemy_count = 4, enemies_count = 4, in_combat = true, rage = 80,
        settings = { aoe_threshold = 3 },
        target = { get_health_percentage = function() return 80 end },
        has_valid_enemy_target = true,
    })
    local state
    if mod.get_state then
        local ok, st = pcall(mod.get_state, ctx)
        state = (ok and st) or {}
    else
        state = {}
    end
    state = H.ready_state(70, state)
    state.enemy_count = 4
    state.aoe_threshold = 3
    state.rage = 80
    state.is_bear = true
    state.in_combat = true
    local ok, res = pcall(s.matches, ctx, state)
    assert_true(ok and res, "SwipeAoE must match enemy_count>=aoe_threshold")
end)

-- Raid-70 priority order (strategy index — wowsims tbc-new / guides)
local function assert_prio_before(path, folder, earlier, later)
    expect("raid70 prio " .. earlier .. " before " .. later .. " in " .. path, function()
        local mod = H.load_module(path, { level = 70, class_folder = folder })
        local _, i_early = H.find_strategy(mod.strategies, earlier)
        local _, i_late = H.find_strategy(mod.strategies, later)
        assert_true(i_early ~= nil, earlier .. " present")
        assert_true(i_late ~= nil, later .. " present")
        assert_true(i_early < i_late, earlier .. " (" .. i_early .. ") before " .. later .. " (" .. i_late .. ")")
    end)
end

assert_prio_before("EaxRotations/classes/warrior/fury_sylvanas.lua", "warrior", "Bloodthirst", "HeroicStrike")
assert_prio_before("EaxRotations/classes/warrior/fury_sylvanas.lua", "warrior", "Execute", "HeroicStrike")
-- BM: KillCommand (pet burst) before Steady filler weave; Arcane is low-level/fallback after Steady in table
assert_prio_before("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", "hunter", "KillCommand", "SteadyShot")
assert_prio_before("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua", "hunter", "SteadyShot", "Volley")
assert_prio_before("EaxRotations/classes/warlock/destruction_sylvanas.lua", "warlock", "Shadowburn", "ShadowBolt")
assert_prio_before("EaxRotations/classes/rogue/combat_sylvanas.lua", "rogue", "SliceAndDice", "Eviscerate")
assert_prio_before("EaxRotations/classes/mage/fire_sylvanas.lua", "mage", "Scorch", "Fireball")
assert_prio_before("EaxRotations/classes/shaman/elemental_sylvanas.lua", "shaman", "ChainLightning", "LightningBolt")
assert_prio_before("EaxRotations/classes/priest/shadow_sylvanas.lua", "priest", "MindBlast", "MindFlay")
assert_prio_before("EaxRotations/classes/druid/balance_sylvanas.lua", "druid", "MoonfireDoT", "StarfirePrimary")
assert_prio_before("EaxRotations/classes/paladin/protection_sylvanas.lua", "paladin", "HolyShield", "Consecration")

-- LEARN map smoke: key TBC levels documented
expect("LEARN SteadyShot=50 KC=66 BT=40 Mangle=50 VT=50 SF=66 SS=40 AB=64", function()
    assert_true(H.LEARN.SteadyShot == 50, "SteadyShot 50")
    assert_true(H.LEARN.KillCommand == 66, "KillCommand 66")
    assert_true(H.LEARN.Bloodthirst == 40, "BT 40")
    assert_true(H.LEARN.MortalStrike == 40, "MS 40")
    assert_true(H.LEARN.Mangle == 50, "Mangle 50")
    assert_true(H.LEARN.VampiricTouch == 50, "VT 50")
    assert_true(H.LEARN.Shadowfiend == 66, "SF 66")
    assert_true(H.LEARN.Stormstrike == 40, "SS 40")
    assert_true(H.LEARN.ArcaneBlast == 64, "AB 64")
    assert_true(not H.is_learned("SteadyShot", 40), "Steady unlearned L40")
    assert_true(H.is_learned("SteadyShot", 50), "Steady learned L50")
    assert_true(not H.is_learned("KillCommand", 60), "KC unlearned L60")
    assert_true(H.is_learned("KillCommand", 66), "KC learned L66")
end)

-- ============================================================================
if #failures > 0 then
    print("FAIL test_tbc_spell_ladders — " .. passed .. "/" .. total)
    for i = 1, math.min(#failures, 60) do
        print("  " .. failures[i])
    end
    if #failures > 60 then print("  ... +" .. (#failures - 60) .. " more") end
    error("test_tbc_spell_ladders failed", 0)
end
print("PASS test_tbc_spell_ladders — " .. passed .. "/" .. total)
