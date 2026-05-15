-- Druid leveling rotation.
-- Auto-activates in solo/leveling context or when playstyle = "leveling".
-- Uses shared leveling module for context guard, wand, and common helpers.
-- Designed for caster-form solo leveling (Moonfire, Wrath, Starfire, Insect Swarm).

local NS = _G.EaxRotations
if not NS then return nil end

local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end

-- ============================================================================
-- Module table
-- ============================================================================
local druid_leveling = {}

-- ============================================================================
-- Context guard
-- ============================================================================
local is_leveling_context = leveling.create_context_guard()

-- ============================================================================
-- Constants
-- ============================================================================
local SPELLS = NS.DruidSpells or {}
local MARK_OF_THE_WILD_BUFF = { 26991, 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126, 21850, 21849 }
local THORNS_BUFF = { 26992, 9910, 9756, 8914, 1075, 782, 467 }

-- ============================================================================
-- Strategy helpers
-- ============================================================================

local function spell_ready(spell_action)
    if not spell_action then return false end
    return NS.spell_ready and NS.spell_ready(spell_action) or false
end

local function try_cast(spell_action, target, label)
    if not spell_action then return false end
    local ok, result = pcall(NS.try_cast, spell_action, target, label or "")
    return ok and result == true
end

local function has_buff(buff_ids)
    if not buff_ids then return false end
    local me = NS.get_local_player and NS.get_local_player()
    if not me then return false end
    local ids = type(buff_ids) == "table" and buff_ids or { buff_ids }
    for _, id in ipairs(ids) do
        local ok, result = pcall(function() return me:has_buff(id) end)
        if ok and result then return true end
    end
    return false
end

-- ============================================================================
-- State builder
-- ============================================================================

function druid_leveling.build_state(context)
    if not context then return nil end

    local state = {}

    -- Common state
    leveling.build_common_state(context, state)

    -- Druid-specific spell readiness
    state.mark_of_the_wild_ready = spell_ready(SPELLS.MarkOfTheWild)
    state.thorns_ready = spell_ready(SPELLS.Thorns)
    state.moonfire_ready = spell_ready(SPELLS.Moonfire)
    state.wrath_ready = spell_ready(SPELLS.Wrath)
    state.starfire_ready = spell_ready(SPELLS.Starfire)
    state.insect_swarm_ready = spell_ready(SPELLS.InsectSwarm)
    state.hurricane_ready = spell_ready(SPELLS.Hurricane)
    state.rejuvenation_ready = spell_ready(SPELLS.Rejuvenation)
    state.healing_touch_ready = spell_ready(SPELLS.HealingTouch)
    state.barkskin_ready = spell_ready(SPELLS.Barkskin)
    state.entangling_roots_ready = spell_ready(SPELLS.EntanglingRoots)
    state.natures_grasp_ready = spell_ready(SPELLS.NaturesGrasp)
    state.faerie_fire_ready = spell_ready(SPELLS.FaerieFire)

    -- Buff checks
    state.has_mark_of_wild = has_buff(MARK_OF_THE_WILD_BUFF)
    state.has_thorns = has_buff(THORNS_BUFF)

    -- Settings
    local settings = context.settings or {}
    state.wand_threshold = settings.leveling_wand_threshold or 30
    state.heal_hp = settings.leveling_heal_hp or 40

    return state
end

-- ============================================================================
-- Match functions
-- ============================================================================

--- Mark of the Wild - OOC buff
local motw_matches = function(context, state)
	    if not state then return false end
	    if state.in_combat then return false end
    if state.has_mark_of_wild then return false end
    if not state.mark_of_the_wild_ready then return false end
    return true
end

--- Thorns - OOC buff
local thorns_matches = function(context, state)
	    if not state then return false end
	    if state.in_combat then return false end
    if state.has_thorns then return false end
    if not state.thorns_ready then return false end
    return true
end

--- Barkskin - defensive
local barkskin_matches = function(context, state)
	    if not state then return false end
	    if not state.in_combat then return false end
    if not state.barkskin_ready then return false end
    if state.hp > 50 then return false end  -- Only when HP is low
    return true
end

--- Rejuvenation - HoT heal when low HP
local rejuvenation_matches = function(context, state)
	    if not state then return false end
	    if not state.in_combat then return false end
    if not state.rejuvenation_ready then return false end
    if state.hp > state.heal_hp then return false end
    return true
end

--- Entangling Roots - CC/survival when overwhelmed
local entangling_roots_matches = function(context, state)
	    if not state then return false end
	    if not state.in_combat then return false end
    if not state.entangling_roots_ready then return false end
    if not state.target then return false end
    -- Use when overwhelmed (3+ enemies) or low HP
    if state.enemies < 3 and state.hp > 30 then return false end
    return true
end

--- Moonfire - DoT refresh
local moonfire_matches = function(context, state)
	    if not state then return false end
	    if not state.in_combat then return false end
    if not state.moonfire_ready then return false end
    if not state.target then return false end
    -- Check DoT remaining
    local ok, remains = pcall(function() return NS.debuff_remains and NS.debuff_remains(state.target, SPELLS.Moonfire) or 0 end)
    if ok and remains and remains > 4 then return false end
    return true
end

--- Insect Swarm - DoT refresh
local insect_swarm_matches = function(context, state)
	    if not state then return false end
	    if not state.in_combat then return false end
    if not state.insect_swarm_ready then return false end
    if not state.target then return false end
    -- Check DoT remaining
    local ok, remains = pcall(function() return NS.debuff_remains and NS.debuff_remains(state.target, SPELLS.InsectSwarm) or 0 end)
    if ok and remains and remains > 4 then return false end
    return true
end

--- Faerie Fire - armor debuff (refresh < 60s, apply once)
local faerie_fire_matches = function(context, state)
	    if not state then return false end
	    if not state.in_combat then return false end
    if not state.faerie_fire_ready then return false end
    if not state.target then return false end
    -- Only apply if not already up
    local ok, remains = pcall(function() return NS.debuff_remains and NS.debuff_remains(state.target, SPELLS.FaerieFire) or 0 end)
    if ok and remains and remains > 10 then return false end  -- Already active
    return true
end

--- Hurricane - AoE (3+ enemies, not moving)
local hurricane_matches = function(context, state)
	    if not state then return false end
	    if not state.in_combat then return false end
    if not state.hurricane_ready then return false end
    if not state.target then return false end
    if state.enemies < 3 then return false end
    if state.is_moving then return false end
    return true
end

--- Starfire - big cast (not moving)
local starfire_matches = function(context, state)
	    if not state then return false end
	    if not state.in_combat then return false end
    if not state.starfire_ready then return false end
    if not state.target then return false end
    if state.is_moving then return false end
    return true
end

--- Wrath - filler (can cast while moving)
local wrath_matches = function(context, state)
	    if not state then return false end
	    if not state.in_combat then return false end
    if not state.wrath_ready then return false end
    if not state.target then return false end
    return true
end

-- ============================================================================
-- Strategies table
-- ============================================================================

local strategies = {
    -- OOC: Mark of the Wild
    { name = "MarkOfTheWild",
      matches = motw_matches,
      execute = function(context) return try_cast(SPELLS.MarkOfTheWild, nil, "[LEVELING] Mark of the Wild") end },

    -- OOC: Thorns
    { name = "Thorns",
      matches = thorns_matches,
      execute = function(context) return try_cast(SPELLS.Thorns, nil, "[LEVELING] Thorns") end },

    -- Defensive: Barkskin
    { name = "Barkskin",
      matches = barkskin_matches,
      execute = function(context) return try_cast(SPELLS.Barkskin, nil, "[LEVELING] Barkskin") end },

    -- Heal: Rejuvenation
    { name = "Rejuvenation",
      matches = rejuvenation_matches,
      execute = function(context) return try_cast(SPELLS.Rejuvenation, nil, "[LEVELING] Rejuvenation") end },

    -- CC: Entangling Roots (when overwhelmed)
    { name = "EntanglingRoots",
      matches = entangling_roots_matches,
      execute = function(context) return try_cast(SPELLS.EntanglingRoots, context.target, "[LEVELING] Entangling Roots") end },

    -- DoT: Moonfire
    { name = "Moonfire",
      matches = moonfire_matches,
      execute = function(context) return try_cast(SPELLS.Moonfire, context.target, "[LEVELING] Moonfire") end },

    -- DoT: Insect Swarm
    { name = "InsectSwarm",
      matches = insect_swarm_matches,
      execute = function(context) return try_cast(SPELLS.InsectSwarm, context.target, "[LEVELING] Insect Swarm") end },

    -- Debuff: Faerie Fire
    { name = "FaerieFire",
      matches = faerie_fire_matches,
      execute = function(context) return try_cast(SPELLS.FaerieFire, context.target, "[LEVELING] Faerie Fire") end },

    -- AoE: Hurricane
    { name = "Hurricane",
      matches = hurricane_matches,
      execute = function(context) return try_cast(SPELLS.Hurricane, context.target, "[LEVELING] Hurricane") end },

    -- Filler: Starfire (not moving)
    { name = "Starfire",
      matches = starfire_matches,
      execute = function(context) return try_cast(SPELLS.Starfire, context.target, "[LEVELING] Starfire") end },

    -- Filler: Wrath (any state)
    { name = "Wrath",
      matches = wrath_matches,
      execute = function(context) return try_cast(SPELLS.Wrath, context.target, "[LEVELING] Wrath") end },

    -- Wand fallback (when low mana)
    { name = "Wand",
      matches = leveling.create_wand_matches("leveling_wand_threshold", 30),
      execute = function(context) return leveling.execute_wand(context) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = druid_leveling.build_state })
end

-- ============================================================================
-- Rotation entry point
-- ============================================================================

function druid_leveling.on_update(context)
    if not context then return false end
    if not is_leveling_context(context) then return false end

    local state = druid_leveling.build_state(context)
    if not state then return false end

    -- Evaluate strategies in priority order
    for i = 1, #strategies do
        local strategy = strategies[i]
        local ok, should_execute = pcall(strategy.matches, context, state)
        if ok and should_execute then
            local ok2, result = pcall(strategy.execute, context)
            if ok2 and result then
                return true
            end
        end
    end

    return false
end

NS.log("[Druid] Leveling rotation loaded")
return druid_leveling
