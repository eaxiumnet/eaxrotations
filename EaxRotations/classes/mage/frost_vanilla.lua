-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-28
-- Change: Classic Vanilla Frost Mage rotation
-- =========================================================================
local __eax_file = "classes/mage/frost_vanilla.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-28"
local __eax_change = "Classic Vanilla Frost Mage rotation"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Mage Frost priority list.

-- ============================================================================
-- What: Classic Vanilla Mage Frost priority with control, defensive, and burst logic.
-- When: Evaluated every tick.
-- Why: Priority-list early exit keeps combat decisions fast and predictable.
-- Safety: All settings nil-guarded; shared data is pcall-gated; conservative fallbacks.
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.MageSpells or {}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { mage = {} } } end
local TBC_MAGE = (TBC.SPELLS and TBC.SPELLS.mage) or {}

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local ICE_BARRIER_BUFF = { 13032, 13031, 13033 }
local FROST_NOVA_ROOTS = TBC_MAGE.frost_nova or { 27088, 10230, 6131, 865, 122 }
local MANA_SHIELD_BUFF = { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }
local ARCANE_INTELLECT_BUFF = { 27126, 10157, 10156, 1461, 1460, 1459, 23028, 27127 }
local MOLTEN_ARMOR_BUFF = { 30482 }
local ICE_BLOCK_BUFF = { 45438, 27619 }
local PRESENCE_OF_MIND_BUFF = { 12043 }
local COMBUSTION_BUFF = { 11129 }
local WINTERS_CHILL_DEBUFF = { 28595, 28594, 28593, 28592, 11180 }
local FROSTBITE_DEBUFF = { 12494 }
local MANA_GEM_CONJURE = { 27103, 27101, 27100, 27099, 10054 }

-- ============================================================================
-- Custom Gating Functions (test assertions depend on these signatures)
-- ============================================================================

local function ice_block_matches(context)
    local me = context.me
    if not me then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100
    if hp > 20 then return false end
    return true
end

local function cold_snap_matches(context)
    local me = context.me
    if not me then return false end
    if me and NS.spell_ready(SPELLS.IceBlock, me) then return false end
    local hp = me.get_health_percentage and me:get_health_percentage() or 100
    if hp > 35 then return false end
    return true
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
    local nearby = 1
    if context.enemies then
        nearby = 0
        for i = 1, #context.enemies do
            local e = context.enemies[i]
            if e and e:is_valid() then
                local edist = me.get_distance and me:get_distance(e) or 999
                if edist <= 10 then nearby = nearby + 1 end
            end
        end
    end
    if nearby < 2 then return false end
    return true
end

-- ============================================================================
-- State builder
-- ============================================================================
local frost_state = {
    has_ice_barrier = false,
    has_mana_shield = false,
    has_arcane_intellect = false,
    has_molten_armor = false,
    has_ice_block = false,
    has_presence_of_mind = false,
    has_combustion = false,
    mana_pct = 100,
    hp_pct = 100,
    enemy_count = 1,
    target_casting = false,
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
    mana_gem_available = false,
    ice_barrier_remains = 999,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target

    frost_state.has_ice_barrier = me and NS.buff_up(me, ICE_BARRIER_BUFF) or false
    frost_state.has_mana_shield = me and NS.buff_up(me, MANA_SHIELD_BUFF) or false
    frost_state.has_arcane_intellect = me and NS.buff_up(me, ARCANE_INTELLECT_BUFF) or false
    frost_state.has_molten_armor = me and NS.buff_up(me, MOLTEN_ARMOR_BUFF) or false
    frost_state.has_ice_block = me and NS.buff_up(me, ICE_BLOCK_BUFF) or false
    frost_state.has_presence_of_mind = me and NS.buff_up(me, PRESENCE_OF_MIND_BUFF) or false
    frost_state.has_combustion = me and NS.buff_up(me, COMBUSTION_BUFF) or false
    frost_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    frost_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    frost_state.enemy_count = context.enemy_count or context.enemies_count or 1
    frost_state.target_casting = target and target.is_casting and target:is_casting() or false
    frost_state.target_hp_pct = target and NS.unit_health_pct and NS.unit_health_pct(target) or 100
    frost_state.target_not_rooted = target and not NS.debuff_up(target, FROST_NOVA_ROOTS) or false
    frost_state.in_combat = context.in_combat or false
    frost_state.ice_barrier_ready = me and NS.spell_ready(SPELLS.IceBarrier, me, { skip_range = true }) or false
    frost_state.ice_block_ready = me and NS.spell_ready(SPELLS.IceBlock, me, { skip_range = true }) or false
    frost_state.cold_snap_ready = me and NS.spell_ready(SPELLS.ColdSnap, me, { skip_range = true, expected_cooldown = 480 }) or false
    frost_state.icy_veins_ready = me and NS.spell_ready(SPELLS.IcyVeins, me, { skip_range = true, expected_cooldown = 180 }) or false
    frost_state.water_elemental_ready = me and NS.spell_ready(SPELLS.UnavailableClassicMagePet, me, { skip_range = true, expected_cooldown = 180 }) or false
    frost_state.frost_nova_ready = me and NS.spell_ready(SPELLS.FrostNova, me, { skip_range = true, expected_cooldown = 25 }) or false
    frost_state.ice_lance_ready = target and NS.spell_ready(SPELLS.UnavailableClassicMageFrost, target) or false
    frost_state.cone_of_cold_ready = me and NS.spell_ready(SPELLS.ConeOfCold, me, { expected_cooldown = 10 }) or false
    frost_state.blizzard_ready = me and NS.spell_ready(SPELLS.Blizzard, me, { expected_cooldown = 8, skip_range = true }) or false
    frost_state.frostbolt_ready = target and NS.spell_ready(SPELLS.Frostbolt, target, { expected_cooldown = 3 }) or false
    frost_state.presence_of_mind_ready = me and NS.spell_ready(SPELLS.PresenceOfMind, me, { skip_range = true, expected_cooldown = 180 }) or false
    frost_state.evocation_ready = me and NS.spell_ready(SPELLS.Evocation, me, { skip_range = true, expected_cooldown = 480 }) or false
    frost_state.mana_shield_ready = me and NS.spell_ready(SPELLS.ManaShield, me, { skip_range = true }) or false
    frost_state.arcane_intellect_ready = me and NS.spell_ready(SPELLS.ArcaneIntellect, me, { skip_range = true }) or false
    frost_state.fire_blast_ready = target and NS.spell_ready(SPELLS.FireBlast, target, { expected_cooldown = 8 }) or false
    frost_state.frost_ward_ready = me and NS.spell_ready(SPELLS.FrostWard, me, { skip_range = true }) or false
    frost_state.counterspell_ready = target and NS.spell_ready(SPELLS.Counterspell, target, { expected_cooldown = 24 }) or false
    frost_state.polymorph_ready = target and NS.spell_ready(SPELLS.Polymorph, target, { expected_cooldown = 1.5 }) or false
    frost_state.remove_curse_ready = me and NS.spell_ready(SPELLS.RemoveCurse, me, { skip_range = true }) or false
    frost_state.scorch_ready = target and NS.spell_ready(SPELLS.Scorch, target, { expected_cooldown = 1.5 }) or false
    frost_state.arcane_missiles_ready = target and NS.spell_ready(SPELLS.ArcaneMissiles, target, { expected_cooldown = 5 }) or false
    frost_state.winter_chill_stacks = target and NS.debuff_stacks and NS.debuff_stacks(target, WINTERS_CHILL_DEBUFF) or 0
    frost_state.frostbite_active = target and NS.debuff_up and NS.debuff_up(target, FROSTBITE_DEBUFF) or false
    frost_state.mana_gem_available = false
    if me and NS.spell_ready then
        for _, gem_id in ipairs(MANA_GEM_CONJURE) do
            if NS.spell_ready(gem_id, me, { skip_range = true }) then
                frost_state.mana_gem_available = true
                break
            end
        end
    end
    frost_state.ice_barrier_remains = me and (NS.buff_remains and NS.buff_remains(me, ICE_BARRIER_BUFF)) or 999

    return frost_state
end

-- (Action definitions removed — all execute functions use NS.try_cast directly)

-- ============================================================================
-- Match functions
-- ============================================================================
local function ice_barrier_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.IceBarrier, 3.0) then return false end
    if s.has_ice_barrier and s.ice_barrier_remains > 5 then return false end
    if not s.ice_barrier_ready then return false end
    return true
end

local function ice_block_wrapper(context)
    return ice_block_matches(context)
end

local function cold_snap_wrapper(context)
    return cold_snap_matches(context)
end

local function icy_veins_matches(context, s)
    if not s.in_combat then return false end
    if not s.icy_veins_ready then return false end
    return true
end

local function water_elemental_matches(context, s)
    if not s.in_combat then return false end
    if not s.water_elemental_ready then return false end
    return true
end

local function frost_nova_wrapper(context)
    return frost_nova_matches(context)
end

local function ice_lance_matches(context, s)
    if not context.target then return false end
    if not s.ice_lance_ready then return false end
    return true
end

local function cone_of_cold_wrapper(context)
    return cone_of_cold_matches(context)
end

local function blizzard_matches(context, s)
    if context.is_channeling then return false end
    if s.enemy_count < 3 then return false end
    if not context.in_combat then return false end
    if context.is_moving then return false end
    if not s.blizzard_ready then return false end
    return true
end

local function arcane_explosion_matches(context, s)
    if s.enemy_count < 3 then return false end
    if not context.in_combat then return false end
    if not (SPELLS.ArcaneExplosion and NS.spell_ready) then return false end
    return NS.spell_ready(SPELLS.ArcaneExplosion, context.me or NS.GetPlayer(), { skip_range = true })
end

local function frostbolt_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.frostbolt_ready then return false end
    return true
end

local function presence_of_mind_matches(context, s)
    if not s.in_combat then return false end
    if s.has_presence_of_mind then return false end
    if not s.presence_of_mind_ready then return false end
    return true
end

local function evocation_matches(context, s)
    if not s.in_combat then return false end
    if s.mana_pct > 30 then return false end
    if not s.evocation_ready then return false end
    return true
end

local function mana_shield_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.ManaShield, 3.0) then return false end
    if s.has_mana_shield then return false end
    if not s.mana_shield_ready then return false end
    return true
end

local function arcane_intellect_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.ArcaneIntellect, 3.0) then return false end
    if s.has_arcane_intellect then return false end
    if not s.arcane_intellect_ready then return false end
    return true
end

local function fire_blast_matches(context, s)
    if not context.target then return false end
    if not s.fire_blast_ready then return false end
    return true
end

local function frost_ward_matches(context, s)
    if not s.frost_ward_ready then return false end
    return true
end

local function counterspell_matches(context, s)
    if not context.target then return false end
    if not s.target_casting then return false end
    if not s.counterspell_ready then return false end
    return true
end

local function polymorph_matches(context, s)
    if not context.target then return false end
    if not s.polymorph_ready then return false end
    return true
end

local function remove_curse_matches(context, s)
    if not s.remove_curse_ready then return false end
    return true
end

local function scorch_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.scorch_ready then return false end
    return true
end

local function arcane_missiles_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.arcane_missiles_ready then return false end
    return true
end

local function molten_armor_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.UnavailableClassicMageArmor, 3.0) then return false end
    if s.has_molten_armor then return false end
    return true
end

local function winter_chill_fb_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.frostbolt_ready then return false end
    if s.winter_chill_stacks >= 5 then
        local wc_remains = NS.debuff_remains and NS.debuff_remains(context.target, WINTERS_CHILL_DEBUFF) or 999
        if wc_remains > 3 then return false end
    end
    return true
end

local function frostbite_fb_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.frostbite_active then return false end
    if not s.frostbolt_ready then return false end
    return true
end

local function mana_gem_conjure_matches_fn(context, s)
    if s.in_combat then return false end
    if s.mana_gem_available then return false end
    return NS.spell_ready(SPELLS.ConjureManaEmerald, context.me or NS.GetPlayer(), { skip_range = true }) or false
end

local function mana_gem_matches_fn(context, s)
    if not s.mana_gem_available then return false end
    local gem_threshold = (context.settings and context.settings.mana_gem_mana_pct) or 70
    if s.mana_pct > gem_threshold then return false end
    return true
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "UnavailableClassicMageArmor", matches = molten_armor_matches, execute = function() return NS.try_cast(SPELLS.UnavailableClassicMageArmor, NS.PLAYER_UNIT, "[FROST] UnavailableClassicMageArmor", { skip_range = true }) end },
    { name = "ArcaneIntellect", matches = arcane_intellect_matches, execute = function() return NS.try_cast(SPELLS.ArcaneIntellect, NS.PLAYER_UNIT, "[FROST] ArcaneIntellect", { skip_range = true }) end },
    { name = "IceBarrier", matches = ice_barrier_matches, execute = function() return NS.try_cast(SPELLS.IceBarrier, NS.PLAYER_UNIT, "[FROST] IceBarrier", { skip_range = true }) end },
    { name = "IceBlock", matches = ice_block_wrapper, execute = function() return NS.try_cast(SPELLS.IceBlock, NS.PLAYER_UNIT, "[FROST] IceBlock", { skip_range = true }) end },
    { name = "ColdSnap", matches = cold_snap_wrapper, execute = function() return NS.try_cast(SPELLS.ColdSnap, NS.PLAYER_UNIT, "[FROST] ColdSnap", { skip_range = true }) end },
    { name = "IcyVeins", matches = icy_veins_matches, execute = function() return NS.try_cast(SPELLS.IcyVeins, NS.PLAYER_UNIT, "[FROST] IcyVeins", { skip_range = true, expected_cooldown = 180 }) end },
    { name = "UnavailableClassicMagePet", matches = water_elemental_matches, execute = function() return NS.try_cast(SPELLS.UnavailableClassicMagePet, NS.PLAYER_UNIT, "[FROST] UnavailableClassicMagePet", { skip_range = true, expected_cooldown = 180 }) end },
    { name = "FrostbiteFrostbolt", matches = frostbite_fb_matches, execute = function(context) return NS.try_cast(SPELLS.Frostbolt, context.target, "[FROST] Frostbite FB") end },
    { name = "PresenceOfMind", matches = presence_of_mind_matches, execute = function() return NS.try_cast(SPELLS.PresenceOfMind, NS.PLAYER_UNIT, "[FROST] PresenceOfMind", { skip_range = true }) end },
    { name = "Evocation", matches = evocation_matches, execute = function() return NS.try_cast(SPELLS.Evocation, NS.PLAYER_UNIT, "[FROST] Evocation", { skip_range = true }) end },
    { name = "ManaGemConjure", matches = mana_gem_conjure_matches_fn, execute = function() return NS.try_cast(SPELLS.ConjureManaEmerald, NS.PLAYER_UNIT, "[FROST] ConjureManaGem", { skip_range = true }) end },
    { name = "ManaGem", matches = mana_gem_matches_fn, execute = function(context) return NS.try_cast(SPELLS.ConjureManaEmerald, NS.PLAYER_UNIT or NS.GetPlayer(), "[FROST] ManaGem", { skip_range = true }) end },
    { name = "ManaShield", matches = mana_shield_matches, execute = function() return NS.try_cast(SPELLS.ManaShield, NS.PLAYER_UNIT, "[FROST] ManaShield", { skip_range = true }) end },
    { name = "FrostWard", matches = frost_ward_matches, execute = function() return NS.try_cast(SPELLS.FrostWard, NS.PLAYER_UNIT, "[FROST] FrostWard", { skip_range = true }) end },
    { name = "Counterspell", matches = counterspell_matches, execute = function(context) return NS.try_cast(SPELLS.Counterspell, context.target, "[FROST] Counterspell") end },
    { name = "RemoveCurse", matches = remove_curse_matches, execute = function() return NS.try_cast(SPELLS.RemoveCurse, NS.PLAYER_UNIT, "[FROST] RemoveCurse", { skip_range = true }) end },
    { name = "WintersChill", matches = winter_chill_fb_matches, execute = function(context) return NS.try_cast(SPELLS.Frostbolt, context.target, "[FROST] Winter's Chill") end },
    { name = "FrostNova", matches = frost_nova_wrapper, execute = function(context) return NS.try_cast(SPELLS.FrostNova, context.me or NS.GetPlayer(), "[FROST] FrostNova", { skip_range = true }) end },
    { name = "ConeOfCold", matches = cone_of_cold_wrapper, execute = function(context) return NS.try_cast(SPELLS.ConeOfCold, context.me or NS.GetPlayer(), "[FROST] ConeOfCold", { skip_range = true }) end },
    { name = "Polymorph", matches = polymorph_matches, execute = function(context) return NS.try_cast(SPELLS.Polymorph, context.target, "[FROST] Polymorph") end },
    { name = "ArcaneExplosion", matches = arcane_explosion_matches, execute = function(context) return NS.try_cast(SPELLS.ArcaneExplosion, context.me or NS.GetPlayer(), "[FROST] ArcaneExplosion", { skip_range = true }) end },
    { name = "Blizzard", matches = blizzard_matches, execute = function(context) return NS.try_cast(SPELLS.Blizzard, context.target, "[FROST] Blizzard") end },
    { name = "FireBlast", matches = fire_blast_matches, execute = function(context) return NS.try_cast(SPELLS.FireBlast, context.target, "[FROST] FireBlast") end },
    { name = "Scorch", matches = scorch_matches, execute = function(context) return NS.try_cast(SPELLS.Scorch, context.target, "[FROST] Scorch") end },
    { name = "UnavailableClassicMageFrost", matches = ice_lance_matches, execute = function(context) return NS.try_cast(SPELLS.UnavailableClassicMageFrost, context.target, "[FROST] UnavailableClassicMageFrost") end },
    { name = "ArcaneMissiles", matches = arcane_missiles_matches, execute = function(context) return NS.try_cast(SPELLS.ArcaneMissiles, context.target, "[FROST] ArcaneMissiles") end },
    { name = "Frostbolt", matches = frostbolt_matches, execute = function(context) return NS.try_cast(SPELLS.Frostbolt, context.target, "[FROST] Frostbolt") end },
}

NS.rotation_registry:register("frost", strategies, { get_state = build_state })
NS.log("Mage frost rotation registered (Tier A)")
return strategies

