-- protection_sod.lua -- Paladin Protection rotation for Season of Discovery.
-- WHAT: emergency defensives followed by the pinned p5 protection priority.
-- WHEN: SoD combat while tanking a valid hostile target.
-- WHY: preserves survival ordering before threat and damage actions.
-- SAFETY: health and Holy Shield charge reads are nil-safe; runes fail closed.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")

local ACTION = {
    HammerOfJustice = define("HammerOfJustice", { 10308, 5589, 5588, 853 }, {}, "HammerOfJustice"),
    LayOnHands = define("SodLayOnHands", 10310, {}, "LayOnHands"),
    DivineProtection = define("SodDivineProtection", 458371, { rune_id = 458318, min_phase = 4 }, "DivineProtection"),
    HolyShield = define("SodHolyShield", 20928, {}, "HolyShield"),
    AvengersShield = define("SodAvengersShield", 407669, { rune_id = 407669 }, "AvengersShield"),
    HammerOfTheRighteous = define("SodHammerOfTheRighteous", 407632, { rune_id = 407632, min_phase = 3 }, "HammerOfTheRighteous"),
    Exorcism = define("SodExorcism", 415073, { min_phase = 2 }, "Exorcism"),
    ShieldOfRighteousness = define("SodShieldOfRighteousness", 440658, { rune_id = 440658, min_phase = 4 }, "ShieldOfRighteousness"),
    -- Guide priority: baseline Seal of Martyrdom upkeep (348700, same id
    -- the retri_sod seal lane carries) and seal-gated Judgement on CD.
    SealMartyr = define("SodSealMartyr", 348700, {}, "SealMartyr"),
    Judgement = define("SodJudgement", 20271, {}, "Judgement"),
}
local HOLY_SHIELD_BUFF = { 20928 }
local SEAL_MARTYR_BUFF = { 348700 }

-- Seal of Martyrdom drains caster HP per swing (era-correct martyr
-- mechanic): hold the refresh lane while dangerously low so the upkeep
-- itself cannot kill the tank.
local SEAL_HP_FLOOR = 15
-- Seal resolution mirrors retribution_sod: the real read path is the
-- player buff map via NS.buff_up, not a context field.
local function seal_buff_up()
    if type(NS.buff_up) ~= "function" then return false end
    local ok, up = pcall(NS.buff_up, NS.GetPlayer and NS.GetPlayer() or nil, SEAL_MARTYR_BUFF)
    if ok then return up == true end
    return false
end

local function build_state(context)
    local charges = context and context.holy_shield_charges or nil
    if charges == nil and NS.buff_points then
        local points = NS.buff_points(NS.GetPlayer and NS.GetPlayer() or nil, HOLY_SHIELD_BUFF)
        charges = points and points[1] or nil
    end
    return spec_kit.safe_state({
        hp_pct = context and (context.hp_pct or context.hp) or nil,
        holy_shield_charges = charges,
        seal_up = seal_buff_up(),
    }, { hp_pct = 100, holy_shield_charges = 0 })
end

local function available(context, descriptor)
    return type(context) == "table"
        and context.is_sod == true
        and context.in_combat == true
        and context.target ~= nil
        and spec_kit.sod_action_available(context, descriptor)
end

local function target_strategy(name, descriptor)
    return {
        name = name,
        matches = function(context) return available(context, descriptor) end,
        execute = function(context)
            return NS.try_cast(descriptor.action, context.target, "[SOD PROTECTION] " .. name)
        end,
    }
end

local strategies = {
    -- Shared interrupt-manager lane (strategy #1 -- must beat casts).
    (interrupt_manager and interrupt_manager.register_interrupt_spell
        and interrupt_manager.register_interrupt_spell("paladin", "HammerOfJustice", { HammerOfJustice = ACTION.HammerOfJustice.action }))
        or { name = "HammerOfJusticeSkip", matches = function() return false end, execute = function() return false end },
    -- Seal upkeep (guide: keep Martyrdom up for holy procs + mana return).
    -- No target needed; fails safe at the martyr HP floor.
    { name = "SealMartyr", matches = function(context, state)
        return available(context, ACTION.SealMartyr, false)
            and (state and state.seal_up or false) ~= true
            and (state and state.hp_pct or 100) > SEAL_HP_FLOOR
    end, execute = function(context)
        return NS.try_cast(ACTION.SealMartyr.action, NS.PLAYER_UNIT, "[SOD PROTECTION] SealMartyr", { skip_range = true })
    end },
    {
        name = "LayOnHands",
        matches = function(context, state)
            return (state and state.hp_pct or 100) < 10 and available(context, ACTION.LayOnHands)
        end,
        execute = function()
            return NS.try_cast(ACTION.LayOnHands.action, NS.PLAYER_UNIT, "[SOD PROTECTION] LayOnHands", { skip_range = true })
        end,
    },
    {
        name = "DivineProtection",
        matches = function(context, state)
            return (state and state.hp_pct or 100) < 40 and available(context, ACTION.DivineProtection)
        end,
        execute = function()
            return NS.try_cast(ACTION.DivineProtection.action, NS.PLAYER_UNIT, "[SOD PROTECTION] DivineProtection", { skip_range = true })
        end,
    },
    {
        name = "HolyShield",
        matches = function(context, state)
            return (state and state.holy_shield_charges or 0) <= 2 and available(context, ACTION.HolyShield)
        end,
        execute = function()
            return NS.try_cast(ACTION.HolyShield.action, NS.PLAYER_UNIT, "[SOD PROTECTION] HolyShield", { skip_range = true })
        end,
    },
    -- Judgement on cooldown with the seal up (the upkeep lane refreshes
    -- first when it is down); the battery's sod_seal_up scenario
    -- presents the seal-buff window.
    { name = "Judgement", matches = function(context, state)
        return available(context, ACTION.Judgement, true) and (state and state.seal_up or false) == true
    end, execute = function(context)
        return NS.try_cast(ACTION.Judgement.action, context.target, "[SOD PROTECTION] Judgement")
    end },
    target_strategy("AvengersShield", ACTION.AvengersShield),
    target_strategy("HammerOfTheRighteous", ACTION.HammerOfTheRighteous),
    target_strategy("Exorcism", ACTION.Exorcism),
    target_strategy("ShieldOfRighteousness", ACTION.ShieldOfRighteousness),
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("protection", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
