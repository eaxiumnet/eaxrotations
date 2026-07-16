-- shadow_vanilla.lua — Priest Shadow for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  shadow DPS (SW:P, Mind Blast, Mind Flay, Shadow Weaving).
-- WHEN:  combat, when NS.is_vanilla() is true.
-- WHY:   Vanilla Shadow has no Vampiric Touch; VT is TBC-only.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

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
-- Why: Snapshot-aware DoT refresh and channel clipping maximize damage
-- Safety: Per-target cast lockouts, nil-guarded target checks, conservative refresh windows
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PriestSpells or {}

local mf_tick = require("shared/mf_tick_compute_sylvanas")
-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local SHADOWFORM_BUFF = { 15473 }
local INNER_FIRE_BUFF = { 10952, 10951, 1006, 602, 7128, 588 }
local WEAKENED_SOUL_DEBUFF = { 6788 }
local POWER_WORD_SHIELD_SPELL = { 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }
local FLASH_HEAL_SPELL = { 10917, 10916, 10915, 9474, 9473, 9472, 2061 }
local INNER_FOCUS_BUFF = { 14751 }
local VAMPIRIC_TOUCH_DEBUFF = { }  -- VT is TBC-only; empty in Classic
local SHADOW_WORD_PAIN_DEBUFF = { 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local VAMPIRIC_EMBRACE_DEBUFF = { 15286 }
local MIND_FLAY_IDS = { 18807, 17314, 17313, 17312, 17311, 15407 }
local DEVOURING_PLAGUE_DEBUFF = { 19280, 19279, 19278, 19277, 19276, 2944 }
local SHADOW_WEAVING_DEBUFF = { 15258 }  -- Shadow Weaving talent debuff (5-stack +2% shadow dmg/stack)
local PSYCHIC_SCREAM_BUFF = { 10890, 10888, 8124, 8122 }
local FADE_BUFF = { 10942, 10941, 9592, 9579, 9578, 586 }
local STARSHARDS_SPELL = { 19305, 19304, 19303, 19302, 19299, 19296, 10797 }
local HOLY_NOVA_SPELL = { 15431, 15430, 15237 }

local SILENCE_INTERRUPT_SPELL = { 15487 }          -- Shadow talent Silence (15pt, interrupt)

-- Long cooldown TTD gating thresholds (seconds)
local SHADOWFIEND_CD = 300
local INNER_FOCUS_CD = 180
local MIN_TTD_FOR_CD_SHADOWFIEND = 60     -- Don't summon if combat ends within 60s (won't get 2nd use)
local MIN_TTD_FOR_CD_INNER_FOCUS = 45     -- Don't burn Inner Focus if combat ends within 45s

local VT_CLIP_THRESHOLD = 1.5

-- Snapshot-aware refresh constants
local SPELL_DMG_UPGRADE_RATIO = 1.08    -- Refresh only if 8%+ spell damage upgrade
local REFRESH_EXTRA_WINDOW = 1.5         -- Extra seconds past pandemic window for upgrade refresh

-- Per-target cast lockout: prevents double-queuing a DoT to the same target
-- while a cast is in flight (matching parity's lockout tracking)
local _cast_lockouts = {}  -- guid -> { spell_name = true, expires = time_ms }

local function _set_lockout(spell_name, duration_ms)
    local target = NS.GetTarget and NS.GetTarget()
    if not target then return end
    local guid = target.get_guid and target:get_guid()
    if not guid then return end
    _cast_lockouts[guid] = _cast_lockouts[guid] or {}
    _cast_lockouts[guid][spell_name] = (NS.game_time_ms and NS.game_time_ms() or 0) + duration_ms
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
    ve_remaining = 0,
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
    vt_refresh_window = 3,
    swp_refresh_window = 3,
    dp_refresh_window = 3,
    shield_hp = 35,
    flash_heal_hp = 25,
    mounted = false,
    psychic_scream_ready = false,
    silence_ready = false,
    fade_ready = false,
    dispel_magic_ready = false,
    shackle_undead_ready = false,
    mana_pct = 100,
    hp_pct = 100,
    in_combat = false,
    enemy_count = 1,
    target_hp_pct = 100,
    target_casting = false,
    target_creature_type = nil,
    -- Debuff tracking on target
    weaving_stacks = 0,                     -- Shadow Weaving stacks (0-5)
    -- Threat & mana safety gates
    threat_safe = true,                     -- Tank threat lead sufficient for burst
    mana_low = false,                       -- Mana below MB floor (drop Mind Blast)
    mana_emergency = false,                 -- Mana below emergency floor (wand only)
    -- Snapshot state (spell damage when DoT was applied)
    spell_damage = 0,
    snapshot_vt_dmg = 0,
    snapshot_swp_dmg = 0,
    snapshot_dp_dmg = 0,
    has_bloodlust = false,
    snapshot_target = nil,
}

local function build_state(context)
    local target = context.target
    local me = NS.GetPlayer()
    if not me then return shadow_state end
    local mounted_bail = spec_kit.setting_bool(context, "shadow_mounted_bail", true)
    if mounted_bail then
        if me.is_mounted and me:is_mounted() then
            shadow_state.mounted = true
            return shadow_state
        end
    end
    shadow_state.mounted = false
    
    shadow_state.vt_remaining = target and NS.debuff_remains(target, VAMPIRIC_TOUCH_DEBUFF) or 0
    shadow_state.swp_remaining = target and NS.debuff_remains(target, SHADOW_WORD_PAIN_DEBUFF) or 0
    shadow_state.ve_remaining = target and NS.debuff_remains(target, VAMPIRIC_EMBRACE_DEBUFF) or 0
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
    shadow_state.vt_refresh_window = spec_kit.setting_number(context, "shadow_vt_refresh_window", 3)
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
    shadow_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100

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
    shadow_state.enemy_count = context.enemy_count or context.enemies_count or 1
    shadow_state.target_hp_pct = target and NS.unit_health_pct and NS.unit_health_pct(target) or 100
    shadow_state.target_casting = target and target.is_casting and target:is_casting() or false
    shadow_state.target_creature_type = target_creature_type(target)

    -- Current spell damage from NS (provided by middleware or character API)
    shadow_state.spell_damage = context.spell_damage or 0
    -- Classic haste buff — enables more aggressive snapshot upgrade threshold
    shadow_state.has_bloodlust = false
    -- Maintain snapshot state: reset snapshots if DoT expired or target changed
    local target_key = target and (target.get_guid and target:get_guid()) or nil
    if target_key ~= shadow_state.snapshot_target then
        shadow_state.snapshot_vt_dmg = 0
        shadow_state.snapshot_swp_dmg = 0
        shadow_state.snapshot_dp_dmg = 0
        shadow_state.snapshot_target = target_key
    else
        if shadow_state.vt_remaining <= 0 then shadow_state.snapshot_vt_dmg = 0 end
        if shadow_state.swp_remaining <= 0 then shadow_state.snapshot_swp_dmg = 0 end
        if shadow_state.dp_remaining <= 0 then shadow_state.snapshot_dp_dmg = 0 end
    end

    return shadow_state
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
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.Shadowform, 3.0) then return false end
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
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.InnerFire, 3.0) then return false end
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
    if s.enemy_count < 3 then return false end
    if not context.in_combat then return false end
    return NS.spell_ready and NS.spell_ready(SPELLS.HolyNova, context.target, nil)
end

local function racial_matches(context, s)
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 120) then return false end
    if not s.berserking_known and not s.blood_fury_known and not s.arcane_torrent_known then return false end
    if not can_break_mind_flay(s) then return false end
    if not context.has_valid_enemy_target then return false end
    if not context.in_combat then return false end
    -- TTD gate: don't use racials if target is about to die
    if context.ttd and context.ttd > 0 and context.ttd < 8 then return false end
    return true
end

local function shadow_word_pain_matches(context, s)
    if not s.swp_known then return false end
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.ShadowWordPain, 2.0) then return false end
    if not can_break_mind_flay(s) then return false end
    if not context.has_valid_enemy_target then return false end
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
    if not context.has_valid_enemy_target or s.ve_remaining > 10 then return false end
    return true
end

local function devouring_plague_matches(context, s)
    if not s.devouring_plague_known then return false end
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.DevouringPlague, 2.0) then return false end
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
    if not context.target or not NS.unit_interruptible then
        -- Fallback: check target casting state without native interruptible API
        if not context.target_is_casting then return false end
    end
    return true
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
    { name = "ManaBelow5Wand", matches = mana_below_5_wand_matches, execute = function(context) if NS.start_attack then NS.start_attack() end; return true end },
    { name = "ShadowWordPain", matches = shadow_word_pain_matches, execute = function(context) local ok = NS.try_cast(SPELLS.ShadowWordPain, context.target, "[SHADOW] ShadowWordPain"); if ok then shadow_state.snapshot_swp_dmg = shadow_state.spell_damage end; return ok end },
    { name = "VampiricEmbrace", matches = vampiric_embrace_matches, execute = function(context) return NS.try_cast(SPELLS.VampiricEmbrace, context.target, "[SHADOW] VampiricEmbrace") end },
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
    { name = "RacialBerserking", matches = racial_matches, execute = function(context) return NS.try_cast(SPELLS.Berserking, NS.PLAYER_UNIT, "[SHADOW] Berserking", { skip_range = true }) end },
    { name = "RacialBloodFury", matches = racial_matches, execute = function(context) return NS.try_cast(SPELLS.BloodFury, NS.PLAYER_UNIT, "[SHADOW] BloodFury", { skip_range = true }) end },
    { name = "RacialArcaneTorrent", matches = racial_matches, execute = function(context) return NS.try_cast(SPELLS.ArcaneTorrent, NS.PLAYER_UNIT, "[SHADOW] ArcaneTorrent", { skip_range = true }) end },
    { name = "Starshards", matches = starshards_matches, execute = function(context) return NS.try_cast(SPELLS.Starshards, context.target, "[SHADOW] Starshards") end },
}

NS.rotation_registry:register("shadow", strategies, { get_state = build_state })
-- Priest shadow rotation registered
return strategies

