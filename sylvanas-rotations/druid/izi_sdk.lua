-- =============================================================================
-- IZI SDK - Minimal Working Implementation for Sylvanas
-- Core API wrapper for spell casting, units, and game state
-- =============================================================================

local core = _G.core

local izi = {}

-- ============================================================================
-- SPELL SYSTEM
-- ============================================================================

---@class izi_spell
---@field id number Spell ID
---@field name string|nil Spell name
local SpellMT = {}
SpellMT.__index = SpellMT

---Create a spell object
---@param spell_id number
---@return izi_spell
function izi.spell(spell_id)
    local spell = {
        id = spell_id,
        name = nil
    }
    setmetatable(spell, SpellMT)
    return spell
end

---Check if spell is learned
---@return boolean
function SpellMT:is_learned()
    if not core.spell_book then return false end
    local spells = core.spell_book.get_spells()
    if not spells then return false end
    for _, id in ipairs(spells) do
        if id == self.id then return true end
    end
    return false
end

---Check if spell is on cooldown
---@return boolean
function SpellMT:is_on_cooldown()
    if not core.spell_book then return false end
    local cd = core.spell_book.get_cooldown(self.id)
    return cd and cd > 0
end

---Get cooldown remaining
---@return number
function SpellMT:cooldown_left()
    if not core.spell_book then return 0 end
    return core.spell_book.get_cooldown(self.id) or 0
end

---Check if spell is usable
---@return boolean
function SpellMT:is_usable()
    if not core.spell_book then return false end
    return core.spell_book.is_usable(self.id) or false
end

---Check if can cast to target
---@param target game_object|nil
---@return boolean
function SpellMT:is_castable_to(target)
    if not target then return false end
    if not core.spell_helper then return false end
    return core.spell_helper.can_cast_to(self.id, target)
end

---Cast spell
---@param target game_object|nil
---@param label string|nil Debug label
---@return boolean
function SpellMT:cast(target, label)
    if not core.spell_helper then return false end
    return core.spell_helper.cast(self.id, target, label)
end

---Cast spell (safe version with checks)
---@param target game_object|nil
---@param label string|nil Debug label
---@return boolean
function SpellMT:cast_safe(target, label)
    if not self:is_learned() then return false end
    if self:is_on_cooldown() then return false end
    if not self:is_usable() then return false end
    if target and not self:is_castable_to(target) then return false end
    return self:cast(target, label)
end

---Get spell charges
---@return number
function SpellMT:charges()
    if not core.spell_book then return 0 end
    return core.spell_book.get_charges(self.id) or 0
end

---Get spell max charges
---@return number
function SpellMT:max_charges()
    if not core.spell_book then return 0 end
    return core.spell_book.get_max_charges(self.id) or 0
end

-- ============================================================================
-- ITEM SYSTEM
-- ============================================================================

---@class izi_item
---@field id number Item ID
---@field name string|nil Item name
local ItemMT = {}
ItemMT.__index = ItemMT

---Create an item object
---@param item_id number
---@return izi_item
function izi.item(item_id)
    local item = {
        id = item_id,
        name = nil
    }
    setmetatable(item, ItemMT)
    return item
end

---Check if item is in bags
---@return boolean
function ItemMT:has_in_bags()
    -- Check inventory for item
    if not core.inventory_helper then return false end
    return core.inventory_helper.has_item(self.id) or false
end

---Get item count in bags
---@return number
function ItemMT:count()
    if not core.inventory_helper then return 0 end
    return core.inventory_helper.get_item_count(self.id) or 0
end

---Check if item is on cooldown
---@return boolean
function ItemMT:is_on_cooldown()
    if not core.inventory_helper then return false end
    local cd = core.inventory_helper.get_item_cooldown(self.id)
    return cd and cd > 0
end

---Get item cooldown remaining
---@return number
function ItemMT:cooldown_left()
    if not core.inventory_helper then return 0 end
    return core.inventory_helper.get_item_cooldown(self.id) or 0
end

---Use item
---@param target game_object|nil
---@return boolean
function ItemMT:use(target)
    if not core.inventory_helper then return false end
    return core.inventory_helper.use_item(self.id, target) or false
end

---Use item (safe version with checks)
---@param target game_object|nil
---@return boolean
function ItemMT:use_safe(target)
    if not self:has_in_bags() then return false end
    if self:is_on_cooldown() then return false end
    return self:use(target)
end

-- ============================================================================
-- UNIT API
-- ============================================================================

---Get local player
---@return game_object|nil
function izi.me()
    if not core.object_manager then return nil end
    return core.object_manager.get_local_player()
end

---Get target
---@return game_object|nil
function izi.target()
    -- Sylvanas doesn't have get_target() - return nil for now
    -- Target should be obtained through other means
    return nil
end

---Get unit by GUID
---@param guid string
---@return game_object|nil
function izi.unit(guid)
    if not core.object_manager then return nil end
    return core.object_manager.get_object_by_guid(guid)
end

---Get all enemies
---@return game_object[]
function izi.enemies()
    if not core.object_manager then return {} end
    return core.object_manager.get_enemy_list() or {}
end

---Get all allies
---@return game_object[]
function izi.allies()
    if not core.object_manager then return {} end
    return core.object_manager.get_ally_list() or {}
end

---Get group members
---@return game_object[]
function izi.group()
    if not core.object_manager then return {} end
    return core.object_manager.get_group_members() or {}
end

-- ============================================================================
-- BUFF/DEBUFF API
-- ============================================================================

---Check if unit has buff
---@param unit game_object
---@param spell_id number|string Spell ID or name
---@return boolean
function izi.has_buff(unit, spell_id)
    if not unit or not unit.has_buff then return false end
    return unit:has_buff(spell_id)
end

---Check if unit has debuff
---@param unit game_object
---@param spell_id number|string Spell ID or name
---@return boolean
function izi.has_debuff(unit, spell_id)
    if not unit or not unit.has_debuff then return false end
    return unit:has_debuff(spell_id)
end

---Get buff remaining time
---@param unit game_object
---@param spell_id number|string
---@return number
function izi.buff_remaining(unit, spell_id)
    if not unit or not unit.buff_remaining then return 0 end
    return unit:buff_remaining(spell_id) or 0
end

---Get debuff remaining time
---@param unit game_object
---@param spell_id number|string
---@return number
function izi.debuff_remaining(unit, spell_id)
    if not unit or not unit.debuff_remaining then return 0 end
    return unit:debuff_remaining(spell_id) or 0
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

---Check if in combat
---@return boolean
function izi.in_combat()
    local me = izi.me()
    if not me then return false end
    return me.is_in_combat and me:is_in_combat() or false
end

---Check if moving
---@return boolean
function izi.is_moving()
    local me = izi.me()
    if not me then return false end
    return me.is_moving and me:is_moving() or false
end

---Check if casting
---@return boolean
function izi.is_casting()
    local me = izi.me()
    if not me then return false end
    return me.is_casting and me:is_casting() or false
end

---Check if channeling
---@return boolean
function izi.is_channeling()
    local me = izi.me()
    if not me then return false end
    return me.is_channeling and me:is_channeling() or false
end

---Get GCD remaining
---@return number
function izi.gcd_remaining()
    if not core.spell_book then return 0 end
    return core.spell_book.get_gcd_remaining() or 0
end

---Check if on GCD
---@return boolean
function izi.on_gcd()
    return izi.gcd_remaining() > 0
end

---Get current time
---@return number
function izi.time()
    return core.game_time and core.game_time() or 0
end

-- ============================================================================
-- DISTANCE/RANGE
-- ============================================================================

---Get distance between units
---@param unit1 game_object
---@param unit2 game_object|nil
---@return number
function izi.distance_to(unit1, unit2)
    if not unit1 or not unit1.distance_to then return 999 end
    unit2 = unit2 or izi.me()
    if not unit2 then return 999 end
    return unit1:distance_to(unit2) or 999
end

---Check if in melee range
---@param target game_object|nil
---@return boolean
function izi.in_melee(target)
    target = target or izi.target()
    if not target then return false end
    return izi.distance_to(target) <= 5
end

---Check if in spell range
---@param target game_object|nil
---@param spell_id number
---@return boolean
function izi.in_spell_range(target, spell_id)
    if not target then return false end
    if not core.spell_helper then return false end
    return core.spell_helper.is_in_range(spell_id, target) or false
end

-- ============================================================================
-- HEALTH/POWER
-- ============================================================================

---Get unit health percent
---@param unit game_object|nil
---@return number
function izi.health(unit)
    unit = unit or izi.me()
    if not unit then return 0 end
    local health = unit.health and unit:health() or 0
    local max_health = unit.max_health and unit:max_health() or 1
    if max_health == 0 then return 0 end
    return (health / max_health) * 100
end

---Get unit mana percent
---@param unit game_object|nil
---@return number
function izi.mana(unit)
    unit = unit or izi.me()
    if not unit then return 0 end
    local mana = unit.mana and unit:mana() or 0
    local max_mana = unit.max_mana and unit:max_mana() or 1
    if max_mana == 0 then return 0 end
    return (mana / max_mana) * 100
end

---Get unit power (rage/energy/etc)
---@param unit game_object|nil
---@return number
function izi.power(unit)
    unit = unit or izi.me()
    if not unit then return 0 end
    local power = unit.power and unit:power() or 0
    local max_power = unit.max_power and unit:max_power() or 1
    if max_power == 0 then return 0 end
    return (power / max_power) * 100
end

-- ============================================================================
-- COLOR UTILS
-- ============================================================================

izi.color = {}

---Create RGB color
---@param r number 0-255
---@param g number 0-255
---@param b number 0-255
---@param a number|nil 0-255
---@return table
function izi.color.rgb(r, g, b, a)
    return {
        r = r / 255,
        g = g / 255,
        b = b / 255,
        a = (a or 255) / 255
    }
end

---White color
---@param alpha number|nil
---@return table
function izi.color.white(alpha)
    return izi.color.rgb(255, 255, 255, alpha)
end

---Black color
---@param alpha number|nil
---@return table
function izi.color.black(alpha)
    return izi.color.rgb(0, 0, 0, alpha)
end

---Red color
---@param alpha number|nil
---@return table
function izi.color.red(alpha)
    return izi.color.rgb(255, 0, 0, alpha)
end

---Green color
---@param alpha number|nil
---@return table
function izi.color.green(alpha)
    return izi.color.rgb(0, 255, 0, alpha)
end

---Blue color
---@param alpha number|nil
---@return table
function izi.color.blue(alpha)
    return izi.color.rgb(0, 0, 255, alpha)
end

---Yellow color
---@param alpha number|nil
---@return table
function izi.color.yellow(alpha)
    return izi.color.rgb(255, 255, 0, alpha)
end

---Orange color
---@param alpha number|nil
---@return table
function izi.color.orange(alpha)
    return izi.color.rgb(255, 165, 0, alpha)
end

-- ============================================================================
-- RETURN
-- ============================================================================

return izi
