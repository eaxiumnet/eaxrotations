-- _warlock_deep_dive.lua -- Warlock deep dive tests.
-- WHAT:  Warlock deep dive tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Explores edge cases and internal logic paths not covered by standard suites.
-- SAFETY: Ad-hoc tests; may be run manually during deep debugging.
-- NOTE (PR2): numeric strategy indices here (e.g. Corruption was ~11, Immolate~12) are from
-- this ad-hoc file's strategy table (may differ from affliction_sylvanas main rotation).
-- Post UA reorder in main affliction, some indices stale. Converted relevant debuff/DoT
-- tests to name-based. Use name-based for sylvanas main rotation (see test_affliction_custom_matches.lua).

-- ============================================================================
-- Deep dive: Systematic OOC guard loop — combat-gated strategies
-- ============================================================================
do
    -- Combat-gated: {4,5,6,7,8,9,10,11,12,13,14,15,16,17,18}
    -- OOC-only: {1,2,3} — have `if state.in_combat then return false end`
    -- No combat gate: none (all have either combat-gate or OOC-only or both)
    --   * FelArmor(1): OOC-only (if state.in_combat then return false)
    --   * Healthstone(2): OOC-only
    --   * Soulstone(3): OOC-only
    --   * SpellLock(4): no in_combat check, but checks target.is_casting
    --   * HealthFunnel(5): combat-gated
    --   * SummonPet(6): combat-gated
    --   * Fear(7): combat-gated
    --   * HowlOfTerror(8): combat-gated
    --   * DeathCoil(9): combat-gated
    --   * LifeTap(10): combat-gated
    --   * Corruption(11): combat-gated   [was ~11; post UA reorder in affliction main; stale indices note added; prefer name-based lookup for sylvanas main rotation]
    --   * Immolate(12): combat-gated   [stale indices; use name-based for sylvanas main rotation]
    --   * CurseOfAgony(13): combat-gated
    --   * SiphonLife(14): combat-gated
    --   * DrainLife(15): combat-gated
    --   * DrainSoul(16): combat-gated
    --   * ShadowBolt(17): combat-gated
    --   * Wand(18): combat-gated
    local combat_gated = {5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18}
    local ooc_only = {1, 2, 3}

    local ctx = make_context({in_combat = false, hp = 30, mana_pct = 30, enemies_count = 3, is_moving = false})
    ctx.pet = { is_valid = function() return true end, get_health_percentage = function() return 30 end }
    ctx.target.get_health_percentage = function() return 25 end
    ctx.target.is_casting = function() return true end

    local state = get_state(ctx)
    for k, v in pairs(state) do
        if type(v) == "boolean" then state[k] = true end
    end
    state.in_combat = false
    state.has_fel_armor = true  -- prevent OOC-only from matching
    state.healthstone_ready = true
    state.soulstone_ready = true
    state.pet_hp = 30
    state.hp = 30
    state.mana_pct = 30
    state.enemies = 3
    state.wand_threshold = 30
    state.drain_soul_execute = 25
    state.drain_life_hp = 60
    state.use_corruption = true
    state.use_immolate = true
    state.use_curse_of_agony = true

    test("ooc_guard_systematic: combat-gated strategies return false OOC", function()
        for _, idx in ipairs(combat_gated) do
            local ok, matched = pcall(strategies[idx].matches, ctx, state)
            assert_true(ok, "strategy " .. idx .. " (" .. strategies[idx].name .. ") OOC does not throw")
            assert_false(matched, "strategy " .. idx .. " (" .. strategies[idx].name .. ") returns false OOC")
        end
    end)

    -- OOC-only strategies should match OOC (without their buff active)
    local ctx_ooc = make_context({in_combat = false})
    local state_ooc = get_state(ctx_ooc)
    state_ooc.has_fel_armor = false
    state_ooc.fel_armor_ready = true
    state_ooc.healthstone_ready = true
    state_ooc.soulstone_ready = true
    assert_true(strategies[1].matches(ctx_ooc, state_ooc), "felarmor matches OOC without buff")
    assert_true(strategies[2].matches(ctx_ooc, state_ooc), "healthstone matches OOC")
    assert_true(strategies[3].matches(ctx_ooc, state_ooc), "soulstone matches OOC")

    -- OOC-only strategies return false in combat
    local ctx_combat = make_context({in_combat = true})
    local state_combat = get_state(ctx_combat)
    state_combat.has_fel_armor = false
    state_combat.fel_armor_ready = true
    state_combat.healthstone_ready = true
    state_combat.soulstone_ready = true
    assert_false(strategies[1].matches(ctx_combat, state_combat), "felarmor no match in combat")
    assert_false(strategies[2].matches(ctx_combat, state_combat), "healthstone no match in combat")
    assert_false(strategies[3].matches(ctx_combat, state_combat), "soulstone no match in combat")
end

-- ============================================================================
-- Deep dive: Systematic nil target guard loop
-- ============================================================================
do
    -- Target-dependent: {4,7,9,11,12,13,14,15,16,17,18}
    -- Non-target: {1,2,3,5,6,8,10}
    -- (indices audited post-reorder; Corruption etc noted stale; use name-based)
    local target_dependent = {4, 7, 9, 11, 12, 13, 14, 15, 16, 17, 18}
    local ctx = make_context({target = nil, in_combat = true, hp = 30, mana_pct = 30, enemies_count = 3, is_moving = false})
    ctx.target = nil
    ctx.pet = { is_valid = function() return true end, get_health_percentage = function() return 30 end }
    local state = get_state(ctx)
    for k, v in pairs(state) do
        if type(v) == "boolean" then state[k] = true end
    end
    state.target = nil
    state.in_combat = true
    state.mana_pct = 30
    state.enemies = 3
    state.hp = 30
    state.wand_threshold = 30
    state.pet_hp = 30
    state.use_corruption = true
    state.use_immolate = true
    state.use_curse_of_agony = true
    state.drain_soul_execute = 25
    state.drain_life_hp = 60

    test("nil_target_systematic: target-dependent strategies return false with nil target", function()
        for _, idx in ipairs(target_dependent) do
            local ok, matched = pcall(strategies[idx].matches, ctx, state)
            assert_true(ok, "strategy " .. idx .. " (" .. strategies[idx].name .. ") nil target does not throw")
            assert_false(matched, "strategy " .. idx .. " (" .. strategies[idx].name .. ") returns false with nil target")
        end
    end)
end

-- ============================================================================
-- Deep dive: NS.debuff_remains nil/throwing in match functions
-- ============================================================================
do
    -- All three safe_debuff_remains usages in Warlock handle nil/throwing via pcall
    -- Corruption (was ~11), Immolate (12), Curse of Agony (13), Siphon Life (14), Fear (7)
    -- stale indices; use name-based for sylvanas main rotation (post UA reorder)
    local ctx = make_context({is_moving = false})
    local state = get_state(ctx)
    state.corruption_ready = true
    state.use_corruption = true
    state.immolate_ready = true
    state.use_immolate = true
    state.curse_of_agony_ready = true
    state.use_curse_of_agony = true
    state.siphon_life_ready = true
    state.fear_ready = true
    state.enemies = 2

    test("debuff_remains_nil: corruption match does not crash when NS.debuff_remains is nil", function()
        local saved = NS.debuff_remains
        NS.debuff_remains = nil
        -- name-based (converted per PR2; was strategies[11] ~Corruption)
        local strat = nil; for i=1,#strategies do if strategies[i].name == "CorruptionDoT" or strategies[i].name == "Corruption" then strat = strategies[i]; break end end
        local ok, result = pcall((strat or strategies[11] or {}).matches, ctx, state)
        assert_true(ok, "corruption match does not crash when NS.debuff_remains nil")
        assert_true(result, "corruption match returns true when remains defaults to 0")
        NS.debuff_remains = saved
    end)

    test("debuff_remains_nil: immolate match does not crash when NS.debuff_remains is nil", function()
        local saved = NS.debuff_remains
        NS.debuff_remains = nil
        -- name-based (converted per PR2; was strategies[12] ~Immolate)
        local strat = nil; for i=1,#strategies do if strategies[i].name == "ImmolateDoT" or strategies[i].name == "Immolate" then strat = strategies[i]; break end end
        local ok, result = pcall((strat or strategies[12] or {}).matches, ctx, state)
        assert_true(ok, "immolate match does not crash when NS.debuff_remains nil")
        NS.debuff_remains = saved
    end)

    test("debuff_remains_nil: curse_of_agony match does not crash when NS.debuff_remains is nil", function()
        local saved = NS.debuff_remains
        NS.debuff_remains = nil
        -- name-based fallback (stale indices; use name-based for sylvanas main rotation)
        local strat = nil; for i=1,#strategies do if strategies[i].name == "CurseOfAgony" or strategies[i].name == "CurseOfAgonyDoT" then strat = strategies[i]; break end end
        local ok, result = pcall((strat or strategies[13] or {}).matches, ctx, state)
        assert_true(ok, "curse_of_agony match does not crash when NS.debuff_remains nil")
        NS.debuff_remains = saved
    end)

    test("debuff_remains_nil: siphon_life match does not crash when NS.debuff_remains is nil", function()
        local saved = NS.debuff_remains
        NS.debuff_remains = nil
        -- name-based (converted; was [14])
        local strat = nil; for i=1,#strategies do if strategies[i].name == "SiphonLife" or strategies[i].name == "SiphonLifeDoT" then strat = strategies[i]; break end end
        local ok, result = pcall((strat or strategies[14] or {}).matches, ctx, state)
        assert_true(ok, "siphon_life match does not crash when NS.debuff_remains nil")
        NS.debuff_remains = saved
    end)

    test("debuff_remains_throwing: corruption match does not crash when NS.debuff_remains throws", function()
        local saved = NS.debuff_remains
        NS.debuff_remains = function() error("crash") end
        -- name-based (was [11])
        local strat = nil; for i=1,#strategies do if strategies[i].name == "CorruptionDoT" or strategies[i].name == "Corruption" then strat = strategies[i]; break end end
        local ok, result = pcall((strat or strategies[11] or {}).matches, ctx, state)
        assert_true(ok, "corruption match does not crash when NS.debuff_remains throws")
        NS.debuff_remains = saved
    end)
end

-- ============================================================================
-- Deep dive: SpellLock pcall safety when target:is_casting throws
-- ============================================================================
do
    test("spell_lock_is_casting_throw: is_casting throwing does not crash match", function()
        local ctx = make_context()
        ctx.target = {
            is_valid = function() return true end,
            is_casting = function() error("simulated throw") end,
            get_guid = function() return "mock-target" end,
        }
        local state = get_state(ctx)
        state.spell_lock_ready = true
        state.target = ctx.target
        state.use_interrupt = true
        local ok, result = pcall(strategies[4].matches, ctx, state)
        assert_true(ok, "spell_lock match does not crash when is_casting throws")
        assert_false(result, "spell_lock returns false when is_casting throws")
    end)
end

-- ============================================================================
-- Deep dive: NS.try_cast returning false for all 18 strategy executes
-- ============================================================================
do
    test("try_cast_false_all: all executes handle NS.try_cast returning false", function()
        local saved = NS.try_cast
        NS.try_cast = function() return false end
        local ctx = make_context()
        for i = 1, #strategies do
            local ok, result = pcall(strategies[i].execute, ctx)
            assert_true(ok, "strategy " .. i .. " execute did not crash when try_cast returns false")
        end
        NS.try_cast = saved
    end)
end

-- ============================================================================
-- Deep dive: safe_debuff_remains with nil target
-- ============================================================================
do
    -- safe_debuff_remains checks `if not unit or not NS.debuff_remains then return 0 end`
    -- If state.target is nil, safe_debuff_remains receives nil and returns 0 safely
    test("debuff_remains_nil_target: corruption match with nil target does not crash", function()
        local ctx = make_context({target = nil})
        ctx.target = nil
        local state = get_state(ctx)
        state.corruption_ready = true
        state.use_corruption = true
        state.target = nil
        -- corruption_matches first checks `if not state.target then return false end`
        -- converted to name-based + fallback (stale indices; use name-based for sylvanas main rotation)
        local strat = nil; for i=1,#strategies do if strategies[i].name == "CorruptionDoT" or strategies[i].name == "Corruption" then strat = strategies[i]; break end end
        local ok, result = pcall((strat or strategies[11] or {}).matches, ctx, state)
        assert_true(ok, "corruption match does not crash with nil target")
        assert_false(result, "corruption match returns false with nil target (nil target guard fires first)")
    end)
end

-- ============================================================================
-- Deep dive: build_state with mana_pct=0 and 100 extremes
-- ============================================================================
do
    test("build_state_mana_0: all strategies handle mana_pct=0 safely", function()
        local ctx = make_context({mana_pct = 0, is_moving = false})
        local state = get_state(ctx)
        assert_eq(state.mana_pct, 0, "mana_pct=0 from context")
        -- ShadowBolt: mana=0 < 10 -> no match
        state.shadow_bolt_ready = true
        assert_false(strategies[17].matches(ctx, state), "shadowbolt mana=0 -> no match (<10)")
        -- Wand: mana=0 < 30 -> match
        state.wand_learned = true
        state.wand_threshold = 30
        assert_true(strategies[18].matches(ctx, state), "wand mana=0 -> match (<30)")
        -- LifeTap: mana=0 <= 30 -> match (if HP ok)
        state.life_tap_ready = true
        state.life_tap_mana = 30
        state.hp = 50
        assert_true(strategies[10].matches(ctx, state), "lifetap mana=0 -> match (<=30)")
    end)

    test("build_state_mana_100: all strategies handle mana_pct=100 safely", function()
        local ctx = make_context({mana_pct = 100, is_moving = false})
        local state = get_state(ctx)
        assert_eq(state.mana_pct, 100, "mana_pct=100 from context")
        -- ShadowBolt: mana=100 >= 10 -> match
        state.shadow_bolt_ready = true
        assert_true(strategies[17].matches(ctx, state), "shadowbolt mana=100 -> match (>=10)")
        -- Wand: mana=100 >= 30 -> no match
        state.wand_learned = true
        state.wand_threshold = 30
        assert_false(strategies[18].matches(ctx, state), "wand mana=100 -> no match (>=30)")
        -- LifeTap: mana=100 > 30 -> no match
        state.life_tap_ready = true
        state.life_tap_mana = 30
        assert_false(strategies[10].matches(ctx, state), "lifetap mana=100 -> no match (>30)")
    end)
end

-- ============================================================================
-- Deep dive: Pet HP nil in build_state
-- ============================================================================
do
    test("build_state_pet_hp_nil: pet exists but get_health_percentage returns nil -> pet_hp=100", function()
        local ctx = make_context({})
        ctx.pet = {
            is_valid = function() return true end,
            get_health_percentage = function() return nil end,
        }
        local state = get_state(ctx)
        assert_eq(state.pet_hp, 100, "pet_hp defaults to 100 when get_health_percentage returns nil")
    end)

    test("build_state_pet_hp_throws: pet get_health_percentage throws -> pcall catches, pet_hp=100", function()
        local ctx = make_context({})
        ctx.pet = {
            is_valid = function() return true end,
            get_health_percentage = function() error("crash") end,
        }
        local state = get_state(ctx)
        assert_eq(state.pet_hp, 100, "pet_hp defaults to 100 when get_health_percentage throws")
    end)
end

-- ============================================================================
-- Deep dive: leveling_context_allowed edge cases
-- ============================================================================
do
    test("context_allowed: not solo and not leveling -> false for all strategies", function()
        local ctx = make_context({})
        ctx.is_solo = false
        ctx.is_leveling = false
        ctx.settings.playstyle = "raid"
        ctx.settings.active_playstyle = "raid"
        local state = get_state(ctx)
        -- All match functions check leveling_context_allowed first
        for i = 1, #strategies do
            local ok, matched = pcall(strategies[i].matches, ctx, state)
            assert_true(ok, "strategy " .. i .. " does not throw when context not allowed")
            assert_false(matched, "strategy " .. i .. " returns false when context not allowed")
        end
    end)

    test("context_allowed: solo mode is allowed", function()
        local ctx = make_context({})
        ctx.is_solo = true
        ctx.is_leveling = false
        local state = get_state(ctx)
        state.has_fel_armor = false
        state.fel_armor_ready = true
        assert_true(strategies[1].matches(ctx, state), "felarmor matches in solo mode")
    end)
end

-- ============================================================================
-- Deep dive: Fear debuff remains boundary at exactly 8
-- ============================================================================
do
    test("fear_remains_8: fear debuff remains exactly 8 -> match (<=8)", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.fear_ready = true
        state.enemies = 2
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 8 end
        assert_true(strategies[7].matches(ctx, state), "fear remains=8 -> match (<=8)")
        NS.debuff_remains = saved
    end)

    test("fear_remains_9: fear debuff remains exactly 9 -> no match (>8)", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.fear_ready = true
        state.enemies = 2
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 9 end
        assert_false(strategies[7].matches(ctx, state), "fear remains=9 -> no match (>8)")
        NS.debuff_remains = saved
    end)
end

-- ============================================================================
-- Deep dive: SummonPet spell priority chain - nil spells handled safely
-- ============================================================================
do
    test("summon_pet_spell_nil: summon chain handles nil SPELLS entries", function()
        -- Simulate that only SummonFelhunter is available (others nil)
        local saved_guard = SPELLS.SummonFelguard
        local saved_hunter = SPELLS.SummonFelhunter
        SPELLS.SummonFelguard = nil
        SPELLS.SummonFelhunter = { 19647 }
        -- Reload state to pick up nil Felguard
        local ctx = make_context({in_combat = true})
        ctx.pet = nil
        ctx.target = {
            is_valid = function() return true end,
            get_health = function() return 8000 end,
            get_max_health = function() return 10000 end,
            is_casting = function() return false end,
            is_alive = function() return true end,
            get_guid = function() return "mock-target" end,
            get_health_percentage = function() return 50 end,
        }
        local state = get_state(ctx)
        state.summon_felguard_ready = false
        state.summon_felhunter_ready = true
        assert_true(strategies[6].matches(ctx, state), "summonpet falls through nil spells to felhunter")
        SPELLS.SummonFelguard = saved_guard
        SPELLS.SummonFelhunter = saved_hunter
    end)
end
