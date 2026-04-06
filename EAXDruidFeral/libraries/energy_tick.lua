-- energy_tick.lua | Energy tick tracking for EAX* Feral Druid
-- Tracks 2-second energy ticks and filters out Furor/Wolfshead energy from shifts

-- Hot-path local caching
local _core_time = core.time

-- Constants
local ENERGY_TICK_INTERVAL = 2.0
local SHIFT_ENERGY_IGNORE_WINDOW = 0.6
local TICK_WAIT_THRESHOLD = 0.4
local WOLFSHEAD_HELM_ID = 8345
local INVSLOT_HEAD = 1
local EQUIPMENT_CHECK_INTERVAL = 2.0

-- State
local state = {
    last_energy = 0,
    last_tick_time = 0,
    confident = false,
    last_shift_time = 0,
    wolfshead_cache = { equipped = false, last_check = 0 }
}

local energy_tick = {}

function energy_tick.is_wolfshead_equipped()
    local now = _core_time()
    if now - state.wolfshead_cache.last_check < EQUIPMENT_CHECK_INTERVAL then
        return state.wolfshead_cache.equipped
    end
    local head_item = core.inventory and core.inventory.get_inventory_item_id("player", INVSLOT_HEAD)
    state.wolfshead_cache.equipped = (head_item == WOLFSHEAD_HELM_ID)
    state.wolfshead_cache.last_check = now
    return state.wolfshead_cache.equipped
end

function energy_tick.on_shift()
    state.last_shift_time = _core_time()
end

function energy_tick.update(current_energy, in_cat_form)
    if not in_cat_form then
        state.last_energy = 0
        state.confident = false
        return
    end
    local now = _core_time()
    local delta = current_energy - state.last_energy
    if delta > 0 and delta <= 25 and (now - state.last_shift_time) > SHIFT_ENERGY_IGNORE_WINDOW then
        state.last_tick_time = now
        state.confident = true
    end
    state.last_energy = current_energy
end

function energy_tick.time_until_next_tick()
    if not state.confident or state.last_tick_time == 0 then return 1.0 end
    local elapsed = _core_time() - state.last_tick_time
    return ENERGY_TICK_INTERVAL - (elapsed % ENERGY_TICK_INTERVAL)
end

function energy_tick.should_delay_shift()
    if not state.confident then return false end
    return energy_tick.time_until_next_tick() <= TICK_WAIT_THRESHOLD
end

function energy_tick.should_prefer_mangle(energy, mangle_cost, shred_cost)
    local low = 2 * mangle_cost - 20
    local high = mangle_cost + shred_cost - 21
    return energy >= low and energy <= high and state.confident and energy_tick.time_until_next_tick() < 1.0
end

function energy_tick.reset_confidence()
    state.confident = false
    state.last_tick_time = 0
end

function energy_tick.get_debug_info()
    return {
        confident = state.confident,
        last_tick_time = state.last_tick_time,
        time_until_next = energy_tick.time_until_next_tick(),
        should_delay = energy_tick.should_delay_shift(),
        wolfshead = energy_tick.is_wolfshead_equipped(),
        last_shift = state.last_shift_time
    }
end

return energy_tick
