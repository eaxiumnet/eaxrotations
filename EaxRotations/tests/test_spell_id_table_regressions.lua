-- Regression checks for TBC spell/consumable IDs.
-- This test is intentionally semantic: it accepts both legacy one-line
-- NS.spell_action({ ... }, "Name") calls and structured
-- NS.spell_action({ name = "Name", ids = { ... } }) tables.

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_not(v, label)
    if v then error(label or "assert_not failed", 2) end
end

local function read_file(path)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a")
    f:close()
    return data
end

local function contains(data, text)
    return data:find(text, 1, true) ~= nil
end

local function before(data, first, second)
    local a = data:find(first, 1, true)
    local b = data:find(second, 1, true)
    return a ~= nil and b ~= nil and a < b
end

local function nums(text)
    local out = {}
    for n in (text or ""):gmatch("%f[%d](%d+)%f[%D]") do
        out[#out + 1] = tonumber(n)
    end
    return out
end

local function same_nums(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function spell_ids(data, spell_name)
    local escaped = spell_name:gsub("([^%w])", "%%%1")
    local legacy = data:match(escaped .. "%s*=%s*NS%.spell_action%s*%(%s*%{([^}]*)%}%s*,%s*\"" .. escaped .. "\"")
    if legacy then return nums(legacy) end

    local start = data:find('name = "' .. spell_name .. '"', 1, true)
    if not start then return nil end
    local chunk = data:sub(start, start + 700)
    local structured = chunk:match("ids%s*=%s*%{([^}]*)%}")
    if structured then return nums(structured) end
    return nil
end

local function assert_spell_ids(path, spell_name, expected)
    local data = read_file(path)
    local actual = spell_ids(data, spell_name)
    assert_true(actual ~= nil, path .. " missing spell table for " .. spell_name)
    assert_true(same_nums(actual, expected), path .. " " .. spell_name .. " IDs mismatch")
end

local function assert_not_numbers(path, bad_ids, label)
    local data = read_file(path)
    for i = 1, #bad_ids do
        assert_not(contains(data, tostring(bad_ids[i])), (label or path) .. " should not contain " .. tostring(bad_ids[i]))
    end
end

assert_spell_ids("EaxRotations/classes/mage/class_sylvanas.lua", "ArcaneBlast", { 30451 })
assert_spell_ids("EaxRotations/classes/mage/class_sylvanas.lua", "Blizzard", { 27085, 10187, 10186, 10185, 8427, 6141, 10 })
assert_spell_ids("EaxRotations/classes/mage/class_sylvanas.lua", "Flamestrike", { 27086, 10216, 10215, 8423, 8422, 2121, 2120 })
assert_spell_ids("EaxRotations/classes/mage/class_sylvanas.lua", "Frostbolt", { 27072, 25304, 10181, 10180, 10179, 8408, 8407, 8406, 7322, 837, 205, 116 })
assert_not_numbers("EaxRotations/classes/mage/class_sylvanas.lua", { 10198 }, "mage spell table")
local arcane_mage = read_file("EaxRotations/classes/mage/arcane_sylvanas.lua")
assert_true(contains(arcane_mage, "MANA_GEM_ITEM_IDS"), "Arcane mana gem should use item IDs for combat gem use")
assert_true(contains(arcane_mage, "NS.use_item_by_id"), "Arcane mana gem should use items instead of conjure spells in combat")
assert_true(contains(read_file("EaxRotations/classes/mage/frost_sylvanas.lua"), "TBC_MAGE.frost_nova"), "Frost Nova roots should use central TBC data")

assert_spell_ids("EaxRotations/classes/druid/class_sylvanas.lua", "Cower", { 27004, 9892, 8998 })
assert_spell_ids("EaxRotations/classes/druid/class_sylvanas.lua", "DemoralizingRoar", { 26998, 9898, 9747, 9490, 1735, 99 })
assert_spell_ids("EaxRotations/classes/druid/class_sylvanas.lua", "FaerieFireFeral", { 27011, 17392, 17391, 17390, 16857 })
assert_spell_ids("EaxRotations/classes/druid/class_sylvanas.lua", "Shred", { 27002, 27001, 9830, 9829, 8992, 6800, 5221 })
assert_spell_ids("EaxRotations/classes/druid/class_sylvanas.lua", "MangleCat", { 33983, 33982, 33876 })
assert_spell_ids("EaxRotations/classes/druid/class_sylvanas.lua", "Prowl", { 9913, 6783, 5215 })
assert_spell_ids("EaxRotations/classes/druid/class_sylvanas.lua", "Swiftmend", { 18562 })
assert_not_numbers("EaxRotations/classes/druid/class_sylvanas.lua", { 25275 }, "druid spell table")
assert_not_numbers("EaxRotations/classes/druid/bear_sylvanas.lua", { 39213, 23720 }, "druid bear consumables")

assert_spell_ids("EaxRotations/classes/shaman/class_sylvanas.lua", "NaturesSwiftness", { 16188 })
assert_spell_ids("EaxRotations/classes/shaman/class_sylvanas.lua", "Stormstrike", { 17364 })
assert_spell_ids("EaxRotations/classes/shaman/class_sylvanas.lua", "FlameShock", { 25457, 29228, 10448, 10447, 8053, 8052, 8050 })
assert_spell_ids("EaxRotations/classes/shaman/class_sylvanas.lua", "FrostShock", { 25464, 10473, 10472, 8058, 8056 })
assert_spell_ids("EaxRotations/classes/shaman/class_sylvanas.lua", "Purge", { 8012, 370 })
assert_spell_ids("EaxRotations/classes/shaman/class_sylvanas.lua", "WaterShield", { 33736, 24398, 23575 })
assert_spell_ids("EaxRotations/classes/shaman/class_sylvanas.lua", "WindfuryWeapon", { 25505, 16362, 10486, 8235, 8232 })
assert_not_numbers("EaxRotations/classes/shaman/class_sylvanas.lua", { 17423 }, "shaman spell table")
assert_not_numbers("EaxRotations/classes/shaman/enhancement_sylvanas.lua", { 10430, 8133, 8132 }, "shaman enhancement Lightning Shield")

assert_spell_ids("EaxRotations/classes/priest/class_sylvanas.lua", "InnerFire", { 25431, 10952, 10951, 1006, 602, 7128, 588 })
assert_spell_ids("EaxRotations/classes/priest/class_sylvanas.lua", "PowerWordFortitude", { 25389, 10938, 10937, 2791, 1245, 1244, 1243 })
assert_spell_ids("EaxRotations/classes/priest/class_sylvanas.lua", "Starshards", { 25446, 19305, 19304, 19303, 19302, 19299, 19296, 10797 })
assert_true(contains(read_file("EaxRotations/classes/priest/shadow_sylvanas.lua"), "STARSHARDS_SPELL = { 25446, 19305, 19304, 19303, 19302, 19299, 19296, 10797 }"), "Shadow Starshards should use online TBC spell IDs")
assert_true(contains(read_file("EaxRotations/classes/priest/shadow_sylvanas.lua"), "HOLY_NOVA_SPELL = { 25331, 25329, 27805, 27804, 27803, 27801, 27800, 27799, 15431, 15430, 15237 }"), "Shadow Holy Nova fallback should not use item/NPC IDs")
assert_not_numbers("EaxRotations/classes/priest/class_sylvanas.lua", { 25430, 10936, 1242, 1241, 1240 }, "priest spell table")

assert_spell_ids("EaxRotations/classes/warlock/class_sylvanas.lua", "CurseOfAgony", { 27218, 11713, 11712, 11711, 6217, 1014, 980 })
assert_spell_ids("EaxRotations/classes/warlock/class_sylvanas.lua", "DeathCoil", { 27223, 17926, 17925, 6789 })
assert_spell_ids("EaxRotations/classes/warlock/class_sylvanas.lua", "Shadowburn", { 30546, 27263, 18871, 18870, 18869, 18868, 18867, 17877 })
assert_not_numbers("EaxRotations/classes/warlock/middleware_sylvanas.lua", { 190005, 190006, 190007, 190008, 18892, 39213 }, "warlock consumables")
assert_not_numbers("EaxRotations/classes/warlock/affliction_sylvanas.lua", { 22791, 13445 }, "warlock affliction mana consumables")

assert_spell_ids("EaxRotations/classes/paladin/class_sylvanas.lua", "LayOnHands", { 27154, 10310, 2800, 633 })
assert_spell_ids("EaxRotations/classes/paladin/class_sylvanas.lua", "SealBlood", { 31892 })
assert_spell_ids("EaxRotations/classes/paladin/class_sylvanas.lua", "SealCommandRank1", { 20375 })

assert_spell_ids("EaxRotations/classes/warrior/class_sylvanas.lua", "Devastate", { 30022, 30016, 20243 })
assert_spell_ids("EaxRotations/classes/warrior/class_sylvanas.lua", "Revenge", { 30357, 25269, 25288, 11601, 11600, 7379, 6574, 6572 })
assert_spell_ids("EaxRotations/classes/warrior/class_sylvanas.lua", "Pummel", { 6554, 6552 })
assert_spell_ids("EaxRotations/classes/warrior/class_sylvanas.lua", "Hamstring", { 25212, 7373, 7372, 1715 })
assert_spell_ids("EaxRotations/classes/warrior/class_sylvanas.lua", "BattleShout", { 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 })

assert_spell_ids("EaxRotations/classes/rogue/class_sylvanas.lua", "Envenom", { 32684, 32645 })
assert_spell_ids("EaxRotations/classes/rogue/class_sylvanas.lua", "Shiv", { 5938 })
assert_spell_ids("EaxRotations/classes/rogue/class_sylvanas.lua", "CloakOfShadows", { 31224 })
assert_spell_ids("EaxRotations/classes/rogue/class_sylvanas.lua", "Gouge", { 38764, 11286, 11285, 8629, 1777, 1776 })
assert_not_numbers("EaxRotations/classes/rogue/middleware_sylvanas.lua", { 51722 }, "rogue middleware")
assert_not_numbers("EaxRotations/classes/rogue/assassination_sylvanas.lua", { 51722 }, "rogue assassination")
assert_not_numbers("EaxRotations/classes/rogue/combat_sylvanas.lua", { 51722 }, "rogue combat")
assert_not_numbers("EaxRotations/classes/rogue/subtlety_sylvanas.lua", { 51722 }, "rogue subtlety")
assert_not_numbers("EaxRotations/classes/rogue/leveling_sylvanas.lua", { 51722 }, "rogue leveling")

assert_spell_ids("EaxRotations/classes/hunter/class_sylvanas.lua", "ExplosiveTrap", { 27025, 14317, 14316, 13813 })
assert_spell_ids("EaxRotations/classes/hunter/class_sylvanas.lua", "AspectOfTheHawk", { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 })
assert_spell_ids("EaxRotations/classes/hunter/class_sylvanas.lua", "FreezingTrap", { 14311, 14310, 1499 })
assert_spell_ids("EaxRotations/classes/hunter/class_sylvanas.lua", "ViperSting", { 27018, 14280, 14279, 3034 })
assert_not_numbers("EaxRotations/classes/hunter/class_sylvanas.lua", { 38121, 27045, 10926, 10925, 10924, 25810 }, "hunter spell table")

local hunter_bm = read_file("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua")
assert_true(before(hunter_bm, 'name = "SteadyShot"', 'name = "SerpentSting"'), "BM should not prioritize Serpent Sting above core shot rotation")

local paladin_ret = read_file("EaxRotations/classes/paladin/retribution_sylvanas.lua")
assert_true(before(paladin_ret, 'name = "SealTwistBlood"', 'name = "CrusaderStrike"'), "Ret should prioritize twist-window seals over normal strikes")

print("PASS test_spell_id_table_regressions")
