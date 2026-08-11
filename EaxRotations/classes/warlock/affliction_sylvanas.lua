-- affliction_sylvanas.lua -- Warlock Affliction DPS for TBC Anniversary (2.5.5).
-- WHAT:  multi-DoT priority list with snapshot-aware refresh, Nightfall proc
--         consumption, execute-phase Drain Soul, curse mode selection, and
--         IZI spread_dot multi-target cycling.
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors wowsims APL + TBC affliction consensus: UA > Corruption >
--         Siphon Life > Immolate > curse (CoA/CoD/CoE/CoR/CoW) > Shadow Bolt filler.
-- SAFETY: Pattern 14 nil-guarded via spec_kit.safe_state(); no on_update() allocs.

-- TBC Warlock Affliction priority list with multi-DoT cycling, Nightfall procs, and execute drain.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end
local pet_manager = require("shared/pet_manager_sylvanas")

local potion_helper = require("shared/potion_helper_sylvanas")
local DotTTD = require("shared/dot_ttd_gating_sylvanas")
local BuffHelper = require("shared/buff_manager_helper_sylvanas")
local Profiler = require("shared/profiler_helper_sylvanas")
local _ts_ok, TSHelper = pcall(require, "shared/ts_helper_sylvanas")
if not _ts_ok or type(TSHelper) ~= "table" then TSHelper = nil end
local _planner_ok, planner = pcall(require, "shared/cooldown_planner_sylvanas")
if not _planner_ok or type(planner) ~= "table" then planner = nil end
local SPELLS = NS.WarlockSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local curse_helper = require("shared/warlock_curse_helper_sylvanas")
local healthstone_helper = require("shared/warlock_healthstone_sylvanas")
local soulshatter_helper = require("shared/warlock_soulshatter_sylvanas")
local death_coil_helper = require("shared/warlock_death_coil_sylvanas")
local shadow_ward_helper = require("shared/warlock_shadow_ward_sylvanas")
local CURSE_REFRESH_WINDOW = curse_helper.CURSE_REFRESH_WINDOW

-- Centralized spell resolver via spec_kit (rank IDs from warlock/class_sylvanas.lua).
-- LOCAL_SPELLS (below) handles spells not in the class spell table.
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    Corruption          = define("Corruption",          { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    CurseOfAgony        = define("CurseOfAgony",        { 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfAgony"),
    CurseOfDoom         = define("CurseOfDoom",         { 30910, 603 }, "CurseOfDoom"),
    CurseOfRecklessness = define("CurseOfRecklessness", { 27226, 11717, 7659, 7658, 704 }, "CurseOfRecklessness"),
    CurseOfWeakness     = define("CurseOfWeakness",     { 30909, 27224, 11708, 11707, 7646, 6205, 1108, 702 }, "CurseOfWeakness"),
    Immolate            = define("Immolate",            { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
    LifeTap             = define("LifeTap",             { 27222, 11689, 11688, 11687, 1456, 1455, 1454 }, "LifeTap"),
    SeedOfCorruption    = define("SeedOfCorruption",    { 27243 }, "SeedOfCorruption"),
    ShadowBolt          = define("ShadowBolt",          { 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
    SiphonLife          = define("SiphonLife",          { 30911, 27264, 18881, 18880, 18879, 18265 }, "SiphonLife"),
    Soulshatter         = define("Soulshatter",         { 29858 }, "Soulshatter"),
    SummonFelhunter     = define("SummonFelhunter",     { 691 }, "SummonFelhunter"),
    UnstableAffliction  = define("UnstableAffliction",  { 30405, 30404, 30108 }, "UnstableAffliction"),
}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { potions = {} } } end
local TBC_POTIONS = (TBC.ITEMS and TBC.ITEMS.potions) or {}

-- IZI SDK for spread_dot multi-DoT support
local _izi = nil
do
    local ok, mod = pcall(require, "common/izi_sdk")
    if ok and type(mod) == "table" then _izi = mod end
end

-- CC debuff IDs that damage would break (don't DoT these targets)
local CC_DEBUFF_IDS = {
    118, 12824, 12825, 12826, 28271, 28272,  -- Polymorph
    6770, 2070, 11297,                        -- Sap
    1776,                                     -- Gouge
    2094,                                     -- Blind
    3355, 14308, 14309,                       -- Freezing Trap
    20066,                                    -- Repentance
    19386,                                    -- Wyvern Sting
    5782, 6213, 6215, 5484, 17928,            -- Fear / Howl of Terror
    2637, 18657, 18658,                       -- Hibernate
    33786,                                    -- Cyclone
    18647,                                    -- Banish
}

--- Check if a unit has a breakable CC debuff (don't DoT CC'd targets)
local function is_cc_target(unit)
    if not unit or not NS.debuff_up then return false end
    for _, cc_id in ipairs(CC_DEBUFF_IDS) do
        if NS.debuff_up(unit, { cc_id }) then return true end
    end
    return false
end

--- Check if a unit is engaged with the player (not an unengaged patrol)
local function is_engaged(unit, me)
    if not unit or not me then return true end
    -- Already damaged = engaged
    local ok_hp, hp = pcall(function() return unit:get_health_percentage() end)
    if ok_hp and hp and hp < 100 then return true end
    -- Targeting me or my party = engaged
    local ok_t, target = pcall(function() return unit:get_target() end)
    if ok_t and target then
        if NS.same_unit and NS.same_unit(target, me) then return true end
        -- Check if targeting a party member
        local allies = NS.GetPartyMembers and NS.GetPartyMembers() or {}
        for _, ally in ipairs(allies) do
            if ally and NS.same_unit and NS.same_unit(target, ally) then return true end
        end
    end
    return false
end

--- Scan all DoT debuffs on the target in one buff_manager call and return a
--- map of debuff category -> remaining seconds. Falls back to NS.debuff_remains
--- when buff_manager is unavailable so tests without the module still work.
local function scan_target_dots(target)
    if not target then return {} end
    local rows = BuffHelper.get_all_debuffs(target, 50)
    if not rows or type(rows) ~= "table" then return {} end
    local out = {}
    for _, row in ipairs(rows) do
        local id = row and (row.buff_id or row.spell_id or row.id)
        if id then
            local remains = row.remaining or 0
            if remains > 0 then
                -- buff_manager may return milliseconds or seconds depending on build.
                -- Values >= 1000 are almost certainly ms; smaller values are seconds.
                if remains >= 1000 then remains = remains / 1000 end
                out[id] = remains
            end
        end
    end
    return out
end

local function dot_remains_from_scan(target, scan, id_list)
    if not id_list then return 0 end
    if scan then
        for _, id in ipairs(id_list) do
            if scan[id] then return scan[id] end
        end
    end
    -- Fallback: if the bulk buff_manager cache is empty/unavailable, use the
    -- standard NS.debuff_remains path so DoTs are not treated as expired.
    if target and NS.debuff_remains then
        local ok, remains = pcall(NS.debuff_remains, target, id_list)
        if ok and type(remains) == "number" and remains > 0 then
            return remains
        end
    end
    return 0
end

local function profile_enabled(context)
    return spec_kit.setting_bool(context, "debug_profile", false)
end

local function profiled_matches(name, fn)
    return function(context, state)
        if not profile_enabled(context) then return fn(context, state) end
        Profiler.start(name)
        local ok, result = pcall(fn, context, state)
        Profiler.stop(name, not ok)
        if not ok then error(result, 0) end
        return result
    end
end


--- Find a target missing the specified DoT.
--- Primary: TSHelper.get_dps_targets (target_selector priority list).
--- Fallback: IZI spread_dot when TSHelper is unavailable or yields no valid unit.
--- Safety: skips CC'd targets, unengaged patrols, and dying adds (< 20% HP).
--- Perf: results cached per-tick keyed by spell_id (Pattern 4: no redundant scans).
---       3 spread strategies × 2 calls each (matches+execute) = 6 scans → 3 max.
---@param spell_id number DoT spell ID to check
---@param radius number|nil Search radius (default 40)
---@return game_object|nil target Missing the DoT, or nil
local _dot_target_cache = {}     -- [spell_id] = target|false
local _dot_target_cache_tick = -1
local function find_dot_target(spell_id, radius)
    -- Per-tick cache: avoid re-scanning the same enemy list for the same debuff
    local now = NS.time_now and NS.time_now() or 0
    if now ~= _dot_target_cache_tick then
        _dot_target_cache = {}
        _dot_target_cache_tick = now
    end
    if _dot_target_cache[spell_id] ~= nil then
        return _dot_target_cache[spell_id] or nil  -- false→nil
    end

    local me = NS.GetPlayer and NS.GetPlayer() or nil
    local result = nil

    -- Primary: target_selector DPS list (priority-ordered by TS)
    if TSHelper and TSHelper.get_dps_targets then
        local ok_ts, targets = pcall(TSHelper.get_dps_targets, 10)
        if ok_ts and type(targets) == "table" then
            for i = 1, #targets do
                local unit = targets[i]
                if unit then
                    local ok_v, valid = pcall(function()
                        if unit.is_valid then return unit:is_valid() end
                        return true
                    end)
                    if (not ok_v or valid ~= false)
                        and not is_cc_target(unit)
                        and (not me or is_engaged(unit, me))
                    then
                        -- IZI SDK: skip damage-immune targets (Divine Shield, etc.)
                        local skip_immune = false
                        if type(unit.is_damage_immune) == "function" then
                            local ok_im, im = pcall(unit.is_damage_immune, unit)
                            if ok_im and im then skip_immune = true end
                        end
                        if not skip_immune then
                            local ok_hp, hp = pcall(function() return unit:get_health_percentage() end)
                            if not (ok_hp and hp and hp < 20) then
                                local has_dot = NS.debuff_up and NS.debuff_up(unit, { spell_id })
                                if not has_dot then
                                    result = unit
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Fallback: IZI enemies() when TSHelper unavailable or no valid target
    if not result and _izi and _izi.enemies then
        local ok_e, enemies = pcall(_izi.enemies, radius or 40)
        if ok_e and type(enemies) == "table" then
            for i = 1, #enemies do
                local unit = enemies[i]
                if unit then
                    if not is_cc_target(unit)
                        and (not me or is_engaged(unit, me))
                    then
                        -- IZI SDK: skip damage-immune targets
                        local skip_immune = false
                        if type(unit.is_damage_immune) == "function" then
                            local ok_im, im = pcall(unit.is_damage_immune, unit)
                            if ok_im and im then skip_immune = true end
                        end
                        if not skip_immune then
                            local ok_hp, hp = pcall(function() return unit:get_health_percentage() end)
                            if not (ok_hp and hp and hp < 20) then
                                local has_dot = NS.debuff_up and NS.debuff_up(unit, { spell_id })
                                if not has_dot then
                                    result = unit
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    _dot_target_cache[spell_id] = result or false  -- cache nil as false
    return result
end

-- ============================================================================
-- Debuff & Buff ID tables
-- ============================================================================
local CORRUPTION_DEBUFF      = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local CURSE_OF_AGONY_DEBUFF  = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }
local CURSE_OF_DOOM_DEBUFF   = { 30910, 603 }
local UNSTABLE_AFFL_DEBUFF   = { 30405, 30404, 30108 }
local SIPHON_LIFE_DEBUFF     = { 30911, 27264, 18881, 18880, 18879, 18265 }
local IMMOLATE_DEBUFF        = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local SHADOW_EMBRACE_DEBUFF  = { 32386, 32388, 32389, 32390, 32391 }
local CURSE_OF_ELEMENTS_DEBUFF = { 27228, 11722, 11721, 1490 }
local NIGHTFALL_BUFF         = { 17941 }  -- Shadow Trance
local FEL_ARMOR_BUFF         = { 28189, 28176 }
-- Imp Firebolt spell IDs (all ranks). Only the Imp has Firebolt, so these also
-- identify the active pet as an Imp.
local IMP_FIREBOLT_IDS       = { 3110, 7799, 7800, 7801, 7802, 11762, 11763, 27267 }

local DOT_REFRESH_WINDOW = 1.5   -- refresh within last 1.5s per Research Angle 1 (clip <1.5s)
local SOUL_SHARD_CAPTURE_TTD = 5  -- TBC: Drain Soul is shard-capture only (mob about to die); sub-25% execute is Wrath, not TBC
local LIFE_TAP_SAFETY_HP = 35   -- don't Life Tap below this HP%

-- Snapshot-aware refresh constants
local SPELL_DMG_UPGRADE_RATIO = 1.08    -- Refresh only if 8%+ spell damage upgrade
local REFRESH_EXTRA_WINDOW = 1.5         -- Extra seconds past pandemic window for upgrade refresh


local LOCAL_SPELLS = {
    DrainLife       = NS.spell_action({ 27220, 27219, 11700, 11699, 7651, 709, 699, 689 }, "DrainLife"),
    DrainSoul       = NS.spell_action({ 27217, 11675, 8289, 8288, 1120 }, "DrainSoul"),
    DarkPact        = NS.spell_action({ 27265, 18938, 18937, 18220 }, "DarkPact"),
    Fear            = NS.spell_action({ 6215, 6213, 5782 }, "Fear"),
    HowlOfTerror    = NS.spell_action({ 17928, 5484 }, "HowlOfTerror"),
    CurseWeakness   = NS.spell_action({ 30909, 27224, 11708, 11707, 7646, 6205, 1108, 702 }, "CurseOfWeakness"),
    CurseTongues    = NS.spell_action({ 11719, 1714 }, "CurseOfTongues"),
    CurseExhaustion = NS.spell_action({ 18223 }, "CurseOfExhaustion"),
    CurseElements   = NS.spell_action({ 27228, 11722, 11721, 1490 }, "CurseOfElements"),
    DrainMana       = NS.spell_action({ 30908, 27221, 11704, 11703, 6226, 5138 }, "DrainMana"),
    HealthFunnel    = NS.spell_action({ 27259, 11695, 11694, 11693, 3700, 3699, 3698, 755 }, "HealthFunnel"),
    CreateHealthstone = NS.spell_action({ 27230, 11730, 11729, 6202, 6201, 5699 }, "CreateHealthstone"),
    FelDomination   = NS.spell_action({ 18708 }, "FelDomination"),
    DeathCoil       = NS.spell_action({ 27223, 17926, 17925, 6789 }, "DeathCoil"),
    ShadowWard      = NS.spell_action({ 28610, 11740, 11739, 6229 }, "ShadowWard"),
    DemonArmor      = NS.spell_action({ 27260, 11735, 11734, 11733, 1086, 706 }, "DemonArmor"),
    FelArmor        = NS.spell_action({ 28189, 28176 }, "FelArmor"),
    AmplifyCurse    = NS.spell_action({ 18288 }, "AmplifyCurse"),
    BloodFury       = NS.spell_action({ 33697, 20572 }, "BloodFury"),
    Berserking      = NS.spell_action({ 20554, 26297 }, "Berserking"),
    ArcaneTorrent   = NS.spell_action({ 25046 }, "ArcaneTorrent"),
    CreateSoulstone = NS.spell_action({ 27238, 20756, 20755, 20752, 693 }, "CreateSoulstone"),
    Shoot           = NS.spell_action({ 5019 }, "Shoot"),
    Shadowburn      = NS.spell_action({ 30546, 27263, 18871, 18870, 18869, 18868, 18867, 17877 }, "Shadowburn"),
    RainOfFire      = NS.spell_action({ 27212, 17954, 17953, 5740 }, "RainOfFire"),
}


local BLOODLUST_LOWER_RATIO = 1.04      -- More aggressive upgrade threshold during Bloodlust/Heroism
local BLOODLUST_BUFFS = { 2825, 32182 }  -- Bloodlust (Horde) / Heroism (Alliance)
local HEALTHSTONE_IDS = (TBC.ITEMS and TBC.ITEMS.healthstones) or { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local SOULSTONE_BUFF_IDS = { 27239, 20765, 20764, 20763, 20762, 20707 }
local SOULSTONE_ITEMS = { 22116, 16896, 16895, 16893, 16892, 5232 }
local MANA_POTION_IDS = {
    TBC_POTIONS.crystal_mana or 33935,
    TBC_POTIONS.auchenai_mana or 32948,
    TBC_POTIONS.super_mana or 22832,
    TBC_POTIONS.super_rejuvenation or 22850,
    TBC_POTIONS.major_mana or 13444,
    TBC_POTIONS.superior_mana or 13443,
}

-- ============================================================================
-- Schema for safe_state (Pattern 14 nil-guard elimination).
-- ============================================================================
local AFFL_SCHEMA = {
    -- DoT remains
    ua_remains = 0, corruption_remains = 0, agony_remains = 0,
    doom_remains = 0, siphon_remains = 0, immolate_remains = 0,
    coe_remains = 0, recklessness_remains = 0, weakness_remains = 0,
    -- DoT stacks
    se_stacks = 0, isb_stacks = 0,
    -- Proc / resource
    nightfall_active = false, mana_pct = 100, hp_pct = 100,
    target_hp = 100, enemy_count = 0,
    -- Pet
    pet_alive = false, pet_health = 100, pet_mana = 100,
    pet_type_imp = false, pet_casting_firebolt = false, has_pet = false,
    in_combat = false,
    has_demonic_sacrifice = false,
    -- Items
    mana_potion_id = nil, healthstone_id = nil, healthstone_ready = false,
    amplify_curse_ready = false,
    -- Soulstone / Wand
    has_soulstone = false, wand_learned = false,
    -- Snapshot
    spell_damage = 0, snapshot_ua_dmg = 0, snapshot_corruption_dmg = 0,
    snapshot_siphon_dmg = 0, snapshot_immolate_dmg = 0,
    -- Power windows
    bloodlust_active = false, has_bloodlust = false,
    major_cd_active = false, major_cd_window = false,
}

-- ============================================================================
-- State builder (pre-allocated)
-- ============================================================================
local aff_state = {
    -- DoT remains on target
    ua_remains = 0,
    corruption_remains = 0,
    agony_remains = 0,
    doom_remains = 0,
    siphon_remains = 0,
    immolate_remains = 0,
    recklessness_remains = 0,
    weakness_remains = 0,
	    -- Shadow Embrace stacks
	    se_stacks = 0,
	    -- Improved Shadow Bolt (Shadow Vulnerability) stacks
    -- Proc
    nightfall_active = false,
    -- Resources
    mana_pct = 100,
    hp_pct = 100,
    target_hp = 100,
    -- Pet
    pet_alive = false,
    pet_health = 100,
    pet_mana = 100,
    pet_type_imp = false,
    -- Items
    mana_potion_id = nil,
    healthstone_id = nil,
    healthstone_ready = false,
    amplify_curse_ready = false,
    -- Soulstone / Wand
    has_soulstone = false,
    wand_learned = false,    -- Snapshot state (spell damage when DoT was applied — persisted across build_state calls)
    spell_damage = 0,
    snapshot_ua_dmg = 0,
    snapshot_corruption_dmg = 0,
    snapshot_siphon_dmg = 0,
    snapshot_immolate_dmg = 0,
    snapshot_target = nil,
    -- AoE
    enemy_count = 1,
}

local _last_build_state_time = -1
local function build_state(context)
    -- Pattern 6: frame-keyed dedup — skip rebuild if already built this frame
    local now = context.now or (NS.time_now and NS.time_now() or 0)
    if now == _last_build_state_time then return spec_kit.safe_state(aff_state, AFFL_SCHEMA) end
    if context.now then _last_build_state_time = now end
    local target = context.target
    if target then
        local dot_scan = scan_target_dots(target)
        aff_state.ua_remains = dot_remains_from_scan(target, dot_scan, UNSTABLE_AFFL_DEBUFF)
        aff_state.corruption_remains = dot_remains_from_scan(target, dot_scan, CORRUPTION_DEBUFF)
        aff_state.agony_remains = dot_remains_from_scan(target, dot_scan, CURSE_OF_AGONY_DEBUFF)
        aff_state.doom_remains = dot_remains_from_scan(target, dot_scan, CURSE_OF_DOOM_DEBUFF)
        aff_state.siphon_remains = dot_remains_from_scan(target, dot_scan, SIPHON_LIFE_DEBUFF)
        aff_state.immolate_remains = dot_remains_from_scan(target, dot_scan, IMMOLATE_DEBUFF)
        aff_state.coe_remains = dot_remains_from_scan(target, dot_scan, CURSE_OF_ELEMENTS_DEBUFF)
        aff_state.recklessness_remains = dot_remains_from_scan(target, dot_scan, curse_helper.CURSE_OF_RECKLESSNESS_DEBUFF)
        aff_state.weakness_remains     = dot_remains_from_scan(target, dot_scan, curse_helper.CURSE_OF_WEAKNESS_DEBUFF)
        aff_state.se_stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, SHADOW_EMBRACE_DEBUFF) or 0
        aff_state.target_hp = (target.get_health_percentage and target:get_health_percentage()) or 100
    else
        aff_state.ua_remains = 0
        aff_state.corruption_remains = 0
        aff_state.agony_remains = 0
        aff_state.siphon_remains = 0
        aff_state.immolate_remains = 0
        aff_state.coe_remains = 0
        aff_state.recklessness_remains = 0
        aff_state.weakness_remains = 0
        aff_state.se_stacks = 0
	        aff_state.target_hp = 100
	    end
	    -- Nightfall proc
	    aff_state.nightfall_active = NS.has_player_buff and NS.has_player_buff(NIGHTFALL_BUFF) or false
	    -- Resources
	aff_state.mana_pct = context.mana_pct
	    or (context.me and context.me.get_mana_percentage and context.me:get_mana_percentage())
	    or 100
	aff_state.hp_pct = context.hp or 100
	aff_state.enemy_count = context.enemy_count or 1
	aff_state.in_combat = context.in_combat or false            -- Pet status (via pet object if available)
            local pet = context.pet
            if pet then
                aff_state.pet_alive = (pet.is_alive and pet:is_alive())
                aff_state.pet_health = (pet.get_health_percentage and pet:get_health_percentage()) or 100
                aff_state.pet_mana = (pet.get_mana_percentage and pet:get_mana_percentage()) or 100
            else
                aff_state.pet_alive = false
                aff_state.pet_health = 100
                aff_state.pet_mana = 100
            end
            aff_state.has_pet = aff_state.pet_alive
            -- Imp Machine Gun detection: only the Imp has Firebolt
            aff_state.pet_type_imp = false
            if pet and aff_state.pet_alive then
                if pet.is_casting_spell and pet:is_casting_spell() and pet.get_active_spell_id then
                    local sid = pet:get_active_spell_id()
                    if type(sid) == "number" then
                        for _, id in ipairs(IMP_FIREBOLT_IDS) do
                            if sid == id then
                                aff_state.pet_type_imp = true
                                break
                            end
                        end
                    end
                end
                if not aff_state.pet_type_imp and pet.get_name then
                    local ok_name, name = pcall(pet.get_name, pet)
                    if ok_name and type(name) == "string" then
                        aff_state.pet_type_imp = name:lower():find("imp") ~= nil
                    end
                end
            end
            aff_state.has_demonic_sacrifice = context.me and NS.buff_up and NS.buff_up(context.me, {18789, 18790, 18791, 18792, 35701}) or false
            -- Amplify Curse readiness
            aff_state.amplify_curse_ready = NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.AmplifyCurse, NS.PLAYER_UNIT, { skip_range = true }) or false
	    aff_state.spell_damage = context.spell_damage or 0  -- Current spell damage from NS (provided by middleware or character API)
	    -- Bloodlust/Heroism buff — enables more aggressive snapshot upgrade threshold
	    aff_state.has_bloodlust = context.me and NS.buff_up and NS.buff_up(context.me, BLOODLUST_BUFFS) or false
	    -- Maintain snapshot state: reset snapshots if DoT expired (stale)
	    local target_key = target and (target.get_guid and target:get_guid()) or nil
	    if target_key ~= aff_state.snapshot_target then
	        -- Target changed: reset all snapshots for fresh tracking
	        aff_state.snapshot_ua_dmg = 0
	        aff_state.snapshot_corruption_dmg = 0
	        aff_state.snapshot_siphon_dmg = 0
	        aff_state.snapshot_immolate_dmg = 0
	        aff_state.snapshot_target = target_key
	    else
	        -- Reset per-DoT snapshot if DoT completely fell off
	        if aff_state.ua_remains <= 0 then aff_state.snapshot_ua_dmg = 0 end
	        if aff_state.corruption_remains <= 0 then aff_state.snapshot_corruption_dmg = 0 end
	        if aff_state.siphon_remains <= 0 then aff_state.snapshot_siphon_dmg = 0 end
	        if aff_state.immolate_remains <= 0 then aff_state.snapshot_immolate_dmg = 0 end
	    end
    -- Items
    aff_state.mana_potion_id = nil
    for _, id in ipairs(MANA_POTION_IDS) do
        if NS.is_item_ready and NS.is_item_ready(id) then aff_state.mana_potion_id = id; break end
    end
    aff_state.healthstone_id = nil
    aff_state.healthstone_ready = false
    if NS.is_item_ready then
        for _, id in ipairs(HEALTHSTONE_IDS) do
            local ok, ready = pcall(NS.is_item_ready, id)
            if ok and ready then
                aff_state.healthstone_id = id
                aff_state.healthstone_ready = true
                break
            end
        end
    end
    -- Soulstone buff check (pre-combat self-buff)
    local me = context.me
    aff_state.has_soulstone = me and NS.has_player_buff and NS.has_player_buff(SOULSTONE_BUFF_IDS) or false
    if not aff_state.has_soulstone and NS.has_item then
        for _, id in ipairs(SOULSTONE_ITEMS) do
            if NS.has_item(id) then aff_state.has_soulstone = true; break end
        end
    end
    -- Wand (Shoot) spell readiness
    aff_state.wand_learned = NS.spell_exists and NS.spell_exists(5019) or false

    -- Major power-window awareness for racial/trinket alignment
    aff_state.bloodlust_active = me and NS.buff_up and NS.buff_up(me, BLOODLUST_BUFFS) or false
    aff_state.major_cd_active = planner and planner.is_major_offensive_cd_active(context) or false
    aff_state.major_cd_window = aff_state.bloodlust_active or aff_state.major_cd_active

    return spec_kit.safe_state(aff_state, AFFL_SCHEMA)
	end

	-- ============================================================================
	-- Snapshot upgrade logic
	-- ============================================================================
	
	-- Determine if current spell damage justifies refreshing a DoT early
	-- Returns true if: DoT expired, in pandemic window with upgrade, or about to fall off
	local function should_snapshot_upgrade(current_dmg, snapshotted_dmg, remains, refresh_window, ratio)
	    -- Always refresh if DoT has expired
	    if remains <= 0 then return true end
	    -- Always refresh if in pandemic window (about to fall off anyway)
	    if remains <= refresh_window then return true end
	    -- No previous snapshot to compare — refresh normally
	    if snapshotted_dmg <= 0 then return true end
	    -- Upgrade refresh: only if current damage is significantly higher AND still within extended window
	    if current_dmg >= snapshotted_dmg * ratio and remains <= refresh_window + REFRESH_EXTRA_WINDOW then
	        return true
	    end
	    return false
	end

	-- ============================================================================
	-- Helper functions
	-- ============================================================================

local function select_curse(context, state)
    local assigned = spec_kit.setting(context, "warlock_assigned_curse", "none")
    if assigned ~= "none" then return assigned end

    local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
    if curse_mode == "agony" then
        if context.is_pvp and context.enemy_healer then return "tongues" end
        if context.is_pvp and context.melee_on_you then return "exhaustion" end
        return "agony"
    elseif curse_mode == "doom" then return "doom"
    elseif curse_mode == "elements" then return "elements"
    elseif curse_mode == "recklessness" then return "recklessness"
    elseif curse_mode == "weakness" then return "weakness"
    elseif curse_mode == "none" then return nil
    end

    if context.is_pvp then
        if context.enemy_healer then return "tongues" end
        if context.melee_on_you then return "exhaustion" end
    end
    -- Group/raid curse auto-selection is gated by player setting (default off)
    if spec_kit.setting_bool(context, "warlock_curse_group_aware", false) then
        if (state.enemy_count or 0) >= 3 then return "elements" end
        if context.is_group then
            local reck_threshold = spec_kit.setting_number(context, "warlock_curse_reck_threshold", 2)
            if (context.physical_dps_count or 0) >= reck_threshold then return "recklessness" end
            return "elements"
        end
    end
    -- Auto mode: Doom for long fights (TTD >= 60s), Agony for short fights.
    local ttd = context.ttd or 999
    if ttd >= 60 then return "doom" end
    return "agony"
end

-- Centralized assigned-curse gate (used by all curse matches for strict enforcement)
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

-- Racial ability match gate for all racial strategies
local function racial_matches(context, state)
    if not context.has_valid_enemy_target then return false end
    if not context.in_combat then return false end
    -- TTD gate: don't use racials if target is about to die
    if context.ttd_known and context.ttd > 0 and context.ttd < 8 then return false end
    -- Stack racials with major power windows; timeout fallback so they fire
    local align = state.major_cd_window or false
    local combat_time = context.combat_time or 0
    local ttd = context.ttd or 999
    if not align and combat_time < 45 and ttd > 15 then return false end
    return true
end


-- ============================================================================
-- Declarative Strategy DSL definitions (6 strategies converted)
-- ============================================================================
local DSL_DEFS = {
    {
        name = "PetDefensive",
        conditions = {
            { type = "state", field = "pet_alive", op = "==", value = true },
            { type = "in_combat" },
            { type = "state", field = "pet_health", op = "<=", value = 35 },
        },
        action = { type = "custom", fn = function(context, state)
            return pet_manager.set_defensive()
        end },
    },
    {
        name = "PetPassive",
        conditions = {
            { type = "state", field = "pet_alive", op = "==", value = true },
            { type = "in_combat" },
            { type = "hp_threshold", unit = "self", op = "<=", value = 25 },
        },
        action = { type = "custom", fn = function(context, state)
            return pet_manager.set_passive()
        end },
    },
    {
        name = "PetAggressive",
        conditions = {
            { type = "state", field = "pet_alive", op = "==", value = true },
            { type = "in_combat" },
            { type = "state", field = "pet_health", op = ">=", value = 50 },
        },
        action = { type = "custom", fn = function(context, state)
            return pet_manager.set_aggressive()
        end },
    },
    {
        name = "NightfallProc",
        conditions = {
            { type = "context", field = "has_valid_enemy_target", op = "==", value = true },
            { type = "state", field = "nightfall_active", op = "==", value = true },
            { type = "spell_ready", spell = ACTION.ShadowBolt, target = "target" },
        },
        action = { type = "cast", spell = ACTION.ShadowBolt, target = "target", label = "[AFFL] Nightfall instant Shadow Bolt" },
    },
    {
        name = "NightfallProc",
        conditions = {
            { type = "context", field = "has_valid_enemy_target", op = "==", value = true },
            { type = "state", field = "nightfall_active", op = "==", value = true },
            { type = "spell_ready", spell = ACTION.ShadowBolt, target = "target" },
        },
        action = { type = "cast", spell = ACTION.ShadowBolt, target = "target", label = "[AFFL] Nightfall instant Shadow Bolt" },
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
    { name = "PetDefensive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not (context.in_combat or false) then return false end
          if (state.pet_health or 100) > 35 then return false end
          return true
      end,
      execute = function() return pet_manager.set_defensive() end },
    -- Pet State: set passive when player HP critically low
    { name = "PetPassive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not (context.in_combat or false) then return false end
          if (context.hp or 100) > 25 then return false end
          return true
      end,
      execute = function() return pet_manager.set_passive() end },
    -- Pet State: set aggressive during combat when pet is healthy
    { name = "PetAggressive",
      matches = function(context, state)
          if not state.pet_alive then return false end
          if not (context.in_combat or false) then return false end
          if (state.pet_health or 100) < 50 then return false end
          return true
      end,
      execute = function() return pet_manager.set_aggressive() end },

    -- ------------------------------------------------------------------------
    -- 1. Death Coil (survival heal + CC)
    -- ------------------------------------------------------------------------
    death_coil_helper.make_strategy("DeathCoilSurvival", LOCAL_SPELLS.DeathCoil, { label = "[AFFL] Death Coil (survival + heal)" }),

    -- ------------------------------------------------------------------------
    -- 2. Healthstone
    -- ------------------------------------------------------------------------
    healthstone_helper.make_strategy("Healthstone", {
        use_state_id = true,
        require_in_combat = false,
        priority = 850,
        is_defensive = true,
    }),

    -- ------------------------------------------------------------------------
    -- 3. Soulshatter (threat reduction)
    -- ------------------------------------------------------------------------
    soulshatter_helper.make_strategy("Soulshatter", ACTION.Soulshatter, "[AFFL] Soulshatter"),

    -- ------------------------------------------------------------------------
    -- ------------------------------------------------------------------------
    -- 4. Nightfall proc - instant Shadow Bolt
    -- ------------------------------------------------------------------------
    {
        name = "NightfallProc",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if not state.nightfall_active then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.ShadowBolt, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(ACTION.ShadowBolt, context.target, "[AFFL] Nightfall instant Shadow Bolt")
        end,
    },
    -- ------------------------------------------------------------------------
    {
        name = "UnstableAffliction",
        matches = profiled_matches("UnstableAffliction", function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.ua_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
            local ratio = state.has_bloodlust and BLOODLUST_LOWER_RATIO or SPELL_DMG_UPGRADE_RATIO
            if (state.ua_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_ua_dmg or 0, state.ua_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            -- DoT TTD gating
            local ttd_threshold = spec_kit.setting_number(context, "dot_ttd_threshold", 50) / 100
            if DotTTD.should_skip_dot(context.ttd, DotTTD.DOT_DURATIONS.unstable_affliction, ttd_threshold) then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.UnstableAffliction, context.target) or false
        end),
        execute = function(context)
            local ok = NS.try_cast(ACTION.UnstableAffliction, context.target, "[AFFL] Unstable Affliction")
            if ok and aff_state.spell_damage then aff_state.snapshot_ua_dmg = aff_state.spell_damage end
            return ok
        end,
    },
    -- Unstable Affliction Spread — multi-DoT (TSHelper + IZI enemies fallback)
    {
        name = "UnstableAfflictionSpread",
        matches = function(context, state)
            -- Fire spread to additional targets when primary already has the DoT (remains sufficient).
            -- Inverted from previous to match intended multi-dot behavior.
            if (state.ua_remains or 0) <= DOT_REFRESH_WINDOW then return false end
            local target = find_dot_target(UNSTABLE_AFFL_DEBUFF[1])
            if not target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.UnstableAffliction, target) or false
        end,
        execute = function(context)
            local target = find_dot_target(UNSTABLE_AFFL_DEBUFF[1])
            if not target then return false end
            return NS.try_cast(ACTION.UnstableAffliction, target, "[AFFL] Unstable Affliction Spread")
        end,
    },

    -- ------------------------------------------------------------------------
    -- Siphon Life (DoT + self-heal, if talented)
    -- Requires ISB debuff on target to maximize Shadow damage benefit
    -- ------------------------------------------------------------------------
    {
        name = "CorruptionDoT",
        matches = profiled_matches("CorruptionDoT", function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.corruption_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
            local ratio = state.has_bloodlust and BLOODLUST_LOWER_RATIO or SPELL_DMG_UPGRADE_RATIO
            if (state.corruption_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_corruption_dmg or 0, state.corruption_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            -- DoT TTD gating
            local ttd_threshold = spec_kit.setting_number(context, "dot_ttd_threshold", 50) / 100
            if DotTTD.should_skip_dot(context.ttd, DotTTD.DOT_DURATIONS.corruption, ttd_threshold) then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.Corruption, context.target) or false
        end),
        execute = function(context)
            local ok = NS.try_cast(ACTION.Corruption, context.target, "[AFFL] Corruption")
            if ok and aff_state.spell_damage then aff_state.snapshot_corruption_dmg = aff_state.spell_damage end
            return ok
        end,
    },
    -- Corruption Spread — multi-DoT via find_dot_target (TSHelper + IZI enemies fallback)
    {
        name = "CorruptionSpread",
        matches = function(context, state)
            -- Fire spread to additional targets when primary already has the DoT (remains sufficient).
            -- Inverted from previous to match intended multi-dot behavior.
            if (state.corruption_remains or 0) <= DOT_REFRESH_WINDOW then return false end
            local target = find_dot_target(CORRUPTION_DEBUFF[1])
            if not target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.Corruption, target) or false
        end,
        execute = function(context)
            local target = find_dot_target(CORRUPTION_DEBUFF[1])
            if not target then return false end
            return NS.try_cast(ACTION.Corruption, target, "[AFFL] Corruption Spread")
        end,
    },

    -- ------------------------------------------------------------------------
    -- MovingCorruption (instant DoT while moving)
    -- ------------------------------------------------------------------------
    {
        name = "MovingCorruption",
        matches = function(context, state)
            if not context.is_moving then return false end
            if not context.has_valid_enemy_target then return false end
            if (state.corruption_remains or 0) > DOT_REFRESH_WINDOW then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.Corruption, context.target) or false
        end,
        execute = function(context)
            local ok = NS.try_cast(ACTION.Corruption, context.target, "[AFFL] Corruption (moving)")
            if ok and aff_state.spell_damage then aff_state.snapshot_corruption_dmg = aff_state.spell_damage end
            return ok
        end,
    },

    -- ------------------------------------------------------------------------
    -- Unstable Affliction (primary DoT — dispel protection, 1.5s cast)
    -- ------------------------------------------------------------------------
    {
        name = "SiphonLife",
        matches = profiled_matches("SiphonLife", function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.siphon_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
            local ratio = state.has_bloodlust and BLOODLUST_LOWER_RATIO or SPELL_DMG_UPGRADE_RATIO
            if (state.siphon_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_siphon_dmg or 0, state.siphon_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            -- DoT TTD gating
            local ttd_threshold = spec_kit.setting_number(context, "dot_ttd_threshold", 50) / 100
            if DotTTD.should_skip_dot(context.ttd, DotTTD.DOT_DURATIONS.siphon_life, ttd_threshold) then return false end
            -- Siphon Life is talent-gated; spell won't be ready if not learned
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.SiphonLife, context.target) or false
        end),
        execute = function(context)
            local ok = NS.try_cast(ACTION.SiphonLife, context.target, "[AFFL] Siphon Life")
            if ok and aff_state.spell_damage then aff_state.snapshot_siphon_dmg = aff_state.spell_damage end
            return ok
        end,
    },
    -- Siphon Life Spread — multi-DoT (TSHelper + IZI enemies fallback)
    {
        name = "SiphonLifeSpread",
        matches = function(context, state)
            -- Fire spread to additional targets when primary already has the DoT (remains sufficient).
            -- Inverted from previous to match intended multi-dot behavior.
            if (state.siphon_remains or 0) <= DOT_REFRESH_WINDOW then return false end
            local target = find_dot_target(SIPHON_LIFE_DEBUFF[1])
            if not target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.SiphonLife, target) or false
        end,
        execute = function(context)
            local target = find_dot_target(SIPHON_LIFE_DEBUFF[1])
            if not target then return false end
            return NS.try_cast(ACTION.SiphonLife, target, "[AFFL] Siphon Life Spread")
        end,
    },

    -- ------------------------------------------------------------------------
    -- Immolate (wowsims priority #5: after Siphon Life, before curses)
    -- ------------------------------------------------------------------------
    {
        name = "ImmolateDoT",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.immolate_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Skip if target TTD is very short
            if context.ttd_known and context.ttd < 5 then return false end
            -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
            local ratio = state.has_bloodlust and BLOODLUST_LOWER_RATIO or SPELL_DMG_UPGRADE_RATIO
            if (state.immolate_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_immolate_dmg or 0, state.immolate_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            -- DoT TTD gating
            local ttd_threshold = spec_kit.setting_number(context, "dot_ttd_threshold", 50) / 100
            if DotTTD.should_skip_dot(context.ttd, DotTTD.DOT_DURATIONS.immolate, ttd_threshold) then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.Immolate, context.target) or false
        end,
        execute = function(context)
            local ok = NS.try_cast(ACTION.Immolate, context.target, "[AFFL] Immolate")
            if ok and aff_state.spell_damage then aff_state.snapshot_immolate_dmg = aff_state.spell_damage end
            return ok
        end,
    },
    -- Immolate Spread — multi-DoT (TSHelper + IZI enemies fallback)
    {
        name = "ImmolateSpread",
        matches = function(context, state)
            -- Fire spread to additional targets when primary already has the DoT (remains sufficient).
            -- Inverted from previous to match intended multi-dot behavior.
            if (state.immolate_remains or 0) <= DOT_REFRESH_WINDOW then return false end
            if context.ttd_known and context.ttd < 5 then return false end
            local target = find_dot_target(IMMOLATE_DEBUFF[1])
            if not target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.Immolate, target) or false
        end,
        execute = function(context)
            local target = find_dot_target(IMMOLATE_DEBUFF[1])
            if not target then return false end
            return NS.try_cast(ACTION.Immolate, target, "[AFFL] Immolate Spread")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 9a. Amplify Curse (before CoD/CoA/CoE — 3 min cooldown)
    -- ------------------------------------------------------------------------
    -- Fires when a curse is about to be applied and Amplify Curse is off cooldown
    {
        name = "AmplifyCurse",
        matches = function(context, state)
            if not context.target then return false end
            if not state.amplify_curse_ready then return false end
            -- Gate: setting check
            if not spec_kit.setting_bool(context, "aff_use_amplify_curse", true) then return false end
            -- Only use on targets that live long enough (60s+ to warrant 3min CD)
            if context.ttd_known and context.ttd < 60 then return false end
            -- Check if a curse is about to be applied (CoD, CoA, or Curse of Elements)
            local about_to_curse = false
            if (state.agony_remains or 0) <= CURSE_REFRESH_WINDOW and context.ttd_known and context.ttd >= 8 then about_to_curse = true end
            if (state.doom_remains or 0) <= CURSE_REFRESH_WINDOW and context.ttd_known and context.ttd >= 62 then about_to_curse = true end
            -- Also check CoD cooldown via spell_ready (60s CD, if ready with no debuff it's about to be cast)
            if context.target and (state.doom_remains or 0) <= 0 and NS.spell_ready and NS.spell_ready(ACTION.CurseOfDoom, context.target) then about_to_curse = true end
            return about_to_curse
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.AmplifyCurse, NS.PLAYER_UNIT, "[AFFL] Amplify Curse", { skip_range = true })
        end,
    },

    -- ------------------------------------------------------------------------
    -- 8. Curse of Doom (long-lived PvE targets)
    -- ------------------------------------------------------------------------
    {
        name = "CurseOfDoom",
        matches = function(context, state)
            if not context.target then return false end
            if not context.has_valid_enemy_target then return false end
            if assigned_curse_blocks(context, "doom") then return false end
            if select_curse(context, state) ~= "doom" then return false end
            if (state.doom_remains or 0) > CURSE_REFRESH_WINDOW then return false end
            if other_curse_active(state, "doom") then return false end
            if context.ttd_known and context.ttd < 62 then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.CurseOfDoom, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(ACTION.CurseOfDoom, context.target, "[AFFL] Curse of Doom")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 8a. Curse of Elements (raid debuff — gated by curse mode setting)
    -- ------------------------------------------------------------------------
    {
        name = "CurseOfElements",
        matches = function(context, state)
            if not context.target then return false end
            if assigned_curse_blocks(context, "elements") then return false end
            if select_curse(context, state) ~= "elements" then return false end
            if (state and state.coe_remains or 0) > CURSE_REFRESH_WINDOW then return false end
            if other_curse_active(state, "elements") then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.CurseElements, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CurseElements, context.target, "[AFFL] Curse of Elements")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 8b. Curse of Recklessness (utility curse — gated by curse mode setting)
    -- ------------------------------------------------------------------------
    {
        name = "CurseOfRecklessness",
        matches = function(context, state)
            if not context.target then return false end
            if assigned_curse_blocks(context, "recklessness") then return false end
            if select_curse(context, state) ~= "recklessness" then return false end
            if (state and state.recklessness_remains or 0) > CURSE_REFRESH_WINDOW then return false end
            if other_curse_active(state, "recklessness") then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.CurseOfRecklessness, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(ACTION.CurseOfRecklessness, context.target, "[AFFL] Curse of Recklessness")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 8c. Curse of Weakness (utility curse — gated by curse mode setting)
    -- ------------------------------------------------------------------------
    {
        name = "CurseOfWeakness",
        matches = function(context, state)
            if not context.target then return false end
            if assigned_curse_blocks(context, "weakness") then return false end
            if select_curse(context, state) ~= "weakness" then return false end
            if (state and state.weakness_remains or 0) > CURSE_REFRESH_WINDOW then return false end
            if other_curse_active(state, "weakness") then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.CurseOfWeakness, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(ACTION.CurseOfWeakness, context.target, "[AFFL] Curse of Weakness")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 9. Curse of Agony (long DoT curse)
    -- ------------------------------------------------------------------------
    {
        name = "CurseOfAgony",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if assigned_curse_blocks(context, "agony") then return false end
            local curse = select_curse(context, state)
            if curse ~= "agony" then return false end
            if (state.agony_remains or 0) > CURSE_REFRESH_WINDOW then return false end
            if other_curse_active(state, "agony") then return false end
            if context.ttd_known and context.ttd < 8 then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.CurseOfAgony, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(ACTION.CurseOfAgony, context.target, "[AFFL] Curse of Agony")
        end,
    },
    -- Curse of Agony Spread — multi-DoT (TSHelper + IZI enemies fallback)
    {
        name = "CurseOfAgonySpread",
        matches = function(context, state)
            if assigned_curse_blocks(context, "agony") then return false end
            local curse = select_curse(context, state)
            if curse ~= "agony" then return false end
            -- Fire spread to additional targets when primary already has the DoT (remains sufficient).
            -- Inverted from previous to match intended multi-dot behavior for the chosen curse.
            if (state.agony_remains or 0) <= CURSE_REFRESH_WINDOW then return false end
            if context.ttd_known and context.ttd < 8 then return false end
            local target = find_dot_target(CURSE_OF_AGONY_DEBUFF[1])
            if not target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.CurseOfAgony, target) or false
        end,
        execute = function(context)
            local target = find_dot_target(CURSE_OF_AGONY_DEBUFF[1])
            if not target then return false end
            return NS.try_cast(ACTION.CurseOfAgony, target, "[AFFL] Curse of Agony Spread")
        end,
    },

    -- ------------------------------------------------------------------------
    -- Drain Life (sustain — fires after all DoTs are applied)
    -- ------------------------------------------------------------------------
    {
        name = "DrainLife",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.hp_pct or 100) > 55 then return false end
            if context.is_channeling then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.DrainLife, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.DrainLife, context.target, "[AFFL] Drain Life sustain")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 10. Seed of Corruption (AoE 3+ targets)
    -- ------------------------------------------------------------------------
    {
        name = "SeedOfCorruption",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            local min_targets = spec_kit.setting_number(context, "aff_seed_targets", 3)
            if not NS.aoe_target_meets or not NS.aoe_target_meets(min_targets, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_15) or 15, context.target, context, state) then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.SeedOfCorruption, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(ACTION.SeedOfCorruption, context.target, "[AFFL] Seed of Corruption")
        end,
    },

    -- Rain of Fire (AoE for big packs, especially pre-70 where Seed of Corruption not available)
    {
        name = "RainOfFire",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            local min_targets = spec_kit.setting_number(context, "aff_seed_targets", 3)
            if not NS.aoe_target_meets or not NS.aoe_target_meets(min_targets, (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8, context.target, context, state) then return false end
            if context.is_moving then return false end
            if context.is_channeling then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.RainOfFire, context.target) or false
        end,
        execute = function(context)
            local t = context.target
            local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8
            if NS.cast_ground_aoe then
                return NS.cast_ground_aoe(LOCAL_SPELLS.RainOfFire, t, r, 35, "[AFFL] Rain of Fire")
            end
            local pos = t and NS.get_aoe_cast_position and NS.get_aoe_cast_position(LOCAL_SPELLS.RainOfFire, t, r, 35)
            if pos and NS.try_cast_position then
                return NS.try_cast_position(LOCAL_SPELLS.RainOfFire, pos, t, "[AFFL] Rain of Fire")
            end
            return NS.try_cast(LOCAL_SPELLS.RainOfFire, t, "[AFFL] Rain of Fire")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 11. Drain Soul (execute + shard capture)
    -- Wowsims APL: Drain Soul at remainingTimePercent <= 5% (execute filler).
    -- Also channels when mob is about to die for shard capture.
    -- ------------------------------------------------------------------------
    {
        name = "DrainSoulExecute",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if context.is_channeling then return false end
            -- Low health: force Drain Life (which heals) instead of Drain Soul (no self-heal, shard/execute only)
            local player_hp = state and (state.hp_pct or state.hp or 100) or (context.hp or 100)
            if player_hp < 40 then return false end
            -- Use only documented context fields from the API (ttd for shard capture on death).
            -- TBC: Drain Soul is for capturing a soul shard as the mob dies during channel (ttd <= window).
            -- It is low value as filler (use Shadow Bolt instead). No Wrath-style execute.
            local shard_capture = context.ttd_known and context.ttd and context.ttd > 0 and context.ttd <= SOUL_SHARD_CAPTURE_TTD
            if not shard_capture then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.DrainSoul, context.target) or false
        end,
        execute = function(context, state)
            return NS.try_cast(LOCAL_SPELLS.DrainSoul, context.target,
                string.format("[AFFL] Drain Soul (shard capture, ttd %.0fs)", (context and context.ttd) or 0))
        end,
    },

    -- ------------------------------------------------------------------------
    -- 11a. Shadowburn (execute)
    -- Wowsims APL: Shadowburn at remainingTimePercent <= 5%.
    -- Higher priority than Shadow Bolt when target is about to die.
    -- ------------------------------------------------------------------------
    {
        name = "ShadowburnExecute",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            local target_hp = context.target_hp or 100
            local execute_threshold = spec_kit.setting_number(context, "destro_shadowburn_hp", 20)
            if target_hp > execute_threshold then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.Shadowburn, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.Shadowburn, context.target, "[AFFL] Shadowburn (execute)")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 12. Shadow Bolt (filler)
    -- v2.5.1: ShadowBoltFiller now gates on mana — when mana is too low to cast
    -- Shadow Bolt and Life Tap is unsafe, falls through to Wand instead.
    -- ------------------------------------------------------------------------
    {
        name = "PreCombatPull",
        matches = function(context)
            if context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            -- Range check: Shadow Bolt has 30yd range
            if context.target_range and context.target_range > 28 then return false end
            -- Pre-cast Shadow Bolt on pull timer targets
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.ShadowBolt, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(ACTION.ShadowBolt, context.target, "[AFFL] Pre-combat Shadow Bolt")
        end,
    },

    {
        name = "ShadowEmbraceMaintenance",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.se_stacks or 0) >= 5 then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.ShadowBolt, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(ACTION.ShadowBolt, context.target, "[AFFL] Shadow Embrace maintenance")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 12. Life Tap (HP → Mana) — before fillers so it can sustain zero-mana states.
    -- ------------------------------------------------------------------------
    {
        name = "LifeTap",
        max_mana = 65,
        matches = function(context, state)
            if context.is_casting or context.is_channeling then return false end
            local threshold = math.min(spec_kit.setting_number(context, "aff_life_tap_mana", 30), 65)
            if (state.mana_pct or 100) > threshold then return false end
            if (state.hp_pct or 100) < LIFE_TAP_SAFETY_HP then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.LifeTap, NS.PLAYER_UNIT, { skip_range = true }) or false
        end,
        execute = function()
            return NS.try_cast(ACTION.LifeTap, NS.PLAYER_UNIT, "[AFFL] Life Tap")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 13. Shadow Bolt filler
    -- ------------------------------------------------------------------------
    {
        name = "ShadowBoltFiller",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            -- v2.5.1: don't try to cast Shadow Bolt when mana is critically low —
            -- let Wand catch it instead. Shadow Bolt costs ~380 mana at max rank;
            -- if we have less than 5% mana and can't Life Tap (HP unsafe), skip.
            local mana = state and state.mana_pct or (context.mana_pct or 100)
            local hp = state and state.hp_pct or (context.hp or 100)
            if mana < 5 and hp < LIFE_TAP_SAFETY_HP then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.ShadowBolt, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(ACTION.ShadowBolt, context.target, "[AFFL] Shadow Bolt filler")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 14. Dark Pact (pet mana drain)
    -- ------------------------------------------------------------------------
    {
        name = "DarkPact",
        matches = function(context, state)
            local threshold = spec_kit.setting_number(context, "aff_dark_pact_mana", 20)
            if (state.mana_pct or 100) > threshold then return false end
            if not state.pet_alive then return false end
            if (state.pet_mana or 0) < 20 then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.DarkPact, NS.PLAYER_UNIT, { skip_range = true }) or false
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.DarkPact, NS.PLAYER_UNIT, "[AFFL] Dark Pact")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 16. Mana potion
    -- ------------------------------------------------------------------------
    {
        name = "ManaPotion",
        matches = function(context, state)
            local threshold = spec_kit.setting_number(context, "aff_mana_potion", 15)
            if (state.mana_pct or 100) > threshold then return false end
            return state.mana_potion_id ~= nil
        end,
        execute = function(_, state)
            if NS.use_item_by_id then NS.use_item_by_id(state.mana_potion_id) end
            return true
        end,
    },

    -- ------------------------------------------------------------------------
    -- Racial abilities (off-GCD, usable in combat)
    -- ------------------------------------------------------------------------
    {
        name = "RacialBerserking",
        matches = function(context, state) return racial_matches(context, state) and NS.spell_ready(LOCAL_SPELLS.Berserking, NS.PLAYER_UNIT, { skip_range = true }) end,
        execute = function() return NS.try_cast(LOCAL_SPELLS.Berserking, NS.PLAYER_UNIT, "[AFFL] Berserking", { skip_range = true }) end,
    },
    {
        name = "RacialBloodFury",
        matches = function(context, state) return racial_matches(context, state) and NS.spell_ready(LOCAL_SPELLS.BloodFury, NS.PLAYER_UNIT, { skip_range = true }) end,
        execute = function() return NS.try_cast(LOCAL_SPELLS.BloodFury, NS.PLAYER_UNIT, "[AFFL] Blood Fury", { skip_range = true }) end,
    },
    {
        name = "RacialArcaneTorrent",
        matches = function(context, state) return racial_matches(context, state) and NS.spell_ready(LOCAL_SPELLS.ArcaneTorrent, context.target) end,
        execute = function(context) return NS.try_cast(LOCAL_SPELLS.ArcaneTorrent, context.target, "[AFFL] Arcane Torrent") end,
    },

    -- ------------------------------------------------------------------------
    -- PvP Section
    -- ------------------------------------------------------------------------
    {
        name = "CC_Fear",
        matches = function(context)
            local group_aware = spec_kit.setting_bool(context, "warlock_group_aware_utility", true)
            if not (context.is_pvp or (group_aware and context.is_group)) then return false end
            if not context.target then return false end
            -- IZI SDK: skip Fear if target is already CC'd
            local target = context.target
            if target and type(target.is_cc) == "function" then
                local ok, cc = pcall(target.is_cc, target)
                if ok and cc then return false end
            end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.Fear, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.Fear, context.target, "[AFFL] Fear")
        end,
    },
    {
        name = "CC_HowlOfTerror",
        matches = function(context)
            local group_aware = spec_kit.setting_bool(context, "warlock_group_aware_utility", true)
            if not (context.is_pvp or (group_aware and context.is_group)) then return false end
            if not context.melee_on_you then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.HowlOfTerror, NS.PLAYER_UNIT, { skip_range = true }) or false
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.HowlOfTerror, NS.PLAYER_UNIT, "[AFFL] Howl of Terror")
        end,
    },
    {
        name = "PvP_CurseExhaustion",
        matches = function(context, state)
            if not context.is_pvp then return false end
            if not context.target then return false end
            if not context.melee_on_you then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.CurseExhaustion, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CurseExhaustion, context.target, "[AFFL PvP] Curse of Exhaustion kite")
        end,
    },
    {
        name = "PvP_CurseTongues",
        matches = function(context)
            local group_aware = spec_kit.setting_bool(context, "warlock_group_aware_utility", true)
            if not (context.is_pvp or (group_aware and context.is_group)) then return false end
            if not context.target then return false end
            if not context.enemy_caster then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.CurseTongues, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CurseTongues, context.target, "[AFFL PvP] Curse of Tongues")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 21. Fel Armor (out of combat + in-combat refresh if dropped)
    -- ------------------------------------------------------------------------
    {
        name = "FelArmorBuff",
        matches = function(context)
            local me = context.me or (NS.GetPlayer and NS.GetPlayer())
            if me and NS.buff_remains(me, FEL_ARMOR_BUFF) > 0 then return false end
            -- In combat: only refresh if not channeling (don't interrupt Drain Soul)
            if context.in_combat and context.is_channeling then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.FelArmor, me or NS.PLAYER_UNIT, { skip_range = true }) or false
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.FelArmor, NS.PLAYER_UNIT, "[AFFL] Fel Armor")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 22. Health Funnel (heal pet)
    -- ------------------------------------------------------------------------
    {
        name = "HealthFunnelPet",
        matches = function(context, state)
            if not state.pet_alive then return false end
            if (state.pet_health or 100) > 40 then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.HealthFunnel, context.pet) or false
        end,
        execute = function(context)
            if context.pet then
                return NS.try_cast(LOCAL_SPELLS.HealthFunnel, context.pet, "[AFFL] Health Funnel pet")
            end
            return false
        end,
    },

    -- ------------------------------------------------------------------------
    -- 24. Shadow Ward (shadow absorb)
    -- ------------------------------------------------------------------------
    shadow_ward_helper.make_strategy("ShadowWard", LOCAL_SPELLS.ShadowWard, { label = "[AFFL PvP] Shadow Ward", use_group_aware = true }),

    -- ------------------------------------------------------------------------
    -- 25. Soulstone (pre-combat self-buff)
    -- ------------------------------------------------------------------------
    {
        name = "SelfSoulstone",
        matches = function(context, state)
            if context.in_combat then return false end
            if state.has_soulstone then return false end
            -- Require at least one soul shard to create
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.CreateSoulstone, NS.PLAYER_UNIT, { skip_range = true }) or false
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.CreateSoulstone, NS.PLAYER_UNIT, "[AFFL] Create Soulstone (self-buff)")
        end,
    },

    {
        name = "SummonFelhunter",
        matches = function(context, state)
            if context.in_combat then return false end
            if context.has_valid_enemy_target then return false end
            if state and state.has_pet then return false end
            -- Do NOT re-summon if Demonic Sacrifice aura is already active
            if state and state.has_demonic_sacrifice then return false end
            return NS.is_spell_learned and NS.is_spell_learned(691)
        end,
        execute = function(context)
            return NS.try_cast(ACTION.SummonFelhunter, NS.PLAYER_UNIT, "[AFFL] Summon Felhunter", { skip_range = true })
        end,
    },

    -- ------------------------------------------------------------------------
    -- 26. Wand (Shoot) — mana conservation fallback
    -- v2.5.1: raised default threshold from 15% → 30% so wand kicks in sooner
    -- when Life Tap is unsafe (HP too low) and Shadow Bolt is uncastable.
    -- ------------------------------------------------------------------------
    {
        name = "Wand",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.wand_learned then return false end
            -- v2.5.1: wand at 30% mana (was 15%) — catches "can't Life Tap" scenarios
            local wand_threshold = spec_kit.setting_number(context, "aff_wand_mana", 30)
            if (state.mana_pct or 100) >= wand_threshold then return false end
            -- Only wand when Life Tap is unsafe (HP too low) OR Shadow Bolt would OOM us
            local hp_ok_for_tap = (state.hp_pct or 100) >= LIFE_TAP_SAFETY_HP
            if hp_ok_for_tap then return false end  -- prefer Life Tap → Shadow Bolt over wand
            if not context.has_valid_enemy_target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.Shoot, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.Shoot, context.target, "[AFFL] Wand (mana conservation)")
        end,
    },
}

-- Substitute any DSL-defined strategies into the priority list by name.
-- This preserves the existing order while replacing imperative match functions
-- with their declarative equivalents.
local dsl_map = {}
for _, def in ipairs(DSL_DEFS) do
    dsl_map[def.name] = def
end
for i = 1, #strategies do
    local strat = strategies[i]
    local dsl_def = dsl_map[strat.name]
    if dsl_def then
        strategies[i] = dsl.compile_strategy(dsl_def, { get_state = build_state })
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("affliction", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warlock affliction rotation registered") end
return { strategies = strategies, build_state = build_state }


