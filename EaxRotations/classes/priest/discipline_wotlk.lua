-- discipline_wotlk.lua — Priest Discipline rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Discipline priest.
-- WHEN:  combat with valid enemy target / friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PriestSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    PowerWordShield = define("PowerWordShield", { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }, "PowerWordShield"),
    Penance = define("Penance", 47540, "Penance"),
    PrayerOfMending = define("PrayerofMending", 33076, "PrayerofMending"),
    Renew = define("Renew", { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }, "Renew"),
}

local WEAKENED_SOUL_DEBUFF = { 6788 }
local RENEW_BUFF = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }

local discipline_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    weakened_soul_up = false,
    renew_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(discipline_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.weakened_soul_up = (target and NS.debuff_up and NS.debuff_up(target, WEAKENED_SOUL_DEBUFF)) or false
    state.renew_remains = (target and NS.buff_remains and NS.buff_remains(target, RENEW_BUFF)) or 0
    return state
end

local function power_word_shield_matches(context, state)
    return not state.weakened_soul_up
end

local function penance_matches(context, state)
    return true
end

local function prayer_of_mending_matches(context, state)
    return true
end

local function renew_matches(context, state)
    return state.renew_remains < 3
end

local strategies = {
    { name = "PowerWordShield", matches = power_word_shield_matches, execute = function(ctx) return ACTION.PowerWordShield and ACTION.PowerWordShield:cast_safe(ctx.target) end },
    { name = "Penance", matches = penance_matches, execute = function(ctx) return ACTION.Penance and ACTION.Penance:cast_safe(ctx.target) end },
    { name = "PrayerOfMending", matches = prayer_of_mending_matches, execute = function(ctx) return ACTION.PrayerOfMending and ACTION.PrayerOfMending:cast_safe(ctx.target) end },
    { name = "Renew", matches = renew_matches, execute = function(ctx) return ACTION.Renew and ACTION.Renew:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("discipline", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
