-- test_rune_manager.lua — Unit tests for rune_manager_sylvanas.
-- WHAT:  Validates rune ready counts, rune-state snapshot, and runic-power queries.
-- WHEN:  run as a standalone test or via the WotLK test runner.
-- WHY:   rune_manager is a new shared dependency for Death Knight specs.
-- SAFETY: fully mocked; no real unit or spell interaction.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function assert_eq(a, b, label)
    if a ~= b then
        error((label or "assert_eq failed") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

-- ---------------------------------------------------------------------------
-- Build a fresh rune_manager with the provided rune mocks.
-- `runes` is an array of 6 tables: { type = 1-4, ready = boolean }
-- ---------------------------------------------------------------------------
local function make_manager(runes)
    runes = runes or {}

    _G.core = {
        spell_book = {
            get_rune_type = function(slot)
                local r = runes[slot]
                return r and r.type or 1
            end,
            get_rune_info = function(slot)
                local r = runes[slot]
                return { start = 0, duration = 10, ready = r and r.ready or false }
            end,
            is_rune_slot_active = function(slot)
                local r = runes[slot]
                return r and r.active or false
            end,
        },
    }

    _G.EaxRotations = {
        GetPlayer = function()
            return _G.EaxRotations._mock_player
        end,
    }

    package.loaded["shared/rune_manager_sylvanas"] = nil
    return require("shared/rune_manager_sylvanas")
end

-- ---------------------------------------------------------------------------
-- Scenario 1: All runes ready
-- ---------------------------------------------------------------------------
local function test_all_runes_ready()
    local runes = {}
    for i = 1, 6 do
        runes[i] = { type = 1, ready = true, active = true }
    end
    local rm = make_manager(runes)

    assert_eq(rm.get_blood_runes_ready(), 6, "all blood runes should be ready")
    assert_eq(rm.get_frost_runes_ready(), 0, "no frost runes expected")
    assert_eq(rm.get_unholy_runes_ready(), 0, "no unholy runes expected")
    assert_eq(rm.get_death_runes_ready(), 0, "no death runes expected")

    local state = rm.get_rune_state()
    assert_eq(state.blood, 6, "state.blood count should be 6")
    assert_eq(state.ready.blood, 6, "state.ready.blood should be 6")
end

-- ---------------------------------------------------------------------------
-- Scenario 2: All runes on cooldown
-- ---------------------------------------------------------------------------
local function test_all_runes_on_cooldown()
    local runes = {}
    for i = 1, 6 do
        runes[i] = { type = 1, ready = false, active = true }
    end
    local rm = make_manager(runes)

    assert_eq(rm.get_blood_runes_ready(), 0, "no blood runes should be ready on cooldown")

    local state = rm.get_rune_state()
    assert_eq(state.blood, 6, "state.blood count should still be 6")
    assert_eq(state.ready.blood, 0, "state.ready.blood should be 0")
end

-- ---------------------------------------------------------------------------
-- Scenario 3: Mixed rune types
-- ---------------------------------------------------------------------------
local function test_mixed_rune_types()
    local runes = {
        { type = 1, ready = true,  active = true }, -- blood ready
        { type = 1, ready = false, active = true }, -- blood on cooldown
        { type = 3, ready = true,  active = true }, -- frost ready
        { type = 3, ready = true,  active = true }, -- frost ready
        { type = 2, ready = true,  active = true }, -- unholy ready
        { type = 4, ready = false, active = true }, -- death on cooldown
    }
    local rm = make_manager(runes)

    assert_eq(rm.get_blood_runes_ready(),   1, "one blood rune ready")
    assert_eq(rm.get_frost_runes_ready(),   2, "two frost runes ready")
    assert_eq(rm.get_unholy_runes_ready(),  1, "one unholy rune ready")
    assert_eq(rm.get_death_runes_ready(),   0, "no death runes ready")

    local state = rm.get_rune_state()
    assert_eq(state.blood,   2, "state.blood count should be 2")
    assert_eq(state.frost,   2, "state.frost count should be 2")
    assert_eq(state.unholy,  1, "state.unholy count should be 1")
    assert_eq(state.death,   1, "state.death count should be 1")
    assert_eq(state.ready.blood,   1, "state.ready.blood should be 1")
    assert_eq(state.ready.frost,   2, "state.ready.frost should be 2")
    assert_eq(state.ready.unholy,  1, "state.ready.unholy should be 1")
    assert_eq(state.ready.death,   0, "state.ready.death should be 0")
end

-- ---------------------------------------------------------------------------
-- Scenario 4: Runic power thresholds
-- ---------------------------------------------------------------------------
local function test_runic_power_thresholds()
    local player = {
        _power = 50,
        _max_power = 100,
        get_power = function(self, power_type)
            if power_type == 6 then return self._power end
            return 0
        end,
        get_max_power = function(self, power_type)
            if power_type == 6 then return self._max_power end
            return 0
        end,
    }

    _G.core = { spell_book = {} }
    _G.EaxRotations = {
        GetPlayer = function() return player end,
        _mock_player = player,
    }
    package.loaded["shared/rune_manager_sylvanas"] = nil
    local rm = require("shared/rune_manager_sylvanas")

    assert_eq(rm.get_runic_power(player), 50, "runic power should read 50")
    assert_eq(rm.get_runic_power_pct(player), 50, "runic power pct should be 50%")

    player._power = 0
    assert_eq(rm.get_runic_power(player), 0, "runic power should read 0")
    assert_eq(rm.get_runic_power_pct(player), 0, "runic power pct should be 0%")

    player._power = 100
    assert_eq(rm.get_runic_power(player), 100, "runic power should read 100")
    assert_eq(rm.get_runic_power_pct(player), 100, "runic power pct should be 100%")
end

-- ---------------------------------------------------------------------------
-- Scenario 5: API-missing fallback
-- ---------------------------------------------------------------------------
local function test_api_missing_fallback()
    _G.core = { spell_book = {} }
    _G.EaxRotations = { GetPlayer = function() return {} end }
    package.loaded["shared/rune_manager_sylvanas"] = nil
    local rm = require("shared/rune_manager_sylvanas")

    assert_eq(rm.get_blood_runes_ready(),  0, "blood ready fallback should be 0")
    assert_eq(rm.get_frost_runes_ready(),  0, "frost ready fallback should be 0")
    assert_eq(rm.get_unholy_runes_ready(), 0, "unholy ready fallback should be 0")
    assert_eq(rm.get_death_runes_ready(),  0, "death ready fallback should be 0")
    assert_eq(rm.get_runic_power(),        0, "runic power fallback should be 0")
    assert_eq(rm.get_runic_power_pct(),  0, "runic power pct fallback should be 0")

    local state = rm.get_rune_state()
    assert_eq(state.blood,   0, "fallback state.blood should be 0")
    assert_eq(state.frost,   0, "fallback state.frost should be 0")
    assert_eq(state.unholy,  0, "fallback state.unholy should be 0")
    assert_eq(state.death,   0, "fallback state.death should be 0")
    assert_eq(state.ready.blood,   0, "fallback ready.blood should be 0")
    assert_eq(state.ready.frost,   0, "fallback ready.frost should be 0")
    assert_eq(state.ready.unholy,  0, "fallback ready.unholy should be 0")
    assert_eq(state.ready.death,   0, "fallback ready.death should be 0")
end

-- ---------------------------------------------------------------------------
-- Execute all scenarios
-- ---------------------------------------------------------------------------
test_all_runes_ready()
test_all_runes_on_cooldown()
test_mixed_rune_types()
test_runic_power_thresholds()
test_api_missing_fallback()

print("PASS test_rune_manager")
