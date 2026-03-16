-- EAX Warrior Arms | spells.lua
-- Rank tables and buff/debuff ID tables only.
-- Ranks are ordered highest-to-lowest for resolve_spell_id().

local spells = {}

-- ═══ Offensive abilities ═══
spells.MORTAL_STRIKE     = { 30330, 25248, 21553, 21552, 21551, 12294 }
spells.SLAM              = { 25242, 25241, 11605, 11604, 8820, 1464 }
spells.WHIRLWIND         = { 1680 }
spells.EXECUTE           = { 25236, 25234, 20662, 20661, 20660, 20658, 5308 }
spells.HEROIC_STRIKE     = { 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }
spells.CLEAVE            = { 25231, 20569, 11609, 11608, 7369, 845 }
spells.OVERPOWER         = { 11585, 11584, 7887, 7384 }
spells.HAMSTRING         = { 25212, 7373, 7372, 1715 }
spells.REND              = { 25208, 11574, 11573, 11572, 6548, 6547, 6546, 772 }
spells.SUNDER_ARMOR      = { 25225, 11597, 11596, 8380, 7405, 7386 }
spells.THUNDER_CLAP      = { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
spells.INTERCEPT         = { 25275, 25272, 20617, 20616, 20252 }
spells.CHARGE            = { 11578, 6178, 100 }
spells.PIERCING_HOWL     = { 12323 }
spells.INTIMIDATING_SHOUT = { 5246 }
spells.BLOODTHIRST       = { 30335, 23894, 23893, 23892, 23881 }
spells.REVENGE           = { 30357, 12712, 12711, 12710 }
spells.DEVASTATE         = { 30022, 20243 }
spells.DEEP_WOUNDS       = { 12867, 12850, 12849, 12834 }
spells.SHIELD_SLAM       = { 30356, 23922, 23923 }
spells.SHIELD_BLOCK      = { 871, 10716, 10717 }
spells.SPELL_REFLECTION  = { 23920, 23919 }
spells.DISARM            = { 676, 6870, 6871 }
spells.HEROIC_THROW      = { 27176, 57735 }
spells.SHATTERING_THROW  = { 32736, 35798 }

-- ═══ Self buffs / utility ═══
spells.BATTLE_SHOUT      = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
spells.COMMANDING_SHOUT  = { 469 }
spells.BLOODRAGE         = { 2687 }
spells.BERSERKER_RAGE    = { 18499 }
spells.DEMORALIZING_SHOUT = { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
spells.SWEEPING_STRIKES  = { 12292 }
spells.STONEFORM         = { 20594 }
spells.WAR_STOMP         = { 20549 }

-- ═══ Stances / cooldowns / interrupt ═══
spells.BATTLE_STANCE     = { 2457 }
spells.BERSERKER_STANCE  = { 2458 }
spells.DEFENSIVE_STANCE  = { 71 }
spells.DEATH_WISH        = { 12328 }
spells.RECKLESSNESS      = { 1719 }
spells.BLOOD_FURY        = { 20572 }
spells.BERSERKING        = { 26297 }
spells.PUMMEL            = { 6554, 6552 }
spells.TACTICAL_MASTERY  = { 12677, 12676, 12295 }

-- ═══ Consumables ═══
spells.HEALTHSTONE_ITEMS      = { 22105, 22104, 22103, 19013, 19012, 9421, 19011, 19010, 5510, 19009, 19008, 5509, 19007, 19006, 5511, 19005, 19004, 5512 }
spells.HEALING_POTION_ITEMS   = { 22829, 13446, 3928, 1710, 929, 858, 118 }

-- ═══ Buff / debuff tables ═══
spells.BUFF_BATTLE_SHOUT       = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
spells.BUFF_COMMANDING_SHOUT   = { 469 }
spells.BUFF_BLOODRAGE          = { 2687 }
spells.BUFF_BERSERKER_RAGE     = { 18499 }
spells.BUFF_STONEFORM          = { 20594 }
spells.BUFF_SWEEPING_STRIKES   = { 12292 }
spells.BUFF_BATTLE_STANCE      = { 2457 }
spells.BUFF_BERSERKER_STANCE   = { 2458 }
spells.BUFF_DEFENSIVE_STANCE   = { 71 }
spells.BUFF_DEATH_WISH         = { 12328 }
spells.BUFF_RECKLESSNESS       = { 1719 }
spells.BUFF_BLOODLUST_HEROISM  = { 2825, 32182 }
spells.BUFF_BLOOD_FURY         = { 20572 }
spells.BUFF_BERSERKING         = { 26297 }
spells.BUFF_HASTE_POTION       = { 28507 }
spells.BUFF_DESTRUCTION_POTION = { 28508 }
spells.BUFF_DRUMS_OF_BATTLE    = { 35476 }
spells.BUFF_DRUMS_OF_WAR       = { 35475 }
spells.DEBUFF_REND             = { 25208, 11574, 11573, 11572, 6548, 6547, 6546, 772 }
spells.DEBUFF_DEMORALIZING_SHOUT = { 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
spells.DEBUFF_SUNDER_ARMOR     = { 25225, 11597, 11596, 8380, 7405, 7386 }
spells.DEBUFF_THUNDER_CLAP     = { 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
spells.DEBUFF_HAMSTRING        = { 25212, 7373, 7372, 1715 }
spells.DEBUFF_PIERCING_HOWL    = { 12323 }
spells.DEBUFF_DEEP_WOUNDS      = { 12867, 12850, 12849, 12834 }
spells.DEBUFF_SHIELD_SLAM      = { 30356, 23922, 23923 }
spells.DEBUFF_SPELL_REFLECTION = { 23920, 23919 }
spells.BUFF_BLOODTHIRST        = { 30335, 23894, 23893, 23892, 23881 }
spells.BUFF_REVENGE            = { 30357, 12712, 12711, 12710 }
spells.BUFF_DEVASTATE          = { 30022, 20243 }
spells.BUFF_SHIELD_SLAM        = { 30356 }
spells.BUFF_SHIELD_BLOCK       = { 871, 10716, 10717 }

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
