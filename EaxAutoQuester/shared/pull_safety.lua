-- shared/pull_safety.lua — should the bot start this fight at all?
-- WHAT:  pull_safety.engage(ctx, shared, enemy, opts) is the ONE checkpoint between "there is a
--        hostile" and "the bot commits to it": it asks the gate and, on a pass, issues the
--        approach walk itself — so a call site cannot reach its swing without having asked.
--        pull_safety.gate(ctx, shared, enemy, objects, limit) is the decision underneath it
--        (owner-internal; production asks through M.engage). Unsafe → the site does not engage:
--        the gate reports the reason once, remembers a retreat point and publishes it as an INTENT
--        (M.destination) for nav_state to apply through shared/nav_destination.lua — neither the
--        gate nor the checkpoint ever writes the navigation fields directly.
-- WHEN:  every place do_action_state is about to approach, pull or attack a hostile goes through
--        M.engage; the two ask-without-consequences readers are M.would_refuse (the en-route
--        pre-tag: a walk already under way must not turn around) and M.holding (idle_state, and
--        the recovery pause and spawn search that live inside the hold).
-- WHY:   Live report: "more careful pulling more mobs on casters with low mana and scan nearby
--        mobs pathing so we dont pull and kill ourselves due to no mana or low health but instead
--        move away so we dont pull." Three ways the old code committed anyway:
--          * It approached and pulled at ANY health and ANY mana. menu_sylvanas.lua has shipped
--            eaxaq_min_hp and eaxaq_min_mana since it was written and NOTHING in the plugin ever
--            read them (they are not even rendered) — two dead rows. This module uses NEITHER:
--            those rows were never this feature's, and their 80/80 display defaults refuse a
--            healthy caster whose mana is merely ordinary (see GATE_MIN_* below).
--          * Its only crowd check asked "are 3 hostiles within 10yd of the target" AFTER the bot
--            was already in melee range, i.e. after the pull — and the answer was to stand still,
--            not to leave.
--          * It read only their positions, so a PATROLLING mob walking into the fight count read
--            exactly like an idle one. A mover is the more dangerous of the two: it closes the
--            distance for you and brings the camp.
-- SAFETY: every client read is pcall-guarded and the decision degrades to "engage" when it cannot
--        be answered — a bot that refuses to fight because a probe failed would stall the whole
--        step. The hold is bounded on both ends (HOLD_SECONDS, and MAX_WAIT_SECONDS hard cap), so
--        this can never wedge a step the way an un-guarded regen wait would; after the cap it
--        engages and says so.
-- DECISION: shared module — do_action_state's three engage sites and idle_state's hold check need
--        one definition of "unsafe". No per-tick allocation; the object list is the caller's.

local M = {}

local _core_time = core.time
local _get_visible_objects = core.object_manager and core.object_manager.get_visible_objects

-- A hostile inside CROWD_YDS of the fight site is a risk point. A MOVING one is two: it is
-- pathing, so it will not stay where it is. RISK_LIMIT is the most risk the bot will start a
-- fight with — two idle mobs (2) are survivable-ish, one patroller plus one idle (3) is not.
local CROWD_YDS = 18
local CROWD_YDS_SQ = CROWD_YDS * CROWD_YDS
local RISK_LIMIT = 3
local SCAN_LIMIT = 50

-- ============================================================================
-- The gate's own floors — derived from what actually threatens a leveling caster, NOT inherited
-- from the menu sliders' display defaults (both were 80, which is not "low" by any reading: it
-- would refuse a full-health caster whose mana is merely ordinary, i.e. right after most kills).
--
-- These are FLOORS, not preferences. Each one answers "would the next fight plausibly kill me or
-- leave me unable to finish it?", and each is below the point a player would call the resource
-- low, so ordinary leveling never trips them:
--
--   HP  50% — the gate is the wrong tool for "topping up". A leveling caster eats ~25-40% of its
--        health to a single solo mob over a kill, so half a bar is where ONE fight can finish you
--        outright if it runs long, and where an add certainly does. Above it there is room to
--        fight and heal afterwards.
--   MP  30% — a caster pays roughly a quarter to a third of its pool for one kill. Below a third
--        it cannot pay for another, and a caster that cannot kill cannot run either: the failure
--        mode is dying to a mob it cannot finish, which is exactly what was reported.
--
-- Both are the plugin's own rows (eaxaq_pull_gate_min_hp / _min_mana, 0-100, 0 disables a rule
-- because no healthy percentage is below zero). The whole gate is switchable at eaxaq_pull_gate.
local GATE_ENABLED_FALLBACK = true
local GATE_MIN_HP_FALLBACK = 50
local GATE_MIN_MANA_FALLBACK = 30

local RETREAT_YDS = 25        -- how far from the group the player is put
local HOLD_SECONDS = 6.0      -- quiet time after backing off before anything may be re-assessed
local MAX_WAIT_SECONDS = 40.0 -- hard cap: after this the bot engages anyway rather than stalling

-- ============================================================================
-- Hoisted unit probes
-- ============================================================================

local function unit_get_position(u) return u:get_position() end
local function unit_is_dead(u) return u:is_dead() end
local function unit_is_unit(u) return u:is_unit() end
local function unit_can_attack(u, other) return u:can_attack(other) end
local function unit_is_in_combat(u) return u:is_in_combat() end
local function unit_get_movement_speed(u) return u:get_movement_speed() end
local function unit_get_health(u) return u:get_health() end
local function unit_get_max_health(u) return u:get_max_health() end
local function unit_get_power(u, t) return u:get_power(t) end
local function unit_get_max_power(u, t) return u:get_max_power(t) end

local PLAYER_POWER_MANA = 0

-- ============================================================================
-- The retreat point's Z
-- ============================================================================

-- The plugin's convention: a producer fixes Z before handing a destination over. An unlived-in Z is
-- what puts a point off the navmesh or inside a hill, and the client then cannot walk to it at all —
-- the "Stuck detected" shape, and the one thing that would make the safest decision in this module
-- fail to move the bot. Every other producer does this (do_action_state's NPC spawn point,
-- idle_state's terrain raycast, zygor/questie/goal_resolver waypoints); the retreat point used the
-- player's own Z, which is only right on flat ground. Cached after the first success, so a test that
-- installs a stub later still gets it.
local _waypoint_fixer = nil
local function fix_z(pos)
    if not _waypoint_fixer then
        local ok, wf = pcall(require, "waypoint_fixer_sylvanas")
        if ok and wf then _waypoint_fixer = wf end
    end
    if _waypoint_fixer and _waypoint_fixer.fix_z then
        local ok, fixed = pcall(_waypoint_fixer.fix_z, pos)
        if ok and fixed then return fixed end
    end
    return pos
end

-- ============================================================================
-- State — the hold window (the only state this module keeps)
-- ============================================================================

local _hold_until = 0        -- nothing may engage before this
local _wait_since = 0        -- when the current wait started (anti-stall cap)
local _wait_key = nil        -- which resource caused it ("hp"/"mana"), or nil for a positional reason
local _wait_value = nil      -- that resource's value at the last check, so a recovering wait can tell
local _last_reason = nil
local _retreat_dest = nil    -- where we went to stand; reused so repeated trips do not pace

--- Is the pull gate on at all? One switch, eaxaq_pull_gate, owns every rule in this module.
--- @param ctx table Per-tick context
--- @return boolean enabled
function M.enabled(ctx)
    local menu = ctx and ctx.menu
    if menu and menu.get then
        local ok, v = pcall(menu.get, "pull_gate", GATE_ENABLED_FALLBACK)
        if ok and type(v) == "boolean" then return v end
    end
    return GATE_ENABLED_FALLBACK
end

--- Is the bot inside a back-off hold right now?
--- idle_state asks this so it does not navigate straight back into the group it just left.
--- A switched-off gate holds nothing: otherwise the switch would leave the bot parking at a
--- retreat point it no longer has a reason to be at.
--- @param ctx table Per-tick context
--- @return boolean holding
function M.holding(ctx)
    if not M.enabled(ctx) then return false end
    local now = ctx and ctx.now or (_core_time and _core_time() or 0)
    return now < _hold_until
end

--- Reason of the last back-off, for logs and the on-screen warning.
function M.last_reason() return _last_reason end

--- Clear the hold (tests, and any state change that should re-assess immediately).
function M.reset()
    _hold_until = 0
    _wait_since = 0
    _wait_key = nil
    _wait_value = nil
    _last_reason = nil
    _retreat_dest = nil
end

-- ============================================================================
-- Reads
-- ============================================================================

--- Health as a percentage, or nil when the client cannot say.
local function health_pct(me)
    local ok_h, hp = pcall(unit_get_health, me)
    local ok_m, max_hp = pcall(unit_get_max_health, me)
    if not (ok_h and ok_m) or not hp or not max_hp or max_hp <= 0 then return nil end
    return (hp / max_hp) * 100
end

--- Mana as a percentage, or nil when this class has no mana at all.
--- The gate is about CASTERS: a warrior's power that matters is rage, and reading index 0 for one
--- returns nothing usable, so a max of zero means "ask a different question", not "no mana".
local function mana_pct(me)
    local ok_m, max_mp = pcall(unit_get_max_power, me, PLAYER_POWER_MANA)
    if not ok_m or not max_mp or max_mp <= 0 then return nil end
    local ok_c, mp = pcall(unit_get_power, me, PLAYER_POWER_MANA)
    if not ok_c or not mp then return nil end
    return (mp / max_mp) * 100
end

--- A numeric setting from the plugin menu, or the fallback.
local function setting(ctx, key, fallback)
    local menu = ctx and ctx.menu
    if menu and menu.get then
        local ok, v = pcall(menu.get, key, fallback)
        if ok and type(v) == "number" then return v end
    end
    return fallback
end

-- ============================================================================
-- Gate floors — the one place "low" starts, for any module that has to ask
-- ============================================================================
--- The gate's own refusal floors as the menu currently reads them (0 disables that rule).
--- A floor kept anywhere else is a floor this gate does not enforce.
--- @param ctx table Per-tick context
--- @return number min_hp, number min_mana
function M.floors(ctx)
    return setting(ctx, "pull_gate_min_hp", GATE_MIN_HP_FALLBACK),
        setting(ctx, "pull_gate_min_mana", GATE_MIN_MANA_FALLBACK)
end

-- ============================================================================
-- Crowd scan
-- ============================================================================

--- Risk points of hostiles around a point. A moving hostile counts double.
--- @param ctx table
--- @param point table vec3 the fight site
--- @param objects table|nil visible objects (fetched when absent)
--- @param limit number|nil how many entries of `objects` to read
--- @return number risk, number hostiles
function M.crowd(ctx, point, objects, limit)
    if not point then return 0, 0 end
    if not objects and _get_visible_objects then
        local ok, list = pcall(_get_visible_objects)
        if ok then objects = list end
    end
    if not objects then return 0, 0 end

    local n = limit or #objects
    if n > SCAN_LIMIT then n = SCAN_LIMIT end

    local risk, hostiles = 0, 0
    for i = 1, n do
        local obj = objects[i]
        if obj and obj ~= ctx.me then
            local ok_unit, is_unit = pcall(unit_is_unit, obj)
            if ok_unit and is_unit then
                local ok_dead, dead = pcall(unit_is_dead, obj)
                local ok_atk, attackable = pcall(unit_can_attack, obj, ctx.me)
                if attackable and not (ok_dead and dead) then
                    local ok_pos, pos = pcall(unit_get_position, obj)
                    if ok_pos and pos then
                        local dx = (pos.x or 0) - (point.x or 0)
                        local dy = (pos.y or 0) - (point.y or 0)
                        if dx * dx + dy * dy <= CROWD_YDS_SQ then
                            hostiles = hostiles + 1
                            -- Moving = pathing. It will not still be there when the fight starts,
                            -- and it may well arrive during it.
                            local ok_spd, spd = pcall(unit_get_movement_speed, obj)
                            if ok_spd and type(spd) == "number" and spd > 0.1 then
                                risk = risk + 2
                            else
                                risk = risk + 1
                            end
                        end
                    end
                end
            end
        end
    end
    return risk, hostiles
end

-- ============================================================================
-- The retreat point
-- ============================================================================

--- Where to stand instead: away from the crowd's centre of mass, RETREAT_YDS from here, with its Z
--- fixed for the terrain (see fix_z above) so the client can actually walk to it.
--- @return table|nil vec3
function M.retreat_point(ctx, objects, limit)
    local me = ctx and ctx.me
    if not me then return nil end
    local ok_pos, me_pos = pcall(unit_get_position, me)
    if not ok_pos or not me_pos then return nil end

    -- Centre of mass of the thing we would be fighting: every hostile inside CROWD_YDS, which is
    -- the same set the risk count came from — one radius, so "too crowded to pull" and "which way
    -- is out" cannot disagree.
    local sx, sy, n = 0, 0, 0
    local list = objects
    if not list and _get_visible_objects then
        local ok, l = pcall(_get_visible_objects)
        if ok then list = l end
    end
    if list then
        local count = limit or #list
        if count > SCAN_LIMIT then count = SCAN_LIMIT end
        for i = 1, count do
            local obj = list[i]
            if obj and obj ~= me then
                local ok_unit, is_unit = pcall(unit_is_unit, obj)
                if ok_unit and is_unit then
                    local ok_atk, attackable = pcall(unit_can_attack, obj, me)
                    local ok_dead, dead = pcall(unit_is_dead, obj)
                    if attackable and not (ok_dead and dead) then
                        local ok_p, pos = pcall(unit_get_position, obj)
                        if ok_p and pos then
                            local dx = (pos.x or 0) - (me_pos.x or 0)
                            local dy = (pos.y or 0) - (me_pos.y or 0)
                            if dx * dx + dy * dy <= CROWD_YDS_SQ then
                                sx, sy, n = sx + (pos.x or 0), sy + (pos.y or 0), n + 1
                            end
                        end
                    end
                end
            end
        end
    end

    local dirx, diry
    if n > 0 then
        dirx, diry = (me_pos.x or 0) - (sx / n), (me_pos.y or 0) - (sy / n)
    end
    local len = math.sqrt((dirx or 0) * (dirx or 0) + (diry or 0) * (diry or 0))
    if len < 0.001 then
        -- Standing on the centre of mass: fall back to straight away from the engaged direction.
        dirx, diry = 0, 0
        len = 0
    end
    if len < 0.001 then
        dirx, diry = 0, 1        -- nothing to run from in particular: step off north
        len = 1
    end

    return fix_z({
        x = (me_pos.x or 0) + (dirx / len) * RETREAT_YDS,
        y = (me_pos.y or 0) + (diry / len) * RETREAT_YDS,
        z = me_pos.z or 0,
    })
end

--- Where the gate wants the bot to walk instead, or nil when it wants nothing.
---
--- This is the gate's INTENT, and it is deliberately the only way it expresses one: this module does
--- not write the navigation fields. shared/nav_destination.lua owns them, and nav_state — the state
--- that issues the walk — applies this claim at the moment it consumes the destination. A retreat
--- armed here therefore cannot be silently overwritten by another writer in the same tick, which is
--- what writing the fields from here used to allow.
--- @param ctx table Per-tick context
--- @return table|nil vec3
function M.destination(ctx)
    if not _retreat_dest or not M.holding(ctx) then return nil end
    return _retreat_dest
end

-- ============================================================================
-- The gate
-- ============================================================================

--- Read the player's condition. Returns nil (safe), or a reason string plus which resource
--- caused it and that resource's value now (the value is what tells a wait that is recovering from
--- one that is going nowhere — see the anti-stall cap in M.gate).
--- A floor of 0 is a disabled rule: no health or mana percentage is below zero, so `pct < 0` is
--- never true and the branch needs no special case to be switchable.
--- @return string|nil reason, string|nil key ("hp"/"mana"), number|nil value
local function condition_reason(ctx)
    local me = ctx and ctx.me
    if not me then return nil end

    local min_hp = setting(ctx, "pull_gate_min_hp", GATE_MIN_HP_FALLBACK)
    local hp = health_pct(me)
    if hp and hp < min_hp then
        return "health " .. tostring(math.floor(hp)) .. "% < " .. tostring(math.floor(min_hp)) .. "%",
            "hp", hp
    end

    local min_mana = setting(ctx, "pull_gate_min_mana", GATE_MIN_MANA_FALLBACK)
    local mp = mana_pct(me)
    if mp and mp < min_mana then
        return "mana " .. tostring(math.floor(mp)) .. "% < " .. tostring(math.floor(min_mana)) .. "%",
            "mana", mp
    end

    return nil
end

--- The condition itself, and nothing else: nil when this fight is fine to start, or the reason it
--- is not. The hold plays no part here — a quiet hold over a condition that has cleared must not
--- keep refusing — and the caller decides what to do about the answer.
--- @return string|nil reason, string|nil key, number|nil value
local function decide(ctx, enemy, objects, limit)
    local me = ctx and ctx.me
    if not me or not enemy then return nil end

    -- Switched off: no rule in this module applies.
    if not M.enabled(ctx) then return nil end

    -- Once the fight is on, the decision is over: the bot does not run from a fight it is in
    -- (that is a different behaviour, and the rotation owns the fight it started). This gate is
    -- about not STARTING one — which is why it must be consulted before the approach, too.
    local ok_combat, in_combat = pcall(unit_is_in_combat, me)
    if ok_combat and in_combat then return nil end
    local ok_target, target = pcall(function() return me:get_target() end)
    if ok_target and target == enemy then
        local ok_t_combat, t_in_combat = pcall(unit_is_in_combat, enemy)
        if ok_t_combat and t_in_combat then return nil end
    end

    local reason, key, value = condition_reason(ctx)
    if reason then return reason, key, value end

    local ok_pos, enemy_pos = pcall(unit_get_position, enemy)
    if ok_pos and enemy_pos then
        local risk = M.crowd(ctx, enemy_pos, objects, limit)

        -- Also count what is standing around US: the fight happens in the gap between the two,
        -- and a patroller crossing our side of it is the same problem.
        local ok_me_pos, me_pos = pcall(unit_get_position, me)
        if ok_me_pos and me_pos then
            local here = M.crowd(ctx, me_pos, objects, limit)
            if here > risk then risk = here end
        end

        if risk >= RISK_LIMIT then
            return tostring(risk) .. " nearby hostiles (moving counts double)"
        end
    end

    return nil
end

--- Would this fight be refused right now? The same decision as M.gate, asked without any of its
--- consequences — no hold, no retreat, no wait clock, no notice. This is what an EN-ROUTE pre-tag
--- asks: it must not tag a mob the bot would refuse to fight, and it must not make a walk that is
--- already under way turn around (a bot running 300yd across a camp, at low mana, is not pulling).
--- @param ctx table Per-tick context
--- @param enemy game_object|nil the hostile the caller is about to tag
--- @param objects table|nil visible objects (fetched when absent)
--- @param limit number|nil how many entries of `objects` to read
--- @return boolean refused
function M.would_refuse(ctx, enemy, objects, limit)
    return decide(ctx, enemy, objects, limit) ~= nil
end

--- Should this fight be started? When not, this walks the player out (or parks them) itself.
--- @param ctx table Per-tick context
--- @param shared table Shared state variables
--- @param enemy game_object|nil the hostile the caller is about to engage
--- @param objects table|nil visible objects (fetched when absent)
--- @param limit number|nil how many entries of `objects` to read
--- @return boolean handled True when the caller must NOT engage this tick
function M.gate(ctx, shared, enemy, objects, limit)
    local me = ctx and ctx.me
    if not me or not shared or not enemy then return false end

    -- Switched off: no rule in this module applies. The wait clock is the one piece of state that
    -- must not survive a switch-off — a gate re-enabled 40s later would otherwise find the cap
    -- already spent and engage into the very condition it exists to refuse. The hold needs no
    -- clearing here: M.holding answers false while the gate is off, and nothing else reads it.
    if not M.enabled(ctx) then
        _wait_since = 0
        _wait_key = nil
        _wait_value = nil
        return false
    end

    local now = ctx.now or (_core_time and _core_time() or 0)

    local reason, wait_key, wait_value = decide(ctx, enemy, objects, limit)

    if not reason and not M.holding(ctx) then
        _retreat_dest = nil        -- condition cleared: forget the refuge, a fresh one is computed
        _wait_since = 0
        _wait_key = nil
        _wait_value = nil
        return false
    end
    if not reason and M.holding(ctx) then
        -- Safe again while the hold runs: nothing left to hold for.
        _hold_until = 0
        _retreat_dest = nil
        _wait_since = 0
        _wait_key = nil
        _wait_value = nil
        return false
    end

    _last_reason = reason

    -- A wait whose resource is coming back is going somewhere. Restarting its clock is what makes
    -- the cap below an anti-STALL rule rather than a "30 seconds and we go anyway" rule: at low
    -- mana the wait lasts until mana recovers, however long that takes, and the cap only fires when
    -- the situation has genuinely stopped changing (or when the reason is positional — a camp does
    -- not thin out because the bot stood still).
    if wait_key and wait_key == _wait_key and wait_value and _wait_value
        and wait_value > _wait_value then
        _wait_since = now
    end
    _wait_key, _wait_value = wait_key, wait_value

    -- Anti-stall: a hold that keeps being renewed over a situation that is not improving is a step
    -- going nowhere. Past the cap the bot engages and says which rule it had to break. Never wedges.
    if _wait_since > 0 and (now - _wait_since) > MAX_WAIT_SECONDS then
        local waited = math.floor(now - _wait_since)
        _hold_until = 0
        _wait_since = 0
        _wait_key = nil
        _wait_value = nil
        _retreat_dest = nil
        -- Keyed separately from the "not pulling" notice: they are two different events, and the
        -- first one having been said must not swallow the second — the player needs to see that
        -- the rule was broken on purpose, or the pull that follows looks like a bug.
        if shared._pull_overwait_at ~= reason then
            shared._pull_overwait_at = reason
            ctx.debug_log("PULL_SAFETY: " .. reason .. " — waited " ..
                tostring(waited) .. "s, engaging anyway")
            core.log_warning("[EaxAutoQuester] Pull safety: " .. reason ..
                " — waited " .. tostring(waited) .. "s, engaging anyway")
        end
        return false
    end

    -- Walk out only if we are not already standing at the point we walked to. Re-issuing the same
    -- walk every time the hold is re-armed is what would turn a back-off into pacing: the bot
    -- would shuffle away, get re-assessed, shuffle away again, for as long as the condition held.
    -- The point is remembered and published as-is (M.destination), so the nav owner asserts the same
    -- coordinates every tick rather than a fresh one.
    local already_out = false
    if _retreat_dest then
        local ok_pos, me_pos = pcall(unit_get_position, me)
        if ok_pos and me_pos then
            local dx = (me_pos.x or 0) - (_retreat_dest.x or 0)
            local dy = (me_pos.y or 0) - (_retreat_dest.y or 0)
            already_out = (dx * dx + dy * dy) <= 25      -- within 5yd of it
        end
    end

    if not already_out then
        _retreat_dest = M.retreat_point(ctx, objects, limit)
    end
    local dest = _retreat_dest

    _hold_until = now + HOLD_SECONDS
    if _wait_since == 0 then
        _wait_since = now
        _wait_key, _wait_value = wait_key, wait_value
    end

    if shared._pull_warned_at ~= reason then
        shared._pull_warned_at = reason
        ctx.debug_log("PULL_SAFETY: not pulling — " .. reason ..
            (dest and " (backing off)" or " (nowhere to back off to, holding)"))
        local ns = _G.EaxAutoQuester
        if ns and ns.set_warning then
            ns.set_warning("Not pulling: " .. reason, 4.0)
        end
    end

    return true
end

-- ============================================================================
-- The one checkpoint
-- ============================================================================

-- Lazy, like waypoint_fixer above: nav_destination reaches back for this module (lazily) when
-- nav_state applies the retreat, and the gate must load before it regardless of require order.
local _nav_destination = nil
local function nav_destination()
    if not _nav_destination then
        local ok, nd = pcall(require, "shared/nav_destination")
        if ok and nd then _nav_destination = nd end
    end
    return _nav_destination
end

-- The approach rule: a fight range at or below melee reach is not a stand-off — the class swings
-- on contact, so its walk goes all the way in; above it the class fights from range and stops at
-- that range. One rule, here, so no lane restates the threshold.
local MELEE_REACH_SQ = 9

--- The stand-off an approach walk carries: the fight range itself for a class that fights from
--- range, nothing (walk all the way in) for one that swings in melee.
--- @param approach_sq number|nil squared distance the fight is approached for
--- @return number|nil stand_off_sq
local function stand_off_for(approach_sq)
    if not approach_sq then return nil end
    return approach_sq > MELEE_REACH_SQ and approach_sq or nil
end

--- May this fight start — and if so, open it.
---
--- The one door between "there is a hostile" and "the bot commits to it": the gate has the first
--- and only word, and on a pass the approach walk is issued HERE, through the nav owner, so a
--- call site cannot reach its swing without having asked. A refusal has already parked the bot,
--- armed the hold and said why — the recovery pause the hold allows runs during it — and nil is
--- the caller's signal that this tick must not begin a fight. The caller's remaining job is the
--- fight itself (the ranged cast, the melee swing), which no other module can own.
---
--- opts (all optional):
---   objects, limit   passed through to the gate's crowd scan, when the caller already holds them
---   dist_sq          the caller's own distance measurement, when it is fresher than a re-read
---   approach_sq      squared distance beyond which this fight is approached, not opened; the
---                    walk's stand-off is derived from it (the range the fight is held at)
---   stand_off_sq     explicit stand-off override; nil derives it from approach_sq, and a melee
---                    range closes all the way in
---
--- @param ctx table Per-tick context
--- @param shared table Shared state variables
--- @param enemy game_object|nil the hostile the caller is about to engage
--- @param opts table|nil
--- @return table|nil nil = the fight may not start this tick; else its geometry:
---   { me_pos, enemy_pos, dist_sq, out_of_range, walked }
function M.engage(ctx, shared, enemy, opts)
    if not enemy or not shared then return nil end
    opts = opts or {}

    -- The gate's word is final: a refusal has already done everything a refusal does.
    if M.gate(ctx, shared, enemy, opts.objects, opts.limit) then return nil end

    local me = ctx and ctx.me
    local ok_me, me_pos = false, nil
    if me then
        ok_me, me_pos = pcall(unit_get_position, me)
    end
    local ok_pos, enemy_pos = pcall(unit_get_position, enemy)

    -- The caller's measurement wins (it may be the scan's own); otherwise read it fresh. A
    -- distance of 1e9 when utils are missing mirrors what every engage site already assumed.
    local dist_sq = opts.dist_sq
    if dist_sq == nil and ok_me and me_pos and ok_pos and enemy_pos then
        dist_sq = (ctx.utils and ctx.utils.squared_distance(me_pos, enemy_pos)) or 1e9
    end

    -- The approach is part of the engage: farther than the threshold, the walk to the fight is
    -- issued here and now — through the nav owner, the stand-off riding on it — so "asked the
    -- gate" and "walked into range" are one action no site can take separately.
    local out_of_range = (opts.approach_sq ~= nil and dist_sq ~= nil and dist_sq > opts.approach_sq)
    local walked = false
    if out_of_range and ok_pos and enemy_pos then
        local nd = nav_destination()
        if nd then
            -- The stand-off is derived, not restated: the walk stops at the range the fight is
            -- approached for, and a melee range closes all the way in. An explicit stand_off_sq
            -- still wins, so a genuinely different approach stays expressible.
            local stand_off_sq = opts.stand_off_sq
            if stand_off_sq == nil then stand_off_sq = stand_off_for(opts.approach_sq) end
            nd.engage(shared, enemy, enemy_pos, stand_off_sq)
            walked = true
        end
    end

    return {
        me_pos = (ok_me and me_pos) or nil,
        enemy_pos = (ok_pos and enemy_pos) or nil,
        dist_sq = dist_sq,
        out_of_range = out_of_range,
        walked = walked,
    }
end

--- Close to melee and swing: the walk-in half of the approach rule, named here so a lane that
--- means "no stand-off" says so through this module instead of passing a bare nil at the nav
--- owner. The nav owner's nil convention is what this expresses (test_nav_destination_ownership
--- S3 pins it); the band half is derived by M.engage.
--- @param shared table Shared state variables
--- @param enemy game_object|nil the live unit being closed on
--- @param point table|nil vec3 where it stands, as the caller measured it
--- @return boolean closed true when the walk was issued
function M.close_in(shared, enemy, point)
    if not (shared and point) then return false end
    local nd = nav_destination()
    if not nd then return false end
    nd.engage(shared, enemy, point, nil)
    return true
end

return M
