-- EAX Priest Discipline | spells.lua
-- Spell ID tables ordered high-to-low for resolving the highest learned rank.

local spells = {}

spells.POWER_WORD_SHIELD = { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }
spells.RENEW = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
spells.PRAYER_OF_MENDING = { 33110, 33076 }
spells.POWER_INFUSION = { 10060 }
spells.PAIN_SUPPRESSION = { 33206 }

return spells
