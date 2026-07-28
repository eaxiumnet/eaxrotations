-- leveling_wotlk.lua — Warlock leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for warlock leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple dot/drain/nuke rotation using core leveling abilities.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local helpers = require("shared/leveling_helpers_sylvanas")
local pet_manager = require("shared/pet_manager_sylvanas")
local SPELLS = NS.WarlockSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Haunt = define("Haunt", 48181, "Haunt"),
    UnstableAffliction = define("UnstableAffliction", { 30405, 30404, 30108 }, "UnstableAffliction"),
    Corruption = define("Corruption", { 47813, 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    CurseOfAgony = define("CurseOfAgony", { 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfAgony"),
    Immolate = define("Immolate", { 47811, 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
    DrainSoul = define("DrainSoul", { 27217, 11675, 8289, 8288, 1120 }, "DrainSoul"),
    DrainLife = define("DrainLife", { 27220, 27219, 11700, 11699, 7651, 709, 699, 689 }, "DrainLife"),
    ShadowBolt = define("ShadowBolt", { 47809, 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
    Incinerate = define("Incinerate", { 32231, 29722 }, "Incinerate"),
    ChaosBolt = define("ChaosBolt", 50796, "ChaosBolt"),
    SoulFire = define("SoulFire", { 30545, 27211, 17924, 6353 }, "SoulFire"),
    Conflagrate = define("Conflagrate", { 30912, 27266, 18932, 18931, 18930, 17962 }, "Conflagrate"),
    FelArmor = define("FelArmor", { 28189, 28176 }, "FelArmor"),
    DemonArmor = define("DemonArmor", { 27260, 11735, 11734, 11733, 1086, 706 }, "DemonArmor"),
    LifeTap = define("LifeTap", { 27222, 11689, 11688, 11687, 1456, 1455, 1454 }, "LifeTap"),
    CreateHealthstone = define("CreateHealthstone", { 27230, 11730, 11729, 6202, 6201, 5699 }, "CreateHealthstone"),
    CreateSoulstone = define("CreateSoulstone", { 47884, 27238, 20770, 20759, 20758, 693 }, "CreateSoulstone"),
    SummonFelhunter = define("SummonFelhunter", 691, "SummonFelhunter"),
    SummonVoidwalker = define("SummonVoidwalker", 697, "SummonVoidwalker"),
    SummonImp = define("SummonImp", 688, "SummonImp"),
    SpellLock = define("SpellLock", 19647, "SpellLock"),
    SeedOfCorruption = define("SeedOfCorruption", { 47836, 47835, 27243 }, "SeedOfCorruption"),
    RainOfFire = define("RainOfFire", { 47820, 47819, 27212, 11678, 5740 }, "RainOfFire"),
    Shoot = define("Shoot", 5019, "Shoot"),
}

local UNSTABLE_AFFLICTION_DEBUFF = { 30405, 30404, 30108 }
local CORRUPTION_DEBUFF = { 47813, 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local CURSE_OF_AGONY_DEBUFF = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }
local IMMOLATE_DEBUFF = { 47811, 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local HAUNT_DEBUFF = { 48181, 59164 }
local FEL_ARMOR_BUFF = { 28189, 28176 }
local DEMON_ARMOR_BUFF = { 27260, 11735, 11734, 11733, 1086, 706 }

local warlock_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    corruption_remains = 0,
    immolate_remains = 0,
    curse_remains = 0,
    unstable_remains = 0,
    haunt_remains = 0,
    fel_armor_up = false,
    demon_armor_up = false,
    target_casting = false,
    has_pet = false,
    pet_alive = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(warlock_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.corruption_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CORRUPTION_DEBUFF)) or 0
    state.immolate_remains = (target and NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF)) or 0
    state.curse_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_AGONY_DEBUFF)) or 0
    state.unstable_remains = (target and NS.debuff_remains and NS.debuff_remains(target, UNSTABLE_AFFLICTION_DEBUFF)) or 0
    state.haunt_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HAUNT_DEBUFF)) or 0
    state.fel_armor_up = (me and NS.buff_up and NS.buff_up(me, FEL_ARMOR_BUFF)) or false
    state.demon_armor_up = (me and NS.buff_up and NS.buff_up(me, DEMON_ARMOR_BUFF)) or false
    state.target_casting = helpers.should_interrupt(target)
    local pet = pet_manager.get_pet(me)
    state.has_pet = pet ~= nil
    state.pet_alive = pet_manager.pet_alive(pet)
    return state
end

local DSL_DEFS = {
    -- Spell Lock (Felhunter) is an interrupt: only fire when the target is actually casting.
    {
        name = "SpellLock",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_casting", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 5 },
        },
        action = { type = "cast", spell = ACTION.SpellLock, target = "target" },
    },
    -- Keep a demon out: resummon out of combat when the pet is missing or dead.
    -- 10s cast time makes in-combat summoning impractical for leveling.
    -- Prefer Felhunter (Spell Lock interrupt), fall back to Voidwalker (tank), then Imp (no shard).
    {
        name = "SummonPet",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "OR", conditions = {
                { type = "state", field = "has_pet", op = "falsy" },
                { type = "state", field = "pet_alive", op = "falsy" },
            } },
            { type = "state", field = "mana_pct", op = ">=", value = 60 },
        },
        action = { type = "custom", fn = function(context, state)
            if NS.try_cast(ACTION.SummonFelhunter, nil, "SummonFelhunter") == true then return true end
            if NS.try_cast(ACTION.SummonVoidwalker, nil, "SummonVoidwalker") == true then return true end
            return NS.try_cast(ACTION.SummonImp, nil, "SummonImp") == true
        end },
    },
    -- Stock a Soulstone out of combat for self-res insurance while leveling.
    {
        name = "CreateSoulstone",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.CreateSoulstone, target = "self" },
    },
    {
        name = "CreateHealthstone",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.CreateHealthstone, target = "self" },
    },
    {
        name = "FelArmor",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "fel_armor_up", op = "falsy" },
            { type = "state", field = "demon_armor_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.FelArmor, target = "self" },
    },
    {
        name = "Haunt",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "haunt_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Haunt, target = "target" },
    },
    {
        name = "SeedOfCorruption",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 34 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_target_meets then return false end
                local radius = (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_15) or 15
                return NS.aoe_target_meets(3, radius, context and context.target, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.SeedOfCorruption, target = "target" },
    },
    {
        name = "RainOfFire",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 57 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_target_meets then return false end
                local radius = (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8
                return NS.aoe_target_meets(3, radius, context and context.target, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.RainOfFire, target = "target" },
    },
    {
        name = "UnstableAffliction",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "unstable_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.UnstableAffliction, target = "target" },
    },
    {
        name = "Corruption",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "corruption_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Corruption, target = "target" },
    },
    {
        name = "Immolate",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "immolate_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Immolate, target = "target" },
    },
    {
        name = "CurseOfAgony",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "curse_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.CurseOfAgony, target = "target" },
    },
    {
        name = "Conflagrate",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "immolate_remains", op = ">", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Conflagrate, target = "target" },
    },
    {
        name = "DrainSoul",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = "<", value = 25 },
        },
        action = { type = "cast", spell = ACTION.DrainSoul, target = "target" },
    },
    {
        name = "DrainLife",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 60 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.DrainLife, target = "target" },
    },
    {
        name = "LifeTap",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 30 },
            { type = "state", field = "hp", op = ">", value = 40 },
        },
        action = { type = "cast", spell = ACTION.LifeTap, target = "self" },
    },
    {
        name = "ChaosBolt",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.ChaosBolt, target = "target" },
    },
    {
        name = "Incinerate",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Incinerate, target = "target" },
    },
    {
        name = "ShadowBolt",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.ShadowBolt, target = "target" },
    },
    {
        name = "SoulFire",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.SoulFire, target = "target" },
    },
    -- OOM fallback: wand when too low to cast and Life Tap would be unsafe.
    {
        name = "Shoot",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Shoot, target = "target" },
    },
}

-- Priority order (compiled in place from DSL_DEFS below).
local strategies = {
    { name = "SpellLock" },
    { name = "SummonPet" },
    { name = "CreateSoulstone" },
    { name = "CreateHealthstone" },
    { name = "FelArmor" },
    { name = "Haunt" },
    { name = "SeedOfCorruption" },
    { name = "RainOfFire" },
    { name = "UnstableAffliction" },
    { name = "Corruption" },
    { name = "Immolate" },
    { name = "CurseOfAgony" },
    { name = "Conflagrate" },
    { name = "DrainSoul" },
    { name = "DrainLife" },
    { name = "LifeTap" },
    { name = "ChaosBolt" },
    { name = "Incinerate" },
    { name = "ShadowBolt" },
    { name = "SoulFire" },
    { name = "Shoot" },
}

for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

if NS.log then NS.log("Warlock leveling rotation registered") end

return { strategies = strategies, build_state = build_state }
