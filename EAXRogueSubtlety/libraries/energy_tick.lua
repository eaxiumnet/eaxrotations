-- energy_tick.lua
-- Enhanced energy tick tracking for Rogue Combat energy budgeting.
-- Tracks spell costs so the rotation can plan builders/finishers intelligently.

local spells = require("libraries/spells")
local izi = require("common/izi_sdk")

local ENERGY_POWER_TYPE = 3
local ENERGY_TICK_VALUE = 20

local energy_tick = {
    last_energy = 0,
    last_tick_time = 0,
    confident = false,
    TICK_INTERVAL = 2.0,
    DELAY_THRESHOLD = 0.4,
    COST_REFRESH_INTERVAL = 5.0,
    CHEAP_CHOICE_WINDOW = 0.65,
}

local _core_time = core.time
local _spell_book = core.spell_book or {}
local _is_spell_learned = _spell_book.is_spell_learned

local _cost_entries = {
    sinister_strike = {
        ranks = spells.SINISTER_STRIKE,
        default_cost = 45,
        current_cost = 45,
        spell_id = nil,
    },
    backstab = {
        ranks = spells.BACKSTAB,
        default_cost = 60,
        current_cost = 60,
        spell_id = nil,
    },
    eviscerate = {
        ranks = spells.EVISCERATE,
        default_cost = 35,
        current_cost = 35,
        spell_id = nil,
    },
}

local _izi_cache = {}
local _last_cost_refresh = 0

local function get_izi_spell(spell_id)
    if not spell_id then return nil end
    if _izi_cache[spell_id] == nil then
        local ok, spell_obj = pcall(function() return izi.spell(spell_id) end)
        _izi_cache[spell_id] = ok and spell_obj or false
    end
    return _izi_cache[spell_id] or nil
end

local function resolve_learned_spell_id(ranks)
    if not ranks then return nil end
    for i = 1, #ranks do
        local spell_id = ranks[i]
        if spell_id and (not _is_spell_learned or _is_spell_learned(spell_id)) then
            return spell_id
        end
    end
    return ranks[1]
end

local function fetch_spell_cost(spell_id)
    local spell_obj = get_izi_spell(spell_id)
    if not spell_obj or not spell_obj.get_spell_power_cost then
        return nil
    end
    local ok, cost, power_type = pcall(function()
        return spell_obj:get_spell_power_cost()
    end)
    if not ok or not cost or cost <= 0 then
        return nil
    end
    if power_type and power_type ~= ENERGY_POWER_TYPE then
        return nil
    end
    return cost
end

local function refresh_cost_entry(entry)
    if not entry then return end
    entry.spell_id = resolve_learned_spell_id(entry.ranks)
    local cost = fetch_spell_cost(entry.spell_id)
    entry.current_cost = cost or entry.default_cost
end

local function refresh_all_costs(force)
    local now = _core_time()
    if not force and (now - _last_cost_refresh) < energy_tick.COST_REFRESH_INTERVAL then
        return
    end
    _last_cost_refresh = now
    for _, entry in pairs(_cost_entries) do
        refresh_cost_entry(entry)
    end
end

local function resolve_cost_input(cost_or_key)
    if type(cost_or_key) == "number" then
        return cost_or_key
    end
    if type(cost_or_key) == "string" then
        local entry = _cost_entries[cost_or_key]
        return entry and entry.current_cost or nil
    end
    return nil
end

function energy_tick.refresh_spell_costs(force)
    refresh_all_costs(force)
end

function energy_tick.get_ability_cost(key)
    refresh_all_costs(false)
    local entry = _cost_entries[key]
    return entry and entry.current_cost or nil
end

function energy_tick:update(current_energy)
    if not current_energy or type(current_energy) ~= "number" then
        return
    end

    refresh_all_costs(false)

    local delta = current_energy - self.last_energy
    if delta > 0 and delta <= (ENERGY_TICK_VALUE + 5) then
        self.last_tick_time = _core_time()
        self.confident = true
    end

    self.last_energy = current_energy
end

function energy_tick:time_until_next_tick()
    if not self.confident or self.last_tick_time == 0 then
        return 1.0
    end
    local now = _core_time()
    local elapsed = now - self.last_tick_time
    return self.TICK_INTERVAL - (elapsed % self.TICK_INTERVAL)
end

function energy_tick:should_delay_action(current_energy, ability_cost_or_key)
    if not self.confident then
        return false
    end

    local target_cost = resolve_cost_input(ability_cost_or_key)
    if not target_cost then
        return self:time_until_next_tick() <= self.DELAY_THRESHOLD
    end

    local energy = (type(current_energy) == "number" and current_energy) or self.last_energy or 0
    if energy >= target_cost then
        return false
    end

    local time_until = self:time_until_next_tick()
    if time_until > self.DELAY_THRESHOLD then
        return false
    end

    return (energy + ENERGY_TICK_VALUE) >= target_cost
end

function energy_tick:should_prefer_cheap_ability(current_energy, opts)
    refresh_all_costs(false)

    local cheap_cost = _cost_entries.sinister_strike.current_cost
    local expensive_cost = _cost_entries.backstab.current_cost
    local energy = (type(current_energy) == "number" and current_energy) or self.last_energy or 0

    if not cheap_cost or not expensive_cost then
        return false
    end
    if energy < cheap_cost then
        return false
    end
    if energy >= expensive_cost then
        return false
    end
    if not self.confident then
        return true
    end

    local window = (opts and opts.tick_window) or self.CHEAP_CHOICE_WINDOW
    local time_until = self:time_until_next_tick()
    local energy_after_tick = energy + ENERGY_TICK_VALUE

    if energy_after_tick < expensive_cost then
        return true
    end
    return time_until > window
end

function energy_tick:on_shift()
    self.confident = false
    self.last_tick_time = 0
end

function energy_tick:get_last_tick_time()
    return self.last_tick_time
end

function energy_tick:is_confident()
    return self.confident
end

function energy_tick.get_debug_info()
    refresh_all_costs(false)
    return {
        confident = energy_tick.confident,
        last_energy = energy_tick.last_energy,
        last_tick_time = energy_tick.last_tick_time,
        time_until_next = energy_tick:time_until_next_tick(),
        delay_default = energy_tick:should_delay_action(nil, nil),
        costs = {
            sinister_strike = _cost_entries.sinister_strike.current_cost,
            backstab = _cost_entries.backstab.current_cost,
            eviscerate = _cost_entries.eviscerate.current_cost,
        },
        delay_eviscerate = energy_tick:should_delay_action(nil, "eviscerate"),
        prefer_cheap = energy_tick:should_prefer_cheap_ability(nil, nil),
    }
end

return energy_tick
