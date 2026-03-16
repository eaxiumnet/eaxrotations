-- spells.lua
-- EAX Shaman Elemental | Spell tables
-- IDs derived from the legacy OpenShaman2 dataset

local spells = {}

spells.LIGHTNING_BOLT = { 25449, 25448, 15208, 15207 }
spells.CHAIN_LIGHTNING = { 25442, 25439, 10605, 2860, 930, 421 }
spells.FLAME_SHOCK = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
spells.ELEMENTAL_MASTERY = { 16166 }
spells.NATURES_SWIFTNESS = { 16188, 17116 }
spells.TOTEM_OF_WRATH = { 30706 }
spells.MANA_SPRING_TOTEM = { 25569, 10494, 10493, 10491, 5677 }

spells.BUFF_FLAME_SHOCK = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
spells.BUFF_TOTEM_OF_WRATH = { 30708 }

spells.CHAIN_LIGHTNING_RADIUS = 30
spells.TOTEM_REFRESH_INTERVAL_S = 30

return spells
