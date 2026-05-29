-- ============================================================================
-- Shared Helper: HUD Overlay
-- Draggable tile overlay with clickable state indicators
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations
local _core_time = core.time
local sdf = require("shared/sdf_render_sylvanas")

-- ============================================================================
-- Internal state
-- ============================================================================

local _hud = {
    visible = true,
    drag_offset = { x = 0, y = 0 },
    position = { x = 10, y = 200 },
    dragging = false,
    drag_start = { x = 0, y = 0 },
    tiles = {},           -- Registered tiles
    width = 0,
    height = 0,
}

-- ============================================================================
-- Tile definition
-- ============================================================================

---@class hud_tile
---@field id string Unique identifier
---@field label string Display label
---@field value string|number Current value
---@field color table RGBA color
---@field bg_color table BG color
---@field hover_color table Hover color
---@field clickable boolean Whether clicking does something
---@field on_click function Called on click
---@field width number Tile width
---@field height number Tile height

-- ============================================================================
-- Drawing helpers (call from on_render)
-- ============================================================================

local TILE_WIDTH = 80
local TILE_HEIGHT = 28
local TILE_GAP = 4
local PADDING = 6

--- Registers a tile for display
---@param tile hud_tile
function M.register_tile(tile)
    if not tile or not tile.id then return end
    _hud.tiles[tile.id] = tile
end

--- Removes a tile by ID
---@param id string Tile ID
function M.unregister_tile(id)
    _hud.tiles[id] = nil
end

--- Sets a tile's value and color
---@param id string Tile ID
---@param value string|number New value
---@param color table|nil Optional RGBA color override
---@param bg_color table|nil Optional BG color override
function M.update_tile(id, value, color, bg_color)
    local tile = _hud.tiles[id]
    if not tile then return end
    tile.value = value
    if color then tile.color = color end
    if bg_color then tile.bg_color = bg_color end
end

--- Sets the HUD position
---@param x number Screen X
---@param y number Screen Y
function M.set_position(x, y)
    _hud.position.x = x
    _hud.position.y = y
end

--- Shows or hides the HUD
---@param visible boolean
function M.set_visible(visible)
    _hud.visible = visible
end

--- Toggles HUD visibility
function M.toggle_visibility()
    _hud.visible = not _hud.visible
end

-- ============================================================================
-- Main render function (call from on_render callback)
-- ============================================================================

local TITLE_HEIGHT = 18
local TITLE_WIDTH_CALC = 80

--- Renders the HUD overlay
---@param ctx table|nil Combat context (for theme colors)
function M.render(ctx)
    if not _hud.visible then return end

    -- Count registered tiles
    local tile_count = 0
    for _ in pairs(_hud.tiles) do
        tile_count = tile_count + 1
    end
    if tile_count == 0 then return end

    local x = _hud.position.x
    local y = _hud.position.y

    -- Title bar dimensions
    local title_w = TILE_WIDTH + PADDING * 2
    local title_h = TITLE_HEIGHT

    -- Layout tiles in a single row
    local total_w = tile_count * (TILE_WIDTH + TILE_GAP) - TILE_GAP + PADDING * 2
    local total_h = TITLE_HEIGHT + TILE_HEIGHT + PADDING * 3 + 2

    -- Drop shadow behind the entire HUD panel
    sdf.drop_shadow(x - 2, y - 2, total_w + 4, total_h + 4, { 0, 0, 0, 120 }, 2, 2, 8, 12, 2)

    -- Draw background panel with SDF smooth rect
    sdf.smooth_rect(x, y, total_w, total_h, { 0, 0, 0, 180 }, 6, 1)

    -- Draw title bar with SDF gradient (dark to slightly lighter)
    sdf.linear_gradient(x, y, total_w, title_h, { 20, 20, 30, 220 }, { 40, 40, 55, 220 }, 0, 0, 0)

    -- Draw title text
    sdf.text("EAX Rotations", x + PADDING, y + 3, 12, { 200, 200, 200, 255 })

    -- Track mouse for dragging via cursor position API
    local mx, my
    local cursor_pos = core.get_cursor_position and core.get_cursor_position()
    if cursor_pos and cursor_pos.x then
        mx, my = cursor_pos.x, cursor_pos.y
    end

    -- Title bar drag handle
    if mx and my then
        local in_title = mx >= x and mx <= x + total_w and my >= y and my <= y + title_h

        -- Mouse down detection via key press (VK_LBUTTON = 1)
        local mouse_down = core.input.is_key_pressed and core.input.is_key_pressed(1)
        if mouse_down and in_title then
            _hud.dragging = true
            _hud.drag_start.x = mx
            _hud.drag_start.y = my
        end

        -- Dragging
        if _hud.dragging and mx and my then
            _hud.position.x = _hud.position.x + (mx - _hud.drag_start.x)
            _hud.position.y = _hud.position.y + (my - _hud.drag_start.y)
            _hud.drag_start.x = mx
            _hud.drag_start.y = my

            -- Mouse up detection
            if not mouse_down then
                _hud.dragging = false
            end
        end
    end

    -- Render tiles
    local tile_x = x + PADDING
    local tile_y = y + title_h + 3
    local now = _core_time()
    local mouse_over_id = nil

    for id, tile in pairs(_hud.tiles) do
        local tcol = tile.bg_color or { 40, 40, 50, 200 }

        -- Check hover
        local hovered = false
        if mx and my then
            if mx >= tile_x and mx <= tile_x + TILE_WIDTH
                and my >= tile_y and my <= tile_y + TILE_HEIGHT then
                hovered = true
                mouse_over_id = id
            end
        end

        -- Draw tile background with SDF smooth rect
        if hovered then
            sdf.hover_pill(tile_x, tile_y, TILE_WIDTH, TILE_HEIGHT, tcol, { 108, 99, 255, 60 }, _core_time(), 6, 1, 1, 1)
        else
            sdf.smooth_rect(tile_x, tile_y, TILE_WIDTH, TILE_HEIGHT, tcol, 6, 1)
        end

        -- Draw label (top line)
        sdf.text(tile.label or id, tile_x + 3, tile_y + 2, 10, { 160, 160, 170, 220 })

        -- Draw value (bottom line)
        local val_color = tile.color or { 255, 255, 255, 255 }
        sdf.text(tostring(tile.value or ""), tile_x + 3, tile_y + 13, 10, val_color)

        tile_x = tile_x + TILE_WIDTH + TILE_GAP
    end

    -- Handle clicks on tiles (simple hover-click via key state change)
    if mouse_over_id and _hud.tiles[mouse_over_id].clickable then
        local mouse_just_pressed = not _hud._last_mouse_down and (core.input.is_key_pressed and core.input.is_key_pressed(1))
        _hud._last_mouse_down = core.input.is_key_pressed and core.input.is_key_pressed(1)
        if mouse_just_pressed then
            local tile = _hud.tiles[mouse_over_id]
            if tile.on_click then
                pcall(tile.on_click)
            end
        end
    end
end

-- ============================================================================
-- Helper: build standard tiles for a spec
-- ============================================================================

--- Creates standard control tiles for a combat rotation spec
---@param opts table Options with keys:
---   prefix - string namespace prefix for IDs (e.g. \"hunter\")
---   rotation_enabled - boolean function to check
---   cooldowns_enabled - boolean function to check
---   interrupts_enabled - boolean function to check
---   combat_mode - string function to get mode label
---   extra - table of additional tile configs
function M.register_standard_tiles(opts)
    if not opts or not opts.prefix then return end

    local p = opts.prefix

    -- Script toggle
    M.register_tile({
        id = p .. "_toggle",
        label = "Script",
        value = opts.rotation_enabled and "ON" or "OFF",
        color = opts.rotation_enabled and { 100, 255, 100, 255 } or { 255, 100, 100, 255 },
        bg_color = { 40, 50, 40, 200 },
        clickable = true,
        on_click = opts.on_toggle or nil,
    })

    -- Cooldowns
    if opts.cooldowns_enabled ~= nil then
        M.register_tile({
            id = p .. "_cds",
            label = "Cooldowns",
            value = opts.cooldowns_enabled and "ON" or "OFF",
            color = opts.cooldowns_enabled and { 100, 255, 100, 255 } or { 255, 100, 100, 255 },
            bg_color = { 40, 40, 50, 200 },
            clickable = true,
            on_click = opts.on_cooldowns_toggle or nil,
        })
    end

    -- Interrupts
    if opts.interrupts_enabled ~= nil then
        M.register_tile({
            id = p .. "_interrupt",
            label = "Interrupt",
            value = opts.interrupts_enabled and "ON" or "OFF",
            color = opts.interrupts_enabled and { 100, 255, 100, 255 } or { 255, 100, 100, 255 },
            bg_color = { 40, 40, 50, 200 },
            clickable = true,
            on_click = opts.on_interrupt_toggle or nil,
        })
    end

    -- Combat mode
    if opts.combat_mode then
        M.register_tile({
            id = p .. "_mode",
            label = "Mode",
            value = opts.combat_mode or "Auto",
            color = { 200, 200, 100, 255 },
            bg_color = { 40, 40, 50, 200 },
            clickable = true,
            on_click = opts.on_mode_cycle or nil,
        })
    end

    -- Extra tiles
    if opts.extra then
        for _, tile in ipairs(opts.extra) do
            M.register_tile(tile)
        end
    end
end

--- Updates all standard tiles for a spec
---@param opts table Same structure as register_standard_tiles, with current values
function M.update_standard_tiles(opts)
    local p = opts.prefix
    M.update_tile(p .. "_toggle",
        opts.rotation_enabled and "ON" or "OFF",
        opts.rotation_enabled and { 100, 255, 100, 255 } or { 255, 100, 100, 255 })
    if opts.cooldowns_enabled ~= nil then
        M.update_tile(p .. "_cds",
            opts.cooldowns_enabled and "ON" or "OFF",
            opts.cooldowns_enabled and { 100, 255, 100, 255 } or { 255, 100, 100, 255 })
    end
    if opts.interrupts_enabled ~= nil then
        M.update_tile(p .. "_interrupt",
            opts.interrupts_enabled and "ON" or "OFF",
            opts.interrupts_enabled and { 100, 255, 100, 255 } or { 255, 100, 100, 255 })
    end
    if opts.combat_mode then
        M.update_tile(p .. "_mode", opts.combat_mode, { 200, 200, 100, 255 })
    end
end

-- ============================================================================
-- Export
-- ============================================================================

NS.HUD = M

return M
