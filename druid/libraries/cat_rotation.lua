-- =============================================================================
-- CAT (FERAL DPS) ROTATION MODULE
-- Ported from Flux AIO - Strategy-based Feral Cat DPS for TBC
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local Constants = require("libraries/constants")
local Spells = require("libraries/spells")
local Utils = require("libraries/utils")
local RotationEngine = require("libraries/rotation_engine")

-- Hot-path API caching (EAX pattern)
local _core_time = core.time

local CatRotation = {}

-- ============================================================================
-- ENERGY COSTS (dynamically resolved)
-- ============================================================================
local ENERGY_COST_RIP = 30
local ENERGY_COST_RAKE = 35
local ENERGY_COST_MANGLE = 40
local ENERGY_COST_SHRED = 42
local ENERGY_COST_BITE = 35
local ENERGY_COST_RAVAGE = 60
local ENERGY_COST_TIGERS_FURY = 30

-- Tick optimization thresholds
local TICK_OPT_MANGLE_LOW = 2 * ENERGY_COST_MANGLE - 20
local TICK_OPT_MANGLE_HIGH = ENERGY_COST_MANGLE + ENERGY_COST_SHRED - 21
local TICK_OPT_THRESHOLD = 1.0

-- ============================================================================
-- CAT STATE (computed once per frame)
-- ============================================================================
local cat_state = {
    has_wolfshead = false,
    can_powershift = false,
    energy_tick_soon = false,
    cat_form_cost = 0,
    shifts_remaining = 0,
    mangle_duration = 0,
    rip_duration = 0,
    rake_duration = 0,
    rip_now = false,
    mangle_now = false,
    rip_needs_refresh_soon = false,
    target_qualifies_for_rip = true,
    rip_refresh_threshold = 0,
    energy_after_shift = 0,
    wolfshead_bonus = 0,
    pooling = false,
    prefer_mangle_for_tick = false,
    tf_queued = false,
    tf_queued_at = 0,
}

-- ============================================================================
-- CONTEXT BUILDER (called once per frame)
-- ============================================================================
local function build_cat_context(ctx, state)
    -- Copy to state table
    for k, v in pairs(cat_state) do
        state[k] = v
    end
    
    local settings = ctx.settings
    local cp = ctx.cp or 0
    local energy = ctx.energy or 0
    local ttd = ctx.ttd or 999
    
    -- Reset pooling flag
    state.pooling = false
    
    -- Wolfshead detection
    state.has_wolfshead = Utils.has_wolfshead_helm()
    state.wolfshead_bonus = state.has_wolfshead and Constants.POWERSHIFT.WOLFSHEAD_BONUS or 0
    state.energy_after_shift = Constants.POWERSHIFT.FUROR_ENERGY + state.wolfshead_bonus
    
    -- Powershift viability
    local auto_ps = settings.auto_powershift or false
    local ps_min_mana = settings.powershift_min_mana or 25
    local form_cost = Utils.get_form_cost(768) -- Cat Form
    state.cat_form_cost = form_cost
    -- Defensive nil checks for mana values
    local mana_pct = ctx.mana_pct or 100
    local mana = ctx.mana or 0
    state.can_powershift = auto_ps and mana_pct >= ps_min_mana
        and (form_cost == 0 or mana >= form_cost)
    state.shifts_remaining = (form_cost > 0) and math.floor(mana / form_cost) or 0
    
    -- Energy tick tracking
    Utils.energy_tick:update(energy, ctx.stance)
    state.energy_tick_soon = Utils.energy_tick:should_delay()
    
    -- Debuff durations
    state.mangle_duration = Utils.has_mangle(ctx.target)
    state.rip_duration = ctx.target and ctx.target:debuff_remains(Constants.DEBUFF_ID.RIP) or 0
    state.rake_duration = ctx.target and ctx.target:debuff_remains(Constants.DEBUFF_ID.RAKE) or 0
    
    -- Target qualification for Rip (elites/bosses only if setting enabled)
    state.target_qualifies_for_rip = true
    if settings.rip_only_elites then
        local classification = ctx.target and ctx.target:get_classification() or 0
        state.target_qualifies_for_rip = classification == 3 or classification == 1 or classification == 2
    end
    
    -- Rip refresh threshold (dynamic)
    state.rip_refresh_threshold = (settings.rip_refresh or 0) + (ctx.gcd_remains or 0)
    
    -- Rip now decision
    local rip_min_cp = settings.rip_min_cp or 4
    state.rip_now = settings.maintain_rip and state.target_qualifies_for_rip
        and cp >= rip_min_cp and ttd >= Constants.TTD.RIP_MIN
        and not ctx.target_phys_immune
        and (state.rip_duration == 0 or state.rip_duration < state.rip_refresh_threshold)
    
    -- Defer Rip if Mangle debuff missing and we can apply it
    if state.rip_now and state.mangle_duration == 0 then
        local mangle = Spells.Cat.MangleCat
        if mangle:is_learned() and (energy >= ENERGY_COST_MANGLE or ctx.has_clearcasting) then
            state.rip_now = false
        end
    end
    
    -- Rip needs refresh soon (prevent Bite from blocking Rip)
    state.rip_needs_refresh_soon = not state.rip_now and settings.maintain_rip
        and state.target_qualifies_for_rip
        and not ctx.target_phys_immune and ttd >= Constants.TTD.RIP_MIN
        and state.rip_duration > 0 and state.rip_duration < rip_min_cp * 1.5
    
    -- Tick optimization: prefer Mangle over Shred
    state.prefer_mangle_for_tick = settings.cat_tick_optimization
        and energy >= TICK_OPT_MANGLE_LOW and energy <= TICK_OPT_MANGLE_HIGH
        and Utils.energy_tick.confident and Utils.energy_tick:time_until_next() < TICK_OPT_THRESHOLD
    
    -- Mangle debuff needed
    state.mangle_now = not state.rip_now and state.mangle_duration == 0 and not ctx.target_phys_immune
    
    -- Tiger's Fury queue tracking
    if state.tf_queued then
        if ctx.me:buff_up(Constants.BUFF_ID.TIGERS_FURY) then
            state.tf_queued = false
        elseif _core_time() - state.tf_queued_at > 5.0 then
            state.tf_queued = false  -- Safety timeout
        end
    end
end

-- ============================================================================
-- STRATEGY DEFINITIONS
-- ============================================================================

-- Helper: Safe powershift cast
local function safe_powershift(ctx, state, label)
    local form = Spells.Forms.CatForm
    if form:is_learned() then
        Utils.energy_tick:record_shift()
        if form:cast_safe(ctx.me, label) then
            Utils.log_cast("Powershift: " .. label, {spec = "Cat"})
            return true
        end
    end
    return false
end

-- Helper: Will reach energy soon?
local function will_reach_energy(target_energy, ctx)
    local current = ctx.energy or 0
    if current >= target_energy then return true end
    -- Approximate: 10 energy per second
    local time_needed = (target_energy - current) / 10
    return time_needed <= 0.5
end

-- [P0] Critical Energy Shift
local CriticalEnergyShift = {
    name = "CriticalEnergyShift",
    requires_combat = true,
    requires_enemy = true,
    spell = Spells.Forms.CatForm,
}
function CriticalEnergyShift.matches(ctx, state)
    if ctx.has_clearcasting then return false end
    return (ctx.energy or 0) < Constants.ENERGY.CRITICAL and state.can_powershift
end
function CriticalEnergyShift.execute(ctx, state)
    if will_reach_energy(Constants.ENERGY.CRITICAL + 10, ctx) then return nil end
    return safe_powershift(ctx, state, "[P0] Critical Energy Shift")
end

-- [P1] Faerie Fire
local FaerieFire = {
    name = "FaerieFire",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    spell = Spells.Cat.FaerieFire,
}
function FaerieFire.matches(ctx, state)
    local ff_mode = ctx.settings.maintain_faerie_fire
    if ff_mode == 4 or ff_mode == false or ff_mode == nil then return false end
    
    local target = ctx.target
    if not target or not target:is_valid() then return false end
    
    -- Check classification filter
    if ff_mode == 3 then -- Bosses only
        local class = target:get_classification()
        if class ~= 3 then return false end
    elseif ff_mode == 2 then -- Elites+
        local class = target:get_classification()
        if class ~= 1 and class ~= 2 and class ~= 3 then return false end
    end
    
    local ff_duration = Utils.has_faerie_fire(target)
    return ff_duration <= 3  -- Refresh at 3s
end
function FaerieFire.execute(ctx, state)
    local spell = Spells.Cat.FaerieFire
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[FF] Faerie Fire") then
            Utils.log_cast("Faerie Fire", {spec = "Cat"})
            return true
        end
    end
    return nil
end

-- [P2] Rip (Finisher)
local Rip = {
    name = "Rip",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    spell = Spells.Cat.Rip,
}
function Rip.matches(ctx, state)
    return state.rip_now
end
function Rip.execute(ctx, state)
    local energy = ctx.energy or 0
    local has_cc = ctx.has_clearcasting
    
    if (energy >= ENERGY_COST_RIP or has_cc) and not ctx.target_phys_immune then
        local spell = Spells.Cat.Rip
        if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
            if spell:cast_safe(ctx.target, "[P2] Rip - Finisher") then
                Utils.log_cast("Rip", {spec = "Cat"})
                return true
            end
        end
    end
    
    state.pooling = true
    return nil
end

-- [P2] Rip Shift (Powershift for Rip)
local RipShift = {
    name = "RipShift",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    spell = Spells.Forms.CatForm,
}
function RipShift.matches(ctx, state)
    return state.rip_now and state.can_powershift
        and (ctx.energy or 0) < ENERGY_COST_RIP and not ctx.has_clearcasting
end
function RipShift.execute(ctx, state)
    if will_reach_energy(ENERGY_COST_RIP, ctx) then return nil end
    if state.energy_tick_soon then return nil end
    return safe_powershift(ctx, state, "[P2] Powershift for Rip")
end

-- [P3] Execute Bite (target dying)
local ExecuteBite = {
    name = "ExecuteBite",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    min_energy = ENERGY_COST_BITE,
    min_cp = 1,
    spell = Spells.Cat.FerociousBite,
}
function ExecuteBite.matches(ctx, state)
    if state.pooling then return false end
    if not ctx.settings.use_bite_execute then return false end
    local cp = ctx.cp or 0
    return ctx.ttd <= cp * 1.5
end
function ExecuteBite.execute(ctx, state)
    local spell = Spells.Cat.FerociousBite
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P2.5] Ferocious Bite - Execute") then
            Utils.log_cast("Ferocious Bite (Execute)", {spec = "Cat"})
            return true
        end
    end
    return nil
end

-- [P3] Ferocious Bite (Standard finisher)
local FerociousBite = {
    name = "FerociousBite",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    min_cp = 1,
    spell = Spells.Cat.FerociousBite,
}
function FerociousBite.matches(ctx, state)
    if state.pooling then return false end
    local min_cp = ctx.settings.fb_min_cp or 5
    return (ctx.cp or 0) >= min_cp
end
function FerociousBite.execute(ctx, state)
    local settings = ctx.settings
    local energy = ctx.energy or 0
    local ttd = ctx.ttd or 999
    local target_hp = ctx.target and ctx.target:get_health_percentage() or 100
    local bite_now = false
    
    local fb_max_energy = settings.fb_max_energy or 39
    local not_maintaining_rip = not settings.maintain_rip or not state.target_qualifies_for_rip
    
    -- Bite if not maintaining Rip
    if not_maintaining_rip and energy >= ENERGY_COST_BITE and energy <= fb_max_energy then
        bite_now = true
    end
    
    -- Bite if excess energy and Rip has enough duration
    if state.rip_duration > (settings.fb_min_rip_duration or 3) 
       and energy >= (settings.fb_min_energy or 35) and energy <= fb_max_energy then
        bite_now = true
    end
    
    -- Execute phase
    if settings.use_bite_execute then
        local bite_execute_hp = settings.bite_execute_hp or Constants.HP.EXECUTE
        if ttd < Constants.TTD.BITE_EXECUTE and energy >= ENERGY_COST_BITE then
            bite_now = true
        elseif target_hp <= bite_execute_hp and state.rip_duration > Constants.DURATION.BITE_MIN_RIP 
               and energy >= ENERGY_COST_BITE then
            bite_now = true
        end
    end
    
    if bite_now then
        local spell = Spells.Cat.FerociousBite
        if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
            if spell:cast_safe(ctx.target, "[P3] Ferocious Bite") then
                Utils.log_cast("Ferocious Bite", {spec = "Cat"})
                return true
            end
        end
    end
    return nil
end

-- [P4] Mangle Debuff
local MangleDebuff = {
    name = "MangleDebuff",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
}
function MangleDebuff.matches(ctx, state)
    if state.pooling then return false end
    return state.mangle_now
end
function MangleDebuff.execute(ctx, state)
    local energy = ctx.energy or 0
    local has_cc = ctx.has_clearcasting
    
    if (energy >= ENERGY_COST_MANGLE or has_cc) and not ctx.target_phys_immune then
        local spell = Spells.Cat.MangleCat
        if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
            if spell:cast_safe(ctx.target, "[P4] Mangle - Debuff") then
                Utils.log_cast("Mangle (Cat)", {spec = "Cat"})
                return true
            end
        end
    end
    
    state.pooling = true
    return nil
end

-- [P4] Mangle Shift
local MangleShift = {
    name = "MangleShift",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    spell = Spells.Forms.CatForm,
}
function MangleShift.matches(ctx, state)
    return state.mangle_now and state.can_powershift
        and (ctx.energy or 0) < ENERGY_COST_MANGLE and not ctx.has_clearcasting
end
function MangleShift.execute(ctx, state)
    if will_reach_energy(ENERGY_COST_MANGLE, ctx) then return nil end
    if state.energy_tick_soon then return nil end
    return safe_powershift(ctx, state, "[P4] Powershift for Mangle")
end

-- [P4.5] Rake (DoT maintenance)
local Rake = {
    name = "Rake",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    min_energy = ENERGY_COST_RAKE,
    setting_key = "maintain_rake",
}
function Rake.matches(ctx, state)
    if state.pooling then return false end
    local ttd = ctx.ttd or 999
    if ttd < Constants.TTD.RAKE_MIN then return false end
    
    local cp = ctx.cp or 0
    if cp > 4 then return false end  -- Don't Rake when close to finisher
    
    local rake_refresh = (ctx.settings.rake_refresh or 0) + (ctx.gcd_remains or 0)
    return state.rake_duration <= rake_refresh
end
function Rake.execute(ctx, state)
    local spell = Spells.Cat.Rake
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P4.5] Rake - DoT") then
            Utils.log_cast("Rake", {spec = "Cat"})
            return true
        end
    end
    return nil
end

-- [P5] Clearcasting Shred
local ClearcastingShred = {
    name = "ClearcastingShred",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    requires_clearcasting = true,
    requires_behind = true,
    spell = Spells.Cat.Shred,
}
function ClearcastingShred.matches(ctx, state)
    return not state.pooling
end
function ClearcastingShred.execute(ctx, state)
    local spell = Spells.Cat.Shred
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P5] Shred - Clearcasting") then
            Utils.log_cast("Shred (Clearcasting)", {spec = "Cat"})
            return true
        end
    end
    return nil
end

-- [P6] Bite Trick (low energy dump)
local BiteTrick = {
    name = "BiteTrick",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    min_energy = ENERGY_COST_BITE,
    min_cp = 3,
    setting_key = "use_bite_trick",
    spell = Spells.Cat.FerociousBite,
}
function BiteTrick.matches(ctx, state)
    if state.pooling then return false end
    if state.rip_needs_refresh_soon then return false end
    local energy = ctx.energy or 0
    return energy <= Constants.ENERGY.BITE_TRICK_MAX and ctx.ttd >= Constants.TTD.BITE_EXECUTE
end
function BiteTrick.execute(ctx, state)
    local spell = Spells.Cat.FerociousBite
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P6] Ferocious Bite - Bite Trick") then
            Utils.log_cast("Ferocious Bite (Bite Trick)", {spec = "Cat"})
            return true
        end
    end
    return nil
end

-- [P7] Rake Trick
local RakeTrick = {
    name = "RakeTrick",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    min_energy = ENERGY_COST_RAKE,
    setting_key = "use_rake_trick",
    spell = Spells.Cat.Rake,
}
function RakeTrick.matches(ctx, state)
    if state.pooling then return false end
    local energy = ctx.energy or 0
    return energy < ENERGY_COST_MANGLE and state.mangle_duration > 0 
       and state.rake_duration == 0 and ctx.ttd >= Constants.TTD.RAKE_MIN
end
function RakeTrick.execute(ctx, state)
    local spell = Spells.Cat.Rake
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P7] Rake - Rake Trick") then
            Utils.log_cast("Rake (Rake Trick)", {spec = "Cat"})
            return true
        end
    end
    return nil
end

-- [P8] Shred (Primary builder)
local Shred = {
    name = "Shred",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    requires_behind = true,
    requires_stealth = false,
    min_energy = ENERGY_COST_SHRED,
}
function Shred.matches(ctx, state)
    if state.pooling then return false end
    if state.prefer_mangle_for_tick then return false end
    return (ctx.cp or 0) < 5
end
function Shred.execute(ctx, state)
    local spell = Spells.Cat.Shred
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P8] Shred - Builder") then
            Utils.log_cast("Shred", {spec = "Cat"})
            return true
        end
    end
    return nil
end

-- [P9] Mangle Builder
local MangleBuilder = {
    name = "MangleBuilder",
    requires_combat = true,
    requires_enemy = true,
    requires_phys_immune = false,
    requires_stealth = false,
    spell = Spells.Cat.MangleCat,
}
function MangleBuilder.matches(ctx, state)
    if state.pooling then return false end
    local not_behind = not ctx.is_behind
    if not_behind and not ctx.settings.use_mangle_builder then return false end
    local energy = ctx.energy or 0
    return (not_behind or energy < ENERGY_COST_SHRED or state.prefer_mangle_for_tick)
       and (energy >= ENERGY_COST_MANGLE or ctx.has_clearcasting)
       and (ctx.cp or 0) < 5
end
function MangleBuilder.execute(ctx, state)
    local spell = Spells.Cat.MangleCat
    if spell:is_learned() and spell:is_castable_to_unit(ctx.target) then
        if spell:cast_safe(ctx.target, "[P9] Mangle - Builder") then
            Utils.log_cast("Mangle (Cat)", {spec = "Cat"})
            return true
        end
    end
    return nil
end

-- [CD] Tiger's Fury
local TigersFury = {
    name = "TigersFury",
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    is_burst = true,
    min_energy = ENERGY_COST_TIGERS_FURY,
    setting_key = "use_tigers_fury",
    spell = Spells.Cat.TigersFury,
}
function TigersFury.matches(ctx, state)
    if state.pooling then return false end
    if ctx.ttd < 4 then return false end
    if state.tf_queued then return false end
    if ctx.me:buff_up(Constants.BUFF_ID.TIGERS_FURY) then return false end
    return (ctx.energy or 0) >= (ctx.settings.tigers_fury_energy or 40)
end
function TigersFury.execute(ctx, state)
    -- Don't TF if about to powershift
    local shift_threshold = state.has_wolfshead and Constants.ENERGY.EARLY_SHIFT_WOLFSHEAD or Constants.ENERGY.EARLY_SHIFT
    if state.can_powershift and (ctx.energy or 0) < shift_threshold then
        return nil
    end
    
    local spell = Spells.Cat.TigersFury
    if spell:is_learned() and spell:is_usable() then
        if spell:cast_safe(ctx.me, "[CD] Tiger's Fury") then
            state.tf_queued = true
            state.tf_queued_at = core.time()
            Utils.log_cast("Tiger's Fury", {spec = "Cat"})
            return true
        end
    end
    return nil
end

-- [SHIFT] Wolfshead Shred Shift
local WolfsheadShred = {
    name = "WolfsheadShred",
    requires_combat = true,
    requires_enemy = true,
    requires_behind = true,
    requires_stealth = false,
    spell = Spells.Forms.CatForm,
}
function WolfsheadShred.matches(ctx, state)
    if ctx.has_clearcasting then return false end
    if state.pooling or state.rip_now or state.mangle_now then return false end
    local cp = ctx.cp or 0
    local energy = ctx.energy or 0
    return state.has_wolfshead and state.can_powershift
       and (state.energy_after_shift - energy) >= Constants.POWERSHIFT.MIN_SHIFT_ENERGY_GAIN
       and cp < 5 and state.energy_after_shift >= ENERGY_COST_SHRED and energy < ENERGY_COST_SHRED
end
function WolfsheadShred.execute(ctx, state)
    if will_reach_energy(ENERGY_COST_SHRED, ctx) then return nil end
    if state.energy_tick_soon then return nil end
    return safe_powershift(ctx, state, "[WOLFSHEAD] Shift for Shred")
end

-- [SHIFT] Early Shift
local EarlyShift = {
    name = "EarlyShift",
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    spell = Spells.Forms.CatForm,
}
function EarlyShift.matches(ctx, state)
    if ctx.has_clearcasting then return false end
    if state.pooling or state.rip_now or state.mangle_now then return false end
    if not state.can_powershift then return false end
    local energy = ctx.energy or 0
    local threshold = state.has_wolfshead and Constants.ENERGY.EARLY_SHIFT_WOLFSHEAD or Constants.ENERGY.EARLY_SHIFT
    return energy < threshold
end
function EarlyShift.execute(ctx, state)
    if ctx.settings.use_rake_trick and (ctx.energy or 0) >= Constants.ENERGY.RAKE_TRICK_MIN then
        return nil
    end
    return safe_powershift(ctx, state, "[SHIFT] Early Powershift")
end

-- ============================================================================
-- REGISTRATION
-- ============================================================================

function CatRotation.register()
    local strategies = {
        CriticalEnergyShift,
        FaerieFire,
        Rip,
        RipShift,
        ExecuteBite,
        FerociousBite,
        MangleDebuff,
        MangleShift,
        Rake,
        ClearcastingShred,
        BiteTrick,
        RakeTrick,
        Shred,
        MangleBuilder,
        TigersFury,
        WolfsheadShred,
        EarlyShift,
    }
    
    RotationEngine.register("cat", strategies, {
        context_builder = build_cat_context,
    })
end

return CatRotation
