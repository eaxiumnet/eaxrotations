local M = {}

local BANNED_PATTERNS = {
    { pattern = "ffi%.", label = "ffi.C" },
    { pattern = "io%.popen", label = "io.popen" },
    { pattern = "os%.execute", label = "os.execute" },
    { pattern = "^debug[%.%[]", label = "debug namespace" },
    { pattern = "[^%w%.:]debug[%.%[]", label = "debug namespace" },
}

local function normalize_path(path)
    return (path:gsub("\\", "/"))
end

local function current_dir()
    local sep = package.config:sub(1, 1)
    local handle
    if sep == "\\" then
        handle = io.popen("cmd /c cd")
    else
        handle = io.popen("pwd")
    end

    if not handle then
        return ""
    end

    local line = handle:read("*l") or ""
    handle:close()
    return normalize_path(line)
end

local REPO_ROOT = current_dir()

local function to_repo_path(path)
    local normalized = normalize_path(path)
    if REPO_ROOT ~= "" and normalized:sub(1, #REPO_ROOT + 1) == REPO_ROOT .. "/" then
        return normalized:sub(#REPO_ROOT + 2)
    end
    return normalized
end

local function file_exists(path)
    local file = io.open(path, "r")
    if not file then
        return false
    end
    file:close()
    return true
end

local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()
    return content
end

local function strip_line(line)
    local stripped = line:gsub("%-%-.*$", "")
    stripped = stripped:gsub('"[^"\\]*(\\.[^"\\]*)*"', '""')
    stripped = stripped:gsub("'[^'\\]*(\\.[^'\\]*)*'", "''")
    return stripped
end

local function is_function_definition(line)
    if line:match("^%s*local%s+function%s+[%a_][%w_]*%s*%(") then
        return true
    end

    if line:match("^%s*function%s+[%a_][%w_%.:]*%s*%(") then
        return true
    end

    if line:match("[%a_][%w_%.]*%s*=%s*function%s*%(") then
        return true
    end

    return false
end

local function command_lines(command)
    local handle = io.popen(command)
    if not handle then
        return {}
    end

    local lines = {}
    for line in handle:lines() do
        if line ~= "" then
            lines[#lines + 1] = to_repo_path(line)
        end
    end
    handle:close()
    return lines
end

local function list_runtime_paths()
    local paths = {}
    local seen = {}
    local sep = package.config:sub(1, 1)

    local spec_dirs
    if sep == "\\" then
        spec_dirs = command_lines('cmd /c dir /b /ad "EAX*" 2>nul')
    else
        spec_dirs = command_lines("find . -maxdepth 1 -type d -name 'EAX*' -printf '%P\\n' 2>/dev/null")
    end

    for _, spec_dir in ipairs(spec_dirs) do
        for _, file_name in ipairs({ "main.lua", "utils.lua", "eax_utils.lua" }) do
            local candidate = normalize_path(spec_dir .. "/" .. file_name)
            if file_exists(candidate) and not seen[candidate] then
                seen[candidate] = true
                paths[#paths + 1] = candidate
            end
        end
    end

    local shared_files
    if sep == "\\" then
        shared_files = command_lines('cmd /c dir /b /s "eax_shared\\*.lua" 2>nul')
    else
        shared_files = command_lines('find "eax_shared" -maxdepth 1 -type f -name "*.lua" 2>/dev/null')
    end

    for _, path in ipairs(shared_files) do
        if not seen[path] then
            seen[path] = true
            paths[#paths + 1] = path
        end
    end

    table.sort(paths)
    return paths
end

local function load_allowlist()
    local chunk, err = loadfile("tools/api_allowlist.lua")
    if not chunk then
        return nil, "missing tools/api_allowlist.lua"
    end

    local ok, allowlist = pcall(chunk, "tools.api_allowlist")
    if not ok or type(allowlist) ~= "table" then
        return nil, "unable to load tools/api_allowlist.lua"
    end

    return allowlist
end

local function add_violation(violations, seen, path, line_no, call)
    local key = table.concat({ path, tostring(line_no), call }, "|")
    if seen[key] then
        return
    end

    seen[key] = true
    violations[#violations + 1] = {
        path = path,
        line = line_no,
        call = call,
    }
end

local function scan_rooted_calls(line, allowlist, violations, seen, path, line_no)
    for call in line:gmatch("([%a_][%w_]*%.[%a_][%w_%.]*)%s*%(") do
        local namespace = call:match("^([%a_][%w_]*)%.")
        if namespace and allowlist.root_names[namespace] and not call:match("^ffi%.") and not call:match("^debug%.") and not allowlist.roots[call] then
            add_violation(violations, seen, path, line_no, call)
        end
    end
end

local function scan_method_calls(line, allowlist, violations, seen, path, line_no)
    for receiver, method in line:gmatch("([%a_][%w_]*)%s*:%s*([%a_][%w_]*)%s*%(") do
        if allowlist.object_receivers[receiver] and not allowlist.methods[method] then
            add_violation(violations, seen, path, line_no, ":" .. method)
        end
    end
end

local function scan_file(path, allowlist, violations, seen)
    local content = read_file(path)
    if not content then
        add_violation(violations, seen, path, 0, "unreadable file")
        return
    end

    local line_no = 0

    for raw_line in (content .. "\n"):gmatch("(.-)\n") do
        line_no = line_no + 1
        local line = strip_line(raw_line)

        for _, banned in ipairs(BANNED_PATTERNS) do
            if line:find(banned.pattern) then
                add_violation(violations, seen, path, line_no, banned.label)
            end
        end

        if not is_function_definition(line) then
            scan_rooted_calls(line, allowlist, violations, seen, path, line_no)
            scan_method_calls(line, allowlist, violations, seen, path, line_no)
        end
    end
end

function M.scan_paths(paths)
    local allowlist, err = load_allowlist()
    if not allowlist then
        return false, {
            { path = "tools/api_allowlist.lua", line = 0, call = err },
        }
    end

    local violations = {}
    local seen = {}
    allowlist.roots = allowlist.roots or {}
    allowlist.methods = allowlist.methods or {}
    allowlist.root_names = {}
    for call in pairs(allowlist.roots) do
        local namespace = call:match("^([%a_][%w_]*)%.")
        if namespace then
            allowlist.root_names[namespace] = true
        end
    end
    allowlist.object_receivers = {
        me = true,
        player = true,
        local_player = true,
        target = true,
        focus = true,
        pet = true,
        unit = true,
        ally = true,
        enemy = true,
        member = true,
        object = true,
        obj = true,
        corpse = true,
        mouseover = true,
        cp_obj = true,
    }
    for _, path in ipairs(paths or {}) do
        scan_file(normalize_path(path), allowlist, violations, seen)
    end

    table.sort(violations, function(a, b)
        if a.path == b.path then
            if a.line == b.line then
                return a.call < b.call
            end
            return a.line < b.line
        end
        return a.path < b.path
    end)

    return #violations == 0, violations
end

function M.discover_runtime_paths()
    return list_runtime_paths()
end

function M.main(argv)
    local paths = argv
    if type(paths) ~= "table" or #paths == 0 then
        paths = list_runtime_paths()
    end

    local ok, violations = M.scan_paths(paths)
    if ok then
        print("PASS: api hard gate")
        return 0
    end

    for _, violation in ipairs(violations) do
        print(string.format("FAIL: %s:%d -> %s", violation.path, violation.line, violation.call))
    end
    return 1
end

local module_name = ...
if module_name ~= "tools.api_hard_gate" then
    os.exit(M.main(), true)
end

return M
