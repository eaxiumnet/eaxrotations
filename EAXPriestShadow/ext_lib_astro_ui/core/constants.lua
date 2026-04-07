-- ext_lib_astro_ui/constants.lua
-- Layout, theme and key-name data tables

---@type color
local color = require("common/color")

-- ============================================================================
-- LAYOUT CONSTANTS
-- ============================================================================

local LAYOUT = {
    padding_top = 10,
    padding_side = 15,
    padding_bottom = 15,

    -- Tab system
    tab_bar_height = 35,
    tab_button_height = 30,
    tab_button_min_width = 80,
    tab_button_max_width = 150,
    tab_button_spacing = 2,
    tab_bar_padding_top = 5,
    tab_content_padding_top = 15,
    tab_bar_right_reserved = 48,

    -- Optional side menu (sub-categories inside a tab)
    side_menu_width = 190,
    side_menu_padding = 10,
    side_menu_item_height = 24,
    side_menu_item_spacing = 4,
    side_menu_gap = 10,

    -- Section settings
    section_spacing = 18,
    section_header_height = 0,
    section_padding_top = 8,
    section_padding_bottom = 10,
    element_height = 26,
    element_spacing = 6,
    column_spacing = 25,
    slider_bar_height = 16,
    checkbox_size = 16,
    keybind_badge_width = 60,
    keybind_status_width = 45,
    keybind_clear_width = 60,
    separator_height = 2,

    -- Preset footer
    preset_footer_height = 62,
    preset_row_height = 24,
    preset_row_spacing = 6,
    preset_button_width = 50,
    preset_button_spacing = 6,
    preset_dropdown_width = 170,
    preset_name_input_width = 200,
    preset_footer_padding = 8,

    -- Scroll input
    scroll_wheel_step = 40,
    scroll_page_factor = 0.8
}

-- ============================================================================
-- COLOR THEMES
-- ============================================================================

local THEME_NAMES = { "astro", "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" }
local THEME_INDEX = {
    astro = 1,
    warrior = 2,
    paladin = 3,
    hunter = 4,
    rogue = 5,
    priest = 6,
    shaman = 7,
    mage = 8,
    warlock = 9,
    druid = 10
}

local THEMES = {
    -- Astro - Cosmic purple/violet theme
    astro = {
        background = color.new(15, 10, 30, 220),
        border = color.new(140, 100, 220, 255),
        section_bg = color.new(25, 18, 45, 180),
        section_border = color.new(120, 80, 200, 200),
        primary_accent = color.new(160, 100, 255, 255),
        secondary_accent = color.new(100, 200, 255, 255),
        text_primary = color.new(240, 240, 255, 255),
        text_secondary = color.new(200, 210, 240, 255),
        text_disabled = color.new(110, 100, 130, 255),
        slider_fill = color.new(160, 100, 255, 220),
        slider_bg = color.new(30, 25, 50, 200),
        checkbox_active = color.new(160, 100, 255, 255),
        checkbox_inactive = color.new(55, 45, 75, 200),
        checkbox_border = color.new(120, 80, 200, 200),
        keybind_bg = color.new(28, 20, 48, 220),
        keybind_border = color.new(120, 80, 200, 180),
        keybind_active = color.new(100, 200, 255, 255),
        keybind_inactive = color.new(45, 35, 65, 200),
        separator = color.new(120, 80, 200, 200),
        tab_text_active = color.new(25, 18, 45, 255)
    },
    -- Warrior - Tan/Brown (Class color: #C79C6E)
    warrior = {
        background = color.new(22, 18, 15, 220),
        border = color.new(199, 156, 110, 255),
        section_bg = color.new(30, 25, 20, 180),
        section_border = color.new(180, 140, 95, 200),
        primary_accent = color.new(220, 175, 125, 255),
        secondary_accent = color.new(200, 120, 60, 255),
        text_primary = color.new(245, 240, 230, 255),
        text_secondary = color.new(220, 210, 195, 255),
        text_disabled = color.new(130, 120, 110, 255),
        tab_text_active = color.new(30, 25, 20, 255),
        slider_fill = color.new(220, 175, 125, 220),
        slider_bg = color.new(40, 35, 30, 200),
        checkbox_active = color.new(220, 175, 125, 255),
        checkbox_inactive = color.new(75, 70, 65, 200),
        checkbox_border = color.new(180, 140, 95, 200),
        keybind_bg = color.new(35, 30, 25, 220),
        keybind_border = color.new(180, 140, 95, 180),
        keybind_active = color.new(200, 120, 60, 255),
        keybind_inactive = color.new(60, 55, 50, 200),
        separator = color.new(180, 140, 95, 200)
    },
    -- Paladin - Pink/Rose (Class color: #F58CBA)
    paladin = {
        background = color.new(25, 15, 20, 220),
        border = color.new(245, 140, 186, 255),
        section_bg = color.new(35, 22, 28, 180),
        section_border = color.new(220, 120, 165, 200),
        primary_accent = color.new(255, 150, 200, 255),
        secondary_accent = color.new(255, 215, 100, 255),
        text_primary = color.new(255, 245, 250, 255),
        text_secondary = color.new(240, 220, 230, 255),
        text_disabled = color.new(130, 110, 120, 255),
        tab_text_active = color.new(35, 22, 28, 255),
        slider_fill = color.new(255, 150, 200, 220),
        slider_bg = color.new(45, 35, 40, 200),
        checkbox_active = color.new(255, 150, 200, 255),
        checkbox_inactive = color.new(80, 70, 75, 200),
        checkbox_border = color.new(220, 120, 165, 200),
        keybind_bg = color.new(40, 30, 35, 220),
        keybind_border = color.new(220, 120, 165, 180),
        keybind_active = color.new(255, 215, 100, 255),
        keybind_inactive = color.new(65, 55, 60, 200),
        separator = color.new(220, 120, 165, 200)
    },
    -- Hunter - Green (Class color: #ABD473)
    hunter = {
        background = color.new(20, 24, 18, 220),
        border = color.new(171, 212, 115, 255),
        section_bg = color.new(28, 32, 25, 180),
        section_border = color.new(150, 190, 100, 200),
        primary_accent = color.new(180, 225, 125, 255),
        secondary_accent = color.new(220, 180, 80, 255),
        text_primary = color.new(245, 250, 240, 255),
        text_secondary = color.new(220, 230, 210, 255),
        text_disabled = color.new(120, 130, 115, 255),
        tab_text_active = color.new(28, 32, 25, 255),
        slider_fill = color.new(180, 225, 125, 220),
        slider_bg = color.new(38, 44, 35, 200),
        checkbox_active = color.new(180, 225, 125, 255),
        checkbox_inactive = color.new(75, 82, 70, 200),
        checkbox_border = color.new(150, 190, 100, 200),
        keybind_bg = color.new(33, 39, 30, 220),
        keybind_border = color.new(150, 190, 100, 180),
        keybind_active = color.new(220, 180, 80, 255),
        keybind_inactive = color.new(58, 64, 55, 200),
        separator = color.new(150, 190, 100, 200)
    },
    -- Rogue - Yellow (Class color: #FFF569)
    rogue = {
        background = color.new(22, 22, 15, 220),
        border = color.new(255, 245, 105, 255),
        section_bg = color.new(30, 30, 20, 180),
        section_border = color.new(230, 220, 90, 200),
        primary_accent = color.new(255, 250, 120, 255),
        secondary_accent = color.new(255, 180, 60, 255),
        text_primary = color.new(255, 255, 240, 255),
        text_secondary = color.new(240, 240, 210, 255),
        text_disabled = color.new(130, 130, 110, 255),
        tab_text_active = color.new(30, 30, 20, 255),
        slider_fill = color.new(255, 250, 120, 220),
        slider_bg = color.new(40, 40, 30, 200),
        checkbox_active = color.new(255, 250, 120, 255),
        checkbox_inactive = color.new(80, 80, 65, 200),
        checkbox_border = color.new(230, 220, 90, 200),
        keybind_bg = color.new(35, 35, 25, 220),
        keybind_border = color.new(230, 220, 90, 180),
        keybind_active = color.new(255, 180, 60, 255),
        keybind_inactive = color.new(60, 60, 50, 200),
        separator = color.new(230, 220, 90, 200)
    },
    -- Priest - White/Silver (Class color: #FFFFFF)
    priest = {
        background = color.new(18, 18, 20, 220),
        border = color.new(240, 240, 255, 255),
        section_bg = color.new(25, 25, 28, 180),
        section_border = color.new(210, 210, 230, 200),
        primary_accent = color.new(250, 250, 255, 255),
        secondary_accent = color.new(180, 200, 255, 255),
        text_primary = color.new(255, 255, 255, 255),
        text_secondary = color.new(230, 230, 245, 255),
        text_disabled = color.new(120, 120, 130, 255),
        tab_text_active = color.new(25, 25, 28, 255),
        slider_fill = color.new(250, 250, 255, 220),
        slider_bg = color.new(35, 35, 40, 200),
        checkbox_active = color.new(250, 250, 255, 255),
        checkbox_inactive = color.new(75, 75, 85, 200),
        checkbox_border = color.new(210, 210, 230, 200),
        keybind_bg = color.new(30, 30, 35, 220),
        keybind_border = color.new(210, 210, 230, 180),
        keybind_active = color.new(180, 200, 255, 255),
        keybind_inactive = color.new(55, 55, 65, 200),
        separator = color.new(210, 210, 230, 200)
    },
    -- Shaman - Blue (Class color: #0070DE)
    shaman = {
        background = color.new(12, 18, 25, 220),
        border = color.new(0, 112, 222, 255),
        section_bg = color.new(18, 25, 35, 180),
        section_border = color.new(0, 100, 200, 200),
        primary_accent = color.new(20, 130, 240, 255),
        secondary_accent = color.new(100, 180, 255, 255),
        text_primary = color.new(240, 250, 255, 255),
        text_secondary = color.new(210, 230, 245, 255),
        text_disabled = color.new(100, 120, 135, 255),
        tab_text_active = color.new(18, 25, 35, 255),
        slider_fill = color.new(20, 130, 240, 220),
        slider_bg = color.new(28, 38, 50, 200),
        checkbox_active = color.new(20, 130, 240, 255),
        checkbox_inactive = color.new(60, 75, 90, 200),
        checkbox_border = color.new(0, 100, 200, 200),
        keybind_bg = color.new(23, 33, 45, 220),
        keybind_border = color.new(0, 100, 200, 180),
        keybind_active = color.new(100, 180, 255, 255),
        keybind_inactive = color.new(45, 60, 75, 200),
        separator = color.new(0, 100, 200, 200)
    },
    -- Mage - Cyan/Aqua (Class color: #69CCF0)
    mage = {
        background = color.new(12, 20, 25, 220),
        border = color.new(105, 204, 240, 255),
        section_bg = color.new(18, 28, 35, 180),
        section_border = color.new(90, 185, 220, 200),
        primary_accent = color.new(120, 215, 250, 255),
        secondary_accent = color.new(180, 140, 255, 255),
        text_primary = color.new(240, 252, 255, 255),
        text_secondary = color.new(210, 240, 250, 255),
        text_disabled = color.new(100, 130, 140, 255),
        tab_text_active = color.new(18, 28, 35, 255),
        slider_fill = color.new(120, 215, 250, 220),
        slider_bg = color.new(28, 40, 48, 200),
        checkbox_active = color.new(120, 215, 250, 255),
        checkbox_inactive = color.new(60, 80, 90, 200),
        checkbox_border = color.new(90, 185, 220, 200),
        keybind_bg = color.new(23, 35, 43, 220),
        keybind_border = color.new(90, 185, 220, 180),
        keybind_active = color.new(180, 140, 255, 255),
        keybind_inactive = color.new(45, 65, 75, 200),
        separator = color.new(90, 185, 220, 200)
    },
    -- Warlock - Purple (Class color: #9482C9)
    warlock = {
        background = color.new(18, 15, 25, 220),
        border = color.new(148, 130, 201, 255),
        section_bg = color.new(25, 20, 35, 180),
        section_border = color.new(130, 115, 180, 200),
        primary_accent = color.new(160, 140, 220, 255),
        secondary_accent = color.new(200, 100, 180, 255),
        text_primary = color.new(245, 240, 255, 255),
        text_secondary = color.new(220, 210, 240, 255),
        text_disabled = color.new(120, 110, 135, 255),
        tab_text_active = color.new(25, 20, 35, 255),
        slider_fill = color.new(160, 140, 220, 220),
        slider_bg = color.new(35, 30, 48, 200),
        checkbox_active = color.new(160, 140, 220, 255),
        checkbox_inactive = color.new(70, 65, 85, 200),
        checkbox_border = color.new(130, 115, 180, 200),
        keybind_bg = color.new(30, 25, 43, 220),
        keybind_border = color.new(130, 115, 180, 180),
        keybind_active = color.new(200, 100, 180, 255),
        keybind_inactive = color.new(55, 50, 70, 200),
        separator = color.new(130, 115, 180, 200)
    },
    -- Druid - Orange (Class color: #FF7D0A)
    druid = {
        background = color.new(25, 18, 12, 220),
        border = color.new(255, 125, 10, 255),
        section_bg = color.new(35, 25, 18, 180),
        section_border = color.new(230, 110, 10, 200),
        primary_accent = color.new(255, 140, 30, 255),
        secondary_accent = color.new(180, 220, 80, 255),
        text_primary = color.new(255, 245, 235, 255),
        text_secondary = color.new(240, 220, 200, 255),
        text_disabled = color.new(130, 115, 100, 255),
        tab_text_active = color.new(35, 25, 18, 255),
        slider_fill = color.new(255, 140, 30, 220),
        slider_bg = color.new(45, 35, 28, 200),
        checkbox_active = color.new(255, 140, 30, 255),
        checkbox_inactive = color.new(80, 70, 60, 200),
        checkbox_border = color.new(230, 110, 10, 200),
        keybind_bg = color.new(40, 30, 23, 220),
        keybind_border = color.new(230, 110, 10, 180),
        keybind_active = color.new(180, 220, 80, 255),
        keybind_inactive = color.new(65, 55, 48, 200),
        separator = color.new(230, 110, 10, 200)
    }
}

-- ============================================================================
-- KEY NAME MAPPING
-- ============================================================================

local KEY_NAMES = {
    -- Windows virtual-key codes
    [1] = "LMB",
    [2] = "RMB",
    [4] = "MMB",
    [5] = "Mouse4",
    [6] = "Mouse5",
    [8] = "Backspace",
    [9] = "Tab",
    [13] = "Enter",
    [16] = "Shift",
    [17] = "Ctrl",
    [18] = "Alt",
    [20] = "CapsLock",
    [27] = "Esc",
    [32] = "Space",
    [33] = "PgUp",
    [34] = "PgDn",
    [35] = "End",
    [36] = "Home",
    [37] = "Left",
    [38] = "Up",
    [39] = "Right",
    [40] = "Down",
    [45] = "Insert",
    [46] = "Delete",
    [96] = "Num0",
    [97] = "Num1",
    [98] = "Num2",
    [99] = "Num3",
    [100] = "Num4",
    [101] = "Num5",
    [102] = "Num6",
    [103] = "Num7",
    [104] = "Num8",
    [105] = "Num9",
    [112] = "F1",
    [113] = "F2",
    [114] = "F3",
    [115] = "F4",
    [116] = "F5",
    [117] = "F6",
    [118] = "F7",
    [119] = "F8",
    [120] = "F9",
    [121] = "F10",
    [122] = "F11",
    [123] = "F12",
    [999] = "None"
}

return {
    LAYOUT = LAYOUT,
    THEMES = THEMES,
    THEME_NAMES = THEME_NAMES,
    THEME_INDEX = THEME_INDEX,
    KEY_NAMES = KEY_NAMES,
}


