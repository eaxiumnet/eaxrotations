-- spells.lua
-- Eax Shaman Restoration | The Burning Crusade (patch 2.4.3)
-- ALL IDs are TBC-only. Nothing from WotLK, Cata, or later.

local spells = {}

-- --- Healing -----------------------------------------------------------------

-- Chain Heal r1-5 (r5 = 25423 added in TBC 2.1)
spells.CHAIN_HEAL           = { 25423, 25422, 10623, 10622, 1064 }

-- Healing Wave r1-12 (r12 = 25396 is TBC max)
spells.HEALING_WAVE         = { 25396, 25391, 25357, 10396, 10395, 8005, 959, 939, 913, 547, 332, 331 }

-- Lesser Healing Wave r1-7
spells.LESSER_HEALING_WAVE  = { 25420, 10468, 10467, 10466, 8010, 8008, 8004 }

-- Earth Shield r1-3 (TBC new spell)
spells.EARTH_SHIELD        = { 32594, 32593, 974 }

-- --- Totems ------------------------------------------------------------------

-- Water
spells.MANA_TIDE_TOTEM      = { 16190 }
spells.HEALING_STREAM_TOTEM = { 25567, 10461, 10460, 6372, 6371, 5672 }
spells.MANA_SPRING_TOTEM    = { 25569, 10494, 10493, 10491, 5677 }

-- Fire (both give raid throughput - place whichever is learned)
spells.TOTEM_OF_WRATH       = { 30706 }          -- TBC: +3% spell crit to party
spells.FLAMETONGUE_TOTEM    = { 25557, 16387, 16386, 16385, 8233 }

-- Air
spells.WRATH_OF_AIR_TOTEM   = { 3738 }           -- TBC: 5% spell haste to party
spells.WINDFURY_TOTEM       = { 25587, 25585, 10614, 10613, 8512 }

-- Earth
spells.TREMOR_TOTEM         = { 8143 }
spells.STONESKIN_TOTEM      = { 25509, 10408, 8156, 8155, 8154 }

-- --- Cooldowns ---------------------------------------------------------------

spells.NATURES_SWIFTNESS    = { 16188 }           -- TBC talent

-- Lust (Horde = Bloodlust, Alliance = Heroism)
spells.BLOODLUST            = { 2825 }
spells.HEROISM              = { 32182 }

-- --- Dispels -----------------------------------------------------------------
-- TBC Resto can remove Poison and Disease only. No curse/magic removal.

spells.CURE_POISON          = { 526 }
spells.CURE_DISEASE         = { 2870 }
spells.POISON_CLEANSING_TOTEM = { 8166 }
spells.DISEASE_CLEANSING_TOTEM = { 8170 }
spells.GROUNDING_TOTEM      = { 8177 }
spells.GHOST_WOLF           = { 2645 }
spells.PURGE                = { 8012, 370 }       -- removes 1 magic buff from enemy

-- --- DPS fillers -------------------------------------------------------------

spells.CHAIN_LIGHTNING      = { 25442, 25439, 10605, 2860, 930, 421 }
spells.LIGHTNING_BOLT       = { 25449, 25448, 15208, 15207 }
spells.EARTH_SHOCK          = { 25454, 10414, 10413, 10412, 8045 }  -- interrupt + damage
spells.FLAME_SHOCK          = { 29228, 25457, 10448, 10447, 8051, 8050 }

-- --- Self-buffs ---------------------------------------------------------------

-- Water Shield r1-2 (r3 = 57960 is WotLK - not included)
spells.LIGHTNING_SHIELD     = { 25472, 25469, 10432, 10431, 10430, 8134, 8133, 8132, 324 }

-- Flametongue Weapon: TBC Resto mainhand buff (spell power); ranks 1-7
spells.FLAMETONGUE_WEAPON   = { 25489, 16342, 16341, 16339, 8030, 8027, 8024 }

spells.TOTEMIC_RECALL       = { 36936 }

-- --- Buff tracking IDs -------------------------------------------------------

spells.EARTH_SHIELD_BUFF    = { 32594, 32593, 974 }
spells.WATER_SHIELD_BUFF    = { 33736, 24398 }

-- --- Constants ---------------------------------------------------------------

spells.CHAIN_HEAL_JUMP_RANGE = 12   -- yards, TBC confirmed

spells.BERSERKING = { 26297 }
spells.BLOOD_FURY = { 33697, 20572 }
spells.WAR_STOMP = { 20549 }
spells.HEROIC_PRESENCE = { 28878 }

spells.BUFF_BERSERKING = { 26297 }
spells.BUFF_BLOOD_FURY = { 33697, 20572 }
spells.BUFF_HEROIC_PRESENCE = { 28878 }

spells.HASTE_POTION = { 28508, 22832 }
spells.SUPER_MANA_POTION = { 28499, 22828 }
spells.SCROLL_OF_INTELLECT = { 22732, 10291 }
spells.SCROLL_OF_STAMINA = { 22733, 10292 }

spells.ANCESTRAL_SPIRIT  = { 25590, 20777, 20776, 20775, 2008 }

-- Pacify debuffs that prevent casting (e.g., Mechanar's Pacifying Dust)
spells.PACIFY_BUFFS = { 32904, 6465 }

return spells
