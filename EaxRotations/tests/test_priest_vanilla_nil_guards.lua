-- test_priest_vanilla_nil_guards.lua -- Priest Vanilla-era compatibility nil-guard tests.
-- WHAT:  Priest Vanilla-era compatibility nil-guard tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Validates nil-guard safety on all numeric state reads (Pattern 14).
-- SAFETY: Must pass after any state table change.

-- Regression test: priest vanilla specs Pattern 14 nil-guards.
-- Covers: discipline_vanilla, holy_vanilla, shadow_vanilla, smite_vanilla, leveling_vanilla.
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
    import_helpers = function(...) local ns = _G.EaxRotations; local r = {}; for _, k in ipairs({...}) do r[#r+1] = (ns and ns[k]) or function() return false end end; return unpack(r) end,
    PriestSpells = {
        AbolishDisease = 552, CureDisease = 528, DesperatePrayer = 19236,
        DevouringPlague = 2944, DispelMagic = 528, DivineSpirit = 14752,
        Fade = 586, FearWard = 6346, FlashHeal = 2061, GreaterHeal = 2060,
        HolyFire = 14914, HolyNova = 15237, InnerFire = 588, InnerFocus = 14751,
        Lightwell = 731, ManaBurn = 8129, MindBlast = 8092, MindFlay = 15407,
        PowerInfusion = 10060, PowerWordFortitude = 1244, PowerWordShield = 17,
        PrayerOfHealing = 596, PsychicScream = 8122, Renew = 139,
        Resurrection = 2006, ShackleUndead = 9484, ShadowWordDeath = 32379,
        ShadowWordPain = 589, Shadowform = 15473, Shadowfiend = 34433,
        Silence = 15487, Smite = 585, Starshards = 10797, SurgeOfLight = 33151,
        VampiricEmbrace = 15286, HolyNovaAoE = 15237,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return { get_class = function() return 5 end, get_race_id = function() return 1 end } end,
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
    has_dispel_type_debuff = function() return false end,
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

print("=== test_priest_vanilla_nil_guards ===")

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
local priest_state = { enemy_count = 1, hp = 80, mana_pct = 80,
    psychic_scream_ready = true, fade_ready = true,
    prayer_of_healing_ready = true, subgroup_damaged_count = 0 }
local heal_ctx = { in_combat = true, target = {}, me = {}, settings = {}, hp = 80, mana_pct = 80,
    lowest = { unit = {}, hp_pct = 50 }, party = {}, tank = { unit = {}, hp_pct = 70 } }
local heal_state = { enemy_count = 1, hp = 80, mana_pct = 80,
    subgroup_damaged_count = 0, group_damaged_count = 0,
    prayer_of_healing_ready = true, has_inner_focus = false,
    lowest = { unit = {}, hp_pct = 50, has_renew = false, effective_hp = 50 },
    lowest_hp = 50, tank = { unit = {}, hp_pct = 70 }, tank_hp = 70 }

-- Discipline
test_spec("EaxRotations/classes/priest/discipline_vanilla.lua", "discipline_vanilla",
    { "PowerWordShieldTank", "EmergencyPowerWordShield", "PowerWordShieldLowest", "EmergencyFlashHeal", "FriendlyTarget", "GreaterHeal", "PrayerOfHealing", "RenewTank", "RenewLowest", "InnerFire", "FearWard", "PowerWordFortitude", "DivineSpirit", "PsychicScream", "ShackleUndead", "DispelMagic", "PowerInfusion", "InnerFocus", "StopCast", "PreHeal" },
    heal_ctx, heal_state)

-- Holy
test_spec("EaxRotations/classes/priest/holy_vanilla.lua", "holy_vanilla",
    { "EmergencyPWS", "EmergencyFlashHeal", "FriendlyTarget", "PrayerOfHealing", "InnerFocus", "Lightwell", "GreaterHeal", "FlashHeal", "DesperatePrayer", "DispelMagic", "CureDisease", "AbolishDisease", "RenewTank", "RenewSpread", "IdleSWP", "IdleHolyFire", "IdleSmite", "ManaBelow5Wand", "StopCast" },
    heal_ctx, heal_state)

-- Shadow (PR3: tracker-based SWP maintenance parity added; same strategy names)
test_spec("EaxRotations/classes/priest/shadow_vanilla.lua", "shadow_vanilla",
    { "Shadowform", "Silence", "ManaBelow5Wand", "ShadowWordPain", "VampiricEmbrace", "DevouringPlague", "InnerFocusMindBlast", "MindBlast", "MindFlay", "PsychicScream", "Fade", "DispelMagic", "ShackleUndead", "SWPSpread", "InnerFire", "PowerWordShield", "FlashHeal", "HolyNovaAoE", "RacialBerserking", "RacialBloodFury" },
    base_ctx, priest_state)

-- Smite
test_spec("EaxRotations/classes/priest/smite_vanilla.lua", "smite_vanilla",
    { "InnerFire", "SoloPowerWordShield", "SoloRenew", "SoloPsychicScream", "ShadowfiendMana", "HolyFire", "SurgeOfLightSmite", "ShadowWordPain", "PowerInfusion", "InnerFocus", "Starshards", "DevouringPlague", "MindBlast", "ShadowWordDeath", "HolyNova", "SmiteFiller" },
    base_ctx, priest_state)

-- Leveling
test_spec("EaxRotations/classes/priest/leveling_vanilla.lua", "leveling_vanilla",
    { "PowerWordFortitude", "InnerFire", "Shadowform", "VampiricEmbrace", "PowerWordShield", "Renew", "FlashHeal", "InnerFocus", "GreaterHeal", "DesperatePrayer", "PsychicScream", "Fade", "ShackleUndead", "ShadowWordPain", "HolyFire", "MindBlast", "MindFlay", "HolyNova" },
    base_ctx, priest_state)

-- REPORT
print()
if #failures == 0 then
    print(string.format("PASS test_priest_vanilla_nil_guards — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_priest_vanilla_nil_guards — %d/%d passed, %d failures:", total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do print(string.format("  %d. [%s] %s", i, f.label, f.error)) end
    error(string.format("test_priest_vanilla_nil_guards: %d failure(s)", #failures))
end
