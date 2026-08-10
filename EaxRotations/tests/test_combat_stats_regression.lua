-- test_combat_stats_regression.lua — pins shared/combat_stats_sylvanas.lua.
-- WHAT:  Exercises the session stats engine: on_combat_start/end lifecycle,
--        action counting (success/failure/cooldown classification), update
--        tick accounting, DoT uptime accumulation (0.05/tick for debuffed
--        targets), downtime accounting, summary/current metric math (apm,
--        downtime_pct, dot uptimes, cooldowns), short-combat handling,
--        reset(), and the nil-guards. The module feeds the in-game DPS/HPS
--        overlay and previously had ZERO test references.
-- WHEN:  rotation suite execution.
-- WHY:   a future edit to the aggregation math (apm, downtime_pct, uptime
--        accrual) could silently corrupt the overlay metrics; this test fails
--        on regressions.
-- SAFETY: Pure unit test. The module caches NS at load, so a mock NS with a
--        controllable time_now + is_cooldown/get_spell_name/has_debuff +
--        callback registrations is installed BEFORE dofile. The real SDK is
--        never touched.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function assert_close(a, b, label)
    if math.abs(a - b) > 1e-9 then
        error((label or "assert_close") .. ": expected " .. tostring(b) .. " +/- 1e-9, got " .. tostring(a), 2)
    end
end

local now = 100.0
local is_cooldown = {}
local spell_names = {}
local debuffs = {}
local combat_start_cb = nil
local combat_end_cb = nil

local NS = {
    time_now = function() return now end,
    is_cooldown = function(id) return is_cooldown[id] == true end,
    get_spell_name = function(id) return spell_names[id] end,
    has_debuff = function(target, id) return debuffs[id] == true end,
    register_on_combat_start = function(cb) combat_start_cb = cb end,
    register_on_combat_end = function(cb) combat_end_cb = cb end,
}
_G.EaxRotations = NS

local cs = dofile("EaxRotations/shared/combat_stats_sylvanas.lua")
assert_true(type(cs) == "table", "combat_stats must load under mock NS")
assert_eq(NS.CombatStats, cs, "module registers itself as NS.CombatStats")
assert_eq(combat_start_cb, nil, "no auto-init without NS.GetPlayer (deferred)")
cs.init()
assert_true(type(combat_start_cb) == "function", "init registers the combat-start callback")
assert_true(type(combat_end_cb) == "function", "init registers the combat-end callback")

-- ---------------------------------------------------------------------------
-- 1. Empty / not-tracking state
-- ---------------------------------------------------------------------------
assert_eq(cs.is_tracking(), false, "not tracking before combat")
assert_eq(cs.get_current(), nil, "get_current nil before combat")
assert_eq(cs.get_last_summary(), nil, "no summary before any combat")
assert_eq(cs.get_dot_uptime("Corruption"), 0, "dot uptime 0 before combat")
assert_eq(cs.get_dot_uptime("Nope"), 0, "unknown dot name returns 0")

-- Actions / updates while NOT tracking are ignored.
cs.on_action(172, true, {})
cs.on_update({})
assert_eq(cs.get_current(), nil, "actions before tracking are ignored")
assert_eq(cs.is_tracking(), false, "still not tracking")

-- ---------------------------------------------------------------------------
-- 2. Combat start + action accounting
-- ---------------------------------------------------------------------------
is_cooldown[172] = true
spell_names[172] = "Corruption"
debuffs[172] = true
debuffs[589] = false  -- SW:P NOT on the target

combat_start_cb({})  -- driven through the registered callback to prove wiring
assert_eq(cs.is_tracking(), true, "on_combat_start begins tracking")
local cur = cs.get_current()
assert_eq(cur.duration, 0, "current duration 0 at combat start")
assert_eq(cur.actions_cast, 0, "current actions 0 at combat start")
assert_eq(cur.apm, 0, "current apm 0 at combat start")
assert_eq(cur.is_tracking, true, "current is_tracking true")
assert_eq(cs.get_dot_uptime("Corruption"), 0, "dots initialized to 0 at start")
assert_eq(cs.get_dot_uptime("Shadow Word: Pain"), 0, "all tracked dots initialized to 0")

cs.on_action(172, true, {})   -- success + cooldown
cs.on_action(133, true, {})   -- success, not a cooldown
cs.on_action(172, false, {})  -- failed cast
assert_eq(cs.get_current().actions_cast, 2, "successes counted, failures not")
assert_eq(cs.get_current().failed_actions, 1, "failed actions counted separately")

now = 101
local cur2 = cs.get_current()
assert_eq(cur2.duration, 1, "current duration follows the clock")
assert_close(cur2.apm, 120, "apm = 2 actions / 1s * 60")

-- ---------------------------------------------------------------------------
-- 3. Update ticks: total_ticks, DoT uptime accrual, downtime accounting
-- ---------------------------------------------------------------------------
now = 100
combat_start_cb({})  -- fresh session
local target = {}
for i = 1, 4 do
    -- All four ticks idle: GCD ready, not casting, not channeling.
    cs.on_update({ target = target, gcd_remains = 0, is_casting = false, is_channeling = false })
    now = now + 1
end
assert_close(cs.get_dot_uptime("Corruption"), 0.2, "debuffed dot accrues 0.05/tick (4 ticks)")
assert_eq(cs.get_dot_uptime("Shadow Word: Pain"), 0, "undebuffed dot accrues nothing")

cs.on_combat_end({})  -- duration = 104 - 100 = 4
assert_eq(cs.is_tracking(), false, "combat end stops tracking")
local sum = cs.get_last_summary()
assert_eq(sum.duration, 4, "summary duration")
assert_eq(sum.actions_cast, 0, "summary actions (none this session)")
assert_eq(sum.downtime_pct, 100, "downtime pct counts idle ticks (dead branch fixed)")
assert_close(sum.dot_uptimes["Corruption"].uptime_seconds, 0.2, "summary dot uptime seconds")
assert_close(sum.dot_uptimes["Corruption"].uptime_pct, 5.0, "summary dot uptime pct (0.2/4s)")
assert_eq(sum.dot_uptimes["Shadow Word: Pain"], nil, "undebuffed dot absent from summary")

-- ---------------------------------------------------------------------------
-- 4. Mixed busy/idle session: downtime_pct is proportional, apm computed,
--    cooldowns copied into the summary.
-- ---------------------------------------------------------------------------
now = 200
combat_start_cb({})
cs.on_action(172, true, {})   -- 1 success + cooldown
cs.on_update({ target = target, gcd_remains = 0.5, is_casting = false, is_channeling = false })  -- GCD busy
now = 201
cs.on_update({ target = target, gcd_remains = 0, is_casting = true, is_channeling = false })     -- casting
now = 202
cs.on_update({ target = target, gcd_remains = 0, is_casting = false, is_channeling = false })    -- idle -> downtime
now = 203
cs.on_combat_end({})  -- duration = 203 - 200 = 3
local sum2 = cs.get_last_summary()
assert_eq(sum2.duration, 3, "session 2 duration")
assert_eq(sum2.actions_cast, 1, "session 2 actions")
assert_eq(sum2.failed_actions, 0, "session 2 failures")
assert_close(sum2.apm, 20, "apm = 1 action / 3s * 60")
assert_close(sum2.downtime_pct, 100 / 3, "downtime pct = 1 idle tick / 3 ticks")
assert_eq(sum2.cooldowns_used["Corruption"], 1, "cooldown usage copied into summary")
assert_close(sum2.dot_uptimes["Corruption"].uptime_seconds, 0.15, "dot uptime accrues on every tick with target (3 ticks)")
assert_close(sum2.dot_uptimes["Corruption"].uptime_pct, 5.0, "dot uptime pct = 0.15/3s")

-- ---------------------------------------------------------------------------
-- 5. Short combat (< 1s): stops tracking but leaves NO summary
-- ---------------------------------------------------------------------------
now = 300
combat_start_cb({})
now = 300.5
cs.on_combat_end({})
assert_eq(cs.is_tracking(), false, "short combat stops tracking")
assert_eq(cs.get_last_summary(), sum2, "short combat leaves the prior summary untouched")

-- ---------------------------------------------------------------------------
-- 6. Second combat session resets counters; reset() clears session state
-- ---------------------------------------------------------------------------
now = 400
combat_start_cb({})
cs.on_action(172, true, {})
assert_eq(cs.get_current().actions_cast, 1, "new session starts counting fresh")
now = 402
cs.on_combat_end({})
local sum3 = cs.get_last_summary()
assert_eq(sum3.actions_cast, 1, "session 3 actions")
assert_eq(sum3.duration, 2, "session 3 duration")

cs.reset()
assert_eq(cs.is_tracking(), false, "reset stops tracking")
assert_eq(cs.get_current(), nil, "reset clears the current session")
assert_eq(cs.get_dot_uptime("Corruption"), 0, "reset zeroes dot uptimes")
assert_eq(cs.get_last_summary(), sum3, "last completed summary survives reset (design)")

-- ---------------------------------------------------------------------------
-- 7. Nil guards on the dot scan / cooldown path
-- ---------------------------------------------------------------------------
now = 500
cs.update_dot_uptimes(nil)              -- no context -> no-op
cs.update_dot_uptimes({})               -- no target -> no-op
assert_eq(cs.get_dot_uptime("Corruption"), 0, "dot scan nil-guards context and target")

combat_start_cb({})
local saved_has_debuff = NS.has_debuff
NS.has_debuff = nil                     -- module must bail, not crash
cs.on_update({ target = {}, gcd_remains = 0, is_casting = false, is_channeling = false })
NS.has_debuff = saved_has_debuff
assert_eq(cs.get_dot_uptime("Corruption"), 0, "dot scan bails without NS.has_debuff")

-- Cooldown keyed by tostring(spell_id) when get_spell_name is absent.
now = 600
combat_start_cb({})
spell_names[172] = nil
cs.on_action(172, true, {})
now = 602
cs.on_combat_end({})
local sum4 = cs.get_last_summary()
assert_eq(sum4.cooldowns_used["172"], 1, "cooldown keyed by tostring(id) when no spell name")

-- ---------------------------------------------------------------------------
-- 8. get_dot_uptime during live tracking
-- ---------------------------------------------------------------------------
now = 700
combat_start_cb({})
debuffs[172] = true
local t2 = {}
cs.on_update({ target = t2, gcd_remains = 0.5, is_casting = false, is_channeling = false })
cs.on_update({ target = t2, gcd_remains = 0.5, is_casting = false, is_channeling = false })
assert_close(cs.get_dot_uptime("Corruption"), 0.1, "live dot uptime accumulates during tracking")
cs.on_combat_end({})
assert_eq(cs.get_dot_uptime("Corruption"), 0, "get_dot_uptime reads 0 once tracking stops (the summary holds the totals)")

print("PASS test_combat_stats_regression")
