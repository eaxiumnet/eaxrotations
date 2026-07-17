-- test_wotlk_leveling_load.lua — WotLK leveling rotation load verification.
-- WHAT:  Loads every WotLK leveling rotation with a mocked NS and verifies registration.
-- WHEN:  During WotLK test suite execution.
-- WHY:   Regression guard for the 10-class WotLK leveling rotation rollout.
-- SAFETY: pure orchestration; no engine API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end

print("=== test_wotlk_leveling_load ===")

local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

local function make_spell_table()
    return {
        BattleStance = make_action(2457, "BattleStance"),
        BerserkerStance = make_action(2458, "BerserkerStance"),
        BattleShout = make_action(47436, "BattleShout"),
        CommandingShout = make_action(47439, "CommandingShout"),
        Charge = make_action(11578, "Charge"),
        Rend = make_action(47465, "Rend"),
        MortalStrike = make_action(47486, "MortalStrike"),
        Overpower = make_action(11585, "Overpower"),
        Execute = make_action(47498, "Execute"),
        Bladestorm = make_action(46924, "Bladestorm"),
        SweepingStrikes = make_action(12328, "SweepingStrikes"),
        Slam = make_action(47475, "Slam"),
        HeroicStrike = make_action(47497, "HeroicStrike"),
        ThunderClap = make_action(47502, "ThunderClap"),
        DemoralizingShout = make_action(47437, "DemoralizingShout"),
        Hamstring = make_action(25212, "Hamstring"),
        Pummel = make_action(6554, "Pummel"),
        Bloodthirst = make_action(30335, "Bloodthirst"),
        Whirlwind = make_action(1680, "Whirlwind"),
        DeathWish = make_action(12292, "DeathWish"),
        ShieldSlam = make_action(30356, "ShieldSlam"),
        Revenge = make_action(30357, "Revenge"),
        Devastate = make_action(30022, "Devastate"),
        ShieldBlock = make_action(2565, "ShieldBlock"),
        Judgement = make_action(20271, "Judgement"),
        CrusaderStrike = make_action(35395, "CrusaderStrike"),
        DivineStorm = make_action(53385, "DivineStorm"),
        Consecration = make_action(48819, "Consecration"),
        Exorcism = make_action(48801, "Exorcism"),
        HammerOfWrath = make_action(48807, "HammerOfWrath"),
        AvengingWrath = make_action(31884, "AvengingWrath"),
        SealOfVengeance = make_action(31801, "SealOfVengeance"),
        SealOfCommand = make_action(27170, "SealOfCommand"),
        BeaconOfLight = make_action(53563, "BeaconOfLight"),
        HolyShock = make_action(33074, "HolyShock"),
        FlashOfLight = make_action(27137, "FlashOfLight"),
        HolyLight = make_action(27136, "HolyLight"),
        SacredShield = make_action(53601, "SacredShield"),
        AvengersShield = make_action(48827, "AvengersShield"),
        HammerOfTheRighteous = make_action(53595, "HammerOfTheRighteous"),
        ShieldOfRighteousness = make_action(53600, "ShieldOfRighteousness"),
        ArcaneBlast = make_action(42897, "ArcaneBlast"),
        ArcaneMissiles = make_action(42846, "ArcaneMissiles"),
        ArcaneBarrage = make_action(44425, "ArcaneBarrage"),
        Evocation = make_action(12051, "Evocation"),
        ArcanePower = make_action(12042, "ArcanePower"),
        IcyVeins = make_action(12472, "IcyVeins"),
        MirrorImage = make_action(55342, "MirrorImage"),
        MageArmor = make_action(43024, "MageArmor"),
        Pyroblast = make_action(33938, "Pyroblast"),
        LivingBomb = make_action(44457, "LivingBomb"),
        Scorch = make_action(30455, "Scorch"),
        Fireball = make_action(33938, "Fireball"),
        Combustion = make_action(11129, "Combustion"),
        Frostbolt = make_action(27072, "Frostbolt"),
        FrostfireBolt = make_action(44614, "FrostfireBolt"),
        IceLance = make_action(30455, "IceLance"),
        DeepFreeze = make_action(44572, "DeepFreeze"),
        ColdSnap = make_action(12472, "ColdSnap"),
        KillCommand = make_action(34026, "KillCommand"),
        SerpentSting = make_action(27016, "SerpentSting"),
        SteadyShot = make_action(34120, "SteadyShot"),
        ArcaneShot = make_action(27019, "ArcaneShot"),
        BestialWrath = make_action(19574, "BestialWrath"),
        HuntersMark = make_action(14325, "HuntersMark"),
        ChimeraShot = make_action(53209, "ChimeraShot"),
        AimedShot = make_action(27065, "AimedShot"),
        KillShot = make_action(53351, "KillShot"),
        ExplosiveShot = make_action(53301, "ExplosiveShot"),
        BlackArrow = make_action(3674, "BlackArrow"),
        HungerForBlood = make_action(51662, "HungerForBlood"),
        Mutilate = make_action(34413, "Mutilate"),
        Envenom = make_action(32645, "Envenom"),
        Rupture = make_action(26867, "Rupture"),
        TricksOfTheTrade = make_action(57934, "TricksOfTheTrade"),
        SliceAndDice = make_action(6774, "SliceAndDice"),
        SinisterStrike = make_action(26862, "SinisterStrike"),
        Eviscerate = make_action(26865, "Eviscerate"),
        BladeFlurry = make_action(13877, "BladeFlurry"),
        KillingSpree = make_action(51690, "KillingSpree"),
        Premeditation = make_action(14183, "Premeditation"),
        ShadowDance = make_action(51713, "ShadowDance"),
        Ambush = make_action(27441, "Ambush"),
        Backstab = make_action(26863, "Backstab"),
        UnstableAffliction = make_action(30405, "UnstableAffliction"),
        Haunt = make_action(48181, "Haunt"),
        Corruption = make_action(27216, "Corruption"),
        CurseOfAgony = make_action(27218, "CurseOfAgony"),
        DrainSoul = make_action(27217, "DrainSoul"),
        ShadowBolt = make_action(27209, "ShadowBolt"),
        Metamorphosis = make_action(47241, "Metamorphosis"),
        Immolate = make_action(27215, "Immolate"),
        SoulFire = make_action(30545, "SoulFire"),
        ChaosBolt = make_action(50796, "ChaosBolt"),
        Incinerate = make_action(32231, "Incinerate"),
        Conflagrate = make_action(30912, "Conflagrate"),
        PowerWordShield = make_action(25218, "PowerWordShield"),
        Penance = make_action(47540, "Penance"),
        PrayerOfMending = make_action(33076, "PrayerOfMending"),
        Renew = make_action(25222, "Renew"),
        FlashHeal = make_action(25235, "FlashHeal"),
        GreaterHeal = make_action(25213, "GreaterHeal"),
        GuardianSpirit = make_action(47788, "GuardianSpirit"),
        VampiricTouch = make_action(34917, "VampiricTouch"),
        ShadowWordPain = make_action(25368, "ShadowWordPain"),
        DevouringPlague = make_action(25467, "DevouringPlague"),
        MindBlast = make_action(25375, "MindBlast"),
        MindFlay = make_action(25387, "MindFlay"),
        FlameShock = make_action(25457, "FlameShock"),
        LavaBurst = make_action(51505, "LavaBurst"),
        LightningBolt = make_action(25449, "LightningBolt"),
        ChainLightning = make_action(25442, "ChainLightning"),
        Thunderstorm = make_action(51490, "Thunderstorm"),
        Stormstrike = make_action(17364, "Stormstrike"),
        LavaLash = make_action(60103, "LavaLash"),
        FeralSpirit = make_action(51533, "FeralSpirit"),
        ShamanisticRage = make_action(30823, "ShamanisticRage"),
        Riptide = make_action(61295, "Riptide"),
        ChainHeal = make_action(25423, "ChainHeal"),
        HealingWave = make_action(25396, "HealingWave"),
        EarthShield = make_action(32594, "EarthShield"),
        MoonkinForm = make_action(24858, "MoonkinForm"),
        InsectSwarm = make_action(27013, "InsectSwarm"),
        Moonfire = make_action(26988, "Moonfire"),
        Starfall = make_action(48505, "Starfall"),
        Wrath = make_action(26985, "Wrath"),
        Starfire = make_action(26986, "Starfire"),
        MangleCat = make_action(33983, "MangleCat"),
        Rake = make_action(27003, "Rake"),
        Rip = make_action(27008, "Rip"),
        SavageRoar = make_action(52610, "SavageRoar"),
        FerociousBite = make_action(24248, "FerociousBite"),
        Shred = make_action(27002, "Shred"),
        MangleBear = make_action(33987, "MangleBear"),
        Lacerate = make_action(33745, "Lacerate"),
        SwipeBear = make_action(26997, "SwipeBear"),
        Maul = make_action(26996, "Maul"),
        FaerieFireFeral = make_action(27011, "FaerieFireFeral"),
        Rejuvenation = make_action(26982, "Rejuvenation"),
        WildGrowth = make_action(48438, "WildGrowth"),
        Regrowth = make_action(26980, "Regrowth"),
        Swiftmend = make_action(18562, "Swiftmend"),
        Lifebloom = make_action(33763, "Lifebloom"),
        -- Death Knight
        BloodStrike = make_action(45902, "BloodStrike"),
        DeathStrike = make_action(49998, "DeathStrike"),
        HeartStrike = make_action(55050, "HeartStrike"),
        IcyTouch = make_action(49802, "IcyTouch"),
        PlagueStrike = make_action(49917, "PlagueStrike"),
        Obliterate = make_action(49020, "Obliterate"),
        HowlingBlast = make_action(49184, "HowlingBlast"),
        ScourgeStrike = make_action(55090, "ScourgeStrike"),
        DeathCoil = make_action(47541, "DeathCoil"),
        Pestilence = make_action(50842, "Pestilence"),
        BloodBoil = make_action(49936, "BloodBoil"),
        DeathAndDecay = make_action(43265, "DeathAndDecay"),
        BoneShield = make_action(49222, "BoneShield"),
        IceboundFortitude = make_action(48792, "IceboundFortitude"),
        VampiricBlood = make_action(55233, "VampiricBlood"),
        DancingRuneWeapon = make_action(49028, "DancingRuneWeapon"),
        SummonGargoyle = make_action(49206, "SummonGargoyle"),
        EmpowerRuneWeapon = make_action(47568, "EmpowerRuneWeapon"),
        HornOfWinter = make_action(57330, "HornOfWinter"),
        MindFreeze = make_action(47528, "MindFreeze"),
        Strangulate = make_action(47476, "Strangulate"),
        DeathGrip = make_action(49576, "DeathGrip"),
        RaiseDead = make_action(46584, "RaiseDead"),
        ArmyOfTheDead = make_action(42650, "ArmyOfTheDead"),
        UnbreakableArmor = make_action(51271, "UnbreakableArmor"),
        AntiMagicShell = make_action(48707, "AntiMagicShell"),
        RuneStrike = make_action(56815, "RuneStrike"),
        DarkCommand = make_action(56222, "DarkCommand"),
    }
end

local registered = {}

local function make_ns(spell_table)
    return {
        WarriorSpells = spell_table,
        WarriorConstants = { STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 } },
        PaladinSpells = spell_table,
        HunterSpells = spell_table,
        RogueSpells = spell_table,
        WarlockSpells = spell_table,
        PriestSpells = spell_table,
        ShamanSpells = spell_table,
        DruidSpells = spell_table,
        MageSpells = spell_table,
        DeathKnightSpells = spell_table,
        DeathKnightConstants = { FROST_FEVER_DEBUFF = {}, BLOOD_PLAGUE_DEBUFF = {}, HORN_OF_WINTER_BUFF = {}, DISEASES = {} },
        PLAYER_UNIT = {},
        me = {
            get_health_percentage = function() return 80 end,
            get_mana_percentage = function() return 80 end,
            get_rage = function() return 50 end,
            get_energy = function() return 80 end,
            get_combo_points = function() return 3 end,
        },
        spell_action = function(ids, label)
            local id = type(ids) == "table" and ids[1] or ids
            return { id = id, name = label or tostring(id), cast_safe = function() return true end, cooldown_remaining = function() return 0 end, can_cast = function() return true end, is_learned = function() return true end }
        end,
        buff_up = function() return false end,
        buff_remains = function() return 0 end,
        buff_stacks = function() return 0 end,
        debuff_up = function() return false end,
        debuff_remains = function() return 0 end,
        GetPlayer = function(self) return self.me end,
        log = function() end,
        rotation_registry = {
            register = function(self, name, strategies, options)
                registered[name] = { strategies = strategies, options = options }
            end,
        },
    }
end

local leveling_files = {
    { file = "EaxRotations/classes/warrior/leveling_wotlk.lua", class = "warrior" },
    { file = "EaxRotations/classes/paladin/leveling_wotlk.lua", class = "paladin" },
    { file = "EaxRotations/classes/hunter/leveling_wotlk.lua", class = "hunter" },
    { file = "EaxRotations/classes/rogue/leveling_wotlk.lua", class = "rogue" },
    { file = "EaxRotations/classes/priest/leveling_wotlk.lua", class = "priest" },
    { file = "EaxRotations/classes/shaman/leveling_wotlk.lua", class = "shaman" },
    { file = "EaxRotations/classes/druid/leveling_wotlk.lua", class = "druid" },
    { file = "EaxRotations/classes/mage/leveling_wotlk.lua", class = "mage" },
    { file = "EaxRotations/classes/warlock/leveling_wotlk.lua", class = "warlock" },
    { file = "EaxRotations/classes/deathknight/leveling_wotlk.lua", class = "deathknight" },
}

local spell_table = make_spell_table()
local failures = {}
local passed = 0

-- Phase 2: each interrupt-equipped WotLK file must expose its interrupt strategy
-- (gated on target casting via helpers.should_interrupt).
local expected_interrupt = {
    warrior = "Pummel",
    rogue = "Kick",
    deathknight = "MindFreeze",
    shaman = "WindShear",
    mage = "Counterspell",
    hunter = "SilencingShot",
    warlock = "SpellLock",
}

-- Phase 2e: each rebuilt WotLK file must expose its primary AoE strategy.
local expected_aoe = {
    warrior = "Whirlwind",
    paladin = "DivineStorm",
    hunter = "Volley",
    rogue = "FanOfKnives",
    shaman = "ChainLightning",
    mage = "Blizzard",
    warlock = "RainOfFire",
    deathknight = "DeathAndDecay",
    druid = "Swipe",
}

for i = 1, #leveling_files do
    local entry = leveling_files[i]
    local ok, err = pcall(function()
        _G.EaxRotations = make_ns(spell_table)
        local mod = dofile(entry.file)
        assert_true(type(mod) == "table", entry.file .. " should return a table")
        assert_true(type(mod.strategies) == "table", entry.file .. " should expose strategies")
        assert_true(type(mod.build_state) == "function", entry.file .. " should expose build_state")
        assert_true(registered["leveling"] ~= nil, entry.file .. " should register under 'leveling'")
        local ctx = { in_combat = true, target = { get_health_percentage = function() return 50 end }, settings = {} }
        local state = mod.build_state(ctx)
        for _, s in ipairs(mod.strategies) do
            local m = s.matches(ctx, state)
            assert_true(m == true or m == false, entry.file .. " strategy " .. s.name .. " matches should return boolean")
        end
        -- Regression: WotLK build_state must honor the shared enemies_count field
        -- contract (the shared builder exposes enemies_count, not enemy_count).
        local aoe_ctx = { in_combat = true, enemies_count = 4, target = { get_health_percentage = function() return 50 end }, settings = {} }
        local aoe_state = mod.build_state(aoe_ctx)
        assert_true(aoe_state.enemy_count == 4, entry.file .. " build_state must read context.enemies_count (got " .. tostring(aoe_state.enemy_count) .. ")")
        -- Interrupt strategy presence (Phase 2).
        local want = expected_interrupt[entry.class]
        if want then
            local found = false
            for _, s in ipairs(mod.strategies) do
                if s.name == want then found = true; break end
            end
            assert_true(found, entry.file .. " must expose interrupt strategy " .. want)
        end
        -- AoE strategy presence (Phase 2e).
        local want_aoe = expected_aoe[entry.class]
        if want_aoe then
            local found_aoe = false
            for _, s in ipairs(mod.strategies) do
                if s.name == want_aoe then found_aoe = true; break end
            end
            assert_true(found_aoe, entry.file .. " must expose AoE strategy " .. want_aoe)
        end
        -- Druid feral form shifting must be present (setting-gated).
        if entry.class == "druid" then
            local has_cat, has_bear = false, false
            for _, s in ipairs(mod.strategies) do
                if s.name == "CatForm" then has_cat = true end
                if s.name == "DireBearForm" then has_bear = true end
            end
            assert_true(has_cat and has_bear, entry.file .. " must expose Cat/Bear form shifting")
        end
    end)
    if ok then
        passed = passed + 1
    else
        failures[#failures + 1] = entry.file .. ": " .. tostring(err)
    end
end

print("Tests: " .. passed .. "/" .. #leveling_files .. " passed")
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do print("  " .. f) end
    os.exit(1)
end
