-- discipline_wotlk.lua — Priest Discipline rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Discipline priest.
-- WHEN:  combat with valid enemy target / friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.
-- DECISION (W3.3): plain spec_kit.define_action with file-local WotLK rank
--         ladders — define_action_for_class would resolve through the TBC-capped
--         class table and silently shadow the WotLK max ranks (precedent:
--         classes/mage/fire_wotlk.lua:20). Penance/PoM are multi-rank trainer
--         ladders (max 53007 / 48113) so a single TBC-era ID can never resolve
--         at level 80; WotLK max-rank buff ids (48068/48065) are tracked for
--         literal aura matching.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")

local define = spec_kit.define_action

local ACTION = {
    PowerWordShield = define("PowerWordShield", { 48066, 48065, 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }, "PowerWordShield"),
    -- WotLK Penance is a 4-rank trainer ladder (47540 r1 -> 53005 r2 -> 53006
    -- r3 -> 53007 r4). First-known-wins resolution needs the full ladder: a
    -- single 47540 can never resolve for a max-level character (the trainer
    -- replaces lower ranks), which was the production never-lane this fixes.
    Penance = define("Penance", { 53007, 53006, 53005, 47540 }, "Penance"),
    -- WotLK Prayer of Mending: 33076 r1 -> 48112 r2 -> 48113 r3 (max). The
    -- pinned disc APL (tools/evidence/apl/disc_priest_wotlk.apl.json) casts
    -- 48113; a single 33076 is a TBC-era cap that never fires at 80.
    PrayerOfMending = define("PrayerofMending", { 48113, 48112, 33076 }, "PrayerofMending"),
    Renew = define("Renew", { 48068, 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }, "Renew"),
}

local WEAKENED_SOUL_DEBUFF = { 6788 }
local RENEW_BUFF = { 48068, 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }

local discipline_state = {
    target_hp = 100,
    enemy_count = 1,
    in_combat = false,
    weakened_soul_up = false,
    renew_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(discipline_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = (context and context.lowest and context.lowest.unit) or me
    -- target_hp: the LOWEST FRIENDLY unit's hp (healers score the lowest
    -- friendly as their target) — test-pinned in
    -- test_discipline_wotlk_dsl_priority.lua:160.
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.weakened_soul_up = (target and NS.debuff_up and NS.debuff_up(target, WEAKENED_SOUL_DEBUFF)) or false
    state.renew_remains = (target and NS.buff_remains and NS.buff_remains(target, RENEW_BUFF)) or 0
    return state
end

local DSL_DEFS = {
    {
        name = "PowerWordShield",
        conditions = {
            { type = "state", field = "weakened_soul_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.PowerWordShield, target = "friendly" },
    },
    {
        name = "Penance",
        conditions = {},
        action = { type = "cast", spell = ACTION.Penance, target = "friendly" },
    },
    {
        name = "PrayerOfMending",
        conditions = {},
        action = { type = "cast", spell = ACTION.PrayerOfMending, target = "friendly" },
    },
    {
        name = "Renew",
        conditions = {
            { type = "state", field = "renew_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Renew, target = "friendly" },
    },
}

local strategies = {
    { name = "PowerWordShield" },
    { name = "Penance" },
    { name = "PrayerOfMending" },
    { name = "Renew" },
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
    NS.rotation_registry:register("discipline", strategies, { get_state = build_state })
end
if NS.log then NS.log("Priest discipline rotation registered") end

return { strategies = strategies, build_state = build_state }
