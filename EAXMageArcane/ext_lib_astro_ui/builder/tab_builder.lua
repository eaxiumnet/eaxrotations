-- ext_lib_astro_ui/tab_builder.lua
-- TabBuilder class (builder pattern for UI components) + build_tab_section helper

local constants = require("ext_lib_astro_ui/core/constants")
local LAYOUT = constants.LAYOUT

-- ============================================================================
-- TAB BUILDER CLASS
-- ============================================================================

---@class rotation_settings_ui_tab_builder
---@field _ui rotation_settings_ui
---@field _section table
local TabBuilder = {}
TabBuilder.__index = TabBuilder

---@param ui rotation_settings_ui
---@param section table
---@return rotation_settings_ui_tab_builder
function TabBuilder.new(ui, section)
    return setmetatable({ _ui = ui, _section = section }, TabBuilder)
end

function TabBuilder:_add_group(group)
    if not group or not group.type then
        return self
    end
    self._section.groups = self._section.groups or {}
    table.insert(self._section.groups, group)
    return self
end

---@param opts table {label?, columns?, elements, visible_when?}
function TabBuilder:checkbox_grid(opts)
    return self:_add_group({
        type = "checkbox_grid",
        label = opts and opts.label or nil,
        columns = opts and opts.columns or nil,
        elements = opts and opts.elements or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil
    })
end

---@param opts table {label?, elements: table|fun():table, visible_when?}
function TabBuilder:runtime_checkbox_list(opts)
    return self:_add_group({
        type = "runtime_checkbox_list",
        label = opts and opts.label or nil,
        elements = opts and opts.elements or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil
    })
end

---@param opts table {label?, elements, visible_when?}
function TabBuilder:slider_list(opts)
    return self:_add_group({
        type = "slider_list",
        label = opts and opts.label or nil,
        elements = opts and opts.elements or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil
    })
end

---@param opts table {label?, elements, visible_when?}
function TabBuilder:combo_list(opts)
    return self:_add_group({
        type = "combo_list",
        label = opts and opts.label or nil,
        elements = opts and opts.elements or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil
    })
end

---@param opts table {label?, elements, visible_when?}
function TabBuilder:text_input_list(opts)
    return self:_add_group({
        type = "text_input_list",
        label = opts and opts.label or nil,
        elements = opts and opts.elements or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil
    })
end

---@param opts table {label?, elements, visible_when?}
function TabBuilder:color_list(opts)
    return self:_add_group({
        type = "color_list",
        label = opts and opts.label or nil,
        elements = opts and opts.elements or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil
    })
end

---@param opts table {elements, labels?, visible_when?}
function TabBuilder:keybind_grid(opts)
    return self:_add_group({
        type = "keybind_grid",
        elements = opts and opts.elements or nil,
        labels = opts and opts.labels or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil
    })
end

---@param opts table {text: string, font_id?: integer, color?: color, visible_when?: fun():boolean, page?: any, subpage?: any}
function TabBuilder:text(opts)
    return self:_add_group({
        type = "text",
        text = opts and opts.text or "",
        font_id = opts and opts.font_id or nil,
        color = opts and opts.color or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil
    })
end

---@param opts table|nil {height?: number, thickness?: number, color?: color, visible_when?: fun():boolean, page?: any, subpage?: any}
function TabBuilder:separator(opts)
    return self:_add_group({
        type = "separator",
        height = opts and opts.height or nil,
        thickness = opts and opts.thickness or nil,
        color = opts and opts.color or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil
    })
end

---@param opts table {label: string, on_click: fun(), visible_when?: fun():boolean, page?: any, subpage?: any}
function TabBuilder:button(opts)
    return self:_add_group({
        type = "button",
        button_label = opts and opts.label or "",
        on_click = opts and opts.on_click or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil
    })
end

---@param opts table { items: table[], width?: number, label?: string }
function TabBuilder:side_menu(opts)
    if not opts or type(opts) ~= "table" then
        return self
    end
    self._section.side_menu = {
        items = opts.items or {},
        width = opts.width,
        label = opts.label
    }
    return self
end

function TabBuilder:spacer(opts)
    return self:_add_group({
        type = "spacer",
        height = opts and opts.height or LAYOUT.section_spacing,
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:label(opts)
    return self:_add_group({
        type = "label",
        text = opts and opts.text or "",
        font_id = opts and opts.font_id or nil,
        color = opts and opts.color or nil,
        align = opts and opts.align or "left",
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:toggle_list(opts)
    return self:_add_group({
        type = "toggle_list",
        label = opts and opts.label or nil,
        elements = opts and opts.elements or {},
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:radio_group(opts)
    return self:_add_group({
        type = "radio_group",
        label = opts and opts.label or nil,
        element = opts and opts.element or nil,
        options = opts and opts.options or {},
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:progress_bar(opts)
    return self:_add_group({
        type = "progress_bar",
        label = opts and opts.label or nil,
        value_fn = opts and opts.value_fn or nil,
        suffix = opts and opts.suffix or "%",
        bar_color = opts and opts.color or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:icon_button(opts)
    return self:_add_group({
        type = "icon_button",
        icon = opts and opts.icon or "?",
        button_label = opts and opts.label or "",
        on_click = opts and opts.on_click or nil,
        width = opts and opts.width or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:list_box(opts)
    return self:_add_group({
        type = "list_box",
        label = opts and opts.label or nil,
        items_fn = opts and opts.items_fn or nil,
        element = opts and opts.element or nil,
        height = opts and opts.height or 120,
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:spinner(opts)
    return self:_add_group({
        type = "spinner",
        label = opts and opts.label or nil,
        active_fn = opts and opts.active_fn or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:skeleton(opts)
    return self:_add_group({
        type = "skeleton",
        rows = opts and opts.rows or 3,
        row_height = opts and opts.row_height or LAYOUT.element_height,
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:panel(opts, build_fn)
    local panel_section = { groups = {} }
    if build_fn and type(build_fn) == "function" then
        local inner = TabBuilder.new(self._ui, panel_section)
        pcall(build_fn, inner)
    end
    return self:_add_group({
        type = "panel",
        label = opts and opts.label or nil,
        bg_color = opts and opts.bg_color or nil,
        border_color = opts and opts.border_color or nil,
        padding = opts and opts.padding or 10,
        children = panel_section.groups,
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:card(opts, build_fn)
    local card_section = { groups = {} }
    if build_fn and type(build_fn) == "function" then
        local inner = TabBuilder.new(self._ui, card_section)
        pcall(build_fn, inner)
    end
    return self:_add_group({
        type = "card",
        label = opts and opts.label or nil,
        children = card_section.groups,
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:hstack(opts, build_fn)
    local stack_section = { groups = {} }
    if build_fn and type(build_fn) == "function" then
        local inner = TabBuilder.new(self._ui, stack_section)
        pcall(build_fn, inner)
    end
    return self:_add_group({
        type = "hstack",
        spacing = opts and opts.spacing or LAYOUT.column_spacing,
        children = stack_section.groups,
        visible_when = opts and opts.visible_when or nil,
        page = opts and opts.page or nil
    })
end

function TabBuilder:range_slider_list(opts)
    return self:_add_group({
        type = "range_slider_list",
        label = opts and opts.label or nil,
        elements = opts and opts.elements or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil
    })
end

function TabBuilder:data_table(opts)
    return self:_add_group({
        type = "data_table",
        id = opts and opts.id or nil,
        label = opts and opts.label or nil,
        columns = opts and opts.columns or {},
        rows = opts and opts.rows or nil,
        rows_fn = opts and opts.rows_fn or nil,
        max_height = opts and opts.max_height or nil,
        sortable = opts and opts.sortable or false,
        element = opts and opts.element or nil,
        row_height = opts and opts.row_height or nil,
        stripe = (opts == nil or opts.stripe == nil) and true or opts.stripe,
        on_row_click = opts and opts.on_row_click or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil,
    })
end

function TabBuilder:context_trigger(opts)
    return self:_add_group({
        type = "context_trigger",
        label = opts and opts.label or nil,
        items = opts and opts.items or {},
        width = opts and opts.width or nil,
        height = opts and opts.height or nil,
        visible_when = opts and opts.visible_when or nil,
        page = opts and (opts.page or opts.subpage) or nil,
    })
end

-- ============================================================================
-- BUILD TAB SECTION HELPER
-- ============================================================================

local function build_tab_section(tab_info, build_fn, ui)
    if not tab_info or not tab_info.id or not tab_info.label then
        return nil
    end
    local section = {
        id = tab_info.id,
        label = tab_info.label,
        type = "tab",
        groups = {},
        visible_when = tab_info.visible_when
    }
    if build_fn and type(build_fn) == "function" then
        local builder = TabBuilder.new(ui, section)
        pcall(build_fn, builder)
    end
    section.__is_extension_tab = tab_info.__is_extension_tab == true
    return section
end

return {
    TabBuilder = TabBuilder,
    build_tab_section = build_tab_section,
}
