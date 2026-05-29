-- Mage Fire priority list.


local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.MageSpells or {}

local SCORCH_DEBUFF = { 22959 }

-- Mana Gem item IDs (highest to lowest rank)
local MANA_GEM_ITEM_IDS = { 8008, 8007, 5513, 5514 }  -- Ruby, Citrine, Jade, Agate
local MANA_GEM_CONJURE = { 10054, 10053, 3552, 759 }  -- Conjure Mana Ruby..Agate

-- Test assertion strings (preserved for regression tests)

-- ============================================================================
-- State builder
-- ============================================================================

local fire_state = {
    scorch_stacks = 0,
    scorch_remains = 0,
    combustion_ready = false,
    mana_pct = 100,
    mana_gem_available = false,
    remove_curse_ready = false,
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
    local target = context.target
    if target then
        fire_state.scorch_stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, SCORCH_DEBUFF) or 0
        fire_state.scorch_remains = NS.debuff_remains and NS.debuff_remains(target, SCORCH_DEBUFF) or 0
    else
        fire_state.scorch_stacks = 0
        fire_state.scorch_remains = 0
    end
    fire_state.combustion_ready = NS.spell_ready(SPELLS.Combustion, NS.PLAYER_UNIT, { skip_range = true })
    fire_state.mana_pct = context.mana_pct or 100
    fire_state.remove_curse_ready = NS.spell_ready(SPELLS.RemoveCurse, NS.PLAYER_UNIT, { skip_range = true })
    fire_state.mana_gem_available = first_ready_mana_gem() ~= nil
    return fire_state
end

-- ============================================================================
-- Matches functions
-- ============================================================================

local function combustion_matches_fn(context, state)
    if not state.combustion_ready then return false end
    if not context.in_combat then return false end
    if context.settings and context.settings.use_cooldowns == false then return false end
    if context.should_burst then return true end
    if NS.should_use_long_cd then return NS.should_use_long_cd(context, 180) end; return false
end

local function scorch_matches_fn(context, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Scorch, 2.0) then return false end
    if context.is_moving then return false end
    if not context.target then return false end
    -- Gate on user toggle for assigned Scorch debuff duty
    if context.settings and context.settings.use_scorch_debuff == false then return false end
    -- Build 5-stack Fire Vulnerability; maintain when about to drop

    local stacks = (state and state.scorch_stacks) or (context.scorch_stacks or 0)
    local remains = (state and state.scorch_remains) or (context.scorch_remains or 0)
    if stacks < 5 then return NS.spell_ready(SPELLS.Scorch, context.target) end
    if remains <= 4 then return NS.spell_ready(SPELLS.Scorch, context.target) end
    return false
end

local function fireball_matches_fn(context, state)
    if context.is_moving then return false end
    -- Only require 5-stack Scorch when Scorch duty is assigned
    local scorch_duty = not context.settings or context.settings.use_scorch_debuff ~= false
    if scorch_duty and ((state and state.scorch_stacks) or (context.scorch_stacks or 0)) < 5 then return false end

    return NS.spell_ready(SPELLS.Fireball, context.target)
end

local function fire_blast_matches_fn(context, state)
    -- Instant filler when moving or nothing else ready

    return NS.spell_ready(SPELLS.FireBlast, context.target)
end

local function flamestrike_matches_fn(context, state)
    if context.is_moving then return false end
    if (context.enemy_count or 1) < 3 then return false end

    return NS.spell_ready(SPELLS.Flamestrike, context.target)
end

local function flamestrike_rank6_matches_fn(context, state)
    if context.is_moving then return false end
    if (context.enemy_count or 1) < 3 then return false end

    return NS.spell_ready(SPELLS.FlamestrikeRank6, context.target)
end

local function blizzard_matches_fn(context, state)
    if context.is_moving then return false end
    if (context.enemy_count or 1) < 4 then return false end

    return NS.spell_ready(SPELLS.Blizzard, context.target)
end

local function arcane_explosion_matches_fn(context, state)
    if (context.enemy_count or 1) < 3 then return false end

    return NS.spell_ready(SPELLS.ArcaneExplosion, context.target)
end

-- Defensives / Utility
local function ice_barrier_matches_fn(context, state)
    if (context.hp or 100) > 60 then return false end
    if context.settings and (context.settings.use_defensives == false or context.settings.use_ice_barrier == false) then return false end
    if NS.has_player_buff(11426) then return false end

    return NS.spell_ready(SPELLS.IceBarrier, NS.PLAYER_UNIT, { skip_range = true })
end

local function mana_shield_matches_fn(context, state)
    if (context.hp or 100) > 40 then return false end
    if context.settings and (context.settings.use_defensives == false or context.settings.use_mana_shield == false) then return false end

    return NS.spell_ready(SPELLS.ManaShield, NS.PLAYER_UNIT, { skip_range = true })
end

local function evocation_matches_fn(context, state)
    if context.settings and context.settings.use_evocation == false then return false end
    if ((state and state.mana_pct) or (context.mana_pct or 100)) > 20 then return false end
    if not context.in_combat then return false end

    return NS.spell_ready(SPELLS.Evocation, NS.PLAYER_UNIT, { skip_range = true })
end

local function mana_gem_conjure_matches_fn(context, state)
    if context.in_combat then return false end
    if state and state.mana_gem_available then return false end
    return NS.spell_ready(SPELLS.ConjureManaEmerald, NS.PLAYER_UNIT, { skip_range = true })
end

local function mana_gem_matches_fn(context, state)
    if context.settings and context.settings.use_mana_gem == false then return false end
    if not context.in_combat then return false end
    if not (state and state.mana_gem_available) then return false end
    local gem_threshold = (context.settings and context.settings.mana_gem_mana_pct) or 70
    if (state and state.mana_pct or context.mana_pct or 100) > gem_threshold then return false end
    return true
end

local function counterspell_matches_fn(context, state)
    if not context.target then return false end
    if context.settings and context.settings.use_interrupt == false then return false end
    local target_casting = false
    if type(context.target.is_casting) == "function" then
        local ok, val = pcall(context.target.is_casting, context.target)
        target_casting = ok and val == true
    elseif context.target.is_casting == true then
        target_casting = true
    end
    if not target_casting then return false end

    return NS.spell_ready(SPELLS.Counterspell, context.target)
end

local function blast_wave_matches_fn(context, state)
    if (context.enemy_count or 1) < 2 then return false end
    return NS.spell_ready(SPELLS.BlastWave, context.target)
end

local function dragons_breath_matches_fn(context, state)
    if (context.enemy_count or 1) < 2 then return false end
    -- Talent gate: must have Dragon's Breath learned (fire talent, not baseline)
    if not (SPELLS.UnavailableClassicMageFire and NS.spell_ready(SPELLS.UnavailableClassicMageFire, context.target, { skip_range = true })) then
        -- Fall back to BlastWave if Dragon's Breath not talented

        return NS.spell_ready(SPELLS.BlastWave, context.target)
    end

    return true
end

local function polymorph_matches_fn(context, state)
    if not context.is_pvp then return false end
    if not context.cc_target then return false end

    return NS.spell_ready(SPELLS.Polymorph, context.cc_target)
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
    return NS.spell_ready(SPELLS.Pyroblast, context.target)
end

local function presence_of_mind_matches_fn(context, state)
    if not context.in_combat then return false end
    if context.settings and context.settings.use_cooldowns == false then return false end
    if not context.should_burst then return false end
    if NS.has_player_buff(12043) then return false end
    return NS.spell_ready(SPELLS.PresenceOfMind, NS.PLAYER_UNIT, { skip_range = true })
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
    -- Defensives
    { name = "IceBarrier",
      matches = ice_barrier_matches_fn,
      execute = function() return NS.try_cast(SPELLS.IceBarrier, NS.PLAYER_UNIT, "[FIRE] Ice Barrier") end },
    { name = "ManaShield",
      matches = mana_shield_matches_fn,
      execute = function() return NS.try_cast(SPELLS.ManaShield, NS.PLAYER_UNIT, "[FIRE] Mana Shield") end },
    -- Interrupt
    { name = "Counterspell",
      matches = counterspell_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.Counterspell, context.target, "[FIRE] Counterspell") end },
    -- Presence of Mind burst setup
    { name = "PresenceOfMind",
      matches = presence_of_mind_matches_fn,
      execute = function() return NS.try_cast(SPELLS.PresenceOfMind, NS.PLAYER_UNIT, "[FIRE] Presence of Mind") end },
    -- Combustion burst
    { name = "Combustion",
      matches = combustion_matches_fn,
      execute = function() return NS.try_cast(SPELLS.Combustion, NS.PLAYER_UNIT, "[FIRE] Combustion") end },
    -- Pyroblast (PoM / opener)
    { name = "Pyroblast",
      matches = pyroblast_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.Pyroblast, context.target, "[FIRE] Pyroblast") end },
    -- Scorch 5-stack maintenance
    { name = "Scorch",
      matches = scorch_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.Scorch, context.target, "[FIRE] Scorch") end },
    -- Main nuke
    { name = "Fireball",
      matches = fireball_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.Fireball, context.target, "[FIRE] Fireball") end },
    -- Instant filler
    { name = "FireBlast",
      matches = fire_blast_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.FireBlast, context.target, "[FIRE] Fire Blast") end },
    -- AoE: Flamestrike before Blizzard (test assertion ordering)
    { name = "Flamestrike",
      matches = flamestrike_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.Flamestrike, context.target, "[FIRE] Flamestrike") end },
    { name = "FlamestrikeRank6",
      matches = flamestrike_rank6_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.FlamestrikeRank6, context.target, "[FIRE] Flamestrike Rank 6") end },
    { name = "ArcaneExplosion",
      matches = arcane_explosion_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.ArcaneExplosion, context.target, "[FIRE] Arcane Explosion") end },
    { name = "Blizzard",
      matches = blizzard_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.Blizzard, context.target, "[FIRE] Blizzard") end },
    -- AoE burst
    { name = "BlastWave",
      matches = blast_wave_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.BlastWave, context.target, "[FIRE] Blast Wave") end },
    { name = "UnavailableClassicMageFire",
      matches = dragons_breath_matches_fn,
      execute = function(context)
           if SPELLS.UnavailableClassicMageFire and NS.spell_ready(SPELLS.UnavailableClassicMageFire, context.target, { skip_range = true }) then
              return NS.try_cast(SPELLS.UnavailableClassicMageFire, context.target, "[FIRE] Dragon's Breath")
          end
          return NS.try_cast(SPELLS.BlastWave, context.target, "[FIRE] Dragon's Breath fallback")
      end },
    -- CC
    { name = "Polymorph",
      matches = polymorph_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.Polymorph, context.cc_target, "[FIRE] Polymorph") end },
    -- Utility: Remove Curse (curse detection via mage middleware; Fire toggle gates execution)
    { name = "RemoveCurse",
      matches = remove_curse_matches_fn,
      execute = function(context) return NS.try_cast(SPELLS.RemoveCurse, context.me or NS.GetPlayer() or NS.PLAYER_UNIT, "[FIRE] Remove Curse") end },
    -- Mana sustain
    { name = "ManaGemConjure",
      matches = mana_gem_conjure_matches_fn,
      execute = function() return NS.try_cast(SPELLS.ConjureManaEmerald, NS.PLAYER_UNIT, "[FIRE] Conjure Mana Gem") end },
    { name = "ManaGem",
      matches = mana_gem_matches_fn,
      execute = function() return use_mana_gem() end },
    { name = "Evocation",
      matches = evocation_matches_fn,
      execute = function() return NS.try_cast(SPELLS.Evocation, NS.PLAYER_UNIT, "[FIRE] Evocation") end },
}

NS.rotation_registry:register("fire", strategies, { get_state = build_state })
NS.log("Mage fire rotation registered (deep enhanced)")
return strategies

