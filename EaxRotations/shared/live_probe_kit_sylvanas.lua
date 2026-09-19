-- live_probe_kit_sylvanas.lua — shared plumbing for the live-beta probe harness.
-- WHAT:  the guarded reads every probe shares: safe()/now()/player(), the
--        runtime name index (ROOTS + lookup) that probes engine members without
--        compile-time field reads, and the log sink (push_line/out) over one
--        reused line buffer (lines/reset_lines).
-- WHEN:  loaded by every live_probe_* part; never a probe entry point itself.
-- WHY:   report/sample/capture/readers/integrity all need the same reads and the
--        same output buffer; owning them once is what lets each probe file be
--        read on its own.
-- SAFETY: every engine read is pcall-guarded and nil means "this build does not
--        expose it"; output goes to NS.log only; no banned APIs.
local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end
local type = type
local pcall = pcall
local M = {}
local _lines = {}               -- log lines, reused by every producer


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


local function power_of(p, power_type)
    if not p then return nil end
    if type(p.get_power) ~= "function" then return nil end
    local v = safe(p.get_power, p, power_type)
    return tonumber(v)
end

local function push_line(text)
    _lines[#_lines + 1] = text
end

local function out(text)
    push_line(text)
    if NS.log then pcall(NS.log, text) end
end


-- Exported for the probe parts: each one destructures the members it calls,
-- so a reader of that file sees exactly what it depends on.
M.safe = safe
M.power_of = power_of
M.now = now
M.player = player
M.lookup = lookup
M.out = out
M.push_line = push_line

function M.lines()
    return _lines
end

function M.reset_lines()
    _lines = {}
end
return M
