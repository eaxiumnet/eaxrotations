-- test_druid_form_stay_cat.lua -- TBC druid: never leave Cat Form to run a lane.
-- WHAT:  pins the shared shapeshift detector (the aura names the form; the
--        stance number only proves that some form is active), the druid
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
--        Follow-up live report (same day): after that fix the cat rotation
--        went SILENT. The detector named the form from the engine stance
--        number first, and on that client a cat druid reports the class-global
--        form id (1), not the bar index (3), so cat was read as bear and every
--        required_form == "cat" lane held. PHASE A pins the corrected order.
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

-- The aura NAMES the form; the stance number only proves that SOME form is
-- active. Live proof (2026-09-13): a TBC cat druid reports the class-global
-- form id (1), not the bar index (3), so naming from the number read cat as
-- bear and held every required_form == "cat" lane.
test("detector: the aura names the form, the stance number only says shifted", function()
    -- LIVE SHAPE (the regression this pins).
    local live = load_detector({ has_form = function(name) return name == "cat" end })
    assert_eq(live.current({ stance = 1 }), "cat", "aura cat wins over the live stance number")
    assert_true(live.is_cat({ stance = 1 }), "is_cat from the aura even when 1 looks like bear")
    assert_true(live.is_feral({ stance = 1 }), "aura cat is feral")
    assert_true(live.is_shifted({ stance = 1 }), "aura cat is shifted")

    -- No aura API at all: the number proves a form, never names one.
    local stance_only = load_detector({})
    for _, n in ipairs({ 1, 2, 3, 4, 5, 6, 7 }) do
        assert_eq(stance_only.current({ stance = n }), "form", "stance " .. n .. " is an unnamed form")
        assert_true(stance_only.is_shifted({ stance = n }), "stance " .. n .. " is shifted")
        assert_false(stance_only.is_cat({ stance = n }), "stance " .. n .. " must never be named cat")
        assert_false(stance_only.is_feral({ stance = n }), "an unnamed form is not feral (fail open)")
    end
    assert_eq(stance_only.current({ stance = 0 }), nil, "0 = caster")
    assert_false(stance_only.is_shifted({ stance = 0 }), "stance 0 is not shifted")
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
    -- Documented boundary: core's FORMS table has no travel/aquatic entry, so
    -- the aura cannot name Travel Form. With no stance reading either it is
    -- indistinguishable from caster here; when the stance number reports a
    -- form it comes back as the generic "form" (shifted), which is the safe
    -- answer for the caster-only gates. Pinned deliberately.
    local travel = load_detector({ has_form = function(name) return name == "travel" end })
    assert_eq(travel.current({}), nil, "travel: no aura entry, no stance -> caster")
    assert_eq(travel.current({ stance = 3 }), "form", "travel + a stance reading -> shifted, unnamed")
end)

test("detector: the stance producer answers the shifted question, never the form name", function()
    local form = load_detector({ get_player_stance = function() return 3 end })
    assert_eq(form.current({}), "form", "producer read: a form, unnamed")
    assert_true(form.is_shifted({}), "producer read: shifted")
    assert_false(form.is_cat({}), "the producer number must never name the form")
    assert_eq(form.current({ stance = 0 }), nil, "context stance 0 is caster")
    assert_eq(form.current({ stance = 3 }), "form", "context stance 3 is an unnamed form")
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

test("middleware MarkOfTheWild: blocked whenever any form is proven (aura silent)", function()
    local find = load_middleware({ has_form = function() return false end })
    local motw = find("MarkOfTheWild")

    -- Control: unshifted -> the lane still fires (this keeps the gate non-vacuous).
    assert_true(motw.matches({ in_combat = false, me = mock_me, settings = {}, stance = 0 }),
        "caster form -> MotW fires")

    -- MotW is caster-only in EVERY form, so the generic "some form" answer from
    -- the stance number is enough to hold the lane -- no form name required.
    for _, n in ipairs({ 1, 2, 3, 4, 5 }) do
        assert_false(motw.matches({ in_combat = false, me = mock_me, settings = {}, stance = n }),
            "stance " .. n .. " (some form) -> MotW holds")
    end
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

test("middleware Thorns: same gate, aura and stance alike", function()
    local find = load_middleware({})
    local thorns = find("Thorns")
    assert_true(thorns.matches({ in_combat = false, me = mock_me, settings = {}, stance = 0 }),
        "caster form -> Thorns fires")
    assert_false(thorns.matches({ in_combat = false, me = mock_me, settings = {}, stance = 3 }),
        "some form (stance 3) -> Thorns holds")
    assert_false(thorns.matches({ in_combat = false, me = mock_me, settings = {}, stance = 1 }),
        "some form (stance 1) -> Thorns holds")
    local cat = load_middleware({ has_form = function(n) return n == "cat" end })
    assert_false(cat("Thorns").matches({ in_combat = false, me = mock_me, settings = {} }),
        "aura cat -> Thorns holds")
end)

test("middleware party dispel: refused in an aura-named feral form, fail-open when unnamed", function()
    local find, dispel_did_run = load_middleware({})
    local dispel = find("PartyDispel")
    assert_true(dispel.matches({ in_combat = true, me = mock_me, settings = {}, stance = 3 }),
        "matches still reports the intent in combat")

    -- Cat and Bear cannot cast Remove Curse / Abolish Poison: the client
    -- refuses, so the execute is gated. Refusing needs the form NAME, which
    -- only the aura source provides.
    local cat, cat_ran = load_middleware({ has_form = function(n) return n == "cat" end })
    assert_false(cat("PartyDispel").execute({ in_combat = true, me = mock_me, settings = {} }),
        "aura cat -> execute refused")
    assert_false(cat_ran(), "the shared dispel strategy must not run in cat form")
    local bear, bear_ran = load_middleware({ has_form = function(n) return n == "bear" end })
    assert_false(bear("PartyDispel").execute({ in_combat = true, me = mock_me, settings = {} }),
        "aura bear -> execute refused")
    assert_false(bear_ran(), "the shared dispel strategy must not run in bear form")

    -- A stance number alone can only say "some form", so the feral-only gate
    -- FAILS OPEN there: guessing feral from it is how cat was called bear.
    local unnamed, unnamed_ran = load_middleware({ has_form = function() return false end })
    assert_true(unnamed("PartyDispel").execute({ in_combat = true, me = mock_me, settings = {}, stance = 3 }),
        "unnamed form (stance only) -> fail open")
    assert_true(unnamed_ran(), "the unnamed-form control actually dispatched")

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

test("middleware ThreatDrop/Cower: refused in a named non-feral form, fail-open when unnamed", function()
    local grouped = function() return { {} } end
    local find = load_middleware({ GetPartyMembers = grouped, has_form = function(n) return n == "cat" end })
    assert_true(find("ThreatDrop").matches({ in_combat = true, me = mock_me, settings = {} }),
        "aura cat grouped -> Cower allowed")
    local bear = load_middleware({ GetPartyMembers = grouped, has_form = function(n) return n == "bear" end })
    assert_true(bear("ThreatDrop").matches({ in_combat = true, me = mock_me, settings = {} }),
        "aura bear grouped -> Cower allowed")
    local moonkin = load_middleware({ GetPartyMembers = grouped, has_form = function(n) return n == "moonkin" end })
    assert_false(moonkin("ThreatDrop").matches({ in_combat = true, me = mock_me, settings = {} }),
        "aura moonkin -> Cower refused")
    local unnamed = load_middleware({ GetPartyMembers = grouped, has_form = function() return false end })
    assert_false(unnamed("ThreatDrop").matches({ in_combat = true, me = mock_me, settings = {}, stance = 3 }),
        "unnamed form (stance only) -> refused (positive non-feral evidence)")
    local nosource = load_middleware({ GetPartyMembers = grouped })
    assert_true(nosource("ThreatDrop").matches({ in_combat = true, me = mock_me, settings = {} }),
        "no form source -> fail OPEN (previous behavior kept)")
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

    -- The regression: while shifted nothing fires (before the fix
    -- try_buff_upgrades and food/flask were reachable here even though
    -- try_self_buffs held). The stance number alone is enough for this gate:
    -- it only has to prove SOME form, never name one.
    local before = #casts
    clock = clock + 5
    assert_false(ooc.on_update({ me = me, in_combat = false, settings = { use_ooc_manager = true }, stance = 3 }),
        "cat form -> OOC manager holds")
    clock = clock + 5
    assert_false(ooc.on_update({ me = me, in_combat = false, settings = { use_ooc_manager = true }, stance = 1 }),
        "some form (stance 1) -> OOC manager holds")
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

test("cat spec: the required_form guard reads the detector's aura name", function()
    local ns = {
        DruidSpells = { Shred = 5221 },
        get_player_stance = function() return 1 end,   -- live: class-global form id (cat)
        has_form = function(name) return name == "cat" end,  -- the source that names it
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
        "a cat-only action is available from the live aura + stance number")

    -- Control: without the aura name the same lane holds, so the assertion
    -- above is not passing on a guard that always says cat.
    ns.has_form = function() return false end
    assert_false(track.matches({ energy = 100, me = {}, target = {}, is_pvp = true, stance = 1 }),
        "stance number alone -> the cat-only lane holds")
end)

-- ============================================================================
-- PHASE D: the feral cat spec reads the same detector
-- ============================================================================

test("cat spec: build_state sees the live aura, not the stance number", function()
    local ns = {
        DruidSpells = { Shred = 5221 },
        get_player_stance = function() return 1 end,   -- live: class-global form id (cat)
        has_form = function(name) return name == "cat" end,  -- the source that names it
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
    assert_true(state.is_cat, "live aura cat + stance 1 -> is_cat (never re-shift Cat Form)")

    -- Control 1: the stance number alone must not carry is_cat.
    ns.has_form = function() return false end
    local unnamed = spec.build_state({ me = {}, target = {}, now = math.huge })
    assert_false(unnamed.is_cat, "stance-only unnamed form -> not cat")

    -- Control 2: with no form at all the spec says caster.
    ns.get_player_stance = function() return 0 end
    local caster = spec.build_state({ me = {}, target = {}, now = math.huge })
    assert_false(caster.is_cat, "no form at all -> not cat")
end)

print(string.format("\n=== Druid stay-in-cat-form regression suite: %d passed, %d failed ===\n", passed, failed))
if failed > 0 then
    error(string.format("Some tests FAILED (%d failures)", failed))
else
    print("All druid form-hold tests passed!")
end
