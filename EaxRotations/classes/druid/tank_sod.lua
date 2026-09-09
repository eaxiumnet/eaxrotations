-- tank_sod.lua -- Druid Feral Tank rotation for Season of Discovery.
-- WHAT: defensive, Bear Form, threat tools (Growl/Demo Roar), Survival
--       Instincts, Enrage, Lacerate, Mangle, Swipe, and Maul priority
--       (Icy-Veins SoD feral-tank rotation: Demo Roar for intake, Mangle on
--       CD, Lacerate spam, Maul on excess rage; Growl for breaking adds,
--       2025).
-- WHEN: SoD tank combat with a valid hostile target (Enrage also pre-pull).
-- WHY: translates the pinned wowsims/sod phase 6 Feral Tank APL plus the
--      guide-priority tank-control lanes the file lacked.
-- SAFETY: 20 percent defensive gate and all phase/rune/resource reads fail closed.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})
local ACTION = {
    Barkskin = define("Barkskin", 22812, {}, "Barkskin"),
    BearForm = define("DireBearForm", { 9634, 5487 }, {}, "BearForm"),
    Lacerate = define("Lacerate", 414644, { rune_id = 414644 }, "Lacerate"),
    Mangle = define("MangleBear", 407995, { rune_id = 407995 }, "MangleBear"),
    Berserk = define("Berserk", 417141, { rune_id = 417141, min_phase = 2 }, "Berserk"),
    Swipe = define("Swipe", { 9908, 769 }, {}, "Swipe"),
    Maul = define("Maul", { 9881, 9880, 9745, 8972, 6809, 6808, 6807 }, {}, "Maul"),
    -- Era-common abilities (TBC-bridge-valid ids) + the Survival Instincts
    -- rune (409809 castable, Wowhead-verified; buff 408024).
    DemoralizingRoar = define("SodDemoralizingRoar", { 16857, 9898 }, {}, "DemoralizingRoar"),
    Growl = define("SodGrowl", 6795, {}, "Growl"),
    Enrage = define("SodEnrage", 5229, {}, "Enrage"),
    SurvivalInstincts = define("SodSurvivalInstincts", 409809, { rune_id = 409809 }, "SurvivalInstincts"),
}

local function number(context, key, fallback)
    return type(context[key]) == "number" and context[key] or fallback
end

-- Survival Instincts active buff (408024 - the rune cast 409809 applies it).
local SI_ACTIVE = { 408024 }
local function has_buff(ids)
    if not NS.buff_up then return false end
    local ok, up = pcall(NS.buff_up, NS.GetPlayer and NS.GetPlayer() or nil, ids)
    return ok and up == true
end

local function build_state(context)
    context = type(context) == "table" and context or {}
    return spec_kit.safe_state({
        hp_pct = number(context, "hp_pct", 100),
        in_bear_form = context.in_bear_form == true,
        lacerate_remains = number(context, "lacerate_remains", 0),
        lacerate_stacks = number(context, "lacerate_stacks", 0),
        rage = number(context, "rage", 0),
        enemy_count = number(context, "enemy_count", 1),
        in_combat = context.in_combat == true,
        si_active = has_buff(SI_ACTIVE),
    }, { hp_pct = 100, lacerate_remains = 0, lacerate_stacks = 0, rage = 0 })
end

-- Validity without the combat/target gates (self-cast utility lanes).
local function valid_sod(context, descriptor)
    return type(context) == "table" and context.is_sod == true
        and spec_kit.sod_action_available(context, descriptor)
end

local function base(context, descriptor)
    return type(context) == "table" and context.is_sod == true and context.in_combat == true
        and context.target ~= nil
        and spec_kit.sod_action_available(context, descriptor)
end

local function ready(descriptor, target)
    return type(NS.spell_ready) == "function" and NS.spell_ready(descriptor.action, target) == true
end

local function cast(descriptor, context, target, label)
    return NS.try_cast(descriptor.action, target, "[SOD TANK] " .. label)
end

local strategies = {
    { name = "Barkskin", matches = function(c, s) return base(c, ACTION.Barkskin) and s.hp_pct <= 20 and ready(ACTION.Barkskin, c.me) end,
      execute = function(c) return cast(ACTION.Barkskin, c, c.me, "Barkskin") end },
    -- Survival Instincts (guide: emergency defensive; 30% max health +
    -- damage reduction). Held while the buff is already active.
    { name = "SurvivalInstincts", matches = function(c, s) return base(c, ACTION.SurvivalInstincts) and s.hp_pct <= 30 and not s.si_active and ready(ACTION.SurvivalInstincts, c.me) end,
      execute = function(c) return cast(ACTION.SurvivalInstincts, c, c.me, "Survival Instincts") end },
    -- Demoralizing Roar (guide #1: reduce intake on heavy multi-target
    -- damage when no equivalent debuff is up).
    { name = "DemoralizingRoar", matches = function(c, s) return base(c, ACTION.DemoralizingRoar) and s.in_bear_form and (s.enemy_count or 0) >= 3 and ready(ACTION.DemoralizingRoar, c.me) end,
      execute = function(c) return cast(ACTION.DemoralizingRoar, c, c.me, "Demoralizing Roar") end },
    { name = "BearForm", matches = function(c, s) return base(c, ACTION.BearForm) and not s.in_bear_form and ready(ACTION.BearForm, c.me) end,
      execute = function(c) return cast(ACTION.BearForm, c, c.me, "Bear Form") end },    -- Growl (guide: snap-threat for mobs breaking away). Fires only when a
    -- real threat readout says the target is headed elsewhere (fails closed
    -- without one - never wastes the taunt on a held mob).
    { name = "Growl", matches = function(c, s)
        -- context.threat_pct is the engine readout (main_sylvanas scales
        -- NS.threat_status 0-3 to 0-100). Full threat (>=100) or NO readout
        -- (nil) both hold the taunt - it only fires on real evidence the mob
        -- is heading elsewhere.
        if type(c) ~= "table" then return false end
        local threat = type(c.threat_pct) == "number" and c.threat_pct or nil
        return base(c, ACTION.Growl) and s.in_bear_form and threat ~= nil and threat < 100 and ready(ACTION.Growl, c.target) end,
      execute = function(c) return cast(ACTION.Growl, c, c.target, "Growl") end },
    { name = "LacerateRefresh", matches = function(c, s) return base(c, ACTION.Lacerate) and s.in_bear_form and s.lacerate_remains > 0 and s.lacerate_remains < 3 and ready(ACTION.Lacerate, c.target) end,
      execute = function(c) return cast(ACTION.Lacerate, c, c.target, "Lacerate refresh") end },
    { name = "Mangle", matches = function(c, s) return base(c, ACTION.Mangle) and s.in_bear_form and ready(ACTION.Mangle, c.target) end,
      execute = function(c) return cast(ACTION.Mangle, c, c.target, "Mangle") end },
    { name = "Lacerate", matches = function(c, s) return base(c, ACTION.Lacerate) and s.in_bear_form and s.lacerate_stacks < 5 and ready(ACTION.Lacerate, c.target) end,
      execute = function(c) return cast(ACTION.Lacerate, c, c.target, "Lacerate") end },
    { name = "Berserk", matches = function(c, s) return base(c, ACTION.Berserk) and s.in_bear_form and ready(ACTION.Berserk, c.me) end,
      execute = function(c) return cast(ACTION.Berserk, c, c.me, "Berserk") end },
    { name = "Swipe", matches = function(c, s) return base(c, ACTION.Swipe) and s.in_bear_form and ready(ACTION.Swipe, c.target) end,
      execute = function(c) return cast(ACTION.Swipe, c, c.target, "Swipe") end },
    { name = "Maul", matches = function(c, s) return base(c, ACTION.Maul) and s.in_bear_form and s.rage >= 30 and ready(ACTION.Maul, c.target) end,
      execute = function(c) return cast(ACTION.Maul, c, c.target, "Maul") end },
    -- Enrage (guide: rage generation before/in between pulls). No target or
    -- combat gate; deep rage poverty is the only trigger so it never steals
    -- a GCD from the spender chain.
    { name = "Enrage", matches = function(c, s) return base(c, ACTION.Enrage) and (s.rage or 0) < 10 and ready(ACTION.Enrage, c.me) end,
      execute = function(c) return cast(ACTION.Enrage, c, c.me, "Enrage") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("tank", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
