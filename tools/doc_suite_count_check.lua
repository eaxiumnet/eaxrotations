-- tools/doc_suite_count_check.lua -- the doc suite-count drift gate.
--
-- WHAT:  Every test-suite count mentioned in a *current-state* doc must equal the
--        count the runners actually execute (the `tests = { ... }` table length the
--        runner reports as its Total): rotation / leveling / total. Three things
--        FAIL: a classified mention whose number disagrees, a count-shaped mention
--        that is not classified at all (a brand-new phrasing), and a change in how
--        many mentions a doc carries (the per-file inventory pin).
-- WHEN:  tools/pre-commit step 4 (right next to tools/update_badges.lua --check,
--        whose blind spot is the reason this gate exists) and
--        tests/run_verify_all.lua, so a wrong hand-typed count cannot reach master.
-- WHY:   The 2026-09-13 delivery bumped the suite count with hand edits and left two
--        stale 563s behind: README.md:18 ("563-suite release battery" -- a phrasing
--        update_badges' substitution list did not know about) and docs/ACCURACY.md:205
--        (a hardcoded literal in its generator, since derived from the registry).
--        update_badges REPAIRS the badge-shaped counts it knows and stays the repair
--        tool; this gate FAILS CLOSED on every count-shaped mention in the docs,
--        including phrasings nobody has written yet -- an unrecognized mention is a
--        failure, not a free pass, so a new count has to be classified (and thereby
--        compared) before it can land. That is the property "the count can never be
--        hand-typed wrong again" needs; a substitution list alone cannot have it.
-- SCOPE: Current-state docs: EaxRotations/{README,CONTRIBUTING,LICENSE,
--        scorecard_data}.md and EaxRotations/{docs,tools}/*.md whose filename does
--        not carry a date. Dated snapshots (`*_YYYY-MM-DD.md`: the never-triage
--        reports, the sweep/audit reports) and the explicitly listed historical
--        docs record a past moment and are exempt; a line that marks its own counts
--        as of the past with HISTORICAL_MARKERS is exempt too, and the number of
--        exempt mentions per file is pinned, so the exemption cannot be sprinkled
--        on to hide a live count. CHANGELOG.md is the release log: each entry states
--        its own release's counts by definition.
-- SAFETY: Read-only. Reads the two runner files + the docs, shells out to
--        `git ls-files` to enumerate the tracked docs (the run_clean_checkout_probe
--        idiom). Never writes and never repairs.
-- USAGE:
--   lua tools/doc_suite_count_check.lua              # check (read-only)
--   lua tools/doc_suite_count_check.lua --check      # same, accepted for symmetry
--   lua tools/doc_suite_count_check.lua --self-test  # synthetic fixtures
-- EXIT:  0 = every mention agrees; 1 = drift / unclassified / inventory change;
--        3 = cannot read the runners or enumerate the docs.

-- ROOT is the checkout root (the directory above tools/). The separator is
-- built with string.char(92), so this source carries no backslash escape.
local SELF_PATH = (arg and arg[0] or ''):gsub(string.char(92), '/')
local ROOT = SELF_PATH:match('^(.*)/tools/[^/]*$') or '.'
if ROOT == '' then ROOT = '.' end

local SELFTEST = false
for i = 1, (arg and #arg or 0) do
    local a = arg[i]
    if a == '--self-test' then
        SELFTEST = true
    elseif a == '--check' then -- accepted: this tool is read-only by construction
        -- no-op
    else
        io.stderr:write('doc_suite_count_check: unknown argument: ' .. tostring(a) .. '\n')
        os.exit(3)
    end
end

-- ---------------------------------------------------------------------------
-- Runner suite counts (rotation / leveling), the single source of truth the docs
-- are compared against. Read the same way the runners' own totals are produced.
--
-- NOTE: this inside-table quoted-.lua scan is duplicated in
-- tools/update_badges.lua (count_tests_in_runner) and tools/spec_scorecard.lua
-- (all_test_names), which say the same thing to each other. If the toggle changes
-- there, mirror it here too, or this gate would compare the docs against a count
-- the badge/scorecard writers no longer agree with.
-- ---------------------------------------------------------------------------
local function count_tests_in_runner(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local content = f:read('*a')
    f:close()
    local count = 0
    local inside = false
    for line in content:gmatch('([^\r\n]*)\r?\n?') do
        local trimmed = line:gsub('^%s+', '')
        if not inside and (trimmed:match('^local tests = {') or trimmed:match('^local test_files = {')) then
            inside = true
        end
        if inside and trimmed == '}' then
            inside = false
        end
        if inside and not trimmed:match('^%-%-') then
            for _ in trimmed:gmatch('"([^"]+%.lua)"') do count = count + 1 end
        end
    end
    return count
end

-- ---------------------------------------------------------------------------
-- Counted mentions, classified once. Order matters: the context/pair forms run
-- before the generic ones, and a match consumes its own text so a later pattern
-- cannot re-read the same digits. `values` maps each capture, in order, to the
-- runner count it must equal ({ "rot" | "lvl" | "total" }).
--
-- To cover a new doc phrasing: anchor the sentence here (the digits alone are not
-- enough -- "603 suites" could mean rotation or total, so an unanchored mention is
-- a failure by design; see the residual scan).
-- ---------------------------------------------------------------------------
local CLASSIFIED_MENTIONS = {
    { label = 'badge URL',          pattern = 'tests%-(%d+)%%2F(%d+)%%20passing',       values = { 'rot', 'rot' } },
    { label = 'badge alt',          pattern = '(%d+)/(%d+) Tests Passing',              values = { 'rot', 'rot' } },
    { label = 'runtime pair',       pattern = '(%d+)/(%d+) rotation passing at runtime', values = { 'rot', 'rot' } },
    { label = 'suites pair',        pattern = '(%d+)/(%d+) suites',                    values = { 'rot', 'rot' } },
    { label = 'structure line',     pattern = '(%d+) test suites %((%d+) rotation %+ (%d+) leveling%)',
                                                                                        values = { 'total', 'rot', 'lvl' } },
    { label = 'features total',     pattern = '%*%*(%d+) Test Suites%*%*',              values = { 'total' } },
    { label = 'features registry',  pattern = '(%d+) rotation %+ (%d+) leveling registered',
                                                                                        values = { 'rot', 'lvl' } },
    { label = 'runtime single',     pattern = '(%d+) rotation passing at runtime',       values = { 'rot' } },
    { label = 'scorecard registry', pattern = 'rotation suites %(registry%) %| (%d+)',  values = { 'rot' } },
    { label = 'release battery',    pattern = '(%d+)%-suite',                            values = { 'rot' } },
    { label = 'rotation suites',    pattern = '(%d+) rotation suites',                   values = { 'rot' } },
    { label = 'leveling suites',    pattern = '(%d+) leveling suites',                   values = { 'lvl' } },
    { label = 'tests-dir registry', pattern = '`EaxRotations/tests/` %((%d+) suites%)',  values = { 'rot' } },
    { label = 'rotation set',       pattern = 'rotation regression suite %(%*%*(%d+) suites%*%*%)',
                                                                                        values = { 'rot' } },
    { label = 'leveling set',       pattern = 'leveling test suite %(%*%*(%d+) suites%*%*%)',
                                                                                        values = { 'lvl' } },
}

local FIELD_NAME = { rot = 'rotation', lvl = 'leveling', total = 'total' }

-- A line carrying one of these marks its own counts as a snapshot of a past
-- moment (the era the document was written in), so they are not compared -- but
-- they ARE counted, and the count is pinned per file.
local HISTORICAL_MARKERS = { 'at record time' }

-- Residual scan: a number still reads as a suite count when the suite wording
-- FOLLOWS it ("557 suites", "557-suite battery", "557/557 Tests Passing") or when it
-- sits in the badge path shape ("tests-557"). Two deliberate narrowings keep it from
-- crying wolf on prose that merely shares a line with a count: only the trailing
-- wording counts (a symmetric window flagged the "~2,500 decision rules" figures
-- beside "(563 suites)"), and a figure behind a comparison operator is a metric
-- ("never=0", "(d)>0"), not a count.
local RESIDUAL_AFTER = 18
local RESIDUAL_TOKENS = { 'suite', 'tests passing', 'passing at runtime' }
local RESIDUAL_OPERATORS = { '=', '<', '>', '+', '~', '&' }
local BADGE_DIGIT_PREFIX = 'tests-'

-- ---------------------------------------------------------------------------
-- Docs that describe the CURRENT build: every one must be listed here (and carry
-- a FILE_PINS entry), so a new doc cannot quietly escape the gate.
-- ---------------------------------------------------------------------------
local SCANNED_DOCS = {
    'EaxRotations/README.md',
    'EaxRotations/CONTRIBUTING.md',
    'EaxRotations/LICENSE.md',
    'EaxRotations/scorecard_data.md',
    'EaxRotations/docs/ACCURACY.md',
    'EaxRotations/docs/CONTRIBUTING.md',
    'EaxRotations/docs/DEBUGGING_TRACE_CASTS.md',
    'EaxRotations/docs/HEAL_RANK_FIT_VALIDATION.md',
    'EaxRotations/docs/PER_CLASS_RESEARCH.md',
    'EaxRotations/docs/PVP_FEATURE_PAGE.md',
    'EaxRotations/docs/SOD_ROTATIONS.md',
    'EaxRotations/docs/SPELL_COVERAGE_AUDIT.md',
    'EaxRotations/docs/TECHNICAL_GUIDE.md',
    'EaxRotations/docs/scorecard.md',
}

-- Docs that record a past moment on purpose. Each needs a reason, like every
-- other allowlist in this repo. Dated filenames (`*_YYYY-MM-DD.md`) are exempt by
-- pattern and do not need an entry.
local SKIP_DOCS = {
    ['EaxRotations/CHANGELOG.md'] =
        'release log: every entry states its own release-time counts by definition',
    ['EaxRotations/docs/API_ADOPTION_ANALYSIS.md'] =
        'analysis of an earlier port ("95 suites" is what the TBC API migration saw then)',
    ['EaxRotations/docs/README_Sylvanas_API_Edition.md'] =
        'README of the earlier API-edition variant ("208 suites"), not the shipped plugin',
    ['EaxRotations/docs/status_audit.md'] =
        'status-audit snapshot ("111/111") of the workspace it was taken in',
    ['EaxRotations/tools/buff_debuff_full_verification.md'] =
        'generated evidence artifact (id-audit report), regenerated by its tool',
    ['EaxRotations/tools/spell_id_sweep.md'] =
        'generated evidence artifact (spell-id sweep report), regenerated by its tool',
}

local DATED_DOC_PATTERN = '_[0-9][0-9][0-9][0-9]%-[0-9][0-9]%-[0-9][0-9]%.md$'

-- The non-vacuity pin: how many mentions each scanned doc carries. A PASS over
-- nothing is not evidence, and a doc that silently gains or loses a mention has
-- changed the surface this gate covers -- both fail until the pin is updated
-- deliberately. Kept in step with the docs line by line when they were classified.
local FILE_PINS = {
    ['EaxRotations/README.md']                     = { classified = 11, historical = 0 },
    ['EaxRotations/CONTRIBUTING.md']               = { classified = 0,  historical = 0 },
    ['EaxRotations/LICENSE.md']                    = { classified = 0,  historical = 0 },
    ['EaxRotations/scorecard_data.md']             = { classified = 0,  historical = 0 },
    ['EaxRotations/docs/ACCURACY.md']              = { classified = 2,  historical = 0 },
    ['EaxRotations/docs/CONTRIBUTING.md']          = { classified = 0,  historical = 0 },
    ['EaxRotations/docs/DEBUGGING_TRACE_CASTS.md'] = { classified = 0,  historical = 0 },
    ['EaxRotations/docs/HEAL_RANK_FIT_VALIDATION.md'] = { classified = 0,  historical = 0 },
    ['EaxRotations/docs/PER_CLASS_RESEARCH.md']    = { classified = 2,  historical = 1 },
    ['EaxRotations/docs/PVP_FEATURE_PAGE.md']      = { classified = 3,  historical = 0 },
    ['EaxRotations/docs/SOD_ROTATIONS.md']         = { classified = 0,  historical = 0 },
    ['EaxRotations/docs/SPELL_COVERAGE_AUDIT.md']  = { classified = 0,  historical = 0 },
    ['EaxRotations/docs/TECHNICAL_GUIDE.md']       = { classified = 0,  historical = 0 },
    ['EaxRotations/docs/scorecard.md']             = { classified = 2,  historical = 0 },
}

-- ---------------------------------------------------------------------------
-- Mention machinery (pure -- the self-test drives these directly).
-- ---------------------------------------------------------------------------

local function overlaps(consumed, s, e)
    for i = s, e do
        if consumed[i] then return true end
    end
    return false
end

-- Classify every known mention on one line. Marks the matched spans consumed so
-- overlapping patterns and the residual scan stay honest.
local function classify_line(line)
    local consumed, mentions = {}, {}
    for _, spec in ipairs(CLASSIFIED_MENTIONS) do
        local init = 1
        while true do
            local s, e, c1, c2, c3 = line:find(spec.pattern, init)
            if not s then break end
            init = e + 1
            if not overlaps(consumed, s, e) then
                for i = s, e do consumed[i] = true end
                mentions[#mentions + 1] = {
                    label = spec.label,
                    text = line:sub(s, e),
                    values = spec.values,
                    caps = { c1, c2, c3 },
                }
            end
        end
    end
    return mentions, consumed
end

-- Count-shaped numbers that no classified pattern claimed. This is what makes a
-- new phrasing fail instead of passing unchecked.
local function residual_mentions(line, consumed)
    local found = {}
    local init = 1
    while true do
        local s, e = line:find('%d+', init)
        if not s then break end
        init = e + 1
        if not overlaps(consumed, s, e) then
            local is_metric = false
            for _, op in ipairs(RESIDUAL_OPERATORS) do
                if line:sub(s - 1, s - 1) == op then is_metric = true end
            end
            if not is_metric then
                local after = line:sub(e + 1, e + RESIDUAL_AFTER):lower()
                local before = line:sub(math.max(1, s - #BADGE_DIGIT_PREFIX), s - 1):lower()
                local token = nil
                for _, candidate in ipairs(RESIDUAL_TOKENS) do
                    if after:find(candidate, 1, true) then
                        token = candidate
                        break
                    end
                end
                if not token and before == BADGE_DIGIT_PREFIX then token = BADGE_DIGIT_PREFIX end
                if token then
                    found[#found + 1] = { text = line:sub(s, e), token = token }
                end
            end
        end
    end
    return found
end

-- Compare one mention's captures against the runner counts. Returns a problem
-- description, or nil when every capture agrees.
local function verify_mention(mention, counts)
    local bad = {}
    for i = 1, #mention.values do
        local want = counts[mention.values[i]]
        local got = mention.caps[i] and tonumber(mention.caps[i]) or nil
        if got ~= want then
            bad[#bad + 1] = string.format('%s=%s (expected %d)',
                FIELD_NAME[mention.values[i]], mention.caps[i] or '?', want)
        end
    end
    if #bad == 0 then return nil end
    return table.concat(bad, ', ')
end

-- Tally one doc. `problems` carries { line = <n>, kind = <label>, message = <text> }.
local function tally_doc(text, counts)
    local classified, historical, problems = 0, 0, {}
    local lines = {}
    for raw in (text .. '\n'):gmatch('([^\n]*)\n') do
        lines[#lines + 1] = (raw:gsub('\r$', ''))
    end
    for line_no, line in ipairs(lines) do
        local mentions, consumed = classify_line(line)
        local is_historical = false
        local lower = line:lower()
        for _, marker in ipairs(HISTORICAL_MARKERS) do
            if lower:find(marker, 1, true) then is_historical = true end
        end
        if is_historical then
            historical = historical + #mentions
        else
            classified = classified + #mentions
            for _, mention in ipairs(mentions) do
                local bad = verify_mention(mention, counts)
                if bad then
                    problems[#problems + 1] = {
                        line = line_no, kind = 'wrong count',
                        message = string.format('"%s" (%s) -> %s', mention.text, mention.label, bad),
                    }
                end
            end
            for _, res in ipairs(residual_mentions(line, consumed)) do
                problems[#problems + 1] = {
                    line = line_no, kind = 'unclassified mention',
                    message = string.format(
                        '"%s" reads as a suite count but no classified pattern matches it '
                        .. '(nearest token: "%s") -- anchor the sentence in CLASSIFIED_MENTIONS',
                        res.text, res.token),
                }
            end
        end
    end
    return classified, historical, problems
end

-- ---------------------------------------------------------------------------
-- Self-test: synthetic fixtures proving each mechanism fires, and that the
-- comparison follows the injected counts rather than today's numbers.
-- ---------------------------------------------------------------------------
local function run_self_test()
    local checks, failures = 0, {}
    local R, L, T = 120, 7, 127
    local counts = { rot = R, lvl = L, total = T }

    local function case(name, fn)
        checks = checks + 1
        local ok, detail = pcall(fn)
        if not ok then
            failures[#failures + 1] = name .. ': ' .. tostring(detail)
            print('  !! ' .. name .. ': ' .. tostring(detail))
        else
            print('  ok ' .. name)
        end
    end

    local function expect(cond, detail)
        if not cond then error(detail or 'assertion failed', 2) end
    end

    case('a correct classified mention passes', function()
        local c, h, p = tally_doc('Every spec is verified by a **' .. R .. '-suite release battery**.', counts)
        expect(c == 1 and h == 0 and #p == 0, string.format('classified=%d historical=%d problems=%d', c, h, #p))
    end)

    case('a wrong classified count fails', function()
        local c, _, p = tally_doc('verified by a **' .. (R - 1) .. '-suite release battery**', counts)
        expect(c == 1 and #p == 1 and p[1].kind == 'wrong count', 'expected exactly one wrong-count problem')
    end)

    case('the structure line checks all three numbers', function()
        local c, _, p = tally_doc('tests/  # ' .. T .. ' test suites (' .. R .. ' rotation + ' .. L .. ' leveling)', counts)
        expect(c == 1 and #p == 0, string.format('classified=%d problems=%d', c, #p))
    end)

    case('a wrong number inside the structure line fails', function()
        local _, _, p = tally_doc('tests/  # ' .. T .. ' test suites (' .. R .. ' rotation + 9 leveling)', counts)
        expect(#p == 1 and p[1].kind == 'wrong count', 'expected one wrong-count problem')
    end)

    case('the registry pair classifies without residue', function()
        local _, _, p = tally_doc('Total: ' .. R .. ' rotation suites + ' .. L .. ' leveling suites registered', counts)
        expect(#p == 0, 'pair forms should leave no residue')
    end)

    case('an unclassified count-shaped mention fails', function()
        local c, _, p = tally_doc('the battery now runs ' .. (R + 1) .. ' suites', counts)
        expect(c == 0 and #p == 1 and p[1].kind == 'unclassified mention',
            string.format('classified=%d problems=%d', c, #p))
    end)

    case('a badge URL with a wrong number fails', function()
        local _, _, p = tally_doc('<img src="badge/tests-' .. (R + 1) .. '%2F' .. (R + 1) .. '%20passing">', counts)
        expect(#p == 1 and p[1].kind == 'wrong count', 'expected one wrong-count problem')
    end)

    case('a historical-marked line is exempt and counted, not compared', function()
        local c, h, p = tally_doc('*Gates at record time: 999/999 suites green.*', counts)
        expect(c == 0 and h == 1 and #p == 0, string.format('classified=%d historical=%d problems=%d', c, h, #p))
    end)

    case('an unclassified mention on a historical line is not gated', function()
        local _, h, p = tally_doc('*Gates at record time: 999 suites green.*', counts)
        expect(h == 0 and #p == 0, 'a historical line is fully exempt')
    end)

    case('the residual scan ignores unrelated counts', function()
        local _, _, p = tally_doc('ships **132 rated spec rotations** (31 TBC, 41 WotLK, 40 Vanilla, 20 SoD)', counts)
        expect(#p == 0, 'unrelated numbers must not be flagged')
    end)

    case('an unrelated figure beside a suite mention is not flagged', function()
        local _, _, p = tally_doc('| battery | ' .. R .. ' rotation suites | ~2,500 decision rules |', counts)
        expect(#p == 0, 'the 2,500 figures must not be read as counts')
    end)

    case('a metric comparison is not read as a count', function()
        local _, _, p = tally_doc('**F** (d)>0. Suite columns: class keyword match; never=0', counts)
        expect(#p == 0, 'a comparison figure must not be read as a count')
    end)

    case('a classified mention inside a longer sentence still passes', function()
        local _, _, p = tally_doc('Run the whole release gate yourself (' .. R .. ' rotation suites + leveling).', counts)
        expect(#p == 0, 'the rotation-suites form must be classified')
    end)

    case('the comparison follows the injected counts, not constants', function()
        local _, _, p = tally_doc('verified by a **' .. R .. '-suite release battery**', { rot = 999, lvl = 7, total = 1006 })
        expect(#p == 1 and p[1].kind == 'wrong count', 'a different counts table must flip the verdict')
    end)

    print(string.format('self-test: %d/%d checks passed', checks - #failures, checks))
    if #failures > 0 then
        io.stderr:write('doc_suite_count_check self-test FAILED (' .. #failures .. ')\n')
        os.exit(1)
    end
    print('[PASS] doc suite-count check self-tests: each classified form, the residual scan,\n'
        .. '  the historical exemption, and the injected-counts comparison.\n')
    os.exit(0)
end

if SELFTEST then run_self_test() end

-- ---------------------------------------------------------------------------
-- Check mode.
-- ---------------------------------------------------------------------------
local rotation_runner = ROOT .. '/EaxRotations/tests/run_rotation_tests.lua'
local leveling_runner = ROOT .. '/EaxRotations/tests/run_leveling_tests.lua'

local rot = count_tests_in_runner(rotation_runner)
local lvl = count_tests_in_runner(leveling_runner)
if not rot or not lvl then
    io.stderr:write('doc_suite_count_check: cannot read the runner suite lists ('
        .. tostring(rotation_runner) .. ' / ' .. tostring(leveling_runner) .. ')\n')
    os.exit(3)
end
local counts = { rot = rot, lvl = lvl, total = rot + lvl }
print(string.format('doc suite-count check: runner counts rotation=%d leveling=%d total=%d',
    rot, lvl, counts.total))

-- Enumerate the tracked docs in scope: EaxRotations/{,docs/,tools/}*.md.
local function enumerate_docs()
    local pipe = io.popen('git -C "' .. ROOT .. '" ls-files EaxRotations')
    if not pipe then return nil, 'io.popen failed' end
    local out = pipe:read('*a')
    pipe:close()
    local docs = {}
    for path in out:gmatch('[^\r\n]+') do
        if path:match('^EaxRotations/[^/]+%.md$')
            or path:match('^EaxRotations/docs/[^/]+%.md$')
            or path:match('^EaxRotations/tools/[^/]+%.md$') then
            docs[#docs + 1] = path
        end
    end
    table.sort(docs)
    return docs, nil
end

local docs, err = enumerate_docs()
if not docs or #docs == 0 then
    io.stderr:write('doc_suite_count_check: cannot enumerate tracked docs via git ls-files'
        .. (err and (' (' .. err .. ')') or '') .. '\n')
    os.exit(3)
end

local problems = {}
local function add_problem(file, line, kind, message)
    problems[#problems + 1] = { file = file, line = line, kind = kind, message = message }
end

local known, mentions_total, historical_total, scanned_total = {}, 0, 0, 0
for _, name in ipairs(SCANNED_DOCS) do known[name] = 'scanned' end
for name in pairs(SKIP_DOCS) do known[name] = 'skip' end

-- Every scanned doc must carry a pin, and every pin must point at a scanned doc
-- (a pin for a skipped doc would silently hide it).
for _, name in ipairs(SCANNED_DOCS) do
    if not FILE_PINS[name] then
        add_problem(name, 0, 'missing pin', 'scanned doc has no FILE_PINS entry')
    end
end
for name in pairs(FILE_PINS) do
    if known[name] ~= 'scanned' then
        add_problem(name, 0, 'stray pin', 'FILE_PINS entry is not in SCANNED_DOCS')
    end
end

for _, name in ipairs(docs) do
    local dated = name:match(DATED_DOC_PATTERN) ~= nil
    if not known[name] and not dated then
        add_problem(name, 0, 'unclassified doc',
            'tracked doc is neither in SCANNED_DOCS nor in SKIP_DOCS with a reason '
            .. '-- classify it so the gate covers it')
    elseif known[name] == 'scanned' then
        local f = io.open(ROOT .. '/' .. name, 'rb')
        if not f then
            add_problem(name, 0, 'unreadable', 'scanned doc missing from the working tree')
        else
            local text = f:read('*a')
            f:close()
            scanned_total = scanned_total + 1
            local classified, historical, doc_problems = tally_doc(text, counts)
            for _, p in ipairs(doc_problems) do
                add_problem(name, p.line, p.kind, p.message)
            end
            mentions_total = mentions_total + classified
            historical_total = historical_total + historical
            local pin = FILE_PINS[name]
            if pin and (pin.classified ~= classified or pin.historical ~= historical) then
                add_problem(name, 0, 'inventory changed', string.format(
                    'mention inventory changed (classified=%d historical=%d, pinned classified=%d historical=%d) '
                    .. '-- classify the new/changed mention, then update FILE_PINS',
                    classified, historical, pin.classified, pin.historical))
            end
            if classified + historical > 0 then
                print(string.format('  %s: %d mention(s)%s', name, classified,
                    historical > 0 and (' + ' .. historical .. ' historical') or ''))
            end
        end
    end
end

if #problems == 0 then
    print(string.format(
        'doc suite-count check: %d mention(s) verified across %d current-state doc(s)'
        .. ' (%d historical mention(s) exempt) -- in sync [PASS]',
        mentions_total, scanned_total, historical_total))
    os.exit(0)
end

io.stderr:write('\ndoc suite-count check: ' .. #problems .. ' problem(s)\n')
for _, p in ipairs(problems) do
    local where = (p.line and p.line > 0) and (p.file .. ':' .. p.line) or p.file
    io.stderr:write(string.format('  !! %s [%s] %s\n', where, p.kind, p.message))
end
io.stderr:write('  expected counts: rotation=' .. rot .. ' leveling=' .. lvl
    .. ' total=' .. counts.total .. '\n')
io.stderr:write('  Fix: correct the doc text (tools/update_badges.lua repairs the badge-shaped counts),\n')
io.stderr:write('  then classify any new phrasing in CLASSIFIED_MENTIONS and update FILE_PINS.\n')
os.exit(1)
