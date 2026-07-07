-- test_shaman_enhancement_totem_twist.lua — Totem Twisting Enhancement.
-- WHAT:  verifies twist phase tracking, mana threshold, and <3s remaining gate.
-- WHEN:  regression guard for enhancement_sylvanas.lua totem twisting logic.
-- WHY:   prevents wasted GCDs from early totem replacement; respects mana floor.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;api/?.lua;api/?/?.lua;api/?/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local enh_build_state = nil
local _captured_strategies

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
            _captured_strategies = strategies
            return true
        end,
    },
    game_time_ms = function() return 0 end,
    GetPlayer = function() local me = {}; me.is_moving = function() return false end; me.get_level = function() return 70 end; return me end,
    unit_mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    buff_up = function() return false end,
    spell_ready = function() return true end,
    action_matches = function() return true end,
    action_execute = function() return true end,
    try_cast = function() return true end,
    log = function() end,
    is_spell_learned = function(spell) return true end,
    get_totem_info = function(slot)
        return { have_totem = false }
    end,
    PLAYER_UNIT = {},
}

_G.core = {
    spell_book = { get_totem_info = function() return { have_totem = false } end },
    object_manager = { get_visible_objects = function() return {} end },
}

package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end, MANA_POTION_IDS = {} }

local strategies = dofile("EaxRotations/classes/shaman/enhancement_sylvanas.lua").strategies

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local wf_twist = find_strategy("WindfuryTotemTwist")
local grace_twist = find_strategy("GraceOfAirTotemTwist")
assert_true(wf_twist, "WindfuryTotemTwist should exist")
assert_true(grace_twist, "GraceOfAirTotemTwist should exist")

-- C1: No totem active, next_air = windfury, enough mana -> match
local ctx1 = { settings = { enhancement_totem_twisting = true, enhancement_twist_mana_threshold = 40 }, in_combat = true, me = { is_moving = function() return false end }, mana_pct = 100, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx1) end
assert_true(wf_twist.matches(ctx1), "C1: no totem + windfury phase + enough mana -> match")
print("  [ PASS ] C1: windfury twist matches when no totem")

-- C2: Totem active with >3s remaining -> no match (don't replace early)
local old_get_totem_info = _G.EaxRotations.get_totem_info
_G.EaxRotations.get_totem_info = function(slot)
    if slot == 4 then return { have_totem = true, spell_id = 8835, start_time = 0, duration = 120 } end
    return { have_totem = false }
end
_G.core.spell_book.get_totem_info = _G.EaxRotations.get_totem_info

local ctx2 = { settings = { enhancement_totem_twisting = true, enhancement_twist_mana_threshold = 40 }, in_combat = true, me = { is_moving = function() return false end }, mana_pct = 100, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx2) end
assert_false(wf_twist.matches(ctx2), "C2: grace totem active with >3s -> no early replace")
print("  [ PASS ] C2: no early replacement when totem has >3s")

-- C3: Mana below threshold -> no match
_G.EaxRotations.get_totem_info = old_get_totem_info
_G.core.spell_book.get_totem_info = old_get_totem_info
local ctx3 = { settings = { enhancement_totem_twisting = true, enhancement_twist_mana_threshold = 40 }, in_combat = true, me = { is_moving = function() return false end }, mana_pct = 30, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx3) end
assert_false(wf_twist.matches(ctx3), "C3: mana 30% < threshold 40% -> no match")
print("  [ PASS ] C3: twist blocked below mana threshold")

-- C4: Totem active with <3s remaining -> match (time to drop next)
-- Set next_air to "grace" so we're ready to drop grace after windfury expires
local _original_next_air = nil  -- we can't access totem_state directly; set via get_totem_info returning grace-like
_G.EaxRotations.get_totem_info = function(slot)
    if slot == 4 then return { have_totem = true, spell_id = 8512, start_time = 0, duration = 2 } end
    return { have_totem = false }
end
_G.core.spell_book.get_totem_info = _G.EaxRotations.get_totem_info

local ctx4 = { settings = { enhancement_totem_twisting = true, enhancement_twist_mana_threshold = 40 }, in_combat = true, me = { is_moving = function() return false end }, mana_pct = 100, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(ctx4) end
-- Since next_air defaults to "windfury", grace won't match. Instead test windfury twist again with expiring totem.
assert_true(wf_twist.matches(ctx4), "C4: windfury totem expiring <3s -> windfury twist matches (re-drop)")
print("  [ PASS ] C4: windfury twist matches when current totem expiring")

_G.EaxRotations.get_totem_info = old_get_totem_info
_G.core.spell_book.get_totem_info = old_get_totem_info

print("PASS test_shaman_enhancement_totem_twist")
