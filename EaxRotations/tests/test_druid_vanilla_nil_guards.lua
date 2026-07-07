-- Regression test: druid vanilla specs Pattern 14 nil-guards.
-- Covers: balance_vanilla, cat_vanilla, caster_vanilla, resto_vanilla, leveling_vanilla.
-- bear_vanilla has its own dedicated test file.
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
    DruidSpells = {
        Barkskin = 22812, BearForm = 5487, CatForm = 5488, ChallengingRoar = 5209,
        Claw = 1082, DemoralizingRoar = 99, Enrage = 5229, EntanglingRoots = 339,
        FaerieFire = 770, FaerieFireFeral = 16857, FrenziedRegeneration = 22842,
        GiftOfTheWild = 21849, Growl = 6794, HealingTouch = 8936, Hurricane = 16914,
        InsectSwarm = 5570, Innervate = 29166, Lacerate = 33745, MangleBear = 33878,
        MarkOfTheWild = 1126, Maul = 6807, Moonfire = 8921, MoonkinForm = 24858,
        NaturesGrasp = 16689, Pounce = 9007, Prowl = 5215, Rake = 1822, Ravage = 6785,
        Rebirth = 20484, Rejuvenation = 774, RemoveCurse = 2782, Resto = {},
        Rip = 1079, Shred = 5221, Starfire = 2912, SwipeBear = 779, Thorns = 467,
        Tranquility = 740, Wrath = 517, FerociousBite = 22568, Bash = 5211,
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
    has_form = function(form) return false end,
    is_vanilla = function() return true end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    time_now = function() return 0 end,
    setting = function(ctx, key, default)
        local s = ctx and ctx.settings
        if s and s[key] ~= nil then return s[key] end return default end,
    same_unit = function() return false end,
    mana_pct = function() return 100 end,
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {}, MANA_POTION_IDS = {} }
package.loaded["shared/tbc_data_sylvanas"] =
    { ITEMS = { healthstones = {}, potions = {} }, SPELLS = { mage = {} } }
package.loaded["shared/leveling_sylvanas"] = {
    create_context_guard = function() return function() return true end end,
    build_common_state = function() end,
    create_wand_matches = function() return function() return false end end,
    execute_wand = function() return false end,
}

print("=== test_druid_vanilla_nil_guards ===")

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

-- Balance
test_spec("EaxRotations/classes/druid/balance_vanilla.lua", "balance_vanilla",
    { "MoonfireDoT", "InsectSwarmDoT", "StarfirePrimary", "WrathFiller", "FaerieFireDebuff", "HurricaneAoE", "BarkskinDefense", "MoonkinForm" },
    base_ctx)

-- Cat
test_spec("EaxRotations/classes/druid/cat_vanilla.lua", "cat_vanilla",
    { "Shred", "Rip", "FerociousBite", "Rake", "Claw", "Pounce", "Ravage", "FaerieFireFeral" },
    { in_combat = true, target = {}, me = {}, settings = {}, energy = 50, combo_points = 3, hp = 80 })

-- Caster
test_spec("EaxRotations/classes/druid/caster_vanilla.lua", "caster_vanilla",
    { "Moonfire", "Wrath", "Starfire", "InsectSwarm", "FaerieFire" },
    base_ctx)

-- Resto
test_spec("EaxRotations/classes/druid/resto_vanilla.lua", "resto_vanilla",
    { "Rejuvenation", "HealingTouch", "Regrowth", "Lifebloom", "Swiftmend" },
    { in_combat = true, target = { get_health = function() return 50 end, get_max_health = function() return 100 end }, me = {}, settings = {}, hp = 80, mana_pct = 80 })

-- Leveling
test_spec("EaxRotations/classes/druid/leveling_vanilla.lua", "leveling_vanilla",
    { "Rake", "Shred", "Rip", "FerociousBite", "Claw", "Maul", "SwipeBear", "Moonfire", "Wrath", "Starfire", "HealingTouch", "Rejuvenation" },
    { in_combat = true, target = {}, me = {}, settings = {}, energy = 50, combo_points = 3, rage = 30, hp = 80 })

-- REPORT
print()
if #failures == 0 then
    print(string.format("PASS test_druid_vanilla_nil_guards — %d/%d passed", total_passed, total_tests))
else
    print(string.format("FAIL test_druid_vanilla_nil_guards — %d/%d passed, %d failures:", total_passed, total_tests, #failures))
    for i, f in ipairs(failures) do print(string.format("  %d. [%s] %s", i, f.label, f.error)) end
    error(string.format("test_druid_vanilla_nil_guards: %d failure(s)", #failures))
end
