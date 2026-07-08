-- test_elemental_clearcast_priority.lua -- Elemental priority logic tests.
-- WHAT:  Elemental priority logic tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Test: Shaman Elemental Clearcast Chain Lightning Priority (SH3)
-- ----------------------------------------------------------------------------
-- Coverage for EaxRotations/classes/shaman/elemental_sylvanas.lua.
-- Pins the contract that Chain Lightning fires when Clearcast (Elemental Focus)
-- is active even with <3 targets, consuming the proc for free mana.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

_G.EaxRotations = {
    ShamanSpells = {
        ChainLightning = 421,
        LightningBolt = 403,
        FlameShock = 8050,
        EarthShock = 8042,
        FrostShock = 8056,
        Bloodlust = 2825,
        LightningShield = 25472,
        WaterShield = 23551,
        TotemOfWrath = 30706,
        WrathOfAirTotem = 3738,
        ManaSpringTotem = 5675,
        ManaTideTotem = 16190,
        ElementalMastery = 16166,
        NaturesSwiftness = 16188,
        GhostWolf = 2645,
        TremorTotem = 8143,
        EarthbindTotem = 2484,
        FireNovaTotem = 1535,
        MagmaTotem = 8190,
        HealingWave = 331,
        ChainHeal = 1064,
        TotemicCall = 36936,
        FlametongueWeapon = 8024,
        WindfuryWeapon = 8232,
        RockbiterWeapon = 8017,
    },
    PLAYER_UNIT = "player",
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
    spell_ready = function() return true end,
    has_player_buff = function() return false end,
    debuff_remains = function() return 0 end,
    buff_up = function() return false end,
}

local strategies = dofile("EaxRotations/classes/shaman/elemental_sylvanas.lua").strategies
assert_true(type(strategies) == "table", "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name, 2)
end

-- ============================================================================
-- Contract 1: ChainLightning — clearcast active, single target -> match
-- ============================================================================
local cl = find_strategy("ChainLightning")
do
    local ctx = {
        in_combat = true,
        target = {},
        is_moving = false,
        settings = {},
    }
    local s = {
        mana_emergency = false,
        mana_conserve = false,
        target_count = 1,
        clearcast_active = true,
    }
    assert_true(cl.matches(ctx, s),
        "ChainLightning should match when Clearcast is active even with 1 target")
end
print("  [ PASS ] ChainLightning: clearcast + 1 target -> match")

-- ============================================================================
-- Contract 2: ChainLightning — no clearcast, <3 targets -> NO match
-- ============================================================================
do
    local ctx = {
        in_combat = true,
        target = {},
        is_moving = false,
        settings = {},
    }
    local s = {
        mana_emergency = false,
        mana_conserve = false,
        target_count = 1,
        clearcast_active = false,
    }
    assert_false(cl.matches(ctx, s),
        "ChainLightning should NOT match with 1 target and no Clearcast")
end
print("  [ PASS ] ChainLightning: no clearcast + 1 target -> no match")

-- ============================================================================
-- Contract 3: ChainLightning — no clearcast, 3+ targets -> match
-- ============================================================================
do
    local ctx = {
        in_combat = true,
        target = {},
        is_moving = false,
        settings = {},
    }
    local s = {
        mana_emergency = false,
        mana_conserve = false,
        target_count = 3,
        clearcast_active = false,
    }
    assert_true(cl.matches(ctx, s),
        "ChainLightning should match with 3+ targets even without Clearcast")
end
print("  [ PASS ] ChainLightning: no clearcast + 3 targets -> match")

-- ============================================================================
-- Contract 4: ChainLightning — clearcast active, moving -> NO match
-- ============================================================================
do
    local ctx = {
        in_combat = true,
        target = {},
        is_moving = true,
        settings = {},
    }
    local s = {
        mana_emergency = false,
        mana_conserve = false,
        target_count = 1,
        clearcast_active = true,
    }
    assert_false(cl.matches(ctx, s),
        "ChainLightning should NOT match when moving even with Clearcast")
end
print("  [ PASS ] ChainLightning: clearcast + moving -> no match")

-- ============================================================================
-- Contract 5: ChainLightning — mana emergency, clearcast active -> NO match
-- ============================================================================
do
    local ctx = {
        in_combat = true,
        target = {},
        is_moving = false,
        settings = {},
    }
    local s = {
        mana_emergency = true,
        mana_conserve = false,
        target_count = 1,
        clearcast_active = true,
    }
    assert_false(cl.matches(ctx, s),
        "ChainLightning should NOT match during mana emergency even with Clearcast")
end
print("  [ PASS ] ChainLightning: clearcast + mana emergency -> no match")

print("PASS test_elemental_clearcast_priority")
