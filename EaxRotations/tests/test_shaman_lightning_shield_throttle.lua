-- Regression: Shaman spec rotations should not spam Lightning Shield when
-- aura detection fails or target changes cause state rebuilds.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;api/?.lua;api/?/?.lua;api/?/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_false(v, label)
    if v then error(label or "assert_false failed", 2) end
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local now_ms = 0
local enh_build_state = nil  -- captured from rotation_registry:register to populate enh_state

_G.EaxRotations = {
    ShamanSpells = {
        LightningShield = { 324 },
        WaterShield = { 24398 },
        GhostWolf = { 2645 },
        TremorTotem = { 8143 },
        EarthbindTotem = { 2484 },
        ManaTideTotem = { 16190 },
        ElementalMastery = { 16166 },
        NaturesSwiftness = { 16188 },
        Bloodlust = { 2825 },
        ChainLightning = { 421 },
        LightningBolt = { 403 },
        FlameShock = { 8050 },
        EarthShock = { 8042 },
        FrostShock = { 8056 },
        ShamanisticRage = { 30823 },
        Stormstrike = { 17364 },
        WindfuryTotem = { 8512 },
        GraceOfAirTotem = { 8835 },
        StrengthOfEarthTotem = { 8075 },
        ManaSpringTotem = { 5675 },
        LesserHealingWave = { 8004 },
        ChainHeal = { 1064 },
    },
    PLAYER_UNIT = {},
    rotation_registry = {
        register = function(self, name, strategies, opts)
            if opts and opts.get_state then
                enh_build_state = opts.get_state  -- capture to populate enh_state for test
            end
            return true
        end,
    },
    game_time_ms = function() return now_ms end,
    GetPlayer = function() local me = {}; me.is_moving = function() return false end; return me end,
    has_player_buff = function() return false end,
    buff_up = function() return false end,
    unit_mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    spell_ready = function() return true end,
    action_matches = function() return true end,
    action_execute = function() return true end,
    try_cast = function() return true end,
    debuff_remains = function() return 0 end,
    should_refresh_dot = function() return true end,
    log = function() end,
    is_hostile_unit = function() return true end,
}

_G.core = {
    time = function() return 0 end,
    spell_book = {
        get_totem_info = function() return { have_totem = false } end,
    },
}

local elemental = dofile("EaxRotations/classes/shaman/elemental_sylvanas.lua").strategies
local enhancement = dofile("EaxRotations/classes/shaman/enhancement_sylvanas.lua").strategies
    -- Helper: refresh enh_state by calling enh_build_state with current now_ms
    -- The enhancement shield match function reads enh_state (not the state param),
    -- so enh_build_state must be called each time to refresh enh_state.now_ms.
    local function refresh_state()
        if enh_build_state then
            enh_build_state({ me = { is_moving = function() return false end, get_position = function() return { x = 0, y = 0, z = 0 } end }, mana_pct = 100, hp = 100, in_combat = false, enemy_count = 1 })
        end
    end
    
    local elemental_shield = find_strategy(elemental, "LightningShield")
    local enhancement_shield = find_strategy(enhancement, "LightningShield")
    
    assert_true(elemental_shield ~= nil, "Elemental Lightning Shield strategy should exist")
    assert_true(enhancement_shield ~= nil, "Enhancement Lightning Shield strategy should exist")
    
    now_ms = 0
    assert_true(elemental_shield.matches({}, { lightning_shield_up = false, now_ms = now_ms }), "Elemental shield should match initially")
    assert_true(elemental_shield.execute({}, { now_ms = now_ms }), "Elemental shield execute should succeed")
    now_ms = 10000
    assert_false(elemental_shield.matches({}, { lightning_shield_up = false, now_ms = now_ms }), "Elemental shield should throttle failed aura reads")
    now_ms = 31000
    assert_true(elemental_shield.matches({}, { lightning_shield_up = false, now_ms = now_ms }), "Elemental shield should allow retry after throttle")
    
    -- Enhancement shield uses enh_state (not state param), so refresh before each test
    now_ms = 0
    refresh_state()
    assert_true(enhancement_shield.matches({}, { has_lightning_shield = false, lightning_shield_ready = true, now_ms = now_ms }), "Enhancement shield should match initially")
    assert_true(enhancement_shield.execute({}), "Enhancement shield execute should succeed")
    now_ms = 10000
    refresh_state()
    assert_false(enhancement_shield.matches({}, { has_lightning_shield = false, lightning_shield_ready = true, now_ms = now_ms }), "Enhancement shield should throttle failed aura reads")
    now_ms = 31000
    refresh_state()
    assert_true(enhancement_shield.matches({}, { has_lightning_shield = false, lightning_shield_ready = true, now_ms = now_ms }), "Enhancement shield should allow retry after throttle")

print("PASS test_shaman_lightning_shield_throttle")
