-- test_druid_resto_vanilla_friendly_target.lua -- Restoration Druid Vanilla-era compatibility friendly target targeting tests.
-- WHAT:  Restoration Druid Vanilla-era compatibility friendly target targeting tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Verifies Vanilla/Classic-era rotation compatibility and spell availability.
-- SAFETY: Tests only Vanilla spell IDs and mechanics.

-- B6 FriendlyTarget for vanilla resto druid.
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local _ft_unit = { _friendly = true, is_player = function() return true end }
local _ft_hp = 75
local _ft_hostile = false
local _ft_present = true
local _last_cast = nil

_G.core = { time = function() return 0 end, log = function() end, get_game_version = function() return "Vanilla" end }
_G.EaxRotations = {
    DruidSpells = { Regrowth = 26980, Rejuvenation = 26981, HealingTouch = 26978, Barkskin = 22812, BearForm = 9634, NaturesGrasp = 16689, RemoveCurse = 2782, AbolishPoison = 2893, Tranquility = 740 },
    CLASS_ID = { DRUID = 11 },
    PLAYER_UNIT = { _mock = true },
    GetPlayer = function() return { get_class = function() return 11 end } end,
    GetTarget = function() return _ft_present and _ft_unit or nil end,
    is_hostile_unit = function() return _ft_hostile end,
    unit_alive = function(u) return u ~= nil end,
    unit_health_pct = function(u) if u == _ft_unit then return _ft_hp end return 100 end,
    get_friendly_target_entry = function()
        if not _ft_present or _ft_hostile then return nil end
        return { unit = _ft_unit, hp_pct = _ft_hp, effective_hp = _ft_hp, is_player = true }
    end,
    spell_ready = function() return true end,
    has_player_buff = function() return false end,
    debuff_remains = function() return 0 end,
    gate_overheal = function() return false end,
    try_cast = function(spell, target, reason, opts) _last_cast = { spell = spell, target = target, reason = reason }; return true end,
    healing_get_tank = function() return nil end,
    healing_get_lowest_hp = function() return nil end,
    healing_all_above_hp = function() return false end,
    healing_get_cleanse_target = function() return nil end,
    healing_count_below_hp = function() return 0 end,
    has_dispel_type_debuff = function() return false end,
    has_healing_reduction_debuff = function() return false end,
    is_in_raid = function() return false end,
    is_in_party = function() return false end,
    spell_action = function(ids, name) return { spell = ids, name = name } end,
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS = {}, HEALTH_POTION_IDS = {} }
package.loaded["classes/druid/healing_sylvanas"] = { select_heal = function() return nil end, scan_healing_targets = function() return {}, 0 end }

local result = dofile("EaxRotations/classes/druid/resto_vanilla.lua")
local strategies = result.strategies or result
local function find(name) for i = 1, #strategies do if strategies[i].name == name then return strategies[i] end end error("not found: "..name) end
local ft = find("FriendlyTarget")
assert_true(ft, "FriendlyTarget strategy should exist")

local function ctx(o) local c = { in_combat = true, is_moving = false, mana_pct = 100, hp = 100, settings = {}, me = { _mock = true }, is_pvp = false, target = nil } if o then for k,v in pairs(o) do c[k]=v end end return c end
local function st(o) local s = { lowest = nil, tank = nil, mana_pct = 100, mana_conserve = false, has_natures_swiftness = false, has_clearcasting = false, ht_target = nil, regrowth_target = nil, ns_target = nil } if o then for k,v in pairs(o) do s[k]=v end end return s end
local function reset() _ft_present = true; _ft_hostile = false; _ft_hp = 75; _last_cast = nil end

print("--- Druid Resto Vanilla FriendlyTarget (B6) ---")

reset()
assert_true(ft.matches(ctx(), st({ lowest = { effective_hp = 80, unit = {} } })), "C1: should match")
_last_cast = nil
assert_true(ft.execute(ctx(), st()), "C1: execute returns true")
assert_eq(_last_cast.target, _ft_unit, "C1: targets friendly unit")
print("  [ PASS ] C1: matches + casts Regrowth on friendly target")

reset()
assert_false(ft.matches(ctx(), st({ lowest = { effective_hp = 25, unit = {} } })), "C2: lowest 25% (<=35) -> emergency override")
print("  [ PASS ] C2: emergency override")

reset()
assert_false(ft.matches(ctx({ settings = { resto_use_friendly_target = false } }), st()), "C3: opt-out respected")
print("  [ PASS ] C3: opt-out setting respected")

reset()
assert_false(ft.matches(ctx({ is_moving = true }), st()), "C4: moving -> no match")
print("  [ PASS ] C4: moving-gated")

reset(); _ft_hostile = true
assert_false(ft.matches(ctx(), st()), "C5: hostile target does not match")
_ft_hostile = false
print("  [ PASS ] C5: hostile target does not match")

local ft_idx, ht_idx, rs_idx
for i = 1, #strategies do
    if strategies[i].name == "FriendlyTarget" then ft_idx = i end
    if strategies[i].name == "HealingTouchMaxEmergency" then ht_idx = i end
    if strategies[i].name == "RegrowthSpotHeal" then rs_idx = i end
end
assert_true(ft_idx and ht_idx and rs_idx, "C6: expected strategies present")
assert_true(ht_idx < ft_idx, "C6: FriendlyTarget after HealingTouchMaxEmergency")
assert_true(ft_idx < rs_idx, "C6: FriendlyTarget before RegrowthSpotHeal")
print("  [ PASS ] C6: strategy ordering")

-- ============================================================================
-- Healing Touch deficit-fit (2026-09-16): smallest covering rank over the
-- learn-capped classic ladder, fail-closed to the legacy max-rank cast.
-- Live NS lookup so the hook is injected post-load here.
-- ============================================================================
local NS_V = _G.EaxRotations
NS_V.DruidHEALING_TOUCH_RANKS = { { spell = "HT_FAKE_LADDER", label = "R11" } }
local FIT_HT = "HT_FIT_R9"
local ht_hook_calls = 0
local ht_last_opts = nil
NS_V.cast_best_heal_rank = function(ranks, target, context, label, opts)
    ht_hook_calls = ht_hook_calls + 1
    assert_true(ranks == NS_V.DruidHEALING_TOUCH_RANKS, "HT fit receives the shared ladder")
    ht_last_opts = opts
    return FIT_HT, "Healing Touch emergency R9"
end

local em = find("HealingTouchMaxEmergency")
local fb = find("FallbackHealingTouch")

-- Emergency fit: deficit 1500 -> mid-rank, level-60 divisor threaded.
ht_hook_calls = 0
_last_cast = nil
local s_em = st({ ht_target = { unit = {}, effective_hp = 30, deficit = 1500 } })
assert_true(em.matches(ctx(), s_em), "C7: emergency matches at hp 30")
assert_true(em.execute(ctx(), s_em), "C7: emergency executes")
assert_eq(_last_cast.spell, FIT_HT, "C7: deficit-fit rank replaces max-rank HT")
assert_eq(ht_last_opts and ht_last_opts.player_level, 60, "C7: level-60 penalty divisor threaded")
assert_eq(ht_hook_calls, 1, "C7: hook attempted once")
print("  [ PASS ] C7: emergency deficit-fit + level threading")

-- Fail-closed: hook misses -> legacy max-rank cast (mock id 26978).
NS_V.cast_best_heal_rank = function() return nil end
_last_cast = nil
local s_em_fb = st({ ht_target = { unit = {}, effective_hp = 30, deficit = 1500 } })
assert_true(em.execute(ctx(), s_em_fb), "C8: emergency executes on fit miss")
assert_eq(_last_cast.spell, 26978, "C8: fit miss falls back to max-rank HealingTouch")
print("  [ PASS ] C8: emergency fail-closed fallback")

-- Fallback lane fit: deficit 800 -> fit rank.
NS_V.cast_best_heal_rank = function(ranks, target, context, label, opts)
    ht_last_opts = opts
    return FIT_HT, "Healing Touch fallback R9"
end
_last_cast = nil
local s_fb = st({ lowest = { unit = {}, effective_hp = 70, deficit = 800 } })
assert_true(fb.matches(ctx(), s_fb), "C9: fallback matches at hp 70")
assert_true(fb.execute(ctx(), s_fb), "C9: fallback executes")
assert_eq(_last_cast.spell, FIT_HT, "C9: fallback lane uses the fit rank")
assert_eq(ht_last_opts and ht_last_opts.player_level, 60, "C9: level-60 divisor threaded")
print("  [ PASS ] C9: fallback deficit-fit")

-- Zero deficit: hook never attempted, legacy cast answers.
ht_hook_calls = 0
NS_V.cast_best_heal_rank = function(...) ht_hook_calls = ht_hook_calls + 1 return nil end
_last_cast = nil
local s_zero = st({ lowest = { unit = {}, effective_hp = 70, deficit = 0 } })
assert_true(fb.execute(ctx(), s_zero), "C10: fallback executes at zero deficit")
assert_eq(_last_cast.spell, 26978, "C10: zero deficit keeps max-rank cast")
assert_eq(ht_hook_calls, 0, "C10: hook skipped when deficit is unreadable")
print("  [ PASS ] C10: zero-deficit skip")

print("PASS test_druid_resto_vanilla_friendly_target")
