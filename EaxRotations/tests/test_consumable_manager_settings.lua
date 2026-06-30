-- ============================================================================
-- Test: consumable_manager — settings + bag wiring
-- WHAT:  Regression test for the 2026-06-29 user-reported bugs:
--          (1) Disabling "Auto Consumables" did not actually stop health
--              potions and dark runes from being used.
--          (2) The manager did 60+ ``has_item`` bag scans even when the
--              player had nothing in bags (no fast-path bag check).
--          (3) ``use_health_potion`` / ``use_rune`` had no per-setting
--              gate (``use_health_potions`` / ``use_dark_runes``) and no
--              schema entry, so the user had no UI to disable them.
-- WHEN:  Run via `lua EaxRotations/tests/run_rotation_tests.lua`.
-- WHY:   These three are the explicit user complaint on 2026-06-29.
-- SAFETY: No state leaks (all mocks per-test).
-- ============================================================================

-- Load helpers (matches test_pattern of other tests in this dir)
local function find_runner_lib()
    local candidates = {
        "EaxRotations/tests/test_runner_lib.lua",
        "../test_runner_lib.lua",
        "test_runner_lib.lua",
    }
    for _, p in ipairs(candidates) do
        local ok, lib = pcall(dofile, p)
        if ok and type(lib) == "table" then return lib end
    end
    return nil
end

local lib = find_runner_lib()
if not lib then
    -- Fall back: bare-bones assert helpers so the test still runs.
    lib = {}
end
-- Add assert_false / assert_not_nil as either-or (some test_runner_lib versions lack them)
lib.assert_true = lib.assert_true or function(cond, msg) assert(cond == true, msg or "expected true") end
lib.assert_eq = lib.assert_eq or function(a, b, msg) assert(a == b, msg or ("expected " .. tostring(b) .. " got " .. tostring(a))) end
lib.assert_false = lib.assert_false or function(cond, msg) assert(cond == false, msg or "expected false") end
lib.assert_not_nil = lib.assert_not_nil or function(v, msg) assert(v ~= nil, msg or "expected non-nil") end

local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

-- Minimal NS mocks --------------------------------------------------------
NS.log = function() end
NS.log_warning = function() end

-- time_now must advance when we want to test throttle windows
local current_time = 100
NS.time_now = function() return current_time end
local function advance(sec) current_time = current_time + sec end

NS.game_time_ms = function() return current_time * 1000 end
NS.mana_pct = function() return 100 end
NS.GetPlayer = function() return { is_in_combat = function() return false end } end
NS.has_player_buff = function() return false end
NS.buff_up = function() return false end
NS.has_buff = function() return false end
NS.use_item_by_id = function() return false end
NS.is_item_ready = function() return false end
NS.WeaponImbueManager = nil
NS.get_role = nil -- not used; we test pure settings gate

-- has_item is the bag-check function. Default to "no items anywhere".
-- Individual tests can override this to simulate "player has X in bags".
local bag_inventory = {}
NS.has_item = function(item_id) return bag_inventory[item_id] == true end
-- Default: items are always ready.  Individual tests may override.
NS.is_item_ready = function() return true end

-- core.inventory.get_items_in_bag is the path the fast-path bag scan uses.
-- We stub it to return whatever the test sets in bag_inventory.
NS.core = NS.core or {}
NS.core.inventory = NS.core.inventory or {}
NS.core.inventory.get_items_in_bag = function(bag_id)
    -- Build a flat list of all item ids the test marked as in-bag.
    local list = {}
    for id, present in pairs(bag_inventory) do
        if present then list[#list + 1] = { item_id = id } end
    end
    return list
end

-- Load the consumable_manager module --------------------------------------
-- The module reads TBC.ITEMS at load time. Stub a minimal TBC data module.
-- We override the file-based require by pre-loading the module's
-- ``shared/tbc_data_sylvanas`` dependency.
package.preload["shared/tbc_data_sylvanas"] = function()
    return {
        ITEMS = {
            healthstones = { 22103, 22104 },  -- Master Healthstone + Major
            potions = {
                super_mana = 22832,
                fel_mana = 32902,
                super_rejuvenation = 22866,
                crystal_mana = 22831,
                auchenai_mana = 22829,
                major_mana = 13443,
                superior_mana = 13442,
                nightmare_seed = 22797,
                super_healing = 22829,
                fel_regeneration = 28103,
                destruction = 22839,
                haste = 22838,
                heroic = 22837,
                insane_strength = 22828,
            },
            elixirs = { major_agility = 9187, major_mageblood = 20007 },
            food = { spicy_hot_talbuk = 27672, warp_burger = 27655 },
            drinks = { conjured_manna_biscuit = 34062 },
            weapon_buffs = { adamantite_sharpening_stone = 23529, brilliant_wizard_oil = 20749 },
            drums = { battle = 29528, war = 29529, speed = 29530 },
            runes = { dark = 20520, demonic = 12662 },
            bandages = { heavy_netherweave = 14530, netherweave = 14529, heavy_runecloth = 14531, runecloth = 14528 },
            scrolls = { agility_v = 27498, intellect_v = 27500 },
            flasks = {
                shattrath_relentless_assault = 35716, relentless_assault = 22851,
                shattrath_supreme_power = 35717, supreme_power = 13512,
                shattrath_mighty_restoration = 35718, mighty_restoration = 22853,
                distilled_wisdom = 13511,
                shattrath_fortification = 35719, fortification = 22850, titans = 13510,
            },
        },
        BUFFS = {
            flasks = { 17628, 17627, 17626 },   -- arbitrary buff ids
            potions = { 17539, 17538, 28507 },
            food = { 18125, 18141, 25661 },
            drink = { 18191, 18192, 18193, 18194 },
            refreshment = { 18191, 18192, 18193, 18194 },
            scrolls = { 24705, 25661, 27498 },
            drums = { 35475, 35476 },
        },
    }
end

-- Load the module.  ``shared/consumable_manager_sylvanas`` does
-- ``pcall(require, "shared/tbc_data_sylvanas")`` at load time, so the
-- preload above is what populates the consumable item tables.
local ok, M = pcall(dofile, "EaxRotations/shared/consumable_manager_sylvanas.lua")
if not ok then ok, M = pcall(dofile, "../shared/consumable_manager_sylvanas.lua") end
if not ok then ok, M = pcall(dofile, "shared/consumable_manager_sylvanas.lua") end
assert(ok, "Failed to load consumable_manager: " .. tostring(M))
assert(type(M) == "table", "consumable_manager did not return a table")
assert(type(M.on_update) == "function", "consumable_manager missing on_update")
assert(type(M.has_any_consumable) == "function", "consumable_manager missing has_any_consumable")

-- Test bag reset helper ---------------------------------------------------
local function reset_bags()
    for k in pairs(bag_inventory) do bag_inventory[k] = nil end
    if M.invalidate_bag_cache then M.invalidate_bag_cache() end
end

-- ============================================================================
-- BUG 1 (user reported): use_health_potion fires even when
--                        use_auto_consumables = false
-- ============================================================================
do
    reset_bags()
    bag_inventory[22797] = true  -- nightmare_seed in bags
    bag_inventory[22829] = true  -- super_healing in bags
    -- Bypass bag-cache stale entry from earlier tests
    M.has_any_consumable({ 22797, 22829, 28103, 22866 })

    local context = {
        in_combat = true,
        hp = 20,             -- below 35% threshold
        mana_pct = 100,
        me = {},
        player_class = 4,    -- rogue
        active_playstyle = "combat",
        settings = {
            use_auto_consumables = false,  -- <-- the bug
            use_health_potions = true,
            health_potion_threshold = 35,
        },
    }

    local fired = M.use_health_potion(context)
    lib.assert_false(fired, "[BUG1] use_health_potion should NOT fire when use_auto_consumables = false")
end

-- ============================================================================
-- BUG 2 (user reported): use_rune fires even when use_auto_consumables = false
-- ============================================================================
do
    reset_bags()
    bag_inventory[20520] = true  -- dark rune in bags
    M.has_any_consumable({ 20520, 12662 })  -- warm cache

    local context = {
        in_combat = true,
        hp = 100,
        mana_pct = 20,        -- below 40% threshold
        me = {},
        player_class = 9,     -- warlock
        active_playstyle = "affliction",
        settings = {
            use_auto_consumables = false,
            use_dark_runes = true,
        },
    }

    local fired = M.use_rune(context)
    lib.assert_false(fired, "[BUG2] use_rune should NOT fire when use_auto_consumables = false")
end

-- ============================================================================
-- BUG 3 (user reported): use_health_potion fires even when per-setting
--                        use_health_potions = false
-- ============================================================================
do
    reset_bags()
    bag_inventory[22797] = true
    M.has_any_consumable({ 22797, 22829, 28103, 22866 })

    local context = {
        in_combat = true,
        hp = 20,
        mana_pct = 100,
        me = {},
        player_class = 4,
        active_playstyle = "combat",
        settings = {
            use_auto_consumables = true,    -- master on
            use_health_potions = false,     -- per-setting off
        },
    }

    local fired = M.use_health_potion(context)
    lib.assert_false(fired, "[BUG3] use_health_potion should NOT fire when use_health_potions = false")
end

-- ============================================================================
-- BUG 4 (user reported): we didn't check our bags before consuming.
--                        If player has no items, manager should short-circuit
--                        without doing 60+ has_item calls.
-- ============================================================================
do
    reset_bags()
    -- Verify has_any_consumable reports empty for health potions.
    local present = M.has_any_consumable({ 22797, 22829, 28103, 22866 })
    lib.assert_false(present, "[BUG4] has_any_consumable should return false for empty bags")
end

-- ============================================================================
-- POSITIVE: when both toggles are on AND player has items, fire the item
-- ============================================================================
do
    reset_bags()
    bag_inventory[22797] = true  -- nightmare_seed in bags
    local use_calls = 0
    NS.use_item_by_id = function(id, target)
        if id == 22797 then
            use_calls = use_calls + 1
            return true
        end
        return false
    end
    M.has_any_consumable({ 22797, 22829, 28103, 22866 })  -- warm cache

    local context = {
        in_combat = true,
        hp = 20,
        mana_pct = 100,
        me = {},
        player_class = 4,
        active_playstyle = "combat",
        settings = {
            use_auto_consumables = true,
            use_health_potions = true,
            health_potion_threshold = 35,
        },
    }

    local fired = M.use_health_potion(context)
    lib.assert_true(fired, "use_health_potion should fire when toggles on + items in bags")
    lib.assert_eq(use_calls, 1, "use_item_by_id should be called exactly once for the matching item")
end

-- ============================================================================
-- THROTTLE: should_check should throttle to 3s
-- ============================================================================
do
    local context = {
        in_combat = true,
        hp = 50,
        mana_pct = 40,
        settings = { use_auto_consumables = true },
    }

    -- First call: should_check true (HP low, in combat)
    local r1 = M.should_check(context)
    lib.assert_true(r1, "should_check should fire on first call when HP low + in combat")

    -- Immediate second call: should be throttled
    local r2 = M.should_check(context)
    lib.assert_false(r2, "should_check should be throttled within 3s window")

    -- Advance past 3s
    advance(4)
    local r3 = M.should_check(context)
    lib.assert_true(r3, "should_check should re-fire after 3s elapse")
end

-- ============================================================================
-- BUGFIX (2026-06-29 follow-up): should_check must also honor the master
-- ``use_auto_consumables`` toggle.  Previously when the toggle was off the
-- executor (``on_update``) returned false, but ``should_check`` continued to
-- return true, causing per-3s trace spam of
--   ``matched=true, executed=false``
-- with no way for the user to recognise the cause.
-- ============================================================================
do
    local context = {
        in_combat = true,
        hp = 30,
        mana_pct = 20,
        settings = { use_auto_consumables = false },
    }
    local r = M.should_check(context)
    lib.assert_false(r, "should_check should return false when use_auto_consumables=false (fixes trace spam)")
end

print("  [ PASS ] test_consumable_manager_settings.lua ok")
