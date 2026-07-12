-- marksmanship_wotlk.lua — Hunter Marksmanship rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Marksmanship hunter.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.HunterSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    SerpentSting = define("SerpentSting", { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }, "SerpentSting"),
    ChimeraShot = define("ChimeraShot", 53209, "ChimeraShot"),
    AimedShot = define("AimedShot", { 27065, 20904, 20903, 20902, 20901, 20900, 19434 }, "AimedShot"),
    ArcaneShot = define("ArcaneShot", { 27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 }, "ArcaneShot"),
    SteadyShot = define("SteadyShot", 34120, "SteadyShot"),
    KillShot = define("KillShot", 53351, "KillShot"),
    HuntersMark = define("HuntersMark", { 14325, 14324, 14323, 1130 }, "HuntersMark"),
}

local SERPENT_STING_DEBUFF = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local HUNTERS_MARK_DEBUFF = { 14325, 14324, 14323, 1130 }

local mm_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    serpent_remains = 0,
    mark_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(mm_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.serpent_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SERPENT_STING_DEBUFF)) or 0
    state.mark_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HUNTERS_MARK_DEBUFF)) or 0
    return state
end

local function hunters_mark_matches(context, state)
    return state.mark_remains < 3
end

local function serpent_sting_matches(context, state)
    return state.serpent_remains < 3
end

local function chimera_shot_matches(context, state)
    return true
end

local function aimed_shot_matches(context, state)
    return true
end

local function arcane_shot_matches(context, state)
    return state.mana_pct >= 20
end

local function kill_shot_matches(context, state)
    return state.target_hp < 20
end

local function steady_shot_matches(context, state)
    return true
end

local strategies = {
    { name = "HuntersMark", matches = hunters_mark_matches, execute = function(ctx) return ACTION.HuntersMark and ACTION.HuntersMark:cast_safe(ctx.target) end },
    { name = "KillShot", matches = kill_shot_matches, execute = function(ctx) return ACTION.KillShot and ACTION.KillShot:cast_safe(ctx.target) end },
    { name = "SerpentSting", matches = serpent_sting_matches, execute = function(ctx) return ACTION.SerpentSting and ACTION.SerpentSting:cast_safe(ctx.target) end },
    { name = "ChimeraShot", matches = chimera_shot_matches, execute = function(ctx) return ACTION.ChimeraShot and ACTION.ChimeraShot:cast_safe(ctx.target) end },
    { name = "AimedShot", matches = aimed_shot_matches, execute = function(ctx) return ACTION.AimedShot and ACTION.AimedShot:cast_safe(ctx.target) end },
    { name = "ArcaneShot", matches = arcane_shot_matches, execute = function(ctx) return ACTION.ArcaneShot and ACTION.ArcaneShot:cast_safe(ctx.target) end },
    { name = "SteadyShot", matches = steady_shot_matches, execute = function(ctx) return ACTION.SteadyShot and ACTION.SteadyShot:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("marksmanship", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
