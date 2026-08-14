-- frost_wotlk.lua — Mage Frost rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Frost mage: ColdSnap panic heal, DeepFreeze
--        on frozen targets OR Fingers of Frost, FrostfireBolt debuff (44549)
--        refresh, IceLance on frozen/FoF, Frostbolt filler.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors wowsims APL (ui/mage/apls/frost.apl.json — pinned fixture):
--        DeepFreeze on aura 44545 (FoF), FFB on debuff 44549, Frostbolt filler.
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
    -- Frostbolt: full rank ladder, max-first (42842 = 3.3.5 max; the old ladder
    -- carried 10175/10176 Dampen Magic + 10177 Frost Ward — wrong-family).
    Frostbolt = define("Frostbolt", { 42842, 27072, 27071, 25304, 10181, 10180, 10179, 8408, 8407, 8406, 7322, 837, 205, 116 }, "Frostbolt"),
    FrostfireBolt = define("FrostfireBolt", 47610, "FrostfireBolt"), -- 47610 = max-rank FFB (44614 = rank 1)
    IceLance = define("IceLance", { 42914, 30455 }, "IceLance"),
    DeepFreeze = define("DeepFreeze", 44572, "DeepFreeze"),
    ColdSnap = define("ColdSnap", 11958, "ColdSnap"),
    Counterspell = define("Counterspell", { 2139 }, "Counterspell"),
}

-- 44549 = the Frostfire Bolt DEBUFF aura (wowsims APL refreshes FFB on it);
-- 47610 is the CAST spell id, not a debuff (the old table was wrong).
local FROSTFIRE_BOLT_DEBUFF = { 44549 }
-- Frost Nova root family incl. the WotLK max rank 42917 (W3.3 fix: without it
-- a WotLK-rank Nova root was invisible to the frozen check).
local FROST_NOVA_DEBUFF = { 122, 865, 6131, 10230, 42917 }
-- Fingers of Frost proc buff (wowsims APL gates DeepFreeze on aura 44545).
local FINGERS_OF_FROST_BUFF = { 44545 }

local frost_state = {
    hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    frostfire_remains = 0,
    target_frozen = false,
    target_is_casting = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(frost_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    -- context.hp / context.mana_pct are dispatcher-set; me:mana_pct() is the
    -- IZI SDK unit method (me:get_mana_percentage() is mock-only, W3.3).
    state.hp = (context and context.hp)
        or (me and me.get_health_percentage and me:get_health_percentage())
        or 100
    state.mana_pct = (context and context.mana_pct)
        or (me and me.mana_pct and me:mana_pct())
        or (NS.unit_mana_pct and NS.unit_mana_pct(me))
        or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.frostfire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FROSTFIRE_BOLT_DEBUFF)) or 0
    -- Frozen = target rooted by the Frost Nova family (incl. WotLK 42917) OR
    -- the Fingers of Frost proc (44545) — the wowsims DeepFreeze gate.
    state.target_frozen = (target and NS.debuff_up and NS.debuff_up(target, FROST_NOVA_DEBUFF))
        or (me and NS.buff_up and NS.buff_up(me, FINGERS_OF_FROST_BUFF))
        or false
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
        name = "ColdSnap",
        conditions = {
            { type = "state", field = "hp", op = "<", value = 50 },
        },
        action = { type = "cast", spell = ACTION.ColdSnap, target = "self" },
    },
    {
        name = "DeepFreeze",
        conditions = {
            { type = "state", field = "target_frozen", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.DeepFreeze, target = "target" },
    },
    {
        name = "FrostfireBolt",
        conditions = {
            { type = "state", field = "frostfire_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.FrostfireBolt, target = "target" },
    },
    {
        name = "IceLance",
        conditions = {
            { type = "state", field = "target_frozen", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.IceLance, target = "target" },
    },
    {
        name = "Frostbolt",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Frostbolt, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "Counterspell" },
    { name = "ColdSnap" },
    { name = "DeepFreeze" },
    { name = "FrostfireBolt" },
    { name = "IceLance" },
    { name = "Frostbolt" },
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

-- Register (guarded — nil-safe in unit tests)
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("frost", strategies, { get_state = build_state })
end
if NS.log then NS.log("Mage Frost WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
