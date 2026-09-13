-- test_druid_form_stay_cat.lua -- TBC druid: never leave Cat Form to run a lane.
-- WHAT:  pins the shared shapeshift detector (bar index + aura), the druid
--        middleware's caster-only gates (Mark of the Wild / Thorns / party
--        dispel), and the OOC manager's druid form gate.
-- WHEN:  standalone: `lua EaxRotations/tests/test_druid_form_stay_cat.lua`
-- WHY:   live report (2026-09-13): a TBC feral/cat druid left Cat Form right
--        after combat ended, when the OOC lanes re-evaluated. Every gate
--        asserted below was dead or absent before that fix:
--          * the middleware's only form gate was `can_cast_in_current_form`,
--            which returns true on every live client (NS.can_cast_in_form does
--            not exist in production), so MotW/Thorns fired while shifted;
--          * the OOC manager's guard sat inside try_self_buffs, leaving rank
--            upgrades (buff_upgrade_sylvanas) and food/flask ungated.
--        Each assertion is paired with its unshifted control, so a gate that
--        simply never fires cannot pass this suite.
-- SAFETY: isolated mocked NS; no production code or live game state touched.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local passed = 0
local failed = 0

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label)
    if a ~= b then
        error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS: " .. name)
    else
        failed = failed + 1
        print("  FAIL: " .. name .. " -- " .. tostring(err))
    end
end

-- Drop every cached shared/ module so each phase builds against the NS it just
-- installed (those modules capture _G.EaxRotations members at load time).
local function reset_shared_modules()
    for name, _ in pairs(package.loaded) do
        if type(name) == "string" and name:find("^shared/") then
            package.loaded[name] = nil
        end
    end
end

-- ============================================================================
-- PHASE A: shared/druid_form_sylvanas -- one detector, every source
-- ============================================================================

local function load_detector(ns)
    _G.EaxRotations = ns
    reset_shared_modules()
    return dofile("EaxRotations/shared/druid_form_sylvanas.lua")
end

-- The engine stance source stops at 3 (bear/aquatic/cat); Moonkin and Tree are
-- resolved by aura below, and an index it cannot name is still a form.
test("detector: bar index maps the engine forms, unknown index still counts as shifted", function()
    local form = load_detector({})
    assert_eq(form.current({ stance = 1 }), "bear", "1 = bear")
    assert_eq(form.current({ stance = 2 }), "aquatic", "2 = aquatic")
    assert_eq(form.current({ stance = 3 }), "cat", "3 = cat")
    assert_eq(form.current({ stance = 4 }), "form", "index 4 is a form, just an unnamed one")
    assert_eq(form.current({ stance = 7 }), "form", "unknown index is still a form")
    assert_eq(form.current({ stance = 0 }), nil, "0 = caster")
    assert_false(form.is_shifted({ stance = 0 }), "stance 0 is not shifted")
    assert_true(form.is_shifted({ stance = 4 }), "index 4 is shifted even when unnamed")
    assert_true(form.is_cat({ stance = 3 }), "stance 3 is cat")
    assert_false(form.is_cat({ stance = 1 }), "bear is not cat")
    assert_true(form.is_feral({ stance = 3 }), "cat is feral")
    assert_true(form.is_feral({ stance = 1 }), "bear is feral")
    assert_false(form.is_feral({ stance = 2 }), "aquatic is not feral")
end)

test("detector: aura API alone is enough when no stance is available", function()
    local form = load_detector({
        has_form = function(name) return name == "cat" end,
    })
    assert_eq(form.current({}), "cat", "aura cat")
    assert_true(form.is_cat({}), "aura is_cat")
    local bear = load_detector({ has_form = function(name) return name == "bear" end })
    assert_eq(bear.current({}), "bear", "aura bear")
    local moonkin = load_detector({ has_form = function(name) return name == "moonkin" end })
    assert_eq(moonkin.current({}), "moonkin", "aura moonkin")
    local tree = load_detector({ has_form = function(name) return name == "tree" end })
    assert_eq(tree.current({}), "tree", "aura tree")
    assert_false(moonkin.is_feral({}), "moonkin is not feral")
    assert_false(tree.is_feral({}), "tree is not feral")
    -- Documented boundary: core's FORMS table has no travel/aquatic entry and
    -- the engine stance stops at 3, so a travel-form druid reads as caster
    -- here -- exactly as it did before this module existed. Pinned so that a
    -- future fix has to update this line deliberately.
    local travel = load_detector({ has_form = function(name) return name == "travel" end })
    assert_eq(travel.current({}), nil, "travel has no engine stance and no FORMS aura entry")
end)

test("detector: falls back to NS.get_player_stance when the context has no stance", function()
    local form = load_detector({ get_player_stance = function() return 3 end })
    assert_eq(form.current({}), "cat", "stance producer read")
    assert_eq(form.current({ stance = 1 }), "bear", "context stance is the fast path and wins")
end)

test("detector: a broken source degrades instead of throwing", function()
    local throwing_aura = load_detector({ has_form = function() error("crash") end })
    local ok, value = pcall(throwing_aura.current, {})
    assert_true(ok, "throwing has_form must not raise")
    assert_eq(value, nil, "no answer -> caster")

    local throwing_stance = load_detector({
        get_player_stance = function() error("crash") end,
        has_form = function(name) return name == "cat" end,
    })
    assert_eq(throwing_stance.current({}), "cat", "aura answers when the stance producer throws")

    local no_sources = load_detector({})
    assert_eq(no_sources.current({}), nil, "no sources -> caster")
    assert_eq(no_sources.current(nil), nil, "nil context is safe")
end)

-- ============================================================================
-- PHASE B: druid middleware caster-only gates
-- ============================================================================

local mock_me = { buff_remains = function() return 0 end, has_buff = function() return false end }

local function load_middleware(extra_ns)
    local dispel_ran = false
    local ns = {
        CLASS_ID = { DRUID = 11 },
        DruidSpells = {
            BearForm = 9634, CatForm = 768, RemoveCurse = 5186, AbolishPoison = 2893,
            Cower = 8998, MarkOfTheWild = 26990, Thorns = 467,
        },
        PLAYER_UNIT = {},
        core = { spell_book = { is_spell_learned = function() return true end } },
        register_class_middleware = function(_, strategies) _G._druid_form_strategies = strategies end,
        spell_ready = function() return true end,
        try_cast = function() return true end,
        debuff_up = function() return false end,
        has_player_buff = function() return false end,
        has_buff = function() return false end,
        buff_up = function() return false end,
        is_item_ready = function() return false end,
        use_item_by_id = function() return false end,
        action_matches = function() return false end,
        action_execute = function() return false end,
        time_now = function() return 0 end,
        get_setting = function(_, default) return default end,
        power_current = function() return 100 end,
        log = function() end,
        GetPartyMembers = function() return {} end,
        rotation_registry = { register = function() end },
        -- DispelManager stub: proves the party-dispel execute is gated BEFORE the
        -- shared strategy runs (a real manager would cast Remove Curse).
        DispelManager = {
            create_dispel_strategy = function()
                return {
                    matches = function() return true end,
                    execute = function() dispel_ran = true; return true end,
                }
            end,
        },
    }
    for k, v in pairs(extra_ns or {}) do ns[k] = v end
    _G.EaxRotations = ns
    _G._druid_form_strategies = nil
    reset_shared_modules()
    dofile("EaxRotations/classes/druid/middleware_sylvanas.lua")
    local function find(name)
        local list = _G._druid_form_strategies
        assert_true(type(list) == "table", "middleware did not register strategies")
        for i = 1, #list do
            if list[i].name == name then return list[i] end
        end
        error("strategy not found: " .. name)
    end
    return find, function() return dispel_ran end
end

test("middleware MarkOfTheWild: blocked by the bar index alone (aura API lying)", function()
    local find = load_middleware({ has_form = function() return false end })
    local motw = find("MarkOfTheWild")

    -- Control: unshifted -> the lane still fires (this keeps the gate non-vacuous).
    assert_true(motw.matches({ in_combat = false, me = mock_me, settings = {}, stance = 0 }),
        "caster form -> MotW fires")

    -- The regression: shifted per the shapeshift bar index while the aura lies.
    assert_false(motw.matches({ in_combat = false, me = mock_me, settings = {}, stance = 3 }),
        "cat form (bar index 3) -> MotW holds")
    assert_false(motw.matches({ in_combat = false, me = mock_me, settings = {}, stance = 1 }),
        "bear form -> MotW holds")
    assert_false(motw.matches({ in_combat = false, me = mock_me, settings = {}, stance = 2 }),
        "aquatic form -> MotW holds")
    assert_false(motw.matches({ in_combat = false, me = mock_me, settings = {}, stance = 4 }),
        "unnamed form index -> MotW holds (MotW is caster-only in EVERY form)")
end)

test("middleware MarkOfTheWild: blocked by the aura source alone, Moonkin and Tree included", function()
    local find = load_middleware({ has_form = function(name) return name == "cat" end })
    assert_false(find("MarkOfTheWild").matches({ in_combat = false, me = mock_me, settings = {} }),
        "aura-only cat form -> MotW holds")
    -- MotW is caster-only in EVERY form, so the aura path must block these too.
    local moonkin = load_middleware({ has_form = function(name) return name == "moonkin" end })
    assert_false(moonkin("MarkOfTheWild").matches({ in_combat = false, me = mock_me, settings = {} }),
        "aura-only moonkin -> MotW holds")
    local tree = load_middleware({ has_form = function(name) return name == "tree" end })
    assert_false(tree("MarkOfTheWild").matches({ in_combat = false, me = mock_me, settings = {} }),
        "aura-only tree -> MotW holds")
end)

test("middleware Thorns: same gate, both sources", function()
    local find = load_middleware({})
    local thorns = find("Thorns")
    assert_true(thorns.matches({ in_combat = false, me = mock_me, settings = {}, stance = 0 }),
        "caster form -> Thorns fires")
    assert_false(thorns.matches({ in_combat = false, me = mock_me, settings = {}, stance = 3 }),
        "cat form -> Thorns holds")
    assert_false(thorns.matches({ in_combat = false, me = mock_me, settings = {}, stance = 4 }),
        "unnamed form index -> Thorns holds")
end)

test("middleware party dispel: refused in the feral forms ONLY", function()
    local find, dispel_did_run = load_middleware({})
    local dispel = find("PartyDispel")
    assert_true(dispel.matches({ in_combat = true, me = mock_me, settings = {}, stance = 3 }),
        "matches still reports the intent in combat")

    -- Cat and Bear cannot cast Remove Curse / Abolish Poison: the client
    -- refuses, so the execute is gated.
    assert_false(dispel.execute({ in_combat = true, me = mock_me, settings = {}, stance = 3 }),
        "cat form -> execute refused")
    assert_false(dispel.execute({ in_combat = true, me = mock_me, settings = {}, stance = 1 }),
        "bear form -> execute refused")
    assert_false(dispel_did_run(), "the shared dispel strategy must not run in a feral form")

    -- TBC allows Remove Curse in Moonkin Form and poison removal in Tree of
    -- Life, so those forms must NOT be gated (this is the regression pinned).
    local moonkin, moonkin_ran = load_middleware({ has_form = function(n) return n == "moonkin" end })
    assert_true(moonkin("PartyDispel").execute({ in_combat = true, me = mock_me, settings = {} }),
        "moonkin -> shared dispel runs (Remove Curse is legal in Moonkin Form)")
    assert_true(moonkin_ran(), "moonkin control actually dispatched")
    local tree, tree_ran = load_middleware({ has_form = function(n) return n == "tree" end })
    assert_true(tree("PartyDispel").execute({ in_combat = true, me = mock_me, settings = {} }),
        "tree -> shared dispel runs (poison removal is legal in Tree of Life)")
    assert_true(tree_ran(), "tree control actually dispatched")

    assert_true(dispel.execute({ in_combat = true, me = mock_me, settings = {}, stance = 0 }),
        "unshifted -> the shared strategy runs")
    assert_true(dispel_did_run(), "unshifted control actually dispatched")
end)

test("middleware ThreatDrop/Cower: blocked in a positive non-feral form, fail-open when unknown", function()
    local find = load_middleware({ GetPartyMembers = function() return { {} } end })
    local threat = find("ThreatDrop")
    assert_true(threat.matches({ in_combat = true, me = mock_me, settings = {}, stance = 3 }),
        "cat/bear grouped -> Cower allowed")
    assert_false(threat.matches({ in_combat = true, me = mock_me, settings = {}, stance = 5 }),
        "moonkin -> Cower refused")
    assert_true(threat.matches({ in_combat = true, me = mock_me, settings = {} }),
        "unknown form -> fail OPEN (previous behavior kept)")
end)

-- ============================================================================
-- PHASE C: OOC manager druid form gate (hoisted over every OOC path)
-- ============================================================================

local function load_ooc(class_id, now)
    local casts = {}
    local ns = {
        CLASS_ID = { DRUID = 11, WARRIOR = 1, MAGE = 8, PRIEST = 5, SHAMAN = 7, WARLOCK = 9, PALADIN = 2, HUNTER = 3 },
        player_class_id = class_id,
        time_now = function() return now() end,
        GetPlayer = function() return { get_level = function() return 70 end } end,
        spell_action = function(spell, label) return { id = spell, name = label } end,
        spell_ready = function() return true end,
        try_cast = function(spell, target, reason, opts)
            casts[#casts + 1] = { spell = spell, reason = reason }
            return true
        end,
        buff_remains = function() return 0 end,
        has_player_buff = function() return false end,
        mana_pct = function() return 100 end,
        gcd_remains = function() return 0 end,
        POWER_RAGE = 1,
        power_current = function() return 100 end,  -- warrior rage floor for the control
        get_setting = function(_, default) return default end,
        log = function() end,
    }
    _G.EaxRotations = ns
    reset_shared_modules()
    local module = dofile("EaxRotations/shared/ooc_manager_sylvanas.lua")
    return module, casts
end

test("ooc_manager: a shifted druid runs no OOC work at all", function()
    local clock = 100
    local ooc, casts = load_ooc(11, function() return clock end)
    local me = { get_level = function() return 70 end }

    -- Control: unshifted -> OOC maintenance fires.
    local caster_ctx = { me = me, in_combat = false, settings = { use_ooc_manager = true }, stance = 0 }
    assert_true(ooc.on_update(caster_ctx), "caster form -> OOC maintenance fires")
    assert_true(#casts > 0, "caster form -> a cast actually happened")

    -- The regression: in cat form per the bar index nothing fires (before the fix
    -- try_buff_upgrades and food/flask were reachable here even though
    -- try_self_buffs held).
    local before = #casts
    clock = clock + 5
    assert_false(ooc.on_update({ me = me, in_combat = false, settings = { use_ooc_manager = true }, stance = 3 }),
        "cat form -> OOC manager holds")
    clock = clock + 5
    assert_false(ooc.on_update({ me = me, in_combat = false, settings = { use_ooc_manager = true }, stance = 1 }),
        "bear form -> OOC manager holds")
    assert_eq(#casts, before, "no cast happened while shifted")

    -- Aura-only detection behaves the same way.
    _G.EaxRotations.has_form = function(name) return name == "cat" end
    clock = clock + 5
    assert_false(ooc.on_update({ me = me, in_combat = false, settings = { use_ooc_manager = true } }),
        "aura-only cat form -> OOC manager holds")
    assert_eq(#casts, before, "no cast happened with the aura source alone")
end)

test("ooc_manager: the gate is druid-only", function()
    local clock = 500
    local ooc, casts = load_ooc(1, function() return clock end)  -- warrior
    local me = { get_level = function() return 70 end }
    assert_true(ooc.on_update({ me = me, in_combat = false, settings = { use_ooc_manager = true }, stance = 3 }),
        "a warrior with the same stance reading still runs (the gate only guards druids)")
    assert_true(#casts > 0, "warrior cast happened")
end)

test("cat spec: the required_form guard reads the bar index too", function()
    local ns = {
        DruidSpells = { Shred = 5221 },
        get_player_stance = function() return 3 end,   -- shapeshift bar: cat
        has_form = function() return false end,        -- aura API lies
        debuff_remains = function() return 0 end,
        buff_up = function() return false end,
        is_spell_learned = function() return true end,
        spell_ready = function() return true end,
        action_matches = function() return true end,
        setting_number = function(t, k, d)
            return (type(t) == "table" and type(t[k]) == "number") and t[k] or d
        end,
        setting_bool = function(t, k, d)
            local v = type(t) == "table" and t[k] or nil
            if v == nil then return d end
            return v ~= false
        end,
        log = function() end,
        try_cast = function() return true end,
        rotation_registry = { register = function() end },
    }
    _G.EaxRotations = ns
    reset_shared_modules()
    local spec = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
    -- TrackHumanoids is an action-based lane (it goes through base_matches, which
    -- owns the required_form == "cat" guard). Its own match only needs an
    -- out-of-combat PvP non-player target, so the guard is the only thing that
    -- can flip the result.
    local track
    for i = 1, #spec.strategies do
        if spec.strategies[i].name == "TrackHumanoids" then track = spec.strategies[i] end
    end
    assert_true(track ~= nil, "TrackHumanoids exists")
    assert_true(track.matches({ energy = 100, me = {}, target = {}, is_pvp = true }),
        "a cat-only action is available from the bar index while the aura lies")
end)

-- ============================================================================
-- PHASE D: the feral cat spec reads the same detector
-- ============================================================================

test("cat spec: build_state sees cat form from the bar index while the aura lies", function()
    local ns = {
        DruidSpells = { Shred = 5221 },
        get_player_stance = function() return 3 end,   -- shapeshift bar: cat
        has_form = function() return false end,        -- aura API lies
        debuff_remains = function() return 0 end,
        buff_up = function() return false end,
        is_spell_learned = function() return true end,
        spell_ready = function() return true end,
        action_matches = function() return true end,
        setting_number = function(t, k, d)
            return (type(t) == "table" and type(t[k]) == "number") and t[k] or d
        end,
        setting_bool = function(t, k, d)
            local v = type(t) == "table" and t[k] or nil
            if v == nil then return d end
            return v ~= false
        end,
        log = function() end,
        try_cast = function() return true end,
        rotation_registry = { register = function() end },
    }
    _G.EaxRotations = ns
    reset_shared_modules()
    local spec = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
    local state = spec.build_state({ me = {}, target = {} })
    assert_true(state.is_cat, "bar index cat + lying aura -> is_cat (never re-shift Cat Form)")

    -- Control: when both sources agree there is no form, the spec says caster,
    -- so the assertion above is not passing on a detector that always says cat.
    ns.get_player_stance = function() return 0 end
    local caster = spec.build_state({ me = {}, target = {}, now = math.huge })
    assert_false(caster.is_cat, "bar index caster + aura silent -> not cat")
end)

print(string.format("\n=== Druid stay-in-cat-form regression suite: %d passed, %d failed ===\n", passed, failed))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All druid form-hold tests passed!")
end
