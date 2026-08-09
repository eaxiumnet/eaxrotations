-- combat_wotlk.lua — Rogue Combat rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Combat rogue.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.RogueSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    SliceAndDice = define("SliceAndDice", { 6774, 5171 }, "SliceAndDice"),
    SinisterStrike = define("SinisterStrike", { 48638, 26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 }, "SinisterStrike"),
    Eviscerate = define("Eviscerate", { 48668, 26865, 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, "Eviscerate"),
    BladeFlurry = define("BladeFlurry", 13877, "BladeFlurry"),
    KillingSpree = define("KillingSpree", 51690, "KillingSpree"),
}

local SLICE_AND_DICE_BUFF = { 6774, 5171 }

local combat_state = {
    hp = 100,
    target_hp = 100,
    energy = 0,
    combo_points = 0,
    enemy_count = 1,
    in_combat = false,
    snd_remains = 0,
    blade_flurry_ready = false,
    killing_spree_ready = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(combat_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.energy = (me and me.get_energy and me:get_energy()) or 0
    state.combo_points = (me and me.get_combo_points and me:get_combo_points()) or 0
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.snd_remains = (me and NS.buff_remains and NS.buff_remains(me, SLICE_AND_DICE_BUFF)) or 0
    state.blade_flurry_ready = (ACTION.BladeFlurry and ACTION.BladeFlurry.cooldown_remaining and ACTION.BladeFlurry:cooldown_remaining() <= 0) or false
    state.killing_spree_ready = (ACTION.KillingSpree and ACTION.KillingSpree.cooldown_remaining and ACTION.KillingSpree:cooldown_remaining() <= 0) or false
    return state
end

local DSL_DEFS = {
    {
        name = "SliceAndDice",
        conditions = {
            { type = "state", field = "snd_remains", op = "<=", value = 1 },
            { type = "state", field = "combo_points", op = ">=", value = 1 },
        },
        action = { type = "cast", spell = ACTION.SliceAndDice, target = "self" },
    },
    {
        name = "BladeFlurry",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "blade_flurry_ready", op = "truthy" },
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 120) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.BladeFlurry, target = "self" },
    },
    {
        name = "KillingSpree",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "killing_spree_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 120) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.KillingSpree, target = "target" },
    },
    {
        name = "Eviscerate",
        conditions = {
            { type = "state", field = "combo_points", op = ">=", value = 4 },
        },
        action = { type = "cast", spell = ACTION.Eviscerate, target = "target" },
    },
    {
        name = "SinisterStrike",
        conditions = {
            { type = "state", field = "energy", op = ">=", value = 45 },
        },
        action = { type = "cast", spell = ACTION.SinisterStrike, target = "target" },
    },
}

-- Priority order mirrors wowsims combat APL (ui/rogue/apls/combat.apl.json):
-- SnD > Eviscerate > BladeFlurry > KillingSpree > SinisterStrike.
local strategies = {
    { name = "SliceAndDice" },
    { name = "Eviscerate" },
    { name = "BladeFlurry" },
    { name = "KillingSpree" },
    { name = "SinisterStrike" },
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
    NS.rotation_registry:register("combat", strategies, { get_state = build_state })
end
if NS.log then NS.log("Rogue combat rotation registered") end

return { strategies = strategies, build_state = build_state }
