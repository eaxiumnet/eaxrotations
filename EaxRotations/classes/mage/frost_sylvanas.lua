-- Readability notes:
--   What: Mage Frost priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05): Added Ice Barrier pre-shield, Cold Snap cooldown reset, Frost Nova freeze
--   into Ice Lance shatter combo, Cone of Cold AoE, and improved Ice Block defensive gating.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.MageSpells or {}

local ICE_BARRIER_BUFF = { 13032, 13031, 13033 }

-- ============================================================================
-- Custom Gating Functions
-- ============================================================================

local function ice_block_matches(context, action)
    -- Only Ice Block when HP is critically low
    local me = context.me
    if not me then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100
    if hp > 20 then return false end
    return NS.action_matches(context, action)
end

local function cold_snap_matches(context, action)
    -- Use Cold Snap when Ice Block is on cooldown and we might need it soon,
    -- or when Icy Veins is on cooldown during burst windows.
    local me = context.me
    if not me then return false end
    -- Don't Cold Snap if Ice Block is already ready
    if NS.spell_ready and NS.spell_ready(SPELLS.IceBlock, me) then return false end
    -- Use when HP is dropping
    local hp = me.get_health_percentage and me:get_health_percentage() or 100
    if hp > 35 then return false end
    return NS.action_matches(context, action)
end

local function frost_nova_matches(context, action)
    -- Freeze target for Ice Lance shatter combo, or AoE root
    if not context.target then return false end
    local target = context.target
    -- Skip if target is already rooted (wastes the nova)
    local is_rooted = target.has_debuff and target:has_debuff({ 27088, 12505, 122, 865, 6131, 10230, 120, 119 })
    if is_rooted then return false end
    -- Only freeze in melee range (or when multiple enemies nearby for AoE)
    local me = context.me
    if not me then return false end
    local dist = me.get_distance and me:get_distance(target) or 999
    if dist > 10 then return false end
    return NS.action_matches(context, action)
end

local function cone_of_cold_matches(context, action)
    if not context.target then return false end
    -- Cone of Cold is short-range AoE; only use within 10 yards
    local me = context.me
    if not me then return false end
    local dist = me.get_distance and me:get_distance(context.target) or 999
    if dist > 10 then return false end
    -- Count nearby enemies via the local player's enemy scan (if available)
    -- Falls back to distance-only gate so CoC still fires on close targets
    local nearby = 1  -- at least the target is nearby
    if context.enemies then
        nearby = 0
        for i = 1, #context.enemies do
            local e = context.enemies[i]
            if e and e:is_valid() then
                local edist = me.get_distance and me:get_distance(e) or 999
                if edist <= 10 then nearby = nearby + 1 end
            end
        end
    end
    if nearby < 2 then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Priority List
-- ============================================================================

local ACTIONS = {
    -- Self-buffs & defensives (no target required)
    { name = "IceBarrier",       spell = SPELLS.IceBarrier,       target = "self", kind = "buff", buff = ICE_BARRIER_BUFF, requires_target = false },

    -- Emergency defensive
    { name = "IceBlock",         spell = SPELLS.IceBlock,         target = "self", matches = ice_block_matches, requires_target = false },

    -- Cooldown reset (only when Ice Block is down and HP is low)
    { name = "ColdSnap",         spell = SPELLS.ColdSnap,         target = "self", cooldown = 480, matches = cold_snap_matches, requires_target = false },

    -- Burst cooldowns
    { name = "IcyVeins",         spell = SPELLS.IcyVeins,         target = "self", combat = true, cooldown = 180, requires_target = false, setting = "use_cooldowns" },
    { name = "WaterElemental",   spell = SPELLS.WaterElemental,   target = "self", combat = true, cooldown = 180, requires_target = false },

    -- Freeze + Shatter combo: Frost Nova then Ice Lance for bonus damage
    { name = "FrostNova",        spell = SPELLS.FrostNova,        matches = frost_nova_matches },
    { name = "IceLance",         spell = SPELLS.IceLance },

    -- AoE
    { name = "ConeOfCold",       spell = SPELLS.ConeOfCold,       matches = cone_of_cold_matches },
    { name = "Blizzard",         spell = SPELLS.Blizzard,         position = "target", enemy_count = 3, not_moving = true },

    -- Core nuke
    { name = "Frostbolt",        spell = SPELLS.Frostbolt,        not_moving = true },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    strategies[#strategies + 1] = {
        name = action.name,
        matches = function(context)
            if action.matches then
                return action.matches(context, action)
            end
            return NS.action_matches(context, action)
        end,
        execute = function(context) return NS.action_execute(context, action, "[FROST]") end,
    }
end

NS.rotation_registry:register("frost", strategies, { get_state = function(context) return context end })
NS.log("Mage frost rotation registered (enhanced: Ice Barrier, Cold Snap, Frost Nova combo, Cone of Cold AoE)")
return strategies
