-- check_unused_requires.lua — Audit unused local require() assignments in EaxRotations Lua files.
-- WHAT:  scans all .lua files under EaxRotations/ for `local X = require(...)` where X
--        is never referenced again in the same file.
-- WHEN:  pre-commit / CI check.
-- WHY:   dead requires bloat load time and confuse readers; this keeps the tree clean.
-- SAFETY: pure file-read static analysis; never loads Lua modules.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local audit_helper = require("EaxRotations/tests/audit_helper")

local lfs, lfs_err = audit_helper.require_lfs()
if not lfs then
    -- Fail-closed (mirror run_clean_checkout_probe.lua): a SKIP + exit 0 on a
    -- missing dependency silently disables this audit — the exact graceful-skip
    -- masking class that hid the 5 rotation-suite gaps. lfs is a hard requirement
    -- for the walk, so a build without it must fail loudly, not pass green.
    print("[ERROR] check_unused_requires cannot run (" .. tostring(lfs_err) .. ")")
    print("        lfs is required to walk the EaxRotations tree; install it or fix the build.")
    os.exit(1)
end

-- Remove block comments, single-line comments, and string literals from text
-- so that subsequent analysis only looks at real code.
local function strip_comments_and_strings(text)
    -- Remove block comments (best-effort for balanced long brackets).
    text = text:gsub("%-%-%[=*%[.-]%=*%]", "")
    -- Remove single-line comments.
    text = text:gsub("%-%-[^\n]*", "")
    -- Replace string literals with placeholder (best-effort; handles simple escapes).
    text = text:gsub('"[^"]*"', '""')
    text = text:gsub("'[^']*'", "''")
    return text
end

-- Find all local variables assigned from require() calls in the file.
-- Returns a list of { var = "X", pos = number }.
local function find_local_requires(text)
    local requires = {}
    local pos = 1
    while pos <= #text do
        -- Look for "local" followed by variable(s) and an assignment that includes require().
        local local_start, vars, rest = text:match("()local%s+([%w_,%s]+)%s*=%s*()", pos)
        if not local_start then break end

        -- Find the first require() call within the right-hand side (naive: up to newline or next statement).
        local rhs_end = text:find("\n", rest) or #text + 1
        local rhs = text:sub(rest, rhs_end - 1)

        -- Match require("..."), require('...'), require "...", require '...'
        local req_pos = rhs:find("require%s*%(")
        if not req_pos then
            req_pos = rhs:find("require%s+[%\"']")
        end

        if req_pos then
            local var_list = {}
            for v in vars:gmatch("([%w_]+)") do
                var_list[#var_list + 1] = v
            end
            -- Only handle the simple case: one variable per require on the RHS.
            -- For multi-variable assignments, we only flag the first variable as used by the first require.
            if #var_list > 0 then
                requires[#requires + 1] = { var = var_list[1], pos = local_start }
            end
        end

        pos = rhs_end + 1
    end
    return requires
end

local function find_unused_requires(path, text)
    local unused = {}
    local cleaned = strip_comments_and_strings(text)
    local requires = find_local_requires(cleaned)

    for _, req in ipairs(requires) do
        local var = req.var
        if var ~= "_" then
            -- Search the remainder of the file (after the require line) for any use of var.
            local after = cleaned:sub(req.pos + 1)
            local pattern = "[^%w_]" .. var .. "[^%w_]"
            local used = after:find(pattern, 1, false) ~= nil
            if not used then
                unused[#unused + 1] = { path = path, var = var }
            end
        end
    end
    return unused
end

local files = audit_helper.get_lua_files("EaxRotations")
local all_unused = {}

for _, path in ipairs(files) do
    local f = io.open(path, "rb")
    if f then
        local text = f:read("*a") or ""
        f:close()
        local unused = find_unused_requires(path, text)
        for _, u in ipairs(unused) do
            all_unused[#all_unused + 1] = u
        end
    end
end

print("Lua files scanned for unused requires: " .. #files)
print("Unused local requires found: " .. #all_unused)

if #all_unused > 0 then
    print("Unused local requires:")
    for _, u in ipairs(all_unused) do
        print(string.format("  %s: %s", u.path, u.var))
    end
    os.exit(1)
end

print("OK: no unused local requires found")
