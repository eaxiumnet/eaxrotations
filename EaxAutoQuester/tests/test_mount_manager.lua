-- test_mount_manager.lua — Unit tests for mount_manager_sylvanas

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- ============================================================================
-- Mock helpers
-- ============================================================================

local _mounted = false
local _in_combat = false
local _mount_calls = {}
local _dismount_calls = 0

local function make_me(pos, mounted, combat)
    local me = mock.create_player({ pos = pos or { x = 0, y = 0, z = 0 } })
    me.is_mounted = function() return mounted or false end
    me.is_in_combat = function() return combat or false end
    return me
end

core.input.mount = function(idx) _mount_calls[#_mount_calls + 1] = idx end
core.input.dismount = function() _dismount_calls = _dismount_calls + 1 end
local function setup_mounts()
    core.spell_book.get_mount_count = function() return 2 end
    core.spell_book.get_mount_info = function(idx)
        if idx == 1 then return { is_usable = true, mount_name = "Horse" } end
        if idx == 2 then return { is_usable = false, mount_name = "Epic Horse" } end
        return nil
    end
end
setup_mounts()

-- ============================================================================
-- S1: try_mount — far destination, not mounted, not in combat → mounts
-- ============================================================================
package.loaded["mount_manager_sylvanas"] = nil
local mm = require("EaxAutoQuester/mount_manager_sylvanas")

mock.reset()
setup_mounts()
mm.reset()
mock.set_time(10.0)
_mount_calls = {}
_dismount_calls = 0

local me = make_me({ x = 0, y = 0, z = 0 }, false, false)
mock._player = me

local ok = mm.try_mount(me, { x = 0, y = 100, z = 0 })
assert(ok == true, "S1a FAIL: should mount")
assert(#_mount_calls == 1, "S1b FAIL: mount should be called once")
assert(_mount_calls[1] == 1, "S1c FAIL: should use first usable mount")
print("  S1 PASS: try_mount mounts when far")

-- ============================================================================
-- S2: try_mount — close destination → no mount
-- ============================================================================
mock.reset()
setup_mounts()
mm.reset()
mock.set_time(10.0)
_mount_calls = {}
local me2 = make_me({ x = 0, y = 0, z = 0 }, false, false)
mock._player = me2

ok = mm.try_mount(me2, { x = 0, y = 5, z = 0 })
assert(ok == false, "S2a FAIL: close dest should not mount")
assert(#_mount_calls == 0, "S2b FAIL: mount should not be called")
print("  S2 PASS: try_mount skips when close")

-- ============================================================================
-- S3: try_mount — in combat → no mount
-- ============================================================================
mock.reset()
setup_mounts()
mm.reset()
mock.set_time(10.0)
_mount_calls = {}
local me3 = make_me({ x = 0, y = 0, z = 0 }, false, true)
mock._player = me3

ok = mm.try_mount(me3, { x = 0, y = 100, z = 0 })
assert(ok == false, "S3a FAIL: combat should block mount")
assert(#_mount_calls == 0, "S3b FAIL")
print("  S3 PASS: try_mount blocked in combat")

-- ============================================================================
-- S4: try_dismount — close to destination → dismounts
-- ============================================================================
mock.reset()
setup_mounts()
mm.reset()
mock.set_time(10.0)
_mount_calls = {}
_dismount_calls = 0
local me4 = make_me({ x = 0, y = 0, z = 0 }, true, false)
mock._player = me4

ok = mm.try_dismount(me4, { x = 0, y = 10, z = 0 })
assert(ok == true, "S4a FAIL: should dismount when close")
assert(_dismount_calls == 1, "S4b FAIL")
print("  S4 PASS: try_dismount when close")

-- ============================================================================
-- S5: try_dismount — far from destination → no dismount
-- ============================================================================
mock.reset()
setup_mounts()
mm.reset()
mock.set_time(10.0)
_dismount_calls = 0
local me5 = make_me({ x = 0, y = 0, z = 0 }, true, false)
mock._player = me5

ok = mm.try_dismount(me5, { x = 0, y = 100, z = 0 })
assert(ok == false, "S5a FAIL: far dest should not dismount")
assert(_dismount_calls == 0, "S5b FAIL")
print("  S5 PASS: try_dismount skips when far")

-- ============================================================================
-- S6: update — mounts when far
-- ============================================================================
mock.reset()
setup_mounts()
mm.reset()
mock.set_time(10.0)
_mount_calls = {}
_dismount_calls = 0
local me6 = make_me({ x = 0, y = 0, z = 0 }, false, false)
mock._player = me6

local result = mm.update(me6, { x = 0, y = 100, z = 0 })
assert(result == "mounted", "S6 FAIL: should return 'mounted', got " .. tostring(result))
print("  S6 PASS: update mounts when far")

-- ============================================================================
-- S7: throttle — rapid calls blocked
-- ============================================================================
mock.reset()
setup_mounts()
mm.reset()
mock.set_time(10.0)
_mount_calls = {}
local me7 = make_me({ x = 0, y = 0, z = 0 }, false, false)
mock._player = me7

mm.try_mount(me7, { x = 0, y = 100, z = 0 })  -- first call succeeds
local calls_after_first = #_mount_calls
mm.try_mount(me7, { x = 0, y = 100, z = 0 })  -- second call within 3s → blocked
assert(#_mount_calls == calls_after_first, "S7 FAIL: second call should be throttled")
print("  S7 PASS: mount throttle works")

print("PASS test_mount_manager")
os.exit(0)
