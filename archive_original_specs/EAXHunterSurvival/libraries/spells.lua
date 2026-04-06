-- spells.lua  |  Eax Hunter Survival  |  TBC
local spells = {}

-- -- Ranged shots --------------------------------------------------------------
spells.AUTO_SHOT      = { 75 }
spells.AIMED_SHOT     = { 27065, 20904, 20903, 20902, 20901, 20900, 19434 }
spells.ARCANE_SHOT    = { 27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 }
spells.STEADY_SHOT    = { 34120 }
spells.MULTI_SHOT     = { 27021, 25294, 14290, 14289, 14288, 2643 }
spells.RAPTOR_STRIKE  = { 27014, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 14259, 14258, 2973 }

-- -- Pet abilities -------------------------------------------------------------
spells.KILL_COMMAND = { 34026 }
spells.MEND_PET     = { 27046, 13544, 13543, 13542, 3662, 3661, 3111, 136 }
spells.REVIVE_PET   = { 982 }
spells.CALL_PET     = { 883 }

-- -- Stings --------------------------------------------------------------------
spells.SERPENT_STING  = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
spells.HUNTERS_MARK   = { 14325, 14324, 14323, 1130 }

-- -- Aspects -------------------------------------------------------------------
spells.ASPECT_OF_THE_HAWK   = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
spells.ASPECT_OF_THE_MONKEY = { 13163 }
spells.ASPECT_OF_THE_VIPER  = { 34074 }
spells.ASPECT_OF_THE_CHEETAH = { 5118 }
spells.ASPECT_OF_THE_PACK    = { 13159 }

-- -- Traps ---------------------------------------------------------------------
spells.IMMOLATION_TRAP = { 27023, 14305, 14304, 14303, 14302, 13795 }
spells.EXPLOSIVE_TRAP  = { 27025, 14317, 14316, 14315, 14314, 13813 }
spells.FREEZING_TRAP   = { 14311, 14310, 1499 }

-- -- Cooldowns -----------------------------------------------------------------
spells.RAPID_FIRE = { 3045 }
spells.MISDIRECTION = { 34477 }
spells.DETERRENCE = { 19263 }
spells.FLARE = { 1543 }

-- -- Utility -------------------------------------------------------------------
spells.DISENGAGE        = { 781 }
spells.FEIGN_DEATH      = { 5384 }
spells.SCARE_BEAST      = { 1513, 14326, 14327, 14328, 14329, 14330 }
spells.WING_CLIP        = { 14268, 14267, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 14259, 2974 }
spells.WYVERN_STING     = { 27068, 24133, 24132, 19386 }
spells.CONCUSSIVE_SHOT  = { 5116 }
spells.SCATTER_SHOT     = { 19503 }
spells.MONGOOSE_BITE    = { 14271, 14270, 14269 }

-- -- Racials -------------------------------------------------------------------
spells.BERSERKING = { 26297 }
spells.BLOOD_FURY = { 33697, 20572 }
spells.WAR_STOMP  = { 20549 }
spells.SHADOWMELD = { 1784 }

-- -- Buff / Debuff check tables ------------------------------------------------
spells.BUFF_ASPECT_OF_THE_HAWK  = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
spells.BUFF_ASPECT_OF_THE_VIPER = { 34074 }
spells.BUFF_ASPECT_OF_THE_CHEETAH = { 5118 }
spells.BUFF_ASPECT_OF_THE_PACK    = { 13159 }
spells.BUFF_RAPID_FIRE          = { 3045 }
spells.BUFF_MISDIRECTION        = { 35079 }
spells.BUFF_BERSERKING          = { 26297 }
spells.BUFF_BLOOD_FURY          = { 33697, 20572 }

spells.DEBUFF_HUNTERS_MARK  = { 14325, 1130 }
spells.DEBUFF_SERPENT_STING = { 27016, 13550, 1978 }
spells.DEBUFF_EXPOSE_WEAKNESS = { 33830, 12868 }

spells.DEBUFF_WING_CLIP   = { 2974, 14261, 14262, 14263, 14264, 14265, 14266, 14267, 14268 }
spells.DEBUFF_CONCUSSIVE  = { 5116 }

-- Pacify debuffs that prevent casting (e.g., Mechanar's Pacifying Dust)
spells.PACIFY_BUFFS = { 32904, 6465 }

return spells
