--[[
    EAX Dashboard Update Validation Tool
    
    Validates:
    1. Root libraries/dashboard.lua syntax
    2. All 29 spec dashboard.lua files match root (byte-identical)
    3. All dashboard_config.lua have required feature flags
    4. All menu.lua have required toggle definitions
    
    Usage: lua tools/validate_dashboard_updates.lua
--]]

-- Configuration
local ROOT_DASHBOARD = "libraries/dashboard.lua"
local REQUIRED_CONFIG_FIELDS = {
    "show_timer_bars",
    "show_action_history",
    "show_energy_tick",
    "show_combo_points",
    "show_threat_bar",
    "enable_smart_collapse",
}
local REQUIRED_MENU_TOGGLES = {
    "dashboard_enabled",
    "dashboard_opacity",
    "dashboard_scale",
    "dashboard_x",
    "dashboard_y",
}

-- Stats
local stats = {
    total_specs = 0,
    synced = 0,
    mismatched = 0,
    config_ok = 0,
    config_missing = 0,
    menu_ok = 0,
    menu_missing = 0,
}

-- Helper: Check if file exists using io.open
local function file_exists(path)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

-- Helper: Read file contents
local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    return content
end

-- Helper: Run luac -p on a file
local function validate_syntax(path)
    local cmd = string.format("luac -p \"%s\" 2>&1", path)
    local handle = io.popen(cmd)
    if not handle then return false, "Failed to run luac" end
    local result = handle:read("*all")
    handle:close()
    
    if result and result:match("error") then
        return false, result:gsub("\n", " ")
    end
    return true, nil
end

-- Helper: Get all EAX directories using dir command
local function get_eax_directories()
    local dirs = {}
    local handle = io.popen('dir /b /ad "EAX*" 2>nul')
    if handle then
        for line in handle:lines() do
            if line:match("^EAX") then
                table.insert(dirs, line)
            end
        end
        handle:close()
    end
    table.sort(dirs)
    return dirs
end

-- Step 1: Validate root dashboard.lua syntax
local function validate_root()
    print("Step 1: Validating root dashboard.lua...")
    
    if not file_exists(ROOT_DASHBOARD) then
        print("  [FAIL] Root dashboard.lua not found: " .. ROOT_DASHBOARD)
        return false
    end
    
    local ok, err = validate_syntax(ROOT_DASHBOARD)
    if not ok then
        print("  [FAIL] Syntax error: " .. (err or "unknown"))
        return false
    end
    
    print("  [PASS] Root dashboard.lua syntax OK")
    return true
end

-- Step 2: Check all spec dashboard.lua files match root
local function check_spec_dashboards(root_content)
    print("")
    print("Step 2: Checking spec dashboard.lua files...")
    
    local dirs = get_eax_directories()
    stats.total_specs = #dirs
    
    if #dirs == 0 then
        print("  [WARN] No EAX directories found")
        return
    end
    
    for _, dir in ipairs(dirs) do
        local spec_dashboard = dir .. "/libraries/dashboard.lua"
        
        if not file_exists(spec_dashboard) then
            print("  [MISSING] " .. dir .. " (no dashboard.lua)")
            stats.mismatched = stats.mismatched + 1
        else
            local spec_content = read_file(spec_dashboard)
            if spec_content == root_content then
                print("  [OK] " .. dir)
                stats.synced = stats.synced + 1
            else
                -- Check if it's just a size difference or actual content
                local root_size = #root_content
                local spec_size = #spec_content
                if root_size ~= spec_size then
                    print("  [MISMATCH] " .. dir .. " (size: " .. spec_size .. " vs " .. root_size .. ")")
                else
                    print("  [MISMATCH] " .. dir .. " (content differs)")
                end
                stats.mismatched = stats.mismatched + 1
            end
        end
    end
end

-- Step 3: Check dashboard_config.lua for required fields
local function check_dashboard_configs()
    print("")
    print("Step 3: Checking dashboard_config.lua...")
    
    local dirs = get_eax_directories()
    
    for _, dir in ipairs(dirs) do
        local config_path = dir .. "/libraries/dashboard_config.lua"
        
        if not file_exists(config_path) then
            print("  [MISSING FILE] " .. dir)
            stats.config_missing = stats.config_missing + 1
        else
            local content = read_file(config_path) or ""
            local missing = {}
            
            for _, field in ipairs(REQUIRED_CONFIG_FIELDS) do
                -- Check for field in various formats (simple string search)
                if not content:find(field, 1, true) then
                    table.insert(missing, field)
                end
            end
            
            if #missing > 0 then
                print("  [MISSING FIELDS] " .. dir .. ": " .. table.concat(missing, ", "))
                stats.config_missing = stats.config_missing + 1
            else
                print("  [OK] " .. dir)
                stats.config_ok = stats.config_ok + 1
            end
        end
    end
end

-- Step 4: Check menu.lua for required toggle definitions
local function check_menu_toggles()
    print("")
    print("Step 4: Checking menu.lua toggle definitions...")
    
    local dirs = get_eax_directories()
    
    for _, dir in ipairs(dirs) do
        local menu_path = dir .. "/libraries/menu.lua"
        
        if not file_exists(menu_path) then
            print("  [MISSING FILE] " .. dir)
            stats.menu_missing = stats.menu_missing + 1
        else
            local content = read_file(menu_path) or ""
            local missing = {}
            
            for _, toggle in ipairs(REQUIRED_MENU_TOGGLES) do
                -- Look for menu.toggle_name pattern (simple string search)
                local search_str = "menu." .. toggle
                if not content:find(search_str, 1, true) then
                    table.insert(missing, toggle)
                end
            end
            
            if #missing > 0 then
                print("  [MISSING TOGGLES] " .. dir .. ": " .. table.concat(missing, ", "))
                stats.menu_missing = stats.menu_missing + 1
            else
                print("  [OK] " .. dir)
                stats.menu_ok = stats.menu_ok + 1
            end
        end
    end
end

-- Print summary
local function print_summary()
    print("")
    print("=== Validation Summary ===")
    print(string.format("Total specs found: %d", stats.total_specs))
    print("")
    print("Dashboard.lua Sync Status:")
    print(string.format("  Synced:     %d", stats.synced))
    print(string.format("  Mismatched: %d", stats.mismatched))
    print("")
    print("Dashboard Config Status:")
    print(string.format("  OK:         %d", stats.config_ok))
    print(string.format("  Missing:    %d", stats.config_missing))
    print("")
    print("Menu Toggle Status:")
    print(string.format("  OK:         %d", stats.menu_ok))
    print(string.format("  Missing:    %d", stats.menu_missing))
    print("")
    
    -- Overall status
    local all_ok = (stats.mismatched == 0 and stats.config_missing == 0 and stats.menu_missing == 0)
    if all_ok then
        print("[PASS] All validations passed!")
        return 0
    else
        print("[FAIL] Some validations failed. Run sync script to fix mismatches.")
        return 1
    end
end

-- Main
print("=== EAX Dashboard Update Validation ===")
print("")

-- Step 1: Validate root
if not validate_root() then
    print("")
    print("[FAIL] Root validation failed. Cannot continue.")
    os.exit(1)
end

-- Read root content for comparison
local root_content = read_file(ROOT_DASHBOARD)

-- Step 2-4: Check specs
check_spec_dashboards(root_content)
check_dashboard_configs()
check_menu_toggles()

-- Summary and exit
local exit_code = print_summary()
os.exit(exit_code)
