-- holy_wotlk.lua — Priest Holy rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Holy priest.
-- WHEN:  combat with valid friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.
-- DECISION (W3.3): plain spec_kit.define_action with file-local WotLK rank
--         ladders (define_action_for_class resolves through the TBC-capped
--         class table — precedent classes/mage/fire_wotlk.lua:20). PoM is a
--         3-rank WotLK trainer ladder (max 48113 per the pinned holy APL), so
--         the old single 33076 could never fire at 80. CircleOfHealing sits
--         exactly where the pinned holy APL evaluates it (GreaterHeal ->
--         CircleOfHealing -> Renew -> PrayerOfMending) and gates on the engine
--         context.party_injured_count (2+ injured) — the parse-critical raid
--         heal the file previously lacked.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")

local define = spec_kit.define_action

local ACTION = {
    Renew = define("Renew", { 48068, 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }, "Renew"),
    -- WotLK Prayer of Mending: 33076 r1 -> 48112 r2 -> 48113 r3 (max).
    PrayerOfMending = define("PrayerofMending", { 48113, 48112, 33076 }, "PrayerofMending"),
    FlashHeal = define("FlashHeal", { 48071, 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }, "FlashHeal"),
    GreaterHeal = define("GreaterHeal", { 48063, 25213, 25210, 25314, 10965, 10964, 10963, 2060 }, "GreaterHeal"),
    GuardianSpirit = define("GuardianSpirit", 47788, "GuardianSpirit"),
    -- Circle of Healing: full WotLK trainer ladder 34861 r1 .. 34866 r6 (TBC
    -- era, bridge-omitted, audit-pinned) -> 48088 r7 -> 48089 r8 max (pinned
    -- via the holy APL fixture id 48089).
    CircleOfHealing = define("CircleofHealing", { 48089, 48088, 34866, 34865, 34864, 34863, 34862, 34861 }, "CircleofHealing"),
}

local RENEW_BUFF = { 48068, 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local GUARDIAN_SPIRIT_BUFF = { 47788 }

local holy_state = {
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    renew_remains = 0,
    guardian_spirit_up = false,
    injured_count = 0,
    lowest_hp = 100,
}

local function build_state(context)
    local state = spec_kit.safe_state(holy_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = (context and context.lowest and context.lowest.unit) or me
    state.mana_pct = (context and context.mana_pct)
        or (me and NS.mana_pct and NS.mana_pct(me))
        or (me and me.get_mana_percentage and me:get_mana_percentage())
        or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.renew_remains = (target and NS.buff_remains and NS.buff_remains(target, RENEW_BUFF)) or 0
    state.guardian_spirit_up = (target and NS.buff_up and NS.buff_up(target, GUARDIAN_SPIRIT_BUFF)) or false
    -- Engine field (main_sylvanas.lua): number of party members below the
    -- injured threshold. nil-safe default 0 keeps the CoH lane inert solo.
    state.injured_count = (context and context.party_injured_count) or 0
    state.lowest_hp = (context and context.lowest_hp) or state.target_hp
    return state
end

-- Order note (2026-08-10): GreaterHeal sits ABOVE Renew/PrayerOfMending to match
-- the wowsims healing-priest APL evaluation order (ui/healing_priest/apls/holy.apl.json:
-- GreaterHeal -> CircleOfHealing -> Renew -> PrayerOfMending). The prior order had
-- Renew/PoM above GreaterHeal — a genuine divergence from the sim, fixed as a pure
-- order move (no matcher-logic change) when the healer pins were wired. GuardianSpirit
-- stays the emergency top; FlashHeal is our extra below (both absent from the sim APL).
-- W3.3: CircleOfHealing added at its exact APL position (index 3, GreaterHeal ->
-- CoH -> Renew -> PoM) gated on 2+ injured party members (engine
-- context.party_injured_count) — the previously-missing parse-critical raid heal.
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
        name = "CircleOfHealing",
        conditions = {
            { type = "state", field = "injured_count", op = ">=", value = 2 },
            { type = "state", field = "lowest_hp", op = "<", value = 85 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.CircleOfHealing, target = "friendly" },
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
    { name = "CircleOfHealing" },
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
