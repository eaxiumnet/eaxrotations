-- shadow_sod.lua -- Priest Shadow rotation for Season of Discovery.
-- WHAT: phase 6 DoT setup, cooldowns, and Mind Flay/Mind Spike fillers.
-- WHEN: SoD combat with a valid hostile target.
-- WHY: translates the pinned phase_6 shadow APL in source priority order.
-- SAFETY: DoT timers, phase, and rune reads are nil-safe and fail closed.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})

local ACTION = {
    VoidPlague = define("SodVoidPlague", 425204, { rune_id = 425204, min_phase = 2 }, "VoidPlague"),
    ShadowWordPain = define("SodShadowWordPain", 10894, {}, "ShadowWordPain"),
    VampiricTouch = define("SodVampiricTouch", 402668, { rune_id = 402668, min_phase = 4 }, "VampiricTouch"),
    DevouringPlague = define("SodDevouringPlague", 19280, {}, "DevouringPlague"),
    MindBlast = define("SodMindBlast", 10947, {}, "MindBlast"),
    Homunculi = define("SodHomunculi", 402799, { rune_id = 402799, min_phase = 1 }, "Homunculi"),
    Shadowfiend = define("SodShadowfiend", 401977, { min_phase = 3 }, "Shadowfiend"),
    MindFlay = define("SodMindFlay", 18807, {}, "MindFlay"),
    MindSpike = define("SodMindSpike", 431655, { rune_id = 431655, min_phase = 2 }, "MindSpike"),
}
local VOID_PLAGUE_DEBUFF = { 425204 }
local SHADOW_WORD_PAIN_DEBUFF = { 10894 }
local VAMPIRIC_TOUCH_DEBUFF = { 402668 }
local DEVOURING_PLAGUE_DEBUFF = { 19280 }

local function dot_remains(context, field, spell_ids)
    if context and context[field] ~= nil then return context[field] end
    local target = context and context.target or nil
    if target and NS.debuff_remains then return NS.debuff_remains(target, spell_ids) or 0 end
    return 0
end

local function build_state(context)
    return spec_kit.safe_state({
        void_plague_remains = dot_remains(context, "void_plague_remains", VOID_PLAGUE_DEBUFF),
        shadow_word_pain_remains = dot_remains(context, "shadow_word_pain_remains", SHADOW_WORD_PAIN_DEBUFF),
        vampiric_touch_remains = dot_remains(context, "vampiric_touch_remains", VAMPIRIC_TOUCH_DEBUFF),
        devouring_plague_remains = dot_remains(context, "devouring_plague_remains", DEVOURING_PLAGUE_DEBUFF),
    }, {
        void_plague_remains = 0,
        shadow_word_pain_remains = 0,
        vampiric_touch_remains = 0,
        devouring_plague_remains = 0,
    })
end

local function available(context, descriptor)
    return type(context) == "table"
        and context.is_sod == true
        and context.in_combat == true
        and context.target ~= nil
        and spec_kit.sod_action_available(context, descriptor)
end

local function action_strategy(name, descriptor, remains_field)
    return {
        name = name,
        matches = function(context, state)
            if remains_field and (state and state[remains_field] or 0) > 0 then return false end
            return available(context, descriptor)
        end,
        execute = function(context)
            return NS.try_cast(descriptor.action, context.target, "[SOD SHADOW] " .. name)
        end,
    }
end

local strategies = {
    action_strategy("VoidPlague", ACTION.VoidPlague, "void_plague_remains"),
    action_strategy("ShadowWordPain", ACTION.ShadowWordPain, "shadow_word_pain_remains"),
    action_strategy("VampiricTouch", ACTION.VampiricTouch, "vampiric_touch_remains"),
    action_strategy("DevouringPlague", ACTION.DevouringPlague, "devouring_plague_remains"),
    action_strategy("MindBlast", ACTION.MindBlast),
    action_strategy("Homunculi", ACTION.Homunculi),
    action_strategy("Shadowfiend", ACTION.Shadowfiend),
    action_strategy("MindFlay", ACTION.MindFlay),
    action_strategy("MindSpike", ACTION.MindSpike),
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("shadow", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
