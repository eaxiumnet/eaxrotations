-- check_todos.lua — Audit developer-debt markers in EaxRotations Lua files.
-- WHAT:  scans all .lua files under EaxRotations/ for disallowed marker words in comments.
-- WHEN:  pre-commit / CI check.
-- WHY:   prevents accidental accumulation of unresolved technical debt in rotation code.
-- SAFETY: pure file-read static analysis; never loads Lua modules.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local audit_helper = require("EaxRotations/tests/audit_helper")

local lfs, lfs_err = audit_helper.require_lfs()
if not lfs then
    -- Fail-closed (mirror run_clean_checkout_probe.lua): a SKIP + exit 0 on a
    -- missing dependency silently disables this audit — the exact graceful-skip
    -- masking class that hid the 5 rotation-suite gaps. lfs is a hard requirement
    -- for the walk, so a build without it must fail loudly, not pass green.
    print("[ERROR] check_todos cannot run (" .. tostring(lfs_err) .. ")")
    print("        lfs is required to walk the EaxRotations tree; install it or fix the build.")
    os.exit(1)
end

local MARKERS = { "TODO", "FIXME", "XXX", "HACK" }
local ALLOW_TAG = "AUDIT%-ALLOW%-"  -- e.g. -- AUDIT-ALLOW-TODO

local function has_marker(text)
    local upper = text:upper()
    for _, marker in ipairs(MARKERS) do
        if upper:find("%f[%a]" .. marker .. "%f[%A]") then
            return marker
        end
    end
    return nil
end

local function is_allowed(text)
    local upper = text:upper()
    for _, marker in ipairs(MARKERS) do
        if upper:find(ALLOW_TAG .. marker) then
            return true
        end
    end
    return false
end

-- Extract the comment portion of a line (everything after the first `--`).
local function extract_comment(line)
    local pos = line:find("%-%-")
    if not pos then return nil end
    return line:sub(pos + 2)
end

local files = audit_helper.get_lua_files("EaxRotations")

local findings = {}
for _, path in ipairs(files) do
    local f = io.open(path, "rb")
    if f then
        local line_no = 0
        for line in f:lines() do
            line_no = line_no + 1
            local comment = extract_comment(line)
            if comment then
                local marker = has_marker(comment)
                if marker and not is_allowed(comment) then
                    findings[#findings + 1] = { path = path, line = line_no, marker = marker, text = comment }
                end
            end
        end
        f:close()
    end
end

print("Lua files scanned for disallowed markers: " .. #files)
print("Disallowed markers found: " .. #findings)

if #findings > 0 then
    print("Files with disallowed markers:")
    for _, f in ipairs(findings) do
        print(string.format("  %s:%d [%s] %s", f.path, f.line, f.marker, f.text:gsub("^%s*", "")))
    end
    print("Add an inline tag like -- AUDIT-ALLOW-<MARKER> to explicitly permit a marker.")
    os.exit(1)
end

print("OK: no disallowed developer-debt markers found")
