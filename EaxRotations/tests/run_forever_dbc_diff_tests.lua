-- run_forever_dbc_diff_tests.lua — gate for the Forever DBC diff harness.
-- WHAT:  runs tools/forever_dbc_diff.py twice: --self-test (synthetic old/new
--        DBs in TEMP; every finding shape, lane mapping, exit contract) and
--        --check-fixtures (the committed tests/fixtures/forever_dbc pair
--        through the harness's real end-to-end path, including the
--        lane-impact scan over the actual classes/*/*_forever.lua
--        resolve_id call sites).
-- WHEN:  verify_all + the CI job (and standalone by hand).
-- WHY:   the harness is the launch-day guard for new beta builds: a
--        re-ranked or renamed row that silently changes a lane's spell must
--        fail a gate, not wait for someone to run the diff by hand. The
--        fixture pair is committed (32 KB each; regenerate with
--        `python tools/forever_dbc_diff.py --write-fixtures`) so the gate
--        needs no client extraction and no runtime generation step.
-- SAFETY: spawns the tracked python tool only (no network, no client, no
--         gitignored inputs); the fixture check writes its JSON report into
--         the OS temp dir.
-- NOTE:   named run_*.lua so the banned-API exemption applies — os.execute is
--         required to spawn the python tool, exactly like every other run_*
--         runner.
-- PYTHON: CI has python3; local runs probe python3 then python. With no
--         interpreter the gate prints an explicit SKIP marker and exits 0 —
--         the CI step is the fail-closed side, and the skip stays visible in
--         verify_all's per-assertion output, never silent.

local TOOL = "tools/forever_dbc_diff.py"

local function capture(cmd)
    local path = os.tmpname() or "forever_dbc_diff_gate.txt"
    os.remove(path)
    os.execute(cmd .. " > \"" .. path .. "\" 2>&1")
    local f = io.open(path, "rb")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    os.remove(path)
    return content
end

local function find_python()
    for _, cand in ipairs({ "python3", "python" }) do
        local out = capture(cand .. " --version")
        if out and out:find("Python 3", 1, true) then return cand end
    end
    return nil
end

local python = find_python()
if not python then
    print("SKIP: no python3/python interpreter on PATH — the CI job runs this gate with python3")
    print("verdict: skipped")
    os.exit(0)
end

local failures = {}

-- 1. Self-test: every finding shape + lane mapping + exit contract, on
--    synthetic DBs in TEMP (never the canonical DBC path).
local selftest = capture(python .. " " .. TOOL .. " --self-test")
if not selftest:find("self-test: all assertions passed", 1, true)
    or selftest:find("FAIL:", 1, true) then
    failures[#failures + 1] = "self-test"
    print("--- self-test output ---")
    print(selftest)
end

-- 2. Fixture check: the committed pair through the real end-to-end path
--    (extraction, diff, lane-impact scan over the live delta call sites,
--    JSON report, exit contract).
local fixtures = capture(python .. " " .. TOOL .. " --check-fixtures")
if not fixtures:find("[PASS] forever DBC diff fixture check", 1, true)
    or fixtures:find("FAIL:", 1, true) then
    failures[#failures + 1] = "fixture check"
    print("--- fixture check output ---")
    print(fixtures)
else
    for line in fixtures:gmatch("[^\r\n]+") do
        if line:find("^verdict:", 1) then print(line) end
    end
end

if #failures > 0 then
    print("FAIL run_forever_dbc_diff_tests (" .. table.concat(failures, ", ") .. ")")
    os.exit(1)
end
print("verdict: harness + committed fixtures in sync")
print("[PASS] run_forever_dbc_diff_tests")
os.exit(0)
