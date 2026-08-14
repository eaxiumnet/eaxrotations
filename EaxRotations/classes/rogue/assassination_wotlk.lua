-- assassination_wotlk.lua — Rogue Assassination rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Assassination rogue.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); Mutilate dagger
--         gate (has_daggers); WotLK max-rank debuff ids (48672/57970) tracked
--         literally; energy/combo read context first; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local read_combo_points = require("shared/combo_points_reader_sylvanas")

-- Dagger set for the Mutilate eligibility check (mirrors the TBC sibling).
local _dagger_set_ok, dagger_set = pcall(require, "shared/dagger_set_sylvanas")
if not _dagger_set_ok then dagger_set = nil end

-- Plain define_action (fire_wotlk precedent): define_action_for_class would
-- shadow the file-local WotLK rank lists with the TBC-era NS.RogueSpells
-- entries, so the WotLK max-rank ids (48666/57993/48672) would never be cast.
local define = spec_kit.define_action

local ACTION = {
    HungerForBlood = define("HungerForBlood", 51662, "HungerForBlood"),
    Mutilate = define("Mutilate", { 48666, 34413, 34412, 34411, 1329 }, "Mutilate"),
    Envenom = define("Envenom", { 57993, 32645, 32684 }, "Envenom"),
    Rupture = define("Rupture", { 48672, 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, "Rupture"),
    TricksOfTheTrade = define("TricksOfTheTrade", 57934, "TricksOfTheTrade"),
    SliceAndDice = define("SliceAndDice", { 6774, 5171 }, "SliceAndDice"),
    -- Baseline rogue interrupt (3.3.5); not in the mutilate APL fixture.
    Kick = define("Kick", { 38768, 1769, 1768, 1767, 1766 }, "Kick"),
}

-- WotLK max-rank Rupture (48672) first: literal ID matching — a max-level
-- WotLK client applies the 48672 debuff, and the table must see it or the
-- lane re-applies Rupture every tick.
local RUPTURE_DEBUFF = { 48672, 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local SLICE_AND_DICE_BUFF = { 6774, 5171 }
-- WotLK Deadly Poison IX/VIII apply+DoT ids (wowhead WotLK Classic
-- spell=57970/57969, DoT stacking debuff on the target). TBC-era poison ids
-- are absent from the WotLK bridge and are NOT tracked here — the max-rank
-- application is the parse-relevant stack source for Envenom.
local DEADLY_POISON_DEBUFF = { 57970, 57969 }
-- Envenom grants a self-buff with the same id as the cast spell (57993);
-- wowsims mutilate APL gates re-Envenom on `not buff.envenom.up or energy>=85`.
local ENVENOM_BUFF = { 57993 }
local HUNGER_FOR_BLOOD_BUFF = { 51662 }

local assassination_state = {
    energy = 0,
    combo_points = 0,
    enemy_count = 1,
    in_combat = false,
    rupture_remains = 0,
    snd_remains = 0,
    dp_stacks = 0,
    envenom_buff_up = false,
    hfb_up = false,
    has_daggers = false,
    target_is_casting = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(assassination_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    -- context.energy / context.combo_points are engine-populated real fields
    -- (main_sylvanas.lua:816/878); me:get_energy()/get_combo_points() are
    -- mock-only unit methods and collapse to 0 in live play.
    state.energy = (context and context.energy) or (me and me.get_power and me:get_power(NS.POWER_ENERGY or 3)) or 0
    state.combo_points = (context and context.combo_points) or (me and read_combo_points and read_combo_points(me, NS.POWER_COMBO or 4)) or 0
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.target_is_casting = (target and target.is_casting and target:is_casting()) or false
    state.rupture_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RUPTURE_DEBUFF)) or 0
    state.snd_remains = (me and NS.buff_remains and NS.buff_remains(me, SLICE_AND_DICE_BUFF)) or 0
    state.dp_stacks = (target and NS.get_debuff_stacks and NS.get_debuff_stacks(target, DEADLY_POISON_DEBUFF)) or 0
    state.envenom_buff_up = (me and NS.buff_up and NS.buff_up(me, ENVENOM_BUFF)) or false
    state.hfb_up = (me and NS.buff_up and NS.buff_up(me, HUNGER_FOR_BLOOD_BUFF)) or false
    -- Dagger check: Mutilate requires daggers in BOTH hands (TBC sibling
    -- convention — dagger_set.is_dagger map over equipped item ids).
    local main_id, off_id
    if NS.get_equipped_item_id and NS.EQUIPMENT_SLOTS then
        main_id = NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.MAIN_HAND)
        off_id  = NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.OFF_HAND)
    end
    local is_dagger = dagger_set and dagger_set.is_dagger or {}
    state.has_daggers = (main_id and main_id ~= 0 and is_dagger[main_id])
        and (off_id and off_id ~= 0 and is_dagger[off_id])
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "Kick",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_casting", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Kick, target = "target" },
    },
    {
        name = "TricksOfTheTrade",
        conditions = {
            -- APL gate (mutilate.apl.json): ToTT is used at <= 50 energy so
            -- it never delays a builder.
            { type = "state", field = "energy", op = "<=", value = 50 },
        },
        action = { type = "cast", spell = ACTION.TricksOfTheTrade, target = "self" },
    },
    {
        name = "HungerForBlood",
        conditions = {
            -- Upkeep only: re-apply when the HfB buff is down (APL
            -- mutilate.apl.json `if=buff.hunger_for_blood.remains<=1`).
            { type = "state", field = "hfb_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.HungerForBlood, target = "target" },
    },
    {
        name = "SliceAndDice",
        conditions = {
            { type = "state", field = "snd_remains", op = "<", value = 3 },
            { type = "state", field = "combo_points", op = ">=", value = 1 },
        },
        action = { type = "cast", spell = ACTION.SliceAndDice, target = "self" },
    },
    {
        name = "Rupture",
        conditions = {
            { type = "state", field = "rupture_remains", op = "<", value = 3 },
            { type = "state", field = "combo_points", op = ">=", value = 1 },
        },
        action = { type = "cast", spell = ACTION.Rupture, target = "target" },
    },
    {
        name = "Envenom",
        conditions = {
            { type = "state", field = "combo_points", op = ">=", value = 4 },
            -- Deadly Poison stack management: Envenom consumes DP stacks and
            -- hits ~50% harder per stack — never Envenom without the poison
            -- stacked (mirrors the TBC sibling's dp_stacks >= min gate).
            { type = "state", field = "dp_stacks", op = ">=", value = 3 },
            -- Envenom buff management (APL mutilate.apl.json): keep the
            -- Envenom buff rolling — refresh only when it is down, or when
            -- pooling at >= 85 energy.
            { type = "custom", fn = function(context, state)
                if state.envenom_buff_up then
                    return (state.energy or 0) >= 85
                end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Envenom, target = "target" },
    },
    {
        name = "Mutilate",
        conditions = {
            { type = "state", field = "energy", op = ">=", value = 60 },
            -- Mutilate requires daggers in both hands; without the gate the
            -- lane queues failed casts for non-dagger players. When blocked,
            -- the rotation degrades to the fallback filler lanes.
            { type = "state", field = "has_daggers", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Mutilate, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL). Priority preserved.
-- -----------------------------------------------------------------------------
-- Priority order mirrors wowsims mutilate APL (ui/rogue/apls/mutilate.apl.json):
-- SnD > HfB > Tricks > Envenom > Mutilate (Rupture unconstrained by fixture,
-- kept after SnD maintenance).
-- Kick is a baseline interrupt, not in the mutilate APL fixture — first,
-- outside the pinned order.
local strategies = {
    { name = "Kick" },
    { name = "SliceAndDice" },
    { name = "Rupture" },
    { name = "HungerForBlood" },
    { name = "TricksOfTheTrade" },
    { name = "Envenom" },
    { name = "Mutilate" },
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
    NS.rotation_registry:register("assassination", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
