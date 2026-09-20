-- What: Auto-loot module for EaxAutoQuester — loot window management
-- When: Called from quest_state or main loop after kills / object interaction
-- Why: Centralize loot logic with gold priority, throttle, and nil-guards
-- Safety: All game_ui/input calls pcall-wrapped; static table reuse; 0.5s throttle via utils
-- Decision: Standalone module (not EaxRotations), caches core API at load
-- API shapes (item 14): loot_object is UNITS AND CORPSES ONLY and refuses everything else, so
--     containers go through use_object; loot indices are 0 based; bag-space numbers come from
--     common/utility/inventory_helper, the documented owner of both them and the (bag_id,
--     bag_slot) pair, because the raw core.inventory bindings are shifted against each other
--     and get_items_in_bag(0) is the whole player container, not the backpack.

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _core_time = core.time
local _core_log = core.log
local _get_loot_item_count = core.game_ui.get_loot_item_count
local _get_loot_item_id = core.game_ui.get_loot_item_id
local _get_loot_item_name = core.game_ui.get_loot_item_name
local _get_loot_is_gold = core.game_ui.get_loot_is_gold
local _loot_item = core.input.loot_item
local _close_loot = core.input.close_loot
local _loot_object = core.input.loot_object
local _use_object = core.input.use_object
local _confirm_loot_slot = core.input.confirm_loot_slot
local _get_visible_objects = core.object_manager.get_visible_objects
local _get_local_player = core.object_manager.get_local_player

-- Static table reuse (Pattern 4 from AGENTS.md) — avoids per-frame GC churn
local _t = { n = 0 }
-- Lockstep companion to _t: true at an index means that object is a container (chest, herb or
-- ore node, bobber) and has to be opened with use_object rather than loot_object.
local _t_is_container = { n = 0 }

-- ============================================================================
-- Module Table
-- ============================================================================
local M = {}

-- ============================================================================
-- Internal: utils reference (lazy-loaded)
-- ============================================================================

local _utils = nil

local function ensure_utils()
    if _utils then return true end
    local ok, mod = pcall(require, "utils_sylvanas")
    if ok and mod then
        _utils = mod
        return true
    end
    return false
end

-- ============================================================================
-- try_loot — process currently open loot window
-- ============================================================================

--- Answer a bind-on-pickup prompt the client is holding for a slot this pass looted.
--- This is the plugin's own action: the window only gets here because the plugin looted
--- every slot it found, and taking a BoP item is what raises the prompt. It is answered
--- only from inside that emptying pass, so a prompt the player raised by looting by hand is
--- left alone for the player to answer.
--- The slot comes from the recorded event and needs the documented conversion: "WoW's own
--- LOOT_BIND_CONFIRM event reports the 1 BASED slot, so forwarding args[1] straight from that
--- event confirms the wrong slot: subtract one first" (core.input.confirm_loot_slot).
--- @return boolean confirmed True when a prompt was answered
local function answer_loot_bind_confirm()
    local bridge_ok, bridge = pcall(require, "quest_frame_events_sylvanas")
    if not bridge_ok or type(bridge) ~= "table" or type(bridge.take_confirm) ~= "function" then
        return false
    end
    local ok_rec, record = pcall(bridge.take_confirm, "LOOT_BIND_CONFIRM")
    if not ok_rec or not record or type(record.args) ~= "table" then return false end
    local one_based = tonumber(record.args[1])
    if not one_based then return false end
    if not _confirm_loot_slot then return false end
    local ok = pcall(_confirm_loot_slot, one_based - 1)
    if ok and _core_log then
        _core_log("[EaxAutoQuester] Confirmed bind-on-pickup loot slot " .. tostring(one_based - 1))
    end
    return ok
end

--- Empty the currently open loot window. THE single owner of that behavior: the live
--- frame branch (quest_interaction_sylvanas.handle_any_frame, priority 1) and
--- auto_loot_all both call this, so the 0-based range, the gold-first order and the
--- compaction-safe walk exist in one place.
--- Gold slots are looted first (priority), then the remaining item slots.
--- Closes the window when done.
---
--- Two index rules, both documented:
---  1. LOOT SLOTS ARE 0 BASED. "Every loot index below is 0 based, running 0 to this
---     count minus 1" (.api/core.lua:1025), and core.input.loot_item / confirm_loot_slot
---     match it (:1849, :2123). Walking 1..count skips slot 0 and reads one past the end.
---  2. TAKING A SLOT COMPACTS THE WINDOW, so a captured list of slots goes stale. Walk
---     each pass DOWNWARD: removing a higher slot never shifts a lower one. The count is
---     re-read for the second pass for the same reason (vendor's sell loop does this too).
--- The set of slots looted does not depend on which way the window behaves, so both
--- callers see the same result either way.
--- @return boolean processed True when a loot window was open and has been emptied
--- @return integer slots The slot count read on entry (0 when no window was open)
function M.try_loot()
    local count_ok, count = pcall(_get_loot_item_count)
    if not count_ok or type(count) ~= "number" or count < 1 then
        return false, 0
    end

    -- Pass 1: gold (priority), classified against the live window, highest slot first
    for i = count - 1, 0, -1 do
        local is_gold_ok, is_gold = pcall(_get_loot_is_gold, i)
        if is_gold_ok and is_gold then
            pcall(_loot_item, i)
        end
    end

    -- Pass 2: item slots (gold is already gone), again highest slot first. A slot whose
    -- gold check fails is treated as an item, i.e. looted rather than left behind.
    local count2_ok, count2 = pcall(_get_loot_item_count)
    if count2_ok and type(count2) == "number" then
        for i = count2 - 1, 0, -1 do
            local is_gold_ok, is_gold = pcall(_get_loot_is_gold, i)
            if not (is_gold_ok and is_gold) then
                pcall(_loot_item, i)
            end
        end
    end

    -- A BoP slot is held open by a bind prompt: answer it and LEAVE THE WINDOW OPEN, so the
    -- next tick takes the item the client has just released. Closing here would drop it —
    -- the item never entered the bags, and the window taking it away is the only record.
    if answer_loot_bind_confirm() then
        return true, count
    end

    -- Close loot window after processing
    pcall(_close_loot)

    return true, count
end

-- ============================================================================
-- Internal: compute bag fullness percentage (0-100)
-- ============================================================================

--- The documented owner of the bag-slot pair and of the bag-space numbers:
--- "common/utility/inventory_helper.lua owns that conversion and is the supported way to get a
--- usable pair" (.api/core.lua:889-890). Cached on success only, so a build that loads the
--- mini-lib late still picks it up.
local _inv_helper = nil
local function get_inventory_helper()
    if _inv_helper then return _inv_helper end
    local ok, mod = pcall(require, "common/utility/inventory_helper")
    if ok and type(mod) == "table" then _inv_helper = mod end
    return _inv_helper
end

--- Bag capacity snapshot, read from the documented owner of those numbers.
---
--- The previous version paired core.inventory.get_items_in_bag(N) with
--- get_num_bag_slots(N), which the runtime docs call out as a silent mistake: the two bindings
--- are shifted by one ("the pairing you want is get_num_bag_slots(N) alongside
--- get_items_in_bag(N - 1). Passing the same number to both asks about two different bags and
--- the mistake is silent", :906-909), and get_num_bag_slots(0) fails an internal range guard
--- and answers 0 on every build (:923-929). get_items_in_bag(0) is not the backpack either —
--- it is the whole player container, equipped gear and the bag objects included, with the
--- backpack proper starting at BAG_1_REAL_START (:859-876) — so the used count carried worn
--- gear while the total was missing a bag. inventory_helper owns both numbers, and its
--- get_total_free_slots / get_total_bag_capacity / get_total_used_slots are the documented read.
--- Returns nil when the inventory cannot be read, so callers can tell
--- "unknown" apart from "known empty".
--- @return integer|nil free_slots
--- @return integer|nil total_slots
--- @return integer|nil used_slots
local function get_bag_space()
    local helper = get_inventory_helper()
    if not helper then return nil, nil, nil end

    local ok_free, free_slots = pcall(helper.get_total_free_slots, helper)
    local ok_total, total_slots = pcall(helper.get_total_bag_capacity, helper)
    if not ok_free or type(free_slots) ~= "number" then return nil, nil, nil end
    if not ok_total or type(total_slots) ~= "number" or total_slots <= 0 then return nil, nil, nil end
    if free_slots < 0 then free_slots = 0 end

    local ok_used, used_slots = pcall(helper.get_total_used_slots, helper)
    if not ok_used or type(used_slots) ~= "number" then
        used_slots = total_slots - free_slots
    end
    return free_slots, total_slots, used_slots
end

--- Internal: compute bag fullness percentage (0-100)
local function get_bag_fullness_pct()
    local _, total_slots, used_slots = get_bag_space()
    if not total_slots or total_slots <= 0 then return 0 end
    return math.floor((used_slots / total_slots) * 100)
end

-- ============================================================================
-- auto_loot_all — find and loot all nearby lootable objects
-- ============================================================================

--- Scan visible objects in range, open loot window for each, and loot contents.
--- Throttled to 0.5s between cycles via utils.throttle.
--- @param range number|nil Max distance in yards (default: 5). Uses squared distance internally.
--- @return boolean true if at least one lootable object was processed
function M.auto_loot_all(range)
    -- Throttle: 0.5s between full loot cycles
    if not ensure_utils() then return false end
    if not _utils.throttle("loot_cycle", 0.5) then return false end

    -- Check bag space — skip if nearly full (leave room for quest items).
    -- The old code called core.inventory.get_num_free_slots, which the runtime does
    -- not expose: pcall failed, the second return was the ERROR STRING, and
    -- `free_slots < 4` then threw "attempt to compare string with number" on every
    -- loot cycle. get_bag_space() returns nil when the inventory is unreadable, so
    -- an unknown bag state means "loot anyway" instead of a crash.
    local free_slots = get_bag_space()
    if free_slots and free_slots < 4 then
        _core_log("[EaxAutoQuester] Bags full — skipping loot")
        return false
    end

    local max_range = range or 5
    local max_range_sq = max_range * max_range

    local player_ok, player = pcall(_get_local_player)
    if not player_ok or not player then return false end

    local objects_ok, objects = pcall(_get_visible_objects)
    if not objects_ok or not objects then return false end

    -- Collect lootable objects into static table
    _t.n = 0

    for idx = 1, #objects do
        local obj = objects[idx]
        if obj then
            -- Check if object can be looted
            local can_loot_ok, can_loot = pcall(function() return obj:can_be_looted() end)
            if can_loot_ok and can_loot then
                -- Only an object proven NOT to be a unit is routed to use_object; a failed
                -- is_unit() keeps the object on loot_object, which is what it got before.
                local unit_ok, is_unit = pcall(function() return obj:is_unit() end)
                -- Check distance (squared, no math.sqrt — Pattern 3)
                local pos_ok, pos = pcall(function() return obj:get_position() end)
                if pos_ok and pos then
                    local _, player_pos = pcall(function() return player:get_position() end)
                    if not player_pos then break end
                    local dx = (pos.x or 0) - (player_pos.x or 0)
                    local dy = (pos.y or 0) - (player_pos.y or 0)
                    local dz = (pos.z or 0) - (player_pos.z or 0)
                    local dist_sq = dx * dx + dy * dy + dz * dz

                    if dist_sq <= max_range_sq then
                        _t.n = _t.n + 1
                        _t[_t.n] = obj
                        _t_is_container[_t.n] = (unit_ok and is_unit == false) or false
                    end
                end
            end
        end
    end

    if _t.n < 1 then return false end

    -- Process each lootable object. The opener is chosen per object because the two APIs are
    -- documented for different kinds: loot_object is "UNITS AND CORPSES ONLY. The native path
    -- rejects anything that is not a unit and answers false straight away, so a fishing
    -- bobber, chest, herb node or ore node cannot be looted through this" (.api/core.lua:2121),
    -- while use_object is "the entry point for world objects rather than units: fishing
    -- bobbers, chests, herb and ore nodes, mailboxes" (:2143). A chest handed to loot_object
    -- answered false, left the container shut, and was still counted as handled.
    for j = 1, _t.n do
        local obj = _t[j]
        local opener = _t_is_container[j] and _use_object or _loot_object
        local opened = opener and pcall(opener, obj)
        if opened then
            -- Process the loot window contents
            M.try_loot()
        end
    end

    -- Bag-fullness check: if bags >= 80% full after looting, trigger vendor run
    local fullness = get_bag_fullness_pct()
    if fullness >= 80 then
        local ns = _G.EaxAutoQuester
        if ns then
            ns._force_vendor_soon = true
            _core_log("[EaxAutoQuester] Bags " .. tostring(fullness) .. "% full — forcing vendor visit")
        end
    end

    return _t.n > 0
end

-- ============================================================================
-- close — close loot window if open
-- ============================================================================

--- Close the currently open loot window.
--- Nil-guarded via pcall.
function M.close()
    pcall(_close_loot)
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.loot_manager = M

return M
