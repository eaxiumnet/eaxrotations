-- enhancement_wotlk.lua — Shaman Enhancement rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Enhancement shaman: Feral Spirit wolves,
--        Bloodlust / Shamanistic Rage CD windows (NS.spell_ready-computed),
--        Maelstrom Weapon Lightning Bolt, Stormstrike debuff, Lava Lash
--        off-hand, totem slot-occupancy maintenance (Magma Totem, Fire Nova
--        fire-slot gate, Call of the Elements re-drop), Lightning Shield, and
--        OOC weapon-imbue upkeep (Windfury Weapon + Flametongue Weapon).
-- WHEN:  combat with valid enemy target (imbue lanes fire out of combat).
-- WHY:   mirrors SimulationCraft / wowsims APL (default_wf variant = Windfury
--        Weapon upkeep) with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions
--         replace imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

local define = spec_kit.define_action

local ACTION = {
    FeralSpirit = define("FeralSpirit", 51533, "FeralSpirit"),
    Bloodlust = define("Bloodlust", 2825, "Bloodlust"),
    LightningBolt = define("LightningBolt", 49238, "LightningBolt"),
    Stormstrike = define("Stormstrike", 17364, "Stormstrike"),
    FlameShock = define("FlameShock", 49233, "FlameShock"),
    EarthShock = define("EarthShock", 49231, "EarthShock"),
    CallOfTheElements = define("CallOfTheElements", 66842, "CallOfTheElements"),
    MagmaTotem = define("MagmaTotem", 58734, "MagmaTotem"),
    FireNova = define("FireNova", 61657, "FireNova"),
    LightningShield = define("LightningShield", 49281, "LightningShield"),
    LavaLash = define("LavaLash", 60103, "LavaLash"),
    ShamanisticRage = define("ShamanisticRage", 30823, "ShamanisticRage"),
    WindfuryWeapon = define("WindfuryWeapon", 58804, "WindfuryWeapon"),
    FlametongueWeapon = define("FlametongueWeapon", 58790, "FlametongueWeapon"),
}

local MAELSTROM_WEAPON_BUFF = { 53817, 53816, 53815, 53814, 53813 }
local FLAME_SHOCK_DEBUFF = { 49233, 25457, 29228, 10448, 10447, 8053, 8052, 8050 }
local LIGHTNING_SHIELD_BUFF = { 49281, 49280, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
-- Totem slots (player:get_totem_info): 1 = fire, 2 = earth, 3 = water, 4 = air.
local FIRE_SLOT = 1
local WATER_SLOT = 3
-- Weapon imbues last 30 min; refresh window = 29.8 min (margin for GCD drift).
local WEAPON_BUFF_REFRESH_MS = 1790000

local runtime = {
    last_windfury_ms = -2 * WEAPON_BUFF_REFRESH_MS,
    last_flametongue_ms = -2 * WEAPON_BUFF_REFRESH_MS,
}

local enhancement_state = {
    enemy_count = 1,
    in_combat = false,
    mana_pct = 100,
    maelstrom_stacks = 0,
    feral_spirit_ready = false,
    bloodlust_ready = false,
    shamanistic_rage_ready = false,
    flame_shock_remains = 0,
    fire_slot_free = true,
    water_slot_free = true,
    lightning_shield_up = false,
    now_ms = 0,
    has_windfury = false,
    has_flametongue = false,
}

local function slot_free(slot)
    local info = NS.get_totem_info and NS.get_totem_info(slot) or nil
    return not (type(info) == "table" and info.have_totem == true)
end

local function build_state(context)
    local state = spec_kit.safe_state(enhancement_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.mana_pct = (context and context.mana_pct) or (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.maelstrom_stacks = (me and NS.buff_stacks and NS.buff_stacks(me, MAELSTROM_WEAPON_BUFF)) or 0
    -- CD windows from REAL cooldown API — the old build_state read
    -- ACTION.FeralSpirit:cooldown_remaining() (mock-only member, always nil in
    -- production) and phantom context flags; every CD lane was dead.
    state.feral_spirit_ready = (NS.spell_ready and NS.spell_ready(ACTION.FeralSpirit, me, { skip_range = true })) or false
    state.bloodlust_ready = (NS.spell_ready and NS.spell_ready(ACTION.Bloodlust, me, { skip_range = true })) or false
    state.shamanistic_rage_ready = (NS.spell_ready and NS.spell_ready(ACTION.ShamanisticRage, me, { skip_range = true, expected_cooldown = 120 })) or false
    state.flame_shock_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF)) or 0
    -- Totem slot occupancy: Call of the Elements re-drops when the water totem
    -- is gone (the old phantom water_totem_remains field was never set by the
    -- engine); Magma/Fire Nova gate on the fire slot.
    state.fire_slot_free = slot_free(FIRE_SLOT)
    state.water_slot_free = slot_free(WATER_SLOT)
    state.lightning_shield_up = (me and NS.buff_up and NS.buff_up(me, LIGHTNING_SHIELD_BUFF)) or false
    -- Weapon-imbue freshness (no player aura for imbues — time-windowed, same
    -- pattern as TBC elemental_sylvanas).
    state.now_ms = (NS.game_time_ms and NS.game_time_ms()) or 0
    state.has_windfury = (state.now_ms - runtime.last_windfury_ms) < WEAPON_BUFF_REFRESH_MS
    state.has_flametongue = (state.now_ms - runtime.last_flametongue_ms) < WEAPON_BUFF_REFRESH_MS
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "FeralSpirit",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "feral_spirit_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.FeralSpirit, target = "self" },
    },
    {
        name = "Bloodlust",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "bloodlust_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Bloodlust, target = "self" },
    },
    {
        name = "LightningBolt",
        conditions = {
            { type = "state", field = "maelstrom_stacks", op = ">=", value = 5 },
        },
        action = { type = "cast", spell = ACTION.LightningBolt, target = "target" },
    },
    {
        name = "Stormstrike",
        conditions = {},
        action = { type = "cast", spell = ACTION.Stormstrike, target = "target" },
    },
    {
        name = "FlameShock",
        conditions = {
            { type = "state", field = "flame_shock_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.FlameShock, target = "target" },
    },
    {
        name = "EarthShock",
        conditions = {},
        action = { type = "cast", spell = ACTION.EarthShock, target = "target" },
    },
    -- Call of the Elements: re-drop the totem set when the water slot is free
    -- (the old build_state read the phantom context.water_totem_remains which
    -- production never set — default 300 made `300 < 20` false forever).
    {
        name = "CallOfTheElements",
        conditions = {
            { type = "state", field = "water_slot_free", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.CallOfTheElements, target = "self" },
    },
    {
        name = "MagmaTotem",
        conditions = {
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "state", field = "fire_slot_free", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.MagmaTotem, target = "self" },
    },
    -- Fire Nova requires an active fire totem in WotLK — without the slot gate
    -- every cast failed whenever Magma Totem was on cooldown or destroyed.
    {
        name = "FireNova",
        conditions = {
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "custom", fn = function(context, state)
                local info = NS.get_totem_info and NS.get_totem_info(FIRE_SLOT) or nil
                return type(info) == "table" and info.have_totem == true
            end },
        },
        action = { type = "cast", spell = ACTION.FireNova, target = "self" },
    },
    {
        name = "LightningShield",
        conditions = {
            { type = "state", field = "lightning_shield_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.LightningShield, target = "self" },
    },
    {
        name = "LavaLash",
        conditions = {},
        action = { type = "cast", spell = ACTION.LavaLash, target = "target" },
    },
    -- Shamanistic Rage (rubric-listed mana/CD mechanic): defensive use at low
    -- mana, ready via the real cooldown API.
    {
        name = "ShamanisticRage",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 40 },
            { type = "state", field = "shamanistic_rage_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.ShamanisticRage, target = "self" },
    },
    -- Weapon-imbue upkeep (wowsims default_wf fixture): no player aura, so the
    -- lanes re-apply on a ~29.8-min window, out of combat only.
    {
        name = "WindfuryWeapon",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "has_windfury", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 5 },
        },
        action = { type = "custom", fn = function(context, state)
            if NS.try_cast(ACTION.WindfuryWeapon, nil, "WindfuryWeapon") == true then
                runtime.last_windfury_ms = state.now_ms
                return true
            end
            return false
        end },
    },
    {
        name = "FlametongueWeapon",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "has_flametongue", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 5 },
        },
        action = { type = "custom", fn = function(context, state)
            if NS.try_cast(ACTION.FlametongueWeapon, nil, "FlametongueWeapon") == true then
                runtime.last_flametongue_ms = state.now_ms
                return true
            end
            return false
        end },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL). The 11 pinned APL
-- lanes keep their exact order; the new lanes append at the end (pin-safe).
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "FeralSpirit" },
    { name = "Bloodlust" },
    { name = "LightningBolt" },
    { name = "Stormstrike" },
    { name = "FlameShock" },
    { name = "EarthShock" },
    { name = "CallOfTheElements" },
    { name = "MagmaTotem" },
    { name = "FireNova" },
    { name = "LightningShield" },
    { name = "LavaLash" },
    { name = "ShamanisticRage" },
    { name = "WindfuryWeapon" },
    { name = "FlametongueWeapon" },
}

-- Name-based substitution preserves the existing priority order.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("enhancement", strategies, { get_state = build_state })
end
if NS.log then NS.log("Shaman Enhancement WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
