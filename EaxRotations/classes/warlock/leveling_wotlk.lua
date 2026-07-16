-- leveling_wotlk.lua — Warlock leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for warlock leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple dot/drain/nuke rotation using core leveling abilities.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
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

local function summon_pet_matches(context, state)
    -- Keep a demon out: resummon out of combat when the pet is missing or dead.
    -- 10s cast time makes in-combat summoning impractical for leveling.
    return not state.in_combat and (not state.has_pet or not state.pet_alive) and state.mana_pct >= 60
end

local function create_soulstone_matches(context, state)
    -- Stock a Soulstone out of combat for self-res insurance while leveling.
    return not state.in_combat
end

local function spell_lock_matches(context, state)
    -- Spell Lock (Felhunter) is an interrupt: only fire when the target is actually casting.
    return state.in_combat and state.target_casting == true and state.mana_pct >= 5
end

local function create_healthstone_matches(context, state)
    return not state.in_combat
end

local function fel_armor_matches(context, state)
    return not state.in_combat and not state.fel_armor_up and not state.demon_armor_up
end

local function haunt_matches(context, state)
    return state.in_combat and state.haunt_remains < 3 and state.mana_pct >= 10
end

local function unstable_affliction_matches(context, state)
    return state.in_combat and state.unstable_remains < 3 and state.mana_pct >= 10
end

local function corruption_matches(context, state)
    return state.in_combat and state.corruption_remains < 3 and state.mana_pct >= 10
end

local function immolate_matches(context, state)
    return state.in_combat and state.immolate_remains < 3 and state.mana_pct >= 15
end

local function curse_of_agony_matches(context, state)
    return state.in_combat and state.curse_remains < 3 and state.mana_pct >= 10
end

local function conflagrate_matches(context, state)
    return state.in_combat and state.immolate_remains > 3 and state.mana_pct >= 15
end

local function drain_soul_matches(context, state)
    return state.in_combat and state.target_hp < 25
end

local function drain_life_matches(context, state)
    return state.in_combat and state.hp < 60 and state.mana_pct >= 15
end

local function life_tap_matches(context, state)
    return state.in_combat and state.mana_pct < 30 and state.hp > 40
end

local function chaos_bolt_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function incinerate_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function shadow_bolt_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function seed_of_corruption_matches(context, state)
    return state.in_combat and state.mana_pct >= 34
        and NS.aoe_target_meets and NS.aoe_target_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_15) or 15, context and context.target, context)
end

local function rain_of_fire_matches(context, state)
    return state.in_combat and state.mana_pct >= 57
        and NS.aoe_target_meets and NS.aoe_target_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8, context and context.target, context, state)
end

local function shoot_wand_matches(context, state)
    -- OOM fallback: wand when too low to cast and Life Tap would be unsafe.
    return state.in_combat and state.mana_pct < 10
end

local function soul_fire_matches(context, state)
    return state.in_combat and state.mana_pct >= 30
end

local strategies = {
    { name = "SpellLock", matches = spell_lock_matches, execute = function(ctx) return ACTION.SpellLock and ACTION.SpellLock:cast_safe(ctx.target) end },
    { name = "SummonPet", matches = summon_pet_matches, execute = function(ctx)
        -- Prefer Felhunter (Spell Lock interrupt), fall back to Voidwalker (tank), then Imp (no shard).
        if ACTION.SummonFelhunter and ACTION.SummonFelhunter:cast_safe() then return true end
        if ACTION.SummonVoidwalker and ACTION.SummonVoidwalker:cast_safe() then return true end
        return ACTION.SummonImp and ACTION.SummonImp:cast_safe()
    end },
    { name = "CreateSoulstone", matches = create_soulstone_matches, execute = function(ctx) return ACTION.CreateSoulstone and ACTION.CreateSoulstone:cast_safe() end },
    { name = "CreateHealthstone", matches = create_healthstone_matches, execute = function(ctx) return ACTION.CreateHealthstone and ACTION.CreateHealthstone:cast_safe() end },
    { name = "FelArmor", matches = fel_armor_matches, execute = function(ctx) return ACTION.FelArmor and ACTION.FelArmor:cast_safe() end },
    { name = "Haunt", matches = haunt_matches, execute = function(ctx) return ACTION.Haunt and ACTION.Haunt:cast_safe(ctx.target) end },
    { name = "SeedOfCorruption", matches = seed_of_corruption_matches, execute = function(ctx) return ACTION.SeedOfCorruption and ACTION.SeedOfCorruption:cast_safe(ctx.target) end },
    { name = "RainOfFire", matches = rain_of_fire_matches, execute = function(ctx) return ACTION.RainOfFire and ACTION.RainOfFire:cast_safe(ctx.target) end },
    { name = "UnstableAffliction", matches = unstable_affliction_matches, execute = function(ctx) return ACTION.UnstableAffliction and ACTION.UnstableAffliction:cast_safe(ctx.target) end },
    { name = "Corruption", matches = corruption_matches, execute = function(ctx) return ACTION.Corruption and ACTION.Corruption:cast_safe(ctx.target) end },
    { name = "Immolate", matches = immolate_matches, execute = function(ctx) return ACTION.Immolate and ACTION.Immolate:cast_safe(ctx.target) end },
    { name = "CurseOfAgony", matches = curse_of_agony_matches, execute = function(ctx) return ACTION.CurseOfAgony and ACTION.CurseOfAgony:cast_safe(ctx.target) end },
    { name = "Conflagrate", matches = conflagrate_matches, execute = function(ctx) return ACTION.Conflagrate and ACTION.Conflagrate:cast_safe(ctx.target) end },
    { name = "DrainSoul", matches = drain_soul_matches, execute = function(ctx) return ACTION.DrainSoul and ACTION.DrainSoul:cast_safe(ctx.target) end },
    { name = "DrainLife", matches = drain_life_matches, execute = function(ctx) return ACTION.DrainLife and ACTION.DrainLife:cast_safe(ctx.target) end },
    { name = "LifeTap", matches = life_tap_matches, execute = function(ctx) return ACTION.LifeTap and ACTION.LifeTap:cast_safe() end },
    { name = "ChaosBolt", matches = chaos_bolt_matches, execute = function(ctx) return ACTION.ChaosBolt and ACTION.ChaosBolt:cast_safe(ctx.target) end },
    { name = "Incinerate", matches = incinerate_matches, execute = function(ctx) return ACTION.Incinerate and ACTION.Incinerate:cast_safe(ctx.target) end },
    { name = "ShadowBolt", matches = shadow_bolt_matches, execute = function(ctx) return ACTION.ShadowBolt and ACTION.ShadowBolt:cast_safe(ctx.target) end },
    { name = "SoulFire", matches = soul_fire_matches, execute = function(ctx) return ACTION.SoulFire and ACTION.SoulFire:cast_safe(ctx.target) end },
    { name = "Shoot", matches = shoot_wand_matches, execute = function(ctx) return ACTION.Shoot and ACTION.Shoot:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
