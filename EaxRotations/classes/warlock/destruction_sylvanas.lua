-- Warlock Destruction priority list.

--
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}

-- Debuff and buff ID lists for state queries
local CURSE_OF_DOOM_DEBUFF = { 30910, 603 }
local CURSE_OF_AGONY_DEBUFF = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }
local IMMOLATE_DEBUFF = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local CORRUPTION_DEBUFF = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local BACKLASH_BUFF = { 34936, 34935 }
local FEL_ARMOR_BUFF = { 28189, 28176 }
local DEMON_ARMOR_BUFF = { 27260, 11735, 11734, 11733, 1086, 706, 687, 696 }
local SHADOW_WARD_BUFF = { 28610, 11740, 11739, 6229 }

-- Local spell actions for spells not exposed in NS.WarlockSpells
local DemonArmorSpell = NS.spell_action({ 27260, 11735, 11734, 11733, 1086, 706, 687 }, "DemonArmor")
local ShadowWardSpell = NS.spell_action({ 28610, 11740, 11739, 6229 }, "ShadowWard")
local DrainLife = NS.spell_action({ 27220, 27219, 11700, 11699, 7651, 709, 699, 689 }, "DrainLife")
local HealthFunnel = NS.spell_action({ 27259, 11695, 11694, 11693, 3700, 3699, 3698, 755 }, "HealthFunnel")
local DarkPact = NS.spell_action({ 27265, 18938, 18937, 18220 }, "DarkPact")
local SoulFire = NS.spell_action({ 30545, 27211, 17924, 6353 }, "SoulFire")
local SearingPain = NS.spell_action({ 30459, 27210, 17923, 17922, 17921, 17920, 17919, 5676 }, "SearingPain")
local Fear = NS.spell_action({ 5782, 6213, 6215 }, "Fear")
local RainOfFire = NS.spell_action({ 27212, 17954, 17953, 5740 }, "RainOfFire")
local Hellfire = NS.spell_action({ 27213, 11684, 11683, 1949 }, "Hellfire")
local SeedOfCorruption = NS.spell_action({ 27243 }, "SeedOfCorruption")
local CreateHealthstone = NS.spell_action({ 27230, 11730, 11729, 6202, 6201, 5699 }, "CreateHealthstone")
local SummonImp = NS.spell_action({ 688 }, "SummonImp")
local SummonVoidwalker = NS.spell_action({ 697 }, "SummonVoidwalker")
local SummonSuccubus = NS.spell_action({ 712 }, "SummonSuccubus")
local SummonFelhunter = NS.spell_action({ 691 }, "SummonFelhunter")
local SummonFelguard = NS.spell_action({ 30146 }, "SummonFelguard")
local FelDomination = NS.spell_action({ 18708, 18707, 18706 }, "FelDomination")

-- Constants
local IMMOLATE_PANDEMIC_WINDOW = 3.5
local SHADOWBURN_HP_PCT = 20
local DRAIN_LIFE_HP_THRESHOLD = 40
local MANA_LIFE_TAP_THRESHOLD = 35
local DARK_PACT_MANA_THRESHOLD = 45
local MANA_ITEM_IDS = { 20520, 12662 }  -- Dark Rune, Demonic Rune

-- build_state: compute per-update aura and timing state once for all strategies
local function build_state(context)
    local target = context.target
    local me = NS.GetPlayer()
    local state = {
        immolate_remains = target and NS.debuff_remains(target, IMMOLATE_DEBUFF) or 0,
        corruption_remains = target and NS.debuff_remains(target, CORRUPTION_DEBUFF) or 0,
        cod_remains = target and NS.debuff_remains(target, CURSE_OF_DOOM_DEBUFF) or 0,
        coa_remains = target and NS.debuff_remains(target, CURSE_OF_AGONY_DEBUFF) or 0,
        has_backlash = me and NS.buff_up(me, BACKLASH_BUFF) or false,
        has_backdraft = false,
        has_fel_armor = me and NS.buff_up(me, FEL_ARMOR_BUFF) or false,
        has_demon_armor = me and NS.buff_up(me, DEMON_ARMOR_BUFF) or false,
        has_shadow_ward = me and NS.buff_up(me, SHADOW_WARD_BUFF) or false,
        hp = context.hp or 100,
        mana_pct = context.mana_pct or 100,
        mana_gem_id = nil,
        mana_gem_ready = false,
    }
    -- Find ready mana item
    state.mana_gem_id = nil
    for _, id in ipairs(MANA_ITEM_IDS) do
        if NS.is_item_ready and NS.is_item_ready(id) then
            state.mana_gem_id = id
            break
        end
    end
    state.mana_gem_ready = state.mana_gem_id ~= nil
    return state
end

local ACTIONS = {
    -- Buffs / OOC
    { name = "FelArmor", spell = SPELLS.FelArmor, target = "self", kind = "buff", buff = FEL_ARMOR_BUFF, requires_target = false },
    { name = "DemonArmor", spell = DemonArmorSpell, target = "self", kind = "buff", buff = DEMON_ARMOR_BUFF, requires_target = false },
    { name = "ShadowWard", spell = ShadowWardSpell, target = "self", kind = "buff", buff = SHADOW_WARD_BUFF, requires_target = false, cooldown = 30 },
    { name = "CreateHealthstone", spell = CreateHealthstone, target = "self", ooc = true, requires_target = false },
    { name = "LifeTap", spell = SPELLS.LifeTap, target = "self", max_mana = 65, min_hp = 40, requires_target = false },
    { name = "DarkPact", spell = DarkPact, target = "self", max_mana = 55, requires_target = false },
    { name = "DrainLife", spell = DrainLife, not_moving = true, min_hp = 40 },
    { name = "HealthFunnel", spell = HealthFunnel, target = "pet", not_moving = true, min_hp = 60, requires_target = false },
    -- Curses (CurseOfDoom before Immolate per regression test)
    { name = "CurseOfDoom", spell = SPELLS.CurseOfDoom, debuff = CURSE_OF_DOOM_DEBUFF, refresh = 5, cooldown = 60, min_ttd = 62, require_ttd = true, target_not_player = true },
    { name = "CurseOfAgony", spell = SPELLS.CurseOfAgony, debuff = CURSE_OF_AGONY_DEBUFF, refresh = 3 },
    -- DoTs
    { name = "Corruption", spell = SPELLS.Corruption, debuff = CORRUPTION_DEBUFF, refresh = 3 },
    { name = "Immolate", spell = SPELLS.Immolate, debuff = IMMOLATE_DEBUFF, refresh = 3, not_moving = true },
    -- Burst / Procs
    { name = "BacklashShadowBolt", spell = SPELLS.ShadowBolt, priority = 100 },
    { name = "Conflagrate", spell = SPELLS.Conflagrate, moving = true, cooldown = 10 },
    { name = "SoulFire", spell = SoulFire, not_moving = true },
    { name = "Shadowburn", spell = SPELLS.Shadowburn, cooldown = 15 },
    { name = "SearingPain", spell = SearingPain, moving = true },
    -- Filler
    { name = "Incinerate", spell = SPELLS.Incinerate, not_moving = true },
    { name = "ShadowBolt", spell = SPELLS.ShadowBolt, not_moving = true },
    -- AoE
    { name = "SeedOfCorruption", spell = SeedOfCorruption, position = "target", enemy_count = 3 },
    { name = "RainOfFire", spell = RainOfFire, position = "target", enemy_count = 4, not_moving = true },
    { name = "Hellfire", spell = Hellfire, position = "self", enemy_count = 4, not_moving = true },
    -- CC / Emergency
    { name = "DeathCoil", spell = SPELLS.DeathCoil, max_hp = 35, cooldown = 120 },
    { name = "Fear", spell = Fear, cooldown = 15, target_not_player = true },
    -- Pet summons
    { name = "SummonImp", spell = SummonImp, target = "self", ooc = true, requires_target = false },
    { name = "SummonVoidwalker", spell = SummonVoidwalker, target = "self", ooc = true, requires_target = false },
    { name = "SummonSuccubus", spell = SummonSuccubus, target = "self", ooc = true, requires_target = false },
    { name = "SummonFelhunter", spell = SummonFelhunter, target = "self", ooc = true, requires_target = false },
    { name = "SummonFelguard", spell = SummonFelguard, target = "self", ooc = true, requires_target = false },
    { name = "FelDomination", spell = FelDomination, target = "self", cooldown = 900, requires_target = false },
}

local function immolate_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.immolate_remains > IMMOLATE_PANDEMIC_WINDOW then return false end
    if not NS.should_refresh_dot(state.immolate_remains, 1.5, context.ttd, 15) then return false end
    return NS.action_matches(context, action)
end

local function conflagrate_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.immolate_remains <= 0 then return false end
    return NS.action_matches(context, action)
end

local function shadowburn_matches(context, action, state)
    if NS.has_item and not NS.has_item(SOUL_SHARD_ITEM) then return false end
    local hp_threshold = (context.settings and context.settings.destro_shadowburn_hp) or SHADOWBURN_HP_PCT
    if not NS.is_execute_phase(context.target_hp, hp_threshold) then return false end
    return NS.action_matches(context, action)
end

local function curse_of_doom_matches(context, action, state)
    if not NS.should_use_long_cd(context, action.cooldown) then return false end
    if not state then return false end
    state = state or {}
    if state.cod_remains > 5 then return false end
    return NS.action_matches(context, action)
end

local function backlash_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if not state.has_backlash then return false end
    return NS.action_matches(context, action)
end

local function incinerate_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.immolate_remains <= 0 then return false end
    return NS.action_matches(context, action)
end

local function searing_pain_matches(context, action, state)
    return NS.action_matches(context, action)
end

local SOUL_SHARD_ITEM = 6265  -- TBC soul shard reagent

local function soul_fire_matches(context, action, state)
    if NS.has_item and not NS.has_item(SOUL_SHARD_ITEM) then return false end
    return NS.action_matches(context, action)
end

local function corruption_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.corruption_remains > 3 then return false end
    return NS.action_matches(context, action)
end

local function curse_of_agony_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.coa_remains > 3 then return false end
    if state.cod_remains > 0 then return false end
    return NS.action_matches(context, action)
end

local function drain_life_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.hp > DRAIN_LIFE_HP_THRESHOLD then return false end
    return NS.action_matches(context, action)
end

local function health_funnel_matches(context, action, state)
    local pet = NS.GetPet()
    if not pet then return false end
    if NS.unit_health_pct(pet) > 50 then return false end
    return NS.action_matches(context, action)
end

local function dark_pact_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.mana_pct > DARK_PACT_MANA_THRESHOLD then return false end
    return NS.action_matches(context, action)
end

local function fel_armor_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.has_fel_armor then return false end
    return NS.action_matches(context, action)
end

local function demon_armor_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.has_fel_armor then return false end
    if state.has_demon_armor then return false end
    return NS.action_matches(context, action)
end

local function shadow_ward_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.has_shadow_ward then return false end
    return NS.action_matches(context, action)
end

local function create_healthstone_matches(context, action, state)
    if NS.has_item and not NS.has_item(SOUL_SHARD_ITEM) then return false end
    if context.in_combat then return false end
    if context.has_valid_enemy_target then return false end
    return NS.action_matches(context, action)
end

local function life_tap_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.mana_pct > MANA_LIFE_TAP_THRESHOLD then return false end
    return NS.action_matches(context, action)
end

local function summon_pet_matches(context, action, state)
    if context.in_combat then return false end
    if context.has_valid_enemy_target then return false end
    local pet = NS.GetPet()
    if pet and NS.unit_alive(pet) then return false end
    return NS.action_matches(context, action)
end

local function death_coil_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if state.hp > 35 then return false end
    return NS.action_matches(context, action)
end

local function fear_matches(context, action, state)
    return NS.action_matches(context, action)
end

local function aoe_matches(context, action, state)
    if not NS.action_matches(context, action) then return false end
    if context.is_moving and action.not_moving then return false end
    return true
end

local strategies = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    local custom_matches
    if action.name == "Immolate" then
        custom_matches = function(context, state) return immolate_matches(context, action, state) end
    elseif action.name == "Conflagrate" then
        custom_matches = function(context, state) return conflagrate_matches(context, action, state) end
    elseif action.name == "Shadowburn" then
        custom_matches = function(context, state) return shadowburn_matches(context, action, state) end
    elseif action.name == "CurseOfDoom" then
        custom_matches = function(context, state) return curse_of_doom_matches(context, action, state) end
    elseif action.name == "BacklashShadowBolt" then
        custom_matches = function(context, state) return backlash_matches(context, action, state) end
    elseif action.name == "Incinerate" then
        custom_matches = function(context, state) return incinerate_matches(context, action, state) end
    elseif action.name == "SearingPain" then
        custom_matches = function(context, state) return searing_pain_matches(context, action, state) end
    elseif action.name == "SoulFire" then
        custom_matches = function(context, state) return soul_fire_matches(context, action, state) end
    elseif action.name == "Corruption" then
        custom_matches = function(context, state) return corruption_matches(context, action, state) end
    elseif action.name == "CurseOfAgony" then
        custom_matches = function(context, state) return curse_of_agony_matches(context, action, state) end
    elseif action.name == "DrainLife" then
        custom_matches = function(context, state) return drain_life_matches(context, action, state) end
    elseif action.name == "HealthFunnel" then
        custom_matches = function(context, state) return health_funnel_matches(context, action, state) end
    elseif action.name == "DarkPact" then
        custom_matches = function(context, state) return dark_pact_matches(context, action, state) end
    elseif action.name == "FelArmor" then
        custom_matches = function(context, state) return fel_armor_matches(context, action, state) end
    elseif action.name == "DemonArmor" then
        custom_matches = function(context, state) return demon_armor_matches(context, action, state) end
    elseif action.name == "ShadowWard" then
        custom_matches = function(context, state) return shadow_ward_matches(context, action, state) end
    elseif action.name == "CreateHealthstone" then
        custom_matches = function(context, state) return create_healthstone_matches(context, action, state) end
    elseif action.name == "LifeTap" then
        custom_matches = function(context, state) return life_tap_matches(context, action, state) end
    elseif action.name == "DeathCoil" then
        custom_matches = function(context, state) return death_coil_matches(context, action, state) end
    elseif action.name == "Fear" then
        custom_matches = function(context, state) return fear_matches(context, action, state) end
    elseif action.name == "SummonImp" or action.name == "SummonVoidwalker" or action.name == "SummonSuccubus" or action.name == "SummonFelhunter" or action.name == "SummonFelguard" then
        custom_matches = function(context, state) return summon_pet_matches(context, action, state) end
    elseif action.enemy_count then
        custom_matches = function(context, state) return aoe_matches(context, action, state) end
    else
        custom_matches = function(context, state) return NS.action_matches(context, action) end
    end
    strategies[#strategies + 1] = {
        name = action.name,
        matches = custom_matches,
        execute = function(context)
            return NS.action_execute(context, action, "[DESTRUCTION]")
        end,
    }
end

-- ============================================================================
-- FrostByte parity strategies (inserted at correct priority positions)
-- ============================================================================

-- ManaGem: auto-use mana items when mana is low
-- Insert at position 7 (after DarkPact=6, before DrainLife=7)
table.insert(strategies, 7, {
    name = "ManaGem",
    matches = function(context, state)
        local threshold = (context.settings and context.settings.destro_mana_gem_threshold) or 35
        if (state.mana_pct or 100) > threshold then return false end
        return state.mana_gem_ready or false
    end,
    execute = function(context, state)
        local id = state and state.mana_gem_id
        if id and NS.use_item_by_id then
            NS.use_item_by_id(id)
            return true
        end
        return false
    end,
})

-- Soulshatter: threat dump
-- Insert at position 24 (after Hellfire=22 shift by ManaGem=1, before DeathCoil=23 shift by ManaGem=1)
-- Original position after AoE (SeedOfCorruption=20, RainOfFire=21, Hellfire=22), before emergency (DeathCoil=23, Fear=24)
table.insert(strategies, 24, {
    name = "Soulshatter",
    matches = function(context, state)
        if not context.in_combat then return false end
        return NS.spell_ready(SPELLS.Soulshatter, NS.PLAYER_UNIT, { skip_range = true })
    end,
    execute = function()
        return NS.try_cast(SPELLS.Soulshatter, NS.PLAYER_UNIT, "[DESTRUCTION] Soulshatter")
    end,
})

NS.rotation_registry:register("destruction", strategies, { get_state = build_state })
NS.log("Warlock destruction rotation registered (build_state, explicit strategies, Backlash/Backdraft, execute, AoE, defensives, utility)")
return strategies
