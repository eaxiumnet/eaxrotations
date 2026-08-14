-- frost_vanilla.lua — Mage Frost for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  frost DPS (Frostbolt spam, Winter's Chill, Frost Nova + Cone of Cold).
-- WHEN:  combat, when NS.is_vanilla() is true.
-- WHY:   expansion-aware loader selects _vanilla suffix for Classic Era.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.


local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end
local SPELLS = NS.MageSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")

local potion_helper = require("shared/potion_helper_sylvanas")

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local ICE_BARRIER_BUFF = { 11426, 13031, 13032, 13033 }
local FROST_NOVA_ROOTS = { 10230, 6131, 865, 122 }
local MANA_SHIELD_BUFF = { 10193, 10192, 10191, 8495, 8494, 1463 }
local ARCANE_INTELLECT_BUFF = { 23028, 10157, 10156, 1461, 1460, 1459 }
local PRESENCE_OF_MIND_BUFF = { 12043 }
local WINTERS_CHILL_DEBUFF = { 11180 }
local FROSTBITE_DEBUFF = { 12494 }
local MANA_GEM_ITEM_IDS = { 8008, 8007, 5513, 5514 }

-- Curse debuff IDs a Mage can dispel from self (Vanilla warlock curses + raid
-- curses). All verified present in the 2.5.5 DBC.
local CURSE_DEBUFFS = {
    702, 1108, 6205, 7646, 11707, 11708,   -- Curse of Weakness R1-R6
    1714, 11719, 12889, 13338, 15470,      -- Curse of Tongues R1-R5
    704, 7658, 7659, 11717,                -- Curse of Recklessness R1-R4
    980, 1014, 6217, 11711, 11712, 11713,  -- Curse of Agony R1-R6
    1490, 11721, 11722,                    -- Curse of the Elements R1-R3
    603, 18223,                            -- Curse of Doom / Curse of Exhaustion
}

--- True when the unit carries a curse, false when definitively not afflicted,
--- nil when the affliction cannot be determined (unit API surface absent).
local function curse_present(unit)
    if not unit then return nil end
    if type(unit.has_debuff) ~= "function" then return nil end
    for i = 1, #CURSE_DEBUFFS do
        local ok, present = pcall(unit.has_debuff, unit, CURSE_DEBUFFS[i])
        if ok and present then return true end
    end
    return false
end

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
    -- AoE: 2+ targets inside frontal cone (~10yd)
    local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10
    if NS.aoe_cone_meets then
        return NS.aoe_cone_meets(2, r, nil, context)
    end
    if NS.aoe_self_meets then
        return NS.aoe_self_meets(2, r, context)
    end
    return false
end

-- ============================================================================
-- State builder
-- ============================================================================
-- Schema for safe_state: Pattern 14 nil-guard defaults.
local FROST_VANILLA_SCHEMA = {
    has_ice_barrier = false,  has_mana_shield = false,
    has_arcane_intellect = false,  has_ice_block = false,
    has_presence_of_mind = false,  has_combustion = false,
    mana_pct = 100,  hp_pct = 100,  enemy_count = 1,
    target_casting = false,  target_hp_pct = 100,
    ice_barrier_ready = false,  ice_block_ready = false,
    frostbolt_ready = false,  presence_of_mind_ready = false,
    evocation_ready = false,  mana_shield_ready = false,
    arcane_intellect_ready = false,  fire_blast_ready = false,
    frost_ward_ready = false,  counterspell_ready = false,
    polymorph_ready = false,  remove_curse_ready = false,
    scorch_ready = false,  arcane_missiles_ready = false,
    winter_chill_stacks = 0,  frostbite_active = false,
    mana_gem_available = false,  ice_barrier_remains = 999,
}

local frost_state = {
    has_ice_barrier = false,
    has_mana_shield = false,
    has_arcane_intellect = false,
    has_presence_of_mind = false,
    mana_pct = 100,
    enemy_count = 1,
    target_casting = false,
    in_combat = false,
    ice_barrier_ready = false,
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

-- Hoisted spell_ready opts (no fresh table per frame — Pattern 4 static reuse)
local _SKIP_RANGE = { skip_range = true }

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

    frost_state.has_ice_barrier = me and NS.buff_up(me, ICE_BARRIER_BUFF) or false
    frost_state.has_mana_shield = me and NS.buff_up(me, MANA_SHIELD_BUFF) or false
    frost_state.has_arcane_intellect = me and NS.buff_up(me, ARCANE_INTELLECT_BUFF) or false
    frost_state.has_presence_of_mind = me and NS.buff_up(me, PRESENCE_OF_MIND_BUFF) or false
    frost_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct and NS.unit_mana_pct(me)) or 100
    frost_state.enemy_count = context.enemy_count or context.enemies_count or 1
    frost_state.target_casting = target and target.is_casting and target:is_casting() or false
    frost_state.in_combat = context.in_combat or false
    frost_state.ice_barrier_ready = me and NS.spell_ready(SPELLS.IceBarrier, me, _SKIP_RANGE) or false
    frost_state.blizzard_ready = me and NS.spell_ready(SPELLS.Blizzard, me, { expected_cooldown = 8, skip_range = true }) or false
    frost_state.frostbolt_ready = target and NS.spell_ready(SPELLS.Frostbolt, target, { expected_cooldown = 3 }) or false
    frost_state.presence_of_mind_ready = me and NS.spell_ready(SPELLS.PresenceOfMind, me, { skip_range = true, expected_cooldown = 180 }) or false
    frost_state.evocation_ready = me and NS.spell_ready(SPELLS.Evocation, me, { skip_range = true, expected_cooldown = 480 }) or false
    frost_state.mana_shield_ready = me and NS.spell_ready(SPELLS.ManaShield, me, _SKIP_RANGE) or false
    frost_state.arcane_intellect_ready = me and NS.spell_ready(SPELLS.ArcaneIntellect, me, _SKIP_RANGE) or false
    frost_state.fire_blast_ready = target and NS.spell_ready(SPELLS.FireBlast, target, { expected_cooldown = 8 }) or false
    frost_state.frost_ward_ready = me and NS.spell_ready(SPELLS.FrostWard, me, _SKIP_RANGE) or false
    frost_state.counterspell_ready = target and NS.spell_ready(SPELLS.Counterspell, target, { expected_cooldown = 24 }) or false
    frost_state.polymorph_ready = target and NS.spell_ready(SPELLS.Polymorph, target, { expected_cooldown = 1.5 }) or false
    frost_state.remove_curse_ready = me and NS.spell_ready(SPELLS.RemoveCurse, me, _SKIP_RANGE) or false
    frost_state.scorch_ready = target and NS.spell_ready(SPELLS.Scorch, target, { expected_cooldown = 1.5 }) or false
    frost_state.arcane_missiles_ready = target and NS.spell_ready(SPELLS.ArcaneMissiles, target, { expected_cooldown = 5 }) or false
    frost_state.winter_chill_stacks = target and NS.debuff_stacks and NS.debuff_stacks(target, WINTERS_CHILL_DEBUFF) or 0
    frost_state.frostbite_active = target and NS.debuff_up and NS.debuff_up(target, FROSTBITE_DEBUFF) or false
    frost_state.mana_gem_available = first_ready_mana_gem() ~= nil
    frost_state.ice_barrier_remains = me and (NS.buff_remains and NS.buff_remains(me, ICE_BARRIER_BUFF)) or 999

    return spec_kit.safe_state(frost_state, FROST_VANILLA_SCHEMA)
end

-- (Action definitions removed ? all execute functions use NS.try_cast directly)

-- ============================================================================
-- Match functions
-- ============================================================================
local function ice_barrier_matches(context, s)
    if context.settings and (context.settings.use_defensives == false or context.settings.use_ice_barrier == false) then return false end
    if s.has_ice_barrier and (s.ice_barrier_remains or 999) > 5 then return false end
    if not s.ice_barrier_ready then return false end
    return true
end

local function ice_block_wrapper(context)
    return ice_block_matches(context)
end

local function cold_snap_wrapper(context)
    return cold_snap_matches(context)
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
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    if context.settings and context.settings.use_cooldowns == false then return false end
    if not s.in_combat then return false end
    if s.has_presence_of_mind then return false end
    if not s.presence_of_mind_ready then return false end
    return true
end

local function evocation_matches(context, s)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 480) then return false end
    if context.settings and context.settings.use_evocation == false then return false end
    if not s.in_combat then return false end
    if (s.mana_pct or 100) > 30 then return false end
    if not s.evocation_ready then return false end
    return true
end

local function mana_shield_matches(context, s)
    if context.settings and (context.settings.use_defensives == false or context.settings.use_mana_shield == false) then return false end
    if (context.hp or 100) > 40 then return false end
    if s.has_mana_shield then return false end
    if not s.mana_shield_ready then return false end
    return true
end

local function arcane_intellect_matches(context, s)
    if context.settings and context.settings.use_self_buffs == false then return false end
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
    if not s.in_combat then return false end
    if not s.frost_ward_ready then return false end
    return true
end

local function counterspell_matches(context, s)
    if not context.target then return false end
    if context.settings and context.settings.use_interrupt == false then return false end
    if not s.target_casting then return false end
    if not s.counterspell_ready then return false end
    return true
end

local function polymorph_matches(context, s)
    -- Mirror the arcane/fire sibling gates: never sheep the main PvE target.
    if not context.is_pvp then return false end
    if not context.cc_target then return false end
    if not s.polymorph_ready then return false end
    return true
end

local function remove_curse_matches(context, s)
    -- Curse detection is NOT middleware-handled on Vanilla: gate on combat
    -- and on an actual curse affliction (documented unit API me:has_debuff;
    -- nil = cannot determine, keep the ready-check behavior). Honors both the
    -- frost key (auto_remove_curse) and the fire key (use_remove_curse_fire).
    if context.settings and (context.settings.auto_remove_curse == false or context.settings.use_remove_curse_fire == false) then return false end
    if not s.remove_curse_ready then return false end
    if not context.in_combat then return false end
    if curse_present(context.me or NS.GetPlayer()) == false then return false end
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

local function winter_chill_fb_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.frostbolt_ready then return false end
    if (s.winter_chill_stacks or 0) >= 5 then
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
    if context.settings and context.settings.use_mana_gem == false then return false end
    if not s.mana_gem_available then return false end
    local gem_threshold = (context.settings and context.settings.mana_gem_mana_pct) or 70
    if (s.mana_pct or 100) > gem_threshold then return false end
    return true
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "ManaPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_mana_potion then return false end
          if (context.mana_pct or 100) > 20 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
    { name = "ArcaneIntellect", matches = arcane_intellect_matches, execute = function() return NS.try_cast(SPELLS.ArcaneIntellect, NS.PLAYER_UNIT, "[FROST] ArcaneIntellect", { skip_range = true }) end },
    { name = "IceBarrier", matches = ice_barrier_matches, execute = function() return NS.try_cast(SPELLS.IceBarrier, NS.PLAYER_UNIT, "[FROST] IceBarrier", { skip_range = true }) end },
    { name = "IceBlock", matches = ice_block_wrapper, execute = function() return NS.try_cast(SPELLS.IceBlock, NS.PLAYER_UNIT, "[FROST] IceBlock", { skip_range = true }) end },
    { name = "ColdSnap", matches = cold_snap_wrapper, execute = function() return NS.try_cast(SPELLS.ColdSnap, NS.PLAYER_UNIT, "[FROST] ColdSnap", { skip_range = true }) end },
    { name = "FrostbiteFrostbolt", matches = frostbite_fb_matches, execute = function(context) return NS.try_cast(SPELLS.Frostbolt, context.target, "[FROST] Frostbite FB") end },
    { name = "PresenceOfMind", matches = presence_of_mind_matches, execute = function() return NS.try_cast(SPELLS.PresenceOfMind, NS.PLAYER_UNIT, "[FROST] PresenceOfMind", { skip_range = true }) end },
    { name = "Evocation", matches = evocation_matches, execute = function() return NS.try_cast(SPELLS.Evocation, NS.PLAYER_UNIT, "[FROST] Evocation", { skip_range = true }) end },
    { name = "ManaGemConjure", matches = mana_gem_conjure_matches_fn, execute = function() return NS.try_cast(SPELLS.ConjureManaEmerald, NS.PLAYER_UNIT, "[FROST] ConjureManaGem", { skip_range = true }) end },
    { name = "ManaGem", matches = mana_gem_matches_fn, execute = function() return use_mana_gem() end },
    { name = "ManaShield", matches = mana_shield_matches, execute = function() return NS.try_cast(SPELLS.ManaShield, NS.PLAYER_UNIT, "[FROST] ManaShield", { skip_range = true }) end },
    { name = "FrostWard", matches = frost_ward_matches, execute = function() return NS.try_cast(SPELLS.FrostWard, NS.PLAYER_UNIT, "[FROST] FrostWard", { skip_range = true }) end },
    { name = "Counterspell", matches = counterspell_matches, execute = function(context) return NS.try_cast(SPELLS.Counterspell, context.target, "[FROST] Counterspell") end },
    { name = "RemoveCurse", matches = remove_curse_matches, execute = function() return NS.try_cast(SPELLS.RemoveCurse, NS.PLAYER_UNIT, "[FROST] RemoveCurse", { skip_range = true }) end },
    { name = "WintersChill", matches = winter_chill_fb_matches, execute = function(context) return NS.try_cast(SPELLS.Frostbolt, context.target, "[FROST] Winter's Chill") end },
    { name = "FrostNova", matches = frost_nova_wrapper, execute = function(context) return NS.try_cast(SPELLS.FrostNova, context.me or NS.GetPlayer(), "[FROST] FrostNova", { skip_range = true }) end },
    { name = "ConeOfCold", matches = cone_of_cold_wrapper, execute = function(context) return NS.try_cast(SPELLS.ConeOfCold, context.me or NS.GetPlayer(), "[FROST] ConeOfCold", { skip_range = true }) end },
    { name = "Polymorph", matches = polymorph_matches, execute = function(context) return NS.try_cast(SPELLS.Polymorph, context.target, "[FROST] Polymorph") end },
    { name = "ArcaneExplosion", matches = arcane_explosion_matches, execute = function(context) return NS.try_cast(SPELLS.ArcaneExplosion, context.me or NS.GetPlayer(), "[FROST] ArcaneExplosion", { skip_range = true }) end },
    { name = "Blizzard", matches = blizzard_matches, execute = function(context)
        local t = context.target
        local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8
        if NS.cast_ground_aoe then return NS.cast_ground_aoe(SPELLS.Blizzard, t, r, 35, "[FROST] Blizzard") end
        local pos = t and NS.get_aoe_cast_position and NS.get_aoe_cast_position(NS.get_spell_id(SPELLS.Blizzard), t, r, 35)
        if pos then return NS.try_cast_position(SPELLS.Blizzard, pos, t, "[FROST] Blizzard") end
        return NS.try_cast(SPELLS.Blizzard, t, "[FROST] Blizzard")
    end },
    -- Frostbolt is THE primary nuke for Frost mage — it must precede FireBlast
    -- (the lane order was inverted, so an always-ready FireBlast starved the
    -- primary nuke) and sit above the Scorch/AM fillers so a hybrid mage who
    -- learned those spells doesn't waste GCDs on weaker fillers.
    { name = "Frostbolt", matches = frostbolt_matches, execute = function(context) return NS.try_cast(SPELLS.Frostbolt, context.target, "[FROST] Frostbolt") end },
    { name = "FireBlast", matches = fire_blast_matches, execute = function(context) return NS.try_cast(SPELLS.FireBlast, context.target, "[FROST] FireBlast") end },
    { name = "Scorch", matches = scorch_matches, execute = function(context) return NS.try_cast(SPELLS.Scorch, context.target, "[FROST] Scorch") end },
    { name = "ArcaneMissiles", matches = arcane_missiles_matches, execute = function(context) return NS.try_cast(SPELLS.ArcaneMissiles, context.target, "[FROST] ArcaneMissiles") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("frost", strategies, { get_state = build_state })
end
-- Mage frost rotation registered
return strategies

