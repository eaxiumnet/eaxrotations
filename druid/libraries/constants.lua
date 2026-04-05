-- =============================================================================
-- DRUID CONSTANTS MODULE
-- Ported from Flux AIO - Framework-agnostic constants for TBC Druid
-- =============================================================================

local Constants = {
    -- =========================================================================
    -- STANCE INDICES (TBC WoW stance IDs)
    -- =========================================================================
    STANCE = {
        CASTER = 0,
        BEAR = 1,
        CAT = 3,
        TRAVEL = 4,
        MOONKIN = 5,
        TREE = 5,  -- Moonkin and Tree share stance slot (mutually exclusive 41pt talents)
    },

    -- =========================================================================
    -- BUFF IDs (for aura detection)
    -- =========================================================================
    BUFF_ID = {
        CLEARCASTING = 16870,    -- Omen of Clarity proc
        NATURES_GRACE = 16886,   -- Nature's Grace proc (post-cast haste)
        TIGERS_FURY = 5217,      -- Tiger's Fury buff
        OOMEN_OF_CLARITY = 16864, -- Omen of Clarity (passive buff)
    },

    -- =========================================================================
    -- DEBUFF IDs (for target debuff detection)
    -- =========================================================================
    DEBUFF_ID = {
        FAERIE_FIRE = 16857,     -- Feral Faerie Fire
        FAERIE_FIRE_CASTER = 770, -- Caster Faerie Fire
        MOONFIRE = 8921,
        INSECT_SWARM = 5570,
        RIP = 1079,
        RAKE = 1822,
        MANGLE = 33876,          -- Mangle (Cat)
        MANGLE_BEAR = 33878,     -- Mangle (Bear)
        LACERATE = 33745,
        DEMO_ROAR = 99,
    },

    -- =========================================================================
    -- TIME-TO-DIE THRESHOLDS
    -- =========================================================================
    TTD = {
        RIP_MIN = 10,            -- Minimum TTD to apply Rip
        RAKE_MIN = 6,            -- Minimum TTD to apply Rake
        BITE_EXECUTE = 6,        -- TTD threshold for bite execute
        SHORT_FIGHT = 10,        -- Short fight threshold
        FORCE_OF_NATURE_MIN = 15, -- Minimum TTD to summon treants
    },

    -- =========================================================================
    -- ENERGY MANAGEMENT (Cat Form)
    -- =========================================================================
    ENERGY = {
        CRITICAL = 10,           -- Critical energy threshold for emergency powershift
        CRITICAL_SHIFT = 15,     -- Shift threshold when critically low
        MANGLE_POOL = 20,        -- Energy to pool for Mangle
        BITE_TRICK_MAX = 39,     -- Max energy for bite trick
        RAKE_TRICK_MIN = 35,     -- Min energy for rake trick
        EARLY_SHIFT = 20,        -- Early shift threshold
        EARLY_SHIFT_WOLFSHEAD = 25, -- Early shift with Wolfshead Helm
        TICK_INTERVAL = 2.0,     -- Energy tick interval (seconds)
        TICK_AMOUNT = 20,        -- Energy per tick
    },

    -- =========================================================================
    -- POWERSHIFT CONSTANTS
    -- =========================================================================
    POWERSHIFT = {
        FUROR_ENERGY = 40,       -- Energy from Furor talent on shift
        WOLFSHEAD_BONUS = 20,    -- Bonus energy from Wolfshead Helm
        MIN_SHIFT_ENERGY_GAIN = 20, -- Minimum gain to justify a shift
        SHIFT_IGNORE_WINDOW = 0.6, -- Ignore energy gains within this window of shift
        TICK_WAIT_THRESHOLD = 0.4, -- Wait for tick if arriving within this window
    },

    -- =========================================================================
    -- HP THRESHOLDS
    -- =========================================================================
    HP = {
        EXECUTE = 25,            -- Target HP% for execute phase
    },

    -- =========================================================================
    -- DURATION CONSTANTS
    -- =========================================================================
    DURATION = {
        BITE_MIN_RIP = 3,        -- Minimum Rip duration before biting
    },

    -- =========================================================================
    -- AOE CONSTANTS
    -- =========================================================================
    AOE = {
        RAKE_SPREAD_NEARBY = 8,  -- Range for Rake spread
        HURRICANE_MIN_TARGETS = 3, -- Minimum targets for Hurricane
        SWIPE_CC_CHECK_RANGE = 10, -- Range for breakable CC check
    },

    -- =========================================================================
    -- BALANCE (MOONKIN) CONSTANTS
    -- =========================================================================
    BALANCE = {
        FAERIE_FIRE_REFRESH = 3, -- Refresh threshold for Faerie Fire
        MANA_TIER1 = 20,         -- Full rotation above this mana %
        MANA_TIER2 = 10,         -- Reduced DoTs above this mana %
        MANA_LOW = 20,           -- Low mana threshold
    },

    -- =========================================================================
    -- BEAR (TANK) CONSTANTS
    -- =========================================================================
    BEAR = {
        MANGLE_CD = 6,                    -- Mangle cooldown
        LACERATE_MAX_STACKS = 5,          -- Max Lacerate stacks
        LACERATE_DURATION = 15,           -- Lacerate duration
        LACERATE_URGENT_REFRESH = 3,     -- Urgent refresh threshold
        LACERATE_SWIPE_THRESHOLD = 3,     -- Swipe threshold at 5 stacks
        LACERATE_BUILD_REFRESH = 6,       -- Reapply when building stacks
        DEMO_ROAR_DURATION = 30,          -- Demo Roar duration
        DEMO_ROAR_REFRESH = 5,            -- Demo Roar refresh threshold
        DEMO_ROAR_THROTTLE = 10,          -- Demo Roar cast throttle
        DEFAULT_MAUL_RAGE = 25,           -- Default Maul rage threshold
        DEFAULT_SWIPE_RAGE = 15,          -- Default Swipe rage threshold
        DEFAULT_SWIPE_TARGETS = 3,        -- Default Swipe target threshold
        ENRAGE_RAGE_THRESHOLD = 20,       -- Enrage rage threshold
        ENRAGE_HP_SAFETY = 50,            -- Safe HP to use Enrage
        DEMO_ROAR_MIN_TTD = 8,            -- Min TTD for Demo Roar
        GROWL_MIN_TTD = 4,                -- Min TTD for Growl
        GROWL_CC_THRESHOLD = 2,           -- CC threshold for Growl
        FRENZIED_PROACTIVE_HP = 50,       -- Proactive FR HP threshold
        FRENZIED_PROACTIVE_RAGE = 50,     -- Proactive FR rage threshold
        MAUL_AOE_EXTRA_RAGE = 15,         -- Extra rage for Maul in AoE
        MANGLE_HOLD_WINDOW = 0.5,         -- Hold GCD for Mangle window
        DEFAULT_DEMO_ROAR_RANGE = 10,     -- Demo Roar check range
        DEFAULT_DEMO_ROAR_MIN_BOSSES = 1, -- Min bosses for Demo Roar
        DEFAULT_DEMO_ROAR_MIN_ELITES = 2, -- Min elites for Demo Roar
        DEFAULT_DEMO_ROAR_MIN_TRASH = 5,  -- Min trash for Demo Roar
        DEFAULT_CROAR_RANGE = 10,         -- Challenging Roar range
        DEFAULT_CROAR_MIN_BOSSES = 1,     -- Min bosses for Challenging Roar
        DEFAULT_CROAR_MIN_ELITES = 3,     -- Min elites for Challenging Roar
        FF_THROTTLE = 6,                  -- Faerie Fire throttle (seconds)
        TAB_MAX_ATTEMPTS = 10,            -- Max tab target attempts
        MANUAL_TARGET_GRACE = 3,          -- Grace period after manual target
    },

    -- =========================================================================
    -- RESTO (HEALER) CONSTANTS
    -- =========================================================================
    RESTO = {
        EMERGENCY_HP = 30,           -- Emergency heal HP threshold
        TANK_HEAL_HP = 50,           -- Tank heal HP threshold
        STANDARD_HEAL_HP = 80,       -- Standard heal HP threshold
        PROACTIVE_HP = 90,           -- Proactive HoT HP threshold
        LIFEBLOOM_REFRESH = 2,       -- Lifebloom refresh threshold
        SWIFTMEND_HP = 50,           -- Swiftmend HP threshold
        MANA_CONSERVE = 40,          -- Mana conserve threshold
    },

    -- =========================================================================
    -- ITEM IDs
    -- =========================================================================
    ITEM_ID = {
        WOLFSHEAD_HELM = 8345,       -- Wolfshead Helm (for powershifting)
        INVSLOT_HEAD = 1,            -- Head slot index
    },

    -- =========================================================================
    -- DEBUFF TYPE CONSTANTS (for dispel)
    -- =========================================================================
    DEBUFF_TYPE = {
        MAGIC = 1,
        DISEASE = 2,
        POISON = 4,
        CURSE = 8,
    },

    -- =========================================================================
    -- BREAKABLE CC NAMES (for Swipe safety)
    -- =========================================================================
    BREAKABLE_CC_NAMES = {
        "Polymorph",
        "Freezing Trap Effect",
        "Repentance",
        "Blind",
        "Sap",
        "Gouge",
        "Hibernate",
        "Wyvern Sting",
        "Scatter Shot",
        "Shackle Undead",
        "Seduction",
    },

    -- =========================================================================
    -- BUFF ID ARRAYS (multi-rank detection)
    -- =========================================================================
    MOTW_BUFF_IDS = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 21849, 21850, 26991 },
    THORNS_BUFF_IDS = { 467, 782, 1075, 8914, 9756, 9910, 26992 },
    TIGERS_FURY_BUFF_IDS = { 5217, 6793, 9845, 9846 },
    REJUVENATION_BUFF_IDS = { 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299, 26981, 26982 },
    REGROWTH_BUFF_IDS = { 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858, 26980 },
    FAERIE_FIRE_DEBUFF_IDS = { 16857, 17390, 17391, 17392, 27011, 770, 778, 9749, 9907, 26993 },
    DEMO_ROAR_DEBUFF_IDS = { 99, 1735, 9490, 9747, 9898, 26998 },
    MANGLE_DEBUFF_IDS = { 33876, 33982, 33983, 33878, 33986, 33987 },
    RIP_DEBUFF_IDS = { 1079, 9492, 9493, 9752, 9894, 9896, 27008 },
    RAKE_DEBUFF_IDS = { 1822, 1823, 1824, 9904, 27003 },
    MOONFIRE_DEBUFF_IDS = { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835, 26987, 26988 },
    INSECT_SWARM_DEBUFF_IDS = { 5570, 24974, 24975, 24976, 24977, 27013 },
}

return Constants
