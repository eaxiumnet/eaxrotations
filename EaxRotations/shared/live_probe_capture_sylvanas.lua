-- live_probe_capture_sylvanas.lua — the CLEU capture ring.
-- WHAT:  arm()/disarm()/status()/flush(): a fixed 64-slot numeric ring fed by
--        COMBAT_LOG_EVENT_UNFILTERED (own form changes with their energy
--        snapshot, own DoT ticks with their interval, incoming damage with the
--        rage it produced) plus one raw first-event arg dump. on_arm()/on_flush()
--        let a read-only probe hook the capture's two moments.
-- WHEN:  armed from a Diagnostics entry; nothing registers until arm() runs, and
--        one boolean test gates the handler when disarmed.
-- WHY:   an in-game action should record itself instead of being timed by hand,
--        with watch ids supplied by the caller (bridge/DBC), never guessed.
-- SAFETY: numbers only in the handler (formatting happens on flush), a fixed
--        ring with a dropped counter, foreign-source events ignored, and a
--        scope gate so a capture records only what was asked for.
local NS = _G.EaxRotations
if not NS then return nil end
local type = type
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local kit = require("shared/live_probe_kit_sylvanas")
local out, safe, player, now, power_of = kit.out, kit.safe, kit.player, kit.now, kit.power_of
local M = {}
local CLEU = "COMBAT_LOG_EVENT_UNFILTERED"

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
local RING_CAPACITY = 64        -- slots; the handler never grows anything
local RAW_ARG_LIMIT = 24        -- CLEU fixed-prefix width worth dumping

local KIND_FORM = 1             -- an aura the caller watches appearing/leaving
local KIND_INCOMING = 2         -- damage/swing the player took
local KIND_TICK = 3             -- a watched periodic-damage tick

-- ---------------------------------------------------------------------------
-- State: preallocated ring (numbers only), reused every event
-- ---------------------------------------------------------------------------
local _ring = {}
local _ring_head = 0
local _ring_dropped = 0
local _last_tick_time = {}      -- spell_id -> last tick timestamp (delta source)

local _armed = false
local _registered = false
local _watch_forms = {}         -- spell_id -> true
local _watch_spells = {}        -- spell_id -> true
-- Counted explicitly: these are maps keyed by spell id, so #table is
-- undefined (returns 0) -- status()/the arm log must not lie about them.
local _watch_form_count = 0
local _watch_spell_count = 0
local _raw_budget = 0
local _scope = "all"            -- capture scope: all | forms | dots | rage
local _raw_args = nil

for i = 1, RING_CAPACITY do
    _ring[i] = { t = 0, kind = 0, spell = 0, a = 0, b = 0, c = 0 }
end

local _on_arm = nil
local _on_flush = nil

-- ---------------------------------------------------------------------------
-- Capture ring: numbers in, formatted on flush
-- ---------------------------------------------------------------------------
local function push_slot(kind, spell, a, b, c, t)
    _ring_head = _ring_head + 1
    if _ring_head > RING_CAPACITY then
        _ring_dropped = _ring_dropped + 1
        _ring_head = RING_CAPACITY
        return
    end
    local slot = _ring[_ring_head]
    slot.kind, slot.spell, slot.a, slot.b, slot.c, slot.t = kind, spell, a, b, c, t
end

local function args_num(args, index)
    local v = args and args[index]
    v = tonumber(v)
    return v or 0
end

-- The CLEU handler: one boolean test when disarmed, numbers only when armed.
-- Is the CLEU guid in this 1-based arg slot (4 = source, 8 = destination)
-- this player's? Compared as string and as number because builds differ in
-- which shape the dispatcher hands over; a foreign-source event is never a
-- probe of this character.
local function player_guid_matches(args, index)
    local p = player()
    if p == nil then return false end
    local guid = safe(p.get_guid, p)
    if guid == nil then guid = p.guid end
    if guid == nil then return false end
    local other = args and args[index]
    if other == nil then return false end
    if guid == other then return true end
    local guid_num = tonumber(p.guid)
    return guid_num ~= nil and guid_num == tonumber(other)
end

local function on_game_event(event_name, args)
    if not _armed then return end
    if event_name ~= CLEU then return end

    if _raw_budget > 0 then
        _raw_budget = _raw_budget - 1
        local snapshot_args = {}
        for i = 1, RAW_ARG_LIMIT do
            snapshot_args[i] = args and args[i]
        end
        _raw_args = snapshot_args
    end

    local sub = args and args[2]
    local spell = tonumber(args and args[12])
    local stamp = args_num(args, 1)
    if stamp == 0 then stamp = now() end

    -- Own-aura changes. A non-empty watch list filters by id; an empty one
    -- (scope all) records every own aura, which is how the menu arms with no
    -- id input. Source must be this player: someone else's aura is not a probe.
    if spell and (_scope == "all" and #_watch_forms == 0 or _watch_forms[spell])
        and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REMOVED")
        and player_guid_matches(args, 4) then
        local p = player()
        push_slot(KIND_FORM, spell, power_of(p, NS.POWER_ENERGY),
            power_of(p, NS.POWER_RAGE), sub == "SPELL_AURA_APPLIED" and 1 or 0, stamp)
        return
    end

    -- Own periodic ticks. An empty watch list (scope all/dots) records every
    -- own DoT tick, so an id-free session can still measure an interval.
    if spell and (_scope == "all" or _scope == "dots")
        and (#_watch_spells == 0 or _watch_spells[spell])
        and sub == "SPELL_PERIODIC_DAMAGE"
        and player_guid_matches(args, 4) then
        local previous = _last_tick_time[spell]
        local delta = previous and (stamp - previous) or 0
        _last_tick_time[spell] = stamp
        push_slot(KIND_TICK, spell, delta, args_num(args, 15), 0, stamp)
        return
    end

    -- Incoming damage -> the rage it produced (the rage-from-damage curve).
    if (_scope == "all" or _scope == "rage")
        and (sub == "SWING_DAMAGE" or sub == "SWING_MISSED" or sub == "SPELL_DAMAGE")
        and player_guid_matches(args, 8) then
        push_slot(KIND_INCOMING, spell or 0, args_num(args, 15),
            power_of(player(), NS.POWER_RAGE), 0, stamp)
    end
end

local function ensure_registered()
    if _registered then return true end
    if type(NS.register_on_game_event) ~= "function" then return false end
    local ok = pcall(NS.register_on_game_event, CLEU, on_game_event)
    if ok then _registered = true end
    return _registered
end

-- arm({ forms = {id,...}, spells = {id,...}, raw_events = N })
function M.arm(opts)
    opts = opts or {}
    _watch_forms = {}
    _watch_spells = {}
    _watch_form_count = 0
    _watch_spell_count = 0
    _last_tick_time = {}
    local forms = opts.forms
    if type(forms) == "table" then
        for i = 1, #forms do
            local id = tonumber(forms[i])
            if id then
                _watch_forms[id] = true
                _watch_form_count = _watch_form_count + 1
            end
        end
    end
    local spells = opts.spells
    if type(spells) == "table" then
        for i = 1, #spells do
            local id = tonumber(spells[i])
            if id then
                _watch_spells[id] = true
                _watch_spell_count = _watch_spell_count + 1
            end
        end
    end
    _raw_budget = tonumber(opts.raw_events) or 0
    _scope = type(opts.scope) == "string" and opts.scope or "all"
    _raw_args = nil
    _ring_head = 0
    _ring_dropped = 0
    -- Read-only probes observe this moment (0.5 snapshots its surfaces).
    if _on_arm then _on_arm() end
    _armed = ensure_registered()
    if not _armed then
        out("[LiveProbe] arm FAILED: NS.register_on_game_event unavailable")
    else
        out(string_format("[LiveProbe] armed: scope=%s, %s form id(s), %s watch id(s), raw_events=%d",
            tostring(_scope), tostring(_watch_form_count), tostring(_watch_spell_count), _raw_budget))
    end
    return _armed
end

function M.disarm()
    _armed = false
    out("[LiveProbe] disarmed")
    return true
end

function M.status()
    return {
        armed = _armed, registered = _registered, scope = _scope,
        captured = _ring_head, dropped = _ring_dropped,
        forms = _watch_form_count, spells = _watch_spell_count,
    }
end

local function format_slot(slot)
    if slot.kind == KIND_FORM then
        return string_format("[LiveProbe] FORM id=%d energy=%s rage=%s %s",
            slot.spell, tostring(slot.a), tostring(slot.b),
            slot.c == 1 and "applied" or "removed")
    end
    if slot.kind == KIND_TICK then
        return string_format("[LiveProbe] TICK id=%d interval=%.2fs amount=%s",
            slot.spell, (slot.a or 0), tostring(slot.b))
    end
    if slot.kind == KIND_INCOMING then
        return string_format("[LiveProbe] INCOMING spell=%d amount=%s rage=%s",
            slot.spell, tostring(slot.a), tostring(slot.b))
    end
    return "[LiveProbe] slot (empty)"
end

function M.flush()
    kit.reset_lines()
    local n = _ring_head
    if n == 0 then
        out("[LiveProbe] flush: no events captured")
        if _on_flush then _on_flush() end
        return 0, kit.lines()
    end
    out(string_format("[LiveProbe] === capture: %d event(s), %d dropped ===",
        n, _ring_dropped))
    if _raw_args then
        out("[LiveProbe] raw first-event args (confirms the CLEU layout this build sends):")
        for i = 1, RAW_ARG_LIMIT do
            out(string_format("[LiveProbe]   args[%d] = %s", i, tostring(_raw_args[i])))
        end
    end
    for i = 1, n do
        out(format_slot(_ring[i]))
    end
    if _on_flush then _on_flush() end
    out("[LiveProbe] === end capture ===")
    return n, kit.lines()
end

-- The facade wires a read-only probe in here; the ring itself knows nothing
-- about what observes it.
function M.on_arm(fn)
    _on_arm = type(fn) == "function" and fn or nil
end

function M.on_flush(fn)
    _on_flush = type(fn) == "function" and fn or nil
end
return M
