-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/apl_parser.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- ============================================================================
-- What: Shared helper that parses SimC APL text into native strategy tables
-- When: On demand during profile import / APL parsing
-- Why: Convert SimulationCraft actions into rotation definitions without manual translation
-- Safety: Validates tokens, preserves defaults, and nil-guards malformed config
-- ============================================================================
-- Shared Helper: SimC APL Parser
-- ============================================================================
-- Usage:
--   local parser = require("shared/apl_parser")
--   local strategies = parser.parse_apl(simc_text, config)
--   NS.rotation_registry:register("shadow", strategies, { get_state = build_state })
--
-- SimC APL Syntax Supported:
--   actions=spell_name,if=condition
--   actions+=/spell_name,if=condition1&condition2|!condition3
--   actions+=/spell_name                   (no condition = always)
--   actions.precombat=inner_focus          (precombat actions)
--   actions.LISTNAME=spell_name            (named sub-action list)
--   actions.LISTNAME+=/spell_name,if=...   (append to sub-action list)
--   call_action_list,name=LISTNAME,if=...  (dispatch to sub-list)
--
-- Condition Operators:
--   &   AND
--   |   OR
--   !   NOT
--   < > <= >= == !=  comparisons
--   .   dot accessor (buff.name.up, debuff.name.remains, etc.)
-- ============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Section 0: Security — forbidden pattern validation for generated code
-- ---------------------------------------------------------------------------

--- Patterns that must never appear in generated Lua code.
-- These block access to I/O, OS, debug, and dynamic code execution.
local FORBIDDEN_PATTERNS = {
    { pattern = "%bos%.",           name = "os.execute/os.remove/os.rename" },
    { pattern = "%bio%.",           name = "io.open/io.popen/io.write" },
    { pattern = "%bdebug%.",        name = "debug.getinfo/debug.setmetatable" },
    { pattern = "loadstring",       name = "loadstring (dynamic code)" },
    { pattern = "loadfile",         name = "loadfile (dynamic code)" },
    { pattern = "dofile",           name = "dofile (dynamic code)" },
    { pattern = "rawset",           name = "rawset" },
    { pattern = "rawget",           name = "rawget" },
    { pattern = "setmetatable",     name = "setmetatable" },
    { pattern = "getmetatable",     name = "getmetatable" },
    { pattern = "setfenv",          name = "setfenv" },
    { pattern = "getfenv",          name = "getfenv" },
    { pattern = "_G",               name = "_G global table" },
    { pattern = "string%.dump",     name = "string.dump" },
    { pattern = "coroutine%.wrap",  name = "coroutine.wrap" },
    { pattern = "pcall",            name = "pcall" },
    { pattern = "xpcall",           name = "xpcall" },
    { pattern = "select",           name = "select" },
    { pattern = "require",          name = "require" },
    { pattern = "collectgarbage",   name = "collectgarbage" },
    { pattern = "newproxy",         name = "newproxy" },
}

--- Validate generated Lua code against forbidden patterns.
-- @param code string The generated Lua source
-- @return boolean ok, string|nil error_message
local function validate_generated_code(code)
    if type(code) ~= "string" then
        return false, "validate_generated_code: code is not a string"
    end
    for _, entry in ipairs(FORBIDDEN_PATTERNS) do
        if code:match(entry.pattern) then
            return false, "[APL Security] Forbidden pattern in generated code: " .. entry.name
        end
    end
    return true, nil
end

--- Sanitize a string for safe interpolation into a Lua string literal.
-- Rejects characters that could break out of double-quoted strings.
-- @param s string The raw string
-- @return string sanitized The safe string (or "invalid" if dangerous chars found)
local function safe_string_literal(s)
    if type(s) ~= "string" then return "invalid" end
    -- Reject if contains characters that could break double-quote context
    if s:match('[\\"%\n\r]') then
        return "invalid"
    end
    -- Reject if empty
    if s == "" then return "invalid" end
    return s
end

-- ---------------------------------------------------------------------------
-- Section 1: Tokenizer
-- ---------------------------------------------------------------------------

---Token kinds
local TOK_ACTIONS = "actions"
local TOK_SPELL = "spell"
local TOK_IF = "if"
local TOK_AND = "and_op"
local TOK_OR = "or_op"
local TOK_NOT = "not_op"
local TOK_DOT = "dot"
local TOK_LPAREN = "lparen"
local TOK_RPAREN = "rparen"
local TOK_COMP = "comp"
local TOK_NUMBER = "number"
local TOK_IDENT = "ident"
local TOK_EOF = "eof"

---Tokenize a single condition string.
-- Returns array of {kind, value, pos}.
local function tokenize_condition(cond_str)
    local tokens = {}
    local i = 1
    local len = #cond_str

    local function peek(n)
        n = n or 0
        local p = i + n
        if p > len then return nil end
        return cond_str:sub(p, p)
    end

    local function consume()
        local ch = peek()
        i = i + 1
        return ch
    end

    local function add_token(kind, value)
        tokens[#tokens + 1] = { kind = kind, value = value, pos = i }
    end

    while i <= len do
        local ch = peek()

        -- Whitespace
        if ch:match("%s") then
            consume()
        -- Two-character operators
        elseif ch == "&" and peek(1) == "&" then
            consume(); consume()
            add_token(TOK_AND, "&&")
        elseif ch == "|" and peek(1) == "|" then
            consume(); consume()
            add_token(TOK_OR, "||")
        elseif ch == "!" and peek(1) == "=" then
            consume(); consume()
            add_token(TOK_COMP, "!=")
        elseif ch == "=" and peek(1) == "=" then
            consume(); consume()
            add_token(TOK_COMP, "==")
        elseif ch == "<" and peek(1) == "=" then
            consume(); consume()
            add_token(TOK_COMP, "<=")
        elseif ch == ">" and peek(1) == "=" then
            consume(); consume()
            add_token(TOK_COMP, ">=")
        -- Single-character operators & punctuation
        elseif ch == "&" then
            consume()
            add_token(TOK_AND, "&")
        elseif ch == "|" then
            consume()
            add_token(TOK_OR, "|")
        elseif ch == "!" then
            consume()
            add_token(TOK_NOT, "!")
        elseif ch == "." then
            consume()
            add_token(TOK_DOT, ".")
        elseif ch == "(" then
            consume()
            add_token(TOK_LPAREN, "(")
        elseif ch == ")" then
            consume()
            add_token(TOK_RPAREN, ")")
        elseif ch == "<" then
            consume()
            add_token(TOK_COMP, "<")
        elseif ch == ">" then
            consume()
            add_token(TOK_COMP, ">")
        elseif ch == "=" then
            consume()
            add_token(TOK_COMP, "=")
        -- Numbers
        elseif ch:match("%d") then
            local num = ""
            while peek() and peek():match("[%d%.]") do
                num = num .. consume()
            end
            add_token(TOK_NUMBER, tonumber(num))
        -- Identifiers (words)
        elseif ch:match("[%a_]") then
            local word = ""
            while peek() and peek():match("[%w_]") do
                word = word .. consume()
            end
            add_token(TOK_IDENT, word)
        else
            -- Unknown character, skip
            consume()
            add_token("unknown", ch)
        end
    end

    add_token(TOK_EOF, "<<eof>>")
    return tokens
end

-- ---------------------------------------------------------------------------
-- Section 2: Condition Parser (Recursive Descent AST)
-- ---------------------------------------------------------------------------

-- Forward declarations for mutually recursive local functions (Lua 5.1)
local parse_expr, parse_or_expr, parse_and_expr, parse_not_expr, parse_primary, parse_access_or_boolean

-- Grammar precedence (low to high):
--   expr     → or_expr
--   or_expr  → and_expr ( "|" and_expr )*
--   and_expr → not_expr ( "&" not_expr )*
--   not_expr → "!" not_expr | primary
--   primary  → access [comp_op value] | "(" expr ")" | number | boolean
--   access   → ident ( "." ident )*
--   comp_op  → "<" | ">" | "<=" | ">=" | "==" | "!=" | "="
--   value    → number | access | boolean
--   boolean  → "true" | "false" | "up" | "down" | "ready" | "ticking"

local boolean_keywords = {
    ["true"] = true, ["false"] = false,
    ["up"] = true, ["down"] = false, ["ready"] = true,
    ["ticking"] = true,
}

---Parse the full expression — entry point.
function parse_expr(tokens, pos)
    return parse_or_expr(tokens, pos)
end

---Parse OR expression: and_expr ( "|" and_expr )*
function parse_or_expr(tokens, pos)
    local left, new_pos = parse_and_expr(tokens, pos)
    if not left then return nil, pos end

    while tokens[new_pos] and tokens[new_pos].kind == TOK_OR do
        local op_pos = new_pos
        new_pos = new_pos + 1
        local right, after = parse_and_expr(tokens, new_pos)
        if not right then return nil, op_pos end
        left = { type = "or_op", left = left, right = right }
        new_pos = after
    end

    return left, new_pos
end

---Parse AND expression: not_expr ( "&" not_expr )*
function parse_and_expr(tokens, pos)
    local left, new_pos = parse_not_expr(tokens, pos)
    if not left then return nil, pos end

    while tokens[new_pos] and tokens[new_pos].kind == TOK_AND do
        local op_pos = new_pos
        new_pos = new_pos + 1
        local right, after = parse_not_expr(tokens, new_pos)
        if not right then return nil, op_pos end
        left = { type = "and_op", left = left, right = right }
        new_pos = after
    end

    return left, new_pos
end

---Parse NOT expression: "!" not_expr | primary
function parse_not_expr(tokens, pos)
    if tokens[pos] and tokens[pos].kind == TOK_NOT then
        local inner, new_pos = parse_not_expr(tokens, pos + 1)
        if not inner then return nil, pos end
        return { type = "not_op", inner = inner }, new_pos
    end
    return parse_primary(tokens, pos)
end

---Parse primary: access [comp_op value] | "(" expr ")" | number | boolean
function parse_primary(tokens, pos)
    local tok = tokens[pos]
    if not tok then return nil, pos end

    -- Parenthesized expression
    if tok.kind == TOK_LPAREN then
        local inner, new_pos = parse_expr(tokens, pos + 1)
        if not inner then return nil, pos end
        if tokens[new_pos] and tokens[new_pos].kind == TOK_RPAREN then
            return { type = "paren", inner = inner }, new_pos + 1
        end
        return nil, pos
    end

    -- Number literal
    if tok.kind == TOK_NUMBER then
        return { type = "number", value = tok.value }, pos + 1
    end

    -- Identifier → access or boolean
    if tok.kind == TOK_IDENT then
        return parse_access_or_boolean(tokens, pos)
    end

    return nil, pos
end

---Parse access path and optional comparison, or boolean literal.
function parse_access_or_boolean(tokens, pos)
    local path = {}
    local current_pos = pos

    -- Single identifier check: boolean keyword?
    if tokens[current_pos] and tokens[current_pos].kind == TOK_IDENT then
        local word = tokens[current_pos].value            if boolean_keywords[word] ~= nil and (not tokens[current_pos+1] or tokens[current_pos+1].kind ~= TOK_DOT) then
            if not tokens[current_pos+1] or tokens[current_pos+1].kind ~= TOK_DOT then
                return { type = "boolean", value = boolean_keywords[word] }, current_pos + 1
            end
        end
    end

    -- Collect dot-separated path: ident ( "." ident )*
    while tokens[current_pos] and tokens[current_pos].kind == TOK_IDENT do
        path[#path + 1] = tokens[current_pos].value
        current_pos = current_pos + 1
        if tokens[current_pos] and tokens[current_pos].kind == TOK_DOT then
            current_pos = current_pos + 1
        else
            break
        end
    end

    -- Build access node
    local node = { type = "access", path = path }

    -- Optional comparison
    if tokens[current_pos] and tokens[current_pos].kind == TOK_COMP then
        local op = tokens[current_pos].value
        -- Normalize "=" to "=="
        if op == "=" then op = "==" end
        current_pos = current_pos + 1
        local right, after_right = parse_primary(tokens, current_pos)
        if not right then return nil, pos end
        node = { type = "compare", op = op, left = node, right = right }
        current_pos = after_right
    end

    return node, current_pos
end

-- ---------------------------------------------------------------------------
-- Section 3: SimC → Eax Code Generator
-- ---------------------------------------------------------------------------

---Default mapping table.
-- Keys are SimC access paths as dot-joined strings.
-- Values are Lua expression strings referencing Eax runtime.
-- Callers can override or extend this via config.mapping.
M.DEFAULT_MAPPING = {
    -- Buffs (player)
    ["buff.shadowform.up"]          = "NS.has_player_buff(BUFF_SHADOWFORM)",
    ["buff.inner_focus.up"]         = "NS.has_player_buff(INNER_FOCUS_BUFF)",
    ["buff.vampiric_embrace.up"]    = "NS.has_player_buff(VAMPIRIC_EMBRACE_BUFF)",
    ["buff.power_infusion.up"]      = "NS.has_player_buff(POWER_INFUSION_BUFF)",

    -- Debuffs (target)
    ["debuff.vampiric_touch.up"]     = "(state.vt_remaining > 0)",
    ["debuff.vampiric_touch.remains"]= "state.vt_remaining",
    ["debuff.shadow_word_pain.up"]   = "(state.swp_remaining > 0)",
    ["debuff.shadow_word_pain.remains"]= "state.swp_remaining",
    ["debuff.vampiric_embrace.up"]   = "(state.ve_remaining > 0)",
    ["debuff.vampiric_embrace.remains"]= "state.ve_remaining",

    -- Cooldowns
    ["cooldown.mind_blast.ready"]    = "state.mb_ready",
    ["cooldown.mind_blast.up"]       = "state.mb_ready",
    ["cooldown.shadow_word_death.ready"] = "state.swd_ready",
    ["cooldown.shadow_word_death.up"]    = "state.swd_ready",
    ["cooldown.shadowfiend.ready"]   = "NS.spell_ready(SPELLS.Shadowfiend, context.target, { expected_cooldown = 300 })",

    -- Player state
    ["moving"]                       = "context.is_moving",
    ["channeling"]                   = "context.is_channeling",
    ["casting"]                      = "context.is_casting",
    ["in_combat"]                    = "context.in_combat",

    -- Resources
    ["player.health.pct"]            = "context.player_hp",
    ["target.health.pct"]            = "context.target_hp",
    ["mana.pct"]                     = "context.mana_pct",
    ["health.pct"]                   = "context.player_hp",

    -- Combat time
    ["time"]                         = "context.combat_time",
    ["combat_time"]                  = "context.combat_time",
    ["active_enemies"]               = "(context.enemies_count or 1)",
}

---Resolve a SimC access path to an Eax Lua expression.
-- Tries exact match first, then falls back to heuristic rules.
local function resolve_access(path, mapping)
    local key = table.concat(path, ".")

    -- 1. Exact mapping
    if mapping[key] then
        return mapping[key]
    end

    -- 2. Heuristic: buff.xxx.up → NS.has_player_buff(BUFF_XXX)
    if #path == 3 and path[1] == "buff" and path[3] == "up" then
        local name = path[2]:gsub("(%a)([%w_]*)", function(first, rest)
            return first:upper() .. rest:upper()
        end)
        return "NS.has_player_buff(" .. name .. "_BUFF)"
    end

    -- 3. Heuristic: buff.xxx.remains → state.xxx_remaining
    if #path == 3 and path[1] == "buff" and path[3] == "remains" then
        return "(state." .. path[2] .. "_remaining or 0)"
    end

    -- 4. Heuristic: debuff.xxx.up → state.xxx_remaining > 0
    if #path == 3 and path[1] == "debuff" and path[3] == "up" then
        return "(state." .. path[2] .. "_remaining > 0)"
    end

    -- 5. Heuristic: debuff.xxx.remains → state.xxx_remaining
    if #path == 3 and path[1] == "debuff" and path[3] == "remains" then
        return "state." .. path[2] .. "_remaining"
    end

    -- 6. Heuristic: cooldown.xxx.ready → NS.spell_ready(SPELLS.Xxx)
    if #path == 3 and path[1] == "cooldown" and path[3] == "ready" then
        local name = path[2]:gsub("_(%a)", function(c) return c:upper() end):gsub("^%a", string.upper)
        return "NS.spell_ready(SPELLS." .. name .. ", context.target)"
    end

    -- 7. Heuristic: bare "remains" → generic dot remaining
    if #path == 1 and path[1] == "remains" then
        return "(state.dot_remaining or 0)"
    end

    -- 8. Heuristic: bare "ticking" → generic dot ticking
    if #path == 1 and path[1] == "ticking" then
        return "(state.dots_ticking and true or false)"
    end

    -- 9. Heuristic: buff.xxx.down → (not NS.has_player_buff(XXX_BUFF))
    if #path == 3 and path[1] == "buff" and path[3] == "down" then
        local name = path[2]:gsub("(%a)([%w_]*)", function(first, rest)
            return first:upper() .. rest:upper()
        end)
        return "(not NS.has_player_buff(" .. name .. "_BUFF))"
    end

    -- 10. Heuristic: talent.xxx.enabled → NS.has_talent(TALENT_XXX)
    if #path == 3 and path[1] == "talent" and path[3] == "enabled" then
        local name = path[2]:gsub("(%a)([%w_]*)", function(first, rest)
            return first:upper() .. rest:upper()
        end)
        return "NS.has_talent(TALENT_" .. name .. ")"
    end

    -- 99. Fallback: generate a runtime table access
    local parts = {}
    for _, p in ipairs(path) do
        parts[#parts + 1] = '"' .. p .. '"'
    end
    return "(state or {})[" .. table.concat(parts, "][") .. "]"
end

---Generate Lua source from an AST node.
local function generate_lua(node, mapping)
    if not node then return "nil" end

    if node.type == "or_op" then
        return "(" .. generate_lua(node.left, mapping) .. " or " .. generate_lua(node.right, mapping) .. ")"
    elseif node.type == "and_op" then
        return "(" .. generate_lua(node.left, mapping) .. " and " .. generate_lua(node.right, mapping) .. ")"
    elseif node.type == "not_op" then
        return "(not " .. generate_lua(node.inner, mapping) .. ")"
    elseif node.type == "compare" then
        local left = generate_lua(node.left, mapping)
        local right = generate_lua(node.right, mapping)
        return "(" .. left .. " " .. node.op .. " " .. right .. ")"
    elseif node.type == "paren" then
        return "(" .. generate_lua(node.inner, mapping) .. ")"
    elseif node.type == "access" then
        return resolve_access(node.path, mapping)

    elseif node.type == "number" then
        return tostring(node.value)

    elseif node.type == "boolean" then
        return node.value and "true" or "false"
    end

    return "false"
end

-- ---------------------------------------------------------------------------
-- Section 4: APL Line Parser
-- ---------------------------------------------------------------------------

---Parse a single SimC APL line.
-- Supports:
--   actions=spell_name,if=condition            → main list
--   actions+=/spell_name,if=condition          → main list (append)
--   actions.precombat=inner_focus              → precombat list
--   actions.LISTNAME=spell_name,if=condition   → named sub-list
--   actions.LISTNAME+=/spell_name,if=condition → named sub-list (append)
--   call_action_list,name=LISTNAME,if=condition → dispatch to sub-list
-- Returns nil if not a recognized actions/call line.
local function parse_apl_line(line)
    line = line:match("^%s*(.-)%s*$")  -- trim
    if not line or line == "" then
        return nil
    end
    if line:sub(1, 1) == "#" then
        return nil  -- comment
    end

    -- call_action_list,name=NAME,if=COND
    if line:match("^call_action_list") then
        local list_name = line:match("name=([%w_]+)")
        local cond = line:match(",if=(.+)$")
        if list_name then
            return { type = "call", list_name = list_name, condition = cond, raw = line }
        end
        return nil
    end

    -- Must start with "actions"
    if not line:match("^actions") then
        return nil
    end

    -- Extract list name from actions.XXX= or actions.XXX+=/
    local list_name = line:match("^actions%.([%w_]+)[+=]")
    if not list_name then
        -- actions.precombat or plain actions= / actions+=/
        if line:match("^actions%.precombat") then
            list_name = "precombat"
        else
            list_name = "default"
        end
    end

    -- Extract the part after "actions[stuff]=/spell_name,..."
    local action_part = line:match("^actions[^=]*=/?(.+)$")
    if not action_part then
        return nil
    end

    -- Split on ",if="
    local spell_part, cond_part = action_part:match("^(.-),if=(.+)$")
    if not spell_part then
        spell_part = action_part
    end

    -- spell_part may have parameters like ",target_if=..." — strip for now
    spell_part = spell_part:match("^([^,]+)") or spell_part

    return {
        type = "spell",
        list_name = list_name,
        spell = spell_part,
        condition = cond_part,
        raw = line,
    }
end

-- ---------------------------------------------------------------------------
-- Section 5: Strategy Builder
-- ---------------------------------------------------------------------------

---Convert a SimC spell name to a strategy name.
-- e.g., "shadow_word_pain" → "ShadowWordPain"
local function spell_to_name(spell)
    return spell:gsub("_(%a)", function(c)
        return c:upper()
    end):gsub("^%a", string.upper)
end

---Convert a SimC spell name to a SPELLS table key.
-- e.g., "shadow_word_pain" → "ShadowWordPain"
local function spell_to_spell_key(spell)
    return spell:gsub("_(%a)", function(c)
        return c:upper()
    end):gsub("^%a", string.upper)
end

---Build an Eax strategy table from a parsed APL entry.
-- entry: { spell, condition|nil, raw }
-- config: { mapping = {}, spell_map = {}, class_label = "[SHADOW]" }
local function build_strategy(entry, config)
    config = config or {}
    local mapping = {}
    -- Start with defaults
    for k, v in pairs(M.DEFAULT_MAPPING) do mapping[k] = v end
    -- Overlay caller mapping
    if config.mapping then
        for k, v in pairs(config.mapping) do mapping[k] = v end
    end

    local spell_name = entry.spell
    local strategy_name = spell_to_name(spell_name)
    local spell_key = spell_to_spell_key(spell_name)

    -- Allow spell map override (e.g., simc "vampiric_touch" → SPELLS.VampiricTouch)
    local spells_ref = "SPELLS." .. spell_key
    if config.spell_map and config.spell_map[spell_name] then
        spells_ref = config.spell_map[spell_name]
    end

    local class_label = config.class_label or "[APL]"
    local label = class_label .. " " .. strategy_name

    -- Build matches function
    local matches_body
    if entry.condition and entry.condition ~= "" then
        local tokens = tokenize_condition(entry.condition)
        local ast, final_pos = parse_expr(tokens, 1)
        -- Validate we consumed the whole input (or hit EOF)
        if ast and tokens[final_pos] and tokens[final_pos].kind == TOK_EOF then
            local lua_expr = generate_lua(ast, mapping)
            matches_body = lua_expr
        else
            -- Parse failure — safe fallback
            matches_body = "false  -- [[APL parse failed for: " .. tostring(entry.condition) .. "]]"
        end
    else
        matches_body = "true"
    end

    -- Strategy table
    local strategy = {
        name = strategy_name,
        -- matches will be compiled into a function below
        _matches_body = matches_body,
        -- execute references runtime SPELLS and NS
        _spell_ref = spells_ref,
        _label = label,
    }

    return strategy
end

---Build a dispatch strategy for a call_action_list entry.
-- This strategy checks a condition and then iterates over the named sub-list,
-- executing the first matching strategy it finds.
local function build_dispatch_strategy(entry, config)
    config = config or {}
    local mapping = {}
    for k, v in pairs(M.DEFAULT_MAPPING) do mapping[k] = v end
    if config.mapping then
        for k, v in pairs(config.mapping) do mapping[k] = v end
    end

    local list_name = entry.list_name
    local strategy_name = "Call_" .. spell_to_name(list_name)
    local class_label = config.class_label or "[APL]"
    local label = class_label .. " SubList:" .. list_name

    -- Build matches from condition
    local matches_body
    if entry.condition and entry.condition ~= "" then
        local tokens = tokenize_condition(entry.condition)
        local ast, final_pos = parse_expr(tokens, 1)
        if ast and tokens[final_pos] and tokens[final_pos].kind == TOK_EOF then
            matches_body = generate_lua(ast, mapping)
        else
            matches_body = "false  -- [[APL parse failed for: " .. tostring(entry.condition) .. "]]"
        end
    else
        matches_body = "true"
    end

    local strategy = {
        name = strategy_name,
        _matches_body = matches_body,
        _spell_ref = "nil",
        _label = label,
        _is_dispatch = true,
        _list_name = list_name,
    }

    return strategy
end

-- ---------------------------------------------------------------------------
-- Section 6: Public API
-- ---------------------------------------------------------------------------

---Parse a SimC APL text block and return an array of strategy tables.
-- Supports sub-action lists (actions.NAME=...) and call_action_list dispatch.
--
-- @param apl_text   string   Raw SimC APL (multi-line)
-- @param config     table    {
--     mapping = { ["buff.xxx.up"] = "NS.has_buff(...)", ... },
--     spell_map = { ["simc_name"] = "SPELLS.CustomKey", ... },
--     class_label = "[SHADOW]",
--     compile_functions = true,   -- if true, generates real functions; else strings
-- }
-- @return table  Array of strategy tables {name, matches, execute}
--                strategies._sub_lists = { cds = {...}, aoe = {...} }
function M.parse_apl(apl_text, config)
    config = config or {}
    local strategies = {}    -- main / "default" / "precombat" list
    local sub_lists = {}     -- named sub-lists: { cds = {...}, aoe = {...} }

    for line in apl_text:gmatch("[^\r\n]+") do
        local entry = parse_apl_line(line)
        if entry then
            if entry.type == "call" then
                -- Build dispatch strategy for call_action_list
                local dispatch = build_dispatch_strategy(entry, config)
                if dispatch then
                    -- dedup in main strategies
                    for i = #strategies, 1, -1 do
                        if strategies[i].name == dispatch.name then
                            table.remove(strategies, i)
                        end
                    end
                    table.insert(strategies, dispatch)
                end
            elseif entry.type == "spell" then
                local strategy = build_strategy(entry, config)
                if strategy then
                    if entry.list_name == "default" or entry.list_name == "precombat" then
                        -- Main list: dedup (last wins)
                        for i = #strategies, 1, -1 do
                            if strategies[i].name == strategy.name then
                                table.remove(strategies, i)
                            end
                        end
                        table.insert(strategies, strategy)
                    else
                        -- Sub-list
                        if not sub_lists[entry.list_name] then
                            sub_lists[entry.list_name] = {}
                        end
                        local sl = sub_lists[entry.list_name]
                        -- dedup within sub-list
                        for i = #sl, 1, -1 do
                            if sl[i].name == strategy.name then
                                table.remove(sl, i)
                            end
                        end
                        table.insert(sl, strategy)
                    end
                end
            end
        end
    end

    -- Store sub_lists for generate_source / runtime access
    strategies._sub_lists = sub_lists

    -- Compile functions if requested
    if config.compile_functions ~= false then
        -- SECURITY: Use closure-captured local instead of _G._sub_lists.
        -- This prevents global namespace pollution and removes the exposure window
        -- that existed during loadstring compilation.
        local _captured_sub_lists = sub_lists

        --- Safely compile and return a function from Lua source.
        -- Validates generated code against forbidden patterns before compilation.
        -- Uses setfenv sandboxing (Lua 5.1) to restrict the function's environment.
        -- @param src string Lua source code
        -- @param context string Label for error logging
        -- @param env table|nil Optional restricted environment
        -- @return function|nil compiled_fn
        local function safe_compile(src, context, env)
            local ok_v, err_v = validate_generated_code(src)
            if not ok_v then
                if NS and NS.core and NS.core.log_warning then
                    NS.core.log_warning("[APL] " .. tostring(context) .. ": " .. tostring(err_v))
                end
                return nil
            end
            local ok, factory = pcall(loadstring, src)
            if not ok or not factory then return nil end
            -- Apply restricted environment via setfenv (Lua 5.1)
            if env and setfenv then
                pcall(setfenv, factory, env)
            end
            local ok2, compiled = pcall(factory)
            if ok2 and type(compiled) == "function" then
                if env and setfenv then
                    pcall(setfenv, compiled, env)
                end
                return compiled
            end
            return nil
        end

        --- Build a restricted environment for compiled APL functions.
        -- Only exposes safe globals needed by generated code.
        -- @param extra table|nil Additional upvalues to inject
        -- @return table env Restricted environment
        local function build_restricted_env(extra)
            local env = {
                NS = NS,
                ipairs = ipairs,
                pairs = pairs,
                tostring = tostring,
                type = type,
                pcall = pcall,
                error = error,
                assert = assert,
                select = select,
                unpack = unpack or table.unpack,
                table = table,
                math = math,
                string = string,
                tonumber = tonumber,
                print = print,
            }
            if extra then
                for k, v in pairs(extra) do env[k] = v end
            end
            return env
        end

        -- Compile main strategies
        for _, strategy in ipairs(strategies) do
            -- SECURITY: Sanitize string literals before interpolation
            local safe_label = safe_string_literal(strategy._label)
            local safe_spell_ref = safe_string_literal(strategy._spell_ref)

            if strategy._is_dispatch then
                -- Dispatch strategy: compile matches and execute
                local matches_src = "return function(context, state)\n    return " .. strategy._matches_body .. "\nend"
                strategy.matches = safe_compile(matches_src, "dispatch matches:" .. strategy.name) or function() return false end

                -- execute checks matches then iterates the sub-list
                local list_name = safe_string_literal(strategy._list_name)
                local exec_src = "return function(context, state)\n" ..
                    "    if not (" .. strategy._matches_body .. ") then\n" ..
                    "        return false\n" ..
                    "    end\n" ..
                    "    local sub = (_sub_lists or {})[" .. string.format("%q", list_name) .. "]\n" ..
                    "    if sub then\n" ..
                    "        for _, s in ipairs(sub) do\n" ..
                    "            if s.matches and s.matches(context, state) then\n" ..
                    "                return s.execute(context, state)\n" ..
                    "            end\n" ..
                    "        end\n" ..
                    "    end\n" ..
                    "    return false\n" ..
                    "end"
                local dispatch_env = build_restricted_env({ _sub_lists = _captured_sub_lists })
                strategy.execute = safe_compile(exec_src, "dispatch execute:" .. strategy.name, dispatch_env) or function() return false end
            else
                -- Normal spell strategy
                local matches_src = "return function(context, state)\n    return " .. strategy._matches_body .. "\nend"
                local spell_env = build_restricted_env()
                strategy.matches = safe_compile(matches_src, "spell matches:" .. strategy.name, spell_env) or function() return false end

                local exec_src = "return function(context)\n    return NS.try_cast(" .. strategy._spell_ref .. ", context.target, " .. string.format("%q", safe_label) .. ")\nend"
                strategy.execute = safe_compile(exec_src, "spell execute:" .. strategy.name, spell_env) or function() return false end
            end

            -- Clean up internal fields
            strategy._matches_body = nil
            strategy._spell_ref = nil
            strategy._label = nil
            strategy._is_dispatch = nil
            strategy._list_name = nil
        end

        -- Compile sub-list strategies
        for _, sl in pairs(sub_lists) do
            for _, strategy in ipairs(sl) do
                local safe_label = safe_string_literal(strategy._label)
                local safe_spell_ref = safe_string_literal(strategy._spell_ref)

                local matches_src = "return function(context, state)\n    return " .. strategy._matches_body .. "\nend"
                local sub_env = build_restricted_env()
                strategy.matches = safe_compile(matches_src, "sublist matches:" .. strategy.name, sub_env) or function() return false end

                local exec_src = "return function(context)\n    return NS.try_cast(" .. strategy._spell_ref .. ", context.target, " .. string.format("%q", safe_label) .. ")\nend"
                strategy.execute = safe_compile(exec_src, "sublist execute:" .. strategy.name, sub_env) or function() return false end

                strategy._matches_body = nil
                strategy._spell_ref = nil
                strategy._label = nil
            end
        end
    end

    return strategies
end

---Parse SimC APL and return the generated Lua source as a string.
-- Useful for inspecting output or writing to a file.
-- Supports sub-lists and call_action_list dispatch.
--
-- @param apl_text   string   Raw SimC APL
-- @param config     table    Same as parse_apl
-- @return string   Lua source for the strategies array (includes _sub_lists)
function M.generate_source(apl_text, config)
    config = config or {}
    local strategies = {}
    local sub_lists = {}

    for line in apl_text:gmatch("[^\r\n]+") do
        local entry = parse_apl_line(line)
        if entry then
            if entry.type == "call" then
                local dispatch = build_dispatch_strategy(entry, config)
                if dispatch then
                    for i = #strategies, 1, -1 do
                        if strategies[i].name == dispatch.name then
                            table.remove(strategies, i)
                        end
                    end
                    table.insert(strategies, dispatch)
                end
            elseif entry.type == "spell" then
                local strategy = build_strategy(entry, config)
                if strategy then
                    if entry.list_name == "default" or entry.list_name == "precombat" then
                        for i = #strategies, 1, -1 do
                            if strategies[i].name == strategy.name then
                                table.remove(strategies, i)
                            end
                        end
                        table.insert(strategies, strategy)
                    else
                        if not sub_lists[entry.list_name] then
                            sub_lists[entry.list_name] = {}
                        end
                        local sl = sub_lists[entry.list_name]
                        for i = #sl, 1, -1 do
                            if sl[i].name == strategy.name then
                                table.remove(sl, i)
                            end
                        end
                        table.insert(sl, strategy)
                    end
                end
            end
        end
    end

    local lines = {}

    -- Emit sub-list tables first
    local sub_list_names = {}
    for list_name, _ in pairs(sub_lists) do
        sub_list_names[#sub_list_names + 1] = list_name
    end
    table.sort(sub_list_names)

    if #sub_list_names > 0 then
        for _, list_name in ipairs(sub_list_names) do
            local sl = sub_lists[list_name]
            lines[#lines + 1] = "-- Sub-list: " .. list_name
            lines[#lines + 1] = "local sub_" .. list_name .. " = {"
            for _, s in ipairs(sl) do
                lines[#lines + 1] = "    {"
                lines[#lines + 1] = '        name = "' .. s.name .. '",'
                lines[#lines + 1] = "        matches = function(context, state)"
                lines[#lines + 1] = "            return " .. s._matches_body
                lines[#lines + 1] = "        end,"
                lines[#lines + 1] = "        execute = function(context)"
                local escaped_label = s._label:gsub('"', '\\"')
                lines[#lines + 1] = "            return NS.try_cast(" .. s._spell_ref .. ', context.target, "' .. escaped_label .. '")'
                lines[#lines + 1] = "        end,"
                lines[#lines + 1] = "    },"
            end
            lines[#lines + 1] = "}"
            lines[#lines + 1] = ""
        end

        -- Emit _sub_lists registry table
        lines[#lines + 1] = "-- Sub-list registry for dispatch"
        lines[#lines + 1] = "local _sub_lists = {"
        for _, list_name in ipairs(sub_list_names) do
            lines[#lines + 1] = '    ["' .. list_name .. '"] = sub_' .. list_name .. ','
        end
        lines[#lines + 1] = "}"
        lines[#lines + 1] = ""
    end

    -- Emit main strategies
    lines[#lines + 1] = "-- Auto-generated from SimC APL"
    lines[#lines + 1] = "local strategies = {"

    for _, s in ipairs(strategies) do
        lines[#lines + 1] = "    {"
        lines[#lines + 1] = '        name = "' .. s.name .. '",'
        if s._is_dispatch then
            lines[#lines + 1] = "        matches = function(context, state)"
            lines[#lines + 1] = "            return " .. s._matches_body
            lines[#lines + 1] = "        end,"
            lines[#lines + 1] = "        execute = function(context, state)"
            local list_name = s._list_name
            lines[#lines + 1] = '            local sub = _sub_lists["' .. list_name .. '"]'
            lines[#lines + 1] = "            if sub then"
            lines[#lines + 1] = "                for _, s2 in ipairs(sub) do"
            lines[#lines + 1] = "                    if s2.matches and s2.matches(context, state) then"
            lines[#lines + 1] = "                        return s2.execute(context, state)"
            lines[#lines + 1] = "                    end"
            lines[#lines + 1] = "                end"
            lines[#lines + 1] = "            end"
            lines[#lines + 1] = "            return false"
            lines[#lines + 1] = "        end,"
        else
            lines[#lines + 1] = "        matches = function(context, state)"
            lines[#lines + 1] = "            return " .. s._matches_body
            lines[#lines + 1] = "        end,"
            lines[#lines + 1] = "        execute = function(context)"
            local escaped_label = s._label:gsub('"', '\\"')
            lines[#lines + 1] = "            return NS.try_cast(" .. s._spell_ref .. ', context.target, "' .. escaped_label .. '")'
            lines[#lines + 1] = "        end,"
        end
        lines[#lines + 1] = "    },"
    end

    lines[#lines + 1] = "}"
    lines[#lines + 1] = "return strategies"

    return table.concat(lines, "\n")
end

---Validate a SimC APL text block.
-- Returns { ok = true|false, errors = {}, warnings = {} }
function M.validate(apl_text, config)
    local errors = {}
    local warnings = {}
    local line_num = 0

    for line in apl_text:gmatch("[^\r\n]+") do
        line_num = line_num + 1
        local entry = parse_apl_line(line)
        if entry and entry.condition then
            local tokens = tokenize_condition(entry.condition)
            local ast, final_pos = parse_expr(tokens, 1)
            if not ast then
                table.insert(errors, "Line " .. line_num .. ": failed to parse condition: " .. entry.condition)
            elseif tokens[final_pos].kind ~= TOK_EOF then
                table.insert(warnings, "Line " .. line_num .. ": condition may have unparsed trailing tokens: " .. entry.condition)
            end
        elseif not entry and line:match("^%S") and not line:match("^#") and not line:match("^%s*$") then
            -- Warn about non-comment, non-empty lines that aren't actions/calls
            if line:match("call_action_list") then
                -- call_action_list is now supported; validate condition syntax
                local list_name = line:match("name=([%w_]+)")
                local cond = line:match(",if=(.+)$")
                if cond then
                    local tokens = tokenize_condition(cond)
                    local ast, final_pos = parse_expr(tokens, 1)
                    if not ast then
                        table.insert(errors, "Line " .. line_num .. ": failed to parse call_action_list condition: " .. cond)
                    elseif tokens[final_pos].kind ~= TOK_EOF then
                        table.insert(warnings, "Line " .. line_num .. ": call_action_list condition trailing tokens")
                    end
                elseif not list_name then
                    table.insert(warnings, "Line " .. line_num .. ": call_action_list missing name=...: " .. line)
                end
            elseif not line:match("^actions") then
                table.insert(warnings, "Line " .. line_num .. ": unrecognized line type: " .. line)
            end
        end
    end

    return {
        ok = #errors == 0,
        errors = errors,
        warnings = warnings,
    }
end

-- ---------------------------------------------------------------------------
-- Section 7: Module Return
-- ---------------------------------------------------------------------------

---Expose internal functions for unit testing.
M._tokenize_condition = tokenize_condition
M._parse_expr = parse_expr
M._generate_lua = generate_lua
M._parse_apl_line = parse_apl_line
M._TOK_EOF = TOK_EOF

return M
