-- test_rogue_wotlk_live_fixes.lua — Rogue WotLK live-fix regression tests (wave 3.3).
-- WHAT:  Standalone match/build_state assertions for the wave-3.3 fixes across
--        rogue/assassination_wotlk, combat_wotlk, subtlety_wotlk and
--        leveling_wotlk: real cooldown reads (NS.cooldown_remains — never the
--        mock-only action:cooldown_remaining), context-first energy/combo
--        (never mock-only me:get_energy/get_combo_points), dagger + behind
--        gates (Mutilate/Backstab/Ambush), WotLK max-rank debuff ids tracked
--        literally (Rupture 48672, Deadly Poison 57970/57969), Envenom
--        DP-stack + buff management, Hunger for Blood upkeep, ToTT/Killing
--        Spree energy gates, BladeFlurry SnD alignment, plain
--        spec_kit.define_action (no TBC class-table shadowing).
-- WHEN:  Standalone only (NOT registered — wave 3.5 registers all):
--        lua EaxRotations/tests/test_rogue_wotlk_live_fixes.lua
-- WHY:   The register (audit wave 3.1) proved the battery's lenient mocks
--        (me:get_energy/get_combo_points, action:cooldown_remaining) mask
--        production never-lanes; these pins encode the real-API fixes.
-- SAFETY: Pure unit tests with mocked _G.EaxRotations + the REAL spec_kit/DSL;
--         no game data, no fs writes, no registration.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error("FAIL: " .. (label or "assert_true"), 2) end end
local function assert_false(v, label) if v then error("FAIL: " .. (label or "assert_false"), 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    error("strategy not found: " .. name, 2)
end

-- ============================================================================
-- Shared real-API mock NS. Mirrors the live engine surface the fixed files
-- must use: me:get_power(NS.POWER_ENERGY/COMBO) (not get_energy/get_combo_points),
-- NS.cooldown_remains(spell), NS.get_equipped_item_id, NS.is_behind_target.
-- The spell_action mock deliberately exposes NO cooldown_remaining method —
-- any file still calling action:cooldown_remaining() would read nil -> false.
-- ============================================================================
local state_bank = {
    energy = 0, combo = 0,
    on_cd = nil,            -- { [spell_id] = seconds }
    buff_map = nil,         -- { [buff_id] = seconds }
    debuff_map = nil,       -- { [debuff_id] = seconds }
    dp_stacks = 0,
    daggers = false,
    behind = true,
    me_power_energy = nil,  -- me:get_power(3) fallback value
    me_power_combo = nil,   -- me:get_power(4) fallback value
}
local spell_action_calls = {}  -- every (rank_ids, label) passed to NS.spell_action
local target_mock = {
    is_valid = function() return true end,
    is_dead = function() return false end,
    is_casting = function() return false end,
    is_channeling = function() return false end,
    get_health_percentage = function() return 100 end,
}
local me_mock = {
    -- NOTE: get_energy / get_combo_points are deliberately ABSENT (mock-only
    -- unit methods in the battery; production game objects do not expose them).
    get_power = function(self, p)
        if p == 3 then return state_bank.me_power_energy or 0 end
        if p == 4 then return state_bank.me_power_combo or 0 end
        return 0
    end,
    get_health_percentage = function() return 100 end,
}

local function make_ns()
    spell_action_calls = {}
    local ns = {
        RogueSpells = {
            -- TBC-era entries: define_action_for_class would shadow the
            -- file-local WotLK rank lists with these. The fixed files use
            -- plain define_action, so NS.spell_action still receives the
            -- WotLK rank lists (see the define-path assertion below).
            SliceAndDice = 6774, SinisterStrike = 26862, Eviscerate = 26865,
            BladeFlurry = 13877, KillingSpree = 51690, Rupture = 26867,
            HungerForBlood = 51662, Mutilate = 34413, Envenom = 32684,
            TricksOfTheTrade = 57934, Premeditation = 14183, ShadowDance = 51713,
            Ambush = 27441, Backstab = 26863, Gouge = 11286, Kick = 38768,
            Stealth = 1787, FanOfKnives = 51723,
        },
        POWER_ENERGY = 3,
        POWER_COMBO = 4,
        PLAYER_UNIT = "player",
        me = me_mock,
        GetPlayer = function() return me_mock end,
        -- Real-API shape resolver: rich spell_action objects WITHOUT
        -- cooldown_remaining (production surface: id/IsReady/IsInRange/Cast).
        spell_action = function(rank_ids, label)
            local ids = type(rank_ids) == "table" and rank_ids or { rank_ids }
            spell_action_calls[#spell_action_calls + 1] = { ids = ids, label = label }
            return {
                ids = ids,
                id = function(self) return ids[1] end,
                rank = function(self, r) return ids[r or #ids] end,
                is_known = function() return true end,
            }
        end,
        cooldown_remains = function(spell)
            local id = type(spell) == "number" and spell or (type(spell) == "table" and spell.ids and spell.ids[1])
            local cd = state_bank.on_cd
            if id and cd and cd[id] then return cd[id] end
            return 0
        end,
        spell_ready = function(spell) return ns.cooldown_remains(spell) <= 0 end,
        try_cast = function() return true end,
        should_use_long_cd = function() return true end,
        buff_up = function(unit, ids)
            local map = state_bank.buff_map
            if type(map) == "table" then
                for _, id in ipairs(ids) do
                    if map[id] ~= nil then return true end
                end
            end
            return false
        end,
        buff_remains = function(unit, ids)
            local map = state_bank.buff_map
            if type(map) == "table" then
                for _, id in ipairs(ids) do
                    if map[id] ~= nil then return map[id] end
                end
            end
            return 0
        end,
        debuff_remains = function(unit, ids)
            local map = state_bank.debuff_map
            if type(map) == "table" then
                for _, id in ipairs(ids) do
                    if map[id] ~= nil then return map[id] end
                end
            end
            return 0
        end,
        get_debuff_stacks = function(unit, ids)
            if state_bank.dp_stacks <= 0 then return 0 end
            local map = state_bank.debuff_map
            if type(map) == "table" then
                for _, id in ipairs(ids) do
                    if map[id] ~= nil then return state_bank.dp_stacks end
                end
            end
            return 0
        end,
        get_equipped_item_id = function(slot)
            if state_bank.daggers then return 776 end  -- Frostmane dagger
            return 0
        end,
        EQUIPMENT_SLOTS = { MAIN_HAND = 16, OFF_HAND = 17 },
        is_behind_target = function() return state_bank.behind end,
        _EAX_MOCK = true,  -- shared write-back modules must not bind into the mock
        log = function() end,
        log_warning = function() end,
        rotation_registry = { register = function() end },
    }
    return ns
end

local function reset_bank()
    state_bank.energy = 0
    state_bank.combo = 0
    state_bank.on_cd = nil
    state_bank.buff_map = nil
    state_bank.debuff_map = nil
    state_bank.dp_stacks = 0
    state_bank.daggers = false
    state_bank.behind = true
    state_bank.me_power_energy = nil
    state_bank.me_power_combo = nil
end

local function ctx_with(overrides)
    local ctx = {
        in_combat = true,
        target = target_mock,
        me = me_mock,
        settings = {},
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

-- ============================================================================
-- 1. combat_wotlk
-- ============================================================================
reset_bank()
_G.EaxRotations = make_ns()
local combat = dofile("EaxRotations/classes/rogue/combat_wotlk.lua")
assert_true(type(combat) == "table" and #combat.strategies > 0, "combat_wotlk loads")

-- Systemic 4: plain define_action — NS.spell_action receives the WotLK rank
-- lists (heads 48638/48668), NOT the TBC-era RogueSpells entries (26862/26865).
local saw_ss_wotlk, saw_ev_wotlk = false, false
for _, call in ipairs(spell_action_calls) do
    if call.ids[1] == 48638 then saw_ss_wotlk = true end
    if call.ids[1] == 48668 then saw_ev_wotlk = true end
end
assert_true(saw_ss_wotlk, "SinisterStrike resolves through the WotLK rank list (48638 head)")
assert_true(saw_ev_wotlk, "Eviscerate resolves through the WotLK rank list (48668 head)")

-- Systemic 1: cooldown gates read NS.cooldown_remains — the mock action objects
-- expose no cooldown_remaining(), so the state fields prove the real-API path.
local st_cd = combat.build_state(ctx_with({ energy = 60, combo_points = 3, enemy_count = 1 }))
assert_eq(st_cd.blade_flurry_ready, true, "blade_flurry_ready true when cooldown_remains 0")
assert_eq(st_cd.killing_spree_ready, true, "killing_spree_ready true when cooldown_remains 0")
state_bank.on_cd = { [13877] = 5, [51690] = 3 }
local st_cd2 = combat.build_state(ctx_with({ energy = 60, combo_points = 3 }))
assert_eq(st_cd2.blade_flurry_ready, false, "blade_flurry_ready false when 13877 on cd (real cooldown_remains)")
assert_eq(st_cd2.killing_spree_ready, false, "killing_spree_ready false when 51690 on cd (real cooldown_remains)")

-- Systemic 6: energy/combo come from context (engine fields), never from
-- me:get_energy()/get_combo_points() — the me mock lacks both methods.
reset_bank()
state_bank.me_power_energy = 42
state_bank.me_power_combo = 3
local st_e = combat.build_state(ctx_with({ energy = 77, combo_points = 4 }))
assert_eq(st_e.energy, 77, "context.energy is authoritative")
assert_eq(st_e.combo_points, 4, "context.combo_points is authoritative")
local st_e2 = combat.build_state(ctx_with({}))
assert_eq(st_e2.energy, 42, "energy falls back to me:get_power(NS.POWER_ENERGY)")
assert_eq(st_e2.combo_points, 3, "combo falls back to me:get_power(NS.POWER_COMBO)")

-- BladeFlurry aligns with SnD (APL); KillingSpree gates at energy <= 50 (APL).
local bf = find_strategy(combat.strategies, "BladeFlurry")
local ks = find_strategy(combat.strategies, "KillingSpree")
reset_bank()
state_bank.buff_map = { [6774] = 20 }
assert_true(bf.matches(ctx_with({ energy = 60, enemy_count = 3 }),
    { in_combat = true, blade_flurry_ready = true, snd_active = true, enemy_count = 3 }),
    "BladeFlurry fires with SnD up + 2+ enemies")
assert_false(bf.matches(ctx_with({ energy = 60, enemy_count = 3 }),
    { in_combat = true, blade_flurry_ready = true, snd_active = false, enemy_count = 3 }),
    "BladeFlurry blocked without Slice and Dice (APL alignment)")
assert_true(ks.matches(ctx_with({ energy = 40 }),
    { in_combat = true, killing_spree_ready = true, energy = 40 }),
    "KillingSpree fires at energy <= 50")
assert_false(ks.matches(ctx_with({ energy = 70 }),
    { in_combat = true, killing_spree_ready = true, energy = 70 }),
    "KillingSpree held above 50 energy (APL gate)")

-- ============================================================================
-- 2. assassination_wotlk
-- ============================================================================
reset_bank()
_G.EaxRotations = make_ns()
local assn = dofile("EaxRotations/classes/rogue/assassination_wotlk.lua")
assert_true(type(assn) == "table" and #assn.strategies > 0, "assassination_wotlk loads")

-- Systemic 4: Mutilate/Envenom/Rupture resolve through WotLK rank lists.
local saw_mut_wotlk, saw_env_wotlk, saw_rup_wotlk = false, false, false
for _, call in ipairs(spell_action_calls) do
    if call.ids[1] == 48666 then saw_mut_wotlk = true end
    if call.ids[1] == 57993 then saw_env_wotlk = true end
    if call.ids[1] == 48672 then saw_rup_wotlk = true end
end
assert_true(saw_mut_wotlk, "Mutilate resolves through the WotLK rank list (48666 head)")
assert_true(saw_env_wotlk, "Envenom resolves through the WotLK rank list (57993 head)")
assert_true(saw_rup_wotlk, "Rupture resolves through the WotLK rank list (48672 head)")

local mutilate = find_strategy(assn.strategies, "Mutilate")
local envenom = find_strategy(assn.strategies, "Envenom")
local hfb = find_strategy(assn.strategies, "HungerForBlood")
local tot = find_strategy(assn.strategies, "TricksOfTheTrade")

-- Critical 2: Mutilate dagger gate — blocked without daggers, fires with them.
assert_false(mutilate.matches(ctx_with({ energy = 70 }),
    { energy = 70, has_daggers = false }),
    "Mutilate blocked without daggers (no failed-cast queue)")
state_bank.daggers = true
assert_true(mutilate.matches(ctx_with({ energy = 70 }),
    { energy = 70, has_daggers = true }),
    "Mutilate fires with daggers equipped")

-- Systemic 3: WotLK max-rank debuff ids tracked literally — the mock returns
-- remains/stacks only for the exact WotLK ids the file must list.
reset_bank()
state_bank.debuff_map = { [48672] = 8 }   -- WotLK Rupture debuff id
local st_r = assn.build_state(ctx_with({ energy = 60, combo_points = 4 }))
assert_eq(st_r.rupture_remains, 8, "rupture_remains sees the WotLK max-rank id 48672 (literal matching)")
reset_bank()
state_bank.debuff_map = { [57970] = 8 }   -- WotLK Deadly Poison IX id
state_bank.dp_stacks = 5
local st_dp = assn.build_state(ctx_with({ energy = 60, combo_points = 5 }))
assert_eq(st_dp.dp_stacks, 5, "dp_stacks sees the WotLK Deadly Poison id 57970 (literal matching)")

-- Envenom: combo >= 4 + DP stacks >= 3 + (buff down or energy >= 85).
state_bank.debuff_map = { [57970] = 8 }
state_bank.dp_stacks = 5
assert_true(envenom.matches(ctx_with({ energy = 60, combo_points = 5 }),
    { combo_points = 5, dp_stacks = 5, envenom_buff_up = false, energy = 60 }),
    "Envenom fires at 5 CP / 5 DP stacks with the buff down")
assert_false(envenom.matches(ctx_with({ energy = 60, combo_points = 5 }),
    { combo_points = 5, dp_stacks = 2, envenom_buff_up = false, energy = 60 }),
    "Envenom blocked below 3 DP stacks (no weak Envenom)")
state_bank.buff_map = { [57993] = 1 }
assert_false(envenom.matches(ctx_with({ energy = 60, combo_points = 5 }),
    { combo_points = 5, dp_stacks = 5, envenom_buff_up = true, energy = 60 }),
    "Envenom held while the Envenom buff is up (APL)")
assert_true(envenom.matches(ctx_with({ energy = 90, combo_points = 5 }),
    { combo_points = 5, dp_stacks = 5, envenom_buff_up = true, energy = 90 }),
    "Envenom refreshes at energy >= 85 even with the buff up (APL)")

-- Hunger for Blood: upkeep only — buff down.
reset_bank()
assert_true(hfb.matches(ctx_with({ energy = 60 }), { hfb_up = false }),
    "HungerForBlood fires when the buff is down")
state_bank.buff_map = { [51662] = 10 }
assert_false(hfb.matches(ctx_with({ energy = 60 }), { hfb_up = true }),
    "HungerForBlood held while the buff is up (upkeep only)")

-- Tricks of the Trade: APL energy gate.
reset_bank()
assert_true(tot.matches(ctx_with({ energy = 40 }), { energy = 40 }),
    "TricksOfTheTrade fires at energy <= 50")
assert_false(tot.matches(ctx_with({ energy = 80 }), { energy = 80 }),
    "TricksOfTheTrade held above 50 energy (APL gate)")

-- ============================================================================
-- 3. subtlety_wotlk
-- ============================================================================
reset_bank()
_G.EaxRotations = make_ns()
local sub = dofile("EaxRotations/classes/rogue/subtlety_wotlk.lua")
assert_true(type(sub) == "table" and #sub.strategies > 0, "subtlety_wotlk loads")

local ambush = find_strategy(sub.strategies, "Ambush")
local backstab = find_strategy(sub.strategies, "Backstab")

-- Critical 2: Backstab dagger + behind gates; Ambush behind gate.
assert_false(backstab.matches(ctx_with({ energy = 80 }),
    { energy = 80, is_behind = true, has_daggers = false }),
    "Backstab blocked without daggers")
assert_false(backstab.matches(ctx_with({ energy = 80 }),
    { energy = 80, is_behind = false, has_daggers = true }),
    "Backstab blocked in front")
state_bank.daggers = true
assert_true(backstab.matches(ctx_with({ energy = 80 }),
    { energy = 80, is_behind = true, has_daggers = true }),
    "Backstab fires behind with daggers")
assert_false(ambush.matches(ctx_with({ energy = 80 }),
    { shadow_dance_up = true, is_behind = false, energy = 80 }),
    "Ambush blocked in front (stealth window saved)")
assert_true(ambush.matches(ctx_with({ energy = 80 }),
    { shadow_dance_up = true, is_behind = true, energy = 80 }),
    "Ambush fires behind inside the Shadow Dance window")

-- Systemic 6: energy/combo from context (no me:get_energy on the mock).
reset_bank()
local st_sub = sub.build_state(ctx_with({ energy = 55, combo_points = 2 }))
assert_eq(st_sub.energy, 55, "subtlety energy reads context.energy")
assert_eq(st_sub.combo_points, 2, "subtlety combo reads context.combo_points")

-- ============================================================================
-- 4. leveling_wotlk
-- ============================================================================
reset_bank()
_G.EaxRotations = make_ns()
local lvl = dofile("EaxRotations/classes/rogue/leveling_wotlk.lua")
assert_true(type(lvl) == "table" and #lvl.strategies > 0, "leveling_wotlk loads")

-- Systemic 6: energy/combo from context; Systemic 3: Rupture debuff table
-- carries the WotLK max-rank id 48672 (literal matching).
state_bank.debuff_map = { [48672] = 6 }
local st_lv = lvl.build_state(ctx_with({ energy = 63, combo_points = 4, target = target_mock }))
assert_eq(st_lv.energy, 63, "leveling energy reads context.energy")
assert_eq(st_lv.combo_points, 4, "leveling combo reads context.combo_points")
assert_eq(st_lv.rupture_remains, 6, "leveling rupture_remains sees the WotLK max-rank id 48672")

print("PASS test_rogue_wotlk_live_fixes")
