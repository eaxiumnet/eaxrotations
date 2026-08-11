-- run_ns_member_audit_tests.lua -- Static audit: no `NS.<member>(...)` call may
-- target a member that is never defined on the NS namespace.
-- WHAT:  Scans every class and shared file for NS member CALLS
--        (`NS.<name>(` on the file's module-level binding) and flags any
--        whose <name> is (a) never assigned to NS anywhere in the repo
--        (`NS.<name> = ...` / `function NS.<name>(`), (b) absent from the
--        engine API surface (.api/ stubs incl. ---@field annotations,
--        apidocs/, scraped docs), and (c) not on the explicit ALLOWLIST
--        below. This is the mechanical guard for the two live-game crashes
--        this session already fixed by hand: incoming_heal_predictor's bare
--        `cleanup_caches` call (a global — the sibling bug class) and
--        los_guard's UNGUARDED `NS.same_unit(...)` member call (never
--        assigned anywhere; the survey's bare-call scanner missed exactly
--        this member form).
-- WHEN:  Run manually, in CI (verify_all), and in the pre-commit gate.
-- CI-PARITY: the engine census reads GITIGNORED local dirs (.api/,
--        apidocs/pages/, scraped_docs_md/dev/api/) that a clean CI
--        checkout does NOT contain — so in CI the engine surface is empty
--        and a name that resolves locally via those docs is flagged unless
--        it is also on the ALLOWLIST. Keep the allowlist as the portable
--        guarantee: any engine member the docs enumerate locally must ALSO
--        have an allowlist entry (mock= / guarded=, live-verified), or CI
--        diverges from the local run. See the third allowlist batch.
-- WHY:   A future spec copying an optional-engine-method call could drop the
--        guard (the los_guard shape) or reference a member that never
--        exists; this audit mechanically covers every file so it is caught
--        before it ships.
-- SAFETY: Read-only text scan + static classification; --self-test has no
--        filesystem writes (synthetic in-memory content only).
-- LIMITATIONS (accepted, documented): the guard detector's lookback is two
--        lines — a guard 3+ lines above a call (unusual, but possible with
--        intervening locals) is classified as unguarded, a FALSE POSITIVE
--        that blocks commits (the safe failure direction). The ` or` and
--        `if not ... then` nil-selection forms are NOT treated as guards
--        (the crash direction, not a guard) — the `not` early-return idiom
--        is still covered via the ` then` pattern.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;.api/?.lua;.api/?/?.lua;" .. package.path

local CLASS_ROOT = "EaxRotations/classes"
local SHARED_ROOT = "EaxRotations/shared"
local REPO_ROOT = "EaxRotations"
local MOCK_FILE = "EaxRotations/tests/behavioral_audit.lua"
local ENGINE_DIRS = { ".api", "apidocs/pages", "scraped_docs_md/dev/api" }

-- ============================================================================
-- ALLOWLIST — engine-provided NS members that api/ does not enumerate.
-- A name here is CALLED but never repo-assigned and absent from the engine
-- surface, yet legitimately optional. Two derivation sources (2026-08-10,
-- from the live call-site census + battery mock census):
--   mock=    the behavioral battery's build_ns defines `ns.<name>`, so the
--            name is part of the runtime NS surface the mock mirrors.
--   guarded= EVERY real call site uses the repo's optional-method pattern
--            (`NS.<name> and NS.<name>(...)` or an `if NS.<name> then` guard
--            on the same/previous lines). An UNGUARDED call to one of these
--            (the los_guard crash shape) FAILS the audit — see violations().
-- Keep minimal: add an entry ONLY with the file:line evidence below.
-- ============================================================================
local ALLOWLIST = {
    aoe_cone_meets        = "mock: battery ns.aoe_cone_meets (engine AoE helper)",
    can_cast_in_form      = "mock: battery ns.can_cast_in_form",
    cancel_current_cast   = "mock: battery ns.cancel_current_cast",
    get_spell_cd          = "mock: battery ns.get_spell_cd",
    start_attack          = "mock: battery ns.start_attack",
    stop_casting          = "mock: battery ns.stop_casting",
    unit_faction          = "mock: battery ns.unit_faction",
    unit_max_mana         = "mock: battery ns.unit_max_mana",
    SetDashboardConfig    = "guarded: tick_profiler_sylvanas:162",
    action_ready          = "guarded: fury_vanilla:161",
    gate_cooldown         = "guarded: destruction_vanilla:204",
    get_tactical_mastery_cap = "guarded: arms_sylvanas:262 + 4 more",
    has_cc                = "guarded: arena_priority_sylvanas:205/207",
    has_talent            = "guarded: combat_sylvanas:69",
    is_cooldown           = "guarded: combat_stats_sylvanas:114",
    should_burst          = "guarded: destruction_vanilla:205/206 block + :467",
    use_trinket           = "guarded: destruction_vanilla:476",
    unit_energy_pct       = "guarded: combat_vanilla:185",
    unit_is_tank          = "guarded: health_pred_helper_sylvanas:73",
    -- Second batch (2026-08-10, after the production-only census fix exposed
    -- them): battery-mock members — verified in behavioral_audit.lua build_ns.
    -- 2026-08-11 undefined-NS-member sweep: buff_stacks, unit_mana_pct,
    -- is_interruptible, unit_is_boss, is_tank_unit, is_threat_safe and
    -- is_valid_target were found to be GENUINELY undefined in live play
    -- (the "engine-provided" label was unsupported) and are now DEFINED in
    -- core_sylvanas — removed from the allowlist, resolved by the census.
    -- The four members below were probed the same way and KEPT pinned: every
    -- real call site resolves through a working context/unit-method chain
    -- checked BEFORE the member (engine writes context.combo_points at
    -- main_sylvanas.lua:858 and context.energy at :811), so the member is an
    -- unreached optional path, not a live break. rogue/leveling_vanilla.lua
    -- had the one bare-read variant (NS.combo_points or 0 — never audited
    -- because it is not a call) and was fixed 2026-08-11 to the context +
    -- unit-method chain.
    combo_points          = "optional: guarded chains (cat_sylvanas:365, cat_vanilla:169, leveling:107) all read context.combo_points (engine :858) first; leveling_vanilla bare read fixed 2026-08-11",
    energy                = "optional: guarded chains (cat_sylvanas:423, cat_vanilla:180, leveling:268) read context.energy (engine :811) + me:get_power(3) first; leveling_vanilla bare read fixed 2026-08-11",
    get_combo_points      = "optional: guarded chains (cat_sylvanas:371, cat_vanilla:170, leveling:111) read context.combo_points / me:get_power(4) first",
    unit_creature_type    = "optional: guarded by type() checks, discipline_sylvanas:81 with unit:get_creature_type() fallback right after (all 6 priest files)",
    -- 2026-08-11 bare-value-read rule sweep (leveling_vanilla class): every
    -- remaining value read below is a DOCUMENTED-BENIGN optional path — a
    -- guard-then-use presence check on an engine-mounted module/constant, or
    -- a nil-safe default chain. The two genuine finds of the sweep were
    -- FIXED instead (cat:127 get_item_count crash, protection:414 party
    -- members), so no live break hides behind these pins.
    SPELLS                = "optional: generic class-table fallback — `NS.<Class>Spells or NS.SPELLS or {}` in 6 leveling files; never assigned, default {} when absent (per-class tables are the real surface)",
    target_selector       = "optional: engine-mounted module (documented .api/common/utility/ts_override_helper.lua:154); cached at load, every consumer nil-guards (ts_helper_sylvanas:15)",
    izi                   = "optional: engine-mounted IZI SDK presence check — hunter BM/MM/SV `if not NS.izi or type(NS.izi.spell) ~= function` with NS.spell_ready fallback when absent",
    ConsumableManager     = "optional: engine-mounted module — guard + pcall method access (holy_sylvanas:614, discipline_sylvanas:959)",
    GetRaidMembers        = "optional: guarded engine member — multidot_engagement_filter:74 `if NS.GetRaidMembers then pcall(NS.GetRaidMembers)`",
    debuff_types          = "optional: guarded engine member — dispel_manager:165-166 `if NS.debuff_types then pcall(NS.debuff_types, unit)`",
    PLAYER_CLASS          = "optional: engine constant read inside `if NS and NS.PLAYER_CLASS then` (spell_validation_sylvanas:226)",
    -- Third batch (2026-08-10, CI parity fix): these four names resolve on
    -- the maintainer's machine ONLY via the gitignored engine-doc dirs
    -- (.api/, apidocs/pages/, scraped_docs_md/dev/api/ — absent in CI's
    -- clean checkout, so the engine census is empty there and CI flagged
    -- them as never-assigned). All four are legitimate engine members:
    --   mock=      battery build_ns defines ns.<name> (live stale-check
    --              against behavioral_audit.lua pins it).
    --   guarded=   every real call site uses the optional-method guard
    --              (live unguarded-site check, los_guard shape).
    get_local_player      = "mock: battery ns.get_local_player (engine core.object_manager.get_local_player)",
    power_pct             = "mock: battery ns.power_pct",
    is_casting            = "guarded: arena_priority_sylvanas:85-86 + pvp_burst_window_sylvanas:78-79 (`if NS and NS.is_casting then`)",
    get_spell_name        = "guarded: combat_stats_sylvanas:115 (NS.get_spell_name and NS.get_spell_name(...))",
}

-- ============================================================================
-- Comment stripping (same convention as the dead-matcher audit): replace
-- comment text with same-length spaces so line positions survive. Handles
-- line comments and block comments at any level. Pragmatic: a `--` inside a
-- string literal is treated as a comment opener — false negatives only.
-- ============================================================================
local function strip_comments(content)
    local pieces = {}
    local pos = 1
    local len = #content
    while pos <= len do
        local s = content:find("%-%-", pos)
        if not s then
            pieces[#pieces + 1] = content:sub(pos)
            break
        end
        pieces[#pieces + 1] = content:sub(pos, s - 1)
        local eq = content:match("^%-%-%[(=*)%[", s)
        if eq then
            local close = content:find("%]" .. eq .. "%]", s + 3 + #eq)
            if close then
                pieces[#pieces + 1] = content:sub(s, close + #eq + 1):gsub(".", " ")
                pos = close + #eq + 2
            else
                pieces[#pieces + 1] = content:sub(s):gsub(".", " ")
                pos = len + 1
            end
        else
            local nl = content:find("\n", s + 2)
            if nl then
                pieces[#pieces + 1] = content:sub(s, nl - 1):gsub(".", " ")
                pos = nl
            else
                pieces[#pieces + 1] = content:sub(s):gsub(".", " ")
                pos = len + 1
            end
        end
    end
    return table.concat(pieces)
end

-- ============================================================================
-- String stripping: blank double/single-quoted literals with same-length
-- spaces so `"NS.foo()"` inside a string never counts as a call. Escaped
-- quotes handled. Pragmatic imbalance blanks to EOF (false negatives only).
-- ============================================================================
local function strip_strings(content)
    local pieces = {}
    local pos = 1
    local len = #content
    while pos <= len do
        local dq = content:find('"', pos)
        local sq = content:find("'", pos)
        local s, quote
        if dq and (not sq or dq < sq) then
            s, quote = dq, '"'
        elseif sq then
            s, quote = sq, "'"
        end
        if not s then
            pieces[#pieces + 1] = content:sub(pos)
            break
        end
        pieces[#pieces + 1] = content:sub(pos, s - 1)
        local j = s + 1
        while j <= len do
            local c = content:sub(j, j)
            if c == "\\" then
                j = j + 2
            elseif c == quote then
                break
            else
                j = j + 1
            end
        end
        local e = math.min(j, len + 1)
        pieces[#pieces + 1] = content:sub(s, e - 1):gsub(".", " ")
        pos = e + 1
    end
    return table.concat(pieces)
end

local function strip_comments_and_strings(content)
    return strip_strings(strip_comments(content))
end

-- ============================================================================
-- Version-stable line split (same convention as the cache-hit audit).
-- ============================================================================
local function split_lines(stripped)
    local lines = {}
    if stripped:sub(-1) == "\n" then stripped = stripped:sub(1, -2) end
    for line in (stripped .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line:gsub("\r$", "")
    end
    return lines
end

-- ============================================================================
-- Per-file module-level NS binding. Convention: `local NS = _G.EaxRotations`.
-- A handful of shared modules take lowercase `ns` as a FUNCTION PARAMETER
-- (aoe_hit_volume M.install(ns), offensive_dispel M.find_best_dispel_target
-- (unit, ns)) — those param uses are NOT the namespace and must not count as
-- calls or assignments. We honor only the token bound at module level to
-- `_G.EaxRotations` / `NS`, falling back to "NS" (the repo-wide convention).
-- ============================================================================
local function detect_binding(content)
    -- The RHS must be a BARE `_G.EaxRotations` / `NS` token ENDING the line
    -- (or followed only by a comment). `local is_valid = NS.has_pet()`,
    -- `local _core = NS and NS.core`, `local X = NS or {}` must NOT bind —
    -- they alias a member or expression, not the namespace table.
    -- Scan each line; the binding line is `local <tok> = <rhs>` where rhs is
    -- exactly `_G.EaxRotations` / `_G.EaxRotations or {}` / `NS` (optionally
    -- followed by a comment). `NS.` / `NS and` / `NS or <member>` / `NS(...)`
    -- RHS values all fail: they alias a member or expression, not the
    -- namespace table (enhancement:75 `local _core = NS and NS.core` must not
    -- hijack the binding). The `or {}` form is core_sylvanas's canonical
    -- module-level binding (`local NS = _G.EaxRotations or {}`).
    local function is_binding_rhs(rhs)
        local stripped = rhs:gsub("^%s*(.-)%s*$", "%1")
        -- NOTE: `NS or {}` is deliberately NOT accepted. It would let
        -- `local foo = NS or {}` (an alias with fallback) hijack the
        -- binding and silently skip every real `NS.` call in the file. The
        -- canonical module binding (`local NS = _G.EaxRotations or {},
        -- core_sylvanas:19) is matched by the `_G.EaxRotations or {}` form,
        -- and a re-binding `local NS = NS or {}` still resolves correctly
        -- via the bare `NS` branch / the default fallback.
        if stripped == "_G.EaxRotations" or stripped == "_G.EaxRotations or {}"
            or stripped == "NS" then
            return true
        end
        -- trailing comment: strip it and re-check
        local comment = stripped:find("%-%-", 1, true)
        if comment then
            local head = stripped:sub(1, comment - 1):gsub("^%s*(.-)%s*$", "%1")
            return head == "_G.EaxRotations" or head == "_G.EaxRotations or {}"
                or head == "NS"
        end
        return false
    end
    for line in (content .. "\n"):gmatch("(.-)\n") do
        local line2 = line:gsub("\r$", "")
        local tok, rhs = line2:match("^%s*local%s+([A-Za-z_][A-Za-z0-9_]*)%s*=%s*(.-)%s*$")
        if tok and rhs and is_binding_rhs(rhs) then
            return tok
        end
    end
    return "NS"
end

local function esc_token(tok)
    return tok:gsub("([^%w])", "%%%1")
end

-- ============================================================================
-- Core scan: content -> { calls = { name -> { {line, text} } }, binding }
-- A call is `TOKEN.<name>(` where TOKEN is the file's module-level binding.
-- ============================================================================
local function scan_content(content)
    if type(content) ~= "string" then
        return { error = "content must be a string", calls = {}, binding = "NS" }
    end
    local stripped = strip_comments_and_strings(content)
    local lines = split_lines(stripped)
    local binding = detect_binding(content)
    local esc = esc_token(binding)
    local calls = {}
    for i = 1, #lines do
        local line = lines[i]
        for name in line:gmatch(esc .. "%s*%.%s*([A-Za-z_][A-Za-z0-9_]*)%s*%(") do
            calls[name] = calls[name] or {}
            calls[name][#calls[name] + 1] = { line = i, text = line }
        end
    end
    -- Bare value reads (2026-08-11 rule): `TOKEN.<name>` tokens that are
    -- NOT a call / assignment / method-access / index and NOT a guard-position
    -- presence check. The value of an undefined member consumed as data is
    -- the leveling_vanilla crash/degrade class (`state.x = NS.undef or 0`,
    -- `pcall(NS.undef, ...)` — pcall(nil) ERRORS); a guard-position token
    -- (`NS.x and NS.x(`, `if NS.x then`, `type(NS.x) == "function"`) is a
    -- nil-safe presence check and is excluded here by construction.
    local value_reads = {}
    for i = 1, #lines do
        local line = lines[i]
        for pos, name, after in line:gmatch("()" .. esc .. "%s*%.([A-Za-z_][A-Za-z0-9_]*)()") do
            local prev = line:sub(pos - 1, pos - 1)
            if prev == "" or not prev:match("[%w_]") then
                local nxt = line:sub(after, after)
                if nxt ~= "(" and nxt ~= "=" and nxt ~= "." and nxt ~= "[" then
                    local rest = line:sub(after)
                    local is_guard = rest:match("^%s+and") or rest:match("^%s+then")
                        or rest:match("^%s*%)%s*[~=]%s*=")
                    if not is_guard then
                        value_reads[name] = value_reads[name] or {}
                        value_reads[name][#value_reads[name] + 1] = { line = i, text = line }
                    end
                end
            end
        end
    end
    return { calls = calls, value_reads = value_reads, binding = binding, lines = lines }
end

-- ============================================================================
-- File scan: relative path under classes/ or shared/ -> skipped flag or result
-- ============================================================================
local function scan_file(root, rel_path)
    local f = io.open(root .. "/" .. rel_path, "rb")
    if not f then return { skipped = true } end
    local content = f:read("*a")
    f:close()
    local res = scan_content(content)
    res.file = rel_path
    return res
end

-- ============================================================================
-- Repo-wide NS member ASSIGNMENT census: `TOKEN.<name> =` and
-- `function TOKEN.<name>(` where TOKEN is the per-file module binding.
-- Also censuses the battery mock's `ns.<name> =` surface (the mock mirrors
-- the real runtime NS surface — the mock= allowlist source).
-- ============================================================================
local function collect_assignments()
    local assigned = {}
    local mock = {}
    local function walk(root, into)
        local pipe = io.popen("find " .. root .. " -name '*.lua'")
        for line in pipe:lines() do
            local p = line:gsub("\\", "/")
            -- Production assignment census only: test files stub their own mock
            -- NS members (perf_benchmark_hotpath assigns NS.get_setting etc.)
            -- which must not resolve a PRODUCTION member as "repo-assigned".
            if not (p:find("/tests/") or p:find("/tools/")) then
                local f = io.open(p, "rb")
                if f then
                    local content = f:read("*a")
                    f:close()
                    local stripped = strip_comments_and_strings(content)
                    local binding = detect_binding(content)
                    local esc = esc_token(binding)
                    -- 1) `<binding>.<name> =` (the module's own binding token).
                    for name in stripped:gmatch(esc .. "%s*%.%s*([A-Za-z_][A-Za-z0-9_]*)%s*=") do
                        into[name] = true
                    end
                    for name in stripped:gmatch("function%s+" .. esc .. "%s*%.%s*([A-Za-z_][A-Za-z0-9_]*)%s*%(") do
                        into[name] = true
                    end
                    -- 1b) Multi-assignment LHS: `NS.a, NS.b = x, y` — only the
                    -- LAST name is followed by `=`. Capture every NS.<name> in
                    -- the LHS segment of a line whose LHS contains an NS
                    -- comma-list and a whitespace-prefixed `=` (a `~=` compare
                    -- is excluded by the `%s+=` requirement — paladin
                    -- class_sylvanas:497 HL_COEFFICIENT shape).
                    for line in stripped:gmatch("[^\n]+") do
                        local eq = line:find("%s+=[^=]")
                        if eq and line:sub(1, eq):find(esc .. "%s*%.%s*[A-Za-z_][A-Za-z0-9_]*%s*,") then
                            local lhs = line:sub(1, eq)
                            for name in lhs:gmatch(esc .. "%s*%.%s*([A-Za-z_][A-Za-z0-9_]*)%s*,?%s*") do
                                into[name] = true
                            end
                        end
                    end
                    -- 2) `_G.EaxRotations.<name> =` direct writes (the
                    --    write-back modules: execute_phase, dot_refresh,
                    --    auto_tremor, combat_forecast_gate).
                    for name in stripped:gmatch("_?G%.EaxRotations%s*%.%s*([A-Za-z_][A-Za-z0-9_]*)%s*=") do
                        into[name] = true
                    end
                    -- 3) `ns.<name> =` inside `function M.install(ns)` with
                    --    `ns = ns or NS` (aoe_hit_volume install form — the
                    --    lowercase ns param aliases the real NS there).
                    --    Only honored when the file ALSO uses `ns = ns or NS`
                    --    so a pure param named ns (offensive_dispel) is not
                    --    misread. Offensive_dispel's `ns.buff_up(unit)` is a
                    --    CALL, not an assignment, so `ns.<name> =` only ever
                    --    matches assignments in the install form anyway.
                    if stripped:find("ns%s*=%s*ns%s+or%s+NS", 1) then
                        for name in stripped:gmatch("ns%s*%.%s*([A-Za-z_][A-Za-z0-9_]*)%s*=") do
                            into[name] = true
                        end
                    end
                end
            end
        end
        pipe:close()
    end
    walk(REPO_ROOT, assigned)
    -- Battery mock: behavioral_audit.lua's build_ns assigns `ns.<name> =`.
    local mf = io.open(MOCK_FILE, "rb")
    if mf then
        local content = mf:read("*a")
        mf:close()
        local stripped = strip_comments_and_strings(content)
        for name in stripped:gmatch("ns%s*%.%s*([A-Za-z_][A-Za-z0-9_]*)%s*=") do
            mock[name] = true
        end
    end
    return assigned, mock
end

-- ============================================================================
-- Engine API surface census: function names + `---@field <name> fun` type
-- annotations from .api/ stubs, apidocs/, and scraped docs.
-- NOTE: @field annotations are COMMENTS — read them from the RAW content
-- before comment/string stripping, or the census misses them (is_casting /
-- start_attack are @field-enumerated engine members). The find command uses
-- the simple `-name a -o -name b` form (the parenthesized form breaks on
-- Windows bash with "The system cannot find the path specified").
-- ============================================================================
local function collect_engine()
    local engine = {}
    for _, dir in ipairs(ENGINE_DIRS) do
        -- NOTE: no `2>/dev/null` — Windows cmd's io.popen mangles the redirect
        -- ("The system cannot find the path specified") and the census comes
        -- back EMPTY, silently flagging every @field member as unresolved.
        local pipe = io.popen("find " .. dir .. " -name '*.lua' -o -name '*.md'")
        for line in pipe:lines() do
            local f = io.open(line, "rb")
            if f then
                local content = f:read("*a")
                f:close()
                -- @field annotations: raw (they are comments).
                for name in content:gmatch("%-%-%-@field%s+([A-Za-z_][A-Za-z0-9_]*)%s+fun") do
                    engine[name] = true
                end
                -- function names + backtick docs: comment/string-stripped.
                -- Multi-segment paths (`function core.object_manager.get_local_\n                -- player(`) capture the LAST segment — the member name.
                local stripped = strip_comments_and_strings(content)
                for name in stripped:gmatch("function%s+[%w_%.]-%.([A-Za-z_][A-Za-z0-9_]*)%s*%(") do
                    engine[name] = true
                end
                for name in stripped:gmatch("function%s+([A-Za-z_][A-Za-z0-9_]*)%s*%(") do
                    engine[name] = true
                end
                for name in stripped:gmatch("`([A-Za-z_][A-Za-z0-9_]*)%s*%(") do
                    engine[name] = true
                end
            end
        end
        pipe:close()
    end
    return engine
end

-- ============================================================================
-- Guard detection: a call site is GUARDED if the call line or the two
-- preceding lines show the optional-method truthiness check (`NS.<name> and`,
-- `if [not] NS.<name>`, `if X and NS.<name>`, `if NS and NS.<name>`).
-- ============================================================================
local function is_guarded_site(lines, call_line, esc, name)
    local start = math.max(1, call_line - 2)
    local fin = math.min(#lines, call_line)
    for i = start, fin do
        local l = lines[i]
        local pat = esc .. "%s*%.%s*" .. name
        -- Guard forms are spell out explicitly (Lua patterns have no (not)?
        -- grouping — `not?` would mean "no" + optional "t"). Each pattern
        -- requires `then`/`and` directly after the member token so a bare
        -- call `if NS.name(...)` on the same line is NOT misread as a guard.
        -- A guard means the member token is used as a VALUE: directly
        -- followed by ` and` / ` then` (truthiness-check position). A token
        -- followed by `(` is a CALL — an unguarded call in a condition
        -- (`if X and NS.x(...)`, the los_guard shape) must NOT be misread as
        -- a guard, so the trailing keyword is required. ` or` is deliberately
        -- NOT a guard: `local t = NS.x or NS.x(...)` selects the call when
        -- the member is nil — the crash direction, not a guard. The `not`
        -- form is covered by the ` then` pattern (`if not NS.x then` contains
        -- `NS.x then`), which is correct for the repo's early-return idiom
        -- (`if not NS.can_cast_in_form then return true end`).
        if l:find(pat .. "%s+and", 1)                        -- NS.x and NS.x(  /  if NS.x and
            or l:find(pat .. "%s+then", 1)                   -- if NS.x then  /  if X and NS.x then
            or l:find("type%s*%(%s*" .. pat .. "%s*%)%s*[~=]%s*=", 1) then
            -- type(NS.x) == / ~= — the optional-method guard the six priest
            -- creature-type readers use (discipline_sylvanas:81): the member
            -- is only called inside the type==function branch. Works on the
            -- comment/string-stripped lines (the "function" literal is
            -- blanked, so only the type(...)== comparison shape survives);
            -- the type( wrapper is required so a bare value comparison is
            -- not misread as a guard (2026-08-11 refinement).
            return true
        end
    end
    return false
end

-- ============================================================================
-- Full scan: every .lua under classes/ + shared/
-- ============================================================================
local function run_scan()
    local assigned, mock = collect_assignments()
    local engine = collect_engine()

    local files = {}
    for _, root in ipairs({ CLASS_ROOT, SHARED_ROOT }) do
        local pipe = io.popen("find " .. root .. " -name '*.lua'")
        for line in pipe:lines() do
            local rel = line:gsub("^" .. root .. "/", ""):gsub("\\", "/")
            files[#files + 1] = { root = root, rel = rel }
        end
        pipe:close()
    end
    table.sort(files, function(a, b) return a.rel < b.rel end)

    local results = {}
    local total_files = 0
    local total_calls = 0
    for _, entry in ipairs(files) do
        local res = scan_file(entry.root, entry.rel)
        res.root = entry.root
        results[#results + 1] = res
        local n = 0
        for _, sites in pairs(res.calls) do n = n + #sites end
        if n > 0 then
            total_files = total_files + 1
            total_calls = total_calls + n
        end
    end
    return {
        results = results, assigned = assigned, mock = mock, engine = engine,
        total_files = total_files, total_calls = total_calls,
    }
end

-- ============================================================================
-- Violations: a called name is invalid iff NOT repo-assigned AND NOT engine
-- surface AND NOT on the ALLOWLIST. Allowlist entries are verified live:
--   guarded= names FAIL if any real call site is unguarded (the los_guard
--            crash shape — the guard must be present at EVERY site);
--   mock=    names FAIL if the battery no longer defines them (stale pin).
-- ============================================================================
local function violations(scan)
    local v = {}
    for _, res in ipairs(scan.results) do
        if not res.skipped then
            local esc = esc_token(res.binding)
            local fname = res.file or res.rel
            for name, sites in pairs(res.calls) do
                local why = ALLOWLIST[name]
                if scan.assigned[name] or scan.engine[name] then
                    -- resolved (repo-assigned or engine surface)
                elseif why then
                    if why:find("^mock") then
                        if not scan.mock[name] then
                            v[#v + 1] = { file = fname, line = sites[1].line,
                                name = name, text = sites[1].text,
                                why = "allowlist[mock] stale: battery ns." .. name .. " no longer defined" }
                        end
                    else -- guarded=
                        for _, s in ipairs(sites) do
                            if not is_guarded_site(res.lines, s.line, esc, name) then
                                v[#v + 1] = { file = fname, line = s.line,
                                    name = name, text = s.text,
                                    why = "allowlist[guarded]: call site is UNGUARDED (los_guard crash shape)" }
                            end
                        end
                    end
                else
                    for _, s in ipairs(sites) do
                        v[#v + 1] = { file = fname, line = s.line, name = name,
                            text = s.text, why = "never assigned / not engine / not allowlisted" }
                    end
                end
            end
        -- 2026-08-11 rule: bare VALUE reads of members that are never
        -- assigned / not engine / not allowlisted — the leveling_vanilla
        -- `state.x = NS.combo_points or 0` class (and pcall(NS.undef, ...),
        -- which ERRORS on a nil reference). Guard-position presence checks
        -- are excluded at collection time (nil-safe by construction);
        -- allowlisted optional paths resolve above.
        for name, sites in pairs(res.value_reads or {}) do
            if not (scan.assigned[name] or scan.engine[name] or ALLOWLIST[name]) then
                for _, s in ipairs(sites) do
                    v[#v + 1] = { file = fname, line = s.line, name = name, text = s.text,
                        why = "bare value read of never-assigned member (leveling_vanilla shape)" }
                end
            end
        end
        end
    end
    table.sort(v, function(a, b)
        if a.file ~= b.file then return a.file < b.file end
        if a.line ~= b.line then return a.line < b.line end
        return a.name < b.name
    end)
    return v
end

-- ============================================================================
-- Self-tests (non-vacuity): every resolver rule fires correctly. Synthetic
-- in-memory fixtures only.
-- ============================================================================
local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end

    expect(scan_content(nil).error, "content must be a string", "malformed nil content")
    expect(scan_content(123).error, "content must be a string", "malformed numeric content")
    expect(scan_file(CLASS_ROOT, "__missing_ns_fixture__.lua").skipped, true, "missing fixture")

    local function call_names(content)
        local names = {}
        for name in pairs(scan_content(content).calls) do
            names[#names + 1] = name
        end
        table.sort(names)
        return names
    end

    -- Style 1: repo binding `local NS = _G.EaxRotations` + member call.
    local bound = call_names(
        "local NS = _G.EaxRotations\n"
        .. "if NS.GetPlayer() then return true end\n")
    expect(#bound, 1, "bound NS call found")
    expect(bound[1], "GetPlayer", "bound NS member name")

    -- Style 2: lowercase `ns` as a FUNCTION PARAM must NOT count as the
    -- namespace (aoe_hit_volume M.install(ns) shape) — binding is `NS`.
    local param_ns = call_names(
        "local NS = _G.EaxRotations\n"
        .. "function M.install(ns)\n"
        .. "    ns.AOE_RADIUS = M.AOE_RADIUS\n"
        .. "    if ns.buff_up(unit) then return true end\n"
        .. "end\n")
    expect(#param_ns, 0, "lowercase param ns is not the namespace")

    -- Style 3: call inside a string literal must NOT count.
    local str_call = call_names(
        "local NS = _G.EaxRotations\n"
        .. "local msg = \"NS.GetPlayer() not a real call\"\n"
        .. "if NS.GetPlayer() then return true end\n")
    expect(#str_call, 1, "string-embedded NS call ignored")
    expect(str_call[1], "GetPlayer", "only the real call survives string strip")

    -- Style 4: call inside a line comment must NOT count.
    local cmt_call = call_names(
        "local NS = _G.EaxRotations\n"
        .. "-- NS.GetPlayer() is documented here\n"
        .. "if NS.GetPlayer() then return true end\n")
    expect(#cmt_call, 1, "comment-embedded NS call ignored")

    -- Style 5: call inside a block comment must NOT count.
    local block_cmt = call_names(
        "local NS = _G.EaxRotations\n"
        .. "--[[ NS.same_unit() was the crash ]]--\n")
    expect(#block_cmt, 0, "block-comment NS call ignored")

    -- Style 6: whitespace before the paren is a call.
    local spaced = call_names("local NS = _G.EaxRotations\nif NS.is_casting (unit) then end\n")
    expect(#spaced, 1, "whitespace-before-paren is a call")
    expect(spaced[1], "is_casting", "spaced call member name")

    -- Style 7: guard detection — inline `if NS.name and` is guarded; a bare
    -- `NS.name(...)` call is NOT (the los_guard crash shape).
    local inline_guard = is_guarded_site(
        { "if NS.action_ready then return NS.action_ready(context, action) or false end" },
        1, "NS", "action_ready")
    expect(inline_guard, true, "inline guard detected")

    local block_guard = is_guarded_site(
        { "if NS.should_burst and context.settings then",
          "    if not NS.should_burst(context) then return false end" },
        2, "NS", "should_burst")
    expect(block_guard, true, "block guard detected (guard on line above)")

    local bare = is_guarded_site({ "if NS.same_unit(caster, target) then return true end" }, 1, "NS", "same_unit")
    expect(bare, false, "bare call is NOT guarded (the los_guard crash shape)")

    -- Style 7b: an UNGUARDED call inside a condition (`if X and NS.x(...)`)
    -- must NOT be misread as a guard — the trailing-keyword requirement.
    local cond_call = is_guarded_site(
        { "if context.target and NS.should_burst(context) then return false end" },
        1, "NS", "should_burst")
    expect(cond_call, false, "unguarded call in condition is NOT a guard")

    -- Style 7c: `if NS and NS.x then` is a guard (has_cc arena_priority shape).
    local ns_and_guard = is_guarded_site(
        { "if NS and NS.has_cc then" }, 1, "NS", "has_cc")
    expect(ns_and_guard, true, "`if NS and NS.x then` is a guard")

    -- Style 2b: `local _core = NS and NS.core` must NOT bind `_core` — the
    -- file's real `NS.` calls must still be scanned (enhancement:75 shape).
    local alias_binding = scan_content(
        "local NS = _G.EaxRotations\n"
        .. "local _core = NS and NS.core\n"
        .. "if NS.GetPlayer() then return true end\n")
    expect(alias_binding.binding, "NS", "NS-and alias does not hijack the binding")
    expect(alias_binding.calls.GetPlayer ~= nil, true, "NS calls still scanned after alias")

    -- Style 8: violations() gating. same_unit is never-assigned/non-engine/
    -- non-allowlisted -> violation. GetPlayer is repo-assigned -> clean.
    -- is_casting is engine -> clean. has_cc is allowlisted[guarded] and its
    -- real site is guarded -> clean; an unguarded has_cc site -> violation.
    local scan = {
        assigned = { GetPlayer = true },
        engine = { is_casting = true },
        mock = { aoe_cone_meets = true },
        results = {
            { rel = "a.lua", binding = "NS", skipped = nil, lines = {
                "if NS.GetPlayer() then return true end",
                "if NS.is_casting(u) then return true end",
                "if NS.same_unit(c, t) then return true end",
                "if NS and NS.has_cc then",
                "    if NS.has_cc(unit) then return true end",
            }, calls = {
                GetPlayer = { { line = 1, text = "NS.GetPlayer()" } },
                is_casting = { { line = 2, text = "NS.is_casting(u)" } },
                same_unit = { { line = 3, text = "NS.same_unit(c, t)" } },
                has_cc = { { line = 5, text = "NS.has_cc(unit)" } },
            } },
        },
    }
    local v = violations(scan)
    expect(#v, 1, "exactly one violation in synthetic scan")
    expect(v[1].name, "same_unit", "violating member name")

    -- Style 9: an UNGUARDED call to an allowlisted[guarded] name fails
    -- (proving the allowlist is enforced, not blind).
    local scan2 = {
        assigned = {}, engine = {}, mock = {},
        results = {
            { rel = "b.lua", binding = "NS", skipped = nil, lines = {
                "if NS.should_burst(context) then return true end",
            }, calls = {
                should_burst = { { line = 1, text = "NS.should_burst(context)" } },
            } },
        },
    }
    local v2 = violations(scan2)
    expect(#v2, 1, "unguarded allowlisted call fails")

    -- Style 10: a mock= allowlist entry whose name vanished from the battery
    -- is a stale pin and fails.
    local scan3 = {
        assigned = {}, engine = {}, mock = {},
        results = {
            { rel = "c.lua", binding = "NS", skipped = nil, lines = {
                "if NS.aoe_cone_meets(2, r) then return true end",
            }, calls = {
                aoe_cone_meets = { { line = 1, text = "NS.aoe_cone_meets(2, r)" } },
            } },
        },
    }
    local v3 = violations(scan3)
    expect(#v3, 1, "stale mock allowlist pin fails")

    -- Style 11: bare VALUE reads (2026-08-11 rule) — the leveling_vanilla
    -- `state.x = NS.undef or 0` shape flags; guard-position presence checks
    -- and type()-guards are NOT value reads (collection-level exclusion);
    -- pcall(NS.undef, ...) IS a value read (a nil reference ERRORS in
    -- pcall); allowlisted members (SPELLS shape) are collected but resolve.
    local value_scan = {
        assigned = {}, engine = {}, mock = {},
        results = {
            { rel = "d.lua", binding = "NS", skipped = nil, lines = {
                "state.combo_points = NS.never_defined_member or 0",
            }, calls = {}, value_reads = {
                never_defined_member = {
                    { line = 1, text = "state.combo_points = NS.never_defined_member or 0" },
                },
            } },
        },
    }
    local vv = violations(value_scan)
    expect(#vv, 1, "bare value read of undefined member flags once")
    expect(vv[1].name, "never_defined_member", "flagged member name")
    expect(vv[1].why:find("bare value read") ~= nil, true, "violation reason names the rule")

    local guard_reads = scan_content(
        "local NS = _G.EaxRotations\n"
        .. "if NS.opt_module and NS.opt_module.method() then return true end\n"
        .. "if type(NS.opt_fn) == \"function\" then return NS.opt_fn() end\n")
    expect(guard_reads.value_reads.opt_module == nil, true, "guard-position token is not a value read")
    expect(guard_reads.value_reads.opt_fn == nil, true, "type()-guard token is not a value read")

    local pcall_read = scan_content(
        "local NS = _G.EaxRotations\n"
        .. "local ok, count = pcall(NS.never_defined_fn, id)\n")
    expect(pcall_read.value_reads.never_defined_fn ~= nil, true, "pcall function reference is a value read")

    local allow_reads = scan_content(
        "local NS = _G.EaxRotations\n"
        .. "local SPELLS = NS.RogueSpells or NS.SPELLS or {}\n")
    expect(allow_reads.value_reads.SPELLS ~= nil, true, "allowlisted member value read is still collected")

    -- Style 12: type()-guard recognition pin (2026-08-11 refinement) — the
    -- optional-method guard shape the six priest creature-type readers use
    -- (discipline_sylvanas:81), recognized on comment/string-stripped lines.
    local type_guard = is_guarded_site(
        { "if type(NS.unit_creature_type) == \"function\" then return NS.unit_creature_type(unit) end" },
        1, "NS", "unit_creature_type")
    expect(type_guard, true, "type(NS.x) == function guard recognized")
    local type_guard_neq = is_guarded_site(
        { "if type(NS.unit_creature_type) ~= \"function\" then return nil end" },
        1, "NS", "unit_creature_type")
    expect(type_guard_neq, true, "type(NS.x) ~= function guard recognized")

    print("[PASS] NS-member audit self-tests: binding detection (NS vs param "
        .. "ns), string/line/block-comment exclusion, whitespace parens, "
        .. "inline + block guard detection, bare-call flagging, allowlist "
        .. "gating incl. unguarded-allowlisted and stale-mock failure, bare "
        .. "value-read rule (leveling_vanilla shape / guard exclusion / pcall "
        .. "reference), type()-guard recognition pin")
    os.exit(0)
end

-- ============================================================================
-- CLI
-- ============================================================================
if arg and arg[1] == "--self-test" then
    run_self_tests()
end

local scan = run_scan()
local bad = violations(scan)

print("=============================================================================")
print("  NS-MEMBER AUDIT (called + bare-value-read members must be assigned,")
print("  engine, or allowlisted)")
print("=============================================================================")
local clean = 0
for _, res in ipairs(scan.results) do
    if not res.skipped then
        local n = 0
        for _, sites in pairs(res.calls) do n = n + #sites end
        if n > 0 then
            local file_bad = false
            local fname = res.file or res.rel
            for _, v in ipairs(bad) do
                if v.file == fname then file_bad = true break end
            end
            if not file_bad then
                clean = clean + 1
                print(string.format("  [ PASS ]  %-46s %d NS member call%s", fname,
                    n, (n == 1 and "" or "s")))
            end
        end
    end
end
local mock_n, guarded_n, optional_n = 0, 0, 0
for _, why in pairs(ALLOWLIST) do
    if why:find("^mock") then mock_n = mock_n + 1
    elseif why:find("^optional") then optional_n = optional_n + 1
    else guarded_n = guarded_n + 1 end
end
print("=============================================================================")
print(string.format("  Total:     %d call-bearing files (%d NS member calls)",
    scan.total_files, scan.total_calls))
print(string.format("  Clean:     %d", clean))
print(string.format("  Invalid:   %d", #bad))
print(string.format("  Allowlist: %d members (%d mock, %d guarded, %d optional)",
    mock_n + guarded_n + optional_n, mock_n, guarded_n, optional_n))
print("=============================================================================")

if #bad > 0 then
    print("  NS members called but not assigned / not engine / not allowlisted,")
    print("  or allowlisted entries that failed live verification:")
    for _, v in ipairs(bad) do
        print(string.format("    %s  line %d: NS.%s(  -- %s", v.file, v.line, v.name, v.why))
    end
    print("")
    print("  Fix: define NS.<member> in the repo, guard every call site (the")
    print("  optional-method pattern), or add the name to ALLOWLIST in this")
    print("  file with the evidence it is engine-provided.")
    os.exit(1)
end

print("  Every NS member call and bare value read targets an assigned, engine,")
print("  or allowlisted member.")
os.exit(0)
