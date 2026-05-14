-- ============================================================================
-- Shared Helper: SimC APL Parser
-- ============================================================================
-- Readability notes:
--   What: parses SimulationCraft APL lines into EaxRotations strategy tables.
--   When: loaded by class modules or the optimizer bridge when importing sim data.
--   Why: theorycraft validation requires matching SimC priority logic exactly.
--   Safety: unparseable lines are logged, not crashed; evaluation stays data-driven.

local M = {}
local _G = _G
local NS = _G.EaxRotations
local EMPTY = {}

local function warn(msg)
    if NS and NS.log_warning then NS.log_warning("[APL] " .. tostring(msg)) end
end

local function info(msg)
    if NS and NS.log then NS.log("[APL] " .. tostring(msg)) end
end

local function trim(value)
    if type(value) ~= "string" then return value end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize_name(value)
    return (tostring(value or ""):lower():gsub("[^%w]+", ""))
end

local function split_lines(text)
    local lines = {}
    if type(text) ~= "string" then return lines end
    for line in text:gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

local function split_path(path)
    local parts = {}
    if type(path) ~= "string" then return parts end
    for part in path:gmatch("[^%.]+") do
        parts[#parts + 1] = part
    end
    return parts
end

local function to_number(value)
    if type(value) == "number" then return value end
    if type(value) == "string" then return tonumber(value) end
    return nil
end

local function bool(value)
    return not not value
end

local function safe_call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function read_file(path)
    if type(path) ~= "string" or path == "" then return nil, "invalid path" end
    local file, err = io.open(path, "rb")
    if not file then return nil, err or "unable to open file" end
    local contents = file:read("*a") or ""
    file:close()
    return contents
end

function M.load_apl_file(path)
    local contents, err = read_file(path)
    if not contents then
        warn("failed to read APL file: " .. tostring(err))
        return nil, err
    end
    return contents
end

local function build_spell_lookup(spell_db)
    local lookup = {}
    if type(spell_db) ~= "table" then return lookup end
    for key, value in pairs(spell_db) do
        lookup[normalize_name(key)] = value
        if type(value) == "table" then
            local label = value._meta and value._meta.label or value.name or value.label
            if label then lookup[normalize_name(label)] = value end
        end
    end
    return lookup
end

local function lookup_state_value(state, keys)
    if type(state) ~= "table" then return nil end
    for i = 1, #keys do
        local key = keys[i]
        if key and state[key] ~= nil then return state[key] end
    end
    return nil
end

local function lookup_nested(state, parts)
    local cursor = state
    for i = 1, #parts do
        if type(cursor) ~= "table" then return nil end
        cursor = cursor[parts[i]]
        if cursor == nil then return nil end
    end
    return cursor
end

local function lookup_flat_reference(state, reference)
    if type(state) ~= "table" or type(reference) ~= "string" then return nil end
    if state[reference] ~= nil then return state[reference] end
    local normalized = normalize_name(reference)
    for key, value in pairs(state) do
        if normalize_name(key) == normalized then return value end
    end
    return nil
end

local function resolve_resource_name(name, state, suffix)
    local key = normalize_name(name or "")
    local suffix_key = suffix and normalize_name(suffix) or nil
    local candidates = {}
    if suffix_key == "pct" or suffix_key == "percent" then
        candidates[#candidates + 1] = key .. "_pct"
        candidates[#candidates + 1] = key .. "_percent"
    elseif suffix_key == "max" then
        candidates[#candidates + 1] = key .. "_max"
    elseif suffix_key == "current" or suffix_key == "value" then
        candidates[#candidates + 1] = key
    elseif suffix_key ~= nil then
        candidates[#candidates + 1] = key .. "_" .. suffix_key
    else
        candidates[#candidates + 1] = key
        candidates[#candidates + 1] = key .. "_pct"
        candidates[#candidates + 1] = key .. "_current"
    end
    return lookup_state_value(state, candidates)
end

local function resolve_buff_like(prefix, name, suffix, context, state)
    local base = normalize_name(name)
    local suffix_name = normalize_name(suffix or "")
    local candidates = {
        prefix .. "_" .. base .. (suffix_name ~= "" and ("_" .. suffix_name) or ""),
        base .. "_" .. prefix .. (suffix_name ~= "" and ("_" .. suffix_name) or ""),
        base .. (suffix_name ~= "" and ("_" .. suffix_name) or ""),
        prefix .. "." .. base .. (suffix_name ~= "" and ("." .. suffix_name) or ""),
    }
    local value = lookup_state_value(state, candidates)
    if value ~= nil then return value end
    if type(state) == "table" then
        local bucket = state[prefix] or state[prefix .. "s"] or state[base]
        if type(bucket) == "table" then
            local ref = bucket[suffix] or bucket[suffix_name] or bucket[normalize_name(suffix_name)]
            if ref ~= nil then return ref end
        end
    end
    if suffix_name == "up" or suffix_name == "active" or suffix_name == "present" then
        local flag = lookup_state_value(state, { prefix .. "_" .. base .. "_up", base .. "_up", prefix .. "_" .. base, base })
        if flag ~= nil then return bool(flag) end
    end
    if suffix_name == "stacks" or suffix_name == "stack" then
        return lookup_state_value(state, { prefix .. "_" .. base .. "_stacks", base .. "_stacks", prefix .. "_" .. base .. "_stack", base .. "_stack" })
    end
    if suffix_name == "remains" or suffix_name == "remain" or suffix_name == "remainsms" then
        return lookup_state_value(state, { prefix .. "_" .. base .. "_remains", base .. "_remains", prefix .. "_" .. base .. "_remain", base .. "_remain" })
    end
    return nil
end

local function resolve_stance_or_form(kind, name, state)
    local base = normalize_name(name)
    local direct_keys = {
        kind .. "_" .. base,
        "in_" .. base .. "_" .. kind,
        base .. "_" .. kind,
        kind .. base,
    }
    local value = lookup_state_value(state, direct_keys)
    if value ~= nil then return value end
    if type(state) == "table" and state[kind] ~= nil then
        local current = state[kind]
        if type(current) == "string" then return normalize_name(current) == base end
        if type(current) == "table" then return bool(current[base] or current[name]) end
    end
    local flag = lookup_state_value(state, { "in_" .. base .. "_" .. kind, "has_" .. base .. "_" .. kind })
    if flag ~= nil then return bool(flag) end
    return false
end

local function resolve_reference(reference, context, state)
    if type(reference) ~= "string" then return reference end
    local token = trim(reference)
    if token == "" then return nil end
    if token == "true" then return true end
    if token == "false" then return false end
    local numeric = tonumber(token)
    if numeric ~= nil then return numeric end

    local parts = split_path(token)
    local head = normalize_name(parts[1] or token)
    local suffix = parts[2] and normalize_name(parts[2]) or nil
    local third = parts[3] and normalize_name(parts[3]) or nil

    if head == "combat" then
        if type(context) == "table" and context.in_combat ~= nil then return bool(context.in_combat) end
        return bool(lookup_state_value(state, { "in_combat", "combat" }))
    end

    if head == "target" and suffix == "health" and third == "pct" then
        return lookup_state_value(state, { "target_hp_pct", "target_health_pct", "target_hp", "target_health" })
    end

    if head == "hp" or head == "health" or head == "mana" or head == "rage" or head == "energy" or head == "focus" or head == "combo" or head == "combo_points" then
        if suffix == "pct" or suffix == "percent" or suffix == "current" or suffix == "max" then
            return resolve_resource_name(head, state, suffix)
        end
        return resolve_resource_name(head, state, nil)
    end

    if head == "resource" and suffix then
        return resolve_resource_name(suffix, state, third or parts[4])
    end

    if head == "buff" and suffix then
        return resolve_buff_like("buff", suffix, third or parts[4] or "up", context, state)
    end

    if head == "debuff" and suffix then
        return resolve_buff_like("debuff", suffix, third or parts[4] or "up", context, state)
    end

    if head == "cooldown" and suffix then
        local base = normalize_name(suffix)
        local tail = normalize_name(third or parts[4] or "remains")
        local candidates = {
            "cooldown_" .. base .. "_" .. tail,
            base .. "_cooldown_" .. tail,
            base .. "_" .. tail,
            "cd_" .. base .. "_" .. tail,
        }
        local value = lookup_state_value(state, candidates)
        if value ~= nil then return value end
        if tail == "ready" or tail == "up" then
            local ready = lookup_state_value(state, { "cooldown_" .. base .. "_ready", base .. "_ready", base .. "_up" })
            if ready ~= nil then return bool(ready) end
        end
        if tail == "remains" or tail == "remain" then
            return lookup_state_value(state, { "cooldown_" .. base .. "_remains", base .. "_remains", base .. "_cd", base .. "_cooldown" })
        end
        if tail == "charges" then
            return lookup_state_value(state, { "cooldown_" .. base .. "_charges", base .. "_charges" })
        end
        return value
    end

    if head == "stance" and suffix then
        return resolve_stance_or_form("stance", suffix, state)
    end

    if head == "form" and suffix then
        return resolve_stance_or_form("form", suffix, state)
    end

    if head == "player" and suffix then
        return resolve_reference(table.concat(parts, ".", 2), context, state)
    end

    local direct = lookup_flat_reference(state, token)
    if direct ~= nil then return direct end
    if type(context) == "table" then
        local context_value = lookup_flat_reference(context, token)
        if context_value ~= nil then return context_value end
    end
    return nil
end

local function compare(lhs, op, rhs)
    local left = lhs
    local right = rhs
    local left_num = to_number(left)
    local right_num = to_number(right)
    if left_num ~= nil and right_num ~= nil then
        left = left_num
        right = right_num
    end
    if op == "=" or op == "==" then return left == right end
    if op == "!=" then return left ~= right end
    if op == "<" then return (to_number(left) or 0) < (to_number(right) or 0) end
    if op == "<=" then return (to_number(left) or 0) <= (to_number(right) or 0) end
    if op == ">" then return (to_number(left) or 0) > (to_number(right) or 0) end
    if op == ">=" then return (to_number(left) or 0) >= (to_number(right) or 0) end
    return false
end

local function lex(condition)
    local tokens = {}
    local i = 1
    local len = #condition
    while i <= len do
        local ch = condition:sub(i, i)
        if ch:match("%s") then
            i = i + 1
        elseif ch == "(" or ch == ")" or ch == "!" or ch == "&" or ch == "|" then
            tokens[#tokens + 1] = { type = ch, value = ch }
            i = i + 1
        elseif ch == "<" or ch == ">" or ch == "=" then
            local next_ch = condition:sub(i + 1, i + 1)
            local op = ch
            if next_ch == "=" then op = ch .. next_ch end
            tokens[#tokens + 1] = { type = "op", value = op }
            i = i + #op
        else
            local j = i
            while j <= len do
                local cj = condition:sub(j, j)
                if cj:match("[%w_%.:/-]") then
                    j = j + 1
                else
                    break
                end
            end
            local text = condition:sub(i, j - 1)
            if text ~= "" then
                local num = tonumber(text)
                if num ~= nil then
                    tokens[#tokens + 1] = { type = "number", value = num }
                elseif text == "true" or text == "false" then
                    tokens[#tokens + 1] = { type = "boolean", value = text == "true" }
                else
                    tokens[#tokens + 1] = { type = "ident", value = text }
                end
            end
            i = j
        end
    end
    return tokens
end

local function parse_condition_ast(tokens)
    local pos = 1

    local parse_expr, parse_and, parse_unary, parse_primary

    local function peek()
        return tokens[pos]
    end

    local function consume(expected)
        local token = tokens[pos]
        if not token then return nil end
        if expected and token.type ~= expected then return nil end
        pos = pos + 1
        return token
    end

    function parse_primary()
        local token = peek()
        if not token then return nil end
        if token.type == "(" then
            consume("(")
            local node = parse_expr()
            consume(")")
            return node
        end

        if token.type == "boolean" then
            consume("boolean")
            return { type = "bool", value = token.value }
        end

        if token.type == "number" then
            consume("number")
            return { type = "value", value = token.value }
        end

        if token.type == "ident" then
            local left = token.value
            consume("ident")
            local op = peek()
            if op and op.type == "op" then
                consume("op")
                local right = peek()
                if not right then return { type = "value", value = left } end
                if right.type == "number" or right.type == "boolean" or right.type == "ident" then
                    consume(right.type)
                    return {
                        type = "compare",
                        left = left,
                        op = op.value,
                        right = right.value,
                        right_type = right.type,
                    }
                end
                return { type = "value", value = left }
            end
            return { type = "value", value = left }
        end

        return nil
    end

    function parse_unary()
        local token = peek()
        if token and token.type == "!" then
            consume("!")
            return { type = "not", value = parse_unary() }
        end
        return parse_primary()
    end

    function parse_and()
        local left = parse_unary()
        while true do
            local token = peek()
            if token and token.type == "&" then
                consume("&")
                left = { type = "and", left = left, right = parse_unary() }
            else
                break
            end
        end
        return left
    end

    function parse_expr()
        local left = parse_and()
        while true do
            local token = peek()
            if token and token.type == "|" then
                consume("|")
                left = { type = "or", left = left, right = parse_and() }
            else
                break
            end
        end
        return left
    end

    local ast = parse_expr()
    return ast, pos <= #tokens and tokens[pos] or nil
end

local function eval_ast(node, context, state)
    if not node then return true end
    if node.type == "bool" then return bool(node.value) end
    if node.type == "value" then
        local value = resolve_reference(node.value, context, state)
        if value == nil then return false end
        if type(value) == "number" then return value ~= 0 end
        return bool(value)
    end
    if node.type == "compare" then
        local left = resolve_reference(node.left, context, state)
        local right
        if node.right_type == "number" or node.right_type == "boolean" then
            right = node.right
        else
            right = resolve_reference(node.right, context, state)
            if right == nil then right = node.right end
        end
        return compare(left, node.op, right)
    end
    if node.type == "not" then
        return not eval_ast(node.value, context, state)
    end
    if node.type == "and" then
        return eval_ast(node.left, context, state) and eval_ast(node.right, context, state)
    end
    if node.type == "or" then
        return eval_ast(node.left, context, state) or eval_ast(node.right, context, state)
    end
    return false
end

function M.condition_to_function(condition)
    if condition == nil or condition == "" then
        return function() return true end
    end

    local tokens = lex(condition)
    local ast, remainder = parse_condition_ast(tokens)
    if remainder ~= nil then
        warn("unparsed condition tail: " .. tostring(remainder.value or remainder.type))
    end
    if not ast then
        warn("unable to parse condition: " .. tostring(condition))
        return function() return false end
    end

    return function(context, state)
        return eval_ast(ast, context or EMPTY, state or context or EMPTY)
    end
end

function M.condition_to_lua(condition)
    return condition or "true"
end

local function build_action_object(parsed, spell_ref)
    local action = {
        name = parsed.action,
        spell = spell_ref,
    }
    return action
end

function M.to_strategy(parsed, spell_ref, opts)
    if not parsed then return nil end
    opts = opts or EMPTY
    local matches_condition = M.condition_to_function(parsed.condition)
    local action = build_action_object(parsed, spell_ref)

    local strategy = {
        name = parsed.action,
        spell = spell_ref,
        raw = parsed.raw,
        apl = parsed,
        source = opts.source or "simc_apl",
        priority = parsed.line_no or opts.priority or 0,
        matches = function(context, state)
            if not matches_condition(context, state) then return false end
            if type(NS) ~= "table" or type(NS.action_matches) ~= "function" then return true end
            if not spell_ref then return false end
            return NS.action_matches(context or EMPTY, action)
        end,
        execute = function(context)
            if type(NS) ~= "table" or type(NS.action_execute) ~= "function" or not spell_ref then return false end
            return NS.action_execute(context or EMPTY, action, opts.prefix or "[APL]")
        end,
    }

    return strategy
end

function M.parse_line(line)
    if type(line) ~= "string" then return nil end
    local cleaned = trim(line)
    if cleaned == "" or cleaned:sub(1, 1) == "#" then return nil end

    local section, payload = cleaned:match("^(actions[^=]*)=/?(.*)$")
    if not payload then
        payload = cleaned:match("^actions[^=]*=/?(.*)$")
    end
    if not payload or payload == "" then
        warn("unparseable line: " .. cleaned)
        return nil
    end

    local action, condition = payload:match("^([^,]+),%s*if=(.+)$")
    if not action then
        action = payload
    end

    action = trim(action or "")
    condition = trim(condition or "")
    if action == "" then
        warn("unparseable line: " .. cleaned)
        return nil
    end

    return {
        raw = cleaned,
        section = section,
        action = action,
        condition = condition ~= "" and condition or nil,
    }
end

function M.parse_simc(simc_text, spell_db, opts)
    opts = opts or EMPTY
    local result = {
        source = opts.source,
        lines = {},
        strategies = {},
        unparseable = {},
        missing_spells = {},
    }
    if type(simc_text) ~= "string" then return result end

    local lookup = build_spell_lookup(spell_db)
    local line_no = 0
    for _, line in ipairs(split_lines(simc_text)) do
        line_no = line_no + 1
        local parsed = M.parse_line(line)
        if parsed then
            parsed.line_no = line_no
            result.lines[#result.lines + 1] = parsed
            local spell_ref = lookup[normalize_name(parsed.action)]
            if spell_ref then
                local strategy = M.to_strategy(parsed, spell_ref, opts)
                if strategy then result.strategies[#result.strategies + 1] = strategy end
            else
                result.missing_spells[#result.missing_spells + 1] = {
                    line = line_no,
                    action = parsed.action,
                    raw = parsed.raw,
                }
            end
        else
            result.unparseable[#result.unparseable + 1] = { line = line_no, raw = line }
        end
    end

    return result
end

function M.parse_simc_file(path, spell_db, opts)
    local text, err = M.load_apl_file(path)
    if not text then
        return { source = path, error = err, lines = {}, strategies = {}, unparseable = {}, missing_spells = {} }
    end
    opts = opts or EMPTY
    opts.source = path
    return M.parse_simc(text, spell_db, opts)
end

function M.default_validation_contexts()
    return {
        { label = "ooc_idle", in_combat = false, has_valid_enemy_target = false, mana_pct = 100, hp_pct = 100, target_hp_pct = 100, is_moving = false },
        { label = "combat_stationary", in_combat = true, has_valid_enemy_target = true, mana_pct = 100, hp_pct = 100, target_hp_pct = 100, is_moving = false, enemy_count = 1, rage = 50, energy = 50 },
        { label = "combat_moving", in_combat = true, has_valid_enemy_target = true, mana_pct = 35, hp_pct = 70, target_hp_pct = 60, is_moving = true, enemy_count = 3, rage = 30, energy = 30 },
        { label = "execute_window", in_combat = true, has_valid_enemy_target = true, mana_pct = 20, hp_pct = 55, target_hp_pct = 15, is_moving = false, enemy_count = 1, rage = 60, energy = 80 },
    }
end

local function strategy_name(strategy)
    if type(strategy) ~= "table" then return nil end
    return normalize_name(strategy.name or strategy.action or strategy.label or strategy.raw)
end

local function select_strategy(strategies, context, state)
    if type(strategies) ~= "table" then return nil end
    for i = 1, #strategies do
        local strategy = strategies[i]
        local matcher = strategy and strategy.matches
        if type(matcher) == "function" then
            local ok, result = pcall(matcher, context, state)
            if ok and result then
                return strategy, i
            end
        end
    end
    return nil
end

function M.validate_strategy_sets(simc_strategies, eax_strategies, contexts, opts)
    opts = opts or EMPTY
    local samples = contexts or M.default_validation_contexts()
    local report = {
        passed = true,
        checked = 0,
        matches = 0,
        mismatches = {},
        samples = {},
    }

    local build_state = opts.get_state or function(context) return context and context.state or context end

    for i = 1, #samples do
        local context = samples[i]
        local state = build_state(context)
        local simc_strategy = select_strategy(simc_strategies, context, state)
        local eax_strategy = select_strategy(eax_strategies, context, state)
        local simc_name = strategy_name(simc_strategy)
        local eax_name = strategy_name(eax_strategy)

        report.checked = report.checked + 1
        report.samples[#report.samples + 1] = {
            label = context and context.label or ("sample_" .. i),
            simc = simc_name,
            eax = eax_name,
        }

        if simc_name == eax_name then
            report.matches = report.matches + 1
        else
            report.passed = false
            report.mismatches[#report.mismatches + 1] = {
                label = context and context.label or ("sample_" .. i),
                expected = simc_name,
                actual = eax_name,
                simc = simc_strategy and simc_strategy.raw or nil,
                eax = eax_strategy and eax_strategy.raw or nil,
            }
        end
    end

    return report
end

function M.validate_apl_file(path, spell_db, eax_strategies, contexts, opts)
    local parsed = M.parse_simc_file(path, spell_db, opts)
    local report = M.validate_strategy_sets(parsed.strategies, eax_strategies, contexts, opts)
    report.source = path
    report.parsed = parsed
    return report
end

function M.report_mismatches(report)
    if not report then
        return { passed = false, summary = "no report" }
    end
    local summary = {
        passed = report.passed == true,
        checked = report.checked or 0,
        matches = report.matches or 0,
        mismatch_count = report.mismatch_count or #(report.mismatches or EMPTY),
        lines = {},
    }
    for i = 1, #(report.mismatches or EMPTY) do
        local mismatch = report.mismatches[i]
        summary.lines[#summary.lines + 1] = string.format("%s: expected=%s actual=%s", tostring(mismatch.label), tostring(mismatch.expected), tostring(mismatch.actual))
    end
    return summary
end

NS.APLParser = M
info("Parser loaded: file loading, SimC conditions, strategy generation, validation")
return M
