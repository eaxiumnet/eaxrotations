-- frost_sylvanas.lua -- Mage Frost rotation for TBC Anniversary (2.5.5).
-- WHAT:  frost DPS spec (Frostbolt spam, Water Elemental, Ice Lance shatter,
--         Winter's Chill stacking, Icy Veins CD, AoE Blizzard/CoC).
-- WHEN:  combat, with valid enemy target.
-- WHY:   mirrors wowsims APL + TBC frost community consensus. Priority:
--         defensives/buffs > CDs (WE/IV/ColdSnap) > shatter Ice Lance >
--         Winter's Chill Frostbolt > AoE Blizzard/CoC > Frostbolt filler.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no on_update() allocs.
local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end
local SPELLS = NS.MageSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

-- Centralized spell resolver via spec_kit (rank IDs from mage/class_sylvanas.lua).
local define = spec_kit.define_action_for_class(SPELLS)
local ACTION = {
    ArcaneExplosion   = define("ArcaneExplosion",   { 27082, 27080, 10202, 10201, 8439, 8438, 8437, 1449 }, "ArcaneExplosion"),
    ArcaneIntellect   = define("ArcaneIntellect",   { 27126, 10157, 10156, 1461, 1460, 1459 }, "ArcaneIntellect"),
    ArcaneMissiles    = define("ArcaneMissiles",    { 38699, 25345, 10212, 10211, 8418, 8417, 8416, 5145, 5144, 5143 }, "ArcaneMissiles"),
    Blink             = define("Blink",             { 1953 }, "Blink"),
    Blizzard          = define("Blizzard",          { 27085, 10187, 10186, 10185, 8427, 6141, 10 }, "Blizzard"),
    ColdSnap          = define("ColdSnap",          { 11958 }, "ColdSnap"),
    ConeOfCold        = define("ConeOfCold",        { 27087, 10161, 10160, 10159, 8492, 120 }, "ConeOfCold"),
    ConjureManaEmerald= define("ConjureManaEmerald",{ 27101, 10054, 10053, 3552, 759 }, "ConjureManaEmerald"),
    Counterspell      = define("Counterspell",      { 2139 }, "Counterspell"),
    Evocation         = define("Evocation",         { 12051 }, "Evocation"),
    FireBlast         = define("FireBlast",         { 27079, 27078, 10199, 10197, 8413, 8412, 2138, 2137, 2136 }, "FireBlast"),
    FrostArmor        = define("FrostArmor",        { 27124, 10220, 10219, 7320, 7302, 7301, 7300, 168 }, "FrostArmor"),
    FrostNova         = define("FrostNova",         { 27088, 10230, 6131, 865, 122 }, "FrostNova"),
    FrostWard         = define("FrostWard",         { 32796, 28609, 10177, 8462, 8461, 6143 }, "FrostWard"),
    Frostbolt         = define("Frostbolt",         { 27072, 25304, 10181, 10180, 10179, 8408, 8407, 8406, 7322, 837, 205, 116 }, "Frostbolt"),
    IceBarrier        = define("IceBarrier",        { 33405, 27134, 13033, 13032, 13031, 11426 }, "IceBarrier"),
    IceBlock          = define("IceBlock",          { 45438 }, "IceBlock"),
    IceLance          = define("IceLance",          { 30455 }, "IceLance"),
    IcyVeins          = define("IcyVeins",          { 12472 }, "IcyVeins"),
    MageArmor         = define("MageArmor",         { 27125, 22783, 22782, 6117 }, "MageArmor"),
    ManaShield        = define("ManaShield",        { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }, "ManaShield"),
    Polymorph         = define("Polymorph",         { 12826, 12825, 12824, 118 }, "Polymorph"),
    PresenceOfMind    = define("PresenceOfMind",    { 12043 }, "PresenceOfMind"),
    RemoveCurse       = define("RemoveCurse",       { 475 }, "RemoveCurse"),
    Scorch            = define("Scorch",            { 27074, 27073, 10207, 10206, 10205, 8446, 8445, 8444, 2948 }, "Scorch"),
    WaterElemental    = define("WaterElemental",    { 31687 }, "WaterElemental"),
}

-- Root/snare debuff IDs (used by Blink escape)
local COMMON_SNARES = { 122, 116, 120, 339, 5116, 3409, 3600, 12494, 13099 }

local potion_helper = require("shared/potion_helper_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { mage = {} } } end
local TBC_MAGE = (TBC.SPELLS and TBC.SPELLS.mage) or {}

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local ICE_BARRIER_BUFF = { 13032, 13031, 13033 }
local FROST_NOVA_ROOTS = TBC_MAGE.frost_nova or { 27088, 10230, 6131, 865, 122 }
local MANA_SHIELD_BUFF = { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }
local ARCANE_INTELLECT_BUFF = { 27127, 23028, 27126, 10157, 10156, 1461, 1460, 1459 }
local MAGE_ARMOR_BUFF = { 27125, 22783, 22782, 6117 }
-- Frost Armor + Ice Armor share one ladder (Ice Armor replaces Frost Armor at lvl 30).
local FROST_ARMOR_BUFF = { 27124, 10220, 10219, 7320, 7302, 7301, 7300, 168 }
-- Any active mage armor — used to suppress the armor fallback when one is already up.
local ANY_MAGE_ARMOR_BUFF = { 27125, 22783, 22782, 6117, 27124, 10220, 10219, 7320, 7302, 7301, 7300, 168, 30482 }
local ICE_BLOCK_BUFF = { 45438 }  -- 11958=ColdSnap not IceBlock; 27619 unverified
local PRESENCE_OF_MIND_BUFF = { 12043 }
local COMBUSTION_BUFF = { 11129 }
local WINTERS_CHILL_DEBUFF = { 28595, 28594, 28593, 28592, 11180 }
local FROSTBITE_DEBUFF = { 12494 }
local MANA_GEM_CONJURE = { 27101, 10054, 10053, 3552, 759 }
local MANA_GEM_ITEM_IDS = { 22044, 8008, 8007, 5513, 5514 }
local CLEARCASTING_BUFF = { 12536 }  -- Clearcasting proc from Arcane Concentration talent

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(item_ids)
    if not NS.is_item_ready then return 0 end
    for i = 1, #item_ids do
        local item_id = item_ids[i]
        if NS.is_item_ready(item_id) then return item_id end
    end
    return 0
end

-- ============================================================================
-- Custom Gating Functions (test assertions depend on these signatures)
-- ============================================================================

local function ice_block_matches(context)
    local me = context.me
    if not me then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100
    local threshold = (context.is_group or false) and 30 or 20
    if hp > threshold then return false end
    return true
end

local function cold_snap_matches(context, s)
    s = s or {}
    local me = context.me
    if not me then return false end
    -- Defensive path: Ice Block on cooldown, low HP
    if not (me and NS.spell_ready(ACTION.IceBlock, me)) then
        local hp = me.get_health_percentage and me:get_health_percentage() or 100
        local threshold = (context.is_group or false) and 45 or 35
        if hp <= threshold then return true end
    end
    -- DPS path: double-pet or double-IV
    if s.in_combat then
        if not s.has_water_elemental and not s.water_elemental_ready then
            return true
        end
        if not s.icy_veins_ready then
            return true
        end
    end
    return false
end

local function frost_nova_matches(context)
    if not context.target then return false end
    local target = context.target
    local is_rooted = NS.debuff_up and NS.debuff_up(target, FROST_NOVA_ROOTS) or false
    if is_rooted then return false end
    local me = context.me
    if not me then return false end
    local dist = me.get_distance and me:get_distance(target) or 999
    if dist > 10 then return false end
    return true
end

local function cone_of_cold_matches(context)
    if not context.target then return false end
    local me = context.me
    if not me then return false end
    local dist = me.get_distance and me:get_distance(context.target) or 999
    if dist > 10 then return false end
    -- Use on frozen target in melee range (single target burst, 3x CoC damage)
    local frozen = context.target and NS.debuff_up and (NS.debuff_up(context.target, FROSTBITE_DEBUFF) or NS.debuff_up(context.target, FROST_NOVA_ROOTS)) or false
    if frozen then return true end
    -- AoE: 2+ targets inside Cone of Cold frontal cone (~10yd, ESP-style facing sector)
    local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10
    if NS.aoe_cone_meets then
        if not NS.aoe_cone_meets(2, r, nil, context) then return false end
    elseif not NS.aoe_self_meets or not NS.aoe_self_meets(2, r, context) then
        return false
    end
    return true
end

-- ============================================================================
-- State builder
-- ============================================================================
-- ============================================================================
-- Schema for safe_state (Pattern 14 nil-guard elimination).
-- ============================================================================
local FROST_SCHEMA = {
    -- Buff presence
    has_ice_barrier = false, has_mana_shield = false, has_arcane_intellect = false,
    has_mage_armor = false, has_any_armor = false, has_ice_block = false,
    has_presence_of_mind = false, has_combustion = false, has_clearcasting = false,
    -- Resource
    mana_pct = 100, hp_pct = 100,
    -- Combat
    enemy_count = 0, in_combat = false, is_group = false,
    -- Target
    target_casting = false, target_casting_interruptible = false,
    target_hp_pct = 100, target_not_rooted = false,
    target_frozen = false, frostbite_active = false,
    -- Spell readiness
    ice_barrier_ready = false, ice_block_ready = false, cold_snap_ready = false,
    icy_veins_ready = false, water_elemental_ready = false, frost_nova_ready = false,
    ice_lance_ready = false, cone_of_cold_ready = false, blizzard_ready = false,
    frostbolt_ready = false, presence_of_mind_ready = false, evocation_ready = false,
    mana_shield_ready = false, arcane_intellect_ready = false, fire_blast_ready = false,
    frost_ward_ready = false, counterspell_ready = false, polymorph_ready = false,
    remove_curse_ready = false, scorch_ready = false, arcane_missiles_ready = false,
    -- Numeric
    winter_chill_stacks = 0, ice_barrier_remains = 999,
    healthstone_ready = 0,
    -- Pet
    has_water_elemental = false,
    -- Items
    mana_gem_available = false,
}

local frost_state = {
    has_ice_barrier = false,
    has_mana_shield = false,
    has_arcane_intellect = false,
    has_mage_armor = false,
    has_any_armor = false,
    has_ice_block = false,
    has_presence_of_mind = false,
    has_combustion = false,
    has_clearcasting = false,
    mana_pct = 100,
    hp_pct = 100,
    enemy_count = 1,
    target_casting = false,
    target_casting_interruptible = false,
    target_hp_pct = 100,
    target_not_rooted = false,
    in_combat = false,
    ice_barrier_ready = false,
    ice_block_ready = false,
    cold_snap_ready = false,
    icy_veins_ready = false,
    water_elemental_ready = false,
    frost_nova_ready = false,
    ice_lance_ready = false,
    cone_of_cold_ready = false,
    blizzard_ready = false,
    frostbolt_ready = false,
    presence_of_mind_ready = false,
    evocation_ready = false,
    mana_shield_ready = false,
    arcane_intellect_ready = false,
    fire_blast_ready = false,
    frost_ward_ready = false,
    counterspell_ready = false,
    polymorph_ready = false,
    remove_curse_ready = false,
    scorch_ready = false,
    arcane_missiles_ready = false,
    winter_chill_stacks = 0,
    frostbite_active = false,
    target_frozen = false,
    mana_gem_available = false,
    ice_barrier_remains = 999,
    healthstone_ready = 0,
}

local function first_ready_mana_gem()
    if not NS.is_item_ready then return nil end
    for _, item_id in ipairs(MANA_GEM_ITEM_IDS) do
        local ok, ready = pcall(NS.is_item_ready, item_id)
        if ok and ready then return item_id end
    end
    return nil
end

local function use_mana_gem()
    local item_id = first_ready_mana_gem()
    if not item_id or not NS.use_item_by_id then return false end
    local ok, used = pcall(NS.use_item_by_id, item_id)
    return ok and used == true
end

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target
    frost_state.is_group = context.is_group or false

    frost_state.has_ice_barrier = me and NS.buff_up(me, ICE_BARRIER_BUFF) or false
    frost_state.has_mana_shield = me and NS.buff_up(me, MANA_SHIELD_BUFF) or false
    frost_state.has_arcane_intellect = me and NS.buff_up(me, ARCANE_INTELLECT_BUFF) or false
    frost_state.has_mage_armor = me and NS.buff_up(me, MAGE_ARMOR_BUFF) or false
    frost_state.has_any_armor = me and NS.buff_up(me, ANY_MAGE_ARMOR_BUFF) or false
    frost_state.has_ice_block = me and NS.buff_up(me, ICE_BLOCK_BUFF) or false
    frost_state.has_presence_of_mind = me and NS.buff_up(me, PRESENCE_OF_MIND_BUFF) or false
    frost_state.has_combustion = me and NS.buff_up(me, COMBUSTION_BUFF) or false
    frost_state.has_clearcasting = me and NS.buff_up(me, CLEARCASTING_BUFF) or false
    frost_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct and NS.unit_mana_pct(me)) or 100
    frost_state.hp_pct = context.hp or (me and NS.unit_health_pct and NS.unit_health_pct(me)) or 100
    frost_state.enemy_count = context.enemy_count or context.enemies_count or 1
    frost_state.target_casting = target and target.is_casting and target:is_casting() or false
    frost_state.target_casting_interruptible = frost_state.target_casting and (NS.is_interruptible and NS.is_interruptible(target) or false)
    frost_state.target_hp_pct = target and NS.unit_health_pct and NS.unit_health_pct(target) or 100
    frost_state.target_not_rooted = target and not NS.debuff_up(target, FROST_NOVA_ROOTS) or false
    frost_state.in_combat = context.in_combat or false
    frost_state.ice_barrier_ready = me and NS.spell_ready(ACTION.IceBarrier, me, { skip_range = true }) or false
    frost_state.ice_block_ready = me and NS.spell_ready(ACTION.IceBlock, me, { skip_range = true }) or false
    frost_state.cold_snap_ready = me and NS.spell_ready(ACTION.ColdSnap, me, { skip_range = true, expected_cooldown = 480 }) or false
    frost_state.icy_veins_ready = me and NS.spell_ready(ACTION.IcyVeins, me, { skip_range = true, expected_cooldown = 180 }) or false
    frost_state.water_elemental_ready = me and NS.spell_ready(ACTION.WaterElemental, me, { skip_range = true, expected_cooldown = 180 }) or false
    frost_state.frost_nova_ready = me and NS.spell_ready(ACTION.FrostNova, me, { skip_range = true, expected_cooldown = 25 }) or false
    frost_state.ice_lance_ready = target and NS.spell_ready(ACTION.IceLance, target) or false
    frost_state.cone_of_cold_ready = me and NS.spell_ready(ACTION.ConeOfCold, me, { expected_cooldown = 10 }) or false
    frost_state.blizzard_ready = me and NS.spell_ready(ACTION.Blizzard, me, { expected_cooldown = 8, skip_range = true }) or false
    frost_state.frostbolt_ready = target and NS.spell_ready(ACTION.Frostbolt, target, { expected_cooldown = 3 }) or false
    frost_state.presence_of_mind_ready = me and NS.spell_ready(ACTION.PresenceOfMind, me, { skip_range = true, expected_cooldown = 180 }) or false
    frost_state.evocation_ready = me and NS.spell_ready(ACTION.Evocation, me, { skip_range = true, expected_cooldown = 480 }) or false
    frost_state.mana_shield_ready = me and NS.spell_ready(ACTION.ManaShield, me, { skip_range = true }) or false
    frost_state.arcane_intellect_ready = me and NS.spell_ready(ACTION.ArcaneIntellect, me, { skip_range = true }) or false
    frost_state.fire_blast_ready = target and NS.spell_ready(ACTION.FireBlast, target, { expected_cooldown = 8 }) or false
    frost_state.frost_ward_ready = me and NS.spell_ready(ACTION.FrostWard, me, { skip_range = true }) or false
    frost_state.counterspell_ready = target and NS.spell_ready(ACTION.Counterspell, target, { expected_cooldown = 24 }) or false
    frost_state.polymorph_ready = target and NS.spell_ready(ACTION.Polymorph, target, { expected_cooldown = 1.5 }) or false
    frost_state.remove_curse_ready = me and NS.spell_ready(ACTION.RemoveCurse, me, { skip_range = true }) or false
    frost_state.scorch_ready = target and NS.spell_ready(ACTION.Scorch, target, { expected_cooldown = 1.5 }) or false
    frost_state.arcane_missiles_ready = target and NS.spell_ready(ACTION.ArcaneMissiles, target, { expected_cooldown = 5 }) or false
    frost_state.winter_chill_stacks = target and NS.debuff_stacks and NS.debuff_stacks(target, WINTERS_CHILL_DEBUFF) or 0
    frost_state.frostbite_active = target and NS.debuff_up and NS.debuff_up(target, FROSTBITE_DEBUFF) or false
    local target_rooted = target and NS.debuff_up and NS.debuff_up(target, FROST_NOVA_ROOTS) or false
    frost_state.target_frozen = frost_state.frostbite_active or target_rooted
    frost_state.has_water_elemental = false
    if me and me.has_pet then
        local ok_pet, pet = pcall(function() return me:get_pet() end)
        if ok_pet and pet and pet.is_valid then
            local ok_valid, valid = pcall(function() return pet:is_valid() end)
            frost_state.has_water_elemental = ok_valid and valid or false
        end
    end
    frost_state.ice_barrier_remains = me and (NS.buff_remains and NS.buff_remains(me, ICE_BARRIER_BUFF)) or 999
    frost_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS)

    return spec_kit.safe_state(frost_state, FROST_SCHEMA)
end

-- (Action definitions removed — all execute functions use NS.try_cast directly)

-- ============================================================================
-- Match functions
-- ============================================================================
local function ice_block_wrapper(context)
    return ice_block_matches(context)
end

local function cold_snap_wrapper(context, s)
    return cold_snap_matches(context, s)
end

local function frost_nova_wrapper(context)
    return frost_nova_matches(context)
end

local function cone_of_cold_wrapper(context)
    return cone_of_cold_matches(context)
end

local function blizzard_matches(context, s)
    if context.is_channeling then return false end
    if not NS.aoe_target_meets or not NS.aoe_target_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8, context.target, context, s) then return false end
    if not context.in_combat then return false end
    if context.is_moving then return false end
    if not s.blizzard_ready then return false end
    return true
end

local function arcane_explosion_matches(context, s)
    if not NS.aoe_self_meets or not NS.aoe_self_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, s) then return false end
    if not context.in_combat then return false end
    if not (ACTION.ArcaneExplosion and NS.spell_ready) then return false end
    return NS.spell_ready(ACTION.ArcaneExplosion, context.me or NS.GetPlayer(), { skip_range = true })
end

local function frostbolt_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    -- Clearcasting: always consume on Frostbolt (highest damage) per research
    if s.has_clearcasting then return true end
    if not s.frostbolt_ready then return false end
    return true
end

local function presence_of_mind_matches(context, s)
    if context.settings and context.settings.use_cooldowns == false then return false end
    if not s.in_combat then return false end
    if s.has_presence_of_mind then return false end
    if not s.presence_of_mind_ready then return false end
    return true
end

local function evocation_matches(context, s)
    if context.settings and context.settings.use_evocation == false then return false end
    if not s.in_combat then return false end
    if (s.mana_pct or 100) > 30 then return false end
    if not s.evocation_ready then return false end
    return true
end

local function mana_shield_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.ManaShield, 3.0) then return false end
    if context.settings and (context.settings.use_defensives == false or context.settings.use_mana_shield == false) then return false end
    if s.has_mana_shield then return false end
    if not s.mana_shield_ready then return false end
    return true
end

local function arcane_intellect_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.ArcaneIntellect, 3.0) then return false end
    if context.settings and context.settings.use_self_buffs == false then return false end
    if s.has_arcane_intellect then return false end
    if not s.arcane_intellect_ready then return false end
    return true
end

local function fire_blast_matches(context, s)
    if not context.settings or context.settings.frost_use_fire_blast ~= true then return false end
    if not context.target then return false end
    if not s.fire_blast_ready then return false end
    return true
end

local function frost_ward_matches(context, s)
    if not s.frost_ward_ready then return false end
    return true
end

local function polymorph_matches(context, s)
    if not (context.is_pvp or context.is_group) then return false end
    if not context.target then return false end
    if not s.polymorph_ready then return false end
    return true
end

local function remove_curse_matches(context, s)
    if context.settings and context.settings.auto_remove_curse == false then return false end
    if not s.remove_curse_ready then return false end
    return true
end

local function scorch_matches(context, s)
    if not context.settings or context.settings.frost_use_scorch ~= true then return false end
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.scorch_ready then return false end
    return true
end

local function arcane_missiles_matches(context, s)
    if not context.settings or context.settings.frost_use_arcane_missiles ~= true then return false end
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.arcane_missiles_ready then return false end
    return true
end

local function frost_armor_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.FrostArmor, 3.0) then return false end
    if context.settings and context.settings.use_self_buffs == false then return false end
    if s.has_any_armor then return false end
    -- Frost/Ice Armor is the low-level fallback; once Mage Armor is learned (lvl 34+)
    -- it is strictly better, so defer to mage_armor_matches.
    if NS.is_spell_learned and NS.is_spell_learned(ACTION.MageArmor) then return false end
    local me = context.me or NS.GetPlayer()
    return NS.spell_ready and NS.spell_ready(ACTION.FrostArmor, me, { skip_range = true }) or false
end

local function mage_armor_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.MageArmor, 3.0) then return false end
    if context.settings and context.settings.use_self_buffs == false then return false end
    if s.has_mage_armor then return false end
    -- Skip when Mage Armor is not learned so we never spam an unlearned spell;
    -- frost_armor_matches handles the Frost/Ice Armor fallback below it.
    if NS.is_spell_learned and not NS.is_spell_learned(ACTION.MageArmor) then return false end
    return true
end

local function mana_gem_conjure_matches_fn(context, s)
    if s.in_combat then return false end
    if s.mana_gem_available then return false end
    return NS.spell_ready(ACTION.ConjureManaEmerald, context.me or NS.GetPlayer(), { skip_range = true }) or false
end

local function mana_gem_matches_fn(context, s)
    if context.settings and context.settings.use_mana_gem == false then return false end
    if not s.mana_gem_available then return false end
    local gem_threshold = (context.settings and context.settings.mana_gem_mana_pct) or 70
    if (s.mana_pct or 100) > gem_threshold then return false end
    return true
end

local function blink_matches(context, s)
    return s.in_combat and (context.self_rooted_snared or (NS.has_player_debuff and NS.has_player_debuff(COMMON_SNARES) or false)) and NS.spell_ready(ACTION.Blink)
end

local function blizzard_execute(context)
    local t = context.target
    local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8
    if NS.cast_ground_aoe then
        return NS.cast_ground_aoe(ACTION.Blizzard, t, r, 35, "[FROST] Blizzard")
    end
    local pos = t and NS.get_aoe_cast_position and NS.get_aoe_cast_position(NS.get_spell_id(ACTION.Blizzard), t, r, 35)
    if pos then return NS.try_cast_position(ACTION.Blizzard, pos, t, "[FROST] Blizzard") end
    return NS.try_cast(ACTION.Blizzard, t, "[FROST] Blizzard")
end

-- ============================================================================
-- Declarative Strategy DSL
-- ============================================================================
local DSL_DEFS = {
    {
        name = "IceBarrier",
        conditions = {
            { type = "custom", fn = function(context, state)
                if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.IceBarrier, 3.0) then return false end
                return true
            end },
            { type = "setting", key = "use_defensives", op = "!=", value = false },
            { type = "setting", key = "use_ice_barrier", op = "!=", value = false },
            { type = "custom", fn = function(context, state)
                if state.has_ice_barrier and (state.ice_barrier_remains or 999) > 5 then return false end
                return true
            end },
            { type = "state", field = "ice_barrier_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.IceBarrier, target = "self", opts = { skip_range = true }, label = "[FROST] IceBarrier" },
    },
    {
        name = "IcyVeins",
        conditions = {
            { type = "setting", key = "use_cooldowns", op = "!=", value = false },
            { type = "custom", fn = function(context, state)
                return NS.gate_cooldown_boss_only(context)
            end },
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "icy_veins_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if context.ttd_known and context.ttd > 0 and context.ttd < 15 then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.IcyVeins, target = "self", opts = { skip_range = true, expected_cooldown = 180 }, label = "[FROST] IcyVeins" },
    },
    {
        name = "WaterElemental",
        conditions = {
            { type = "setting", key = "use_cooldowns", op = "!=", value = false },
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "has_water_elemental", op = "falsy" },
            { type = "state", field = "water_elemental_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if context.ttd_known and context.ttd > 0 and context.ttd < 15 then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.WaterElemental, target = "self", opts = { skip_range = true, expected_cooldown = 180 }, label = "[FROST] WaterElemental" },
    },
    {
        name = "FrozenIceLance",
        conditions = {
            { type = "custom", fn = function(context, state) return context.target ~= nil end },
            { type = "state", field = "ice_lance_ready", op = "truthy" },
            { type = "OR", conditions = {
                { type = "state", field = "target_frozen", op = "truthy" },
                { type = "context", field = "is_moving", op = "truthy" },
            } },
        },
        action = { type = "cast", spell = ACTION.IceLance, target = "target", label = "[FROST] Frozen IceLance" },
    },
    {
        name = "FrostbiteFrostbolt",
        conditions = {
            { type = "custom", fn = function(context, state) return context.target ~= nil end },
            { type = "context", field = "is_moving", op = "falsy" },
            { type = "state", field = "frostbite_active", op = "truthy" },
            { type = "state", field = "frostbolt_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Frostbolt, target = "target", label = "[FROST] Frostbite FB" },
    },
    {
        name = "WintersChill",
        conditions = {
            { type = "custom", fn = function(context, state) return context.target ~= nil end },
            { type = "context", field = "is_moving", op = "falsy" },
            { type = "state", field = "frostbolt_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if (state.winter_chill_stacks or 0) >= 5 then
                    local wc_remains = NS.debuff_remains and NS.debuff_remains(context.target, WINTERS_CHILL_DEBUFF) or 999
                    if wc_remains > 3 then return false end
                end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Frostbolt, target = "target", label = "[FROST] Winter's Chill" },
    },
}

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    -- Auto Mana Potion — gate on context.has_mana_potion (inventory_helper)
    { name = "ManaPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_mana_potion then return false end
          if (context.mana_pct or 100) > 20 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
    { name = "FrostArmor", matches = frost_armor_matches, execute = function() return NS.try_cast(ACTION.FrostArmor, NS.PLAYER_UNIT, "[FROST] Frost Armor", { skip_range = true }) end },
    { name = "MageArmor", matches = mage_armor_matches, execute = function() return NS.try_cast(ACTION.MageArmor, NS.PLAYER_UNIT, "[FROST] Mage Armor", { skip_range = true }) end },
    { name = "ArcaneIntellect", matches = arcane_intellect_matches, execute = function() return NS.try_cast(ACTION.ArcaneIntellect, NS.PLAYER_UNIT, "[FROST] ArcaneIntellect", { skip_range = true }) end },
    { name = "IceBarrier" },  -- DSL-substituted at runtime
    { name = "IceBlock", matches = ice_block_wrapper, execute = function() return NS.try_cast(ACTION.IceBlock, NS.PLAYER_UNIT, "[FROST] IceBlock", { skip_range = true }) end },
    { name = "Healthstone",
      matches = function(context, state)
          if not context.in_combat then return false end
          if (state.hp_pct or 100) > 28 then return false end
          return (state.healthstone_ready or 0) > 0
      end,
      execute = function(context)
          local item_id = first_ready_item(HEALTHSTONE_IDS)
          if item_id > 0 and NS.use_item_by_id then
              return NS.use_item_by_id(item_id, context.me) and true or false
          end
          return false
      end,
    },
    { name = "Blink", matches = blink_matches, execute = function() return NS.try_cast(ACTION.Blink, NS.PLAYER_UNIT, "[FROST] Blink", { skip_range = true }) end },
    { name = "ColdSnap", matches = cold_snap_wrapper, execute = function() return NS.try_cast(ACTION.ColdSnap, NS.PLAYER_UNIT, "[FROST] ColdSnap", { skip_range = true }) end },
    { name = "IcyVeins" },  -- DSL-substituted at runtime
    { name = "WaterElemental" },  -- DSL-substituted at runtime
    { name = "FrostbiteFrostbolt" },  -- DSL-substituted at runtime
    { name = "FrozenIceLance" },  -- DSL-substituted at runtime
    { name = "PresenceOfMind", matches = presence_of_mind_matches, execute = function() return NS.try_cast(ACTION.PresenceOfMind, NS.PLAYER_UNIT, "[FROST] PresenceOfMind", { skip_range = true }) end },
    { name = "Evocation", matches = evocation_matches, execute = function() return NS.try_cast(ACTION.Evocation, NS.PLAYER_UNIT, "[FROST] Evocation", { skip_range = true }) end },
    { name = "ManaGemConjure", matches = mana_gem_conjure_matches_fn, execute = function() return NS.try_cast(ACTION.ConjureManaEmerald, NS.PLAYER_UNIT, "[FROST] ConjureManaGem", { skip_range = true }) end },
    { name = "ManaGem", matches = mana_gem_matches_fn, execute = function() return use_mana_gem() end },
    { name = "ManaShield", matches = mana_shield_matches, execute = function() return NS.try_cast(ACTION.ManaShield, NS.PLAYER_UNIT, "[FROST] ManaShield", { skip_range = true }) end },
    { name = "FrostWard", matches = frost_ward_matches, execute = function() return NS.try_cast(ACTION.FrostWard, NS.PLAYER_UNIT, "[FROST] FrostWard", { skip_range = true }) end },
    { name = "RemoveCurse", matches = remove_curse_matches, execute = function() return NS.try_cast(ACTION.RemoveCurse, NS.PLAYER_UNIT, "[FROST] RemoveCurse", { skip_range = true }) end },
    { name = "WintersChill" },  -- DSL-substituted at runtime
    { name = "FrostNova", matches = frost_nova_wrapper, execute = function(context) return NS.try_cast(ACTION.FrostNova, context.me or NS.GetPlayer(), "[FROST] FrostNova", { skip_range = true }) end },
    { name = "ConeOfCold", matches = cone_of_cold_wrapper, execute = function(context) return NS.try_cast(ACTION.ConeOfCold, context.me or NS.GetPlayer(), "[FROST] ConeOfCold", { skip_range = true }) end },
    { name = "Polymorph", matches = polymorph_matches, execute = function(context) return NS.try_cast(ACTION.Polymorph, context.target, "[FROST] Polymorph") end },
    { name = "ArcaneExplosion", matches = arcane_explosion_matches, execute = function(context) return NS.try_cast(ACTION.ArcaneExplosion, context.me or NS.GetPlayer(), "[FROST] ArcaneExplosion", { skip_range = true }) end },
    { name = "Blizzard", matches = blizzard_matches, execute = blizzard_execute },
    { name = "FireBlast", matches = fire_blast_matches, execute = function(context) return NS.try_cast(ACTION.FireBlast, context.target, "[FROST] FireBlast") end },
    { name = "Scorch", matches = scorch_matches, execute = function(context) return NS.try_cast(ACTION.Scorch, context.target, "[FROST] Scorch") end },
    { name = "ArcaneMissiles", matches = arcane_missiles_matches, execute = function(context) return NS.try_cast(ACTION.ArcaneMissiles, context.target, "[FROST] ArcaneMissiles") end },
    { name = "Frostbolt", matches = frostbolt_matches, execute = function(context) return NS.try_cast(ACTION.Frostbolt, context.target, "[FROST] Frostbolt") end },
}

-- Replace imperative match functions with DSL-compiled equivalents.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("frost", strategies, { get_state = build_state })
end
if NS.log then NS.log("Mage frost rotation registered") end
-- Mage frost rotation registered
return { strategies = strategies, build_state = build_state }

