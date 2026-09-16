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
-- 7. Vanilla-era heal-value wiring: the era alias, the level-60 learn
--    ceiling, and the era-less TBC calls staying byte-identical. Evidence:
--    GH 25314 classic 1966-2194 vs TBC 2006-2235 @710 (Wowhead classic page
--    read 2026-09-15); GH R6/R7 (25210 L63, 25213 L68) and FH R8/R9
--    (25233 L61, 25235 L67) are TBC tails a level-60 vanilla client cannot
--    learn, so the vanilla build drops them at build time.
-- ---------------------------------------------------------------------------
do
    local GH_VAN = HV.build_ladder("priest", "GreaterHeal", mk_action("GreaterHeal"), nil, "vanilla", 60)
    assert_true(GH_VAN ~= nil, "vanilla GH ladder constructs")
    assert_eq(#GH_VAN, 1, "vanilla GH ladder carries only the level-60 row (R6/R7 tail dropped)")
    assert_eq(GH_VAN[1].id, 25314, "vanilla GH ladder's row is 25314")
    assert_eq(GH_VAN[1].base_min, 1966, "vanilla GH R5 base_min is the classic 1966 (25314 override applied)")
    assert_eq(GH_VAN[1].base_max, 2194, "vanilla GH R5 base_max is the classic 2194")
    assert_eq(GH_VAN[1].cost, 710, "vanilla GH R5 cost 710 (verified identical both eras)")
    assert_eq(GH_VAN[1].level, 60, "boundary: level == max_level (60) is kept")

    local FH_VAN = HV.build_ladder("priest", "FlashHeal", mk_action("FlashHeal"), nil, "vanilla", 60)
    assert_true(FH_VAN ~= nil, "vanilla FH ladder constructs")
    assert_eq(#FH_VAN, 7, "vanilla FH ladder keeps R1-R7 (R8/R9 tail dropped)")
    local van_ranks = {}
    for _, e in ipairs(FH_VAN) do van_ranks[e.id] = e.rank end
    assert_eq(van_ranks[25235], nil, "FH R9 25235 (level 67) dropped at ceiling 60")
    assert_eq(van_ranks[25233], nil, "FH R8 25233 (level 61) dropped at ceiling 60")
    assert_eq(van_ranks[2061], 1, "FH R1 2061 survives the ceiling")
    assert_eq(van_ranks[10917], 7, "FH R7 10917 survives the ceiling")
    local r7v = nil
    for _, e in ipairs(FH_VAN) do if e.id == 10917 then r7v = e end end
    assert_eq(r7v.base_min, 828, "vanilla FH R7 keeps the corrected classic 828")

    -- TBC (era-less, unlimited) stays byte-identical, including the
    -- vanilla-divergent 25314 keeping its TBC values.
    local GH_TBC = HV.build_ladder("priest", "GreaterHeal", mk_action("GreaterHeal"))
    assert_eq(#GH_TBC, 3, "era-less GH ladder keeps R5-R7")
    local r5 = nil
    for _, e in ipairs(GH_TBC) do if e.id == 25314 then r5 = e end end
    assert_eq(r5.base_min, 2006, "era-less GH R5 keeps the TBC 2006")
    assert_eq(r5.base_max, 2235, "era-less GH R5 keeps the TBC 2235")
    assert_eq(HV.find_rank_by_id(25314).base_min, 2006, "find_rank_by_id(25314) stays TBC-authoritative")

    -- Alias is fail-closed: an unknown era name applies nothing.
    local GH_BOGUS = HV.build_ladder("priest", "GreaterHeal", mk_action("GreaterHeal"), nil, "vanilla_classic")
    local r5b = nil
    for _, e in ipairs(GH_BOGUS) do if e.id == 25314 then r5b = e end end
    assert_eq(r5b.base_min, 2006, "unknown era applies no override (fail-closed alias)")

    -- max_level boundary at the row level: level 63 kept, 68 dropped; nil
    -- ceiling (TBC call shape) keeps every row.
    local GH_M63 = HV.build_ladder("priest", "GreaterHeal", mk_action("GreaterHeal"), nil, nil, 63)
    assert_eq(#GH_M63, 2, "max_level 63 keeps levels 60+63, drops 68")
    local GH_M68 = HV.build_ladder("priest", "GreaterHeal", mk_action("GreaterHeal"), nil, nil, 68)
    assert_eq(#GH_M68, 3, "max_level 68 keeps every GH row")
end

-- ---------------------------------------------------------------------------
-- 8. WotLK priest fit (2026-09-16 wave): era-distinct FH/GH families, the
--    wrath penalty branch, and the real hook + real spec lanes at
--    player_level 80.
-- ---------------------------------------------------------------------------
do
    local saved = {}
    for k, v in pairs(common) do NS[k] = v; saved[k] = v end
    NS.HealValue = NS.HealValue or HV
    NS.cast_best_heal_rank = NS.cast_best_heal_rank or CAST_HOOK
    local wfh = HV.build_ladder("priest", "WotlkFlashHeal", mk_action("FlashHeal"))
    local wgh = HV.build_ladder("priest", "WotlkGreaterHeal", mk_action("GreaterHeal"))
    assert_eq(#wfh, 10, "WotLK FH ladder carries 10 ranks (R1-R10)")
    assert_eq(#wgh, 8, "WotLK GH ladder carries 8 ranks (R1-R8)")
    assert_eq(wfh[1].id, 48071, "WotLK FH head is 48071")
    assert_eq(wgh[1].id, 48063, "WotLK GH head is 48063")
    assert_eq(wgh[4].base_min, 2006, "WotLK GH R5 25314 keeps the TBC-agreeing 2006 (ladder index 4, newest-first)")
    assert_eq(wgh[2].base_min, 2433, "WotLK GH R7 25213 carries the wrath 2433 (ladder index 2)")
    assert_eq(wfh[2].base_min, 1121, "WotLK FH R9 25235 carries the wrath 1121")
    -- Era isolation both directions: the TBC families and find_rank_by_id
    -- keep their TBC-authoritative values (no sod/wotlk bucket was needed --
    -- the wotlk rows agree with TBC wherever both eras have the id, except
    -- the two retunes which live only in the wotlk families).
    local tbc_gh = HV.build_ladder("priest", "GreaterHeal", mk_action("GreaterHeal"))
    assert_eq(#tbc_gh, 3, "TBC GH family unchanged (3 rows)")
    local r48071 = HV.find_rank_by_id(48071)
    assert_true(r48071 ~= nil and r48071.base_min == 1896, "find_rank_by_id resolves corpus-wide (48071 -> wotlk row 1896)")
    assert_eq(HV.find_rank_by_id(25213).base_min, 2414, "find_rank_by_id(25213) stays the TBC 2414")

    -- Wrath penalty branch (downrank_penalty, playerLevel > 70): the LHC-4.0
    -- isWrath factor REPLACES the classic/TBC factors entirely.
    local PRE = NS.PreemptiveHeal
    assert_true(PRE and type(PRE.downrank_penalty) == "function", "preemptive heal module loaded")
    assert_eq(PRE.downrank_penalty(79, 80), 1.0, "wrath: level 79 rank at 80 -> 1.0")
    assert_eq(PRE.downrank_penalty(60, 80), 0.35, "wrath: level 60 rank at 80 -> 0.35 (22+65-80)/20")
    assert_eq(PRE.downrank_penalty(20, 80), 0.0, "wrath: level 20 rank at 80 clamps to 0")
    assert_eq(PRE.downrank_penalty(56, 70), (56 + 11) / 70, "classic/TBC path unchanged at 70 ((56+11)/70)")
    assert_true(PRE.downrank_penalty(10, 60) < 1.0, "classic/TBC path keeps the sub-20 factor at 60")

    -- Real hook at 80 (spell_ready restored to all-true via common).
    local pick80 = function(ranks, d, extra)
        local opts = { player_level = 80 }
        if type(extra) == "table" then for k2, v2 in pairs(extra) do opts[k2] = v2 end end
        local s, l = CAST_HOOK(ranks, { unit = unit(d) }, ctx, "T", opts)
        return l
    end
    -- GH expected at 80, bonus 0: R1 981.5 R2 1248 R3 1395 R5 2120.5
    -- R6 2275.5 R7 2627.5 R8 4300.5; the walk is newest-first with the
    -- 1.3 tolerance bar (deficit * 1.3).
    assert_eq(pick80(wgh, 500), "T R8", "GH deficit 500 -> no rank fits (smallest 981.5 > bar 650) -> overshoot fallback head R8")
    assert_eq(pick80(wgh, 900), "T R1", "GH deficit 900 -> R1 (981.5 <= 1170)")
    assert_eq(pick80(wgh, 1000), "T R2", "GH deficit 1000 -> R2")
    assert_eq(pick80(wgh, 1700), "T R5", "GH deficit 1700 -> R5 (bar 2210 < R6 2275.5)")
    assert_eq(pick80(wgh, 2000), "T R6", "GH deficit 2000 -> R6")
    assert_eq(pick80(wgh, 2350), "T R7", "GH deficit 2350 -> R7 (wrath 2433-2822)")
    assert_eq(pick80(wgh, 3800), "T R8", "GH deficit 3800 -> R8 head")
    -- FH expected at 80: R4 453 R5 583.5 R6 722.5 R7 906 R8 1004.5
    -- R9 1210.5 R10 2049.5.
    assert_eq(pick80(wfh, 440), "T R4", "FH deficit 440 -> R4")
    assert_eq(pick80(wfh, 600), "T R6", "FH deficit 600 -> R6 (722.5 <= bar 780, newest-first beats R5)")
    assert_eq(pick80(wfh, 900), "T R8", "FH deficit 900 -> R8 (bar 1170 < R9 1210.5)")
    assert_eq(pick80(wfh, 1500), "T R9", "FH deficit 1500 -> R9 (wrath 1121-1300)")
    assert_eq(pick80(wfh, 2500), "T R10", "FH deficit 2500 -> R10 head")
    -- Default-divisor isolation: WITHOUT the opt the hook defaults to 70;
    -- the wrath application is chosen by that divisor, and since every
    -- wotlk row carries DBC SpellLevel 80 (factor 1.0 at any caster <= 82)
    -- the base-only math is identical either way.
    assert_eq(pick80(wgh, 1700, {}), "T R5", "deficit fit stable across the default-divisor path")

    -- Spec lanes through the real modules: deficits pick mid ranks; the
    -- nil-deficit shape falls back to the exact legacy max-rank casts
    -- (lane conditions untouched).
    local holy_registry = { playstyles = {} }
    function holy_registry:register(name, strategies, options)
        self.playstyles[name] = strategies; self.options = self.options or {}
        self.options[name] = options
    end
    NS.rotation_registry = holy_registry
    local log = {}
    NS.try_cast = function(spell, target, reason)
        log[#log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end
    local holy = load_spec("classes/priest/holy_wotlk")
    local hlanes = {}
    for _, s in ipairs(holy.playstyles and holy.playstyles.holy or holy_registry.playstyles.holy or {}) do hlanes[s.name] = s end
    local gh_ally = { get_max_health = function(self) return 12000 end, get_health = function(self) return 10300 end } -- deficit 1700
    local fh_ally = { get_max_health = function(self) return 12000 end, get_health = function(self) return 11100 end } -- deficit 900
    hlanes.GreaterHeal.execute({ lowest = { unit = gh_ally }, mana_pct = 90, settings = {} }, {})
    assert_true(action_id(log[1].spell) == 25314, "holy GH lane deficit 1700 fits R5 (25314), not the 48063 head")
    hlanes.FlashHeal.execute({ lowest = { unit = fh_ally }, mana_pct = 90, settings = {} }, {})
    assert_true(action_id(log[2].spell) == 25233, "holy FH lane deficit 900 fits R8 (25233), not the 48071 head")
    local full = { get_max_health = function(self) return 12000 end, get_health = function(self) return 12000 end }
    hlanes.GreaterHeal.execute({ lowest = { unit = full }, mana_pct = 90, settings = {} }, {})
    assert_true(action_id(log[3].spell) == 48063, "holy GH lane nil deficit -> legacy max-rank 48063")

    local disc_registry = { playstyles = {} }
    function disc_registry:register(name, strategies, options)
        self.playstyles[name] = strategies; self.options = self.options or {}
        self.options[name] = options
    end
    NS.rotation_registry = disc_registry
    local dlog = {}
    NS.try_cast = function(spell, target, reason)
        dlog[#dlog + 1] = { spell = spell, target = target, reason = reason }
        return true
    end
    local disc = load_spec("classes/priest/discipline_wotlk")
    local dlanes = {}
    for _, s in ipairs(disc.playstyles and disc.playstyles.discipline or disc_registry.playstyles.discipline or {}) do dlanes[s.name] = s end
    dlanes.GreaterHeal.execute({ lowest = { unit = gh_ally }, mana_pct = 90, settings = {} }, {})
    assert_true(action_id(dlog[1].spell) == 25314, "disc GH lane deficit 1700 fits R5 (25314)")
    dlanes.FlashHeal.execute({ lowest = { unit = fh_ally }, mana_pct = 90, settings = {} }, {})
    assert_true(action_id(dlog[2].spell) == 25233, "disc FH lane deficit 900 fits R8 (25233)")

    for k in pairs(saved) do NS[k] = nil end
    NS.HealValue = nil
    NS.cast_best_heal_rank = nil
    for k, v in pairs(saved) do NS[k] = v end
end

-- ---------------------------------------------------------------------------
-- 9. Vanilla resto druid fit (2026-09-16 wave): the learn-capped classic HT
--    ladder (era vanilla + max 60, the priest section-7 precedent) and the
--    real hook picking mid ranks at the level-60 divisor. Evidence: HT R13
--    25297 classic 2267-2677 vs TBC 2303-2714 and R10 9889 classic 1916-2257
--    vs TBC 1923-2263 (Wowhead classic pages read 2026-09-15); R12/R13
--    (levels 62/69) unlearnable at 60. TBC practice mirror: Warcraft Tavern
--    ("experiment with different ranks ... do just enough healing").
-- ---------------------------------------------------------------------------
do
    NS.HealValue = HV
    local HT_VAN = HV.build_ladder("druid", "HealingTouch", mk_action("HealingTouch"), nil, "vanilla", 60)
    assert_true(HT_VAN ~= nil, "vanilla HT ladder constructs")
    assert_eq(#HT_VAN, 11, "vanilla HT ladder carries R1-R11 (R12/R13 tail dropped)")
    assert_eq(HT_VAN[1].id, 25297, "vanilla HT head is R11 25297")
    assert_eq(HT_VAN[1].level, 60, "boundary: level == max_level (60) is kept")
    assert_eq(HT_VAN[1].base_min, 2267, "vanilla HT R11 base_min is the classic 2267 (override applied)")
    assert_eq(HT_VAN[1].base_max, 2677, "vanilla HT R11 base_max is the classic 2677")
    local van_ranks = {}
    for _, e in ipairs(HT_VAN) do van_ranks[e.id] = e.rank end
    assert_eq(van_ranks[26979], nil, "HT R13 26979 (level 69) dropped at ceiling 60")
    assert_eq(van_ranks[26978], nil, "HT R12 26978 (level 62) dropped at ceiling 60")
    assert_eq(van_ranks[5185], 1, "HT R1 5185 survives the ceiling")
    local r10v = nil
    for _, e in ipairs(HT_VAN) do if e.id == 9889 then r10v = e end end
    assert_eq(r10v.base_min, 1916, "vanilla HT R10 keeps the corrected classic 1916")
    assert_eq(r10v.base_max, 2257, "vanilla HT R10 keeps the corrected classic 2257")

    -- TBC era-less ladder stays byte-identical (13 ranks, TBC values).
    local HT_TBC = HV.build_ladder("druid", "HealingTouch", mk_action("HealingTouch"))
    assert_eq(#HT_TBC, 13, "era-less HT ladder keeps R1-R13")
    assert_eq(HT_TBC[1].id, 26979, "era-less HT head stays R13 26979")
    assert_eq(HV.find_rank_by_id(25297).base_min, 2303, "find_rank_by_id(25297) stays TBC-authoritative")

    -- Real hook at the level-60 divisor, bonus 0 (classic penalty applied).
    local pick60 = function(ranks, d, extra)
        local opts = { player_level = 60 }
        if type(extra) == "table" then for k2, v2 in pairs(extra) do opts[k2] = v2 end end
        local s, l = CAST_HOOK(ranks, { unit = unit(d) }, ctx, "T", opts)
        return l
    end
    assert_eq(pick60(HT_VAN, 2000), "T R11", "HT deficit 2000 -> R11 head (2472 <= bar 2600)")
    assert_eq(pick60(HT_VAN, 1500), "T R9", "HT deficit 1500 -> R9 (bar 1950 < R10 2086.5)")
    assert_eq(pick60(HT_VAN, 800), "T R7", "HT deficit 800 -> R7 (858 <= bar 1040)")
    assert_eq(pick60(HT_VAN, 400), "T R5", "HT deficit 400 -> R5 (bar 520 < R6 ~600)")
    assert_eq(pick60(HT_VAN, 150), "T R3", "HT deficit 150 -> R3 (bar 195 < R4 ~215)")
    NS.HealValue = nil
end

-- ---------------------------------------------------------------------------
-- 10. Vanilla resto shaman fit (2026-09-16 wave): the learn-capped classic
--    HW/LHW ladders (era vanilla + max 60, the priest/druid precedent) and
--    the real hook picking mid ranks at the level-60 divisor. Evidence: HW
--    R10 25357 classic 1620-1850 vs TBC 1647-1878, HW R9 10396 classic
--    1389-1583 vs TBC 1394-1589, LHW R6 10468 classic 832-928 @380 vs TBC
--    853-949 (cost nil) -- Wowhead classic pages read 2026-09-15; every
--    other HW/LHW id agrees exactly. HW R11/R12 (levels 63/70) and LHW R7
--    (level 66) unlearnable at 60. TBC practice mirror: Warcraft Tavern
--    ("experiment with different ranks ... do just enough healing").
-- ---------------------------------------------------------------------------
do
    NS.HealValue = HV
    local HW_VAN = HV.build_ladder("shaman", "HealingWave", mk_action("HealingWave"), nil, "vanilla", 60)
    assert_true(HW_VAN ~= nil, "vanilla HW ladder constructs")
    assert_eq(#HW_VAN, 10, "vanilla HW ladder carries R1-R10 (R11/R12 tail dropped)")
    assert_eq(HW_VAN[1].id, 25357, "vanilla HW head is R10 25357")
    assert_eq(HW_VAN[1].level, 60, "boundary: level == max_level (60) is kept")
    assert_eq(HW_VAN[1].base_min, 1620, "vanilla HW R10 base_min is the classic 1620 (override applied)")
    assert_eq(HW_VAN[1].base_max, 1850, "vanilla HW R10 base_max is the classic 1850")
    local hw_ranks = {}
    for _, e in ipairs(HW_VAN) do hw_ranks[e.id] = e.rank end
    assert_eq(hw_ranks[25396], nil, "HW R12 25396 (level 70) dropped at ceiling 60")
    assert_eq(hw_ranks[25391], nil, "HW R11 25391 (level 63) dropped at ceiling 60")
    assert_eq(hw_ranks[331], 1, "HW R1 331 survives the ceiling")
    local r9v = nil
    for _, e in ipairs(HW_VAN) do if e.id == 10396 then r9v = e end end
    assert_eq(r9v.base_min, 1389, "vanilla HW R9 keeps the corrected classic 1389")
    assert_eq(r9v.base_max, 1583, "vanilla HW R9 keeps the corrected classic 1583")

    local LHW_VAN = HV.build_ladder("shaman", "LesserHealingWave", mk_action("LesserHealingWave"), nil, "vanilla", 60)
    assert_true(LHW_VAN ~= nil, "vanilla LHW ladder constructs")
    assert_eq(#LHW_VAN, 6, "vanilla LHW ladder carries R1-R6 (R7 tail dropped)")
    assert_eq(LHW_VAN[1].id, 10468, "vanilla LHW head is R6 10468")
    assert_eq(LHW_VAN[1].base_min, 832, "vanilla LHW R6 base_min is the classic 832 (override applied)")
    assert_eq(LHW_VAN[1].base_max, 928, "vanilla LHW R6 base_max is the classic 928")
    assert_eq(LHW_VAN[1].cost, 380, "vanilla LHW R6 cost 380 (read off the classic page)")
    local lhw_ranks = {}
    for _, e in ipairs(LHW_VAN) do lhw_ranks[e.id] = e.rank end
    assert_eq(lhw_ranks[25420], nil, "LHW R7 25420 (level 66) dropped at ceiling 60")
    assert_eq(lhw_ranks[8004], 1, "LHW R1 8004 survives the ceiling")

    -- TBC era-less ladders stay byte-identical (12 + 7 ranks, TBC values).
    local HW_TBC = HV.build_ladder("shaman", "HealingWave", mk_action("HealingWave"))
    assert_eq(#HW_TBC, 12, "era-less HW ladder keeps R1-R12")
    assert_eq(HW_TBC[1].id, 25396, "era-less HW head stays R12 25396")
    assert_eq(HV.find_rank_by_id(25357).base_min, 1647, "find_rank_by_id(25357) stays TBC-authoritative")
    local LHW_TBC = HV.build_ladder("shaman", "LesserHealingWave", mk_action("LesserHealingWave"))
    assert_eq(#LHW_TBC, 7, "era-less LHW ladder keeps R1-R7")
    assert_eq(LHW_TBC[1].id, 25420, "era-less LHW head stays R7 25420")

    -- Real hook at the level-60 divisor, bonus 0 (classic penalty applied).
    local pick60 = function(ranks, d, extra)
        local opts = { player_level = 60 }
        if type(extra) == "table" then for k2, v2 in pairs(extra) do opts[k2] = v2 end end
        local s, l = CAST_HOOK(ranks, { unit = unit(d) }, ctx, "T", opts)
        return l
    end
    assert_eq(pick60(HW_VAN, 1500), "T R10", "HW deficit 1500 -> R10 head (1735 <= bar 1950)")
    assert_eq(pick60(HW_VAN, 1000), "T R8", "HW deficit 1000 -> R8 (bar 1300 < R9 1486)")
    assert_eq(pick60(HW_VAN, 500), "T R6", "HW deficit 500 -> R6 (bar 650 < R7 ~694)")
    assert_eq(pick60(HW_VAN, 250), "T R5", "HW deficit 250 -> R5 (bar 325 < R6 ~427)")
    assert_eq(pick60(HW_VAN, 100), "T R3", "HW deficit 100 -> R3 (bar 130 < R4 ~136)")
    assert_eq(pick60(LHW_VAN, 700), "T R6", "LHW deficit 700 -> R6 head (880 <= bar 910)")
    NS.HealValue = nil
end

-- ---------------------------------------------------------------------------
-- 11. Vanilla holy paladin fit (2026-09-16 wave): the learn-capped classic
--    HL/FoL ladders (era vanilla + max 60, the priest/druid/shaman precedent)
--    and the real hook picking mid ranks at the level-60 divisor with the
--    1.12 Healing Light talent mult. Evidence: nether.wowhead.com classic
--    tooltips read 2026-09-16 — every vanilla-reachable HL/FoL id checked;
--    only HL R9 25292 (classic 1590-1770 vs TBC 1619-1799) and FoL R6 19943
--    (classic 348-389 vs TBC 356-396) diverge. All others agree exactly
--    (HL R8 1272-1414, R7 968-1076, R6 717-799, R5 506-569, R4 322-368;
--    FoL R5 278-310, R4 206-231, R3 153-171, R2 102-117). HL R1-R3 and FoL
--    R1 carry no TBC base rows, so no override is recorded (the era-less TBC
--    ladder shape stays byte-identical). TBC practice mirror: wowhead classic
--    holy guide ("If your target is missing 200 health, you should not cast
--    a max rank Holy Light ... cast a lower rank of Flash of Light").
-- ---------------------------------------------------------------------------
do
    NS.HealValue = HV
    local HL_VAN = HV.build_ladder("paladin", "HolyLight", mk_action("HolyLight"), 1.12, "vanilla", 60)
    assert_true(HL_VAN ~= nil, "vanilla HL ladder constructs")
    assert_eq(#HL_VAN, 6, "vanilla HL ladder carries R4-R9 (R10/R11 tail dropped, R1-R3 never in family)")
    assert_eq(HL_VAN[1].id, 25292, "vanilla HL head is R9 25292")
    assert_eq(HL_VAN[1].level, 60, "boundary: level == max_level (60) is kept")
    assert_eq(HL_VAN[1].base_min, 1590, "vanilla HL R9 base_min is the classic 1590 (override applied)")
    assert_eq(HL_VAN[1].base_max, 1770, "vanilla HL R9 base_max is the classic 1770")
    local hl_ranks = {}
    for _, e in ipairs(HL_VAN) do hl_ranks[e.id] = e.rank end
    assert_eq(hl_ranks[27136], nil, "HL R11 27136 (level 70) dropped at ceiling 60")
    assert_eq(hl_ranks[27135], nil, "HL R10 27135 (level 62) dropped at ceiling 60")
    assert_eq(hl_ranks[1026], 4, "HL R4 1026 survives the ceiling")
    local r8v = nil
    for _, e in ipairs(HL_VAN) do if e.id == 10329 then r8v = e end end
    assert_eq(r8v.base_min, 1272, "vanilla HL R8 keeps the agreeing 1272 (no override)")

    local FOL_VAN = HV.build_ladder("paladin", "FlashOfLight", mk_action("FlashOfLight"), 1.12, "vanilla", 60)
    assert_true(FOL_VAN ~= nil, "vanilla FoL ladder constructs")
    assert_eq(#FOL_VAN, 5, "vanilla FoL ladder carries R2-R6 (R7 tail dropped, R1 never in family)")
    assert_eq(FOL_VAN[1].id, 19943, "vanilla FoL head is R6 19943")
    assert_eq(FOL_VAN[1].base_min, 348, "vanilla FoL R6 base_min is the classic 348 (override applied)")
    assert_eq(FOL_VAN[1].base_max, 389, "vanilla FoL R6 base_max is the classic 389")
    local fol_ranks = {}
    for _, e in ipairs(FOL_VAN) do fol_ranks[e.id] = e.rank end
    assert_eq(fol_ranks[27137], nil, "FoL R7 27137 (level 66) dropped at ceiling 60")
    assert_eq(fol_ranks[19939], 2, "FoL R2 19939 survives the ceiling")

    -- TBC era-less ladders stay byte-identical (8 + 6 ranks, TBC values).
    local HL_TBC = HV.build_ladder("paladin", "HolyLight", mk_action("HolyLight"), 1.12)
    assert_eq(#HL_TBC, 8, "era-less HL ladder keeps R4-R11")
    assert_eq(HL_TBC[1].id, 27136, "era-less HL head stays R11 27136")
    assert_eq(HV.find_rank_by_id(25292).base_min, 1619, "find_rank_by_id(25292) stays TBC-authoritative")
    local FOL_TBC = HV.build_ladder("paladin", "FlashOfLight", mk_action("FlashOfLight"), 1.12)
    assert_eq(#FOL_TBC, 6, "era-less FoL ladder keeps R2-R7")
    assert_eq(FOL_TBC[1].id, 27137, "era-less FoL head stays R7 27137")
    assert_eq(HV.find_rank_by_id(19943).base_min, 356, "find_rank_by_id(19943) stays TBC-authoritative")

    -- Real hook at the level-60 divisor with the 1.12 talent mult, bonus 0.
    local pick60 = function(ranks, d, extra)
        local opts = { player_level = 60 }
        if type(extra) == "table" then for k2, v2 in pairs(extra) do opts[k2] = v2 end end
        local s, l = CAST_HOOK(ranks, { unit = unit(d) }, ctx, "T", opts)
        return l
    end
    -- NOTE: build_ladder entries carry talent_mult, but the hook resolves
    -- bonus/penalty through expected_heal_ladder which reads entry fields —
    -- the 1.12 mult is baked into the entries above, so plain pick60 applies.
    assert_eq(pick60(HL_VAN, 1500), "T R9", "HL deficit 1500 -> R9 head (1882 <= bar 1950)")
    assert_eq(pick60(HL_VAN, 1000), "T R7", "HL deficit 1000 -> R7 (bar 1300 < R8 1504)")
    assert_eq(pick60(HL_VAN, 500), "T R5", "HL deficit 500 -> R5 (bar 650 < R6 693)")
    assert_eq(pick60(HL_VAN, 250), "T R4", "HL deficit 250 -> R4 tail (213 <= bar 325)")
    assert_eq(pick60(FOL_VAN, 700), "T R6", "FoL deficit 700 -> R6 head (413 <= bar 910)")
    assert_eq(pick60(FOL_VAN, 300), "T R5", "FoL deficit 300 -> R5 (bar 390 < R6 413)")
    assert_eq(pick60(FOL_VAN, 150), "T R3", "FoL deficit 150 -> R3 (bar 195 < R4 216)")
    NS.HealValue = nil
end

-- ---------------------------------------------------------------------------
print(("# test_sod_healer_rank_fit: %d passed, %d failed"):format(pass, fail))
if fail > 0 then error("test_sod_healer_rank_fit failed", 0) end
print("PASS test_sod_healer_rank_fit")
