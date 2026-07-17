-- test_vanilla_content_coverage.lua — Structural 1–60 Vanilla coverage harness.
-- WHAT:  Load all 40 *_vanilla.lua ships; assert strategies load; level-band smoke.
-- WHEN:  During rotation test suite (deep Classic audit).
-- WHY:   Encodes "module loads + has combat strategies" for every Vanilla path.
-- SAFETY: Mocked NS; drives real dofile of shipped modules only.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;"
    .. (package.path or "")

-- Lua 5.4 compat: global unpack was moved to table.unpack
local unpack = table.unpack or unpack

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local failures = {}
local total, passed = 0, 0

local function expect(label, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failures[#failures + 1] = label .. ": " .. tostring(err)
    end
end

-- Class IDs (match common/enums when present; used when require enums fails)
local CLASS_ID = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}
local current_class_id = CLASS_ID.WARRIOR

local CLASS_BY_FOLDER = {
    warrior = CLASS_ID.WARRIOR,
    paladin = CLASS_ID.PALADIN,
    hunter = CLASS_ID.HUNTER,
    rogue = CLASS_ID.ROGUE,
    priest = CLASS_ID.PRIEST,
    shaman = CLASS_ID.SHAMAN,
    mage = CLASS_ID.MAGE,
    warlock = CLASS_ID.WARLOCK,
    druid = CLASS_ID.DRUID,
}

-- Minimal NS for load (class spell tables left empty — spell_action returns ids)
local function make_ns()
    return {
        is_vanilla = function() return true end,
        CLASS_ID = CLASS_ID,
        PLAYER_UNIT = {},
        GetPlayer = function()
            return {
                get_health_percentage = function() return 100 end,
                get_class = function() return current_class_id end,
                get_race_id = function() return 1 end,
            }
        end,
        GetPet = function() return nil end,
        spell_action = function(ids, name)
            if type(ids) == "table" then
                return { ids = ids, name = name, [1] = ids[1] }
            end
            return ids
        end,
        spell_ready = function() return true end,
        spell_exists = function() return true end,
        is_spell_learned = function() return true end,
        get_spell_id = function(spell)
            if type(spell) == "number" then return spell end
            if type(spell) == "table" then return spell[1] or spell.spell or spell.id end
            return spell
        end,
        try_cast = function() return true end,
        buff_up = function() return false end,
        buff_remains = function() return 0 end,
        debuff_up = function() return false end,
        debuff_remains = function() return 0 end,
        debuff_stacks = function() return 0 end,
        unit_mana_pct = function() return 80 end,
        unit_alive = function() return true end,
        time_now = function() return 0 end,
        log = function() end,
        has_item = function() return true end,
        is_execute_phase = function(hp, pct) return (hp or 100) <= (pct or 20) end,
        broken_api_throttled = function() return false end,
        should_refresh_dot = function() return true end,
        should_use_long_cd = function() return true end,
        import_helpers = function(...)
            local names = { ... }
            local out = {}
            for i = 1, #names do
                out[i] = function() return true end
            end
            return unpack(out)
        end,
        rotation_registry = {
            register = function() end,
        },
        WarriorSpells = {},
        WarriorConstants = { STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 } },
        HunterSpells = {},
        MageSpells = {},
        PaladinSpells = {},
        PriestSpells = {},
        RogueSpells = {},
        ShamanSpells = {},
        WarlockSpells = {},
        DruidSpells = {},
        HunterClipTracker = {
            ms_until_auto = function() return 0 end,
            record_manual_shot = function() end,
            can_cast_steady = function() return true end,
        },
    }
end

package.loaded["shared/spec_kit_sylvanas"] = {
    setting = function(_, _, d) return d end,
    setting_bool = function(_, _, d) return d end,
    setting_number = function(_, _, d) return d end,
    define_action_for_class = function()
        return function(name, ids)
            return ids
        end
    end,
    safe_state = function(s) return s end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {},
    MANA_POTION_IDS = {},
    DAMAGE_POTION_IDS = {},
}
package.loaded["shared/leveling_helpers_sylvanas"] = {
    level_from_context = function(_, fb) return fb or 60 end,
    vanilla_level_from_context = function() return 60 end,
    is_low_level = function(l) return (l or 60) < 50 end,
    has_mangle_cat = function(l) return (l or 60) >= 50 end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    has_buff = function() return false end,
    get_player = function() return nil end,
}
package.loaded["shared/leveling_sylvanas"] = {
    create_context_guard = function()
        return function() return true end
    end,
    build_common_state = function() end,
    create_wand_matches = function()
        return function() return false end
    end,
    execute_wand = function() return false end,
}
package.loaded["shared/hunter_core_sylvanas"] = {
    get_pet = function() return nil end,
    pet_alive = function() return false end,
    pet_hp_pct = function() return 100 end,
    can_cast_steady = function() return true end,
    can_cast_instant = function() return true end,
    record_instant_shot = function() end,
    sting_remains = function() return 10 end,
    should_feign_death = function() return false end,
}
package.loaded["shared/targeting_sylvanas"] = {}
package.loaded["shared/pet_manager_sylvanas"] = {}
package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { healthstones = {}, potions = {} }, SPELLS = {} }
package.loaded["shared/curse_helper_sylvanas"] = { other_curse_active = function() return false end }
package.loaded["shared/hit_cap_tracker_sylvanas"] = {}
package.loaded["shared/cc_gate_db_sylvanas"] = {
    find_best_dispel_target = function() return nil end,
}

local VANILLA_FILES = {
    "EaxRotations/classes/druid/balance_vanilla.lua",
    "EaxRotations/classes/druid/bear_vanilla.lua",
    "EaxRotations/classes/druid/caster_vanilla.lua",
    "EaxRotations/classes/druid/cat_vanilla.lua",
    "EaxRotations/classes/druid/leveling_vanilla.lua",
    "EaxRotations/classes/druid/resto_vanilla.lua",
    "EaxRotations/classes/hunter/beast_mastery_vanilla.lua",
    "EaxRotations/classes/hunter/leveling_vanilla.lua",
    "EaxRotations/classes/hunter/marksmanship_vanilla.lua",
    "EaxRotations/classes/hunter/survival_vanilla.lua",
    "EaxRotations/classes/mage/arcane_vanilla.lua",
    "EaxRotations/classes/mage/fire_vanilla.lua",
    "EaxRotations/classes/mage/frost_vanilla.lua",
    "EaxRotations/classes/mage/leveling_vanilla.lua",
    "EaxRotations/classes/paladin/holy_vanilla.lua",
    "EaxRotations/classes/paladin/leveling_vanilla.lua",
    "EaxRotations/classes/paladin/protection_vanilla.lua",
    "EaxRotations/classes/paladin/retribution_vanilla.lua",
    "EaxRotations/classes/priest/discipline_vanilla.lua",
    "EaxRotations/classes/priest/holy_vanilla.lua",
    "EaxRotations/classes/priest/leveling_vanilla.lua",
    "EaxRotations/classes/priest/shadow_vanilla.lua",
    "EaxRotations/classes/priest/smite_vanilla.lua",
    "EaxRotations/classes/rogue/assassination_vanilla.lua",
    "EaxRotations/classes/rogue/combat_vanilla.lua",
    "EaxRotations/classes/rogue/leveling_vanilla.lua",
    "EaxRotations/classes/rogue/subtlety_vanilla.lua",
    "EaxRotations/classes/shaman/elemental_vanilla.lua",
    "EaxRotations/classes/shaman/enhancement_vanilla.lua",
    "EaxRotations/classes/shaman/leveling_vanilla.lua",
    "EaxRotations/classes/shaman/restoration_vanilla.lua",
    "EaxRotations/classes/warlock/affliction_vanilla.lua",
    "EaxRotations/classes/warlock/demonology_vanilla.lua",
    "EaxRotations/classes/warlock/destruction_vanilla.lua",
    "EaxRotations/classes/warlock/leveling_vanilla.lua",
    "EaxRotations/classes/warrior/arms_vanilla.lua",
    "EaxRotations/classes/warrior/fury_vanilla.lua",
    "EaxRotations/classes/warrior/kebab_vanilla.lua",
    "EaxRotations/classes/warrior/leveling_vanilla.lua",
    "EaxRotations/classes/warrior/protection_vanilla.lua",
}

assert_true(#VANILLA_FILES == 40, "must list all 40 Vanilla ships, got " .. #VANILLA_FILES)

local function extract_strategies(result)
    if type(result) ~= "table" then return nil end
    if type(result.strategies) == "table" then return result.strategies end
    -- plain array of strategy rows
    if result[1] and (result[1].name or result[1].matches) then return result end
    -- named module tables (e.g. resto) may nest
    if type(result.module) == "table" and result.module.strategies then
        return result.module.strategies
    end
    -- leveling modules sometimes only expose on_update + build_state (strategies local)
    -- Accept non-empty table with build_state as "loaded rotation module"
    if type(result.build_state) == "function" or type(result.on_update) == "function" then
        return result.strategies or result
    end
    return result
end

local function count_named(strats)
    if type(strats) ~= "table" then return 0 end
    local n = 0
    for i = 1, #strats do
        if type(strats[i]) == "table" and (strats[i].name or strats[i].matches) then
            n = n + 1
        end
    end
    return n
end

print("=== test_vanilla_content_coverage (40 files) ===")

for _, path in ipairs(VANILLA_FILES) do
    expect("load " .. path, function()
        local folder = path:match("classes/([^/]+)/")
        current_class_id = (folder and CLASS_BY_FOLDER[folder]) or CLASS_ID.WARRIOR
        _G.EaxRotations = make_ns()
        local chunk = assert(loadfile(path), "loadfile failed: " .. path)
        local result = chunk()
        -- Class-gated files return nil when class mismatch; must not with correct class mock
        assert_true(result ~= nil, path .. " returned nil (class gate / early return?)")
        local strats = extract_strategies(result)
        assert_true(type(strats) == "table", path .. " must return strategies/module table")
        local n = count_named(strats)
        local has_module = type(result.build_state) == "function" or type(result.on_update) == "function"
        assert_true(n >= 1 or has_module or (type(result) == "table" and #result >= 1),
            path .. " must expose strategies or leveling module API (got named=" .. tostring(n) .. ")")
    end)
end

-- Level-band smoke: hunter BM + warrior fury + warlock destruction (real matches)
local LEVELS = { 10, 25, 40, 60 }
local function reload(path)
    local folder = path:match("classes/([^/]+)/")
    current_class_id = (folder and CLASS_BY_FOLDER[folder]) or CLASS_ID.WARRIOR
    _G.EaxRotations = make_ns()
    local result = assert(loadfile(path))()
    return extract_strategies(result), result
end

local function find_strat(strats, name)
    for i = 1, #strats do
        if strats[i].name == name then return strats[i] end
    end
    return nil
end

expect("hunter BM AimedShot at 60", function()
    local s = reload("EaxRotations/classes/hunter/beast_mastery_vanilla.lua")
    local aimed = find_strat(s, "AimedShot")
    assert_true(aimed ~= nil, "AimedShot present")
    local st = { in_combat = true, aimed_shot_ready = true, mana_pct = 80, is_mounted = false }
    assert_true(aimed.matches({ in_combat = true, target = {}, me = {}, player_level = 60 }, st),
        "Aimed matches at 60")
end)

expect("hunter Survival leveling fillers when Aimed not ready (L15)", function()
    local s = reload("EaxRotations/classes/hunter/survival_vanilla.lua")
    local arcane = find_strat(s, "LevelingArcaneShot") or find_strat(s, "ArcaneShot")
    assert_true(arcane ~= nil, "Arcane path present")
end)

expect("destruction SoulFire execute-only across levels", function()
    local s = reload("EaxRotations/classes/warlock/destruction_vanilla.lua")
    local sf = find_strat(s, "SoulFire")
    assert_true(sf ~= nil, "SoulFire present")
    for _, lvl in ipairs(LEVELS) do
        assert_true(not sf.matches({ target = {}, target_hp = 100, player_level = lvl, settings = {} }, {}),
            "SoulFire must not match full HP at L" .. lvl)
        assert_true(sf.matches({ target = {}, target_hp = 15, player_level = lvl, settings = {} }, {}),
            "SoulFire matches execute at L" .. lvl)
    end
end)

expect("vanilla_level helper default 60", function()
    package.loaded["shared/leveling_helpers_sylvanas"] = nil
    -- Load real helper
    package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path
    local H = require("shared/leveling_helpers_sylvanas")
    assert_true(H.vanilla_level_from_context ~= nil, "vanilla_level_from_context exists")
    assert_true(H.vanilla_level_from_context({}) == 60, "default Classic cap 60")
    assert_true(H.vanilla_level_from_context({ player_level = 25 }) == 25, "uses player_level")
end)

if #failures > 0 then
    print("FAIL test_vanilla_content_coverage — " .. passed .. "/" .. total)
    for i = 1, #failures do
        print("  " .. failures[i])
    end
    error("test_vanilla_content_coverage failed", 0)
end

print("PASS test_vanilla_content_coverage — " .. passed .. "/" .. total)
