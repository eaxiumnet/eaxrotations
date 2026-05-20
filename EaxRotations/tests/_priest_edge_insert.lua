-- ============================================================================
-- Edge Case Tests: Power Word: Shield (strategy 3)
-- ============================================================================

do -- edge_shield
    test("edge_shield: shield matches at HP 59 (below heal_hp threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.shield_ready = true
        state.hp = 59
        assert_true(strategies[3].matches(ctx, state), "shield should match at HP 59 (below 60)")
    end)

    test("edge_shield: shield does not match at HP 60 (at heal_hp threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.shield_ready = true
        state.hp = 60
        assert_false(strategies[3].matches(ctx, state), "shield should not match at HP 60")
    end)

    test("edge_shield: shield does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.shield_ready = true
        state.hp = 40
        state.target = nil
        assert_false(strategies[3].matches(ctx, state), "shield should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Renew (strategy 4)
-- ============================================================================

do -- edge_renew
    test("edge_renew: renew matches at HP 59 (below heal_hp threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.renew_ready = true
        state.hp = 59
        assert_true(strategies[4].matches(ctx, state), "renew should match at HP 59")
    end)

    test("edge_renew: renew does not match at HP 60 (at heal_hp threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.renew_ready = true
        state.hp = 60
        assert_false(strategies[4].matches(ctx, state), "renew should not match at HP 60")
    end)

    test("edge_renew: renew does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.renew_ready = true
        state.hp = 40
        state.target = nil
        assert_false(strategies[4].matches(ctx, state), "renew should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: GreaterHeal (strategy 5)
-- ============================================================================

do -- edge_heal
    test("edge_heal: GreaterHeal matches at HP 59, not moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.greater_heal_ready = true
        state.hp = 59
        state.is_moving = false
        assert_true(strategies[5].matches(ctx, state), "heal should match at HP 59, stationary")
    end)

    test("edge_heal: GreaterHeal does not match when moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.greater_heal_ready = true
        state.hp = 40
        state.is_moving = true
        assert_false(strategies[5].matches(ctx, state), "heal should not match while moving")
    end)

    test("edge_heal: GreaterHeal does not match at HP 60 (at heal_hp threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.greater_heal_ready = true
        state.hp = 60
        state.is_moving = false
        assert_false(strategies[5].matches(ctx, state), "heal should not match at HP 60")
    end)
end

-- ============================================================================
-- Edge Case Tests: Psychic Scream (strategy 6)
-- ============================================================================

do -- edge_scream
    test("edge_scream: scream matches when enemy count is exactly 3", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.scream_ready = true
        state.enemies = 3
        assert_true(strategies[6].matches(ctx, state), "scream should match at exactly 3 enemies")
    end)

    test("edge_scream: scream does not match when enemy count exactly 2", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.scream_ready = true
        state.enemies = 2
        assert_false(strategies[6].matches(ctx, state), "scream should not match at 2 enemies")
    end)

    test("edge_scream: scream does not match when not ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.scream_ready = false
        state.enemies = 3
        assert_false(strategies[6].matches(ctx, state), "scream should not match when not ready")
    end)
end

-- ============================================================================
-- Edge Case Tests: Fade (strategy 7)
-- ============================================================================

do -- edge_fade
    test("edge_fade: fade matches when threat >= 3", function()
        local ctx = make_context({}, {threat_status = 3})
        local state = get_state(ctx)
        state.fade_ready = true
        assert_true(strategies[7].matches(ctx, state), "fade should match at threat 3")
    end)

    test("edge_fade: fade does not match when threat < 3", function()
        local ctx = make_context({}, {threat_status = 2})
        local state = get_state(ctx)
        state.fade_ready = true
        assert_false(strategies[7].matches(ctx, state), "fade should not match at threat 2")
    end)

    test("edge_fade: fade does not match when not ready", function()
        local ctx = make_context({}, {threat_status = 3})
        local state = get_state(ctx)
        state.fade_ready = false
        assert_false(strategies[7].matches(ctx, state), "fade should not match when not ready")
    end)
end

-- ============================================================================
-- Edge Case Tests: Shackle Undead (strategy 8)
-- ============================================================================

do -- edge_shackle
    test("edge_shackle: shackle matches when target is undead", function()
        local ctx = make_context({}, {target_creature_type = "undead"})
        local state = get_state(ctx)
        state.shackle_ready = true
        assert_true(strategies[8].matches(ctx, state), "shackle should match on undead target")
    end)

    test("edge_shackle: shackle does not match when target is humanoid", function()
        local ctx = make_context({}, {target_creature_type = "humanoid"})
        local state = get_state(ctx)
        state.shackle_ready = true
        assert_false(strategies[8].matches(ctx, state), "shackle should not match on humanoid")
    end)

    test("edge_shackle: shackle does not match when not ready", function()
        local ctx = make_context({}, {target_creature_type = "undead"})
        local state = get_state(ctx)
        state.shackle_ready = false
        assert_false(strategies[8].matches(ctx, state), "shackle should not match when not ready")
    end)
end

-- ============================================================================
-- Edge Case Tests: Shadow Word: Pain (strategy 9)
-- ============================================================================

do -- edge_swp
    test("edge_swp: SWP matches when debuff remains exactly 0 (needs refresh)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swp_ready = true
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 0 end
        assert_true(strategies[9].matches(ctx, state), "SWP should match when debuff at 0")
        NS.debuff_remains = saved_remains
    end)

    test("edge_swp: SWP does not match when debuff remains at 4 (>= refresh threshold)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swp_ready = true
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 4 end
        assert_false(strategies[9].matches(ctx, state), "SWP should not match when remains >= 4")
        NS.debuff_remains = saved_remains
    end)

    test("edge_swp: SWP does not match when not ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swp_ready = false
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 0 end
        assert_false(strategies[9].matches(ctx, state), "SWP should not match when not ready")
        NS.debuff_remains = saved_remains
    end)

    test("edge_swp: SWP does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.swp_ready = true
        state.target = nil
        assert_false(strategies[9].matches(ctx, state), "SWP should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Shadow Word: Death (strategy 10)
-- ============================================================================

do -- edge_swd
    test("edge_swd: SWD matches when player HP is 34 (below 35)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swd_ready = true
        state.hp = 34
        assert_true(strategies[10].matches(ctx, state), "SWD should match at HP 34")
    end)

    test("edge_swd: SWD does not match when player HP is exactly 35", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swd_ready = true
        state.hp = 35
        assert_false(strategies[10].matches(ctx, state), "SWD should not match at HP 35")
    end)

    test("edge_swd: SWD does not match when not ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.swd_ready = false
        state.hp = 34
        assert_false(strategies[10].matches(ctx, state), "SWD should not match when not ready")
    end)

    test("edge_swd: SWD does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.swd_ready = true
        state.target = nil
        state.hp = 34
        assert_false(strategies[10].matches(ctx, state), "SWD should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Holy Fire (strategy 11)
-- ============================================================================

do -- edge_holy_fire
    test("edge_holy_fire: Holy Fire matches when debuff remains 0, not moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_fire_ready = true
        state.is_moving = false
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 0 end
        assert_true(strategies[11].matches(ctx, state), "Holy Fire should match when debuff at 0")
        NS.debuff_remains = saved_remains
    end)

    test("edge_holy_fire: Holy Fire does not match when moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_fire_ready = true
        state.is_moving = true
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 0 end
        assert_false(strategies[11].matches(ctx, state), "Holy Fire should not match while moving")
        NS.debuff_remains = saved_remains
    end)

    test("edge_holy_fire: Holy Fire does not match when debuff remains at 4", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_fire_ready = true
        state.is_moving = false
        local saved_remains = NS.debuff_remains
        NS.debuff_remains = function(target, ids) return 4 end
        assert_false(strategies[11].matches(ctx, state), "Holy Fire should not match when remains >= 4")
        NS.debuff_remains = saved_remains
    end)
end

-- ============================================================================
-- Edge Case Tests: Mind Blast (strategy 12)
-- ============================================================================

do -- edge_mind_blast
    test("edge_mind_blast: Mind Blast matches when ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.mind_blast_ready = true
        assert_true(strategies[12].matches(ctx, state), "Mind Blast should match when ready")
    end)

    test("edge_mind_blast: Mind Blast does not match when not ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.mind_blast_ready = false
        assert_false(strategies[12].matches(ctx, state), "Mind Blast should not match when not ready")
    end)

    test("edge_mind_blast: Mind Blast does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.mind_blast_ready = true
        state.target = nil
        assert_false(strategies[12].matches(ctx, state), "Mind Blast should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Holy Nova (strategy 13)
-- ============================================================================

do -- edge_holy_nova
    test("edge_holy_nova: Holy Nova matches when enemy count exactly 3, not moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_nova_ready = true
        state.enemies = 3
        state.is_moving = false
        assert_true(strategies[13].matches(ctx, state), "Holy Nova should match at 3 enemies")
    end)

    test("edge_holy_nova: Holy Nova does not match when enemy count exactly 2", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_nova_ready = true
        state.enemies = 2
        state.is_moving = false
        assert_false(strategies[13].matches(ctx, state), "Holy Nova should not match at 2 enemies")
    end)

    test("edge_holy_nova: Holy Nova does not match while moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.holy_nova_ready = true
        state.enemies = 3
        state.is_moving = true
        assert_false(strategies[13].matches(ctx, state), "Holy Nova should not match while moving")
    end)
end

-- ============================================================================
-- Edge Case Tests: Smite (strategy 14)
-- ============================================================================

do -- edge_smite
    test("edge_smite: smite matches when mana_pct exactly at threshold (20), not moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.smite_ready = true
        state.mana_pct = 20
        state.is_moving = false
        assert_true(strategies[14].matches(ctx, state), "smite should match at mana_pct 20")
    end)

    test("edge_smite: smite does not match when mana_pct below threshold (19)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.smite_ready = true
        state.mana_pct = 19
        state.is_moving = false
        assert_false(strategies[14].matches(ctx, state), "smite should not match at mana_pct 19")
    end)

    test("edge_smite: smite does not match while moving", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.smite_ready = true
        state.mana_pct = 50
        state.is_moving = true
        assert_false(strategies[14].matches(ctx, state), "smite should not match while moving")
    end)

    test("edge_smite: smite does not match when not ready", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.smite_ready = false
        state.mana_pct = 50
        state.is_moving = false
        assert_false(strategies[14].matches(ctx, state), "smite should not match when not ready")
    end)

    test("edge_smite: smite does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.smite_ready = true
        state.mana_pct = 50
        state.is_moving = false
        state.target = nil
        assert_false(strategies[14].matches(ctx, state), "smite should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Wand (strategy 15)
-- ============================================================================

do -- edge_wand
    test("edge_wand: wand matches when mana_pct (10) below threshold (20)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.mana_pct = 10
        assert_true(strategies[15].matches(ctx, state), "wand should match at low mana")
    end)

    test("edge_wand: wand does not match when mana_pct exactly at threshold (20)", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.mana_pct = 20
        assert_false(strategies[15].matches(ctx, state), "wand should not match at mana_pct 20")
    end)

    test("edge_wand: wand does not match when no target", function()
        local ctx = make_context({target = nil})
        local state = get_state(ctx)
        state.mana_pct = 10
        state.target = nil
        assert_false(strategies[15].matches(ctx, state), "wand should not match with no target")
    end)
end

-- ============================================================================
-- Edge Case Tests: Buff API Safety (has_buff via pcall)
-- ============================================================================

do -- edge_buff
    test("edge_buff: NS.get_local_player nil in build_state returns safe defaults for buff checks", function()
        local saved = NS.get_local_player
        NS.get_local_player = function() return nil end
        local ok, state = pcall(get_state, make_context())
        NS.get_local_player = saved
        assert_true(ok, "build_state should not crash when NS.get_local_player returns nil")
        if ok and state then
            assert_false(state.has_fortitude, "has_fortitude should be false when no local player")
            assert_false(state.has_inner_fire, "has_inner_fire should be false when no local player")
        end
    end)

    test("edge_buff: NS.get_local_player throws in build_state returns safe defaults for buff checks", function()
        local saved = NS.get_local_player
        NS.get_local_player = function() error("player system failure") end
        local ok, state = pcall(get_state, make_context())
        NS.get_local_player = saved
        assert_true(ok, "build_state should not crash when NS.get_local_player throws")
        if ok and state then
            assert_false(state.has_fortitude, "has_fortitude should be false when get_local_player throws")
            assert_false(state.has_inner_fire, "has_inner_fire should be false when get_local_player throws")
        end
    end)
end

-- ============================================================================
-- Edge Case Tests: Spell API Safety (spell_ready via spell_ready wrapper)
-- ============================================================================

do -- edge_api
    test("edge_api: NS.spell_ready nil in build_state returns false for readiness", function()
        local saved = NS.spell_ready
        NS.spell_ready = nil
        local ok, state = pcall(get_state, make_context())
        NS.spell_ready = saved
        assert_true(ok, "build_state should not crash when NS.spell_ready is nil")
        if ok and state then
            assert_false(state.smite_ready, "smite_ready should be false when NS.spell_ready is nil")
            assert_false(state.shield_ready, "shield_ready should be false when NS.spell_ready is nil")
        end
    end)

    test("edge_api: NS.spell_ready throws in build_state returns false for readiness", function()
        local saved = NS.spell_ready
        NS.spell_ready = function() error("cd system down") end
        local ok, state = pcall(get_state, make_context())
        NS.spell_ready = saved
        assert_true(ok, "build_state should not crash when NS.spell_ready throws")
        if ok and state then
            assert_false(state.smite_ready, "smite_ready should be false when NS.spell_ready throws")
        end
    end)

    test("edge_api: NS.try_cast nil does not crash execute functions", function()
        local saved = NS.try_cast
        NS.try_cast = nil
        local ctx = make_context()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.execute, ctx)
            assert_true(ok, string.format("strategies[%d].execute should not crash when NS.try_cast is nil", i))
        end
        NS.try_cast = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Rotation Crash Safety (nil context / nil state)
-- ============================================================================

do -- edge_rotation_crash
    test("edge_rotation_crash: all match functions handle nil context", function()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.matches, nil, {})
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil context", i))
        end
    end)

    test("edge_rotation_crash: all match functions handle nil state", function()
        local ctx = make_context()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.matches, ctx, nil)
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil state", i))
        end
    end)

    test("edge_rotation_crash: all execute functions handle nil context", function()
        for i, s in ipairs(strategies) do
            local ok, result = pcall(s.execute)
            assert_true(ok, string.format("strategies[%d].execute should not crash with nil context", i))
        end
    end)
end
