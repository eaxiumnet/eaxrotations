-- retribution_sod.lua -- Paladin Retribution rotation for Season of Discovery.
-- WHAT: p8 Exodin core priority (Divine Storm > Exorcism > Crusader Strike,
--       the pinned APL order) plus the guide-priority lanes the file lacked:
--       Seal of Martyrdom upkeep, Judgement with the seal up, the opt-in
--       Avenging Wrath burst, the Hammer of Wrath execute band, and AoE
--       Consecration (Icy-Veins/Wowhead SoD p8 retribution priority, 2025).
-- WHEN: SoD combat with a valid hostile target (self-cast lanes excepted).
-- WHY:  keeps Divine Storm and Exorcism ordering aligned with the pinned APL
--       while covering the full published playstyle instead of 3 GCDs.
-- SAFETY: malformed phase/rune state disables actions without touching legacy
--       specs; every state read is nil-safe via spec_kit.safe_state and the
--       central try_cast guard still owns cooldown/resource/range.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")

local ACTION = {
    HammerOfJustice = define("HammerOfJustice", { 10308, 5589, 5588, 853 }, {}, "HammerOfJustice"),
    DivineStorm = define("SodDivineStorm", 407778, { rune_id = 407778 }, "DivineStorm"),
    Exorcism = define("SodExorcism", 415073, { min_phase = 2 }, "Exorcism"),
    CrusaderStrike = define("SodCrusaderStrike", 407676, { rune_id = 407676 }, "CrusaderStrike"),
    -- Era-common abilities (TBC-bridge-valid ids, also in class_sylvanas).
    SealMartyr = define("SodSealMartyr", 348700, {}, "SealMartyr"),
    Judgement = define("SodJudgement", 20271, {}, "Judgement"),
    AvengingWrath = define("SodAvengingWrath", 31884, {}, "AvengingWrath"),
    HammerOfWrath = define("SodHammerOfWrath", { 27180, 24239, 24274, 24275 }, {}, "HammerOfWrath"),
    Consecration = define("SodConsecration", { 27173, 20924, 20923, 20922, 20116, 26573 }, {}, "Consecration"),
    -- Emergency cooldowns (guide Cooldowns section; era-common ids).
    DivineShield = define("SodDivineShield", 642, {}, "DivineShield"),
    LayOnHands = define("SodLayOnHands", 633, {}, "LayOnHands"),
}

-- Seal of the Martyrdom player buff (348700, same id the TBC retribution
-- spec's SEAL_MARTYR_BUFF carries).
local SEAL_MARTYR_BUFF = { 348700 }

-- Guide bands: Hammer of Wrath is usable below 20% target health; Avenging
-- Wrath is held for pulls with time to pay it back (ttd above its 15s tail);
-- Consecration is an AoE mana dump (2+ enemies, mana to spare).
local HAMMER_HP_THRESHOLD = 20
local AW_MIN_TTD = 15
local CONSECRATE_MIN_MANA = 35

local function build_state(context)
    local seal_up = false
    if NS.buff_up then
        local ok, up = pcall(NS.buff_up, NS.GetPlayer and NS.GetPlayer() or nil, SEAL_MARTYR_BUFF)
        if ok then seal_up = up == true end
    end
    return spec_kit.safe_state({
        hp_pct = context and (context.hp_pct or context.hp) or nil,
        seal_up = seal_up,
        target_hp_pct = context and (context.target_hp_pct or context.target_hp) or nil,
        mana_pct = context and context.mana_pct or nil,
        enemy_count = context and (context.enemy_count or context.enemies_count) or nil,
        ttd = context and (context.target_ttd or context.ttd) or nil,
    }, {
        hp_pct = 100,
        seal_up = false,
        target_hp_pct = 100,
        mana_pct = 100,
        enemy_count = 0,
        ttd = 0,
    })
end

local function available(context, descriptor, needs_target)
    return type(context) == "table" and context.is_sod == true
        and context.in_combat == true
        and (not needs_target or context.target ~= nil)
        and spec_kit.sod_action_available(context, descriptor)
end

local function target_strategy(name, descriptor)
    return {
        name = name,
        matches = function(context) return available(context, descriptor, true) end,
        execute = function(context)
            return NS.try_cast(descriptor.action, context.target, "[SOD RETRIBUTION] " .. name)
        end,
    }
end

local strategies = {
    -- Shared interrupt-manager lane (strategy #1 -- must beat casts).
    (interrupt_manager and interrupt_manager.register_interrupt_spell
        and interrupt_manager.register_interrupt_spell("paladin", "HammerOfJustice", { HammerOfJustice = ACTION.HammerOfJustice.action }))
        or { name = "HammerOfJusticeSkip", matches = function() return false end, execute = function() return false end },
    -- Emergency defensives (guide Cooldowns: Lay on Hands is the absolute
    -- emergency heal; Divine Shield the full-immunity save). Forbearance
    -- exclusivity: DS holds while LoH is up (both apply the debuff).
    { name = "LayOnHands", matches = function(context, state)
        return available(context, ACTION.LayOnHands, false)
            and (state.hp_pct or 100) <= 15
    end, execute = function(context)
        return NS.try_cast(ACTION.LayOnHands.action, NS.PLAYER_UNIT, "[SOD RETRIBUTION] LayOnHands", { skip_range = true, expected_cooldown = 3600 })
    end },
    { name = "DivineShield", matches = function(context, state)
        return available(context, ACTION.DivineShield, false)
            and (state.hp_pct or 100) <= 20
            and (state.hp_pct or 100) > 15  -- LoH owns the <=15 band (Forbearance)
    end, execute = function(context)
        return NS.try_cast(ACTION.DivineShield.action, NS.PLAYER_UNIT, "[SOD RETRIBUTION] DivineShield", { skip_range = true })
    end },
    -- Keep Seal of Martyrdom up (guide priority #4): refresh whenever the
    -- seal buff is down, no target needed.
    { name = "SealMartyr", matches = function(context, state)
        return available(context, ACTION.SealMartyr, false) and state.seal_up ~= true
    end, execute = function(context)
        return NS.try_cast(ACTION.SealMartyr.action, NS.PLAYER_UNIT, "[SOD RETRIBUTION] SealMartyr", { skip_range = true })
    end },
    -- Opt-in burst cooldown (guide: use when the tank has threat). Held while
    -- the target dies inside the buff's own tail (ttd gate); the battery's
    -- shared use_cooldowns scenario presents the window.
    { name = "AvengingWrath", matches = function(context, state)
        return available(context, ACTION.AvengingWrath, false)
            and spec_kit.setting_bool(context, "use_cooldowns", false)
            and (state.ttd or 0) > AW_MIN_TTD
    end, execute = function(context)
        return NS.try_cast(ACTION.AvengingWrath.action, NS.PLAYER_UNIT, "[SOD RETRIBUTION] AvengingWrath", { skip_range = true })
    end },
    -- Judgement on cooldown, only with the damage seal up (the seal lane
    -- refreshes first when it is down).
    { name = "Judgement", matches = function(context, state)
        return available(context, ACTION.Judgement, true) and state.seal_up == true
    end, execute = function(context)
        return NS.try_cast(ACTION.Judgement.action, context.target, "[SOD RETRIBUTION] Judgement")
    end },
    -- Pinned APL core: Divine Storm > Exorcism > Crusader Strike.
    target_strategy("DivineStorm", ACTION.DivineStorm),
    target_strategy("Exorcism", ACTION.Exorcism),
    target_strategy("CrusaderStrike", ACTION.CrusaderStrike),
    -- Execute band: Hammer of Wrath below 20% target health.
    { name = "HammerOfWrath", matches = function(context, state)
        return available(context, ACTION.HammerOfWrath, true)
            and (state.target_hp_pct or 100) <= HAMMER_HP_THRESHOLD
    end, execute = function(context)
        return NS.try_cast(ACTION.HammerOfWrath.action, context.target, "[SOD RETRIBUTION] HammerOfWrath")
    end },
    -- AoE mana dump: 2+ enemies with mana to spare (self/ground cast).
    { name = "Consecration", matches = function(context, state)
        return available(context, ACTION.Consecration, false)
            and (state.enemy_count or 0) >= 2
            and (state.mana_pct or 0) >= CONSECRATE_MIN_MANA
    end, execute = function(context)
        return NS.try_cast(ACTION.Consecration.action, NS.PLAYER_UNIT, "[SOD RETRIBUTION] Consecration", { skip_range = true })
    end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("retribution", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
