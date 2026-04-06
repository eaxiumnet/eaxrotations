-- spells.lua  |  EAX Port)  |  TBC
local spells = {}

-- -- Ranged shots --------------------------------------------------------------
spells.AUTO_SHOT    = { 75 }
spells.AIMED_SHOT   = { 27065, 20904, 20903, 20902, 20901, 20900, 19434 }
spells.ARCANE_SHOT  = { 27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 }
spells.STEADY_SHOT  = { 34120 }
spells.MULTI_SHOT   = { 27021, 25294, 14290, 14289, 14288, 2643 }

-- -- Survival talents ----------------------------------------------------------
spells.WYVERN_STING   = { 27068, 24133, 24132, 24131, 19386 }
spells.COUNTERATTACK  = { 27067, 20909, 20910, 19306 }
spells.MONGOOSE_BITE  = { 27063, 14271, 14270, 14269, 1495 }
spells.DETERRENCE     = { 19263 }
spells.EXPLOSIVE_TRAP  = { 27025, 14317, 14316, 14315, 14314, 13813 }

-- -- Pet abilities -------------------------------------------------------------
spells.KILL_COMMAND  = { 34026 }
spells.MEND_PET      = { 27046, 13544, 13543, 13542, 3662, 3661, 3111, 136 }
spells.REVIVE_PET    = { 982 }
spells.CALL_PET      = { 883 }

-- -- Stings --------------------------------------------------------------------
spells.SERPENT_STING = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
spells.SCORPID_STING = { 3043 }
spells.VIPER_STING   = { 27018, 14280, 14279, 3034 }
spells.HUNTERS_MARK  = { 14325, 14324, 14323, 1130 }

-- -- Aspects -------------------------------------------------------------------
spells.ASPECT_OF_THE_HAWK   = { 27044, 25296, 14327, 14326, 14325, 14324, 14323, 14322, 13165 }
spells.ASPECT_OF_THE_MONKEY = { 13163 }
spells.ASPECT_OF_THE_VIPER  = { 34074 }
spells.ASPECT_OF_THE_CHEETAH = { 5118 }
spells.ASPECT_OF_THE_PACK    = { 13159 }

-- -- Traps ---------------------------------------------------------------------
spells.IMMOLATION_TRAP = { 27023, 14305, 14304, 14303, 14302, 13795 }
spells.FREEZING_TRAP   = { 14311, 14310, 1499 }
spells.FROST_TRAP      = { 13810 }
spells.EXPLOSIVE_TRAP   = { 27025, 14317, 14316, 14315, 14314, 13813 }
spells.SNAKE_TRAP      = { 34600 }

-- -- Cooldowns -----------------------------------------------------------------
spells.RAPID_FIRE = { 3045 }
spells.MISDIRECTION = { 34477 }
spells.FLARE = { 1543 }

-- -- Utility -------------------------------------------------------------------
spells.DISENGAGE        = { 781 }
spells.FEIGN_DEATH      = { 5384 }
spells.SCARE_BEAST      = { 1513, 14326, 14327, 14328, 14329, 14330 }
spells.WING_CLIP        = { 14268, 14267, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 14259, 2974 }
spells.CONCUSSIVE_SHOT  = { 19407, 5116 }
spells.SCATTER_SHOT     = { 19503 }
spells.RAPTOR_STRIKE    = { 27014, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 14259, 14258, 2973 }

-- -- Racials -------------------------------------------------------------------
spells.BERSERKING = { 26297 }
spells.BLOOD_FURY = { 33697, 20572 }
spells.WAR_STOMP  = { 20549 }
spells.SHADOWMELD = { 1784 }

-- -- Buff / Debuff check tables ------------------------------------------------
spells.BUFF_ASPECT_OF_THE_HAWK  = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
spells.BUFF_ASPECT_OF_THE_VIPER = { 34074 }
spells.BUFF_ASPECT_OF_THE_MONKEY = { 13163 }
spells.BUFF_ASPECT_OF_THE_CHEETAH = { 5118 }
spells.BUFF_ASPECT_OF_THE_PACK    = { 13159 }
spells.BUFF_RAPID_FIRE          = { 3045 }
spells.BUFF_MISDIRECTION        = { 35079 }
spells.BUFF_BERSERKING          = { 26297 }
spells.BUFF_BLOOD_FURY          = { 33697, 20572 }

spells.DEBUFF_HUNTERS_MARK  = { 14325, 1130 }
spells.DEBUFF_SERPENT_STING = { 27016, 13550, 1978 }
spells.DEBUFF_SCORPID_STING = { 3043 }
spells.DEBUFF_VIPER_STING   = { 27018, 14280, 14279, 3034 }

spells.DEBUFF_WING_CLIP   = { 2974, 14261, 14262, 14263, 14264, 14265, 14266, 14267, 14268 }
spells.DEBUFF_CONCUSSIVE  = { 5116 }

-- Pacify debuffs that prevent casting
spells.PACIFY_BUFFS = { 32904, 6465 }

-- Arcane-immune NPCs (by npcID) - from 
spells.ARCANE_IMMUNE_NPCS = {
    [18864] = true,
    [18865] = true,
    [15691] = true,
    [20478] = true,
}

return spells
