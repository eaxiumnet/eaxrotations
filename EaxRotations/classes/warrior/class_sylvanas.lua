-- Readability notes:
--   What: Warrior spell table, playstyle config, and child module loader.
--   When: main.lua loads the active player's class module.
--   Why: every spec shares one audited spell map and one safe require path.
--   Safety: child module failures are logged instead of crashing startup.

-- Decision notes:
--   Class module is the single spell map and playstyle registry for this class.
--   Spell IDs are ranked newest-to-oldest so runtime resolution can pick the best learned TBC rank.
--   Child modules load with pcall so one broken playstyle logs cleanly instead of preventing the whole class from loading.
local NS = _G.EaxRotations
if not NS then return nil end
local enums = require("common/enums")
if type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
local player = NS.GetPlayer()
if not player or player:get_class() ~= enums.class_id.WARRIOR then return nil end

local SPELLS = {
    BattleShout = NS.spell_action({ 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
    BattleStance = NS.spell_action({ 2457 }, "BattleStance"),
    BerserkerRage = NS.spell_action({ 18499 }, "BerserkerRage"),
    BerserkerStance = NS.spell_action({ 2458 }, "BerserkerStance"),
    Bloodrage = NS.spell_action({ 2687 }, "Bloodrage"),
    Bloodthirst = NS.spell_action({ 30335, 25251, 23894, 23893, 23892, 23881 }, "Bloodthirst"),
    Cleave = NS.spell_action({ 25231, 20569, 11609, 11608, 7369, 845 }, "Cleave"),
    CommandingShout = NS.spell_action({ 469 }, "CommandingShout"),
    DeathWish = NS.spell_action(12292, "DeathWish"),
    DefensiveStance = NS.spell_action({ 71 }, "DefensiveStance"),
    DemoralizingShout = NS.spell_action({ 25203, 25202, 11556, 11555, 11554, 6190, 1160 }, "DemoralizingShout"),
    Devastate = NS.spell_action({ 30022, 30016, 20243 }, "Devastate"),
    Execute = NS.spell_action({ 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
    VictoryRush = NS.spell_action({ 34428 }, "VictoryRush"),
    HeroicStrike = NS.spell_action({ 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    Hamstring = NS.spell_action({ 25212, 1715 }, "Hamstring"),
    Intercept = NS.spell_action({ 25275, 20617, 20616, 20252 }, "Intercept"),
    Pummel = NS.spell_action({ 30030, 20617 }, "Pummel"),
    LastStand = NS.spell_action({ 12975 }, "LastStand"),
    MortalStrike = NS.spell_action({ 30330, 25248, 21553, 21552, 21551, 12294 }, "MortalStrike"),
    Overpower = NS.spell_action({ 11585, 7887, 7384 }, "Overpower"),
    Rampage = NS.spell_action({ 30033, 30032, 30030 }, "Rampage"),
    Revenge = NS.spell_action({ 30357, 25269, 25288, 11601, 11600, 7379, 6574, 6572 }, "Revenge"),
    ShieldBlock = NS.spell_action(2565, "ShieldBlock"),
    ShieldSlam = NS.spell_action({ 30356, 25258, 23925, 23924, 23923, 23922 }, "ShieldSlam"),
    ShieldWall = NS.spell_action({ 871 }, "ShieldWall"),
    SunderArmor = NS.spell_action({ 25225, 11597, 11596, 8380, 7405, 7386 }, "SunderArmor"),
    SweepingStrikes = NS.spell_action(12328, "SweepingStrikes"),
    Taunt = NS.spell_action({ 355 }, "Taunt"),
    ThunderClap = NS.spell_action({ 25264, 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),

    Whirlwind = NS.spell_action({ 1680 }, "Whirlwind"),
}
NS.WarriorSpells = SPELLS

NS.WarriorConstants = {
    STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    BUFF_ID = { SWEEPING_STRIKES = 12328 },
    SUNDER_DEBUFF = { 25225, 11597, 11596, 8380, 7405, 7386 },
    THUNDER_CLAP_DEBUFF = { 25264, 11581, 11580, 8205, 8204, 8198, 6343 },
    DEMO_SHOUT_DEBUFF = { 25202, 11556, 11555, 11554, 6190, 1160 },
    BATTLE_SHOUT_IDS = { 6673, 11549, 11550, 11551, 25289, 2048 },
    COMMANDING_SHOUT_BUFF = { 469 },
}

local config = {
    class_key = "warrior",
    class_name = "Warrior",
    default_playstyle = "arms",
    playstyles = {
        { name = "arms", display_name = "Arms" },
        { name = "fury", display_name = "Fury" },
        { name = "kebab", display_name = "Kebab" },
        { name = "protection", display_name = "Protection" },
    },
}
NS.rotation_registry:set_class_config(config)

local function load_child(name)
    local ok, result = pcall(require, "classes/warrior/" .. name)
    if not ok then NS.log_warning("Warrior module skipped: " .. tostring(name) .. " -> " .. tostring(result)) end
    return ok and result or nil
end

load_child("middleware_sylvanas")
load_child("arms_sylvanas")
load_child("fury_sylvanas")
load_child("kebab_sylvanas")
load_child("protection_sylvanas")
NS.log("Warrior class module loaded")
return config
