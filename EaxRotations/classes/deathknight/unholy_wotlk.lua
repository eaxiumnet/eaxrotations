-- unholy_wotlk.lua — Death Knight Unholy DPS rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Unholy death knight with disease maintenance,
--        Scourge Strike, Summon Gargoyle, Death and Decay AoE, pet commands
--        (Ghoul Gnaw on casting targets, Ghoul Leap gap close), and buff upkeep
--        via rune_manager, presence_manager, and interrupt_manager.
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
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")
if not _ok_int or type(interrupt_manager) ~= "table" then interrupt_manager = nil end

local SPELLS = NS.DeathKnightSpells or {}
local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    IcyTouch          = define("IcyTouch",          { 49909, 45477, 49903, 49904 }, "IcyTouch"),
    PlagueStrike      = define("PlagueStrike",      { 49921, 49917, 49918, 49919, 49920 }, "PlagueStrike"),
    ScourgeStrike     = define("ScourgeStrike",     { 55271, 55090, 55265, 55270 }, "ScourgeStrike"),
    BloodStrike       = define("BloodStrike",       { 49930, 45902, 49926, 49927, 49928, 49929 }, "BloodStrike"),
    DeathCoil         = define("DeathCoil",         { 49895, 47541, 49892, 49893, 49894 }, "DeathCoil"),
    Pestilence        = define("Pestilence",        { 50842 }, "Pestilence"),
    DeathAndDecay     = define("DeathAndDecay",     { 49938, 43265, 49936, 49937 }, "DeathAndDecay"),
    SummonGargoyle    = define("SummonGargoyle",    49206, "SummonGargoyle"),
    HornOfWinter      = define("HornOfWinter",      { 57623, 57330 }, "HornOfWinter"),
    EmpowerRuneWeapon = define("EmpowerRuneWeapon", 47568, "EmpowerRuneWeapon"),
    BoneShield        = define("BoneShield",        49222, "BoneShield"),
    RaiseDead         = define("RaiseDead",         46584, "RaiseDead"),
    BloodPresence     = define("BloodPresence",     48266, "BloodPresence"),
    FrostPresence     = define("FrostPresence",     48263, "FrostPresence"),
    UnholyPresence    = define("UnholyPresence",    48265, "UnholyPresence"),
    -- Ghoul pet commands (wowhead WotLK Classic spell=47481 / =47482):
    -- Gnaw = 3s stun (1 min CD, 30 energy); Leap = gap close (20s CD).
    GhoulGnaw         = define("GhoulGnaw",         47481, "GhoulGnaw"),
    GhoulLeap         = define("GhoulLeap",         47482, "GhoulLeap"),
}

local FROST_FEVER         = { 55095 }
local BLOOD_PLAGUE        = { 55078 }
local HORN_OF_WINTER_BUFF = { 57623, 57330 }
local BONE_SHIELD_BUFF    = { 49222 }

local unholy_state = {
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

-- Static 2s-TTL rune snapshot (read-only for strategies). build_state must not
-- allocate a fresh table every frame; the OLD code did (12 pcalls + 2 allocs
-- per frame via get_rune_state() + table literal). rune_ready is only read by
-- the EmpowerRuneWeapon strategy, so a 2s cache is imperceptible in play.
local _rune_snapshot = { blood = 0, frost = 0, unholy = 0, death = 0 }
local _rune_snapshot_time = -1
local function get_rune_snapshot()
    local now = NS.time_now and NS.time_now() or 0
    if now - _rune_snapshot_time < 2 then return _rune_snapshot end
    _rune_snapshot_time = now
    local runes = rune_manager and rune_manager.get_rune_state and rune_manager.get_rune_state()
    local ready = (runes and runes.ready) or {}
    _rune_snapshot.blood = ready.blood or 0
    _rune_snapshot.frost = ready.frost or 0
    _rune_snapshot.unholy = ready.unholy or 0
    _rune_snapshot.death = ready.death or 0
    return _rune_snapshot
end

local function build_state(context)
    local state = spec_kit.safe_state(unholy_state)
    local target = context and context.target
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())

    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false

    state.frost_fever_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FROST_FEVER)) or 0
    state.blood_plague_remains = (target and NS.debuff_remains and NS.debuff_remains(target, BLOOD_PLAGUE)) or 0

    state.horn_of_winter_up = (me and NS.buff_up and NS.buff_up(me, HORN_OF_WINTER_BUFF)) or false
    state.bone_shield_up = (me and NS.buff_up and NS.buff_up(me, BONE_SHIELD_BUFF)) or false

    -- Current presence id feeds presence_manager.should_switch_presence
    -- (it falls back to PRESENCE.BLOOD when unset — without this the auto
    -- lane would recast Unholy Presence every tick).
    state.presence = presence_manager and presence_manager.current_presence_id(me) or nil

    state.runic_power = 0
    if me and rune_manager then
        state.runic_power = rune_manager.get_runic_power(me) or 0
    end

    -- Rune snapshot: ONE get_rune_state() call, cached with a 2s TTL (the old
    -- code rebuilt a fresh {blood=0,...} table + get_rune_state() every frame:
    -- 12 pcalls + 2 allocs). Only EmpowerRuneWeapon reads rune_ready. The
    -- static snapshot table is READ-ONLY for strategies (never mutated).
    state.rune_ready = get_rune_snapshot()

    state.pet_present = false
    if NS.has_pet then
        local ok, has = pcall(NS.has_pet)
        if ok then state.pet_present = has or false end
    end

    -- Boss flag: the dispatcher sets context.target_is_boss (main_sylvanas.lua
    -- :1287); the old context.is_boss read was a phantom field and made
    -- SummonGargoyle a production never-lane. Fall back to NS.unit_is_boss on
    -- the target; the legacy context.is_boss compat read was DELETED (W3.5):
    -- no production writer ever sets it (main_sylvanas writes target_is_boss;
    -- the battery drives target_is_boss), mirroring arms_wotlk.lua:143.
    state.is_boss = (context and context.target_is_boss == true)
        or (target and NS.unit_is_boss and NS.unit_is_boss(target) == true)
        or false

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
            -- ERW is a 5-minute CD (class_sylvanas.lua cooldown 300) — same
            -- forecast gate frost uses.
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 300) then return false end
                return true
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
    {
        -- Ghoul command lanes (pet-control rubric close-out): Gnaw is a 3s
        -- stun (1 min CD) — cast it on a casting target to interrupt hard
        -- casts. context.target_casting is the REAL dispatcher field
        -- (main_sylvanas.lua:759). Casts via NS.try_cast (DSL cast handler).
        name = "GhoulGnaw",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "pet_present", op = "truthy" },
            { type = "custom", fn = function(context, state)
                return (context and context.target_casting) == true
            end },
        },
        action = { type = "cast", spell = ACTION.GhoulGnaw, target = "target" },
    },
    {
        -- Ghoul Leap (20s CD) gap closer: cast when the target is out of
        -- melee range (context.target_distance is the real dispatcher field,
        -- main_sylvanas.lua:877).
        name = "GhoulLeap",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "pet_present", op = "truthy" },
            { type = "custom", fn = function(context, state)
                return (context and context.target_distance or 0) >= 8
            end },
        },
        action = { type = "cast", spell = ACTION.GhoulLeap, target = "target" },
    },
}

-- ---------------------------------------------------------------------------
-- Presence execute helper
-- ---------------------------------------------------------------------------

local function presence_execute(ctx, state)
    if not presence_manager then return false end
    local desired = presence_manager.get_optimal_presence(ctx, state or {})
    if not desired then return false end
    local action = nil
    if desired == "blood" then action = ACTION.BloodPresence
    elseif desired == "frost" then action = ACTION.FrostPresence
    elseif desired == "unholy" then action = ACTION.UnholyPresence end
    if not action then return false end
    local me = (ctx and ctx.me) or (NS.GetPlayer and NS.GetPlayer())
    if not me then return false end
    -- REAL cast path: action:cast_safe() exists only on izi.spell() objects
    -- (core_sylvanas.lua:2165-2166); the old `if action and action.cast_safe`
    -- silently no-oped on production NS.spell_action tables, so unholy never
    -- entered Unholy Presence. NS.try_cast is the production entrypoint.
    return NS.try_cast and NS.try_cast(action, me, "Presence") == true or false
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
-- Pet command lanes appended AFTER DeathCoilDump (pin-safe: unholy is pinned
-- only for the 4 resolved strategies PlagueStrike < ScourgeStrike <
-- BloodStrike(occ2) < DeathCoilDump; conditions/actions are free).
strategies[#strategies + 1] = { name = "GhoulGnaw" }
strategies[#strategies + 1] = { name = "GhoulLeap" }

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
