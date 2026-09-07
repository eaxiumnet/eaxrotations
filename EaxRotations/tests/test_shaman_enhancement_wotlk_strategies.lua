-- test_shaman_enhancement_wotlk_strategies.lua — Enhancement shaman WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL enhancement_wotlk.lua through its real build_state read
--        path (NS.buff_stacks for the Maelstrom Weapon proc, NS.debuff_remains
--        for Flame Shock, NS.spell_ready for Feral Spirit / Bloodlust /
--        Shamanistic Rage, NS.get_totem_info for the fire/water slots,
--        NS.buff_up for Lightning Shield, NS.game_time_ms for the weapon-imbue
--        window), pinning both sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): enhancement had no real-read
--        behavioral pins; these exercise the real proc/CD/totem plumbing.
-- SAFETY: Pure unit tests with a mocked NS; the real enhancement_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local mana = 100
local enemy_count = 1
local maelstrom = 0
local debuffs = {}
local buffs = {}
local not_ready = {}
local totem_slots = {}
local now_ms = 0

local function flame(secs) debuffs[49233] = secs end
local function shield(up) buffs[49281] = up or nil end

local function reset_env()
    combat, mana, enemy_count, maelstrom, now_ms = true, 100, 1, 0, 0
    debuffs, buffs, not_ready, totem_slots = {}, {}, {}, {}
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
    GetPlayer = function() return _G.EaxRotations.me end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if debuffs[id] then return debuffs[id] end
        end
        return 0
    end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    buff_stacks = function(unit, ids)
        for _, id in ipairs(ids) do
            if maelstrom > 0 and id == 53817 then return maelstrom end
        end
        return 0
    end,
    spell_ready = function(spell, unit, opts)
        local id = type(spell) == "number" and spell or (spell and spell.id) or 0
        if not_ready[id] then return false end
        return true
    end,
    get_totem_info = function(slot) return totem_slots[slot] end,
    game_time_ms = function() return now_ms end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/shaman/enhancement_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "enhancement_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        mana_pct = mana,
        enemy_count = enemy_count,
        target = { is_casting = function() return false end },
        settings = {},
    }
    local state = result.build_state(ctx)
    local matched = find_strategy(strategy_name).matches(ctx, state)
    if expect then
        assert_true(matched, label .. " should match")
    else
        assert_false(matched, label .. " should NOT match")
    end
end

local function assert_lane(label, strategy_name, setup, expect)
    reset_env()
    setup()
    scenario(label, strategy_name, expect)
end

-- ============================================================================
-- Feral Spirit / Bloodlust: in combat + real spell_ready window.
-- ============================================================================
assert_lane("Feral Spirit fires in combat when ready", "FeralSpirit", function() end, true)
assert_lane("Feral Spirit held on cooldown", "FeralSpirit", function() not_ready[51533] = true end, false)
assert_lane("Feral Spirit held out of combat", "FeralSpirit", function() combat = false end, false)
assert_lane("Bloodlust fires in combat when ready", "Bloodlust", function() end, true)
assert_lane("Bloodlust held on cooldown", "Bloodlust", function() not_ready[2825] = true end, false)

-- ============================================================================
-- LightningBolt: Maelstrom Weapon proc consumer at 5 stacks.
-- ============================================================================
assert_lane("Maelstrom Lightning Bolt fires at 5 stacks", "LightningBolt",
    function() maelstrom = 5 end, true)
assert_lane("Maelstrom Lightning Bolt fires above 5 stacks", "LightningBolt",
    function() maelstrom = 7 end, true)
assert_lane("Maelstrom Lightning Bolt held at 4 stacks", "LightningBolt",
    function() maelstrom = 4 end, false)
assert_lane("Maelstrom Lightning Bolt held with no proc", "LightningBolt", function() end, false)

-- ============================================================================
-- Stormstrike / EarthShock / LavaLash: unconditional in-combat fillers
-- (ungated lanes — pinned as always-match so the real rotation order owns
-- the priority between them).
-- ============================================================================
assert_lane("Stormstrike is ungated (matches any state)", "Stormstrike", function() end, true)
assert_lane("EarthShock is ungated (matches any state)", "EarthShock", function() end, true)
assert_lane("LavaLash is ungated (matches any state)", "LavaLash", function() end, true)

-- ============================================================================
-- FlameShock: refresh at/below 3s.
-- ============================================================================
assert_lane("FlameShock refreshes when the debuff is down", "FlameShock", function() end, true)
assert_lane("FlameShock refreshes at 2.9s remaining", "FlameShock", function() flame(2.9) end, true)
assert_lane("FlameShock blocked at the 3.0s boundary", "FlameShock", function() flame(3) end, false)

-- ============================================================================
-- CallOfTheElements: re-drop when the water slot (3) is free.
-- ============================================================================
assert_lane("Call of the Elements fires with the water slot free",
    "CallOfTheElements", function() end, true)
assert_lane("Call of the Elements held while a water totem is up",
    "CallOfTheElements", function() totem_slots[3] = { have_totem = true } end, false)

-- ============================================================================
-- MagmaTotem: 2+ enemies + fire slot (1) free.
-- ============================================================================
assert_lane("Magma Totem fires at 2 enemies with the fire slot free",
    "MagmaTotem", function() enemy_count = 2 end, true)
assert_lane("Magma Totem blocked single-target", "MagmaTotem", function() end, false)
assert_lane("Magma Totem blocked when the fire slot is occupied",
    "MagmaTotem", function() enemy_count = 2; totem_slots[1] = { have_totem = true } end, false)

-- ============================================================================
-- FireNova: 2+ enemies AND an active fire totem (WotLK requirement).
-- ============================================================================
assert_lane("Fire Nova fires at 2 enemies with a fire totem up", "FireNova",
    function() enemy_count = 2; totem_slots[1] = { have_totem = true } end, true)
assert_lane("Fire Nova blocked single-target", "FireNova", function() end, false)
assert_lane("Fire Nova blocked when no fire totem is up", "FireNova",
    function() enemy_count = 2 end, false)

-- ============================================================================
-- LightningShield: re-apply when the aura is down.
-- ============================================================================
assert_lane("Lightning Shield applies when down", "LightningShield", function() end, true)
assert_lane("Lightning Shield held while up", "LightningShield", function() shield(true) end, false)

-- ============================================================================
-- ShamanisticRage: in combat + mana < 40 + ready.
-- ============================================================================
assert_lane("Shamanistic Rage fires at 39% mana ready", "ShamanisticRage",
    function() mana = 39 end, true)
assert_lane("Shamanistic Rage blocked at 40% mana", "ShamanisticRage", function() end, false)
assert_lane("Shamanistic Rage held on cooldown", "ShamanisticRage",
    function() mana = 39; not_ready[30823] = true end, false)
assert_lane("Shamanistic Rage blocked out of combat", "ShamanisticRage",
    function() mana = 39; combat = false end, false)

-- ============================================================================
-- WindfuryWeapon / FlametongueWeapon: OOC windowed imbue upkeep (~29.8 min).
-- The runtime window starts expired (never applied), so the OOC fire side is
-- default; a negative clock proves the freshness comparison holds the lane.
-- ============================================================================
local REFRESH = 1790000
assert_lane("Windfury applies out of combat when the window is expired",
    "WindfuryWeapon", function() combat = false end, true)
assert_lane("Windfury held out of combat inside the 29.8-min window",
    "WindfuryWeapon", function() combat = false; now_ms = -(REFRESH + 1) end, false)
assert_lane("Windfury blocked in combat with the window expired",
    "WindfuryWeapon", function() end, false)
assert_lane("Windfury blocked below 5% mana", "WindfuryWeapon",
    function() combat = false; mana = 4 end, false)
assert_lane("Flametongue applies out of combat when the window is expired",
    "FlametongueWeapon", function() combat = false end, true)
assert_lane("Flametongue held out of combat inside the 29.8-min window",
    "FlametongueWeapon", function() combat = false; now_ms = -(REFRESH + 1) end, false)
assert_lane("Flametongue blocked in combat with the window expired",
    "FlametongueWeapon", function() end, false)

print("PASS test_shaman_enhancement_wotlk_strategies")
