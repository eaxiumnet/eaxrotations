-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/_debug_shaman.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Debug script - standalone test of Shaman edge case failures
-- Set up Lua path like the test file
local EAXROTATIONS_DIR = "C:/newbot/scripts/EaxRotations"
if not package.path:find(EAXROTATIONS_DIR, 1, true) then
    package.path = package.path .. ";" .. EAXROTATIONS_DIR .. "/?.lua"
end

-- Set up minimal mock env matching the test file
local MOCK_SHAMAN_SPELLS = {
    LightningBolt = { 25449 }, EarthShock = { 25454 }, FlameShock = { 25457 },
    FrostShock = { 25464 }, ChainLightning = { 25442 }, LightningShield = { 25472 },
    WaterShield = { 33736 }, HealingWave = { 25396 }, LesserHealingWave = { 25420 },
    GhostWolf = { 2645 }, Purge = { 370 }, EarthbindTotem = { 2484 },
    StoneclawTotem = { 2487 }, FireNovaTotem = { 25459 }, SearingTotem = { 25295 },
    StrengthOfEarthTotem = { 25587 }, GraceOfAirTotem = { 25360 },
    ManaSpringTotem = { 25570 }, HealingStreamTotem = { 25567 },
    GroundingTotem = { 8177 }, WindfuryTotem = { 8516 }, TremorTotem = { 8143 },
    WindfuryWeapon = { 25485 }, RockbiterWeapon = { 25487 },
    FlametongueWeapon = { 25489 }, FrostbrandWeapon = { 25493 }, Shoot = { 5019 },
}

local mock_state = {
    health = 8000, max_health = 10000, mana = 5000, max_mana = 10000,
    buffs = {}, debuffs = {}, is_casting = false, target_guid = "mock-target",
}

local mock_target = {
    is_valid = function() return true end, get_health = function() return 8000 end,
    get_max_health = function() return 10000 end, is_casting = function() return mock_state.is_casting end,
    is_alive = function() return true end, get_guid = function() return mock_state.target_guid end,
    get_distance = function(other) return 5 end, get_health_percentage = function() return 80 end,
}

local mock_player = {
    is_valid = function() return true end, get_health = function() return mock_state.health end,
    get_max_health = function() return mock_state.max_health end,
    get_mana = function() return mock_state.mana end, get_max_mana = function() return mock_state.max_mana end,
    has_buff = function(id)
        if not id then return false end; local remains = mock_state.buffs[id]; return remains ~= nil and remains > 0
    end,
    has_debuff = function(id) return false end, get_class = function() return 7 end,
    is_in_combat = function() return false end, get_target = function() return mock_target end,
    get_position = function() return { x = 0, y = 0, z = 0 } end,
    get_item_at_inventory_slot = function() return nil end, get_totem_info = function() return nil end,
}

local NS = {}
NS.log = function() end; NS.log_warning = function() end
NS.spell_ready = function(spell_action, target, opts)
    if not spell_action then return false end; return true
end
NS.spell_exists = function(spell_id) return true end
NS.try_cast = function(spell_action, target, label, opts)
    if not spell_action then return false end; return true
end
NS.get_local_player = function() return mock_player end; NS.GetPlayer = function() return mock_player end
NS.get_target = function() return mock_target end
NS.get_distance = function(target) if not target then return nil end; return 10 end
NS.debuff_remains = function(target, spell) if not target or not spell then return 0 end; return 0 end
NS.buff_remains = function(unit, buff_ids) return 0 end
NS.buff_up = function(unit, buff_ids) if not unit or not buff_ids then return false end; return false end
NS.game_time_ms = function() return 100000 end
NS.rotation_registry = {
    _registrations = {}, register = function(self, key, strategies, opts)
        self._registrations[key] = { strategies = strategies, opts = opts }
    end, set_class_config = function(self, config) end,
}
NS.ShamanSpells = {}
for k, v in pairs(MOCK_SHAMAN_SPELLS) do NS.ShamanSpells[k] = v end
_G.EaxRotations = NS

local function make_context(overrides)
    local ctx = {
        is_solo = false, is_leveling = true, in_combat = true,
        mana_pct = 80, hp = 100, enemies_count = 1, is_moving = false, has_valid_enemy_target = false,
        me = {
            is_valid = function() return true end, get_health = function() return 10000 end,
            get_max_health = function() return 10000 end, has_buff = function(id) return false end,
            get_position = function() return { x = 0, y = 0, z = 0 } end,
        },
        target = mock_target, pet = { guid = "mock-pet" },
        settings = {
            playstyle = "leveling", active_playstyle = "leveling",
            use_interrupt = true, leveling_wand_threshold = 30, leveling_heal_hp = 50,
            leveling_use_shocks = true, leveling_default_shock = "flame",
            leveling_use_weapon_imbue = true, leveling_weapon_imbue = "windfury",
            leveling_use_totems = true, leveling_use_searing_totem = true,
            leveling_use_strength_totem = true, leveling_use_water_totem = true,
        },
    }
    if overrides then for k, v in pairs(overrides) do ctx[k] = v end end
    return ctx
end

-- Load the production module
local ok, module = pcall(dofile, "EaxRotations/classes/shaman/leveling_sylvanas.lua")
if not ok then
    print("FAILED to load module: " .. tostring(module)); os.exit(1)
end

local reg = NS.rotation_registry._registrations["leveling"]
if not reg then print("FAILED: no leveling registration"); os.exit(1) end
local strategies = reg.strategies
local get_state = reg.opts.get_state

-- Test WaterTotem at mana 85
print("=== Test WaterTotem mana 85 ===")
local ctx = make_context({mana_pct = 85, hp = 100})
local state = get_state(ctx)
print("  state.in_combat = " .. tostring(state.in_combat))
print("  state.mana_pct = " .. tostring(state.mana_pct))
print("  state.hp = " .. tostring(state.hp))
print("  state.use_totems = " .. tostring(state.use_totems))
print("  state.use_water_totem = " .. tostring(state.use_water_totem))
print("  state.mana_spring_ready = " .. tostring(state.mana_spring_ready))
print("  state.now_ms = " .. tostring(state.now_ms))
state.mana_spring_ready = true
state.healing_stream_ready = true
state.use_totems = true
state.use_water_totem = true
state.mana_pct = 85
state.hp = 100
local r = strategies[7].matches(ctx, state)
print("  MATCH RESULT: " .. tostring(r))

-- Test LightningShield OOC
print("\n=== Test LightningShield OOC ===")
local ctx2 = make_context({in_combat = false})
local state2 = get_state(ctx2)
print("  state.in_combat = " .. tostring(state2.in_combat))
print("  state.has_lightning_shield = " .. tostring(state2.has_lightning_shield))
print("  state.lightning_shield_ready = " .. tostring(state2.lightning_shield_ready))
print("  state.now_ms = " .. tostring(state2.now_ms))
state2.has_lightning_shield = false
state2.lightning_shield_ready = true
local r2 = strategies[2].matches(ctx2, state2)
print("  MATCH RESULT: " .. tostring(r2))

-- Test NS.spell_ready throws
print("\n=== Test NS.spell_ready throws ===")
local saved = NS.spell_ready
NS.spell_ready = function() error("crash") end
local ctx4 = make_context()
local ok4, state4 = pcall(get_state, ctx4)
print("  get_state pcall ok=" .. tostring(ok4))
if ok4 then print("  state exists") else print("  get_state threw: " .. tostring(state4)) end
NS.spell_ready = saved

-- Test NS.try_cast nil
print("\n=== Test NS.try_cast nil ===")
local saved_tc = NS.try_cast
NS.try_cast = nil
local ctx5 = make_context()
for i = 1, 15 do
    local ok5, r5 = pcall(strategies[i].execute, ctx5)
    if not ok5 then print("  strategies[" .. i .. "].execute CRASHED: " .. tostring(r5)) end
end
NS.try_cast = saved_tc

-- Test nil context execute
print("\n=== Test nil context execute ===")
for i = 1, 15 do
    local ok6, r6 = pcall(strategies[i].execute)
    if not ok6 then print("  strategies[" .. i .. "].execute() CRASHED: " .. tostring(r6)) end
end

print("\nDone.")
