-- tests/source_scan.lua — the read-only source-scanning machinery the tripwire suites share.
-- WHAT:  plugin-root location, production-file discovery, comment stripping (newlines kept),
--        byte-offset -> line mapping, pattern offsets, and the assignment-vs-comparison test
--        every write scan discriminates with.
-- WHEN:  required by tests/test_nav_destination_ownership.lua, tests/test_pull_checkpoint.lua,
--        tests/test_shared_state_declaration.lua and tests/test_pull_safety.lua's P15 scan. Not
--        a suite: its name does not match the runner's discovery pattern, so it is never run.
-- WHY:   each tripwire had grown its own copy of this, so a fix to one copy (a directory to
--        skip, a comment shape to strip, a comparison operator to exclude) could leave the
--        others scanning a different surface while all of them still reported green. One
--        implementation is what makes "the scans cover the same files, the same way" true.
-- SAFETY: reads only (io.open + lfs); no requires of scanned modules, no execution of scanned
--         code, no writes. A missing plugin root or lfs raises — a scan that covers nothing
--         must never be able to pass.

local M = {}

-- ============================================================================
-- The plugin root
-- ============================================================================

local _root = nil

--- Locate the plugin root so a suite runs from the repo root or the plugin root.
--- @return string prefix ("" when the working directory already is the plugin root)
function M.root()
    if _root then return _root end
    for _, prefix in ipairs({ "EaxAutoQuester/", "" }) do
        local f = io.open(prefix .. "main.lua", "r")
        if f then
            f:close()
            _root = prefix
            return _root
        end
    end
    error("source_scan: EaxAutoQuester root not found (expected main.lua in ./ or EaxAutoQuester/)",
        2)
end

-- ============================================================================
-- Reading production source
-- ============================================================================

--- The source of a file under the plugin root, or nil when it cannot be read.
--- @param rel string path relative to the plugin root
--- @return string|nil
function M.read(rel)
    local f = io.open(M.root() .. rel, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

--- Every production Lua file: everything under the plugin root except the suites, the docs and
--- the throwaway `_`-prefixed probes. Sorted, relative to the plugin root, so two scans over
--- this list see the same surface.
--- @return string[]
function M.production_files()
    local ok, lfs = pcall(require, "lfs")
    assert(ok and lfs and lfs.dir,
        "source_scan: lfs is required — a partial scan of production code must not be able to pass")

    local root = M.root()
    local dir = root:sub(1, #root - 1)
    if dir == "" then dir = "." end        -- run from inside the plugin root: walk the cwd
    local cut = #dir + 2                    -- `dir .. "/"`, so a path becomes a relative path
    local out = {}
    local function walk(at)
        for entry in lfs.dir(at) do
            if entry ~= "." and entry ~= ".." then
                local path = at .. "/" .. entry
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    if entry ~= "tests" and entry ~= "docs" then walk(path) end
                elseif entry:match("%.lua$") and not entry:match("^_") then
                    out[#out + 1] = path:sub(cut)
                end
            end
        end
    end
    walk(dir)
    table.sort(out)
    return out
end

-- ============================================================================
-- Comments and offsets
-- ============================================================================

--- Blank out comments while preserving newlines, so prose about a banned write cannot trip a
--- scan and a line number in the stripped source is still a line number in the file.
--- @param src string
--- @return string
function M.strip_comments(src)
    local out = {}
    local i, n = 1, #src
    while i <= n do
        if src:sub(i, i + 1) == "--" then
            local eq = src:match("^%-%-%[(=*)%[", i)
            if eq then
                local close = "]" .. eq .. "]"
                local start = i + 4 + #eq
                local e = src:find(close, start, true)
                e = e and (e + #close) or (n + 1)
                -- Keep the newlines the comment covered, so offsets after it stay aligned.
                for nl in src:sub(i, e - 1):gmatch("[\r\n]") do out[#out + 1] = nl end
                i = e
            else
                local e = src:find("[\r\n]", i) or (n + 1)
                i = e
            end
        else
            out[#out + 1] = src:sub(i, i)
            i = i + 1
        end
    end
    return table.concat(out)
end

--- 1-based line number of a byte offset in `s`.
--- @param s string
--- @param at number
--- @return number
function M.line_at(s, at)
    local _, count = s:sub(1, at):gsub("\n", "\n")
    return count + 1
end

--- Byte offsets of every occurrence of a Lua pattern, in order.
--- @param s string
--- @param pat string
--- @return number[]
function M.find_offsets(s, pat)
    local out = {}
    local at = s:find(pat)
    while at do
        out[#out + 1] = at
        at = s:find(pat, at + 1)
    end
    return out
end

--- Is the `=` at byte offset `at` an assignment (a write) rather than part of a comparison?
--- `==`, `~=`, `<=` and `>=` are reads of the field and must never trip a write scan.
--- @param s string comment-stripped source
--- @param at number byte offset of the `=`
--- @return boolean
function M.is_assignment(s, at)
    if s:sub(at, at) ~= "=" then return false end
    if s:sub(at + 1, at + 1) == "=" then return false end
    local before = s:sub(at - 1, at - 1)
    return not (before == "~" or before == "<" or before == ">")
end

return M
