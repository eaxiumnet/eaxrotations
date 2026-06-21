-- Rogue Combat priority list.
-- WHAT:  dual-wield sword combat DPS (Sinister Strike / Backstab builders,
--         Slice and Dice always rolling, Blade Flurry for cleave, Revealing
--         Strike debuff uptime, Adrenaline Rush energy injection).
-- WHEN:  in combat, in melee range, dual-wielding.
-- WHY:   TBC combat consensus: SnD rolling > Evis at 4-5 CP > RS debuff
--         (talented) > Blade Flurry AoE > Adrenaline Rush sustain.
-- SAFETY: pattern 14 nil-guards. Energy / CP reads default to 0 to avoid
--          finisher-skipped-false-positives.

local NS = _G.EaxRotations
if not NS then return nil end
local potion_helper = require("shared/potion_helper_sylvanas")
local SPELLS = NS.RogueSpells or {}
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local Stealth = require("shared/stealth_helper_sylvanas")

local SND_BUFF = { 6774, 5171 }
local RUPTURE_DEBUFF = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local BLADE_FLURRY_BUFF = { 13877 }
local ADRENALINE_RUSH_BUFF = { 13750 }
local KIDNEY_SHOT_DEBUFF = { 8643, 408 }
local EVISCERATE_SPELL = SPELLS.Eviscerate
local RUPTURE_SPELL = SPELLS.Rupture

-- Energy tick constants
local ENERGY_TICK = 2.0
local ENERGY_PER_TICK = 20
-- Vigor talent ID (increases energy cap to 110)
local VIGOR_TALENT_ID = 14983

-- Dynamic energy cap: returns 110 if Vigor talented, 100 otherwise
local function get_energy_cap(me)
    if me and NS.has_talent and NS.has_talent(me, VIGOR_TALENT_ID) then
        return 110
    end
    return 100
end
local SND_REFRESH_WINDOW = 3
local RUPTURE_REFRESH_WINDOW = 3

-- Energy / resource thresholds (Research: wowsims canPoolEnergy)
-- wowsims: pool at <= 50 energy when fight >= 6s, not during AR unless <= 30
local ENERGY_LOW_BUILDER = 50
local ENERGY_LOW_FINISHER = 25
local ENERGY_POOL_TTD_FLOOR = 6
local RUPTURE_TTD_FLOOR = 12
-- Bloodlust / Heroism buff IDs (Research: avoid energy capping AR during heroism)
local HEROISM_BUFF = { 2825, 32182 }

-- ============================================================================
-- [ARTISTRY] Energy Tick Optimization
-- ============================================================================
local _last_energy = 0
local _last_tick_time = 0

local function get_next_tick_in(energy, settings)
    local now = NS.time_now and NS.time_now() or 0
    local energy_gained = energy - _last_energy
    
    -- Heuristic: TBC energy ticks are usually 20. 
    -- If gain is 20 (or slightly different due to haste/procs?), it's likely a server tick.
    -- AR gain is higher (40?), Tea is 100.
    if energy_gained >= 19 and energy_gained <= 21 then
        _last_tick_time = now
        _last_energy = energy
        return ENERGY_TICK
    end
    
    if energy_gained > 0 then
        _last_energy = energy
    end

    local time_since_tick = now - _last_tick_time
    if time_since_tick < 0 or time_since_tick > ENERGY_TICK * 2 then
        -- Desync: assume a tick just happened to be safe
        _last_tick_time = now
        return ENERGY_TICK
    end
    return math.max(0, ENERGY_TICK - time_since_tick)
end

local function should_pool_energy(context)
    if not (context.settings and context.settings.combat_energy_tick_sync) then return false end
    
    local energy = context.energy or 0
    local offset = (context.settings and context.settings.combat_energy_tick_offset or 100) / 1000
    local next_tick_in = get_next_tick_in(energy, context.settings)
    
    -- If tick is coming in very soon, wait for it unless we are capping
    if next_tick_in <= offset + 0.1 then
        local projected_energy = energy + ENERGY_PER_TICK
        if projected_energy <= get_energy_cap(context.me) then
            return true
        end
    end
    return false
end

local function should_spend_energy(context, cost)
    local energy = context.energy or 0
    local settings = context.settings or {}
    local offset = (settings.combat_energy_tick_offset or 100) / 1000
    local next_tick_in = get_next_tick_in(energy, settings)
    
    -- Capping risk: if next tick will put us over cap, spend NOW
    local projected_energy = energy + ENERGY_PER_TICK
    if projected_energy > get_energy_cap(context.me) then
        return true
    end
    
    -- Logic: only spend if we just had a tick or the next one is far away
    if next_tick_in > offset + 0.3 then
        return true
    end
    
    -- Or if we are in the "Advance" window (offset)
    if next_tick_in <= offset then
        return true
    end

    return not (settings.combat_energy_tick_sync)
end

-- ============================================================================
-- State builder
-- ============================================================================
local combat_state = {
    is_stealthed = false,
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
    target_casting_interruptible = false,
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
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target

    combat_state.is_stealthed = Stealth.is_stealthed_for_class("rogue")
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
    local ok_casting, casting = false, false
    if target and target.is_casting then
        ok_casting, casting = pcall(function() return target:is_casting() end)
    end
    combat_state.target_casting = ok_casting and casting or false
    combat_state.target_casting_interruptible = combat_state.target_casting and (NS.is_interruptible and NS.is_interruptible(target) or false)
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

    -- Research: energy pooling gates (wowsims canPoolEnergy)
    -- Pool at <= 50 energy when fight >= 6s; during AR, pool only if <= 30
    do
        local energy = combat_state.energy
        local ttd_known = context.ttd_known or false
        local ttd = context.ttd or 999
        local should_pool = false
        if (not ttd_known or ttd >= ENERGY_POOL_TTD_FLOOR) and energy <= ENERGY_LOW_BUILDER then
            if combat_state.has_adrenaline_rush then
                should_pool = energy <= 30
            else
                should_pool = true
            end
        end
        combat_state.energy_low = should_pool
    end
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

    return combat_state
end

local function cooldowns_enabled(context)
    return not context.settings or context.settings.use_cooldowns ~= false
end

-- ============================================================================
-- Match functions
-- ============================================================================
local function stealth_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Stealth, 3.0) then return false end
    if s.in_combat then return false end
    if s.is_stealthed then return false end
    return true
end

local function adrenaline_rush_wrapper(context, s)
    if not cooldowns_enabled(context) then return false end
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    if not s.in_combat then return false end
    if s.has_adrenaline_rush then return false end
    if not s.adrenaline_rush_ready then return false end
    -- Optimal: USE AR during Heroism for maximum combo point generation
    -- Setting defaults to false (use during Heroism) — override via combat_adrenaline_rush_heroism=true to delay
    local delay_during_heroism = context.settings and context.settings.combat_adrenaline_rush_heroism == true
    if delay_during_heroism and s.heroism_active then return false end
    return true
end

local function blade_flurry_wrapper(context, s)
    if not cooldowns_enabled(context) then return false end
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    if not s.in_combat then return false end
    if s.has_blade_flurry then return false end
    if not s.blade_flurry_ready then return false end
    -- TBC Blade Flurry is also a single-target DPS cooldown due to attack speed.
    local min_targets = (context.settings and context.settings.combat_blade_flurry_count) or 1
    if (s.target_count or 0) < min_targets then return false end
    return true
end

local function slice_and_dice_wrapper(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.SliceAndDice, 3.0) then return false end
    if not s.slice_and_dice_ready then return false end
    -- Research: maintain 100% uptime; refresh when <3s remains
    if s.has_snd and not s.snd_needs_refresh then return false end
    if (s.combo_points or 0) < 2 then return false end
    return true
end

local function rupture_wrapper(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Rupture, 2.0) then return false end
    if not s.rupture_ready then return false end
    if s.energy_pool_finisher then return false end
    -- Research: only Rupture when target lives > ttd floor (avoid wasted DoT ticks)
    local ttd_floor = (context.settings and context.settings.combat_rupture_ttd) or RUPTURE_TTD_FLOOR
    if context.ttd_known and context.ttd < ttd_floor then return false end
    if not context.target then return false end
    local rupture_remains = NS.debuff_remains(context.target, RUPTURE_DEBUFF) or 0
    if rupture_remains > RUPTURE_REFRESH_WINDOW then return false end
    if (s.combo_points or 0) < 5 then return false end
    return true
end

local function eviscerate_matches(context, s)
    if not s.eviscerate_ready then return false end
    if s.energy_pool_finisher then return false end
    if (s.energy or 0) < 35 then return false end  -- hard floor: spell costs 35 energy
    -- Optimal: Eviscerate only at 5 CP for maximum damage per combo point
    if (s.combo_points or 0) < 5 then return false end
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
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Shiv, 2.0) then return false end
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
    if (s.hp_pct or 100) > vanish_hp then return false end
    return true
end

local function feint_matches(context, s)
    if not s.in_combat then return false end
    if not s.feint_ready then return false end
    -- Research: Feint is a threat drop — only fire when threat is known and high
    local feint_threat = (context.settings and context.settings.combat_feint_threat) or 90
    if (s.threat_pct or 0) <= 0 or (s.threat_pct or 0) < feint_threat then return false end
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
    -- Skip if target has no armor (API unavailable or already fully reduced)
    if (context.target_armor or 0) <= 0 then return false end
    return true
end

local function evasion_matches(context, s)
    if not s.in_combat then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(26669)) then return false end
    local cd = NS.get_spell_cooldown and NS.get_spell_cooldown(SPELLS.Evasion) or 0
    if cd > 0 then return false end
    local evasion_hp = (context.settings and context.settings.combat_evasion_hp) or 30
    return (s.hp_pct or 100) <= evasion_hp
end

local function cloak_of_shadows_matches(context, s)
    if not s.in_combat then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(31224)) then return false end
    local cd = NS.get_spell_cooldown and NS.get_spell_cooldown(SPELLS.CloakOfShadows) or 0
    if cd > 0 then return false end
    local cloak_hp = (context.settings and context.settings.combat_cloak_hp) or 20
    return (s.hp_pct or 100) <= cloak_hp
end

local function cheap_shot_matches(context, s)
    if not s.is_stealthed then return false end
    if not context.target then return false end
    if not (context.in_melee_range or false) then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(1833)) then return false end
    return true
end

local function garrote_matches(context, s)
    if not s.is_stealthed then return false end
    if not context.target then return false end
    if not (context.in_melee_range or false) then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(703)) then return false end
    local is_caster = context.target.is_casting and context.target:is_casting()
    if not is_caster then return false end
    return true
end

local function deadly_throw_matches(context, s)
    if not s.in_combat then return false end
    if not context.target then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(26679)) then return false end
    local cd = NS.get_spell_cooldown and NS.get_spell_cooldown(SPELLS.DeadlyThrow) or 0
    if cd > 0 then return false end
    local in_melee = context.in_melee_range or false
    local dist = context.target_distance or 30
    return not in_melee and dist <= 30 and (s.combo_points or 0) >= 1
end

local function blind_matches(context, s)
    if not s.in_combat then return false end
    if not context.target then return false end
    if not (context.is_pvp or false) then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(2094)) then return false end
    local cd = NS.get_spell_cooldown and NS.get_spell_cooldown(SPELLS.Blind) or 0
    if cd > 0 then return false end
    local blind_hp = (context.settings and context.settings.combat_blind_hp) or 40
    return (s.hp_pct or 100) <= blind_hp
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "HealthPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end },
    { name = "DamagePotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_damage_potion then return false end
          if not context.should_burst then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS) end },
    { name = "Stealth", matches = stealth_matches, execute = function(context) return Stealth.try(context) end },
    { name = "CheapShot", matches = cheap_shot_matches, execute = function(context) return NS.try_cast(SPELLS.CheapShot, context.target, "[COMBAT] Cheap Shot") end },
    { name = "Garrote", matches = garrote_matches, execute = function(context) return NS.try_cast(SPELLS.Garrote, context.target, "[COMBAT] Garrote") end },
    { name = "SliceAndDice", matches = slice_and_dice_wrapper, execute = function(context) return NS.try_cast(SPELLS.SliceAndDice, NS.PLAYER_UNIT, "[COMBAT] SliceAndDice", { skip_range = true }) end },
    { name = "AdrenalineRush", matches = adrenaline_rush_wrapper, execute = function(context) return NS.try_cast(SPELLS.AdrenalineRush, NS.PLAYER_UNIT, "[COMBAT] AdrenalineRush", { skip_range = true }) end },
    { name = "BladeFlurry", matches = blade_flurry_wrapper, execute = function(context) return NS.try_cast(SPELLS.BladeFlurry, NS.PLAYER_UNIT, "[COMBAT] BladeFlurry", { skip_range = true }) end },
    { name = "Rupture", matches = rupture_wrapper, execute = function(context) return NS.try_cast(SPELLS.Rupture, context.target, "[COMBAT] Rupture") end },
    { name = "Eviscerate", matches = eviscerate_matches, execute = function(context) return NS.try_cast(SPELLS.Eviscerate, context.target, "[COMBAT] Eviscerate") end },
    { name = "ShivPurge", matches = function(context, s) if shiv_purge_matches(context, s) then context._shiv_purge_name = s.shiv_purge_name return true end return false end, execute = function(context) local name = context._shiv_purge_name or "buff" return NS.try_cast(SPELLS.Shiv, context.target, "[COMBAT] Shiv purge → " .. name, { expected_cooldown = 10 }) end },
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
NS.log("Rogue combat rotation registered")
return strategies
