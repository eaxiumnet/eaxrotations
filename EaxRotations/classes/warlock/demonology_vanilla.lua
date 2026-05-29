-- Warlock Demonology priority list.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local CURSE_OF_DOOM_DEBUFF = { 603 }
local CORRUPTION_DEBUFF = { 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local IMMOLATE_DEBUFF = { 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local DEMON_ARMOR_BUFF = { 11735, 11734, 11733, 1086, 706 }
local PET_LOW_HP = 30

local DOT_REFRESH_WINDOW = 1.5

-- ============================================================================
-- State builder
-- ============================================================================
local demo_state = {
    has_demon_armor = false,
    has_pet = false,
    pet_hp_pct = 100,
    hp_pct = 100,
    mana_pct = 100,
    enemy_count = 1,
    target_casting = false,
    demon_armor_ready = false,
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
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target

    demo_state.has_demon_armor = me and NS.buff_up and NS.buff_up(me, DEMON_ARMOR_BUFF) or false
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
    demo_state.demon_armor_ready = me and NS.spell_ready(SPELLS.DemonArmor, me, { skip_range = true }) or false
    demo_state.curse_of_doom_ready = target and NS.spell_ready(SPELLS.CurseOfDoom, target, { expected_cooldown = 60 }) or false
    demo_state.corruption_ready = target and NS.spell_ready(SPELLS.Corruption, target) or false
    demo_state.immolate_ready = target and NS.spell_ready(SPELLS.Immolate, target, { expected_cooldown = 1.5 }) or false
    demo_state.life_tap_ready = me and NS.spell_ready(SPELLS.LifeTap, me, { skip_range = true }) or false
    demo_state.death_coil_ready = target and NS.spell_ready(SPELLS.DeathCoil, target, { expected_cooldown = 120 }) or false
    demo_state.shadow_bolt_ready = target and NS.spell_ready(SPELLS.ShadowBolt, target, { expected_cooldown = 2.5 }) or false
    demo_state.seed_of_corruption_ready = false
    demo_state.howl_of_terror_ready = me and NS.spell_ready(SPELLS.HowlofTerror, me, { skip_range = true, expected_cooldown = 40 }) or false
    demo_state.shadow_ward_ready = me and NS.spell_ready(SPELLS.ShadowWard, me, { skip_range = true, expected_cooldown = 30 }) or false
    demo_state.siphon_life_ready = target and NS.spell_ready(SPELLS.SiphonLife, target, { expected_cooldown = 1.5 }) or false
    demo_state.fel_domination_ready = me and NS.spell_ready(SPELLS.FelDomination, me, { skip_range = true, expected_cooldown = 900 }) or false
    demo_state.soulshatter_ready = false
    demo_state.incinerate_ready = false

    return demo_state
end

-- ============================================================================
-- Custom match functions (test assertions depend on these)
-- ============================================================================
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

-- ============================================================================
-- Match functions
-- ============================================================================
local function curse_of_doom_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.CurseOfDoom, 2.0) then return false end
    if not context.target then return false end
    if not s.curse_of_doom_ready then return false end
    return true
end

local function corruption_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Corruption, 2.0) then return false end
    if not context.target then return false end
    if not s.corruption_ready then return false end
    if NS.debuff_remains(context.target, CORRUPTION_DEBUFF) > DOT_REFRESH_WINDOW then return false end
    return true
end

local function immolate_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Immolate, 2.0) then return false end
    if not context.target then return false end
    if not s.immolate_ready then return false end
    if NS.debuff_remains(context.target, IMMOLATE_DEBUFF) > DOT_REFRESH_WINDOW then return false end
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
    return false
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
    return true
end

local function fel_domination_matches(context, s)
    if context.in_combat then return false end
    if s.has_pet then return false end
    if not s.fel_domination_ready then return false end
    return true
end

local function soulshatter_matches(context, s)
    return false
end

local function incinerate_matches(context, s)
    return false
end

local function demon_armor_matches(context, s)
    if not s then return false end
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.DemonArmor, 3.0) then return false end
    if s.has_demon_armor then return false end
    return s.demon_armor_ready == true
end

local function health_funnel_matches(context, s)
    if not pet_needs_healing(context) then return false end
    return true
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "DemonArmor", matches = demon_armor_matches, execute = function(context) return NS.try_cast(SPELLS.DemonArmor, context.me, "[DEMONOLOGY] Demon Armor", { skip_range = true }) end },
    { name = "FelDomination", matches = fel_domination_matches, execute = function(context) return NS.try_cast(SPELLS.FelDomination, context.me, "[DEMONOLOGY] Fel Domination", { skip_range = true, expected_cooldown = 900 }) end },
    { name = "HealthFunnel", matches = health_funnel_matches, execute = function(context) return NS.try_cast(SPELLS.HealthFunnel, context.pet or context.me, "[DEMONOLOGY] Health Funnel") end },
    { name = "CurseOfDoom", matches = curse_of_doom_matches, execute = function(context) return NS.try_cast(SPELLS.CurseOfDoom, context.target, "[DEMONOLOGY] Curse of Doom", { expected_cooldown = 60 }) end },
    { name = "Corruption", matches = corruption_matches, execute = function(context) return NS.try_cast(SPELLS.Corruption, context.target, "[DEMONOLOGY] Corruption") end },
    { name = "Immolate", matches = immolate_matches, execute = function(context) return NS.try_cast(SPELLS.Immolate, context.target, "[DEMONOLOGY] Immolate") end },
    { name = "SiphonLife", matches = siphon_life_matches, execute = function(context) return NS.try_cast(SPELLS.SiphonLife, context.target, "[DEMONOLOGY] Siphon Life") end },
    { name = "UnavailableClassicWarlockAoe", matches = seed_of_corruption_matches, execute = function(context) return NS.try_cast(SPELLS.UnavailableClassicWarlockAoe, context.target, "[DEMONOLOGY] Seed of Corruption") end },
    { name = "DeathCoil", matches = function(context) return death_coil_matches(context, { name = "DeathCoil", spell = SPELLS.DeathCoil }) end, execute = function(context) return NS.try_cast(SPELLS.DeathCoil, context.target, "[DEMONOLOGY] Death Coil", { expected_cooldown = 120 }) end },
    { name = "LifeTap", matches = life_tap_matches, execute = function(context) return NS.try_cast(SPELLS.LifeTap, context.me, "[DEMONOLOGY] Life Tap", { skip_range = true }) end },
    { name = "ShadowWard", matches = shadow_ward_matches, execute = function(context) return NS.try_cast(SPELLS.ShadowWard, context.me, "[DEMONOLOGY] Shadow Ward", { skip_range = true, expected_cooldown = 30 }) end },
    { name = "HowlofTerror", matches = howl_of_terror_matches, execute = function(context) return NS.try_cast(SPELLS.HowlofTerror, context.me, "[DEMONOLOGY] Howl of Terror", { skip_range = true, expected_cooldown = 40 }) end },
    { name = "UnavailableClassicWarlockThreat", matches = soulshatter_matches, execute = function(context) return NS.try_cast(SPELLS.UnavailableClassicWarlockThreat, context.me, "[DEMONOLOGY] UnavailableClassicWarlockThreat", { skip_range = true }) end },
    { name = "ShadowBolt", matches = shadow_bolt_matches, execute = function(context) return NS.try_cast(SPELLS.ShadowBolt, context.target, "[DEMONOLOGY] Shadow Bolt") end },
    { name = "UnavailableClassicWarlockNuke", matches = incinerate_matches, execute = function(context) return NS.try_cast(SPELLS.UnavailableClassicWarlockNuke, context.target, "[DEMONOLOGY] UnavailableClassicWarlockNuke") end },
}

NS.rotation_registry:register("demonology", strategies, { get_state = build_state })
NS.log("Demonology rotation registered (Tier A)")
return strategies

