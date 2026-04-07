
-- Example:
-- ---@type pet_handler
-- local pet_handler = require("common/utility/pet_handler")
-- pet_handler:set_pet_state(pet_handler.pet_state.PASSIVE, 2.0) -- Pet goes passive after 2s

-- x: -> IntelliSense
-- Warning: Access with ":", not "."

---@class pet_handler
---@field pet_state table   -- Enum of pet states
---@field set_pet_state fun(self: pet_handler, new_state: number, delay?: number): nil
---@field move_pet_to_position fun(self: pet_handler, position: vec3, delay?: number, duration?: number): nil
---@field on_render fun(self: pet_handler): nil

---@type pet_handler
local tbl
return tbl
