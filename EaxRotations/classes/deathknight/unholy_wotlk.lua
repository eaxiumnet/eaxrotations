-- unholy_wotlk.lua — Death Knight Unholy DPS rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Unholy death knight with disease maintenance,
--        Scourge Strike, Summon Gargoyle, Death and Decay AoE, pet management, and
--        buff upkeep via rune_manager, presence_manager, and interrupt_manager.
-- WHEN:  combat with valid enemy target on WotLK 3.3.5a clients.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit          = require("shared/spec_kit_sylvanas")
local dsl               = require("shared/strategy_dsl_sylvanas")
local rune_manager = require("shared/rune_manager_sylvanas")
local presence_manager = require("shared/presence_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")

local SPELLS = NS.DeathKnightSpells or {}
local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    IcyTouch          = define("IcyTouch",          { 45477, 49903, 49904, 49909 }, "IcyTouch"),
    PlagueStrike      = define("PlagueStrike",      { 49917, 49918, 49919, 49920, 49921 }, "PlagueStrike"),
    ScourgeStrike     = define("ScourgeStrike",     { 55090, 55265, 55270, 55271 }, "ScourgeStrike"),
    BloodStrike       = define("BloodStrike",       { 45902, 49926, 49927, 49928, 49929, 49930 }, "BloodStrike"),
    DeathCoil         = define("DeathCoil",         { 47541, 49892, 49893, 49894, 49895 }, "DeathCoil"),
    Pestilence        = define("Pestilence",        { 50842 }, "Pestilence"),
    DeathAndDecay     = define("DeathAndDecay",     { 43265, 49936, 49937, 49938 }, "DeathAndDecay"),
    SummonGargoyle    = define("SummonGargoyle",    49206, "SummonGargoyle"),
    HornOfWinter      = define("HornOfWinter",      { 57330, 57623 }, "HornOfWinter"),
    EmpowerRuneWeapon = define("EmpowerRuneWeapon", 47568, "EmpowerRuneWeapon"),
    BoneShield        = define("BoneShield",        49222, "BoneShield"),
    RaiseDead         = define("RaiseDead",         46584, "RaiseDead"),
    BloodPresence     = define("BloodPresence",     48266, "BloodPresence"),
    FrostPresence     = define("FrostPresence",     48263, "FrostPresence"),
    UnholyPresence    = define("UnholyPresence",    48265, "UnholyPresence"),
}

local FROST_FEVER         = { 55095 }
local BLOOD_PLAGUE        = { 55078 }
local HORN_OF_WINTER_BUFF = { 57330, 57623 }
local BONE_SHIELD_BUFF    = { 49222 }

local unholy_state = {
    hp                   = 100,
    target_hp            = 100,
    enemy_count          = 1,
    in_combat            = false,
    frost_fever_remains  = 0,
    blood_plague_remains = 0,
    horn_of_winter_up    = false,
    bone_shield_up       = false,
    runic_power          = 0,
    rune_ready           = { blood = 0, frost = 0, unholy = 0, death = 0 },
    pet_present          = false,
    is_boss              = false,
    spec                 = "unholy",
    role                 = "dps",
}

local function build_state(context)
    local state = spec_kit.safe_state(unholy_state)
    local target = context and context.target
    local me = NS.me

    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false

    state.frost_fever_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FROST_FEVER)) or 0
    state.blood_plague_remains = (target and NS.debuff_remains and NS.debuff_remains(target, BLOOD_PLAGUE)) or 0

    state.horn_of_winter_up = (me and NS.buff_up and NS.buff_up(me, HORN_OF_WINTER_BUFF)) or false
    state.bone_shield_up = (me and NS.buff_up and NS.buff_up(me, BONE_SHIELD_BUFF)) or false

    state.runic_power = 0
    if me and rune_manager then
        state.runic_power = rune_manager.get_runic_power(me) or 0
    end

    state.rune_ready = { blood = 0, frost = 0, unholy = 0, death = 0 }
    if rune_manager then
        local runes = rune_manager.get_rune_state()
        if runes and runes.ready then
            state.rune_ready = runes.ready
        end
    end

    state.pet_present = false
    if NS.has_pet then
        local ok, has = pcall(NS.has_pet)
        if ok then state.pet_present = has or false end
    end

    state.is_boss = (context and context.is_boss) or false

    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "HornOfWinter",
        conditions = {
            { type = "state", field = "horn_of_winter_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.HornOfWinter, target = "self" },
    },
    {
        name = "BoneShield",
        conditions = {
            { type = "state", field = "bone_shield_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.BoneShield, target = "self" },
    },
    {
        name = "RaiseDead",
        conditions = {
            { type = "state", field = "pet_present", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.RaiseDead, target = "target" },
    },
    {
        name = "SummonGargoyle",
        conditions = {
            { type = "state", field = "is_boss", op = "truthy" },
            { type = "state", field = "runic_power", op = ">=", value = 60 },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.SummonGargoyle, target = "target" },
    },
    {
        name = "EmpowerRuneWeapon",
        conditions = {
            { type = "custom", fn = function(context, state)
                local ready = state.rune_ready or { blood = 0, frost = 0, unholy = 0, death = 0 }
                local total = (ready.blood or 0) + (ready.frost or 0) + (ready.unholy or 0) + (ready.death or 0)
                return total == 0
            end },
        },
        action = { type = "cast", spell = ACTION.EmpowerRuneWeapon, target = "self" },
    },
    {
        name = "IcyTouch",
        conditions = {
            { type = "state", field = "frost_fever_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.IcyTouch, target = "target" },
    },
    {
        name = "PlagueStrike",
        conditions = {
            { type = "state", field = "blood_plague_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.PlagueStrike, target = "target" },
    },
    {
        name = "Pestilence",
        conditions = {
            { type = "custom", fn = function(context, state)
                local ff = (state.frost_fever_remains or 0)
                local bp = (state.blood_plague_remains or 0)
                if ff <= 0 or bp <= 0 then return false end
                return (ff < 3 or bp < 3)
                    and NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_10) or 10, context and context.target, context)
            end },
        },
        action = { type = "cast", spell = ACTION.Pestilence, target = "target" },
    },
    {
        name = "DeathCoil",
        conditions = {
            { type = "state", field = "runic_power", op = ">=", value = 100 },
        },
        action = { type = "cast", spell = ACTION.DeathCoil, target = "target" },
    },
    {
        name = "DeathAndDecay",
        conditions = {
            { type = "custom", fn = function(context, state)
                return NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_10) or 10, context and context.target, context, state)
            end },
        },
        action = { type = "cast", spell = ACTION.DeathAndDecay, target = "target" },
    },
    {
        name = "ScourgeStrike",
        conditions = {
            { type = "state", field = "frost_fever_remains", op = ">", value = 0 },
            { type = "state", field = "blood_plague_remains", op = ">", value = 0 },
        },
        action = { type = "cast", spell = ACTION.ScourgeStrike, target = "target" },
    },
    {
        name = "BloodStrike",
        conditions = {},
        action = { type = "cast", spell = ACTION.BloodStrike, target = "target" },
    },
    {
        name = "DeathCoilDump",
        conditions = {
            { type = "state", field = "runic_power", op = ">=", value = 40 },
        },
        action = { type = "cast", spell = ACTION.DeathCoil, target = "target" },
    },
}

-- ---------------------------------------------------------------------------
-- Presence execute helper
-- ---------------------------------------------------------------------------

local function presence_execute(ctx)
    if not presence_manager then return false end
    local desired = presence_manager.get_optimal_presence(ctx, {})
    if not desired then return false end
    local action = nil
    if desired == "blood" then action = ACTION.BloodPresence
    elseif desired == "frost" then action = ACTION.FrostPresence
    elseif desired == "unholy" then action = ACTION.UnholyPresence end
    if action and action.cast_safe then return action:cast_safe() end
    return false
end

-- ---------------------------------------------------------------------------
-- Interrupt strategy via interrupt_manager
-- ---------------------------------------------------------------------------

local interrupt_strategy = nil
if interrupt_manager and interrupt_manager.register_interrupt_spell then
    local ok, strat = pcall(interrupt_manager.register_interrupt_spell, "deathknight", "MindFreeze", SPELLS)
    if ok and strat then interrupt_strategy = strat end
end

-- ---------------------------------------------------------------------------
-- Strategies (interrupt + Presence kept manual for complex multi-action execute)
-- ---------------------------------------------------------------------------

local strategies = {}

if interrupt_strategy then
    strategies[#strategies + 1] = interrupt_strategy
end

-- Name-only placeholders — substituted by DSL loop below
strategies[#strategies + 1] = { name = "HornOfWinter" }
strategies[#strategies + 1] = { name = "BoneShield" }

-- Presence kept manual because its execute chooses between 3 spells dynamically
strategies[#strategies + 1] = { name = "Presence", matches = function(context, state)
    if not presence_manager then return false end
    local desired = presence_manager.get_optimal_presence(context, state)
    if not desired then return false end
    return presence_manager.should_switch_presence(context, state, desired)
end, execute = presence_execute }

strategies[#strategies + 1] = { name = "RaiseDead" }
strategies[#strategies + 1] = { name = "SummonGargoyle" }
strategies[#strategies + 1] = { name = "EmpowerRuneWeapon" }
strategies[#strategies + 1] = { name = "IcyTouch" }
strategies[#strategies + 1] = { name = "PlagueStrike" }
strategies[#strategies + 1] = { name = "Pestilence" }
strategies[#strategies + 1] = { name = "DeathCoil" }
strategies[#strategies + 1] = { name = "DeathAndDecay" }
strategies[#strategies + 1] = { name = "ScourgeStrike" }
strategies[#strategies + 1] = { name = "BloodStrike" }
strategies[#strategies + 1] = { name = "DeathCoilDump" }

-- Name-based substitution preserves the existing priority order.
-- interrupt_strategy and Presence (position 4) have no DSL_DEFS name match, so they remain as-is.
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
    NS.rotation_registry:register("unholy", strategies, { get_state = build_state })
end
if NS.log then NS.log("Death Knight unholy rotation registered") end

return { strategies = strategies, build_state = build_state }
