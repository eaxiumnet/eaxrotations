-- combat_sod.lua -- Rogue Combat DPS rotation for Season of Discovery.
-- WHAT:  poison-aware Mutilate/Saber DPS with finishers and Fan of Knives AoE.
-- WHEN:  SoD runtime with a valid hostile target and equipped action runes.
-- WHY:   follows the pinned wowsims/sod phase-6 Mutilate and Saber priorities.
-- SAFETY: action availability fails closed through spec_kit; no frame allocations.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.RogueSpells or {}
local define = spec_kit.define_sod_action_for_class(SPELLS)

local FAN_OF_KNIVES_ID = 409240
local ACTION = {
    FanOfKnives = define("FanOfKnives", FAN_OF_KNIVES_ID, {
        rune_id = FAN_OF_KNIVES_ID, min_phase = 4,
    }, "FanOfKnives"),
    CrimsonTempest = define("CrimsonTempest", 412096, { rune_id = 412096, min_phase = 4 }, "CrimsonTempest"),
    SliceAndDice = define("SliceAndDice", { 6774, 5171 }, nil, "SliceAndDice"),
    Envenom = define("Envenom", 399963, { rune_id = 399963 }, "Envenom"),
    Mutilate = define("Mutilate", 399956, { rune_id = 399956 }, "Mutilate"),
    SaberSlash = define("SaberSlash", 424785, { rune_id = 424785 }, "SaberSlash"),
    PoisonedKnife = define("PoisonedKnife", 425012, { rune_id = 425012, min_phase = 2 }, "PoisonedKnife"),
}

local function build_state(context)
    local state = {
        enemy_count = context and (context.enemy_count or context.enemies_count) or 0,
        combo_points = context and context.combo_points or 0,
        energy = context and context.energy or 0,
        poison_stacks = context and (context.poison_stacks or context.deadly_poison_stacks) or 0,
        target_poisoned = context and context.target_poisoned == true or false,
        snd_remains = context and context.snd_remains or 0,
        crimson_tempest_remains = context and context.crimson_tempest_remains or 0,
        remaining_time = context and (context.remaining_time or context.target_ttd or context.ttd) or 0,
    }
    return spec_kit.safe_state(state, {
        enemy_count = 0, combo_points = 0, energy = 0, poison_stacks = 0,
        target_poisoned = false, snd_remains = 0, crimson_tempest_remains = 0, remaining_time = 0,
    })
end

local function available(context, descriptor)
    return type(context) == "table" and context.is_sod == true and context.target ~= nil
        and spec_kit.sod_action_available(context, descriptor)
end

local function fan_of_knives_matches(context, state)
    if (state and state.enemy_count or 0) < 2 then return false end
    return available(context, ACTION.FanOfKnives)
end

local strategies = {
    {
        name = "FanOfKnives",
        matches = fan_of_knives_matches,
        execute = function(context)
            return NS.try_cast(ACTION.FanOfKnives.action, context.target, "[SOD COMBAT] FanOfKnives")
        end,
    },
    { name = "CrimsonTempest", matches = function(context, state)
        return available(context, ACTION.CrimsonTempest) and state.enemy_count >= 2
            and state.combo_points >= 4 and state.crimson_tempest_remains < 2
    end, execute = function(context)
        return NS.try_cast(ACTION.CrimsonTempest.action, context.target, "[SOD COMBAT] CrimsonTempest")
    end },
    { name = "SliceAndDice", matches = function(context, state)
        return available(context, ACTION.SliceAndDice) and state.combo_points >= 4 and state.snd_remains < 1
    end, execute = function(context)
        return NS.try_cast(ACTION.SliceAndDice.action, context.target, "[SOD COMBAT] SliceAndDice")
    end },
    { name = "Envenom", matches = function(context, state)
        return available(context, ACTION.Envenom) and state.poison_stacks > 0
            and (state.combo_points >= 5
                or (state.combo_points >= 3 and state.remaining_time > 0 and state.remaining_time <= 4)
                or (state.combo_points >= 4 and state.energy >= 70))
    end, execute = function(context)
        return NS.try_cast(ACTION.Envenom.action, context.target, "[SOD COMBAT] Envenom")
    end },
    { name = "PoisonedKnife", matches = function(context, state)
        return available(context, ACTION.PoisonedKnife) and state.combo_points < 5
            and state.poison_stacks >= 4 and state.energy <= 80
    end, execute = function(context)
        return NS.try_cast(ACTION.PoisonedKnife.action, context.target, "[SOD COMBAT] PoisonedKnife")
    end },
    { name = "Mutilate", matches = function(context, state)
        return available(context, ACTION.Mutilate) and state.combo_points <= 3
            and context.dual_daggers ~= false
    end, execute = function(context)
        return NS.try_cast(ACTION.Mutilate.action, context.target, "[SOD COMBAT] Mutilate")
    end },
    { name = "SaberSlash", matches = function(context, state)
        return available(context, ACTION.SaberSlash)
            and (state.combo_points <= 2
                or (state.combo_points < 5 and state.energy >= 75))
    end, execute = function(context)
        return NS.try_cast(ACTION.SaberSlash.action, context.target, "[SOD COMBAT] SaberSlash")
    end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("combat", strategies, { get_state = build_state })
end

return {
    strategies = strategies,
    build_state = build_state,
    action = ACTION.FanOfKnives,
    actions = ACTION,
}
