-- test_hunter_wotlk_live_fixes.lua — Hunter WotLK live-fix regression coverage.
-- WHAT:  Pins the Wave 3.3 hunter WotLK gates: BestialWrath readiness via
--        NS.cooldown_remains (never action:cooldown_remaining), mana_pct via
--        NS.unit_mana_pct (never me:get_mana_percentage), Explosive Shot
--        max-rank 60051 ladder, Lock and Load proc wired through NS.buff_up
--        (56344-family) with the proc lane casting the MAX rank, and the
--        leveling WotLK rank lists not shadowed by TBC HunterSpells.
-- WHEN:  Standalone (lua EaxRotations/tests/test_hunter_wotlk_live_fixes.lua);
--        NOT registered in run_wotlk_tests.lua yet (W3.5 registers all).
-- WHY:   The W3.1 audit flagged mock-only API reads that silently never-fire
--        in production; these asserts pin the fixed contract on real API
--        shapes (NS.cooldown_remains / NS.unit_mana_pct / NS.buff_up).
-- SAFETY: Pure unit tests with mocked NS + stubbed shared modules; no live
--         game data; no filesystem writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq failed") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end

-- Faithful safe_state stub (spec_kit:217 semantics): schema-defaulted reads.
local function safe_state(raw_state, schema)
    raw_state = raw_state or {}
    return setmetatable({}, {
        __index = function(_, key)
            if raw_state[key] ~= nil then return raw_state[key] end
            local d = schema and schema[key]
            if d ~= nil then return d end
            return nil
        end,
        __newindex = function(_, key, value) raw_state[key] = value end,
        __pairs = function(_) return pairs(raw_state) end,
    })
end

-- spec_kit stub: define_action resolves the ladder HEAD (first-known-wins),
-- exactly like the real spec_kit.define_action with NS.spell_action present.
package.loaded["shared/spec_kit_sylvanas"] = {
    safe_state = safe_state,
    define_action = function(spell_field, rank_ids, label)
        if type(rank_ids) == "table" then return rank_ids[1] end
        return rank_ids
    end,
    setting = function(context, key, default)
        local s = context and context.settings
        if s and s[key] ~= nil then return s[key] end
        return default
    end,
    setting_bool = function(context, key, default) return (context and context.settings and context.settings[key]) or default end,
    setting_number = function(context, key, default)
        local v = context and context.settings and context.settings[key]
        return (type(v) == "number") and v or default
    end,
}
-- Shared modules the leveling file requires unconditionally.
package.loaded["shared/leveling_helpers_sylvanas"] = {
    should_interrupt = function() return false end,
}
package.loaded["shared/pet_manager_sylvanas"] = {
    get_pet = function() return nil end,
    pet_alive = function() return false end,
    pet_hp_pct = function() return 100 end,
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = {
    install = function() end,
}

-- Test-controlled mock state.
local mock = { mana = 100, cd = {}, buffs = {}, cast_log = nil }

local registrations = {}
local function build_ns()
    local ns = {
        HunterSpells = {
            -- TBC-era table (mirrors classes/hunter/class_sylvanas.lua tops).
            -- If a WotLK file used define_action_for_class these would shadow
            -- the file-local WotLK max-rank ladders.
            SerpentSting = 27016, SteadyShot = 34120, ArcaneShot = 27019,
            MultiShot = 27021, KillShot = 53351, BestialWrath = 19574,
            HuntersMark = 14325, AimedShot = 27065, ExplosiveShot = 53301,
            KillCommand = 34026,
        },
        PLAYER_UNIT = {},
        me = {
            get_health_percentage = function() return 100 end,
            get_mana_percentage = function() return mock.mana end,
        },
        GetPlayer = function() return nil end,
        spell_action = function(rank_ids, label)
            return (type(rank_ids) == "table") and rank_ids[1] or rank_ids
        end,
        unit_mana_pct = function(unit) return mock.mana end,
        cooldown_remains = function(spell)
            local id = type(spell) == "number" and spell
                or (type(spell) == "table" and (spell.ids and spell.ids[1] or spell[1])) or nil
            return mock.cd[id] or 0
        end,
        get_spell_cooldown = function(spell)
            local id = type(spell) == "number" and spell
                or (type(spell) == "table" and (spell.ids and spell.ids[1] or spell[1])) or nil
            return mock.cd[id] or 0
        end,
        buff_up = function(unit, ids)
            for i = 1, #ids do
                if mock.buffs[ids[i]] then return true end
            end
            return false
        end,
        buff_remains = function() return 0 end,
        debuff_up = function() return false end,
        debuff_remains = function() return 0 end,
        spell_ready = function() return true end,
        try_cast = function(spell, unit, reason, opts)
            mock.cast_log = type(spell) == "number" and spell
                or (type(spell) == "table" and (spell.ids and spell.ids[1] or spell[1])) or nil
            return true
        end,
        time_now = function() return 0 end,
        log = function() end,
        log_warning = function() end,
        rotation_registry = {
            register = function(_, name, strategies, opts)
                registrations[name] = { strategies = strategies, options = opts }
            end,
        },
    }
    _G.EaxRotations = ns
    return ns
end

local function reset_mock()
    mock.mana = 100
    mock.cd = {}
    mock.buffs = {}
    mock.cast_log = nil
end

local function find(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- beast_mastery_wotlk.lua
-- ============================================================================
local function bm_suite()
    reset_mock()
    local ns = build_ns()
    local mod = dofile("EaxRotations/classes/hunter/beast_mastery_wotlk.lua")
    assert_true(type(mod) == "table" and type(mod.strategies) == "table", "bm module shape")
    local build_state = mod.build_state
    local strategies = mod.strategies

    -- mana_pct via NS.unit_mana_pct (not me:get_mana_percentage).
    mock.mana = 42
    local ctx = { me = ns.me, in_combat = true, target = {}, enemy_count = 1 }
    local st = build_state(ctx)
    assert_eq(st.mana_pct, 42, "bm mana_pct comes from NS.unit_mana_pct")

    -- BestialWrath readiness via NS.cooldown_remains(ACTION.BestialWrath).
    mock.cd[19574] = 0
    st = build_state(ctx)
    assert_eq(st.bestial_wrath_ready, true, "bm bestial_wrath_ready true off CD")
    mock.cd[19574] = 12
    st = build_state(ctx)
    assert_eq(st.bestial_wrath_ready, false, "bm bestial_wrath_ready false on CD (NS.cooldown_remains)")

    -- Lane gating + real-API cast path.
    local bw = find(strategies, "BestialWrath")
    mock.cd[19574] = 12
    st = build_state(ctx)
    assert_false(bw.matches(ctx, st), "bm BestialWrath must not match on CD")
    mock.cd[19574] = 0
    st = build_state(ctx)
    assert_true(bw.matches(ctx, st), "bm BestialWrath matches off CD")
    bw.execute(ctx, st)
    assert_eq(mock.cast_log, 19574, "bm BestialWrath casts 19574 via NS.try_cast")
end

-- ============================================================================
-- marksmanship_wotlk.lua
-- ============================================================================
local function mm_suite()
    reset_mock()
    local ns = build_ns()
    local mod = dofile("EaxRotations/classes/hunter/marksmanship_wotlk.lua")
    assert_true(type(mod) == "table" and type(mod.strategies) == "table", "mm module shape")
    local build_state = mod.build_state
    local strategies = mod.strategies

    mock.mana = 42
    local ctx = { me = ns.me, in_combat = true, target = { get_health_percentage = function() return 15 end }, enemy_count = 1 }
    local st = build_state(ctx)
    assert_eq(st.mana_pct, 42, "mm mana_pct comes from NS.unit_mana_pct")
    assert_eq(st.target_hp, 15, "mm target_hp read")

    local ks = find(strategies, "KillShot")
    assert_true(ks.matches(ctx, st), "mm KillShot matches at target_hp 15")
    ks.execute(ctx, st)
    assert_eq(mock.cast_log, 61006, "mm KillShot casts max-rank 61006")
end

-- ============================================================================
-- survival_wotlk.lua
-- ============================================================================
local function sv_suite()
    reset_mock()
    local ns = build_ns()
    local mod = dofile("EaxRotations/classes/hunter/survival_wotlk.lua")
    assert_true(type(mod) == "table" and type(mod.strategies) == "table", "sv module shape")
    local build_state = mod.build_state
    local strategies = mod.strategies

    local ctx = { me = ns.me, in_combat = true, target = {}, enemy_count = 1 }

    -- Lock and Load proc via NS.buff_up(me, {56344,56343,56342}).
    mock.buffs = { [56344] = true }
    local st = build_state(ctx)
    assert_eq(st.lock_and_load, true, "sv lock_and_load true when 56344 buff up")
    local proc = find(strategies, "ExplosiveShotProc")
    local plain = find(strategies, "ExplosiveShot")
    assert_true(proc.matches(ctx, st), "sv ExplosiveShotProc matches in the proc window")
    assert_false(plain.matches(ctx, st), "sv plain ExplosiveShot must not match in the proc window")
    -- The proc lane casts the MAX-rank Explosive Shot (60051), not the old
    -- rank-2 downrank 60052.
    proc.execute(ctx, st)
    assert_eq(mock.cast_log, 60051, "sv ExplosiveShotProc casts max-rank 60051")

    mock.buffs = {}
    st = build_state(ctx)
    assert_eq(st.lock_and_load, false, "sv lock_and_load false without the proc")
    assert_true(plain.matches(ctx, st), "sv plain ExplosiveShot matches outside the proc window")
    assert_false(proc.matches(ctx, st), "sv ExplosiveShotProc must not match without the proc")
    plain.execute(ctx, st)
    assert_eq(mock.cast_log, 60051, "sv plain ExplosiveShot casts max-rank 60051")

    -- mana_pct via NS.unit_mana_pct.
    mock.mana = 42
    st = build_state(ctx)
    assert_eq(st.mana_pct, 42, "sv mana_pct comes from NS.unit_mana_pct")
end

-- ============================================================================
-- leveling_wotlk.lua
-- ============================================================================
local function lvl_suite()
    reset_mock()
    local ns = build_ns()
    local mod = dofile("EaxRotations/classes/hunter/leveling_wotlk.lua")
    assert_true(type(mod) == "table" and type(mod.strategies) == "table", "leveling module shape")
    local build_state = mod.build_state
    local strategies = mod.strategies

    local ctx = { me = ns.me, in_combat = true, target = {}, enemy_count = 1 }

    -- Plain define_action: the file-local WotLK ladders win over the TBC
    -- HunterSpells table (NS.HunterSpells.SerpentSting = 27016 above).
    local ss = find(strategies, "SerpentSting")
    local st = build_state(ctx)
    st.serpent_remains = 0
    st.mana_pct = 50
    assert_true(ss.matches(ctx, st), "leveling SerpentSting matches with sting expiring")
    ss.execute(ctx, st)
    assert_eq(mock.cast_log, 49001, "leveling SerpentSting casts WotLK max rank 49001 (not 27016)")

    -- SteadyShot ladder head is the WotLK max rank 49052 (was 34120).
    local steady = find(strategies, "SteadyShot")
    st = build_state(ctx)
    st.mana_pct = 50
    assert_true(steady.matches(ctx, st), "leveling SteadyShot matches with mana")
    steady.execute(ctx, st)
    assert_eq(mock.cast_log, 49052, "leveling SteadyShot casts WotLK max rank 49052 (not 34120)")

    -- BestialWrath readiness via NS.cooldown_remains.
    mock.cd[19574] = 0
    st = build_state(ctx)
    assert_eq(st.bestial_wrath_ready, true, "leveling bestial_wrath_ready true off CD")
    mock.cd[19574] = 25
    st = build_state(ctx)
    assert_eq(st.bestial_wrath_ready, false, "leveling bestial_wrath_ready false on CD")
    local bw = find(strategies, "BestialWrath")
    assert_false(bw.matches(ctx, st), "leveling BestialWrath must not match on CD")
    mock.cd[19574] = 0
    st = build_state(ctx)
    assert_true(bw.matches(ctx, st), "leveling BestialWrath matches off CD")
    bw.execute(ctx, st)
    assert_eq(mock.cast_log, 19574, "leveling BestialWrath casts 19574 via NS.try_cast")

    -- mana_pct via NS.unit_mana_pct.
    mock.mana = 42
    st = build_state(ctx)
    assert_eq(st.mana_pct, 42, "leveling mana_pct comes from NS.unit_mana_pct")
end

bm_suite()
mm_suite()
sv_suite()
lvl_suite()

print("PASS test_hunter_wotlk_live_fixes")
