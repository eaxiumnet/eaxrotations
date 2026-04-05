-- =============================================================================
-- DRUID SPELL DEFINITIONS MODULE
-- Ported from Flux AIO - IZI SDK Spell Definitions for TBC Druid
-- =============================================================================

local izi = require("common/izi_sdk")

-- ============================================================================
-- RACIALS
-- ============================================================================
local Racials = {
    Berserking = izi.spell(26297),    -- Troll
    BloodFury = izi.spell(33697),     -- Orc
}

-- ============================================================================
-- SELF BUFFS
-- ============================================================================
local SelfBuffs = {
    MarkOfTheWild = izi.spell(1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 21849, 21850, 26991),
    Thorns = izi.spell(467, 782, 1075, 8914, 9756, 9910, 26992),
    OmenOfClarity = izi.spell(16864),
}

-- ============================================================================
-- SELF-CAST UTILITY
-- ============================================================================
local SelfUtility = {
    RemoveCurse = izi.spell(2782),
    AbolishPoison = izi.spell(2893),
    Innervate = izi.spell(29166),
    Barkskin = izi.spell(22812),
}

-- ============================================================================
-- FORMS
-- ============================================================================
local Forms = {
    CatForm = izi.spell(768),
    BearForm = izi.spell(9634),      -- Dire Bear Form
    MoonkinForm = izi.spell(24858),
    TravelForm = izi.spell(783),
    TreeOfLifeForm = izi.spell(33891),
}

-- ============================================================================
-- CAT ABILITIES
-- ============================================================================
local CatAbilities = {
    Rake = izi.spell(1822, 1823, 1824, 9904, 27003),
    Rip = izi.spell(1079, 9492, 9493, 9752, 9894, 9896, 27008),
    FerociousBite = izi.spell(22568, 22827, 22828, 22829, 31018),
    Shred = izi.spell(5221, 6800, 8992, 9829, 9830, 27001, 27002),
    MangleCat = izi.spell(33876, 33982, 33983),
    TigersFury = izi.spell(5217, 6793, 9845, 9846),
    Prowl = izi.spell(5215, 6783),
    Ravage = izi.spell(6785, 6787, 9866, 9867, 27005, 27006),
    Pounce = izi.spell(9005, 9823, 9827, 27006, 27007),
    Dash = izi.spell(33357, 1850, 9821),
    FaerieFire = izi.spell(16857, 17390, 17391, 17392, 27011),
    Cower = izi.spell(8998, 9000, 9892, 31709),
}

-- ============================================================================
-- BEAR ABILITIES
-- ============================================================================
local BearAbilities = {
    MangleBear = izi.spell(33878, 33986, 33987),
    Maul = izi.spell(6807, 6808, 6809, 8972, 8974, 9880, 9881, 26996, 26997),
    Swipe = izi.spell(779, 780, 769, 9754, 9908, 26997, 26998),
    Lacerate = izi.spell(33745, 33986, 33987),
    FrenziedRegeneration = izi.spell(22842, 22895, 22896, 26999),
    Enrage = izi.spell(5229),
    DemoralizingRoar = izi.spell(99, 1735, 9490, 9747, 9898, 26998),
    Growl = izi.spell(6795),
    ChallengingRoar = izi.spell(5209),
    FeralChargeBear = izi.spell(16979),
}

-- ============================================================================
-- BALANCE ABILITIES
-- ============================================================================
local BalanceAbilities = {
    FaerieFireCaster = izi.spell(770, 778, 9749, 9907, 26993),
    Moonfire = izi.spell(8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835, 26987, 26988),
    Starfire = izi.spell(2912, 8949, 8950, 8951, 9875, 9876, 25298, 26986),
    Wrath = izi.spell(5176, 5177, 5178, 5179, 5180, 6780, 8905, 9912, 26984, 26985),
    InsectSwarm = izi.spell(5570, 24974, 24975, 24976, 24977, 27013),
    Hurricane = izi.spell(16914, 17401, 17402, 27012),
    ForceOfNature = izi.spell(33831),
}

-- ============================================================================
-- HEALING SPELLS
-- ============================================================================
local HealingSpells = {
    -- Nature's Swiftness (off-GCD instant cast buff)
    NaturesSwiftness = izi.spell(17116),
    
    -- Swiftmend (consumes Rejuv/Regrowth for instant heal)
    Swiftmend = izi.spell(18562),
    
    -- Lifebloom (rolling HoT, stack to 3)
    Lifebloom = izi.spell(33763),
    
    -- Tranquility (raid channel heal)
    Tranquility = izi.spell(740, 8918, 9862, 9863, 26983),
}

-- ============================================================================
-- HEALING TOUCH RANKS (13 total, high to low)
-- ============================================================================
local HealingTouchRanks = {
    izi.spell(26979), -- Rank 13 (max)
    izi.spell(26978), -- Rank 12
    izi.spell(25297), -- Rank 11
    izi.spell(9889),  -- Rank 10
    izi.spell(9888),  -- Rank 9
    izi.spell(9758),  -- Rank 8
    izi.spell(8903),  -- Rank 7
    izi.spell(6778),  -- Rank 6
    izi.spell(5189),  -- Rank 5
    izi.spell(5188),  -- Rank 4
    izi.spell(5187),  -- Rank 3
    izi.spell(5186),  -- Rank 2
    izi.spell(5185),  -- Rank 1
}

-- ============================================================================
-- REGROWTH RANKS (10 total)
-- ============================================================================
local RegrowthRanks = {
    izi.spell(26980), -- Rank 10 (max)
    izi.spell(9858),  -- Rank 9
    izi.spell(9857),  -- Rank 8
    izi.spell(9856),  -- Rank 7
    izi.spell(9750),  -- Rank 6
    izi.spell(8941),  -- Rank 5
    izi.spell(8940),  -- Rank 4
    izi.spell(8939),  -- Rank 3
    izi.spell(8938),  -- Rank 2
    izi.spell(8936),  -- Rank 1
}

-- ============================================================================
-- REJUVENATION RANKS (13 total)
-- ============================================================================
local RejuvenationRanks = {
    izi.spell(26982), -- Rank 13 (max)
    izi.spell(26981), -- Rank 12
    izi.spell(25299), -- Rank 11
    izi.spell(9841),  -- Rank 10
    izi.spell(9840),  -- Rank 9
    izi.spell(9839),  -- Rank 8
    izi.spell(8910),  -- Rank 7
    izi.spell(3627),  -- Rank 6
    izi.spell(2091),  -- Rank 5
    izi.spell(2090),  -- Rank 4
    izi.spell(1430),  -- Rank 3
    izi.spell(1058),  -- Rank 2
    izi.spell(774),   -- Rank 1
}

-- ============================================================================
-- UTILITY / CC
-- ============================================================================
local Utility = {
    RemoveCurse = izi.spell(2782),
    AbolishPoison = izi.spell(2893),
    Innervate = izi.spell(29166),
    Barkskin = izi.spell(22812),
    EntanglingRoots = izi.spell(339, 1062, 5195, 5196, 9852, 9853, 26989),
    Cyclone = izi.spell(33786),
    Bash = izi.spell(5211, 6798, 8983),
    Maim = izi.spell(22570, 4980),
    NaturesGrasp = izi.spell(16689, 16810, 16811, 16812, 16813, 17329, 27009),
    Hibernate = izi.spell(2637, 18657, 18658),
}

-- ============================================================================
-- HEALING ITEMS
-- ============================================================================
local HealingItems = {
    HealthstoneMaster = izi.item(22105),
    HealthstoneMajor = izi.item(22104),
    SuperHealingPotion = izi.item(22829),
    MajorHealingPotion = izi.item(13446),
}

-- ============================================================================
-- MANA ITEMS
-- ============================================================================
local ManaItems = {
    SuperManaPotion = izi.item(22832),
    DarkRune = izi.item(20520),
    DemonicRune = izi.item(12662),
}

-- ============================================================================
-- DAMAGE ITEMS (Sapper Charges)
-- ============================================================================
local DamageItems = {
    GoblinSapperCharge = izi.item(10646),
    SuperSapperCharge = izi.item(23827),
}

-- ============================================================================
-- AGGREGATED SPELLS TABLE (for easy access)
-- ============================================================================
local Spells = {
    -- Categories
    Racials = Racials,
    SelfBuffs = SelfBuffs,
    SelfUtility = SelfUtility,
    Forms = Forms,
    Cat = CatAbilities,
    Bear = BearAbilities,
    Balance = BalanceAbilities,
    Healing = HealingSpells,
    HealingTouchRanks = HealingTouchRanks,
    RegrowthRanks = RegrowthRanks,
    RejuvenationRanks = RejuvenationRanks,
    Utility = Utility,
    HealingItems = HealingItems,
    ManaItems = ManaItems,
    DamageItems = DamageItems,
}

-- Flatten for direct access (convenience)
for k, v in pairs(Racials) do Spells[k] = v end
for k, v in pairs(SelfBuffs) do Spells[k] = v end
for k, v in pairs(SelfUtility) do Spells[k] = v end
for k, v in pairs(Forms) do Spells[k] = v end
for k, v in pairs(CatAbilities) do Spells[k] = v end
for k, v in pairs(BearAbilities) do Spells[k] = v end
for k, v in pairs(BalanceAbilities) do Spells[k] = v end
for k, v in pairs(HealingSpells) do Spells[k] = v end
for k, v in pairs(Utility) do Spells[k] = v end
for k, v in pairs(HealingItems) do Spells[k] = v end
for k, v in pairs(ManaItems) do Spells[k] = v end
for k, v in pairs(DamageItems) do Spells[k] = v end

return Spells
