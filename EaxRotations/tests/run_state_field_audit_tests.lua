-- run_state_field_audit_tests.lua -- Static audit: no state-table field may be
-- WRITTEN in a class/shared file but READ by nothing; no never-completed stub
-- (empty if-body / dead local) may exist either.
-- WHAT:  Scans every class file (sylvanas / vanilla / wotlk / sod / leveling)
--        plus shared/ for per-frame state tables (the table build_state fills
--        and returns — or a shared module's equivalent) and fails if any
--        field is written in the file but never read there. This is the
--        computed-but-unread defect class: fury_vanilla's pummel_ready shipped
--        un-consumed for 18 months (fixed 2026-08-11), and
--        shadow_sylvanas.lua:529 silence_ready / frost_sylvanas.lua:296
--        counterspell_ready are the same shape. The era-pair and dead-matcher
--        audits cannot see state fields (they are not strategy names / matcher
--        names), which is why this class shipped repeatedly.
-- NEW (2026-08-11): the never-completed-stub family. Two rules, both
--        invisible to the field rules (no state write, no read, no matcher):
--        S1 empty if-body (`if X then` + `end`, or inline `if X then end`) —
--        the shape that hid 4x `local exp_info = HitCap.get_expertise_cap()`
--        dead calls, the ViperSting/ScorpidSting stub pairs, and a bare
--        `if me then end`; S2 dead local (`local NAME = expr` where NAME is
--        never referenced again, word-boundary) — catches a discarded per-tick
--        call even without an empty-if. One live find: dispel_manager:301's
--        half-finished block was fixed (fear_nearby folded into skip_critical)
--        rather than removed, per the site's documented intent.
-- NEW (2026-08-11): the require-side family — the mirror of the dead-local
--        rule on the module surface.
--        S3 dead require: a column-0 `local X = require(...)` /
--        `local _, X = pcall(require, ...)` binding whose X is referenced by
--        nothing else in the file. S2 skips column-0 module constants, so the
--        discarded-module shape needs its own rule.
--        S4 dead export: a shared-module member (a table returned by
--        require()) referenced by NO pool file. Reference pool = every .lua
--        under EaxRotations/ (classes, shared, core, tests, root runtime
--        files), comment-stripped; test files COUNT as references (a
--        test-pinned export is used by the tree, not dead). This is the rule
--        that would have caught the consumable_manager re-export family and
--        the partially-dead spell_corpus surface swept in the 2026-08-11
--        cleanup (94 dead exports across 36 shared files).
--        S4 resolver rules (all validated against the real tree):
--          * module shape: the module's own `local M = {}` + column-0
--            `return M`, or a column-0 `return { ... }` literal (a mid-file
--            `return {` never counts — only when no valid return-ident
--            exists). Exports = dotted defs on the self-binding (excl `==`)
--            + literal keys, minus leading-underscore (private) names.
--          * require-map: `local X = require("shared/path")` and
--            `local _, X = pcall(require, "shared/path")` -> path -> {X};
--            a bare `require("path")` (side-effect load, no binding) marks
--            the module dynamically-loaded and SKIPS it (consumption
--            unknowable).
--          * NS aliases: `NS.Name = BINDING` anywhere in the pool makes
--            "Name" an extra reference prefix for BINDING's module (los_guard
--            installs itself at los_guard:157; core_sylvanas:233 installs
--            spell_corpus).
--          * reference census: one gmatch pass per pool file collecting
--            (prefix, member) pairs for every known prefix (self-binding +
--            consumer bindings + NS aliases). A member is DEAD iff its total
--            pool refs minus its definition occurrences == 0 (self-use inside
--            the module counts as a reference, so an internal helper called
--            only by a live member stays live).
--          * dynamic consumption: `pairs(B)` / `ipairs(B)` over a module's
--            prefix in any pool file skips the whole module.
--          * scope: extraction covers shared/ module tables ONLY — the
--            require() surface this rule targets. NS-surface members
--            installed on NS by core_sylvanas are OUT of scope (a separate
--            NS-surface sweep; census 2026-08-11: 58 genuinely-uncalled of
--            75 flagged). Prefix-keyed census may under-report members whose
--            names collide across modules (never over-report) — conservative
--            by design.
-- Resolver rules (all validated against the real tree):
--   State-table names per file:
--     A. every ident passed as the first argument to spec_kit.safe_state(...)
--     B. the two universal locals `state` and `s`
--     C. every WRITTEN ident ending in `_state` (per-frame state tables)
--     Leading-underscore idents (_energy_state in cat_sylvanas, a private
--     tracker table consumed by a shared module through a function-call API)
--     are out of scope, as are module-export names (strategies / M / module /
--     config / Healing / restoration_module / helpers). Note: bare `return X`
--     is deliberately NOT a name signal — it captures helper locals (row,
--     status, ...) and false-positives the scan (verified empirically).
--   Writes:  `ident.field =` where ident is a resolved state name. A trailing
--     `==` is excluded (`state.x == true` is a READ, not a write; `>=`, `<=`,
--     `~=` cannot match the pattern at all).
--   Reads (file-local, counted param-name-agnostically — `state.field` /
--     `s.field` / `st.field` all count the same token):
--     R1. every `.field` token in the comment-stripped content, MINUS the
--         write-site tokens;
--     R2. declarative DSL condition reads, per the evaluators in
--         shared/strategy_dsl_sylvanas.lua:
--           { type = "state", field = "X" }            -> state.X
--           { type = "in_combat" }                     -> state.in_combat
--           { type = "enemy_count" }                   -> state.enemy_count
--           { type = "distance" }                      -> state.target_distance
--           { type = "stance" }                        -> state.stance
--           { type = "is_pvp" }                        -> state.is_pvp
--           { type = "execute_phase" }                 -> state.execute_phase
--           { type = "hp_threshold", unit = X }        -> self: hp,
--                                        target: target_hp, else: lowest_hp
--     Comment text and SCHEMA bare keys (`silence_ready = false` inside a
--     schema table) never count as reads (they carry no leading dot).
--   A field is DEAD iff total reads (R1 + R2) <= 0, i.e. total `.field`
--   tokens <= write-site count.
--   Cross-file reads are NOT resolvable file-locally (a shared module can
--   consume the state through a function call, e.g. PresenceManager reading
--   state.presence). Every flagged field must be verified tree-wide before
--   removal; verified cross-file / test-only reads are pinned in the
--   CROSS_FILE_READS allowlist below with the evidence — never silently
--   exempted.
-- WHEN:  Run manually, in CI (verify_all), and in the pre-commit gate.
-- WHY:   A computed-but-unread state field is misleading live code — the
--        engine pays for the computation (NS.spell_ready / buff_up /
--        debuff_remains calls) every frame and a maintainer assumes the value
--        is consumed. Removing it deletes the write, its schema key, and its
--        init-table key.
-- SAFETY: Read-only text scan + static classification; --self-test has no
--        filesystem writes (synthetic in-memory content only).
--
-- ALLOWLIST: verified cross-file or test-only reads of fields that ARE live
-- but whose reads live outside the writing file. Each entry is pinned with
-- the evidence (file:line of the reader) so it cannot silently drift.
local CROSS_FILE_READS = {
    -- blood_wotlk presence: read by presence_manager_sylvanas.lua:107
    -- (`state.presence or context.presence`) — blood passes its state to
    -- get_optimal_presence / should_switch_presence (blood_wotlk.lua:112-113),
    -- and test_wotlk_battery_regression.lua:120-122 pins state.presence.
    ["EaxRotations/classes/deathknight/blood_wotlk.lua"] = { presence = true },
    -- resto healer entries/count: read by preemptive_heal_sylvanas.lua:285-286
    -- (`state.entries`, `state.count`) — the healer passes its state to
    -- PreemptiveHeal.match(context, state, ...) (e.g. resto_sylvanas.lua:802).
    ["EaxRotations/classes/druid/resto_sylvanas.lua"] = {
        entries = true, count = true,
        -- lowest_hp_pct: read by fsr_manager_sylvanas.lua:93 (`state.lowest_hp_pct`)
        -- — the FSR manager's documented state contract (resto_sylvanas.lua:442
        -- hoist comment).
        lowest_hp_pct = true,
    },
    ["EaxRotations/classes/priest/discipline_sylvanas.lua"] = {
        entries = true, count = true,
    },
    ["EaxRotations/classes/priest/holy_sylvanas.lua"] = {
        entries = true, count = true,
    },
    ["EaxRotations/classes/shaman/restoration_sylvanas.lua"] = {
        entries = true, count = true,
        -- mana_low: test-pinned by test_heal_scan_lane_regression.lua:189
        -- (mana_tide_window scenario must yield state.mana_low == true).
        mana_low = true,
    },
    -- healer tank / lowest_hp: read by dispel_manager_sylvanas.lua:243-251
    -- (`state.tank`), :310 (`state.lowest_hp`) via the class middleware
    -- strategies which receive the spec state.
    ["EaxRotations/classes/paladin/healing_sylvanas.lua"] = {
        tank = true, lowest_hp = true,
        -- divine_favor_active: read by heal_helper_sylvanas.lua:229/253
        -- (select_heal — the Holy Light fast-path when Divine Favor is
        -- active); written by this file's build_state (2026-08 read-side
        -- audit fix, buff 20216). Cross-file consumer.
        divine_favor_active = true,
    },
    ["EaxRotations/classes/priest/healing_sylvanas.lua"] = {
        tank = true, lowest_hp = true,
    },
    -- druid leveling wand_threshold: read by shared/leveling_sylvanas.lua:91
    -- (`state.wand_threshold or threshold`) via create_wand_matches
    -- (druid/leveling_sylvanas.lua:769).
    ["EaxRotations/classes/druid/leveling_sylvanas.lua"] = { wand_threshold = true, in_caster = true },
    --   druid/leveling_sylvanas in_caster: test_leveling_druid.lua:1157
    --     (form-state default contract — in_caster true when no forms).
    --   rogue/leveling_sylvanas sap_ready: test_leveling_rogue.lua:323
    --     (leveling readiness-surface contract — build_state populates every
    --     spell's readiness field and the test asserts it true).
    ["EaxRotations/classes/rogue/leveling_sylvanas.lua"] = { sap_ready = true },
    --   warrior/leveling_sylvanas slam_ready/shield_bash_ready:
    --     test_leveling_warrior.lua:339/343 (same readiness-surface contract).
    ["EaxRotations/classes/warrior/leveling_sylvanas.lua"] = { slam_ready = true, shield_bash_ready = true },
    --   shaman/leveling_sylvanas wand_threshold: test_leveling_shaman.lua:348
    --     (custom-settings contract — leveling_wand_threshold flows into state).
    ["EaxRotations/classes/shaman/leveling_sylvanas.lua"] = { wand_threshold = true },
    ["EaxRotations/classes/druid/leveling_vanilla.lua"] = { wand_threshold = true },
    -- BM sylvanas has_cheetah: read by aspect_manager_sylvanas.lua:54
    -- (`state.has_cheetah`) via the TBC hunter middleware aspect strategies
    -- (hunter/middleware_sylvanas.lua:135-138) which receive the spec state.
    ["EaxRotations/classes/hunter/beast_mastery_sylvanas.lua"] = { has_cheetah = true },
    -- Test-pinned fields: consumed by no strategy but asserted on the real
    -- build_state by regression tests, so the write (and its semantics) must
    -- stay. These are documented pins, not silent exemptions — the tests read
    -- the real state through the rotation harness.
    --   enhancement_sylvanas swing_remains: test_melee_cleu_wiring.lua:97/102
    --     (CLEU swing timer value or native fallback — SwingDiagnostics wiring).
    ["EaxRotations/classes/shaman/enhancement_sylvanas.lua"] = { swing_remains = true },
    --   discipline_wotlk target_hp: test_discipline_wotlk_dsl_priority.lua:160
    --     (healers score the LOWEST FRIENDLY unit as their target, so
    --     state.target_hp is the lowest friendly's hp — a healer-only semantic).
    ["EaxRotations/classes/priest/discipline_wotlk.lua"] = { target_hp = true },
    --   restoration_wotlk tidal_waves_stacks: test_shaman_wotlk_live_fixes.lua:394
    --     (WotLK resto mechanic — Riptide-proc Tidal Waves stacks 53390 tracked
    --     on the real build_state; the field documents the mechanic and pins
    --     the single-max-rank buff table that survived the W3.3 ID audit).
    ["EaxRotations/classes/shaman/restoration_wotlk.lua"] = { tidal_waves_stacks = true },
    -- Warlock item-state fields: read by the shared helpers that receive the
    -- real build_state output — warlock_healthstone_sylvanas.lua:62/99
    -- (`state.healthstone_ready`, `state.healthstone_id`) and
    -- warlock_mana_gem_sylvanas.lua:26/29 (`state.mana_gem_ready`/`id`).
    ["EaxRotations/classes/warlock/affliction_sylvanas.lua"] = { healthstone_id = true, healthstone_ready = true },
    --   demonology: also the curse-remains read by warlock_curse_helper
    --     sylvanas.lua:22-28 via other_curse_active(state, curse) at :389.
    ["EaxRotations/classes/warlock/demonology_sylvanas.lua"] = {
        healthstone_id = true, healthstone_ready = true,
        agony_remains = true, doom_remains = true, coe_remains = true,
        recklessness_remains = true, weakness_remains = true,
    },
    ["EaxRotations/classes/warlock/destruction_sylvanas.lua"] = {
        healthstone_id = true, healthstone_ready = true,
        mana_gem_id = true, mana_gem_ready = true,
    },
    -- protection_sylvanas execute_ready: read by stance_manager_sylvanas.lua:145
    -- (`state.execute_ready` — get_optimal_stance cost calc) via the
    -- SM.get_optimal_stance(context, prot_state) call at :406.
    ["EaxRotations/classes/warrior/protection_sylvanas.lua"] = { execute_ready = true },
    -- restoration_sylvanas mana_low: test-pinned by
    -- test_heal_scan_lane_regression.lua:189 (mana_tide_window scenario
    -- must yield state.mana_low == true).
}

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local ROOTS = { "EaxRotations/classes", "EaxRotations/shared" }

-- ---------------------------------------------------------------------------
-- Comment stripping: replace comment text with same-length spaces so line
-- positions survive and comment text can never count as a read or a write.
-- Same implementation as the dead-matcher audit.
-- ---------------------------------------------------------------------------
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

local MODULE_EXPORTS = {
    strategies = true, M = true, module = true, config = true, Healing = true,
    restoration_module = true, helpers = true,
}

local function resolve_names(stripped)
    local names = {}
    local function add(n)
        if n and n ~= "nil" and n ~= "false" and n ~= "true"
            and not n:match("^_") and not MODULE_EXPORTS[n] then
            names[n] = true
        end
    end
    -- Rule A: first arg of spec_kit.safe_state(...)
    for n in stripped:gmatch("spec_kit%.safe_state%(([%a_][%w_]*)") do add(n) end
    -- Rule B: the two universal state locals
    add("state")
    add("s")
    -- Rule C: written idents ending in _state
    for ident in stripped:gmatch("([%a_][%w_]*)%.[%a_][%w_]*%s*=") do
        if ident:sub(-6) == "_state" then add(ident) end
    end
    return names
end

-- ---------------------------------------------------------------------------
-- Core scan: content -> { names, writes = { {ident, field, line} }, counts }
-- ---------------------------------------------------------------------------
local function scan_content(content)
    if type(content) ~= "string" then
        return { error = "content must be a string", writes = {}, counts = {}, names = {} }
    end
    local stripped = strip_comments(content)
    local names = resolve_names(stripped)

    local lines = {}
    if stripped:sub(-1) == "\n" then stripped = stripped:sub(1, -2) end
    for line in (stripped .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line:gsub("\r$", "")
    end

    local writes = {}
    for i = 1, #lines do
        local line = lines[i]
        local pos = 1
        while true do
            local si, ei, ident, field = line:find("([%a_][%w_]*)%.([%a_][%w_]*)%s*=", pos)
            if not si then break end
            -- A `==` after the captured `=` means a comparison, not a write.
            if line:sub(ei + 1, ei + 1) ~= "=" and names[ident] then
                writes[#writes + 1] = { ident = ident, field = field, line = i }
            end
            pos = ei + 1
        end
    end

    local counts = {}
    for field in stripped:gmatch("%.([%a_][%w_]*)") do
        counts[field] = (counts[field] or 0) + 1
    end
    -- Declarative DSL condition reads (R2) — source of truth:
    -- shared/strategy_dsl_sylvanas.lua condition_evaluators.
    local function read(field)
        counts[field] = (counts[field] or 0) + 1
    end
    for f in stripped:gmatch('type%s*=%s*"state"%s*,%s*field%s*=%s*"([%a_][%w_]*)"') do read(f) end
    for f in stripped:gmatch('field%s*=%s*"([%a_][%w_]*)"%s*,%s*type%s*=%s*"state"') do read(f) end
    for _ in stripped:gmatch('type%s*=%s*"in_combat"') do read("in_combat") end
    for _ in stripped:gmatch('type%s*=%s*"enemy_count"') do read("enemy_count") end
    for _ in stripped:gmatch('type%s*=%s*"distance"') do read("target_distance") end
    for _ in stripped:gmatch('type%s*=%s*"stance"') do read("stance") end
    for _ in stripped:gmatch('type%s*=%s*"is_pvp"') do read("is_pvp") end
    for _ in stripped:gmatch('type%s*=%s*"execute_phase"') do read("execute_phase") end
    for unit in stripped:gmatch('type%s*=%s*"hp_threshold"%s*,%s*unit%s*=%s*"([a-z]+)"') do
        if unit == "self" then read("hp")
        elseif unit == "target" then read("target_hp")
        else read("lowest_hp") end
    end

    -- -------------------------------------------------------------------------
    -- Stub rules (2026-08-11): the never-completed-block family the field
    -- audits cannot see. Two shapes, both invisible to write-side (no state
    -- field), read-side (no read), and dead-matcher (no matcher) rules:
    --   S1. empty if-body: `if X then` immediately followed by `end` (blank
    --       lines allowed between), or the inline `if X then end`. This is
    --       what let 4x `local exp_info = HitCap.get_expertise_cap() ...
    --       if exp_info then end` and the ViperSting/ScorpidSting stub pairs
    --       ship: a per-tick call whose result is discarded + an empty body.
    --   S2. dead local: an INDENTED `local NAME = expr` (function scope = the
    --       per-tick / per-call body) where NAME is never referenced again
    --       anywhere in the file (word-boundary match, so `x1` does not count
    --       as a use of `x`). A per-tick call whose result is discarded
    --       without even an empty-if (plain `local x = f()`) is caught here.
    --       Column-0 (module-level) constants are deliberately OUT of scope —
    --       the tree carries ~237 never-referenced module constants that are a
    --       separate dead-constant campaign, not the per-tick stub family.
    local stubs = {}
    for i = 1, #lines do
        local line = lines[i]
        if line:match("^%s*if .+ then%s*$") then
            local j = i + 1
            while j <= #lines and lines[j]:match("^%s*$") do j = j + 1 end
            if j <= #lines and lines[j]:match("^%s*end%s*$") then
                stubs[#stubs + 1] = { kind = "empty_if", line = i,
                                      name = line:match("^%s*if (.+) then") }
            end
        elseif line:match("^%s*if .+ then%s*end%s*$") then
            stubs[#stubs + 1] = { kind = "empty_if", line = i,
                                  name = line:match("^%s*if (.+) then") }
        end
    end
    for i = 1, #lines do
        -- NOTE: `([%a_][%w_]*)` is the identifier form — `(%a_%w*)` would be
        -- the SEQUENCE letter+underscore+word and never match (the 2026-08-11
        -- first cut silently matched nothing; fixtures caught it).
        -- Only INDENTED declarations are function-scope (per-tick/per-call);
        -- column-0 declarations are module-level constants, out of scope here.
        local lead, name = lines[i]:match("^(%s*)local%s+([%a_][%w_]*)%s*=")
        if name and lead and lead ~= "" then
            local used = false
            for j = 1, #lines do
                if j ~= i then
                    for token in lines[j]:gmatch("%f[%a_][%a_][%w_]*") do
                        if token == name then used = true break end
                    end
                end
                if used then break end
            end
            if not used then
                stubs[#stubs + 1] = { kind = "dead_local", line = i, name = name }
            end
        end
    end
    -- S3. dead require: a column-0 `local X = require(...)` / pcall require
    -- binding whose X is referenced by nothing else in the file. S2 skips
    -- column-0 declarations (module constants), so the discarded-module shape
    -- needs this rule. Same word-boundary reference check as S2; the require
    -- path string can never match the binding name, so no extra exclusion.
    for i = 1, #lines do
        local name = lines[i]:match("^local%s+([%a_][%w_]*)%s*=%s*require%s*%(")
            or lines[i]:match("^local%s+[%a_][%w_]*%s*,%s*([%a_][%w_]*)%s*=%s*pcall%s*%(%s*require%s*,")
        if name then
            local used = false
            for j = 1, #lines do
                if j ~= i then
                    for token in lines[j]:gmatch("%f[%a_][%a_][%w_]*") do
                        if token == name then used = true break end
                    end
                end
                if used then break end
            end
            if not used then
                stubs[#stubs + 1] = { kind = "dead_require", line = i, name = name }
            end
        end
    end

    return { names = names, writes = writes, counts = counts, stubs = stubs }
end

-- ---------------------------------------------------------------------------
-- File scan: relative path under a ROOT -> skipped flag or result
-- ---------------------------------------------------------------------------
local function scan_file(rel_path)
    local f = io.open(rel_path, "rb")
    if not f then return { skipped = true } end
    local content = f:read("*a")
    f:close()
    local res = scan_content(content)
    res.file = rel_path
    return res
end

-- ---------------------------------------------------------------------------
-- Full scan: every .lua under classes/ + shared/
-- ---------------------------------------------------------------------------
local function run_scan()
    local files = {}
    for _, root in ipairs(ROOTS) do
        local pipe = io.popen("find " .. root .. " -name '*.lua'")
        for line in pipe:lines() do
            files[#files + 1] = line:gsub("\\", "/")
        end
        pipe:close()
    end
    table.sort(files)

    local results = {}
    local total_files = 0
    local total_fields = 0
    for _, path in ipairs(files) do
        local res = scan_file(path)
        if not res.skipped and #res.writes > 0 then
            total_files = total_files + 1
            total_fields = total_fields + #res.writes
        end
        results[#results + 1] = { path = path, res = res }
    end
    return { results = results, total_files = total_files, total_fields = total_fields }
end

-- dead list: { {file, line, field, writes} }
local function dead_fields(res)
    local by_field = {}
    for _, w in ipairs(res.writes) do
        by_field[w.field] = by_field[w.field] or {}
        by_field[w.field][#by_field[w.field] + 1] = w
    end
    local dead = {}
    for field, wlist in pairs(by_field) do
        local tokens = res.counts[field] or 0
        if tokens <= #wlist then
            dead[#dead + 1] = { field = field, writes = #wlist, tokens = tokens,
                                line = wlist[1].line }
        end
    end
    table.sort(dead, function(a, b)
        if a.line ~= b.line then return a.line < b.line end
        return a.field < b.field
    end)
    return dead
end

local function allowlisted(res_file, field)
    local entry = CROSS_FILE_READS[res_file]
    return entry and entry[field] == true
end

-- ---------------------------------------------------------------------------
-- Duplicate allowlist-key detection. A table constructor silently keeps the
-- LAST occurrence of a duplicated key, so a second entry for a file silently
-- drops the first one's fields (the 2026-08-11 mana_low footgun: adding
-- shaman/restoration mana_low overrode the pre-existing entries/count entry
-- and the audit stopped protecting them without any signal). This scans the
-- constructor source for `["key"] =` string keys and reports repeats.
-- ---------------------------------------------------------------------------
local function dup_allowlist_keys(src)
    -- Strip -- line comments so prose mentioning bracket keys can't false-hit.
    local stripped = src:gsub('%-%-[^\n]*', '')
    local dups, seen = {}, {}
    for k in stripped:gmatch('%["([^"]+)"%]%s*=') do
        if seen[k] then dups[#dups + 1] = k else seen[k] = true end
    end
    return dups
end

-- Extract just the real CROSS_FILE_READS constructor (first occurrence, so
-- self-test fixture strings that mention the same keys can never false-hit).
local function extract_allowlist_block(src)
    local start = src:find('local CROSS_FILE_READS = {', 1, true)
    if not start then return "" end
    start = src:find('{', start, true)
    local depth, i = 1, start
    while depth > 0 do
        i = src:find('[{}]', i + 1)
        if not i then return "" end
        if src:sub(i, i) == "{" then depth = depth + 1 else depth = depth - 1 end
    end
    return src:sub(start, i)
end

local function check_own_allowlist(path)
    local f = io.open(path, "rb")
    if not f then
        print("  Cannot read own source for allowlist dup check: " .. tostring(path))
        os.exit(1)
    end
    local src = f:read("*a")
    f:close()
    local dups = dup_allowlist_keys(extract_allowlist_block(src))
    if #dups > 0 then
        print("  DUPLICATE CROSS_FILE_READS keys (later entry silently overrides")
        print("  the earlier one — the mana_low footgun): " .. table.concat(dups, ", "))
        os.exit(1)
    end
end

-- ---------------------------------------------------------------------------
-- S4. Dead-export scan: shared-module members referenced by no pool file.
-- See the header for the full resolver contract. All functions below take an
-- injected pool (path -> comment-stripped content) so the self-test can feed
-- synthetic in-memory files; the CLI builds the pool from disk.
-- ---------------------------------------------------------------------------
local S4_POOL_ROOT = "EaxRotations"

local function pool_files()
    local files = {}
    local pipe = io.popen("find " .. S4_POOL_ROOT .. " -name '*.lua'")
    for line in pipe:lines() do
        files[#files + 1] = line:gsub("\\", "/")
    end
    pipe:close()
    table.sort(files)
    return files
end

local function build_pool()
    local pool = {}
    for _, path in ipairs(pool_files()) do
        local f = io.open(path, "rb")
        if f then
            local content = f:read("*a")
            f:close()
            pool[path] = strip_comments(content)
        end
    end
    return pool
end

local function normalize_require_path(path)
    if path:match("^EaxRotations/") then return path end
    if path:match("^(shared/|classes/)") then return "EaxRotations/" .. path .. ".lua" end
    if path:match("^common/") then return nil end -- engine module, out of pool
    return "EaxRotations/" .. path .. ".lua"
end

-- path -> { binding = true } for every `local X = require("path")` and
-- `local _, X = pcall(require, "path")`; bare (unbound) requires collected
-- separately as dynamic side-effect loads.
local function build_require_map(pool)
    local rmap, bare = {}, {}
    for path, src in pairs(pool) do
        for binding, rpath in src:gmatch("local%s+([%a_][%w_]*)%s*=%s*require%s*%(%s*[\"']([^\"']+)[\"']%s*%)") do
            local norm = normalize_require_path(rpath)
            if norm and pool[norm] then
                rmap[norm] = rmap[norm] or {}
                rmap[norm][binding] = true
            end
        end
        for binding, rpath in src:gmatch("local%s+[%a_][%w_]*%s*,%s*([%a_][%w_]*)%s*=%s*pcall%s*%(%s*require%s*,%s*[\"']([^\"']+)[\"']%s*%)") do
            local norm = normalize_require_path(rpath)
            if norm and pool[norm] then
                rmap[norm] = rmap[norm] or {}
                rmap[norm][binding] = true
            end
        end
        for line in (src .. "\n"):gmatch("(.-)\n") do
            local rpath = line:match("require%s*%(%s*[\"']([^\"']+)[\"']")
            if rpath
                and not line:match("local%s+[%a_][%w_]*%s*=%s*require%s*%(")
                and not line:match("local%s+[%a_][%w_]*%s*,%s*[%a_][%w_]*%s*=%s*pcall%s*%(%s*require%s*,") then
                local norm = normalize_require_path(rpath)
                if norm and pool[norm] then bare[norm] = true end
            end
        end
    end
    return rmap, bare
end

-- Module self-binding: the module's own table name from a column-0
-- `return X` where X is a module-level `local X = {` (or setmetatable);
-- "LITERAL" for a column-0 `return { ... }`; nil otherwise (non-table
-- return or no return — not a module table, out of scope). All patterns are
-- PER-LINE anchored: Lua's `^` anchors to the string start, not to a line,
-- so a `return M` at line 160 (los_guard) or a `local M = {}` below a
-- header comment would silently fail an unanchored match.
local function module_self_binding(stripped)
    local ret, has_literal
    local function each_line(fn)
        for line in (stripped .. "\n"):gmatch("(.-)\n") do
            fn(line)
        end
    end
    each_line(function(line)
        local r = line:match("^return%s+([%a_][%w_]*)")
        if r then ret = r end
        if line:match("^return%s*{") then has_literal = true end
    end)
    if ret then
        local decl_ok = false
        each_line(function(line)
            if line:match("^local%s+" .. ret .. "%s*=%s*{")
                or line:match("^local%s+" .. ret .. "%s*=%s*setmetatable%s*%(") then
                decl_ok = true
            end
        end)
        if decl_ok then return ret end
        return nil -- return of a non-module value (function result etc.)
    end
    if has_literal then return "LITERAL" end
    return nil
end

-- Top-level keys of the LAST `return { ... }` literal in the module (only
-- consulted when module_self_binding returned "LITERAL", so a mid-file
-- `return {` in a function body cannot hijack a named-table module).
local function table_literal_keys(src)
    local out, last = {}, nil
    local pos = 1
    while true do
        local s = src:find("return%s*{", pos)
        if not s then break end
        last = s
        pos = s + 1
    end
    if not last then return out end
    local brace = src:find("{", last)
    if not brace then return out end
    local depth = 0
    for i = brace, #src do
        local ch = src:sub(i, i)
        if ch == "{" then
            depth = depth + 1
        elseif ch == "}" then
            if depth == 1 then break end
            depth = depth - 1
        elseif depth == 1 and ch == "=" and src:sub(i - 1, i - 1) ~= "=" then
            local k = src:sub(math.max(1, i - 40), i - 1):match("([%a_][%w_]*)%s*$")
            if k then out[k] = true end
        end
    end
    return out
end

-- Dotted definitions of a binding's members (`B.x =` excluding `==`, and
-- `function B.x(`). Returns member -> definition count.
local function dotted_defs(stripped, binding)
    local defs = {}
    for line in (stripped .. "\n"):gmatch("(.-)\n") do
        local pos = 1
        while true do
            local si, ei, m = line:find("%.([%a_][%w_]*)%s*=", pos)
            if not si then break end
            if line:sub(ei + 1, ei + 1) ~= "="
                and line:sub(1, si - 1):match("%f[%a_]" .. binding .. "%s*$") then
                defs[m] = (defs[m] or 0) + 1
            end
            pos = ei + 1
        end
        for m in line:gmatch("function%s+" .. binding .. "%.([%a_][%w_]*)%s*%(") do
            defs[m] = (defs[m] or 0) + 1
        end
        for m in line:gmatch("function%s+" .. binding .. ":([%a_][%w_]*)%s*%(") do
            defs[m] = (defs[m] or 0) + 1
        end
    end
    return defs
end

-- Global (prefix, member) census across every pool file, one gmatch pass per
-- file, for every known reference prefix.
local function build_census(pool, binding_set)
    local counts = {}
    for _, src in pairs(pool) do
        -- Dot references: `B.member` at any depth. Chains like
        -- `NS.SpellCorpus.use_me()` must count BOTH (NS, SpellCorpus) and
        -- (SpellCorpus, use_me) — a plain gmatch CONSUMES the middle token
        -- ("NS.SpellCorpus" matches as one pair and the search resumes at
        -- use_me), silently missing the NS-alias reference. The find-loop
        -- advances past each matched `word.` segment so the member token is
        -- re-scanned as a potential prefix.
        local pos = 1
        while true do
            local s, e = src:find("%f[%a_][%a_][%w_]*%.", pos)
            if not s then break end
            local prefix = src:match("([%a_][%w_]*)%.", s)
            local member = src:match("^[%a_][%w_]*", e + 1)
            if prefix and member and binding_set[prefix] then
                local t = counts[prefix]
                if not t then t = {}; counts[prefix] = t end
                t[member] = (t[member] or 0) + 1
            end
            pos = e + 1
        end
        -- String-index references: `B["member"]` / `B['member']` count too
        -- (dot and bracket access are the same call).
        for prefix, member in src:gmatch("([%a_][%w_]*)%[%s*[\"']([%a_][%w_]*)[\"']%s*%]") do
            if binding_set[prefix] then
                local t = counts[prefix]
                if not t then t = {}; counts[prefix] = t end
                t[member] = (t[member] or 0) + 1
            end
        end
        -- Colon calls: `B:method(...)` — the 2026-08-11 sweep's census missed
        -- this form and wrongly removed combat_mode.is_single_target/mode_name
        -- (called through an NS alias) and spell_queue_helper's
        -- queue_spell_position (called as `spell_queue:queue_spell_position`
        -- behind a type() guard). A colon DEF line (`function M:method(`) is
        -- counted here too and subtracted by dotted_defs, so a colon-defined
        -- member with zero calls still flags dead.
        for prefix, member in src:gmatch("([%a_][%w_]*)%:([%a_][%w_]*)") do
            if binding_set[prefix] then
                local t = counts[prefix]
                if not t then t = {}; counts[prefix] = t end
                t[member] = (t[member] or 0) + 1
            end
        end
    end
    return counts
end

local function iterated_bindings(pool)
    local iterated = {}
    for _, src in pairs(pool) do
        for prefix in src:gmatch("pairs%s*%(%s*([%a_][%w_]*)") do iterated[prefix] = true end
        for prefix in src:gmatch("ipairs%s*%(%s*([%a_][%w_]*)") do iterated[prefix] = true end
    end
    return iterated
end

-- Full S4 pass over an injected pool. Returns a sorted list of dead exports
-- { path, member }.
local function run_export_scan_from_pool(pool)
    local rmap, bare = build_require_map(pool)
    local binding_path = {}
    for path, bindings in pairs(rmap) do
        for b in pairs(bindings) do binding_path[b] = path end
    end
    -- NS aliases: (alias, binding) pairs -> the module path each alias refers
    -- to. Consumer installs resolve the RHS binding through the require-map
    -- (core_sylvanas:233 `NS.SpellCorpus = _spell_corpus`); self-installs
    -- resolve through the module's OWN file only (`NS.LosGuard = M` at
    -- los_guard:157 — the RHS "M" is unambiguous only inside the module that
    -- declares that M, so the alias scan is scoped to the module's own
    -- source, never pooled across modules with the same self-binding name).
    local self_binding = {}
    for path, src in pairs(pool) do
        if path:match("^EaxRotations/shared/") then
            local b = module_self_binding(src)
            if b then self_binding[path] = b end
        end
    end
    local alias_path = {}
    for _, src in pairs(pool) do
        for alias, binding in src:gmatch("NS%.([%a_][%w_]*)%s*=%s*([%a_][%w_]*)") do
            local p = binding_path[binding]
            if p then
                alias_path[p] = alias_path[p] or {}
                alias_path[p][alias] = true
            end
        end
    end
    for path, sb in pairs(self_binding) do
        if sb ~= "LITERAL" and pool[path] then
            for alias in pool[path]:gmatch("NS%.([%a_][%w_]*)%s*=%s*" .. sb) do
                alias_path[path] = alias_path[path] or {}
                alias_path[path][alias] = true
            end
        end
    end
    -- Full prefix set: every consumer binding, self-binding, and NS alias.
    local binding_set = {}
    for _, bindings in pairs(rmap) do
        for b in pairs(bindings) do binding_set[b] = true end
    end
    for _, sb in pairs(self_binding) do binding_set[sb] = true end
    for _, aliases in pairs(alias_path) do
        for a in pairs(aliases) do binding_set[a] = true end
    end
    local counts = build_census(pool, binding_set)
    local iterated = iterated_bindings(pool)

    local dead = {}
    for path, src in pairs(pool) do
        if path:match("^EaxRotations/shared/") then
            if bare[path] then -- side-effect-only load: consumption unknowable
            else
                local sb = self_binding[path]
                if sb then
                    local prefixes = {}
                    if sb ~= "LITERAL" then prefixes[#prefixes + 1] = sb end
                    for b in pairs(rmap[path] or {}) do prefixes[#prefixes + 1] = b end
                    for a in pairs(alias_path[path] or {}) do prefixes[#prefixes + 1] = a end
                    local skip = false
                    for _, p in ipairs(prefixes) do
                        if iterated[p] then skip = true break end
                    end
                    if not skip then
                        local defs = {}
                        if sb == "LITERAL" then
                            -- Literal-return members are never counted in the
                            -- census under a self-binding prefix (there is no
                            -- `local M`), so their defs must NOT be subtracted.
                            for m in pairs(table_literal_keys(src)) do
                                if not m:match("^_") then defs[m] = 0 end
                            end
                        else
                            defs = dotted_defs(src, sb)
                        end
                        for m in pairs(defs) do
                            if not m:match("^_") then
                                local refs = 0
                                for _, p in ipairs(prefixes) do
                                    local pc = counts[p]
                                    if pc then refs = refs + (pc[m] or 0) end
                                end
                                refs = refs - (defs[m] or 0)
                                if refs <= 0 then
                                    dead[#dead + 1] = { path = path, member = m }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(dead, function(a, b)
        if a.path ~= b.path then return a.path < b.path end
        return a.member < b.member
    end)
    return dead
end

local function run_export_scan()
    return run_export_scan_from_pool(build_pool())
end

-- ---------------------------------------------------------------------------
-- Self-tests (non-vacuity): every resolver rule behaves correctly on
-- synthetic in-memory fixtures, plus real-file probes.
-- ---------------------------------------------------------------------------
local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end

    expect(scan_content(nil).error, "content must be a string", "malformed nil content")
    expect(scan_content(123).error, "content must be a string", "malformed numeric content")

    -- Fixture 1: dead field flagged (write, no read).
    local dead1 = scan_content(
        "local state = {}\n"
        .. "local function build_state()\n"
        .. "    state.silence_ready = false\n"
        .. "    return state\n"
        .. "end\n")
    expect(#dead_fields(dead1), 1, "write with no read is dead")
    expect(dead_fields(dead1)[1].field, "silence_ready", "dead field name")

    -- Fixture 2: live via matcher param of a DIFFERENT name (st.field).
    local live = scan_content(
        "local state = {}\n"
        .. "state.x = 1\n"
        .. "local function m(context, st)\n"
        .. "    return st.x\n"
        .. "end\n")
    expect(#dead_fields(live), 0, "param-agnostic dot read is live")

    -- Fixture 3: `==` comparison is a READ, not a write.
    local cmp = scan_content(
        "local state = {}\n"
        .. "local function m()\n"
        .. "    return state.x == true\n"
        .. "end\n")
    expect(#cmp.writes, 0, "`==` never counts as a write")
    expect(#dead_fields(cmp), 0, "no writes means nothing flagged")

    -- Fixture 4: comment mention must NOT count as a read.
    local commented = scan_content(
        "local state = {}\n"
        .. "state.silence_ready = false\n"
        .. "-- state.silence_ready is consumed elsewhere\n")
    expect(#dead_fields(commented), 1, "comment mention is not a read")

    -- Fixture 5: schema bare key must NOT count as a read.
    local schema = scan_content(
        "local SCHEMA = { silence_ready = false, }\n"
        .. "local state = {}\n"
        .. "state.silence_ready = false\n"
        .. "return spec_kit.safe_state(state, SCHEMA)\n")
    expect(#dead_fields(schema), 1, "schema bare key is not a read")

    -- Fixture 6: declarative { type = "state", field = "X" } IS a read.
    local decl = scan_content(
        "local state = {}\n"
        .. "state.hp = 100\n"
        .. "local D = { { type = \"state\", field = \"hp\", op = \"<\", value = 40 } }\n")
    expect(#dead_fields(decl), 0, "declarative state-field read is live")

    -- Fixture 7: declarative implicit reads (hp_threshold unit=self -> hp).
    local thresh = scan_content(
        "local state = {}\n"
        .. "state.hp = 100\n"
        .. "local D = { { type = \"hp_threshold\", unit = \"self\", op = \"<\", value = 35 } }\n")
    expect(#dead_fields(thresh), 0, "hp_threshold self reads state.hp")

    -- Fixture 8: field written twice with no reads -> flagged once.
    local twice = scan_content(
        "local state = {}\n"
        .. "state.x = 1\n"
        .. "state.x = 2\n")
    expect(#dead_fields(twice), 1, "double-write with no read is dead")

    -- Fixture 9: compound write+read keeps the OTHER field live.
    local compound = scan_content(
        "local state = {}\n"
        .. "state.presence = state.frost_presence_up and 2 or 1\n")
    local df = dead_fields(compound)
    expect(#df, 1, "compound line: presence dead")
    expect(df[1].field, "presence", "compound line: presence is the dead one")
    expect(dead_fields(scan_content(
        "local state = {}\n"
        .. "state.frost_presence_up = true\n"
        .. "state.presence = state.frost_presence_up and 2 or 1\n")).field,
        nil, "frost_presence_up stays live via the compound read")

    -- Fixture 10: leading-underscore tracker tables are out of scope.
    local tracker = scan_content(
        "local _energy_state = {}\n"
        .. "_energy_state.last_tick_time = 1\n")
    expect(#tracker.writes, 0, "leading-underscore ident is out of scope")

    -- Fixture 11: module-export names are out of scope.
    local mod = scan_content(
        "row.name = name\n"
        .. "strategies.thing = 1\n")
    expect(#mod.writes, 0, "row/strategies are not state names")

    -- Fixture 12: `s` as the state local resolves (hunter/arcane shape).
    local svar = scan_content(
        "local s = {}\n"
        .. "s.target_hp = 50\n")
    expect(#dead_fields(svar), 1, "s-named state table resolves")
    expect(dead_fields(svar)[1].field, "target_hp", "s-named dead field name")

    -- Real-file probes: the known dead fields were REMOVED by the 2026-08-11
    -- cleanup — they must no longer be written at all (pins the removal, so a
    -- future re-add of a computed-but-unread field fails the audit).
    local shadow = scan_file("EaxRotations/classes/priest/shadow_sylvanas.lua")
    expect(shadow.skipped, nil, "shadow_sylvanas.lua exists")
    local shadow_writes = {}
    for _, w in ipairs(shadow.writes) do shadow_writes[w.field] = true end
    expect(shadow_writes["silence_ready"], nil, "shadow silence_ready was removed")
    local frost = scan_file("EaxRotations/classes/mage/frost_sylvanas.lua")
    local frost_writes = {}
    for _, w in ipairs(frost.writes) do frost_writes[w.field] = true end
    expect(frost_writes["counterspell_ready"], nil, "frost counterspell_ready was removed")

    -- ...and the 2026-08-11 live fix is still live (write + read both present).
    local fury = scan_file("EaxRotations/classes/warrior/fury_vanilla.lua")
    local fury_dead = {}
    for _, d in ipairs(dead_fields(fury)) do fury_dead[d.field] = true end
    expect(fury_dead["pummel_ready"], nil, "fury_vanilla pummel_ready is live")

    -- arms_sylvanas's ms_ready was removed with the other computed-but-unread
    -- readiness fields (the strategies gate via action_ready recomputation).
    local arms = scan_file("EaxRotations/classes/warrior/arms_sylvanas.lua")
    local arms_writes = {}
    for _, w in ipairs(arms.writes) do arms_writes[w.field] = true end
    expect(arms_writes["ms_ready"], nil, "arms ms_ready was removed")

    -- Fixture 13: duplicate CROSS_FILE_READS keys are detected loudly (the
    -- mana_low footgun — a duplicated file key silently drops the earlier
    -- entry's fields, weakening the allowlist with no signal).
    local dup_src = "local CROSS_FILE_READS = {\n"
        .. '  ["EaxRotations/classes/a.lua"] = { x = true },\n'
        .. '  ["EaxRotations/classes/b.lua"] = { y = true },\n'
        .. '  ["EaxRotations/classes/a.lua"] = { z = true },\n'
        .. "}\n"
    local dups = dup_allowlist_keys(dup_src)
    expect(#dups, 1, "one duplicate allowlist key detected")
    expect(dups[1], "EaxRotations/classes/a.lua", "duplicate key name")
    local clean_src = dup_src:gsub('%[%"EaxRotations/classes/a.lua%"%] = %{ z = true %},',
        '["EaxRotations/classes/c.lua"] = { z = true },')
    expect(#dup_allowlist_keys(clean_src), 0, "no duplicates in clean constructor")

    -- Fixture 14: stub rules — empty if-body (S1) and dead local (S2). These
    -- pin the never-completed-block family the field audits cannot see: the
    -- 2026-08-11 sweep removed 4x `local exp_info = HitCap.get_expertise_cap()
    -- ... if exp_info then end`, the ViperSting/ScorpidSting stub pairs, and
    -- the bare `if me then end`. The fixtures prove the rules fire on the
    -- exact shapes; the real-file probe below proves the tree is clean today.
    local function stub_kinds(content)
        local out = {}
        for _, s in ipairs(scan_content(content).stubs or {}) do
            out[#out + 1] = s.kind .. ":" .. tostring(s.name or "")
        end
        table.sort(out)
        return out
    end
    -- S1 multi-line empty body (the exp_info shape): the empty-if fires; the
    -- local is referenced by the empty-if's condition, so the dead-local rule
    -- (which catches the plain discarded call with NO empty-if) does not
    -- double-fire — the empty-if is the violation that names the shape.
    local s1 = scan_content(
        "    local exp_info = HitCap.get_expertise_cap()\n"
        .. "    if exp_info then\n"
        .. "    end\n")
    expect(#(s1.stubs or {}), 1, "exp_info shape flags the empty-if")
    expect(s1.stubs[1].kind, "empty_if", "multi-line empty if-body flagged")
    expect(s1.stubs[1].name, "exp_info", "empty-if condition named")
    -- S1 inline form: `if x then end` on one line is also an empty body.
    local s1b = scan_content("if x then end\n")
    expect(#(s1b.stubs or {}), 1, "inline empty if-body flagged")
    expect(s1b.stubs[1].kind, "empty_if", "inline empty if-body kind")
    -- S1 negative: a real if with a body is NOT an empty body.
    local s1c = scan_content(
        "if x then\n"
        .. "  return y\n"
        .. "end\n")
    expect(#(s1c.stubs or {}), 0, "real if-body not flagged")
    -- S2 dead local: discarded per-tick call without an empty-if is still
    -- caught; `x1` elsewhere does NOT count as a use of `x` (word boundary).
    local s2 = scan_content(
        "    local wasted = NS.spell_ready(ACTION.X, target)\n"
        .. "    state.x1 = wasted_x or 0\n")
    expect(#(s2.stubs or {}), 1, "discarded local flagged without empty-if")
    expect(s2.stubs[1].kind, "dead_local", "dead-local kind without empty-if")
    expect(s2.stubs[1].name, "wasted", "dead-local name")
    -- S2 negative: a local read later is live.
    local s2b = scan_content(
        "    local me = NS.GetPlayer()\n"
        .. "    state.hp = me and NS.unit_health_pct(me) or 100\n")
    expect(#(s2b.stubs or {}), 0, "live local not flagged")
    -- S2 negative: a column-0 module constant is out of scope (the ~237
    -- module-constant population is a separate campaign, not the stub family).
    local s2c = scan_content("local MODULE_CONST = 75\n")
    expect(#(s2c.stubs or {}), 0, "module-level constant not flagged")
    -- Real-file probes: the stub family is gone from the tree (the 2026-08-11
    -- sweep removed all 10 sites + the dispel_manager half-finished block).
    local arms = scan_file("EaxRotations/classes/warrior/arms_sylvanas.lua")
    expect(#(arms.stubs or {}), 0, "arms_sylvanas has zero stubs")
    local dm = scan_file("EaxRotations/shared/dispel_manager_sylvanas.lua")
    expect(#(dm.stubs or {}), 0, "dispel_manager has zero stubs")

    -- The real committed allowlist must itself be duplicate-free (non-vacuity:
    -- the fixture above proves the detector fires; this proves the tree is
    -- clean today).
    check_own_allowlist(arg[0])

    -- Real-file probes: fields kept alive by CROSS_FILE_READS consumers must
    -- STAY written (pins the restore so a future cleanup pass can't re-remove
    -- them — the shared helpers read them through the real state).
    local function writes_of(path)
        local r = scan_file(path)
        local ws = {}
        for _, w in ipairs(r.writes) do ws[w.field] = true end
        return ws
    end
    local aff = writes_of("EaxRotations/classes/warlock/affliction_sylvanas.lua")
    expect(aff["healthstone_ready"], true, "affliction healthstone_ready kept (warlock_healthstone:62)")
    local demo = writes_of("EaxRotations/classes/warlock/demonology_sylvanas.lua")
    expect(demo["agony_remains"], true, "demonology agony_remains kept (curse_helper:22)")
    expect(demo["weakness_remains"], true, "demonology weakness_remains kept (curse_helper:28)")
    local dest = writes_of("EaxRotations/classes/warlock/destruction_sylvanas.lua")
    expect(dest["mana_gem_ready"], true, "destruction mana_gem_ready kept (mana_gem:26)")
    expect(dest["healthstone_id"], true, "destruction healthstone_id kept (healthstone:99)")
    local prot = writes_of("EaxRotations/classes/warrior/protection_sylvanas.lua")
    expect(prot["execute_ready"], true, "protection execute_ready kept (stance_manager:145)")
    local resto = writes_of("EaxRotations/classes/shaman/restoration_sylvanas.lua")
    expect(resto["mana_low"], true, "restoration mana_low kept (heal_scan regression:189)")
    expect(resto["entries"], true, "restoration entries kept (preemptive_heal:285)")

    -- ----------------------------------------------------------------------
    -- S3 fixtures: column-0 dead require (the discarded-module shape S2 skips
    -- by design — column-0 module constants are out of the stub family).
    -- ----------------------------------------------------------------------
    local s3 = scan_content(
        "local Foo = require(\"shared/foo\")\n"
        .. "local Bar = require(\"shared/bar\")\n"
        .. "local function f()\n"
        .. "    return Bar.thing\n"
        .. "end\n")
    local s3_kinds = {}
    for _, s in ipairs(s3.stubs or {}) do
        s3_kinds[#s3_kinds + 1] = s.kind .. ":" .. tostring(s.name or "")
    end
    table.sort(s3_kinds)
    expect(#s3_kinds, 1, "S3: exactly one dead require flagged")
    expect(s3_kinds[1], "dead_require:Foo", "S3: the unreferenced require is Foo")
    -- S3 pcall form: `local _, X = pcall(require, ...)` with X unused.
    local s3b = scan_content(
        "local _ok, Mod = pcall(require, \"shared/mod\")\n"
        .. "local _ok2, Used = pcall(require, \"shared/used\")\n"
        .. "local function g()\n"
        .. "    return Used.x\n"
        .. "end\n")
    local s3b_kinds = {}
    for _, s in ipairs(s3b.stubs or {}) do
        s3b_kinds[#s3b_kinds + 1] = s.kind .. ":" .. tostring(s.name or "")
    end
    expect(#s3b_kinds, 1, "S3: pcall dead require flagged")
    expect(s3b_kinds[1], "dead_require:Mod", "S3: the unused pcall binding is Mod")

    -- ----------------------------------------------------------------------
    -- S4 fixtures: dead exports. Synthetic in-memory pools; every resolver
    -- rule gets a positive and its live counterpart.
    -- ----------------------------------------------------------------------
    local function mock_pool(files)
        local pool = {}
        for path, content in pairs(files) do
            pool[path] = strip_comments(content)
        end
        return pool
    end
    -- F1: dead export fires; live export (via a consumer binding) stays clean.
    local pool1 = mock_pool({
        ["EaxRotations/shared/m1.lua"] =
            "local M = {}\n"
            .. "function M.dead_fn()\n"
            .. "end\n"
            .. "function M.live_fn()\n"
            .. "end\n"
            .. "return M\n",
        ["EaxRotations/classes/warrior/consumer.lua"] =
            "local M1 = require(\"shared/m1\")\n"
            .. "local x = M1.live_fn()\n",
    })
    local dead1 = run_export_scan_from_pool(pool1)
    expect(#dead1, 1, "S4: exactly one dead export (F1)")
    expect(dead1[1].member, "dead_fn", "S4: dead export name (F1)")
    expect(dead1[1].path, "EaxRotations/shared/m1.lua", "S4: dead export file (F1)")
    -- F2: string-index `B["member"]` is a reference.
    local pool2 = mock_pool({
        ["EaxRotations/shared/m2.lua"] =
            "local M = {}\n"
            .. "M.si = function() end\n"
            .. "M.never = function() end\n"
            .. "return M\n",
        ["EaxRotations/classes/warrior/consumer2.lua"] =
            "local M2 = require(\"shared/m2\")\n"
            .. "M2[\"si\"]()\n",
    })
    local dead2 = run_export_scan_from_pool(pool2)
    expect(#dead2, 1, "S4: string-index keeps si, flags never (F2)")
    expect(dead2[1].member, "never", "S4: string-index member is live (F2)")
    -- F3: NS-alias self-install (`NS.SpellCorpus = M` inside the module)
    -- makes the alias a reference prefix.
    local pool3 = mock_pool({
        ["EaxRotations/shared/m3.lua"] =
            "local M = {}\n"
            .. "function M.use_me()\n"
            .. "end\n"
            .. "function M.unused()\n"
            .. "end\n"
            .. "NS.SpellCorpus = M\n"
            .. "return M\n",
        ["EaxRotations/classes/warrior/consumer3.lua"] =
            "local S = require(\"shared/m3\")\n"
            .. "local x = NS.SpellCorpus.use_me()\n",
    })
    local dead3 = run_export_scan_from_pool(pool3)
    expect(#dead3, 1, "S4: NS-alias keeps use_me, flags unused (F3)")
    expect(dead3[1].member, "unused", "S4: only unused flagged under NS alias (F3)")
    -- F4: pairs() iteration over a module's binding is dynamic consumption ->
    -- the whole module is skipped (members not statically resolvable).
    local pool4 = mock_pool({
        ["EaxRotations/shared/m4.lua"] =
            "local M = {}\n"
            .. "function M.a() end\n"
            .. "function M.b() end\n"
            .. "return M\n",
        ["EaxRotations/classes/warrior/consumer4.lua"] =
            "local M4 = require(\"shared/m4\")\n"
            .. "for k, v in pairs(M4) do print(k) end\n",
    })
    expect(#(run_export_scan_from_pool(pool4)), 0,
        "S4: pairs iteration skips the module (F4)")
    -- F5: literal-return module (`return { ... }`) — defs not subtracted (no
    -- self-binding prefix in the census), dead members still flagged.
    local pool5 = mock_pool({
        ["EaxRotations/shared/m5.lua"] =
            "return {\n"
            .. "    live = function() end,\n"
            .. "    ghost = 1,\n"
            .. "}\n",
        ["EaxRotations/classes/warrior/consumer5.lua"] =
            "local M5 = require(\"shared/m5\")\n"
            .. "local x = M5.live()\n",
    })
    local dead5 = run_export_scan_from_pool(pool5)
    expect(#dead5, 1, "S4: literal-return module flags ghost (F5)")
    expect(dead5[1].member, "ghost", "S4: literal-return dead name (F5)")
    -- F6: `==` is a READ, not a definition — a compared member stays live.
    local pool6 = mock_pool({
        ["EaxRotations/shared/m6.lua"] =
            "local M = {}\n"
            .. "M.x = 1\n"
            .. "M.y = 1\n"
            .. "return M\n",
        ["EaxRotations/classes/warrior/consumer6.lua"] =
            "local M6 = require(\"shared/m6\")\n"
            .. "if M6.x == 1 then print('eq') end\n",
    })
    local dead6 = run_export_scan_from_pool(pool6)
    expect(#dead6, 1, "S4: `==` guard keeps x, flags y (F6)")
    expect(dead6[1].member, "y", "S4: `==` guard member (F6)")
    -- F7: leading-underscore members are private, never exports.
    local pool7 = mock_pool({
        ["EaxRotations/shared/m7.lua"] =
            "local M = {}\n"
            .. "function M._priv() end\n"
            .. "function M.dead() end\n"
            .. "return M\n",
        ["EaxRotations/classes/warrior/consumer7.lua"] =
            "local M7 = require(\"shared/m7\")\n",
    })
    local dead7 = run_export_scan_from_pool(pool7)
    expect(#dead7, 1, "S4: leading-underscore private out of scope (F7)")
    expect(dead7[1].member, "dead", "S4: _priv excluded, dead flagged (F7)")
    -- F8: bare require (side-effect load, no binding) skips the module.
    local pool8 = mock_pool({
        ["EaxRotations/shared/m8.lua"] =
            "local M = {}\n"
            .. "function M.effect() end\n"
            .. "return M\n",
        ["EaxRotations/classes/warrior/consumer8.lua"] =
            "require(\"shared/m8\")\n",
    })
    expect(#(run_export_scan_from_pool(pool8)), 0,
        "S4: bare require skips the module (F8)")
    -- F9: a mid-file `return {` inside a function must NOT hijack a
    -- named-table module (the earlier ret_name hijack regression).
    local pool9 = mock_pool({
        ["EaxRotations/shared/m9.lua"] =
            "local M = {}\n"
            .. "local function helper()\n"
            .. "    return { internal = 1 }\n"
            .. "end\n"
            .. "function M.real() end\n"
            .. "return M\n",
        ["EaxRotations/classes/warrior/consumer9.lua"] =
            "local M9 = require(\"shared/m9\")\n"
            .. "local x = M9.real()\n",
    })
    expect(#(run_export_scan_from_pool(pool9)), 0,
        "S4: mid-file literal return does not hijack (F9)")
    -- F10: colon calls (`B:method()`) and colon defs (`function M:method(`)
    -- keep the member live; a colon-defined member with zero calls flags dead.
    -- This pins the 2026-08-11 sweep's colon-blindness bug (the census missed
    -- `spell_queue:queue_spell_position` and wrongly removed it).
    local pool10 = mock_pool({
        ["EaxRotations/shared/m10.lua"] =
            "local M = {}\n"
            .. "function M:method() end\n"
            .. "function M:uncalled() end\n"
            .. "return M\n",
        ["EaxRotations/classes/warrior/consumer10.lua"] =
            "local M10 = require(\"shared/m10\")\n"
            .. "M10:method()\n",
    })
    local dead10 = run_export_scan_from_pool(pool10)
    expect(#dead10, 1, "S4: colon call keeps method, flags uncalled (F10)")
    expect(dead10[1].member, "uncalled", "S4: colon-defined dead member (F10)")

    -- Real-file probe: the tree must be clean today (the 2026-08-11 sweep
    -- removed the 94 dead exports; test-pinned members count as references
    -- because tests are in the pool; the core_sylvanas NS surface is
    -- deliberately out of S4 scope).
    expect(#(run_export_scan()), 0, "S4: zero dead exports in the real tree")

    print("[PASS] State-field audit self-tests: dead detection, param-agnostic "
        .. "dot reads, `==` non-write, comment + schema-bare-key exclusion, "
        .. "declarative (state/in_combat/hp_threshold) reads, double-write, "
        .. "compound write+read, leading-underscore + module-export scope, "
        .. "s-named state, stub rules (empty if-body multi-line + inline, "
        .. "dead local with word-boundary, live-if/live-local negatives, "
        .. "real-file probes arms/dispel_manager zero stubs), real-file "
        .. "probes (shadow/frost dead, fury live), S3 dead-require (named + "
        .. "pcall forms), S4 dead-export (dead/live, string-index, NS-alias "
        .. "self-install, pairs-iteration skip, literal-return, `==` guard, "
        .. "leading-underscore private, bare-require skip, mid-file return "
        .. "hijack, zero-dead real-tree probe)")
    os.exit(0)
end

-- ---------------------------------------------------------------------------
-- CLI
-- ---------------------------------------------------------------------------
if arg and arg[1] == "--self-test" then
    run_self_tests()
end

local scan = run_scan()

print("=============================================================================")
print("  STATE-FIELD AUDIT (computed-but-unread fields + never-completed stubs)")
print("=============================================================================")
local failures = {}
local clean = 0
for _, entry in ipairs(scan.results) do
    local res = entry.res
    if not res.skipped and #res.writes > 0 then
        local dead = dead_fields(res)
        if #dead == 0 then
            clean = clean + 1
        else
            for _, d in ipairs(dead) do
                if allowlisted(res.file, d.field) then
                    clean = clean + 0 -- allowlisted findings are reported, not failures
                else
                    failures[#failures + 1] = { file = res.file, line = d.line,
                                                field = d.field, writes = d.writes }
                end
            end
        end
    end
end
-- Stub violations are collected across EVERY scanned file (a stub can exist
-- in a file with no state writes at all), independent of the field rules.
local stub_failures = {}
for _, entry in ipairs(scan.results) do
    local res = entry.res
    if not res.skipped and res.stubs and #res.stubs > 0 then
        for _, s in ipairs(res.stubs) do
            stub_failures[#stub_failures + 1] = { file = res.file, line = s.line,
                                                  kind = s.kind, name = s.name }
        end
    end
end
print(string.format("  Total:     %d state-bearing files (%d field writes)",
    scan.total_files, scan.total_fields))
print(string.format("  Clean:     %d files with zero dead fields", clean))
print(string.format("  Invalid:   %d dead fields, %d stub violations",
    #failures, #stub_failures))
print("=============================================================================")

if #failures > 0 then
    print("  State fields written but read by nothing (file-local):")
    for _, f in ipairs(failures) do
        print(string.format("    %s  line %d: %s  (%d write site%s)",
            f.file, f.line, f.field, f.writes, (f.writes == 1 and "" or "s")))
    end
    print("")
    print("  Fix: remove the dead field (write line + its schema key + init")
    print("  key). If a finding is a false positive — a verified cross-file or")
    print("  test-only read — pin it in CROSS_FILE_READS with the evidence")
    print("  (file:line of the reader) rather than suppressing the finding.")
    os.exit(1)
end

if #stub_failures > 0 then
    print("  Never-completed stubs (empty if-body / dead local / dead require):")
    for _, s in ipairs(stub_failures) do
        print(string.format("    %s  line %d: %s %s", s.file, s.line, s.kind, s.name or ""))
    end
    print("")
    print("  Fix: remove the dead stub (and its discarded local). If the block")
    print("  documents an intent, implement it or delete the comment — an empty")
    print("  body is never the intended computation.")
    os.exit(1)
end

-- S4 export scan (the require-side dead-export rule). Runs after the state
-- field/stub sections: verify_all parses the FIRST `Invalid: %d` line, which
-- remains the state-field count above, and the gate checks the exit code.
local export_failures = run_export_scan()
print(string.format("  Dead exports: %d (shared module members referenced by no pool file)",
    #export_failures))
if #export_failures > 0 then
    print("=============================================================================")
    print("  Shared-module exports referenced by nothing in the pool:")
    for _, d in ipairs(export_failures) do
        print(string.format("    %s  %s", d.path, d.member))
    end
    print("")
    print("  Fix: remove the dead export (its definition and comment block). If")
    print("  it is referenced outside the pool (docs, an untracked consumer),")
    print("  pin it with evidence — never silently exempt it.")
    os.exit(1)
end

check_own_allowlist(arg[0])

print("  Every written state field is read somewhere; no empty if-bodies,")
print("  dead locals, dead requires, or dead shared-module exports.")
os.exit(0)
