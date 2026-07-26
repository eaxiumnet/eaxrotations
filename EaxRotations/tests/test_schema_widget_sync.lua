-- test_schema_widget_sync.lua — Regression guard for schema widget → NS.settings sync.
-- WHAT:  verifies that the on_update() sync loop in main.lua reads schema widget values
--        (checkbox/slider/dropdown) and injects them into NS.settings so spec_kit.setting_bool
--        / NS.get_setting see the live user-selected value. This is the v2.16.1 fix that
--        made all schema settings actually work (previously they were purely cosmetic).
-- WHEN:  run as a standalone test or via run_rotation_tests.lua.
-- WHY:   before v2.16.1, the sync loop only synced hardcoded quick-toggle keybinds + playstyle.
--        Schema checkboxes like cat_auto_prowl, bear_use_challenging_roar, prot_righteous_defense,
--        use_auto_consumables, etc. were NEVER synced — their widget values never reached
--        NS.settings, so spec_kit.setting_bool always returned the default. Disabling Auto Prowl
--        in the menu did nothing. This test ensures the sync loop is never accidentally removed.
-- SAFETY: pure static text-scan + functional mock; no engine API calls; no module loading.

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_eq(a, b, label)
    if a ~= b then error(string.format("%s: expected %s, got %s", label or "assert_eq", tostring(b), tostring(a)), 2) end
end

local function assert_false(v, label)
    if v then error(label or "assert_false failed", 2) end
end

local function read_file(path)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a")
    f:close()
    return data
end

local function contains(data, text)
    return data:find(text, 1, true) ~= nil
end

-- ============================================================================
-- PART 1: Static text-scan — guard against accidental removal of the sync loop
-- ============================================================================

local main = read_file("EaxRotations/main.lua")

-- The sync loop must exist and iterate schema_widgets calling widget.sync
assert_true(contains(main, "for key, widget in pairs(schema_widgets) do"),
    "main.lua must have the schema widget sync loop iterating schema_widgets")
assert_true(contains(main, "widget and widget.sync"),
    "sync loop must check widget.sync exists before calling")
assert_true(contains(main, "pcall(widget.sync)"),
    "sync loop must pcall the sync function for safety")
assert_true(contains(main, "st[key] = value"),
    "sync loop must write the synced value to the settings table (st[key])")

-- The old broken state had a comment "schema widget sync (writes removed)" — ensure it's gone
assert_false(contains(main, "schema widget sync (writes removed)"),
    "the 'writes removed' comment must NOT be present — that was the broken state where settings were cosmetic")

-- The sync loop must be gated so it doesn't double-run with the declarative menu
assert_true(contains(main, "if not _declarative_menu_active then"),
    "schema widget sync must be skipped when declarative menu is active (no double-sync)")

-- The create_schema_widget function must define .sync for each widget type
assert_true(contains(main, 'widget.sync = function()'),
    "create_schema_widget must define .sync functions for widgets")

-- Checkbox sync must use get_state() — the sync function calls control:get_state()
assert_true(main:find("get_state", 1, true) ~= nil,
    "checkbox widget sync must call control:get_state()")

-- Slider sync must use get() — the sync function calls control:get()
-- Both checkbox and slider sync functions exist; slider's returns control:get()
assert_true(contains(main, "widget.control and widget.control:get()"),
    "slider widget sync must call control:get()")

-- ============================================================================
-- PART 2: Functional mock — verify the sync loop pattern actually works
-- ============================================================================

-- Simulate the sync loop from main.lua on_update():
--   for key, widget in pairs(schema_widgets) do
--       if widget and widget.sync then
--           local ok, value = pcall(widget.sync)
--           if ok and value ~= nil then
--               st[key] = value
--           end
--       end
--   end

-- Mock checkbox widget (simulates cat_auto_prowl = false, user unchecked it)
local checkbox_control = {
    _state = false,
    get_state = function(self) return self._state end,
}
local checkbox_widget = {
    key = "cat_auto_prowl",
    type = "checkbox",
    control = checkbox_control,
    sync = function() return checkbox_control:get_state() end,
}

-- Mock slider widget (simulates cat_rip_cp = 4, user moved slider)
local slider_control = {
    _value = 4,
    get = function(self) return self._value end,
}
local slider_widget = {
    key = "cat_rip_cp",
    type = "slider",
    control = slider_control,
    sync = function() return slider_control:get() end,
}

-- Mock dropdown widget (simulates playstyle = "cat", user selected index 4)
local dropdown_option_values = { "leveling", "balance", "bear", "cat", "caster", "resto" }
local dropdown_control = {
    _index = 4,
    get = function(self) return self._index end,
}
-- Use the same resolve_index helper pattern as the fixed production code
local function mock_resolve_index(idx, vals)
    local v = vals[idx]
    if v ~= nil then return v end
    return vals[idx + 1]
end
local dropdown_widget = {
    key = "some_dropdown_setting",
    type = "dropdown",
    control = dropdown_control,
    option_values = dropdown_option_values,
    -- Dropdown sync resolves the 1-based index to the option value (same as create_schema_widget)
    sync = function()
        local raw = dropdown_control:get()
        if type(raw) == "number" then
            return mock_resolve_index(raw, dropdown_option_values)
        end
        return nil
    end,
}

-- Mock a widget with a broken sync (throws an error) — sync loop must not crash
local broken_widget = {
    key = "broken_setting",
    type = "checkbox",
    sync = function() error("intentional sync failure") end,
}

-- Build the mock schema_widgets table
local mock_schema_widgets = {
    cat_auto_prowl = checkbox_widget,
    cat_rip_cp = slider_widget,
    some_dropdown_setting = dropdown_widget,
    broken_setting = broken_widget,
}

-- Run the sync loop (exact pattern from main.lua)
local st = {}
local sync_errors = 0
for key, widget in pairs(mock_schema_widgets) do
    if widget and widget.sync then
        local ok, value = pcall(widget.sync)
        if ok and value ~= nil then
            st[key] = value
        elseif not ok then
            sync_errors = sync_errors + 1
        end
    end
end

-- Assert: checkbox value (false) was synced — this is the cat_auto_prowl regression
assert_true(st.cat_auto_prowl ~= nil, "cat_auto_prowl must be synced to settings table")
assert_eq(st.cat_auto_prowl, false, "cat_auto_prowl must be false (user unchecked it)")

-- Assert: slider value (4) was synced
assert_true(st.cat_rip_cp ~= nil, "cat_rip_cp must be synced to settings table")
assert_eq(st.cat_rip_cp, 4, "cat_rip_cp must be 4 (user moved slider)")

-- Assert: dropdown value was resolved from index 4 to "cat"
assert_true(st.some_dropdown_setting ~= nil, "dropdown setting must be synced to settings table")
assert_eq(st.some_dropdown_setting, "cat", "dropdown must resolve 1-based index 4 to option value 'cat'")

-- Assert: broken widget did not crash the sync loop (pcall caught the error)
assert_eq(sync_errors, 1, "exactly one sync error should have been caught by pcall")
assert_true(st.broken_setting == nil, "broken widget must not write to settings table")

-- ============================================================================
-- PART 3: Verify spec_kit.setting_bool reads the synced value correctly
-- ============================================================================

-- Simulate spec_kit.setting_bool reading from context.settings (which is NS.settings)
-- This is the actual consumer path: spec file → spec_kit.setting_bool(context, key, default)
local context = { settings = st }

local function setting_bool(ctx, key, default)
    local settings = ctx and ctx.settings
    if type(settings) == "table" and settings[key] ~= nil then
        return settings[key] ~= false
    end
    return default
end

-- cat_auto_prowl = false in settings → setting_bool must return false (not the default true)
assert_eq(setting_bool(context, "cat_auto_prowl", true), false,
    "spec_kit.setting_bool must return false when cat_auto_prowl is false in settings, NOT the default true")

-- cat_rip_cp = 4 in settings → setting_bool returns true (4 is not false)
assert_eq(setting_bool(context, "cat_rip_cp", true), true,
    "spec_kit.setting_bool must return true for non-false slider value")

-- Unknown key → must return the default
assert_eq(setting_bool(context, "nonexistent_key", true), true,
    "spec_kit.setting_bool must return default for unknown keys")
assert_eq(setting_bool(context, "nonexistent_key", false), false,
    "spec_kit.setting_bool must return default false for unknown keys when default is false")

-- ============================================================================
-- PART 4: Verify the sync loop handles nil widget.sync gracefully
-- ============================================================================

local mock_with_nil_sync = {
    has_sync = { key = "has_sync", sync = function() return true end },
    no_sync = { key = "no_sync", sync = nil },
    nil_widget = nil,
}

local st2 = {}
for key, widget in pairs(mock_with_nil_sync) do
    if widget and widget.sync then
        local ok, value = pcall(widget.sync)
        if ok and value ~= nil then
            st2[key] = value
        end
    end
end

assert_eq(st2.has_sync, true, "widget with sync function must be synced")
assert_true(st2.no_sync == nil, "widget without sync function must be skipped (not crash)")
assert_true(st2.nil_widget == nil, "nil widget entry must be skipped (not crash)")

-- ============================================================================
-- PART 5: Regression guard — sync loop must NOT use NS.set_setting / settings_manager:set
-- ============================================================================
-- The v2.5.15 "File name not set" spam was caused by the old sync loop calling
-- NS.set_setting() per-frame, which forwarded to settings_manager:set() every tick.
-- The v2.16.1 fix replaced this with direct table writes (st[key] = value),
-- bypassing settings_manager entirely. This part ensures the sync loop never
-- regresses back to set_setting calls.

-- Extract the sync loop region from main.lua (the block between the schema
-- widget sync comment and the declarative menu sync comment)
local sync_start = main:find("Schema widget sync:", 1, true)
assert_true(sync_start ~= nil, "must find the 'Schema widget sync:' comment in main.lua")
local sync_end = main:find("Declarative menu sync:", sync_start, true)
assert_true(sync_end ~= nil, "must find the 'Declarative menu sync:' comment after the sync loop")
local sync_region = main:sub(sync_start, sync_end)

-- The sync loop MUST use direct table writes (st[key] = value), NOT set_setting
-- Use "set_setting(" (with opening paren) to match function CALLS, not comment
-- mentions like "(no set_setting writes)" which would cause false positives.
assert_true(contains(sync_region, "st[key] = value"),
    "sync loop must use direct table writes (st[key] = value), not NS.set_setting")
assert_false(contains(sync_region, "set_setting("),
    "sync loop must NOT call set_setting() — that triggers settings_manager:set() per-frame (v2.5.15 spam root cause)")
assert_false(contains(sync_region, "settings_manager:set"),
    "sync loop must NOT reference settings_manager:set — direct table writes only")

-- Also verify the quick-toggle injection block uses direct writes, not set_setting
local qt_start = main:find("states injected from widgets", 1, true)
assert_true(qt_start ~= nil, "must find the 'states injected from widgets' comment")
local qt_end = main:find("Playstyle is driven", qt_start, true)
assert_true(qt_end ~= nil, "must find the 'Playstyle is driven' comment after quick toggle injection")
local qt_region = main:sub(qt_start, qt_end)
assert_false(contains(qt_region, "set_setting("),
    "quick toggle injection must NOT call set_setting() — direct table writes only (st.rotation_enabled = ...)")

-- Verify sync_quick_toggles() is a no-op (set_setting removed comment)
assert_true(contains(main, "set_setting removed; no writes for these toggles"),
    "sync_quick_toggles() must be a no-op with the 'set_setting removed' comment")

-- ============================================================================
-- PART 6: Dropdown/combobox sync audit — edge cases for all combobox return types
-- ============================================================================
-- Audits the resolve_index / resolve_label helpers in create_schema_widget.
-- These helpers replaced the old `or`-chained lookups that had a Lua truthiness
-- bug: option values of 0 or false are falsy, so `vals[i] or vals[i+1]` would
-- fall through to the wrong index. The fix uses explicit nil-checks.

-- Replicate the FIXED resolve helpers from create_schema_widget (main.lua).
-- These MUST stay in sync with the production code.
local function resolve_index(idx, vals)
    local v = vals[idx]
    if v ~= nil then return v end
    return vals[idx + 1]  -- 0-based fallback
end

local function resolve_label(label, by_label)
    local v = by_label[tostring(label)]
    if v ~= nil then return v end
    return by_label[tostring(label):lower()]
end

-- --- Case A: 1-based index (standard PS combobox:get() returns 1-based) ---
local vals_a = { "off", "near", "all" }
assert_eq(resolve_index(1, vals_a), "off", "1-based index 1 → 'off'")
assert_eq(resolve_index(2, vals_a), "near", "1-based index 2 → 'near'")
assert_eq(resolve_index(3, vals_a), "all", "1-based index 3 → 'all'")

-- --- Case B: 0-based index (some PS builds return 0-based) ---
-- Fallback: vals[0] is nil in Lua, so it tries vals[0+1] = vals[1]
assert_eq(resolve_index(0, vals_a), "off", "0-based index 0 → vals[0]=nil, fallback vals[1]='off'")

-- --- Case C: Numeric option values (priest shadow_multidot_mode: 1, 2, 3) ---
local vals_num = { 1, 2, 3 }
assert_eq(resolve_index(1, vals_num), 1, "numeric value 1 at index 1")
assert_eq(resolve_index(2, vals_num), 2, "numeric value 2 at index 2")
assert_eq(resolve_index(3, vals_num), 3, "numeric value 3 at index 3")

-- --- Case D: Option value is 0 (the truthiness bug the fix prevents) ---
-- OLD code: vals[i] or vals[i+1] → 0 is falsy → falls through to vals[i+1] (WRONG)
-- NEW code: vals[i] ~= nil → 0 is not nil → returns 0 (CORRECT)
local vals_zero = { 0, 1, 2 }
assert_eq(resolve_index(1, vals_zero), 0, "value 0 at index 1 must return 0, NOT fall through to 1")
assert_eq(resolve_index(2, vals_zero), 1, "value 1 at index 2")

-- --- Case E: Option value is false (another truthiness edge case) ---
-- OLD code: vals[i] or vals[i+1] → false is falsy → falls through (WRONG)
-- NEW code: vals[i] ~= nil → false is not nil → returns false (CORRECT)
local vals_false = { false, true }
assert_eq(resolve_index(1, vals_false), false, "value false at index 1 must return false, NOT fall through to true")
assert_eq(resolve_index(2, vals_false), true, "value true at index 2")

-- --- Case F: Out-of-bounds index returns nil (no crash) ---
assert_eq(resolve_index(99, vals_a), nil, "out-of-bounds index → nil (no crash)")
assert_eq(resolve_index(0, {}), nil, "empty table index 0 → nil")

-- --- Case G: Label-based resolution (combobox returns string label) ---
local by_label = {
    ["Off"] = 1, ["off"] = 1,
    ["Near Target Only"] = 2, ["near target only"] = 2,
    ["All in Range"] = 3, ["all in range"] = 3,
}
assert_eq(resolve_label("Off", by_label), 1, "exact label 'Off' → 1")
assert_eq(resolve_label("off", by_label), 1, "lowercased label 'off' → 1 (via fallback)")
assert_eq(resolve_label("Near Target Only", by_label), 2, "exact multi-word label → 2")
assert_eq(resolve_label("nonexistent", by_label), nil, "unknown label → nil")

-- --- Case H: Verify production code uses explicit nil-check (not `or`) ---
-- Static scan: the dropdown sync in main.lua must NOT use bare `or` for index resolution.
-- The fix replaced `widget.option_values[raw] or widget.option_values[raw + 1]` with
-- the resolve_index helper that uses `if v ~= nil then return v end`.
-- Check that the helper functions exist in main.lua.
assert_true(contains(main, "local function resolve_index"),
    "create_schema_widget must define resolve_index helper (explicit nil-check, not `or`)")
assert_true(contains(main, "local function resolve_label"),
    "create_schema_widget must define resolve_label helper (explicit nil-check, not `or`)")
assert_true(contains(main, "if v ~= nil then return v end"),
    "resolve helpers must use explicit nil-check (`~= nil`), not Lua `or` truthiness")

-- The old broken pattern (bare `or` on option_values) must be gone from the dropdown sync
-- Check the dropdown widget section for the old pattern.
-- CRITICAL: the end marker must be AFTER the sync function (which is defined after
-- widget.render), not before it. Using `return widget` (end of create_schema_widget)
-- captures the entire dropdown block including the sync function.
local dropdown_section_start = main:find('elseif def.type == "dropdown" then', 1, true)
assert_true(dropdown_section_start ~= nil, "must find the dropdown section in create_schema_widget")
-- Find the end of create_schema_widget — `return widget` comes after all widget type blocks
local dropdown_section_end = main:find('return widget', dropdown_section_start, true)
assert_true(dropdown_section_end ~= nil, "must find 'return widget' (end of create_schema_widget) after dropdown section")
local dropdown_section = main:sub(dropdown_section_start, dropdown_section_end)
-- The sync function (defined after render) must use resolve_index, not bare `or`
assert_false(contains(dropdown_section, 'widget.option_values[raw_value] or widget.option_values[raw_value + 1]'),
    "dropdown sync must NOT use bare `or` for index resolution (truthiness bug with 0/false values)")
-- Use a shorter search string for robustness against line-ending differences
assert_true(contains(dropdown_section, 'resolve_index'),
    "dropdown sync must call resolve_index() for index-based resolution")
assert_true(contains(dropdown_section, 'resolve_label'),
    "dropdown sync must call resolve_label() for label-based resolution")

print("PASS test_schema_widget_sync (6 parts: static scan, functional mock, setting_bool consumer, nil-sync guard, set_setting spam guard, dropdown edge-case audit)")
