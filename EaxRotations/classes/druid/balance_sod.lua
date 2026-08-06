-- balance_sod.lua -- Druid Balance rotation for Season of Discovery.
-- WHAT: Starsurge, Moonfire, Sunfire, Starfall, Starfire, and Wrath priority.
-- WHEN: SoD combat with a valid hostile target.
-- WHY: translates the pinned wowsims/sod phase 6 Balance APL.
-- SAFETY: rune and phase actions fail closed; numeric state is schema guarded.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})
local ACTION = {
    Starsurge = define("Starsurge", 417157, { rune_id = 417157 }, "Starsurge"),
    Moonfire = define("Moonfire", { 9835, 8921 }, {}, "Moonfire"),
    Sunfire = define("Sunfire", 414684, { rune_id = 414684 }, "Sunfire"),
    Starfall = define("Starfall", 439748, { rune_id = 439748, min_phase = 4 }, "Starfall"),
    Starfire = define("Starfire", { 25298, 9876 }, {}, "Starfire"),
    Wrath = define("Wrath", { 9912, 8905 }, {}, "Wrath"),
}

local function aura_up(context, key, unit, ids)
    if context[key] ~= nil then return context[key] == true end
    return unit and type(NS.buff_up) == "function" and NS.buff_up(unit, ids) or false
end

local function remains(context, key, unit, ids)
    if type(context[key]) == "number" then return context[key] end
    return unit and type(NS.debuff_remains) == "function" and NS.debuff_remains(unit, ids) or 0
end

local function build_state(context)
    context = type(context) == "table" and context or {}
    local target = context.target
    return spec_kit.safe_state({
        has_starsurge_aura = aura_up(context, "has_starsurge_aura", context.me, { 417157 }),
        moonfire_remains = remains(context, "moonfire_remains", target, { 9835 }),
        sunfire_remains = remains(context, "sunfire_remains", target, { 414684 }),
    }, { moonfire_remains = 0, sunfire_remains = 0 })
end

local function base(context, descriptor)
    return type(context) == "table" and context.is_sod == true and context.in_combat == true
        and context.target ~= nil
        and spec_kit.sod_action_available(context, descriptor)
end

local function ready(descriptor, target)
    return type(NS.spell_ready) == "function" and NS.spell_ready(descriptor.action, target) == true
end

local function cast(descriptor, context, label)
    return NS.try_cast(descriptor.action, context.target, "[SOD BALANCE] " .. label)
end

local strategies = {
    { name = "Starsurge", matches = function(c, s) return base(c, ACTION.Starsurge) and not s.has_starsurge_aura and ready(ACTION.Starsurge, c.target) end,
      execute = function(c) return cast(ACTION.Starsurge, c, "Starsurge") end },
    { name = "Moonfire", matches = function(c, s) return base(c, ACTION.Moonfire) and s.moonfire_remains <= 0 and ready(ACTION.Moonfire, c.target) end,
      execute = function(c) return cast(ACTION.Moonfire, c, "Moonfire") end },
    { name = "Sunfire", matches = function(c, s) return base(c, ACTION.Sunfire) and s.sunfire_remains <= 0 and ready(ACTION.Sunfire, c.target) end,
      execute = function(c) return cast(ACTION.Sunfire, c, "Sunfire") end },
    { name = "Starfall", matches = function(c) return base(c, ACTION.Starfall) and ready(ACTION.Starfall, c.target) end,
      execute = function(c) return cast(ACTION.Starfall, c, "Starfall") end },
    { name = "Starfire", matches = function(c) return base(c, ACTION.Starfire) and ready(ACTION.Starfire, c.target) end,
      execute = function(c) return cast(ACTION.Starfire, c, "Starfire") end },
    { name = "Wrath", matches = function(c) return base(c, ACTION.Wrath) and ready(ACTION.Wrath, c.target) end,
      execute = function(c) return cast(ACTION.Wrath, c, "Wrath") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("balance", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
