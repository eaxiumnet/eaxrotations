-- affliction_sylvanas.lua -- Warlock Affliction DPS for TBC Anniversary (2.5.5).
-- WHAT:  multi-DoT priority list with snapshot-aware refresh, Nightfall proc
--         consumption, execute-phase Drain Soul, curse mode selection, and
--         tracker-preferred spread (ActiveFightTracker for candidates) + izi fallback.
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors wowsims APL + TBC affliction consensus: UA > Corruption >
--         Siphon Life > Immolate > curse (CoA/CoD/CoE/CoS) > Shadow Bolt filler.
-- SAFETY: Pattern 14 nil-guarded via spec_kit.safe_state(); tracker pcall; strict
--         engagement from filter (no hp<100); no on_update() allocs.
-- DECISION: PR4 wires to tracker (find_undotted_target / get_active_fights) for
--         spread candidates; setting gate "aff_use_fight_tracker" (default on);
--         unifies is_engaged logic to strict; keeps izi path for compatibility.

-- TBC Warlock Affliction priority list with multi-DoT cycling, Nightfall procs, and execute drain.

local NS = _G.EaxRotations
if not NS then return nil end
local pet_manager = require("shared/pet_manager_sylvanas")

local potion_helper = require("shared/potion_helper_sylvanas")
local DotTTD = require("shared/dot_ttd_gating_sylvanas")
local _planner_ok, planner = pcall(require, "shared/cooldown_planner_sylvanas")
if not _planner_ok or type(planner) ~= "table" then planner = nil end
local SPELLS = NS.WarlockSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")

-- Centralized spell resolver via spec_kit (rank IDs from warlock/class_sylvanas.lua).
-- LOCAL_SPELLS (below) handles spells not in the class spell table.
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    Corruption          = define("Corruption",          { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    CurseOfAgony        = define("CurseOfAgony",        { 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfAgony"),
    CurseOfDoom         = define("CurseOfDoom",         { 30910, 603 }, "CurseOfDoom"),
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

-- ActiveFightTracker (from PR1 base) for strict-engagement candidate pool.
-- Prefer for find_undotted / get_active_fights over legacy custom is_engaged + izi spread.
local _aft_ok, ActiveFightTracker = pcall(require, "shared/active_fight_tracker_sylvanas")
if not _aft_ok or type(ActiveFightTracker) ~= "table" then ActiveFightTracker = nil end

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
-- LEGACY for izi fallback path only. Unified to strict via ActiveFightTracker
-- (is_in_combat + targeting us/party/pet; no hp<100 heuristic) in spread paths.
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

-- Simple setting gate for tracker-based DoT maintenance (defaults true; via spec_kit).
local function use_tracker_for_dots(context)
    local v = spec_kit.setting(context, "aff_use_fight_tracker", true)
    return v ~= false and v ~= 0
end

--- Find a target missing the specified DoT. Prefers ActiveFightTracker (strict
-- engagement from multidot filter / get_active_fights) for candidates; falls
-- back to izi.spread_dot when tracker unavailable (keep izi where advantageous).
-- Unifies spread to tracker pool (PR4). Cache only for izi path.
---@param spell_id number DoT spell ID to check
---@param radius number|nil Search radius (default 40)
---@param context table|nil for tracker (provides .me .target); used for gate too
---@return game_object|nil target Missing the DoT, or nil
local _dot_target_cache = {}     -- [spell_id] = target|false
local _dot_target_cache_tick = -1
local function find_dot_target(spell_id, radius, context)
    radius = radius or 40
    local debuff_ids = { spell_id }
    local me = NS.GetPlayer and NS.GetPlayer() or nil
    -- Prefer tracker for pool of engaged candidates (unify to strict engagement)
    if ActiveFightTracker and ActiveFightTracker.find_undotted_target and use_tracker_for_dots(context) then
        local ctx = context or { me = me, target = nil }
        local t = ActiveFightTracker.find_undotted_target(ctx, debuff_ids, radius)
        if t then
            if not is_cc_target(t) then
                local ok_hp, hp = pcall(function() return t:get_health_percentage() end)
                if not (ok_hp and hp and hp < 20) then return t end
            end
        end
        -- no tracker candidate; continue to izi only if wanted, else nil
        if not _izi then return nil end
    end
    if not _izi then return nil end
    -- Per-tick cache: avoid re-scanning the same enemy list for the same debuff
    local now = NS.time_now and NS.time_now() or 0
    if now ~= _dot_target_cache_tick then
        _dot_target_cache = {}
        _dot_target_cache_tick = now
    end
    if _dot_target_cache[spell_id] ~= nil then
        return _dot_target_cache[spell_id] or nil  -- false→nil
    end
    local ok, target = pcall(_izi.spread_dot, spell_id, radius, 1, false, function(unit)
        if not unit then return false end
        -- Skip CC'd targets (don't break Polymorph/Sap/Banish/etc.)
        if is_cc_target(unit) then return false end
        -- Skip unengaged patrols (don't pull new mobs)
        if me and not is_engaged(unit, me) then return false end
        -- Skip dying adds (don't waste GCD on < 20% HP targets)
        local ok_hp, hp = pcall(function() return unit:get_health_percentage() end)
        if ok_hp and hp and hp < 20 then return false end
        return true
    end)
    local result = (ok and target) or nil
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
local ISB_DEBUFF = { 17800 } -- Shadow Vulnerability (ISB proc debuff)
local SEED_OF_CORRUPTION_DEBUFF = { 27285 }  -- the DoT that triggers the explosion
local CURSE_OF_ELEMENTS_DEBUFF = { 27228, 11722, 11721, 1490 }
local CURSE_OF_SHADOW_DEBUFF   = { 27229, 17937, 17862 }
local NIGHTFALL_BUFF         = { 17941 }  -- Shadow Trance
local SOULSHATTER_BUFF       = { 29858 }
local FEL_ARMOR_BUFF         = { 28189, 28176 }
-- Imp Firebolt spell IDs (all ranks). Only the Imp has Firebolt, so these also
-- identify the active pet as an Imp.
local IMP_FIREBOLT_IDS       = { 3110, 7799, 7800, 7801, 7802, 11762, 11763, 27267 }

local DOT_REFRESH_WINDOW = 1.5   -- refresh within last 1.5s per Research Angle 1 (clip <1.5s)
local SOUL_SHARD_CAPTURE_TTD = 5  -- TBC: Drain Soul is shard-capture only (mob about to die); sub-25% execute is Wrath, not TBC
local LIFE_TAP_SAFETY_HP = 35   -- don't Life Tap below this HP%

-- Snapshot-aware refresh constants
local SPELL_DMG_UPGRADE_RATIO = 1.08    -- Refresh only if 8%+ spell damage upgrade
local REFRESH_EXTRA_WINDOW = 1.5         -- Extra seconds past pandemic window for upgrade refresh    -- Local anti-spam: Soulshatter has 5min CD, use local timer as fallback for broken API
    local _last_soulshatter = 0

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
    CurseShadow     = NS.spell_action({ 27229, 17937, 17862 }, "CurseOfShadow"),
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
    coe_remains = 0, cos_remains = 0,
    -- DoT stacks
    se_stacks = 0, isb_stacks = 0,
    -- Proc / resource
    nightfall_active = false, mana_pct = 100, hp_pct = 100,
    target_hp = 100, enemy_count = 0,
    -- Pet
    pet_alive = false, pet_health = 100, pet_mana = 100,
    pet_type_imp = false, pet_casting_firebolt = false, has_pet = false,
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
    immolate_remains = 0,	    -- Shadow Embrace stacks
	    se_stacks = 0,
	    -- Improved Shadow Bolt (Shadow Vulnerability) stacks
	    isb_stacks = 0,
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
    pet_casting_firebolt = false,
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
        aff_state.ua_remains = NS.debuff_remains and NS.debuff_remains(target, UNSTABLE_AFFL_DEBUFF) or 0
        aff_state.corruption_remains = NS.debuff_remains and NS.debuff_remains(target, CORRUPTION_DEBUFF) or 0
        aff_state.agony_remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_AGONY_DEBUFF) or 0
        aff_state.doom_remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_DOOM_DEBUFF) or 0
        aff_state.siphon_remains = NS.debuff_remains and NS.debuff_remains(target, SIPHON_LIFE_DEBUFF) or 0
        aff_state.immolate_remains = NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF) or 0
        aff_state.coe_remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_ELEMENTS_DEBUFF) or 0
        aff_state.cos_remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_SHADOW_DEBUFF) or 0
        aff_state.se_stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, SHADOW_EMBRACE_DEBUFF) or 0
        aff_state.isb_stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, ISB_DEBUFF) or 0
        aff_state.target_hp = (target.get_health_percentage and target:get_health_percentage()) or 100
    else
        aff_state.ua_remains = 0
        aff_state.corruption_remains = 0
        aff_state.agony_remains = 0
        aff_state.siphon_remains = 0
        aff_state.immolate_remains = 0
        aff_state.coe_remains = 0
        aff_state.cos_remains = 0
        aff_state.se_stacks = 0
        aff_state.isb_stacks = 0
	        aff_state.target_hp = 100
	    end
	    -- Nightfall proc
	    aff_state.nightfall_active = NS.has_player_buff and NS.has_player_buff(NIGHTFALL_BUFF) or false
	    -- Resources
	    aff_state.mana_pct = context.mana_pct or 100
	    aff_state.hp_pct = context.hp or 100
	    aff_state.enemy_count = context.enemy_count or 1            -- Pet status (via pet object if available)
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
            aff_state.pet_casting_firebolt = false
            aff_state.pet_type_imp = false
            if pet and aff_state.pet_alive then
                if pet.is_casting_spell and pet:is_casting_spell() and pet.get_active_spell_id then
                    local sid = pet:get_active_spell_id()
                    if type(sid) == "number" then
                        for _, id in ipairs(IMP_FIREBOLT_IDS) do
                            if sid == id then
                                aff_state.pet_casting_firebolt = true
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

-- Select which curse to use based on context and user settings
local function select_curse(context, state)
    -- Respect explicit curse mode setting (from schema dropdown)
    local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
    if curse_mode == "agony" then
        if context.is_pvp and context.enemy_healer then return "tongues" end
        if context.is_pvp and context.melee_on_you then return "exhaustion" end
        return "agony"
    elseif curse_mode == "shadow" then
        return "shadow"
    elseif curse_mode == "elements" then
        return "elements"
    elseif curse_mode == "doom" then
        return "doom"
    elseif curse_mode == "recklessness" then
        return "recklessness"
    elseif curse_mode == "weakness" then
        return "weakness"
    elseif curse_mode == "none" then
        return nil
    end
    -- Auto mode: context-aware curse selection
    if context.is_pvp then
        if (context.enemy_healer or false) then return "tongues" end
        if (context.melee_on_you or false) then return "exhaustion" end
    end
    if (state.enemy_count or 0) >= 3 then return "elements" end  -- AoE benefit
    -- In raids: prefer Shadow for Affliction (Shadow damage), Elements for Destruction
    if context.is_group and context.active_playstyle == "affliction" then return "shadow" end
    return "agony"  -- default: damage
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

-- Throttle DoT re-matches when aura APIs are broken on private servers.
local function broken_api_dot_throttled(spell_id)
    return NS.is_api_health_broken and NS.is_api_health_broken() and NS.recent_spell_cast and NS.recent_spell_cast(spell_id, 2.0)
end
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
    {
        name = "DeathCoilSurvival",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.hp_pct or 100) > 30 then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.DeathCoil, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.DeathCoil, context.target, "[AFFL] Death Coil (survival + heal)")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 2. Healthstone
    -- ------------------------------------------------------------------------
    {
        name = "Healthstone",
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

    -- ------------------------------------------------------------------------
    -- 3. Soulshatter (threat reduction)
    -- ------------------------------------------------------------------------
    {
        name = "Soulshatter",
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.threat_pct and context.threat_pct < 80 then return false end
            local me = context.me or (NS.GetPlayer and NS.GetPlayer())
            if not me then return false end
            -- Local timer: Soul shatter has 5min CD
            if (NS.time_now() - _last_soulshatter) < 290 then return false end
            if NS.cooldown_remains(ACTION.Soulshatter, 300) > 0 then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.Soulshatter, me, { skip_range = true }) or false
        end,
        execute = function(context)
            local me = context.me or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
            local ok = NS.try_cast(ACTION.Soulshatter, me, "[AFFL] Soulshatter", { skip_range = true })
            if ok then _last_soulshatter = NS.time_now() end
            return ok
        end,
    },

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
        name = "CorruptionDoT",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if broken_api_dot_throttled(27216) then return false end
            if (state.corruption_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
            local ratio = state.has_bloodlust and BLOODLUST_LOWER_RATIO or SPELL_DMG_UPGRADE_RATIO
            if (state.corruption_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_corruption_dmg or 0, state.corruption_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            -- DoT TTD gating
            local ttd_threshold = spec_kit.setting_number(context, "dot_ttd_threshold", 50) / 100
            if DotTTD.should_skip_dot(context.ttd, DotTTD.DOT_DURATIONS.corruption, ttd_threshold) then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.Corruption, context.target) or false
        end,
        execute = function(context)
            local ok = NS.try_cast(ACTION.Corruption, context.target, "[AFFL] Corruption")
            if ok and aff_state.spell_damage then aff_state.snapshot_corruption_dmg = aff_state.spell_damage end
            return ok
        end,
    },
    -- Corruption Spread — via tracker (preferred) or izi; strict engagement unified.
    {
        name = "CorruptionSpread",
        matches = function(context, state)
            if (state.corruption_remains or 0) > DOT_REFRESH_WINDOW then return false end
            local target = find_dot_target(CORRUPTION_DEBUFF[1], 40, context)
            if not target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.Corruption, target) or false
        end,
        execute = function(context)
            local target = find_dot_target(CORRUPTION_DEBUFF[1], 40, context)
            if not target then return false end
            return NS.try_cast(ACTION.Corruption, target, "[AFFL] Corruption Spread")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 5a. MovingCorruption (instant DoT while moving)
    -- ------------------------------------------------------------------------
    {
        name = "MovingCorruption",
        matches = function(context, state)
            if not context.is_moving then return false end
            if not context.has_valid_enemy_target then return false end
            if broken_api_dot_throttled(27216) then return false end
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
    -- 6. Unstable Affliction (primary DoT — dispel protection, 1.5s cast)
    -- ------------------------------------------------------------------------
    {
        name = "UnstableAffliction",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if broken_api_dot_throttled(30405) then return false end
            if (state.ua_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
            local ratio = state.has_bloodlust and BLOODLUST_LOWER_RATIO or SPELL_DMG_UPGRADE_RATIO
            if (state.ua_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_ua_dmg or 0, state.ua_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            -- DoT TTD gating
            local ttd_threshold = spec_kit.setting_number(context, "dot_ttd_threshold", 50) / 100
            if DotTTD.should_skip_dot(context.ttd, DotTTD.DOT_DURATIONS.unstable_affliction, ttd_threshold) then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.UnstableAffliction, context.target) or false
        end,
        execute = function(context)
            local ok = NS.try_cast(ACTION.UnstableAffliction, context.target, "[AFFL] Unstable Affliction")
            if ok and aff_state.spell_damage then aff_state.snapshot_ua_dmg = aff_state.spell_damage end
            return ok
        end,
    },
    -- Unstable Affliction Spread — via tracker (preferred) or izi; strict engagement unified.
    {
        name = "UnstableAfflictionSpread",
        matches = function(context, state)
            -- Fire when primary target already has UA; spread to additional targets
            if (state.ua_remains or 0) > DOT_REFRESH_WINDOW then return false end
            local target = find_dot_target(UNSTABLE_AFFL_DEBUFF[1], 40, context)
            if not target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.UnstableAffliction, target) or false
        end,
        execute = function(context)
            local target = find_dot_target(UNSTABLE_AFFL_DEBUFF[1], 40, context)
            if not target then return false end
            return NS.try_cast(ACTION.UnstableAffliction, target, "[AFFL] Unstable Affliction Spread")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 7. Siphon Life (DoT + self-heal, if talented)
    -- Requires ISB debuff on target to maximize Shadow damage benefit
    -- ------------------------------------------------------------------------
    {
        name = "SiphonLife",
        matches = function(context, state)
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
        end,
        execute = function(context)
            local ok = NS.try_cast(ACTION.SiphonLife, context.target, "[AFFL] Siphon Life")
            if ok and aff_state.spell_damage then aff_state.snapshot_siphon_dmg = aff_state.spell_damage end
            return ok
        end,
    },
    -- Siphon Life Spread — via tracker (preferred) or izi; strict engagement unified.
    {
        name = "SiphonLifeSpread",
        matches = function(context, state)
            if (state.siphon_remains or 0) > DOT_REFRESH_WINDOW then return false end
            local target = find_dot_target(SIPHON_LIFE_DEBUFF[1], 40, context)
            if not target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.SiphonLife, target) or false
        end,
        execute = function(context)
            local target = find_dot_target(SIPHON_LIFE_DEBUFF[1], 40, context)
            if not target then return false end
            return NS.try_cast(ACTION.SiphonLife, target, "[AFFL] Siphon Life Spread")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 5. Immolate (wowsims priority #5: after Siphon Life, before curses)
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
    -- Immolate Spread — via tracker (preferred) or izi; strict engagement unified.
    {
        name = "ImmolateSpread",
        matches = function(context, state)
            -- Fire when primary target already has Immolate; spread to additional targets
            if (state.immolate_remains or 0) > DOT_REFRESH_WINDOW then return false end
            if context.ttd_known and context.ttd < 5 then return false end
            local target = find_dot_target(IMMOLATE_DEBUFF[1], 40, context)
            if not target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.Immolate, target) or false
        end,
        execute = function(context)
            local target = find_dot_target(IMMOLATE_DEBUFF[1], 40, context)
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
            if (state.agony_remains or 0) <= DOT_REFRESH_WINDOW and context.ttd_known and context.ttd >= 8 then about_to_curse = true end
            if (state.doom_remains or 0) <= DOT_REFRESH_WINDOW and context.ttd_known and context.ttd >= 62 then about_to_curse = true end
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
            -- Respect curse mode — only fire when user chose "doom" or "auto"
            local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
            if curse_mode ~= "auto" and curse_mode ~= "doom" then return false end
            -- Don't refresh if already applied and still ticking
            if (state.doom_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Only on long-lived targets (Doom takes 60s to tick)
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
            if not context.is_group then return false end
            -- v2.5.1 FIX: respect curse mode dropdown — previously fired unconditionally
            -- in groups, overriding Agony/DPS curse preference. Only applies in "elements"
            -- or "auto" mode.
            local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
            if curse_mode ~= "auto" and curse_mode ~= "elements" then return false end
            if (state and state.coe_remains or 0) > DOT_REFRESH_WINDOW then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.CurseElements, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CurseElements, context.target, "[AFFL] Curse of Elements")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 8b. Curse of Shadow (Shadow damage debuff — gated by curse mode setting)
    -- ------------------------------------------------------------------------
    {
        name = "CurseOfShadow",
        matches = function(context, state)
            if not context.target then return false end
            if not context.is_group then return false end
            -- v2.5.1 FIX: respect curse mode dropdown. Only applies in "shadow"
            -- or "auto" mode (auto prefers Shadow for Affliction in groups).
            local curse_mode = spec_kit.setting(context, "warlock_curse_mode", "auto")
            if curse_mode ~= "auto" and curse_mode ~= "shadow" then return false end
            if (state and state.cos_remains or 0) > DOT_REFRESH_WINDOW then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.CurseShadow, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CurseShadow, context.target, "[AFFL] Curse of Shadow")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 9. Curse of Agony (long DoT curse)
    -- ------------------------------------------------------------------------
    {
        name = "CurseOfAgony",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            -- Skip in groups when a raid curse (Elements/Shadow) is active (TBC: one curse per target)
            if context.is_group and ((state and state.coe_remains or 0) > 0 or (state and state.cos_remains or 0) > 0) then return false end
            local curse = select_curse(context, state)
            if curse ~= "agony" then return false end
            if (state.agony_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- On short-lived targets, CoA may not run full duration
            if context.ttd_known and context.ttd < 8 then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.CurseOfAgony, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(ACTION.CurseOfAgony, context.target, "[AFFL] Curse of Agony")
        end,
    },
    -- Curse of Agony Spread — via tracker (preferred) or izi; strict engagement unified.
    {
        name = "CurseOfAgonySpread",
        matches = function(context, state)
            if (state.agony_remains or 0) > DOT_REFRESH_WINDOW then return false end
            if context.ttd_known and context.ttd < 8 then return false end
            local target = find_dot_target(CURSE_OF_AGONY_DEBUFF[1], 40, context)
            if not target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.CurseOfAgony, target) or false
        end,
        execute = function(context)
            local target = find_dot_target(CURSE_OF_AGONY_DEBUFF[1], 40, context)
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
            if (state.enemy_count or 0) < min_targets then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(ACTION.SeedOfCorruption, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(ACTION.SeedOfCorruption, context.target, "[AFFL] Seed of Corruption")
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
            -- Execute: target HP <= 5% (wowsims remainingTimePercent <= 5%)
            local target_hp = context.target_hp_pct or 100
            local in_execute = target_hp <= 5
            -- Shard capture: mob about to die
            local shard_capture = context.ttd_known and context.ttd and context.ttd > 0 and context.ttd <= SOUL_SHARD_CAPTURE_TTD
            if not in_execute and not shard_capture then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.DrainSoul, context.target) or false
        end,
        execute = function(context, state)
            local target_hp = context.target_hp_pct or 100
            local reason = target_hp <= 5 and "execute" or "shard capture"
            return NS.try_cast(LOCAL_SPELLS.DrainSoul, context.target,
                string.format("[AFFL] Drain Soul (%s, ttd %.0fs)", reason, (context and context.ttd) or 0))
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
            local target_hp = context.target_hp_pct or 100
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
    -- 13. Life Tap (HP → Mana)
    -- ------------------------------------------------------------------------
    {
        name = "LifeTap",
        max_mana = 65,
        matches = function(context, state)
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
            if not (context.is_pvp or context.is_group) then return false end
            if not context.target then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.Fear, context.target) or false
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.Fear, context.target, "[AFFL] Fear")
        end,
    },
    {
        name = "CC_HowlOfTerror",
        matches = function(context)
            if not (context.is_pvp or context.is_group) then return false end
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
            if not (context.is_pvp or context.is_group) then return false end
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
    {
        name = "ShadowWard",
        matches = function(context)
            if not (context.is_pvp or context.is_group) then return false end
            if not context.enemy_shadow_caster then return false end
            return NS.spell_ready ~= nil and NS.spell_ready(LOCAL_SPELLS.ShadowWard, NS.PLAYER_UNIT, { skip_range = true }) or false
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.ShadowWard, NS.PLAYER_UNIT, "[AFFL PvP] Shadow Ward")
        end,
    },

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

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("affliction", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warlock affliction rotation registered") end
return { strategies = strategies, build_state = build_state }


