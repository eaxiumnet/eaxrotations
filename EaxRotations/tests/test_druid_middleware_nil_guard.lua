-- Unit tests for druid middleware BearFormPreCombat playstyle gate.
-- Verifies that the bear-only gate prevents non-bear specs from auto-entering bear form OOC.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

_G._druid_strategies = nil
_G._mock_player = {
    buff_remains = function(self, buff_id) return 0 end,
    has_buff = function(self, buff_id) return false end,
}

_G.core = {
    spell_book = {
        is_spell_learned = function() return false end,
    },
    object_manager = {
        get_party_frames = function() return {} end,
    },
}

_G.EaxRotations = {
    DruidSpells = {
        BearForm = 9634,
        CatForm = 768,
        RemoveCurse = 5186,
        AbolishPoison = 2893,
        Cower = 8998,
        MarkOfTheWild = 26990,
        Thorns = 467,
    },
    PLAYER_UNIT = {},
    register_class_middleware = function(class_key, strategies)
        _G._druid_strategies = strategies
    end,
    spell_ready = function(...) return true end,
    spell_castable_via_izi = function(...) return true end,
    try_cast = function(...) return true end,
    debuff_up = function(unit, ids) return false end,
    has_player_buff = function(ids) return false end,
    has_buff = function(ids) return false end,
    buff_up = function(unit, ids) return false end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return false end,
    action_matches = function(...) return false end,
    action_execute = function(...) return false end,
    time_now = function() return 0 end,
    get_setting = function(key, default) return default end,
    power_current = function() return 100 end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

-- Load the middleware file
local strategies = dofile("EaxRotations/classes/druid/middleware_sylvanas.lua")
assert_true(strategies, "strategies table should load")
assert_true(type(strategies) == "table", "strategies table exists")

-- Helper to find strategy by name
local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- BearFormPreCombat (OOC, bear-only playstyle gate)
-- ============================================================================
local bear_form = find_strategy("BearFormPreCombat")

do
    -- Base context: OOC, not mounted, not in bear form
    local ctx_base = {
        in_combat = false,
        is_mounted = false,
        settings = {},
        me = _G._mock_player,
    }

    -- Test 1: Bear playstyle -> true (gate passes, OOC, no bear form)
    local ctx = ctx_base
    ctx.settings = { playstyle = "bear" }
    assert_true(bear_form.matches(ctx), "BearFormPreCombat: bear playstyle -> true")

    -- Test 2: Balance playstyle -> false (playstyle gate)
    ctx.settings = { playstyle = "balance" }
    assert_false(bear_form.matches(ctx), "BearFormPreCombat: balance -> false (playstyle gate)")

    -- Test 3: Resto playstyle -> false (playstyle gate)
    ctx.settings = { playstyle = "resto" }
    assert_false(bear_form.matches(ctx), "BearFormPreCombat: resto -> false (playstyle gate)")

    -- Test 4: Cat playstyle -> false (playstyle gate)
    ctx.settings = { playstyle = "cat" }
    assert_false(bear_form.matches(ctx), "BearFormPreCombat: cat -> false (playstyle gate)")

    -- Test 5: Caster playstyle -> false (playstyle gate)
    ctx.settings = { playstyle = "caster" }
    assert_false(bear_form.matches(ctx), "BearFormPreCombat: caster -> false (playstyle gate)")

    -- Test 6: No playstyle set -> false (default "" not "bear")
    ctx.settings = {}
    assert_false(bear_form.matches(ctx), "BearFormPreCombat: no playstyle -> false (gate)")

    -- Test 7: Bear playstyle + auto_bear_form_ooc = false -> false (toggle gate)
    ctx.settings = { playstyle = "bear", auto_bear_form_ooc = false }
    assert_false(bear_form.matches(ctx), "BearFormPreCombat: bear but toggle off -> false")

    -- Test 8: Bear playstyle + in combat -> false (combat gate fires before playstyle)
    ctx.settings = { playstyle = "bear" }
    ctx.in_combat = true
    assert_false(bear_form.matches(ctx), "BearFormPreCombat: bear in combat -> false")

    -- Test 9: Bear playstyle + already in bear form -> false (buff check)
    ctx.in_combat = false
    local orig_buff = _G.EaxRotations.has_player_buff
    _G.EaxRotations.has_player_buff = function(ids) return true end  -- Simulate already in bear form
    assert_false(bear_form.matches(ctx), "BearFormPreCombat: bear already in form -> false")
    _G.EaxRotations.has_player_buff = orig_buff  -- Restore

    -- Test 10: active_playstyle = "bear" -> true (fallback key passes gate)
    ctx.settings = { active_playstyle = "bear" }
    assert_true(bear_form.matches(ctx), "BearFormPreCombat: active_playstyle=bear -> true")

    -- Test 11: active_playstyle = "resto" -> false (fallback key catches gate)
    ctx.settings = { active_playstyle = "resto" }
    assert_false(bear_form.matches(ctx), "BearFormPreCombat: active_playstyle=resto -> false (gate)")
end

-- ============================================================================
-- MarkOfTheWild (Self-buff, checks use_self_buffs, has_player_buff, spell_ready)
-- Verifies nil-guards: NS.has_player_buff and, NS.spell_ready and
-- ============================================================================
local motw = find_strategy("MarkOfTheWild")

do
    -- Create a fresh mock player for these tests
    local mock_me = {
        buff_remains = function(self, buff_id) return 0 end,
        has_buff = function(self, buff_id) return false end,
    }
    local ctx_base = {
        in_combat = false,
        is_mounted = false,
        me = mock_me,
        settings = {},
    }

    -- Test 12: NS.has_player_buff = nil -> nil and ... returns nil, no crash
    local ctx = ctx_base
    local orig_hpb = _G.EaxRotations.has_player_buff
    _G.EaxRotations.has_player_buff = nil
    local ok, err = pcall(motw.matches, ctx)
    _G.EaxRotations.has_player_buff = orig_hpb
    assert_true(ok, "MarkOfTheWild: has_player_buff nil -> pcall should not error. Error: " .. tostring(err))
    -- With has_player_buff nil, nil and ... returns nil (falsy), passes through to spell_ready check.
    -- Since spell_ready is mocked to return true, matches returns true (no buff, ready to cast).

    -- Test 13: NS.spell_ready = nil -> nil and ... returns nil, no crash
    local orig_sr = _G.EaxRotations.spell_ready
    _G.EaxRotations.spell_ready = nil
    _G.EaxRotations.has_player_buff = orig_hpb  -- Restore has_player_buff
    local ok2, err2 = pcall(motw.matches, ctx)
    _G.EaxRotations.spell_ready = orig_sr
    assert_true(ok2, "MarkOfTheWild: spell_ready nil -> pcall should not error. Error: " .. tostring(err2))

    -- Test 14: Both has_player_buff AND spell_ready nil -> no crash on either guard
    _G.EaxRotations.has_player_buff = nil
    _G.EaxRotations.spell_ready = nil
    local ok3, err3 = pcall(motw.matches, ctx)
    _G.EaxRotations.has_player_buff = orig_hpb
    _G.EaxRotations.spell_ready = orig_sr
    assert_true(ok3, "MarkOfTheWild: both has_player_buff & spell_ready nil -> pcall should not error. Error: " .. tostring(err3))
end

-- ============================================================================
-- Thorns (Self-buff, same guard pattern as MarkOfTheWild)
-- Verifies nil-guards: NS.has_player_buff and, NS.spell_ready and
-- ============================================================================
local thorns = find_strategy("Thorns")

do
    local mock_me = {
        buff_remains = function(self, buff_id) return 0 end,
        has_buff = function(self, buff_id) return false end,
    }
    local ctx = {
        in_combat = false,
        is_mounted = false,
        me = mock_me,
        settings = {},
    }

    -- Test 15: NS.has_player_buff = nil -> no crash
    local orig_hpb = _G.EaxRotations.has_player_buff
    _G.EaxRotations.has_player_buff = nil
    local ok, err = pcall(thorns.matches, ctx)
    _G.EaxRotations.has_player_buff = orig_hpb
    assert_true(ok, "Thorns: has_player_buff nil -> pcall should not error. Error: " .. tostring(err))

    -- Test 16: NS.spell_ready = nil -> no crash
    local orig_sr = _G.EaxRotations.spell_ready
    _G.EaxRotations.spell_ready = nil
    local ok2, err2 = pcall(thorns.matches, ctx)
    _G.EaxRotations.spell_ready = orig_sr
    assert_true(ok2, "Thorns: spell_ready nil -> pcall should not error. Error: " .. tostring(err2))
end

-- ============================================================================
-- PartyDispel (Party scan, checks auto_dispel, playstyle keys, debuff_up)
-- Verifies nil-guards: context.settings or {}, context.me or NS.GetPlayer()
-- ============================================================================
local party_dispel = find_strategy("PartyDispel")

do
    local mock_me = {
        buff_remains = function(self, buff_id) return 0 end,
        has_buff = function(self, buff_id) return false end,
    }
    local ctx_base = {
        in_combat = true,
        me = mock_me,
        settings = { auto_dispel = true, playstyle = "resto" },
    }

    -- Test 17: No settings table -> local settings = context.settings or {}, no crash
    local ctx_no_settings = {
        in_combat = true,
        me = mock_me,
    }
    local ok, err = pcall(party_dispel.matches, ctx_no_settings)
    assert_true(ok, "PartyDispel: no settings table -> pcall should not error. Error: " .. tostring(err))

    -- Test 18: No me object -> local me = context.me or NS.GetPlayer(), no crash
    local ctx_no_me = {
        in_combat = true,
        settings = { auto_dispel = true, playstyle = "resto" },
    }
    -- Save/restore GetPlayer since it may be called
    local orig_get_player = _G.EaxRotations.GetPlayer
    _G.EaxRotations.GetPlayer = function() return mock_me end
    local ok2, err2 = pcall(party_dispel.matches, ctx_no_me)
    _G.EaxRotations.GetPlayer = orig_get_player
    assert_true(ok2, "PartyDispel: no me object -> pcall should not error. Error: " .. tostring(err2))

    -- Test 19: Both settings AND me nil -> no crash from either missing field
    local ctx_bare = { in_combat = true }
    _G.EaxRotations.GetPlayer = function() return mock_me end
    local ok3, err3 = pcall(party_dispel.matches, ctx_bare)
    _G.EaxRotations.GetPlayer = orig_get_player
    assert_true(ok3, "PartyDispel: neither settings nor me -> pcall should not error. Error: " .. tostring(err3))
end

-- ============================================================================
-- FormAwareConsumables (In-combat pot/stone with form checks)
-- Verifies nil-guards: context.settings or {}, NS.is_item_ready and, NS.use_item_by_id and
-- ============================================================================
local form_cons = find_strategy("FormAwareConsumables")

do
    local mock_me = {
        buff_remains = function(self, buff_id) return 0 end,
        has_buff = function(self, buff_id) return false end,
    }
    local ctx = {
        in_combat = true,
        is_stealthed = false,
        stance = 0,  -- Caster form
        hp = 20,
        me = mock_me,
        settings = {},
    }

    -- Test 20: NS.is_item_ready = nil -> nil and ... returns nil, no crash
    local orig_iir = _G.EaxRotations.is_item_ready
    _G.EaxRotations.is_item_ready = nil
    local ok, err = pcall(form_cons.matches, ctx)
    _G.EaxRotations.is_item_ready = orig_iir
    assert_true(ok, "FormAwareConsumables: is_item_ready nil -> pcall should not error. Error: " .. tostring(err))

    -- Test 21: NS.use_item_by_id = nil -> no crash (gate in matches only, execute would use it)
    local orig_uibi = _G.EaxRotations.use_item_by_id
    _G.EaxRotations.use_item_by_id = nil
    local ok2, err2 = pcall(form_cons.matches, ctx)
    _G.EaxRotations.use_item_by_id = orig_uibi
    assert_true(ok2, "FormAwareConsumables: use_item_by_id nil -> pcall should not error. Error: " .. tostring(err2))

    -- Test 22: context.settings = nil -> local settings = context.settings or {}, no crash
    local ctx_no_stg = {
        in_combat = true,
        is_stealthed = false,
        stance = 0,
        hp = 20,
        me = mock_me,
    }
    _G.EaxRotations.is_item_ready = orig_iir  -- Restore
    local ok3, err3 = pcall(form_cons.matches, ctx_no_stg)
    assert_true(ok3, "FormAwareConsumables: no settings table -> pcall should not error. Error: " .. tostring(err3))

    -- Test 23: Both is_item_ready AND use_item_by_id nil -> no crash from either guard
    _G.EaxRotations.is_item_ready = nil
    _G.EaxRotations.use_item_by_id = nil
    local ok4, err4 = pcall(form_cons.matches, ctx)
    _G.EaxRotations.is_item_ready = orig_iir
    _G.EaxRotations.use_item_by_id = orig_uibi
    assert_true(ok4, "FormAwareConsumables: both is_item_ready & use_item_by_id nil -> pcall should not error. Error: " .. tostring(err4))
end

-- ============================================================================
-- Cleanup
-- ============================================================================
_G._druid_strategies = nil
_G._mock_player = nil

print("PASS test_druid_middleware_nil_guard")
