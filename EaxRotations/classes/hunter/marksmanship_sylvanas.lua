-- Hunter Marksmanship priority list.


local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.HunterSpells or {}

local AUTO_SHOT_BUFFER_MS = 100
local MULTI_SHOT_CAST_MS = 500
local AIMED_SHOT_CAST_MS = 2500

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
local ASPECT_HAWK_BUFF = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
local ASPECT_VIPER_BUFF = { 34074 }

local MISDIRECTION_ID = 34477
local WING_CLIP_DEBUFF = { 2974 }
local RAPTOR_STRIKE_IDS = { 27014, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 2973 }
local CONCUSSIVE_SHOT_IDS = { 5116 }
local VOLLEY_IDS = { 27022, 14295, 14294, 1510 }

local SERPENT_STING_REFRESH_SEC = 1.5

-- ============================================================================
-- State builder
-- ============================================================================
local mm_state = {
    has_pet = false,
    pet_alive = false,
    pet_dead = false,
    pre_steady_leveling = false,
    pet_hp_pct = 100,
    has_hunters_mark = false,
    has_serpent_sting = false,
    serpent_sting_remains = 0,
    has_aspect_hawk = false,
    has_aspect_viper = false,
    mend_pet_ready = false,
    hunters_mark_ready = false,
    rapid_fire_ready = false,
    aimed_shot_prepull_ready = false,
    aimed_shot_ready = false,
    silencing_shot_ready = false,
    target_is_casting = false,
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
    readiness_ready = false,
    raptor_strike_ready = false,
    concussive_shot_ready = false,
    volley_ready = false,
    explosive_trap_ready = false,
    wing_clip_active = false,
    use_misdirection = false,
    mana_pct = 100,
    in_combat = false,
    enemy_count = 1,
    is_ooc = false,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target
    local pet = context.pet or (NS.GetPet and NS.GetPet()) or nil
    local pet_alive = pet and ((NS.unit_alive and NS.unit_alive(pet)) or (pet.is_alive and pet:is_alive()) or false) or false

    mm_state.has_pet = pet ~= nil
    mm_state.pet_alive = pet_alive == true
    mm_state.pet_dead = context.pet_dead == true or (pet ~= nil and not mm_state.pet_alive)
    mm_state.pet_hp_pct = mm_state.pet_alive and pet.get_health_percentage and pet:get_health_percentage() or 100
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(14325, 3.0) or false
    if not skip_aura then
        mm_state.has_hunters_mark = target and NS.debuff_up(target, HUNTERS_MARK_DEBUFF) or false
        mm_state.has_serpent_sting = target and NS.debuff_up(target, SERPENT_STING_DEBUFF) or false
        mm_state.serpent_sting_remains = target and NS.debuff_remains(target, SERPENT_STING_DEBUFF) or 0
        mm_state.has_aspect_hawk = me and NS.buff_up(me, ASPECT_HAWK_BUFF) or false
        mm_state.has_aspect_viper = me and NS.buff_up(me, ASPECT_VIPER_BUFF) or false
    end
    mm_state.mend_pet_ready = me and NS.spell_ready(SPELLS.MendPet, me, { skip_range = true }) or false
    mm_state.hunters_mark_ready = target and NS.spell_ready(SPELLS.HuntersMark, target) or false
    mm_state.rapid_fire_ready = me and NS.spell_ready(SPELLS.RapidFire, me, { skip_range = true, expected_cooldown = 300 }) or false
    mm_state.aimed_shot_prepull_ready = target and NS.spell_ready(SPELLS.AimedShot, target, { expected_cooldown = 6 }) or false
    mm_state.aimed_shot_ready = target and NS.spell_ready(SPELLS.AimedShot, target, { expected_cooldown = 6 }) or false
    mm_state.silencing_shot_ready = target and NS.spell_ready(SPELLS.SilencingShot, target, { expected_cooldown = 20 }) or false
    mm_state.target_is_casting = target and ((target.is_casting and target:is_casting()) or false)
    mm_state.kill_command_ready = target and NS.spell_ready(SPELLS.KillCommand, target, { expected_cooldown = 5 }) or false
    mm_state.multi_shot_ready = target and NS.spell_ready(SPELLS.MultiShot, target, { expected_cooldown = 10 }) or false
    mm_state.steady_shot_ready = target and NS.spell_ready(SPELLS.SteadyShot, target) or false
    mm_state.arcane_shot_ready = target and NS.spell_ready(SPELLS.ArcaneShot, target, { expected_cooldown = 6 }) or false
    mm_state.serpent_sting_ready = target and NS.spell_ready(SPELLS.SerpentSting, target) or false
    mm_state.call_pet_ready = me and NS.spell_ready(SPELLS.CallPet, me, { skip_range = true }) or false
    mm_state.revive_pet_ready = me and NS.spell_ready(SPELLS.RevivePet, me, { skip_range = true }) or false
    mm_state.feign_death_ready = me and NS.spell_ready(SPELLS.FeignDeath, me, { skip_range = true, expected_cooldown = 30 }) or false
    mm_state.freezing_trap_ready = me and NS.spell_ready(SPELLS.FreezingTrap, me, { skip_range = true, expected_cooldown = 30 }) or false
    mm_state.viper_sting_ready = target and NS.spell_ready(SPELLS.ViperSting, target, { expected_cooldown = 8 }) or false
    mm_state.readiness_ready = me and NS.spell_ready(SPELLS.Readiness, me, { skip_range = true, expected_cooldown = 300 }) or false
    mm_state.raptor_strike_ready = target and NS.spell_ready(RAPTOR_STRIKE_IDS, target) or false
    mm_state.concussive_shot_ready = target and NS.spell_ready(CONCUSSIVE_SHOT_IDS, target) or false
    mm_state.volley_ready = target and NS.spell_ready(VOLLEY_IDS, target) or false
    mm_state.explosive_trap_ready = me and NS.spell_ready(SPELLS.ExplosiveTrap, me, { skip_range = true, expected_cooldown = 30 }) or false
    mm_state.wing_clip_active = target and NS.debuff_up(target, WING_CLIP_DEBUFF) or false
    mm_state.use_misdirection = context.settings and context.settings.use_misdirection == true
    mm_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    mm_state.in_combat = context.in_combat or false
    mm_state.enemy_count = context.enemy_count or context.enemies_count or 1
    mm_state.is_ooc = not mm_state.in_combat
    mm_state.pre_steady_leveling = ((context.player_level or 70) < 62) or (context.is_leveling == true and not mm_state.steady_shot_ready)

    return mm_state
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

local function aimed_shot_prepull_matches(context, s)
    if not s.is_ooc then return false end
    if not s.aimed_shot_prepull_ready then return false end
    if not can_cast_before_auto(AIMED_SHOT_CAST_MS) then return false end
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
    if (s.mana_pct or 100) < 20 then return false end
    return true
end

local function serpent_sting_matches(context, s)
    if s.has_serpent_sting and (s.serpent_sting_remains or 0) > SERPENT_STING_REFRESH_SEC then return false end
    if not s.serpent_sting_ready then return false end
    return true
end

local function aspect_hawk_matches(context, s)
    if s.has_aspect_hawk then return false end
    -- Only switch from Viper to Hawk when mana has recovered above viper_end threshold
    if s.has_aspect_viper then
        local viper_end = (context.settings and context.settings.mana_viper_end) or 30
        if (s.mana_pct or 100) <= viper_end then return false end
    end
    return true
end

local function aspect_viper_matches(context, s)
    if s.has_aspect_viper then return false end
    if (s.mana_pct or 100) > 30 then return false end
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

local function silencing_shot_matches(context, s)
    if not s.in_combat then return false end
    if not s.target_is_casting then return false end
    if not s.silencing_shot_ready then return false end
    return true
end

local function in_combat_aimed_shot_matches(context, s)
    if not s.in_combat then return false end
    if not s.aimed_shot_ready then return false end
    if (s.mana_pct or 100) < 20 then return false end
    if not can_cast_before_auto(AIMED_SHOT_CAST_MS) then return false end
    return true
end

local function viper_sting_matches(context, s)
    if not s.viper_sting_ready then return false end
    return true
end

local function bestial_wrath_matches(context, s)
    if not s.in_combat then return false end
    if not s.pet_alive then return false end
    if not s.bestial_wrath_ready then return false end
    return true
end

local function readiness_matches(context, s)
    if not cooldowns_enabled(context) then return false end
    if not s.in_combat then return false end
    if not s.readiness_ready then return false end
    -- Use after Rapid Fire has been used (on CD) to reset it for a 2nd burst window
    if s.bestial_wrath_ready or s.rapid_fire_ready then return false end
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

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "MendPet", matches = mend_pet_matches, execute = function(context) return NS.try_cast(SPELLS.MendPet, context.pet or (NS.GetPet and NS.GetPet()) or context.me, "[MARKSMANSHIP] Mend Pet", { skip_range = true }) end },
    { name = "CallPet", matches = call_pet_matches, execute = function(context) return NS.try_cast(SPELLS.CallPet, context.me, "[MARKSMANSHIP] Call Pet", { skip_range = true }) end },
    { name = "RevivePet", matches = revive_pet_matches, execute = function(context) return NS.try_cast(SPELLS.RevivePet, context.me, "[MARKSMANSHIP] Revive Pet", { skip_range = true }) end },
    { name = "AspectOfTheHawk", matches = aspect_hawk_matches, execute = function(context) return NS.try_cast(SPELLS.AspectOfTheHawk, context.me, "[MARKSMANSHIP] Aspect of the Hawk", { skip_range = true }) end },
    { name = "AspectOfTheViper", matches = aspect_viper_matches, execute = function(context) return NS.try_cast(SPELLS.AspectOfTheViper, context.me, "[MARKSMANSHIP] Aspect of the Viper", { skip_range = true }) end },
    { name = "FreezingTrap", matches = freezing_trap_matches, execute = function(context) return NS.try_cast(SPELLS.FreezingTrap, context.me, "[MARKSMANSHIP] Freezing Trap", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "HuntersMark", matches = hunters_mark_matches, execute = function(context) return NS.try_cast(SPELLS.HuntersMark, context.target, "[MARKSMANSHIP] Hunter's Mark") end },
    { name = "RapidFire", matches = rapid_fire_matches, execute = function(context) return NS.try_cast(SPELLS.RapidFire, context.me, "[MARKSMANSHIP] Rapid Fire", { skip_range = true, expected_cooldown = 300 }) end },
    { name = "BestialWrath", matches = bestial_wrath_matches, execute = function(context) local pet = context.pet or (NS.GetPet and NS.GetPet()) or context.me; return NS.try_cast(SPELLS.BestialWrath, pet, "[MARKSMANSHIP] Bestial Wrath", { skip_range = true, expected_cooldown = 120 }) end },
    { name = "Readiness", matches = readiness_matches, execute = function(context) return NS.try_cast(SPELLS.Readiness, context.me, "[MARKSMANSHIP] Readiness", { skip_range = true, expected_cooldown = 300 }) end },
    { name = "SilencingShot", matches = silencing_shot_matches, execute = function(context) return NS.try_cast(SPELLS.SilencingShot, context.target, "[MARKSMANSHIP] Silencing Shot", { expected_cooldown = 20 }) end },
    { name = "InCombatAimedShot", matches = in_combat_aimed_shot_matches, execute = function(context) if NS.try_cast(SPELLS.AimedShot, context.target, "[MARKSMANSHIP] Aimed Shot", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "AimedShotPrepull", matches = aimed_shot_prepull_matches, execute = function(context) if NS.try_cast(SPELLS.AimedShot, context.target, "[MARKSMANSHIP] Aimed Shot (prepull)", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "KillCommand", matches = kill_command_matches, execute = function(context) return NS.try_cast(SPELLS.KillCommand, context.target, "[MARKSMANSHIP] Kill Command", { expected_cooldown = 5, skip_gcd = true }) end },
    { name = "FeignDeath", matches = feign_death_matches, execute = function(context) return NS.try_cast(SPELLS.FeignDeath, context.me, "[MARKSMANSHIP] Feign Death", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "LevelingArcaneShot", matches = leveling_arcane_shot_matches, execute = function(context) if NS.try_cast(SPELLS.ArcaneShot, context.target, "[MARKSMANSHIP] Arcane Shot (leveling)", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "LevelingSting", matches = leveling_sting_matches, execute = function(context) return NS.try_cast(SPELLS.SerpentSting, context.target, "[MARKSMANSHIP] Serpent Sting (leveling)") end },
    { name = "MultiShot", matches = multi_shot_matches, execute = function(context) if NS.try_cast(SPELLS.MultiShot, context.target, "[MARKSMANSHIP] Multi-Shot", { expected_cooldown = 10 }) then record_manual_shot() return true end return false end },
    { name = "SteadyShot", matches = steady_shot_matches, execute = function(context) if NS.try_cast(SPELLS.SteadyShot, context.target, "[MARKSMANSHIP] Steady Shot") then record_manual_shot() return true end return false end },
    { name = "ArcaneShot", matches = arcane_shot_matches, execute = function(context) if NS.try_cast(SPELLS.ArcaneShot, context.target, "[MARKSMANSHIP] Arcane Shot", { expected_cooldown = 6 }) then record_manual_shot() return true end return false end },
    { name = "ViperSting", matches = viper_sting_matches, execute = function(context) return NS.try_cast(SPELLS.ViperSting, context.target, "[MARKSMANSHIP] Viper Sting", { expected_cooldown = 8 }) end },
    { name = "SerpentSting", matches = serpent_sting_matches, execute = function(context) return NS.try_cast(SPELLS.SerpentSting, context.target, "[MARKSMANSHIP] Serpent Sting") end },
}

NS.rotation_registry:register("marksmanship", strategies, { get_state = build_state })
NS.log("Hunter marksmanship rotation registered (Tier A)")
return strategies
