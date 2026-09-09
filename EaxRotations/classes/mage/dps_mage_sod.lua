-- dps_mage_sod.lua -- Mage DPS rotation for Season of Discovery.
-- WHAT: source-ordered mana recovery, rune cooldowns, and spellfrost fillers.
-- WHEN: SoD combat with a valid hostile target.
-- WHY: translates the pinned p5 spellfrost APL into native EAX strategies.
-- SAFETY: every action is phase/rune gated and state reads have safe defaults.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})

local ACTION = {
    Evocation = define("SodEvocation", 12051, {}, "Evocation"),
    FrozenOrb = define("SodFrozenOrb", 440802, { rune_id = 440802, min_phase = 4 }, "FrozenOrb"),
    BalefireBolt = define("SodBalefireBolt", 428878, { rune_id = 428878, min_phase = 3 }, "BalefireBolt"),
    SpellfrostBolt = define("SodSpellfrostBolt", 412532, { rune_id = 412532, min_phase = 2 }, "SpellfrostBolt"),
    FrostfireBolt = define("SodFrostfireBolt", 401502, { rune_id = 401502, min_phase = 2 }, "FrostfireBolt"),
    Frostbolt = define("SodFrostbolt", 10181, {}, "Frostbolt"),
    -- SoD runes (Wowhead-verified): Living Bomb (Helm) + era-common Icy
    -- Veins (bridge 12472). Deep Freeze is deliberately NOT modeled: the
    -- engine context exposes no frozen/Fingers-of-Frost field, so its
    -- FoF gate has no real read path (repo real-read-path rule).
    LivingBomb = define("SodLivingBomb", 400613, { rune_id = 400613 }, "LivingBomb"),
    IcyVeins = define("SodIcyVeins", 12472, {}, "IcyVeins"),
}

-- Debuff resolution mirrors balance_sod: the real read path is the target
-- debuff map via NS.debuff_remains, not a context field.
local function target_debuff_remains(context, ids)
    local target = context and context.target or nil
    return (target and type(NS.debuff_remains) == "function" and NS.debuff_remains(target, ids)) or 0
end

local function build_state(context)
    return spec_kit.safe_state({
        mana_pct = context and context.mana_pct or nil,
        living_bomb_remains = target_debuff_remains(context, { 400613 }),
    }, { mana_pct = 100, living_bomb_remains = 0 })
end

local function combat_action_matches(context, descriptor)
    return type(context) == "table"
        and context.is_sod == true
        and context.in_combat == true
        and context.target ~= nil
        and spec_kit.sod_action_available(context, descriptor)
end

local function action_strategy(name, descriptor)
    return {
        name = name,
        matches = function(context) return combat_action_matches(context, descriptor) end,
        execute = function(context)
            return NS.try_cast(descriptor.action, context.target, "[SOD MAGE] " .. name)
        end,
    }
end

local strategies = {
    {
        name = "Evocation",
        matches = function(context, state)
            return (state and state.mana_pct or 100) <= 15
                and combat_action_matches(context, ACTION.Evocation)
        end,
        execute = function()
            return NS.try_cast(ACTION.Evocation.action, NS.PLAYER_UNIT, "[SOD MAGE] Evocation", { skip_range = true })
        end,
    },
    action_strategy("FrozenOrb", ACTION.FrozenOrb),
    -- Guide: cast Living Bomb, reapply once it expires.
    { name = "LivingBomb",
      matches = function(context, state)
          return combat_action_matches(context, ACTION.LivingBomb)
              and (state and state.living_bomb_remains or 0) <= 0
      end,
      execute = function(context)
          return NS.try_cast(ACTION.LivingBomb.action, context.target, "[SOD MAGE] LivingBomb")
      end,
    },
    action_strategy("BalefireBolt", ACTION.BalefireBolt),
    action_strategy("SpellfrostBolt", ACTION.SpellfrostBolt),
    action_strategy("FrostfireBolt", ACTION.FrostfireBolt),
    -- Personal haste cooldown: pop whenever speeding up casts helps
    -- (guide: simple yet powerful, no window gate).
    { name = "IcyVeins",
      matches = function(context) return combat_action_matches(context, ACTION.IcyVeins) end,
      execute = function(context)
          return NS.try_cast(ACTION.IcyVeins.action, NS.PLAYER_UNIT, "[SOD MAGE] IcyVeins", { skip_range = true })
      end,
    },
    action_strategy("Frostbolt", ACTION.Frostbolt),
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("dps_mage", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
