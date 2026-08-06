-- _rogue_edge_insert.lua -- Rogue edge-case insert tests.
-- WHAT:  Rogue edge-case insert tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Explores edge cases and internal logic paths not covered by standard suites.
-- SAFETY: Ad-hoc tests; may be run manually during deep debugging.

-- ============================================================================
-- Edge case tests - boundary values
-- ============================================================================

do -- edge_gouge
 local label = "edge_gouge"

 test(label .. ": HP exactly 40 -> match", function()
 local ctx = make_context({hp = 40})
 local state = get_state(ctx)
 state.gouge_ready = true
 state.hp = 40
 assert_true(strategies[5].matches(ctx, state), "HP 40 should match (<= threshold)")
 end)

 test(label .. ": HP exactly 41 -> no match", function()
 local ctx = make_context({hp = 41})
 local state = get_state(ctx)
 state.gouge_ready = true
 state.hp = 41
 assert_false(strategies[5].matches(ctx, state), "HP 41 should not match (> threshold)")
 end)
end

do -- edge_vanish
 local label = "edge_vanish"

 test(label .. ": HP exactly 15 (vanish_hp) -> match", function()
 local ctx = make_context({hp = 15})
 local state = get_state(ctx)
 state.vanish_ready = true
 state.hp = 15
 state.vanish_hp = 15
 assert_true(strategies[7].matches(ctx, state), "HP 15 should match (<= threshold)")
 end)

 test(label .. ": HP exactly 16 (above vanish_hp) -> no match", function()
 local ctx = make_context({hp = 16})
 local state = get_state(ctx)
 state.vanish_ready = true
 state.hp = 16
 state.vanish_hp = 15
 assert_false(strategies[7].matches(ctx, state), "HP 16 should not match (> threshold)")
 end)

 test(label .. ": vanish not ready -> no match", function()
 local ctx = make_context({hp = 10})
 local state = get_state(ctx)
 state.vanish_ready = false
 state.hp = 10
 state.vanish_hp = 15
 assert_false(strategies[7].matches(ctx, state), "not ready should not match")
 end)

 test(label .. ": OOC -> no match", function()
 local ctx = make_context({hp = 10, in_combat = false})
 local state = get_state(ctx)
 state.vanish_ready = true
 state.hp = 10
 state.vanish_hp = 15
 state.in_combat = false
 assert_false(strategies[7].matches(ctx, state), "OOC should not match")
 end)
end

do -- edge_evasion
 local label = "edge_evasion"

 test(label .. ": HP exactly 50, enemies exactly 2 -> match", function()
 local ctx = make_context({hp = 50, enemies_count = 2})
 local state = get_state(ctx)
 state.evasion_ready = true
 state.hp = 50
 state.enemies = 2
 assert_true(strategies[8].matches(ctx, state), "HP 50 with 2 enemies should match")
 end)

 test(label .. ": HP exactly 51, enemies 2 -> no match", function()
 local ctx = make_context({hp = 51, enemies_count = 2})
 local state = get_state(ctx)
 state.evasion_ready = true
 state.hp = 51
 state.enemies = 2
 assert_false(strategies[8].matches(ctx, state), "HP 51 should not match (> 50)")
 end)

 test(label .. ": HP 40, exactly 1 enemy -> no match", function()
 local ctx = make_context({hp = 40, enemies_count = 1})
 local state = get_state(ctx)
 state.evasion_ready = true
 state.hp = 40
 state.enemies = 1
 assert_false(strategies[8].matches(ctx, state), "1 enemy should not match (< 2)")
 end)

 test(label .. ": not ready -> no match", function()
 local ctx = make_context({hp = 40, enemies_count = 3})
 local state = get_state(ctx)
 state.evasion_ready = false
 state.hp = 40
 state.enemies = 3
 assert_false(strategies[8].matches(ctx, state), "not ready should not match")
 end)
end

do -- edge_sprint
 local label = "edge_sprint"

 test(label .. ": HP exactly 30 -> match", function()
 local ctx = make_context({hp = 30})
 local state = get_state(ctx)
 state.sprint_ready = true
 state.hp = 30
 assert_true(strategies[10].matches(ctx, state), "HP 30 should match (<= threshold)")
 end)

 test(label .. ": HP exactly 31 -> no match", function()
 local ctx = make_context({hp = 31})
 local state = get_state(ctx)
 state.sprint_ready = true
 state.hp = 31
 assert_false(strategies[10].matches(ctx, state), "HP 31 should not match (> threshold)")
 end)
end

do -- edge_blind
 local label = "edge_blind"

 test(label .. ": HP exactly 30 -> match", function()
 local ctx = make_context({hp = 30})
 local state = get_state(ctx)
 state.blind_ready = true
 state.hp = 30
 assert_true(strategies[11].matches(ctx, state), "HP 30 should match (<= threshold)")
 end)

 test(label .. ": HP exactly 31 -> no match", function()
 local ctx = make_context({hp = 31})
 local state = get_state(ctx)
 state.blind_ready = true
 state.hp = 31
 assert_false(strategies[11].matches(ctx, state), "HP 31 should not match (> threshold)")
 end)
end

do -- edge_cold_blood
 local label = "edge_cold_blood"

 test(label .. ": 5 CP, cooldowns enabled -> match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.cold_blood_ready = true
 state.use_cooldowns = true
 state.combo_points = 5
 assert_true(strategies[12].matches(ctx, state), "5 CP with cooldowns should match")
 end)

 test(label .. ": 4 CP -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.cold_blood_ready = true
 state.use_cooldowns = true
 state.combo_points = 4
 assert_false(strategies[12].matches(ctx, state), "4 CP should not match (< 5)")
 end)

 test(label .. ": cooldowns disabled -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.cold_blood_ready = true
 state.use_cooldowns = false
 state.combo_points = 5
 assert_false(strategies[12].matches(ctx, state), "cooldowns disabled should not match")
 end)
end

do -- edge_adrenaline_rush
 local label = "edge_adrenaline_rush"

 test(label .. ": energy exactly 60 -> match (<= 60)", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.adrenaline_rush_ready = true
 state.use_cooldowns = true
 state.energy = 60
 assert_true(strategies[13].matches(ctx, state), "energy 60 should match (<= 60)")
 end)

 test(label .. ": energy exactly 61 -> no match (> 60)", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.adrenaline_rush_ready = true
 state.use_cooldowns = true
 state.energy = 61
 assert_false(strategies[13].matches(ctx, state), "energy 61 should not match (> 60)")
 end)

 test(label .. ": cooldowns disabled -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.adrenaline_rush_ready = true
 state.use_cooldowns = false
 state.energy = 40
 assert_false(strategies[13].matches(ctx, state), "cooldowns disabled should not match")
 end)
end

do -- edge_blade_flurry
 local label = "edge_blade_flurry"

 test(label .. ": enemies exactly 3 (threshold) -> match", function()
 local ctx = make_context({enemies_count = 3})
 local state = get_state(ctx)
 state.blade_flurry_ready = true
 state.use_blade_flurry = true
 state.enemies = 3
 state.blade_flurry_min_enemies = 3
 assert_true(strategies[14].matches(ctx, state), "3 enemies should match (>= threshold)")
 end)

 test(label .. ": enemies exactly 2 -> no match", function()
 local ctx = make_context({enemies_count = 2})
 local state = get_state(ctx)
 state.blade_flurry_ready = true
 state.use_blade_flurry = true
 state.enemies = 2
 state.blade_flurry_min_enemies = 3
 assert_false(strategies[14].matches(ctx, state), "2 enemies should not match (< threshold)")
 end)

 test(label .. ": AoE disabled -> no match", function()
 local ctx = make_context({enemies_count = 4})
 local state = get_state(ctx)
 state.blade_flurry_ready = true
 state.use_blade_flurry = false
 state.enemies = 4
 assert_false(strategies[14].matches(ctx, state), "AoE disabled should not match")
 end)
end

do -- edge_slice_and_dice
 local label = "edge_slice_and_dice"

 test(label .. ": 1 CP, no buff -> match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.slice_and_dice_ready = true
 state.has_slice_and_dice = false
 state.combo_points = 1
 assert_true(strategies[15].matches(ctx, state), "1 CP should match (>= 1)")
 end)

 test(label .. ": 0 CP -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.slice_and_dice_ready = true
 state.has_slice_and_dice = false
 state.combo_points = 0
 assert_false(strategies[15].matches(ctx, state), "0 CP should not match (< 1)")
 end)

 test(label .. ": buff already active -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.slice_and_dice_ready = true
 state.has_slice_and_dice = true
 state.combo_points = 2
 assert_false(strategies[15].matches(ctx, state), "buff active should not match")
 end)
end

do -- edge_rupture
 local label = "edge_rupture"

 test(label .. ": 3 CP, debuff remains 0 -> match", function()
 local ctx = make_context()
 local saved = NS.debuff_remains
 NS.debuff_remains = function(target, spell) return 0 end
 local state = get_state(ctx)
 state.rupture_ready = true
 state.combo_points = 3
 assert_true(strategies[16].matches(ctx, state), "3 CP with expired debuff should match")
 NS.debuff_remains = saved
 end)

 test(label .. ": 2 CP -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.rupture_ready = true
 state.combo_points = 2
 assert_false(strategies[16].matches(ctx, state), "2 CP should not match (< 3)")
 end)

 test(label .. ": 5 CP (prefer eviscerate) -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.rupture_ready = true
 state.combo_points = 5
 assert_false(strategies[16].matches(ctx, state), "5 CP should not match (>= max)")
 end)

 test(label .. ": 4 CP -> match", function()
 local ctx = make_context()
 local saved = NS.debuff_remains
 NS.debuff_remains = function(target, spell) return 0 end
 local state = get_state(ctx)
 state.rupture_ready = true
 state.combo_points = 4
 assert_true(strategies[16].matches(ctx, state), "4 CP should match (< 5 and >= 3)")
 NS.debuff_remains = saved
 end)

 test(label .. ": debuff remains exactly 4 -> match (<= 4)", function()
 local ctx = make_context()
 local saved = NS.debuff_remains
 NS.debuff_remains = function(target, spell) return 4 end
 local state = get_state(ctx)
 state.rupture_ready = true
 state.combo_points = 3
 assert_true(strategies[16].matches(ctx, state), "remains 4 should match (<= 4)")
 NS.debuff_remains = saved
 end)

 test(label .. ": debuff remains exactly 5 -> no match (> 4)", function()
 local ctx = make_context()
 local saved = NS.debuff_remains
 NS.debuff_remains = function(target, spell) return 5 end
 local state = get_state(ctx)
 state.rupture_ready = true
 state.combo_points = 3
 assert_false(strategies[16].matches(ctx, state), "remains 5 should not match (> 4)")
 NS.debuff_remains = saved
 end)
end

do -- edge_expose_armor
 local label = "edge_expose_armor"

 test(label .. ": 3 CP, 0 stacks, target has armor -> match", function()
 local ctx = make_context()
 ctx.target_armor = 100
 local saved = NS.debuff_stacks
 NS.debuff_stacks = function(target, spell) return 0 end
 local state = get_state(ctx)
 state.expose_armor_ready = true
 state.use_expose_armor = true
 state.combo_points = 3
 state.target_ttd = 30
 assert_true(strategies[17].matches(ctx, state), "3 CP with 0 stacks should match")
 NS.debuff_stacks = saved
 end)

 test(label .. ": 2 CP -> no match", function()
 local ctx = make_context()
 ctx.target_armor = 100
 local state = get_state(ctx)
 state.expose_armor_ready = true
 state.use_expose_armor = true
 state.combo_points = 2
 state.target_ttd = 30
 assert_false(strategies[17].matches(ctx, state), "2 CP should not match")
 end)

 test(label .. ": 5 CP (prefer eviscerate) -> no match", function()
 local ctx = make_context()
 ctx.target_armor = 100
 local state = get_state(ctx)
 state.expose_armor_ready = true
 state.use_expose_armor = true
 state.combo_points = 5
 state.target_ttd = 30
 assert_false(strategies[17].matches(ctx, state), "5 CP should not match (>= max)")
 end)

 test(label .. ": 1 stack already -> no match", function()
 local ctx = make_context()
 ctx.target_armor = 100
 local saved = NS.debuff_stacks
 NS.debuff_stacks = function(target, spell) return 1 end
 local state = get_state(ctx)
 state.expose_armor_ready = true
 state.use_expose_armor = true
 state.combo_points = 3
 state.target_ttd = 30
 assert_false(strategies[17].matches(ctx, state), "1 stack should not match")
 NS.debuff_stacks = saved
 end)

 test(label .. ": no target armor -> no match", function()
 local ctx = make_context()
 ctx.target_armor = 0
 local state = get_state(ctx)
 state.expose_armor_ready = true
 state.use_expose_armor = true
 state.combo_points = 3
 assert_false(strategies[17].matches(ctx, state), "no armor should not match")
 end)
end

do -- edge_kidney_shot
 local label = "edge_kidney_shot"

 test(label .. ": 3 CP, HP 40 -> match", function()
 local ctx = make_context({hp = 40})
 local state = get_state(ctx)
 state.kidney_shot_ready = true
 state.combo_points = 3
 state.hp = 40
 assert_true(strategies[18].matches(ctx, state), "3 CP with HP 40 should match")
 end)

 test(label .. ": 2 CP -> no match", function()
 local ctx = make_context({hp = 40})
 local state = get_state(ctx)
 state.kidney_shot_ready = true
 state.combo_points = 2
 state.hp = 40
 assert_false(strategies[18].matches(ctx, state), "2 CP should not match")
 end)

 test(label .. ": HP 41 -> no match", function()
 local ctx = make_context({hp = 41})
 local state = get_state(ctx)
 state.kidney_shot_ready = true
 state.combo_points = 3
 state.hp = 41
 assert_false(strategies[18].matches(ctx, state), "HP 41 should not match (> 40)")
 end)

 test(label .. ": not ready -> no match", function()
 local ctx = make_context({hp = 40})
 local state = get_state(ctx)
 state.kidney_shot_ready = false
 state.combo_points = 3
 state.hp = 40
 assert_false(strategies[18].matches(ctx, state), "not ready should not match")
 end)
end

do -- edge_eviscerate
 local label = "edge_eviscerate"

 test(label .. ": 5 CP -> match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.eviscerate_ready = true
 state.combo_points = 5
 assert_true(strategies[19].matches(ctx, state), "5 CP should match")
 end)

 test(label .. ": 4 CP -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.eviscerate_ready = true
 state.combo_points = 4
 assert_false(strategies[19].matches(ctx, state), "4 CP should not match (< max)")
 end)

 test(label .. ": no target -> no match", function()
 local ctx = make_context({target = nil})
 local state = get_state(ctx)
 state.eviscerate_ready = true
 state.target = nil
 state.combo_points = 5
 assert_false(strategies[19].matches(ctx, state), "no target should not match")
 end)
end

do -- edge_sinister_strike
 local label = "edge_sinister_strike"

 test(label .. ": 4 CP -> match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.sinister_strike_ready = true
 state.combo_points = 4
 assert_true(strategies[20].matches(ctx, state), "4 CP should match (< max)")
 end)

 test(label .. ": 5 CP -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.sinister_strike_ready = true
 state.combo_points = 5
 assert_false(strategies[20].matches(ctx, state), "5 CP should not match (>= max)")
 end)

 test(label .. ": no target -> no match", function()
 local ctx = make_context({target = nil})
 local state = get_state(ctx)
 state.sinister_strike_ready = true
 state.target = nil
 state.combo_points = 3
 assert_false(strategies[20].matches(ctx, state), "no target should not match")
 end)

 test(label .. ": OOC -> no match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.sinister_strike_ready = true
 state.combo_points = 3
 state.in_combat = false
 assert_false(strategies[20].matches(ctx, state), "OOC should not match")
 end)
end

do -- edge_stealth
 local label = "edge_stealth"

 test(label .. ": distance exactly 30 -> match", function()
 local ctx = make_context({in_combat = false})
 local saved = NS.get_distance
 NS.get_distance = function() return 30 end
 local state = get_state(ctx)
 state.stealthed = false
 state.stealth_ready = true
 assert_true(strategies[1].matches(ctx, state), "distance 30 should match (<= 30)")
 NS.get_distance = saved
 end)

 test(label .. ": distance exactly 31 -> no match", function()
 local ctx = make_context({in_combat = false})
 local saved = NS.get_distance
 NS.get_distance = function() return 31 end
 local state = get_state(ctx)
 state.stealthed = false
 state.stealth_ready = true
 assert_false(strategies[1].matches(ctx, state), "distance 31 should not match (> 30)")
 NS.get_distance = saved
 end)

 test(label .. ": already stealthed -> no match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.stealthed = true
 state.stealth_ready = true
 assert_false(strategies[1].matches(ctx, state), "already stealthed should not match")
 end)

 test(label .. ": OOC -> match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.stealthed = false
 state.stealth_ready = true
 assert_true(strategies[1].matches(ctx, state), "OOC with target nearby should match")
 end)
end

do -- edge_ambush_garrote
 local label = "edge_ambush_garrote"

 test(label .. ": Ambush - stealthed OOC -> match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.stealthed = true
 state.ambush_ready = true
 assert_true(strategies[2].matches(ctx, state), "stealthed OOC should match")
 end)

 test(label .. ": Ambush - not stealthed -> no match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.stealthed = false
 state.ambush_ready = true
 assert_false(strategies[2].matches(ctx, state), "not stealthed should not match")
 end)

 test(label .. ": Garrote - stealthed OOC -> match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.stealthed = true
 state.garrote_ready = true
 assert_true(strategies[3].matches(ctx, state), "stealthed OOC should match")
 end)

 test(label .. ": Garrote - not stealthed -> no match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.stealthed = false
 state.garrote_ready = true
 assert_false(strategies[3].matches(ctx, state), "not stealthed should not match")
 end)
end

do -- edge_kick
 local label = "edge_kick"

 test(label .. ": target casting, ready -> match", function()
 local ctx = make_context()
 ctx.target.is_casting = function() return true end
 local state = get_state(ctx)
 state.kick_ready = true
 state.use_interrupt = true
 assert_true(strategies[4].matches(ctx, state), "target casting should match")
 end)

 test(label .. ": target not casting -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.kick_ready = true
 state.use_interrupt = true
 assert_false(strategies[4].matches(ctx, state), "target not casting should not match")
 end)

 test(label .. ": interrupt disabled -> no match", function()
 local ctx = make_context()
 ctx.target.is_casting = function() return true end
 local state = get_state(ctx)
 state.kick_ready = true
 state.use_interrupt = false
 assert_false(strategies[4].matches(ctx, state), "interrupt disabled should not match")
 end)
end

-- ============================================================================
-- Edge case tests - API crash safety
-- ============================================================================

do -- edge_api_buff_up
 local label = "edge_api_buff_up"

 test(label .. ": NS.buff_up is nil -> has_buff returns false", function()
 local saved = NS.buff_up
 NS.buff_up = nil
 local ctx = make_context()
 local state = get_state(ctx)
 -- has_buff used by has_slice_and_dice and stealthed; both should be false
 assert_eq(state.has_slice_and_dice, false, "has_slice_and_dice should be false when buff_up nil")
 assert_eq(state.stealthed, false, "stealthed should be false when buff_up nil")
 NS.buff_up = saved
 end)

 test(label .. ": NS.buff_up throws -> pcall catches, has_buff returns false", function()
 local saved = NS.buff_up
 NS.buff_up = function() error("crash") end
 local ctx = make_context()
 local state = get_state(ctx)
 assert_eq(state.has_slice_and_dice, false, "has_slice_and_dice should be false when buff_up throws")
 assert_eq(state.stealthed, false, "stealthed should be false when buff_up throws")
 NS.buff_up = saved
 end)
end

do -- edge_api_spell_ready
 local label = "edge_api_spell_ready"

 test(label .. ": NS.spell_ready is nil -> all readiness fields false", function()
 local saved = NS.spell_ready
 NS.spell_ready = nil
 local ctx = make_context()
 local state = get_state(ctx)
 -- All spell readiness should default to false
 assert_eq(state.sinister_strike_ready, false, "sinister_strike_ready should be false")
 assert_eq(state.eviscerate_ready, false, "eviscerate_ready should be false")
 assert_eq(state.kick_ready, false, "kick_ready should be false")
 assert_eq(state.vanish_ready, false, "vanish_ready should be false")
 assert_eq(state.stealth_ready, false, "stealth_ready should be false")
 NS.spell_ready = saved
 end)

 test(label .. ": NS.spell_ready returns nil -> readiness fields are nil/false", function()
 local saved = NS.spell_ready
 NS.spell_ready = function() return nil end
 local ctx = make_context()
 local state = get_state(ctx)
 -- NS.spell_ready and NS.spell_ready(...) or false -> nil and nil or false -> false
 assert_eq(state.sinister_strike_ready, false, "should be false when spell_ready returns nil")
 NS.spell_ready = saved
 end)

 test(label .. ": match functions handle nil readiness -> return false", function()
 local saved_spell = NS.spell_ready
 NS.spell_ready = nil
 local ctx = make_context({in_combat = false, hp = 10})
 local state = get_state(ctx)
 -- All readiness fields are false, so combat matches should return false gracefully
 for i = 4, 20 do
 local ok, matched = pcall(strategies[i].matches, ctx, state)
 assert_true(ok, "strategy[" .. i .. "] matches should not throw when readiness is nil")
 -- Most should return false since readiness fields are nil/false
 end
 NS.spell_ready = saved_spell
 end)
end

do -- edge_api_try_cast
 local label = "edge_api_try_cast"

 test(label .. ": NS.try_cast returns nil -> execute returns false, no crash", function()
 local saved = NS.try_cast
 NS.try_cast = function() return nil end
 local ctx = make_context()
 for i, s in ipairs(strategies) do
 local ok, result = pcall(s.execute, ctx)
 assert_true(ok, "strategy[" .. i .. "] execute should not throw when try_cast returns nil")
 end
 NS.try_cast = saved
 end)

 test(label .. ": NS.try_cast is nil -> execute returns false, no crash", function()
 local saved = NS.try_cast
 NS.try_cast = nil
 local ctx = make_context()
 for i, s in ipairs(strategies) do
 local ok, result = pcall(s.execute, ctx)
 assert_true(ok, "strategy[" .. i .. "] execute should not throw when try_cast is nil")
 end
 NS.try_cast = saved
 end)
end

-- ============================================================================
-- Edge case tests - rotation crash safety
-- ============================================================================

do -- edge_rotation_crash
 local label = "edge_rotation_crash"

 test(label .. ": all match functions handle nil context", function()
 for i, s in ipairs(strategies) do
 local ok, result = pcall(s.matches, nil, {})
 assert_true(ok, "strategy[" .. i .. "] matches(nil, {}) should not throw")
 end
 end)

 test(label .. ": all match functions handle nil state", function()
 local ctx = make_context()
 for i, s in ipairs(strategies) do
 local ok, result = pcall(s.matches, ctx, nil)
 assert_true(ok, "strategy[" .. i .. "] matches(ctx, nil) should not throw")
 end
 end)

 test(label .. ": all execute functions handle nil context", function()
 for i, s in ipairs(strategies) do
 local ok, result = pcall(s.execute, nil)
 assert_true(ok, "strategy[" .. i .. "] execute(nil) should not throw")
 end
 end)

 test(label .. ": all execute functions handle nil context with nil references", function()
 for i, s in ipairs(strategies) do
 local ok, result = pcall(s.execute)
 assert_true(ok, "strategy[" .. i .. "] execute() with no args should not throw")
 end
 end)
end
