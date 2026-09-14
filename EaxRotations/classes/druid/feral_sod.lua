-- feral_sod.lua -- Druid Feral rotation for Season of Discovery.
-- WHAT: Cat Form, Savage Roar, Mangle, Rip, Rake, and Shred priority.
-- WHEN: SoD combat with a valid hostile target.
-- WHY: SoD phase-5 feral priority (Wowhead SoD druid guides; every rune
--      id Wowhead-verified in-tree). No SoD APL fixture is pinned in
--      tools/evidence/apl/ - the earlier "pinned wowsims/sod APL" claim
--      pointed at an unrelated gh-pages workflow commit and was removed
--      (2026-09-14 evidence audit). The SoD Skull Bash rune (410176,
--      Wowhead-verified: 13y charge interrupt, 10s CD,
--      Forms Cat/Bear/Dire Bear - NOT Moonkin, so balance_sod is
--      deliberately not wired) is registered via the shared interrupt
--      manager so a SoD feral can interrupt in both feral forms.
-- SAFETY: form, combo, rune, and phase gates fail closed on uncertain state.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")
if not _ok_int or type(interrupt_manager) ~= "table" then interrupt_manager = nil end
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
    -- Skull Bash rune (410176, Wowhead-verified 2026-09-14): 13-yard charge
    -- interrupt, 10s CD, 25 energy/10 rage, cat AND bear forms (not moonkin).
    SkullBash = define("SkullBash", 410176, { rune_id = 410176 }, "SkullBash"),
    -- SoD carries the classic Feral Faerie Fire (16857 family — the same
    -- ids cat_vanilla/bear_sylvanas already use; sweep-approved family).
    FaerieFireFeral = define("FaerieFireFeral", { 27011, 17392, 17391, 17390, 16857 }, {}, "FaerieFireFeral"),
    Berserk = define("Berserk", 417141, { rune_id = 417141 }, "Berserk"),
    Swipe = define("Swipe", { 26997, 9908, 9754, 780, 779 }, {}, "Swipe"),
}

-- Feral Faerie Fire debuff ids (armor reduction; mirror of the
-- cat_vanilla/bear_sylvanas tables, debuff side incl. the TBC ranks).
local FAERIE_FIRE_DEBUFF = { 27011, 17392, 17391, 17390, 16857, 26993, 9907, 9749, 778, 770 }
local FAERIE_FIRE_REFRESH = 6.0

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
        faerie_fire_remains = context.target and type(NS.debuff_remains) == "function"
            and NS.debuff_remains(context.target, FAERIE_FIRE_DEBUFF) or 0,
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
    -- Interrupt: Skull Bash, both feral forms, no form gate (the manager
    -- lane uses NS.has_form-style gating only when `required` is passed;
    -- omitted here because the rune is legal in BOTH cat and bear).
    (interrupt_manager and interrupt_manager.register_interrupt_spell
        -- pass the inner action (with _meta.id), not the SoD descriptor wrapper
        and interrupt_manager.register_interrupt_spell("druid", "SkullBash", { SkullBash = ACTION.SkullBash.action }))
        or { name = "SkullBashSkip", matches = function() return false end, execute = function() return false end },
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
    -- Feral Faerie Fire: armor-reduction maintain, never costs a GCD the
    -- core needs (sits below every damage lane; refresh window mirrors
    -- cat_vanilla).
    { name = "FaerieFireFeral", matches = function(c, s) return base(c, ACTION.FaerieFireFeral) and s.in_cat_form
        and (s.faerie_fire_remains or 0) <= FAERIE_FIRE_REFRESH and ready(ACTION.FaerieFireFeral, c.target) end,
      execute = function(c) return cast(ACTION.FaerieFireFeral, c, c.target, "Faerie Fire Feral") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("feral", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
