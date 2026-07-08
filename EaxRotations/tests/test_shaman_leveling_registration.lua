-- test_shaman_leveling_registration.lua -- Shaman leveling rotation tests.
-- WHAT:  Shaman leveling rotation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Regression: Shaman leveling must be registered with the dispatcher and use
-- NS.ShamanSpells, not the legacy empty NS.SPELLS table.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local casts = {}

_G.core = {
    time = function() return 0 end,
    input = {
        cast_target_spell = function(spell_id, target)
            casts[#casts + 1] = { spell_id = spell_id, target = target }
            return true
        end,
    },
}

_G.EaxRotations = {
    ShamanSpells = {
        LightningBolt = { 403 },
        EarthShock = { 8042 },
        FlameShock = { 8050 },
        FrostShock = { 8056 },
        ChainLightning = { 421 },
        LightningShield = { 324 },
        WaterShield = { 24398 },
        HealingWave = { 331 },
        LesserHealingWave = { 8004 },
        GhostWolf = { 2645 },
        Purge = { 370 },
        EarthbindTotem = { 2484 },
        StoneclawTotem = { 5730 },
        FireNovaTotem = { 1535 },
        SearingTotem = { 3599 },
        StrengthOfEarthTotem = { 8075 },
        GraceOfAirTotem = { 8835 },
        ManaSpringTotem = { 5675 },
        HealingStreamTotem = { 5394 },
        GroundingTotem = { 8177 },
        WindfuryTotem = { 8512 },
        TremorTotem = { 8143 },
        WindfuryWeapon = { 8232 },
        RockbiterWeapon = { 8017 },
        FlametongueWeapon = { 8024 },
        FrostbrandWeapon = { 8033 },
    },
    rotation_registry = {
        registered_name = nil,
        registered_strategies = nil,
        registered_options = nil,
        register = function(self, name, strategies, options)
            self.registered_name = name
            self.registered_strategies = strategies
            self.registered_options = options
            return true
        end,
    },
    log = function() end,
    spell_ready = function(spell) return spell ~= nil end,
    try_cast = function(spell, target)
        if not spell then return false end
        casts[#casts + 1] = { spell = spell, target = target }
        return true
    end,
    spell_exists = function() return true end,
    debuff_remains = function() return 0 end,
    get_local_player = function()
        return { has_buff = function() return false end }
    end,
}

local module = dofile("EaxRotations/classes/shaman/leveling_sylvanas.lua")
local registry = _G.EaxRotations.rotation_registry

assert_true(module ~= nil, "module should load")
assert_true(registry.registered_name == "leveling", "Shaman leveling should register as a playstyle")
assert_true(type(registry.registered_options.get_state) == "function", "Shaman leveling should expose get_state")

local target = { is_casting = function() return false end }
local state = registry.registered_options.get_state({
    in_combat = true,
    is_solo = true,
    mana_pct = 80,
    hp = 100,
    enemies_count = 1,
    target = target,
    is_moving = false,
    settings = { playstyle = "leveling", leveling_use_shocks = true },
})

assert_true(state.lightning_bolt_ready == true, "Lightning Bolt should be ready from NS.ShamanSpells")
assert_true(module.on_update({
    in_combat = true,
    is_solo = true,
    mana_pct = 80,
    hp = 100,
    enemies_count = 1,
    target = target,
    is_moving = false,
    settings = { playstyle = "leveling", leveling_use_shocks = true },
}) == true, "Shaman leveling should cast a spell")
assert_true(casts[#casts] and casts[#casts].spell == _G.EaxRotations.ShamanSpells.SearingTotem, "Shaman leveling should drop Searing Totem in combat")

casts = {}
assert_true(module.on_update({
    in_combat = false,
    is_solo = true,
    mana_pct = 80,
    hp = 100,
    enemies_count = 0,
    target = nil,
    is_moving = false,
    settings = { playstyle = "leveling", leveling_use_weapon_imbue = true },
}) == true, "Shaman leveling should apply a weapon imbue out of combat")
assert_true(casts[1] and casts[1].spell == _G.EaxRotations.ShamanSpells.WindfuryWeapon, "Auto imbue should prefer Windfury when known")

_G.EaxRotations.get_local_player = function()
    return { has_buff = function() return true end }
end

assert_true(module.on_update({
    in_combat = false,
    has_valid_enemy_target = true,
    is_solo = true,
    mana_pct = 80,
    hp = 100,
    enemies_count = 1,
    target = target,
    is_moving = false,
    settings = { playstyle = "leveling", leveling_use_shocks = false, leveling_use_weapon_imbue = false },
}) == true, "Shaman leveling should pull a selected enemy before combat")

print("PASS test_shaman_leveling_registration")
