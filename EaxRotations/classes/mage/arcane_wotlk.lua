-- arcane_wotlk.lua — Mage Arcane rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  Arcane Blast stacking (0-3), Missile Barrage procs, PoM/AP/IV burst, mana management.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.MageSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    -- Arcane Blast: WotLK max 42897 + TBC 30451 (lexxer). Removed invalid 30450/30449/25376/25375/42891.
    ArcaneBlast = define("ArcaneBlast", { 42897, 42896, 42895, 42894, 30451 }, "ArcaneBlast"),
    ArcaneMissiles = define("ArcaneMissiles", { 42846, 42845, 42844, 42843, 38704, 38699, 25346, 10212, 10211, 5143, 5144, 5145, 8417, 8418, 8419 }, "ArcaneMissiles"),
    ArcaneBarrage = define("ArcaneBarrage", { 44425, 44780, 44781 }, "ArcaneBarrage"),
    Evocation = define("Evocation", { 12051 }, "Evocation"),
    ArcanePower = define("ArcanePower", { 12042 }, "ArcanePower"),
    IcyVeins = define("IcyVeins", { 12472 }, "IcyVeins"),
    MirrorImage = define("MirrorImage", { 55342 }, "MirrorImage"),
    PresenceOfMind = define("PresenceOfMind", { 12043 }, "PresenceOfMind"),
    Counterspell = define("Counterspell", { 2139 }, "Counterspell"),
    ConjureManaEmerald = define("ConjureManaEmerald", { 27101, 10054, 10053, 3552, 759 }, "ConjureManaEmerald"),
    MageArmor = define("MageArmor", { 43024, 43023, 27130, 22783, 22782, 1008 }, "MageArmor"),
}

local ARCANE_BLAST_BUFF = { 36032, 36033, 36034, 40057 }
local MAGE_ARMOR_BUFF = { 43024, 43023, 27130, 22783, 22782, 1008 }
-- Missile Barrage proc buff is 44401 (lexxer wotlk). 54490+ are talent ranks, not the proc aura.
local MISSILE_BARRAGE_PROC = { 44401 }
local ARCANE_POWER_BUFF = { 12042 }
local ICY_VEINS_BUFF = { 12472 }

local arcane_state = {
    hp = 100,
    mana_pct = 100,
    target_hp = 100,
    enemy_count = 1,
    in_combat = false,
    arcane_blast_stacks = 0,
    missile_barrage_proc = false,
    arcane_power_up = false,
    icy_veins_up = false,
    mage_armor_up = false,
    pom_ready = false,
    target_is_casting = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(arcane_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.arcane_blast_stacks = (me and NS.buff_stacks and NS.buff_stacks(me, ARCANE_BLAST_BUFF)) or 0
    state.missile_barrage_proc = (me and NS.buff_up and NS.buff_up(me, MISSILE_BARRAGE_PROC)) or false
    state.arcane_power_up = (me and NS.buff_up and NS.buff_up(me, ARCANE_POWER_BUFF)) or false
    state.icy_veins_up = (me and NS.buff_up and NS.buff_up(me, ICY_VEINS_BUFF)) or false
    state.mage_armor_up = (me and NS.buff_up and NS.buff_up(me, MAGE_ARMOR_BUFF)) or false
    state.pom_ready = (ACTION.PresenceOfMind and ACTION.PresenceOfMind.cooldown_remaining and ACTION.PresenceOfMind:cooldown_remaining() <= 0) or false
    state.target_is_casting = (target and target.is_casting and target:is_casting()) or false
    return state
end

-- Counterspell: interrupt when target is casting
local function counterspell_matches(context, state)
    return state.in_combat and state.target_is_casting
end

-- Mage Armor: maintain if not up
local function mage_armor_matches(context, state)
    return not state.mage_armor_up
end

-- Evocation: mana emergency at < 20%
local function evocation_matches(context, state)
    return (state.mana_pct or 100) < 20
end

-- Mana Gem: mana recovery at < 40% (above evocation threshold)
local function mana_gem_matches(context, state)
    return (state.mana_pct or 100) < 40 and (state.mana_pct or 100) >= 20
end

-- Arcane Power: burst cooldown (not already active)
local function arcane_power_matches(context, state)
    if not state.in_combat or state.arcane_power_up then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 120) then return false end
    return true
end

local function icy_veins_matches(context, state)
    if not state.in_combat or state.icy_veins_up then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    return true
end

-- Mirror Image: cooldown
local function mirror_image_matches(context, state)
    return state.in_combat
end

-- Presence of Mind: enables instant Arcane Blast combo
local function presence_of_mind_matches(context, state)
    if not state.in_combat or not state.pom_ready then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    return true
end

-- Arcane Missiles: filler with Missile Barrage proc (instant) or at 3 AB stacks
local function arcane_missiles_matches(context, state)
    return state.missile_barrage_proc or (state.arcane_blast_stacks or 0) >= 3
end

-- Arcane Barrage: instant finisher with Missile Barrage proc or at 3 AB stacks (reset)
local function arcane_barrage_matches(context, state)
    return state.missile_barrage_proc or (state.arcane_blast_stacks or 0) >= 3
end

-- Arcane Blast: spam at 0-2 stacks, mana permitting
local function arcane_blast_matches(context, state)
    return (state.mana_pct or 100) >= 20 and (state.arcane_blast_stacks or 0) < 3
end

local strategies = {
    { name = "Counterspell", matches = counterspell_matches, execute = function(ctx) return ACTION.Counterspell and ACTION.Counterspell:cast_safe(ctx.target) end },
    { name = "MageArmor", matches = mage_armor_matches, execute = function(ctx) return ACTION.MageArmor and ACTION.MageArmor:cast_safe() end },
    { name = "Evocation", matches = evocation_matches, execute = function(ctx) return ACTION.Evocation and ACTION.Evocation:cast_safe() end },
    { name = "ManaGem", matches = mana_gem_matches, execute = function(ctx) return ACTION.ConjureManaEmerald and ACTION.ConjureManaEmerald:cast_safe() end },
    { name = "ArcanePower", matches = arcane_power_matches, execute = function(ctx) return ACTION.ArcanePower and ACTION.ArcanePower:cast_safe() end },
    { name = "IcyVeins", matches = icy_veins_matches, execute = function(ctx) return ACTION.IcyVeins and ACTION.IcyVeins:cast_safe() end },
    { name = "MirrorImage", matches = mirror_image_matches, execute = function(ctx) return ACTION.MirrorImage and ACTION.MirrorImage:cast_safe() end },
    { name = "PresenceOfMind", matches = presence_of_mind_matches, execute = function(ctx) return ACTION.PresenceOfMind and ACTION.PresenceOfMind:cast_safe() end },
    { name = "ArcaneMissiles", matches = arcane_missiles_matches, execute = function(ctx) return ACTION.ArcaneMissiles and ACTION.ArcaneMissiles:cast_safe(ctx.target) end },
    { name = "ArcaneBarrage", matches = arcane_barrage_matches, execute = function(ctx) return ACTION.ArcaneBarrage and ACTION.ArcaneBarrage:cast_safe(ctx.target) end },
    { name = "ArcaneBlast", matches = arcane_blast_matches, execute = function(ctx) return ACTION.ArcaneBlast and ACTION.ArcaneBlast:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("arcane", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
