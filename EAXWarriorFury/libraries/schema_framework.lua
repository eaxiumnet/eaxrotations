--[[
    schema_framework.lua

    Schema-driven settings framework for EAX specs.

    The framework allows specs to define their settings once as a schema table
    and automatically generate Sylvanas menu controls, fetch runtime values,
    and migrate legacy menu tables without losing saved user preferences.

    Usage:
        local schema_framework = require("libraries/schema_framework")
        local schema = schema_framework.new("eaxwarriorfury")

        schema:define({
            sections = {
                {
                    id = "controls",
                    label = "Controls",
                    settings = {
                        { type = "checkbox", key = "enabled", default = true, label = "Enabled" },
                        { type = "keybind", key = "toggle_key", default = 7, label = "Toggle Key" },
                        { type = "dropdown", key = "mode", default = "auto",
                          options = {
                              { value = "auto", label = "Auto" },
                              { value = "pve", label = "PvE" },
                              { value = "pvp", label = "PvP" },
                          }
                        },
                    },
                },
            },
        })

        schema:migrate_legacy(require("libraries/menu"))
        local generated = schema:generate_menu()
        local enabled = schema:get("enabled")
        schema:set("enabled", true)
]]

local schema_framework = {}

---@class EAXSchemaInstance
---@field namespace string
---@field _schema_defined boolean
---@field _sections table
---@field _registry table<string, table>
---@field _controls table<string, table>
---@field _legacy_controls table<string, table>
---@field _legacy_values table<string, any>
---@field _pending_values table<string, any>
---@field _pending_legacy_menu table|nil
---@field _menu_table table|nil
---@field _generated_sections table|nil
local SchemaInstance = {}
SchemaInstance.__index = SchemaInstance

local _core = core or {}
local _menu_api = (_core.menu) or {}
local _log_warning = _core.log_warning or _core.log or function() end

local _checkbox = _menu_api.checkbox
local _slider_int = _menu_api.slider_int
local _slider_float = _menu_api.slider_float
local _combobox = _menu_api.combobox
local _keybind = _menu_api.keybind

local SUPPORTED_TYPES = {
    checkbox = true,
    slider_int = true,
    slider_float = true,
    dropdown = true,
    keybind = true,
}

local DEFAULT_KEYBIND = 7

local function clamp(value, min_val, max_val)
    if min_val ~= nil and value < min_val then
        value = min_val
    end
    if max_val ~= nil and value > max_val then
        value = max_val
    end
    return value
end

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function call_control(control, method_names)
    if not control then
        return nil
    end

    for i = 1, #method_names do
        local method = control[method_names[i]]
        if type(method) == "function" then
            local ok, result = pcall(method, control)
            if ok then
                return result
            end
        end
    end

    return nil
end

local function normalize_dropdown_options(raw_options, key)
    local normalized = {}
    local value_lookup = {}

    if type(raw_options) ~= "table" then
        error("Dropdown setting '" .. key .. "' requires an options table")
    end

    for idx, option in ipairs(raw_options) do
        local value = option
        local label = nil
        if type(option) == "table" then
            value = option.value
            label = option.label or option.text
            if value == nil and option[1] ~= nil then
                value = option[1]
            end
            if not label and option[2] ~= nil then
                label = option[2]
            end
        end

        if value == nil then
            value = idx
        end
        if not label then
            label = tostring(value)
        end

        normalized[idx] = { value = value, label = label }
        value_lookup[value] = idx
    end

    if #normalized == 0 then
        error("Dropdown setting '" .. key .. "' must include at least one option")
    end

    return normalized, value_lookup
end

local function normalize_setting(namespace, raw)
    if type(raw) ~= "table" then
        error("Schema settings must be tables")
    end

    local setting_type = raw.type
    if not SUPPORTED_TYPES[setting_type] then
        error("Unsupported schema setting type: " .. tostring(setting_type))
    end

    local key = tostring(raw.key or "")
    if key == "" then
        error("Schema setting is missing a 'key' field")
    end

    local normalized = {
        key = key,
        type = setting_type,
        label = raw.label or key,
        tooltip = raw.tooltip or "",
        description = raw.description,
        id = raw.id or (namespace .. "_" .. key),
        min = raw.min,
        max = raw.max,
        step = raw.step,
    }

    if setting_type == "checkbox" then
        normalized.default_value = raw.default == nil and false or raw.default == true
    elseif setting_type == "slider_int" then
        normalized.min = raw.min or 0
        normalized.max = raw.max or 100
        normalized.step = raw.step or 1
        local def = raw.default
        if def == nil then
            def = normalized.min
        end
        normalized.default_value = round(clamp(def, normalized.min, normalized.max))
    elseif setting_type == "slider_float" then
        normalized.min = raw.min or 0
        normalized.max = raw.max or 100
        normalized.step = raw.step or 0.1
        local def = raw.default
        if def == nil then
            def = normalized.min
        end
        normalized.default_value = clamp(def, normalized.min, normalized.max)
    elseif setting_type == "dropdown" then
        local options, lookup = normalize_dropdown_options(raw.options, key)
        normalized.options = options
        normalized.dropdown_value_lookup = lookup

        local default_value = raw.default
        local default_index = nil
        if default_value ~= nil then
            if type(default_value) == "number" and options[default_value] then
                default_index = default_value
                default_value = options[default_index].value
            else
                default_index = lookup[default_value]
            end
        end

        if not default_index then
            default_index = 1
            default_value = options[default_index].value
        end

        normalized.default_index = default_index
        normalized.default_value = default_value
    elseif setting_type == "keybind" then
        local def = raw.default
        local default_key = DEFAULT_KEYBIND
        if type(def) == "number" then
            default_key = def
        elseif type(def) == "table" and def.key_code then
            default_key = def.key_code
        end
        normalized.default_value = default_key
        normalized.require_modifier = raw.require_modifier == true
    end

    return normalized
end

local function normalize_sections(namespace, section_def)
    local raw_sections = section_def.sections or section_def
    if type(raw_sections) ~= "table" then
        error("Schema definition requires a 'sections' array")
    end

    local normalized_sections = {}
    local registry = {}

    for index, raw_section in ipairs(raw_sections) do
        local section = {
            id = raw_section.id or ("section_" .. index),
            label = raw_section.label or ("Section " .. index),
            description = raw_section.description or "",
            settings = {},
        }

        local settings = raw_section.settings or raw_section.items or {}
        if type(settings) ~= "table" then
            error("Section '" .. section.id .. "' is missing a settings list")
        end

        for _, raw_setting in ipairs(settings) do
            local normalized_setting = normalize_setting(namespace, raw_setting)
            normalized_setting.section_id = section.id
            section.settings[#section.settings + 1] = normalized_setting
            registry[normalized_setting.key] = normalized_setting
        end

        normalized_sections[#normalized_sections + 1] = section
    end

    return normalized_sections, registry
end

local function dropdown_index_for_value(setting, value)
    if value == nil then
        return setting.default_index or 1
    end

    if type(value) == "number" and setting.options[value] then
        return value
    end

    return setting.dropdown_value_lookup and setting.dropdown_value_lookup[value]
end

local function ensure_menu_function(fn, name)
    if type(fn) ~= "function" then
        error("core.menu." .. name .. " is not available")
    end
end

ensure_menu_function(_checkbox, "checkbox")
ensure_menu_function(_slider_int, "slider_int")
ensure_menu_function(_slider_float, "slider_float")
ensure_menu_function(_combobox, "combobox")
ensure_menu_function(_keybind, "keybind")

--------------------------------------------------------------------------------
-- SchemaInstance methods
--------------------------------------------------------------------------------

function SchemaInstance:define(schema_definition)
    local sections, registry = normalize_sections(self.namespace, schema_definition or {})
    self._schema_defined = true
    self._sections = sections
    self._registry = registry
    self._controls = {}
    self._legacy_controls = self._legacy_controls or {}
    self._legacy_values = self._legacy_values or {}
    self._pending_values = self._pending_values or {}

    if self._pending_legacy_menu then
        self:_ingest_legacy(self._pending_legacy_menu)
    end

    return self
end

function SchemaInstance:_ingest_legacy(old_menu)
    if type(old_menu) ~= "table" or not self._registry then
        return
    end

    self._legacy_controls = self._legacy_controls or {}
    self._legacy_values = self._legacy_values or {}

    for key, setting in pairs(self._registry) do
        local legacy_control = old_menu[key]
        if legacy_control then
            self._legacy_controls[key] = legacy_control
            local value = self:_read_control_value(legacy_control, setting)
            if value ~= nil then
                self._legacy_values[key] = value
            end
        end
    end
end

function SchemaInstance:migrate_legacy(old_menu)
    if type(old_menu) ~= "table" then
        _log_warning("schema_framework: migrate_legacy expected a menu table")
        return self
    end

    self._pending_legacy_menu = old_menu
    if self._schema_defined then
        self:_ingest_legacy(old_menu)
    end

    return self
end

function SchemaInstance:_create_control(setting, initial_value)
    local control
    if setting.type == "checkbox" then
        local default_value = initial_value
        if default_value == nil then
            default_value = setting.default_value
        end
        control = _checkbox(default_value, setting.id)
    elseif setting.type == "slider_int" then
        local default_value = initial_value
        if default_value == nil then
            default_value = setting.default_value
        end
        default_value = round(clamp(default_value, setting.min, setting.max))
        control = _slider_int(setting.min, setting.max, default_value, setting.id)
    elseif setting.type == "slider_float" then
        local default_value = initial_value
        if default_value == nil then
            default_value = setting.default_value
        end
        default_value = clamp(default_value, setting.min, setting.max)
        control = _slider_float(setting.min, setting.max, default_value, setting.id)
    elseif setting.type == "dropdown" then
        local default_value = initial_value
        if default_value == nil then
            default_value = setting.default_value
        end
        local default_index = dropdown_index_for_value(setting, default_value) or setting.default_index or 1
        control = _combobox(default_index, setting.id)
    elseif setting.type == "keybind" then
        local default_value = initial_value
        if type(default_value) ~= "number" then
            default_value = setting.default_value or DEFAULT_KEYBIND
        end
        control = _keybind(default_value, setting.require_modifier or false, setting.id)
    end

    return control
end

function SchemaInstance:_apply_pending_values()
    if not self._pending_values then
        return
    end

    for key, value in pairs(self._pending_values) do
        self:set(key, value)
    end
end

function SchemaInstance:generate_menu(options)
    if not self._schema_defined then
        error("schema_framework: define() must be called before generate_menu()")
    end

    options = options or {}
    local menu_table = options.menu or self._menu_table or {}
    local generated_sections = {}

    for _, section in ipairs(self._sections or {}) do
        local section_entry = {
            id = section.id,
            label = section.label,
            description = section.description,
            settings = {},
        }

        for _, setting in ipairs(section.settings) do
            local control = self._legacy_controls and self._legacy_controls[setting.key]
            if not control then
                control = self:_create_control(setting, self._legacy_values and self._legacy_values[setting.key])
            end

            self._controls[setting.key] = control
            menu_table[setting.key] = control

            section_entry.settings[#section_entry.settings + 1] = {
                key = setting.key,
                label = setting.label,
                tooltip = setting.tooltip,
                control = control,
                metadata = setting,
            }
        end

        generated_sections[#generated_sections + 1] = section_entry
    end

    self._menu_table = menu_table
    self._generated_sections = generated_sections
    self:_apply_pending_values()

    return {
        menu = menu_table,
        sections = generated_sections,
    }
end

function SchemaInstance:_coerce_value(setting, value)
    if setting.type == "checkbox" then
        if type(value) ~= "boolean" then
            if value == nil then
                return true, setting.default_value
            end
            return nil, "Checkbox settings require boolean values"
        end
        return true, value
    elseif setting.type == "slider_int" then
        if type(value) ~= "number" then
            return nil, "slider_int settings require numeric values"
        end
        return true, round(clamp(value, setting.min, setting.max))
    elseif setting.type == "slider_float" then
        if type(value) ~= "number" then
            return nil, "slider_float settings require numeric values"
        end
        return true, clamp(value, setting.min, setting.max)
    elseif setting.type == "dropdown" then
        if value == nil then
            return true, setting.default_value
        end
        if setting.dropdown_value_lookup and setting.dropdown_value_lookup[value] then
            return true, value
        end
        if type(value) == "number" then
            local option = setting.options and setting.options[value]
            if option then
                return true, option.value
            end
        end
        return nil, "Invalid dropdown value for key '" .. setting.key .. "'"
    elseif setting.type == "keybind" then
        if type(value) == "table" and type(value.key_code) == "number" then
            return true, value.key_code
        end
        if type(value) == "number" then
            return true, value
        end
        return nil, "Keybind values must be numeric key codes"
    end

    return nil, "Unknown setting type"
end

function SchemaInstance:_apply_value_to_control(control, setting, value)
    if not control then
        return false, "Control not generated yet"
    end

    local ok, err
    if setting.type == "checkbox" then
        local setter = control.set or control.set_state
        if not setter then
            return false, "Checkbox control does not support set()"
        end
        ok, err = pcall(setter, control, value)
    elseif setting.type == "slider_int" or setting.type == "slider_float" then
        local setter = control.set or control.set_value
        if not setter then
            return false, "Slider control does not support set()"
        end
        ok, err = pcall(setter, control, value)
    elseif setting.type == "dropdown" then
        local setter = control.set or control.set_state
        if not setter then
            return false, "Dropdown control does not support set()"
        end
        local index = dropdown_index_for_value(setting, value)
        if not index then
            return false, "Invalid dropdown value for key '" .. setting.key .. "'"
        end
        ok, err = pcall(setter, control, index)
    elseif setting.type == "keybind" then
        local setter = control.set_key_code or control.set
        if not setter then
            return false, "Keybind control does not support updating key codes"
        end
        ok, err = pcall(setter, control, value)
    else
        return false, "Unsupported setting type for set()"
    end

    if not ok then
        return false, err
    end

    return true
end

function SchemaInstance:set(key, value)
    if not self._registry or not self._registry[key] then
        return false, "Unknown schema key: " .. tostring(key)
    end

    local setting = self._registry[key]
    local ok, coerced = self:_coerce_value(setting, value)
    if not ok then
        return false, coerced
    end

    local control = self._controls and self._controls[key]
    if not control then
        self._pending_values = self._pending_values or {}
        self._pending_values[key] = coerced
        return true
    end

    local applied, err = self:_apply_value_to_control(control, setting, coerced)
    if not applied then
        return false, err
    end

    return true
end

function SchemaInstance:_read_control_value(control, setting)
    if not control then
        return nil
    end

    if setting.type == "checkbox" then
        local value = call_control(control, { "get_state", "get" })
        if value == nil then
            return nil
        end
        return value == true
    elseif setting.type == "slider_int" then
        local value = call_control(control, { "get", "get_value" })
        if type(value) ~= "number" then
            return nil
        end
        return round(clamp(value, setting.min, setting.max))
    elseif setting.type == "slider_float" then
        local value = call_control(control, { "get", "get_value" })
        if type(value) ~= "number" then
            return nil
        end
        return clamp(value, setting.min, setting.max)
    elseif setting.type == "dropdown" then
        local index = call_control(control, { "get", "get_state" })
        if type(index) ~= "number" then
            return nil
        end
        local option = setting.options and setting.options[index]
        if not option then
            return nil
        end
        return option.value
    elseif setting.type == "keybind" then
        local key_code = call_control(control, { "get_key_code" })
        if type(key_code) ~= "number" then
            return nil
        end
        return key_code
    end

    return nil
end

function SchemaInstance:get(key)
    if not self._registry or not self._registry[key] then
        return nil
    end

    local setting = self._registry[key]
    local control = (self._controls and self._controls[key]) or (self._legacy_controls and self._legacy_controls[key])
    local value

    if control then
        value = self:_read_control_value(control, setting)
    elseif self._pending_values and self._pending_values[key] ~= nil then
        value = self._pending_values[key]
    elseif self._legacy_values and self._legacy_values[key] ~= nil then
        value = self._legacy_values[key]
    else
        value = setting.default_value
    end

    if value == nil then
        return setting.default_value
    end

    local ok, coerced = self:_coerce_value(setting, value)
    if not ok then
        _log_warning("schema_framework: Failed to coerce value for key '" .. key .. "' - " .. tostring(coerced))
        return setting.default_value
    end

    return coerced
end

function SchemaInstance:get_sections()
    return self._generated_sections or self._sections or {}
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function schema_framework.new(namespace)
    namespace = tostring(namespace or "eaxschema")
    if namespace == "" then
        namespace = "eaxschema"
    end

    return setmetatable({
        namespace = namespace,
        _schema_defined = false,
        _sections = {},
        _registry = {},
        _controls = {},
        _legacy_controls = {},
        _legacy_values = {},
        _pending_values = {},
    }, SchemaInstance)
end

return schema_framework
