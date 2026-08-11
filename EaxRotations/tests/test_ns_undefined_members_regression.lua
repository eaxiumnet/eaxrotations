-- test_ns_undefined_members_regression.lua — pins the 2026-08-11
-- undefined-NS-member sweep: NS.buff_stacks / unit_mana_pct /
-- is_interruptible / unit_is_boss / is_tank_unit / is_threat_safe /
-- is_valid_target were called (6+ sites each, incl. by the ENGINE at
-- main_sylvanas.lua:711/832/1013) but never assigned — every guarded caller
-- silently read nil/0 live, and unguarded callers (9 unit_mana_pct sites)
-- were a crash waiting for a context without mana_pct.
-- WHAT:  (1) NS.buff_stacks returns the stack count for a buff id set and 0
--        when absent (mirrors debuff_stacks); (2) the enhancement_wotlk
--        Maelstrom consumer reads it — LightningBolt DSL strategy FIRES at
--        >= 5 stacks and is SILENT at 0; (3) the other six definitions
--        return their documented semantics under a mock unit/context.
-- WHEN:  rotation suite execution (run_rotation_tests.lua).
-- WHY:   a future edit that drops any of these definitions re-deads the
--        engine's target_is_boss / target_casting_interruptible / party
--        tank scan and every Maelstrom/charge/stacks consumer — must fail
--        loudly instead of silently shipping nil again.
-- SAFETY: boots core_sylvanas with a local mock _G.core (runner snapshots
--         and restores _G per suite); no game data, no fs writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;.api/?.lua;.api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
end

local function assert_eq(a, b, label)
    if a ~= b then
        error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

-- ============================================================================
-- Boot the REAL core_sylvanas against a minimal _G.core stub (same shape as
-- tests/sod_runtime_fixture) so the definitions under test are the live ones.
-- ============================================================================
_G.core = {
    time = function() return 0 end,
    get_game_version = function() return "3.3.5" end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = { get_local_player = function() return nil end },
    spell_book = {
        is_spell_learned = function() return false end,
        get_global_cooldown = function() return 1.5 end,
        get_spell_cooldown = function() return 0 end,
        get_totem_info = function() return {} end,
    },
    input = { cast_target_spell = function() return false end },
}
package.loaded["core_sylvanas"] = nil
local NS = require("core_sylvanas")

-- ============================================================================
-- (1) NS.buff_stacks — mirror of debuff_stacks (per-id max over the list).
-- ============================================================================
local function stacks_unit(stacks_by_id)
    return { get_buff_stacks = function(self, id) return stacks_by_id[id] or 0 end }
end
local unit4 = stacks_unit({ [53817] = 4 })
assert_eq(NS.buff_stacks(unit4, { 53817, 53816, 53815, 53814, 53813 }), 4,
    "buff_stacks returns the stack count from get_buff_stacks")
assert_eq(NS.buff_stacks(unit4, { 99999 }), 0, "buff_stacks 0 for an absent buff")
assert_eq(NS.buff_stacks(nil, { 53817 }), 0, "buff_stacks nil unit -> 0")
local unit5 = stacks_unit({ [53816] = 5 })
assert_eq(NS.buff_stacks(unit5, { 53817, 53816 }), 5, "buff_stacks scans the id list (max wins)")

-- ============================================================================
-- (2) Consumer: enhancement_wotlk Maelstrom read fires/silent via the DSL.
-- ============================================================================
NS.ShamanSpells = {}
local me = stacks_unit({ [53817] = 0 })
NS.me = me
NS.GetPlayer = function() return me end
package.loaded["classes/shaman/enhancement_wotlk"] = nil
local enh = require("classes/shaman/enhancement_wotlk")
local ctx = { target = {}, enemy_count = 1 }

local function lightning_bolt_matches()
    for _, s in ipairs(enh.strategies) do
        if s.name == "LightningBolt" then
            return s.matches(ctx, enh.build_state(ctx)) == true
        end
    end
    error("LightningBolt strategy not found", 2)
end

assert_eq(enh.build_state(ctx).maelstrom_stacks, 0, "0 stacks read from NS.buff_stacks")
assert_eq(lightning_bolt_matches(), false, "Maelstrom LightningBolt SILENT at 0 stacks")
me.get_buff_stacks = function(self, id) return id == 53817 and 5 or 0 end
assert_eq(enh.build_state(ctx).maelstrom_stacks, 5, "5 stacks read from NS.buff_stacks")
assert_true(lightning_bolt_matches(), "Maelstrom LightningBolt FIRES at 5 stacks")

-- ============================================================================
-- (3) The other six definitions.
-- ============================================================================
-- unit_mana_pct mirrors mana_pct.
local mana_unit = { get_mana_percentage = function(self) return 42 end }
assert_eq(NS.unit_mana_pct(mana_unit), 42, "unit_mana_pct reads get_mana_percentage")
assert_eq(NS.unit_mana_pct(nil), 100, "unit_mana_pct nil unit -> 100 (mana_pct default)")

-- is_interruptible: explicit flag wins; fail-open only for active casts.
local intr_unit = { is_active_spell_interruptable = function(self) return true end }
assert_true(NS.is_interruptible(intr_unit), "is_interruptible true from the explicit flag")
local un_intr = { is_active_spell_interruptable = function(self) return false end }
assert_eq(NS.is_interruptible(un_intr), false, "is_interruptible false from the explicit flag")
local casting_only = { is_casting = function(self) return true end }
assert_true(NS.is_interruptible(casting_only), "fail-open: active cast with no flag data is interruptible")
local idle = { is_casting = function(self) return false end, is_channeling = function(self) return false end }
assert_eq(NS.is_interruptible(idle), false, "idle unit is never interruptible")
assert_eq(NS.is_interruptible(nil), false, "is_interruptible nil unit -> false")

-- unit_is_boss: classification >= 3 (dispatcher's own is_raid_boss fallback).
local boss = { get_classification = function(self) return 3 end }
assert_true(NS.unit_is_boss(boss), "unit_is_boss true at classification 3")
local elite = { get_classification = function(self) return 1 end }
assert_eq(NS.unit_is_boss(elite), false, "unit_is_boss false at classification 1")
assert_eq(NS.unit_is_boss(nil), false, "unit_is_boss nil unit -> false")

-- is_tank_unit delegates to health_pred_helper.is_tank_role (canonical tank
-- detection used by the dispatcher party scan and auto_tremor).
package.loaded["shared/health_pred_helper_sylvanas"] = {
    is_tank_role = function(self, unit) return unit and unit.is_tank == true end,
}
local tank_unit = { is_tank = true }
assert_true(NS.is_tank_unit(tank_unit), "is_tank_unit delegates to health_pred_helper")
local dps_unit = { is_tank = false }
assert_eq(NS.is_tank_unit(dps_unit), false, "is_tank_unit false for a non-tank")
assert_eq(NS.is_tank_unit(nil), false, "is_tank_unit nil unit -> false")

-- is_threat_safe: not-has-aggro; unknown threat degrades to safe.
assert_eq(NS.is_threat_safe({ has_aggro = true }), false, "threat_safe false with aggro")
assert_eq(NS.is_threat_safe({ has_aggro = false }), true, "threat_safe true without aggro")
assert_eq(NS.is_threat_safe({}), true, "threat_safe defaults to safe on unknown threat")

-- is_valid_target mirrors the t:is_valid() fallback chain.
local valid_u = { is_valid = function(self) return true end }
assert_true(NS.is_valid_target(valid_u), "is_valid_target true for a valid unit")
local dead_u = { is_valid = function(self) return false end }
assert_eq(NS.is_valid_target(dead_u), false, "is_valid_target false for an invalid unit")
assert_eq(NS.is_valid_target(nil), false, "is_valid_target nil unit -> false")

print("PASS test_ns_undefined_members_regression (7 definitions: buff_stacks + consumer, "
    .. "unit_mana_pct, is_interruptible, unit_is_boss, is_tank_unit, is_threat_safe, is_valid_target)")
