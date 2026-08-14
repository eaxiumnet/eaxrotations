-- arcane_wotlk.lua — Mage Arcane rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  Arcane Blast stacking (0-4), Missile Barrage proc consumer, PoM/AP/IV
--        burst, ABarrage 4-stack dump, mana management.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors wowsims APL (ui/mage/apls/arcane.apl.json — pinned fixture):
--        AB while stacks < 4, AM on Missile Barrage proc (44401), Evocation at
--        low mana. Arcane Barrage dumps the 4-stack cap (distinct from AM).
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

-- Plain define_action (NOT define_action_for_class): NS.MageSpells is TBC-era,
-- so the class-bound resolver would shadow these WotLK rank ladders with TBC
-- ranks (systemic W3.3 fix — fire_wotlk.lua is the clean precedent).
local define = spec_kit.define_action

local ACTION = {
    -- Arcane Blast: WotLK max 42897 + TBC 30451 (bridge-verified; 42895 is a
    -- cosmetic spell, not an AB rank — removed).
    ArcaneBlast = define("ArcaneBlast", { 42897, 42896, 42894, 30451 }, "ArcaneBlast"),
    ArcaneMissiles = define("ArcaneMissiles", { 42846, 42845, 42844, 42843, 38704, 38699, 25346, 10212, 10211, 5143, 5144, 5145, 8417, 8418, 8419 }, "ArcaneMissiles"),
    ArcaneBarrage = define("ArcaneBarrage", { 44425, 44780, 44781 }, "ArcaneBarrage"),
    Evocation = define("Evocation", { 12051 }, "Evocation"),
    ArcanePower = define("ArcanePower", { 12042 }, "ArcanePower"),
    IcyVeins = define("IcyVeins", { 12472 }, "IcyVeins"),
    MirrorImage = define("MirrorImage", { 55342 }, "MirrorImage"),
    PresenceOfMind = define("PresenceOfMind", { 12043 }, "PresenceOfMind"),
    Counterspell = define("Counterspell", { 2139 }, "Counterspell"),
    ConjureManaEmerald = define("ConjureManaEmerald", { 27101, 10054, 10053, 3552, 759 }, "ConjureManaEmerald"),
    -- 27125 = Mage Armor TBC max (not 27130 = Amplify Magic); 6117 = R1 (1008 = Amplify Magic).
    MageArmor = define("MageArmor", { 43024, 43023, 27125, 22783, 22782, 6117 }, "MageArmor"),
}

-- Arcane Blast stack aura: ONE stacking buff (36032) in WotLK (wowsims APL
-- counts stacks of 36032); 36033/36034/40057 are unrelated spells, not AB ranks.
local ARCANE_BLAST_BUFF = { 36032 }
local MAGE_ARMOR_BUFF = { 43024, 43023, 27125, 22783, 22782, 6117 }
-- Missile Barrage proc buff is 44401 (lexxer wotlk). 54490+ are talent ranks, not the proc aura.
local MISSILE_BARRAGE_PROC = { 44401 }
local ARCANE_POWER_BUFF = { 12042 }
local ICY_VEINS_BUFF = { 12472 }

local arcane_state = {
    mana_pct = 100,
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
    -- context.mana_pct is dispatcher-set (main_sylvanas.lua:795); me:mana_pct()
    -- is the IZI SDK unit method. me:get_mana_percentage() is mock-only (W3.3).
    state.mana_pct = (context and context.mana_pct)
        or (me and me.mana_pct and me:mana_pct())
        or (NS.unit_mana_pct and NS.unit_mana_pct(me))
        or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.arcane_blast_stacks = (me and NS.buff_stacks and NS.buff_stacks(me, ARCANE_BLAST_BUFF)) or 0
    state.missile_barrage_proc = (me and NS.buff_up and NS.buff_up(me, MISSILE_BARRAGE_PROC)) or false
    state.arcane_power_up = (me and NS.buff_up and NS.buff_up(me, ARCANE_POWER_BUFF)) or false
    state.icy_veins_up = (me and NS.buff_up and NS.buff_up(me, ICY_VEINS_BUFF)) or false
    state.mage_armor_up = (me and NS.buff_up and NS.buff_up(me, MAGE_ARMOR_BUFF)) or false
    -- Real API only: spell_action objects expose id/IsReady/IsInRange/Cast, not
    -- cooldown_remaining() (mock-only). NS.spell_ready is the production gate.
    state.pom_ready = (ACTION.PresenceOfMind and NS.spell_ready
        and NS.spell_ready(ACTION.PresenceOfMind, me, { skip_range = true })) or false
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
            -- Wowsims APL: AM is the Missile Barrage proc consumer (44401).
            { type = "state", field = "missile_barrage_proc", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.ArcaneMissiles, target = "target" },
    },
    {
        name = "ArcaneBarrage",
        conditions = {
            -- Distinct lane (W3.3): instant 4-stack dump. AB builds to 4 per the
            -- APL (stacks < 4), AM consumes procs — at the 4-stack cap with no
            -- proc, ABarrage resets the stack burden instead of competing with AM.
            { type = "state", field = "arcane_blast_stacks", op = ">=", value = 4 },
        },
        action = { type = "cast", spell = ACTION.ArcaneBarrage, target = "target" },
    },
    {
        name = "ArcaneBlast",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
            -- Wowsims APL: keep AB while the stack cap (4) is not reached.
            { type = "state", field = "arcane_blast_stacks", op = "<", value = 4 },
        },
        action = { type = "cast", spell = ACTION.ArcaneBlast, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
-- Priority order mirrors wowsims arcane APL (AB stacker > AM proc > Evoc):
-- the checker enforces ArcaneBlast before ArcaneMissiles before Evocation.
local strategies = {
    { name = "Counterspell" },
    { name = "MageArmor" },
    { name = "ArcaneBlast" },
    { name = "ArcaneMissiles" },
    { name = "ArcaneBarrage" },
    { name = "ManaGem" },
    { name = "ArcanePower" },
    { name = "IcyVeins" },
    { name = "MirrorImage" },
    { name = "PresenceOfMind" },
    { name = "Evocation" },
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
