-- spec_kit_sylvanas.lua contract test.
--
-- Proves (without requiring the live engine):
--   1. safe_state returns documented defaults for nil schema fields.
--   2. safe_state reads pass-through to raw_state for non-schema fields.
--   3. safe_state writes land on raw_state (write-through).
--   4. define_action delegates to NS.spell_action when present.
--   5. define_action_for_class honors per-class SPELLS overrides.
--   6. setting reads context.settings first, then NS.get_setting, then default.
--   7. Kit initializes with NS absent (offline fallback).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path

local spec_kit = require("shared/spec_kit_sylvanas")

local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end
local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_nil(v, label) if v ~= nil then error(label or "assert_nil failed", 2) end end

-- ============================================================================
-- safe_state defaults
-- ============================================================================

-- Health -> full (100)
local s1 = spec_kit.safe_state({})
assert_eq(s1.hp, 100, "safe_state: hp defaults to 100")
assert_eq(s1.hp_pct, 100, "safe_state: hp_pct defaults to 100")
assert_eq(s1.target_hp, 100, "safe_state: target_hp defaults to 100")
assert_eq(s1.mana_pct, 100, "safe_state: mana_pct defaults to 100")

-- Resources -> empty (0)
assert_eq(s1.rage, 0, "safe_state: rage defaults to 0")
assert_eq(s1.energy, 0, "safe_state: energy defaults to 0")
assert_eq(s1.focus, 0, "safe_state: focus defaults to 0")
assert_eq(s1.combo_points, 0, "safe_state: combo_points defaults to 0")

-- Enemies -> none (0)
assert_eq(s1.enemy_count, 0, "safe_state: enemy_count defaults to 0")
assert_eq(s1.enemies, 0, "safe_state: enemies defaults to 0")

-- Movement neutral
assert_eq(s1.target_distance, 0, "safe_state: target_distance defaults to 0")
assert_eq(s1.ttd, 0, "safe_state: ttd defaults to 0")

-- ============================================================================
-- safe_state: read-through for present fields
-- ============================================================================
local s2 = spec_kit.safe_state({ rage = 45, hp = 30, custom_field = "x" })
assert_eq(s2.rage, 45, "safe_state: rage read-through")
assert_eq(s2.hp, 30, "safe_state: hp read-through")
assert_eq(s2.custom_field, "x", "safe_state: non-schema field read-through")

-- ============================================================================
-- safe_state: write-through to raw table
-- ============================================================================
local raw = {}
local proxy = spec_kit.safe_state(raw)
proxy.rage = 99
proxy.new_field = "hello"
assert_eq(raw.rage, 99, "safe_state: writes land on raw_state.rage")
assert_eq(raw.new_field, "hello", "safe_state: writes land on raw_state.new_field")

-- ============================================================================
-- safe_state: custom schema overrides defaults
-- ============================================================================
local s_custom = spec_kit.safe_state({}, { rage = 10, hp = 1 })
assert_eq(s_custom.rage, 10, "safe_state: schema override rage")
assert_eq(s_custom.hp, 1, "safe_state: schema override hp")

-- ============================================================================
-- define_action: delegates to NS.spell_action when present
-- ============================================================================
local saved_NS = _G.EaxRotations
_G.EaxRotations = {
    spell_action = function(ids, label) return "RESOLVED:" .. label end,
}
-- table rank chain -> spell_action receives it raw
local v1 = spec_kit.define_action("MortalStrike", { 30330, 25248 }, "MortalStrike")
assert_eq(v1, "RESOLVED:MortalStrike", "define_action: delegates to NS.spell_action with label")

-- restore
_G.EaxRotations = saved_NS

-- ============================================================================
-- define_action: offline fallback when NS.spell_action absent
-- ============================================================================
_G.EaxRotations = nil
local v2 = spec_kit.define_action("MortalStrike", { 30330, 25248 })
assert_eq(v2, 30330, "define_action: falls back to first rank id when no NS")
local v3 = spec_kit.define_action("VictoryRush", 34428)
assert_eq(v3, 34428, "define_action: returns single id as-is")
_G.EaxRotations = saved_NS

-- ============================================================================
-- define_action_for_class: SPELLS override wins
-- ============================================================================
local SPELLS = { MortalStrike = { 30330, 25248, custom_chain } }
local define = spec_kit.define_action_for_class(SPELLS)
local v4 = define("MortalStrike", { 99, 88 })
assert_eq(v4, SPELLS.MortalStrike, "define_action_for_class: SPELLS override wins verbatim")

-- ============================================================================
-- setting(): context.settings wins, then NS.get_setting, then default
-- ============================================================================
_G.EaxRotations = { get_setting = function(k, d) return "from_ns:" .. (k or "?") end }

-- context.settings present and has the key
local v5 = spec_kit.setting({ settings = { hp = 50 } }, "hp", 100)
assert_eq(v5, 50, "setting: context.settings wins")

-- context.settings absent -> NS.get_setting
local v6 = spec_kit.setting({}, "tough_hp", 40)
assert_eq(v6, "from_ns:tough_hp", "setting: NS.get_setting used when no context.settings")

-- context.settings nil, NS.get_setting nil -> default
_G.EaxRotations = { get_setting = nil }
local v7 = spec_kit.setting({}, "unknown_key", 7)
assert_eq(v7, 7, "setting: default used when both upstream sources unavailable")

_G.EaxRotations = saved_NS

-- ============================================================================
-- setting_number, setting_bool
-- ============================================================================
-- setting_number only returns numeric values
assert_eq(spec_kit.setting_number({ settings = { hp = 25 } }, "hp", 99), 25,
    "setting_number: number from context")
assert_eq(spec_kit.setting_number({ settings = { hp = "twenty-five" } }, "hp", 99), 99,
    "setting_number: non-numeric falls back to default")

-- setting_bool
assert_eq(spec_kit.setting_bool({ settings = { use_thing = true } }, "use_thing", false), true,
    "setting_bool: true from context")
assert_eq(spec_kit.setting_bool({ settings = { use_thing = false } }, "use_thing", true), false,
    "setting_bool: false wins even when default true")
assert_eq(spec_kit.setting_bool({ settings = {} }, "missing", true), true,
    "setting_bool: default when key missing")

-- ============================================================================
-- nil safety
-- ============================================================================
assert_eq(spec_kit.setting(nil, nil, "fallback"), "fallback", "setting: nil context, nil key returns fallback")

print("PASS test_spec_kit (safe_state defaults, fallback chain, write-through, define_action parity)")
