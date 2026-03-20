local M = {}

local DEFAULT_API_PATHS = {
    ".api/core.lua",
    ".api/game_object.lua",
    ".api/menu.lua",
    ".api/common",
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

local function list_lua_files(root)
    local normalized = normalize_path(root)
    if normalized:match("%.lua$") then
        if file_exists(normalized) then
            return { to_repo_path(normalized) }
        end
        return {}
    end

    local sep = package.config:sub(1, 1)
    if sep == "\\" then
        local windows_root = normalized:gsub("/", "\\")
        return command_lines(string.format('cmd /c dir /b /s "%s\\*.lua" 2>nul', windows_root))
    end

    return command_lines(string.format('find "%s" -type f -name "*.lua" 2>/dev/null', normalized))
end

local function parse_surface(content, roots, methods)
    for callable in content:gmatch("function%s+([%a_][%w_%.]*)%s*%(") do
        roots[callable] = true
    end

    for method in content:gmatch("%-%-%-@field%s+([%a_][%w_]*)%s+fun%s*%(") do
        methods[method] = true
    end
end

local function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function serialize_bool_map(name, map)
    local lines = { string.format("    %s = {", name) }
    for _, key in ipairs(sorted_keys(map)) do
        lines[#lines + 1] = string.format('        ["%s"] = true,', key)
    end
    lines[#lines + 1] = "    },"
    return lines
end

local function serialize_array(name, values)
    local lines = { string.format("    %s = {", name) }
    for _, value in ipairs(values) do
        lines[#lines + 1] = string.format('        "%s",', value)
    end
    lines[#lines + 1] = "    },"
    return lines
end

function M.extract_surface(api_paths)
    local roots = {}
    local methods = {}
    local generated_from_map = {}

    for _, api_path in ipairs(api_paths or DEFAULT_API_PATHS) do
        for _, file_path in ipairs(list_lua_files(api_path)) do
            local content = read_file(file_path)
            if content then
                generated_from_map[file_path] = true
                parse_surface(content, roots, methods)
            end
        end
    end

    local generated_from = sorted_keys(generated_from_map)
    return {
        roots = roots,
        methods = methods,
        generated_from = generated_from,
    }
end

function M.write_allowlist(output_path)
    local surface = M.extract_surface(DEFAULT_API_PATHS)
    local target_path = output_path or "tools/api_allowlist.lua"

    local lines = {
        "local allowlist = {",
    }

    for _, line in ipairs(serialize_bool_map("roots", surface.roots)) do
        lines[#lines + 1] = line
    end

    for _, line in ipairs(serialize_bool_map("methods", surface.methods)) do
        lines[#lines + 1] = line
    end

    for _, line in ipairs(serialize_array("generated_from", surface.generated_from)) do
        lines[#lines + 1] = line
    end

    lines[#lines + 1] = "}"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "return allowlist"

    local file, err = io.open(target_path, "w")
    if not file then
        error("failed to write allowlist: " .. tostring(err))
    end

    file:write(table.concat(lines, "\n"))
    file:close()
    return true
end

function M.main()
    M.write_allowlist("tools/api_allowlist.lua")
    print("PASS: tools/api_allowlist.lua")
    return 0
end

local module_name = ...
if module_name ~= "tools.api_surface_extract" then
    os.exit(M.main(), true)
end

return M
