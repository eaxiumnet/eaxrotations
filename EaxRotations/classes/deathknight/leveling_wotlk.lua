-- leveling_wotlk.lua — Death Knight leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for death knight leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple disease-first rotation using core leveling abilities.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local helpers = require("shared/leveling_helpers_sylvanas")
local SPELLS = NS.DeathKnightSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    IcyTouch = define("IcyTouch", { 49909, 49802, 49903, 49904, 49905, 49906 }, "IcyTouch"),
    PlagueStrike = define("PlagueStrike", { 49921, 49917, 49918, 49919, 49920 }, "PlagueStrike"),
    -- Blood Strike ranks (lexxer): 45902 r1 … 49930 max. Removed invalid 49932/49931.
    BloodStrike = define("BloodStrike", { 49930, 49929, 49928, 49927, 49926, 45902 }, "BloodStrike"),
    DeathStrike = define("DeathStrike", { 49999, 49998, 45463, 49924 }, "DeathStrike"),
    HeartStrike = define("HeartStrike", { 55262, 55050, 55258, 55259, 55260, 55261 }, "HeartStrike"),
    Obliterate = define("Obliterate", { 51425, 49020, 51423, 51424 }, "Obliterate"),
    HowlingBlast = define("HowlingBlast", { 51411, 49184, 51209, 51210, 51211, 51212, 51409, 51410 }, "HowlingBlast"),
    ScourgeStrike = define("ScourgeStrike", { 55271, 55090, 55265, 55270 }, "ScourgeStrike"),
    DeathCoil = define("DeathCoil", { 49895, 47541, 49892, 49893, 49894 }, "DeathCoil"),
    HornOfWinter = define("HornOfWinter", { 57623, 57330 }, "HornOfWinter"),
    MindFreeze = define("MindFreeze", 47528, "MindFreeze"),
    BloodPresence = define("BloodPresence", 48266, "BloodPresence"),
    -- AoE + runic-power dump (verified vs class_sylvanas.lua rank lists).
    Pestilence = define("Pestilence", { 50842 }, "Pestilence"),
    DeathAndDecay = define("DeathAndDecay", { 49938, 43265, 49936, 49937 }, "DeathAndDecay"),
    BloodBoil = define("BloodBoil", { 49941, 48721, 49939, 49940 }, "BloodBoil"),
    RuneStrike = define("RuneStrike", { 56815 }, "RuneStrike"),
    EmpowerRuneWeapon = define("EmpowerRuneWeapon", 47568, "EmpowerRuneWeapon"),
}

-- DK diseases are single aura IDs (lexxer wotlk). Removed fake "ranks" 55096-55100 / 55079-55083.
local FROST_FEVER = { 55095 }
local BLOOD_PLAGUE = { 55078 }
local HORN_OF_WINTER_BUFF = { 57623, 57330 }
local BLOOD_PRESENCE_BUFF = { 48266 }

local dk_state = {
    hp = 100,
    target_hp = 100,
    runic_power = 0,
    enemy_count = 1,
    in_combat = false,
    frost_fever_remains = 0,
    blood_plague_remains = 0,
    diseases_up = false,
    horn_of_winter_up = false,
    target_casting = false,
    blood_presence_up = false,
    empower_rune_weapon_ready = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(dk_state)
    local target = context and context.target
    state.hp = (NS.me and NS.me.get_health_percentage and NS.me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.runic_power = (NS.me and NS.me.get_runic_power and NS.me:get_runic_power()) or 0
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.frost_fever_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FROST_FEVER)) or 0
    state.blood_plague_remains = (target and NS.debuff_remains and NS.debuff_remains(target, BLOOD_PLAGUE)) or 0
    state.diseases_up = (state.frost_fever_remains > 0) or (state.blood_plague_remains > 0)
    state.horn_of_winter_up = (NS.me and NS.buff_up and NS.buff_up(NS.me, HORN_OF_WINTER_BUFF)) or false
    state.target_casting = helpers.should_interrupt(target)
    state.blood_presence_up = (NS.me and NS.buff_up and NS.buff_up(NS.me, BLOOD_PRESENCE_BUFF)) or false
    state.empower_rune_weapon_ready = (ACTION.EmpowerRuneWeapon and ACTION.EmpowerRuneWeapon.cooldown_remaining
        and ACTION.EmpowerRuneWeapon:cooldown_remaining() <= 0) or false
    return state
end

local DSL_DEFS = {
    {
        name = "MindFreeze",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_casting", op = "==", value = true },
        },
        action = { type = "cast", spell = ACTION.MindFreeze, target = "target" },
    },
    {
        name = "BloodPresence",
        conditions = {
            { type = "state", field = "blood_presence_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.BloodPresence, target = "self" },
    },
    {
        name = "HornOfWinter",
        conditions = {
            { type = "state", field = "horn_of_winter_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.HornOfWinter, target = "self" },
    },
    {
        name = "IcyTouch",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "frost_fever_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.IcyTouch, target = "target" },
    },
    {
        name = "PlagueStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "blood_plague_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.PlagueStrike, target = "target" },
    },
    {
        name = "Pestilence",
        -- Spread existing diseases to nearby targets when fighting a pack.
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "diseases_up", op = "==", value = true },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_target_meets then return false end
                local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_10) or 10
                return NS.aoe_target_meets(2, r, context and context.target, context) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.Pestilence, target = "target" },
    },
    {
        name = "DeathAndDecay",
        -- Ground-target AoE for larger packs (~10yd Community/WotLK).
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_target_meets then return false end
                local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_10) or 10
                return NS.aoe_target_meets(3, r, context and context.target, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.DeathAndDecay, target = "target" },
    },
    {
        name = "BloodBoil",
        -- Instant AoE that also detonates diseases; good for 2+ targets (~10yd self).
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_self_meets then return false end
                local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10
                return NS.aoe_self_meets(2, r, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.BloodBoil, target = "self" },
    },
    {
        name = "DeathStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 80 },
        },
        action = { type = "cast", spell = ACTION.DeathStrike, target = "target" },
    },
    {
        name = "Obliterate",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Obliterate, target = "target" },
    },
    {
        name = "ScourgeStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.ScourgeStrike, target = "target" },
    },
    {
        name = "HeartStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.HeartStrike, target = "target" },
    },
    {
        name = "HowlingBlast",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_target_meets then return false end
                local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_10) or 10
                return NS.aoe_target_meets(2, r, context and context.target, context) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.HowlingBlast, target = "target" },
    },
    {
        name = "BloodStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.BloodStrike, target = "target" },
    },
    {
        name = "RuneStrike",
        -- Runic-power dump that hits harder than Death Coil; fire before it.
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "runic_power", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.RuneStrike, target = "target" },
    },
    {
        name = "DeathCoil",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "runic_power", op = ">=", value = 40 },
        },
        action = { type = "cast", spell = ACTION.DeathCoil, target = "target" },
    },
    {
        name = "EmpowerRuneWeapon",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "empower_rune_weapon_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if not NS.should_use_long_cd then return true end
                return NS.should_use_long_cd(context, 120) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.EmpowerRuneWeapon, target = "self" },
    },
}

-- Placeholder priority order (compiled in place from DSL_DEFS below).
local strategies = {
    { name = "MindFreeze" },
    { name = "BloodPresence" },
    { name = "HornOfWinter" },
    { name = "IcyTouch" },
    { name = "PlagueStrike" },
    { name = "Pestilence" },
    { name = "DeathAndDecay" },
    { name = "BloodBoil" },
    { name = "DeathStrike" },
    { name = "Obliterate" },
    { name = "ScourgeStrike" },
    { name = "HeartStrike" },
    { name = "HowlingBlast" },
    { name = "BloodStrike" },
    { name = "RuneStrike" },
    { name = "DeathCoil" },
    { name = "EmpowerRuneWeapon" },
}

for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

if NS.log then NS.log("Death Knight leveling rotation registered") end

return { strategies = strategies, build_state = build_state }
