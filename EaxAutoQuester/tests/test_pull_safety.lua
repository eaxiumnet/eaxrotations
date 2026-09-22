-- What: shared/pull_safety.lua — should the bot start this fight at all?
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Live request: "more careful pulling more mobs on casters with low mana and scan nearby
--      mobs pathing so we dont pull and kill ourselves due to no mana or low health but instead
--      move away so we dont pull."
--      Three defects sat behind that, and each has a scenario here:
--        * menu_sylvanas.lua has shipped eaxaq_min_hp and eaxaq_min_mana since it was written and
--          nothing in the plugin read either one — the gate is now their only reader (P1, P5, P6).
--        * the crowd rule counted hostiles within 10yd of the target, only once the bot was
--          already in melee, and stood still on the answer; here it is checked before the pull and
--          the answer is a retreat (P2, P3, P8).
--        * a patrolling mob read exactly like an idle one, though it is the one that closes the
--          distance for you (P3 — the ONLY difference from P2 is movement speed).
--      P7 pins the other half of the contract: the gate is about not STARTING a fight, so it must
--      never fire once one is on (running from a fight you are in is a different behaviour, and it
--      would fight the rotation). P9 pins that the hold cannot wedge a step: past MAX_WAIT it
--      engages and says so.
-- Safety: pure module + unit stubs; no client, no network, no writes.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local _time = 1000
local _warnings = {}
local _logs = {}
local _visible = {}          -- the client's visible-objects list, per scenario

core = {
    time = function() return _time end,
    object_manager = { get_visible_objects = function() return _visible end },
    log = function(msg) _logs[#_logs + 1] = tostring(msg) end,
    log_warning = function(msg) _warnings[#_warnings + 1] = tostring(msg) end,
}

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.set_warning = function() end   -- the on-screen warning is main.lua's business

local pull_safety = require("shared/pull_safety")
local nav_destination = require("shared/nav_destination")

-- =============================================================================
-- Stubs
-- =============================================================================

-- The terrain fix-up is stubbed before ANY scenario runs. The gate caches the fixer on first
-- success (like every other producer in the plugin), so a stub installed later — inside R2, which
-- asserts that the retreat point goes through it — would never be reached.
local HEIGHT = 4242.5
local _fix_z_calls = {}
package.loaded["waypoint_fixer_sylvanas"] = {
    fix_z = function(pos)
        _fix_z_calls[#_fix_z_calls + 1] = { x = pos and pos.x, y = pos and pos.y, z = pos and pos.z }
        return { x = pos and pos.x or 0, y = pos and pos.y or 0, z = HEIGHT }
    end,
}

--- A player. `mana` nil means "this class has no mana" (max_power(0) == 0).
local function player(o)
    o = o or {}
    return {
        get_position = function() return o.pos or { x = 0, y = 0, z = 0 } end,
        get_health = function() return o.hp or 1000 end,
        get_max_health = function() return o.max_hp or 1000 end,
        get_power = function() return o.mana or 0 end,
        get_max_power = function() return o.max_mana or 0 end,
        is_in_combat = function() return o.combat == true end,
        get_target = function() return o.target end,
        is_unit = function() return true end,
        is_dead = function() return false end,
        can_attack = function() return false end,
        get_movement_speed = function() return 0 end,
    }
end

--- A hostile unit. `speed` > 0 means it is pathing.
local function mob(o)
    o = o or {}
    return {
        is_unit = function() return true end,
        is_dead = function() return o.dead == true end,
        can_attack = function() return true end,
        get_position = function() return o.pos or { x = 0, y = 0, z = 0 } end,
        get_movement_speed = function() return o.speed or 0 end,
        is_in_combat = function() return o.combat == true end,
        get_health = function() return 100 end,
        get_max_health = function() return 100 end,
        get_power = function() return 0 end,
        get_max_power = function() return 0 end,
    }
end

local function ctx_for(o)
    o = o or {}
    return {
        me = o.me,
        now = o.now or _time,
        menu = o.menu,
        debug_log = function(msg) _logs[#_logs + 1] = tostring(msg) end,
    }
end

local function fresh_shared()
    return { _nav_destination = nil, _nav_unit_dest = nil, _nav_engage_dest = nil }
end

-- =============================================================================
-- P1 — a caster with low mana does not pull, and is walked away from the mob
-- =============================================================================

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 1000
    local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = 1000, max_hp = 1000,
                        mana = 200, max_mana = 1000 })            -- 20% mana
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })
    local shared = fresh_shared()
    local ctx = ctx_for({ me = me })
    _visible = { enemy }

    assert(pull_safety.gate(ctx, shared, enemy) == true,
        "P1a FAIL: a caster at 20% mana must not pull")
    assert(pull_safety.holding(ctx) == true, "P1b FAIL: the gate must arm the hold")
    -- The retreat is the gate's published INTENT — the gate writes no navigation field (R1 is the
    -- proof) and nav_state applies this through shared/nav_destination.lua.
    local dest = pull_safety.destination(ctx)
    assert(dest ~= nil,
        "P1c FAIL: an unsafe pull must produce somewhere to back off TO")
    local dx = (dest.x or 0) - 0
    assert(dx < -1,
        "P1d FAIL: the retreat must be AWAY from the mob (+X here), got x=" .. tostring(dest.x))
    -- Applied by the owner: the point lands in the destination fields, as a point.
    assert(nav_destination.claim(shared, ctx) == true, "P1e FAIL: the hold must be claimable")
    assert(shared._nav_destination == dest,
        "P1f FAIL: the owner must apply exactly the point the gate published")
    assert(shared._nav_unit_dest == nil and shared._nav_engage_dest == nil,
        "P1g FAIL: the retreat is a point, not a unit to follow, and has no stand-off")
    assert(tostring(pull_safety.last_reason()):find("mana") ~= nil,
        "P1h FAIL: the reason should name mana, got " .. tostring(pull_safety.last_reason()))

    -- And with nothing listed at all, a retreat must still be produced (direction unknown, but the
    -- bot must not be left standing in the pull it just refused).
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 1100
    _visible = {}
    local shared_empty = fresh_shared()
    assert(pull_safety.gate(ctx_for({ me = me }), shared_empty, enemy) == true,
        "P1i FAIL: still unsafe")
    assert(pull_safety.destination(ctx_for({ me = me })) ~= nil,
        "P1j FAIL: a retreat must exist even when the client lists no objects")
    print("  P1 PASS: low mana caster backs off instead of pulling (reason: " ..
        tostring(pull_safety.last_reason()) .. ")")
end

-- =============================================================================
-- P2 — healthy, full mana, one idle neighbour: pull
-- =============================================================================

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 2000
    local me = player({ pos = { x = 0, y = 0, z = 0 } })
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })
    local neighbour = mob({ pos = { x = 14, y = 0, z = 0 } })     -- idle, 14yd from the fight site
    local shared = fresh_shared()
    local ctx = ctx_for({ me = me })
    _visible = { neighbour, enemy }

    assert(pull_safety.gate(ctx, shared, enemy) == false,
        "P2a FAIL: one idle neighbour is 1 risk point — that pull is allowed")
    assert(shared._nav_destination == nil,
        "P2b FAIL: an allowed pull must not move the player anywhere")
    assert(pull_safety.destination(ctx) == nil,
        "P2c FAIL: an allowed pull must not publish a retreat either")
    print("  P2 PASS: one idle neighbour does not block the pull")
end

-- =============================================================================
-- P3 — same counts, but the neighbour is PATHING: the pull is refused
-- =============================================================================

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 3000
    local me = player({ pos = { x = 0, y = 0, z = 0 } })
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })
    local patroller = mob({ pos = { x = 14, y = 0, z = 0 }, speed = 2.5 })
    local shared = fresh_shared()
    local ctx = ctx_for({ me = me })
    _visible = { patroller, enemy }

    local risk, hostiles = pull_safety.crowd(ctx, { x = 10, y = 0, z = 0 }, { patroller }, 1)
    assert(hostiles == 1, "P3a FAIL: one hostile is in radius (got " .. tostring(hostiles) .. ")")
    assert(risk == 2, "P3b FAIL: a moving hostile must weigh 2 (got " .. tostring(risk) .. ")")

    assert(pull_safety.gate(ctx, shared, enemy) == true,
        "P3c FAIL: a pathing neighbour makes an otherwise-identical pull unsafe (this is the only " ..
        "difference from P2)")
    assert(tostring(pull_safety.last_reason()):find("hostiles") ~= nil,
        "P3d FAIL: the reason should name the crowd, got " .. tostring(pull_safety.last_reason()))
    print("  P3 PASS: a patrolling neighbour outweighs an idle one (risk " .. tostring(risk) .. ")")
end

-- =============================================================================
-- P4 — a class with no mana is not held back by the mana rule
-- =============================================================================

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 4000
    -- max_mana 0 → get_max_power(0) == 0: a warrior/rogue. Reading mana here would be reading the
    -- wrong resource, so the rule must not fire at all.
    local me = player({ pos = { x = 0, y = 0, z = 0 }, mana = 0, max_mana = 0 })
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })
    local shared = fresh_shared()

    assert(pull_safety.gate(ctx_for({ me = me }), shared, enemy) == false,
        "P4a FAIL: a rage/energy class must not be gated by a mana reading")
    print("  P4 PASS: no mana bar means no mana rule")
end

-- =============================================================================
-- P5 — low health is refused even at full mana
-- =============================================================================

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 5000
    local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = 200, max_hp = 1000,
                        mana = 1000, max_mana = 1000 })            -- 20% health
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })
    local shared = fresh_shared()

    assert(pull_safety.gate(ctx_for({ me = me }), shared, enemy) == true,
        "P5a FAIL: 20% health must not start a fight")
    assert(tostring(pull_safety.last_reason()):find("health") ~= nil,
        "P5b FAIL: the reason should name health, got " .. tostring(pull_safety.last_reason()))
    print("  P5 PASS: low health refuses the pull too")
end

-- =============================================================================
-- P6 — the gate reads its OWN rows; the legacy min_hp/min_mana rows drive nothing
-- =============================================================================

--- Menu stub. It answers the gate's three keys, and answers the legacy pair (eaxaq_min_hp /
--- eaxaq_min_mana) with something deliberately loud whenever a scenario does not override it: a
--- gate that still read them would be visible here as a refusal.
local function menu_with(o)
    o = o or {}
    return { get = function(key, fallback)
        if key == "pull_gate" then
            if o.gate ~= nil then return o.gate end
        elseif key == "pull_gate_min_hp" then
            if o.min_hp ~= nil then return o.min_hp end
        elseif key == "pull_gate_min_mana" then
            if o.min_mana ~= nil then return o.min_mana end
        elseif key == "min_hp" or key == "min_mana" then
            return 90
        end
        return fallback
    end }
end

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 6000
    local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = 1000, max_hp = 1000,
                        mana = 500, max_mana = 1000 })            -- 50% mana
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })

    -- The legacy pair says 90 here (see the stub). A full-health caster at 50% mana still pulls:
    -- those rows are another feature's, and inheriting their 80/80 is what made this gate refuse
    -- ordinary post-fight states.
    assert(pull_safety.gate(ctx_for({ me = me, menu = menu_with({ min_mana = 20 }) }),
        fresh_shared(), enemy) == false,
        "P6a FAIL: with the gate's own min_mana at 20 a 50%-mana caster may pull")

    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 6100
    assert(pull_safety.gate(ctx_for({ me = me, menu = menu_with({}) }), fresh_shared(), enemy) == false,
        "P6b FAIL: eaxaq_min_mana at 90 (legacy row) refused a 50%-mana caster — the gate must not " ..
        "read the legacy pair")

    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 6200
    assert(pull_safety.gate(ctx_for({ me = me, menu = menu_with({ min_mana = 90 }) }),
        fresh_shared(), enemy) == true,
        "P6c FAIL: with the gate's own min_mana at 90 the same caster must not pull")

    -- Health half of the same claim: 60% is above the gate's 50 default and below a legacy 80.
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 6300
    local hurt = player({ pos = { x = 0, y = 0, z = 0 }, hp = 600, max_hp = 1000,
                          mana = 1000, max_mana = 1000 })
    assert(pull_safety.gate(ctx_for({ me = hurt, menu = menu_with({}) }), fresh_shared(), enemy) == false,
        "P6d FAIL: 60% health is above the gate's own 50 default and must pull (the legacy 80 must " ..
        "not apply)")
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 6400
    assert(pull_safety.gate(ctx_for({ me = hurt, menu = menu_with({ min_hp = 80 }) }),
        fresh_shared(), enemy) == true,
        "P6e FAIL: with the gate's own min_hp at 80, 60% health must not pull")
    print("  P6 PASS: the gate's own rows are the thresholds; eaxaq_min_hp/min_mana drive nothing")
end

-- =============================================================================
-- N1 — the case the audit measured: an ordinary post-fight caster must PULL
-- =============================================================================
-- Full health (90%), mana that is merely ordinary for the middle of a questing session (60%), one
-- idle mob and nothing else in the world. As first shipped this was refused and walked away, which
-- is "retreat after most kills". It has to be allowed, and it has to be allowed with no menu at all
-- in reach (the fallback path, i.e. the defaults this module ships with).

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 20000
    local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = 900, max_hp = 1000,
                        mana = 600, max_mana = 1000 })
    local lone = mob({ pos = { x = 10, y = 0, z = 0 } })
    _visible = { lone }
    local shared = fresh_shared()

    assert(pull_safety.gate(ctx_for({ me = me }), shared, lone) == false,
        "N1a FAIL: 90% health and ordinary 60% mana against ONE idle mob must pull — refusing here " ..
        "is retreat-after-most-kills (shipped defaults were hp 80 / mana 80)")
    assert(shared._nav_destination == nil,
        "N1b FAIL: an allowed pull must not move the player")
    assert(pull_safety.holding(ctx_for({ me = me })) == false,
        "N1c FAIL: an allowed pull must not arm a hold")

    -- ...and the same at 51% mana, the low end of ordinary rather than the comfortable middle.
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 20100
    local thirsty = player({ pos = { x = 0, y = 0, z = 0 }, hp = 900, max_hp = 1000,
                             mana = 510, max_mana = 1000 })
    _visible = { lone }
    assert(pull_safety.gate(ctx_for({ me = thirsty }), fresh_shared(), lone) == false,
        "N1d FAIL: 51% mana is above the gate's floor and must pull")
    print("  N1 PASS: ordinary post-fight caster pulls (90% hp / 60% mp, one idle mob)")
end

-- =============================================================================
-- N2 — the floors, pinned from both sides
-- =============================================================================

do
    local lone = mob({ pos = { x = 10, y = 0, z = 0 } })
    local function scene(hp_pct, mp_pct)
        pull_safety.reset()
        _visible = {}      -- each scenario starts from a clean client list
        _time = _time + 100
        local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = hp_pct * 10, max_hp = 1000,
                            mana = mp_pct * 10, max_mana = 1000 })
        _visible = { lone }
        return pull_safety.gate(ctx_for({ me = me }), fresh_shared(), lone)
    end

    -- Mana floor 30: below refuses, above allows. 29 and 31 rather than 30 itself so the boundary
    -- is pinned without depending on float equality.
    assert(scene(90, 29) == true, "N2a FAIL: 29% mana is below the 30 floor and must refuse")
    assert(scene(90, 31) == false, "N2b FAIL: 31% mana is above the 30 floor and must pull")

    -- Health floor 50, same shape.
    assert(scene(49, 80) == true, "N2c FAIL: 49% health is below the 50 floor and must refuse")
    assert(scene(51, 80) == false, "N2d FAIL: 51% health is above the 50 floor and must pull")

    -- The floors are floors, not preferences: a full bar of one resource does not buy a pull on an
    -- empty bar of the other.
    assert(scene(5, 100) == true, "N2e FAIL: 5% health must refuse even at full mana")
    assert(scene(100, 5) == true, "N2f FAIL: 5% mana must refuse even at full health")

    -- And the refusal names the resource, so the log says which floor was hit.
    local me_low = player({ pos = { x = 0, y = 0, z = 0 }, hp = 1000, max_hp = 1000,
                            mana = 50, max_mana = 1000 })
    pull_safety.reset()
    _time = _time + 100
    _visible = { lone }
    pull_safety.gate(ctx_for({ me = me_low }), fresh_shared(), lone)
    assert(tostring(pull_safety.last_reason()):find("mana 5%%") ~= nil
        and tostring(pull_safety.last_reason()):find("30%%") ~= nil,
        "N2g FAIL: the reason should read 'mana 5% < 30%', got " .. tostring(pull_safety.last_reason()))
    print("  N2 PASS: floors pinned both sides — mana 29/31, health 49/51, and one per resource")
end

-- =============================================================================
-- N3 — the toggle: off means every rule off, mid-hold included
-- =============================================================================

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 21000
    -- Nothing about this player or this world is safe: dying, out of mana, and standing in a camp
    -- of mobs that are all pathing.
    local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = 100, max_hp = 1000,
                        mana = 50, max_mana = 1000 })
    local camp = {}
    for i = 1, 4 do camp[i] = mob({ pos = { x = 3 + i, y = 0, z = 0 }, speed = 2.5 }) end
    _visible = camp
    local off = ctx_for({ me = me, menu = menu_with({ gate = false }) })
    local shared = fresh_shared()

    assert(pull_safety.enabled(off) == false, "N3a FAIL: the toggle must be readable")
    assert(pull_safety.gate(off, shared, camp[1]) == false,
        "N3b FAIL: with the gate switched off every rule is off — health, mana and crowd alike")
    assert(pull_safety.destination(off) == nil,
        "N3c FAIL: a switched-off gate must not publish a retreat")
    assert(nav_destination.claim(shared, off) == false and shared._nav_destination == nil,
        "N3d FAIL: a switched-off gate must not walk the player anywhere")
    assert(pull_safety.holding(off) == false,
        "N3d FAIL: a switched-off gate must not hold IDLE")

    -- Switched off after a hold was already armed: the hold has to go, not linger.
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 21100
    _visible = { camp[1] }
    local on = ctx_for({ me = me })
    assert(pull_safety.gate(on, fresh_shared(), camp[1]) == true, "N3e FAIL: expected a refusal")
    assert(pull_safety.holding(on) == true, "N3f FAIL: expected the hold to be armed")
    _time = 21150
    off.now = _time
    assert(pull_safety.holding(off) == false,
        "N3g FAIL: flipping the switch mid-hold must release it immediately")

    -- Switched back on: the rules apply again.
    assert(pull_safety.gate(off, fresh_shared(), camp[1]) == false,
        "N3h FAIL: gate(off) must not refuse")
    on.now = _time
    assert(pull_safety.gate(on, fresh_shared(), camp[1]) == true,
        "N3i FAIL: switched back on, the same scene must be refused again")

    -- N3j — and the wait clock must NOT survive the switch-off. This scene is refused at t, then
    -- the gate is off for a minute, then switched back on: if the off period counted toward the
    -- 40s anti-stall cap, the first refusal after the player re-enabled it would give up and
    -- engage, into a dying, empty player standing in a camp of patrollers.
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 21200
    _visible = { camp[1] }
    local on2 = ctx_for({ me = me })
    assert(pull_safety.gate(on2, fresh_shared(), camp[1]) == true, "N3j FAIL: expected a refusal")
    _time = _time + 60                     -- a minute with the switch off
    off.now = _time
    assert(pull_safety.gate(off, fresh_shared(), camp[1]) == false,
        "N3k FAIL: gate(off) must not refuse")
    on2.now = _time
    assert(pull_safety.gate(on2, fresh_shared(), camp[1]) == true,
        "N3l FAIL: a minute with the gate switched off must not spend the anti-stall cap — after " ..
        "re-enabling, the first refusal must still refuse rather than engage")
    print("  N3 PASS: one switch disables every rule, mid-hold included, and back on restores them")
end

-- =============================================================================
-- N4 — the pathing rule still refuses what it refused before the thresholds moved
-- =============================================================================
-- The fix was to the condition floors. The crowd rule and its moving-mob weighting must behave
-- exactly as they did: one idle neighbour is survivable, a neighbour that is walking is not.

do
    -- Healthy, full mana, and nothing to do with the condition rule: only the crowd can decide here.
    local function crowd_scene(neighbour_speed, count)
        pull_safety.reset()
        _visible = {}      -- each scenario starts from a clean client list
        _time = _time + 100
        local me = player({ pos = { x = 0, y = 0, z = 0 } })
        local target = mob({ pos = { x = 10, y = 0, z = 0 } })
        local others = {}
        for i = 1, (count or 1) do
            others[i] = mob({ pos = { x = 12 + i, y = 0, z = 0 }, speed = neighbour_speed })
        end
        _visible = others
        _visible[#_visible + 1] = target
        return pull_safety.gate(ctx_for({ me = me }), fresh_shared(), target),
            pull_safety.last_reason()
    end

    local allowed = crowd_scene(0)
    assert(allowed == false,
        "N4a FAIL: target + one idle neighbour (risk 2 of 3) must still be allowed")

    local refused, reason = crowd_scene(2.5)
    assert(refused == true,
        "N4b FAIL: target + one PATHING neighbour (risk 3) must still be refused")
    assert(tostring(reason):find("hostiles") ~= nil,
        "N4c FAIL: the crowd refusal must still name the crowd, got " .. tostring(reason))

    -- Two idle neighbours on top of the target is exactly the limit.
    local two_idle = crowd_scene(0, 2)
    assert(two_idle == true,
        "N4d FAIL: target + 2 idle neighbours (risk 3) must be refused — the crowd rule is unchanged")
    print("  N4 PASS: pathing weighting and the crowd limit behave exactly as before")
end

-- =============================================================================
-- N5 — a floor of 0 switches that one rule off
-- =============================================================================
-- The rows are the user's, so "off" has to be reachable without the master switch: setting either
-- slider to 0 disables that rule alone (no percentage is below zero, so `pct < 0` is never true).

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 22000
    local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = 100, max_hp = 1000,
                        mana = 50, max_mana = 1000 })             -- 10% health, 5% mana
    local lone = mob({ pos = { x = 10, y = 0, z = 0 } })
    _visible = { lone }

    assert(pull_safety.gate(ctx_for({ me = me, menu = menu_with({ min_hp = 0 }) }),
        fresh_shared(), lone) == true,
        "N5a FAIL: with min_hp 0 the health rule is off, so 5% mana must still refuse")
    assert(tostring(pull_safety.last_reason()):find("mana") ~= nil,
        "N5b FAIL: the reason must be the mana rule, got " .. tostring(pull_safety.last_reason()))

    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 22100
    _visible = { lone }
    assert(pull_safety.gate(ctx_for({ me = me, menu = menu_with({ min_hp = 0, min_mana = 0 }) }),
        fresh_shared(), lone) == false,
        "N5c FAIL: with both floors at 0 the condition rules are off entirely (10% health / 5% mana)")

    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 22200
    _visible = { lone }
    assert(pull_safety.gate(ctx_for({ me = me, menu = menu_with({ min_mana = 0 }) }),
        fresh_shared(), lone) == true,
        "N5d FAIL: with min_mana 0 the mana rule is off, so 10% health must still refuse")
    print("  N5 PASS: a floor of 0 disables that rule alone, and the other still fires")
end

-- =============================================================================
-- P7 — never once the fight is on
-- =============================================================================

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 7000
    local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = 100, max_hp = 1000,
                        mana = 0, max_mana = 1000, combat = true })   -- hurt AND empty AND fighting
    local enemy = mob({ pos = { x = 3, y = 0, z = 0 }, combat = true })
    local shared = fresh_shared()

    assert(pull_safety.gate(ctx_for({ me = me }), shared, enemy) == false,
        "P7a FAIL: the gate must not fire in combat — the rotation owns a fight that is on")
    assert(shared._nav_destination == nil, "P7b FAIL: no retreat may be issued mid-fight")
    assert(pull_safety.destination(ctx_for({ me = me })) == nil,
        "P7c FAIL: no retreat may be published mid-fight either")

    -- And the same when the enemy is the one fighting us, whatever our own flag says.
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 7100
    local me2 = player({ pos = { x = 0, y = 0, z = 0 }, hp = 100, max_hp = 1000,
                         mana = 0, max_mana = 1000, target = nil })
    local enemy2 = mob({ pos = { x = 3, y = 0, z = 0 }, combat = true })
    local me3 = player({ pos = { x = 0, y = 0, z = 0 }, hp = 100, max_hp = 1000, mana = 0,
                         max_mana = 1000 })
    local shared2 = fresh_shared()
    local ctx3 = ctx_for({ me = me3 })
    -- me3:get_target() returns nil above; point it at the enemy to exercise the second check.
    me3.get_target = function() return enemy2 end
    assert(pull_safety.gate(ctx3, shared2, enemy2) == false,
        "P7c FAIL: an enemy already fighting us is a fight that is on")
    print("  P7 PASS: the gate is about starting fights, never about leaving them")
end

-- =============================================================================
-- P8 — backing off is not pacing: a second trip while already out does not re-issue the walk
-- =============================================================================

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 8000
    -- The position table is held so the scenario can walk the player to where it was sent.
    local pos = { x = 0, y = 0, z = 0 }
    local me = player({ pos = pos, hp = 1000, max_hp = 1000,
                        mana = 0, max_mana = 1000 })               -- stays unsafe (mana is empty)
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })
    local shared = fresh_shared()
    local ctx = ctx_for({ me = me })

    assert(pull_safety.gate(ctx, shared, enemy) == true, "P8a FAIL: expected a back-off")
    local first = pull_safety.destination(ctx)
    assert(first, "P8b FAIL: expected a retreat destination")
    -- The owner applies it (what nav_state does), then the bot walks there.
    assert(nav_destination.claim(shared, ctx) == true, "P8c FAIL: the hold must be claimable")
    assert(shared._nav_destination == first, "P8d FAIL: the owner must apply the published point")
    pos.x, pos.y, pos.z = first.x, first.y, first.z

    -- The hold re-arms on the next assessment, still unsafe.
    _time = _time + 1
    ctx.now = _time
    assert(pull_safety.gate(ctx, shared, enemy) == true, "P8e FAIL: still unsafe")
    assert(pull_safety.holding(ctx) == true, "P8f FAIL: the hold must re-arm while unsafe")
    assert(pull_safety.destination(ctx) == first,
        "P8g FAIL: standing at the retreat point must not produce a different one — a fresh " ..
        "destination every re-arm is pacing, not backing off")
    assert(nav_destination.claim(shared, ctx) == true, "P8h FAIL: still claimable while unsafe")
    assert(shared._nav_destination == first,
        "P8i FAIL: and the owner must keep asserting the same coordinates")
    print("  P8 PASS: the retreat point is reused while unsafe, so the bot parks instead of pacing")
end

-- =============================================================================
-- P9 — the hold cannot wedge a step: past the cap it engages and says so
-- =============================================================================

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 9000
    local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = 1000, max_hp = 1000,
                        mana = 0, max_mana = 1000 })
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })
    local shared = fresh_shared()
    local ctx = ctx_for({ me = me })

    _warnings = {}
    local engagements = 0
    local held = 0
    local first_engage = nil
    for pass = 1, 60 do
        ctx.now = _time
        if pull_safety.gate(ctx, shared, enemy) then
            held = held + 1
        else
            engagements = engagements + 1
            if not first_engage then first_engage = pass end
        end
        _time = _time + 1                          -- one second per pass
    end
    assert(held > 0, "P9a FAIL: the condition should have held the bot at first")
    assert(engagements >= 1,
        "P9b FAIL: after the anti-stall cap the bot must engage — a hold that never expires is a " ..
        "step that never finishes")
    assert(first_engage and first_engage <= 45,
        "P9c FAIL: the cap is 40s, so the first engagement belongs by pass 45; got " ..
        tostring(first_engage) .. " — an unbounded hold is the failure this cap exists to prevent")
    assert(#_warnings >= 1 and tostring(_warnings[1]):find("engaging anyway") ~= nil,
        "P9d FAIL: breaking the rule to make progress must be announced")
    -- One warning per reason, not one per pass: otherwise the notice becomes the noise this whole
    -- pass was about removing.
    assert(#_warnings == 1,
        "P9e FAIL: the over-wait notice must be said once per condition, got " ..
        tostring(#_warnings))
    print("  P9 PASS: bounded hold — first engagement at pass " .. tostring(first_engage) ..
        " (cap 40s), announced once")
end

-- =============================================================================
-- P10 — the hold expires on its own, and clears when the condition does
-- =============================================================================

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 11000
    local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = 1000, max_hp = 1000,
                        mana = 0, max_mana = 1000 })
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })
    local ctx = ctx_for({ me = me })
    ctx.now = _time
    pull_safety.gate(ctx, fresh_shared(), enemy)
    assert(pull_safety.holding(ctx) == true, "P10a FAIL: the hold should be live")
    ctx.now = _time + 100
    assert(pull_safety.holding(ctx) == false, "P10b FAIL: the hold must expire by itself")

    -- Condition cleared while held → released immediately, no waiting out the timer.
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 12000
    ctx.now = _time
    pull_safety.gate(ctx, fresh_shared(), enemy)
    assert(pull_safety.holding(ctx) == true, "P10c FAIL: expected a hold")
    local healthy = player({ pos = { x = 0, y = 0, z = 0 }, hp = 1000, max_hp = 1000,
                             mana = 1000, max_mana = 1000 })
    local ctx2 = ctx_for({ me = healthy })
    ctx2.now = _time + 1
    assert(pull_safety.gate(ctx2, fresh_shared(), enemy) == false,
        "P10d FAIL: a cleared condition must release the hold at once")
    assert(pull_safety.holding(ctx2) == false, "P10e FAIL: and the hold flag must be gone")
    print("  P10 PASS: the hold expires, and clears early when the condition does")
end

-- =============================================================================
-- P11 — unreadable client: engage, never stall
-- =============================================================================

do
    pull_safety.reset()
    _visible = {}          -- each scenario starts from a clean client list
    _time = 13000
    local opaque = {
        get_position = function() return { x = 0, y = 0, z = 0 } end,
        is_in_combat = function() error("no such method") end,
        get_target = function() error("no such method") end,
    }
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })
    local shared = fresh_shared()
    local ok, result = pcall(pull_safety.gate, ctx_for({ me = opaque }), shared, enemy)
    assert(ok, "P11a FAIL: the gate must not raise on a client that cannot answer")
    assert(result == false,
        "P11b FAIL: with nothing readable the gate must allow the pull — refusing to fight " ..
        "because a probe failed would stall every step")
    print("  P11 PASS: an unreadable client engages rather than stalling")
end

-- =============================================================================
-- R1 — the gate writes no navigation field, ever
-- =============================================================================
-- The gate used to write all five destination fields itself, which is why a retreat it armed could
-- be replaced by whoever wrote last in the same tick. A shared table whose metatable refuses any
-- `_nav_*` write turns that into a hard error instead of a convention: whatever path the gate takes
-- (retreat produced, hold armed, warnings reported) it may not touch the destination.

do
    local function guarded_shared()
        return setmetatable({}, {
            __newindex = function(t, k, v)
                if type(k) == "string" and k:match("^_nav_") then
                    error("the pull gate wrote the navigation field " .. k, 2)
                end
                rawset(t, k, v)
            end,
        })
    end

    local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = 1000, max_hp = 1000,
                        mana = 0, max_mana = 1000 })
    local enemy = mob({ pos = { x = 10, y = 0, z = 0 } })
    local ctx = ctx_for({ me = me })

    -- The refusal path, where the retreat is produced and the hold armed.
    pull_safety.reset()
    _time = 40000
    _visible = { enemy }
    local guarded = guarded_shared()
    local ok, err = pcall(pull_safety.gate, ctx, guarded, enemy)
    assert(ok, "R1a FAIL: the gate touched a navigation field on a refusal — " .. tostring(err))
    assert(guarded._pull_warned_at ~= nil,
        "R1b FAIL: the gate's own bookkeeping key is not navigation state and must still be " ..
        "written on the refusal path — otherwise this scenario proves nothing about which keys " ..
        "it may touch")

    -- The safe path (no retreat at all).
    pull_safety.reset()
    _time = 40100
    local healthy = player({ pos = { x = 0, y = 0, z = 0 } })
    local guarded2 = guarded_shared()
    assert(pcall(pull_safety.gate, ctx_for({ me = healthy }), guarded2, enemy),
        "R1c FAIL: the gate touched a navigation field on the allow path")

    -- And the override-the-cap path, where it clears its own wait and warns again.
    pull_safety.reset()
    _time = 40200
    local guarded3 = guarded_shared()
    ctx.now = _time
    local ok3 = pcall(pull_safety.gate, ctx, guarded3, enemy)
    for pass = 1, 60 do
        ctx.now = _time + pass
        ok3 = ok3 and pcall(pull_safety.gate, ctx, guarded3, enemy)
    end
    assert(ok3, "R1d FAIL: the gate touched a navigation field on the anti-stall path")

    -- Non-vacuous: the guard really does catch a write, so the pcall above is a real test.
    local caught = guarded_shared()
    local raised = not pcall(function() caught._nav_destination = { x = 1, y = 1, z = 1 } end)
    assert(raised, "R1e FAIL: the guard does not catch a navigation write — R1a proves nothing")
    print("  R1 PASS: the gate writes no _nav_* field on any path (guard proven non-vacuous)")
end

-- =============================================================================
-- R2 — the retreat point goes through the terrain fix-up, as every other destination does
-- =============================================================================
-- The point used to carry the player's own Z, which is only correct on flat ground: off a ledge or
-- a terrace the client cannot walk to it at all, and the retreat — the safest decision in this
-- module — would be the most reliable way to produce a "Stuck detected" report.

do
    pull_safety.reset()
    _visible = {}
    _time = 41000
    local me = player({ pos = { x = 100, y = 200, z = 17 }, hp = 1000, max_hp = 1000,
                        mana = 0, max_mana = 1000 })
    local enemy = mob({ pos = { x = 110, y = 200, z = 17 } })
    _visible = { enemy }
    _fix_z_calls = {}

    assert(pull_safety.gate(ctx_for({ me = me }), fresh_shared(), enemy) == true,
        "R2a FAIL: expected a refusal")
    local dest = pull_safety.destination(ctx_for({ me = me }))
    assert(dest, "R2b FAIL: expected a retreat point")

    assert(#_fix_z_calls == 1,
        "R2c FAIL: the retreat point must be produced through waypoint_fixer.fix_z like every " ..
        "other destination in the plugin, got " .. tostring(#_fix_z_calls) .. " call(s)")
    assert(_fix_z_calls[1].z == 17,
        "R2d FAIL: the fixer must be given the point to correct, got z=" ..
        tostring(_fix_z_calls[1].z))
    assert(dest.z == HEIGHT,
        "R2e FAIL: the retreat point must carry the fixed height (" .. tostring(HEIGHT) .."), got " ..
        tostring(dest.z) .. " — the player's own Z is only right on flat ground")
    local dx = (dest.x or 0) - 100
    local dy = (dest.y or 0) - 200
    assert((dx * dx + dy * dy) >= 400,
        "R2f FAIL: the fix-up must not move the point off its bearing (>=20yd from the player)")
    print("  R2 PASS: the retreat point is terrain-fixed (z " .. tostring(HEIGHT) ..") and still away")
end

-- =============================================================================
-- R3 — a destination written AFTER the retreat does not win
-- =============================================================================
-- The measured defect: the destination had four writers, so a retreat armed by the gate could be
-- silently replaced in the same tick. The gate now publishes intent and the nav owner asserts it at
-- the moment the destination is consumed, so the later write loses.

do
    pull_safety.reset()
    _visible = {}
    _time = 42000
    local me = player({ pos = { x = 0, y = 0, z = 0 }, hp = 1000, max_hp = 1000,
                        mana = 0, max_mana = 1000 })
    local mob_pos = { x = 40, y = 0, z = 0 }
    local target = mob({ pos = mob_pos })
    _visible = { target }
    local shared = fresh_shared()
    local ctx = ctx_for({ me = me })

    assert(pull_safety.gate(ctx, shared, target) == true, "R3a FAIL: expected a refusal")
    local retreat = pull_safety.destination(ctx)
    assert(retreat, "R3b FAIL: the gate must publish the retreat it wants")

    -- Another writer runs later in the same tick: a walk onto the mob, with the live-unit link
    -- nav_state follows and re-issues.
    shared._nav_destination = mob_pos
    shared._nav_unit_dest = target
    shared._nav_unit_dest_key = mob_pos
    shared._nav_engage_dest = mob_pos
    shared._nav_engage_sq = 100

    -- What nav_state and idle_state do before they read the destination.
    assert(nav_destination.claim(shared, ctx) == true,
        "R3c FAIL: the hold is live, so the claim must apply")
    assert(shared._nav_destination == retreat,
        "R3d FAIL: the retreat must win over a destination written after it (got " ..
        tostring(shared._nav_destination and shared._nav_destination.x) .. ")")
    assert(shared._nav_unit_dest == nil and shared._nav_unit_dest_key == nil,
        "R3e FAIL: the live-unit link must be dropped — nav_state would otherwise re-issue walks " ..
        "toward the mob the retreat is leaving")
    assert(shared._nav_engage_dest == nil and shared._nav_engage_sq == nil,
        "R3f FAIL: no stand-off may survive either, or the walk would stop early at the mob")

    -- Contrast: with no hold, the same later write stands, so the claim is what beat it.
    pull_safety.reset()
    shared._nav_destination, shared._nav_unit_dest = mob_pos, target
    shared._nav_unit_dest_key = mob_pos
    assert(nav_destination.claim(shared, ctx) == false,
        "R3g FAIL: no hold must mean no claim")
    assert(shared._nav_destination == mob_pos,
        "R3h FAIL: without a claim the ordinary destination must stand")

    -- And the claim stops when the hold ends, so nothing is held forever: inside the 6s window it
    -- still applies, past it the gate has no opinion about where the bot stands.
    ctx.now = 42100
    assert(pull_safety.gate(ctx, shared, target) == true, "R3i FAIL: still unsafe")
    ctx.now = 42103
    assert(nav_destination.claim(shared, ctx) == true,
        "R3j FAIL: inside the hold the claim must still apply")
    ctx.now = 42110
    assert(pull_safety.holding(ctx) == false, "R3k FAIL: the hold expires on its own")
    assert(nav_destination.claim(shared, ctx) == false,
        "R3l FAIL: an expired hold must stop claiming at once")
    print("  R3 PASS: the retreat beats a later writer while armed, and releases when the hold ends")
end
