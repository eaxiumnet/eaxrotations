-- dps_mage_sod.lua -- Mage DPS rotation for Season of Discovery.
-- WHAT: source-ordered mana recovery, rune cooldowns, and spellfrost fillers.
-- WHEN: SoD combat with a valid hostile target.
-- WHY: translates the pinned p5 spellfrost APL into native EAX strategies.
-- SAFETY: every action is phase/rune gated and state reads have safe defaults.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})

local ACTION = {
    Evocation = define("SodEvocation", 12051, {}, "Evocation"),
    FrozenOrb = define("SodFrozenOrb", 440802, { rune_id = 440802, min_phase = 4 }, "FrozenOrb"),
    BalefireBolt = define("SodBalefireBolt", 428878, { rune_id = 428878, min_phase = 3 }, "BalefireBolt"),
    SpellfrostBolt = define("SodSpellfrostBolt", 412532, { rune_id = 412532, min_phase = 2 }, "SpellfrostBolt"),
    FrostfireBolt = define("SodFrostfireBolt", 401502, { rune_id = 401502, min_phase = 2 }, "FrostfireBolt"),
    Frostbolt = define("SodFrostbolt", 10181, {}, "Frostbolt"),
}

local function build_state(context)
    return spec_kit.safe_state({
        mana_pct = context and context.mana_pct or nil,
    }, { mana_pct = 100 })
end

local function combat_action_matches(context, descriptor)
    return type(context) == "table"
        and context.is_sod == true
        and context.in_combat == true
        and context.target ~= nil
        and spec_kit.sod_action_available(context, descriptor)
end

local function action_strategy(name, descriptor)
    return {
        name = name,
        matches = function(context) return combat_action_matches(context, descriptor) end,
        execute = function(context)
            return NS.try_cast(descriptor.action, context.target, "[SOD MAGE] " .. name)
        end,
    }
end

local strategies = {
    {
        name = "Evocation",
        matches = function(context, state)
            return (state and state.mana_pct or 100) <= 15
                and combat_action_matches(context, ACTION.Evocation)
        end,
        execute = function()
            return NS.try_cast(ACTION.Evocation.action, NS.PLAYER_UNIT, "[SOD MAGE] Evocation", { skip_range = true })
        end,
    },
    action_strategy("FrozenOrb", ACTION.FrozenOrb),
    action_strategy("BalefireBolt", ACTION.BalefireBolt),
    action_strategy("SpellfrostBolt", ACTION.SpellfrostBolt),
    action_strategy("FrostfireBolt", ACTION.FrostfireBolt),
    action_strategy("Frostbolt", ACTION.Frostbolt),
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("dps_mage", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
