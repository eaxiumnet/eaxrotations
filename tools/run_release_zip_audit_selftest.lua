-- tools/run_release_zip_audit_selftest.lua -- Lua gate shim for the zip audit.
--
-- WHAT:  Runs tools/release_zip_audit.py --self-test, picking python3 when
--        present (CI ubuntu-latest) else python (local Windows) -- the same
--        bridge run_era_pair_seed_freshness.lua uses. The self-test is fully
--        offline and deterministic (synthetic in-memory zips), so it meets
--        the sibling-audit bar for run_verify_all + pre-commit components.
-- WHY:   The zip audit is Python (zipfile + curl are its turf, mirroring
--        create_release_zip.py); the gates are Lua. Rather than hardcode a
--        python binary name that differs between CI and Windows, both gates
--        call this shim.
-- SAFETY: read-only; spawns only the tool's --self-test mode (no network,
--         no filesystem writes).

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

local py = pick_python()
if not py then
    io.stderr:write("[ERROR] run_release_zip_audit_selftest: python3/python " ..
        "not found -- cannot run the release zip audit self-test\n")
    os.exit(1)
end

-- os.execute's return shape differs across Lua versions (5.1 numeric /
-- 5.4 boolean+string+code); normalize like run_era_pair_seed_freshness.lua.
local a, b, c = os.execute(py .. " tools/release_zip_audit.py --self-test")
local code
if type(a) == "number" then
    code = a
elseif b == "exit" then
    code = c
else
    code = (a == true) and 0 or 1
end
os.exit(code or 1)
