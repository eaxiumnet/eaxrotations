-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-28
-- Change: Classic Vanilla Affliction Warlock rotation
-- =========================================================================
local __eax_file = "classes/warlock/affliction_vanilla.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-28"
local __eax_change = "Classic Vanilla Affliction Warlock rotation"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Classic Vanilla Warlock Affliction priority list with multi-DoT cycling, Nightfall procs, and execute drain.
-- ============================================================================
-- What: Classic Vanilla Warlock Affliction multi-DoT rotation with curses, drains, and execute handling
-- When: Per tick
-- Why: Refresh windows and proc tracking need cached state to keep DoTs stable
-- Safety: Spell IDs are ordered newest-to-oldest; optional data uses pcall; timers and lookups are nil-guarded
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.WarlockSpells or {}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { potions = {} } } end
local TBC_POTIONS = (TBC.ITEMS and TBC.ITEMS.potions) or {}
local _reagent_guard_ok, _reagent_guard = pcall(require, "shared/reagent_guard_sylvanas")
if not _reagent_guard_ok then _reagent_guard = nil end

-- ============================================================================
-- Debuff & Buff ID tables
-- ============================================================================
local CORRUPTION_DEBUFF      = { 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local CURSE_OF_AGONY_DEBUFF  = { 11713, 11712, 11711, 6217, 1014, 980 }
local CURSE_OF_DOOM_DEBUFF   = { 603 }
local UNSTABLE_AFFL_DEBUFF   = { }  -- UA is TBC-only; empty in Classic
local SIPHON_LIFE_DEBUFF     = { 18881, 18880, 18879, 18265 }
local IMMOLATE_DEBUFF        = { 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }	local SHADOW_EMBRACE_DEBUFF  = { }  -- Shadow Embrace is TBC-only; empty in Classic	local ISB_DEBUFF = { 17800 } -- Shadow Vulnerability (ISB proc debuff)
local CURSE_OF_ELEMENTS_DEBUFF = { 11722, 11721, 1490 }
local SEED_OF_CORRUPTION_DEBUFF = { }  -- Seed is TBC-only; empty in Classic
local NIGHTFALL_BUFF         = { 17941 }  -- Shadow Trance
local THREAT_REDUCTION_BUFF   = { }  -- UnavailableClassicWarlockThreat is TBC-only; empty in Classic
local FEL_ARMOR_BUFF         = { }  -- Fel Armor is TBC-only; empty in Classic
local DEMON_ARMOR_BUFF       = { 11735, 11734, 11733, 1086, 706 }

local DOT_REFRESH_WINDOW = 1.5   -- refresh within last 1.5s per Research Angle 1 (clip <1.5s)
local EXECUTE_HP = 25           -- Drain Soul execute threshold
local LIFE_TAP_SAFETY_HP = 35   -- don't Life Tap below this HP%

-- Snapshot-aware refresh constants
local SPELL_DMG_UPGRADE_RATIO = 1.08    -- Refresh only if 8%+ spell damage upgrade
local REFRESH_EXTRA_WINDOW = 1.5         -- Extra seconds past pandemic window for upgrade refresh    -- Local anti-spam: UnavailableClassicWarlockThreat has 5min CD, use local timer as fallback for broken API
    local _last_soulshatter = 0

local LOCAL_SPELLS = {
    DrainLife       = NS.spell_action({ 11700, 11699, 7651, 709, 699, 689 }, "DrainLife"),
    DrainSoul       = NS.spell_action({ 11675, 8289, 8288, 1120 }, "DrainSoul"),
    DarkPact        = NS.spell_action({ 18938, 18937, 18220 }, "DarkPact"),
    Fear            = NS.spell_action({ 6215, 6213, 5782 }, "Fear"),
    HowlOfTerror    = NS.spell_action({ 17928, 5484 }, "HowlOfTerror"),
    CurseWeakness   = NS.spell_action({ 11708, 11707, 7646, 6205, 1108, 702 }, "CurseOfWeakness"),
    CurseTongues    = NS.spell_action({ 11719, 1714 }, "CurseOfTongues"),
    CurseExhaustion = NS.spell_action({ 18223 }, "CurseOfExhaustion"),
    CurseElements   = NS.spell_action({ 11722, 11721, 1490 }, "CurseOfElements"),
    DrainMana       = NS.spell_action({ 11704, 11703, 6226, 5138 }, "DrainMana"),
    HealthFunnel    = NS.spell_action({ 11695, 11694, 11693, 3700, 3699, 3698, 755 }, "HealthFunnel"),
    CreateHealthstone = NS.spell_action({ 11730, 11729, 6202, 6201, 5699 }, "CreateHealthstone"),
    FelDomination   = NS.spell_action({ 18708 }, "FelDomination"),
    DeathCoil       = NS.spell_action({ 17926, 17925, 6789 }, "DeathCoil"),
    ShadowWard      = NS.spell_action({ 11740, 11739, 6229 }, "ShadowWard"),
    DemonArmor      = NS.spell_action({ 11735, 11734, 11733, 1086, 706 }, "DemonArmor"),
    FelArmor        = nil,  -- Fel Armor is TBC-only
    AmplifyCurse    = NS.spell_action({ 18288 }, "AmplifyCurse"),
    BloodFury       = NS.spell_action({ 20572 }, "BloodFury"),
    Berserking      = NS.spell_action({ 20554 }, "Berserking"),
    ArcaneTorrent   = nil,  -- Arcane Torrent is TBC-only (Blood Elf racial)
    CreateSoulstone = NS.spell_action({ 20756, 20755, 20752, 693 }, "CreateSoulstone"),
    Shoot           = NS.spell_action({ 5019 }, "Shoot"),
}

local MANA_POTION_IDS = {
    13444,  -- Major Mana Potion
    13443,  -- Superior Mana Potion
}
local HEALTHSTONE_IDS = { 19013, 19012, 19011, 19010, 19009, 19008, 19007, 19006, 19005, 19004, 5510, 5509, 5511, 5512 }
local SOULSTONE_BUFF_IDS = { 20765, 20764, 20763, 20762, 20707 }
local SOULSTONE_ITEMS = { 16896, 16895, 16893, 16892, 5232 }

-- ============================================================================
-- State builder (pre-allocated)
-- ============================================================================
local aff_state = {
    -- DoT remains on target
    ua_remains = 0,
    corruption_remains = 0,
    agony_remains = 0,
    doom_remains = 0,
    siphon_remains = 0,
    immolate_remains = 0,	    -- Shadow Embrace stacks
	    se_stacks = 0,
	    -- Improved Shadow Bolt (Shadow Vulnerability) stacks
	    isb_stacks = 0,
    -- Proc
    nightfall_active = false,
    -- Resources
    mana_pct = 100,
    hp_pct = 100,
    target_hp = 100,
    -- Pet
    pet_alive = false,
    pet_health = 100,
    pet_mana = 100,
    -- Items
    mana_potion_id = nil,
    healthstone_id = nil,
    healthstone_ready = false,
    amplify_curse_ready = false,
    -- Soulstone / Wand
    has_soulstone = false,
    wand_learned = false,    -- Snapshot state (spell damage when DoT was applied — persisted across build_state calls)
    spell_damage = 0,
    snapshot_ua_dmg = 0,
    snapshot_corruption_dmg = 0,
    snapshot_siphon_dmg = 0,
    snapshot_immolate_dmg = 0,
    snapshot_target = nil,
    -- AoE
    enemy_count = 1,
}

local function build_state(context)
    local target = context.target
    if target then
        aff_state.ua_remains = NS.debuff_remains and NS.debuff_remains(target, UNSTABLE_AFFL_DEBUFF) or 0
        aff_state.corruption_remains = NS.debuff_remains and NS.debuff_remains(target, CORRUPTION_DEBUFF) or 0
        aff_state.agony_remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_AGONY_DEBUFF) or 0
        aff_state.doom_remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_DOOM_DEBUFF) or 0
        aff_state.siphon_remains = NS.debuff_remains and NS.debuff_remains(target, SIPHON_LIFE_DEBUFF) or 0
        aff_state.immolate_remains = NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF) or 0
        aff_state.coe_remains = NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_ELEMENTS_DEBUFF) or 0
        aff_state.se_stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, SHADOW_EMBRACE_DEBUFF) or 0
		        aff_state.isb_stacks = NS.get_debuff_stacks and NS.get_debuff_stacks(target, ISB_DEBUFF) or 0
	        aff_state.target_hp = (target.get_health_percentage and target:get_health_percentage()) or 100
	    else
	        aff_state.ua_remains = 0
	        aff_state.corruption_remains = 0
	        aff_state.agony_remains = 0
	        aff_state.siphon_remains = 0
	        aff_state.immolate_remains = 0
            aff_state.coe_remains = 0
            aff_state.se_stacks = 0
		        aff_state.isb_stacks = 0
	        aff_state.target_hp = 100
	    end
	    -- Nightfall proc
	    aff_state.nightfall_active = NS.has_player_buff(NIGHTFALL_BUFF)
	    -- Resources
	    aff_state.mana_pct = context.mana_pct or 100
	    aff_state.hp_pct = context.hp or 100
	    aff_state.enemy_count = context.enemy_count or 1            -- Pet status (via pet object if available)
            local pet = context.pet
            if pet then
                aff_state.pet_alive = (pet.is_alive and pet:is_alive())
                aff_state.pet_health = (pet.get_health_percentage and pet:get_health_percentage()) or 100
                aff_state.pet_mana = (pet.get_mana_percentage and pet:get_mana_percentage()) or 100
            else
                aff_state.pet_alive = false
                aff_state.pet_health = 100
                aff_state.pet_mana = 100
            end
            -- Amplify Curse readiness
            aff_state.amplify_curse_ready = NS.spell_ready(LOCAL_SPELLS.AmplifyCurse, NS.PLAYER_UNIT, { skip_range = true })	-- Current spell damage from NS (provided by middleware or character API)
	    aff_state.spell_damage = context.spell_damage or 0
	    -- Classic haste buff — enables more aggressive snapshot upgrade threshold
	    aff_state.has_bloodlust = false
	    -- Maintain snapshot state: reset snapshots if DoT expired (stale)
	    local target_key = target and (target.get_guid and target:get_guid()) or nil
	    if target_key ~= aff_state.snapshot_target then
	        -- Target changed: reset all snapshots for fresh tracking
	        aff_state.snapshot_ua_dmg = 0
	        aff_state.snapshot_corruption_dmg = 0
	        aff_state.snapshot_siphon_dmg = 0
	        aff_state.snapshot_immolate_dmg = 0
	        aff_state.snapshot_target = target_key
	    else
	        -- Reset per-DoT snapshot if DoT completely fell off
	        if aff_state.ua_remains <= 0 then aff_state.snapshot_ua_dmg = 0 end
	        if aff_state.corruption_remains <= 0 then aff_state.snapshot_corruption_dmg = 0 end
	        if aff_state.siphon_remains <= 0 then aff_state.snapshot_siphon_dmg = 0 end
	        if aff_state.immolate_remains <= 0 then aff_state.snapshot_immolate_dmg = 0 end
	    end
    -- Items
    aff_state.mana_potion_id = nil
    for _, id in ipairs(MANA_POTION_IDS) do
        if NS.is_item_ready and NS.is_item_ready(id) then aff_state.mana_potion_id = id; break end
    end
    aff_state.healthstone_id = nil
    aff_state.healthstone_ready = false
    if NS.is_item_ready then
        for _, id in ipairs(HEALTHSTONE_IDS) do
            local ok, ready = pcall(NS.is_item_ready, id)
            if ok and ready then
                aff_state.healthstone_id = id
                aff_state.healthstone_ready = true
                break
            end
        end
    end
    -- Soulstone buff check (pre-combat self-buff)
    local me = context.me
    aff_state.has_soulstone = me and NS.has_player_buff and NS.has_player_buff(SOULSTONE_BUFF_IDS) or false
    if not aff_state.has_soulstone and NS.has_item then
        for _, id in ipairs(SOULSTONE_ITEMS) do
            if NS.has_item(id) then aff_state.has_soulstone = true; break end
        end
    end
    -- Wand (Shoot) spell readiness
    aff_state.wand_learned = NS.spell_exists and NS.spell_exists(5019) or false
    return aff_state
	end

	-- ============================================================================
	-- Snapshot upgrade logic
	-- ============================================================================
	
	-- Determine if current spell damage justifies refreshing a DoT early
	-- Returns true if: DoT expired, in pandemic window with upgrade, or about to fall off
	local function should_snapshot_upgrade(current_dmg, snapshotted_dmg, remains, refresh_window, ratio)
	    -- Always refresh if DoT has expired
	    if remains <= 0 then return true end
	    -- Always refresh if in pandemic window (about to fall off anyway)
	    if remains <= refresh_window then return true end
	    -- No previous snapshot to compare — refresh normally
	    if snapshotted_dmg <= 0 then return true end
	    -- Upgrade refresh: only if current damage is significantly higher AND still within extended window
	    if current_dmg >= snapshotted_dmg * ratio and remains <= refresh_window + REFRESH_EXTRA_WINDOW then
	        return true
	    end
	    return false
	end

	-- ============================================================================
	-- Helper functions
	-- ============================================================================

-- Select which curse to use based on context
local function select_curse(context, state)
    if context.is_pvp then
        if context.enemy_healer then return "tongues" end
        if context.melee_on_you then return "exhaustion" end
    end
    if (state.enemy_count or 0) >= 3 then return "elements" end  -- AoE benefit
    return "agony"  -- default: damage
end

-- Racial ability match gate for all racial strategies
local function racial_matches(context, state)
    if not context.has_valid_enemy_target then return false end
    if not context.in_combat then return false end
    -- TTD gate: don't use racials if target is about to die
    if context.ttd and context.ttd > 0 and context.ttd < 8 then return false end
    return true
end

-- Throttle DoT re-matches when aura APIs are broken on private servers.
local function broken_api_dot_throttled(spell_id)
    return NS.is_api_health_broken and NS.is_api_health_broken() and NS.recent_spell_cast and NS.recent_spell_cast(spell_id, 2.0)
end
local strategies = {

    -- ------------------------------------------------------------------------
    -- 1. Death Coil (survival heal + CC)
    -- ------------------------------------------------------------------------
    {
        name = "DeathCoilSurvival",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.hp_pct or 100) > 30 then return false end
            return NS.spell_ready(LOCAL_SPELLS.DeathCoil, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.DeathCoil, context.target, "[AFFL] Death Coil (survival + heal)")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 2. Healthstone
    -- ------------------------------------------------------------------------
    {
        name = "Healthstone",
        matches = function(context, state)
            if (context.hp or 100) > 40 then return false end
            return state and state.healthstone_ready == true
        end,
        execute = function(_, state)
            return state and state.healthstone_id and NS.use_item_by_id and NS.use_item_by_id(state.healthstone_id) or false
        end,
    },

    -- ------------------------------------------------------------------------
    -- 3. UnavailableClassicWarlockThreat (threat reduction)
    -- ------------------------------------------------------------------------
    {
        name = "UnavailableClassicWarlockThreat",
        matches = function(context, state)
            return false
        end,
        execute = function(context)
            local me = context.me or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
            local ok = NS.try_cast(SPELLS.UnavailableClassicWarlockThreat, me, "[AFFL] UnavailableClassicWarlockThreat", { skip_range = true })
            if ok then _last_soulshatter = NS.time_now() end
            return ok
        end,
    },

    -- ------------------------------------------------------------------------
    -- 4. Nightfall proc — instant Shadow Bolt
    -- ------------------------------------------------------------------------
    {
        name = "NightfallProc",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if not state.nightfall_active then return false end
            return NS.spell_ready(SPELLS.ShadowBolt, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.ShadowBolt, context.target, "[AFFL] Nightfall instant Shadow Bolt")
        end,
    },

    {
        name = "DrainLife",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.hp_pct or 100) > 55 then return false end
            if context.is_channeling then return false end
            return NS.spell_ready(LOCAL_SPELLS.DrainLife, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.DrainLife, context.target, "[AFFL] Drain Life sustain")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 5. Unstable Affliction (primary DoT — dispel protection)
    -- ------------------------------------------------------------------------
    {
        name = "UnavailableClassicWarlockDot",
        matches = function(context, state)
            return false
        end,
        execute = function(context)
            local ok = NS.try_cast(SPELLS.UnavailableClassicWarlockDot, context.target, "[AFFL] Unstable Affliction")
            if ok then aff_state.snapshot_ua_dmg = aff_state.spell_damage end
            return ok
        end,
    },

    -- ------------------------------------------------------------------------
    -- 6. Corruption (instant DoT)
    -- ------------------------------------------------------------------------
    {
        name = "CorruptionDoT",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if broken_api_dot_throttled(25311) then return false end
            if (state.corruption_remains or 0) > DOT_REFRESH_WINDOW then return false end	            -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
	            local ratio = SPELL_DMG_UPGRADE_RATIO
	            if (state.corruption_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_corruption_dmg or 0, state.corruption_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            return NS.spell_ready(SPELLS.Corruption, context.target)
        end,
        execute = function(context)
            local ok = NS.try_cast(SPELLS.Corruption, context.target, "[AFFL] Corruption")
            if ok then aff_state.snapshot_corruption_dmg = aff_state.spell_damage end
            return ok
        end,
    },

    -- ------------------------------------------------------------------------
    -- 7. Siphon Life (DoT + self-heal, if talented)
    -- Requires ISB debuff on target to maximize Shadow damage benefit
    -- ------------------------------------------------------------------------
    {
        name = "SiphonLife",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.siphon_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
	            local ratio = SPELL_DMG_UPGRADE_RATIO
	            if (state.siphon_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_siphon_dmg or 0, state.siphon_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            -- Siphon Life is talent-gated; spell won't be ready if not learned
            return NS.spell_ready(SPELLS.SiphonLife, context.target)
        end,
        execute = function(context)
            local ok = NS.try_cast(SPELLS.SiphonLife, context.target, "[AFFL] Siphon Life")
            if ok then aff_state.snapshot_siphon_dmg = aff_state.spell_damage end
            return ok
        end,
    },

    -- ------------------------------------------------------------------------
    -- 8. Curse of Doom (long-lived PvE targets)
    -- ------------------------------------------------------------------------
    {
        name = "CurseOfDoom",
        matches = function(context, state)
            if not context.target then return false end
            if not context.has_valid_enemy_target then return false end
            -- Don't refresh if already applied and still ticking
            if (state.doom_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Only on long-lived targets (Doom takes 60s to tick)
            if context.ttd and context.ttd < 62 then return false end
            return NS.spell_ready(SPELLS.CurseOfDoom, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.CurseOfDoom, context.target, "[AFFL] Curse of Doom")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 9. Curse of Agony (long DoT curse)
    -- ------------------------------------------------------------------------
    {
        name = "CurseOfAgony",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            local curse = select_curse(context, state)
            if curse ~= "agony" then return false end
            if (state.agony_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- On short-lived targets, CoA may not run full duration
            if context.ttd and context.ttd < 8 then return false end
            return NS.spell_ready(SPELLS.CurseOfAgony, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.CurseOfAgony, context.target, "[AFFL] Curse of Agony")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 9. Immolate (optional DoT, lower prio for Affliction)
    -- ------------------------------------------------------------------------
    {
        name = "ImmolateDoT",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.immolate_remains or 0) > DOT_REFRESH_WINDOW then return false end
            -- Skip if target TTD is very short
            if context.ttd and context.ttd < 5 then return false end	            -- Snapshot-aware: hold refresh if current spell damage is not an upgrade over snapshotted
	            local ratio = SPELL_DMG_UPGRADE_RATIO
	            if (state.immolate_remains or 0) > 0 and not should_snapshot_upgrade(state.spell_damage or 0, state.snapshot_immolate_dmg or 0, state.immolate_remains or 0, DOT_REFRESH_WINDOW, ratio) then return false end
            return NS.spell_ready(SPELLS.Immolate, context.target)
        end,
        execute = function(context)
            local ok = NS.try_cast(SPELLS.Immolate, context.target, "[AFFL] Immolate")
            if ok then aff_state.snapshot_immolate_dmg = aff_state.spell_damage end
            return ok
        end,
    },

    -- ------------------------------------------------------------------------
    -- 9a. Amplify Curse (before CoD/CoA/CoE — 3 min cooldown)
    -- ------------------------------------------------------------------------
    -- Fires when a curse is about to be applied and Amplify Curse is off cooldown
    {
        name = "AmplifyCurse",
        matches = function(context, state)
            if not context.target then return false end
            if not state.amplify_curse_ready then return false end
            -- Gate: setting check
            if context.settings and context.settings.aff_use_amplify_curse == false then return false end
            -- Only use on targets that live long enough (60s+ to warrant 3min CD)
            if context.ttd and context.ttd < 60 then return false end
            -- Check if a curse is about to be applied (CoD, CoA, or Curse of Elements)
            local about_to_curse = false
            if (state.agony_remains or 0) <= DOT_REFRESH_WINDOW and context.ttd and context.ttd >= 8 then about_to_curse = true end
            if (state.doom_remains or 0) <= DOT_REFRESH_WINDOW and context.ttd and context.ttd >= 62 then about_to_curse = true end
            -- Also check CoD cooldown via spell_ready (60s CD, if ready with no debuff it's about to be cast)
            if context.target and (state.doom_remains or 0) <= 0 and NS.spell_ready(SPELLS.CurseOfDoom, context.target) then about_to_curse = true end
            return about_to_curse
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.AmplifyCurse, NS.PLAYER_UNIT, "[AFFL] Amplify Curse", { skip_range = true })
        end,
    },

    -- ------------------------------------------------------------------------
    -- 10. Seed of Corruption (AoE 3+ targets)
    -- ------------------------------------------------------------------------
    {
        name = "UnavailableClassicWarlockAoe",
        matches = function(context, state)
            return false
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.UnavailableClassicWarlockAoe, context.target, "[AFFL] Seed of Corruption")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 11. Drain Soul (execute <25%)
    -- ------------------------------------------------------------------------
    {
        name = "DrainSoulExecute",
        matches = function(context, state)
            if not context.has_valid_enemy_target then return false end
            if (state.target_hp or 100) > EXECUTE_HP then return false end
            if context.is_channeling then return false end
            return NS.spell_ready(LOCAL_SPELLS.DrainSoul, context.target)
        end,
        execute = function(context, state)
            return NS.try_cast(LOCAL_SPELLS.DrainSoul, context.target,
                string.format("[AFFL] Drain Soul execute (%.0f%%)", (state and state.target_hp) or 0))
        end,
    },

    -- ------------------------------------------------------------------------
    -- 12. Shadow Bolt (filler)
    -- ------------------------------------------------------------------------
    {
        name = "PreCombatPull",
        matches = function(context)
            if context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            -- Range check: Shadow Bolt has 30yd range
            if context.target_range and context.target_range > 28 then return false end
            -- Pre-cast Shadow Bolt on pull timer targets
            return NS.spell_ready(SPELLS.ShadowBolt, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.ShadowBolt, context.target, "[AFFL] Pre-combat Shadow Bolt")
        end,
    },

    {
        name = "ShadowBoltFiller",
        matches = function(context)
            if not context.has_valid_enemy_target then return false end
            return NS.spell_ready(SPELLS.ShadowBolt, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.ShadowBolt, context.target, "[AFFL] Shadow Bolt filler")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 13. Life Tap (HP → Mana)
    -- ------------------------------------------------------------------------
    {
        name = "LifeTap",
        max_mana = 65,
        matches = function(context, state)
            local threshold = math.min(context.settings and context.settings.aff_life_tap_mana or 30, 65)
            if (state.mana_pct or 100) > threshold then return false end
            if (state.hp_pct or 100) < LIFE_TAP_SAFETY_HP then return false end
            return NS.spell_ready(SPELLS.LifeTap, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.LifeTap, NS.PLAYER_UNIT, "[AFFL] Life Tap")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 14. Dark Pact (pet mana drain)
    -- ------------------------------------------------------------------------
    {
        name = "DarkPact",
        matches = function(context, state)
            local threshold = context.settings and context.settings.aff_dark_pact_mana or 20
            if (state.mana_pct or 100) > threshold then return false end
            if not state.pet_alive then return false end
            if (state.pet_mana or 0) < 20 then return false end
            return NS.spell_ready(LOCAL_SPELLS.DarkPact, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.DarkPact, NS.PLAYER_UNIT, "[AFFL] Dark Pact")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 16. Mana potion
    -- ------------------------------------------------------------------------
    {
        name = "ManaPotion",
        matches = function(context, state)
            local threshold = context.settings and context.settings.aff_mana_potion or 15
            if (state.mana_pct or 100) > threshold then return false end
            return state.mana_potion_id ~= nil
        end,
        execute = function(_, state)
            if NS.use_item_by_id then NS.use_item_by_id(state.mana_potion_id) end
            return true
        end,
    },

    -- ------------------------------------------------------------------------
    -- Racial abilities (off-GCD, usable in combat)
    -- ------------------------------------------------------------------------
    {
        name = "RacialBerserking",
        matches = function(context, state) return racial_matches(context, state) and NS.spell_ready(LOCAL_SPELLS.Berserking, NS.PLAYER_UNIT, { skip_range = true }) end,
        execute = function() return NS.try_cast(LOCAL_SPELLS.Berserking, NS.PLAYER_UNIT, "[AFFL] Berserking", { skip_range = true }) end,
    },
    {
        name = "RacialBloodFury",
        matches = function(context, state) return racial_matches(context, state) and NS.spell_ready(LOCAL_SPELLS.BloodFury, NS.PLAYER_UNIT, { skip_range = true }) end,
        execute = function() return NS.try_cast(LOCAL_SPELLS.BloodFury, NS.PLAYER_UNIT, "[AFFL] Blood Fury", { skip_range = true }) end,
    },
    {
        name = "RacialArcaneTorrent",
        matches = function(context, state) return LOCAL_SPELLS.ArcaneTorrent and racial_matches(context, state) and NS.spell_ready(LOCAL_SPELLS.ArcaneTorrent, context.target) end,
        execute = function(context) return NS.try_cast(LOCAL_SPELLS.ArcaneTorrent, context.target, "[AFFL] Arcane Torrent") end,
    },

    -- ------------------------------------------------------------------------
    -- PvP Section
    -- ------------------------------------------------------------------------
    {
        name = "PvP_Fear",
        matches = function(context)
            if not context.is_pvp then return false end
            if not context.target then return false end
            return NS.spell_ready(LOCAL_SPELLS.Fear, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.Fear, context.target, "[AFFL PvP] Fear")
        end,
    },
    {
        name = "PvP_HowlOfTerror",
        matches = function(context)
            if not context.is_pvp then return false end
            if not context.melee_on_you then return false end
            return NS.spell_ready(LOCAL_SPELLS.HowlOfTerror, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.HowlOfTerror, NS.PLAYER_UNIT, "[AFFL PvP] Howl of Terror")
        end,
    },
    {
        name = "PvP_CurseExhaustion",
        matches = function(context, state)
            if not context.is_pvp then return false end
            if not context.target then return false end
            if not context.melee_on_you then return false end
            return NS.spell_ready(LOCAL_SPELLS.CurseExhaustion, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CurseExhaustion, context.target, "[AFFL PvP] Curse of Exhaustion kite")
        end,
    },
    {
        name = "PvP_CurseTongues",
        matches = function(context)
            if not context.is_pvp then return false end
            if not context.target then return false end
            if not context.enemy_caster then return false end
            return NS.spell_ready(LOCAL_SPELLS.CurseTongues, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CurseTongues, context.target, "[AFFL PvP] Curse of Tongues")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 21. Demon Armor / Fel Armor (out of combat)
    -- ------------------------------------------------------------------------
    {
        name = "DemonArmorBuff",
        matches = function(context)
            if context.in_combat then return false end
            local me = context.me or (NS.GetPlayer and NS.GetPlayer())
            if me and NS.buff_remains(me, DEMON_ARMOR_BUFF) > 0 then return false end
            return NS.spell_ready(LOCAL_SPELLS.DemonArmor, me or NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.DemonArmor, NS.PLAYER_UNIT, "[AFFL] Demon Armor")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 22. Health Funnel (heal pet)
    -- ------------------------------------------------------------------------
    {
        name = "HealthFunnelPet",
        matches = function(context, state)
            if not state.pet_alive then return false end
            if (state.pet_health or 100) > 40 then return false end
            return NS.spell_ready(LOCAL_SPELLS.HealthFunnel, context.pet)
        end,
        execute = function(context)
            if context.pet then
                return NS.try_cast(LOCAL_SPELLS.HealthFunnel, context.pet, "[AFFL] Health Funnel pet")
            end
            return false
        end,
    },

    -- ------------------------------------------------------------------------
    -- 23. Curse of Elements (raid debuff)
    -- ------------------------------------------------------------------------
    {
        name = "CurseOfElements",
        matches = function(context, state)
            if not context.target then return false end
            if state and (state.coe_remains or 0) > 10 then return false end
            return NS.spell_ready(LOCAL_SPELLS.CurseElements, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.CurseElements, context.target, "[AFFL] Curse of Elements")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 24. Shadow Ward (shadow absorb)
    -- ------------------------------------------------------------------------
    {
        name = "ShadowWard",
        matches = function(context)
            if not context.is_pvp then return false end
            if not context.enemy_shadow_caster then return false end
            return NS.spell_ready(LOCAL_SPELLS.ShadowWard, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.ShadowWard, NS.PLAYER_UNIT, "[AFFL PvP] Shadow Ward")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 25. Soulstone (pre-combat self-buff)
    -- ------------------------------------------------------------------------
    {
        name = "SelfSoulstone",
        matches = function(context, state)
            if context.in_combat then return false end
            if state.has_soulstone then return false end
            -- Require at least one soul shard to create
            local reagent = NS.ReagentGuard or _reagent_guard
            if reagent and reagent.check_reagent then
                local spell_id = LOCAL_SPELLS.CreateSoulstone and LOCAL_SPELLS.CreateSoulstone.id and LOCAL_SPELLS.CreateSoulstone:id()
                if spell_id and not reagent.check_reagent(spell_id) then return false end
            end
            return NS.spell_ready(LOCAL_SPELLS.CreateSoulstone, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(LOCAL_SPELLS.CreateSoulstone, NS.PLAYER_UNIT, "[AFFL] Create Soulstone (self-buff)")
        end,
    },

    -- ------------------------------------------------------------------------
    -- 26. Wand (Shoot) — mana conservation fallback
    -- ------------------------------------------------------------------------
    {
        name = "Wand",
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.wand_learned then return false end
            local wand_threshold = context.settings and context.settings.aff_wand_mana or 15
            if (state.mana_pct or 100) >= wand_threshold then return false end
            if not context.has_valid_enemy_target then return false end
            return NS.spell_ready(LOCAL_SPELLS.Shoot, context.target)
        end,
        execute = function(context)
            return NS.try_cast(LOCAL_SPELLS.Shoot, context.target, "[AFFL] Wand (mana conservation)")
        end,
    },
}

NS.rotation_registry:register("affliction", strategies, { get_state = build_state })
return { strategies = strategies, build_state = build_state }


