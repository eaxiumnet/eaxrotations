-- survival_wotlk.lua — Hunter Survival rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Survival hunter.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.
--          Lock and Load proc (56344-family) read via NS.buff_up (real API);
--          Explosive Shot ladder casts the WotLK max rank 60051 (not 60053/60052).

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")

local define = spec_kit.define_action

local ACTION = {
    AspectOfTheViper = define("AspectOfTheViper", 34074, "AspectOfTheViper"),
    AspectOfTheDragonhawk = define("AspectOfTheDragonhawk", 61847, "AspectOfTheDragonhawk"),
    KillShot = define("KillShot", 61006, "KillShot"),
    -- WotLK 3.3.5 Explosive Shot ladder, max rank first: 60051 (r4) > 60053
    -- (r3) > 60052 (r2) > 53301 (r1). 60051 verified on wowhead WotLK Classic
    -- (spell=60051, Hunter Explosive Shot). The old single-ID define used the
    -- rank-3 downrank 60053 — max-level hunters cast 60051 (W3.1 audit).
    ExplosiveShot = define("ExplosiveShot", { 60051, 60053, 60052, 53301 }, "ExplosiveShot"),
    ExplosiveTrap = define("ExplosiveTrap", 49067, "ExplosiveTrap"),
    BlackArrow = define("BlackArrow", 63672, "BlackArrow"),
    SerpentSting = define("SerpentSting", { 49001, 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }, "SerpentSting"),
    AimedShot = define("AimedShot", { 49050, 27065, 20904, 20903, 20902, 20901, 20900, 19434 }, "AimedShot"),
    MultiShot = define("MultiShot", { 49048, 49047, 27021, 25294, 14290, 14289, 14288, 2643 }, "MultiShot"),
    SteadyShot = define("SteadyShot", { 49052, 34120 }, "SteadyShot"),
    HuntersMark = define("HuntersMark", { 14325, 14324, 14323, 1130 }, "HuntersMark"),
}

local ASPECT_VIPER_BUFF = { 34074 }
local ASPECT_DRAGONHAWK_BUFF = { 61847 }
local SERPENT_STING_DEBUFF = { 49001, 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local EXPLOSIVE_TRAP_DEBUFF = { 49067 }
local BLACK_ARROW_DEBUFF = { 63672, 3674, 63668, 63669, 63670, 63671 }
local HUNTERS_MARK_DEBUFF = { 14325, 14324, 14323, 1130 }
-- Lock and Load talent ranks (56342/56343/56344, 1-3 points). The max-rank
-- aura 56344 is what a fully-talented survival hunter carries; the lower ranks
-- are included for literal-ID matching. Verified on wowhead WotLK Classic.
local LOCK_AND_LOAD_BUFF = { 56344, 56343, 56342 }

local survival_state = {
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    serpent_remains = 0,
    explosive_trap_remains = 0,
    black_arrow_remains = 0,
    mark_remains = 0,
    viper_up = false,
    dragonhawk_up = false,
    lock_and_load = false,
    target_remaining_time = 100,
}

local function build_state(context)
    local state = spec_kit.safe_state(survival_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.mana_pct = (context and context.mana_pct) or (me and NS.unit_mana_pct and NS.unit_mana_pct(me)) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.serpent_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SERPENT_STING_DEBUFF)) or 0
    state.explosive_trap_remains = (target and NS.debuff_remains and NS.debuff_remains(target, EXPLOSIVE_TRAP_DEBUFF)) or 0
    state.black_arrow_remains = (target and NS.debuff_remains and NS.debuff_remains(target, BLACK_ARROW_DEBUFF)) or 0
    state.mark_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HUNTERS_MARK_DEBUFF)) or 0
    if context and context.viper_up ~= nil then
        state.viper_up = context.viper_up
    else
        state.viper_up = (me and NS.buff_up and NS.buff_up(me, ASPECT_VIPER_BUFF)) or false
    end
    if context and context.dragonhawk_up ~= nil then
        state.dragonhawk_up = context.dragonhawk_up
    else
        state.dragonhawk_up = (me and NS.buff_up and NS.buff_up(me, ASPECT_DRAGONHAWK_BUFF)) or false
    end
    -- Lock and Load proc (makes Explosive Shot instant + free): read via the
    -- real buff API. context.lock_and_load is never set by production.
    state.lock_and_load = (me and NS.buff_up and NS.buff_up(me, LOCK_AND_LOAD_BUFF)) or false
    state.target_remaining_time = (context and context.target_remaining_time) or 100
    return state
end

local DSL_DEFS = {
    {
        name = "AspectOfTheViper",
        conditions = {
            { type = "state", field = "viper_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = "<", value = 10 },
        },
        action = { type = "cast", spell = ACTION.AspectOfTheViper, target = "self" },
    },
    {
        name = "AspectOfTheDragonhawk",
        conditions = {
            { type = "state", field = "dragonhawk_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.AspectOfTheDragonhawk, target = "self" },
    },
    {
        name = "HuntersMark",
        conditions = {
            { type = "state", field = "mark_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.HuntersMark, target = "target" },
    },
    {
        name = "KillShot",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = "<", value = 20 },
        },
        action = { type = "cast", spell = ACTION.KillShot, target = "target" },
    },
    {
        name = "ExplosiveShotProc",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "lock_and_load", op = "truthy" },
        },
        -- Lock and Load makes Explosive Shot instant + free: cast the MAX-rank
        -- Explosive Shot (the client applies the free/instant via the proc
        -- aura). The old lane cast the rank-2 downrank 60052 as a separate
        -- action — a silent DPS loss on every proc window.
        action = { type = "cast", spell = ACTION.ExplosiveShot, target = "target" },
    },
    {
        name = "ExplosiveTrap",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "explosive_trap_remains", op = "<", value = 1 },
        },
        action = { type = "cast", spell = ACTION.ExplosiveTrap, target = "target" },
    },
    {
        name = "SerpentSting",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "serpent_remains", op = "<", value = 3 },
            { type = "state", field = "target_remaining_time", op = ">", value = 6 },
        },
        action = { type = "cast", spell = ACTION.SerpentSting, target = "target" },
    },
    {
        name = "BlackArrow",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "black_arrow_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.BlackArrow, target = "target" },
    },
    {
        name = "ExplosiveShot",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            -- Outside the Lock and Load proc window the plain lane handles the
            -- normal (costed, cast-time) shot; during the proc window the
            -- ExplosiveShotProc lane above fires the instant/free cast. Keeps
            -- the proc lane reachable in the production dispatcher.
            { type = "state", field = "lock_and_load", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.ExplosiveShot, target = "target" },
    },
    {
        name = "AimedShot",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.AimedShot, target = "target" },
    },
    {
        name = "MultiShot",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
        },
        action = { type = "cast", spell = ACTION.MultiShot, target = "target" },
    },
    {
        name = "SteadyShot",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.SteadyShot, target = "target" },
    },
}

local strategies = {
    { name = "AspectOfTheViper" },
    { name = "AspectOfTheDragonhawk" },
    { name = "HuntersMark" },
    { name = "KillShot" },
    { name = "ExplosiveShot" },
    { name = "ExplosiveShotProc" },
    { name = "ExplosiveTrap" },
    { name = "SerpentSting" },
    { name = "BlackArrow" },
    { name = "AimedShot" },
    { name = "MultiShot" },
    { name = "SteadyShot" },
}

-- Name-based substitution preserves the existing priority order
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("survival", strategies, { get_state = build_state })
end
if NS.log then NS.log("Hunter survival rotation registered") end

return { strategies = strategies, build_state = build_state }
