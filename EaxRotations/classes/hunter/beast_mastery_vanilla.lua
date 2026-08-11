-- beast_mastery_vanilla.lua — Hunter Beast Mastery for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  pet-focused DPS (Bestial Wrath, Aimed Shot primary, Multi/Arcane fillers, auto weave).
-- WHEN:  combat, with active pet, when NS.is_vanilla() is true.
-- WHY:   Classic Era hunter APL (wowsims classic p1): Aimed > Multi > Serpent; no Steady Shot.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.HunterSpells or {}
local hunter_core = require("shared/hunter_core_sylvanas")
-- Load-for-side-effect: targeting_sylvanas installs NS.Targeting (consumed
-- nil-guarded by restoration_sylvanas:271 and multidot_engagement_filter:227).
-- The returned table is not used by this file — keep the require, drop the local.
require("shared/targeting_sylvanas")
local pet_manager = require("shared/pet_manager_sylvanas")

local potion_helper = require("shared/potion_helper_sylvanas")

-- ============================================================================
-- Constants
-- ============================================================================
local AUTO_SHOT_BUFFER_MS = 100
local AIMED_SHOT_CAST_MS = 3000     -- Classic Aimed Shot cast; weave in auto gaps (wowsims p1)
local ARCANE_SHOT_MANA_FLOOR = 20   -- Suppress Arcane when mana critical
local MULTI_SHOT_MANA_FLOOR = 15    -- Suppress expensive AoE below 15%

-- Match MM/Survival: casted Aimed needs remain > cast_ms + buffer (NOT can_cast_steady).
local function can_cast_before_auto(cast_ms)
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.ms_until_auto) == "function" then
        local remain = tracker.ms_until_auto()
        return remain == 0 or remain > cast_ms + AUTO_SHOT_BUFFER_MS
    end
    return true
end

local function record_manual_shot()
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.record_manual_shot) == "function" then
        tracker.record_manual_shot()
    end
end
local SERPENT_STING_IDS  = { 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local HUNTER_MARK_IDS    = { 14325, 14324, 14323, 1130 }
local ASPECT_HAWK_IDS    = { 14322, 14321, 14320, 14319, 14318, 13165 }
local RAPTOR_STRIKE_IDS  = { 14266, 14265, 14264, 14263, 14262, 14261, 14260, 2973 }
local CONCUSSIVE_SHOT_IDS = { 5116 }
local VOLLEY_IDS          = { 14295, 14294, 1510 }
local is_item_ready

-- ============================================================================
-- State builder
-- ============================================================================
local state = {
    pet_alive = false, pet_hp = 100, has_pet = false,
    mana_pct = 100, in_combat = false, enemy_count = 1,
    has_hawk = false, has_viper = false, has_cheetah = false,
    has_hunters_mark = false, has_serpent_sting = false,
    arcane_shot_ready = false,
    multi_shot_ready = false,
    aimed_shot_ready = false,
    bestial_wrath_ready = false, rapid_fire_ready = false,
    feign_death_ready = false, mend_pet_ready = false,
    call_pet_ready = false, revive_pet_ready = false,
    hunters_mark_ready = false, serpent_sting_ready = false,
    -- parity features
    sting_mode = "serpent",
    fd_mode = "high_threat",
    multishot_mode = 2,
    use_cooldowns = true,
    misdirection_target = nil,
    trinket_mode = "off",
    shot_buffer = 150,
    threat_level = 0,
    is_mounted = false,
    has_pet_spell = false,
    -- Melee & AoE features (parity parity)
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

-- Schema for safe_state: Pattern 14 nil-guard defaults.
local BM_VANILLA_SCHEMA = {
    pet_alive = false,  pet_hp = 100,  has_pet = false,
    mana_pct = 100,  in_combat = false,  enemy_count = 1,
    has_hawk = false,  has_viper = false,  has_cheetah = false,
    has_hunters_mark = false,  has_serpent_sting = false,
    arcane_shot_ready = false,  multi_shot_ready = false,
    aimed_shot_ready = false,  bestial_wrath_ready = false,
    rapid_fire_ready = false,  feign_death_ready = false,
    mend_pet_ready = false,  call_pet_ready = false,
    revive_pet_ready = false,  hunters_mark_ready = false,
    serpent_sting_ready = false,
    sting_mode = "serpent",  fd_mode = "high_threat",
    multishot_mode = 2,  pull_mode = "combat_only",
    use_cooldowns = true,  use_misdirection = false,
    misdirection_target = nil,  trinket_mode = "off",
    shot_buffer = 150,  threat_level = 0,
    is_mounted = false,  has_pet_spell = false,
    raptor_strike_ready = false,  concussive_shot_ready = false,
    volley_ready = false,  explosive_trap_ready = false,
    aoe_threshold = 3,  use_volley = false,
    use_explosive_trap = false,  trinket_1_id = nil,
    trinket_2_id = nil,  trinket_1_ready = false,
    trinket_2_ready = false,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target

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

    -- Debuff state
    if target then
        state.has_hunters_mark = NS.debuff_up and NS.debuff_up(target, HUNTER_MARK_IDS) or false
        state.has_serpent_sting = NS.debuff_up and NS.debuff_up(target, SERPENT_STING_IDS) or false
    end

    -- Spell readiness
    state.hunters_mark_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.HuntersMark, target) or false
    state.serpent_sting_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.SerpentSting, target) or false
    state.arcane_shot_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.ArcaneShot, target) or false
    state.multi_shot_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.MultiShot, target) or false
    state.aimed_shot_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.AimedShot, target, { expected_cooldown = 6 }) or false
    state.bestial_wrath_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.BestialWrath, me, { skip_range = true }) or false
    state.rapid_fire_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.RapidFire, me, { skip_range = true }) or false
    state.feign_death_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.FeignDeath, me, { skip_range = true }) or false
    state.mend_pet_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.MendPet, me, { skip_range = true }) or false
    state.call_pet_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.CallPet, me, { skip_range = true }) or false
    state.revive_pet_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.RevivePet, me, { skip_range = true }) or false
    -- Raptor Strike ready (melee weaving)
    state.raptor_strike_ready = target and NS.spell_ready and NS.spell_ready(RAPTOR_STRIKE_IDS, target) or false
    -- Concussive Shot ready
    state.concussive_shot_ready = target and NS.spell_ready and NS.spell_ready(CONCUSSIVE_SHOT_IDS, target) or false
    -- Volley ready (AoE)
    state.volley_ready = target and NS.spell_ready and NS.spell_ready(VOLLEY_IDS, target) or false
    -- Explosive Trap ready (AoE)
    state.explosive_trap_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.ExplosiveTrap, me, { skip_range = true, expected_cooldown = 30 }) or false

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

    -- parity settings
    state.sting_mode = spec_kit.setting(context, "sting_mode", "serpent")
    state.fd_mode = spec_kit.setting(context, "fd_mode", (spec_kit.setting_bool(context, "use_threat_drop", false) and "high_threat" or "off"))
    state.multishot_mode = spec_kit.setting_number(context, "multishot_mode", spec_kit.setting_number(context, "aoe_threshold", 2))
    state.use_cooldowns = spec_kit.setting_bool(context, "use_cooldowns", true)
    state.shot_buffer = spec_kit.setting_number(context, "shot_buffer", 150)

    -- Melee & AoE settings (parity parity)
    state.use_melee = spec_kit.setting_bool(context, "use_melee", true)
    state.use_volley = spec_kit.setting_bool(context, "use_volley", false)
    state.use_explosive_trap = spec_kit.setting_bool(context, "use_explosive_trap", false)
    state.aoe_threshold = spec_kit.setting_number(context, "aoe_threshold", spec_kit.setting_number(context, "volley_threshold", 3))
    state.trinket_mode = spec_kit.setting(context, "trinket_mode", "off")

    return spec_kit.safe_state(state, BM_VANILLA_SCHEMA)
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
function is_item_ready(me, item_id)
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

-- OUT OF COMBAT ? Pet management
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

-- Aspect management (OOC ? Cheetah for speed if auto mode)
-- (Handled inline in strategy for simplicity)

-- OUT OF COMBAT ? Aspect of the Hawk on login/respawn
local function ooc_aspect_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if s.in_combat then return false end
    if s.has_hawk then return false end
    if not (NS.spell_ready and NS.spell_ready(SPELLS.AspectOfTheHawk, context.me, { skip_range = true })) then return false end
    return true
end

-- IN COMBAT ? Hunter's Mark
local function hunters_mark_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not context.target then return false end
    if s.has_hunters_mark then return false end
    if not s.hunters_mark_ready then return false end
    return true
end

-- ThreatRedirect (TBC-only, pull window)
-- Mend Pet (in combat)
local function mend_pet_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.pet_alive then return false end
    if (s.pet_hp or 100) > 45 then return false end
    if not s.mend_pet_ready then return false end
    return true
end

-- Bestial Wrath
local function bestial_wrath_matches(context, s)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 120) then return false end
    if not mounted_bail(context, s) then return false end
    if not cooldowns_allowed(context) then return false end
    if not (NS.gate_cooldown_boss_only and NS.gate_cooldown_boss_only(context)) then return false end
    if not s.pet_alive then return false end
    if not s.bestial_wrath_ready then return false end
    return true
end

-- Rapid Fire
local function rapid_fire_matches(context, s)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 300) then return false end
    if not mounted_bail(context, s) then return false end
    if not s.use_cooldowns or not s.in_combat then return false end
    if not s.rapid_fire_ready then return false end
    if not s.aimed_shot_ready then return false end
    local tracker = NS.HunterClipTracker
    if tracker and type(tracker.ms_until_auto) == "function" then
        local remains = tracker.ms_until_auto()
        if remains >= 100 then return false end
    end
    return true
end

-- Multi-Shot (configurable threshold, CC-safe and mana-gated)
local function multi_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if s.multishot_mode == 0 then return false end
    if (s.enemy_count or 0) < (s.multishot_mode or 2) then return false end
    if not s.multi_shot_ready then return false end
    -- CC gate: skip Multi-Shot near breakable CC (sheep/trap/sap)
    if context.has_breakable_cc_nearby then return false end
    -- Mana gate: suppress Multi-Shot below 15% mana (expensive AoE)
    if (s.mana_pct or 100) < MULTI_SHOT_MANA_FLOOR then return false end
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

-- Aimed Shot: Classic Era primary cast (wowsims hunter p1.apl — no Steady Shot)
-- Weave rule matches marksmanship/survival_vanilla: remain > AIMED_SHOT_CAST_MS + buffer.
-- Do NOT use hunter_core.can_cast_steady (TBC Steady ~1.5s + high-haste remain>500).
local function aimed_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not context.target then return false end
    if not s.aimed_shot_ready then return false end
    if (s.mana_pct or 100) < 20 then return false end
    if not can_cast_before_auto(AIMED_SHOT_CAST_MS) then return false end
    return true
end

-- Arcane Shot (instant filler, suppressed at low mana)
local function arcane_shot_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.arcane_shot_ready then return false end
    -- Mana gate: suppress Arcane Shot below 20% mana
    if (s.mana_pct or 100) < ARCANE_SHOT_MANA_FLOOR then return false end
    -- Prefer Aimed Shot when ready (classic priority: Aimed > Multi > Arcane filler)
    if s.aimed_shot_ready then return false end
    -- Check auto-shot clipping for instant
    if not hunter_core.can_cast_instant(500, s.shot_buffer) then return false end
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
-- parity parity match functions (Melee, AoE, Trinkets)
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
    if (s.enemy_count or 0) < (s.aoe_threshold or 3) then return false end
    if not s.volley_ready then return false end
    if context.is_moving then return false end
    return true
end

-- Explosive Trap: AoE ground placement
local function explosive_trap_matches(context, s)
    if not mounted_bail(context, s) then return false end
    if not s.in_combat then return false end
    if not s.use_explosive_trap then return false end
    if (s.enemy_count or 0) < (s.aoe_threshold or 3) then return false end
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
    { name = "HealthPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_health_potion then return false end
          if (context.hp or 100) > 35 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.HEALTH_POTION_IDS) end },
    { name = "ManaPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_mana_potion then return false end
          if (context.mana_pct or 100) > 25 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
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
    -- Pet State: set defensive when pet HP is critically low to preserve it
    { name = "PetDefensive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not state.in_combat then return false end
          if (state.pet_hp or 100) > 40 then return false end
          return true
      end,
      execute = function() return pet_manager.set_defensive() end },
    -- Pet State: set passive when player HP is critically low (survival mode)
    { name = "PetPassive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not state.in_combat then return false end
          if (context.hp or 100) > 25 then return false end
          return true
      end,
      execute = function() return pet_manager.set_passive() end },
    -- Pet State: set aggressive during combat when pet is healthy
    { name = "PetAggressive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not state.in_combat then return false end
          if (state.pet_hp or 100) < 50 then return false end
          return true
      end,
      execute = function() return pet_manager.set_aggressive() end },
    -- 3. OOC: Aspect of the Hawk (initial buff)
    {
        name = "AspectOfTheHawk_OOC",
        matches = ooc_aspect_matches,
        execute = ooc_aspect_execute,
    },
    -- 4. Mend Pet
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
    -- 6. Hunter's Mark
    {
        name = "HuntersMark",
        matches = hunters_mark_matches,
        execute = function(context) return NS.try_cast(SPELLS.HuntersMark, context.target, "[BEAST_MASTERY] HuntersMark") end,
    },
    -- 9. Freezing Trap (OOC CC)
    {
        name = "FreezingTrap",
        matches = freezing_trap_matches,
        execute = function(context) return NS.try_cast(SPELLS.FreezingTrap, context.me, "[BEAST_MASTERY] FreezingTrap", { skip_range = true, expected_cooldown = 30 }) end,
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
    -- 12. Feign Death (threat management)
    {
        name = "FeignDeath",
        matches = feign_death_matches,
        execute = function(context) return NS.try_cast(SPELLS.FeignDeath, context.me, "[BEAST_MASTERY] FeignDeath", { skip_range = true }) end,
    },
    -- 13. Aimed Shot (Classic Era primary cast — wowsims hunter p1.apl)
    {
        name = "AimedShot",
        matches = aimed_shot_matches,
        execute = function(context)
            local result = NS.try_cast(SPELLS.AimedShot, context.target, "[BEAST_MASTERY] AimedShot", { expected_cooldown = 6 })
            -- Casted Aimed: same clip-tracker path as MM/Survival (not instant-shot record)
            if result then record_manual_shot() end
            return result
        end,
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
    -- 18. Arcane Shot (instant filler when Aimed not ready)
    {
        name = "ArcaneShot",
        matches = arcane_shot_matches,
        execute = function(context)
            local result = NS.try_cast(SPELLS.ArcaneShot, context.target, "[BEAST_MASTERY] ArcaneShot")
            if result then hunter_core.record_instant_shot() end
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
        execute = function(context) return NS.try_cast(SPELLS.ExplosiveTrap, context.me, "[BEAST_MASTERY] ExplosiveTrap", { skip_range = true, expected_cooldown = 30 }) end,
    },
    -- 24. Raptor Strike (melee weaving)
    {
        name = "RaptorStrike",
        matches = raptor_strike_matches,
        execute = function(context) return NS.try_cast(RAPTOR_STRIKE_IDS, context.target, "[BEAST_MASTERY] RaptorStrike") end,
    },
}

-- Register strategies
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("beast_mastery", strategies, { get_state = build_state })
end
-- Hunter beast_mastery rotation registered (parity parity)

return strategies
