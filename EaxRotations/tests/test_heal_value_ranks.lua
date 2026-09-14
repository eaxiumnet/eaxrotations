-- test_heal_value_ranks.lua — pins for shared/heal_value_sylvanas (2026-09-14)
-- WHAT:  per-rank expected-heal math (base avg + coeff * bonus, TBC downrank
--        penalty), deficit-fit selection, castable pick with mana-tier
--        ceiling, the cast_best_heal_rank deficit-fit hook + kill switch,
--        and the corrected FoL R7 base (458-513, Wowhead description text).
-- WHEN:  standalone -- lua EaxRotations/tests/test_heal_value_ranks.lua
--        (standalone suite convention, like test_priest_healer_live_fixes).
-- WHY:   the PhDamage-harvested per-rank data changes what healers cast;
--        every claim is pinned so a wrong value or a legacy regression fails
--        loudly.
-- SAFETY: pure unit tests with mocked API context; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label)
  if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

_G.EaxRotations = { settings = {} }
local NS = _G.EaxRotations

local HV = require("shared/heal_value_sylvanas")
assert_true(HV and type(HV.expected_heal) == "function", "heal_value module loads")

-- ---------------------------------------------------------------------------
-- 1. expected_heal: base average, SP bonus, downrank penalty
-- ---------------------------------------------------------------------------
-- Holy Light R11 (level 70): penalty 1, base avg (2196+2446)/2 = 2321
local hl11 = { base_min = 2196, base_max = 2446, coeff = 0.714, level = 70 }
local heal, pen = HV.expected_heal(hl11, 0)
assert_eq(heal, 2321, "HL R11 base avg")
assert_eq(pen, 1.0, "HL R11 no penalty")

-- With +1000 bonus healing: 2321 + 714 = 3035
assert_eq(HV.expected_heal(hl11, 1000), 3035, "HL R11 with +1000 SP")

-- Flash of Light R2 (19939, level 26): base avg 109.5,
-- penalty = min(1, (26+11)/70) = 37/70 -> floor(109.5*0.52857+0.5) = 58
local fol2 = { base_min = 102, base_max = 117, coeff = 0.429, level = 26 }
local f2heal, f2pen = HV.expected_heal(fol2, 0)
assert_eq(f2heal, 58, "FoL R2 downrank-penalized")
assert_true(f2pen > 0.52 and f2pen < 0.54, "FoL R2 penalty magnitude")

-- Greater Heal R7 with +1000 SP: (2414+2803)/2 + 857 = 3466
local gh7 = { base_min = 2414, base_max = 2803, coeff = 0.857, level = 68 }
assert_eq(HV.expected_heal(gh7, 1000), 3466, "GH R7 with +1000 SP")

-- talent_mult: HL R11 with Healing Light 1.12
assert_eq(HV.expected_heal(hl11, 0, { talent_mult = 1.12 }), 2600, "HL R11 x1.12")

-- malformed entry: fail-closed zeros
assert_eq(HV.expected_heal(nil, 100), 0, "expected_heal(nil) = 0")
assert_eq(HV.expected_heal({ spell = "x" }, 100), 0, "expected_heal(no base) = 0")

-- ---------------------------------------------------------------------------
-- 2. corrected FoL R7 base (Wowhead description 458-513, not effect 448-502)
-- ---------------------------------------------------------------------------
local family = HV.RANKS.paladin.FlashOfLight
local fol7 = family[1]
assert_eq(fol7.id, 27137, "FoL head id 27137")
assert_eq(fol7.base_min, 458, "FoL R7 base_min corrected")
assert_eq(fol7.base_max, 513, "FoL R7 base_max corrected")

-- ---------------------------------------------------------------------------
-- 3. heal_per_mana: verified costs divide; nil cost = no signal (0)
-- ---------------------------------------------------------------------------
assert_eq(HV.heal_per_mana({ base_min = 931, base_max = 1078, coeff = 0.429, level = 61, cost = 400 }, 0) > 2.5, true, "FH R8 HPM ~2.51")
assert_eq(HV.heal_per_mana({ base_min = 931, base_max = 1078, coeff = 0.429, level = 61 }, 0), 0, "unverified cost = no HPM signal")

-- ---------------------------------------------------------------------------
-- 4. deficit-fit selection (pure math, no readiness)
-- ---------------------------------------------------------------------------
local ladder = {}
local function mk(id, rank, level, bmin, bmax, coeff)
  return { id = id, rank = rank, level = level, base_min = bmin, base_max = bmax, coeff = coeff }
end
-- Mirror of the real FoL ladder (newest first)
local fol_ladder = {
  mk(27137, 7, 66, 458, 513, 0.429), -- ~486
  mk(19943, 6, 58, 356, 396, 0.429), -- ~376
  mk(19942, 5, 50, 278, 310, 0.429), -- ~294
  mk(19941, 4, 42, 206, 231, 0.429), -- ~218.5
  mk(19940, 3, 34, 153, 171, 0.429), -- ~162 (penalized further)
  mk(19939, 2, 26, 102, 117, 0.429), -- ~109.5 (penalized ~58)
}
-- Real (penalized) heals: R7 486, R6 371, R5 256, R4 165, R3 104, R2 58.
-- Deficit 300 (fit bar 390): R7 486 overshoots, R6 371 fits -> R6.
local e, lab = HV.heal_rank_for_deficit(fol_ladder, 300, 0)
assert_eq(e.id, 19943, "deficit 300 -> FoL R6")
-- Tiny deficit 100 (bar 130): R2 58 fits -> R2; R3 104 also fits but R2 is
-- smaller and newer-first walk reaches it first? No: walk is newest-first,
-- R3 (104) fits before R2 is reached -> R3.
e = HV.heal_rank_for_deficit(fol_ladder, 100, 0)
assert_eq(e.id, 19940, "deficit 100 -> FoL R3 (smallest fitting, penalized)")
-- Huge deficit: nothing fits -> max rank (never nil)
e = HV.heal_rank_for_deficit(fol_ladder, 100000, 0)
assert_eq(e.id, 27137, "huge deficit -> max rank")
-- Legacy no-deficit call: max rank (never nil)
e = HV.heal_rank_for_deficit(fol_ladder, nil, 0)
assert_eq(e.id, 27137, "nil deficit -> max rank (legacy)")
-- nil/empty ladder safe
assert_eq(HV.heal_rank_for_deficit(nil, 100, 0), nil, "nil ladder -> nil")
assert_eq(HV.heal_rank_for_deficit({}, 100, 0), nil, "empty ladder -> nil")

-- SP shifts the fit upward: with +1000 SP the heals are R7 915, R6 794,
-- R5 630, R4 490, R3 380, R2 285. Deficit 300 (bar 390): R3 380 fits.
e = HV.heal_rank_for_deficit(fol_ladder, 300, 1000)
assert_eq(e.id, 19940, "SP shifts fit: +1000 SP -> deficit 300 picks R3")

-- ---------------------------------------------------------------------------
-- 5. pick_castable: readiness filtering + ceiling + legacy deferral
-- ---------------------------------------------------------------------------
-- Wrap pure-ladder entries with .spell fields for the castable pick
local function with_spells(ladder, ready_set)
  local out = {}
  for i, e in ipairs(ladder) do
    out[i] = setmetatable({ spell = "spell_" .. e.id, id = e.id, rank = e.rank, level = e.level,
      base_min = e.base_min, base_max = e.base_max, coeff = e.coeff },
      { __index = e })
  end
  return out
end
local cast_ladder = with_spells(fol_ladder)
local function ready_all() return true end
local function ready_only(ids)
  return function(spell) return ready_setContains(spell, ids) end
end
local function ready_setContains(v, t)
  for _, x in ipairs(t) do if x == v then return true end end
  return false
end
local opts_ready = { is_ready = function(spell, unit) return ready_setContains(spell, { "spell_19942", "spell_19941", "spell_19939" }) end, unit = "u" }
-- Deficit 300: R7/R6 NOT ready; R5 ready + fits -> R5
local fit = HV.pick_castable(cast_ladder, 300, 0, opts_ready)
assert_eq(fit.entry.id, 19942, "pick_castable skips unready larger ranks")
-- Deficit 100 with only R5/R4/R2 ready: R5 294>130, R4 218>130, R2 58<=130 -> R2
local fit2 = HV.pick_castable(cast_ladder, 100, 0, opts_ready)
assert_eq(fit2.entry.id, 19939, "pick_castable walks down to smallest fitting castable")
-- All overshoot -> biggest castable (R5) not nil
local fit3 = HV.pick_castable(cast_ladder, 20000, 0, opts_ready)
assert_eq(fit3.entry.id, 19942, "pick_castable huge deficit -> biggest castable")
-- Nothing ready -> nil (caller falls back to legacy)
local fit4 = HV.pick_castable(cast_ladder, 300, 0, { is_ready = function() return false end, unit = "u" })
assert_eq(fit4, nil, "pick_castable nothing ready -> nil")
-- Legacy ladder (no base data) -> nil (caller falls back)
local legacy = { { spell = "A", label = "R1" }, { spell = "B", label = "R2" } }
assert_eq(HV.pick_castable(legacy, 300, 0, { is_ready = ready_all, unit = "u" }), nil, "legacy ladder -> nil (defer to caller)")

-- Ceiling: mana-tier cap. Ceiling at R5 (19942): only R5/R4/R3/R2 allowed.
-- Deficit 300 -> R5 fits (294 <= 390). Deficit 800: R5 294>1040? no fits;
-- walk starts AT R5, all overshoot -> first_castable = R5 (the ceiling).
local ceil_entry = cast_ladder[3] -- R5 19942
local fit5 = HV.pick_castable(cast_ladder, 800, 0, { is_ready = ready_all, unit = "u", ceiling = ceil_entry })
assert_eq(fit5.entry.id, 19942, "ceiling caps upward: oversized deficit -> ceiling rank")
local fit6 = HV.pick_castable(cast_ladder, 300, 0, { is_ready = ready_all, unit = "u", ceiling = ceil_entry })
assert_eq(fit6.entry.id, 19942, "ceiling + fitting deficit -> ceiling rank when it fits")
-- Deficit 100 under ceiling R5 (bar 130): R5 256>130, R4 165>130,
-- R3 104<=130 -> R3.
local fit7 = HV.pick_castable(cast_ladder, 100, 0, { is_ready = ready_all, unit = "u", ceiling = ceil_entry })
assert_eq(fit7.entry.id, 19940, "ceiling still lets smaller ranks fit")
-- Ceiling not in ladder -> unrestricted (deficit 300 -> R6, same as no ceiling)
local fit8 = HV.pick_castable(cast_ladder, 300, 0, { is_ready = ready_all, unit = "u", ceiling = { id = 999 } })
assert_eq(fit8.entry.id, 19943, "unknown ceiling id -> unrestricted walk")

-- ---------------------------------------------------------------------------
-- 6. core cast_best_heal_rank: deficit-fit live, kill switch, legacy shape
-- ---------------------------------------------------------------------------
local core_ok = pcall(require, "core_sylvanas")
assert_true(core_ok, "core_sylvanas loads in test env")
assert_true(type(NS.cast_best_heal_rank) == "function", "cast_best_heal_rank exposed")
assert_true(type(NS.HealValue) == "table", "NS.HealValue installed by core")
-- The hook reads NS.spell_ready at call time; stub it so the fake rank
-- actions are castable (readiness itself is pinned by the rotation suites).
NS.spell_ready = function() return true end

-- Ladder built by the module (same shape as class tables now build)
local mk_action = function(id) return NS.spell_action({ name = "GreaterHeal", ids = { id } }) end
local built = HV.build_ladder("priest", "GreaterHeal", mk_action)
assert_eq(#built, 3, "GH ladder has 3 ranks")
assert_eq(built[1].label, "R7", "GH head label R7")
assert_eq(built[1].cost, 825, "GH head verified cost")

-- Deficit-fit through the real hook: unit at 5000/8000 -> deficit 3000.
-- GH R7 expected 2609 (no SP) fits 3000*1.3 -> R7... but R6 2276 fits too and
-- is checked first? No: R7 is newest and fits first -> R7.
local unit = { get_max_health = function(self) return 8000 end, get_health = function(self) return 5000 end }
local picked, picked_label = NS.cast_best_heal_rank(built, { unit = unit }, { settings = {} }, "T")
assert_true(picked and picked._meta and picked._meta.id[1] == 25213, "hook picks GH R7 for 3000 deficit")
-- Smaller deficit 400: R7 2609>520, R6 2276>520, R5 2121>520 -> all overshoot
-- -> biggest castable = R7.
local unit2 = { get_max_health = function(self) return 1000 end, get_health = function(self) return 600 end }
picked = NS.cast_best_heal_rank(built, { unit = unit2 }, { settings = {} }, "T")
assert_true(picked._meta.id[1] == 25213, "hook falls back to max rank on tiny deficits")
-- Mid-rank discriminator: deficit 1700 -> R5 (2121 fits bar 2210) while the
-- legacy first-ready walk would cast R7. Proves deficit-fit is live in the hook.
local unit3 = { get_max_health = function(self) return 4700 end, get_health = function(self) return 3000 end }
local mid = NS.cast_best_heal_rank(built, { unit = unit3 }, { settings = {} }, "T")
assert_true(mid and mid._meta and mid._meta.id[1] == 25314, "hook picks mid rank R5 at deficit 1700 (legacy would pick R7)")
-- SP knob discriminator: with +1000 bonus healing R5 = 2464 > 2210 bar, so the
-- same deficit now over-shoots every small rank -> back to R7.
local with_sp = NS.cast_best_heal_rank(built, { unit = unit3 }, { settings = { heal_bonus_healing = 1000 } }, "T")
assert_true(with_sp and with_sp._meta and with_sp._meta.id[1] == 25213, "bonus-healing knob shifts the fit back to R7")
-- Tier ceiling through the hook (the Clearcasting lane path): the 5th arg
-- caps the pick even when the deficit alone would choose R7.
local ceil_entry = built[3] -- R5 25314
local capped = NS.cast_best_heal_rank(built, { unit = unit }, { settings = {} }, "T", { ceiling = ceil_entry })
assert_true(capped and capped._meta and capped._meta.id[1] == 25314, "hook ceiling caps deficit-fit to R5 (tier-cast fix)")
-- Kill switch off: legacy walk, plain ladder behavior, first ready wins
NS.settings.healer_rank_fit_enabled = false
local legacy_ladder = { { spell = "L1", label = "R1" }, { spell = "L2", label = "R2" } }
local s, l = NS.cast_best_heal_rank(legacy_ladder, { unit = unit }, { settings = { healer_rank_fit_enabled = false } }, "T")
assert_eq(s, "L1", "kill switch restores legacy walk")
assert_eq(l, "T R1", "legacy label shape intact")
NS.settings.healer_rank_fit_enabled = true

-- Bonus healing knob: with +1000 the GH ladder all-fits at 3000 deficit...
-- R7 2609+857=3466 > 3900? no, 3466 <= 3900 fits -> R7 still. Use FoL: with
-- +1000 SP, deficit 300 -> all overshoot -> max rank (same as part 4).
NS.settings.heal_bonus_healing = 1000
local gh_pick = NS.cast_best_heal_rank(built, { unit = unit2 }, { settings = { heal_bonus_healing = 1000 } }, "T")
assert_true(gh_pick and gh_pick._meta.id[1] == 25213, "bonus healing knob resolves through the hook")
NS.settings.heal_bonus_healing = 0

-- find_rank_by_id: the mana-tier ceiling path used by the Clearcasting lane
local tier = HV.find_rank_by_id(25314) -- GH R5 (EFFICIENT tier)
assert_true(tier and tier.rank == 5, "find_rank_by_id locates the tier entry")
assert_true(HV.find_rank_by_id(123456) == nil, "find_rank_by_id unknown id -> nil")


-- ===========================================================================
-- 8. shaman + druid + discipline extension (2026-09-14 heal-fit ext wave)
-- ===========================================================================
-- HW R12 base avg (2134+2436)/2 = 2285 (PhDamage @ 22b8ed92, Wowhead-verified)
local hw12 = { base_min = 2134, base_max = 2436, coeff = 0.857, level = 70 }
assert_eq(HV.expected_heal(hw12, 0), 2285, "HW R12 base avg")
-- LHW R7 base avg (1051+1198)/2 = 1125
local lhw7 = { base_min = 1051, base_max = 1198, coeff = 0.429, level = 66 }
assert_eq(HV.expected_heal(lhw7, 0), 1125, "LHW R7 base avg")
-- HT R13 base avg (2715+3206)/2 = 2961 (Wowhead 2.4.3-corrected tail, coeff 1.0)
local ht13 = { base_min = 2715, base_max = 3206, coeff = 1.0, level = 69 }
assert_eq(HV.expected_heal(ht13, 0), 2961, "HT R13 base avg (Wowhead-corrected)")
-- HT R12 (26978) must NOT be PhDamage's stale pre-2.4 value (2707-3197):
-- Wowhead's TBC description (2401-2827, avg 2614) is the 2.5.5 truth.
local ht12 = HV.RANKS.druid.HealingTouch[2]
assert_eq(ht12.id, 26978, "HT R12 id")
assert_eq(HV.expected_heal(ht12, 0), 2614, "HT R12 carries the Wowhead 2.4.3 size, not PhDamage pre-2.4")
-- Ladder shapes
assert_eq(#HV.RANKS.shaman.HealingWave, 12, "HW ladder 12 ranks")
assert_eq(HV.RANKS.shaman.HealingWave[1].id, 25396, "HW head 25396")
assert_eq(HV.RANKS.shaman.HealingWave[12].id, 331, "HW tail 331")
assert_eq(#HV.RANKS.shaman.LesserHealingWave, 7, "LHW ladder 7 ranks")
assert_eq(HV.RANKS.shaman.LesserHealingWave[1].id, 25420, "LHW head 25420")
assert_eq(#HV.RANKS.druid.HealingTouch, 13, "HT ladder 13 ranks")
assert_eq(HV.RANKS.druid.HealingTouch[1].id, 26979, "HT head 26979")
assert_eq(HV.RANKS.druid.HealingTouch[13].id, 5185, "HT tail 5185")
-- find_rank_by_id across the new families (ceiling path used by lanes)
assert_true(HV.find_rank_by_id(25420) and HV.find_rank_by_id(25420).rank == 7, "find 25420 -> LHW R7")
assert_true(HV.find_rank_by_id(5189) and HV.find_rank_by_id(5189).rank == 5, "find 5189 -> HT R5")
-- Mid-rank discriminators (legacy first-ready walk would cast the head):
-- HW deficit 1500: R11 1879 > 1950? no fits -> ... probe: 25391
local mk_fake = function(id) return { id = id } end
assert_eq(HV.heal_rank_for_deficit(HV.build_ladder("shaman", "HealingWave", mk_fake), 1500, 0).id, 25391, "HW deficit 1500 -> R11 (mid-rank fit)")
assert_eq(HV.heal_rank_for_deficit(HV.build_ladder("shaman", "LesserHealingWave", mk_fake), 800, 0).id, 10468, "LHW deficit 800 -> R6 (mid-rank fit)")
-- HT deficit 2000: R12 2614 > 2600 bar overshoots -> R11 2509. Legacy would cast R13.
assert_eq(HV.heal_rank_for_deficit(HV.build_ladder("druid", "HealingTouch", mk_fake), 2000, 0).id, 25297, "HT deficit 2000 -> R11 (R12 overshoots: Wowhead-corrected tail is load-bearing)")
-- Huge deficit -> head; nil deficit -> head (legacy max-rank)
assert_eq(HV.heal_rank_for_deficit(HV.build_ladder("druid", "HealingTouch", mk_fake), 100000, 0).id, 26979, "HT huge deficit -> R13")
assert_eq(HV.heal_rank_for_deficit(HV.build_ladder("shaman", "HealingWave", mk_fake), nil, 0).id, 25396, "HW nil deficit -> R12 (legacy max-rank)")
-- Ceiling path over the new ladders (mana-tier cap semantics)
local ht_ladder = HV.build_ladder("druid", "HealingTouch", mk_fake)
local ceil12 = HV.find_rank_by_id(26978)
local fitc = HV.pick_castable(ht_ladder, 100000, 0, { ceiling = ceil12 })
assert_eq(fitc.entry.id, 26978, "HT ceiling R12: oversized deficit lands on the ceiling rank")
local fitd = HV.pick_castable(ht_ladder, 2000, 0, { ceiling = ceil12 })
assert_eq(fitd.entry.id, 25297, "HT ceiling R12: deficit 2000 still refines to R11 below the cap")
-- Hook end-to-end over the new families (NS.spell_ready stubbed above)
local built_hw = HV.build_ladder("shaman", "HealingWave", function(id) return NS.spell_action({ name = "HealingWave", ids = { id } }) end)
local hook_pick = NS.cast_best_heal_rank(built_hw, { unit = unit3 }, { settings = {} }, "T")
assert_true(hook_pick and hook_pick._meta and hook_pick._meta.id[1] == 25391, "hook deficit-fit picks HW R11 at deficit 1700 (mid-rank, legacy would pick R12)")
local built_ht = HV.build_ladder("druid", "HealingTouch", function(id) return NS.spell_action({ name = "HealingTouch", ids = { id } }) end)
local hook_ht = NS.cast_best_heal_rank(built_ht, { unit = unit3 }, { settings = {} }, "T")
-- deficit 1700, bar 2210: R13 2961 / R12 2614 / R11 2509 all overshoot;
-- R10 9889 (penalized 2003) fits -> R10, a deeper mid-rank proof.
assert_true(hook_ht and hook_ht._meta and hook_ht._meta.id[1] == 9889, "hook deficit-fit picks HT R10 at deficit 1700 (R11 overshoots)")

print("PASS test_heal_value_ranks")
