-- affliction_wotlk.lua — Warlock Affliction rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Affliction warlock.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.WarlockSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    UnstableAffliction = define("UnstableAffliction", { 30405, 30404, 30108 }, "UnstableAffliction"),
    Haunt = define("Haunt", 48181, "Haunt"),
    Corruption = define("Corruption", { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    CurseOfAgony = define("CurseOfAgony", { 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfAgony"),
    DrainSoul = define("DrainSoul", { 27217, 11675, 8289, 8288, 1120 }, "DrainSoul"),
    ShadowBolt = define("ShadowBolt", { 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
}

local UNSTABLE_AFFLICTION_DEBUFF = { 30405, 30404, 30108 }
local CORRUPTION_DEBUFF = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local CURSE_OF_AGONY_DEBUFF = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }
local HAUNT_DEBUFF = { 48181, 59164 }

local affliction_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    unstable_remains = 0,
    haunt_remains = 0,
    corruption_remains = 0,
    agony_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(affliction_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.unstable_remains = (target and NS.debuff_remains and NS.debuff_remains(target, UNSTABLE_AFFLICTION_DEBUFF)) or 0
    state.haunt_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HAUNT_DEBUFF)) or 0
    state.corruption_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CORRUPTION_DEBUFF)) or 0
    state.agony_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_AGONY_DEBUFF)) or 0
    return state
end

local function unstable_affliction_matches(context, state)
    return state.unstable_remains < 3
end

local function haunt_matches(context, state)
    return state.haunt_remains < 3
end

local function corruption_matches(context, state)
    return state.corruption_remains < 3
end

local function curse_of_agony_matches(context, state)
    return state.agony_remains < 3
end

local function drain_soul_matches(context, state)
    return state.target_hp < 25
end

local function shadow_bolt_matches(context, state)
    return state.mana_pct >= 20
end

local strategies = {
    { name = "Haunt", matches = haunt_matches, execute = function(ctx) return ACTION.Haunt and ACTION.Haunt:cast_safe(ctx.target) end },
    { name = "UnstableAffliction", matches = unstable_affliction_matches, execute = function(ctx) return ACTION.UnstableAffliction and ACTION.UnstableAffliction:cast_safe(ctx.target) end },
    { name = "Corruption", matches = corruption_matches, execute = function(ctx) return ACTION.Corruption and ACTION.Corruption:cast_safe(ctx.target) end },
    { name = "CurseOfAgony", matches = curse_of_agony_matches, execute = function(ctx) return ACTION.CurseOfAgony and ACTION.CurseOfAgony:cast_safe(ctx.target) end },
    { name = "DrainSoul", matches = drain_soul_matches, execute = function(ctx) return ACTION.DrainSoul and ACTION.DrainSoul:cast_safe(ctx.target) end },
    { name = "ShadowBolt", matches = shadow_bolt_matches, execute = function(ctx) return ACTION.ShadowBolt and ACTION.ShadowBolt:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("affliction", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
