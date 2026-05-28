-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tools/audit_static_behavior.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Build-time audit tool: scans Lua files for known bad patterns.
-- This is a non-runtime tool; external commands are used for directory listing when LuaFileSystem is unavailable.
-- ============================================================================

local root = arg and arg[1] or "EaxRotations"
local report_path = root .. "/docs/STATIC_BEHAVIOR_AUDIT.md"

-- Try LuaFileSystem first to avoid os.execute
local _lfs_ok, lfs = pcall(require, "lfs")
if not _lfs_ok then lfs = nil end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return "" end
    local data = f:read("*a")
    f:close()
    return data or ""
end

local function write_file(path, data)
    local f = assert(io.open(path, "wb"))
    f:write(data)
    f:close()
end

local function list_lua_files()
    local files = {}
    if lfs then
        -- Pure Lua with LuaFileSystem
        local function walk(dir)
            for entry in lfs.dir(dir) do
                if entry ~= "." and entry ~= ".." then
                    local full = dir .. "/" .. entry
                    local attr = lfs.attributes(full)
                    if attr then
                        if attr.mode == "directory" then
                            walk(full)
                        elseif entry:match("%.lua$") then
                            local rel = full:gsub("^" .. root:gsub("%-", "%%-") .. "/", "")
                            files[#files + 1] = rel
                        end
                    end
                end
            end
        end
        walk(root)
    else
        -- Fallback: use external command only if lfs is missing
        local tmp = os.tmpname() or (os.getenv("TEMP") or "/tmp") .. "/eax_audit_files.txt"
        local cmd = 'powershell -NoProfile -Command "Get-ChildItem -LiteralPath \'' .. root .. '\' -Recurse -File -Filter *.lua | ForEach-Object { $_.FullName }"'
        os.execute(cmd .. " > " .. tmp .. " 2>nul")
        local f = io.open(tmp, "rb")
        if f then
            for line in f:read("*a"):gmatch("[^\r\n]+") do
                local rel = line:gsub("\\", "/")
                files[#files + 1] = rel
            end
            f:close()
        end
        os.remove(tmp)
    end
    table.sort(files)
    return files
end

local function line_number(data, pos)
    local line = 1
    for _ in data:sub(1, pos):gmatch("\n") do line = line + 1 end
    return line
end

local function strip_comments(data)
    data = data:gsub("%-%-%[%[.-%]%]", "")
    data = data:gsub("%-%-[^\r\n]*", "")
    return data
end

local rules = {
    {
        key = "fake_or_known_bad_ids",
        severity = "high",
        note = "Known bad/fake IDs should not appear in production code.",
        scan = function(data)
            local hits = {}
            for _, id in ipairs({ "190005", "190006", "190007", "190008", "39213", "23720" }) do
                local pos = data:find(id, 1, true)
                if pos then hits[#hits + 1] = id .. " at line " .. tostring(line_number(data, pos)) end
            end
            return hits
        end,
    },
    {
        key = "legacy_lightning_shield_aliases",
        severity = "high",
        note = "Old Lightning Shield aliases caused recast spam and should remain out of current Shaman production files.",
        scan = function(data, path)
            if not path:lower():find("/classes/shaman/", 1, true) then return {} end
            local hits = {}
            for _, id in ipairs({ "10430", "8133", "8132" }) do
                local pos = data:find(id, 1, true)
                if pos then hits[#hits + 1] = id .. " at line " .. tostring(line_number(data, pos)) end
            end
            return hits
        end,
    },
    {
        key = "noncentral_consumable_lists",
        severity = "medium",
        note = "Consumable item lists should prefer shared/tbc_data_sylvanas.lua.",
        scan = function(data)
            local hits = {}
            for pos, name in data:gmatch("()local%s+([%w_]+)%s*=%s*%{") do
                local upper = name:upper()
                local is_consumable = upper:find("POTION", 1, true)
                    or upper:find("HEALTHSTONE", 1, true)
                    or upper:find("FOOD", 1, true)
                    or upper:find("DRINK", 1, true)
                if is_consumable then
                local chunk = data:sub(math.max(1, pos - 600), pos + 300)
                if not chunk:find("TBC", 1, true) then
                    hits[#hits + 1] = name .. " at line " .. tostring(line_number(data, pos))
                end
                end
            end
            return hits
        end,
    },
    {
        key = "direct_core_in_class_files",
        severity = "low",
        note = "Class/spec files should usually use the NS boundary, with explicit exceptions for simple cached helpers/tests.",
        scan = function(data, path)
            if not path:lower():find("/classes/", 1, true) then return {} end
            local hits = {}
            for pos in data:gmatch("()core%.") do
                hits[#hits + 1] = "core. at line " .. tostring(line_number(data, pos))
                if #hits >= 8 then break end
            end
            return hits
        end,
    },
    {
        key = "todo_markers",
        severity = "low",
        note = "TODO/FIXME markers should be reviewed before release.",
        scan = function(data)
            local hits = {}
            for pos, marker in data:gmatch("()([Tt][Oo][Dd][Oo]|FIXME)") do
                hits[#hits + 1] = marker .. " at line " .. tostring(line_number(data, pos))
                if #hits >= 8 then break end
            end
            return hits
        end,
    },
}

local files = list_lua_files()
local counts = {}
local details = {}
for _, rule in ipairs(rules) do counts[rule.key] = 0 end

for i = 1, #files do
    local path = files[i]
    local rel = path:gsub("^.-EaxRotations/", "EaxRotations/")
    local lower = rel:lower()
    if not lower:find("/tests/", 1, true) and not lower:find("/tools/", 1, true) then
        local data = strip_comments(read_file(path))
        for _, rule in ipairs(rules) do
            local hits = rule.scan(data, rel)
            if hits and #hits > 0 then
                counts[rule.key] = counts[rule.key] + #hits
                details[#details + 1] = { rule = rule, file = rel, hits = hits }
            end
        end
    end
end

local lines = {
    "# Static Behavior Audit",
    "",
    "Generated by `EaxRotations/tools/audit_static_behavior.lua`.",
    "",
    "This is a non-runtime scan for patterns that have previously caused bad in-game behavior or release risk.",
    "",
    "| Rule | Severity | Hits | Meaning |",
    "|---|---|---:|---|",
}

for _, rule in ipairs(rules) do
    lines[#lines + 1] = string.format("| `%s` | %s | %d | %s |", rule.key, rule.severity, counts[rule.key], rule.note)
end

lines[#lines + 1] = ""
lines[#lines + 1] = "## Findings"

if #details == 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "No static behavior findings."
else
    for i = 1, #details do
        local d = details[i]
        lines[#lines + 1] = ""
        lines[#lines + 1] = "### " .. d.file
        lines[#lines + 1] = "- Rule: `" .. d.rule.key .. "` (" .. d.rule.severity .. ")"
        for _, hit in ipairs(d.hits) do
            lines[#lines + 1] = "- " .. hit
        end
    end
end

write_file(report_path, table.concat(lines, "\n") .. "\n")
print("Static behavior audit written: " .. report_path)
for _, rule in ipairs(rules) do print(rule.key .. ": " .. tostring(counts[rule.key])) end
