-- holy_forever.lua — Paladin Holy day-1 rotation for WoW Forever (beta 2026-09-17).
-- WHAT:  Forever kit deltas spliced ON TOP of the vanilla baseline: Infusion-of-
--        Light fast Holy Light weave (healing priority), Light's Vigil mark —
--        party-heal / damage+refund branches, DBC-verified 6s category CD —
--        mana-aware deficit-fit top-off through the shared HealValue ladders
--        and the core cast_best_heal_rank hook, the 10s Holy Shock core, the
--        Holy Strike melee weave, and Seal/Judgement of the Crusader support
--        (Judgment no longer consumes the seal on Forever).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/paladin.md (Deep Dive 2026-09-13 + beta DBC
--        2026-09-17): Holy Shock on a 10s CD becomes a core rotational spell;
--        Infusion of Light turns Holy Shock/FoL crits into fast Holy Lights;
--        Light's Vigil marks a target so the next Holy Shock on it triggers
--        no cooldown and pays a party heal (allies) or damage + 76% mana
--        refund (enemies) — the beta DBC carries CategoryRecoveryTime 6000 on
--        every rank, so it is a rotational mark, not a 180s burst CD; Holy
--        Strike (level 6) is a new melee weave in EVERY paladin rotation.
--        Twist of Light (1310735) is deliberately NOT wired here: the beta DBC
--        has no SpellClassOptions row for it (class NULL, BaseLevel 0) and it
--        sits in the Retribution trainer list, so it is a ret passive — a
--        by-name lane could never resolve through the bridge (see the kit doc).
-- SAFETY: ZERO numeric spell-ID literals — the fail-closed forever audit
--        (run_forever_audit_tests.lua) resolves every ID through the bridge,
--        so a hardcoded literal could never pass on beta day. Forever-new
--        spells resolve BY NAME through the DBC-derived bridge module
--        (shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua,
--        pcall-required as an optional module); a nil lookup leaves the
--        lane dormant — never a guessed ID.
--        Era-shared spells come from the class map (NS.PaladinSpells). The
--        vanilla baseline is loaded through an intercepted registration
--        (load_sod_specs pattern) so this file edits nothing in
--        holy_vanilla.lua, and its safe_state-backed get_state is reused
--        unchanged. Healer-first ordering: conditional healing lanes sit
--        above the whole baseline; rotational fillers sit just above the
--        baseline's solo-damage block and below every heal/utility lane, so
--        no delta lane can shadow an emergency cast (first-match dispatch);
--        the head lanes gate their own emergency bands (hp floors) so the
--        baseline's last-resort lanes stay reachable.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.PaladinSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "holy" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("paladin holy", "classes/paladin/holy_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): cast
-- lanes resolve through the max-rank mirror (max-level rotations cast max
-- rank, not rank 1) and buff lanes through the buff mirror; a nil lookup in
-- either mirror leaves the lane dormant -- never a guessed ID. Exact client
-- names come from docs/forever/kits/paladin.md; sentinel stand-ins for these
-- names are seeded per mirror by the battery's build_ns so the lanes are
-- observable (Pattern 17) and mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_name, by_maxrank, by_buff = mirrors.name, mirrors.maxrank, mirrors.buff

-- Cast roles resolve through the max-rank mirror: Holy Strike 10333@60 (not
-- the 678 rank-1 baseline), Light's Vigil 1311595@60 (not the 1310909 aura
-- row), Seal of the Crusader 20308 (not the 20162 rank-1 baseline).
-- Aura/debuff roles resolve through the buff mirror (Light's Vigil 1310909,
-- Infusion of Light 437063 -- the live 15s Holy Light row; the TBC-era 53672
-- is an orphan this build wires to nothing) or the rank-1 mirror for debuff
-- rows the client
-- applies at max rank (Judgement of the Crusader 20188 / 20303).
local HOLY_STRIKE = resolve_id(by_maxrank, "Holy Strike")
local LIGHTS_VIGIL = resolve_id(by_maxrank, "Light's Vigil")
local LIGHTS_VIGIL_AURA = resolve_id(by_buff, "Light's Vigil")
local INFUSION_OF_LIGHT_BUFF = resolve_id(by_buff, "Infusion of Light")
local SEAL_CRUSADER_CAST = resolve_id(by_maxrank, "Seal of the Crusader")
local SEAL_CRUSADER_BASELINE = resolve_id(by_name, "Seal of the Crusader")
local JOC_BASELINE = resolve_id(by_name, "Judgement of the Crusader")
local JOC_MAXRANK = resolve_id(by_maxrank, "Judgement of the Crusader")

-- Rank-id tables are built from resolved ids only (never literals): the cast
-- action needs one id; the aura/debuff probes want every rank the class map
-- knows (SPELLS.SealCrusader._meta.ids carries the client's classic ladder),
-- plus the two bridge-resolved ids as the always-available floor.
local append_unique = forever.append_unique

local SEAL_CRUSADER_IDS = {}
append_unique(SEAL_CRUSADER_IDS, { SEAL_CRUSADER_CAST, SEAL_CRUSADER_BASELINE })
append_unique(SEAL_CRUSADER_IDS, SPELLS.SealCrusader
    and SPELLS.SealCrusader._meta and SPELLS.SealCrusader._meta.ids or nil)
local JOC_IDS = {}
append_unique(JOC_IDS, { JOC_BASELINE, JOC_MAXRANK })
local VIGIL_IDS = {}
append_unique(VIGIL_IDS, { LIGHTS_VIGIL_AURA })

-- ---------------------------------------------------------------------------
-- Shared helpers (mirror the baseline's local semantics; file-locals there
-- are not importable) and Forever constants. Thresholds are menu-tunable
-- via spec_kit.setting; the "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}
local SELF_OPTS = { skip_range = true }
local CAST_OPTS = { player_level = 60 }
local EXPECTED_10S = { expected_cooldown = 10 }

-- DBC-confirmed (wowsims_forever.db, SpellCooldowns): CategoryRecoveryTime
-- 10000 on both Holy Shock rows (20473 + 1311606) and 6000 on every Light's
-- Vigil rank (1310911 / 1311590 / 1311595). The Vigil aura lasts 30s.
local FOREVER_HOLY_SHOCK_CD = 10
local FOREVER_HOLY_SHOCK_MANA_FLOOR = 20
local FOREVER_IOL_HL_DEFICIT = 30       -- fast big heal only when it matters
local FOREVER_IOL_MANA_FLOOR = 25
local FOREVER_IOL_HP_FLOOR = 20         -- never shadow Lay on Hands / Divine Shield
local FOREVER_VIGIL_MANA_FLOOR = 40     -- high-cost mark: never at starvation
local FOREVER_VIGIL_ALLY_MANA_FLOOR = 50
local FOREVER_VIGIL_ALLY_HP = 70        -- ally branch: someone actually hurt
local FOREVER_VIGIL_EMERGENCY_HP = 20   -- below this the baseline saves first
local FOREVER_HOLY_STRIKE_MANA_FLOOR = 30
local FOREVER_HOLY_STRIKE_RANGE = 5     -- melee range in yards
local FOREVER_FIT_MANA_FLOOR = 30
local FOREVER_FIT_CEILING = 92          -- efficient top-off band ceiling
local FOREVER_FIT_EMERGENCY = 65        -- never touch the baseline heal bands
local FOREVER_SOTC_MANA_FLOOR = 35
local FOREVER_BOSS_HP_FLOOR = 20

local function hp_of(entry, fallback)
    if entry and type(entry.effective_hp) == "number" then return entry.effective_hp end
    if entry and type(entry.hp) == "number" then return entry.hp end
    return fallback or 100
end

local function deficit_of(entry, hp_fallback)
    if not entry then return 0 end
    -- Explicit scan fields win even at 0 (a 0 means the scan saw no deficit);
    -- the hp-derived fallback is only for percentage-only entries such as the
    -- friendly-target record, which carries no deficit field at all.
    if type(entry.effective_deficit) == "number" then return entry.effective_deficit end
    if type(entry.deficit) == "number" then return entry.deficit end
    if type(hp_fallback) == "number" and hp_fallback < 100 then return 100 - hp_fallback end
    return 0
end

local function can_help(entry)
    if not entry or not entry.unit then return false end
    if entry.is_dead == true or entry.dead == true then return false end
    return true
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- Healer-first discipline: fillers must never outrank topping off a hurt
-- ally (mirrors the baseline's solo_damage_enabled safe_hp gate).
local function group_healthy(s)
    if s and can_help(s.lowest) and hp_of(s.lowest) < 88 then return false end
    return true
end

local setting = forever.setting

-- spec_kit.setting_bool exists in production; the delta's unit harness mocks
-- only setting(), so fall back to a nil-safe boolean read of the same key.
local setting_bool = forever.setting_bool

local function unit_has_any_buff(unit, ids)
    if not unit or type(ids) ~= "table" or #ids == 0 or not NS.buff_up then return false end
    return NS.buff_up(unit, ids) and true or false
end

local function unit_debuff_remains(unit, ids)
    if not unit or type(ids) ~= "table" or #ids == 0 or not NS.debuff_remains then return 0 end
    return NS.debuff_remains(unit, ids) or 0
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Healing-priority lanes (conditional, never hot) sit above the
-- whole baseline; rotational fillers sit just above the baseline's
-- solo-damage block ("SealOfRighteousnessSolo"; fallback: append).
-- ---------------------------------------------------------------------------

local delta_head = {}

-- Infusion of Light weave (kit: HS/FoL crits reduce Holy Light cast time):
-- while the buff is up and an ally is hurt enough to deserve the big heal,
-- Holy Light becomes the fast filler. Dormant until the bridge resolves the
-- buff id (battery drives it through the sentinel map).
if INFUSION_OF_LIGHT_BUFF then
    delta_head[#delta_head + 1] = {
        name = "Forever_InfusionOfLightWeave",
        matches = function(context, s)
            if not can_help(s.lowest) then return false end
            if hp_of(s.lowest) <= FOREVER_IOL_HP_FLOOR then return false end
            if (s.mana_pct or 100) < setting(context, "holy_forever_iol_mana_floor", FOREVER_IOL_MANA_FLOOR) then return false end
            if not NS.has_player_buff(INFUSION_OF_LIGHT_BUFF) then return false end
            if 100 - hp_of(s.lowest) < setting(context, "holy_forever_iol_deficit", FOREVER_IOL_HL_DEFICIT) then return false end
            return NS.spell_ready(SPELLS.HolyLight, s.lowest.unit, EMPTY_OPTS)
        end,
        execute = function(_, s)
            return NS.try_cast(SPELLS.HolyLight, s.lowest.unit,
                format("[FOREVER-HOLY] IoL Holy Light weave %.0f%%", hp_of(s.lowest)))
        end,
    }
end

-- Light's Vigil mark (DBC: 6s category CD on every rank, 1340 mana, 1.5s
-- cast, 30s aura; "next Holy Shock cast on them triggers no cooldown" plus a
-- party heal on allies or damage + 76% mana refund on enemies). The mark only
-- pays off on the next Holy Shock, so it is gated on the shock being ready
-- NOW: ally branch when the baseline's own triage says the group is taking
-- heavy damage, enemy branch when the group is healthy (damage + refund).
local function vigil_choice(context, s)
    if can_help(s.lowest)
        and s.heavy_healing
        and hp_of(s.lowest) > FOREVER_VIGIL_EMERGENCY_HP
        and hp_of(s.lowest) <= setting(context, "holy_forever_vigil_ally_hp", FOREVER_VIGIL_ALLY_HP)
        and (s.mana_pct or 100) >= setting(context, "holy_forever_vigil_ally_mana_floor", FOREVER_VIGIL_ALLY_MANA_FLOOR)
        and not unit_has_any_buff(s.lowest.unit, VIGIL_IDS) then
        return s.lowest.unit, true
    end
    if has_valid_enemy(context)
        and group_healthy(s)
        and unit_debuff_remains(context.target, VIGIL_IDS) <= 0 then
        return context.target, false
    end
    return nil, false
end

if LIGHTS_VIGIL then
    delta_head[#delta_head + 1] = {
        name = "Forever_LightsVigilBurst",
        matches = function(context, s)
            if (s.mana_pct or 100) < setting(context, "holy_forever_vigil_mana_floor", FOREVER_VIGIL_MANA_FLOOR) then return false end
            local hs_remains = NS.cooldown_remains and NS.cooldown_remains(SPELLS.HolyShock) or 0
            if (hs_remains or 0) > 0 then return false end
            if not NS.spell_ready(LIGHTS_VIGIL, NS.PLAYER_UNIT, SELF_OPTS) then return false end
            local target = vigil_choice(context, s)
            return target ~= nil
        end,
        execute = function(context, s)
            local target, is_ally = vigil_choice(context, s)
            if not target then return false end
            if is_ally then
                return NS.try_cast(LIGHTS_VIGIL, target,
                    format("[FOREVER-HOLY] Light's Vigil party mark %.0f%%", hp_of(s.lowest)), SELF_OPTS)
            end
            return NS.try_cast(LIGHTS_VIGIL, target,
                "[FOREVER-HOLY] Light's Vigil damage mark (refund)", SELF_OPTS)
        end,
    }
end

-- Mana-aware deficit-fit top-off (shared/heal_value_sylvanas ladders through
-- NS.cast_best_heal_rank's deficit-fit hook): targets the worse of the lowest
-- group entry and the friendly target, inside the efficient top-off band, and
-- casts the smallest rank whose expected heal covers the deficit. A zero
-- deficit never fires (the fit declines); when a Flash cannot meaningfully
-- cover the deficit the lane escalates to the Holy Light ladder, whose own
-- biggest-castable fallback applies. The fit is bypassed entirely when the
-- core hook is unavailable (lane stays match-only, like the baseline's
-- FriendlyTarget).
local function fit_target(context, s)
    local gl = s.lowest
    local gl_hp = hp_of(gl, 100)
    local ft = NS.get_friendly_target_entry and NS.get_friendly_target_entry(context) or nil
    local ft_hp = ft and (ft.effective_hp or ft.hp_pct or 100) or 100
    if ft and ft.unit and ft_hp < gl_hp then
        return ft, ft_hp, gl_hp, true
    end
    return gl, gl_hp, gl_hp, false
end

delta_head[#delta_head + 1] = {
    name = "Forever_DeficitFitTopoff",
    matches = function(context, s)
        if not context or not context.in_combat then return false end
        if s.moving or context.is_moving then return false end
        if (s.mana_pct or 100) < setting(context, "holy_forever_fit_mana_floor", FOREVER_FIT_MANA_FLOOR) then return false end
        local entry, t_hp, gl_hp, is_friendly_target = fit_target(context, s)
        if not can_help(entry) then return false end
        if t_hp > setting(context, "holy_forever_fit_ceiling", FOREVER_FIT_CEILING) then return false end
        -- Never touch the baseline's emergency/heavy-heal bands: the group's
        -- lowest must be above the band, and for a friendly target the group
        -- must not be in emergency either (the baseline saves the group first).
        if is_friendly_target then
            if gl_hp <= FOREVER_FIT_EMERGENCY then return false end
        elseif t_hp <= FOREVER_FIT_EMERGENCY then
            return false
        end
        return deficit_of(entry, t_hp) > 0
    end,
    execute = function(context, s)
        local entry, t_hp = fit_target(context, s)
        if not can_help(entry) then return false end
        local cast_best = NS.cast_best_heal_rank
        if type(cast_best) ~= "function" then return false end
        local spell, label, expected = nil, nil, nil
        local fol_ladder = NS.FLASH_OF_LIGHT_RANKS
        if type(fol_ladder) == "table" then
            spell, label, expected = cast_best(fol_ladder, entry, context,
                "[FOREVER-HOLY] fit top-off", CAST_OPTS)
        end
        local deficit = deficit_of(entry, t_hp)
        local hl_ladder = NS.HOLY_LIGHT_RANKS
        if (not spell) or (expected and deficit > 0 and deficit > expected * 2) then
            if type(hl_ladder) == "table" then
                local hl_spell, hl_label = cast_best(hl_ladder, entry, context,
                    "[FOREVER-HOLY] fit top-off", CAST_OPTS)
                if hl_spell then spell, label = hl_spell, hl_label end
            end
        end
        if not spell then return false end
        return NS.try_cast(spell, entry.unit,
            format("[FOREVER-HOLY] %s", tostring(label or "deficit-fit heal")))
    end,
}

local delta_weave = {}

-- Holy Shock core (kit: 10s CD, "significantly more uptime than TBC's 30s"):
-- the baseline's HolyShock lane only fires as an emergency heal below 40%;
-- on Forever it is a rotational spell — spend it as holy damage on the kill
-- target when the group is healthy, otherwise heal the lowest ally. Positioned
-- below every baseline heal/utility lane so it can never shadow one.
delta_weave[#delta_weave + 1] = {
    name = "Forever_HolyShockCore",
    matches = function(context, s)
        if not (can_help(s.lowest) or has_valid_enemy(context)) then return false end
        if (s.mana_pct or 100) < setting(context, "holy_forever_shock_mana_floor", FOREVER_HOLY_SHOCK_MANA_FLOOR) then return false end
        return NS.spell_ready(SPELLS.HolyShock, NS.PLAYER_UNIT, EMPTY_OPTS)
    end,
    execute = function(context, s)
        if has_valid_enemy(context) and group_healthy(s) then
            return NS.try_cast(SPELLS.HolyShock, context.target, "[FOREVER-HOLY] Holy Shock core (damage)")
        end
        return NS.try_cast(SPELLS.HolyShock, s.lowest.unit,
            format("[FOREVER-HOLY] Holy Shock core %.0f%%", hp_of(s.lowest)))
    end,
}

-- Holy Strike weave (kit: level-6 instant Holy strike on a 12s CD, present
-- in EVERY paladin rotation): melee-range filler, gated on a healthy group so
-- it can never outrank healing.
if HOLY_STRIKE then
    delta_weave[#delta_weave + 1] = {
        name = "Forever_HolyStrikeWeave",
        matches = function(context, s)
            if not HOLY_STRIKE then return false end
            if not has_valid_enemy(context) then return false end
            if not group_healthy(s) then return false end
            if (s.mana_pct or 100) < setting(context, "holy_forever_strike_mana_floor", FOREVER_HOLY_STRIKE_MANA_FLOOR) then return false end
            if NS.unit_distance and NS.unit_distance(context.target, context.me) > FOREVER_HOLY_STRIKE_RANGE then return false end
            return NS.spell_ready(HOLY_STRIKE, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(HOLY_STRIKE, context.target, "[FOREVER-HOLY] Holy Strike weave")
        end,
    }
end

-- Seal of the Crusader support: Judgment no longer consumes the seal on
-- Forever, so the pair becomes cheap upkeep the baseline never considers
-- (Judgement of the Crusader raises the target's holy damage taken). Seal
-- lane keeps SotC up while the target lacks JoC; judgement lane spends it.
-- Both are gated behind the setting and stay dormant when the bridge cannot
-- resolve the ids (never a guessed ID).
local SEAL_CRUSADER = nil
if SEAL_CRUSADER_CAST then
    SEAL_CRUSADER = NS.spell_action({ SEAL_CRUSADER_CAST }, "ForeverSealOfTheCrusader")
    delta_weave[#delta_weave + 1] = {
        name = "Forever_SealOfTheCrusaderSupport",
        matches = function(context, s)
            if not setting_bool(context, "holy_forever_sotc_support", true) then return false end
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "holy_forever_sotc_mana_floor", FOREVER_SOTC_MANA_FLOOR) then return false end
            if (s.target_hp_pct or 100) < FOREVER_BOSS_HP_FLOOR then return false end
            if unit_debuff_remains(context.target, JOC_IDS) > 0 then return false end
            if unit_has_any_buff(NS.PLAYER_UNIT, SEAL_CRUSADER_IDS) then return false end
            return NS.spell_ready(SEAL_CRUSADER, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function()
            return NS.try_cast(SEAL_CRUSADER, NS.PLAYER_UNIT,
                "[FOREVER-HOLY] Seal of the Crusader support", SELF_OPTS)
        end,
    }
end

if SEAL_CRUSADER and #SEAL_CRUSADER_IDS > 0 and #JOC_IDS > 0 then
    delta_weave[#delta_weave + 1] = {
        name = "Forever_JudgementOfTheCrusaderSupport",
        matches = function(context, s)
            if not setting_bool(context, "holy_forever_sotc_support", true) then return false end
            if not has_valid_enemy(context) then return false end
            if (s.mana_pct or 100) < setting(context, "holy_forever_sotc_mana_floor", FOREVER_SOTC_MANA_FLOOR) then return false end
            if (s.target_hp_pct or 100) < FOREVER_BOSS_HP_FLOOR then return false end
            if unit_debuff_remains(context.target, JOC_IDS) > 0 then return false end
            if not unit_has_any_buff(NS.PLAYER_UNIT, SEAL_CRUSADER_IDS) then return false end
            return NS.spell_ready(SPELLS.Judgement, context.target, EXPECTED_10S)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Judgement, context.target,
                "[FOREVER-HOLY] Judgement of the Crusader support", EXPECTED_10S)
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: healing-priority deltas first, then everything
-- vanilla in order, with the rotational fillers inserted just above the
-- baseline's solo-damage block. Re-registering the playstyle name replaces
-- the baseline wholesale — the combined list IS the "holy" playstyle on
-- Forever.
-- ---------------------------------------------------------------------------
local combined = {}
for i = 1, #delta_head do combined[#combined + 1] = delta_head[i] end
local weave_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if not weave_inserted and type(st) == "table" and st.name == "SealOfRighteousnessSolo" then
        for j = 1, #delta_weave do combined[#combined + 1] = delta_weave[j] end
        weave_inserted = true
    end
    combined[#combined + 1] = st
end
if not weave_inserted then
    for j = 1, #delta_weave do combined[#combined + 1] = delta_weave[j] end
end

baseline.register(combined)
if NS.log then NS.log("Paladin holy Forever delta registered (" .. #delta_head .. " head + " .. #delta_weave .. " filler lanes over " .. #baseline.strategies .. " baseline lanes)") end

return combined
