-- test_mount_manager.lua — Unit tests for mount_manager_sylvanas
--
-- Two families here. S* covers the raw one-shot calls (try_mount / try_dismount / the bag scan)
-- and the bag judgement order (client item info outranks the generated list). H* covers the
-- behaviour the manager exists for in play: mount BEFORE a long walk, hold the walk for the cast,
-- and dismount at the end of it. The old S6 — which asserted `update` mounts a player who is
-- already walking — is gone on purpose: a mount cast dies to movement, so an attempt on a
-- travelling tick could never complete and was the reason "auto mount" never mounted.

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- ============================================================================
-- Mock helpers
-- ============================================================================

-- Player state, mutable so a scenario can mount the player mid-flight (H2) the way the client
-- does when the cast lands, or walk the player (H9), the way a mob/knockback does.
local _st = { mounted = false, combat = false, indoors = false, dead = false, ghost = false,
    casting = false, channelling = false, speed = 0 }

local _mount_calls = {}
local _dismount_calls = 0
local _use_item_calls = {}
local _bag_scans = 0

-- Every member the manager probes is answered from _st, so a scenario can put the player in any
-- state the gate has to judge. The names are the real game_object ones (.api/game_object.lua) —
-- is_casting_spell, not the izi_sdk is_casting convenience — so a probe the runtime does not
-- actually have would fail here rather than pass silently.
local function make_me(pos)
    local me = mock.create_player({ pos = pos or { x = 0, y = 0, z = 0 } })
    me.is_mounted = function() return _st.mounted end
    me.is_in_combat = function() return _st.combat end
    me.is_indoors = function() return _st.indoors end
    me.is_dead = function() return _st.dead end
    me.is_ghost = function() return _st.ghost end
    me.is_casting_spell = function() return _st.casting end
    me.is_channelling_spell = function() return _st.channelling end
    me.get_movement_speed = function() return _st.speed end
    return me
end

local function reset_st(mounted, combat, indoors)
    _st.mounted = mounted or false
    _st.combat = combat or false
    _st.indoors = indoors or false
    _st.dead = false
    _st.ghost = false
    _st.casting = false
    _st.channelling = false
    _st.speed = 0
end

-- Stubbed here, before the require: mount_manager caches its API calls at load (Pattern 2), so an
-- override installed later in this file would never be reached.
core.input.mount = function(idx) _mount_calls[#_mount_calls + 1] = idx end
core.input.dismount = function() _dismount_calls = _dismount_calls + 1 end
core.input.use_item = function(id) _use_item_calls[#_use_item_calls + 1] = id end
-- The bag read is wrapped so a scenario can assert how OFTEN the bags are scanned: an attempt
-- that finds nothing must back off, not rescan five bags on every long walk.
local _real_get_items_in_bag = core.inventory.get_items_in_bag
core.inventory.get_items_in_bag = function(bag_id)
    _bag_scans = _bag_scans + 1
    return _real_get_items_in_bag(bag_id)
end

local mm
local function setup_mounts()
    core.spell_book.get_mount_count = function() return 2 end
    core.spell_book.get_mount_info = function(idx)
        if idx == 1 then return { is_usable = true, mount_name = "Horse" } end
        if idx == 2 then return { is_usable = false, mount_name = "Epic Horse" } end
        return nil
    end
end

local function no_learned_mounts()
    core.spell_book.get_mount_count = function() return 0 end
    core.spell_book.get_mount_info = function() return nil end
end

-- The require happens after the stubs above, because the manager caches the input and bag calls
-- it uses at load (Pattern 2). The mount LIST is read at call time instead, so setup_mounts() /
-- no_learned_mounts() can still be swapped per scenario.
package.loaded["mount_manager_sylvanas"] = nil
mm = require("mount_manager_sylvanas")

--- Fresh player + clean counters, the preamble every scenario needs.
local function fresh(mounted, combat, indoors)
    mock.reset()
    reset_st(mounted, combat, indoors)
    mm.reset()
    mock.set_time(10.0)
    _mount_calls = {}
    _dismount_calls = 0
    _use_item_calls = {}
    _bag_scans = 0
    local me = make_me({ x = 0, y = 0, z = 0 })
    mock._player = me
    return me
end

setup_mounts()

-- ============================================================================
-- S1: try_mount — far destination, not mounted, not in combat → mounts
-- ============================================================================
local me = fresh(false, false, false)

local ok = mm.try_mount(me, { x = 0, y = 100, z = 0 })
assert(ok == true, "S1a FAIL: should mount")
assert(#_mount_calls == 1, "S1b FAIL: mount should be called once")
assert(_mount_calls[1] == 1, "S1c FAIL: should use first usable mount")
print("  S1 PASS: try_mount mounts when far")

-- ============================================================================
-- S2: try_mount — close destination → no mount
-- ============================================================================
local me2 = fresh(false, false, false)
ok = mm.try_mount(me2, { x = 0, y = 5, z = 0 })
assert(ok == false, "S2a FAIL: close dest should not mount")
assert(#_mount_calls == 0, "S2b FAIL: mount should not be called")
print("  S2 PASS: try_mount skips when close")

-- ============================================================================
-- S3: try_mount — in combat → no mount
-- ============================================================================
local me3 = fresh(false, true, false)
ok = mm.try_mount(me3, { x = 0, y = 100, z = 0 })
assert(ok == false, "S3a FAIL: combat should block mount")
assert(#_mount_calls == 0, "S3b FAIL")
print("  S3 PASS: try_mount blocked in combat")

-- ============================================================================
-- S4: try_dismount — close to destination → dismounts
-- ============================================================================
local me4 = fresh(true, false, false)
ok = mm.try_dismount(me4, { x = 0, y = 10, z = 0 })
assert(ok == true, "S4a FAIL: should dismount when close")
assert(_dismount_calls == 1, "S4b FAIL")
print("  S4 PASS: try_dismount when close")

-- ============================================================================
-- S5: try_dismount — far from destination → no dismount
-- ============================================================================
local me5 = fresh(true, false, false)
ok = mm.try_dismount(me5, { x = 0, y = 100, z = 0 })
assert(ok == false, "S5a FAIL: far dest should not dismount")
assert(_dismount_calls == 0, "S5b FAIL")
print("  S5 PASS: try_dismount skips when far")

-- ============================================================================
-- S6: update — the travelling tick. It must DISMOUNT when close, and must never mount: the
-- client is walking the player, and movement cancels a mount cast. This is the regression guard
-- for the old per-tick mount attempt that never landed.
-- ============================================================================
local me6 = fresh(false, false, false)
local result = mm.update(me6, { x = 0, y = 100, z = 0 })
assert(result == nil, "S6a FAIL: a travelling tick must not report a mount, got " .. tostring(result))
assert(#_mount_calls == 0 and #_use_item_calls == 0,
    "S6b FAIL: update must not attempt a mount while the client is walking")

mock._bag_items = { [0] = { object = mock.create_object({ item_id = 1041, unit = false }) } }
mm.update(me6, { x = 0, y = 100, z = 0 })
assert(#_use_item_calls == 0, "S6c FAIL: no bag mount may be used mid-walk either")

_st.mounted = true
result = mm.update(me6, { x = 0, y = 10, z = 0 })
assert(result == "dismounted", "S6d FAIL: update should dismount when close")
assert(_dismount_calls == 1, "S6e FAIL: dismount should have been issued once")
print("  S6 PASS: update dismounts when close and never mounts mid-walk")

-- ============================================================================
-- S7: throttle — rapid calls blocked
-- ============================================================================
local me7 = fresh(false, false, false)
mm.try_mount(me7, { x = 0, y = 100, z = 0 })  -- first call succeeds
local calls_after_first = #_mount_calls
mm.try_mount(me7, { x = 0, y = 100, z = 0 })  -- second call within 3s → blocked
assert(#_mount_calls == calls_after_first, "S7 FAIL: second call should be throttled")
print("  S7 PASS: mount throttle works")

-- ============================================================================
-- Bag mounts — a mount you are CARRYING is invisible to the client's mount list,
-- so the manager has to look in the bags. Live: "it doesn't auto mount".
-- (core.input.use_item was stubbed above, before the require.)
-- ============================================================================

local REINS = 8627          -- Reins of the Night saber, in the generated TBC mount list
local HORN = 1041           -- Horn of the Black Wolf, also in the list
local NON_MOUNT_ITEM = 4540 -- Tough Hunk of Bread

--- A bag entry as the container read publishes it: { object = <game_object> }.
local function bag_item(item_id)
    local obj = mock.create_object({ name = "item_" .. tostring(item_id), unit = false, item_id = item_id })
    return { object = obj, slot_id = 1 }
end

-- S8 --- no learned mount, a mount item in the bags → use the item
local me8 = fresh(false, false, false)
no_learned_mounts()
mock._bag_items = { [0] = { bag_item(NON_MOUNT_ITEM), bag_item(REINS) } }

ok = mm.try_mount(me8, { x = 0, y = 100, z = 0 })
assert(ok == true, "S8a FAIL: a carried mount item must be used")
assert(#_use_item_calls == 1 and _use_item_calls[1] == REINS,
    "S8b FAIL: expected use_item(" .. REINS .. "), got " .. tostring(_use_item_calls[1]))
assert(#_mount_calls == 0, "S8c FAIL: the mount list is empty, so core.input.mount must not be used")
print("  S8 PASS: bag mount — use_item on the carried reins")

-- S9 --- the same bags without a mount → nothing happens
local me9 = fresh(false, false, false)
no_learned_mounts()
mock._bag_items = { [0] = { bag_item(NON_MOUNT_ITEM), bag_item(6948) } }  -- bread and a hearthstone

ok = mm.try_mount(me9, { x = 0, y = 100, z = 0 })
assert(ok == false, "S9a FAIL: bags full of junk must not be used as mounts")
assert(#_use_item_calls == 0, "S9b FAIL: no item should be used")
print("  S9 PASS: non-mount bag contents are ignored")

-- S10 --- the client's own item info decides, even for an id the table does not know
local me10 = fresh(false, false, false)
no_learned_mounts()
local UNLISTED_MOUNT = 987654
mock._bag_items = { [0] = { bag_item(UNLISTED_MOUNT) } }
mock._item_info[UNLISTED_MOUNT] = { item_type = "Miscellaneous", item_sub_type = "Mount",
    class_id = 15, subclass_id = 5 }

ok = mm.try_mount(me10, { x = 0, y = 100, z = 0 })
assert(ok == true, "S10a FAIL: a mount the client flags as a mount must be used")
assert(_use_item_calls[1] == UNLISTED_MOUNT,
    "S10b FAIL: expected use_item(" .. UNLISTED_MOUNT .. ")")
print("  S10 PASS: client item info identifies a mount the generated list does not know")

-- S11 --- and the client WINS over the generated list when it says "not a mount"
local me11 = fresh(false, false, false)
no_learned_mounts()
mock._bag_items = { [0] = { bag_item(REINS) } }
mock._item_info[REINS] = { item_type = "Junk", item_sub_type = "Junk", class_id = 15, subclass_id = 0 }

ok = mm.try_mount(me11, { x = 0, y = 100, z = 0 })
assert(ok == false and #_use_item_calls == 0,
    "S11 FAIL: the generated list must not override a client that says this item is not a mount")
print("  S11 PASS: client item info outranks the generated mount list")

-- S12 --- a learned mount wins over a carried one (the list is authoritative when it answers)
local me12 = fresh(false, false, false)
setup_mounts()
mock._bag_items = { [0] = { bag_item(REINS) } }

ok = mm.try_mount(me12, { x = 0, y = 100, z = 0 })
assert(ok == true and #_mount_calls == 1 and _mount_calls[1] == 1,
    "S12a FAIL: the client's mount list should be used first")
assert(#_use_item_calls == 0, "S12b FAIL: a carried mount must not be consumed when one is learned")
print("  S12 PASS: learned mount preferred over a carried mount")

-- S13 --- the bags are scanned beyond the backpack (bag ids 1..4 are equipped bags)
local me13 = fresh(false, false, false)
no_learned_mounts()
mock._bag_items = { [0] = { bag_item(NON_MOUNT_ITEM) }, [2] = { bag_item(HORN) } }

ok = mm.try_mount(me13, { x = 0, y = 100, z = 0 })
assert(ok == true and _use_item_calls[1] == HORN,
    "S13 FAIL: a mount in an equipped bag must be found (bag ids 1..4)")
print("  S13 PASS: mount found in an equipped bag")

-- S14 --- mounting is still gated: a bag mount changes nothing in combat
local me14 = fresh(false, true, false)
no_learned_mounts()
mock._bag_items = { [0] = { bag_item(REINS) } }

ok = mm.try_mount(me14, { x = 0, y = 100, z = 0 })
assert(ok == false and #_use_item_calls == 0, "S14 FAIL: no mount item may be used in combat")
print("  S14 PASS: bag mount still blocked in combat")

-- ============================================================================
-- H1: begin_travel — far walk, mount available → the cast is issued and the walk is HELD
-- ============================================================================
local meH = fresh(false, false, false)
setup_mounts()
local FAR = { x = 0, y = 200, z = 0 }

local hold = mm.begin_travel(meH, FAR, 10.0)
assert(hold == true, "H1a FAIL: the walk must be held while the mount cast is in flight")
assert(#_mount_calls == 1, "H1b FAIL: the mount cast must have been issued")
print("  H1 PASS: begin_travel mounts first and holds the walk")

-- ============================================================================
-- H2: the cast lands → the hold is released and the walk may start
-- ============================================================================
_st.mounted = true
hold = mm.begin_travel(meH, FAR, 10.5)
assert(hold == false, "H2a FAIL: a mounted player must be allowed to walk")
assert(#_mount_calls == 1, "H2b FAIL: no second cast may be issued once mounted")
hold = mm.begin_travel(meH, FAR, 10.6)
assert(hold == false, "H2c FAIL: the hold must stay released")
print("  H2 PASS: hold released once mounted")

-- ============================================================================
-- H3: the cast never lands → bounded hold, then walk on foot behind a fail cooldown
-- ============================================================================
local meH3 = fresh(false, false, false)
setup_mounts()

hold = mm.begin_travel(meH3, FAR, 10.0)
assert(hold == true, "H3a FAIL: first attempt holds")
hold = mm.begin_travel(meH3, FAR, 11.0)          -- still inside the cast window
assert(hold == true, "H3b FAIL: the hold must last for the cast window")
hold = mm.begin_travel(meH3, FAR, 12.5)          -- window expired, never mounted
assert(hold == false, "H3c FAIL: an expired attempt must release the walk")
assert(#_mount_calls == 1, "H3d FAIL: no extra cast may be issued")
hold = mm.begin_travel(meH3, FAR, 13.0)          -- inside the fail cooldown
assert(hold == false, "H3e FAIL: a failed mount must be backed off, not retried")
assert(#_mount_calls == 1, "H3f FAIL: no cast inside the fail cooldown")
hold = mm.begin_travel(meH3, FAR, 33.0)          -- cooldown over
assert(hold == true, "H3g FAIL: after the cooldown a new attempt must be made")
assert(#_mount_calls == 2, "H3h FAIL: the retry should have cast again")
print("  H3 PASS: failed cast is bounded, then backed off, then retried")

-- ============================================================================
-- H4: nothing to mount → never hold, and do not rescan the bags every walk
-- ============================================================================
local meH4 = fresh(false, false, false)
no_learned_mounts()
mock._bag_items = { [0] = { bag_item(NON_MOUNT_ITEM) } }

hold = mm.begin_travel(meH4, FAR, 10.0)
assert(hold == false, "H4a FAIL: no mount source must not hold the walk")
assert(#_mount_calls == 0 and #_use_item_calls == 0, "H4b FAIL: nothing may be cast")
local scans_after_first = _bag_scans
assert(scans_after_first > 0, "H4c FAIL: the bags should have been scanned at least once")
mm.begin_travel(meH4, FAR, 20.0)
assert(_bag_scans == scans_after_first,
    "H4d FAIL: the bags must not be rescanned inside the no-mount cooldown")
mm.begin_travel(meH4, FAR, 80.0)
assert(_bag_scans > scans_after_first, "H4e FAIL: after the cooldown the bags are worth a look")
print("  H4 PASS: no mount source walks on, without rescanning the bags")

-- ============================================================================
-- H5: indoors → no attempt (the client refuses a mount inside, so a hold is pure loss)
-- ============================================================================
local meH5 = fresh(false, false, true)
setup_mounts()

hold = mm.begin_travel(meH5, FAR, 10.0)
assert(hold == false, "H5a FAIL: indoors must not hold the walk")
assert(#_mount_calls == 0, "H5b FAIL: no mount cast indoors")
print("  H5 PASS: no mount attempt indoors")

-- ============================================================================
-- H6: short walk → no attempt, no hold (a 1.5s cast costs more than it saves)
-- ============================================================================
local meH6 = fresh(false, false, false)
setup_mounts()

hold = mm.begin_travel(meH6, { x = 0, y = 20, z = 0 }, 10.0)
assert(hold == false, "H6a FAIL: a short walk must not be held")
assert(#_mount_calls == 0, "H6b FAIL: no cast for a short walk")
print("  H6 PASS: short walks are left alone")

-- ============================================================================
-- H7: already mounted → straight through, and riding into combat dismounts
-- ============================================================================
local meH7 = fresh(true, false, false)
setup_mounts()

hold = mm.begin_travel(meH7, FAR, 10.0)
assert(hold == false, "H7a FAIL: an already mounted player walks")
assert(#_mount_calls == 0, "H7b FAIL: no cast for an already mounted player")

assert(mm.dismount_now(meH7, "combat") == true, "H7c FAIL: dismount_now must dismount")
assert(_dismount_calls == 1, "H7d FAIL: one dismount expected")
_st.mounted = false
assert(mm.dismount_now(meH7, "combat") == false, "H7e FAIL: nothing to dismount on foot")
assert(_dismount_calls == 1, "H7f FAIL: no extra dismount on foot")
print("  H7 PASS: mounted travel passes through; dismount_now takes the player off")

-- ============================================================================
-- H8: a build whose is_mounted() flag never answers still detects a mount from the client's
-- mount list, so the hold cannot repeat forever and dismount still fires.
-- ============================================================================
local meH8 = fresh(false, false, false)
_st.mounted = false                                  -- the flag lies: we are mounted
core.spell_book.get_mount_count = function() return 1 end
core.spell_book.get_mount_info = function(idx)
    if idx == 1 then return { is_usable = true, is_active = true } end
    return nil
end

hold = mm.begin_travel(meH8, FAR, 10.0)
assert(hold == false, "H8a FAIL: an active mount in the client's list must stop the hold")
assert(#_mount_calls == 0, "H8b FAIL: no cast for a mount the list reports as active")
assert(mm.dismount_now(meH8, "test") == true, "H8c FAIL: the list must also drive dismount")
print("  H8 PASS: the client's mount list backs up the unit flag for both mount and dismount")

-- ============================================================================
-- H9: the player is already WALKING → no cast and no hold. Movement cancels a mount cast, and the
-- state that matters in play is the walk issued right after a gather or a knockback, where the
-- client is still moving the player. The mount that starts here dies a few frames in, and the
-- failure cooldown it arms is what left long journeys on foot.
-- ============================================================================
local meH9 = fresh(false, false, false)
setup_mounts()

_st.speed = 2.5
hold, why = mm.begin_travel(meH9, FAR, 10.0)
assert(hold == false, "H9a FAIL: a moving player must not hold the walk")
assert(#_mount_calls == 0, "H9b FAIL: no cast may be issued while the player is moving")
assert(why == "moving", "H9c FAIL: expected the reason 'moving', got " .. tostring(why))

-- Control, same scene standing still: the check is the movement, not the walk.
_st.speed = 0
hold, why = mm.begin_travel(meH9, FAR, 11.0)
assert(hold == true and #_mount_calls == 1,
    "H9d FAIL: standing still at the same distance must mount (got " .. tostring(why) .. ")")
print("  H9 PASS: a walking player is never mounted for; standing still is")

-- ============================================================================
-- H10: mid-cast / mid-channel → no attempt. A loot, gather or herb cast owns the player, and the
-- walk issued behind it is exactly when the bot tries to mount.
-- ============================================================================
local meH10 = fresh(false, false, false)
setup_mounts()

_st.casting = true
hold, why = mm.begin_travel(meH10, FAR, 10.0)
assert(hold == false and #_mount_calls == 0, "H10a FAIL: a casting player must not be mounted for")
assert(why == "casting", "H10b FAIL: expected 'casting', got " .. tostring(why))

_st.casting = false
_st.channelling = true
hold, why = mm.begin_travel(meH10, FAR, 11.0)
assert(hold == false and #_mount_calls == 0,
    "H10c FAIL: a channelling player must not be mounted for either")
assert(why == "casting", "H10d FAIL: expected 'casting' for a channel too, got " .. tostring(why))

_st.channelling = false
hold = mm.begin_travel(meH10, FAR, 12.0)
assert(hold == true and #_mount_calls == 1, "H10e FAIL: with the cast over the walk must mount")
print("  H10 PASS: a player mid-cast or mid-channel is left alone")

-- ============================================================================
-- H11: dead or a ghost → no attempt. The corpse run is not a travel, and the attempt it used to
-- spend armed a 20s failure cooldown that the resurrected player then waited out.
-- ============================================================================
local meH11 = fresh(false, false, false)
setup_mounts()

_st.dead = true
hold, why = mm.begin_travel(meH11, FAR, 10.0)
assert(hold == false and #_mount_calls == 0, "H11a FAIL: a dead player must not be mounted for")
assert(why == "dead", "H11b FAIL: expected 'dead', got " .. tostring(why))

_st.dead = false
_st.ghost = true
hold, why = mm.begin_travel(meH11, FAR, 11.0)
assert(hold == false and #_mount_calls == 0, "H11c FAIL: a ghost must not be mounted for")
assert(why == "dead", "H11d FAIL: expected 'dead' for a ghost too, got " .. tostring(why))

_st.ghost = false
hold = mm.begin_travel(meH11, FAR, 12.0)
assert(hold == true and #_mount_calls == 1, "H11e FAIL: alive again, the walk must mount")
print("  H11 PASS: dead and ghost players are never mounted for")

-- ============================================================================
-- H12: churn — no re-mount right after stepping off. Turning a quest in at a camp and walking 80yd
-- to the next camp is the pattern that used to pay mount/ride/dismount/mount for one arrival.
-- ============================================================================
local meH12 = fresh(true, false, false)
setup_mounts()

mm.dismount_now(meH12, "arrived")
_st.mounted = false

hold, why = mm.begin_travel(meH12, FAR, 11.0)      -- one second later (mock time is 10.0)
assert(hold == false and #_mount_calls == 0,
    "H12a FAIL: a walk issued right after stepping off must not mount again")
assert(why == "just dismounted", "H12b FAIL: expected 'just dismounted', got " .. tostring(why))

hold, why = mm.begin_travel(meH12, FAR, 19.0)      -- past the 8s guard
assert(hold == true and #_mount_calls == 1,
    "H12c FAIL: past the guard the same walk must mount (got " .. tostring(why) .. ")")
print("  H12 PASS: mounting is not attempted straight after a dismount, and is after the guard")

-- ============================================================================
-- H13: a cast that dies mid-hold is written off at once. Waiting out the full cast window with the
-- walk held is pure loss once the player is moving again — and the fail cooldown has to start now,
-- not two seconds from now.
-- ============================================================================
local meH13 = fresh(false, false, false)
setup_mounts()

hold = mm.begin_travel(meH13, FAR, 10.0)
assert(hold == true, "H13a FAIL: the first attempt holds")
_st.speed = 2.5                                     -- something moved the player mid-cast
hold, why = mm.begin_travel(meH13, FAR, 10.4)
assert(hold == false, "H13b FAIL: an interrupted cast must release the walk immediately")
assert(why == "cast interrupted", "H13c FAIL: expected 'cast interrupted', got " .. tostring(why))

_st.speed = 0
hold = mm.begin_travel(meH13, FAR, 12.1)            -- the old hold would have expired here anyway
assert(hold == false and #_mount_calls == 1,
    "H13d FAIL: the interrupted attempt must be behind the fail cooldown, not retried")
hold = mm.begin_travel(meH13, FAR, 33.0)            -- cooldown over
assert(hold == true and #_mount_calls == 2, "H13e FAIL: after the cooldown a new attempt is made")

-- Control: the same hold with a still player lasts the full cast window.
local meH13b = fresh(false, false, false)
setup_mounts()
hold = mm.begin_travel(meH13b, FAR, 10.0)
assert(hold == true, "H13f FAIL: unattended hold, first tick")
hold = mm.begin_travel(meH13b, FAR, 11.5)
assert(hold == true, "H13g FAIL: unattended hold, inside the cast window")
hold, why = mm.begin_travel(meH13b, FAR, 12.5)
assert(hold == false and why == "cast did not land",
    "H13h FAIL: an unattended hold expires at the cast timeout with its own reason, got " ..
    tostring(why))
print("  H13 PASS: an interrupted cast releases at once; an unattended one expires at the timeout")

-- ============================================================================
-- H14: the reason is published — riding answers nil, walking answers why. This is what the field log
-- rides on ("travelling on foot — too close"), so it must not report a reason for a mounted player.
-- ============================================================================
local meH14 = fresh(true, false, false)
setup_mounts()
hold, why = mm.begin_travel(meH14, FAR, 10.0)
assert(hold == false and why == nil,
    "H14a FAIL: a mounted player must not report a reason, got " .. tostring(why))
assert(mm.why_not() == nil, "H14b FAIL: a player already mounted has no denial to report")

_st.mounted = false
hold, why = mm.begin_travel(meH14, { x = 0, y = 5, z = 0 }, 11.0)
assert(why == "too close" and mm.why_not() == "too close",
    "H14c FAIL: denied walks must name the reason, got " .. tostring(why))

-- And a reason is cleared by a successful attempt, so why_not() cannot report a stale denial.
hold = mm.begin_travel(meH14, FAR, 12.0)
assert(hold == true and mm.why_not() == nil,
    "H14d FAIL: an issued cast clears the previous denial")
print("  H14 PASS: the gate publishes why a walk is on foot, and only then")

-- ============================================================================
-- H15: the 80yd floor, pinned from both sides, plus the unmeasurable destination.
-- ============================================================================
local meH15 = fresh(false, false, false)
setup_mounts()

hold, why = mm.begin_travel(meH15, { x = 0, y = 79, z = 0 }, 10.0)
assert(hold == false and #_mount_calls == 0 and why == "too close",
    "H15a FAIL: 79yd must still be walked (got " .. tostring(why) .. ")")
hold = mm.begin_travel(meH15, { x = 0, y = 81, z = 0 }, 11.0)
assert(hold == true and #_mount_calls == 1, "H15b FAIL: 81yd must mount")

-- A destination we cannot measure: stay on foot rather than mount for an unknown walk.
local meH15b = fresh(false, false, false)
setup_mounts()
meH15b.get_position = function() error("no position") end
hold, why = mm.begin_travel(meH15b, FAR, 10.0)
assert(hold == false and #_mount_calls == 0 and why == "too close",
    "H15c FAIL: an unmeasurable destination must not mount (got " .. tostring(why) .. ")")

-- No destination at all is the same shape: the gate has nothing to judge, so it refuses.
local meH15c = fresh(false, false, false)
setup_mounts()
assert(mm.try_mount(meH15c) == false and #_mount_calls == 0,
    "H15d FAIL: a mount attempt with no destination must be refused")
assert(mm.why_not() == "too close",
    "H15e FAIL: expected 'too close' for a destination-less attempt, got " ..
    tostring(mm.why_not()))
print("  H15 PASS: the mount floor holds at 80yd and an unmeasurable walk stays on foot")

-- H16: a character's profile can disable automatic mounting without disabling dismount safety.
-- The profile owner is session-scoped; this proves the mount manager asks it before every cast.
-- ============================================================================
local character_profile = require("character_profile_sylvanas")
local profile_menu = { _values = {} }
function profile_menu.get(key, fallback)
    local value = profile_menu._values[key]
    if value == nil then return fallback end
    return value
end
function profile_menu.set(key, value) profile_menu._values[key] = value end

character_profile.reset()
local profile_me = make_me({ x = 0, y = 0, z = 0 })
profile_me.get_name = function() return "MountProfileHero" end
profile_me.get_realm_name = function() return "TestRealm" end
assert(character_profile.activate_for(profile_me, profile_menu),
    "H16a FAIL: mount profile fixture did not activate")
profile_menu.set("profile_mount_use", false)
assert(character_profile.sync_active(profile_menu), "H16b FAIL: mount profile was not synchronized")

local meH16 = fresh(false, false, false)
setup_mounts()
hold, why = mm.begin_travel(meH16, FAR, 10.0)
assert(hold == false and #_mount_calls == 0,
    "H16c FAIL: mount use disabled must walk on foot without a cast")
assert(why == "mount use disabled",
    "H16d FAIL: disabled mount use must publish its reason, got " .. tostring(why))
print("  H16 PASS: profile mount use gates automatic casts only")
character_profile.reset()

-- ============================================================================
-- S15: the generated list itself. It is data, so what is worth pinning is the RULE behind it:
-- the counting-crystal and event-broom mounts carry "Mount" as their item type WITHOUT the
-- "Summons and dismisses" use line, and a table built on the use line alone silently missed every
-- one of them — a mount in the bags that the manager could not recognise.
-- ============================================================================
do
    local items = require("shared/mount_items_sylvanas")
    local n = 0
    for _ in pairs(items) do n = n + 1 end
    assert(n >= 200, "S15a FAIL: the mount table looks truncated (" .. n .. " entries)")
    -- One from each category, so a rule that only catches "Reins of..." cannot pass this.
    for _, id in ipairs({ 2411, 12302, 19902, 21218, 33176, 35225 }) do
        assert(items[id], "S15b FAIL: mount item " .. id .. " is missing from the generated table")
    end
    -- Cut content the corpus still ships: never offered as a mount.
    for _, id in ipairs({ 823, 842, 18063, 33302 }) do
        assert(not items[id],
            "S15c FAIL: cut content item " .. id .. " must not be offered as a mount")
    end
    print("  S15 PASS: generated mount table covers the type-line mounts and drops cut content")
end

print("PASS test_mount_manager")
os.exit(0)
