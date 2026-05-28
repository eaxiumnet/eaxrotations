-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/_warlock_edge_insert.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- ============================================================================
-- Edge Case Tests: Corruption refresh boundaries
-- ============================================================================

do -- edge_corruption
    test("edge_corruption: debuff remains exactly 0 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.corruption_ready = true
        state.use_corruption = true
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 0 end
        assert_true(strategies[8].matches(ctx, state), "remains 0 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test("edge_corruption: debuff remains exactly 5 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.corruption_ready = true
        state.use_corruption = true
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 5 end
        assert_false(strategies[8].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)

    test("edge_corruption: use_corruption disabled -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.corruption_ready = true
        state.use_corruption = false
        assert_false(strategies[8].matches(ctx, state), "disabled should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Immolate refresh boundaries
-- ============================================================================

do -- edge_immolate
    test("edge_immolate: debuff remains exactly 0 -> match", function()
        local ctx = make_context({is_moving = false})
        local state = get_state(ctx)
        state.immolate_ready = true
        state.use_immolate = true
        state.is_moving = false
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 0 end
        assert_true(strategies[9].matches(ctx, state), "remains 0 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test("edge_immolate: debuff remains exactly 5 -> no match", function()
        local ctx = make_context({is_moving = false})
        local state = get_state(ctx)
        state.immolate_ready = true
        state.use_immolate = true
        state.is_moving = false
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 5 end
        assert_false(strategies[9].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)

    test("edge_immolate: moving -> no match", function()
        local ctx = make_context({is_moving = true})
        local state = get_state(ctx)
        state.immolate_ready = true
        state.use_immolate = true
        state.is_moving = true
        assert_false(strategies[9].matches(ctx, state), "moving should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Curse of Agony refresh boundaries
-- ============================================================================

do -- edge_curse
    test("edge_curse: debuff remains exactly 0 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.curse_of_agony_ready = true
        state.use_curse_of_agony = true
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 0 end
        assert_true(strategies[10].matches(ctx, state), "remains 0 should match (<= 4)")
        NS.debuff_remains = saved
    end)

    test("edge_curse: debuff remains exactly 5 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.curse_of_agony_ready = true
        state.use_curse_of_agony = true
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 5 end
        assert_false(strategies[10].matches(ctx, state), "remains 5 should not match (> 4)")
        NS.debuff_remains = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Life Tap boundaries
-- ============================================================================

do -- edge_life_tap
    test("edge_life_tap: mana exactly 30 (threshold) -> match", function()
        local ctx = make_context({mana_pct = 30, hp = 50})
        local state = get_state(ctx)
        state.life_tap_ready = true
        state.mana_pct = 30
        state.life_tap_mana = 30
        state.hp = 50
        assert_true(strategies[7].matches(ctx, state), "mana at threshold should match")
    end)

    test("edge_life_tap: mana exactly 31 (above threshold) -> no match", function()
        local ctx = make_context({mana_pct = 31, hp = 50})
        local state = get_state(ctx)
        state.life_tap_ready = true
        state.mana_pct = 31
        state.life_tap_mana = 30
        state.hp = 50
        assert_false(strategies[7].matches(ctx, state), "mana above threshold should not match")
    end)

    test("edge_life_tap: HP exactly 29 -> match", function()
        local ctx = make_context({mana_pct = 20, hp = 29})
        local state = get_state(ctx)
        state.life_tap_ready = true
        state.mana_pct = 20
        state.life_tap_mana = 30
        state.hp = 29
        assert_true(strategies[7].matches(ctx, state), "HP 29 should match (< 30)")
    end)

    test("edge_life_tap: HP exactly 30 -> no match", function()
        local ctx = make_context({mana_pct = 20, hp = 30})
        local state = get_state(ctx)
        state.life_tap_ready = true
        state.mana_pct = 20
        state.life_tap_mana = 30
        state.hp = 30
        assert_false(strategies[7].matches(ctx, state), "HP 30 should not match (> 29)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Drain Soul execute boundaries
-- ============================================================================

do -- edge_drain_soul
    test("edge_drain_soul: target HP exactly 25 (execute threshold) -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 50
        local saved = ctx.target.get_health_percentage
        ctx.target.get_health_percentage = function() return 25 end
        -- Need to rebuild state to pick up target HP
        state.target_hp_override = 25
        -- Direct state override since build_state reads target at test time
        local target_ok, target_hp = pcall(ctx.target.get_health_percentage)
        if not (target_ok and target_hp and target_hp > state.drain_soul_execute) and state.mana_pct <= 30 then
            -- we need to set state via override
        end
        -- Production reads target HP directly, not from state. Need to mock target.get_health_percentage
        -- The test already set it above, now recreate state to pick it up
        state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 50
        assert_true(strategies[11].matches(ctx, state), "target HP 25 should match (<= threshold)")
        ctx.target.get_health_percentage = saved
    end)

    test("edge_drain_soul: target HP exactly 26 (above execute threshold) -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 50
        local saved = ctx.target.get_health_percentage
        ctx.target.get_health_percentage = function() return 26 end
        state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 50
        assert_false(strategies[11].matches(ctx, state), "target HP 26 should not match (> threshold)")
        ctx.target.get_health_percentage = saved
    end)

    test("edge_drain_soul: mana exactly 30 (low mana gate) -> match", function()
        local ctx = make_context({mana_pct = 30})
        local state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 30
        local saved = ctx.target.get_health_percentage
        ctx.target.get_health_percentage = function() return 50 end
        state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 30
        assert_true(strategies[11].matches(ctx, state), "mana 30 should match (<= 30)")
        ctx.target.get_health_percentage = saved
    end)

    test("edge_drain_soul: mana exactly 31 (above low mana gate) -> no match", function()
        local ctx = make_context({mana_pct = 31})
        local state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 31
        local saved = ctx.target.get_health_percentage
        ctx.target.get_health_percentage = function() return 50 end
        state = get_state(ctx)
        state.drain_soul_ready = true
        state.drain_soul_execute = 25
        state.mana_pct = 31
        assert_false(strategies[11].matches(ctx, state), "mana 31 should not match (> 30)")
        ctx.target.get_health_percentage = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Death Coil HP boundary
-- ============================================================================

do -- edge_death_coil
    test("edge_death_coil: HP exactly 40 -> match", function()
        local ctx = make_context({hp = 40})
        local state = get_state(ctx)
        state.death_coil_ready = true
        state.hp = 40
        assert_true(strategies[6].matches(ctx, state), "HP 40 should match (<= 40)")
    end)

    test("edge_death_coil: HP exactly 41 -> no match", function()
        local ctx = make_context({hp = 41})
        local state = get_state(ctx)
        state.death_coil_ready = true
        state.hp = 41
        assert_false(strategies[6].matches(ctx, state), "HP 41 should not match (> 40)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Fear enemy count boundary
-- ============================================================================

do -- edge_fear
    test("edge_fear: enemies exactly 2 -> match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.fear_ready = true
        state.enemies = 2
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 0 end
        assert_true(strategies[5].matches(ctx, state), "2 enemies should match (>= 2)")
        NS.debuff_remains = saved
    end)

    test("edge_fear: enemies exactly 1 -> no match", function()
        local ctx = make_context({enemies_count = 1})
        local state = get_state(ctx)
        state.fear_ready = true
        state.enemies = 1
        assert_false(strategies[5].matches(ctx, state), "1 enemy should not match (< 2)")
    end)

    test("edge_fear: debuff remains exactly 8 -> match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.fear_ready = true
        state.enemies = 2
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 8 end
        assert_true(strategies[5].matches(ctx, state), "remains 8 should match (<= 8)")
        NS.debuff_remains = saved
    end)

    test("edge_fear: debuff remains exactly 9 -> no match", function()
        local ctx = make_context({enemies_count = 2})
        local state = get_state(ctx)
        state.fear_ready = true
        state.enemies = 2
        local saved = NS.debuff_remains
        NS.debuff_remains = function() return 9 end
        assert_false(strategies[5].matches(ctx, state), "remains 9 should not match (> 8)")
        NS.debuff_remains = saved
    end)
end

-- ============================================================================
-- Edge Case Tests: Health Funnel boundaries
-- ============================================================================

do -- edge_health_funnel
    test("edge_health_funnel: pet HP exactly 50 -> match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.health_funnel_ready = true
        state.pet_hp = 50
        state.hp = 80
        assert_true(strategies[4].matches(ctx, state), "pet HP 50 should match (<= 50)")
    end)

    test("edge_health_funnel: pet HP exactly 51 -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.health_funnel_ready = true
        state.pet_hp = 51
        state.hp = 80
        assert_false(strategies[4].matches(ctx, state), "pet HP 51 should not match (> 50)")
    end)

    test("edge_health_funnel: player HP exactly 39 -> match", function()
        local ctx = make_context({hp = 39})
        local state = get_state(ctx)
        state.health_funnel_ready = true
        state.pet_hp = 30
        state.hp = 39
        assert_true(strategies[4].matches(ctx, state), "player HP 39 should match (< 40)")
    end)

    test("edge_health_funnel: player HP exactly 40 -> no match", function()
        local ctx = make_context({hp = 40})
        local state = get_state(ctx)
        state.health_funnel_ready = true
        state.pet_hp = 30
        state.hp = 40
        assert_false(strategies[4].matches(ctx, state), "player HP 40 should not match (> 39)")
    end)
end

-- ============================================================================
-- Edge Case Tests: Wand mana boundary
-- ============================================================================

do -- edge_wand
    test("edge_wand: mana exactly 29 (below threshold) -> match", function()
        local ctx = make_context({mana_pct = 29})
        local state = get_state(ctx)
        state.wand_learned = true
        state.wand_threshold = 30
        state.mana_pct = 29
        assert_true(strategies[13].matches(ctx, state), "mana 29 should match (< threshold)")
    end)

    test("edge_wand: mana exactly 30 (at threshold) -> no match", function()
        local ctx = make_context({mana_pct = 30})
        local state = get_state(ctx)
        state.wand_learned = true
        state.wand_threshold = 30
        state.mana_pct = 30
        assert_false(strategies[13].matches(ctx, state), "mana 30 should not match (>= threshold)")
    end)

    test("edge_wand: wand not learned -> no match", function()
        local ctx = make_context({mana_pct = 10})
        local state = get_state(ctx)
        state.wand_learned = false
        state.wand_threshold = 30
        state.mana_pct = 10
        assert_false(strategies[13].matches(ctx, state), "wand not learned should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Shadow Bolt mana boundary
-- ============================================================================

do -- edge_shadow_bolt
    test("edge_shadow_bolt: mana exactly 9 -> match", function()
        local ctx = make_context({mana_pct = 9, is_moving = false})
        local state = get_state(ctx)
        state.shadow_bolt_ready = true
        state.mana_pct = 9
        state.is_moving = false
        assert_true(strategies[12].matches(ctx, state), "mana 9 should match (>= 9)")
    end)

    test("edge_shadow_bolt: mana exactly 10 -> no match", function()
        local ctx = make_context({mana_pct = 10, is_moving = false})
        local state = get_state(ctx)
        state.shadow_bolt_ready = true
        state.mana_pct = 10
        state.is_moving = false
        assert_false(strategies[12].matches(ctx, state), "mana 10 should not match (>= 10)")
    end)

    test("edge_shadow_bolt: moving -> no match", function()
        local ctx = make_context({mana_pct = 50, is_moving = true})
        local state = get_state(ctx)
        state.shadow_bolt_ready = true
        state.mana_pct = 50
        state.is_moving = true
        assert_false(strategies[12].matches(ctx, state), "moving should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Fel Armor & Healthstone (OOC buffs)
-- ============================================================================

do -- edge_fel_armor
    test("edge_fel_armor: not buffed, OOC -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.has_fel_armor = false
        state.fel_armor_ready = true
        assert_true(strategies[1].matches(ctx, state), "unbuffed OOC should match")
    end)

    test("edge_fel_armor: already buffed -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.has_fel_armor = true
        state.fel_armor_ready = true
        assert_false(strategies[1].matches(ctx, state), "buffed should not match")
    end)
end

do -- edge_healthstone
    test("edge_healthstone: ready, OOC -> match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.healthstone_ready = true
        assert_true(strategies[2].matches(ctx, state), "ready OOC should match")
    end)

    test("edge_healthstone: not ready -> no match", function()
        local ctx = make_context({in_combat = false})
        local state = get_state(ctx)
        state.healthstone_ready = false
        assert_false(strategies[2].matches(ctx, state), "not ready should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Spell Lock (interrupt)
-- ============================================================================

do -- edge_spell_lock
    test("edge_spell_lock: target is casting -> match", function()
        local ctx = make_context()
        ctx.target.is_casting = function() return true end
        local state = get_state(ctx)
        state.spell_lock_ready = true
        state.target = ctx.target
        state.use_interrupt = true
        assert_true(strategies[3].matches(ctx, state), "target casting should match")
    end)

    test("edge_spell_lock: target not casting -> no match", function()
        local ctx = make_context()
        local state = get_state(ctx)
        state.spell_lock_ready = true
        state.target = ctx.target
        state.use_interrupt = true
        assert_false(strategies[3].matches(ctx, state), "target not casting should not match")
    end)
end

-- ============================================================================
-- Edge Case Tests: Build state API safety (nil/throwing NS functions)
-- ============================================================================

do -- edge_buff
    test("edge_buff: NS.buff_up nil in build_state -> no crash, has_fel_armor false", function()
        local saved = NS.buff_up
        NS.buff_up = nil
        local ctx = make_context()
        local state = get_state(ctx)
        NS.buff_up = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.has_fel_armor, "has_fel_armor should be false when NS.buff_up is nil")
    end)

    test("edge_buff: NS.buff_up throws in build_state -> no crash, has_fel_armor false", function()
        local saved = NS.buff_up
        NS.buff_up = function() error("crash") end
        local ctx = make_context()
        local state = get_state(ctx)
        NS.buff_up = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.has_fel_armor, "has_fel_armor should be false when NS.buff_up throws")
    end)
end

-- ============================================================================
-- Edge Case Tests: API crash safety (spell_ready, try_cast)
-- ============================================================================

do -- edge_api
    test("edge_api: NS.spell_ready nil in build_state -> no crash, all ready flags false", function()
        local saved = NS.spell_ready
        NS.spell_ready = nil
        local ctx = make_context()
        local state = get_state(ctx)
        NS.spell_ready = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.shadow_bolt_ready, "shadow_bolt_ready should be false")
        assert_false(state.corruption_ready, "corruption_ready should be false")
        assert_false(state.immolate_ready, "immolate_ready should be false")
    end)

    test("edge_api: NS.spell_ready throws in build_state -> no crash, all ready flags false", function()
        local saved = NS.spell_ready
        NS.spell_ready = function() error("crash") end
        local ctx = make_context()
        local state = get_state(ctx)
        NS.spell_ready = saved
        assert_not_nil(state, "state should not be nil")
        assert_false(state.shadow_bolt_ready, "shadow_bolt_ready should be false")
        assert_false(state.corruption_ready, "corruption_ready should be false")
    end)

    test("edge_api: NS.try_cast nil does not crash execute functions", function()
        local saved = NS.try_cast
        NS.try_cast = nil
        local ctx = make_context()
        for i = 1, 13 do
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
        for i = 1, 13 do
            local ok, result = pcall(strategies[i].execute)
            assert_true(ok, string.format("strategies[%d].execute should not crash with nil context", i))
        end
    end)

    test("edge_rotation_crash: all match functions handle nil context", function()
        for i = 1, 13 do
            local ok, result = pcall(strategies[i].matches, nil, {})
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil context", i))
        end
    end)

    test("edge_rotation_crash: all match functions handle nil state", function()
        local ctx = make_context()
        for i = 1, 13 do
            local ok, result = pcall(strategies[i].matches, ctx, nil)
            assert_true(ok, string.format("strategies[%d].matches should not crash with nil state", i))
        end
    end)
end
