"""
enrich_spells.py — Enrich all class_sylvanas.lua spell tables with TBC spell metadata.

Transforms each NS.spell_action({id1, id2, ...}, "Name") into the new rich format:
    NS.spell_action({
        name = "Name",
        ids = {id1, id2, ...},
        levels = {l1, l2, ...},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    })
"""

import os
import re
import json

ROOT = "EaxRotations/classes"
SKIP_DIRS = {"_backup", ".git", "__pycache__"}

# ============================================================================
# TBC SPELL DATABASE
# Format: "ClassName.SpellName" -> {
#     levels: [list of learn levels, newest-first matching ID order],
#     cast_time: float (0 = instant),
#     cooldown: float (0 = no CD),
#     power_cost: int (0 = free),
#     power_type: "mana"|"rage"|"energy"|"focus"|"none",
#     school: "physical"|"fire"|"frost"|"shadow"|"nature"|"arcane"|"holy"
# }
# ============================================================================

SPELL_DATA = {
    # ======== DRUID ========
    "Druid.Barkskin": {"levels": [48], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.Bash": {"levels": [62, 44, 16], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.BearForm": {"levels": [68, 10], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.CatForm": {"levels": [20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.ChallengingRoar": {"levels": [58], "cast_time": 0, "cooldown": 600, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.Claw": {"levels": [70, 60, 50, 40, 30, 22], "cast_time": 0, "cooldown": 0, "power_cost": 40, "power_type": "energy", "school": "physical"},
    "Druid.Cower": {"levels": [70, 60, 50, 38], "cast_time": 0, "cooldown": 0, "power_cost": 20, "power_type": "energy", "school": "physical"},
    "Druid.Cyclone": {"levels": [62], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.Dash": {"levels": [54, 30], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.DemoralizingRoar": {"levels": [60, 50, 40, 30, 20, 14], "cast_time": 0, "cooldown": 0, "power_cost": 10, "power_type": "rage", "school": "physical"},
    "Druid.Enrage": {"levels": [60, 50, 36], "cast_time": 0, "cooldown": 60, "power_cost": 5, "power_type": "rage", "school": "physical"},
    "Druid.EntanglingRoots": {"levels": [70, 60, 50, 40, 30, 20, 14], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.FaerieFire": {"levels": [56, 46, 30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.FaerieFireFeral": {"levels": [62], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.FeralCharge": {"levels": [70, 50], "cast_time": 0, "cooldown": 15, "power_cost": 10, "power_type": "rage", "school": "physical"},
    "Druid.FerociousBite": {"levels": [70, 60, 50, 40, 32], "cast_time": 0, "cooldown": 0, "power_cost": 35, "power_type": "energy", "school": "physical"},
    "Druid.ForceOfNature": {"levels": [70], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.GiftOfTheWild": {"levels": [70, 60, 50, 40], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.Growl": {"levels": [68, 58, 48, 38, 28, 16], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.HealingTouch": {"levels": [70, 60, 52, 42, 34, 26, 18, 8], "cast_time": 3.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.HealingTouchRank4": {"levels": [70, 60, 52, 42, 34, 26, 18, 8], "cast_time": 3.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.Hurricane": {"levels": [70, 60, 50, 40], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.Innervate": {"levels": [60], "cast_time": 0, "cooldown": 360, "power_cost": 0, "power_type": "none", "school": "nature"},
    "Druid.InsectSwarm": {"levels": [70, 60, 50, 40, 30, 22], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.Lacerate": {"levels": [70, 66], "cast_time": 0, "cooldown": 0, "power_cost": 15, "power_type": "rage", "school": "physical"},
    "Druid.Lifebloom": {"levels": [70, 64], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.Maim": {"levels": [70, 64], "cast_time": 0, "cooldown": 0, "power_cost": 30, "power_type": "energy", "school": "physical"},
    "Druid.MangleBear": {"levels": [70, 64], "cast_time": 0, "cooldown": 6, "power_cost": 15, "power_type": "rage", "school": "physical"},
    "Druid.MangleCat": {"levels": [70, 64], "cast_time": 0, "cooldown": 6, "power_cost": 45, "power_type": "energy", "school": "physical"},
    "Druid.MarkOfTheWild": {"levels": [60, 50, 40, 30, 20, 10, 4], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.Maul": {"levels": [70, 60, 50, 40, 30, 20, 12], "cast_time": 0, "cooldown": 0, "power_cost": 15, "power_type": "rage", "school": "physical"},
    "Druid.Moonfire": {"levels": [70, 60, 50, 40, 30, 20, 14], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "arcane"},
    "Druid.MoonkinForm": {"levels": [40], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.NaturesGrasp": {"levels": [60, 50, 40, 30, 18, 10], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.NaturesSwiftness": {"levels": [50], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "nature"},
    "Druid.Pounce": {"levels": [70, 60, 50, 42], "cast_time": 0, "cooldown": 0, "power_cost": 50, "power_type": "energy", "school": "physical"},
    "Druid.Prowl": {"levels": [26], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.Rake": {"levels": [70, 60, 50, 40, 30, 22], "cast_time": 0, "cooldown": 0, "power_cost": 40, "power_type": "energy", "school": "physical"},
    "Druid.Ravage": {"levels": [70, 60, 50, 40, 32], "cast_time": 0, "cooldown": 0, "power_cost": 60, "power_type": "energy", "school": "physical"},
    "Druid.Regrowth": {"levels": [70, 60, 50, 40, 30, 22, 12], "cast_time": 2.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.Rejuvenation": {"levels": [70, 60, 50, 40, 30, 20, 12, 4], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.RemoveCurse": {"levels": [48], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.AbolishPoison": {"levels": [46], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.Rip": {"levels": [70, 60, 50, 40, 32], "cast_time": 0, "cooldown": 0, "power_cost": 30, "power_type": "energy", "school": "physical"},
    "Druid.Shred": {"levels": [70, 60, 50, 40, 30, 22], "cast_time": 0, "cooldown": 0, "power_cost": 50, "power_type": "energy", "school": "physical"},
    "Druid.Starfire": {"levels": [70, 60, 50, 40, 30, 20, 10], "cast_time": 3.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "arcane"},
    "Druid.Swiftmend": {"levels": [60], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.SwipeBear": {"levels": [70, 60, 50, 40, 30, 22], "cast_time": 0, "cooldown": 0, "power_cost": 15, "power_type": "rage", "school": "physical"},
    "Druid.Thorns": {"levels": [60, 50, 40, 30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.TigersFury": {"levels": [70, 60, 50, 40, 30, 24], "cast_time": 0, "cooldown": 30, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.TrackHumanoids": {"levels": [14], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.Tranquility": {"levels": [70, 60, 50, 40, 30], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Druid.TravelForm": {"levels": [16], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.TreeOfLifeForm": {"levels": [60], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Druid.Wrath": {"levels": [70, 60, 50, 40, 30, 20, 10, 1], "cast_time": 2.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},

    # ======== HUNTER ========
    "Hunter.AimedShot": {"levels": [70, 62, 54, 46, 40, 34, 28], "cast_time": 3.0, "cooldown": 6, "power_cost": 0, "power_type": "focus", "school": "physical"},
    "Hunter.ArcaneShot": {"levels": [70, 60, 50, 42, 34, 28, 22, 16, 6], "cast_time": 0, "cooldown": 6, "power_cost": 0, "power_type": "focus", "school": "arcane"},
    "Hunter.AspectOfTheHawk": {"levels": [70, 64, 58, 52, 44, 36, 28, 20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Hunter.AspectOfTheViper": {"levels": [62], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Hunter.BestialWrath": {"levels": [50], "cast_time": 0, "cooldown": 120, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Hunter.CallPet": {"levels": [10], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Hunter.ExplosiveTrap": {"levels": [70, 60, 50, 40], "cast_time": 0, "cooldown": 15, "power_cost": 0, "power_type": "none", "school": "fire"},
    "Hunter.FeignDeath": {"levels": [32], "cast_time": 0, "cooldown": 30, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Hunter.FreezingTrap": {"levels": [68, 58, 48, 28], "cast_time": 0, "cooldown": 15, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Hunter.HuntersMark": {"levels": [62, 54, 44, 4], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Hunter.KillCommand": {"levels": [62], "cast_time": 0, "cooldown": 5, "power_cost": 0, "power_type": "focus", "school": "physical"},
    "Hunter.MendPet": {"levels": [70, 64, 58, 52, 44, 36, 28, 20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "focus", "school": "physical"},
    "Hunter.MultiShot": {"levels": [70, 62, 52, 42, 32, 24], "cast_time": 0, "cooldown": 10, "power_cost": 0, "power_type": "focus", "school": "physical"},
    "Hunter.RapidFire": {"levels": [26], "cast_time": 0, "cooldown": 300, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Hunter.Readiness": {"levels": [50], "cast_time": 0, "cooldown": 600, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Hunter.RevivePet": {"levels": [10], "cast_time": 2.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "physical"},
    "Hunter.SerpentSting": {"levels": [70, 64, 56, 48, 40, 32, 24, 16, 8, 4], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "focus", "school": "nature"},
    "Hunter.SteadyShot": {"levels": [62], "cast_time": 2.0, "cooldown": 0, "power_cost": 0, "power_type": "focus", "school": "physical"},
    "Hunter.ViperSting": {"levels": [60, 52, 44, 36, 28, 20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "focus", "school": "nature"},

    # ======== MAGE ========
    "Mage.ArcaneBlast": {"levels": [64], "cast_time": 2.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "arcane"},
    "Mage.ArcaneIntellect": {"levels": [70, 60, 50, 40, 30, 20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "arcane"},
    "Mage.ArcaneMissiles": {"levels": [70, 62, 52, 44, 36, 28, 20, 14, 8], "cast_time": 5.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "arcane"},
    "Mage.ArcanePower": {"levels": [40], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "arcane"},
    "Mage.BlastWave": {"levels": [70, 64, 56, 48, 40, 34, 28], "cast_time": 0, "cooldown": 45, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Mage.Blizzard": {"levels": [70, 62, 52, 44, 36, 28, 20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "frost"},
    "Mage.ColdSnap": {"levels": [48], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "frost"},
    "Mage.Combustion": {"levels": [50], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "fire"},
    "Mage.ConeOfCold": {"levels": [70, 64, 56, 48, 40, 34, 28], "cast_time": 0, "cooldown": 10, "power_cost": 0, "power_type": "mana", "school": "frost"},
    "Mage.Counterspell": {"levels": [24], "cast_time": 0, "cooldown": 24, "power_cost": 0, "power_type": "none", "school": "arcane"},
    "Mage.DragonsBreath": {"levels": [70, 64, 56, 50], "cast_time": 0, "cooldown": 15, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Mage.Evocation": {"levels": [20], "cast_time": 0, "cooldown": 480, "power_cost": 0, "power_type": "none", "school": "arcane"},
    "Mage.FireBlast": {"levels": [70, 60, 50, 42, 34, 28, 22, 14, 6], "cast_time": 0, "cooldown": 8, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Mage.Fireball": {"levels": [70, 62, 52, 44, 36, 28, 22, 16, 10, 6, 3, 1], "cast_time": 3.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Mage.Flamestrike": {"levels": [70, 62, 52, 42, 34, 26], "cast_time": 3.0, "cooldown": 15, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Mage.FlamestrikeRank6": {"levels": [70, 62, 52, 42, 34, 26], "cast_time": 3.0, "cooldown": 15, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Mage.FrostNova": {"levels": [70, 62, 52, 44, 36, 28, 20], "cast_time": 0, "cooldown": 25, "power_cost": 0, "power_type": "mana", "school": "frost"},
    "Mage.FrostWard": {"levels": [70, 60, 50, 40, 30], "cast_time": 0, "cooldown": 30, "power_cost": 0, "power_type": "mana", "school": "frost"},
    "Mage.Frostbolt": {"levels": [70, 62, 52, 44, 36, 28, 22, 16, 10, 6, 3, 1], "cast_time": 3.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "frost"},
    "Mage.IceBarrier": {"levels": [70, 62, 54, 46, 40], "cast_time": 0, "cooldown": 30, "power_cost": 0, "power_type": "mana", "school": "frost"},
    "Mage.IceBlock": {"levels": [50], "cast_time": 0, "cooldown": 300, "power_cost": 0, "power_type": "none", "school": "frost"},
    "Mage.IceLance": {"levels": [66], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "frost"},
    "Mage.IcyVeins": {"levels": [60], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "frost"},
    "Mage.MageArmor": {"levels": [70, 60, 50, 40], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "arcane"},
    "Mage.ManaShield": {"levels": [70, 60, 50, 40, 30, 22], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "arcane"},
    "Mage.MoltenArmor": {"levels": [60], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "fire"},
    "Mage.Polymorph": {"levels": [64, 56, 48, 8], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "arcane"},
    "Mage.PresenceOfMind": {"levels": [40], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "arcane"},
    "Mage.Pyroblast": {"levels": [70, 64, 56, 50, 44, 38, 32, 26, 20, 16], "cast_time": 6.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Mage.RemoveCurse": {"levels": [30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "arcane"},
    "Mage.Scorch": {"levels": [70, 60, 50, 42, 34, 28, 22, 6], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Mage.Slow": {"levels": [60], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "arcane"},
    "Mage.WaterElemental": {"levels": [50], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "mana", "school": "frost"},

    # ======== PALADIN ========
    "Paladin.AvengerShield": {"levels": [60], "cast_time": 0, "cooldown": 30, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.AvengingWrath": {"levels": [60], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Paladin.BlessingOfFreedom": {"levels": [34], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.BlessingOfKings": {"levels": [30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.BlessingOfLight": {"levels": [70, 60, 50, 40, 30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.BlessingOfMight": {"levels": [70, 60, 50, 40, 30, 20, 10, 4], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.BlessingOfProtection": {"levels": [34, 20], "cast_time": 0, "cooldown": 300, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.BlessingOfSacrifice": {"levels": [50, 38, 24, 10], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.BlessingOfWisdom": {"levels": [70, 60, 50, 40, 30, 20, 14, 8], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.Cleanse": {"levels": [48], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.ConcentrationAura": {"levels": [18], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Paladin.Consecration": {"levels": [70, 60, 50, 40, 30, 20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.CrusaderStrike": {"levels": [60], "cast_time": 0, "cooldown": 6, "power_cost": 0, "power_type": "mana", "school": "physical"},
    "Paladin.DevotionAura": {"levels": [70, 60, 50, 40, 30, 20, 12, 1], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Paladin.DivineFavor": {"levels": [50], "cast_time": 0, "cooldown": 120, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Paladin.DivineIllumination": {"levels": [60], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Paladin.DivineProtection": {"levels": [34, 20], "cast_time": 0, "cooldown": 300, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.DivineShield": {"levels": [50], "cast_time": 0, "cooldown": 300, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Paladin.Exorcism": {"levels": [70, 60, 50, 40, 30, 20, 12], "cast_time": 1.5, "cooldown": 15, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.FireResistanceAura": {"levels": [58, 42], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Paladin.FlashOfLight": {"levels": [70, 60, 50, 40, 30, 20, 12, 6], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.FrostResistanceAura": {"levels": [56, 40], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Paladin.GreaterBlessingOfKings": {"levels": [62], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.GreaterBlessingOfLight": {"levels": [70, 64, 56], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.GreaterBlessingOfWisdom": {"levels": [70, 64, 56], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.HammerOfJustice": {"levels": [60, 50, 40, 30], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.HammerOfWrath": {"levels": [70, 60, 50], "cast_time": 0, "cooldown": 6, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.HolyLight": {"levels": [70, 60, 50, 40, 30, 20, 12, 6], "cast_time": 2.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.HolyShield": {"levels": [60], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.HolyShock": {"levels": [70, 64, 60], "cast_time": 0, "cooldown": 6, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.Judgement": {"levels": [70, 60, 50, 40, 30, 20, 4], "cast_time": 0, "cooldown": 10, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.LayOnHands": {"levels": [70, 60, 50], "cast_time": 0, "cooldown": 3600, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Paladin.Purify": {"levels": [42], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.RighteousFury": {"levels": [70, 60, 50, 40, 30, 20, 16], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Paladin.Repentance": {"levels": [56], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.SanctityAura": {"levels": [50], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Paladin.SealOfBlood": {"levels": [64], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.SealOfCommand": {"levels": [30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.SealOfCommandRank1": {"levels": [30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.SealOfRighteousness": {"levels": [70, 60, 50, 40, 30, 20, 14], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.SealOfCrusader": {"levels": [70, 60, 50, 40, 30, 20, 14], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.SealOfWisdom": {"levels": [70, 60, 50, 40, 30, 22], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Paladin.ShadowResistanceAura": {"levels": [54, 38], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "holy"},

    # ======== PRIEST ========
    "Priest.BindingHeal": {"levels": [64], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.CircleofHealing": {"levels": [70, 64, 56, 50, 40], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.DevouringPlague": {"levels": [68, 60, 50, 40, 30, 20, 10], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Priest.DispelMagic": {"levels": [54, 30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.Fade": {"levels": [70, 60, 50, 40, 30, 20, 14], "cast_time": 0, "cooldown": 30, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Priest.FearWard": {"levels": [26], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.FlashHeal": {"levels": [68, 60, 52, 44, 36, 28, 20, 14, 8], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.GreaterHeal": {"levels": [66, 56, 48, 40, 32, 24], "cast_time": 3.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.HolyFire": {"levels": [70, 60, 50, 40, 34, 28, 22, 14], "cast_time": 1.5, "cooldown": 10, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.InnerFire": {"levels": [70, 60, 50, 40, 32, 24, 16, 6], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.InnerFocus": {"levels": [40], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "holy"},
    "Priest.MindBlast": {"levels": [70, 62, 54, 46, 38, 30, 24, 18, 12, 8, 4], "cast_time": 1.5, "cooldown": 8, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Priest.MindFlay": {"levels": [70, 62, 54, 46, 38, 30, 20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Priest.PowerWordFortitude": {"levels": [70, 60, 50, 40, 30, 20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.PowerWordShield": {"levels": [70, 62, 54, 46, 38, 30, 24, 18, 12, 8, 6, 1], "cast_time": 0, "cooldown": 15, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.PrayerOfHealing": {"levels": [70, 62, 54, 46, 38, 30], "cast_time": 3.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.PrayerofMending": {"levels": [68], "cast_time": 0, "cooldown": 10, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.PsychicScream": {"levels": [64, 56, 48, 14], "cast_time": 0, "cooldown": 30, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Priest.Renew": {"levels": [70, 62, 54, 46, 38, 30, 22, 16, 10, 6, 2], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.ShadowWordDeath": {"levels": [70, 62], "cast_time": 0, "cooldown": 12, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Priest.ShadowWordPain": {"levels": [70, 62, 52, 44, 36, 28, 20, 14, 10, 4], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Priest.Shadowfiend": {"levels": [66], "cast_time": 0, "cooldown": 300, "power_cost": 0, "power_type": "none", "school": "shadow"},
    "Priest.Shadowform": {"levels": [40], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "shadow"},
    "Priest.ShackleUndead": {"levels": [60, 50, 24], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.Smite": {"levels": [70, 62, 52, 44, 36, 28, 22, 16, 10, 6], "cast_time": 2.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "holy"},
    "Priest.Starshards": {"levels": [64, 56, 48, 40, 32, 24, 16], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "arcane"},
    "Priest.VampiricEmbrace": {"levels": [30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "shadow"},
    "Priest.VampiricTouch": {"levels": [70, 64, 56], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},

    # ======== ROGUE ========
    "Rogue.AdrenalineRush": {"levels": [50], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.Ambush": {"levels": [70, 62, 54, 46, 38, 30, 18], "cast_time": 0, "cooldown": 0, "power_cost": 60, "power_type": "energy", "school": "physical"},
    "Rogue.Backstab": {"levels": [70, 62, 52, 44, 36, 28, 20, 14, 8, 4], "cast_time": 0, "cooldown": 0, "power_cost": 60, "power_type": "energy", "school": "physical"},
    "Rogue.BladeFlurry": {"levels": [40], "cast_time": 0, "cooldown": 120, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.Blind": {"levels": [34], "cast_time": 0, "cooldown": 120, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.CheapShot": {"levels": [26], "cast_time": 0, "cooldown": 10, "power_cost": 50, "power_type": "energy", "school": "physical"},
    "Rogue.CloakOfShadows": {"levels": [62], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.ColdBlood": {"levels": [40], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.DeadlyThrow": {"levels": [66], "cast_time": 0, "cooldown": 15, "power_cost": 25, "power_type": "energy", "school": "physical"},
    "Rogue.Envenom": {"levels": [70, 62], "cast_time": 0, "cooldown": 0, "power_cost": 35, "power_type": "energy", "school": "nature"},
    "Rogue.Evasion": {"levels": [70, 22], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.Eviscerate": {"levels": [70, 62, 54, 46, 38, 30, 22, 14, 8, 1], "cast_time": 0, "cooldown": 0, "power_cost": 35, "power_type": "energy", "school": "physical"},
    "Rogue.ExposeArmor": {"levels": [70, 64, 56, 48, 40, 32], "cast_time": 0, "cooldown": 0, "power_cost": 25, "power_type": "energy", "school": "physical"},
    "Rogue.Feint": {"levels": [70, 62, 52, 44, 36, 28, 16], "cast_time": 0, "cooldown": 10, "power_cost": 20, "power_type": "energy", "school": "physical"},
    "Rogue.Garrote": {"levels": [70, 62, 52, 44, 36, 28, 14], "cast_time": 0, "cooldown": 0, "power_cost": 50, "power_type": "energy", "school": "physical"},
    "Rogue.GhostlyStrike": {"levels": [56], "cast_time": 0, "cooldown": 20, "power_cost": 40, "power_type": "energy", "school": "physical"},
    "Rogue.Gouge": {"levels": [68, 60, 50, 40, 30, 22], "cast_time": 0, "cooldown": 10, "power_cost": 45, "power_type": "energy", "school": "physical"},
    "Rogue.Hemorrhage": {"levels": [70, 62, 54, 40], "cast_time": 0, "cooldown": 0, "power_cost": 35, "power_type": "energy", "school": "physical"},
    "Rogue.Kick": {"levels": [24, 18, 12, 6], "cast_time": 0, "cooldown": 10, "power_cost": 25, "power_type": "energy", "school": "physical"},
    "Rogue.KidneyShot": {"levels": [60, 30], "cast_time": 0, "cooldown": 20, "power_cost": 25, "power_type": "energy", "school": "physical"},
    "Rogue.Mutilate": {"levels": [70, 64, 56, 48], "cast_time": 0, "cooldown": 0, "power_cost": 60, "power_type": "energy", "school": "physical"},
    "Rogue.Premeditation": {"levels": [56], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.Preparation": {"levels": [40], "cast_time": 0, "cooldown": 600, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.Rupture": {"levels": [70, 62, 52, 44, 36, 28, 20], "cast_time": 0, "cooldown": 0, "power_cost": 25, "power_type": "energy", "school": "physical"},
    "Rogue.Sap": {"levels": [62, 52, 24], "cast_time": 0, "cooldown": 10, "power_cost": 45, "power_type": "energy", "school": "physical"},
    "Rogue.Shadowstep": {"levels": [70], "cast_time": 0, "cooldown": 30, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.Shiv": {"levels": [28], "cast_time": 0, "cooldown": 0, "power_cost": 20, "power_type": "energy", "school": "physical"},
    "Rogue.SinisterStrike": {"levels": [70, 62, 52, 44, 36, 28, 20, 14, 8, 1], "cast_time": 0, "cooldown": 0, "power_cost": 45, "power_type": "energy", "school": "physical"},
    "Rogue.SliceAndDice": {"levels": [60, 30], "cast_time": 0, "cooldown": 0, "power_cost": 25, "power_type": "energy", "school": "physical"},
    "Rogue.Sprint": {"levels": [64, 54, 22], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.Stealth": {"levels": [60, 50, 40, 30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.ThistleTea": {"levels": [30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Rogue.Vanish": {"levels": [70, 40, 22], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "physical"},

    # ======== SHAMAN ========
    "Shaman.Bloodlust": {"levels": [68], "cast_time": 0, "cooldown": 600, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.ChainHeal": {"levels": [70, 62, 52, 44, 40], "cast_time": 2.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.ChainLightning": {"levels": [70, 62, 52, 44, 36, 28], "cast_time": 2.5, "cooldown": 6, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.EarthbindTotem": {"levels": [26], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.EarthShield": {"levels": [70, 64, 62], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.EarthShock": {"levels": [70, 62, 52, 44, 36, 28, 22, 14], "cast_time": 0, "cooldown": 6, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.ElementalMastery": {"levels": [50], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "nature"},
    "Shaman.FireNovaTotem": {"levels": [70, 60, 50, 40, 30, 20], "cast_time": 0, "cooldown": 3, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Shaman.FlameShock": {"levels": [70, 64, 56, 48, 40, 30, 22], "cast_time": 0, "cooldown": 6, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Shaman.FrostShock": {"levels": [70, 62, 52, 44, 36], "cast_time": 0, "cooldown": 6, "power_cost": 0, "power_type": "mana", "school": "frost"},
    "Shaman.GhostWolf": {"levels": [20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Shaman.GraceOfAirTotem": {"levels": [70, 60, 48], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.GroundingTotem": {"levels": [32], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.HealingWave": {"levels": [70, 64, 58, 50, 42, 34, 26, 18, 12, 6, 1], "cast_time": 3.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.LesserHealingWave": {"levels": [68, 60, 50, 42, 34, 26, 18], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.LightningBolt": {"levels": [70, 62, 54, 46, 38, 30, 22, 14, 8, 4, 1], "cast_time": 3.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.LightningShield": {"levels": [70, 62, 52, 44, 36, 28, 20, 14, 1], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.ManaSpringTotem": {"levels": [70, 60, 50, 40, 30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.ManaTideTotem": {"levels": [60], "cast_time": 0, "cooldown": 300, "power_cost": 0, "power_type": "none", "school": "nature"},
    "Shaman.NaturesSwiftness": {"levels": [40], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "nature"},
    "Shaman.Purge": {"levels": [58, 22], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.ShamanisticRage": {"levels": [50], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Shaman.Stormstrike": {"levels": [50], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "physical"},
    "Shaman.StrengthOfEarthTotem": {"levels": [70, 62, 54, 44, 34], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.TremorTotem": {"levels": [18], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "nature"},
    "Shaman.WaterShield": {"levels": [66, 60], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "nature"},
    "Shaman.WindfuryTotem": {"levels": [70, 60, 50, 42], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "physical"},

    # ======== WARLOCK ========
    "Warlock.Banish": {"levels": [62, 30], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.Conflagrate": {"levels": [70, 64, 56], "cast_time": 0, "cooldown": 10, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Warlock.Corruption": {"levels": [70, 62, 54, 46, 38, 30, 22, 14, 8, 4], "cast_time": 2.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.CurseOfAgony": {"levels": [70, 62, 54, 46, 38, 30, 22, 14, 8, 4], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.CurseOfDoom": {"levels": [70, 64, 56], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.CurseOfElements": {"levels": [48, 34, 20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.CurseOfRecklessness": {"levels": [42, 24], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.CurseOfShadow": {"levels": [48], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.CurseOfTongues": {"levels": [28], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.CurseOfWeakness": {"levels": [56, 44, 32, 20, 10, 4], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.DarkPact": {"levels": [56], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "shadow"},
    "Warlock.DeathCoil": {"levels": [70, 62, 54, 48], "cast_time": 0, "cooldown": 120, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.DemonicSacrifice": {"levels": [40], "cast_time": 0, "cooldown": 1800, "power_cost": 0, "power_type": "none", "school": "shadow"},
    "Warlock.DrainLife": {"levels": [70, 62, 52, 44, 36, 28, 20, 14, 8], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.DrainMana": {"levels": [42, 30, 14], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.DrainSoul": {"levels": [70, 62, 52, 44, 36, 28, 20, 10], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.Fear": {"levels": [60, 50, 40, 30], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.Hellfire": {"levels": [70, 60, 50, 40, 30, 20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Warlock.HowlOfTerror": {"levels": [64, 50, 40], "cast_time": 0, "cooldown": 40, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.Immolate": {"levels": [70, 62, 52, 44, 36, 28, 20, 12, 6], "cast_time": 2.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Warlock.HealthFunnel": {"levels": [70, 60, 50, 40, 30, 20, 12, 6], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "shadow"},
    "Warlock.Healthstone": {"levels": [70, 60, 50, 40, 30, 20, 10], "cast_time": 3.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.Immolate": {"levels": [70, 62, 52, 44, 36, 28, 20, 12, 6], "cast_time": 2.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Warlock.LifeTap": {"levels": [70, 62, 52, 44, 36, 28, 20, 12, 6], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "shadow"},
    "Warlock.RitualOfSummoning": {"levels": [40], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.SeedOfCorruption": {"levels": [68], "cast_time": 2.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.ShadowBolt": {"levels": [70, 62, 52, 44, 36, 28, 20, 14, 8, 4, 1], "cast_time": 3.0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.Shadowburn": {"levels": [70, 62, 54, 48], "cast_time": 0, "cooldown": 15, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.ShadowFury": {"levels": [70], "cast_time": 2.0, "cooldown": 20, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.SiphonLife": {"levels": [70, 62, 54, 46, 38, 30, 20], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.SoulFire": {"levels": [70, 62, 52, 42], "cast_time": 6.0, "cooldown": 60, "power_cost": 0, "power_type": "mana", "school": "fire"},
    "Warlock.SoulLink": {"levels": [50], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "shadow"},
    "Warlock.Soulshatter": {"levels": [50], "cast_time": 0, "cooldown": 300, "power_cost": 0, "power_type": "none", "school": "shadow"},
    "Warlock.SummonFelguard": {"levels": [50], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.UnendingBreath": {"levels": [22], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},
    "Warlock.UnstableAffliction": {"levels": [70, 64, 56], "cast_time": 1.5, "cooldown": 0, "power_cost": 0, "power_type": "mana", "school": "shadow"},

    # ======== WARRIOR ========
    "Warrior.BattleShout": {"levels": [70, 62, 54, 46, 38, 30, 22, 14], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.BattleStance": {"levels": [1], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.BerserkerRage": {"levels": [38], "cast_time": 0, "cooldown": 30, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.BerserkerStance": {"levels": [30], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.Bloodrage": {"levels": [8], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.Bloodthirst": {"levels": [70, 64, 58, 52, 46, 40], "cast_time": 0, "cooldown": 6, "power_cost": 30, "power_type": "rage", "school": "physical"},
    "Warrior.ChallengingShout": {"levels": [58], "cast_time": 0, "cooldown": 600, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.Charge": {"levels": [62, 32, 4], "cast_time": 0, "cooldown": 15, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.Cleave": {"levels": [66, 56, 46, 36, 26, 16], "cast_time": 0, "cooldown": 0, "power_cost": 20, "power_type": "rage", "school": "physical"},
    "Warrior.CommandingShout": {"levels": [62], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.ConcussionBlow": {"levels": [44], "cast_time": 0, "cooldown": 30, "power_cost": 15, "power_type": "rage", "school": "physical"},
    "Warrior.DeathWish": {"levels": [50], "cast_time": 0, "cooldown": 180, "power_cost": 10, "power_type": "rage", "school": "physical"},
    "Warrior.DefensiveStance": {"levels": [10], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.DemoralizingShout": {"levels": [68, 60, 52, 44, 36, 28, 12], "cast_time": 0, "cooldown": 0, "power_cost": 10, "power_type": "rage", "school": "physical"},
    "Warrior.Devastate": {"levels": [70, 62, 50], "cast_time": 0, "cooldown": 0, "power_cost": 15, "power_type": "rage", "school": "physical"},
    "Warrior.Disarm": {"levels": [26], "cast_time": 0, "cooldown": 60, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.Execute": {"levels": [60, 50, 42, 36, 30, 24, 20], "cast_time": 0, "cooldown": 0, "power_cost": 15, "power_type": "rage", "school": "physical"},
    "Warrior.VictoryRush": {"levels": [64], "cast_time": 0, "cooldown": 0, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.HeroicStrike": {"levels": [68, 60, 52, 44, 36, 28, 20, 14, 10, 6, 1], "cast_time": 0, "cooldown": 0, "power_cost": 15, "power_type": "rage", "school": "physical"},
    "Warrior.Hamstring": {"levels": [60, 40, 24, 8], "cast_time": 0, "cooldown": 0, "power_cost": 10, "power_type": "rage", "school": "physical"},
    "Warrior.Intercept": {"levels": [68, 60, 50, 40], "cast_time": 0, "cooldown": 30, "power_cost": 10, "power_type": "rage", "school": "physical"},
    "Warrior.Pummel": {"levels": [18], "cast_time": 0, "cooldown": 10, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.LastStand": {"levels": [50], "cast_time": 0, "cooldown": 180, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.MockingBlow": {"levels": [56, 46, 36, 22], "cast_time": 0, "cooldown": 120, "power_cost": 10, "power_type": "rage", "school": "physical"},
    "Warrior.MortalStrike": {"levels": [70, 64, 56, 52, 48, 40], "cast_time": 0, "cooldown": 6, "power_cost": 30, "power_type": "rage", "school": "physical"},
    "Warrior.Overpower": {"levels": [64, 48, 32], "cast_time": 0, "cooldown": 5, "power_cost": 5, "power_type": "rage", "school": "physical"},
    "Warrior.Rampage": {"levels": [70, 62, 52], "cast_time": 0, "cooldown": 0, "power_cost": 30, "power_type": "rage", "school": "physical"},
    "Warrior.Rend": {"levels": [64, 54, 44, 34, 24, 4], "cast_time": 0, "cooldown": 0, "power_cost": 10, "power_type": "rage", "school": "physical"},
    "Warrior.Revenge": {"levels": [70, 64, 56, 48, 40, 32, 24, 14], "cast_time": 0, "cooldown": 5, "power_cost": 5, "power_type": "rage", "school": "physical"},
    "Warrior.ShieldBlock": {"levels": [16], "cast_time": 0, "cooldown": 5, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.ShieldBash": {"levels": [58, 40, 20], "cast_time": 0, "cooldown": 12, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.ShieldSlam": {"levels": [70, 62, 54, 46, 40], "cast_time": 0, "cooldown": 6, "power_cost": 20, "power_type": "rage", "school": "physical"},
    "Warrior.ShieldWall": {"levels": [34], "cast_time": 0, "cooldown": 600, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.Slam": {"levels": [68, 60, 50, 40, 30, 18], "cast_time": 1.5, "cooldown": 0, "power_cost": 15, "power_type": "rage", "school": "physical"},
    "Warrior.SpellReflection": {"levels": [62], "cast_time": 0, "cooldown": 10, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.SunderArmor": {"levels": [68, 58, 48, 38, 28, 14], "cast_time": 0, "cooldown": 0, "power_cost": 15, "power_type": "rage", "school": "physical"},
    "Warrior.SweepingStrikes": {"levels": [40], "cast_time": 0, "cooldown": 30, "power_cost": 30, "power_type": "rage", "school": "physical"},
    "Warrior.Taunt": {"levels": [10], "cast_time": 0, "cooldown": 8, "power_cost": 0, "power_type": "none", "school": "physical"},
    "Warrior.ThunderClap": {"levels": [68, 60, 52, 44, 36, 28, 6], "cast_time": 0, "cooldown": 4, "power_cost": 20, "power_type": "rage", "school": "physical"},
    "Warrior.Whirlwind": {"levels": [36], "cast_time": 0, "cooldown": 10, "power_cost": 25, "power_type": "rage", "school": "physical"},
}

# ============================================================================
# CLASS MAPPING: file name prefix -> class name for spell lookup
# ============================================================================

CLASS_MAP = {
    "druid": "Druid",
    "hunter": "Hunter",
    "mage": "Mage",
    "paladin": "Paladin",
    "priest": "Priest",
    "rogue": "Rogue",
    "shaman": "Shaman",
    "warlock": "Warlock",
    "warrior": "Warrior",
}


def format_rich_spell(name, ids_list, data):
    """Format a spell_action call with rich metadata."""
    if data:
        levels_str = ", ".join(str(l) for l in data["levels"])
        return (
            f"    {name} = NS.spell_action({{\n"
            f"        name = \"{name}\",\n"
            f"        ids = {{{', '.join(str(i) for i in ids_list)}}},\n"
            f"        levels = {{{levels_str}}},\n"
            f"        cast_time = {data['cast_time']},\n"
            f"        cooldown = {data['cooldown']},\n"
            f"        power_cost = {data['power_cost']},\n"
            f"        power_type = \"{data['power_type']}\",\n"
            f"        school = \"{data['school']}\",\n"
            f"    }}),\n"
        )
    else:
        # No data available, keep old format
        ids_str = "{" + ", ".join(str(i) for i in ids_list) + "}"
        return f"    {name} = NS.spell_action({ids_str}, \"{name}\"),\n"


def process_class_file(class_dir):
    """Process a single class_sylvanas.lua file, enriching spell data."""
    filepath = os.path.join(ROOT, class_dir, "class_sylvanas.lua")
    if not os.path.exists(filepath):
        print(f"  SKIP: {filepath} not found")
        return False

    class_name = CLASS_MAP.get(class_dir, class_dir.capitalize())
    
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Find the SPELLS table and parse spell_action calls
    # Pattern: SpellName = NS.spell_action({id1, id2, ...}, "SpellName"),
    spell_pattern = re.compile(
        r'^(\s{4})(\w+)\s*=\s*NS\.spell_action\(\s*\{([^}]+)\}\s*,\s*"(\w+)"\s*\)\s*,?\s*$',
        re.MULTILINE
    )
    
    # Also handle single-ID format: NS.spell_action(id, "Name")
    single_pattern = re.compile(
        r'^(\s{4})(\w+)\s*=\s*NS\.spell_action\(\s*(\d+)\s*,\s*"(\w+)"\s*\)\s*,?\s*$',
        re.MULTILINE
    )

    lines = content.split("\n")
    new_lines = []
    changes = 0
    skipped = 0
    
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Check for single-ID format first
        m = single_pattern.match(line)
        if m:
            indent = m.group(1)
            name = m.group(2)
            spell_id = int(m.group(3))
            label = m.group(4)
            
            lookup_key = f"{class_name}.{name}"
            data = SPELL_DATA.get(lookup_key)
            
            if data:
                new_lines.append(format_rich_spell(name, [spell_id], data).rstrip("\n"))
                changes += 1
            else:
                new_lines.append(line)
                skipped += 1
            i += 1
            continue
        
        # Check for multi-ID format
        m = spell_pattern.match(line)
        if m:
            indent = m.group(1)
            name = m.group(2)
            ids_str = m.group(3)
            label = m.group(4)
            
            ids_list = [int(x.strip()) for x in ids_str.split(",") if x.strip()]
            
            lookup_key = f"{class_name}.{name}"
            data = SPELL_DATA.get(lookup_key)
            
            # If not found, try with Immolate/Immolate variation
            if not data:
                # Warlock has both Immolate and Immolate
                pass
            
            if data:
                new_lines.append(format_rich_spell(name, ids_list, data).rstrip("\n"))
                changes += 1
            else:
                new_lines.append(line)
                skipped += 1
            i += 1
            continue
        
        new_lines.append(line)
        i += 1
    
    if changes > 0:
        new_content = "\n".join(new_lines)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"  ENRICHED: {filepath} ({changes} spells enriched, {skipped} skipped)")
        return True
    else:
        print(f"  NO CHANGE: {filepath} ({skipped} spells skipped)")
        return False


def main():
    total_enriched = 0
    total_changed = 0

    for class_dir in sorted(CLASS_MAP.keys()):
        if class_dir in SKIP_DIRS:
            continue
        print(f"\nProcessing {class_dir}...")
        changed = process_class_file(class_dir)
        if changed:
            total_enriched += 1
            total_changed += 1

    print(f"\nDone: {total_enriched} files enriched, {total_changed} files changed")


if __name__ == "__main__":
    main()
