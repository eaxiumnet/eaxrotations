-- arcane_wotlk.lua — Mage Arcane rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  Arcane Blast stacking (0-3), Missile Barrage procs, PoM/AP/IV burst, mana management.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
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

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "Counterspell",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_casting", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Counterspell, target = "target" },
    },
    {
        name = "MageArmor",
        conditions = {
            { type = "state", field = "mage_armor_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.MageArmor, target = "self" },
    },
    {
        name = "Evocation",
        conditions = {
            { type = "state", field = "mana_pct", op = "<", value = 20 },
        },
        action = { type = "cast", spell = ACTION.Evocation, target = "self" },
    },
    {
        name = "ManaGem",
        conditions = {
            { type = "state", field = "mana_pct", op = "<", value = 40 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ConjureManaEmerald, target = "self" },
    },
    {
        name = "ArcanePower",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "arcane_power_up", op = "falsy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 120) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.ArcanePower, target = "self" },
    },
    {
        name = "IcyVeins",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "icy_veins_up", op = "falsy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.IcyVeins, target = "self" },
    },
    {
        name = "MirrorImage",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.MirrorImage, target = "self" },
    },
    {
        name = "PresenceOfMind",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "pom_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.PresenceOfMind, target = "self" },
    },
    {
        name = "ArcaneMissiles",
        conditions = {
            -- OR logic: proc OR stacks >= 3 (compound check inline via custom)
            { type = "custom", fn = function(context, state)
                return state.missile_barrage_proc or (state.arcane_blast_stacks or 0) >= 3
            end },
        },
        action = { type = "cast", spell = ACTION.ArcaneMissiles, target = "target" },
    },
    {
        name = "ArcaneBarrage",
        conditions = {
            -- OR logic: proc OR stacks >= 3 (compound check inline via custom)
            { type = "custom", fn = function(context, state)
                return state.missile_barrage_proc or (state.arcane_blast_stacks or 0) >= 3
            end },
        },
        action = { type = "cast", spell = ACTION.ArcaneBarrage, target = "target" },
    },
    {
        name = "ArcaneBlast",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
            { type = "state", field = "arcane_blast_stacks", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.ArcaneBlast, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "Counterspell" },
    { name = "MageArmor" },
    { name = "Evocation" },
    { name = "ManaGem" },
    { name = "ArcanePower" },
    { name = "IcyVeins" },
    { name = "MirrorImage" },
    { name = "PresenceOfMind" },
    { name = "ArcaneMissiles" },
    { name = "ArcaneBarrage" },
    { name = "ArcaneBlast" },
}

-- Name-based substitution preserves the existing priority order.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("arcane", strategies, { get_state = build_state })
end
if NS.log then NS.log("Mage Arcane WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
