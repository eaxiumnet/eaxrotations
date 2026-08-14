-- test_druid_vanilla_live_fixes.lua — Druid Vanilla W1.3 live-fix regression tests.
-- WHAT:  pins the 2026-08-13 Wave 1.3 vanilla fixes: cat mana_pct (was
--        mock-only NS.power_pct), cat TigersFury low-energy gate, cat
--        Barkskin menu threshold, bear pack-scan throttle, resto
--        should_move_form reset, balance RemoveCurse curse gate, leveling
--        in_melee/target_range ordering.
-- WHEN:  standalone: lua EaxRotations/tests/test_druid_vanilla_live_fixes.lua
-- WHY:   each fix must fail loudly if a future edit regresses it.
-- SAFETY: Pure unit tests with mocked _G.EaxRotations; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- Deterministic module stubs (mirrors test_druid_vanilla_nil_guards).
package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {}, MANA_POTION_IDS = {} }
package.loaded["shared/tbc_data_sylvanas"] =
    { ITEMS = { healthstones = {}, potions = {} }, SPELLS = { mage = {} } }
package.loaded["shared/leveling_sylvanas"] = {
    create_context_guard = function() return function() return true end end,
    build_common_state = function() end,
    create_wand_matches = function() return function() return false end end,
    execute_wand = function() return false end,
}
package.loaded["shared/find_dead_party_ally_sylvanas"] = { find_dead_party_ally = function() return nil end }
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }

local visible_scans = 0
local curse_present = false

_G.EaxRotations = {
    CLASS_ID = { DRUID = 11 },
    PLAYER_UNIT = {},
    DruidSpells = {
        CatForm = 768, Prowl = 5215, Shred = 5221, Rake = 1822, Rip = 1079,
        FerociousBite = 22568, TigersFury = 5217, FaerieFireFeral = 770,
        Dash = 1850, Barkskin = 22812, TrackHumanoids = 5225, Ravage = 6785,
        Pounce = 9005, TravelForm = 783, Claw = 1082,
        SwipeBear = 779, Maul = 6807, Growl = 6794, DemoralizingRoar = 99,
        ChallengingRoar = 5209, Enrage = 5229, BearForm = 5487,
        FrenziedRegeneration = 22842, MarkOfTheWild = 1126, GiftOfTheWild = 21849,
        Thorns = 467, Bash = 8983,
        RemoveCurse = 2782, Starfire = 2912, Wrath = 517, Moonfire = 8921,
        InsectSwarm = 5570, Hurricane = 16914, Innervate = 29166, Rebirth = 20484,
        FaerieFire = 770, NaturesSwiftness = 16689, Tranquility = 740,
        EntanglingRoots = 339, NaturesGrasp = 16689, AbolishPoison = 2893,
    },
    GetPlayer = function() return { get_class = function() return 11 end, get_power = function() return 100 end } end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_remains = function() return 0 end,
    has_player_buff = function() return false end,
    has_form = function() return false end,
    is_behind_target = function() return true end,
    -- mana_pct: the engine read (core_sylvanas.lua:2764) — the fix replaces
    -- the mock-only NS.power_pct fallback with this.
    mana_pct = function(unit) return 42 end,
    same_unit = function() return false end,
    safe_field = function(unit, method) return unit and unit[method] end,
    time_now = function() return 0 end,
    -- Spy for the bear pack-scan throttle (scan_pack → get_visible_units).
    get_visible_units = function(hostile_only, limit) visible_scans = visible_scans + 1; return {}, 0 end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
    DruidHealing = { scan_healing_targets = function() return {}, 0 end },
    has_dispel_type_debuff = function() return curse_present end,
    get_setting = function(key, default) return default end,
    is_in_party = function() return false end,
    is_in_raid = function() return false end,
    POWER_ENERGY = 3,
    POWER_MANA = 0,
}

-- ============================================================================
-- 1. cat_vanilla: mana_pct read must use NS.mana_pct (not mock-only power_pct)
-- ============================================================================
local cat_mod = dofile("EaxRotations/classes/druid/cat_vanilla.lua")
assert_true(cat_mod and cat_mod.strategies, "cat_vanilla should load")
local cat_state = cat_mod.build_state({})
assert_true(cat_state.mana_pct == 42,
    "cat build_state must read mana via NS.mana_pct (got " .. tostring(cat_state.mana_pct) .. ")")
print("PASS: cat mana_pct via NS.mana_pct (mock-only power_pct removed)")

-- ============================================================================
-- 2. cat_vanilla: TigersFury gate (inverted energy gate fixed)
-- ============================================================================
local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name, 2)
end
local tf = find_strategy(cat_mod.strategies, "TigersFury")
local tf_ctx = { in_combat = true, me = {}, has_valid_enemy_target = true }

assert_true(tf.matches(tf_ctx, { is_cat = true, has_tigers_fury = false, in_combat = true, is_stealthed = false, energy = 25, next_tick_in = 2.0 }),
    "TigersFury must fire at LOW energy (25) — the gain fits under the cap")
assert_false(tf.matches(tf_ctx, { is_cat = true, has_tigers_fury = false, in_combat = true, is_stealthed = false, energy = 90, next_tick_in = 2.0 }),
    "TigersFury must not fire at near-cap energy (90 + 30 > 100)")
assert_false(tf.matches(tf_ctx, { is_cat = true, has_tigers_fury = false, in_combat = true, is_stealthed = false, energy = 68, next_tick_in = 0.5 }),
    "TigersFury must not fire near cap with an imminent tick")
assert_false(tf.matches(tf_ctx, { is_cat = true, has_tigers_fury = true, in_combat = true, is_stealthed = false, energy = 25, next_tick_in = 2.0 }),
    "TigersFury must not fire while the buff is already up")
assert_false(tf.matches(tf_ctx, { is_cat = true, has_tigers_fury = false, in_combat = false, is_stealthed = false, energy = 25, next_tick_in = 2.0 }),
    "TigersFury must not fire out of combat")
assert_false(tf.matches(tf_ctx, { is_cat = true, has_tigers_fury = false, in_combat = true, is_stealthed = true, energy = 25, next_tick_in = 2.0 }),
    "TigersFury must not fire while stealthed")
print("PASS: cat TigersFury low-energy gate (6 assertions)")

-- ============================================================================
-- 3. cat_vanilla: Barkskin reads the menu setting (was pinned at 25 forever)
-- ============================================================================
local bk = find_strategy(cat_mod.strategies, "Barkskin")
assert_true(bk.matches({ settings = {}, me = {} }, { hp = 50, has_barkskin = false }),
    "Barkskin must fire at hp 50 with the default 85 threshold")
assert_false(bk.matches({ settings = {}, me = {} }, { hp = 90, has_barkskin = false }),
    "Barkskin must not fire at hp 90 with the default 85 threshold")
assert_false(bk.matches({ settings = { cat_barkskin_hp = 60 }, me = {} }, { hp = 70, has_barkskin = false }),
    "Barkskin must honor cat_barkskin_hp = 60 (hp 70 above threshold)")
print("PASS: cat Barkskin reads cat_barkskin_hp setting (default 85)")

-- ============================================================================
-- 4. bear_vanilla: pack scan throttled to 0.5s (lazy_scan_pack wired)
-- ============================================================================
-- The bear file returns the bare strategies table and registers get_state
-- through the registry; capture it with a recording registry mock.
local bear_registry = { get_state = nil }
_G.EaxRotations.rotation_registry = { register = function(self, spec, strats, opts) bear_registry.get_state = opts.get_state end }
dofile("EaxRotations/classes/druid/bear_vanilla.lua")
_G.EaxRotations.rotation_registry = { register = function() end }
assert_true(bear_registry.get_state ~= nil, "bear_vanilla must register get_state")

visible_scans = 0
local s1 = bear_registry.get_state({ now = 0, settings = {}, me = {}, in_combat = true })
assert_true(visible_scans == 1, "bear first frame (now=0) must scan once, got " .. visible_scans)
local s2 = bear_registry.get_state({ now = 0.4, settings = {}, me = {}, in_combat = true })
assert_true(visible_scans == 1, "bear scan must be throttled at now=0.4 (0.4s since last), got " .. visible_scans)
local s3 = bear_registry.get_state({ now = 0.9, settings = {}, me = {}, in_combat = true })
assert_true(visible_scans == 2, "bear scan must run again at now=0.9 (>= 0.5s), got " .. visible_scans)
local s4 = bear_registry.get_state({ now = 0.9, settings = {}, me = {}, in_combat = true })
assert_true(visible_scans == 2, "bear same-frame build_state must hit the frame cache (no rescan), got " .. visible_scans)
assert_true(s1.pack_elites == 0 and s3.pack_elites == 0, "bear pack fields default to 0")
print("PASS: bear pack scan throttled (0.5s SCAN_INTERVAL + frame cache)")

-- ============================================================================
-- 5. resto_vanilla: should_move_form reset every build_state
-- ============================================================================
local resto_mod = dofile("EaxRotations/classes/druid/resto_vanilla.lua")
assert_true(resto_mod and resto_mod.build_state, "resto_vanilla should load")
local moving_state = resto_mod.build_state({ is_moving = true, target_distance = 30, settings = {}, me = {}, mana_pct = 100 })
assert_true(moving_state.should_move_form == true,
    "resto should_move_form must be true while moving far, got " .. tostring(moving_state.should_move_form))
local stopped_state = resto_mod.build_state({ is_moving = false, target_distance = 5, settings = {}, me = {}, mana_pct = 100 })
assert_true(stopped_state.should_move_form == false,
    "resto should_move_form must RESET to false once not moving (was sticky), got " .. tostring(stopped_state.should_move_form))
local tf_r = find_strategy(resto_mod.strategies, "TravelFormReposition")
assert_true(tf_r.matches({ is_moving = true, stance = 0, settings = {} }, { should_move_form = true }),
    "TravelFormReposition must fire while moving with the flag set")
assert_false(tf_r.matches({ is_moving = false, stance = 0, settings = {} }, { should_move_form = true }),
    "TravelFormReposition must not fire when not moving (belt-and-braces is_moving gate)")
print("PASS: resto should_move_form reset + reposition lanes gated on is_moving")

-- ============================================================================
-- 6. balance_vanilla: RemoveCurse curse-presence gate
-- ============================================================================
local bal_mod = dofile("EaxRotations/classes/druid/balance_vanilla.lua")
assert_true(bal_mod and bal_mod.strategies, "balance_vanilla should load")
local rc = find_strategy(bal_mod.strategies, "RemoveCurse")
curse_present = false
assert_false(rc.matches({ settings = {} }),
    "RemoveCurse must NOT fire when the player has no curse (was every-GCD spam)")
curse_present = true
assert_true(rc.matches({ settings = {} }),
    "RemoveCurse must fire when the player has a curse")
assert_false(rc.matches({ settings = { balance_auto_dispel = false } }),
    "RemoveCurse must respect balance_auto_dispel = false")
print("PASS: balance RemoveCurse curse-presence gate (3 assertions)")

-- ============================================================================
-- 7. leveling_vanilla: in_melee computed AFTER target_range (dead branch fix)
-- ============================================================================
local lvl_mod = dofile("EaxRotations/classes/druid/leveling_vanilla.lua")
assert_true(lvl_mod and lvl_mod.build_state, "leveling_vanilla should load")
local lvl_state = lvl_mod.build_state({ target_distance = 3 })
assert_true(lvl_state.in_melee == true,
    "leveling in_melee must be true at target_distance 3 (was dead: read default 40), got " .. tostring(lvl_state.in_melee))
assert_true(lvl_state.target_range == 3, "leveling target_range must be assigned before in_melee reads it")
local lvl_far = lvl_mod.build_state({ target_distance = 20 })
assert_false(lvl_far.in_melee == true, "leveling in_melee must be false at target_distance 20")
print("PASS: leveling in_melee/target_range ordering fixed")

print("PASS test_druid_vanilla_live_fixes")
