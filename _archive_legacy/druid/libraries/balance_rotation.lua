-- =============================================================================
-- BALANCE (MOONKIN) ROTATION MODULE
-- Ported from Flux AIO - Strategy-based Balance DPS for TBC
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local Constants = require("libraries/constants")
local Spells = require("libraries/spells")
local Utils = require("libraries/utils")
local RotationEngine = require("libraries/rotation_engine")

local BalanceRotation = {}

-- ============================================================================
-- BALANCE STATE
-- ============================================================================
local balance_state = {
    mana_tier = 1,
    has_natures_grace = false,
    dot_refresh_threshold = 0,
}

-- ============================================================================
-- CONTEXT BUILDER
-- ============================================================================
local function build_balance_context(ctx, state)
    for k, v in pairs(balance_state) do
        state[k] = v
    end
    
    -- Calculate mana tier
    local settings = ctx.settings
    local mana_pct = ctx.mana_pct or 100
    local tier1 = settings.balance_tier1_mana or Constants.BALANCE.MANA_TIER1
    local tier2 = settings.balance_tier2_mana or Constants.BALANCE.MANA_TIER2
    
    if mana_pct < tier2 then
        state.mana_tier = 3
    elseif mana_pct < tier1 then
        state.mana_tier = 2
    else
        state.mana_tier = 1
    end
    
    -- Check for Nature's Grace
    state.has_natures_grace = ctx.me:buff_up(Constants.BUFF_ID.NATURES_GRACE)
    
    -- Dot refresh threshold
    state.dot_refresh_threshold = settings.balance_dot_refresh or 0
end

-- ============================================================================
-- STRATEGY DEFINITIONS
-- ============================================================================

-- [1] Faerie Fire
local FaerieFire = {
    name = "FaerieFire",
    requires_combat = true,
    requires_enemy = true,
    setting_key = "maintain_faerie_fire",
}
function FaerieFire.matches(ctx, state)
    local ff_mode = ctx.settings.maintain_faerie_fire
    if ff_mode == 4 or ff_mode == false then return false end
    
    local target = ctx.target
    if not target or not target:is_valid() then return false end
    
    -- Classification filter
    if ff_mode == 3 then -- Bosses only
        local class = target:get_classification()
        if class ~= 3 then return false end
    elseif ff_mode == 2 then -- Elites+
        local class = target:get_classification()
        if class ~= 1 and class ~= 2 and class ~= 3 then return false end
    end
    
    local ff_duration = Utils.has_faerie_fire(target)
    return ff_duration <= Constants.BALANCE.FAERIE_FIRE_REFRESH
end
function FaerieFire.execute(ctx, state)
    local spell = Spells.Balance.FaerieFireCaster
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P1] Faerie Fire") then
            Utils.log_cast("Faerie Fire", {spec = "Balance"})
            return true
        end
    end
    return nil
end

-- [2] Force of Nature (Treants)
local ForceOfNature = {
    name = "ForceOfNature",
    requires_combat = true,
    requires_enemy = true,
    is_burst = true,
    setting_key = "use_force_of_nature",
    spell = Spells.Balance.ForceOfNature,
}
function ForceOfNature.matches(ctx, state)
    local min_ttd = ctx.settings.force_of_nature_min_ttd or Constants.TTD.FORCE_OF_NATURE_MIN
    return ctx.ttd > min_ttd
end
function ForceOfNature.execute(ctx, state)
    local spell = Spells.Balance.ForceOfNature
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P2] Force of Nature") then
            Utils.log_cast("Force of Nature", {spec = "Balance"})
            return true
        end
    end
    return nil
end

-- [3] Innervate
local Innervate = {
    name = "Innervate",
    setting_key = "balance_use_innervate",
    spell = Spells.SelfUtility.Innervate,
}
function Innervate.matches(ctx, state)
    if ctx.stance ~= Constants.STANCE.MOONKIN then return false end
    if not ctx.in_combat then return false end
    if ctx.me:buff_up(Spells.SelfUtility.Innervate:id()) then return false end
    local threshold = ctx.settings.balance_innervate_mana or 20
    return ctx.mana_pct <= threshold
end
function Innervate.execute(ctx, state)
    local spell = Spells.SelfUtility.Innervate
    if spell:is_learned() and spell:is_usable() then
        if spell:cast_safe(ctx.me, "[P3] Innervate") then
            Utils.log_cast("Innervate", {spec = "Balance"})
            return true
        end
    end
    return nil
end

-- [4] AoE Hurricane
local AoE = {
    name = "AoE",
    requires_combat = true,
    requires_enemy = true,
}
function AoE.matches(ctx, state)
    if ctx.stance ~= Constants.STANCE.MOONKIN then return false end
    if not ctx.in_combat then return false end
    if Utils.has_magic_immunity(ctx.target) then return false end
    local min_targets = ctx.settings.hurricane_min_targets or Constants.AOE.HURRICANE_MIN_TARGETS
    return ctx.enemy_count >= min_targets
end
function AoE.execute(ctx, state)
    -- Pre-cast Barkskin if available
    local barkskin = Spells.SelfUtility.Barkskin
    if barkskin:is_learned() and barkskin:is_usable() 
       and not ctx.me:buff_up(barkskin:id()) then
        barkskin:cast_safe(ctx.me, "[P4] Barkskin (Hurricane prep)")
    end
    
    local spell = Spells.Balance.Hurricane
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P4] Hurricane - AoE") then
            Utils.log_cast("Hurricane", {spec = "Balance"})
            return true
        end
    end
    return nil
end

-- [5] Pull Opener
local Opener = {
    name = "Opener",
    requires_enemy = true,
}
function Opener.matches(ctx, state)
    if ctx.stance ~= Constants.STANCE.MOONKIN then return false end
    if ctx.in_combat then return false end
    return true
end
function Opener.execute(ctx, state)
    -- Try Starfire first (not moving)
    local starfire = Spells.Balance.Starfire
    if starfire:is_learned() and starfire:is_castable_to_unit(ctx.target) then
        if starfire:cast_safe(ctx.target, "[P5] Starfire (Opener)") then
            Utils.log_cast("Starfire", {spec = "Balance"})
            return true
        end
    end
    
    -- Fallback to Wrath
    local wrath = Spells.Balance.Wrath
    if wrath:is_learned() and wrath:is_castable_to_unit(ctx.target) then
        if wrath:cast_safe(ctx.target, "[P5] Wrath (Opener)") then
            Utils.log_cast("Wrath", {spec = "Balance"})
            return true
        end
    end
    
    -- Final fallback: Moonfire if not already applied
    local mf_duration = ctx.target and ctx.target:debuff_remains(Constants.DEBUFF_ID.MOONFIRE) or 0
    if mf_duration <= 0 then
        local moonfire = Spells.Balance.Moonfire
        if moonfire:is_learned() and moonfire:is_castable_to_unit(ctx.target) then
            if moonfire:cast_safe(ctx.target, "[P5] Moonfire (Opener)") then
                Utils.log_cast("Moonfire", {spec = "Balance"})
                return true
            end
        end
    end
    
    return nil
end

-- [6] Main DPS Rotation
local DPS = {
    name = "DPS",
    requires_combat = true,
    requires_enemy = true,
}
function DPS.matches(ctx, state)
    return ctx.stance == Constants.STANCE.MOONKIN and ctx.in_combat
end
function DPS.execute(ctx, state)
    local settings = ctx.settings
    local mana_tier = state.mana_tier
    local has_ng = state.has_natures_grace
    local target = ctx.target
    
    -- Magic immunity check
    if Utils.has_magic_immunity(target) then return nil end
    
    -- Clearcasting: Starfire priority
    if ctx.has_clearcasting and settings.clearcast_starfire ~= false then
        local starfire = Spells.Balance.Starfire
        if starfire:is_learned() and starfire:is_castable_to_unit(target) then
            if starfire:cast_safe(target, "[P7] Starfire (Clearcast)") then
                Utils.log_cast("Starfire (Clearcasting)", {spec = "Balance"})
                return true
            end
        end
    end
    
    -- DoT maintenance
    local dot_refresh = state.dot_refresh_threshold
    
    -- Insect Swarm (Tier 1-2 only)
    if settings.maintain_insect_swarm ~= false and mana_tier <= 2 then
        local is_duration = target and target:debuff_remains(Constants.DEBUFF_ID.INSECT_SWARM) or 0
        if is_duration <= dot_refresh then
            local spell = Spells.Balance.InsectSwarm
            if spell:is_learned() and spell:is_castable_to_unit(target) then
                if spell:cast_safe(target, "[P8] Insect Swarm") then
                    Utils.log_cast("Insect Swarm", {spec = "Balance"})
                    return true
                end
            end
        end
    end
    
    -- Moonfire (Tier 1 only)
    if settings.maintain_moonfire ~= false and mana_tier == 1 then
        local mf_duration = target and target:debuff_remains(Constants.DEBUFF_ID.MOONFIRE) or 0
        if mf_duration <= dot_refresh then
            local spell = Spells.Balance.Moonfire
            if spell:is_learned() and spell:is_castable_to_unit(target) then
                if spell:cast_safe(target, "[P8] Moonfire") then
                    Utils.log_cast("Moonfire", {spec = "Balance"})
                    return true
                end
            end
        end
    end
    
    -- Nature's Grace optimization: Wrath priority during NG
    if has_ng and settings.ng_wrath_priority then
        local wrath = Spells.Balance.Wrath
        if wrath:is_learned() and wrath:is_castable_to_unit(target) then
            if wrath:cast_safe(target, "[P9] Wrath (Nature's Grace)") then
                Utils.log_cast("Wrath (NG)", {spec = "Balance"})
                return true
            end
        end
    end
    
    -- Primary nuke: Starfire
    local starfire = Spells.Balance.Starfire
    if starfire:is_learned() and starfire:is_castable_to_unit(target) then
        if starfire:cast_safe(target, "[P10] Starfire") then
            Utils.log_cast("Starfire", {spec = "Balance"})
            return true
        end
    end
    
    -- Fallback: Wrath
    local wrath = Spells.Balance.Wrath
    if wrath:is_learned() and wrath:is_castable_to_unit(target) then
        if wrath:cast_safe(target, "[P11] Wrath") then
            Utils.log_cast("Wrath", {spec = "Balance"})
            return true
        end
    end
    
    return nil
end

-- ============================================================================
-- REGISTRATION
-- ============================================================================

function BalanceRotation.register()
    local strategies = {
        FaerieFire,
        ForceOfNature,
        Innervate,
        AoE,
        Opener,
        DPS,
    }
    
    RotationEngine.register("balance", strategies, {
        context_builder = build_balance_context,
    })
end

return BalanceRotation
