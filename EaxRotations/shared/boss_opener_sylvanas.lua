-- boss_opener_sylvanas.lua -- ordered boss-opener sequencer.
--
-- WHAT:  owns the ORDER of a raid opener. A spec declares an ordered list of
--        steps (ability name + spell id); while the opener is armed, only the
--        step at the head of the list may claim the GCD. Casting it advances
--        the head, so a later step can never jump the queue.
--
-- WHY:   the cooldown lanes were independent. Every one of them was gated only
--        on its own readiness, so they fired in list order on the same tick
--        chain -- or, worse, Heroism/Lust could leave before the Fire Elemental
--        that was supposed to be on the ground first. "Fire Elemental, then
--        Heroism, then Elemental Mastery" is an order, and an order needs one
--        owner rather than three lanes that each believe they are next.
--
-- WHEN:  armed = in combat AND the target is a raid boss
--        (context.target_is_boss, produced by main_sylvanas). Off a boss the
--        sequencer is INERT and every lane falls back to its own readiness gate,
--        so trash/leveling behavior is exactly what it was.
--
-- SAFETY: FAIL-OPEN. An unknown key, no declaration, a completed sequence, or a
--         never-armed opener all make turn() true, which hands the decision back
--         to the lane's own gate. Nothing here reads the engine, allocates on
--         the hot path, or holds combat state that outlives the fight: the head
--         resets to the first step whenever the opener is disarmed.
--
-- DECISION: advance is driven by the lane's OWN successful cast (the custom
--         action calls advance() only when NS.try_cast returned true), not by
--         guessing from cooldowns. A refused cast therefore holds the opener
--         (the lane keeps its turn until it lands). Known limit: a cast that the
--         queue accepts and then silently drops still advances the head; the
--         cast-confirmation state machine is what detects that case.

local M = {}

local _defs = {}       -- key -> { { name = ..., spell = ..., opts = ... }, ... }
local _head = {}       -- key -> index of the step that currently owns the turn

--- Declare (or re-declare) an ordered opener. Progress is preserved, so a
--- re-loaded spec does not restart a fight that is already underway.
-- @param key   string
-- @param steps table  Ordered array of { name = string, spell = any, opts = table|nil }.
-- @return boolean true when the declaration was accepted.
function M.define(key, steps)
    if type(key) ~= "string" or type(steps) ~= "table" or #steps == 0 then return false end
    _defs[key] = steps
    if _head[key] == nil then _head[key] = 1 end
    return true
end

--- The declared order for a key (nil when nothing was declared).
function M.steps(key)
    return _defs[key]
end

--- True when the opener should be armed: a boss fight the spec is opted into.
-- @param state table  Must expose .in_combat and .target_is_boss.
-- @return boolean
function M.armed(state)
    if type(state) ~= "table" then return false end
    return state.in_combat == true and state.target_is_boss == true
end

--- Sync the head with the fight and report it.
-- Disarming (out of combat, or off a boss) resets the head to the first step,
-- which is what makes the next pull a fresh opener.
-- @param key    string
-- @param active boolean  M.armed(state)
-- @return number index  1..#steps while armed, 0 when inert
function M.sync(key, active)
    local def = _defs[key]
    if not def then return 0 end
    if not active then
        _head[key] = 1
        return 0
    end
    local head = _head[key] or 1
    if head > #def then return 0 end   -- sequence finished: lanes are free again
    _head[key] = head
    return head
end

--- May this step claim the GCD right now?
-- FAIL-OPEN: true whenever the opener is inert (not armed, undeclared, or the
-- sequence has already finished), so the lane falls back to its own gate.
-- @param key    string
-- @param active boolean   M.armed(state), as cached in state.opener_active
-- @param head   number    state.opener_step (0 when inert)
-- @param name   string    the step this lane owns
-- @return boolean
function M.turn(key, active, head, name)
    if not active then return true end
    if type(head) ~= "number" or head <= 0 then return true end
    local def = _defs[key]
    if not def then return true end
    local step = def[head]
    if not step then return true end
    return step.name == name
end

--- Record that the lane owning this step landed its cast, and advance the head.
-- A name that does not own the current turn is refused, so a lane that fired
-- out of order (or twice) cannot skip a step.
-- @return boolean true when the head advanced.
function M.advance(key, name)
    local def = _defs[key]
    if not def or type(name) ~= "string" then return false end
    local head = _head[key] or 1
    local step = def[head]
    if not step or step.name ~= name then return false end
    _head[key] = head + 1
    return true
end
return M
