-- beast_mastery_wotlk.lua — Hunter Beast Mastery rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Beast Mastery hunter.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.HunterSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    KillCommand = define("KillCommand", 34026, "KillCommand"),
    SerpentSting = define("SerpentSting", { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }, "SerpentSting"),
    SteadyShot = define("SteadyShot", 34120, "SteadyShot"),
    ArcaneShot = define("ArcaneShot", { 27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 }, "ArcaneShot"),
    BestialWrath = define("BestialWrath", 19574, "BestialWrath"),
    HuntersMark = define("HuntersMark", { 14325, 14324, 14323, 1130 }, "HuntersMark"),
}

local SERPENT_STING_DEBUFF = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local HUNTERS_MARK_DEBUFF = { 14325, 14324, 14323, 1130 }

local bm_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    serpent_remains = 0,
    mark_remains = 0,
    bestial_wrath_ready = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(bm_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.serpent_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SERPENT_STING_DEBUFF)) or 0
    state.mark_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HUNTERS_MARK_DEBUFF)) or 0
    state.bestial_wrath_ready = (ACTION.BestialWrath and ACTION.BestialWrath.cooldown_remaining and ACTION.BestialWrath:cooldown_remaining() <= 0) or false
    return state
end

local function hunters_mark_matches(context, state)
    return state.mark_remains < 3
end

local function serpent_sting_matches(context, state)
    return state.serpent_remains < 3
end

local function bestial_wrath_matches(context, state)
    return state.bestial_wrath_ready
end

local function kill_command_matches(context, state)
    return true
end

local function arcane_shot_matches(context, state)
    return state.mana_pct >= 20
end

local function steady_shot_matches(context, state)
    return true
end

local strategies = {
    { name = "HuntersMark", matches = hunters_mark_matches, execute = function(ctx) return ACTION.HuntersMark and ACTION.HuntersMark:cast_safe(ctx.target) end },
    { name = "BestialWrath", matches = bestial_wrath_matches, execute = function(ctx) return ACTION.BestialWrath and ACTION.BestialWrath:cast_safe() end },
    { name = "KillCommand", matches = kill_command_matches, execute = function(ctx) return ACTION.KillCommand and ACTION.KillCommand:cast_safe(ctx.target) end },
    { name = "SerpentSting", matches = serpent_sting_matches, execute = function(ctx) return ACTION.SerpentSting and ACTION.SerpentSting:cast_safe(ctx.target) end },
    { name = "ArcaneShot", matches = arcane_shot_matches, execute = function(ctx) return ACTION.ArcaneShot and ACTION.ArcaneShot:cast_safe(ctx.target) end },
    { name = "SteadyShot", matches = steady_shot_matches, execute = function(ctx) return ACTION.SteadyShot and ACTION.SteadyShot:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("beast_mastery", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
