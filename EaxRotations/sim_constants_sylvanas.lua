-- runtime module.

-- ============================================================================
-- Sim-Derived Constants
-- Source: sim/core/base_stats_auto_gen.go, constants.go,
--         flags.go, target.go, spell_result.go, spell_outcome.go
--
-- These constants represent mathematically validated TBC mechanics.
-- They are used by EaxRotations rotation logic for accurate threshold
-- calculations, hit/crit caps, and combat table awareness.
--
-- DO NOT EDIT these values — they are derived from the simulator which
-- models TBC's actual combat mechanics. If the sim updates, re-extract.
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

-- ============================================================================
-- 1. RATING → PERCENTAGE CONVERSION CONSTANTS
-- Source: sim/sim/core/base_stats_auto_gen.go
-- These give the amount of rating needed for 1% at level 70.
-- ============================================================================

NS.SIM_RATING = {
    -- Expertise: 3.942308 rating per 0.25% dodge/parry reduction (quarter-percent)
    ExpertisePerQuarterPercentReduction = 3.942308,

    -- Defense: 2.365385 rating per defense skill point
    DefenseRatingPerDefenseLevel = 2.365385,

    -- Dodge: 18.923079 rating per 1% dodge
    DodgeRatingPerDodgePercent = 18.923079,

    -- Parry: 23.653847 rating per 1% parry
    ParryRatingPerParryPercent = 23.653847,

    -- Block: 7.884615 rating per 1% block
    BlockRatingPerBlockPercent = 7.884615,

    -- Physical Hit: 15.769233 rating per 1% physical hit
    PhysicalHitRatingPerHitPercent = 15.769233,

    -- Spell Hit: 12.615385 rating per 1% spell hit
    SpellHitRatingPerHitPercent = 12.615385,

    -- Physical Crit: 22.076923 rating per 1% physical crit
    PhysicalCritRatingPerCritPercent = 22.076923,

    -- Spell Crit: 22.076923 rating per 1% spell crit
    SpellCritRatingPerCritPercent = 22.076923,

    -- Physical Haste: 15.769233 rating per 1% physical haste
    PhysicalHasteRatingPerHastePercent = 15.769233,

    -- Spell Haste: 15.76923 rating per 1% spell haste
    SpellHasteRatingPerHastePercent = 15.76923,
}

-- ============================================================================
-- 2. CORE GAME CONSTANTS
-- Source: sim/sim/core/constants.go
-- ============================================================================

NS.SIM_CORE = {
    -- Player level (TBC max)
    CharacterLevel = 70,

    -- Boss level (raid boss = player + 3)
    BossLevel = 73,

    -- GCD duration in seconds
    GCDMin = 1.0,
    GCDDefault = 1.5,

    -- Boss GCD (1.62s)
    BossGCD = 1.62,

    -- Max spell queue window (0.4s)
    MaxSpellQueueWindow = 0.4,

    -- Attack Power per DPS (14 AP = 1 DPS)
    AttackPowerPerDPS = 14.0,

    -- Armor Penetration per percent armor ignored
    ArmorPenPerPercentArmor = 5.92,

    -- Defense skill contribution per defense point
    -- Each point of defense gives 0.04% to miss/dodge/parry/block/crit reduction
    MissDodgeParryBlockCritChancePerDefense = 0.04,

    -- Resilience: 39.4231 rating per 1% crit reduction chance
    ResilienceRatingPerCritReductionChance = 39.4231,

    -- Combat table coverage cap (102.4% = uncrushable for tanks)
    CombatTableCoverageCap = 1.024,

    -- Dual wield miss penalty (additional 19% miss on white attacks)
    DWMissPenalty = 0.19,

    -- Maximum melee range in yards
    MaxMeleeRange = 5.0,
}

-- ============================================================================
-- 3. COMBAT TABLE VALUES (Attack Table by Level Difference)
-- Source: sim/sim/core/target.go - NewAttackTable()
-- Values indexed by [attacker_level - defender_level] offset.
-- For players attacking bosses (70 vs 73), use offset +3.
-- ============================================================================

NS.SIM_COMBAT_TABLE = {
    -- Attack table chances for PLAYER vs NPC (attacker = player, defender = enemy)
    -- Index: level difference (defender_level - attacker_level)
    -- [0] = same level, [1] = +1, [2] = +2, [3] = +3 (boss)
    PlayerVsNPC = {
        -- Base miss chance (single weapon / special attacks — NO DW penalty)
        -- DW white attacks add 0.19 to these values
        BaseMissChance = {
            [0] = 0.050,   -- 5.0%
            [1] = 0.055,   -- 5.5%
            [2] = 0.060,   -- 6.0%
            [3] = 0.080,   -- 8.0% (boss — 9% with hit suppression)
        },

        -- Spell miss chance
        BaseSpellMissChance = {
            [0] = 0.04,    -- 4%
            [1] = 0.05,    -- 5%
            [2] = 0.06,    -- 6%
            [3] = 0.17,    -- 17% (boss)
        },

        -- Block chance (from front only)
        BaseBlockChance = 0.05, -- 5% (constant across levels)

        -- Dodge chance (from front only; negated from behind)
        BaseDodgeChance = {
            [0] = 0.050,   -- 5.0%
            [1] = 0.055,   -- 5.5%
            [2] = 0.060,   -- 6.0%
            [3] = 0.065,   -- 6.5% (boss, before Sunwell suppression)
        },

        -- Parry chance (from front only; negated from behind)
        BaseParryChance = {
            [0] = 0.050,   -- 5.0%
            [1] = 0.055,   -- 5.5%
            [2] = 0.060,   -- 6.0%
            [3] = 0.140,   -- 14.0% (boss)
        },

        -- Glancing blow chance (white attacks only, from front)
        BaseGlanceChance = {
            [0] = 0.060,   -- 6%
            [1] = 0.120,   -- 12%
            [2] = 0.180,   -- 18%
            [3] = 0.240,   -- 24% (boss)
        },

        -- Glancing blow damage multiplier
        GlanceMultiplier = {
            [0] = 0.95,    -- 95% damage
            [1] = 0.95,    -- 95% damage
            [2] = 0.85,    -- 85% damage
            [3] = 0.75,    -- 75% damage (boss)
        },

        -- Hit suppression (reduces your hit% effectively)
        HitSuppression = {
            [0] = 0.00,
            [1] = 0.00,
            [2] = 0.00,
            [3] = 0.01,    -- 1% (boss)
        },

        -- Melee crit suppression (reduces your crit% against target)
        MeleeCritSuppression = {
            [0] = 0.000,   -- 0%
            [1] = 0.010,   -- 1%
            [2] = 0.020,   -- 2%
            [3] = 0.048,   -- 4.8% (boss)
        },

        -- Spell crit suppression
        SpellCritSuppression = {
            [0] = 0.000,   -- 0%
            [1] = 0.000,   -- 0%
            [2] = 0.003,   -- 0.3%
            [3] = 0.021,   -- 2.1% (boss)
        },
    },

    -- NPC vs Player attack table (for tanking calculations)
    -- Key = mob_level - player_level (positive = mob is higher level)
    -- Source note: constants mirror the server-side level-difference lookup.
    -- These are the defender's (player) avoidance values when an NPC of given level attacks.
    -- Higher-level mobs are harder for the player to avoid: miss/dodge/parry/block all decrease.
    NPCVsPlayer = {
        BaseSpellMissChance = 0.05, -- 5% (constant, not level-dependent)

        -- Miss chance: higher-level mobs miss less often vs players
        BaseMissChance = {
            [0]  = 0.050,   -- Same-level mob vs player
            [1]  = 0.048,   -- +1 mob
            [2]  = 0.046,   -- +2 mob
            [3]  = 0.044,   -- +3 mob (boss)
        },

        -- Block chance: decreases vs higher-level mobs
        BaseBlockChance = {
            [0]  = 0.050,
            [1]  = 0.048,
            [2]  = 0.046,
            [3]  = 0.044,
        },

        -- Dodge chance: goes negative vs higher-level mobs (player dodges LESS)
        -- Server lookup values for same-level through boss-level attackers.
        BaseDodgeChance = {
            [0]  = 0.000,   -- Same-level mob: no dodge modifier
            [1]  = -0.002,  -- +1 mob: -0.2% dodge
            [2]  = -0.004,  -- +2 mob: -0.4% dodge
            [3]  = -0.006,  -- +3 mob (boss): -0.6% dodge
        },

        -- Parry chance: decreases vs higher-level mobs
        BaseParryChance = {
            [0]  = 0.050,
            [1]  = 0.048,
            [2]  = 0.046,
            [3]  = 0.044,
        },

        -- Crushing blow chance (mobs 4+ levels above, or boss = level 73)
        -- Server lookup values for same-level through boss-level attackers.
        BaseCrushChance = {
            [0]  = 0.0,     -- Same-level mob: no crushing
            [1]  = 0.0,
            [2]  = 0.0,
            [3]  = 0.15,    -- +3 mob (boss): 15% crushing
        },
    },
}

-- ============================================================================
-- 4. PRE-COMPUTED HIT CAPS FOR BOSS TARGETS (Level 73)
-- These are the most commonly needed values for rotation logic.
-- ============================================================================

NS.SIM_HIT_CAPS = {
    -- Special attack hit cap (8% base miss + 1% suppression = 9% total needed)
    -- With NO DW penalty (specials never suffer DW penalty)
    MeleeSpecialHitCapPercent = 9.0,
    MeleeSpecialHitCapRating = 9.0 * 15.769233, -- ~142 rating

    -- White attack hit cap for 2H (same as special: 9%)
    Melee2HHitCapPercent = 9.0,
    Melee2HHitCapRating = 9.0 * 15.769233, -- ~142 rating

    -- White attack hit cap for DW (9% + 19% DW penalty = 28%)
    MeleeDWHitCapPercent = 28.0,
    MeleeDWHitCapRating = 28.0 * 15.769233, -- ~442 rating

    -- Spell hit cap (17% base miss, min 1% can't be removed)
    SpellHitCapPercent = 16.0,  -- 17% base - 1% minimum = 16% effective cap
    SpellHitCapRating = 16.0 * 12.615385, -- ~202 rating

    -- Expertise cap for dodge (6.5% dodge, each quarter-percent = 3.94 rating)
    -- floor(6.5 * 4) = 26 quarter-percent reductions = 26 * 3.94 ≈ 102.5 rating
    -- 6.5% dodge needs 26 expertise skill (= 102.5 rating at 3.94/skill)
    ExpertiseDodgeCapSkill = 26,  -- 6.5% dodge removal
    ExpertiseDodgeCapRating = 26 * 3.942308, -- ~102.5 rating

    -- Expertise cap for parry (14% parry from front on boss)
    -- floor(14 * 4) = 56 quarter-percent reductions
    ExpertiseParryCapSkill = 56,  -- 14% parry removal
    ExpertiseParryCapRating = 56 * 3.942308, -- ~220.8 rating
}

-- ============================================================================
-- 5. CLASS BASE STATS (Extra class-specific at level 70)
-- Source: sim/sim/core/base_stats_auto_gen.go - ExtraClassBaseStats
-- ============================================================================

NS.SIM_CLASS_BASE_STATS = {
    WARRIOR = {
        BaseMana = 0,
        BaseSpellCritPercent = 0.0,
        BasePhysicalCritPercent = 1.14, -- 1.14% base melee crit
    },
    PALADIN = {
        BaseMana = 2953,
        BaseSpellCritPercent = 3.3355,
        BasePhysicalCritPercent = 0.652,
    },
    HUNTER = {
        BaseMana = 3383,
        BaseSpellCritPercent = 3.602,
        BasePhysicalCritPercent = -1.532,
    },
    ROGUE = {
        BaseMana = 0,
        BaseSpellCritPercent = 0.0,
        BasePhysicalCritPercent = -0.295,
    },
    PRIEST = {
        BaseMana = 2620,
        BaseSpellCritPercent = 1.2375,
        BasePhysicalCritPercent = 3.183,
    },
    SHAMAN = {
        BaseMana = 2958,
        BaseSpellCritPercent = 2.201,
        BasePhysicalCritPercent = 1.675,
    },
    MAGE = {
        BaseMana = 2241,
        BaseSpellCritPercent = 0.9075,
        BasePhysicalCritPercent = 3.4575,
    },
    WARLOCK = {
        BaseMana = 2615,
        BaseSpellCritPercent = 1.70,
        BasePhysicalCritPercent = 2.0,
    },
    DRUID = {
        BaseMana = 2370,
        BaseSpellCritPercent = 1.8515,
        BasePhysicalCritPercent = 0.961,
    },
}

-- ============================================================================
-- 6. CRIT PER AGILITY / INTELLECT (at max level)
-- Source: sim/sim/core/base_stats_auto_gen.go
-- Values are crit% per 1 point of the stat at level 70.
-- ============================================================================

NS.SIM_CRIT_PER_STAT = {
    -- Crit% per Agility (melee/ranged crit contribution)
    CritPerAgi = {
        WARRIOR  = 0.0303,  -- ~33 agi = 1% crit
        PALADIN  = 0.0400,  -- 25 agi = 1% crit
        HUNTER   = 0.0250,  -- 40 agi = 1% crit
        ROGUE    = 0.0250,  -- 40 agi = 1% crit
        PRIEST   = 0.0400,  -- 25 agi = 1% crit
        SHAMAN   = 0.0400,  -- 25 agi = 1% crit
        MAGE     = 0.0400,  -- 25 agi = 1% crit
        WARLOCK  = 0.0405,  -- ~24.7 agi = 1% crit
        DRUID    = 0.0400,  -- 25 agi = 1% crit
    },

    -- Crit% per Intellect (spell crit contribution)
    CritPerInt = {
        WARRIOR  = 0.0000,  -- No spell crit from int
        PALADIN  = 0.0125,  -- 80 int = 1% spell crit
        HUNTER   = 0.0125,  -- 80 int = 1% spell crit
        ROGUE    = 0.0000,  -- No spell crit from int
        PRIEST   = 0.0125,  -- 80 int = 1% spell crit
        SHAMAN   = 0.0125,  -- 80 int = 1% spell crit
        MAGE     = 0.0125,  -- 80 int = 1% spell crit
        WARLOCK  = 0.0122,  -- ~82 int = 1% spell crit
        DRUID    = 0.0125,  -- 80 int = 1% spell crit
    },
}

-- ============================================================================
-- 7. SPELL FLAGS
-- These classify spells for rotation gating logic.
-- EaxRotations uses these in matches() conditions to determine
-- when a spell type is appropriate.
-- ============================================================================

NS.SIM_SPELL_FLAG = {
    -- Source: sim/sim/core/flags.go
    -- Go uses `1 << iota` where iota=1 for the first entry after the =0 constant,
    -- so the first flag is 2, not 1. Values must match the Go source exactly.

    None                     = 0,
    IgnoreResists            = 2,       -- 1 << 1 — skip spell resist/armor
    IgnoreTargetModifiers    = 4,       -- 1 << 2 — skip target damage modifiers
    IgnoreAttackerModifiers  = 8,       -- 1 << 3 — skip attacker damage modifiers
    ApplyArmorReduction      = 16,      -- 1 << 4 — force armor reduction
    CannotBeDodged           = 32,      -- 1 << 5 — ignore dodge in hit rolls (Overpower)
    IncludeTargetBonusDamage = 64,      -- 1 << 6 — benefits from Hemorrhage/Gift of Arthas
    Binary                   = 128,     -- 1 << 7 — no partial resists (different hit roll)
    Channeled                = 256,     -- 1 << 8 — spell is channeled
    Disease                  = 512,     -- 1 << 9 — categorized as disease
    Poison                   = 1024,    -- 1 << 10 — categorized as poison
    HauntSE                  = 2048,    -- 1 << 11 — benefits from Haunt/SE effects
    Helpful                  = 4096,    -- 1 << 12 — healing spell / buff
    MeleeMetrics             = 8192,    -- 1 << 13 — melee ability for metrics
    NoOnCastComplete         = 16384,   -- 1 << 14 — disables OnCastComplete callback
    NoMetrics                = 32768,   -- 1 << 15 — disables metrics
    NoLogs                   = 65536,   -- 1 << 16 — disables logs

    -- *** KEY FLAGS FOR ROTATION GATING ***
    -- These are the flags the knowledge.md explicitly calls for:
    APL                      = 131072,  -- 1 << 17 — can be used from APL rotation
    MCD                      = 262144,  -- 1 << 18 — Major Cooldown (burst CD)
    Reactive                 = 524288,  -- 1 << 19 — off-GCD instant defensive CD
    NoOnDamageDealt          = 1048576, -- 1 << 20 — disables OnSpellHitDealt/OnPeriodicDamageDealt
    PrepullOnly              = 2097152, -- 1 << 21 — prepull only
    EncounterOnly            = 4194304, -- 1 << 22 — encounter only (not prepull)
    Potion                   = 8388608, -- 1 << 23 — potion spell
    Conjured                 = 16777216,-- 1 << 24 — conjured item spell
    CombatPotion             = 33554432,-- 1 << 25 — combat potion
    NoSpellMods              = 67108864,-- 1 << 26 — no spell mods
    CanCastWhileMoving       = 134217728, -- 1 << 27 — castable while moving
    PassiveSpell             = 268435456, -- 1 << 28 — applied by another spell
    SupressDoTApply          = 536870912, -- 1 << 29 — suppress DoT application
    Swapped                  = 1073741824,-- 1 << 30 — from swapped item

    -- Composite masks
    IgnoreModifiers          = 12,     -- IgnoreAttacker(8) | IgnoreTarget(4)
}

-- ============================================================================
-- 8. SPELL SCHOOLS
-- Source: sim/sim/core/flags.go
-- ============================================================================

NS.SIM_SPELL_SCHOOL = {
    -- Source: sim/sim/core/flags.go
    -- Go uses `1 << iota` where iota=1 for Physical, so Physical=2, not 1.
    None     = 0,
    Physical = 2,       -- 1 << 1
    Arcane   = 4,       -- 1 << 2
    Fire     = 8,       -- 1 << 3
    Frost    = 16,      -- 1 << 4
    Holy     = 32,      -- 1 << 5
    Nature   = 64,      -- 1 << 6
    Shadow   = 128,     -- 1 << 7
    -- Composite schools
    Chaos       = 252,  -- Arcane(4) + Fire(8) + Frost(16) + Holy(32) + Nature(64) + Shadow(128)
    ShadowFlame = 136,  -- Fire(8) + Shadow(128)
    ShadowFrost = 144,  -- Frost(16) + Shadow(128)
    Plague      = 192,  -- Nature(64) + Shadow(128)
    Firestorm   = 72,   -- Fire(8) + Nature(64)
    Frostfire   = 24,   -- Fire(8) + Frost(16)
    Elemental   = 88,   -- Fire(8) + Nature(64) + Frost(16)
}

-- ============================================================================
-- 9. HIT OUTCOME FLAGS
-- Source: sim/sim/core/flags.go
-- Used for understanding combat table results
-- ============================================================================

NS.SIM_OUTCOME = {
    -- Source: sim/sim/core/flags.go
    -- Go uses `1 << iota` where iota=1 for OutcomeMiss, so Miss=2, not 1.
    Empty = 0,
    Miss  = 2,         -- 1 << 1
    Hit   = 4,         -- 1 << 2
    Dodge = 8,         -- 1 << 3
    Glance = 16,       -- 1 << 4
    Parry = 32,        -- 1 << 5
    Block = 64,        -- 1 << 6
    Crit  = 128,       -- 1 << 7
    Crush = 256,       -- 1 << 8
    Partial1_4 = 512,   -- 1 << 9 — 25% resisted
    Partial2_4 = 1024,  -- 1 << 10 — 50% resisted
    Partial3_4 = 2048,  -- 1 << 11 — 75% resisted
    -- Composite masks
    Partial = 512 + 1024 + 2048,
    Landed  = 4 + 128 + 256 + 16 + 64, -- Hit | Crit | Crush | Glance | Block
}

-- ============================================================================
-- 10. PROC MASKS (for understanding which spells trigger which procs)
-- Source: sim/sim/core/flags.go
-- ============================================================================

NS.SIM_PROC_MASK = {
    -- Source: sim/sim/core/flags.go
    -- Go uses `1 << iota` where iota=1 for ProcMaskEmpty, so Empty=2, not 1.
    Unknown           = 0,
    Empty             = 2,       -- 1 << 1
    MeleeMHAuto       = 4,       -- 1 << 2 — main hand auto attack
    MeleeOHAuto       = 8,       -- 1 << 3 — off hand auto attack
    MeleeMHSpecial    = 16,      -- 1 << 4 — main hand special
    MeleeOHSpecial    = 32,      -- 1 << 5 — off hand special
    RangedAuto        = 64,      -- 1 << 6 — ranged auto
    RangedSpecial     = 128,     -- 1 << 7 — ranged special
    SpellDamage       = 256,     -- 1 << 8 — spell damage
    SpellHealing      = 512,     -- 1 << 9 — spell healing
    SpellProc         = 1024,    -- 1 << 10 — spell proc trigger
    MeleeProc         = 2048,    -- 1 << 11 — melee proc trigger
    RangedProc        = 4096,    -- 1 << 12 — ranged proc trigger
    SpellDamageProc   = 8192,    -- 1 << 13 — spell damage proc (FT/poisons)

    -- Composite masks
    MeleeMH       = 4 + 16,           -- MH auto + special
    MeleeOH       = 8 + 32,           -- OH auto + special
    MeleeWhiteHit = 4 + 8,           -- All auto attacks
    WhiteHit      = 4 + 8 + 64,      -- All white hits (melee + ranged)
    MeleeSpecial  = 16 + 32,          -- All melee specials
    MeleeOrRangedSpecial = 16 + 32 + 128, -- All specials
    Melee         = 4 + 8 + 16 + 32, -- All melee
    Ranged        = 64 + 128,         -- All ranged
    MeleeOrRanged = 4 + 8 + 16 + 32 + 64 + 128, -- All attacks
    Direct        = 4 + 8 + 16 + 32 + 64 + 128 + 256, -- Direct damage
    Special       = 16 + 32 + 128 + 256, -- All specials + spell damage
    Proc          = 1024 + 4096 + 2048, -- All proc triggers
}

-- ============================================================================
-- 11. EXECUTE THRESHOLDS
-- Source: sim/sim/core/target.go - Encounter struct
-- Commonly used HP% thresholds for execute-phase abilities
-- ============================================================================

NS.SIM_EXECUTE_THRESHOLD = {
    -- Standard execute range (Warrior Execute, etc.)
    Execute_20 = 0.20,  -- 20% HP

    -- Warlock Drain Soul bonus damage
    Execute_25 = 0.25,  -- 25% HP

    -- Mage Molten Fury talent
    Execute_35 = 0.35,  -- 35% HP

    -- Shadow Priest Shadow of Death
    Execute_45 = 0.45,  -- 45% HP

    -- Hunter Kill Command (some specs)
    Execute_90 = 0.90,  -- 90% HP (mostly for target below 90% checks)
}

-- ============================================================================
-- 12. SUNWELL RADIANCE (Sunwell Plateau boss dodge/miss suppression)
-- Source: sim/sim/core/target.go
-- Applied to level 73 bosses with SuppressDodge flag
-- ============================================================================

NS.SIM_SUNWELL_RADIANCE = {
    DodgeReduction = 0.20,   -- -20% dodge
    IncreasedMissChance = -0.05, -- -5% miss (makes bosses easier to hit)
}

-- ============================================================================
-- 13. CONVENIENCE DERIVED VALUES
-- Pre-computed common thresholds that rotation logic uses frequently
-- ============================================================================

-- Boss target level offset (most common case: player 70 vs boss 73)
NS.SIM_BOSS_LEVEL_OFFSET = 3

-- Melee crit cap calculator for 2H weapons against boss from behind:
-- crit_cap = 100% - miss% - dodge% - glance% - melee_crit_suppression%
-- For 2H behind boss: 100 - 8 - 6.5 - 24 - 4.8 = 56.7% crit cap
-- (After hit/expertise caps: 100 - 0 - 0 - 24 - 4.8 = 71.2%)
NS.SIM_CRIT_CAP = {
    -- 2H weapon, from behind, boss target, hit capped, dodge capped (26 expertise)
    TwoH_Behind_Boss_HitExpCapped = 100 - 0 - 0 - 24 - 4.8, -- 71.2%

    -- 2H weapon, from behind, boss target, no hit/expertise
    TwoH_Behind_Boss_Uncapped = 100 - 8 - 6.5 - 24 - 4.8, -- 56.7%

    -- DW weapon, from behind, boss target, hit capped, dodge capped
    -- DW white: miss = 8 + 19 = 27% before hit rating
    DW_Behind_Boss_HitExpCapped = 100 - 0 - 0 - 24 - 4.8, -- 71.2% (same as 2H when hit capped for DW)

    -- From front, boss target, hit capped, parry capped (56 expertise), block included
    Front_Boss_HitParryExpCapped = 100 - 0 - 0 - 0 - 5 - 24 - 4.8, -- 66.2%
}

-- Rating needed to reach hit cap (melee specials vs boss)
NS.SIM_RATING_TO_CAP = {
    -- Melee special hit cap (9% needed at 15.77 rating/%)
    MeleeSpecialHit = math.ceil(9.0 * 15.769233),   -- 142 rating

    -- Spell hit cap (16% effective at 12.62 rating/%)
    SpellHit = math.ceil(16.0 * 12.615385),          -- 202 rating

    -- Dodge expertise cap (6.5% dodge = 26 skill at 3.94 rating/skill)
    ExpertiseDodge = math.ceil(26 * 3.942308),        -- 103 rating

    -- Parry expertise cap (14% parry = 56 skill at 3.94 rating/skill)
    ExpertiseParry = math.ceil(56 * 3.942308),        -- 221 rating
}

-- ============================================================================
-- 14. SPELL CRIT MULTIPLIERS (TBC default values)
-- ============================================================================

NS.SIM_CRIT_MULTIPLIER = {
    -- Melee crit: 2.0x damage (200%)
    MeleeDefault = 2.0,

    -- Spell crit: 1.5x damage (150%)
    SpellDefault = 1.5,

    -- Melee crit with crit multiplier talents:
    -- Some classes have talents that increase crit bonus
    -- (e.g. Rogue Lethality, Warrior Impale, etc.)
    -- These are per-class and defined in class constants if needed.
}

-- ============================================================================
-- 15. RESOURCE CONSTANTS
-- ============================================================================

NS.SIM_RESOURCE = {
    -- Energy regen per tick
    EnergyPerTick = 20,

    -- Energy tick interval
    EnergyTickDuration = 2.0,

    -- Max energy (base, before talents)
    EnergyMax = 100,

    -- Max rage
    RageMax = 100,

    -- Max combo points
    ComboPointsMax = 5,

    -- Base mana regen from spirit (formula: spirit * 0.25 + 0.12 per 2s while not casting)
    -- This is simplified; actual regen depends on class and level
    ManaRegenSpiritCoefficient = 0.25,

    -- Five second rule (no spirit regen for 5s after casting)
    FiveSecondRule = 5.0,
}

NS.log("Sim-derived constants loaded")
