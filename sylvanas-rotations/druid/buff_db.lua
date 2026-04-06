-- =============================================================================
-- BUFF DATABASE - Actual Spell IDs for TBC
-- Minimal working set of common buffs and debuffs
-- =============================================================================

local buff_db = {}

-- ============================================================================
-- DRUID BUFFS
-- ============================================================================
buff_db.MARK_OF_THE_WILD = {1126, 5232, 5234, 6756, 8907, 9884, 9885, 26990} -- All ranks
buff_db.THORNS = {467, 782, 1075, 8914, 9756, 9910, 26992}
buff_db.OMEN_OF_CLARITY = {16864, 16865}
buff_db.INNERVATE = {29166}
buff_db.BARKSKIN = {22812}

-- Druid Forms
buff_db.CAT_FORM = {768}
buff_db.BEAR_FORM = {5487}
buff_db.DIRE_BEAR_FORM = {9634}
buff_db.MOONKIN_FORM = {24858}
buff_db.TRAVEL_FORM = {783, 1066} -- Land and Aquatic
buff_db.AQUATIC_FORM = {1066}
buff_db.FLIGHT_FORM = {33943}
buff_db.SWIFT_FLIGHT_FORM = {40120}
buff_db.TREE_OF_LIFE = {33891}

-- Druid Buffs (Cat/Bear)
buff_db.PROWL = {5215, 6783, 9913}
buff_db.TIGERS_FURY = {5217, 6793, 9844, 9845}
buff_db.SAVAGE_ROAR = {40733} -- WotLK but may be in TBC servers

-- Druid Debuffs
buff_db.MOONFIRE = {8921, 8924, 8925, 8926, 8927, 8928, 8929, 9834, 9835, 26987, 26988}
buff_db.ENTANGLING_ROOTS = {339, 1062, 5195, 5196, 9852, 9853, 26989}
buff_db.FAERIE_FIRE = {770, 778, 9749, 9907, 26993}
buff_db.FAERIE_FIRE_FERAL = {16857, 17390, 17391, 17392, 27011, 27012}
buff_db.RAKE = {1822, 1823, 1824, 9904, 27003}
buff_db.RIP = {1079, 9492, 9493, 9752, 9894, 9896, 27008}
buff_db.LACERATE = {33745} -- TBC only

-- ============================================================================
-- COMMON RAID BUFFS
-- ============================================================================

-- Stamina
buff_db.POWER_WORD_FORTITUDE = {1243, 1244, 1245, 2791, 10937, 10938, 25389}
buff_db.PRAYER_OF_FORTITUDE = {21562, 21564, 25392}

-- Intellect
buff_db.ARCANE_INTELLECT = {1459, 1460, 1461, 10157, 10158, 27126}
buff_db.ARCANE_BRILLIANCE = {23028, 27127}

-- Spirit
buff_db.DIVINE_SPIRIT = {14752, 14818, 14819, 27841, 27842}
buff_db.PRAYER_OF_SPIRIT = {27681, 32999}

-- Blessings (Paladin)
buff_db.BLESSING_OF_MIGHT = {19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140}
buff_db.BLESSING_OF_WISDOM = {19742, 19850, 19852, 19853, 19854, 25290, 27142}
buff_db.BLESSING_OF_KINGS = {20217}
buff_db.BLESSING_OF_SALVATION = {1038}
buff_db.BLESSING_OF_LIGHT = {19977, 19978, 19979, 27144}
buff_db.BLESSING_OF_SANCTUARY = {20911, 20912, 20913, 20914, 27168}
buff_db.BLESSING_OF_PROTECTION = {1022, 5599, 10278}
buff_db.BLESSING_OF_FREEDOM = {1044}
buff_db.BLESSING_OF_SACRIFICE = {6940, 20729, 20711, 27147, 27148}

-- Greater Blessings
buff_db.GREATER_BLESSING_OF_MIGHT = {25782, 25916, 27141}
buff_db.GREATER_BLESSING_OF_WISDOM = {25894, 25918, 27143}
buff_db.GREATER_BLESSING_OF_KINGS = {25898}
buff_db.GREATER_BLESSING_OF_SALVATION = {25895}
buff_db.GREATER_BLESSING_OF_LIGHT = {25890}
buff_db.GREATER_BLESSING_OF_SANCTUARY = {25899}

-- Auras
buff_db.DEVOTION_AURA = {465, 10290, 643, 10291, 1032, 10292, 10293, 27149}
buff_db.RETRIBUTION_AURA = {7294, 10298, 10299, 10300, 10301, 27150}
buff_db.CONCENTRATION_AURA = {19746}
buff_db.SHADOW_RESISTANCE_AURA = {19876, 19875, 19896, 19895, 27151, 27152}
buff_db.FROST_RESISTANCE_AURA = {19888, 19897, 19898, 27153, 27154}
buff_db.FIRE_RESISTANCE_AURA = {19891, 19899, 19900, 27155, 27156}
buff_db.CRUSADER_AURA = {32223}
buff_db.SANCTITY_AURA = {20218}

-- Shields
buff_db.POWER_WORD_SHIELD = {17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218}
buff_db.WEAKENED_SOUL = {6788}

-- Weapon buffs
buff_db.ROCKBITER_WEAPON = {801, 802, 803, 804, 805, 3583, 6654, 16314, 16315, 16316}
buff_db.FLAMETONGUE_WEAPON = {8024, 8027, 8030, 16339, 16341, 16342, 25489, 25500}
buff_db.FROSTBRAND_WEAPON = {8033, 8038, 10456, 16355, 16356, 25501}
buff_db.WINDFURY_WEAPON = {8232, 8235, 10486, 16362, 25505}
buff_db.EARTH_LIVING_WEAPON = {51730, 51988, 51989, 51990, 51991, 51992, 51993, 51994} -- WotLK

-- Shaman Buffs
buff_db.LIGHTNING_SHIELD = {324, 325, 905, 945, 8134, 10431, 10432, 25469, 25472}
buff_db.WATER_SHIELD = {24398} -- TBC
buff_db.EARTH_SHIELD = {974, 32593, 32594} -- TBC

-- Hunter Aspects
buff_db.ASPECT_OF_THE_HAWK = {13165, 14318, 14319, 14320, 14321, 14322, 25296, 27044}
buff_db.ASPECT_OF_THE_MONKEY = {13163}
buff_db.ASPECT_OF_THE_CHEETAH = {5118}
buff_db.ASPECT_OF_THE_PACK = {13159}
buff_db.ASPECT_OF_THE_WILD = {20043, 20190, 27045}
buff_db.ASPECT_OF_THE_VIPER = {34074, 34074} -- TBC

-- Hunter Pet Buffs
buff_db.FRENZY = {19615, 19616} -- Pet talent
buff_db.FEROCIOUS_INSPIRATION = {34456, 34457, 34459} -- BM talent

-- Warrior Shouts
buff_db.BATTLE_SHOUT = {6673, 5242, 6192, 11549, 11550, 11551, 25289, 2048, 47436}
buff_db.COMMANDING_SHOUT = {469, 2048, 47436, 47437, 47438, 47439, 47440} -- TBC+ mostly
buff_db.DEMORALIZING_SHOUT = {1160, 6190, 11554, 11555, 11556, 25202, 25203}

-- Warrior Stances
buff_db.BATTLE_STANCE = {2457}
buff_db.DEFENSIVE_STANCE = {71}
buff_db.BERSERKER_STANCE = {2458}

-- Rogue Poisons
buff_db.INSTANT_POISON = {8680, 8685, 8686, 8687, 8692, 11341, 11342, 11343, 25247}
buff_db.DEADLY_POISON = {2818, 2819, 11355, 11356, 25248}
buff_db.CRIPPLING_POISON = {3408, 3409, 11201}
buff_db.WOUND_POISON = {13218, 13222, 13223, 13224, 27188}
buff_db.MIND_NUMBING_POISON = {5760, 5761, 5762, 5763, 25810}
buff_db.ANESTHETIC_POISON = {26786} -- TBC

-- Rogue Stealth
buff_db.STEALTH = {1784, 1785, 1786, 1787, 5215} -- 5215 is druid prowl actually

-- ============================================================================
-- WARLOCK BUFFS
-- ============================================================================
buff_db.DEMON_SKIN = {687, 696}
buff_db.DEMON_ARMOR = {706, 1086, 11733, 11734, 11735, 27260, 47793}
buff_db.FEL_ARMOR = {28176, 28189, 47892, 47893} -- TBC+
buff_db.BLOOD_PACT = {6307, 18696, 18697, 18698, 25505} -- Imp buff

-- Warlock Self Buffs
buff_db.SHADOW_WARD = {6229, 11739, 11740, 28610, 47890, 47891}
buff_db.SOUL_LINK = {19028, 25229, 27265}

-- Demon Buffs
buff_db.PHASE_SHIFT = {4511} -- Imp

-- ============================================================================
-- MAGE BUFFS
-- ============================================================================
buff_db.MAGE_ARMOR = {6117, 22782, 22783, 27125}
buff_db.ICE_ARMOR = {168, 7300, 7301, 7302, 7320, 10219, 10220, 27124}
buff_db.FROST_ARMOR = {168, 7300, 7301} -- Low level
buff_db.MOLTEN_ARMOR = {30482, 30483, 43043, 43044} -- TBC+
buff_db.MANA_SHIELD = {1463, 8494, 8495, 10191, 10192, 10193, 27131}
buff_db.ICE_BARRIER = {11426, 13031, 13032, 13033, 27134, 33405, 43038, 43039} -- TBC+
buff_db.COMBUSTION = {11129}
buff_db.PRESENCE_OF_MIND = {12043}
buff_db.ARCANE_POWER = {12042}
buff_db.ICY_VEINS = {12472, 28595, 28596, 28597} -- TBC+

-- ============================================================================
-- PRIEST BUFFS
-- ============================================================================
buff_db.INNER_FIRE = {588, 7128, 602, 1004, 1006, 10951, 10952, 25431}
buff_db.FEAR_WARD = {6346}
buff_db.SHADOWGUARD = {18137, 18138, 18139, 18140, 18141, 28610} -- Troll racial

-- Priest Forms
buff_db.SHADOWFORM = {15473, 15474}
buff_db.INNER_FOCUS = {14751}
buff_db.SPIRIT_OF_REDEMPTION = {20711} -- Holy talent

-- ============================================================================
-- RACIAL BUFFS
-- ============================================================================
buff_db.BERSERKING = {26297} -- Troll
buff_db.BLOOD_FURY = {33697, 20572} -- Orc
buff_db.STONEFORM = {20594} -- Dwarf
buff_db.ESCAPE_ARTIST = {20589} -- Gnome
buff_db.SHADOWMELD = {20580, 58984} -- Night Elf
buff_db.WAR_STOMP = {20549} -- Tauren

-- ============================================================================
-- COMBAT POTIONS/CONSUMABLES
-- ============================================================================
buff_db.HASTE_POTION = {28507} -- TBC

-- Food buffs
buff_db.WELL_FED = {33257, 33258, 33259, 33260, 33261, 35254, 44106, 43730, 46898}

-- Flasks
buff_db.FLASK_OF_BLINDING_LIGHT = {28521, 28522, 38954} -- TBC
buff_db.FLASK_OF_MIGHTY_RESTORATION = {28518, 28519, 38955} -- TBC
buff_db.FLASK_OF_RELENTLESS_ASSAULT = {28520, 28521, 38960} -- TBC
buff_db.FLASK_OF_PURE_DEATH = {28540, 28541, 38962} -- TBC

-- ============================================================================
-- RAID DEBUFFS (Boss abilities to watch for)
-- ============================================================================

-- Common Raid Debuffs
buff_db.SILENCE = {15487} -- Priest silence
buff_db.COUNTERSPELL_SILENCE = {18469, 18498} -- Mage/Rogue silence
buff_db.SPELL_LOCK = {24259} -- Felhunter

-- Fear effects
buff_db.INTIMIDATING_SHOUT = {5246}
buff_db.HOWL_OF_TERROR = {5484, 17928}
buff_db.PSYCHIC_SCREAM = {8122, 8124, 10888, 10890, 25411}
buff_db.FEAR = {5782, 6213, 6215, 25470}

-- Stuns
buff_db.CHEAP_SHOT = {1833}
buff_db.KIDNEY_SHOT = {408, 8643}
buff_db.BASH = {5211, 6798, 8983}
buff_db.HAMMER_OF_JUSTICE = {853, 5588, 5589, 10308}
buff_db.SHADOW_FURY = {30283, 30413, 30414} -- Warlock TBC talent

-- Disorients
buff_db.GOUGE = {1776, 1777, 8629, 11285, 11286, 38764}
buff_db.BLIND = {2094, 2094, 2094, 2094}

-- Roots
buff_db.HAMSTRING = {1715, 7372, 7373, 25212}
buff_db.COSMIC_INFUSION = {28433} -- TBC reference

-- Bleeds
buff_db.DEEP_WOUND = {12721} -- Warrior

-- Important buffs to purge/dispel
buff_db.POWER_INFUSION = {10060}
buff_db.BLOODLUST = {2825, 32182} -- Heroism is alliance version 32182
buff_db.HEROISM = {32182}
buff_db.ICY_VEINS = {12472}
buff_db.AVENGING_WRATH = {31884} -- Paladin wings

return buff_db
