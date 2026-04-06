---@meta simple_ui
--- simple_ui v2.0.0 — LuaLS type annotations
--- Place this file in your workspace for IDE autocompletion.

------------------------------------------------------------------------
-- CONSTANTS
------------------------------------------------------------------------

---@class simple_ui_vk
---@field LBUTTON  integer  0x01
---@field RBUTTON  integer  0x02
---@field MBUTTON  integer  0x04
---@field BACK     integer  0x08
---@field TAB      integer  0x09
---@field RETURN   integer  0x0D
---@field SHIFT    integer  0x10
---@field CONTROL  integer  0x11
---@field ALT      integer  0x12
---@field ESCAPE   integer  0x1B
---@field SPACE    integer  0x20
---@field END_KEY  integer  0x23
---@field HOME     integer  0x24
---@field LEFT     integer  0x25
---@field UP       integer  0x26
---@field RIGHT    integer  0x27
---@field DOWN     integer  0x28
---@field DELETE   integer  0x2E

---@class simple_ui_settings
---@field debug_mode          boolean
---@field auto_save_enabled   boolean
---@field default_font_size   number
---@field default_spacing     number
---@field default_padding     number
---@field title_bar_height    number
---@field component_height    number
---@field slider_handle_width number

---@class simple_ui_colors
---@field window_bg       color
---@field title_bar       color
---@field component_bg    color
---@field border          color
---@field border_hover    color
---@field border_focus    color
---@field text            color
---@field text_dim        color
---@field text_disabled   color
---@field text_title      color
---@field accent          color
---@field accent_hover    color
---@field accent_pressed  color
---@field hover           color
---@field pressed         color
---@field selected        color
---@field success         color
---@field warning         color
---@field error           color
---@field checkbox_bg     color
---@field checkbox_check  color
---@field slider_track    color
---@field slider_fill     color
---@field slider_handle   color
---@field separator       color
---@field progress_bg     color
---@field progress_fill   color

---@class simple_ui_text_align
---@field LEFT   integer  0
---@field CENTER integer  1
---@field RIGHT  integer  2

---@class simple_ui_component_type
---@field CHECKBOX    string
---@field SLIDER      string
---@field BUTTON      string
---@field LABEL       string
---@field TEXTINPUT   string
---@field COMBOBOX    string
---@field KEYBIND     string
---@field COLORPICKER string
---@field HEADER      string
---@field TREENODE    string
---@field LISTBOX     string
---@field PROGRESSBAR string
---@field SEPARATOR   string

---@class simple_ui_constants
---@field color          table
---@field vec2           table
---@field VK             simple_ui_vk
---@field SETTINGS       simple_ui_settings
---@field TEXT_ALIGN     simple_ui_text_align
---@field COLORS         simple_ui_colors
---@field COMPONENT_TYPE simple_ui_component_type

------------------------------------------------------------------------
-- HELPERS
------------------------------------------------------------------------

---@class simple_ui_helpers
---Generates a unique id string with optional prefix.
---@field generate_id       fun(prefix?: string): string
---Resets the internal id counter to 0.
---@field reset_id_counter  fun()
---Returns true if point (px, py) is inside rectangle (rx, ry, rw, rh).
---@field point_in_rect     fun(px: number, py: number, rx: number, ry: number, rw: number, rh: number): boolean
---Clamps value between min and max.
---@field clamp             fun(value: number, min: number, max: number): number
---Linear interpolation from a to b by factor t.
---@field lerp              fun(a: number, b: number, t: number): number
---Rounds num to the given number of decimal places.
---@field round             fun(num: number, decimals?: number): number
---Maps value from input range to output range.
---@field map_range         fun(value: number, in_min: number, in_max: number, out_min: number, out_max: number): number
---Deep copies a table recursively.
---@field deep_copy         fun(orig: table): table
---Shallow merges two tables; t2 keys override t1.
---@field merge_tables      fun(t1?: table, t2?: table): table
---Returns a new color with the given alpha, keeping r/g/b from col.
---@field color_with_alpha  fun(col: color, alpha: number): color
---Returns a new color lightened by amount.
---@field lighten_color     fun(col: color, amount: number): color
---Returns a new color darkened by amount.
---@field darken_color      fun(col: color, amount: number): color
---Truncates string to max_length, appending suffix (default "...").
---@field truncate_string   fun(str: string, max_length: number, suffix?: string): string
---Returns a human-readable name for a virtual key code.
---@field get_key_name      fun(key_code: integer): string

------------------------------------------------------------------------
-- INPUT
------------------------------------------------------------------------

---@class simple_ui_input
---Polls hardware state. Called automatically by menu:update().
---@field update              fun()
---Returns current mouse x and y.
---@field get_mouse_pos       fun(): number, number
---Returns true if mouse is inside the given rectangle.
---@field is_mouse_in_rect    fun(x: number, y: number, w: number, h: number): boolean
---Returns true while the left mouse button is held.
---@field is_left_down        fun(): boolean
---Returns true on the frame left mouse button was pressed.
---@field is_left_clicked     fun(): boolean
---Returns true on the frame left mouse button was released.
---@field is_left_released    fun(): boolean
---Returns true while the right mouse button is held.
---@field is_right_down       fun(): boolean
---Returns true on the frame right mouse button was pressed.
---@field is_right_clicked    fun(): boolean
---Returns true while Ctrl is held.
---@field is_ctrl_down        fun(): boolean
---Returns true while Shift is held.
---@field is_shift_down       fun(): boolean
---Returns true while Alt is held.
---@field is_alt_down         fun(): boolean
---Returns true while the given key code is held.
---@field is_key_pressed      fun(key_code: integer): boolean
---Returns true on the frame the given key was pressed (edge-triggered).
---@field is_key_just_pressed fun(key_code: integer): boolean
---Returns the first currently pressed key code (for keybind capture), or nil.
---@field get_pressed_key     fun(): integer|nil
---Returns the raw mouse state table.
---@field get_mouse_state     fun(): table
---Prevents the game from receiving keyboard input this frame.
---@field capture_keyboard    fun()
---Returns a typed character on new key press (shift-aware), or nil.
---@field get_typed_char      fun(): string|nil

------------------------------------------------------------------------
-- RENDERING
------------------------------------------------------------------------

---@class simple_ui_rendering
---Draws a filled rectangle with optional corner radius.
---@field rect_filled    fun(x: number, y: number, w: number, h: number, col: color, radius?: number)
---Draws a rectangle outline with optional thickness and corner radius.
---@field rect           fun(x: number, y: number, w: number, h: number, col: color, thickness?: number, radius?: number)
---Draws text at (x, y). Optionally centered horizontally.
---@field text           fun(x: number, y: number, text_str: string, col: color, size?: number, centered?: boolean)
---Draws a line between two points.
---@field line           fun(x1: number, y1: number, x2: number, y2: number, col: color, thickness?: number)
---Draws a complete window frame (background + title bar + border).
---@field window         fun(x: number, y: number, w: number, h: number, title_height?: number)
---Draws a styled button rectangle with centered text.
---@field button         fun(x: number, y: number, w: number, h: number, text_str: string, is_hovered: boolean, is_pressed: boolean, style?: string)
---Draws a checkbox square with optional check mark.
---@field checkbox       fun(x: number, y: number, size: number, checked: boolean, is_hovered: boolean)
---Draws a slider track, fill, and handle.
---@field slider         fun(x: number, y: number, w: number, h: number, percent: number, is_hovered: boolean, is_dragging: boolean)
---Draws a progress bar with fill.
---@field progress_bar   fun(x: number, y: number, w: number, h: number, percent: number, col?: color)
---Draws a horizontal separator line.
---@field separator      fun(x: number, y: number, w: number)
---Draws a text input field box.
---@field text_input     fun(x: number, y: number, w: number, h: number, text_str: string, is_focused: boolean, is_hovered: boolean)
---Draws a combobox control with arrow indicator.
---@field combobox       fun(x: number, y: number, w: number, h: number, text_str: string, is_open: boolean, is_hovered: boolean)
---Draws a single dropdown list item.
---@field dropdown_item  fun(x: number, y: number, w: number, h: number, text_str: string, is_selected: boolean, is_hovered: boolean)

------------------------------------------------------------------------
-- BASE COMPONENT
------------------------------------------------------------------------

---@class base_component
---Returns whether the component is both visible and enabled.
---@field is_active       fun(self: base_component): boolean
---Returns whether the parent menu currently has input focus.
---@field menu_has_focus   fun(self: base_component): boolean
---Sets the component position.
---@field set_position     fun(self: base_component, x: number, y: number)
---Sets the component size.
---@field set_size         fun(self: base_component, width: number, height: number)
---Sets the component label text.
---@field set_text         fun(self: base_component, text: string)
---Sets component visibility.
---@field set_visible      fun(self: base_component, visible: boolean)
---Sets whether the component accepts input.
---@field set_enabled      fun(self: base_component, enabled: boolean)
---Returns absolute screen x (component x + menu x).
---@field get_abs_x        fun(self: base_component): number
---Returns absolute screen y (component y + menu y).
---@field get_abs_y        fun(self: base_component): number
---Returns bounding box as {x, y, width, height}.
---@field get_bounds       fun(self: base_component): table
---Returns true if screen point (px, py) is inside the component.
---@field contains_point   fun(self: base_component, px: number, py: number): boolean
---Updates hover state from current mouse position.
---@field update_hover     fun(self: base_component): boolean
---Fires the on_click callback.
---@field handle_click     fun(self: base_component)
---Override: per-frame logic.
---@field update           fun(self: base_component)
---Override: per-frame drawing.
---@field render           fun(self: base_component)
---Override: draws overlay elements (dropdowns etc.) after all components.
---@field render_overlay   fun(self: base_component)
---Override: returns true if component has an active overlay capturing input.
---@field has_overlay      fun(self: base_component): boolean
---Override: returns the component's current value.
---@field get_value        fun(self: base_component): any
---Override: sets the component's value.
---@field set_value        fun(self: base_component, value: any)
---Persists the current value via the parent menu's save system.
---@field save_value       fun(self: base_component)
---Loads a previously saved value, or applies default.
---@field load_value       fun(self: base_component, default?: any): boolean
---@field type        string
---@field id          string
---@field name        string
---@field x           number
---@field y           number
---@field width       number
---@field height      number
---@field text        string
---@field text_color  color
---@field visible     boolean
---@field enabled     boolean
---@field is_hovered  boolean
---@field is_focused  boolean
---@field is_pressed  boolean
---@field on_click    fun(self: base_component)|nil
---@field on_change   fun(self: base_component, ...)|nil
---@field on_hover    fun(self: base_component)|nil
---@field auto_save   boolean
---@field parent_menu menu|nil
---@field data        table

------------------------------------------------------------------------
-- MENU
------------------------------------------------------------------------

---@class menu
---@field title            string
---@field save_key         string
---@field width            number
---@field height           number
---@field min_height       number
---@field auto_height      boolean
---@field x                number
---@field y                number
---@field is_open          boolean
---@field is_collapsed     boolean
---@field is_dragging      boolean
---@field components       table<string, base_component>
---@field component_order  string[]
---@field next_y           number
---@field saved_data       table
local menu = {}

---Creates a new menu window.
---@param title     string   Window title
---@param width     number?  Window width (default 300)
---@param height    number?  Window min height (default 400)
---@param save_key  string?  Unique persistence key
---@return menu
function menu:new(title, width, height, save_key) end

---Processes input, dragging, focus, and all component updates. Call once per frame.
---@return nil
function menu:update() end

---Draws the window and all visible components. Call once per frame.
---@return nil
function menu:render() end

---Opens the menu.
function menu:show() end

---Closes the menu.
function menu:hide() end

---Toggles the menu open/closed.
function menu:toggle() end

---Collapses to title bar only.
function menu:collapse() end

---Expands from collapsed state.
function menu:expand() end

---Toggles collapsed state.
function menu:toggle_collapse() end

---Returns the current rendered height (title bar height if collapsed).
---@return number
function menu:get_display_height() end

---Returns the next auto-layout y coordinate.
---@param spacing number?
---@return number
function menu:get_next_y(spacing) end

---Advances the auto-layout y cursor.
---@param height  number
---@param spacing number?
function menu:advance_y(height, spacing) end

---Recalculates menu height to fit content.
function menu:update_height() end

---Generates a unique id.
---@param prefix string?
---@return string
function menu:generate_id(prefix) end

---Adds a component instance to the menu.
---@param component base_component
---@return base_component
function menu:add_component(component) end

---Gets a component by its id.
---@param id string
---@return base_component|nil
function menu:get_component(id) end

---Removes a component by its id.
---@param id string
function menu:remove_component(id) end

---Removes all components and resets layout.
function menu:clear_components() end

---Persists a component value.
---@param id    string
---@param value any
function menu:save_component(id, value) end

---Retrieves a previously saved component value.
---@param id string
---@return any
function menu:load_component(id) end

---Saves all menu state to file.
function menu:save_all() end

---Loads all menu state from file.
function menu:load_all() end

---Returns true if the mouse cursor is over this menu.
---@return boolean
function menu:is_mouse_over() end

-- menu:add_* shortcut methods -----------------------------------------

---Adds a label component.
---@param text    string
---@param x       number?
---@param y       number?
---@param options table?
---@return label
function menu:add_label(text, x, y, options) end

---Adds a separator component.
---@param x       number?
---@param y       number?
---@param options table?
---@return separator
function menu:add_separator(x, y, options) end

---Adds a header component.
---@param text    string
---@param x       number?
---@param y       number?
---@param options table?
---@return header
function menu:add_header(text, x, y, options) end

---Adds a checkbox component.
---@param text     string
---@param x        number?
---@param y        number?
---@param default  boolean?
---@param callback fun(self: checkbox, checked: boolean)?
---@param options  table?
---@return checkbox
function menu:add_checkbox(text, x, y, default, callback, options) end

---Adds a slider component.
---@param text     string
---@param x        number?
---@param y        number?
---@param min      number
---@param max      number
---@param default  number
---@param callback fun(self: slider, value: number)?
---@param options  table?
---@return slider
function menu:add_slider(text, x, y, min, max, default, callback, options) end

---Adds a button component.
---@param text     string
---@param x        number?
---@param y        number?
---@param width    number?
---@param height   number?
---@param callback fun(self: button)?
---@param options  table?
---@return button
function menu:add_button(text, x, y, width, height, callback, options) end

---Adds a progress bar component.
---@param text      string
---@param x         number?
---@param y         number?
---@param value     number?
---@param max_value number?
---@param options   table?
---@return progressbar
function menu:add_progressbar(text, x, y, value, max_value, options) end

---Adds a text input component.
---@param text     string
---@param x        number?
---@param y        number?
---@param default  string?
---@param callback fun(self: textinput, value: string)?
---@param options  table?
---@return textinput
function menu:add_textinput(text, x, y, default, callback, options) end

---Adds a combobox component.
---@param text     string
---@param x        number?
---@param y        number?
---@param items    string[]
---@param default  integer?
---@param callback fun(self: combobox, index: integer, text: string)?
---@param options  table?
---@return combobox
function menu:add_combobox(text, x, y, items, default, callback, options) end

---Adds a keybind component.
---@param text     string
---@param x        number?
---@param y        number?
---@param default  integer?
---@param callback fun(self: keybind, key_code: integer)?
---@param options  table?
---@return keybind
function menu:add_keybind(text, x, y, default, callback, options) end

---Adds a color picker component.
---@param text     string
---@param x        number?
---@param y        number?
---@param default  table?   {r=number, g=number, b=number, a=number}
---@param callback fun(self: colorpicker, color: color)?
---@param options  table?
---@return colorpicker
function menu:add_colorpicker(text, x, y, default, callback, options) end

---Adds a tree node component.
---@param text     string
---@param x        number?
---@param y        number?
---@param default  boolean?
---@param callback fun(self: treenode, is_expanded: boolean)?
---@param options  table?
---@return treenode
function menu:add_treenode(text, x, y, default, callback, options) end

---Adds a listbox component.
---@param text     string
---@param x        number?
---@param y        number?
---@param items    string[]
---@param default  integer?
---@param callback fun(self: listbox, value: any, selected_text: any)?
---@param options  table?
---@return listbox
function menu:add_listbox(text, x, y, items, default, callback, options) end

------------------------------------------------------------------------
-- COMPONENT TYPES
------------------------------------------------------------------------

---@class label : base_component
---@field font_size  number
---@field centered   boolean
---Returns the label text.
---@field get_value  fun(self: label): string
---Sets the label text.
---@field set_value  fun(self: label, value: string)

---@class separator : base_component
---Always returns nil.
---@field get_value  fun(self: separator): nil

---@class header : base_component
---@field font_size  number
---@field show_line  boolean
---Returns the header text.
---@field get_value  fun(self: header): string
---Sets the header text.
---@field set_value  fun(self: header, value: string)

---@class checkbox : base_component
---@field checked   boolean
---@field box_size  number
---Toggles the checked state and fires on_change.
---@field toggle     fun(self: checkbox)
---Returns whether checked.
---@field is_checked fun(self: checkbox): boolean
---Returns the checked state.
---@field get_value  fun(self: checkbox): boolean
---Sets the checked state.
---@field set_value  fun(self: checkbox, value: boolean)

---@class slider : base_component
---@field min_value    number
---@field max_value    number
---@field value        number
---@field slider_type  string   "int"|"float"
---@field decimals     number
---@field track_height number
---@field show_value   boolean
---@field is_dragging  boolean
---Returns 0..1 fill ratio.
---@field get_percentage    fun(self: slider): number
---Sets value by 0..1 ratio.
---@field set_percentage    fun(self: slider, percent: number)
---Returns formatted display string.
---@field get_display_value fun(self: slider): string
---Returns the numeric value.
---@field get_value         fun(self: slider): number
---Sets the numeric value (clamped to range).
---@field set_value         fun(self: slider, value: number)
---Sets min and max, clamping current value.
---@field set_range         fun(self: slider, min: number, max: number)

---@class button : base_component
---@field style     string   "default"|"primary"
---Programmatically fires the on_click callback.
---@field click     fun(self: button)
---Always returns nil.
---@field get_value fun(self: button): nil

---@class progressbar : base_component
---@field value      number
---@field max_value  number
---@field show_text  boolean
---@field fill_color color
---Returns 0..1 fill ratio.
---@field get_percentage fun(self: progressbar): number
---Returns the current value.
---@field get_value      fun(self: progressbar): number
---Sets the current value (clamped to 0..max_value).
---@field set_value      fun(self: progressbar, value: number)
---Sets the maximum value.
---@field set_max        fun(self: progressbar, max: number)

---@class textinput : base_component
---@field value       string
---@field placeholder string
---@field max_length  number
---@field cursor_pos  number
---@field select_all  boolean
---@field is_focused  boolean
---Appends text to the end of the current value.
---@field append    fun(self: textinput, text: string)
---Clears the value to empty string.
---@field clear     fun(self: textinput)
---Returns the current text value.
---@field get_value fun(self: textinput): string
---Sets the text value.
---@field set_value fun(self: textinput, value: string)

---@class combobox : base_component
---@field items          string[]
---@field selected_index integer
---@field max_visible    integer
---@field item_height    number
---@field is_open        boolean
---Returns the text of the currently selected item.
---@field get_selected_text fun(self: combobox): string
---Selects item by 1-based index.
---@field set_selected      fun(self: combobox, index: integer)
---Appends an item string.
---@field add_item          fun(self: combobox, item: string)
---Removes an item by index.
---@field remove_item       fun(self: combobox, index: integer)
---Replaces the entire items list.
---@field set_items         fun(self: combobox, items: string[])
---Returns the selected 1-based index.
---@field get_value         fun(self: combobox): integer
---Sets the selected index.
---@field set_value         fun(self: combobox, value: integer)

---@class keybind : base_component
---@field key          integer
---@field is_toggle    boolean
---@field toggle_state boolean
---@field is_capturing boolean
---Returns human-readable key name ("A", "F1", "None", etc.).
---@field get_key_name fun(self: keybind): string
---Returns true while the bound key is held.
---@field is_pressed   fun(self: keybind): boolean
---Returns the current state (hold or toggle depending on is_toggle).
---@field check        fun(self: keybind): boolean
---Returns the bound virtual key code.
---@field get_value    fun(self: keybind): integer
---Sets the bound key code.
---@field set_value    fun(self: keybind, value: integer)

---@class colorpicker : base_component
---@field r            number  0-255
---@field g            number  0-255
---@field b            number  0-255
---@field a            number  0-255
---@field preview_size number
---@field is_open      boolean
---Returns the color as a color object.
---@field get_color  fun(self: colorpicker): color
---Sets rgba values directly.
---@field set_color  fun(self: colorpicker, r: number, g: number, b: number, a: number)
---Returns {r, g, b, a} table.
---@field get_value  fun(self: colorpicker): table
---Sets value from {r, g, b, a} table.
---@field set_value  fun(self: colorpicker, value: table)

---@class treenode : base_component
---@field is_expanded boolean
---@field children    treenode[]
---@field indent      number
---@field indent_size number
---Toggles expanded state.
---@field toggle          fun(self: treenode)
---Expands the node.
---@field expand          fun(self: treenode)
---Collapses the node.
---@field collapse        fun(self: treenode)
---Adds a child treenode, setting indent and parent.
---@field add_child       fun(self: treenode, child: treenode): treenode
---Removes a child by index.
---@field remove_child    fun(self: treenode, index: integer)
---Returns total height including expanded children.
---@field get_total_height fun(self: treenode): number
---Returns the expanded state.
---@field get_value       fun(self: treenode): boolean
---Sets the expanded state.
---@field set_value       fun(self: treenode, value: boolean)

---@class listbox : base_component
---@field items            string[]
---@field selected_index   integer
---@field multi_select     boolean
---@field selected_indices integer[]
---@field item_height      number
---@field scroll_offset    integer
---Returns true if the given 1-based index is selected.
---@field is_item_selected  fun(self: listbox, index: integer): boolean
---Selects (or toggles in multi_select mode) the given index.
---@field select_item       fun(self: listbox, index: integer)
---Returns the selected text (string or table of strings for multi).
---@field get_selected_text fun(self: listbox): string|string[]
---Scrolls up one item.
---@field scroll_up         fun(self: listbox)
---Scrolls down one item.
---@field scroll_down       fun(self: listbox)
---Appends an item string.
---@field add_item          fun(self: listbox, item: string)
---Removes an item by index.
---@field remove_item       fun(self: listbox, index: integer)
---Replaces the entire items list and resets selection.
---@field set_items         fun(self: listbox, items: string[])
---Returns selected index (single) or table of indices (multi).
---@field get_value         fun(self: listbox): integer|integer[]
---Sets selected index or indices.
---@field set_value         fun(self: listbox, value: integer|integer[])

------------------------------------------------------------------------
-- SIMPLE_UI MODULE
------------------------------------------------------------------------

---@class simple_ui
---@field constants      simple_ui_constants
---@field helpers        simple_ui_helpers
---@field input          simple_ui_input
---@field rendering      simple_ui_rendering
---@field base_component base_component
---@field menu           menu
---@field label          label
---@field separator      separator
---@field header         header
---@field checkbox       checkbox
---@field slider         slider
---@field button         button
---@field progressbar    progressbar
---@field textinput      textinput
---@field combobox       combobox
---@field keybind        keybind
---@field colorpicker    colorpicker
---@field treenode       treenode
---@field listbox        listbox
---@field COLORS         simple_ui_colors
---@field SETTINGS       simple_ui_settings
---@field VERSION        string

---@type simple_ui
local tbl
return tbl
