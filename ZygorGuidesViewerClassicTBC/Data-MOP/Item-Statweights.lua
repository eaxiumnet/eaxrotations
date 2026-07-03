local ItemScore = ZGV.ItemScore

ItemScore.rules = {
	["DEATHKNIGHT"] = {
		[1] = {
			name = "Blood",
			itemtypes={ TH_POLE=1,TH_AXE=1,TH_MACE=1,TH_SWORD=1, RELIC=1, PLATE=1 },
			stats = { DPS=8.57, STAMINA=2.17, MASTERY=2.48, STRENGTH=5.57, HASTE=1.51, PARRY=1.56, DODGE=1.04, HIT=1.50, EXPERTISE=0.41, ATTACK_POWER=2.12 },			
			caps = { HIT=7.5, EXPERTISE=6.5 },
		},
		[2] = {
			name = "Frost",
			itemtypes={ TH_POLE=1,TH_AXE=1,TH_MACE=1,TH_SWORD=1, AXE=2,MACE=2,SWORD=2, RELIC=1, PLATE=1 },
			stats = { DPS=13.14, STRENGTH=4.79, HASTE=1.68, CRIT=2.06, MASTERY=1.48, HIT=0.51, EXPERTISE=0.03, ATTACK_POWER=1.76 },
			caps = { HIT=7.5, EXPERTISE=6.5 },
		},
		[3] = {
			name = "Unholy",
			itemtypes={ TH_POLE=1,TH_AXE=1,TH_MACE=1,TH_SWORD=1, RELIC=1, PLATE=1 },
			stats = { DPS=4.98, STRENGTH=6.53, HASTE=1.90, CRIT=2.74, HIT=0.52, EXPERTISE=0.41, MASTERY=2.35, ATTACK_POWER=1.90 },
			caps = { HIT=7.5, EXPERTISE=6.5 },
		},
	},
	["DRUID"] = {
		[1] = {
			name = "Balance",
			itemtypes={ DAGGER=1,MACE=1, MISCARM=1, TH_STAFF=1, RELIC=1, LEATHER=1 },
			stats = { INTELLECT=6.34, HASTE=2.35, SPELL_POWER=4.88, HIT=0.54, MASTERY=2.97, CRIT=3.56 },
			caps = { HIT=15 },
		},
		[2] = {
			name = "Feral",
			itemtypes={ TH_POLE=1,TH_STAFF=1,TH_MACE=1, RELIC=1, LEATHER=1 },
			stats = { DPS=6.84, STRENGTH=2.60, AGILITY=6.72, MASTERY=2.67, CRIT=2.41, HASTE=1.76, HIT=0.43, EXPERTISE=0.22, ATTACK_POWER=2.41 },
			caps = { HIT=7.5, EXPERTISE=7.5 },

		},
		[3] = {
			name = "Guardian",
			itemtypes={ TH_POLE=1,TH_STAFF=1,TH_MACE=1, RELIC=1, LEATHER=1 },
			stats = { DPS=8.57, STAMINA=2.17, MASTERY=2.48, STRENGTH=5.57, HASTE=1.51, PARRY=1.56, DODGE=1.04, HIT=1.50, EXPERTISE=0.41, ATTACK_POWER=2.12 },
			caps = { HIT=7.5, EXPERTISE=7.5 },
		},
		[4] = {
			name = "Restoration",
			itemtypes={ DAGGER=1,MACE=1, MISCARM=1, TH_STAFF=1, RELIC=1, LEATHER=1 },
			stats = { INTELLECT=6.34, HASTE=2.35, SPELL_POWER=4.88, HIT=0.54, MASTERY=2.97, CRIT=3.56 },
			caps = { HIT=15 },
		},
	},
	["HUNTER"] = {
		[1] = {
			name = "Beastmastery",
			itemtypes={ BOW=1, CROSSBOW=1, GUN=1, LEATHER=-40, MAIL=40 },
			stats = { DPS=5.57, AGILITY=7.24, EXPERTISE=0.07, CRIT=2.45, HASTE=2.44, MASTERY=2.48, HIT=0.14, ATTACK_POWER=2.72 },					
			caps = { HIT=7.5 },
		},
		[2] = {
			name = "Marksmanship",
			itemtypes={ BOW=1,CROSSBOW=1,GUN=1, LEATHER=-40,MAIL=40 },
			stats = { DPS=9.75, AGILITY=5.84, EXPERTISE=0.34, CRIT=2.30, HASTE=2.24, MASTERY=1.28, HIT=1.22, ATTACK_POWER=2.16 },			
			caps = { HIT=7.5 },
		},
		[3] = {
			name = "Survival",
			itemtypes={ BOW=1, CROSSBOW=1, GUN=1, LEATHER=-40, MAIL=40 },
			stats = { DPS=4.91, AGILITY=7.25, EXPERTISE=0.01, CRIT=2.34, HASTE=1.89, MASTERY=1.45, HIT=0.21, ATTACK_POWER=2.76 },
			caps = { HIT=7.5 },
		},
	},	
	
	["MAGE"] = {
		[1] = {
			name="Arcane",
			itemtypes={ DAGGER=1, SWORD=1, TH_STAFF=1, WAND=1, MISCARM=1, CLOTH=1 },
			stats = { INTELLECT=5.35, SPELL_POWER=4.28, HASTE=2.55, MASTERY=2.67, HIT=0.13, CRIT=2.25 },
			caps = { HIT=15 },
		},
		[2] = {
			name="Fire",
			itemtypes={ DAGGER=1,SWORD=1,TH_STAFF=1, WAND=1, MISCARM=1, CLOTH=1 },
			stats = { INTELLECT=4.79, SPELL_POWER=3.73, HASTE=2.20, MASTERY=2.02, HIT=0.13, CRIT=2.74 },
			caps = { HIT=15 },
		},
		[3] = {
			name="Frost",
			itemtypes={ DAGGER=1,SWORD=1,TH_STAFF=1, WAND=1, MISCARM=1, CLOTH=1 },
			stats = { INTELLECT=6.50, SPELL_POWER=5.23, HASTE=2.52, MASTERY=2.72, HIT=0.13, CRIT=2.30 },
			caps = { HIT=15 },
		},
	},
	["MONK"] = {
		[1] = {
			name = "Brewmaster",
			itemtypes={ TH_POLE=1, TH_STAFF=1, FIST=1, AXE=1, SWORD=1, MACE=1, LEATHER=1 },
			stats = { DPS=8.57, STAMINA=2.17, MASTERY=2.48, AGILITY=5.57, HASTE=1.51, PARRY=1.56, DODGE=1.04, HIT=1.50, EXPERTISE=0.41, ATTACK_POWER=2.12 },
			caps = { HIT=7.5, EXPERTISE=7.5 },
		},
		[2] = {
			name = "Mistweaver",
			itemtypes={ TH_POLE=1, TH_STAFF=1, FIST=1, AXE=1, SWORD=1, MACE=1, LEATHER=1 },
			stats = { INTELLECT=6.34, HASTE=2.35, SPELL_POWER=4.88, HIT=0.54, MASTERY=2.97, CRIT=3.56 },
			caps = { HIT=15 },
		},
		[3] = {
			name = "Windwalker",
			itemtypes={ TH_POLE=1, TH_STAFF=1, FIST=1, AXE=1, SWORD=1, MACE=1, LEATHER=1 },
			stats = { DPS=14.36, STRENGTH=1.63, AGILITY=4.42, CRIT=2.09, HASTE=1.05, MASTERY=1.07, HIT=0.14, EXPERTISE=0.07, ATTACK_POWER=1.53 },
			caps = { HIT=7.5, EXPERTISE=7.5 },

		}
	},
	["PALADIN"] = {
		[1] = {
			name = "Holy",
			itemtypes={ AXE=1,MACE=1,SWORD=1, SHIELD=1, MISCARM=1, RELIC=1, MAIL=-40,PLATE=40 },
			stats = { INTELLECT=6.34, HASTE=2.35, SPELL_POWER=4.88, HIT=0.54, MASTERY=2.97, CRIT=3.56 },
			caps = { HIT=15 },
		},
		[2] = {
			name = "Protection",
			itemtypes={ AXE=1,MACE=1,SWORD=1, SHIELD=1, RELIC=1, MAIL=-40,PLATE=40 },
			stats = { DPS=8.57, STAMINA=2.17, MASTERY=2.48, STRENGTH=5.57, HASTE=1.51, PARRY=1.56, DODGE=1.04, HIT=1.50, EXPERTISE=0.41, ATTACK_POWER=2.12 },
			caps = { HIT=7.5, EXPERTISE=15 },
		},
		[3] = {
			name = "Retribution",
			itemtypes={ TH_POLE=1,TH_AXE=1,TH_MACE=1,TH_SWORD=1, RELIC=1, MAIL=-40,PLATE=40 },
			stats = { DPS=10.64, STRENGTH=5.20, AGILITY=0.16, HASTE=2.68, MASTERY=2.58, CRIT=2.56, HIT=0.13, EXPERTISE=0.32, ATTACK_POWER=2.18 },
			caps = { HIT=7.5, EXPERTISE=7.5 },
		},
	},
	["PRIEST"] = {
		[1] = {
			name = "Discipline",
			itemtypes={ DAGGER=1,MACE=1,TH_STAFF=1, WAND=1, MISCARM=1, CLOTH=1 },
			stats = { INTELLECT=6.34, HASTE=2.35, SPELL_POWER=4.88, HIT=0.54, MASTERY=2.97, CRIT=3.56 },
			caps = { HIT=15 },
		},
		[2] = {
			name = "Holy",
			itemtypes={ DAGGER=1,MACE=1,TH_STAFF=1, WAND=1, MISCARM=1, CLOTH=1 },
			stats = { INTELLECT=6.34, HASTE=2.35, SPELL_POWER=4.88, HIT=0.54, MASTERY=2.97, CRIT=3.56 },
			caps = { HIT=15 },
		},
		[3] = {
			name = "Shadow",
			itemtypes={ DAGGER=1,MACE=1,TH_STAFF=1, WAND=1, MISCARM=1, CLOTH=1 },
			stats = { INTELLECT=4.62, HASTE=1.51, CRIT=2.56, SPELL_POWER=3.66, MASTERY=2.31, HIT=0.13 },
			caps = { HIT=15 },
		},
	},
	["ROGUE"] = {
		[1] = {
			name = "Assassination",
			itemtypes={ DAGGER=1,LEATHER=1 },
			stats = { DPS=7.70, STRENGTH=2.67, AGILITY=6.94, MASTERY=2.92, HASTE=2.48, CRIT=2.88, HIT=1.55, EXPERTISE=1.02, ATTACK_POWER=2.52 },
			caps = { HIT=7.5, EXPERTISE=7.5 },
		},
		[2] = {
			name = "Combat",
			itemtypes={ DAGGER=1,FIST=1,AXE=1,MACE=1,SWORD=1,LEATHER=1 },
			stats = { DPS=6.89, STRENGTH=1.68, AGILITY=4.76, HASTE=2.41, HIT=1.46, EXPERTISE=0.19, CRIT=1.81, MASTERY=1.99, ATTACK_POWER=1.63 },
			caps = { HIT=7.5, EXPERTISE=7.5 },
		},
		[3] = {
			name = "Subtlety",
			itemtypes={ DAGGER=1,FIST=1,AXE=1,MACE=1,SWORD=1,LEATHER=1 },
			stats = { DPS=9.39, STRENGTH=1.78, AGILITY=6.76, HASTE=2.48, CRIT=2.70, HIT=1.44, EXPERTISE=3.85, MASTERY=1.92, ATTACK_POWER=1.72 },
			caps = { HIT=7.5, EXPERTISE=7.5 },
		},
	},
	["SHAMAN"] = {
		[1] = {
			name = "Elemental",
			itemtypes={ DAGGER=1,FIST=1,AXE=1,MACE=1,TH_STAFF=1,MISCARM=1,SHIELD=1, LEATHER=-40,MAIL=40, RELIC=1 },
			stats = { INTELLECT=4.99, HASTE=2.15, CRIT=2.24, SPELL_POWER=4.01, MASTERY=2.25, HIT=0.13 },
			caps = { HIT=15 },
		},
		[2] = {
			name = "Enhancement",
			itemtypes={ DAGGER=2,FIST=2,AXE=2,MACE=2,TH_STAFF=1,TH_AXE=1,TH_MACE=1,MISCARM=1, LEATHER=-40,MAIL=40, RELIC=1 }, --dual from 10?
			stats = { DPS=3.34, STRENGTH=1.55, AGILITY=4.15, MASTERY=1.76, CRIT=1.70, HASTE=1.50, HIT=0.75, EXPERTISE=7.75, ATTACK_POWER=1.48 },
			caps = { HIT=7.5, EXPERTISE=7.5 },
		},
		[3] = {
			name = "Restoration",
			itemtypes={ DAGGER=1,FIST=1,AXE=1,MACE=1,TH_STAFF=1,MISCARM=1,SHIELD=1, LEATHER=-40,MAIL=40, RELIC=1 },
			stats = { INTELLECT=6.34, HASTE=2.35, SPELL_POWER=4.88, HIT=0.54, MASTERY=2.97, CRIT=3.56 },
			caps = { HIT=15 },
		},
	},
	["WARLOCK"] = {
		[1] = {
			name = "Affliction",
			itemtypes={ SWORD=1,DAGGER=1,TH_STAFF=1,WAND=1, MISCARM=1, CLOTH=1 },
			stats = { INTELLECT=4.07, HASTE=2.15, CRIT=1.70, SPELL_POWER=3.26, MASTERY=2.74, HIT=0.13 },
			caps = { HIT=15 },
		},
		[2] = {
			name = "Demonology",
			itemtypes={ SWORD=1,DAGGER=1,TH_STAFF=1,WAND=1, MISCARM=1, CLOTH=1 },
			stats = { INTELLECT=4.69, HASTE=2.38, CRIT=2.13, SPELL_POWER=3.82, MASTERY=2.34, HIT=0.13 },
			caps = { HIT=15 },
		},
		[3] = {
			name = "Destruction",
			itemtypes={ SWORD=1,DAGGER=1,TH_STAFF=1,WAND=1, MISCARM=1, CLOTH=1 },
			stats = { INTELLECT=5.97, HASTE=2.54, CRIT=2.67, SPELL_POWER=4.84, MASTERY=3.02, HIT=0.13 },
			caps = { HIT=15 },
		},
	},
	["WARRIOR"] = {
		[1] = {
			name = "Arms",
			itemtypes={ TH_POLE=1,TH_STAFF=1,TH_AXE=1,TH_MACE=1,TH_SWORD=1, BOW=1,CROSSBOW=1,GUN=1,THROWN=1, MAIL=-40,PLATE=40 },
			stats = { DPS=12.57, STRENGTH=3.85, CRIT=2.07, HASTE=1.28, MASTERY=1.75, HIT=0.01, EXPERTISE=0.01, ATTACK_POWER=1.78, AGILITY=0.15 },
			caps = { HIT=7.5, EXPERTISE=7.5 },
		},
		[2] = {
			name = "Fury",
			itemtypes={ TH_AXE=69,TH_MACE=69,TH_SWORD=69, DAGGER=-69,FIST=-69,AXE=-69,MACE=-69,SWORD=-69, BOW=1,CROSSBOW=1,GUN=1,THROWN=1, MAIL=-40,PLATE=40 }, -- duals...
			stats = { DPS=10.15, STRENGTH=4.23, CRIT=3.48, HASTE=1.80, MASTERY=2.55, HIT=1.66, EXPERTISE=3.49, ATTACK_POWER=1.92, AGILITY=0.24 },
			caps = { HIT=7.5, EXPERTISE=7.5 },
		},
		[3] = {
			name = "Protection",
			itemtypes={ DAGGER=1,FIST=1,AXE=1,MACE=1,SWORD=1, BOW=1,CROSSBOW=1,GUN=1,THROWN=1, MAIL=-40,PLATE=40, SHIELD=1 },
			stats = { DPS=8.57, STAMINA=2.17, MASTERY=2.48, STRENGTH=5.57, HASTE=1.51, PARRY=1.56, DODGE=1.04, HIT=1.50, EXPERTISE=0.41, ATTACK_POWER=2.12 },
			caps = { HIT=7.5, EXPERTISE=7.5 },
		},
	},
}

