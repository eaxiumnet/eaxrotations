-- restoration_wotlk.lua — Shaman Restoration rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Restoration shaman: Mana Tide Totem
--        (NS.spell_ready, 5-min CD), charge-aware Earth Shield refresh
--        (NS.buff_points Pattern 12), Riptide / Chain Heal / Healing Wave /
--        Lesser Healing Wave on the lowest friendly target, and Water Shield
--        mana sustain. Tidal Waves stacks tracked (WotLK resto mechanic).
-- WHEN:  combat with a valid friendly target (resolve_target -> context.lowest).
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")

local define = spec_kit.define_action

local ACTION = {
    ManaTideTotem = define("ManaTideTotem", 16190, "ManaTideTotem"),
    EarthShield = define("EarthShield", 49284, "EarthShield"),
    Riptide = define("Riptide", 61301, "Riptide"),
    ChainHeal = define("ChainHeal", 55459, "ChainHeal"),
    HealingWave = define("HealingWave", 49273, "HealingWave"),
    LesserHealingWave = define("LesserHealingWave", 49276, "LesserHealingWave"),
    WaterShield = define("WaterShield", 52127, "WaterShield"),
}

local RIPTIDE_BUFF = { 61301, 61300, 61299, 61295 }
local EARTH_SHIELD_BUFF = { 49284, 32594, 32593, 974 }
-- Single WotLK max rank only: the TBC-era lower ranks (33736/24398/23575) are
-- not bridge-known and would fail the WotLK ID audit; a level-80 resto never
-- sees them.
local WATER_SHIELD_BUFF = { 52127 }
local TIDAL_WAVES_BUFF = { 53390 }

local restoration_state = {
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    riptide_remains = 0,
    earth_shield_up = false,
    earth_shield_charges = 0,
    mana_tide_ready = false,
    party_injured_count = 0,
    lowest_hp = 100,
    water_shield_up = false,
    water_shield_ready = false,
    tidal_waves_stacks = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(restoration_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    -- Heals target the lowest-HP friendly (DSL target="friendly" resolves to
    -- context.lowest.unit); the old code healed context.target, which can be
    -- an enemy.
    local friendly = context and context.lowest and context.lowest.unit
    local ft_hp = 100
    if friendly and friendly.get_health_percentage then
        local ok, v = pcall(friendly.get_health_percentage, friendly)
        if ok and type(v) == "number" then ft_hp = v end
    elseif context and context.lowest_hp then
        ft_hp = context.lowest_hp
    end
    state.target_hp = ft_hp
    state.lowest_hp = (context and context.lowest_hp) or ft_hp
    state.mana_pct = (context and context.mana_pct) or (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.riptide_remains = (friendly and NS.buff_remains and NS.buff_remains(friendly, RIPTIDE_BUFF)) or 0
    -- Earth Shield charge-aware refresh (Pattern 12): points[1] = charges left.
    local es_pts = friendly and NS.buff_points and NS.buff_points(friendly, EARTH_SHIELD_BUFF) or nil
    state.earth_shield_charges = (es_pts and es_pts[1]) or 0
    state.earth_shield_up = (friendly and NS.buff_up and NS.buff_up(friendly, EARTH_SHIELD_BUFF)) or false
    -- Mana Tide from the REAL cooldown API (production never sets the phantom
    -- context.mana_tide_ready flag the old build_state read).
    state.mana_tide_ready = (NS.spell_ready and NS.spell_ready(ACTION.ManaTideTotem, me, { skip_range = true, expected_cooldown = 300 })) or false
    -- Engine field name: main_sylvanas.lua provides context.party_injured_count
    -- (not the phantom context.injured_count the old code read — Chain Heal
    -- could never fire).
    state.party_injured_count = (context and context.party_injured_count) or 0
    state.water_shield_up = (me and NS.buff_up and NS.buff_up(me, WATER_SHIELD_BUFF)) or false
    state.water_shield_ready = (NS.spell_ready and NS.spell_ready(ACTION.WaterShield, me, { skip_range = true })) or false
    state.tidal_waves_stacks = (me and NS.buff_stacks and NS.buff_stacks(me, TIDAL_WAVES_BUFF)) or 0
    return state
end

local DSL_DEFS = {
    {
        name = "ManaTideTotem",
        conditions = {
            { type = "state", field = "mana_tide_ready", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 30 },
        },
        action = { type = "cast", spell = ACTION.ManaTideTotem, target = "self" },
    },
    {
        name = "EarthShield",
        conditions = {
            { type = "custom", fn = function(context, state)
                if not state.earth_shield_up then return true end
                local charges = state.earth_shield_charges or 0
                -- Refresh only when the shield is low on charges; fail closed
                -- (hold) when charges cannot be read.
                return charges > 0 and charges <= 1
            end },
        },
        action = { type = "cast", spell = ACTION.EarthShield, target = "friendly" },
    },
    {
        name = "Riptide",
        conditions = {
            { type = "state", field = "riptide_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Riptide, target = "friendly" },
    },
    {
        name = "ChainHeal",
        conditions = {
            { type = "state", field = "party_injured_count", op = ">=", value = 2 },
            { type = "state", field = "lowest_hp", op = "<", value = 85 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.ChainHeal, target = "friendly" },
    },
    {
        name = "LesserHealingWave",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 90 },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.LesserHealingWave, target = "friendly" },
    },
    {
        name = "HealingWave",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 70 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.HealingWave, target = "friendly" },
    },
    -- Water Shield mana sustain (WotLK resto mechanic): re-apply at low mana
    -- when the shield is down.
    {
        name = "WaterShield",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "water_shield_up", op = "falsy" },
            { type = "state", field = "mana_pct", op = "<", value = 50 },
            { type = "state", field = "water_shield_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.WaterShield, target = "self" },
    },
}

local strategies = {
    { name = "ManaTideTotem" },
    { name = "EarthShield" },
    { name = "Riptide" },
    { name = "ChainHeal" },
    { name = "HealingWave" },
    { name = "LesserHealingWave" },
    { name = "WaterShield" },
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
    NS.rotation_registry:register("restoration", strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman restoration rotation registered") end

return { strategies = strategies, build_state = build_state }
