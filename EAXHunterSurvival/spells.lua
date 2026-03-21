-- spells.lua  |  EAX Hunter Survival  |  TBC
local spells = {}

-- ── Ranged shots ──────────────────────────────────────────────────────────────
spells.AUTO_SHOT      = { 75 }
spells.AIMED_SHOT     = { 19434, 19426, 19407, 19405, 19404, 19403, 19402, 19401, 19400, 19880 }
spells.ARCANE_SHOT    = { 27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 14280, 3044, 3034, 3018, 3017, 2714 }
spells.STEADY_SHOT    = { 34120, 56654 }
spells.MULTI_SHOT     = { 27021, 14290, 14289, 14288, 14287, 14286, 2643 }

-- ── Pet abilities ─────────────────────────────────────────────────────────────
spells.KILL_COMMAND = { 34026, 25272 }
spells.MEND_PET     = { 27046, 24401, 13583, 13582, 13581, 13580, 13579, 3111, 136 }
spells.REVIVE_PET   = { 982 }
spells.CALL_PET     = { 883 }

-- ── Stings ────────────────────────────────────────────────────────────────────
spells.SERPENT_STING  = { 27016, 13550, 13549, 13548, 13547, 1978 }
spells.HUNTERS_MARK   = { 14325, 14323, 14322, 1130 }

-- ── Aspects ───────────────────────────────────────────────────────────────────
spells.ASPECT_OF_THE_HAWK   = { 27044, 25296, 14327, 14326, 14325, 14324, 14323, 14322, 13165 }
spells.ASPECT_OF_THE_MONKEY = { 13163 }
spells.ASPECT_OF_THE_VIPER  = { 34074 }

-- ── Traps ─────────────────────────────────────────────────────────────────────
spells.IMMOLATION_TRAP = { 27023, 14305, 14304, 14303, 14302, 13795 }
spells.EXPLOSIVE_TRAP  = { 27025, 14317, 14316, 14315, 14314, 13813 }
spells.FREEZING_TRAP   = { 14311, 14310, 3355 }

-- ── Cooldowns ─────────────────────────────────────────────────────────────────
spells.RAPID_FIRE = { 3045 }

-- ── Utility ───────────────────────────────────────────────────────────────────
spells.DISENGAGE        = { 781 }
spells.FEIGN_DEATH      = { 5384 }
spells.WING_CLIP        = { 14268, 14267, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 14259, 2974 }
spells.CONCUSSIVE_SHOT  = { 19407, 5116 }
spells.SCATTER_SHOT     = { 19503 }
spells.RAPTOR_STRIKE    = { 27014, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 14259, 14258, 2973 }
spells.MONGOOSE_BITE    = { 14271, 14270, 14269 }

-- ── Racials ───────────────────────────────────────────────────────────────────
spells.BERSERKING = { 26297 }
spells.BLOOD_FURY = { 33697, 20572 }
spells.WAR_STOMP  = { 20549 }
spells.SHADOWMELD = { 58984 }

-- ── Buff / Debuff check tables ────────────────────────────────────────────────
spells.BUFF_ASPECT_OF_THE_HAWK  = { 27044, 25296, 14327, 14326, 14325, 14324, 14323, 14322, 13165 }
spells.BUFF_ASPECT_OF_THE_VIPER = { 34074 }
spells.BUFF_RAPID_FIRE          = { 3045 }
spells.BUFF_BERSERKING          = { 26297 }
spells.BUFF_BLOOD_FURY          = { 33697, 20572 }

spells.DEBUFF_HUNTERS_MARK  = { 14325, 1130 }
spells.DEBUFF_SERPENT_STING = { 27016, 13550, 1978 }

spells.DEBUFF_WING_CLIP   = { 2974, 14261, 14262, 14263, 14264, 14265, 14266, 14267, 14268 }
spells.DEBUFF_CONCUSSIVE  = { 5116 }

return spells
