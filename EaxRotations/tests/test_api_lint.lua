-- test_api_lint.lua - Validate core_sylvanas.lua contains no null bytes (binary corruption guard).
-- WHAT:  Validate core_sylvanas.lua contains no null bytes (binary corruption guard).
-- WHEN:  Run as part of rotation test suite.
-- SAFETY: Pure test - no production code, no side effects, no state mutation.
--
-- Also carries the .api MEMBER-CONTRACT lint (2026-09-13). A production file
-- must not read a member the corresponding `.api` module does not declare.
-- Regression that motivated it: ten class files called
-- `inventory_helper.has_item(id)`, a member the .api `inventory_helper` module
-- has never had (it declares get_all_slots / get_current_consumables_list /
-- get_total_free_slots / ... only). The call was a nil call, so the live client
-- logged "attempt to call field 'has_item' (a nil value)" on every combat tick
-- while every mock-based suite stayed green - the battery had seeded
-- package.loaded["common/utility/inventory_helper"] with an invented has_item.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local NUL = string.char(0)
local CR = string.char(13)
local LF = string.char(10)

local f = assert(io.open("EaxRotations/core_sylvanas.lua", "rb"))
local d = f:read("*a")
f:close()
assert_true(d:find(NUL, 1, true) == nil, "no nul")

-- ============================================================================
-- .api member-contract lint
-- ============================================================================
local lfs_ok, lfs = pcall(require, "lfs")
if not lfs_ok or type(lfs) ~= "table" then
    print("PASS api_lint (member-contract lint skipped: luafilesystem unavailable)")
    return
end

local LINE_SPLIT = "[^" .. CR .. LF .. "]+"

local function read_all(path)
    local fh = io.open(path, "rb")
    if not fh then return nil end
    local body = fh:read("*a")
    fh:close()
    return body
end

-- --- 1. Declared members per .api module -----------------------------------
-- A module participates only when it declares a `---@class <basename>` block;
-- every `---@field name` under that class is an allowed member.
local api_members = {}
local function scan_api_module(module_path, body)
    local classes, current = {}, nil
    for line in body:gmatch(LINE_SPLIT) do
        local cls = line:match("^%s*%-%-%-@class%s+([%w_]+)")
        if cls then
            current = cls
            classes[current] = classes[current] or {}
        else
            local field = line:match("^%s*%-%-%-@field%s+([%w_]+)")
            if field and current then classes[current][field] = true end
        end
    end
    local base = module_path:match("([^/]+)$") or module_path
    if classes[base] then return classes[base] end
    return nil
end

local function walk(root, rel_prefix, fn)
    for entry in lfs.dir(root) do
        if entry ~= "." and entry ~= ".." then
            local full = root .. "/" .. entry
            local attr = lfs.attributes(full)
            local rel = (rel_prefix == "" and entry) or (rel_prefix .. "/" .. entry)
            if attr and attr.mode == "directory" then
                walk(full, rel, fn)
            elseif attr and attr.mode == "file" and entry:sub(-4) == ".lua" then
                fn(rel, full)
            end
        end
    end
end

local api_root = ".api"
if lfs.attributes(api_root) then
    walk(api_root, "", function(rel, full)
        local body = read_all(full)
        if body then
            local module_path = rel:sub(1, -5) -- strip ".lua"
            local members = scan_api_module(module_path, body)
            if members then api_members[module_path] = members end
        end
    end)
end
assert_true(next(api_members) ~= nil, "api lint: no .api module declarations found")

-- --- 2. Aliases bound to .api modules, then <alias>.<member> reads ---------
local violations = {}
local function lint_file(rel, full)
    local body = read_all(full)
    if not body then return end
    local alias_to_module = {}
    for line in body:gmatch(LINE_SPLIT) do
        if line:find("require", 1, true) then
            local module_path = line:match('require%s*[,%(]?%s*"([^"]+)"')
            if module_path and api_members[module_path] then
                local lhs = line:match("^(.-)=") or ""
                local alias
                if line:find("pcall", 1, true) then
                    alias = lhs:match("([%w_]+)%s*$")     -- last name in the LHS list
                else
                    alias = lhs:match("%f[%a_][%w_]+")    -- first name after `local`
                end
                if alias and alias ~= "" and alias ~= "local" and alias ~= "require" then
                    alias_to_module[alias] = module_path
                end
            end
        end
    end
    -- Only CALLS are in scope (alias.member(...)). The crash class this lint
    -- guards is "call a member the engine module does not have"; a plain field
    -- read of a derived sub-table (BUFF_DB.BLOODLUST, where BUFF_DB is
    -- require("common/buff_db").SpellIDs) is legitimate and not a nil call.
    -- A char that is an identifier or "." before the alias disqualifies the
    -- match, so `obj.alias.member(` cannot be mistaken for a module call.
    for alias, module_path in pairs(alias_to_module) do
        local function check(member)
            if not api_members[module_path][member] then
                violations[#violations + 1] = string.format(
                    "%s: %s.%s - .api module '%s' does not declare that member",
                    rel, alias, member, module_path)
            end
        end
        for member in body:gmatch("[^%w_.]" .. alias .. "%.([%w_]+)%s*%(") do check(member) end
        for member in body:gmatch("^" .. alias .. "%.([%w_]+)%s*%(") do check(member) end
    end
end

walk("EaxRotations", "", function(rel, full)
    if rel:sub(1, 6) == "tests/" then return end
    lint_file(rel, full)
end)

if #violations > 0 then
    error("api_lint: " .. #violations .. " .api member-contract violation(s):" .. LF .. "  " ..
        table.concat(violations, LF .. "  "), 0)
end

local api_module_count = 0
for _ in pairs(api_members) do api_module_count = api_module_count + 1 end
print("PASS api_lint binary-corruption + .api member-contract (" .. api_module_count .. " declared modules)")
print("PASS api_lint")
