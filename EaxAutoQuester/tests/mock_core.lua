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
M._vendor_items = {}
M._trainer_services = {}
M._gossip_available = {}
M._gossip_active = {}
M._quest_rewards = {}
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

-- ============================================================================
-- Reset
-- ============================================================================

function M.reset()
    _mock_time = 0
    M._player = nil
    M._objects = {}
    M._loot_items = {}
    M._vendor_items = {}
    M._trainer_services = {}
    M._gossip_available = {}
    M._gossip_active = {}
    M._quest_rewards = {}
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
        _attackable = opts.attackable or false,
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

    return o
end

-- ============================================================================
-- Mock core API
-- ============================================================================

M.object_manager = {
    get_local_player = function() return M._player end,
    get_visible_objects = function() return M._objects end,
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
}

M.quests = {
    get_gossip_available_quests = function() return M._gossip_available end,
    get_gossip_active_quests = function() return M._gossip_active end,
    select_gossip_available_quest = function(id)
        M._frames.gossip_selected = id
    end,
    select_gossip_active_quest = function(id)
        M._frames.gossip_selected = id
    end,
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
    get_trainer_service_info = function(index) return M._trainer_services[index] or nil end,
    get_trainer_service_cost = function(index)
        local s = M._trainer_services[index]
        return s and { service_cost = s.cost } or nil
    end,
    buy_trainer_service = function(index)
        M._input_calls[#M._input_calls + 1] = { "buy_trainer_service", index }
    end,
    get_item_info = function(id)
        return { quality = 0, sell_price = 1 }
    end,
}

M._bag_slots = { [0] = 16, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }  -- backpack 16, others default 0 (no bag equipped)

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

function M.log(msg) end
function M.log_warning(msg) end
function M.register_on_pre_tick_callback(fn) end
function M.register_on_render_callback(fn) end
function M.register_on_render_menu_callback(fn) end
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
end

function M.uninstall()
    -- noop — tests snapshot/restore _G so this is handled by the runner
end

return M
