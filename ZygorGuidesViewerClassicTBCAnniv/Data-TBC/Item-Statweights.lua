local ItemScore = ZGV.ItemScore

ItemScore.rules = {
	["DRUID"] = {
		[1] = { 
			name="Balance",
			itemtypes = { CLOTH=1, LEATHER=1, TH_STAFF=1, MACE=1, TH_MACE=1, DAGGER=1, FIST=1, MISCARM=1 },
						caps = { HIT_SPELL=16, },

						stats = {
										INTELLECT=0.54,
										SPELL_DAMAGE_DONE=1, 
										SPELL_DAMAGE_DONE_ARCANE=1, 
										SPELL_DAMAGE_DONE_NATURE=0.4, 
										HIT_SPELL=1.21,
										CRIT_SPELL=0.84},

		},
		[2] = { 
			name="Feral DPS", 
			itemtypes = { CLOTH=1, LEATHER=1, TH_STAFF=1, MACE=1, TH_MACE=1, DAGGER=1, FIST=1 },
						caps = { HIT=9, EXPERTISE=6.5, },
						stats = {
										STRENGTH=2.266, 
										AGILITY=3.5, 
										ATTACK_POWER=1, 
										FERAL_ATTACK_POWER=1, 
										HIT=3.2, 
										EXPERTISE=3.2, 
										CRIT=2.37,
										HASTE=1.36,
										ARMOR_PENETRATION=0.47},

		},
		[3] = {
			name="Feral TANK", 
			itemtypes = { CLOTH=1, LEATHER=1, TH_STAFF=1, MACE=1, TH_MACE=1, DAGGER=1, FIST=1 },
						caps = { HIT=9, EXPERTISE=6.5, },
						stats = {
										STRENGTH=2.266,
										AGILITY=4.6,
										ATTACK_POWER=1, 
										FERAL_ATTACK_POWER=1, 
										HIT=3.5, 
										EXPERTISE=7.3, 
										CRIT=1, 
										HASTE=1.6, 
										ARMOR_PENETRATION=0.34,
										STAMINA=3.05,
										HEALTH=0.3, 
										ARMOR=0.59, 
										DEFENSE_SKILL=2.2, 
										DODGE=1.7},

		},
		[4] = {
			name="Restoration", 
			itemtypes = { CLOTH=1, LEATHER=1, TH_STAFF=1, MACE=1, TH_MACE=1, DAGGER=1, FIST=1, MISCARM=1 },
						caps = {},
						stats = {
										INTELLECT=1,
										SPIRIT=0.87, 
										MANA_REGENERATION=1.7, 
										SPELL_HEALING_DONE=1.21, 
										CRIT_SPELL=0.35,
										HASTE=0.49},

		}
	},
	["HUNTER"] = { -- cloth/leather only until 40, mail from 40
		[1] = { 
			name="Beast Mastery", 
			itemtypes = { CLOTH=-40, LEATHER=1, MAIL=40, BOW=1, CROSSBOW=1, GUN=1, TH_SWORD=1, TH_AXE=1, SWORD=1, AXE=1, FIST=1, TH_POLE=1, DAGGER=1, TH_STAFF=1, },
      caps = { HIT=5, },
						stats = {
          AGILITY=2.5, 
          DAMAGE_PER_SECOND=3.0, 
          ATTACK_POWER=0.15, 
          RANGED_ATTACK_POWER=1, 
          HIT=0.3, 
          CRIT=2.3, 
          HASTE=1.97, 
          ARMOR_PENETRATION=0.4},
	
		},
		[2] = { 
			name="Marksmanship", 
			itemtypes = { CLOTH=-40, LEATHER=1, MAIL=40, BOW=1, CROSSBOW=1, GUN=1, TH_SWORD=1, TH_AXE=1, SWORD=1, AXE=1, FIST=1, TH_POLE=1, DAGGER=1, TH_STAFF=1, },
						caps = { HIT=5, },
						stats = {
										AGILITY=1, 
										DAMAGE_PER_SECOND=2.6, 
										ATTACK_POWER=0.57, 
										RANGED_ATTACK_POWER=0.55, 
										HIT=1, 
										CRIT=2.3, 
										HASTE=1.5, 
										ARMOR_PENETRATION=0.4},
			
		},
		[3] = { 
			name="Survival", 
			itemtypes = { CLOTH=-40, LEATHER=1, MAIL=40, BOW=1, CROSSBOW=1, GUN=1, TH_SWORD=1, TH_AXE=1, SWORD=1, AXE=1, FIST=1, TH_POLE=1, DAGGER=1, TH_STAFF=1, },
						caps = { HIT=2, },
						stats = {		
										STRENGTH=0.05, 
										AGILITY=1.2, 
										DAMAGE_PER_SECOND=2.4, 
										ATTACK_POWER=0.55,
										RANGED_ATTACK_POWER=0.55,
										HIT=0.7,
										EXPERTISE=0.05,
										CRIT=0.8,
										HASTE=0.4,
										ARMOR_PENETRATION=0.6},									 
			
		},
	},
	["MAGE"] = {
		[1] = { 
			name="Arcane", 
			itemtypes = { CLOTH=1, TH_STAFF=1, DAGGER=1, SWORD=1, WAND=1, MISCARM=1 },
						caps = { HIT_SPELL=6 },
						stats = {
										INTELLECT=1.29, 
										SPIRIT=0.89, 
										SPELL_DAMAGE_DONE=1,
										SPELL_DAMAGE_DONE_ARCANE=0.79,
										SPELL_DAMAGE_DONE_FROST=0.21, 
										HIT_SPELL=1.1, 
										CRIT_SPELL=0.77, 
										HASTE=0.84, 
										SPELL_PENETRATION=0.09},
			
		},
		[2] = { 
			name="Fire", 
			itemtypes = { CLOTH=1, TH_STAFF=1, DAGGER=1, SWORD=1, WAND=1, MISCARM=1 },
						caps = { HIT_SPELL=13 },
						stats = {
										INTELLECT=0.7,
										SPIRIT=0.3,
										SPELL_DAMAGE_DONE=1,
										SPELL_DAMAGE_DONE_FIRE=1, 
										HIT_SPELL=1.07,
										CRIT_SPELL=0.77,
										HASTE=0.83,
										SPELL_PENETRATION=0.09},
		
		},
		[3] = { 
			name="Frost", 
			itemtypes = { CLOTH=1, TH_STAFF=1, DAGGER=1, SWORD=1, WAND=1, MISCARM=1 },
						caps = { HIT_SPELL=10 },
						stats = {
										INTELLECT=0.7,
										SPIRIT=0.3,
										SPELL_DAMAGE_DONE=1,
										SPELL_DAMAGE_DONE_FROST=1,
										HIT_SPELL=1.22, 
										CRIT_SPELL=0.77, 
										HASTE=0.83, 
										SPELL_PENETRATION=0.09},

		}
	},
	["PALADIN"] = { -- cloth/leather/mail only till 40, plate from 40
		[1] = {
			name="Holy", 
			itemtypes = { CLOTH=1, LEATHER=1, MAIL=1, PLATE=40, SHIELD=1, MACE=1, TH_MACE=1, TH_POLE=1, SWORD=1, TH_SWORD=1, MISCARM=1 },
						caps = {},
						stats = {
										INTELLECT=1, 
										SPIRIT=0.28, 
										MANA_REGENERATION=1.24, 
										SPELL_HEALING_DONE=1.54, 
										CRIT_SPELL=1.1, 
										HASTE=0.9},
			
		},
		[2] = {
			name="Protection", 
			itemtypes = { CLOTH=-40, LEATHER=-40, MAIL=1, PLATE=40, SHIELD=1, MACE=1, TH_MACE=1, TH_POLE=1, SWORD=1, TH_SWORD=1 },
						caps = { HIT_SPELL=9 },
						stats = {
										STRENGTH=0.33, 
										AGILITY=0.6, 
										DAMAGE_PER_SECOND=1.77,
										ATTACK_POWER=0.06, 
										EXPERTISE=0.67, 
										HASTE=0.21, 
										SPELL_DAMAGE_DONE=1, 
										SPELL_DAMAGE_DONE_HOLY=1, 
										HIT_SPELL=0.78, 
										STAMINA=1, 
										HEALTH=0.09, 
										ARMOR=0.05, 
										DEFENSE_SKILL=0.9,
										DODGE=0.7, 
										PARRY=0.58, 
										BLOCK=0.35, 
										BLOCK_VALUE=0.59},
			
		},
		[3] = { 
			name="Retribution", 
			itemtypes = { CLOTH=-40, LEATHER=1, MAIL=1, PLATE=40, SHIELD=1, MACE=1, TH_MACE=1, TH_POLE=1, SWORD=1, TH_SWORD=1 },
						caps = { HIT=9, EXPERTISE=6.5 },
						stats = {
										STRENGTH=2.42, 
										AGILITY=1.88, 
										DAMAGE_PER_SECOND=5.4, 
										ATTACK_POWER=1, 
										HIT=2.5, 
										EXPERTISE=4.7, 
										CRIT=1.98, 
										HASTE=3.27, 
										ARMOR_PENETRATION=0.29,
										SPELL_DAMAGE_DONE=0.35},
	
		}
	},
	["PRIEST"] = {
		[1] = {
			name="Discipline", 
			itemtypes = { CLOTH=1, MACE=1, DAGGER=1, TH_STAFF=1, WAND=1, MISCARM=1 },
						caps = {},
						stats = {
										INTELLECT=1, 
										SPIRIT=1.3, 
										MANA_REGENERATION=0.9, 
										SPELL_HEALING_DONE=1.2, 
										CRIT_SPELL=0.6, 
										HASTE=0.7},
					
		},
		[2] = {
			name="Holy", 
			itemtypes = { CLOTH=1, MACE=1, DAGGER=1, TH_STAFF=1, WAND=1, MISCARM=1 },
						caps = {},
						stats = {
										INTELLECT=1,
										SPIRIT=1.2, 
										MANA_REGENERATION=0.9, 
										SPELL_HEALING_DONE=1.4, 
										CRIT_SPELL=1.25, 
										HASTE=1.5},
						
		},
		[3] = {
			name="Shadow", 
			itemtypes = { CLOTH=1, MACE=1, DAGGER=1, TH_STAFF=1, WAND=1, MISCARM=1 },
						caps = { HIT_SPELL=10, },
						stats = {
										INTELLECT=0.05,
										SPIRIT=0.11,
										SPELL_DAMAGE_DONE=1, 
										SPELL_DAMAGE_DONE_SHADOW=1, 
										HIT_SPELL=1.12, 
										CRIT_SPELL=0.163, 
										HASTE=1, 
										SPELL_PENETRATION=0.08},
			
		}
	},
	["ROGUE"] = {
		[1] = { 
			name="Assassination", 
			itemtypes = { CLOTH=1, LEATHER=1, BOW=1, CROSSBOW=1, DAGGER=1, FIST=1, GUN=1, MACE=1, SWORD=1, THROWN=1, },
						caps = { HIT=24, EXPERTISE=6.5 },
						stats = {
										STRENGTH=0.5, 
										AGILITY=1, 
										DAMAGE_PER_SECOND=3, 
										ATTACK_POWER=0.45, 
										HIT=1.2, 
										EXPERTISE=1.1, 
										CRIT=0.81, 
										HASTE=0.9, 
										ARMOR_PENETRATION=0.7},
			
		},
		[2] = { 
			name="Combat", 
			itemtypes = { CLOTH=1, LEATHER=1, BOW=1, CROSSBOW=1, DAGGER=1, FIST=1, GUN=1, MACE=1, SWORD=1, THROWN=1, },
						caps = { HIT=24, EXPERTISE=4 },
						stats = {
										STRENGTH=1.1, 
										AGILITY=2.21, 
										DAMAGE_PER_SECOND=3, 
										ATTACK_POWER=1, 
										HIT=2.85, 
										EXPERTISE=3.1, 
										CRIT=1.7,
										HASTE=2.3, 
										ARMOR_PENETRATION=0.44},
			
		},
		[3] = { 
			name="Subtlety", 
			itemtypes = { CLOTH=1, LEATHER=1, BOW=1, CROSSBOW=1, DAGGER=1, FIST=1, GUN=1, MACE=1, SWORD=1, THROWN=1, },
						caps = { HIT=24, EXPERTISE=6.5 },
						stats = {
										STRENGTH=0.5, 
										AGILITY=1, 
										DAMAGE_PER_SECOND=3, 
										ATTACK_POWER=0.45, 
										HIT=1, 
										EXPERTISE=1.1, 
										CRIT=0.81, 
										HASTE=0.9, 
										ARMOR_PENETRATION=0.7},
			
		}
	},
	["SHAMAN"] = { -- cloth/leather only till 40, mail from 40
		[1] = { 
			name="Elemental", 
			itemtypes = { CLOTH=1, LEATHER=1, MAIL=40, SHIELD=1, AXE=1, TH_AXE=1, DAGGER=1, FIST=1, MACE=1, TH_MACE=1, TH_STAFF=1, },
						caps = { HIT_SPELL=4, },
						stats = {
										INTELLECT=0.9, 
										MANA_REGENERATION=0.08, 
										SPELL_DAMAGE_DONE=1, 
										SPELL_DAMAGE_DONE_NATURE=1, 
										HIT_SPELL=1.2, 
										CRIT_SPELL=0.78, 
										HASTE=1.25, 
										SPELL_PENETRATION=0.1},
		},
		[2] = { 
			name="Enhancement",
			itemtypes = { CLOTH=-40, LEATHER=1, MAIL=40, SHIELD=1, AXE=1, TH_AXE=1, DAGGER=1, FIST=1, MACE=1, TH_MACE=1, TH_STAFF=1, },
						caps = { HIT=24, EXPERTISE=6.5 },
						stats = {
										STRENGTH=2.2, 
										AGILITY=1.3, 
										DAMAGE_PER_SECOND=3, 
										ATTACK_POWER=1, 
										HIT=1.67, 
										EXPERTISE=2.8, 
										CRIT=1.36, 
										HASTE=1.95, 
										ARMOR_PENETRATION=0.28}, 
			
		},
		[3] = {
			name="Restoration", 
			itemtypes = { CLOTH=1, LEATHER=1, MAIL=40, SHIELD=1, AXE=1, TH_AXE=1, DAGGER=1, FIST=1, MACE=1, TH_MACE=1, TH_STAFF=1, MISCARM=1 },
						caps = {},
						stats = {
										INTELLECT=1, 
										SPIRIT=0.61, 
										MANA_REGENERATION=2, 
										SPELL_HEALING_DONE=1, 
										CRIT_SPELL=0.7, 
										HASTE=1.5},
			
		}
	},
	["WARLOCK"] = {
		[1] = {
			name="Affliction", 
			itemtypes = { CLOTH=1, DAGGER=1, WAND=1, TH_STAFF=1, SWORD=1, MISCARM=1 },
						caps = { HIT_SPELL=6, },
						stats = {
										INTELLECT=0.4, 
										SPELL_DAMAGE_DONE=1, 
										SPELL_DAMAGE_DONE_FIRE=0.35, 
										SPELL_DAMAGE_DONE_SHADOW=0.91, 
										HIT_SPELL=1.43, 
										CRIT_SPELL=0.53, 
										HASTE=1.2, 
										SPELL_PENETRATION=0.08},
			
		},
		[2] = {
			name="Demonology", 
			itemtypes = { CLOTH=1, DAGGER=1, WAND=1, TH_STAFF=1, SWORD=1, MISCARM=1 },
						caps = { HIT_SPELL=16, },
						stats = {
										INTELLECT=0.4,
										SPELL_DAMAGE_DONE=1, 
										SPELL_DAMAGE_DONE_FIRE=0.35, 
										SPELL_DAMAGE_DONE_SHADOW=0.91, 
										HIT_SPELL=1.43, 
										CRIT_SPELL=0.53, 
										HASTE=1.2, 
										SPELL_PENETRATION=0.08},
			
		},
		[3] = {
			name="Destruction", 
			itemtypes = { CLOTH=1, DAGGER=1, WAND=1, TH_STAFF=1, SWORD=1, MISCARM=1 },
						caps = { HIT_SPELL=16, },
						stats = {
										INTELLECT=0.4,
										SPELL_DAMAGE_DONE=1, 
										SPELL_DAMAGE_DONE_FIRE=1, 
										SPELL_DAMAGE_DONE_SHADOW=1, 
										HIT_SPELL=1.43, 
										CRIT_SPELL=0.53, 
										HASTE=1.2, 
										SPELL_PENETRATION=0.08},
			
		}
	},
	["WARRIOR"] = { -- cloth/leather,mail only till 40, plate from 40
		[1] = { 
			name="Arms", 
			itemtypes = {CLOTH=-40, LEATHER=1, MAIL=1, PLATE=40, SHIELD=1, AXE=1, TH_AXE=1, BOW=1, CROSSBOW=1, DAGGER=1, FIST=1, GUN=1, MACE=1, TH_MACE=1, TH_POLE=1, TH_STAFF=1, SWORD=1, TH_SWORD=1, OFFHAND=1, MISCARM=1, THROWN=1, },
						caps = { HIT=9, EXPERTISE=6.5, },
						stats = {
										STRENGTH=1, 
										AGILITY=0.69, 
										DAMAGE_PER_SECOND=5.31,
										ATTACK_POWER=0.45, 
										HIT=1.5, 
										EXPERTISE=3.3, 
										CRIT=1.6, 
										HASTE=1.8, 
										ARMOR_PENETRATION=0.5},
		
		},
		[2] = { 
			name="Fury", 
			itemtypes = {CLOTH=-40, LEATHER=1, MAIL=1, PLATE=40, SHIELD=1, AXE=1, TH_AXE=1, BOW=1, CROSSBOW=1, DAGGER=1, FIST=1, GUN=1, MACE=1, TH_MACE=1, TH_POLE=1, TH_STAFF=1, SWORD=1, TH_SWORD=1, OFFHAND=1, MISCARM=1, THROWN=1, },
						caps = { HIT=24, EXPERTISE=6.5, },
						stats = {
										STRENGTH=1, 
										AGILITY=0.57, 
										DAMAGE_PER_SECOND=5.2, 
										ATTACK_POWER=0.54, 
										HIT=0.41, 
										EXPERTISE=3.3, 
										CRIT=1.8, 
										HASTE=2.1, 
										ARMOR_PENETRATION=0.5},
			
		},
		[3] = {
			name="Prot", 
			itemtypes = {CLOTH=-40, LEATHER=-40, MAIL=-40, PLATE=40, SHIELD=1, AXE=1, TH_AXE=1, BOW=1, CROSSBOW=1, DAGGER=1, FIST=1, GUN=1, MACE=1, TH_MACE=1, TH_POLE=1, TH_STAFF=1, SWORD=1, TH_SWORD=1, OFFHAND=1, MISCARM=1, THROWN=1, },
						caps = { HIT=9, EXPERTISE=6.5, },
						stats = {
										STRENGTH=0.33, 
										AGILITY=0.6, 
										DAMAGE_PER_SECOND=3.13, 
										ATTACK_POWER=0.06, 
										HIT=0.67, 
										EXPERTISE=0.67, 
										CRIT=0.28, 
										HASTE=0.21,
										ARMOR_PENETRATION=0.19, 
										STAMINA=1,
										ARMOR=0.05, 
										DEFENSE_SKILL=0.8, 
										DODGE=0.7, 
										PARRY=0.58, 
										BLOCK=0.35, 
										BLOCK_VALUE=0.59},
			
		}
	},
}