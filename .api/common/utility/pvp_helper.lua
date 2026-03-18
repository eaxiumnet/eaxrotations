
--- Example:
--- ---@type pvp_helper
--- local x = require("common/utility/pvp_helper")
--- x: -> IntelliSense
--- Warning: Access with ":", not "."

---@class pvp_helper
---@field is_player fun(self: pvp_helper, unit: game_object): boolean
---@field is_pvp_scenario fun(self: pvp_helper): boolean
---@field cc_flags cc_flags
---@field damage_type_flags damage_type_flags
---@field cc_flag_descriptions table<number, string>
---@field dr_categories table<number, string>
---@field no_dr_flags table<number, boolean>
---@field DR_RESET_TIME number
---@field game_version string
---@field is_retail boolean
---@field is_tbc boolean
---@field is_wotlk boolean
---@field is_mop boolean
---@field is_classic_era boolean
---@field PVP_TRINKET_SPELL_IDS table<number, boolean>
---@field cc_debuffs table<number, {debuff_id: number, debuff_name: string, flag: number, weak: boolean, immune: boolean, source: number}>
---@field slow_debuffs table<number, {debuff_id: number, debuff_name: string, mult: number, source: number}>
---@field cc_immune_buffs table<number, {buff_id: number, buff_name: string, flag: number, class: number, mult: number}>
---@field slow_immune_buffs table<number, {buff_id: number, buff_name: string, class: number}>
---@field damage_reduction_buff table<number, {buff_id: number, buff_name: string, flag: number, class: number, mult: number}>
---@field burst_buffs table<number, {buff_id: number, buff_name: string, class: number}>
---@field purgeable_buffs table<number, {buff_id: number, buff_name: string, priority: number, min_remaining: number}>
---@field stealeable_buffs table<number, {buff_id: number, buff_name: string, priority: number, min_remaining: number}>

---@class pvp_helper
---is_cc, cc_flag, remaining, is_immune, is_weak
---@field is_crowd_controlled fun(self: pvp_helper, unit: game_object, type_flags: number?, min_remaining_ms: number?, source_filter: number?): boolean, number, number, boolean, boolean
---@field is_crowd_controlled_weak fun(self: pvp_helper, unit: game_object, min_remaining_ms: number?, source_filter: number?): boolean, number, number
---is_immune, cc_flag, remaining | Checks if unit is in immune CC (Cyclone, Banish) where heals won't land
---@field is_immune_to_heal fun(self: pvp_helper, unit: game_object, min_remaining_ms: number?): boolean, number, number
---@field get_unit_dr fun(self: pvp_helper, unit: game_object, cc_flag: number, hit_time_sec: number): number
---@field get_cc_reduction_mult fun(self: pvp_helper, unit: game_object, type_flags?: integer, min_remaining_ms?: integer, ignore_dot?: boolean, dot_blacklist?: number[]|nil, source_filter?: integer): number, integer, integer
---@field get_cc_reduction_percentage fun(self: pvp_helper, unit: game_object, type_flags?: integer, min_remaining_ms?: integer, ignore_dot?: boolean, dot_blacklist?: number[]|nil, source_filter?: integer): number, integer, integer
---@field has_cc_reduction fun(self: pvp_helper, unit: game_object, threshold?: number, type_flags?: integer, min_remaining_ms?: integer, ignore_dot?: boolean, dot_blacklist?: number[]|nil, source_filter?: integer): boolean, integer, integer
---@field is_cc_immune fun(self: pvp_helper, unit: game_object, type_flags?: integer, min_remaining_ms?: integer, ignore_dot?: boolean, dot_blacklist?: number[]|nil, source_filter?: integer): boolean, integer, integer
---@field is_slow fun(self: pvp_helper, unit: game_object, threshold: number?, min_remaining_ms: number?, source_filter: number?): boolean, number, number
---@field get_slow_percentage fun(self: pvp_helper, unit: game_object, min_remaining_ms: number?, source_filter: number?): number, number
---@field is_slow_immune fun(self: pvp_helper, unit: game_object, source_filter: number?, min_remaining_ms: number?): boolean, number

---@class pvp_helper
---@field get_damage_reduction_mult fun(self: pvp_helper, unit: game_object, type_flags: number?, min_remaining_ms: number?): number, number, number
---@field get_damage_reduction_percentage fun(self: pvp_helper, unit: game_object, type_flags: number?, min_remaining_ms: number?): number, number, number
---is_above_threshold, damage_type, remaining_ms | note: threshold is from 1-100
---@field has_damage_reduction fun(self: pvp_helper, unit: game_object, threshold: number?, type_flags: number?, min_remaining_ms: number?): boolean, number, number
---@field is_damage_immune fun(self: pvp_helper, unit: game_object, type_flags: number?, min_remaining_ms: number?): boolean, number, number

---@class pvp_helper
---@field is_purgeable fun(self: pvp_helper, unit: game_object, min_remaining: number?): {is_purgeable: boolean, table: {buff_id: number, buff_name: string, priority: number, min_remaining: number}?, current_remaining_ms: number, expire_time: number}
---@field is_stealable fun(self: pvp_helper, unit: game_object, min_remaining: number?): {is_stealable: boolean, table: {buff_id: number, buff_name: string, priority: number, min_remaining: number}?, current_remaining_ms: number, expire_time: number}

---@class pvp_helper
---@field is_melee fun(self: pvp_helper, unit: game_object): boolean
---@field is_disarmable fun(self: pvp_helper, unit: game_object, include_all: boolean?): boolean

---@class pvp_helper
---@field has_burst_active fun(self: pvp_helper, unit: game_object, min_remaining_ms: number?): boolean

---@class pvp_helper
---@field get_combined_cc_descriptions fun(self: pvp_helper, type: number): string
---@field get_combined_damage_type_descriptions fun(self: pvp_helper, type: number): string

---@class pvp_helper
---Wire to core.register_on_spell_cast_callback. Handles trinket detection and fires registered callbacks.
---@field on_spell fun(self: pvp_helper, data: table)
---Register a general spell cast listener. Fires every time on_spell is called, before trinket detection.
---@field on_spell_usage fun(self: pvp_helper, callback: fun(data: table))
---Register a callback that fires when an enemy uses a PvP trinket. Receives the caster game_object.
---@field on_trinket_usage fun(self: pvp_helper, callback: fun(caster: game_object))
---Returns core.time() timestamp of the unit's last PvP trinket usage, or 0 if never used.
---@field get_last_trinket_time fun(self: pvp_helper, unit: game_object): number
---Returns seconds elapsed since the unit's last PvP trinket usage, or 9999 if never used.
---@field time_since_last_trinket fun(self: pvp_helper, unit: game_object): number
---Returns true if the unit used their PvP trinket within the given time window (seconds).
---@field trinket_used_within fun(self: pvp_helper, unit: game_object, window: number): boolean
---Clear trinket history for a specific unit (e.g. on arena reset).
---@field clear_trinket_history fun(self: pvp_helper, unit: game_object)
---Clear all trinket history (e.g. on arena/BG start).
---@field clear_all_trinket_history fun(self: pvp_helper)

---@type pvp_helper
local tbl
return tbl
