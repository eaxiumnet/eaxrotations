-- retribution_sod.lua -- Paladin Retribution rotation for Season of Discovery.
-- WHAT: p8 Exodin core priority with rune-aware melee fillers.
-- WHEN: SoD combat with a valid hostile target.
-- WHY: keeps Divine Storm and Exorcism ordering aligned with the pinned APL.
-- SAFETY: malformed phase/rune state disables actions without touching legacy specs.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})

local ACTION = {
    DivineStorm = define("SodDivineStorm", 407778, { rune_id = 407778 }, "DivineStorm"),
    Exorcism = define("SodExorcism", 415073, { min_phase = 2 }, "Exorcism"),
    CrusaderStrike = define("SodCrusaderStrike", 407676, { rune_id = 407676 }, "CrusaderStrike"),
}

local function build_state()
    return spec_kit.safe_state({}, {})
end

local function action_strategy(name, descriptor)
    return {
        name = name,
        matches = function(context)
            return type(context) == "table"
                and context.is_sod == true
                and context.in_combat == true
                and context.target ~= nil
                and spec_kit.sod_action_available(context, descriptor)
        end,
        execute = function(context)
            return NS.try_cast(descriptor.action, context.target, "[SOD RETRIBUTION] " .. name)
        end,
    }
end

local strategies = {
    action_strategy("DivineStorm", ACTION.DivineStorm),
    action_strategy("Exorcism", ACTION.Exorcism),
    action_strategy("CrusaderStrike", ACTION.CrusaderStrike),
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("retribution", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
