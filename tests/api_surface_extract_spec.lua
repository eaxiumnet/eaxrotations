local chunk, err = loadfile("tools/api_surface_extract.lua")
assert(chunk, "expected tools/api_surface_extract.lua to exist: " .. tostring(err))

local script = chunk("tools.api_surface_extract")
assert(type(script) == "table", "api_surface_extract should return a module table")
assert(type(script.extract_surface) == "function", "extract_surface must be defined")
assert(type(script.write_allowlist) == "function", "write_allowlist must be defined")

local surface = script.extract_surface({
    ".api/core.lua",
    ".api/game_object.lua",
    ".api/menu.lua",
    ".api/common",
})

assert(type(surface) == "table", "extract_surface must return a table")
assert(type(surface.roots) == "table", "surface.roots must be a table")
assert(type(surface.methods) == "table", "surface.methods must be a table")
assert(type(surface.generated_from) == "table", "surface.generated_from must be a table")
assert(surface.roots["core.log"], "expected core.log to be extracted")
assert(surface.roots["core.register_on_update_callback"], "expected core.register_on_update_callback to be extracted")
assert(surface.roots["core.input.use_item"], "expected core.input.use_item to be extracted")
assert(surface.methods["get_health"], "expected get_health method to be extracted")
assert(surface.methods["get_state"], "expected get_state method to be extracted")

local output_path = "tools/api_allowlist.lua"
os.remove(output_path)

local ok = script.write_allowlist(output_path)
assert(ok == true, "write_allowlist should return true")

local allowlist_chunk, allowlist_err = loadfile(output_path)
assert(allowlist_chunk, "expected generated allowlist to load: " .. tostring(allowlist_err))

local allowlist = allowlist_chunk("tools.api_allowlist")
assert(type(allowlist) == "table", "generated allowlist must return a table")
assert(allowlist.roots["core.log"], "generated allowlist missing core.log")
assert(allowlist.roots["core.input.use_item"], "generated allowlist missing core.input.use_item")
assert(allowlist.methods["get_health"], "generated allowlist missing get_health")
assert(allowlist.methods["get_state"], "generated allowlist missing get_state")
assert(type(allowlist.generated_from) == "table", "generated allowlist missing generated_from")
assert(#allowlist.generated_from >= 4, "expected generated_from to list source files")

local saw_common_file = false
for _, path in ipairs(allowlist.generated_from) do
    if path == ".api/common/modules/health_prediction.lua" then
        saw_common_file = true
        break
    end
end

assert(saw_common_file, "expected generated_from to include .api/common files")

print("api_surface_extract_spec: ok")
