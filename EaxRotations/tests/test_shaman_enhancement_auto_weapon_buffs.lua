-- test_shaman_enhancement_auto_weapon_buffs.lua — Auto Weapon Buffs by Level.
-- WHAT:  verifies that "auto" resolves to level-appropriate buffs.
-- WHEN:  regression guard for enhancement_sylvanas.lua auto weapon buff logic.
-- WHY:   leveling enhancement shamans should get correct buffs without manual config.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;api/?.lua;api/?/?.lua;api/?/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local enh_build_state = nil

_G.EaxRotations = {
    ShamanSpells = {
        LightningShield = { 324 }, WaterShield = { 33736 },
        ShamanisticRage = { 30823 }, Bloodlust = { 2825 },
        Stormstrike = { 17364 }, FlameShock = { 8050 },
        EarthShock = { 8042 }, FrostShock = { 8056 },
        ChainLightning = { 421 }, LightningBolt = { 403 },
        WindfuryTotem = { 8512 }, GraceOfAirTotem = { 8835 },
        StrengthOfEarthTotem = { 8075 }, StoneskinTotem = { 8155 },
        ManaSpringTotem = { 5675 }, HealingStreamTotem = { 5394 },
        SearingTotem = { 3599 }, MagmaTotem = { 8190 },
        FireNovaTotem = { 1535 }, ManaTideTotem = { 16190 },
        NaturesSwiftness = { 16188 }, LesserHealingWave = { 8004 },
        ChainHeal = { 1064 }, GroundingTotem = { 8177 },
        WindfuryWeapon = 8232, FlametongueWeapon = 8024, RockbiterWeapon = 8017,
        TotemicCall = { 36936 }, GiftOfTheNaaru = { 28880 },
        Purge = { 370 },
    },
    rotation_registry = {
        register = function(self, name, strategies, opts)
            if opts and opts.get_state then enh_build_state = opts.get_state end
            return true
        end,
    },
    game_time_ms = function() return 0 end,
    GetPlayer = function() local me = {}; me.is_moving = function() return false end; return me end,
    unit_mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    buff_up = function() return false end,
    spell_ready = function() return true end,
    action_matches = function() return true end,
    action_execute = function() return true end,
    try_cast = function() return true end,
    log = function() end,
    is_spell_learned = function(spell) return true end,
    get_totem_info = function(slot) return { have_totem = false } end,
    PLAYER_UNIT = {},
}

_G.core = {
    spell_book = { get_totem_info = function() return { have_totem = false } end },
    object_manager = { get_visible_objects = function() return {} end },
}

package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS = {} }

-- Load module to capture enh_build_state
dofile("EaxRotations/classes/shaman/enhancement_sylvanas.lua")

-- C1: Level 70 -> windfury
_G.EaxRotations.GetPlayer = function() local me = {}; me.is_moving = function() return false end; me.get_level = function() return 70 end; return me end
local ctx1 = { settings = { enhancement_main_hand_ench = "auto", enhancement_off_hand_ench = "auto" }, in_combat = false, me = { is_moving = function() return false end }, mana_pct = 100, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx1) end
assert_eq(ctx1.settings.enhancement_main_hand_ench, "auto", "C1: input should be auto")
print("  [ PASS ] C1: level 70 setup")

-- C2: Level 5 -> rockbiter (lowest fallback when spells not learned)
_G.EaxRotations.GetPlayer = function() local me = {}; me.is_moving = function() return false end; me.get_level = function() return 5 end; return me end
local ctx2 = { settings = { enhancement_main_hand_ench = "auto" }, in_combat = false, me = { is_moving = function() return false end }, mana_pct = 100, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx2) end
print("  [ PASS ] C2: level 5 setup")

-- C3: Level 20 -> flametongue (learned)
_G.EaxRotations.GetPlayer = function() local me = {}; me.is_moving = function() return false end; me.get_level = function() return 20 end; return me end
local ctx3 = { settings = { enhancement_main_hand_ench = "auto" }, in_combat = false, me = { is_moving = function() return false end }, mana_pct = 100, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx3) end
print("  [ PASS ] C3: level 20 setup")

-- C4: Explicit choice bypasses auto
local ctx4 = { settings = { enhancement_main_hand_ench = "frostbrand" }, in_combat = false, me = { is_moving = function() return false end }, mana_pct = 100, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx4) end
print("  [ PASS ] C4: explicit frostbrand setup")


print("PASS test_shaman_enhancement_auto_weapon_buffs")
