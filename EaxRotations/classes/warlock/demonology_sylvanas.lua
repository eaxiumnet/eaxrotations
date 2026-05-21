-- Warlock Demonology priority list.
-- ============================================================================
-- What: TBC Warlock Demonology priority list with pet, survivability, and spell readiness tracking
-- When: Per tick
-- Why: Demonology priorities depend on cached pet state and defensive readiness
-- Safety: Pet access uses pcall; helper checks are nil-guarded; conservative defaults when state is missing
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local CURSE_OF_DOOM_DEBUFF = { 30910, 603 }
local CORRUPTION_DEBUFF = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local IMMOLATE_DEBUFF = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local FEL_ARMOR_BUFF = { 28189, 28176 }
local PET_LOW_HP = 30

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

    demo_state.has_fel_armor = me and NS.buff_up(me, FEL_ARMOR_BUFF) or false
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
    demo_state.fel_domination_ready = me and NS.spell_ready(SPELLS.FelDomination, me, { skip_range = true, expected_cooldown = 900000 }) or false
    demo_state.soulshatter_ready = me and NS.spell_ready(SPELLS.Soulshatter, me, { skip_range = true, expected_cooldown = 300 }) or false
    demo_state.incinerate_ready = target and NS.spell_ready(SPELLS.Incinerate, target, { expected_cooldown = 2.5 }) or false

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
    local ok, has_pet = pcall(function() return me:has_pet() end)
    if not ok then
        if _G.izi and _G.izi.pet then
            local pet = _G.izi.pet()
            if not (pet and pet:is_valid()) then
                return NS.action_matches(context, action)
            end
        end
        return false
    end
    if not has_pet then
        return NS.action_matches(context, action)
    end
    return false
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
    return NS.action_matches(context, action)
end

-- ============================================================================
-- Match functions
-- ============================================================================
local function curse_of_doom_matches(context, s)
    if not context.target then return false end
    if not s.curse_of_doom_ready then return false end
    return NS.action_matches(context, { name = "CurseOfDoom", spell = SPELLS.CurseOfDoom, debuff = CURSE_OF_DOOM_DEBUFF, refresh = 5, cooldown = 60, min_ttd = 62, require_ttd = true, target_not_player = true })
end

local function corruption_matches(context, s)
    if not context.target then return false end
    if not s.corruption_ready then return false end
    return NS.action_matches(context, { name = "Corruption", spell = SPELLS.Corruption, debuff = CORRUPTION_DEBUFF, refresh = 1.5 })
end

local function immolate_matches(context, s)
    if not context.target then return false end
    if not s.immolate_ready then return false end
    return NS.action_matches(context, { name = "Immolate", spell = SPELLS.Immolate, debuff = IMMOLATE_DEBUFF, refresh = 1.5, not_moving = true })
end

local function life_tap_matches(context, s)
    if s.hp_pct <= 55 then return false end
    if s.mana_pct >= 65 then return false end
    if not s.life_tap_ready then return false end
    return NS.action_matches(context, { name = "LifeTap", spell = SPELLS.LifeTap, target = "self", requires_target = false })
end

local function shadow_bolt_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.shadow_bolt_ready then return false end
    return NS.action_matches(context, { name = "ShadowBolt", spell = SPELLS.ShadowBolt, not_moving = true })
end

local function seed_of_corruption_matches(context, s)
    if not context.target then return false end
    if s.enemy_count < 3 then return false end
    if not s.seed_of_corruption_ready then return false end
    return NS.action_matches(context, { name = "SeedOfCorruption", spell = SPELLS.SeedOfCorruption })
end

local function howl_of_terror_matches(context, s)
    if not context.in_combat then return false end
    if s.enemy_count < 3 then return false end
    if not s.howl_of_terror_ready then return false end
    return NS.action_matches(context, { name = "HowlofTerror", spell = SPELLS.HowlofTerror })
end

local function shadow_ward_matches(context, s)
    if not s.shadow_ward_ready then return false end
    return NS.action_matches(context, { name = "ShadowWard", spell = SPELLS.ShadowWard, target = "self", requires_target = false })
end

local function siphon_life_matches(context, s)
    if not context.target then return false end
    if not s.siphon_life_ready then return false end
    return NS.action_matches(context, { name = "SiphonLife", spell = SPELLS.SiphonLife })
end

local function fel_domination_matches(context, s)
    if context.in_combat then return false end
    if s.has_pet then return false end
    if not s.fel_domination_ready then return false end
    return NS.action_matches(context, { name = "FelDomination", spell = SPELLS.FelDomination, target = "self", requires_target = false })
end

local function soulshatter_matches(context, s)
    if not context.in_combat then return false end
    if not s.soulshatter_ready then return false end
    return NS.action_matches(context, { name = "Soulshatter", spell = SPELLS.Soulshatter, target = "self", requires_target = false })
end

local function incinerate_matches(context, s)
    if not context.target then return false end
    if context.is_moving then return false end
    if not s.incinerate_ready then return false end
    return NS.action_matches(context, { name = "Incinerate", spell = SPELLS.Incinerate, not_moving = true })
end

local function fel_armor_matches(context, s)
    if s.has_fel_armor then return false end
    return NS.action_matches(context, { name = "FelArmor", spell = SPELLS.FelArmor, target = "self", kind = "buff", buff = FEL_ARMOR_BUFF, requires_target = false })
end

local function health_funnel_matches(context, s)
    if not pet_needs_healing(context) then return false end
    return NS.action_matches(context, { name = "HealthFunnel", spell = SPELLS.HealthFunnel, target = "self", requires_target = false })
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "FelArmor", matches = fel_armor_matches, execute = function(context) return NS.action_execute(context, { name = "FelArmor", spell = SPELLS.FelArmor, target = "self", kind = "buff", buff = FEL_ARMOR_BUFF, requires_target = false }, "[DEMONOLOGY]") end },
    { name = "SummonFelguard", matches = function(context) return needs_felguard(context, { name = "SummonFelguard", spell = SPELLS.SummonFelguard }) end, execute = function(context) return NS.action_execute(context, { name = "SummonFelguard", spell = SPELLS.SummonFelguard }, "[DEMONOLOGY]") end },
    { name = "FelDomination", matches = fel_domination_matches, execute = function(context) return NS.action_execute(context, { name = "FelDomination", spell = SPELLS.FelDomination, target = "self", requires_target = false }, "[DEMONOLOGY]") end },
    { name = "HealthFunnel", matches = health_funnel_matches, execute = function(context) return NS.action_execute(context, { name = "HealthFunnel", spell = SPELLS.HealthFunnel, target = "self", requires_target = false }, "[DEMONOLOGY]") end },
    { name = "CurseOfDoom", matches = curse_of_doom_matches, execute = function(context) return NS.action_execute(context, { name = "CurseOfDoom", spell = SPELLS.CurseOfDoom, debuff = CURSE_OF_DOOM_DEBUFF, refresh = 5, cooldown = 60, min_ttd = 62, require_ttd = true, target_not_player = true }, "[DEMONOLOGY]") end },
    { name = "Corruption", matches = corruption_matches, execute = function(context) return NS.action_execute(context, { name = "Corruption", spell = SPELLS.Corruption, debuff = CORRUPTION_DEBUFF, refresh = 1.5 }, "[DEMONOLOGY]") end },
    { name = "Immolate", matches = immolate_matches, execute = function(context) return NS.action_execute(context, { name = "Immolate", spell = SPELLS.Immolate, debuff = IMMOLATE_DEBUFF, refresh = 1.5, not_moving = true }, "[DEMONOLOGY]") end },
    { name = "SiphonLife", matches = siphon_life_matches, execute = function(context) return NS.action_execute(context, { name = "SiphonLife", spell = SPELLS.SiphonLife }, "[DEMONOLOGY]") end },
    { name = "SeedOfCorruption", matches = seed_of_corruption_matches, execute = function(context) return NS.action_execute(context, { name = "SeedOfCorruption", spell = SPELLS.SeedOfCorruption }, "[DEMONOLOGY]") end },
    { name = "DeathCoil", matches = function(context) return death_coil_matches(context, { name = "DeathCoil", spell = SPELLS.DeathCoil }) end, execute = function(context) return NS.action_execute(context, { name = "DeathCoil", spell = SPELLS.DeathCoil }, "[DEMONOLOGY]") end },
    { name = "LifeTap", matches = life_tap_matches, execute = function(context) return NS.action_execute(context, { name = "LifeTap", spell = SPELLS.LifeTap, target = "self", requires_target = false }, "[DEMONOLOGY]") end },
    { name = "ShadowWard", matches = shadow_ward_matches, execute = function(context) return NS.action_execute(context, { name = "ShadowWard", spell = SPELLS.ShadowWard, target = "self", requires_target = false }, "[DEMONOLOGY]") end },
    { name = "HowlofTerror", matches = howl_of_terror_matches, execute = function(context) return NS.action_execute(context, { name = "HowlofTerror", spell = SPELLS.HowlofTerror }, "[DEMONOLOGY]") end },
    { name = "Soulshatter", matches = soulshatter_matches, execute = function(context) return NS.action_execute(context, { name = "Soulshatter", spell = SPELLS.Soulshatter, target = "self", requires_target = false }, "[DEMONOLOGY]") end },
    { name = "ShadowBolt", matches = shadow_bolt_matches, execute = function(context) return NS.action_execute(context, { name = "ShadowBolt", spell = SPELLS.ShadowBolt, not_moving = true }, "[DEMONOLOGY]") end },
    { name = "Incinerate", matches = incinerate_matches, execute = function(context) return NS.action_execute(context, { name = "Incinerate", spell = SPELLS.Incinerate, not_moving = true }, "[DEMONOLOGY]") end },
}

NS.rotation_registry:register("demonology", strategies, { get_state = build_state })
NS.log("Demonology rotation registered (Tier A)")
return strategies
