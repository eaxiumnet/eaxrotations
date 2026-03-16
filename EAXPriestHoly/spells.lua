-- EAX Priest Holy | spells.lua
-- Spell ID tables ordered highest-to-lowest for each Holy spell referenced by the rotation.

local spells = {}

spells.RENEW = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
spells.GREATER_HEAL = { 25213, 25210, 25314, 10965, 10964, 10963, 2060 }
spells.PRAYER_OF_HEALING = { 25316, 25308, 10961, 10960, 996, 596 }
spells.PRAYER_OF_MENDING = { 33110, 33076 }
spells.FLASH_HEAL = { 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }
spells.CIRCLE_OF_HEALING = { 34866, 34865, 34864, 34863, 34862, 34861 }

return spells
