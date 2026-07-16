-- leveling_wotlk.lua — Priest leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for priest leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple shadow/holy damage rotation with emergency heal.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PriestSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    PowerWordFortitude = define("PowerWordFortitude", { 48161, 25389, 10938, 10937, 2791, 1245, 1244, 1243 }, "PowerWordFortitude"),
    InnerFire = define("InnerFire", { 48168, 48040, 25431, 10952, 10951, 7128, 1006, 602, 588 }, "InnerFire"),
    PowerWordShield = define("PowerWordShield", { 48066, 48065, 25218, 25217, 10901, 10900, 600, 592, 548, 17 }, "PowerWordShield"),
    Shadowform = define("Shadowform", 15473, "Shadowform"),
    ShadowWordPain = define("ShadowWordPain", { 48125, 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }, "ShadowWordPain"),
    MindBlast = define("MindBlast", { 25375, 25372, 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092 }, "MindBlast"),
    MindFlay = define("MindFlay", { 25387, 18807, 17314, 17313, 17312, 17311, 15407 }, "MindFlay"),
    Smite = define("Smite", { 25364, 25363, 10934, 10933, 6060, 1004, 984, 598, 591, 585 }, "Smite"),
    Penance = define("Penance", 47540, "Penance"),
    FlashHeal = define("FlashHeal", { 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }, "FlashHeal"),
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
    target_hp = 100,
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
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
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

local function flash_heal_matches(context, state)
    return state.in_combat and state.hp < 50 and state.mana_pct >= 25
end

local function power_word_fortitude_matches(context, state)
    return not state.in_combat and not state.fortitude_up and state.mana_pct >= 10
end

local function inner_fire_matches(context, state)
    return not state.in_combat and not state.inner_fire_up and state.mana_pct >= 10
end

local function shadowform_matches(context, state)
    -- Opt-in: Shadowform blocks holy spells (heals), so gate behind a setting.
    return state.use_shadowform == true and not state.in_combat and not state.shadowform_up
end

local function power_word_shield_matches(context, state)
    -- Proactive absorb; never re-cast into the Weakened Soul lockout.
    return state.in_combat and not state.pws_up and not state.weakened_soul and state.mana_pct >= 15
end

local function shadow_word_pain_matches(context, state)
    return state.in_combat and state.swp_remains < 3 and state.mana_pct >= 15
end

local function penance_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function mind_blast_matches(context, state)
    return state.in_combat and state.mana_pct >= 20
end

local function mind_flay_matches(context, state)
    return state.in_combat and state.mana_pct >= 20
end

local function smite_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function shoot_wand_matches(context, state)
    -- OOM fallback: fire the wand when too low on mana to cast a real nuke.
    return state.in_combat and state.mana_pct < 10
end

local strategies = {
    { name = "PowerWordFortitude", matches = power_word_fortitude_matches, execute = function(ctx) return ACTION.PowerWordFortitude and ACTION.PowerWordFortitude:cast_safe() end },
    { name = "InnerFire", matches = inner_fire_matches, execute = function(ctx) return ACTION.InnerFire and ACTION.InnerFire:cast_safe() end },
    { name = "Shadowform", matches = shadowform_matches, execute = function(ctx) return ACTION.Shadowform and ACTION.Shadowform:cast_safe() end },
    { name = "PowerWordShield", matches = power_word_shield_matches, execute = function(ctx) return ACTION.PowerWordShield and ACTION.PowerWordShield:cast_safe() end },
    { name = "FlashHeal", matches = flash_heal_matches, execute = function(ctx) return ACTION.FlashHeal and ACTION.FlashHeal:cast_safe() end },
    { name = "ShadowWordPain", matches = shadow_word_pain_matches, execute = function(ctx) return ACTION.ShadowWordPain and ACTION.ShadowWordPain:cast_safe(ctx.target) end },
    { name = "Penance", matches = penance_matches, execute = function(ctx) return ACTION.Penance and ACTION.Penance:cast_safe(ctx.target) end },
    { name = "MindBlast", matches = mind_blast_matches, execute = function(ctx) return ACTION.MindBlast and ACTION.MindBlast:cast_safe(ctx.target) end },
    { name = "MindFlay", matches = mind_flay_matches, execute = function(ctx) return ACTION.MindFlay and ACTION.MindFlay:cast_safe(ctx.target) end },
    { name = "Smite", matches = smite_matches, execute = function(ctx) return ACTION.Smite and ACTION.Smite:cast_safe(ctx.target) end },
    { name = "Shoot", matches = shoot_wand_matches, execute = function(ctx) return ACTION.Shoot and ACTION.Shoot:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
