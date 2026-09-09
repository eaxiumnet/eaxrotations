-- healing_sod.lua -- Priest healing rotation for Season of Discovery.
-- WHAT: emergency Penance, shielding, group raid heals (PoM/CoH), direct healing, and Renew upkeep.
-- WHEN: SoD runtime with an injured friendly target selected by healer context.
-- WHY:  the corpus file cast only the pinned Penance/PWS/FlashHeal/Renew core; the SoD
--       healer runes players actually engrave (Wowhead SoD healer rotation guide) --
--       Prayer of Mending (Legs rune, spell 401859) and Circle of Healing (Gloves rune,
--       402842) -- were absent. Binding Heal (Cloak engrave 402853) is deliberately NOT
--       added: its castable SoD ability id is not verifiable from available sources, and
--       guessing ids breaks the source-audit contract.
-- SAFETY: absent targets and malformed health/rune state always fail closed.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})

local ACTION = {
    Penance = define("SodPenance", 402284, { rune_id = 402174 }, "Penance"),
    -- Wowhead-verified SoD rune spells (Legs / Gloves). No rune_id gate: the
    -- engraving ids are not verifiable, and has_sod_rune with a guessed id
    -- would disable the lanes for players whose rune map keys differ.
    PrayerOfMending = define("SodPrayerOfMending", 401859, {}, "PrayerOfMending"),
    CircleOfHealing = define("SodCircleOfHealing", 402842, {}, "CircleOfHealing"),
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
        party_injured_count = type(context) == "table" and context.party_injured_count or nil,
    }, { lowest_hp = 100, party_injured_count = 0 })
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
    -- Circle of Healing: raid heal for group damage (2+ injured allies), the
    -- party_injured_count engine gate mirroring holy_wotlk's parse-critical
    -- CoH lane. Fires in the shared priest_wotlk_circle_healing battery
    -- scenario (inherited by SCENARIOS_SOD).
    heal_strategy("CircleOfHealing", ACTION.CircleOfHealing, 65, function(state)
        return state ~= nil and (state.party_injured_count or 0) >= 2
    end),
    -- Prayer of Mending: efficient bounce heal filling the band above the PWS
    -- threshold, before raw FlashHeal throughput.
    heal_strategy("PrayerOfMending", ACTION.PrayerOfMending, 60),
    heal_strategy("FlashHeal", ACTION.FlashHeal, 70),
    heal_strategy("Renew", ACTION.Renew, 90),
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("healing", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
