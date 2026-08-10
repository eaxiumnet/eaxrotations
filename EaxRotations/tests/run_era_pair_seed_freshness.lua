-- run_era_pair_seed_freshness.lua — era-pair seed drift guard.
-- WHAT:  ensures tests/era_pair_seed.lua matches a fresh regeneration of
--        EaxRotations/tools/generate_era_pair_seed.py (the scorecard --check
--        drift discipline applied to the era-pair baseline). The era-pair
--        audit (run_era_pair_audit_tests.lua) allowlists whatever the seed
--        contains, so a stale seed — regeneration committed separately from
--        the re-baselining rotation change, or a hand-edit — silently weakens
--        the era-coverage gate. This check makes the seed itself
--        machine-verified: it must be the generator's exact output.
-- WHEN:  verify_all + pre-commit, alongside run_era_pair_audit_tests.lua.
-- WHY:   the audit's non-vacuity depends on the seed being the generator's
--        deterministic output (proven byte-identical on regeneration);
--        regeneration stays a local-only manual step (like
--        generate_buff_debuff_verification.py), but drift from the committed
--        seed now fails loudly instead of silently weakening the gate.
-- SAFETY: read-only against the tree; os.execute spawns the committed
--         generator's --check / --self-test modes only (both generate in
--         memory, never write). No rotation logic, no io writes.

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
        -- Fail loudly, never skip: a build without python cannot verify the
        -- seed, and a graceful skip would silently disable this guard (the
        -- same fail-closed discipline as the lfs-based audits).
        io.stderr:write("[ERROR] run_era_pair_seed_freshness: python3/python not found — " ..
            "cannot run the generator's " .. mode .. " drift guard\n")
        os.exit(1)
    end
    -- os.execute's return shape differs across Lua versions: 5.1 returns the
    -- numeric exit code; 5.4 returns (true/false, "exit", code). Normalize so
    -- the wrapper behaves identically under the gate's pinned 5.1 AND local 5.4.
    local a, b, c = os.execute(py .. " EaxRotations/tools/generate_era_pair_seed.py " .. mode)
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
