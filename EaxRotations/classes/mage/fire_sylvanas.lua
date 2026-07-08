-- fire_sylvanas.lua — Mage Fire DPS for TBC Anniversary (2.5.5).
-- WHAT:  fire DPS spec (Scorch 5-stack maintenance, Fireball filler, Combustion burst,
--         AoE tools, mana sustain, defensives).
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors wowsims APL: Scorch (5-stack) > Fireball > Fire Blast (moving).
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no on_update() allocs.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.MageSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")

-- Centralized spell resolver via spec_kit (rank IDs from class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    ArcaneExplosion   = define("ArcaneExplosion",   { 27082, 27080, 10202, 10201, 8439, 8438, 8437, 1449 }, "ArcaneExplosion"),
    BlastWave         = define("BlastWave",         { 33933, 27133, 13021, 13020, 13019, 13018, 11113 }, "BlastWave"),
    Blizzard          = define("Blizzard",          { 27085, 10187, 10186, 10185, 8427, 6141, 10 }, "Blizzard"),
    Combustion        = define("Combustion",        { 11129 }, "Combustion"),
    ConjureManaEmerald= define("ConjureManaEmerald",{ 27101, 10054, 10053, 3552, 759 }, "ConjureManaEmerald"),
    DragonsBreath     = define("DragonsBreath",     { 33043, 33042, 33041, 31661 }, "DragonsBreath"),
    Evocation         = define("Evocation",         { 12051 }, "Evocation"),
    FireBlast         = define("FireBlast",         { 27079, 27078, 10199, 10197, 8413, 8412, 2138, 2137, 2136 }, "FireBlast"),
    Fireball          = define("Fireball",          { 27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133 }, "Fireball"),
    Flamestrike       = define("Flamestrike",       { 27086, 10216, 10215, 8423, 8422, 2121, 2120 }, "Flamestrike"),
    FlamestrikeRank6  = define("FlamestrikeRank6",  { 10216 }, "FlamestrikeRank6"),
    IceBarrier        = define("IceBarrier",        { 33405, 27134, 13033, 13032, 13031, 11426 }, "IceBarrier"),
    ManaShield        = define("ManaShield",        { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }, "ManaShield"),
    Polymorph         = define("Polymorph",         { 12826, 12825, 12824, 118 }, "Polymorph"),
    PresenceOfMind    = define("PresenceOfMind",    { 12043 }, "PresenceOfMind"),
    Pyroblast         = define("Pyroblast",         { 33938, 27132, 18809, 12526, 12525, 12524, 12523, 12522, 12505, 11366 }, "Pyroblast"),
    RemoveCurse       = define("RemoveCurse",       { 475 }, "RemoveCurse"),
    Scorch            = define("Scorch",            { 27074, 27073, 10207, 10206, 10205, 8446, 8445, 8444, 2948 }, "Scorch"),
}

local potion_helper = require("shared/potion_helper_sylvanas")

local SCORCH_DEBUFF = { 22959 }
local CLEARCASTING_BUFF = { 12536 }  -- Clearcasting proc from Arcane Concentration talent

local _planner_ok, planner = pcall(require, "shared/cooldown_planner_sylvanas")
if not _planner_ok or type(planner) ~= "table" then planner = nil end
local BLOODLUST_HEROISM_BUFFS = { 2825, 32182 }

-- Mana Gem item IDs (highest to lowest rank)
local MANA_GEM_ITEM_IDS = { 22044, 8008, 8007, 5513, 5514 }  -- Emerald, Ruby, Citrine, Jade, Agate
local MANA_GEM_CONJURE = { 27101, 10054, 10053, 3552, 759 }  -- Conjure Mana Emerald..Agate

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(item_ids)
    if not NS.is_item_ready then return 0 end
    for i = 1, #item_ids do
        local item_id = item_ids[i]
        if NS.is_item_ready(item_id) then return item_id end
    end
    return 0
end

-- Test assertion strings (preserved for regression tests)

-- ============================================================================
-- State builder
-- ============================================================================

-- ============================================================================
-- Schema for safe_state (Pattern 14 nil-guard elimination).
local FIRE_SCHEMA = {
    scorch_stacks = 0,
    scorch_remains = 0,
    pyroblast_ready = false,
    combustion_ready = false,
    mana_pct = 100,
    hp_pct = 100,
    mana_gem_available = false,
    remove_curse_ready = false,
    healthstone_ready = 0,
    has_clearcasting = false,
    bloodlust_active = false,
    major_cd_window = false,
}

local fire_state = {
    scorch_stacks = 0,
    scorch_remains = 0,
    pyroblast_ready = false,
    combustion_ready = false,
    mana_pct = 100,
    mana_gem_available = false,
    remove_curse_ready = false,
    healthstone_ready = 0,
}

local function first_ready_mana_gem()
    if not NS.is_item_ready then return nil end
    for _, item_id in ipairs(MANA_GEM_ITEM_IDS) do
        local ok, ready = pcall(NS.is_item_ready, item_id)
        if ok and ready then return item_id end
    end
    return nil
end

local function use_mana_gem()
    local item_id = first_ready_mana_gem()
    if not item_id or not NS.use_item_by_id then return false end
    local ok, used = pcall(NS.use_item_by_id, item_id)
    return ok and used == true
end

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target
    -- Clearcasting proc (Arcane Concentration) — consumed on Fireball below. [#fix-1]
    fire_state.has_clearcasting = me and NS.buff_up(me, CLEARCASTING_BUFF) or false
    if target then
        fire_state.scorch_stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, SCORCH_DEBUFF) or 0
        fire_state.scorch_remains = NS.debuff_remains and NS.debuff_remains(target, SCORCH_DEBUFF) or 0
    else
        fire_state.scorch_stacks = 0
        fire_state.scorch_remains = 0
    end
    fire_state.combustion_ready = NS.spell_ready(ACTION.Combustion, NS.PLAYER_UNIT, { skip_range = true })
    fire_state.mana_pct = context.mana_pct or 100
    fire_state.remove_curse_ready = NS.spell_ready(ACTION.RemoveCurse, NS.PLAYER_UNIT, { skip_range = true })
    fire_state.mana_gem_available = first_ready_mana_gem() ~= nil
    if target then
        fire_state.pyroblast_ready = NS.spell_ready(ACTION.Pyroblast, target)
    end
    fire_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS)
    -- Major power-window awareness for cooldown alignment
    fire_state.bloodlust_active = me and NS.buff_up and NS.buff_up(me, BLOODLUST_HEROISM_BUFFS) or false
    fire_state.major_cd_active = planner and planner.is_major_offensive_cd_active(context) or false
    fire_state.major_cd_window = fire_state.bloodlust_active or fire_state.major_cd_active
    return spec_kit.safe_state(fire_state, FIRE_SCHEMA)
end

-- ============================================================================
-- Matches functions
-- ============================================================================

local function combustion_matches_fn(context, state)
    if not state.combustion_ready then return false end
    if not context.in_combat then return false end
    if context.settings and context.settings.use_cooldowns == false then return false end
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    -- TTD gate: don't waste 3min CD on a dying target
    if context.ttd_known and context.ttd > 0 and context.ttd < 15 then return false end
    -- Prefer 5-stack Scorch before popping Combustion, unless burst forced
    local stacks = (state and state.scorch_stacks) or (context.scorch_stacks or 0)
    if not context.should_burst and stacks < 5 then return false end
    -- Align with major power windows (Bloodlust/Drums/trinkets/other CDs).
    local align = state.major_cd_window or false
    local combat_time = context.combat_time or 0
    local ttd = context.ttd or 999
    if not context.should_burst and not align and combat_time < 45 and ttd > 15 then return false end
    return true
end

local function scorch_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.Scorch, 2.0) then return false end
    if context.is_moving then return false end
    if not context.target then return false end
    -- Gate on user toggle for assigned Scorch debuff duty
    if context.settings and context.settings.use_scorch_debuff == false then return false end
    -- Build 5-stack Fire Vulnerability; maintain when about to drop

    -- Context fallbacks: context.scorch_stacks / context.scorch_remains / context.pyroblast_ready
    -- Are all harmless dead code with or 0/or false guards -- no functional change needed.
    local stacks = (state and state.scorch_stacks) or (context.scorch_stacks or 0)
    local remains = (state and state.scorch_remains) or (context.scorch_remains or 0)
    if stacks < 5 then return NS.spell_ready(ACTION.Scorch, context.target) end
    if remains <= 4 then return NS.spell_ready(ACTION.Scorch, context.target) end
    return false
end

local function fireball_matches_fn(context, state)
    if context.is_moving then return false end
    -- Clearcasting: always consume on Fireball (highest damage) per research
    if state and state.has_clearcasting then return true end
    -- Only require 5-stack Scorch when Scorch duty is assigned
    local scorch_duty = not context.settings or context.settings.use_scorch_debuff ~= false
    if scorch_duty and ((state and state.scorch_stacks) or (context.scorch_stacks or 0)) < 5 then return false end

    return NS.spell_ready(ACTION.Fireball, context.target)
end

local function fire_blast_matches_fn(context, state)
    -- Instant filler when moving or nothing else ready

    return NS.spell_ready(ACTION.FireBlast, context.target)
end

local function flamestrike_matches_fn(context, state)
    if context.is_moving then return false end
    if (context.enemy_count or 1) < 3 then return false end

    return NS.spell_ready(ACTION.Flamestrike, context.target)
end

local function flamestrike_rank6_matches_fn(context, state)
    if context.is_moving then return false end
    if (context.enemy_count or 1) < 3 then return false end

    return NS.spell_ready(ACTION.FlamestrikeRank6, context.target)
end

local function blizzard_matches_fn(context, state)
    if context.is_moving then return false end
    if (context.enemy_count or 1) < 4 then return false end

    return NS.spell_ready(ACTION.Blizzard, context.target)
end

local function arcane_explosion_matches_fn(context, state)
    if (context.enemy_count or 1) < 3 then return false end

    return NS.spell_ready(ACTION.ArcaneExplosion, context.target)
end

-- Defensives / Utility
local function ice_barrier_matches_fn(context, state)
    if (context.hp or 100) > 60 then return false end
    if context.settings and (context.settings.use_defensives == false or context.settings.use_ice_barrier == false) then return false end
    if NS.has_player_buff(11426) then return false end

    return NS.spell_ready(ACTION.IceBarrier, NS.PLAYER_UNIT, { skip_range = true })
end

local function mana_shield_matches_fn(context, state)
    if (context.hp or 100) > 40 then return false end
    if context.settings and (context.settings.use_defensives == false or context.settings.use_mana_shield == false) then return false end

    return NS.spell_ready(ACTION.ManaShield, NS.PLAYER_UNIT, { skip_range = true })
end

local function evocation_matches_fn(context, state)
    if context.settings and context.settings.use_evocation == false then return false end
    if ((state and state.mana_pct) or (context.mana_pct or 100)) > 20 then return false end
    if not context.in_combat then return false end

    return NS.spell_ready(ACTION.Evocation, NS.PLAYER_UNIT, { skip_range = true })
end

local function mana_gem_conjure_matches_fn(context, state)
    if context.in_combat then return false end
    if state and state.mana_gem_available then return false end
    return NS.spell_ready(ACTION.ConjureManaEmerald, NS.PLAYER_UNIT, { skip_range = true })
end

local function mana_gem_matches_fn(context, state)
    if context.settings and context.settings.use_mana_gem == false then return false end
    if not context.in_combat then return false end
    if not (state and state.mana_gem_available) then return false end
    local gem_threshold = (context.settings and context.settings.mana_gem_mana_pct) or 70
    if (state and state.mana_pct or context.mana_pct or 100) > gem_threshold then return false end
    return true
end

local function blast_wave_matches_fn(context, state)
    if (context.enemy_count or 1) < 2 then return false end
    return NS.spell_ready(ACTION.BlastWave, context.target)
end

local function dragons_breath_matches_fn(context, state)
    if (context.enemy_count or 1) < 2 then return false end
    -- Talent gate: must have Dragon's Breath learned (fire talent, not baseline)
    if not (ACTION.DragonsBreath and NS.spell_ready(ACTION.DragonsBreath, context.target, { skip_range = true })) then
        -- Fall back to BlastWave if Dragon's Breath not talented

        return NS.spell_ready(ACTION.BlastWave, context.target)
    end

    return true
end

local function polymorph_matches_fn(context, state)
    if NS.DRTracker and NS.DRTracker.is_dr_immune and context.cc_target and NS.DRTracker.is_dr_immune(context.cc_target, "incapacitate") then return false end
    if NS.pvp_trinket_used_recently and NS.pvp_trinket_used_recently(context.cc_target) then return false end
    if not (context.is_pvp or context.is_group) then return false end
    if not context.cc_target then return false end

    return NS.spell_ready(ACTION.Polymorph, context.cc_target or context.target)
end

local function pyroblast_matches_fn(context, state)
    if context.is_moving then return false end
    -- Opener with Presence of Mind, or when not in combat
    local pom_active = NS.has_player_buff(12043) -- Presence of Mind
    local can_cast = false
    if not context.in_combat and context.settings and context.settings.use_pyro_opener then
        can_cast = true
    elseif pom_active then
        can_cast = true
    end
    if not can_cast then return false end
    if not ((state and state.pyroblast_ready) or context.pyroblast_ready or pom_active) then return false end

    return NS.spell_ready(ACTION.Pyroblast, context.target)
end

local function presence_of_mind_matches_fn(context, state)
    if not context.in_combat then return false end
    if context.settings and context.settings.use_cooldowns == false then return false end
    if not context.should_burst then return false end
    if NS.has_player_buff(12043) then return false end
    return NS.spell_ready(ACTION.PresenceOfMind, NS.PLAYER_UNIT, { skip_range = true })
end

local function remove_curse_matches_fn(context, state)
    -- Gate on user toggle (following Frost pattern: simple ready check, middleware handles curse detection)
    if context.settings and context.settings.use_remove_curse_fire == false then return false end
    if not (state and state.remove_curse_ready) then return false end
    return true
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    { name = "ManaPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_mana_potion then return false end
          if (context.mana_pct or 100) > 20 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
    -- Defensives
    { name = "IceBarrier",
      matches = ice_barrier_matches_fn,
      execute = function() return NS.try_cast(ACTION.IceBarrier, NS.PLAYER_UNIT, "[FIRE] Ice Barrier") end },
    { name = "ManaShield",
      matches = mana_shield_matches_fn,
      execute = function() return NS.try_cast(ACTION.ManaShield, NS.PLAYER_UNIT, "[FIRE] Mana Shield") end },
    { name = "Healthstone",
      matches = function(context, state)
          if not context.in_combat then return false end
          if (state.hp_pct or 100) > 28 then return false end
          return (state.healthstone_ready or 0) > 0
      end,
      execute = function(context)
          local item_id = first_ready_item(HEALTHSTONE_IDS)
          if item_id > 0 and NS.use_item_by_id then
              return NS.use_item_by_id(item_id, context.me) and true or false
          end
          return false
      end,
    },
    -- Presence of Mind burst setup
    { name = "PresenceOfMind",
      matches = presence_of_mind_matches_fn,
      execute = function() return NS.try_cast(ACTION.PresenceOfMind, NS.PLAYER_UNIT, "[FIRE] Presence of Mind") end },
    -- Combustion burst
    { name = "Combustion",
      matches = combustion_matches_fn,
      execute = function() return NS.try_cast(ACTION.Combustion, NS.PLAYER_UNIT, "[FIRE] Combustion") end },
    -- Pyroblast (PoM / opener)
    { name = "Pyroblast",
      matches = pyroblast_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.Pyroblast, context.target, "[FIRE] Pyroblast") end },
    -- Scorch 5-stack maintenance
    { name = "Scorch",
      matches = scorch_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.Scorch, context.target, "[FIRE] Scorch") end },
    -- Main nuke
    { name = "Fireball",
      matches = fireball_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.Fireball, context.target, "[FIRE] Fireball") end },
    -- Instant filler
    { name = "FireBlast",
      matches = fire_blast_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.FireBlast, context.target, "[FIRE] Fire Blast") end },
    -- AoE: Flamestrike before Blizzard (test assertion ordering)
    { name = "Flamestrike",
      matches = flamestrike_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.Flamestrike, context.target, "[FIRE] Flamestrike") end },
    { name = "FlamestrikeRank6",
      matches = flamestrike_rank6_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.FlamestrikeRank6, context.target, "[FIRE] Flamestrike Rank 6") end },
    { name = "ArcaneExplosion",
      matches = arcane_explosion_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.ArcaneExplosion, context.target, "[FIRE] Arcane Explosion") end },
    { name = "Blizzard",
      matches = blizzard_matches_fn,
      execute = function(context) local t = context.target; local pos = t and NS.get_aoe_cast_position(NS.get_spell_id(ACTION.Blizzard), t, 8, 35); if pos then return NS.try_cast_position(ACTION.Blizzard, pos, t, "[FIRE] Blizzard") end; return NS.try_cast(ACTION.Blizzard, t, "[FIRE] Blizzard") end },
    -- AoE burst
    { name = "BlastWave",
      matches = blast_wave_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.BlastWave, context.target, "[FIRE] Blast Wave") end },
    { name = "DragonsBreath",
      matches = dragons_breath_matches_fn,
      execute = function(context)
           if ACTION.DragonsBreath and NS.spell_ready(ACTION.DragonsBreath, context.target, { skip_range = true }) then
              return NS.try_cast(ACTION.DragonsBreath, context.target, "[FIRE] Dragon's Breath")
          end
          return NS.try_cast(ACTION.BlastWave, context.target, "[FIRE] Dragon's Breath fallback")
      end },
    -- CC
    { name = "Polymorph",
      matches = polymorph_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.Polymorph, context.cc_target or context.target, "[FIRE] Polymorph") end },
    -- Utility: Remove Curse (curse detection via mage middleware; Fire toggle gates execution)
    { name = "RemoveCurse",
      matches = remove_curse_matches_fn,
      execute = function(context) return NS.try_cast(ACTION.RemoveCurse, context.me or NS.GetPlayer() or NS.PLAYER_UNIT, "[FIRE] Remove Curse") end },
    -- Mana sustain
    { name = "ManaGemConjure",
      matches = mana_gem_conjure_matches_fn,
      execute = function() return NS.try_cast(ACTION.ConjureManaEmerald, NS.PLAYER_UNIT, "[FIRE] Conjure Mana Gem") end },
    { name = "ManaGem",
      matches = mana_gem_matches_fn,
      execute = function() return use_mana_gem() end },
    { name = "Evocation",
      matches = evocation_matches_fn,
      execute = function() return NS.try_cast(ACTION.Evocation, NS.PLAYER_UNIT, "[FIRE] Evocation") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("fire", strategies, { get_state = build_state })
end
-- Mage fire rotation registered (deep enhanced)
return { strategies = strategies, build_state = build_state }

