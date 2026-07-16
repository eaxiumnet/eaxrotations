-- leveling_sylvanas -- mage leveling_sylvanas rotation for TBC Anniversary (2.5.5).

-- WHAT:  priority-list strategies for leveling_sylvanas gameplay.

-- WHEN:  combat with valid enemy target.

-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.

-- SAFETY: every state field read is nil-guarded via build_state() defaults; no on_update() allocs.



-- Mage leveling priority list.

-- Designed for solo/leveling play, from level 1 to 70.

-- Handles unlearned spells gracefully via NS.spell_ready checks.

-- Uses wand/Shoot as fallback when out of mana.

-- Safety spells: Frost Armor (lvl 1+), Cone of Cold (lvl 26+), Blink (lvl 20+), Remove Curse (lvl 18+).





local NS = _G.EaxRotations

if not NS then return nil end

local leveling = require("shared/leveling_sylvanas")

if not leveling then return nil end

local SPELLS = NS.MageSpells or {}

local spec_kit = require("shared/spec_kit_sylvanas")



-- ============================================================================

-- Constants

-- ============================================================================



local _rbf_ok, RBF = pcall(require, "shared/ranked_buff_families_sylvanas")
-- AB first (superior), then AI ranks high→low (Vanilla∪TBC∪WotLK).
local ARCANE_INTELLECT_BUFF = (_rbf_ok and RBF and RBF.detect("arcane_intellect")) or { 27127, 23028, 27126, 10157, 10156, 1461, 1460, 1459 }

local FROST_ARMOR_BUFF = { 27124, 10220, 10219, 7320, 7302, 7301, 7300, 168 }

local MAGE_ARMOR_BUFF = { 27125, 22783, 22782, 6117 }

local ICE_BARRIER_BUFF = { 33405, 27134, 13033, 13032, 13031, 11426 }

local MANA_SHIELD_BUFF = { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }

local POLYMORPH_IDS = { 12826, 12825, 12824, 118 }



-- Mana gem conjure spells (newest → oldest rank)

local CONJURE_MANA_GEM_SPELLS = { 27101, 10054, 10053, 3552, 759 }

-- Mana gem item IDs (highest → lowest rank) — using correct TBC item IDs

local MANA_GEM_ITEM_IDS = { 22044, 8008, 8007, 5513, 5514 }



-- Freeze detection for Ice Lance 3x damage

local FROST_NOVA_ROOTS = { 27088, 10230, 6131, 865, 122 }

local FROSTBITE_DEBUFF = { 12494 }



local WAND_SPELL_ID = leveling.WAND_SPELL_ID or 5019



local EMPTY_SETTINGS = {}



-- ============================================================================

-- Spell readiness helper (hoisted to module level — no closure per frame)

-- ============================================================================



local function spell_is_ready(action, target, opts)

    if not NS.spell_ready then return false end

    local ok, ready = pcall(NS.spell_ready, action, target, opts)

    return ok and ready

end



--- Safe buff check wrapper — pcall protects against nil/throwing NS.buff_up

local function safe_buff_up(unit, ids)

    if not unit or not NS.buff_up then return false end

    local ok, has_buff = pcall(NS.buff_up, unit, ids)

    return ok and has_buff

end



--- Safe debuff remains wrapper — pcall protects against nil/throwing NS.debuff_remains

local function safe_debuff_remains(unit, ids)

    if not unit or not NS.debuff_remains then return 0 end

    local ok, remains = pcall(NS.debuff_remains, unit, ids)

    if ok and type(remains) == "number" then return remains end

    return 0

end



--- Safe item ready check wrapper — pcall protects against nil/throwing NS.is_item_ready

local function safe_is_item_ready(item_id)

    if not NS.is_item_ready then return false end

    local ok, ready = pcall(NS.is_item_ready, item_id)

    return ok and ready

end



--- Safe item use wrapper — pcall protects against nil/throwing NS.use_item_by_id

local function safe_use_item(item_id)

    if not NS.use_item_by_id then return false end

    local ok, used = pcall(NS.use_item_by_id, item_id)

    return ok and used

end



--- Safe try_cast wrapper — pcall protects against nil/throwing NS.try_cast

local function try_cast(spell_action, target, label, opts)

    if not NS.try_cast then return false end

    local ok, result = pcall(NS.try_cast, spell_action, target, label, opts)

    return ok and result == true

end



-- ============================================================================

-- State builder

-- ============================================================================



local function build_state(context)

    if not context then return nil end

    local me = context.me

    local state = {}



    state.has_ai = safe_buff_up(me, ARCANE_INTELLECT_BUFF)

    state.has_mage_armor = safe_buff_up(me, MAGE_ARMOR_BUFF)

    state.has_frost_armor = safe_buff_up(me, FROST_ARMOR_BUFF)

    state.has_ice_barrier = safe_buff_up(me, ICE_BARRIER_BUFF)

    state.has_mana_shield = safe_buff_up(me, MANA_SHIELD_BUFF)



    state.in_combat = context.in_combat or false

    state.mana_pct = context.mana_pct or 100

    state.hp = context.hp or 100

    state.enemies = context.enemies_count or 0

    state.target = context.target

    state.is_moving = context.is_moving or false



    -- Settings from schema (with sensible defaults)

    state.wand_threshold = spec_kit.setting_number(context, "leveling_wand_threshold", 30)

    state.polymorph_hp = spec_kit.setting_number(context, "leveling_polymorph_hp", 40)

    state.use_arcane_missiles = spec_kit.setting_bool(context, "leveling_arcane_missiles_use", true)

    state.use_scorch = spec_kit.setting_bool(context, "leveling_scorch_use", true)

    state.use_interrupt = spec_kit.setting_bool(context, "use_interrupt", true)

    state.use_fire_blast = spec_kit.setting_bool(context, "leveling_fire_blast_use", true)

    state.use_fireball = spec_kit.setting_bool(context, "leveling_fireball_use", true)



    -- Mana gem state

    state.use_mana_gem = spec_kit.setting_bool(context, "use_mana_gem", true)

    state.mana_gem_threshold = spec_kit.setting_number(context, "mana_gem_mana_pct", 70)



    -- Check if conjure mana gem spell is learned

    state.conjure_gem_ready = false

    for _, spell_id in ipairs(CONJURE_MANA_GEM_SPELLS) do

        local ok_e, exists = pcall(NS.spell_exists, spell_id)

        if ok_e and exists then

            state.conjure_gem_ready = true

            break

        end

    end



    -- Check if any mana gem item is available in inventory

    state.mana_gem_available = false

    for _, item_id in ipairs(MANA_GEM_ITEM_IDS) do

        if safe_is_item_ready(item_id) then

            state.mana_gem_available = true

            break

        end

    end



    -- Spell readiness (each returns false if spell not learned, errors caught via pcall)

    state.frostbolt_ready = spell_is_ready(SPELLS.Frostbolt, context.target)

    state.fireball_ready = spell_is_ready(SPELLS.Fireball, context.target)

    state.fire_blast_ready = spell_is_ready(SPELLS.FireBlast, context.target)

    state.scorch_ready = spell_is_ready(SPELLS.Scorch, context.target)

    state.arcane_missiles_ready = spell_is_ready(SPELLS.ArcaneMissiles, context.target)

    state.frost_nova_ready = spell_is_ready(SPELLS.FrostNova, context.target)

    state.blizzard_ready = spell_is_ready(SPELLS.Blizzard, context.target)

    state.polymorph_ready = spell_is_ready(SPELLS.Polymorph, context.target)

    state.counterspell_ready = spell_is_ready(SPELLS.Counterspell, context.target)

    state.evocation_ready = spell_is_ready(SPELLS.Evocation, nil, { skip_range = true })

    state.ice_barrier_ready = spell_is_ready(SPELLS.IceBarrier, nil, { skip_range = true })

    state.mana_shield_ready = spell_is_ready(SPELLS.ManaShield, nil, { skip_range = true })

    state.ai_ready = spell_is_ready(SPELLS.ArcaneIntellect, nil, { skip_range = true })

    state.remove_curse_ready = spell_is_ready(SPELLS.RemoveCurse, nil, { skip_range = true })

    state.frost_armor_ready = spell_is_ready(SPELLS.FrostArmor, nil, { skip_range = true })

    state.cone_of_cold_ready = spell_is_ready(SPELLS.ConeOfCold, context.target)

    state.blink_ready = spell_is_ready(SPELLS.Blink, nil, { skip_range = true })

    state.mage_armor_ready = spell_is_ready(SPELLS.MageArmor, nil, { skip_range = true })

    state.water_elemental_ready = spell_is_ready(SPELLS.WaterElemental, nil, { skip_range = true })

    state.ice_lance_ready = spell_is_ready(SPELLS.IceLance, context.target)



    -- Pet tracking: check if Water Elemental is already active

    state.has_water_elemental = false

    if me and me.has_pet then

        local ok_pet, pet = pcall(function() return me:get_pet() end)

        if ok_pet and pet then

            local ok_valid, valid = pcall(function() return pet:is_valid() end)

            state.has_water_elemental = ok_valid and valid or false

        end

    end



    -- Freeze detection for Ice Lance 3x damage

    local target = context.target

    local frostbite_active = target and NS.debuff_up and NS.debuff_up(target, FROSTBITE_DEBUFF) or false

    local target_rooted = target and NS.debuff_up and NS.debuff_up(target, FROST_NOVA_ROOTS) or false

    state.target_frozen = frostbite_active or target_rooted

    state.target_not_rooted = target and not target_rooted or false



    -- Wand readiness (learned via wand training)

    local ok_wand, exists = pcall(NS.spell_exists, WAND_SPELL_ID)

    state.wand_learned = ok_wand and exists or false



    return spec_kit.safe_state(state)

end



-- ============================================================================

-- Match functions

-- ============================================================================



local function arcane_intellect_matches(context, state)

    if not state then return false end

    if state.in_combat then return false end

    if state.has_ai then return false end

    return state.ai_ready

end



local function evocation_matches(context, state)

    if not state then return false end

    if not state.in_combat then return false end

    if (state.mana_pct or 100) > 25 then return false end

    return state.evocation_ready

end



local function ice_barrier_matches(context, state)

    if not state then return false end

    if state.has_ice_barrier then return false end

    if not state.in_combat then return false end

    return state.ice_barrier_ready

end



local function mana_shield_matches(context, state)

    if not state then return false end

    if not state.in_combat then return false end

    if state.has_mana_shield then return false end

    if (state.hp or 100) > 40 then return false end

    return state.mana_shield_ready

end



local function counterspell_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.use_interrupt then return false end

    local ok, casting = pcall(function() return state.target:is_casting() end)

    if not ok or not casting then return false end

    return state.counterspell_ready

end



local function polymorph_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if state.in_combat then return false end

    -- Don't polymorph targets below HP threshold (too dangerous to pull)

    local ok, hp = pcall(function() return state.target:get_health_percentage() end)

    if ok and hp and hp >= (state.polymorph_hp or 40) then return false end

    local remains = safe_debuff_remains(state.target, POLYMORPH_IDS)

    if remains >= 10 then return false end

    return state.polymorph_ready

end



local function frost_nova_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if not context or not context.me then return false end

    -- Only frost nova when target is in melee range

    local ok, dist = pcall(function() return state.target:get_distance(context.me) end)

    if not ok or not dist or dist > 10 then return false end

    return state.frost_nova_ready

end



local function blizzard_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if (state.enemies or 0) < 3 then return false end

    if state.is_moving then return false end

    return state.blizzard_ready

end



local function fire_blast_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if not state.use_fire_blast then return false end

    return state.fire_blast_ready

end



local function arcane_missiles_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if state.is_moving then return false end

    if not state.use_arcane_missiles then return false end

    if (state.mana_pct or 100) < 20 then return false end

    return state.arcane_missiles_ready

end



local function frostbolt_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if state.is_moving then return false end

    if (state.mana_pct or 100) < 10 then return false end

    -- Prefer Ice Lance when target is frozen (3x damage)

    if state.target_frozen then return false end

    return state.frostbolt_ready

end



local function fireball_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if state.is_moving then return false end

    if not state.use_fireball then return false end

    if (state.mana_pct or 100) < 10 then return false end

    return state.fireball_ready

end



local function scorch_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if not state.use_scorch then return false end

    if state.is_moving then return false end

    if (state.mana_pct or 100) < 10 then return false end

    return state.scorch_ready

end



local function frost_armor_matches(context, state)

    if not state then return false end

    if state.in_combat then return false end

    if state.has_frost_armor then return false end

    if state.has_mage_armor then return false end

    return state.frost_armor_ready

end



local function cone_of_cold_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if (state.enemies or 0) < 2 then return false end

    if not context or not context.me then return false end

    local ok, dist = pcall(function() return state.target:get_distance(context.me) end)

    if not ok or not dist or dist > 10 then return false end

    return state.cone_of_cold_ready

end



local function blink_matches(context, state)

    if not state then return false end

    if not state.in_combat then return false end

    if (state.hp or 100) > 50 then return false end

    return state.blink_ready

end



local function remove_curse_matches(context, state)

    if not state then return false end

    -- OOC cleanup: remove curses between pulls

    if state.in_combat then return false end

    return state.remove_curse_ready

end



-- NOTE: In-combat curse removal would require scanning for curse debuffs on self.

-- For leveling simplicity, Remove Curse runs OOC only.



local function mage_armor_matches(context, state)

    if not state then return false end

    if state.in_combat then return false end

    if state.has_mage_armor then return false end

    -- Prefer Mage Armor over Frost Armor once learned (better mana regen)

    return state.mage_armor_ready

end



local function water_elemental_matches(context, state)

    if not state then return false end

    if not state.in_combat then return false end

    if state.has_water_elemental then return false end

    if not state.water_elemental_ready then return false end

    return true

end



local function ice_lance_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.ice_lance_ready then return false end

    -- Ice Lance deals 3x damage to frozen targets; otherwise use when moving

    if state.target_frozen then return true end

    if state.is_moving then return true end

    return false

end



local function wand_matches(context, state)

    if not state then return false end

    if not state.target then return false end

    if not state.wand_learned then return false end

    -- Use wand threshold from settings instead of hardcoded 20%

    if (state.mana_pct or 100) >= (state.wand_threshold or 30) then return false end

    return true

end



-- ============================================================================

-- Mana gem match functions

-- ============================================================================



local function conjure_gem_matches(context, state)

    if not state then return false end

    if state.in_combat then return false end

    if not state.conjure_gem_ready then return false end

    -- Only conjure if we don't already have a gem

    if state.mana_gem_available then return false end

    return true

end



local function use_mana_gem_matches(context, state)

    if not state then return false end

    if not state.in_combat then return false end

    if not state.use_mana_gem then return false end

    if not state.mana_gem_available then return false end

    if (state.mana_pct or 100) >= (state.mana_gem_threshold or 70) then return false end

    return true

end



-- ============================================================================

-- Execute functions

-- ============================================================================



local function execute_wand(context)

    local ok, result = pcall(leveling.execute_wand, context)

    return ok and (result == true) or false

end



local function frost_nova_execute()

    -- Frost Nova is a self-centered AoE, no target needed

    return try_cast(SPELLS.FrostNova, nil, "[LEVELING] Frost Nova")

end



local function conjure_gem_execute()

    -- Conjure the highest rank mana gem (spell resolution handled by spell exists check)

    for _, spell_id in ipairs(CONJURE_MANA_GEM_SPELLS) do

        if NS.spell_exists and NS.spell_exists(spell_id) then

            return try_cast(spell_id, NS.PLAYER_UNIT, "[LEVELING] Conjure Mana Gem")

        end

    end

    return false

end



local function use_mana_gem_execute()

    -- Try the highest rank gem first, fall back to lower ranks

    for _, item_id in ipairs(MANA_GEM_ITEM_IDS) do

        if safe_is_item_ready(item_id) then

            return safe_use_item(item_id)

        end

    end

    return false

end



-- ============================================================================

-- Strategies

-- ============================================================================



local strategies = {

    -- Out-of-combat buffs

    { name = "ArcaneIntellect",

      matches = arcane_intellect_matches,

      execute = function() return try_cast(SPELLS.ArcaneIntellect, NS.PLAYER_UNIT, "[LEVELING] Arcane Intellect") end },



    { name = "MageArmor",

      matches = mage_armor_matches,

      execute = function() return try_cast(SPELLS.MageArmor, NS.PLAYER_UNIT, "[LEVELING] Mage Armor") end },



    { name = "FrostArmor",

      matches = frost_armor_matches,

      execute = function() return try_cast(SPELLS.FrostArmor, NS.PLAYER_UNIT, "[LEVELING] Frost Armor") end },



    -- OOC: remove curses between pulls

    { name = "RemoveCurse",

      matches = remove_curse_matches,

      execute = function() return try_cast(SPELLS.RemoveCurse, NS.PLAYER_UNIT, "[LEVELING] Remove Curse") end },



    -- Pre-combat: conjure mana gem if missing

    { name = "ConjureManaGem",

      matches = conjure_gem_matches,

      execute = conjure_gem_execute },



    -- Pull / CC

    { name = "Polymorph",

      matches = polymorph_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.Polymorph, context.target, "[LEVELING] Polymorph") end },



    -- Combat utility

    { name = "Counterspell",

      matches = counterspell_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.Counterspell, context.target, "[LEVELING] Counterspell") end },



    -- Defensive

    { name = "ManaShield",

      matches = mana_shield_matches,

      execute = function() return try_cast(SPELLS.ManaShield, NS.PLAYER_UNIT, "[LEVELING] Mana Shield") end },



    { name = "IceBarrier",

      matches = ice_barrier_matches,

      execute = function() return try_cast(SPELLS.IceBarrier, NS.PLAYER_UNIT, "[LEVELING] Ice Barrier") end },



    { name = "WaterElemental",

      matches = water_elemental_matches,

      execute = function() return try_cast(SPELLS.WaterElemental, NS.PLAYER_UNIT, "[LEVELING] Water Elemental", { skip_range = true }) end },



    { name = "FrostNova",

      matches = frost_nova_matches,

      execute = frost_nova_execute },



    -- AoE: Cone of Cold (kite tool, before Blizzard)

    { name = "ConeOfCold",

      matches = cone_of_cold_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.ConeOfCold, context.target, "[LEVELING] Cone of Cold") end },



    -- Escape: Blink

    { name = "Blink",

      matches = blink_matches,

      execute = function() return try_cast(SPELLS.Blink, NS.PLAYER_UNIT, "[LEVELING] Blink") end },



    -- AoE

    { name = "Blizzard",

      matches = blizzard_matches,

      execute = function(context)
          if not context then return false end
          local t = context.target
          local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8
          if NS.cast_ground_aoe then return NS.cast_ground_aoe(SPELLS.Blizzard, t, r, 35, "[LEVELING] Blizzard") end
          local pos = t and NS.get_aoe_cast_position and NS.get_aoe_cast_position(NS.get_spell_id(SPELLS.Blizzard), t, r, 35)
          if pos and NS.try_cast_position then return NS.try_cast_position(SPELLS.Blizzard, pos, t, "[LEVELING] Blizzard") end
          return try_cast(SPELLS.Blizzard, t, "[LEVELING] Blizzard")
      end },



    -- Mana recovery

    { name = "Evocation",

      matches = evocation_matches,

      execute = function() return try_cast(SPELLS.Evocation, NS.PLAYER_UNIT, "[LEVELING] Evocation") end },



    -- Damage

    { name = "FireBlast",

      matches = fire_blast_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.FireBlast, context.target, "[LEVELING] Fire Blast") end },



    { name = "Fireball",

      matches = fireball_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.Fireball, context.target, "[LEVELING] Fireball") end },



    { name = "Scorch",

      matches = scorch_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.Scorch, context.target, "[LEVELING] Scorch") end },



    { name = "ArcaneMissiles",

      matches = arcane_missiles_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.ArcaneMissiles, context.target, "[LEVELING] Arcane Missiles") end },



    { name = "IceLance",

      matches = ice_lance_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.IceLance, context.target, "[LEVELING] Ice Lance") end },



    { name = "Frostbolt",

      matches = frostbolt_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.Frostbolt, context.target, "[LEVELING] Frostbolt") end },



    -- Mana recovery: use mana gem before resorting to wand

    { name = "UseManaGem",

      matches = use_mana_gem_matches,

      execute = use_mana_gem_execute },



    -- Wand fallback (threshold controlled by schema setting)

    { name = "Wand",

      matches = wand_matches,

      execute = execute_wand },

}



if NS.rotation_registry and NS.rotation_registry.register then

    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })

end

-- Mage leveling rotation registered

return { strategies = strategies, build_state = build_state }