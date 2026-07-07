-- =============================================================================
-- Core/API Surface Module - Single adapter for all runtime API calls
-- 
-- This is the ONLY internal module allowed to touch raw core.*, izi.*, 
-- and helper modules. All feature modules call this adapter instead of 
-- reaching into runtime APIs directly.
--
-- Purpose:
-- 1. Provide a clean abstraction over Sylvanas runtime APIs
-- 2. Handle all pcall wrapping for safety
-- 3. Implement fallback chains for non-critical features
-- 4. Document all API usage in one place
-- 5. Enable easy migration when APIs change
--
-- Usage:
--   local API = require("core/api_surface")
--   local me = API.get_local_player()
--   local bobber = API.find_bobber(ctx, me)
-- =============================================================================

local M = {}

-- =============================================================================
-- CORE REGISTRATION
-- =============================================================================

--- Register on update callback
-- @param callback function
function M.register_on_update(callback)
    if core and core.register_on_update_callback then
        local ok, err = pcall(core.register_on_update_callback, callback)
        if not ok then
            print("[API Surface] register_on_update failed: " .. tostring(err))
        end
    end
end

--- Register on render callback
-- @param callback function
function M.register_on_render(callback)
    if core and core.register_on_render_callback then
        local ok, err = pcall(core.register_on_render_callback, callback)
        if not ok then
            print("[API Surface] register_on_render failed: " .. tostring(err))
        end
    end
end

--- Register on menu render callback
-- @param callback function
function M.register_on_render_menu(callback)
    if core and core.register_on_render_menu_callback then
        local ok, err = pcall(core.register_on_render_menu_callback, callback)
        if not ok then
            print("[API Surface] register_on_render_menu failed: " .. tostring(err))
        end
    end
end

--- Register on control panel render callback
-- @param callback function
-- @return table elements (from callback)
function M.register_on_render_control_panel(callback)
    if core and core.register_on_render_control_panel_callback then
        local ok, result = pcall(core.register_on_render_control_panel_callback, callback)
        if not ok then
            print("[API Surface] register_on_render_control_panel failed: " .. tostring(result))
            return {}
        end
        return result or {}
    end
    return {}
end

-- =============================================================================
-- OBJECT MANAGER
-- =============================================================================

--- Get local player object
-- @return table|nil player object
function M.get_local_player()
    if core and core.object_manager and core.object_manager.get_local_player then
        local ok, result = pcall(core.object_manager.get_local_player)
        if ok then
            return result
        end
    end
    return nil
end

--- Get all objects (preferred over get_visible_objects)
-- @return table array of game objects
function M.get_all_objects()
    if core and core.object_manager and core.object_manager.get_all_objects then
        local ok, result = pcall(core.object_manager.get_all_objects)
        if ok and type(result) == "table" then
            return result
        end
    end
    -- Fallback to get_visible_objects
    return M.get_visible_objects()
end

--- Get visible objects (fallback)
-- @return table array of game objects
function M.get_visible_objects()
    if core and core.object_manager and core.object_manager.get_visible_objects then
        local ok, result = pcall(core.object_manager.get_visible_objects)
        if ok and type(result) == "table" then
            return result
        end
    end
    return {}
end

-- =============================================================================
-- GAME OBJECT METHODS
-- =============================================================================

--- Check if object is valid
-- @param obj table game object
-- @return boolean
function M.is_valid(obj)
    if not obj then return false end
    if type(obj.is_valid) == "function" then
        local ok, result = pcall(obj.is_valid, obj)
        if ok then return result end
    end
    return false
end

--- Get object name
-- @param obj table game object
-- @return string
function M.get_object_name(obj)
    if not M.is_valid(obj) then return "" end
    if type(obj.get_name) == "function" then
        local ok, result = pcall(obj.get_name, obj)
        if ok then return result or "" end
    end
    return ""
end

--- Get object position
-- @param obj table game object
-- @return table|nil {x, y, z}
function M.get_object_position(obj)
    if not M.is_valid(obj) then return nil end
    if type(obj.get_position) == "function" then
        local ok, result = pcall(obj.get_position, obj)
        if ok and result and type(result.x) == "number" then
            return result
        end
    end
    return nil
end

--- Get object yaw rotation (radians)
-- @param obj table game object
-- @return number|nil yaw in radians
function M.get_rotation(obj)
    if not M.is_valid(obj) then return nil end
    if type(obj.get_rotation) == "function" then
        local ok, result = pcall(obj.get_rotation, obj)
        if ok and type(result) == "number" then
            return result
        end
    end
    return nil
end

--- Get creator object (for bobber ownership)
-- @param obj table game object
-- @return table|nil creator object
function M.get_creator_object(obj)
    if not M.is_valid(obj) then return nil end
    if type(obj.get_creator_object) == "function" then
        local ok, result = pcall(obj.get_creator_object, obj)
        if ok then return result end
    end
    return nil
end

--- Check if bobber has fish
-- @param bobber table bobber object
-- @return boolean
function M.does_bobber_have_fish(bobber)
    if not M.is_valid(bobber) then return false end

    local debug_on = M._debug_on or false

    -- Try fish_helper — only trust a TRUE result
    local has_fish_helper, fish_helper = pcall(require, "common/utility/fish_helper")
    if has_fish_helper and fish_helper and fish_helper.does_bobber_have_fish then
        local ok, result = pcall(fish_helper.does_bobber_have_fish, fish_helper, bobber)
        -- Bite detected — log immediately (bypasses any throttle). Sylvanas
        -- currently always returns false, so this line only prints when they
        -- finally fix the API.
        if debug_on and ok and result == true then
            M.print("[EaxFishing][dbg] fish_helper BITE")
        end
        if ok and result == true then return true end
    end

    -- Fallback: call directly on the bobber object
    if type(bobber.does_bobber_have_fish) == "function" then
        local ok, result = pcall(bobber.does_bobber_have_fish, bobber)
        if debug_on and ok and result == true then
            M.print("[EaxFishing][dbg] bobber BITE")
        end
        if ok then return result == true end
    end

    return false
end

--- Check if object is a fishing bobber
-- @param obj table game object
-- @return boolean
function M.is_fish_bobber(obj)
    if not M.is_valid(obj) then return false end
    
    -- Try fish_helper first — but only trust a TRUE result from it.
    -- If fish_helper returns false, fall through to name check, because
    -- fish_helper may not recognise the object even when it is a valid bobber.
    local has_fish_helper, fish_helper = pcall(require, "common/utility/fish_helper")
    if has_fish_helper and fish_helper and fish_helper.is_fish_bobber then
        local ok, result = pcall(fish_helper.is_fish_bobber, fish_helper, obj)
        if ok and result == true then return true end
    end
    
    -- Name-based detection: lowercase contains match to handle locale variants.
    local name = M.get_object_name(obj)
    if type(name) == "string" and #name > 0 then
        local lower = string.lower(name)
        if string.find(lower, "bobber", 1, true)
        or string.find(lower, "float", 1, true) then
            return true
        end
    end
    
    return false
end

--- Check if player is dead
-- @param me table player object
-- @return boolean
function M.is_dead(me)
    if not M.is_valid(me) then return true end
    if type(me.is_dead) == "function" then
        local ok, result = pcall(me.is_dead, me)
        if ok then return result end
    end
    return false
end

--- Check if player is ghost
-- @param me table player object
-- @return boolean
function M.is_ghost(me)
    if not M.is_valid(me) then return true end
    if type(me.is_ghost) == "function" then
        local ok, result = pcall(me.is_ghost, me)
        if ok then return result end
    end
    return false
end

--- Check if player is in combat
-- @param me table player object
-- @return boolean
function M.is_in_combat(me)
    if not M.is_valid(me) then return false end
    if type(me.is_in_combat) == "function" then
        local ok, result = pcall(me.is_in_combat, me)
        if ok then return result end
    end
    return false
end

--- Check if player is casting
-- @param me table player object
-- @return boolean
function M.is_casting_spell(me)
    if not M.is_valid(me) then return false end
    if type(me.is_casting_spell) == "function" then
        local ok, result = pcall(me.is_casting_spell, me)
        if ok then return result end
    end
    return false
end

--- Check if player is channeling
-- @param me table player object
-- @return boolean
function M.is_channelling_spell(me)
    if not M.is_valid(me) then return false end
    if type(me.is_channelling_spell) == "function" then
        local ok, result = pcall(me.is_channelling_spell, me)
        if ok then return result end
    end
    return false
end

--- Check if player is moving
-- @param me table player object
-- @return boolean
function M.is_moving(me)
    if not M.is_valid(me) then return false end
    if type(me.is_moving) == "function" then
        local ok, result = pcall(me.is_moving, me)
        if ok then return result end
    end
    return false
end

--- Get player buffs
-- @param me table player object
-- @return table array of buffs
function M.get_buffs(me)
    if not M.is_valid(me) then return {} end
    if type(me.get_buffs) == "function" then
        local ok, result = pcall(me.get_buffs, me)
        if ok and type(result) == "table" then
            return result
        end
    end
    return {}
end

--- Get item at inventory slot
-- @param me table player object
-- @param slot number (16=main hand, 17=off hand)
-- @return table|nil {object, bag, slot}
function M.get_item_at_inventory_slot(me, slot)
    if not M.is_valid(me) then return nil end
    if type(me.get_item_at_inventory_slot) == "function" then
        local ok, result = pcall(me.get_item_at_inventory_slot, me, slot)
        if ok then
            return result
        end
    end
    return nil
end

--- Get item ID from inventory item object
-- @param item_obj table item object (from get_item_at_inventory_slot)
-- @return number|nil
function M.get_item_id_from_slot_item(item_obj)
    if not item_obj then return nil end
    if type(item_obj) == "table" and item_obj.object then
        if type(item_obj.object.get_item_id) == "function" then
            local ok, result = pcall(item_obj.object.get_item_id, item_obj.object)
            if ok and type(result) == "number" then
                return result
            end
        end
    end
    return nil
end

--- Get item name from inventory item object
-- @param item_obj table item object
-- @return string
function M.get_item_name_from_slot_item(item_obj)
    if not item_obj then return "" end
    if type(item_obj) == "table" and item_obj.object then
        if type(item_obj.object.get_name) == "function" then
            local ok, result = pcall(item_obj.object.get_name, item_obj.object)
            if ok then return result or "" end
        end
    end
    return ""
end

-- =============================================================================
-- INPUT APIs
-- =============================================================================

--- Cast target spell
-- @param spell_id number
-- @param target table game object
-- @return boolean success
function M.cast_target_spell(spell_id, target)
    if not (core and core.input and core.input.cast_target_spell) then
        return false
    end
    -- Try with provided target first
    local ok, err = pcall(core.input.cast_target_spell, spell_id, target)
    if ok then return true end
    -- Fishing is self-targeted on some builds; try without explicit target
    local ok2, err2 = pcall(core.input.cast_target_spell, spell_id)
    if ok2 then return true end
    print("[API Surface] cast_target_spell failed (spell=" .. tostring(spell_id)
        .. "): " .. tostring(err) .. " / " .. tostring(err2))
    return false
end

--- Use object (click)
-- @param obj table game object
-- @return boolean success
function M.use_object(obj)
    if not obj then return false end
    if core and core.input and core.input.use_object then
        local ok, err = pcall(core.input.use_object, obj)
        if ok then return true end
        print("[API Surface] use_object failed: " .. tostring(err))
    end
    return false
end

--- Look at position
-- @param pos table {x, y, z}
function M.look_at(pos)
    if not pos then return end
    if core and core.input and core.input.look_at then
        local ok, err = pcall(core.input.look_at, pos)
        if not ok then
            print("[API Surface] look_at failed: " .. tostring(err))
        end
    end
end

--- Jump (anti-AFK)
function M.jump()
    if core and core.input and core.input.jump then
        local ok, err = pcall(core.input.jump)
        if not ok then
            print("[API Surface] jump failed: " .. tostring(err))
        end
    end
end

--- Stop moving forward
function M.move_forward_stop()
    if core and core.input and core.input.move_forward_stop then
        local ok, err = pcall(core.input.move_forward_stop)
        if not ok then
            print("[API Surface] move_forward_stop failed: " .. tostring(err))
        end
    end
end

--- Repair all items (REPLACES banned core.vendor.repair_all)
-- @param merchant_open boolean
-- @return boolean success
function M.repair_all_items(merchant_open)
    if core and core.input and core.input.repair_all_items then
        local ok, err = pcall(core.input.repair_all_items, merchant_open or false)
        if ok then return true end
        print("[API Surface] repair_all_items failed: " .. tostring(err))
    end
    return false
end

--- Loot item at index (REPLACES banned core.input.loot_slot)
-- @param index number (0-based)
-- @return boolean success
function M.loot_item(index)
    -- Try fish_helper first (documented)
    local has_fish_helper, fish_helper = pcall(require, "common/utility/fish_helper")
    if has_fish_helper and fish_helper and fish_helper.loot_item then
        local ok, err = pcall(fish_helper.loot_item, fish_helper, index)
        if ok then return true end
    end
    
    -- Fallback to core.input.loot_item
    if core and core.input and core.input.loot_item then
        local ok, err = pcall(core.input.loot_item, index)
        if ok then return true end
    end
    
    return false
end

-- =============================================================================
-- INVENTORY APIs
-- =============================================================================

--- Get total repair cost
-- @return number copper
function M.get_total_repair_cost()
    if core and core.inventory and core.inventory.get_total_repair_cost then
        local ok, result = pcall(core.inventory.get_total_repair_cost)
        if ok and type(result) == "number" then
            return result
        end
    end
    return 0
end

--- Get player gold
-- @return number copper
function M.get_gold()
    if core and core.inventory and core.inventory.get_gold then
        local ok, result = pcall(core.inventory.get_gold)
        if ok and type(result) == "number" then
            return result
        end
    end
    return 0
end

--- Get number of bag slots for a specific bag
-- @param bag_id number bag slot index (0=backpack, 1-4=bags)
-- @return number number of slots in the bag
function M.get_num_bag_slots(bag_id)
    if core and core.inventory and core.inventory.get_num_bag_slots then
        local ok, result = pcall(core.inventory.get_num_bag_slots, bag_id)
        if ok and type(result) == "number" then
            return result
        end
    end
    return 0
end

--- Get items in bag
-- @param bag_id number
-- @return table array of items
function M.get_items_in_bag(bag_id)
    if core and core.inventory and core.inventory.get_items_in_bag then
        local ok, result = pcall(core.inventory.get_items_in_bag, bag_id)
        if ok and type(result) == "table" then
            return result
        end
    end
    return {}
end

-- =============================================================================
-- GAME UI APIs
-- =============================================================================

--- Get loot window item count
-- @return number
function M.get_loot_item_count()
    if core and core.game_ui and core.game_ui.get_loot_item_count then
        local ok, result = pcall(core.game_ui.get_loot_item_count)
        if ok and type(result) == "number" then
            return result
        end
    end
    return 0
end

--- Check if loot slot is gold
-- @param index number
-- @return boolean
function M.get_loot_is_gold(index)
    if core and core.game_ui and core.game_ui.get_loot_is_gold then
        local ok, result = pcall(core.game_ui.get_loot_is_gold, index)
        if ok then return result end
    end
    return false
end

--- Get loot item ID
-- @param index number
-- @return number|nil
function M.get_loot_item_id(index)
    if core and core.game_ui and core.game_ui.get_loot_item_id then
        local ok, result = pcall(core.game_ui.get_loot_item_id, index)
        if ok and type(result) == "number" then
            return result
        end
    end
    return nil
end

--- Get loot item name
-- @param index number
-- @return string
function M.get_loot_item_name(index)
    if core and core.game_ui and core.game_ui.get_loot_item_name then
        local ok, result = pcall(core.game_ui.get_loot_item_name, index)
        if ok then return result or "" end
    end
    return ""
end

-- =============================================================================
-- SPELL BOOK APIs
-- =============================================================================

--- Check if spell is learned
-- @param spell_id number
-- @return boolean
function M.is_spell_learned(spell_id)
    if core and core.spell_book and core.spell_book.is_spell_learned then
        local ok, result = pcall(core.spell_book.is_spell_learned, spell_id)
        if ok then return result end
    end
    return false
end

--- Get all learned spells
-- @return table array of spell IDs
function M.get_spells()
    if core and core.spell_book and core.spell_book.get_spells then
        local ok, result = pcall(core.spell_book.get_spells)
        if ok and type(result) == "table" then
            return result
        end
    end
    return {}
end

-- =============================================================================
-- IZI SDK
-- =============================================================================

--- Print message
-- @param message string
function M.print(message)
    local has_izi, izi = pcall(require, "common/izi_sdk")
    if has_izi and izi and izi.print then
        local ok, err = pcall(izi.print, message)
        if not ok then
            print(message)  -- Fallback to native print
        end
    else
        print(message)
    end
end

--- Get current timestamp
-- @return number
function M.now()
    local has_izi, izi = pcall(require, "common/izi_sdk")
    if has_izi and izi and izi.now then
        local ok, result = pcall(izi.now)
        if ok and type(result) == "number" then
            return result
        end
    end
    -- Fallback to os.time (less precise but functional)
    return os.time()
end

--- Get item reference
-- @param item_id number
-- @return table|nil item object
function M.get_item(item_id)
    local has_izi, izi = pcall(require, "common/izi_sdk")
    if has_izi and izi and izi.item then
        local ok, result = pcall(izi.item, item_id)
        if ok then
            return result
        end
    end
    return nil
end

--- Use item on self (safe)
-- @param item_id number
-- @return boolean success
function M.use_item_self_safe(item_id)
    local item = M.get_item(item_id)
    if not item then return false end
    
    -- Try safe method first
    if type(item.use_self_safe) == "function" then
        local ok, result = pcall(item.use_self_safe, item)
        if ok and result then return true end
    end
    
    -- Fallback to regular use_self
    if type(item.use_self) == "function" then
        local ok, result = pcall(item.use_self, item)
        if ok and result then return true end
    end
    
    return false
end

--- Use item on target (safe)
-- @param item_id number
-- @param target table game object
-- @return boolean success
function M.use_item_on_safe(item_id, target)
    local item = M.get_item(item_id)
    if not item then return false end
    
    -- Try safe method first
    if type(item.use_on_safe) == "function" then
        local ok, result = pcall(item.use_on_safe, item, target)
        if ok and result then return true end
    end
    
    -- Fallback to regular use_on
    if type(item.use_on) == "function" then
        local ok, result = pcall(item.use_on, item, target)
        if ok and result then return true end
    end
    
    return false
end

--- Get item count
-- @param item_id number
-- @return number
function M.get_item_count(item_id)
    -- Try izi.item first (works for bags 1-4)
    local item = M.get_item(item_id)
    if item and type(item.count) == "function" then
        local ok, result = pcall(item.count, item)
        if ok and type(result) == "number" and result > 0 then
            return result
        end
    end

    -- izi.item() does not reliably find items in the main backpack (bag 0).
    -- Scan all bags manually via core.inventory as fallback.
    if core and core.inventory and core.inventory.get_items_in_bag then
        for bag_id = 0, 4 do
            local ok, items = pcall(core.inventory.get_items_in_bag, bag_id)
            if ok and type(items) == "table" then
                for _, slot_item in ipairs(items) do
                    if slot_item and slot_item.object then
                        local ok2, id = pcall(slot_item.object.get_item_id, slot_item.object)
                        if ok2 and id == item_id then
                            return 1
                        end
                    end
                end
            end
        end
    end

    return 0
end

--- Get terrain height at position
-- @param x number
-- @param y number
-- @return number|nil
function M.get_terrain_height(x, y)
    -- Try coords_helper first
    local has_coords, coords_helper = pcall(require, "common/utility/coords_helper")
    if has_coords and coords_helper and coords_helper.get_terrain_height then
        local ok, result = pcall(coords_helper.get_terrain_height, coords_helper, x, y)
        if ok and type(result) == "number" then
            return result
        end
    end
    
    -- Try izi directly
    local has_izi, izi = pcall(require, "common/izi_sdk")
    if has_izi and izi and izi.get_terrain_height then
        local ok, result = pcall(izi.get_terrain_height, x, y)
        if ok and type(result) == "number" then
            return result
        end
    end
    
    -- Try core.get_height_for_position
    if core and core.get_height_for_position then
        local pos = {x = x, y = y, z = 0}
        local ok, result = pcall(core.get_height_for_position, pos)
        if ok and type(result) == "number" then
            return result
        end
    end
    
    return nil
end

-- =============================================================================
-- HELPER MODULES
-- =============================================================================

--- Get inventory helper
-- @return table|nil
function M.get_inventory_helper()
    local has_helper, helper = pcall(require, "common/utility/inventory_helper")
    if has_helper then
        return helper
    end
    return nil
end

--- Get total free bag slots (via helper)
-- @return number
function M.get_total_free_slots()
    local helper = M.get_inventory_helper()
    if helper and type(helper.get_total_free_slots) == "function" then
        local ok, result = pcall(helper.get_total_free_slots, helper)
        -- Only trust the helper result if it returns a positive number.
        -- A result of 0 is ambiguous: it could mean truly full bags OR
        -- the helper failing to read slots (e.g. during a loading screen).
        -- In that case we fall through to the manual count below.
        if ok and type(result) == "number" and result > 0 then
            return math.floor(result)
        end
    end

    -- Manual fallback: count free slots across all bags (0=backpack, 1-4)
    -- Uses only documented core.inventory APIs.
    if core and core.inventory and core.inventory.get_items_in_bag then
        local total_free = 0
        local found_any = false
        for bag_id = 0, 4 do
            local ok_slots, num_slots = pcall(core.inventory.get_num_bag_slots, bag_id)
            local ok_items, items = pcall(core.inventory.get_items_in_bag, bag_id)
            if ok_slots and type(num_slots) == "number" and num_slots > 0
               and ok_items and type(items) == "table" then
                found_any = true
                local used = #items
                total_free = total_free + math.max(0, num_slots - used)
            end
        end
        if found_any then
            return total_free
        end
    end

    -- If all APIs failed (loading screen, unsupported build, etc.)
    -- return 999 so we never false-stop on a "bags full" that isn't real.
    return 999
end

--- Get control panel helper
-- @return table|nil
function M.get_control_panel_helper()
    local has_helper, helper = pcall(require, "common/utility/control_panel_helper")
    if has_helper then
        return helper
    end
    return nil
end

--- Get coords helper
-- @return table|nil
function M.get_coords_helper()
    local has_helper, helper = pcall(require, "common/utility/coords_helper")
    if has_helper then
        return helper
    end
    return nil
end

--- Get fish helper
-- @return table|nil
function M.get_fish_helper()
    local has_helper, helper = pcall(require, "common/utility/fish_helper")
    if has_helper then
        return helper
    end
    return nil
end

-- =============================================================================
-- GRAPHICS APIs
-- =============================================================================

--- Draw 3D line
-- @param from table {x, y, z}
-- @param to table {x, y, z}
-- @param color table color object
-- @param thickness number
function M.draw_line_3d(from, to, color, thickness)
    if core and core.graphics and core.graphics.line_3d then
        local ok, err = pcall(core.graphics.line_3d, from, to, color, thickness)
        if not ok then
            print("[API Surface] line_3d failed: " .. tostring(err))
        end
    end
end

--- Draw 3D text
-- @param text string
-- @param pos table {x, y, z}
-- @param size number
-- @param color table color object
function M.draw_text_3d(text, pos, size, color)
    if core and core.graphics and core.graphics.text_3d then
        local ok, err = pcall(core.graphics.text_3d, text, pos, size, color)
        if not ok then
            print("[API Surface] text_3d failed: " .. tostring(err))
        end
    end
end

--- Draw 2D text
-- @param text string
-- @param pos table {x, y}
-- @param size number
-- @param color table color object
-- @param centered boolean
function M.draw_text_2d(text, pos, size, color, centered)
    if core and core.graphics and core.graphics.text_2d then
        local ok, err = pcall(core.graphics.text_2d, text, pos, size, color, centered)
        if not ok then
            print("[API Surface] text_2d failed: " .. tostring(err))
        end
    end
end

-- =============================================================================
-- HIGH-LEVEL HELPERS
-- =============================================================================

--- Find fishing bobber near player
-- @param ctx table context with deps
-- @param me table player object
-- @param px number player x
-- @param py number player y
-- @param pz number player z
-- @param range number search range (default 40)
-- @return table|nil bobber object
function M.find_bobber(ctx, me, px, py, pz, range)
    range = range or 40
    local range_sq = range * range
    local closest_owned = nil
    local closest_owned_dist = math.huge
    local closest_any = nil
    local closest_any_dist = math.huge

    -- Check debug mode
    local debug_on = ctx and ctx.deps and ctx.deps.config
        and ctx.deps.config.menu.debug
        and ctx.deps.config.menu.debug.get_state
        and ctx.deps.config.menu.debug:get_state()

    M._debug_on = debug_on  -- share with does_bobber_have_fish which has no ctx

    -- Throttle bobber-scan debug to once per 2s so enabling Debug Logging
    -- doesn't flood the console with 5+ lines per tick.
    local can_log = false
    if debug_on then
        local t = M.now()
        if t and t > (M._bobber_dbg_next or 0) then
            M._bobber_dbg_next = t + 2.0
            can_log = true
        end
    end

    local objects = M.get_all_objects()
    local my_name = M.get_object_name(me)

    if can_log then
        M.print("[EaxFishing][dbg] find_bobber: scanning " .. #objects .. " objects (me=" .. tostring(my_name) .. ")")
    end

    for _, obj in ipairs(objects) do
        if M.is_valid(obj) then
            local pos = M.get_object_position(obj)
            if pos then
                local dx = px - pos.x
                local dy = py - pos.y
                local dz = pz - pos.z
                local dist_sq = dx*dx + dy*dy + dz*dz

                if dist_sq < range_sq then
                    local name = M.get_object_name(obj)
                    if can_log and type(name) == "string" and #name > 0 then
                        -- Squared distance only (Pattern 3: avoid sqrt for comparisons; this is debug text)
                        M.print("[EaxFishing][dbg] nearby obj: '" .. name .. "' dist_sq=" .. string.format("%.0f", dist_sq))
                    end

                    if M.is_fish_bobber(obj) then
                        -- Track any bobber in range
                        if dist_sq < closest_any_dist then
                            closest_any_dist = dist_sq
                            closest_any = obj
                        end

                        -- Check ownership
                        if dist_sq < closest_owned_dist then
                            local creator = M.get_creator_object(obj)
                            if creator and M.is_valid(creator) then
                                local creator_name = M.get_object_name(creator)
                                if creator_name == my_name then
                                    closest_owned_dist = dist_sq
                                    closest_owned = obj
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if can_log then
        if closest_owned then
            M.print("[EaxFishing][dbg] find_bobber: found OWNED bobber")
        elseif closest_any then
            M.print("[EaxFishing][dbg] find_bobber: found unowned bobber (fallback)")
        else
            M.print("[EaxFishing][dbg] find_bobber: NO bobber found in range " .. range)
        end
    end

    -- Return owned bobber if found, otherwise any bobber
    return closest_owned or closest_any
end

--- Resolve fishing spell ID based on learned spells
-- @param fishing_ranks table array of spell IDs in priority order
-- @return number|nil spell_id
function M.resolve_fishing_spell(fishing_ranks)
    -- DBC-verified: 33095=Master, 18248=Artisan, 7732=Expert, 7731=Journeyman, 7620=Apprentice
    -- Spell 13147 was removed (does not exist in WoW 2.5.5 DBC).
    fishing_ranks = fishing_ranks or {33095, 18248, 7732, 7731, 7620}
    
    for _, spell_id in ipairs(fishing_ranks) do
        if M.is_spell_learned(spell_id) then
            return spell_id
        end
    end
    
    -- Fallback to Apprentice (always exists)
    return 7620
end

--- Check if can repair (has cost and gold)
-- @return boolean can_repair
-- @return number repair_cost
function M.can_repair()
    local cost = M.get_total_repair_cost()
    local gold = M.get_gold()
    return cost > 0 and gold >= cost, cost
end

-- =============================================================================
-- ITEM ENCHANT METHODS (for lure handling)
-- =============================================================================

--- Check if item has enchant
-- @param item_obj table item object
-- @return boolean
function M.item_has_enchant(item_obj)
    if not item_obj then return false end
    if type(item_obj.item_has_enchant) == "function" then
        local ok, result = pcall(item_obj.item_has_enchant, item_obj)
        if ok then return result end
    end
    return false
end

--- Get item enchant ID
-- @param item_obj table item object
-- @return number|nil
function M.item_enchant_id(item_obj)
    if not item_obj then return nil end
    if type(item_obj.item_enchant_id) == "function" then
        local ok, result = pcall(item_obj.item_enchant_id, item_obj)
        if ok and type(result) == "number" then
            return result
        end
    end
    return nil
end

--- Get item enchant expiration
-- @param item_obj table item object
-- @return number|nil
function M.item_enchant_expiration(item_obj)
    if not item_obj then return nil end
    if type(item_obj.item_enchant_expiration) == "function" then
        local ok, result = pcall(item_obj.item_enchant_expiration, item_obj)
        if ok and type(result) == "number" then
            return result
        end
    end
    return nil
end

--- Get item enchant charges
-- @param item_obj table item object
-- @return number|nil
function M.item_enchant_charges(item_obj)
    if not item_obj then return nil end
    if type(item_obj.item_enchant_charges) == "function" then
        local ok, result = pcall(item_obj.item_enchant_charges, item_obj)
        if ok and type(result) == "number" then
            return result
        end
    end
    return nil
end

-- =============================================================================
-- SOUND
-- =============================================================================

--- Play a game sound by ID
-- @param id number sound ID
function M.play_sound_by_id(id)
    if core and core.play_sound_by_id then
        local ok, err = pcall(core.play_sound_by_id, id)
        if not ok then
            print("[API Surface] play_sound_by_id failed: " .. tostring(err))
        end
    end
end

-- =============================================================================
-- COLOR MODULE
-- =============================================================================

--- Create color object
-- @param r number red (0-255)
-- @param g number green (0-255)
-- @param b number blue (0-255)
-- @param a number alpha (0-255)
-- @return table color object
function M.color_new(r, g, b, a)
    local has_color, color = pcall(require, "common/color")
    if has_color and color and color.new then
        local ok, result = pcall(color.new, r, g, b, a)
        if ok then return result end
    end
    -- Fallback: return a simple table
    return {r = r or 255, g = g or 255, b = b or 255, a = a or 255}
end

return M
