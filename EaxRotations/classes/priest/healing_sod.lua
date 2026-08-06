-- healing_sod.lua -- Priest healing rotation for Season of Discovery.
-- WHAT: emergency Penance, shielding, direct healing, and Renew triage.
-- WHEN: SoD runtime with an injured friendly target selected by healer context.
-- WHY: adds the pinned source's implemented Penance path to native healer safety.
-- SAFETY: absent targets and malformed health/rune state always fail closed.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})

local ACTION = {
    Penance = define("SodPenance", 402284, { rune_id = 402174 }, "Penance"),
    PowerWordShield = define("SodPowerWordShield", 10901, {}, "PowerWordShield"),
    FlashHeal = define("SodFlashHeal", 10917, {}, "FlashHeal"),
    Renew = define("SodRenew", 10929, {}, "Renew"),
}

local function build_state(context)
    local lowest = context and context.lowest or nil
    return spec_kit.safe_state({
        heal_target = lowest and lowest.unit or nil,
        lowest_hp = lowest and (lowest.effective_hp or lowest.hp) or nil,
        has_weakened_soul = lowest and lowest.has_weakened_soul == true or false,
    }, { lowest_hp = 100 })
end

local function heal_matches(context, state, descriptor, threshold)
    return type(context) == "table"
        and context.is_sod == true
        and state ~= nil
        and state.heal_target ~= nil
        and (state.lowest_hp or 100) <= threshold
        and spec_kit.sod_action_available(context, descriptor)
end

local function heal_strategy(name, descriptor, threshold, extra_gate)
    return {
        name = name,
        matches = function(context, state)
            if extra_gate and not extra_gate(state) then return false end
            return heal_matches(context, state, descriptor, threshold)
        end,
        execute = function(context)
            local lowest = context and context.lowest or nil
            local target = lowest and lowest.unit or nil
            if not target then return false end
            return NS.try_cast(descriptor.action, target, "[SOD HEALING] " .. name)
        end,
    }
end

local strategies = {
    heal_strategy("Penance", ACTION.Penance, 40),
    heal_strategy("PowerWordShield", ACTION.PowerWordShield, 55, function(state)
        return state ~= nil and state.has_weakened_soul ~= true
    end),
    heal_strategy("FlashHeal", ACTION.FlashHeal, 70),
    heal_strategy("Renew", ACTION.Renew, 90),
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("healing", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
