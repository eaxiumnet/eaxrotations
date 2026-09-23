-- What: Tripwire — no production site starts a fight except through the one checkpoint.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why:  The pull gate used to be an ad-hoc step remembered at nine call sites, and the live
--       reports ("it still tries to engage mobs on low health/mana", "walks up instead of
--       standing at range") were exactly the sites that forgot it. shared/pull_safety.lua now
--       owns one checkpoint — M.engage(ctx, shared, enemy, opts): the gate's word first, and on
--       a pass the approach walk issued through the nav owner — and the fight lanes of
--       quest_state/do_action_state.lua ask it and nothing else. This suite is what keeps it
--       that way, in three layers:
--         E2  the gate itself is owner-internal: no production file calls pull_safety.gate.
--         E3  every fight-opener in the lane answers to a checkpoint ask, counted AND ordered —
--             an opener whose last hostile selection happened after the last ask is a violation.
--         E4  the checkpoint's own contract: a refusal returns nil and walks nowhere, a pass
--             carries the approach walk (and its stand-off) inside it.
--       Every layer has positive controls (a synthetic violator the layer must catch) and
--       negative controls (the intentional ask-without-consequences reads — would_refuse,
--       holding — and the lane's own nav_destination walks stay legal). Mirrors
--       tests/test_nav_destination_ownership.lua.
-- Safety: read-only source scans (io.open + lfs) and requires of the owner modules; no writes,
--       no execution of scanned code.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- The suite builds its own client surface (like tests/test_pull_safety.lua) and re-requires the
-- modules under test, so it is deterministic whether or not an earlier suite in the same runner
-- process already loaded them.
local _visible = {}
core = {
    time = function() return 1000 end,
    object_manager = { get_visible_objects = function() return _visible end },
    log = function() end,
    log_warning = function() end,
}
_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.set_warning = function() end

package.loaded["shared/pull_safety"] = nil
package.loaded["shared/nav_destination"] = nil
package.loaded["waypoint_fixer_sylvanas"] = {
    fix_z = function(pos) return { x = pos and pos.x or 0, y = pos and pos.y or 0, z = 4242.5 } end,
}

local pull_safety = require("shared/pull_safety")
local nav_destination = require("shared/nav_destination")

-- =============================================================================
-- Helpers — plugin root, production discovery, comment-stripping scan
-- =============================================================================

--- Locate the plugin root so this suite runs from the repo root or the plugin root.
local function plugin_root()
    for _, prefix in ipairs({ "EaxAutoQuester/", "" }) do
        local f = io.open(prefix .. "main.lua", "r")
        if f then
            f:close()
            return prefix
        end
    end
    return nil
end

local ROOT = plugin_root()
assert(ROOT, "FAIL: EaxAutoQuester root not found (expected main.lua in ./ or ./EaxAutoQuester/)")

local function read_source(rel)
    local f = io.open(ROOT .. rel, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

--- Every production Lua file: everything under the plugin root except the suites, the docs and
--- the throwaway `_`-prefixed probes.
local function list_production_files()
    local ok, lfs = pcall(require, "lfs")
    assert(ok and lfs and lfs.dir,
        "FAIL: lfs is required — a partial scan of production code must not be able to pass")

    local out = {}
    local function walk(dir)
        for entry in lfs.dir(dir) do
            if entry ~= "." and entry ~= ".." then
                local path = dir .. "/" .. entry
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    if entry ~= "tests" and entry ~= "docs" then walk(path) end
                elseif entry:match("%.lua$") and not entry:match("^_") then
                    out[#out + 1] = path:sub(#ROOT + 1)
                end
            end
        end
    end
    walk(ROOT:sub(1, #ROOT - 1))
    table.sort(out)
    return out
end

--- Blank out comments while preserving newlines, so a line number in the stripped source is
--- still a line number in the file. Prose about a bypass must not trip the scan.
--- @param src string
--- @return string
local function strip_comments(src)
    local out = {}
    local i, n = 1, #src
    while i <= n do
        if src:sub(i, i + 1) == "--" then
            local eq = src:match("^%-%-%[(=*)%[", i)
            if eq then
                local close = "]" .. eq .. "]"
                local start = i + 4 + #eq
                local e = src:find(close, start, true)
                e = e and (e + #close) or (n + 1)
                -- Keep the newlines the comment covered, so offsets after it stay aligned.
                for nl in src:sub(i, e - 1):gmatch("[\r\n]") do out[#out + 1] = nl end
                i = e
            else
                local e = src:find("[\r\n]", i) or (n + 1)
                i = e
            end
        else
            out[#out + 1] = src:sub(i, i)
            i = i + 1
        end
    end
    return table.concat(out)
end

--- Byte offsets of every occurrence of a Lua pattern, in order.
local function find_offsets(s, pat)
    local out = {}
    local at = s:find(pat)
    while at do
        out[#out + 1] = at
        at = s:find(pat, at + 1)
    end
    return out
end

--- 1-based line number of a byte offset in `s`.
local function line_at(s, at)
    local _, count = s:sub(1, at):gsub("\n", "\n")
    return count + 1
end

-- The two vocabularies the lane scan reasons about. The checkpoint ask is one pattern; the
-- openers are the calls that commit the bot to a fight, and the markers are the calls that
-- produce a hostile candidate. core.input.set_target is deliberately NOT an opener: it is also
-- how the plugin targets a quest object or a giver (the interact lane does exactly that), so it
-- cannot discriminate a fight. pull_at_range/start_auto_attack can.
local ASK_PAT = "pull_safety%.engage%("
local GATE_PAT = "pull_safety%.gate%("
local OPENERS = {
    { pat = "pull_at_range%(",   label = "pull_at_range" },
    { pat = "start_auto_attack", label = "start_auto_attack" },
}
local MARKERS = {
    { pat = "get_nearest_enemy%(" },
    { pat = "find_nearest_npc%(" },
    { pat = "find_nearest_quest_unit%(" },
}

--- Offset of the LAST occurrence of any of `pats` that starts before `limit`, or nil.
local function last_offset_before(s, pats, limit)
    local best = nil
    for _, p in ipairs(pats) do
        local at = s:find(p.pat)
        while at and at < limit do
            if not best or at > best then best = at end
            at = s:find(p.pat, at + 1)
        end
    end
    return best
end

--- The lane's violations: a fight-opener that answers to a hostile selection no checkpoint ask
--- covered. Occurrences above the file's first ask are skipped — the lane's own attack helper
--- (pull_at_range) is defined there, and it is the mechanism, not a site: its callers are what
--- this scan checks.
--- @param src string raw source
--- @return table[] violations (strings), number ask_count
local function lane_violations(src)
    local s = strip_comments(src)
    local asks = find_offsets(s, ASK_PAT)
    local first_ask = asks[1]
    local out = {}

    for _, call in ipairs(OPENERS) do
        for _, at in ipairs(find_offsets(s, call.pat)) do
            if not first_ask or at > first_ask then
                local sel = last_offset_before(s, MARKERS, at)
                local ask = last_offset_before(s, { { pat = ASK_PAT } }, at)
                if (not ask) or (sel and sel > ask) then
                    out[#out + 1] = "line " .. tostring(line_at(s, at)) .. " (" .. call.label .. ")"
                end
            end
        end
    end
    return out, #asks
end

--- Direct gate calls in a source string (comments stripped).
local function gate_calls(src)
    return #find_offsets(strip_comments(src), GATE_PAT)
end

local LANE = "quest_state/do_action_state.lua"
local OWNER = "shared/pull_safety.lua"

-- =============================================================================
-- E1 — the scanner itself: it catches real violations and ignores prose
-- =============================================================================

do
    local silent = "local e = npc.get_nearest_enemy(50, s)\nNS.start_auto_attack(e)\n"
    local v = lane_violations(silent)
    assert(#v == 1, "E1a FAIL: a swing with no ask at all must be a violation")

    local asked = "local e = npc.get_nearest_enemy(50, s)\n"
        .. "if not pull_safety.engage(ctx, shared, e) then return end\nNS.start_auto_attack(e)\n"
    assert(#(lane_violations(asked)) == 0, "E1b FAIL: ask-then-swing must be clean")

    local swapped = "if not pull_safety.engage(ctx, shared, a) then return end\n"
        .. "local e = npc.get_nearest_enemy(50, s)\nNS.start_auto_attack(e)\n"
    assert(#(lane_violations(swapped)) == 1,
        "E1c FAIL: asking about one mob and swinging at another must be a violation")

    -- The lane's own helper: its body sits above the first ask, and its callers are the sites.
    local helper = "local function pull_at_range(ctx, enemy, sq)\n"
        .. "  NS.start_auto_attack(enemy)\nend\n"
        .. "local e = npc.get_nearest_enemy(50, s)\n"
        .. "if not pull_safety.engage(ctx, shared, e) then return end\n"
        .. "pull_at_range(ctx, e, 784)\n"
    assert(#(lane_violations(helper)) == 0,
        "E1d FAIL: the lane's own attack helper must not read as a site")

    local prose = "-- NS.start_auto_attack(e) is behind the checkpoint now\nreturn 1\n"
    assert(#(lane_violations(prose)) == 0, "E1e FAIL: a comment must not trip the scan")

    print("  E1 PASS: scanner catches unasked/answered-for-the-wrong-mob swings, ignores prose")
end

-- =============================================================================
-- E2 — the gate is owner-internal: production asks the checkpoint, never the gate
-- =============================================================================

do
    -- Positive control: the same scanner on a source that does call the gate.
    assert(gate_calls("if pull_safety.gate(ctx, shared, e) then return end\n") == 1,
        "E2a FAIL: the gate scan cannot see a direct gate call")
    assert(gate_calls("-- pull_safety.gate(ctx, shared, e)\n") == 0,
        "E2b FAIL: a comment must not read as a gate call")

    -- Negative controls: the declared ask-without-consequences reads, and the nav owner's own
    -- producer, are not gate calls — a refusal there would park the bot for no reason.
    assert(gate_calls("pull_safety.would_refuse(ctx, nearest)") == 0, "E2c FAIL")
    assert(gate_calls("pull_safety.holding(ctx)") == 0, "E2d FAIL")
    assert(gate_calls("nav_destination.engage(shared, unit, pos, 784)") == 0, "E2e FAIL")

    local files = list_production_files()
    assert(#files >= 40,
        "E2f FAIL: the walk found only " .. tostring(#files) ..
        " production files — a scan this thin proves nothing")

    local offenders = {}
    local scanned = 0
    for _, rel in ipairs(files) do
        local src = read_source(rel)
        assert(src, "E2g FAIL: production file listed but unreadable: " .. rel)
        scanned = scanned + 1
        if rel ~= OWNER and gate_calls(src) > 0 then
            offenders[#offenders + 1] = rel
        end
    end
    assert(#offenders == 0,
        "E2h FAIL: pull_safety.gate is the owner-internal decision — production asks the "
        .. "checkpoint (pull_safety.engage) instead; found: " .. table.concat(offenders, ", "))

    -- Non-vacuous on real source: a gate call injected into a real production file is caught.
    local lane_src = read_source(LANE)
    assert(lane_src, "E2i FAIL: could not read " .. LANE)
    local poisoned = lane_src:gsub("local function pull_at_range",
        "local function poisoned() if pull_safety.gate(ctx, shared, e) then return end end\n"
        .. "local function pull_at_range", 1)
    assert(poisoned ~= lane_src, "E2j FAIL: the control could not inject a gate call")
    assert(gate_calls(poisoned) == 1,
        "E2k FAIL: the gate ban cannot see a gate call added to " .. LANE)

    -- And the declared readers really are still there, so this scan is guarding something live.
    local nav = read_source("quest_state/nav_state.lua")
    assert(nav and nav:find("pull_safety.would_refuse(", 1, true),
        "E2l FAIL: the en-route pre-tag no longer asks would_refuse — tagging a hostile while "
        .. "walking starts the fight mid-travel")
    local idle = read_source("quest_state/idle_state.lua")
    assert(idle and idle:find("pull_safety.holding(", 1, true),
        "E2m FAIL: IDLE no longer honours the hold — it would walk back to the mob the gate "
        .. "just refused")

    print("  E2 PASS: " .. tostring(scanned) .. " production files, zero direct gate calls")
end

-- =============================================================================
-- E3 — every fight-opener in the lane answers to a checkpoint ask
-- =============================================================================

do
    local src = read_source(LANE)
    assert(src and #src > 1000, "E3a FAIL: could not read " .. LANE .. " — the scan would be vacuous")

    local violations, asks = lane_violations(src)
    assert(#violations == 0,
        "E3b FAIL: " .. LANE .. " opens a fight without a fresh checkpoint ask: "
        .. table.concat(violations, ", "))

    -- Counted, not merely found: a walk-only site (one that asks and then walks to the mob) has
    -- no opener for the ordering rule above to reason about, so its ask going missing is only
    -- visible as a lower count. Nine sites ask today; a tenth lane must update this number and
    -- that is the point — the count is what makes a removed site fail here instead of in game.
    assert(asks == 9,
        "E3c FAIL: expected the 9 engage sites of the kill/area lanes to ask the checkpoint, "
        .. "found " .. tostring(asks) .. " — a fight nothing gates cannot be refused")
    local missing = src:gsub(ASK_PAT, "removed_by_control(", 1)
    assert(missing ~= src, "E3d FAIL: the control could not remove an ask")
    assert(select(2, lane_violations(missing)) == 8,
        "E3d FAIL: the count cannot detect a removed ask — the pin above proves nothing")

    -- Non-vacuous on real source: a naked opener appended to the lane is caught.
    local naked = src .. "\nlocal e2 = npc.get_nearest_enemy(50, s)\nNS.start_auto_attack(e2)\n"
    assert(#(lane_violations(naked)) == 1,
        "E3e FAIL: the ordering rule cannot see a candidate selected after the last ask")

    -- Negative control: the lane's own walks (nav_destination.engage) are not fights and stay as
    -- they are; what keeps them honest is that they sit inside already-asked regions.
    assert(#find_offsets(strip_comments(src), "nav_destination%.engage%(") >= 1,
        "E3f FAIL: the lane's own destination writing must keep going through the nav owner")

    print("  E3 PASS: all " .. tostring(asks) ..
        " fight sites ask the checkpoint, and no opener answers to a stale ask")
end

-- =============================================================================
-- E4 — the checkpoint's contract: the gate's word first, the approach walk inside it
-- =============================================================================

do
    --- A player the module can read: bars, position, combat state.
    local function player(o)
        o = o or {}
        return {
            get_position = function() return o.pos or { x = 0, y = 0, z = 0 } end,
            get_health = function() return o.hp end,
            get_max_health = function() return o.max_hp end,
            get_power = function() return o.mana end,
            get_max_power = function() return o.max_mana end,
            is_in_combat = function() return o.combat == true end,
            get_target = function() return o.target end,
            is_unit = function() return true end,
            is_dead = function() return false end,
            can_attack = function() return false end,
        }
    end

    --- A hostile at a fixed spot.
    local function mob_at(x, y)
        return {
            get_position = function() return { x = x, y = y, z = 0 } end,
            get_name = function() return "Checkpoint Mob" end,
            is_unit = function() return true end,
            is_dead = function() return false end,
            can_attack = function() return true end,
            is_in_combat = function() return false end,
            get_movement_speed = function() return 0 end,
        }
    end

    local function ctx_for(me, now)
        return {
            me = me,
            now = now,
            debug_log = function() end,
            utils = { squared_distance = function(a, b)
                local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
                return dx * dx + dy * dy
            end },
        }
    end

    -- 4a/4b: a refusal returns nil, walks nowhere, and says why — the hold is armed and the
    -- retreat the nav owner will apply is published as an intent.
    pull_safety.reset()
    local me = player({ hp = 100, max_hp = 100, mana = 10, max_mana = 1000 })
    local shared = {}
    local ctx = ctx_for(me, 1000)
    local far = mob_at(30, 0)
    assert(pull_safety.engage(ctx, shared, far, { approach_sq = 100 }) == nil,
        "E4a FAIL: a refused fight must return nil (the gate's word is final)")
    assert(shared._nav_destination == nil,
        "E4a FAIL: a refusal must not walk the bot — the approach comes after the ask, never "
        .. "instead of it")
    assert(pull_safety.holding(ctx) == true, "E4b FAIL: a refusal must arm the hold")
    assert(pull_safety.destination(ctx) ~= nil,
        "E4b FAIL: a refusal must publish the retreat intent for the nav owner to apply")
    assert(type(shared._pull_warned_at) == "string",
        "E4b FAIL: a refusal must say why it refused")

    -- 4c: a pass issues the approach walk inside the ask, stand-off and all — a caller cannot
    -- walk into a fight it did not ask about.
    pull_safety.reset()
    local healthy = player({ hp = 100, max_hp = 100, mana = 900, max_mana = 1000 })
    local shared2 = {}
    local eng = pull_safety.engage(ctx_for(healthy, 2000), shared2, far,
        { approach_sq = 100, stand_off_sq = 784 })
    assert(eng ~= nil, "E4c FAIL: a healthy engage must pass the checkpoint")
    assert(eng.out_of_range == true and eng.walked == true,
        "E4c FAIL: an out-of-range pass must issue the approach walk")
    assert(shared2._nav_destination ~= nil and shared2._nav_unit_dest == far,
        "E4c FAIL: the walk must go through the nav owner, linked to the unit it closes on")
    assert(shared2._nav_engage_sq == 784,
        "E4c FAIL: the stand-off must ride on the walk (stop at fight range, by construction)")

    -- 4d: in range the ask drives nothing — no destination, no stand-off.
    pull_safety.reset()
    local shared3 = {}
    local near = mob_at(4, 0)
    local eng2 = pull_safety.engage(ctx_for(healthy, 3000), shared3, near, { approach_sq = 100 })
    assert(eng2 ~= nil and eng2.out_of_range == false and eng2.walked == false,
        "E4d FAIL: an in-range pass must not walk")
    assert(shared3._nav_destination == nil and shared3._nav_engage_sq == nil,
        "E4d FAIL: an in-range pass must write no navigation field")
    assert(eng2.dist_sq == 16, "E4d FAIL: the ask must report the geometry it answered about")

    print("  E4 PASS: refusal drives nothing and announces itself; a pass carries its own walk")
end

print("PASS test_pull_checkpoint")
os.exit(0)
