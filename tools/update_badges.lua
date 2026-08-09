-- update_badges.lua -- sync test-count badges with runner reality
-- WHAT: counts the suite list each runner ACTUALLY executes (the `tests = { ... }`
--       table whose length the runner reports as its Total), then rewrites the
--       README.md tests badge + suite totals, AGENTS.md (when present) and
--       docs/PVP_FEATURE_PAGE.md totals AND runtime-passing clauses.
-- WHEN:  badge counts in README/AGENTS/PVP drift from the runner suite lists
-- WHY:   the old whole-file scan also counted quoted .lua strings OUTSIDE the
--        suite list (package.path patterns, the runner's file_exists path, the
--        manifest_only_test variable) -- it over-claimed by 3 rotation and 2
--        leveling suites (473 vs 470, 33 vs 31). The rotation list also executes
--        its 3 check_*.lua static-analysis audits AS suites, so they are part of
--        the 470 rotation total. The "N/N passing" claim is enforced by the
--        pre-commit rotation-suite step and verify_all, which assert every listed
--        suite passes -- this tool owns the count, the gate owns the pass.
-- USAGE: lua tools/update_badges.lua [--check]

local ROOT = arg and arg[0] and arg[0]:match('^(.*)[\\/]tools[\\/]') or '.'
if ROOT == '' then ROOT = '.' end
local CHECK_ONLY = false
for i = 1, (arg and #arg or 0) do if arg[i] == '--check' then CHECK_ONLY = true end end

local function read_file(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local s = f:read('*a'); f:close(); return s
end
local function write_file(path, content)
    local f = io.open(path, 'wb')
    if not f then return false end
    f:write(content); f:close(); return true
end

local function count_tests_in_runner(path)
    local content = read_file(path)
    if not content then return nil, 'missing: ' .. path end
    local count = 0
    local inside = false
    for line in content:gmatch('([^\r\n]*)\r?\n?') do
        local trimmed = line:gsub('^%s+', '')
        -- NOTE: this inside-table scan is duplicated in tools/spec_scorecard.lua
        -- (all_test_names). If you change the toggle here, mirror it there so the
        -- badge and scorecard registry counts cannot silently diverge.
        if not inside and (trimmed:match('^local tests = {') or trimmed:match('^local test_files = {')) then
            inside = true
        end
        if inside and trimmed == '}' then
            inside = false
        end
        if inside and not trimmed:match('^%-%-') then
            -- Only quoted .lua entries inside the suite table -- the exact set
            -- the runner executes (#tests). Comments are skipped so a quoted
            -- filename inside a comment cannot inflate the count.
            for _ in trimmed:gmatch('"([^"]+%.lua)"') do count = count + 1 end
        end
    end
    return count
end

local function replace_once(s, pat, repl)
    local new, n = s:gsub(pat, repl, 1)
    return new, n > 0
end

local function apply_substitutions(text, rot, lvl, tot)
    local changes = {}
    local function tally(lbl, chg) if chg then changes[#changes + 1] = lbl end end
    local R, L, T = tostring(rot), tostring(lvl), tostring(tot)
    local new, ok

    -- Accept both '%20passing' (current README form) and '-passing' (legacy
    -- hand-edit) so a URL-encoding change cannot silently freeze the badge
    -- again. %20 is three characters, so it needs its own literal, not a
    -- single-char class.
    -- In the gsub REPLACEMENT, '%%20' is the literal '%20' (a bare '%' would be
    -- read as a capture reference like %2). '%%2F' is the literal '%2F'.
    new, ok = replace_once(text, 'tests%-%d+%%2F%d+%%20passing',
        'tests-' .. R .. '%%2F' .. R .. '%%20passing')
    text = new; if ok then tally('README badge URL', ok) end
    new, ok = replace_once(text, 'tests%-%d+%%2F%d+%-passing',
        'tests-' .. R .. '%%2F' .. R .. '%%20passing')
    text = new; if ok then tally('README badge URL', ok) end

    -- No trailing quote in the pattern: the alt keeps its parenthetical, e.g.
    -- '467/467 Tests Passing (rotation suite fully green)'.
    new, ok = replace_once(text, 'alt="%d+/%d+ Tests Passing',
        'alt="' .. R .. '/' .. R .. ' Tests Passing')
    text = new; tally('README badge alt', ok)

    new, ok = replace_once(text, '(%d+) regression test suites',
        function() return R .. ' regression test suites' end)
    text = new; tally('README regression suites', ok)

    new, ok = replace_once(text, '(%d+) rotation suites',
        function() return R .. ' rotation suites' end)
    text = new; tally('README rotation suites', ok)

    new, ok = replace_once(text, 'regression suite %(%*%*(%d+) suites%*%*%)',
        function() return 'regression suite (**' .. R .. ' suites**)' end)
    text = new; tally('README regression **suites**', ok)

    new, ok = replace_once(text, 'leveling test suite %(%*%*(%d+) suites%*%*%)',
        function() return 'leveling test suite (**' .. L .. ' suites**)' end)
    text = new; tally('README leveling **suites**', ok)

    new, ok = replace_once(text, '(%d+) Regression Tests',
        function() return R .. ' Regression Tests' end)
    text = new; tally('README Regression Tests', ok)

    new, ok = replace_once(text, '(%d+) leveling suites',
        function() return L .. ' leveling suites' end)
    text = new; tally('README leveling suites', ok)

    -- README structure line: 'N test suites (R rotation + L leveling)'
    new, ok = replace_once(text, '(%d+) test suites %((%d+) rotation %+ (%d+) leveling%)',
        function() return T .. ' test suites (' .. R .. ' rotation + ' .. L .. ' leveling)' end)
    text = new; tally('README structure suites', ok)

    -- README features row: '**N Test Suites** | R rotation + L leveling registered; ...'
    new, ok = replace_once(text, '%*%*(%d+) Test Suites%*%*',
        function() return '**' .. T .. ' Test Suites**' end)
    text = new; tally('README features Test Suites', ok)

    new, ok = replace_once(text, '(%d+) rotation %+ (%d+) leveling registered',
        function() return R .. ' rotation + ' .. L .. ' leveling registered' end)
    text = new; tally('README features registered', ok)

    -- Runtime-passing clauses. Two-number form (PVP '467/467 rotation passing')
    -- MUST run before the one-number form ('467 rotation passing') so the
    -- second pattern cannot half-replace the two-number text.
    new, ok = replace_once(text, '(%d+)/(%d+) rotation passing at runtime',
        function() return R .. '/' .. R .. ' rotation passing at runtime' end)
    text = new; tally('PVP rotation passing runtime', ok)

    new, ok = replace_once(text, '(%d+) rotation passing at runtime',
        function() return R .. ' rotation passing at runtime' end)
    text = new; tally('README rotation passing runtime', ok)

    new, ok = replace_once(text, '(%d+) rotation suites registered',
        function() return R .. ' rotation suites registered' end)
    text = new; tally('AGENTS rotation registered', ok)

    new, ok = replace_once(text, '(%d+) leveling suites in `run_leveling_tests%.lua`',
        function() return L .. ' leveling suites in `run_leveling_tests.lua`' end)
    text = new; tally('AGENTS leveling registered', ok)

    new, ok = replace_once(text, '%((%d+) total%)',
        function() return '(' .. T .. ' total)' end)
    text = new; tally('AGENTS (total)', ok)

    new, ok = replace_once(text, 'all (%d+) rotation suites must pass',
        function() return 'all ' .. R .. ' rotation suites must pass' end)
    text = new; tally('AGENTS testing-rules rotation', ok)

    new, ok = replace_once(text, 'all (%d+) leveling suites must pass',
        function() return 'all ' .. L .. ' leveling suites must pass' end)
    text = new; tally('AGENTS testing-rules leveling', ok)

    return text, changes
end

local rotation_runner = ROOT .. '/EaxRotations/tests/run_rotation_tests.lua'
local leveling_runner = ROOT .. '/EaxRotations/tests/run_leveling_tests.lua'

local rot_count, err1 = count_tests_in_runner(rotation_runner)
local lvl_count, err2 = count_tests_in_runner(leveling_runner)

if not rot_count then
    io.stderr:write('update_badges: cannot count rotation tests: ' .. tostring(err1) .. '\n')
    os.exit(3)
end
if not lvl_count then
    io.stderr:write('update_badges: cannot count leveling tests: ' .. tostring(err2) .. '\n')
    os.exit(3)
end

local total = rot_count + lvl_count
print(string.format('update_badges: rotation=%d  leveling=%d  total=%d',
    rot_count, lvl_count, total))

local readme_path = ROOT .. '/EaxRotations/README.md'
local agents_path = ROOT .. '/AGENTS.md'
local pvp_path = ROOT .. '/EaxRotations/docs/PVP_FEATURE_PAGE.md'

local readme_old = read_file(readme_path)
local agents_old = read_file(agents_path)
local pvp_old = read_file(pvp_path)
if not readme_old then
    io.stderr:write('update_badges: missing ' .. readme_path .. '\n'); os.exit(3)
end
-- AGENTS.md is documented local-only (untracked); its badge section is
-- checked when present and skipped with a note when absent, so CI can run
-- this gate without requiring AGENTS.md to be committed.
if not agents_old then
    print('update_badges: note - AGENTS.md absent (local-only); skipping its badge section')
    agents_old = ''
end
if not pvp_old then
    io.stderr:write('update_badges: missing ' .. pvp_path .. '\n'); os.exit(3)
end

local readme_new, readme_changes = apply_substitutions(readme_old, rot_count, lvl_count, total)
local agents_new, agents_changes = apply_substitutions(agents_old, rot_count, lvl_count, total)
local pvp_new, pvp_changes = apply_substitutions(pvp_old, rot_count, lvl_count, total)

local readme_drift = (readme_new ~= readme_old)
local agents_drift = (agents_new ~= agents_old)
local pvp_drift = (pvp_new ~= pvp_old)

if CHECK_ONLY then
    if readme_drift or agents_drift or pvp_drift then
        io.stderr:write('\nERROR: test-count drift detected.\n')
        if readme_drift then
            io.stderr:write('  EaxRotations/README.md is stale:\n')
            for _, c in ipairs(readme_changes) do io.stderr:write('    - ' .. c .. '\n') end
        end
        if agents_drift then
            io.stderr:write('  AGENTS.md is stale:\n')
            for _, c in ipairs(agents_changes) do io.stderr:write('    - ' .. c .. '\n') end
        end
        if pvp_drift then
            io.stderr:write('  EaxRotations/docs/PVP_FEATURE_PAGE.md is stale:\n')
            for _, c in ipairs(pvp_changes) do io.stderr:write('    - ' .. c .. '\n') end
        end
        io.stderr:write('  Fix: lua tools/update_badges.lua && commit the diff.\n')
        os.exit(2)
    end
    print('update_badges: badges in sync (no drift)')
    os.exit(0)
end

if readme_drift then
    if write_file(readme_path, readme_new) then
        print('  wrote ' .. readme_path)
        for _, c in ipairs(readme_changes) do print('    - ' .. c) end
    end
end
if agents_drift and agents_old ~= '' then
    if write_file(agents_path, agents_new) then
        print('  wrote ' .. agents_path)
        for _, c in ipairs(agents_changes) do print('    - ' .. c) end
end
end
if pvp_drift then
    if write_file(pvp_path, pvp_new) then
        print('  wrote ' .. pvp_path)
        for _, c in ipairs(pvp_changes) do print('    - ' .. c) end
    end
end
if not readme_drift and not agents_drift and not pvp_drift then
    print('  no changes (already in sync)')
end
