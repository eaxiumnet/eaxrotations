-- leveling_vanilla.lua — Hunter Leveling rotation for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  adaptive leveling rotation (pet, auto shot, arcane shot, serpent sting).
-- WHEN:  any combat while leveling, when NS.is_vanilla() is true.
-- WHY:   handles sub-60 content and pet survival.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.HunterSpells or {}
local leveling = require("shared/leveling_sylvanas")

local ASPECT_HAWK_BUFF = { 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
local SERPENT_STING_IDS = { 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local HUNTERS_MARK_IDS = { 14325, 14324, 14323, 1130 }

local context_allowed = leveling.create_context_guard()
local leveling_state = {}
local _last_aspect_hawk_cast = 0  -- Throttle: WoW API buff detection delay

local function safe_buff_up(unit, ids)
    if not unit or not NS.buff_up then return false end
    local ok, result = pcall(NS.buff_up, unit, ids)
    return ok and result or false
end

local function safe_spell_ready(spell, target, opts)
    if not NS.spell_ready then return false end
    local ok, result = pcall(NS.spell_ready, spell, target, opts)
    return ok and result or false
end

local function safe_debuff_remains(unit, ids)
    if not unit or not NS.debuff_remains then return 0 end
    local ok, result = pcall(NS.debuff_remains, unit, ids)
    if ok and type(result) == "number" then return result end
    return 0
end

local function build_state(context)
    if not context then return nil end
    local settings = context.settings or {}
    leveling.build_common_state(context, leveling_state)

    leveling_state.has_aspect_hawk = safe_buff_up(context.me, ASPECT_HAWK_BUFF)
    leveling_state.low_mana = (context.mana_pct or 100) < 15  -- Preserve mana for emergency CC
    leveling_state.serpent_sting_use = settings.leveling_serpent_sting_use ~= false
    leveling_state.hunters_mark_use = settings.leveling_hunters_mark_use ~= false

    leveling_state.serpent_sting_ready = safe_spell_ready(SPELLS.SerpentSting, context.target)
    leveling_state.hunters_mark_ready = safe_spell_ready(SPELLS.HuntersMark, context.target)
    leveling_state.arcane_shot_ready = safe_spell_ready(SPELLS.ArcaneShot, context.target)
    leveling_state.multi_shot_ready = safe_spell_ready(SPELLS.MultiShot, context.target)
    leveling_state.aimed_shot_ready = safe_spell_ready(SPELLS.AimedShot, context.target, { expected_cooldown = 6 })
    leveling_state.mend_pet_ready = safe_spell_ready(SPELLS.MendPet, nil, { skip_range = true })
    leveling_state.call_pet_ready = safe_spell_ready(SPELLS.CallPet, nil, { skip_range = true })
    leveling_state.aspect_hawk_ready = safe_spell_ready(SPELLS.AspectOfTheHawk, nil, { skip_range = true })
    leveling_state.aspect_cheetah_ready = safe_spell_ready(SPELLS.AspectOfTheCheetah, nil, { skip_range = true })
    leveling_state.has_aspect_cheetah = safe_buff_up(context.me, { 5118 })
    leveling_state.concussive_shot_ready = safe_spell_ready(SPELLS.ConcussiveShot, context.target)
    leveling_state.wing_clip_ready = safe_spell_ready(SPELLS.WingClip, context.target)
    leveling_state.raptor_strike_ready = safe_spell_ready(SPELLS.RaptorStrike, context.target)
    leveling_state.mongoose_bite_ready = safe_spell_ready(SPELLS.MongooseBite, context.target)
    leveling_state.rapid_fire_ready = safe_spell_ready(SPELLS.RapidFire, nil, { skip_range = true })
    leveling_state.scare_beast_ready = safe_spell_ready(SPELLS.ScareBeast, context.target)
    leveling_state.freezing_trap_ready = safe_spell_ready(SPELLS.FreezingTrap, context.me, { skip_range = true, expected_cooldown = 30 })
    leveling_state.feign_death_ready = safe_spell_ready(SPELLS.FeignDeath, nil, { skip_range = true })

    if context.pet then
        local ok, pet_hp = pcall(function() return context.pet:get_health_percentage() end)
        leveling_state.pet_hp = ok and pet_hp or 100
    else
        leveling_state.pet_hp = 100
    end

    return leveling_state
end

local function aspect_hawk_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if state.has_aspect_hawk then return false end
    if not state.aspect_hawk_ready then return false end
    -- Throttle: WoW API buff detection lags 1-2 frames — prevent thrashing
    if (NS.time_now() - _last_aspect_hawk_cast) < 3 then return false end
    return true
end

local function aspect_cheetah_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if state.has_aspect_cheetah then return false end
    if state.has_aspect_hawk then return false end
    if not state.aspect_cheetah_ready then return false end
    return true
end

local function hunters_mark_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.hunters_mark_use then return false end
    if state.in_combat then return false end
    local remains = safe_debuff_remains(state.target, HUNTERS_MARK_IDS)
    if remains > 30 then return false end
    return state.hunters_mark_ready
end

local function call_pet_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if context.pet then return false end
    return state.call_pet_ready
end

local function mend_pet_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if not context.pet then return false end
    if (state.pet_hp or 100) > 60 then return false end
    if state.low_mana then return false end
    return state.mend_pet_ready
end

local function concussive_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end
    if (state.enemies or 0) < 2 and (state.hp or 100) > 40 then return false end
    return state.concussive_shot_ready
end

local function wing_clip_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end
    if not state.in_melee then return false end
    if (state.hp or 100) > 50 then return false end
    return state.wing_clip_ready
end
--- Raptor Strike — melee weave attack when target is in melee range
local function raptor_strike_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if not state.in_melee then return false end
    if state.low_mana then return false end
    return state.raptor_strike_ready
end

--- Mongoose Bite — instant melee attack (proc-based, only when available)
local function mongoose_bite_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if not state.in_melee then return false end
    return state.mongoose_bite_ready
end



local function scare_beast_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if (state.enemies or 0) < 2 then return false end
    return state.scare_beast_ready
end

local function freezing_trap_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if (state.enemies or 0) < 2 then return false end
    return state.freezing_trap_ready
end

local function rapid_fire_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    return state.rapid_fire_ready
end

local function aimed_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if state.low_mana then return false end
    if state.is_moving then return false end
    if not state.aimed_shot_ready then return false end
    return true
end

local function serpent_sting_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.serpent_sting_use then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end
    local remains = safe_debuff_remains(state.target, SERPENT_STING_IDS)
    if remains >= 4 then return false end
    return state.serpent_sting_ready
end

local function arcane_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end
    return state.arcane_shot_ready
end

local function multi_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end
    if (state.enemies or 0) < 2 then return false end
    return state.multi_shot_ready
end

local function feign_death_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if (state.hp or 100) > 30 then return false end
    return state.feign_death_ready  -- Emergency: no mana gate
end

local strategies = {
    { name = "AspectHawk", matches = aspect_hawk_matches,
      execute = function()
          local result = NS.try_cast and NS.try_cast(SPELLS.AspectOfTheHawk, NS.PLAYER_UNIT, "[LEVELING] Aspect of the Hawk") or false
          if result then _last_aspect_hawk_cast = NS.time_now() end
          return result
      end },

    { name = "AspectCheetah", matches = aspect_cheetah_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.AspectOfTheCheetah, NS.PLAYER_UNIT, "[LEVELING] Aspect of the Cheetah") or false end },
    { name = "CallPet", matches = call_pet_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.CallPet, NS.PLAYER_UNIT, "[LEVELING] Call Pet") or false end },
    { name = "HuntersMark", matches = hunters_mark_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.HuntersMark, context.target, "[LEVELING] Hunter's Mark") or false end },
    { name = "RapidFire", matches = rapid_fire_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.RapidFire, NS.PLAYER_UNIT, "[LEVELING] Rapid Fire") or false end },
    { name = "AimedShot", matches = aimed_shot_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.AimedShot, context.target, "[LEVELING] Aimed Shot") or false end },
    { name = "MendPet", matches = mend_pet_matches,
    -- Melee weave: Raptor Strike + Mongoose Bite (when target is in melee range)
    { name = "MongooseBite", matches = mongoose_bite_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.MongooseBite, context.target, "[LEVELING] Mongoose Bite") or false end },
    { name = "RaptorStrike", matches = raptor_strike_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.RaptorStrike, context.target, "[LEVELING] Raptor Strike") or false end },

      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.MendPet, context.pet, "[LEVELING] Mend Pet") or false end },
    { name = "ConcussiveShot", matches = concussive_shot_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.ConcussiveShot, context.target, "[LEVELING] Concussive Shot") or false end },
    { name = "WingClip", matches = wing_clip_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.WingClip, context.target, "[LEVELING] Wing Clip") or false end },
    { name = "ScareBeast", matches = scare_beast_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.ScareBeast, context.target, "[LEVELING] Scare Beast") or false end },
    { name = "FreezingTrap", matches = freezing_trap_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.FreezingTrap, context.me or NS.PLAYER_UNIT, "[LEVELING] Freezing Trap", { skip_range = true, expected_cooldown = 30 }) or false end },
    { name = "FeignDeath", matches = feign_death_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.FeignDeath, NS.PLAYER_UNIT, "[LEVELING] Feign Death") or false end },
    { name = "SerpentSting", matches = serpent_sting_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.SerpentSting, context.target, "[LEVELING] Serpent Sting") or false end },
    { name = "ArcaneShot", matches = arcane_shot_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.ArcaneShot, context.target, "[LEVELING] Arcane Shot") or false end },
    { name = "MultiShot", matches = multi_shot_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.MultiShot, context.target, "[LEVELING] Multi-Shot") or false end },
}

NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
-- [Hunter] Leveling rotation loaded (Classic)
return strategies
