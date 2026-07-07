-- Regression test: paladin vanilla specs Pattern 14 nil-guards.
-- Covers: holy_vanilla, protection_vanilla, retribution_vanilla, leveling_vanilla.
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local failures, total_tests, total_passed = {}, 0, 0

local function expect_no_crash(label, fn)
    total_tests = total_tests + 1
    local ok, err = pcall(fn)
    if ok then total_passed = total_passed + 1
    else failures[#failures + 1] = { label = label, error = err } end
end

_G.EaxRotations = {
    action_matches = function() return true end,
    action_execute = function() return true end,
    PaladinSpells = {
        AvengingWrath = 31884, BlessingOfFreedom = 1044, BlessingOfKings = 20217,
        BlessingOfLight = 19977, BlessingOfMight = 19740, BlessingOfProtection = 1022,
        BlessingOfSanctuary = 20911, BlessingOfWisdom = 19742, Cleanse = 4987,
        Consecration = 26573, DevotionAura = 465, DivineFavor = 20216,
        DivineShield = 642, Exorcism = 879, FlashOfLight = 19750, HammerOfJustice = 853,
        HammerOfWrath = 24275, HolyLight = 635, HolyShock = 20473, HolyWrath = 2812,
        Judgement = 20271, LayOnHands = 733, Purify = 1152, RetributionAura = 7294,
        RighteousFury = 25780, SealOfCommand = 20375, SealOfRighteousness = 21084,
        SealOfWisdom = 20166, SealOfLight = 20165, SealOfJustice = 20164,
        SealOfTheCrusader = 20164, SenseUndead = 5502,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return nil end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    debuff_stacks = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    has_player_buff = function() return false end,
    buff_stacks = function() return 0 end,
    has_form = function() return false end,
    is_vanilla = function() return true end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    time_now = function() return 0 end,
    setting = function(ctx, key, default)
        local s = ctx and ctx.settings
        if s and s[key] ~= nil then return s[key] end return default end,
    same_unit = function() return false end,
    mana_pct = function() return 80 end,
    CLASS_ID = { PALADIN = 2, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, WARRIOR = 1, ROGUE = 4, HUNTER = 3, DRUID = 11 },
    healing_entries = function() return {} end,
    healing_lowest = function() return nil end,
    get_setting = function(key, default) return default end,
    get_friendly_target_entry = function() return nil end,
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {}, MANA_POTION_IDS = {} }
package.loaded["shared/tbc_data_sylvanas"] =
    { ITEMS = { healthstones = {}, potions = {} }, SPELLS = {} }
package.loaded["shared/leveling_sylvanas"] = {
    create_context_guard = function() return function() return true end end,
    build_common_state = function() end,
    create_wand_matches = function() return function() return false end end,
    execute_wand = function() return false end,
}

print("=== test_paladin_vanilla_nil_guards ===")

local function find_in(strats, name)
    for i = 1, #strats do if strats[i].name == name then return strats[i] end end
    return nil
end

local function test_spec(path, spec_name, strategy_names, ctx, mock_state)
    local strats = dofile(path)
    if type(strats) == "table" and strats.strategies then strats = strats.strategies end
    assert_true(type(strats) == "table", spec_name .. " should load")
    local st = mock_state or {}
    for _, name in ipairs(strategy_names) do
        local s = find_in(strats, name)
        if s then
            expect_no_crash(spec_name .. ": " .. name .. " with minimal context", function()
                return s.matches(ctx, st)
            end)
        end
    end
end

local base_ctx = { in_combat = true, target = {}, me = {}, settings = {}, hp = 80, mana_pct = 80 }
local heal_ctx = { in_combat = true, target = {}, me = {}, settings = {}, hp = 80, mana_pct = 80,
    lowest = { unit = {}, hp_pct = 50 }, party = {}, tank = { unit = {}, hp_pct = 70 } }

-- Holy
test_spec("EaxRotations/classes/paladin/holy_vanilla.lua", "holy_vanilla",
    { "LayOnHandsLastResort", "DivineShieldSelfPreservation", "BlessingOfProtectionFocusedAlly", "CleanseTankPriority", "PurifySelf", "CleanseParty", "BlessingOfFreedomSnare", "DivineFavor", "HolyShock", "HolyLightEmergency", "DivineFavorHolyLightFollowup", "FriendlyTarget", "BlessingOfSacrificeTank", "ManaPotion", "DarkRune", "AuraManagement", "BlessingRefresh", "BlessingOfLightTank", "TankPreHeal", "SmartHeal" },
    heal_ctx)

-- Protection
test_spec("EaxRotations/classes/paladin/protection_vanilla.lua", "protection_vanilla",
    { "ManaPotion", "RighteousFury", "HolyShield", "Consecration", "Judgement", "SealRighteousness", "HammerOfWrath", "Exorcism", "HolyWrath", "SealOfWisdom", "DevotionAura", "BlessingOfSanctuary", "HolyShock", "FlashOfLight", "HolyLight", "Cleanse", "DivineShield", "LayOnHands", "HammerOfJustice", "BlessingOfProtectionAlly" },
    base_ctx)

-- Retribution
test_spec("EaxRotations/classes/paladin/retribution_vanilla.lua", "retribution_vanilla",
    { "SealTwistPrepCommand", "Consecration" },
    base_ctx)

-- Leveling
test_spec("EaxRotations/classes/paladin/leveling_vanilla.lua", "leveling_vanilla",
    { "BlessingMight", "BlessingWisdom", "DevotionAura", "RetributionAura", "HolyShield", "DivineShield", "Cleanse", "FlashOfLight", "HolyLight", "LayOnHands", "HammerOfJustice", "Judgement", "HammerOfWrath", "Exorcism", "Consecration", "Seal" },
    base_ctx)

-- REPORT
print()
if #failures == 0 then
    print(string.format("PASS test_paladin_vanilla_nil_guards — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_paladin_vanilla_nil_guards — %d/%d passed, %d failures:", total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do print(string.format("  %d. [%s] %s", i, f.label, f.error)) end
    error(string.format("test_paladin_vanilla_nil_guards: %d failure(s)", #failures))
end
