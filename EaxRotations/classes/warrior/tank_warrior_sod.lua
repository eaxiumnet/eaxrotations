local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})
local ACTION = {
    DefensiveStance = define("SodDefensiveStance", 71, {}, "DefensiveStance"),
    Rampage = define("SodRampage", 426940, { rune_id = 426940, min_phase = 4 }, "Rampage"),
    SweepingStrikes = define("SodSweepingStrikes", 12328, {}, "SweepingStrikes"),
    Recklessness = define("SodRecklessness", 1719, {}, "Recklessness"),
    LastStand = define("SodLastStand", 12975, {}, "LastStand"),
    Shockwave = define("SodShockwave", 440488, { rune_id = 440488, min_phase = 4 }, "Shockwave"),
    Cleave = define("SodCleave", 25286, {}, "Cleave"),
    ThunderClap = define("SodThunderClap", 11581, {}, "ThunderClap"),
    ShieldSlam = define("SodShieldSlam", 23925, {}, "ShieldSlam"),
    Revenge = define("SodRevenge", 11601, {}, "Revenge"),
    Devastate = define("SodDevastate", 11597, { rune_id = 403195, min_phase = 1 }, "Devastate"),
    DemoralizingShout = define("SodDemoralizingShout", 11554, {}, "DemoralizingShout"),
    Bloodrage = define("SodBloodrage", 2687, {}, "Bloodrage"),
}

local function number(context, key, fallback)
    return type(context[key]) == "number" and context[key] or fallback
end

local function build_state(context)
    context = type(context) == "table" and context or {}
    return spec_kit.safe_state({
        stance = context.stance,
        rage = number(context, "rage", 0),
        hp_pct = number(context, "hp_pct", 100),
        enemy_count = number(context, "enemy_count", 0),
        target_hp_pct = number(context, "target_hp_pct", 100),
        demoralizing_remains = number(context, "demoralizing_remains", 0),
        sunder_stacks = number(context, "sunder_stacks", 0),
    }, {
        rage = 0, hp_pct = 100, enemy_count = 0, target_hp_pct = 100,
        demoralizing_remains = 0, sunder_stacks = 0,
    })
end

local function tank_stance(stance)
    return stance == "defensive" or stance == 2
end

local function available(context, descriptor, target_required)
    return type(context) == "table" and context.is_sod == true and context.in_combat == true
        and tank_stance(context.stance) and (not target_required or context.target ~= nil)
        and spec_kit.sod_action_available(context, descriptor)
end

local function ready(descriptor, target)
    return type(NS.spell_ready) == "function" and NS.spell_ready(descriptor.action, target) == true
end

local function cast(descriptor, target, label)
    return NS.try_cast(descriptor.action, target, "[SOD WARRIOR TANK] " .. label)
end

local strategies = {
    { name = "LastStand", matches = function(c, s)
        return available(c, ACTION.LastStand, false) and s.hp_pct <= 50 and ready(ACTION.LastStand, c.me)
    end, execute = function(c) return cast(ACTION.LastStand, c.me, "LastStand") end },
    { name = "Rampage", matches = function(c) return available(c, ACTION.Rampage, true)
        and ready(ACTION.Rampage, c.target)
    end, execute = function(c) return cast(ACTION.Rampage, c.target, "Rampage") end },
    { name = "SweepingStrikes", matches = function(c, s)
        return available(c, ACTION.SweepingStrikes, false) and s.enemy_count >= 2
            and s.rage >= 30 and ready(ACTION.SweepingStrikes, c.me)
    end, execute = function(c) return cast(ACTION.SweepingStrikes, c.me, "SweepingStrikes") end },
    { name = "Shockwave", matches = function(c, s)
        return available(c, ACTION.Shockwave, true) and s.enemy_count >= 2 and s.rage >= 35
            and ready(ACTION.Shockwave, c.target)
    end, execute = function(c) return cast(ACTION.Shockwave, c.target, "Shockwave") end },
    { name = "Cleave", matches = function(c, s)
        return available(c, ACTION.Cleave, true) and s.enemy_count >= 2 and s.rage >= 35
            and ready(ACTION.Cleave, c.target)
    end, execute = function(c) return cast(ACTION.Cleave, c.target, "Cleave") end },
    { name = "ShieldSlam", matches = function(c, s)
        return available(c, ACTION.ShieldSlam, true) and s.rage >= 20
            and ready(ACTION.ShieldSlam, c.target)
    end, execute = function(c) return cast(ACTION.ShieldSlam, c.target, "ShieldSlam") end },
    { name = "Revenge", matches = function(c, s)
        return available(c, ACTION.Revenge, true) and s.rage >= 5
            and ready(ACTION.Revenge, c.target)
    end, execute = function(c) return cast(ACTION.Revenge, c.target, "Revenge") end },
    { name = "ThunderClap", matches = function(c, s)
        return available(c, ACTION.ThunderClap, true) and s.enemy_count >= 2 and s.rage >= 20
            and ready(ACTION.ThunderClap, c.target)
    end, execute = function(c) return cast(ACTION.ThunderClap, c.target, "ThunderClap") end },
    { name = "Devastate", matches = function(c, s)
        return available(c, ACTION.Devastate, true) and s.rage >= 15
            and ready(ACTION.Devastate, c.target)
    end, execute = function(c) return cast(ACTION.Devastate, c.target, "Devastate") end },
    { name = "DemoralizingShout", matches = function(c, s)
        return available(c, ACTION.DemoralizingShout, true) and s.demoralizing_remains <= 0
            and s.rage >= 10 and ready(ACTION.DemoralizingShout, c.target)
    end, execute = function(c) return cast(ACTION.DemoralizingShout, c.target, "DemoralizingShout") end },
    { name = "Bloodrage", matches = function(c, s)
        return available(c, ACTION.Bloodrage, false) and s.rage < 20 and ready(ACTION.Bloodrage, c.me)
    end, execute = function(c) return cast(ACTION.Bloodrage, c.me, "Bloodrage") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("tank_warrior", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
