-- combat_sylvanas.lua -- Rogue Combat DPS for TBC Anniversary (2.5.5).
-- WHAT:  sword/fist DPS spec with SnD/Rupture/Eviscerate finisher priority,
--         energy tick synchronization, Blade Flurry + Adrenaline Rush CDs,
--         Shiv dispel, and stealth opener support. 6 strategies use the
--         declarative strategy DSL (third DSL adopter, first non-warrior).
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors wowsims APL: SnD > Rupture > Eviscerate > SS builder,
--         with energy pooling gating and TTD-aware finisher selection.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no on_update() allocs.
local NS = _G.EaxRotations
if not NS then return nil end
	local potion_helper = require("shared/potion_helper_sylvanas")
	local HitCap = require("shared/hit_cap_tracker_sylvanas")
	local leveling_helpers = require("shared/leveling_helpers_sylvanas")
	local SPELLS = NS.RogueSpells or {}
	local spec_kit = require("shared/spec_kit_sylvanas")
	local dsl = require("shared/strategy_dsl_sylvanas")
	local read_combo_points = require("shared/combo_points_reader_sylvanas")

-- Centralized spell resolver via spec_kit (rank IDs from rogue/class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    AdrenalineRush   = define("AdrenalineRush",   { 13750 }, "AdrenalineRush"),
    Backstab         = define("Backstab",         { 26863, 25300, 11281, 11280, 11279, 8721, 2591, 2590, 2589, 53 }, "Backstab"),
    BladeFlurry      = define("BladeFlurry",      { 13877 }, "BladeFlurry"),
    Blind            = define("Blind",            { 2094 }, "Blind"),
    CheapShot        = define("CheapShot",        { 1833 }, "CheapShot"),
    CloakOfShadows   = define("CloakOfShadows",   { 31224 }, "CloakOfShadows"),
    DeadlyThrow      = define("DeadlyThrow",      { 26679 }, "DeadlyThrow"),
    Evasion          = define("Evasion",          { 26669, 5277 }, "Evasion"),
    Eviscerate       = define("Eviscerate",       { 26865, 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, "Eviscerate"),
    Envenom          = define("Envenom",          { 32684, 32645 }, "Envenom"),
    ExposeArmor      = define("ExposeArmor",      { 26866, 11198, 11197, 8650, 8649, 8647 }, "ExposeArmor"),
    Feint            = define("Feint",            { 27448, 25302, 11303, 8637, 6768, 1966 }, "Feint"),
    Garrote          = define("Garrote",          { 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }, "Garrote"),
    GhostlyStrike    = define("GhostlyStrike",    { 14278 }, "GhostlyStrike"),
    Gouge            = define("Gouge",            { 11286, 11285, 8629, 1777, 1776 }, "Gouge"),
    Hemorrhage       = define("Hemorrhage",       { 26864, 17348, 17347, 16511 }, "Hemorrhage"),
    Kick             = define("Kick",             { 38768, 1769, 1768, 1767, 1766 }, "Kick"),
    KidneyShot       = define("KidneyShot",       { 8643, 408 }, "KidneyShot"),
    Rupture          = define("Rupture",          { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, "Rupture"),
    Shiv             = define("Shiv",             { 5938 }, "Shiv"),
    SinisterStrike   = define("SinisterStrike",   { 26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 }, "SinisterStrike"),
    SliceAndDice     = define("SliceAndDice",     { 6774, 5171 }, "SliceAndDice"),
    Sprint           = define("Sprint",           { 11305, 8696, 2983 }, "Sprint"),
    Stealth          = define("Stealth",          { 1787, 1786, 1785, 1784 }, "Stealth"),
    Vanish           = define("Vanish",           { 26889, 1857, 1856 }, "Vanish"),
}
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local Stealth = require("shared/stealth_helper_sylvanas")

local SND_BUFF = { 6774, 5171 }
local RUPTURE_DEBUFF = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local DEADLY_POISON_DEBUFF = { 27187, 26967, 11356, 11355, 11353, 11352, 11351, 11350, 11349, 2818 }
local BLADE_FLURRY_BUFF = { 13877 }
local ADRENALINE_RUSH_BUFF = { 13750 }
local KIDNEY_SHOT_DEBUFF = { 8643, 408 }
local EVISCERATE_SPELL = ACTION.Eviscerate
local RUPTURE_SPELL = ACTION.Rupture

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

local function read_energy(me)
    if me and type(me.get_power) == "function" then
        local ok, energy = pcall(me.get_power, me, NS.POWER_ENERGY or 3)
        if ok and type(energy) == "number" then return energy end
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

local function get_next_tick_in(energy)
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
    if not spec_kit.setting_bool(context, "combat_energy_tick_sync", false) then return false end
    
    local energy = context.energy or 0
    local offset = spec_kit.setting_number(context, "combat_energy_tick_offset", 100) / 1000
    local next_tick_in = get_next_tick_in(energy)
    
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
    local offset = spec_kit.setting_number(context, "combat_energy_tick_offset", 100) / 1000
    local next_tick_in = get_next_tick_in(energy)

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

    return not spec_kit.setting_bool(context, "combat_energy_tick_sync", false)
end

-- ============================================================================
-- Schema for safe_state (Pattern 14 nil-guard elimination).
-- ============================================================================
local COMBAT_SCHEMA = {
    -- Stealth / buffs
    is_stealthed = false, has_snd = false, has_blade_flurry = false,
    has_adrenaline_rush = false,
    -- Remains
    snd_remains = 0, rupture_remains = 0,
    -- Resources
    combo_points = 0, energy = 100, hp_pct = 100,
    -- Combat
    in_combat = false, is_group = false, enemy_count = 0, target_count = 1,
    -- Target
    target_casting = false, target_casting_interruptible = false,
    -- Energy
    energy_low = false, energy_pool_finisher = false,
    heroism_active = false, threat_pct = 0,
    snd_needs_refresh = false, expose_assigned = false,
    -- Spell readiness
    blade_flurry_ready = false, slice_and_dice_ready = false,
    rupture_ready = false, eviscerate_ready = false,
    envenom_ready = false,
    sinister_strike_ready = false, kick_ready = false,
    gouge_ready = false, sprint_ready = false,
    vanish_ready = false, feint_ready = false,
    hemorrhage_ready = false, backstab_ready = false,
    ghostly_strike_ready = false, kidney_shot_ready = false,
    expose_armor_ready = false,
    -- Shiv
    shiv_ready = false,
    -- Poison
    deadly_poison_stacks = 0,
    hit_cap_rating_needed = 142,
}

-- ============================================================================
-- State builder
-- ============================================================================
local combat_state = {
    is_stealthed = false,
    has_snd = false,
    has_blade_flurry = false,
    has_adrenaline_rush = false,
    snd_remains = 0,
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

    combat_state.is_group = context.is_group or false
    combat_state.is_stealthed = Stealth.is_stealthed_for_class("rogue")
    combat_state.has_snd = me and NS.buff_up(me, SND_BUFF) or false
    combat_state.has_blade_flurry = me and NS.buff_up(me, BLADE_FLURRY_BUFF) or false
    combat_state.has_adrenaline_rush = me and NS.buff_up(me, ADRENALINE_RUSH_BUFF) or false
    combat_state.snd_remains = me and NS.buff_remains(me, SND_BUFF) or 0
    combat_state.combo_points = context.combo_points or 0
    local combo_points = read_combo_points(me, NS.POWER_COMBO or 4)
    if type(combo_points) == "number" then combat_state.combo_points = combo_points end
    combat_state.energy = context.energy or read_energy(me)
    -- IZI SDK: energy_predicted gives projected energy after next tick (better pooling)
    if me and type(me.energy_predicted) == "function" then
        local ok, pred = pcall(me.energy_predicted, me)
        if ok and type(pred) == "number" then
            combat_state.energy_predicted = pred
        else
            combat_state.energy_predicted = combat_state.energy
        end
    else
        combat_state.energy_predicted = combat_state.energy
    end
    combat_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    combat_state.in_combat = context.in_combat or false
    -- IZI SDK: time_in_combat() for opener vs sustained phase decisions
    combat_state.combat_time = context.combat_time or 0
    if me and type(me.time_in_combat) == "function" then
        local ok_t, t = pcall(me.time_in_combat, me)
        if ok_t and type(t) == "number" then combat_state.combat_time = t end
    end
    combat_state.enemy_count = context.enemy_count or context.enemies_count or 1
    local ok_casting, casting = false, false
    if target and target.is_casting then
        ok_casting, casting = pcall(function() return target:is_casting() end)
    end
    combat_state.target_casting = ok_casting and casting or false
    combat_state.target_casting_interruptible = combat_state.target_casting and (NS.is_interruptible and NS.is_interruptible(target) or false)
    combat_state.adrenaline_rush_ready = me and NS.spell_ready(ACTION.AdrenalineRush, me, { skip_range = true, expected_cooldown = 300 }) or false
    combat_state.blade_flurry_ready = me and NS.spell_ready(ACTION.BladeFlurry, me, { skip_range = true, expected_cooldown = 120 }) or false
    combat_state.slice_and_dice_ready = me and NS.spell_ready(ACTION.SliceAndDice, me, { skip_range = true }) or false
    combat_state.rupture_ready = target and NS.spell_ready(ACTION.Rupture, target) or false
    combat_state.eviscerate_ready = target and NS.spell_ready(ACTION.Eviscerate, target) or false
    combat_state.envenom_ready = target and NS.spell_ready(ACTION.Envenom, target) or false
    combat_state.deadly_poison_stacks = target and NS.debuff_stacks and NS.debuff_stacks(target, DEADLY_POISON_DEBUFF) or 0
    combat_state.sinister_strike_ready = target and NS.spell_ready(ACTION.SinisterStrike, target) or false
    combat_state.kick_ready = target and NS.spell_ready(ACTION.Kick, target, { expected_cooldown = 10 }) or false
    combat_state.gouge_ready = target and NS.spell_ready(ACTION.Gouge, target, { expected_cooldown = 10 }) or false
    combat_state.sprint_ready = me and NS.spell_ready(ACTION.Sprint, me, { skip_range = true, expected_cooldown = 180 }) or false
    combat_state.vanish_ready = me and NS.spell_ready(ACTION.Vanish, me, { skip_range = true, expected_cooldown = 300 }) or false
    combat_state.feint_ready = me and NS.spell_ready(ACTION.Feint, me, { skip_range = true, expected_cooldown = 10 }) or false
    combat_state.hemorrhage_ready = target and NS.spell_ready(ACTION.Hemorrhage, target) or false
    combat_state.backstab_ready = target and NS.spell_ready(ACTION.Backstab, target) or false
    combat_state.ghostly_strike_ready = target and NS.spell_ready(ACTION.GhostlyStrike, target, { expected_cooldown = 20 }) or false
    combat_state.kidney_shot_ready = target and NS.spell_ready(ACTION.KidneyShot, target, { expected_cooldown = 20 }) or false
    combat_state.expose_armor_ready = target and NS.spell_ready(ACTION.ExposeArmor, target) or false

    -- Research: energy pooling gates (wowsims canPoolEnergy)
    -- Pool at <= 50 energy when fight >= 6s; during AR, pool only if <= 30
    -- Use energy_predicted for smarter pool decisions (accounts for incoming regen)
    do
        local energy = combat_state.energy
        local predicted = combat_state.energy_predicted or energy
        local ttd_known = context.ttd_known or false
        local ttd = context.ttd or 999
        local should_pool = false
        if (not ttd_known or ttd >= ENERGY_POOL_TTD_FLOOR) and energy <= ENERGY_LOW_BUILDER then
            if combat_state.has_adrenaline_rush then
                should_pool = energy <= 30
            else
                -- If predicted energy will exceed threshold soon, don't pool (act immediately)
                should_pool = predicted <= ENERGY_LOW_BUILDER
            end
        end
        combat_state.energy_low = should_pool
    end
    combat_state.energy_pool_finisher = combat_state.energy < ENERGY_LOW_FINISHER
    combat_state.target_count = context.enemy_count or 1
    combat_state.heroism_active = me and NS.buff_up(me, HEROISM_BUFF) or false
    combat_state.threat_pct = context.threat_pct or 0
    combat_state.snd_needs_refresh = combat_state.has_snd and combat_state.snd_remains <= SND_REFRESH_WINDOW
    combat_state.expose_assigned = spec_kit.setting_bool(context, "combat_expose_assigned", false)

    -- Shiv Purge (PvP buff dispel via Wound Poison)
    combat_state.shiv_ready = target and NS.spell_ready(ACTION.Shiv, target, { expected_cooldown = 10 }) or false
    combat_state.shiv_purge_name = nil
    if combat_state.in_combat and (context.is_pvp or false) and target and CCGateDB.find_best_dispel_target then
        local best_id, _, best_name = CCGateDB.find_best_dispel_target(target, NS)
        if best_id then combat_state.shiv_purge_name = best_name end
    end

    -- Hit cap / expertise awareness
    if HitCap then
        local hit_info = HitCap.get_hit_cap("rogue_melee")
        if hit_info then
            combat_state.hit_cap_rating_needed = hit_info.rating_needed
        end
    end

    return spec_kit.safe_state(combat_state, COMBAT_SCHEMA)
end

local function cooldowns_enabled(context)
    return spec_kit.setting_bool(context, "use_cooldowns", true)
end

-- ============================================================================
-- Match functions
-- ============================================================================
local function kick_matches(context, s)
    -- Route through InterruptManager for cast-window detection + humanization
    -- (mirrors subtlety_sylvanas.lua). Falls back to the state-computed
    -- interruptible flag when the manager is unavailable.
    if not spec_kit.setting_bool(context, "use_interrupt", true) then return false end
    if not s.in_combat then return false end
    if not context.target then return false end
    if not s.kick_ready then return false end
    local mgr = NS.InterruptManager
    if mgr then
        if not (NS.try_interrupt and NS.try_interrupt(context.target)) then return false end
        if not mgr.cast_has_interrupt_window(context.target, context.settings or {}) then return false end
        if not mgr.humanize_interrupt_elapsed(context.target, context.settings or {}) then return false end
    else
        if not s.target_casting_interruptible then return false end
    end
    return true
end

local function stealth_matches(context, s)
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
    -- IZI SDK: skip offensive CD if target is damage-immune (Divine Shield, Ice Block, etc.)
    local target = context.target
    if target and type(target.is_damage_immune) == "function" then
        local ok, immune = pcall(target.is_damage_immune, target)
        if ok and immune then return false end
    end
    -- Wowsims: fire AR at <=40 energy (when energy is actually needed, not at cap)
    if (s.energy or 100) > 40 then return false end
    -- Optimal: USE AR during Heroism for maximum combo point generation
    -- Setting defaults to false (use during Heroism) — override via combat_adrenaline_rush_heroism=true to delay
    local delay_during_heroism = spec_kit.setting_bool(context, "combat_adrenaline_rush_heroism", false)
    if delay_during_heroism and s.heroism_active then return false end
    return true
end

local function blade_flurry_wrapper(context, s)
    if not cooldowns_enabled(context) then return false end
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    if not s.in_combat then return false end
    if s.has_blade_flurry then return false end
    if not s.blade_flurry_ready then return false end
    -- Wowsims APL: Blade Flurry requires Slice and Dice active (don't waste BF time without attack speed buff)
    if not s.has_snd then return false end
    -- TBC Blade Flurry is also a single-target DPS cooldown due to attack speed.
    local min_targets = spec_kit.setting_number(context, "combat_blade_flurry_count", 1)
    if (s.target_count or 0) < min_targets then return false end
    return true
end

local function rupture_wrapper(context, s)
    if not s.rupture_ready then return false end
    if s.energy_pool_finisher then return false end
    -- Research: only Rupture when target lives > ttd floor (avoid wasted DoT ticks)
    local ttd_floor = spec_kit.setting_number(context, "combat_rupture_ttd", RUPTURE_TTD_FLOOR)
    if context.ttd_known and context.ttd < ttd_floor then return false end
    if not context.target then return false end
    local rupture_remains = NS.debuff_remains(context.target, RUPTURE_DEBUFF) or 0
    if rupture_remains > RUPTURE_REFRESH_WINDOW then return false end
    if (s.combo_points or 0) < 5 then return false end
    return true
end

local function shiv_purge_matches(context, s)
    if not spec_kit.setting_bool(context, "use_shiv_purge", true) then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(5938)) then return false end
    if not s.in_combat then return false end
    if not (context.is_pvp or false) then return false end
    if not context.target then return false end
    if not (context.in_melee_range or false) then return false end
    if not s.shiv_ready then return false end
    if not s.shiv_purge_name then return false end
    if spec_kit.setting_bool(context, "shiv_purge_pvp_only", true) then
        local ok, is_player = pcall(function() return context.target:is_player() end)
        if not (ok and is_player) then return false end
    end
    return true
end

local function vanish_matches(context, s)
    if not s.in_combat then return false end
    if not s.vanish_ready then return false end
    local vanish_hp = spec_kit.setting_number(context, "combat_vanish_hp", 20)
    -- Research: Vanish as emergency threat drop when HP critical
    if (s.hp_pct or 100) > vanish_hp then return false end
    return true
end

local function feint_matches(context, s)
    if not s.in_combat then return false end
    if not s.feint_ready then return false end
    -- Research: Feint is a threat drop — only fire when threat is known and high
    local feint_threat = spec_kit.setting_number(context, "combat_feint_threat", 90)
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
    if NS.DRTracker and NS.DRTracker.is_dr_immune and context.target and NS.DRTracker.is_dr_immune(context.target, "stun") then return false end
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

local function cheap_shot_matches(context, s)
    if NS.DRTracker and NS.DRTracker.is_dr_immune and context.target and NS.DRTracker.is_dr_immune(context.target, "stun") then return false end
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

local function blind_matches(context, s)
    if not s.in_combat then return false end
    if not context.target then return false end
    local group_aware = spec_kit.setting_bool(context, "rogue_group_aware_utility", true)
    if not (context.is_pvp or (group_aware and context.is_group) or false) then return false end
    -- IZI SDK: skip Blind if target is already CC'd
    local target = context.target
    if target and type(target.is_cc) == "function" then
        local ok, cc = pcall(target.is_cc, target)
        if ok and cc then return false end
    end
    if not (NS.is_spell_learned and NS.is_spell_learned(2094)) then return false end
    local cd = NS.get_spell_cooldown and NS.get_spell_cooldown(ACTION.Blind) or 0
    if cd > 0 then return false end
    local blind_hp = spec_kit.setting_number(context, "combat_blind_hp", 40)
    return (s.hp_pct or 100) <= blind_hp
end

-- ============================================================================
-- Declarative Strategy DSL definitions (third DSL adopter, first non-warrior)
-- ============================================================================
-- These strategies are compiled from declarative definitions and replace the
-- imperative match/execute pairs in the strategies table below for the same
-- names. Complex conditions (energy pooling, leveling-aware CP thresholds,
-- poison-stack deferral) are kept in `custom` nodes so behavior is preserved
-- exactly. This proves the DSL generalizes beyond warrior rage mechanics.
local DSL_DEFS = {
    {
        name = "SliceAndDice",
        conditions = {
            { type = "custom", fn = function(context, state)
                return true
            end },
            { type = "state", field = "slice_and_dice_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                -- maintain 100% uptime; refresh when <3s remains, skip if fresh
                if state.has_snd and not state.snd_needs_refresh then return false end
                return true
            end },
            { type = "state", field = "combo_points", op = ">=", value = 2 },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.SliceAndDice, NS.PLAYER_UNIT, "[COMBAT] SliceAndDice", { skip_range = true })
        end },
    },
    {
        name = "Eviscerate",
        conditions = {
            { type = "state", field = "eviscerate_ready", op = "truthy" },
            { type = "state", field = "energy_pool_finisher", op = "falsy" },
            { type = "state", field = "energy", op = ">=", value = 35 },
            { type = "custom", fn = function(context, state)
                -- Endgame: 5 CP; low-level/leveling: dump at 4 CP (short fights, no Envenom)
                local min_cp = 5
                local level = leveling_helpers.level_from_context(context, 70)
                if leveling_helpers.is_low_level(level) or context.is_leveling then min_cp = 4 end
                if (state.combo_points or 0) < min_cp then return false end
                -- Prefer Envenom when 5 deadly poison stacks are up
                if (state.deadly_poison_stacks or 0) >= 5 and state.envenom_ready then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.Eviscerate, context.target, "[COMBAT] Eviscerate")
        end },
    },
    {
        name = "Envenom",
        conditions = {
            { type = "state", field = "envenom_ready", op = "truthy" },
            { type = "state", field = "energy_pool_finisher", op = "falsy" },
            { type = "state", field = "energy", op = ">=", value = 35 },
            { type = "state", field = "combo_points", op = ">=", value = 5 },
            { type = "state", field = "deadly_poison_stacks", op = ">=", value = 5 },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.Envenom, context.target, "[COMBAT] Envenom")
        end },
    },
    {
        name = "SinisterStrike",
        conditions = {
            { type = "state", field = "sinister_strike_ready", op = "truthy" },
            { type = "state", field = "energy_low", op = "falsy" },
            { type = "custom", fn = function(context, state)
                -- Energy pooling: only spend if we just had a tick or the next one is far
                local energy = context.energy or 0
                if energy < 85 then
                    if not should_spend_energy(context, 45) then return false end
                end
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.SinisterStrike, context.target, "[COMBAT] SinisterStrike")
        end },
    },
    {
        name = "Gouge",
        conditions = {
            { type = "state", field = "gouge_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.Gouge, context.target, "[COMBAT] Gouge")
        end },
    },
    {
        name = "Sprint",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "sprint_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.Sprint, NS.PLAYER_UNIT, "[COMBAT] Sprint", { skip_range = true })
        end },
    },
}

-- Compile declarative strategies, injecting build_state so unit tests that call
-- strategy.matches(context) without state get a freshly-built state.
local DSL_STRATEGIES = dsl.compile_strategies(DSL_DEFS, { get_state = build_state })

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "HealthPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end },
    { name = "DamagePotion",
      matches = function(context)
          if not context.in_combat then return false end
          if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
          if not context.has_damage_potion then return false end
          if not context.should_burst then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS) end },
    -- Interrupt (reactive, high priority — beats DPS filler). InterruptManager
    -- provides cast-window detection + humanization; state gates readiness.
    { name = "Kick", matches = kick_matches, execute = function(context) return NS.try_cast(ACTION.Kick, context.target, "[COMBAT] Kick interrupt") end },
    { name = "Stealth", matches = stealth_matches, execute = function(context) return Stealth.try(context) end },
    { name = "CheapShot", matches = cheap_shot_matches, execute = function(context) return NS.try_cast(ACTION.CheapShot, context.target, "[COMBAT] Cheap Shot") end },
    { name = "Garrote", matches = garrote_matches, execute = function(context) return NS.try_cast(ACTION.Garrote, context.target, "[COMBAT] Garrote") end },
    { name = "SliceAndDice" },  -- DSL-substituted at runtime
    { name = "AdrenalineRush", matches = adrenaline_rush_wrapper, execute = function(context) return NS.try_cast(ACTION.AdrenalineRush, NS.PLAYER_UNIT, "[COMBAT] AdrenalineRush", { skip_range = true }) end },
    { name = "BladeFlurry", matches = blade_flurry_wrapper, execute = function(context) return NS.try_cast(ACTION.BladeFlurry, NS.PLAYER_UNIT, "[COMBAT] BladeFlurry", { skip_range = true }) end },
    { name = "Rupture", matches = rupture_wrapper, execute = function(context) return NS.try_cast(ACTION.Rupture, context.target, "[COMBAT] Rupture") end },
    { name = "Eviscerate" },  -- DSL-substituted at runtime
    { name = "Envenom" },  -- DSL-substituted at runtime
    { name = "ShivPurge", matches = function(context, s) if shiv_purge_matches(context, s) then context._shiv_purge_name = s.shiv_purge_name return true end return false end, execute = function(context) local name = context._shiv_purge_name or "buff" return NS.try_cast(ACTION.Shiv, context.target, "[COMBAT] Shiv purge → " .. name, { expected_cooldown = 10 }) end },
    { name = "Gouge" },  -- DSL-substituted at runtime
    { name = "Sprint" },  -- DSL-substituted at runtime
    { name = "Vanish", matches = vanish_matches, execute = function(context) return NS.try_cast(ACTION.Vanish, NS.PLAYER_UNIT, "[COMBAT] Vanish", { skip_range = true }) end },
    { name = "Feint", matches = feint_matches, execute = function(context) return NS.try_cast(ACTION.Feint, NS.PLAYER_UNIT, "[COMBAT] Feint", { skip_range = true }) end },
    -- Blind is intentionally positioned near the end of the priority list. It is a
    -- defensive/utility CC that only fires when the rogue is low HP and in a
    -- group or PvP context. Keeping it after core DPS/cooldowns and before filler
    -- builders (Hemorrhage/Backstab/Sinister Strike) ensures it does not steal
    -- GCDs from rotation-essential actions, but still fires before pure filler.
    { name = "Blind", matches = blind_matches, execute = function(context) return NS.try_cast(ACTION.Blind, context.target, "[COMBAT] Blind") end },
    { name = "Hemorrhage", matches = hemorrhage_matches, execute = function(context) return NS.try_cast(ACTION.Hemorrhage, context.target, "[COMBAT] Hemorrhage") end },
    { name = "GhostlyStrike", matches = ghostly_strike_matches, execute = function(context) return NS.try_cast(ACTION.GhostlyStrike, context.target, "[COMBAT] GhostlyStrike") end },
    { name = "Backstab", matches = backstab_matches, execute = function(context) return NS.try_cast(ACTION.Backstab, context.target, "[COMBAT] Backstab") end },
    { name = "KidneyShot", matches = kidney_shot_matches, execute = function(context) return NS.try_cast(ACTION.KidneyShot, context.target, "[COMBAT] KidneyShot") end },
    { name = "ExposeArmor", matches = expose_armor_matches, execute = function(context) return NS.try_cast(ACTION.ExposeArmor, context.target, "[COMBAT] ExposeArmor") end },
    { name = "SinisterStrike" },  -- DSL-substituted at runtime
    { name = "HitCapPriority",
      matches = function(context, s)
          if not s.hit_cap_rating_needed then return false end
          local hit_rating = context.hit_rating
          if not hit_rating then return false end
          local deficit = s.hit_cap_rating_needed - hit_rating
          if deficit <= 30 then return false end
          if NS.log then NS.log(string.format("[COMBAT] Hit cap deficit %d — gating missable abilities", deficit)) end
          return true
      end,
      execute = function() return true end },
}

-- ============================================================================
-- DSL in-place substitution (preserves priority order)
-- ============================================================================
-- Build a lookup of DSL strategies by name and replace the imperative entries
-- at the same indices. This preserves the exact priority order while swapping
-- in the declaratively-compiled match/execute functions.
local DSL_BY_NAME = {}
for i = 1, #DSL_STRATEGIES do
    DSL_BY_NAME[DSL_STRATEGIES[i].name] = DSL_STRATEGIES[i]
end

for i = 1, #strategies do
    local dsl_strategy = DSL_BY_NAME[strategies[i].name]
    if dsl_strategy then
        strategies[i] = dsl_strategy
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("combat", strategies, { get_state = build_state })
end
if NS.log then NS.log("Rogue combat rotation registered") end
return { strategies = strategies, build_state = build_state }
