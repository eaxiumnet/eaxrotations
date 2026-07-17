-- scan_aoe_manifest.lua
-- WHAT:  Scans aoe_high_severity_manifest.lua paths; each needle must be
--        followed (within window) by the required helper (aoe_self/target_meets).
-- WHEN:  Standalone or via test_aoe_range_audit_contracts.
-- WHY:  One scan fails every unfixed expansion at once (no subset theater).
-- SAFETY: Read-only file I/O.

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local t = f:read("*a") or ""
    f:close()
    return t
end

local function load_manifest()
    local candidates = {
        "EaxRotations/tests/aoe_high_severity_manifest.lua",
        "tests/aoe_high_severity_manifest.lua",
        "aoe_high_severity_manifest.lua",
    }
    for i = 1, #candidates do
        local chunk = loadfile(candidates[i])
        if chunk then
            local ok, result = pcall(chunk)
            if ok and type(result) == "table" then return result end
        end
    end
    return nil
end

--- @return table rows { status, family, path, needle, helper, detail }
--- @return number dirty_count
local function scan(manifest)
    manifest = manifest or load_manifest()
    assert(type(manifest) == "table", "aoe_high_severity_manifest missing or invalid")
    local rows = {}
    local dirty = 0
    for _, entry in ipairs(manifest) do
        local window = entry.window or 700
        local helper = entry.helper
        local needle = entry.needle
        local family = entry.family or "?"
        for _, path in ipairs(entry.paths or {}) do
            local text = read_file(path)
            local status, detail
            if not text then
                status, detail = "MISSING", "file not found"
                dirty = dirty + 1
            else
                local start = text:find(needle, 1, true)
                if not start then
                    status, detail = "MISSING_NEEDLE", "needle not in file"
                    dirty = dirty + 1
                else
                    local win = text:sub(start, start + window)
                    if win:find(helper, 1, true) then
                        status, detail = "CLEAN", "helper in window"
                    else
                        status, detail = "DIRTY", "helper '" .. helper .. "' not within " .. window .. " chars of needle"
                        dirty = dirty + 1
                    end
                end
            end
            rows[#rows + 1] = {
                status = status,
                family = family,
                path = path,
                needle = needle,
                helper = helper,
                detail = detail,
            }
        end
    end
    return rows, dirty
end

local function format_report(rows, dirty)
    local lines = {
        "AoE high-severity manifest scan",
        "rows=" .. tostring(#rows) .. " dirty_count=" .. tostring(dirty) .. " ALL_CLEAN=" .. tostring(dirty == 0),
        "",
    }
    for i = 1, #rows do
        local r = rows[i]
        lines[#lines + 1] = string.format(
            "%s [%s] %s :: needle=%s helper=%s -- %s",
            r.status, r.family, r.path, r.needle, r.helper, r.detail
        )
    end
    return table.concat(lines, "\n")
end

-- Standalone runner
if arg and arg[0] and tostring(arg[0]):find("scan_aoe_manifest", 1, true) then
    local rows, dirty = scan()
    local report = format_report(rows, dirty)
    print(report)
    if dirty > 0 then
        os.exit(1)
    end
    os.exit(0)
end

return {
    load_manifest = load_manifest,
    scan = scan,
    format_report = format_report,
}
