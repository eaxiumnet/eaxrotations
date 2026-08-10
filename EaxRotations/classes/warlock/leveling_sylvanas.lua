-- leveling_sylvanas -- warlock leveling_sylvanas rotation for TBC Anniversary (2.5.5).

-- WHAT:  priority-list strategies for leveling_sylvanas gameplay.

-- WHEN:  combat with valid enemy target.

-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.

-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no manual nil-guards; no on_update() allocs.



-- Warlock leveling priority list.

-- Designed for solo/leveling play, from level 1 to 70.

-- Handles unlearned spells gracefully via NS.spell_ready checks.

-- Uses wand/Shoot as fallback when out of mana.



local NS = _G.EaxRotations

if not NS then return nil end

local leveling = require("shared/leveling_sylvanas")

if not leveling then return nil end

local SPELLS = NS.WarlockSpells or {}

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_action_for_class(SPELLS)



-- ============================================================================

-- Constants

-- ============================================================================



local FEL_ARMOR_BUFF = { 28189, 28176 }

local DEATH_COIL_IDS = { 27223, 17926, 17925, 6789 }

local FEAR_IDS = { 6215, 6213, 5782 }

local DRAIN_SOUL_IDS = { 27217, 11675, 8289, 8288, 1120 }

local CORRUPTION_IDS = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }

local IMMOLATE_IDS = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }

local CURSE_OF_AGONY_IDS = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }

local HEALTH_FUNNEL_IDS = { 27259, 11695, 11694, 11693, 755, 3699, 3700 }

local DRAIN_LIFE_IDS = { 27220, 27219, 11700, 11699, 7651, 709, 699, 689 }



local WAND_SPELL_ID = leveling.WAND_SPELL_ID or 5019

local DEMONIC_SACRIFICE_AURA_ALL = { 18789, 18790, 18791, 18792, 35701 }



local EMPTY_SETTINGS = {}



-- ============================================================================

-- Safe API wrappers (pcall-protected against nil/throwing NS functions)

-- ============================================================================



local function safe_buff_up(unit, buff_ids)

    if not unit or not NS.buff_up then return false end

    local ok, result = pcall(NS.buff_up, unit, buff_ids)

    return ok and result

end



local function safe_is_spell_ready(spell_ids, target, opts)

    if not NS.spell_ready then return false end

    local ok, ready = pcall(NS.spell_ready, spell_ids, target, opts)

    return ok and ready

end



local function safe_debuff_remains(unit, debuff_ids)

    if not unit or not NS.debuff_remains then return 0 end

    local ok, remains = pcall(NS.debuff_remains, unit, debuff_ids)

    if not ok or not remains then return 0 end

    return remains

end

local leveling_state = {}



-- ============================================================================

-- Context guard

-- ============================================================================



local function leveling_context_allowed(context)

    if not context then return false end

    if context.is_solo == true or context.is_leveling == true then return true end

    -- Also allow if user explicitly selected leveling playstyle

    return spec_kit.setting(context, "playstyle", "") == "leveling" or spec_kit.setting(context, "active_playstyle", "") == "leveling"

end



-- ============================================================================

-- State builder

-- ============================================================================



local _last_build_state_time = -1

local function build_state(context)

    if not context then return nil end

    -- Pattern 6: frame-keyed dedup

    local now = context.now or (NS.time_now and NS.time_now() or 0)

    -- Cache-hit branch MUST wrap in safe_state too (cache-hit audit 2026-08-10):
    -- a raw return lets nil-guard defaults leak as nil on frame-cache hits,
    -- the same family as the bear/cat bypass (6abb9039). Mirrors line 284.
    if now == _last_build_state_time then return spec_kit.safe_state(leveling_state) end

    if context.now then _last_build_state_time = now end

    local me = context.me

    local pet = context.pet



    leveling_state.has_fel_armor = safe_buff_up(me, FEL_ARMOR_BUFF)

    leveling_state.in_combat = context.in_combat or false

    leveling_state.mana_pct = context.mana_pct or 100

    leveling_state.hp = context.hp or 100

    leveling_state.enemies = context.enemies_count or 0

    leveling_state.target = context.target

    leveling_state.is_moving = context.is_moving or false

    leveling_state.pet = pet



    -- Settings from schema

    leveling_state.use_interrupt = spec_kit.setting_bool(context, "use_interrupt", true)

    leveling_state.wand_threshold = spec_kit.setting_number(context, "leveling_wand_threshold", 30)

    leveling_state.life_tap_mana = spec_kit.setting_number(context, "leveling_life_tap_mana", 30)

    leveling_state.drain_soul_execute = spec_kit.setting_number(context, "leveling_drain_soul_execute", 25)

    leveling_state.use_immolate = spec_kit.setting_bool(context, "leveling_use_immolate", true)

    leveling_state.use_corruption = spec_kit.setting_bool(context, "leveling_use_corruption", true)

    leveling_state.use_curse_of_agony = spec_kit.setting_bool(context, "leveling_use_curse_of_agony", true)

    leveling_state.drain_life_hp = spec_kit.setting_number(context, "leveling_drain_life_hp", 60)



    -- Spell readiness (each returns false if spell not learned)

    leveling_state.shadow_bolt_ready = safe_is_spell_ready(SPELLS.ShadowBolt, context.target)

    leveling_state.corruption_ready = safe_is_spell_ready(SPELLS.Corruption, context.target)

    leveling_state.immolate_ready = safe_is_spell_ready(SPELLS.Immolate, context.target)

    leveling_state.curse_of_agony_ready = safe_is_spell_ready(SPELLS.CurseOfAgony, context.target)

    leveling_state.life_tap_ready = safe_is_spell_ready(SPELLS.LifeTap, nil, { skip_range = true })

    leveling_state.fear_ready = safe_is_spell_ready(SPELLS.Fear, context.target)

    leveling_state.drain_soul_ready = safe_is_spell_ready(SPELLS.DrainSoul, context.target)

    leveling_state.death_coil_ready = safe_is_spell_ready(SPELLS.DeathCoil, context.target)

    leveling_state.health_funnel_ready = safe_is_spell_ready(SPELLS.HealthFunnel, nil, { skip_range = true })

    leveling_state.fel_armor_ready = safe_is_spell_ready(SPELLS.FelArmor, nil, { skip_range = true })

    leveling_state.healthstone_ready = safe_is_spell_ready(SPELLS.CreateHealthstone, nil, { skip_range = true })

    leveling_state.soulstone_ready = safe_is_spell_ready(SPELLS.CreateSoulstone, nil, { skip_range = true })

    leveling_state.spell_lock_ready = safe_is_spell_ready(SPELLS.SpellLock, context.target)

    leveling_state.howl_of_terror_ready = safe_is_spell_ready(SPELLS.HowlofTerror, nil, { skip_range = true })

    leveling_state.siphon_life_ready = safe_is_spell_ready(SPELLS.SiphonLife, context.target)

    leveling_state.drain_life_ready = safe_is_spell_ready(SPELLS.DrainLife, context.target)



    -- Summon spell readiness (highest rank first for resummon during combat)

    leveling_state.summon_felguard_ready = SPELLS.SummonFelguard and safe_is_spell_ready(SPELLS.SummonFelguard, nil, { skip_range = true }) or false

    leveling_state.summon_felhunter_ready = SPELLS.SummonFelhunter and safe_is_spell_ready(SPELLS.SummonFelhunter, nil, { skip_range = true }) or false

    leveling_state.summon_succubus_ready = SPELLS.SummonSuccubus and safe_is_spell_ready(SPELLS.SummonSuccubus, nil, { skip_range = true }) or false

    leveling_state.summon_voidwalker_ready = SPELLS.SummonVoidwalker and safe_is_spell_ready(SPELLS.SummonVoidwalker, nil, { skip_range = true }) or false

    leveling_state.summon_imp_ready = SPELLS.SummonImp and safe_is_spell_ready(SPELLS.SummonImp, nil, { skip_range = true }) or false



    -- Wand readiness

    leveling_state.wand_learned = NS.spell_exists and NS.spell_exists(WAND_SPELL_ID) or false



    -- Pet HP tracking

    if pet then

        local ok, pet_hp = pcall(function() return pet:get_health_percentage() end)

        leveling_state.pet_hp = ok and pet_hp or 100

    else

        leveling_state.pet_hp = 100

    end



    return spec_kit.safe_state(leveling_state)

end



-- ============================================================================

-- Match functions

-- ============================================================================



local function fel_armor_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if state.in_combat then return false end

    if state.has_fel_armor then return false end

    return state.fel_armor_ready

end



local function healthstone_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if state.in_combat then return false end

    return state.healthstone_ready

end



local function spell_lock_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.target then return false end

    if not state.use_interrupt then return false end

    local ok, casting = pcall(function() return state.target:is_casting() end)

    if not ok or not casting then return false end

    return state.spell_lock_ready

end



local function health_funnel_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.in_combat then return false end

    if not state.pet then return false end

    if (state.pet_hp or 100) > 50 then return false end

    if (state.hp or 100) < 40 then return false end  -- Don't kill self healing pet

    return state.health_funnel_ready

end



local function summon_pet_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if context.pet then return false end

    -- Do NOT summon if Demonic Sacrifice aura is already active

    local me = context.me

    if me and NS.buff_up and NS.buff_up(me, DEMONIC_SACRIFICE_AURA_ALL) then return false end

    -- Leveling: Imp is free (no shard) and gives Blood Pact stamina buff — prefer it first

    if state.summon_imp_ready then return true end

    -- Shard-costing pets (VW, Succubus, Felhunter, Felguard): require Soul Shard (6265) when OOC

    if not state.in_combat and not NS.has_item then return false end

    if not state.in_combat and NS.has_item and not NS.has_item(6265) then return false end

    -- Try remaining pets in order of leveling usefulness

    if state.summon_voidwalker_ready then return true end

    if state.summon_succubus_ready then return true end

    if state.summon_felhunter_ready then return true end

    if state.summon_felguard_ready then return true end

    return false

end



local function fear_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    -- Fear when overwhelmed (multiple enemies)

    if (state.enemies or 0) < 2 then return false end

    -- Don't re-fear if already feared

    local remains = safe_debuff_remains(state.target, FEAR_IDS)

    if remains > 8 then return false end

    return state.fear_ready

end



local function death_coil_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if (state.hp or 100) > 40 then return false end

    return state.death_coil_ready

end



local function life_tap_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.in_combat then return false end

    if (state.mana_pct or 100) > (state.life_tap_mana or 30) then return false end

    if (state.hp or 100) < 30 then return false end  -- Don't kill self

    return state.life_tap_ready

end



local function corruption_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.target then return false end

    if not state.use_corruption then return false end

    if not state.in_combat then return false end

    -- Refresh only if not active or about to expire

    local remains = safe_debuff_remains(state.target, CORRUPTION_IDS)

    if remains > 4 then return false end

    return state.corruption_ready

end



local function immolate_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.target then return false end

    if not state.use_immolate then return false end

    if not state.in_combat then return false end

    if state.is_moving then return false end

    -- Refresh only if not active or about to expire

    local remains = safe_debuff_remains(state.target, IMMOLATE_IDS)

    if remains > 4 then return false end

    return state.immolate_ready

end



local function curse_of_agony_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.target then return false end

    if not state.use_curse_of_agony then return false end

    if not state.in_combat then return false end

    -- Refresh only if not active or about to expire

    local remains = safe_debuff_remains(state.target, CURSE_OF_AGONY_IDS)

    if remains > 4 then return false end

    return state.curse_of_agony_ready

end



local function soulstone_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if state.in_combat then return false end

    return state.soulstone_ready

end



local function howl_of_terror_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.in_combat then return false end

    if not state.howl_of_terror_ready then return false end

    if (state.enemies or 0) < 3 then return false end

    if (state.hp or 100) > 40 then return false end

    return true

end



local function siphon_life_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if not state.siphon_life_ready then return false end

    local remains = safe_debuff_remains(state.target, SPELLS.SiphonLife)

    if remains > 4 then return false end

    return true

end



local function drain_life_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if not state.drain_life_ready then return false end

    if state.is_moving then return false end

    -- Only drain life when HP is below threshold

    if (state.hp or 100) > (state.drain_life_hp or 60) then return false end

    -- Don't drain if target is in execute range (Drain Soul handles that)

    local target_hp = 100

    if state.target then

        local ok, hp = pcall(function() return state.target:get_health_percentage() end)

        if ok and hp then target_hp = hp end

    end

    if target_hp <= (state.drain_soul_execute or 25) then return false end

    -- Don't drain if mana too low (keep reserve for Life Tap or wand)

    if (state.mana_pct or 100) < 10 then return false end

    return true

end



local function drain_soul_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    -- Use Drain Soul as execute or when low mana

    local target_hp = 100

    if state.target then

        local ok, hp = pcall(function() return state.target:get_health_percentage() end)

        if ok and hp then target_hp = hp end

    end

    if target_hp > (state.drain_soul_execute or 25) and (state.mana_pct or 100) > 30 then return false end

    return state.drain_soul_ready

end



local function shadow_bolt_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.target then return false end

    if not state.in_combat then return false end

    if state.is_moving then return false end

    if (state.mana_pct or 100) < 10 then return false end

    return state.shadow_bolt_ready

end



local function wand_matches(context, state)

    if not leveling_context_allowed(context) then return false end

    if not state then return false end

    if not state.target then return false end

    if not state.wand_learned then return false end

    if not state.in_combat then return false end

    if (state.mana_pct or 100) >= (state.wand_threshold or 30) then return false end

    return true

end



-- ============================================================================

-- Execute functions

-- ============================================================================



local function try_cast(spell_action, target, label, opts)

    if not NS.try_cast then return false end

    local ok, result = pcall(NS.try_cast, spell_action, target, label, opts)

    return ok and result == true

end



local function execute_wand(context)

    local ok, result = pcall(leveling.execute_wand, context)

    return ok and (result == true) or false

end



-- ============================================================================

-- Strategies

-- ============================================================================



local strategies = {

    -- Out-of-combat buffs

    { name = "FelArmor",

      matches = fel_armor_matches,

      execute = function() return try_cast(SPELLS.FelArmor, NS.PLAYER_UNIT, "[LEVELING] Fel Armor") end },



    { name = "CreateHealthstone",

      matches = healthstone_matches,

      execute = function() return try_cast(SPELLS.CreateHealthstone, NS.PLAYER_UNIT, "[LEVELING] Healthstone") end },



    -- OOC: Soulstone (self-buff, pre-death safety)

    { name = "CreateSoulstone",

      matches = soulstone_matches,

      execute = function() return try_cast(SPELLS.CreateSoulstone, NS.PLAYER_UNIT, "[LEVELING] Soulstone") end },



    -- Interrupt

    { name = "SpellLock",

      matches = spell_lock_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.SpellLock, context.target, "[LEVELING] Spell Lock") end },



    -- Pet sustain

    { name = "HealthFunnel",

      matches = health_funnel_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.HealthFunnel, context.pet, "[LEVELING] Health Funnel") end },



    -- Pet resummon: try Imp first (free, stamina buff), then shard pets by leveling usefulness

    { name = "SummonPet", matches = summon_pet_matches,

      execute = function(context)

        if not context then return false end

        if SPELLS.SummonImp and safe_is_spell_ready(SPELLS.SummonImp, nil, { skip_range = true }) then

            return try_cast(SPELLS.SummonImp, NS.PLAYER_UNIT, "[LEVELING] Summon Imp", { skip_range = true })

        end

        if SPELLS.SummonVoidwalker and safe_is_spell_ready(SPELLS.SummonVoidwalker, nil, { skip_range = true }) then

            return try_cast(SPELLS.SummonVoidwalker, NS.PLAYER_UNIT, "[LEVELING] Summon Voidwalker", { skip_range = true })

        end

        if SPELLS.SummonSuccubus and safe_is_spell_ready(SPELLS.SummonSuccubus, nil, { skip_range = true }) then

            return try_cast(SPELLS.SummonSuccubus, NS.PLAYER_UNIT, "[LEVELING] Summon Succubus", { skip_range = true })

        end

        if SPELLS.SummonFelhunter and safe_is_spell_ready(SPELLS.SummonFelhunter, nil, { skip_range = true }) then

            return try_cast(SPELLS.SummonFelhunter, NS.PLAYER_UNIT, "[LEVELING] Summon Felhunter", { skip_range = true })

        end

        if SPELLS.SummonFelguard and safe_is_spell_ready(SPELLS.SummonFelguard, nil, { skip_range = true }) then

            return try_cast(SPELLS.SummonFelguard, NS.PLAYER_UNIT, "[LEVELING] Summon Felguard", { skip_range = true })

        end

        return false

      end },



    -- CC / survival

    { name = "Fear",

      matches = fear_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.Fear, context.target, "[LEVELING] Fear") end },



    -- CC: Howl of Terror (AoE fear escape)

    { name = "HowlOfTerror",

      matches = howl_of_terror_matches,

      execute = function() return try_cast(SPELLS.HowlofTerror, nil, "[LEVELING] Howl of Terror") end },



    { name = "DeathCoil",

      matches = death_coil_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.DeathCoil, context.target, "[LEVELING] Death Coil") end },



    -- Mana

    { name = "LifeTap",

      matches = life_tap_matches,

      execute = function() return try_cast(SPELLS.LifeTap, NS.PLAYER_UNIT, "[LEVELING] Life Tap") end },



    -- DoTs

    { name = "Corruption",

      matches = corruption_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.Corruption, context.target, "[LEVELING] Corruption") end },



    { name = "Immolate",

      matches = immolate_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.Immolate, context.target, "[LEVELING] Immolate") end },



    { name = "CurseOfAgony",

      matches = curse_of_agony_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.CurseOfAgony, context.target, "[LEVELING] Curse of Agony") end },



    -- DoT: Siphon Life (damage + self-heal)

    { name = "SiphonLife",

      matches = siphon_life_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.SiphonLife, context.target, "[LEVELING] Siphon Life") end },



    -- Sustain: Drain Life (channeled damage + self-heal)

    { name = "DrainLife",

      matches = drain_life_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.DrainLife, context.target, "[LEVELING] Drain Life") end },



    -- Execute / low mana filler

    { name = "DrainSoul",

      matches = drain_soul_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.DrainSoul, context.target, "[LEVELING] Drain Soul") end },



    -- Main filler

    { name = "ShadowBolt",

      matches = shadow_bolt_matches,

      execute = function(context) if not context then return false end; return try_cast(SPELLS.ShadowBolt, context.target, "[LEVELING] Shadow Bolt") end },



    -- Wand fallback (threshold controlled by schema setting)

    { name = "Wand",

      matches = wand_matches,

      execute = execute_wand },

}



if NS.rotation_registry and NS.rotation_registry.register then

    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })

end

-- Warlock leveling rotation registered

return { strategies = strategies, build_state = build_state }