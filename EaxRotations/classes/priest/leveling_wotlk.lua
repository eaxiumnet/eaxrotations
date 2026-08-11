-- leveling_wotlk.lua — Priest leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for priest leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple shadow/holy damage rotation with emergency heal.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.PriestSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    PowerWordFortitude = define("PowerWordFortitude", { 48161, 25389, 10938, 10937, 2791, 1245, 1244, 1243 }, "PowerWordFortitude"),
    InnerFire = define("InnerFire", { 48168, 48040, 25431, 10952, 10951, 7128, 1006, 602, 588 }, "InnerFire"),
    PowerWordShield = define("PowerWordShield", { 48066, 48065, 25218, 25217, 10901, 10900, 600, 592, 548, 17 }, "PowerWordShield"),
    Shadowform = define("Shadowform", 15473, "Shadowform"),
    ShadowWordPain = define("ShadowWordPain", { 48125, 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }, "ShadowWordPain"),
    MindBlast = define("MindBlast", { 48127, 25375, 25372, 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092 }, "MindBlast"),
    MindFlay = define("MindFlay", { 48156, 25387, 18807, 17314, 17313, 17312, 17311, 15407 }, "MindFlay"),
    Smite = define("Smite", { 48123, 25364, 25363, 10934, 10933, 6060, 1004, 984, 598, 591, 585 }, "Smite"),
    Penance = define("Penance", 47540, "Penance"),
    FlashHeal = define("FlashHeal", { 48071, 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }, "FlashHeal"),
    Shoot = define("Shoot", 5019, "Shoot"),
}

local SHADOW_WORD_PAIN_DEBUFF = { 48125, 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local POWER_WORD_FORTITUDE_BUFF = { 48161, 25389, 10938, 10937, 2791, 1245, 1244, 1243 }
local INNER_FIRE_BUFF = { 48168, 48040, 25431, 10952, 10951, 7128, 1006, 602, 588 }
local POWER_WORD_SHIELD_BUFF = { 48066, 48065, 25218, 25217, 10901, 10900, 600, 592, 548, 17 }
local SHADOWFORM_BUFF = { 15473 }
local WEAKENED_SOUL_DEBUFF = { 6788 }

local priest_state = {
    hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    swp_remains = 0,
    fortitude_up = false,
    inner_fire_up = false,
    shadowform_up = false,
    pws_up = false,
    weakened_soul = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(priest_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.swp_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SHADOW_WORD_PAIN_DEBUFF)) or 0
    state.fortitude_up = (me and NS.buff_up and NS.buff_up(me, POWER_WORD_FORTITUDE_BUFF)) or false
    state.inner_fire_up = (me and NS.buff_up and NS.buff_up(me, INNER_FIRE_BUFF)) or false
    state.shadowform_up = (me and NS.buff_up and NS.buff_up(me, SHADOWFORM_BUFF)) or false
    state.pws_up = (me and NS.buff_up and NS.buff_up(me, POWER_WORD_SHIELD_BUFF)) or false
    state.weakened_soul = (me and NS.debuff_up and NS.debuff_up(me, WEAKENED_SOUL_DEBUFF)) or false
    state.use_shadowform = spec_kit.setting_bool and spec_kit.setting_bool(context, "eaxpriestlvl_use_shadowform", false) or false
    return state
end

local DSL_DEFS = {
    {
        name = "PowerWordFortitude",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "fortitude_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.PowerWordFortitude, target = "self" },
    },
    {
        name = "InnerFire",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "inner_fire_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.InnerFire, target = "self" },
    },
    -- Opt-in: Shadowform blocks holy spells (heals), so gate behind a setting.
    {
        name = "Shadowform",
        conditions = {
            { type = "state", field = "use_shadowform", op = "truthy" },
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "shadowform_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.Shadowform, target = "self" },
    },
    -- Proactive absorb; never re-cast into the Weakened Soul lockout.
    {
        name = "PowerWordShield",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "pws_up", op = "falsy" },
            { type = "state", field = "weakened_soul", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.PowerWordShield, target = "self" },
    },
    {
        name = "FlashHeal",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 50 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.FlashHeal, target = "self" },
    },
    {
        name = "ShadowWordPain",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "swp_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.ShadowWordPain, target = "target" },
    },
    {
        name = "Penance",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Penance, target = "target" },
    },
    {
        name = "MindBlast",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.MindBlast, target = "target" },
    },
    {
        name = "MindFlay",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.MindFlay, target = "target" },
    },
    {
        name = "Smite",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Smite, target = "target" },
    },
    -- OOM fallback: fire the wand when too low on mana to cast a real nuke.
    {
        name = "Shoot",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Shoot, target = "target" },
    },
}

local strategies = {
    { name = "PowerWordFortitude" },
    { name = "InnerFire" },
    { name = "Shadowform" },
    { name = "PowerWordShield" },
    { name = "FlashHeal" },
    { name = "ShadowWordPain" },
    { name = "Penance" },
    { name = "MindBlast" },
    { name = "MindFlay" },
    { name = "Smite" },
    { name = "Shoot" },
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
if NS.log then NS.log("Priest leveling rotation registered") end

return { strategies = strategies, build_state = build_state }
