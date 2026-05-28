-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-28
-- Change: Classic Vanilla Beast Mastery Hunter rotation
-- =========================================================================
local __eax_file = "classes/hunter/beast_mastery_vanilla.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-28"
local __eax_change = "Classic Vanilla Beast Mastery Hunter rotation"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Hunter Beast Mastery — FrostByte Parity (1-70)
-- Auto-shot timer, pet mgmt, dynamic aspects, stings, threat, pull modes, melee, AoE

-- ============================================================================
-- What: Hunter Beast Mastery priority list with auto-shot timing, pet control, and pull modes
-- When: Evaluated every tick via main_sylvanas.lua dispatcher
-- Why: Priority-list early-exit keeps ranged, pet, and threat checks efficient
-- Safety: Nil-guarded settings; NS.* wrappers; pcall optional shared helpers; conservative fallback behavior
-- ============================================================================
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.HunterSpells or {}
local hunter_core = require("shared/hunter_core_sylvanas")
local targeting = require("shared/targeting_sylvanas")

-- ============================================================================
-- Constants
-- ============================================================================
local AUTO_SHOT_ID = 75
local ARCANE_SHOT_MANA_FLOOR = 20   -- Research Angle 4: <20% = Steady Shot only
local MULTI_SHOT_MANA_FLOOR = 15    -- Suppress expensive AoE below 15%
local SERPENT_STING_IDS  = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local SCORPID_STING_IDS  = { 27015, 14601, 14600, 14599, 14598, 14597, 14596, 14595 }
local VIPER_STING_IDS    = { 27018, 14280, 14279, 3034 }
local HUNTER_MARK_IDS    = { 14325, 14324, 14323, 1130 }
local ASPECT_HAWK_IDS    = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
local ASPECT_VIPER_IDS   = { 34074 }
local ASPECT_CHEETAH_IDS = { 24394, 14322, 5118 }
local MISDIRECTION_ID    = 34477
local WING_CLIP_DEBUFF   = { 2974 }
local RAPTOR_STRIKE_IDS  = { 27014, 14271, 14270, 14269, 14268, 14267, 14266, 14265, 14264, 14263, 14262, 2973 }
local CONCUSSIVE_SHOT_IDS = { 27020, 19802, 5116 }
local VOLLEY_IDS          = { 27021, 1510, 14294, 14295, 14296, 14297 }

-- ============================================================================
-- State builder
-- ============================================================================
local state = {
    pet_alive = false, pet_hp = 100, has_pet = false,
    mana_pct = 100, in_combat = false, enemy_count = 1,
    has_hawk = false, has_viper = false, has_cheetah = false,
    has_hunters_mark = false, has_serpent_sting = false,
    has_scorpid_sting = false, has_viper_sting = false,
    steady_shot_ready = false, arcane_shot_ready = false,
    multi_shot_ready = false, kill_command_ready = false,
    bestial_wrath_ready = false, rapid_fire_ready = false,
    feign_death_ready = false, mend_pet_ready = false,
    call_pet_ready = false, revive_pet_ready = false,
    hunters_mark_ready = false, serpent_sting_ready = false,
    scorpid_sting_ready = false, viper_sting_ready = false,
    -- FrostByte features
    aspect_mode = "auto",
    sting_mode = "serpent",
    fd_mode = "high_threat",
    multishot_mode = 2,
    pull_mode = "combat_only",
    use_cooldowns = true,
    use_misdirection = false,
    misdirection_target = nil,
    trinket_mode = "off",
    sticky_target = false,
    prioritize_markers = false,
    shot_buffer = 150,
    threat_level = 0,
    is_mounted = false,
    has_pet_spell = false,
    wing_clip_active = false,
    -- Melee & AoE features (FrostByte parity)
    use_melee = true,
    raptor_strike_ready = false,
    concussive_shot_ready = false,
    volley_ready = false,
    explosive_trap_ready = false,
    aoe_threshold = 3,
    use_volley = false,
    use_explosive_trap = false,
    trinket_1_id = nil,
    trinket_2_id = nil,
    trinket_1_ready = false,
    trinket_2_ready = false,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target
    local settings = context.settings or {}

    -- Core state
    state.is_mounted = context.is_mounted or false
    state.in_combat = context.in_combat or false
    state.enemy_count = context.enemy_count or context.enemies_count or 1
    state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct and NS.unit_mana_pct(me)) or 100
    state.threat_level = context.threat_level or 0

    -- Pet state
    local pet = hunter_core.get_pet()
    state.has_pet = pet ~= nil
    state.pet_alive = hunter_core.pet_alive()
    state.pet_hp = hunter_core.pet_hp_pct()
    state.has_pet_spell = me and NS.is_spell_learned and NS.is_spell_learned(SPELLS.CallPet) or false

    -- Aspect state
    state.has_hawk = me and NS.buff_up and NS.buff_up(me, ASPECT_HAWK_IDS) or false
    state.has_viper = me and NS.buff_up and NS.buff_up(me, ASPECT_VIPER_IDS) or false
    state.has_cheetah = me and NS.buff_up and NS.buff_up(me, ASPECT_CHEETAH_IDS) or false

    -- Debuff state
    if target then
        state.has_hunters_mark = NS.debuff_up and NS.debuff_up(target, HUNTER_MARK_IDS) or false
        state.has_serpent_sting = NS.debuff_up and NS.debuff_up(target, SERPENT_STING_IDS) or false
        state.has_scorpid_sting = NS.debuff_up and NS.debuff_up(target, SCORPID_STING_IDS) or false
        state.has_viper_sting = NS.debuff_up and NS.debuff_up(target, VIPER_STING_IDS) or false
        state.wing_clip_active = NS.debuff_up and NS.debuff_up(target, WING_CLIP_DEBUFF) or false
    end

    -- Spell readiness
    state.hunters_mark_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.HuntersMark, target) or false
    state.serpent_sting_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.SerpentSting, target) or false
    state.arcane_shot_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.ArcaneShot, target) or false
    state.steady_shot_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.UnavailableClassicHunterShotA, target) or false
    state.multi_shot_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.MultiShot, target) or false
    state.kill_command_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.UnavailableClassicHunterShotB, target) or false
    state.bestial_wrath_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.BestialWrath, me, { skip_range = true }) or false
    state.rapid_fire_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.RapidFire, me, { skip_range = true }) or false
    state.feign_death_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.FeignDeath, me, { skip_range = true }) or false
    state.mend_pet_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.MendPet, me, { skip_range = true }) or false
    state.call_pet_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.CallPet, me, { skip_range = true }) or false
    state.revive_pet_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.RevivePet, me, { skip_range = true }) or false
    -- Viper Sting ready from SPELLS or fallback
    if SPELLS.ViperSting then
        state.viper_sting_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.ViperSting, target) or false
    end
    if SPELLS.ScorpidSting then
        state.scorpid_sting_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.ScorpidSting, target) or false
    end
    -- Raptor Strike ready (melee weaving)
    state.raptor_strike_ready = target and NS.spell_ready and NS.spell_ready(RAPTOR_STRIKE_IDS, target) or false
    -- Concussive Shot ready
    state.concussive_shot_ready = target and NS.spell_ready and NS.spell_ready(CONCUSSIVE_SHOT_IDS, target) or false
    -- Volley ready (AoE)
    state.volley_ready = target and NS.spell_ready and NS.spell_ready(VOLLEY_IDS, target) or false
    -- Explosive Trap ready (AoE)
    state.explosive_trap_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.ExplosiveTrap, target) or false

    -- Trinket state
    if NS.TrinketManager then
        local trinkets = NS.TrinketManager.get_equipped_trinkets and NS.TrinketManager.get_equipped_trinkets()
        if trinkets then
            state.trinket_1_id = trinkets[1] and trinkets[1].item_id or nil
            state.trinket_2_id = trinkets[2] and trinkets[2].item_id or nil
        end
    end
    state.trinket_1_ready = state.trinket_1_id ~= nil and is_item_ready(me, state.trinket_1_id)
    state.trinket_2_ready = state.trinket_2_id ~= nil and is_item_ready(me, state.trinket_2_id)

    -- FrostByte settings
    state.aspect_mode = settings.aspect_mode or "auto"
    state.sting_mode = settings.sting_mode or "serpent"
    state.fd_mode = settings.fd_mode or settings.use_threat_drop and "high_threat" or "off"
    state.multishot_mode = settings.multishot_mode or settings.aoe_threshold or 2
    state.pull_mode = settings.pull_mode or "combat_only"
    state.use_cooldowns = settings.use_cooldowns ~= false
    state.use_misdirection = settings.use_misdirection == true
    state.shot_buffer = settings.shot_buffer or 150
    state.sticky_target = settings.sticky_target == true
    state.prioritize_markers = settings.prioritize_markers == true

    -- Melee & AoE settings (FrostByte parity)
    state.use_melee = settings.use_melee ~= false
    state.use_volley = settings.use_volley == true
    state.use_explosive_trap = settings.use_explosive_trap == true
    state.aoe_threshold = settings.aoe_threshold or settings.volley_threshold or 3
    state.trinket_mode = settings.trinket_mode or "off"

    return state
end

-- ============================================================================
-- Helper: is target worth a sting? (HP% gate)
-- ============================================================================
local function sting_worthwhile(target, hp_gate)
    if not target then return false end
    hp_gate = hp_gate or 30
    local target_hp = target.get_health_percentage and target:get_health_percentage() or 100
    return target_hp >= hp_gate
end

-- ============================================================================
-- Helper: should use cooldowns? (TTD gate)
-- ============================================================================
local function cooldowns_allowed(context)
    return state.use_cooldowns and state.in_combat
end

-- ============================================================================
-- Helper: check item cooldown (trinkets, potions)
-- ============================================================================
local function is_item_ready(me, item_id)
    if not me or not item_id then return false end
    local cd_fn = me.get_item_cooldown
    if cd_fn then
        local start, dur = cd_fn(me, item_id)
        if start and dur then
            local remaining = (start + dur) - (NS.time_now and NS.time_now() or 0)
            return remaining <= 0.5
        end
    end
    return true
end



-- ============================================================================
-- Match functions
-- ============================================================================

-- Mounted bail: skip everything if mounted
local function mounted_bail(context, s)
    if s.is_mounted then return false end
    return true
end

-- OUT OF COMBAT — Pet management
local function call_pet_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if s.in_combat then return false end
    if not s.has_pet_spell then return false end
    if s.has_pet then return false end
    if not s.call_pet_ready then return false end
    return true
end

local function revive_pet_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if s.in_combat then return false end
    if not s.has_pet_spell then return false end
    if s.has_pet and s.pet_alive then return false end
    if s.call_pet_ready and not s.has_pet then
        -- Let Call Pet handle first attempt
        return false
    end
    if not s.revive_pet_ready then return false end
    return true
end

-- Aspect management (OOC — Cheetah for speed if auto mode)
-- (Handled inline in strategy for simplicity)

-- OUT OF COMBAT — Aspect of the Hawk on login/respawn
local function ooc_aspect_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if s.in_combat then return false end
    if s.has_hawk then return false end
    if not (NS.spell_ready and NS.spell_ready(SPELLS.AspectOfTheHawk, context.me, { skip_range = true })) then return false end
    return true
end

-- IN COMBAT — Hunter's Mark
local function hunters_mark_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.HuntersMark, 2.0) then return false end
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not context.target then return false end
    if s.has_hunters_mark then return false end
    if not s.hunters_mark_ready then return false end
    return true
end

-- UnavailableClassicHunterThreat (pull window)
local function misdirection_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.use_misdirection then return false end
    if not s.in_combat then return false end
    local combat_time = context.combat_time or 0
    if combat_time > 6 then return false end
    if not (NS.is_spell_learned and NS.is_spell_learned(MISDIRECTION_ID)) then return false end
    if not (NS.spell_ready and NS.spell_ready(MISDIRECTION_ID)) then return false end
    -- Check if already active
    if NS.has_buff and context.me then
        if NS.has_buff(context.me, MISDIRECTION_ID) then return false end
    end
    return true
end

-- Mend Pet (in combat)
local function mend_pet_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.pet_alive then return false end
    if s.pet_hp > 45 then return false end
    if not s.mend_pet_ready then return false end
    return true
end

-- Aspect management (in combat — Viper if low mana)
local function aspect_viper_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.UnavailableClassicHunterAspect, 3.0) then return false end
    if not mounted_bail(context, s) then return false end
    if s.aspect_mode ~= "auto" then return false end
    if s.has_viper then return false end
    if not hunter_core.should_viper(s.mana_pct) then return false end
    if not (NS.spell_ready and NS.spell_ready(SPELLS.UnavailableClassicHunterAspect, context.me, { skip_range = true })) then return false end
    return true
end

-- Aspect back to Hawk when mana recovers
local function aspect_hawk_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if s.aspect_mode ~= "auto" then return false end
    if s.has_hawk then return false end
    if not hunter_core.should_hawk(s.mana_pct) then return false end
    if not (NS.spell_ready and NS.spell_ready(SPELLS.AspectOfTheHawk, context.me, { skip_range = true })) then return false end
    return true
end

-- Bestial Wrath
local function bestial_wrath_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not cooldowns_allowed(context) then return false end
    if not s.pet_alive then return false end
    if not s.bestial_wrath_ready then return false end
    return true
end

-- Rapid Fire
local function rapid_fire_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not cooldowns_allowed(context) then return false end
    if not s.rapid_fire_ready then return false end
    return true
end

-- Kill Command (off-GCD, high priority)
local function kill_command_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.pet_alive then return false end
    if not s.kill_command_ready then return false end
    return true
end

-- Multi-Shot (configurable threshold, CC-safe and mana-gated)
local function multi_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if s.multishot_mode == 0 then return false end
    if s.enemy_count < s.multishot_mode then return false end
    if not s.multi_shot_ready then return false end
    -- CC gate: skip Multi-Shot near breakable CC (sheep/trap/sap)
    if context.has_breakable_cc_nearby then return false end
    -- Mana gate: suppress Multi-Shot below 15% mana (expensive AoE)
    if s.mana_pct < MULTI_SHOT_MANA_FLOOR then return false end
    -- Check auto-shot clipping
    if not hunter_core.can_cast_instant(500, s.shot_buffer) then return false end
    return true
end

-- Feign Death (threat management)
local function feign_death_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if s.fd_mode == "off" then return false end
    if not hunter_core.should_feign_death(s.threat_level, s.fd_mode) then return false end
    if not s.feign_death_ready then return false end
    return true
end

-- Sting application (Serpent/Scorpid/Viper based on mode)
local function sting_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not context.target then return false end
    if s.sting_mode == "none" or not s.sting_mode then return false end
    -- Check HP gate (don't sting low-HP targets)
    if not sting_worthwhile(context.target, 30) then return false end

    if s.sting_mode == "serpent" then
        if s.has_serpent_sting then return false end
        if not s.serpent_sting_ready then return false end
        return true
    end
    -- Other stings not implemented yet (Scorpid/Viper via middleware)
    return false
end

-- Serpent Sting refresh (within refresh window)
local function serpent_refresh_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not context.target then return false end
    if s.sting_mode ~= "serpent" then return false end
    if not s.has_serpent_sting then return false end
    if not sting_worthwhile(context.target, 30) then return false end
    -- Check remaining time
    local remains = hunter_core.sting_remains(context.target, "serpent")
    if remains > 3 then return false end
    if not s.serpent_sting_ready then return false end
    return true
end

-- Arcane Shot (instant filler, suppressed at low mana per Research Angle 4: <20% = Steady only)
local function arcane_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.arcane_shot_ready then return false end
    -- Mana gate: suppress Arcane Shot below 20% mana (Research Angle 4)
    if s.mana_pct < ARCANE_SHOT_MANA_FLOOR then return false end
    -- Check auto-shot clipping for instant
    if not hunter_core.can_cast_instant(500, s.shot_buffer) then return false end
    return true
end

-- Steady Shot (primary filler, 62+)
local function steady_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.steady_shot_ready then return false end
    -- Check auto-shot clipping for steady
    if not hunter_core.can_cast_steady(s.shot_buffer) then return false end
    -- Not while moving (steady requires standing still)
    if context.is_moving then return false end
    return true
end

-- Freezing Trap (OOC, CC)
local function freezing_trap_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if s.in_combat then return false end
    if not context.target then return false end
    if not (NS.spell_ready and NS.spell_ready(SPELLS.FreezingTrap, context.me, { skip_range = true })) then return false end
    return true
end

-- ============================================================================
-- FrostByte parity match functions (Melee, AoE, Trinkets)
-- ============================================================================

-- Raptor Strike: melee weaving when target in close range
local function raptor_strike_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.use_melee then return false end
    if not context.target then return false end
    local dist = context.distance or context.target_distance or 100
    if dist > 6 then return false end
    if not s.raptor_strike_ready then return false end
    -- Don't clip auto-shot
    if not hunter_core.can_cast_instant(500, s.shot_buffer) then return false end
    return true
end

-- Concussive Shot: slow chasing mobs
local function concussive_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not context.target then return false end
    if not s.concussive_shot_ready then return false end
    -- Only shoot if target is not in melee range (kiting)
    local dist = context.distance or context.target_distance or 100
    if dist < 8 then return false end
    -- Check auto-shot clipping
    if not hunter_core.can_cast_instant(500, s.shot_buffer) then return false end
    return true
end

-- Volley: AoE channeled (respects threshold)
local function volley_matches(context, s)
    if context.is_channeling then return false end
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.use_volley then return false end
    if s.enemy_count < s.aoe_threshold then return false end
    if not s.volley_ready then return false end
    if context.is_moving then return false end
    return true
end

-- Explosive Trap: AoE ground placement
local function explosive_trap_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.use_explosive_trap then return false end
    if s.enemy_count < s.aoe_threshold then return false end
    if not s.explosive_trap_ready then return false end
    return true
end

-- Trinket: on-use trinket activation during combat
local function trinket_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not cooldowns_allowed(context) then return false end
    if s.trinket_mode == "off" then return false end
    if s.trinket_mode == "slot1" or s.trinket_mode == "both" then
        if s.trinket_1_id and s.trinket_1_ready then
            return true
        end
    end
    if s.trinket_mode == "slot2" or s.trinket_mode == "both" then
        if s.trinket_2_id and s.trinket_2_ready then
            return true
        end
    end
    return false
end

-- ============================================================================
-- Execute helpers
-- ============================================================================
local function execute_spell(context, name, id, target, prefix)
    prefix = prefix or "[BEAST_MASTERY]"
    if not id then return false end
    local t = target or context.target or context.me
    if not t then return false end
    return NS.try_cast and NS.try_cast(id, t, prefix .. " " .. name) or false
end

local function execute_misdirection(context)
    local prefix = "[BEAST_MASTERY]"
    local target = nil
    -- Try focus target first
    if NS.GetFocus then
        target = NS.GetFocus()
    end
    -- Fallback to pet
    if not target then
        target = hunter_core.get_pet()
    end
    if not target then
        target = context.me
    end
    if target then
        return NS.try_cast(MISDIRECTION_ID, target, prefix .. " UnavailableClassicHunterThreat", { skip_range = true })
    end
    return false
end

-- ============================================================================
-- Inline strategy helpers for OOC aspect
-- ============================================================================
local function ooc_aspect_execute(context)
    return NS.try_cast(SPELLS.AspectOfTheHawk, context.me, "[BEAST_MASTERY] AspectOfTheHawk", { skip_range = true })
end

-- Trinket execute: use on-use trinkets based on mode
local function execute_trinket(context, s)
    local prefix = "[BEAST_MASTERY]"
    if not s then
        local ctx_built = build_state(context)
        s = ctx_built
    end
    if s.trinket_mode == "slot1" or s.trinket_mode == "both" then
        if s.trinket_1_id and s.trinket_1_ready then
            if NS.use_item_by_id then
                local ok = NS.use_item_by_id(s.trinket_1_id, context.me)
                if ok then return true end
            end
        end
    end
    if s.trinket_mode == "slot2" or s.trinket_mode == "both" then
        if s.trinket_2_id and s.trinket_2_ready then
            if NS.use_item_by_id then
                local ok = NS.use_item_by_id(s.trinket_2_id, context.me)
                if ok then return true end
            end
        end
    end
    return false
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    -- 1. OOC: Call Pet
    {
        name = "CallPet",
        matches = call_pet_matches,
        execute = function(context) return NS.try_cast(SPELLS.CallPet, context.me, "[BEAST_MASTERY] CallPet", { skip_range = true }) end,
    },
    -- 2. OOC: Revive Pet
    {
        name = "RevivePet",
        matches = revive_pet_matches,
        execute = function(context) return NS.try_cast(SPELLS.RevivePet, context.me, "[BEAST_MASTERY] RevivePet", { skip_range = true }) end,
    },
    -- 3. OOC: Aspect of the Hawk (initial buff)
    {
        name = "AspectOfTheHawk_OOC",
        matches = ooc_aspect_matches,
        execute = ooc_aspect_execute,
    },
    -- 4. UnavailableClassicHunterThreat (pull window)
    {
        name = "UnavailableClassicHunterThreat",
        matches = misdirection_matches,
        execute = execute_misdirection,
    },
    -- 5. Mend Pet
    {
        name = "MendPet",
        matches = mend_pet_matches,
        execute = function(context)
            local pet = hunter_core.get_pet()
            if not pet then return false end
            local result = NS.try_cast(SPELLS.MendPet, pet, "[BEAST_MASTERY] MendPet")
            if result then hunter_core.record_mend() end
            return result
        end,
    },
    -- 6. Aspect of the Viper (low mana)
    {
        name = "UnavailableClassicHunterAspect",
        matches = aspect_viper_matches,
        execute = function(context) return NS.try_cast(SPELLS.UnavailableClassicHunterAspect, context.me, "[BEAST_MASTERY] UnavailableClassicHunterAspect", { skip_range = true }) end,
    },
    -- 7. Aspect of the Hawk (mana recovered)
    {
        name = "AspectOfTheHawk",
        matches = aspect_hawk_matches,
        execute = function(context) return NS.try_cast(SPELLS.AspectOfTheHawk, context.me, "[BEAST_MASTERY] AspectOfTheHawk", { skip_range = true }) end,
    },
    -- 8. Hunter's Mark
    {
        name = "HuntersMark",
        matches = hunters_mark_matches,
        execute = function(context) return NS.try_cast(SPELLS.HuntersMark, context.target, "[BEAST_MASTERY] HuntersMark") end,
    },
    -- 9. Freezing Trap (OOC CC)
    {
        name = "FreezingTrap",
        matches = freezing_trap_matches,
        execute = function(context) return NS.try_cast(SPELLS.FreezingTrap, context.target, "[BEAST_MASTERY] FreezingTrap", { skip_range = true }) end,
    },
    -- 10. Bestial Wrath
    {
        name = "BestialWrath",
        matches = bestial_wrath_matches,
        execute = function(context)
            local pet = hunter_core.get_pet()
            local target = pet or context.me
            return NS.try_cast(SPELLS.BestialWrath, target, "[BEAST_MASTERY] BestialWrath", { skip_range = true })
        end,
    },
    -- 11. Rapid Fire
    {
        name = "RapidFire",
        matches = rapid_fire_matches,
        execute = function(context) return NS.try_cast(SPELLS.RapidFire, context.me, "[BEAST_MASTERY] RapidFire", { skip_range = true }) end,
    },
    -- 12. Kill Command (off-GCD, highest DPS)
    {
        name = "UnavailableClassicHunterShotB",
        matches = kill_command_matches,
        execute = function(context) return NS.try_cast(SPELLS.UnavailableClassicHunterShotB, context.target, "[BEAST_MASTERY] UnavailableClassicHunterShotB") end,
    },
    -- 14. Feign Death (threat management)
    {
        name = "FeignDeath",
        matches = feign_death_matches,
        execute = function(context) return NS.try_cast(SPELLS.FeignDeath, context.me, "[BEAST_MASTERY] FeignDeath", { skip_range = true }) end,
    },
    -- 15. Multi-Shot (AoE)
    {
        name = "MultiShot",
        matches = multi_shot_matches,
        execute = function(context)
            local result = NS.try_cast(SPELLS.MultiShot, context.target, "[BEAST_MASTERY] MultiShot")
            if result then hunter_core.record_instant_shot() end
            return result
        end,
    },
    -- 17. Serpent Sting refresh
    {
        name = "SerpentStingRefresh",
        matches = serpent_refresh_matches,
        execute = function(context) return NS.try_cast(SPELLS.SerpentSting, context.target, "[BEAST_MASTERY] SerpentSting") end,
    },
    -- 18. Arcane Shot (instant filler)
    {
        name = "ArcaneShot",
        matches = arcane_shot_matches,
        execute = function(context)
            local result = NS.try_cast(SPELLS.ArcaneShot, context.target, "[BEAST_MASTERY] ArcaneShot")
            if result then hunter_core.record_instant_shot() end
            return result
        end,
    },
    -- 19. Steady Shot (primary filler, 62+)
    {
        name = "UnavailableClassicHunterShotA",
        matches = steady_shot_matches,
        execute = function(context)
            local result = NS.try_cast(SPELLS.UnavailableClassicHunterShotA, context.target, "[BEAST_MASTERY] UnavailableClassicHunterShotA")
            if result then hunter_core.record_steady_start() end
            return result
        end,
    },
    {
        name = "SerpentSting",
        matches = sting_matches,
        execute = function(context) return NS.try_cast(SPELLS.SerpentSting, context.target, "[BEAST_MASTERY] SerpentSting") end,
    },
    -- 20. Trinkets (on-use, during combat, respects cooldown toggle)
    {
        name = "Trinket",
        matches = trinket_matches,
        execute = function(context)
            local s = build_state(context)
            return execute_trinket(context, s)
        end,
    },
    -- 21. Concussive Shot (kiting utility)
    {
        name = "ConcussiveShot",
        matches = concussive_shot_matches,
        execute = function(context) return NS.try_cast(CONCUSSIVE_SHOT_IDS, context.target, "[BEAST_MASTERY] ConcussiveShot") end,
    },
    -- 22. Volley (AoE channeled)
    {
        name = "Volley",
        matches = volley_matches,
        execute = function(context) return NS.try_cast(VOLLEY_IDS, context.target, "[BEAST_MASTERY] Volley") end,
    },
    -- 23. Explosive Trap (AoE ground placement)
    {
        name = "ExplosiveTrap",
        matches = explosive_trap_matches,
        execute = function(context) return NS.try_cast(SPELLS.ExplosiveTrap, context.me, "[BEAST_MASTERY] ExplosiveTrap", { skip_range = true }) end,
    },
    -- 24. Raptor Strike (melee weaving)
    {
        name = "RaptorStrike",
        matches = raptor_strike_matches,
        execute = function(context) return NS.try_cast(RAPTOR_STRIKE_IDS, context.target, "[BEAST_MASTERY] RaptorStrike") end,
    },
}

-- Register strategies
local ok, existing = pcall(NS.rotation_registry.register, NS.rotation_registry, "beast_mastery", strategies, { get_state = build_state })
if not ok then
    NS.rotation_registry:register("beast_mastery", strategies, { get_state = build_state })
end
NS.log("Hunter beast_mastery rotation registered (FrostByte parity)")

return strategies
