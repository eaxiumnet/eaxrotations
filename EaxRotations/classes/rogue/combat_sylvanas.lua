-- Rogue Combat priority list.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.RogueSpells or {}

local SND_BUFF = { 6774, 5171 }
local RUPTURE_DEBUFF = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local STEALTH_BUFF = { 1787, 1786, 1785, 1784 }
local KIDNEY_SHOT_DEBUFF = { 8643, 408 }
local EVISCERATE_SPELL = SPELLS.Eviscerate
local RUPTURE_SPELL = SPELLS.Rupture

-- Energy tick constants
local ENERGY_TICK = 2.0
local ENERGY_PER_TICK = 20
local ENERGY_CAP = 100
local SND_REFRESH_WINDOW = 3
local RUPTURE_REFRESH_WINDOW = 3

-- Energy / resource thresholds (Research: Resource Floor Thresholds)
local ENERGY_LOW_BUILDER = 45
local ENERGY_LOW_FINISHER = 25
local RUPTURE_TTD_FLOOR = 12
-- Bloodlust / Heroism buff IDs (Research: avoid energy capping AR during heroism)
local HEROISM_BUFF = { 2825, 32182 }

-- ============================================================================
-- Energy Tick Optimization (preserved)
-- ============================================================================
local _last_energy = 0
local _last_tick_time = 0

local function get_next_tick_in(energy)
    local now = NS.time_now and NS.time_now() or 0
    local energy_gained = energy - _last_energy
    if energy_gained > 0 then
        _last_tick_time = now
        _last_energy = energy
        return ENERGY_TICK
    end
    local time_since_tick = now - _last_tick_time
    if time_since_tick < 0 or time_since_tick > ENERGY_TICK * 2 then
        _last_tick_time = now
        return ENERGY_TICK
    end
    return math.max(0, ENERGY_TICK - time_since_tick)
end

local function should_pool_energy(context)
    local energy = context.energy or 0
    local next_tick_in = get_next_tick_in(energy)
    if next_tick_in <= 0.5 then
        local projected_energy = energy + ENERGY_PER_TICK
        if projected_energy <= ENERGY_CAP then
            return true
        end
    end
    return false
end

local function should_spend_energy(context, cost)
    local energy = context.energy or 0
    local next_tick_in = get_next_tick_in(energy)
    local projected_energy = energy + ENERGY_PER_TICK
    if projected_energy > ENERGY_CAP then
        return true
    end
    if next_tick_in > 1.0 then
        return true
    end
    if next_tick_in > ENERGY_TICK - 0.3 then
        return true
    end
    return false
end

-- ============================================================================
-- State builder
-- ============================================================================
local combat_state = {
    has_stealth = false,
    has_snd = false,
    has_blade_flurry = false,
    has_adrenaline_rush = false,
    snd_remains = 0,
    rupture_remains = 0,
    combo_points = 0,
    energy = 100,
    hp_pct = 100,
    in_combat = false,
    enemy_count = 1,
    target_casting = false,
    -- Research: energy pooling gates
    energy_low = false,
    energy_pool_finisher = false,
    target_count = 1,
    heroism_active = false,
    threat_pct = 0,
    snd_needs_refresh = false,
    expose_assigned = false,
    -- spell readiness
    stealth_ready = false,
    adrenaline_rush_ready = false,
    blade_flurry_ready = false,
    slice_and_dice_ready = false,
    rupture_ready = false,
    eviscerate_ready = false,
    sinister_strike_ready = false,
    kick_ready = false,
    gouge_ready = false,
    sprint_ready = false,
    vanish_ready = false,
    feint_ready = false,
    hemorrhage_ready = false,
    backstab_ready = false,
    ghostly_strike_ready = false,
    kidney_shot_ready = false,
    expose_armor_ready = false,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target

    combat_state.has_stealth = me and NS.buff_up(me, STEALTH_BUFF) or false
    combat_state.has_snd = me and NS.buff_up(me, SND_BUFF) or false
    combat_state.has_blade_flurry = me and NS.buff_up(me, { 13877 }) or false
    combat_state.has_adrenaline_rush = me and NS.buff_up(me, { 13750 }) or false
    combat_state.snd_remains = me and NS.buff_remains(me, SND_BUFF) or 0
    combat_state.rupture_remains = target and NS.debuff_remains(target, RUPTURE_DEBUFF) or 0
    combat_state.combo_points = context.combo_points or 0
    combat_state.energy = context.energy or (me and NS.unit_energy_pct and NS.unit_energy_pct(me)) or 100
    combat_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    combat_state.in_combat = context.in_combat or false
    combat_state.enemy_count = context.enemy_count or context.enemies_count or 1
    combat_state.target_casting = target and target.is_casting and target:is_casting() or false
    combat_state.stealth_ready = me and NS.spell_ready(SPELLS.Stealth, me, { skip_range = true }) or false
    combat_state.adrenaline_rush_ready = me and NS.spell_ready(SPELLS.AdrenalineRush, me, { skip_range = true, expected_cooldown = 300 }) or false
    combat_state.blade_flurry_ready = me and NS.spell_ready(SPELLS.BladeFlurry, me, { skip_range = true, expected_cooldown = 120 }) or false
    combat_state.slice_and_dice_ready = me and NS.spell_ready(SPELLS.SliceAndDice, me, { skip_range = true }) or false
    combat_state.rupture_ready = target and NS.spell_ready(SPELLS.Rupture, target) or false
    combat_state.eviscerate_ready = target and NS.spell_ready(SPELLS.Eviscerate, target) or false
    combat_state.sinister_strike_ready = target and NS.spell_ready(SPELLS.SinisterStrike, target) or false
    combat_state.kick_ready = target and NS.spell_ready(SPELLS.Kick, target, { expected_cooldown = 10 }) or false
    combat_state.gouge_ready = target and NS.spell_ready(SPELLS.Gouge, target, { expected_cooldown = 10 }) or false
    combat_state.sprint_ready = me and NS.spell_ready(SPELLS.Sprint, me, { skip_range = true, expected_cooldown = 180 }) or false
    combat_state.vanish_ready = me and NS.spell_ready(SPELLS.Vanish, me, { skip_range = true, expected_cooldown = 300 }) or false
    combat_state.feint_ready = me and NS.spell_ready(SPELLS.Feint, me, { skip_range = true, expected_cooldown = 10 }) or false
    combat_state.hemorrhage_ready = target and NS.spell_ready(SPELLS.Hemorrhage, target) or false
    combat_state.backstab_ready = target and NS.spell_ready(SPELLS.Backstab, target) or false
    combat_state.ghostly_strike_ready = target and NS.spell_ready(SPELLS.GhostlyStrike, target, { expected_cooldown = 20 }) or false
    combat_state.kidney_shot_ready = target and NS.spell_ready(SPELLS.KidneyShot, target, { expected_cooldown = 20 }) or false
    combat_state.expose_armor_ready = target and NS.spell_ready(SPELLS.ExposeArmor, target) or false

    -- Research: energy pooling gates
    combat_state.energy_low = combat_state.energy < ENERGY_LOW_BUILDER
    combat_state.energy_pool_finisher = combat_state.energy < ENERGY_LOW_FINISHER
    combat_state.target_count = context.enemy_count or 1
    combat_state.heroism_active = me and NS.buff_up(me, HEROISM_BUFF) or false
    combat_state.threat_pct = context.threat_pct or 0
    combat_state.snd_needs_refresh = combat_state.has_snd and combat_state.snd_remains <= SND_REFRESH_WINDOW
    combat_state.expose_assigned = context.settings and context.settings.combat_expose_assigned or false

    return combat_state
end

local function cooldowns_enabled(context)
    return not context.settings or context.settings.use_cooldowns ~= false
end

-- ============================================================================
-- Action definitions (test assertion strings embedded)
-- ============================================================================
local STEALTH_ACTION = { name = "Stealth", spell = SPELLS.Stealth, target = "self", kind = "buff", buff = STEALTH_BUFF, ooc = true, requires_target = false }
local ADRENALINE_RUSH_ACTION = { name = "AdrenalineRush", spell = SPELLS.AdrenalineRush, target = "self", combat = true, setting = "use_cooldowns", cooldown = 300, requires_target = false }
local BLADE_FLURRY_ACTION = { name = "BladeFlurry", spell = SPELLS.BladeFlurry, target = "self", combat = true, setting = "use_cooldowns", cooldown = 120, requires_target = false }
local SLICE_AND_DICE_ACTION = { name = "SliceAndDice", spell = SPELLS.SliceAndDice, target = "self", kind = "buff", buff = SND_BUFF, min_combo = 2, min_energy = 25, requires_target = false }
local RUPTURE_ACTION = { name = "Rupture", spell = SPELLS.Rupture, min_combo = 5, min_energy = 25, kind = "debuff", debuff = RUPTURE_DEBUFF, refresh = 3, max_enemy_count = 1 }
local EVISCERATE_ACTION = { name = "Eviscerate", spell = SPELLS.Eviscerate, min_combo = 5, min_energy = 35 }
local SINISTER_STRIKE_ACTION = { name = "SinisterStrike", spell = SPELLS.SinisterStrike, min_energy = 45 }
local KICK_ACTION = { name = "Kick", spell = SPELLS.Kick, cooldown = 10, interrupt = true }
local GOUGE_ACTION = { name = "Gouge", spell = SPELLS.Gouge, cooldown = 10 }
local SPRINT_ACTION = { name = "Sprint", spell = SPELLS.Sprint, target = "self", cooldown = 180, requires_target = false }
local VANISH_ACTION = { name = "Vanish", spell = SPELLS.Vanish, target = "self", cooldown = 300, requires_target = false }
local FEINT_ACTION = { name = "Feint", spell = SPELLS.Feint, target = "self", cooldown = 10, requires_target = false }
local HEMORRHAGE_ACTION = { name = "Hemorrhage", spell = SPELLS.Hemorrhage, min_energy = 35 }
local BACKSTAB_ACTION = { name = "Backstab", spell = SPELLS.Backstab, min_energy = 60 }
local GHOSTLY_STRIKE_ACTION = { name = "GhostlyStrike", spell = SPELLS.GhostlyStrike, min_energy = 40, cooldown = 20 }
local KIDNEY_SHOT_ACTION = { name = "KidneyShot", spell = SPELLS.KidneyShot, cooldown = 20 }
local EXPOSE_ARMOR_ACTION = { name = "ExposeArmor", spell = SPELLS.ExposeArmor, min_combo = 2, min_energy = 25, kind = "debuff" }

-- ============================================================================
-- Custom match functions (preserved from original for test compatibility)
-- ============================================================================
local function rupture_matches(context, action)
    local target = context.target
    if not target then return false end
    local rupture_remains = NS.debuff_remains(target, RUPTURE_DEBUFF) or 0
    local combo = context.combo_points or 0
    if combo < 5 then return false end
    if rupture_remains > RUPTURE_REFRESH_WINDOW then return false end
    return NS.action_matches(context, action)
end

local function sinister_strike_matches(context, action)
    local energy = context.energy or 0
    if energy >= 85 then return NS.action_matches(context, action) end
    if not should_spend_energy(context, 45) then return false end
    return NS.action_matches(context, action)
end

local function adrenaline_rush_matches(context, action)
    if not NS.action_matches(context, action) then return false end
    local bf_ready = NS.spell_ready(SPELLS.BladeFlurry, context.me, { skip_range = true, expected_cooldown = 120 })
    if bf_ready then return true end
    return true
end

local function blade_flurry_matches(context, action)
    if not NS.action_matches(context, action) then return false end
    local ar_active = context.me and NS.buff_up(context.me, { 13750 }) or false
    if ar_active then return true end
    return context.should_burst or false
end

-- ============================================================================
-- Match functions
-- ============================================================================
local function stealth_matches(context, s)
    if s.in_combat then return false end
    if s.has_stealth then return false end
    if not s.stealth_ready then return false end
    return NS.action_matches(context, STEALTH_ACTION)
end

local function adrenaline_rush_wrapper(context, s)
    if not cooldowns_enabled(context) then return false end
    if not s.in_combat then return false end
    if s.has_adrenaline_rush then return false end
    if not s.adrenaline_rush_ready then return false end
    -- Research: delay AR during Bloodlust/Heroism to avoid energy capping
    local delay_during_heroism = (context.settings and context.settings.combat_adrenaline_rush_heroism) ~= false
    if delay_during_heroism and s.heroism_active then return false end
    return adrenaline_rush_matches(context, ADRENALINE_RUSH_ACTION)
end

local function blade_flurry_wrapper(context, s)
    if not cooldowns_enabled(context) then return false end
    if not s.in_combat then return false end
    if s.has_blade_flurry then return false end
    if not s.blade_flurry_ready then return false end
    -- Research: only use when 2+ targets within 5y (avoid wasted CD on single target)
    local min_targets = (context.settings and context.settings.combat_blade_flurry_count) or 2
    if s.target_count < min_targets then return false end
    return blade_flurry_matches(context, BLADE_FLURRY_ACTION)
end

local function slice_and_dice_wrapper(context, s)
    if not s.slice_and_dice_ready then return false end
    -- Research: maintain 100% uptime; refresh when <3s remains
    if s.has_snd and not s.snd_needs_refresh then return false end
    if s.combo_points < 2 then return false end
    return NS.action_matches(context, SLICE_AND_DICE_ACTION)
end

local function rupture_wrapper(context, s)
    if not s.rupture_ready then return false end
    if s.energy_pool_finisher then return false end
    -- Research: only Rupture when target lives > ttd floor (avoid wasted DoT ticks)
    local ttd_floor = (context.settings and context.settings.combat_rupture_ttd) or RUPTURE_TTD_FLOOR
    local ttd = context.target_ttd
    if ttd and ttd < ttd_floor then return false end
    return rupture_matches(context, RUPTURE_ACTION)
end

local function eviscerate_matches(context, s)
    if not s.eviscerate_ready then return false end
    if s.energy_pool_finisher then return false end
    if s.energy < 35 then return false end  -- hard floor: spell costs 35 energy
    -- Research: only Eviscerate at 4-5 CP (not wasted at 2-3 CP)
    if s.combo_points < 4 then return false end
    return NS.action_matches(context, EVISCERATE_ACTION)
end

local function sinister_strike_wrapper(context, s)
    if not s.sinister_strike_ready then return false end
    if s.energy_low then return false end  -- Research: pool energy below 45
    return sinister_strike_matches(context, SINISTER_STRIKE_ACTION)
end

local function kick_matches(context, s)
    if not s.target_casting then return false end
    if not s.kick_ready then return false end
    return NS.action_matches(context, KICK_ACTION)
end

local function gouge_matches(context, s)
    if not s.gouge_ready then return false end
    return NS.action_matches(context, GOUGE_ACTION)
end

local function sprint_matches(context, s)
    if not s.in_combat then return false end
    if not s.sprint_ready then return false end
    return NS.action_matches(context, SPRINT_ACTION)
end

local function vanish_matches(context, s)
    if not s.in_combat then return false end
    if not s.vanish_ready then return false end
    local vanish_hp = (context.settings and context.settings.combat_vanish_hp) or 20
    -- Research: Vanish as emergency threat drop when HP critical
    if s.hp_pct > vanish_hp then return false end
    return NS.action_matches(context, VANISH_ACTION)
end

local function feint_matches(context, s)
    if not s.in_combat then return false end
    if not s.feint_ready then return false end
    -- Research: Feint is a threat drop — only fire when threat is known and high
    local feint_threat = (context.settings and context.settings.combat_feint_threat) or 90
    if s.threat_pct <= 0 or s.threat_pct < feint_threat then return false end
    return NS.action_matches(context, FEINT_ACTION)
end

local function hemorrhage_matches(context, s)
    if not s.hemorrhage_ready then return false end
    return NS.action_matches(context, HEMORRHAGE_ACTION)
end

local function backstab_matches(context, s)
    if not s.backstab_ready then return false end
    return NS.action_matches(context, BACKSTAB_ACTION)
end

local function ghostly_strike_matches(context, s)
    if not s.ghostly_strike_ready then return false end
    return NS.action_matches(context, GHOSTLY_STRIKE_ACTION)
end

local function kidney_shot_matches(context, s)
    if not s.kidney_shot_ready then return false end
    return NS.action_matches(context, KIDNEY_SHOT_ACTION)
end

local function expose_armor_matches(context, s)
    if not s.expose_armor_ready then return false end
    -- Research: only apply Expose Armor when assigned (conflicts with Sunder/Devastate)
    if not s.expose_assigned then return false end
    return NS.action_matches(context, EXPOSE_ARMOR_ACTION)
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "Stealth", matches = stealth_matches, execute = function(context) return NS.action_execute(context, STEALTH_ACTION, "[COMBAT]") end },
    { name = "AdrenalineRush", matches = adrenaline_rush_wrapper, execute = function(context) return NS.action_execute(context, ADRENALINE_RUSH_ACTION, "[COMBAT]") end },
    { name = "BladeFlurry", matches = blade_flurry_wrapper, execute = function(context) return NS.action_execute(context, BLADE_FLURRY_ACTION, "[COMBAT]") end },
    { name = "SliceAndDice", matches = slice_and_dice_wrapper, execute = function(context) return NS.action_execute(context, SLICE_AND_DICE_ACTION, "[COMBAT]") end },
    { name = "Rupture", matches = rupture_wrapper, execute = function(context) return NS.action_execute(context, RUPTURE_ACTION, "[COMBAT]") end },
    { name = "Eviscerate", matches = eviscerate_matches, execute = function(context) return NS.action_execute(context, EVISCERATE_ACTION, "[COMBAT]") end },
    { name = "Kick", matches = kick_matches, execute = function(context) return NS.action_execute(context, KICK_ACTION, "[COMBAT]") end },
    { name = "Gouge", matches = gouge_matches, execute = function(context) return NS.action_execute(context, GOUGE_ACTION, "[COMBAT]") end },
    { name = "Sprint", matches = sprint_matches, execute = function(context) return NS.action_execute(context, SPRINT_ACTION, "[COMBAT]") end },
    { name = "Vanish", matches = vanish_matches, execute = function(context) return NS.action_execute(context, VANISH_ACTION, "[COMBAT]") end },
    { name = "Feint", matches = feint_matches, execute = function(context) return NS.action_execute(context, FEINT_ACTION, "[COMBAT]") end },
    { name = "Hemorrhage", matches = hemorrhage_matches, execute = function(context) return NS.action_execute(context, HEMORRHAGE_ACTION, "[COMBAT]") end },
    { name = "GhostlyStrike", matches = ghostly_strike_matches, execute = function(context) return NS.action_execute(context, GHOSTLY_STRIKE_ACTION, "[COMBAT]") end },
    { name = "Backstab", matches = backstab_matches, execute = function(context) return NS.action_execute(context, BACKSTAB_ACTION, "[COMBAT]") end },
    { name = "KidneyShot", matches = kidney_shot_matches, execute = function(context) return NS.action_execute(context, KIDNEY_SHOT_ACTION, "[COMBAT]") end },
    { name = "ExposeArmor", matches = expose_armor_matches, execute = function(context) return NS.action_execute(context, EXPOSE_ARMOR_ACTION, "[COMBAT]") end },
    { name = "SinisterStrike", matches = sinister_strike_wrapper, execute = function(context) return NS.action_execute(context, SINISTER_STRIKE_ACTION, "[COMBAT]") end },
}

NS.rotation_registry:register("combat", strategies, { get_state = build_state })
NS.log("Rogue combat rotation registered (Tier A)")
return strategies
