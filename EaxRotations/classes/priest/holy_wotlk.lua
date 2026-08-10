-- holy_wotlk.lua — Priest Holy rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Holy priest.
-- WHEN:  combat with valid friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.PriestSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Renew = define("Renew", { 48068, 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }, "Renew"),
    PrayerOfMending = define("PrayerofMending", 33076, "PrayerofMending"),
    FlashHeal = define("FlashHeal", { 48071, 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }, "FlashHeal"),
    GreaterHeal = define("GreaterHeal", { 48063, 25213, 25210, 25314, 10965, 10964, 10963, 2060 }, "GreaterHeal"),
    GuardianSpirit = define("GuardianSpirit", 47788, "GuardianSpirit"),
}

local RENEW_BUFF = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local GUARDIAN_SPIRIT_BUFF = { 47788 }

local holy_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    renew_remains = 0,
    guardian_spirit_up = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(holy_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = (context and context.lowest and context.lowest.unit) or me
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.renew_remains = (target and NS.buff_remains and NS.buff_remains(target, RENEW_BUFF)) or 0
    state.guardian_spirit_up = (target and NS.buff_up and NS.buff_up(target, GUARDIAN_SPIRIT_BUFF)) or false
    return state
end

-- Order note (2026-08-10): GreaterHeal sits ABOVE Renew/PrayerOfMending to match
-- the wowsims healing-priest APL evaluation order (ui/healing_priest/apls/holy.apl.json:
-- GreaterHeal -> CircleOfHealing -> Renew -> PrayerOfMending). The prior order had
-- Renew/PoM above GreaterHeal — a genuine divergence from the sim, fixed as a pure
-- order move (no matcher-logic change) when the healer pins were wired. GuardianSpirit
-- stays the emergency top; FlashHeal is our extra below (both absent from the sim APL).
local DSL_DEFS = {
    {
        name = "GuardianSpirit",
        conditions = {
            { type = "state", field = "guardian_spirit_up", op = "falsy" },
            { type = "state", field = "target_hp", op = "<", value = 30 },
        },
        action = { type = "cast", spell = ACTION.GuardianSpirit, target = "friendly" },
    },
    {
        name = "GreaterHeal",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 50 },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.GreaterHeal, target = "friendly" },
    },
    {
        name = "Renew",
        conditions = {
            { type = "state", field = "renew_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Renew, target = "friendly" },
    },
    {
        name = "PrayerOfMending",
        conditions = {},
        action = { type = "cast", spell = ACTION.PrayerOfMending, target = "friendly" },
    },
    {
        name = "FlashHeal",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 70 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.FlashHeal, target = "friendly" },
    },
}

local strategies = {
    { name = "GuardianSpirit" },
    { name = "GreaterHeal" },
    { name = "Renew" },
    { name = "PrayerOfMending" },
    { name = "FlashHeal" },
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
    NS.rotation_registry:register("holy", strategies, { get_state = build_state })
end
if NS.log then NS.log("Priest holy rotation registered") end

return { strategies = strategies, build_state = build_state }
