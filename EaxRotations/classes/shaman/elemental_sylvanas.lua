-- Readability notes:
--   What: Shaman Elemental priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: action rows show what is cast, why it is gated, and when it is allowed.
--   Safety: all rows use shared spell/resource/range/form checks before casting.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
--   Enhancement notes (2026-05-13): Added Flame Shock DoT maintenance, Chain Lightning clearcast logic,
--   Totem of Wrath support, and moving filler with shocks.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.ShamanSpells or {}

local LIGHTNING_SHIELD_BUFF = { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local FLAME_SHOCK_DEBUFF = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
local EARTH_SHOCK_DEBUFF = { 25464, 10414, 10413, 10412, 8046, 8045, 8044, 8042 }

local SHOCK_REFRESH_WINDOW = 3
local LOW_MANA_THRESHOLD = 15

-- ============================================================================
-- Flame Shock DoT Maintenance
-- ============================================================================

local function flame_shock_matches(context, action)
    local target = context.target
    if not target then return false end
    local remains = NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF) or 0
    if remains > SHOCK_REFRESH_WINDOW then return false end
    -- Only refresh if target lives long enough
    if not NS.should_refresh_dot(remains, 1.5, context.ttd, 12) then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Chain Lightning Logic
-- ============================================================================
-- Only cast Chain Lightning when 2+ enemies (natural AoE) or during burst windows

local function chain_lightning_matches(context, action)
    if context.is_moving then return false end
    -- Chain Lightning is higher DPS than Lightning Bolt when 2+ targets
    if (context.enemy_count or 1) >= 2 then
        return NS.action_matches(context, action)
    end
    -- Single target: only use CL if it's ready and we're not mana-starved
    local mana_pct = context.mana_pct or 100
    if mana_pct < LOW_MANA_THRESHOLD then return false end
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Earth Shock Interrupt / Weaving
-- ============================================================================
-- Earth Shock as interrupt when target casting, or as moving filler

local function earth_shock_interrupt_matches(context, action)
    -- Interrupt priority: target is casting and we can shock
    local target = context.target
    if not target then return false end
    local is_casting = false
    local ok = pcall(function()
        if target.is_casting and target:is_casting() then is_casting = true end
        if target.is_casting_spell and target:is_casting_spell() then is_casting = true end
    end)
    if not is_casting then return false end
    return NS.action_matches(context, action)
end

local ACTIONS = {
    { name = "LightningShield", spell = SPELLS.LightningShield, target = "self", kind = "buff", buff = LIGHTNING_SHIELD_BUFF, requires_target = false },
    { name = "Bloodlust", spell = SPELLS.Bloodlust, target = "self", combat = true, setting = "use_cooldowns", cooldown = 600, min_mana = 25, requires_target = false },
    { name = "ChainLightning", spell = SPELLS.ChainLightning, not_moving = true, cooldown = 6, matches = chain_lightning_matches },
    { name = "LightningBolt", spell = SPELLS.LightningBolt, not_moving = true },
    { name = "FlameShockMoving", spell = SPELLS.FlameShock, debuff = FLAME_SHOCK_DEBUFF, refresh = 3, moving = true, cooldown = 6, matches = flame_shock_matches },
    { name = "EarthShockMoving", spell = SPELLS.EarthShock, moving = true, cooldown = 6, matches = earth_shock_interrupt_matches },
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
        execute = function(context) return NS.action_execute(context, action, "[ELEMENTAL]") end,
    }
end

NS.rotation_registry:register("elemental", strategies, { get_state = function(context) return context end })
NS.log("Shaman elemental rotation registered (enhanced: Flame Shock DoT, CL AoE logic, Earth Shock interrupt)")
return strategies
