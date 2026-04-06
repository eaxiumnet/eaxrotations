-- =============================================================================
-- DRUID MAIN ROTATION - SYLVANAS FRAMEWORK
-- Consolidated standalone plugin with all rotations
-- Includes: Cat (Feral DPS), Bear (Guardian Tank), Balance (Moonkin), Resto (Healer)
-- =============================================================================

local core = _G.core
local izi = require("izi_sdk")
local FluxCompat = require("flux_compat")
local SettingsBridge = require("settings_bridge")

-- Initialize settings bridge
SettingsBridge:init("druid_rotation_settings")

-- Settings accessor
local function s(key, default)
    return SettingsBridge:get(key, default)
end

-- =============================================================================
-- SPELL DEFINITIONS
-- =============================================================================
local Spells = {
    -- Racials
    Berserking = izi.spell(26297),
    BloodFury = izi.spell(33697),

    -- Self Buffs
    SelfMarkOfTheWild = izi.spell(1126),
    SelfThorns = izi.spell(467),
    SelfOmenOfClarity = izi.spell(16864),

    -- Self-cast utility
    SelfRemoveCurse = izi.spell(2782),
    SelfAbolishPoison = izi.spell(2893),
    SelfInnervate = izi.spell(29166),
    SelfBarkskin = izi.spell(22812),

    -- Forms
    CatForm = izi.spell(768),
    BearForm = izi.spell(9634),
    MoonkinForm = izi.spell(24858),
    TravelForm = izi.spell(783),
    TreeOfLifeForm = izi.spell(33891),

    -- Cat Abilities
    Rake = izi.spell(1822),
    Rip = izi.spell(1079),
    FerociousBite = izi.spell(22568),
    Shred = izi.spell(5221),
    MangleCat = izi.spell(33876),
    TigersFury = izi.spell(5217),
    Prowl = izi.spell(5215),
    Ravage = izi.spell(6785),
    Pounce = izi.spell(27006),
    Dash = izi.spell(33357),
    FaerieFire = izi.spell(16857),
    Cower = izi.spell(8998),

    -- Bear Abilities
    MangleBear = izi.spell(33878),
    Maul = izi.spell(6807),
    Swipe = izi.spell(779),
    Lacerate = izi.spell(33745),
    FrenziedRegeneration = izi.spell(22842),
    Enrage = izi.spell(5229),
    DemoralizingRoar = izi.spell(99),
    Growl = izi.spell(6795),
    ChallengingRoar = izi.spell(5209),
    FeralChargeBear = izi.spell(16979),

    -- Balance Abilities
    FaerieFireCaster = izi.spell(770),
    Moonfire = izi.spell(8921),
    Starfire = izi.spell(2912),
    Wrath = izi.spell(5176),
    InsectSwarm = izi.spell(5570),
    Hurricane = izi.spell(16914),
    ForceOfNature = izi.spell(33831),

    -- Healing
    NaturesSwiftness = izi.spell(17116),
    Swiftmend = izi.spell(18562),
    Lifebloom = izi.spell(33763),
    Tranquility = izi.spell(740),

    -- Healing Touch ranks
    HealingTouch = izi.spell(26979, 26978, 25297, 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185),

    -- Regrowth ranks
    Regrowth = izi.spell(26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936),

    -- Rejuvenation ranks
    Rejuvenation = izi.spell(26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774),

    -- Utility
    RemoveCurse = izi.spell(2782),
    AbolishPoison = izi.spell(2893),
    Innervate = izi.spell(29166),
    Barkskin = izi.spell(22812),
    EntanglingRoots = izi.spell(339),

    -- CC / Utility
    Cyclone = izi.spell(33786),
    Bash = izi.spell(8983),
    Maim = izi.spell(22570),
    NaturesGrasp = izi.spell(27009),
    Hibernate = izi.spell(18658),
    SurvivalInstincts = izi.spell(50322),
    Berserk = izi.spell(50334),

    -- Items
    HealthstoneMaster = izi.item(22105),
    HealthstoneMajor = izi.item(22104),
    SuperHealingPotion = izi.item(22829),
    MajorHealingPotion = izi.item(13446),
    SuperManaPotion = izi.item(22832),
    DarkRune = izi.item(20520),
    DemonicRune = izi.item(12662),
    GoblinSapperCharge = izi.item(10646),
    SuperSapperCharge = izi.item(23827),
}

-- =============================================================================
-- CONSTANTS
-- =============================================================================
local Constants = {
    STANCE = {
        CASTER = 0,
        BEAR = 1,
        CAT = 3,
        TRAVEL = 4,
        MOONKIN = 5,
        TREE = 5,
    },

    BUFF_ID = {
        CLEARCASTING = 16870,
        NATURES_GRACE = 16886,
        TIGERS_FURY = 5217,
        OOMEN_OF_CLARITY = 16864,
    },

    DEBUFF_ID = {
        FAERIE_FIRE = 16857,
        MOONFIRE = 8921,
        INSECT_SWARM = 5570,
        RIP = 1079,
        RAKE = 1822,
        MANGLE = 33876,
        LACERATE = 33745,
        DEMO_ROAR = 99,
    },

    TTD = {
        RIP_MIN = 10,
        RAKE_MIN = 6,
        BITE_EXECUTE = 6,
        SHORT_FIGHT = 10,
        FORCE_OF_NATURE_MIN = 15,
    },

    ENERGY = {
        CRITICAL = 10,
        CRITICAL_SHIFT = 15,
        MANGLE_POOL = 20,
        BITE_TRICK_MAX = 39,
        RAKE_TRICK_MIN = 35,
        EARLY_SHIFT = 20,
        EARLY_SHIFT_WOLFSHEAD = 25,
        TICK_INTERVAL = 2.0,
    },

    POWERSHIFT = {
        FUROR_ENERGY = 40,
        WOLFSHEAD_BONUS = 20,
        MIN_SHIFT_ENERGY_GAIN = 20,
    },

    HP = {
        EXECUTE = 25,
    },

    DURATION = {
        BITE_MIN_RIP = 3,
    },

    AOE = {
        RAKE_SPREAD_NEARBY = 8,
        HURRICANE_MIN_TARGETS = 3,
    },

    BALANCE = {
        FAERIE_FIRE_REFRESH = 3,
        MANA_TIER1 = 20,
        MANA_TIER2 = 10,
        MANA_LOW = 20,
    },

    BEAR = {
        MANGLE_CD = 6,
        LACERATE_MAX_STACKS = 5,
        LACERATE_DURATION = 15,
        LACERATE_URGENT_REFRESH = 3,
        LACERATE_SWIPE_THRESHOLD = 3,
        DEMO_ROAR_DURATION = 30,
        DEMO_ROAR_REFRESH = 5,
        DEFAULT_MAUL_RAGE = 25,
        DEFAULT_SWIPE_RAGE = 15,
        DEFAULT_SWIPE_TARGETS = 3,
        ENRAGE_RAGE_THRESHOLD = 20,
        DEMO_ROAR_MIN_TTD = 8,
        GROWL_MIN_TTD = 4,
        GROWL_CC_THRESHOLD = 2,
        ENRAGE_HP_SAFETY = 50,
        MAUL_AOE_EXTRA_RAGE = 15,
        FRENZIED_PROACTIVE_HP = 50,
        FRENZIED_PROACTIVE_RAGE = 50,
        DEFAULT_DEMO_ROAR_RANGE = 10,
        DEFAULT_DEMO_ROAR_MIN_BOSSES = 1,
        DEFAULT_DEMO_ROAR_MIN_ELITES = 2,
        DEFAULT_DEMO_ROAR_MIN_TRASH = 5,
        DEFAULT_CROAR_RANGE = 10,
        DEFAULT_CROAR_MIN_BOSSES = 1,
        DEFAULT_CROAR_MIN_ELITES = 3,
    },

    RESTO = {
        EMERGENCY_HP = 30,
        TANK_HEAL_HP = 50,
        STANDARD_HEAL_HP = 80,
        PROACTIVE_HP = 90,
        LIFEBLOOM_REFRESH = 2,
        SWIFTMEND_HP = 50,
    },

    -- Buff/Debuff ID arrays
    MOTW_BUFF_IDS = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 21849, 21850, 26991 },
    THORNS_BUFF_IDS = { 467, 782, 1075, 8914, 9756, 9910, 26992 },
    TIGERS_FURY_BUFF_IDS = { 5217, 6793, 9845, 9846 },
}

-- =============================================================================
-- MENU ELEMENTS (Sylvanas OO API - declared outside callback)
-- =============================================================================
local menu_main_node = core.menu.tree_node()
local menu_general_node = core.menu.tree_node()
local cb_faerie_fire = core.menu.checkbox(true, "druid_maintain_faerie_fire")
local cb_rip = core.menu.checkbox(true, "druid_maintain_rip")
local cb_rake = core.menu.checkbox(true, "druid_maintain_rake")
local cb_frenzied_regen = core.menu.checkbox(true, "druid_use_frenzied_regen")
local cb_growl = core.menu.checkbox(true, "druid_use_growl")
local cb_lacerate = core.menu.checkbox(true, "druid_maintain_lacerate")
local cb_force_of_nature = core.menu.checkbox(true, "druid_use_force_of_nature")
local cb_moonfire = core.menu.checkbox(true, "druid_maintain_moonfire")
local cb_insect_swarm = core.menu.checkbox(true, "druid_maintain_insect_swarm")

-- =============================================================================
-- HEALING DATA TABLES
-- =============================================================================
local HealingData = {
    HEALING_TOUCH_RANKS = {
        {rank = 13, heal = 2908},
        {rank = 12, heal = 2472},
        {rank = 11, heal = 2060},
        {rank = 10, heal = 1890},
        {rank = 9, heal = 1730},
        {rank = 8, heal = 1590},
        {rank = 7, heal = 1440},
        {rank = 6, heal = 1290},
        {rank = 5, heal = 1000},
        {rank = 4, heal = 750},
        {rank = 3, heal = 450},
        {rank = 2, heal = 200},
        {rank = 1, heal = 40},
    },

    REGROWTH_RANKS = {
        {rank = 10, heal = 1142},
        {rank = 9, heal = 1003},
        {rank = 8, heal = 897},
        {rank = 7, heal = 803},
        {rank = 6, heal = 721},
        {rank = 5, heal = 650},
        {rank = 4, heal = 556},
        {rank = 3, heal = 256},
        {rank = 2, heal = 162},
        {rank = 1, heal = 93},
    },

    REJUVENATION_RANKS = {
        {rank = 13, heal = 1344},
        {rank = 12, heal = 1192},
        {rank = 11, heal = 1060},
        {rank = 10, heal = 972},
        {rank = 9, heal = 888},
        {rank = 8, heal = 820},
        {rank = 7, heal = 756},
        {rank = 6, heal = 608},
        {rank = 5, heal = 488},
        {rank = 4, heal = 304},
        {rank = 3, heal = 180},
        {rank = 2, heal = 84},
        {rank = 1, heal = 32},
    },
}

-- =============================================================================
-- CONTEXT BUILDER
-- =============================================================================
local function get_current_stance()
    local me = izi.me()
    if not me then return 0 end
    
    if me:buff_up(768) then return 3
    elseif me:buff_up(9634) then return 1
    elseif me:buff_up(24858) then return 5
    elseif me:buff_up(33891) then return 5
    elseif me:buff_up(783) then return 4
    else return 0 end
end

local function build_context()
    local ctx = FluxCompat.build_context()
    if not ctx then return nil end

    local me = ctx.me
    local target = ctx.target
    local stance = get_current_stance()

    ctx.stance = stance
    ctx.is_stealthed = me:buff_up(5215) or me:buff_up(6783)

    if stance == Constants.STANCE.CAT then
        ctx.energy = me:power_current()
        ctx.cp = me:combo_points()
    elseif stance == Constants.STANCE.BEAR then
        ctx.rage = me:power_current()
    else
        ctx.mana_pct = me:mana_pct()
        ctx.mana = me:mana_current()
    end

    ctx.is_behind = target and target:is_behind() or false
    ctx.has_clearcasting = me:buff_up(Constants.BUFF_ID.CLEARCASTING)
    ctx.enemy_count = (target and target:is_valid()) and 1 or 0

    if target and target:is_valid() then
        ctx.is_boss = target:is_dummy() or target:get_classification() == "worldboss"
        ctx.target_phys_immune = target:debuff_up(45438) or target:debuff_up(642)
    end

    ctx.settings = {
        maintain_faerie_fire = cb_faerie_fire:get_state(),
        maintain_rip = cb_rip:get_state(),
        maintain_rake = cb_rake:get_state(),
        use_frenzied_regen = cb_frenzied_regen:get_state(),
        use_growl = cb_growl:get_state(),
        maintain_lacerate = cb_lacerate:get_state(),
        use_force_of_nature = cb_force_of_nature:get_state(),
        maintain_moonfire = cb_moonfire:get_state(),
        maintain_insect_swarm = cb_insect_swarm:get_state(),
    }
    return ctx
end

-- =============================================================================
-- CAT (FERAL DPS) ROTATION
-- =============================================================================
local CatRotation = {}

local ENERGY_COST_RIP = 30
local ENERGY_COST_RAKE = 35
local ENERGY_COST_MANGLE = 40
local ENERGY_COST_SHRED = 42
local ENERGY_COST_BITE = 35
local ENERGY_COST_RAVAGE = 60

function CatRotation.execute(ctx)
    local settings = ctx.settings
    local energy = ctx.energy or 0
    local cp = ctx.cp or 0
    local me = ctx.me
    local target = ctx.target

    if not target or not target:is_valid() then return nil end

    -- Faerie Fire
    if settings.maintain_faerie_fire ~= "off" then
        local ff_duration = target:debuff_remains(Constants.DEBUFF_ID.FAERIE_FIRE)
        if ff_duration <= 0 then
            if Spells.FaerieFire:is_castable_to(target) then
                return Spells.FaerieFire:cast(target, "[FF] Faerie Fire")
            end
        end
    end

    -- [P2] Rip
    if settings.maintain_rip then
        local rip_duration = target:debuff_remains(Constants.DEBUFF_ID.RIP)
        local rip_min_cp = settings.rip_min_cp or 4
        if cp >= rip_min_cp and rip_duration <= 0 and not ctx.target_phys_immune then
            if energy >= ENERGY_COST_RIP or ctx.has_clearcasting then
                if Spells.Rip:is_castable_to(target) then
                    return Spells.Rip:cast(target, "[P2] Rip - Finisher")
                end
            end
        end
    end

    -- [P3] Ferocious Bite
    if cp >= 5 then
        if energy >= ENERGY_COST_BITE then
            if Spells.FerociousBite:is_castable_to(target) then
                return Spells.FerociousBite:cast(target, "[P3] Ferocious Bite")
            end
        end
    end

    -- [P4] Rake
    if settings.maintain_rake then
        local rake_duration = target:debuff_remains(Constants.DEBUFF_ID.RAKE)
        if rake_duration <= 0 and cp <= 4 then
            if energy >= ENERGY_COST_RAKE then
                if Spells.Rake:is_castable_to(target) then
                    return Spells.Rake:cast(target, "[P4] Rake - DoT")
                end
            end
        end
    end

    -- [P8] Shred
    if cp < 5 and ctx.is_behind then
        if energy >= ENERGY_COST_SHRED then
            if Spells.Shred:is_castable_to(target) then
                return Spells.Shred:cast(target, "[P8] Shred - Builder")
            end
        end
    end

    -- [P9] Mangle Builder
    if cp < 5 and (not ctx.is_behind or energy < ENERGY_COST_SHRED) then
        if energy >= ENERGY_COST_MANGLE or ctx.has_clearcasting then
            if Spells.MangleCat:is_castable_to(target) then
                return Spells.MangleCat:cast(target, "[P9] Mangle - Builder")
            end
        end
    end

    return nil
end

-- =============================================================================
-- BEAR (GUARDIAN TANK) ROTATION
-- =============================================================================
local BearRotation = {}

local RAGE_COST_MANGLE = 20
local RAGE_COST_MAUL = 15
local RAGE_COST_SWIPE = 15
local RAGE_COST_LACERATE = 13

function BearRotation.execute(ctx)
    local settings = ctx.settings
    local rage = ctx.rage or 0
    local target = ctx.target

    if not target or not target:is_valid() then return nil end

    -- [1] Frenzied Regeneration
    if settings.use_frenzied_regen and rage >= 10 then
        if ctx.hp <= 30 then
            if Spells.FrenziedRegeneration:is_usable() then
                return Spells.FrenziedRegeneration:cast(izi.me(), "[P2] Frenzied Regen - Emergency")
            end
        end
    end

    -- [3] Growl
    if settings.use_growl and not settings.bear_no_taunt then
        local threat = target.threat and target:threat() or 0
        if threat < 2 then
            if Spells.Growl:is_castable_to(target) then
                return Spells.Growl:cast(target, "[P3] Growl - Taunt")
            end
        end
    end

    -- [P10] Mangle
    if not ctx.target_phys_immune then
        if rage >= RAGE_COST_MANGLE or ctx.has_clearcasting then
            if Spells.MangleBear:is_castable_to(target) then
                return Spells.MangleBear:cast(target, "[P10] Mangle")
            end
        end
    end

    -- [P11] Lacerate
    if settings.maintain_lacerate and not ctx.target_phys_immune then
        local stacks = target:debuff_stacks(Constants.DEBUFF_ID.LACERATE)
        local duration = target:debuff_remains(Constants.DEBUFF_ID.LACERATE)
        if stacks < 5 or duration <= 3 then
            if rage >= RAGE_COST_LACERATE or ctx.has_clearcasting then
                if Spells.Lacerate:is_castable_to(target) then
                    return Spells.Lacerate:cast(target, "[P12] Lacerate - Stack/Refresh")
                end
            end
        end
    end

    return nil
end

-- =============================================================================
-- BALANCE (MOONKIN) ROTATION
-- =============================================================================
local BalanceRotation = {}

function BalanceRotation.execute(ctx)
    local settings = ctx.settings
    local me = ctx.me
    local target = ctx.target

    if ctx.stance ~= Constants.STANCE.MOONKIN then return nil end
    if not target or not target:is_valid() then return nil end

    -- Check magic immunity
    local magic_immune = target:debuff_up(45438) or target:debuff_up(642)
    if magic_immune then return nil end

    -- [1] Faerie Fire
    if settings.maintain_faerie_fire ~= "off" then
        local ff_duration = target:debuff_remains(Constants.DEBUFF_ID.FAERIE_FIRE)
        if ff_duration <= Constants.BALANCE.FAERIE_FIRE_REFRESH then
            if Spells.FaerieFireCaster:is_castable_to(target) then
                return Spells.FaerieFireCaster:cast(target, "[P1] Faerie Fire")
            end
        end
    end

    -- [2] Force of Nature
    if settings.use_force_of_nature then
        if ctx.ttd > Constants.TTD.FORCE_OF_NATURE_MIN then
            if Spells.ForceOfNature:is_castable_to(target) then
                return Spells.ForceOfNature:cast(target, "[P2] Force of Nature")
            end
        end
    end

    -- [4] AoE Hurricane
    if ctx.enemy_count >= Constants.AOE.HURRICANE_MIN_TARGETS then
        if Spells.Hurricane:is_castable_to(target) then
            return Spells.Hurricane:cast(target, "[P4] Hurricane - AoE")
        end
    end

    -- DoT maintenance
    if settings.maintain_insect_swarm then
        local is_duration = target:debuff_remains(Constants.DEBUFF_ID.INSECT_SWARM)
        if is_duration <= 0 then
            if Spells.InsectSwarm:is_castable_to(target) then
                return Spells.InsectSwarm:cast(target, "[P4] Insect Swarm")
            end
        end
    end

    if settings.maintain_moonfire then
        local mf_duration = target:debuff_remains(Constants.DEBUFF_ID.MOONFIRE)
        if mf_duration <= 0 then
            if Spells.Moonfire:is_castable_to(target) then
                return Spells.Moonfire:cast(target, "[P5] Moonfire")
            end
        end
    end

    -- [P6] Starfire primary nuke
    if Spells.Starfire:is_castable_to(target) then
        return Spells.Starfire:cast(target, "[P6] Starfire")
    end

    -- [P7] Wrath fallback
    if Spells.Wrath:is_castable_to(target) then
        return Spells.Wrath:cast(target, "[P7] Wrath")
    end

    return nil
end

-- =============================================================================
-- RESTO (TREE OF LIFE) ROTATION
-- =============================================================================
local RestoRotation = {}

function RestoRotation.execute(ctx)
    local settings = ctx.settings
    local me = ctx.me

    if ctx.stance ~= Constants.STANCE.TREE then return nil end

    -- [1] Emergency Healing (self)
    if ctx.hp <= 30 then
        if not me:buff_up(Spells.Rejuvenation:id()) then
            if Spells.Rejuvenation:is_usable() then
                return Spells.Rejuvenation:cast(izi.me(), "[HEAL] Emergency Rejuvenation")
            end
        end
        if Spells.HealingTouch:is_usable() then
            return Spells.HealingTouch:cast(izi.me(), "[HEAL] Emergency Healing Touch")
        end
    end

    -- [6] Self-Buffs (out of combat only)
    if not ctx.in_combat then
        if settings.use_motw then
            local has_motw = false
            for _, id in ipairs(Constants.MOTW_BUFF_IDS) do
                if me:buff_up(id) then has_motw = true break end
            end
            if not has_motw and Spells.SelfMarkOfTheWild:is_usable() then
                return Spells.SelfMarkOfTheWild:cast(izi.me(), "[BUFF] Mark of the Wild")
            end
        end

        if settings.use_thorns then
            local has_thorns = false
            for _, id in ipairs(Constants.THORNS_BUFF_IDS) do
                if me:buff_up(id) then has_thorns = true break end
            end
            if not has_thorns and Spells.SelfThorns:is_usable() then
                return Spells.SelfThorns:cast(izi.me(), "[BUFF] Thorns")
            end
        end
    end

    return nil
end

-- =============================================================================
-- MAIN ROTATION EXECUTION
-- =============================================================================
local function execute_rotation()
    local ctx = build_context()
    if not ctx then return nil end

    local cast = nil

    -- Route to appropriate rotation based on stance/spec
    if ctx.stance == Constants.STANCE.CAT then
        cast = CatRotation.execute(ctx)
    elseif ctx.stance == Constants.STANCE.BEAR then
        cast = BearRotation.execute(ctx)
    elseif ctx.stance == Constants.STANCE.MOONKIN then
        cast = BalanceRotation.execute(ctx)
    elseif ctx.stance == Constants.STANCE.TREE then
        cast = RestoRotation.execute(ctx)
    end

    return cast
end

-- =============================================================================
-- MENU REGISTRATION (Sylvanas OO API)
-- =============================================================================
core.register_on_render_menu_callback(function()
  menu_main_node:render("Druid Rotations", function()
    menu_general_node:render("General", function()
      cb_faerie_fire:render("Maintain Faerie Fire")
      cb_rip:render("Maintain Rip (Cat)")
      cb_rake:render("Maintain Rake (Cat)")
      cb_frenzied_regen:render("Use Frenzied Regen (Bear)")
      cb_growl:render("Use Growl (Bear)")
      cb_lacerate:render("Maintain Lacerate (Bear)")
      cb_force_of_nature:render("Use Force of Nature (Balance)")
      cb_moonfire:render("Maintain Moonfire (Balance)")
      cb_insect_swarm:render("Maintain Insect Swarm (Balance)")
    end)
  end)
end)

-- =============================================================================
-- UPDATE CALLBACK
-- =============================================================================
core.register_on_update_callback(function()
    execute_rotation()
end)

core.log("Druid Rotations v1.8.10 loaded - Cat/Bear/Balance/Resto")


