-- engine_signals_sylvanas.lua -- THE landing place for engine-derived context signals.
-- WHAT:  owns every "read a raw engine API and publish a normalised context key"
--        signal the dispatcher exposes to specs, plus the registry that makes
--        adding one a single-entry change.
-- WHEN:  main_sylvanas build_context calls M.publish(context, env) once per tick.
-- WHY:   before this module each signal was 8-15 lines of bespoke pcall
--        boilerplate inlined in build_context, so a new signal had no obvious
--        home and the school-lockout / cast-end-time / channel-id producers each
--        re-invented the same safe-read + fail-open shape.
-- SAFETY: PURE -- captures no NS at require time (the behavioral battery's
--         shared-virgin guard), allocates NOTHING per publish (the registry and
--         the env table shape are built at load), and FAILS OPEN: every signal
--         declares the value an unpopulated client must see, so a build without
--         the engine field behaves exactly as it did before the signal existed.
-- DECISION: pure module + registry; main_sylvanas owns WHEN, this owns WHAT.

local M = {}

-- Single owner of the tree's safe reads (closure-free safe_field, so these
-- readers stay allocation-free on the hot path).
local safe_helpers = require("shared/safe_helpers_sylvanas")

-- REUSED per-tick env (mutated in place by M.publish -> zero per-tick allocation).
local ENV = { me = nil, target = nil, is_channeling = false }

-- Cast/channel end-time family (shared/cast_timing_sylvanas.lua). A missing file
-- degrades to "unknown timing" (fail-open), never a load error.
local _ct_ok, cast_timing = pcall(require, "shared/cast_timing_sylvanas")
if not _ct_ok or type(cast_timing) ~= "table" then cast_timing = nil end

-- ---------------------------------------------------------------------------
-- Registry. Each entry: { key, fallback, read(env) -> value|nil }.
--   key       context field this signal publishes (the spec-facing contract)
--   fallback  value written when the engine reports nothing (the fail-open rule)
--   read      pure reader over the per-tick env table; must not allocate
--
-- A NEW ENGINE SIGNAL LANDS BY ADDING ONE ENTRY HERE (or calling M.register
-- from a sibling module). Nothing in main_sylvanas changes.
-- ---------------------------------------------------------------------------
local PUBLISHERS = {}

local function register(key, fallback, read)
    PUBLISHERS[#PUBLISHERS + 1] = { key = key, fallback = fallback, read = read }
end

-- Seconds left on the target's current cast/channel; 0 = none/unknown.
-- is_casting/is_channeling say WHETHER something is running; this says HOW LONG
-- IS LEFT, which is what an interrupt gate needs: a cast that lands before the
-- interrupt arrives must not claim the cooldown.
register("target_cast_remaining", 0, function(env)
    if not cast_timing or not env.target then return nil end
    local remaining = cast_timing.remaining(env.target)
    if type(remaining) == "number" and remaining > 0 then return remaining end
    return nil
end)

-- Id of the channel the PLAYER is running; 0 = none/unknown. The dispatcher
-- uses it to tell whether this channel is one the active spec declared
-- clip-managed (registry.channel_clip_ids) and may therefore re-enter the
-- decision loop mid-channel; 0 keeps the pre-existing blanket channel skip.
register("channel_spell_id", 0, function(env)
    if not cast_timing or not env.is_channeling or not env.me then return nil end
    local channel_id = cast_timing.channel_id(env.me)
    if type(channel_id) == "number" and channel_id > 0 then return channel_id end
    return nil
end)

-- Engine school lockout (interrupted school) as a schools_flag bitmask, so specs
-- can fall back to an OFF-SCHOOL spell instead of queueing a locked cast
-- (shared/spell_school_gate_sylvanas.lua). 0 = nothing locked.
register("school_lockout", 0, function(env)
    local me = env.me
    if not me then return nil end
    local loc_fn = safe_helpers.safe_field(me, "get_loss_of_control_info")
    if type(loc_fn) ~= "function" then return nil end
    local ok, loc = pcall(loc_fn, me)
    if ok and type(loc) == "table" and loc.valid
        and type(loc.lockout_school) == "number" and loc.lockout_school > 0 then
        return loc.lockout_school
    end
    return nil
end)

--- Register an additional engine signal (sibling modules / future signals).
-- @param key       context field to publish
-- @param fallback  fail-open value written when the reader yields nil
-- @param read      function(env) -> value|nil
function M.register(key, fallback, read)
    if type(key) ~= "string" or type(read) ~= "function" then return false end
    register(key, fallback, read)
    return true
end

--- Publish every registered signal onto the context.
-- pcall'd per publisher so one throwing engine accessor can never break the
-- tick; a nil read (or an error) writes the signal's fail-open value.
-- The three engine handles are PASSED IN rather than held in a caller-built
-- table: the dispatcher's build_context is at Lua 5.1's 60-upvalue ceiling, so a
-- module-local env there would be one upvalue too many. The env table below is
-- module-owned and mutated in place, so publishing allocates nothing per tick.
-- @param context       the per-tick context table
-- @param me            player game_object (or nil)
-- @param target        current target game_object (or nil)
-- @param is_channeling whether the PLAYER is currently channeling
function M.publish(context, me, target, is_channeling)
    if not context then return end
    ENV.me = me
    ENV.target = target
    ENV.is_channeling = is_channeling
    for i = 1, #PUBLISHERS do
        local publisher = PUBLISHERS[i]
        local ok, value = pcall(publisher.read, ENV)
        if ok and value ~= nil then
            context[publisher.key] = value
        else
            context[publisher.key] = publisher.fallback
        end
    end
end

--- Names of the context keys this module owns (diagnostics / audits).
function M.keys()
    local out = {}
    for i = 1, #PUBLISHERS do out[i] = PUBLISHERS[i].key end
    return out
end

return M
