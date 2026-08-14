-- test_druid_live_fixes.lua -- regression tests for the 2026-08-12 druid
-- live-correctness fixes (audit-driven).
-- WHAT:  pins the cat mana_pct fix (NS.mana_pct, not the never-defined
--        NS.power_pct), PoolForExecuteBite energy gate, rip_snapshot
--        would_rip_fire guard, bear interrupt-manager settings argument,
--        bear Faerie Fire armor sentinel (0 = no armor), balance dead SP-gate
--        removal, resto DownrankHealingTouch max-rank gate, can_tree dead
--        branch removal, Triage-aware lowest_hp_pct, MovingLifebloom tank
--        roll guard, and Regrowth downrank rank-ladder fallback.
-- WHEN:  standalone: `lua EaxRotations/tests/test_druid_live_fixes.lua`
-- SAFETY: isolated mocked NS; no production code or live game state touched.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

-- ---------------------------------------------------------------------------
-- Mock NS (mutable behaviors per spec phase)
-- ---------------------------------------------------------------------------
local mock_mana_pct = 100
local mock_buff_up = false
local mock_has_form = nil          -- function(form) -> bool (set per phase)
local mock_spell_ready = "permissive"  -- "permissive" | "selective"
local ready_ids = {}               -- selective spell_ready map
local mock_get_spell_id = nil      -- function(id) -> id|nil
local cast_calls = {}              -- try_cast capture

local player = {
    get_health_percentage = function() return 100 end,
    get_attack_power = function() return 0 end,
    get_power = function() return 0 end,
}

local function resolve_spell_id(spell)
    if type(spell) == "number" then return spell end
    if type(spell) == "table" then
        if type(spell.id) == "function" then
            local ok, id = pcall(spell.id, spell)
            if ok and type(id) == "number" then return id end
        end
        if type(spell.spell_id) == "number" then return spell.spell_id end
        if type(spell.ids) == "table" then return spell.ids[1] end
        if type(spell[1]) == "number" then return spell[1] end
    end
    return nil
end

local ns = {
    CLASS_ID = { DRUID = 11 },
    PLAYER_UNIT = player,
    DruidSpells = {},
    GetPlayer = function() return player end,
    time_now = function() return 0 end,
    game_time_ms = function() return 0 end,
    mana_pct = function(unit) return mock_mana_pct end,
    same_unit = function(a, b) return a == b end,
    not_same_unit = function(a, b) return a ~= b end,
    buff_up = function(me, ids) return mock_buff_up end,
    has_player_buff = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    buff_remains = function() return 0 end,
    spell_exists = function() return true end,
    is_item_ready = function() return false end,
    has_form = function(form) return mock_has_form and mock_has_form(form) or false end,
    spell_ready = function(spell, target, opts)
        if mock_spell_ready == "selective" then
            return ready_ids[resolve_spell_id(spell)] == true
        end
        return true
    end,
    try_cast = function(spell, target, label, opts)
        cast_calls[#cast_calls + 1] = { spell = spell, target = target, label = label }
        return true
    end,
    get_spell_id = function(id) return mock_get_spell_id and mock_get_spell_id(id) end,
    use_item_by_id = function() return false end,
    log = function() end,
    log_warning = function() end,
    rotation_registry = { register = function() end },
    POWER_MANA = 0,
    POWER_ENERGY = 3,
    POWER_RAGE = 1,
    POWER_COMBO = 4,
    action_matches = function() return true end,
    action_execute = function() return true end,
    get_friendly_target_entry = function() return nil end,
    GetEnemiesInRange = function() return {} end,
    GetPartyMembers = function() return {} end,
    unit_alive = function() return true end,
    gate_overheal = function() return false end,
    has_dispel_type_debuff = function() return false end,
    safe_field = nil,
}
_G.core = { time = function() return 0 end, log = function() end }
_G.EaxRotations = ns

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name, 2)
end

-- ============================================================================
-- CAT phase
-- ============================================================================
mock_has_form = function(form) return form == "cat" end
local cat = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
assert_true(cat and cat.strategies, "cat strategies should load")

local function cat_ctx(o)
    local base = {
        in_combat = true,
        combo_points = 3,
        energy = 40,
        target = {},
        ttd = 60,
        has_valid_enemy_target = true,
        stance = 3,
        settings = {},
        me = {
            energy_predicted = function() return 25 end,
            energy_time_to_x = function(self, want) return 0.3 end,
        },
    }
    for k, v in pairs(o or {}) do base[k] = v end
    return base
end

-- CAT-1: state.mana_pct must come from NS.mana_pct (real member), NOT the
-- never-defined NS.power_pct. Without context.mana_pct, mana must reflect
-- the unit query.
mock_mana_pct = 10
local cat_state = cat.build_state(cat_ctx({ mana_pct = nil }))
assert_eq(cat_state.mana_pct, 10, "cat state.mana_pct should read NS.mana_pct when context.mana_pct absent")

-- ManaPotion DSL lane: mana_pct <= 20 must now fire with real mana (10).
local mana_potion = find_strategy(cat.strategies, "ManaPotion")
mock_has_form = function() return false end  -- potion lane requires NOT in cat form
assert_true(mana_potion.matches(cat_ctx({ mana_pct = nil, has_mana_potion = true, stance = 0 })), "ManaPotion should match at real 10% mana")
mock_mana_pct = 50
assert_false(mana_potion.matches(cat_ctx({ mana_pct = nil, has_mana_potion = true, stance = 0 })), "ManaPotion must NOT match at 50% mana")
mock_has_form = function(form) return form == "cat" end

-- EmergencyPowershift: POWERSHIFT_MIN_MANA gate must block at low mana.
local emergency_ps = find_strategy(cat.strategies, "EmergencyPowershift")
mock_mana_pct = 5
assert_false(emergency_ps.matches(cat_ctx({ energy = 5 })), "EmergencyPowershift must be blocked below POWERSHIFT_MIN_MANA")
mock_mana_pct = 50
assert_true(emergency_ps.matches(cat_ctx({ energy = 5 })), "EmergencyPowershift should match with ample mana")

-- CAT-6: PoolForExecuteBite — execute must NOT attempt FerociousBite when
-- energy < BITE_COST (35); dispatch falls through to lower strategies.
local pool_bite = find_strategy(cat.strategies, "PoolForExecuteBite")
cast_calls = {}
mock_mana_pct = 100
local exec_ctx_pool = cat_ctx({ energy = 20, combo_points = 5, target_hp = 10 })
assert_true(pool_bite.matches(exec_ctx_pool), "PoolForExecuteBite should match while pooling for the tick")
assert_false(pool_bite.execute(exec_ctx_pool), "PoolForExecuteBite execute must return false without casting when energy < BITE_COST")
assert_eq(#cast_calls, 0, "no FerociousBite attempt while pooling")
local exec_ctx_ready = cat_ctx({ energy = 40, combo_points = 5, target_hp = 10 })
assert_true(pool_bite.execute(exec_ctx_ready), "PoolForExecuteBite execute should cast when energy >= BITE_COST")
assert_eq(#cast_calls, 1, "FerociousBite attempted once when affordable")
assert_eq(resolve_spell_id(cast_calls[1].spell), 24248, "PoolForExecuteBite casts FerociousBite (24248)")
assert_true(cast_calls[1].target == exec_ctx_ready.target, "PoolForExecuteBite casts on current target")

-- CAT-4: ShredOmen still matches on clearcasting (mutation removed) and is
-- correctly gated when clearcasting is absent.
local shred_omen = find_strategy(cat.strategies, "ShredOmen")
mock_buff_up = true
assert_true(shred_omen.matches(cat_ctx({ energy = 10, combo_points = 3, is_behind = true })), "ShredOmen should match with clearcasting")
mock_buff_up = false
assert_false(shred_omen.matches(cat_ctx({ energy = 10, combo_points = 3, is_behind = true })), "ShredOmen must not match without clearcasting")
mock_buff_up = false

-- CAT-5: RipSnapshot consults would_rip_fire (cat_use_rip + TTD guards).
local rip_snapshot = find_strategy(cat.strategies, "RipSnapshot")
assert_false(rip_snapshot.matches(cat_ctx({ combo_points = 5, settings = { cat_use_rip = false } })),
    "RipSnapshot must respect cat_use_rip=false")
assert_false(rip_snapshot.matches(cat_ctx({ combo_points = 5, ttd = 5 })),
    "RipSnapshot must respect the MIN_RIP_TTD floor (ttd < 10)")

-- ============================================================================
-- BEAR phase
-- ============================================================================
mock_has_form = function(form) return form == "bear" end
mock_spell_ready = "permissive"
local bear = dofile("EaxRotations/classes/druid/bear_sylvanas.lua")
assert_true(bear and bear.strategies, "bear strategies should load")

-- BEAR-1: BashInterrupt passes s.settings (not the undefined bare `settings`)
-- into the InterruptManager helpers.
local captured_settings = nil
ns.InterruptManager = {
    cast_has_interrupt_window = function(target, s) captured_settings = s; return true end,
    humanize_interrupt_elapsed = function(target, s) return true end,
}
ns.try_interrupt = function() return true end
local bash = find_strategy(bear.strategies, "BashInterrupt")
local bear_ctx = {
    in_combat = true,
    stance = 1,
    rage = 50,
    target = {},
    has_valid_enemy_target = true,
    target_range = 5,
    target_is_casting = true,
    settings = { use_interrupt = true },
    me = {},  -- no get_power: current_rage falls back to context.rage
    enemy_count = 1,
    hp = 100,
    target_hp = 50,
    ttd = 60,
}
assert_true(bash.matches(bear_ctx), "BashInterrupt should match a casting interruptible target")
assert_true(captured_settings == bear_ctx.settings, "InterruptManager must receive context.settings (was nil)")
ns.InterruptManager = nil
ns.try_interrupt = nil

-- BEAR armor sentinel: 0 (not 1) is the "no armor" value the engine sets
-- (main_sylvanas.lua:820 -> get_armor() or 0). Both gates must skip armorless
-- targets and still fire on armored ones.
local bear_state_full = {
    is_bear = true, in_combat = true, has_valid_target = true,
    target_range = 5, faerie_remains = 0, settings = {},
}
local ff_combat = find_strategy(bear.strategies, "FaerieFireFeral")
local ff_ctx0 = { in_combat = true, stance = 1, target = {}, has_valid_enemy_target = true, target_range = 5, target_armor = 0, settings = {}, me = player }
assert_false(ff_combat.matches(ff_ctx0, bear_state_full), "FaerieFireFeral must skip no-armor targets (armor 0)")
local ff_ctx_armored = { in_combat = true, stance = 1, target = {}, has_valid_enemy_target = true, target_range = 5, target_armor = 5000, settings = {}, me = player }
assert_true(ff_combat.matches(ff_ctx_armored, bear_state_full), "FaerieFireFeral should match armored targets")

local ff_pull = find_strategy(bear.strategies, "FaerieFirePull")
local pull_ctx0 = { in_combat = false, stance = 1, target = {}, has_valid_enemy_target = true, target_range = 30, target_armor = 0, settings = {}, me = player }
assert_false(ff_pull.matches(pull_ctx0), "FaerieFirePull must skip no-armor targets (armor 0)")
local pull_ctx_armored = { in_combat = false, stance = 1, target = {}, has_valid_enemy_target = true, target_range = 30, target_armor = 5000, settings = {}, me = player }
assert_true(ff_pull.matches(pull_ctx_armored), "FaerieFirePull should match armored targets")

-- ============================================================================
-- BALANCE phase (smoke: dead SP-gate locals removed without breaking lanes)
-- ============================================================================
mock_has_form = function() return false end
local balance = dofile("EaxRotations/classes/druid/balance_sylvanas.lua")
assert_true(balance and balance.strategies, "balance strategies should load")
local is_dot = find_strategy(balance.strategies, "InsectSwarmDoT")
assert_true(is_dot.matches({ in_combat = true, target = {}, has_valid_enemy_target = true, settings = {} }, { insect_remains = 0, mana_pct = 100 }),
    "InsectSwarmDoT should still match after dead SP-gate removal")

-- ============================================================================
-- RESTO phase
-- ============================================================================
mock_spell_ready = "selective"
ready_ids = { [26979] = true, [33763] = true, [26980] = true, [2782] = true, [18562] = true, [17116] = true }
mock_get_spell_id = function(id) return nil end  -- no downrank ranks learned by default

local healer_u = { name = "healer" }
local tank_u = { name = "tank" }
local ns_healing = { scan_healing_targets = function() return {}, 0 end }
ns.DruidHealing = ns_healing
ns.Triage = nil

local resto = dofile("EaxRotations/classes/druid/resto_sylvanas.lua")
assert_true(resto and resto.strategies, "resto strategies should load")

local resto_ctx = {
    in_combat = true,
    is_group = true,
    is_moving = false,
    mana_pct = 80,
    hp = 100,
    settings = {},
    me = {},
    target = nil,
    has_valid_enemy_target = false,
    enemy_count = 0,
    stance = 0,
}

-- RESTO-1: DownrankHealingTouch gates on the resolved max Healing Touch rank
-- (26979), not the rank-5 id 5189. With 5189 unready and 26979 ready the lane
-- must still match (old code returned false -> no downrank below 70).
local downrank_ht = find_strategy(resto.strategies, "DownrankHealingTouch")
local ht_lowest = { unit = healer_u, effective_hp = 60, hp = 60, deficit = 4000 }
local ht_ctx = { in_combat = true, is_moving = false, mana_pct = 20, settings = {}, me = {} }
assert_true(downrank_ht.matches(ht_ctx, { lowest = ht_lowest }), "DownrankHealingTouch should match with max rank ready")
cast_calls = {}
assert_true(downrank_ht.execute(ht_ctx, { lowest = ht_lowest }), "DownrankHealingTouch should execute")
assert_eq(resolve_spell_id(cast_calls[1] and cast_calls[1].spell), 26978, "DownrankHealingTouch casts conserve rank 26978 at 20% mana")

-- RESTO-2: can_tree no longer depends on the never-defined NS.spell_book.
ns.spell_exists = function() return true end
local st2 = resto.build_state(resto_ctx)
assert_true(st2.can_tree == true, "can_tree should resolve via NS.spell_exists")
ns.spell_exists = function() return true end

-- RESTO-4: lowest_hp_pct is computed AFTER the NS.Triage override.
ns_healing.scan_healing_targets = function() return { { unit = healer_u, effective_hp = 70, hp = 70 } }, 1 end
ns.Triage = {
    rank = function(entries, count, settings)
        return { { unit = healer_u, effective_hp = 40, hp = 40, deficit = 6000 } }
    end,
}
local st4 = resto.build_state(resto_ctx)
assert_eq(st4.lowest_hp_pct, 40, "lowest_hp_pct must reflect the Triage-ranked lowest (40), not the pre-Triage 70/100")
ns.Triage = nil
ns_healing.scan_healing_targets = function() return {}, 0 end

-- RESTO-5: MovingLifebloom must not steal the tank's ACTIVE Lifebloom roll
-- (stacks > 0 and due for refresh); a roll-less tank is TankLifebloomStack's
-- job at higher priority, so the lane must still fire there.
local moving_lb = find_strategy(resto.strategies, "MovingLifebloom")
local move_ctx = { is_moving = true, mana_pct = 80, settings = {}, me = {}, in_combat = true }
assert_true(moving_lb.matches(move_ctx, { lowest = { unit = healer_u, effective_hp = 80, hp = 80 } }),
    "MovingLifebloom should match when no tank roll needs refresh")
assert_false(moving_lb.matches(move_ctx, {
        lowest = { unit = healer_u, effective_hp = 80, hp = 80 },
        lifebloom_tank = { unit = tank_u, effective_hp = 60, hp = 60 },
        tank = { unit = tank_u, effective_hp = 60, hp = 60, lifebloom_stacks = 2 },
    }),
    "MovingLifebloom must skip while the tank's ACTIVE Lifebloom roll needs refresh")
assert_true(moving_lb.matches(move_ctx, {
        lowest = { unit = healer_u, effective_hp = 80, hp = 80 },
        lifebloom_tank = { unit = tank_u, effective_hp = 60, hp = 60 },
        tank = { unit = tank_u, effective_hp = 60, hp = 60, lifebloom_stacks = 0 },
    }),
    "MovingLifebloom may cast when the tank has no active roll (TankLifebloomStack owns it)")

-- RESTO-6: RegrowthSpotHeal downrank falls back to the max-rank action when
-- the downrank rank (9858/9857) is not learned.
local regrowth_spot = find_strategy(resto.strategies, "RegrowthSpotHeal")
local rg_entry = { unit = healer_u, effective_hp = 60, hp = 60, deficit = 4000 }
local rg_ctx = { is_moving = false, mana_pct = 40, settings = {}, me = {} }
assert_true(regrowth_spot.matches(rg_ctx, { regrowth_target = rg_entry, mana_conserve = false }),
    "RegrowthSpotHeal should match")
cast_calls = {}
assert_true(regrowth_spot.execute(rg_ctx, { regrowth_target = rg_entry, mana_conserve = false }), "RegrowthSpotHeal should execute")
assert_eq(resolve_spell_id(cast_calls[1] and cast_calls[1].spell), 26980,
    "RegrowthSpotHeal must fall back to max-rank Regrowth (26980) when 9858 is unlearned")
mock_get_spell_id = function(id) return id == 9858 and 9858 or nil end
cast_calls = {}
assert_true(regrowth_spot.execute(rg_ctx, { regrowth_target = rg_entry, mana_conserve = false }), "RegrowthSpotHeal should execute (rank learned)")
assert_eq(resolve_spell_id(cast_calls[1] and cast_calls[1].spell), 9858,
    "RegrowthSpotHeal should cast the conserve downrank 9858 when learned")

print("PASS test_druid_live_fixes")
