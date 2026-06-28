-- test_shaman_enhancement_intelligent_shield.lua — Intelligent Shield Switching.
-- WHAT:  verifies auto shield selection based on mana thresholds.
-- WHEN:  regression guard for enhancement_sylvanas.lua auto shield logic.
-- WHY:   high mana = Lightning Shield (DPS), low mana = Water Shield (regen).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;api/?.lua;api/?/?.lua;api/?/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local enh_build_state = nil
local _captured_strategies

_G.EaxRotations = {
    ShamanSpells = {
        LightningShield = { 324 }, WaterShield = { 33736 },
        ShamanisticRage = { 30823 }, Bloodlust = { 2825 },
        Stormstrike = { 17364 }, FlameShock = { 8050 },
        EarthShock = { 8042 }, FrostShock = { 8056 },
        ChainLightning = { 421 }, LightningBolt = { 403 },
        WindfuryTotem = { 8512 }, GraceOfAirTotem = { 8835 },
        StrengthOfEarthTotem = { 8075 }, StoneskinTotem = { 8155 },
        ManaSpringTotem = { 5675 }, HealingStreamTotem = { 5394 },
        SearingTotem = { 3599 }, MagmaTotem = { 8190 },
        FireNovaTotem = { 1535 }, ManaTideTotem = { 16190 },
        NaturesSwiftness = { 16188 }, LesserHealingWave = { 8004 },
        ChainHeal = { 1064 }, GroundingTotem = { 8177 },
        WindfuryWeapon = 8232, FlametongueWeapon = 8024, RockbiterWeapon = 8017,
        TotemicCall = { 36936 }, GiftOfTheNaaru = { 28880 },
        Purge = { 370 },
    },
    rotation_registry = {
        register = function(self, name, strategies, opts)
            if opts and opts.get_state then enh_build_state = opts.get_state end
            _captured_strategies = strategies
            return true
        end,
    },
    game_time_ms = function() return 0 end,
    GetPlayer = function() local me = {}; me.is_moving = function() return false end; return me end,
    unit_mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    buff_up = function() return false end,
    spell_ready = function() return true end,
    action_matches = function() return true end,
    action_execute = function() return true end,
    try_cast = function() return true end,
    log = function() end,
    is_spell_learned = function(spell) return true end,
    get_totem_info = function(slot) return { have_totem = false } end,
    PLAYER_UNIT = {},
}

_G.core = {
    spell_book = { get_totem_info = function() return { have_totem = false } end },
    object_manager = { get_visible_objects = function() return {} end },
}

package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS = {} }

local strategies = dofile("EaxRotations/classes/shaman/enhancement_sylvanas.lua")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local lightning = find_strategy("LightningShield")
local water = find_strategy("WaterShield")
assert_true(lightning, "LightningShield strategy should exist")
assert_true(water, "WaterShield strategy should exist")

-- C1: High mana (80%), auto shield -> Lightning Shield matches, Water does not
local ctx1 = { settings = { enhancement_shield_type = "auto", enhancement_lightning_shield_mana = 80, enhancement_water_shield_mana = 60 }, in_combat = false, me = { is_moving = function() return false end }, mana_pct = 80, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx1) end
assert_true(lightning.matches(ctx1), "C1: high mana auto -> LightningShield matches")
assert_false(water.matches(ctx1), "C1: high mana auto -> WaterShield blocked")
print("  [ PASS ] C1: high mana auto prefers Lightning Shield")

-- C2: Low mana (30%), auto shield -> Water Shield matches, Lightning does not
local ctx2 = { settings = { enhancement_shield_type = "auto", enhancement_lightning_shield_mana = 80, enhancement_water_shield_mana = 60 }, in_combat = false, me = { is_moving = function() return false end }, mana_pct = 30, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx2) end
assert_true(water.matches(ctx2), "C2: low mana auto -> WaterShield matches")
assert_false(lightning.matches(ctx2), "C2: low mana auto -> LightningShield blocked")
print("  [ PASS ] C2: low mana auto prefers Water Shield")

-- C3: Middle mana (50%), auto shield -> hysteresis keeps current (none active -> default lightning)
local ctx3 = { settings = { enhancement_shield_type = "auto", enhancement_lightning_shield_mana = 80, enhancement_water_shield_mana = 60 }, in_combat = false, me = { is_moving = function() return false end }, mana_pct = 50, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx3) end
-- With no shield active and mana in middle band, should default to lightning
assert_true(lightning.matches(ctx3), "C3: mid mana no shield -> LightningShield default")
print("  [ PASS ] C3: mid mana with no shield defaults to Lightning")

-- C4: Forced lightning -> Water blocked even at low mana
local ctx4 = { settings = { enhancement_shield_type = "lightning", enhancement_lightning_shield_mana = 80, enhancement_water_shield_mana = 60 }, in_combat = false, me = { is_moving = function() return false end }, mana_pct = 20, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx4) end
assert_true(lightning.matches(ctx4), "C4: forced lightning -> matches even at low mana")
assert_false(water.matches(ctx4), "C4: forced lightning -> Water blocked")
print("  [ PASS ] C4: forced shield type overrides auto logic")

-- C5: Forced water -> Lightning blocked even at high mana
local ctx5 = { settings = { enhancement_shield_type = "water", enhancement_lightning_shield_mana = 80, enhancement_water_shield_mana = 60 }, in_combat = false, me = { is_moving = function() return false end }, mana_pct = 90, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx5) end
assert_true(water.matches(ctx5), "C5: forced water -> matches even at high mana")
assert_false(lightning.matches(ctx5), "C5: forced water -> Lightning blocked")
print("  [ PASS ] C5: forced water overrides auto logic")

print("PASS test_shaman_enhancement_intelligent_shield")
