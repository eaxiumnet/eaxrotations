-- test_mage_live_fixes.lua — Regression tests for verified live-correctness
-- fixes in the TBC mage rotations (2026-08-12 live-fix campaign).
-- WHAT:  arcane AB-stack buff read + FireBlast conserve gating + Clearcasting
--        priority + burn stack default; fire Polymorph is_moving gate +
--        spell_ready nil guards; frost Frostbite rank coverage + FrostNova
--        context/readiness gates + Winter's Chill-aware Frostbolt filler skip
--        + Polymorph is_moving gate.
-- WHEN:  standalone only — NOT registered in any runner.
-- WHY:   audit-verified live bugs; this test pins the fixed behavior.
-- SAFETY: Pure unit tests with a mocked _G.EaxRotations; no game API calls.
--        No mock-only NS members (get_spell_cd/start_attack/power_pct/
--        unit_faction/unit_max_mana) are used anywhere.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock spec_kit + shared modules (canonical pattern from test_fire_dsl_priority)
-- ============================================================================
local _setting = function(context, key, default)
    if context and context.settings and context.settings[key] ~= nil then return context.settings[key] end
    return default
end
local mock_spec_kit = {
    define_action_for_class = function(SPELLS)
        return function(field, rank_ids, label)
            if SPELLS and SPELLS[field] then return SPELLS[field] end
            return rank_ids and rank_ids[1] or field
        end
    end,
    safe_state = function(raw, schema)
        return setmetatable({}, {
            __index = function(t, k)
                if raw[k] ~= nil then return raw[k] end
                if schema and schema[k] ~= nil then return schema[k] end
                return nil
            end,
        })
    end,
    setting = _setting,
    setting_bool = function(context, key, default)
        local v = _setting(context, key, nil)
        if v == nil then return default end
        return v ~= false
    end,
    setting_number = function(context, key, default)
        local v = _setting(context, key, nil)
        if type(v) == "number" then return v end
        return default
    end,
}
package.loaded["shared/spec_kit_sylvanas"] = mock_spec_kit
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS = {} }
package.loaded["shared/hit_cap_tracker_sylvanas"] = { get_hit_cap = function() return nil end }
package.loaded["shared/tbc_data_sylvanas"] = { SPELLS = { mage = { frost_nova = { 27088, 10230, 6131, 865, 122 } } } }

-- ============================================================================
-- Mock _G.EaxRotations
-- ============================================================================
local NS = {}
_G.EaxRotations = NS
NS.MageSpells = {
    ArcaneBlast = 30451, ArcaneMissiles = 5143, FireBlast = 2136, Fireball = 133,
    Frostbolt = 116, FrostNova = 122, Polymorph = 118, Slow = 31589,
    Evocation = 12051, PresenceOfMind = 12043, ArcanePower = 12042,
    IcyVeins = 12472, ColdSnap = 11958, IceBlock = 45438, IceBarrier = 11426,
    ManaShield = 1463, Blink = 1953, WaterElemental = 31687, IceLance = 30455,
    ConeOfCold = 120, Blizzard = 10, ArcaneExplosion = 1449, FrostArmor = 168,
    MageArmor = 6117, ArcaneIntellect = 1460, FrostWard = 6143, RemoveCurse = 475,
    Scorch = 2948, ConjureManaEmerald = 759, Pyroblast = 11366, Combustion = 11129,
    Flamestrike = 2120, BlastWave = 11113, DragonsBreath = 31661,
}
NS.PLAYER_UNIT = {
    get_health = function() return 100 end,
    get_health_percentage = function() return 100 end,
    is_valid = function() return true end,
    is_dead = function() return false end,
    is_casting = function() return false end,
    is_mounted = function() return false end,
    get_guid = function() return "player" end,
    get_target = function() return nil end,
}
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.log = function() end
NS.rotation_registry = { register = function() end }
NS.POWER_MANA = 0
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.is_item_ready = function() return false end
NS.use_item_by_id = function() return false end
NS.cooldown_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.buff_up = function() return false end
-- AB stack aura (36032) is a SELF BUFF: mock the buff side (production
-- NS.buff_stacks exists in core_sylvanas.lua).
NS.buff_stacks = function(me, ids) return me and me._ab_stacks or 0 end
NS.buff_remains = function(me, ids) return me and me._ab_remains or 0 end
NS.debuff_stacks = function() return 0 end
NS.debuff_up = function(unit, ids)
    if unit and unit._debuff and type(ids) == "table" then
        for _, id in ipairs(ids) do
            if unit._debuff[id] then return true end
        end
    end
    return false
end
NS.debuff_remains = function(target, ids) return target and target._wc_remains or 0 end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name, 2)
end

-- ============================================================================
-- ARCANE
-- ============================================================================
local arcane = dofile("EaxRotations/classes/mage/arcane_sylvanas.lua")
local arc_strategies = arcane.strategies

-- (1) AB stacks must come from the SELF-BUFF side (36032), not debuff_stacks.
local ab_me = {
    _ab_stacks = 3,
    _ab_remains = 4,
    get_max_power = function() return 15000 end,
    get_power = function() return 12000 end,
}
local ab_ctx = { me = ab_me, target = {}, mana_pct = 80, hp = 100, in_combat = true, is_moving = false, ttd = 60, settings = {} }
local ab_state = arcane.build_state(ab_ctx)
assert_eq(ab_state.ab_stacks, 3, "ab_stacks must be read via buff_stacks (self buff 36032), not debuff_stacks")
assert_true(ab_state.ab_remains == 4, "ab_remains must be read via buff_remains (self buff 36032)")

local fbc = find_strategy(arc_strategies, "FrostboltConserve")
assert_true(fbc.matches(ab_ctx, ab_state),
    "FrostboltConserve must fire at 3 AB stacks with fresh buff (was silently dead: debuff read always 0)")

-- (2) FireBlast must not starve the conserve filler / Clearcasting-AM lane.
local fb = find_strategy(arc_strategies, "FireBlast")
assert_false(fb.matches({ target = {} }, { phase = "conserve", is_moving = false, ab_stacks = 3 }),
    "FireBlast must not fire as an unconditional conserve filler")
assert_true(fb.matches({ target = {} }, { phase = "burn", is_moving = false }),
    "FireBlast fires in burn phase")
assert_true(fb.matches({ target = {} }, { phase = "conserve", is_moving = true }),
    "FireBlast fires while moving (instant cast)")
assert_false(fb.matches({}, { phase = "burn", is_moving = false }),
    "FireBlast requires a target")

-- (3) Burn max-stack default unified at 4 (was 4 in AB, 3 in FireBlast).
local ab = find_strategy(arc_strategies, "ArcaneBlast")
assert_true(ab.matches({ target = {} }, { phase = "burn", is_moving = false, ab_stacks = 3, ab_remains = 2, has_clearcasting = false, mana_pct = 50 }),
    "burn max-stack default is 4: AB still fires at 3 stacks with fresh buff")
assert_false(ab.matches({ target = {} }, { phase = "burn", is_moving = false, ab_stacks = 4, ab_remains = 2, has_clearcasting = false, mana_pct = 50 }),
    "AB skips at max stacks (4) with fresh buff and no Clearcasting")

-- (6) Clearcasting must be consumed before the max-stack skip.
assert_true(ab.matches({ target = {} }, { phase = "burn", is_moving = false, ab_stacks = 4, ab_remains = 5, has_clearcasting = true, mana_pct = 50 }),
    "Clearcasting must be consumed on AB even at max stacks with fresh buff (was wasted)")

-- ============================================================================
-- FIRE
-- ============================================================================
local fire = dofile("EaxRotations/classes/mage/fire_sylvanas.lua")
local fire_strategies = fire.strategies

-- (2) Polymorph is_moving gate.
local fpoly = find_strategy(fire_strategies, "Polymorph")
assert_false(fpoly.matches({ is_pvp = true, cc_target = {}, is_moving = true }, {}),
    "fire Polymorph must not fire while moving (1.5s cast)")
assert_true(fpoly.matches({ is_pvp = true, cc_target = {}, is_moving = false }, {}),
    "fire Polymorph fires stationary in PvP")

-- (3) build_state must survive NS.spell_ready == nil (nil-guarded reads).
local saved_spell_ready = NS.spell_ready
NS.spell_ready = nil
local fok, fstate = pcall(fire.build_state, { me = NS.PLAYER_UNIT, target = {}, mana_pct = 80, hp = 100, in_combat = true, settings = {} })
NS.spell_ready = saved_spell_ready
assert_true(fok, "fire build_state must not crash without NS.spell_ready: " .. tostring(fstate))
assert_false(fok and fstate and fstate.combustion_ready,
    "combustion_ready must default to false without NS.spell_ready")

-- ============================================================================
-- FROST
-- ============================================================================
local frost = dofile("EaxRotations/classes/mage/frost_sylvanas.lua")
local fro_strategies = frost.strategies

-- (1) Frostbite rank-1 debuff (11071) must be detected as frozen.
local fb_target = { _debuff = { [11071] = true } }
local frost_ctx = { me = NS.PLAYER_UNIT, target = fb_target, in_combat = true, is_solo = true, is_moving = false, mana_pct = 80, hp = 100, settings = {} }
local frost_state = frost.build_state(frost_ctx)
assert_true(frost_state.frostbite_active,
    "Frostbite rank 1 (11071) must set frostbite_active (was: only 12494 covered)")

local ffb_lane = find_strategy(fro_strategies, "FrostbiteFrostbolt")
assert_true(ffb_lane.matches({ target = fb_target, is_moving = false }, { frostbite_active = true, frostbolt_ready = true }),
    "FrostbiteFrostbolt must fire when a rank-1 Frostbite proc is active")

-- (4) FrostNova: context gate (no raid/dungeon misuse) + readiness.
local fn = find_strategy(fro_strategies, "FrostNova")
local fn_me = { get_distance = function() return 5 end }
assert_false(fn.matches({ target = {}, me = fn_me, in_combat = true, is_group = true, settings = { mage_group_aware_utility = false } }, { frost_nova_ready = true }),
    "FrostNova must not fire in group content without group-utility consent")
assert_true(fn.matches({ target = {}, me = fn_me, in_combat = true, is_solo = true, settings = {} }, { frost_nova_ready = true }),
    "FrostNova fires in solo when ready")
assert_false(fn.matches({ target = {}, me = fn_me, in_combat = true, is_solo = true, settings = {} }, { frost_nova_ready = false }),
    "FrostNova must not fire when the spell is not ready")
-- Legacy single-arg call with no explicit in_combat / context flags (the
-- pinned unit-test shape) keeps the open behavior.
assert_true(fn.matches({ target = {}, me = fn_me }, {}),
    "FrostNova legacy single-arg call (no state) keeps the open behavior")

-- (5) Plain Frostbolt filler respects the Winter's Chill stack-aware skip.
local fro_fb = find_strategy(fro_strategies, "Frostbolt")
assert_false(fro_fb.matches({ target = { _wc_remains = 6 }, is_moving = false }, { winter_chill_stacks = 5, frostbolt_ready = true, has_clearcasting = false }),
    "plain Frostbolt filler must skip while WC is at 5 stacks with >3s remaining")
assert_true(fro_fb.matches({ target = { _wc_remains = 2 }, is_moving = false }, { winter_chill_stacks = 5, frostbolt_ready = true, has_clearcasting = false }),
    "plain Frostbolt filler fires when WC is about to expire")

-- (6) Polymorph is_moving gate.
local fro_poly = find_strategy(fro_strategies, "Polymorph")
assert_false(fro_poly.matches({ is_pvp = true, target = {}, is_moving = true }, { polymorph_ready = true }),
    "frost Polymorph must not fire while moving (1.5s cast)")
assert_true(fro_poly.matches({ is_pvp = true, target = {}, is_moving = false }, { polymorph_ready = true }),
    "frost Polymorph fires stationary in PvP")

print("PASS test_mage_live_fixes")
