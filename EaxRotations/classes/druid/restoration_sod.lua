-- restoration_sod.lua -- Druid Restoration rotation for Season of Discovery.
-- WHAT: Wild Growth, Nourish, Lifebloom, Rejuvenation, and Healing Touch triage.
-- WHEN: SoD healing with a valid friendly target.
-- WHY: adds native rune-aware healing around the pinned simulator package contract.
-- SAFETY: friendly target, health, phase, and rune state all fail closed.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})
local ACTION = {
    WildGrowth = define("WildGrowth", 408120, { rune_id = 408120 }, "WildGrowth"),
    Nourish = define("Nourish", 408247, { rune_id = 408247, min_phase = 2 }, "Nourish"),
    Lifebloom = define("Lifebloom", 409824, { rune_id = 409824 }, "Lifebloom"),
    Rejuvenation = define("Rejuvenation", { 25299, 9841, 774 }, {}, "Rejuvenation"),
    HealingTouch = define("HealingTouch", { 25297, 9888, 5185 }, {}, "HealingTouch"),
}

local function build_state(context)
    context = type(context) == "table" and context or {}
    local target = context.heal_target or (type(context.lowest) == "table" and context.lowest.unit) or nil
    local hp = context.heal_target_hp_pct
        or (type(context.lowest) == "table" and (context.lowest.hp_pct or context.lowest.hp))
    return spec_kit.safe_state({
        heal_target = target,
        heal_target_hp_pct = type(hp) == "number" and hp or 100,
        injured_count = type(context.injured_count) == "number" and context.injured_count or 0,
        has_lifebloom = context.has_lifebloom == true,
        has_rejuvenation = context.has_rejuvenation == true,
    }, { heal_target_hp_pct = 100, injured_count = 0 })
end

local function base(context, state, descriptor)
    return type(context) == "table" and context.is_sod == true and state.heal_target ~= nil
        and spec_kit.sod_action_available(context, descriptor)
end

local function ready(descriptor, target)
    return type(NS.spell_ready) == "function" and NS.spell_ready(descriptor.action, target) == true
end

local function cast(descriptor, context, label)
    local state = build_state(context)
    return NS.try_cast(descriptor.action, state.heal_target, "[SOD RESTORATION] " .. label)
end

local strategies = {
    { name = "WildGrowth", matches = function(c, s) return base(c, s, ACTION.WildGrowth) and s.injured_count >= 3 and s.heal_target_hp_pct < 85 and ready(ACTION.WildGrowth, s.heal_target) end,
      execute = function(c) return cast(ACTION.WildGrowth, c, "Wild Growth") end },
    { name = "Nourish", matches = function(c, s) return base(c, s, ACTION.Nourish) and s.heal_target_hp_pct <= 60 and ready(ACTION.Nourish, s.heal_target) end,
      execute = function(c) return cast(ACTION.Nourish, c, "Nourish") end },
    { name = "Lifebloom", matches = function(c, s) return base(c, s, ACTION.Lifebloom) and s.heal_target_hp_pct <= 80 and not s.has_lifebloom and ready(ACTION.Lifebloom, s.heal_target) end,
      execute = function(c) return cast(ACTION.Lifebloom, c, "Lifebloom") end },
    { name = "Rejuvenation", matches = function(c, s) return base(c, s, ACTION.Rejuvenation) and s.heal_target_hp_pct <= 75 and not s.has_rejuvenation and ready(ACTION.Rejuvenation, s.heal_target) end,
      execute = function(c) return cast(ACTION.Rejuvenation, c, "Rejuvenation") end },
    { name = "HealingTouch", matches = function(c, s) return base(c, s, ACTION.HealingTouch) and s.heal_target_hp_pct <= 50 and ready(ACTION.HealingTouch, s.heal_target) end,
      execute = function(c) return cast(ACTION.HealingTouch, c, "Healing Touch") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("restoration", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
