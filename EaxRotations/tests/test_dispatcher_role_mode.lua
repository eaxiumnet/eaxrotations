-- test_dispatcher_role_mode.lua — Validate dispatcher role selection and mode gating.
-- WHAT:  mocks player class/role and verifies the dispatcher routes to the correct rotation module.
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   dispatcher bugs affect every spec; role mis-routing is a total rotation failure.
-- SAFETY: fully mocked; exercises dispatch table lookups only.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local casts = 0
local strategies_fired = {}

local player = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power = function() return 1000 end,
    get_class = function() return 5 end,
    get_target = function()
        return {
            is_alive = function() return true end,
            is_valid = function() return true end,
            is_enemy_with = function() return true end,
            get_health_percentage = function() return 80 end,
            get_distance = function() return 15 end,
        }
    end,
    is_in_combat = function() return true end,
    gcd_remains = function() return 0 end,
    is_moving = function() return false end,
    is_casting = function() return false end,
    is_channeling = function() return false end,
}

_G.core = {
    time = function() return 100 end,
    game_time = function() return 100000 end,
    log = function(...) end,
    log_warning = function(...) end,
    log_error = function(...) end,
    object_manager = {
        get_local_player = function() return player end,
        get_visible_objects = function() return {} end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 0, 0 end,
        get_spell_cooldown = function() return 0 end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return true end,
    },
    input = {},
}

package.loaded.core_sylvanas = nil
package.loaded.main_sylvanas = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")

NS.izi = {
    spell = function(spell_id)
        return {
            is_castable_to_unit = function(_, unit, opts)
                return true, nil
            end,
            cast_safe = function(_, unit, reason)
                casts = casts + 1
                return true
            end,
        }
    end,
}

local dispatcher = require("main_sylvanas")

local function reset()
    casts = 0
    strategies_fired = {}
end

local function track(name, category)
    return {
        name = name,
        category = category,
        matches = function() return true end,
        execute = function()
            strategies_fired[#strategies_fired + 1] = { name = name, category = category }
            return true
        end,
    }
end

NS.class_middleware = {
    priest = {
        track("DPS_Buff_Middleware", "damage"),
    },
}

NS.rotation_registry = {
    class_config = { class_key = "priest", default_playstyle = "discipline" },
    playstyles = {
        discipline = {
            track("Heal_Greater", "healing"),
        },
    },
    options = {
        discipline = { get_state = function(ctx) return ctx end },
    },
}

NS.set_setting("playstyle", "discipline")

reset()
dispatcher.on_rotation_update()

assert_true(#strategies_fired == 1, "Dispatcher: exactly ONE strategy should fire per tick (current=" .. tostring(#strategies_fired) .. ")")
assert_true(strategies_fired[1].name == "Heal_Greater", "Dispatcher: role mode must be selected FIRST; healer mode should run only healer strategies (fired=" .. tostring(strategies_fired[1].name) .. ")")
assert_true(casts <= 1, "Dispatcher: at most ONE cast should be emitted per tick (casts=" .. tostring(casts) .. ")")

NS.class_middleware = { rogue = {} }
NS.rotation_registry = {
    class_config = {
        class_key = "rogue",
        default_playstyle = "combat",
        playstyles = { { name = "sod_rogue_combat", display_name = "DPS" } },
    },
    playstyles = {
        sod_rogue_combat = { track("SoD_Combat", "sod") },
    },
    options = { sod_rogue_combat = {} },
}
NS.set_setting("playstyle", nil)
NS.set_setting("active_playstyle", nil)
NS.refresh_settings_cache()
reset()
dispatcher.on_rotation_update()
assert_true(#strategies_fired == 1 and strategies_fired[1].name == "SoD_Combat",
    "Dispatcher: invalid legacy default must fall back to the first SoD playstyle")


-- ============================================================================
-- Test 3: CastTrace — the in-game "why" trace records fired rules through the
-- REAL dispatcher (run_list) when Diagnostics -> Trace Casts is on, and records
-- nothing when it is off. Exercises a DSL-compiled strategy end to end: real
-- compile, real dispatch, live state rendered into the entry.
-- ============================================================================
local dsl_ok3, dsl3 = pcall(require, "shared/strategy_dsl_sylvanas")
assert_true(dsl_ok3 and type(dsl3.compile_strategy) == "function", "strategy_dsl available for CastTrace dispatcher test")

local arcane_strat = dsl3.compile_strategy({
    name = "ArcaneBlast",
    conditions = {
        { type = "state", field = "in_combat", op = "truthy" },
        { type = "state", field = "arcane_blast_stacks", op = ">=", value = 2 },
        { type = "state", field = "mana_pct", op = ">=", value = 40 },
    },
    action = { type = "cast", spell = 30451, target = "target" },
})

NS.try_cast = function(spell, target, label, opts)
    casts = casts + 1
    return true
end
NS.rotation_registry = {
    class_config = { class_key = "mage", default_playstyle = "arcane" },
    playstyles = { arcane = { arcane_strat } },
    options = {
        arcane = {
            get_state = function()
                return { in_combat = true, arcane_blast_stacks = 3, mana_pct = 62 }
            end,
        },
    },
}
NS.class_middleware = { mage = {} }
NS.set_setting("playstyle", "arcane")
NS.set_setting("active_playstyle", nil)
NS.refresh_settings_cache()

assert_true(NS.CastTrace ~= nil, "CastTrace module loaded with the dispatcher")

-- Trace OFF: repeated real ticks record nothing.
NS._TRACE_CASTS = nil
NS.CastTrace.clear()
reset()
for _ = 1, 3 do dispatcher.on_rotation_update() end
assert_true(NS.CastTrace.count() == 0, "dispatcher records nothing with trace off (count=" .. tostring(NS.CastTrace.count()) .. ")")

-- Trace ON: the fired rule + live state land in the ring through run_list.
NS._TRACE_CASTS = true
NS.CastTrace.clear()
reset()
local fired_arcane = dispatcher.on_rotation_update()
assert_true(fired_arcane, "arcane tick fired a cast")
assert_true(NS.CastTrace.count() >= 1, "dispatcher recorded at least one entry with trace on (count=" .. tostring(NS.CastTrace.count()) .. ")")
local tlines3 = NS.CastTrace.lines(5)
local found_trace = false
for i = 1, #tlines3 do
    local l = tlines3[i]
    if l:find("ArcaneBlast", 1, true) and l:find("arcane_blast_stacks=3", 1, true) and l:find("mana_pct=62", 1, true) then
        found_trace = true
    end
end
assert_true(found_trace, "recorded entry names the rule and its live state through the real dispatcher")
NS._TRACE_CASTS = nil

-- ============================================================================
-- Test 4: the Diagnostics UI surface end to end. Both menu hosts (imperative
-- main.lua and declarative_menu_sylvanas) drive ONE shared gate — the
-- "eax_debug_trace_casts" checkbox (retained setting key), which main.lua
-- syncs to NS._TRACE_CASTS via read_debug_flag each tick. Declarative mode
-- writes the setting into NS.settings; the imperative widget is read live.
-- This pins the whole loop a player drives: toggle on -> combat ticks record
-- -> the "Last Casts" readout renders rule + DSL-watch state -> Print writes
-- one-line entries to the log -> Clear empties -> toggle off records nothing.
-- ============================================================================

-- (a) The imperative checkbox state read (main.lua read_debug_flag semantics
--     for _declarative_menu_active == false) must drive recording.
local chk_widget = { _state = false, get_state = function(self) return self._state end }
local function read_checkbox_flag(widget)
    if not widget then return false end
    local ok, val = pcall(function() return widget:get_state() end)
    return ok and val == true
end
local function drive_imperative_toggle(on)
    chk_widget._state = on
    NS._TRACE_CASTS = read_checkbox_flag(chk_widget)
end

-- (b) Declarative-mode read (main.lua read_debug_flag for
--     _declarative_menu_active == true): NS.settings carries the retained
--     page's setting value.
local function drive_declarative_toggle(on)
    NS.settings.eax_debug_trace_casts = on and true or nil
    NS._TRACE_CASTS = (NS.settings.eax_debug_trace_casts) == true
end

-- Toggle ON through the imperative checkbox path -> real dispatch records.
drive_imperative_toggle(true)
NS.CastTrace.clear()
reset()
dispatcher.on_rotation_update()
assert_true(NS.CastTrace.count() >= 1, "imperative Trace Casts checkbox on -> dispatcher records (count=" .. tostring(NS.CastTrace.count()) .. ")")
local ui_lines = NS.CastTrace.lines(4)
assert_true(#ui_lines >= 1 and ui_lines[1]:find("ArcaneBlast", 1, true)
    and ui_lines[1]:find("arcane_blast_stacks=3", 1, true),
    "Last Casts readout renders rule + DSL-watch state (line=" .. tostring(ui_lines[1] or "?"))

-- Print Last Casts -> writes one-line explanations through the addon log.
local logged = {}
local orig_log = NS.log
NS.log = function(msg) logged[#logged + 1] = tostring(msg) end
NS.CastTrace.print_recent(8)
NS.log = orig_log
assert_true(#logged >= 1 and logged[1]:find("[CastTrace]", 1, true),
    "Print Last Casts writes one-line entries to the log (got " .. tostring(#logged) .. " lines)")

-- Clear Trace -> the readout falls back to its empty-state line.
drive_imperative_toggle(true)
NS.CastTrace.clear()
assert_true(NS.CastTrace.count() == 0 and #NS.CastTrace.lines(4) == 0,
    "Clear Trace empties the ring (readout shows the empty-state line)")

-- Declarative host drives the SAME shared gate via NS.settings: toggle ON via
-- the retained setting key records through the real dispatcher.
drive_declarative_toggle(true)
NS.CastTrace.clear()
reset()
dispatcher.on_rotation_update()
assert_true(NS.CastTrace.count() >= 1, "declarative Trace Casts setting on -> dispatcher records (count=" .. tostring(NS.CastTrace.count()) .. ")")

-- Toggle OFF (both hosts -> NS._TRACE_CASTS false): ticks record nothing.
drive_imperative_toggle(false)
drive_declarative_toggle(false)
NS.CastTrace.clear()
reset()
for _ = 1, 3 do dispatcher.on_rotation_update() end
assert_true(NS.CastTrace.count() == 0, "toggle off -> repeated real ticks record nothing (count=" .. tostring(NS.CastTrace.count()) .. ")")
NS.settings.eax_debug_trace_casts = nil
NS._TRACE_CASTS = nil

print("PASS test_dispatcher_role_mode")
