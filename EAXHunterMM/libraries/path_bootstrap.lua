-- Path bootstrap for EAX rotation plugins
-- Resolves common/ modules relative to repo root instead of plugin directory
-- Place this require at the TOP of main.lua, before any other requires

local function get_script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)") or str:match("(.*\\)") or "./"
end

local plugin_dir = get_script_path()
-- Navigate from EAX<Class><Spec>/main.lua to repo root
local repo_root = plugin_dir:gsub("[^/]+/[^/]+/$", ""):gsub("[^\\]+\\[^\\]+\\$", "")

-- Add repo root to package.path if not already present
local path_pattern = repo_root .. "?.lua;"
if not package.path:find(path_pattern, 1, true) then
    package.path = path_pattern .. package.path
end

return true
