-- _paladin_edge_insert.lua -- Paladin edge-case insert tests.
-- WHAT:  Paladin edge-case insert tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Explores edge cases and internal logic paths not covered by standard suites.
-- SAFETY: Ad-hoc tests; may be run manually during deep debugging.

-- ============================================================================
-- Edge case tests - boundary values
-- ============================================================================

do -- edge_flash_light
 local label = "edge_flash_light"

 test(label .. ": HP exactly 60 -> match", function()
 local ctx = make_context({hp = 60})
 local state = get_state(ctx)
 state.flash_light_ready = true
 state.hp = 60
 assert_true(strategies[7].matches(ctx, state), "HP 60 should match (<= threshold)")
 end)

 test(label .. ": HP exactly 61 -> no match", function()
 local ctx = make_context({hp = 61})
 local state = get_state(ctx)
 state.flash_light_ready = true
 state.hp = 61
 assert_false(strategies[7].matches(ctx, state), "HP 61 should not match (> threshold)")
 end)
end

do -- edge_holy_light
 local label = "edge_holy_light"

 test(label .. ": HP exactly 35 -> match", function()
 local ctx = make_context({hp = 35})
 local state = get_state(ctx)
 state.holy_light_ready = true
 state.hp = 35
 assert_true(strategies[8].matches(ctx, state), "HP 35 should match (<= threshold)")
 end)

 test(label .. ": HP exactly 36 -> no match", function()
 local ctx = make_context({hp = 36})
 local state = get_state(ctx)
 state.holy_light_ready = true
 state.hp = 36
 assert_false(strategies[8].matches(ctx, state), "HP 36 should not match (> threshold)")
 end)
end

do -- edge_divine_shield
 local label = "edge_divine_shield"

 test(label .. ": HP exactly 20 -> match", function()
 local ctx = make_context({hp = 20})
 local state = get_state(ctx)
 state.divine_shield_ready = true
 state.hp = 20
 assert_true(strategies[9].matches(ctx, state), "HP 20 should match (<= threshold)")
 end)

 test(label .. ": HP exactly 21 -> no match", function()
 local ctx = make_context({hp = 21})
 local state = get_state(ctx)
 state.divine_shield_ready = true
 state.hp = 21
 assert_false(strategies[9].matches(ctx, state), "HP 21 should not match (> threshold)")
 end)
end

do -- edge_lay_on_hands
 local label = "edge_lay_on_hands"

 test(label .. ": HP exactly 15 -> match", function()
 local ctx = make_context({hp = 15})
 local state = get_state(ctx)
 state.lay_on_hands_ready = true
 state.hp = 15
 assert_true(strategies[10].matches(ctx, state), "HP 15 should match (<= threshold)")
 end)

 test(label .. ": HP exactly 16 -> no match", function()
 local ctx = make_context({hp = 16})
 local state = get_state(ctx)
 state.lay_on_hands_ready = true
 state.hp = 16
 assert_false(strategies[10].matches(ctx, state), "HP 16 should not match (> threshold)")
 end)
end

do -- edge_hammer_justice
 local label = "edge_hammer_justice"

 test(label .. ": enemies exactly 2 -> match", function()
 local ctx = make_context({enemies_count = 2})
 local state = get_state(ctx)
 state.hammer_justice_ready = true
 state.enemies = 2
 assert_true(strategies[11].matches(ctx, state), "2 enemies should match (>= threshold)")
 end)

 test(label .. ": exactly 1 enemy -> no match", function()
 local ctx = make_context({enemies_count = 1})
 local state = get_state(ctx)
 state.hammer_justice_ready = true
 state.enemies = 1
 assert_false(strategies[11].matches(ctx, state), "1 enemy should not match (< threshold)")
 end)
end

do -- edge_hammer_wrath
 local label = "edge_hammer_wrath"

 test(label .. ": target HP exactly 20 -> match", function()
 local ctx = make_context()
 ctx.target.get_health_percentage = function() return 20 end
 local state = get_state(ctx)
 state.hammer_wrath_ready = true
 assert_true(strategies[13].matches(ctx, state), "target HP 20 should match (<= threshold)")
 end)

 test(label .. ": target HP exactly 21 -> no match", function()
 local ctx = make_context()
 ctx.target.get_health_percentage = function() return 21 end
 local state = get_state(ctx)
 state.hammer_wrath_ready = true
 assert_false(strategies[13].matches(ctx, state), "target HP 21 should not match (> threshold)")
 end)

 test(label .. ": not ready -> no match", function()
 local ctx = make_context()
 ctx.target.get_health_percentage = function() return 15 end
 local state = get_state(ctx)
 state.hammer_wrath_ready = false
 assert_false(strategies[13].matches(ctx, state), "not ready should not match")
 end)
end

do -- edge_consecration
 local label = "edge_consecration"

 test(label .. ": enemies exactly 2, not moving -> match", function()
 local ctx = make_context({enemies_count = 2, is_moving = false})
 local state = get_state(ctx)
 state.consecration_ready = true
 state.enemies = 2
 state.is_moving = false
 assert_true(strategies[16].matches(ctx, state), "2 enemies not moving should match")
 end)

 test(label .. ": exactly 1 enemy -> no match", function()
 local ctx = make_context({enemies_count = 1})
 local state = get_state(ctx)
 state.consecration_ready = true
 state.enemies = 1
 assert_false(strategies[16].matches(ctx, state), "1 enemy should not match")
 end)

 test(label .. ": moving -> no match", function()
 local ctx = make_context({enemies_count = 3, is_moving = true})
 local state = get_state(ctx)
 state.consecration_ready = true
 state.enemies = 3
 state.is_moving = true
 assert_false(strategies[16].matches(ctx, state), "moving should not match")
 end)
end

do -- edge_blessings
 local label = "edge_blessings"

 test(label .. ": BlessingMight OOC, no buff, ready -> match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.has_blessing_might = false
 state.blessing_might_ready = true
 assert_true(strategies[1].matches(ctx, state), "OOC no buff should match")
 end)

 test(label .. ": BlessingMight already has buff -> no match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.has_blessing_might = true
 state.blessing_might_ready = true
 assert_false(strategies[1].matches(ctx, state), "buff active should not match")
 end)

 test(label .. ": BlessingWisdom OOC, no buff, ready -> match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.has_blessing_wisdom = false
 state.blessing_wisdom_ready = true
 assert_true(strategies[2].matches(ctx, state), "OOC no buff should match")
 end)
end

do -- edge_auras
 local label = "edge_auras"

 test(label .. ": DevotionAura OOC, no buff, ready -> match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.has_devotion_aura = false
 state.devotion_aura_ready = true
 assert_true(strategies[4].matches(ctx, state), "OOC no buff should match")
 end)

 test(label .. ": DevotionAura already has buff -> no match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.has_devotion_aura = true
 state.devotion_aura_ready = true
 assert_false(strategies[4].matches(ctx, state), "buff active should not match")
 end)

 test(label .. ": RetributionAura OOC, no buff, ready -> match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.has_retribution_aura = false
 state.retribution_aura_ready = true
 assert_true(strategies[3].matches(ctx, state), "OOC no buff should match")
 end)
end

do -- edge_holy_shield
 local label = "edge_holy_shield"

 test(label .. ": in combat, no buff, ready -> match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.has_holy_shield = false
 state.holy_shield_ready = true
 assert_true(strategies[5].matches(ctx, state), "in combat without buff should match")
 end)

 test(label .. ": already has buff -> no match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.has_holy_shield = true
 state.holy_shield_ready = true
 assert_false(strategies[5].matches(ctx, state), "buff active should not match")
 end)

 test(label .. ": OOC -> no match", function()
 local ctx = make_context({in_combat = false})
 local state = get_state(ctx)
 state.has_holy_shield = false
 state.holy_shield_ready = true
 assert_false(strategies[5].matches(ctx, state), "OOC should not match")
 end)
end

do -- edge_exorcism
 local label = "edge_exorcism"

 test(label .. ": target is demon, not moving -> match", function()
 local ctx = make_context()
 ctx.target.get_creature_type = function() return 3 end -- demon
 local state = get_state(ctx)
 state.exorcism_ready = true
 state.is_moving = false
 assert_true(strategies[15].matches(ctx, state), "demon target should match")
 end)

 test(label .. ": target is undead, not moving -> match", function()
 local ctx = make_context()
 ctx.target.get_creature_type = function() return 6 end -- undead
 local state = get_state(ctx)
 state.exorcism_ready = true
 state.is_moving = false
 assert_true(strategies[15].matches(ctx, state), "undead target should match")
 end)

 test(label .. ": target is humanoid -> no match", function()
 local ctx = make_context()
 ctx.target.get_creature_type = function() return 7 end -- humanoid
 local state = get_state(ctx)
 state.exorcism_ready = true
 state.is_moving = false
 assert_false(strategies[15].matches(ctx, state), "humanoid target should not match")
 end)

 test(label .. ": moving -> no match", function()
 local ctx = make_context({is_moving = true})
 ctx.target.get_creature_type = function() return 3 end -- demon
 local state = get_state(ctx)
 state.exorcism_ready = true
 state.is_moving = true
 assert_false(strategies[15].matches(ctx, state), "moving should not match")
 end)
end

do -- edge_judgement_crusader
 local label = "edge_judgement_crusader"

 test(label .. ": Judgement in combat, target, ready -> match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.judgement_ready = true
 assert_true(strategies[12].matches(ctx, state), "in combat should match")
 end)

 test(label .. ": CrusaderStrike in combat, target, ready -> match", function()
 local ctx = make_context()
 local state = get_state(ctx)
 state.crusader_strike_ready = true
 assert_true(strategies[14].matches(ctx, state), "in combat should match")
 end)
end

-- ============================================================================
-- Edge case tests - API crash safety
-- ============================================================================

do -- edge_api_buff
 local label = "edge_api_buff"

 test(label .. ": NS.buff_up is nil -> safe_buff_up returns false", function()
 local saved = NS.buff_up
 NS.buff_up = nil
 local ctx = make_context()
 local state = get_state(ctx)
 -- Buff states depend on buff_up, should be false when nil
 assert_eq(state.has_blessing_might, false, "buff nil should give false")
 assert_eq(state.has_blessing_wisdom, false, "buff nil should give false")
 assert_eq(state.has_devotion_aura, false, "buff nil should give false")
 assert_eq(state.has_holy_shield, false, "buff nil should give false")
 NS.buff_up = saved
 end)

 test(label .. ": NS.buff_up throws -> pcall catches, returns false", function()
 local saved = NS.buff_up
 NS.buff_up = function() error("crash") end
 local ctx = make_context()
 local state = get_state(ctx)
 assert_eq(state.has_blessing_might, false, "buff_up throws should give false")
 assert_eq(state.has_holy_shield, false, "buff_up throws should give false")
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
 assert_eq(state.judgement_ready, false, "judgement_ready should be false")
 assert_eq(state.hammer_wrath_ready, false, "hammer_wrath_ready should be false")
 assert_eq(state.crusader_strike_ready, false, "crusader_strike_ready should be false")
 assert_eq(state.flash_light_ready, false, "flash_light_ready should be false")
 assert_eq(state.holy_light_ready, false, "holy_light_ready should be false")
 NS.spell_ready = saved
 end)

 test(label .. ": NS.spell_ready returns nil -> readiness fields false", function()
 local saved = NS.spell_ready
 NS.spell_ready = function() return nil end
 local ctx = make_context()
 local state = get_state(ctx)
 assert_eq(state.judgement_ready, false, "should be false when spell_ready returns nil")
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
