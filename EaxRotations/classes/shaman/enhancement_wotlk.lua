-- enhancement_wotlk.lua — Shaman Enhancement rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Enhancement shaman.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.ShamanSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Stormstrike = define("Stormstrike", 17364, "Stormstrike"),
    LavaLash = define("LavaLash", 60103, "LavaLash"),
    FeralSpirit = define("FeralSpirit", 51533, "FeralSpirit"),
    ShamanisticRage = define("ShamanisticRage", 30823, "ShamanisticRage"),
}

local MAELSTROM_WEAPON_BUFF = { 53817, 53816, 53815, 53814, 53813 }

local enhancement_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    maelstrom_stacks = 0,
    shamanistic_rage_ready = false,
    feral_spirit_ready = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(enhancement_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.maelstrom_stacks = (me and NS.buff_stacks and NS.buff_stacks(me, MAELSTROM_WEAPON_BUFF)) or 0
    state.shamanistic_rage_ready = (ACTION.ShamanisticRage and ACTION.ShamanisticRage.cooldown_remaining and ACTION.ShamanisticRage:cooldown_remaining() <= 0) or false
    state.feral_spirit_ready = (ACTION.FeralSpirit and ACTION.FeralSpirit.cooldown_remaining and ACTION.FeralSpirit:cooldown_remaining() <= 0) or false
    return state
end

local function shamanistic_rage_matches(context, state)
    if not state.in_combat then return false end
    if not state.shamanistic_rage_ready then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 60) then return false end
    return true
end

local function feral_spirit_matches(context, state)
    if not state.in_combat then return false end
    if not state.feral_spirit_ready then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    return true
end

local function stormstrike_matches(context, state)
    return true
end

local function lava_lash_matches(context, state)
    return true
end

local strategies = {
    { name = "ShamanisticRage", matches = shamanistic_rage_matches, execute = function(ctx) return ACTION.ShamanisticRage and ACTION.ShamanisticRage:cast_safe() end },
    { name = "FeralSpirit", matches = feral_spirit_matches, execute = function(ctx) return ACTION.FeralSpirit and ACTION.FeralSpirit:cast_safe(ctx.target) end },
    { name = "Stormstrike", matches = stormstrike_matches, execute = function(ctx) return ACTION.Stormstrike and ACTION.Stormstrike:cast_safe(ctx.target) end },
    { name = "LavaLash", matches = lava_lash_matches, execute = function(ctx) return ACTION.LavaLash and ACTION.LavaLash:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("enhancement", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
