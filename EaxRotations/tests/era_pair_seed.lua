-- era_pair_seed.lua -- baseline era-mirror divergence table.
-- WHAT:  for each spec with era sibling files (sylvanas/vanilla/wotlk),
--        the strategy names present in one era but missing in a sibling
--        era file. Read by the era-pair audit
--        (run_era_pair_audit_tests.lua) as its reviewed allowlist
--        baseline: divergences outside this table fail the audit.
-- WHEN:  regenerated deliberately via
--        EaxRotations/tools/generate_era_pair_seed.py (local-only
--        manual step, like generate_buff_debuff_verification.py) and
--        committed together with the rotation change that re-baselines
--        it; consumed on every verify_all / pre-commit run.
-- WHY:   the WotLK rogue Kick-interrupt gap was found only by hand; the
--        seed pins the accepted divergence set so a strategy added to
--        one era without its siblings, or removed from one sibling,
--        fails loudly (same drift pattern as the scorecard/badge pins).
-- SAFETY: data table only; no code, no side effects.
--
-- SCAN SCOPE (documented, not silent):
--   * leveling_* files are era-specific teaching rotations, not mirror-
--     synced (see test_leveling_* suites) -- excluded by design.
--   * *_sod.lua is the separate SoD experiment (runes) -- excluded.
--   * TBC (sylvanas) sets fold in the class middleware's interrupt
--     registrations (register_interrupt_spell), since interrupts are a
--     class-baseline capability the middleware provides era-wide.
return {
    {
        spec = "druid/balance",
        missing_in = "sylvanas",
        names = { "Barkskin", "FaerieFire", "Innervate", "Starfall" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "druid/balance",
        missing_in = "vanilla",
        names = { "Barkskin", "Bash", "FaerieFire", "FeralCharge", "ForceOfNature", "Healthstone", "Innervate", "InnervateHealer", "InsectSwarmSpread", "ManaGem", "MoonfireSpread", "MoonkinForm", "MovingMoonfire", "PvP_Cyclone", "Starfall" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "druid/balance",
        missing_in = "wotlk",
        names = { "BarkskinDefense", "Bash", "FaerieFireDebuff", "FeralCharge", "Healthstone", "Hurricane", "InnervateHealer", "InnervateSelf", "InsectSwarmDoT", "InsectSwarmSpread", "ManaGem", "ManaPotion", "ManaPotionEmergency", "MarkOfTheWild", "MoonfireDoT", "MoonfireSpread", "MovingMoonfire", "PreHurricaneBarkskin", "PvP_Cyclone", "PvP_EntanglingRoots", "PvP_NaturesGrasp", "RebirthBattleRez", "RemoveCurse", "StarfirePrimary", "ThornsBuff", "WarStomp", "WrathFiller" },
        reason = "WotLK-era build-out: druid_balance_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "druid/bear",
        missing_in = "sylvanas",
        names = { "BarkskinBear", "Berserk", "Enrage", "FeralFaerieFire", "HealingPotion", "Healthstone", "SurvivalInstincts", "SwipeBear" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "druid/bear",
        missing_in = "vanilla",
        names = { "BarkskinBear", "Bash", "Berserk", "Enrage", "FeralCharge", "FeralChargePull", "FeralFaerieFire", "Lacerate", "MangleBear", "SurvivalInstincts", "SwipeBear" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "druid/bear",
        missing_in = "wotlk",
        names = { "Barkskin", "Bash", "BashInterrupt", "BearForm", "DemoralizingRoar", "EnrageCombat", "FaerieFireFeral", "FaerieFirePull", "FeralCharge", "FeralChargePull", "GiftOfTheWild", "HealingPotion", "Healthstone", "MarkOfTheWild", "PrePullEnrage", "Swipe", "SwipeAoE", "Thorns" },
        reason = "WotLK-era build-out: druid_bear_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "druid/caster",
        missing_in = "sylvanas",
        names = { "HealingTouch", "HealthPotion", "ManaPotion", "Rejuvenation" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "druid/caster",
        missing_in = "vanilla",
        names = { "Bash", "FeralCharge", "ForceOfNature", "HurricaneAoE", "PreHurricaneBarkskin", "RebirthBattleRez" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "druid/cat",
        missing_in = "sylvanas",
        names = { "Berserk", "MangleCat", "Ravage", "SavageRoar" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "druid/cat",
        missing_in = "vanilla",
        names = { "Bash", "Berserk", "BiteTrick", "EmergencyPowershift", "EngineeringBomb", "FeralCharge", "FeralChargeCat", "FerociousBiteTtd", "Healthstone", "MaimControl", "MaimInterrupt", "MangleCat", "MangleDebuff", "MangleFiller", "PoolForBuilderTick", "PoolForExecuteBite", "PoolForRip", "RakeTab", "Ravage", "RemoveCurse", "RipSnapshot", "RipTrick", "SavageRoar", "ShredTrick", "StealthMangle" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "druid/cat",
        missing_in = "wotlk",
        names = { "Barkskin", "Bash", "BiteTrick", "CatForm", "ClawFallback", "Dash", "EmergencyPowershift", "EngineeringBomb", "FaerieFireStealthLock", "FeralCharge", "FeralChargeCat", "FerociousBiteTtd", "HealthPotion", "Healthstone", "MaimControl", "ManaPotion", "MangleDebuff", "MangleFiller", "PoolForBuilderTick", "PoolForExecuteBite", "PoolForRip", "PounceOpener", "Powershift", "Prowl", "RakeSnapshot", "RakeTab", "RavageOpener", "RemoveCurse", "RipSnapshot", "RipTrick", "ShredTrick", "StealthMangle", "StealthShred", "TrackHumanoids", "TravelForm" },
        reason = "WotLK-era build-out: druid_cat_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "druid/resto",
        missing_in = "sylvanas",
        names = { "Innervate", "Lifebloom", "Nourish", "Rebirth", "Regrowth", "Rejuvenation", "Swiftmend", "Tranquility", "WildGrowth" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "druid/resto",
        missing_in = "vanilla",
        names = { "Bash", "CycloneEnemyHealer", "FSRPause", "FeralCharge", "Healthstone", "Innervate", "LeaveTreeForDirectHeal", "Lifebloom", "LifebloomLetBloom", "MovingLifebloom", "Nourish", "PreemptiveRegrowth", "RaidLifebloomCoverage", "Rebirth", "Regrowth", "Rejuvenation", "SecondRaidLifebloomCoverage", "Swiftmend", "TankLifebloomStack", "Tranquility", "TreeOfLifeMaintain", "WildGrowth" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "druid/resto",
        missing_in = "wotlk",
        names = { "AbolishPoison", "BarkskinSelfPreservation", "Bash", "BearFormFocusedByMelee", "CatFormRepositionFallback", "ClearcastRegrowth", "CycloneEnemyHealer", "DownrankHealingTouch", "EntanglingRootsMelee", "FSRPause", "FallbackHealingTouch", "FeralCharge", "FriendlyTarget", "HealingTouchMaxEmergency", "Healthstone", "InnervateHealer", "InnervateSelf", "LeaveTreeForDirectHeal", "LifebloomLetBloom", "ManaPotionFloor", "MovingLifebloom", "MovingRejuvenation", "NaturesGraspMelee", "PreemptiveRegrowth", "PriorityRejuvenation", "RaidLifebloomCoverage", "RebirthBattleRez", "RegrowthSpotHeal", "RemoveCurse", "SecondRaidLifebloomCoverage", "SoloInsectSwarm", "SoloMoonfire", "SoloWrath", "SwiftmendEmergency", "TankLifebloomStack", "TranquilityEmergency", "TravelFormReposition", "TreeOfLifeMaintain" },
        reason = "WotLK-era build-out: druid_resto_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "hunter/beast_mastery",
        missing_in = "sylvanas",
        names = { "AimedShot", "AspectOfTheDragonhawk", "AspectOfTheViper", "KillShot" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "hunter/beast_mastery",
        missing_in = "vanilla",
        names = { "AdaptiveRotation", "AspectOfTheDragonhawk", "AspectOfTheViper", "AutoAspect", "Deterrence", "Healthstone", "Intimidation", "KillCommand", "KillShot", "LevelingArcaneShot", "LevelingSting", "Misdirection", "Readiness", "ScatterShot", "SilencingShot", "SteadyShot" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "hunter/beast_mastery",
        missing_in = "wotlk",
        names = { "AdaptiveRotation", "AspectOfTheHawk_OOC", "AutoAspect", "CallPet", "ConcussiveShot", "Deterrence", "FeignDeath", "FreezingTrap", "HealthPotion", "Healthstone", "Intimidation", "LevelingArcaneShot", "LevelingSting", "ManaPotion", "MendPet", "Misdirection", "PetAggressive", "PetDefensive", "PetPassive", "RapidFire", "RaptorStrike", "Readiness", "RevivePet", "ScatterShot", "SerpentStingRefresh", "SilencingShot", "Trinket", "Volley" },
        reason = "WotLK-era build-out: hunter_beast_mastery_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "hunter/marksmanship",
        missing_in = "sylvanas",
        names = { "AimedShot", "AspectOfTheDragonhawk", "ChimeraShot", "ExplosiveTrap", "KillShot" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "hunter/marksmanship",
        missing_in = "vanilla",
        names = { "AdaptiveRotation", "AimedShot", "AimedShotWeave", "AspectOfTheDragonhawk", "AspectOfTheViper", "BestialWrath", "ChimeraShot", "Deterrence", "ExplosiveTrap", "Healthstone", "KillCommand", "KillShot", "RaptorStrike", "Readiness", "ScatterShot", "SilencingShot", "SteadyShot", "TrueshotAura", "WingClip" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "hunter/marksmanship",
        missing_in = "wotlk",
        names = { "AdaptiveRotation", "AimedShotPrepull", "AimedShotWeave", "AspectOfTheHawk", "BestialWrath", "CallPet", "Deterrence", "FeignDeath", "FreezingTrap", "HealthPotion", "Healthstone", "InCombatAimedShot", "KillCommand", "LevelingArcaneShot", "LevelingSting", "ManaPotion", "MendPet", "PetAggressive", "PetDefensive", "PetPassive", "RapidFire", "RaptorStrike", "Readiness", "RevivePet", "ScatterShot", "TrueshotAura", "ViperSting", "WingClip" },
        reason = "WotLK-era build-out: hunter_marksmanship_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "hunter/survival",
        missing_in = "sylvanas",
        names = { "AimedShot", "AspectOfTheDragonhawk", "BlackArrow", "ExplosiveShot", "ExplosiveShotProc", "KillShot" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "hunter/survival",
        missing_in = "vanilla",
        names = { "AdaptiveRotation", "AspectOfTheDragonhawk", "AspectOfTheViper", "BlackArrow", "Deterrence", "ExplosiveShot", "ExplosiveShotProc", "Healthstone", "ImmolationTrap", "KillCommand", "KillShot", "Misdirection", "MongooseBite", "Readiness", "ScatterShot", "SerpentStingRefresh", "SilencingShot", "SnakeTrap", "SteadyShot", "WyvernSting" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "hunter/survival",
        missing_in = "wotlk",
        names = { "AdaptiveRotation", "ArcaneShot", "AspectOfTheHawk", "CallPet", "ConcussiveShot", "Deterrence", "FeignDeath", "FreezingTrap", "HealthPotion", "Healthstone", "ImmolationTrap", "KillCommand", "LevelingArcaneShot", "LevelingSting", "ManaPotion", "MendPet", "Misdirection", "MongooseBite", "PetAggressive", "PetDefensive", "PetPassive", "RapidFire", "RaptorStrike", "Readiness", "RevivePet", "ScatterShot", "ScorpidSting", "SerpentStingRefresh", "SilencingShot", "SnakeTrap", "ViperSting", "Volley", "WingClip", "WyvernSting" },
        reason = "WotLK-era build-out: hunter_survival_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "mage/arcane",
        missing_in = "sylvanas",
        names = { "ArcaneBarrage", "ArcaneExplosion", "Frostbolt", "MageArmor", "MirrorImage" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "mage/arcane",
        missing_in = "vanilla",
        names = { "ArcaneBarrage", "ArcaneBlast", "Blink", "ColdSnap", "ColdSnapIVReset", "FireBlastExecute", "FrostboltConserve", "Healthstone", "IceBlock", "IcyVeins", "MageArmor", "MirrorImage", "Slow" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "mage/arcane",
        missing_in = "wotlk",
        names = { "ArcaneExplosion", "Blink", "ColdSnap", "ColdSnapIVReset", "FireBlast", "FireBlastExecute", "FireballLeveling", "FrostNova", "Frostbolt", "FrostboltConserve", "FrostboltLeveling", "Healthstone", "IceBarrier", "IceBlock", "ManaShield", "Polymorph", "Slow" },
        reason = "WotLK-era build-out: mage_arcane_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "mage/fire",
        missing_in = "sylvanas",
        names = { "BlastWaveAoE", "DragonsBreathAoE", "LivingBomb", "MirrorImage", "ScorchFinal" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "mage/fire",
        missing_in = "vanilla",
        names = { "BlastWave", "BlastWaveAoE", "DragonsBreath", "DragonsBreathAoE", "Healthstone", "LivingBomb", "MirrorImage", "ScorchFinal" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "mage/fire",
        missing_in = "wotlk",
        names = { "ArcaneExplosion", "BlastWave", "Blizzard", "DragonsBreath", "Flamestrike", "FlamestrikeRank6", "Healthstone", "IceBarrier", "ManaGem", "ManaGemConjure", "ManaPotion", "ManaShield", "Polymorph", "PresenceOfMind", "RemoveCurse" },
        reason = "WotLK-era build-out: mage_fire_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "mage/frost",
        missing_in = "sylvanas",
        names = { "DeepFreeze", "FrostfireBolt", "IceLance", "MirrorImage", "SummonWaterElemental" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "mage/frost",
        missing_in = "vanilla",
        names = { "Blink", "DeepFreeze", "FrostArmor", "FrostfireBolt", "FrozenIceLance", "Healthstone", "IceLance", "IcyVeins", "MageArmor", "MirrorImage", "SummonWaterElemental", "WaterElemental" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "mage/frost",
        missing_in = "wotlk",
        names = { "ArcaneExplosion", "ArcaneIntellect", "ArcaneMissiles", "Blink", "Blizzard", "ConeOfCold", "FrostArmor", "FrostNova", "FrostWard", "FrostbiteFrostbolt", "FrozenIceLance", "Healthstone", "IceBlock", "MageArmor", "ManaGem", "ManaGemConjure", "ManaPotion", "ManaShield", "Polymorph", "PresenceOfMind", "RemoveCurse", "Scorch", "WaterElemental", "WintersChill" },
        reason = "WotLK-era build-out: mage_frost_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "paladin/holy",
        missing_in = "sylvanas",
        names = { "BeaconOfLight", "DivineFavorHolyLight", "DivinePlea", "FlashOfLight", "HolyLight", "JudgementOfWisdom", "LayOnHands", "SacredShield", "SealOfWisdom" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "paladin/holy",
        missing_in = "vanilla",
        names = { "AvengingWrathHeavyHealing", "BeaconOfLight", "DivineFavorHolyLight", "DivineFavorHolyShockCombo", "DivineIlluminationHeavyHealing", "DivinePlea", "FSRPause", "FlashOfLight", "HammerOfJustice", "Healthstone", "HolyLight", "JudgementOfWisdom", "LayOnHands", "LightGraceBuild", "LightGraceChain", "Repentance", "SacredShield", "SealOfWisdom" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "paladin/holy",
        missing_in = "wotlk",
        names = { "AuraManagement", "AvengingWrathHeavyHealing", "BlessingOfFreedomSnare", "BlessingOfLightTank", "BlessingOfProtectionFocusedAlly", "BlessingOfSacrificeTank", "BlessingRefresh", "CleanseParty", "CleanseTankPriority", "ConsecrationSoloAoE", "DarkRune", "DivineFavor", "DivineFavorHolyLightFollowup", "DivineFavorHolyShockCombo", "DivineIlluminationHeavyHealing", "DivineShieldSelfPreservation", "FSRPause", "FlashOfLightEfficientTopoff", "FriendlyTarget", "HammerOfJustice", "HammerOfJusticeDiver", "HammerOfWrathSolo", "Healthstone", "HolyLightEmergency", "HolyShockSoloDamage", "JudgementOfLightBoss", "JudgementOfWisdomBoss", "JudgementSoloRighteousness", "LayOnHandsLastResort", "LightGraceBuild", "LightGraceChain", "ManaPotion", "PurifySelf", "Repentance", "SealOfLightBoss", "SealOfRighteousnessIdle", "SealOfRighteousnessSolo", "SealOfWisdomLowMana", "SmartHeal", "TankPreHeal" },
        reason = "WotLK-era build-out: paladin_holy_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "paladin/protection",
        missing_in = "sylvanas",
        names = { "AvengersShield", "DivinePlea", "HammerOfTheRighteous", "ShieldOfRighteousness" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "paladin/protection",
        missing_in = "vanilla",
        names = { "AvengerShield", "AvengersShield", "AvengingWrath", "BlessingOfKingsParty", "DivinePlea", "DivineProtection", "HammerOfTheRighteous", "Healthstone", "Repentance", "RighteousDefense", "SealOfCommandAoE", "ShieldOfRighteousness", "TurnEvil" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "paladin/protection",
        missing_in = "wotlk",
        names = { "AvengerShield", "AvengingWrath", "BlessingOfKingsParty", "BlessingOfProtectionAlly", "BlessingOfSanctuary", "Cleanse", "DevotionAura", "DivineProtection", "DivineShield", "Exorcism", "FlashOfLight", "HammerOfJustice", "HammerOfWrath", "Healthstone", "HolyLight", "HolyShock", "LayOnHands", "ManaPotion", "Repentance", "RighteousDefense", "SealOfCommandAoE", "SealOfWisdom", "SealRighteousness", "TurnEvil" },
        reason = "WotLK-era build-out: paladin_protection_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "paladin/retribution",
        missing_in = "sylvanas",
        names = { "AvengingWrath", "DivinePlea", "DivineStorm", "Exorcism", "HammerOfWrath", "Judgement", "SealOfCommand", "SealOfVengeance", "SealSwitch" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "paladin/retribution",
        missing_in = "vanilla",
        names = { "AvengingWrath", "CrusaderStrike", "DivinePlea", "DivineStorm", "Exorcism", "HammerOfJustice", "HammerOfWrath", "Judgement", "Repentance", "Ret_Cleanse_Self", "Ret_DivineShield_Emergency", "Ret_HammerWrath_Execute", "Ret_HealthstoneOrPotion", "Ret_LayOnHands_LastResort", "Ret_SanctityAura", "Ret_SealCommand_Primary", "SealOfCommand", "SealOfVengeance", "SealSwitch", "SealTwistBlood" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "paladin/retribution",
        missing_in = "wotlk",
        names = { "HammerOfJustice", "Repentance", "Ret_Cleanse_Self", "Ret_DivineShield_Emergency", "Ret_HammerWrath_Execute", "Ret_HealthstoneOrPotion", "Ret_LayOnHands_LastResort", "Ret_SanctityAura", "Ret_SealCommand_Primary", "SealTwistBlood", "SealTwistPrepCommand" },
        reason = "WotLK-era build-out: paladin_retribution_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "priest/discipline",
        missing_in = "sylvanas",
        names = { "DesperatePrayer", "FlashHeal", "Penance", "PowerWordShield", "PowerWordShieldLowest", "PrayerOfMending", "Renew" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "priest/discipline",
        missing_in = "vanilla",
        names = { "BindingHeal", "DesperatePrayer", "FSRPause", "FlashHeal", "ManaPotion", "MassDispel", "PainSuppression", "Penance", "PowerWordShield", "PrayerOfFortitude", "PrayerOfMending", "PrayerOfMendingTank", "PreemptiveGreaterHeal", "Renew", "Shadowfiend", "Silence", "SymbolOfHope" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "priest/discipline",
        missing_in = "wotlk",
        names = { "BindingHeal", "DispelMagic", "EmergencyFlashHeal", "EmergencyPowerWordShield", "FSRPause", "Fade", "FearWard", "FriendlyTarget", "Healthstone", "HolyFire", "IdleShadowWordPain", "IdleSmite", "InnerFire", "ManaPotion", "MassDispel", "PowerWordFortitude", "PowerWordShieldLowest", "PowerWordShieldTank", "PrayerOfFortitude", "PrayerOfHealing", "PrayerOfMendingTank", "PreHeal", "PreemptiveGreaterHeal", "PsychicScream", "RenewLowest", "RenewTank", "ShackleUndead", "Silence", "StopCast", "SymbolOfHope" },
        reason = "WotLK-era build-out: priest_discipline_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "priest/holy",
        missing_in = "sylvanas",
        names = { "DivineHymn", "GuardianSpirit", "HymnOfHope", "Renew", "UnavailableClassicPriestHealA" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "priest/holy",
        missing_in = "vanilla",
        names = { "BindingHeal", "CircleOfHealing", "ClearcastingGreaterHeal", "DivineHymn", "DivineSpirit", "FSRPause", "FearWard", "GuardianSpirit", "HymnOfHope", "InnerFire", "ManaPotion", "MassDispel", "PrayerOfMending", "PreemptiveGreaterHeal", "PsychicScream", "Renew", "ShackleUndead", "Shadowfiend", "Silence", "SurgeOfLightSmite", "SymbolOfHope" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "priest/holy",
        missing_in = "wotlk",
        names = { "AbolishDisease", "BindingHeal", "ClearcastingGreaterHeal", "CureDisease", "DispelMagic", "EmergencyFlashHeal", "EmergencyPWS", "EncounterReactions", "FSRPause", "Fade", "FearWard", "FriendlyTarget", "Healthstone", "IdleHolyFire", "IdleSWP", "IdleSmite", "InnerFocus", "ManaBelow5Wand", "ManaPotion", "MassDispel", "MountedProtection", "PrayerOfHealing", "PreHeal", "PreemptiveGreaterHeal", "PsychicScream", "RenewSpread", "RenewTank", "ShackleUndead", "Shadowfiend", "Silence", "StopCast", "SurgeOfLightSmite", "SymbolOfHope", "UnavailableClassicPriestHealA" },
        reason = "WotLK-era build-out: priest_holy_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "priest/shadow",
        missing_in = "sylvanas",
        names = { "ManaBelow5Wand", "MindSear" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "priest/shadow",
        missing_in = "vanilla",
        names = { "Healthstone", "ManaEmergencyWand", "MindSear", "MovingSWP", "MultiDotSWP", "MultiDotVT", "PowerWordFortitude", "PreCombatPull", "SWDCCBreak", "ShadowWordDeath", "Shadowfiend", "VTSpread", "VampiricTouch" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "priest/shadow",
        missing_in = "wotlk",
        names = { "DispelMagic", "Fade", "FlashHeal", "Healthstone", "HolyNovaAoE", "InnerFire", "InnerFocusMindBlast", "ManaBelow5Wand", "ManaEmergencyWand", "MovingSWP", "MultiDotSWP", "MultiDotVT", "PowerWordFortitude", "PowerWordShield", "PreCombatPull", "PsychicScream", "RacialArcaneTorrent", "RacialBerserking", "RacialBloodFury", "SWDCCBreak", "SWPSpread", "ShackleUndead", "Shadowform", "Starshards", "VTSpread", "VampiricEmbrace" },
        reason = "WotLK-era build-out: priest_shadow_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "priest/smite",
        missing_in = "vanilla",
        names = { "DivineSpirit", "Healthstone", "PowerWordFortitude", "PsychicScream", "ShackleUndead", "Silence" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "rogue/assassination",
        missing_in = "sylvanas",
        names = { "ColdBlood", "ColdBloodEviscerate", "Envenom", "FanOfKnives", "Garrote", "HungerForBlood", "KickInterrupt", "PvP_Blind", "Rupture", "TricksOfTheTrade" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "rogue/assassination",
        missing_in = "vanilla",
        names = { "AssassinationShivPurge", "BlindCC", "CloakOfShadows", "ColdBlood", "ColdBloodEnvenom", "DeadlyThrow", "Envenom", "EnvenomFinisher", "FanOfKnives", "Garrote", "HungerForBlood", "Kick", "Mutilate", "Rupture", "ShivRefresh", "SinisterStrikeFallback", "TricksOfTheTrade" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "rogue/assassination",
        missing_in = "wotlk",
        names = { "AssassinationShivPurge", "BlindCC", "CloakOfShadows", "ColdBloodEnvenom", "ColdBloodEviscerate", "DamagePotion", "DeadlyThrow", "EnvenomFinisher", "EvasionDefense", "EviscerateFallback", "ExposeArmor", "FeintAoE", "GarroteOpen", "HealingItem", "HealthPotion", "KickInterrupt", "KidneyShotCC", "LevelingSinisterStrike", "PvP_Blind", "PvP_CheapShotOpen", "PvP_SprintGapClose", "RuptureBleed", "ShivRefresh", "SinisterStrikeFallback", "Stealth", "ThistleTea", "VanishReopen" },
        reason = "WotLK-era build-out: rogue_assassination_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "rogue/combat",
        missing_in = "sylvanas",
        names = { "KillingSpree", "TricksOfTheTrade" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "rogue/combat",
        missing_in = "vanilla",
        names = { "Blind", "CheapShot", "Envenom", "Garrote", "KillingSpree", "ShivPurge", "TricksOfTheTrade" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "rogue/combat",
        missing_in = "wotlk",
        names = { "Backstab", "Blind", "CheapShot", "DamagePotion", "Envenom", "ExposeArmor", "Feint", "Garrote", "GhostlyStrike", "Gouge", "HealthPotion", "Hemorrhage", "KidneyShot", "ShivPurge", "Sprint", "Stealth", "Vanish" },
        reason = "WotLK-era build-out: rogue_combat_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "rogue/subtlety",
        missing_in = "sylvanas",
        names = { "ShadowDance" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "rogue/subtlety",
        missing_in = "vanilla",
        names = { "CloakOfShadows", "DeadlyThrow", "Healthstone", "ShadowDance", "Shadowstep", "ShadowstepHemorrhage", "ShadowstepOpener", "ShivPurge" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "rogue/subtlety",
        missing_in = "wotlk",
        names = { "Blind", "CheapShot", "CloakOfShadows", "DamagePotion", "DeadlyThrow", "Evasion", "EviscerateKill", "ExposeArmor", "Feint", "Garrote", "GhostlyStrike", "Gouge", "HealthPotion", "Healthstone", "HemorrhageDebuff", "KidneyShot", "Sap", "Shadowstep", "ShadowstepHemorrhage", "ShadowstepOpener", "ShivPurge", "SinisterStrikeFallback", "Sprint", "Stealth", "Vanish" },
        reason = "WotLK-era build-out: rogue_subtlety_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "shaman/elemental",
        missing_in = "sylvanas",
        names = { "FireElemental", "LavaBurst", "SearingTotem", "Thunderstorm", "WindShear" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "shaman/elemental",
        missing_in = "vanilla",
        names = { "Bloodlust", "ChainLightningSingleTarget", "FireElemental", "FlameShockMaintain", "Healthstone", "LavaBurst", "SearingTotem", "Thunderstorm", "TotemOfWrath", "WaterShield", "WindShear" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "shaman/elemental",
        missing_in = "wotlk",
        names = { "ChainHeal", "ChainLightningSingleTarget", "EarthShockMoving", "EarthbindTotem", "FireNovaTotem", "FlameShockMaintain", "FlameShockMoving", "FlametongueWeapon", "FrostShockMoving", "GhostWolf", "HealingWave", "Healthstone", "LightningShield", "MagmaTotem", "ManaEmergencyWand", "ManaPotion", "ManaSpringTotem", "ManaTideTotem", "NaturesSwiftness", "RockbiterWeapon", "TotemicCall", "TremorTotem", "WaterShield", "WindfuryWeapon", "WrathOfAirTotem" },
        reason = "WotLK-era build-out: shaman_elemental_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "shaman/enhancement",
        missing_in = "sylvanas",
        names = { "CallOfTheElements", "FeralSpirit", "FireNova", "FlametongueWeapon", "LavaLash", "MagmaTotem", "WindfuryWeapon" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "shaman/enhancement",
        missing_in = "vanilla",
        names = { "Bloodlust", "CallOfTheElements", "FeralSpirit", "FireNova", "FlametongueWeapon", "Healthstone", "LavaLash", "MagmaTotem", "Purge", "ShamanisticRage", "WaterShield", "WindfuryWeapon" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "shaman/enhancement",
        missing_in = "wotlk",
        names = { "AutoAttack", "Berserking", "BloodFury", "ChainHeal", "ChainLightning", "EarthTotem", "FireNovaReplacement", "FireTotem", "FrostShock", "GhostWolf", "GiftOfTheNaaru", "GraceOfAirTotemTwist", "GroundingTotem", "Healthstone", "LesserHealingWave", "MHWeaponBuff", "ManaEmergencyWand", "ManaPotion", "ManaTideTotem", "NaturesSwiftness", "OHWeaponBuff", "Purge", "TotemicCall", "TremorTotem", "WaterShield", "WaterTotem", "WindfuryTotemMaintain", "WindfuryTotemTwist" },
        reason = "WotLK-era build-out: shaman_enhancement_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "shaman/restoration",
        missing_in = "sylvanas",
        names = { "EarthShield", "HealingWave", "LesserHealingWave", "NaturesSwiftnessHealingWave", "Riptide", "TidalWavesHealingWave", "UnavailableClassicShamanBurst" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "shaman/restoration",
        missing_in = "vanilla",
        names = { "Bloodlust", "EarthShield", "EarthShieldTank", "FSRPause", "HealingWave", "Healthstone", "LesserHealingWave", "LesserHealingWaveEmergency", "NaturesSwiftnessHealingWave", "PreemptiveChainHeal", "Riptide", "TidalWavesHealingWave", "WaterShield" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "shaman/restoration",
        missing_in = "wotlk",
        names = { "Bloodlust", "ChainLightning", "CureDisease", "CurePoison", "DiseaseCleansingTotem", "EarthShieldTank", "EarthShock", "FSRPause", "FlameShock", "FriendlyTarget", "GraceOfAirTotem", "GroundingTotem", "HealingWay", "Healthstone", "LesserHealingWaveEmergency", "LightningBolt", "LightningShield", "ManaEmergencyWand", "ManaPotion", "ManaSpringTotem", "PoisonCleansingTotem", "PreemptiveChainHeal", "Purge", "SmartHeal", "StrengthOfEarthTotem", "TremorTotem", "UnavailableClassicShamanBurst", "WindfuryTotem" },
        reason = "WotLK-era build-out: shaman_restoration_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "warlock/affliction",
        missing_in = "sylvanas",
        names = { "Corruption", "DeathCoilSurvival", "DemonArmorBuff", "DrainSoul", "Haunt", "Healthstone", "PvP_Fear", "PvP_HowlOfTerror", "SeedOfCorruptionAoE", "ShadowBolt", "ShadowWard", "SummonInfernal" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "warlock/affliction",
        missing_in = "vanilla",
        names = { "CC_Fear", "CC_HowlOfTerror", "Corruption", "CorruptionSpread", "CurseFirst", "CurseOfAgonySpread", "CurseOfRecklessness", "CurseOfWeakness", "DrainSoul", "FelArmorBuff", "Haunt", "ImmolateSpread", "MovingCorruption", "RainOfFire", "SeedOfCorruption", "SeedOfCorruptionAoE", "ShadowBolt", "ShadowEmbraceMaintenance", "ShadowburnExecute", "SiphonLifeSpread", "SpellLock", "SummonFelhunter", "SummonInfernal", "UnstableAffliction", "UnstableAfflictionSpread" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "warlock/affliction",
        missing_in = "wotlk",
        names = { "AmplifyCurse", "CC_Fear", "CC_HowlOfTerror", "CorruptionDoT", "CorruptionSpread", "CurseFirst", "CurseOfAgonySpread", "CurseOfElements", "CurseOfRecklessness", "CurseOfWeakness", "DamagePotion", "DarkPact", "DeathCoilSurvival", "DemonArmorBuff", "DrainSoulExecute", "FelArmorBuff", "HealthFunnelPet", "Healthstone", "ImmolateDoT", "ImmolateSpread", "ManaPotion", "MovingCorruption", "PetAggressive", "PetDefensive", "PetPassive", "PreCombatPull", "PvP_CurseExhaustion", "PvP_CurseTongues", "PvP_Fear", "PvP_HowlOfTerror", "RacialArcaneTorrent", "RacialBerserking", "RacialBloodFury", "RainOfFire", "SeedOfCorruption", "SelfSoulstone", "ShadowBoltFiller", "ShadowEmbraceMaintenance", "ShadowWard", "ShadowburnExecute", "SiphonLife", "SiphonLifeSpread", "SpellLock", "SummonFelhunter", "UnstableAfflictionSpread", "Wand" },
        reason = "WotLK-era build-out: warlock_affliction_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "warlock/demonology",
        missing_in = "sylvanas",
        names = { "CorruptionDoT", "DeathCoilSurvival", "DemonArmorBuff", "DrainLife", "DrainSoulExecute", "HealthFunnelFallback", "Healthstone", "ImmolateDoT", "ImmolationAura", "IncinerateProc", "ManaPotion", "Metamorphosis", "PvP_CurseExhaustion", "PvP_CurseTongues", "PvP_Fear", "PvP_HowlOfTerror", "RacialBerserking", "RacialBloodFury", "SeedOfCorruptionAoE", "SelfSoulstone", "ShadowBoltFiller", "ShadowWard", "SoulFireDecimation", "Wand" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "warlock/demonology",
        missing_in = "vanilla",
        names = { "Corruption", "CurseOfRecklessness", "CurseOfWeakness", "DrainSoul", "Fear", "FelArmor", "Hellfire", "HowlofTerror", "Immolate", "ImmolationAura", "Incinerate", "IncinerateProc", "Metamorphosis", "RainOfFire", "Seduction", "SeedOfCorruption", "SeedOfCorruptionAoE", "ShadowBolt", "SoulFire", "SoulFireDecimation", "SoulLink", "SpellLock", "SummonFelguard", "SummonImp" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "warlock/demonology",
        missing_in = "wotlk",
        names = { "CorruptionDoT", "CurseOfElements", "CurseOfRecklessness", "CurseOfWeakness", "DamagePotion", "DarkPact", "DeathCoilSurvival", "DemonArmorBuff", "DrainLife", "DrainSoul", "DrainSoulExecute", "Fear", "FelArmor", "FelDomination", "HealthFunnel", "HealthFunnelFallback", "Healthstone", "Hellfire", "HowlofTerror", "ImmolateDoT", "Incinerate", "ManaPotion", "PetAggressive", "PetDefensive", "PetPassive", "PvP_CurseExhaustion", "PvP_CurseTongues", "PvP_Fear", "PvP_HowlOfTerror", "RacialBerserking", "RacialBloodFury", "RainOfFire", "Seduction", "SeedOfCorruption", "SelfSoulstone", "ShadowBoltFiller", "ShadowWard", "SiphonLife", "SoulLink", "SpellLock", "SummonFelguard", "SummonImp", "Wand" },
        reason = "WotLK-era build-out: warlock_demonology_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "warlock/destruction",
        missing_in = "sylvanas",
        names = { "ChaosBolt", "HealthPotion", "HellfireAoE", "ManaGem", "ShadowWard", "SoulFireBackdraft", "Trinket" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "warlock/destruction",
        missing_in = "vanilla",
        names = { "ChaosBolt", "CurseOfElements", "CurseOfRecklessness", "CurseOfWeakness", "DarkPact", "DemonicSacrifice", "FelArmor", "HellfireAoE", "Incinerate", "LifeTapMoving", "SeedOfCorruption", "Shadowfury", "SoulFireBackdraft", "SpellLock", "SummonFelguard" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "warlock/destruction",
        missing_in = "wotlk",
        names = { "BacklashShadowBolt", "Corruption", "CreateHealthstone", "CurseOfAgony", "CurseOfDoom", "CurseOfRecklessness", "CurseOfWeakness", "DarkPact", "DeathCoil", "DemonArmor", "DemonicSacrifice", "DrainLife", "Fear", "FelArmor", "FelDomination", "HealthFunnel", "HealthPotion", "Hellfire", "LifeTapMoving", "ManaGem", "RainOfFire", "SearingPain", "SeedOfCorruption", "ShadowBolt", "ShadowWard", "Shadowfury", "SpellLock", "SummonFelguard", "SummonFelhunter", "SummonImp", "SummonSuccubus", "SummonVoidwalker", "Trinket" },
        reason = "WotLK-era build-out: warlock_destruction_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "warrior/arms",
        missing_in = "sylvanas",
        names = { "Bladestorm" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "warrior/arms",
        missing_in = "vanilla",
        names = { "BerserkerRage", "Bladestorm", "CommandingShout", "EngineeringBomb", "SpellReflection", "VictoryRush" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "warrior/arms",
        missing_in = "wotlk",
        names = { "BerserkerRage", "Bloodrage", "CommandingShout", "DamagePotion", "DeathWish", "Disarm", "EngineeringBomb", "HealthPotion", "Healthstone", "IntimidatingShout", "PiercingHowl", "Recklessness", "SpellReflection", "SunderArmor", "VictoryRush", "Whirlwind" },
        reason = "WotLK-era build-out: warrior_arms_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "warrior/fury",
        missing_in = "sylvanas",
        names = { "HeroicThrow", "Rend" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "warrior/fury",
        missing_in = "vanilla",
        names = { "BattleStance", "BerserkerStance", "Charge", "EngineeringBomb", "Healthstone", "HeroicThrow", "Rampage", "Recklessness", "SwingDesync", "VictoryRush" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "warrior/fury",
        missing_in = "wotlk",
        names = { "BattleStance", "BerserkerRage", "Bloodrage", "Charge", "DamagePotion", "DemoralizingShout", "EngineeringBomb", "Hamstring", "HealthPotion", "Healthstone", "Intercept", "Overpower", "Rampage", "Rend", "SunderArmor", "SweepingStrikes", "SwingDesync", "VictoryRush" },
        reason = "WotLK-era build-out: warrior_fury_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
    {
        spec = "warrior/kebab",
        missing_in = "vanilla",
        names = { "BerserkerRage", "Bloodrage", "CommandingShout", "DeathWish", "Healthstone", "Pummel" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "warrior/protection",
        missing_in = "sylvanas",
        names = { "BerserkerStance", "Shockwave" },
        reason = "TBC covers this via the class middleware or a different strategy name; vanilla/wotlk-only strategy",
    },
    {
        spec = "warrior/protection",
        missing_in = "vanilla",
        names = { "BerserkerStance", "CommandingShout", "ConcussionBlow", "Devastate", "Healthstone", "Intervene", "RageDumpSafetyNet", "ShieldSlamPurge", "Shockwave", "SpellReflection", "StanceSwitch", "TauntSecondary", "VictoryRush", "WhirlwindMulti" },
        reason = "vanilla mirror implements the core rotation only; the TBC-era utility suite (consumables, PvP, hit-cap, spreads) is not mirrored",
    },
    {
        spec = "warrior/protection",
        missing_in = "wotlk",
        names = { "BattleShout", "BerserkerRage", "Bloodrage", "ChallengingShout", "Cleave", "CommandingShout", "ConcussionBlow", "DamagePotion", "DemoralizingShout", "Disarm", "Execute", "Hamstring", "HealthPotion", "Healthstone", "Intercept", "Intervene", "IntimidatingShout", "MockingBlow", "RageDumpSafetyNet", "Rend", "ShieldBash", "ShieldSlamPurge", "ShieldWall", "SpellReflection", "StanceSwitch", "SunderArmor", "Taunt", "TauntSecondary", "VictoryRush", "WhirlwindMulti" },
        reason = "WotLK-era build-out: warrior_protection_wotlk.lua is a minimal APL-mirror rotation; utility/PvP/consumable/defensive strategies are TBC/vanilla-era (see docs/scorecard.md WotLK rows)",
    },
}
