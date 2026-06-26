-- demonology_sylvanas -- warlock demonology_sylvanas rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies for demonology_sylvanas gameplay.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.
-- SAFETY: every state field read is nil-guarded via build_state() defaults; no on_update() allocs.

-- Warlock Demonology priority list.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}
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
local CURSE_OF_AGONY_DEBUFF = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }
local CURSE_OF_ELEMENTS_DEBUFF = { 27228, 11722, 11721, 1490 }
local PET_LOW_HP = 30
local EXECUTE_THRESHOLD = 25
local SOUL_SHARD_CAPTURE_TTD = 5  -- TBC: Drain Soul is shard-capture only (mob about to die); sub-25% execute is Wrath, not TBC

local DOT_REFRESH_WINDOW = 1.5

-- ============================================================================
-- State builder
-- ============================================================================
local demo_state = {
    has_fel_armor = false,
    has_pet = false,
    pet_hp_pct = 100,
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
    dark_pact_ready = false,
    drain_soul_ready = false,
    soul_link_ready = false,
    has_soul_link = false,
    target_hp_pct = 100,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target

    demo_state.has_fel_armor = me and NS.buff_up and NS.buff_up(me, FEL_ARMOR_BUFF) or false
    demo_state.has_pet = false
    demo_state.pet_hp_pct = 100
    if me then
        local ok, has_pet = pcall(function() return me:has_pet() end)
        demo_state.has_pet = ok and has_pet or false
        if demo_state.has_pet then
            local ok_pet, pet = pcall(function() return me:get_pet() end)
            if ok_pet and pet and pet:is_valid() then
                demo_state.pet_hp_pct = pet.get_health_percentage and pet:get_health_percentage() or 100
            end
        end
    end
    demo_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    demo_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    demo_state.enemy_count = context.enemy_count or context.enemies_count or 1
    demo_state.target_casting = target and target.is_casting and target:is_casting() or false
    demo_state.fel_armor_ready = me and NS.spell_ready(SPELLS.FelArmor, me, { skip_range = true }) or false
    demo_state.curse_of_doom_ready = target and NS.spell_ready(SPELLS.CurseOfDoom, target, { expected_cooldown = 60 }) or false
    demo_state.corruption_ready = target and NS.spell_ready(SPELLS.Corruption, target) or false
    demo_state.immolate_ready = target and NS.spell_ready(SPELLS.Immolate, target, { expected_cooldown = 1.5 }) or false
    demo_state.life_tap_ready = me and NS.spell_ready(SPELLS.LifeTap, me, { skip_range = true }) or false
    demo_state.death_coil_ready = target and NS.spell_ready(SPELLS.DeathCoil, target, { expected_cooldown = 120 }) or false
    demo_state.shadow_bolt_ready = target and NS.spell_ready(SPELLS.ShadowBolt, target, { expected_cooldown = 2.5 }) or false
    demo_state.seed_of_corruption_ready = target and NS.spell_ready(SPELLS.SeedOfCorruption, target, { expected_cooldown = 1.5 }) or false
    demo_state.howl_of_terror_ready = me and NS.spell_ready(SPELLS.HowlofTerror, me, { skip_range = true, expected_cooldown = 40 }) or false
    demo_state.shadow_ward_ready = me and NS.spell_ready(SPELLS.ShadowWard, me, { skip_range = true, expected_cooldown = 30 }) or false
    demo_state.siphon_life_ready = target and NS.spell_ready(SPELLS.SiphonLife, target, { expected_cooldown = 1.5 }) or false
    demo_state.fel_domination_ready = me and NS.spell_ready(SPELLS.FelDomination, me, { skip_range = true, expected_cooldown = 900 }) or false
    demo_state.soulshatter_ready = me and NS.cooldown_remains(SPELLS.Soulshatter, 300) <= 0 and NS.spell_ready(SPELLS.Soulshatter, me, { skip_range = true }) or false
    demo_state.incinerate_ready = target and NS.spell_ready(SPELLS.Incinerate, target, { expected_cooldown = 2.5 }) or false
    demo_state.soul_fire_ready = target and NS.spell_ready(SPELLS.SoulFire, target, { expected_cooldown = 1.5 }) or false
    demo_state.fear_ready = target and NS.spell_ready(SPELLS.Fear, target) or false
    demo_state.rain_of_fire_ready = target and NS.spell_ready(SPELLS.RainOfFire, target, { expected_cooldown = 1.5 }) or false
    demo_state.hellfire_ready = me and NS.spell_ready(SPELLS.Hellfire, me, { skip_range = true }) or false
    demo_state.curse_of_agony_ready = target and NS.spell_ready(SPELLS.CurseOfAgony, target) or false
    demo_state.curse_of_elements_ready = target and NS.spell_ready(SPELLS.CurseElements, target) or false
    demo_state.dark_pact_ready = me and NS.spell_ready(SPELLS.DarkPact, me, { skip_range = true, expected_cooldown = 10 }) or false
    demo_state.drain_soul_ready = target and NS.spell_ready(SPELLS.DrainSoul, target) or false
    demo_state.soul_link_ready = me and NS.spell_ready(25228, me, { skip_range = true }) or false
    demo_state.has_soul_link = me and NS.buff_up and NS.buff_up(me, SOUL_LINK_BUFF) or false
    demo_state.target_hp_pct = target and target.get_health_percentage and target:get_health_percentage() or 100

    return demo_state
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
        if _G.izi and _G.izi.pet then
            local pet = _G.izi.pet()
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
        if _G.izi and _G.izi.pet then
            local pet = _G.izi.pet()
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
        if _G.izi and _G.izi.pet then
            pet = _G.izi.pet()
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

-- ============================================================================
-- Match functions
-- ============================================================================
local function curse_of_doom_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.CurseOfDoom, 2.0) then return false end
    if not context.target then return false end
    if not s.curse_of_doom_ready then return false end
    -- TTD gate: Curse of Doom has 60s CD and 60s DoT — only use on long-lived targets
    if context.ttd_known and context.ttd > 0 and context.ttd < 62 then return false end
    return true
end

local function corruption_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Corruption, 2.0) then return false end
    if not context.target then return false end
    if not s.corruption_ready then return false end
    if NS.debuff_remains(context.target, CORRUPTION_DEBUFF) > DOT_REFRESH_WINDOW then return false end
    -- TTD gate: skip long DoT if target will die before it pays off (18s base)
    if context.ttd_known and context.ttd > 0 and context.ttd < 4 then return false end
    return true
end

local function immolate_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Immolate, 2.0) then return false end
    if not context.target then return false end
    if not s.immolate_ready then return false end
    if NS.debuff_remains(context.target, IMMOLATE_DEBUFF) > DOT_REFRESH_WINDOW then return false end
    -- TTD gate: skip casted DoT if target will die before it pays off (15s base + 2s cast)
    if context.ttd_known and context.ttd > 0 and context.ttd < 5 then return false end
    return true
end

local function life_tap_matches(context, s)
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
    if (s.enemy_count or 0) < 3 then return false end
    if not s.seed_of_corruption_ready then return false end
    return true
end

local function howl_of_terror_matches(context, s)
    if not s then return false end
    if not context.in_combat then return false end
    if (s.enemy_count or 0) < 3 then return false end
    if not s.howl_of_terror_ready then return false end
    return true
end

local function shadow_ward_matches(context, s)
    if not s.shadow_ward_ready then return false end
    return true
end

local function siphon_life_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.SiphonLife, 2.0) then return false end
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
    if NS.cooldown_remains(SPELLS.Soulshatter, 300) > 0 then return false end
    return NS.spell_ready(SPELLS.Soulshatter, me, { skip_range = true })
end

local function incinerate_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.incinerate_ready then return false end
    return true
end

local function fel_armor_matches(context, s)
    if not s then return false end
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.FelArmor, 3.0) then return false end
    if s.has_fel_armor then return false end
    return s.fel_armor_ready == true
end

local function soul_fire_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.SoulFire, 2.0) then return false end
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
    if not context.is_pvp then return false end
    return true
end

local function rain_of_fire_matches(context, s)
    if not s then return false end
    if not context.target then return false end
    if (s.enemy_count or 0) < 3 then return false end
    if not s.rain_of_fire_ready then return false end
    return true
end

local function hellfire_matches(context, s)
    if not s then return false end
    if not context.in_combat then return false end
    if (s.enemy_count or 0) < 4 then return false end
    if (s.hp_pct or 100) < 40 then return false end
    if not s.hellfire_ready then return false end
    return true
end

local function curse_of_agony_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.CurseOfAgony, 2.0) then return false end
    if not s then return false end
    if not context.target then return false end
    if not s.curse_of_agony_ready then return false end
    if NS.debuff_remains(context.target, CURSE_OF_AGONY_DEBUFF) > DOT_REFRESH_WINDOW then return false end
    if (s.target_hp_pct or 100) < EXECUTE_THRESHOLD then return false end
    return true
end

local function curse_of_elements_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.CurseElements, 2.0) then return false end
    if not s then return false end
    if not context.target then return false end
    if not s.curse_of_elements_ready then return false end
    if NS.debuff_remains(context.target, CURSE_OF_ELEMENTS_DEBUFF) > DOT_REFRESH_WINDOW then return false end
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
    -- channel and yields a Soul Shard. Drain Soul ~62 dps vs Shadow Bolt
    -- ~250 dps, so channeling it for DPS is a large loss.
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

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    -- Auto Damage Potion — gate on context.has_damage_potion (inventory_helper)
    { name = "DamagePotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_damage_potion then return false end
          if not context.should_burst then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.DAMAGE_POTION_IDS) end },
    -- Pet State: set defensive when pet HP is critically low
    { name = "PetDefensive",
      matches = function(context, state)
          if not state.has_pet then return false end
          if not (context.in_combat or state.in_combat) then return false end
          if (state.pet_hp_pct or 100) > 35 then return false end
          return true
      end,
      execute = function() return pet_manager.set_defensive() end },
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
    { name = "FelArmor", matches = fel_armor_matches, execute = function(context) return NS.try_cast(SPELLS.FelArmor, context.me, "[DEMONOLOGY] Fel Armor", { skip_range = true }) end },
    { name = "SoulLink", matches = soul_link_matches, execute = function(context) return NS.try_cast(25228, context.me, "[DEMONOLOGY] Soul Link", { skip_range = true }) end },
    { name = "SummonFelguard", matches = function(context) return needs_felguard(context, { name = "SummonFelguard", spell = SPELLS.SummonFelguard }) end, execute = function(context) return NS.try_cast(SPELLS.SummonFelguard, context.me, "[DEMONOLOGY] Summon Felguard", { skip_range = true }) end },
    { name = "SummonImp", matches = function(context) return needs_imp_fallback(context) end, execute = function(context) return NS.try_cast(SPELLS.SummonImp, context.me, "[DEMONOLOGY] Summon Imp", { skip_range = true }) end },
    { name = "FelDomination", matches = fel_domination_matches, execute = function(context) return NS.try_cast(SPELLS.FelDomination, context.me, "[DEMONOLOGY] Fel Domination", { skip_range = true, expected_cooldown = 900 }) end },
    { name = "HealthFunnel", matches = health_funnel_matches, execute = function(context) return NS.try_cast(SPELLS.HealthFunnel, context.pet or context.me, "[DEMONOLOGY] Health Funnel") end },
    { name = "CurseOfDoom", matches = curse_of_doom_matches, execute = function(context) return NS.try_cast(SPELLS.CurseOfDoom, context.target, "[DEMONOLOGY] Curse of Doom", { expected_cooldown = 60 }) end },
    { name = "CurseOfElements", matches = curse_of_elements_matches, execute = function(context) return NS.try_cast(SPELLS.CurseElements, context.target, "[DEMONOLOGY] Curse of Elements") end },
    { name = "CurseOfAgony", matches = curse_of_agony_matches, execute = function(context) return NS.try_cast(SPELLS.CurseOfAgony, context.target, "[DEMONOLOGY] Curse of Agony") end },
    -- TBC guide order: Corruption > Immolate (higher DPCT, longer DoT) — apply Corruption first when both need refresh.
    { name = "Corruption", matches = corruption_matches, execute = function(context) return NS.try_cast(SPELLS.Corruption, context.target, "[DEMONOLOGY] Corruption") end },
    { name = "Immolate", matches = immolate_matches, execute = function(context) return NS.try_cast(SPELLS.Immolate, context.target, "[DEMONOLOGY] Immolate") end },
    { name = "SiphonLife", matches = siphon_life_matches, execute = function(context) return NS.try_cast(SPELLS.SiphonLife, context.target, "[DEMONOLOGY] Siphon Life") end },
    { name = "SeedOfCorruption", matches = seed_of_corruption_matches, execute = function(context) return NS.try_cast(SPELLS.SeedOfCorruption, context.target, "[DEMONOLOGY] Seed of Corruption") end },
    { name = "SoulFire", matches = soul_fire_matches, execute = function(context) return NS.try_cast(SPELLS.SoulFire, context.target, "[DEMONOLOGY] Soul Fire", { expected_cooldown = 1.5 }) end },
    { name = "DrainSoul", matches = drain_soul_matches, execute = function(context) return NS.try_cast(SPELLS.DrainSoul, context.target, "[DEMONOLOGY] Drain Soul") end },
    { name = "RainOfFire", matches = rain_of_fire_matches, execute = function(context) local t = context.target; local pos = t and NS.get_aoe_cast_position(NS.get_spell_id(SPELLS.RainOfFire), t, 8, 35); if pos then return NS.try_cast_position(SPELLS.RainOfFire, pos, t, "[DEMONOLOGY] Rain of Fire", { expected_cooldown = 1.5 }) end; return NS.try_cast(SPELLS.RainOfFire, t, "[DEMONOLOGY] Rain of Fire", { expected_cooldown = 1.5 }) end },
    { name = "Hellfire", matches = hellfire_matches, execute = function(context) return NS.try_cast(SPELLS.Hellfire, context.me, "[DEMONOLOGY] Hellfire", { skip_range = true }) end },
    { name = "DeathCoil", matches = function(context, state) return death_coil_matches(context, { name = "DeathCoil", spell = SPELLS.DeathCoil }) end, execute = function(context) return NS.try_cast(SPELLS.DeathCoil, context.target, "[DEMONOLOGY] Death Coil", { expected_cooldown = 120 }) end },
    { name = "LifeTap", matches = life_tap_matches, execute = function(context) return NS.try_cast(SPELLS.LifeTap, context.me, "[DEMONOLOGY] Life Tap", { skip_range = true }) end },
    { name = "DarkPact", matches = dark_pact_matches, execute = function(context) return NS.try_cast(SPELLS.DarkPact, context.me, "[DEMONOLOGY] Dark Pact", { skip_range = true, expected_cooldown = 10 }) end },
    { name = "ShadowWard", matches = shadow_ward_matches, execute = function(context) return NS.try_cast(SPELLS.ShadowWard, context.me, "[DEMONOLOGY] Shadow Ward", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "HowlofTerror", matches = howl_of_terror_matches, execute = function(context) return NS.try_cast(SPELLS.HowlofTerror, context.me, "[DEMONOLOGY] Howl of Terror", { skip_range = true, expected_cooldown = 40 }) end },
    { name = "Fear", matches = fear_matches, execute = function(context) return NS.try_cast(SPELLS.Fear, context.target, "[DEMONOLOGY] Fear") end },
    { name = "Soulshatter", matches = soulshatter_matches, execute = function(context) return NS.try_cast(SPELLS.Soulshatter, context.me, "[DEMONOLOGY] Soulshatter", { skip_range = true }) end },
    { name = "ShadowBolt", matches = shadow_bolt_matches, execute = function(context) return NS.try_cast(SPELLS.ShadowBolt, context.target, "[DEMONOLOGY] Shadow Bolt") end },
    { name = "Incinerate", matches = incinerate_matches, execute = function(context) return NS.try_cast(SPELLS.Incinerate, context.target, "[DEMONOLOGY] Incinerate") end },
}

NS.rotation_registry:register("demonology", strategies, { get_state = build_state })
NS.log("Demonology rotation registered")
return strategies

