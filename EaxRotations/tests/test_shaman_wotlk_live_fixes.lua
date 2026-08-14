-- test_shaman_wotlk_live_fixes.lua — Shaman WotLK wave-3.3 live fixes.
-- WHAT:  Match/build_state regression for the 2026-08-13 shaman WotLK fixes:
--        (1) elemental Wind Shear interrupt lane + Earth Shock era correction
--        (Earth Shock lost its kick in 3.0.2) + CD windows computed from
--        NS.spell_ready (never the phantom context flags) + Searing Totem /
--        Totem of Wrath slot-occupancy re-drops;
--        (2) enhancement Feral Spirit / Bloodlust / Shamanistic Rage readiness
--        via NS.spell_ready, Call of the Elements water-slot gate, Fire Nova
--        fire-slot gate, weapon-imbue upkeep lanes (Windfury 58804 /
--        Flametongue 58790);
--        (3) restoration Mana Tide via NS.spell_ready (5-min CD), Chain Heal on
--        the REAL engine field context.party_injured_count, friendly-target
--        healing (context.lowest.unit), charge-aware Earth Shield refresh
--        (NS.buff_points), Water Shield lane, Tidal Waves tracking;
--        (4) leveling Lava Burst max rank 60043 ladder, Flametongue imbue
--        refresh on a ~29.8-min window, shared fire-slot totem timestamp.
-- WHEN:  Registered in run_rotation_tests.lua (Wave 3.3 block).
--        Standalone: lua EaxRotations/tests/test_shaman_wotlk_live_fixes.lua
-- WHY:   Pins the W3.1 audit fixes so they cannot regress.
-- SAFETY: Pure unit tests with a mocked NS (test_warlock_wotlk_live_fixes
--         convention); real spec_kit + strategy_dsl loaded (real API shapes);
--         no game data, no filesystem writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq failed") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

-- ---------------------------------------------------------------------------
-- Leveling helpers stub (the leveling spec requires it).
-- ---------------------------------------------------------------------------
package.loaded["shared/leveling_helpers_sylvanas"] = {
    should_interrupt = function(target) return false end,
}

-- ---------------------------------------------------------------------------
-- NS mock. Real spec_kit + strategy_dsl are loaded (pure helpers; NS resolved
-- at call time) so assertions exercise the production resolution paths.
-- ---------------------------------------------------------------------------
local function make_ns(overrides)
    local ladder_records = {}   -- rank tables passed to NS.spell_action (spy)
    local spell_ready_records = {}
    local try_cast_records = {}
    local on_cd = {}            -- { [spell_id] = seconds } CD map
    local buff_points_map = {}  -- { [spell_id] = {points...} }
    local buff_stacks_map = {}  -- { [spell_id] = stacks }
    local totem_slots = {}      -- { [slot] = {have_totem=true} }
    local ns = {
        ShamanSpells = {
            -- TBC-era class table (mirrors classes/shaman/class_sylvanas.lua
            -- values): a spec still on define_action_for_class would resolve
            -- these and lose the WotLK rank ladder head.
            LightningBolt = 25449, FlameShock = 25457, EarthShock = 25454,
            SearingTotem = 25533, MagmaTotem = 25552, FlametongueWeapon = 25489,
            LavaBurst = 51505, LightningShield = 25472, HealingWave = 25396,
        },
        PLAYER_UNIT = {},
        spell_action = function(rank_ids, label)
            local ids = type(rank_ids) == "table" and rank_ids or { rank_ids }
            ladder_records[#ladder_records + 1] = { ids = ids, label = label }
            return {
                ids = ids,
                name = label,
                id = ids[1],
                IsReady = function(self) return true end,
                IsInRange = function(self) return true end,
                Cast = function(self) return true end,
            }
        end,
        GetPlayer = function()
            return {
                get_health_percentage = function(self) return 100 end,
                get_mana_percentage = function(self) return 100 end,
            }
        end,
        me = {
            get_health_percentage = function(self) return 100 end,
            get_mana_percentage = function(self) return 100 end,
        },
        spell_ready = function(spell, target, opts)
            spell_ready_records[#spell_ready_records + 1] = { spell = spell, opts = opts }
            local id = type(spell) == "table" and (spell.ids and spell.ids[1] or spell.id) or spell
            if on_cd[id] then return false end
            return true
        end,
        try_cast = function(spell, unit, reason, opts)
            try_cast_records[#try_cast_records + 1] = { spell = spell, unit = unit, reason = reason }
            return true
        end,
        -- Map-aware buff_up: a buff_points_map entry means the aura is active
        -- (used by the Earth Shield charge-refresh tests).
        buff_up = function(unit, ids)
            for _, id in ipairs(ids or {}) do
                if buff_points_map[id] ~= nil then return true end
            end
            return false
        end,
        buff_remains = function() return 0 end,
        buff_points = function(unit, ids)
            for _, id in ipairs(ids or {}) do
                if buff_points_map[id] ~= nil then return buff_points_map[id] end
            end
            return nil
        end,
        buff_stacks = function(unit, ids)
            for _, id in ipairs(ids or {}) do
                if buff_stacks_map[id] ~= nil then return buff_stacks_map[id] end
            end
            return 0
        end,
        debuff_up = function() return false end,
        debuff_remains = function() return 0 end,
        get_totem_info = function(slot)
            return totem_slots[slot] or nil
        end,
        game_time_ms = function() return 0 end,
        time_now = function() return 0 end,
        log = function() end,
        log_warning = function() end,
        rotation_registry = { register = function() end },
        get_spell_ladders = function() return ladder_records end,
        get_spell_ready_records = function() return spell_ready_records end,
        get_try_cast_records = function() return try_cast_records end,
        set_on_cd = function(map) on_cd = map end,
        set_buff_points = function(map) buff_points_map = map end,
        set_buff_stacks = function(map) buff_stacks_map = map end,
        set_totem_slots = function(map) totem_slots = map end,
        _on_cd = on_cd,
    }
    if overrides then for k, v in pairs(overrides) do ns[k] = v end end
    return ns
end

local function load_strategies(path, ns)
    _G.EaxRotations = ns
    local result = dofile(path)
    -- Full module: { strategies = ..., build_state = ... } (canonical return).
    return result
end

local function find(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return i, strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function ctx(overrides)
    overrides = overrides or {}
    local c = {
        me = {},
        target = {
            get_health_percentage = function() return 100 end,
            is_casting = function() return overrides.target_is_casting == true end,
        },
        has_valid_enemy_target = true,
        in_combat = true,
        mana_pct = 100,
        hp = 100,
        target_hp = 100,
        enemy_count = 1,
        lowest = { unit = nil, hp = 100 },
        settings = {},
    }
    for k, v in pairs(overrides) do c[k] = v end
    return c
end

local FRIENDLY = { get_health_percentage = function() return 50 end }

-- ============================================================================
-- (1) Elemental fixes
-- ============================================================================
do
    local ns = make_ns()
    local ele = load_strategies("EaxRotations/classes/shaman/elemental_wotlk.lua", ns)
    assert_eq(#ele.strategies, 12, "elemental has 12 strategies (WindShear added)")

    -- 1a. WindShear is the WotLK interrupt, first in the kick block; Earth
    --     Shock is kept as instant damage while the target casts (era fix).
    local ws_i, ws = find(ele.strategies, "WindShear")
    local es_i, es = find(ele.strategies, "EarthShock")
    assert_eq(ws_i, 1, "WindShear first (kick block)")
    assert_eq(es_i, 2, "EarthShock second (kick block)")
    assert_true(ws.matches(ctx({ in_combat = true, target_is_casting = true }), {}),
        "WindShear fires when target casts")
    assert_false(ws.matches(ctx({ in_combat = true, target_is_casting = false }), {}),
        "WindShear held when target is not casting")
    assert_false(ws.matches(ctx({ in_combat = false, target_is_casting = true }), {}),
        "WindShear held out of combat")
    assert_true(es.matches(ctx({ in_combat = true, target_is_casting = true }), {}),
        "EarthShock instant damage while target casts")
    assert_false(es.matches(ctx({ in_combat = true, target_is_casting = false }), {}),
        "EarthShock held when target is not casting")

    -- 1b. CD windows come from NS.spell_ready (never phantom context flags).
    local state = ele.build_state(ctx({ in_combat = true }))
    assert_true(state.bloodlust_ready, "bloodlust ready via NS.spell_ready")
    assert_true(state.fire_elemental_ready, "fire elemental ready via NS.spell_ready")
    assert_true(state.elemental_mastery_ready, "elemental mastery ready via NS.spell_ready")
    local ready_ids = {}
    for _, r in ipairs(ns.get_spell_ready_records()) do
        local id = type(r.spell) == "table" and (r.spell.ids and r.spell.ids[1] or r.spell.id) or r.spell
        ready_ids[id] = true
    end
    assert_true(ready_ids[2825], "spell_ready queried for Bloodlust 2825")
    assert_true(ready_ids[2894], "spell_ready queried for Fire Elemental 2894")
    assert_true(ready_ids[16166], "spell_ready queried for Elemental Mastery 16166")
    ns.set_on_cd({ [2825] = 300 })
    local state_cd = ele.build_state(ctx({ in_combat = true }))
    assert_false(state_cd.bloodlust_ready, "bloodlust blocked while on CD")
    assert_true(state_cd.fire_elemental_ready, "fire elemental still ready")

    -- 1c. Searing Totem: fire-slot occupancy gate (slot 1), not the old
    --     summon-spell debuff check that never matched in game.
    local _, st = find(ele.strategies, "SearingTotem")
    ns.set_totem_slots({})
    assert_true(st.matches(ctx({ in_combat = true }), {}), "Searing Totem drops when fire slot free")
    ns.set_totem_slots({ [1] = { have_totem = true } })
    assert_false(st.matches(ctx({ in_combat = true }), {}), "Searing Totem held while fire slot occupied")
    assert_false(st.matches(ctx({ in_combat = false }), {}), "Searing Totem held out of combat")

    -- 1d. Totem of Wrath: buff-down + air-slot-free re-drop (mid-fight too).
    local _, tow = find(ele.strategies, "TotemOfWrath")
    ns.set_totem_slots({})
    assert_true(tow.matches(ctx({ in_combat = true }), {}),
        "Totem of Wrath re-drops in combat when destroyed (air slot free)")
    ns.set_totem_slots({ [4] = { have_totem = true } })
    assert_false(tow.matches(ctx({ in_combat = true }), {}),
        "Totem of Wrath held while air slot occupied")

    -- 1e. FlameShock now has an in-combat + mana gate (pre-pull spam fixed).
    local _, fs = find(ele.strategies, "FlameShock")
    assert_false(fs.matches(ctx({ in_combat = false }), {}), "FlameShock held out of combat")
    assert_true(fs.matches(ctx({ in_combat = true, mana_pct = 50 }), {}), "FlameShock fires in combat")
end

-- ============================================================================
-- (2) Enhancement fixes
-- ============================================================================
do
    local ns = make_ns()
    local enh = load_strategies("EaxRotations/classes/shaman/enhancement_wotlk.lua", ns)
    assert_eq(#enh.strategies, 14, "enhancement has 14 strategies")

    -- 2a. Feral Spirit readiness via NS.spell_ready (the old
    --     ACTION.FeralSpirit:cooldown_remaining() member is mock-only).
    local _, fs = find(enh.strategies, "FeralSpirit")
    local state = enh.build_state(ctx({ in_combat = true }))
    assert_true(state.feral_spirit_ready, "feral spirit ready via NS.spell_ready")
    assert_true(fs.matches(ctx({ in_combat = true }), state), "Feral Spirit fires when ready")
    ns.set_on_cd({ [51533] = 120 })
    local state_cd = enh.build_state(ctx({ in_combat = true }))
    assert_false(state_cd.feral_spirit_ready, "feral spirit blocked while on CD")
    assert_false(fs.matches(ctx({ in_combat = true }), state_cd), "Feral Spirit held while on CD")
    ns.set_on_cd({})

    -- 2b. Bloodlust ready via NS.spell_ready.
    local _, bl = find(enh.strategies, "Bloodlust")
    assert_true(bl.matches(ctx({ in_combat = true }), enh.build_state(ctx({ in_combat = true }))),
        "Bloodlust fires when ready")

    -- 2c. Shamanistic Rage lane appended after the pinned order; fires at low
    --     mana in combat (rubric-listed mana/CD mechanic).
    local sr_i, sr = find(enh.strategies, "ShamanisticRage")
    local lv_i = find(enh.strategies, "LavaLash")
    assert_true(sr_i > lv_i, "ShamanisticRage appended after the pinned order")
    assert_true(sr.matches(ctx({ in_combat = true, mana_pct = 30 }), {}),
        "ShamanisticRage fires at low mana")
    assert_false(sr.matches(ctx({ in_combat = true, mana_pct = 100 }), {}),
        "ShamanisticRage held at full mana")
    assert_false(sr.matches(ctx({ in_combat = false, mana_pct = 30 }), {}),
        "ShamanisticRage held out of combat")

    -- 2d. Call of the Elements: water-slot gate (slot 3) — the old phantom
    --     water_totem_remains field was never set by production.
    local _, cote = find(enh.strategies, "CallOfTheElements")
    ns.set_totem_slots({})
    assert_true(cote.matches(ctx({}), {}), "Call of the Elements fires when water slot free")
    ns.set_totem_slots({ [3] = { have_totem = true } })
    assert_false(cote.matches(ctx({}), {}), "Call of the Elements held while water slot occupied")
    ns.set_totem_slots({})

    -- 2e. Fire Nova requires an ACTIVE fire totem (WotLK mechanic).
    local _, fn = find(enh.strategies, "FireNova")
    assert_false(fn.matches(ctx({ enemy_count = 3 }), {}),
        "Fire Nova held without a fire totem (failed-cast fix)")
    ns.set_totem_slots({ [1] = { have_totem = true } })
    assert_true(fn.matches(ctx({ enemy_count = 3 }), {}),
        "Fire Nova fires with a fire totem up and 2+ enemies")
    assert_false(fn.matches(ctx({ enemy_count = 1 }), {}),
        "Fire Nova held on single target")
    ns.set_totem_slots({})

    -- 2f. Magma Totem also respects the fire slot.
    local _, mt = find(enh.strategies, "MagmaTotem")
    ns.set_totem_slots({ [1] = { have_totem = true } })
    assert_false(mt.matches(ctx({ enemy_count = 3 }), {}), "Magma held while fire slot occupied")
    ns.set_totem_slots({})

    -- 2g. Weapon-imbue upkeep lanes (wowsims default_wf): appended, OOC-only,
    --     ~29.8-min window, casting the WotLK max ranks.
    local wf_i, wf = find(enh.strategies, "WindfuryWeapon")
    local ft_i, ft = find(enh.strategies, "FlametongueWeapon")
    assert_true(wf_i > sr_i, "WindfuryWeapon appended at the end")
    assert_true(ft_i > wf_i, "FlametongueWeapon after WindfuryWeapon")
    local ladders = {}
    for _, entry in ipairs(ns.get_spell_ladders()) do
        ladders[entry.label] = entry.ids[1]
    end
    assert_eq(ladders["WindfuryWeapon"], 58804, "WindfuryWeapon ladder head 58804 (WotLK max)")
    assert_eq(ladders["FlametongueWeapon"], 58790, "FlametongueWeapon ladder head 58790 (WotLK max)")
    local state_ooc = enh.build_state(ctx({ in_combat = false, mana_pct = 100 }))
    assert_false(state_ooc.has_windfury, "windfury stale on fresh state")
    -- NOTE: build_state mutates the module-level raw state table (safe_state
    -- write-through), so every matches() call below passes a FRESH state (or
    -- {} for a DSL rebuild) — never a proxy captured across rebuilds.
    assert_true(wf.matches(ctx({ in_combat = false, mana_pct = 100 }), {}),
        "WindfuryWeapon matches OOC when stale")
    assert_false(wf.matches(ctx({ in_combat = true, mana_pct = 100 }), {}),
        "WindfuryWeapon held in combat")
    assert_true(ft.matches(ctx({ in_combat = false, mana_pct = 100 }), {}),
        "FlametongueWeapon matches OOC when stale")
end

-- ============================================================================
-- (3) Restoration fixes
-- ============================================================================
do
    local ns = make_ns()
    local resto = load_strategies("EaxRotations/classes/shaman/restoration_wotlk.lua", ns)
    assert_eq(#resto.strategies, 7, "restoration has 7 strategies (WaterShield added)")

    -- 3a. Mana Tide readiness via NS.spell_ready with the 5-min expected CD
    --     (mirrors TBC healing_sylvanas.lua:394).
    local _, mtt = find(resto.strategies, "ManaTideTotem")
    local state = resto.build_state(ctx({ in_combat = true, mana_pct = 27 }))
    assert_true(state.mana_tide_ready, "mana tide ready via NS.spell_ready (expected_cooldown 300)")
    assert_true(mtt.matches(ctx({ in_combat = true, mana_pct = 27 }), state),
        "ManaTideTotem fires at mana 27")
    assert_false(mtt.matches(ctx({ in_combat = true, mana_pct = 50 }), {}),
        "ManaTideTotem held above mana 30")
    ns.set_on_cd({ [16190] = 300 })
    assert_false(resto.build_state(ctx({ in_combat = true, mana_pct = 27 })).mana_tide_ready,
        "mana tide blocked while on CD")
    ns.set_on_cd({})

    -- 3b. Chain Heal gates on the REAL engine field party_injured_count (the
    --     old context.injured_count was never populated by production).
    local _, ch = find(resto.strategies, "ChainHeal")
    assert_true(ch.matches(ctx({ party_injured_count = 2, lowest_hp = 50, mana_pct = 27 }), {}),
        "ChainHeal fires with 2 party members injured (engine field)")
    assert_false(ch.matches(ctx({ party_injured_count = 1, lowest_hp = 50, mana_pct = 27 }), {}),
        "ChainHeal held with 1 injured")
    assert_false(ch.matches(ctx({ party_injured_count = 2, lowest_hp = 90, mana_pct = 27 }), {}),
        "ChainHeal held when lowest ally healthy")

    -- 3c. Heals target the lowest friendly (context.lowest.unit), never the
    --     (possibly hostile) context.target.
    local _, es = find(resto.strategies, "EarthShield")
    local _, rt = find(resto.strategies, "Riptide")
    local hostile = { get_health_percentage = function() return 100 end, is_enemy = true }
    local heal_ctx = ctx({ target = hostile, lowest = { unit = FRIENDLY, hp = 50 } })
    ns.get_try_cast_records = ns.get_try_cast_records  -- keep spy
    es.execute(heal_ctx, resto.build_state(heal_ctx))
    rt.execute(heal_ctx, resto.build_state(heal_ctx))
    local casts = ns.get_try_cast_records()
    assert_eq(casts[#casts - 1].unit, FRIENDLY, "EarthShield casts on the lowest friendly")
    assert_eq(casts[#casts].unit, FRIENDLY, "Riptide casts on the lowest friendly")

    -- 3d. Earth Shield charge-aware refresh (Pattern 12 via NS.buff_points).
    local state_es = resto.build_state(heal_ctx)
    assert_true(es.matches(heal_ctx, state_es), "EarthShield applies when absent")
    ns.set_buff_points({ [49284] = { 5 } })
    local state_full = resto.build_state(heal_ctx)
    assert_true(state_full.earth_shield_up, "ES up via buff_up mock override")
    ns.set_buff_points({ [49284] = { 1 } })
    local state_low = resto.build_state(heal_ctx)
    assert_eq(state_low.earth_shield_charges, 1, "ES charges read from buff_points")
    assert_true(es.matches(heal_ctx, state_low), "EarthShield refreshes at 1 charge")
    ns.set_buff_points({ [49284] = { 5 } })
    assert_false(es.matches(heal_ctx, resto.build_state(heal_ctx)),
        "EarthShield held with 5 charges")

    -- 3e. Water Shield lane appended; Tidal Waves stacks tracked.
    local ws_i, ws = find(resto.strategies, "WaterShield")
    assert_eq(ws_i, #resto.strategies, "WaterShield appended at the end")
    assert_true(ws.matches(ctx({ in_combat = true, mana_pct = 30 }), {}),
        "WaterShield fires at low mana")
    ns.set_buff_stacks({ [53390] = 2 })
    assert_eq(resto.build_state(ctx({ in_combat = true, mana_pct = 100 })).tidal_waves_stacks, 2,
        "Tidal Waves stacks tracked (53390)")
end

-- ============================================================================
-- (4) Leveling fixes
-- ============================================================================
-- Fake time holder: the spec captures _G.core.time AT LOAD, so the holder
-- closure must read a mutable upvalue (mutating _G.core.time after load has no
-- effect on the captured reference).
local _fake_now = 0
do
    local ns = make_ns()
    _G.core = { time = function() return _fake_now end }
    local lvl = load_strategies("EaxRotations/classes/shaman/leveling_wotlk.lua", ns)
    assert_eq(#lvl.strategies, 12, "leveling still has 12 strategies")

    -- 4a. Lava Burst ladder head is the WotLK max rank 60043 (was hardcoded
    --     rank-1 51505); plain define_action so the TBC ShamanSpells table
    --     cannot shadow the WotLK ladders.
    local ladders = {}
    for _, entry in ipairs(ns.get_spell_ladders()) do
        ladders[entry.label] = entry.ids
    end
    assert_eq(ladders["LavaBurst"][1], 60043, "LavaBurst ladder head 60043 (WotLK max)")
    assert_eq(ladders["LavaBurst"][2], 51505, "LavaBurst ladder keeps rank-1 fallback")
    assert_eq(ladders["SearingTotem"][1], 58704, "SearingTotem ladder head 58704")
    assert_eq(ladders["MagmaTotem"][1], 58734, "MagmaTotem ladder head 58734")
    assert_eq(ladders["LightningBolt"][1], 49238, "LightningBolt ladder head 49238")
    -- The TBC ShamanSpells table (25449 etc.) must NOT be used verbatim:
    assert_false(ladders["LightningBolt"][1] == 25449, "TBC ShamanSpells shadow eliminated")

    -- 4b. FlametongueWeapon: OOC, ~29.8-min window — a 1.5s GCD-lock is
    --     structurally impossible. Execute records the cast and arms the
    --     window; the lane holds until 1790s elapse.
    local _, ftw = find(lvl.strategies, "FlametongueWeapon")
    local ooc = ctx({ in_combat = false, mana_pct = 100 })
    assert_true(ftw.matches(ooc, {}), "FlametongueWeapon matches OOC on fresh state")
    ns.get_try_cast_records = ns.get_try_cast_records
    assert_true(ftw.execute(ooc, {}), "FlametongueWeapon executes OOC")
    assert_eq(ns.get_try_cast_records()[1].spell.ids[1], 58790,
        "FlametongueWeapon casts the WotLK max rank 58790")
    _fake_now = 60
    assert_false(ftw.matches(ooc, {}), "FlametongueWeapon held at 60s (29.8-min window)")
    _fake_now = 1791
    assert_true(ftw.matches(ooc, {}), "FlametongueWeapon re-applies after ~29.8 min")

    -- 4c. Searing/Magma share ONE fire-slot timestamp: dropping Searing arms
    --     the slot so Magma cannot overwrite it for its own duration.
    _fake_now = 0
    local _, searing = find(lvl.strategies, "SearingTotem")
    local _, magma = find(lvl.strategies, "MagmaTotem")
    local combat = ctx({ in_combat = true, enemy_count = 3, mana_pct = 100 })
    assert_true(searing.matches(combat, {}), "SearingTotem matches in combat with fire slot free")
    assert_true(searing.execute(combat, {}), "SearingTotem executes")
    _fake_now = 10
    assert_false(magma.matches(combat, {}), "Magma held 10s after Searing (shared fire-slot timestamp)")
    _fake_now = 19
    assert_true(magma.matches(combat, {}), "Magma fires after 18s (Searing still alive, slot free)")
    assert_true(magma.execute(combat, {}), "MagmaTotem executes")
    _fake_now = 30
    assert_false(searing.matches(combat, {}), "Searing held 30s after Magma (shared timestamp)")
end

print("PASS test_shaman_wotlk_live_fixes")
