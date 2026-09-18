-- elemental_forever.lua — Shaman Elemental delta for WoW Forever (beta).
-- WHAT:  Forever kit deltas spliced ON TOP of the vanilla baseline: a
--        Lava Burst nuke lane hard-gated on Flame Shock being up (+20% /
--        rendered 21% on shocked targets — the flagship keep-FS-up loop,
--        10s category CD declared to the readiness check) and a Fire Nova
--        spell lane (the trainer-taught totem-detonating cast row, gated on
--        a live Fire Totem); re-registered as the "elemental" playstyle with
--        the vanilla strategies kept below.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/shaman.md (Icy Veins class overview, 2026-09-15;
--        beta DBC verification 2026-09-17): Lava Burst is the capstone nuke
--        with the Flame Shock dependency, making FS uptime a rotation-shaping
--        gate; Fire Nova is no longer a totem — it detonates your Fire Totem
--        as a plain spell (the vanilla totem-drop semantics collapse into a
--        spell gate). Elemental Mastery needs NO delta: the talent row (16166,
--        tier 6, prereq Elemental Fury 5) still exists in the client's
--        Elemental tree and the baseline lane casts it from the class map —
--        the client's SpellName table simply has no name row for it, so it is
--        absent from the bridge (documented in the kit, no dead lane added).
-- SAFETY: ZERO numeric spell-ID literals — the fail-closed forever audit
--        (run_forever_audit_tests.lua) resolves every ID through the bridge.
--        Forever-new spells resolve BY NAME through the DBC-derived bridge
--        module (shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua,
--        pcall-required as an optional module); a nil lookup leaves the lane
--        dormant — never a guessed ID. Era-shared spells (Lava Burst is NOT
--        in the TBC-era class map — it resolves by name; Flame Shock ids
--        come from the class map action) keep every read map/bridge-driven.
--        The vanilla baseline is loaded through an intercepted registration
--        (holy_forever template) so this file edits nothing in
--        elemental_vanilla.lua, and its safe_state-backed get_state is
--        reused unchanged. New lanes sit just above the baseline's
--        "LightningBolt" nuke block — never above a defensive/utility lane.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.ShamanSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "elemental" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("shaman elemental", "classes/shaman/elemental_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): both
-- lanes CAST, so both resolve through the max-rank mirror (Lava Burst
-- 1238300@60, the +20%/rendered-21% Flame Shock row; Fire Nova 408345@52,
-- the trainer-taught totem-detonating cast pinned in the builder's
-- MAXRANK_OVERRIDES over the internal 11307 damage row). A nil lookup leaves
-- the lane dormant -- never a guessed ID. Sentinel stand-ins are seeded per
-- mirror by the battery's build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_maxrank = mirrors.maxrank

local LAVA_BURST_SPELL = resolve_id(by_maxrank, "Lava Burst")
local FIRE_NOVA_SPELL = resolve_id(by_maxrank, "Fire Nova")

-- Zero-literal Flame Shock debuff table: reuse the class map's rank list.
local FLAME_SHOCK_DEBUFF = SPELLS.FlameShock and SPELLS.FlameShock.ids or nil

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}

local FOREVER_LB_MANA_FLOOR = 25
local FOREVER_NOVA_MANA_FLOOR = 30
local FOREVER_FS_MIN_REMAINS = 2   -- cast LB while FS comfortably up
-- DBC-confirmed: CategoryRecoveryTime 10000 on both Lava Burst cast rows
-- (408490@40, 1238300@60). The engine owns the real cooldown; the expected
-- value keeps the manual fallback honest on a client with sparse data.
local FOREVER_LAVA_BURST_CD = 10
-- Fire totem slot (WoW totem slots: 1 fire, 2 earth, 3 water, 4 air). The
-- Forever Fire Nova detonates the ACTIVE fire totem, so the lane holds when
-- the client reports none.
local FOREVER_FIRE_TOTEM_SLOT = 1

local setting = forever.setting

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- Live-fire-totem probe (NS.get_totem_info, core_sylvanas). Fail-open when
-- the API is unavailable; the engine wrapper returns a table with
-- have_totem, while the battery's no-totem shape is the literal false.
local function fire_totem_up()
    local get_info = NS.get_totem_info
    if type(get_info) ~= "function" then return true end
    local info = get_info(FOREVER_FIRE_TOTEM_SLOT)
    if info == false then return false end
    if type(info) == "table" and info.have_totem == false then return false end
    return true
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Rotational deltas only in this file: the Lava Burst + Fire
-- Nova lanes sit just above the baseline's "ChainLightning" nuke (the top
-- damage lane below ElementalMastery), so they win the nuke slot when their
-- gates pass and no defensive/utility lane is shadowed.
-- ---------------------------------------------------------------------------

local delta_nuke = {}

local LAVA_BURST_OPTS = { expected_cooldown = FOREVER_LAVA_BURST_CD }

-- Lava Burst (kit: capstone nuke, +20% on Flame-Shocked targets). Hard FS
-- dependency: only while the target's Flame Shock has comfortable remains —
-- the classic keep-FS-up loop this delta exists to enforce. Battery drives
-- FS through the debuff_remains_map on the primary target (sentinel spell
-- id for Lava Burst comes from the bridge map).
if LAVA_BURST_SPELL then
    delta_nuke[#delta_nuke + 1] = {
        name = "Forever_LavaBurstShocked",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "ele_forever_lb_mana_floor", FOREVER_LB_MANA_FLOOR) then return false end
            if not FLAME_SHOCK_DEBUFF then return false end
            if (NS.debuff_remains(context.target, FLAME_SHOCK_DEBUFF) or 0)
                < setting(context, "ele_forever_fs_min_remains", FOREVER_FS_MIN_REMAINS) then return false end
            return NS.spell_ready(LAVA_BURST_SPELL, context.target, LAVA_BURST_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(LAVA_BURST_SPELL, context.target,
                "[FOREVER-ELE] Lava Burst (Flame-Shocked target)")
        end,
    }
end

-- Fire Nova spell (kit: no longer a totem — the max-rank mirror's cast row
-- 408345 detonates your live Fire Totem, +15y with Elemental Reach). Above
-- the baseline nuke block so the spell semantics win while it is off
-- cooldown; holds when no fire totem is up (the detonation is a no-op
-- without one). Dormant until the bridge resolves the name.
if FIRE_NOVA_SPELL then
    delta_nuke[#delta_nuke + 1] = {
        name = "Forever_FireNovaSpell",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if not fire_totem_up() then return false end
            if (s.mana_pct or 100) < setting(context, "ele_forever_nova_mana_floor", FOREVER_NOVA_MANA_FLOOR) then return false end
            return NS.spell_ready(FIRE_NOVA_SPELL, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(FIRE_NOVA_SPELL, context.target,
                "[FOREVER-ELE] Fire Nova (detonates Fire Totem)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: delta lanes go above the baseline's LightningBolt
-- nuke block. Re-registering the playstyle name replaces the baseline
-- wholesale — the combined list IS the "elemental" playstyle on Forever.
-- ---------------------------------------------------------------------------
local combined = {}
local nuke_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if not nuke_inserted and type(st) == "table" and st.name == "ChainLightning" then
        for j = 1, #delta_nuke do combined[#combined + 1] = delta_nuke[j] end
        nuke_inserted = true
    end
    combined[#combined + 1] = st
end
if not nuke_inserted then
    for j = 1, #delta_nuke do combined[#combined + 1] = delta_nuke[j] end
end

baseline.register(combined)
if NS.log then NS.log("Shaman elemental Forever delta registered (" ..
    #delta_nuke .. " nuke lanes over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
