local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})
local ACTION = {
    Bloodrage = define("SodBloodrage", 2687, {}, "Bloodrage"),
    BerserkerRage = define("SodBerserkerRage", 18499, {}, "BerserkerRage"),
    SweepingStrikes = define("SodSweepingStrikes", 12328, {}, "SweepingStrikes"),
    Rampage = define("SodRampage", 426940, { rune_id = 426940, min_phase = 4 }, "Rampage"),
    MortalStrike = define("SodMortalStrike", 12294, {}, "MortalStrike"),
    Bloodthirst = define("SodBloodthirst", 23894, {}, "Bloodthirst"),
    Whirlwind = define("SodWhirlwind", 1680, {}, "Whirlwind"),
    Execute = define("SodExecute", 20660, {}, "Execute"),
    RagingBlow = define("SodRagingBlow", 402911, { rune_id = 402911, min_phase = 1 }, "RagingBlow"),
    QuickStrike = define("SodQuickStrike", 429765, { rune_id = 429765, min_phase = 3 }, "QuickStrike"),
    HeroicStrike = define("SodHeroicStrike", 11565, {}, "HeroicStrike"),
    Slam = define("SodSlam", 11604, {}, "Slam"),
}

local function number(context, key, fallback)
    return type(context[key]) == "number" and context[key] or fallback
end

local function build_state(context)
    context = type(context) == "table" and context or {}
    return spec_kit.safe_state({
        stance = context.stance,
        rage = number(context, "rage", 0),
        target_hp_pct = number(context, "target_hp_pct", 100),
        enemy_count = number(context, "enemy_count", 0),
    }, { rage = 0, target_hp_pct = 100, enemy_count = 0 })
end

local function dps_stance(stance)
    return stance == "battle" or stance == "berserker" or stance == 1 or stance == 3
end

local function available(context, descriptor, target_required)
    return type(context) == "table" and context.is_sod == true and context.in_combat == true
        and dps_stance(context.stance) and (not target_required or context.target ~= nil)
        and spec_kit.sod_action_available(context, descriptor)
end

local function ready(descriptor, target)
    return type(NS.spell_ready) == "function" and NS.spell_ready(descriptor.action, target) == true
end

local function cast(descriptor, target, label)
    return NS.try_cast(descriptor.action, target, "[SOD WARRIOR DPS] " .. label)
end

local strategies = {
    { name = "Bloodrage", matches = function(c, s)
        return available(c, ACTION.Bloodrage, false) and s.rage < 20 and ready(ACTION.Bloodrage, c.me)
    end, execute = function(c) return cast(ACTION.Bloodrage, c.me, "Bloodrage") end },
    { name = "BerserkerRage", matches = function(c, s)
        return available(c, ACTION.BerserkerRage, false) and c.stance == "berserker"
            and s.rage < 40 and ready(ACTION.BerserkerRage, c.me)
    end, execute = function(c) return cast(ACTION.BerserkerRage, c.me, "BerserkerRage") end },
    { name = "SweepingStrikes", matches = function(c, s)
        return available(c, ACTION.SweepingStrikes, false) and s.enemy_count >= 2
            and s.rage >= 30 and ready(ACTION.SweepingStrikes, c.me)
    end, execute = function(c) return cast(ACTION.SweepingStrikes, c.me, "SweepingStrikes") end },
    { name = "Rampage", matches = function(c) return available(c, ACTION.Rampage, true)
        and ready(ACTION.Rampage, c.target)
    end, execute = function(c) return cast(ACTION.Rampage, c.target, "Rampage") end },
    { name = "Execute", matches = function(c, s)
        return available(c, ACTION.Execute, true) and s.target_hp_pct <= 20 and s.rage >= 15
            and ready(ACTION.Execute, c.target)
    end, execute = function(c) return cast(ACTION.Execute, c.target, "Execute") end },
    { name = "MortalStrike", matches = function(c, s)
        return available(c, ACTION.MortalStrike, true) and s.rage >= 30
            and ready(ACTION.MortalStrike, c.target)
    end, execute = function(c) return cast(ACTION.MortalStrike, c.target, "MortalStrike") end },
    { name = "Bloodthirst", matches = function(c, s)
        return available(c, ACTION.Bloodthirst, true) and s.rage >= 30
            and ready(ACTION.Bloodthirst, c.target)
    end, execute = function(c) return cast(ACTION.Bloodthirst, c.target, "Bloodthirst") end },
    { name = "RagingBlow", matches = function(c, s)
        return available(c, ACTION.RagingBlow, true) and s.rage >= 20
            and ready(ACTION.RagingBlow, c.target)
    end, execute = function(c) return cast(ACTION.RagingBlow, c.target, "RagingBlow") end },
    { name = "QuickStrike", matches = function(c, s)
        return available(c, ACTION.QuickStrike, true) and s.rage >= 20
            and ready(ACTION.QuickStrike, c.target)
    end, execute = function(c) return cast(ACTION.QuickStrike, c.target, "QuickStrike") end },
    { name = "Whirlwind", matches = function(c, s)
        return available(c, ACTION.Whirlwind, true) and s.enemy_count >= 2 and s.rage >= 25
            and ready(ACTION.Whirlwind, c.target)
    end, execute = function(c) return cast(ACTION.Whirlwind, c.target, "Whirlwind") end },
    { name = "HeroicStrike", matches = function(c, s)
        return available(c, ACTION.HeroicStrike, true) and s.rage >= 80
            and ready(ACTION.HeroicStrike, c.target)
    end, execute = function(c) return cast(ACTION.HeroicStrike, c.target, "HeroicStrike") end },
    { name = "Slam", matches = function(c, s)
        return available(c, ACTION.Slam, true) and s.rage >= 15
            and ready(ACTION.Slam, c.target)
    end, execute = function(c) return cast(ACTION.Slam, c.target, "Slam") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("dps_warrior", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
