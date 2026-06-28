-- survival_sylvanas.lua -- Hunter Survival rotation for TBC Anniversary (2.5.5).
-- WHAT:  melee-weave DPS spec (Raptor Strike, Wing Clip, traps, Readiness resets).
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors wowsims APL: KC > Multi-Shot > Steady Shot > Raptor Strike melee weave.
-- SAFETY: all state fields nil-guarded via build_state() defaults; no on_update() allocs.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.HunterSpells or {}
local pet_manager = require("shared/pet_manager_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")

local AUTO_SHOT_BUFFER_MS = 100
local MULTI_SHOT_CAST_MS = 500

local function can_cast_steady()
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.can_cast_steady) == "function" then
        return tracker.can_cast_steady() ~= false
    end
    return true
end

local function can_cast_before_auto(cast_ms)
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

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local HUNTERS_MARK_DEBUFF = { 14325, 14324, 14323, 1130 }
local SERPENT_STING_DEBUFF = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local SCORPID_STING_DEBUFF = { 3043 }
local WING_CLIP_DEBUFF = { 2974 }
local ASPECT_HAWK_BUFF = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
local ASPECT_VIPER_BUFF = { 34074 }
local _last_aspect_hawk_cast = 0  -- Throttle: WoW API buff detection delay (~1-2 frames)

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
    rapid_fire_cd = 0,
    explosive_trap_ready = false,
    immolation_trap_ready = false,
    mongoose_bite_ready = false,
    kill_command_ready = false,
    multi_shot_ready = false,
    steady_shot_ready = false,
    arcane_shot_ready = false,
    serpent_sting_ready = false,
    call_pet_ready = false,
    revive_pet_ready = false,
    feign_death_ready = false,
    freezing_trap_ready = false,
    viper_sting_ready = false,
    wyvern_sting_ready = false,
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
    local is_group = context.is_group or false
    local me = context.me or NS.GetPlayer()
    local target = context.target
    local pet = context.pet or (NS.GetPet and NS.GetPet()) or nil
    local pet_alive = pet and ((NS.unit_alive and NS.unit_alive(pet)) or (pet.is_alive and pet:is_alive()) or false) or false

    sv_state.has_pet = pet ~= nil
    sv_state.pet_alive = pet_alive == true
    sv_state.pet_dead = context.pet_dead == true or (pet ~= nil and not sv_state.pet_alive)
    sv_state.pet_hp_pct = sv_state.pet_alive and pet.get_health_percentage and pet:get_health_percentage() or 100
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(14325, 3.0) or false
    if not skip_aura then
        sv_state.has_hunters_mark = target and NS.debuff_up(target, HUNTERS_MARK_DEBUFF) or false
        sv_state.has_serpent_sting = target and NS.debuff_up(target, SERPENT_STING_DEBUFF) or false
        sv_state.has_scorpid_sting = target and NS.debuff_up(target, SCORPID_STING_DEBUFF) or false
        sv_state.wing_clip_active = target and NS.debuff_up(target, WING_CLIP_DEBUFF) or false
        sv_state.has_aspect_hawk = me and NS.buff_up(me, ASPECT_HAWK_BUFF) or false
        sv_state.has_aspect_viper = me and NS.buff_up(me, ASPECT_VIPER_BUFF) or false
    end
    sv_state.mend_pet_ready = me and NS.spell_ready(SPELLS.MendPet, me, { skip_range = true }) or false
    sv_state.hunters_mark_ready = target and NS.spell_ready(SPELLS.HuntersMark, target) or false
    sv_state.rapid_fire_ready = me and NS.spell_ready(SPELLS.RapidFire, me, { skip_range = true, expected_cooldown = 300 }) or false
    sv_state.rapid_fire_cd = NS.cooldown_remains and NS.cooldown_remains(SPELLS.RapidFire) or 0
    sv_state.explosive_trap_ready = me and NS.spell_ready(SPELLS.ExplosiveTrap, me, { skip_range = true, expected_cooldown = 30 }) or false
    sv_state.immolation_trap_ready = me and NS.spell_ready(SPELLS.ImmolationTrap, me, { skip_range = true, expected_cooldown = 30 }) or false
    sv_state.mongoose_bite_ready = target and NS.spell_ready(SPELLS.MongooseBite, target) or false
    sv_state.kill_command_ready = target and NS.spell_ready(SPELLS.KillCommand, target, { expected_cooldown = 5 }) or false
    sv_state.multi_shot_ready = target and NS.spell_ready(SPELLS.MultiShot, target, { expected_cooldown = 10 }) or false
    sv_state.steady_shot_ready = target and NS.spell_ready(SPELLS.SteadyShot, target) or false
    sv_state.arcane_shot_ready = target and NS.spell_ready(SPELLS.ArcaneShot, target, { expected_cooldown = 6 }) or false
    sv_state.serpent_sting_ready = target and NS.spell_ready(SPELLS.SerpentSting, target) or false
    sv_state.call_pet_ready = me and NS.spell_ready(SPELLS.CallPet, me, { skip_range = true }) or false
    sv_state.revive_pet_ready = me and NS.spell_ready(SPELLS.RevivePet, me, { skip_range = true }) or false
    sv_state.feign_death_ready = me and NS.spell_ready(SPELLS.FeignDeath, me, { skip_range = true, expected_cooldown = 30 }) or false
    sv_state.freezing_trap_ready = me and NS.spell_ready(SPELLS.FreezingTrap, me, { skip_range = true, expected_cooldown = 30 }) or false
    sv_state.snake_trap_ready = me and NS.spell_ready(SPELLS.SnakeTrap, me, { skip_range = true, expected_cooldown = 30 }) or false
    sv_state.viper_sting_ready = target and NS.spell_ready(SPELLS.ViperSting, target, { expected_cooldown = 8 }) or false
    sv_state.wyvern_sting_ready = target and NS.spell_ready(SPELLS.WyvernSting, target) or false
    sv_state.scorpid_sting_ready = target and NS.spell_ready(SPELLS.ScorpidSting, target) or false
    sv_state.raptor_strike_ready = target and NS.spell_ready(SPELLS.RaptorStrike, target) or false
    sv_state.wing_clip_ready = target and NS.spell_ready(SPELLS.WingClip, target) or false
    sv_state.volley_ready = target and NS.spell_ready(SPELLS.Volley, target) or false
    sv_state.readiness_ready = me and NS.spell_ready(SPELLS.Readiness, me, { skip_range = true, expected_cooldown = 300 }) or false
    sv_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    sv_state.in_combat = context.in_combat or false
    sv_state.enemy_count = context.enemy_count or context.enemies_count or 1
    sv_state.pre_steady_leveling = ((context.player_level or 70) < 62) or (context.is_leveling == true and not sv_state.steady_shot_ready)
    sv_state.distance_sq = context.distance_sq or (context.target_range and context.target_range * context.target_range) or (context.distance and context.distance * context.distance) or 10000

    return sv_state
end

local function cooldowns_enabled(context)
    return not context.settings or context.settings.use_cooldowns ~= false
end

-- ============================================================================
-- Match functions
-- ============================================================================
local function mend_pet_matches(context, s)
    if not s.pet_alive then return false end
    if (s.pet_hp_pct or 100) > 45 then return false end
    if not s.mend_pet_ready then return false end
    return true
end

local function hunters_mark_matches(context, s)
    if s.has_hunters_mark then return false end
    if not s.hunters_mark_ready then return false end
    return true
end

local function rapid_fire_matches(context, s)
    if not cooldowns_enabled(context) then return false end
    if not s.in_combat then return false end
    if not s.rapid_fire_ready then return false end
    return true
end

local function explosive_trap_matches(context, s)
    if (s.enemy_count or 0) < 3 then return false end
    if not s.explosive_trap_ready then return false end
    -- TTD gate: don't waste trap CD on a dying target
    if context.ttd_known and context.ttd < 8 then return false end
    return true
end

-- Immolation Trap: AoE fire trap for 2-3 enemies
local function immolation_trap_matches(context, s)
    if not s.in_combat then return false end
    if (s.enemy_count or 0) < 2 then return false end
    if not s.immolation_trap_ready then return false end
    -- TTD gate: don't waste trap CD on a dying target
    if context.ttd_known and context.ttd < 8 then return false end
    return true
end

local function kill_command_matches(context, s)
    if not s.in_combat then return false end
    if not s.pet_alive then return false end
    if not s.kill_command_ready then return false end
    return true
end

local function multi_shot_matches(context, s)
    if not s.multi_shot_ready then return false end
    if context.has_breakable_cc_nearby then return false end
    if (s.mana_pct or 100) < 15 then return false end
    if not can_cast_before_auto(MULTI_SHOT_CAST_MS) then return false end
    return true
end

local function steady_shot_matches(context, s)
    if not s.steady_shot_ready then return false end
    if not can_cast_steady() then return false end
    return true
end

local function arcane_shot_matches(context, s)
    if not s.arcane_shot_ready then return false end
    if (s.mana_pct or 100) < 10 then return false end
    return true
end

local function serpent_sting_matches(context, s)
    if s.has_serpent_sting then return false end
    if not s.serpent_sting_ready then return false end
    -- TTD gate: Serpent Sting worth applying only if target lives long enough for DoT value
    if context.ttd_known and context.ttd < 6 then return false end
    return true
end

local function aspect_hawk_matches(context, s)
    if s.has_aspect_hawk then return false end
    -- Throttle: prevent thrashing due to WoW API buff detection delay
    if (NS.time_now() - _last_aspect_hawk_cast) < 3 then return false end
    return true
end

local function aspect_viper_matches(context, s)
    if s.has_aspect_viper then return false end
    if (s.mana_pct or 100) > 20 then return false end
    return true
end

local function call_pet_matches(context, s)
    if s.has_pet then return false end
    if s.in_combat then return false end
    if not s.call_pet_ready then return false end
    return true
end

local function revive_pet_matches(context, s)
    if s.has_pet and not s.pet_dead then return false end
    if s.in_combat then return false end
    if s.call_pet_ready and not s.pet_dead then return false end
    if not s.revive_pet_ready then return false end
    return true
end

local function feign_death_matches(context, s)
    if not s.in_combat then return false end
    if not s.feign_death_ready then return false end
    return true
end

local function freezing_trap_matches(context, s)
    if s.in_combat then return false end
    if not s.freezing_trap_ready then return false end
    return true
end

local function snake_trap_matches(context, s)
    if not s.snake_trap_ready then return false end
    if context.settings and context.settings.use_snake_trap == false then return false end
    if not s.in_combat then return false end
    if (s.enemy_count or 0) < 2 then return false end
    return true
end

local function viper_sting_matches(context, s)
    if not s.viper_sting_ready then return false end
    return true
end

-- Wyvern Sting: CC + DoT; suppress if target already has a DoT (breaks sleep)
local function wyvern_sting_matches(context, s)
    if not (context.is_pvp or context.is_group) then return false end
    if NS.DRTracker and NS.DRTracker.is_dr_immune and context.target and NS.DRTracker.is_dr_immune(context.target, "incapacitate") then return false end
    if not s.wyvern_sting_ready then return false end
    if s.has_serpent_sting then return false end
    if s.has_scorpid_sting then return false end
    return true
end

local function readiness_matches(context, s)
    if not cooldowns_enabled(context) then return false end
    if context.settings and context.settings.use_readiness == false then return false end
    if not s.in_combat then return false end
    if not s.readiness_ready then return false end
    -- Use after Rapid Fire has been used (on CD with >= 60 s remaining) to reset it for 2nd burst window
    if (s.rapid_fire_cd or 0) < 60 then return false end
    return true
end

local function leveling_arcane_shot_matches(context, s)
    if not s.pre_steady_leveling then return false end
    if not s.arcane_shot_ready then return false end
    return true
end

local function leveling_sting_matches(context, s)
    if not s.pre_steady_leveling then return false end
    if s.has_serpent_sting then return false end
    if (s.mana_pct or 100) < 25 then return false end
    if not s.serpent_sting_ready then return false end
    return true
end

-- Concussive Shot: kiting/slow utility (15yd max range)
local function concussive_shot_matches(context, s)
    if not context.has_valid_enemy_target then return false end
    local target = context.target
    if not target then return false end
    -- Squared distance: 15yd = 225
    local dsq = s.distance_sq or (context.distance and context.distance * context.distance) or 10000
    if dsq > 225 then return false end
    return true
end

-- Misdirection: redirect threat to pet
local function misdirection_matches(context, s)
    if not s.in_combat then return false end
    if not s.pet_alive then return false end
    return NS.spell_ready(SPELLS.Misdirection, context.me or NS.PLAYER_UNIT, { skip_range = true, expected_cooldown = 120 })
end

local function misdirection_execute(context, s)
    local pet = context.pet or (NS.GetPet and NS.GetPet()) or nil
    if not pet then return false end
    return NS.try_cast(SPELLS.Misdirection, pet, "[SURVIVAL] Misdirection")
end

-- Scorpid Sting: debuff reducing target's AP; refresh only when expiring
local function scorpid_sting_matches(context, s)
    if not s.in_combat then return false end
    if not s.scorpid_sting_ready then return false end
    -- TTD gate: Scorpid Sting worth applying only if target lives long enough
    if context.ttd_known and context.ttd < 10 then return false end
    if s.has_scorpid_sting then
        -- Only refresh when about to expire (within 2s)
        local target = context.target
        if target then
            for _, id in ipairs(SCORPID_STING_DEBUFF) do
                if NS.debuff_up and NS.debuff_up(target, id) then
                    local remains = NS.debuff_remains and NS.debuff_remains(target, id) or 999
                    if remains > 2 then return false end
                end
            end
        end
    end
    return true
end

-- Raptor Strike: melee weaving when target in melee range (5yd)
local function raptor_strike_matches(context, s)
    if not s.in_combat then return false end
    local target = context.target
    if not target then return false end
    -- Squared distance: 5yd = 25
    local dsq = s.distance_sq or (context.distance and context.distance * context.distance) or 10000
    if dsq > 25 then return false end
    if not s.raptor_strike_ready then return false end
    -- Don't clip auto-shot
    if not can_cast_before_auto(500) then return false end
    return true
end

-- Wing Clip: melee slow to keep enemies in range (5yd)
local function wing_clip_matches(context, s)
    if not s.in_combat then return false end
    if s.wing_clip_active then return false end
    local target = context.target
    if not target then return false end
    -- Squared distance: 5yd = 25
    local dsq = s.distance_sq or (context.distance and context.distance * context.distance) or 10000
    if dsq > 25 then return false end
    if not s.wing_clip_ready then return false end
    -- Don't clip auto-shot
    if not can_cast_before_auto(500) then return false end
    return true
end

-- Mongoose Bite: melee-range counterattack after dodge
local function mongoose_bite_matches(context, s)
    if not s.in_combat then return false end
    local target = context.target
    if not target then return false end
    -- Squared distance: 5yd = 25
    local dsq = s.distance_sq or (context.distance and context.distance * context.distance) or 10000
    if dsq > 25 then return false end
    if not s.mongoose_bite_ready then return false end
    -- Don't clip auto-shot
    if not can_cast_before_auto(500) then return false end
    return true
end

-- Volley: AoE channeled attack for multi-target
local function volley_matches(context, s)
    if context.is_channeling then return false end
    if not s.in_combat then return false end
    if (s.enemy_count or 0) < 4 then return false end
    if context.is_moving then return false end
    if not s.volley_ready then return false end
    return true
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    -- Auto Health Potion — gate on context.has_health_potion (inventory_helper)
    { name = "HealthPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end },
    -- Auto Mana Potion — gate on context.has_mana_potion (inventory_helper)
    { name = "ManaPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_mana_potion then return false end
          if (context.mana_pct or 100) > 25 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
    -- Pet State: set defensive when pet HP is critically low
    { name = "PetDefensive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not state.in_combat then return false end
          if (state.pet_hp_pct or 100) > 40 then return false end
          return true
      end,
      execute = function() return pet_manager.set_defensive() end },
    -- Pet State: set passive when player HP critically low (survival mode)
    { name = "PetPassive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not state.in_combat then return false end
          if (context.hp or 100) > 25 then return false end
          return true
      end,
      execute = function() return pet_manager.set_passive() end },
    -- Pet State: set aggressive during combat when pet is healthy
    { name = "PetAggressive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not state.in_combat then return false end
          if (state.pet_hp_pct or 100) < 50 then return false end
          return true
      end,
      execute = function() return pet_manager.set_aggressive() end },
    { name = "MendPet", matches = mend_pet_matches, execute = function(context) return NS.try_cast(SPELLS.MendPet, context.pet or (NS.GetPet and NS.GetPet()) or context.me, "[SURVIVAL] Mend Pet", { skip_range = true }) end },
    { name = "CallPet", matches = call_pet_matches, execute = function(context) return NS.try_cast(SPELLS.CallPet, context.me, "[SURVIVAL] Call Pet", { skip_range = true }) end },
    { name = "RevivePet", matches = revive_pet_matches, execute = function(context) return NS.try_cast(SPELLS.RevivePet, context.me, "[SURVIVAL] Revive Pet", { skip_range = true }) end },
    { name = "AspectOfTheHawk", matches = aspect_hawk_matches, execute = function(context) local r = NS.try_cast(SPELLS.AspectOfTheHawk, context.me, "[SURVIVAL] Aspect of the Hawk", { skip_range = true }); if r then _last_aspect_hawk_cast = NS.time_now() end; return r end },
    { name = "AspectOfTheViper", matches = aspect_viper_matches, execute = function(context) return NS.try_cast(SPELLS.AspectOfTheViper, context.me, "[SURVIVAL] Aspect of the Viper", { skip_range = true }) end },
    { name = "FreezingTrap", matches = freezing_trap_matches, execute = function(context) return NS.try_cast(SPELLS.FreezingTrap, context.me, "[SURVIVAL] Freezing Trap", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "WyvernSting", matches = wyvern_sting_matches, execute = function(context) return NS.try_cast(SPELLS.WyvernSting, context.target, "[SURVIVAL] Wyvern Sting") end },
    { name = "HuntersMark", matches = hunters_mark_matches, execute = function(context) return NS.try_cast(SPELLS.HuntersMark, context.target, "[SURVIVAL] Hunter's Mark") end },
    { name = "RapidFire", matches = rapid_fire_matches, execute = function(context) return NS.try_cast(SPELLS.RapidFire, context.me, "[SURVIVAL] Rapid Fire", { skip_range = true, expected_cooldown = 300 }) end },
    { name = "Readiness", matches = readiness_matches, execute = function(context) return NS.try_cast(SPELLS.Readiness, context.me, "[SURVIVAL] Readiness", { skip_range = true, expected_cooldown = 300 }) end },
    { name = "ExplosiveTrap", matches = explosive_trap_matches, execute = function(context) return NS.try_cast(SPELLS.ExplosiveTrap, context.me, "[SURVIVAL] Explosive Trap", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "SnakeTrap", matches = snake_trap_matches, execute = function(context) return NS.try_cast(SPELLS.SnakeTrap, context.me, "[SURVIVAL] Snake Trap", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "ImmolationTrap", matches = immolation_trap_matches, execute = function(context) return NS.try_cast(SPELLS.ImmolationTrap, context.me, "[SURVIVAL] Immolation Trap", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "KillCommand", matches = kill_command_matches, execute = function(context) return NS.try_cast(SPELLS.KillCommand, context.target, "[SURVIVAL] Kill Command", { expected_cooldown = 5, skip_gcd = true }) end },
    { name = "FeignDeath", matches = feign_death_matches, execute = function(context) return NS.try_cast(SPELLS.FeignDeath, context.me, "[SURVIVAL] Feign Death", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "Misdirection", matches = misdirection_matches, execute = misdirection_execute },
    { name = "ConcussiveShot", matches = concussive_shot_matches, execute = function(context) return NS.try_cast(SPELLS.ConcussiveShot, context.target, "[SURVIVAL] Concussive Shot") end },
    { name = "ScorpidSting", matches = scorpid_sting_matches, execute = function(context) return NS.try_cast(SPELLS.ScorpidSting, context.target, "[SURVIVAL] Scorpid Sting") end },
    { name = "Volley", matches = volley_matches, execute = function(context) local t = context.target; local pos = t and NS.get_aoe_cast_position(NS.get_spell_id(SPELLS.Volley), t, 8, 35); if pos then return NS.try_cast_position(SPELLS.Volley, pos, t, "[SURVIVAL] Volley") end; return NS.try_cast(SPELLS.Volley, t, "[SURVIVAL] Volley") end },
    { name = "RaptorStrike", matches = raptor_strike_matches, execute = function(context) return NS.try_cast(SPELLS.RaptorStrike, context.target, "[SURVIVAL] Raptor Strike") end },
    { name = "MongooseBite", matches = mongoose_bite_matches, execute = function(context) return NS.try_cast(SPELLS.MongooseBite, context.target, "[SURVIVAL] Mongoose Bite") end },
    { name = "WingClip", matches = wing_clip_matches, execute = function(context) return NS.try_cast(SPELLS.WingClip, context.target, "[SURVIVAL] Wing Clip") end },
    { name = "LevelingArcaneShot", matches = leveling_arcane_shot_matches, execute = function(context) if NS.try_cast(SPELLS.ArcaneShot, context.target, "[SURVIVAL] Arcane Shot (leveling)", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "LevelingSting", matches = leveling_sting_matches, execute = function(context) return NS.try_cast(SPELLS.SerpentSting, context.target, "[SURVIVAL] Serpent Sting (leveling)") end },
    { name = "MultiShot", matches = multi_shot_matches, execute = function(context) if NS.try_cast(SPELLS.MultiShot, context.target, "[SURVIVAL] Multi-Shot", { expected_cooldown = 10 }) then record_manual_shot() return true end return false end },
    { name = "SteadyShot", matches = steady_shot_matches, execute = function(context) if NS.try_cast(SPELLS.SteadyShot, context.target, "[SURVIVAL] Steady Shot") then record_manual_shot() return true end return false end },
    { name = "ArcaneShot", matches = arcane_shot_matches, execute = function(context) if NS.try_cast(SPELLS.ArcaneShot, context.target, "[SURVIVAL] Arcane Shot", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "ViperSting", matches = viper_sting_matches, execute = function(context) return NS.try_cast(SPELLS.ViperSting, context.target, "[SURVIVAL] Viper Sting", { expected_cooldown = 8 }) end },
    { name = "SerpentSting", matches = serpent_sting_matches, execute = function(context) return NS.try_cast(SPELLS.SerpentSting, context.target, "[SURVIVAL] Serpent Sting") end },
}

NS.rotation_registry:register("survival", strategies, { get_state = build_state })
NS.log("Hunter survival rotation registered")
return strategies
