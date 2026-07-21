-- update_badges.lua -- sync test-count badges with runner reality
-- WHAT: counts quoted .lua entries in runners, rewrites README.md + AGENTS.md
-- WHEN:  badge counts in README/AGENTS drift from the actual runner lists
-- WHY:   runner treats any registered .lua entry as a suite (including check_*.lua audits)
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
    for line in content:gmatch('([^\r\n]*)\r?\n?') do
        local trimmed = line:gsub('^%s+', '')
        if not trimmed:match('^%-%-') then
            -- Count any quoted .lua entry in the runner (includes check_*.lua static-analysis suites).
            -- Note: %.lua is a Lua pattern escape for the literal dot; no backslash is involved.
            for _ in trimmed:gmatch('"[^"]+%.lua"') do count = count + 1 end
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

    new, ok = replace_once(text, 'tests%-%d+%%2F%d+%-passing',
        'tests-' .. R .. '%%2F' .. R .. '-passing')
    text = new; tally('README badge URL', ok)

    new, ok = replace_once(text, 'alt="%d+/%d+ Tests Passing"',
        'alt="' .. R .. '/' .. R .. ' Tests Passing"')
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

local readme_old = read_file(readme_path)
local agents_old = read_file(agents_path)
if not readme_old then
    io.stderr:write('update_badges: missing ' .. readme_path .. '\n'); os.exit(3)
end
if not agents_old then
    io.stderr:write('update_badges: missing ' .. agents_path .. '\n'); os.exit(3)
end

local readme_new, readme_changes = apply_substitutions(readme_old, rot_count, lvl_count, total)
local agents_new, agents_changes = apply_substitutions(agents_old, rot_count, lvl_count, total)

local readme_drift = (readme_new ~= readme_old)
local agents_drift = (agents_new ~= agents_old)

if CHECK_ONLY then
    if readme_drift or agents_drift then
        io.stderr:write('\nERROR: test-count drift detected.\n')
        if readme_drift then
            io.stderr:write('  EaxRotations/README.md is stale:\n')
            for _, c in ipairs(readme_changes) do io.stderr:write('    - ' .. c .. '\n') end
        end
        if agents_drift then
            io.stderr:write('  AGENTS.md is stale:\n')
            for _, c in ipairs(agents_changes) do io.stderr:write('    - ' .. c .. '\n') end
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
if agents_drift then
    if write_file(agents_path, agents_new) then
        print('  wrote ' .. agents_path)
        for _, c in ipairs(agents_changes) do print('    - ' .. c) end
    end
end
if not readme_drift and not agents_drift then
    print('  no changes (already in sync)')
end
