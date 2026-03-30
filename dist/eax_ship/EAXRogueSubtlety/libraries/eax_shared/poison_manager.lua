local poison_manager = {}

local MAIN_HAND_SLOT = 16
local OFF_HAND_SLOT = 17
local APPLY_THROTTLE_S = 5.0
local STATUS_LOG_INTERVAL_S = 15.0
-- TBC poisons last 30 minutes, but there is no WoW API in this environment to
-- query the actual remaining poison duration on the weapon. We therefore track
-- an assumed duration and refresh a bit early with a safety margin.
local POISON_REAL_DURATION_S = 1800.0
local POISON_SAFETY_MARGIN_S = 100.0
local ASSUMED_POISON_DURATION_S = POISON_REAL_DURATION_S - POISON_SAFETY_MARGIN_S

local last_apply_attempt_at = 0
local last_status_log_at = 0
local last_status_summary = nil
local applied_state = {
    [MAIN_HAND_SLOT] = { weapon_item_id = nil, poison_item_id = nil, expires_at = 0 },
    [OFF_HAND_SLOT] = { weapon_item_id = nil, poison_item_id = nil, expires_at = 0 },
}

local function get_slot_item(me, slot_id)
    if not me or not me.is_valid or not me:is_valid() then return nil end
    local ok, slot_info = pcall(function() return me:get_item_at_inventory_slot(slot_id) end)
    if not ok or not slot_info or not slot_info.object then return nil end
    local item = slot_info.object
    if not item or not item.is_valid or not item:is_valid() then return nil end
    return item
end

local function item_has_temporary_enchant(item)
    if not item then return false end
    if type(item.item_has_enchant) == "function" then local ok, v = pcall(item.item_has_enchant, item); if ok and v then return true end elseif type(item.item_has_enchant) == "boolean" then return item.item_has_enchant end
    if type(item.item_enchant_id) == "function" then local ok, v = pcall(item.item_enchant_id, item); if ok and type(v) == "number" and v > 0 then return true end end
    if type(item.item_enchant_expiration) == "function" then local ok, v = pcall(item.item_enchant_expiration, item); if ok and type(v) == "number" and v > 0 then return true end end
    return false
end

local function slot_has_temporary_enchant(me, slot_id)
    if type(GetWeaponEnchantInfo) == "function" then
        local mh_has, _, _, _, oh_has = GetWeaponEnchantInfo()
        if slot_id == MAIN_HAND_SLOT then return mh_has == true end
        if slot_id == OFF_HAND_SLOT then return oh_has == true end
    end
    local weapon = get_slot_item(me, slot_id)
    if weapon and item_has_temporary_enchant(weapon) then return true end
    if type(me.get_equipped_items) == "function" then
        local ok, items = pcall(me.get_equipped_items, me)
        if ok and items then
            for _, value in pairs(items) do
                if value and value.slot_id == slot_id and value.object and item_has_temporary_enchant(value.object) then return true end
            end
        end
    end
    return false
end

local function find_poison_item_id(me, item_ids)
    if not me or not item_ids then return nil end
    local wanted = {}
    for _, item_id in ipairs(item_ids) do wanted[item_id] = true end
    if core.inventory and core.inventory.get_items_in_bag then
        for bag_id = 0, 4 do
            local ok, items = pcall(core.inventory.get_items_in_bag, bag_id)
            if ok and items then
                for _, item in ipairs(items) do
                    if item and item.is_valid and item:is_valid() and type(item.get_item_id) == "function" then
                        local ok_id, item_id = pcall(item.get_item_id, item)
                        if ok_id and item_id and wanted[item_id] then return item_id end
                    end
                end
            end
        end
    end
    for _, item_id in ipairs(item_ids) do if me:has_item(item_id) then return item_id end end
    return nil
end

local function get_item_id(item)
    if not item or type(item.get_item_id) ~= "function" then return nil end
    local ok, item_id = pcall(item.get_item_id, item)
    return ok and item_id or nil
end

local function has_assumed_poison(slot_id, weapon_item_id, poison_item_id, now)
    local state = applied_state[slot_id]
    return state and state.expires_at > now and state.weapon_item_id == weapon_item_id and state.poison_item_id == poison_item_id
end

local function set_assumed_poison(slot_id, weapon_item_id, poison_item_id, now)
    local state = applied_state[slot_id]
    if not state then return end
    state.weapon_item_id = weapon_item_id
    state.poison_item_id = poison_item_id
    state.expires_at = now + ASSUMED_POISON_DURATION_S
end

local function slot_status(me, slot_id, item_ids, now)
    local weapon = get_slot_item(me, slot_id)
    if not weapon then return "no-weapon", nil, nil end
    local weapon_item_id = get_item_id(weapon)
    local poison_item_id = find_poison_item_id(me, item_ids)
    if slot_has_temporary_enchant(me, slot_id) then return "live", weapon_item_id, poison_item_id end
    if has_assumed_poison(slot_id, weapon_item_id, poison_item_id, now) then return "assumed", weapon_item_id, poison_item_id end
    if poison_item_id then return "ready", weapon_item_id, poison_item_id end
    return "missing", weapon_item_id, poison_item_id
end

local function log_compact_status(me, loadout, now)
    local mh_state, mh_weapon, mh_poison = slot_status(me, MAIN_HAND_SLOT, loadout and loadout.main_hand_items or nil, now)
    local oh_state, oh_weapon, oh_poison = slot_status(me, OFF_HAND_SLOT, loadout and loadout.off_hand_items or nil, now)
    local summary = string.format("slot=%d state=%s weapon=%s poison=%s | slot=%d state=%s weapon=%s poison=%s", MAIN_HAND_SLOT, mh_state, tostring(mh_weapon), tostring(mh_poison), OFF_HAND_SLOT, oh_state, tostring(oh_weapon), tostring(oh_poison))
    if summary ~= last_status_summary or (now - last_status_log_at) >= STATUS_LOG_INTERVAL_S then
        core.log("[Eax Rogue Poison] " .. summary)
        last_status_summary = summary
        last_status_log_at = now
    end
end

function poison_manager.force_reapply()
    last_apply_attempt_at = 0
    last_status_summary = nil
    last_status_log_at = 0
    for _, state in pairs(applied_state) do state.weapon_item_id = nil; state.poison_item_id = nil; state.expires_at = 0 end
end

local function try_apply_to_slot(me, item_ids, slot_id, now)
    local weapon = get_slot_item(me, slot_id)
    if not weapon then return false end
    local poison_item_id = find_poison_item_id(me, item_ids)
    local weapon_item_id = get_item_id(weapon)
    if slot_has_temporary_enchant(me, slot_id) then return false end
    if has_assumed_poison(slot_id, weapon_item_id, poison_item_id, now) then return false end
    if not poison_item_id then return false end
    if core.input and type(core.input.use_item_target) == "function" then
        local ok, applied = pcall(core.input.use_item_target, poison_item_id, weapon)
        if ok and applied then
            set_assumed_poison(slot_id, weapon_item_id, poison_item_id, now)
            last_status_summary = nil
            last_status_log_at = 0
            return true
        end
    end
    return false
end

function poison_manager.try_apply_poisons(me, menu, utils, loadout)
    if not menu or not menu.auto_apply_poisons or not menu.auto_apply_poisons:get_state() then return false end
    if not me or not me.is_valid or not me:is_valid() or me:is_dead() then return false end
    if me:is_in_combat() or me:is_moving() or me:is_mounted() then return false end
    if me:is_casting_spell() or me:is_channelling_spell() then return false end
    if not loadout then return false end
    local now = core.time()
    if (now - last_apply_attempt_at) < APPLY_THROTTLE_S then return false end
    last_apply_attempt_at = now
    log_compact_status(me, loadout, now)
    if try_apply_to_slot(me, loadout.main_hand_items, MAIN_HAND_SLOT, now) then if utils and utils.log_debug then utils.log_debug(menu, "Applied main-hand poison") end return true end
    if try_apply_to_slot(me, loadout.off_hand_items, OFF_HAND_SLOT, now) then if utils and utils.log_debug then utils.log_debug(menu, "Applied off-hand poison") end return true end
    return false
end

return poison_manager
