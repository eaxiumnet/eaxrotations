-- _warrior_edge_insert.lua -- Warrior edge-case insert tests.
-- WHAT:  Warrior edge-case insert tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Explores edge cases and internal logic paths not covered by standard suites.
-- SAFETY: Ad-hoc tests; may be run manually during deep debugging.

-- ============================================================================
-- Edge case tests - boundary values
-- ============================================================================

do -- edge_bloodrage
 local label = "edge_bloodrage"

 test(label .. ": rage exactly 20 -> match", function()
 local saved = mock_player.get_power
 mock_player.get_power = function() return 20 end
 local ctx = make_context()
 local state = get_state(ctx)
 state.bloodrage_ready = true
 assert_true(strategies[6].matches(ctx, state), "rage 20 should match (<= threshold)")
 mock_player.get_power = saved
 end)

 test(label .. ": rage exactly 21 -> no match", function()
 local saved = mock_player.get_power
 mock_player.get_power = function() return 21 end
 local ctx = make_context()
 local state = get_state(ctx)
 state.bloodrage_ready = true
 assert_false(strategies[6].matches(ctx, state), "rage 21 should not match (> threshold)")
 mock_player.get_power = saved
 end)
end

do -- edge_execute
 local label = "edge_execute"

 test(label .. ": target HP exactly 20 -> match", function()
 local ctx = make_context()
 ctx.target.get_health_percentage = function() return 20 end
 local state = get_state(ctx)
 state.execute_ready = true
 state.use_execute = true
 state.exec_hp = 20
 assert_true(strategies[11].matches(ctx, state), "target HP 20 should match (<= threshold)")
 end)

 test(label .. ": target HP exactly 21 -> no match", function()
 local ctx = make_context()
 ctx.target.get_health_percentage = function() return 21 end
 local state = get_state(ctx)
 state.execute_ready = true
 state.use_execute = true
 state.exec_hp = 20
 assert_false(strategies[11].matches(ctx, state), "target HP 21 should not match (> threshold)")
 end)

 test(label .. ": execute disabled -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.execute_ready = true
 state.use_execute = false
 state.exec_hp = 20
 assert_false(strategies[11].matches(ctx, state), "disabled should not match")
 end)
end

do -- edge_sweeping_strikes
 local label = "edge_sweeping_strikes"

 test(label .. ": enemies exactly 2 -> match", function()
 local ctx = make_context({enemies_count = 2})
 local state = get_state(ctx)
 state.sweeping_strikes_ready = true
 state.enemies = 2
 assert_true(strategies[15].matches(ctx, state), "2 enemies should match (>= 2)")
 end)

 test(label .. ": exactly 1 enemy -> no match", function()
 local ctx = make_context({enemies_count = 1})
 local state = get_state(ctx)
 state.sweeping_strikes_ready = true
 state.enemies = 1
 assert_false(strategies[15].matches(ctx, state), "1 enemy should not match (< 2)")
 end)
end

do -- edge_cleave
 local label = "edge_cleave"

 test(label .. ": enemies exactly 2, rage 25 -> match", function()
 local saved = mock_player.get_power
 mock_player.get_power = function() return 25 end
 local ctx = make_context({enemies_count = 2})
 local state = get_state(ctx)
 state.cleave_ready = true
 state.enemies = 2
 assert_true(strategies[16].matches(ctx, state), "2 enemies with rage 25 should match")
 mock_player.get_power = saved
 end)

 test(label .. ": enemies exactly 2, rage 24 -> no match", function()
 local saved = mock_player.get_power
 mock_player.get_power = function() return 24 end
 local ctx = make_context({enemies_count = 2})
 local state = get_state(ctx)
 state.cleave_ready = true
 state.enemies = 2
 assert_false(strategies[16].matches(ctx, state), "2 enemies with rage 24 should not match")
 mock_player.get_power = saved
 end)

 test(label .. ": exactly 1 enemy -> no match", function()
 local ctx = make_context({enemies_count = 1})
 local state = get_state(ctx)
 state.cleave_ready = true
 state.enemies = 1
 assert_false(strategies[16].matches(ctx, state), "1 enemy should not match (< 2)")
 end)
end

do -- edge_whirlwind
 local label = "edge_whirlwind"

 test(label .. ": enemies exactly 3 -> match", function()
 local ctx = make_context({enemies_count = 3})
 local state = get_state(ctx)
 state.whirlwind_ready = true
 state.enemies = 3
 assert_true(strategies[17].matches(ctx, state), "3 enemies should match (>= 3)")
 end)

 test(label .. ": exactly 2 enemies -> no match", function()
 local ctx = make_context({enemies_count = 2})
 local state = get_state(ctx)
 state.whirlwind_ready = true
 state.enemies = 2
 assert_false(strategies[17].matches(ctx, state), "2 enemies should not match (< 3)")
 end)
end

do -- edge_thunder_clap
 local label = "edge_thunder_clap"

 test(label .. ": enemies exactly 2 -> match", function()
 local ctx = make_context({enemies_count = 2})
 local state = get_state(ctx)
 state.thunder_clap_ready = true
 state.use_thunder_clap = true
 state.enemies = 2
 assert_true(strategies[18].matches(ctx, state), "2 enemies should match (>= 2)")
 end)

 test(label .. ": exactly 1 enemy -> no match", function()
 local ctx = make_context({enemies_count = 1})
 local state = get_state(ctx)
 state.thunder_clap_ready = true
 state.use_thunder_clap = true
 state.enemies = 1
 assert_false(strategies[18].matches(ctx, state), "1 enemy should not match (< 2)")
 end)
end

do -- edge_rend
 local label = "edge_rend"

 test(label .. ": debuff remains exactly 4 -> match", function()
 local ctx = make_context()
 local saved = NS.debuff_remains
 NS.debuff_remains = function(target, spell) return 4 end
 local state = get_state(ctx)
 state.rend_ready = true
 state.use_rend = true
 assert_true(strategies[14].matches(ctx, state), "remains 4 should match (<= 4)")
 NS.debuff_remains = saved
 end)

 test(label .. ": debuff remains exactly 5 -> no match", function()
 local ctx = make_context()
 local saved = NS.debuff_remains
 NS.debuff_remains = function(target, spell) return 5 end
 local state = get_state(ctx)
 state.rend_ready = true
 state.use_rend = true
 assert_false(strategies[14].matches(ctx, state), "remains 5 should not match (> 4)")
 NS.debuff_remains = saved
 end)

 test(label .. ": rend disabled -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.rend_ready = true
 state.use_rend = false
 assert_false(strategies[14].matches(ctx, state), "disabled should not match")
 end)
end

do -- edge_rampage
 local label = "edge_rampage"

 test(label .. ": rage exactly 30, no buff -> match", function()
 local saved_power = mock_player.get_power
 local saved_buff = NS.buff_up
 mock_player.get_power = function() return 30 end
 NS.buff_up = function(unit, ids) return false end
 local ctx = make_context()
 local state = get_state(ctx)
 state.rampage_ready = true
 state.has_rampage = false
 state.rampage_remains = 0
 assert_true(strategies[20].matches(ctx, state), "rage 30 with no buff should match")
 mock_player.get_power = saved_power
 NS.buff_up = saved_buff
 end)

 test(label .. ": rage exactly 29 -> no match", function()
 local saved_power = mock_player.get_power
 mock_player.get_power = function() return 29 end
 local ctx = make_context()
 local state = get_state(ctx)
 state.rampage_ready = true
 state.has_rampage = false
 state.rampage_remains = 0
 assert_false(strategies[20].matches(ctx, state), "rage 29 should not match (< 30)")
 mock_player.get_power = saved_power
 end)

 test(label .. ": buff remains exactly 3 -> match (<= 3)", function()
 local saved_power = mock_player.get_power
 mock_player.get_power = function() return 100 end
 local saved_buff = NS.buff_up
 local saved_remains = NS.buff_remains
 NS.buff_up = function(unit, ids) return true end
 NS.buff_remains = function(unit, ids) return 3 end
 local ctx = make_context()
 local state = get_state(ctx)
 state.rampage_ready = true
 state.has_rampage = true
 state.rampage_remains = 3
 assert_true(strategies[20].matches(ctx, state), "remains 3 should match")
 mock_player.get_power = saved_power
 NS.buff_up = saved_buff
 NS.buff_remains = saved_remains
 end)

 test(label .. ": buff remains exactly 4 -> no match (> 3)", function()
 local saved_power = mock_player.get_power
 mock_player.get_power = function() return 100 end
 local saved_buff = NS.buff_up
 local saved_remains = NS.buff_remains
 NS.buff_up = function(unit, ids) return true end
 NS.buff_remains = function(unit, ids) return 4 end
 local ctx = make_context()
 local state = get_state(ctx)
 state.rampage_ready = true
 state.has_rampage = true
 state.rampage_remains = 4
 assert_false(strategies[20].matches(ctx, state), "remains 4 should not match (> 3)")
 mock_player.get_power = saved_power
 NS.buff_up = saved_buff
 NS.buff_remains = saved_remains
 end)
end

do -- edge_sunder_armor
 local label = "edge_sunder_armor"

 test(label .. ": 2 stacks, HP 40, rage 25, target has armor -> match", function()
 local saved_power = mock_player.get_power
 mock_player.get_power = function() return 25 end
 local saved_stacks = NS.debuff_stacks
 NS.debuff_stacks = function(target, spell) return 2 end
 local ctx = make_context()
 ctx.target_armor = 100
 ctx.target.get_health_percentage = function() return 40 end
 local state = get_state(ctx)
 state.sunder_armor_ready = true
 state.sunder_stacks = 2
 assert_true(strategies[24].matches(ctx, state), "2 stacks with HP 40 should match")
 mock_player.get_power = saved_power
 NS.debuff_stacks = saved_stacks
 end)

 test(label .. ": 3 stacks -> no match", function()
 local saved_power = mock_player.get_power
 mock_player.get_power = function() return 100 end
 local saved_stacks = NS.debuff_stacks
 NS.debuff_stacks = function(target, spell) return 3 end
 local ctx = make_context()
 ctx.target_armor = 100
 local state = get_state(ctx)
 state.sunder_armor_ready = true
 state.sunder_stacks = 3
 assert_false(strategies[24].matches(ctx, state), "3 stacks should not match (>= 3)")
 mock_player.get_power = saved_power
 NS.debuff_stacks = saved_stacks
 end)

 test(label .. ": target HP 39 -> no match", function()
 local saved_power = mock_player.get_power
 mock_player.get_power = function() return 100 end
 local saved_stacks = NS.debuff_stacks
 NS.debuff_stacks = function(target, spell) return 0 end
 local ctx = make_context()
 ctx.target_armor = 100
 ctx.target.get_health_percentage = function() return 39 end
 local state = get_state(ctx)
 state.sunder_armor_ready = true
 state.sunder_stacks = 0
 assert_false(strategies[24].matches(ctx, state), "HP 39 should not match (< 40)")
 mock_player.get_power = saved_power
 NS.debuff_stacks = saved_stacks
 end)

 test(label .. ": rage 24 -> no match", function()
 local saved_power = mock_player.get_power
 mock_player.get_power = function() return 24 end
 local saved_stacks = NS.debuff_stacks
 NS.debuff_stacks = function(target, spell) return 0 end
 local ctx = make_context()
 ctx.target_armor = 100
 ctx.target.get_health_percentage = function() return 60 end
 local state = get_state(ctx)
 state.sunder_armor_ready = true
 state.sunder_stacks = 0
 assert_false(strategies[24].matches(ctx, state), "rage 24 should not match (< 25)")
 mock_player.get_power = saved_power
 NS.debuff_stacks = saved_stacks
 end)
end

do -- edge_heroic_strike
 local label = "edge_heroic_strike"

 test(label .. ": rage exactly 50 -> match", function()
 local saved = mock_player.get_power
 mock_player.get_power = function() return 50 end
 local ctx = make_context()
 local state = get_state(ctx)
 state.heroic_strike_ready = true
 assert_true(strategies[25].matches(ctx, state), "rage 50 should match (>= 50)")
 mock_player.get_power = saved
 end)

 test(label .. ": rage exactly 49 -> no match", function()
 local saved = mock_player.get_power
 mock_player.get_power = function() return 49 end
 local ctx = make_context()
 local state = get_state(ctx)
 state.heroic_strike_ready = true
 assert_false(strategies[25].matches(ctx, state), "rage 49 should not match (< 50)")
 mock_player.get_power = saved
 end)
end

do -- edge_hamstring
 local label = "edge_hamstring"

 test(label .. ": target HP exactly 20 -> match", function()
 local ctx = make_context()
 ctx.target.get_health_percentage = function() return 20 end
 local state = get_state(ctx)
 state.hamstring_ready = true
 assert_true(strategies[21].matches(ctx, state), "target HP 20 should match (<= 20)")
 end)

 test(label .. ": target HP exactly 21 -> no match", function()
 local ctx = make_context()
 ctx.target.get_health_percentage = function() return 21 end
 local state = get_state(ctx)
 state.hamstring_ready = true
 assert_false(strategies[21].matches(ctx, state), "target HP 21 should not match (> 20)")
 end)
end

do -- edge_demo_shout
 local label = "edge_demo_shout"

 test(label .. ": enemies exactly 2 -> match", function()
 local ctx = make_context({enemies_count = 2})
 local state = get_state(ctx)
 state.demoralizing_shout_ready = true
 state.enemies = 2
 assert_true(strategies[19].matches(ctx, state), "2 enemies should match (>= 2)")
 end)

 test(label .. ": exactly 1 enemy -> no match", function()
 local ctx = make_context({enemies_count = 1})
 local state = get_state(ctx)
 state.demoralizing_shout_ready = true
 state.enemies = 1
 assert_false(strategies[19].matches(ctx, state), "1 enemy should not match (< 2)")
 end)
end

do -- edge_shield_wall
 local label = "edge_shield_wall"

 test(label .. ": HP exactly 20 -> match", function()
 local ctx = make_context({hp = 20})
 local state = get_state(ctx)
 state.shield_wall_ready = true
 state.hp = 20
 assert_true(strategies[9].matches(ctx, state), "HP 20 should match (<= 20)")
 end)

 test(label .. ": HP exactly 21 -> no match", function()
 local ctx = make_context({hp = 21})
 local state = get_state(ctx)
 state.shield_wall_ready = true
 state.hp = 21
 assert_false(strategies[9].matches(ctx, state), "HP 21 should not match (> 20)")
 end)
end

do -- edge_intimidating_shout
 local label = "edge_intimidating_shout"

 test(label .. ": enemies 3, HP 30 -> match", function()
 local ctx = make_context({hp = 30, enemies_count = 3})
 local state = get_state(ctx)
 state.intimidating_shout_ready = true
 state.hp = 30
 state.enemies = 3
 assert_true(strategies[13].matches(ctx, state), "3 enemies with HP 30 should match")
 end)

 test(label .. ": 2 enemies -> no match", function()
 local ctx = make_context({hp = 30, enemies_count = 2})
 local state = get_state(ctx)
 state.intimidating_shout_ready = true
 state.hp = 30
 state.enemies = 2
 assert_false(strategies[13].matches(ctx, state), "2 enemies should not match (< 3)")
 end)

 test(label .. ": HP 31 -> no match", function()
 local ctx = make_context({hp = 31, enemies_count = 3})
 local state = get_state(ctx)
 state.intimidating_shout_ready = true
 state.hp = 31
 state.enemies = 3
 assert_false(strategies[13].matches(ctx, state), "HP 31 should not match (> 30)")
 end)
end

do -- edge_berserker_rage
 local label = "edge_berserker_rage"

 test(label .. ": enemies exactly 2 -> match", function()
 local ctx = make_context({enemies_count = 2})
 local state = get_state(ctx)
 state.berserker_rage_ready = true
 state.enemies = 2
 assert_true(strategies[7].matches(ctx, state), "2 enemies should match (>= 2)")
 end)

 test(label .. ": exactly 1 enemy -> no match", function()
 local ctx = make_context({enemies_count = 1})
 local state = get_state(ctx)
 state.berserker_rage_ready = true
 state.enemies = 1
 assert_false(strategies[7].matches(ctx, state), "1 enemy should not match (< 2)")
 end)
end

do -- edge_charge
 local label = "edge_charge"

 test(label .. ": distance exactly 8 -> match", function()
 local ctx = make_context({in_combat = false})
 local saved = NS.get_distance
 NS.get_distance = function() return 8 end
 local state = get_state(ctx)
 state.charge_ready = true
 assert_true(strategies[5].matches(ctx, state), "distance 8 should match (>= 8)")
 NS.get_distance = saved
 end)

 test(label .. ": distance exactly 7 -> no match", function()
 local ctx = make_context({in_combat = false})
 local saved = NS.get_distance
 NS.get_distance = function() return 7 end
 local state = get_state(ctx)
 state.charge_ready = true
 assert_false(strategies[5].matches(ctx, state), "distance 7 should not match (< 8)")
 NS.get_distance = saved
 end)

 test(label .. ": distance exactly 25 -> match", function()
 local ctx = make_context({in_combat = false})
 local saved = NS.get_distance
 NS.get_distance = function() return 25 end
 local state = get_state(ctx)
 state.charge_ready = true
 assert_true(strategies[5].matches(ctx, state), "distance 25 should match (<= 25)")
 NS.get_distance = saved
 end)

 test(label .. ": distance exactly 26 -> no match", function()
 local ctx = make_context({in_combat = false})
 local saved = NS.get_distance
 NS.get_distance = function() return 26 end
 local state = get_state(ctx)
 state.charge_ready = true
 assert_false(strategies[5].matches(ctx, state), "distance 26 should not match (> 25)")
 NS.get_distance = saved
 end)

 test(label .. ": in combat -> no match", function()
 local ctx = make_context({in_combat = true})
 local state = get_state(ctx)
 state.charge_ready = true
 assert_false(strategies[5].matches(ctx, state), "in combat should not match")
 end)
end

do -- edge_battle_shout
 local label = "edge_battle_shout"

 test(label .. ": OOC, no buff, ready -> match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.battle_shout_ready = true
 state.has_battle_shout = false
 assert_true(strategies[1].matches(ctx, state), "OOC with no buff should match")
 end)

 test(label .. ": already has buff -> no match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.battle_shout_ready = true
 state.has_battle_shout = true
 assert_false(strategies[1].matches(ctx, state), "buff active should not match")
 end)

 test(label .. ": in combat -> no match", function()
 local ctx = make_context({in_combat = true})
 local state = get_state(ctx)
 state.battle_shout_ready = true
 state.has_battle_shout = false
 assert_false(strategies[1].matches(ctx, state), "in combat should not match")
 end)
end

do -- edge_pummel
 local label = "edge_pummel"

 test(label .. ": target casting, ready -> match", function()
 local ctx = make_context()
 ctx.target.is_casting = function() return true end
 local state = get_state(ctx)
 state.pummel_ready = true
 state.use_interrupt = true
 assert_true(strategies[2].matches(ctx, state), "target casting should match")
 end)

 test(label .. ": target not casting -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.pummel_ready = true
 state.use_interrupt = true
 assert_false(strategies[2].matches(ctx, state), "target not casting should not match")
 end)

 test(label .. ": interrupt disabled -> no match", function()
 local ctx = make_context()
 ctx.target.is_casting = function() return true end
 local state = get_state(ctx)
 state.pummel_ready = true
 state.use_interrupt = false
 assert_false(strategies[2].matches(ctx, state), "interrupt disabled should not match")
 end)
end

do -- edge_victory_rush
 local label = "edge_victory_rush"

 test(label .. ": ready, in combat -> match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.victory_rush_ready = true
 assert_true(strategies[8].matches(ctx, state), "ready in combat should match")
 end)

 test(label .. ": not ready -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.victory_rush_ready = false
 assert_false(strategies[8].matches(ctx, state), "not ready should not match")
 end)
end

do -- edge_overpower
 local label = "edge_overpower"

 test(label .. ": ready, in combat -> match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.overpower_ready = true
 assert_true(strategies[23].matches(ctx, state), "ready in combat should match")
 end)

 test(label .. ": not ready -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.overpower_ready = false
 assert_false(strategies[23].matches(ctx, state), "not ready should not match")
 end)
end

-- ============================================================================
-- Edge case tests - API crash safety
-- ============================================================================

do -- edge_api_buff
 local label = "edge_api_buff"

 test(label .. ": NS.buff_up is nil -> has_buff returns false", function()
 local saved = NS.buff_up
 NS.buff_up = nil
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 assert_eq(state.has_battle_shout, false, "has_battle_shout should be false when buff_up nil")
 assert_eq(state.has_rampage, false, "has_rampage should be false when buff_up nil")
 NS.buff_up = saved
 end)

 test(label .. ": NS.buff_up throws -> pcall catches, has_buff returns false", function()
 local saved = NS.buff_up
 NS.buff_up = function() error("crash") end
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 assert_eq(state.has_battle_shout, false, "has_battle_shout should be false when buff_up throws")
 assert_eq(state.has_rampage, false, "has_rampage should be false when buff_up throws")
 NS.buff_up = saved
 end)

 test(label .. ": NS.buff_remains is nil -> buff_remains returns 0", function()
 local saved = NS.buff_remains
 NS.buff_remains = nil
 local ctx = make_context()
 local state = get_state(ctx)
 assert_eq(state.rampage_remains, 0, "rampage_remains should be 0 when buff_remains nil")
 NS.buff_remains = saved
 end)

 test(label .. ": NS.buff_remains throws -> pcall catches, returns 0", function()
 local saved = NS.buff_remains
 NS.buff_remains = function() error("crash") end
 local ctx = make_context()
 local state = get_state(ctx)
 assert_eq(state.rampage_remains, 0, "rampage_remains should be 0 when buff_remains throws")
 NS.buff_remains = saved
 end)

 test(label .. ": NS.debuff_stacks nil -> debuff_stacks returns 0", function()
 local saved = NS.debuff_stacks
 NS.debuff_stacks = nil
 local ctx = make_context()
 local state = get_state(ctx)
 assert_eq(state.sunder_stacks, 0, "sunder_stacks should be 0 when debuff_stacks nil")
 NS.debuff_stacks = saved
 end)

 test(label .. ": NS.debuff_stacks throws -> pcall catches, returns 0", function()
 local saved = NS.debuff_stacks
 NS.debuff_stacks = function() error("crash") end
 local ctx = make_context()
 local state = get_state(ctx)
 assert_eq(state.sunder_stacks, 0, "sunder_stacks should be 0 when debuff_stacks throws")
 NS.debuff_stacks = saved
 end)
end

do -- edge_api_spell_ready
 local label = "edge_api_spell_ready"

 test(label .. ": NS.spell_ready is nil -> all readiness fields false", function()
 local saved = NS.spell_ready
 NS.spell_ready = nil
 local ctx = make_context()
 local state = get_state(ctx)
 assert_eq(state.charge_ready, false, "charge_ready should be false")
 assert_eq(state.execute_ready, false, "execute_ready should be false")
 assert_eq(state.heroic_strike_ready, false, "heroic_strike_ready should be false")
 assert_eq(state.pummel_ready, false, "pummel_ready should be false")
 assert_eq(state.overpower_ready, false, "overpower_ready should be false")
 NS.spell_ready = saved
 end)

 test(label .. ": NS.spell_ready returns nil -> readiness fields false", function()
 local saved = NS.spell_ready
 NS.spell_ready = function() return nil end
 local ctx = make_context()
 local state = get_state(ctx)
 assert_eq(state.charge_ready, false, "charge_ready should be false when spell_ready returns nil")
 NS.spell_ready = saved
 end)

 test(label .. ": match functions handle nil readiness -> no crash", function()
 local saved_spell = NS.spell_ready
 NS.spell_ready = nil
 local ctx = make_context()
 local state = get_state(ctx)
 for i = 1, #strategies do
 local ok, matched = pcall(strategies[i].matches, ctx, state)
 assert_true(ok, "strategy[" .. i .. "] matches should not throw when readiness is nil")
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

 test(label .. ": all execute functions handle no args", function()
 for i, s in ipairs(strategies) do
 local ok, result = pcall(s.execute)
 assert_true(ok, "strategy[" .. i .. "] execute() with no args should not throw")
 end
 end)
end
