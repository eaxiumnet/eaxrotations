-- EAX PaladinProtection | spells.lua
-- Rank tables and buff identifiers only.

local spells = {}

-- Threat and utility abilities
spells.AVENGERS_SHIELD = { 32700, 31935 }
spells.CONSECRATION = { 27173, 20924, 20923, 26573 }
spells.JUDGEMENT = { 53408, 20271 }
spells.HOLY_SHIELD = { 27179, 20925, 20927, 20928 }
spells.RIGHTEOUS_FURY = { 25780 }

-- Buff tables used for state detection
spells.BUFF_RIGHTEOUS_FURY = { 25780 }
spells.BUFF_HOLY_SHIELD = { 20925, 20927, 20928, 27179 }

-- Default AoE radius (yards) for Consecration profiling.
spells.DEFAULT_AOE_RADIUS = 8

return spells
