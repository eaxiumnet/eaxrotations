-- totem_manager.lua
-- Shaman totem item scanning and cast gating.

local totem_manager = {}

local TOTEM_ITEM_IDS = {
    earth = 5175,
    fire = 5176,
    water = 5177,
    air = 5178,
}

local cache = {
    last_scan_at = 0,
    scan_interval_s = 2.0,
    bag_items = {},
    last_warn_at = {},
    warn_interval_s = 8.0,
}

local function scan_bags()
    local now = core.time()
    if (now - cache.last_scan_at) < cache.scan_interval_s then
        return
    end

    cache.last_scan_at = now
    cache.bag_items = {}

    for bag = 0, 4 do
        local ok, items = pcall(function()
            return core.inventory.get_items_in_bag(bag)
        end)
        if ok and items then
            for _, item in ipairs(items) do
                if item and item.get_item_id then
                    local item_id = item:get_item_id()
                    if item_id and item_id > 0 then
                        cache.bag_items[item_id] = true
                    end
                end
            end
        end
    end
end

local function required_totem_key(spell_label)
    if not spell_label then
        return nil
    end

    local s = string.lower(tostring(spell_label))

    if s:find("earth", 1, true) or s:find("tremor", 1, true) or s:find("strength", 1, true) then
        return "earth"
    end
    if s:find("flame", 1, true) or s:find("fire", 1, true) or s:find("lava", 1, true)
        or s:find("searing", 1, true) or s:find("magma", 1, true) then
        return "fire"
    end
    if s:find("frost", 1, true) or s:find("water", 1, true) or s:find("healing stream", 1, true)
        or s:find("mana spring", 1, true) or s:find("mana tide", 1, true) then
        return "water"
    end
    if s:find("wind", 1, true) or s:find("air", 1, true) or s:find("grounding", 1, true)
        or s:find("wrath", 1, true) then
        return "air"
    end

    return nil
end

local function has_totem_item(totem_key)
    local item_id = TOTEM_ITEM_IDS[totem_key]
    if not item_id then
        return true
    end
    scan_bags()
    return cache.bag_items[item_id] == true
end

local function warn_missing(spell_label, totem_key)
    local now = core.time()
    local last = cache.last_warn_at[totem_key] or 0
    if (now - last) < cache.warn_interval_s then
        return
    end
    cache.last_warn_at[totem_key] = now

    local item_id = TOTEM_ITEM_IDS[totem_key]
    core.log("[EAX Totem] Missing " .. tostring(totem_key) .. " totem item " .. tostring(item_id)
        .. " for " .. tostring(spell_label) .. ". Rotation skipping this cast.")
end

function totem_manager.can_cast_spell(spell_label)
    local totem_key = required_totem_key(spell_label)
    if not totem_key then
        return true
    end
    if has_totem_item(totem_key) then
        return true
    end
    warn_missing(spell_label, totem_key)
    return false
end

function totem_manager.try_workaround(_me, _spell_label)
    return false
end

return totem_manager
