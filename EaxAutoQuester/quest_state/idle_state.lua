-- What: IDLE state handler — evaluates Zygor step, detects frames, decides next state
-- When: Called by coordinator when shared._state == "IDLE"
-- Why: Centralize all IDLE logic including frame detection, HP/mana gates, distance checks
-- API: exports detect_open_frame() and run(shared, ctx) → next_state string

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

local corpse_loot = require("shared/corpse_loot")
local recovery = require("shared/recovery")
local goal_resolver_ok, goal_resolver = pcall(require, "goal_resolver_sylvanas")
local goal_filter_ok, goal_filter = pcall(require, "goal_filter_sylvanas")
-- Shared owners IDLE asks rather than reimplements:
--   objective_match  — "is this unit the goal's objective?" (ids first, whole names second)
--   nav_destination  — who owns where the bot walks next, incl. the pull gate's claim
--   spawn_patrol     — the spawn-point sweep a respawn wait walks
--   facing           — the one place that may issue a look-at lock
--   pull_safety      — is the bot allowed to start this fight at all (the hold)
local objective_match = require("shared/objective_match")
local nav_destination = require("shared/nav_destination")
local spawn_patrol = require("shared/spawn_patrol")
local facing = require("shared/facing")
local pull_safety = require("shared/pull_safety")

local _look_at = core.input.look_at
local _set_target = core.input.set_target
local _use_object = core.input.use_object

-- Every waypoint-like destination produced by IDLE goes through the same terrain-height owner.
-- The area sweep used to publish its step list raw: a z=0 waypoint could be treated as a valid point,
-- snap to an off-mesh location, arrive 13yd away, and then be retired as if the client had
-- refused the guide's real place. The handle is lazy and cached so the fixer is not required on
-- every tick and a missing optional module remains a no-op.
local _waypoint_fixer = nil
local _waypoint_fixer_failed = false
local function fix_destination_z(pos)
    if not pos then return pos end
    if not _waypoint_fixer and not _waypoint_fixer_failed then
        local ok, wf = pcall(require, "waypoint_fixer_sylvanas")
        if ok and wf then
            _waypoint_fixer = wf
        else
            _waypoint_fixer_failed = true
        end
    end
    if _waypoint_fixer and _waypoint_fixer.fix_z then
        local ok, fixed = pcall(_waypoint_fixer.fix_z, pos)
        if ok and fixed then return fixed, true end
    end
    return pos, false
end

-- Hoisted unit probes (perf pass): every one of these was an inline `pcall(function() ... end)`
-- on the tick path, which built a closure per call — the death check alone cost three per tick,
-- plus one per ghost-aura method it scanned. The probes are module-level, handed their unit as
-- the pcall argument, so the pcall protection and every return value are unchanged.
local function unit_is_dead(u) return u:is_dead() end
local function unit_get_health(u) return u:get_health() end
local function unit_aura_read(u, method) return u[method](u) end
local function unit_is_casting(u) return u:is_casting_spell() end
local function unit_is_channelling(u) return u:is_channelling_spell() end
local function unit_is_in_combat(u) return u:is_in_combat() end
local function unit_get_target(u) return u:get_target() end
local function unit_can_attack(u, other) return u:can_attack(other) end
local function unit_is_unit(u) return u:is_unit() end
local function unit_is_valid(u) return u:is_valid() end
local function unit_get_name(u) return u:get_name() end
local function unit_get_position(u) return u:get_position() end

-- Resolve transport against the live player context. Keeping the map and position at
-- the caller makes the locality contract explicit: the DB can rank local spawns, but
-- it never gets to choose a destination on another map.
local function find_current_transport(type_hint, ctx)
    local npc_db_ok, npc_db = pcall(require, "npc_db_sylvanas")
    if not npc_db_ok or not npc_db or not npc_db.find_transport_npc then return nil end

    local map_id = nil
    local map_ok, current_map = pcall(core.get_map_id)
    if map_ok then map_id = current_map end

    local player_pos = nil
    if ctx and ctx.me then
        local pos_ok, current_pos = pcall(unit_get_position, ctx.me)
        if pos_ok then player_pos = current_pos end
    end

    return npc_db.find_transport_npc(type_hint, map_id, player_pos)
end

-- (The movement_handler look-at/pause probes that used to live here are gone: shared/facing.lua
--  owns the look-at lock, and a second caller issuing its own was the spin it exists to stop.)

-- The ghost-aura method list was rebuilt as a table literal on every tick; it never changes.
local AURA_METHODS = { "get_buffs", "get_auras", "get_debuffs" }

-- Shared empty-goals default (perf pass): `ctx.safe(step.goals, {})` built a fresh table on every
-- tick in the two places below — the has-active-goal probe and the goal loop — which measured
-- 32.00 B each on the goal-evaluation path. `safe()` only ever RETURNS its default (it never
-- writes to it, coordinator.lua:127), and both call sites only iterate the result, so one shared
-- table is correct as well as cheaper.
local EMPTY_GOALS = {}

-- How long a goal whose targets are all corpses underfoot is left alone. Same value do_action_state
-- uses when the kill lane finds nothing to kill: one wait, two producers.
local RESPAWN_WAIT_SECONDS = 60

-- How long a covered pass over a movement-only step's waypoints is left alone before the sweep
-- starts another one. Without it a completed pass re-issued its whole path on the next tick.
local SWEEP_RELAP_SECONDS = 60

-- Reached-path memory (AQ-P4-6): the places this character has actually stood on during the
-- current client session. The sweep's `visited` marks are per-pass and nav_destination's
-- retirement is per-step, so ground the bot had already covered came back in full on the next
-- lap. This set is session-scoped and monotonic, so a later pass - or a later step that crosses
-- the same ground - walks only what has not been covered yet.
--
-- Keyed by PLACE, never by the slot the guide returned: the reader hands back a fresh table on
-- every tick, so a slot index says nothing about which piece of ground it names. The key is a
-- pair of rounded numeric coordinates rather than a formatted string, so the sweep's
-- per-candidate check allocates nothing on the tick path.
--
-- Session-only, exactly like the per-character profiles: the runtime has no file-write API, so
-- this dies with the client and claims nothing across a restart. Bounded so a long session
-- cannot grow it without limit; the oldest insertion is dropped first.
local REACHED_PLACE_LIMIT = 64
local _reached_seq = 0

--- Rounded x/y for a point, or nil when it carries no usable coordinates.
local function place_coords(point)
    if type(point) ~= "table" then return nil end
    local x, y = point.x, point.y
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    return math.floor(x * 10 + 0.5), math.floor(y * 10 + 0.5)
end

--- Whether the character has already stood on this place this session.
local function place_reached(shared, point)
    local cx, cy = place_coords(point)
    if not cx then return false end
    local set = shared._reached_places
    if not set then return false end
    local column = set[cx]
    return column ~= nil and column[cy] ~= nil
end

--- Record a place the character actually reached. True only the first time, so the caller logs
--- and records the event once instead of on every later pass over the same ground.
local function remember_reached_place(shared, point)
    local cx, cy = place_coords(point)
    if not cx then return false end
    local set = shared._reached_places
    if not set then
        set = {}
        shared._reached_places = set
    end
    local column = set[cx]
    if not column then
        column = {}
        set[cx] = column
    end
    if column[cy] ~= nil then return false end

    _reached_seq = _reached_seq + 1
    column[cy] = _reached_seq

    -- Bound the table. The lowest sequence number is the oldest insertion, and a column left
    -- empty by the eviction is dropped with it.
    local count, oldest_x, oldest_y, oldest_seq = 0, nil, nil, nil
    for x, entries in pairs(set) do
        for y, seq in pairs(entries) do
            count = count + 1
            if oldest_seq == nil or seq < oldest_seq then
                oldest_seq, oldest_x, oldest_y = seq, x, y
            end
        end
    end
    if count > REACHED_PLACE_LIMIT and oldest_x ~= nil then
        local evicted = set[oldest_x]
        evicted[oldest_y] = nil
        if next(evicted) == nil then set[oldest_x] = nil end
    end
    return true
end

-- Optional profession gathering is deliberately conservative: it runs only when the guide has
-- no active goal, scans a bounded nearby set, recognizes nodes by the names the client exposes,
-- and requires the character profile to enable that profession (detected once when the profile is
-- created, or set by hand). It never changes quest-object handling, combat, or the guide route.
local GATHER_SCAN_SECONDS = 1.0
local GATHER_SCAN_RANGE_SQ = 2500 -- 50yd
local GATHER_INTERACT_SQ = 25     -- 5yd
local GATHER_COOLDOWN_SECONDS = 2.0
local GATHER_SCAN_LIMIT = 50
-- Fallback free-slot reserve for gathering, used ONLY when the character profile owner cannot be
-- reached. The live value is the per-character slider `eaxaq_profile_gather_min_free_slots`; its
-- default matches the loot gate's "< 4 free slots" rule in loot_manager_sylvanas.auto_loot_all so
-- the two gates agree until the user moves this one.
local GATHER_MIN_FREE_SLOTS_FALLBACK = 4

-- How long the gathering route waits before asking for another vendor visit after one that freed
-- nothing. Selling is not guaranteed to free a slot (a bag of quest items sells nothing), so
-- without this a blocked route would request, walk to the vendor, sell nothing, and request again
-- on the very next blocked tick.
local GATHER_VENDOR_RETRY_SECONDS = 180
local GATHER_PROFESSION_KEYWORDS = {
    { key = "herbalism", words = {
        "herb", "bloom", "root", "mushroom", "plant", "flower", "vine", "lily", "lotus",
        "clover", "thistle", "shrub", "moss", "silverleaf", "golden sansa", "whispweed",
        "sonsing", "crimsoncap", "nightbloom", "starfall", "marsh lotus", "arrowhead", "briar",
    } },
    { key = "mining", words = {
        "ore", "vein", "deposit", "copper vein", "tin vein", "iron vein", "silver vein",
        "gold vein", "truesilver vein", "mithril deposit", "fel iron deposit", "thorium deposit",
        "cobalt deposit", "adamantite deposit", "indurium deposit",
    } },
    { key = "skinning", words = {
        "carcass", "hide", "pelt", "leather", "skinning",
    } },
    { key = "fishing", words = {
        "fish", "fishing", "bobber", "school",
    } },
}

local _character_profile = nil
local _character_profile_failed = false

--- The character profile owner, resolved once: a successful require is cached, a failure is
--- latched so a broken module cannot allocate an error string on every probe.
local function character_profile_module()
    if not _character_profile and not _character_profile_failed then
        local ok, profile = pcall(require, "character_profile_sylvanas")
        if ok and profile then
            _character_profile = profile
        else
            _character_profile_failed = true
        end
    end
    return _character_profile
end

local function profile_gathering_enabled(profession)
    local profile = character_profile_module()
    if profile and profile.gathering_enabled then
        local ok, enabled = pcall(profile.gathering_enabled, profession)
        if ok and enabled == true then return true end
    end
    return false
end

--- The free-slot reserve this character chose on their profile slider. Read only where the bag
--- gate actually runs, never per candidate.
local function profile_gather_min_free_slots()
    local profile = character_profile_module()
    if profile and profile.gather_min_free_slots then
        local ok, reserve = pcall(profile.gather_min_free_slots)
        if ok and type(reserve) == "number" and reserve >= 0 then return reserve end
    end
    return GATHER_MIN_FREE_SLOTS_FALLBACK
end

local function classify_gathering_name(name)
    if type(name) ~= "string" then return nil end
    local lower = name:lower()
    for i = 1, #GATHER_PROFESSION_KEYWORDS do
        local entry = GATHER_PROFESSION_KEYWORDS[i]
        for j = 1, #entry.words do
            if lower:find(entry.words[j], 1, true) then return entry.key end
        end
    end
    return nil
end

local function gathering_visible_objects(ctx)
    if ctx.object_scanner and ctx.object_scanner.get_visible_objects then
        local ok, objects = pcall(ctx.object_scanner.get_visible_objects)
        if ok and objects then return objects end
    end
    local ok, objects = pcall(core.object_manager.get_visible_objects)
    if ok and objects then return objects end
    return nil
end

-- Find the nearest visible non-unit object whose client name identifies an enabled profession.
-- The profile owner owns learned-profession detection; this scan only classifies the already
-- documented object name/position surface and never probes a profession API on the tick path.
local function find_gathering_target(ctx)
    if not ctx.me or not ctx.utils then return nil end
    local pos_ok, player_pos = pcall(unit_get_position, ctx.me)
    if not pos_ok or not player_pos then return nil end
    local objects = gathering_visible_objects(ctx)
    if not objects then return nil end

    local limit = #objects
    if limit > GATHER_SCAN_LIMIT then limit = GATHER_SCAN_LIMIT end
    local best, best_pos, best_name, best_profession, best_dist_sq
    for i = 1, limit do
        local obj = objects[i]
        if obj then
            local valid_ok, valid = pcall(unit_is_valid, obj)
            local unit_ok, is_unit = pcall(unit_is_unit, obj)
            if valid_ok and valid and unit_ok and not is_unit then
                local name_ok, name = pcall(unit_get_name, obj)
                local profession = name_ok and classify_gathering_name(name) or nil
                if profession and profile_gathering_enabled(profession) then
                    local opos_ok, opos = pcall(unit_get_position, obj)
                    if opos_ok and opos then
                        local dist_sq = ctx.utils.squared_distance(player_pos, opos)
                        if dist_sq <= GATHER_SCAN_RANGE_SQ
                            and (not best_dist_sq or dist_sq < best_dist_sq) then
                            best, best_pos, best_name = obj, opos, name
                            best_profession, best_dist_sq = profession, dist_sq
                        end
                    end
                end
            end
        end
    end
    return best, best_pos, best_name, best_profession, best_dist_sq
end

local function clear_gathering_target(shared)
    shared._gather_target = nil
    shared._gather_target_profession = nil
end

local function use_gathering_target(shared, ctx, obj, pos, name, profession)
    if _look_at then pcall(_look_at, pos) end
    if _set_target then pcall(_set_target, obj) end
    if _use_object then pcall(_use_object, obj) end
    clear_gathering_target(shared)
    nav_destination.clear(shared)
    shared._post_interact_timer = (ctx.now or 0) + 0.3
    shared._gather_cooldown = (ctx.now or 0) + GATHER_COOLDOWN_SECONDS
    ctx.debug_log("IDLE: gathering " .. tostring(name or "node") .. " [" .. tostring(profession) .. "] — used")
    return "IDLE"
end

--- The shared bag-space reader, resolved lazily once and only cached on success. The loot
--- manager owns the inventory-helper read (free/total/used); going through it keeps the loot
--- gate and the gather gate on the same numbers and the same reserve.
local _loot_manager = nil
local _loot_manager_failed = false

--- Free bag slots for the gathering reserve, or nil when the inventory cannot be read.
local function gather_free_slots()
    if not _loot_manager and not _loot_manager_failed then
        local ok, mod = pcall(require, "loot_manager_sylvanas")
        if ok and mod and type(mod.get_bag_space) == "function" then
            _loot_manager = mod
        else
            _loot_manager_failed = true
        end
    end
    if _loot_manager then
        local ok, free = pcall(_loot_manager.get_bag_space)
        if ok and type(free) == "number" and free >= 0 then return free end
    end
    return nil
end

--- Ask for a vendor visit because the gathering route has no room to work in. The force-vendor
--- flag is the existing routing owner: the coordinator walks to the vendor whenever the flag is
--- set while the state is IDLE, and vendor_manager.handle_vendor clears it after the visit. The
--- same flag also makes the vendor sell up to green, which is what actually frees the slots — so a
--- blocked route that has NOT tripped the fullness threshold still gets space freed. This is
--- idempotent (a pending visit is left alone) and paced by GATHER_VENDOR_RETRY_SECONDS so a visit
--- that freed nothing is not requested again immediately.
--- @return boolean requested true when the flag is set (pending or just raised)
local function request_vendor_for_space(shared, ctx, now, free, reserve)
    local ns = rawget(_G, "EaxAutoQuester")
    if type(ns) ~= "table" then return false end
    if ns._force_vendor_soon then return true end
    local last = shared._gather_vendor_request_at
    if type(last) == "number" and now - last < GATHER_VENDOR_RETRY_SECONDS then return false end
    shared._gather_vendor_request_at = now
    ns._force_vendor_soon = true
    -- The reason travels with the flag so the coordinator reports THIS cause rather than the
    -- fullness threshold, which is not what asked for the visit.
    ns._force_vendor_reason = "gathering blocked: " .. tostring(free) ..
        " free bag slot(s), reserve " .. tostring(reserve)
    ctx.debug_log("IDLE: gathering blocked — requesting a vendor visit (" ..
        tostring(free) .. " free, reserve " .. tostring(reserve) .. ")")
    return true
end

--- Decide whether the bag reserve blocks the gathering route, and if so what the caller should do.
--- Returns nil when the route may run, "IDLE" when a vendor visit is pending or was just raised
--- (the caller stays IDLE so the coordinator routes to the vendor on the flag), or true when the
--- route is blocked with no vendor request (the caller waits).
--- An in-progress target is abandoned (and its NAV destination cleared) so the bot does not keep
--- walking to a node it must not loot. A blocked check re-arms the scan clock so a full bag is
--- re-checked on the scan cadence, not every tick. A reserve of 0 is the slider's "off" position
--- and skips the inventory read entirely. An unreadable inventory (nil) does NOT block — that is
--- the established "unknown = proceed" policy of the loot gate, and the vendor threshold remains
--- the backstop.
local function bags_block_gathering(shared, ctx, now)
    local reserve = profile_gather_min_free_slots()
    if reserve <= 0 then return nil end
    local free = gather_free_slots()
    if not free or free >= reserve then return nil end
    if shared._gather_target then
        clear_gathering_target(shared)
        nav_destination.clear(shared)
        ctx.debug_log("IDLE: gathering stopped — " .. tostring(free) ..
            " free bag slot(s), this character reserves " .. tostring(reserve))
    end
    shared._gather_scan_at = now + GATHER_SCAN_SECONDS
    if request_vendor_for_space(shared, ctx, now, free, reserve) then return "IDLE" end
    return true
end

-- Run one optional gathering decision. The caller invokes this only when no quest goal is active.
local function run_gathering(shared, ctx)
    local now = ctx.now or 0
    if (shared._action_pause_timer or 0) > now
        or (shared._post_interact_timer or 0) > now
        or (shared._at_quest_object_timer or 0) > now then
        return nil
    end

    local target = shared._gather_target
    local profession = shared._gather_target_profession
    if target and (not profession or not profile_gathering_enabled(profession)) then
        clear_gathering_target(shared)
        target = nil
    end

    -- Inventory gate. Read only when a target is live or a new scan is due, so an idle bot
    -- without gathering work never touches the inventory; a blocked check re-arms the scan
    -- clock (see bags_block_gathering) so the read costs once per second, not once per tick.
    -- A block that raised (or found pending) a vendor visit returns "IDLE" so the coordinator's
    -- force-vendor route — which only fires while the state is IDLE — actually sends us to the
    -- vendor; a paced block just waits.
    local scan_due = (shared._gather_cooldown or 0) <= now and (shared._gather_scan_at or 0) <= now
    if target or scan_due then
        local blocked = bags_block_gathering(shared, ctx, now)
        if blocked == "IDLE" then return "IDLE" end
        if blocked then return nil end
    end

    if target then
        local valid_ok, valid = pcall(unit_is_valid, target)
        if not (valid_ok and valid) then
            clear_gathering_target(shared)
            target = nil
        else
            local pos_ok, pos = pcall(unit_get_position, target)
            if not pos_ok or not pos then
                clear_gathering_target(shared)
                return "IDLE"
            end
            local player_ok, player_pos = pcall(unit_get_position, ctx.me)
            if player_ok and player_pos and ctx.utils then
                local dist_sq = ctx.utils.squared_distance(player_pos, pos)
                if dist_sq > GATHER_INTERACT_SQ then
                    nav_destination.point(shared, pos)
                    return "NAV"
                end
                local name_ok, name = pcall(unit_get_name, target)
                return use_gathering_target(shared, ctx, target, pos,
                    name_ok and name or "node", profession)
            end
            clear_gathering_target(shared)
            return "IDLE"
        end
    end

    if (shared._gather_cooldown or 0) > now then return nil end
    if (shared._gather_scan_at or 0) > now then return nil end
    shared._gather_scan_at = now + GATHER_SCAN_SECONDS

    local obj, pos, name, found_profession, dist_sq = find_gathering_target(ctx)
    if not obj then return nil end
    if dist_sq <= GATHER_INTERACT_SQ then
        return use_gathering_target(shared, ctx, obj, pos, name, found_profession)
    end
    shared._gather_target = obj
    shared._gather_target_profession = found_profession
    nav_destination.point(shared, pos)
    ctx.debug_log("IDLE: gathering " .. tostring(name or "node") .. " [" .. tostring(found_profession) ..
        "] — NAV")
    return "NAV"
end

-- ============================================================================
-- Frame Detection — lightweight probe without handling
-- Used by IDLE state to detect open UI frames before transitioning to INTERACT
-- Also used by INTERACT state (via ctx.detect_open_frame) to check if frame closed
-- ============================================================================

--- Check if any UI frame (loot, gossip, quest detail, trainer, vendor) is open.
--- @return boolean true if any frame is open
function M.detect_open_frame()
    -- Loot frame: check item count
    local ok, loot_count = pcall(core.game_ui.get_loot_item_count)
    if ok and loot_count and loot_count > 0 then return true end

    -- Gossip frame: check if gossip is shown
    local ok2, gossip = pcall(core.quests.is_gossip_frame_shown)
    if ok2 and gossip then return true end

    -- Quest detail/reward frame: probe reward link
    local ok3, link = pcall(core.quests.get_quest_item_link, "choice", 1)
    if ok3 and link and link ~= "" then return true end

    -- Also check for reward money (alternative quest frame indicator)
    local ok3b, reward_money = pcall(core.quests.get_reward_money)
    if ok3b and reward_money and reward_money > 0 then return true end

    -- Trainer frame: check service count
    local ok4, num = pcall(core.quests.get_num_trainer_services)
    if ok4 and num and num > 0 then return true end

    -- Vendor frame: check vendor item count
    local ok5, vendor = pcall(core.game_ui.get_vendor_item_count)
    if ok5 and vendor and vendor > 0 then return true end

    return false
end

-- ============================================================================
-- State: IDLE — Evaluate current Zygor step and decide next state
-- ============================================================================

--- Read Zygor step info and determine transition.
--- Transitions: WAITING (no step), INTERACT (open frame),
---              NAV (waypoint far), DO_ACTION (goal at position)
--- @param shared table Shared state variables
--- @param ctx table Per-tick context with submodules, me, helpers
--- @return string next_state
function M.run(shared, ctx)
    -- Death check FIRST — before the guidance/step gate. A dead or ghosted
    -- player must enter DEAD even when there is no current step, or Zygor is
    -- absent entirely; otherwise the machine parks in WAITING and the corpse
    -- run never starts. (The retired monolith also checked death before its
    -- guidance logic.)
    -- Checks is_dead() AND HP. Handles ghost-form: ghost players have
    -- is_dead()=false but get_health() returns nil (no body, no health).
    -- The old logic missed ghost-form deaths because `hp and hp <= 0`
    -- is false when hp is nil. Now: is_dead() OR HP<=0 OR HP=nil OR
    -- get_health() throws → DEAD. Live bug: bot stuck in IDLE for 100+
    -- ticks after dying (ghost form), spamming "HP low (0%) — waiting for
    -- regen" instead of navigating to corpse.
    if ctx.me then
        local dead = false
        local is_dead_v = nil
        local hp_v = nil
        local buff_api = "none"
        local ghost_found = false

        if ctx.me.is_dead then
            local ok, result = pcall(unit_is_dead, ctx.me)
            is_dead_v = (ok and tostring(result)) or "err"
            if ok and result then dead = true end
        end

        if not dead then
            local hp_ok, hp = pcall(unit_get_health, ctx.me)
            hp_v = (hp_ok and tostring(hp)) or "err"
            if hp_ok then
                if hp == nil or hp <= 0 then dead = true end
            else
                dead = true
            end
        end

        if not dead then
            for _, m in ipairs(AURA_METHODS) do
                if ctx.me[m] then
                    local ok, data = pcall(unit_aura_read, ctx.me, m)
                    if ok and data then
                        for i = 1, #data do
                            local b = data[i]
                            if b then
                                local id = b.buff_id or b.id or b.spell_id or b.aura_id or "?"
                                if id == 8326 or id == "8326" then
                                    ghost_found = true
                                    dead = true
                                    buff_api = m
                                end
                            end
                        end
                    end
                end
            end
        end

        if dead then
            ctx.debug_log("IDLE: player dead → DEAD")
            return "DEAD"
        end
    end

    local zygor = ctx.zygor
    if not zygor then
        ctx.debug_log("IDLE: Zygor not available → WAITING")
        return "WAITING"
    end

    -- No active step → WAITING
    if not zygor.has_current_step() then
        ctx.debug_log("IDLE: no step → WAITING")
        return "WAITING"
    end

    -- Cast/channel pause: if the player is mid-cast or mid-channel (e.g. after
    -- clicking a gathering node like "Milly's Harvest"), the bot must stay in
    -- IDLE and NOT move, re-target, or re-interact. Any of those would cancel
    -- the cast/channel and break the quest. Live observed: Milly's Harvest
    -- pumpkins in Northshire Valley require a 2-3s channel to gather the
    -- quest item. Re-targeting the pumpkin cancels the channel and the quest
    -- never progresses.
    if ctx.me then
        local casting_ok, is_casting = pcall(unit_is_casting, ctx.me)
        local channelling_ok, is_channelling = pcall(unit_is_channelling, ctx.me)
        if (casting_ok and is_casting) or (channelling_ok and is_channelling) then
            return "IDLE"
        end
    end

    -- Combat check first: if in combat, skip frame handling
    local in_combat = false
    if ctx.me then
        local ok, combat = pcall(unit_is_in_combat, ctx.me)
        in_combat = ok and combat == true
    end
    if in_combat then
        local nav = ctx.nav
        if nav and nav.is_navigating and nav.is_navigating() then
            nav.stop()
            ctx.debug_log("IDLE: combat — stopped navigation")
        end
        shared._interact_cooldown = 0
        if ctx.me then
            local target = nil
            local _, t = pcall(unit_get_target, ctx.me)
            if t then target = t end
            if target then
                -- Close distance if enemy is attacking from range (prevents desync death)
                local ok_att, can_att = pcall(unit_can_attack, target, ctx.me)
                if ok_att and can_att then
                    local _, me_pos = pcall(unit_get_position, ctx.me)
                    local _, t_pos = pcall(unit_get_position, target)
                    if me_pos and t_pos and ctx.utils then
                        local d_sq = ctx.utils.squared_distance(me_pos, t_pos)
                        if d_sq > 100 then  -- 10 yards squared
                            nav_destination.point(shared, t_pos)
                            ctx.debug_log("IDLE: combat — closing distance to enemy (" .. tostring(math.floor(math.sqrt(d_sq))) .. "yd)")
                            return "NAV"
                        end
                    end
                end
                -- Face the enemy through the single owner of facing (shared/facing.lua): one lock
                -- per interval, never at a corpse, and no second writer of the movement handler's
                -- look-at. This used to be an inline pause+look_at every tick, which is the spin.
                facing.ensure(ctx.me, target)
            end
        end
        return "IDLE"
    end
    shared._last_target_valid = false

    -- Pull-safety hold: the gate refused a pull and armed a back-off. IDLE must not undo that by
    -- walking at the mob on the next tick, and when the player is still standing where the refusal
    -- happened it walks the retreat out. `nav_destination.claim` is what applies the gate's intent —
    -- the gate writes no navigation field — and settling it HERE is what stops a destination written
    -- later in the same tick from winning the walk.
    if ctx.me and pull_safety.holding(ctx) then
        if not nav_destination.claim(shared, ctx) then
            -- Holding with nowhere published to back off to: wait the hold out rather than walk on.
            -- Standing still is standing still: the same recovery licence as the parked path below.
            if recovery.tick(ctx, shared) then
                ctx.debug_log("IDLE: pull safety hold — no retreat, recovering")
                return "IDLE"
            end
            ctx.debug_log("IDLE: pull safety hold — no retreat published, waiting")
            return "IDLE"
        end
        local point = shared._nav_destination
        local pos_ok, pos = pcall(unit_get_position, ctx.me)
        if not (pos_ok and pos and point and ctx.utils) then
            ctx.debug_log("IDLE: pull safety hold — cannot measure the retreat, waiting")
            return "IDLE"
        end
        if ctx.utils.squared_distance(pos, point) <= 25 then
            -- Parked: the recovery half of the gate's promise. While the hold runs and the bot
            -- stands at its retreat, a bar below its LOW floor is an eat/drink pause (see
            -- shared/recovery.lua for the floors and the cap) — not a stare at the regen bar,
            -- and never the "wait until high %" that killed the old regen wait.
            if recovery.tick(ctx, shared) then
                ctx.debug_log("IDLE: pull safety hold — parked, recovering")
                return "IDLE"
            end
            ctx.debug_log("IDLE: pull safety hold — parked at the retreat")
            return "IDLE"
        end
        ctx.debug_log("IDLE: pull safety hold — walking the retreat out")
        return "NAV"
    end

    -- Check for an active quest goal early — determines autoloot behavior.
    -- When a quest is active, the bot should only loot corpses it passes by
    -- (within 5yd), not chase distant corpses. Chasing distant corpses while a
    -- quest is active causes loops: loot corpse A → approach quest → find corpse
    -- B → loot B → approach quest → find corpse C → ... (live observed with
    -- Milly's Harvest goal in Northshire Valley).
    local has_active_goal = false
    do
        local zygor = ctx.zygor
        if zygor and zygor.has_current_step and zygor.has_current_step() then
            local step = zygor.get_current_step_info and zygor.get_current_step_info()
            if step and not step.is_complete then
                local goals = ctx.safe(step.goals, EMPTY_GOALS)
                for i = 1, #goals do
                    local g = goals[i]
                    local complete = false
                    if type(g) == "table" then
                        complete = ctx.safe(g.is_complete, false)
                    end
                    if not complete then
                        has_active_goal = true
                        break
                    end
                end
            end
        end
    end

    -- Autoloot: check for nearby corpses (up to 20yd). Even with an active quest,
    -- auto-loot corpses that are close by. The "stay near quest object" flag
    -- (shared._at_quest_object_timer) prevents deviation from just-clicked quest
    -- objects, so autoloot NAV won't fight the quest objective.
    if not in_combat then
        local result = corpse_loot.try_loot_nearest_corpse(shared, ctx, 400, "[autoloot]")
        if result then return result end
    end

    -- Open UI frame → INTERACT (detect without handling)
    -- Skip if cooldown active (prevents immediate re-entry after timeout)
    if shared._interact_cooldown > 0 then
        if ctx.now < shared._interact_cooldown then
            -- throttle log to once per 5s
            if (not shared._last_cooldown_log) or ctx.now - shared._last_cooldown_log > 5.0 then
                shared._last_cooldown_log = ctx.now
                ctx.debug_log("IDLE: frame cooldown active (" .. tostring(math.floor(shared._interact_cooldown - ctx.now)) .. "s left)")
            end
        else
            shared._interact_cooldown = 0
        end
    elseif ctx.detect_open_frame() or ctx.frame_signalled then
        -- The polling probe, or a quest frame the client announced with a game event
        -- (GOSSIP_SHOW / QUEST_DETAIL / QUEST_PROGRESS / QUEST_COMPLETE / QUEST_GREETING).
        -- The event adds an entry reason only; the polling probe remains the exit check in
        -- INTERACT, so a frame that has closed is still left.
        ctx.debug_log("IDLE: open frame detected → INTERACT")
        return "INTERACT"
    end

    -- Get current step info
    local step = zygor.get_current_step_info()
    if not step then
        ctx.debug_log("IDLE: nil step info → WAITING")
        return "WAITING"
    end

    -- Step already complete → optionally gather, otherwise WAITING (wait for next step)
    if step.is_complete then
        shared._respawn_wait_until = 0
        shared._respawn_target_name = nil
        local gathering_result = run_gathering(shared, ctx)
        if gathering_result then return gathering_result end
        ctx.debug_log("IDLE: step complete → WAITING")
        return "WAITING"
    end

    -- Track step number changes — reset retries on step transition
    local step_num = ctx.safe(step.step_num, 0)
    if step_num ~= shared._last_step_num then
        shared._last_step_num = step_num
        shared._nav_retries = 0
        shared._last_goal_type = nil
        shared._area_fail_count = 0
        shared._area_last_target_guid = nil
        shared._visited_waypoints = {}
        shared._area_waypoint_fixes = {}
        shared._gather_target = nil
        shared._gather_target_profession = nil
        shared._gather_scan_at = 0
        shared._gather_cooldown = 0
        -- A new step is a new path: a waypoint of the old one that the client could not reach says
        -- nothing about the new one, and the sweep starts from scratch (cleared through the owner,
        -- so the retirement stays one field).
        nav_destination.clear_retired(shared)
        shared._sweep_lap_at = 0
        shared._respawn_wait_until = 0
        shared._respawn_target_name = nil
        -- Reset progress tracking on step change
        do
            local pt_ok, pt = pcall(require, "progress_tracker_sylvanas")
            if pt_ok and pt and pt.clear_all then pt.clear_all() end
        end
        ctx.debug_log("IDLE: new step " .. tostring(step_num))
    end

    -- Find first uncompleted goal
    local goals = ctx.safe(step.goals, EMPTY_GOALS)
    local current_goal = nil

    for i = 1, #goals do
        local g = goals[i]
        local complete = false
        if type(g) == "table" then
            complete = ctx.safe(g.is_complete, false)
        end
        if not complete then
            -- Item C: class/level/faction filter
            local passes = true
            if goal_filter_ok and goal_filter and goal_filter.passes then
                local ok, result = pcall(goal_filter.passes, g, ctx.me, nil, step)
                if ok then passes = result end
            end
            if passes then
                current_goal = g
                break
            end
        end
    end

    -- Debug: log current goal details. Guarded by the debug flag (perf pass): the concatenation
    -- builds a string on every tick and `debug_log` then discards it when debug is off, which is
    -- the normal case (0.34 B/tick measured even for a short message). Same output when on.
    -- Logged on a CHANGE, not on every tick: the pause DO_ACTION arms holds this line for seconds
    -- at a time, and ~40 identical lines a second buried the decisions that were being debugged
    -- (live: the "Ogre Remains" step, where the id could not be read and the flood hid it).
    if shared._debug and current_goal and type(current_goal) == "table" then
        if shared._debug_goal_step ~= step_num or shared._debug_goal ~= current_goal then
            shared._debug_goal_step = step_num
            shared._debug_goal = current_goal
            local g_text = tostring(current_goal.text or current_goal.name or "nil")
            -- objective_match.goal_id reads every spelling the goal carries its id in (npc_id,
            -- target_id, targetid, id, the {name,id} pairs). `current_goal.npc_id or
            -- current_goal.target_id` printed 0 for a goal whose id lives in `targetid`, because 0
            -- is truthy in Lua — the log said the step had no identity when it had one.
            local g_npc = tostring(objective_match.goal_id(current_goal) or "nil")
            local g_target = tostring(current_goal.target or current_goal.npc or "nil")
            ctx.debug_log("IDLE: goal[" .. tostring(step_num) .. "] text=" .. g_text .. " npc_id=" .. g_npc .. " target=" .. g_target)
        end
    end

    -- Low HP / Mana pause: DISABLED. The user reported the HP check was
    -- preventing the bot from dying naturally — at 76% HP, the bot would
    -- wait for regen instead of fighting, and could never reach the
    -- death state. The death check at the top of this function handles
    -- the 0% case. Now the bot fights at any HP/mana level. Disabled
    -- via `if false and ...` so the original logic is preserved as a
    -- reference but never executes.
    if false and ctx.me then
        local hp_ok, hp_pct = pcall(function()
            local max_hp = ctx.me:get_max_health()
            local cur_hp = ctx.me:get_health()
            if max_hp and max_hp > 0 and cur_hp then
                return (cur_hp / max_hp) * 100
            end
            return 100
        end)
        if hp_ok and hp_pct and hp_pct < 80 then
            if (not shared._last_hp_warning) or ctx.now - shared._last_hp_warning > 5.0 then
                shared._last_hp_warning = ctx.now
                if hp_pct == 0 then
                    ctx.debug_log("IDLE: player dead — waiting for resurrection")
                else
                    ctx.debug_log("IDLE: HP low (" .. math.floor(hp_pct) .. "%) — waiting for regen")
                end
                local ns = _G.EaxAutoQuester
                if ns and ns.set_warning then
                    ns.set_warning("HP low (" .. math.floor(hp_pct) .. "%) - waiting", 4.0)
                end
            end
            return "IDLE"
        end

        -- Mana check: wait until > 80% (use power type 0 = MANA)
        local mana_ok, mana_pct = pcall(function()
            local max_mp = ctx.me:get_max_power(0)
            local cur_mp = ctx.me:get_power(0)
            if max_mp and max_mp > 0 and cur_mp then
                return (cur_mp / max_mp) * 100
            end
            return nil
        end)
        if mana_ok and mana_pct and mana_pct < 80 then
            if (not shared._last_mana_warning) or ctx.now - shared._last_mana_warning > 5.0 then
                shared._last_mana_warning = ctx.now
                ctx.debug_log("IDLE: Mana low (" .. math.floor(mana_pct) .. "%) — waiting for regen")
            end
            return "IDLE"
        end
    end

    -- Post-interact pause: after clicking a quest object (set by DO_ACTION),
    -- stay in IDLE briefly (0.3s) for the server round-trip before the next
    -- state evaluation. Longer interaction waits (gather channel, etc.) are
    -- handled by the cast/channel pause at the top of this function.
    if shared._post_interact_timer and shared._post_interact_timer > ctx.now then
        return "IDLE"
    end

    -- "At quest object" flag: after clicking a quest object, for 30s the bot
    -- ignores the waypoint distance check. This prevents the back-and-forth
    -- loop (click → NAV to waypoint → NAV back → click) that occurred when
    -- the waypoint check fired immediately after the click. The bot commits
    -- to the quest object for 30s, giving the interaction time to complete
    -- (gather channel, server round-trip, etc.). After 30s, if the quest
    -- still hasn't progressed, the click genuinely failed and the bot will
    -- try again.
    if shared._at_quest_object_timer and shared._at_quest_object_timer > ctx.now then
        return "IDLE"
    end

    -- Flight path step detection: if step says "Fly to X", find nearest
    -- flight master and navigate there instead of the normal waypoint.
    do
        local fp_ok, fp = pcall(require, "flight_path_sylvanas")
        if fp_ok and fp and step and step.text then
            local dest = fp.extract_destination(step.text)
            if dest then
                local fm = find_current_transport("flight", ctx)
                if fm then
                    fm = fix_destination_z(fm)
                    -- Straight to the destination record: the `wp` local is declared much
                    -- further down this function, so this used to write and read a global
                    -- `wp` (a leak that also collided with any sibling plugin using the name).
                    ctx.debug_log("IDLE: flight step to " .. dest .. " → NAV to flight master " .. tostring(fm.name or "?"))
                    nav_destination.point(shared, fm)
                    return "NAV"
                end
            end
        end
    end

    -- Hearth-set step detection: if step says "Set your Hearthstone to X",
    -- find nearest innkeeper and navigate there.
    do
        local svc_ok, svc = pcall(require, "service_gossip_sylvanas")
        if svc_ok and svc and step and step.text and svc.step_requires_hearth(step.text) then
            local inn = find_current_transport("inn", ctx)
            if inn then
                inn = fix_destination_z(inn)
                ctx.debug_log("IDLE: hearth-set step → NAV to innkeeper " .. tostring(inn.name or "?"))
                nav_destination.point(shared, inn)
                return "NAV"
            end
        end
    end

    -- Respawn wait: if DO_ACTION set a respawn timer, stay near the spawn
    -- point and periodically scan.  Prevents 100fps spam-scans and stuck loops.
    if shared._respawn_wait_until > ctx.now then
        -- Scan every 5 seconds for early respawn. Everything the wait says, it says here: the live
        -- log had "waiting for respawn" four times a second for minutes because the line was outside
        -- the throttle, which is a per-tick concatenation to be discarded.
        local scanned = false
        if ctx.now - (shared._respawn_last_scan or 0) >= 5.0 then
            shared._respawn_last_scan = ctx.now
            scanned = true
            local npc = ctx.npc_manager
            if npc and npc.get_nearest_enemy then
                local enemy = npc.get_nearest_enemy(50, ctx.object_scanner)
                if enemy then
                    shared._respawn_wait_until = 0
                    shared._respawn_target_name = nil
                    ctx.debug_log("IDLE: respawn detected — resuming")
                    return "DO_ACTION"
                end
            end
            -- The enemy probe answers only for attackable hostiles, and it reads one list: a mob
            -- that has come back is the thing being waited for even when that probe is blind to it.
            -- Identity decides — the goal's OWN mobs, never a lookalike under a longer name (live:
            -- waiting on Rock Elemental 92 while killing Lesser Rock Elementals).
            if npc and npc.find_interactable_objects and type(current_goal) == "table" then
                local probe = ctx.safe(current_goal.target, ctx.safe(current_goal.npc, nil))
                if probe and probe ~= "" then
                    local objects = npc.find_interactable_objects(probe, ctx.object_scanner)
                    local matches = objects and objective_match.only(current_goal, objects)
                    for i = 1, #(matches or EMPTY_GOALS) do
                        local ok_dead, dead = pcall(unit_is_dead, matches[i])
                        if not (ok_dead and dead == true) then
                            shared._respawn_wait_until = 0
                            shared._respawn_target_name = nil
                            ctx.debug_log("IDLE: respawn detected — resuming")
                            return "DO_ACTION"
                        end
                    end
                end
            end
        end
        -- The wait is a SEARCH, not a park: it walks the goal mob's own spawn points instead of
        -- standing at one of them. Live, the wait sat at a single point for twelve minutes while
        -- the mob's other seventeen spawns (from the shipped cAoNGOS index) were outside its only
        -- sensor — a 50yd enemy probe fired every 5s. shared/spawn_patrol.lua owns the sweep, and
        -- returns nil while the pull gate holds, so a refused camp is never searched.
        local leg = spawn_patrol.next_point(shared, ctx, current_goal)
        if leg then
            nav_destination.point(shared, leg)
            if scanned then
                ctx.debug_log("IDLE: respawn wait — walking the camp's spawn points")
            end
            return "NAV"
        end
        if scanned then
            ctx.debug_log("IDLE: waiting for respawn" .. (shared._respawn_target_name and " (" .. shared._respawn_target_name .. ")" or ""))
        end
        return "IDLE"
    elseif shared._respawn_wait_until > 0 and shared._respawn_wait_until <= ctx.now then
        -- Timer expired — retry
        shared._respawn_wait_until = 0
        shared._respawn_target_name = nil
        ctx.debug_log("IDLE: respawn wait expired — retrying objective")
    end

    -- Determine if player needs to move to goal position first
    local wp = zygor.get_current_waypoint_world()

    -- Item A: goal_resolver integration - use NPC DB position if available
    if current_goal and goal_resolver_ok and goal_resolver and goal_resolver.resolve_goal then
        local ok, res = pcall(goal_resolver.resolve_goal, current_goal, step_num, ctx.me)
        if ok and res and res.position then
            wp = res.position
            ctx.debug_log("IDLE: using resolved position from " .. tostring(res.source))
        end
    end

    -- Fix the final destination after goal resolution, not only the reader's original waypoint:
    -- a resolver position is another producer and must obey the same terrain contract.
    wp = fix_destination_z(wp)

    -- Z sanity check: if destination Z is 0 (likely underground) and player is
    -- at a non-zero Z, the waypoint is probably broken. Use player Z as fallback.
    -- This is a last-chance guard before navigation; waypoint_fixer already
    -- attempted terrain-height correction, but raycasts can still return 0.
    if wp and (wp.z or 0) == 0 then
        local me_ok, me = pcall(core.object_manager.get_local_player)
        if me_ok and me then
            local pos_ok, me_pos = pcall(me.get_position, me)
            if pos_ok and me_pos and me_pos.z and math.abs(me_pos.z) > 5 then
                wp = { x = wp.x, y = wp.y, z = me_pos.z }
                ctx.debug_log("IDLE: waypoint Z was 0, using player Z fallback")
            end
        end
    end

    if current_goal then
        -- Goal found — determine action type
        local action_type = "area"
        if type(current_goal) == "table" then
            action_type = ctx.safe(current_goal.type, ctx.safe(current_goal.action_type, "area"))
        end
        shared._last_goal_type = action_type

        if shared._nav_destination and ctx.me then
            local pos_ok, pos = pcall(function() return ctx.me:get_position() end)
            if pos_ok and pos and ctx.utils then
                local dist_sq = ctx.utils.squared_distance(pos, shared._nav_destination)
                if dist_sq > 25 then
                    ctx.debug_log("IDLE: goal type=" .. action_type .. ", approaching target → NAV")
                    return "NAV"
                end
            end
            nav_destination.point(shared, nil)
        end

        -- Objective-first scan (ported from the monolith's live IDLE path; see
        -- docs/phase1_port_list.md item 1). When the goal names an interactable,
        -- look for it within 50yd BEFORE walking to the step waypoint. In range
        -- (<= 5yd) the waypoint check below is skipped entirely: navigating to a
        -- destination the player is already standing on spins
        -- IDLE->NAV->ARRIVED->IDLE forever, because SentinelNavClient resolves it
        -- instantly and this block re-fires every tick.
        local objective_in_range = false
        -- What the scan saw, for the goal-type branches below: a goal whose only matches are corpses
        -- underfoot is a respawn wait, and a live match is the objective itself.
        local corpse_underfoot = false
        local living_match = false
        if type(current_goal) == "table" and ctx.me and ctx.npc_manager
            and ctx.npc_manager.find_interactable_objects then
            local goal_target = ctx.safe(current_goal.target, ctx.safe(current_goal.npc, nil))
            if goal_target and goal_target ~= "" then
                -- Zygor pluralizes names ("Bundles of Wood"), so try the singular
                -- of the first word and of the whole string too.
                local names_to_try = {}
                for name in goal_target:gmatch("[^,]+") do
                    local trimmed = name:match("^%s*(.-)%s*$")
                    if trimmed and trimmed ~= "" then
                        names_to_try[#names_to_try + 1] = trimmed
                    end
                end
                local name_count = #names_to_try
                for i = 1, name_count do
                    local name = names_to_try[i]
                    local first_word = name:match("^(%S+)")
                    if first_word and first_word:sub(-1) == "s" then
                        names_to_try[#names_to_try + 1] =
                            name:gsub("^" .. first_word, first_word:sub(1, -2), 1)
                    end
                    if name:sub(-1) == "s" then
                        local singular = name:sub(1, -2)
                        if singular ~= "" then
                            names_to_try[#names_to_try + 1] = singular
                        end
                    end
                end

                local pos_ok, pos = pcall(unit_get_position, ctx.me)
                local best_obj = nil
                local best_dist_sq = 2500  -- 50yd squared
                if pos_ok and pos and ctx.utils then
                    for _, name in ipairs(names_to_try) do
                        local objects = ctx.npc_manager.find_interactable_objects(name, ctx.object_scanner)
                        if objects then
                            -- IDENTITY, not similarity: the name lookup is a substring match, so
                            -- "Lesser Rock Elemental" answers for "Rock Elemental". The scan must
                            -- not call a lookalike "my objective", and it must not act on a corpse:
                            -- a dead match underfoot used to report the objective "in range (0yd)"
                            -- forever while the bot stood in the corpse pile it had just made.
                            local matches = objective_match.only(current_goal, objects)
                            if matches then
                                for i = 1, #matches do
                                    local obj = matches[i]
                                    local ok_opos, opos = pcall(unit_get_position, obj)
                                    if ok_opos and opos then
                                        local dsq = ctx.utils.squared_distance(pos, opos)
                                        local ok_dead, dead = pcall(unit_is_dead, obj)
                                        dead = ok_dead and dead == true
                                        if dead then
                                            if dsq <= 100 then corpse_underfoot = true end
                                        else
                                            living_match = true
                                            if dsq < best_dist_sq then
                                                best_dist_sq = dsq
                                                best_obj = obj
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if best_obj then
                    local ok_opos, opos = pcall(unit_get_position, best_obj)
                    if ok_opos and opos then
                        -- Game objects often report z=0, which is off the navmesh;
                        -- fall back to the player's own Z.
                        if (opos.z or 0) == 0 and pos and pos.z then
                            opos = { x = opos.x, y = opos.y, z = pos.z }
                        end
                        -- Hostile objectives keep combat_helper's class band (28yd for a
                        -- caster, 3yd for melee). Friendly units and game objects keep
                        -- the fixed 5yd interaction gate instead: a caster's combat band
                        -- must not make a friendly quest object look ready for DO_ACTION.
                        local is_hostile = false
                        local ok_unit, is_unit = pcall(unit_is_unit, best_obj)
                        if ok_unit and is_unit then
                            local ok_attack, can_attack = pcall(unit_can_attack, best_obj, ctx.me)
                            is_hostile = ok_attack and can_attack == true
                        end
                        local in_range_sq = 25
                        if is_hostile then
                            local ch = ctx.combat_helper
                            if ch and ch.engage_distance_sq then
                                local ok_band, band = pcall(ch.engage_distance_sq, ctx.me)
                                if ok_band and type(band) == "number" and band > 0 then
                                    in_range_sq = band
                                end
                            end
                        end
                        if best_dist_sq <= in_range_sq then
                            objective_in_range = true
                            ctx.debug_log("IDLE: objective-first '" .. tostring(goal_target) ..
                                "' in range (" .. tostring(math.floor(math.sqrt(best_dist_sq))) ..
                                "yd) - skip NAV")
                        else
                            -- Preserve the existing NAV stand-off mechanism. For a friendly
                            -- objective in_range_sq is now the fixed 25 squared (5yd), not
                            -- the caster's combat band; hostiles keep their combat stand-off.
                            nav_destination.engage(shared, nil, opos,
                                in_range_sq > 9 and in_range_sq or nil)
                            ctx.debug_log("IDLE: objective-first '" .. tostring(goal_target) ..
                                "' found at " .. tostring(math.floor(math.sqrt(best_dist_sq))) .. "yd -> NAV")
                            return "NAV"
                        end
                    end
                end
            end
        end

        -- Check distance to waypoint using :get_position() (game_object has no .x/.y)
        -- Skip check if we just arrived (tolerance mismatch with navigator) or if
        -- the objective is already in interaction range.
        if not objective_in_range and not shared._just_arrived and wp and ctx.me then
            local pos_ok, pos = pcall(function() return ctx.me:get_position() end)
            if pos_ok and pos and ctx.utils then
                local dist_sq = ctx.utils.squared_distance(pos, wp)
                if dist_sq > 1600 then
                    nav_destination.point(shared, wp)
                    ctx.debug_log("IDLE: goal type=" .. action_type .. ", far from wp → NAV")
                    return "NAV"
                end
            end
        end
        shared._just_arrived = false

        -- Player at position (or no waypoint) — execute action
        if action_type == "area" and shared._area_wait_timer > 0 and ctx.now < shared._area_wait_timer then
            ctx.debug_log("IDLE: area wait active, staying in IDLE")
            return "IDLE"
        end
        -- Movement-only area goal: no target to interact with, just need to be here.
        -- Use Zygor step waypoints to walk through them sequentially.
        if action_type == "area" then
            local has_target = false
            if type(current_goal) == "table" then
                local npc_id = ctx.safe(current_goal.npc_id, 0)
                local target = ctx.safe(current_goal.target, "")
                local text = ctx.safe(current_goal.text, "")
                if npc_id and npc_id ~= 0 then has_target = true end
                if target and target ~= "" then has_target = true end
                if text and text ~= "" then has_target = true end
            end
            if has_target and corpse_underfoot and not living_match then
                -- Everything this goal names is a corpse where the bot is standing: there is nothing
                -- here to kill or use, so acting again would only re-enter DO_ACTION once a tick
                -- (the freeze). Wait for the mobs to come back instead.
                if (shared._respawn_wait_until or 0) == 0 then
                    shared._respawn_wait_until = ctx.now + RESPAWN_WAIT_SECONDS
                    shared._respawn_target_name = ctx.safe(current_goal.target, nil)
                    if shared._debug then
                        ctx.debug_log("IDLE: '" .. tostring(shared._respawn_target_name) ..
                            "' is a corpse underfoot and nothing alive matches — waiting for respawn")
                    end
                end
                return "IDLE"
            end

            if not has_target then
                local zygor_module = ctx.zygor
                local all_wps = zygor_module and zygor_module.get_step_waypoints_world and zygor_module.get_step_waypoints_world()
                if all_wps and #all_wps > 0 and ctx.me then
                    local visited = shared._visited_waypoints or {}
                    local fixed_waypoints = shared._area_waypoint_fixes
                    if not fixed_waypoints then
                        fixed_waypoints = {}
                        shared._area_waypoint_fixes = fixed_waypoints
                    end
                    local pos_ok, pos = pcall(unit_get_position, ctx.me)
                    if pos_ok and pos and ctx.utils then
                        local best_wp = nil
                        local best_dist_sq = 1e9
                        local best_idx = nil
                        for i = 1, #all_wps do
                            local candidate = all_wps[i]
                            -- The reader returns a fresh table each tick. Cache the repaired point
                            -- by slot and x/y, so the sweep pays for one terrain query per waypoint,
                            -- not one per candidate per tick, while still publishing a fixed vec3.
                            local fixed_entry = candidate and fixed_waypoints[i]
                            local fixed, terrain_fixed
                            if candidate and candidate.x and candidate.y then
                                if fixed_entry and fixed_entry.point
                                    and fixed_entry.point.x == candidate.x
                                    and fixed_entry.point.y == candidate.y then
                                    fixed = fixed_entry.point
                                    terrain_fixed = fixed_entry.terrain_fixed
                                else
                                    local raw_z = candidate.z
                                    fixed, terrain_fixed = fix_destination_z(candidate)
                                    fixed_waypoints[i] = {
                                        point = fixed,
                                        raw_z = raw_z,
                                        terrain_fixed = terrain_fixed,
                                    }
                                    candidate = fixed
                                end
                                if not fixed then fixed = candidate end
                                candidate = fixed
                            end
                            -- A waypoint the client could not walk to is skipped and retired FOR THE
                            -- STEP (shared/nav_destination.lua owns the set) instead of being offered
                            -- again. Without this the producer re-issued the same coordinates every
                            -- second — IDLE -> NAV -> "arrived but still 13yd away" -> IDLE — and the
                            -- step's other waypoints were never covered, so the bot appeared to walk
                            -- between the one or two points the navmesh actually reaches. The 60s
                            -- memory behind it expires; the retirement is what keeps the skip alive
                            -- for this pass, and a new step (or a new pass) clears it.
                            --
                            -- A place the character has already stood on this session is skipped too,
                            -- and that memory is NOT cleared with the pass or the step: re-walking
                            -- ground the route already covers is exactly what the reached-path memory
                            -- exists to stop. The sweep is movement-only (it runs only when there is no
                            -- target), so a covered waypoint carries no trigger the bot still owes.
                            if not visited[i]
                                and not nav_destination.place_retired(shared, candidate)
                                and not place_reached(shared, candidate) then
                                if nav_destination.recently_unreachable(shared, ctx.now, candidate) then
                                    -- The refusal is recorded against the PLACE and nothing else:
                                    -- `visited` is keyed by the slot the reader happened to return, and
                                    -- a refusal does not say anything about whatever waypoint ends up
                                    -- in that slot later in the pass.
                                    if nav_destination.retire_place(shared, candidate) then
                                        ctx.debug_log("IDLE: area goal — wp " .. tostring(i) .. "/" ..
                                            tostring(#all_wps) .. " is unreachable — retiring it for this step")
                                        if ctx.record_event then
                                            ctx.record_event("waypoint_retired", {
                                                index = i,
                                                x = candidate.x,
                                                y = candidate.y,
                                                z = candidate.z,
                                                reason = "unreachable",
                                            }, ctx.now)
                                        end
                                    end
                                else
                                    local d_sq = ctx.utils.squared_distance(pos, candidate)
                                    if d_sq < best_dist_sq then
                                        best_dist_sq = d_sq
                                        best_wp = candidate
                                        best_idx = i
                                    end
                                end
                            end
                        end
                        -- Persist the marks: the sweep is read back from shared next tick, and an
                        -- expired memory must not resurrect a waypoint this pass already refused.
                        shared._visited_waypoints = visited
                        if best_wp then
                            if best_dist_sq > 100 then
                                if ctx.record_event then
                                    local selected = fixed_waypoints[best_idx]
                                    ctx.record_event("waypoint_selected", {
                                        index = best_idx,
                                        x = best_wp.x,
                                        y = best_wp.y,
                                        z = best_wp.z,
                                        raw_z = selected and selected.raw_z,
                                        terrain_fixed = selected and selected.terrain_fixed,
                                    }, ctx.now)
                                end
                                nav_destination.point(shared, best_wp)
                                ctx.debug_log("IDLE: area goal — navigating to wp " .. tostring(best_idx) .. "/" .. tostring(#all_wps) .. " (" .. tostring(math.floor(math.sqrt(best_dist_sq))) .. "yd)")
                                return "NAV"
                            else
                                visited[best_idx] = true
                                shared._visited_waypoints = visited
                                -- AQ-P4-6: remember the PLACE, not the slot, so the next pass (or a
                                -- later step over the same ground) does not walk it again.
                                local remembered = remember_reached_place(shared, best_wp)
                                if remembered and ctx.record_event then
                                    ctx.record_event("waypoint_reached", {
                                        index = best_idx,
                                        x = best_wp.x,
                                        y = best_wp.y,
                                        z = best_wp.z,
                                    }, ctx.now)
                                end
                                ctx.debug_log("IDLE: area goal - reached wp " .. tostring(best_idx) ..
                                    "/" .. tostring(#all_wps) .. (remembered and " (remembered)" or ""))
                                return "IDLE"
                            end
                        elseif (shared._sweep_lap_at or 0) == 0 then
                            -- The pass is over: nothing left to walk to. Two ways to get here —
                            -- every reachable waypoint was covered, or every waypoint was refused by
                            -- the client — and they answer differently, because only the first has
                            -- something for the guide to do at these coordinates.
                            shared._sweep_lap_at = ctx.now
                            if nav_destination.retired_count(shared) >= #all_wps then
                                ctx.debug_log("IDLE: area goal — none of the " .. tostring(#all_wps) ..
                                    " step waypoints is reachable — waiting for the retry")
                                return "WAITING"
                            end
                            ctx.debug_log("IDLE: area goal — all " .. tostring(#all_wps) ..
                                " waypoints covered — handing over to the guide")
                            return "DO_ACTION"
                        elseif ctx.now - shared._sweep_lap_at < SWEEP_RELAP_SECONDS then
                            -- Between passes the state waits instead of marching. This is the other
                            -- half of "moves between 2 waypoints": a covered pass used to re-issue
                            -- its whole path on the very next tick, so a step the guide had not
                            -- finished became an endless march over the same points.
                            return "WAITING"
                        else
                            -- A new pass. The marks go with it, so a waypoint the client refused is
                            -- retried once per pass — at most once a minute — rather than never: a
                            -- transient refusal of a real part of the path must not retire it for
                            -- the whole step.
                            shared._visited_waypoints = {}
                            nav_destination.clear_retired(shared)
                            shared._sweep_lap_at = 0
                            ctx.debug_log("IDLE: area goal — re-patrolling the step's waypoints")
                            return "DO_ACTION"
                        end
                    end
                elseif wp and ctx.me then
                    local pos_ok, pos = pcall(function() return ctx.me:get_position() end)
                    if pos_ok and pos and ctx.utils then
                        local dist_sq = ctx.utils.squared_distance(pos, wp)
                        if dist_sq > 1600 then
                            nav_destination.point(shared, wp)
                            ctx.debug_log("IDLE: area goal with no target, far from wp → NAV")
                            return "NAV"
                        end
                    end
                end
                ctx.debug_log("IDLE: area goal with no target - waiting for Zygor to mark complete")
                return "WAITING"
            end
        end

        -- Kill goal with a valid target already engaged: stay in IDLE and let the
        -- rotation fight. Re-entering DO_ACTION re-tags every cycle, which thrashes
        -- the target and can pull extra mobs. (Ported: docs/phase1_port_list.md item 2.)
        if action_type == "kill" and ctx.combat_helper
            and ctx.combat_helper.is_current_target_valid
            and ctx.combat_helper.is_current_target_valid(50) then
            ctx.debug_log("IDLE: kill goal — target already valid, holding")
            return "IDLE"
        end

        -- Respect the pause DO_ACTION set for the previous action. The modular path
        -- used to zero it here, which quietly bypassed the 0.5s pacing entirely.
        -- (Ported: docs/phase1_port_list.md item 3.)
        local action_pause_until = shared._action_pause_timer or 0
        if action_pause_until > 0 and ctx.now < action_pause_until then
            return "IDLE"
        end

        shared._action_pause_timer = 0
        shared._area_fail_count = 0
        shared._area_last_target_guid = nil
        ctx.debug_log("IDLE: goal type=" .. action_type .. " → DO_ACTION")
        return "DO_ACTION"
    end

    -- No uncompleted goal — check for lootable corpses (any distance)
    if not in_combat then
        local result = corpse_loot.try_loot_nearest_corpse(shared, ctx)
        if result then return result end
    end

    -- A loaded guide with no active goal and no waypoint may use the character's opted-in
    -- profession route. With a waypoint present, the guide remains authoritative.
    if not current_goal and not wp then
        local gathering_result = run_gathering(shared, ctx)
        if gathering_result then return gathering_result end
    end

    -- No uncompleted goal found — navigate to waypoint if available
    if wp then
        nav_destination.point(shared, wp)
        -- Attempt to mount before long-distance travel
        do
            local mm_ok, mm = pcall(require, "mount_manager_sylvanas")
            if mm_ok and mm and mm.try_mount then
                mm.try_mount(ctx.me, wp)
            end
        end
        ctx.debug_log("IDLE: nav to wp → NAV")
        return "NAV"
    end

    -- No goal, no waypoint — wait
    ctx.debug_log("IDLE: no goal/wp → WAITING")
    return "WAITING"
end

return M
