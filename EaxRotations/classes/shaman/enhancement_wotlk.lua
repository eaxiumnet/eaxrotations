-- enhancement_wotlk.lua — Shaman Enhancement rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Enhancement shaman: Shamanistic Rage mana/CD,
--        Feral Spirit wolves, Stormstrike debuff, Lava Lash off-hand.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.ShamanSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Stormstrike = define("Stormstrike", 17364, "Stormstrike"),
    LavaLash = define("LavaLash", 60103, "LavaLash"),
    FeralSpirit = define("FeralSpirit", 51533, "FeralSpirit"),
    ShamanisticRage = define("ShamanisticRage", 30823, "ShamanisticRage"),
}

local MAELSTROM_WEAPON_BUFF = { 53817, 53816, 53815, 53814, 53813 }

local enhancement_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    maelstrom_stacks = 0,
    shamanistic_rage_ready = false,
    feral_spirit_ready = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(enhancement_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.maelstrom_stacks = (me and NS.buff_stacks and NS.buff_stacks(me, MAELSTROM_WEAPON_BUFF)) or 0
    state.shamanistic_rage_ready = (ACTION.ShamanisticRage and ACTION.ShamanisticRage.cooldown_remaining and ACTION.ShamanisticRage:cooldown_remaining() <= 0) or false
    state.feral_spirit_ready = (ACTION.FeralSpirit and ACTION.FeralSpirit.cooldown_remaining and ACTION.FeralSpirit:cooldown_remaining() <= 0) or false
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "ShamanisticRage",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "shamanistic_rage_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 60) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.ShamanisticRage, target = "self" },
    },
    {
        name = "FeralSpirit",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "feral_spirit_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.FeralSpirit, target = "target" },
    },
    {
        name = "Stormstrike",
        conditions = {},
        action = { type = "cast", spell = ACTION.Stormstrike, target = "target" },
    },
    {
        name = "LavaLash",
        conditions = {},
        action = { type = "cast", spell = ACTION.LavaLash, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "ShamanisticRage" },
    { name = "FeralSpirit" },
    { name = "Stormstrike" },
    { name = "LavaLash" },
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
    NS.rotation_registry:register("enhancement", strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman Enhancement WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
