-- test_paladin_retribution_forever.lua — Ret paladin Forever delta unit suite.
-- WHAT:  pins the Holy Strike weave (mirror selection + splice position +
--        gate discipline + the dormant no-op path) on the
--        retribution_forever splice.
-- WHEN:  run via run_rotation_tests.lua or standalone.
-- WHY:   the battery seeds ONE sentinel per name across all mirrors, so
--        mirror SELECTION (maxrank cast 10333@60 vs the rank-1 row) is
--        pinned here with a distinct per-mirror sentinel — a delta that
--        reads the wrong mirror would pass the battery and break live.
--        Twist of Light is deliberately NOT laned (no bridge row on the
--        beta client — a by-name lane could never fire live); the dormant
--        pin proves the delta degrades to a no-op rather than guessing.
-- SAFETY: mocked NS + registry capture; no filesystem writes; self-contained.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local SENT_CAST = 19060      -- maxrank mirror sentinel (Holy Strike cast row)
local SENT_RANK1 = 19160     -- rank-1 mirror sentinel (must NOT be read)

local _last_cast = nil
_ns_registrations = {}

local function fresh_ns()
    _last_cast = nil
    return {
        PaladinSpells = {},
        PLAYER_UNIT = { _mock = true },
        GetPlayer = function() return { _mock = true } end,
        is_forever = function() return true end,
        spell_action = function(ids, name) return { ids = ids, name = name } end,
        spell_ready = function() return true end,
        spell_exists = function() return true end,
        has_player_buff = function() return false end,
        has_player_debuff = function() return false end,
        buff_up = function() return false end,
        buff_remains = function() return 0 end,
        debuff_up = function() return false end,
        debuff_remains = function() return 0 end,
        unit_distance = function() return 3 end,
        try_cast = function(spell, target, reason, opts)
            _last_cast = { spell = spell, target = target, reason = reason }
            return true
        end,
        mana_pct = function() return 100 end,
        unit_mana_pct = function() return 100 end,
        unit_health_pct = function() return 100 end,
        get_any_setting = function() return false end,
        log = function() end,
        log_warning = function() end,
        rotation_registry = {
            register = function(self, name, strategies, options)
                _ns_registrations[#_ns_registrations + 1] =
                    { name = name, strategies = strategies, options = options }
            end,
        },
    }
end

_G.EaxRotations = nil
package.loaded["classes/paladin/retribution_vanilla"] = nil
package.loaded["shared/spec_kit_sylvanas"] = nil
package.loaded["shared/tbc_data_sylvanas"] = nil
package.loaded["shared/wowhead_data_bridge_spell_index_forever_sylvanas"] = nil
package.loaded["classes/paladin/retribution_forever"] = nil

-- Sentinel bridge: maxrank carries the cast sentinel; the rank-1 mirror
-- carries a DIFFERENT id so reading the wrong mirror is detectable.
package.loaded["shared/wowhead_data_bridge_spell_index_forever_sylvanas"] = {
    spell_index_by_name_forever = { ["Holy Strike"] = SENT_RANK1 },
    spell_maxrank_by_name_forever = { ["Holy Strike"] = SENT_CAST },
    spell_buff_by_name_forever = { ["Holy Strike"] = SENT_RANK1 },
}

-- Load the baseline FIRST (its registration lands in the mock registry),
-- then the delta.
_G.EaxRotations = fresh_ns()
local baseline_ok = pcall(require, "classes/paladin/retribution_vanilla")
assert_true(baseline_ok, "baseline retribution_vanilla loads under mock NS")
assert_true(#_ns_registrations >= 1, "baseline registered")

local baseline_strategies = _ns_registrations[1].strategies
local baseline_sor_index = nil
for i, s in ipairs(baseline_strategies) do
    if s.name == "Ret_SealRighteousness_Filler" then baseline_sor_index = i break end
end
assert_true(baseline_sor_index, "baseline carries Ret_SealRighteousness_Filler")

local result = dofile("EaxRotations/classes/paladin/retribution_forever.lua")
local strategies = type(result) == "table" and (result.strategies or result) or nil
assert_true(type(strategies) == "table", "delta returns a strategies table")
assert_true(#_ns_registrations >= 2, "delta re-registered the playstyle")
local re_reg = _ns_registrations[#_ns_registrations]
assert_eq(re_reg.name, "retribution", "re-registration keeps the playstyle name")

local function find(name)
    for i, s in ipairs(strategies) do
        if s.name == name then return s, i end
    end
    return nil, nil
end

-- Pin 1: the weave exists and sits immediately above the SoR filler.
local weave, weave_idx = find("Forever_RetHolyStrikeWeave")
assert_true(weave, "Forever_RetHolyStrikeWeave present")
assert_true(weave_idx == baseline_sor_index,
    "weave splices immediately above Ret_SealRighteousness_Filler (idx "
    .. tostring(weave_idx) .. " vs " .. tostring(baseline_sor_index) .. ")")

-- Pin 2: mirror selection — the cast action carries the MAXRANK sentinel.
local ctx = { in_combat = true, has_valid_enemy_target = true,
              target = { _mock = true }, me = { _mock = true }, settings = {} }
local state = { mana_pct = 100 }
assert_true(weave.matches(ctx, state), "weave fires in-band")
assert_true(weave.execute(ctx, state), "weave executes")
assert_true(_last_cast and _last_cast.spell and _last_cast.spell.ids
    and _last_cast.spell.ids[1] == SENT_CAST,
    "weave casts through the MAXRANK mirror id (" .. tostring(SENT_CAST) .. ")")

-- Pin 3: gate discipline — OOC holds; starvation holds; the setting gate works.
local ooc = { in_combat = false, has_valid_enemy_target = false,
              target = nil, me = { _mock = true }, settings = {} }
assert_false(weave.matches(ooc, state), "weave holds out of combat")
local starved = { in_combat = true, has_valid_enemy_target = true,
                  target = { _mock = true }, me = { _mock = true },
                  settings = { ret_forever_holy_strike_mana_floor = 90 } }
assert_false(weave.matches(starved, { mana_pct = 80 }),
    "weave holds below its mana floor")
local opted_out = { in_combat = true, has_valid_enemy_target = true,
                    target = { _mock = true }, me = { _mock = true },
                    settings = { ret_forever_holy_strike = false } }
assert_false(weave.matches(opted_out, state), "weave respects the setting gate")

-- Pin 4: the dormant path — a bridge that resolves nothing returns the
-- baseline list UNCHANGED (no Forever_ lanes).
package.loaded["classes/paladin/retribution_forever"] = nil
package.loaded["classes/paladin/retribution_vanilla"] = nil
package.loaded["shared/wowhead_data_bridge_spell_index_forever_sylvanas"] = {
    spell_index_by_name_forever = {},
    spell_maxrank_by_name_forever = {},
    spell_buff_by_name_forever = {},
}
_ns_registrations = {}
_G.EaxRotations = fresh_ns()
assert_true(pcall(require, "classes/paladin/retribution_vanilla"), "baseline re-load")
local dormant = dofile("EaxRotations/classes/paladin/retribution_forever.lua")
local dormant_strategies = type(dormant) == "table" and (dormant.strategies or dormant) or nil
assert_true(type(dormant_strategies) == "table", "dormant load returns a table")
assert_eq(#dormant_strategies, #baseline_strategies,
    "dormant: strategy count equals the baseline's")
for _, s in ipairs(dormant_strategies) do
    assert_false(s.name and s.name:find("^Forever_") ~= nil,
        "dormant: no Forever_ lane (" .. tostring(s.name) .. ")")
end

print("PASS test_paladin_retribution_forever (4 pins)")
return { name = "test_paladin_retribution_forever" }
