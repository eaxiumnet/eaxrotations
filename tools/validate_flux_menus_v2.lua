-- Validation script for Flux rotation menu.lua files
-- Checks for common AstroUI menu configuration issues

local flux_specs = {
    "EAXDruidResto_Flux", "EAXDruidBalance_Flux", "EAXDruidFeral_Flux", "EAXDruidBear_Flux",
    "EAXWarriorProtection_Flux", "EAXWarriorFury_Flux", "EAXWarriorArms_Flux",
    "EAXWarlockDestruction_Flux", "EAXWarlockDemonology_Flux", "EAXWarlockAffliction_Flux",
    "EAXShamanRestoration_Flux", "EAXShamanEnhancement_Flux", "EAXShamanElemental_Flux",
    "EAXRogueSubtlety_Flux", "EAXRogueCombat_Flux", "EAXRogueAssassination_Flux",
    "EAXPriestShadow_Flux", "EAXPriestHoly_Flux", "EAXPriestDiscipline_Flux",
    "EAXPaladinRetribution_Flux", "EAXPaladinProtection_Flux", "EAXPaladinHoly_Flux",
    "EAXMageFrost_Flux", "EAXMageFire_Flux", "EAXMageArcane_Flux",
    "EAXHunterSurvival_Flux", "EAXHunterMM_Flux", "EAXHunterBM_Flux"
}

local issues = {}
local total_checked = 0

for _, spec in ipairs(flux_specs) do
    local menu_path = spec .. "/libraries/menu.lua"
    local file = io.open(menu_path, "r")
    
    if not file then
        table.insert(issues, spec .. ": menu.lua not found")
        goto continue
    end
    
    local content = file:read("*all")
    file:close()
    total_checked = total_checked + 1
    
    -- Check 1: Wrong element method names (old API)
    if content:match("t:slider_int%(") then
        table.insert(issues, spec .. ": Uses deprecated t:slider_int() - should be t:slider_list()")
    end
    if content:match("t:keybind%(") then
        table.insert(issues, spec .. ": Uses deprecated t:keybind() - should be t:keybind_grid()")
    end
    if content:match("t:combobox%(") then
        table.insert(issues, spec .. ": Uses deprecated t:combobox() - should be t:combo_list()")
    end
    
    -- Check 2: Old element definition pattern (check for element = without elements array wrapper)
    -- Look for t:slider_list({ element = which is WRONG
    if content:match("t:slider_list%s*%(?%s*%{[^}]*element%s*=%s*menu") then
        table.insert(issues, spec .. ": slider_list uses wrong element format (needs elements = { { element = ... } })")
    end
    
    -- Check 3: Check for on_render callbacks
    if not content:match("function%s+menu%.on_render") then
        table.insert(issues, spec .. ": Missing menu.on_render function")
    end
    if not content:match("function%s+menu%.on_menu_render") then
        table.insert(issues, spec .. ": Missing menu.on_menu_render function")
    end
    
    -- Check 4: Check AstroUI registration
    if not content:match("AstroUI%.register_window") then
        table.insert(issues, spec .. ": Missing AstroUI.register_window call")
    end
    
    -- Check 5: Check for menu.ui initialization
    if not content:match("menu%.ui%s*=%s*AstroUI%.new") then
        table.insert(issues, spec .. ": Missing menu.ui = AstroUI.new() initialization")
    end
    
    -- Check 6: Check for ext_lib_astro_ui require
    if not content:match("require%s*%(%s*[%'\"]ext_lib_astro_ui") then
        table.insert(issues, spec .. ": Missing require for ext_lib_astro_ui")
    end
    
    -- Check 7: Check for add_tab calls (should have tabs)
    local tab_count = 0
    for _ in content:gmatch("menu%.ui:add_tab") do
        tab_count = tab_count + 1
    end
    if tab_count == 0 then
        table.insert(issues, spec .. ": No tabs defined (no menu.ui:add_tab calls)")
    end
    
    ::continue::
end

print("========================================")
print("FLUX MENU VALIDATION RESULTS")
print("========================================")
print("Specs checked: " .. total_checked .. "/" .. #flux_specs)
print("Issues found: " .. #issues)
print("")

if #issues == 0 then
    print("✓ All menu.lua files appear correctly configured!")
else
    print("Issues detected:")
    for i, issue in ipairs(issues) do
        print(string.format("  %d. %s", i, issue))
    end
end

print("")
print("========================================")
print("SYNTAX CHECK - SAMPLE SPECS")
print("========================================")

-- Run luac -p on a sample of specs to verify syntax
local sample_specs = {
    "EAXDruidResto_Flux/libraries/menu.lua",
    "EAXWarriorFury_Flux/libraries/menu.lua",
    "EAXPriestHoly_Flux/libraries/menu.lua",
    "EAXMageArcane_Flux/libraries/menu.lua"
}

for _, path in ipairs(sample_specs) do
    local cmd = "luac -p " .. path .. " 2>&1"
    local handle = io.popen(cmd)
    local result = handle:read("*a") or ""
    handle:close()
    
    if #result > 0 then
        print("✗ " .. path .. ": " .. result:gsub("\n", " "))
    else
        print("✓ " .. path .. ": syntax OK")
    end
end

print("")
print("Validation complete.")
