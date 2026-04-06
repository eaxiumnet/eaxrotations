-- ext_lib_astro_ui/presets.lua
-- Preset system: serialization, file I/O, and footer rendering

local constants = require("ext_lib_astro_ui/core/constants")
local helpers = require("ext_lib_astro_ui/core/helpers")
local RotationSettingsUI = require("ext_lib_astro_ui/core/class")

---@type color
local color = require("common/color")
---@type vec2
local vec2 = require("common/geometry/vector_2")
---@type enums
local enums = require("common/enums")

local LAYOUT = constants.LAYOUT
local lighten_color = helpers.lighten_color
local is_mouse_clicked_left = helpers.is_mouse_clicked_left

-- ============================================================================
-- PRESET SYSTEM — Built-in preset save/load/serialize engine
-- ============================================================================

local PRESET_FOLDER_ROOT = "bungee_presets"
local PRESET_NAME_KEY = "__name__"

local function preset_build_type_map(registry)
    local map = {}
    for i = 1, #registry do
        local entry = registry[i]
        if entry and entry.element then
            map[entry.element] = entry.type_tag
        end
    end
    return map
end

local function preset_collect(menu_elements, registry)
    local type_map = preset_build_type_map(registry)
    local snapshot = {}

    for key, element in pairs(menu_elements) do
        local tag = type_map[element]
        if tag == "checkbox" then
            local ok, val = pcall(element.get_state, element)
            if ok then
                snapshot[key] = { type = "b", value = val }
            end
        elseif tag == "slider" then
            local ok, val = pcall(element.get, element)
            if ok then
                snapshot[key] = { type = "i", value = val }
            end
        elseif tag == "combobox" then
            local ok, val = pcall(element.get, element)
            if ok then
                snapshot[key] = { type = "c", value = val }
            end
        elseif tag == "keybind" then
            local ok_k, kc = pcall(element.get_key_code, element)
            local ok_t, ts = pcall(element.get_toggle_state, element)
            if ok_k and ok_t then
                snapshot[key] = {
                    type = "k",
                    value = tostring(kc or 999) .. "|" .. tostring(ts == true)
                }
            end
        end
    end

    return snapshot
end

local function preset_apply(menu_elements, snapshot, registry)
    local type_map = preset_build_type_map(registry)

    for key, entry in pairs(snapshot) do
        if key ~= PRESET_NAME_KEY then
            local element = menu_elements[key]
            if element then
                local tag = type_map[element] or entry.type
                if tag == "b" or tag == "checkbox" then
                    pcall(element.set, element, entry.value == true or entry.value == "true")
                elseif tag == "i" or tag == "slider" then
                    pcall(element.set, element, tonumber(entry.value) or 0)
                elseif tag == "c" or tag == "combobox" then
                    pcall(element.set, element, tonumber(entry.value) or 1)
                elseif tag == "k" or tag == "keybind" then
                    local val_str = tostring(entry.value)
                    local kc_str, ts_str = val_str:match("^(.-)%|(.*)$")
                    if kc_str then
                        pcall(element.set_key, element, tonumber(kc_str) or 999)
                        pcall(element.set_toggle_state, element, ts_str == "true")
                    end
                end
            end
        end
    end
end

local function preset_serialize(snapshot, name)
    local lines = {}
    if name and #name > 0 then
        lines[#lines + 1] = PRESET_NAME_KEY .. "=" .. name
    end

    local keys = {}
    for k in pairs(snapshot) do
        keys[#keys + 1] = k
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
        local entry = snapshot[key]
        if entry and entry.type then
            lines[#lines + 1] = entry.type .. ":" .. key .. "=" .. tostring(entry.value)
        end
    end

    return table.concat(lines, "\n")
end

local function preset_deserialize(str)
    if not str or #str == 0 then
        return {}, nil
    end

    local snapshot = {}
    local name = nil

    for line in str:gmatch("[^\r\n]+") do
        local name_val = line:match("^" .. PRESET_NAME_KEY .. "=(.*)$")
        if name_val then
            name = name_val
        else
            local type_tag, key, value = line:match("^(%a):(.-)=(.*)$")
            if type_tag and key then
                if type_tag == "b" then
                    snapshot[key] = { type = "b", value = value == "true" }
                elseif type_tag == "i" or type_tag == "c" then
                    snapshot[key] = { type = type_tag, value = tonumber(value) or 0 }
                elseif type_tag == "k" then
                    snapshot[key] = { type = "k", value = value }
                end
            end
        end
    end

    return snapshot, name
end

local function preset_file_path(rotation_id, slot)
    return PRESET_FOLDER_ROOT .. "/" .. rotation_id .. "/preset_" .. slot .. ".txt"
end

local function preset_ensure_folders(rotation_id)
    pcall(core.create_data_folder, PRESET_FOLDER_ROOT)
    pcall(core.create_data_folder, PRESET_FOLDER_ROOT .. "/" .. rotation_id)
end

local function preset_save(rotation_id, slot, name, menu_elements, registry)
    local snapshot = preset_collect(menu_elements, registry)
    local data = preset_serialize(snapshot, name)
    preset_ensure_folders(rotation_id)
    local path = preset_file_path(rotation_id, slot)
    pcall(core.create_data_file, path)
    local ok = pcall(core.write_data_file, path, data)
    if ok and core.log then
        core.log("[Presets] Saved preset " .. slot .. " (" .. (name or "") .. ")")
    end
    return ok
end

local function preset_load(rotation_id, slot, menu_elements, registry)
    local path = preset_file_path(rotation_id, slot)
    local ok, data = pcall(core.read_data_file, path)
    if not ok or not data or #data == 0 then
        if core.log then
            core.log("[Presets] Slot " .. slot .. " is empty.")
        end
        return nil, false
    end

    local snapshot, name = preset_deserialize(data)
    preset_apply(menu_elements, snapshot, registry)

    if core.log then
        core.log("[Presets] Loaded preset " .. slot .. " (" .. (name or "") .. ")")
    end
    return name, true
end

local function preset_read_name(rotation_id, slot)
    local path = preset_file_path(rotation_id, slot)
    local ok, data = pcall(core.read_data_file, path)
    if not ok or not data or #data == 0 then
        return nil
    end
    return data:match("^" .. PRESET_NAME_KEY .. "=([^\r\n]*)")
end

-- ============================================================================
-- PRESET PUBLIC API & STATE
-- ============================================================================

---@class preset_state
---@field menu_elements table
---@field md any
---@field registry table
---@field selector table|nil
---@field name_inputs table[]
---@field dropdown_open boolean
---@field names_loaded boolean

---Enable preset system for this UI instance
---@param menu_elements table Menu elements for preset collection/apply
---@param md_instance any Metadata instance with get_registry()
function RotationSettingsUI:enable_presets(menu_elements, md_instance)
    if not menu_elements or not md_instance then
        return
    end

    self._preset = {
        menu_elements = menu_elements,
        md = md_instance,
        registry = md_instance.get_registry(),
        -- Simple internal state for preset selection (replaces core.menu.combobox)
        selector = {
            value = 1,
            get = function(self) return self.value end,
            set = function(self, v) self.value = v end,
        },
        -- Simple internal state for name inputs (replaces core.menu.text_input)
        name_inputs = {
            { text = "", get_text = function(self) return self.text end, set_text = function(self, v) self.text = v end },
            { text = "", get_text = function(self) return self.text end, set_text = function(self, v) self.text = v end },
            { text = "", get_text = function(self) return self.text end, set_text = function(self, v) self.text = v end },
        },
        dropdown_open = false,
        names_loaded = false,
    }
end

function RotationSettingsUI:_load_preset_names()
    if not self._preset or self._preset.names_loaded then
        return
    end
    self._preset.names_loaded = true

    for slot = 1, 3 do
        local name = preset_read_name(self.id, slot)
        if name and #name > 0 then
            pcall(function()
                self._preset.name_inputs[slot]:set_text(name)
            end)
        else
            pcall(function()
                self._preset.name_inputs[slot]:set_text("")
            end)
        end
    end
end

function RotationSettingsUI:_preset_slot_label(slot)
    if not self._preset then
        return "Preset " .. slot
    end
    local ok, text = pcall(function()
        return self._preset.name_inputs[slot]:get_text()
    end)
    if ok and text and #text > 0 then
        return slot .. ": " .. text
    end
    return slot .. ": (empty)"
end

function RotationSettingsUI:_preset_selected_slot()
    if not self._preset or not self._preset.selector then
        return 1
    end
    local ok, val = pcall(function()
        return self._preset.selector:get()
    end)
    if ok and val and val >= 1 and val <= 3 then
        return val
    end
    return 1
end

function RotationSettingsUI:_save_current_preset()
    if not self._preset then
        return
    end
    local slot = self:_preset_selected_slot()
    local ok_name, name = pcall(function()
        return self._preset.name_inputs[slot]:get_text()
    end)
    if not ok_name or not name or #name == 0 then
        name = "Preset " .. slot
    end

    preset_save(
        self.id, slot, name,
        self._preset.menu_elements,
        self._preset.registry
    )
end

function RotationSettingsUI:_load_current_preset()
    if not self._preset then
        return
    end
    local slot = self:_preset_selected_slot()
    local name, loaded = preset_load(
        self.id, slot,
        self._preset.menu_elements,
        self._preset.registry
    )
    if loaded and name and #name > 0 then
        pcall(function()
            self._preset.name_inputs[slot]:set_text(name)
        end)
    end
end

function RotationSettingsUI:_reset_to_defaults()
    if not self._preset or not self._preset.md then
        return
    end
    self._preset.md.reset_all()
end

function RotationSettingsUI:export_profile()
    if not self._preset then return end

    local snapshot = preset_collect(self._preset.menu_elements, self._preset.registry)
    local profile_str = preset_serialize(snapshot, self.id .. "_Profile")

    local success = false
    if self.window and self.window.copy_to_clipboard then
        local ok = pcall(function() self.window:copy_to_clipboard(profile_str) end)
        if ok then
            success = true
            if core.graphics.add_notification then
                core.graphics.add_notification(
                    "profile_export_" .. self.id,
                    "Profile Exported",
                    "Rotation settings copied to clipboard.",
                    4,
                    color.new(100, 205, 100, 255)
                )
            end
        end
    end

    if self._preset.menu_elements.profile_string then
        pcall(function() self._preset.menu_elements.profile_string:set(profile_str) end)
    end

    if not success then
        if core.graphics.add_notification then
            core.graphics.add_notification(
                "profile_export_manual_" .. self.id,
                "Profile Generated",
                "Please copy from 'Profile String' box.",
                5,
                color.new(255, 200, 50, 255)
            )
        end
        if core.log then
            core.log("[RotationUI] Profile generated. Manual copy required.")
        end
    else
        if core.log then
            core.log("[RotationUI] Profile exported to clipboard.")
        end
    end
end

function RotationSettingsUI:import_profile(profile_str)
    if not self._preset or not profile_str or #profile_str == 0 then return end

    local snapshot, name = preset_deserialize(profile_str)
    if snapshot and next(snapshot) then
        preset_apply(self._preset.menu_elements, snapshot, self._preset.registry)

        if core.graphics.add_notification then
            core.graphics.add_notification(
                "profile_import_" .. self.id,
                "Profile Imported",
                "Rotation settings updated successfully.",
                4,
                color.new(100, 205, 100, 255)
            )
        end
        if core.log then
            core.log("[RotationUI] Profile imported: " .. (name or "Unnamed"))
        end
    else
        if core.log then
            core.log_error("[RotationUI] Import failed: Invalid profile string.")
        end
    end
end

function RotationSettingsUI:import_from_clipboard()
    local window = self.window
    if window and window.get_clipboard_text then
        local str = nil
        local ok = pcall(function() str = window:get_clipboard_text() end)

        if ok and str and #str > 0 then
            self:import_profile(str)
        else
            if core.graphics.add_notification then
                core.graphics.add_notification(
                    "profile_import_fail_" .. self.id,
                    "Import Failed",
                    "Clipboard is empty or inaccessible.",
                    5,
                    color.new(255, 100, 100, 255)
                )
            end
            if core.log then
                core.log_error("[RotationUI] Import failed: Clipboard is empty or inaccessible.")
            end
        end
    else
        if core.graphics.add_notification then
            core.graphics.add_notification(
                "profile_import_unsupported_" .. self.id,
                "Import Unused",
                "Paste into 'Profile String' box manually.",
                5,
                color.new(255, 100, 100, 255)
            )
        end
        if core.log then
            core.log_error("[RotationUI] Import failed: Get clipboard text function not found on window.")
        end
    end
end

-- ============================================================================
-- PRESET FOOTER RENDERING
-- ============================================================================

function RotationSettingsUI:_render_preset_btn(label, x, y, w, h)
    local start = vec2.new(x, y)
    local endp = vec2.new(x + w, y + h)

    local hovered = false
    do
        local mouse_pos = select(1, self:_get_window_local_mouse_pos("adjusted"))
        if mouse_pos then
            hovered = mouse_pos.x >= start.x and mouse_pos.x <= endp.x
                and mouse_pos.y >= start.y and mouse_pos.y <= endp.y
        else
            hovered = self.window:is_mouse_hovering_rect(start, endp)
        end
    end
    self.window:is_mouse_hovering_rect_block_movement(start, endp)

    local bg = hovered and lighten_color(self.colors.slider_bg, 20) or self.colors.slider_bg
    self.window:render_rect_filled(start, endp, bg, 2.0)
    local border = hovered and self.colors.secondary_accent or self.colors.primary_accent
    self.window:render_rect(start, endp, border, 2.0, 1.0)

    local sz = self.window:get_text_size(label)
    local tx = x + (w - sz.x) / 2
    local ty = y + (h - sz.y) / 2
    self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(tx, ty),
        self.colors.text_primary, label)

    local clicked = false
    if hovered and is_mouse_clicked_left(self.window) then
        clicked = true
    elseif self.window:is_rect_clicked(start, endp) then
        clicked = true
    end

    if clicked then
        self.window:block_input_capture()
    end
    return clicked
end

function RotationSettingsUI:_render_preset_dropdown_closed(x, y, w, h)
    local slot = self:_preset_selected_slot()
    local label = self:_preset_slot_label(slot)

    local start = vec2.new(x, y)
    local endp = vec2.new(x + w, y + h)

    local hovered = self.window:is_mouse_hovering_rect(start, endp)
    self.window:is_mouse_hovering_rect_block_movement(start, endp)

    local bg = hovered and lighten_color(self.colors.slider_bg, 20) or self.colors.slider_bg
    self.window:render_rect_filled(start, endp, bg, 1.5)
    local border = hovered and self.colors.secondary_accent or self.colors.primary_accent
    self.window:render_rect(start, endp, border, 1.5, 1.0)

    local max_text_w = w - 20
    local display = label
    local txt_size = self.window:get_text_size(display)
    if txt_size.x > max_text_w then
        while #display > 1 do
            display = display:sub(1, -2)
            local ts = self.window:get_text_size(display .. "..")
            if ts.x <= max_text_w then
                display = display .. ".."
                txt_size = ts
                break
            end
        end
        if #display <= 1 then
            display = display .. ".."
            txt_size = self.window:get_text_size(display)
        end
    end

    local tx = x + 6
    local ty = y + (h - txt_size.y) / 2
    self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(tx, ty),
        self.colors.text_secondary, display)

    local arrow = "v"
    local arrow_sz = self.window:get_text_size(arrow)
    self.window:render_text(enums.window_enums.font_id.FONT_SMALL,
        vec2.new(x + w - arrow_sz.x - 6, ty), self.colors.text_secondary, arrow)

    if self.window:is_rect_clicked(start, endp) then
        self._preset.dropdown_open = not self._preset.dropdown_open
        self.window:block_input_capture()
    end
end

function RotationSettingsUI:_render_preset_dropdown_overlay()
    if not self._preset or not self._preset.dropdown_open then
        return
    end

    local window_size = self.window:get_size()
    local x = LAYOUT.padding_side
    local footer_y = window_size.y - LAYOUT.preset_footer_height
    local w = LAYOUT.preset_dropdown_width
    local option_h = LAYOUT.preset_row_height
    local list_h = 3 * option_h
    local list_padding = 2

    local list_start = vec2.new(x, footer_y - list_h - list_padding)
    local list_end = vec2.new(x + w, footer_y - list_padding)

    self.window:render_rect_filled(list_start, list_end,
        self.colors.background or color.new(20, 20, 30, 240), 2.0)
    self.window:render_rect(list_start, list_end,
        self.colors.primary_accent, 2.0, 1.0)

    local list_hovered = self.window:is_mouse_hovering_rect(list_start, list_end)
    self.window:is_mouse_hovering_rect_block_movement(list_start, list_end)

    local dd_box_start = vec2.new(x, footer_y + LAYOUT.preset_footer_padding)
    local dd_box_end = vec2.new(x + w, footer_y + LAYOUT.preset_footer_padding + LAYOUT.preset_row_height)
    local box_hovered = self.window:is_mouse_hovering_rect(dd_box_start, dd_box_end)

    if is_mouse_clicked_left(self.window) and not list_hovered and not box_hovered then
        self._preset.dropdown_open = false
        return
    end

    local current_slot = self:_preset_selected_slot()

    for slot = 1, 3 do
        local oy = list_start.y + (slot - 1) * option_h
        local opt_start = vec2.new(list_start.x + 1, oy)
        local opt_end = vec2.new(list_end.x - 1, oy + option_h)

        local opt_hovered = self.window:is_mouse_hovering_rect(opt_start, opt_end)
        self.window:is_mouse_hovering_rect_block_movement(opt_start, opt_end)

        local is_active = (slot == current_slot)
        local bg_col = is_active and self.colors.primary_accent
            or (opt_hovered and lighten_color(self.colors.slider_bg, 15) or self.colors.slider_bg)
        self.window:render_rect_filled(opt_start, opt_end, bg_col, 1.0)

        local slot_label = self:_preset_slot_label(slot)
        local sz = self.window:get_text_size(slot_label)
        local tx = opt_start.x + 6
        local ty = oy + (option_h - sz.y) / 2
        local txt_col = is_active and (self.colors.tab_text_active or color.white(255)) or self.colors.text_primary
        self.window:render_text(enums.window_enums.font_id.FONT_SMALL, vec2.new(tx, ty), txt_col, slot_label)

        if self.window:is_rect_clicked(opt_start, opt_end) then
            pcall(function() self._preset.selector:set(slot) end)
            self._preset.dropdown_open = false
            self.window:block_input_capture()
        end
    end
end

function RotationSettingsUI:_render_preset_footer()
    if not self._preset or not self.window then
        return
    end

    self:_load_preset_names()

    local window_size = self.window:get_size()
    local footer_y = window_size.y - LAYOUT.preset_footer_height
    local pad = LAYOUT.preset_footer_padding
    local x_start = LAYOUT.padding_side
    local btn_w = LAYOUT.preset_button_width
    local btn_h = LAYOUT.preset_row_height
    local btn_sp = LAYOUT.preset_button_spacing
    local dd_w = LAYOUT.preset_dropdown_width

    self.window:render_rect_filled(
        vec2.new(x_start, footer_y),
        vec2.new(window_size.x - LAYOUT.padding_side, footer_y + 2),
        self.colors.separator, 0)

    local row1_y = footer_y + pad

    self:_render_preset_dropdown_closed(x_start, row1_y, dd_w, btn_h)

    local btn_x = x_start + dd_w + btn_sp

    if self:_render_preset_btn("Load", btn_x, row1_y, btn_w, btn_h) then
        self:_load_current_preset()
    end
    btn_x = btn_x + btn_w + btn_sp

    if self:_render_preset_btn("Save", btn_x, row1_y, btn_w, btn_h) then
        self:_save_current_preset()
    end
    btn_x = btn_x + btn_w + btn_sp

    if self:_render_preset_btn("Reset", btn_x, row1_y, btn_w, btn_h) then
        self:_reset_to_defaults()
    end

    local row2_y = row1_y + btn_h + LAYOUT.preset_row_spacing
    local slot = self:_preset_selected_slot()
    local name_element = self._preset.name_inputs[slot]

    local name_label = "Name:"
    local name_label_sz = self.window:get_text_size(name_label)
    local label_y = row2_y + (btn_h - name_label_sz.y) / 2
    self.window:render_text(enums.window_enums.font_id.FONT_SMALL,
        vec2.new(x_start, label_y), self.colors.text_primary, name_label)

    local input_x = x_start + name_label_sz.x + 8
    local input_w = math.min(LAYOUT.preset_name_input_width,
        window_size.x - input_x - LAYOUT.padding_side)

    if name_element then
        local input_offset = vec2.new(input_x, row2_y - 2)
        local ok_prev, prev_offset = pcall(function()
            return self.window:get_current_context_dynamic_drawing_offset()
        end)

        local ok_set = pcall(function()
            self.window:set_current_context_dynamic_drawing_offset(input_offset)
        end)

        if ok_set then
            pcall(function()
                if name_element.render_custom then
                    name_element:render_custom("##preset_name", "",
                        self.colors.slider_bg, self.colors.primary_accent,
                        self.colors.secondary_accent, self.colors.text_primary,
                        input_w, 0)
                elseif name_element.render then
                    name_element:render("##preset_name", "")
                end
            end)
        end

        if ok_prev and prev_offset then
            pcall(function()
                self.window:set_current_context_dynamic_drawing_offset(prev_offset)
            end)
        end
    end
end
