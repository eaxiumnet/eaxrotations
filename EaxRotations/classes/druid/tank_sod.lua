-- tank_sod.lua -- Druid Feral Tank rotation for Season of Discovery.
-- WHAT: defensive, Bear Form, Lacerate, Mangle, Swipe, and Maul priority.
-- WHEN: SoD tank combat with a valid hostile target.
-- WHY: translates the pinned wowsims/sod phase 6 Feral Tank APL.
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
}

local function number(context, key, fallback)
    return type(context[key]) == "number" and context[key] or fallback
end

local function build_state(context)
    context = type(context) == "table" and context or {}
    return spec_kit.safe_state({
        hp_pct = number(context, "hp_pct", 100),
        in_bear_form = context.in_bear_form == true,
        lacerate_remains = number(context, "lacerate_remains", 0),
        lacerate_stacks = number(context, "lacerate_stacks", 0),
        rage = number(context, "rage", 0),
    }, { hp_pct = 100, lacerate_remains = 0, lacerate_stacks = 0, rage = 0 })
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
    { name = "BearForm", matches = function(c, s) return base(c, ACTION.BearForm) and not s.in_bear_form and ready(ACTION.BearForm, c.me) end,
      execute = function(c) return cast(ACTION.BearForm, c, c.me, "Bear Form") end },
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
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("tank", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
