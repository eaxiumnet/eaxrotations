-- Unit tests for BM Hunter parity features.
-- Tests: Raptor Strike melee weave, Concussive Shot range gate,
--  Volley/Trap AoE detection, and Trinket activation with cooldown check.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
 assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
 assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
 assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local action_calls = {}
_G.EaxRotations = {
 HunterSpells = {
  AspectOfTheHawk = 13165,
  AspectOfTheViper = 34074,
  ArcaneShot = 3044,
  SerpentSting = 1978,
  MendPet = 136,
  CallPet = 883,
  RevivePet = 0,
  KillCommand = 34026,
  SteadyShot = 34120,
  MultiShot = 25294,
  HuntersMark = 14325,
  BestialWrath = 19574,
  RapidFire = 3045,
  Readiness = 23989,
  FeignDeath = 5384,
  FreezingTrap = 1499,
  ExplosiveTrap = 13812,
  ViperSting = 3034,
  ScorpidSting = 14595,
 },
 action_matches = function(ctx, act)
  action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
  return true
 end,
 action_execute = function(ctx, act, prefix) return true end,
 spell_ready = function(spell, target, opts) return true end,
 spell_action = function(ids, name) return { name = name, ids = ids } end,
 buff_up = function(unit, buff_list) return false end,
 debuff_up = function(unit, debuff_list) return false end,
 try_cast = function(spell_id, target, prefix, opts) return true end,
 has_buff = function(unit, buff_id) return false end,
 is_spell_learned = function(spell_id) return true end,
 use_item_by_id = function(item_id, target) return true end,
 unit_mana_pct = function(unit) return 100 end,
 log = function() end,
 rotation_registry = {
  register = function() end,
 },
 GetPlayer = function() return {} end,
 GetFocus = function() return nil end,
}

-- Mock shared modules
package.preload["shared/hunter_core_sylvanas"] = function()
 return {
  get_pet = function() return { is_alive = function() return true end, get_health_percentage = function() return 100 end } end,
  pet_alive = function() return true end,
  pet_hp_pct = function() return 100 end,
  should_viper = function(mana_pct) return mana_pct < 20 end,
  should_hawk = function(mana_pct) return mana_pct >= 20 end,
  can_cast_instant = function(safety, buffer) return true end,
  can_cast_steady = function(buffer) return true end,
  should_feign_death = function(threat, mode) return false end,
  sting_remains = function(target, sting_type) return 0 end,
  record_mend = function() end,
  record_instant_shot = function() end,
  record_steady_start = function() end,
 }
end
package.preload["shared/targeting_sylvanas"] = function()
 return {}
end

local strategies = dofile("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua").strategies
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
 for i = 1, #strategies do
  if strategies[i].name == name then
   return strategies[i]
  end
 end
 error("strategy not found: " .. name)
end

-- Helper to create base context with me and target
local function make_context(overrides)
 local ctx = {
  me = {
   get_health_percentage = function() return 100 end,
   get_mana_percentage = function() return 100 end,
   get_item_cooldown = function(self, item_id)
    return 0, 0 -- start, duration (0 means ready)
   end,
  },
  target = { get_health_percentage = function() return 100 end },
  in_combat = true,
  is_mounted = false,
  is_moving = false,
  distance = 20,
  enemy_count = 1,
  mana_pct = 100,
  settings = {
   use_melee = true,
   use_volley = true,
   use_explosive_trap = true,
   aoe_threshold = 3,
   trinket_mode = "both",
   use_cooldowns = true,
  },
 }
 if overrides then
  for k, v in pairs(overrides) do
   if type(k) == "string" then
    ctx[k] = v
   end
  end
 end
 return ctx
end

-- ============================================================================
-- Raptor Strike: melee weaving within 6 yards
-- ============================================================================

local raptor = find_strategy("RaptorStrike")

-- Case 1: In combat, use_melee enabled, within 6y, ready -> should match
action_calls = {}
local ctx_r = make_context({ distance = 4, in_combat = true })
local s_r = {
 in_combat = true,
 use_melee = true,
 raptor_strike_ready = true,
 is_mounted = false,
}
assert_true(raptor.matches(ctx_r, s_r), "Raptor Strike should match at melee range")

-- Case 2: Out of melee range (> 6y) -> should NOT match
action_calls = {}
local ctx_r_far = make_context({ distance = 10, in_combat = true })
assert_false(raptor.matches(ctx_r_far, s_r), "Raptor Strike should not match at > 6y range")
assert_eq(#action_calls, 0, "action_matches should not be called for Raptor Strike out of range")

-- Case 3: use_melee disabled -> should NOT match
action_calls = {}
local ctx_r_melee_off = make_context({ distance = 4, in_combat = true, settings = { use_melee = false, aoe_threshold = 3, trinket_mode = "off", use_cooldowns = true } })
local s_r_melee_off = {
 in_combat = true,
 use_melee = false,
 raptor_strike_ready = true,
 is_mounted = false,
}
assert_false(raptor.matches(ctx_r_melee_off, s_r_melee_off), "Raptor Strike should not match when use_melee is false")
assert_eq(#action_calls, 0, "action_matches should not be called for Raptor Strike when melee disabled")

-- Case 4: Out of combat -> should NOT match
action_calls = {}
local ctx_r_ooc = make_context({ distance = 4, in_combat = false })
local s_r_ooc = {
 in_combat = false,
 use_melee = true,
 raptor_strike_ready = true,
 is_mounted = false,
}
assert_false(raptor.matches(ctx_r_ooc, s_r_ooc), "Raptor Strike should not match when OOC")
assert_eq(#action_calls, 0, "action_matches should not be called for Raptor Strike OOC")

-- Case 5: Not ready -> should NOT match
action_calls = {}
local s_r_not_ready = {
 in_combat = true,
 use_melee = true,
 raptor_strike_ready = false,
 is_mounted = false,
}
assert_false(raptor.matches(ctx_r, s_r_not_ready), "Raptor Strike should not match when not ready")
assert_eq(#action_calls, 0, "action_matches should not be called for Raptor Strike not ready")

-- ============================================================================
-- Concussive Shot: kiting utility at 8y+ range
-- ============================================================================

local conc = find_strategy("ConcussiveShot")

-- Case 6: In combat, ready, at range (>= 8y) -> should match
action_calls = {}
local ctx_c = make_context({ distance = 15, in_combat = true })
local s_c = {
 in_combat = true,
 concussive_shot_ready = true,
 is_mounted = false,
}
assert_true(conc.matches(ctx_c, s_c), "Concussive Shot should match at range")

-- Case 7: Too close (< 8y) -> should NOT match
action_calls = {}
local ctx_c_close = make_context({ distance = 5, in_combat = true })
assert_false(conc.matches(ctx_c_close, s_c), "Concussive Shot should not match at < 8y range")
assert_eq(#action_calls, 0, "action_matches should not be called for Concussive Shot too close")

-- Case 8: Not ready -> should NOT match
action_calls = {}
local s_c_not_ready = {
 in_combat = true,
 concussive_shot_ready = false,
 is_mounted = false,
}
assert_false(conc.matches(ctx_c, s_c_not_ready), "Concussive Shot should not match when not ready")
assert_eq(#action_calls, 0, "action_matches should not be called for Concussive Shot not ready")

-- ============================================================================
-- Volley: AoE channeled ability
-- ============================================================================

local volley = find_strategy("Volley")

-- Case 9: use_volley enabled, enough enemies, not moving -> should match
action_calls = {}
local ctx_v = make_context({ in_combat = true, enemy_count = 4, is_moving = false })
local s_v = {
 in_combat = true,
 use_volley = true,
 use_explosive_trap = false,
 volley_ready = true,
 enemy_count = 4,
 aoe_threshold = 3,
 is_mounted = false,
}
assert_true(volley.matches(ctx_v, s_v), "Volley should match with 4 enemies and not moving")

-- Case 10: Too few enemies -> should NOT match
action_calls = {}
local ctx_v_few = make_context({ in_combat = true, enemy_count = 2, is_moving = false })
local s_v_few = {
 in_combat = true,
 use_volley = true,
 volley_ready = true,
 enemy_count = 2,
 aoe_threshold = 3,
 is_mounted = false,
}
assert_false(volley.matches(ctx_v_few, s_v_few), "Volley should not match with < 3 enemies")
assert_eq(#action_calls, 0, "action_matches should not be called for Volley with few enemies")

-- Case 11: Moving -> should NOT match
action_calls = {}
local ctx_v_move = make_context({ in_combat = true, enemy_count = 4, is_moving = true })
local s_v_move = {
 in_combat = true,
 use_volley = true,
 volley_ready = true,
 enemy_count = 4,
 aoe_threshold = 3,
 is_mounted = false,
}
assert_false(volley.matches(ctx_v_move, s_v_move), "Volley should not match when moving")
assert_eq(#action_calls, 0, "action_matches should not be called for Volley while moving")

-- Case 12: use_volley disabled -> should NOT match
action_calls = {}
local ctx_v_disabled = make_context({ in_combat = true, enemy_count = 4, is_moving = false, settings = { use_volley = false, aoe_threshold = 3, trinket_mode = "off", use_cooldowns = true } })
local s_v_disabled = {
 in_combat = true,
 use_volley = false,
 volley_ready = true,
 enemy_count = 4,
 aoe_threshold = 3,
 is_mounted = false,
}
assert_false(volley.matches(ctx_v_disabled, s_v_disabled), "Volley should not match when use_volley disabled")
assert_eq(#action_calls, 0, "action_matches should not be called for Volley when disabled")

-- ============================================================================
-- Explosive Trap: AoE ground placement
-- ============================================================================

local trap = find_strategy("ExplosiveTrap")

-- Case 13: use_explosive_trap enabled, enough enemies -> should match
action_calls = {}
local ctx_t = make_context({ in_combat = true, enemy_count = 4 })
local s_t = {
 in_combat = true,
 use_explosive_trap = true,
 explosive_trap_ready = true,
 enemy_count = 4,
 aoe_threshold = 3,
 is_mounted = false,
}
assert_true(trap.matches(ctx_t, s_t), "Explosive Trap should match with 4 enemies")

-- Case 14: Too few enemies -> should NOT match
action_calls = {}
local ctx_t_few = make_context({ in_combat = true, enemy_count = 2 })
local s_t_few = {
 in_combat = true,
 use_explosive_trap = true,
 explosive_trap_ready = true,
 enemy_count = 2,
 aoe_threshold = 3,
 is_mounted = false,
}
assert_false(trap.matches(ctx_t_few, s_t_few), "Explosive Trap should not match with < 3 enemies")
assert_eq(#action_calls, 0, "action_matches should not be called for Explosive Trap with few enemies")

-- Case 15: use_explosive_trap disabled -> should NOT match
action_calls = {}
local ctx_t_disabled = make_context({ in_combat = true, enemy_count = 4, settings = { use_explosive_trap = false, aoe_threshold = 3, trinket_mode = "off", use_cooldowns = true } })
local s_t_disabled = {
 in_combat = true,
 use_explosive_trap = false,
 explosive_trap_ready = true,
 enemy_count = 4,
 aoe_threshold = 3,
 is_mounted = false,
}
assert_false(trap.matches(ctx_t_disabled, s_t_disabled), "Explosive Trap should not match when disabled")
assert_eq(#action_calls, 0, "action_matches should not be called for Explosive Trap when disabled")

-- ============================================================================
-- Trinket: on-use trinket activation
-- ============================================================================

local trinket = find_strategy("Trinket")

-- Case 16: In combat, trinket_mode both, trinkets equipped and ready -> should match
-- Note: cooldowns_allowed() reads from module-level state, so prime it via execute first
local ctx_tr = make_context({ in_combat = true, settings = { trinket_mode = "both", use_cooldowns = true, aoe_threshold = 3 } })
trinket.execute(ctx_tr) -- Primes module-level state via build_state

action_calls = {}
local s_tr_ready = {
 in_combat = true,
 trinket_mode = "both",
 trinket_1_id = 12345,
 trinket_2_id = 67890,
 trinket_1_ready = true,
 trinket_2_ready = true,
 is_mounted = false,
 use_cooldowns = true,
}
assert_true(trinket.matches(ctx_tr, s_tr_ready), "Trinket should match when trinkets are ready")
assert_false(#action_calls > 0, "Trinket should NOT call action_matches (returns true directly)")

-- Case 17: trinket_mode off -> should NOT match
action_calls = {}
local s_tr_off = {
 in_combat = true,
 trinket_mode = "off",
 trinket_1_id = 12345,
 trinket_2_id = 67890,
 trinket_1_ready = true,
 trinket_2_ready = true,
 is_mounted = false,
 use_cooldowns = true,
}
assert_false(trinket.matches(ctx_tr, s_tr_off), "Trinket should not match when trinket_mode is off")
assert_eq(#action_calls, 0, "action_matches should not be called for Trinket when mode off")

-- Case 18: No trinkets equipped -> should NOT match
action_calls = {}
local s_tr_no = {
 in_combat = true,
 trinket_mode = "both",
 trinket_1_id = nil,
 trinket_2_id = nil,
 trinket_1_ready = false,
 trinket_2_ready = false,
 is_mounted = false,
 use_cooldowns = true,
}
assert_false(trinket.matches(ctx_tr, s_tr_no), "Trinket should not match when no trinkets equipped")
assert_eq(#action_calls, 0, "action_matches should not be called for Trinket with no trinkets")

-- Case 19: Out of combat -> should NOT match
action_calls = {}
local ctx_tr_ooc = make_context({ in_combat = false, settings = { trinket_mode = "both", use_cooldowns = true, aoe_threshold = 3 } })
local s_tr_ooc = {
 in_combat = false,
 trinket_mode = "both",
 trinket_1_id = 12345,
 trinket_2_id = 67890,
 trinket_1_ready = true,
 trinket_2_ready = true,
 is_mounted = false,
 use_cooldowns = true,
}
assert_false(trinket.matches(ctx_tr_ooc, s_tr_ooc), "Trinket should not match when OOC")
assert_eq(#action_calls, 0, "action_matches should not be called for Trinket OOC")

-- Case 20: Trinkets on cooldown -> should NOT match
action_calls = {}
local s_tr_cd = {
 in_combat = true,
 trinket_mode = "both",
 trinket_1_id = 12345,
 trinket_2_id = 67890,
 trinket_1_ready = false,
 trinket_2_ready = false,
 is_mounted = false,
 use_cooldowns = true,
}
assert_false(trinket.matches(ctx_tr, s_tr_cd), "Trinket should not match when both trinkets on cooldown")
assert_eq(#action_calls, 0, "action_matches should not be called for Trinket on CD")

-- Case 21: trinket_mode slot1, only slot1 ready -> should match
action_calls = {}
local s_tr_slot1 = {
 in_combat = true,
 trinket_mode = "slot1",
 trinket_1_id = 12345,
 trinket_2_id = 67890,
 trinket_1_ready = true,
 trinket_2_ready = false,
 is_mounted = false,
 use_cooldowns = true,
}
assert_true(trinket.matches(ctx_tr, s_tr_slot1), "Trinket should match in slot1 mode when only trinket 1 is ready")
assert_eq(#action_calls, 0, "Trinket should not call action_matches (returns true directly)")

print("PASS test_hunter_bm_melee_aoe_trinket")
