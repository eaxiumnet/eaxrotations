-- check_wotlk_placeholders.lua — Count placeholder match functions in WotLK specs.
-- WHAT:  scans all *_wotlk.lua files for match functions that only return true.
-- WHEN:  pre-commit / CI check.
-- WHY:   prevents skeleton specs from being considered complete.
-- SAFETY: pure file-read static analysis.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local lfs = require("lfs")
local function scan_dir(path, files)
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local full = path .. "/" .. file
            local attr = lfs.attributes(full)
            if attr.mode == "directory" then
                scan_dir(full, files)
            elseif file:match("_wotlk%.lua$") then
                files[#files + 1] = full
            end
        end
    end
end

local files = {}
scan_dir("EaxRotations/classes", files)

local total_placeholders = 0
local files_with_placeholders = {}

for _, path in ipairs(files) do
    local f = io.open(path, "rb")
    local text = f and f:read("*a") or ""
    if f then f:close() end
    local count = 0
    local normalized = text:gsub("%s+", " ")
    for _ in normalized:gmatch("local function [%w_]+_matches [^%a]* return true end") do
        count = count + 1
    end
    if count > 0 then
        total_placeholders = total_placeholders + count
        files_with_placeholders[#files_with_placeholders + 1] = path .. " (" .. count .. ")"
    end
end

print("WotLK spec files scanned: " .. #files)
print("Placeholder match functions: " .. total_placeholders)
if total_placeholders > 0 then
    print("Files with placeholders:")
    for _, info in ipairs(files_with_placeholders) do
        print("  " .. info)
    end
    os.exit(1)
end
print("OK: no placeholder match functions found")
