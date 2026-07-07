-- engineering_helper_sylvanas.lua -- Engineering bomb/explosive usage helper.
-- WHAT:  Detects and uses the best available engineering explosive (Sapper, Grenade, Dynamite).
-- WHEN:  combat with valid enemy target; called as a filler strategy by DPS specs.
-- WHY:   wowsims APLs include engineering items in dedicated groups (Fury, Arms, Feral Cat).
-- SAFETY: nil-guarded; self-gating on item readiness; opt-in via use_engineering_bombs setting.
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.
-- SOURCE: wowsims/tbc-new/ui/<class>/dps/apls/*.apl.json "Engineering" groups.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local M = {}
NS.EngineeringHelper = M

-- Engineering explosives, ordered best-first (highest level / damage first).
-- Source: wowsims Fury/Arms/Cat APL "Engineering" groups.
--   23827 = Super Sapper Charge      (lvl 68, engineering)
--   23737 = Adamantite Grenade        (lvl 65, engineering)
--   23736 = Fel Iron Bomb            (lvl 60, engineering)
--   18588 = Ez-Thro Dynamite II       (lvl 40, engineering, 30s CD)
--   11566 = Crystal Charge           (lvl 55, Zul'Farrak — usable by anyone)
--   10646 = Goblin Sapper Charge      (lvl 41, engineering)
local BOMB_ITEM_IDS = { 23827, 23737, 23736, 18588, 11566, 10646 }

--- Find the best (highest-priority) ready engineering bomb in bags.
-- @return number|nil  item ID of the best ready bomb, or nil if none ready.
function M.best_ready_bomb()
    if not NS.is_item_ready then return nil end
    for _, item_id in ipairs(BOMB_ITEM_IDS) do
        local ok, ready = pcall(NS.is_item_ready, item_id)
        if ok and ready then return item_id end
    end
    return nil
end

--- Check whether engineering bombs should be used.
-- Gates on the use_engineering_bombs setting (default true) and item readiness.
-- @param context  table  Rotation context (settings + combat state).
-- @return boolean
function M.should_use_bomb(context)
    local settings = (context and context.settings) or {}
    if settings.use_engineering_bombs == false then return false end
    if not (context and context.in_combat) then return false end
    if not (context and context.has_valid_enemy_target) then return false end
    return M.best_ready_bomb() ~= nil
end

--- Use the best ready engineering bomb on the current target.
-- @param context  table  Rotation context.
-- @return boolean  true if a bomb was used.
function M.use_best_bomb(context)
    local item_id = M.best_ready_bomb()
    if not item_id then return false end
    if not NS.use_item_by_id then return false end
    local ok, used = pcall(NS.use_item_by_id, item_id, context.me)
    return ok and used == true
end

-- Export for unit-test dofile pattern
_G.EngineeringHelper = M
return M
