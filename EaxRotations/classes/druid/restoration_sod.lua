-- restoration_sod.lua -- Druid Restoration rotation for Season of Discovery.
-- WHAT: Wild Growth, Nourish, Lifebloom, Rejuvenation, and Healing Touch triage.
-- WHEN: SoD healing with a valid friendly target.
-- WHY: adds native rune-aware healing around the pinned simulator package contract.
--      2026-09-09 guide pass (Wowhead SoD druid-healer rune guide: Survival
--      Instincts / Living Seed / Efflorescence / Lifebloom / Tree of Life ...):
--      adds Swiftmend (the Efflorescence rune's trigger — the rune is passive,
--      417149, and rides the Swiftmend cast 18562), the Nature's Swiftness +
--      Healing Touch emergency pair, Innervate, and battle-Rebirth. Ids
--      verified in the SoD client DBC (wowsims.db); Rebirth ladder capped at
--      20748 (the level-60 rank in this client).
-- SAFETY: friendly target, health, phase, and rune state all fail closed.

local NS = _G.EaxRotations
if not NS then return nil end
if type(NS.is_sod) == "function" and not NS.is_sod() then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_sod_action_for_class({})

-- 2026-09-15 SoD healer wave: deficit-fit HT ladder from the shared
-- heal-value module (SoD HT ids are a subset of its 13-rank table).
-- Fail-closed: without the module the HT lane keeps the single action.
-- The NS+HT emergency pair deliberately stays max-rank single-action.
local HEALING_TOUCH_RANKS
local _hv_ok, _HealValue = pcall(require, "shared/heal_value_sylvanas")
if _hv_ok and type(_HealValue) == "table" then
    NS.HealValue = NS.HealValue or _HealValue
    local function _mk_ht(id)
        return NS.spell_action(id, "HealingTouch")
    end
    HEALING_TOUCH_RANKS = _HealValue.build_ladder("druid", "HealingTouch", _mk_ht, nil, "sod")
end
local cast_best_heal_rank = NS.cast_best_heal_rank or function() return nil end
local ACTION = {
    WildGrowth = define("WildGrowth", 408120, { rune_id = 408120 }, "WildGrowth"),
    Nourish = define("Nourish", 408247, { rune_id = 408247, min_phase = 2 }, "Nourish"),
    Lifebloom = define("Lifebloom", 409824, { rune_id = 409824 }, "Lifebloom"),
    Rejuvenation = define("Rejuvenation", { 25299, 9841, 774 }, {}, "Rejuvenation"),
    HealingTouch = define("HealingTouch", { 25297, 9888, 5185 }, {}, "HealingTouch"),
    -- Era-common self-buff cooldown (bridge 6669/6664); guide: use whenever
    -- healing opportunity is high.
    SurvivalInstincts = define("SurvivalInstincts", { 6669, 6664 }, {}, "SurvivalInstincts"),
    -- 2026-09-09 guide-pass additions (DBC-verified):
    -- Swiftmend (18562, 15s CD): consumes Rejuv/Regrowth on the target; the
    -- Efflorescence rune (passive 417149) makes the cast also drop the ground
    -- HoT — so the lane's job is the Swiftmend cast.
    Swiftmend = define("Swiftmend", { 18562 }, {}, "Swiftmend"),
    -- Nature's Swiftness: druid version is 17116 in this client (shaman
    -- 16188; SLA rows prove the split), 3-min CD, next nature spell instant.
    NaturesSwiftness = define("NaturesSwiftness", 17116, {}, "NaturesSwiftness"),
    -- Innervate (29166, 6-min CD): mana game. 29167 is the buff id
    -- (item-indexed in this client) - NOT a cast id, excluded.
    Innervate = define("Innervate", 29166, {}, "Innervate"),
    -- Rebirth battle-rez, classic-60 ladder 20748 (lv 60) / 20747 (lv 50) /
    -- 20484 (lv 20); 30-min CD at 60. 10-min in WotLK, NOT here.
    Rebirth = define("Rebirth", { 20748, 20747, 20484 }, {}, "Rebirth"),
}

local NATURES_SWIFTNESS_BUFF = { 17116 }

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
        player_hp = type(context.player_hp) == "number" and context.player_hp
            or (type(context.hp) == "number" and context.hp) or 100,
        natures_swiftness_up = (type(NS.buff_up) == "function"
            and NS.buff_up(NS.PLAYER_UNIT or (NS.me and NS.me), NATURES_SWIFTNESS_BUFF) == true),
        in_group = context.is_group == true or context.is_raid == true,
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
    { name = "NaturesSwiftness", matches = function(c, s)
        return type(c) == "table" and c.is_sod == true and spec_kit.sod_action_available(c, ACTION.NaturesSwiftness)
            and s.natures_swiftness_up == false and s.player_hp <= 30
    end,
      execute = function(c) return NS.try_cast(ACTION.NaturesSwiftness.action, NS.PLAYER_UNIT, "[SOD RESTORATION] NaturesSwiftness", { skip_range = true }) end },
    { name = "NaturesSwiftnessHealingTouch", matches = function(c, s)
        return type(c) == "table" and c.is_sod == true and spec_kit.sod_action_available(c, ACTION.NaturesSwiftness)
            and s.natures_swiftness_up and s.heal_target ~= nil and s.heal_target_hp_pct < 50
    end,
      execute = function(c) return cast(ACTION.HealingTouch, c, "NaturesSwiftness Healing Touch") end },
    { name = "Rebirth", matches = function(c, s)
        return type(c) == "table" and c.is_sod == true and spec_kit.sod_action_available(c, ACTION.Rebirth)
            and s.in_group == true and type(NS.find_dead_party_ally) == "function"
            and NS.find_dead_party_ally() ~= nil
    end,
      execute = function(c)
          local dead = NS.find_dead_party_ally and NS.find_dead_party_ally() or nil
          if not dead then return false end
          return NS.try_cast(ACTION.Rebirth.action, dead, "[SOD RESTORATION] Rebirth", { skip_range = true })
      end },
    { name = "Innervate", matches = function(c, s)
        return type(c) == "table" and c.is_sod == true and spec_kit.sod_action_available(c, ACTION.Innervate)
            and (type(c.mana_pct) == "number" and c.mana_pct <= 40)
    end,
      execute = function(c) return NS.try_cast(ACTION.Innervate.action, NS.PLAYER_UNIT, "[SOD RESTORATION] Innervate", { skip_range = true }) end },
    { name = "WildGrowth", matches = function(c, s) return base(c, s, ACTION.WildGrowth) and s.injured_count >= 2 and s.heal_target_hp_pct < 85 and ready(ACTION.WildGrowth, s.heal_target) end,
      execute = function(c) return cast(ACTION.WildGrowth, c, "Wild Growth") end },
    -- Self-buff cooldown, no friendly target needed (base() requires one, so
    -- this lane carries its own availability check).
    { name = "SurvivalInstincts", matches = function(c, s)
        return type(c) == "table" and c.is_sod == true
            and spec_kit.sod_action_available(c, ACTION.SurvivalInstincts)
    end, execute = function(c)
        return NS.try_cast(ACTION.SurvivalInstincts.action, NS.PLAYER_UNIT, "[SOD RESTORATION] SurvivalInstincts", { skip_range = true })
    end },
    { name = "Nourish", matches = function(c, s) return base(c, s, ACTION.Nourish) and s.heal_target_hp_pct <= 60 and ready(ACTION.Nourish, s.heal_target) end,
      execute = function(c) return cast(ACTION.Nourish, c, "Nourish") end },
    { name = "Swiftmend", matches = function(c, s) return base(c, s, ACTION.Swiftmend) and s.heal_target_hp_pct <= 65
        and s.has_rejuvenation and ready(ACTION.Swiftmend, s.heal_target) end,
      execute = function(c) return cast(ACTION.Swiftmend, c, "Swiftmend") end },
    { name = "Lifebloom", matches = function(c, s) return base(c, s, ACTION.Lifebloom) and s.heal_target_hp_pct <= 80 and not s.has_lifebloom and ready(ACTION.Lifebloom, s.heal_target) end,
      execute = function(c) return cast(ACTION.Lifebloom, c, "Lifebloom") end },
    { name = "Rejuvenation", matches = function(c, s) return base(c, s, ACTION.Rejuvenation) and s.heal_target_hp_pct <= 75 and not s.has_rejuvenation and ready(ACTION.Rejuvenation, s.heal_target) end,
      execute = function(c) return cast(ACTION.Rejuvenation, c, "Rejuvenation") end },
    { name = "HealingTouch", matches = function(c, s) return base(c, s, ACTION.HealingTouch) and s.heal_target_hp_pct <= 50 and ready(ACTION.HealingTouch, s.heal_target) end,
      execute = function(c)
        -- deficit-fit rank over the ladder (SoD penalty divisor 60);
        -- the single-action path is the fail-closed fallback.
        if HEALING_TOUCH_RANKS then
            local s = build_state(c)
            if s.heal_target then
                local chosen, rank_label = cast_best_heal_rank(HEALING_TOUCH_RANKS,
                    s.heal_target, c, "[SOD RESTORATION] Healing Touch", { player_level = 60 })
                if chosen then return NS.try_cast(chosen, s.heal_target, rank_label) end
            end
        end
        return cast(ACTION.HealingTouch, c, "Healing Touch")
      end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("restoration", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state, actions = ACTION }
