
-- Example:
-- ---@type spell_prediction
-- local x = require("common/modules/spell_prediction")
-- x: -> IntelliSense
-- Warning: Access with ":", not "."

---@class prediction_type
---@field ACCURACY number
---@field MOST_HITS number

---@class geometry_type
---@field CIRCLE number
---@field RECTANGLE number
---@field CONE number

---@class spell_data
---@field angle number
---@field radius number
---@field spell_id number
---@field max_range number
---@field cast_time number
---@field source_position vec3
---@field projectile_speed number
---@field exception_is_heal boolean
---@field geometry_type geometry_type | number
---@field intersection_factor number
---@field time_to_hit_override number
---@field prediction_mode prediction_type | number
---@field exception_target_included boolean
---@field exception_player_included boolean
---@field hitbox_min number
---@field hitbox_max number
---@field hitbox_mult number
---@field cache_time_override number
---@field is_debug boolean -- allows quick debug with localplayer

---@class hit_data
---@field obj game_object
---@field center_position vec3
---@field intersection_position vec3

---@class prediction_result
---@field hit_list hit_data_table
---@field amount_of_hits number
---@field cast_position vec3
---@field center_position vec3
---@field intersection_position vec3

-- spell_data constructor
---@class spell_prediction
--- Helper function to create new spell data with default values.
---@field new_spell_data fun(self: spell_prediction, spell_id: number, max_range: number?, radius: number?, cast_time: number?, projectile_speed: number?, prediction_mode: prediction_type | number, geometry: geometry_type | number, source_position: vec3?): spell_data

-- main function
---@class spell_prediction
--- Function to get the cast position based on the prediction mode.
---@field get_cast_position fun(self: spell_prediction, target: game_object, spell_data: spell_data): prediction_result
---@field get_quick_cast_position fun(self: spell_prediction, spell_id: number, target: game_object, radius: number, hit_time: number): vec3

-- utility functions
---@class spell_prediction
--- Helper function to get the center position of a target.
---@field get_center_position fun(self: spell_prediction, target: game_object, spell_data: spell_data): vec3
--- Helper function to get the intersection position for casting.
---@field get_intersection_position fun(self: spell_prediction, target: game_object, center_position: vec3, circle_radius: number, intersection_percentage: number): vec3
--- Gets the circle list of hit data based on the target position and spell data.
---@field get_circle_list fun(self: spell_prediction, target_position: vec3, spell_data: spell_data, is_heal: boolean?): hit_data_table
--- Gets the rectangle list of hit data based on the target position and spell data.
---@field get_rectangle_list fun(self: spell_prediction, target_position: vec3, spell_data: spell_data, is_heal: boolean?): hit_data_table
--- Gets the cone list of hit data based on the target position and spell data.
---@field get_cone_list fun(self: spell_prediction, target_position: vec3, spell_data: spell_data, is_heal: boolean?): hit_data_table
--- Gets the unit geometry list of hit data based on the position and spell data.
---@field get_unit_geometry_list fun(self: spell_prediction, position: vec3, spell_data: spell_data): hit_data_table
--- Helper function to get the best position for most hits.
---@field get_most_hits_position fun(self: spell_prediction, main_position: vec3, spell_data: spell_data, target: game_object?): prediction_result
--- Function to get the cast position based on the prediction mode with position override.
---@field get_cast_position_ fun(self: spell_prediction, position_override: vec3, spell_data: spell_data): prediction_result
--- Helper function to get the center position of a target.
---@field get_future_position fun(self: spell_prediction, target: game_object, time: number): vec3

-- utility functions
---@class spell_prediction
---@field geometry_type geometry_type
---@field prediction_type prediction_type

---@type spell_prediction
local tbl
return tbl
