-- Rogue Combat priority list.
-- ============================================================================
-- What: TBC Rogue Combat rotation with energy pooling and cooldown alignment
-- When: Per tick
-- Why: Maintains SnD, Rupture, and burst timing while avoiding energy waste
-- Safety: Cached state tables, no per-tick allocations in hot path, conservative spend/pool gates
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.RogueSpells or {}
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local DISARM_CLASS_IDS = { [1] = true, [2] = true, [4] = true, [7] = true }  -- Warrior, Paladin, Rogue, Shaman

local SND_BUFF = { 6774, 5171 }
local RUPTURE_DEBUFF = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local STEALTH_BUFF = { 1787, 1786, 1785, 1784 }
local BLADE_FLURRY_BUFF = { 13877 }
local ADRENALINE_RUSH_BUFF = { 13750 }
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
    -- Shiv Purge (PvP buff dispel via Wound Poison)
    shiv_ready = false,
    shiv_purge_name = nil,
    -- Disarm (PvP Dismantle)
    disarm_ready = false,
    disarm_class_ok = false,
    disarm_buff_name = nil,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target

    combat_state.has_stealth = me and NS.buff_up(me, STEALTH_BUFF) or false
    combat_state.has_snd = me and NS.buff_up(me, SND_BUFF) or false
    combat_state.has_blade_flurry = me and NS.buff_up(me, BLADE_FLURRY_BUFF) or false
    combat_state.has_adrenaline_rush = me and NS.buff_up(me, ADRENALINE_RUSH_BUFF) or false
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

    -- Shiv Purge (PvP buff dispel via Wound Poison)
    combat_state.shiv_ready = target and NS.spell_ready(SPELLS.Shiv, target, { expected_cooldown = 10 }) or false
    combat_state.shiv_purge_name = nil
    if combat_state.in_combat and (context.is_pvp or false) and target and CCGateDB.find_best_dispel_target then
        local best_id, _, best_name = CCGateDB.find_best_dispel_target(target, NS)
        if best_id then combat_state.shiv_purge_name = best_name end
    end

    -- Disarm (PvP Dismantle — weapon removal vs melee)
    combat_state.disarm_ready = target and NS.spell_ready(SPELLS.Dismantle, target, { expected_cooldown = 60 }) or false
    combat_state.disarm_class_ok = false
    combat_state.disarm_buff_name = nil
    if target and (context.is_pvp or false) and combat_state.disarm_ready then
        local ok, class_id = pcall(function() return target:get_class() end)
        if ok and type(class_id) == "number" and DISARM_CLASS_IDS[class_id] then
            combat_state.disarm_class_ok = true
            if CCGateDB and CCGateDB.find_best_dispel_target then
                local best_id, best_priority, best_name = CCGateDB.find_best_dispel_target(target, NS)
                if best_id and (best_priority or 0) >= 3 then
                    combat_state.disarm_buff_name = best_name
                end
            end
        end
    end

    return combat_state
end

local function cooldowns_enabled(context)
    return not context.settings or context.settings.use_cooldowns ~= false
end

-- ============================================================================
-- Match functions
-- ============================================================================
local function stealth_matches(context, s)
    if s.in_combat then return false end
    if s.has_stealth then return false end
    if not s.stealth_ready then return false end
    return true
end

local function adrenaline_rush_wrapper(context, s)
    if not cooldowns_enabled(context) then return false end
    if not s.in_combat then return false end
    if s.has_adrenaline_rush then return false end
    if not s.adrenaline_rush_ready then return false end
    -- Research: delay AR during Bloodlust/Heroism to avoid energy capping
    local delay_during_heroism = (context.settings and context.settings.combat_adrenaline_rush_heroism) ~= false
    if delay_during_heroism and s.heroism_active then return false end
    return true
end

local function blade_flurry_wrapper(context, s)
    if not cooldowns_enabled(context) then return false end
    if not s.in_combat then return false end
    if s.has_blade_flurry then return false end
    if not s.blade_flurry_ready then return false end
    -- Research: only use when 2+ targets within 5y (avoid wasted CD on single target)
    local min_targets = (context.settings and context.settings.combat_blade_flurry_count) or 2
    if s.target_count < min_targets then return false end
    return true
end

local function slice_and_dice_wrapper(context, s)
    if not s.slice_and_dice_ready then return false end
    -- Research: maintain 100% uptime; refresh when <3s remains
    if s.has_snd and not s.snd_needs_refresh then return false end
    if s.combo_points < 2 then return false end
    return true
end

local function rupture_wrapper(context, s)
    if not s.rupture_ready then return false end
    if s.energy_pool_finisher then return false end
    -- Research: only Rupture when target lives > ttd floor (avoid wasted DoT ticks)
    local ttd_floor = (context.settings and context.settings.combat_rupture_ttd) or RUPTURE_TTD_FLOOR
    local ttd = context.target_ttd
    if ttd and ttd < ttd_floor then return false end
    if not context.target then return false end
    local rupture_remains = NS.debuff_remains(context.target, RUPTURE_DEBUFF) or 0
    if rupture_remains > RUPTURE_REFRESH_WINDOW then return false end
    if s.combo_points < 5 then return false end
    return true
end

local function eviscerate_matches(context, s)
    if not s.eviscerate_ready then return false end
    if s.energy_pool_finisher then return false end
    if s.energy < 35 then return false end  -- hard floor: spell costs 35 energy
    -- Research: only Eviscerate at 4-5 CP (not wasted at 2-3 CP)
    if s.combo_points < 4 then return false end
    return true
end

local function sinister_strike_wrapper(context, s)
    if not s.sinister_strike_ready then return false end
    if s.energy_low then return false end  -- Research: pool energy below 45
    local energy = context.energy or 0
    if energy < 85 then
        if not should_spend_energy(context, 45) then return false end
    end
    return true
end

local function shiv_purge_matches(context, s)
    local settings = context.settings or {}
    if settings.use_shiv_purge == false then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(5938)) then return false end
    if not s.in_combat then return false end
    if not (context.is_pvp or false) then return false end
    if not context.target then return false end
    if not (context.in_melee_range or false) then return false end
    if not s.shiv_ready then return false end
    if not s.shiv_purge_name then return false end
    if settings.shiv_purge_pvp_only ~= false then
        local ok, is_player = pcall(function() return context.target:is_player() end)
        if not (ok and is_player) then return false end
    end
    return true
end

local function disarm_matches(context, s)
    local settings = context.settings or {}
    if settings.use_disarm == false then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(51722)) then return false end
    if not s.in_combat then return false end
    if not (context.is_pvp or false) then return false end
    if not context.target then return false end
    if not (context.in_melee_range or false) then return false end
    if not s.disarm_ready then return false end
    if not s.disarm_class_ok then return false end
    if settings.disarm_pvp_only ~= false then
        local ok, is_player = pcall(function() return context.target:is_player() end)
        if not (ok and is_player) then return false end
    end
    local trigger = settings.disarm_trigger or "on_burst"
    if trigger == "on_burst" then
        if not s.disarm_buff_name then return false end
        context._disarm_buff_name = s.disarm_buff_name
    end
    return true
end

local function kick_matches(context, s)
    if not s.target_casting then return false end
    if not s.kick_ready then return false end
    return true
end

local function gouge_matches(context, s)
    if not s.gouge_ready then return false end
    return true
end

local function sprint_matches(context, s)
    if not s.in_combat then return false end
    if not s.sprint_ready then return false end
    return true
end

local function vanish_matches(context, s)
    if not s.in_combat then return false end
    if not s.vanish_ready then return false end
    local vanish_hp = (context.settings and context.settings.combat_vanish_hp) or 20
    -- Research: Vanish as emergency threat drop when HP critical
    if s.hp_pct > vanish_hp then return false end
    return true
end

local function feint_matches(context, s)
    if not s.in_combat then return false end
    if not s.feint_ready then return false end
    -- Research: Feint is a threat drop — only fire when threat is known and high
    local feint_threat = (context.settings and context.settings.combat_feint_threat) or 90
    if s.threat_pct <= 0 or s.threat_pct < feint_threat then return false end
    return true
end

local function hemorrhage_matches(context, s)
    if not s.hemorrhage_ready then return false end
    return true
end

local function backstab_matches(context, s)
    if not s.backstab_ready then return false end
    return true
end

local function ghostly_strike_matches(context, s)
    if not s.ghostly_strike_ready then return false end
    return true
end

local function kidney_shot_matches(context, s)
    if not s.kidney_shot_ready then return false end
    return true
end

local function expose_armor_matches(context, s)
    if not s.expose_armor_ready then return false end
    -- Research: only apply Expose Armor when assigned (conflicts with Sunder/Devastate)
    if not s.expose_assigned then return false end
    return true
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "Stealth", matches = stealth_matches, execute = function(context) return NS.try_cast(SPELLS.Stealth, NS.PLAYER_UNIT, "[COMBAT] Stealth", { skip_range = true }) end },
    { name = "AdrenalineRush", matches = adrenaline_rush_wrapper, execute = function(context) return NS.try_cast(SPELLS.AdrenalineRush, NS.PLAYER_UNIT, "[COMBAT] AdrenalineRush", { skip_range = true }) end },
    { name = "BladeFlurry", matches = blade_flurry_wrapper, execute = function(context) return NS.try_cast(SPELLS.BladeFlurry, NS.PLAYER_UNIT, "[COMBAT] BladeFlurry", { skip_range = true }) end },
    { name = "SliceAndDice", matches = slice_and_dice_wrapper, execute = function(context) return NS.try_cast(SPELLS.SliceAndDice, NS.PLAYER_UNIT, "[COMBAT] SliceAndDice", { skip_range = true }) end },
    { name = "Rupture", matches = rupture_wrapper, execute = function(context) return NS.try_cast(SPELLS.Rupture, context.target, "[COMBAT] Rupture") end },
    { name = "Eviscerate", matches = eviscerate_matches, execute = function(context) return NS.try_cast(SPELLS.Eviscerate, context.target, "[COMBAT] Eviscerate") end },
    { name = "Kick", matches = kick_matches, execute = function(context) return NS.try_cast(SPELLS.Kick, context.target, "[COMBAT] Kick") end },
    { name = "ShivPurge", matches = function(context, s) if shiv_purge_matches(context, s) then context._shiv_purge_name = s.shiv_purge_name return true end return false end, execute = function(context) local name = context._shiv_purge_name or "buff" return NS.try_cast(SPELLS.Shiv, context.target, "[COMBAT] Shiv purge → " .. name, { expected_cooldown = 10 }) end },
    { name = "Disarm", matches = disarm_matches, execute = function(context) local label = context._disarm_buff_name and ("[COMBAT] Dismantle → " .. context._disarm_buff_name) or "[COMBAT] Dismantle" return NS.try_cast(SPELLS.Dismantle, context.target, label, { expected_cooldown = 60 }) end },
    { name = "Gouge", matches = gouge_matches, execute = function(context) return NS.try_cast(SPELLS.Gouge, context.target, "[COMBAT] Gouge") end },
    { name = "Sprint", matches = sprint_matches, execute = function(context) return NS.try_cast(SPELLS.Sprint, NS.PLAYER_UNIT, "[COMBAT] Sprint", { skip_range = true }) end },
    { name = "Vanish", matches = vanish_matches, execute = function(context) return NS.try_cast(SPELLS.Vanish, NS.PLAYER_UNIT, "[COMBAT] Vanish", { skip_range = true }) end },
    { name = "Feint", matches = feint_matches, execute = function(context) return NS.try_cast(SPELLS.Feint, NS.PLAYER_UNIT, "[COMBAT] Feint", { skip_range = true }) end },
    { name = "Hemorrhage", matches = hemorrhage_matches, execute = function(context) return NS.try_cast(SPELLS.Hemorrhage, context.target, "[COMBAT] Hemorrhage") end },
    { name = "GhostlyStrike", matches = ghostly_strike_matches, execute = function(context) return NS.try_cast(SPELLS.GhostlyStrike, context.target, "[COMBAT] GhostlyStrike") end },
    { name = "Backstab", matches = backstab_matches, execute = function(context) return NS.try_cast(SPELLS.Backstab, context.target, "[COMBAT] Backstab") end },
    { name = "KidneyShot", matches = kidney_shot_matches, execute = function(context) return NS.try_cast(SPELLS.KidneyShot, context.target, "[COMBAT] KidneyShot") end },
    { name = "ExposeArmor", matches = expose_armor_matches, execute = function(context) return NS.try_cast(SPELLS.ExposeArmor, context.target, "[COMBAT] ExposeArmor") end },
    { name = "SinisterStrike", matches = sinister_strike_wrapper, execute = function(context) return NS.try_cast(SPELLS.SinisterStrike, context.target, "[COMBAT] SinisterStrike") end },
}

NS.rotation_registry:register("combat", strategies, { get_state = build_state })
NS.log("Rogue combat rotation registered (Tier A)")
return strategies
