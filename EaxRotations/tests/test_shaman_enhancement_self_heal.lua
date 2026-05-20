-- Regression: Enhancement self-heals must be HP-gated and must not fire at
-- full health just because the heal spell is ready.

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

local enh_build_state = nil  -- captured from rotation_registry:register to populate enh_state

_G.EaxRotations = {
    ShamanSpells = {
        LightningShield = { 324 },
        ShamanisticRage = { 30823 },
        Bloodlust = { 2825 },
        Stormstrike = { 17364 },
        FlameShock = { 8050 },
        EarthShock = { 8042 },
        FrostShock = { 8056 },
        ChainLightning = { 421 },
        LightningBolt = { 403 },
        WindfuryTotem = { 8512 },
        GraceOfAirTotem = { 8835 },
        StrengthOfEarthTotem = { 8075 },
        ManaSpringTotem = { 5675 },
        ManaTideTotem = { 16190 },
        NaturesSwiftness = { 16188 },
        LesserHealingWave = { 8004 },
        ChainHeal = { 1064 },
    },
    rotation_registry = {
        register = function(self, name, strategies, opts)
            if opts and opts.get_state then
                enh_build_state = opts.get_state  -- capture to populate enh_state for test
            end
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
}	-- Call build_state AFTER enhancement loads so enh_state is populated
	local strategies = dofile("EaxRotations/classes/shaman/enhancement_sylvanas.lua")
	local lhw = find_strategy(strategies, "LesserHealingWave")
	local chain = find_strategy(strategies, "ChainHeal")
	
	assert_true(lhw ~= nil, "Lesser Healing Wave strategy should exist")
	assert_true(chain ~= nil, "Chain Heal strategy should exist")
	
	-- Match functions read from module-local enh_state, not the state parameter.
	-- Rebuild state with appropriate HP before each match call.
	if enh_build_state then
	    enh_build_state({ me = { is_moving = function() return false end }, mana_pct = 100, hp = 100, in_combat = false, enemy_count = 1 })
	end
	assert_false(lhw.matches({ settings = {} }, { lesser_healing_wave_ready = true, hp_pct = 100 }), "LHW should not match at full HP")
	
	if enh_build_state then
	    enh_build_state({ me = { is_moving = function() return false end }, mana_pct = 100, hp = 40, in_combat = false, enemy_count = 1 })
	end
	assert_true(lhw.matches({ settings = {} }, { lesser_healing_wave_ready = true, hp_pct = 40 }), "LHW should match below default self-heal HP")
	
	if enh_build_state then
	    enh_build_state({ me = { is_moving = function() return false end }, mana_pct = 100, hp = 100, in_combat = false, enemy_count = 1 })
	end
	assert_false(chain.matches({ settings = {} }, { chain_heal_ready = true, hp_pct = 100 }), "Chain Heal should not match at full HP")
	
	if enh_build_state then
	    enh_build_state({ me = { is_moving = function() return false end }, mana_pct = 100, hp = 45, in_combat = false, enemy_count = 1, settings = { enhancement_chain_heal_hp = 50 } })
	end
	assert_true(chain.matches({ settings = { enhancement_chain_heal_hp = 50 } }, { chain_heal_ready = true, hp_pct = 45 }), "Chain Heal should honor configured HP")

print("PASS test_shaman_enhancement_self_heal")
