-- run_spell_id_sweep_check.lua — spell-id sweep baseline gate.
-- WHAT:  runs EaxRotations/tools/spell_id_sweep.py --check: every pinned spell
--        id is re-derived from the local sources (TBC DBC set, both Wowhead
--        index dumps, the wowsims APL fixtures, the audit pin tables) and
--        compared against the committed, classified-once baseline
--        (EaxRotations/tools/spell_id_sweep_baseline.json).
--        Each bucket carries a disposition frozen in the sweep's
--        CHECK_DISPOSITION: `gate` buckets (DEAD, REJECTED-ID-IN-USE,
--        ERA-TBC-IN-VANILLA, ERA-WOTLK-IN-TBC) are proofs of wrongness and must
--        stay empty; `pinned` buckets (REDIRECTED, WRONG-RANK, RANK-ORDER,
--        PIN-FAMILY-MISMATCH, DUPLICATE-CONFLICT, UNSOURCED) freeze the
--        adjudicated finding set. A NEW finding — a wrong-family id the baseline
--        has never seen — fails the build, and so does CLEARING one, until the
--        pin is moved on purpose.
-- WHEN:  verify_all (component "spell-id sweep"), alongside the sylvanas /
--        vanilla / wotlk spell audits. Not wired into tools/pre-commit's own
--        numbered 19-check subset.
-- WHY:   48927 (a fabricated Holy Shield id) and `SodCleave` -> 25286 (Heroic
--        Strike) both shipped pins no offline gate could disprove: the audits
--        accept a bridge-known id once it is pinned, so the pin was
--        self-certifying. The sweep re-derives every pin from the raw sources;
--        this wrapper turns it into a gate instead of a report someone has to
--        remember to run.
-- SAFETY: read-only — only the sweep's --check / --self-test modes are spawned
--         (neither writes to the tree). verify_all parses the markers instead
--         of trusting the exit code, matching its own discipline.

-- Pick python3 when present (CI ubuntu-latest), else python (local Windows).
local function pick_python()
    for _, cand in ipairs({ "python3", "python" }) do
        local pipe = io.popen(cand .. " --version 2>&1")
        if pipe then
            local line = pipe:read("*l")
            pipe:close()
            if line and line:match("%d") then
                return cand
            end
        end
    end
    return nil
end

local function run_mode(mode)
    local py = pick_python()
    if not py then
        -- Fail loudly, never skip: without python the whole pinned-id surface is
        -- unverified, and a graceful skip would silently disable this gate (the
        -- same fail-closed discipline as run_era_pair_seed_freshness.lua).
        io.stderr:write("[ERROR] run_spell_id_sweep_check: python3/python not found — " ..
            "cannot run the spell-id sweep " .. mode .. " gate\n")
        os.exit(1)
    end
    -- os.execute's return shape differs across Lua versions: 5.1 returns the
    -- numeric exit code; 5.4 returns (true/false, "exit", code). Normalize so
    -- the wrapper behaves identically under the gate's pinned 5.1 AND local 5.4.
    local a, b, c = os.execute(py .. " EaxRotations/tools/spell_id_sweep.py " .. mode)
    local code
    if type(a) == "number" then
        code = a
    elseif b == "exit" then
        code = c
    else
        code = (a == true) and 0 or 1
    end
    if code ~= 0 then
        os.exit(1)
    end
    os.exit(0)
end

if arg and arg[1] == "--self-test" then
    run_mode("--self-test")
end

run_mode("--check")
