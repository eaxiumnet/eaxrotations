-- weapon_poison_sylvanas.lua -- rogue weapon poison detection + application.
-- WHAT:  detects whether each weapon slot carries a poison and applies the best
--        owned poison out of combat (main hand = damage poison, off hand =
--        stacking poison).
-- WHEN:  called by the rogue middleware out-of-combat upkeep lane; pure helper
--        everywhere else.
-- WHY:   the previous PoisonCheck only WARNED that poisons were missing - nothing
--        ever applied one, so the weapons stayed bare and the spec lost both the
--        poison damage and the poison-stack gates (Envenom, Mutilate).
-- SAFETY: every engine call pcall'd; nil-tolerant weapon/slot reads; fail-open
--        (this module never gates the rotation); no per-frame work - one status
--        probe per call, module-local state only.
-- DECISION: detection + application owned here; the middleware only decides when.
--
-- APPLY SURFACE: core.input.use_item_target(poison_item_id, weapon_object),
-- reached through NS.use_item_by_id(item_id, weapon). The weapon object comes
-- from me:get_item_at_inventory_slot(16|17).object. This is the same item-on-item
-- call the archived original EAX rogue poison manager used in production; the
-- engine exposes no "apply enchant" entry point, so an item use is the only
-- supported way to put a poison on a weapon.
--
-- DETECTION SURFACE: GetWeaponEnchantInfo() (the client's per-slot temporary
-- enchant read) first, then the equipped item's own item_has_enchant /
-- item_enchant_id / item_enchant_expiration fields. A slot whose detection APIs
-- answer nothing after a successful apply is held as "assumed" for the poison's
-- real duration, so an engine that cannot report the enchant does not make the
-- rotation re-apply every throttled tick.
--
-- POISON LADDER: item ids per poison kind, highest rank first (vanilla/TBC item
-- data; see EaxRotations/tools/generate_weapon_data.py --check). Eras whose item
-- data is not sourced here report NO_ITEM rather than guessing a rank - the lane
-- then warns that a poison is missing instead of applying the wrong item.

local M = {}

local MAIN_HAND_SLOT = 16
local OFF_HAND_SLOT = 17
local APPLY_THROTTLE_S = 5
local ASSUMED_POISON_DURATION_S = 1700

M.SLOT = { MAIN_HAND = MAIN_HAND_SLOT, OFF_HAND = OFF_HAND_SLOT }
M.APPLY_THROTTLE_S = APPLY_THROTTLE_S

-- Item ids, highest rank first (Wowhead/cMaNGOS item data, vanilla + TBC).
M.POISON_LADDERS = {
    instant = { 21927, 8928, 8927, 8926, 6950, 6949, 6947 },   -- Instant Poison VII .. I
    deadly  = { 22054, 22053, 20844, 8985, 8984, 2893, 2892 }, -- Deadly Poison VII .. I
}

-- The published rogue loadout: flat damage poison on the main hand, the
-- stacking poison on the off hand.
M.LOADOUT = { mainhand = "instant", offhand = "deadly" }

M.STATUS = {
    NO_WEAPON = "no-weapon",        -- nothing equipped in the slot
    LIVE      = "live",             -- the engine reports an enchant on the slot
    ASSUMED   = "assumed",          -- applied by us, engine cannot confirm it
    READY     = "ready",            -- bare slot AND a usable poison is in the bags
    NO_ITEM   = "no-poison-item",   -- bare slot and no poison item owned
}

local applied_state = {
    [MAIN_HAND_SLOT] = { weapon_item_id = nil, poison_item_id = nil, expires_at = 0 },
    [OFF_HAND_SLOT]  = { weapon_item_id = nil, poison_item_id = nil, expires_at = 0 },
}
local last_apply_at = 0


-- ============================================================================
-- Engine readers (every call guarded; no bare NS member use)
-- ============================================================================

local function time_now(NS)
    local f = NS and NS.time_now
    if type(f) ~= "function" then return 0 end
    local ok, t = pcall(f)
    if ok and type(t) == "number" then return t end
    return 0
end

local function player(NS)
    local f = NS and NS.GetPlayer
    if type(f) ~= "function" then return nil end
    local ok, me = pcall(f)
    if ok and type(me) == "table" then return me end
    return nil
end

-- The equipped weapon OBJECT for a slot (this is what use_item_target targets).
function M.slot_weapon(NS, slot)
    local me = player(NS)
    if not me then return nil end
    local get = me.get_item_at_inventory_slot
    if type(get) ~= "function" then return nil end
    local ok, info = pcall(get, me, slot)
    if not ok or type(info) ~= "table" then return nil end
    local item = info.object or info.item
    if type(item) ~= "table" then return nil end
    return item
end

local function item_id_of(item)
    if type(item) ~= "table" then return nil end
    local f = item.get_item_id
    if type(f) ~= "function" then return nil end
    local ok, id = pcall(f, item)
    if ok and type(id) == "number" and id > 0 then return id end
    return nil
end

-- GetWeaponEnchantInfo() -> mh_has, _, _, _, oh_has (nil when unavailable).
local function weapon_enchant_flags()
    if type(GetWeaponEnchantInfo) ~= "function" then return nil end
    local ok, mh, _, _, _, oh = pcall(GetWeaponEnchantInfo)
    if not ok then return nil end
    return { mh = mh == true, oh = oh == true }
end

-- The equipped item's own enchant fields -> true / nil (nil = no answer).
local function item_enchant_live(item)
    if type(item) ~= "table" then return nil end
    local has = item.item_has_enchant
    if type(has) == "function" then
        local ok, v = pcall(has, item)
        if ok and v == true then return true end
    elseif type(has) == "boolean" and has then
        return true
    end
    local idf = item.item_enchant_id
    if type(idf) == "function" then
        local ok, v = pcall(idf, item)
        if ok and type(v) == "number" and v > 0 then return true end
    end
    local exp = item.item_enchant_expiration
    if type(exp) == "function" then
        local ok, v = pcall(exp, item)
        if ok and type(v) == "number" and v > 0 then return true end
    end
    return nil
end

local function owns(NS, item_id)
    local f = NS and NS.has_item
    if type(f) ~= "function" then return false end
    local ok, has = pcall(f, item_id)
    return ok and has == true
end

-- Highest-rank poison of `kind` that is actually in the bags (nil when none).
function M.best_owned(NS, kind)
    local ladder = M.POISON_LADDERS[kind]
    if not ladder then return nil end
    for i = 1, #ladder do
        if owns(NS, ladder[i]) then return ladder[i] end
    end
    return nil
end

-- ============================================================================
-- Status + application
-- ============================================================================

local function assumed_live(slot, weapon_id, poison_id, now)
    local s = applied_state[slot]
    if not s then return false end
    return s.expires_at > now
        and s.weapon_item_id == weapon_id
        and s.poison_item_id == poison_id
end

local function mark_assumed(slot, weapon_id, poison_id, now)
    local s = applied_state[slot]
    if not s then return end
    s.weapon_item_id = weapon_id
    s.poison_item_id = poison_id
    s.expires_at = now + ASSUMED_POISON_DURATION_S
end

-- status, weapon_item_id, poison_item_id
function M.slot_status(NS, slot, now)
    now = now or time_now(NS)
    local weapon = M.slot_weapon(NS, slot)
    if not weapon then return M.STATUS.NO_WEAPON, nil, nil end
    local weapon_id = item_id_of(weapon)
    local kind = (slot == OFF_HAND_SLOT) and M.LOADOUT.offhand or M.LOADOUT.mainhand
    local poison_id = M.best_owned(NS, kind)

    local live
    local flags = weapon_enchant_flags()
    if flags then
        live = (slot == OFF_HAND_SLOT) and flags.oh or flags.mh
    end
    if live ~= true and item_enchant_live(weapon) == true then live = true end

    if live then return M.STATUS.LIVE, weapon_id, poison_id end
    if assumed_live(slot, weapon_id, poison_id, now) then
        return M.STATUS.ASSUMED, weapon_id, poison_id
    end
    if poison_id then return M.STATUS.READY, weapon_id, poison_id end
    return M.STATUS.NO_ITEM, weapon_id, poison_id
end

-- True when a slot is bare and we own something to put on it.
function M.needs_poison(NS, now)
    now = now or time_now(NS)
    local s = M.slot_status(NS, MAIN_HAND_SLOT, now)
    if s == M.STATUS.READY then return true end
    s = M.slot_status(NS, OFF_HAND_SLOT, now)
    return s == M.STATUS.READY
end

-- True when any equipped weapon slot is bare, whether or not we can fix it.
function M.missing(NS, now)
    now = now or time_now(NS)
    for _, slot in ipairs({ MAIN_HAND_SLOT, OFF_HAND_SLOT }) do
        local status = M.slot_status(NS, slot, now)
        if status == M.STATUS.READY or status == M.STATUS.NO_ITEM then return true end
    end
    return false
end

-- True when a slot is bare AND no poison item is owned (the actionable warning).
function M.warn_state(NS, now)
    now = now or time_now(NS)
    local mh = M.slot_status(NS, MAIN_HAND_SLOT, now)
    local oh = M.slot_status(NS, OFF_HAND_SLOT, now)
    return mh == M.STATUS.NO_ITEM or oh == M.STATUS.NO_ITEM
end

-- Apply the best owned poison to the first slot that needs it.
-- Returns applied, slot, poison_item_id (throttled to one attempt per 5s).
function M.try_apply(NS, now)
    now = now or time_now(NS)
    if (now - last_apply_at) < APPLY_THROTTLE_S then return false end
    local use = NS and NS.use_item_by_id
    if type(use) ~= "function" then return false end
    for _, slot in ipairs({ MAIN_HAND_SLOT, OFF_HAND_SLOT }) do
        local status, weapon_id, poison_id = M.slot_status(NS, slot, now)
        if status == M.STATUS.READY and poison_id then
            local weapon = M.slot_weapon(NS, slot)
            if weapon then
                last_apply_at = now
                local ok, applied = pcall(use, poison_id, weapon)
                if ok and applied then
                    mark_assumed(slot, weapon_id, poison_id, now)
                    return true, slot, poison_id
                end
                return false
            end
        end
    end
    return false
end

-- Test/telemetry helper: forget every assumed reading and the throttle.
function M.reset()
    last_apply_at = 0
    for _, slot in ipairs({ MAIN_HAND_SLOT, OFF_HAND_SLOT }) do
        local s = applied_state[slot]
        s.weapon_item_id = nil
        s.poison_item_id = nil
        s.expires_at = 0
    end
end

return M
