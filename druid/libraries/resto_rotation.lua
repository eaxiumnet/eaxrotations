-- =============================================================================
-- RESTO (TREE OF LIFE) ROTATION MODULE
-- Ported from Flux AIO - Strategy-based Restoration Healing for TBC
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local Constants = require("libraries/constants")
local Spells = require("libraries/spells")
local Utils = require("libraries/utils")
local RotationEngine = require("libraries/rotation_engine")

local RestoRotation = {}

-- ============================================================================
-- RESTO STATE
-- ============================================================================
local resto_state = {
    tank = nil,
    lowest = nil,
    emergency_count = 0,
    tank_lb_stacks = 0,
    tank_lb_duration = 0,
    cursed_target = nil,
    poisoned_target = nil,
}

-- ============================================================================
-- CONTEXT BUILDER
-- ============================================================================
local function build_resto_context(ctx, state)
    for k, v in pairs(resto_state) do
        state[k] = v
    end
    
    -- Scan healing targets
    local targets = Utils.scan_healing_targets()
    local settings = ctx.settings
    local emergency_hp = settings.resto_emergency_hp or Constants.RESTO.EMERGENCY_HP
    
    -- Reset state
    state.tank = nil
    state.lowest = nil
    state.emergency_count = 0
    state.tank_lb_stacks = 0
    state.tank_lb_duration = 0
    state.cursed_target = nil
    state.poisoned_target = nil
    
    -- Process targets
    for i, entry in ipairs(targets) do
        -- Track lowest HP
        if not state.lowest then
            state.lowest = entry
        end
        
        -- Count emergency targets
        if entry.effective_hp < emergency_hp then
            state.emergency_count = state.emergency_count + 1
        end
        
        -- Track tank
        if entry.is_tank and not state.tank then
            state.tank = entry
            -- Get Lifebloom info
            local lb_dur = entry.unit:buff_remains(Constants.DEBUFF_ID.LIFEBLOOM) or 0
            if lb_dur > 0 then
                state.tank_lb_stacks = entry.unit:get_buff_stacks(33763) or 0
                state.tank_lb_duration = lb_dur
            end
        end
        
        -- Dispel tracking
        local ok, debuffs = pcall(function() return entry.unit:get_debuffs() end)
        if ok and debuffs then
            for _, aura in ipairs(debuffs) do
                if settings.resto_auto_dispel_curse and not state.cursed_target then
                    if aura.type == Constants.DEBUFF_TYPE.CURSE then
                        state.cursed_target = entry
                    end
                end
                if settings.resto_auto_dispel_poison and not state.poisoned_target then
                    if aura.type == Constants.DEBUFF_TYPE.POISON then
                        -- Check if Abolish Poison not already active
                        local abolish = entry.unit:buff_up(2893)
                        if not abolish then
                            state.poisoned_target = entry
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- TREE RESHIFT MIDDLEWARE
-- ============================================================================
local pending_tree_reshift = false

local TreeReshift = {
    name = "TreeReshift",
    priority = 500,
}
function TreeReshift.matches(ctx)
    if not pending_tree_reshift then return false end
    if ctx.stance ~= Constants.STANCE.CASTER then
        pending_tree_reshift = false
        return false
    end
    return true
end
function TreeReshift.execute(ctx)
    local spell = Spells.Forms.TreeOfLifeForm
    if spell:is_learned() and spell:is_usable() then
        pending_tree_reshift = false
        if spell:cast_safe(ctx.me, "[RESTO] Reshifting to Tree") then
            Utils.log_cast("Tree of Life Form", {spec = "Resto"})
            return true
        end
    end
    return nil
end

function RestoRotation.set_pending_reshift()
    pending_tree_reshift = true
end

function RestoRotation.clear_pending_reshift()
    pending_tree_reshift = false
end

-- ============================================================================
-- STRATEGY DEFINITIONS
-- ============================================================================

-- [1] Emergency Swiftmend
local EmergencySwiftmend = {
    name = "EmergencySwiftmend",
    spell = Spells.Healing.Swiftmend,
}
function EmergencySwiftmend.matches(ctx, state)
    if state.emergency_count == 0 then return false end
    local spell = Spells.Healing.Swiftmend
    if not spell:is_learned() then return false end
    
    local target = state.lowest
    return target and target.effective_hp < (ctx.settings.resto_emergency_hp or 30)
       and (target.has_rejuv or target.has_regrowth)
       and spell:is_usable()
end
function EmergencySwiftmend.execute(ctx, state)
    local target = state.lowest
    if not target then return nil end
    local spell = Spells.Healing.Swiftmend
    if spell:is_castable_to_unit(target.unit) then
        if spell:cast_safe(target.unit, "[RESTO] Swiftmend (Emergency)") then
            Utils.log_cast("Swiftmend (Emergency)", {spec = "Resto"})
            return true
        end
    end
    return nil
end

-- [2] Emergency NS + Healing Touch (leaves Tree)
local EmergencyNSHealingTouch = {
    name = "EmergencyNSHealingTouch",
    spell = Spells.Healing.NaturesSwiftness,
}
function EmergencyNSHealingTouch.matches(ctx, state)
    if state.emergency_count == 0 then return false end
    if not ctx.settings.resto_ns_healing_touch then return false end
    local ns = Spells.Healing.NaturesSwiftness
    if not ns:is_learned() then return false end
    return ns:is_usable()
end
function EmergencyNSHealingTouch.execute(ctx, state)
    local target = state.lowest
    if not target then return nil end
    
    -- Flag for reshift
    pending_tree_reshift = true
    
    -- Cast Nature's Swiftness
    local ns = Spells.Healing.NaturesSwiftness
    if ns:is_usable() then
        ns:cast_safe(ctx.me, "[RESTO] Nature's Swiftness")
    end
    
    -- Find best Healing Touch rank
    local deficit = (target.unit:get_health_max() or 1) - (target.unit:get_health() or 0)
    local best_ht = Utils.get_best_healing_touch(deficit)
    
    if best_ht and best_ht:is_learned() and best_ht:is_castable_to_unit(target.unit) then
        if best_ht:cast_safe(target.unit, "[RESTO] Healing Touch (NS Emergency)") then
            Utils.log_cast("NS + Healing Touch", {spec = "Resto"})
            return true
        end
    end
    return nil
end

-- [3] Emergency NS + Regrowth (stays in Tree)
local EmergencyNSRegrowth = {
    name = "EmergencyNSRegrowth",
    spell = Spells.Healing.NaturesSwiftness,
}
function EmergencyNSRegrowth.matches(ctx, state)
    if state.emergency_count == 0 then return false end
    local ns = Spells.Healing.NaturesSwiftness
    if not ns:is_learned() then return false end
    return ns:is_usable()
end
function EmergencyNSRegrowth.execute(ctx, state)
    local target = state.lowest
    if not target then return nil end
    
    -- Cast Nature's Swiftness
    local ns = Spells.Healing.NaturesSwiftness
    if ns:is_usable() then
        ns:cast_safe(ctx.me, "[RESTO] Nature's Swiftness")
    end
    
    -- Cast max rank Regrowth
    local regrowth = Spells.RegrowthRanks[1]
    if regrowth:is_learned() and regrowth:is_castable_to_unit(target.unit) then
        if regrowth:cast_safe(target.unit, "[RESTO] Regrowth (NS Emergency)") then
            Utils.log_cast("NS + Regrowth", {spec = "Resto"})
            return true
        end
    end
    return nil
end

-- [4] Emergency Barkskin
local EmergencyBarkskin = {
    name = "EmergencyBarkskin",
    is_gcd_gated = false,
    requires_combat = true,
}
function EmergencyBarkskin.matches(ctx, state)
    local emergency_hp = ctx.settings.resto_emergency_hp or Constants.RESTO.EMERGENCY_HP
    return ctx.hp < emergency_hp and ctx.me:buff_up(Spells.SelfUtility.Barkskin:id()) == false
end
function EmergencyBarkskin.execute(ctx, state)
    local spell = Spells.SelfUtility.Barkskin
    if spell:is_learned() and spell:is_usable() then
        if spell:cast_safe(ctx.me, "[RESTO] Barkskin (Emergency)") then
            Utils.log_cast("Barkskin", {spec = "Resto"})
            return true
        end
    end
    return nil
end

-- [5] Tranquility (AoE emergency)
local Tranquility = {
    name = "Tranquility",
    spell = Spells.Healing.Tranquility,
}
function Tranquility.matches(ctx, state)
    if state.emergency_count < 3 then return false end
    local spell = Spells.Healing.Tranquility
    if not spell:is_learned() then return false end
    return spell:is_usable()
end
function Tranquility.execute(ctx, state)
    local spell = Spells.Healing.Tranquility
    if spell:is_usable() then
        if spell:cast_safe(ctx.me, "[RESTO] Tranquility (Raid Emergency)") then
            Utils.log_cast("Tranquility", {spec = "Resto"})
            return true
        end
    end
    return nil
end

-- [6] Lifebloom Tank
local LifebloomTank = {
    name = "LifebloomTank",
    spell = Spells.Healing.Lifebloom,
}
function LifebloomTank.matches(ctx, state)
    if not state.tank then return false end
    if not ctx.settings.resto_prioritize_tank then return false end
    local spell = Spells.Healing.Lifebloom
    if not spell:is_learned() then return false end
    
    local stacks = state.tank_lb_stacks
    local duration = state.tank_lb_duration
    local refresh = ctx.settings.resto_lifebloom_refresh or Constants.RESTO.LIFEBLOOM_REFRESH
    
    -- Cast if no Lifebloom, building stacks, or 3-stack expiring
    if stacks == 0 then return true end
    if stacks < 3 then return true end
    return duration > 0 and duration <= refresh
end
function LifebloomTank.execute(ctx, state)
    local tank = state.tank
    if not tank then return nil end
    local spell = Spells.Healing.Lifebloom
    if spell:is_castable_to_unit(tank.unit) then
        local action = state.tank_lb_stacks >= 3 and "Refresh" or "Build"
        if spell:cast_safe(tank.unit, "[RESTO] Lifebloom (Tank " .. action .. ")") then
            Utils.log_cast("Lifebloom (Tank)", {spec = "Resto"})
            return true
        end
    end
    return nil
end

-- [7] Swiftmend Urgent
local SwiftmendUrgent = {
    name = "SwiftmendUrgent",
    spell = Spells.Healing.Swiftmend,
}
function SwiftmendUrgent.matches(ctx, state)
    local spell = Spells.Healing.Swiftmend
    if not spell:is_learned() then return false end
    
    local threshold = ctx.settings.resto_swiftmend_hp or Constants.RESTO.SWIFTMEND_HP
    local target = Utils.get_lowest_hp(Utils.scan_healing_targets(), threshold)
    return target and (target.has_rejuv or target.has_regrowth) and spell:is_usable()
end
function SwiftmendUrgent.execute(ctx, state)
    local threshold = ctx.settings.resto_swiftmend_hp or Constants.RESTO.SWIFTMEND_HP
    local target = Utils.get_lowest_hp(Utils.scan_healing_targets(), threshold)
    if not target then return nil end
    
    local spell = Spells.Healing.Swiftmend
    if spell:is_castable_to_unit(target.unit) then
        if spell:cast_safe(target.unit, "[RESTO] Swiftmend (Urgent)") then
            Utils.log_cast("Swiftmend", {spec = "Resto"})
            return true
        end
    end
    return nil
end

-- [8] Rejuvenation Tank
local RejuvTank = {
    name = "RejuvTank",
    spell = Spells.RejuvenationRanks[1],
}
function RejuvTank.matches(ctx, state)
    if not state.tank then return false end
    if not ctx.settings.resto_prioritize_tank then return false end
    return not state.tank.has_rejuv
end
function RejuvTank.execute(ctx, state)
    local tank = state.tank
    if not tank then return nil end
    local spell = Spells.RejuvenationRanks[1]
    if spell:is_learned() and spell:is_castable_to_unit(tank.unit) then
        if spell:cast_safe(tank.unit, "[RESTO] Rejuvenation (Tank)") then
            Utils.log_cast("Rejuvenation (Tank)", {spec = "Resto"})
            return true
        end
    end
    return nil
end

-- [9] Regrowth Tank
local RegrowthTank = {
    name = "RegrowthTank",
    spell = Spells.RegrowthRanks[1],
}
function RegrowthTank.matches(ctx, state)
    if not state.tank then return false end
    if not ctx.settings.resto_prioritize_tank then return false end
    if state.tank.has_regrowth then return false end
    
    local mana_conserve = ctx.settings.resto_mana_conserve or Constants.RESTO.MANA_CONSERVE
    if ctx.mana_pct < mana_conserve then return false end
    
    local spell = Spells.RegrowthRanks[1]
    return spell:is_learned()
end
function RegrowthTank.execute(ctx, state)
    local tank = state.tank
    if not tank then return nil end
    local spell = Spells.RegrowthRanks[1]
    if spell:is_castable_to_unit(tank.unit) then
        if spell:cast_safe(tank.unit, "[RESTO] Regrowth (Tank)") then
            Utils.log_cast("Regrowth (Tank)", {spec = "Resto"})
            return true
        end
    end
    return nil
end

-- [10] Regrowth Low HP
local RegrowthLow = {
    name = "RegrowthLow",
    spell = Spells.RegrowthRanks[1],
}
function RegrowthLow.matches(ctx, state)
    local threshold = ctx.settings.resto_standard_heal_hp or Constants.RESTO.STANDARD_HEAL_HP
    local mana_conserve = ctx.settings.resto_mana_conserve or Constants.RESTO.MANA_CONSERVE
    if ctx.mana_pct < mana_conserve then return false end
    
    local targets = Utils.scan_healing_targets()
    local target = Utils.get_lowest_hp(targets, threshold)
    return target and not target.has_regrowth
end
function RegrowthLow.execute(ctx, state)
    local threshold = ctx.settings.resto_standard_heal_hp or Constants.RESTO.STANDARD_HEAL_HP
    local targets = Utils.scan_healing_targets()
    local target = Utils.get_lowest_hp(targets, threshold)
    if not target then return nil end
    
    -- Use rank optimizer if enabled
    if ctx.settings.resto_use_rank_optimization then
        local deficit = (target.unit:get_health_max() or 1) - (target.unit:get_health() or 0)
        local best_regrowth = Utils.get_best_regrowth(deficit)
        if best_regrowth and best_regrowth:is_learned() and best_regrowth:is_castable_to_unit(target.unit) then
            if best_regrowth:cast_safe(target.unit, "[RESTO] Regrowth (Rank Opt)") then
                Utils.log_cast("Regrowth (Rank Optimized)", {spec = "Resto"})
                return true
            end
        end
    else
        local spell = Spells.RegrowthRanks[1]
        if spell:is_castable_to_unit(target.unit) then
            if spell:cast_safe(target.unit, "[RESTO] Regrowth") then
                Utils.log_cast("Regrowth", {spec = "Resto"})
                return true
            end
        end
    end
    return nil
end

-- [11] Rejuvenation Spread
local RejuvSpread = {
    name = "RejuvSpread",
    spell = Spells.RejuvenationRanks[1],
}
function RejuvSpread.matches(ctx, state)
    local threshold = ctx.settings.resto_proactive_hp or Constants.RESTO.PROACTIVE_HP
    local targets = Utils.scan_healing_targets()
    for _, t in ipairs(targets) do
        if t.effective_hp < threshold and not t.has_rejuv then
            return true
        end
    end
    return false
end
function RejuvSpread.execute(ctx, state)
    local threshold = ctx.settings.resto_proactive_hp or Constants.RESTO.PROACTIVE_HP
    local targets = Utils.scan_healing_targets()
    for _, t in ipairs(targets) do
        if t.effective_hp < threshold and not t.has_rejuv then
            local spell = Spells.RejuvenationRanks[1]
            if spell:is_learned() and spell:is_castable_to_unit(t.unit) then
                if spell:cast_safe(t.unit, "[RESTO] Rejuvenation (Spread)") then
                    Utils.log_cast("Rejuvenation (Spread)", {spec = "Resto"})
                    return true
                end
            end
        end
    end
    return nil
end

-- [12] Dispel Curse
local DispelCurse = {
    name = "DispelCurse",
    spell = Spells.Utility.RemoveCurse,
}
function DispelCurse.matches(ctx, state)
    return state.cursed_target ~= nil
end
function DispelCurse.execute(ctx, state)
    local target = state.cursed_target
    if not target then return nil end
    local spell = Spells.Utility.RemoveCurse
    if spell:is_learned() and spell:is_castable_to_unit(target.unit) then
        if spell:cast_safe(target.unit, "[RESTO] Remove Curse") then
            Utils.log_cast("Remove Curse", {spec = "Resto"})
            return true
        end
    end
    return nil
end

-- [13] Dispel Poison
local DispelPoison = {
    name = "DispelPoison",
    spell = Spells.Utility.AbolishPoison,
}
function DispelPoison.matches(ctx, state)
    return state.poisoned_target ~= nil
end
function DispelPoison.execute(ctx, state)
    local target = state.poisoned_target
    if not target then return nil end
    local spell = Spells.Utility.AbolishPoison
    if spell:is_learned() and spell:is_castable_to_unit(target.unit) then
        if spell:cast_safe(target.unit, "[RESTO] Abolish Poison") then
            Utils.log_cast("Abolish Poison", {spec = "Resto"})
            return true
        end
    end
    return nil
end

-- ============================================================================
-- REGISTRATION
-- ============================================================================

function RestoRotation.register()
    -- Register tree reshift middleware
    RotationEngine.register_middleware(TreeReshift)
    
    -- Register resto strategies
    local strategies = {
        EmergencySwiftmend,
        EmergencyNSHealingTouch,
        EmergencyNSRegrowth,
        EmergencyBarkskin,
        Tranquility,
        LifebloomTank,
        SwiftmendUrgent,
        RejuvTank,
        RegrowthTank,
        RegrowthLow,
        RejuvSpread,
        DispelCurse,
        DispelPoison,
    }
    
    RotationEngine.register("resto", strategies, {
        context_builder = build_resto_context,
    })
end

return RestoRotation
