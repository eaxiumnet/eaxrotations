-- Readability notes:
--   What: render/menu helper.
--   When: runs from render or menu callbacks.
--   Why: keeps UI separate from combat decisions.
--   Safety: do not cast spells or mutate combat flow from render code.
--   Performance: ProfileUI rows are built once from schema data instead of rebuilt per frame.

-- Decision notes:
--   This support module keeps side effects explicit and routes runtime-sensitive work through NS helpers.
--   Comments emphasize intent and constraints so future edits preserve behavior without adding frame-costly checks.
--   When API data is missing, callers should skip unsafe work rather than guessing.
-- EaxRotations Sylvanas ProfileUI builder.
-- Converts the class schema table into the profile UI format consumed by the menu.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local schema = _G.EaxRotations_SETTINGS_SCHEMA
if not schema then return end

local function text(value)
    return { enUS = value or "" }
end

local function hidden_slider(key)
    -- Hidden sliders persist window/button positions through the same settings path
    -- as visible controls. This avoids a second persistence system and keeps UI
    -- state cheap to load.
    return {
        type = "slider",
        key = key,
        label = "",
        tooltip = "",
        default = -1,
        min = -10000,
        max = 10000,
        hidden = true,
    }
end

local function append_position_storage(schema_root)
    local first_tab = schema_root[1]
    local first_section = first_tab and first_tab.sections and first_tab.sections[1]
    local settings = first_section and first_section.settings
    if not settings then return end

    local keys = { "_btn_x", "_btn_y", "_dash_x", "_dash_y" }
    for i = 1, #keys do
        settings[#settings + 1] = hidden_slider(keys[i])
    end
end

local function dropdown_options(setting)
    local out = {}
    local source = setting.options or {}
    for i = 1, #source do
        local item = source[i]
        out[i] = { text = item.text, value = item.value }
    end
    return out
end

local function widget_for(setting, marker)
    -- Convert our small schema vocabulary into the ProfileUI widget format.
    -- Keeping this as data transformation means class files do not allocate or
    -- render widget objects while combat logic is running.
    local kind = setting.type
    local base = {
        DB = setting.key,
        DBV = setting.default,
        L = text(setting.label),
        TT = text(setting.tooltip),
        M = marker,
    }

    if kind == "dropdown" then
        base.E = "Dropdown"
        base.OT = dropdown_options(setting)
    elseif kind == "checkbox" then
        base.E = "Checkbox"
    else
        base.E = "Slider"
        base.MIN = setting.min
        base.MAX = setting.max
    end

    return base
end

local function add_header(rows, label, size)
    rows[#rows + 1] = {
        { E = "Header", L = text(label), S = size },
    }
end

local function add_setting_rows(rows, settings, marker)
    -- Pack two narrow settings per row at build time. Doing layout once here
    -- keeps the render/menu callback focused on drawing the already-built rows.
    local index = 1
    while index <= #settings do
        local current = settings[index]
        local row = { widget_for(current, marker) }
        local next_setting = settings[index + 1]

        if next_setting and not current.wide and not next_setting.wide then
            row[#row + 1] = widget_for(next_setting, marker)
            index = index + 1
        end

        rows[#rows + 1] = row
        index = index + 1
    end
end

local function build_profile(schema_root)
    local rows = {}
    local marker = {}

    add_header(rows, "EaxRotations Settings", 16)

    for tab_index = 1, #schema_root do
        local tab = schema_root[tab_index]
        local sections = tab.sections
        if sections then
            add_header(rows, (tab.name or "General") .. " Settings", 14)
            for section_index = 1, #sections do
                local group = sections[section_index]
                add_header(rows, group.header or "", 12)
                if group.settings then
                    add_setting_rows(rows, group.settings, marker)
                end
            end
        end
    end

    return rows
end

append_position_storage(schema)

NS.ProfileUI = {
    DateTime = "v2.5 (17.02.2026)",
    [2] = build_profile(schema),
}

NS.log("ProfileUI built")
