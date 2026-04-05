-- =============================================================================
-- BEAR (FERAL TANK) ROTATION MODULE
-- Ported from Flux AIO - Strategy-based Feral Bear Tank for TBC
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local Constants = require("libraries/constants")
local Spells = require("libraries/spells")
local Utils = require("libraries/utils")
local RotationEngine = require("libraries/rotation_engine")

-- Hot-path API caching (EAX pattern)
local _core_time = core.time

local BearRotation = {}

-- ============================================================================
-- RAGE COSTS
-- ============================================================================
local RAGE_COST_MAUL = 15
local RAGE_COST_MANGLE = 20
local RAGE_COST_SWIPE = 15
local RAGE_COST_LACERATE = 13
local RAGE_COST_DEMO_ROAR = 10

-- ============================================================================
-- BEAR STATE (computed once per frame)
-- ============================================================================
local bear_state = {
    maul_queued = false,
    maul_confirmed = false,
    maul_dequeue_logged = false,
    lacerate_stacks = 0,
    lacerate_duration = 0,
    nearby_elites = 0,
    nearby_bosses = 0,
    nearby_trash = 0,
    tab_target_desired = nil,
    tab_target_attempts = 0,
    last_target_guid = nil,
    manual_target_time = 0,
    last_demo_roar_cast = 0,
    last_ff_cast = 0,
    last_swipe_aoe_cast = 0,
    cc_nearby = false,
    has_frenzied_regen = false,
}

-- ============================================================================
-- CONTEXT BUILDER
-- ============================================================================
local function build_bear_context(ctx, state)
    for k, v in pairs(bear_state) do
        state[k] = v
    end
    
    -- Manual target detection
    local target = ctx.target
    if target and target:is_valid() then
        local current_guid = nil
        local ok, guid = pcall(function() return target:npc_id() end)
        if ok then current_guid = guid end
        
        if current_guid ~= state.last_target_guid then
            if state.last_target_guid and not state.tab_target_desired then
                state.manual_target_time = _core_time()
            end
            state.last_target_guid = current_guid
        end
    end
    
    -- Maul queue state
    if state.maul_queued then
        -- Simplified: assume confirmed after short delay
        if not state.maul_confirmed then
            state.maul_confirmed = true
        end
    end
    
    -- Lacerate info
    if target and target:is_valid() then
        state.lacerate_stacks, state.lacerate_duration = Utils.get_lacerate_info(target)
    end
    
    -- Nearby enemies
    state.nearby_elites, state.nearby_bosses, state.nearby_trash = Utils.count_nearby_enemies(5, false)
    
    -- CC nearby check
    state.cc_nearby = ctx.settings.swipe_cc_check ~= false and Utils.has_breakable_cc_nearby(10) or false
    
    -- Frenzied Regen check
    state.has_frenzied_regen = ctx.me:buff_up(Spells.Bear.FrenziedRegeneration:id()) or false
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function get_swipe_threshold(ctx, state)
    local swipe_min = ctx.settings.swipe_min_targets or Constants.BEAR.DEFAULT_SWIPE_TARGETS
    local base = swipe_min <= 1 and 3 or swipe_min
    if state.nearby_bosses > 0 or state.nearby_elites > 0 then
        return base + 1
    end
    return base
end

local function should_hold_for_mangle()
    local mangle = Spells.Bear.MangleBear
    if not mangle:is_learned() then return false end
    local cd = mangle:cooldown_remains() or 0
    return cd > 0 and cd <= Constants.BEAR.MANGLE_HOLD_WINDOW
end

local function would_starve_maul(ctx, state, rage_cost)
    if ctx.has_clearcasting then return false end
    return state.maul_confirmed and (ctx.rage - rage_cost) < RAGE_COST_MAUL
end

local function would_starve_mangle(ctx, rage_cost)
    if ctx.has_clearcasting then return false end
    local mangle = Spells.Bear.MangleBear
    local cd = mangle:cooldown_remains() or 0
    if cd <= 0 then
        if ctx.rage >= RAGE_COST_MANGLE then return false end
        return (ctx.rage - rage_cost) < RAGE_COST_MANGLE
    end
    if cd >= 0.5 then return false end
    if (ctx.rage - rage_cost) >= RAGE_COST_MANGLE then return false end
    return true
end

-- ============================================================================
-- STRATEGY DEFINITIONS
-- ============================================================================

-- [1] Frenzied Regeneration (Emergency heal)
local FrenziedRegen = {
    name = "FrenziedRegen",
    is_gcd_gated = false,
    is_defensive = true,
    requires_combat = true,
    setting_key = "use_frenzied_regen",
    spell = Spells.Bear.FrenziedRegeneration,
}
function FrenziedRegen.matches(ctx, state)
    if ctx.rage < 10 then return false end
    if ctx.hp <= (ctx.settings.emergency_heal_hp or 30) then return true end
    if ctx.enemy_count <= 1 and ctx.ttd > 0 and ctx.ttd < 8 then return false end
    return ctx.hp <= Constants.BEAR.FRENZIED_PROACTIVE_HP 
       and ctx.rage >= Constants.BEAR.FRENZIED_PROACTIVE_RAGE
end
function FrenziedRegen.execute(ctx, state)
    local spell = Spells.Bear.FrenziedRegeneration
    if spell:is_learned() and spell:is_usable() then
        if spell:cast_safe(ctx.me, "[P2] Frenzied Regeneration") then
            Utils.log_cast("Frenzied Regeneration", {spec = "Bear"})
            return true
        end
    end
    return nil
end

-- [2] Enrage (Rage generation)
local Enrage = {
    name = "Enrage",
    is_gcd_gated = false,
    requires_combat = true,
    setting_key = "use_enrage",
    spell = Spells.Bear.Enrage,
}
function Enrage.matches(ctx, state)
    local threshold = ctx.settings.enrage_rage_threshold or Constants.BEAR.ENRAGE_RAGE_THRESHOLD
    if ctx.rage >= threshold then return false end
    
    -- Skip on boss without Frenzied Regen active
    if ctx.is_boss and not state.has_frenzied_regen then return false end
    
    -- HP safety
    if ctx.hp < Constants.BEAR.ENRAGE_HP_SAFETY and not state.has_frenzied_regen then
        return false
    end
    
    -- Fight ending
    if ctx.enemy_count <= 1 and ctx.ttd > 0 and ctx.ttd < 8 then return false end
    
    return true
end
function Enrage.execute(ctx, state)
    local spell = Spells.Bear.Enrage
    if spell:is_learned() and spell:is_usable() then
        if spell:cast_safe(ctx.me, "[Bear] Enrage") then
            Utils.log_cast("Enrage", {spec = "Bear"})
            return true
        end
    end
    return nil
end

-- [3] Growl (Single-target taunt)
local Growl = {
    name = "Growl",
    is_gcd_gated = false,
    requires_combat = true,
    requires_enemy = true,
    setting_key = "use_growl",
    spell = Spells.Bear.Growl,
}
function Growl.matches(ctx, state)
    if ctx.settings.bear_no_taunt then return false end
    if ctx.combat_time < 1.5 then return false end
    
    local threat = Utils.get_threat_status(ctx.target)
    if threat >= 2 then return false end  -- Already tanking
    
    -- Don't taunt mobs another tank is handling
    if Utils.is_other_tank_target(ctx.target) then return false end
    
    return true
end
function Growl.execute(ctx, state)
    local spell = Spells.Bear.Growl
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P3] Growl") then
            Utils.log_cast("Growl", {spec = "Bear"})
            return true
        end
    end
    return nil
end

-- [4] Challenging Roar (AoE taunt)
local ChallengingRoar = {
    name = "ChallengingRoar",
    is_gcd_gated = false,
    requires_combat = true,
    requires_enemy = true,
    setting_key = "use_challenging_roar",
    spell = Spells.Bear.ChallengingRoar,
}
function ChallengingRoar.matches(ctx, state)
    if ctx.settings.bear_no_taunt then return false end
    local croar_range = ctx.settings.croar_range or Constants.BEAR.DEFAULT_CROAR_RANGE
    local elites, bosses = Utils.count_nearby_enemies(croar_range, true)
    local min_bosses = ctx.settings.croar_min_bosses or Constants.BEAR.DEFAULT_CROAR_MIN_BOSSES
    local min_elites = ctx.settings.croar_min_elites or Constants.BEAR.DEFAULT_CROAR_MIN_ELITES
    return bosses >= min_bosses or elites >= min_elites
end
function ChallengingRoar.execute(ctx, state)
    local spell = Spells.Bear.ChallengingRoar
    if spell:is_learned() and spell:is_usable() then
        if spell:cast_safe(ctx.me, "[Bear] Challenging Roar") then
            Utils.log_cast("Challenging Roar", {spec = "Bear"})
            return true
        end
    end
    return nil
end

-- [5] Lacerate Urgent Refresh
local LacerateUrgent = {
    name = "LacerateUrgent",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    spell = Spells.Bear.Lacerate,
}
function LacerateUrgent.matches(ctx, state)
    if not ctx.settings.maintain_lacerate then return false end
    return state.lacerate_stacks >= Constants.BEAR.LACERATE_MAX_STACKS
       and state.lacerate_duration > 0
       and state.lacerate_duration <= Constants.BEAR.LACERATE_URGENT_REFRESH
end
function LacerateUrgent.execute(ctx, state)
    local spell = Spells.Bear.Lacerate
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if ctx.has_clearcasting or ctx.rage >= RAGE_COST_LACERATE then
            if not would_starve_maul(ctx, state, RAGE_COST_LACERATE) 
               and not would_starve_mangle(ctx, RAGE_COST_LACERATE) then
                if spell:cast_safe(ctx.target, "[P5] Lacerate URGENT") then
                    Utils.log_cast("Lacerate (Urgent)", {spec = "Bear"})
                    return true
                end
            end
        end
    end
    return nil
end

-- [6] Faerie Fire
local FaerieFire = {
    name = "FaerieFire",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
}
function FaerieFire.matches(ctx, state)
        local time_since_ff = _core_time() - state.last_ff_cast
    if time_since_ff < Constants.BEAR.FF_THROTTLE then return false end
    
    local ff_duration = Utils.has_faerie_fire(ctx.target)
    return ff_duration <= 3
end
function FaerieFire.execute(ctx, state)
    local spell = Spells.Cat.FaerieFire  -- Same spell ID for both
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        state.last_ff_cast = _core_time()
        if spell:cast_safe(ctx.target, "[P7] Faerie Fire") then
            Utils.log_cast("Faerie Fire", {spec = "Bear"})
            return true
        end
    end
    return nil
end

-- [7] Mangle (Main threat ability)
local Mangle = {
    name = "Mangle",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    spell = Spells.Bear.MangleBear,
}
function Mangle.matches(ctx, state)
    if ctx.target_phys_immune then return false end
    if ctx.has_clearcasting then return true end
    local threshold = ctx.settings.mangle_rage_threshold or RAGE_COST_MANGLE
    return ctx.rage >= threshold
end
function Mangle.execute(ctx, state)
    local spell = Spells.Bear.MangleBear
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if not would_starve_maul(ctx, state, RAGE_COST_MANGLE) then
            if spell:cast_safe(ctx.target, "[P9] Mangle") then
                Utils.log_cast("Mangle (Bear)", {spec = "Bear"})
                return true
            end
        end
    end
    return nil
end

-- [8] Swipe AoE
local SwipeAoE = {
    name = "SwipeAoE",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    spell = Spells.Bear.Swipe,
}
function SwipeAoE.matches(ctx, state)
    local aoe_threshold = get_swipe_threshold(ctx, state)
    if ctx.enemy_count < aoe_threshold then return false end
    
    -- CC safety
    if state.cc_nearby then return false end
    
    if not ctx.has_clearcasting then
        local threshold = ctx.settings.swipe_rage_threshold or Constants.BEAR.DEFAULT_SWIPE_RAGE
        if ctx.rage < threshold then return false end
        if would_starve_maul(ctx, state, RAGE_COST_SWIPE) then return false end
    end
    
    return true
end
function SwipeAoE.execute(ctx, state)
    local spell = Spells.Bear.Swipe
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        state.last_swipe_aoe_cast = _core_time()
        if spell:cast_safe(ctx.target, "[P8] Swipe AoE") then
            Utils.log_cast("Swipe (AoE)", {spec = "Bear"})
            return true
        end
    end
    return nil
end

-- [9] Demoralizing Roar
local DemoRoar = {
    name = "DemoRoar",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    setting_key = "maintain_demo_roar",
    spell = Spells.Bear.DemoralizingRoar,
}
function DemoRoar.matches(ctx, state)
        local time_since_demo = _core_time() - state.last_demo_roar_cast
    if time_since_demo < Constants.BEAR.DEMO_ROAR_THROTTLE then return false end
    
    -- Rage reservation
    if not ctx.is_boss then
        if would_starve_maul(ctx, state, RAGE_COST_DEMO_ROAR) then return false end
        if would_starve_mangle(ctx, RAGE_COST_DEMO_ROAR) then return false end
    end
    
    -- Min enemies check
    local demo_range = ctx.settings.demo_roar_range or Constants.BEAR.DEFAULT_DEMO_ROAR_RANGE
    local elites, bosses, trash = Utils.count_nearby_enemies(demo_range, false)
    local min_bosses = ctx.settings.demo_roar_min_bosses or Constants.BEAR.DEFAULT_DEMO_ROAR_MIN_BOSSES
    local min_elites = ctx.settings.demo_roar_min_elites or Constants.BEAR.DEFAULT_DEMO_ROAR_MIN_ELITES
    local min_trash = ctx.settings.demo_roar_min_trash or Constants.BEAR.DEFAULT_DEMO_ROAR_MIN_TRASH
    if bosses < min_bosses and elites < min_elites and trash < min_trash then return false end
    
    -- TTD check
    if ctx.enemy_count <= 1 and ctx.ttd < Constants.BEAR.DEMO_ROAR_MIN_TTD then return false end
    
    -- Check existing debuff
    local demo_duration = ctx.target and ctx.target:debuff_remains(Constants.DEBUFF_ID.DEMO_ROAR) or 0
    return demo_duration <= Constants.BEAR.DEMO_ROAR_REFRESH
end
function DemoRoar.execute(ctx, state)
    local spell = Spells.Bear.DemoralizingRoar
    if spell:is_learned() and spell:is_usable() then
        state.last_demo_roar_cast = _core_time()
        if spell:cast_safe(ctx.me, "[P7] Demoralizing Roar") then
            Utils.log_cast("Demoralizing Roar", {spec = "Bear"})
            return true
        end
    end
    return nil
end

-- [10] Lacerate Build
local LacerateBuild = {
    name = "LacerateBuild",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    spell = Spells.Bear.Lacerate,
}
function LacerateBuild.matches(ctx, state)
    if not ctx.settings.maintain_lacerate then return false end
    if not ctx.has_clearcasting then
        if ctx.rage < RAGE_COST_LACERATE then return false end
        if would_starve_maul(ctx, state, RAGE_COST_LACERATE) then return false end
        if would_starve_mangle(ctx, RAGE_COST_LACERATE) then return false end
    end
    
    local aoe_threshold = get_swipe_threshold(ctx, state)
    if ctx.enemy_count >= aoe_threshold then return false end
    
    -- Building stacks
    if state.lacerate_stacks < Constants.BEAR.LACERATE_MAX_STACKS then
        return state.lacerate_stacks == 0 or state.lacerate_duration <= Constants.BEAR.LACERATE_BUILD_REFRESH
    end
    
    -- At 5 stacks, refresh as filler
    if should_hold_for_mangle() then return false end
    return state.lacerate_duration > Constants.BEAR.LACERATE_URGENT_REFRESH
       and state.lacerate_duration <= Constants.BEAR.LACERATE_SWIPE_THRESHOLD
end
function LacerateBuild.execute(ctx, state)
    local spell = Spells.Bear.Lacerate
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P11] Lacerate") then
            Utils.log_cast("Lacerate", {spec = "Bear"})
            return true
        end
    end
    return nil
end

-- [11] Swipe Single-Target
local Swipe = {
    name = "Swipe",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    spell = Spells.Bear.Swipe,
}
function Swipe.matches(ctx, state)
    local aoe_threshold = get_swipe_threshold(ctx, state)
    if ctx.enemy_count >= aoe_threshold then return false end
    if should_hold_for_mangle() then return false end
    if state.cc_nearby then return false end
    
    if not ctx.has_clearcasting then
        local threshold = ctx.settings.swipe_rage_threshold or Constants.BEAR.DEFAULT_SWIPE_RAGE
        if ctx.rage < threshold then return false end
        if would_starve_maul(ctx, state, RAGE_COST_SWIPE) then return false end
    end
    
    return true
end
function Swipe.execute(ctx, state)
    local spell = Spells.Bear.Swipe
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P12] Swipe") then
            Utils.log_cast("Swipe", {spec = "Bear"})
            return true
        end
    end
    return nil
end

-- [12] Maul (Off-GCD rage dump)
local Maul = {
    name = "Maul",
    is_gcd_gated = false,
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    requires_in_range = true,
    spell = Spells.Bear.Maul,
}
function Maul.matches(ctx, state)
    if state.maul_confirmed then return false end
    local threshold = ctx.settings.maul_rage_threshold or Constants.BEAR.DEFAULT_MAUL_RAGE
    return ctx.rage >= threshold
end
function Maul.execute(ctx, state)
    state.maul_queued = true
    state.maul_dequeue_logged = false
    local spell = Spells.Bear.Maul
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P13] Maul") then
            return true
        end
    end
    return nil
end

-- ============================================================================
-- REGISTRATION
-- ============================================================================

function BearRotation.register()
    local strategies = {
        FrenziedRegen,
        Enrage,
        Growl,
        ChallengingRoar,
        LacerateUrgent,
        FaerieFire,
        Mangle,
        SwipeAoE,
        DemoRoar,
        LacerateBuild,
        Swipe,
        Maul,
    }
    
    RotationEngine.register("bear", strategies, {
        context_builder = build_bear_context,
    })
end

return BearRotation
