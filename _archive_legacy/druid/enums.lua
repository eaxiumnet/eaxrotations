-- =============================================================================
-- ENUMS - Actual enum values for Sylvanas Framework
-- Minimal subset needed for TBC rotations
-- =============================================================================

local enums = {}

-- Class IDs (from Blizzard API)
enums.class_id = {
    ANY = -1,
    WARRIOR = 1,
    PALADIN = 2,
    HUNTER = 3,
    ROGUE = 4,
    PRIEST = 5,
    DEATHKNIGHT = 6,
    SHAMAN = 7,
    MAGE = 8,
    WARLOCK = 9,
    MONK = 10,
    DRUID = 11,
    DEMONHUNTER = 12,
    EVOKER = 13
}

-- Power Types
enums.power_type = {
    HEALTH = -2,
    NONE = -1,
    MANA = 0,
    RAGE = 1,
    FOCUS = 2,
    ENERGY = 3,
    COMBOPOINTS = 4,
    RUNES = 5,
    RUNICPOWER = 6,
    SOULSHARDS = 7,
    LUNARPOWER = 8,
    HOLYPOWER = 9,
    ALTERNATE = 10,
    MAELSTROM = 11,
    CHI = 12,
    INSANITY = 13,
    OBSOLETE = 14,
    OBSOLETE2 = 15,
    ARCANECHARGES = 16,
    FURY = 17,
    PAIN = 18,
    ESSENCE = 19,
    RUNEFORGEPOWER = 20
}

-- Group Roles
enums.group_role = {
    NONE = 0,
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3
}

-- Mark Indices (raid markers)
enums.mark_index = {
    NO_MARK = 0,
    STAR = 1,
    CIRCLE = 2,
    DIAMOND = 3,
    TRIANGLE = 4,
    MOON = 5,
    SQUARE = 6,
    CROSS = 7,
    SKULL = 8
}

-- Spell Schools
enums.spell_schools_flags = {
    NONE = 0,
    PHYSICAL = 1,
    HOLY = 2,
    FIRE = 4,
    NATURE = 8,
    FROST = 16,
    SHADOW = 32,
    ARCANE = 64
}

-- Spell Types
enums.spell_type = {
    NONE = 0,
    HELPFUL = 1,
    HARMFUL = 2,
    PASSIVE = 4,
    NOT_A_SPELL = 8
}

-- Creature Types
enums.creature_type = {
    NONE = -1,
    BEAST = 1,
    DRAGONKIN = 2,
    DEMON = 3,
    ELEMENTAL = 4,
    GIANT = 5,
    UNDEAD = 6,
    HUMANOID = 7,
    CRITTER = 8,
    MECHANICAL = 9,
    NOT_SPECIFIED = 10,
    TOTEM = 11,
    NON_COMBAT_PET = 12,
    GAS_CLOUD = 13
}

-- Classification (elite, boss, etc)
enums.classification = {
    NONE = 0,
    NORMAL = 1,
    ELITE = 2,
    RARE = 3,
    RAREELITE = 4,
    WORLDBOSS = 5
}

-- CC Source types
enums.cc_source = {
    UNKNOWN = 0,
    PLAYER = 1,
    GROUP_MEMBER = 2,
    EXTERNAL = 3
}

-- CC Flags
enums.cc_flags = {
    NONE = 0,
    STUN = 1,
    FEAR = 2,
    ROOT = 4,
    SILENCE = 8,
    POLYMORPH = 16,
    HORROR = 32,
    SAP = 64,
    BLIND = 128,
    INCAPACITATE = 256,
    DISORIENT = 512,
    BANISH = 1024,
    CYCLONE = 2048,
    SLEEP = 4096,
    FROZEN = 8192,
    ENEMY_CC = 16384
}

-- Loss of Control types
enums.loss_of_control_type = {
    NONE = 0,
    STUN = 1,
    ROOT = 2,
    SILENCE = 3,
    DISARM = 4,
    FEAR = 5,
    CHARM = 6,
    CONFUSE = 7,
    POSSESS = 8,
    SCHOOL_INTERRUPT = 9
}

-- Menu element types
enums.menu_element_type = {
    TEXT = 0,
    BUTTON = 1,
    CHECKBOX = 2,
    KEYBIND = 3,
    SLIDER_INT = 4,
    SLIDER_FLOAT = 5,
    COMBO = 6,
    INPUT_TEXT = 7,
    COLOR_PICKER = 8,
    TREE_NODE = 9,
    SEPARATOR = 10,
    HEADER = 11,
    PROGRESS_BAR = 12
}

-- Buff types
enums.buff_type = {
    BUFF = 0,
    DEBUFF = 1
}

-- Return the enums table
return enums
