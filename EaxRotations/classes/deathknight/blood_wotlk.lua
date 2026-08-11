-- blood_wotlk.lua — Death Knight Blood DPS rotation for Wrath of the Lich King (3.3.5a).
-- WHAT:  priority-list strategies for Blood death knight: disease maintenance
--        (Icy Touch -> Plague Strike -> Pestilence refresh), Heart Strike spam,
--        Death Strike self-heal, Death Coil runic-power dump, Dancing Rune Weapon
--        on boss targets, and Vampiric Blood / Icebound Fortitude defensives.
-- WHEN:  combat with a valid enemy target; Blood Presence is the default DPS presence.
-- WHY:   mirrors the DarhangeR Blood_DPS PQR profile / SimulationCraft APL with
--        WotLK 3.3.5a mechanics (rune + runic-power economy, disease refresh windows).
-- SAFETY: all state.* reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocations.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit          = require("shared/spec_kit_sylvanas")
local dsl               = require("shared/strategy_dsl_sylvanas")
local RuneManager       = require("shared/rune_manager_sylvanas")
local PresenceManager   = require("shared/presence_manager_sylvanas")
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")
if not _ok_int or type(interrupt_manager) ~= "table" then interrupt_manager = nil end

local SPELLS = NS.DeathKnightSpells or {}
local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    IcyTouch          = define("IcyTouch",          { 49909, 45477, 49903, 49904 }, "IcyTouch"),
    PlagueStrike      = define("PlagueStrike",      { 49921, 49917, 49918, 49919, 49920 }, "PlagueStrike"),
    Pestilence        = define("Pestilence",        { 50842 }, "Pestilence"),
    HeartStrike       = define("HeartStrike",       { 55262, 55050, 55258, 55259, 55260, 55261 }, "HeartStrike"),
    DeathStrike       = define("DeathStrike",       { 49999, 49998, 45463, 49924 }, "DeathStrike"),
    DeathCoil         = define("DeathCoil",         { 49895, 47541, 49892, 49893, 49894 }, "DeathCoil"),
    DancingRuneWeapon = define("DancingRuneWeapon", 49028, "DancingRuneWeapon"),
    HornOfWinter      = define("HornOfWinter",      { 57623, 57330 }, "HornOfWinter"),
    VampiricBlood     = define("VampiricBlood",     55233, "VampiricBlood"),
    IceboundFortitude = define("IceboundFortitude", 48792, "IceboundFortitude"),
    BloodPresence     = define("BloodPresence",     48266, "BloodPresence"),
}

local DK_CONST            = NS.DeathKnightConstants or {}
local FROST_FEVER         = DK_CONST.FROST_FEVER_DEBUFF or { 55095 }
local BLOOD_PLAGUE        = DK_CONST.BLOOD_PLAGUE_DEBUFF or { 55078 }
local HORN_OF_WINTER_BUFF = DK_CONST.HORN_OF_WINTER_BUFF or { 57623, 57330 }

local BLOOD_PRESENCE_BUFF  = { 48266 }
local FROST_PRESENCE_BUFF  = { 48263 }
local UNHOLY_PRESENCE_BUFF = { 48265 }

local blood_state = {
    hp                   = 100,
    target_hp            = 100,
    enemy_count          = 1,
    in_combat            = false,
    frost_fever_remains  = 0,
    blood_plague_remains = 0,
    horn_of_winter_up    = false,
    runic_power          = 0,
    presence             = nil,
}

-- safe_cast: invoke an action's cast_safe only when it is a real action table.
-- Guards minimal test mocks where NS.spell_action is absent and define_action
-- falls back to returning a bare spell id (a number).
local function safe_cast(action, target)
    if action and type(action) == "table" and type(action.cast_safe) == "function" then
        return action:cast_safe(target)
    end
    return false
end

local function build_state(context)
    local state  = spec_kit.safe_state(blood_state)
    local target = context and context.target
    local me     = NS.me or (NS.GetPlayer and NS.GetPlayer())

    state.hp           = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp    = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count  = (context and context.enemy_count) or 1
    state.in_combat    = (context and context.in_combat) or false

    state.frost_fever_remains  = (target and NS.debuff_remains and NS.debuff_remains(target, FROST_FEVER)) or 0
    state.blood_plague_remains = (target and NS.debuff_remains and NS.debuff_remains(target, BLOOD_PLAGUE)) or 0

    state.horn_of_winter_up = (me and NS.buff_up and NS.buff_up(me, HORN_OF_WINTER_BUFF)) or false

    -- Runic power and rune snapshot sourced from RuneManager (shared module).
    state.runic_power = RuneManager.get_runic_power(me)

    if me and NS.buff_up and NS.buff_up(me, BLOOD_PRESENCE_BUFF) then
        state.presence = PresenceManager.presence_id("blood")
    elseif me and NS.buff_up and NS.buff_up(me, FROST_PRESENCE_BUFF) then
        state.presence = PresenceManager.presence_id("frost")
    elseif me and NS.buff_up and NS.buff_up(me, UNHOLY_PRESENCE_BUFF) then
        state.presence = PresenceManager.presence_id("unholy")
    else
        state.presence = nil
    end

    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "Presence",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not (NS.is_wotlk and NS.is_wotlk()) then return false end
                local desired = PresenceManager.get_optimal_presence(context, state)
                if not desired then return false end
                return PresenceManager.should_switch_presence(context, state, desired)
            end },
        },
        action = { type = "cast", spell = ACTION.BloodPresence, target = "self" },
    },
    {
        name = "IceboundFortitude",
        conditions = {
            { type = "state", field = "hp", op = "<", value = 40 },
        },
        action = { type = "cast", spell = ACTION.IceboundFortitude, target = "self" },
    },
    {
        name = "VampiricBlood",
        conditions = {
            { type = "state", field = "hp", op = "<", value = 50 },
        },
        action = { type = "cast", spell = ACTION.VampiricBlood, target = "self" },
    },
    {
        name = "HornOfWinter",
        conditions = {
            { type = "state", field = "horn_of_winter_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.HornOfWinter, target = "self" },
    },
    {
        name = "DancingRuneWeapon",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = ">", value = 50 },
            { type = "state", field = "runic_power", op = ">=", value = 60 },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 90) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.DancingRuneWeapon, target = "target" },
    },
    {
        name = "PlagueStrike",
        conditions = {
            { type = "state", field = "blood_plague_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.PlagueStrike, target = "target" },
    },
    {
        name = "DeathStrike",
        conditions = {
            { type = "state", field = "hp", op = "<", value = 80 },
        },
        action = { type = "cast", spell = ACTION.DeathStrike, target = "target" },
    },
    {
        name = "Pestilence",
        conditions = {
            { type = "custom", fn = function(context, state)
                local ff = (state.frost_fever_remains or 0)
                local bp = (state.blood_plague_remains or 0)
                if ff <= 0 or bp <= 0 then return false end
                return ff < 3 or bp < 3
            end },
        },
        action = { type = "cast", spell = ACTION.Pestilence, target = "target" },
    },
    {
        name = "IcyTouch",
        conditions = {
            { type = "state", field = "frost_fever_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.IcyTouch, target = "target" },
    },
    {
        name = "HeartStrike",
        conditions = {},
        action = { type = "cast", spell = ACTION.HeartStrike, target = "target" },
    },
    {
        name = "DeathCoil",
        conditions = {
            { type = "state", field = "runic_power", op = ">=", value = 40 },
        },
        action = { type = "cast", spell = ACTION.DeathCoil, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (interrupt_strategy injected by interrupt_manager, then
-- name-only placeholders substituted by DSL)
-- -----------------------------------------------------------------------------
local interrupt_strategy = nil
if interrupt_manager and interrupt_manager.register_interrupt_spell then
    local ok, strat = pcall(interrupt_manager.register_interrupt_spell, "deathknight", "MindFreeze", SPELLS)
    if ok and strat then interrupt_strategy = strat end
end

local strategies = {
    interrupt_strategy or { name = "MindFreezeSkip", matches = function() return false end, execute = function() return false end },
    { name = "Presence" },
    { name = "IceboundFortitude" },
    { name = "VampiricBlood" },
    { name = "HornOfWinter" },
    { name = "DancingRuneWeapon" },
    { name = "PlagueStrike" },
    { name = "DeathStrike" },
    { name = "Pestilence" },
    { name = "IcyTouch" },
    { name = "HeartStrike" },
    { name = "DeathCoil" },
}

-- Name-based substitution preserves the existing priority order.
-- interrupt_strategy (position 1) has no DSL_DEFS name match, so it remains as-is.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

-- Register (guarded — nil-safe in unit tests)
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("blood", strategies, { get_state = build_state })
end
if NS.log then NS.log("Death Knight blood rotation registered") end

return { strategies = strategies, build_state = build_state }
