-- run_state_field_audit_tests.lua -- Static audit: no state-table field may be
-- WRITTEN in a class/shared file but READ by nothing.
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

    return { names = names, writes = writes, counts = counts }
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

    print("[PASS] State-field audit self-tests: dead detection, param-agnostic "
        .. "dot reads, `==` non-write, comment + schema-bare-key exclusion, "
        .. "declarative (state/in_combat/hp_threshold) reads, double-write, "
        .. "compound write+read, leading-underscore + module-export scope, "
        .. "s-named state, real-file probes (shadow/frost dead, fury live)")
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
print("  STATE-FIELD AUDIT (computed-but-unread state fields)")
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
print(string.format("  Total:     %d state-bearing files (%d field writes)",
    scan.total_files, scan.total_fields))
print(string.format("  Clean:     %d files with zero dead fields", clean))
print(string.format("  Invalid:   %d dead fields", #failures))
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

check_own_allowlist(arg[0])

print("  Every written state field is read somewhere.")
os.exit(0)
