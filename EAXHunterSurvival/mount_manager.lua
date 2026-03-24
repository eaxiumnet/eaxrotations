-- mount_manager.lua
-- Shared mount state transitions for combat and travel.

local mount_manager = {}

local last_mount_attempt_at = 0

local function now_seconds()
    if core and core.time then
        return core.time()
    end
    return 0
end

local function should_auto_mount(menu)
    if not menu then return true end
    if menu.auto_mount and menu.auto_mount.get_state then
        return menu.auto_mount:get_state()
    end
    if menu.use_auto_mount and menu.use_auto_mount.get_state then
        return menu.use_auto_mount:get_state()
    end
    return true
end

local function try_use_configured_mount(me, menu)
    if not me then return false end

    local mount_item_id = menu and menu.mount_item_id and menu.mount_item_id.get and menu.mount_item_id:get() or nil
    if mount_item_id and mount_item_id > 0
        and me:has_item(mount_item_id)
        and me:get_item_cooldown(mount_item_id) <= 0
        and core and core.input and core.input.use_item
    then
        return core.input.use_item(mount_item_id)
    end

    local mount_spell_id = menu and menu.mount_spell_id and menu.mount_spell_id.get and menu.mount_spell_id:get() or nil
    if mount_spell_id and mount_spell_id > 0
        and core and core.spell_book and core.spell_book.is_spell_learned
        and core.spell_book.is_spell_learned(mount_spell_id)
        and core.spell_book.cast_spell
    then
        return core.spell_book.cast_spell(mount_spell_id)
    end

    if core and core.spell_book and core.spell_book.get_mount_count and core.spell_book.get_mount_info and core.input and core.input.mount then
        local count = core.spell_book.get_mount_count()
        for mount_index = 1, count do
            local info = core.spell_book.get_mount_info(mount_index)
            if info and info.is_usable then
                return core.input.mount(mount_index)
            end
        end
    end

    return false
end

function mount_manager.update_mount_state(me, menu, utils)
    if not me or not me.is_valid or not me:is_valid() then return false end

    -- Combat branch: always dismount when combat starts.
    if me:is_in_combat() and me:is_mounted() then
        if core and core.input and core.input.dismount then
            local dismounted = core.input.dismount()
            if dismounted and utils and utils.log_debug then
                utils.log_debug(menu, "Mount: dismounted due to combat")
            end
            return dismounted and true or false
        end
        return false
    end

    -- Out-of-combat branch: mount only when stationary and auto-mount is enabled.
    if (not me:is_in_combat()) and (not me:is_mounted()) and (not me:is_moving()) and should_auto_mount(menu) then
        if (now_seconds() - last_mount_attempt_at) < 2.0 then
            return false
        end

        last_mount_attempt_at = now_seconds()
        local mounted = try_use_configured_mount(me, menu)
        if mounted and utils and utils.log_debug then
            utils.log_debug(menu, "Mount: attempting auto-mount")
        end
        return mounted and true or false
    end

    return false
end

return mount_manager
