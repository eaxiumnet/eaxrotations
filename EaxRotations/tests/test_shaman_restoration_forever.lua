-- test_shaman_restoration_forever.lua — Resto shaman Forever delta unit suite.
-- WHAT:  pins the Riptide amp-setup lane (gate shape + mirror selection + the
--        maintained-hold discipline) and the Water Shield replacement lane on
--        the restoration_forever splice; proves the vanilla baseline lanes
--        survive below the deltas.
-- WHEN:  run via run_rotation_tests.lua or standalone.
-- WHY:   the battery seeds ONE sentinel per name across all mirrors, so
--        mirror SELECTION (maxrank cast vs rank-1 buff) is pinned here with
--        distinct per-mirror sentinels (19000/19100 convention) — a delta
--        that reads the wrong mirror would pass the battery and break live.
-- SAFETY: mocked NS + registry capture; no filesystem writes; self-contained.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local SENT_CAST = 19057      -- maxrank mirror sentinel (Riptide cast row)
local SENT_BUFF = 19157      -- rank-1/buff mirror sentinel (Riptide HoT/amp)
local SENT_WS = 19058        -- maxrank mirror sentinel (Water Shield cast row)

local _low_hp = 55
local _riptide_remains = 0
local _last_cast = nil
local _baseline_strategy_names = {}

_G.EaxRotations = nil
package.loaded["classes/shaman/restoration_vanilla"] = nil
package.loaded["classes/shaman/healing_sylvanas"] = nil
package.loaded["shared/spec_kit_sylvanas"] = nil
package.loaded["shared/wowhead_data_bridge_spell_index_forever_sylvanas"] = nil
package.loaded["classes/shaman/restoration_forever"] = nil

-- Capture the baseline registration while letting the delta re-register over it.
local captured = {}
_G.EaxRotations = {
    ShamanSpells = {},
    PLAYER_UNIT = { _mock = true },
    GetPlayer = function() return { _mock = true } end,
    GetTarget = function() return { is_hostile = function() return false end } end,
    is_forever = function() return true end,
    spell_action = function(ids, name) return { ids = ids, name = name } end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    has_player_buff = function() return false end,
    buff_up = function() return false end,
    buff_remains = function(unit, ids)
        -- the lane passes a single id (the rank-1 mirror resolve); answer the
        -- scenario bank
        return _riptide_remains
    end,
    buff_stacks = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    unit_mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    try_cast = function(spell, target, reason, opts)
        _last_cast = { spell = spell, target = target, reason = reason }
        return true
    end,
    healing_get_lowest_hp = function(entries, count, threshold)
        -- one entry: the lowest ally at the scenario HP
        return { unit = { _ally = true }, effective_hp = _low_hp }
    end,
    healing_get_tank = function() return nil end,
    healing_count_below_hp = function() return 2 end,
    healing_get_cleanse_target = function() return nil end,
    get_friendly_target_entry = function() return nil end,
    HealerDeficit = { gate_spell_overheal = function() return false end },
    unit_mana_pct_present = true,
    log = function() end,
    log_warning = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            captured[#captured + 1] = { name = name, strategies = strategies, options = options }
        end,
    },
}

-- The vanilla baseline requires the healing helper; the battery/test feeds a
-- module-local stub (mirrors the battery's ns.ShamanHealing shape).
package.loaded["classes/shaman/healing_sylvanas"] = {
    select_heal = function() return nil end,
    scan_healing_targets = function() return {}, 0 end,
    count_below_hp = function() return 2 end,
    get_cleanse_target = function() return nil end,
}

-- Sentinel bridge: distinct ids per mirror so mirror selection is pinned.
package.loaded["shared/wowhead_data_bridge_spell_index_forever_sylvanas"] = {
    spell_index_by_name_forever = { ["Riptide"] = SENT_BUFF },
    spell_maxrank_by_name_forever = { ["Riptide"] = SENT_CAST, ["Water Shield"] = SENT_WS },
    spell_buff_by_name_forever = { ["Riptide"] = SENT_BUFF },
}

local function ctx(o)
    local c = { in_combat = true, is_moving = false, mana_pct = 100, hp = 100,
                settings = {}, me = { _mock = true }, enemy_count = 1,
                target = nil, has_valid_enemy_target = false }
    if o then for k, v in pairs(o) do c[k] = v end end
    return c
end
local function st(o)
    local s = { lowest = { unit = { _ally = true }, effective_hp = _low_hp },
                tank = { unit = { _tank = true }, effective_hp = 90 },
                mana_pct = 100, hp_pct = 100, in_combat = true,
                has_lightning_shield = false,
                chain_heal_ready = true, healing_wave_ready = true,
                healing_way_stacks = 0, healing_way_remains = 0,
                chain_heal_target_count = 2, mana_conserve = false,
                mana_emergency = false, enemy_count = 1, target_casting = false,
                lowest_time_to_die = 999 }
    if o then for k, v in pairs(o) do s[k] = v end end
    return s
end

local result = dofile("EaxRotations/classes/shaman/restoration_forever.lua")
local strategies = result.strategies or result
local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    error("not found: " .. name, 2)
end

print("--- Resto shaman Forever delta ---")

-- C1: the delta lanes exist and the baseline survived the splice
assert_true(find("Forever_RiptideAmpSetup"), "C1: Riptide lane registered")
assert_true(find("Forever_WaterShieldDefault"), "C1: Water Shield lane registered")
assert_true(find("ChainHeal"), "C1: baseline ChainHeal survived")
assert_true(find("HealingWay"), "C1: baseline HealingWay survived")
assert_true(find("NaturesSwiftness"), "C1: baseline NaturesSwiftness survived")
print("  [ PASS ] C1: delta lanes registered over the intact baseline")

-- C2: splice geometry — Riptide sits ABOVE ChainHeal (amp before payoff),
-- Water Shield sits above the baseline LightningShield lane position.
local _, rip_idx = find("Forever_RiptideAmpSetup")
local _, ch_idx = find("ChainHeal")
local _, ws_idx = find("Forever_WaterShieldDefault")
local _, ls_idx = find("LightningShield")
assert_true(rip_idx < ch_idx, "C2: Riptide setup above ChainHeal")
assert_true(ws_idx < ls_idx, "C2: Water Shield above baseline shield lane")
print("  [ PASS ] C2: splice geometry (amp before payoff, shield replaced)")

-- C3: Riptide setup fires on a hurt lowest ally with the HoT down
_riptide_remains = 0
_low_hp = 55
local rip = find("Forever_RiptideAmpSetup")
assert_true(rip.matches(ctx(), st()), "C3: setup matches (HoT down, ally hurt)")
_last_cast = nil
assert_true(rip.execute(ctx(), st()), "C3: execute returns true")
-- try_cast receives the resolved spell ID (number), not the action object
assert_eq(_last_cast.spell, SENT_CAST, "C3: cast resolves the MAXRANK sentinel (mirror selection)")
assert_true(_last_cast.target._ally, "C3: targets the lowest ally")
print("  [ PASS ] C3: setup fires on the max-rank mirror at the lowest ally")

-- C4: maintenance hold — HoT comfortably up (> min remains) must NOT re-fire
_riptide_remains = 12
assert_false(rip.matches(ctx(), st()), "C4: holds while the amp window is live")
_riptide_remains = 2
assert_true(rip.matches(ctx(), st()), "C4: re-applies inside the refresh window (<= 3s)")
print("  [ PASS ] C4: amp-window maintenance discipline (hold > 3s, refresh <= 3s)")

-- C5: healthy ally + mana floor gates
_riptide_remains = 0
_low_hp = 95
assert_false(rip.matches(ctx(), st({ lowest = { unit = { _ally = true }, effective_hp = 95 } })),
    "C5: healthy ally (95%) -> no direct-heal waste")
_low_hp = 55
assert_false(rip.matches(ctx({ mana_pct = 10 }), st({ mana_pct = 10 })), "C5: mana floor holds")
print("  [ PASS ] C5: hp ceiling + mana floor gates")

-- C6: Water Shield replacement fires on the max-rank mirror while unshielded
local ws = find("Forever_WaterShieldDefault")
_last_cast = nil
assert_true(ws.matches(ctx(), st()), "C6: matches while shieldless in combat")
assert_true(ws.execute(ctx(), st()), "C6: execute returns true")
assert_eq(_last_cast.spell, SENT_WS, "C6: cast resolves the Water Shield max-rank sentinel")
assert_false(ws.matches(ctx(), st({ has_lightning_shield = true })), "C6: holds while a shield is up")
assert_false(ws.matches(ctx({ in_combat = false }), st({ in_combat = false })), "C6: combat-gated (baseline travel behavior untouched)")
print("  [ PASS ] C6: Water Shield default (one-shield client rule respected)")

-- C7: baseline registration was replaced (the combined list IS restoration)
assert_true(#captured >= 1, "C7: at least one registration captured")
assert_eq(captured[#captured].name, "restoration", "C7: re-registered under 'restoration'")
assert_true(#captured[#captured].strategies >= #strategies,
    "C7: the returned list IS the re-registered combined list")
print("  [ PASS ] C7: re-registration replaces the baseline playstyle")

print("PASS test_shaman_restoration_forever")
