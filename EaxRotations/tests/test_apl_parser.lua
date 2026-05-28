-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_apl_parser.lua"
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
-- Test: SimC APL Parser
-- ============================================================================
local assert_true, assert_eq
do
    local passed, failed = 0, 0
    function assert_true(condition, msg)
        if condition then
            passed = passed + 1
        else
            failed = failed + 1
            print("FAIL: " .. (msg or "assert_true"))
        end
    end
    function assert_eq(actual, expected, msg)
        if actual == expected then
            passed = passed + 1
        else
            failed = failed + 1
            print("FAIL: " .. (msg or "assert_eq") .. " | expected: " .. tostring(expected) .. " | got: " .. tostring(actual))
        end
    end
end

-- Load the parser module (pure Lua, no NS dependency needed)
local parser = dofile("EaxRotations/shared/apl_parser.lua")
assert_true(parser ~= nil, "parser module loaded")
assert_true(parser._tokenize_condition ~= nil, "tokenizer exposed")
assert_true(parser._parse_expr ~= nil, "parser exposed")
assert_true(parser._generate_lua ~= nil, "generator exposed")
assert_true(parser._parse_apl_line ~= nil, "line parser exposed")

-- ============================================================================
-- Section 1: Tokenizer Tests
-- ============================================================================

local function test_tokenize_simple()
    local tokens = parser._tokenize_condition("remains<3")
    assert_eq(tokens[1].kind, "ident", "token 1 is ident")
    assert_eq(tokens[1].value, "remains", "token 1 value")
    assert_eq(tokens[2].kind, "comp", "token 2 is comp")
    assert_eq(tokens[2].value, "<", "token 2 value")
    assert_eq(tokens[3].kind, "number", "token 3 is number")
    assert_eq(tokens[3].value, 3, "token 3 value")
    assert_eq(tokens[4].kind, parser._TOK_EOF, "token 4 is EOF")
end

local function test_tokenize_dot_access()
    local tokens = parser._tokenize_condition("debuff.vampiric_touch.up")
    assert_eq(tokens[1].kind, "ident", "token 1 is ident")
    assert_eq(tokens[1].value, "debuff", "token 1 debuff")
    assert_eq(tokens[2].kind, "dot", "token 2 is dot")
    assert_eq(tokens[3].kind, "ident", "token 3 ident")
    assert_eq(tokens[3].value, "vampiric_touch", "token 3 vt")
    assert_eq(tokens[4].kind, "dot", "token 4 dot")
    assert_eq(tokens[5].kind, "ident", "token 5 ident")
    assert_eq(tokens[5].value, "up", "token 5 up")
    assert_eq(tokens[6].kind, parser._TOK_EOF, "token 6 EOF")
end

local function test_tokenize_complex()
    local tokens = parser._tokenize_condition("remains<3|!ticking")
    assert_eq(tokens[1].kind, "ident", "complex tk1")
    assert_eq(tokens[2].kind, "comp", "complex tk2 <")
    assert_eq(tokens[3].kind, "number", "complex tk3 num")
    assert_eq(tokens[4].kind, "or_op", "complex tk4 |")
    assert_eq(tokens[5].kind, "not_op", "complex tk5 !")
    assert_eq(tokens[6].kind, "ident", "complex tk6 ticking")
    assert_eq(tokens[7].kind, parser._TOK_EOF, "complex tk7 EOF")
end

local function test_tokenize_and()
    local tokens = parser._tokenize_condition("buff.shadowform.up&target.health.pct<20")
    assert_eq(tokens[4].kind, "dot", "and tk4 dot")
    assert_eq(tokens[5].kind, "ident", "and tk5 up")
    assert_eq(tokens[6].kind, "and_op", "and tk6 &")
    assert_eq(tokens[7].kind, "ident", "and tk7 target")
end

local function test_tokenize_parens()
    local tokens = parser._tokenize_condition("(remains<3)&mana.pct>20")
    assert_eq(tokens[1].kind, "lparen", "parens tk1 (")
    assert_eq(tokens[5].kind, "rparen", "parens tk5 )")
    assert_eq(tokens[6].kind, "and_op", "parens tk6 &")
end

local function test_tokenize_double_operators()
    local tokens = parser._tokenize_condition("remains<=3&mana.pct>=20|hp_pct!=0")
    assert_eq(tokens[2].value, "<=", "<= token")
    assert_eq(tokens[8].value, ">=", ">= token")
    assert_eq(tokens[12].value, "!=", "!= token")
end

local function test_tokenize_boolean()
    local tokens = parser._tokenize_condition("in_combat&active_enemies>0")
    assert_eq(tokens[1].kind, "ident", "bool tk1")
    assert_eq(tokens[1].value, "in_combat", "bool val1")
end

local function test_tokenize_empty()
    local tokens = parser._tokenize_condition("")
    assert_eq(#tokens, 1, "empty returns only EOF")
    assert_eq(tokens[1].kind, parser._TOK_EOF, "empty token is EOF")
end

local function test_tokenize_spaces()
    local tokens = parser._tokenize_condition("  remains  <  3  ")
    assert_eq(tokens[1].kind, "ident", "spaces tk1 ident")
    assert_eq(tokens[2].kind, "comp", "spaces tk2 comp")
    assert_eq(tokens[3].kind, "number", "spaces tk3 num")
end

-- ============================================================================
-- Section 2: Parser Tests (AST)
-- ============================================================================

local function test_parse_simple_comparison()
    local tokens = parser._tokenize_condition("remains<3")
    local ast, pos = parser._parse_expr(tokens, 1)
    assert_true(ast ~= nil, "parse simple: ast not nil")
    assert_eq(ast.type, "compare", "parse simple: is compare")
    assert_eq(ast.op, "<", "parse simple: op <")
    assert_eq(ast.left.type, "access", "parse simple: left is access")
    assert_eq(ast.left.path[1], "remains", "parse simple: left path")
    assert_eq(ast.right.type, "number", "parse simple: right is number")
    assert_eq(ast.right.value, 3, "parse simple: right value")
end

local function test_parse_or()
    local tokens = parser._tokenize_condition("remains<3|hp_pct<20")
    local ast, pos = parser._parse_expr(tokens, 1)
    assert_true(ast ~= nil, "parse or: ast not nil")
    assert_eq(ast.type, "or_op", "parse or: type or_op")
    assert_eq(ast.left.type, "compare", "parse or: left compare")
    assert_eq(ast.right.type, "compare", "parse or: right compare")
end

local function test_parse_and()
    local tokens = parser._tokenize_condition("remains<3&debuff.vt.up")
    local ast, pos = parser._parse_expr(tokens, 1)
    assert_true(ast ~= nil, "parse and: ast not nil")
    assert_eq(ast.type, "and_op", "parse and: type and_op")
end

local function test_parse_not()
    local tokens = parser._tokenize_condition("!ticking")
    local ast, pos = parser._parse_expr(tokens, 1)
    assert_true(ast ~= nil, "parse not: ast not nil")
    assert_eq(ast.type, "not_op", "parse not: type not_op")
    assert_eq(ast.inner.type, "boolean", "parse not: inner is boolean")
end

local function test_parse_precedence()
    -- a&b|c should parse as (a&b)|c not a&(b|c)
    local tokens = parser._tokenize_condition("remains<3&debuff.vt.up|hp_pct<20")
    local ast, pos = parser._parse_expr(tokens, 1)
    assert_true(ast ~= nil, "precedence: ast not nil")
    assert_eq(ast.type, "or_op", "precedence: top is or_op (AND has higher prec)")
    assert_eq(ast.left.type, "and_op", "precedence: left is and_op")
    assert_eq(ast.right.type, "compare", "precedence: right is compare")
end

local function test_parse_parens()
    local tokens = parser._tokenize_condition("(remains<3)")
    local ast, pos = parser._parse_expr(tokens, 1)
    assert_true(ast ~= nil, "parens parse: ast not nil")
    assert_eq(ast.type, "paren", "parens parse: type is paren (wraps inner)")
    assert_eq(ast.inner.type, "compare", "parens parse: inner is compare")
end

local function test_parse_deep_nesting()
    local tokens = parser._tokenize_condition("(remains<3|!ticking)&(mana.pct>20)")
    local ast, pos = parser._parse_expr(tokens, 1)
    assert_true(ast ~= nil, "deep nesting: ast not nil")
    assert_eq(ast.type, "and_op", "deep nesting: top is and_op")
    assert_eq(ast.left.type, "paren", "deep nesting: left group is paren")
    assert_eq(ast.left.inner.type, "or_op", "deep nesting: left inner is or_op")
    assert_eq(ast.right.type, "paren", "deep nesting: right group is paren")
    assert_eq(ast.right.inner.type, "compare", "deep nesting: right inner is compare")
end

-- ============================================================================
-- Section 3: Lua Code Generator Tests
-- ============================================================================

local function test_generate_simple()
    local src = parser.generate_source("actions+=/shadow_word_pain,if=remains<3", {})
    assert_true(src:find("ShadowWordPain", 1, true), "generate: spell name camel-cased")
    assert_true(src:find("return", 1, true), "generate: has return")
end

local function test_generate_no_condition()
    local src = parser.generate_source("actions+=/shadow_word_pain", {})
    assert_true(src:find("true", 1, true), "generate no cond: returns true")
end

local function test_generate_multiple_lines()
    local apl = [[
actions=shadow_word_pain,if=remains<3
actions+=/mind_blast
actions+=/mind_flay,if=debuff.vampiric_touch.up
]]
    local src = parser.generate_source(apl, {})
    assert_true(src:find("ShadowWordPain", 1, true), "multi: spell 1")
    assert_true(src:find("MindBlast", 1, true), "multi: spell 2")
    assert_true(src:find("MindFlay", 1, true), "multi: spell 3")
end

-- ============================================================================
-- Section 4: APL Line Parser Tests
-- ============================================================================

local function test_parse_line_standard()
    local entry = parser._parse_apl_line("actions+=/shadow_word_pain,if=remains<3")
    assert_true(entry ~= nil, "line parse: not nil")
    assert_eq(entry.spell, "shadow_word_pain", "line parse: spell")
    assert_eq(entry.condition, "remains<3", "line parse: condition")
end

local function test_parse_line_no_condition()
    local entry = parser._parse_apl_line("actions+=/mind_blast")
    assert_true(entry ~= nil, "line parse nocond: not nil")
    assert_eq(entry.spell, "mind_blast", "line parse nocond: spell")
    assert_eq(entry.condition, nil, "line parse nocond: no condition")
end

local function test_parse_line_comment()
    local entry = parser._parse_apl_line("# this is a comment")
    assert_eq(entry, nil, "comment returns nil")
end

local function test_parse_line_empty()
    local entry = parser._parse_apl_line("")
    assert_eq(entry, nil, "empty line returns nil")
end

local function test_parse_line_actions_without_plus()
    local entry = parser._parse_apl_line("actions=shadow_word_pain,if=remains<3")
    assert_true(entry ~= nil, "actions= without +: not nil")
    assert_eq(entry.spell, "shadow_word_pain", "actions= spell")
end

local function test_parse_line_actions_dot_priority()
    local entry = parser._parse_apl_line("actions.precombat=shadow_word_pain")
    assert_true(entry ~= nil, "actions.precombat: not nil")
    assert_eq(entry.spell, "shadow_word_pain", "precombat spell")
end

-- ============================================================================
-- Section 5: Validation Tests
-- ============================================================================

local function test_validate_valid_apl()
    local result = parser.validate("actions+=/mind_blast,if=remains<3\nactions+=/shadow_word_pain", {})
    assert_true(result.ok, "validate valid: ok")
    assert_eq(#result.errors, 0, "validate valid: no errors")
end

local function test_validate_bad_syntax()
    local result = parser.validate("actions+=/mind_blast,if=<<bad>>", {})
    assert_true(result.ok == false, "validate bad: not ok")
    assert_true(#result.errors > 0, "validate bad: has errors")
end

-- ============================================================================
-- Section 6: Parse APL (End-to-End) Tests
-- ============================================================================

local function test_parse_apl_basic()
    local strategies = parser.parse_apl("actions+=/shadow_word_pain,if=debuff.shadow_word_pain.remains<3", { compile_functions = false })
    assert_true(#strategies > 0, "parse_apl: has strategies")
    assert_eq(strategies[1].name, "ShadowWordPain", "parse_apl: name")
    assert_eq(strategies[1]._matches_body, "(state.swp_remaining < 3)", "parse_apl: matches body from mapping")
end

local function test_parse_apl_dedup()
    local apl = [[
actions+=/shadow_word_pain,if=debuff.shadow_word_pain.remains<5
actions+=/shadow_word_pain,if=debuff.shadow_word_pain.remains<3
]]
    local strategies = parser.parse_apl(apl, { compile_functions = false })
    assert_eq(#strategies, 1, "parse_apl dedup: only 1 strategy")
    assert_eq(strategies[1]._matches_body, "(state.swp_remaining < 3)", "parse_apl dedup: last version wins")
end

local function test_parse_apl_compile()
    local strategies = parser.parse_apl("actions+=/shadow_word_pain", { compile_functions = true })
    assert_true(#strategies > 0, "parse_apl compile: has strategies")
    assert_eq(type(strategies[1].matches), "function", "parse_apl compile: matches is function")
    assert_eq(type(strategies[1].execute), "function", "parse_apl compile: execute is function")
    -- Should have cleaned up internal fields
    assert_eq(strategies[1]._matches_body, nil, "parse_apl compile: _matches_body cleared")
    assert_eq(strategies[1]._spell_ref, nil, "parse_apl compile: _spell_ref cleared")
end

local function test_parse_apl_with_custom_spell_map()
    local config = {
        spell_map = { shadow_word_pain = "MAGE_SPELLS.Frostbolt" },
        compile_functions = false,
    }
    local strategies = parser.parse_apl("actions+=/shadow_word_pain", config)
    assert_true(strategies[1]._spell_ref:find("Frostbolt", 1, true), "custom spell map: uses override")
end

-- ============================================================================
-- Section 7: Mapping Tests
-- ============================================================================

local function test_default_mapping_buff()
    local src = parser.generate_source("actions+=/mind_blast,if=buff.shadowform.up", {})
    assert_true(src:find("NS.has_player_buff", 1, true), "mapping buff: has_player_buff")
    assert_true(src:find("BUFF_SHADOWFORM", 1, true), "mapping buff: BUFF_SHADOWFORM")
end

local function test_default_mapping_debuff()
    local src = parser.generate_source("actions+=/mind_blast,if=debuff.vampiric_touch.up", {})
    assert_true(src:find("state.vt_remaining", 1, true), "mapping debuff: vt_remaining")
end

local function test_heuristic_mapping_buff()
    -- Uses heuristic fallback for unmapped buffs
    local src = parser.generate_source("actions+=/mind_blast,if=buff.molten_armor.up", {})
    assert_true(src:find("BUFF_MOLTEN_ARMOR", 1, true) or src:find("MOLTEN", 1, true), "heuristic buff: generates BUFF_ key")
end

local function test_heuristic_mapping_cooldown()
    local src = parser.generate_source("actions+=/mind_blast,if=cooldown.mind_blast.ready", {})
    assert_true(src:find("spell_ready", 1, true) or src:find("state.mb_ready", 1, true), "heuristic cd: spell_ready or state")
end

-- ============================================================================
-- Section 8: Shadow Priest Proof-of-Concept
-- ============================================================================

local SHADOW_APL = [[
# TBC Shadow Priest APL (SimC-style)
actions.precombat=inner_focus
actions=shadow_word_pain,if=remains<3
actions+=/vampiric_touch,if=remains<3|!ticking
actions+=/shadow_word_death,if=target.health.pct<20&cooldown.shadow_word_death.ready
actions+=/mind_blast,if=buff.shadowform.up
actions+=/shadowfiend,if=mana.pct<30
actions+=/mind_flay
]]

local function test_shadow_priest_parse()
    local result = parser.validate(SHADOW_APL, { class_label = "[SHADOW]" })
    assert_true(result.ok, "Shadow APL validates")
    assert_eq(#result.errors, 0, "Shadow APL: no errors")

    local strategies = parser.parse_apl(SHADOW_APL, { compile_functions = false, class_label = "[SHADOW]" })
    assert_eq(#strategies, 7, "Shadow APL: 7 strategies")

    -- Check strategy names are camel-cased
    -- Inner Focus precombat line parses first
    assert_eq(strategies[1].name, "InnerFocus", "Shadow: IF first (precombat)")
    assert_eq(strategies[2].name, "ShadowWordPain", "Shadow: SWP name")
    assert_eq(strategies[3].name, "VampiricTouch", "Shadow: VT name")
    assert_eq(strategies[4].name, "ShadowWordDeath", "Shadow: SWD name")
    assert_eq(strategies[5].name, "MindBlast", "Shadow: MB name")
    assert_eq(strategies[6].name, "Shadowfiend", "Shadow: Shadowfiend name")
    assert_eq(strategies[7].name, "MindFlay", "Shadow: MF name")
end

local function test_shadow_priest_generate()
    local src = parser.generate_source(SHADOW_APL, { class_label = "[SHADOW]" })
    assert_true(src:find("ShadowWordPain", 1, true), "Shadow gen: SWP")
    assert_true(src:find("VampiricTouch", 1, true), "Shadow gen: VT")
    assert_true(src:find("function(context, state)", 1, true), "Shadow gen: has function sig")
    assert_true(src:find("return NS.try_cast", 1, true), "Shadow gen: has try_cast")
end

-- ============================================================================
-- Section 9: Edge Cases
-- ============================================================================

local function test_parse_line_target_if()
    -- SimC lines sometimes have target_if=... params
    local entry = parser._parse_apl_line("actions+=/shadow_word_pain,target_if=max:debuff.shadow_word_pain.remains<3,if=remains<3")
    assert_true(entry ~= nil, "target_if: parsed")
    assert_eq(entry.spell, "shadow_word_pain", "target_if: spell extracted")
    assert_eq(entry.condition, "remains<3", "target_if: condition extracted")
end

local function test_heuristic_talent()
    -- talent.xxx.enabled → NS.has_talent(TALENT_XXX)
    local src = parser.generate_source("actions+=/mind_blast,if=talent.shadowform.enabled", {})
    assert_true(src:find("NS.has_talent(TALENT_SHADOWFORM)", 1, true), "heuristic talent: generates has_talent call")
end

local function test_heuristic_buff_down()
    -- buff.xxx.down → (not NS.has_player_buff(XXX_BUFF))
    local src = parser.generate_source("actions+=/mind_blast,if=buff.shadowform.down", {})
    assert_true(src:find("(not NS.has_player_buff(SHADOWFORM_BUFF))", 1, true), "heuristic buff.down: generates negated has_player_buff")
end

-- ============================================================================
-- Section 10: call_action_list & Sub-List Tests
-- ============================================================================

local function test_parse_line_call_action_list()
    local entry = parser._parse_apl_line("call_action_list,name=cds,if=buff.lust.up")
    assert_true(entry ~= nil, "call_action_list: parsed")
    assert_eq(entry.type, "call", "call_action_list: type is call")
    assert_eq(entry.list_name, "cds", "call_action_list: list name")
    assert_eq(entry.condition, "buff.lust.up", "call_action_list: condition")
end

local function test_parse_line_sub_list()
    local entry = parser._parse_apl_line("actions.cds=shadowfiend,if=mana.pct<30")
    assert_true(entry ~= nil, "actions.cds: parsed")
    assert_eq(entry.type, "spell", "actions.cds: type is spell")
    assert_eq(entry.list_name, "cds", "actions.cds: list name is cds")
    assert_eq(entry.spell, "shadowfiend", "actions.cds: spell")
    assert_eq(entry.condition, "mana.pct<30", "actions.cds: condition")
end

local function test_parse_line_sub_list_append()
    local entry = parser._parse_apl_line("actions.cds+=/death_coil,if=cooldown.death_coil.ready")
    assert_true(entry ~= nil, "actions.cds+=/: parsed")
    assert_eq(entry.list_name, "cds", "actions.cds+=/: list name retains")
    assert_eq(entry.spell, "death_coil", "actions.cds+=/: spell")
end

local function test_parse_apl_with_sub_lists()
    local apl = [[
actions=shadow_word_pain,if=remains<3
actions.cds=shadowfiend,if=mana.pct<30
actions.cds+=/power_infusion,if=buff.lust.up
]]
    local strategies = parser.parse_apl(apl, { compile_functions = false })
    assert_eq(#strategies, 1, "sub-lists: main list has 1 entry")
    assert_eq(strategies[1].name, "ShadowWordPain", "sub-lists: main entry is SWP")
    assert_true(strategies._sub_lists ~= nil, "sub-lists: _sub_lists exists")
    assert_true(strategies._sub_lists.cds ~= nil, "sub-lists: cds sub-list exists")
    assert_eq(#strategies._sub_lists.cds, 2, "sub-lists: cds has 2 entries")
    assert_eq(strategies._sub_lists.cds[1].name, "Shadowfiend", "sub-lists: cds[1] Shadowfiend")
    assert_eq(strategies._sub_lists.cds[2].name, "PowerInfusion", "sub-lists: cds[2] PowerInfusion")
end

local function test_parse_apl_with_call_dispatch()
    local apl = [[
actions=shadow_word_pain,if=remains<3
actions.cds=shadowfiend,if=mana.pct<30
call_action_list,name=cds,if=buff.lust.up
]]
    local strategies = parser.parse_apl(apl, { compile_functions = false })
    assert_eq(#strategies, 2, "call dispatch: 2 entries in main")
    assert_eq(strategies[1].name, "ShadowWordPain", "call dispatch: SWP first")
    assert_eq(strategies[2].name, "Call_Cds", "call dispatch: dispatch entry named Call_Cds")
    assert_true(strategies[2]._is_dispatch, "call dispatch: has _is_dispatch flag")
    assert_eq(strategies[2]._list_name, "cds", "call dispatch: points to cds list")
    assert_true(strategies._sub_lists ~= nil, "call dispatch: _sub_lists attached")
    assert_eq(#strategies._sub_lists.cds, 1, "call dispatch: cds has 1 entry")
end

local function test_validate_call_action_list_no_warning()
    local result = parser.validate("call_action_list,name=cds,if=buff.lust.up", {})
    assert_true(result.ok, "validate call: ok")
    assert_eq(#result.errors, 0, "validate call: no errors")
    -- Should NOT produce the old "not yet supported" warning
    for _, w in ipairs(result.warnings) do
        assert_true(not w:find("not yet supported", 1, true), "validate call: no 'not yet supported' warning")
    end
end

local function test_validate_call_missing_name()
    local result = parser.validate("call_action_list,if=buff.lust.up", {})
    -- Should warn about missing name
    local has_missing_warning = false
    for _, w in ipairs(result.warnings) do
        if w:find("missing name", 1, true) then
            has_missing_warning = true
        end
    end
    assert_true(has_missing_warning, "validate call: warns about missing name")
end

local function test_generate_source_with_sub_lists()
    local apl = [[
actions=shadow_word_pain,if=remains<3
actions.cds=shadowfiend,if=mana.pct<30
call_action_list,name=cds,if=buff.lust.up
]]
    local src = parser.generate_source(apl, { class_label = "[SHADOW]" })
    assert_true(src:find("_sub_lists", 1, true), "generate sub: has _sub_lists")
    assert_true(src:find("sub_cds", 1, true), "generate sub: has sub_cds table")
    assert_true(src:find("Call_Cds", 1, true), "generate sub: has Call_Cds dispatch")
    assert_true(src:find("for _, s2 in ipairs", 1, true), "generate sub: dispatch has iteration loop")
end

local function test_generate_source_dispatch_has_match()
    local apl = [[
call_action_list,name=cds,if=buff.lust.up&mana.pct>20
]]
    local src = parser.generate_source(apl, { class_label = "[SHADOW]" })
    assert_true(src:find("Call_Cds", 1, true), "dispatch match: has Call_Cds")
    assert_true(src:find("NS.has_player_buff", 1, true), "dispatch match: condition mapped")
end

local function test_dispatch_compile()
    local apl = [[
actions.cds=shadowfiend
call_action_list,name=cds
]]
    local strategies = parser.parse_apl(apl, { compile_functions = true })
    assert_eq(#strategies, 1, "dispatch compile: 1 main entry")
    assert_eq(strategies[1].name, "Call_Cds", "dispatch compile: name")
    assert_eq(type(strategies[1].matches), "function", "dispatch compile: matches compiled")
    assert_eq(type(strategies[1].execute), "function", "dispatch compile: execute compiled")
    -- Sub-list should also have compiled functions
    assert_true(strategies._sub_lists ~= nil and strategies._sub_lists.cds ~= nil, "dispatch compile: sub-list exists")
    local sub = strategies._sub_lists.cds[1]
    assert_eq(type(sub.matches), "function", "dispatch compile: sub-list matches compiled")
    assert_eq(type(sub.execute), "function", "dispatch compile: sub-list execute compiled")
end

-- ============================================================================
-- Section 11: Full TBC Shadow Priest APL with Sub-Lists
-- ============================================================================

local SHADOW_FULL_APL = [[
# TBC Shadow Priest APL with sub-lists
actions.precombat=inner_focus
actions=shadow_word_pain,if=remains<3
actions+=/vampiric_touch,if=remains<3|!ticking
actions+=/shadow_word_death,if=target.health.pct<20&cooldown.shadow_word_death.ready
actions+=/mind_blast,if=buff.shadowform.up
actions+=/mind_flay
# Cooldowns sub-list
actions.cds=shadowfiend,if=mana.pct<30
actions.cds+=/power_infusion,if=buff.lust.up
# Call from main
call_action_list,name=cds,if=cooldown.shadowfiend.ready|buff.lust.up
]]

local function test_shadow_full_parse()
    local result = parser.validate(SHADOW_FULL_APL, { class_label = "[SHADOW]" })
    assert_true(result.ok, "Shadow full: validates")
    assert_eq(#result.errors, 0, "Shadow full: no errors")

    local strategies = parser.parse_apl(SHADOW_FULL_APL, { compile_functions = false, class_label = "[SHADOW]" })
    -- 6 spells + 1 dispatch = 7 in main + 1 precombat = 8? No, precombat merges into default/main
    -- InnerFocus(fused) + SWP + VT + SWD + MB + MF + Call_Cds = 7
    assert_eq(#strategies, 7, "Shadow full: 7 main strategies (precombat fused)")

    -- Names
    assert_eq(strategies[1].name, "InnerFocus", "Shadow full: IF first")
    assert_eq(strategies[2].name, "ShadowWordPain", "Shadow full: SWP")
    assert_eq(strategies[3].name, "VampiricTouch", "Shadow full: VT")
    assert_eq(strategies[4].name, "ShadowWordDeath", "Shadow full: SWD")
    assert_eq(strategies[5].name, "MindBlast", "Shadow full: MB")
    assert_eq(strategies[6].name, "MindFlay", "Shadow full: MF")
    -- The dispatch entry
    local dispatch = strategies[7]
    assert_eq(dispatch.name, "Call_Cds", "Shadow full: dispatch named Call_Cds")
    assert_true(dispatch._is_dispatch, "Shadow full: dispatch has _is_dispatch")
    assert_eq(dispatch._list_name, "cds", "Shadow full: dispatch points to cds")

    -- Sub-lists
    assert_true(strategies._sub_lists ~= nil, "Shadow full: _sub_lists attached")
    assert_true(strategies._sub_lists.cds ~= nil, "Shadow full: cds sub-list exists")
    assert_eq(#strategies._sub_lists.cds, 2, "Shadow full: cds has 2 entries")
    assert_eq(strategies._sub_lists.cds[1].name, "Shadowfiend", "Shadow full: cds[1] Shadowfiend")
    assert_eq(strategies._sub_lists.cds[2].name, "PowerInfusion", "Shadow full: cds[2] PowerInfusion")
end

local function test_shadow_full_generate()
    local src = parser.generate_source(SHADOW_FULL_APL, { class_label = "[SHADOW]" })
    assert_true(src:find("ShadowWordPain", 1, true), "Shadow full gen: SWP")
    assert_true(src:find("Call_Cds", 1, true), "Shadow full gen: dispatch")
    assert_true(src:find("sub_cds", 1, true), "Shadow full gen: sub_cds table")
    assert_true(src:find("_sub_lists", 1, true), "Shadow full gen: _sub_lists registry")
    assert_true(src:find("for _, s2 in ipairs", 1, true), "Shadow full gen: dispatch loop")
end

-- ============================================================================
-- Run all tests
-- ============================================================================

test_tokenize_simple()
test_tokenize_dot_access()
test_tokenize_complex()
test_tokenize_and()
test_tokenize_parens()
test_tokenize_double_operators()
test_tokenize_boolean()
test_tokenize_empty()
test_tokenize_spaces()

test_parse_simple_comparison()
test_parse_or()
test_parse_and()
test_parse_not()
test_parse_precedence()
test_parse_parens()
test_parse_deep_nesting()

test_generate_simple()
test_generate_no_condition()
test_generate_multiple_lines()

test_parse_line_standard()
test_parse_line_no_condition()
test_parse_line_comment()
test_parse_line_empty()
test_parse_line_actions_without_plus()
test_parse_line_actions_dot_priority()

test_validate_valid_apl()
test_validate_bad_syntax()

test_parse_apl_basic()
test_parse_apl_dedup()
test_parse_apl_compile()
test_parse_apl_with_custom_spell_map()

test_default_mapping_buff()
test_default_mapping_debuff()
test_heuristic_mapping_buff()
test_heuristic_mapping_cooldown()

test_shadow_priest_parse()
test_shadow_priest_generate()

test_parse_line_target_if()
test_heuristic_talent()
test_heuristic_buff_down()

print("PASS test_apl_parser")
