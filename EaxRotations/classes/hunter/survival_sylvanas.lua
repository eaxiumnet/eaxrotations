-- Hunter Survival priority list.

-- ============================================================================
-- What: Hunter Survival priority list with traps, shots, and ranged control tools
-- When: Evaluated every tick via main_sylvanas.lua dispatcher
-- Why: Priority-list early-exit keeps control and damage checks efficient
-- Safety: Nil-guarded settings; NS.* wrappers; optional clip tracker; conservative fallback behavior
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.HunterSpells or {}

local AUTO_SHOT_BUFFER_MS = 100
local MULTI_SHOT_CAST_MS = 500

local function can_cast_steady(context, action)
    if not NS.action_matches(context, action) then return false end
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.can_cast_steady) == "function" then
        return tracker.can_cast_steady() ~= false
    end
    return true
end

local function can_cast_before_auto(context, action, cast_ms)
    if not NS.action_matches(context, action) then return false end
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.ms_until_auto) == "function" then
        local remain = tracker.ms_until_auto()
        return remain == 0 or remain > cast_ms + AUTO_SHOT_BUFFER_MS
    end
    return true
end

local function record_manual_shot()
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.record_manual_shot) == "function" then
        tracker.record_manual_shot()
    end
end

local function execute_action(context, action, prefix)
    if NS.action_execute(context, action, prefix) then
        if action.after_cast then action.after_cast(context, action) end
        return true
    end
    return false
end

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local HUNTERS_MARK_DEBUFF = { 14325, 14324, 14323, 1130 }
local SERPENT_STING_DEBUFF = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local SCORPID_STING_DEBUFF = { 3043 }
local WING_CLIP_DEBUFF = { 2974 }
local ASPECT_HAWK_BUFF = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
local ASPECT_VIPER_BUFF = { 34074 }

-- ============================================================================
-- State builder
-- ============================================================================
local sv_state = {
    has_pet = false,
    pet_alive = false,
    pet_dead = false,
    pre_steady_leveling = false,
    pet_hp_pct = 100,
    has_hunters_mark = false,
    has_serpent_sting = false,
    has_aspect_hawk = false,
    has_aspect_viper = false,
    mend_pet_ready = false,
    hunters_mark_ready = false,
    rapid_fire_ready = false,
    explosive_trap_ready = false,
    kill_command_ready = false,
    multi_shot_ready = false,
    steady_shot_ready = false,
    arcane_shot_ready = false,
    serpent_sting_ready = false,
    call_pet_ready = false,
    revive_pet_ready = false,
    feign_death_ready = false,
    freezing_trap_ready = false,	    viper_sting_ready = false,
    scorpid_sting_ready = false,
    readiness_ready = false,
    raptor_strike_ready = false,
    wing_clip_ready = false,
    volley_ready = false,
    has_scorpid_sting = false,
    wing_clip_active = false,
    mana_pct = 100,
    in_combat = false,
    enemy_count = 1,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target
    local pet = context.pet or (NS.GetPet and NS.GetPet()) or nil
    local pet_alive = pet and ((NS.unit_alive and NS.unit_alive(pet)) or (pet.is_alive and pet:is_alive()) or false) or false

    sv_state.has_pet = pet ~= nil
    sv_state.pet_alive = pet_alive == true
    sv_state.pet_dead = context.pet_dead == true or (pet ~= nil and not sv_state.pet_alive)
    sv_state.pet_hp_pct = sv_state.pet_alive and pet.get_health_percentage and pet:get_health_percentage() or 100
    sv_state.has_hunters_mark = target and NS.debuff_up(target, HUNTERS_MARK_DEBUFF) or false
    sv_state.has_serpent_sting = target and NS.debuff_up(target, SERPENT_STING_DEBUFF) or false
    sv_state.has_scorpid_sting = target and NS.debuff_up(target, SCORPID_STING_DEBUFF) or false
    sv_state.wing_clip_active = target and NS.debuff_up(target, WING_CLIP_DEBUFF) or false
    sv_state.has_aspect_hawk = me and NS.buff_up(me, ASPECT_HAWK_BUFF) or false
    sv_state.has_aspect_viper = me and NS.buff_up(me, ASPECT_VIPER_BUFF) or false
    sv_state.mend_pet_ready = me and NS.spell_ready(SPELLS.MendPet, me, { skip_range = true }) or false
    sv_state.hunters_mark_ready = target and NS.spell_ready(SPELLS.HuntersMark, target) or false
    sv_state.rapid_fire_ready = me and NS.spell_ready(SPELLS.RapidFire, me, { skip_range = true, expected_cooldown = 300 }) or false
    sv_state.explosive_trap_ready = me and NS.spell_ready(SPELLS.ExplosiveTrap, me, { skip_range = true, expected_cooldown = 30 }) or false
    sv_state.kill_command_ready = target and NS.spell_ready(SPELLS.KillCommand, target, { expected_cooldown = 5 }) or false
    sv_state.multi_shot_ready = target and NS.spell_ready(SPELLS.MultiShot, target, { expected_cooldown = 10 }) or false
    sv_state.steady_shot_ready = target and NS.spell_ready(SPELLS.SteadyShot, target) or false
    sv_state.arcane_shot_ready = target and NS.spell_ready(SPELLS.ArcaneShot, target, { expected_cooldown = 6 }) or false
    sv_state.serpent_sting_ready = target and NS.spell_ready(SPELLS.SerpentSting, target) or false
    sv_state.call_pet_ready = me and NS.spell_ready(SPELLS.CallPet, me, { skip_range = true }) or false
    sv_state.revive_pet_ready = me and NS.spell_ready(SPELLS.RevivePet, me, { skip_range = true }) or false
    sv_state.feign_death_ready = me and NS.spell_ready(SPELLS.FeignDeath, me, { skip_range = true, expected_cooldown = 30 }) or false
    sv_state.freezing_trap_ready = me and NS.spell_ready(SPELLS.FreezingTrap, me, { skip_range = true, expected_cooldown = 30 }) or false	    sv_state.viper_sting_ready = target and NS.spell_ready(SPELLS.ViperSting, target, { expected_cooldown = 8 }) or false
    sv_state.wyvern_sting_ready = target and NS.spell_ready(SPELLS.WyvernSting, target) or false
    sv_state.scorpid_sting_ready = target and NS.spell_ready(SPELLS.ScorpidSting, target) or false
    sv_state.raptor_strike_ready = target and NS.spell_ready(SPELLS.RaptorStrike, target) or false
    sv_state.wing_clip_ready = target and NS.spell_ready(SPELLS.WingClip, target) or false
    sv_state.volley_ready = target and NS.spell_ready(SPELLS.Volley, target) or false
		    sv_state.readiness_ready = me and NS.spell_ready(SPELLS.Readiness, me, { skip_range = true, expected_cooldown = 180 }) or false
	    sv_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    sv_state.in_combat = context.in_combat or false
    sv_state.enemy_count = context.enemy_count or context.enemies_count or 1
    sv_state.pre_steady_leveling = ((context.player_level or 70) < 62) or (context.is_leveling == true and not sv_state.steady_shot_ready)

    return sv_state
end

local function cooldowns_enabled(context)
    return not context.settings or context.settings.use_cooldowns ~= false
end

-- ============================================================================
-- Action definitions (test assertion strings embedded)
-- ============================================================================
local MEND_PET_ACTION = { name = "MendPet", spell = SPELLS.MendPet, target = "pet", max_hp = 45, requires_target = false }
local HUNTERS_MARK_ACTION = { name = "HuntersMark", spell = SPELLS.HuntersMark, debuff = HUNTERS_MARK_DEBUFF, refresh = 10 }
local RAPID_FIRE_ACTION = { name = "RapidFire", spell = SPELLS.RapidFire, target = "self", combat = true, cooldown = 300, requires_target = false, setting = "use_cooldowns" }
local EXPLOSIVE_TRAP_ACTION = { name = "ExplosiveTrap", spell = SPELLS.ExplosiveTrap, target = "self", enemy_count = 3, cooldown = 30, requires_target = false }
local KILL_COMMAND_ACTION = { name = "KillCommand", spell = SPELLS.KillCommand, combat = true, cooldown = 5, skip_gcd = true }
local MULTI_SHOT_ACTION = { name = "MultiShot", spell = SPELLS.MultiShot, cooldown = 10 }
local STEADY_SHOT_ACTION = { name = "SteadyShot", spell = SPELLS.SteadyShot, not_moving = true }
local ARCANE_SHOT_ACTION = { name = "ArcaneShot", spell = SPELLS.ArcaneShot, cooldown = 6 }
local SERPENT_STING_ACTION = { name = "SerpentSting", spell = SPELLS.SerpentSting, debuff = SERPENT_STING_DEBUFF, refresh = 1.5 }
local ASPECT_HAWK_ACTION = { name = "AspectOfTheHawk", spell = SPELLS.AspectOfTheHawk, target = "self", kind = "buff", buff = ASPECT_HAWK_BUFF, requires_target = false, min_interval = 60 }
local ASPECT_VIPER_ACTION = { name = "AspectOfTheViper", spell = SPELLS.AspectOfTheViper, target = "self", kind = "buff", buff = ASPECT_VIPER_BUFF, requires_target = false, min_interval = 30 }
local CALL_PET_ACTION = { name = "CallPet", spell = SPELLS.CallPet, target = "self", requires_target = false }
local REVIVE_PET_ACTION = { name = "RevivePet", spell = SPELLS.RevivePet, target = "self", requires_target = false }
local FEIGN_DEATH_ACTION = { name = "FeignDeath", spell = SPELLS.FeignDeath, target = "self", cooldown = 30, requires_target = false }
local FREEZING_TRAP_ACTION = { name = "FreezingTrap", spell = SPELLS.FreezingTrap, target = "self", cooldown = 30, requires_target = false }	local VIPER_STING_ACTION = { name = "ViperSting", spell = SPELLS.ViperSting, cooldown = 8 }
local WYVERN_STING_ACTION = { name = "WyvernSting", spell = SPELLS.WyvernSting, cooldown = 0 }	local READINESS_ACTION = { name = "Readiness", spell = SPELLS.Readiness, target = "self", combat = true, cooldown = 180, requires_target = false, setting = "use_readiness" }local CONCUSSIVE_SHOT_ACTION = { name = "ConcussiveShot", spell = SPELLS.ConcussiveShot, cooldown = 0 }
		local MISDIRECTION_ACTION = { name = "Misdirection", spell = SPELLS.Misdirection, target = "pet", cooldown = 120, requires_target = false }
		local SCORPID_STING_ACTION = { name = "ScorpidSting", spell = SPELLS.ScorpidSting, debuff = SCORPID_STING_DEBUFF, refresh = 3 }
		local RAPTOR_STRIKE_ACTION = { name = "RaptorStrike", spell = SPELLS.RaptorStrike }
		local WING_CLIP_ACTION = { name = "WingClip", spell = SPELLS.WingClip }
		local VOLLEY_ACTION = { name = "Volley", spell = SPELLS.Volley, not_moving = true }

		-- ============================================================================
	-- Match functions
	-- ============================================================================
local function mend_pet_matches(context, s)
    if not s.pet_alive then return false end
    if s.pet_hp_pct > 45 then return false end
    if not s.mend_pet_ready then return false end
    return NS.action_matches(context, MEND_PET_ACTION)
end

local function hunters_mark_matches(context, s)
    if s.has_hunters_mark then return false end
    if not s.hunters_mark_ready then return false end
    return NS.action_matches(context, HUNTERS_MARK_ACTION)
end

local function rapid_fire_matches(context, s)
    if not cooldowns_enabled(context) then return false end
    if not s.in_combat then return false end
    if not s.rapid_fire_ready then return false end
    return NS.action_matches(context, RAPID_FIRE_ACTION)
end

local function explosive_trap_matches(context, s)
    if s.enemy_count < 3 then return false end
    if not s.explosive_trap_ready then return false end
    return NS.action_matches(context, EXPLOSIVE_TRAP_ACTION)
end

local function kill_command_matches(context, s)
    if not s.in_combat then return false end
    if not s.pet_alive then return false end
    if not s.kill_command_ready then return false end
    return NS.action_matches(context, KILL_COMMAND_ACTION)
end

local function multi_shot_matches(context, s)
    if not s.multi_shot_ready then return false end
    if context.has_breakable_cc_nearby then return false end
    if (s.mana_pct or 100) < 15 then return false end
    return can_cast_before_auto(context, MULTI_SHOT_ACTION, MULTI_SHOT_CAST_MS)
end

local function steady_shot_matches(context, s)
    if not s.steady_shot_ready then return false end
    return can_cast_steady(context, STEADY_SHOT_ACTION)
end

local function arcane_shot_matches(context, s)
    if not s.arcane_shot_ready then return false end
    if (s.mana_pct or 100) < 10 then return false end
    return NS.action_matches(context, ARCANE_SHOT_ACTION)
end

local function serpent_sting_matches(context, s)
    if s.has_serpent_sting then return false end
    if not s.serpent_sting_ready then return false end
    return NS.action_matches(context, SERPENT_STING_ACTION)
end

local function aspect_hawk_matches(context, s)
    if s.has_aspect_hawk then return false end
    return NS.action_matches(context, ASPECT_HAWK_ACTION)
end

local function aspect_viper_matches(context, s)
    if s.has_aspect_viper then return false end
    if s.mana_pct > 20 then return false end
    return NS.action_matches(context, ASPECT_VIPER_ACTION)
end

local function call_pet_matches(context, s)
    if s.has_pet then return false end
    if s.in_combat then return false end
    if not s.call_pet_ready then return false end
    return NS.action_matches(context, CALL_PET_ACTION)
end

local function revive_pet_matches(context, s)
    if s.has_pet and not s.pet_dead then return false end
    if s.in_combat then return false end
    if s.call_pet_ready and not s.pet_dead then return false end
    if not s.revive_pet_ready then return false end
    return NS.action_matches(context, REVIVE_PET_ACTION)
end

local function feign_death_matches(context, s)
    if not s.in_combat then return false end
    if not s.feign_death_ready then return false end
    return NS.action_matches(context, FEIGN_DEATH_ACTION)
end

local function freezing_trap_matches(context, s)
    if s.in_combat then return false end
    if not s.freezing_trap_ready then return false end
    return NS.action_matches(context, FREEZING_TRAP_ACTION)
end	local function viper_sting_matches(context, s)
	    if not s.viper_sting_ready then return false end
	    return NS.action_matches(context, VIPER_STING_ACTION)
	end

	-- ============================================================================
	-- Wyvern Sting: CC + DoT; suppress if target already has a DoT (breaks sleep)
	-- ============================================================================
	local function wyvern_sting_matches(context, s)
	    if not s.wyvern_sting_ready then return false end
	    if s.has_serpent_sting then return false end
	    if s.has_scorpid_sting then return false end
	    return NS.action_matches(context, WYVERN_STING_ACTION)
	end

	local function readiness_matches(context, s)
	    if not cooldowns_enabled(context) then return false end
	    if not s.in_combat then return false end
	    if not s.readiness_ready then return false end
	    -- Use after Rapid Fire has been used to reset it for 2nd burst window
	    if s.rapid_fire_ready then return false end
	    return NS.action_matches(context, READINESS_ACTION)
	end

	local function leveling_arcane_shot_matches(context, s)
    if not s.pre_steady_leveling then return false end
    if not s.arcane_shot_ready then return false end
    return NS.action_matches(context, ARCANE_SHOT_ACTION)
end

local function leveling_sting_matches(context, s)
    if not s.pre_steady_leveling then return false end
    if s.has_serpent_sting then return false end
    if (s.mana_pct or 100) < 25 then return false end
    if not s.serpent_sting_ready then return false end
    return NS.action_matches(context, SERPENT_STING_ACTION)
end	-- ============================================================================
	-- Concussive Shot: kiting/slow utility
	-- ============================================================================
	local function concussive_shot_matches(context, s)
	    if not context.has_valid_enemy_target then return false end
	    local target = context.target
	    if not target then return false end
	    local target_dist = target.get_distance and target:get_distance(context.me) or 20
	    if target_dist > 30 then return false end
	    return NS.action_matches(context, CONCUSSIVE_SHOT_ACTION)
	end

	-- ============================================================================
	-- Misdirection: redirect threat to pet
	-- ============================================================================
	local function misdirection_matches(context, s)
	    if not s.in_combat then return false end
	    if not s.pet_alive then return false end
	    return NS.spell_ready(SPELLS.Misdirection, context.me or NS.PLAYER_UNIT, { skip_range = true, expected_cooldown = 120 })
	end		local function misdirection_execute(context, s)
		    local pet = context.pet or (NS.GetPet and NS.GetPet()) or nil
		    if not pet then return false end
		    return NS.try_cast(SPELLS.Misdirection, pet, "[SURVIVAL] Misdirection")
		end

		-- ============================================================================
		-- Scorpid Sting: debuff reducing target's chance to hit
		-- ============================================================================
		local function scorpid_sting_matches(context, s)
		    if s.has_scorpid_sting then return false end
		    if not s.in_combat then return false end
		    if not s.scorpid_sting_ready then return false end
		    return NS.action_matches(context, SCORPID_STING_ACTION)
		end

		-- ============================================================================
		-- Raptor Strike: melee weaving when target in melee range
		-- ============================================================================
		local function raptor_strike_matches(context, s)
		    if not s.in_combat then return false end
		    local target = context.target
		    if not target then return false end
		    local dist = context.distance or context.target_distance or 100
		    if dist > 6 then return false end
		    if not s.raptor_strike_ready then return false end
		    return NS.action_matches(context, RAPTOR_STRIKE_ACTION)
		end

		-- ============================================================================
		-- Wing Clip: melee slow to keep enemies in range
		-- ============================================================================
		local function wing_clip_matches(context, s)
		    if not s.in_combat then return false end
		    if s.wing_clip_active then return false end
		    local target = context.target
		    if not target then return false end
		    local dist = context.distance or context.target_distance or 100
		    if dist > 6 then return false end
		    if not s.wing_clip_ready then return false end
		    return NS.action_matches(context, WING_CLIP_ACTION)
		end

		-- ============================================================================
		-- Volley: AoE channeled attack for multi-target
		-- ============================================================================
		local function volley_matches(context, s)
		    if not s.in_combat then return false end    if s.enemy_count < 4 then return false end
    if context.is_moving then return false end
    if not s.volley_ready then return false end
    return NS.action_matches(context, VOLLEY_ACTION)
end

		-- ============================================================================
		-- Strategies
	-- ============================================================================
local strategies = {
    { name = "MendPet", matches = mend_pet_matches, execute = function(context) return execute_action(context, MEND_PET_ACTION, "[SURVIVAL]") end },
    { name = "CallPet", matches = call_pet_matches, execute = function(context) return execute_action(context, CALL_PET_ACTION, "[SURVIVAL]") end },
    { name = "RevivePet", matches = revive_pet_matches, execute = function(context) return execute_action(context, REVIVE_PET_ACTION, "[SURVIVAL]") end },
    { name = "AspectOfTheHawk", matches = aspect_hawk_matches, execute = function(context) return execute_action(context, ASPECT_HAWK_ACTION, "[SURVIVAL]") end },
    { name = "AspectOfTheViper", matches = aspect_viper_matches, execute = function(context) return execute_action(context, ASPECT_VIPER_ACTION, "[SURVIVAL]") end },
    { name = "FreezingTrap", matches = freezing_trap_matches, execute = function(context) return execute_action(context, FREEZING_TRAP_ACTION, "[SURVIVAL]") end },    { name = "WyvernSting", matches = wyvern_sting_matches, execute = function(context) return execute_action(context, WYVERN_STING_ACTION, "[SURVIVAL]") end },
    { name = "HuntersMark", matches = hunters_mark_matches, execute = function(context) return execute_action(context, HUNTERS_MARK_ACTION, "[SURVIVAL]") end },
    { name = "RapidFire", matches = rapid_fire_matches, execute = function(context) return execute_action(context, RAPID_FIRE_ACTION, "[SURVIVAL]") end },
	    { name = "Readiness", matches = readiness_matches, execute = function(context) return execute_action(context, READINESS_ACTION, "[SURVIVAL]") end },
	    { name = "ExplosiveTrap", matches = explosive_trap_matches, execute = function(context) return execute_action(context, EXPLOSIVE_TRAP_ACTION, "[SURVIVAL]") end },
    { name = "KillCommand", matches = kill_command_matches, execute = function(context) return execute_action(context, KILL_COMMAND_ACTION, "[SURVIVAL]") end },	    { name = "FeignDeath", matches = feign_death_matches, execute = function(context) return execute_action(context, FEIGN_DEATH_ACTION, "[SURVIVAL]") end },
	    { name = "Misdirection", matches = misdirection_matches, execute = misdirection_execute },		    { name = "ConcussiveShot", matches = concussive_shot_matches, execute = function(context) return execute_action(context, CONCUSSIVE_SHOT_ACTION, "[SURVIVAL]") end },
		    { name = "ScorpidSting", matches = scorpid_sting_matches, execute = function(context) return execute_action(context, SCORPID_STING_ACTION, "[SURVIVAL]") end },
		    { name = "Volley", matches = volley_matches, execute = function(context) return execute_action(context, VOLLEY_ACTION, "[SURVIVAL]") end },
		    { name = "RaptorStrike", matches = raptor_strike_matches, execute = function(context) return execute_action(context, RAPTOR_STRIKE_ACTION, "[SURVIVAL]") end },
		    { name = "WingClip", matches = wing_clip_matches, execute = function(context) return execute_action(context, WING_CLIP_ACTION, "[SURVIVAL]") end },
		    { name = "LevelingArcaneShot", matches = leveling_arcane_shot_matches, execute = function(context) if execute_action(context, ARCANE_SHOT_ACTION, "[SURVIVAL]") then record_manual_shot() return true end return false end },
    { name = "LevelingSting", matches = leveling_sting_matches, execute = function(context) return execute_action(context, SERPENT_STING_ACTION, "[SURVIVAL]") end },
    { name = "MultiShot", matches = multi_shot_matches, execute = function(context) if execute_action(context, MULTI_SHOT_ACTION, "[SURVIVAL]") then record_manual_shot() return true end return false end },
    { name = "SteadyShot", matches = steady_shot_matches, execute = function(context) if execute_action(context, STEADY_SHOT_ACTION, "[SURVIVAL]") then record_manual_shot() return true end return false end },
    { name = "ArcaneShot", matches = arcane_shot_matches, execute = function(context) if execute_action(context, ARCANE_SHOT_ACTION, "[SURVIVAL]") then record_manual_shot() return true end return false end },
    { name = "ViperSting", matches = viper_sting_matches, execute = function(context) return execute_action(context, VIPER_STING_ACTION, "[SURVIVAL]") end },
    { name = "SerpentSting", matches = serpent_sting_matches, execute = function(context) return execute_action(context, SERPENT_STING_ACTION, "[SURVIVAL]") end },
}

NS.rotation_registry:register("survival", strategies, { get_state = build_state })
NS.log("Hunter survival rotation registered (Tier A)")
return strategies
