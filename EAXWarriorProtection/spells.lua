-- EAX Warrior Protection | spells.lua
-- Rank tables and buff/debuff ID tables only.
-- Ranks are ordered highest-to-lowest for resolve_spell_id().

local spells = {}

-- ═══ Core threat abilities ═══
spells.SHIELD_SLAM     = { 30356, 25258, 23925, 23924, 23923, 23922 }
spells.REVENGE         = { 30357, 25269, 25288, 20647, 11601, 11600, 7379, 6572 }
spells.DEVASTATE       = { 30022, 30020, 30016, 20243 }
spells.HEROIC_STRIKE   = { 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }
spells.CLEAVE          = { 25231, 20569, 11609, 11608, 7369, 845 }
spells.SUNDER_ARMOR    = { 25225, 11597, 11596, 8380, 7405, 7386 }
spells.THUNDER_CLAP    = { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
spells.EXECUTE         = { 25236, 25234, 20662, 20661, 20660, 20658, 5308 }
spells.MORTAL_STRIKE   = { 30330, 25248, 21553, 21552, 21551, 12294 }
spells.WHIRLWIND       = { 1680 }
spells.OVERPOWER       = { 11585, 11584, 7887, 7384 }
spells.SLAM            = { 25242, 25241, 11605, 11604, 8820, 1464 }
spells.DEEP_WOUNDS     = { 12867, 12850, 12849, 12834 }
spells.SWEEPING_STRIKES = { 12292 }
spells.HEROIC_THROW    = { 27176, 57735 }
spells.SHATTERING_THROW = { 32736, 35798 }

-- ═══ Defensive cooldowns ═══
spells.SHIELD_BLOCK       = { 2565 }
spells.LAST_STAND         = { 12975 }
spells.SHIELD_WALL        = { 871 }
spells.SPELL_REFLECTION   = { 23920 }
spells.SHIELD_BASH        = { 29704, 1672, 1671, 72 }
spells.CONCUSSION_BLOW    = { 12809 }
spells.DISARM             = { 676 }

-- ═══ Utility ═══
spells.BATTLE_SHOUT       = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
spells.COMMANDING_SHOUT   = { 469 }
spells.BLOODRAGE          = { 2687 }
spells.DEMORALIZING_SHOUT = { 25202, 11556, 11555, 11554, 6190, 1160 }
spells.TAUNT              = { 355 }
spells.CHALLENGING_SHOUT  = { 1161 }
spells.MOCKING_BLOW       = { 25266, 20560, 20559, 7402, 7400, 694 }
spells.HAMSTRING          = { 25212, 7373, 7372, 1715 }
spells.REND              = { 25208, 11574, 11573, 11572, 6548, 6547, 6546, 772 }
spells.CHARGE            = { 11578, 6178, 100 }
spells.INTERCEPT         = { 25275, 25272, 20617, 20616, 20252 }
spells.INTIMIDATING_SHOUT = { 5246 }
spells.STONEFORM         = { 20594 }
spells.WAR_STOMP         = { 20549 }
spells.PIERCING_HOWL     = { 12323 }
spells.BERSERKER_RAGE    = { 18499 }
spells.RETALIATION       = { 20230 }

-- ═══ Stances ═══
spells.BATTLE_STANCE     = { 2457 }
spells.BERSERKER_STANCE  = { 2458 }
spells.DEFENSIVE_STANCE  = { 71 }
spells.TACTICAL_MASTERY  = { 12677, 12676, 12295 }

-- ═══ Racials / Burst ═══
spells.BLOOD_FURY        = { 20572 }
spells.BERSERKING        = { 26297 }
spells.DEATH_WISH        = { 12328 }
spells.RECKLESSNESS      = { 1719 }

-- ═══ Consumables ═══
spells.HEALTHSTONE_ITEMS      = { 22105, 22104, 22103, 19013, 19012, 9421, 19011, 19010, 5510, 19009, 19008, 5509, 19007, 19006, 5511, 19005, 19004, 5512 }
spells.HEALING_POTION_ITEMS   = { 22829, 13446, 3928, 1710, 929, 858, 118 }
spells.IRONSHIELD_POTION_ITEMS = { 22849 }

-- ═══ Buff / debuff tables ═══
spells.BUFF_BATTLE_SHOUT       = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
spells.BUFF_COMMANDING_SHOUT   = { 469 }
spells.BUFF_BLOODRAGE          = { 2687 }
spells.BUFF_STONEFORM          = { 20594 }
spells.BUFF_SHIELD_BLOCK       = { 2565 }
spells.BUFF_LAST_STAND         = { 12975 }
spells.BUFF_SHIELD_WALL        = { 871 }
spells.BUFF_SPELL_REFLECTION   = { 23920 }
spells.BUFF_BATTLE_STANCE      = { 2457 }
spells.BUFF_BERSERKER_STANCE   = { 2458 }
spells.BUFF_DEFENSIVE_STANCE   = { 71 }
spells.BUFF_BLOODLUST_HEROISM  = { 2825, 32182 }
spells.BUFF_BLOOD_FURY         = { 20572 }
spells.BUFF_BERSERKING         = { 26297 }
spells.BUFF_DEATH_WISH         = { 12328 }
spells.BUFF_RECKLESSNESS       = { 1719 }
spells.BUFF_IRONSHIELD_POTION  = { 33147 }
spells.BUFF_BERSERKER_RAGE     = { 18499 }
spells.BUFF_RETALIATION        = { 20230 }
spells.DEBUFF_DEMORALIZING_SHOUT = { 25202, 11556, 11555, 11554, 6190, 1160 }
spells.DEBUFF_SUNDER_ARMOR     = { 25225, 11597, 11596, 8380, 7405, 7386 }
spells.DEBUFF_THUNDER_CLAP     = { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
spells.DEBUFF_REND             = { 25208, 11574, 11573, 11572, 6548, 6547, 6546, 772 }
spells.DEBUFF_HAMSTRING        = { 25212, 7373, 7372, 1715 }
spells.DEBUFF_DEEP_WOUNDS      = { 12867, 12850, 12849, 12834 }
spells.DEBUFF_SHIELD_SLAM      = { 30356, 23922, 23923 }
spells.BUFF_SWEEPING_STRIKES   = { 12292 }

spells.BERSERKING = { 26297 }
spells.BLOOD_FURY = { 33697, 20572 }
spells.WAR_STOMP = { 20549 }
spells.BERSERKER_RAGE = { 18499 }

spells.BUFF_BERSERKING = { 26297 }
spells.BUFF_BLOOD_FURY = { 33697, 20572 }
spells.BUFF_BERSERKER_RAGE = { 18499 }

spells.HASTE_POTION = { 28508, 22832 }
spells.SUPER_MANA_POTION = { 28499, 22828 }
spells.DRAGON_SLAYER = { 34775, 34774, 34773, 34772, 34771, 34770, 34769, 34768, 34767, 34766, 34765, 34764, 34763, 34762, 34761, 34760 }
spells.SCROLL_OF_MIGHT = { 22734, 10310 }
spells.SCROLL_OF_STAMINA = { 22733, 10292 }

return spells
