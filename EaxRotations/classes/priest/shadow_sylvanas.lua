-- Priest Shadow priority list with Mind Flay channel clipping control.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PriestSpells or {}

local mf_tick = require("shared/mf_tick_compute_sylvanas")

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local SHADOWFORM_BUFF = { 15473 }
local INNER_FIRE_BUFF = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
local WEAKENED_SOUL_DEBUFF = { 6788 }
local POWER_WORD_SHIELD_SPELL = { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }
local FLASH_HEAL_SPELL = { 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }
local INNER_FOCUS_BUFF = { 14751 }
local VAMPIRIC_TOUCH_DEBUFF = { 34917, 34916, 34914 }
local SHADOW_WORD_PAIN_DEBUFF = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local VAMPIRIC_EMBRACE_DEBUFF = { 15286 }
local MIND_FLAY_IDS = { 25387, 18807, 17314, 17313, 17312, 17311, 15407 }
local DEVOURING_PLAGUE_DEBUFF = { 25467, 19280, 19279, 19278, 19277, 19276, 2944 }
local SHADOW_WEAVING_DEBUFF = { 15258 }  -- Shadow Weaving talent debuff (5-stack +2% shadow dmg/stack)
local PSYCHIC_SCREAM_BUFF = { 10890, 10888, 8124, 8122 }
local FADE_BUFF = { 25429, 10942, 10941, 9592, 9579, 9578, 586 }
local STARSHARDS_SPELL = { 25446, 19305, 19304, 19303, 19302, 19299, 19296, 10797 }
local HOLY_NOVA_SPELL = { 25331, 25329, 27805, 27804, 27803, 27801, 27800, 27799, 15431, 15430, 15237 }

local SILENCE_INTERRUPT_SPELL = { 15487 }          -- Shadow talent Silence (15pt, interrupt)

-- Long cooldown TTD gating thresholds (seconds)
local SHADOWFIEND_CD = 300
local INNER_FOCUS_CD = 180
local MIN_TTD_FOR_CD_SHADOWFIEND = 60     -- Don't summon if combat ends within 60s (won't get 2nd use)
local MIN_TTD_FOR_CD_INNER_FOCUS = 45     -- Don't burn Inner Focus if combat ends within 45s

local VT_CLIP_THRESHOLD = 1.5

-- Snapshot-aware refresh constants
local SPELL_DMG_UPGRADE_RATIO = 1.08    -- Refresh only if 8%+ spell damage upgrade
local BLOODLUST_LOWER_RATIO = 1.04      -- More aggressive upgrade threshold during Bloodlust/Heroism
local BLOODLUST_BUFFS = { 2825, 32182 }  -- Bloodlust (Horde) / Heroism (Alliance)
local REFRESH_EXTRA_WINDOW = 1.5         -- Extra seconds past pandemic window for upgrade refresh

-- Per-target cast lockout: prevents double-queuing a DoT to the same target
-- while a cast is in flight (matching FrostByte's lockout tracking)
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
    swd_ready = false,
    has_shadowform = false,
    has_inner_focus = false,
    has_inner_fire = false,
    combat_mode = "auto",          -- "auto" | "st" | "cleave" | "aoe"
    vt_refresh_window = 3,
    swp_refresh_window = 3,
    dp_refresh_window = 3,
    swd_safety_hp = 80,
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
    has_bloodlust = false,               -- Bloodlust/Heroism buff — enables more aggressive snapshot upgrades
    snapshot_target = nil,
}

local function build_state(context)
    local target = context.target
    local me = NS.GetPlayer()
    if not me then return shadow_state end
    local settings = context.settings or {}
    local mounted_bail = settings.shadow_mounted_bail
    if mounted_bail == nil or mounted_bail == true then
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
    shadow_state.swd_ready = target and NS.spell_ready(SPELLS.ShadowWordDeath, target, { expected_cooldown = 12 }) or false
    shadow_state.mf_channeling, shadow_state.mf_ticks = mf_tick.compute_channel_state(me, NS.game_time_ms(), MIND_FLAY_IDS)
    shadow_state.should_clip_mf = mf_tick.should_clip_mf(
        shadow_state.mf_channeling,
        shadow_state.mf_ticks,
        VT_CLIP_THRESHOLD,
        shadow_state.mb_ready,
        shadow_state.swd_ready,
        shadow_state.vt_remaining,
        shadow_state.swp_remaining
    )
    shadow_state.has_shadowform = me and NS.buff_up(me, SHADOWFORM_BUFF) or false
    shadow_state.has_inner_focus = me and NS.buff_up(me, INNER_FOCUS_BUFF) or false
    shadow_state.has_inner_fire = me and NS.buff_up(me, INNER_FIRE_BUFF) or false
    -- Combat mode: explicit setting or auto-detect
    local mode = settings.shadow_combat_mode or "auto"
    if mode == "auto" then
        enemy_count = shadow_state.enemy_count
        if enemy_count >= 5 then mode = "aoe"
        elseif enemy_count >= 3 then mode = "cleave"
        else mode = "st" end
    end
    shadow_state.combat_mode = mode
    -- Configurable refresh windows
    shadow_state.vt_refresh_window = settings.shadow_vt_refresh_window or 3
    shadow_state.swp_refresh_window = settings.shadow_swp_refresh_window or 3
    shadow_state.dp_refresh_window = settings.shadow_dp_refresh_window or 3
    -- Configurable safety thresholds
    shadow_state.swd_safety_hp = settings.shadow_swd_safety_hp or 80
    shadow_state.shield_hp = settings.shadow_shield_hp or 35
    shadow_state.flash_heal_hp = settings.shadow_flash_heal_hp or 25
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
    local mb_mana_floor = settings.shadow_mb_mana_floor or 30
    local conserve_mana_floor = settings.shadow_conserve_mana_floor or 15
    shadow_state.mana_low = shadow_state.mana_pct < mb_mana_floor
    shadow_state.mana_emergency = shadow_state.mana_pct < conserve_mana_floor

    -- Threat safety: gate burst behind tank threat lead
    -- Uses NS.is_threat_safe if available, otherwise assumes safe
    local threat_safe_enabled = (settings.shadow_threat_safe == nil and true) or settings.shadow_threat_safe
    if threat_safe_enabled and NS.is_threat_safe then
        shadow_state.threat_safe = NS.is_threat_safe(context)
    else
        shadow_state.threat_safe = true
    end
    shadow_state.in_combat = context.in_combat or false
    shadow_state.enemy_count = context.enemy_count or context.enemies_count or 1
    shadow_state.target_hp_pct = target and NS.unit_health_pct and NS.unit_health_pct(target) or 100
    shadow_state.target_casting = target and target.is_casting and target:is_casting() or false
    shadow_state.target_creature_type = target and NS.unit_creature_type and NS.unit_creature_type(target) or nil

    -- Current spell damage from NS (provided by middleware or character API)
    shadow_state.spell_damage = (NS.get_spell_damage and NS.get_spell_damage()) or context.spell_damage or 0
    -- Bloodlust/Heroism buff — enables more aggressive snapshot upgrade threshold
    shadow_state.has_bloodlust = me and NS.buff_up(me, BLOODLUST_BUFFS) or false
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
-- Action definitions
-- ============================================================================
local SHADOWFORM_ACTION = { name = "Shadowform", spell = SPELLS.Shadowform, target = "self", kind = "buff", buff = SHADOWFORM_BUFF, requires_target = false }
local SHADOWFIEND_ACTION = { name = "Shadowfiend", spell = SPELLS.Shadowfiend, expected_cooldown = 300 }
local VAMPIRIC_TOUCH_ACTION = { name = "VampiricTouch", spell = SPELLS.VampiricTouch, cooldown = 1.5 }
local SHADOW_WORD_PAIN_ACTION = { name = "ShadowWordPain", spell = SPELLS.ShadowWordPain, cooldown = 1.5 }
local VAMPIRIC_EMBRACE_ACTION = { name = "VampiricEmbrace", spell = SPELLS.VampiricEmbrace, cooldown = 1.5 }
local INNER_FOCUS_ACTION = { name = "InnerFocusMindBlast", spell = SPELLS.InnerFocus, target = "self", kind = "buff", buff = INNER_FOCUS_BUFF, cooldown = 180, requires_target = false }
local MIND_BLAST_ACTION = { name = "MindBlast", spell = SPELLS.MindBlast, cooldown = 5.5 }
local SHADOW_WORD_DEATH_ACTION = { name = "ShadowWordDeath", spell = SPELLS.ShadowWordDeath, cooldown = 12 }
local MIND_FLAY_ACTION = { name = "MindFlay", spell = SPELLS.MindFlay }
local DEVOURING_PLAGUE_ACTION = { name = "DevouringPlague", spell = SPELLS.DevouringPlague, cooldown = 3 }
local SILENCE_ACTION = { name = "Silence", spell = SPELLS.Silence, target = "self", requires_target = false, cooldown = 45 }
local PSYCHIC_SCREAM_ACTION = { name = "PsychicScream", spell = SPELLS.PsychicScream, cooldown = 30 }
local FADE_ACTION = { name = "Fade", spell = SPELLS.Fade, target = "self", kind = "buff", buff = FADE_BUFF, cooldown = 30, requires_target = false }
local DISPEL_MAGIC_ACTION = { name = "DispelMagic", spell = SPELLS.DispelMagic, target = "self", requires_target = false }
local SHACKLE_UNDEAD_ACTION = { name = "ShackleUndead", spell = SPELLS.ShackleUndead, cooldown = 1.5 }
local STARSHARDS_ACTION = { name = "Starshards", spell = SPELLS.Starshards, cooldown = 30 }
local INNER_FIRE_ACTION = { name = "InnerFire", spell = SPELLS.InnerFire, target = "self", kind = "buff", buff = INNER_FIRE_BUFF, requires_target = false }
local POWER_WORD_SHIELD_ACTION = { name = "PowerWordShield", spell = SPELLS.PowerWordShield, target = "self", kind = "buff", requires_target = false }
local FLASH_HEAL_ACTION = { name = "FlashHeal", spell = SPELLS.FlashHeal, target = "self", requires_target = false }

-- ============================================================================
-- Match functions
-- ============================================================================
local function shadowform_matches(context, s)
    if s.has_shadowform then return false end
    return NS.action_matches(context, SHADOWFORM_ACTION)
end

local function pre_combat_pull_matches(context, s)
    if context.in_combat then return false end
    if not context.has_valid_enemy_target then return false end
    if not s.has_shadowform then return false end
    -- Pull with Vampiric Touch (instant-cast DoT) if available, otherwise Mind Blast
    if NS.spell_ready and NS.spell_ready(SPELLS.VampiricTouch, context.target, { skip_range = false }) then
        return true
    end
    return false
end

local function shadowfiend_matches(context, s)
    if not can_break_mind_flay(s) then return false end
    if not context.has_valid_enemy_target then return false end
    if (context.mana_pct or 100) > 55 then return false end
    -- TTD gate: don't summon Shadowfiend if combat won't last long enough for its mana return
    if context.ttd and context.ttd > 0 and context.ttd < MIN_TTD_FOR_CD_SHADOWFIEND then return false end
    return NS.action_matches(context, SHADOWFIEND_ACTION)
end

local function shadow_swp_spread_matches(context, s)
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
    return NS.action_matches(context, SHADOW_WORD_PAIN_ACTION)
end

local function shadow_vt_spread_matches(context, s)
    if not can_break_mind_flay(s) then return false end
    -- Combat mode gate: only spread in cleave or aoe mode
    if s.combat_mode ~= "cleave" and s.combat_mode ~= "aoe" then return false end
    if s.enemy_count < 3 then return false end
    if not context.has_valid_enemy_target then return false end
    -- Per-target lockout: prevent double-queuing VT to same target while in-flight
    if _is_locked("VT") then return false end
    -- Avoid refreshing VT if still active on this target (spread to targets that don't have it)
    local vt_window = s.vt_refresh_window or 3
    if s.vt_remaining > 0 and s.vt_remaining > vt_window then return false end
    if s.vt_remaining > 0 and not should_snapshot_upgrade(s.spell_damage, s.snapshot_vt_dmg, s.vt_remaining, vt_window, SPELL_DMG_UPGRADE_RATIO) then return false end
    return NS.action_matches(context, VAMPIRIC_TOUCH_ACTION)
end

local function inner_fire_matches(context, s)
    if s.has_inner_fire then return false end
    local settings = context.settings or {}
    if settings.shadow_use_inner_fire == false then return false end
    return NS.action_matches(context, INNER_FIRE_ACTION)
end

local function power_word_shield_matches(context, s)
    -- HP-gated self-shield
    if (context.hp or 100) > (s.shield_hp or 35) then return false end
    -- Can't cast if Weakened Soul is active
    if s.has_weakened_soul then return false end
    if not NS.spell_ready(SPELLS.PowerWordShield, NS.PLAYER_UNIT, { skip_range = true }) then return false end
    return NS.action_matches(context, POWER_WORD_SHIELD_ACTION)
end

local function flash_heal_matches(context, s)
    -- HP-gated self-heal
    if (context.hp or 100) > (s.flash_heal_hp or 25) then return false end
    if context.is_moving then return false end
    return NS.action_matches(context, FLASH_HEAL_ACTION)
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
    if not can_break_mind_flay(s) then return false end
    if not context.has_valid_enemy_target then return false end
    if not context.in_combat then return false end
    -- TTD gate: don't use racials if target is about to die
    if context.ttd and context.ttd > 0 and context.ttd < 8 then return false end
    return true
end

local function vampiric_touch_matches(context, s)
    if not can_break_mind_flay(s) then return false end
    if context.is_moving then return false end
    if not context.has_valid_enemy_target or s.vt_remaining > (s.vt_refresh_window or 3) then return false end
    -- Mana emergency: drop all spells (wand only)
    if s.mana_emergency then return false end
    -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
    local ratio = s.has_bloodlust and BLOODLUST_LOWER_RATIO or SPELL_DMG_UPGRADE_RATIO
    if s.vt_remaining > 0 and not should_snapshot_upgrade(s.spell_damage, s.snapshot_vt_dmg, s.vt_remaining, 3, ratio) then return false end
    return NS.action_matches(context, VAMPIRIC_TOUCH_ACTION)
end

local function shadow_word_pain_matches(context, s)
    if not can_break_mind_flay(s) then return false end
    if not context.has_valid_enemy_target then return false end
    -- Mana emergency: drop all spells (wand only)
    if s.mana_emergency then return false end
    -- Shadow Weaving maintenance: extend refresh window from 3s to 5s when stacks < 5
    local sw_window = s.swp_refresh_window or 3
    local effective_window = (s.weaving_stacks > 0 and s.weaving_stacks < 5) and 5 or sw_window
    if s.swp_remaining > effective_window then return false end
    -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
    local ratio = s.has_bloodlust and BLOODLUST_LOWER_RATIO or SPELL_DMG_UPGRADE_RATIO
    if s.swp_remaining > 0 and not should_snapshot_upgrade(s.spell_damage, s.snapshot_swp_dmg, s.swp_remaining, sw_window, ratio) then return false end
    return NS.action_matches(context, SHADOW_WORD_PAIN_ACTION)
end

local function vampiric_embrace_matches(context, s)
    if not can_break_mind_flay(s) then return false end
    if not context.has_valid_enemy_target or s.ve_remaining > 10 then return false end
    return NS.action_matches(context, VAMPIRIC_EMBRACE_ACTION)
end

local function devouring_plague_matches(context, s)
    if not can_break_mind_flay(s) then return false end
    if not context.has_valid_enemy_target or s.dp_remaining > (s.dp_refresh_window or 3) then return false end
    -- Mana emergency: drop all spells (wand only)
    if s.mana_emergency then return false end
    -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
    local ratio = s.has_bloodlust and BLOODLUST_LOWER_RATIO or SPELL_DMG_UPGRADE_RATIO
    if s.dp_remaining > 0 and not should_snapshot_upgrade(s.spell_damage, s.snapshot_dp_dmg, s.dp_remaining, 3, ratio) then return false end
    return NS.action_matches(context, DEVOURING_PLAGUE_ACTION)
end

local function inner_focus_matches(context, s)
    if not can_break_mind_flay(s) then return false end
    if not context.in_combat or not s.mb_ready then return false end
    if s.has_inner_focus then return false end
    -- TTD gate: don't burn 180s cooldown if combat ends within threshold
    if context.ttd and context.ttd > 0 and context.ttd < MIN_TTD_FOR_CD_INNER_FOCUS then return false end
    return NS.action_matches(context, INNER_FOCUS_ACTION)
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
    return NS.action_matches(context, MIND_BLAST_ACTION)
end

local function shadow_word_death_matches(context, s)
    if not can_break_mind_flay(s) then return false end
    if (context.hp or 100) < (s.swd_safety_hp or 80) then return false end
    if not context.has_valid_enemy_target then return false end
    if not s.swd_ready then return false end
    -- Mana conservation: hold SW:D in emergency mana
    if s.mana_emergency then return false end
    -- Threat safety: hold SW:D if tank threat lead insufficient
    if not s.threat_safe then return false end
    return NS.action_matches(context, SHADOW_WORD_DEATH_ACTION)
end

local function mind_flay_matches(context, s)
    if context.is_moving or context.is_casting or context.is_channeling then return false end
    if not context.has_valid_enemy_target then return false end
    -- Mana emergency: drop all spells (wand only)
    if s.mana_emergency then return false end
    return NS.action_matches(context, MIND_FLAY_ACTION)
end

local function silence_matches(context, s)
    if not can_break_mind_flay(s) then return false end
    if not context.in_combat then return false end
    if not s.silence_ready then return false end
    if not context.target or not NS.unit_interruptible then
        -- Fallback: check target casting state without native interruptible API
        if not context.target_is_casting then return false end
    end
    return NS.action_matches(context, SILENCE_ACTION)
end

local function psychic_scream_matches(context, s)
    if not context.in_combat then return false end
    if s.enemy_count < 3 then return false end
    if not s.psychic_scream_ready then return false end
    return NS.action_matches(context, PSYCHIC_SCREAM_ACTION)
end

local function fade_matches(context, s)
    if not context.in_combat then return false end
    if s.enemy_count < 2 then return false end
    if not s.fade_ready then return false end
    return NS.action_matches(context, FADE_ACTION)
end

local function dispel_magic_matches(context, s)
    if not s.dispel_magic_ready then return false end
    return NS.action_matches(context, DISPEL_MAGIC_ACTION)
end

local function shackle_undead_matches(context, s)
    if not context.has_valid_enemy_target then return false end
    if s.target_creature_type ~= 6 then return false end
    if not s.shackle_undead_ready then return false end
    return NS.action_matches(context, SHACKLE_UNDEAD_ACTION)
end

local function starshards_matches(context, s)
    if not context.has_valid_enemy_target then return false end
    if context.is_moving then return false end
    return NS.action_matches(context, STARSHARDS_ACTION)
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
    { name = "PreCombatPull", matches = pre_combat_pull_matches, execute = function(context) return NS.action_execute(context, VAMPIRIC_TOUCH_ACTION, "[SHADOW]") end },
    { name = "Shadowform", matches = shadowform_matches, execute = function(context) return NS.action_execute(context, SHADOWFORM_ACTION, "[SHADOW]") end },
    { name = "Silence", matches = silence_matches, execute = function(context) return NS.action_execute(context, SILENCE_ACTION, "[SHADOW]") end },
    { name = "ManaBelow5Wand", matches = mana_below_5_wand_matches, execute = function(context) if NS.start_attack then NS.start_attack() end; return true end },
    { name = "Shadowfiend", matches = shadowfiend_matches, execute = function(context) return NS.action_execute(context, SHADOWFIEND_ACTION, "[SHADOW]") end },
    { name = "VampiricTouch", matches = vampiric_touch_matches, execute = function(context) local ok = NS.action_execute(context, VAMPIRIC_TOUCH_ACTION, "[SHADOW]"); if ok then shadow_state.snapshot_vt_dmg = shadow_state.spell_damage end; return ok end },
    { name = "ShadowWordPain", matches = shadow_word_pain_matches, execute = function(context) local ok = NS.action_execute(context, SHADOW_WORD_PAIN_ACTION, "[SHADOW]"); if ok then shadow_state.snapshot_swp_dmg = shadow_state.spell_damage end; return ok end },
    { name = "VampiricEmbrace", matches = vampiric_embrace_matches, execute = function(context) return NS.action_execute(context, VAMPIRIC_EMBRACE_ACTION, "[SHADOW]") end },
    { name = "DevouringPlague", matches = devouring_plague_matches, execute = function(context) local ok = NS.action_execute(context, DEVOURING_PLAGUE_ACTION, "[SHADOW]"); if ok then shadow_state.snapshot_dp_dmg = shadow_state.spell_damage end; return ok end },
    { name = "InnerFocusMindBlast", matches = inner_focus_matches, execute = function(context) return NS.action_execute(context, INNER_FOCUS_ACTION, "[SHADOW]") end },
    { name = "MindBlast", matches = mind_blast_matches, execute = function(context) return NS.action_execute(context, MIND_BLAST_ACTION, "[SHADOW]") end },
    { name = "ShadowWordDeath", matches = shadow_word_death_matches, execute = function(context) return NS.action_execute(context, SHADOW_WORD_DEATH_ACTION, "[SHADOW]") end },
    { name = "MindFlay", matches = mind_flay_matches, execute = function(context) return NS.action_execute(context, MIND_FLAY_ACTION, "[SHADOW]") end },
    { name = "PsychicScream", matches = psychic_scream_matches, execute = function(context) return NS.action_execute(context, PSYCHIC_SCREAM_ACTION, "[SHADOW]") end },
    { name = "Fade", matches = fade_matches, execute = function(context) return NS.action_execute(context, FADE_ACTION, "[SHADOW]") end },
    { name = "DispelMagic", matches = dispel_magic_matches, execute = function(context) return NS.action_execute(context, DISPEL_MAGIC_ACTION, "[SHADOW]") end },
    { name = "ShackleUndead", matches = shackle_undead_matches, execute = function(context) return NS.action_execute(context, SHACKLE_UNDEAD_ACTION, "[SHADOW]") end },
    { name = "SWPSpread", matches = shadow_swp_spread_matches, execute = function(context) _set_lockout("SWP", 3000); local ok = NS.action_execute(context, SHADOW_WORD_PAIN_ACTION, "[SHADOW]"); if ok then shadow_state.snapshot_swp_dmg = shadow_state.spell_damage end; return ok end },
    { name = "VTSpread", matches = shadow_vt_spread_matches, execute = function(context) _set_lockout("VT", 3000); local ok = NS.action_execute(context, VAMPIRIC_TOUCH_ACTION, "[SHADOW]"); if ok then shadow_state.snapshot_vt_dmg = shadow_state.spell_damage end; return ok end },
    { name = "InnerFire", matches = inner_fire_matches, execute = function(context) return NS.action_execute(context, INNER_FIRE_ACTION, "[SHADOW]") end },
    { name = "PowerWordShield", matches = power_word_shield_matches, execute = function(context) return NS.action_execute(context, POWER_WORD_SHIELD_ACTION, "[SHADOW]") end },
    { name = "FlashHeal", matches = flash_heal_matches, execute = function(context) return NS.action_execute(context, FLASH_HEAL_ACTION, "[SHADOW]") end },
    { name = "HolyNovaAoE", matches = holy_nova_aoe_matches, execute = function(context) return NS.action_execute(context, { name = "HolyNova", spell = SPELLS.HolyNova, cooldown = 6 }, "[SHADOW]") end },
    { name = "RacialBerserking", matches = racial_matches, execute = function(context) return NS.action_execute(context, { name = "Berserking", spell = SPELLS.Berserking, target = "self", requires_target = false }, "[SHADOW]") end },
    { name = "RacialBloodFury", matches = racial_matches, execute = function(context) return NS.action_execute(context, { name = "BloodFury", spell = SPELLS.BloodFury, target = "self", requires_target = false }, "[SHADOW]") end },
    { name = "RacialArcaneTorrent", matches = racial_matches, execute = function(context) return NS.action_execute(context, { name = "ArcaneTorrent", spell = SPELLS.ArcaneTorrent, target = "self", requires_target = false }, "[SHADOW]") end },
    { name = "Starshards", matches = starshards_matches, execute = function(context) return NS.action_execute(context, STARSHARDS_ACTION, "[SHADOW]") end },
}

NS.rotation_registry:register("shadow", strategies, { get_state = build_state })
NS.log("Priest shadow rotation registered (Tier A)")
return strategies
