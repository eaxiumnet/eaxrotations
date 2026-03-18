-- EAX PaladinProtection | spells.lua
-- Rank tables and buff identifiers only.

local spells = {}

-- Threat and utility abilities
spells.AVENGERS_SHIELD = { 32700, 31935 }
spells.CONSECRATION = { 27173, 20924, 20923, 26573 }
spells.JUDGEMENT = { 53408, 20271 }
spells.HOLY_SHIELD = { 27179, 20925, 20927, 20928 }
spells.RIGHTEOUS_FURY = { 25780 }
spells.HAMMER_OF_THE_RIGHTEOUS = { 31803 }

-- Healing
spells.HOLY_LIGHT = { 27135, 25292, 10328, 10329, 3472, 1042, 1026, 639, 635 }
spells.FLASH_OF_LIGHT = { 27137, 19943, 19942, 19941, 19940, 19939, 19750 }

-- Holy Power builder
spells.CRUSADER_STRIKE = { 35395 }

-- Buffs
spells.BLESSING_OF_MIGHT = { 25782, 27140, 27141, 19836, 19835, 19834, 19740 }
spells.BLESSING_OF_WISDOM = { 25894, 27142, 19853, 19852, 19850, 19742 }

-- Defensive
spells.DIVINE_SHIELD = { 642, 13874 }
spells.BLESSING_OF_PROTECTION = { 1022, 5599, 5598, 1079 }
spells.LAY_ON_HANDS = { 633, 2810, 2808, 2807, 2806, 1998, 1997, 1996 }
spells.HOLY_WRATH = { 2812 }

-- Aura
spells.DEVOTION_AURA = { 465, 1032, 10290, 10291, 10292, 10293, 10294, 10295 }

-- Buff tables used for state detection
spells.BUFF_RIGHTEOUS_FURY = { 25780 }
spells.BUFF_HOLY_SHIELD = { 20925, 20927, 20928, 27179 }
spells.BUFF_DEVOTION_AURA = { 465, 1032, 10290, 10291, 10292, 10293, 10294, 10295 }

-- Default AoE radius (yards) for Consecration profiling.
spells.DEFAULT_AOE_RADIUS = 8

spells.BERSERKING = { 26297 }
spells.CRUSADER_STRIKE = { 35395 }

spells.BUFF_BERSERKING = { 26297 }

spells.HASTE_POTION = { 28508, 22832 }
spells.SUPER_MANA_POTION = { 28499, 22828 }
spells.SCROLL_OF_STAMINA = { 22733, 10292 }


spells.HAMMER_OF_JUSTICE  = { 10308, 5588, 5589, 853 }
spells.DIVINE_SHIELD      = { 642 }
spells.HAND_OF_PROTECTION = { 10278, 1022, 5599 }

spells.REDEMPTION               = { 10322, 788, 19752 }
spells.BLESSING_OF_SANCTUARY    = { 25899, 20914, 20911, 20912, 20913 }
spells.BUFF_BLESSING_OF_SANCTUARY = { 25899, 20914, 20911, 20912, 20913 }

return spells
