-- What: The three pull-gate rows in menu_sylvanas.lua — created, rendered, and actually wired to the
--       gate. A rule with no visible control is a rule the user cannot switch off.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why:  test_pull_safety.lua drives the gate with a menu STUB, so it proves the module honours a
--       setting but not that the setting exists. menu_sylvanas.lua has shipped `eaxaq_min_hp` /
--       `eaxaq_min_mana` since it was written — created, never rendered, never read. That is the
--       exact shape this suite exists to prevent: the user asked for "an explicit way to turn the
--       whole gate off", and a checkbox nobody renders is not one. M1/M2 pin the rows and their
--       defaults, M3 pins that the render body actually draws all three, and M4 walks the real
--       menu module into the real gate (60%-mana caster allowed; untick → nothing refused, tick →
--       refused again) so a stub that agrees with itself cannot pass this.
-- Safety: pure module load with a local widget stub; no client, no network, no writes.
--         `menu_sylvanas` is cleared from package.loaded before and after, because it publishes
--         itself at _G.EaxAutoQuester.menu and other suites read that table.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- =============================================================================
-- Widget stub — mutable, records ids/ranges, and records what gets rendered
-- =============================================================================

local calls = { created = {}, rendered = {}, tree_body = nil }

-- NOTE: the menu calls these with colon syntax (`widget:render(label, tooltip)`), so the first
-- parameter of `render` is the widget itself. Getting that wrong is invisible in a stub whose only
-- job is to record — it records the widget table as the label — so both agree on the shape here.
local function make_checkbox(default, id)
    local w = { _state = default, _id = id, _kind = "checkbox" }
    function w.get_state() return w._state end
    function w.set(_, v) w._state = v end          -- colon call: self first
    function w.render(_, label, tooltip)
        calls.rendered[#calls.rendered + 1] = { label, tooltip, id }
    end
    calls.created[#calls.created + 1] = { kind = "checkbox", id = id, default = default }
    return w
end

local function make_slider(min, max, default, id)
    local w = { _value = default, _id = id, _kind = "slider", _min = min, _max = max }
    function w.get() return w._value end
    function w.set(_, v) w._value = v end          -- colon call: self first
    function w.render(_, label, tooltip)
        calls.rendered[#calls.rendered + 1] = { label, tooltip, id }
    end
    calls.created[#calls.created + 1] =
        { kind = "slider", id = id, default = default, min = min, max = max }
    return w
end

core = {
    time = function() return 1000 end,
    log = function() end,
    log_warning = function() end,
    object_manager = { get_visible_objects = function() return {} end },
    menu = {
        checkbox = make_checkbox,
        slider_int = make_slider,
        combobox = function(default, id) return make_slider(1, 4, default, id) end,
        keybind = function(key, shift, id)
            calls.created[#calls.created + 1] = { kind = "keybind", id = id }
            return { _id = id, get_toggle_state = function() return false end, render = function() end }
        end,
        button = function(id)
            calls.created[#calls.created + 1] = { kind = "button", id = id }
            return { _id = id, is_clicked = function() return false end, render = function() end }
        end,
        tree_node = function()
            return { render = function(_, label, body)
                calls.tree_label = label
                calls.tree_body = body
            end }
        end,
    },
}

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.set_warning = function() end

package.loaded["menu_sylvanas"] = nil
local menu = require("menu_sylvanas")
local pull_safety = require("shared/pull_safety")

local function find(id)
    for i = 1, #calls.created do
        if calls.created[i].id == id then return calls.created[i] end
    end
    return nil
end

-- =============================================================================
-- M1 — the three rows exist, with ids and defaults a user can act on
-- =============================================================================

do
    local gate = find("eaxaq_pull_gate")
    local hp = find("eaxaq_pull_gate_min_hp")
    local mana = find("eaxaq_pull_gate_min_mana")

    assert(gate, "M1a FAIL: eaxaq_pull_gate was never created — the gate has no switch")
    assert(gate.kind == "checkbox", "M1b FAIL: the switch must be a checkbox, got " .. tostring(gate.kind))
    assert(gate.default == true,
        "M1c FAIL: the switch must default ON (the user asked for the behaviour), got " ..
        tostring(gate.default))

    assert(hp and mana, "M1d FAIL: the two floors were never created")
    assert(hp.kind == "slider" and mana.kind == "slider",
        "M1e FAIL: the floors must be sliders")
    assert(hp.min == 0 and mana.min == 0,
        "M1f FAIL: both floors must reach 0 — 0 is how one rule is switched off without the master " ..
        "switch; got min " .. tostring(hp.min))

    -- The defaults are this feature's own, and they must not be the 80/80 the legacy rows carry:
    -- 80% of a mana bar is ordinary post-fight state, and refusing there is "retreat after most
    -- kills". N1 in test_pull_safety pins the behaviour; this pins the number.
    assert(hp.default == 50,
        "M1g FAIL: the health floor must default to 50, got " .. tostring(hp.default))
    assert(mana.default == 30,
        "M1h FAIL: the mana floor must default to 30, got " .. tostring(mana.default))
    assert(mana.default < 80 and hp.default < 80,
        "M1i FAIL: a floor of 80 refuses ordinary leveling — the legacy pair's defaults must not " ..
        "be inherited")

    -- And the module reads those widgets, not the legacy pair.
    assert(menu.get("pull_gate") == true, "M1j FAIL: menu.get must expose the switch")
    assert(menu.get("pull_gate_min_hp") == 50, "M1k FAIL: menu.get must expose the health floor")
    assert(menu.get("pull_gate_min_mana") == 30, "M1l FAIL: menu.get must expose the mana floor")
    print("  M1 PASS: switch (default on) + floors 50/30 exist as real widgets, each reaching 0")
end

-- =============================================================================
-- M2 — a missing widget falls back to the same defaults (no crash, no zero floor)
-- =============================================================================

do
    local saved = menu.pull_gate_min_mana
    menu.pull_gate_min_mana = nil
    assert(menu.get("pull_gate_min_mana", 30) == 30,
        "M2a FAIL: an unreadable row must fall back to the caller's default")
    local me = {
        get_position = function() return { x = 0, y = 0, z = 0 } end,
        get_health = function() return 1000 end, get_max_health = function() return 1000 end,
        get_power = function() return 200 end, get_max_power = function() return 1000 end,   -- 20%
        is_in_combat = function() return false end,
        get_target = function() return nil end,
    }
    local enemy = {
        is_unit = function() return true end, is_dead = function() return false end,
        can_attack = function() return true end,
        get_position = function() return { x = 10, y = 0, z = 0 } end,
        get_movement_speed = function() return 0 end, is_in_combat = function() return false end,
    }
    pull_safety.reset()
    assert(pull_safety.gate({ me = me, now = 1000, menu = menu, debug_log = function() end },
        {}, enemy) == true,
        "M2b FAIL: with the mana row missing the gate must fall back to 30 and still refuse 20% mana")
    menu.pull_gate_min_mana = saved
    print("  M2 PASS: a missing row falls back to the module default, not to zero and not to 80")
end

-- =============================================================================
-- M3 — the render body actually draws all three (the legacy pair is the counter-example)
-- =============================================================================

do
    calls.rendered = {}
    menu.render()
    assert(calls.tree_body, "M3a FAIL: menu.render() never handed a body to the tree node")
    calls.tree_body()      -- what the framework does when the node is open

    local function drawn(id)
        for i = 1, #calls.rendered do
            if calls.rendered[i][3] == id then return calls.rendered[i][1] end
        end
        return nil
    end

    local gate_label = drawn("eaxaq_pull_gate")
    local hp_label = drawn("eaxaq_pull_gate_min_hp")
    local mana_label = drawn("eaxaq_pull_gate_min_mana")
    assert(gate_label, "M3b FAIL: the switch is created but never rendered — an invisible control " ..
        "cannot be used to turn the gate off")
    assert(hp_label and mana_label, "M3c FAIL: a floor slider is created but never rendered")

    -- Non-vacuous: the same scan must be able to see a created-but-unrendered widget. The legacy
    -- pair is exactly that, and it is why nothing consulted them.
    assert(drawn("eaxaq_min_hp") == nil and drawn("eaxaq_min_mana") == nil,
        "M3d FAIL: the scan cannot tell a rendered row from an unrendered one, so M3b proves nothing")
    assert(#calls.rendered >= 3, "M3e FAIL: expected at least the three rows, got " .. #calls.rendered)
    print("  M3 PASS: all three rows render (switch: \"" .. tostring(gate_label) .. "\")")
end

-- =============================================================================
-- M4 — the real menu drives the real gate, both directions
-- =============================================================================

do
    local function player(mana_pct)
        return {
            get_position = function() return { x = 0, y = 0, z = 0 } end,
            get_health = function() return 1000 end, get_max_health = function() return 1000 end,
            get_power = function() return mana_pct * 10 end,
            get_max_power = function() return 1000 end,
            is_in_combat = function() return false end,
            get_target = function() return nil end,
        }
    end
    local enemy = {
        is_unit = function() return true end, is_dead = function() return false end,
        can_attack = function() return true end,
        get_position = function() return { x = 10, y = 0, z = 0 } end,
        get_movement_speed = function() return 0 end, is_in_combat = function() return false end,
    }
    local me = player(60)                       -- ordinary post-fight mana
    local ctx = { me = me, now = 5000, menu = menu, debug_log = function() end }

    pull_safety.reset()
    assert(pull_safety.gate(ctx, {}, enemy) == false,
        "M4a FAIL: 90%+ health at 60% mana against one idle mob must pull with the shipped defaults")
    assert(pull_safety.holding(ctx) == false, "M4b FAIL: and no hold may be armed")

    menu.pull_gate:set(false)                   -- the user unticks the switch
    pull_safety.reset()
    local dying = player(5)
    local camp = {}
    for i = 1, 4 do
        camp[i] = {
            is_unit = function() return true end, is_dead = function() return false end,
            can_attack = function() return true end,
            get_position = function() return { x = 3 + i, y = 0, z = 0 } end,
            get_movement_speed = function() return 2.5 end,
            is_in_combat = function() return false end,
        }
    end
    local ctx_off = { me = dying, now = 5100, menu = menu, debug_log = function() end }
    assert(pull_safety.enabled(ctx_off) == false, "M4c FAIL: the unticked switch must read as off")
    assert(pull_safety.gate(ctx_off, {}, camp[1]) == false,
        "M4d FAIL: unticked, nothing may be refused — not health, not mana, not the patrolling camp")
    assert(pull_safety.holding(ctx_off) == false,
        "M4e FAIL: unticked, IDLE must not be held")

    menu.pull_gate:set(true)                    -- and back on
    assert(pull_safety.gate(ctx_off, {}, camp[1]) == true,
        "M4f FAIL: ticked again, the same scene must be refused")
    print("  M4 PASS: the real menu row drives the real gate — 60% mana pulls, unticked refuses nothing")
end

package.loaded["menu_sylvanas"] = nil
_G.EaxAutoQuester.menu = nil

print("PASS test_menu_pull_gate")
os.exit(0)
