-- live_probe_sylvanas.lua — in-engine capture harness for the live-beta engine-truth probes.
-- WHAT:  five surfaces for docs/forever/beta_smoke_checklist.md blocks 0-1:
--        report() dumps engine truth (expansion/version surface, race, the
--        capability matrix, and aura points incl. absorb reads); sample(tag)
--        prints one snapshot line of the values the gate probes read
--        (form/energy/rage/mana/hp/combo/haste/AP + target); and
--        arm()/flush()/disarm() run a CLEU capture ring so the in-game action
--        records itself (form shift -> energy, incoming damage -> rage, DoT
--        tick -> interval) instead of being timed by hand; and
--        reader_report() (Block 0.4) inventories the external-reader
--        surfaces this build exposes -- the built-in damage meter, the
--        cooldown readers our CD lanes use, the engine CD modules, and a
--        name scan over the engine table's own keys; and integrity_report()
--        (Block 0.5) reads the client's own integrity/error surface state
--        (log sinks, engine tables, runtime generations, a live-read canary)
--        at arm and at flush, so a capture carries its own evidence that
--        nothing reacted while the engine ran.
-- WHEN:  loaded at startup (inert until called: no registration, no work).
--        Run from either menu implementation's Diagnostics section: the
--        operations are published as one list (menu_buttons()) because the
--        engine has no console, arm scope picks what is recorded, and form
--        watch ids resolve BY NAME from the class spell map.
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
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local table_insert = table.insert
local table_sort = table.sort
local table_concat = table.concat
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
-- Counted explicitly: these are maps keyed by spell id, so #table is
-- undefined (returns 0) -- status()/the arm log must not lie about them.
local _watch_form_count = 0
local _watch_spell_count = 0
local _raw_budget = 0
local _scope = "all"            -- capture scope: all | forms | dots | rage
local _raw_args = nil
local _lines = {}               -- flush output, reused
local _integrity_at_arm = nil   -- 0.5: engine surface state when armed

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
-- Engine integrity / error surfaces (Block 0.5)
--
-- 0.5 asks whether anything in the client reacts to the engine running (the
-- memory-reads/no-addon-API posture), and the only honest evidence a plugin can
-- gather without a console is the client's own surface state, read at both ends
-- of a capture:
--   * the surface snapshot -- every engine/framework surface this tree depends
--     on (the log sinks, spell_book, object_manager, input, menu, time, game_ui,
--     damage_meter), the runtime generations, and our API-health stub, each by
--     value or type, resolved at RUNTIME by name. A capture diffs arm -> flush:
--     a surface that vanished or changed type, or a bumped generation, IS the
--     integrity reaction this block is looking for.
--   * a liveness canary -- one real engine read (core.time, callable or as a
--     table with get/now) called at both ends, so "the API still answers" is
--     observed rather than assumed.
-- These reads WRITE nothing to the engine: no log lines, no state changes.
-- ---------------------------------------------------------------------------
local INTEGRITY_DIFF_LIMIT = 16     -- changed surfaces listed per comparison
local INTEGRITY_SURFACES = {
    { root = "core", name = "runtime_generation", label = "core.runtime_generation", mode = "value" },
    { root = "ns", name = "runtime_generation", label = "NS.runtime_generation", mode = "value" },
    { root = "ns", name = "is_api_health_broken", label = "NS.is_api_health_broken()", mode = "call" },
    { root = "ns", name = "reset_api_health", label = "NS.reset_api_health", mode = "type" },
    { root = "core", name = "log", label = "core.log", mode = "type" },
    { root = "core", name = "log_warning", label = "core.log_warning", mode = "type" },
    { root = "core", name = "log_error", label = "core.log_error", mode = "type" },
    { root = "core", name = "spell_book", label = "core.spell_book", mode = "type" },
    { root = "core", name = "object_manager", label = "core.object_manager", mode = "type" },
    { root = "core", name = "input", label = "core.input", mode = "type" },
    { root = "core", name = "menu", label = "core.menu", mode = "type" },
    { root = "core", name = "time", label = "core.time", mode = "type" },
    { root = "core", name = "game_ui", label = "core.game_ui", mode = "type" },
    { root = "core", name = "damage_meter", label = "core.damage_meter", mode = "type" },
}

local function integrity_value(entry)
    local value = lookup(entry.root, entry.name)
    if entry.mode == "call" then
        if type(value) ~= "function" then return "ABSENT" end
        local ok, result = pcall(value)
        if ok then return "callable -> " .. tostring(result) end
        return "callable -> ERROR " .. tostring(result)
    end
    if value == nil then return "ABSENT" end
    if entry.mode == "type" then return type(value) end
    return type(value) .. " " .. tostring(value)
end

-- One real engine read, called at both ends of the capture.
local function integrity_canary()
    local time_surface = lookup("core", "time")
    local fn = nil
    if type(time_surface) == "function" then
        fn = time_surface
    elseif type(time_surface) == "table" then
        for _, key in ipairs({ "get", "now" }) do
            if type(time_surface[key]) == "function" then
                fn = time_surface[key]
                break
            end
        end
    end
    if type(fn) ~= "function" then return "not callable" end
    local ok, result = pcall(fn)
    if not ok then return "ERROR " .. tostring(result) end
    return "ok (" .. type(result) .. ")"
end

local function integrity_snapshot()
    local snapshot = {}
    local labels = {}
    for i = 1, #INTEGRITY_SURFACES do
        local entry = INTEGRITY_SURFACES[i]
        snapshot[entry.label] = integrity_value(entry)
        labels[#labels + 1] = entry.label
    end
    snapshot["core.time live read"] = integrity_canary()
    labels[#labels + 1] = "core.time live read"
    table_sort(labels, function(a, b) return a < b end)
    local parts = {}
    for i = 1, #labels do
        parts[#parts + 1] = labels[i] .. "=" .. snapshot[labels[i]]
    end
    return snapshot, table_concat(parts, " | "), labels
end

-- The arm -> flush diff: a capture carries its own integrity evidence.
local function integrity_lines(before, after, labels)
    if not before then
        out("[LiveProbe] 0.5 integrity: nothing was armed, so there is no arm -> flush comparison")
        return 0
    end
    local changed = 0
    for i = 1, #labels do
        local label = labels[i]
        if before[label] ~= after[label] then
            changed = changed + 1
            if changed <= INTEGRITY_DIFF_LIMIT then
                out(string_format("[LiveProbe] 0.5 integrity CHANGED %s: %s -> %s",
                    label, tostring(before[label]), tostring(after[label])))
            end
        end
    end
    if changed == 0 then
        out(string_format(
            "[LiveProbe] 0.5 integrity: UNCHANGED across the capture (%d surface(s), arm signature matches) -- no integrity/error reaction",
            #labels))
    else
        out(string_format(
            "[LiveProbe] 0.5 integrity: %d surface(s) CHANGED -- the client reacted or an engine surface went away; re-run before trusting this capture",
            changed))
    end
    return changed
end

function M.integrity_report()
    _lines = {}
    out("[LiveProbe] 0.5 engine integrity -- surface state (nothing is written to the engine)")
    local snapshot, signature, labels = integrity_snapshot()
    for i = 1, #labels do
        out(string_format("[LiveProbe]   %s = %s", labels[i], snapshot[labels[i]]))
    end
    out(string_format("[LiveProbe] 0.5 state: %d surface(s) reported (signature length %d)",
        #labels, #signature))
    if _integrity_at_arm then
        out("[LiveProbe] 0.5 comparison (arm -> now):")
        integrity_lines(_integrity_at_arm, snapshot, labels)
    else
        out("[LiveProbe] 0.5 comparison: nothing armed yet -- arm a capture (any scope), run normally, then Flush to read the arm -> flush line")
    end
    return { lines = _lines, labels = labels, signature = signature, snapshot = snapshot }
end

function M.action_integrity()
    return M.integrity_report()
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
    -- 0.5: capture the engine's surface state now, to diff at flush.
    _integrity_at_arm = integrity_snapshot()
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
    _lines = {}
    local n = _ring_head
    local now_snapshot, _now_signature, now_labels = integrity_snapshot()
    if n == 0 then
        out("[LiveProbe] flush: no events captured")
        integrity_lines(_integrity_at_arm, now_snapshot, now_labels)
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
    integrity_lines(_integrity_at_arm, now_snapshot, now_labels)
    out("[LiveProbe] === end capture ===")
    return n, _lines
end

-- ---------------------------------------------------------------------------
-- External-reader surfaces (Block 0.4)
--
-- 0.4 asks what the built-in damage meter and the cooldown surfaces expose to
-- EXTERNAL READERS. The candidates below are names this tree already reads --
-- never invented: core.damage_meter.{is_available,get_session_duration}
-- (core_sylvanas.lua), core.spell_book.{get_spell_cooldown,
-- get_spell_cooldown_information}, core.game_ui.get_talent_info (main_sylvanas),
-- and the engine modules core_sylvanas adapts:
-- common/utility/cooldown_tracker.{has_any_relevant_defensive_up,is_spell_ready,
-- get_remaining_cooldown} and common/utility/spell_helper.{is_spell_castable,
-- get_remaining_charge_cooldown}. Each is resolved at RUNTIME by name, reported
-- PRESENT with the members and value types it carries, or ABSENT. A discovery
-- scan over the real engine table's own keys then reports any key whose name
-- looks meter/cooldown-ish, so a surface this build names differently is found
-- from the build's own inventory instead of being missed -- which is also the
-- only honest way to answer "is there a cooldown manager surface at all".
-- ---------------------------------------------------------------------------
local READER_MEMBER_LIMIT = 16  -- members listed per table (output bound)
local READER_SCAN_LIMIT = 24    -- discovery-scan lines (output bound)
local READER_SCAN_NEEDLES = { "meter", "cooldown", "tracker", "dps", "damage", "cd" }

local READER_TARGETS = {
    {
        root = "core", name = "damage_meter",
        label = "core.damage_meter (built-in damage meter)",
        reads = { "is_available", "get_session_duration" },
        -- The two reads our tree already makes (NS.damage_meter_session_duration):
        -- the availability flag and the current session length, in seconds.
        live = {
            { name = "is_available", args = {} },
            { name = "get_session_duration", args = { 1 } },
        },
    },
    {
        root = "core", name = "spell_book",
        label = "core.spell_book (cooldown readers)",
        reads = { "get_spell_cooldown", "get_spell_cooldown_information" },
    },
    {
        root = "core", name = "game_ui",
        label = "core.game_ui (game UI readers)",
        reads = { "get_talent_info" },
    },
}

local READER_MODULES = {
    {
        path = "common/utility/cooldown_tracker",
        label = "engine cooldown_tracker (enemy cooldown observation)",
        reads = { "has_any_relevant_defensive_up", "is_spell_ready", "get_remaining_cooldown" },
    },
    {
        path = "common/utility/spell_helper",
        label = "engine spell_helper (native readiness: cooldown/range/resource/facing/LoS)",
        reads = { "is_spell_castable", "get_remaining_charge_cooldown" },
    },
}

local function sorted_keys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        keys[#keys + 1] = key
    end
    table_sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

-- What the table carries: every member with its value type, bounded. Sorted so
-- two sessions (or two builds) diff cleanly.
local function describe_table(tbl)
    local keys = sorted_keys(tbl)
    for i = 1, #keys do
        if i > READER_MEMBER_LIMIT then
            out(string_format("[LiveProbe]     ... %d more member(s)", #keys - READER_MEMBER_LIMIT))
            break
        end
        out(string_format("[LiveProbe]     member %s = %s", tostring(keys[i]), type(tbl[keys[i]])))
    end
    out(string_format("[LiveProbe]     members: %d", #keys))
end

-- The specific reads our lanes make: present (with the value type a session
-- would have to handle) or ABSENT.
local function describe_reads(tbl, reads)
    local absent = 0
    for i = 1, #reads do
        local name = reads[i]
        local kind = type(tbl) == "table" and type(tbl[name]) or "nil"
        if kind == "nil" then
            absent = absent + 1
            out(string_format("[LiveProbe]     read %s: ABSENT", name))
        else
            out(string_format("[LiveProbe]     read %s = %s", name, kind))
        end
    end
    return absent
end

-- Live values for the reads our tree already calls, so the verdict carries the
-- actual numbers and not just the member names.
local function describe_live(tbl, live)
    for i = 1, #live do
        local entry = live[i]
        local fn = type(tbl) == "table" and tbl[entry.name] or nil
        if type(fn) ~= "function" then
            out(string_format("[LiveProbe]     live %s: not callable", entry.name))
        else
            local args = entry.args or {}
            local ok, value = pcall(fn, tbl, args[1])
            if ok then
                out(string_format("[LiveProbe]     live %s = %s", entry.name, tostring(value)))
            else
                out(string_format("[LiveProbe]     live %s: ERROR %s", entry.name, tostring(value)))
            end
        end
    end
end

function M.reader_report()
    _lines = {}
    out("[LiveProbe] 0.4 external readers -- what this build exposes to readers")
    local present, absent, absent_reads = 0, 0, 0
    for i = 1, #READER_TARGETS do
        local target = READER_TARGETS[i]
        local surface = lookup(target.root, target.name)
        if type(surface) == "table" then
            present = present + 1
            out(string_format("[LiveProbe] reader %s: PRESENT", target.label))
            describe_table(surface)
        else
            absent = absent + 1
            out(string_format("[LiveProbe] reader %s: ABSENT", target.label))
        end
        absent_reads = absent_reads + describe_reads(surface, target.reads)
        describe_live(surface, target.live or {})
    end
    for i = 1, #READER_MODULES do
        local module = READER_MODULES[i]
        local ok, loaded = pcall(require, module.path)
        if not ok or type(loaded) ~= "table" then
            absent = absent + 1
            out(string_format("[LiveProbe] reader %s: ABSENT (module did not load)", module.label))
        else
            present = present + 1
            out(string_format("[LiveProbe] reader %s: PRESENT", module.label))
            describe_table(loaded)
            absent_reads = absent_reads + describe_reads(loaded, module.reads)
        end
    end
    -- Discovery: the build's own key inventory is the source of truth for a
    -- surface whose name we were never told.
    local hits = 0
    local engine = _G["core"]
    if type(engine) == "table" then
        local keys = sorted_keys(engine)
        for i = 1, #keys do
            local name = tostring(keys[i])
            local lower = name:lower()
            local matched = false
            for n = 1, #READER_SCAN_NEEDLES do
                if lower:find(READER_SCAN_NEEDLES[n], 1, true) then
                    matched = true
                    break
                end
            end
            if matched then
                hits = hits + 1
                if hits <= READER_SCAN_LIMIT then
                    local value = engine[keys[i]]
                    local extra = ""
                    if type(value) == "table" then
                        local members = 0
                        for _ in pairs(value) do
                            members = members + 1
                        end
                        extra = string_format(" (%d member(s))", members)
                    end
                    out(string_format("[LiveProbe]     scan core.%s = %s%s", name, type(value), extra))
                end
            end
        end
        if hits > READER_SCAN_LIMIT then
            out(string_format("[LiveProbe]     ... %d more matching key(s)", hits - READER_SCAN_LIMIT))
        end
    else
        out("[LiveProbe]     scan: core is ABSENT -- no engine table to inventory")
    end
    out(string_format(
        "[LiveProbe] 0.4 summary: %d surface(s) present, %d absent, %d read(s) our lanes make missing, %d name-scan hit(s)",
        present, absent, absent_reads, hits))
    return {
        lines = _lines, present = present, absent = absent,
        absent_reads = absent_reads, scan_hits = hits,
    }
end

function M.action_readers()
    return M.reader_report()
end

-- ---------------------------------------------------------------------------
-- Menu-facing operations (single owner)
--
-- The engine has no console, so the only way a session runs a probe is a menu
-- action. Both menu implementations therefore own WIDGETS only and call these
-- operations; menu_buttons() is the one list they both iterate, so the legacy
-- tree and the declarative page cannot drift. Everything stays disarmed until
-- an action arms it, and no id is ever guessed: form ids resolve BY NAME from
-- the class spell map the spec files publish (NS.<Class>Spells).
-- ---------------------------------------------------------------------------
local FORM_ACTIONS = {
    Druid  = { "CatForm", "BearForm", "TravelForm" },
    Shaman = { "GhostWolf" },
}

local function class_spell_map()
    local name = lookup("ns", "player_class_name")
    if type(name) ~= "string" or name == "" then
        local plugin = _G["plugin_info"]
        if type(plugin) == "table" then name = plugin["player_class_name"] end
    end
    if type(name) ~= "string" or name == "" then return nil, nil end
    name = name:sub(1, 1):upper() .. name:sub(2):lower()
    local map = lookup("ns", name .. "Spells")
    if type(map) ~= "table" then return nil, name end
    return map, name
end

local function resolve_ids(map, action_name)
    local ids = {}
    if type(map) ~= "table" then return ids end
    local action = map[action_name]
    if type(action) ~= "table" then return ids end
    local meta = action["_meta"]
    local candidates = meta and (meta["ids"] or meta["id"]) or action["ids"]
    if type(candidates) == "number" then candidates = { candidates } end
    if type(candidates) ~= "table" then return ids end
    local seen = {}
    for i = 1, #candidates do
        local id = tonumber(candidates[i])
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    return ids
end

local function resolve_form_ids()
    local map, name = class_spell_map()
    local ids = {}
    local list = name and FORM_ACTIONS[name] or nil
    if type(list) == "table" then
        local seen = {}
        for i = 1, #list do
            local sub = resolve_ids(map, list[i])
            for j = 1, #sub do
                local id = sub[j]
                if not seen[id] then
                    seen[id] = true
                    ids[#ids + 1] = id
                end
            end
        end
    end
    return ids, name
end

local ARM_SCOPES = { all = true, forms = true, dots = true, rage = true }

-- action_arm(scope, raw_events): scope is what the capture records --
--   all   -> own aura changes + incoming damage (with the rage it produced)
--   forms -> own aura changes only, ids resolved from the class spell map
--   dots  -> own periodic-damage ticks (and the interval between them)
--   rage  -> incoming damage only (the rage-from-damage curve)
-- raw_events dumps the first CLEU event's args, which is how a session confirms
-- the layout this build sends instead of assuming one.
function M.action_arm(scope, raw_events)
    if type(scope) ~= "string" or not ARM_SCOPES[scope] then scope = "all" end
    local forms = {}
    if scope == "forms" then
        local class_name
        forms, class_name = resolve_form_ids()
        if #forms == 0 then
            out("[LiveProbe] arm(forms): no form id resolved for class "
                .. tostring(class_name or "unknown")
                .. " -- falling back to scope=all (every own aura)")
            scope = "all"
        end
    end
    return M.arm({ forms = forms, raw_events = raw_events, scope = scope })
end

function M.action_report()
    return M.report()
end

function M.action_sample(tag)
    return M.sample(tag or "menu")
end

function M.action_flush()
    return M.flush()
end

function M.action_disarm()
    return M.disarm()
end

local MENU_BUTTONS = {
    {
        id = "eax_probe_report", label = "Probe: Engine Report",
        description = "Log the expansion/version surface, race, capability matrix and aura points (Block 0.1-0.3)",
        run = function() M.action_report() end,
    },
    {
        id = "eax_probe_readers", label = "Probe: Reader Surfaces (0.4)",
        description = "Inventory the external-reader surfaces this build exposes: the built-in damage meter, the cooldown readers our lanes use, the engine CD modules, and a name scan of the engine table",
        run = function() M.action_readers() end,
    },
    {
        id = "eax_probe_integrity", label = "Probe: Engine Integrity (0.5)",
        description = "Show the client's integrity/error surface state (log sinks, engine tables, runtime generations, a live-read canary) and the arm -> flush comparison, so Block 0.5 is evidence from the log",
        run = function() M.action_integrity() end,
    },
    {
        id = "eax_probe_sample", label = "Probe: Snapshot Now",
        description = "Log one line of form/energy/rage/mana/hp/combo/AP/haste at this moment",
        run = function() M.action_sample("menu") end,
    },
    {
        id = "eax_probe_arm_all", label = "Probe: Arm Capture (all)",
        description = "Record own aura changes + incoming damage (with rage) + one raw CLEU event, then Flush",
        run = function() M.action_arm("all", 1) end,
    },
    {
        id = "eax_probe_arm_forms", label = "Probe: Arm Capture (forms)",
        description = "Record own form/buff changes with the energy snapshot -- shift form after arming, then Flush",
        run = function() M.action_arm("forms", 1) end,
    },
    {
        id = "eax_probe_arm_dots", label = "Probe: Arm Capture (ticks)",
        description = "Record own DoT ticks and their interval -- apply the DoT after arming, then Flush",
        run = function() M.action_arm("dots", 0) end,
    },
    {
        id = "eax_probe_arm_rage", label = "Probe: Arm Capture (rage)",
        description = "Record incoming damage with the rage it produced -- take the hit after arming, then Flush",
        run = function() M.action_arm("rage", 0) end,
    },
    {
        id = "eax_probe_flush", label = "Probe: Flush Capture",
        description = "Log the capture: every recorded event, plus the raw CLEU arg dump when armed with it",
        run = function() M.action_flush() end,
    },
    {
        id = "eax_probe_disarm", label = "Probe: Disarm Capture",
        description = "Stop recording; the capture stays readable until the next arm",
        run = function() M.action_disarm() end,
    },
}

-- menu_buttons(): the operation list both menu implementations iterate. One
-- owner means the two Diagnostics sections cannot drift apart, and the wiring
-- suite fails if either menu stops consuming it.
function M.menu_buttons()
    return MENU_BUTTONS
end

function M.get_last_report()
    return M._last_report, _lines
end

return M
