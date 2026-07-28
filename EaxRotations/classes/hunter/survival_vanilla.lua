-- survival_vanilla.lua — Hunter Survival for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  trap/melee hybrid + Aimed Shot primary (Explosive Trap, Raptor Strike).
-- WHEN:  combat, when NS.is_vanilla() is true.
-- WHY:   Classic Era hunter APL (wowsims classic p1): Aimed > Multi > Serpent; no Steady Shot.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.


local NS = _G.EaxRotations
if not NS then return nil end
local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.HunterSpells or {}
local pet_manager = require("shared/pet_manager_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")

local AUTO_SHOT_BUFFER_MS = 100
local MULTI_SHOT_CAST_MS = 500
local AIMED_SHOT_CAST_MS = 3000

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
local SERPENT_STING_DEBUFF = { 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local SCORPID_STING_DEBUFF = { 3043 }
local WING_CLIP_DEBUFF = { 2974 }
local ASPECT_HAWK_BUFF = { 25296, 14322, 14321, 14320, 14319, 14318, 13165 }

-- ============================================================================
-- State builder
-- ============================================================================
local sv_state = {
    has_pet = false,
    pet_alive = false,
    pet_dead = false,
    pet_hp_pct = 100,
    has_hunters_mark = false,
    has_serpent_sting = false,
    has_aspect_hawk = false,
    mend_pet_ready = false,
    hunters_mark_ready = false,
    rapid_fire_ready = false,
    explosive_trap_ready = false,
    multi_shot_ready = false,
    arcane_shot_ready = false,
    aimed_shot_ready = false,
    serpent_sting_ready = false,
    call_pet_ready = false,
    revive_pet_ready = false,
    feign_death_ready = false,
    freezing_trap_ready = false,
    viper_sting_ready = false,
    scorpid_sting_ready = false,
    raptor_strike_ready = false,
    wing_clip_ready = false,
    volley_ready = false,
    has_scorpid_sting = false,
    wing_clip_active = false,
    mana_pct = 100,
    in_combat = false,
    enemy_count = 1,
}

-- Schema for safe_state: Pattern 14 nil-guard defaults.
local SV_VANILLA_SCHEMA = {
    has_pet = false,  pet_alive = false,  pet_dead = false,
    pet_hp_pct = 100,  has_hunters_mark = false,
    has_serpent_sting = false,  has_aspect_hawk = false,
    mend_pet_ready = false,  hunters_mark_ready = false,
    rapid_fire_ready = false,  explosive_trap_ready = false,
    multi_shot_ready = false,  arcane_shot_ready = false,
    aimed_shot_ready = false,  serpent_sting_ready = false,
    call_pet_ready = false,  revive_pet_ready = false,
    feign_death_ready = false,  freezing_trap_ready = false,
    viper_sting_ready = false,  scorpid_sting_ready = false,
    raptor_strike_ready = false,  wing_clip_ready = false,
    volley_ready = false,  has_scorpid_sting = false,
    wing_clip_active = false,  mana_pct = 100,
    in_combat = false,  enemy_count = 1,
    pre_steady_leveling = false,
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
    sv_state.mend_pet_ready = me and NS.spell_ready(SPELLS.MendPet, me, { skip_range = true }) or false
    sv_state.hunters_mark_ready = target and NS.spell_ready(SPELLS.HuntersMark, target) or false
    sv_state.rapid_fire_ready = me and NS.spell_ready(SPELLS.RapidFire, me, { skip_range = true, expected_cooldown = 300 }) or false
    sv_state.explosive_trap_ready = me and NS.spell_ready(SPELLS.ExplosiveTrap, me, { skip_range = true, expected_cooldown = 30 }) or false
    sv_state.multi_shot_ready = target and NS.spell_ready(SPELLS.MultiShot, target, { expected_cooldown = 10 }) or false
    sv_state.arcane_shot_ready = target and NS.spell_ready(SPELLS.ArcaneShot, target, { expected_cooldown = 6 }) or false
    sv_state.aimed_shot_ready = target and NS.spell_ready(SPELLS.AimedShot, target, { expected_cooldown = 6 }) or false
    sv_state.serpent_sting_ready = target and NS.spell_ready(SPELLS.SerpentSting, target) or false
    sv_state.call_pet_ready = me and NS.spell_ready(SPELLS.CallPet, me, { skip_range = true }) or false
    sv_state.revive_pet_ready = me and NS.spell_ready(SPELLS.RevivePet, me, { skip_range = true }) or false
    sv_state.feign_death_ready = me and NS.spell_ready(SPELLS.FeignDeath, me, { skip_range = true, expected_cooldown = 30 }) or false
    sv_state.freezing_trap_ready = me and NS.spell_ready(SPELLS.FreezingTrap, me, { skip_range = true, expected_cooldown = 30 }) or false
    sv_state.viper_sting_ready = target and NS.spell_ready(SPELLS.ViperSting, target, { expected_cooldown = 8 }) or false
    sv_state.scorpid_sting_ready = target and NS.spell_ready(SPELLS.ScorpidSting, target) or false
    sv_state.raptor_strike_ready = target and NS.spell_ready(SPELLS.RaptorStrike, target) or false
    sv_state.wing_clip_ready = target and NS.spell_ready(SPELLS.WingClip, target) or false
    sv_state.volley_ready = target and NS.spell_ready(SPELLS.Volley, target) or false
    sv_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    sv_state.in_combat = context.in_combat or false
    sv_state.enemy_count = context.enemy_count or context.enemies_count or 1
    -- Classic Era: enable Arcane/Sting ladder when Aimed unlearned or unavailable (default level 60).
    local player_level = context.level or context.player_level or 60
    sv_state.pre_steady_leveling = (player_level < 20)
        or (not sv_state.aimed_shot_ready)
        or (context.is_leveling == true)

    return spec_kit.safe_state(sv_state, SV_VANILLA_SCHEMA)
end

local function cooldowns_enabled(context)
    return spec_kit.setting_bool(context, "use_cooldowns", true)
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
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 300) then return false end
    if not cooldowns_enabled(context) then return false end
    if not s.in_combat then return false end
    if not s.rapid_fire_ready then return false end
    return true
end

local function explosive_trap_matches(context, s)
    if (s.enemy_count or 0) < 3 then return false end
    if not s.explosive_trap_ready then return false end
    return true
end

local function multi_shot_matches(context, s)
    if not s.multi_shot_ready then return false end
    if context.has_breakable_cc_nearby then return false end
    if (s.mana_pct or 100) < 15 then return false end
    if not can_cast_before_auto(MULTI_SHOT_CAST_MS) then return false end
    return true
end

-- Aimed Shot: Classic Era primary cast (wowsims hunter p1.apl)
local function aimed_shot_matches(context, s)
    if not s.in_combat then return false end
    if not s.aimed_shot_ready then return false end
    if (s.mana_pct or 100) < 20 then return false end
    if not can_cast_before_auto(AIMED_SHOT_CAST_MS) then return false end
    return true
end

local function arcane_shot_matches(context, s)
    if not s.arcane_shot_ready then return false end
    if (s.mana_pct or 100) < 10 then return false end
    -- Prefer Aimed when ready
    if s.aimed_shot_ready then return false end
    return true
end

local function serpent_sting_matches(context, s)
    if s.has_serpent_sting then return false end
    if not s.serpent_sting_ready then return false end
    return true
end

local function aspect_hawk_matches(context, s)
    if s.has_aspect_hawk then return false end
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

local function viper_sting_matches(context, s)
    if not s.viper_sting_ready then return false end
    return true
end

local function leveling_arcane_shot_matches(context, s)
    if not s.arcane_shot_ready then return false end
    return true
end

local function leveling_sting_matches(context, s)
    if s.has_serpent_sting then return false end
    if (s.mana_pct or 100) < 25 then return false end
    if not s.serpent_sting_ready then return false end
    return true
end

-- Concussive Shot: kiting/slow utility
local function concussive_shot_matches(context, s)
    if not context.has_valid_enemy_target then return false end
    local target = context.target
    if not target then return false end
    local target_dist = target.get_distance and target:get_distance(context.me) or 20
    if target_dist > 30 then return false end
    return true
end

-- Scorpid Sting: debuff reducing target's chance to hit
local function scorpid_sting_matches(context, s)
    if s.has_scorpid_sting then return false end
    if not s.in_combat then return false end
    if not s.scorpid_sting_ready then return false end
    return true
end

-- Raptor Strike: melee weaving when target in melee range
local function raptor_strike_matches(context, s)
    if not s.in_combat then return false end
    local target = context.target
    if not target then return false end
    local dist = context.distance or context.target_distance or 100
    if dist > 6 then return false end
    if not s.raptor_strike_ready then return false end
    return true
end

-- Wing Clip: melee slow to keep enemies in range
local function wing_clip_matches(context, s)
    if not s.in_combat then return false end
    if s.wing_clip_active then return false end
    local target = context.target
    if not target then return false end
    local dist = context.distance or context.target_distance or 100
    if dist > 6 then return false end
    if not s.wing_clip_ready then return false end
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
    { name = "HealthPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if spec_kit.setting_bool(context, "use_auto_potions", true) == false then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end },
    { name = "ManaPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if spec_kit.setting_bool(context, "use_auto_potions", true) == false then return false end
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
    { name = "AspectOfTheHawk", matches = aspect_hawk_matches, execute = function(context) return NS.try_cast(SPELLS.AspectOfTheHawk, context.me, "[SURVIVAL] Aspect of the Hawk", { skip_range = true }) end },
    { name = "FreezingTrap", matches = freezing_trap_matches, execute = function(context) return NS.try_cast(SPELLS.FreezingTrap, context.me, "[SURVIVAL] Freezing Trap", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "HuntersMark", matches = hunters_mark_matches, execute = function(context) return NS.try_cast(SPELLS.HuntersMark, context.target, "[SURVIVAL] Hunter's Mark") end },
    { name = "RapidFire", matches = rapid_fire_matches, execute = function(context) return NS.try_cast(SPELLS.RapidFire, context.me, "[SURVIVAL] Rapid Fire", { skip_range = true, expected_cooldown = 300 }) end },
    { name = "ExplosiveTrap", matches = explosive_trap_matches, execute = function(context) return NS.try_cast(SPELLS.ExplosiveTrap, context.me, "[SURVIVAL] Explosive Trap", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "FeignDeath", matches = feign_death_matches, execute = function(context) return NS.try_cast(SPELLS.FeignDeath, context.me, "[SURVIVAL] Feign Death", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "ConcussiveShot", matches = concussive_shot_matches, execute = function(context) return NS.try_cast(SPELLS.ConcussiveShot, context.target, "[SURVIVAL] Concussive Shot") end },
    { name = "ScorpidSting", matches = scorpid_sting_matches, execute = function(context) return NS.try_cast(SPELLS.ScorpidSting, context.target, "[SURVIVAL] Scorpid Sting") end },
    { name = "Volley", matches = volley_matches, execute = function(context) return NS.try_cast(SPELLS.Volley, context.target, "[SURVIVAL] Volley") end },
    { name = "RaptorStrike", matches = raptor_strike_matches, execute = function(context) return NS.try_cast(SPELLS.RaptorStrike, context.target, "[SURVIVAL] Raptor Strike") end },
    { name = "WingClip", matches = wing_clip_matches, execute = function(context) return NS.try_cast(SPELLS.WingClip, context.target, "[SURVIVAL] Wing Clip") end },
    { name = "LevelingArcaneShot", matches = leveling_arcane_shot_matches, execute = function(context) if NS.try_cast(SPELLS.ArcaneShot, context.target, "[SURVIVAL] Arcane Shot (leveling)", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "LevelingSting", matches = leveling_sting_matches, execute = function(context) return NS.try_cast(SPELLS.SerpentSting, context.target, "[SURVIVAL] Serpent Sting (leveling)") end },
    { name = "AimedShot", matches = aimed_shot_matches, execute = function(context) if NS.try_cast(SPELLS.AimedShot, context.target, "[SURVIVAL] Aimed Shot", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "MultiShot", matches = multi_shot_matches, execute = function(context) if NS.try_cast(SPELLS.MultiShot, context.target, "[SURVIVAL] Multi-Shot", { expected_cooldown = 10 }) then record_manual_shot() return true end return false end },
    { name = "ArcaneShot", matches = arcane_shot_matches, execute = function(context) if NS.try_cast(SPELLS.ArcaneShot, context.target, "[SURVIVAL] Arcane Shot", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "ViperSting", matches = viper_sting_matches, execute = function(context) return NS.try_cast(SPELLS.ViperSting, context.target, "[SURVIVAL] Viper Sting", { expected_cooldown = 8 }) end },
    { name = "SerpentSting", matches = serpent_sting_matches, execute = function(context) return NS.try_cast(SPELLS.SerpentSting, context.target, "[SURVIVAL] Serpent Sting") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("survival", strategies, { get_state = build_state })
end
-- Hunter survival rotation registered
return strategies
