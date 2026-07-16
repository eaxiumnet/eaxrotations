-- test_snap_threat.lua — Unit tests for SnapThreat module.
-- WHAT:  Validates immediate threat opener on combat entry.
-- WHEN:  Run via run_rotation_tests.lua or standalone.
-- WHY:   Ensures snap threat only fires once per combat start and respects cooldown.

local _G = _G
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

NS.log = function(msg) end
NS.settings = {}
NS.time_now = function() return 10.0 end

-- Mock spell ready check
NS.spell_ready = function(spell, target) return true end
NS.try_cast = function(spell, target, label) return true end

-- Load module
local mod_ok, mod_err = pcall(dofile, "EaxRotations/shared/snap_threat_sylvanas.lua")
if not mod_ok then
    print("FAIL: could not load shared/snap_threat_sylvanas.lua: " .. tostring(mod_err))
    return
end

local function assert_true(v, msg)
    if not v then
        print("FAIL " .. tostring(msg))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_eq(a, b, msg)
    if a ~= b then
        print("FAIL " .. tostring(msg) .. ": " .. tostring(a) .. " ~= " .. tostring(b))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local function assert_nil(v, msg)
    if v ~= nil then
        print("FAIL " .. tostring(msg) .. ": expected nil, got " .. tostring(v))
        return false
    end
    print("PASS " .. tostring(msg))
    return true
end

local all_ok = true

-- Test 1: Module loaded
all_ok = assert_true(NS.SnapThreat ~= nil, "NS.SnapThreat is non-nil after load") and all_ok
all_ok = assert_true(type(NS.SnapThreat.check) == "function", "NS.SnapThreat.check is a function") and all_ok

-- Test 2: Snap threat fires on first combat entry
NS.SnapThreat.reset()
local me = { is_in_combat = function() return true end }
local target = {}
local spell_id = NS.SnapThreat.check(me, target, { snap_threat_enabled = true }, { spell_id = 20271 })
all_ok = assert_eq(spell_id, 20271, "Snap threat returns spell_id on first combat entry") and all_ok

-- Test 3: Snap threat does NOT fire again in same combat
spell_id = NS.SnapThreat.check(me, target, { snap_threat_enabled = true }, { spell_id = 20271 })
all_ok = assert_nil(spell_id, "Snap threat does not fire twice in same combat") and all_ok

-- Test 4: Snap threat does NOT fire when disabled
NS.SnapThreat.reset()
spell_id = NS.SnapThreat.check(me, target, { snap_threat_enabled = false }, { spell_id = 20271 })
all_ok = assert_nil(spell_id, "Snap threat disabled returns nil") and all_ok

-- Test 5: Snap threat does NOT fire when not in combat
NS.SnapThreat.reset()
local me_ooc = { is_in_combat = function() return false end }
spell_id = NS.SnapThreat.check(me_ooc, target, { snap_threat_enabled = true }, { spell_id = 20271 })
all_ok = assert_nil(spell_id, "Snap threat OOC returns nil") and all_ok

-- Test 6: Fallback spell used when primary not ready
NS.SnapThreat.reset()
NS.spell_ready = function(spell, target)
    if spell == 20271 then return false end
    if spell == 31935 then return true end
    return false
end
spell_id = NS.SnapThreat.check(me, target, { snap_threat_enabled = true }, { spell_id = 20271, fallback_id = 31935 })
all_ok = assert_eq(spell_id, 31935, "Snap threat uses fallback when primary not ready") and all_ok

-- Test 7: Druid bear opener map (Growl primary, Mangle/Maul fallback)
NS.SnapThreat.reset()
NS.spell_ready = function(spell, target) return true end
local GROWL_ID = 6795
local MANGLE_BEAR_ID = 33987
spell_id = NS.SnapThreat.check(me, target, { snap_threat_enabled = true }, {
    spell_id = GROWL_ID,
    fallback_id = MANGLE_BEAR_ID,
})
all_ok = assert_eq(spell_id, GROWL_ID, "Bear snap threat returns Growl on combat entry") and all_ok

NS.SnapThreat.reset()
NS.spell_ready = function(spell, target)
    if spell == GROWL_ID then return false end
    if spell == MANGLE_BEAR_ID then return true end
    return false
end
spell_id = NS.SnapThreat.check(me, target, { snap_threat_enabled = true }, {
    spell_id = GROWL_ID,
    fallback_id = MANGLE_BEAR_ID,
})
all_ok = assert_eq(spell_id, MANGLE_BEAR_ID, "Bear snap threat falls back to Mangle when Growl not ready") and all_ok

-- Test 8: mark_fired suppresses subsequent snap (after combat already established)
NS.SnapThreat.reset()
NS.spell_ready = function() return true end
NS.SnapThreat.check(me, target, { snap_threat_enabled = true }, { spell_id = GROWL_ID })
NS.SnapThreat.mark_fired()
spell_id = NS.SnapThreat.check(me, target, { snap_threat_enabled = true }, { spell_id = GROWL_ID })
all_ok = assert_nil(spell_id, "mark_fired suppresses snap for rest of combat") and all_ok

if all_ok then
    print("OK snap_threat")
else
    print("FAIL snap_threat")
end
