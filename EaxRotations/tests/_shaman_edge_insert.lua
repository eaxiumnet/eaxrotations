-- ============================================================================
-- Edge Case Tests: Healing Wave HP boundary
-- ============================================================================

do -- edge_healing_wave
    test("edge_healing_wave: HP exactly 50 (threshold) -> match", function()
        local ctx = make_context({hp = 50})
        local state = get_state(ctx)
        state.healing_wave_ready = true
        state.hp = 50
        state.heal_hp = 50
        assert_true(strategies[4].matches(ctx, state), "HP 50 should match (<= threshold)")
    end)

    test("edge_healing_wave: HP exactly 51 (above threshold) -> no match", function()
        local ctx = make_context({hp = 51})
        local state = get_state(ctx)
        state.healing_wave_ready = true
        state.hp = 51
        state.heal_hp = 50
        assert_false(strategies[4].matches(ctx, state), "HP 51 should not match (> threshold)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Chain Lightning enemy count boundary
-- ============================================================================

do -- edge_chain_lightning
    test("edge_chain_lightning: enemies exactly 2 -> match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.chain_lightning_ready = true
        state.enemies = 2
        assert_true(strategies[8].matches(ctx, state), "2 enemies should match (>= 2)")
    end)

    test("edge_chain_lightning: enemies exactly 1 -> no match", function()
        local ctx = make_context({enemies_count = 1})
        local state = get_state(ctx)
        state.chain_lightning_ready = true
        state.enemies = 1
        assert_false(strategies[8].matches(ctx, state), "1 enemy should not match (< 2)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Flame Shock DoT refresh boundary
-- ============================================================================

do -- edge_flame_shock
    test("edge_flame_shock: debuff remains exactly 0 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.flame_shock_ready = true
        state.use_shocks = true
        state.default_shock = "flame"
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 0 end
        assert_true(strategies[9].matches(ctx, state), "remains 0 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test("edge_flame_shock: debuff remains exactly 5 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.flame_shock_ready = true
        state.use_shocks = true
        state.default_shock = "flame"
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 5 end
        assert_false(strategies[9].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)

    test("edge_flame_shock: default shock not flame -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.flame_shock_ready = true
        state.use_shocks = true
        state.default_shock = "earth"
        assert_false(strategies[9].matches(ctx, state), "earth default should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Earth Shock DPS default shock boundary
-- ============================================================================

do -- edge_earth_shock
    test("edge_earth_shock: default shock earth -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.earth_shock_ready = true
        state.use_shocks = true
        state.default_shock = "earth"
        assert_true(strategies[10].matches(ctx, state), "earth default should match")
    end)

    test("edge_earth_shock: default shock not earth -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.earth_shock_ready = true
        state.use_shocks = true
        state.default_shock = "flame"
        assert_false(strategies[10].matches(ctx, state), "flame default should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Frost Shock default shock boundary
-- ============================================================================

do -- edge_frost_shock
    test("edge_frost_shock: default shock frost -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.frost_shock_ready = true
        state.use_shocks = true
        state.default_shock = "frost"
        assert_true(strategies[11].matches(ctx, state), "frost default should match")
    end)

    test("edge_frost_shock: default shock not frost -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.frost_shock_ready = true
        state.use_shocks = true
        state.default_shock = "flame"
        assert_false(strategies[11].matches(ctx, state), "flame default should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Earthbind Totem boundaries
-- ============================================================================

do -- edge_earthbind
    test("edge_earthbind: enemies exactly 3 -> match", function()
        local ctx = make_context({hp = 40, enemies_count = 3})
        local state = get_state(ctx)
        state.earthbind_totem_ready = true
        state.hp = 40
        state.enemies = 3
        assert_true(strategies[12].matches(ctx, state), "3 enemies should match (>= 3)")
    end)

    test("edge_earthbind: enemies exactly 2 -> no match", function()
        local ctx = make_context({hp = 40, enemies_count = 2})
        local state = get_state(ctx)
        state.earthbind_totem_ready = true
        state.hp = 40
        state.enemies = 2
        assert_false(strategies[12].matches(ctx, state), "2 enemies should not match (< 3)")
    end)

    test("edge_earthbind: HP exactly 50 -> match", function()
        local ctx = make_context({hp = 50, enemies_count = 3})
        local state = get_state(ctx)
        state.earthbind_totem_ready = true
        state.hp = 50
        state.enemies = 3
        assert_true(strategies[12].matches(ctx, state), "HP 50 should match (<= 50)")
    end)

    test("edge_earthbind: HP exactly 51 -> no match", function()
        local ctx = make_context({hp = 51, enemies_count = 3})
        local state = get_state(ctx)
        state.earthbind_totem_ready = true
        state.hp = 51
        state.enemies = 3
        assert_false(strategies[12].matches(ctx, state), "HP 51 should not match (> 50)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Water Totem mana/HP boundary
-- ============================================================================

do -- edge_water_totem
    test("edge_water_totem: mana exactly 85 -> match (mana_spring)", function()
        local ctx = make_context({mana_pct = 85, hp = 100})
        local state = get_state(ctx)
        state.mana_spring_ready = true
        state.healing_stream_ready = true
        state.use_totems = true
        state.use_water_totem = true
        state.mana_pct = 85
        state.hp = 100
        assert_true(strategies[7].matches(ctx, state), "mana 85 should match (<= 85)")
    end)

    test("edge_water_totem: mana exactly 86 -> no match", function()
        local ctx = make_context({mana_pct = 86, hp = 100})
        local state = get_state(ctx)
        state.mana_spring_ready = true
        state.healing_stream_ready = true
        state.use_totems = true
        state.use_water_totem = true
        state.mana_pct = 86
        state.hp = 100
        assert_false(strategies[7].matches(ctx, state), "mana 86 should not match (> 85)")
    end)

    test("edge_water_totem: HP exactly 85 -> match (healing_stream)", function()
        local ctx = make_context({mana_pct = 100, hp = 85})
        local state = get_state(ctx)
        state.mana_spring_ready = true
        state.healing_stream_ready = true
        state.use_totems = true
        state.use_water_totem = true
        state.mana_pct = 100
        state.hp = 85
        assert_true(strategies[7].matches(ctx, state), "HP 85 should match (<= 85)")
    end)

    test("edge_water_totem: HP exactly 86 -> no match", function()
        local ctx = make_context({mana_pct = 100, hp = 86})
        local state = get_state(ctx)
        state.mana_spring_ready = true
        state.healing_stream_ready = true
        state.use_totems = true
        state.use_water_totem = true
        state.mana_pct = 100
        state.hp = 86
        assert_false(strategies[7].matches(ctx, state), "HP 86 should not match (> 85)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Ghost Wolf distance boundary
-- ============================================================================

do -- edge_ghost_wolf
    test("edge_ghost_wolf: distance exactly 19 -> no match", function()
        local ctx = make_context({in_combat = false})
        local saved = NS.get_distance
        NS.get_distance = function() return 19 end
        local state = get_state(ctx)
        state.ghost_wolf_ready = true
        state.in_combat = false
        assert_false(strategies[14].matches(ctx, state), "distance 19 should not match (< 20)")
        NS.get_distance = saved
    end)

    test("edge_ghost_wolf: distance exactly 20 -> match", function()
        local ctx = make_context({in_combat = false})
        local saved = NS.get_distance
        NS.get_distance = function() return 20 end
        local state = get_state(ctx)
        state.ghost_wolf_ready = true
        state.in_combat = false
        assert_true(strategies[14].matches(ctx, state), "distance 20 should match (>= 20)")
        NS.get_distance = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Wand mana boundary
-- ============================================================================

do -- edge_wand
    test("edge_wand: mana exactly 29 (below threshold) -> match", function()
        local ctx = make_context({mana_pct = 29})
        local state = get_state(ctx)
        state.wand_threshold = 30
        state.mana_pct = 29
        state.wand_learned = true
        assert_true(strategies[15].matches(ctx, state), "mana 29 should match (< threshold)")
    end)

    test("edge_wand: mana exactly 30 (at threshold) -> no match", function()
        local ctx = make_context({mana_pct = 30})
        local state = get_state(ctx)
        state.wand_threshold = 30
        state.mana_pct = 30
        state.wand_learned = true
        assert_false(strategies[15].matches(ctx, state), "mana 30 should not match (>= threshold)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Weapon Imbue & Lightning Shield (OOC buffs)
-- ============================================================================

do -- edge_weapon_imbue
    test("edge_weapon_imbue: OOC, no imbue, ready -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.use_weapon_imbue = true
        state.weapon_imbue = { 25485 }
        state.has_mainhand_imbue = false
        state.weapon_imbue_api_known = true
        assert_true(strategies[1].matches(ctx, state), "unbuffed OOC should match")
    end)

    test("edge_weapon_imbue: already imbued -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.use_weapon_imbue = true
        state.has_mainhand_imbue = true
        assert_false(strategies[1].matches(ctx, state), "already imbued should not match")
    end)
end

do -- edge_lightning_shield
    test("edge_lightning_shield: OOC, no shield, ready -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.has_lightning_shield = false
        state.lightning_shield_ready = true
        assert_true(strategies[2].matches(ctx, state), "unshielded OOC should match")
    end)

    test("edge_lightning_shield: already shielded -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.has_lightning_shield = true
        state.lightning_shield_ready = true
        assert_false(strategies[2].matches(ctx, state), "already shielded should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Searing/Strength/Water totem disabled boundaries
-- ============================================================================

do -- edge_totem_disabled
    test("edge_searing_totem: totems disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.searing_totem_ready = true
        state.use_totems = false
        assert_false(strategies[5].matches(ctx, state), "totems disabled should not match")
    end)

    test("edge_searing_totem: searing disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.searing_totem_ready = true
        state.use_totems = true
        state.use_searing_totem = false
        assert_false(strategies[5].matches(ctx, state), "searing disabled should not match")
    end)

    test("edge_strength_totem: strength disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.strength_of_earth_ready = true
        state.use_totems = true
        state.use_strength_totem = false
        assert_false(strategies[6].matches(ctx, state), "strength disabled should not match")
    end)

    test("edge_water_totem: water disabled -> no match", function()
        local ctx = make_context({mana_pct = 60})
        local state = get_state(ctx)
        state.mana_spring_ready = true
        state.use_totems = true
        state.use_water_totem = false
        state.mana_pct = 60
        assert_false(strategies[7].matches(ctx, state), "water disabled should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Lightning Bolt movement boundary
-- ============================================================================

do -- edge_lightning_bolt
    test("edge_lightning_bolt: not moving -> match", function()
        local ctx = make_context({is_moving = false})
        local state = get_state(ctx)
        state.lightning_bolt_ready = true
        state.is_moving = false
        assert_true(strategies[13].matches(ctx, state), "stationary should match")
    end)

    test("edge_lightning_bolt: moving -> no match", function()
        local ctx = make_context({is_moving = true})
        local state = get_state(ctx)
        state.lightning_bolt_ready = true
        state.is_moving = true
        assert_false(strategies[13].matches(ctx, state), "moving should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Interrupt boundary
-- ============================================================================

do -- edge_interrupt
    test("edge_earth_shock_interrupt: target casting -> match", function()
        local ctx = make_context()
        ctx.target.is_casting = function() return true end
        local state = get_state(ctx)
        state.earth_shock_ready = true
        state.use_interrupt = true
        assert_true(strategies[3].matches(ctx, state), "target casting should match")
    end)

    test("edge_earth_shock_interrupt: target not casting -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.earth_shock_ready = true
        state.use_interrupt = true
        assert_false(strategies[3].matches(ctx, state), "target not casting should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Build state API safety (nil/throwing NS functions)
-- ============================================================================

do -- edge_buff
    test("edge_buff: NS.buff_up nil in build_state -> no crash", function()
        local saved = NS.buff_up
        NS.buff_up = nil
        local ctx = make_context()
        local state = get_state(ctx)
        NS.buff_up = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.has_lightning_shield, "has_lightning_shield should be false")
    end)

    test("edge_buff: NS.buff_up throws in build_state -> no crash", function()
        local saved = NS.buff_up
        NS.buff_up = function() error("crash") end
        local ctx = make_context()
        local state = get_state(ctx)
        NS.buff_up = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.has_lightning_shield, "has_lightning_shield should be false")
    end)
end

-- ============================================================================
-- Edge Case Tests: API crash safety (spell_ready, try_cast)
-- ============================================================================

do -- edge_api
    test("edge_api: NS.spell_ready nil -> no crash, ready flags false", function()
        local saved = NS.spell_ready
        NS.spell_ready = nil
        local ctx = make_context()
        local state = get_state(ctx)
        NS.spell_ready = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.lightning_bolt_ready, "lightning_bolt_ready should be false")
        assert_false(state.earth_shock_ready, "earth_shock_ready should be false")
    end)

    test("edge_api: NS.spell_ready throws -> no crash, ready flags false", function()
        local saved = NS.spell_ready
        NS.spell_ready = function() error("crash") end
        local ctx = make_context()
        local state = get_state(ctx)
        NS.spell_ready = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.lightning_bolt_ready, "lightning_bolt_ready should be false")
        assert_false(state.earth_shock_ready, "earth_shock_ready should be false")
    end)

    test("edge_api: NS.try_cast nil does not crash execute functions", function()
        local saved = NS.try_cast
        NS.try_cast = nil
        local ctx = make_context()
        for i = 1, 15 do
            local ok, result = pcall(strategies[i].execute, ctx)
            assert_true(ok, string.format("strategies[%d].execute should not crash with NS.try_cast nil", i))
        end
        NS.try_cast = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Rotation crash safety
-- ============================================================================

do -- edge_rotation_crash
    test("edge_rotation_crash: all execute functions handle nil context", function()
        for i = 1, 15 do
            local ok, result = pcall(strategies[i].execute)
            assert_true(ok, string.format("strategies[%d].execute should not crash with nil context", i))
        end
    end)

    test("edge_rotation_crash: all match functions handle nil context", function()
        for i = 1, 15 do
            local ok, result = pcall(strategies[i].matches, nil, {})
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil context", i))
        end
    end)

    test("edge_rotation_crash: all match functions handle nil state", function()
        local ctx = make_context()
        for i = 1, 15 do
            local ok, result = pcall(strategies[i].matches, ctx, nil)
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil state", i))
        end
    end)
end
