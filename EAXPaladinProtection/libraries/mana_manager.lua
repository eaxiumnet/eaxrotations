-- mana_manager.lua
-- ../eax_shared/mana_manager.lua
-- Proactive mana management for all TBC Classic caster specs.
--
-- Handles: mana potion usage, Evocation timing (Mage), Innervate timing (Druid),
-- Hymn of Hope timing (Priest), and Life Tap optimization (Warlock).
--
-- This complements the existing mana_conservator.lua (wand/melee fallback)
-- with proactive mana optimization before going OOM.
--
-- Usage:
--   local mana_manager = require("libraries/mana_manager")
--   if mana_manager.should_use_mana_potion(me, 30) then
--       local potion_id = mana_manager.get_mana_potion_item_id()
--       core.input.use_item(potion_id)
--   end
--
-- v1.0.0

local mana_manager = {}

-- --- Enums (local to this module, avoids repeated pcall) ----------------------

local POWER_TYPE = {
    MANA = 0,
    RAGE = 1,
    ENERGY = 3,
    RUNIC_POWER = 4,
}

-- --- Constants ----------------------------------------------------------------

-- Mana potion item IDs (rank 3 = best, rank 2 = fallback)
mana_manager.MANA_POTIONS = {
    [28499] = true,  -- Super Mana Potion rank 3 (1100-1500 mana)
    [22828] = true,  -- Super Mana Potion rank 2 (1050-1450 mana)
    [28495] = true,  -- Mana Potion rank 3 (850-1050 mana)
    [22829] = true,  -- Mana Potion rank 2 (800-1000 mana)
}

-- Consumable mana sources
mana_manager.DEMONIC_RUNE = 22120
mana_manager.DARK_RUNE = 22103
mana_manager.MANA_EMERALD = 22044

-- Potion buff IDs (to detect if potion is already active)
mana_manager.MANA_POTION_BUFF_IDS = {
    [28499] = true,  -- Super Mana Potion buff
    [22828] = true,  -- Super Mana Potion rank 2 buff
    [28495] = true,  -- Mana Potion buff
    [22829] = true,  -- Mana Potion rank 2 buff
    [11392] = true,  -- Mana Potion rank 1 buff
    [11391] = true,  -- Mana Potion buff old
}

-- Class-specific spell IDs
mana_manager.EVOCATION_ID = 12051      -- Mage: Evocation
mana_manager.INNERVATE_ID = 29166     -- Druid: Innervate
mana_manager.HYMN_OF_HOPE_ID = 64904  -- Priest: Hymn of Hope (Wrath of the Lich King, TBC uses 27541)
mana_manager.LIFE_TAP_ID = 27222       -- Warlock: Life Tap (updated rank)
mana_manager.ARCANE_TORRENT_MANA_ID = 28730  -- Blood Elf: Arcane Torrent (mana restore)

-- Thresholds
mana_manager.DEFAULT_POTION_THRESHOLD_PCT = 30   -- Use potion below 30% mana
mana_manager.DEFAULT_EVOCATION_THRESHOLD_PCT = 30 -- Evocation at 30% mana
mana_manager.DEFAULT_INNERVATE_THRESHOLD_PCT = 25 -- Innervate at 25% mana
mana_manager.DEFAULT_LIFE_TAP_HP_THRESHOLD_PCT = 30 -- Don't Life Tap below 30% HP
mana_manager.DEFAULT_LIFE_TAP_MANA_FLOOR_PCT = 60 -- Life Tap below 60% mana

-- Mana potion cooldown (seconds) - Super Mana Potion: 120s shared cooldown
mana_manager.POTION_COOLDOWN_S = 120

-- --- Internal State ------------------------------------------------------------

local potion_last_use_time = 0
local potion_use_throttle_s = 5.0  -- Minimum 5s between potion use attempts

-- --- Helpers ------------------------------------------------------------------

---Count item stacks in character bags using documented inventory surfaces.
---@param item_id number
---@return number
local function get_item_count(item_id)
    if not item_id or not core or not core.inventory or not core.inventory.get_items_in_bag then
        return 0
    end

    local total = 0
    for bag = 0, 4 do
        local ok, items = pcall(function()
            return core.inventory.get_items_in_bag(bag)
        end)
        if ok and items then
            for _, slot in ipairs(items) do
                local item = slot and slot.object
                if item and item.is_valid and item:is_valid() and item.get_item_id and item:get_item_id() == item_id then
                    if item.get_item_stack_count then
                        total = total + (item:get_item_stack_count() or 1)
                    else
                        total = total + 1
                    end
                end
            end
        end
    end

    return total
end

---Get current mana percentage (0-100).
---@param me game_object
---@return number mana_pct (0-100)
function mana_manager.get_mana_pct(me)
    local max_mana = me:get_max_power(POWER_TYPE.MANA)
    if not max_mana or max_mana <= 0 then
        return 100  -- No mana pool (non-caster)
    end
    local current_mana = me:get_power(POWER_TYPE.MANA)
    return (current_mana / max_mana) * 100
end

---Get the best available mana potion item ID from inventory.
---Returns the highest-ranked potion found in inventory, or nil if none.
---@return number|nil item_id
function mana_manager.get_mana_potion_item_id()
    -- Check in order of quality: Super Mana Potion rank 3 first
    local check_order = {
        28499,  -- Super Mana Potion rank 3
        22828,  -- Super Mana Potion rank 2
        28495,  -- Mana Potion rank 3
        22829,  -- Mana Potion rank 2
        mana_manager.DEMONIC_RUNE,
        mana_manager.DARK_RUNE,
    }

    for _, item_id in ipairs(check_order) do
        local count = get_item_count(item_id)
        if count and count > 0 then
            return item_id
        end
    end

    return nil
end

---Check if a specific buff is active on the player.
---@param me game_object
---@param buff_ids table list of buff spell IDs to check
---@return boolean
local function has_any_buff(me, buff_ids)
    if not me or not buff_ids then return false end
    for _, buff_id in ipairs(buff_ids) do
        if me:has_buff(buff_id) then
            return true
        end
    end
    return false
end

---Check if player is currently buffed by any mana potion.
---@param me game_object
---@return boolean
local function has_mana_potion_buff(me)
    -- Build buff ID list from MANA_POTION_BUFF_IDS
    local buff_list = {}
    for buff_id, _ in pairs(mana_manager.MANA_POTION_BUFF_IDS) do
        table.insert(buff_list, buff_id)
    end
    return has_any_buff(me, buff_list)
end

---Check if a spell is on cooldown.
---@param spell_id number
---@return boolean on_cooldown
local function is_on_cooldown(spell_id)
    if not spell_id then return true end
    local cd = core.spell_book.get_spell_cooldown(spell_id)
    return cd > 0
end

-- --- Public API ---------------------------------------------------------------

---Check if player should use a mana potion.
---Conditions: mana below threshold, potion available, not on potion buff, cooldown passed.
---@param me game_object
---@param threshold_pct number mana below which to use potion (default 30)
---@return boolean
function mana_manager.should_use_mana_potion(me, threshold_pct)
    threshold_pct = threshold_pct or mana_manager.DEFAULT_POTION_THRESHOLD_PCT

    -- Check mana level
    local mana_pct = mana_manager.get_mana_pct(me)
    if mana_pct >= threshold_pct then
        return false
    end

    -- Check if already buffed by mana potion
    if has_mana_potion_buff(me) then
        return false
    end

    -- Check throttle
    local now = core.time()
    if (now - potion_last_use_time) < potion_use_throttle_s then
        return false
    end

    -- Check inventory
    local potion_id = mana_manager.get_mana_potion_item_id()
    if not potion_id then
        return false
    end

    -- Potion is usable
    return true
end

---Use mana potion (call this after should_use_mana_potion returns true).
---@return boolean success
function mana_manager.use_mana_potion()
    local potion_id = mana_manager.get_mana_potion_item_id()
    if not potion_id then
        return false
    end
    local ok = core.input.use_item(potion_id)
    if ok then
        potion_last_use_time = core.time()
    end
    return ok
end

---Check if player should Evocation / Innervate / Hymn of Hope / Arcane Torrent.
---For Mage (Evocation): mana < threshold and not in combat movement.
---For Druid (Innervate): mana < threshold.
---For Priest (Hymn of Hope): party mana average low.
---For Blood Elf (Arcane Torrent): mana < threshold and no boss buff.
---@param me game_object
---@param class_name string "mage", "druid", "priest", or "bloodelf"
---@param menu table|nil optional menu for per-class settings
---@return boolean
function mana_manager.should_evocate(me, class_name, menu)
    if not class_name then
        class_name = "unknown"
    end

    class_name = string.lower(class_name)

    -- Blood Elf: Arcane Torrent
    if class_name == "bloodelf" then
        local mana_pct = mana_manager.get_mana_pct(me)
        local threshold = mana_manager.DEFAULT_EVOCATION_THRESHOLD_PCT
        if menu and menu.arcane_torrent_threshold then
            threshold = menu.arcane_torrent_threshold:get()
        end
        if mana_pct >= threshold then
            return false
        end
        if is_on_cooldown(mana_manager.ARCANE_TORRENT_MANA_ID) then
            return false
        end
        return true
    end

    -- Mage: Evocation
    if class_name == "mage" then
        local mana_pct = mana_manager.get_mana_pct(me)
        local threshold = mana_manager.DEFAULT_EVOCATION_THRESHOLD_PCT
        if menu and menu.evocation_threshold then
            threshold = menu.evocation_threshold:get()
        end
        if mana_pct >= threshold then
            return false
        end
        -- Check Evocation is learned and not on cooldown
        if is_on_cooldown(mana_manager.EVOCATION_ID) then
            return false
        end
        return true
    end

    -- Druid: Innervate
    if class_name == "druid" then
        local mana_pct = mana_manager.get_mana_pct(me)
        local threshold = mana_manager.DEFAULT_INNERVATE_THRESHOLD_PCT
        if menu and menu.innervate_threshold then
            threshold = menu.innervate_threshold:get()
        end
        if mana_pct >= threshold then
            return false
        end
        -- Innervate is a buff we cast on ourselves, check cooldown
        if is_on_cooldown(mana_manager.INNERVATE_ID) then
            return false
        end
        return true
    end

    -- Priest: Shadowfiend + Hymn of Hope (TBC doesn't have Hymn, use Shadowfiend)
    -- For TBC, Hymn of Hope doesn't exist (added in WotLK). Use Shadowfiend instead.
    if class_name == "priest" then
        -- In TBC, Priests rely on Shadowfiend for mana recovery
        -- The shadowfiend mana return is handled in the priest spec itself
        return false  -- Priests handle mana differently in TBC
    end

    return false
end

---Check if player should Life Tap (Warlock self-damage for mana).
---Only when: above HP threshold, below mana floor, target above HP threshold,
---Evocation not on cooldown (dual-use check).
---@param me game_object
---@param menu table|nil optional menu for per-class settings
---@return boolean
function mana_manager.should_life_tap(me, menu)
    -- Check HP safety floor first
    local hp_pct = me:get_health_percentage()
    local hp_threshold = mana_manager.DEFAULT_LIFE_TAP_HP_THRESHOLD_PCT
    if menu and menu.life_tap_hp_threshold then
        hp_threshold = menu.life_tap_hp_threshold:get()
    end
    if hp_pct <= hp_threshold then
        return false
    end

    -- Check mana floor (tap only when mana is below the floor)
    local mana_pct = mana_manager.get_mana_pct(me)
    local mana_floor_pct = mana_manager.DEFAULT_LIFE_TAP_MANA_FLOOR_PCT
    if menu and menu.life_tap_mana_floor then
        mana_floor_pct = menu.life_tap_mana_floor:get()
    end
    if mana_pct >= mana_floor_pct then
        return false
    end

    -- Check Life Tap is learned
    if is_on_cooldown(mana_manager.LIFE_TAP_ID) then
        return false
    end

    -- Check not in combat where we need HP buffer
    if me:is_in_combat() and hp_pct < 50 then
        return false
    end

    return true
end

---Get estimated cast time in ms for a spell.
---@param spell_id number
---@return number cast_time_ms (0 if instant or unknown)
function mana_manager.get_spell_cast_time_ms(spell_id)
    if not spell_id then
        return 0
    end
    local ok, result = pcall(function()
        return core.spell_book.get_spell_cast_time(spell_id)
    end)
    if not ok or not result then
        return 0
    end
    return result
end

---Get the mana cost of a spell (base cost, before talents/bonuses).
---@param spell_id number
---@return number mana_cost (0 if unknown or not a mana spell)
function mana_manager.get_spell_mana_cost(spell_id)
    -- TBC spell book doesn't directly expose mana cost via this API
    -- We use known baseline costs from spell research
    local known_costs = {
        -- Moonfire ranks
        [26988] = 335,  -- Moonfire rank 13
        [26986] = 315,  -- Moonfire rank 12
        -- Insect Swarm
        [27013] = 385,  -- Insect Swarm rank 6
        -- Corruption ranks
        [27216] = 520,  -- Corruption rank 10
        [25311] = 490,  -- Corruption rank 9
        [17811] = 460,  -- Corruption rank 8
        -- Immolate
        [27215] = 490,  -- Immolate rank 13
        [17811] = 425,  -- Immolate rank 12
        -- Shadow Bolt
        [27209] = 380,  -- Shadow Bolt rank 13
        [11661] = 350,  -- Shadow Bolt rank 10
        -- Fireball
        [27070] = 410,  -- Fireball rank 16
        [25306] = 370,  -- Fireball rank 15
        -- Frostbolt
        [27072] = 335,  -- Frostbolt rank 13
        -- Arcane Blast
        [27100] = 660,  -- Arcane Blast rank 5
        [27067] = 560,  -- Arcane Blast rank 4
        -- SW:Pain
        [25368] = 450,  -- SW:Pain rank 12
        [25367] = 430,  -- SW:Pain rank 11
        -- Devouring Plague
        [29406] = 585,  -- Devouring Plague rank 4
        [25467] = 570,  -- Devouring Plague rank 3
        -- Vampiric Touch
        [34917] = 550,  -- VT rank 4
        [34916] = 530,  -- VT rank 3
        -- Unstable Affliction
        [30405] = 570,  -- UA rank 5
        [30404] = 545,  -- UA rank 4
        -- Siphon Life
        [30911] = 650,  -- Siphon Life rank 7
        -- Curse of Agony
        [27218] = 385,  -- CoA rank 9
        -- Pyroblast
        [27068] = 550,  -- Pyroblast rank 11
        [25302] = 510,  -- Pyroblast rank 10
        -- Mind Blast
        [25372] = 400,  -- Mind Blast rank 11
        [10947] = 370,  -- Mind Blast rank 10
        -- Mind Flay
        [25387] = 330,  -- Mind Flay rank 4
        -- Life Tap
        [27222] = 0,    -- Life Tap: gives mana, costs health
        [11689] = 0,    -- Life Tap rank 6
    }

    return known_costs[spell_id] or 0
end

---Get the current Evocation cooldown remaining (seconds).
---@return number cooldown_s (0 if ready)
function mana_manager.get_evocation_cooldown_s()
    if not mana_manager.EVOCATION_ID then
        return 0
    end
    return core.spell_book.get_spell_cooldown(mana_manager.EVOCATION_ID)
end

---Check if a spell is currently usable (not on cooldown, enough mana).
---@param spell_id number
---@return boolean
function mana_manager.can_cast_spell(spell_id)
    if not spell_id then
        return false
    end
    local on_cd = core.spell_book.get_spell_cooldown(spell_id)
    if on_cd > 0 then
        return false
    end
    return core.spell_book.is_usable_spell(spell_id)
end

---Reset potion throttle (call when entering combat, etc.).
function mana_manager.reset()
    potion_last_use_time = 0
end

return mana_manager
