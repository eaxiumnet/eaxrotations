-- feral_sod.lua -- Druid Feral rotation for Season of Discovery.
-- WHAT: Cat Form, Savage Roar, Mangle, Rip, Rake, and Shred priority.
-- WHEN: SoD combat with a valid hostile target.
-- WHY: translates the pinned wowsims/sod phase 5 Feral APL.
-- SAFETY: form, combo, rune, and phase gates fail closed on uncertain state.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})
local ACTION = {
    CatForm = define("CatForm", 768, {}, "CatForm"),
    SavageRoar = define("SavageRoar", 407988, { rune_id = 407988 }, "SavageRoar"),
    Mangle = define("MangleCat", 409828, { rune_id = 407995 }, "MangleCat"),
    Rip = define("Rip", { 9896, 9493 }, {}, "Rip"),
    Rake = define("Rake", { 9904, 1824 }, {}, "Rake"),
    Shred = define("Shred", { 9830, 9829 }, {}, "Shred"),
}

local function value(context, key, fallback)
    local result = context[key]
    if type(result) == type(fallback) then return result end
    return fallback
end

local function build_state(context)
    context = type(context) == "table" and context or {}
    return spec_kit.safe_state({
        in_cat_form = value(context, "in_cat_form", false),
        savage_roar_remains = value(context, "savage_roar_remains", 0),
        mangle_remains = value(context, "mangle_remains", 0),
        rip_remains = value(context, "rip_remains", 0),
        rake_remains = value(context, "rake_remains", 0),
        combo_points = value(context, "combo_points", 0),
        energy = value(context, "energy", 0),
        target_ttd = value(context, "target_ttd", 0),
    }, { combo_points = 0, energy = 0, target_ttd = 0, savage_roar_remains = 0,
        mangle_remains = 0, rip_remains = 0, rake_remains = 0 })
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
    return NS.try_cast(descriptor.action, target, "[SOD FERAL] " .. label)
end

local strategies = {
    { name = "CatForm", matches = function(c, s) return base(c, ACTION.CatForm) and not s.in_cat_form and ready(ACTION.CatForm, c.me) end,
      execute = function(c) return cast(ACTION.CatForm, c, c.me, "Cat Form") end },
    { name = "SavageRoar", matches = function(c, s) return base(c, ACTION.SavageRoar) and s.in_cat_form and s.savage_roar_remains <= 0 and ready(ACTION.SavageRoar, c.me) end,
      execute = function(c) return cast(ACTION.SavageRoar, c, c.me, "Savage Roar") end },
    { name = "Mangle", matches = function(c, s) return base(c, ACTION.Mangle) and s.in_cat_form and s.mangle_remains <= 0 and ready(ACTION.Mangle, c.target) end,
      execute = function(c) return cast(ACTION.Mangle, c, c.target, "Mangle") end },
    { name = "Rip", matches = function(c, s) return base(c, ACTION.Rip) and s.in_cat_form and s.combo_points >= 5 and s.rip_remains <= 0 and s.target_ttd >= 10 and ready(ACTION.Rip, c.target) end,
      execute = function(c) return cast(ACTION.Rip, c, c.target, "Rip") end },
    { name = "Rake", matches = function(c, s) return base(c, ACTION.Rake) and s.in_cat_form and s.rake_remains <= 0 and ready(ACTION.Rake, c.target) end,
      execute = function(c) return cast(ACTION.Rake, c, c.target, "Rake") end },
    { name = "Shred", matches = function(c, s) return base(c, ACTION.Shred) and s.in_cat_form and s.combo_points < 5 and ready(ACTION.Shred, c.target) end,
      execute = function(c) return cast(ACTION.Shred, c, c.target, "Shred") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("feral", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
