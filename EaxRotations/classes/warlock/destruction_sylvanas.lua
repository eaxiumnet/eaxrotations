-- destruction_sylvanas.lua — Warlock Destruction DPS for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies via ACTIONS table with custom match overrides
--         (Shadow Bolt filler, Immolate/Conflagrate, Incinerate, Curse maintenance,
--          demons, AoE, execute, defensives, mana sustain).
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors wowsims destro_fire/destruction.apl: curse > Immolate > Shadowburn (execute) >
--         Incinerate/Shadow Bolt filler; Conflagrate consume after Immolate; Life Tap low mana.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no on_update() allocs.

-- Warlock Destruction priority list.

--
local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end
local SPELLS = NS.WarlockSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local curse_helper = require("shared/warlock_curse_helper_sylvanas")
local CURSE_REFRESH_WINDOW = curse_helper.CURSE_REFRESH_WINDOW
local healthstone_helper = require("shared/warlock_healthstone_sylvanas")
local mana_gem_helper = require("shared/warlock_mana_gem_sylvanas")

-- Centralized spell resolver via spec_kit (rank IDs from class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    Conflagrate     = define("Conflagrate",     { 30912, 27266, 18932, 18931, 18930, 17962 }, "Conflagrate"),
    Corruption      = define("Corruption",      { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    CurseOfAgony    = define("CurseOfAgony",    { 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfAgony"),
    CurseOfDoom     = define("CurseOfDoom",     { 30910, 603 }, "CurseOfDoom"),
    CurseElements   = define("CurseElements",   { 27228, 11722, 11721, 1490 }, "CurseElements"),
    CurseOfRecklessness = define("CurseOfRecklessness", { 27226, 11717, 7659, 7658, 704 }, "CurseOfRecklessness"),
    CurseOfWeakness     = define("CurseOfWeakness",     { 30909, 27224, 11708, 11707, 7646, 6205, 1108, 702 }, "CurseOfWeakness"),
    DeathCoil       = define("DeathCoil",       { 27223, 17926, 17925, 6789 }, "DeathCoil"),
    FelArmor        = define("FelArmor",        { 28189, 28176 }, "FelArmor"),
    Immolate        = define("Immolate",        { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
    Incinerate      = define("Incinerate",      { 32231, 29722 }, "Incinerate"),
    LifeTap         = define("LifeTap",         { 27222, 11689, 11688, 11687, 1456, 1455, 1454 }, "LifeTap"),
    ShadowBolt      = define("ShadowBolt",      { 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
    Shadowburn      = define("Shadowburn",      { 30546, 27263, 18871, 18870, 18869, 18868, 18867, 17877 }, "Shadowburn"),
    Shadowfury      = define("Shadowfury",      { 30414, 30413, 30283 }, "Shadowfury"),
}

-- Debuff and buff ID lists for state queries
local CURSE_OF_DOOM_DEBUFF = { 30910, 603 }
local CURSE_OF_AGONY_DEBUFF = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }
local CURSE_OF_ELEMENTS_DEBUFF = { 27228, 11722, 11721, 1490 }
local IMMOLATE_DEBUFF = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local CORRUPTION_DEBUFF = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local BACKLASH_BUFF = { 34936, 34935 }
local FEL_ARMOR_BUFF = { 28189, 28176 }
local DEMON_ARMOR_BUFF = { 27260, 11735, 11734, 11733, 1086, 706, 687, 696 }

local DEMONIC_SACRIFICE_AURA_ALL = { 18789, 18790, 18791, 18792, 35701 }

-- Local spell actions for spells not exposed in NS.WarlockSpells
local DemonArmorSpell = NS.spell_action({ 27260, 11735, 11734, 11733, 1086, 706, 687 }, "DemonArmor")

local DrainLife = NS.spell_action({ 27220, 27219, 11700, 11699, 7651, 709, 699, 689 }, "DrainLife")
local HealthFunnel = NS.spell_action({ 27259, 11695, 11694, 11693, 3700, 3699, 3698, 755 }, "HealthFunnel")
local DarkPact = NS.spell_action({ 27265, 18938, 18937, 18220 }, "DarkPact")
local SoulFire = NS.spell_action({ 30545, 27211, 17924, 6353 }, "SoulFire")
local SearingPain = NS.spell_action({ 30459, 27210, 17923, 17922, 17921, 17920, 17919, 5676 }, "SearingPain")
local Fear = NS.spell_action({ 5782, 6213, 6215 }, "Fear")
local RainOfFire = NS.spell_action({ 27212, 17954, 17953, 5740 }, "RainOfFire")
local Hellfire = NS.spell_action({ 27213, 11684, 11683, 1949 }, "Hellfire")
local SeedOfCorruption = NS.spell_action({ 27243 }, "SeedOfCorruption")
local CreateHealthstone = NS.spell_action({ 27230, 11730, 11729, 6202, 6201, 5699 }, "CreateHealthstone")
local DemonicSacrifice = NS.spell_action({ 18788 }, "DemonicSacrifice")
local SummonImp = NS.spell_action({ 688 }, "SummonImp")
local SummonVoidwalker = NS.spell_action({ 697 }, "SummonVoidwalker")
local SummonSuccubus = NS.spell_action({ 712 }, "SummonSuccubus")
local SummonFelhunter = NS.spell_action({ 691 }, "SummonFelhunter")
local SummonFelguard = NS.spell_action({ 30146 }, "SummonFelguard")
local FelDomination = NS.spell_action({ 18708 }, "FelDomination")

-- Constants
local IMMOLATE_PANDEMIC_WINDOW = 3.5
local IMMOLATE_MIN_SP_DEFAULT = 400  -- SP below which Immolate is skipped (conservative GCD-positive threshold)
local SHADOWBURN_HP_PCT = 20
local DRAIN_LIFE_HP_THRESHOLD = 40
local LIFE_TAP_MOVING_MIN_HP = 50   -- never Life Tap while moving below this HP (safety gate)
local DARK_PACT_MANA_THRESHOLD = 45
local LIFE_TAP_MIN_INTERVAL = 1.5
local _last_life_tap = 0
local MANA_ITEM_IDS = { 20520, 12662 }  -- Dark Rune, Demonic Rune
local SOUL_SHARD_ITEM = 6265             -- TBC Soul Shard reagent (moved before first use in shadowburn_matches)
local HEALTHSTONE_IDS = { 22105, 22104, 22103, 22102, 22101, 22100 }

-- build_state: compute per-update aura and timing state once for all strategies

-- ============================================================================
-- Schema for safe_state (Pattern 14 nil-guard elimination).
local DESTRO_SCHEMA = {
    immolate_remains = 0,
    corruption_remains = 0,
    cod_remains = 0,
    coa_remains = 0,
    coe_remains = 0,
    recklessness_remains = 0,
    weakness_remains = 0,
    has_backlash = false,
    has_fel_armor = false,
    has_demon_armor = false,
    has_demonic_sacrifice = false,
    hp = 100,
    mana_pct = 100,
    mana_gem_ready = false,
    spell_damage = 0,
    healthstone_ready = false,
}

-- Pre-allocated state (Pattern 4: no per-tick table allocation)
local destro_state = {
    immolate_remains = 0,
    corruption_remains = 0,
    cod_remains = 0,
    coa_remains = 0,
    coe_remains = 0,
    recklessness_remains = 0,
    weakness_remains = 0,
    has_backlash = false,
    has_fel_armor = false,
    has_demon_armor = false,
    has_demonic_sacrifice = false,
    hp = 100,
    mana_pct = 100,
    mana_gem_id = nil,
    mana_gem_ready = false,
    spell_damage = 0,
    healthstone_id = nil,
    healthstone_ready = false,
}
local _last_build_state_time = -1
local function build_state(context)
    -- Pattern 6: frame-keyed dedup
    local now = context.now or (NS.time_now and NS.time_now() or 0)
    if now == _last_build_state_time then return spec_kit.safe_state(destro_state, DESTRO_SCHEMA) end
    if context.now then _last_build_state_time = now end
    local target = context.target
    local me = NS.GetPlayer and NS.GetPlayer()
    local state = destro_state
    if not me then return spec_kit.safe_state(destro_state, DESTRO_SCHEMA) end
    state.immolate_remains = target and NS.debuff_remains(target, IMMOLATE_DEBUFF) or 0
    state.corruption_remains = target and NS.debuff_remains(target, CORRUPTION_DEBUFF) or 0
    state.cod_remains = target and NS.debuff_remains(target, CURSE_OF_DOOM_DEBUFF) or 0
    state.coa_remains = target and NS.debuff_remains(target, CURSE_OF_AGONY_DEBUFF) or 0
    state.coe_remains = target and NS.debuff_remains(target, CURSE_OF_ELEMENTS_DEBUFF) or 0
    state.recklessness_remains = target and NS.debuff_remains(target, curse_helper.CURSE_OF_RECKLESSNESS_DEBUFF) or 0
    state.weakness_remains     = target and NS.debuff_remains(target, curse_helper.CURSE_OF_WEAKNESS_DEBUFF) or 0
    state.has_backlash = me and NS.buff_up(me, BACKLASH_BUFF) or false
    -- Backdraft (Conflagrate instant-followup proc) is a Wrath-era talent;
    -- not present in TBC Classic Anniversary 2.5.5 DBC. Kept as false for compatibility.
    state.has_fel_armor = me and NS.buff_up(me, FEL_ARMOR_BUFF) or false
    state.has_demon_armor = me and NS.buff_up(me, DEMON_ARMOR_BUFF) or false
    state.has_demonic_sacrifice = me and NS.buff_up(me, DEMONIC_SACRIFICE_AURA_ALL) or false
    state.hp = context.hp or 100
    state.mana_pct = context.mana_pct or 100
    state.spell_damage = context.spell_damage or 0
    state.level = context.level or context.player_level or 70
    -- Find ready mana item
    state.mana_gem_id = nil
    for _, id in ipairs(MANA_ITEM_IDS) do
        if NS.is_item_ready and NS.is_item_ready(id) then
            state.mana_gem_id = id
            break
        end
    end
    state.mana_gem_ready = state.mana_gem_id ~= nil
    -- Healthstone: find first available in bags
    state.healthstone_id = nil
    state.healthstone_ready = false
    if NS.is_item_ready then
        for _, id in ipairs(HEALTHSTONE_IDS) do
            if NS.is_item_ready(id) then
                state.healthstone_id = id
                state.healthstone_ready = true
                break
            end
        end
    end
    return spec_kit.safe_state(destro_state, DESTRO_SCHEMA)
end

local ACTIONS = {
    -- Buffs / OOC
    { name = "FelArmor", spell = ACTION.FelArmor, target = "self", kind = "buff", buff = FEL_ARMOR_BUFF, requires_target = false },
    { name = "DemonArmor", spell = DemonArmorSpell, target = "self", kind = "buff", buff = DEMON_ARMOR_BUFF, requires_target = false },
    { name = "CreateHealthstone", spell = CreateHealthstone, target = "self", ooc = true, requires_target = false },
    { name = "LifeTap", spell = ACTION.LifeTap, target = "self", max_mana = 65, min_hp = 40, requires_target = false },
    { name = "DarkPact", spell = DarkPact, target = "self", max_mana = 55, requires_target = false },
    { name = "DrainLife", spell = DrainLife, not_moving = true, min_hp = 40 },
    { name = "HealthFunnel", spell = HealthFunnel, target = "pet", not_moving = true, min_hp = 60, requires_target = false },
    -- Curses (CurseOfDoom before Immolate per regression test)
    { name = "CurseOfDoom", spell = ACTION.CurseOfDoom, debuff = CURSE_OF_DOOM_DEBUFF, refresh = CURSE_REFRESH_WINDOW, cooldown = 60, min_ttd = 62, require_ttd = true, target_not_player = true },
    { name = "CurseOfAgony", spell = ACTION.CurseOfAgony, debuff = CURSE_OF_AGONY_DEBUFF, refresh = CURSE_REFRESH_WINDOW },
    { name = "CurseOfElements", spell = ACTION.CurseElements, debuff = CURSE_OF_ELEMENTS_DEBUFF, refresh = CURSE_REFRESH_WINDOW, group_only = true },
    { name = "CurseOfRecklessness", spell = ACTION.CurseOfRecklessness, debuff = curse_helper.CURSE_OF_RECKLESSNESS_DEBUFF, refresh = CURSE_REFRESH_WINDOW, group_only = true },
    { name = "CurseOfWeakness", spell = ACTION.CurseOfWeakness, debuff = curse_helper.CURSE_OF_WEAKNESS_DEBUFF, refresh = CURSE_REFRESH_WINDOW, group_only = true },
    -- DoTs
    { name = "Corruption", spell = ACTION.Corruption, debuff = CORRUPTION_DEBUFF, refresh = 3 },
    { name = "Immolate", spell = ACTION.Immolate, debuff = IMMOLATE_DEBUFF, refresh = 3, not_moving = true },
    -- Burst / Consume (Conflagrate immediately after Immolate to consume for burst per TBC destro guides; Incinerate is filler while dot rolls)
    { name = "BacklashShadowBolt", spell = ACTION.ShadowBolt, priority = 100 },
    { name = "Conflagrate", spell = ACTION.Conflagrate, moving = true, cooldown = 10 },
    -- Execute (wowsims destro_fire/destruction.apl: Shadowburn before Incinerate/Shadow Bolt filler)
    -- MUST sit above always-matching fillers or Shadowburn is dead while stationary.
    { name = "Shadowburn", spell = ACTION.Shadowburn, cooldown = 15 },
    -- Filler (Incinerate when Immolate active, else Shadow Bolt)
    { name = "Incinerate", spell = ACTION.Incinerate, not_moving = true },
    { name = "ShadowBolt", spell = ACTION.ShadowBolt, not_moving = true },
    { name = "SoulFire", spell = SoulFire, not_moving = true },
    -- LifeTapMoving: placeholder for DSL-compiled strategy (fires while moving to tap mana
    -- instead of Searing Pain). Positioned before SearingPain so it wins the moving filler slot.
    { name = "LifeTapMoving", spell = ACTION.LifeTap, target = "self", moving = true, requires_target = false },
    { name = "SearingPain", spell = SearingPain, moving = true },
    -- AoE
    { name = "SeedOfCorruption", spell = SeedOfCorruption, enemy_count = 3, hit_radius = 15, hit_origin = "target" },
    { name = "RainOfFire", spell = RainOfFire, position = "target", enemy_count = 4, not_moving = true, hit_radius = 8, hit_origin = "target" },
    { name = "Hellfire", spell = Hellfire, position = "self", enemy_count = 4, not_moving = true, hit_radius = 10, hit_origin = "me" },
    -- CC / Emergency (DeathCoil here is self-HP survival, not APL target-execute)
    { name = "Shadowfury", spell = ACTION.Shadowfury, cooldown = 20 },
    { name = "DeathCoil", spell = ACTION.DeathCoil, max_hp = 35, cooldown = 120 },
    { name = "Fear", spell = Fear, cooldown = 15, target_not_player = true },
    { name = "DemonicSacrifice", spell = DemonicSacrifice, target = "self", ooc = true, requires_target = false },
    -- Pet summons
    { name = "SummonImp", spell = SummonImp, target = "self", ooc = true, requires_target = false },
    { name = "SummonVoidwalker", spell = SummonVoidwalker, target = "self", ooc = true, requires_target = false },
    { name = "SummonSuccubus", spell = SummonSuccubus, target = "self", ooc = true, requires_target = false },
    { name = "SummonFelhunter", spell = SummonFelhunter, target = "self", ooc = true, requires_target = false },
    { name = "SummonFelguard", spell = SummonFelguard, target = "self", ooc = true, requires_target = false },
    { name = "FelDomination", spell = FelDomination, target = "self", cooldown = 900, requires_target = false },
}

local function select_curse(context, state)
    local assigned = spec_kit.setting(context, "warlock_assigned_curse", "none")
    if assigned ~= "none" then return assigned end

    local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
    if curse_mode == "agony" then return "agony" end
    if curse_mode == "elements" then return "elements" end
    if curse_mode == "doom" then return "doom" end
    if curse_mode == "recklessness" then return "recklessness" end
    if curse_mode == "weakness" then return "weakness" end
    if curse_mode == "none" then return nil end
    -- Group/raid curse auto-selection is gated by player setting (default off)
    if spec_kit.setting_bool(context, "warlock_curse_group_aware", false) then
        local reck_threshold = spec_kit.setting_number(context, "warlock_curse_reck_threshold", 2)
        if context.is_group and (context.physical_dps_count or 0) >= reck_threshold then return "recklessness" end
    end
    -- Auto mode: Doom for long fights (TTD >= 60s), Agony for short fights.
    -- CoD needs ~60s to deal its damage, so it's a DPS loss on short-lived targets.
    local ttd = context.ttd or 999
    if ttd >= 60 then return "doom" end
    return "agony"
end

-- Centralized assigned-curse gate (strict: when user sets Agony or assigned=agony, no CoE etc)
local function assigned_curse_blocks(context, desired)
    local assigned = spec_kit.setting(context, "warlock_assigned_curse", "none")
    if assigned ~= "none" then
        return assigned ~= desired
    end
    local mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
    if mode == "none" then return true end
    if mode ~= "auto" and mode ~= desired then return true end
    return false
end

local function other_curse_active(state, this_curse)
    return curse_helper.other_curse_active(state, this_curse)
end

local function backlash_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if not state.has_backlash then return false end
    return true
end

local function searing_pain_matches(context, action, state)
    if not context.target then return false end
    if not NS.spell_ready(action.spell, context.target) then return false end
    return true
end


local function soul_fire_matches(context, action, state)
    if NS.has_item and not NS.has_item(SOUL_SHARD_ITEM) then return false end
    return true
end

local function corruption_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if (state.corruption_remains or 0) > 3 then return false end
    return true
end

local function curse_of_agony_matches(context, action, state)
    if assigned_curse_blocks(context, "agony") then return false end
    if select_curse(context, state) ~= "agony" then return false end
    if not state then return false end
    state = state or {}
    if (state.coa_remains or 0) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(state, "agony") then return false end
    return NS.spell_ready(action.spell, context.target)
end

local function curse_of_elements_matches(context, action, state)
    if assigned_curse_blocks(context, "elements") then return false end
    if select_curse(context, state) ~= "elements" then return false end
    if not state then return false end
    state = state or {}
    if (state.coe_remains or 0) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(state, "elements") then return false end
    return NS.spell_ready(action.spell, context.target)
end

local function curse_of_recklessness_matches(context, action, state)
    if assigned_curse_blocks(context, "recklessness") then return false end
    if select_curse(context, state) ~= "recklessness" then return false end
    if not state then return false end
    state = state or {}
    if (state.recklessness_remains or 0) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(state, "recklessness") then return false end
    return NS.spell_ready(action.spell, context.target)
end

local function curse_of_weakness_matches(context, action, state)
    if assigned_curse_blocks(context, "weakness") then return false end
    if select_curse(context, state) ~= "weakness" then return false end
    if not state then return false end
    state = state or {}
    if (state.weakness_remains or 0) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(state, "weakness") then return false end
    return NS.spell_ready(action.spell, context.target)
end

local function drain_life_matches(context, action, state)
    if context.is_channeling then return false end
    if not state then return false end
    state = state or {}
    if (state.hp or 100) > DRAIN_LIFE_HP_THRESHOLD then return false end
    return true
end

local function health_funnel_matches(context, action, state)
    local pet = NS.GetPet()
    if not pet then return false end
    if ((NS.unit_health_pct and NS.unit_health_pct(pet)) or 100) > 50 then return false end
    return true
end

local function dark_pact_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if (state.mana_pct or 100) > DARK_PACT_MANA_THRESHOLD then return false end
    return true
end

local function fel_armor_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.has_fel_armor then return false end
    return true
end

local function demon_armor_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.has_fel_armor then return false end
    if state.has_demon_armor then return false end
    return true
end


local function create_healthstone_matches(context, action, state)
    if NS.has_item and not NS.has_item(SOUL_SHARD_ITEM) then return false end
    if context.in_combat then return false end
    if context.has_valid_enemy_target then return false end
    return true
end

local function summon_pet_matches(context, action, state)
    if context.in_combat then return false end
    -- Do NOT re-summon if Demonic Sacrifice aura is already active
    if state and state.has_demonic_sacrifice then return false end
    local pet = NS.GetPet()
    if pet and NS.unit_alive(pet) then return false end
    -- Spec-aware pet preference: only summon the preferred pet type
    -- This prevents summoning Imp (first in ACTIONS) when player wants Succubus
    local pref = spec_kit.setting(context, "destro_pet_preference", "auto")
    if pref == "auto" then
        -- Default: Succubus for shadow builds (Shadow Bolt filler), Imp for fire (Incinerate filler)
        -- Heuristic: if Incinerate is learned (fire playstyle), prefer Imp; otherwise Succubus
        if NS.is_spell_learned and NS.is_spell_learned(32231) then
            pref = "imp"
        else
            pref = "succubus"
        end
    end
    if action.name == "SummonImp" then return pref == "imp" end
    if action.name == "SummonSuccubus" then return pref == "succubus" end
    -- Voidwalker/Felhunter/Felguard: only if explicitly preferred (not in auto mode)
    if action.name == "SummonFelhunter" then return pref == "felhunter" end
    if action.name == "SummonVoidwalker" then return pref == "voidwalker" end
    if action.name == "SummonFelguard" then return pref == "felguard" end
    return false
end

local function demonic_sacrifice_imp_matches(context, action, state)
    if context.in_combat then return false end
    -- Pre-pull buff: allow even with a target selected (you sac BEFORE pulling)
    -- Only sac when we have a pet alive and no DS aura yet
    if state and state.has_demonic_sacrifice then return false end
    local pet = NS.GetPet()
    if not pet or not NS.unit_alive(pet) then return false end
    return NS.spell_ready(DemonicSacrifice, context.me, { skip_range = true })
end

local function death_coil_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if (state.hp or 100) > 35 then return false end
    return true
end

local function fear_matches(context, action, state)
    if not context.target then return false end
    -- IZI SDK: skip Fear if target is already CC'd
    local target = context.target
    if target and type(target.is_cc) == "function" then
        local ok, cc = pcall(target.is_cc, target)
        if ok and cc then return false end
    end
    if not NS.spell_ready(action.spell, context.target) then return false end
    return true
end

local function shadowfury_matches(context, action, state)
    local group_aware = spec_kit.setting_bool(context, "warlock_group_aware_utility", true)
    if not (context.is_pvp or (group_aware and context.is_group)) then return false end
    -- AoE stun: only worth casting with 2+ enemies nearby or in PvP
    if not context.is_pvp and (context.enemy_count or 0) < 2 then return false end
    if not NS.spell_ready(action.spell, NS.PLAYER_UNIT, { skip_range = true }) then return false end
    return true
end

local function aoe_matches(context, action, state)
    if context.is_channeling then return false end
    local need = action.enemy_count or 0
    if need > 0 then
        local ok = false
        if action.hit_radius and NS.aoe_count_meets then
            ok = NS.aoe_count_meets(need, action.hit_radius, {
                around = action.hit_origin or "me",
                target = context.target,
                context = context,
            })
        else
            ok = (context.enemy_count or context.enemies_count or 0) >= need
        end
        if not ok then return false end
    end
    if not (NS.spell_ready and NS.spell_ready(action.spell, context.target)) then return false end
    if context.is_moving and action.not_moving then return false end
    return true
end

-- ============================================================================
-- Declarative Strategy DSL
-- ============================================================================
local DSL_DEFS = {
    {
        name = "Immolate",
        conditions = {
            { type = "custom", fn = function(context, state)
                -- Toggle: skip Immolate entirely when disabled (speed kills / pure SB spam)
                if not spec_kit.setting_bool(context, "destro_use_immolate", true) then return false end
                return true
            end },
            { type = "custom", fn = function(context, state)
                local min_sp = spec_kit.setting_number(context, "destro_immolate_min_sp", IMMOLATE_MIN_SP_DEFAULT)
                if (state.level or 70) >= 40 and (state.spell_damage or 0) < min_sp then return false end
                if (state.immolate_remains or 0) > IMMOLATE_PANDEMIC_WINDOW then return false end
                return NS.should_refresh_dot and NS.should_refresh_dot((state.immolate_remains or 0), 1.5, context.ttd, 15)
            end },
        },
        action = { type = "cast", spell = ACTION.Immolate, target = "target", label = "[DESTRUCTION] Immolate" },
    },
    {
        name = "Conflagrate",
        conditions = {
            { type = "state", field = "immolate_remains", op = ">", value = 0 },
            { type = "custom", fn = function(context, state)
                if context.ttd_known and context.ttd < 3 then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Conflagrate, target = "target", label = "[DESTRUCTION] Conflagrate" },
    },
    {
        name = "Shadowburn",
        conditions = {
            { type = "context", field = "target", op = "!=", value = nil },
            { type = "custom", fn = function(context, state)
                if NS.has_item and not NS.has_item(SOUL_SHARD_ITEM) then return false end
                local hp_threshold = spec_kit.setting_number(context, "destro_shadowburn_hp", SHADOWBURN_HP_PCT)
                if not (NS.is_execute_phase and NS.is_execute_phase(context.target_hp, hp_threshold)) then return false end
                return NS.spell_ready(ACTION.Shadowburn, context.target)
            end },
        },
        action = { type = "cast", spell = ACTION.Shadowburn, target = "target", label = "[DESTRUCTION] Shadowburn" },
    },
    {
        name = "Incinerate",
        conditions = {
            { type = "context", field = "is_moving", op = "==", value = false },
            { type = "state", field = "immolate_remains", op = ">", value = 0 },
            { type = "custom", fn = function(context, state)
                if context.ttd_known and context.ttd < 6 then return false end
                return NS.spell_ready(ACTION.Incinerate, context.target)
            end },
        },
        action = { type = "cast", spell = ACTION.Incinerate, target = "target", label = "[DESTRUCTION] Incinerate" },
    },
    {
        name = "CurseOfDoom",
        conditions = {
            { type = "custom", fn = function(context, state)
                if assigned_curse_blocks(context, "doom") then return false end
                if select_curse(context, state) ~= "doom" then return false end
                if not (NS.should_use_long_cd and NS.should_use_long_cd(context, 60)) then return false end
                if (state.cod_remains or 0) > CURSE_REFRESH_WINDOW then return false end
                if other_curse_active(state, "doom") then return false end
                return NS.spell_ready(ACTION.CurseOfDoom, context.target)
            end },
        },
        action = { type = "cast", spell = ACTION.CurseOfDoom, target = "target", label = "[DESTRUCTION] Curse of Doom" },
    },
    {
        name = "LifeTap",
        conditions = {
            { type = "custom", fn = function(context, state)
                if context.is_casting or context.is_channeling then return false end
                if (NS.time_now() - _last_life_tap) < LIFE_TAP_MIN_INTERVAL then return false end
                return true
            end },
            { type = "custom", fn = function(context, state)
                -- Configurable mana threshold (default 20% per user request)
                local mana_thresh = spec_kit.setting_number(context, "destro_life_tap_mana", 20)
                return (state.mana_pct or 100) <= mana_thresh
            end },
            { type = "custom", fn = function(context, state)
                -- Safety gate: configurable min HP (default 50% per user request)
                local min_hp = spec_kit.setting_number(context, "destro_life_tap_min_hp", 50)
                return (state.hp or 100) >= min_hp
            end },
        },
        action = { type = "custom", fn = function(context, state)
            _last_life_tap = NS.time_now()
            return NS.try_cast(ACTION.LifeTap, context.me or NS.GetPlayer() or NS.PLAYER_UNIT, "[DESTRUCTION] Life Tap", { skip_range = true })
        end },
    },
    {
        -- Life Tap while moving: when moving and mana isn't full, tap for mana
        -- instead of casting Searing Pain. Safety-gated on HP so we don't kill ourselves.
        name = "LifeTapMoving",
        conditions = {
            { type = "context", field = "is_moving", op = "==", value = true },
            { type = "custom", fn = function(context, state)
                if context.is_casting or context.is_channeling then return false end
                if (NS.time_now() - _last_life_tap) < LIFE_TAP_MIN_INTERVAL then return false end
                -- Only tap if mana isn't already full
                if (state.mana_pct or 100) >= 99 then return false end
                -- Safety gate: don't Life Tap if HP too low (default 50%)
                local min_hp = spec_kit.setting_number(context, "destro_life_tap_min_hp", LIFE_TAP_MOVING_MIN_HP)
                if (state.hp or 100) < min_hp then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            _last_life_tap = NS.time_now()
            return NS.try_cast(ACTION.LifeTap, context.me or NS.GetPlayer() or NS.PLAYER_UNIT, "[DESTRUCTION] Life Tap (moving)", { skip_range = true })
        end },
    },
}

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    local custom_matches
    if action.name == "BacklashShadowBolt" then
        custom_matches = function(context, state) return backlash_matches(context, action, state) end
    elseif action.name == "SearingPain" then
        custom_matches = function(context, state) return searing_pain_matches(context, action, state) end
    elseif action.name == "SoulFire" then
        custom_matches = function(context, state) return soul_fire_matches(context, action, state) end
    elseif action.name == "Corruption" then
        custom_matches = function(context, state) return corruption_matches(context, action, state) end
    elseif action.name == "CurseOfAgony" then
        custom_matches = function(context, state) return curse_of_agony_matches(context, action, state) end
    elseif action.name == "CurseOfElements" then
        custom_matches = function(context, state) return curse_of_elements_matches(context, action, state) end
    elseif action.name == "CurseOfRecklessness" then
        custom_matches = function(context, state) return curse_of_recklessness_matches(context, action, state) end
    elseif action.name == "CurseOfWeakness" then
        custom_matches = function(context, state) return curse_of_weakness_matches(context, action, state) end
    elseif action.name == "DrainLife" then
        custom_matches = function(context, state) return drain_life_matches(context, action, state) end
    elseif action.name == "HealthFunnel" then
        custom_matches = function(context, state) return health_funnel_matches(context, action, state) end
    elseif action.name == "DarkPact" then
        custom_matches = function(context, state) return dark_pact_matches(context, action, state) end
    elseif action.name == "FelArmor" then
        custom_matches = function(context, state) return fel_armor_matches(context, action, state) end
    elseif action.name == "DemonArmor" then
        custom_matches = function(context, state) return demon_armor_matches(context, action, state) end

    elseif action.name == "CreateHealthstone" then
        custom_matches = function(context, state) return create_healthstone_matches(context, action, state) end
    elseif action.name == "DeathCoil" then
        custom_matches = function(context, state) return death_coil_matches(context, action, state) end
    elseif action.name == "Shadowfury" then
        custom_matches = function(context, state) return shadowfury_matches(context, action, state) end
    elseif action.name == "Fear" then
        custom_matches = function(context, state) return fear_matches(context, action, state) end
    elseif action.name == "DemonicSacrifice" then
        custom_matches = function(context, state) return demonic_sacrifice_imp_matches(context, action, state) end
    elseif action.name == "SummonImp" or action.name == "SummonVoidwalker" or action.name == "SummonSuccubus" or action.name == "SummonFelhunter" or action.name == "SummonFelguard" then
        custom_matches = function(context, state) return summon_pet_matches(context, action, state) end
    elseif action.enemy_count then
        custom_matches = function(context, state) return aoe_matches(context, action, state) end
    else
        custom_matches = function(context, state) return true end
    end
    strategies[#strategies + 1] = {
        name = action.name,
        matches = custom_matches,
        execute = function(context)
            local target = context.target
            local opts = { expected_cooldown = action.cooldown }
            if action.target == "self" or action.position == "self" then
                target = context.me or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
                opts.skip_range = true
            elseif action.target == "pet" then
                target = context.pet or (NS.GetPet and NS.GetPet())
            elseif action.position == "target" and NS.try_cast_position then
                local r = action.hit_radius or (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8
                if NS.cast_ground_aoe then
                    return NS.cast_ground_aoe(action.spell, target, r, 35, "[DESTRUCTION] " .. action.name, opts)
                end
                local spell_id = NS.get_spell_id(action.spell)
                local pos = spell_id and NS.get_aoe_cast_position and NS.get_aoe_cast_position(spell_id, target, r, 35)
                if not pos then
                    local get_position = target and target.get_position
                    pos = get_position and target:get_position() or nil
                end
                if not pos then return false end
                return NS.try_cast_position(action.spell, pos, target, "[DESTRUCTION] " .. action.name, opts)
            end
            if action.name == "LifeTap" then
                _last_life_tap = NS.time_now()
            end
            return NS.try_cast(action.spell, target, "[DESTRUCTION] " .. action.name, opts)
        end,
    }
end

-- ============================================================================
-- parity parity strategies (inserted at correct priority positions)
-- ============================================================================

-- ManaGem: auto-use mana items when mana is low (shared helper)
-- Insert at position 7 (after DarkPact=6, before DrainLife=7)
table.insert(strategies, 7, mana_gem_helper.make_strategy("ManaGem", "destro_mana_gem_threshold", 35))

-- Healthstone: auto-use healthstone when HP is low (shared helper)
table.insert(strategies, 23, healthstone_helper.make_strategy("Healthstone", {
    use_state_id = true,
    label = "[DESTRUCTION]",
})) -- Soulshatter is provided centrally by warlock middleware (Soulshatter strategy).

-- Replace imperative match functions with DSL-compiled equivalents.
-- NOTE: The strategies table above is built dynamically from the ACTIONS table,
-- and parity strategies (ManaGem, Healthstone) are inserted at
-- specific priority positions with table.insert. Because those inserts shift
-- indices, we cannot safely substitute by numeric index. Matching by strategy
-- name keeps the DSL substitution robust against future parity additions or
-- reordering of the underlying ACTIONS list.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("destruction", strategies, { get_state = build_state })
end
-- Warlock destruction rotation registered (build_state, explicit strategies, Backlash/Backdraft, execute, AoE, defensives, utility)
return { strategies = strategies, build_state = build_state }


