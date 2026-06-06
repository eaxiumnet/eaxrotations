-- ============================================================================
-- Shared Helper: APL-to-Registry Bridge
-- ============================================================================
-- What:   Thin bridge between apl_parser.parse_apl() and NS.rotation_registry.
-- When:   Module load (utility). Called by spec files that want SimC APL support.
-- Why:    Eliminate boilerplate when wiring APL strings into the rotation system.
-- Safety: Read-only delegation. No state mutation beyond registry registration.
--         Uses io.open only via apl_parser (already audited).

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local M = {}

-- Lazy-load the parser to avoid load-order issues
local _parser = nil
local function parser()
    if not _parser then
        local ok, mod = pcall(require, "shared/apl_parser")
        if ok and type(mod) == "table" then
            _parser = mod
        end
    end
    return _parser
end

--- Parse a SimC APL string and register the resulting strategies with the rotation registry.
--- @param spec_name string   Spec identifier (e.g. "shadow", "frost")
--- @param apl_text string    SimC-format APL text
--- @param build_state function  State builder: function(context) -> state_table
--- @param config table|nil   Optional config overrides (mapping, spell_map, class_label, compile_functions)
--- @return table|nil strategies  Compiled strategy array, or nil on error
function M.register_apl(spec_name, apl_text, build_state, config)
    local p = parser()
    if not p then
        NS.error("[APL] apl_parser not available")
        return nil
    end

    if not spec_name or not apl_text or not build_state then
        NS.error("[APL] register_apl requires spec_name, apl_text, build_state")
        return nil
    end

    -- Validate first
    local ok, result = pcall(p.validate, apl_text, config or {})
    if ok and result and not result.ok then
        local errs = table.concat(result.errors or {}, "; ")
        NS.error("[APL] Validation failed for " .. spec_name .. ": " .. errs)
        return nil
    end

    -- Parse with compiled functions
    local parse_config = {}
    if config then
        for k, v in pairs(config) do parse_config[k] = v end
    end
    parse_config.compile_functions = true

    local strategies, err = p.parse_apl(apl_text, parse_config)
    if not strategies then
        NS.error("[APL] Parse failed for " .. spec_name .. ": " .. tostring(err))
        return nil
    end

    -- Register with rotation registry
    if NS.rotation_registry and NS.rotation_registry.register then
        NS.rotation_registry:register(spec_name, strategies, { get_state = build_state })
    end

    return strategies
end

--- Parse an APL string without registering (for inspection/testing).
--- @param apl_text string  SimC-format APL text
--- @param config table|nil Optional config
--- @return table|nil strategies
function M.parse_only(apl_text, config)
    local p = parser()
    if not p then return nil end

    local parse_config = {}
    if config then
        for k, v in pairs(config) do parse_config[k] = v end
    end
    parse_config.compile_functions = true

    return p.parse_apl(apl_text, parse_config)
end

--- Validate an APL string without parsing.
--- @param apl_text string  SimC-format APL text
--- @param config table|nil Optional config
--- @return table result { ok, errors, warnings }
function M.validate(apl_text, config)
    local p = parser()
    if not p then return { ok = false, errors = { "apl_parser not available" }, warnings = {} } end
    return p.validate(apl_text, config or {})
end

--- Generate Lua source from an APL string (for code generation / debugging).
--- @param apl_text string  SimC-format APL text
--- @param config table|nil Optional config
--- @return string|nil source
function M.generate_source(apl_text, config)
    local p = parser()
    if not p then return nil end
    return p.generate_source(apl_text, config or {})
end

-- Expose to NS
NS.APLRegistry = M

return M
