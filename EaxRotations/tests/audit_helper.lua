-- audit_helper.lua — Shared helpers for lfs-based static-analysis audits.
-- WHAT:  directory traversal and file-collection utilities used by check_*.lua scripts.
-- WHEN:  pre-commit / CI checks that scan the EaxRotations tree.
-- WHY:   keeps each audit script focused on its own rule instead of reimplementing lfs walks.
-- SAFETY: no side effects; pure read-only filesystem queries.

local M = {}

-- Try to load lfs; if unavailable, return nil and a skip message.
function M.require_lfs()
    local ok, lfs = pcall(require, "lfs")
    if ok and lfs then return lfs end
    return nil, "lfs not available on this Lua build"
end

-- Recursively collect .lua files under root_dir.
-- Optional ignored_dirs is a table of directory names to skip (e.g., { tests = true }).
function M.get_lua_files(root_dir, ignored_dirs)
    local lfs = M.require_lfs()
    if not lfs then error("lfs is required for audit_helper.get_lua_files") end
    ignored_dirs = ignored_dirs or {}

    local files = {}
    local function scan(path)
        for entry in lfs.dir(path) do
            if entry ~= "." and entry ~= ".." then
                local full = path .. "/" .. entry
                local attr = lfs.attributes(full)
                if attr and attr.mode == "directory" then
                    if not ignored_dirs[entry] then
                        scan(full)
                    end
                elseif entry:match("%.lua$") then
                    files[#files + 1] = full
                end
            end
        end
    end
    scan(root_dir)
    return files
end

return M
