-- mount_manager_sylvanas.lua — Auto-mount/dismount for EaxAutoQuester
-- WHAT:  Mounts the player before a long walk, and dismounts on arrival, on entering combat, and
--        on request. The mount comes from the client's own mount list when it has one, and from a
--        mount ITEM in the bags otherwise.
-- WHEN:  NAV calls M.begin_travel(me, dest, now) before it issues a walk, M.update(me, dest) every
--        travelling tick, and M.dismount_now(me, why) when a walk ends or combat starts.
-- WHY:   Three facts shape this file.
--        1. A mount is a 1.5s CAST, and movement cancels the cast. Mounting while the nav client
--           is walking the player therefore cannot work — the cast dies a few frames in and the
--           player arrives on foot. So mounting is not a per-tick attempt: it happens BEFORE the
--           walk is issued, while the player is still standing still, and travel is held for the
--           cast (M.begin_travel returns true = "do not start walking yet"). Live symptom this
--           replaces: the bag scan ran, the cast was issued, and nothing ever mounted.
--           One cast is not free, so the gate answers everything that can kill or waste it FIRST:
--           moving (movement cancels the cast), mid-cast/mid-channel (a loot or gather cast owns the
--           player), dead or a ghost (the run-back is not a travel), indoors (the client refuses),
--           in combat, a walk too short to pay for the cast, and a re-mount inside 8s of stepping
--           off (mount/ride/dismount churn on consecutive short hops). A cast that dies anyway is
--           written off the moment the player moves instead of holding the walk to its timeout, and
--           the gate's own answer is published (M.why_not) so "travelled on foot" can name a cause.
--        2. `core.spell_book.get_mount_count/get_mount_info` is the documented mount list (API
--           mount_info at .api/core.lua:3008-3025, summoned with core.input.mount at :2492) — but
--           it lists LEARNED mounts, and a mount you are carrying is not learned yet, so a player
--           holding reins sees an empty list and never mounts. The bag path closes that: read the
--           bags, judge each item, and use the mount item (core.input.use_item at :1983 — using a
--           mount item both summons the mount and teaches it, so one use is enough and the spell
--           path takes over afterwards).
--        3. A mounted player cannot cast, so the rotation is dead until the player is dismounted.
--           Every path that ends a walk and every path that starts a fight dismounts through
--           M.dismount_now. (`nav.dismount` in the coordinator was a nil field on a module that
--           never had one, so combat used to leave the player mounted.)
--        An item is judged by the CLIENT first: core.quests.get_item_info(item_id) answers
--        item_type/item_sub_type/class_id/subclass_id (.api/core.lua:4655-4676), so "Mount" (or
--        class 15 subclass 5) is the client's own verdict. shared/mount_items_sylvanas.lua — the
--        generated TBC mount-item list — is the backstop for builds where that call is missing or
--        answers a table with no class data. It is only ever consulted for an item already in the
--        bags, so a stale entry is inert.
-- SAFETY: pcall on every API call; no mount is ever granted, only recognised; never mounts in
--        combat or indoors (the client refuses a mount indoors, so attempting it only wastes the
--        hold); the bag scan runs only inside a throttled, distance-gated attempt. Squared yards
--        only (Pattern 3). Nothing here allocates on the travelling-tick path: M.update does a
--        position read and at most one dismount call, and every table in this file (the mount item
--        list, the dead-item set) is built at load or on the gated attempt path, never per tick.
--        Every new pre-cast check is a pcall'd read that answers "fine" on a build without the
--        call, so a missing API costs a wasted cast at worst, never a blocked one.

local M = {}

-- ============================================================================
-- Hot-path API caching at module load (Pattern 2)
-- ============================================================================

local _core_time = core.time
local _input_mount = core.input.mount
local _input_dismount = core.input.dismount
local _input_use_item = core.input.use_item
local _get_items_in_bag = core.inventory and core.inventory.get_items_in_bag
local _quests_get_item_info = core.quests and core.quests.get_item_info
local _character_profile = nil
local _character_profile_failed = false

--- The active character's mount preference, if the profile owner is available.
--- A missing optional module keeps the established mount behavior; the failed require is latched
--- so a broken profile cannot allocate an error string on every long-walk attempt.
local function profile_mounts_enabled()
    if not _character_profile and not _character_profile_failed then
        local ok, profile = pcall(require, "character_profile_sylvanas")
        if ok and profile then
            _character_profile = profile
        else
            _character_profile_failed = true
        end
    end
    if _character_profile and _character_profile.mount_use_enabled then
        local ok, enabled = pcall(_character_profile.mount_use_enabled)
        if ok and type(enabled) == "boolean" then return enabled end
    end
    return true
end

--- The client's mount list, read through core.spell_book at call time rather than cached at load
--- (Pattern 2's exception): this is not a hot path — it runs only on a gated mount attempt — and
--- the list changes under us the moment a mount is learned, which is exactly what happens after a
--- carried mount item is used. A cached copy would keep reporting the pre-learn list.
--- @return function|nil count_fn, function|nil info_fn
local function mount_list()
    local sb = core.spell_book
    if not sb then return nil, nil end
    return sb.get_mount_count, sb.get_mount_info
end

-- The generated TBC mount-item list. Optional on purpose: a build without it falls back to the
-- client's item info alone, and a build without that falls back to "no bag mount".
local _ok_items, _MOUNT_ITEMS = pcall(require, "shared/mount_items_sylvanas")
if not _ok_items then _MOUNT_ITEMS = {} end

-- ============================================================================
-- Constants
-- ============================================================================

--- The walk must be long enough to be worth a cast. A mount costs a 1.5s cast, a 2s hold while it
--- lands, and the dismount at the other end; a 50yd walk is about 6s on foot and about 3s ridden,
--- which does not pay for a 3.5s interruption — and short hops are where mounting churns (mount,
--- ride 40yd, dismount, mount again). 80yd is where the cast starts to win outright.
local MOUNT_DISTANCE_SQ = 6400     -- 80 yards squared: the shortest walk worth a cast
local DISMOUNT_DISTANCE_SQ = 225   -- 15 yards squared
local REMOUNT_GUARD = 8.0          -- seconds: no re-mount right after stepping off (short hops)
local MOVING_SPEED = 0.1           -- above this the player is walking, and movement cancels the cast
local MOUNT_COOLDOWN = 3.0         -- seconds between mount attempts
local MOUNT_CAST_TIMEOUT = 2.0     -- a mount cast is 1.5s; past this the attempt is written off
local MOUNT_FAIL_COOLDOWN = 20.0   -- after an attempt that never landed (refused / interrupted)
local NO_MOUNT_COOLDOWN = 60.0     -- when there is no mount source at all, stop rescanning the bags
local BAGS_TO_SCAN = 4             -- bag ids 0..4: the container read 0 covers the backpack and
                                   -- worn gear, 1..4 the equipped bags (see .api/core.lua:889-966
                                   -- for what each id actually reaches)

-- ============================================================================
-- State
-- ============================================================================

local _last_mount_attempt = 0
local _cached_spell_index = nil   -- cached learned-mount index (the list cannot change mid-session)
local _pending_until = 0          -- > now while a mount cast is in flight and travel is held
local _fail_until = 0             -- mounts are not attempted again before this time
local _dead_items = {}            -- mount items the client refused; not offered again this session
local _dismounted_at = nil        -- when the player last stepped off, for the churn guard
local _last_denial = nil          -- why the last attempt was refused (M.why_not, for tests/logs)

-- Hoisted probes and input calls (perf pass): `M.update` runs on every NAV tick, and each of these
-- was an inline `pcall(function() ... end)` that built a closure per call — three or four per tick.
-- Module-level functions handed their arguments through the pcall keep every return value and the
-- pcall's error protection exactly as they were.
local function unit_is_mounted(u) return u:is_mounted() end
local function unit_is_in_combat(u) return u:is_in_combat() end
local function unit_is_indoors(u) return u:is_indoors() end
local function unit_get_position(u) return u:get_position() end
local function unit_is_dead(u) return u:is_dead() end
local function unit_is_ghost(u) return u:is_ghost() end
-- is_casting_spell / is_channelling_spell are the documented game_object members (.api/game_object
-- .lua:311,321) and the ones the rest of this plugin reads (coordinator:311, idle_state:29). The
-- shorter is_casting in izi_sdk is a convenience over the same data and is not what this runtime
-- exposes on the player object, so it is not read here — a probe that only answers in tests would
-- make this check a never-lane.
local function unit_is_casting(u) return u:is_casting_spell() end
local function unit_is_channelling(u) return u:is_channelling_spell() end
local function unit_get_movement_speed(u) return u:get_movement_speed() end
local function item_get_id(obj) return obj:get_item_id() end

-- ============================================================================
-- Helpers
-- ============================================================================

--- Check if player is currently mounted.
-- @param me game_object|nil
-- @return boolean
local function is_mounted(me)
    if not me then return false end
    local ok, mounted = pcall(unit_is_mounted, me)
    return ok and mounted == true
end

--- Mounted, checked twice: the unit flag first (one call), then the client's own mount list for an
--- entry it reports as active. The flag is the documented one (game_object.md) and is enough on a
--- build that has it; the list is the fallback for a build where the flag is missing, because a
--- missed "mounted" reading would make every long walk pay a 2s hold and then dismount nothing.
-- @param me game_object|nil
-- @return boolean
local function is_mounted_thorough(me)
    if is_mounted(me) then return true end
    local count_fn, info_fn = mount_list()
    if not (count_fn and info_fn) then return false end

    local ok, count = pcall(count_fn)
    if not ok or type(count) ~= "number" or count < 1 then return false end

    for i = 1, count do
        local ok2, info = pcall(info_fn, i)
        if ok2 and type(info) == "table" and info.is_active then
            _cached_spell_index = i
            return true
        end
    end
    return false
end

--- Check if player is in combat.
-- @param me game_object|nil
-- @return boolean
local function is_in_combat(me)
    if not me then return false end
    local ok, combat = pcall(unit_is_in_combat, me)
    return ok and combat == true
end

--- Indoors: the client refuses a mount, so the hold would be pure loss. A build without the call
--- answers "outdoors", which is the pre-existing behaviour.
-- @param me game_object|nil
-- @return boolean
local function is_indoors(me)
    if not me then return false end
    local ok, indoors = pcall(unit_is_indoors, me)
    return ok and indoors == true
end

--- Get squared distance between player and destination.
-- @param me game_object
-- @param dest table {x,y,z}
-- @return number|nil
local function dist_sq_to_dest(me, dest)
    if not me or not dest then return nil end
    local ok, pos = pcall(unit_get_position, me)
    if not ok or not pos then return nil end
    local dx = (pos.x or 0) - (dest.x or 0)
    local dy = (pos.y or 0) - (dest.y or 0)
    local dz = (pos.z or 0) - (dest.z or 0)
    return dx*dx + dy*dy + dz*dz
end

--- Walking right now? A mount cast is cancelled by movement, so an attempt made while the client is
--- already walking the player can only waste the attempt and its cooldown. A build without the call
--- answers "standing still", which is the pre-existing behaviour.
-- @param me game_object|nil
-- @return boolean
local function is_moving(me)
    if not me then return false end
    local ok, speed = pcall(unit_get_movement_speed, me)
    return ok and type(speed) == "number" and speed > MOVING_SPEED
end

--- Mid-cast or mid-channel: a loot, gathering or fishing cast owns the player, and a mount attempt
--- would either be refused or eat the cast it was queued behind. (The travelling tick never mounts,
--- but the first walk issued after a gather starts from exactly this state.)
-- @param me game_object|nil
-- @return boolean
local function is_busy_casting(me)
    if not me then return false end
    local ok, casting = pcall(unit_is_casting, me)
    if ok and casting == true then return true end
    local ok2, channelling = pcall(unit_is_channelling, me)
    return ok2 and channelling == true
end

--- Dead or a ghost: there is nothing to mount and running back is not a travel. Without this the
--- run-back paid a refused attempt plus the failure cooldown, and the first thing the resurrected
--- player did was wait that cooldown out.
-- @param me game_object|nil
-- @return boolean
local function is_dead_or_ghost(me)
    if not me then return false end
    local ok, dead = pcall(unit_is_dead, me)
    if ok and dead == true then return true end
    local ok2, ghost = pcall(unit_is_ghost, me)
    return ok2 and ghost == true
end

--- Is this walk long enough to be worth a cast at all? The walk has to clear the floor, and a
--- walk we cannot measure (no destination, or the position read failed) is not mounted for: not
--- mounting costs the walk, mounting badly costs the cast, the hold and the dismount at the far end
--- of it.
-- @param me game_object
-- @param dest table|nil destination
-- @return boolean
local function travel_is_worth_mounting(me, dest)
    local d_sq = dist_sq_to_dest(me, dest)
    if d_sq == nil then return false end
    return d_sq >= MOUNT_DISTANCE_SQ
end

--- Is this item a mount? The client answers first; the generated table is the backstop.
--- A client answer that carries item class data is trusted even when it says "not a mount"
--- (otherwise every mount in the generated table would be used by id even after the client
--- identified it as something else). A missing class item info — the shape this runtime may not
--- have at all — falls through instead, so the table still works.
--- @param item_id number|nil
--- @return boolean
function M.is_mount_item(item_id)
    if type(item_id) ~= "number" then return false end

    if _quests_get_item_info then
        local ok, info = pcall(_quests_get_item_info, item_id)
        if ok and type(info) == "table" then
            local sub = info.item_sub_type
            if type(sub) == "string" and sub:lower():find("mount", 1, true) then
                return true
            end
            if info.class_id == 15 and info.subclass_id == 5 then
                return true
            end
            if type(sub) == "string" or info.class_id ~= nil then
                return false
            end
        end
    end

    return _MOUNT_ITEMS[item_id] ~= nil
end

--- The learned-mount index the client reports as usable, if any.
--- @return number|nil
local function find_spell_mount()
    if _cached_spell_index then return _cached_spell_index end
    local count_fn, info_fn = mount_list()
    if not (count_fn and info_fn) then return nil end

    local ok, count = pcall(count_fn)
    if not ok or type(count) ~= "number" or count < 1 then return nil end

    for i = 1, count do
        local ok2, info = pcall(info_fn, i)
        if ok2 and type(info) == "table" then
            if info.is_usable then
                _cached_spell_index = i
                return i
            end
            -- Usable-but-hidden: a list that reports an active or usable mount by another shape
            -- still counts, otherwise the bag path is taken for a mount the client already knows.
            if info.is_active then
                _cached_spell_index = i
                return i
            end
        end
    end
    return nil
end

--- First mount ITEM carried in the bags, or nil. Scans bag ids 0..4 (0 is the container read
--- that covers the backpack and worn gear — not only the backpack) and returns the item id.
--- Items the client refused earlier in the session are skipped (see _dead_items).
--- @return number|nil item_id, string|nil item_name
local function find_bag_mount()
    if not _get_items_in_bag then return nil end

    for bag = 0, BAGS_TO_SCAN do
        local ok, items = pcall(_get_items_in_bag, bag)
        if ok and type(items) == "table" then
            for i = 1, #items do
                local entry = items[i]
                local obj = entry and entry.object
                if obj then
                    local id_ok, item_id = pcall(item_get_id, obj)
                    if id_ok and not _dead_items[item_id] and M.is_mount_item(item_id) then
                        return item_id, _MOUNT_ITEMS[item_id]
                    end
                end
            end
        end
    end
    return nil
end

--- How to get mounted right now: the client's learned mount if there is one, else a carried
--- mount item. @return table|nil { kind = "spell"|"item", index = n|id = n, name = s|nil }
function M.find_mount_source()
    local index = find_spell_mount()
    if index then return { kind = "spell", index = index } end

    local item_id, item_name = find_bag_mount()
    if item_id then return { kind = "item", id = item_id, name = item_name } end

    return nil
end

--- Issue the cast for a source. Returns false when the call itself failed.
--- @param source table from M.find_mount_source
--- @return boolean cast_issued
local function attempt_mount(source)
    local ok, attempted
    if source.kind == "spell" then
        ok, attempted = pcall(_input_mount, source.index)
    else
        ok, attempted = pcall(_input_use_item, source.id)
    end

    if ok and core.log then
        if source.kind == "spell" then
            core.log("[EaxAutoQuester] Mounting up (mount #" .. tostring(source.index) .. ")")
        else
            core.log("[EaxAutoQuester] Mounting up with a bag mount: " ..
                tostring(source.name or source.id) .. " (" .. tostring(source.id) .. ")")
        end
    end

    -- A spell the client refuses is not a reason to keep asking: drop the cached index so the
    -- next attempt re-reads the mount list (and can fall through to a bag mount). A bag mount the
    -- client refuses is remembered so the same dead item is not offered again all session.
    if not ok or attempted == false then
        if source.kind == "spell" then
            _cached_spell_index = nil
        else
            _dead_items[source.id] = true
        end
        return false
    end

    if source.kind == "spell" and source.index then
        _cached_spell_index = source.index
    end
    return true
end

-- ============================================================================
-- Core Logic
-- ============================================================================

--- Every reason not to mount right now, in the order that costs the least to check. One place, so
--- the answer to "why didn't it mount?" is a name rather than an absence (M.why_not).
--- @param me game_object
--- @param dest table|nil destination
--- @param now number
--- @return boolean allowed, string|nil reason
local function mount_allowed(me, dest, now)
    if is_mounted(me) then return false, "already mounted" end
    if not profile_mounts_enabled() then return false, "mount use disabled" end
    if is_in_combat(me) then return false, "in combat" end
    if is_indoors(me) then return false, "indoors" end
    if is_dead_or_ghost(me) then return false, "dead" end
    if is_moving(me) then return false, "moving" end
    if is_busy_casting(me) then return false, "casting" end
    if not travel_is_worth_mounting(me, dest) then return false, "too close" end

    -- Stepping off and straight back on is the churn this guard is for: a walk issued right after
    -- an arrival is usually the last few dozen yards of the same place.
    if _dismounted_at and (now - _dismounted_at) < REMOUNT_GUARD then
        return false, "just dismounted"
    end

    if now < _fail_until then return false, "last attempt failed" end
    if (now - _last_mount_attempt) < MOUNT_COOLDOWN then return false, "throttled" end
    return true, nil
end

--- Why the last mount attempt was refused (nil when the last attempt was issued). The mount decision
--- is a chain of eight checks, and a silent no is indistinguishable from a broken one in the field:
--- "walked 300 yards on foot" reads as a bug whichever of them answered no.
--- @return string|nil
function M.why_not()
    return _last_denial
end

--- Attempt to mount if conditions are met — the one-shot form, without the hold. Used by tests
--- and by any caller that has already arranged to be standing still.
--- @param me game_object
--- @param dest table|nil {x,y,z} destination position. Required in effect: the gate cannot judge a
---        walk it cannot measure, so a nil destination is refused like an unreachable one.
--- @return boolean True if a mount cast was issued.
function M.try_mount(me, dest)
    if not me then return false end

    local now = _core_time()
    local allowed, reason = mount_allowed(me, dest, now)
    if not allowed then
        _last_denial = reason
        return false
    end
    _last_mount_attempt = now

    local source = M.find_mount_source()
    if not source then
        _fail_until = now + NO_MOUNT_COOLDOWN
        _last_denial = "no mount available"
        return false
    end

    _last_denial = nil
    return attempt_mount(source)
end

--- Mount before travel, holding the walk for the cast.
---
--- Returns TRUE when the caller must NOT start walking yet: a mount cast is in flight and movement
--- would cancel it. Returns FALSE when the caller may walk — already mounted, nothing to mount, or
--- the attempt resolved (mounted, refused, or written off after MOUNT_CAST_TIMEOUT).
---
--- Holding is bounded by MOUNT_CAST_TIMEOUT and backed off by MOUNT_FAIL_COOLDOWN, so a build
--- where the cast never lands pays one 2s pause per MOUNT_FAIL_COOLDOWN at worst — never a stall,
--- and never a loop.
--- @param me game_object
--- @param dest table|nil {x,y,z}
--- @param now number|nil current time (defaults to core.time())
--- @return boolean hold True = keep standing still this tick.
--- @return string|nil why, when NOT holding and the player is on foot: the reason to log. Nil when
---         the player is already mounted, so a caller can tell "riding" from "walking, because …".
function M.begin_travel(me, dest, now)
    if not me then return false, nil end
    now = now or _core_time()

    -- A pending attempt owns the next couple of ticks: the walk must not start until it resolves.
    if _pending_until > 0 then
        if is_mounted_thorough(me) then
            _pending_until = 0
            if core.log then core.log("[EaxAutoQuester] Mounted — starting the walk") end
            return false, nil
        end
        -- The cast is already dead, so the hold is pure loss: something moved the player (a mob, a
        -- knockback, a combat-driven step) or a fight started. Written off now instead of after the
        -- full timeout, because the next tick is where the cooldown should already be running.
        if is_moving(me) or is_in_combat(me) then
            _pending_until = 0
            _fail_until = now + MOUNT_FAIL_COOLDOWN
            _last_denial = "cast interrupted"
            if core.log then core.log("[EaxAutoQuester] Mount interrupted — walking on foot") end
            return false, _last_denial
        end
        if now < _pending_until then
            return true, nil                 -- casting: hold still
        end
        -- The cast never landed (refused, interrupted, indoors after all).
        _pending_until = 0
        _fail_until = now + MOUNT_FAIL_COOLDOWN
        _last_denial = "cast did not land"
        if core.log then core.log("[EaxAutoQuester] Mount did not land — walking on foot") end
        return false, _last_denial
    end

    if is_mounted_thorough(me) then return false, nil end

    -- The thorough "already mounted" check above answers for the flag and the list; everything else
    -- is the shared gate, so the checks a travelling tick and a one-shot attempt make cannot drift.
    local allowed, reason = mount_allowed(me, dest, now)
    if not allowed then
        _last_denial = reason
        return false, reason
    end

    local source = M.find_mount_source()
    if not source then
        _fail_until = now + NO_MOUNT_COOLDOWN
        _last_denial = "no mount available"
        return false, _last_denial
    end

    _last_mount_attempt = now
    if not attempt_mount(source) then
        _fail_until = now + MOUNT_FAIL_COOLDOWN
        _last_denial = "cast refused"
        return false, _last_denial
    end

    _last_denial = nil
    _pending_until = now + MOUNT_CAST_TIMEOUT
    return true, nil
end

--- Dismount now, whatever the reason ("engaging", "arrived", "combat", "shutdown").
--- A mounted player cannot cast, so every path that ends a walk or starts a fight needs this.
--- @param me game_object|nil
--- @param why string|nil reason, for the log
--- @return boolean True if a dismount was issued.
function M.dismount_now(me, why)
    if not me then return false end
    if not is_mounted_thorough(me) then return false end

    pcall(_input_dismount)
    _pending_until = 0
    _dismounted_at = _core_time()
    if core.log then
        core.log("[EaxAutoQuester] Dismounting" .. (why and (" — " .. tostring(why)) or ""))
    end
    return true
end

--- Dismount if close to destination or explicitly requested.
--- @param me game_object
--- @param dest table|nil {x,y,z}
--- @param force boolean|nil Always dismount if true.
--- @return boolean True if a dismount was issued.
function M.try_dismount(me, dest, force)  -- luacheck: ignore
    if not me then return false end
    if force then return M.dismount_now(me, "forced") end
    if not is_mounted_thorough(me) then return false end

    if dest then
        local d_sq = dist_sq_to_dest(me, dest)
        if d_sq and d_sq <= DISMOUNT_DISTANCE_SQ then
            return M.dismount_now(me, "close to destination")
        end
    end

    return false
end

--- Travelling-tick update: dismount when the destination is close. Mounting is NOT attempted here
--- — see the header: a mount cast dies to movement, so mounting lives in M.begin_travel, before any
--- walk is issued. Keeping the attempt here is what made "auto mount" never mount.
---
--- @param me game_object
--- @param dest table|nil {x,y,z}
--- @return string|nil "dismounted", or nil.
function M.update(me, dest)
    if not me then return nil end

    -- The CHEAP flag only, on purpose: this runs on every travelling tick, and the thorough check
    -- walks the client's mount list with a pcall per entry. Missing a broken-flag mount here costs
    -- nothing — the stand-off stop, the arrival and combat entry all use the thorough check, and
    -- they are the ends of the walk where the dismount actually has to happen.
    if not is_mounted(me) then return nil end

    -- The dismount radius is unchanged on purpose. The pre-emptive stop is the end of THIS walk; a
    -- ride that had to survive intermediate waypoints would have to be keyed on the travel's own
    -- destination, which this file does not know — and guessing it (the guide's waypoint) would hold
    -- a mounted player past the point where the next state wants to interact.
    if M.try_dismount(me, dest) then
        return "dismounted"
    end

    return nil
end

--- Reset cached mount index (call on spec/class change).
function M.invalidate_cache()
    _cached_spell_index = nil
end

--- Reset all internal state (for testing).
function M.reset()
    _cached_spell_index = nil
    _last_mount_attempt = 0
    _pending_until = 0
    _fail_until = 0
    _dead_items = {}
    _dismounted_at = nil
    _last_denial = nil
end

return M
