-- fire_wotlk.lua — Mage Fire rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Fire mage.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.MageSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Pyroblast = define("Pyroblast", { 33938, 12526, 12525, 12524, 12523, 12522, 12521, 11366 }, "Pyroblast"),
    LivingBomb = define("LivingBomb", 44457, "LivingBomb"),
    Scorch = define("Scorch", { 30455, 2948, 8444, 8445, 8446, 8447, 10211, 10210, 27073, 27074 }, "Scorch"),
    -- Fireball ranks (lexxer see-also): removed invalid 725/33938.
    Fireball = define("Fireball", { 42833, 38692, 27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133 }, "Fireball"),
    Combustion = define("Combustion", 11129, "Combustion"),
}

local LIVING_BOMB_DEBUFF = { 44457, 44459, 44460, 44461 }
local SCORCH_DEBUFF = { 30455, 2948, 8444, 8445, 8446, 8447, 10211, 10210, 27073, 27074 }
local HOT_STREAK_BUFF = { 48108 }

local fire_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    living_bomb_remains = 0,
    scorch_remains = 0,
    hot_streak_proc = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(fire_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.living_bomb_remains = (target and NS.debuff_remains and NS.debuff_remains(target, LIVING_BOMB_DEBUFF)) or 0
    state.scorch_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SCORCH_DEBUFF)) or 0
    state.hot_streak_proc = (me and NS.buff_up and NS.buff_up(me, HOT_STREAK_BUFF)) or false
    return state
end

local function combustion_matches(context, state)
    if not state.in_combat then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    return true
end

local function pyroblast_matches(context, state)
    return state.hot_streak_proc
end

local function living_bomb_matches(context, state)
    return state.living_bomb_remains < 3
end

local function scorch_matches(context, state)
    return state.scorch_remains < 3 and state.mana_pct >= 15
end

local function fireball_matches(context, state)
    return state.mana_pct >= 20
end

local strategies = {
    { name = "Combustion", matches = combustion_matches, execute = function(ctx) return ACTION.Combustion and ACTION.Combustion:cast_safe() end },
    { name = "Pyroblast", matches = pyroblast_matches, execute = function(ctx) return ACTION.Pyroblast and ACTION.Pyroblast:cast_safe(ctx.target) end },
    { name = "LivingBomb", matches = living_bomb_matches, execute = function(ctx) return ACTION.LivingBomb and ACTION.LivingBomb:cast_safe(ctx.target) end },
    { name = "Scorch", matches = scorch_matches, execute = function(ctx) return ACTION.Scorch and ACTION.Scorch:cast_safe(ctx.target) end },
    { name = "Fireball", matches = fireball_matches, execute = function(ctx) return ACTION.Fireball and ACTION.Fireball:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("fire", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
