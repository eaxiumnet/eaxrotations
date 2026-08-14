-- test_spell_damage_snapshot_sylvanas.lua -- Phase 2.1 snapshot-engine gating tests.
-- WHAT:  proves the player_spell_damage menu setting gates the DoT snapshot engines:
--        setting=0 (default) -> context.spell_damage absent -> byte-equivalent behavior
--        (no snapshot upgrades / min-SP gates / extended refresh windows);
--        setting>0 -> engines demonstrable per class:
--          * affliction + destruction: DoT upgrade decision flips
--          * shadow: SW:P/VT/DP snapshot upgrade ratio
--          * elemental: Flame Shock spellpower gate
--          * balance: Insect Swarm / Moonfire min-SP gates
-- WHEN:  During rotation test suite execution.
-- WHY:   main_sylvanas.lua populates context.spell_damage ONLY when the setting is > 0
--        (2s-throttled read); every consumer gates its snapshot machinery on
--        context.spell_damage > 0, so default behavior is byte-identical. These tests
--        pin both sides of the gate.
-- SAFETY: Synthetic mocks (same pattern as test_affliction_corruption_spam_regression /
--         test_shadow_refresh_windows / test_destruction_dsl_priority /
--         test_elemental_custom_matches / test_balance_custom_matches); no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- Shared stubs used by every spec section (preloaded so hard requires resolve).
package.loaded["shared/potion_helper_sylvanas"] = {}
package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { potions = {} }, SPELLS = { shaman = {} } }
package.loaded["shared/pet_manager_sylvanas"] = {
    set_defensive = function() end, set_passive = function() end, set_aggressive = function() end,
}
package.loaded["shared/dot_ttd_gating_sylvanas"] = {
    should_skip_dot = function() return false end,
    should_skip_dot_from_context = function() return false end,
    DOT_DURATIONS = {
        corruption = 18, unstable_affliction = 18, siphon_life = 30, immolate = 15,
        vampiric_touch = 15, shadow_word_pain = 18,
    },
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
package.loaded["common/modules/buff_manager"] = {
    get_debuff_cache = function() return {} end,
}
package.loaded["shared/offensive_dispel_sylvanas"] = {}
package.loaded["shared/mf_tick_compute_sylvanas"] = {
    compute_channel_state = function() return false, 0 end,
    should_clip_mf = function() return false end,
}

local orig_pcall = _G.pcall
local orig_require = _G.require
-- Intercept the two pcalled optional requires so they never hit disk under mocks.
_G.pcall = function(fn, path, ...)
    if type(path) == "string" then
        if path:find("tbc_data_sylvanas") then return true, package.loaded["shared/tbc_data_sylvanas"] end
        if path:find("izi_sdk") then return false, nil end
        if path:find("dot_ttd_gating_sylvanas") then return true, package.loaded["shared/dot_ttd_gating_sylvanas"] end
        if path:find("pet_manager") then return true, package.loaded["shared/pet_manager_sylvanas"] end
        if path:find("potion_helper") then return true, package.loaded["shared/potion_helper_sylvanas"] end
    end
    return orig_pcall(fn, path, ...)
end
_G.require = function(path)
    if type(path) == "string" then
        if path:find("tbc_data_sylvanas") then return package.loaded["shared/tbc_data_sylvanas"] end
        if path:find("offensive_dispel") then return package.loaded["shared/offensive_dispel_sylvanas"] end
        if path:find("izi_sdk") then return nil end
        if path:find("dot_ttd_gating") then return package.loaded["shared/dot_ttd_gating_sylvanas"] end
        if path:find("pet_manager") then return package.loaded["shared/pet_manager_sylvanas"] end
        if path:find("potion_helper") then return package.loaded["shared/potion_helper_sylvanas"] end
    end
    return orig_require(path)
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- Shallow-merge helper for the shadow section's base-state overrides.
local function vmerge(base, overrides)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(overrides) do out[k] = v end
    return out
end

-- ============================================================================
-- 1. AFFLICTION: Unstable Affliction snapshot upgrade (extended window, gated)
-- ============================================================================
local affl_ok, affl_err = pcall(function()
    _G.EaxRotations = {
        WarlockSpells = {
            DeathCoil = { ids = { 27223 } }, Soulshatter = { ids = { 29858 } },
            ShadowBolt = { ids = { 27209 } }, Corruption = { ids = { 27216 } },
            UnstableAffliction = { ids = { 30405 } }, SiphonLife = { ids = { 30911 } },
            CurseOfDoom = { ids = { 30910 } }, CurseOfAgony = { ids = { 27218 } },
            Immolate = { ids = { 27215 } }, SeedOfCorruption = { ids = { 27285 } },
            LifeTap = { ids = { 27222 } },
        },
        spell_action = function(tbl) return tbl end,
        has_player_buff = function() return false end,
        debuff_remains = function() return 0 end,
        buff_remains = function() return 0 end,
        get_debuff_stacks = function() return 0 end,
        spell_ready = function() return true end,
        is_spell_learned = function() return true end,
        is_api_health_broken = function() return false end,
        is_item_ready = function() return false end,
        has_item = function() return false end,
        log = function() end,
        time_now = function() return 1000 end,
        cooldown_remains = function() return 0 end,
        rotation_registry = { register = function() end },
    }
    package.loaded["EaxRotations/classes/warlock/affliction_sylvanas.lua"] = nil
    local affl = dofile("EaxRotations/classes/warlock/affliction_sylvanas.lua")
    assert_true(affl and affl.strategies, "affliction strategies should load")
    local ua = find_strategy(affl.strategies, "UnstableAffliction")

    -- build_state: setting off (no context.spell_damage) -> state.spell_damage == 0
    local s0 = affl.build_state({ now = 1000, target = nil, mana_pct = 80, hp = 100, enemy_count = 1, in_combat = true })
    assert_eq(s0.spell_damage, 0, "affliction: spell_damage 0 with setting off")
    -- build_state: setting on (context.spell_damage populated) -> state.spell_damage == 500
    local s1 = affl.build_state({ now = 2000, target = nil, mana_pct = 80, hp = 100, enemy_count = 1, in_combat = true, spell_damage = 500 })
    assert_eq(s1.spell_damage, 500, "affliction: spell_damage 500 with setting on")

    -- Byte-equivalence (setting 0): plain window guard unchanged.
    local ctx0 = { has_valid_enemy_target = true, ttd_known = true, ttd = 30, settings = { dot_ttd_threshold = 50 } }
    assert_false(ua.matches(ctx0, { ua_remains = 2.0, spell_damage = 0, snapshot_ua_dmg = 0, has_bloodlust = false }),
        "affliction(0): UA held at 2.0s (beyond 1.5s window)")
    assert_true(ua.matches(ctx0, { ua_remains = 1.0, spell_damage = 0, snapshot_ua_dmg = 0, has_bloodlust = false }),
        "affliction(0): UA refreshed within 1.5s window")

    -- Setting on: extended-window upgrade decision flips on the 8% ratio.
    local ctx_on = { has_valid_enemy_target = true, ttd_known = true, ttd = 30, settings = { dot_ttd_threshold = 50 }, spell_damage = 110 }
    assert_true(ua.matches(ctx_on, { ua_remains = 2.0, spell_damage = 110, snapshot_ua_dmg = 100, has_bloodlust = false }),
        "affliction(on): UA refreshed at 2.0s when 110 >= 100 * 1.08")
    assert_false(ua.matches(ctx_on, { ua_remains = 2.0, spell_damage = 90, snapshot_ua_dmg = 100, has_bloodlust = false }),
        "affliction(on): UA held at 2.0s when 90 < 100 * 1.08 (no upgrade)")
    -- Beyond the extended window the refresh is held even with an upgrade.
    assert_false(ua.matches(ctx_on, { ua_remains = 3.2, spell_damage = 110, snapshot_ua_dmg = 100, has_bloodlust = false }),
        "affliction(on): UA held beyond window + REFRESH_EXTRA_WINDOW (3.0s)")
end)
assert_true(affl_ok, "affliction section: " .. tostring(affl_err))

-- ============================================================================
-- 2. SHADOW: SW:P / VT / DP snapshot ratio (gated extended windows)
-- ============================================================================
local shadow_ok, shadow_err = pcall(function()
    _G.EaxRotations = {
        PriestSpells = {
            ShadowWordPain = 25368, VampiricTouch = 34917, MindBlast = 8092,
            ShadowWordDeath = 32379, Shadowform = 15473, InnerFire = 588,
            InnerFocus = 14751, MindFlay = 15407, PsychicScream = 8122,
            DispelMagic = 528, ShackleUndead = 9484, DevouringPlague = 2944,
            FlashHeal = 2061, PowerWordShield = 17, PowerWordFortitude = 1243,
            VampiricEmbrace = 15286, Shadowfiend = 34433, Berserking = 26297,
            BloodFury = 33697, ArcaneTorrent = 28730, Starshards = 10797,
            HolyNova = 15237,
        },
        action_matches = function() return true end,
        action_execute = function() return true end,
        spell_ready = function(spell, target, opts) return true end,
        spell_exists = function(spell) return true end,
        debuff_remains = function(target, ids) return 0 end,
        debuff_up = function() return false end,
        buff_up = function() return false end,
        log = function() end,
        time_now = function() return 100 end,
        cooldown_remains = function() return 0 end,
        rotation_registry = { register = function() end },
        GetPlayer = function() return {} end,
        GetTarget = function() return nil end,
        GetEnemiesInRange = function() return {} end,
        unit_mana_pct = function() return 80 end,
        unit_health_pct = function() return 100 end,
        get_debuff_stacks = function() return 5 end,
        is_threat_safe = function() return true end,
    }
    package.loaded["EaxRotations/classes/priest/shadow_sylvanas.lua"] = nil
    local shadow = dofile("EaxRotations/classes/priest/shadow_sylvanas.lua")
    local strategies = shadow.strategies or shadow
    assert_true(strategies, "shadow strategies should load")
    local dp = find_strategy(strategies, "DevouringPlague")
    local vt = find_strategy(strategies, "VampiricTouch")
    local swp = find_strategy(strategies, "ShadowWordPain")

    -- DP: byte-equivalence (setting 0) — plain dp_window guard unchanged.
    local ctx0 = { in_combat = true, has_valid_enemy_target = true, ttd_known = false, ttd = 0, settings = {} }
    assert_false(dp.matches(ctx0, { devouring_plague_known = true, mf_channeling = false, should_clip_mf = true,
        dp_remaining = 4.0, dp_refresh_window = 3, spell_damage = 0, snapshot_dp_dmg = 0, mana_emergency = false }),
        "shadow(0): DP held at 4.0s (beyond 3s window)")
    assert_true(dp.matches(ctx0, { devouring_plague_known = true, mf_channeling = false, should_clip_mf = true,
        dp_remaining = 3.0, dp_refresh_window = 3, spell_damage = 0, snapshot_dp_dmg = 0, mana_emergency = false }),
        "shadow(0): DP refreshed within 3s window")

    -- DP: setting on — extended-window ratio flip.
    local ctx_on = { in_combat = true, has_valid_enemy_target = true, ttd_known = false, ttd = 0, settings = {}, spell_damage = 110 }
    assert_true(dp.matches(ctx_on, { devouring_plague_known = true, mf_channeling = false, should_clip_mf = true,
        dp_remaining = 3.5, dp_refresh_window = 3, spell_damage = 110, snapshot_dp_dmg = 100, mana_emergency = false }),
        "shadow(on): DP refreshed at 3.5s when 110 >= 100 * 1.08")
    assert_false(dp.matches(ctx_on, { devouring_plague_known = true, mf_channeling = false, should_clip_mf = true,
        dp_remaining = 3.5, dp_refresh_window = 3, spell_damage = 90, snapshot_dp_dmg = 100, mana_emergency = false }),
        "shadow(on): DP held at 3.5s when 90 < 100 * 1.08 (no upgrade)")

    -- VT: byte-equivalence (setting 0) — plain clip guard unchanged.
    local vstate = { vampiric_touch_known = true, mana_emergency = false, has_bloodlust = false,
        mf_channeling = false, should_clip_mf = true }
    local vctx0 = { in_combat = true, has_valid_enemy_target = true, is_moving = false, is_casting = false,
        is_channeling = false, ttd_known = false, ttd = 0, settings = {} }
    assert_false(vt.matches(vctx0, vmerge(vstate, { vt_remaining = 2.0, spell_damage = 0, snapshot_vt_dmg = 0 })),
        "shadow(0): VT held at 2.0s (beyond 1.5s clip)")
    assert_true(vt.matches(vctx0, vmerge(vstate, { vt_remaining = 1.0, spell_damage = 0, snapshot_vt_dmg = 0 })),
        "shadow(0): VT refreshed within 1.5s clip")

    -- VT: setting on — extended-window ratio flip.
    local vctx_on = { in_combat = true, has_valid_enemy_target = true, is_moving = false, is_casting = false,
        is_channeling = false, ttd_known = false, ttd = 0, settings = {}, spell_damage = 110 }
    assert_true(vt.matches(vctx_on, vmerge(vstate, { vt_remaining = 2.0, spell_damage = 110, snapshot_vt_dmg = 100 })),
        "shadow(on): VT refreshed at 2.0s when 110 >= 100 * 1.08")
    assert_false(vt.matches(vctx_on, vmerge(vstate, { vt_remaining = 2.0, spell_damage = 90, snapshot_vt_dmg = 100 })),
        "shadow(on): VT held at 2.0s when 90 < 100 * 1.08 (no upgrade)")

    -- SW:P: setting on — weaving case, extended-window ratio flip.
    local swp_ctx_on = { in_combat = true, has_valid_enemy_target = true, ttd_known = false, ttd = 0, settings = {}, spell_damage = 110 }
    local swp_state = { swp_known = true, mana_emergency = false, weaving_stacks = 5, mf_channeling = false, should_clip_mf = true }
    assert_true(swp.matches(swp_ctx_on, vmerge(swp_state, { swp_remaining = 2.0, spell_damage = 110, snapshot_swp_dmg = 100 })),
        "shadow(on): SW:P refreshed at 2.0s when 110 >= 100 * 1.08")
    assert_false(swp.matches(swp_ctx_on, vmerge(swp_state, { swp_remaining = 2.0, spell_damage = 90, snapshot_swp_dmg = 100 })),
        "shadow(on): SW:P held at 2.0s when 90 < 100 * 1.08 (no upgrade)")
    -- Byte-equivalence for SW:P with setting 0: in-window refresh unchanged
    -- (weaving_stacks=5 keeps the 1.5s clip window — 2.0s remains is held
    -- exactly like before the Phase 2.1 wiring).
    local swp_ctx0 = { in_combat = true, has_valid_enemy_target = true, ttd_known = false, ttd = 0, settings = {} }
    assert_false(swp.matches(swp_ctx0, vmerge(swp_state, { swp_remaining = 2.0, spell_damage = 0, snapshot_swp_dmg = 0 })),
        "shadow(0): SW:P held at 2.0s (beyond clip, no snapshot engine)")
    assert_true(swp.matches(swp_ctx0, vmerge(swp_state, { swp_remaining = 1.0, spell_damage = 0, snapshot_swp_dmg = 0 })),
        "shadow(0): SW:P refreshed within the 1.5s clip")
end)
assert_true(shadow_ok, "shadow section: " .. tostring(shadow_err))

-- ============================================================================
-- 3. ELEMENTAL: Flame Shock spellpower gate
-- ============================================================================
local ele_ok, ele_err = pcall(function()
    _G.EaxRotations = {
        ShamanSpells = {
            LightningShield = 25472, WaterShield = 32594, GhostWolf = 2645,
            TremorTotem = 8143, EarthbindTotem = 2484, ManaTideTotem = 16190,
            ElementalMastery = 16166, NaturesSwiftness = 16188, Bloodlust = 2825,
            ChainLightning = 25442, LightningBolt = 25449, FlameShock = 25457,
            ChainHeal = 25423, EarthShock = 25454, FrostShock = 25464,
            FireNovaTotem = 25547, MagmaTotem = 25552, TotemicCall = 16191,
            FlametongueWeapon = 25489, WindfuryWeapon = 25505, RockbiterWeapon = 25485,
            HealingWave = 25396, TotemOfWrath = 30706, WrathOfAirTotem = 3738,
            ManaSpringTotem = 25570,
        },
        has_player_buff = function(buff_list) return false end,
        buff_remains = function(me, ids) return 0 end,
        debuff_remains = function(target, ids) return 0 end,
        spell_ready = function(spell, target, opts) return true end,
        is_spell_learned = function(id) return true end,
        broken_api_throttled = function(spell, seconds) return false end,
        game_time_ms = function() return 100000 end,
        log = function() end,
        should_refresh_dot = function(remains, window, ttd, dur) return true end,
        rotation_registry = { register = function() end },
    }
    package.loaded["EaxRotations/classes/shaman/elemental_sylvanas.lua"] = nil
    local strategies = dofile("EaxRotations/classes/shaman/elemental_sylvanas.lua").strategies
    assert_true(strategies, "elemental strategies should load")
    local fs = find_strategy(strategies, "FlameShock")

    -- Byte-equivalence (setting 0): refresh-window-only behavior unchanged.
    assert_true(fs.matches({ target = {}, settings = { elemental_flame_shock_min_sp = 400 } },
        { flame_remains = 0.5, spell_damage = 0 }), "elemental(0): FlameShock refresh allowed (gate inert)")

    -- Setting on: min-SP gate flips on the 400 threshold.
    assert_false(fs.matches({ target = {}, settings = { elemental_flame_shock_min_sp = 400 }, spell_damage = 300 },
        { flame_remains = 0.5, spell_damage = 300 }), "elemental(on): FlameShock held below 400 SP")
    assert_true(fs.matches({ target = {}, settings = { elemental_flame_shock_min_sp = 400 }, spell_damage = 500 },
        { flame_remains = 0.5, spell_damage = 500 }), "elemental(on): FlameShock cast at 500 SP")
end)
assert_true(ele_ok, "elemental section: " .. tostring(ele_err))

-- ============================================================================
-- 4. BALANCE: Insect Swarm / Moonfire min-SP gates
-- ============================================================================
local balance_ok, balance_err = pcall(function()
    _G.EaxRotations = {
        DruidSpells = {
            Barkskin = "Barkskin", FaerieFire = "FaerieFire", FaerieFireFeral = "FaerieFireFeral",
            ForceOfNature = "ForceOfNature", Hurricane = "Hurricane", InsectSwarm = "InsectSwarm",
            Moonfire = "Moonfire", MoonkinForm = "MoonkinForm", Starfire = "Starfire",
            Wrath = "Wrath",
        },
        action_matches = function(ctx, act) return true end,
        action_execute = function(ctx, act, prefix) return true end,
        spell_ready = function(spell, target, opts) return true end,
        same_unit = function(a, b) return a == b end,
        GetPlayer = function() return "self" end,
        debuff_remains = function(target, debuff_list) return target and target._debuff_remains or 0 end,
        player_buff_remains = function(buff_list) return 0 end,
        has_player_buff = function(buff_list) return false end,
        buff_up = function(unit, ids) return false end,
        broken_api_throttled = nil,
        PLAYER_UNIT = "player",
        should_refresh_dot = function(remains, refresh, ttd, duration) return true end,
        spell_action = function(ids, name) return { name = name, ids = ids } end,
        try_cast = function(spell, target, reason, opts) return true end,
        log = function() end,
        rotation_registry = { register = function() end },
    }
    package.loaded["EaxRotations/classes/druid/balance_sylvanas.lua"] = nil
    local module = dofile("EaxRotations/classes/druid/balance_sylvanas.lua")
    local strategies = module.strategies or module
    assert_true(strategies, "balance strategies should load")
    local insect = find_strategy(strategies, "InsectSwarmDoT")
    local moonfire = find_strategy(strategies, "MoonfireDoT")

    -- Byte-equivalence (setting 0): DoTs refresh regardless of SP.
    local ctx0 = { target = {}, has_valid_enemy_target = true, ttd = 60, settings = {} }
    assert_true(insect.matches(ctx0, { insect_remains = 0, spell_damage = 0 }),
        "balance(0): InsectSwarm refresh allowed (min-SP gate inert)")
    assert_true(moonfire.matches(ctx0, { moonfire_remains = 1, spell_damage = 0 }),
        "balance(0): Moonfire refresh allowed (min-SP gate inert)")

    -- Setting on: min-SP gate flips on the 800 default floor.
    local ctx_on_low = { target = {}, has_valid_enemy_target = true, ttd = 60, settings = {}, spell_damage = 500 }
    assert_false(insect.matches(ctx_on_low, { insect_remains = 0, spell_damage = 500 }),
        "balance(on): InsectSwarm held below 800 SP")
    assert_false(moonfire.matches(ctx_on_low, { moonfire_remains = 1, spell_damage = 500 }),
        "balance(on): Moonfire held below 800 SP")
    local ctx_on_high = { target = {}, has_valid_enemy_target = true, ttd = 60, settings = {}, spell_damage = 900 }
    assert_true(insect.matches(ctx_on_high, { insect_remains = 0, spell_damage = 900 }),
        "balance(on): InsectSwarm cast at 900 SP")
    assert_true(moonfire.matches(ctx_on_high, { moonfire_remains = 1, spell_damage = 900 }),
        "balance(on): Moonfire cast at 900 SP")
end)
assert_true(balance_ok, "balance section: " .. tostring(balance_err))

-- ============================================================================
-- 5. DESTRUCTION: Immolate min-SP gate (re-added, gated on the setting)
-- ============================================================================
local destro_ok, destro_err = pcall(function()
    local NS = {}
    _G.EaxRotations = NS
    NS.WarlockSpells = {
        Conflagrate = 30912, Corruption = 27216, CurseOfAgony = 27218, CurseOfDoom = 30910,
        CurseElements = 27228, CurseOfRecklessness = 27226, CurseOfWeakness = 30909,
        DeathCoil = 27223, FelArmor = 28189, Immolate = 27215, Incinerate = 32231,
        LifeTap = 27222, ShadowBolt = 27209, Shadowburn = 30546, Shadowfury = 30414,
        ShadowWard = 28610, Soulshatter = 29858,
    }
    NS.PLAYER_UNIT = {
        get_health = function() return 100 end, get_health_percentage = function() return 100 end,
        is_valid = function() return true end, is_dead = function() return false end,
        is_casting = function() return false end, is_mounted = function() return false end,
        get_guid = function() return "player" end, get_target = function() return nil end,
    }
    NS.GetPlayer = function() return NS.PLAYER_UNIT end
    NS.GetTarget = function() return nil end
    NS.buff_up = function() return false end
    NS.debuff_up = function() return false end
    NS.debuff_remains = function() return 0 end
    NS.get_debuff_stacks = function() return 0 end
    NS.spell_ready = function() return true end
    NS.try_cast = function() return true end
    NS.unit_mana_pct = function() return 100 end
    NS.unit_health_pct = function() return 100 end
    NS.time_now = function() return 0 end
    NS.game_time_ms = function() return 0 end
    NS.broken_api_throttled = function() return false end
    NS.cooldown_remains = function() return 0 end
    NS.spell_exists = function() return true end
    NS.is_item_ready = function() return false end
    NS.has_item = function(id) return true end
    NS.is_auto_attacking = function() return false end
    NS.gate_cooldown_boss_only = function() return true end
    NS.is_spell_learned = function() return true end
    NS.is_interruptible = function() return true end
    NS.is_in_combat = function() return false end
    NS.should_use_long_cd = function() return true end
    NS.is_execute_phase = function(target_hp, threshold) return (target_hp or 100) <= (threshold or 20) end
    NS.should_refresh_dot = function(remains, pandemic, ttd, duration) return (remains or 0) <= (pandemic or 3) end
    NS.log = function() end
    NS.log_warning = function() end
    NS.rotation_registry = { register = function() end }
    NS.AOE_RADIUS = { GROUND_8 = 8, SELF_10 = 10 }
    NS.aoe_self_meets = function() return false end
    NS.aoe_target_meets = function() return false end
    NS.cast_ground_aoe = function() return false end
    NS.get_aoe_cast_position = function() return nil end
    NS.get_spell_id = function(spell) return spell end
    NS.try_cast_position = function() return false end
    NS.use_item_by_id = function() return false end
    NS.spell_action = function(arg, label)
        if type(arg) == "table" then
            if arg.ids then return arg end
            return arg[1] or 0
        end
        return arg or 0
    end

    -- Mock spec_kit (same as test_destruction_dsl_priority.lua).
    local _setting = function(context, key, default)
        if context and context.settings and context.settings[key] ~= nil then
            return context.settings[key]
        end
        return default
    end
    local mock_spec_kit = {
        merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
        define_action_for_class = function(SPELLS)
            return function(field, rank_ids, label)
                if SPELLS and SPELLS[field] then return SPELLS[field] end
                return rank_ids and rank_ids[1] or field
            end
        end,
        safe_state = function(raw, schema)
            return setmetatable({}, {
                __index = function(t, k)
                    if raw[k] ~= nil then return raw[k] end
                    if schema and schema[k] ~= nil then return schema[k] end
                    return nil
                end,
            })
        end,
        setting = _setting,
        setting_bool = function(context, key, default)
            local v = _setting(context, key, nil)
            if v == nil then return default end
            return v ~= false
        end,
        setting_number = function(context, key, default)
            local v = _setting(context, key, nil)
            if type(v) == "number" then return v end
            return default
        end,
    }
    package.loaded["shared/spec_kit_sylvanas"] = mock_spec_kit
    package.loaded["shared/warlock_curse_helper_sylvanas"] = {
        CURSE_REFRESH_WINDOW = 3,
        CURSE_OF_RECKLESSNESS_DEBUFF = { 27226 },
        CURSE_OF_WEAKNESS_DEBUFF = { 30909 },
        other_curse_active = function() return false end,
    }
    package.loaded["shared/warlock_soulshatter_sylvanas"] = dofile("EaxRotations/shared/warlock_soulshatter_sylvanas.lua")
    package.loaded["shared/warlock_healthstone_sylvanas"] = dofile("EaxRotations/shared/warlock_healthstone_sylvanas.lua")
    package.loaded["shared/warlock_mana_gem_sylvanas"] = dofile("EaxRotations/shared/warlock_mana_gem_sylvanas.lua")
    package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

    package.loaded["EaxRotations/classes/warlock/destruction_sylvanas.lua"] = nil
    local destruction = dofile("EaxRotations/classes/warlock/destruction_sylvanas.lua")
    local strategies = destruction.strategies
    assert_true(strategies, "destruction strategies should load")
    local immolate = find_strategy(strategies, "Immolate")

    local function make_ctx(overrides)
        local ctx = {
            me = NS.PLAYER_UNIT,
            target = { is_valid = function() return true end, is_dead = function() return false end,
                       is_casting = function() return false end, get_health_percentage = function() return 100 end,
                       get_creature_type = function() return nil end, get_guid = function() return "target" end,
                       get_target = function() return NS.PLAYER_UNIT end },
            in_combat = true,
            hp = 100,
            hp_pct = 100,
            mana_pct = 80,
            target_hp = 100,
            settings = { warlock_assigned_curse = "none", warlock_curse_mode = "auto" },
            is_pvp = false,
            is_moving = false,
            is_casting = false,
            is_channeling = false,
            ttd_known = false,
            ttd = 999,
        }
        for k, v in pairs(overrides or {}) do ctx[k] = v end
        return ctx
    end
    local function make_state(overrides)
        local s = { immolate_remains = 0, corruption_remains = 0, cod_remains = 0, coa_remains = 0,
            coe_remains = 0, recklessness_remains = 0, weakness_remains = 0, has_backlash = false,
            has_backdraft = false, has_fel_armor = false, has_demon_armor = false, has_shadow_ward = false,
            has_demonic_sacrifice = false, hp = 100, mana_pct = 100, spell_damage = 0, level = 70 }
        for k, v in pairs(overrides or {}) do s[k] = v end
        return s
    end

    -- Byte-equivalence (setting 0): Immolate matches regardless of SP.
    assert_true(immolate.matches(make_ctx(), make_state({ spell_damage = 200, level = 70 })),
        "destro(0): Immolate matches with low SP when the setting is off")

    -- Setting on: min-SP gate flips on the 400 default.
    assert_false(immolate.matches(make_ctx({ spell_damage = 300 }), make_state({ spell_damage = 300, level = 70 })),
        "destro(on): Immolate held below 400 SP")
    assert_true(immolate.matches(make_ctx({ spell_damage = 500 }), make_state({ spell_damage = 500, level = 70 })),
        "destro(on): Immolate cast at 500 SP")
    -- Below level 40 the gate never engages even with the setting on.
    assert_true(immolate.matches(make_ctx({ spell_damage = 300 }), make_state({ spell_damage = 300, level = 30 })),
        "destro(on): Immolate not SP-gated below level 40")
end)
assert_true(destro_ok, "destruction section: " .. tostring(destro_err))

-- ============================================================================
-- Restore globals before leaving (runner also restores, but stay clean in-file).
-- ============================================================================
_G.pcall = orig_pcall
_G.require = orig_require

print("PASS test_spell_damage_snapshot_sylvanas")
