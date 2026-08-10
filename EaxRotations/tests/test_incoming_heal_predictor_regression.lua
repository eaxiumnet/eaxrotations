-- test_incoming_heal_predictor_regression.lua — pins
-- shared/incoming_heal_predictor_sylvanas.lua.
-- WHAT:  Exercises the incoming-heal predictor's three sources and their
--        math: combat-log healer-preference EMA + 3-heal count gate +
--        SCAN_INTERVAL throttle + conservative 0.8 prediction amount;
--        party/visible cast scanning (heal-name detection, remaining-time
--        gating, per-healer preference fallback for missing targets, guid
--        dedup); the MAX_PREDICTIONS_PER_UNIT cap with oldest-arrival
--        eviction; prune-on-cleanup; native-API short-circuit; get /
--        get_detailed / get_arriving_before windowing; and clear().
--        Healer specs read NS.IncomingHeals.get(unit) every tick and the
--        module previously had ZERO test references.
-- WHEN:  rotation suite execution.
-- WHY:   a future edit to the EMA / throttle / horizon / cap arithmetic could
--        silently double-heal or over-cover deficits; this test fails on
--        regressions in the prediction math.
-- SAFETY: Pure unit test. The module caches NS and core at load and returns
--        early without NS, so a mock NS (time_now, GetPartyMembers, spell
--        helpers, CombatLogParser.subscribe) + mock core (time, spell_book,
--        object_manager) are installed BEFORE dofile. The real SDK is never
--        touched.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local now = 0.0
local party_units = {}
local visible_units = {}
local spell_names = {}
local spell_cast_times = {}
local subscribed = nil

local NS = {
    time_now = function() return now end,
    get_spell_name = function(id) return spell_names[id] end,
    GetPartyMembers = function() return party_units end,
    CombatLogParser = { subscribe = function(cb) subscribed = cb end },
}
_G.EaxRotations = NS
_G.core = {
    time = function() return now end,
    spell_book = {
        get_spell_name = function(id) return spell_names[id] end,
        get_spell_cast_time = function(id) return spell_cast_times[id] end,
    },
    object_manager = {
        get_visible_objects = function() return visible_units end,
    },
}

local ihp = dofile("EaxRotations/shared/incoming_heal_predictor_sylvanas.lua")
assert_true(type(ihp) == "table", "incoming_heal_predictor must load under mock NS")
assert_eq(NS.IncomingHeals, ihp, "module registers itself as NS.IncomingHeals")
assert_eq(subscribed, ihp._on_combat_log_entry, "module subscribes to the combat-log parser")

local function mk_unit(guid, extra)
    local u = { guid = guid, name = guid }
    if extra then
        for k, v in pairs(extra) do u[k] = v end
    end
    return u
end

local function heal_entry(healer, target, amount, overrides)
    local e = {
        amount_kind = "HEAL",
        caster_token = healer,
        target_token = target,
        amount = amount,
    }
    if overrides then
        for k, v in pairs(overrides) do e[k] = v end
    end
    return e
end

-- ---------------------------------------------------------------------------
-- 1. Empty / nil guards
-- ---------------------------------------------------------------------------
local tA = mk_unit("tA")
assert_eq(ihp.get(nil), 0, "get(nil) returns 0")
assert_eq(#ihp.get_detailed(nil), 0, "get_detailed(nil) returns empty")
assert_eq(ihp.get_arriving_before(nil, 5), 0, "get_arriving_before(nil, n) returns 0")
assert_eq(ihp.get_arriving_before(tA, "x"), 0, "non-numeric deadline returns 0")
assert_eq(ihp.get_arriving_before(tA, 0), 0, "zero deadline returns 0")

-- ---------------------------------------------------------------------------
-- 2. Native API short-circuit: get() returns the native figure directly
-- ---------------------------------------------------------------------------
local tN = mk_unit("tN", { get_incoming_heals = function() return 42 end })
now = 100
assert_eq(ihp.get(tN), 42, "native get_incoming_heals result is returned directly")

-- ---------------------------------------------------------------------------
-- 3. Combat-log prediction: 3-heal count gate + throttle + EMA
-- ---------------------------------------------------------------------------
now = 1000
ihp._on_combat_log_entry(heal_entry("hA", "tA", 1000))  -- count 1
ihp._on_combat_log_entry(heal_entry("hA", "tA", 1000))  -- count 2
assert_eq(ihp.get(tA), 0, "no prediction before the 3rd observed heal of a pair")
ihp._on_combat_log_entry(heal_entry("hA", "tA", 1000))  -- count 3 -> prediction
assert_eq(ihp.get(tA), 800, "3rd heal triggers 1000*0.8 arriving at now + 2.0")
local det = ihp.get_detailed(tA)
assert_eq(#det, 1, "one prediction detailed")
assert_eq(det[1].amount, 800, "prediction amount 800")
assert_eq(det[1].arrival_in_seconds, 2.0, "arrival 2.0s out (default cast 1.5 + 0.5 buffer)")
assert_eq(det[1].source, "hA", "prediction source is the healer guid")
assert_eq(det[1].spell_name, "Heal", "default spell name")

-- Throttle: a 4th heal inside SCAN_INTERVAL (0.5s) adds no new prediction.
ihp._on_combat_log_entry(heal_entry("hA", "tA", 1000))  -- count 4, 0.0s since last prediction
assert_eq(ihp.get(tA), 800, "predictions throttled within SCAN_INTERVAL")

-- After the window, a new heal adds a second prediction.
now = 1000.8
ihp._on_combat_log_entry(heal_entry("hA", "tA", 1000))  -- count 5, 0.8s >= 0.5
assert_eq(ihp.get(tA), 1600, "second prediction after the throttle window (2 x 800)")

-- Prune: once arrivals are in the past, predictions evaporate.
now = 1500
assert_eq(ihp.get(tA), 0, "expired predictions are pruned on scan cleanup")

-- EMA math on a fresh pair: 1000, 2000, 4000 -> avg 2110; predict 2110*0.8.
local tB = mk_unit("tB")
now = 1600
ihp._on_combat_log_entry(heal_entry("hB", "tB", 1000))
ihp._on_combat_log_entry(heal_entry("hB", "tB", 2000))  -- avg 1300
ihp._on_combat_log_entry(heal_entry("hB", "tB", 4000))  -- avg 2110 -> prediction 1688
assert_eq(ihp.get(tB), 1688, "EMA average 2110 * 0.8 conservative amount")

-- ---------------------------------------------------------------------------
-- 4. get_arriving_before deadline windowing
-- ---------------------------------------------------------------------------
local tD = mk_unit("tD")
now = 1700
ihp._on_combat_log_entry(heal_entry("hD", "tD", 1000))
ihp._on_combat_log_entry(heal_entry("hD", "tD", 1000))
ihp._on_combat_log_entry(heal_entry("hD", "tD", 1000))  -- prediction arriving at 1702
assert_eq(ihp.get_arriving_before(tD, 1.0), 0, "deadline before the arrival excludes it")
assert_eq(ihp.get_arriving_before(tD, 3.0), 800, "deadline past the arrival includes it")

-- ---------------------------------------------------------------------------
-- 5. MAX_PREDICTIONS_PER_UNIT cap (8) with oldest-arrival eviction
-- ---------------------------------------------------------------------------
local tX = mk_unit("tX")
now = 1800
for h = 1, 10 do
    local healer = "hCap" .. h
    ihp._on_combat_log_entry(heal_entry(healer, "tX", 1000))
    ihp._on_combat_log_entry(heal_entry(healer, "tX", 1000))
    ihp._on_combat_log_entry(heal_entry(healer, "tX", 1000))
end
-- 10 distinct healers x 3 heals -> 10 predictions for tX; the cap of 8 evicts
-- the two oldest (all arrivals equal at now+2, so the earliest-added go).
local detX = ihp.get_detailed(tX)
assert_eq(#detX, 8, "prediction cap per unit (MAX_PREDICTIONS_PER_UNIT = 8)")
assert_eq(ihp.get(tX), 8 * 800, "8 surviving predictions sum to 6400")

-- ---------------------------------------------------------------------------
-- 6. Party cast scanning (Flash Heal, cast time 1.5s)
-- ---------------------------------------------------------------------------
spell_names[2061] = "Flash Heal"
spell_cast_times[2061] = 1500  -- ms -> 1.5s
local tP = mk_unit("tP")
local casterA = mk_unit("hP", {
    is_casting = function() return true end,
    get_casting_spell_id = function(self) return self._spell_id end,  -- state-driven: CS-3/CS-4 mutate it
    get_cast_start_time = function(self) return self._start_time end,
    get_target = function(self) return self._target end,
    _spell_id = 2061,
    _start_time = nil,
    _target = nil,
})
party_units = { casterA }

now = 2000
casterA._start_time = 1999.5  -- remaining 1.0s
casterA._target = tP
assert_eq(ihp.get(tP), 1500, "cast scan predicts the fallback heal size (Flash Heal 1500)")
local detP = ihp.get_detailed(tP)
assert_eq(#detP, 1, "cast scan adds one prediction")
assert_eq(detP[1].amount, 1500, "cast-scan amount")
assert_eq(detP[1].arrival_in_seconds, 1.0, "cast-scan arrival = remaining cast time")
assert_eq(detP[1].source, "hP", "cast-scan source is the caster guid")
assert_eq(detP[1].spell_name, "Flash Heal", "cast-scan spell name from the spell book")

-- Nearly-complete cast (remaining <= 0.1s) adds nothing.
ihp.clear()
now = 2001
casterA._start_time = 1999.5  -- remaining = 1.5 - 1.5 = 0
assert_eq(ihp.get(tP), 0, "cast within 0.1s of landing adds no prediction")

-- Non-heal cast is skipped entirely. Remaining = 1.0s (same as the CS-1
-- positive control, which predicted 1500), so the 0 here is genuinely caused
-- by the Fireball classification, not by a near-complete cast.
ihp.clear()
now = 2002
spell_names[2062] = "Fireball"
spell_cast_times[2062] = 3000
casterA._spell_id = 2062
casterA._start_time = 2001.5
assert_eq(ihp.get(tP), 0, "non-heal casts are not predicted (remaining 1.0s)")

-- Unknown spell is cached as non-heal and skipped (remaining 1.0s again,
-- so the 0 is caused by the unknown-spell classification).
ihp.clear()
now = 2003
casterA._spell_id = 9999
spell_names[9999] = nil
casterA._start_time = 2002.5
assert_eq(ihp.get(tP), 0, "unknown spells are cached as non-heal and skipped (remaining 1.0s)")

-- ---------------------------------------------------------------------------
-- 7. Missing get_target falls back to the healer's most-preferred target
-- ---------------------------------------------------------------------------
ihp.clear()
local tE = mk_unit("tE")
now = 2100
ihp._on_combat_log_entry(heal_entry("hE", "tE", 1000))  -- builds hE->tE prefs
ihp._on_combat_log_entry(heal_entry("hE", "tE", 1000))
ihp._on_combat_log_entry(heal_entry("hE", "tE", 1000))  -- + CL prediction 800 @2102
local casterE = mk_unit("hE", {
    is_casting = function() return true end,
    get_casting_spell_id = function() return 2061 end,
    get_cast_start_time = function() return 2099.5 end,  -- remaining 1.0
    get_target = function() return nil end,
})
party_units = { casterE }
assert_eq(ihp.get(tE), 1800, "CL prediction (800) + cast-scan via prefs fallback (1000)")
local tOther = mk_unit("tOther")
assert_eq(ihp.get(tOther), 0, "other targets have no incoming heals")

-- ---------------------------------------------------------------------------
-- 8. Visible-object fallback with guid dedup
-- ---------------------------------------------------------------------------
ihp.clear()
local tF = mk_unit("tF")
local tG = mk_unit("tG")
local casterF = mk_unit("hF", {
    is_casting = function() return true end,
    get_casting_spell_id = function() return 2061 end,
    get_cast_start_time = function() return 2199.5 end,
    get_target = function() return tF end,
    is_party_member = function() return true end,
})
local casterG = mk_unit("hG", {
    is_casting = function() return true end,
    get_casting_spell_id = function() return 2061 end,
    get_cast_start_time = function() return 2199.5 end,
    get_target = function() return tG end,
    is_friend = function() return true end,
})
party_units = { casterF }
visible_units = { casterF, casterG }  -- casterF duplicated -> must not double count
now = 2200
assert_eq(ihp.get(tF), 1500, "party caster predicted once (visible dup deduped)")
assert_eq(ihp.get(tG), 1500, "visible friendly caster predicted")

-- ---------------------------------------------------------------------------
-- 9. clear() empties predictions/prefs and a fresh pair rebuilds
-- ---------------------------------------------------------------------------
ihp.clear()
assert_eq(ihp.get(tX), 0, "clear empties predictions")
assert_eq(#ihp.get_detailed(tX), 0, "clear empties detailed predictions")
local tZ = mk_unit("tZ")
now = 2400
ihp._on_combat_log_entry(heal_entry("hZ", "tZ", 1000))
ihp._on_combat_log_entry(heal_entry("hZ", "tZ", 1000))
ihp._on_combat_log_entry(heal_entry("hZ", "tZ", 1000))
assert_eq(ihp.get(tZ), 800, "predictions rebuild from a clean state after clear")

-- ---------------------------------------------------------------------------
-- 10. Input guards on the combat-log entry
-- ---------------------------------------------------------------------------
ihp.clear()
now = 2500
ihp._on_combat_log_entry(nil)                        -- nil entry
ihp._on_combat_log_entry({ amount_kind = "DAMAGE", caster_token = "h", target_token = "t", amount = 50 })
ihp._on_combat_log_entry(heal_entry("hSelf", "hSelf", 1000))        -- self-heal skipped
ihp._on_combat_log_entry(heal_entry(nil, "tZ", 1000))               -- missing caster
ihp._on_combat_log_entry(heal_entry("hZ2", nil, 1000))              -- missing target
ihp._on_combat_log_entry(heal_entry("hZ2", "tZ", 0))                -- zero amount
ihp._on_combat_log_entry(heal_entry("hZ2", "tZ", -5))               -- negative amount
ihp._on_combat_log_entry(heal_entry("hZ2", "tZ", "not-a-number"))   -- non-numeric amount
assert_eq(ihp.get(tZ), 0, "malformed / non-heal / self-heal entries are ignored")

print("PASS test_incoming_heal_predictor_regression")
