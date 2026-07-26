-- demonology_sylvanas.lua -- Warlock Demonology DPS for TBC Anniversary (2.5.5).
-- WHAT:  pet-centric DPS spec with Felguard, Soul Link, multi-DoT cycling,
--         Fel Domination summoning, and Imp Firebolt management.
-- WHEN:  combat, with valid enemy target and active pet.
-- WHY:   mirrors TBC demonology consensus: pet survival > DoT maintenance >
--         Shadow Bolt filler, with Soul Link for survivability.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no on_update() allocs.

-- Warlock Demonology priority list.

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

-- IZI SDK optional cache for pet access
local _izi = nil
do
    local ok, mod = pcall(require, "common/izi_sdk")
    if ok and type(mod) == "table" then _izi = mod end
end

-- Centralized spell resolver via spec_kit (rank IDs from warlock/class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    Corruption       = define("Corruption",       { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    CurseElements    = define("CurseElements",    { 27228, 11722, 11721, 1490 }, "CurseElements"),
    CurseOfAgony     = define("CurseOfAgony",     { 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfAgony"),
    CurseOfDoom       = define("CurseOfDoom",       { 30910, 603 }, "CurseOfDoom"),
    CurseOfRecklessness = define("CurseOfRecklessness", { 27226, 11717, 7659, 7658, 704 }, "CurseOfRecklessness"),
    CurseOfWeakness   = define("CurseOfWeakness",   { 30909, 27224, 11708, 11707, 7646, 6205, 1108, 702 }, "CurseOfWeakness"),
    DarkPact          = define("DarkPact",          { 27265, 18938, 18937, 18220 }, "DarkPact"),
    DeathCoil        = define("DeathCoil",        { 27223, 17926, 17925, 6789 }, "DeathCoil"),
    DrainSoul        = define("DrainSoul",        { 27217, 11675, 8289, 8288, 1120 }, "DrainSoul"),
    Fear             = define("Fear",             { 6215, 6213, 5782 }, "Fear"),
    FelArmor         = define("FelArmor",         { 28189, 28176 }, "FelArmor"),
    FelDomination    = define("FelDomination",    { 18708 }, "FelDomination"),
    HealthFunnel     = define("HealthFunnel",     { 27259, 11695, 11694, 11693, 3700, 3699, 3698, 755 }, "HealthFunnel"),
    Hellfire         = define("Hellfire",         { 27213, 11684, 11683, 1949 }, "Hellfire"),
    HowlofTerror     = define("HowlofTerror",     { 17928, 5484 }, "HowlofTerror"),
    Immolate         = define("Immolate",         { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
    Incinerate       = define("Incinerate",       { 32231, 29722 }, "Incinerate"),
    LifeTap          = define("LifeTap",          { 27222, 11689, 11688, 11687, 1456, 1455, 1454 }, "LifeTap"),
    RainOfFire       = define("RainOfFire",       { 27212, 5740 }, "RainOfFire"),
    Seduction        = define("Seduction",        { 6358 }, "Seduction"),
    SeedOfCorruption = define("SeedOfCorruption", { 27243 }, "SeedOfCorruption"),
    ShadowBolt       = define("ShadowBolt",       { 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
    ShadowWard       = define("ShadowWard",       { 28610, 11740, 11739, 6229 }, "ShadowWard"),
    SiphonLife       = define("SiphonLife",       { 30911, 27264, 18881, 18880, 18879, 18265 }, "SiphonLife"),
    SoulFire         = define("SoulFire",         { 30545, 27211, 17924, 6353 }, "SoulFire"),
    Soulshatter      = define("Soulshatter",      { 29858 }, "Soulshatter"),
    SummonFelguard   = define("SummonFelguard",   { 30146 }, "SummonFelguard"),
    SummonImp        = define("SummonImp",        { 688 }, "SummonImp"),
}
local pet_manager = require("shared/pet_manager_sylvanas")

local potion_helper = require("shared/potion_helper_sylvanas")

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local CURSE_OF_DOOM_DEBUFF = { 30910, 603 }
local CORRUPTION_DEBUFF = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local IMMOLATE_DEBUFF = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local FEL_ARMOR_BUFF = { 28189, 28176 }
local SOUL_LINK_BUFF = { 25228 }
local CURSE_OF_AGONY_DEBUFF = curse_helper.CURSE_OF_AGONY_DEBUFF
local CURSE_OF_ELEMENTS_DEBUFF = curse_helper.CURSE_OF_ELEMENTS_DEBUFF
local PET_LOW_HP = 30
local EXECUTE_THRESHOLD = 25
local SOUL_SHARD_CAPTURE_TTD = 5  -- TBC: Drain Soul is shard-capture only (mob about to die); sub-25% execute is Wrath, not TBC
local HEALTHSTONE_IDS = { 22105, 22104, 22103, 22102, 22101, 22100 }
local LIFE_TAP_MIN_INTERVAL = 1.5
local _last_life_tap = 0

local DOT_REFRESH_WINDOW = 1.5

local IMP_FIREBOLT_IDS = { 3110, 7799, 7800, 7801, 7802, 11762, 11763, 27267 }
-- Lash of Pain spell IDs (all ranks) — only the Succubus has this, so it
-- identifies the active pet as a Succubus.
-- Lash of Pain ranks high→low (lexxer tbc): 7814-7816, 11778-11780, 27274.
-- Removed invalid 7817-7819 / 11770-11771 / 27268 (items or wrong pet spells).
local SUCC_LASH_IDS = { 27274, 11780, 11779, 11778, 7816, 7815, 7814 }

local ImpFirebolt = NS.spell_action and NS.spell_action(IMP_FIREBOLT_IDS, "ImpFirebolt") or nil

-- ============================================================================
-- Schema for safe_state (Pattern 14 nil-guard elimination).
-- ============================================================================
local DEMO_SCHEMA = {
    -- Buffs / pet
    has_fel_armor = false, has_pet = false, pet_alive = false,
    pet_hp_pct = 100, pet_type_imp = false, pet_type_succubus = false,
    pet_casting_firebolt = false, has_soul_link = false,
    -- Resources
    hp_pct = 100, mana_pct = 100,
    -- Combat
    in_combat = false, enemy_count = 0, target_casting = false,
    target_hp_pct = 100,
    -- Spell readiness
    fel_armor_ready = false, curse_of_doom_ready = false,
    corruption_ready = false, immolate_ready = false,
    life_tap_ready = false, death_coil_ready = false,
    shadow_bolt_ready = false, seed_of_corruption_ready = false,
    howl_of_terror_ready = false, shadow_ward_ready = false,
    siphon_life_ready = false, fel_domination_ready = false,
    soulshatter_ready = false, incinerate_ready = false,
    soul_fire_ready = false, fear_ready = false,
    seduction_ready = false, rain_of_fire_ready = false,
    hellfire_ready = false, curse_of_agony_ready = false,
    curse_of_elements_ready = false,
    curse_of_recklessness_ready = false,
    curse_of_weakness_ready = false,
    agony_remains = 0, doom_remains = 0, coe_remains = 0,
    recklessness_remains = 0, weakness_remains = 0,
    dark_pact_ready = false, drain_soul_ready = false,
    soul_link_ready = false,
    -- Items
    healthstone_ready = false,
}

-- ============================================================================
-- State builder
-- ============================================================================
local demo_state = {
    has_fel_armor = false,
    has_pet = false,
    pet_alive = false,
    pet_hp_pct = 100,
    pet_type_imp = false,
    pet_type_succubus = false,
    pet_casting_firebolt = false,
    hp_pct = 100,
    mana_pct = 100,
    enemy_count = 1,
    target_casting = false,
    fel_armor_ready = false,
    curse_of_doom_ready = false,
    corruption_ready = false,
    immolate_ready = false,
    life_tap_ready = false,
    death_coil_ready = false,
    shadow_bolt_ready = false,
    seed_of_corruption_ready = false,
    howl_of_terror_ready = false,
    shadow_ward_ready = false,
    siphon_life_ready = false,
    fel_domination_ready = false,
    soulshatter_ready = false,
    incinerate_ready = false,
    soul_fire_ready = false,
    fear_ready = false,
    rain_of_fire_ready = false,
    hellfire_ready = false,
    curse_of_agony_ready = false,
    curse_of_elements_ready = false,
    curse_of_recklessness_ready = false,
    curse_of_weakness_ready = false,
    agony_remains = 0,
    doom_remains = 0,
    coe_remains = 0,
    recklessness_remains = 0,
    weakness_remains = 0,
    dark_pact_ready = false,
    drain_soul_ready = false,
    soul_link_ready = false,
    has_soul_link = false,
    target_hp_pct = 100,
}

local _last_build_state_time = -1
local function build_state(context)
    -- Pattern 6: frame-keyed dedup
    local now = context.now or (NS.time_now and NS.time_now() or 0)
    if now == _last_build_state_time then return spec_kit.safe_state(demo_state, DEMO_SCHEMA) end
    if context.now then _last_build_state_time = now end
    local me = context.me or NS.GetPlayer()
    local target = context.target

    demo_state.has_fel_armor = me and NS.buff_up and NS.buff_up(me, FEL_ARMOR_BUFF) or false
    demo_state.has_pet = false
    demo_state.pet_alive = false
    demo_state.pet_hp_pct = 100
    demo_state.pet_type_imp = false
    demo_state.pet_type_succubus = false
    demo_state.pet_casting_firebolt = false
    if me then
        local ok, has_pet = pcall(function() return me:has_pet() end)
        demo_state.has_pet = ok and has_pet or false
        if demo_state.has_pet then
            local ok_pet, pet = pcall(function() return me:get_pet() end)
            if ok_pet and pet and pet:is_valid() then
                local ok_alive, alive = pcall(function() return pet:is_alive() end)
                demo_state.pet_alive = ok_alive and alive or false
                if demo_state.pet_alive then
                    demo_state.pet_hp_pct = pet.get_health_percentage and pet:get_health_percentage() or 100
                    local ok_sp, pet_spells = pcall(function()
                        local sb = (NS.core or _G.core)
                        return sb and sb.spell_book and sb.spell_book.get_pet_spells and sb.spell_book.get_pet_spells() or {}
                    end)
                    if ok_sp and type(pet_spells) == "table" then
                        for _, fire_id in ipairs(IMP_FIREBOLT_IDS) do
                            for _, known in ipairs(pet_spells) do
                                if known == fire_id then
                                    demo_state.pet_type_imp = true
                                    break
                                end
                            end
                            if demo_state.pet_type_imp then break end
                        end
                        if not demo_state.pet_type_imp then
                            for _, lash_id in ipairs(SUCC_LASH_IDS) do
                                for _, known in ipairs(pet_spells) do
                                    if known == lash_id then
                                        demo_state.pet_type_succubus = true
                                        break
                                    end
                                end
                                if demo_state.pet_type_succubus then break end
                            end
                        end
                    end
                    if demo_state.pet_type_imp then
                        local ok_cast, casting = pcall(function() return pet:is_casting_spell() end)
                        demo_state.pet_casting_firebolt = ok_cast and casting or false
                    end
                end
            end
        end
    end
    demo_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    demo_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    demo_state.enemy_count = context.enemy_count or context.enemies_count or 1
    demo_state.in_combat = context.in_combat or false  -- [#fix-4] used by Pet{Defensive,Passive,Aggressive} matchers
    demo_state.target_casting = target and target.is_casting and target:is_casting() or false
    demo_state.fel_armor_ready = me and NS.spell_ready(ACTION.FelArmor, me, { skip_range = true }) or false
    demo_state.curse_of_doom_ready = target and NS.spell_ready(ACTION.CurseOfDoom, target, { expected_cooldown = 60 }) or false
    demo_state.corruption_ready = target and NS.spell_ready(ACTION.Corruption, target) or false
    demo_state.immolate_ready = target and NS.spell_ready(ACTION.Immolate, target, { expected_cooldown = 1.5 }) or false
    demo_state.life_tap_ready = me and NS.spell_ready(ACTION.LifeTap, me, { skip_range = true }) or false
    demo_state.death_coil_ready = target and NS.spell_ready(ACTION.DeathCoil, target, { expected_cooldown = 120 }) or false
    demo_state.shadow_bolt_ready = target and NS.spell_ready(ACTION.ShadowBolt, target, { expected_cooldown = 2.5 }) or false
    demo_state.seed_of_corruption_ready = target and NS.spell_ready(ACTION.SeedOfCorruption, target, { expected_cooldown = 1.5 }) or false
    demo_state.howl_of_terror_ready = me and NS.spell_ready(ACTION.HowlofTerror, me, { skip_range = true, expected_cooldown = 40 }) or false
    demo_state.shadow_ward_ready = me and NS.spell_ready(ACTION.ShadowWard, me, { skip_range = true, expected_cooldown = 30 }) or false
    demo_state.siphon_life_ready = target and NS.spell_ready(ACTION.SiphonLife, target, { expected_cooldown = 1.5 }) or false
    demo_state.fel_domination_ready = me and NS.spell_ready(ACTION.FelDomination, me, { skip_range = true, expected_cooldown = 900 }) or false
    demo_state.soulshatter_ready = me and NS.cooldown_remains(ACTION.Soulshatter, 300) <= 0 and NS.spell_ready(ACTION.Soulshatter, me, { skip_range = true }) or false
    demo_state.incinerate_ready = target and NS.spell_ready(ACTION.Incinerate, target, { expected_cooldown = 2.5 }) or false
    demo_state.soul_fire_ready = target and NS.spell_ready(ACTION.SoulFire, target, { expected_cooldown = 1.5 }) or false
    demo_state.fear_ready = target and NS.spell_ready(ACTION.Fear, target) or false
    demo_state.seduction_ready = target and NS.spell_ready(ACTION.Seduction, target) or false
    demo_state.rain_of_fire_ready = target and NS.spell_ready(ACTION.RainOfFire, target, { expected_cooldown = 1.5 }) or false
    demo_state.hellfire_ready = me and NS.spell_ready(ACTION.Hellfire, me, { skip_range = true }) or false
    demo_state.target = target
    demo_state.curse_of_agony_ready = target and NS.spell_ready(ACTION.CurseOfAgony, target) or false
    demo_state.curse_of_elements_ready = target and NS.spell_ready(ACTION.CurseElements, target) or false
    demo_state.curse_of_recklessness_ready = target and NS.spell_ready(ACTION.CurseOfRecklessness, target) or false
    demo_state.curse_of_weakness_ready = target and NS.spell_ready(ACTION.CurseOfWeakness, target) or false
    demo_state.agony_remains        = target and NS.debuff_remains and NS.debuff_remains(target, curse_helper.CURSE_OF_AGONY_DEBUFF) or 0
    demo_state.doom_remains         = target and NS.debuff_remains and NS.debuff_remains(target, curse_helper.CURSE_OF_DOOM_DEBUFF) or 0
    demo_state.coe_remains          = target and NS.debuff_remains and NS.debuff_remains(target, curse_helper.CURSE_OF_ELEMENTS_DEBUFF) or 0
    demo_state.recklessness_remains = target and NS.debuff_remains and NS.debuff_remains(target, curse_helper.CURSE_OF_RECKLESSNESS_DEBUFF) or 0
    demo_state.weakness_remains     = target and NS.debuff_remains and NS.debuff_remains(target, curse_helper.CURSE_OF_WEAKNESS_DEBUFF) or 0
    demo_state.dark_pact_ready = me and NS.spell_ready(ACTION.DarkPact, me, { skip_range = true, expected_cooldown = 10 }) or false
    demo_state.drain_soul_ready = target and NS.spell_ready(ACTION.DrainSoul, target) or false
    demo_state.soul_link_ready = me and NS.spell_ready(25228, me, { skip_range = true }) or false
    demo_state.has_soul_link = me and NS.buff_up and NS.buff_up(me, SOUL_LINK_BUFF) or false
    demo_state.target_hp_pct = target and target.get_health_percentage and target:get_health_percentage() or 100
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

    return spec_kit.safe_state(demo_state, DEMO_SCHEMA)
end

-- ============================================================================
-- Custom match functions (test assertions depend on these)
-- ============================================================================
local function needs_felguard(context, action)
    local me = context.me
    if not me then return false end
    if not NS.is_spell_learned or not NS.is_spell_learned(30146) then return false end
    if context.in_combat then return false end
    -- Do NOT summon if Demonic Sacrifice aura is already active
    if NS.buff_up and NS.buff_up(me, {18789, 18790, 18791, 18792, 35701}) then return false end
    local ok, has_pet = pcall(function() return me:has_pet() end)
    if not ok then
        if _izi and _izi.pet then
            local pet = _izi.pet()
            if not (pet and pet:is_valid()) then
                return true
            end
        end
        return false
    end
    if not has_pet then
        return true
    end
    return false
end

local function needs_imp_fallback(context)
    local me = context.me
    if not me then return false end
    if context.in_combat then return false end
    if NS.is_spell_learned and NS.is_spell_learned(30146) then return false end
    -- Do NOT re-summon if Demonic Sacrifice aura is already active
    if NS.buff_up and NS.buff_up(me, {18789, 18790, 18791, 18792, 35701}) then return false end
    local ok, has_pet = pcall(function() return me:has_pet() end)
    if not ok then
        if _izi and _izi.pet then
            local pet = _izi.pet()
            if pet and pet:is_valid() then return false end
        end
    elseif has_pet then
        return false
    end
    return NS.is_spell_learned and NS.is_spell_learned(688)
end

local function pet_needs_healing(context)
    local me = context.me
    if not me then return false end
    local ok, pet = pcall(function() return me:get_pet() end)
    if not ok then
        if _izi and _izi.pet then
            pet = _izi.pet()
        else
            return false
        end
    end
    if not pet or not pet:is_valid() then return false end
    local pet_hp = pet.get_health_percentage and pet:get_health_percentage() or 100
    return pet_hp < PET_LOW_HP
end

local function death_coil_matches(context, action)
    if not context.target then return false end
    local me = context.me
    if not me then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100
    if hp > 40 then return false end
    return true
end

local function health_funnel_matches(context)
    return pet_needs_healing(context)
end

-- REMOVED: imp_firebolt_pacing (spec-level Firebolt nudge).
-- This is now handled by pet_manager_sylvanas.lua which:
--   1. Auto-enables autocast on the highest known Firebolt rank
--   2. Manually casts it every 2s as fallback (with correct rank)
-- The old imp_firebolt_pacing hardcoded rank 1 (3110) and fired every
-- tick, conflicting with pet_manager's higher-rank cast.
--
-- Phase Shift (4511) is an OOC defensive Imp ability that makes it
-- unattackable. It is auto-cast by default and does not need rotation
-- handling — the engine manages it.
--
-- Fire Shield (2947) is an Imp buff that reflects fire damage. It is
-- maintained by the player, not the pet, and is not part of the DPS
-- rotation. Not handled here.
--
-- Lesser Invisibility (7870) is a Succubus OOC defensive. Same as Phase
-- Shift — auto-cast by default, not a rotation concern.

-- ============================================================================
-- Match functions
-- ============================================================================
local function select_curse(context, s)
    local assigned = spec_kit.setting(context, "warlock_assigned_curse", "none")
    if assigned ~= "none" then return assigned end

    local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
    if curse_mode == "agony" then return "agony" end
    if curse_mode == "doom" then return "doom" end
    if curse_mode == "elements" then return "elements" end
    if curse_mode == "recklessness" then return "recklessness" end
    if curse_mode == "weakness" then return "weakness" end    if curse_mode == "none" then return nil end
    -- Group/raid curse auto-selection is gated by player setting (default off)
    if spec_kit.setting_bool(context, "warlock_curse_group_aware", false) then
        local reck_threshold = spec_kit.setting_number(context, "warlock_curse_reck_threshold", 2)
        if context.is_group and (context.physical_dps_count or 0) >= reck_threshold then return "recklessness" end
    end
    -- Auto mode: Doom for long fights (TTD >= 60s), Agony for short fights.
    local ttd = context.ttd or 999
    if ttd >= 60 then return "doom" end
    return "agony"
end

-- Centralized assigned-curse gate (strict enforcement so agony/assigned always wins)
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

local function other_curse_active(s, this_curse)
    return curse_helper.other_curse_active(s, this_curse)
end

local function curse_of_doom_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CurseOfDoom, 2.0) then return false end
    if not context.target then return false end
    if assigned_curse_blocks(context, "doom") then return false end
    if select_curse(context, s) ~= "doom" then return false end
    if not s.curse_of_doom_ready then return false end
    if other_curse_active(s, "doom") then return false end
    if context.ttd_known and context.ttd > 0 and context.ttd < 62 then return false end
    return true
end

local function corruption_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.Corruption, 2.0) then return false end
    if not context.target then return false end
    if not s.corruption_ready then return false end
    if NS.debuff_remains(context.target, CORRUPTION_DEBUFF) > DOT_REFRESH_WINDOW then return false end
    -- TTD gate: skip long DoT if target will die before it pays off (18s base)
    if context.ttd_known and context.ttd > 0 and context.ttd < 4 then return false end
    return true
end

local function immolate_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.Immolate, 2.0) then return false end
    if not context.target then return false end
    if not s.immolate_ready then return false end
    if NS.debuff_remains(context.target, IMMOLATE_DEBUFF) > DOT_REFRESH_WINDOW then return false end
    -- TTD gate: skip casted DoT if target will die before it pays off (15s base + 2s cast)
    if context.ttd_known and context.ttd > 0 and context.ttd < 5 then return false end
    return true
end

local function life_tap_matches(context, s)
    if context.is_casting or context.is_channeling then return false end
    if (NS.time_now() - _last_life_tap) < LIFE_TAP_MIN_INTERVAL then return false end
    if not s then return false end
    if (s.hp_pct or 100) <= 55 then return false end
    if (s.mana_pct or 100) >= 65 then return false end
    if not s.life_tap_ready then return false end
    return true
end

local function shadow_bolt_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.shadow_bolt_ready then return false end
    return true
end

local function seed_of_corruption_matches(context, s)
    if not s then return false end
    if not context.target then return false end
    if not NS.aoe_target_meets or not NS.aoe_target_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_15) or 15, context.target, context, s) then return false end
    if not s.seed_of_corruption_ready then return false end
    return true
end

local function howl_of_terror_matches(context, s)
    if not s then return false end
    if not context.in_combat then return false end
    if not NS.aoe_self_meets or not NS.aoe_self_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, s) then return false end
    if not s.howl_of_terror_ready then return false end
    return true
end

local function shadow_ward_matches(context, s)
    if not s.shadow_ward_ready then return false end
    return true
end

local function siphon_life_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.SiphonLife, 2.0) then return false end
    if not context.target then return false end
    if not s.siphon_life_ready then return false end
    -- TTD gate: skip long DoT if target will die before it pays off (30s base)
    if context.ttd_known and context.ttd > 0 and context.ttd < 4 then return false end
    return true
end

local function fel_domination_matches(context, s)
    if context.in_combat then return false end
    if s.has_pet then return false end
    if not s.fel_domination_ready then return false end
    return true
end

local function soulshatter_matches(context, s)
    if not context.in_combat then return false end
    if not s.soulshatter_ready then return false end
    local me = context.me or (NS.GetPlayer and NS.GetPlayer())
    if not me then return false end
    if NS.cooldown_remains(ACTION.Soulshatter, 300) > 0 then return false end
    return NS.spell_ready(ACTION.Soulshatter, me, { skip_range = true })
end

local function incinerate_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.incinerate_ready then return false end
    return true
end

local function fel_armor_matches(context, s)
    if not s then return false end
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.FelArmor, 3.0) then return false end
    if s.has_fel_armor then return false end
    return s.fel_armor_ready == true
end

local function soul_fire_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.SoulFire, 2.0) then return false end
    if not s then return false end
    if not context.target then return false end
    if not s.soul_fire_ready then return false end
    if (s.target_hp_pct or 100) > EXECUTE_THRESHOLD then return false end
    return true
end

local function fear_matches(context, s)
    if not s then return false end
    if not context.in_combat then return false end
    if not context.target then return false end
    if not s.fear_ready then return false end
    local group_aware = spec_kit.setting_bool(context, "warlock_group_aware_utility", true)
    if not (context.is_pvp or (group_aware and context.is_group)) then return false end
    -- IZI SDK: skip Fear if target is already CC'd
    local target = context.target
    if target and type(target.is_cc) == "function" then
        local ok, cc = pcall(target.is_cc, target)
        if ok and cc then return false end
    end
    return true
end

-- Succubus Seduction: PvP-only CC. Only fires when Succubus is active and target
-- is not already CC'd. Cast by pet (pet_cast_target_spell), not by player.
local function seduction_matches(context, s)
    if not s then return false end
    if not context.in_combat then return false end
    if not context.target then return false end
    -- PvP only: arena, battleground, or world PvP flagged
    local group_aware = spec_kit.setting_bool(context, "warlock_group_aware_utility", true)
    if not (context.is_pvp or (group_aware and context.is_group)) then return false end
    -- Must have Succubus summoned and alive
    if not s.pet_type_succubus then return false end
    if not s.pet_alive then return false end
    if not s.seduction_ready then return false end
    -- Don't re-CC target already seduced or feared
    if NS.debuff_up and NS.debuff_up(context.target, { 6358, 5782, 6213, 6215 }) then return false end
    return true
end

local function rain_of_fire_matches(context, s)
    if not s then return false end
    if not context.target then return false end
    if not NS.aoe_target_meets or not NS.aoe_target_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8, context.target, context, s) then return false end
    if not s.rain_of_fire_ready then return false end
    return true
end

local function hellfire_matches(context, s)
    if not s then return false end
    if not context.in_combat then return false end
    if not NS.aoe_self_meets or not NS.aoe_self_meets(4, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, s) then return false end
    if (s.hp_pct or 100) < 40 then return false end
    if not s.hellfire_ready then return false end
    return true
end

local function curse_of_agony_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CurseOfAgony, 2.0) then return false end
    if not s then return false end
    if not context.target then return false end
    if assigned_curse_blocks(context, "agony") then return false end
    if select_curse(context, s) ~= "agony" then return false end
    if not s.curse_of_agony_ready then return false end
    if NS.debuff_remains(context.target, CURSE_OF_AGONY_DEBUFF) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(s, "agony") then return false end
    if (s.target_hp_pct or 100) < EXECUTE_THRESHOLD then return false end
    return true
end

local function curse_of_elements_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CurseElements, 2.0) then return false end
    if not s then return false end
    if not context.target then return false end
    if assigned_curse_blocks(context, "elements") then return false end
    if select_curse(context, s) ~= "elements" then return false end
    if not s.curse_of_elements_ready then return false end
    if NS.debuff_remains(context.target, CURSE_OF_ELEMENTS_DEBUFF) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(s, "elements") then return false end
    return true
end

local function curse_of_recklessness_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CurseOfRecklessness, 2.0) then return false end
    if not s then return false end
    if not context.target then return false end
    if assigned_curse_blocks(context, "recklessness") then return false end
    if select_curse(context, s) ~= "recklessness" then return false end
    if not s.curse_of_recklessness_ready then return false end
    if NS.debuff_remains(context.target, curse_helper.CURSE_OF_RECKLESSNESS_DEBUFF) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(s, "recklessness") then return false end
    return true
end

local function curse_of_weakness_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.CurseOfWeakness, 2.0) then return false end
    if not s then return false end
    if not context.target then return false end
    if assigned_curse_blocks(context, "weakness") then return false end
    if select_curse(context, s) ~= "weakness" then return false end
    if not s.curse_of_weakness_ready then return false end
    if NS.debuff_remains(context.target, curse_helper.CURSE_OF_WEAKNESS_DEBUFF) > CURSE_REFRESH_WINDOW then return false end
    if other_curse_active(s, "weakness") then return false end
    return true
end

local function dark_pact_matches(context, s)
    if not s then return false end
    if not s.has_pet then return false end
    if (s.mana_pct or 100) >= 65 then return false end
    if not s.dark_pact_ready then return false end
    return true
end

local function drain_soul_matches(context, s)
    if not s then return false end
    if not context.target then return false end
    -- TBC: Drain Soul is NOT a DPS execute (that is a Wrath mechanic).
    -- Channel it only when the mob is about to die so it dies during the
    -- channel and yields a Soul Shard. Use the documented ttd from context.
    -- Drain Soul is low value vs filler; rely on perfect API ttd reporting.
    if not (context.ttd_known and context.ttd and context.ttd > 0 and context.ttd <= SOUL_SHARD_CAPTURE_TTD) then return false end
    if not s.drain_soul_ready then return false end
    return true
end

local function soul_link_matches(context, s)
    if not s then return false end
    -- Only maintain Soul Link when a pet is present
    if not s.has_pet then return false end
    -- Don't recast if already active
    if s.has_soul_link then return false end
    if not s.soul_link_ready then return false end
    return true
end

local function rain_of_fire_execute(context)
    local t = context.target
    local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8
    local opts = { expected_cooldown = 1.5 }
    if NS.cast_ground_aoe then
        return NS.cast_ground_aoe(ACTION.RainOfFire, t, r, 35, "[DEMONOLOGY] Rain of Fire", opts)
    end
    local pos = t and NS.get_aoe_cast_position and NS.get_aoe_cast_position(NS.get_spell_id(ACTION.RainOfFire), t, r, 35)
    if pos then return NS.try_cast_position(ACTION.RainOfFire, pos, t, "[DEMONOLOGY] Rain of Fire", opts) end
    return NS.try_cast(ACTION.RainOfFire, t, "[DEMONOLOGY] Rain of Fire", opts)
end

-- ============================================================================
-- Declarative Strategy DSL definitions (6 strategies converted)
-- ============================================================================
local DSL_DEFS = {
    {
        name = "FelArmor",
        conditions = {
            { type = "custom", fn = function(context, state)
                if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.FelArmor, 3.0) then return false end
                return true
            end },
            { type = "state", field = "has_fel_armor", op = "==", value = false },
            { type = "state", field = "fel_armor_ready", op = "==", value = true },
        },
        action = { type = "cast", spell = ACTION.FelArmor, target = "self", label = "[DEMONOLOGY] Fel Armor" },
    },
    {
        name = "SoulLink",
        conditions = {
            { type = "state", field = "has_pet", op = "==", value = true },
            { type = "state", field = "has_soul_link", op = "==", value = false },
            { type = "state", field = "soul_link_ready", op = "==", value = true },
        },
        action = { type = "cast", spell = 25228, target = "self", label = "[DEMONOLOGY] Soul Link" },
    },
    {
        name = "Corruption",
        conditions = {
            { type = "custom", fn = function(context, state)
                if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.Corruption, 2.0) then return false end
                return true
            end },
            { type = "context", field = "target", op = "!=", value = nil },
            { type = "state", field = "corruption_ready", op = "==", value = true },
            { type = "custom", fn = function(context, state)
                local remains = NS.debuff_remains and NS.debuff_remains(context.target, CORRUPTION_DEBUFF) or 0
                return remains <= DOT_REFRESH_WINDOW
            end },
            { type = "custom", fn = function(context, state)
                if context.ttd_known and context.ttd > 0 and context.ttd < 4 then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Corruption, target = "target", label = "[DEMONOLOGY] Corruption" },
    },
    {
        name = "ShadowBolt",
        conditions = {
            { type = "context", field = "target", op = "!=", value = nil },
            { type = "context", field = "is_moving", op = "==", value = false },
            { type = "state", field = "shadow_bolt_ready", op = "==", value = true },
        },
        action = { type = "cast", spell = ACTION.ShadowBolt, target = "target", label = "[DEMONOLOGY] Shadow Bolt" },
    },
    {
        name = "PetDefensive",
        conditions = {
            { type = "state", field = "has_pet", op = "==", value = true },
            { type = "custom", fn = function(context, state)
                return (context.in_combat or state.in_combat) == true
            end },
            { type = "state", field = "pet_hp_pct", op = "<=", value = 35 },
        },
        action = { type = "custom", fn = function(context, state)
            return pet_manager.set_defensive()
        end },
    },
    {
        name = "LifeTap",
        conditions = {
            { type = "custom", fn = function(context, state)
                if context.is_casting or context.is_channeling then return false end
                if (NS.time_now() - _last_life_tap) < LIFE_TAP_MIN_INTERVAL then return false end
                return true
            end },
            { type = "state", field = "hp_pct", op = ">", value = 55 },
            { type = "state", field = "mana_pct", op = "<", value = 65 },
            { type = "state", field = "life_tap_ready", op = "==", value = true },
        },
        action = { type = "custom", fn = function(context, state)
            _last_life_tap = NS.time_now()
            return NS.try_cast(ACTION.LifeTap, context.me, "[DEMONOLOGY] Life Tap", { skip_range = true })
        end },
    },
}

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    -- Auto Damage Potion — gate on context.has_damage_potion (inventory_helper)
    { name = "DamagePotion",
      matches = function(context)
          if not context.in_combat then return false end
          if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end
          if not context.has_damage_potion then return false end
          if not context.should_burst then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS) end },
    -- Pet State: set defensive when pet HP is critically low
    { name = "PetDefensive" },
    -- Pet State: set passive when player HP critically low (survival mode)
    { name = "PetPassive",
      matches = function(context, state)
          if not state.has_pet then return false end
          if not (context.in_combat or state.in_combat) then return false end
          if (context.hp or state.hp_pct or 100) > 25 then return false end
          return true
      end,
      execute = function() return pet_manager.set_passive() end },
    -- Pet State: set aggressive during combat when pet is healthy
    { name = "PetAggressive",
      matches = function(context, state)
          if not state.has_pet then return false end
          if not (context.in_combat or state.in_combat) then return false end
          if (state.pet_hp_pct or 100) < 50 then return false end
          return true
      end,
      execute = function() return pet_manager.set_aggressive() end },
    { name = "FelArmor" },
    { name = "SoulLink" },
    { name = "SummonFelguard", matches = function(context) return needs_felguard(context, { name = "SummonFelguard", spell = ACTION.SummonFelguard }) end, execute = function(context) return NS.try_cast(ACTION.SummonFelguard, context.me, "[DEMONOLOGY] Summon Felguard", { skip_range = true }) end },
    { name = "SummonImp", matches = function(context) return needs_imp_fallback(context) end, execute = function(context) return NS.try_cast(ACTION.SummonImp, context.me, "[DEMONOLOGY] Summon Imp", { skip_range = true }) end },
    { name = "FelDomination", matches = fel_domination_matches, execute = function(context) return NS.try_cast(ACTION.FelDomination, context.me, "[DEMONOLOGY] Fel Domination", { skip_range = true, expected_cooldown = 900 }) end },
    { name = "HealthFunnel", matches = health_funnel_matches, execute = function(context) return NS.try_cast(ACTION.HealthFunnel, context.pet or context.me, "[DEMONOLOGY] Health Funnel") end },

    { name = "CurseOfDoom", matches = curse_of_doom_matches, execute = function(context) return NS.try_cast(ACTION.CurseOfDoom, context.target, "[DEMONOLOGY] Curse of Doom", { expected_cooldown = 60 }) end },
    { name = "CurseOfElements", matches = curse_of_elements_matches, execute = function(context) return NS.try_cast(ACTION.CurseElements, context.target, "[DEMONOLOGY] Curse of Elements") end },
    { name = "CurseOfRecklessness", matches = curse_of_recklessness_matches, execute = function(context) return NS.try_cast(ACTION.CurseOfRecklessness, context.target, "[DEMONOLOGY] Curse of Recklessness") end },
    { name = "CurseOfWeakness", matches = curse_of_weakness_matches, execute = function(context) return NS.try_cast(ACTION.CurseOfWeakness, context.target, "[DEMONOLOGY] Curse of Weakness") end },
    { name = "CurseOfAgony", matches = curse_of_agony_matches, execute = function(context) return NS.try_cast(ACTION.CurseOfAgony, context.target, "[DEMONOLOGY] Curse of Agony") end },
    -- TBC guide order: Corruption > Immolate (higher DPCT, longer DoT) — apply Corruption first when both need refresh.
    { name = "Corruption" },
    { name = "Immolate", matches = immolate_matches, execute = function(context) return NS.try_cast(ACTION.Immolate, context.target, "[DEMONOLOGY] Immolate") end },
    { name = "SiphonLife", matches = siphon_life_matches, execute = function(context) return NS.try_cast(ACTION.SiphonLife, context.target, "[DEMONOLOGY] Siphon Life") end },
    { name = "SeedOfCorruption", matches = seed_of_corruption_matches, execute = function(context) return NS.try_cast(ACTION.SeedOfCorruption, context.target, "[DEMONOLOGY] Seed of Corruption") end },
    { name = "SoulFire", matches = soul_fire_matches, execute = function(context) return NS.try_cast(ACTION.SoulFire, context.target, "[DEMONOLOGY] Soul Fire", { expected_cooldown = 1.5 }) end },
    { name = "DrainSoul", matches = drain_soul_matches, execute = function(context)
        return NS.try_cast(ACTION.DrainSoul, context.target, "[DEMONOLOGY] Drain Soul")
    end },
    { name = "RainOfFire", matches = rain_of_fire_matches, execute = rain_of_fire_execute },
    { name = "Hellfire", matches = hellfire_matches, execute = function(context) return NS.try_cast(ACTION.Hellfire, context.me, "[DEMONOLOGY] Hellfire", { skip_range = true }) end },
    { name = "DeathCoil", matches = function(context, state) return death_coil_matches(context, { name = "DeathCoil", spell = ACTION.DeathCoil }) end, execute = function(context) return NS.try_cast(ACTION.DeathCoil, context.target, "[DEMONOLOGY] Death Coil", { expected_cooldown = 120 }) end },
    { name = "LifeTap" },
    { name = "DarkPact", matches = dark_pact_matches, execute = function(context) return NS.try_cast(ACTION.DarkPact, context.me, "[DEMONOLOGY] Dark Pact", { skip_range = true, expected_cooldown = 10 }) end },
    { name = "ShadowWard", matches = shadow_ward_matches, execute = function(context) return NS.try_cast(ACTION.ShadowWard, context.me, "[DEMONOLOGY] Shadow Ward", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "HowlofTerror", matches = howl_of_terror_matches, execute = function(context) return NS.try_cast(ACTION.HowlofTerror, context.me, "[DEMONOLOGY] Howl of Terror", { skip_range = true, expected_cooldown = 40 }) end },
    { name = "Fear", matches = fear_matches, execute = function(context) return NS.try_cast(ACTION.Fear, context.target, "[DEMONOLOGY] Fear") end },
    { name = "Seduction", matches = seduction_matches, execute = function(context) return NS.try_cast(ACTION.Seduction, context.target, "[DEMONOLOGY] Seduction") end },
    { name = "Soulshatter", matches = soulshatter_matches, execute = function(context) return NS.try_cast(ACTION.Soulshatter, context.me, "[DEMONOLOGY] Soulshatter", { skip_range = true }) end },
    { name = "LifeTap" },
    { name = "ShadowBolt" },
    { name = "Incinerate", matches = incinerate_matches, execute = function(context) return NS.try_cast(ACTION.Incinerate, context.target, "[DEMONOLOGY] Incinerate") end },
    { name = "Healthstone",
      matches = function(context, state)
          local threshold = spec_kit.setting_number(context, "healthstone_hp", 0)
          if not spec_kit.setting_bool(context, "use_auto_consumables", true) then return false end
          if not spec_kit.setting_bool(context, "use_healthstones", true) then return false end
          if threshold <= 0 then return false end
          if (context.hp or 100) > threshold then return false end
          if context.is_casting then return false end
          return state and state.healthstone_ready == true
      end,
      execute = function(_, state)
          return state and state.healthstone_id and NS.use_item_by_id and NS.use_item_by_id(state.healthstone_id) or false
      end,
    },
}

-- Replace imperative match functions with DSL-compiled equivalents.
-- The strategies table is static, but we still match by name so future
-- insertions/deletions in the priority list do not silently break the
-- substitution indices.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("demonology", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warlock demonology rotation registered") end
return { strategies = strategies, build_state = build_state }

