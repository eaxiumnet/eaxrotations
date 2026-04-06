-- Eax Shaman Restoration | spells.lua
-- TBC Spell ID tables for Restoration Shaman.

local spells = {}

-- Healing Spells
spells.HEALING_WAVE = { 331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357, 25391, 25396 }
spells.LESSER_HEALING_WAVE = { 8004, 8008, 8010, 10466, 10467, 10468, 25420, 25423, 25449 }
spells.CHAIN_HEAL = { 1064, 10622, 10623, 25422, 25423, 25449 }

-- Totem Spells - Fire
spells.SEARING_TOTEM = { 3599, 6363, 6364, 6365, 10437, 10438, 25533 }
spells.FLAMETONGUE_TOTEM = { 8227, 8249, 10526, 16387, 25557 }
spells.FIRE_ELEMENTAL_TOTEM = { 2894 }

-- Totem Spells - Earth
spells.STRENGTH_OF_EARTH_TOTEM = { 8075, 8160, 8161, 10442, 25361, 25528 }
spells.STONESKIN_TOTEM = { 8071, 8154, 8155, 10406, 10407, 10408, 25508, 25509 }
spells.TREMOR_TOTEM = { 8143 }
spells.EARTHBIND_TOTEM = { 2484 }

-- Totem Spells - Water
spells.MANA_SPRING_TOTEM = { 5675, 10495, 10496, 10497, 25570 }
spells.HEALING_STREAM_TOTEM = { 5394, 6375, 6377, 10462, 10463, 25567 }
spells.MANA_TIDE_TOTEM = { 16190 }

-- Totem Spells - Air
spells.WINDFURY_TOTEM = { 8512, 10607, 10608, 25585 }
spells.GRACE_OF_AIR_TOTEM = { 8835, 10626, 25359 }
spells.WRATH_OF_AIR_TOTEM = { 3738 }
spells.GROUNDING_TOTEM = { 8177 }
spells.TRANQUIL_AIR_TOTEM = { 25908 }

-- Shields
spells.WATER_SHIELD = { 24398, 33736 }
spells.EARTH_SHIELD = { 974, 32593, 32594 }
spells.LIGHTNING_SHIELD = { 324, 325, 905, 945, 8134, 10431, 10432, 25469, 25472 }

-- Cooldowns & Buffs
spells.NATURES_SWIFTNESS = { 16188 }
spells.BLOODLUST = { 2825 }
spells.HEROISM = { 32182 }

-- Racials
spells.BERSERKING = { 26297 }
spells.BLOOD_FURY_SP = { 33697 }
spells.WAR_STOMP = { 20549 }
spells.GIFT_OF_THE_NAARU = { 28880 }

-- Buffs
spells.BUFF_WATER_SHIELD = { 24398, 33736 }
spells.BUFF_EARTH_SHIELD = { 974, 32593, 32594 }
spells.BUFF_NATURES_SWIFTNESS = { 16188 }
spells.BUFF_BLOODLUST = { 2825, 32182 }
spells.BUFF_BERSERKING = { 26297 }
spells.BUFF_TIDAL_FORCE = { 55198 }

-- Debuffs (for purge)
spells.PURGE_BUFFS = {} -- Will be populated as needed

-- Utility
spells.GHOST_WOLF = { 2645 }
spells.CURE_POISON = { 526 }
spells.CURE_DISEASE = { 2870 }
spells.PURGE = { 370, 8012 }
spells.TOTEMIC_CALL = { 36936 }
spells.REINCARNATION = { 20608, 20758, 20759, 20760, 20761, 20762, 20763, 20764, 20765, 20776, 20777, 25590 }

-- Damage (for solo play)
spells.LIGHTNING_BOLT = { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15271, 25448, 25449 }
spells.EARTH_SHOCK = { 8042, 8044, 8045, 8046, 10412, 10413, 10414, 25454 }
spells.FLAME_SHOCK = { 8050, 8052, 8053, 10447, 10448, 29228, 25457 }

return spells
