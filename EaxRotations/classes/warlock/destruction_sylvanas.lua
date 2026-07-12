-- destruction_sylvanas.lua — Warlock Destruction DPS for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies via ACTIONS table with custom match overrides
--         (Shadow Bolt filler, Immolate/Conflagrate, Incinerate, Curse maintenance,
--          demons, AoE, execute, defensives, mana sustain).
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no on_update() allocs.

-- Warlock Destruction priority list.

--
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local curse_helper = require("shared/warlock_curse_helper_sylvanas")
local CURSE_REFRESH_WINDOW = curse_helper.CURSE_REFRESH_WINDOW

-- Centralized spell resolver via spec_kit (rank IDs from class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    Conflagrate     = define("Conflagrate",     { 30912, 27266, 18932, 18931, 18930, 17962 }, "Conflagrate"),
    Corruption      = define("Corruption",      { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    CurseOfAgony    = define("CurseOfAgony",    { 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfAgony"),
    CurseOfDoom     = define("CurseOfDoom",     { 30910, 603 }, "CurseOfDoom"),
    CurseElements   = define("CurseElements",   { 27228, 11722, 11721, 1490 }, "CurseElements"),
    CurseOfRecklessness = define("CurseOfRecklessness", { 27227, 11717, 11716, 11715, 6209, 6208, 1109, 702 }, "CurseOfRecklessness"),
    CurseOfWeakness     = define("CurseOfWeakness",     { 30909, 27224, 11708, 11707, 7646, 6205, 1108, 702 }, "CurseOfWeakness"),
    DeathCoil       = define("DeathCoil",       { 27223, 17926, 17925, 6789 }, "DeathCoil"),
    FelArmor        = define("FelArmor",        { 28189, 28176 }, "FelArmor"),
    Immolate        = define("Immolate",        { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
    Incinerate      = define("Incinerate",      { 32231, 29722 }, "Incinerate"),
    LifeTap         = define("LifeTap",         { 27222, 11689, 11688, 11687, 1456, 1455, 1454 }, "LifeTap"),
    ShadowBolt      = define("ShadowBolt",      { 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
    Shadowburn      = define("Shadowburn",      { 30546, 27263, 18871, 18870, 18869, 18868, 18867, 17877 }, "Shadowburn"),
    Shadowfury      = define("Shadowfury",      { 30414, 30413, 30283 }, "Shadowfury"),
    ShadowWard      = define("ShadowWard",      { 28610, 11740, 11739, 6229 }, "ShadowWard"),
    Soulshatter     = define("Soulshatter",     { 29858 }, "Soulshatter"),
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
local SHADOW_WARD_BUFF = { 28610, 11740, 11739, 6229 }
local DEMONIC_SACRIFICE_AURA_ALL = { 18789, 18790, 18791, 18792, 35701 }

-- Local spell actions for spells not exposed in NS.WarlockSpells
local DemonArmorSpell = NS.spell_action({ 27260, 11735, 11734, 11733, 1086, 706, 687 }, "DemonArmor")
local ShadowWardSpell = NS.spell_action({ 28610, 11740, 11739, 6229 }, "ShadowWard")
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
local MANA_LIFE_TAP_THRESHOLD = 35
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
    has_backdraft = false,
    has_fel_armor = false,
    has_demon_armor = false,
    has_shadow_ward = false,
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
    has_backdraft = false,
    has_fel_armor = false,
    has_demon_armor = false,
    has_shadow_ward = false,
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
    local me = NS.GetPlayer()
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
    state.has_backdraft = false
    state.has_fel_armor = me and NS.buff_up(me, FEL_ARMOR_BUFF) or false
    state.has_demon_armor = me and NS.buff_up(me, DEMON_ARMOR_BUFF) or false
    state.has_shadow_ward = me and NS.buff_up(me, SHADOW_WARD_BUFF) or false
    state.has_demonic_sacrifice = me and NS.buff_up(me, DEMONIC_SACRIFICE_AURA_ALL) or false
    state.hp = context.hp or 100
    state.mana_pct = context.mana_pct or 100
    state.spell_damage = context.spell_damage or 0
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
    { name = "ShadowWard", spell = ShadowWardSpell, target = "self", kind = "buff", buff = SHADOW_WARD_BUFF, requires_target = false, cooldown = 30 },
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
    -- Filler (Incinerate when Immolate active, else Shadow Bolt)
    { name = "Incinerate", spell = ACTION.Incinerate, not_moving = true },
    { name = "ShadowBolt", spell = ACTION.ShadowBolt, not_moving = true },
    -- Execute
    { name = "SoulFire", spell = SoulFire, not_moving = true },
    { name = "Shadowburn", spell = ACTION.Shadowburn, cooldown = 15 },
    { name = "SearingPain", spell = SearingPain, moving = true },
    -- AoE
    { name = "SeedOfCorruption", spell = SeedOfCorruption, enemy_count = 3 },
    { name = "RainOfFire", spell = RainOfFire, position = "target", enemy_count = 4, not_moving = true },
    { name = "Hellfire", spell = Hellfire, position = "self", enemy_count = 4, not_moving = true },
    -- CC / Emergency
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
    if context.is_pvp then
        if context.enemy_healer then return "tongues" end
        if context.melee_on_you then return "exhaustion" end
    end
    local caster_threshold = spec_kit.setting_number(context, "warlock_curse_elements_threshold", 2)
    if (context.caster_count or 0) >= caster_threshold then return "elements" end
    local reck_threshold = spec_kit.setting_number(context, "warlock_curse_reck_threshold", 2)
    if context.is_group and (context.physical_dps_count or 0) >= reck_threshold then return "recklessness" end
    return "doom"
end

local function other_curse_active(state, this_curse)
    return curse_helper.other_curse_active(state, this_curse)
end

local function immolate_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.Immolate, 2.0) then return false end
    if not state then return false end
    state = state or {}
    -- SP-aware gating: skip Immolate when spell damage is below the threshold
    -- (conservative: defaults to 400 SP, configurable via destro_immolate_min_sp)
    local min_sp = spec_kit.setting_number(context, "destro_immolate_min_sp", IMMOLATE_MIN_SP_DEFAULT)
    if (state.spell_damage or 0) < min_sp then return false end
    if (state.immolate_remains or 0) > IMMOLATE_PANDEMIC_WINDOW then return false end
    if not (NS.should_refresh_dot and NS.should_refresh_dot((state.immolate_remains or 0), 1.5, context.ttd, 15)) then return false end
    return true
end

local function conflagrate_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if (state.immolate_remains or 0) <= 0 then return false end
    -- TTD gate: skip Conflagrate on a nearly dead target (save GCD for harder hit)
    if context.ttd_known and context.ttd < 3 then return false end
    return true
end

local function shadowburn_matches(context, action, state)
    if not context.target then return false end
    if NS.has_item and not NS.has_item(SOUL_SHARD_ITEM) then return false end
    local hp_threshold = spec_kit.setting_number(context, "destro_shadowburn_hp", SHADOWBURN_HP_PCT)
    if not (NS.is_execute_phase and NS.is_execute_phase(context.target_hp, hp_threshold)) then return false end
    return NS.spell_ready(action.spell, context.target)
end

local function curse_of_doom_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CurseOfDoom, 2.0) then return false end
    local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
    if curse_mode ~= "auto" and curse_mode ~= "doom" then return false end
    if curse_mode == "auto" and select_curse(context, state) ~= "doom" then return false end
    if not (NS.should_use_long_cd and NS.should_use_long_cd(context, action.cooldown)) then return false end
    if not state then return false end
    state = state or {}
    if (state.cod_remains or 0) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(state, "doom") then return false end
    return true
end

local function backlash_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if not state.has_backlash then return false end
    return true
end

local function incinerate_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if (state.immolate_remains or 0) <= 0 then return false end
    -- TTD gate: prefer Shadow Bolt (harder hit) when target is dying fast
    if context.ttd_known and context.ttd < 6 then return false end
    return NS.spell_ready(action.spell, context.target)
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
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.Corruption, 2.0) then return false end
    if not state then return false end
    state = state or {}
    if (state.corruption_remains or 0) > 3 then return false end
    return true
end

local function curse_of_agony_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CurseOfAgony, 2.0) then return false end
    local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
    if curse_mode ~= "auto" and curse_mode ~= "agony" then return false end
    if curse_mode == "auto" and select_curse(context, state) ~= "agony" then return false end
    if not state then return false end
    state = state or {}
    if (state.coa_remains or 0) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(state, "agony") then return false end
    return NS.spell_ready(action.spell, context.target)
end

local function curse_of_elements_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CurseElements, 2.0) then return false end
    local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
    if curse_mode ~= "auto" and curse_mode ~= "elements" then return false end
    if curse_mode == "auto" and select_curse(context, state) ~= "elements" then return false end
    if not state then return false end
    state = state or {}
    local assigned = spec_kit.setting(context, "warlock_assigned_curse", "none")
    if not (context.is_group or (context.party_size and context.party_size > 1)) and curse_mode ~= "elements" and assigned ~= "elements" then return false end
    if (state.coe_remains or 0) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(state, "elements") then return false end
    return NS.spell_ready(action.spell, context.target)
end

local function curse_of_recklessness_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CurseOfRecklessness, 2.0) then return false end
    local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
    if curse_mode ~= "auto" and curse_mode ~= "recklessness" then return false end
    if curse_mode == "auto" and select_curse(context, state) ~= "recklessness" then return false end
    if not state then return false end
    state = state or {}
    local assigned = spec_kit.setting(context, "warlock_assigned_curse", "none")
    if not (context.is_group or (context.party_size and context.party_size > 1)) and curse_mode ~= "recklessness" and assigned ~= "recklessness" then return false end
    if (state.recklessness_remains or 0) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(state, "recklessness") then return false end
    return NS.spell_ready(action.spell, context.target)
end

local function curse_of_weakness_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CurseOfWeakness, 2.0) then return false end
    local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
    if curse_mode ~= "auto" and curse_mode ~= "weakness" then return false end
    if curse_mode == "auto" and select_curse(context, state) ~= "weakness" then return false end
    if not state then return false end
    state = state or {}
    local assigned = spec_kit.setting(context, "warlock_assigned_curse", "none")
    if not (context.is_group or (context.party_size and context.party_size > 1)) and curse_mode ~= "weakness" and assigned ~= "weakness" then return false end
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
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.FelArmor, 3.0) then return false end
    if not state then return false end
    state = state or {}
    if state.has_fel_armor then return false end
    return true
end

local function demon_armor_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(DemonArmorSpell, 3.0) then return false end
    if not state then return false end
    state = state or {}
    if state.has_fel_armor then return false end
    if state.has_demon_armor then return false end
    return true
end

local function shadow_ward_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.ShadowWard, 3.0) then return false end
    if not state then return false end
    state = state or {}
    if state.has_shadow_ward then return false end
    return true
end

local function create_healthstone_matches(context, action, state)
    if NS.has_item and not NS.has_item(SOUL_SHARD_ITEM) then return false end
    if context.in_combat then return false end
    if context.has_valid_enemy_target then return false end
    return true
end

local function life_tap_matches(context, action, state)
    if context.is_casting or context.is_channeling then return false end
    if (NS.time_now() - _last_life_tap) < LIFE_TAP_MIN_INTERVAL then return false end
    if not state then return false end
    state = state or {}
    if (state.mana_pct or 100) > MANA_LIFE_TAP_THRESHOLD then return false end
    if (state.hp or 100) < (action.min_hp or 0) then return false end
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
    if not NS.spell_ready(action.spell, context.target) then return false end
    return true
end

local function shadowfury_matches(context, action, state)
    if not (context.is_pvp or context.is_group) then return false end
    -- AoE stun: only worth casting with 2+ enemies nearby or in PvP
    if not context.is_pvp and (context.enemy_count or 0) < 2 then return false end
    if not NS.spell_ready(action.spell, NS.PLAYER_UNIT, { skip_range = true }) then return false end
    return true
end

local function aoe_matches(context, action, state)
    if context.is_channeling then return false end
    if (context.enemy_count or context.enemies_count or 0) < (action.enemy_count or 0) then return false end
    if not (NS.spell_ready and NS.spell_ready(action.spell, context.target)) then return false end
    if context.is_moving and action.not_moving then return false end
    return true
end

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    local custom_matches
    if action.name == "Immolate" then
        custom_matches = function(context, state) return immolate_matches(context, action, state) end
    elseif action.name == "Conflagrate" then
        custom_matches = function(context, state) return conflagrate_matches(context, action, state) end
    elseif action.name == "Shadowburn" then
        custom_matches = function(context, state) return shadowburn_matches(context, action, state) end
    elseif action.name == "CurseOfDoom" then
        custom_matches = function(context, state) return curse_of_doom_matches(context, action, state) end
    elseif action.name == "BacklashShadowBolt" then
        custom_matches = function(context, state) return backlash_matches(context, action, state) end
    elseif action.name == "Incinerate" then
        custom_matches = function(context, state) return incinerate_matches(context, action, state) end
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
    elseif action.name == "ShadowWard" then
        custom_matches = function(context, state) return shadow_ward_matches(context, action, state) end
    elseif action.name == "CreateHealthstone" then
        custom_matches = function(context, state) return create_healthstone_matches(context, action, state) end
    elseif action.name == "LifeTap" then
        custom_matches = function(context, state) return life_tap_matches(context, action, state) end
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
                local spell_id = NS.get_spell_id(action.spell)
                local pos = spell_id and NS.get_aoe_cast_position and NS.get_aoe_cast_position(spell_id, target, 8, 35)
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

-- ManaGem: auto-use mana items when mana is low
-- Insert at position 7 (after DarkPact=6, before DrainLife=7)
table.insert(strategies, 7, {
    name = "ManaGem",
    matches = function(context, state)
        local threshold = spec_kit.setting_number(context, "destro_mana_gem_threshold", 35)
        if (state.mana_pct or 100) > threshold then return false end
        return state.mana_gem_ready or false
    end,
    execute = function(context, state)
        local id = state and state.mana_gem_id
        if id and NS.use_item_by_id then
            NS.use_item_by_id(id)
            return true
        end
        return false
    end,
})

-- Healthstone: auto-use healthstone when HP is low
-- Insert at position 23 (before Soulshatter)
table.insert(strategies, 23, {
    name = "Healthstone",
    matches = function(context, state)
        local threshold = spec_kit.setting_number(context, "healthstone_hp", 0)
        if not spec_kit.setting_bool(context, "use_auto_consumables", true) then return false end
        if not spec_kit.setting_bool(context, "use_healthstones", true) then return false end
            if threshold <= 0 then return false end
            if (context.hp or 100) > threshold then return false end
        if context.is_casting then return false end
        return state.healthstone_ready or false
    end,
    execute = function(_, state)
        if state and state.healthstone_id and NS.use_item_by_id then
            return NS.use_item_by_id(state.healthstone_id)
        end
        return false
    end,
})

-- Soulshatter: threat dump
-- Insert at position 25 (after Healthstone shift)
table.insert(strategies, 25, {
    name = "Soulshatter",
    matches = function(context, state)
        if not context.in_combat then return false end
        local me = context.me or (NS.GetPlayer and NS.GetPlayer())
        if not me then return false end
        if NS.cooldown_remains(ACTION.Soulshatter, 300) > 0 then return false end
        return NS.spell_ready(ACTION.Soulshatter, me, { skip_range = true })
    end,
    execute = function(context)
        local me = context.me or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
        return NS.try_cast(ACTION.Soulshatter, me, "[DESTRUCTION] Soulshatter", { skip_range = true })
    end,
})

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("destruction", strategies, { get_state = build_state })
end
-- Warlock destruction rotation registered (build_state, explicit strategies, Backlash/Backdraft, execute, AoE, defensives, utility)
return { strategies = strategies, build_state = build_state }


