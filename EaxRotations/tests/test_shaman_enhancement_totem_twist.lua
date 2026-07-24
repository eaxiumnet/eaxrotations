-- test_shaman_enhancement_totem_twist.lua — Totem Twisting Enhancement.
-- WHAT:  verifies Windfury/Grace-of-Air twisting follows the 10s WF proc buff,
--         not the physical totem's 120s lifespan.
-- WHEN:  regression guard for enhancement_sylvanas.lua totem twisting logic.
-- WHY:   prevents "twists ground only" where totems were dropped but never
--         refreshed at the correct 10-second cadence.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;api/?.lua;api/?/?.lua;api/?/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local enh_build_state = nil
local _captured_strategies

local _time_ms = 0
local _buffs = { Windfury = 0, Grace = 0 }

local WF_IDS = { [8512]=true, [10607]=true, [10611]=true, [25585]=true, [25587]=true }
local GOA_IDS = { [8835]=true, [10626]=true, [10627]=true, [25359]=true }

local function aura_remains_for(ids)
    if type(ids) == "number" then
        if WF_IDS[ids] then return _buffs.Windfury end
        if GOA_IDS[ids] then return _buffs.Grace end
        return 0
    end
    if type(ids) == "table" then
        for _, id in ipairs(ids) do
            if WF_IDS[id] then return _buffs.Windfury end
            if GOA_IDS[id] then return _buffs.Grace end
        end
    end
    return 0
end

local function aura_up_for(ids) return aura_remains_for(ids) > 0 end

_G.EaxRotations = {
    ShamanSpells = {
        LightningShield = { 324 }, WaterShield = { 33736 },
        ShamanisticRage = { 30823 }, Bloodlust = { 2825 },
        Stormstrike = { 17364 }, FlameShock = { 8050 },
        EarthShock = { 8042 }, FrostShock = { 8056 },
        ChainLightning = { 421 }, LightningBolt = { 403 },
        WindfuryTotem = { 25587, 25585, 10614, 10613, 8512 },
        GraceOfAirTotem = { 25359, 10627, 8835 },
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
    game_time_ms = function() return _time_ms end,
    GetPlayer = function() local me = {}; me.is_moving = function() return false end; me.get_level = function() return 70 end; return me end,
    unit_mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    buff_up = function(unit, ids) return aura_up_for(ids) end,
    buff_remains = function(unit, ids) return aura_remains_for(ids) end,
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

local function ctx(mana_pct, settings)
    return {
        settings = settings or { enhancement_totem_twisting = true, enhancement_twist_mana_threshold = 40 },
        in_combat = true,
        me = { is_moving = function() return false end },
        mana_pct = mana_pct or 100,
        hp = 100,
        enemy_count = 1,
    }
end

-- C1: WF buff missing -> drop WF
_time_ms = 0
_buffs.Windfury = 0; _buffs.Grace = 0
local c1 = ctx(100)
if enh_build_state then enh_build_state(c1) end
assert_true(wf_twist.matches(c1), "C1: missing WF buff -> drop Windfury Totem")
print("  [ PASS ] C1: drop Windfury when its proc buff is missing")

-- C2: Healthy WF buff (>2s), no Grace -> drop GoA
_buffs.Windfury = 8.0; _buffs.Grace = 0
local c2 = ctx(100)
if enh_build_state then enh_build_state(c2) end
assert_false(wf_twist.matches(c2), "C2: healthy WF buff -> do NOT drop WF")
assert_true(grace_twist.matches(c2), "C2: healthy WF + missing Grace -> drop Grace of Air")
print("  [ PASS ] C2: with healthy WF buff, twist to Grace of Air")

-- C3: Both buffs healthy -> neither twist matches (avoid GCD waste)
_buffs.Windfury = 8.0; _buffs.Grace = 6.0
local c3 = ctx(100)
if enh_build_state then enh_build_state(c3) end
assert_false(wf_twist.matches(c3), "C3: both buffs up -> do NOT drop WF")
assert_false(grace_twist.matches(c3), "C3: both buffs up -> do NOT drop GoA")
print("  [ PASS ] C3: no totems cast while both buffs are healthy")

-- C4: WF buff expiring (<2s) -> refresh WF
_buffs.Windfury = 1.5; _buffs.Grace = 6.0
local c4 = ctx(100)
if enh_build_state then enh_build_state(c4) end
assert_true(wf_twist.matches(c4), "C4: WF expiring -> refresh Windfury Totem")
assert_false(grace_twist.matches(c4), "C4: WF expiring -> do NOT drop GoA")
print("  [ PASS ] C4: refresh Windfury Totem just before the proc buff expires")

-- C5: Mana below threshold -> blocked
_buffs.Windfury = 0; _buffs.Grace = 0
local c5 = ctx(30)
if enh_build_state then enh_build_state(c5) end
assert_false(wf_twist.matches(c5), "C5: mana below threshold -> no twist")
print("  [ PASS ] C5: twisting blocked below mana threshold")

-- C6: Out of combat -> blocked
local c6 = { settings = { enhancement_totem_twisting = true, enhancement_twist_mana_threshold = 40 }, in_combat = false, me = { is_moving = function() return false end }, mana_pct = 100, hp = 100, enemy_count = 1 }
if enh_build_state then enh_build_state(c6) end
assert_false(wf_twist.matches(c6), "C6: out of combat -> no twist")
assert_false(grace_twist.matches(c6), "C6: out of combat -> no twist")
print("  [ PASS ] C6: twisting disabled out of combat")

-- C7: 1.5s WF-specific throttle prevents immediate re-cast
_time_ms = 1000
_buffs.Windfury = 0; _buffs.Grace = 0
local c7 = ctx(100)
if enh_build_state then enh_build_state(c7) end
assert_true(wf_twist.matches(c7), "C7: pre-cast, missing WF -> drop WF")
wf_twist.execute(c7)  -- records last_wf_cast_ms
local c7b = ctx(100)
if enh_build_state then enh_build_state(c7b) end
assert_false(wf_twist.matches(c7b), "C7b: immediately after cast, WF throttle blocks WF")
-- GoA cannot match while there is no active WF buff/totem (not a shared throttle)
assert_false(grace_twist.matches(c7b), "C7b: no active WF yet -> GoA still blocked")
print("  [ PASS ] C7: 1.5s WF-specific throttle prevents immediate re-cast")

-- C8: after 1.5s, WF throttle clears; visible expiring WF buff -> recast
_time_ms = 3000
_buffs.Windfury = 1.5  -- visible but expiring (<2s), should refresh
local c8 = ctx(100)
if enh_build_state then enh_build_state(c8) end
assert_true(wf_twist.matches(c8), "C8: WF throttle expired + visible expiring WF -> recast")
print("  [ PASS ] C8: WF throttle clears after 1.5s and recasts on visible expiring WF")

-- C9: GoA fallback - if a WF totem is active but the aura isn't visible, still drop GoA
-- Mock an active WF totem (spell_id 25587) and no visible buffs.
_time_ms = 5000
_buffs.Windfury = 0; _buffs.Grace = 0
local old_get_totem_info = _G.EaxRotations.get_totem_info
_G.EaxRotations.get_totem_info = function(slot)
    if slot == 4 then return { have_totem = true, spell_id = 25587, start_time = 0, duration = 120 } end
    return { have_totem = false }
end
_G.core.spell_book.get_totem_info = _G.EaxRotations.get_totem_info
-- Cast WF first so last_wf_cast_ms is set and >= 0
local c9 = ctx(100)
if enh_build_state then enh_build_state(c9) end
wf_twist.execute(c9)
-- Advance past the 1.5s GoA-specific throttle before checking GoA fallback
_time_ms = 7000
local c9b = ctx(100)
if enh_build_state then enh_build_state(c9b) end
assert_true(grace_twist.matches(c9b), "C9: active WF totem + no visible aura -> still drop GoA")
-- Restore mock
_G.EaxRotations.get_totem_info = old_get_totem_info
_G.core.spell_book.get_totem_info = old_get_totem_info
print("  [ PASS ] C9: GoA falls back to active WF totem when aura is hidden")

print("PASS test_shaman_enhancement_totem_twist")
