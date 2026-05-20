
---@class core
_G.core = {}

---@alias game_objects_table game_object[]
---@alias item_slot_info_table item_slot_info[]
---@alias spell_costs_table spell_costs[]
---@alias buff_table buff[]
---@alias vec3_table vec3[]
---@alias vec2_table vec2[]
---@alias hit_data_table hit_data[]
---@alias consumable_data_table consumable_data[]

--- Log a message to the console.
---@param message string The message to log.
function core.log(message) end

--- Log a warning message to the console.
---@param message string The warning message to log.
function core.log_warning(message) end

--- Log an error message to the console.
---@param message string The error message to log.
function core.log_error(message) end

--- Register a function to be called before each tick.
---@param callback function The function to register as a pre-tick callback.
function core.register_on_pre_tick_callback(callback) end

--- Register a function to be called before each tick.
---@param callback function The function to register as a pre-tick callback.
function core.register_on_render_window_callback(callback) end

--- Register a function to be called during the update phase.
---@param callback function The function to register as an update callback.
function core.register_on_update_callback(callback) end

--- Register a function to be called during the rendering phase.
---@param callback function The function to register as a render callback.
function core.register_on_render_callback(callback) end

--- Register a function to be called during the rendering of menus.
---@param callback function The function to register as a render menu callback.
function core.register_on_render_menu_callback(callback) end

--- Register a function to be called to send control_panel data to core
---@param callback function The function to register as a control_panel callback
function core.register_on_render_control_panel_callback(callback) end

--- Register a function that triggers every time game registers a legit cast attempt
---@param callback function The function to register as a legit cast callback
function core.register_on_legit_spell_cast_callback(callback) end

---@class OnProcessSpellCastData
--- Defines the structure of the data table passed to the on_process_spell callback.
---@field spell_id number        -- Unique identifier for the spell.
---@field caster game_object|nil -- The game object that cast the spell (or nil).
---@field target game_object|nil -- The game object targeted by the spell (or nil).
---@field spell_cast_time number -- The time when the spell was cast.

--- Registers a callback to be triggered when a spell is cast.
--- The callback function receives a OnProcessSpellCastData table as a parameter.
---@param callback fun(data: OnProcessSpellCastData): nil
function core.register_on_spell_cast_callback(callback) end

--- Get the current ping.
---@return number The current ping.
function core.get_ping()
    return 0
end

--- Get the current time in seconds since the injection time.
---@return number The current time in seconds.
function core.time()
    return 0
end

--- Useful for profiling
---@return number
function core.cpu_ticks()
    return 0
end

--- Useful for profiling
---@return number
function core.cpu_ticks_per_second()
    return 0
end

--- Returns a high-resolution CPU timestamp in nanoseconds. Useful for profiling.
---@return number nanoseconds The CPU time in nanoseconds.
function core.cpu_time()
    return 0
end

--- Get the current game time in milliseconds since the start of the game.
---@return number The current game time in milliseconds.
function core.game_time()
    return 0
end

--- Get the time in seconds since the last frame.
---@return number The time in seconds since the last frame.
function core.delta_time()
    return 0
end

--- Get the screen position of cursor.
---@return vec2 The screen position of cursor.
function core.get_cursor_position()
    return {}
end

--- Get the id of the current localplayer map.
---@return number The id of the current localplayer map.
function core.get_map_id()
    return 0
end

---@return number
function core.get_instance_id()
    return 0
end

---@return number
function core.get_difficulty_id()
    return 0
end

---@return number
function core.get_keystone_level()
    return 0
end

---@return string
function core.get_instance_name()
    return ""
end

---@return string
function core.get_difficulty_name()
    return ""
end

---@return string
function core.get_instance_type()
    return ""
end

--- Get the name of the current localplayer map.
---@return string The name of the current localplayer map.
function core.get_map_name()
    return ""
end

---@return number
---@param pos vec3
function core.get_height_for_position(pos)
    return 0
end

---@return boolean
function core.is_main_menu_open()
    return false
end

---@return string
---Returns "Midnight", "Tbc", "Vanilla", "Mop", "Titan"
function core.get_game_version()
    return ""
end

--- Returns the exact game version string (e.g. "wow_tbc_cn", "wow_tbc_ps", "wow_tbc_us", "wow_titan_cn", "wow_midnight_us").
---@return string version The exact game version.
function core.get_exact_game_version()
    return ""
end

---@return string
---Returns "West", "China"
function core.get_game_region()
    return ""
end

---@return nil
--- Set Game Window Foremost
function core.set_window_foremost()
    return nil
end

--------------------------------------------------------------------------------
-- Sandbox file I O
--
-- This scripting environment is sandboxed on purpose to prevent malicious code.
-- You can only interact with files in two allowed locations:
--
-- 1) Game files, inside the World of Warcraft installation folder
--    Used by: core.read_file, core.read_file_partial, core.get_file_size
--
-- 2) Loader data files, inside the loader's scripts_data folder
--    Used by: core.create_data_file, core.create_data_folder, core.write_data_file
--             core.read_data_file, core.read_data_file_partial, core.get_data_file_size
--
-- Any attempt to access files outside these locations will fail.
--------------------------------------------------------------------------------

--- Reads the entire contents of a sandboxed game file.
---
--- Sandbox scope:
--- - Only files inside the World of Warcraft installation folder are accessible.
--- - Any path outside the WoW folder is blocked.
---
--- Path rules:
--- - `filename` is treated as a path inside the WoW folder.
--- - Use relative-style paths such as `Data/...` or `_retail_/...` depending on your client layout.
---
--- Returns:
--- - On success: the full file contents as a Lua string.
--- - On failure: typically an empty string or nil depending on native implementation.
---
--- Example:
--- ```lua
--- local text = core.read_file("_retail_/WTF/Config.wtf")
--- print("Config length:", #text)
--- ```
---
---@param filename string Path inside the World of Warcraft folder (UTF-8).
---@return string data The file contents as a Lua string.
function core.read_file(filename)
    return ""
end

--- Reads a portion of a sandboxed game file, starting at a byte offset.
---
--- Sandbox scope:
--- - Only files inside the World of Warcraft installation folder are accessible.
--- - Any path outside the WoW folder is blocked.
--- - Returns nil if the file cannot be read (missing, outside scope, access denied, etc).
---
--- Path rules:
--- - `filename` is treated as a path inside the WoW folder.
--- - Use relative-style paths such as `Data/...` or `_retail_/...` depending on your client layout.
---
--- Notes:
--- - `offset` and `size_to_read` are in bytes.
--- - The returned string can contain binary data and may include zero bytes.
---
--- Example:
--- ```lua
--- local p = "_retail_/WTF/Config.wtf"
--- local chunk = core.read_file_partial(p, 0, 64)
--- if chunk then
---   print("First 64 bytes:", chunk)
--- else
---   print("Read failed (outside sandbox, missing, or access denied).")
--- end
--- ```
---
---@param filename string Path inside the World of Warcraft folder (UTF-8).
---@param offset integer Byte offset to start reading from.
---@param size_to_read integer Number of bytes to read.
---@return string|nil data The read bytes as a Lua string, or nil on failure.
function core.read_file_partial(filename, offset, size_to_read)
    return ""
end

--- Gets the size of a sandboxed game file in bytes.
---
--- Sandbox scope:
--- - Only files inside the World of Warcraft installation folder are accessible.
--- - Any path outside the WoW folder is blocked.
---
--- Notes:
--- - If the file does not exist or is not accessible, the native side may return 0.
--- - If you need to distinguish "missing" vs "empty file", attempt a small read as well.
---
--- Example:
--- ```lua
--- local p = "_retail_/WTF/Config.wtf"
--- local size = core.get_file_size(p)
--- if size > 0 then
---   print("Config size:", size)
--- else
---   print("Missing, blocked, or empty file.")
--- end
--- ```
---
---@param filename string Path inside the World of Warcraft folder (UTF-8).
---@return integer size The file size in bytes.
function core.get_file_size(filename)
    return 0
end

--- Creates a new data file inside the loader's `scripts_data/` directory.
---
--- Sandbox scope:
--- - Data files are stored under: `<loader_path>/scripts_data/`
--- - Only this directory is writable by scripts (by design).
---
--- Path rules:
--- - `filename` is relative to `scripts_data/`.
--- - Do not prefix with `scripts_data/` yourself.
---
--- Notes:
--- - Parent folders should exist. Use core.create_data_folder for subfolders if needed.
---
--- Example:
--- ```lua
--- core.create_data_file("settings.json")
--- core.write_data_file("settings.json", "{}")
--- ```
---
---@param filename string Path inside `scripts_data/` (UTF-8), relative to the loader data directory.
---@return nil
function core.create_data_file(filename)
    return nil
end

--- Creates a folder inside the loader's `scripts_data/` directory.
---
--- Sandbox scope:
--- - Folders are created under: `<loader_path>/scripts_data/`
--- - Only this directory is writable by scripts (by design).
---
--- Path rules:
--- - `folder` is relative to `scripts_data/`.
--- - Do not prefix with `scripts_data/` yourself.
---
--- Example:
--- ```lua
--- core.create_data_folder("profiles")
--- core.create_data_file("profiles/user1.json")
--- ```
---
---@param folder string Folder path inside `scripts_data/` (UTF-8), relative to the loader data directory.
---@return nil
function core.create_data_folder(folder)
    return nil
end

--- Writes data to a loader data file inside `scripts_data/`.
---
--- Sandbox scope:
--- - Files are written under: `<loader_path>/scripts_data/`
--- - Only this directory is writable by scripts (by design).
---
--- Path rules:
--- - `filename` is relative to `scripts_data/`.
--- - Do not prefix with `scripts_data/` yourself.
---
--- Notes:
--- - The write behavior (overwrite vs append) depends on native implementation.
---   In most systems this overwrites the file.
---
--- Example:
--- ```lua
--- core.write_data_file("cache/state.txt", "last_login=123")
--- ```
---
---@param filename string Path inside `scripts_data/` (UTF-8), relative to the loader data directory.
---@param data string The data to write into the file.
---@return nil
function core.write_data_file(filename, data)
    return nil
end

--- Reads the entire contents of a loader data file from `scripts_data/`.
---
--- Sandbox scope:
--- - Files are read from: `<loader_path>/scripts_data/`
--- - You cannot access arbitrary PC files via this API.
---
--- Path rules:
--- - `filename` is relative to `scripts_data/`.
--- - Do not prefix with `scripts_data/` yourself.
---
--- Notes:
--- - Returned string can contain binary data.
--- - If the file cannot be read, the native side may return an empty string or nil depending on implementation.
---
--- Example:
--- ```lua
--- local json = core.read_data_file("settings.json")
--- if json and #json > 0 then
---   print("settings.json:", json)
--- end
--- ```
---
---@param filename string Path inside `scripts_data/` (UTF-8), relative to the loader data directory.
---@return string data The file contents as a Lua string.
function core.read_data_file(filename)
    return ""
end

--- Creates a new log file.
---
--- Purpose:
--- - Log files are intended for diagnostics and debugging output.
--- - The exact storage location is implementation-defined by the loader.
---
--- Notes:
--- - If the log file already exists, the native side may truncate it or keep it, depending on implementation.
---
--- Example:
--- ```lua
--- core.create_log_file("combat.log")
--- core.write_log_file("combat.log", "addon started")
--- ```
---
---@param filename string The name of the log file to create.
---@return nil
function core.create_log_file(filename)
    return nil
end

--- Creates a folder inside the loader's `scripts_log/` directory.
---
--- Sandbox scope:
--- - Folders are created under: `<loader_path>/scripts_log/`
--- - Only this directory is writable by scripts for logging (by design).
---
--- Path rules:
--- - `folder` is relative to `scripts_log/`.
--- - Do not prefix with `scripts_log/` yourself.
---
--- Notes:
--- - Intermediate segments are created automatically (path is walked segment by segment).
---
--- Example:
--- ```lua
--- core.create_log_folder("my_addon")
--- core.create_log_file("my_addon/combat.log")
--- ```
---
---@param folder string Folder path inside `scripts_log/` (UTF-8), relative to the loader log directory.
---@return boolean success `true` if the folder (and any missing parents) was created or already exists.
function core.create_log_folder(folder)
    return true
end

--- Writes a message to a log file.
---
--- Purpose:
--- - Use this for debug output that should persist outside the in-game console.
---
--- Notes:
--- - Whether a newline is automatically appended depends on native implementation.
---   If you want one, include "\n" yourself.
---
--- Example:
--- ```lua
--- core.write_log_file("combat.log", "Target acquired: " .. tostring(unit_name) .. "\n")
--- ```
---
---@param filename string The name of the log file to write to.
---@param message string The message to write into the log file.
---@return nil
function core.write_log_file(filename, message)
    return nil
end

--- Lists entry names (files and folders) inside a `scripts_log/` subdirectory.
---
--- Sandbox scope:
--- - Only reads from: `<loader_path>/scripts_log/<dir_name>/`
--- - Returns nil on failure (missing directory, path escape, etc).
---
---@param dir_name string Subdirectory name inside `scripts_log/` (UTF-8).
---@return string[]|nil entries Array of entry names, or nil on failure.
function core.read_log_dir(dir_name)
    return nil
end

--- Recursively deletes a folder and all its contents under `scripts_log/`.
---
--- Sandbox scope:
--- - Only deletes inside: `<loader_path>/scripts_log/`
--- - Path traversal attempts are rejected (returns false).
---
---@param folder_path string Folder path inside `scripts_log/` (UTF-8).
---@return boolean success `true` if the folder was deleted successfully.
function core.delete_log_folder(folder_path)
    return true
end

--- Returns the local system date and time as a table.
---
--- Useful in sandboxed Lua where `os.date()` / `os.time()` are unavailable.
---
---@return { year: integer, month: integer, day: integer, hour: integer, minute: integer, second: integer }
function core.get_local_time()
    return { year = 2025, month = 1, day = 1, hour = 0, minute = 0, second = 0 }
end

--- Reads a portion of a loader data file from `scripts_data/`, starting at a byte offset.
---
--- Sandbox scope:
--- - Files are read from: `<loader_path>/scripts_data/`
--- - You cannot access arbitrary PC files via this API.
--- - Returns nil if the data file cannot be read (missing, not permitted, etc).
---
--- Path rules:
--- - `filename` is resolved relative to `scripts_data/`.
--- - Do not prefix with `scripts_data/` yourself.
---
--- Notes:
--- - `offset` and `size_to_read` are in bytes.
--- - The returned string can contain binary data and may include zero bytes.
---
--- Example:
--- ```lua
--- local name = "settings.json" -- resolved as: <loader_path>/scripts_data/settings.json
--- local chunk = core.read_data_file_partial(name, 0, 256)
--- if chunk then
---   print("JSON header:", chunk)
--- else
---   print("Read failed (missing or blocked).")
--- end
--- ```
---
---@param filename string Path inside `scripts_data/` (UTF-8), relative to the loader data directory.
---@param offset integer Byte offset to start reading from.
---@param size_to_read integer Number of bytes to read.
---@return string|nil data The read bytes as a Lua string, or nil on failure.
function core.read_data_file_partial(filename, offset, size_to_read)
    return ""
end

--- Gets the size of a loader data file in bytes, from `scripts_data/`.
---
--- Sandbox scope:
--- - Only files inside the loader's `scripts_data/` directory are accessible.
---
--- Notes:
--- - If the file does not exist or is not accessible, the native side may return 0.
--- - If you need to distinguish "missing" vs "empty file", attempt a small partial read as well.
---
--- Example:
--- ```lua
--- local name = "settings.json"
--- local size = core.get_data_file_size(name)
--- if size > 0 then
---   print("settings.json size:", size)
--- else
---   print("Missing, blocked, or empty file.")
--- end
--- ```
---
---@param filename string Path inside `scripts_data/` (UTF-8), relative to the loader data directory.
---@return integer size The file size in bytes.
function core.get_data_file_size(filename)
    return 0
end

--- Lists all files and folders in a directory inside `scripts_data/`.
---
--- Sandbox scope:
--- - Only directories inside the loader's `scripts_data/` directory are accessible.
--- - Any path outside `scripts_data/` will return nil.
---
--- Path rules:
--- - `directory` is relative to `scripts_data/`.
--- - Do not prefix with `scripts_data/` yourself.
--- - Use forward slashes or backslashes as path separators.
---
--- Returns:
--- - On success: a table (array) of file names in the directory.
--- - On failure: nil (path outside sandbox, doesn't exist, or not a directory).
---
--- Notes:
--- - Only returns file/folder names, not full paths.
--- - Includes both files and subdirectories.
--- - Does not include "." or ".." entries.
---
--- Example:
--- ```lua
--- local files = core.read_dir("profiles")
--- if files then
---   for i, name in ipairs(files) do
---     print("Found: " .. name)
---   end
--- else
---   print("Directory not found or outside sandbox")
--- end
--- ```
---
---@param directory string Directory path inside `scripts_data/` (UTF-8), relative to the loader data directory.
---@return string[]|nil files Array of file/folder names, or nil on failure.
function core.read_dir(directory)
    return nil
end

--- Deletes a file inside the World of Warcraft installation folder.
---@param filename string Path inside the WoW folder (UTF-8).
---@return boolean success True if the file was deleted successfully.
function core.delete_file(filename)
    return false
end

--- Deletes a log file from the `scripts_log/` directory.
---@param filename string The log file name to delete.
---@return boolean success True if the file was deleted successfully.
function core.delete_log_file(filename)
    return false
end

--- Deletes a data file from the `scripts_data/` directory.
---@param filename string The data file name to delete.
---@return boolean success True if the file was deleted successfully.
function core.delete_data_file(filename)
    return false
end

---@param id number
---@return nil
function core.play_sound_by_id(id)
    return nil
end

--- Return if the player is typing something in any textbox like chat, aka is_chat_open, but scalable to other stuff of the game interface and including all addons hopefully
---@return boolean
function core.is_textbox_focused()
    return false
end

---@class inventory
core.inventory = {}

--- -2 for the keyring
--- -4 for the tokens bag
--- 0 = backpack, 1 to 4 for the bags on the character
--- While bank is opened -1 for the bank content, 5 to 11 for bank bags (numbered left to right, was 5-10 prior to tbc expansion, 2.0 game version)
---@param bag_id integer BagId https://wowwiki-archive.fandom.com/wiki/BagId
---@return item_slot_info_table
function core.inventory.get_items_in_bag(bag_id)
    return {}
end

--- Returns the total number of slots a bag has.
--- @param bag_id integer Bag ID (1 to 4 for character bags)
--- @return integer num_slots Number of slots in the bag (0 if no bag equipped)
function core.inventory.get_num_bag_slots(bag_id)
    return 0
end

--- Returns the total cost in copper to repair all equipped items.
--- @return integer cost Repair cost in copper (0 if nothing to repair)
function core.inventory.get_total_repair_cost()
    return 0
end

--- Returns the local player's current gold in copper.
--- @return integer copper Total money in copper
function core.inventory.get_gold()
    return 0
end

---@class game_ui
core.game_ui = {}

--- Get the count of lootable items.
---@return number The number of lootable items.
function core.game_ui.get_loot_item_count()
    return 0
end

--- Check if a loot item is gold.
---@param index integer The index of the loot item.
---@return boolean True if the loot item is gold, false otherwise.
function core.game_ui.get_loot_is_gold(index)
    return false
end

--- Get the item ID of a lootable item.
---@param index integer The index of the loot item.
---@return number The item ID of the lootable item.
function core.game_ui.get_loot_item_id(index)
    return 0
end

--- Get the name of a lootable item.
---@param index integer The index of the loot item.
---@return string The name of the lootable item.
function core.game_ui.get_loot_item_name(index)
    return ""
end

--- @return string
--- @param index number
--- confirm, queued, none, error, active
function core.game_ui.get_battlefield_status(index)
    return ""
end

--- @return number
--- 2 Prep | 3 Action | 5 Finished
function core.game_ui.get_battlefield_state()
    return 0
end

--- @return vec2
--- @param map_id number
--- @param map_pos vec2
--- Returns vec2 x / y in 3dworld format, just missing z height
function core.game_ui.get_world_pos_from_map_pos(map_id, map_pos)
    return {}
end

--- Get the current WoW cursor position.
---@return vec2 The cursor position in UI coordinates.
function core.game_ui.get_wow_cursor_position()
    return {}
end

--- Get the current cursor position in normalized coordinates.
---@return vec2 The cursor position normalized (0-1 range).
function core.game_ui.get_normalized_cursor_position()
    return {}
end

--- Normalize a UI position.
---@param pos vec2 The UI position to normalize.
---@return vec2 The normalized position (0-1 range).
function core.game_ui.normalize_ui_position(pos)
    return {}
end

--- @return number
--- Timer in MS Since the battlefield started
function core.game_ui.get_battlefield_run_time()
    return 0
end

--- @return number|nil
--- NIL NONE | 0 Horde | 1 Ally | 2 Tie
function core.game_ui.get_battlefield_winner()
    return nil
end

--- @return number
function core.game_ui.get_current_map_id()
    return 0
end

--- @return boolean
--- Returns true if the world map is currently open.
function core.game_ui.is_map_open()
    return false
end

--- Returns the top-left corner of the world map frame in UI coordinates.
---@return vec2 The top-left position of the map in UI coordinates.
function core.game_ui.get_map_top_left()
    return {}
end

--- Returns the bottom-right corner of the world map frame in UI coordinates.
---@return vec2 The bottom-right position of the map in UI coordinates.
function core.game_ui.get_map_bottom_right()
    return {}
end

--- Converts a UI-space position to screen-space pixel coordinates.
---@param ui_pos vec2 The position in UI coordinates.
---@return vec2 The corresponding screen-space position in pixels.
function core.game_ui.ui_pos_to_screen_pos(ui_pos)
    return {}
end

---@param world_pos vec3
---@return vec2
function core.game_ui.world_pos_to_map_pos_normalized(world_pos)
    return {}
end

--- Returns the delay in seconds until the player can resurrect at their corpse.
---@return number delay The remaining delay in seconds (0 if ready).
function core.game_ui.get_resurrect_corpse_delay()
    return 0
end

--- Returns the position of the player's corpse in the world.
---@return vec3 The corpse position.
function core.game_ui.get_corpse_position()
    return {}
end

--- Returns the effective UI scale factor.
---@return number The effective scale.
function core.game_ui.get_effective_scale()
    return 0
end

---@class vendor_item_info
---@field cost integer The cost of the item in copper.
---@field is_usable boolean Whether the item is usable by the player.
---@field item_id integer The item ID.
---@field item_name string The name of the item.
---@field quantity integer The quantity available.
---@field vendor_item_index integer The vendor slot index.

--- Returns information about a specific vendor item.
--- Note: vendor_item_id is 1-indexed (internally adjusted to 0-indexed).
---@param vendor_item_id integer The 1-based index of the vendor item.
---@return vendor_item_info A table containing the vendor item information.
function core.game_ui.get_vendor_item_info(vendor_item_id)
    return {}
end

--- Returns the total number of items the current vendor has for sale.
---@return integer The number of vendor items.
function core.game_ui.get_vendor_item_count()
    return 0
end

--- Returns a table containing all completed quest IDs for the local player.
---@return integer[] An array of completed quest IDs.
function core.game_ui.get_all_completed_quest_ids()
    return {}
end

--- Resets all instances for the local player.
---@return nil
function core.game_ui.reset_instances()
    return nil
end

---@class tooltip_info
---@field type string The tooltip type: "unit", "spell", "item", or "".
---@field id integer The ID (NPC ID, spell ID, or item ID).
---@field name string The tooltip name.
---@field num_lines integer The number of tooltip lines.

--- Returns the current GameTooltip information.
---@return tooltip_info info A table with type, id, name, and num_lines.
function core.game_ui.get_tooltip_info()
    return {}
end

--- Deprecated. Removed from core.game_ui on May 10, 2026 and will be nil at runtime.
--- IMPORTANT: Do not call this function. It no longer exists in core 1.930+.
---@deprecated Removed on May 10, 2026. This field is nil in core 1.930+.
core.game_ui.setup_tooltip_processor = nil

--- Deprecated. Removed from core.game_ui on May 10, 2026 and will be nil at runtime.
--- IMPORTANT: Do not call this function. It no longer exists in core 1.930+.
---@deprecated Removed on May 10, 2026. This field is nil in core 1.930+.
core.game_ui.set_tooltip_npc_id = nil

--- Adds a colored line to the GameTooltip.
---@param text string The line text.
---@param r number|nil Red component (0-1, default 1.0).
---@param g number|nil Green component (0-1, default 1.0).
---@param b number|nil Blue component (0-1, default 0.0).
---@return nil
function core.game_ui.add_tooltip_line(text, r, g, b)
    return nil
end

--- Adds a double-line (left + right) to the GameTooltip.
---@param left_text string The left-side text.
---@param right_text string The right-side text.
---@param lr number|nil Left red component (0-1, default 1.0).
---@param lg number|nil Left green component (0-1, default 1.0).
---@param lb number|nil Left blue component (0-1, default 0.0).
---@param rr number|nil Right red component (0-1, default 1.0).
---@param rg number|nil Right green component (0-1, default 1.0).
---@param rb number|nil Right blue component (0-1, default 1.0).
---@return nil
function core.game_ui.add_tooltip_double_line(left_text, right_text, lr, lg, lb, rr, rg, rb)
    return nil
end

--- Returns whether the ping system is currently enabled.
---@return boolean enabled True if the ping system is enabled, false otherwise.
function core.game_ui.is_ping_enabled()
    return false
end

--- Sends a ping, optionally targeting a game object.
---@param ping_type? integer The ping type ID. Pass -1 or omit for default contextual ping.
---@param target? game_object The target game object to ping on. Omit for a contextual ping at the cursor.
function core.game_ui.send_ping(ping_type, target)
end

--- Starts a countdown timer in the party/raid.
---@param seconds integer The countdown duration in seconds.
---@return boolean success Whether the countdown was started successfully.
function core.game_ui.do_countdown(seconds)
    return false
end

--- Returns talent information for a given talent position.
--- Classic: pass tab_index, talent_index, and optionally is_inspect.
--- Retail: pass tier, column, and optionally spec_group_index.
---@class talent_info_classic
---@field name string The talent name.
---@field texture integer The icon texture ID.
---@field tier integer The talent tier.
---@field column integer The talent column.
---@field rank integer The current rank.
---@field max_rank integer The maximum rank.
---@field is_exceptional boolean Whether the talent is exceptional.
---@field available boolean Whether the talent is available.

---@class talent_info_retail
---@field talent_id integer The talent ID.
---@field name string The talent name.
---@field texture integer The icon texture ID.
---@field selected boolean Whether the talent is selected.
---@field available boolean Whether the talent is available.
---@field spell_id integer The spell ID associated with the talent.
---@field row integer The talent row.
---@field column integer The talent column.
---@field known boolean Whether the talent is known.

---@param arg1 integer Tab index (classic) or tier (retail).
---@param arg2 integer Talent index (classic) or column (retail).
---@param arg3? integer Is inspect (classic) or spec group index (retail).
---@return talent_info_classic|talent_info_retail info The talent information table.
function core.game_ui.get_talent_info(arg1, arg2, arg3)
    return {}
end

--- Returns all active talent nodes for the player (retail 10.0+ only).
--- Falls back to an empty table on classic.
---@class active_talent_entry
---@field node_id integer The talent node ID.
---@field spell_id integer The spell ID associated with the talent.
---@field name string The talent name.
---@field rank integer The current rank purchased.
---@field max_rank integer The maximum rank available.

---@return active_talent_entry[] talents Array of active talent entries.
function core.game_ui.get_active_talents()
    return {}
end

--- Deprecated. Removed from core.game_ui on May 10, 2026 and will be nil at runtime.
--- IMPORTANT: Do not call this function. It no longer exists in core 1.930+.
---@deprecated Removed on May 10, 2026. This field is nil in core 1.930+.
core.game_ui.show_context_menu = nil

--- Deprecated. Removed from core.game_ui on May 10, 2026 and will be nil at runtime.
--- IMPORTANT: Do not call this function. It no longer exists in core 1.930+.
---@deprecated Removed on May 10, 2026. This field is nil in core 1.930+.
core.game_ui.get_context_menu_result = nil

--- Deprecated. Removed from core.game_ui on May 10, 2026 and will be nil at runtime.
--- IMPORTANT: Do not call this function. It no longer exists in core 1.930+.
---@deprecated Removed on May 10, 2026. This field is nil in core 1.930+.
core.game_ui.add_unit_menu_button = nil

--- Deprecated. Removed from core.game_ui on May 10, 2026 and will be nil at runtime.
--- IMPORTANT: Do not call this function. It no longer exists in core 1.930+.
---@deprecated Removed on May 10, 2026. This field is nil in core 1.930+.
core.game_ui.set_unit_menu_button_text = nil

--- Deprecated. Removed from core.game_ui on May 10, 2026 and will be nil at runtime.
--- IMPORTANT: Do not call this function. It no longer exists in core 1.930+.
---@deprecated Removed on May 10, 2026. This field is nil in core 1.930+.
core.game_ui.remove_unit_menu_button = nil

--- Deprecated. Removed from core.game_ui on May 10, 2026 and will be nil at runtime.
--- IMPORTANT: Do not call this function. It no longer exists in core 1.930+.
---@deprecated Removed on May 10, 2026. This field is nil in core 1.930+.
core.game_ui.poll_unit_menu_click = nil

--- Adds a custom button to all unit right-click context menus.
--- The button appears in menus for players, targets, focus, party, raid, arena, boss, pet, and vehicle units.
--- Poll for clicks with poll_unit_menu_click().
---@param text string The button label text.
---@return integer id The button ID used to update, remove, or identify clicks.
function core.game_ui.add_unit_menu_button(text)
    return 0
end

--- Updates the label text of an existing unit menu button.
---@param id integer The button ID returned by add_unit_menu_button.
---@param text string The new button label text.
---@return nil
function core.game_ui.set_unit_menu_button_text(id, text)
    return nil
end

--- Removes a unit menu button entirely.
---@param id integer The button ID returned by add_unit_menu_button.
---@return nil
function core.game_ui.remove_unit_menu_button(id)
    return nil
end

--- Polls the oldest queued unit menu button click.
--- Returns nil if no clicks are pending.
---@class unit_menu_click_result
---@field button_id integer The ID of the button that was clicked.
---@field unit_token string The unit token (e.g. "target", "party1").
---@field unit_name string The unit's name.
---@field unit_guid string The unit's GUID.
---@field menu_tag string The menu context tag (e.g. "MENU_UNIT_PLAYER").

---@return unit_menu_click_result|nil result The click info table, or nil if no clicks pending.
function core.game_ui.poll_unit_menu_click()
    return nil
end

---@class character
core.character = {}

--- Returns the combat rating bonus for a given rating index.
--- The rating index corresponds to the combat rating type (e.g., crit, haste, mastery, etc.).
---@param rating_index integer The combat rating index.
---@return number The combat rating bonus value.
function core.character.get_combat_rating_bonus(rating_index)
    return 0
end

--- Returns the combat rating bonus for a specific combat rating value.
--- Useful for calculating what bonus a hypothetical rating value would provide.
---@param rating_index integer The combat rating index.
---@param value integer The combat rating value to calculate the bonus for.
---@return number The combat rating bonus for the given value.
function core.character.get_combat_rating_bonus_for_combat_rating_value(rating_index, value)
    return 0
end

---@class world
core.world = {}

--- Returns whether the current area allows regular flying.
---@return boolean True if the area is flyable, false otherwise.
function core.world.is_flyable_area()
    return false
end

--- Returns whether the current area allows advanced (dynamic/skyriding) flying.
---@return boolean True if the area allows advanced flying, false otherwise.
function core.world.is_advanced_flyable_area()
    return false
end

---@class encounter_info
---@field encounter_id integer The encounter ID.
---@field map_x number The X position on the map.
---@field map_y number The Y position on the map.

--- Returns a table of encounter data for the specified UI map ID.
--- Each entry contains the encounter ID and its map position.
---@param ui_map_id integer The UI map ID to query encounters for.
---@return encounter_info[] An array of encounter info tables.
function core.world.get_encounters_on_map(ui_map_id)
    return {}
end

---@class input
core.input = {}

--- Casts a spell on a specific target game object.
---@param spell_id integer The ID of the spell to cast.
---@param target game_object The target game object on which the spell will be cast.
---@return boolean Indicates whether the spell was successfully cast on the target.
function core.input.cast_target_spell(spell_id, target)
    return false
end

--- Casts a spell on a vec3 position
---@param spell_id integer The ID of the spell to cast.
---@param position vec3 the position where you want to cast the spell.
---@return boolean Indicates whether the spell was successfully cast on the position.
function core.input.cast_position_spell(spell_id, position)
    return false
end

--- Use a self cast item
---@param item_id integer The ID of the item to use.
---@return boolean Indicates whether the spell was successfully usage of the item
function core.input.use_item(item_id)
    return false
end

---@param target game_object
---@param item_id integer The ID of the item to use.
---@return boolean Indicates whether the spell was successfully usage of the item
function core.input.use_item_target(item_id, target)
    return false
end

---@param position vec3
---@param item_id integer The ID of the item to use.
---@return boolean Indicates whether the spell was successfully usage of the item
function core.input.use_item_position(item_id, position)
    return false
end

--- Use a container item by container (bag) and slot index.
---@param container_id integer The container (bag) index.
---@param slot_id integer The slot index within the container.
function core.input.use_container_item(container_id, slot_id)
end

--- Buy an item from a vendor.
---@param index integer The vendor item slot index.
---@param quantity integer The quantity to buy.
function core.input.buy_item(index, quantity)
end

--- Repair all equipped items at a vendor.
---@param use_guild_bank boolean Whether to use guild bank funds for the repair.
function core.input.repair_all_items(use_guild_bank)
end

--- Set the local player target
---@param unit game_object The game_object to set as target
---@return boolean Return true on successfully targetting the desired unit
function core.input.set_target(unit)
    return false
end

--- Set the local player focus
---@param unit game_object The game_object to set as focus
---@return boolean Return true on successfully focusing the desired unit
function core.input.set_focus(unit)
    return false
end

--- Get the local player focus
---@return table Return the game_object focus, can be nil
function core.input.get_focus()
    return {};
end

--- Checks if the key is pressed
--- @param key integer The key to check if is pressed or not
--- @return boolean Returns true if the passed key is being currently pressed. Check https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
function core.input.is_key_pressed(key)
    return false;
end

--- @return boolean
--- @param bit_flag number
function core.input.is_input_bit_active(bit_flag)
    return false
end

--- @return nil
--- Starts local rotation to right side
function core.input.turn_right_start()
    return nil
end

--- @return nil
--- Stops local rotation to right side
function core.input.turn_right_stop()
    return nil
end

--- @return nil
--- Starts local rotation to left side
function core.input.turn_left_start()
    return nil
end

--- @return nil
--- Stops local rotation to left side
function core.input.turn_left_stop()
    return nil
end

--- @return nil
--- Starts local strafe to right
function core.input.strafe_right_start()
    return nil
end

--- @return nil
--- Stops local strafe to right
function core.input.strafe_right_stop()
    return nil
end

--- @return nil
--- Starts local strafe to left
function core.input.strafe_left_start()
    return nil
end

--- @return nil
--- Stops local strafe to left
function core.input.strafe_left_stop()
    return nil
end

--- @return nil
--- Starts local forward
function core.input.move_forward_start()
    return nil
end

--- @return nil
--- Stops local forward
function core.input.move_forward_stop()
    return nil
end

--- @return nil
--- Starts local backward
function core.input.move_backward_start()
    return nil
end

--- @return nil
--- Stops local backward
function core.input.move_backward_stop()
    return nil
end

--- @return nil
function core.input.cancel_spells()
    return nil
end

--- @return nil
function core.input.enable_movement()
    return nil
end

--- @return nil
--- @param is_lock boolean
function core.input.disable_movement(is_lock)
    return nil
end

--- @return nil
--- Faces to vec3
--- @param point vec3
function core.input.look_at(point)
    return nil
end

--- Faces the local player towards a 3D world position (including vertical pitch).
--- @return nil
--- @param point vec3
function core.input.look_at_3d(point)
    return nil
end

--- Sets the local player's pitch (vertical look angle) in radians.
--- @return nil
--- @param radians number The pitch angle in radians.
function core.input.set_pitch(radians)
    return nil
end

--- Stops the local player's current attack.
---@return nil
function core.input.stop_attack()
    return nil
end

---@return nil
function core.input.stop_spell_target()
    return nil
end

--- Sets the pet to passive mode.
---@return nil
function core.input.set_pet_passive()
    return nil
end

--- Sets the pet to defensive mode.
---@return nil
function core.input.set_pet_defensive()
    return nil
end

--- Sets the pet to aggressive mode.
---@return nil
function core.input.set_pet_aggressive()
    return nil
end

--- Sets the pet to assist mode.
---@return nil
function core.input.set_pet_assist()
    return nil
end

--- Commands the pet to wait at its current position.
---@return nil
function core.input.set_pet_wait()
    return nil
end

--- Commands the pet to follow the player.
---@return nil
function core.input.set_pet_follow()
    return nil
end

--- Commands the pet to attack a target.
---@param target game_object The target to attack.
---@return nil
function core.input.pet_attack(target)
    return nil
end

--- Commands the pet to cast a spell on a target.
---@param spell_id integer The ID of the spell to cast.
---@param target game_object The target to cast the spell on.
---@return nil
function core.input.pet_cast_target_spell(spell_id, target)
    return nil
end

--- Commands the pet to cast a spell at a position.
---@param spell_id integer The ID of the spell to cast.
---@param position vec3 The position to cast the spell at.
---@return nil
function core.input.pet_cast_position_spell(spell_id, position)
    return nil
end

--- Commands the pet to move to a specified game object.
---@param target game_object The game object to move to.
---@return nil
function core.input.pet_move(target)
    return nil
end

--- Commands the pet to move to a specified position.
---@param position vec3 The position to move to.
---@return nil
function core.input.pet_move_position(position)
    return nil
end

--- Enables autocast for a pet spell.
---@param spell_id integer The ID of the pet spell to enable autocast for.
---@return nil
function core.input.enable_pet_autocast(spell_id)
    return nil
end

--- Disables autocast for a pet spell.
---@param spell_id integer The ID of the pet spell to disable autocast for.
---@return nil
function core.input.disable_pet_autocast(spell_id)
    return nil
end

--- Leaves and re-enters cat form in the same frame.
--- Useful for legacy mechanics like gaining free energy upon entering cat form,
--- removing roots via shapeshifting, or instantly re-entering cat form.
---@return nil
function core.input.quick_cat()
    return nil
end

--- Loots a specified game object.
---@param target game_object The game object to loot.
---@return nil
function core.input.loot_object(target)
    return nil
end

--- Skins a specified game object.
---@param target game_object The game object to skin.
---@return nil
function core.input.skin_object(target)
    return nil
end

--- Uses a specified game object.
---@param target game_object The game object to use.
---@return nil
function core.input.use_object(target)
    return nil
end

--- Interacts with a specified game object.
---@param target game_object The game object to interact with.
---@return nil
function core.input.interact_with_object(target)
    return nil
end

--- Releases the player's spirit after death.
---@return nil
function core.input.release_spirit()
    return nil
end

--- Sends player back to its corpse.
---@return nil
function core.input.resurrect_corpse()
    return nil
end

--- Starts moving the player character upwards (e.g., for flying or swimming).
--- @return nil
function core.input.move_up_start()
    return nil
end

--- Stops the upward movement of the player character.
--- @return nil
function core.input.move_up_stop()
    return nil
end

--- Starts moving the player character downward (e.g., for flying or swimming).
--- @return nil
function core.input.move_down_start()
    return nil
end

--- Stops the downward movement of the player character.
--- @return nil
function core.input.move_down_stop()
    return nil
end

--- Makes the player character jump.
--- @return nil
function core.input.jump()
    return nil
end

--- Mounts a specific mount by its index.
---@param mount_index integer The index of the mount to use.
---@return nil
function core.input.mount(mount_index)
    return nil
end

--- Dismounts the player from their current mount.
--- @return nil
function core.input.dismount()
    return nil
end

--- Loot a specific item from the loot window.
---@param index integer The index of the loot item to loot.
---@return nil
function core.input.loot_item(index)
    return nil
end

--- Close the loot window.
---@return nil
function core.input.close_loot()
    return nil
end

---@return nil
---@param buff_otr buff
function core.input.cancel_buff(buff_otr)
    return nil
end

---@return nil
---@param index number
---@param is_accept boolean
function core.input.accept_battlefield_port(index, is_accept)
    return nil
end

---@return nil
---@param role_flags number
---@param battlefield_id number
function core.input.join_battlefield(battlefield_id, role_flags)
    return nil
end

---@return nil
function core.input.leave_party()
    return nil
end

---@return nil
function core.input.leave_battlefield()
    return nil
end

---@return nil
---@param dungeon_id number
---@param category_id number
function core.input.select_dungeon(category_id, dungeon_id)
    return nil
end

---@return nil
---@param role_flags number
---@param category_id number
function core.input.join_dungeon(category_id, role_flags)
    return nil
end

---@return nil
function core.input.has_dungeon_proposal()
    return nil
end

---@return nil
---@param is_accept boolean
function core.input.accept_dungeon_proposal(is_accept)
    return nil
end

---@return nil
---@param index integer
function core.input.clear_dungeon_selections(index)
    return nil
end

--- Clears the AFK status of the local player.
--- NOTE: DEPRECATED
---@return nil
function core.input.clear_afk()
    return nil
end

---@class object_manager
core.object_manager = {}

--- Retrieves the local player game object.
---@return game_object
function core.object_manager.get_local_player()
    return {}
end

--- Retrieves all game objects.
---@return game_objects_table
function core.object_manager.get_all_objects()
    return {}
end

-- Retrieves the player for the given arena frame index, nil means we are not in arena
--- @param index integer
--- @return game_object | nil
function core.object_manager.get_arena_target(index)
    return {}
end

--- Retrieves all visible game objects.
---@return game_objects_table
function core.object_manager.get_visible_objects()
    return {}
end

--- Retrieves a list of game objects with all the arena frames.
---@return game_objects_table
function core.object_manager.get_arena_frames()
    return {}
end

--- Retrieves a list of game objects with all the party frames, excluding the local player.
---@return game_objects_table party_members An array of party frame game objects.
function core.object_manager.get_party_frames()
    return {}
end

--- Retrieves mouse_over object
---@return game_object
function core.object_manager.get_mouse_over_object()
    return {}
end

--- Returns the specialization ID of an arena opponent.
---@param index integer The arena opponent index.
---@return integer spec_id The specialization ID (0 if unavailable).
function core.object_manager.get_arena_opponent_spec(index)
    return 0
end

--- Returns a list of boss game objects from boss unit frames.
---@return game_objects_table bosses An array of boss game objects.
function core.object_manager.get_boss_frames()
    return {}
end

--- Returns the number of active boss unit frames (0-8).
---@return integer count The number of active bosses.
function core.object_manager.get_boss_count()
    return 0
end

--- A missile (spell projectile) currently in flight.
---@class missile
---@field source game_object|nil The source object that fired the missile.
---@field caster game_object|nil The caster object.
---@field target game_object|nil The target object.
---@field source_position vec3 The position where the missile was fired from.
---@field current_position vec3 The missile's current position in the world.
---@field impact_position vec3 The missile's destination/impact position.
---@field spell_id integer The spell ID of the missile.
---@field speed number The missile's travel speed.

--- Returns all in-flight spell missiles (projectiles) currently in the world.
---@return missile[]|nil missiles Array of missile tables, or nil if none.
function core.object_manager.get_all_missiles()
    return {}
end

---@class lfg_list
core.lfg_list = {}

---@class lfg_search_result_member_counts
---@field tank integer Filled tank slots.
---@field healer integer Filled healer slots.
---@field damager integer Filled damage slots.
---@field tank_remaining integer Open tank slots.
---@field healer_remaining integer Open healer slots.
---@field damager_remaining integer Open damage slots.

--- Returns role slot counts for an LFG search result.
---@param result_id number The LFG search result ID.
---@return lfg_search_result_member_counts|nil counts Filled and remaining role slot counts, or nil if unavailable.
function core.lfg_list.get_search_result_member_counts(result_id)
    return {}
end

---@class spell_book
core.spell_book = {}

--- Retrieves the local_player specialization_id
---@return number The local_player specialization_id
function core.spell_book.get_specialization_id()
    return 0
end

--- Retrieves the global cooldown duration in seconds.
---@return number The global cooldown duration in seconds.
function core.spell_book.get_global_cooldown()
    return 0
end

--- Retrieves the cooldown duration of the specified spell identified by its ID.
---@param spell_id integer The ID of the spell.
---@return number The cooldown duration of the specified spell in seconds.
function core.spell_book.get_spell_cooldown(spell_id)
    return 0
end

--- Indicates if the spell can be usable based on many requirements.
---@param spell_id integer The ID of the spell.
---@return boolean to indicate if the spell is usable.
function core.spell_book.is_usable_spell(spell_id)
    return false
end

--- Retrieves the amount of current charges of the specified spell identified by its ID.
---@param spell_id integer The ID of the spell.
---@return integer The amount of current stacks of the specified spell.
function core.spell_book.get_spell_charge(spell_id)
    return 0
end

--- Retrieves the amount of max charges of the specified spell identified by its ID.
---@param spell_id integer The ID of the spell.
---@return integer The amount of max stacks of the specified spell.
function core.spell_book.get_spell_charge_max(spell_id)
    return 0
end

--- Retrieves the total cooldown of the specified spell charge identified by its ID.
---@param spell_id integer The ID of the spell.
---@return integer The amount of max stacks of the specified spell.
function core.spell_book.get_spell_charge_cooldown_duration(spell_id)
    return 0
end

--- Retrieves the last time a charge was triggered of the specified spell identified by its ID.
---@param spell_id integer The ID of the spell.
---@return integer The amount of max stacks of the specified spell.
function core.spell_book.get_spell_charge_cooldown_start_time(spell_id)
    return 0
end

--- Retrieves the name of the specified spell identified by its ID.
---@param spell_id integer The ID of the spell.
---@return string The name of the specified spell.
function core.spell_book.get_spell_name(spell_id)
    return ""
end

--- Retrieves the whole tooltip text of the specified spell identified by its ID.
---@param spell_id integer The ID of the spell.
---@return string The tooltip text of the specified spell.
function core.spell_book.get_spell_description(spell_id)
    return ""
end

--- NOTE: DEPRECATED AFTER 03/2026 WILL RETURN JUST INTS AS STRING, BETTER TO USE BUFF.POINTS
--- Retrieves the whole tooltip text of the specified buff.
---@param buff_ptr buff
---@return string The tooltip text of the specified buff.
---@diagnostic disable-next-line: duplicate-set-field
function core.spell_book.get_buff_description(buff_ptr)
    return ""
end

--- Retrieves a table containing all spells and their corresponding IDs.
---@return table<number, number>
function core.spell_book.get_spells()
    return {}
end

--- Checks if the specified spell identified by its ID is owned by the localplayer.
---@param spell_id integer The ID of the spell.
---@return boolean Returns true if the specified spell is equipped, otherwise returns false.
function core.spell_book.has_spell(spell_id)
    return false
end

--- Checks if the specified spell identified by its ID is learned by the localplayer.
---@param spell_id integer The ID of the spell.
---@return boolean Returns true if the specified spell is learned, otherwise returns false.
function core.spell_book.is_spell_learned(spell_id)
    return false
end

--- Checks if the specified spell identified by its ID is known by the localplayer.
---@param spell_id integer The ID of the spell.
---@return boolean Returns true if the specified spell is known, otherwise returns false.
function core.spell_book.is_spell_known(spell_id)
    return false
end

---@param n integer
---@param flag integer
---@param spell_id integer The ID of the spell.
---@return boolean Returns true if the specified spell has certain attribute.
function core.spell_book.spell_has_attribute(spell_id, n, flag)
    return false
end

--- Returns the spell_id from the talent_id.
---@param talent_id integer The ID of the talent.
---@return number Returns the spell_id from the talent_id.
function core.spell_book.get_talent_spell_id(talent_id)
    return 0
end

--- Returns the name from the talent_id.
---@param talent_id integer The ID of the talent.
---@return string Returns the name from the talent_id.
function core.spell_book.get_talent_name(talent_id)
    return ""
end

--- Checks if the specified spell is melee type.
---@param spell_id integer The ID of the spell.
---@return boolean Returns true if the specified spell is melee type.
function core.spell_book.is_melee_spell(spell_id)
    return false
end

--- Checks if the specified spell is an skillshot.
---@param spell_id integer The ID of the spell.
---@return boolean Returns true if the specified spell is skillshot.
function core.spell_book.is_spell_position_cast(spell_id)
    return false
end

--- Checks if the cursor is currently busy with an skillshot.
---@return boolean Returns true if the cursor is currently busy with an skillshot.
function core.spell_book.cursor_has_spell()
    return false
end

---@class spell_costs
---@field min_cost number         Minimum absolute cost (usually equal to `cost` unless the spell scales).
---@field cost number             Absolute resource cost (0 for spells that use `cost_percent` instead).
---@field cost_per_sec number     Drain rate for channelled abilities; 0 otherwise.
---@field cost_percent number     Percent-of-base cost (e.g. 8 for an ability costing 8% of base mana). Monk/modern abilities use this instead of `cost`.
---@field cost_type number        Enum.PowerType of the resource (0 = Mana, 3 = Energy, 4 = Rage, ...).
---@field required_buff_id number Spell ID of the aura that must be up for this entry to apply; 0 if unconditional.

--- Returns the list of power costs for a spell. A single spell can return multiple
--- entries — one per resource (e.g. a spell that costs both Mana and Energy) or one
--- per gated variant (e.g. Monk abilities that cost different resources depending on
--- which stance aura is active).
---@param spell_id integer The ID of the spell.
---@return spell_costs[] costs Array of cost entries; empty if the spell has no costs or data isn't loaded.
function core.spell_book.get_spell_costs(spell_id)
    return {}
end

---@class range_data
---@field min number
---@field max number

--- Retrieves the range data of the specified spell identified by its ID.
---@param spell_id integer The ID of the spell.
---@return range_data A table containing the minimum and maximum range of the specified spell.
function core.spell_book.get_spell_range_data(spell_id)
    return {}
end

--- Retrieves the minimum range of the specified spell identified by its ID.
---@param spell_id integer The ID of the spell.
---@return number The minimum range of the specified spell.
function core.spell_book.get_spell_min_range(spell_id)
    return 0
end

--- Retrieves the maximum range of the specified spell identified by its ID.
---@param spell_id integer The ID of the spell.
---@return number The maximum range of the specified spell.
function core.spell_book.get_spell_max_range(spell_id)
    return 0
end

--- Retrieves the school flag of the specified spell identified by its ID.
---@param spell_id integer The ID of the spell.
---@return schools_flag The spell school flag.
function core.spell_book.get_spell_school(spell_id)

    ---@type schools_flag
    return nil
end

--- Retrieves the cast time of the specified spell identified by its ID.
---@param spell_id integer The ID of the spell.
---@return number The cast time in seconds.
function core.spell_book.get_spell_cast_time(spell_id)
    return 0
end

--- Note: This Function is deprecated
--- Alternative: Common Utility Spell Helper
--- Retrieves the damage value of the spell_id.
-- -@param spell_id integer The ID of the spell.
-- -@return number The damage value of the spell.
-- function core.spell_book.get_spell_damage(spell_id)
    -- return 0
-- end

--- Retrieves the mode flag of our pet
---@return number
function core.spell_book.get_pet_mode()
    return 0
end

--- Retrieves a table with all the pet spells
---@return table
function core.spell_book.get_pet_spells()
    return {}
end

---@class pet_action_info
---@field name string The name of the pet action.
---@field texture string The texture path for the pet action icon.
---@field is_token boolean Whether the action is a token (stance/mode) action.
---@field is_active boolean Whether the action is currently active.
---@field auto_cast_allowed boolean Whether autocast is allowed for this action.
---@field auto_cast_enabled boolean Whether autocast is currently enabled.
---@field spell_id integer The spell ID of the pet action.
---@field checks_range boolean Whether this action checks range.
---@field in_range boolean Whether the target is currently in range for this action.

--- Retrieves detailed information about a pet action by spell ID.
---@param spell_id integer The spell ID of the pet action.
---@return pet_action_info A table containing the pet action information.
function core.spell_book.get_pet_action_info(spell_id)
    return {}
end

---@class mount_info
---@field mount_name string The name of the mount.
---@field spell_id integer The spell ID associated with the mount.
---@field mount_id integer The unique ID of the mount.
---@field is_active boolean Whether the mount is currently active.
---@field is_usable boolean Whether the mount is usable.
---@field mount_type integer The type/category of the mount.

--- Retrieves the number of mounts available to the player.
---@return integer The total number of mounts.
function core.spell_book.get_mount_count()
    return 0
end

--- Retrieves information about a specific mount by its index.
---@param mount_index integer The index of the mount.
---@return mount_info|nil A table containing the mount information, or nil if the index is invalid.
function core.spell_book.get_mount_info(mount_index)
    return {}
end

---@return integer
---@param spell_id integer
function core.spell_book.get_base_spell_id(spell_id)
    return 0
end

---@class totem_info
---@field have_totem boolean         -- Whether the totem exists
---@field totem_name string          -- Name of the totem
---@field start_time number          -- Start time of the totem
---@field duration number            -- Duration of the totem

---@return totem_info
---@param index integer
---Returns a table with totem info for the given index (1–4).  
---Index corresponds to the totem slot (e.g., Fire, Earth, Water, Air).
function core.spell_book.get_totem_info(index)
    return {}
end

---@return boolean
---@param item_id integer
function core.spell_book.is_item_usable(item_id)
    return false
end

---@return integer
---@param index integer
--- 1 Blood | 2 Unholy | 3 Frost | 4 Death
function core.spell_book.get_rune_type(index)
    return 0
end

---@return boolean
---@param index integer
function core.spell_book.is_rune_slot_active(index)
    return false
end

--- Retrieves the base (out-of-combat) power regeneration rate of the local player.
--- This represents the passive regeneration rate when not casting or using abilities.
---@return number The base power regeneration per second.
function core.spell_book.get_base_power_regen()
    return 0
end

--- Retrieves the power regeneration rate of the local player while casting.
--- This may differ from the base regen due to talents, buffs, or class mechanics.
---@return number The casting power regeneration per second.
function core.spell_book.get_casting_power_regen()
    return 0
end

---@class rune_info
---@field start number     -- cooldown start time (seconds)
---@field duration number  -- cooldown duration (seconds)
---@field ready boolean    -- true if the rune is ready now

--- Retrieves cooldown info for the rune in the given slot (1..6).
---@param slot integer  -- 1..6
---@return rune_info
function core.spell_book.get_rune_info(slot)
    -- Example stub values; engine should return real timings:
    return { start = 0, duration = 0, ready = true }
end

--- Checks whether a spell is in range from a specified caster to a target.
--- If `caster` is not provided, it defaults to the local player.
--- If `target` is not provided, it defaults to the current target of the local player.
--- This function internally evaluates the spell's range data and both game object positions.
---@param spell_id integer The ID of the spell to check.
---@param target? game_object (optional) The target game object to check range against. Defaults to current target if omitted.
---@param caster? game_object (optional) The caster game object. Defaults to the local player if omitted.
---@return boolean Returns true if the target is within range for the specified spell, otherwise false.
function core.spell_book.is_spell_in_range(spell_id, target, caster)
    return false
end

--- Checks whether an item has a built-in range definition (e.g., targetable items).
--- Engine should resolve the item's underlying "use spell" and report if range data exists.
---@param item_id integer
---@return boolean  -- true if the item supports range checking
function core.spell_book.has_item_range(item_id)
    -- Engine-backed; stubbed here for syntax.
    return false
end

--- Checks whether an item can be used on `target` with respect to range.
--- Internally maps the item to its "use spell" and performs a spell range check.
--- If `target` is nil, the engine may default to the current target.
---@param item_id integer
---@param target? game_object
---@return boolean  -- true if `target` is in range for this item
function core.spell_book.is_item_in_range(item_id, target)
    -- Engine-backed; stubbed here for syntax.
    return false
end

---@return number
---@param spell_id number
function core.spell_book.get_spell_cast_count(spell_id)
    return 0
end

---@return number
---@param target game_object
---@param ui_check boolean -- true wont suggest the spell unless is on the action bar
function core.spell_book.get_assisted_spell_id(target, ui_check)
    return 0
end

---@return boolean
---@param spell_id number
function core.spell_book.is_current_spell(spell_id)
    return false
end

---@class pet_happiness_data
---@field happiness integer The pet happiness level.
---@field damage_percentage number The pet damage percentage modifier.
---@field loyalty_rate number The pet loyalty rate.

--- Retrieves the current pet happiness information.
---@return pet_happiness_data A table containing happiness, damage_percentage, and loyalty_rate.
function core.spell_book.get_pet_happiness()
    return {}
end

--- Checks if a spell is flagged as important.
---@param spell_id integer The ID of the spell to check.
---@return boolean True if the spell is important, false otherwise.
function core.spell_book.is_important_spell(spell_id)
    return false
end

---@class spell_cooldown_info
---@field start_time number The game time when the cooldown started.
---@field duration number The total duration of the cooldown in seconds.
---@field enabled boolean Whether the cooldown is currently active/enabled.

--- Returns detailed cooldown information for a spell.
---@param spell_id integer The ID of the spell.
---@return spell_cooldown_info A table containing start_time, duration, and enabled.
function core.spell_book.get_spell_cooldown_information(spell_id)
    return {}
end

--- Returns the required aura ID for a spell to be castable.
---@param spell_id integer The ID of the spell.
---@return integer aura_id The required aura spell ID.
function core.spell_book.get_spell_required_aura(spell_id)
    return 0
end

--- Returns the override spell ID for a given spell (e.g. talent-modified versions).
---@param spell_id integer The base spell ID.
---@return integer override_id The override spell ID.
function core.spell_book.get_override_spell_id(spell_id)
    return 0
end

--- Returns the current shapeshift form ID.
--- Returns 0 if the player is not shapeshifted or the Blizzard API is unavailable.
---@return integer form_id The current shapeshift form ID.
function core.spell_book.get_shapeshift_form_id()
    return 0
end

--- Casts the shapeshift form at the given 1-based shapeshift/stance bar index.
--- The actual form change is observed asynchronously via UPDATE_SHAPESHIFT_FORM.
---@param index integer The 1-based shapeshift/stance bar index to cast.
---@return boolean success True if the cast call was issued without a Lua error.
function core.spell_book.cast_shapeshift_form(index)
    return false
end

---@class graphics
core.graphics = {}

--- Adds a notification to the display.
--- NOTE: Must be called from a registered callback (on_update, on_render, on_pre_tick).
--- Calling from event handlers like izi.on_key_release will display visually but
--- is_notification_active and is_notification_clicked won't work correctly.
--- Calling with the same unique_id while one is already active will stack, not replace.
--- @param unique_id string UNIQUE identifier for the notification.
--- @param label string The title or heading for the notification.
--- @param message string The main content of the notification.
--- @param duration_s number The duration in seconds that the notification should be displayed.
--- @param color color The color of the notification.
--- @param x_pos_offset number|nil Optional horizontal position offset (screen-relative), defaults to 0.0.
--- @param y_pos_offset number|nil Optional vertical position offset (screen-relative), defaults to 0.0.
--- @param max_background_alpha number|nil Optional maximum background alpha (opacity), defaults to 0.95.
--- @param length number|nil Optional extra length added to notification box, defaults to 0.0.
--- @param height number|nil Optional extra height added to notification box, defaults to 0.0.
--- @return boolean success Whether the notification was created.
--- @overload fun(unique_id:string, label: string, message: string, duration_s: number, color: color):boolean
--- @overload fun(unique_id:string, label: string, message: string, duration_s: number, color: color, x_pos_offset: number):boolean
--- @overload fun(unique_id:string, label: string, message: string, duration_s: number, color: color, x_pos_offset: number, y_pos_offset: number):boolean
--- @overload fun(unique_id:string, label: string, message: string, duration_s: number, color: color, x_pos_offset: number, y_pos_offset: number, max_background_alpha: number):boolean
--- @overload fun(unique_id:string, label: string, message: string, duration_s: number, color: color, x_pos_offset: number, y_pos_offset: number, max_background_alpha: number, length: number):boolean
function core.graphics.add_notification(unique_id, label, message, duration_s, color, x_pos_offset, y_pos_offset, max_background_alpha, length, height)
    return false
end

--- Returns true if the notification was clicked within the last `delay` seconds.
--- With delay = 0.0, returns true only on the exact click frame.
--- @param unique_id string UNIQUE identifier of the notification.
--- @param delay number|nil Lookback window in seconds. Returns true if clicked within the last N seconds. Defaults to 0.0 (click frame only).
--- @return boolean clicked
function core.graphics.is_notification_clicked(unique_id, delay)
    return false
end

--- Returns true if the notification is currently being shown on screen.
--- @param unique_id string UNIQUE identifier of the notification.
--- @return boolean active
function core.graphics.is_notification_active(unique_id)
    return false
end

--- Retrieves the notification position offset (normalized 0.0-1.0 range, screen-relative).
--- Multiply by screen size to get pixel coordinates. This is the raw slider value.
--- For pixel-space positions ready to use, prefer get_notifications_layout().
--- @return vec2 notifications_position Normalized (x, y) offset.
function core.graphics.get_notifications_menu_position()
    return {}
end

--- Retrieves the base notification size in pixels (before text content expansion).
--- Scaled from 275x80 at 1920x1080. Actual rendered notification may be larger
--- depending on text length and line count.
--- @return vec2 notifications_default_size The base width and height in pixels.
function core.graphics.get_notifications_default_size()
    return {}
end

--- Returns pixel-space layout info for notification positioning and hit-testing.
--- Accounts for screen resolution, slider offsets, and animation offsets.
--- Slot N position: vec2(layout.base_pos.x, layout.base_pos.y + layout.separation * N)
--- Note: actual notification width/height may exceed default_size depending on text content.
--- @return table layout { base_pos: vec2, default_size: vec2, separation: number }
function core.graphics.get_notifications_layout()
    return {}
end

---@return vec2 main_menu_screen_position
function core.graphics.get_main_menu_screen_pos()
    return {}
end

---@return string key_name
---@param key integer
function core.graphics.translate_vkey_to_string(key)
    return ""
end

---@return vec2 main_menu_screen_size
function core.graphics.get_main_menu_screen_size()
    return {}
end

---@return string current_dragged_menu_element_pending_to_be_added_to_control_panel_label The current dragged menu element that is pending to be added to control panel
function core.graphics.get_current_control_panel_element_label()
    return ""
end

---@param label string
function core.graphics.set_current_control_panel_element_label(label) end

--- Retrieves the scaled width - Main resolution is your current resolution X, must be hardcoded. (Eg. 1920)
---@return number scaled_width
---@param value_to_scale number
---@param main_resolution number
function core.graphics.scale_width_to_screen_size(value_to_scale, main_resolution)
    return 0.0
end

--- Retrieves the scaled height - Main resolution is your current resolution Y, must be hardcoded. (Eg. 1080)
---@return number scaled_width
---@param value_to_scale number
---@param main_resolution number
function core.graphics.scale_height_to_screen_size(value_to_scale, main_resolution)
    return 0.0
end

--- Retrieves the scaled size - Main resolution is your current resolution. Must be hardcoded. (Eg. 1920*1080)
---@return vec2 scaled_size
---@param value_to_scale vec2
---@param main_resolution vec2
function core.graphics.scale_size_to_screen_size(value_to_scale, main_resolution)
    return {}
end

--- Line Of Sight
---@return boolean
---@param caster game_object
---@param target game_object
function core.graphics.is_line_of_sight(caster, target)
    return false
end

--- Trace Line
---@return boolean
---@param pos1 vec3
---@param pos2 vec3
---@param flags number
function core.graphics.trace_line(pos1, pos2, flags)
    return false
end

--- World to Screen
---@param position vec3 The 3D world position to convert.
---@return vec2 | nil
function core.graphics.w2s(position)
    return {}
end

--- World to Screen
---@return vec2 --| nil
function core.graphics.get_screen_size()
    return {}
end

--- Cursor World Position (Vec3)
---@return vec3
function core.graphics.get_cursor_world_position()
    return {}
end

--- Returns true when the main menu is open
---@return boolean
function core.graphics.is_menu_open()
    return false
end

--- Render 2D text.
---@param text string The text to render.
---@param position vec2 The position where the text will be rendered.
---@param font_size number The font size of the text.
---@param color color The color of the text.
---@param centered? boolean Indicates whether the text should be centered at the specified position. Default is false.
---@param font_id? integer The font ID. Default is 0.
function core.graphics.text_2d(text, position, font_size, color, centered, font_id) end

--- Render 3D text.
---@param text string The text to render.
---@param position vec3 The position in 3D space where the text will be rendered.
---@param font_size number The font size of the text.
---@param color color The color of the text.
---@param centered? boolean Indicates whether the text should be centered at the specified position. Default is false.
---@param font_id? integer The font ID. Default is 0.
function core.graphics.text_3d(text, position, font_size, color, centered, font_id) end

--- Get Text Width
---@return number
---@param text string The text to render.
---@param font_size number The font size of the text.
---@param font_id? integer The font ID. Default is 0.
function core.graphics.get_text_width(text, font_size, font_id)
    return 0
end

--- Draw 2D Line
---@param start_point vec2 The start point of the line.
---@param end_point vec2 The end point of the line.
---@param color color The color of the line.
---@param thickness? number The thickness of the line. Default is 1.
function core.graphics.line_2d(start_point, end_point, color, thickness) end

--- Draw 2D Rectangle Outline
---@param top_left_point vec2 The top-left corner point of the rectangle.
---@param width number The width of the rectangle.
---@param height number The height of the rectangle.
---@param color color The color of the rectangle outline.
---@param thickness? number The thickness of the outline. Default is 1.
---@param rounding? number The rounding of corners. Default is 0.
function core.graphics.rect_2d(top_left_point, width, height, color, thickness, rounding) end

--- Draw 2D Filled Rectangle
---@param top_left_point vec2 The top-left corner point of the rectangle.
---@param width number The width of the rectangle.
---@param height number The height of the rectangle.
---@param color color The color of the rectangle outline.
---@param rounding? number The rounding of corners. Default is 0.
function core.graphics.rect_2d_filled(top_left_point, width, height, color, rounding) end

--- Draw 3D Line
---@param start_point vec3 The start point of the line in 3D space.
---@param end_point vec3 The end point of the line in 3D space.
---@param color color The color of the line.
---@param thickness? number The thickness of the line. Default is 1.
---@param fade_factor? number The thickness of the outline. Default is 2.5.
---@param has_volume? boolean Add volume. Default true.
function core.graphics.line_3d(start_point, end_point, color, thickness, fade_factor, has_volume) end

--- Draw 3D Rectangle Outline New
---@param origin vec3
---@param destination vec3
---@param color color The color of the rectangle outline.
---@param thickness? number The thickness of the line. Default is 1.
---@param fade_factor? number The thickness of the outline. Default is 2.5.
function core.graphics.rect_3d(origin, destination, width, color, thickness, fade_factor) end

--- Draw 3D Filled Rectangle
---@param p1 vec3 The first corner point of the rectangle in 3D space.
---@param p2 vec3 The second corner point of the rectangle in 3D space.
---@param p3 vec3 The third corner point of the rectangle in 3D space.
---@param p4 vec3 The fourth corner point of the rectangle in 3D space.
---@param color color The fill color of the rectangle.
function core.graphics.rect_3d_filled(p1, p2, p3, p4, color) end

--- Draw 2D Circle Outline
---@param center vec2 The center point of the circle.
---@param radius number The radius of the circle.
---@param color color The color of the circle outline.
---@param thickness? number The thickness of the outline. Default is 1.
function core.graphics.circle_2d(center, radius, color, thickness) end

--- Draw 2D Circle Outline Gradient
---@param center vec2 The center point of the circle.
---@param radius number The radius of the circle.
---@param color_1 color
---@param color_2 color
---@param color_3 color
---@param thickness? number The thickness of the outline. Default is 1.
function core.graphics.circle_2d_gradient(center, radius, color_1, color_2, color_3, thickness) end

--- Draw 2D Filled Circle
---@param center vec2 The center point of the circle.
---@param radius number The radius of the circle.
---@param color color The fill color of the circle.
function core.graphics.circle_2d_filled(center, radius, color) end

--- Draw 3D Circle Outline
---@param center vec3 The center point of the circle in 3D space.
---@param radius number The radius of the circle.
---@param color color The color of the circle outline.
---@param thickness? number The thickness of the outline. Default is 1.
---@param fade_factor? number The factor / strenght it fades out, bigger value, faster fade. Default is 2.5.
function core.graphics.circle_3d(center, radius, color, thickness, fade_factor) end

--- Draw 3D Circle Outline Percentage
---@param center vec3 The center point of the circle in 3D space.
---@param radius number The radius of the circle.
---@param color color The color of the circle outline.
---@param percentage number The percentage of the circle to render.
---@param thickness? number The thickness of the outline. Default is 1.
function core.graphics.circle_3d_percentage(center, radius, color, percentage, thickness) end

--- Draw 3D Circle Outline Gradient
---@param center vec3 The center point of the circle in 3D space.
---@param radius number The radius of the circle.
---@param color_1 color
---@param color_2 color
---@param color_3 color
---@param thickness? number The thickness of the outline. Default is 1.
function core.graphics.circle_3d_gradient(center, radius, color_1, color_2, color_3, thickness) end

--- Draw 3D Cone
---@param center vec3 The center point of the circle in 3D space.
---@param target_pos vec3 The target position of the cone
---@param radius number The radius of the cone
---@param angle_degrees number
---@param color color
---@param fade_power number | nil
function core.graphics.cone_3d(center, target_pos, radius, angle_degrees, color, fade_power) end

--- Draw 3D Circle Outline Gradient Percentage
---@param center vec3 The center point of the circle in 3D space.
---@param radius number The radius of the circle.
---@param color_1 color
---@param color_2 color
---@param color_3 color
---@param percentage number The percentage of the circle to render.
---@param thickness? number The thickness of the outline. Default is 1.
function core.graphics.circle_3d_gradient_percentage(center, radius, color_1, color_2, color_3, percentage, thickness) end

--- Draw 3D Filled Circle
---@param center vec3 The center point of the circle in 3D space.
---@param radius number The radius of the circle.
---@param color color The fill color of the circle.
function core.graphics.circle_3d_filled(center, radius, color) end

--- Draw 2D Filled Triangle
---@param p1 vec2 The first corner point of the triangle in 2D space.
---@param p2 vec2 The second corner point of the triangle in 2D space.
---@param p3 vec2 The third corner point of the triangle in 2D space.
---@param color color The fill color of the triangle.
function core.graphics.triangle_2d_filled(p1, p2, p3, color) end

--- Draw 3D Filled Triangle
---@param p1 vec3 The first corner point of the triangle in 3D space.
---@param p2 vec3 The second corner point of the triangle in 3D space.
---@param p3 vec3 The third corner point of the triangle in 3D space.
---@param color color The fill color of the triangle.
function core.graphics.triangle_3d_filled(p1, p2, p3, color) end

--- Load Image
---@param path_to_asset string The path to the image file.
function core.graphics.load_image(path_to_asset) end

--- Draw Image
---@param image any Loaded image object.
---@param position vec2 The position to place the image.
function core.graphics.draw_image(image, position) end

--- Renders System Menu from C++
function core.graphics.render_system_menu() end

function core.graphics.capture_next_mouse_input() end

function core.graphics.capture_next_keyboard_input() end

--- Sets the hard mouse input capture state.
---@param state boolean Whether to capture mouse input.
---@return nil
function core.graphics.set_mouse_capture_state(state)
    return nil
end

--- Sets the hard keyboard input capture state.
---@param state boolean Whether to capture keyboard input.
---@return nil
function core.graphics.set_keyboard_capture_state(state)
    return nil
end

---@class native_intersect_result
---@field [1] boolean Whether an intersection occurred.
---@field [2] vec3 The intersection position.
---@field [3] number The intersection distance.

--- Performs a native ray intersection test.
---@param end_pos vec3 The end position of the ray.
---@param start_pos vec3 The start position of the ray.
---@param distance number|nil The max distance (default 1.0).
---@param hit_mask integer The collision hit mask flags.
---@return boolean hit Whether an intersection occurred.
---@return vec3 hit_pos The intersection position.
---@return number hit_distance The intersection distance.
function core.graphics.native_intersect(end_pos, start_pos, distance, hit_mask)
    return false, {}, 0
end

--- Loads a custom font from raw binary data.
---@param font_data string The raw font file data.
---@param font_size number The font size (must be > 0 and <= 200).
---@return integer font_id The font handle ID for use in text rendering.
function core.graphics.load_font(font_data, font_size)
    return 0
end

--- Pushes a scissor (clipping) rectangle onto the clip stack.
--- All subsequent draw calls will be clipped to the specified rectangular region
--- until scissor_pop is called. Scissor calls can be nested.
---
--- Example:
--- ```lua
--- core.graphics.scissor_push(100, 150, 555, 200)
--- core.graphics.rect_2d_filled(vec2.new(150, 50), 600, 400, color.red(255))
--- core.graphics.scissor_pop()
--- ```
---
---@param x number The x position of the clipping region top-left corner.
---@param y number The y position of the clipping region top-left corner.
---@param w number The width of the clipping region.
---@param h number The height of the clipping region.
---@return nil
function core.graphics.scissor_push(x, y, w, h)
    return nil
end

--- Pops the last scissor (clipping) rectangle from the clip stack.
--- Must be called after a matching scissor_push to restore the previous clipping state.
---
--- Example:
--- ```lua
--- core.graphics.scissor_push(100, 150, 555, 200)
--- core.graphics.rect_2d_filled(vec2.new(150, 50), 600, 400, color.red(255))
--- core.graphics.scissor_pop()
--- ```
---
---@return nil
function core.graphics.scissor_pop()
    return nil
end

--- Draws a previously loaded texture with custom UV coordinates, allowing rendering
--- of a sub-region (e.g., a single icon from a sprite atlas).
--- Use UV (0,0)-(1,1) to draw the full texture (same behavior as draw_texture).
---
--- Example (full texture):
--- ```lua
--- core.graphics.draw_texture_rect(tex_id, vec2.new(100, 100), 200, 100, 0, 0, 1, 1, color.white(180))
--- ```
---
--- Example (sub-region from atlas):
--- ```lua
--- core.graphics.draw_texture_rect(tex_id, vec2.new(50, 50), 32, 32, 0.0, 0.0, 0.25, 0.25)
--- ```
---
---@param texture_id integer The texture handle returned by core.graphics.load_texture.
---@param top_left vec2 The screen position of the top-left corner.
---@param width number The draw width in pixels.
---@param height number The draw height in pixels.
---@param uv0_x number The left UV coordinate of the source region (0.0 to 1.0).
---@param uv0_y number The top UV coordinate of the source region (0.0 to 1.0).
---@param uv1_x number The right UV coordinate of the source region (0.0 to 1.0).
---@param uv1_y number The bottom UV coordinate of the source region (0.0 to 1.0).
---@param color? color Optional tint color. Defaults to white.
---@param is_for_window? boolean Optional. If true, draws to the current window draw list. Defaults to false (background).
---@return nil
function core.graphics.draw_texture_rect(texture_id, top_left, width, height, uv0_x, uv0_y, uv1_x, uv1_y, color, is_for_window)
    return nil
end

---@class menu
core.menu = {}

--- Registers the menu for interaction.
function core.menu.register_menu() end

--- Creates a new tree node instance
---@return tree_node
function core.menu.tree_node()
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new checkbox instance.
---@param default_state boolean The default state of the checkbox.
---@param id string The unique identifier for the checkbox.
---@return checkbox
function core.menu.checkbox(default_state, id)
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new checkbox instance.
---@param default_key integer The default state of the checkbox.
---@param initial_toggle_state boolean The initial toggle state of the keybind
---@param default_state boolean The default state of the checkbox
---@param show_in_binds boolean The default show in binds state of the checkbox
---@param default_mode_state integer The default show in binds state of the checkbox  -> 0 is hold, 1 is toggle, 2 is always
---@param id string The unique identifier for the checkbox.
---@return key_checkbox
function core.menu.key_checkbox(default_key, initial_toggle_state, default_state, show_in_binds,  default_mode_state, id)
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new slider with integer values.
---@param min_value number The minimum value of the slider.
---@param max_value number The maximum value of the slider.
---@param default_value number The default value of the slider.
---@param id string The unique identifier for the slider.
---@return slider_int
function core.menu.slider_int(min_value, max_value, default_value, id)
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new slider with floating-point values.
---@param min_value number The minimum value of the slider.
---@param max_value number The maximum value of the slider.
---@param default_value number The default value of the slider.
---@param id string The unique identifier for the slider.
---@return slider_float
function core.menu.slider_float(min_value, max_value, default_value, id)
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new combobox.
---@param default_index number The default index of the combobox options (1-based).
---@param id string The unique identifier for the combobox.
---@return combobox
function core.menu.combobox(default_index, id)
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new combobox_reorderable.
---@param default_index number The default index of the combobox options (1-based).
---@param id string The unique identifier for the combobox.
---@return combobox_reorderable
function core.menu.combobox_reorderable(default_index, id)
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new keybind.
---@param default_value number The default value for the keybind.
---@param initial_toggle_state boolean The initial toggle state for the keybind.
---@param id string The unique identifier for the keybind.
---@return keybind
function core.menu.keybind(default_value, initial_toggle_state, id)
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new button.
---@return button
---@param id string The unique identifier for the button.
function core.menu.button(id)
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new color picker.
---@return color_picker
---@param default_color color The default color value.
---@param id string The unique identifier for the color picker.
function core.menu.colorpicker(default_color, id)
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new header
---@return header
function core.menu.header()
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new text input
---@return text_input
---@param save_input boolean?
---@param id string The unique identifier for the color picker.
function core.menu.text_input(id, save_input)
    return {} -- Empty return statement to implicitly return nil
end

--- Creates a new window
---@return window
function core.menu.window(window_id)
    return {} -- Empty return statement to implicitly return nil
end

--------------------------------------------------------------------------------
-- HTTP
--------------------------------------------------------------------------------

--- Performs an asynchronous HTTP GET request.
---
--- This API is generally used to fetch remote data (JSON, text, images, etc).
--- It is optional for texture usage. Most textures are loaded from local files
--- already stored under `scripts_data/`.
---
--- Overloads:
--- 1) core.http_get(url, callback)
--- 2) core.http_get(url, headers, callback)
---
--- Headers:
--- - `headers` is a table<string, string>
--- - Each pair is sent as: "Key: Value"
---
--- Callback parameters:
--- - `http_code` integer, HTTP status code (200, 404, etc). Transport failure may be 0 (native-defined).
--- - `content_type` string, server content type (native-defined on failure).
--- - `response_data` string, raw response body, binary safe.
--- - `response_headers` string, response headers dump, format is native-defined.
---
---@param url string
---@param headers_or_callback table<string, string>|fun(http_code: integer, content_type: string, response_data: string, response_headers: string)
---@param callback_opt fun(http_code: integer, content_type: string, response_data: string, response_headers: string)|nil
---@return nil
function core.http_get(url, headers_or_callback, callback_opt)
  return nil
end

--- Performs an asynchronous HTTP POST request.
---
--- Overloads:
--- 1) core.http_post(url, body, callback)
--- 2) core.http_post(url, headers, body, callback)
---
--- Headers:
--- - `headers` is a table<string, string>
--- - Each pair is sent as: "Key: Value"
---
--- Body:
--- - `body` is a raw string (can contain binary data).
---
--- Callback parameters:
--- - `http_code` integer, HTTP status code (200, 404, etc). Transport failure may be 0 (native-defined).
--- - `content_type` string, server content type (native-defined on failure).
--- - `response_data` string, raw response body, binary safe.
--- - `response_headers` string, response headers dump, format is native-defined.
---
---@param url string
---@param headers_or_body table<string, string>|string
---@param body_or_callback string|fun(http_code: integer, content_type: string, response_data: string, response_headers: string)
---@param callback_opt fun(http_code: integer, content_type: string, response_data: string, response_headers: string)|nil
---@return nil
function core.http_post(url, headers_or_body, body_or_callback, callback_opt)
    return nil
end

--- Returns the mouse wheel delta from the current frame.
---@return number delta The mouse wheel scroll delta.
function core.get_mouse_wheel_delta()
    return 0
end

--------------------------------------------------------------------------------
-- GRAPHICS, TEXTURES
--------------------------------------------------------------------------------

core.graphics = core.graphics or {}

--- Loads a GPU texture from raw image bytes.
---
--- Common usage patterns:
--- 1) Load from a local file in `scripts_data/`
---    - Read the file bytes with `core.read_data_file("path.png")`
---    - Pass bytes to `core.graphics.load_texture(bytes)`
---
--- 2) Load from an HTTP download (less common)
---    - Download bytes via `core.http_get(...)`
---    - Pass bytes to `core.graphics.load_texture(response_data)`
---
--- Native behavior:
--- - Returns nil if the image bytes cannot be decoded.
--- - Returns `texture_id` if texture is already loaded or already queued.
--- - Returns `texture_id, width, height` only when newly queued.
---
--- Notes:
--- - `texture_id` is a numeric handle used by `core.graphics.draw_texture`.
--- - The bytes string may contain binary data and zero bytes.
---
---@param image_data string Raw image bytes (binary-safe Lua string).
---@return integer|nil texture_id Texture handle, or nil on failure.
---@return integer|nil width Width in pixels (only returned when newly created).
---@return integer|nil height Height in pixels (only returned when newly created).
function core.graphics.load_texture(image_data)
  return nil
end

--- Draws a previously loaded texture.
---
--- Typical usage:
--- - Load once, store `texture_id` in a variable.
--- - Draw every frame (inside your render callback or equivalent).
---
--- Parameters:
--- - `texture_id` integer, returned by `core.graphics.load_texture`
--- - `top_left` vec2, screen position
--- - `width` number, draw width in pixels
--- - `height` number, draw height in pixels
--- - `color` optional, tint color (defaults to white)
--- - `is_for_window` optional boolean, defaults false (background). True draws in current window.
---
---@param texture_id integer
---@param top_left vec2
---@param width number
---@param height number
---@param color color|nil
---@param is_for_window boolean|nil
---@return nil
function core.graphics.draw_texture(texture_id, top_left, width, height, color, is_for_window)
  return nil
end

--- Loads an animated GIF from raw bytes and uploads all frames to the GPU.
--- Subsequent calls with the same bytes return the cached entry.
---@param gif_data string Raw GIF file bytes.
---@return integer gif_id The GIF identifier (used with draw_gif).
---@return integer width The GIF width in pixels.
---@return integer height The GIF height in pixels.
---@return integer frame_count The total number of frames.
---@return integer total_duration_ms The total animation duration in milliseconds.
function core.graphics.load_gif(gif_data)
    return 0, 0, 0, 0, 0
end

--- Draws the current frame of a loaded GIF. Frame selection is automatic
--- based on elapsed time — the animation loops continuously.
---@param gif_id integer The GIF identifier returned by load_gif.
---@param top_left vec2 Screen position (top-left corner).
---@param width number Draw width in pixels.
---@param height number Draw height in pixels.
---@param color color|nil Optional tint color (defaults to white).
---@param is_for_window boolean|nil If true, draws into the current window draw list.
---@param speed number|nil Playback speed multiplier (defaults to 1.0).
function core.graphics.draw_gif(gif_id, top_left, width, height, color, is_for_window, speed) end

-- ========================================
-- SDF Shader Rendering (GPU-accelerated)
-- ========================================

--- Draws a smooth rounded rectangle using an SDF pixel shader.
---@param p_min vec2 Top-left corner in screen space.
---@param p_max vec2 Bottom-right corner in screen space.
---@param color color Fill color.
---@param rounding number|nil Corner rounding radius (default 4.0).
---@param softness number|nil Edge softness (default 1.0).
function core.graphics.render_smooth_rect(p_min, p_max, color, rounding, softness) end

--- Draws a drop shadow behind an element using an SDF pixel shader.
---@param p_min vec2 Top-left corner of the shadow quad.
---@param p_max vec2 Bottom-right corner of the shadow quad.
---@param color color Shadow color.
---@param offset_x number Horizontal shadow offset.
---@param offset_y number Vertical shadow offset.
---@param element_w number Width of the element casting the shadow.
---@param element_h number Height of the element casting the shadow.
---@param rounding number|nil Corner rounding radius (default 6.0).
---@param softness number|nil Shadow blur softness (default 8.0).
---@param spread number|nil Shadow spread amount (default 0.0).
function core.graphics.render_drop_shadow(p_min, p_max, color, offset_x, offset_y, element_w, element_h, rounding, softness, spread) end

--- Draws a filled rectangle with a border using an SDF pixel shader.
---@param p_min vec2 Top-left corner in screen space.
---@param p_max vec2 Bottom-right corner in screen space.
---@param fill_color color Interior fill color.
---@param border_color color Border color.
---@param rounding number|nil Corner rounding radius (default 4.0).
---@param softness number|nil Edge softness (default 1.0).
---@param thickness number|nil Border thickness (default 1.0).
function core.graphics.render_border_rect(p_min, p_max, fill_color, border_color, rounding, softness, thickness) end

--- Draws a linear gradient rectangle using an SDF pixel shader.
---@param p_min vec2 Top-left corner in screen space.
---@param p_max vec2 Bottom-right corner in screen space.
---@param color_a color Start color of the gradient.
---@param color_b color End color of the gradient.
---@param angle number|nil Gradient angle in radians (default 0.0, left-to-right).
---@param rounding number|nil Corner rounding radius (default 0.0).
---@param softness number|nil Edge softness (default 0.0).
function core.graphics.render_linear_gradient(p_min, p_max, color_a, color_b, angle, rounding, softness) end

--- Draws a keybind pill widget using an SDF pixel shader.
---@param p_min vec2 Top-left corner in screen space.
---@param p_max vec2 Bottom-right corner in screen space.
---@param base_color color Base background color.
---@param elevation_color color Elevation/shadow color.
---@param accent_color color Accent highlight color.
---@param rounding number|nil Corner rounding radius (default 6.0).
---@param hover number|nil Hover animation factor 0-1 (default 0.0).
---@param listening number|nil Listening/active state factor 0-1 (default 0.0).
---@param time_val number|nil Animation time value (default 0.0).
---@param speed number|nil Animation speed multiplier (default 1.0).
function core.graphics.render_keybind_pill(p_min, p_max, base_color, elevation_color, accent_color, rounding, hover, listening, time_val, speed) end

--- Draws a dropdown field widget using an SDF pixel shader.
---@param p_min vec2 Top-left corner in screen space.
---@param p_max vec2 Bottom-right corner in screen space.
---@param base_color color Base background color.
---@param elevation_color color Elevation/shadow color.
---@param accent_color color Accent highlight color.
---@param rounding number|nil Corner rounding radius (default 4.0).
---@param hover number|nil Hover animation factor 0-1 (default 0.0).
---@param open number|nil Open state factor 0-1 (default 0.0).
---@param time_val number|nil Animation time value (default 0.0).
---@param speed number|nil Animation speed multiplier (default 1.0).
function core.graphics.render_dropdown_field(p_min, p_max, base_color, elevation_color, accent_color, rounding, hover, open, time_val, speed) end

--- Draws a section header widget using an SDF pixel shader.
---@param p_min vec2 Top-left corner in screen space.
---@param p_max vec2 Bottom-right corner in screen space.
---@param primary_color color Primary section color.
---@param secondary_color color Secondary section color.
---@param accent_color color Accent highlight color.
---@param head_split number|nil Header split ratio (default 1.0).
---@param rounding number|nil Corner rounding radius (default 4.0).
---@param hover number|nil Hover animation factor 0-1 (default 0.0).
---@param open number|nil Open state factor 0-1 (default 0.0).
---@param time_val number|nil Animation time value (default 0.0).
---@param speed number|nil Animation speed multiplier (default 1.0).
function core.graphics.render_section_header(p_min, p_max, primary_color, secondary_color, accent_color, head_split, rounding, hover, open, time_val, speed) end

--- Draws a slider track widget using an SDF pixel shader.
---@param p_min vec2 Top-left corner in screen space.
---@param p_max vec2 Bottom-right corner in screen space.
---@param fill_lo color Fill color at the low end of the slider.
---@param fill_hi color Fill color at the high end of the slider.
---@param rail_color color Rail/track background color.
---@param fill_t number Fill progress 0-1.
---@param rounding number|nil Corner rounding radius (default 3.0).
---@param hover number|nil Hover animation factor 0-1 (default 0.0).
---@param time_val number|nil Animation time value (default 0.0).
---@param speed number|nil Animation speed multiplier (default 1.0).
function core.graphics.render_slider_track(p_min, p_max, fill_lo, fill_hi, rail_color, fill_t, rounding, hover, time_val, speed) end

--- Draws a hover pill widget with animated streaks using an SDF pixel shader.
---@param p_min vec2 Top-left corner in screen space.
---@param p_max vec2 Bottom-right corner in screen space.
---@param base_color color Base background color.
---@param streak_color color Animated streak color.
---@param rounding number|nil Corner rounding radius (default 6.0).
---@param softness number|nil Edge softness (default 1.0).
---@param density number|nil Streak density (default 1.0).
---@param time_val number|nil Animation time value (default 0.0).
---@param speed number|nil Animation speed multiplier (default 1.0).
function core.graphics.render_hover_pill(p_min, p_max, base_color, streak_color, rounding, softness, density, time_val, speed) end

--------------------------------------------------------------------------------
-- EXAMPLES
--------------------------------------------------------------------------------

--[[----------------------------------------------------------------------------
Example A, Most common, Load a local texture from scripts_data and draw every frame

Goal:
- Put `icons/sword.png` under: <loader_path>/scripts_data/icons/sword.png
- Load it once at startup
- Draw it each frame

Files:
- You distribute a script that, on first run, expects the file to exist inside scripts_data.
- Later, our library will automate ensuring files exist, downloading, caching, etc.

Code:

local sword_tex_id = nil
local sword_w, sword_h = 0, 0

local function load_sword_icon_once()
  if sword_tex_id ~= nil then
    return
  end

  local bytes = core.read_data_file("icons/sword.png")
  if not bytes or #bytes == 0 then
    core.log("Missing icon: scripts_data/icons/sword.png")
    return
  end

  local tex_id, w, h = core.graphics.load_texture(bytes)
  if not tex_id then
    core.log("Failed to decode icon: icons/sword.png")
    return
  end

  sword_tex_id = tex_id
  sword_w = w or sword_w
  sword_h = h or sword_h

  core.log("Loaded sword icon, texture_id=" .. tostring(sword_tex_id) ..
           ", w=" .. tostring(sword_w) .. ", h=" .. tostring(sword_h))
end

local function on_render()
  -- Ensure it is loaded once before drawing
  load_sword_icon_once()

  if sword_tex_id then
    local pos = vec2.new(20, 20)
    core.graphics.draw_texture(sword_tex_id, pos, 32, 32)
  end
end

-- Register your render callback as appropriate for your environment:
-- core.register_callback("render", on_render)
------------------------------------------------------------------------------]]

--[[----------------------------------------------------------------------------
Example B, Download once (if missing), save to scripts_data, load once, draw every frame

Goal:
- If icons/sword.png is missing locally, download it.
- Save it into scripts_data for next launch.
- Load it into GPU once.
- Draw every frame.

Important lifecycle concept:
- Download and file write happens once (or rarely).
- Texture load happens once (or whenever you need to refresh).
- draw_texture happens every frame.

Code:

local remote_icon_url = "https://dummyimage.com/64x64/000/fff.png"
local remote_icon_path = "icons/remote_icon.png"

local remote_tex_id = nil
local remote_w, remote_h = 0, 0
local remote_requested = false

local function load_remote_icon_from_disk_once()
  if remote_tex_id ~= nil then
    return true
  end

  local bytes = core.read_data_file(remote_icon_path)
  if not bytes or #bytes == 0 then
    return false
  end

  local tex_id, w, h = core.graphics.load_texture(bytes)
  if not tex_id then
    core.log("Failed to decode icon after reading from disk: " .. remote_icon_path)
    return false
  end

  remote_tex_id = tex_id
  remote_w = w or remote_w
  remote_h = h or remote_h
  return true
end

local function ensure_remote_icon_available()
  -- 1) If already loaded from disk, done.
  if load_remote_icon_from_disk_once() then
    return
  end

  -- 2) If not on disk, request download once.
  if remote_requested then
    return
  end
  remote_requested = true

  -- Ensure folder exists
  core.create_data_folder("icons")

  core.http_get(remote_icon_url, function(code, content_type, body, headers)
    if code ~= 200 or not body or #body == 0 then
      core.log("Download failed, code=" .. tostring(code) .. ", type=" .. tostring(content_type))
      remote_requested = false
      return
    end

    -- Persist to scripts_data so we do not re-download next time
    core.create_data_file(remote_icon_path)
    core.write_data_file(remote_icon_path, body)

    -- Load into GPU once
    local tex_id, w, h = core.graphics.load_texture(body)
    if not tex_id then
      core.log("Downloaded icon, but decode failed: " .. remote_icon_path)
      remote_requested = false
      return
    end

    remote_tex_id = tex_id
    remote_w = w or remote_w
    remote_h = h or remote_h

    core.log("Downloaded and loaded icon, texture_id=" .. tostring(remote_tex_id))
  end)
end

local function on_render_remote()
  ensure_remote_icon_available()

  if remote_tex_id then
    local pos = vec2.new(20, 60)
    core.graphics.draw_texture(remote_tex_id, pos, 32, 32)
  end
end

-- Register your render callback as appropriate:
-- core.register_callback("render", on_render_remote)

------------------------------------------------------------------------------]]

--[[----------------------------------------------------------------------------
Example C, HTTP GET with headers (data request, not texture)

Goal:
- Fetch JSON with auth headers.
- Process response.

Code:

local function fetch_profile()
  core.http_get("https://httpbin.org/get", {
    ["Authorization"] = "Bearer token123",
    ["Accept"] = "application/json",
    ["User-Agent"] = "MyApp/1.0",
  }, function(code, content_type, body, headers)
    core.log("Status: " .. tostring(code))
    core.log("Content-Type: " .. tostring(content_type))
    if body then
      core.log("Body: " .. tostring(body))
    end
  end)
end

-- fetch_profile()
------------------------------------------------------------------------------]]

-- More Http examples:
-- Without headers
-- core.http_get("https://httpbin.org/get", function(http_code, content_type, response_data, response_headers)
--     core.log("Status: " .. http_code)
--     core.log("Response: " .. response_data)
--     core.log("ResponseHeaders: " .. response_headers)
-- end)

-- -- With headers
-- core.http_get("https://httpbin.org/get", {
--     ["Authorization"] = "Bearer token123",
--     ["User-Agent"] = "MyApp/1.0",
--     ["Accept"] = "application/json"
-- }, function(http_code, content_type, response_data, response_headers)
--     core.log("Status: " .. http_code)
--     core.log("Response: " .. response_data)
--     core.log("ResponseHeaders: " .. response_headers)
-- end)

-- Load external texture example:
-- local function on_render()
--   if downloaded_texture then
--         -- Draw at position (100, 100) with size 200x200
--         local position = vec2.new(100, 100)
--         core.graphics.draw_texture(downloaded_texture, position, 200, 200)

--         -- Optional: draw with a custom color (semi-transparent white)
--         -- local color = core.color.new(255, 255, 255, 128)
--         -- core.graphics.draw_texture(downloaded_texture, position, 200, 200, color)
--     end

-- end

-- core.http_get("https://dummyimage.com/200x200/000/fff.png", function(http_code, content_type, response_data, response_headers)
--     if content_type ~= "error" and http_code == 200 then
--         downloaded_texture, width, height = core.graphics.load_texture(response_data)

--         if downloaded_texture then
--             core.log("Texture object created successfully and stored in global variable")
--             core.log("Texture: " .. downloaded_texture)
--             core.log("width: " .. width)
--             core.log("height: " .. height)
--         else
--             core.log("Failed to create texture from image data")
--         end
--     else
--         core.log("HTTP request failed. Code: " .. tostring(http_code))
--     end
-- end)

---@class quest_log_entry
---@field title string The title of the quest.
---@field level integer The level of the quest.
---@field suggested_group integer The suggested group size for the quest.
---@field is_header boolean Whether this entry is a header (zone name) rather than a quest.
---@field is_collapsed boolean Whether this header is collapsed.
---@field is_complete integer|nil 1 if the quest is complete, -1 if failed, nil if in progress.
---@field frequency integer The quest frequency (0 = normal, 1 = daily, 2 = weekly).
---@field quest_id integer The unique quest ID.
---@field is_task boolean Whether the quest is a bonus objective / world quest task.
---@field is_story boolean Whether the quest is part of the zone story line.
---@field start_event boolean Whether the quest has a start event.
---@field is_on_map boolean Whether the quest is shown on the map.
---@field has_local_poi boolean Whether the quest has a local point of interest.
---@field is_hidden boolean Whether the quest is hidden.
---@field quest_log_index integer The internal quest log index.

---@class quest_objective
---@field description string The objective description text.
---@field objective_type string The type of objective.
---@field is_completed boolean Whether this objective is completed.

---@class gossip_reward
---@field id integer The reward item ID.
---@field quantity integer The reward quantity.
---@field reward_type integer The reward type.

---@class gossip_option
---@field name string The gossip option name.
---@field gossip_type string The gossip type.
---@field gossip_option_id integer The gossip option ID.
---@field icon integer The gossip icon.
---@field status integer The gossip status.
---@field spell_id integer The associated spell ID.
---@field flags integer The gossip flags.
---@field order_index integer The order index.
---@field rewards gossip_reward[] The rewards for this gossip option.

---@class gossip_quest
---@field title string The quest title.
---@field quest_level integer The quest level.
---@field is_trivial boolean Whether the quest is trivial (grey).
---@field frequency integer The quest frequency.
---@field is_repeatable boolean Whether the quest is repeatable.
---@field is_complete boolean Whether the quest is complete.
---@field is_legendary boolean Whether the quest is legendary.
---@field is_ignored boolean Whether the quest is ignored.
---@field quest_id integer The unique quest ID.
---@field is_important boolean Whether the quest is important.
---@field is_meta boolean Whether the quest is a meta quest.

---@class trainer_service_info
---@field spell_name string The spell name.
---@field rank string The spell rank.
---@field category string The spell category.
---@field expanded integer Whether the category is expanded.

---@class trainer_service_cost
---@field service_cost integer The service cost in copper.
---@field talent_cost integer The talent cost.
---@field profession_cost integer The profession cost.

---@class item_spell_info
---@field spell_name string The spell name.
---@field spell_id integer The spell ID.

---@class quest_item_info
---@field name string The item name.
---@field item_link string The item link string.
---@field quality integer The item quality (0-8).
---@field item_level integer The item level.
---@field min_level integer The minimum required level.
---@field item_type string The item type.
---@field item_sub_type string The item sub type.
---@field stack_count integer The max stack count.
---@field equip_loc string The equip location.
---@field texture integer The item texture ID.
---@field sell_price integer The sell price in copper.
---@field class_id integer The item class ID.
---@field subclass_id integer The item subclass ID.
---@field bind_type integer The bind type.
---@field expansion_id integer The expansion ID.
---@field set_id integer The set ID.
---@field is_crafting_reagent boolean Whether the item is a crafting reagent.
---@field description string The item description.

core.quests = {}

--- Accepts the currently offered quest.
function core.quests.accept_quest() end

--- Closes the quest dialog.
function core.quests.close_quest() end

--- Declines the currently offered quest.
function core.quests.decline_quest() end

--- Completes the currently active quest dialog.
function core.quests.complete_quest() end

--- Selects a quest reward choice.
---@param choice? integer The reward choice index (default 0).
function core.quests.get_quest_reward(choice) end

--- Confirms acceptance of an auto-accept quest.
function core.quests.confirm_accept_quest() end

--- Returns the total number of entries in the quest log (including headers).
---@return integer count The number of quest log entries.
function core.quests.get_num_quest_log_entries() return 0 end

--- Returns information about a quest in the quest log.
---@param index integer The quest log index.
---@return quest_log_entry entry A table containing the quest log entry information.
function core.quests.get_quest_log_title(index) return {} end

--- Checks if a quest has been flagged as completed (historically).
---@param quest_id integer The quest ID.
---@return boolean is_completed Whether the quest is flagged completed.
function core.quests.is_quest_flagged_completed(quest_id) return false end

--- Checks if the player is currently on a quest.
---@param quest_id integer The quest ID.
---@return boolean is_on_quest Whether the player is on the quest.
function core.quests.is_on_quest(quest_id) return false end

--- Selects a quest log entry (sets it as the active quest).
---@param index integer The quest log index.
function core.quests.select_quest_log_entry(index) end

--- Returns the number of objectives for a quest.
---@param quest_log_index integer The quest log index.
---@return integer count The number of objectives.
function core.quests.get_num_quest_leader_boards(quest_log_index) return 0 end

--- Returns information about a quest objective.
---@param obj_index integer The objective index.
---@param quest_log_index? integer The quest log index (default 0).
---@return quest_objective objective A table containing the objective information.
function core.quests.get_quest_log_leader_board(obj_index, quest_log_index) return {} end

--- Returns the item link for a quest log reward/choice item.
---@param type string The type of item ("reward" or "choice").
---@param index integer The item index.
---@param quest_id? integer The quest ID (default 0).
---@return string link The item link string.
function core.quests.get_quest_log_item_link(type, index, quest_id) return "" end

--- Adds a quest to the watch list (tracker).
---@param index integer The quest log index.
---@param watch_time? number The watch time duration (default 0).
function core.quests.add_quest_watch(index, watch_time) end

--- Removes a quest from the watch list (tracker).
---@param index integer The quest log index.
function core.quests.remove_quest_watch(index) end

--- Pushes the selected quest to the quest detail frame.
function core.quests.quest_log_push_quest() end

--- Sets the selected quest for abandonment.
function core.quests.set_abandon_quest() end

--- Abandons the currently selected quest.
function core.quests.abandon_quest() end

--- Returns the list of gossip options from an NPC.
---@return gossip_option[] options An array of gossip option tables.
function core.quests.get_gossip_options() return {} end

--- Selects a gossip option by ID.
---@param id integer The gossip option ID.
function core.quests.select_gossip_option(id) end

--- Returns the list of available quests from a gossip NPC.
---@return gossip_quest[] quests An array of available quest tables.
function core.quests.get_gossip_available_quests() return {} end

--- Returns the list of active quests from a gossip NPC.
---@return gossip_quest[] quests An array of active quest tables.
function core.quests.get_gossip_active_quests() return {} end

--- Selects an available quest from the gossip frame.
---@param quest_id integer The quest ID.
function core.quests.select_gossip_available_quest(quest_id) end

--- Selects an active quest from the gossip frame.
---@param quest_id integer The quest ID.
function core.quests.select_gossip_active_quest(quest_id) end

--- Closes the gossip frame.
function core.quests.close_gossip() end

--- Returns whether the gossip frame is currently shown.
---@return boolean is_shown Whether the gossip frame is shown.
function core.quests.is_gossip_frame_shown() return false end

--- Returns the number of trainer services available.
---@return integer count The number of trainer services.
function core.quests.get_num_trainer_services() return 0 end

--- Returns information about a trainer service.
---@param index integer The trainer service index.
---@return trainer_service_info info A table containing the trainer service information.
function core.quests.get_trainer_service_info(index) return {} end

--- Returns the cost of a trainer service.
---@param index integer The trainer service index.
---@return trainer_service_cost cost A table containing the trainer service costs.
function core.quests.get_trainer_service_cost(index) return {} end

--- Buys a trainer service.
---@param index integer The trainer service index.
function core.quests.buy_trainer_service(index) end

--- Returns spell information for an item.
---@param item_id_or_link integer|string The item ID or item link.
---@return item_spell_info info A table containing the item spell information.
function core.quests.get_item_spell(item_id_or_link) return {} end

--- Returns detailed information about an item.
---@param item_id_or_link integer|string The item ID or item link.
---@return quest_item_info info A table containing the item information.
function core.quests.get_item_info(item_id_or_link) return {} end

--- Returns the title of an active quest at the given index (NPC quest frame).
---@param index integer The active quest index.
---@return string title The quest title.
function core.quests.get_active_title(index) return "" end

--- Returns the title of an available quest at the given index (NPC quest frame).
---@param index integer The available quest index.
---@return string title The quest title.
function core.quests.get_available_title(index) return "" end

--- Returns the level of an active quest at the given index (NPC quest frame).
---@param index integer The active quest index.
---@return integer level The quest level.
function core.quests.get_active_level(index) return 0 end

--- Returns the level of an available quest at the given index (NPC quest frame).
---@param index integer The available quest index.
---@return integer level The quest level.
function core.quests.get_available_level(index) return 0 end

--- Selects an active quest from the NPC quest frame.
---@param index integer The active quest index.
function core.quests.select_active_quest(index) end

--- Selects an available quest from the NPC quest frame.
---@param index integer The available quest index.
function core.quests.select_available_quest(index) end

--- Returns the reward money for the current quest.
---@return integer copper The reward money in copper.
function core.quests.get_reward_money() return 0 end

--- Returns the item link for a quest reward/choice item.
---@param type string The type of item ("reward" or "choice").
---@param index integer The item index.
---@return string link The item link string.
function core.quests.get_quest_item_link(type, index) return "" end

---@class replicate_item_info
---@field name string The name of the auction item.
---@field texture integer The texture/icon ID of the item.
---@field count integer The stack count of the item.
---@field quality_id integer The item quality (0 = Poor, 1 = Common, 2 = Uncommon, 3 = Rare, 4 = Epic, 5 = Legendary).
---@field usable boolean Whether the item is usable by the local player.
---@field level integer The item level.
---@field level_type string The type of the level value (e.g. "ilvl").
---@field min_bid number The minimum bid amount in copper.
---@field min_increment number The minimum bid increment in copper.
---@field buyout_price number The buyout price in copper.
---@field bid_amount number The current highest bid amount in copper.
---@field high_bidder string The name of the highest bidder.
---@field owner string The name of the auction owner.
---@field sale_status integer The sale status of the auction.
---@field item_id integer The item ID.
---@field has_all_info boolean Whether all item information has been loaded.

---@class commodity_search_result_info
---@field item_id integer The item ID.
---@field quantity integer The quantity available in this listing.
---@field unit_price number The price per unit in copper.
---@field auction_id integer The auction ID.
---@field num_owner_items integer The number of items owned by the local player in this listing.
---@field contains_owner_item boolean Whether this listing contains items posted by the local player.
---@field contains_account_item boolean Whether this listing contains items posted by any character on the account.

---@class item_search_result_info
---@field item_id integer The item ID.
---@field auction_id integer The auction ID.
---@field quantity integer The quantity in this listing.
---@field bid_amount number The current highest bid in copper.
---@field buyout_amount number The buyout price in copper.
---@field min_bid number The minimum bid in copper.
---@field time_left integer The time remaining category (1 = Short, 2 = Medium, 3 = Long, 4 = Very Long).
---@field item_link string The item link string for this listing.
---@field contains_owner_item boolean Whether this listing was posted by the local player.
---@field contains_account_item boolean Whether this listing was posted by any character on the account.

---@class owned_auction_info
---@field auction_id integer The auction ID.
---@field item_id integer The item ID.
---@field item_link string The item link string.
---@field status integer The auction status.
---@field quantity integer The quantity listed.
---@field time_left integer The time remaining category.
---@field bid_amount number The current highest bid in copper.
---@field buyout_amount number The buyout price in copper.
---@field bidder string The name of the current highest bidder.

---@class ah_item_info
---@field name string The item name.
---@field item_link string The item link string.
---@field quality integer The item quality.
---@field item_level integer The item level.
---@field min_level integer The minimum required player level.
---@field item_type string The item type category.
---@field item_sub_type string The item sub-type category.
---@field stack_count integer The maximum stack count.
---@field equip_loc string The equip location slot.
---@field texture integer The texture/icon ID.
---@field sell_price integer The vendor sell price in copper.
---@field bind_type integer The bind type (0 = None, 1 = BoP, 2 = BoE, 3 = BoU).

---@class ah_tooltip_line
---@field left string The left-side text of the tooltip line.
---@field right string The right-side text of the tooltip line.
---@field r number The red color component (0-1).
---@field g number The green color component (0-1).
---@field b number The blue color component (0-1).

---@class auction_house
core.auction_house = {}

--- Initiates a full auction house scan (replicate).
--- Results become available via get_num_replicate_items / get_replicate_item_info.
---@return nil
function core.auction_house.replicate_items() end

--- Returns the total number of items from the last replicate scan.
---@return integer count The number of replicate items available.
function core.auction_house.get_num_replicate_items()
    return 0
end

--- Returns detailed information about a replicate item at the given index.
---@param index integer The 0-based index of the replicate item.
---@return replicate_item_info info A table containing the replicate item information.
function core.auction_house.get_replicate_item_info(index)
    return {}
end

--- Returns the item link string for a replicate item at the given index.
---@param index integer The 0-based index of the replicate item.
---@return string link The item link string.
function core.auction_house.get_replicate_item_link(index)
    return ""
end

--- Returns the time remaining category for a replicate item.
---@param index integer The 0-based index of the replicate item.
---@return integer time_left The time remaining category.
function core.auction_house.get_replicate_item_time_left(index)
    return 0
end

--- Returns a batch of replicate items as a raw string (for fast bulk processing).
---@param start integer The starting index.
---@param count integer The number of items to retrieve.
---@return string raw_data The raw serialized item data.
function core.auction_house.batch_get_replicate_items(start, count)
    return ""
end

--- Sends a search query for an item on the auction house.
--- Results are retrieved via commodity or item search result functions depending on the item type.
---@param item_id integer The item ID to search for.
---@param item_level? integer Optional item level filter (default 0).
---@param item_suffix? integer Optional item suffix filter (default 0).
---@param separate_owner_items? boolean Whether to separate the player's own listings (default false).
---@return nil
function core.auction_house.send_search_query(item_id, item_level, item_suffix, separate_owner_items) end

--- Sends a sell-oriented search query (used when posting items to compare prices).
---@param item_id integer The item ID to search for.
---@param item_level? integer Optional item level filter (default 0).
---@param item_suffix? integer Optional item suffix filter (default 0).
---@param separate_owner_items? boolean Whether to separate the player's own listings (default false).
---@return nil
function core.auction_house.send_sell_search_query(item_id, item_level, item_suffix, separate_owner_items) end

--- Returns the number of commodity search results for the given item.
---@param item_id integer The item ID.
---@return integer count The number of commodity search results.
function core.auction_house.get_num_commodity_search_results(item_id)
    return 0
end

--- Returns information about a specific commodity search result.
---@param item_id integer The item ID.
---@param index integer The 0-based index of the result.
---@return commodity_search_result_info info A table containing the commodity result information.
function core.auction_house.get_commodity_search_result_info(item_id, index)
    return {}
end

--- Returns whether all commodity search results have been received for the given item.
---@param item_id integer The item ID.
---@return boolean has_full True if all results have been received.
function core.auction_house.has_full_commodity_search_results(item_id)
    return false
end

--- Returns the number of item (non-commodity) search results.
---@param item_id integer The item ID.
---@param item_level? integer Optional item level filter (default 0).
---@param item_suffix? integer Optional item suffix filter (default 0).
---@return integer count The number of item search results.
function core.auction_house.get_num_item_search_results(item_id, item_level, item_suffix)
    return 0
end

--- Returns information about a specific item search result.
---@param item_id integer The item ID.
---@param item_level? integer Optional item level filter (default 0).
---@param item_suffix? integer Optional item suffix filter (default 0).
---@param index integer The 0-based index of the result.
---@return item_search_result_info info A table containing the item result information.
function core.auction_house.get_item_search_result_info(item_id, item_level, item_suffix, index)
    return {}
end

--- Returns whether all item search results have been received.
---@param item_id integer The item ID.
---@param item_level? integer Optional item level filter (default 0).
---@param item_suffix? integer Optional item suffix filter (default 0).
---@return boolean has_full True if all results have been received.
function core.auction_house.has_full_item_search_results(item_id, item_level, item_suffix)
    return false
end

--- Sends a request to query the player's own active auctions.
--- Results become available via get_num_owned_auctions / get_owned_auction_info.
---@return nil
function core.auction_house.query_owned_auctions() end

--- Returns the number of owned auctions.
---@return integer count The number of the player's active auctions.
function core.auction_house.get_num_owned_auctions()
    return 0
end

--- Returns information about an owned auction at the given index.
---@param index integer The 0-based index of the owned auction.
---@return owned_auction_info info A table containing the owned auction information.
function core.auction_house.get_owned_auction_info(index)
    return {}
end

--- Posts a commodity item on the auction house.
---@param bag integer The bag index containing the item.
---@param slot integer The slot index within the bag.
---@param duration integer The auction duration (1 = 12h, 2 = 24h, 3 = 48h).
---@param quantity integer The quantity to post.
---@param unit_price number The price per unit in copper.
---@return boolean success Whether the post was successful.
function core.auction_house.post_commodity(bag, slot, duration, quantity, unit_price)
    return false
end

--- Posts a non-commodity item on the auction house.
---@param bag integer The bag index containing the item.
---@param slot integer The slot index within the bag.
---@param duration integer The auction duration (1 = 12h, 2 = 24h, 3 = 48h).
---@param quantity integer The quantity to post.
---@param bid number The starting bid in copper.
---@param buyout number The buyout price in copper.
---@return boolean success Whether the post was successful.
function core.auction_house.post_item(bag, slot, duration, quantity, bid, buyout)
    return false
end

--- Places a bid on an auction.
---@param auction_id integer The auction ID to bid on.
---@param bid_amount number The bid amount in copper.
---@return nil
function core.auction_house.place_bid(auction_id, bid_amount) end

--- Initiates a commodity purchase. Must be confirmed with confirm_commodities_purchase.
---@param item_id integer The item ID of the commodity.
---@param quantity integer The quantity to purchase.
---@return nil
function core.auction_house.start_commodities_purchase(item_id, quantity) end

--- Confirms a pending commodity purchase started with start_commodities_purchase.
---@param item_id integer The item ID of the commodity.
---@param quantity integer The quantity to purchase.
---@return nil
function core.auction_house.confirm_commodities_purchase(item_id, quantity) end

--- Cancels a pending commodity purchase.
---@return nil
function core.auction_house.cancel_commodities_purchase() end

--- Cancels one of the player's own auctions.
---@param owned_auction_id integer The owned auction ID (from get_owned_auction_info).
---@return nil
function core.auction_house.cancel_auction(owned_auction_id) end

--- Returns whether an owned auction can be cancelled.
---@param owned_auction_id integer The owned auction ID.
---@return boolean can_cancel True if the auction can be cancelled.
function core.auction_house.can_cancel_auction(owned_auction_id)
    return false
end

--- Calculates the deposit cost for posting a commodity.
---@param item_id integer The item ID.
---@param duration integer The auction duration (1 = 12h, 2 = 24h, 3 = 48h).
---@param quantity integer The quantity to post.
---@return number deposit The deposit cost in copper.
function core.auction_house.calculate_commodity_deposit(item_id, duration, quantity)
    return 0
end

--- Returns the cancellation cost for an owned auction.
---@param owned_auction_id integer The owned auction ID.
---@return number cost The cancellation cost in copper.
function core.auction_house.get_cancel_cost(owned_auction_id)
    return 0
end

--- Returns whether the AH throttled message system is ready for another request.
--- Use this to avoid sending requests too quickly and getting throttled.
---@return boolean ready True if the system is ready for a new request.
function core.auction_house.is_throttled_message_system_ready()
    return false
end

--- Closes the auction house interface.
---@return nil
function core.auction_house.close_auction_house() end

--- Returns whether the auction house frame is currently shown.
---@return boolean is_shown True if the auction house is open.
function core.auction_house.is_auction_house_shown()
    return false
end

--- Returns the remaining duration (in seconds) for the current commodity price quote.
--- A quote locks in the price for a commodity purchase for a limited time.
---@return number seconds The remaining quote duration in seconds.
function core.auction_house.get_quote_duration_remaining()
    return 0
end

--- Returns the commodity status of an item in a bag slot.
--- Determines whether the item will be listed as a commodity or a regular item.
---@param bag integer The bag index.
---@param slot integer The slot index within the bag.
---@return integer status The commodity status code.
function core.auction_house.get_item_commodity_status(bag, slot)
    return 0
end

--- Returns detailed item information for an item ID (similar to GetItemInfo).
---@param item_id integer The item ID.
---@return ah_item_info info A table containing the item information.
function core.auction_house.get_item_info(item_id)
    return {}
end

--- Returns the icon texture name/path for an item.
---@param item_id integer The item ID.
---@return string icon_name The icon texture name.
function core.auction_house.get_item_icon_name(item_id)
    return ""
end

--- Returns the tooltip lines for an item.
--- Each line contains left/right text and an RGB color.
---@param item_id integer The item ID.
---@param link_fragment? string Optional item link fragment for more specific tooltip data.
---@return ah_tooltip_line[] lines An array of tooltip line tables.
function core.auction_house.get_item_tooltip(item_id, link_fragment)
    return {}
end

--- Picks up an item from a bag slot onto the cursor (for placing into the AH sell slot).
---@param bag integer The bag index.
---@param slot integer The slot index within the bag.
---@return nil
function core.auction_house.pickup_container_item(bag, slot) end

--- Clicks the auction sell button to confirm placing the cursor item into the sell slot.
---@return nil
function core.auction_house.click_auction_sell_button() end

--- Posts an auction using the classic auction house flow.
--- Requires an item to be placed in the sell slot first via pickup_container_item + click_auction_sell_button.
---@param min_bid number The minimum starting bid in copper.
---@param buyout number The buyout price in copper.
---@param duration integer The auction duration (1 = 12h, 2 = 24h, 3 = 48h).
---@param stack_size? integer The stack size per auction (default 1).
---@param num_stacks? integer The number of stacks to post (default 1).
---@return boolean success Whether the auction was posted successfully.
function core.auction_house.do_post_auction(min_bid, buyout, duration, stack_size, num_stacks)
    return false
end

--- Returns information about the item currently in the auction sell slot.
---@return string info The sell item info string.
function core.auction_house.get_auction_sell_item_info()
    return ""
end

--- Returns the name of the item currently on the cursor.
---@return string name The cursor item name.
function core.auction_house.get_cursor_item_name()
    return ""
end

---@class mail
core.mail = {}

--- Checks the inbox for new mail.
---@return nil
function core.mail.check_inbox()
    return nil
end

--- Returns the number of items in the inbox.
---@return integer count The number of inbox items.
function core.mail.get_num_inbox_items()
    return 0
end

---@class mail_header_info
---@field package_icon string The package icon path.
---@field stationery_icon string The stationery icon path.
---@field sender string The sender name.
---@field subject string The mail subject.
---@field money number The money attached (in copper).
---@field cod_amount number The COD amount (in copper).
---@field days_left number The remaining days before expiration.
---@field item_count integer The number of items attached.
---@field was_read boolean Whether the mail has been read.
---@field was_returned boolean Whether the mail was returned.
---@field text_created boolean Whether the mail has text content.
---@field can_reply boolean Whether the mail can be replied to.
---@field is_gm boolean Whether the mail is from a GM.

--- Returns the header information for a mail at the given index.
---@param index integer The mail index.
---@return mail_header_info header The mail header info table.
function core.mail.get_inbox_header_info(index)
    return {}
end

---@class mail_item_info
---@field name string The item name.
---@field item_id integer The item ID.
---@field texture string The item texture path.
---@field count integer The item stack count.
---@field quality integer The item quality.
---@field can_use boolean Whether the item can be used by the player.

--- Returns the item information for a specific item in a mail.
---@param index integer The mail index.
---@param item_index integer The item index within the mail.
---@return mail_item_info item The mail item info table.
function core.mail.get_inbox_item(index, item_index)
    return {}
end

--- Returns the body text of a mail.
---@param index integer The mail index.
---@return string text The mail body text.
function core.mail.get_inbox_text(index)
    return ""
end

--- Takes an item from a mail at the given index.
---@param index integer The mail index.
---@param item_index integer The item index within the mail.
---@return nil
function core.mail.take_inbox_item(index, item_index)
    return nil
end

--- Takes the money from a mail at the given index.
---@param index integer The mail index.
---@return nil
function core.mail.take_inbox_money(index)
    return nil
end

--- Takes the text item from a mail at the given index.
---@param index integer The mail index.
---@return nil
function core.mail.take_inbox_text_item(index)
    return nil
end

--- Deletes a mail at the given index.
---@param index integer The mail index.
---@return nil
function core.mail.delete_inbox_item(index)
    return nil
end

--- Returns a mail to the sender.
---@param index integer The mail index.
---@return nil
function core.mail.return_inbox_item(index)
    return nil
end

--- Auto-loots all items from a mail at the given index.
---@param index integer The mail index.
---@return nil
function core.mail.auto_loot_mail_item(index)
    return nil
end

--- Sends a mail to a recipient.
---@param recipient string The recipient character name.
---@param subject string|nil The mail subject (default "").
---@param body string|nil The mail body (default "").
---@return nil
function core.mail.send_mail(recipient, subject, body)
    return nil
end

--- Sets the money amount to attach to the outgoing mail.
---@param money integer The amount in copper.
---@return nil
function core.mail.set_send_mail_money(money)
    return nil
end

--- Returns the cost to send a mail.
---@return number price The mailing cost.
function core.mail.get_send_mail_price()
    return 0
end

--- Returns whether a mail at the given index can be deleted.
---@param index integer The mail index.
---@return boolean can_delete True if the mail can be deleted.
function core.mail.inbox_item_can_delete(index)
    return false
end

--- Returns whether the player has new unread mail.
---@return boolean has_new True if there is new mail.
function core.mail.has_new_mail()
    return false
end

---@class pet_battle_name_info
---@field custom_name string The player-assigned name (empty if none).
---@field species_name string The species name.

---@class pet_battle_xp_info
---@field xp number Current XP.
---@field max_xp number XP needed for next level.

---@class pet_battle_ability_info
---@field id number The ability ID.
---@field name string The ability name.
---@field icon string The icon texture path.
---@field max_cooldown number Cooldown in turns.
---@field description string Raw description text.
---@field num_turns number Duration in rounds (usually 1).
---@field pet_type number Pet type 1-10.
---@field no_strong_weak_hints boolean Whether to hide type advantage hints.

---@class pet_battle_ability_state
---@field is_usable boolean Whether the ability can be used right now.
---@field current_cooldown number Turns remaining on cooldown.
---@field current_lockdown number Turns remaining on lockdown.

---@class pet_battle_aura_info
---@field aura_id number Ability ID of the aura.
---@field instance_id number Unique aura instance identifier.
---@field turns_remaining number Turns left.
---@field is_buff boolean True if displayed to the user.

---@class pet_journal_count_info
---@field num_pets number Total pets available in the game.
---@field num_owned number Pets currently owned by the player.

---@class pet_journal_index_info
---@field pet_id string Pet GUID.
---@field species_id number BattlePetSpeciesID.
---@field owned boolean Whether the player owns this pet.
---@field custom_name string Player-assigned name (empty if none).
---@field level number Pet level.
---@field favorite boolean Marked as favorite.
---@field is_revoked boolean Whether the pet is revoked.
---@field species_name string Species name.
---@field icon number Icon FileDataID.
---@field pet_type number Pet type 1-10.
---@field companion_id number NPC ID.
---@field tooltip string Source/location text.
---@field description string Flavor text.
---@field is_wild boolean Capturable in the wild.
---@field can_battle boolean Can participate in battles.
---@field is_tradeable boolean Can be traded/caged.
---@field is_unique boolean Limited to one.
---@field obtainable boolean Currently obtainable.

---@class pet_journal_pet_id_info
---@field species_id number BattlePetSpeciesID.
---@field custom_name string Player-assigned name (empty if none).
---@field level number Pet level.
---@field xp number Current XP.
---@field max_xp number XP needed for next level.
---@field display_id number Creature display ID.
---@field is_favorite boolean Marked as favorite.
---@field name string Species name.
---@field icon number Icon FileDataID.
---@field pet_type number Pet type 1-10.
---@field creature_id number NPC ID.
---@field source_text string Source/location text.
---@field description string Flavor text.
---@field is_wild boolean Capturable in the wild.
---@field can_battle boolean Can participate in battles.
---@field is_tradeable boolean Can be traded/caged.
---@field is_unique boolean Limited to one.
---@field obtainable boolean Currently obtainable.

---@class pet_journal_species_info
---@field species_name string Species name.
---@field species_icon number Icon FileDataID.
---@field pet_type number Pet type 1-10.
---@field companion_id number NPC ID.
---@field tooltip_source string Source/location text.
---@field tooltip_description string Flavor text.
---@field is_wild boolean Capturable in the wild.
---@field can_battle boolean Can participate in battles.
---@field is_tradeable boolean Can be traded/caged.
---@field is_unique boolean Limited to one.
---@field obtainable boolean Currently obtainable.
---@field creature_display_id number Creature display ID.

---@class pet_journal_stats
---@field health number Current HP (0 or negative if dead).
---@field max_health number Maximum HP.
---@field power number Power stat.
---@field speed number Speed stat.
---@field rarity number Quality (1=Poor, 2=Common, 3=Uncommon, 4=Rare, 5=Epic, 6=Legendary).

---@class pet_loadout_info
---@field pet_guid string GUID of the pet in this slot.
---@field ability1 number Ability ID for slot 1.
---@field ability2 number Ability ID for slot 2.
---@field ability3 number Ability ID for slot 3.
---@field locked boolean Whether the slot is locked/unavailable.

---@class pet_ability_list_info
---@field ability_ids number[] Array of ability IDs available to the species.
---@field level_thresholds number[] Parallel array of level requirements for each ability.

---@class pet_ability_info
---@field name string Ability name.
---@field icon string Icon texture path.
---@field type number BattlePetTypeID (1-10).

---@class pet_battle
core.pet_battle = {}

--- Returns whether the player is currently in a pet battle.
--- Returns false on Classic.
---@return boolean is_in_battle Whether a pet battle is active.
function core.pet_battle.is_in_battle()
    return false
end

--- Returns whether the current pet battle is against a wild pet.
---@return boolean is_wild True if fighting a wild pet.
function core.pet_battle.is_wild_battle()
    return false
end

--- Returns the current pet battle state as an integer.
---@return number state The battle state value.
function core.pet_battle.get_battle_state()
    return 0
end

--- Returns the active pet index (1-3) for the given side.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@return number index The active pet index (1-3).
function core.pet_battle.get_active_pet(owner)
    return 0
end

--- Returns the number of pets on the given side (1-3).
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@return number count The number of pets.
function core.pet_battle.get_num_pets(owner)
    return 0
end

--- Returns the name info for a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return pet_battle_name_info name A table with custom_name and species_name.
function core.pet_battle.get_name(owner, index)
    return {}
end

--- Returns the current HP of a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return number health Current HP.
function core.pet_battle.get_health(owner, index)
    return 0
end

--- Returns the maximum HP of a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return number max_health Maximum HP.
function core.pet_battle.get_max_health(owner, index)
    return 0
end

--- Returns the speed stat of a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return number speed Speed stat.
function core.pet_battle.get_speed(owner, index)
    return 0
end

--- Returns the power stat of a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return number power Power stat.
function core.pet_battle.get_power(owner, index)
    return 0
end

--- Returns the level of a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return number level Battle level.
function core.pet_battle.get_level(owner, index)
    return 0
end

--- Returns the XP info of a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return pet_battle_xp_info xp A table with xp and max_xp.
function core.pet_battle.get_xp(owner, index)
    return {}
end

--- Returns the BattlePetSpeciesID of a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return number species_id BattlePetSpeciesID.
function core.pet_battle.get_pet_species_id(owner, index)
    return 0
end

--- Returns the pet type (1-10) of a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return number pet_type Pet type ID.
function core.pet_battle.get_pet_type(owner, index)
    return 0
end

--- Returns the breed quality of a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return number quality Quality enum (0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary).
function core.pet_battle.get_breed_quality(owner, index)
    return 0
end

--- Returns the icon FileDataID of a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return number icon Icon FileDataID.
function core.pet_battle.get_icon(owner, index)
    return 0
end

--- Returns an arbitrary pet battle state value.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@param state_id integer The state ID to query.
---@return number value The state value.
function core.pet_battle.get_state_value(owner, index, state_id)
    return 0
end

--- Returns full ability details for a pet's ability slot in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@param ability_index integer The ability slot index (1-3).
---@return pet_battle_ability_info info A table containing the ability details.
function core.pet_battle.get_ability_info(owner, index, ability_index)
    return {}
end

--- Returns ability details looked up by ability ID.
---@param ability_id integer The ability ID.
---@return pet_battle_ability_info info A table containing the ability details.
function core.pet_battle.get_ability_info_by_id(ability_id)
    return {}
end

--- Returns the usability and cooldown state of an ability slot in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@param action_index integer The ability slot index (1-3).
---@return pet_battle_ability_state state A table with is_usable, current_cooldown, and current_lockdown.
function core.pet_battle.get_ability_state(owner, index, action_index)
    return {}
end

--- Returns the number of active auras on a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@return number count Number of active auras.
function core.pet_battle.get_num_auras(owner, index)
    return 0
end

--- Returns aura details for a specific aura on a pet in battle.
---@param owner integer The owner side (1 = Ally, 2 = Enemy).
---@param index integer The pet index (1-3).
---@param aura_index integer The aura index.
---@return pet_battle_aura_info info A table containing the aura details.
function core.pet_battle.get_aura_info(owner, index, aura_index)
    return {}
end

--- Returns whether the active pet can be swapped out.
---@return boolean can_swap True if the active pet can swap out.
function core.pet_battle.can_active_pet_swap_out()
    return false
end

--- Returns whether a pet at the given index can swap in.
---@param pet_index integer The pet index (1-3).
---@return boolean can_swap True if the pet can swap in.
function core.pet_battle.can_pet_swap_in(pet_index)
    return false
end

--- Returns whether the trap ability can be used.
---@return boolean available True if the trap is available.
function core.pet_battle.is_trap_available()
    return false
end

--- Returns whether skip turn is available.
---@return boolean available True if skip turn is available.
function core.pet_battle.is_skip_available()
    return false
end

--- Uses an ability in the given slot (1-3). Hardware-event restricted.
---@param action_index integer The ability slot index (1-3).
function core.pet_battle.use_ability(action_index) end

--- Switches to the pet at the given index (1-3).
---@param pet_index integer The pet index (1-3).
function core.pet_battle.change_pet(pet_index) end

--- Forfeits the current pet battle.
function core.pet_battle.forfeit_game() end

--- Skips your turn. Hardware-event restricted.
function core.pet_battle.skip_turn() end

--- Attempts to trap the enemy pet. Hardware-event restricted.
function core.pet_battle.use_trap() end

--- Returns the total and owned pet counts from the journal.
---@return pet_journal_count_info counts A table with num_pets and num_owned.
function core.pet_battle.get_num_pets_journal()
    return {}
end

--- Returns full pet info by journal index.
---@param index integer The journal index.
---@return pet_journal_index_info info A table containing the pet information.
function core.pet_battle.get_pet_info_by_index(index)
    return {}
end

--- Returns full pet info by pet GUID string.
---@param pet_id string The pet GUID.
---@return pet_journal_pet_id_info info A table containing the pet information.
function core.pet_battle.get_pet_info_by_pet_id(pet_id)
    return {}
end

--- Returns species-level info by species ID.
---@param species_id integer The BattlePetSpeciesID.
---@return pet_journal_species_info info A table containing the species information.
function core.pet_battle.get_pet_info_by_species_id(species_id)
    return {}
end

--- Returns combat stats for an owned pet.
---@param pet_id string The pet GUID.
---@return pet_journal_stats stats A table containing health, max_health, power, speed, and rarity.
function core.pet_battle.get_pet_stats(pet_id)
    return {}
end

--- Returns loadout slot info (1-3).
---@param slot_index integer The loadout slot index (1-3).
---@return pet_loadout_info info A table containing pet_guid, abilities, and locked state.
function core.pet_battle.get_pet_load_out_info(slot_index)
    return {}
end

--- Assigns a pet GUID to a loadout slot (1-3).
--- If the pet is already in a different slot, the two pets are swapped.
---@param slot_index integer The loadout slot index (1-3).
---@param pet_id string The pet GUID to assign.
function core.pet_battle.set_pet_load_out_info(slot_index, pet_id) end

--- Returns available abilities for a species.
---@param species_id integer The BattlePetSpeciesID.
---@return pet_ability_list_info info A table with ability_ids and level_thresholds arrays.
function core.pet_battle.get_pet_ability_list(species_id)
    return {}
end

--- Returns ability name, icon, and type for an ability ID.
---@param ability_id integer The ability ID.
---@return pet_ability_info info A table with name, icon, and type.
function core.pet_battle.get_pet_ability_info(ability_id)
    return {}
end

--- Sets an ability for a loadout slot and spell slot.
---@param slot_index integer The loadout slot index (1-3).
---@param spell_index integer The spell slot index (1-3).
---@param pet_spell_id integer The ability ID to assign.
function core.pet_battle.set_ability(slot_index, spell_index, pet_spell_id) end

--- Summons a companion pet by GUID. Passing an already-summoned pet's GUID dismisses it.
--- Cannot be used in combat.
---@param pet_id string The pet GUID to summon or dismiss.
function core.pet_battle.summon_pet_by_guid(pet_id) end

--- Returns whether the player has learned a specific toy.
---@param item_id integer The item ID of the toy.
---@return boolean has_toy True if the player has the toy.
function core.pet_battle.player_has_toy(item_id)
    return false
end

--- Uses a toy by item ID.
---@param item_id integer The item ID of the toy to use.
function core.pet_battle.use_toy(item_id) end

---@class delves
core.delves = {}

--- Returns whether a delve is currently in progress.
---@return boolean in_delve True if currently in a delve.
function core.delves.is_in_delve()
    return false
end

--- Returns whether the current delve has been completed.
---@return boolean is_complete True if the delve is complete.
function core.delves.is_delve_complete()
    return false
end

--- Clicks the enter delve button on the difficulty picker frame.
---@return boolean success True if the action was performed.
function core.delves.enter_delve()
    return false
end

--- Teleports the player out of the current delve.
---@return boolean success True if the action was performed.
function core.delves.teleport_out()
    return false
end

--- Smart leave: teleports out if in a delve, otherwise leaves the party.
---@return boolean success True if the action was performed.
function core.delves.leave_delve()
    return false
end

---@class addons
core.addons = {}

---@class zygor_goal_info
---@field action string The goal action type.
---@field quest_id integer The quest ID associated with this goal.
---@field npc_id integer The NPC ID associated with this goal.
---@field target_id integer The target ID associated with this goal.
---@field target string The target name.
---@field npc string The NPC name.
---@field is_complete boolean Whether this goal is complete.

---@class zygor_step_info
---@field num integer The step number.
---@field is_complete boolean Whether this step is complete.
---@field goals zygor_goal_info[] An array of goals for this step.

---@class addons_zygor
core.addons.zygor = {}

--- Returns whether the Zygor addon is loaded and available.
---@return boolean is_loaded True if Zygor is loaded.
function core.addons.zygor.is_loaded()
    return false
end

--- Returns whether Zygor has an active current step.
---@return boolean has_step True if a current step exists.
function core.addons.zygor.has_current_step()
    return false
end

--- Returns the current active step from Zygor.
---@return zygor_step_info step A table containing the step number, completion state, and goals.
function core.addons.zygor.get_current_step()
    return {}
end

--- Returns the current sticky steps from Zygor.
---@return zygor_step_info[] stickies An array of sticky step tables.
function core.addons.zygor.get_current_stickies()
    return {}
end

--- Returns the current Zygor objectives list.
--- Each entry can be a number or a string depending on the objective type.
---@return (number|string)[] objectives An array of objective values.
function core.addons.zygor.get_objectives()
    return {}
end

---@class zygor_waypoint_info
---@field map_id integer The map ID for the waypoint.
---@field x number The X coordinate on the map.
---@field y number The Y coordinate on the map.
---@field dist number The distance to the waypoint.
---@field title string The waypoint title.
---@field type string The waypoint type.
---@field goal_num integer The goal number.
---@field is_manual boolean Whether the waypoint was manually set.

--- Returns the current active Zygor waypoint.
---@return zygor_waypoint_info waypoint The current waypoint info.
function core.addons.zygor.get_current_waypoint()
    return {}
end

--- Returns all waypoints for the current Zygor step.
---@return zygor_waypoint_info[] waypoints An array of waypoint info tables.
function core.addons.zygor.get_step_waypoints()
    return {}
end

---@class bigwigs_bar_info
---@field key integer The bar key identifier.
---@field text string The bar display text.
---@field remaining number Time remaining in seconds.
---@field duration number Total duration in seconds.
---@field expire_time number The game time when the bar expires.
---@field is_emphasized boolean Whether the bar is emphasized (important).

---@class addons_bigwigs
core.addons.bigwigs = {}

--- Returns whether the BigWigs addon is loaded and available.
---@return boolean is_loaded True if BigWigs is loaded.
function core.addons.bigwigs.is_loaded()
    return false
end

--- Returns whether BigWigs has any active timer bars.
---@return boolean has_bars True if there are active bars.
function core.addons.bigwigs.has_active_bars()
    return false
end

--- Returns all active BigWigs timer bars.
---@return bigwigs_bar_info[] bars An array of bar info tables.
function core.addons.bigwigs.get_bars()
    return {}
end

---@class conroc_suggested_spell
---@field id integer The spell or item ID (always positive).
---@field is_item boolean Whether this entry is an item (true) or a spell (false).

---@class addons_conroc
core.addons.conroc = {}

--- Returns whether the Conroc addon is loaded and available.
---@return boolean is_loaded True if Conroc is loaded.
function core.addons.conroc.is_loaded()
    return false
end

--- Returns the list of suggested offensive spells/items from Conroc.
--- Each entry contains an id and whether it's an item or spell.
---@return conroc_suggested_spell[] spells An array of suggested spell tables.
function core.addons.conroc.get_suggested_spells()
    return {}
end

--- Returns the list of suggested defensive spell IDs from Conroc.
---@return integer[] spell_ids An array of defensive spell IDs.
function core.addons.conroc.get_suggested_utility_spells()
    return {}
end

---@class addons_questie
core.addons.questie = {}

--- Returns whether the Questie addon is loaded and available.
---@return boolean is_loaded True if Questie is loaded.
function core.addons.questie.is_loaded()
    return false
end

--- Returns the list of NPC IDs associated with active quests from Questie.
---@return integer[] npc_ids An array of quest-related NPC IDs.
function core.addons.questie.get_quest_npc_ids()
    return {}
end

---@class tsm_item_prices
---@field market_value number The current market value in copper.
---@field min_buyout number The minimum buyout price in copper.
---@field historical number The historical price in copper.
---@field region_market_avg number The region market average in copper.
---@field region_historical number The region historical price in copper.
---@field region_sale_avg number The region sale average in copper.
---@field region_sale_rate number The region sale rate (0.0-1.0).
---@field region_sold_per_day number The average number sold per day.
---@field vendor_sell number The vendor sell price in copper.

---@class tsm_auctioning_prices
---@field min_price number The minimum posting price in copper.
---@field normal_price number The normal posting price in copper.
---@field max_price number The maximum posting price in copper.

---@class addons_tsm
core.addons.tsm = {}

--- Returns whether the TSM API is available.
---@return boolean is_loaded True if TSM is loaded.
function core.addons.tsm.is_loaded()
    return false
end

--- Returns all price sources for an item.
---@param item_id integer The item ID.
---@return tsm_item_prices prices A table containing all price source values.
function core.addons.tsm.get_item_prices(item_id)
    return {}
end

--- Returns batch prices for multiple items, keyed by item ID.
---@param item_ids integer[] An array of item IDs to query.
---@return table<integer, tsm_item_prices> prices A table of prices keyed by item ID.
function core.addons.tsm.get_market_data(item_ids)
    return {}
end

--- Returns the sniper deal threshold for an item (buy if buyout <= this value).
---@param item_id integer The item ID.
---@return number max_price The sniper max price in copper.
function core.addons.tsm.get_sniper_max_price(item_id)
    return 0
end

--- Returns the shopping operation max price for an item.
---@param item_id integer The item ID.
---@return number max_price The shopping max price in copper.
function core.addons.tsm.get_shopping_max_price(item_id)
    return 0
end

--- Returns the auctioning posting price guidance for an item.
---@param item_id integer The item ID.
---@return tsm_auctioning_prices prices A table with min_price, normal_price, and max_price.
function core.addons.tsm.get_auctioning_prices(item_id)
    return {}
end

--- Returns how many more of an item to buy for restock.
---@param item_id integer The item ID.
---@return integer quantity The restock quantity needed.
function core.addons.tsm.get_shopping_restock_quantity(item_id)
    return 0
end

-- ========================================
-- core.addons.details
-- ========================================

---@class addons_details
core.addons.details = {}

--- Returns whether the Details addon is loaded.
---@return boolean is_loaded Whether Details is loaded.
function core.addons.details.is_loaded()
    return false
end

--- Returns combat information for a given segment.
---@class details_combat_info
---@field combat_time number The combat duration in seconds.
---@field combat_name string The combat/encounter name.
---@field total_damage number Total damage dealt in the segment.
---@field total_healing number Total healing done in the segment.

---@param segment_id? integer The segment ID (0=current, -1=overall, 1-25=specific). Default 0.
---@return details_combat_info info The combat information table.
function core.addons.details.get_combat_info(segment_id)
    return {}
end

--- Returns damage done data for a given segment.
---@class details_actor
---@field name string The actor name.
---@field class_id integer The class ID.
---@field total number The total amount.
---@field per_second number The per-second rate (DPS/HPS).
---@field is_player boolean Whether the actor is a player.
---@field is_group_member boolean Whether the actor is in the group.
---@field unit game_object|nil The game object if found in the world.

---@param segment_id? integer The segment ID (0=current, -1=overall, 1-25=specific). Default 0.
---@return details_actor[] actors Array of actor entries.
function core.addons.details.get_damage_done(segment_id)
    return {}
end

--- Returns healing done data for a given segment.
---@param segment_id? integer The segment ID (0=current, -1=overall, 1-25=specific). Default 0.
---@return details_actor[] actors Array of actor entries.
function core.addons.details.get_healing_done(segment_id)
    return {}
end

--- Returns damage taken data for a given segment.
---@param segment_id? integer The segment ID (0=current, -1=overall, 1-25=specific). Default 0.
---@return details_actor[] actors Array of actor entries.
function core.addons.details.get_damage_taken(segment_id)
    return {}
end

--- Returns all available combat segments.
---@class details_segment
---@field index integer The segment index.
---@field name string The segment name.
---@field duration number The segment duration in seconds.

---@return details_segment[] segments Array of segment entries.
function core.addons.details.get_segments()
    return {}
end

-- ========================================
-- core.addons.timeline_reminders
-- ========================================

---@class addons_timeline_reminders
core.addons.timeline_reminders = {}

--- Returns whether the Timeline Reminders addon is loaded.
---@return boolean is_loaded Whether Timeline Reminders is loaded.
function core.addons.timeline_reminders.is_loaded()
    return false
end

--- Returns reminders for a given encounter and difficulty.
---@class timeline_reminder
---@field trigger_time number The time in seconds when the reminder triggers.
---@field duration number The duration of the reminder in seconds.
---@field linger number The linger time after the reminder fires.
---@field hide_on_use boolean Whether to hide the reminder after it triggers.
---@field region string The display region.
---@field display_type string The display type.
---@field spell_id integer The associated spell ID.
---@field text string The reminder text.
---@field load_type string The load condition type.
---@field load_class string The class load condition.
---@field load_spec integer The specialization load condition.
---@field load_role string The role load condition.
---@field load_name string The name load condition.
---@field countdown_enabled boolean Whether the countdown is enabled.
---@field countdown_start integer The countdown start time in seconds.

---@param encounter_id integer The encounter ID.
---@param difficulty_id integer The difficulty ID.
---@return timeline_reminder[] reminders Array of reminder entries.
function core.addons.timeline_reminders.get_reminders(encounter_id, difficulty_id)
    return {}
end

-- ========================================
-- core.addons.maxdps
-- ========================================

---@class addons_maxdps
core.addons.maxdps = {}

--- Returns whether the MaxDps addon is loaded.
---@return boolean is_loaded Whether MaxDps is loaded.
function core.addons.maxdps.is_loaded()
    return false
end

--- Returns the next recommended spell ID from MaxDps.
---@return integer spell_id The next spell ID suggested by MaxDps.
function core.addons.maxdps.get_next_spell()
    return 0
end

-- ========================================
-- core.addons.swing_timer
-- ========================================

---@class addons_swing_timer
core.addons.swing_timer = {}

--- Returns whether the Swing Timer addon is loaded.
---@return boolean is_loaded Whether Swing Timer is loaded.
function core.addons.swing_timer.is_loaded()
    return false
end

--- Returns the player's ranged auto-shot swing timer information.
---@class swing_timer_ranged_info
---@field expiration_time number The time when the current auto-shot expires.
---@field last_swing number The time of the last ranged swing.
---@field auto_shot_cast_time number The cast time of the auto-shot.

---@return swing_timer_ranged_info info The ranged swing timer information.
function core.addons.swing_timer.get_player_ranged_info()
    return {}
end

-- ========================================
-- core.damage_meter
-- ========================================

---@class damage_meter
core.damage_meter = {}

--- Checks if the damage meter API is available.
---@return boolean is_available Whether the damage meter is available.
---@return string failure_reason The reason it is unavailable (empty string if available).
function core.damage_meter.is_available()
    return false, ""
end

--- Returns all available combat sessions.
---@class damage_meter_session_entry
---@field session_id integer The session identifier.
---@field name string The session name.
---@field duration number The session duration in seconds.

---@return damage_meter_session_entry[] sessions Array of available sessions.
function core.damage_meter.get_available_sessions()
    return {}
end

--- Returns a combat session by its ID and meter type.
---@class damage_meter_source
---@field name string The combatant name.
---@field class string The class filename.
---@field total_amount number The total amount dealt/healed.
---@field per_second number The amount per second.
---@field is_local_player boolean Whether this source is the local player.
---@field spec_icon integer The specialization icon ID.
---@field unit game_object|nil The game object if found, nil otherwise.

---@class damage_meter_session
---@field max_amount number The highest amount from a single source.
---@field total_amount number The total combined amount.
---@field duration number The session duration in seconds.
---@field sources damage_meter_source[] Array of combatant entries.

---@param session_id integer The session ID.
---@param meter_type integer The meter type (e.g. damage, healing).
---@return damage_meter_session session The session data.
function core.damage_meter.get_session_from_id(session_id, meter_type)
    return {}
end

--- Returns a combat session by session type and meter type.
--- Session types: 0 = Overall, 1 = Current, 2 = Expired.
---@param session_type integer The session type (0=Overall, 1=Current, 2=Expired).
---@param meter_type integer The meter type (e.g. damage, healing).
---@return damage_meter_session session The session data.
function core.damage_meter.get_session_from_type(session_type, meter_type)
    return {}
end

--- Returns the duration of a combat session by type.
---@param session_type integer The session type.
---@return number duration The session duration in seconds.
function core.damage_meter.get_session_duration(session_type)
    return 0
end

--- Resets all combat sessions.
---@return nil
function core.damage_meter.reset_all()
    return nil
end

-- ========================================
-- core.lfg_list
-- ========================================

---@class lfg_list
core.lfg_list = {}

--- Triggers a Looking For Group search. Results arrive via the LFG_LIST_SEARCH_RESULT_UPDATED event.
--- Skips the search if the Blizzard LFG or PVE frame is currently shown.
---@param category_id integer The LFG category ID to search.
---@param filter? integer Optional search filter bitmask. Default 0.
---@param preferred_filters? integer Optional preferred filter bitmask. Default 0.
---@return boolean issued True if the search was issued, false if it was skipped.
function core.lfg_list.search(category_id, filter, preferred_filters)
    return false
end

--- Returns the current LFG search results.
---@class lfg_search_results
---@field total_results integer The total number of results.
---@field result_ids number[] Array of search result IDs.

---@return lfg_search_results results The search results.
function core.lfg_list.get_search_results()
    return {}
end

--- Checks whether detailed info is available for a search result.
---@param result_id number The search result ID.
---@return boolean has_info True if info is available.
function core.lfg_list.has_search_result_info(result_id)
    return false
end

--- Returns detailed information about a search result.
---@class lfg_search_result_info
---@field search_result_id number The search result ID.
---@field activity_id integer The activity ID.
---@field leader_name string The group leader's name.
---@field name string The group listing name.
---@field comment string The group listing comment.
---@field voice_chat string The voice chat info string.
---@field required_ilvl integer The required item level.
---@field age integer The listing age in seconds.
---@field num_bnet_friends integer Number of Battle.net friends in the group.
---@field num_char_friends integer Number of character friends in the group.
---@field num_guildmates integer Number of guildmates in the group.
---@field is_delisted boolean Whether the listing has been delisted.
---@field num_members integer The number of members in the group.
---@field is_auto_accept boolean Whether the group auto-accepts applicants.
---@field required_honor_level integer The required honor level.

---@param result_id number The search result ID.
---@return lfg_search_result_info|nil info The result info table, or nil if unavailable.
function core.lfg_list.get_search_result_info(result_id)
    return {}
end

--- Applies to a group listing with the specified roles.
--- The actual outcome arrives via LFG_LIST_APPLICATION_STATUS_UPDATED.
---@param result_id number The search result ID to apply to.
---@param tank boolean Whether to apply as tank.
---@param healer boolean Whether to apply as healer.
---@param damage boolean Whether to apply as damage.
---@return boolean success True if the apply call was issued without error.
---@return string|nil error The error message if the call failed, nil on success.
function core.lfg_list.apply_to_group(result_id, tank, healer, damage)
    return false, nil
end

--- Returns the list of applicant IDs for a group you are hosting.
---@return integer[] applicant_ids Array of applicant IDs.
function core.lfg_list.get_applicants()
    return {}
end

--- Returns detailed information about an applicant.
---@class lfg_applicant_info
---@field applicant_id number The applicant ID.
---@field application_status string The current application status.
---@field pending_application_status string The pending application status.
---@field num_members integer The number of members in the applicant's group.
---@field is_new boolean Whether the applicant is new.
---@field comment string The applicant's comment.
---@field display_order_id integer The display order ID.

---@param applicant_id number The applicant ID.
---@return lfg_applicant_info|nil info The applicant info table, or nil if unavailable.
function core.lfg_list.get_applicant_info(applicant_id)
    return {}
end

--- Cancels a pending application to a group.
---@param result_id number The search result ID of the group to cancel the application for.
---@return boolean success True if the cancel call was issued without error.
---@return string|nil error The error message if the call failed, nil on success.
function core.lfg_list.cancel_application(result_id)
    return false, nil
end

--- Accepts a group invite.
---@param result_id number The search result ID of the group invite to accept.
---@return boolean success True if the accept call was issued without error.
---@return string|nil error The error message if the call failed, nil on success.
function core.lfg_list.accept_invite(result_id)
    return false, nil
end

--- Returns application info for a search result.
---@class lfg_application_info
---@field app_id number The application ID.
---@field app_status string The current application status ("none", "applied", "invited", "failed", "cancelled", "declined", "declined_full", "declined_delisted", "timedout", "inviteaccepted", "invitedeclined").
---@field pending_status string The pending application status.
---@field app_duration number The application duration in seconds.

---@param result_id number The search result ID.
---@return lfg_application_info|nil info The application info table, or nil if unavailable.
function core.lfg_list.get_application_info(result_id)
    return {}
end

--- Programmatically clicks the refresh button on the Blizzard LFG search panel.
---@return boolean success True if the click was issued without error.
---@return string|nil error The error message if the call failed, nil on success.
function core.lfg_list.refresh_search_panel()
    return false, nil
end

--- Returns whether the Blizzard LFG search panel is currently visible.
---@return boolean is_visible True if the search panel is visible.
function core.lfg_list.search_panel_is_visible()
    return false
end

