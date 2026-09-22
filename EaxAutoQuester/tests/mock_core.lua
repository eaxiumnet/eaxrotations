-- What: Minimal mock of core.* API for EaxAutoQuester tests
-- When: Required by every test file to isolate from the real Sylvanas runtime
-- Why: Allows deterministic unit testing without a running WoW client
-- Safety: All mock functions return safe defaults; resettable between tests
-- Decision: Minimal mock (not full Sylvanas API), only covers EaxAutoQuester usage

local M = {}

-- ============================================================================
-- Mock State
-- ============================================================================

local _mock_time = 0

M._player = nil
M._objects = {}
M._loot_items = {}
M._loot_compacts = false   -- true: looting a slot removes it and the rest renumber
M._looted_names = {}       -- names actually looted, in order
M._quest_log_compacts = false  -- true: abandoning removes the entry and the rest renumber
M._pending_abandon_index = nil
M._trainer_compacts = false    -- true: buying a service removes it and the rest renumber
M._trainer_bought_names = {}   -- names actually bought, in order
M._vendor_items = {}
M._trainer_services = {}
M._gossip_available = {}
M._gossip_active = {}
M._quest_rewards = {}
M._item_info = {}   -- id_or_link -> { name, quality, sell_price }; unset falls back to the default
M._quest_money = 0
M._gold = 0
M._repair_cost = 0
M._bag_items = {}
M._map_id = 0
M._addon_loaded = { zygor = false, questie = false }
M._zygor_step = nil
M._zygor_next_wp = nil
M._questie_npcs = {}
M._frames = {}
M._graphics_calls = {}
M._input_calls = {}
-- Party roster as the client reports it (see object_manager.get_party_members below).
M._party = {}
-- Every confirm input answers true by default; set false to model a client whose confirm call
-- was not reached.
M._confirm_answered = true

-- ============================================================================
-- Reset
-- ============================================================================

function M.reset()
    _mock_time = 0
    M._player = nil
    M._objects = {}
    M._party = {}
    M._loot_items = {}
    M._vendor_items = {}
    M._trainer_services = {}
    M._gossip_available = {}
    M._gossip_active = {}
    M._gossip_options = {}
    M._quest_rewards = {}
    M._item_info = {}
    M._quest_money = 0
    M._gold = 0
    M._repair_cost = 0
    M._bag_items = {}
    M._bag_slots = { [0] = 16, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
    M._map_id = 0
    M._addon_loaded = { zygor = false, questie = false }
    M._zygor_step = nil
    M._zygor_next_wp = nil
    M._questie_npcs = {}
    M._frames = {}
    M._graphics_calls = {}
    M._input_calls = {}
    M._player_buffs = {}
    M._logs = {}
    M._dungeon_proposal = false
    M._battlefield_status = {}
    M._quest_log = {}
    M._battlefield_status = {}
    M._loot_compacts = false
    M._looted_names = {}
    M._quest_log_compacts = false
    M._pending_abandon_index = nil
    M._trainer_compacts = false
    M._trainer_bought_names = {}
    M._game_event_callback = nil
    M._game_event_registrations = 0
    M._game_event_raises = false
    M._confirm_answered = true
    M._helper_capacity = nil
    M._helper_used = nil
end

function M.get_time() return _mock_time end
function M.set_time(t) _mock_time = t end

-- ============================================================================
-- Mock Player
-- ============================================================================

function M.create_player(opts)
    opts = opts or {}
    local p = {
        _hp = opts.hp or 100,
        _max_hp = opts.max_hp or 100,
        _mana = opts.mana or 100,
        _max_mana = opts.max_mana or 100,
        _pos = opts.pos or { x = 0, y = 0, z = 0 },
        _combat = opts.combat or false,
        _class = opts.class or 1,
        _target = opts.target or nil,
        _guid = opts.guid or "player_guid",
        _dead = opts.dead or false,
        _casting = opts.casting or false,
        _channelling = opts.channelling or false,
        _buffs = opts.buffs or {},
        _equipped = opts.equipped or {},
        _mounted = opts.mounted or false,
        _indoors = opts.indoors or false,
    }

    function p:get_health() return p._hp end
    function p:get_max_health() return p._max_hp end
    function p:get_power(type) return p._mana end
    function p:get_max_power(type) return p._max_mana end
    function p:get_position() return p._pos end
    function p:is_casting_spell() return p._casting end
    function p:is_channelling_spell() return p._channelling end
    function p:is_in_combat() return p._combat end
    function p:get_class() return p._class end
    function p:get_target() return p._target end
    function p:get_guid() return p._guid end
    function p:get_rotation() return p._rotation or 0 end
    function p:is_dead() return p._dead end
    -- Both are real game_object members (.api/game_object.lua — "is_mounted", "is_indoors"), not
    -- inventions of this mock: mount_manager_sylvanas reads them, and a suite that models a mount
    -- has to be able to answer them without a client. Defaults are "on foot" and "outdoors".
    function p:is_mounted() return p._mounted end
    function p:is_indoors() return p._indoors end
    function p:has_buff(buff_id)
        if type(buff_id) == "table" then
            for _, id in ipairs(buff_id) do
                if p._buffs[id] then return true end
            end
            return false
        end
        return p._buffs[buff_id] or false
    end
    function p:get_buffs()
        local t = {}
        for id, _ in pairs(p._buffs) do
            t[#t + 1] = { buff_id = id, buff_name = "Buff_" .. tostring(id), count = 1, expire_time = 0, duration = 0, type = 0, caster = p }
        end
        return t
    end
    p.get_auras = p.get_buffs
    p.get_debuffs = p.get_buffs
    function p:get_health_percentage()
        if p._max_hp > 0 then return (p._hp / p._max_hp) * 100 end
        return 100
    end
    function p:get_mana_percentage()
        if p._max_mana > 0 then return (p._mana / p._max_mana) * 100 end
        return 100
    end
    function p:get_level() return opts.get_level or 60 end
    -- Equipped items: [{ object = <game_object with get_name/get_item_id>, slot_id = n }].
    -- Empty by default, which leaves auto_equip's reward scan with no slot to compare — the
    -- same "nothing to compare" outcome as before the method existed.
    function p:get_equipped_items() return p._equipped end
    -- Alias x/y/z for squared_distance compatibility
    p.x = p._pos.x
    p.y = p._pos.y
    p.z = p._pos.z

    M._player = p
    return p
end

-- ============================================================================
-- Mock Object
-- ============================================================================

function M.create_object(opts)
    opts = opts or {}
    local o = {
        _pos = opts.pos or { x = 0, y = 0, z = 0 },
        _name = opts.name or "Object",
        _npc_id = opts.npc_id or nil,
        _unit = opts.unit ~= false,
        _player = opts.player or false,
        _dead = opts.dead or false,
        _valid = opts.valid ~= false,
        _guid = opts.guid or "obj_" .. tostring(math.random(100000)),
        _enemy = opts.enemy or false,
        _lootable = opts.lootable or false,
        -- has_loot is a SEPARATE probe from can_be_looted (and may be left out entirely: a build
        -- without the method must answer "no evidence", not "no loot").
        _has_loot = opts.has_loot,
        _attackable = opts.attackable or false,
        _item_id = opts.item_id or nil,
    }

    function o:get_position() return o._pos end
    function o:get_name() return o._name end
    function o:get_npc_id() return o._npc_id end
    function o:is_unit() return o._unit end
    function o:is_player() return o._player end
    function o:is_dead() return o._dead end
    function o:is_valid() return o._valid end
    function o:get_guid() return o._guid end
    function o:is_enemy_with(other) return o._enemy end
    function o:can_attack(other) return o._attackable end
    function o:can_be_looted() return o._lootable end
    function o:has_loot() return o._has_loot end
    function o:get_item_id() return o._item_id end

    return o
end

-- ============================================================================
-- Mock core API
-- ============================================================================

M.object_manager = {
    get_local_player = function() return M._player end,
    get_visible_objects = function() return M._objects end,
    -- Party roster as the client reports it: one entry per member, `.object` present only
    -- when the member is in object range. Tests fill _party with objects or { object = obj }
    -- entries to prove group members are never mistaken for strangers.
    get_party_members = function()
        local out = {}
        for i = 1, #M._party do
            local entry = M._party[i]
            if type(entry) == "table" and entry.object then out[i] = entry else out[i] = { object = entry } end
        end
        return out
    end,
    get_enemy_list = function()
        local enemies = {}
        for _, obj in ipairs(M._objects) do
            if obj._enemy then
                enemies[#enemies + 1] = obj
            end
        end
        return enemies
    end,
}

M.input = {
    set_target = function(obj)
        M._input_calls[#M._input_calls + 1] = { "set_target", obj }
        if M._player then M._player._target = obj end
        return true
    end,
    interact_with_object = function(obj)
        M._input_calls[#M._input_calls + 1] = { "interact_with_object", obj }
    end,
    use_object = function(obj)
        M._input_calls[#M._input_calls + 1] = { "use_object", obj }
    end,
    -- Mounting inputs: real API (.api/core.lua:2492 `core.input.mount(mount_index)`, :2498
    -- `core.input.dismount()`), recorded like every other input so a suite can assert on them.
    mount = function(mount_index)
        M._input_calls[#M._input_calls + 1] = { "mount", mount_index }
    end,
    dismount = function()
        M._input_calls[#M._input_calls + 1] = { "dismount" }
    end,
    move_to = function(pos)
        M._input_calls[#M._input_calls + 1] = { "move_to", pos }
    end,
    look_at = function(pos)
        M._input_calls[#M._input_calls + 1] = { "look_at", pos }
    end,
    look_at_3d = function(pos)
        M._input_calls[#M._input_calls + 1] = { "look_at_3d", pos }
    end,
    loot_item = function(index)
        M._input_calls[#M._input_calls + 1] = { "loot_item", index }
        -- Loot indexes are 0 based on every build (core.lua get_loot_item_count:
        -- "running 0 to this count minus 1"; confirm_loot_slot: "matching
        -- core.input.loot_item"), which is why the fixture is read at index + 1.
        local item = M._loot_items[index + 1]
        if item then
            M._looted_names[#M._looted_names + 1] = item.name
            if M._loot_compacts then
                table.remove(M._loot_items, index + 1)
            end
        end
    end,
    close_loot = function()
        M._input_calls[#M._input_calls + 1] = { "close_loot" }
    end,
    loot_object = function(obj)
        M._input_calls[#M._input_calls + 1] = { "loot_object", obj }
    end,
    repair_all_items = function(arg)
        M._input_calls[#M._input_calls + 1] = { "repair_all_items", arg }
    end,
    buy_item = function(index, quantity)
        M._input_calls[#M._input_calls + 1] = { "buy_item", index, quantity }
    end,
    use_container_item = function(bag, slot)
        M._input_calls[#M._input_calls + 1] = { "use_container_item", bag, slot }
    end,
    use_item_target = function(item_id, target)
        M._input_calls[#M._input_calls + 1] = { "use_item_target", item_id, target }
    end,
    use_item = function(item_id)
        M._input_calls[#M._input_calls + 1] = { "use_item", item_id }
    end,
    use_item_position = function(item_id, position)
        M._input_calls[#M._input_calls + 1] = { "use_item_position", item_id, position }
    end,
    -- Confirm inputs (item 14). Both return the documented `ran` boolean, and
    -- M._confirm_answered lets a suite model a client that did not reach its confirm call.
    confirm_loot_slot = function(loot_slot)
        M._input_calls[#M._input_calls + 1] = { "confirm_loot_slot", loot_slot }
        return M._confirm_answered
    end,
    confirm_binder = function()
        M._input_calls[#M._input_calls + 1] = { "confirm_binder" }
        return M._confirm_answered
    end,
    has_dungeon_proposal = function()
        return M._dungeon_proposal
    end,
    accept_dungeon_proposal = function(is_accept)
        M._input_calls[#M._input_calls + 1] = { "accept_dungeon_proposal", is_accept }
    end,
    accept_battlefield_port = function(index, is_accept)
        M._input_calls[#M._input_calls + 1] = { "accept_battlefield_port", index, is_accept }
    end,
}

M.game_ui = {
    get_corpse_position = function() return { x = 0, y = 0, z = 1 } end,
    get_loot_item_count = function() return #M._loot_items end,
    get_loot_item_id = function(index) return M._loot_items[index + 1] and M._loot_items[index + 1].id or nil end,
    get_loot_item_name = function(index) return M._loot_items[index + 1] and M._loot_items[index + 1].name or nil end,
    get_loot_is_gold = function(index) return M._loot_items[index + 1] and M._loot_items[index + 1].is_gold or false end,
    get_vendor_item_count = function() return #M._vendor_items end,
    get_vendor_item_info = function(index) return M._vendor_items[index] or nil end,
    get_world_pos_from_map_pos = function(map_id, pos)
        return { x = pos.x * 100, y = pos.y * 100 }
    end,
    get_battlefield_status = function(index)
        return M._battlefield_status[index] or "none"
    end,
}

M.quests = {
    get_gossip_available_quests = function() return M._gossip_available end,
    get_gossip_active_quests = function() return M._gossip_active end,
    get_gossip_options = function() return M._gossip_options or {} end,
    select_gossip_option = function(id)
        M._input_calls[#M._input_calls + 1] = { "select_gossip_option", id }
    end,
    select_gossip_available_quest = function(id)
        M._frames.gossip_selected = id
    end,
    select_gossip_active_quest = function(id)
        M._frames.gossip_selected = id
    end,
    is_gossip_frame_shown = function() return M._frames.gossip ~= nil end,
    close_gossip = function() M._frames.gossip = nil end,
    get_quest_item_link = function(type, index)
        local r = M._quest_rewards[index]
        return r and r.link or nil
    end,
    get_reward_money = function() return M._quest_money end,
    get_quest_reward = function(index)
        M._input_calls[#M._input_calls + 1] = { "get_quest_reward", index }
    end,
    complete_quest = function()
        M._input_calls[#M._input_calls + 1] = { "complete_quest" }
    end,
    accept_quest = function()
        M._input_calls[#M._input_calls + 1] = { "accept_quest" }
    end,
    confirm_accept_quest = function()
        M._input_calls[#M._input_calls + 1] = { "confirm_accept_quest" }
    end,
    close_quest = function()
        M._frames.quest = nil
    end,
    close_gossip = function()
        M._frames.gossip = nil
    end,
    is_gossip_frame_shown = function() return M._frames.gossip ~= nil end,
    get_num_trainer_services = function() return #M._trainer_services end,
    get_num_quest_log_entries = function() return #M._quest_log end,
    get_quest_log_title = function(index) return M._quest_log[index] or nil end,
    set_abandon_quest = function(index)
        M._input_calls[#M._input_calls + 1] = { "set_abandon_quest", index }
        -- abandon_quest() confirms whatever was marked here, so remember it.
        M._pending_abandon_index = index
    end,
    abandon_quest = function()
        M._input_calls[#M._input_calls + 1] = { "abandon_quest" }
        -- The quest log is index addressed and 1 based (game-ui.md:1455). Real
        -- abandonment removes the entry, so model that when asked to.
        if M._quest_log_compacts and M._pending_abandon_index then
            table.remove(M._quest_log, M._pending_abandon_index)
        end
        M._pending_abandon_index = nil
    end,
    get_trainer_service_info = function(index) return M._trainer_services[index] or nil end,
    get_trainer_service_cost = function(index)
        local s = M._trainer_services[index]
        return s and { service_cost = s.cost } or nil
    end,
    buy_trainer_service = function(index)
        M._input_calls[#M._input_calls + 1] = { "buy_trainer_service", index }
        -- Trainer services are addressed by index and carry no id, so record WHICH offer
        -- the index resolved to. The label is never nil (a nameless entry still counts)
        -- and an index with nothing behind it records a marker, so a walk that
        -- over-reaches is visible rather than silent. Then optionally model renumbering.
        local service = M._trainer_services[index]
        if service then
            M._trainer_bought_names[#M._trainer_bought_names + 1] =
                service.spell_name or ("unnamed#" .. tostring(index))
        else
            M._trainer_bought_names[#M._trainer_bought_names + 1] =
                ("<no offer @" .. tostring(index) .. ">")
        end
        if M._trainer_compacts then
            table.remove(M._trainer_services, index)
        end
    end,
    -- Per-item detail when a suite registers one (M._item_info[id_or_link]), otherwise the
    -- historical nameless default — `should_equip` rejects a nil name, so suites that do not
    -- opt in behave exactly as before.
    get_item_info = function(id)
        return M._item_info[id] or { quality = 0, sell_price = 1 }
    end,
}

M.spell_book = {
    get_mount_count = function() return 0 end,
    get_mount_info = function(index) return nil end,
}

M._bag_slots = { [0] = 16, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }  -- backpack 16, others default 0 (no bag equipped)

-- ============================================================================
-- common/utility/inventory_helper stand-in (item 14)
-- ============================================================================

-- The plugin reads bag slots and bag-space totals from the documented owner of both
-- (.api/core.lua:889 - "common/utility/inventory_helper.lua owns that conversion and is the
-- supported way to get a usable pair"), so the harness provides it. bag_slot is deliberately
-- NOT the raw core.inventory slot_id: it carries BAG_SLOT_SHIFT, so a regression that passes
-- the raw slot_id (or the snapshot position) fails instead of coincidentally matching.
local BAG_SLOT_SHIFT = 7

--- slot_data list for the current bag fixtures, with the documented (bag_id, bag_slot) pair.
--- @return table[]
function M.build_bag_slots()
    local slots = {}
    for bag_id = 0, 4 do
        local items = M._bag_items[bag_id] or {}
        for index = 1, #items do
            local item = items[index]
            slots[#slots + 1] = {
                item = item.object,
                bag_id = bag_id,
                bag_slot = index + BAG_SLOT_SHIFT,
                global_slot = bag_id * 100 + index,
                stack_count = 1,
            }
        end
    end
    return slots
end

--- Capacity/used the stand-in reports. nil derives them from the raw fixtures; a suite can
--- set them to model the helper's own layout knowledge (its totals cover the backpack, which
--- core.inventory.get_num_bag_slots(0) never does — it answers 0 on every build).
M._helper_capacity = nil
M._helper_used = nil

function M.helper_capacity()
    if M._helper_capacity then return M._helper_capacity end
    local total = 0
    for bag_id = 0, 4 do total = total + (M._bag_slots[bag_id] or 0) end
    return total
end

function M.helper_used()
    if M._helper_used then return M._helper_used end
    local used = 0
    for bag_id = 0, 4 do used = used + #(M._bag_items[bag_id] or {}) end
    return used
end

--- Register the stand-in as the module require() resolves.
function M.install_inventory_helper()
    package.loaded["common/utility/inventory_helper"] = {
        get_character_bag_slots = function() return M.build_bag_slots() end,
        get_all_slots = function() return M.build_bag_slots() end,
        get_total_bag_capacity = function() return M.helper_capacity() end,
        get_total_used_slots = function() return M.helper_used() end,
        get_total_free_slots = function()
            local free = M.helper_capacity() - M.helper_used()
            if free < 0 then free = 0 end
            return free
        end,
    }
end

--- Remove the stand-in. Only meaningful BEFORE production code resolves it: a successful
--- resolve is cached (deliberately), a missing one is not, so an absent-then-present pair of
--- checks in that order sees both branches.
function M.uninstall_inventory_helper()
    package.loaded["common/utility/inventory_helper"] = nil
end

M.inventory = {
    get_gold = function() return M._gold end,
    get_total_repair_cost = function() return M._repair_cost end,
    get_items_in_bag = function(bag_id)
        return M._bag_items[bag_id] or {}
    end,
    get_num_bag_slots = function(bag_id)
        return M._bag_slots[bag_id] or 0
    end,
}

M.addons = {
    zygor = {
        is_loaded = function() return M._addon_loaded.zygor end,
        has_current_step = function() return M._zygor_step ~= nil end,
        get_current_step = function() return M._zygor_step end,
        get_current_waypoint = function() return M._zygor_step and M._zygor_step.waypoint end,
        get_next_waypoint = function() return M._zygor_next_wp end,
        get_step_waypoints = function() return M._zygor_step and M._zygor_step.waypoints or {} end,
        get_objectives = function() return M._zygor_step and M._zygor_step.objectives or {} end,
        get_current_stickies = function() return {} end,
    },
    questie = {
        is_loaded = function() return M._addon_loaded.questie end,
        get_quest_npc_ids = function() return M._questie_npcs end,
    },
}

M.graphics = {
    draw_text = function(x, y, text)
        M._graphics_calls[#M._graphics_calls + 1] = { "draw_text", x, y, text }
    end,
    draw_line = function(x1, y1, x2, y2, color, thickness)
        M._graphics_calls[#M._graphics_calls + 1] = { "draw_line", x1, y1, x2, y2, color, thickness }
    end,
    draw_circle = function(x, y, radius, color, segments, thickness)
        M._graphics_calls[#M._graphics_calls + 1] = { "draw_circle", x, y, radius, color, segments, thickness }
    end,
    get_screen_size = function() return { x = 1920, y = 1080 } end,
}

M.menu = {
    checkbox = function(default, id) return { _state = default, _id = id, get_state = function() return default end, set = function(self, v) self._state = v end, render = function() end } end,
    slider_int = function(min, max, default, id) return { _value = default, _id = id, get = function() return default end, render = function() end } end,
    combobox = function(default, id) return { _value = default, _id = id, get = function() return default end, render = function() end } end,
    keybind = function(key, shift, id) return { _key = key, _shift = shift, _id = id, get_toggle_state = function() return false end, render = function() end } end,
    button = function(id) return { _id = id, is_clicked = function() return false end, render = function() end } end,
    tree_node = function() return { render = function() end } end,
}

-- Log capture: the mock records what the plugin logs so a suite can pin a probe line.
-- Reset clears it; _logs is a bounded ring (last N lines) so a runaway log cannot grow it.
M._logs = {}
local LOG_CAP = 200
function M.log(msg)
    if #M._logs >= LOG_CAP then table.remove(M._logs, 1) end
    M._logs[#M._logs + 1] = tostring(msg)
end
function M.log_warning(msg)
    if #M._logs >= LOG_CAP then table.remove(M._logs, 1) end
    M._logs[#M._logs + 1] = "WARN " .. tostring(msg)
end
function M.last_log_line()
    return M._logs[#M._logs] or nil
end
function M.log_contains(sub)
    for _, line in ipairs(M._logs) do
        if string.find(line, sub, 1, true) then return true end
    end
    return false
end
function M.register_on_pre_tick_callback(fn) end
function M.register_on_render_callback(fn) end
function M.register_on_render_menu_callback(fn) end

-- Game events. The real API takes ONE firehose callback for every event and raises when a
-- plugin exceeds its callback limit, so the mock counts registrations (a suite can assert
-- the plugin registers exactly once) and can be told to refuse, which is the documented
-- "this build will not accept it" case.
M._game_event_callback = nil
M._game_event_registrations = 0
M._game_event_raises = false

function M.register_on_game_event_callback(fn)
    M._game_event_registrations = M._game_event_registrations + 1
    if M._game_event_raises then error("on_game_event callback limit exceeded") end
    M._game_event_callback = fn
end

--- Deliver one event to the registered callback, as the client would.
function M.fire_game_event(name, args)
    if M._game_event_callback then M._game_event_callback(name, args or {}) end
end
function M.read_data_file(path) return nil end
function M.get_map_id() return M._map_id end
function M.get_height_for_position(pos) return pos.z or 0 end

-- ============================================================================
-- Install as _G.core
-- ============================================================================

function M.install()
    -- Make core.time a function so modules that cache it can call it
    M.time = function() return _mock_time end
    _G.core = M
    -- The documented client mini-lib the plugin reads bag slots and bag-space totals from.
    -- Suites that need the "mini-lib absent" branch call M.uninstall_inventory_helper()
    -- BEFORE any production code resolves it (a successful resolve is cached on purpose).
    M.install_inventory_helper()
end

function M.uninstall()
    -- noop — tests snapshot/restore _G so this is handled by the runner
end

return M
