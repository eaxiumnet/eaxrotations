-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-28
-- Change: Classic Vanilla Destruction Warlock rotation
-- =========================================================================
local __eax_file = "classes/warlock/destruction_vanilla.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-28"
local __eax_change = "Classic Vanilla Destruction Warlock rotation"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Warlock Destruction priority list.
-- ============================================================================
-- What: Classic Vanilla Warlock Destruction priority list for nukes, AoE, and emergency survivability
-- When: Per tick
-- Why: Build-once state keeps burst, armor, and execute choices cheap and predictable
-- Safety: Buff scans and readiness checks are nil-guarded; optional spell data falls back conservatively
-- ============================================================================

--
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}

-- Debuff and buff ID lists for state queries
local CURSE_OF_DOOM_DEBUFF = { 603 }
local CURSE_OF_AGONY_DEBUFF = { 11713, 11712, 11711, 6217, 1014, 980 }
local IMMOLATE_DEBUFF = { 11668, 11667, 11665, 2941, 1094, 707, 348 }
local CORRUPTION_DEBUFF = { 11672, 11671, 7648, 6223, 6222, 172 }
local BACKLASH_BUFF = { }  -- Backlash is TBC-only; empty in Classic
local DEMON_ARMOR_BUFF = { 11735, 11734, 11733, 1086, 706, 696, 687 }
local SHADOW_WARD_BUFF = { 11740, 11739, 6229 }

-- Local spell actions for spells not exposed in NS.WarlockSpells
local DemonArmorSpell = NS.spell_action({ 11735, 11734, 11733, 1086, 706, 687 }, "DemonArmor")
local ShadowWardSpell = NS.spell_action({ 11740, 11739, 6229 }, "ShadowWard")
local DrainLife = NS.spell_action({ 11700, 11699, 7651, 709, 699, 689 }, "DrainLife")
local HealthFunnel = NS.spell_action({ 11695, 11694, 11693, 3700, 3699, 3698, 755 }, "HealthFunnel")
local DarkPact = nil  -- Dark Pact is TBC-only
local SoulFire = NS.spell_action({ 17924, 6353 }, "SoulFire")
local SearingPain = NS.spell_action({ 17923, 17922, 17921, 17920, 17919, 5676 }, "SearingPain")
local Fear = NS.spell_action({ 5782, 6213, 6215 }, "Fear")
local RainOfFire = NS.spell_action({ 17954, 17953, 5740 }, "RainOfFire")
local Hellfire = NS.spell_action({ 11684, 11683, 1949 }, "Hellfire")
local UnavailableClassicWarlockAoe = nil
local CreateHealthstone = NS.spell_action({ 11730, 11729, 6202, 6201, 5699 }, "CreateHealthstone")
local SummonImp = NS.spell_action({ 688 }, "SummonImp")
local SummonVoidwalker = NS.spell_action({ 697 }, "SummonVoidwalker")
local SummonSuccubus = NS.spell_action({ 712 }, "SummonSuccubus")
local SummonFelhunter = NS.spell_action({ 691 }, "SummonFelhunter")
local SummonFelguard = nil  -- Felguard is TBC-only
local FelDomination = NS.spell_action({ 18708 }, "FelDomination")

-- Constants
local IMMOLATE_PANDEMIC_WINDOW = 3.5
local IMMOLATE_MIN_SP_DEFAULT = 400  -- SP below which Immolate is skipped (conservative GCD-positive threshold)
local SHADOWBURN_HP_PCT = 20
local DRAIN_LIFE_HP_THRESHOLD = 40
local MANA_LIFE_TAP_THRESHOLD = 35
local MANA_ITEM_IDS = { 20520, 12662 }  -- Dark Rune, Demonic Rune
local SOUL_SHARD_ITEM = 6265             -- Classic Vanilla Soul Shard reagent (moved before first use in shadowburn_matches)

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
        has_demon_armor = me and NS.buff_up(me, DEMON_ARMOR_BUFF) or false,
        has_shadow_ward = me and NS.buff_up(me, SHADOW_WARD_BUFF) or false,
        hp = context.hp or 100,
        mana_pct = context.mana_pct or 100,
        mana_gem_id = nil,
        mana_gem_ready = false,
        spell_damage = 0,
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
    -- SP-aware gating: Falls back through context (middleware) then to 0 (conservative: skip DoTs when SP unknown)
    state.spell_damage = (NS.get_spell_damage and NS.get_spell_damage()) or context.spell_damage or 0
    return state
end

local ACTIONS = {
    -- Buffs / OOC
    { name = "DemonArmor", spell = DemonArmorSpell, target = "self", kind = "buff", buff = DEMON_ARMOR_BUFF, requires_target = false },
    { name = "ShadowWard", spell = ShadowWardSpell, target = "self", kind = "buff", buff = SHADOW_WARD_BUFF, requires_target = false, cooldown = 30 },
    { name = "CreateHealthstone", spell = CreateHealthstone, target = "self", ooc = true, requires_target = false },
    { name = "LifeTap", spell = SPELLS.LifeTap, target = "self", max_mana = 65, min_hp = 40, requires_target = false },
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
    { name = "UnavailableClassicWarlockNuke", spell = SPELLS.UnavailableClassicWarlockNuke, not_moving = true },
    { name = "ShadowBolt", spell = SPELLS.ShadowBolt, not_moving = true },
    -- AoE
    { name = "UnavailableClassicWarlockAoe", spell = UnavailableClassicWarlockAoe, enemy_count = 3 },
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
    { name = "FelDomination", spell = FelDomination, target = "self", cooldown = 900, requires_target = false },
}

local function immolate_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Immolate, 2.0) then return false end
    if not state then return false end
    state = state or {}
    -- SP-aware gating: skip Immolate when spell damage is below the threshold
    -- (conservative: defaults to 400 SP, configurable via destro_immolate_min_sp)
    local s = context.settings or {}
    local min_sp = s.destro_immolate_min_sp or IMMOLATE_MIN_SP_DEFAULT
    if (state.spell_damage or 0) < min_sp then return false end
    if (state.immolate_remains or 0) > IMMOLATE_PANDEMIC_WINDOW then return false end
    if not NS.should_refresh_dot((state.immolate_remains or 0), 1.5, context.ttd, 15) then return false end
    return true
end

local function conflagrate_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if (state.immolate_remains or 0) <= 0 then return false end
    return true
end

local function shadowburn_matches(context, action, state)
    if not context.target then return false end
    if NS.has_item and not NS.has_item(SOUL_SHARD_ITEM) then return false end
    local hp_threshold = (context.settings and context.settings.destro_shadowburn_hp) or SHADOWBURN_HP_PCT
    if not NS.is_execute_phase(context.target_hp, hp_threshold) then return false end
    return NS.spell_ready(action.spell, context.target)
end

local function curse_of_doom_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.CurseOfDoom, 2.0) then return false end
    if not NS.should_use_long_cd(context, action.cooldown) then return false end
    if not state then return false end
    state = state or {}
    if (state.cod_remains or 0) > 5 then return false end
    return true
end

local function backlash_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if not state.has_backlash then return false end
    return true
end

local function incinerate_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if (state.immolate_remains or 0) <= 0 then return false end
    return NS.spell_ready(action.spell, context.target)
end

local function searing_pain_matches(context, action, state)
    return true
end


local function soul_fire_matches(context, action, state)
    if NS.has_item and not NS.has_item(SOUL_SHARD_ITEM) then return false end
    return true
end

local function corruption_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Corruption, 2.0) then return false end
    if not state then return false end
    state = state or {}
    if (state.corruption_remains or 0) > 3 then return false end
    return true
end

local function curse_of_agony_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.CurseOfAgony, 2.0) then return false end
    if not state then return false end
    state = state or {}
    if (state.coa_remains or 0) > 3 then return false end
    if (state.cod_remains or 0) > 0 then return false end
    return NS.spell_ready(action.spell, context.target)
end

local function drain_life_matches(context, action, state)
    if context.is_channeling then return false end
    if not state then return false end
    state = state or {}
    if (state.hp or 100) > DRAIN_LIFE_HP_THRESHOLD then return false end
    return true
end

local function health_funnel_matches(context, action, state)
    local pet = NS.GetPet()
    if not pet then return false end
    if ((NS.unit_health_pct and NS.unit_health_pct(pet)) or 100) > 50 then return false end
    return true
end

local function demon_armor_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(DemonArmorSpell, 3.0) then return false end
    if not state then return false end
    state = state or {}
    if state.has_demon_armor then return false end
    return true
end

local function shadow_ward_matches(context, action, state)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.ShadowWard, 3.0) then return false end
    if not state then return false end
    state = state or {}
    if state.has_shadow_ward then return false end
    return true
end

local function create_healthstone_matches(context, action, state)
    if NS.has_item and not NS.has_item(SOUL_SHARD_ITEM) then return false end
    if context.in_combat then return false end
    if context.has_valid_enemy_target then return false end
    return true
end

local function life_tap_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if (state.mana_pct or 100) > MANA_LIFE_TAP_THRESHOLD then return false end
    if (state.hp or 100) < (action.min_hp or 0) then return false end
    return true
end

local function summon_pet_matches(context, action, state)
    if context.in_combat then return false end
    if context.has_valid_enemy_target then return false end
    local pet = NS.GetPet()
    if pet and NS.unit_alive(pet) then return false end
    return true
end

local function death_coil_matches(context, action, state)
    if not state then return false end
    state = state or {}
    if (state.hp or 100) > 35 then return false end
    return true
end

local function fear_matches(context, action, state)
    return true
end

local function aoe_matches(context, action, state)
    if context.is_channeling then return false end
    if not action.spell then return false end
    if (context.enemy_count or context.enemies_count or 0) < (action.enemy_count or 0) then return false end
    if not NS.spell_ready(action.spell, context.target) then return false end
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
    elseif action.name == "UnavailableClassicWarlockNuke" or action.name == "UnavailableClassicWarlockAoe" then
        custom_matches = function() return false end
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
    elseif action.name == "SummonImp" or action.name == "SummonVoidwalker" or action.name == "SummonSuccubus" or action.name == "SummonFelhunter" then
        custom_matches = function(context, state) return summon_pet_matches(context, action, state) end
    elseif action.enemy_count then
        custom_matches = function(context, state) return aoe_matches(context, action, state) end
    else
        custom_matches = function(context, state) return true end
    end
    strategies[#strategies + 1] = {
        name = action.name,
        matches = custom_matches,
        execute = function(context)
            local target = context.target
            local opts = { expected_cooldown = action.cooldown }
            if action.target == "self" or action.position == "self" then
                target = context.me or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
                opts.skip_range = true
            elseif action.target == "pet" then
                target = context.pet or (NS.GetPet and NS.GetPet())
            elseif action.position == "target" and NS.try_cast_position then
                local get_position = target and target.get_position
                local pos = get_position and target:get_position() or nil
                if not pos then return false end
                return NS.try_cast_position(action.spell, pos, target, "[DESTRUCTION] " .. action.name, opts)
            end
            return NS.try_cast(action.spell, target, "[DESTRUCTION] " .. action.name, opts)
        end,
    }
end

-- ============================================================================
-- parity parity strategies (inserted at correct priority positions)
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

-- UnavailableClassicWarlockThreat: threat dump
-- Insert at position 24 (after Hellfire=22 shift by ManaGem=1, before DeathCoil=23 shift by ManaGem=1)
-- Original position after AoE (UnavailableClassicWarlockAoe=20, RainOfFire=21, Hellfire=22), before emergency (DeathCoil=23, Fear=24)
table.insert(strategies, 24, {
    name = "UnavailableClassicWarlockThreat",
    matches = function(context, state)
        if not context.in_combat then return false end
        local me = context.me or (NS.GetPlayer and NS.GetPlayer())
        if not me then return false end
        if NS.cooldown_remains(SPELLS.UnavailableClassicWarlockThreat, 300) > 0 then return false end
        return NS.spell_ready(SPELLS.UnavailableClassicWarlockThreat, me, { skip_range = true })
    end,
    execute = function(context)
        local me = context.me or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
        return NS.try_cast(SPELLS.UnavailableClassicWarlockThreat, me, "[DESTRUCTION] UnavailableClassicWarlockThreat", { skip_range = true })
    end,
})

NS.rotation_registry:register("destruction", strategies, { get_state = build_state })
NS.log("Warlock destruction rotation registered (build_state, explicit strategies, Backlash/Backdraft, execute, AoE, defensives, utility)")
return strategies

