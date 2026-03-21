-- ooc_manager.lua
-- eax_shared/ooc_manager.lua
-- Out-of-combat utility system for all EAX specs.

local buff_manager = require("common/modules/buff_manager")

local ooc_manager = {}

local last_drink_attempt    = 0
local last_eat_attempt      = 0
local last_rez_attempt      = {}
local last_group_buff       = {}

local DRINK_BUFF_IDS = { 430, 2639, 1133, 10250, 22734, 27089, 29007, 46755 }
local EAT_BUFF_IDS   = { 433, 787,  1131, 5004,  5005,  7737,  18191, 35270 }

local function has_any_buff(unit, ids)
    if not unit or not unit:is_valid() or not ids then return false end
    local data = buff_manager:get_buff_data(unit, ids)
    if data and data.is_active then return true end
    data = buff_manager:get_aura_data(unit, ids)
    return data ~= nil and data.is_active
end

local function find_consumable_of_type(me, want_drink, want_food)
    if not core.inventory then return nil end
    for bag = 0, 4 do
        local ok, items = pcall(function() return core.inventory.get_items_in_bag(bag) end)
        if ok and items then
            for _, item in ipairs(items) do
                if item and item.is_valid and item:is_valid() then
                    local ok2, id = pcall(function() return item:get_item_id() end)
                    if ok2 and id and id > 0 then
                        local cd = me:get_item_cooldown(id)
                        if cd <= 0 then return id end
                    end
                end
            end
        end
    end
    local fallback_drinks = { 33445, 27860, 22018, 8766, 8428, 4605, 1708, 1205, 1179, 159 }
    local fallback_foods   = { 33052, 27854, 20452, 13928, 4457, 4456, 4455, 422, 4540 }
    local list = want_drink and fallback_drinks or fallback_foods
    for _, id in ipairs(list) do
        if me:has_item(id) then
            local cd = me:get_item_cooldown(id)
            if cd <= 0 then return id end
        end
    end
    return nil
end

function ooc_manager.try_drink(me, menu, utils)
    if not menu.ooc_drink or not menu.ooc_drink:get_state() then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    if has_any_buff(me, DRINK_BUFF_IDS) then return false end
    if has_any_buff(me, EAT_BUFF_IDS) then return false end

    local threshold = menu.drink_threshold and (menu.drink_threshold:get() / 100.0) or 0.80
    local _max_mana = me:get_max_power(0)
    local mana_pct = (_max_mana and _max_mana > 0) and (me:get_power(0) / _max_mana) or 1.0
    if mana_pct >= threshold then return false end

    local now = core.time()
    if (now - last_drink_attempt) < 3.0 then return false end
    last_drink_attempt = now

    local inv_ok, inv = pcall(require, "common/utility/inventory_helper")
    if inv_ok and inv and inv.update_consumables_list then
        inv:update_consumables_list()
        local consumables = inv:get_current_consumables_list()
        if consumables then
            for _, c in ipairs(consumables) do
                if c.is_food_or_drink and c.item then
                    local id = (c.item.get_item_id) and c.item:get_item_id()
                    if id and id > 0 and me:get_item_cooldown(id) <= 0 then
                        if core.input.use_item(id) then
                            utils.log_debug(menu, "OOC: Drinking")
                            return true
                        end
                    end
                end
            end
        end
    end

    local item_id = find_consumable_of_type(me, true, false)
    if item_id and core.input.use_item(item_id) then
        utils.log_debug(menu, "OOC: Drinking (bag scan)")
        return true
    end
    return false
end

function ooc_manager.try_eat(me, menu, utils)
    if not menu.ooc_eat or not menu.ooc_eat:get_state() then return false end
    if me:is_in_combat() then return false end
    if me:is_moving() then return false end
    if has_any_buff(me, EAT_BUFF_IDS) then return false end
    if has_any_buff(me, DRINK_BUFF_IDS) then return false end

    local threshold = menu.eat_threshold and (menu.eat_threshold:get() / 100.0) or 0.80
    local hp_pct    = utils.get_health_pct(me)
    if hp_pct >= threshold then return false end

    local now = core.time()
    if (now - last_eat_attempt) < 3.0 then return false end
    last_eat_attempt = now

    local item_id = find_consumable_of_type(me, false, true)
    if item_id and core.input.use_item(item_id) then
        utils.log_debug(menu, "OOC: Eating")
        return true
    end
    return false
end

local function get_rez_targets(me, in_combat)
    local targets = {}
    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and obj:is_player()
           and obj:is_party_member()
           and not obj:is_ghost() and obj:is_dead()
        then
            table.insert(targets, obj)
        end
    end
    table.sort(targets, function(a, b)
        local ra = a.get_group_role and a:get_group_role() or 0
        local rb = b.get_group_role and b:get_group_role() or 0
        return ra > rb
    end)
    return targets
end

function ooc_manager.try_resurrect(me, rez_spell_id, menu, utils, allow_in_combat)
    if not menu.ooc_rez or not menu.ooc_rez:get_state() then return false end
    if not rez_spell_id then return false end
    if me:is_in_combat() and not allow_in_combat then return false end
    if me:is_moving() then return false end
    if me:is_casting_spell() then return false end

    local targets = get_rez_targets(me, me:is_in_combat())
    for _, target in ipairs(targets) do
        local guid = tostring(target:get_guid())
        local now  = core.time()
        if (now - (last_rez_attempt[guid] or 0)) < 10.0 then goto continue end
        if not utils.can_cast_target(rez_spell_id, me, target) then goto continue end
        if utils.cast_target(rez_spell_id, target, "Resurrect") then
            last_rez_attempt[guid] = now
            utils.log_debug(menu, "OOC: Resurrecting party member")
            return true
        end
        ::continue::
    end
    return false
end

local _last_group_buff_scan = 0
local GROUP_BUFF_SCAN_INTERVAL = 5.0
local GROUP_BUFF_RECAST_DELAY  = 1500.0

function ooc_manager.try_group_buff(me, spell_id, buff_ids, buff_name, menu_toggle, menu, utils)
    if not menu_toggle or not menu_toggle:get_state() then return false end
    if not spell_id then return false end
    if me:is_in_combat() then return false end
    local ok_cast, is_casting = pcall(function() return me:is_casting_spell() end)
    if ok_cast and is_casting then return false end
    local ok_chan, is_chan = pcall(function() return me:is_channelling_spell() end)
    if ok_chan and is_chan then return false end

    local now = core.time()
    if (now - _last_group_buff_scan) < GROUP_BUFF_SCAN_INTERVAL then return false end
    if (now - (last_group_buff[spell_id] or 0)) < GROUP_BUFF_RECAST_DELAY then return false end

    if has_any_buff(me, buff_ids) then
        if (last_group_buff[spell_id] or 0) == 0 then
            last_group_buff[spell_id] = now
        end
    else
        if utils.can_cast_self(spell_id, me) then
            if utils.cast_self(spell_id, me) then
                last_group_buff[spell_id] = now
                _last_group_buff_scan = now
                utils.log_debug(menu, "OOC: Buffing self - " .. (buff_name or ""))
                return true
            end
        end
    end

    local objects = core.object_manager.get_all_objects()
    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj:is_valid() and obj:is_unit() and obj:is_player()
           and obj:is_party_member() and not obj:is_dead()
        then
            if not has_any_buff(obj, buff_ids) then
                if utils.can_cast_target(spell_id, me, obj) then
                    if utils.cast_target(spell_id, obj, buff_name or "Group Buff") then
                        last_group_buff[spell_id] = now
                        _last_group_buff_scan = now
                        utils.log_debug(menu, "OOC: Buffing party - " .. (buff_name or ""))
                        return true
                    end
                end
            end
        end
    end

    _last_group_buff_scan = now
    return false
end

function ooc_manager.on_update(me, menu, utils, opts)
    if not me or not me:is_valid() or me:is_dead() then return end
    opts = opts or {}

    ooc_manager.try_drink(me, menu, utils)
    ooc_manager.try_eat(me, menu, utils)

    if opts.rez_spell_id then
        ooc_manager.try_resurrect(me, opts.rez_spell_id, menu, utils, opts.rez_in_combat)
    end

    if opts.group_buffs then
        for _, buff in ipairs(opts.group_buffs) do
            if ooc_manager.try_group_buff(
                me, buff.spell_id, buff.buff_ids,
                buff.name, buff.toggle, menu, utils
            ) then
                return
            end
        end
    end
end

return ooc_manager
