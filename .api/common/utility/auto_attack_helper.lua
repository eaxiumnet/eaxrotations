-- Example:
-- ---@type auto_attack_helper
-- local x = require("common/utility/auto_attack_helper")
-- x: -> IntelliSense
-- Warning: Access with ":", not "."

---@class auto_attack_helper
---@field attacks_logs table<game_object, { last_swing_core_time: number, last_swing_game_time: number }>
---@field last_global_cooldown_value number
---@field last_global_cooldown_core_time number
---@field last_global_cooldown_game_time number
---@field combat_start_core_time number
---@field combat_start_game_time number

---@class auto_attack_helper
---@field is_spell_auto_attack fun(self: auto_attack_helper, spell_id: number): boolean
---@field get_last_attack_core_time fun(self: auto_attack_helper, unit: game_object): number
---@field get_last_attack_game_time fun(self: auto_attack_helper, unit: game_object): number
---@field get_next_attack_core_time fun(self: auto_attack_helper, unit: game_object, weapon_count?: number): number
---@field get_next_attack_game_time fun(self: auto_attack_helper, unit: game_object, weapon_count?: number): number

---@class auto_attack_helper
---@field get_global_value_core_time fun(self: auto_attack_helper): number
---@field get_global_value_game_time fun(self: auto_attack_helper): number
---@field get_last_global_core_time fun(self: auto_attack_helper): number
---@field get_last_global_game_time fun(self: auto_attack_helper): number
---@field get_next_global_core_time fun(self: auto_attack_helper): number
---@field get_next_global_game_time fun(self: auto_attack_helper): number

---@class auto_attack_helper
---@field get_combat_start_core_time fun(self: auto_attack_helper): number
---@field get_combat_start_game_time fun(self: auto_attack_helper): number
---@field get_current_combat_core_time fun(self: auto_attack_helper): number
---@field get_current_combat_game_time fun(self: auto_attack_helper): number

---@class auto_attack_helper
---@field is_auto_attacking fun(self: auto_attack_helper, object: game_object): boolean
---@field start_attack fun(self: auto_attack_helper, target: game_object, attack_type: integer): boolean
---@field stop_attack fun(self: auto_attack_helper, target: game_object, attack_type: integer): boolean
---@field toggle_auto_attack fun(self: auto_attack_helper, target: game_object, attack_type: integer): boolean

---@class AUTO_ATTACK_TYPE
---@field MELEE 6603
---@field RANGED 75
---@field WAND 5019

---@class auto_attack_helper
---@field ATTACK_TYPE AUTO_ATTACK_TYPE

---@type auto_attack_helper
local tbl
return tbl
