-- demonology_vanilla.lua — Warlock Demonology for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  DS/Ruin or pet-active (Demonic Sacrifice, Corruption, Shadow Bolt).
-- WHEN:  combat, when NS.is_vanilla() is true.
-- WHY:   Vanilla has no Felguard or Metamorphosis; DS/Ruin is raid meta.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}
local pet_manager = require("shared/pet_manager_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")

local potion_helper = require("shared/potion_helper_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { potions = {} } } end
local TBC_POTIONS = (TBC.ITEMS and TBC.ITEMS.potions) or {}

-- ============================================================================
-- What: Classic Vanilla Warlock Demonology rotation with DoTs, pet management, execute
-- When: Per tick
-- Why: Pet management and DoT cycling need cached state for stable DPS
-- Safety: Spell IDs ordered newest-to-oldest, timers nil-guarded
-- Decision: Curse assignment via context.settings, execute <25% HP
-- ============================================================================

-- ============================================================================
-- Debuff & Buff ID tables
-- ============================================================================
local CORRUPTION_DEBUFF      = { 11672, 11671, 7648, 6223, 6222, 172 }
local CURSE_OF_AGONY_DEBUFF  = { 11713, 11712, 11711, 6217, 1014, 980 }
local CURSE_OF_DOOM_DEBUFF   = { 603 }
local SIPHON_LIFE_DEBUFF     = { 18881, 18880, 18879, 18265 }
local IMMOLATE_DEBUFF        = { 11668, 11667, 11665, 2941, 1094, 707, 348 }
local CURSE_OF_ELEMENTS_DEBUFF = { 11722, 11721, 1490 }
local DEMON_ARMOR_BUFF       = { 11735, 11734, 11733, 1086, 706 }
local FEL_ARMOR_BUFF         = {}  -- TBC-only
local SOUL_LINK_BUFF         = {}  -- TBC-only
local DARK_PACT_BUFF         = {}  -- TBC-only

local LOCAL_SPELLS = {
    DrainLife       = NS.spell_action({ 11700, 11699, 7651, 709, 699, 689 }, "DrainLife"),
    DrainSoul       = NS.spell_action({ 11675, 8289, 8288, 1120 }, "DrainSoul"),
    DarkPact        = NS.spell_action({ 18938, 18937, 18220 }, "DarkPact"),
    Fear            = NS.spell_action({ 6215, 6213, 5782 }, "Fear"),
    HowlOfTerror    = NS.spell_action({ 17928, 5484 }, "HowlOfTerror"),
    CurseWeakness   = NS.spell_action({ 11708, 11707, 7646, 6205, 1108, 702 }, "CurseOfWeakness"),
    CurseTongues    = NS.spell_action({ 11719, 1714 }, "CurseOfTongues"),
    CurseExhaustion = NS.spell_action({ 18223 }, "CurseOfExhaustion"),
    CurseElements   = NS.spell_action({ 11722, 11721, 1490 }, "CurseOfElements"),
    DrainMana       = NS.spell_action({ 11704, 11703, 6226, 5138 }, "DrainMana"),
    HealthFunnel    = NS.spell_action({ 11695, 11694, 11693, 3700, 3699, 3698, 755 }, "HealthFunnel"),
    CreateHealthstone = NS.spell_action({ 11730, 11729, 6202, 6201, 5699 }, "CreateHealthstone"),
    FelDomination   = NS.spell_action({ 18708 }, "FelDomination"),
    DeathCoil       = NS.spell_action({ 17926, 17925, 6789 }, "DeathCoil"),
    ShadowWard      = NS.spell_action({ 11740, 11739, 6229 }, "ShadowWard"),
    DemonArmor      = NS.spell_action({ 11735, 11734, 11733, 1086, 706 }, "DemonArmor"),
    FelArmor        = nil,
    AmplifyCurse    = NS.spell_action({ 18288 }, "AmplifyCurse"),
    BloodFury       = NS.spell_action({ 20572 }, "BloodFury"),
    Berserking      = NS.spell_action({ 20554 }, "Berserking"),
    ArcaneTorrent   = nil,
    CreateSoulstone = NS.spell_action({ 20756, 20755, 20752, 693 }, "CreateSoulstone"),
    Shoot           = NS.spell_action({ 5019 }, "Shoot"),
}

local HEALTHSTONE_IDS = { 19013, 19012, 19011, 19010, 19009, 19008, 19007, 19006, 19005, 19004, 5510, 5509, 5511, 5512 }
local MANA_POTION_IDS = { 13444, 13443 }
local SOULSTONE_BUFF_IDS = { 20765, 20764, 20763, 20762, 20707 }
local SOULSTONE_ITEMS = { 16896, 16895, 16893, 16892, 5232 }
local PET_LOW_HP = 30

local DOT_REFRESH_WINDOW = 1.5
local EXECUTE_HP = 25
local LIFE_TAP_SAFETY_HP = 35
local SPELL_DMG_UPGRADE_RATIO = 1.08
local REFRESH_EXTRA_WINDOW = 1.5

-- ============================================================================
-- State builder (pre-allocated)
-- ============================================================================
local demo_state = {
    has_demon_armor = false,
    has_pet = false,
    pet_hp_pct = 100,
    pet_mana_pct = 100,
    hp_pct = 100,
    mana_pct = 100,
    target_hp = 100,
    enemy_count = 1,
    in_combat = false,
    is_pvp = false,
    corruption_remains = 0,
    agony_remains = 0,
    doom_remains = 0,
    siphon_remains = 0,
    immolate_remains = 0,
    coe_remains = 0,
    nightfall_active = false,
    spell_damage = 0,
    snapshot_corruption_dmg = 0,
    snapshot_siphon_dmg = 0,
    snapshot_immolate_dmg = 0,
    snapshot_target = nil,
    -- Pet
    fel_domination_ready = false,
    health_funnel_ready = false,
    -- Items
    mana_potion_id = nil,
    healthstone_id = nil,
    healthstone_ready = false,
    has_soulstone = false,
    wand_learned = false,
    -- Abilities
    death_coil_ready = false,
    corruption_ready = false,
    agony_ready = false,
    doom_ready = false,
    siphon_ready = false,
    immolate_ready = false,
    shadow_bolt_ready = false,
    life_tap_ready = false,
    dark_pact_ready = false,
    drain_soul_ready = false,
    drain_life_ready = false,
    fear_ready = false,
    howl_ready = false,
    shadow_ward_ready = false,
    amplify_curse_ready = false,
    soulshatter_ready = false,
}

-- Schema for safe_state: Pattern 14 nil-guard defaults.
local DEMO_VANILLA_SCHEMA = {
    has_demon_armor = false,  has_pet = false,  pet_hp_pct = 100,
    pet_mana_pct = 100,  hp_pct = 100,  mana_pct = 100,
    target_hp = 100,  enemy_count = 1,  in_combat = false,
    is_pvp = false,  target_is_casting = false,
    corruption_remains = 0,  agony_remains = 0,  doom_remains = 0,
    siphon_remains = 0,  immolate_remains = 0,  coe_remains = 0,
    nightfall_active = false,  spell_damage = 0,
    snapshot_corruption_dmg = 0,  snapshot_siphon_dmg = 0,
    snapshot_immolate_dmg = 0,  snapshot_target = nil,
    fel_domination_ready = false,  health_funnel_ready = false,
    mana_potion_id = nil,  healthstone_id = nil,  healthstone_ready = false,
    has_soulstone = false,  wand_learned = false,
    death_coil_ready = false,  corruption_ready = false,
    agony_ready = false,  doom_ready = false,  siphon_ready = false,
    immolate_ready = false,  shadow_bolt_ready = false,
    life_tap_ready = false,  dark_pact_ready = false,
    drain_soul_ready = false,  drain_life_ready = false,
    fear_ready = false,  howl_ready = false,  shadow_ward_ready = false,
    amplify_curse_ready = false,  soulshatter_ready = false,
}

local _last_build_state_time = -1
local function build_state(context)
    -- Pattern 6: frame-keyed dedup
    local now = context.now or (NS.time_now and NS.time_now() or 0)
    if now == _last_build_state_time then return spec_kit.safe_state(demo_state, DEMO_VANILLA_SCHEMA) end
    if context.now then _last_build_state_time = now end
    local target = context.target
    local me = context.me or (NS.GetPlayer and NS.GetPlayer())

    demo_state.in_combat = context.in_combat or false
    demo_state.is_pvp = context.is_pvp or false
    demo_state.hp_pct = context.hp or 100
    demo_state.mana_pct = context.mana_pct or 100
    demo_state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    demo_state.enemy_count = context.enemy_count or context.enemies_count or 1

    -- Pet
    demo_state.has_pet = false
    demo_state.pet_hp_pct = 100
    demo_state.pet_mana_pct = 100
    if me then
        local ok, has_pet = pcall(function() return me:has_pet() end)
        demo_state.has_pet = ok and has_pet or false
        if demo_state.has_pet then
            local ok_pet, pet = pcall(function() return me:get_pet() end)
            if ok_pet and pet and pet:is_valid() then
                demo_state.pet_hp_pct = pet.get_health_percentage and pet:get_health_percentage() or 100
                demo_state.pet_mana_pct = pet.get_mana_percentage and pet:get_mana_percentage() or 100
            end
        end
    end

    -- Buffs
    demo_state.has_demon_armor = me and NS.buff_up and NS.buff_up(me, DEMON_ARMOR_BUFF) or false

    -- DoT remains
    if target then
        demo_state.corruption_remains = NS.debuff_remains and NS.debuff_remains(target, CORRUPTION_DEBUFF) or 0
        demo_state.agony_remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_AGONY_DEBUFF) or 0
        demo_state.doom_remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_DOOM_DEBUFF) or 0
        demo_state.siphon_remains = NS.debuff_remains and NS.debuff_remains(target, SIPHON_LIFE_DEBUFF) or 0
        demo_state.immolate_remains = NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF) or 0
        demo_state.coe_remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_ELEMENTS_DEBUFF) or 0
    else
        demo_state.corruption_remains = 0
        demo_state.agony_remains = 0
        demo_state.doom_remains = 0
        demo_state.siphon_remains = 0
        demo_state.immolate_remains = 0
        demo_state.coe_remains = 0
    end

    -- Snapshot state
    demo_state.spell_damage = context.spell_damage or 0
    local target_key = target and (target.get_guid and target:get_guid()) or nil
    if target_key ~= demo_state.snapshot_target then
        demo_state.snapshot_corruption_dmg = 0
        demo_state.snapshot_siphon_dmg = 0
        demo_state.snapshot_immolate_dmg = 0
        demo_state.snapshot_target = target_key
    else
        if demo_state.corruption_remains <= 0 then demo_state.snapshot_corruption_dmg = 0 end
        if demo_state.siphon_remains <= 0 then demo_state.snapshot_siphon_dmg = 0 end
        if demo_state.immolate_remains <= 0 then demo_state.snapshot_immolate_dmg = 0 end
    end

    -- Abilities
    demo_state.death_coil_ready = target and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.DeathCoil, target, { expected_cooldown = 120 }) or false
    demo_state.corruption_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.Corruption, target) or false
    demo_state.agony_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.CurseOfAgony, target) or false
    demo_state.doom_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.CurseOfDoom, target, { expected_cooldown = 60 }) or false
    demo_state.siphon_ready = target and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.SiphonLife, target) or false
    demo_state.immolate_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.Immolate, target) or false
    demo_state.shadow_bolt_ready = target and NS.spell_ready and NS.spell_ready(SPELLS.ShadowBolt, target) or false
    demo_state.life_tap_ready = me and NS.spell_ready and NS.spell_ready(SPELLS.LifeTap, me, { skip_range = true }) or false
    demo_state.dark_pact_ready = me and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.DarkPact, me, { skip_range = true }) or false
    demo_state.drain_soul_ready = target and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.DrainSoul, target) or false
    demo_state.drain_life_ready = target and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.DrainLife, target) or false
    demo_state.fear_ready = target and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.Fear, target) or false
    demo_state.howl_ready = me and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.HowlOfTerror, me, { skip_range = true, expected_cooldown = 40 }) or false
    demo_state.shadow_ward_ready = me and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.ShadowWard, me, { skip_range = true, expected_cooldown = 30 }) or false
    demo_state.fel_domination_ready = me and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.FelDomination, me, { skip_range = true, expected_cooldown = 300 }) or false
    demo_state.health_funnel_ready = me and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.HealthFunnel, me, { skip_range = true }) or false
    demo_state.wand_learned = NS.spell_exists and NS.spell_exists(5019) or false

    -- Items
    demo_state.mana_potion_id = nil
    for _, id in ipairs(MANA_POTION_IDS) do
        if NS.is_item_ready and NS.is_item_ready(id) then demo_state.mana_potion_id = id; break end
    end
    demo_state.healthstone_id = nil
    demo_state.healthstone_ready = false
    if NS.is_item_ready then
        for _, id in ipairs(HEALTHSTONE_IDS) do
            local ok, ready = pcall(NS.is_item_ready, id)
            if ok and ready then
                demo_state.healthstone_id = id
                demo_state.healthstone_ready = true
                break
            end
        end
    end
    demo_state.has_soulstone = me and NS.has_player_buff and NS.has_player_buff(SOULSTONE_BUFF_IDS) or false

    return spec_kit.safe_state(demo_state, DEMO_VANILLA_SCHEMA)
end

-- ============================================================================
-- Snapshot upgrade logic
-- ============================================================================
local function should_snapshot_upgrade(current_dmg, snapshotted_dmg, remains, refresh_window, ratio)
    if remains <= 0 then return true end
    if remains <= refresh_window then return true end
    if snapshotted_dmg <= 0 then return true end
    if current_dmg >= snapshotted_dmg * ratio and remains <= refresh_window + REFRESH_EXTRA_WINDOW then
        return true
    end
    return false
end

-- ============================================================================
-- Helper: select curse based on context
-- ============================================================================
local function select_curse(context, state)
    if context.is_pvp then
        if context.enemy_healer then return "tongues" end
        if context.melee_on_you then return "exhaustion" end
    end
    if (state.enemy_count or 0) >= 3 then return "elements" end
    return "agony"
end

-- ============================================================================
-- Racial gate
-- ============================================================================
local function racial_matches(context, state)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 120) then return false end
    if not context.has_valid_enemy_target then return false end
    if not context.in_combat then return false end
    if context.ttd and context.ttd > 0 and context.ttd < 8 then return false end
    return true
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    -- Auto Damage Potion — gate on context.has_damage_potion (inventory_helper)
    { name = "DamagePotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_damage_potion then return false end
          if not context.should_burst then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS) end },
    -- Pet State: set defensive when pet HP is critically low
    {
        name = "PetDefensive",
        matches = function(context, state)
            if not state.has_pet then return false end
            if not (context.in_combat or false) then return false end
            if (state.pet_hp_pct or 100) > 35 then return false end
            return true
        end,
        execute = function() return pet_manager.set_defensive() end,
    },
    -- Pet State: set passive when player HP critically low (survival mode)
    {
        name = "PetPassive",
        matches = function(context, state)
            if not state.has_pet then return false end
            if not (context.in_combat or false) then return false end
            if (context.hp or state.hp_pct or 100) > 25 then return false end
            return true
        end,
        execute = function() return pet_manager.set_passive() end,
    },
    -- Pet State: set aggressive during combat when pet is healthy
    {
        name = "PetAggressive",
        matches = function(context, state)
            if not state.has_pet then return false end
            if not (context.in_combat or false) then return false end
            if (state.pet_hp_pct or 100) < 50 then return false end
            return true
        end,
        execute = function() return pet_manager.set_aggressive() end,
    },
    -- Death Coil (survival heal + CC)
    {
        name = "DeathCoilSurvival",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.hp_pct or 100) > 30 then return false end
            return state.death_coil_ready
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.DeathCoil, context.target, "[DEMONOLOGY] Death Coil (survival + heal)")
        end,
    },
    -- Healthstone
    {
        name = "Healthstone",
        matches = function(context, state)
            local threshold = (context.settings and context.settings.healthstone_hp) or 0
            if (context.settings and context.settings.use_auto_consumables) == false then return false end
            if (context.settings and context.settings.use_healthstones) == false then return false end
            if threshold <= 0 then return false end
            if (context.hp or 100) > threshold then return false end
            return state and state.healthstone_ready == true
        end,
        execute = function(_, state)
            return state and state.healthstone_id and NS.use_item_by_id and NS.use_item_by_id(state.healthstone_id) or false
        end,
    },
    -- Pet management: Fel Domination (instant summon)
    {
        name = "FelDomination",
        matches = function(context, state)
            if NS.should_use_long_cd and not NS.should_use_long_cd(context, 300) then return false end
            if state.has_pet then return false end
            if not state.fel_domination_ready then return false end
            return true
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.FelDomination, context.me, "[DEMONOLOGY] Fel Domination", { skip_range = true })
        end,
    },
    -- Pet management: Health Funnel
    {
        name = "HealthFunnel",
        matches = function(context, state)
            if not state.has_pet then return false end
            if (state.pet_hp_pct or 100) > PET_LOW_HP then return false end
            if not state.health_funnel_ready then return false end
            return true
        end,
        execute = function(context)
            local pet = context.pet or (NS.GetPet and NS.GetPet())
            if pet then
                return NS.try_cast(LOCAL_SPELLS.HealthFunnel, pet, "[DEMONOLOGY] Health Funnel")
            end
            return false
        end,
    },
    -- Corruption (instant DoT)
    {
        name = "CorruptionDoT",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.corruption_remains or 0) > DOT_REFRESH_WINDOW then return false end
            local ratio = SPELL_DMG_UPGRADE_RATIO
            if (state.corruption_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_corruption_dmg or 0, state.corruption_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            return state.corruption_ready
        end,
        execute = function(context)
            local ok = NS.try_cast(SPELLS.Corruption, context.target, "[DEMONOLOGY] Corruption")
            if ok then demo_state.snapshot_corruption_dmg = demo_state.spell_damage end
            return ok
        end,
    },
    -- Siphon Life (DoT + self-heal)
    {
        name = "SiphonLife",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.siphon_remains or 0) > DOT_REFRESH_WINDOW then return false end
            local ratio = SPELL_DMG_UPGRADE_RATIO
            if (state.siphon_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_siphon_dmg or 0, state.siphon_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            return state.siphon_ready
        end,
        execute = function(context)
            local ok = NS.try_cast(LOCAL_SPELLS.SiphonLife, context.target, "[DEMONOLOGY] Siphon Life")
            if ok then demo_state.snapshot_siphon_dmg = demo_state.spell_damage end
            return ok
        end,
    },
    -- Curse of Doom (long-lived targets)
    {
        name = "CurseOfDoom",
        matches = function(context, state)
            if NS.should_use_long_cd and not NS.should_use_long_cd(context, 60) then return false end
            if not context.target then return false end
            if not context.has_valid_enemy_target then return false end
            if (state.doom_remains or 0) > DOT_REFRESH_WINDOW then return false end
            if context.ttd and context.ttd < 62 then return false end
            return state.doom_ready
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.CurseOfDoom, context.target, "[DEMONOLOGY] Curse of Doom")
        end,
    },
    -- Curse of Agony (default damage curse)
    {
        name = "CurseOfAgony",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            local curse = select_curse(context, state)
            if curse ~= "agony" then return false end
            if (state.agony_remains or 0) > DOT_REFRESH_WINDOW then return false end
            if context.ttd and context.ttd < 8 then return false end
            return state.agony_ready
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.CurseOfAgony, context.target, "[DEMONOLOGY] Curse of Agony")
        end,
    },
    -- Curse of Elements (raid debuff)
    {
        name = "CurseOfElements",
        matches = function(context, state)
            if not context.target then return false end
            local curse = select_curse(context, state)
            if curse ~= "elements" then return false end
            if (state.coe_remains or 0) > 10 then return false end
            return NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.CurseElements, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CurseElements, context.target, "[DEMONOLOGY] Curse of Elements")
        end,
    },
    -- Immolate (DoT)
    {
        name = "ImmolateDoT",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.immolate_remains or 0) > DOT_REFRESH_WINDOW then return false end
            if context.ttd and context.ttd < 5 then return false end
            local ratio = SPELL_DMG_UPGRADE_RATIO
            if (state.immolate_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_immolate_dmg or 0, state.immolate_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            return state.immolate_ready
        end,
        execute = function(context)
            local ok = NS.try_cast(SPELLS.Immolate, context.target, "[DEMONOLOGY] Immolate")
            if ok then demo_state.snapshot_immolate_dmg = demo_state.spell_damage end
            return ok
        end,
    },
    -- Drain Soul (execute <25%)
    {
        name = "DrainSoulExecute",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.target_hp or 100) > EXECUTE_HP then return false end
            if context.is_channeling then return false end
            return state.drain_soul_ready
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.DrainSoul, context.target,
                string.format("[DEMONOLOGY] Drain Soul execute (%.0f%%)", (context.target_hp) or 0))
        end,
    },
    -- Shadow Bolt (filler)
    {
        name = "ShadowBoltFiller",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if context.is_moving then return false end
            return state.shadow_bolt_ready
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.ShadowBolt, context.target, "[DEMONOLOGY] Shadow Bolt filler")
        end,
    },
    -- Life Tap (HP -> Mana)
    {
        name = "LifeTap",
        matches = function(context, state)
            if (state.mana_pct or 100) >= 65 then return false end
            if (state.hp_pct or 100) < LIFE_TAP_SAFETY_HP then return false end
            return state.life_tap_ready
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.LifeTap, context.me, "[DEMONOLOGY] Life Tap", { skip_range = true })
        end,
    },
    -- Dark Pact (pet mana drain)
    {
        name = "DarkPact",
        matches = function(context, state)
            if (state.mana_pct or 100) >= 50 then return false end
            if not state.has_pet then return false end
            if (state.pet_mana_pct or 0) < 20 then return false end
            return state.dark_pact_ready
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.DarkPact, context.me, "[DEMONOLOGY] Dark Pact", { skip_range = true })
        end,
    },
    -- Drain Life (sustain)
    {
        name = "DrainLife",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.hp_pct or 100) > 55 then return false end
            if context.is_channeling then return false end
            return state.drain_life_ready
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.DrainLife, context.target, "[DEMONOLOGY] Drain Life sustain")
        end,
    },
    -- Mana potion
    {
        name = "ManaPotion",
        matches = function(context, state)
            if (state.mana_pct or 100) > 15 then return false end
            return state.mana_potion_id ~= nil
        end,
        execute = function(_, state)
            if NS.use_item_by_id then NS.use_item_by_id(state.mana_potion_id) end
            return true
        end,
    },
    -- Racial abilities
    {
        name = "RacialBerserking",
        matches = function(context, state) return racial_matches(context, state) and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.Berserking, context.me, { skip_range = true }) end,
        execute = function(context) return NS.try_cast(LOCAL_SPELLS.Berserking, context.me, "[DEMONOLOGY] Berserking", { skip_range = true }) end,
    },
    {
        name = "RacialBloodFury",
        matches = function(context, state) return racial_matches(context, state) and NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.BloodFury, context.me, { skip_range = true }) end,
        execute = function(context) return NS.try_cast(LOCAL_SPELLS.BloodFury, context.me, "[DEMONOLOGY] Blood Fury", { skip_range = true }) end,
    },
    -- PvP: Fear
    {
        name = "PvP_Fear",
        matches = function(context)
            if not context.is_pvp then return false end
            if not context.target then return false end
            return demo_state.fear_ready
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.Fear, context.target, "[DEMONOLOGY PvP] Fear")
        end,
    },
    -- PvP: Howl of Terror
    {
        name = "PvP_HowlOfTerror",
        matches = function(context)
            if not context.is_pvp then return false end
            if not context.melee_on_you then return false end
            return demo_state.howl_ready
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.HowlOfTerror, context.me, "[DEMONOLOGY PvP] Howl of Terror")
        end,
    },
    -- PvP: Curse of Exhaustion (kiting)
    {
        name = "PvP_CurseExhaustion",
        matches = function(context, state)
            if not context.is_pvp then return false end
            if not context.target then return false end
            if not context.melee_on_you then return false end
            return NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.CurseExhaustion, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CurseExhaustion, context.target, "[DEMONOLOGY PvP] Curse of Exhaustion kite")
        end,
    },
    -- PvP: Curse of Tongues (vs healers/casters)
    {
        name = "PvP_CurseTongues",
        matches = function(context)
            if not context.is_pvp then return false end
            if not context.target then return false end
            if not context.enemy_caster then return false end
            return NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.CurseTongues, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CurseTongues, context.target, "[DEMONOLOGY PvP] Curse of Tongues")
        end,
    },
    -- Demon Armor (out of combat)
    {
        name = "DemonArmorBuff",
        matches = function(context)
            if context.in_combat then return false end
            if demo_state.has_demon_armor then return false end
            return demo_state.demon_armor_ready
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.DemonArmor, context.me, "[DEMONOLOGY] Demon Armor", { skip_range = true })
        end,
    },
    -- Soulstone (pre-combat)
    {
        name = "SelfSoulstone",
        matches = function(context, state)
            if context.in_combat then return false end
            if state.has_soulstone then return false end
            return NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.CreateSoulstone, context.me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CreateSoulstone, context.me, "[DEMONOLOGY] Create Soulstone (self-buff)", { skip_range = true })
        end,
    },
    -- Health Funnel (heal pet - fallback if no Fel Domination)
    {
        name = "HealthFunnelFallback",
        matches = function(context, state)
            if not state.has_pet then return false end
            if (state.pet_hp_pct or 100) > 30 then return false end
            if not state.health_funnel_ready then return false end
            return true
        end,
        execute = function(context)
            local pet = context.pet or (NS.GetPet and NS.GetPet())
            if pet then
                return NS.try_cast(LOCAL_SPELLS.HealthFunnel, pet, "[DEMONOLOGY] Health Funnel (fallback)")
            end
            return false
        end,
    },
    -- Shadow Ward (PvP - vs shadow damage)
    {
        name = "ShadowWard",
        matches = function(context)
            if not context.is_pvp then return false end
            if not context.enemy_shadow_caster then return false end
            return demo_state.shadow_ward_ready
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.ShadowWard, context.me, "[DEMONOLOGY PvP] Shadow Ward", { skip_range = true })
        end,
    },
    -- Wand (mana conservation fallback)
    {
        name = "Wand",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.wand_learned then return false end
            if (state.mana_pct or 100) >= 15 then return false end
            if not context.has_valid_enemy_target then return false end
            return NS.spell_ready and NS.spell_ready(LOCAL_SPELLS.Shoot, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.Shoot, context.target, "[DEMONOLOGY] Wand (mana conservation)")
        end,
    },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("demonology", strategies, { get_state = build_state })
end
-- [VANILLA] Warlock Demonology rotation registered (S+ tier)
return { strategies = strategies, build_state = build_state }

