-- shadow_vanilla.lua — Priest Shadow for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  shadow DPS (SW:P, Mind Blast, Mind Flay, Shadow Weaving).
-- WHEN:  combat, when NS.is_vanilla() is true.
-- WHY:   Vanilla Shadow has no Vampiric Touch; VT is TBC-only.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.
-- NOTE:  the snapshot machinery (spell_damage/snapshot_*_dmg) is INERT in
--   Classic: the dispatcher deliberately never provides context.spell_damage
--   (main_sylvanas.lua:816-822), so spell_damage is always 0 and the upgrade
--   path is vacuous. Phase 2 wires a `player_spell_damage` setting source;
--   nothing is built here until that exists.

local __eax_file = "classes/priest/shadow_vanilla.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-28"
local __eax_change = "Classic Vanilla Shadow Priest rotation"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Priest Shadow priority list with Mind Flay channel clipping control.
-- ============================================================================
-- What: Classic Vanilla Priest Shadow rotation with Mind Flay clipping and DoT cycling
-- When: Per tick
-- Why: DoT refresh windows and channel clipping maximize damage.
--   NOTE: the snapshot-aware refresh claim is aspirational — see the header:
--   spell_damage is never populated by the dispatcher in Classic, so the
--   snapshot upgrade path (SPELL_DMG_UPGRADE_RATIO / REFRESH_EXTRA_WINDOW) is
--   inert until a spell-damage source exists (Phase 2 `player_spell_damage`).
-- Safety: Per-target cast lockouts, nil-guarded target checks, conservative refresh windows
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PriestSpells or {}

local mf_tick = require("shared/mf_tick_compute_sylvanas")
-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local SHADOWFORM_BUFF = { 15473 }
local INNER_FIRE_BUFF = { 10952, 10951, 1006, 602, 7128, 588 }
local WEAKENED_SOUL_DEBUFF = { 6788 }
local INNER_FOCUS_BUFF = { 14751 }
local VAMPIRIC_TOUCH_DEBUFF = { }  -- VT is TBC-only; empty in Classic
local SHADOW_WORD_PAIN_DEBUFF = { 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local VAMPIRIC_EMBRACE_BUFF = { 15286 }  -- VE is a SELF buff in vanilla (not a target debuff)
local MIND_FLAY_IDS = { 17314, 17313, 17312, 17311, 15407 }  -- 18807 is TBC rank 6
local DEVOURING_PLAGUE_DEBUFF = { 19280, 19279, 19278, 19277, 19276, 2944 }
local SHADOW_WEAVING_DEBUFF = { 15258 }  -- Shadow Weaving talent debuff (5-stack +2% shadow dmg/stack)

local SILENCE_INTERRUPT_SPELL = { 15487 }          -- Shadow talent Silence (15pt, interrupt)

-- Long cooldown TTD gating thresholds (seconds)
local MIN_TTD_FOR_CD_INNER_FOCUS = 45     -- Don't burn Inner Focus if combat ends within 45s

local VT_CLIP_THRESHOLD = 1.5

-- Snapshot-aware refresh constants
local SPELL_DMG_UPGRADE_RATIO = 1.08    -- Refresh only if 8%+ spell damage upgrade
local REFRESH_EXTRA_WINDOW = 1.5         -- Extra seconds past pandemic window for upgrade refresh

-- Per-target cast lockout: prevents double-queuing a DoT to the same target
-- while a cast is in flight (matching parity's lockout tracking)
local _cast_lockouts = {}  -- guid -> { spell_name = true, expires = time_ms }
-- Bounded map: entries were only ever pruned on lookup of the CURRENT target,
-- so long sessions with many targets grew the table without bound. Cap the
-- guid count and sweep expired entries when the cap is exceeded.
local _LOCKOUT_MAX_GUIDS = 64

local function _prune_lockouts(now)
    for guid, spells in pairs(_cast_lockouts) do
        for name, expires in pairs(spells) do
            if now >= expires then spells[name] = nil end
        end
        if next(spells) == nil then _cast_lockouts[guid] = nil end
    end
end

local function _set_lockout(spell_name, duration_ms)
    local target = NS.GetTarget and NS.GetTarget()
    if not target then return end
    local guid = target.get_guid and target:get_guid()
    if not guid then return end
    local now = NS.game_time_ms and NS.game_time_ms() or 0
    _cast_lockouts[guid] = _cast_lockouts[guid] or {}
    _cast_lockouts[guid][spell_name] = now + duration_ms
    local guid_count = 0
    for _ in pairs(_cast_lockouts) do guid_count = guid_count + 1 end
    if guid_count > _LOCKOUT_MAX_GUIDS then _prune_lockouts(now) end
end

local function _is_locked(spell_name)
    local target = NS.GetTarget and NS.GetTarget()
    if not target then return false end
    local guid = target.get_guid and target:get_guid()
    if not guid or not _cast_lockouts[guid] then return false end
    local expires = _cast_lockouts[guid][spell_name]
    if not expires then return false end
    if (NS.game_time_ms and NS.game_time_ms() or 0) >= expires then
        _cast_lockouts[guid][spell_name] = nil
        return false
    end
    return true
end

local function target_creature_type(unit)
    if not unit then return nil end
    if type(NS.unit_creature_type) == "function" then return NS.unit_creature_type(unit) end
    if unit.get_creature_type then
        local ok, value = pcall(function() return unit:get_creature_type() end)
        if ok then return value end
    end
    return nil
end

-- ============================================================================
-- State builder
-- ============================================================================
local shadow_state = {
    mf_channeling = false,
    mf_ticks = 0,
    should_clip_mf = false,
    vt_remaining = 0,
    swp_remaining = 0,
    dp_remaining = 0,
    mb_ready = false,
    has_shadowform = false,
    shadowform_known = false,
    swp_known = false,
    vampiric_embrace_known = false,
    devouring_plague_known = false,
    mind_flay_known = false,
    inner_fire_known = false,
    flash_heal_known = false,
    berserking_known = false,
    blood_fury_known = false,
    arcane_torrent_known = false,
    starshards_known = false,
    has_inner_focus = false,
    has_inner_fire = false,
    combat_mode = "auto",          -- "auto" | "st" | "cleave" | "aoe"
    swp_refresh_window = 3,
    dp_refresh_window = 3,
    shield_hp = 35,
    flash_heal_hp = 25,
    psychic_scream_ready = false,
    silence_ready = false,
    fade_ready = false,
    dispel_magic_ready = false,
    shackle_undead_ready = false,
    mana_pct = 100,
    in_combat = false,
    enemy_count = 1,
    target_creature_type = nil,
    -- Debuff tracking on target
    weaving_stacks = 0,                     -- Shadow Weaving stacks (0-5)
    -- Threat & mana safety gates
    threat_safe = true,                     -- Tank threat lead sufficient for burst
    mana_low = false,                       -- Mana below MB floor (drop Mind Blast)
    mana_emergency = false,                 -- Mana below emergency floor (wand only)
    -- Snapshot state (spell damage when DoT was applied)
    spell_damage = 0,
    snapshot_swp_dmg = 0,
    snapshot_dp_dmg = 0,
    snapshot_target = nil,
}

-- Schema for safe_state: Pattern 14 nil-guard defaults.
local SHADOW_VANILLA_SCHEMA = {
    mf_channeling = false,  mf_ticks = 0,  should_clip_mf = false,
    vt_remaining = 0,  swp_remaining = 0,  dp_remaining = 0,
    mb_ready = false,  has_shadowform = false,
    shadowform_known = false,  swp_known = false,  vampiric_embrace_known = false,
    devouring_plague_known = false,  mind_flay_known = false,
    inner_fire_known = false,  flash_heal_known = false,
    berserking_known = false,  blood_fury_known = false,
    arcane_torrent_known = false,  starshards_known = false,
    has_inner_focus = false,  has_inner_fire = false,
    combat_mode = "auto",  vt_refresh_window = 3,
    swp_refresh_window = 3,  dp_refresh_window = 3,
    shield_hp = 35,  flash_heal_hp = 25,  mounted = false,
    psychic_scream_ready = false,  silence_ready = false,
    fade_ready = false,  dispel_magic_ready = false,
    shackle_undead_ready = false,
    mana_pct = 100,  hp_pct = 100,  in_combat = false,
    enemy_count = 1,  target_hp_pct = 100,
    weaving_stacks = 0,  threat_safe = true,
    mana_low = false,  mana_emergency = false,
    spell_damage = 0,  snapshot_vt_dmg = 0,  snapshot_swp_dmg = 0,
    snapshot_dp_dmg = 0,  has_bloodlust = false,  snapshot_target = nil,
}

local function build_state(context)
    local target = context.target
    local me = NS.GetPlayer()
    if not me then return spec_kit.safe_state(shadow_state, SHADOW_VANILLA_SCHEMA) end
    local mounted_bail = spec_kit.setting_bool(context, "shadow_mounted_bail", true)
    if mounted_bail then
        if me.is_mounted and me:is_mounted() then
            return spec_kit.safe_state(shadow_state, SHADOW_VANILLA_SCHEMA)
        end
    end
    
    shadow_state.vt_remaining = target and NS.debuff_remains(target, VAMPIRIC_TOUCH_DEBUFF) or 0
    shadow_state.swp_remaining = target and NS.debuff_remains(target, SHADOW_WORD_PAIN_DEBUFF) or 0
    shadow_state.dp_remaining = target and NS.debuff_remains(target, DEVOURING_PLAGUE_DEBUFF) or 0
    shadow_state.mb_ready = target and NS.spell_ready(SPELLS.MindBlast, target, { expected_cooldown = 5.5 }) or false
    shadow_state.mf_channeling, shadow_state.mf_ticks = mf_tick.compute_channel_state(me, NS.game_time_ms(), MIND_FLAY_IDS)
    shadow_state.should_clip_mf = mf_tick.should_clip_mf(
        shadow_state.mf_channeling,
        shadow_state.mf_ticks,
        VT_CLIP_THRESHOLD,
        shadow_state.mb_ready,
        false,
        shadow_state.vt_remaining,
        shadow_state.swp_remaining
    )
    shadow_state.has_shadowform = me and NS.buff_up(me, SHADOWFORM_BUFF) or false
    shadow_state.shadowform_known = me and NS.spell_exists and NS.spell_exists(SPELLS.Shadowform) or false
    shadow_state.swp_known = me and NS.spell_exists and NS.spell_exists(SPELLS.ShadowWordPain) or false
    shadow_state.vampiric_embrace_known = me and NS.spell_exists and NS.spell_exists(SPELLS.VampiricEmbrace) or false
    shadow_state.devouring_plague_known = me and NS.spell_exists and NS.spell_exists(SPELLS.DevouringPlague) or false
    shadow_state.mind_flay_known = me and NS.spell_exists and NS.spell_exists(SPELLS.MindFlay) or false
    shadow_state.inner_fire_known = me and NS.spell_exists and NS.spell_exists(SPELLS.InnerFire) or false
    shadow_state.flash_heal_known = me and NS.spell_exists and NS.spell_exists(SPELLS.FlashHeal) or false
    shadow_state.berserking_known = me and NS.spell_exists and NS.spell_exists(SPELLS.Berserking) or false
    shadow_state.blood_fury_known = me and NS.spell_exists and NS.spell_exists(SPELLS.BloodFury) or false
    shadow_state.arcane_torrent_known = me and NS.spell_exists and NS.spell_exists(SPELLS.ArcaneTorrent) or false
    shadow_state.starshards_known = me and NS.spell_exists and NS.spell_exists(SPELLS.Starshards) or false
    shadow_state.has_inner_focus = me and NS.buff_up(me, INNER_FOCUS_BUFF) or false
    shadow_state.has_inner_fire = me and NS.buff_up(me, INNER_FIRE_BUFF) or false
    -- enemy_count must be assigned BEFORE the combat-mode computation below:
    -- previously the mode read the stale previous-frame value (tick-1 was
    -- always "st"), making mode detection lag one dispatch tick (fix 2026-08-13).
    shadow_state.enemy_count = context.enemy_count or context.enemies_count or 1
    -- Combat mode: explicit setting or auto-detect
    local mode = spec_kit.setting(context, "shadow_combat_mode", "auto")
    if mode == "auto" then
        local enemy_count = shadow_state.enemy_count or 0
        if enemy_count >= 5 then mode = "aoe"
        elseif enemy_count >= 3 then mode = "cleave"
        else mode = "st" end
    end
    shadow_state.combat_mode = mode
    -- Configurable refresh windows
    shadow_state.swp_refresh_window = spec_kit.setting_number(context, "shadow_swp_refresh_window", 3)
    shadow_state.dp_refresh_window = spec_kit.setting_number(context, "shadow_dp_refresh_window", 3)
    -- Configurable safety thresholds
    shadow_state.shield_hp = spec_kit.setting_number(context, "shadow_shield_hp", 35)
    shadow_state.flash_heal_hp = spec_kit.setting_number(context, "shadow_flash_heal_hp", 25)
    -- Has Weakened Soul (cannot receive PW:Shield)
    shadow_state.has_weakened_soul = me and NS.debuff_up and NS.debuff_up(me, WEAKENED_SOUL_DEBUFF) or false
    
    shadow_state.silence_ready = me and NS.spell_ready(SILENCE_INTERRUPT_SPELL, target, { expected_cooldown = 45 }) or false
    shadow_state.psychic_scream_ready = me and NS.spell_ready(SPELLS.PsychicScream, me, { skip_range = true, expected_cooldown = 30 }) or false
    shadow_state.fade_ready = me and NS.spell_ready(SPELLS.Fade, me, { skip_range = true, expected_cooldown = 30 }) or false
    shadow_state.dispel_magic_ready = me and NS.spell_ready(SPELLS.DispelMagic, me, { skip_range = true }) or false
    shadow_state.shackle_undead_ready = me and NS.spell_ready(SPELLS.ShackleUndead, me, { expected_cooldown = 1.5 }) or false
    shadow_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100

    -- Shadow Weaving debuff stacks on target
    shadow_state.weaving_stacks = target and NS.get_debuff_stacks and NS.get_debuff_stacks(target, SHADOW_WEAVING_DEBUFF) or 0

    -- Mana conservation floors (from Research: <30% drop MB, <15% wand only)
    local mb_mana_floor = spec_kit.setting_number(context, "shadow_mb_mana_floor", 30)
    local conserve_mana_floor = spec_kit.setting_number(context, "shadow_conserve_mana_floor", 15)
    shadow_state.mana_low = shadow_state.mana_pct < mb_mana_floor
    shadow_state.mana_emergency = shadow_state.mana_pct < conserve_mana_floor

    -- Threat safety: gate burst behind tank threat lead
    -- Uses NS.is_threat_safe if available, otherwise assumes safe
    local threat_safe_enabled = spec_kit.setting_bool(context, "shadow_threat_safe", true)
    if threat_safe_enabled and NS.is_threat_safe then
        shadow_state.threat_safe = NS.is_threat_safe(context)
    else
        shadow_state.threat_safe = true
    end
    shadow_state.in_combat = context.in_combat or false
    shadow_state.target_creature_type = target_creature_type(target)

    -- Current spell damage from NS — INERT in Classic: the dispatcher
    -- deliberately never provides context.spell_damage (main_sylvanas.lua:
    -- 816-822), so this is always 0 and the snapshot upgrade path is vacuous
    -- until a spell-damage source exists (Phase 2 `player_spell_damage`
    -- setting; do not build that here).
    shadow_state.spell_damage = context.spell_damage or 0
    -- Maintain snapshot state: reset snapshots if DoT expired or target changed
    local target_key = target and (target.get_guid and target:get_guid()) or nil
    if target_key ~= shadow_state.snapshot_target then
        shadow_state.snapshot_swp_dmg = 0
        shadow_state.snapshot_dp_dmg = 0
        shadow_state.snapshot_target = target_key
    else
        if shadow_state.swp_remaining <= 0 then shadow_state.snapshot_swp_dmg = 0 end
        if shadow_state.dp_remaining <= 0 then shadow_state.snapshot_dp_dmg = 0 end
    end

    return spec_kit.safe_state(shadow_state, SHADOW_VANILLA_SCHEMA)
end

-- ============================================================================
-- Snapshot upgrade logic
-- ============================================================================

-- Determine if current spell damage justifies refreshing a DoT early
-- Returns true if: DoT expired, in pandemic window with upgrade, or about to fall off
local function should_snapshot_upgrade(current_dmg, snapshotted_dmg, remains, refresh_window, ratio)
    if remains <= 0 then return true end
    if remains <= refresh_window then return true end
    if snapshotted_dmg <= 0 then return true end
    if current_dmg >= snapshotted_dmg * ratio and remains <= refresh_window + REFRESH_EXTRA_WINDOW then
        return true
    end
    return false
end

local function can_break_mind_flay(s)
    return not s.mf_channeling or s.should_clip_mf
end



-- ============================================================================
-- Match functions
-- ============================================================================
local function shadowform_matches(context, s)
    if s.has_shadowform then return false end
    if not s.shadowform_known then return false end
    return true
end

local function shadow_swp_spread_matches(context, s)
    if not s.swp_known then return false end
    if not can_break_mind_flay(s) then return false end
    -- Combat mode gate: only spread in cleave or aoe mode
    if s.combat_mode ~= "cleave" and s.combat_mode ~= "aoe" then return false end
    if s.enemy_count < 3 then return false end
    if not context.has_valid_enemy_target then return false end
    -- Per-target lockout: prevent double-queuing SW:P to same target while in-flight
    if _is_locked("SWP") then return false end
    -- Avoid refreshing SW:P if it's still active on this target (we want to spread to targets that don't have it)
    local swp_window = s.swp_refresh_window or 3
    if s.swp_remaining > 0 and s.swp_remaining > swp_window then return false end
    if s.swp_remaining > 0 and not should_snapshot_upgrade(s.spell_damage, s.snapshot_swp_dmg, s.swp_remaining, swp_window, SPELL_DMG_UPGRADE_RATIO) then return false end
    return true
end

local function inner_fire_matches(context, s)
    if not s.inner_fire_known then return false end
    if s.has_inner_fire then return false end
    if not spec_kit.setting_bool(context, "shadow_use_inner_fire", true) then return false end
    return true
end

local function power_word_shield_matches(context, s)
    -- HP-gated self-shield
    if (context.hp or 100) > (s.shield_hp or 35) then return false end
    -- Can't cast if Weakened Soul is active
    if s.has_weakened_soul then return false end
    if not (NS.spell_ready and NS.spell_ready(SPELLS.PowerWordShield, NS.PLAYER_UNIT, { skip_range = true })) then return false end
    return true
end

local function flash_heal_matches(context, s)
    if not s.flash_heal_known then return false end
    -- HP-gated self-heal
    if (context.hp or 100) > (s.flash_heal_hp or 25) then return false end
    if context.is_moving then return false end
    return true
end

local function holy_nova_aoe_matches(context, s)
    -- Combat mode gate: only AoE in aoe mode
    if s.combat_mode ~= "aoe" then return false end
    if context.is_moving then return false end
    -- Holy Nova: 10yd self PBAoE — not 40yd enemy_count
    if not NS.aoe_self_meets or not NS.aoe_self_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context, s) then return false end
    if not context.in_combat then return false end
    -- Self-centered PBAoE: readiness is checked on the player with skip_range
    -- (mirrors smite_vanilla:451), not on the enemy target.
    return NS.spell_ready and NS.spell_ready(SPELLS.HolyNova, NS.PLAYER_UNIT, { skip_range = true })
end

-- Racial burst: one matcher per racial, each gated on its own *_known flag.
-- The previous shared matcher fired for ANY known racial, so the first
-- registered lane (RacialBerserking) claimed every GCD even for races that
-- lack the spell (e.g. trolls, humans) and the later lanes were unreachable.
-- Written as explicit functions (not a factory) so the state-field audit sees
-- the literal s.<field> reads.
local function racial_gate(context, s)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 120) then return false end
    if not can_break_mind_flay(s) then return false end
    if not context.has_valid_enemy_target then return false end
    if not context.in_combat then return false end
    -- TTD gate: don't use racials if target is about to die
    if context.ttd and context.ttd > 0 and context.ttd < 8 then return false end
    return true
end

local function berserking_matches(context, s)
    if not s.berserking_known then return false end
    return racial_gate(context, s)
end

local function blood_fury_matches(context, s)
    if not s.blood_fury_known then return false end
    return racial_gate(context, s)
end

local function arcane_torrent_matches(context, s)
    if not s.arcane_torrent_known then return false end
    return racial_gate(context, s)
end

local function shadow_word_pain_matches(context, s)
    if not s.swp_known then return false end
    if not can_break_mind_flay(s) then return false end
    if not context.has_valid_enemy_target then return false end
    if context.ttd and context.ttd > 0 and context.ttd < 10 then return false end
    -- Mana emergency: drop all spells (wand only)
    if s.mana_emergency then return false end
    -- Shadow Weaving maintenance: extend refresh window from 3s to 5s when stacks < 5
    local sw_window = s.swp_refresh_window or 3
    local effective_window = (s.weaving_stacks > 0 and s.weaving_stacks < 5) and 5 or sw_window
    if s.swp_remaining > effective_window then return false end
    -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
    local ratio = SPELL_DMG_UPGRADE_RATIO
    if s.swp_remaining > 0 and not should_snapshot_upgrade(s.spell_damage, s.snapshot_swp_dmg, s.swp_remaining, sw_window, ratio) then return false end
    return true
end

local function vampiric_embrace_matches(context, s)
    if not s.vampiric_embrace_known then return false end
    if not can_break_mind_flay(s) then return false end
    if not context.has_valid_enemy_target then return false end
    -- VE is a SELF buff in vanilla (no raid debuff slot); the old target-debuff
    -- read (ve_remaining) could never be nonzero, so the lane re-cast VE every
    -- eligible GCD. Gate on the self buff instead (leveling_vanilla:271).
    local me = context.me or NS.GetPlayer()
    if me and NS.buff_up and NS.buff_up(me, VAMPIRIC_EMBRACE_BUFF) then return false end
    return true
end

local function devouring_plague_matches(context, s)
    if not s.devouring_plague_known then return false end
    if not can_break_mind_flay(s) then return false end
    if not context.has_valid_enemy_target or s.dp_remaining > (s.dp_refresh_window or 3) then return false end
    -- Mana emergency: drop all spells (wand only)
    if s.mana_emergency then return false end
    -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
    local ratio = SPELL_DMG_UPGRADE_RATIO
    if s.dp_remaining > 0 and not should_snapshot_upgrade(s.spell_damage, s.snapshot_dp_dmg, s.dp_remaining, 3, ratio) then return false end
    return true
end

local function inner_focus_matches(context, s)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    if not can_break_mind_flay(s) then return false end
    if not context.in_combat or not s.mb_ready then return false end
    if s.has_inner_focus then return false end
    -- TTD gate: don't burn 180s cooldown if combat ends within threshold
    if context.ttd and context.ttd > 0 and context.ttd < MIN_TTD_FOR_CD_INNER_FOCUS then return false end
    return true
end

local function mind_blast_matches(context, s)
    if not can_break_mind_flay(s) then return false end
    if context.is_moving then return false end
    if not context.has_valid_enemy_target then return false end
    if not s.mb_ready then return false end
    -- Mana conservation: drop Mind Blast below 30% mana
    if s.mana_low then return false end
    -- Threat safety: hold MB if tank threat lead insufficient
    if not s.threat_safe then return false end
    return true
end

local function mind_flay_matches(context, s)
    if not s.mind_flay_known then return false end
    if context.is_moving or context.is_casting or context.is_channeling then return false end
    if not context.has_valid_enemy_target then return false end
    -- Mana emergency: drop all spells (wand only)
    if s.mana_emergency then return false end
    return true
end

local function silence_matches(context, s)
    if not can_break_mind_flay(s) then return false end
    if not context.in_combat then return false end
    if not s.silence_ready then return false end
    -- Silence is an interrupt: it may only fire while the target is casting or
    -- channeling. The old gate read NS.unit_interruptible (mock-only member)
    -- plus context.target_is_casting (never set by the dispatcher), so the
    -- lane could never fire live. NS.is_interruptible (core:3157) is the live
    -- API; fall back to the raw unit cast check for unit-test environments.
    if not context.target then return false end
    if NS.is_interruptible and NS.is_interruptible(context.target) then return true end
    if type(context.target.is_casting) == "function" then
        local ok, casting = pcall(context.target.is_casting, context.target)
        if ok and casting then return true end
    end
    if type(context.target.is_channeling) == "function" then
        local ok, channelling = pcall(context.target.is_channeling, context.target)
        if ok and channelling then return true end
    end
    return false
end

local function psychic_scream_matches(context, s)
    if not context.in_combat then return false end
    if s.enemy_count < 3 then return false end
    if not s.psychic_scream_ready then return false end
    return true
end

local function fade_matches(context, s)
    if not context.in_combat then return false end
    if s.enemy_count < 2 then return false end
    if not s.fade_ready then return false end
    return true
end

local function dispel_magic_matches(context, s)
    if not s.dispel_magic_ready then return false end
    -- Only dispel self if we actually have a magic debuff
    local me = context.me or NS.GetPlayer()
    if not me then return false end
    -- Common magic debuffs in vanilla (hardcoded whitelist; no dispel_type API)
    local MAGIC_DEBUFFS = {
        118, 12824, 12825, 12826, -- Polymorph
        2637, -- Hibernate
        605, 10911, 10912, -- Mind Control
        9484, 9485, 10955, -- Shackle Undead
        15487, -- Silence
        1330, -- Garrote - Silence
    }
    for _, id in ipairs(MAGIC_DEBUFFS) do
        if NS.has_debuff and NS.has_debuff(me, id) then return true end
    end
    return false
end

local function shackle_undead_matches(context, s)
    if not context.has_valid_enemy_target then return false end
    if s.target_creature_type ~= 6 then return false end
    if not s.shackle_undead_ready then return false end
    if context.target and NS.debuff_up and NS.debuff_up(context.target, {9484, 9485, 10955}) then return false end
    return true
end

local function starshards_matches(context, s)
    if not s.starshards_known then return false end
    if not context.has_valid_enemy_target then return false end
    if context.is_moving then return false end
    return true
end

-- ============================================================================
-- Wand / Auto-Attack (mana < 5% emergency)
-- ============================================================================
local function mana_below_5_wand_matches(context, s)
    if (context.mana_pct or 100) >= 5 then return false end
    if not context.in_combat then return false end
    return true
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "Shadowform", matches = shadowform_matches, execute = function(context) return NS.try_cast(SPELLS.Shadowform, NS.PLAYER_UNIT, "[SHADOW] Shadowform", { skip_range = true }) end },
    { name = "Silence", matches = silence_matches, execute = function(context) return NS.try_cast(SPELLS.Silence, context.target, "[SHADOW] Silence") end },
    { name = "ManaBelow5Wand", matches = mana_below_5_wand_matches, execute = function(context)
        -- Start wanding with the correct attack type: the bare NS.start_attack
        -- member is mock-only, and NS.start_auto_attack() with no target
        -- defaults to melee (6603). Pass the target + AUTO_ATTACK_WAND (5019)
        -- so the emergency lane actually shoots (mirrors leveling.execute_wand).
        if context and context.target then
            if NS.is_auto_attacking and NS.is_auto_attacking(context.me) then return true end
            if NS.start_auto_attack then
                return NS.start_auto_attack(context.target, NS.AUTO_ATTACK_WAND) == true
            end
        end
        return true
    end },
    { name = "ShadowWordPain", matches = shadow_word_pain_matches, execute = function(context) local ok = NS.try_cast(SPELLS.ShadowWordPain, context.target, "[SHADOW] ShadowWordPain"); if ok then shadow_state.snapshot_swp_dmg = shadow_state.spell_damage end; return ok end },
    { name = "VampiricEmbrace", matches = vampiric_embrace_matches, execute = function(context) return NS.try_cast(SPELLS.VampiricEmbrace, NS.PLAYER_UNIT, "[SHADOW] VampiricEmbrace") end },
    { name = "DevouringPlague", matches = devouring_plague_matches, execute = function(context) local ok = NS.try_cast(SPELLS.DevouringPlague, context.target, "[SHADOW] DevouringPlague"); if ok then shadow_state.snapshot_dp_dmg = shadow_state.spell_damage end; return ok end },
    { name = "InnerFocusMindBlast", matches = inner_focus_matches, execute = function(context) return NS.try_cast(SPELLS.InnerFocus, NS.PLAYER_UNIT, "[SHADOW] InnerFocus", { skip_range = true }) end },
    { name = "MindBlast", matches = mind_blast_matches, execute = function(context) return NS.try_cast(SPELLS.MindBlast, context.target, "[SHADOW] MindBlast") end },
    { name = "MindFlay", matches = mind_flay_matches, execute = function(context) return NS.try_cast(SPELLS.MindFlay, context.target, "[SHADOW] MindFlay") end },
    { name = "PsychicScream", matches = psychic_scream_matches, execute = function(context) return NS.try_cast(SPELLS.PsychicScream, context.target, "[SHADOW] PsychicScream") end },
    { name = "Fade", matches = fade_matches, execute = function(context) return NS.try_cast(SPELLS.Fade, NS.PLAYER_UNIT, "[SHADOW] Fade", { skip_range = true }) end },
    { name = "DispelMagic", matches = dispel_magic_matches, execute = function(context) return NS.try_cast(SPELLS.DispelMagic, NS.PLAYER_UNIT, "[SHADOW] DispelMagic", { skip_range = true }) end },
    { name = "ShackleUndead", matches = shackle_undead_matches, execute = function(context) return NS.try_cast(SPELLS.ShackleUndead, context.target, "[SHADOW] ShackleUndead") end },
    { name = "SWPSpread", matches = shadow_swp_spread_matches, execute = function(context) _set_lockout("SWP", 3000); local ok = NS.try_cast(SPELLS.ShadowWordPain, context.target, "[SHADOW] SWPSpread"); if ok then shadow_state.snapshot_swp_dmg = shadow_state.spell_damage end; return ok end },
    { name = "InnerFire", matches = inner_fire_matches, execute = function(context) return NS.try_cast(SPELLS.InnerFire, NS.PLAYER_UNIT, "[SHADOW] InnerFire", { skip_range = true }) end },
    { name = "PowerWordShield", matches = power_word_shield_matches, execute = function(context) return NS.try_cast(SPELLS.PowerWordShield, NS.PLAYER_UNIT, "[SHADOW] PowerWordShield", { skip_range = true }) end },
    { name = "FlashHeal", matches = flash_heal_matches, execute = function(context) return NS.try_cast(SPELLS.FlashHeal, NS.PLAYER_UNIT, "[SHADOW] FlashHeal", { skip_range = true }) end },
    { name = "HolyNovaAoE", matches = holy_nova_aoe_matches, execute = function(context) return NS.try_cast(SPELLS.HolyNova, context.target, "[SHADOW] HolyNova") end },
    { name = "RacialBerserking", matches = berserking_matches, execute = function(context) return NS.try_cast(SPELLS.Berserking, NS.PLAYER_UNIT, "[SHADOW] Berserking", { skip_range = true }) end },
    { name = "RacialBloodFury", matches = blood_fury_matches, execute = function(context) return NS.try_cast(SPELLS.BloodFury, NS.PLAYER_UNIT, "[SHADOW] BloodFury", { skip_range = true }) end },
    { name = "RacialArcaneTorrent", matches = arcane_torrent_matches, execute = function(context) return NS.try_cast(SPELLS.ArcaneTorrent, NS.PLAYER_UNIT, "[SHADOW] ArcaneTorrent", { skip_range = true }) end },
    { name = "Starshards", matches = starshards_matches, execute = function(context) return NS.try_cast(SPELLS.Starshards, context.target, "[SHADOW] Starshards") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("shadow", strategies, { get_state = build_state })
end
-- Priest shadow rotation registered
return strategies

