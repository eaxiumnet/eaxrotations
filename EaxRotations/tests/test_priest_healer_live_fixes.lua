-- test_priest_healer_live_fixes.lua — regression pins for the 2026-08-12
-- live-correctness fixes in priest/discipline + priest/holy.
-- WHAT:  pins fixed behaviors: dispel debuff gating + affected-unit targeting
--        (no more unconditional group/control_risk match + self-cast), honest
--        shadowfiend spell_exists, DISPEL_MAGIC_DEBUFF_IDS cleanup (1022 BoP /
--        6074 Renew removed), CONSUME_MANA_FLOOR gates on RenewLowest/BindingHeal,
--        pushback tick-cache (state.has_pushback), nil-guarded MassDispel mana
--        read, cast_best_heal_rank 4-arg contract (5th options arg dropped).
-- WHEN:  standalone — lua EaxRotations/tests/test_priest_healer_live_fixes.lua
--        (NOT registered in any runner; suite convention like test_smite_solo_matches.lua).
-- WHY:   verified live-correctness bugs; tests keep the fixes from regressing.
-- SAFETY: Pure unit tests with mocked API context; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- ============================================================================
-- Shared module mocks (pattern from test_priest_holy_shackle.lua)
-- ============================================================================
-- Standalone so the mock table's closures can reference it (Lua 5.1: a local
-- is not in scope inside its own initializer).
local function mock_setting(context, key, default)
    local s = context and context.settings
    if s and s[key] ~= nil then return s[key] end
    return default
end

local spec_kit_mock = {
    define_action_for_class = function(SPELLS)
        return function(field, rank_ids)
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
    setting = mock_setting,
    setting_bool = function(context, key, default)
        local v = mock_setting(context, key, nil)
        if v == nil then return default end
        return v ~= false
    end,
    setting_number = function(context, key, default)
        local v = mock_setting(context, key, nil)
        if type(v) == "number" then return v end
        return default
    end,
}
package.loaded["shared/spec_kit_sylvanas"] = spec_kit_mock
package.loaded["shared/preemptive_heal_sylvanas"] = {
    DEFAULT_THRESHOLD = 40,
    match = function() return false end,
    execute = function() return false end,
    get_penalty_adjusted_heal = function(id) return id, 1 end,
}
package.loaded["shared/fsr_manager_sylvanas"] = {
    is_inside_fsr = function() return false end,
    seconds_until_fsr = function() return 0 end,
    get_regen_delta = function() return 0 end,
    should_pause_for_fsr = function() return false end,
}
package.loaded["shared/profiler_helper_sylvanas"] = { start = function() end, stop = function() end }
package.loaded["shared/health_pred_helper_sylvanas"] = nil
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

local player_unit = {
    get_class = function() return "PRIEST" end,
    is_mounted = function() return false end,
    is_moving = function() return false end,
    mana_pct = function() return 100 end,
}
local tank_unit = {}
local ally_unit = {}

-- ============================================================================
-- DISCIPLINE
-- ============================================================================
local disc_has_debuff_ids = {}      -- ids NS.has_debuff reports as present
local disc_try_cast_target = nil
local disc_spell_exists_result = true

local disc_ns = {
    PriestSpells = {
        BindingHeal = 32546, DispelMagic = 988, MassDispel = 32375,
        DivineSpirit = 25312, Fade = 25429, FearWard = 6346,
        FlashHeal = 25235, GreaterHeal = 25213, HolyFire = 25384,
        InnerFire = 25431, InnerFocus = 14751, PainSuppression = 33206,
        PowerInfusion = 10060, PowerWordFortitude = 25389,
        PowerWordShield = 25218, PrayerOfFortitude = 25392,
        PrayerOfHealing = 25308, PrayerofMending = 33076,
        PsychicScream = 10890, Renew = 25222, ShadowWordPain = 25368,
        Shadowfiend = 34433, ShackleUndead = 10955, Smite = 25364,
        SymbolOfHope = 32548,
    },
    CLASS_ID = { PRIEST = 5 },
    PLAYER_UNIT = player_unit,
    GetPlayer = function() return player_unit end,
    GetEnemiesInRange = function() return {} end,
    spell_ready = function() return true end,
    spell_exists = function() return disc_spell_exists_result end,
    buff_up = function() return false end,
    has_debuff = function(unit, id) return disc_has_debuff_ids[id] == true end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    not_same_unit = function(a, b) return a ~= b end,
    same_unit = function(a, b) return a == b end,
    unit_health_pct = function() return 100 end,
    unit_mana_pct = function() return 100 end,
    healing_get_lowest_hp = function(entries) return entries and entries[1] end,
    healing_get_tank = function(entries) return entries and (entries[2] or entries[1]) end,
    healing_count_below_hp = function(entries, count, threshold)
        local n = 0
        for i = 1, count or 0 do
            if entries[i] and (entries[i].effective_hp or 100) <= threshold then n = n + 1 end
        end
        return n
    end,
    get_friendly_target_entry = function() return nil end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    try_cast = function(spell, target) disc_try_cast_target = target return true end,
    gate_overheal = function() return false end,
    StopCast = nil,
    log = function() end,
    rotation_registry = { register = function() end },
    PriestHealing = {
        scan_healing_targets = function()
            return {
                { unit = ally_unit, effective_hp = 60, is_tank = false, has_renew = false },
                { unit = tank_unit, effective_hp = 72, is_tank = true, has_renew = false },
            }, 2
        end,
        count_subgroup_below_hp = function() return 0 end,
        pws_absorb_remaining = function() return 0 end,
    },
}
_G.EaxRotations = disc_ns
local disc = dofile("EaxRotations/classes/priest/discipline_sylvanas.lua")

local function disc_strategy(name)
    for i = 1, #disc.strategies do
        if disc.strategies[i].name == name then return disc.strategies[i] end
    end
    error("discipline strategy not found: " .. name)
end

-- --- D1 (CRITICAL): dispel must gate on a real debuff and target the unit ---
local dispel = disc_strategy("DispelMagic")
disc_has_debuff_ids = {}
-- Group presence / control_risk / fear_nearby alone must NOT match (old bug:
-- matched every tick in any group and self-cast on repeat GCDs)
assert_false(dispel.matches(
    { control_risk = true, fear_nearby = true, is_group = true, me = player_unit },
    { dispel_magic_ready = true, lowest = { unit = ally_unit } }),
    "dispel must NOT match on group/control_risk alone without a debuff")
-- Tank afflicted with a harmful magic debuff (589 SW:P) -> match, execute targets tank
disc_has_debuff_ids = { [589] = true }
local dispel_ctx = { control_risk = true, me = player_unit, settings = {} }
local dispel_state = { dispel_magic_ready = true, tank = { unit = tank_unit }, lowest = { unit = ally_unit } }
assert_true(dispel.matches(dispel_ctx, dispel_state), "dispel should match when tank has a magic debuff")
disc_try_cast_target = nil
dispel.execute(dispel_ctx, dispel_state)
assert_true(disc_try_cast_target == tank_unit, "dispel execute must target the affected tank, not self")
-- Beneficial 1022 (Blessing of Protection) must no longer count as dispellable
disc_has_debuff_ids = { [1022] = true }
assert_false(dispel.matches(dispel_ctx, dispel_state), "dispel must ignore beneficial BoP 1022")
-- Self fallback still works when the player is afflicted
disc_has_debuff_ids = { [594] = true }
assert_true(dispel.matches({ me = player_unit, settings = {} }, { dispel_magic_ready = true }),
    "dispel self fallback with a real magic debuff")
disc_has_debuff_ids = {}

-- --- D2: shadowfiend_ready must respect spell_exists (no `or true` swallow) ---
local base_ctx = { in_combat = true, mana_pct = 80, hp = 80, settings = {}, me = player_unit, is_group = true }
disc_spell_exists_result = false
local st_noexist = disc.build_state(base_ctx)
assert_false(st_noexist.shadowfiend_ready, "shadowfiend_ready must be false when spell does not exist")
disc_spell_exists_result = true
local st_exists = disc.build_state(base_ctx)
assert_true(st_exists.shadowfiend_ready, "shadowfiend_ready should be true when spell exists and ready")

-- --- D4: CONSUME_MANA_FLOOR gates on RenewLowest / BindingHeal ---
local renew = disc_strategy("RenewLowest")
assert_false(renew.matches({ settings = {} },
    { lowest = { effective_hp = 60, has_renew = false }, renew_ready = true, mana_pct = 10 }),
    "RenewLowest must skip below mana floor")
assert_true(renew.matches({ settings = {} },
    { lowest = { effective_hp = 60, has_renew = false }, renew_ready = true, mana_pct = 80 }),
    "RenewLowest matches above mana floor")
local bh = disc_strategy("BindingHeal")
assert_false(bh.matches({ is_moving = false, settings = {} },
    { lowest = { effective_hp = 40 }, hp_pct = 60, binding_heal_ready = true, mana_pct = 10 }),
    "BindingHeal must skip below mana floor")
assert_true(bh.matches({ is_moving = false, settings = {} },
    { lowest = { effective_hp = 40 }, hp_pct = 60, binding_heal_ready = true, mana_pct = 80 }),
    "BindingHeal matches above mana floor")

-- --- D5: pushback tick-cache (computed once in build_state) ---
disc_ns.GetEnemiesInRange = function() return { { is_casting = function() return true end } } end
local st_pb = disc.build_state(base_ctx)
assert_true(st_pb.has_pushback == true, "build_state must tick-cache has_pushback=true with a casting enemy")
disc_ns.GetEnemiesInRange = function() return {} end
local st_nopb = disc.build_state(base_ctx)
assert_true(st_nopb.has_pushback == false, "build_state must tick-cache has_pushback=false without casting enemies")
local gh = disc_strategy("GreaterHeal")
assert_false(gh.matches({ in_combat = true, is_moving = false, settings = {}, me = player_unit },
    { lowest = { effective_hp = 70 }, greater_heal_ready = true, mana_pct = 80, has_pushback = true }),
    "GreaterHeal must skip when pushback is cached")
assert_true(gh.matches({ in_combat = true, is_moving = false, settings = {}, me = player_unit },
    { lowest = { effective_hp = 70 }, greater_heal_ready = true, mana_pct = 80, has_pushback = false }),
    "GreaterHeal matches when pushback is clear")
local preheal = disc_strategy("PreHeal")
assert_true(preheal.matches({ in_combat = true, is_moving = false, settings = {}, me = player_unit },
    { tank = { effective_hp = 72 }, greater_heal_ready = true, has_pushback = true }),
    "PreHeal requires cached pushback (incoming damage)")
assert_false(preheal.matches({ in_combat = true, is_moving = false, settings = {}, me = player_unit },
    { tank = { effective_hp = 72 }, greater_heal_ready = true, has_pushback = false }),
    "PreHeal must not fire without pushback")

-- --- D6: MassDispel nil-mana nil guard ---
local md = disc_strategy("MassDispel")
assert_true(md.matches({ in_combat = true, is_group = true, settings = {} }, { mass_dispel_ready = true }),
    "MassDispel must not crash with nil context.mana_pct")
assert_false(md.matches({ in_combat = true, is_group = true, settings = {}, mana_pct = 20 }, { mass_dispel_ready = true }),
    "MassDispel must respect the 30% mana floor")

-- ============================================================================
-- HOLY
-- ============================================================================
local cast_best_heal_argc = nil
local holy_try_cast_target = nil

local function holy_try_cast(spell, target, label)
    holy_try_cast_target = target
    return true
end

local holy_ns = {
    PriestSpells = {
        AbolishDisease = 552, BindingHeal = 32546, CircleofHealing = 34866,
        CureDisease = 528, DesperatePrayer = 25437, DispelMagic = 988,
        FearWard = 6346, Fade = 25429, FlashHeal = 25235, GreaterHeal = 25213,
        HolyFire = 25384, InnerFocus = 14751, Lightwell = 28275, MassDispel = 32375,
        PowerWordShield = 25218, PrayerofMending = 33076, PrayerOfHealing = 25308,
        Renew = 25222, ShadowWordPain = 25368, Shadowfiend = 34433, Smite = 25364,
        SymbolOfHope = 32548, ShackleUndead = 10955,
    },
    PriestHealing = {
        scan_healing_targets = function() return {}, 0 end,
        count_subgroup_below_hp = function() return 0 end,
        has_dangerous_dispel = function() return false end,
        has_disease = function() return false end,
    },
    PLAYER_UNIT = player_unit,
    CLASS_ID = { PRIEST = "PRIEST" },
    GetPlayer = function() return player_unit end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    has_buff = function() return false end,
    has_player_buff = function() return false end,
    has_player_debuff = function() return false end,
    buff_remains = function() return 0 end,
    buff_stacks = function() return 0 end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = holy_try_cast,
    -- Real signature: cast_best_heal_rank(ranks, target, context, label) — 4 args.
    cast_best_heal_rank = function(...)
        cast_best_heal_argc = select("#", ...)
        return 25213, "Greater Heal"
    end,
    import_helpers = function(...)
        local helpers = {}
        for i = 1, select("#", ...) do helpers[select(i, ...)] = function() return true end end
        helpers["try_cast"] = holy_try_cast
        helpers["health_pct"] = function() return 100 end
        helpers["player_control_locked"] = function() return false end
        return helpers["try_cast"], helpers["spell_exists"], helpers["spell_ready"],
               helpers["debuff_remains"], helpers["health_pct"],
               helpers["player_control_locked"], helpers["has_player_buff"]
    end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    ConsumableManager = { use_mana_potion = function() return true end },
    unit_health_pct = function() return 100 end,
    unit_mana_pct = function() return 100 end,
    time_now = function() return 0 end,
    game_time_ms = function() return 0 end,
    broken_api_throttled = function() return false end,
    gate_overheal = function() return false end,
    GetEnemiesInRange = function() return {} end,
    get_friendly_target_entry = function() return nil end,
    is_pvp_zone = function() return false end,
    log = function() end,
    rotation_registry = { register = function() end },
    StopCast = { update = function() end },
    core = { get_map_id = function() return 0 end },
}
_G.EaxRotations = holy_ns
package.loaded["classes/priest/healing_sylvanas"] = holy_ns.PriestHealing
local holy = dofile("EaxRotations/classes/priest/holy_sylvanas.lua")

local function holy_strategy(name)
    for i = 1, #holy.strategies do
        if holy.strategies[i].name == name then return holy.strategies[i] end
    end
    error("holy strategy not found: " .. name)
end

-- --- H5: cast_best_heal_rank 4-arg contract (5th options arg was dropped) ---
local ft = holy_strategy("FriendlyTarget")
cast_best_heal_argc = nil
holy_try_cast_target = nil
assert_true(ft.matches({ is_moving = false, player_control_locked = false, settings = {} },
    { friendly_target_ready = true, friendly_target = { unit = ally_unit, hp_pct = 60 } }),
    "holy FriendlyTarget matches below threshold")
ft.execute({ is_moving = false, player_control_locked = false, settings = {} },
    { friendly_target = { unit = ally_unit, hp_pct = 60 } })
assert_true(cast_best_heal_argc == 4, "cast_best_heal_rank must be called with 4 args, got " .. tostring(cast_best_heal_argc))
assert_true(holy_try_cast_target == ally_unit, "FriendlyTarget execute must cast at the friendly unit")

-- --- H7: pushback tick-cache gates (matches consume state.has_pushback) ---
local gh = holy_strategy("GreaterHeal")
assert_false(gh.matches({ in_combat = true, is_moving = false, player_control_locked = false, mana_pct = 100, settings = {} },
    { lowest = { unit = ally_unit, effective_hp = 70 }, lowest_hp = 70, greater_heal_ready = true, has_pushback = true }),
    "holy GreaterHeal must skip when pushback is cached")
assert_true(gh.matches({ in_combat = true, is_moving = false, player_control_locked = false, mana_pct = 100, settings = {} },
    { lowest = { unit = ally_unit, effective_hp = 70 }, lowest_hp = 70, greater_heal_ready = true, has_pushback = false }),
    "holy GreaterHeal matches when pushback is clear")
local preheal = holy_strategy("PreHeal")
assert_true(preheal.matches({ in_combat = true, is_moving = false, player_control_locked = false, settings = {} },
    { tank = { unit = tank_unit, effective_hp = 72 }, tank_hp = 72, has_pushback = true }),
    "holy PreHeal requires cached pushback")
assert_false(preheal.matches({ in_combat = true, is_moving = false, player_control_locked = false, settings = {} },
    { tank = { unit = tank_unit, effective_hp = 72 }, tank_hp = 72, has_pushback = false }),
    "holy PreHeal must not fire without pushback")

print("PASS test_priest_healer_live_fixes")
