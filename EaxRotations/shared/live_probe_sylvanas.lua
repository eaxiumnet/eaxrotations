-- live_probe_sylvanas.lua — in-engine capture harness for the live-beta engine-truth probes.
-- WHAT:  three surfaces for docs/forever/beta_smoke_checklist.md blocks 0-1:
--        report() dumps engine truth (expansion/version surface, race, the
--        capability matrix, and aura points incl. absorb reads); sample(tag)
--        prints one snapshot line of the values the gate probes read
--        (form/energy/rage/mana/hp/combo/haste/AP + target); and
--        arm()/flush()/disarm() run a CLEU capture ring so the in-game action
--        records itself (form shift -> energy, incoming damage -> rage, DoT
--        tick -> interval) instead of being timed by hand.
-- WHEN:  loaded at startup (inert until called: no registration, no work).
-- WHY:   the four Block-0 items and the three Block-1 gates are all "read an
--        engine value at a moment"; every estimated threshold in the kits stays
--        an estimate until these reads exist. A fixed ring that stores numbers
--        in the handler and formats only on flush keeps the capture honest and
--        the hot path allocation-free.
-- SAFETY: never guesses an id -- arm() receives the watch ids from the caller
--        (DBC/bridge-derived), so no literal spell id lives here; every surface
--        read is pcall/nil-guarded; capture is off by default; the ring is
--        fixed-size with a dropped counter; handler stores numbers only.
--        No banned APIs: no ffi/io/os.execute/debug.

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local type = type
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local table_insert = table.insert
local math_floor = math.floor

local M = {}
NS.LiveProbe = M

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
local _raw_budget = 0
local _raw_args = nil
local _lines = {}               -- flush output, reused

for i = 1, RING_CAPACITY do
    _ring[i] = { t = 0, kind = 0, spell = 0, a = 0, b = 0, c = 0 }
end

-- ---------------------------------------------------------------------------
-- Surface helpers (every read guarded; nil means "engine does not expose it")
-- ---------------------------------------------------------------------------
local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok then return nil end
    return value
end

local function now()
    local t = safe(NS.time_now)
    if type(t) == "number" then return t end
    local core = _G.core
    if core and core.time and type(core.time.get) == "function" then
        local v = safe(core.time.get)
        if type(v) == "number" then return v end
    end
    return 0
end

local function player()
    local p = safe(NS.GetPlayer)
    if p then return p end
    local core = _G.core
    if core and core.object_manager and core.object_manager.get_local_player then
        return safe(core.object_manager.get_local_player)
    end
    return nil
end

-- Candidate accessors are probed BY NAME through a runtime index, never read as
-- compile-time fields: the matrix exists to learn which of them this build
-- actually exposes, so a member that is absent reports ABSENT instead of being
-- a field read that can never be produced. This is also the one honest way to
-- list a surface the repo does not define yet -- the name is data here.
local ROOTS = {
    ns = function() return NS end,
    core = function()
        local c = _G.core
        if type(c) ~= "table" then return nil end
        return c
    end,
    player = function() return player() end,
}

local function lookup(kind, key)
    local provider = ROOTS[kind]
    if not provider then return nil end
    local root = provider()
    if type(root) ~= "table" then return nil end
    return root[key]
end

local SURFACES = {
    { "NS.buff_points", "ns", "buff_points" },
    { "NS.debuff_points", "ns", "debuff_points" },
    { "NS.has_player_buff", "ns", "has_player_buff" },
    { "NS.spell_ready", "ns", "spell_ready" },
    { "NS.cooldown_remains", "ns", "cooldown_remains" },
    { "NS.unit_mana_pct", "ns", "unit_mana_pct" },
    { "NS.GetPlayer", "ns", "GetPlayer" },
    { "core.register_on_game_event_callback", "core", "register_on_game_event_callback" },
    { "NS.register_on_game_event", "ns", "register_on_game_event" },
    { "player:get_buffs", "player", "get_buffs" },
    { "player:get_auras", "player", "get_auras" },
    { "player:get_debuffs", "player", "get_debuffs" },
    { "player:get_power", "player", "get_power" },
    { "player:get_form", "player", "get_form" },
    { "player:get_shapeshift_form", "player", "get_shapeshift_form" },
    { "player:get_attack_power", "player", "get_attack_power" },
    { "player:get_haste", "player", "get_haste" },
    { "player:is_mounted", "player", "is_mounted" },
    { "player:get_race", "player", "get_race" },
}

local EXPANSION_SURFACES = {
    { "NS.expansion_key", "ns", "expansion_key" },
    { "NS.get_expansion_key", "ns", "get_expansion_key" },
    { "NS.expansion", "ns", "expansion" },
    { "core.get_game_version", "core", "get_game_version" },
    { "core.game_version", "core", "game_version" },
    { "core.expansion_key", "core", "expansion_key" },
}

local function push_line(text)
    _lines[#_lines + 1] = text
end

local function out(text)
    push_line(text)
    if NS.log then pcall(NS.log, text) end
end

-- ---------------------------------------------------------------------------
-- Aura points (Block 0.3): points[1] is the Pattern-11 variable value -- for an
-- absorb that is the remaining shield. Rows come from the aura surface; ids from
-- the row, values from NS.buff_points, so nothing is hardcoded.
-- ---------------------------------------------------------------------------
local function aura_rows(p)
    if not p then return nil end
    local probe = NS.AuraProbe
    if probe and type(probe.collect_player_auras) == "function" then
        local rows = safe(probe.collect_player_auras, p)
        if type(rows) == "table" then return rows end
    end
    return nil
end

local function report_aura_points(p)
    local points_fn = NS.buff_points
    if type(points_fn) ~= "function" then
        out("[LiveProbe] points: NS.buff_points ABSENT -- Pattern-11 reads unavailable on this build")
        return 0
    end
    local rows = aura_rows(p)
    if not rows then
        out("[LiveProbe] points: no aura surface (get_buffs/get_auras/debuffs absent)")
        return 0
    end
    local shown = 0
    for i = 1, #rows do
        local row = rows[i]
        local id = row and tonumber(row.id)
        if id then
            local pts = safe(points_fn, p, { id })
            local first = type(pts) == "table" and tonumber(pts[1]) or nil
            if first then
                shown = shown + 1
                out(string_format("[LiveProbe] points id=%s name=%s points[1]=%s (%s)",
                    tostring(id), tostring(row.name or "?"), tostring(first),
                    tostring(row.source or "aura")))
            end
        end
    end
    out(string_format("[LiveProbe] points: %d aura row(s) exposed a points value", shown))
    return shown
end

-- ---------------------------------------------------------------------------
-- M.report(): Block 0 truth dump
-- ---------------------------------------------------------------------------
function M.report()
    _lines = {}
    out("[LiveProbe] === engine-truth report ===")

    for i = 1, #EXPANSION_SURFACES do
        local entry = EXPANSION_SURFACES[i]
        local value = lookup(entry[2], entry[3])
        local shown = value == nil and "absent" or tostring(value)
        if type(value) == "function" then shown = "present (callable)" end
        out(string_format("[LiveProbe] version %s = %s", entry[1], shown))
    end

    local p = player()
    out(string_format("[LiveProbe] player = %s", p and "resolved" or "NIL (no local player)"))

    local matrix = {}
    local present = 0
    for i = 1, #SURFACES do
        local entry = SURFACES[i]
        local value = lookup(entry[2], entry[3])
        local state = value == nil and "ABSENT" or "present"
        if value ~= nil then present = present + 1 end
        matrix[#matrix + 1] = { name = entry[1], state = state }
        out(string_format("[LiveProbe] surface %-42s %s", entry[1], state))
    end
    out(string_format("[LiveProbe] capability matrix: %d/%d surfaces present",
        present, #SURFACES))

    if p then
        local race = safe(p.get_race, p)
        if race == nil then race = p.race end
        out(string_format("[LiveProbe] race = %s", tostring(race or "unreadable")))
        report_aura_points(p)
    end

    local report = { lines = _lines, matrix = matrix, player = p ~= nil, present = present }
    M._last_report = report
    out("[LiveProbe] === end report ===")
    return report
end

-- ---------------------------------------------------------------------------
-- M.sample(tag, context): one snapshot line at the moment of an in-game action
-- ---------------------------------------------------------------------------
local function power_of(p, power_type)
    if not p then return nil end
    if type(p.get_power) ~= "function" then return nil end
    local v = safe(p.get_power, p, power_type)
    return tonumber(v)
end

local function snapshot(p, context)
    local form = nil
    if p then
        form = safe(p.get_form, p) or safe(p.get_shapeshift_form, p)
    end
    local energy = context and tonumber(context.energy) or power_of(p, NS.POWER_ENERGY)
    local rage = context and tonumber(context.rage) or power_of(p, NS.POWER_RAGE)
    if rage == nil then rage = power_of(p, NS.POWER_RAGE) end
    local mana_pct = context and tonumber(context.mana_pct) or safe(NS.unit_mana_pct, p)
    local ap = p and safe(p.get_attack_power, p) or nil
    local haste = p and safe(p.get_haste, p) or nil
    return {
        form = form, energy = energy, rage = rage, mana_pct = mana_pct,
        hp_pct = context and tonumber(context.hp_pct) or nil,
        combo = context and tonumber(context.combo_points) or nil,
        ap = tonumber(ap), haste = tonumber(haste),
        t = now(),
    }
end

function M.sample(tag, context)
    _lines = {}
    local p = player()
    local s = snapshot(p, context)
    out(string_format(
        "[LiveProbe] %s t=%.2f form=%s energy=%s rage=%s mana=%s hp=%s combo=%s ap=%s haste=%s",
        tostring(tag or "sample"), s.t, tostring(s.form or "-"), tostring(s.energy or "-"),
        tostring(s.rage or "-"), tostring(s.mana_pct or "-"), tostring(s.hp_pct or "-"),
        tostring(s.combo or "-"), tostring(s.ap or "-"), tostring(s.haste or "-")))
    return s
end

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

    if spell and _watch_forms[spell] then
        if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REMOVED" then
            local p = player()
            push_slot(KIND_FORM, spell, power_of(p, NS.POWER_ENERGY),
                power_of(p, NS.POWER_RAGE), sub == "SPELL_AURA_APPLIED" and 1 or 0, stamp)
            return
        end
    end

    if spell and _watch_spells[spell] and sub == "SPELL_PERIODIC_DAMAGE" then
        local previous = _last_tick_time[spell]
        local delta = previous and (stamp - previous) or 0
        _last_tick_time[spell] = stamp
        push_slot(KIND_TICK, spell, delta, args_num(args, 15), 0, stamp)
        return
    end

    if sub == "SWING_DAMAGE" or sub == "SWING_MISSED" or sub == "SPELL_DAMAGE" then
        local p = player()
        local guid = p and safe(p.get_guid, p) or nil
        if guid == nil and p then guid = p.guid end
        local guid_num = p and tonumber(p.guid)
        local destination = args and args[8]
        if guid ~= nil and (guid == destination or (guid_num and guid_num == tonumber(destination))) then
            push_slot(KIND_INCOMING, spell or 0, args_num(args, 15),
                power_of(p, NS.POWER_RAGE), 0, stamp)
        end
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
    _last_tick_time = {}
    local forms = opts.forms
    if type(forms) == "table" then
        for i = 1, #forms do
            local id = tonumber(forms[i])
            if id then _watch_forms[id] = true end
        end
    end
    local spells = opts.spells
    if type(spells) == "table" then
        for i = 1, #spells do
            local id = tonumber(spells[i])
            if id then _watch_spells[id] = true end
        end
    end
    _raw_budget = tonumber(opts.raw_events) or 0
    _raw_args = nil
    _ring_head = 0
    _ring_dropped = 0
    _armed = ensure_registered()
    if not _armed then
        out("[LiveProbe] arm FAILED: NS.register_on_game_event unavailable")
    else
        out(string_format("[LiveProbe] armed: %s form id(s), %s watch id(s), raw_events=%d",
            tostring(forms and #forms or 0), tostring(spells and #spells or 0), _raw_budget))
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
        armed = _armed, registered = _registered,
        captured = _ring_head, dropped = _ring_dropped,
        forms = #_watch_forms, spells = #_watch_spells,
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
    _lines = {}
    local n = _ring_head
    if n == 0 then
        out("[LiveProbe] flush: no events captured")
        return 0, _lines
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
    out("[LiveProbe] === end capture ===")
    return n, _lines
end

function M.get_last_report()
    return M._last_report, _lines
end

return M
