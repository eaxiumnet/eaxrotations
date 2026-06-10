-- regression test: combobox sync must not overwrite user selection on first call.

local playstyle_keys = {"leveling", "affliction", "demonology", "destruction"}

local function get_playstyle_index(value)
    local wanted = tostring(value or ""):lower()
    for i = 1, #playstyle_keys do
        if tostring(playstyle_keys[i]):lower() == wanted then
            return i
        end
    end
    return 1
end

local combobox = { index = 4 }
function combobox:get() return self.index end
function combobox:set(new_index) self.index = new_index end

local settings = { playstyle = "affliction" }
local function get_setting(key, default)
    return settings[key] ~= nil and settings[key] or default
end
local function set_setting(key, value)
    settings[key] = value
end

-- Simulate the FIXED sync_playstyle_control logic from main.lua
local _last_playstyle_combo_index = nil

local function sync_playstyle_control()
    local combo_index = combobox:get()

    if _last_playstyle_combo_index == nil then
        _last_playstyle_combo_index = combo_index
        local value = playstyle_keys[combo_index]
        if type(value) == "string" and value ~= "" then
            set_setting("playstyle", value)
        end
        return
    end

    local current_playstyle = get_setting("playstyle", nil)

    if combo_index ~= _last_playstyle_combo_index then
        local value = playstyle_keys[combo_index]
        if type(value) == "string" and value ~= "" then
            set_setting("playstyle", value)
        end
        _last_playstyle_combo_index = combo_index
        return
    end

    if current_playstyle then
        local setting_index = get_playstyle_index(current_playstyle)
        if setting_index ~= combo_index then
            combobox:set(setting_index)
            _last_playstyle_combo_index = setting_index
        end
    end
end

-- Test: First call with _last=nil and stored playstyle differs from combobox
sync_playstyle_control()
assert(combobox:get() == 4, "combobox should NOT be overwritten on first sync call")
assert(settings.playstyle == "destruction", "playstyle should be seeded from combobox on first call")

-- Test 2: After first call, subsequent user clicks should work
combobox:set(3) -- user clicks "demonology"
sync_playstyle_control()
assert(settings.playstyle == "demonology", "playstyle setting should update to demonology after click")
assert(combobox:get() == 3, "combobox should stay at 3 after user click")

-- Test 3: External setting change should sync back to combobox
settings.playstyle = "affliction"
sync_playstyle_control()
assert(combobox:get() == 2, "combobox should sync to external setting change")

print("PASS test_playstyle_combobox_write_syncs")
