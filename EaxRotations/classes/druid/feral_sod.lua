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
    -- SoD Tiger's Fury rune (Wowhead-verified 417045) + Berserk (417141,
    -- pinned via druid/tank_sod) + era-common Swipe ladder.
    TigersFury = define("TigersFury", 417045, { rune_id = 417045 }, "TigersFury"),
    Berserk = define("Berserk", 417141, { rune_id = 417141 }, "Berserk"),
    Swipe = define("Swipe", { 26997, 9908, 9754, 780, 779 }, {}, "Swipe"),
}

local function buff_up(context, key, unit, ids)
    if context[key] ~= nil then return context[key] == true end
    return unit and type(NS.buff_up) == "function" and NS.buff_up(unit, ids) or false
end

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
        omen_up = buff_up(context, "omen_up", context.me, { 16864 }),
        enemy_count = value(context, "enemy_count", 0),
    }, { combo_points = 0, energy = 0, target_ttd = 0, savage_roar_remains = 0,
        mangle_remains = 0, rip_remains = 0, rake_remains = 0, enemy_count = 0 })
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
    -- Cooldown block (Icy-Veins SoD feral priority): Tiger's Fury at <= 40
    -- energy (King of the Jungle refuel), Berserk right after it, and Omen
    -- of Clarity procs spent on Shred.
    { name = "TigersFury", matches = function(c, s) return base(c, ACTION.TigersFury) and s.in_cat_form and (s.energy or 0) <= 40 and ready(ACTION.TigersFury, c.me) end,
      execute = function(c) return cast(ACTION.TigersFury, c, c.me, "Tiger's Fury") end },
    { name = "Berserk", matches = function(c, s) return base(c, ACTION.Berserk) and s.in_cat_form and ready(ACTION.Berserk, c.me) end,
      execute = function(c) return cast(ACTION.Berserk, c, c.me, "Berserk") end },
    { name = "OmenShred", matches = function(c, s) return base(c, ACTION.Shred) and s.in_cat_form and s.omen_up and ready(ACTION.Shred, c.target) end,
      execute = function(c) return cast(ACTION.Shred, c, c.target, "Omen Shred") end },
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
    -- Multi-target energy dump (guide: spend energy on Swipe).
    { name = "Swipe", matches = function(c, s) return base(c, ACTION.Swipe) and s.in_cat_form and (s.enemy_count or 0) >= 2 and ready(ACTION.Swipe, c.target) end,
      execute = function(c) return cast(ACTION.Swipe, c, c.target, "Swipe") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("feral", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
