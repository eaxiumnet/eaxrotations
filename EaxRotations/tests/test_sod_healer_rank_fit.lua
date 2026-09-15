-- test_sod_healer_rank_fit.lua -- pins for the 2026-09-15 SoD healer wave.
-- WHAT:  SoD shaman/druid/priest deficit-fit rank selection end to end --
--        fail-closed ladder construction from shared/heal_value_sylvanas
--        (full SoD id overlap proved in scoping; FH family extended with the
--        six classic ranks, bases Wowhead-verified), the real core hook
--        picking mid ranks at SoD's level-60 penalty divisor, the SoD lane
--        rewires, emergency lanes keeping their max-rank identity, Chain Heal
--        untouched, and the no-module fallback preserving the legacy cast.
-- WHEN:  standalone -- lua EaxRotations/tests/test_sod_healer_rank_fit.lua
-- WHY:   the fit changes what SoD healers cast; every claim is pinned so a
--        wrong rank id, a lost penalty divisor, or a legacy regression fails
--        loudly.
-- SAFETY: pure unit tests with mocked API context; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local pass, fail = 0, 0
local function assert_true(v, label)
    if v then pass = pass + 1 else fail = fail + 1; print("  FAIL: " .. tostring(label)) end
end
local function assert_eq(a, b, label)
    if a == b then pass = pass + 1
    else fail = fail + 1; print("  FAIL: " .. tostring(label) .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")") end
end

-- Minimal NS: real core hook + module, stubbed spell actions.
_G.EaxRotations = { settings = {} }
-- Minimal core: get_spell_id resolves through core.spell_book; the stub
-- reports every id learned so ladder walks reach the spell_ready stub.
_G.core = {
    time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    spell_book = { is_spell_learned = function() return true end },
}
local NS = _G.EaxRotations
NS.spell_action = function(ids, label)
    if type(ids) == "table" and ids.ids and not ids[1] then
        return { _meta = { id = ids.ids, ids = ids.ids, label = ids.name } }
    end
    local id = type(ids) == "table" and ids[1] or ids
    return { _meta = { id = { id }, ids = { id }, label = label } }
end
NS.spell_id_is_known = function() return true end
dofile("EaxRotations/core_sylvanas.lua")
assert_true(type(NS.cast_best_heal_rank) == "function", "core hook loads")
local CAST_HOOK = NS.cast_best_heal_rank
local HV = NS.HealValue
assert_true(HV and type(HV.build_ladder) == "function", "heal_value module installed")

NS.spell_ready = function() return true end
local ctx = { settings = {} }
local function unit(deficit)
    return {
        get_max_health = function(self) return 8000 end,
        get_health = function(self) return 8000 - deficit end,
    }
end
local function mk_action(name)
    return function(id) return NS.spell_action({ name = name, ids = { id } }) end
end
-- Read the first id off a mock action defensively: _meta.id is a table for
-- rich-format actions and a number for positional ones.
local function action_id(spell)
    local meta = type(spell) == "table" and spell._meta or nil
    if not meta then return nil end
    if type(meta.id) == "table" then return meta.id[1] end
    return meta.id
end

-- ---------------------------------------------------------------------------
-- 1. Ladder construction: fail-closed shapes with verified provenance.
-- ---------------------------------------------------------------------------
local FH = HV.build_ladder("priest", "FlashHeal", mk_action("FlashHeal"))
local HW = HV.build_ladder("shaman", "HealingWave", mk_action("HealingWave"))
local LHW = HV.build_ladder("shaman", "LesserHealingWave", mk_action("LesserHealingWave"))
local HT = HV.build_ladder("druid", "HealingTouch", mk_action("HealingTouch"))
assert_eq(#FH, 9, "FH ladder carries 9 ranks (3 TBC + 6 classic)")
assert_eq(#HW, 12, "HW ladder carries 12 ranks")
assert_eq(#LHW, 7, "LHW ladder carries 7 ranks")
assert_eq(#HT, 13, "HT ladder carries 13 ranks")
-- Classic FH ids present in rank order (R7 head of the classic block ... R1 tail).
assert_eq(FH[3].id, 10917, "FH R7 10917 in ladder")
assert_eq(FH[9].id, 2061, "FH R1 2061 in ladder")
-- Every SoD-reachable id in each ladder is a real Flash Heal / Healing Wave /
-- LHW / HT rank (the wrong-family regression the sweep exists to catch).
local FH_IDS = { [25235]=9,[25233]=8,[10917]=7,[10916]=6,[10915]=5,[9474]=4,[9473]=3,[9472]=2,[2061]=1 }
for _, e in ipairs(FH) do assert_eq(FH_IDS[e.id] or 0, e.rank, "FH id " .. tostring(e.id) .. " maps to its rank") end
-- Unknown family: fail-closed nil.
assert_true(HV.build_ladder("priest", "NoSuchSpell", mk_action("X")) == nil, "build_ladder unknown family -> nil")

-- ---------------------------------------------------------------------------
-- 2. Real-hook deficit fit at SoD's level-60 penalty divisor (probed values).
-- ---------------------------------------------------------------------------
local pick = function(ranks, d, extra)
    local opts = { player_level = 60 }
    if type(extra) == "table" then for k, v in pairs(extra) do opts[k] = v end end
    local s, l = NS.cast_best_heal_rank(ranks, { unit = unit(d) }, ctx, "T", opts)
    return l
end
assert_eq(pick(FH, 200), "T R3", "FH deficit 200 -> R3 (classic mid rank)")
assert_eq(pick(FH, 400), "T R4", "FH deficit 400 -> R4")
assert_eq(pick(FH, 600), "T R6", "FH deficit 600 -> R6")
assert_eq(pick(FH, 1200), "T R9", "FH deficit 1200 -> R9 (max TBC)")
assert_eq(pick(LHW, 150), "T R2", "LHW deficit 150 -> R2")
assert_eq(pick(LHW, 800), "T R6", "LHW deficit 800 -> R6")
assert_eq(pick(HW, 900), "T R8", "HW deficit 900 -> R8")
assert_eq(pick(HT, 2000), "T R11", "HT deficit 2000 -> R11 (Wowhead-corrected bases)")
-- Anti-overshoot rule: the cheapest rank UNDER the deficit bar wins, even
-- when it underheals (mana discipline); max rank only for large deficits.
assert_eq(pick(FH, 100), "T R1", "FH deficit 100 -> R1 (cheapest under bar)")

-- ---------------------------------------------------------------------------
-- 3. Level threading: the divisor is the CASTER level, not a constant 70.
-- ---------------------------------------------------------------------------
NS.spell_ready = function(sp)
    local ids = sp and sp._meta and sp._meta.ids or {}
    local classic = { [2061]=true,[9472]=true,[9473]=true,[9474]=true,[10915]=true,[10916]=true,[10917]=true }
    for _, id in ipairs(ids) do if classic[id] then return true end end
    return false
end
assert_eq(pick(FH, 250), "T R3", "classic-only caster at level 60 -> R3 fits (65/60 penalty)")
assert_eq(pick(FH, 250, { player_level = 70 }), "T R4", "same deficit at level 70 -> R4 (71/70 divisor)")
assert_eq(pick(FH, 100), "T R1", "classic-only tiny deficit -> max classic rank R1 under the bar")
NS.spell_ready = function() return true end

-- ---------------------------------------------------------------------------
-- 4. SoD lane rewires through the real spec modules.
-- ---------------------------------------------------------------------------
local function load_spec(path, extra_ns)
    for k, v in pairs(extra_ns or {}) do NS[k] = v end
    package.loaded[path] = nil
    return assert(require(path), "spec loads: " .. path)
end

local common = {
    is_sod = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    time_now = function() return 1000 end,
    spell_ready = function() return true end,
}

-- 4a. Priest: FH lane fits; rune heals untouched; execute falls back closed.
local priest_registry = { playstyles = {} }
function priest_registry:register(name, strategies, options)
    self.playstyles[name] = strategies; self.options = self.options or {}
    self.options[name] = options
end
do
    local saved = {}
    for k, v in pairs(common) do NS[k] = v; saved[k] = v end
    NS.rotation_registry = priest_registry
    NS.PLAYER_UNIT = "player"
    local fh_ids_logged = {}
    local log_ref
    NS.try_cast = function(spell, target, reason)
        log_ref[#log_ref + 1] = { spell = spell, reason = reason }
        return true
    end
    local priest = load_spec("classes/priest/healing_sod")
    local strategies = priest.playstyles and priest.playstyles.healing or priest_registry.playstyles.healing
    assert_true(strategies ~= nil, "priest healing strategies registered")
    local fh_strategy
    for _, s in ipairs(strategies) do if s.name == "FlashHeal" then fh_strategy = s end end
    assert_true(fh_strategy ~= nil, "FlashHeal lane present")
    log_ref = fh_ids_logged
    local ally = { get_max_health = function(self) return 8000 end, get_health = function(self) return 7400 end } -- deficit 600
    fh_strategy.execute({ lowest = { unit = ally } })
    local cast = fh_ids_logged[1]
    assert_true(cast ~= nil, "FH execute casts")
    assert_true(action_id(cast.spell) == 10916,
        "FH lane deficit 600 fits R6 (10916), not the max-rank action")
    -- Anti-overshoot: a tiny deficit routes to the cheapest rank, never the
    -- max-rank action (mana discipline at small deficits).
    local ally2 = { get_max_health = function(self) return 8000 end, get_health = function(self) return 7950 end }
    fh_strategy.execute({ lowest = { unit = ally2 } })
    assert_true(action_id(fh_ids_logged[2].spell) == 2061, "FH tiny deficit -> cheapest rank 2061 (R1)")
    for k in pairs(saved) do NS[k] = nil end
    for k, v in pairs(saved) do NS[k] = v end
end

-- 4b. Shaman: LHW/HW lanes fit; ChainHeal stays the single max-rank action.
local shaman_registry = { playstyles = {} }
function shaman_registry:register(name, strategies, options)
    self.playstyles[name] = strategies; self.options = self.options or {}
    self.options[name] = options
end
do
    for k, v in pairs(common) do NS[k] = v end
    NS.rotation_registry = shaman_registry
    local log = {}
    NS.try_cast = function(spell, target, reason)
        log[#log + 1] = { spell = spell, reason = reason }
        return true
    end
    load_spec("classes/shaman/restoration_sod")
    local strategies = shaman_registry.playstyles.restoration
    assert_true(strategies ~= nil, "shaman restoration strategies registered")
    local lanes = {}
    for _, s in ipairs(strategies) do lanes[s.name] = s end
    local ally = { get_max_health = function(self) return 8000 end, get_health = function(self) return 7200 end } -- deficit 800
    lanes.LesserHealingWave.execute({}, { heal_target = ally })
    assert_true(action_id(log[1].spell) == 10468,
        "LHW lane deficit 800 fits R6 (10468), not the max-rank action")
    lanes.HealingWave.execute({}, { heal_target = ally })
    assert_true(action_id(log[2].spell) == 8005,
        "HW lane deficit 800 fits R7 (8005)")
    -- Chain Heal untouched: single max-rank action (id head of its ladder).
    local ch = lanes.ChainHeal
    assert_true(ch ~= nil, "ChainHeal lane present")
    log[3] = nil
    ch.execute({}, { heal_target = ally })
    assert_true(action_id(log[3].spell) == 10623,
        "ChainHeal still casts the single max-rank action (10623)")
    for k in pairs(common) do NS[k] = nil end
end

-- 4c. Druid: the <=50% HT lane fits; the NS+HT emergency lane stays max-rank.
local druid_registry = { playstyles = {} }
function druid_registry:register(name, strategies, options)
    self.playstyles[name] = strategies; self.options = self.options or {}
    self.options[name] = options
end
do
    for k, v in pairs(common) do NS[k] = v end
    NS.rotation_registry = druid_registry
    NS.PLAYER_UNIT = "player"
    local log = {}
    NS.try_cast = function(spell, target, reason)
        log[#log + 1] = { spell = spell, reason = reason }
        return true
    end
    load_spec("classes/druid/restoration_sod")
    local strategies = druid_registry.playstyles.restoration
    assert_true(strategies ~= nil, "druid restoration strategies registered")
    local lanes = {}
    for _, s in ipairs(strategies) do lanes[s.name] = s end
    local ally = { get_max_health = function(self) return 8000 end, get_health = function(self) return 6000 end } -- deficit 2000
    lanes.HealingTouch.execute({ heal_target_hp_pct = 50, heal_target = ally, is_sod = true, sod_phase = 7, sod_runes = {} }, { heal_target = ally, heal_target_hp_pct = 50 })
    assert_true(action_id(log[1].spell) == 25297,
        "HT lane deficit 2000 fits R12 (25297)")
    -- NS+HT emergency lane: unchanged max-rank single action.
    lanes.NaturesSwiftnessHealingTouch.execute({ is_sod = true, sod_phase = 7, sod_runes = {}, heal_target = ally })
    assert_true(action_id(log[2].spell) == 25297,
        "NS+HT emergency lane keeps the max-rank single action")
    for k in pairs(common) do NS[k] = nil end
end

-- ---------------------------------------------------------------------------
-- 5. Fail-closed fallback: no module -> lanes keep the legacy single cast.
-- ---------------------------------------------------------------------------
local legacy_registry = { playstyles = {} }
function legacy_registry:register(name, strategies, options)
    self.playstyles[name] = strategies; self.options = self.options or {}
    self.options[name] = options
end
do
    for k, v in pairs(common) do NS[k] = v end
    NS.HealValue = nil
    NS.cast_best_heal_rank = nil
    NS.rotation_registry = legacy_registry
    local log = {}
    NS.try_cast = function(spell, target, reason)
        log[#log + 1] = { spell = spell, reason = reason }
        return true
    end
    load_spec("classes/priest/healing_sod")
    local strategies = legacy_registry.playstyles.healing
    local fh_strategy
    for _, s in ipairs(strategies) do if s.name == "FlashHeal" then fh_strategy = s end end
    local ally = { get_max_health = function(self) return 8000 end, get_health = function(self) return 7400 end }
    fh_strategy.execute({ lowest = { unit = ally } })
    -- Legacy descriptor.action carries _meta.id as a NUMBER (spec_kit single-id
    -- define); read it defensively so both id shapes are covered.
    local legacy_id = log[1] and type(log[1].spell) == "table" and log[1].spell._meta
        and (type(log[1].spell._meta.id) == "table" and log[1].spell._meta.id[1] or log[1].spell._meta.id)
        or nil
    assert_true(legacy_id == 10917,
        "no module: FH lane falls back to the legacy single R7 action (got " .. tostring(legacy_id) .. ")")
    for k in pairs(common) do NS[k] = nil end
end

-- ---------------------------------------------------------------------------
-- 6. Era-keyed overrides: the SoD client (classic dataset) yields different
--    values for ids the TBC client reuses. Verified 2026-09-15 on Wowhead:
--    HT 25297 classic 2267-2677 vs TBC row 2303-2714 (cost 800 both sides).
--    The override must reach era-built ladders, must NOT touch the TBC table
--    (find_rank_by_id / TBC consumers), and must fail closed.
-- ---------------------------------------------------------------------------
local HT_SOD = HV.build_ladder("druid", "HealingTouch", mk_action("HealingTouch"), nil, "sod")
assert_true(HT_SOD ~= nil, "era-built SoD HT ladder constructs")
local r11, r11_tbc = nil, nil
for _, e in ipairs(HT_SOD) do if e.id == 25297 then r11 = e end end
for _, e in ipairs(HT) do if e.id == 25297 then r11_tbc = e end end
assert_true(r11 ~= nil and r11_tbc ~= nil, "both ladders carry 25297")
assert_eq(r11.base_min, 2267, "SoD-built HT R11 base_min is the classic 2267")
assert_eq(r11.base_max, 2677, "SoD-built HT R11 base_max is the classic 2677")
assert_eq(r11.cost, 800, "SoD-built HT R11 cost 800 (verified identical both eras)")
assert_eq(r11.rank, 11, "override preserves the rank label")
-- The TBC table itself stays untouched: same call without the era arg.
assert_eq(r11_tbc.base_min, 2303, "no-era ladder keeps the TBC 2303 (TBC consumers unaffected)")
assert_eq(r11_tbc.base_max, 2714, "no-era ladder keeps the TBC 2714")
-- find_rank_by_id remains the TBC-table authority (its consumers are TBC).
assert_eq(HV.find_rank_by_id(25297).base_min, 2303, "find_rank_by_id stays TBC-authoritative")
-- Unknown era key: applies nothing (fail-closed), same shape as no era.
local HT_BOGUS = HV.build_ladder("druid", "HealingTouch", mk_action("HealingTouch"), nil, "wotlk")
for _, e in ipairs(HT_BOGUS) do
    if e.id == 25297 then assert_eq(e.base_min, 2303, "unknown era key applies no override") end
end
-- The SoD core hook still refines deficit 2000 to 25297 under the override
-- (mid 2472 <= 2000 x 1.3): the corrected values do not change the lane pick.
local spell_sod, lab_sod = CAST_HOOK(HT_SOD, unit(2000), { settings = {}, player_level = 60 }, "T", { bonus_healing = 0 })
assert_eq(lab_sod, "T R11", "SoD HT deficit 2000 still fits the corrected R11")
assert_true(spell_sod ~= nil and spell_sod == r11.spell, "returned action is the corrected R11 entry's spell")

local HW_SOD = HV.build_ladder("shaman", "HealingWave", mk_action("HealingWave"), nil, "sod")
local LHW_SOD = HV.build_ladder("shaman", "LesserHealingWave", mk_action("LesserHealingWave"), nil, "sod")
local function row_of(ladder, id)
    for _, e in ipairs(ladder) do if e.id == id then return e end end
end
-- HW R10 (25357): classic 1620-1850 vs TBC 1647-1878.
assert_eq(row_of(HW_SOD, 25357).base_min, 1620, "SoD HW R10 base_min is the classic 1620")
assert_eq(row_of(HW_SOD, 25357).base_max, 1850, "SoD HW R10 base_max is the classic 1850")
-- HW R9 (10396): classic 1389-1583 vs TBC 1394-1589 (divergence found in the 2026-09-15 sweep).
assert_eq(row_of(HW_SOD, 10396).base_min, 1389, "SoD HW R9 base_min is the classic 1389")
-- LHW R6 (10468): classic 832-928 vs TBC 853-949; cost 380 was nil in the TBC row.
assert_eq(row_of(LHW_SOD, 10468).base_min, 832, "SoD LHW R6 base_min is the classic 832")
assert_eq(row_of(LHW_SOD, 10468).base_max, 928, "SoD LHW R6 base_max is the classic 928")
assert_eq(row_of(LHW_SOD, 10468).cost, 380, "SoD LHW R6 cost filled from the classic page (380)")
-- Agreeing ids stay untouched by the override (spot: HW R8 10395, LHW R5 10467).
assert_eq(row_of(HW_SOD, 10395).base_min, 1040, "HW R8 10395 keeps the agreed base (1040)")
assert_eq(row_of(LHW_SOD, 10467).base_min, 649, "LHW R5 10467 keeps the agreed base (649)")
-- TBC table isolation: no-era ladder keeps the TBC values for all three ids.
assert_eq(row_of(HW, 25357).base_min, 1647, "no-era HW keeps TBC 1647 for 25357")
assert_eq(row_of(LHW, 10468).base_min, 853, "no-era LHW keeps TBC 853 for 10468")
-- Lane pick changes where the corrected size matters: at deficit 1350 the
-- corrected R10 (mid 1735 <= 1350 x 1.3 = 1755) now fits where the TBC-sized
-- R10 (mid 1762.5 > 1755) overshoots and the uncorrected ladder stays on R9.
local spell_hw, lab_hw = CAST_HOOK(HW_SOD, unit(1350), { settings = {}, player_level = 60 }, "T", { bonus_healing = 0 })
assert_eq(lab_hw, "T R10", "SoD HW deficit 1350 fits the corrected R10")
assert_true(spell_hw ~= nil and spell_hw == row_of(HW_SOD, 25357).spell, "HW action is the corrected R10 entry's spell")
-- Non-vacuity (the other direction): the same deficit on a no-era ladder
-- keeps the TBC-sized R10 overshooting and still picks R9.
local _, lab_tbc = CAST_HOOK(HW, unit(1350), { settings = {}, player_level = 60 }, "T", { bonus_healing = 0 })
assert_eq(lab_tbc, "T R9", "no-era HW at deficit 1350 still picks R9 (override is load-bearing)")

-- Full-ladder audit (2026-09-15): the two further divergences found by
-- sweeping every SoD-reachable id - HT 9889 (classic 1916-2257 vs TBC
-- 1923-2263) and FH 10917 (classic 828-975 vs TBC 833-979) - plus
-- agreeing-id isolation proving the sweep did not overreach.
local FH_SOD = HV.build_ladder("priest", "FlashHeal", mk_action("FlashHeal"), nil, "sod")
assert_true(FH_SOD ~= nil, "era-built SoD FH ladder constructs")
local r10, r10_tbc = nil, nil
for _, e in ipairs(HT_SOD) do if e.id == 9889 then r10 = e end end
for _, e in ipairs(HT) do if e.id == 9889 then r10_tbc = e end end
assert_true(r10 ~= nil and r10_tbc ~= nil, "both HT ladders carry 9889")
assert_eq(r10.base_min, 1916, "SoD-built HT R10 base_min is the classic 1916")
assert_eq(r10.base_max, 2257, "SoD-built HT R10 base_max is the classic 2257")
assert_eq(r10.cost, 720, "SoD-built HT R10 cost 720 (verified identical both eras)")
assert_eq(r10_tbc.base_min, 1923, "no-era HT ladder keeps the TBC 1923")
assert_eq(HV.find_rank_by_id(9889).base_min, 1923, "find_rank_by_id(9889) stays TBC-authoritative")
local r7f, r7f_tbc = nil, nil
for _, e in ipairs(FH_SOD) do if e.id == 10917 then r7f = e end end
for _, e in ipairs(FH) do if e.id == 10917 then r7f_tbc = e end end
assert_true(r7f ~= nil and r7f_tbc ~= nil, "both FH ladders carry 10917")
assert_eq(r7f.base_min, 828, "SoD-built FH R7 base_min is the classic 828")
assert_eq(r7f.base_max, 975, "SoD-built FH R7 base_max is the classic 975")
assert_eq(r7f.cost, 380, "SoD-built FH R7 cost 380 (verified identical both eras)")
assert_eq(r7f_tbc.base_min, 833, "no-era FH ladder keeps the TBC 833")
assert_eq(HV.find_rank_by_id(10917).base_min, 833, "find_rank_by_id(10917) stays TBC-authoritative")
-- Agreeing-id isolation, both directions.
local ht_r8, fh_r4 = nil, nil
for _, e in ipairs(HT_SOD) do if e.id == 9758 then ht_r8 = e end end
for _, e in ipairs(FH_SOD) do if e.id == 9474 then fh_r4 = e end end
assert_eq(ht_r8.base_min, 1225, "HT R8 9758 (verified agreeing) untouched")
assert_eq(fh_r4.base_min, 414, "FH R4 9474 (verified agreeing) untouched")

-- ---------------------------------------------------------------------------
print(("# test_sod_healer_rank_fit: %d passed, %d failed"):format(pass, fail))
if fail > 0 then error("test_sod_healer_rank_fit failed", 0) end
print("PASS test_sod_healer_rank_fit")
