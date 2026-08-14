-- behavioral_audit.lua -- Behavioral battery harness for sylvanas (TBC) AND wotlk spec files.
-- WHAT:  Loads every classes/<class>/<spec>_<era>.lua (era = "sylvanas" TBC default,
--        "wotlk" incl. Death Knight blood/frost/unholy) with a permissive mocked NS,
--        then runs each spec's strategy table across a battery of realistic combat
--        contexts exactly like the dispatcher (build state once, first match wins)
--        and reports which strategies fire and which NEVER fire across the battery.
-- WHEN:  Run standalone (`lua behavioral_audit.lua [wotlk]`, report-only, exit 0) or
--        via run_verify_all.lua (which parses this harness's never-firing totals
--        and pins the live contract: TBC never=13, WotLK 0).
-- WHY:   Structural audits already pass (spell IDs exist, load compliance, safe_state
--        nil-guards). This harness hunts the SILENT-GATE defect class -- a strategy
--        that can never return true in any realistic state (e.g. the cat Rip TTD bug:
--        combo points banked forever because the only finisher was unreachable).
-- SAFETY: Pure read-only analysis with a mocked API. Spec loading is pcall-guarded;
--        no files are edited, no io side effects.
--
-- NOTE: This harness runs in a LENIENT mock. A strategy that never fires is a
-- TRIAGE CANDIDATE, not proof of a bug: it may be legitimately situational (stealth
-- only, PvP only, out-of-combat only, opt-in setting off). Each candidate must be
-- reviewed against its match() function before any fix.
--
-- KNOWN LENIENCY (UPDATED 2026-08-09): spell_exists()/is_spell_learned() are
-- map-aware via the not_learned bank (a scenario can mark an id unlearned, so
-- fallbacks like cat ClawFallback before Mangle ARE observable — see
-- cat_claw_fallback). Residual leniency: snapshot-upgrade strategies (Rip/Rake
-- Snapshot) read the module-local snapshot_state populated only by a prior
-- in-combat cast the battery cannot reproduce, and enh FireNovaReplacement
-- reads module-local totem_state.fire_nova_active set by the totem-drop
-- lifecycle — all three are genuinely unpinnable (classified (c) in
-- tools/spec_scorecard.lua LANE_CLASS with rationale). Treat those NEVER
-- entries as mock limitations, not bugs.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

-- Lua 5.4 compat: global unpack was moved to table.unpack (safe on 5.1/5.2 too)
local unpack = table.unpack or unpack

local M = {}

-- Scenario clock: advanced by apply_battery_state so 1s module caches refresh.
local _battery_now = 100.0

-- ---------------------------------------------------------------------------
-- Spec manifests per era. `sylvanas` = TBC-era spec files (battery default,
-- every never-lane pin + scorecard totals are keyed to this set); `wotlk` =
-- the 41 WotLK files including Death Knight blood/frost/unholy + leveling.
M.SPEC_FILES = {
    druid = { "balance", "bear", "cat", "caster", "resto" },
    hunter = { "beast_mastery", "marksmanship", "survival" },
    mage = { "arcane", "fire", "frost" },
    paladin = { "holy", "protection", "retribution" },
    priest = { "discipline", "holy", "shadow", "smite" },
    rogue = { "assassination", "combat", "subtlety" },
    shaman = { "elemental", "enhancement", "restoration" },
    warlock = { "affliction", "demonology", "destruction" },
    warrior = { "arms", "fury", "protection", "kebab" },
}

-- (b) close-out (2026-08-10): per-spec require-time race override. smite binds
-- _player_race from load_player:get_race_id() at module load (smite:30-32);
-- the mock defaults to race 1 (human) so both racial lanes were structurally
-- dead. Loading smite as night elf (4) makes Starshards observable.
-- Threat-family close-out (2026-08-10): smite ALSO carries DevouringPlague
-- gated on race 5 (undead, smite:32) — one spec, two exclusive races.
-- RACE_VARIANTS loads the spec again per extra race and run_all merges the
-- never lists (a lane stays never only if it never fires under ANY variant
-- race), so both Starshards and DevouringPlague are observable.
M.RACE_OVERRIDES = { smite = 4 }
M.RACE_VARIANTS = { smite = { 5 } }

-- Race-gated vanilla lanes (2026-08-11): the vanilla battery loaded smite as
-- race 1 (human) because RACE_OVERRIDES/RACE_VARIANTS were era-gated to
-- sylvanas, leaving Starshards + DevouringPlague structurally dead. Vanilla
-- smite gates on the SAME race ids as TBC (smite_vanilla:28-29: night elf 4
-- for Starshards, undead 5 for DevouringPlague) — verified era-correct:
-- Classic Forsaken priests learn Devouring Plague at level 20 (Blizzard
-- Watch priest-racials guide), Night Elves learn Starshards at 10; TBC-era
-- sources (2.4.3 notes listing Shadowguard as the Troll racial, Apr-2008
-- GameFAQs calling Devouring Plague the Undead priest racial) confirm the
-- races did NOT swap between eras — the 2.0.1 'shuffle' is a myth; the real
-- change was Cataclysm, when DP became baseline for all priests. So the
-- vanilla lanes are a HARNESS gap, not a rotation defect: mirror the TBC
-- mechanism for the vanilla era. (warlock RacialArcaneTorrent is NOT here —
-- blood elves are TBC-only, so that lane is impossible-by-design and stays
-- pinned with evidence at affliction_vanilla.lua:83.)
M.RACE_OVERRIDES_VANILLA = { smite = 4 }
M.RACE_VARIANTS_VANILLA = { smite = { 5 } }

-- Per-era race override/variant lookup. RACE_VARIANTS loads a spec again per
-- extra race so exclusive-race lanes are observable under every race that can
-- gate them; run_all merges the never lists (a lane stays never only if it
-- never fires under ANY variant race). Era-scoped so a WotLK-era smite load
-- can't silently pick up a TBC or vanilla binding. Exposed on M so
-- test_race_override_regression.lua can pin the era-scoping.
function M.race_maps_for(era)
    if era == "vanilla" then return M.RACE_OVERRIDES_VANILLA, M.RACE_VARIANTS_VANILLA end
    if era == "sylvanas" then return M.RACE_OVERRIDES, M.RACE_VARIANTS end
    return nil, nil
end

M.SPEC_FILES_WOTLK = {
    deathknight = { "blood", "frost", "leveling", "unholy" },
    druid = { "balance", "bear", "cat", "leveling", "resto" },
    hunter = { "beast_mastery", "leveling", "marksmanship", "survival" },
    mage = { "arcane", "fire", "frost", "leveling" },
    paladin = { "holy", "leveling", "protection", "retribution" },
    priest = { "discipline", "holy", "leveling", "shadow" },
    rogue = { "assassination", "combat", "leveling", "subtlety" },
    shaman = { "elemental", "enhancement", "leveling", "restoration" },
    warlock = { "affliction", "demonology", "destruction", "leveling" },
    warrior = { "arms", "fury", "leveling", "protection" },
}

-- Vanilla era (Classic 1.15.x): ALL 40 spec files — the 31 non-leveling specs
-- mirror the TBC manifest shape, plus the 9 per-class leveling_vanilla files
-- (wave 1.4 coverage extension, 2026-08-13: the leveling files previously ran
-- only via run_leveling_tests.lua, so the behavioral battery never covered
-- 13 of the 40 vanilla files). Vanilla files are plain-style — they return
-- their strategies table directly and register get_state via
-- NS.rotation_registry (fury_vanilla is the canonical example) — which the
-- harness supports via the registry mock in build_ns + the run_spec build_state
-- fallback. leveling_vanilla files return { strategies, build_state } and
-- require shared/leveling_sylvanas, whose require-time `local NS =
-- _G.EaxRotations` binding is refreshed per load_spec (see the leveling_sylvanas
-- package.loaded cleanup below), so each leveling spec sees its own mock NS.
-- check_manifest_drift includes leveling_ for the vanilla era for the same
-- reason the WotLK era does (leveling files ARE battery specs there).
M.SPEC_FILES_VANILLA = {
    druid = { "balance", "bear", "cat", "caster", "leveling", "resto" },
    hunter = { "beast_mastery", "leveling", "marksmanship", "survival" },
    mage = { "arcane", "fire", "frost", "leveling" },
    paladin = { "holy", "leveling", "protection", "retribution" },
    priest = { "discipline", "holy", "leveling", "shadow", "smite" },
    rogue = { "assassination", "combat", "leveling", "subtlety" },
    shaman = { "elemental", "enhancement", "leveling", "restoration" },
    warlock = { "affliction", "demonology", "destruction", "leveling" },
    warrior = { "arms", "fury", "kebab", "leveling", "protection" },
}

-- SoD era (Season of Discovery, 2026-08-14, W4.3): ALL 20 _sod.lua spec files
-- (the 19-run role set plus warrior tank_warrior). SoD files gate every
-- strategy on context.is_sod and read rune/phase/form state through the REAL
-- shared/sod_context_sylvanas enrich (wired in run_spec, era == "sod"), so
-- the battery exercises the production producer instead of hand-built fields.
-- NOTE: unlike the other eras there are NO non-spec helper files under the
-- _sod.lua suffix (priest/healing_sod.lua IS a spec, so the healing_ prefix
-- exclusion is era-gated OFF for sod — see check_manifest_drift).
M.SPEC_FILES_SOD = {
    druid = { "balance", "feral", "restoration", "tank" },
    hunter = { "dps_hunter" },
    mage = { "dps_mage" },
    paladin = { "protection", "retribution" },
    priest = { "healing", "shadow" },
    rogue = { "combat", "tank" },
    shaman = { "elemental", "enhancement", "restoration", "warden" },
    warlock = { "dps", "tank" },
    warrior = { "dps_warrior", "tank_warrior" },
}

M.ERA_MANIFESTS = { sylvanas = M.SPEC_FILES, wotlk = M.SPEC_FILES_WOTLK, vanilla = M.SPEC_FILES_VANILLA, sod = M.SPEC_FILES_SOD }

-- Class profiles used to build representative contexts.
M.CLASS_PROFILE = {
    druid   = { resource = "energy", mana = true, form = true, melee = true, class_id = 11 },
    hunter  = { resource = "focus", mana = true, pet = true, ranged = true, class_id = 3 },
    mage    = { resource = "mana", mana = true, ranged = true, class_id = 8 },
    paladin = { resource = "mana", mana = true, melee = true, class_id = 2 },
    priest  = { resource = "mana", mana = true, ranged = true, healer = true, class_id = 5 },
    rogue   = { resource = "energy", melee = true, class_id = 4 },
    shaman  = { resource = "mana", mana = true, melee = true, healer = true, totem = true, class_id = 7 },
    warlock = { resource = "mana", mana = true, ranged = true, pet = true, class_id = 9 },
    warrior = { resource = "rage", melee = true, class_id = 1 },
    -- WotLK Death Knight (Phase 1): rune/resource profile; presence replaces
    -- stance, handled via the PresenceManager stub in build_ns.
    deathknight = { resource = "runic_power", mana = true, melee = true, class_id = 6 },
}

M.CLASS_IDS = {
    warrior = 1, paladin = 2, hunter = 3, rogue = 4,
    priest = 5, deathknight = 6, shaman = 7, mage = 8, warlock = 9, druid = 11,
    -- Uppercase aliases mirror api/common/enums class_id so specs that gate on
    -- enums.class_id.PRIEST etc. pass when the real enums module is unable to
    -- load under the harness package.path (api/ absent, .api/ not on path).
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4,
    PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

-- Power type constants (mirror ns.POWER_* set per spec in build_ns).
M.POWER = { MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3, COMBO = 4 }

-- ---------------------------------------------------------------------------
-- (b) close-out (2026-08-10): scenario-driven enemy mock for resto's
-- scan_pvp_pressure (GetEnemiesInRange). PRIEST (5) lands in resto
-- HEALER_CLASS_IDS; melee uses WARRIOR (1). Unit surface covers everything
-- the PvP-pressure scan + offensive-dispel preemptive scan read.
-- ---------------------------------------------------------------------------
local function _battery_enemy(kind)
    return {
        is_valid = function() return true end,
        is_alive = function() return true end,
        is_dead = function() return false end,
        is_cc = function() return false end,
        get_name = function() return "AuditEnemy_" .. kind end,
        get_class = function() return kind == "healer" and 5 or 1 end,
        get_distance = function() return 5 end,
        get_target = function() return nil end,
        get_health_percentage = function() return 100 end,
        get_active_spell_id = function() return 0 end,
        get_active_cast_or_channel_id = function() return 0 end,
    }
end

-- ---------------------------------------------------------------------------
-- Helper: one shared permissive unit mock.
-- ---------------------------------------------------------------------------
local function _me_unit(class_id)
    return {
        get_power = function(self, p) return 100 end,
        get_max_power = function(self, p) return 100 end,
        get_health_percentage = function(self) return 100 end,
        get_health = function(self) return 10000 end,
        -- NO get_mana_percentage: mock-only member removed in W3.4 (see
        -- _scenario_me tripwire) — production reads context.mana_pct or
        -- me:mana_pct() / NS.unit_mana_pct(me).
        -- 0.4s sits inside both pooling (<=0.45) and powershift (>0.35) windows.
        energy_predicted = function(self) return 100 end,
        energy_time_to_x = function(self, v) return 0.4 end,
        is_in_combat = function(self) return true end,
        get_distance = function(self, t) return 5 end,
        get_shapeshift_form_id = function(self) return 0 end,
        get_attack_power = function(self) return 500 end,
        get_player_stance = function(self) return 0 end,
        get_race_id = function(self) return M._race_override or 1 end,
        -- vec3 position (contract verified 2026-08-08): the platform's
        -- get_position returns ONE vec3 TABLE {x,y,z} (with [1]/[2] index
        -- aliases) — see shared/auto_loot (p.x,p.y,p.z), shared/targeting
        -- (pos.x,pos.y,pos.z) and EaxESP (base.x or base[1]). The Intervene
        -- close-out wrongly modeled multi-value returns; prot now reads the
        -- table form too (protection:430/767), and shaman's my_pos.x reads
        -- were already correct.
        get_position = function(self) return { x = 0, y = 0, z = 0, [1] = 0, [2] = 0 } end,
        is_behind = function(self) return true end,
        get_armor = function(self) return 1000 end,
        is_moving = function(self) return false end,
        get_class = function(self) return class_id or 0 end,
        get_name = function(self) return "AuditPlayer" end,
        is_in_party = function(self) return true end,
        is_in_raid = function(self) return false end,
        get_friends_in_range = function(self) return {} end,
    }
end

local function _target()
    return {
        is_valid = function(self) return true end,
        is_dead = function(self) return false end,
        is_player = function(self) return false end,
        get_health_percentage = function(self) return 100 end,
        get_health = function(self) return 10000 end,
        get_distance = function(self) return 5 end,
        get_creature_type = function(self) return 7 end,
        get_classification = function(self) return 0 end,
        is_behind = function(self, u) return true end,
        is_casting = function(self) return false end,
        is_channeling = function(self) return false end,
        is_interruptible = function(self) return true end,
        get_armor = function(self) return 1000 end,
        get_max_health = function(self) return 10000 end,
        get_max_power = function(self) return 0 end,
        get_power = function(self) return 0 end,
        get_name = function(self) return "AuditTarget" end,
        get_attack_power = function(self) return 0 end,
        get_target = function(self) return nil end,
    }
end

local function _friend(hp, dist, class_id, opts)
    hp = type(hp) == "number" and hp or 100
    opts = opts or {}
    local f = {
        is_valid = function(self) return true end,
        is_dead = function(self) return hp <= 0 end,
        is_player = function(self) return true end,
        get_health_percentage = function(self) return hp end,
        get_health = function(self) return hp * 100 end,
        get_distance = function(self) return dist or 30 end,
        get_creature_type = function(self) return 7 end,
        get_power = function(self) return 0 end,
        get_max_power = function(self) return 0 end,
        get_name = function(self) return "AuditFriend" end,
        hp = hp,
        -- Threat-family close-out (2026-08-10): opts.role feeds bear growl's
        -- target-of-target is_tank/is_healer reads (get_group_role);
        -- opts.threat_status / opts.has_aggro feed prot's ally-threatened scan
        -- (protection:584 reads the FIELD directly). All default nil —
        -- is_tank/is_healer read false and the threat scan skips, identical to
        -- the pre-opts behavior for every existing _friend consumer.
        get_group_role = function(self) return opts.role end,
        threat_status = opts.threat_status,
        has_aggro = opts.has_aggro,
        -- vec3 position (contract verified 2026-08-08): one {x,y,z} table
        -- with [1]/[2] aliases, matching the real API; prot's party scan
        -- (protection:443) reads the table fields for Intervene's range gate.
        get_position = function(self) return { x = 0, y = 0, z = 0, [1] = 0, [2] = 0 } end,
    }
    -- Class-id (ranked #4): only present when a scenario sets it via the
    -- `friend_class` override (druid/resto innervate + balance scan friends via
    -- unit_class_id -> get_class to find a healer ally). Absent by default so
    -- no other spec's class reads change.
    if type(class_id) == "number" then
        f.get_class = function(self) return class_id end
    end
    return f
end

-- ---------------------------------------------------------------------------
-- Rich, permissive NS mock. Battery scenarios can override individual closures
-- (e.g. NS.buff_up returning true) by mutating the returned table.
-- ---------------------------------------------------------------------------
function M.build_ns(class_key, era)
    era = era or "sylvanas"
    local ns = {}
    local profile = M.CLASS_PROFILE[class_key] or {}
    local class_id = profile.class_id or 0
    -- Scenario-aware player unit: holy/smite build_state derive
    -- context.hp = health_pct(NS.PLAYER_UNIT), and the unit-aware health_pct
    -- helper (import_helpers) reads unit.get_health_percentage when present.
    -- An empty stub made that read fall back to 100 and CLOBBER the scenario's
    -- low_self hp override, hiding every priest self-preservation lane.
    -- Delegate to the state bank so it reflects ctx.hp after apply_battery_state.
    ns.PLAYER_UNIT = {
        get_health_percentage = function(self) return ns._bstate("hp", 100) end,
        get_health = function(self) return ns._bstate("hp", 100) * 100 end,
    }
    ns.POWER_MANA = 0
    ns.POWER_RAGE = 1
    ns.POWER_ENERGY = 3
    ns.POWER_COMBO = 4
    ns.POWER_FOCUS = 2

    -- Warrior specs resolve ACTION ids through NS.WarriorSpells (mirrors
    -- classes/warrior/class_sylvanas.lua SPELLS). Seeded just below, after
    -- ns.spell_action is defined, so the entries are spell_action objects
    -- (method surface = live fidelity) — see the WarriorSpells block near
    -- ns.spell_action.
    ns.WarriorSpells = {}
    ns.PaladinSpells = {}
    ns.HunterSpells = {}
    ns.MageSpells = {}
    ns.WarlockSpells = {}
    ns.PriestSpells = {}
    ns.ShamanSpells = {}
    ns.RogueSpells = {}
    ns.DruidSpells = {}
    -- WotLK Death Knight spell table (Phase 1): empty table is fine —
    -- define_action_for_class falls back to ns.spell_action on a nil field,
    -- but the table must EXIST so `NS.DeathKnightSpells or {}` in the spec
    -- files resolves consistently and DKConstants reads don't hit nil.
    ns.DeathKnightSpells = {}
    ns.DeathKnightConstants = {
        FROST_FEVER_DEBUFF = { 55095 },
        BLOOD_PLAGUE_DEBUFF = { 55078 },
        HORN_OF_WINTER_BUFF = { 57623, 57330 },
    }
    ns.CLASS_ID = M.CLASS_IDS
    ns.class_id = M.CLASS_IDS
    ns.WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
        -- Mirrors classes/warrior/class_sylvanas.lua so kebab's
        -- Constants.BUFF_ID.SWEEPING_STRIKES index doesn't error on nil.
        BUFF_ID = { SWEEPING_STRIKES = 12328 },
    }
    ns.STANCE = ns.WarriorConstants.STANCE

    ns.log = function() end
    ns.debug = false
    ns.player_class_id = 0

    -- Scenario-aware clock: apply_battery_state advances _battery_now each
    -- scenario so module-level 1s scan caches (e.g. hunter_core pet scan,
    -- swing/mend cooldown gates) actually refresh between scenarios instead of
    -- pinning to scenario #1's state forever.
    ns.time_now = function() return _battery_now end
    ns.game_time_ms = function() return _battery_now * 1000 end
    ns.now_ms = function() return _battery_now * 1000 end
    ns._battery_now = _battery_now
    ns.core = {
        -- Scenario-aware clock (2026-08-08): enhancement's TotemicCall caches
        -- _core = NS.core at load time and throttles the visible-object scan
        -- on _core.time(); without a time() here now=0 always and the 1s
        -- throttle returns the stale cached result, never scanning.
        time = function() return _battery_now end,
        -- Scenario-aware (2026-08-08): enhancement's TotemicCall caches
        -- _get_totem_info = NS.core.spell_book.get_totem_info at load time;
        -- the totem_far scenario sets the totem_active bank key so the
        -- has_totem gate passes. Default (no key) keeps the legacy nil.
        spell_book = {
            get_totem_info = function(slot)
                if ns._bstate("totem_active") then return { have_totem = true } end
                return nil
            end,
            -- (b) close-out (2026-08-10): demo pet-type detection
            -- (demonology:210-228) reads NS.core.spell_book.get_pet_spells() to
            -- classify imp vs succubus. Bank-driven; the pvp_succubus scenario
            -- presents a Lash of Pain id (27274) so pet_type_succubus binds.
            get_pet_spells = function() return ns._bstate("pet_spells", {}) end,
        },
        -- Scenario-aware mirror of the load_spec _G.core stub: the visible
        -- scan (enh TotemicCall, prot threat scan) must see the scenario's
        -- visible_enemies list through the same bank.
        object_manager = { get_visible_objects = function() return ns._bstate("visible_enemies", {}) end },
    }

    -- Warrior spec files call NS.import_helpers("try_cast", ...) at load; the
    -- real implementation is populated by warrior/shared_helpers_sylvanas.lua
    -- on class registration. Return a permissive stub per requested name.
    ns.import_helpers = function(...)
        local names = { ... }
        local typed_map = {
            debuff_remains = 0, debuff_stacks = 0, buff_remains = 0,
            buff_stacks = 0,
        }
        local floaty = {
            -- NOTE: has_player_buff is NOT here on purpose — it has its own
            -- branch above that forwards to the map-aware ns.has_player_buff
            -- (buff_remains_map), so a constant false here would be dead data.
            -- NOTE: spell_ready is NOT here on purpose (2026-08-13) — see its
            -- dedicated forwarding branch below (bank-aware via ns.spell_ready).
            player_control_locked = false, has_breakable_cc_nearby = false,
            can_attack_target = true,
            try_cast = true, spell_exists = true,
        }
        local results = {}
        for i = 1, #names do
            local n = names[i]
            if n == "health_pct" then
                -- Unit-aware: read the scenario target/unit HP (scenarios set
                -- target_hp), NOT a constant 100 — otherwise build_state
                -- calls like kebab's context.target_hp = health_pct(target)
                -- clobber the scenario override back to 100.
                results[i] = function(unit)
                    if unit and unit.get_health_percentage then
                        local ok, v = pcall(unit.get_health_percentage, unit)
                        if ok and type(v) == "number" then return v end
                    end
                    return 100
                end
            elseif n == "has_player_buff" then
                -- Per-buff state (Phase 3): specs capture this helper AT
                -- require() time (holy_sylvanas.lua:240-242 imports
                -- has_player_buff; ClearcastingGreaterHeal + SurgeOfLightSmite
                -- gate on the per-buff flags). A constant `false` here would
                -- deadlock those lanes even though the map-aware
                -- ns.has_player_buff (buff_remains_map) is defined later in
                -- build_ns — forward to the LATEST binding at call time.
                results[i] = function(ids)
                    if ns.has_player_buff then return ns.has_player_buff(ids) end
                    return false
                end
            elseif n == "buff_up" then
                -- Map-aware per-buff state (ranked #5 semantics): smite /
                -- priest-healing capture buff_up via import_helpers at require
                -- time. Without this branch the catch-all below returns a
                -- constant-true function, so every captured buff check read
                -- "up" and SoloRenew (needs has_renew=false) + InnerFocus
                -- (needs has_inner_focus=false) could never fire. Forward to
                -- the LATEST ns.buff_up binding (map-first + buffs_up
                -- fallback) at call time, mirroring has_player_buff.
                results[i] = function(unit, ids)
                    if ns.buff_up then return ns.buff_up(unit, ids) end
                    return false
                end
            elseif n == "spell_ready" then
                -- Vanilla sweep follow-up (2026-08-13): forward to the LATEST
                -- ns.spell_ready binding (bank-aware via cooldown_remains).
                -- holy_vanilla captures spell_ready at require time
                -- (holy_vanilla:125) and its AbolishDisease pre-emptive branch
                -- gates on `not state.cure_disease_ready` — the old constant-
                -- true capture made the asymmetric cure pair (CureDisease on
                -- CD → AbolishDisease) inexpressible, so AbolishDisease could
                -- never fire even in the holy_cure_on_cd scenario. Only
                -- vanilla specs capture spell_ready this way (smite_vanilla:
                -- 66, kebab_vanilla:53, holy_vanilla:125 — verified no TBC
                -- spec does, 2026-08-13), so the change is era-safe, and
                -- forwarding can only SHRINK the never list: lanes gated on
                -- `not spell_ready(X)` become observable, while lanes gated on
                -- spell_ready(X) == true keep firing in every scenario that
                -- does not put X on cd.
                results[i] = function(spell, target, opts)
                    if ns.spell_ready then return ns.spell_ready(spell, target, opts) end
                    return true
                end
            elseif typed_map[n] ~= nil then
                results[i] = function() return typed_map[n] end
            elseif floaty[n] ~= nil then
                results[i] = function() return floaty[n] end
            else
                results[i] = function() return true end
            end
        end
        return unpack(results)
    end

    -- Scenario-aware learned/exists mock (ranked #9): the low_level scenario
    -- marks pre-level spells as NOT learned via the `not_learned` state-bank
    -- key ({ [spell_id] = true }). Default (no key) keeps the legacy
    -- everything-learned behavior, so non-leveling scenarios are untouched.
    -- Both spell_exists and is_spell_learned share the check — a spell that
    -- isn't learned yet also isn't in the spellbook (arcane
    -- low_level_bolt_matches reads spell_exists(ArcaneBlast 30451); frost
    -- frost_armor_matches reads is_spell_learned(MageArmor 27125/6117);
    -- warlock needs_imp_fallback reads is_spell_learned(30146)/688).
    -- Accepts numeric ids and spell_action tables (checks all rank ids — same
    -- normalization as the bank-aware get_spell_cd; keep them in sync).
    -- NOTE: the not_learned map is global per scenario (not spec-scoped), so
    -- the ids a scenario marks must remain class-specific (the low_level map
    -- is mage/warlock only).
    local function not_learned(spell)
        local nl = ns._bstate("not_learned", nil)
        if type(nl) ~= "table" or not spell then return false end
        local ids = type(spell) == "number" and { spell } or (type(spell) == "table" and spell.ids) or {}
        for _, id in ipairs(ids) do
            if nl[id] then return true end
        end
        return false
    end
    ns.spell_exists = function(spell) return not not_learned(spell) end
    ns.spell_ready = function(spell, target, opts)
        return ns.cooldown_remains(spell) <= 0
    end
    ns.is_spell_learned = function(spell) return not not_learned(spell) end
    ns.spell_cooldown_ready = function() return true end
    -- Scenario-driven cooldowns: scenarios set on_cd = { [spell_id] = seconds }.
    -- Accepts both numeric spell IDs and NS spell_action tables (kebab style).
    ns.cooldown_remains = function(spell)
        local on_cd = ns._bstate("on_cd", nil)
        if type(on_cd) == "table" and spell then
            local id = type(spell) == "number" and spell or (type(spell) == "table" and spell.ids and spell.ids[1])
            if id and on_cd[id] then return on_cd[id] end
        end
        return 0
    end

    ns.buff_up = function() return false end
    ns.buff_remains = function() return 0 end
    ns.buff_points = function() return nil end
    ns.debuff_up = function() return false end
    ns.debuff_remains = function() return 0 end
    ns.debuff_points = function() return nil end
    ns.get_buff_stacks = function() return 0 end
    ns.get_debuff_stacks = function() return 0 end
    ns.aura_remains = function() return 0 end
    -- Form-aware has_form: form id comes from the scenario state bank (default
    -- 0 = caster). Previously returned true unconditionally, which made every
    -- druid spec believe it was shapeshifted: cat damage actions fired in every
    -- scenario while form-gated strategies (CatForm, HealthPotion-while-cat,
    -- powershift) could NEVER match. Map names to the same ids the specs use
    -- (cat=3, bear=1, travel=4, moonkin=2).
    local FORM_IDS = { caster = 0, bear = 1, moonkin = 2, cat = 3, travel = 4, aquatic = 5, flight = 6 }
    ns.has_form = function(name)
        local form = ns._bstate("form", 0) or 0
        if name == nil then return form ~= 0 end
        -- String forms ("cat"/"bear") come from the leveling_wotlk scenarios
        -- (leveling_wotlk compares state.form STRINGS) and must match by NAME;
        -- numeric ids compare against FORM_IDS. Without this branch a string
        -- form would silently read as "not in form" for every name — the same
        -- string-in-numeric-slot hazard fixed for ctx.stance below.
        if type(form) == "string" then return form == name end
        local want = FORM_IDS[name]
        if want == nil then return false end
        return form == want
    end
    ns.is_stealthed = function() return ns._bstate("is_stealthed", false) end
    ns.pet_hp_pct = function() return ns._bstate("pet_hp", 100) end
    ns.pet_alive = function() return not (ns._bstate("pet_dead", false) == true) end
    ns.get_player_stance = function() return 0 end
    -- Wave 1.4 (2026-08-13): bank-aware is_behind_target. The druid
    -- leveling_vanilla Claw lane reads NS.is_behind_target DIRECTLY (no
    -- context.is_behind preference like cat_sylvanas/cat_vanilla), so the
    -- constant-true stub made its shred-preference gate (skip Claw when Shred
    -- is usable from behind) block the lane forever. Bank-aware with a TRUE
    -- default keeps every existing scenario byte-identical (cat specs read
    -- context.is_behind first, combat_vanilla/assassination read the same
    -- true default); the cat_lev_claw scenario flips it off.
    ns.is_behind_target = function() return ns._bstate("is_behind", true) ~= false end
    ns.get_combo_points = function() return 0 end
    ns.combo_points = function() return 0 end

    ns.power_current = function() return 100 end
    ns.energy = function() return 100 end
    ns.focus = function() return 100 end
    ns.get_power = function() return 100 end
    ns.get_max_power = function() return 100 end
    ns.power_pct = function() return 100 end
    ns.mana_pct = function() return 100 end
    ns.health_pct = function() return 100 end
    ns.mana = function() return 100 end

    -- (b) close-out (2026-08-10): return the scenario-aware me unit once
    -- apply_battery_state publishes ns.me, so build_state reads that resolve
    -- the player via NS.GetPlayer() (shadow:460, warlock files, etc.) see the
    -- SAME unit the debuff_up/debuff_remains player-map branch compares
    -- against (SW:D CC break's is_breakable_cc_active(me, NS)). Before this,
    -- GetPlayer() minted a fresh default mock every call, so player-debuff
    -- reads via me never matched ns.me. Require-time reads (smite's
    -- load_player race binding) still hit the default mock — ns.me is nil
    -- until the first scenario.
    ns.GetPlayer = function() return ns.me or _me_unit(class_id) end

    ns.try_cast = function() return true end
    ns.use_item_by_id = function() return true end
    ns.is_item_ready = function() return true end
    ns.get_item_count = function() return 1 end
    ns.use_item = function() return true end

    ns.get_setting = function(key, default)
        -- Scenario-aware: setting_overrides flow through the spec_kit fallback
        -- chain (spec_kit.setting -> NS.get_setting), so e.g.
        -- { holy_refresh_enabled = false } (fsr_pause) disables paladin
        -- choose_blessing (BlessingRefresh would otherwise fire before
        -- FSRPause — buffs_up makes every blessing "up" with exactly 120s
        -- remaining == the refresh threshold). Unconfigured keys return nil.
        local ov = ns._bstate("setting_overrides", nil)
        if type(ov) == "table" and key and ov[key] ~= nil then return ov[key] end
        return nil
    end
    -- Vanilla-era support (2026-08-11): mirror core/settings.lua's NS.setting
    -- (context.settings first, then NS.get_setting, then default). The vanilla
    -- files capture `local setting = NS.setting` at require time — without the
    -- stub, subtlety_vanilla's matchers (option()/Evasion/Vanish/Preparation/
    -- Feint, subtlety_vanilla:133-368) crashed on every scenario and all seven
    -- of its lanes reported never. Scenario-aware via the get_setting chain.
    ns.setting = function(context, key, default)
        local settings = context and context.settings
        if settings and settings[key] ~= nil then return settings[key] end
        if ns.get_setting then
            -- get_setting returns nil for unconfigured keys (deliberately, so
            -- spec_kit.setting's chain can apply ITS default) — NS.setting must
            -- fall through to its own default in that case (engine semantics).
            local v = ns.get_setting(key, nil)
            if v ~= nil then return v end
        end
        return default
    end
    -- Scenario-aware settings: `setting_overrides = { [setting_key] = value }`
    -- (e.g. { seal_twisting_enabled = true }) flips get_any_setting for the
    -- scenario; unconfigured keys return nil, so retri can_twist stays false
    -- everywhere except the seal-twist scenarios (retribution_sylvanas.lua:403
    -- falls back to the `true` default only when the setting is unreadable,
    -- which we must NOT mimic battery-wide or SealTwistPrepCommand would fire
    -- in every scenario at the default 0.5s swing).
    ns.get_any_setting = function(ctx, key, key2, default)
        local ov = ns._bstate("setting_overrides", nil)
        if type(ov) == "table" then
            if key and ov[key] ~= nil then return ov[key] end
            if key2 and ov[key2] ~= nil then return ov[key2] end
        end
        return nil
    end

    local _ok_kit, _spec_kit = pcall(require, "shared/spec_kit_sylvanas")
    local function _setting_bool(ctx, key, def)
        if _ok_kit and _spec_kit and _spec_kit.setting_bool then
            return _spec_kit.setting_bool(ctx, key, def)
        end
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] ~= false end
        return def ~= false
    end
    local function _setting_number(ctx, key, def)
        if _ok_kit and _spec_kit and _spec_kit.setting_number then
            return _spec_kit.setting_number(ctx, key, def)
        end
        if ctx and ctx.settings and type(ctx.settings[key]) == "number" then return ctx.settings[key] end
        return def
    end

    -- NS helper surface: permissive stubs so every spec's match/execute can run.
    ns.action_matches = function() return true end
    ns.action_execute = function() return true end
    -- Phase 2.2a (2026-08-13): bank-aware aoe_target_meets with a TRUE default
    -- (mirrors the is_behind_target pattern) so the elem_cl_st scenario can
    -- present a single-target fight (aoe gate fails) without changing any
    -- other scenario — absent the bank key every caller keeps the legacy true.
    ns.aoe_target_meets = function() return ns._bstate("aoe_target_meets", true) ~= false end
    ns.aoe_cone_meets = function() return true end
    ns.aoe_count_meets = function() return true end
    ns.aoe_self_meets = function() return true end
    ns.cancel_buff = function() return true end
    ns.cancel_current_cast = function() return true end
    ns.cancel_spells = function() return true end
    ns.can_cast_in_form = function() return true end
    ns.start_attack = function() return true end
    ns.start_auto_attack = function() return true end
    ns.stop_casting = function() return true end
    -- (b) close-out (2026-08-10): enh AutoAttack gates on NOT auto-attacking
    -- (enhancement:1207); the legacy always-true stub hard-blocked the lane.
    -- Bank-driven with default true so every other scenario is unchanged; the
    -- enh_autoattack scenario flips it to false. Battery artifact only — the
    -- live client's is_auto_attacking is false at combat start, so the lane
    -- fires in-game; no spec-file change.
    ns.is_auto_attacking = function() return ns._bstate("is_auto_attacking", true) == true end
    ns.is_current_spell = function() return false end
    ns.is_execute_phase = function(hp, threshold) return type(hp) == "number" and hp <= (threshold or 20) end
    ns.is_valid_target = function() return true end
    ns.is_melee_target = function() return true end
    ns.is_tank_unit = function() return true end
    ns.is_pvp_zone = function() return false end
    -- Era flag: DK specs + presence_manager call NS.is_wotlk() as a FUNCTION.
    -- The legacy TBC battery set a boolean false; era="wotlk" must provide the
    -- callable form or presence_manager's `if not (NS.is_wotlk and NS.is_wotlk())`
    -- short-circuits on the boolean and every DK spec bails at load.
    ns.is_wotlk = (era == "wotlk") and function() return true end or false
    -- Vanilla era flag, callable like is_wotlk (vanilla file headers reference
    -- NS.is_vanilla() as the loader contract; keep it a function for parity).
    ns.is_vanilla = (era == "vanilla") and function() return true end or false
    -- SoD era flag (W4.3, 2026-08-14): every _sod.lua file guards its load with
    -- `type(NS.is_sod) == "function" and not NS.is_sod()` (dps_warrior_sod:3),
    -- so era="sod" must provide the callable form exactly like is_wotlk; the
    -- boolean false keeps every other era's load guard short-circuiting.
    ns.is_sod = (era == "sod") and function() return true end or false
    ns.should_kite = function() return false end
    ns.has_player_buff = function() return false end
    ns.has_player_debuff = function() return false end
    ns.has_buff = function() return false end
    ns.has_debuff = function() return false end
    ns.buff_stacks = function() return 0 end
    ns.debuff_stacks = function() return 0 end
    ns.get_aoe_cast_position = function() return nil end
    ns.cast_ground_aoe = function() return true end
    ns.try_cast_position = function() return true end
    -- try_interrupt stays a constant-true permissive stub (legacy posture):
    -- making it bank-aware on target_is_casting was trialed during the vanilla
    -- sweep but rippled across TBC interrupt/cyclone lanes (bear, cat, priest,
    -- shadow, subtlety, enhancement) — the subtlety Ambush lane it would fix is
    -- pinned as expected-absence instead (see the vanilla pin comment).
    ns.try_interrupt = function() return true end
    ns.is_interruptible = ns.is_interruptible
    ns.unit_alive = function() return true end
    ns.unit_health_pct = function() return 100 end
    ns.unit_mana_pct = function() return 100 end
    ns.unit_max_mana = function() return 10000 end
    ns.unit_distance = function() return 5 end
    ns.unit_faction = function() return 0 end
    ns.unit_is_boss = function() return false end
    ns.unit_interruptible = function() return true end
    ns.unit_creature_type = function() return ns._bstate("target_creature_type", 7) end
    ns.threat_status = function() return 0 end
    ns.is_threat_safe = function() return true end
    ns.get_pet = function() return nil end
    ns.GetPet = function() return nil end
    ns.get_pet_hp = function() return 100 end
    ns.has_pet = function() return false end
    ns.mana = ns.mana
    -- Bank-aware get_spell_cd (ranked #8): subtlety's Preparation matcher
    -- requires a major CD burned (vanish_cd/sprint_cd/evasion_cd derived from
    -- NS.get_spell_cd in build_state); this stub was hardwired 0 so the CD
    -- was never "burned" and Preparation could never fire. Now reads on_cd
    -- like cooldown_remains (same table; DIFFERENT scan semantics — this one
    -- checks ALL rank ids so scenarios may key by any rank, e.g. 1856 =
    -- Vanish low rank, ids[1] the TBC top rank 26889, while cooldown_remains
    -- stays ids[1]-only for its top-rank-keyed scenarios). Only
    -- subtlety_sylvanas/subtlety_vanilla consume get_spell_cd, so no other
    -- spec is affected.
    ns.get_spell_cd = function(spell)
        local on_cd = ns._bstate("on_cd", nil)
        if type(on_cd) == "table" and spell then
            local ids
            if type(spell) == "number" then
                ids = { spell }
            elseif type(spell) == "table" then
                ids = spell.ids
            end
            for _, id in ipairs(ids or {}) do
                if on_cd[id] then return on_cd[id] end
            end
        end
        return 0
    end
    ns.get_spell_cooldown = function() return 0 end
    ns.get_spell_id = function() return 0 end
    ns.is_spell_in_range = function() return true end
    ns.get_time_until_swing = function() return ns._bstate("swing_until", 0.5) end
    ns.get_time_until_oh_swing = function() return ns._bstate("swing_until", 0.5) end
    ns.swing_progress = function() return 0.5 end
    ns.swing_time_until = function() return ns._bstate("swing_until", 0.5) end
    ns.get_totem_info = function(slot)
        -- Bank-aware (Wave 3.3, 2026-08-13): the totem_active scenario presents
        -- a live totem ({have_totem=true}) so WotLK slot-gated lanes (enh Fire
        -- Nova, elem Searing Totem holds) are exercised through the REAL
        -- NS.get_totem_info path. Default false preserves the legacy posture
        -- for every pre-existing consumer; spell_id 0 keeps TBC enh
        -- _air_totem_active (WF/GoA id match) byte-identical.
        if ns._bstate("totem_active") then
            return { have_totem = true, totem_name = "AuditTotem", start_time = 0, duration = 60, spell_id = 0 }
        end
        return false
    end
    ns.register_on_spell_cast = function() return true end
    ns.register_class_middleware = function() end
    -- Scenario-aware (2026-08-08): the healer FriendlyTarget lanes (disc +
    -- holy priest, holy paladin, resto druid + shaman) gate on
    -- state.friendly_target_ready / state.friendly_target, populated from
    -- NS.get_friendly_target_entry (core/units.lua:129 — { unit, hp_pct,
    -- effective_hp, is_player } of the current target when it is friendly).
    -- The friendly_target scenario presents a friendly unit below the 90%
    -- threshold; absent the flag every spec keeps the nil-entry behavior
    -- (hostile/default targets never produce an entry). Keyed on
    -- friendly_target_hp ALONE (a number is non-nil only when the scenario
    -- sets it) — deliberately NOT a friendly_target boolean, which would
    -- collide with healing_sylvanas.lua:454 reading context.friendly_target
    -- as a UNIT.
    ns.get_friendly_target_entry = function()
        local hp = ns._bstate("friendly_target_hp", nil)
        if not hp then return nil end
        local unit = _friend(hp, 30)
        return { unit = unit, hp_pct = hp, effective_hp = hp, is_player = true }
    end
    -- (c) close-out (2026-08-09): balance RebirthBattleRez (balance:381-386)
    -- reads `_find_dead()` and needs a dead PLAYER ally for the is_player gate
    -- (dead:is_player()). The dead_ally scenario presents _friend(0, 5) — hp 0
    -- makes is_dead true, is_player stays true; absent the flag we keep the
    -- legacy nil so every other find_dead consumer is unchanged.
    ns.find_dead_party_ally = function()
        if ns._bstate("dead_ally", false) then return _friend(0, 5) end
        return nil
    end
    ns.reset_api_health = function() end
    ns.get_local_player = ns.GetPlayer
    ns.dump_class_spells = function() end
    ns.pvp_trinket_used_recently = function() return false end
    ns.gate_overheal = function() return false end
    ns.gate_cooldown_boss_only = function() return true end
    ns.should_use_long_cd = function() return true end
    ns.should_refresh_dot = function() return not ns._bstate("buffs_up", false) end
    ns.has_dispel_type_debuff = function() return ns._bstate("friends_afflicted", false) end
    ns.is_breakable_cc_active = function() return false end
    ns.has_healing_reduction_debuff = function() return false end
    ns.get_best_heal_target = function() return nil end
    ns.healing_count_below_hp = function(entries, count, threshold)
        threshold = threshold or 100
        if not entries then return 0 end
        local n = 0
        for i = 1, (count or #entries) do
            if entries[i] and (entries[i].effective_hp or 100) < threshold then n = n + 1 end
        end
        return n
    end
    ns.healing_get_lowest_hp = function(entries, count, threshold)
        if not entries or not count or count <= 0 then return nil end
        threshold = threshold or 100
        local best, best_hp = nil, 999
        for i = 1, count do
            local e = entries[i]
            if e and e.effective_hp then
                local hp = e.effective_hp
                if hp <= threshold and hp < best_hp then best, best_hp = e, hp end
            end
        end
        return best
    end
    ns.healing_get_tank = function(entries, count)
        if not entries or not count or count <= 0 then return nil end
        for i = 1, count do
            local e = entries[i]
            if e and e.is_tank then return e end
        end
        return entries[1]
    end
    ns.get_local_player = ns.GetPlayer
    ns.get_energy = ns.energy
    -- Real safe_field(obj, key) semantics (shared/safe_helpers_sylvanas.lua:
    -- 45): returns obj[key] or nil. Every consumer passes (obj, key) — druid
    -- unit_class_id(unit, "get_class"), offensive_dispel, ooc_manager, mage/
    -- warrior middleware. The old (value, default) shape returned the whole
    -- object, making unit_class_id pcall a table (always error -> nil).
    ns.safe_field = function(obj, key)
        if obj == nil then return nil end
        local ok, value = pcall(function() return obj[key] end)
        if not ok then return nil end
        return value
    end
    ns.same_unit = ns.same_unit
    ns.not_same_unit = ns.not_same_unit
    ns.setting_bool = function(ctx, key, def) return _setting_bool(ctx, key, def) end
    ns.setting_number = function(ctx, key, def) return _setting_number(ctx, key, def) end
    ns.register_strategy = function() end
    ns.run_unified_strategies = function() return false end

    -- Subsystem namespaces specs access (populated by class registration in
    -- the live engine; permissive stubs keep the audit loadable).
    ns.ConsumableManager = { should_use = function() return false end, try_use = function() return false end }
    ns.DispelManager = { try_dispel = function() return ns._bstate("friends_afflicted", false) end, should_dispel = function() return ns._bstate("friends_afflicted", false) end }
    ns.Triage = { score = function() return 0 end, rank = function() return {} end }
    ns.HealerDeficit = { deficit_of = function() return 0 end }
    -- (c) close-out (2026-08-09): BM Trinket (beast_mastery:378-385) reads
    -- NS.TrinketManager.get_equipped_trinkets for trinket_1_id; the battery
    -- stub only had try_use, so trinket_1_id stayed nil and the lane could
    -- never fire even with trinket_mode = slot1. The has_trinket scenario
    -- presents one equipped item (id 1); is_item_ready below returns true.
    ns.TrinketManager = {
        try_use = function() return false end,
        get_equipped_trinkets = function()
            if ns._bstate("has_trinket", false) then return { { item_id = 1 } } end
            return nil
        end,
    }
    ns.RageManager = { should_dump = function() return true end }
    -- Mirrors shared/stance_manager_sylvanas.lua semantics: get_optimal_stance
    -- returns a stance NAME (string) or nil; should_switch returns false when
    -- already in the desired stance. Unblocks protection StanceSwitch
    -- (prot build_state reads SM.get_optimal_stance into desired_stance).
    ns.StanceManager = {
        ensure_stance = function() return true end,
        get_optimal_stance = function(context, state)
            local stance = (state and state.stance) or (context and context.stance) or 2
            if stance ~= 2 then return "defensive" end
            return nil
        end,
        should_switch = function(context, state, desired)
            if not desired then return false end
            local stance = (state and state.stance) or (context and context.stance) or 1
            local desired_id = desired == "defensive" and 2
                or (desired == "berserker" and 3)
                or (desired == "battle" and 1)
                or nil
            if not desired_id then return false end
            if stance == desired_id then return false end
            return true
        end,
    }
    ns.SnapThreat = { try = function() return false end }
    ns.PvPBurstWindow = { should_burst = function() return false end }
    ns.StopCast = { stop_if_needed = function() return false end }
    ns.HotTickTracker = { on_tick = function() end }
    ns.InterruptManager = {
        try_interrupt = function() return true end,
        cast_has_interrupt_window = function() return true end,
        humanize_interrupt_elapsed = function() return true end,
    }
    ns.DRTracker = { is_dr = function() return false end }
    ns.Targeting = { pick = function() return nil end }
    ns.WeaponImbueManager = { apply = function() return false end }
    ns.OffensiveDispelDB = {
        -- Priority tiers mirror shared/offensive_dispel_sylvanas.lua so specs
        -- that gate on OffensiveDispelDB.PRIORITY_HIGH work in the battery.
        PRIORITY_CRITICAL = 4,
        PRIORITY_HIGH = 3,
        PRIORITY_MEDIUM = 2,
        PRIORITY_LOW = 1,
        should_purge = function() return ns._bstate("enemy_buffed", false) end,
        -- Real module returns (best_id, priority, best_name); rogue ShivPurge
        -- reads all three, so the stub must return a name too or shiv_purge_name
        -- stays nil and the whole purge lane is invisible.
        find_best_dispel_target = function(target)
            if ns._bstate("enemy_buffed", false) then return target, 10, "Bloodlust" end
            return nil, 0, nil
        end,
        -- (b) close-out (2026-08-10): shadow binds CCBreakDB = NS.OffensiveDispelDB
        -- (shadow:55), so this stub IS the SW:D CC-break reader. Delegate to
        -- ns.debuff_up over the damage-breakable CC ids (Polymorph/Sap/Gouge/
        -- Blind/Repentance/Fear family) — debuff_up consults the player-debuff
        -- map for the player unit, so the shadow_cc_break scenario's
        -- player_debuff_remains_map { [118] = 5 } drives has_breakable_cc.
        is_breakable_cc_active = function(unit, ns2)
            local ids = { 118, 12824, 12825, 12826, 28271, 28272, 6770, 2070, 11297, 2094, 1776, 1079, 5782, 6215 }
            for _, id in ipairs(ids) do
                if ns.debuff_up(unit or ns.me, id) then return true, "CC" end
            end
            return false, nil
        end,
        is_casting_preemptive_cc = function() return false, nil end,
        -- Wave 1.4 (2026-08-13): warrior leveling_vanilla's PvPCCGate strategy
        -- reads CCGateDB.is_any_nearby_enemy_under_cc (the real
        -- shared/offensive_dispel_sylvanas:311 surface — a live game-state
        -- scan the battery cannot reproduce). Bank-driven on the
        -- enemy_cc_nearby key; default false keeps every other scenario
        -- identical (no other consumer reads this method).
        is_any_nearby_enemy_under_cc = function()
            return ns._bstate("enemy_cc_nearby", false) == true
        end,
    }
    -- Note: NS.purge_should_cast / NS.PurgeManager stubs were considered but
    -- removed — enhancement_sylvanas.lua now mirrors the middleware gate
    -- (OffensiveDispelDB + purge_manager) and no spec reads those helpers.
    ns.SwingDiagnostics = {
        on_update = function() end,
        register_seals = function() end,
        is_active = function() return false end,
        get_swing_remains = function() return nil end,
        mark_twist_attempt = function() end,
        is_overpower_proc_active = function() return false end,
    }
    ns.HunterCore = { on_update = function() end }
    ns.HunterAdaptive = { on_update = function() end }
    ns.HunterClipTracker = { on_update = function() end }
    -- Scenario-driven heal-scan stubs (healer triage upgrade): the per-class
    -- Healing modules expose the triage surface the specs' build_state reads.
    -- Entries mirror the scenario's friends_hp (default { 55, 70, 85 }) plus a
    -- player entry. CONTRACT: entry[2] is ALWAYS the tank (is_tank/role="tank")
    -- so tank ~= lowest (PreHeal/Emergency PWS lanes) — scenario authors must
    -- keep the tank at friends_hp index 2 or add a tank_low-style override;
    -- the player entry (is_self, hp from ctx.hp) enables PurifySelf/self-cure.
    -- Per-debuff-type affliction flags come from the scenario `afflicted` table
    -- (poison/disease/curse/magic) — this unblocks the dispel/cleanse/cure lanes.
    local function _heal_entries()
        -- Default to an INJURED group (55/70/85) so the heal lanes that gate on
        -- state.lowest/tank fire in the base scenarios (mirrors the prior scan
        -- behavior). The `group_healthy` scenario (friends_hp 100s) presents a
        -- fully-healthy group so the Idle*/Solo* DPS lanes stay observable.
        local hps = ns._bstate("friends_hp", nil)
        if not hps or type(hps) ~= "table" or #hps == 0 then hps = { 55, 70, 85 } end
        local aff = ns._bstate("afflicted", nil) or {}
        local a = { poison = aff.poison == true, disease = aff.disease == true,
                    curse = aff.curse == true, magic = aff.magic == true }
        local friend_class = ns._bstate("friend_class", nil)
        -- (b) close-out (2026-08-10): snared_friend marks the lowest ally
        -- entry is_snared → holy entry_needs_freedom (holy:319-324) picks it as
        -- freedom_target → BlessingOfFreedomSnare observable. Only freedom
        -- lanes read is_snared, so other heal-scan consumers are unaffected.
        local entries, count = {}, 0
        for i, hp in ipairs(hps) do
            count = count + 1
            -- Low-HP targets carry a short TTD so TTD-gated urgency lanes
            -- (druid NaturesSwiftness) are observable; healthy ones do not.
            local ttd = (hp <= 30) and 3 or 999
            entries[count] = {
                unit = _friend(hp, 30, friend_class), hp = hp, effective_hp = hp, max_hp = 10000,
                time_to_die = ttd, future_hp = hp, death_risk = 0, will_die_soon = false,
                is_snared = (ns._bstate("snared_friend", false) == true and i == 1) or nil,
                -- Threat-family close-out (2026-08-10): friendly_target_threat
                -- marks the lowest ally entry threatened (holy:332
                -- entry_needs_protection ORs threat_status >= 2). Only holy
                -- BoPFocusedAlly reads it; default nil is a no-op for every
                -- other heal-scan consumer.
                threat_status = (i == 1) and ns._bstate("friendly_target_threat", nil) or nil,
                -- Deficit must mirror the real scan semantics (heal modules set
                -- deficit = max_hp - current_hp): a low-HP entry needs a
                -- positive deficit or every deficit_of(...) > 0 gate (paladin
                -- LightGraceBuild/LightGraceChain) is battery-dead. Percentage
                -- scale (100 - effective_hp) is consistent with effective_hp.
                -- NOTE: percentage scale is fine for `> 0` gates only; do not
                -- compare against raw-HP constants (LARGE/MEDIUM/LIGHT_HEAL_
                -- DEFICIT are raw-scale in live play).
                deficit = math.max(0, 100 - hp), effective_deficit = math.max(0, 100 - hp),
                is_tank = (i == 2), role = (i == 2) and "tank" or "dps",
                is_player = false, is_self = false,
                is_valid = true, is_friendly = true, hostile = false,
                has_weakened_soul = false, has_renew = false, renew_remains = 0,
                has_poison = a.poison, has_disease = a.disease, has_curse = a.curse,
                has_magic = a.magic, needs_cleanse = a.poison or a.disease or a.curse or a.magic,
            }
        end
        count = count + 1
        local ph = ns._bstate("hp", 100)
        entries[count] = {
            unit = ns.PLAYER_UNIT, hp = ph, effective_hp = ph, max_hp = 10000,
            time_to_die = 999, future_hp = ph, death_risk = 0, will_die_soon = false,
            deficit = math.max(0, 100 - ph), effective_deficit = math.max(0, 100 - ph),
            is_tank = false, role = "dps",
            is_player = true, is_self = true,
            is_valid = true, is_friendly = true, hostile = false,
            has_weakened_soul = false, has_renew = false, renew_remains = 0,
            has_poison = a.poison, has_disease = a.disease, has_curse = a.curse,
            has_magic = a.magic, needs_cleanse = a.poison or a.disease or a.curse or a.magic,
        }
        -- Lifebloom let-bloom state (healer (c) close-out): the resto druid
        -- LifebloomLetBloom lane needs an entry with Lifebloom stacks near
        -- expiry (should_let_lifebloom_bloom gates on lifebloom_stacks > 0 +
        -- lifebloom_remains <= LIFEBLOOM_BLOOM_SOON). The scenario override
        -- `lifebloom = { index = N, stacks = S, remains = R }` attaches the
        -- fields so the lane becomes observable.
        local lb = ns._bstate("lifebloom", nil)
        if type(lb) == "table" and type(lb.index) == "number" and entries[lb.index] then
            entries[lb.index].lifebloom_stacks = lb.stacks or 0
            entries[lb.index].lifebloom_remains = lb.remains or 0
        end
        return entries, count
    end
    local function _afflicted_flag(key)
        local aff = ns._bstate("afflicted", nil)
        return type(aff) == "table" and aff[key] == true
    end
    local function _heal_module()
        return {
            should_cast = function() return true end,
            scan_healing_targets = _heal_entries,
            count_below_hp = function(threshold)
                local entries, count = _heal_entries()
                return ns.healing_count_below_hp(entries, count, threshold)
            end,
            count_subgroup_below_hp = function(threshold)
                local entries, count = _heal_entries()
                return ns.healing_count_below_hp(entries, count, threshold)
            end,
            healing_count_below_hp = function(threshold)
                local entries, count = _heal_entries()
                return ns.healing_count_below_hp(entries, count, threshold)
            end,
            get_lowest_hp_target = function(threshold)
                local entries, count = _heal_entries()
                return ns.healing_get_lowest_hp(entries, count, threshold)
            end,
            get_tank_target = function()
                local entries, count = _heal_entries()
                return ns.healing_get_tank(entries, count)
            end,
            get_cleanse_target = function()
                local entries, count = _heal_entries()
                for i = 1, count do
                    if entries[i].needs_cleanse then return entries[i] end
                end
                return nil
            end,
            all_members_above_hp = function(threshold)
                local entries, count = _heal_entries()
                for i = 1, count do
                    if (entries[i].effective_hp or 100) < threshold then return false end
                end
                return true
            end,
            has_disease = function() return _afflicted_flag("disease") end,
            has_poison = function() return _afflicted_flag("poison") end,
            has_curse = function() return _afflicted_flag("curse") end,
            has_magic = function() return _afflicted_flag("magic") end,
            has_dangerous_dispel = function() return _afflicted_flag("magic") end,
            has_weakened_soul = function() return false end,
            has_renew = function() return false end,
            renew_remains = function() return 0 end,
            has_pws = function() return false end,
            pws_absorb_remaining = function() return 0 end,
            predict_effective_deficit = function() return 0 end,
            group_mana_avg = function() return ns._bstate("mana_pct", 100) end,
            is_in_raid = function() return false end,
            is_in_party = function() return true end,
            select_heal = function(context, state, lowest)
                local entry = lowest or { unit = ns.PLAYER_UNIT, effective_hp = 60 }
                return {
                    spell = ns.spell_action({ 1064, 1062, 25423, 25422, 25421, 25420, 1061, 1060, 421, 930, 913, 943, 604 }, "ChainHeal"),
                    name = "ChainHeal",
                    unit = entry.unit,
                    effective_hp = entry.effective_hp or 60,
                }
            end,
        }
    end
    ns.PaladinHealing = _heal_module()
    ns.PriestHealing = _heal_module()
    ns.ShamanHealing = _heal_module()
    ns.DruidHealing = _heal_module()
    ns.class_middleware = {}
    ns.unified_registry = {}
    ns.unified_state_builders = {}
    ns.playstyles = { leveling = {} }

    -- Vanilla-era support (2026-08-11): plain-style vanilla files register via
    -- NS.rotation_registry:register(name, strategies, { get_state = build_state })
    -- and return their bare strategies table (fury_vanilla is the canonical
    -- example). The real engine resolves get_state from this registry, so the
    -- mock captures the registration per load (build_ns runs once per
    -- load_spec) and run_spec falls back to it when result.build_state is
    -- absent — without this, every vanilla state-field read in a matcher
    -- (s.target_casting etc.) silently sees nil and the lanes report never.
    ns.rotation_registry = {
        register = function(self, name, strategies, options)
            ns._registry = { name = name, strategies = strategies, options = options or {} }
        end,
    }
    ns.same_unit = function(a, b) return a == b end
    ns.not_same_unit = function(a, b) return a ~= b end
    ns.spell_action = function(rank_ids, label)
        local ids
        if type(rank_ids) == "table" then ids = rank_ids else ids = { rank_ids } end
        local obj = {
            -- W4.3 (2026-08-14): emit the LIVE `_meta` surface (mirrors
            -- core_sylvanas.lua NS.spell_action — rich objects carry
            -- _meta.id/_meta.ids/_meta.label). Previously the mock exposed
            -- only flat `.ids`, a mock-only shape: spec_kit's
            -- define_sod_action_for_class unwrap (W4.2) resolves source ids
            -- via _meta.ids, so every class-table-backed SoD action (shaman
            -- FlameShock/LightningBolt/ChainLightning, druid, warrior...)
            -- resolved nil in the battery and its lanes reported never-firing
            -- while firing fine in production. Additive: every flat-.ids
            -- reader (normalize_ids, cooldown_remains, rank_ids) still works.
            _meta = { id = ids, ids = ids, label = label },
            label = label,
            ids = ids,
            id = function(self) return ids[1] or ids[#ids] end,
            rank = function(self, r) return ids[r or #ids] end,
            cooldown = function(self) return 0 end,
            is_known = function(self) return true end,
            -- W3.4 mock-tightening (2026-08-13): the W3.1-audited
            -- `action:cooldown_remaining()` injection is REMOVED — it masked
            -- production never-lanes (callers fell through to 99 live, then
            -- 0 in the battery, so cd-gated lanes fired only under the mock).
            -- All W3.3 fixers migrated to NS.cooldown_remains / NS.spell_ready
            -- (0 when unknown, on_cd-map aware); the repo-wide grep audit
            -- found ZERO live production reads of this member. This tripwire
            -- FAILS LOUDLY if any (re)introduced production or test code
            -- calls the member on a battery spell_action.
            cooldown_remaining = function(self)
                error("mock-only member action:cooldown_remaining() removed in W3.4 "
                    .. "(behavioral_audit.lua) — production must use NS.cooldown_remains/NS.spell_ready "
                    .. "(label: " .. tostring(label) .. ")", 2)
            end,
        }
        obj.rank_ids = function() return ids end
        return obj
    end

    -- Warrior spell resolution (mirrors classes/warrior/class_sylvanas.lua
    -- SPELLS rank tables). The primary-on-cooldown filler lanes
    -- (Devastate/Rend/HeroicStrike) gate on
    -- `ss_ready == false and revenge_ready == false`, which the battery can
    -- only exercise when ShieldSlam/Revenge resolve to real ids and appear in
    -- a scenario's on_cd table (30356 = ShieldSlam top rank, 30357 = Revenge
    -- top rank — the low-rank 23922/6572 are never read since cooldown_remains
    -- uses ids[1]). Built via ns.spell_action so ACTION entries carry the same
    -- method surface (id/rank/cooldown/is_known) as live SPELLS entries.
    ns.WarriorSpells = {
        ShieldSlam = ns.spell_action({ 30356, 25258, 23925, 23924, 23923, 23922 }, "ShieldSlam"),
        Revenge = ns.spell_action({ 30357, 25269, 25288, 11601, 11600, 7379, 6574, 6572 }, "Revenge"),
        -- Taunt (ranked #6): the elite_taunt_cd scenario puts Taunt on CD via
        -- on_cd = { [355] = 6 }; without a real spell_action entry the spec's
        -- ACTION.Taunt has no ids and cooldown_remains can't resolve 355, so
        -- taunt_ready stays true and TauntSecondary's "Taunt on CD" gate never
        -- passes. Mirrors class_sylvanas.lua (ids = { 355 }).
        Taunt = ns.spell_action({ 355 }, "Taunt"),
        -- Devastate (close-out ranked #1): WITHOUT this entry the spec's
        -- define("Devastate") falls back to spell_action(nil) -> ids { nil }
        -- -> cooldown_remains can never resolve an on_cd key -> dev_ready
        -- stays true in every scenario -> SunderArmor's pre-Devastate
        -- fallback (prot:531 `if state.dev_ready then return false end`) can
        -- never fire. The `not_learned` map does NOT help here: it only gates
        -- spell_exists/is_spell_learned, while dev_ready comes from the
        -- cooldown-only spell_ready mock. Seeding the ids makes the
        -- sunder_fallback scenario's on_cd { [30022] = 6 } resolvable.
        -- Mirrors class_sylvanas.lua (ids = { 30022, 30016, 20243 }).
        Devastate = ns.spell_action({ 30022, 30016, 20243 }, "Devastate"),
        -- Wave 1.4 leveling_vanilla seeds (2026-08-13) — see the DruidSpells
        -- comment for the rationale and ladder convention. NOTE: Whirlwind
        -- (1680) and MortalStrike (30330) ids[1] collide with existing TBC
        -- scenario on_cd keys — that is intended (the on_cd scenarios model
        -- those abilities mid-cooldown for the TBC fillers), and the seeds
        -- only make the cooldown resolution REAL instead of nil-fallback.
        BattleShout = ns.spell_action({ 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
        BattleStance = ns.spell_action({ 2457 }, "BattleStance"),
        BerserkerRage = ns.spell_action({ 18499 }, "BerserkerRage"),
        BerserkerStance = ns.spell_action({ 2458 }, "BerserkerStance"),
        Bloodrage = ns.spell_action({ 2687 }, "Bloodrage"),
        Bloodthirst = ns.spell_action({ 30335, 25251, 23894, 23893, 23892, 23881 }, "Bloodthirst"),
        Charge = ns.spell_action({ 11578, 6178, 100 }, "Charge"),
        DefensiveStance = ns.spell_action({ 71 }, "DefensiveStance"),
        DemoralizingShout = ns.spell_action({ 25203, 25202, 11556, 11555, 11554, 6190, 1160 }, "DemoralizingShout"),
        Disarm = ns.spell_action({ 676 }, "Disarm"),
        Execute = ns.spell_action({ 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
        Hamstring = ns.spell_action({ 25212, 7373, 7372, 1715 }, "Hamstring"),
        HeroicStrike = ns.spell_action({ 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
        IntimidatingShout = ns.spell_action({ 5246 }, "IntimidatingShout"),
        MortalStrike = ns.spell_action({ 30330, 25248, 21553, 21552, 21551, 12294 }, "MortalStrike"),
        Overpower = ns.spell_action({ 11585, 11584, 7887, 7384 }, "Overpower"),
        Pummel = ns.spell_action({ 6554, 6552 }, "Pummel"),
        Rend = ns.spell_action({ 25208, 11574, 11573, 6548, 6547, 772 }, "Rend"),
        ShieldBash = ns.spell_action({ 29704, 1672, 1671, 72 }, "ShieldBash"),
        ShieldWall = ns.spell_action({ 871 }, "ShieldWall"),
        SweepingStrikes = ns.spell_action({ 12328 }, "SweepingStrikes"),
        ThunderClap = ns.spell_action({ 25264, 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
        Whirlwind = ns.spell_action({ 1680 }, "Whirlwind"),
    }
    -- Druid spell resolution for the balance multi-DoT spread lanes: the
    -- spread matchers explicitly gate on `SPELLS.Moonfire`/`SPELLS.InsectSwarm`
    -- existing (the main DoT lanes use the lenient NS.action_matches path and
    -- fire regardless, but the spreads return false on nil). Rank ids mirror
    -- classes/druid/class_sylvanas.lua (27013/26988 top ranks — the same ids
    -- the multidot scenario's debuff_remains_map uses).
    -- Druid cat-form spells (2026-08-11): the vanilla 19-lane cat block was
    -- root-caused to THIS table — cat_vanilla is plain-style and reads
    -- SPELLS.CatForm/Shred/Rake/... directly (no define_action_for_class
    -- fallback), so every spell-gated lane died on nil. Same precedent as the
    -- Hurricane fix above; rank ladders mirror classes/druid/class_sylvanas.lua
    -- (TBC max-rank first). Shared with the TBC battery: TBC cat resolves the
    -- SAME ids through define_action_for_class, so its behavior is unchanged.
    ns.DruidSpells = {
        Moonfire = ns.spell_action({ 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, "Moonfire"),
        InsectSwarm = ns.spell_action({ 27013, 24977, 24976, 24975, 24974, 5570 }, "InsectSwarm"),
        -- (c) close-out (2026-08-09): balance HurricaneAoE (balance:421) does
        -- `if not SPELLS.Hurricane then return false end` — the battery
        -- DruidSpells had no Hurricane, so the lane was structurally dead even
        -- with aoe+mana+barkskin in place. 27011 is the TBC max rank (matches
        -- the class_sylvanas ladder).
        Hurricane = ns.spell_action({ 27011, 27012, 27013 }, "Hurricane"),
        CatForm = ns.spell_action({ 768 }, "CatForm"),
        TravelForm = ns.spell_action({ 783 }, "TravelForm"),
        Prowl = ns.spell_action({ 9913, 6783, 5215 }, "Prowl"),
        Barkskin = ns.spell_action({ 22812 }, "Barkskin"),
        Ravage = ns.spell_action({ 27005, 9867, 9866, 6787, 6785 }, "Ravage"),
        Shred = ns.spell_action({ 27002, 27001, 9830, 9829, 8992, 6800, 5221 }, "Shred"),
        Dash = ns.spell_action({ 33357, 9821, 1850 }, "Dash"),
        FaerieFireFeral = ns.spell_action({ 27011, 17392, 17391, 17390, 16857 }, "FaerieFireFeral"),
        Rip = ns.spell_action({ 27008, 9896, 9894, 9752, 9493, 9492, 1079 }, "Rip"),
        FerociousBite = ns.spell_action({ 24248, 31018, 22829, 22828, 22827, 22568 }, "FerociousBite"),
        TigersFury = ns.spell_action({ 9846, 9845, 6793, 5217 }, "TigersFury"),
        Rake = ns.spell_action({ 27003, 9904, 1824, 1823, 1822 }, "Rake"),
        Claw = ns.spell_action({ 27000, 9850, 9849, 5201, 3029, 1082 }, "Claw"),
        -- Wave 1.4 leveling_vanilla seeds (2026-08-13): the 9 leveling files
        -- read SPELLS.X directly with a `if not spell_action then return false
        -- end` guard on the local spell_ready helper, so unseeded names were
        -- structurally dead in the battery (every spell-gated leveling lane
        -- reported never). Ladders mirror classes/<class>/class_sylvanas.lua
        -- (TBC max-rank first) — same convention as the existing seeds. Only
        -- ids[1] is consulted by cooldown_remains/on_cd, so no existing
        -- scenario keys are affected.
        BearForm = ns.spell_action({ 9634, 5487 }, "BearForm"),
        EntanglingRoots = ns.spell_action({ 26989, 9853, 9852, 5196, 5195, 1062, 339 }, "EntanglingRoots"),
        FaerieFire = ns.spell_action({ 26993, 9907, 9749, 778, 770 }, "FaerieFire"),
        FrenziedRegeneration = ns.spell_action({ 26999, 22896, 22895, 22842 }, "FrenziedRegeneration"),
        HealingTouch = ns.spell_action({ 26979, 26978, 25297, 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185 }, "HealingTouch"),
        MarkOfTheWild = ns.spell_action({ 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, "MarkOfTheWild"),
        Maul = ns.spell_action({ 26996, 9881, 9880, 9745, 8972, 6809, 6808, 6807 }, "Maul"),
        NaturesGrasp = ns.spell_action({ 27009, 17329, 16813, 16812, 16811, 16810, 16689 }, "NaturesGrasp"),
        Pounce = ns.spell_action({ 27006, 9827, 9823, 9005 }, "Pounce"),
        Rejuvenation = ns.spell_action({ 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }, "Rejuvenation"),
        Starfire = ns.spell_action({ 26986, 25298, 9876, 9875, 8951, 8950, 8949, 2912 }, "Starfire"),
        SwipeBear = ns.spell_action({ 26997, 9908, 9754, 769, 780, 779 }, "SwipeBear"),
        Thorns = ns.spell_action({ 26992, 9910, 9756, 8914, 1075, 782, 467 }, "Thorns"),
        Wrath = ns.spell_action({ 26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176 }, "Wrath"),
    }
    -- Vanilla battery sweep (2026-08): plain-style vanilla spec files read
    -- SPELLS.X directly (no define_action_for_class fallback), so an empty
    -- class table silently suppressed spell-gated lanes (the cat-block
    -- precedent: resto totems/cures via _totem_ready's `spell and ...`
    -- short-circuit, frost ArcaneExplosion's nil-failing guard, ColdSnap's
    -- `not spell_ready(IceBlock)` inversion, arcane low_level's sentinel
    -- spell_exists inversion, hunter ArcaneShot's `aimed_shot_ready`
    -- inversion, holy AuraManagement's nil aura_spell). Ladders mirror
    -- classes/<class>/class_sylvanas.lua (max rank first). Shared with the
    -- TBC battery, which resolves the SAME ids through define_action_for_class
    -- — TBC behavior is byte-identical.
    ns.ShamanSpells = {
        StrengthOfEarthTotem = ns.spell_action({ 25528, 25361, 10442, 8161, 8160, 8075 }, "StrengthOfEarthTotem"),
        ManaSpringTotem = ns.spell_action({ 25570, 10497, 10496, 10495, 5675 }, "ManaSpringTotem"),
        GraceOfAirTotem = ns.spell_action({ 25359, 10627, 8835 }, "GraceOfAirTotem"),
        WindfuryTotem = ns.spell_action({ 25587, 25585, 10614, 10613, 8512 }, "WindfuryTotem"),
        CurePoison = ns.spell_action({ 526 }, "CurePoison"),
        CureDisease = ns.spell_action({ 2870 }, "CureDisease"),
        PoisonCleansingTotem = ns.spell_action({ 8166 }, "PoisonCleansingTotem"),
        DiseaseCleansingTotem = ns.spell_action({ 8170 }, "DiseaseCleansingTotem"),
        -- Wave 1.4 leveling_vanilla seeds (2026-08-13) — see the DruidSpells
        -- comment for the rationale and ladder convention.
        ChainLightning = ns.spell_action({ 25442, 25439, 10605, 2860, 930, 421 }, "ChainLightning"),
        EarthShock = ns.spell_action({ 25454, 10414, 10413, 10412, 8046, 8045, 8044, 8042 }, "EarthShock"),
        EarthbindTotem = ns.spell_action({ 2484 }, "EarthbindTotem"),
        FlameShock = ns.spell_action({ 25457, 29228, 10448, 10447, 8053, 8052, 8050 }, "FlameShock"),
        FlametongueWeapon = ns.spell_action({ 25489, 16342, 16341, 16339, 8030, 8027, 8024 }, "FlametongueWeapon"),
        FrostShock = ns.spell_action({ 25464, 10473, 10472, 8058, 8056 }, "FrostShock"),
        FrostbrandWeapon = ns.spell_action({ 25500, 16356, 16355, 10456, 8038, 8033 }, "FrostbrandWeapon"),
        GhostWolf = ns.spell_action({ 2645 }, "GhostWolf"),
        GroundingTotem = ns.spell_action({ 8177 }, "GroundingTotem"),
        HealingStreamTotem = ns.spell_action({ 25567, 10463, 10462, 6377, 6375, 5394 }, "HealingStreamTotem"),
        HealingWave = ns.spell_action({ 25396, 25391, 25357, 10396, 10395, 8005, 959, 939, 913, 547, 332, 331 }, "HealingWave"),
        LesserHealingWave = ns.spell_action({ 25420, 10468, 10467, 10466, 8010, 8008, 8004 }, "LesserHealingWave"),
        LightningBolt = ns.spell_action({ 25449, 25448, 15208, 15207, 10392, 10391, 6041, 943, 915, 548, 529, 403 }, "LightningBolt"),
        LightningShield = ns.spell_action({ 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, "LightningShield"),
        Purge = ns.spell_action({ 8012, 370 }, "Purge"),
        RockbiterWeapon = ns.spell_action({ 25485, 25479, 16316, 16315, 16314, 10399, 8019, 8018, 8017 }, "RockbiterWeapon"),
        SearingTotem = ns.spell_action({ 25533, 10438, 10437, 6365, 6364, 6363, 3599 }, "SearingTotem"),
        StoneclawTotem = ns.spell_action({ 25525, 10428, 10427, 6392, 6391, 6390, 5730 }, "StoneclawTotem"),
        Stormstrike = ns.spell_action({ 17364 }, "Stormstrike"),
        TremorTotem = ns.spell_action({ 8143 }, "TremorTotem"),
        WindfuryWeapon = ns.spell_action({ 25505, 16362, 10486, 8235, 8232 }, "WindfuryWeapon"),
    }
    ns.MageSpells = {
        ArcaneExplosion = ns.spell_action({ 27082, 27080, 10202, 10201, 8439, 8438, 8437, 1449 }, "ArcaneExplosion"),
        IceBlock = ns.spell_action({ 45438 }, "IceBlock"),
        -- UnavailableClassicMageArcane is nil in the class file; arcane_vanilla
        -- gates low_level_bolt on spell_exists(SPELLS.UnavailableClassicMageArcane).
        -- spell_exists(nil) is nil-lenient TRUE in the mock, inverting the
        -- sentinel's "unavailable in classic" semantics — give it a sentinel
        -- id (0) so the low_level scenario's not_learned {[0]=true} drives it.
        UnavailableClassicMageArcane = ns.spell_action({ 0 }, "UnavailableClassicMageArcane"),
        -- Wave 1.4 leveling_vanilla seeds (2026-08-13) — see the DruidSpells
        -- comment for the rationale and ladder convention.
        ArcaneIntellect = ns.spell_action({ 27126, 10157, 10156, 1461, 1460, 1459 }, "ArcaneIntellect"),
        ArcaneMissiles = ns.spell_action({ 38699, 25345, 10212, 10211, 8418, 8417, 8416, 5145, 5144, 5143 }, "ArcaneMissiles"),
        Blink = ns.spell_action({ 1953 }, "Blink"),
        Blizzard = ns.spell_action({ 27085, 10187, 10186, 10185, 8427, 6141, 10 }, "Blizzard"),
        ConeOfCold = ns.spell_action({ 27087, 10161, 10160, 10159, 8492, 120 }, "ConeOfCold"),
        Counterspell = ns.spell_action({ 2139 }, "Counterspell"),
        Evocation = ns.spell_action({ 12051 }, "Evocation"),
        FireBlast = ns.spell_action({ 27079, 27078, 10199, 10197, 8413, 8412, 2138, 2137, 2136 }, "FireBlast"),
        FireWard = ns.spell_action({ 27128, 10225, 10223, 8458, 8457, 543 }, "FireWard"),
        Fireball = ns.spell_action({ 27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133 }, "Fireball"),
        FrostArmor = ns.spell_action({ 27124, 10220, 10219, 7320, 7302, 7301, 7300, 168 }, "FrostArmor"),
        FrostNova = ns.spell_action({ 27088, 10230, 6131, 865, 122 }, "FrostNova"),
        Frostbolt = ns.spell_action({ 27072, 25304, 10181, 10180, 10179, 8408, 8407, 8406, 7322, 837, 205, 116 }, "Frostbolt"),
        IceBarrier = ns.spell_action({ 33405, 27134, 13033, 13032, 13031, 11426 }, "IceBarrier"),
        ManaShield = ns.spell_action({ 27131, 10193, 10192, 10191, 8495, 8494, 1463 }, "ManaShield"),
        Polymorph = ns.spell_action({ 12826, 12825, 12824, 118 }, "Polymorph"),
        RemoveCurse = ns.spell_action({ 475 }, "RemoveCurse"),
        Scorch = ns.spell_action({ 27074, 27073, 10207, 10206, 10205, 8446, 8445, 8444, 2948 }, "Scorch"),
    }
    ns.HunterSpells = {
        AimedShot = ns.spell_action({ 27065, 20904, 20903, 20902, 20901, 20900, 19434 }, "AimedShot"),
        ArcaneShot = ns.spell_action({ 27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 }, "ArcaneShot"),
        SerpentSting = ns.spell_action({ 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }, "SerpentSting"),
        -- Wave 1.4 leveling_vanilla seeds (2026-08-13) — see the DruidSpells
        -- comment for the rationale and ladder convention.
        AspectOfTheCheetah = ns.spell_action({ 5118 }, "AspectOfTheCheetah"),
        AspectOfTheHawk = ns.spell_action({ 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }, "AspectOfTheHawk"),
        CallPet = ns.spell_action({ 883 }, "CallPet"),
        ConcussiveShot = ns.spell_action({ 5116 }, "ConcussiveShot"),
        FeignDeath = ns.spell_action({ 5384 }, "FeignDeath"),
        FreezingTrap = ns.spell_action({ 14311, 14310, 1499 }, "FreezingTrap"),
        HuntersMark = ns.spell_action({ 14325, 14324, 14323, 1130 }, "HuntersMark"),
        MendPet = ns.spell_action({ 27046, 13544, 13543, 13542, 3662, 3661, 3111, 136 }, "MendPet"),
        MongooseBite = ns.spell_action({ 14271, 14270, 14269, 1495 }, "MongooseBite"),
        MultiShot = ns.spell_action({ 27021, 25294, 14290, 14289, 14288, 2643 }, "MultiShot"),
        RapidFire = ns.spell_action({ 3045 }, "RapidFire"),
        RaptorStrike = ns.spell_action({ 27014, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 2973 }, "RaptorStrike"),
        ScareBeast = ns.spell_action({ 14327, 14326, 1513 }, "ScareBeast"),
        WingClip = ns.spell_action({ 14268, 14267, 2974 }, "WingClip"),
    }
    ns.PaladinSpells = {
        DevotionAura = ns.spell_action({ 27149, 10293, 10292, 1032, 10291, 643, 10290, 465 }, "DevotionAura"),
        -- Wave 1.4 leveling_vanilla seeds (2026-08-13) — see the DruidSpells
        -- comment for the rationale and ladder convention. DivineShield was
        -- previously unseeded: TBC paladin middleware's get_divine_shield_spell
        -- (middleware_sylvanas:110) reads SPELLS.DivineShield and now resolves
        -- to a real action (verified era-safe: TBC holy/protection never counts
        -- are unchanged by the seed).
        BlessingOfMight = ns.spell_action({ 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }, "BlessingOfMight"),
        BlessingOfWisdom = ns.spell_action({ 27142, 25290, 19854, 19853, 19852, 19850, 19742 }, "BlessingOfWisdom"),
        Cleanse = ns.spell_action({ 4987 }, "Cleanse"),
        Consecration = ns.spell_action({ 27173, 20924, 20923, 20922, 20116, 26573 }, "Consecration"),
        DivineShield = ns.spell_action({ 1020, 642 }, "DivineShield"),
        Exorcism = ns.spell_action({ 27138, 10314, 10313, 10312, 5615, 5614, 879 }, "Exorcism"),
        FlashOfLight = ns.spell_action({ 27137, 19943, 19942, 19941, 19940, 19939, 19750 }, "FlashOfLight"),
        HammerOfJustice = ns.spell_action({ 10308, 5589, 5588, 853 }, "HammerOfJustice"),
        HammerOfWrath = ns.spell_action({ 27180, 24239, 24274, 24275 }, "HammerOfWrath"),
        HolyLight = ns.spell_action({ 27136, 27135, 25292, 10329, 10328, 3472, 1042, 1026, 647, 639, 635 }, "HolyLight"),
        HolyShield = ns.spell_action({ 27179, 20928, 20927, 20925 }, "HolyShield"),
        Judgement = ns.spell_action({ 20271 }, "Judgement"),
        LayOnHands = ns.spell_action({ 27154, 10310, 2800, 633 }, "LayOnHands"),
        RetributionAura = ns.spell_action({ 27150, 10301, 10300, 10299, 10298, 7294 }, "RetributionAura"),
        SealCommand = ns.spell_action({ 27170, 20920, 20919, 20918, 20915, 20375 }, "SealCommand"),
        SealRighteousness = ns.spell_action({ 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154 }, "SealRighteousness"),
    }
    ns.PriestSpells = {
        -- ids[1] resolves the holy_cure_on_cd on_cd entry (CureDisease on CD
        -- → holy AbolishDisease's `not cure_disease_ready` gate passes).
        CureDisease = ns.spell_action({ 528, 11554 }, "CureDisease"),
        -- Wave 1.4 leveling_vanilla seeds (2026-08-13) — see the DruidSpells
        -- comment for the rationale and ladder convention.
        DesperatePrayer = ns.spell_action({ 25437, 19243, 19242, 19241, 19240, 19238, 19236, 13908 }, "DesperatePrayer"),
        Fade = ns.spell_action({ 25429, 10942, 10941, 9592, 9579, 9578, 586 }, "Fade"),
        FlashHeal = ns.spell_action({ 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }, "FlashHeal"),
        GreaterHeal = ns.spell_action({ 25213, 25210, 25314, 10965, 10964, 10963, 2060 }, "GreaterHeal"),
        HolyFire = ns.spell_action({ 25384, 15261, 15267, 15266, 15265, 15264, 15263, 15262, 14914 }, "HolyFire"),
        HolyNova = ns.spell_action({ 25331, 25329, 27805, 27804, 27803, 27801, 27800, 27799, 15431, 15430, 15237 }, "HolyNova"),
        InnerFire = ns.spell_action({ 25431, 10952, 10951, 1006, 602, 7128, 588 }, "InnerFire"),
        InnerFocus = ns.spell_action({ 14751 }, "InnerFocus"),
        MindBlast = ns.spell_action({ 25375, 25372, 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092 }, "MindBlast"),
        MindFlay = ns.spell_action({ 25387, 18807, 17314, 17313, 17312, 17311, 15407 }, "MindFlay"),
        PowerWordFortitude = ns.spell_action({ 25389, 10938, 10937, 2791, 1245, 1244, 1243 }, "PowerWordFortitude"),
        PowerWordShield = ns.spell_action({ 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }, "PowerWordShield"),
        PsychicScream = ns.spell_action({ 10890, 10888, 8124, 8122 }, "PsychicScream"),
        Renew = ns.spell_action({ 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }, "Renew"),
        ShackleUndead = ns.spell_action({ 10955, 9485, 9484 }, "ShackleUndead"),
        ShadowWordPain = ns.spell_action({ 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }, "ShadowWordPain"),
        Shadowform = ns.spell_action({ 15473 }, "Shadowform"),
        Smite = ns.spell_action({ 25364, 25363, 10934, 10933, 6060, 1004, 984, 598, 591, 585 }, "Smite"),
        VampiricEmbrace = ns.spell_action({ 15286 }, "VampiricEmbrace"),
    }
    -- Wave 1.4 leveling_vanilla seeds (2026-08-13): warlock + rogue leveling
    -- files read SPELLS.X with a nil-guarded local spell_ready (see the
    -- DruidSpells comment for the full rationale). Ladders mirror
    -- classes/<class>/class_sylvanas.lua (TBC max-rank first); Stealth/
    -- SliceAndDice ids mirror the class ladder — the buff-map readers
    -- (stealth_helper, SnD gates) use their own id tables, so no buff/on_cd
    -- collision.
    ns.WarlockSpells = {
        Corruption = ns.spell_action({ 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
        CreateHealthstone = ns.spell_action({ 27230, 11730, 11729, 6202, 6201, 5699 }, "CreateHealthstone"),
        CreateSoulstone = ns.spell_action({ 27238, 20756, 20755, 20752, 693 }, "CreateSoulstone"),
        CurseOfAgony = ns.spell_action({ 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfAgony"),
        DeathCoil = ns.spell_action({ 27223, 17926, 17925, 6789 }, "DeathCoil"),
        DemonArmor = ns.spell_action({ 27260, 11735, 11734, 11733, 1086, 706 }, "DemonArmor"),
        DrainLife = ns.spell_action({ 27220, 27219, 11700, 11699, 7651, 709, 699, 689 }, "DrainLife"),
        DrainSoul = ns.spell_action({ 27217, 11675, 8289, 8288, 1120 }, "DrainSoul"),
        Fear = ns.spell_action({ 6215, 6213, 5782 }, "Fear"),
        HealthFunnel = ns.spell_action({ 27259, 11695, 11694, 11693, 3700, 3699, 3698, 755 }, "HealthFunnel"),
        HowlofTerror = ns.spell_action({ 17928, 5484 }, "HowlofTerror"),
        Immolate = ns.spell_action({ 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
        LifeTap = ns.spell_action({ 27222, 11689, 11688, 11687, 1456, 1455, 1454 }, "LifeTap"),
        SearingPain = ns.spell_action({ 30459, 27210, 17923, 17922, 17921, 17920, 17919, 5676 }, "SearingPain"),
        ShadowBolt = ns.spell_action({ 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
        SiphonLife = ns.spell_action({ 30911, 27264, 18881, 18880, 18879, 18265 }, "SiphonLife"),
        SpellLock = ns.spell_action({ 24259, 19647 }, "SpellLock"),
    }
    ns.RogueSpells = {
        AdrenalineRush = ns.spell_action({ 13750 }, "AdrenalineRush"),
        Ambush = ns.spell_action({ 27441, 11269, 11268, 11267, 8725, 8724, 8676 }, "Ambush"),
        BladeFlurry = ns.spell_action({ 13877 }, "BladeFlurry"),
        Blind = ns.spell_action({ 2094 }, "Blind"),
        ColdBlood = ns.spell_action({ 14177 }, "ColdBlood"),
        Evasion = ns.spell_action({ 26669, 5277 }, "Evasion"),
        Eviscerate = ns.spell_action({ 26865, 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, "Eviscerate"),
        ExposeArmor = ns.spell_action({ 26866, 11198, 11197, 8650, 8649, 8647 }, "ExposeArmor"),
        Garrote = ns.spell_action({ 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }, "Garrote"),
        Gouge = ns.spell_action({ 11286, 11285, 8629, 1777, 1776 }, "Gouge"),
        Kick = ns.spell_action({ 38768, 1769, 1768, 1767, 1766 }, "Kick"),
        KidneyShot = ns.spell_action({ 8643, 408 }, "KidneyShot"),
        Rupture = ns.spell_action({ 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, "Rupture"),
        Sap = ns.spell_action({ 11297, 2070, 6770 }, "Sap"),
        SinisterStrike = ns.spell_action({ 26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 }, "SinisterStrike"),
        SliceAndDice = ns.spell_action({ 6774, 5171 }, "SliceAndDice"),
        Sprint = ns.spell_action({ 11305, 8696, 2983 }, "Sprint"),
        Stealth = ns.spell_action({ 1787, 1786, 1785, 1784 }, "Stealth"),
        ThistleTea = ns.spell_action({ 9513 }, "ThistleTea"),
        Vanish = ns.spell_action({ 26889, 1857, 1856 }, "Vanish"),
    }
    -- Scenario-aware equipped-item mock: the mutilate_daggers scenario sets
    -- equipped_daggers = true and get_equipped_item_id returns a real dagger
    -- item id (776, from shared/dagger_set_sylvanas DAGGER_IDS) for the
    -- MAIN_HAND/OFF_HAND slots, so assassination's build_state derives
    -- state.has_daggers = true (assn:234-240 reads both hands + is_dagger
    -- map). Default 0 preserves the legacy no-weapon behavior everywhere else.
    -- NOTE: kebab's has_offhand_weapon also reads slot 17, so it sees the
    -- dagger in mutilate_daggers too — benign (kebab has 0 never-firing lanes
    -- and no exclusivity pin reads has_offhand).
    ns.get_equipped_item_id = function(slot)
        if ns._bstate("equipped_daggers", false)
            and (slot == ns.EQUIPMENT_SLOTS.MAIN_HAND or slot == ns.EQUIPMENT_SLOTS.OFF_HAND) then
            return 776
        end
        return 0
    end
    ns.EQUIPMENT_SLOTS = { HEAD = 1, MAIN_HAND = 16, OFF_HAND = 17 }
    ns.broken_api_throttled = function() return false end
    ns.is_interruptible = function() return true end
    ns.target_casting = function() return ns._bstate("target_is_casting", false) end
    ns.is_in_melee_range = function() return true end
    -- (resto RebirthBattleRez group gate: group_ok = (not group_aware) or
    -- is_in_party() or is_in_raid(); absent these the lane could never fire.)
    ns.is_in_party = function() return true end
    ns.is_in_raid = function() return false end
    ns.cp_debug = function() end
    ns.time_until_swing = function() return ns._bstate("swing_until", 0.5) end
    ns.has_health_potion = false
    ns.gcd_remains = function() return 0 end
    ns.get_gcd = function() return 1.5 end
    ns.in_combat = true

    -- ------------------------------------------------------------------
    -- Scenario state bank: apply_battery_state() rewrites this per scenario
    -- so every numeric NS read reflects the CURRENT context, not a fixed
    -- value. Defaults keep the legacy behavior (buffs down, full bars).
    -- ------------------------------------------------------------------
    ns._battery = {
        power = { [M.POWER.MANA] = 100, [M.POWER.RAGE] = 70, [M.POWER.FOCUS] = 90, [M.POWER.ENERGY] = 90, [M.POWER.COMBO] = 5 },
        stance = 0,
        form = 0,
        buffs_up = false,
        faction = 0,
        hp = 100,
        mana_pct = 100,
    }
    ns._bstate = function(key, def)
        local v = ns._battery[key]
        if v == nil then return def end
        return v
    end
    ns._bpower = function(id, def)
        local v = ns._battery.power[id]
        if v == nil then return def end
        return v
    end
    -- FSR manager (ranked #6): the real shared/fsr_manager_sylvanas loads and
    -- its game-state reads (is_inside_fsr via last-cast time, get_regen_delta
    -- via _core.spell_book power regen) return false/0 in the battery, so the
    -- 5 FSRPause healer lanes could never fire. Preload a scenario-driven
    -- stub backed by the state bank (the fsr_pause scenario sets the flags);
    -- each spec module captures THIS table at require() time, so the closures
    -- see the current scenario's bank on every build_state/match call.
    -- load_spec restores package.loaded after dofile so other suites get the
    -- real module back.
    package.loaded["shared/fsr_manager_sylvanas"] = {
        is_inside_fsr = function() return ns._bstate("fsr_inside", false) == true end,
        seconds_until_fsr = function() return ns._bstate("fsr_seconds", 0) end,
        get_regen_delta = function() return ns._bstate("fsr_regen_delta", 0) end,
        should_pause_for_fsr = function(state, context)
            local ok = ns._bstate("fsr_pause_ok", false) == true
            return ok, ok and "battery: inside FSR window" or "battery: outside FSR window"
        end,
        is_fsr_pause_enabled = function() return ns._bstate("fsr_pause_ok", false) == true end,
    }
    -- TSHelper (ranked #1): the real shared/ts_helper_sylvanas reads live
    -- target_selector state, so get_dps_targets returns empty in the battery
    -- and the multi-DoT spread lanes (warlock find_dot_target, shadow
    -- _find_multidot_target, balance _multidot_enemy_list) could never find a
    -- second unit. Preload a stub whose get_dps_targets returns the scenario's
    -- enemy list (ctx.enemies — populated for 2+ enemy scenarios, ranked #7);
    -- specs capture THIS table at require() time. get_heal_targets stays
    -- empty: the heal-scan stubs replace scan_healing_targets wholesale and
    -- must not see phantom allies.
    package.loaded["shared/ts_helper_sylvanas"] = {
        get_dps_targets = function(limit)
            local list = ns._bstate("enemies", {})
            if type(list) ~= "table" then return {} end
            return list
        end,
        get_heal_targets = function(limit) return {} end,
    }
    -- Buffs/debuffs: buffs_up scenarios report auras present, otherwise down.
    -- Per-buff remains: the `buff_remains_map` override ({ [buff_id] = seconds })
    -- takes precedence — this is the per-buff state mechanism (paladin holy
    -- LightGraceChain gates on lights_grace_remains in (0, 2.5), id 31834;
    -- future per-buff lanes — clearcasting, Surge of Light, Inner Focus —
    -- reuse it). NOTE: aura_remains/debuff_remains intentionally stay on the
    -- buffs_up fallback (no map lookup) — extend the map if a future lane
    -- gates on those APIs.
    -- buff_up is map-aware (ranked #5): combat's BladeFlurry needs SnD up
    -- (SND_BUFF {6774, 5171}) AND Blade Flurry's own buff down (13877) — both
    -- read ns.buff_up, so the all-or-nothing buffs_up fallback self-blocks
    -- (buffs_up=true marks BF already-up; buffs_up=false leaves SnD down). The
    -- battle_ready scenario sets buff_remains_map = { [6774]=20, [5171]=20 }
    -- → has_snd=true, has_blade_flurry=false. Map-miss ids fall back to
    -- buffs_up exactly as before, so non-map scenarios stay byte-identical.
    -- Shared with has_player_buff below (same map-first + buffs_up fallback
    -- semantics, identical normalization) — keep them on ONE helper so they
    -- can't drift apart.
    -- (a) opt-in close-out (2026-08-10): enh GraceOfAirTotemTwist reads
    -- NS.buff_remains(PLAYER, ACTION.WindfuryTotem / ACTION.GraceOfAirTotem)
    -- where ACTION.* is a spell_action OBJECT ({ids={...}}, no top-level
    -- numeric keys) — the legacy stubs iterated the object itself, so the
    -- map lookup always missed (buff 0) and the WF-buff/GoA-expiry gates
    -- could never pass. cooldown_remains already normalizes via spell.ids;
    -- share that normalization across every map-aware id consumer so
    -- callers passing lists, numbers, or spell_action objects all resolve.
    local function normalize_ids(ids)
        if type(ids) == "number" then return { ids } end
        if type(ids) == "table" then
            -- spell_action object (method surface, .ids list) vs plain list
            -- of numeric ids (SEAL_*_BUFF, RIP_DEBUFF, etc.).
            if type(ids.ids) == "table" then return ids.ids end
            return ids
        end
        return {}
    end
    local function map_aware_buff(ids)
        local map = ns._bstate("buff_remains_map", nil)
        ids = normalize_ids(ids)
        if type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return true end
            end
        end
        return ns._bstate("buffs_up", false)
    end
    ns.buff_up = function(unit, ids) return map_aware_buff(ids) end
    ns.buff_remains = function(unit, ids)
        local map = ns._bstate("buff_remains_map", nil)
        -- callers pass either a list of ids, a single numeric id (e.g. bear
        -- THORNS_BUFF), or a spell_action object (enh totem auras);
        -- normalize so ipairs never sees a number or an object.
        ids = normalize_ids(ids)
        if type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return map[id] end
            end
        end
        if ns._bstate("buffs_up", false) then return 20 end
        return 0
    end
    ns.aura_remains = function() if ns._bstate("buffs_up", false) then return 20 end return 0 end
    -- Per-target DoT model (ranked #1): the `debuff_remains_map` override
    -- ({ [debuff_id] = seconds }) marks the PRIMARY target as carrying those
    -- debuffs while peers stay clean, so multi-DoT spread lanes see
    -- primary-dotted + peer-undotted simultaneously. Previously `buffs_up`
    -- marked EVERY target dotted (deadlocking the spreads: primary-dot gate
    -- passes but find_dot_target sees the peer as already-dotted) and no
    -- scenario could set the primary's dot remains at all. Peers and
    -- map-less scenarios keep the buffs_up fallback unchanged, so Rupture /
    -- WintersChill / poison-stack consumers are byte-identical.
    ns.debuff_up = function(unit, ids)
        local map = ns._bstate("debuff_remains_map", nil)
        local prim = ns._bstate("primary_target", nil)
        ids = normalize_ids(ids)
        if unit == prim and type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return true end
            end
        end
        -- (b) close-out (2026-08-10): player-side debuff reads — SW:D CC break
        -- (offensive_dispel.is_breakable_cc_active(me, NS) → ns.debuff_up(me,
        -- id)) — consult the player-debuff map when the unit is the player
        -- (ns.me, published per scenario by apply_battery_state). The snare_self
        -- scenario uses player_debuff_remains_map { [122] = 5 }.
        if unit ~= nil and unit == ns.me then
            local pmap = ns._bstate("player_debuff_remains_map", nil)
            if type(pmap) == "table" then
                for _, id in ipairs(ids or {}) do
                    if pmap[id] ~= nil then return true end
                end
            end
        end
        if ns._bstate("buffs_up", false) then return true end
        return false
    end
    ns.debuff_remains = function(unit, ids)
        local map = ns._bstate("debuff_remains_map", nil)
        local prim = ns._bstate("primary_target", nil)
        ids = normalize_ids(ids)
        if unit == prim and type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return map[id] end
            end
        end
        -- (b) close-out (2026-08-10): player-side mirror of the debuff_up
        -- branch above (unit == ns.me → player_debuff_remains_map).
        if unit ~= nil and unit == ns.me then
            local pmap = ns._bstate("player_debuff_remains_map", nil)
            if type(pmap) == "table" then
                for _, id in ipairs(ids or {}) do
                    if pmap[id] ~= nil then return pmap[id] end
                end
            end
        end
        if ns._bstate("buffs_up", false) then return 20 end
        return 0
    end
    ns.has_player_buff = function(ids) return map_aware_buff(ids) end
    -- (c) close-out (2026-08-09): retribution Cleanse/Purify lanes read
    -- NS.has_player_debuff(COMMON_CLEANSE) (retribution:265-267); the early
    -- stub returned false always, so Ret_Cleanse_Self / Ret_Purify_SelfFallback
    -- / Ret_Cleanse_Ally were structurally dead. Map-aware over the new
    -- player_debuff_remains_map bank (scenario-driven); absent the map every
    -- caller keeps the legacy false. has_target_debuff mirrors it for
    -- unit_has_debuff(me) so find_ally can match the player when self is the
    -- debuffed unit (Cleanse_Ally falls back to me with no party members).
    ns.has_player_debuff = function(ids)
        local map = ns._bstate("player_debuff_remains_map", nil)
        ids = normalize_ids(ids)
        if type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return true end
            end
        end
        return false
    end
    -- Vanilla battery sweep (2026-08): discipline DispelMagic reads
    -- NS.has_debuff(me, id) (DISPEL_MAGIC_DEBUFF_IDS) — the constant-false
    -- stub made it structurally dead. Mirror has_player_debuff over the same
    -- player_debuff_remains_map bank (ret_cleanse_self carries a magic DoT
    -- id 589).
    ns.has_debuff = function(unit, ids)
        return ns.has_player_debuff(ids)
    end
    ns.has_target_debuff = function(unit, ids)
        -- Cleanse_Ally's unit_has_debuff(me, ...) passes the PLAYER; reuse the
        -- player-debuff map so a self-afflicted scenario fires it (find_ally
        -- falls back to me when the battery presents no party members).
        return ns.has_player_debuff(ids)
    end
    -- Stealth helper (ranked #7): the real shared/stealth_helper_sylvanas
    -- caches `NS = _G.EaxRotations` at ITS first require() — the first spec
    -- that loads it (druid cat, run order) — so every later rogue spec's
    -- is_stealthed_for_class() read the FIRST spec's state bank, stale across
    -- specs and scenario-order-dependent (combat CheapShot/Garrote fired or
    -- not depending on which process/order ran). Stub it scenario-driven like
    -- fsr/ts_helper: has_player_buff is map-aware, so stealth maps to the
    -- current spec's own bank (stealth_opener's buff_remains_map [1784], or
    -- the buffs_up fallback). load_spec restores package.loaded afterwards.
    package.loaded["shared/stealth_helper_sylvanas"] = {
        STEALTH_BUFF_IDS = { 1787, 1786, 1785, 1784 },
        PROWL_BUFF_IDS = { 9913, 6783, 5215 },
        is_stealthed = function()
            return ns.has_player_buff({ 1787, 1786, 1785, 1784, 9913, 6783, 5215, 20580 })
        end,
        is_stealthed_for_class = function(class)
            local ids = class == "druid" and { 9913, 6783, 5215 } or { 1787, 1786, 1785, 1784 }
            return ns.has_player_buff(ids)
        end,
        try = function() return true end,
    }
    -- has_buff: map-only (NO buffs_up fallback) — holy's PrayerOfMending
    -- (holy_sylvanas.lua:786) and hunter BM Misdirection (beast_mastery:556)
    -- use it as an anti-overwrite gate. The fsr_pause scenario carries the PoM
    -- buff id (33076) so PoM (position 5, before FSRPause at 13) stops
    -- stealing the lane; every other scenario has no map entry so the return
    -- is false — byte-identical to the pre-map behavior. (No buffs_up fallback:
    -- unlike has_player_buff, these callers must NOT see "all buffs up" in
    -- buffs_up scenarios or Misdirection/PoM would silently stop firing there.)
    ns.has_buff = function(unit, ids)
        local map = ns._bstate("buff_remains_map", nil)
        if type(ids) == "number" then ids = { ids } end
        if type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return true end
            end
        end
        return false
    end
    ns.get_buff_stacks = function() if ns._bstate("buffs_up", false) then return 1 end return 0 end
    -- buff_stacks alias: shaman resto reads NS.buff_stacks for water/earth
    -- shield charges (water_shield_matches refreshes at 0 charges); without
    -- it charges read nil->0 and WaterShield fires before FSRPause even in
    -- buffs_up scenarios. Mirroring get_buff_stacks (1 when buffs_up) also
    -- keeps earth-shield refresh suppressed (remains 20 > 5 + charges 1).
    -- buff_stacks alias (enh LightningBolt maelstrom gate reads this with the
    -- MAELSTROM_WEAPON_BUFF ids): make it map-aware like buff_remains — a
    -- buff_remains_map entry for a queried id returns its stack value (the
    -- enh_procs scenario sets [53817] = 5), else the buffs_up fallback (1) to
    -- keep resto water/earth-shield reads byte-identical.
    ns.buff_stacks = function(unit, ids)
        local map = ns._bstate("buff_remains_map", nil)
        if type(ids) == "number" then ids = { ids } end
        if type(map) == "table" then
            for _, id in ipairs(ids or {}) do
                if map[id] ~= nil then return map[id] end
            end
        end
        if ns._bstate("buffs_up", false) then return 1 end
        return 0
    end
    -- Scenario-driven debuff stacks (poison_stacks scenario). Scoped by aura
    -- ids so one spec's stacks never bleed into another (e.g. mage AB stacks /
    -- frost Winter's Chill must stay 0 when only deadly-poison stacks are set).
    ns.debuff_stacks = function(unit, ids)
        local v = ns._bstate("debuff_stacks", 0)
        if not (v and v > 0) then return 0 end
        -- Strict id-scoping: a scenario that raises stacks MUST carry the aura
        -- ids, otherwise unrelated readers (mage AB stacks, frost Winter's
        -- Chill) would spuriously see the value.
        local aura_ids = ns._bstate("debuff_aura_ids", nil)
        if type(aura_ids) ~= "table" or type(ids) ~= "table" then return 0 end
        for _, id in ipairs(ids) do
            for _, aid in ipairs(aura_ids) do
                if id == aid then return v end
            end
        end
        return 0
    end
    ns.get_debuff_stacks = ns.debuff_stacks
    -- Numeric reads delegate to the scenario state bank.
    ns.power_current = function(p) return ns._bpower(p or M.POWER.MANA, 100) end
    ns.get_power = function(p) return ns._bpower(p or M.POWER.MANA, 100) end
    ns.power_pct = function(p) return math.min(100, ns._bpower(p or M.POWER.MANA, 100)) end
    ns.power_mana = function() return ns._bpower(M.POWER.MANA, 100) end
    ns.energy = function() return ns._bpower(M.POWER.ENERGY, 100) end
    ns.focus = function() return ns._bpower(M.POWER.FOCUS, 90) end
    ns.rage = function() return ns._bpower(M.POWER.RAGE, 70) end
    ns.mana = function() return ns._bpower(M.POWER.MANA, 100) end
    ns.get_combo_points = function() return ns._bpower(M.POWER.COMBO, 5) end
    ns.combo_points = function() return ns._bpower(M.POWER.COMBO, 5) end
    ns.mana_pct = function() return ns._bstate("mana_pct", 100) end
    ns.health_pct = function(u)
        if u and u.get_health_percentage then
            local ok, v = pcall(u.get_health_percentage, u)
            if ok and type(v) == "number" then return v end
        end
        return ns._bstate("hp", 100)
    end
    ns.unit_health_pct = ns.health_pct
    ns.unit_mana_pct = function() return ns._bstate("mana_pct", 100) end
    ns.get_player_stance = function() return ns._bstate("stance", 0) end
    ns.unit_faction = function() return ns._bstate("faction", 0) end
    -- Mock marker (survey item #2, require-time NS-caching fix): shared modules
    -- that bind their exports into _G.EaxRotations at require() time (e.g.
    -- auto_tremor, dot_refresh, purge_manager, mf_tick_compute) must NOT write
    -- into a mock NS — the mock is discarded after each battery load and any
    -- bindings are pure pollution (they'd shadow the real engine's bindings if
    -- the mock's table were ever cached by a later tool). All 8 write-back
    -- modules now gate on `not _G.EaxRotations._EAX_MOCK`, so a mock NS can
    -- never capture a module instance.
    ns._EAX_MOCK = true
    return ns
end

-- ---------------------------------------------------------------------------
-- Context builder
-- ---------------------------------------------------------------------------
local function _base_ctx(profile)
    local ctx = {
        me = _me_unit(),
        target = _target(),
        has_valid_enemy_target = true,
        has_target = true,
        in_combat = true,
        combat_state_known = true,
        target_ttd = 60,
        ttd = 60,
        target_hp = 100,
        hp = 100,
        player_hp = 100,
        mana_pct = 100,
        player_mana = 100,
        player_mana_pct = 100,
        enemy_count = 1,
        enemies_count = 1,
        enemies = {},
        target_range = 5,
        target_distance = 5,
        is_pvp = false,
        is_dungeon = false,
        is_raid = false,
        is_group = false,
        is_solo = true,
        is_leveling = false,
        level = 70,
        player_level = 70,
        stance = 0,
        rage = 100,
        energy = 100,
        focus = 100,
        combo_points = 5,
        attack_power = 300,
        target_armor = 1000,
        combat_time = 30,
        gcd_remains = 0,
        on_gcd = false,
        is_moving = false,
        me_casting = false,
        in_melee_range = true,
        ttd_known = true,
        has_health_potion = false,
        has_mana_potion = false,
        friends_afflicted = false,
        enemy_buffed = false,
        settings = {},
        lowest = { unit = nil, hp = 100 },
    }
    if profile ~= nil then
        if profile.ranged then
            ctx.target_range = 30
            ctx.target_distance = 30
        end
        if profile.melee then
            ctx.target_range = 5
            ctx.target_distance = 5
        end
        ctx.mana_pct = 90
        if profile.resource == "rage" then ctx.rage = 70 end
        if profile.resource == "energy" then ctx.energy = 90 end
        if profile.resource == "focus" then ctx.focus = 90 end
    end
    return ctx
end

-- ---------------------------------------------------------------------------
-- Scenario battery (deterministic order). Overrides drive BOTH the context
-- table and (via apply_battery_state) the NS state bank, so each scenario
-- presents realistic resource/stance/aura states to the match functions.
-- ---------------------------------------------------------------------------
M.SCENARIOS = {
    { name = "standard" },
    { name = "combo_build",      overrides = { combo_points = 0, energy = 60, focus = 60 } },
    { name = "energy_low",       overrides = { combo_points = 0, energy = 30 } },
    { name = "aoe",              overrides = { enemy_count = 4, enemies_count = 4, stance = 1 } },
    { name = "execute",          overrides = { target_hp = 8, ttd = 6, target_ttd = 6, on_cd = { [30330] = 6, [1680] = 10 } } },
    { name = "cd_pressure",      overrides = { on_cd = { [30356] = 6, [30357] = 5, [30330] = 6, [1680] = 10, [11585] = 1, [30335] = 6 } } },
    { name = "leveling_execute", overrides = { level = 25, player_level = 25, is_leveling = true, target_hp = 8, ttd = 6, target_ttd = 6 } },
    { name = "swing_window",     overrides = { swing_until = 1.0, on_cd = { [30330] = 6, [1680] = 10, [11585] = 1, [30335] = 6 } } },
    -- Primary-on-cooldown fillers (triage upgrade): prot Devastate/Rend/
    -- HeroicStrike gate on `ss_ready == false and revenge_ready == false`
    -- (ShieldSlam 30356 / Revenge 30357 on cd); stance=2 (defensive) matches
    -- live tanking and rage=100 clears the HS dump floor (default 70 == the
    -- HEROIC_STRIKE_RAGE_DUMP constant, a razor edge). Requires the
    -- WarriorSpells seed. (Devastate fires here: dev_ready true, ss/rev on CD.)
    { name = "prot_filler_cd",   overrides = { stance = 2, rage = 100, on_cd = { [30356] = 6, [30357] = 5 } } },
    -- Close-out ranked #1 (2026-08-08): SunderArmor's pre-Devastate fallback
    -- needs dev_ready false (prot:531) — Devastate {30022,...} on CD — PLUS
    -- ss_ready/revenge_ready false (prot:533) so the filler branch fires.
    -- NOT the not_learned map: it only gates spell_exists/is_spell_learned,
    -- while dev_ready comes from the cooldown-only spell_ready mock. The
    -- Devastate entry in the WarriorSpells seed makes the [30022] key
    -- resolvable by cooldown_remains (ids[1]). Devastate itself is silenced
    -- in THIS scenario only (dev_ready false) — harmless, it fires in
    -- prot_filler_cd and elsewhere.
    { name = "sunder_fallback",  overrides = { stance = 2, rage = 100, on_cd = { [30022] = 6, [30356] = 6, [30357] = 5 } } },
    -- Tank triage (ranked #6): elite classification (1) + an un-tanked target
    -- (target_get_target = false → target:get_target() nil) + visible
    -- un-tanked enemies (visible_enemies) make the smart-taunt lanes
    -- observable. Taunt needs Taunt ready; TauntSecondary needs Taunt on CD
    -- (355) + no_threat_target from the visible-objects scan + enemy_count ≥ 3.
    -- MockingBlow/ChallengingShout share the elite gates and clear here too.
    { name = "elite_target",   overrides = { target_classification = 1, enemy_count = 3, enemies_count = 3, target_get_target = false, visible_enemies = true } },
    { name = "elite_taunt_cd", overrides = { target_classification = 1, enemy_count = 3, enemies_count = 3, target_get_target = false, visible_enemies = true, on_cd = { [355] = 6 } } },
    -- Tank triage (last (c) item): prot IntimidatingShout needs min_enemies 3
    -- (protection:505 via s.enemy_count) AND state.hp <= 50 (matcher:825).
    -- elite_target has the 3 enemies but hp 100; low_self has hp 15 but 1
    -- enemy — only this combo clears it (and fires exclusively here: no other
    -- scenario combines enemy_count >= 3 with hp <= 50).
    -- NOTE: this is a SUPERSET of elite_target + low_self — low-self-gated
    -- prot lanes (e.g. HealthPotion) may also fire here even though they are
    -- pinned elsewhere; do NOT pin such a lane to this scenario.
    { name = "elite_low_self", overrides = { target_classification = 1, hp = 15, player_hp = 15, enemy_count = 3, enemies_count = 3 } },
    -- Ice Block (45438) on cooldown + low HP (triage upgrade): arcane/frost
    -- ColdSnap defensive lanes gate on `not spell_ready(IceBlock)` and hp <= 35.
    { name = "cold_snap_cd",     overrides = { on_cd = { [45438] = 60 }, hp = 15, player_hp = 15 } },
    { name = "low_mana",         overrides = { mana_pct = 10, player_mana = 300, player_mana_pct = 10, has_potions = true } },
    { name = "low_self",         overrides = { hp = 15, player_hp = 15, has_potions = true } },
    -- Mana emergency floor (healer triage upgrade): elemental/restoration
    -- default mana_emergency to strict `< 5` (MANA_EMERGENCY_DEFAULT=5) and
    -- holy's ManaBelow5Wand blocks at `>= 5`, so the scenario must set 4 — a
    -- 5 would leave all four wand lanes invisible. Unblocks ManaEmergencyWand
    -- x3 (elemental/enhancement/restoration) + holy ManaBelow5Wand.
    { name = "mana_critical",     overrides = { mana_pct = 4, player_mana = 120, player_mana_pct = 4 } },
    { name = "moving",           overrides = { is_moving = true } },
    { name = "target_casting",   overrides = { target_is_casting = true } },
    -- WotLK rogue Kick interrupt (2026-08-10): the three *_wotlk.lua rogue
    -- rotations gained a baseline Kick strategy (combat/subtlety/assassination
    -- had zero interrupt handling). It gates on in_combat + target_is_casting
    -- like arcane Counterspell; this scenario keeps it observable so the
    -- WotLK never=0 pin stays non-vacuous.
    { name = "wotlk_rogue_kick", overrides = { target_is_casting = true, target_cast_pct = 60 } },
    -- WotLK era-coverage close-out (2026-08-10): prot/fury Pummel, elemental
    -- EarthShock, shadow Silence — the remaining specs whose class siblings
    -- already interrupted (arms Pummel, rogue Kick, arcane Counterspell) but
    -- that had zero interrupt handling. Same gate, same dedicated scenario so
    -- the WotLK never=0 pin stays non-vacuous for the new strategies.
    { name = "wotlk_interrupts", overrides = { target_is_casting = true, target_cast_pct = 60 } },
    -- W3.3 warrior sweep (2026-08-13): arms Retaliation is Defensive-stance-only
    -- in WotLK AND boss-gated; the file's DefensiveStance dance covers the
    -- stance swap, so this scenario presents the tank already in Defensive
    -- facing a boss so the lane itself is observable (real CD API: retaliation
    -- NOT on cooldown in the default on_cd bank).
    -- W3.4 mock-tightening (2026-08-13): drives the REAL dispatcher field
    -- context.target_is_boss (main_sylvanas.lua:1287) — the phantom
    -- ctx.is_boss override is gone (arms_wotlk is_boss() reads target_is_boss
    -- first; the legacy context.is_boss compat line was DELETED in the W3.4
    -- targeted fix, see run_read_side_audit_tests.lua allowlist).
    { name = "arms_retaliation", overrides = { stance = 2, target_is_boss = true, rage = 50 } },
    -- W3.4 warrior rage chain (2026-08-13): with me:get_rage() tripwired, the
    -- battery unit has NO mock rage member — warrior wotlk lanes can only see
    -- rage through the REAL chain (context.rage from main_sylvanas.lua:814, or
    -- me:get_power(NS.POWER_RAGE)). This scenario drives context.rage = 25
    -- (>= the WotLK Execute cost 15) inside the execute window (target_hp 15)
    -- so the arms/fury/leveling Execute lanes prove they fire through that
    -- chain: any surviving me:get_rage() read errors loudly instead of
    -- silently firing the lane.
    { name = "arms_execute_rage", overrides = { rage = 25, target_hp = 15 } },
    -- W3.3 warrior sweep (2026-08-13): leveling_wotlk's BattleStance lane only
    -- fires OOC when the warrior is NOT already in Battle stance, but the
    -- harness force-defaults warriors to stance 1 — this scenario presents a
    -- warrior left in Defensive stance OOC so the stance-up lane (and the
    -- 8-25 yd range-gated Charge, same scenario) stay observable.
    { name = "leveling_warrior_ooc", overrides = { in_combat = false, stance = 2, target_distance = 15, target_range = 15 } },
    { name = "stealth",          overrides = { is_stealthed = true, combo_points = 0 } },
    -- Rogue stealth openers (ranked #7): combat Garrote needs stealth + a
    -- casting target; subtlety CheapShot needs stealth + the explicit
    -- opener_preference (auto resolves garrote-on-caster / ambush-elsewhere,
    -- so the pref is what isolates CheapShot). buff_remains_map [1784]
    -- (Stealth) is map-first, so no buffs_up fallback claims the lane.
    { name = "stealth_opener", overrides = { buff_remains_map = { [1784] = 10 }, target_is_casting = true, setting_overrides = { opener_preference = "cheap_shot" } } },
    -- PvP combo scenarios (warrior/rogue triage, 2026-08-08): the remaining
    -- rogue (b) lanes need ONE extra flag on top of an existing scenario.
    -- NOTE: the pvp_low_hp combo from the triage ({ is_pvp, hp = 15 }) is
    -- ALREADY satisfied by defensive_casting — combat/subtlety Blind cleared
    -- there and are exclusivity-pinned (fires-in(1)), so a separate scenario
    -- would only break that pin; do not add it.
    -- pvp_stealth_opener: assassin PvP_CheapShotOpen needs stealth_active
    -- (NS.has_player_buff(STEALTH_BUFF = {1787..1784}) — map-driven, so the
    -- is_stealthed bank key does NOT feed it) + is_pvp. The stealth_opener
    -- scenario has the stealth map but no is_pvp; `stealth`/`pvp` have one
    -- flag each. This is the only is_pvp + stealth-map combo. No
    -- target_is_casting / opener_preference, so the combat Garrote + subtlety
    -- CheapShot pins (stealth_opener exclusivity) are untouched.
    { name = "pvp_stealth_opener", overrides = { is_pvp = true, buff_remains_map = { [1784] = 10 } } },
    -- pvp_gap_close: assassin PvP_SprintGapClose needs is_pvp AND
    -- target_distance >= 15 (pvp = dist 5; gap_close = 15 but not pvp).
    -- This is the only is_pvp + range combo. Already-firing lanes that read
    -- dist >= 15 (subtlety sprint_gap, warrior Intercept) legitimately gain a
    -- fires-in here — never-list unchanged.
    { name = "pvp_gap_close",     overrides = { is_pvp = true, target_distance = 15, in_melee_range = false } },
    -- Rogue Preparation reset (ranked #8): subtlety's matcher needs
    -- state.hp <= 40 (subtlety_prep_hp default) AND a major CD burned
    -- (vanish_cd/sprint_cd/evasion_cd from state). vanish_cd derives from
    -- NS.get_spell_cd, now bank-aware; prep_ready puts Vanish on CD (1856,
    -- any rank) at low HP. Preparation fires ONLY here (no other scenario has
    -- a Vanish/Sprint/Evasion CD entry).
    { name = "prep_ready",   overrides = { hp = 15, player_hp = 15, on_cd = { [1856] = 60 } } },
    -- Alt/leveling lanes (ranked #9): the low_level scenario marks pre-level
    -- spells as NOT learned (not_learned map) so the leveling fallbacks become
    -- observable: arcane FireballLeveling/FrostboltLeveling (is_leveling +
    -- spell_exists(ArcaneBlast 30451) false), frost FrostArmor (MageArmor
    -- 27125/6117 not learned — pre-34 fallback), warlock demonology SummonImp
    -- (SummonFelguard 30146 not learned + Imp 688 learned, OOC, no pet).
    -- Every lane fires ONLY here (no other scenario sets is_leveling together
    -- with a not-learned entry; OOC no-pet lanes already exist).
    { name = "low_level",    overrides = { level = 20, player_level = 20, is_leveling = true, in_combat = false, not_learned = { [30451] = true, [27125] = true, [6117] = true, [30146] = true, [0] = true } }, no_pet = true },
    -- Vanilla battery sweep (2026-08): arcane_vanilla's low_level_bolt gates
    -- on spell_exists(SPELLS.UnavailableClassicMageArcane) (a nil sentinel in
    -- the class file) instead of ArcaneBlast — the mock seeds the sentinel
    -- with id 0, so [0] in not_learned makes the vanilla Fireball/Frostbolt
    -- leveling lanes observable exactly like the TBC ArcaneBlast path.
    -- Phase 3 (2026-08-09): first batch of ranked (c) fixtures from the
    -- non-DPS triage — hunter Readiness x3, SerpentStingRefresh x2, holy
    -- ClearcastingGreaterHeal/SurgeOfLightSmite, elem moving shocks x2.
    --
    -- readiness_window: hunter Readiness (BM DSL + MM + survival) gates on
    -- `rapid_fire_cd >= 60` (state from safe_cooldown_remains(RapidFire 3045),
    -- which reads the bank-aware cooldown_remains mock). MM additionally needs
    -- ttd >= 20 (marksmanship:495). No other scenario puts 3045 on cd.
    { name = "readiness_window", overrides = { on_cd = { [3045] = 61 }, ttd = 60, target_ttd = 60 } },
    -- serpent_refresh: SerpentStingRefresh (BM + survival) gates on the
    -- serpent debuff being up with <= 3s remaining (hunter_core.sting_remains
    -- / NS.debuff_remains read the primary-target debuff_remains_map) plus a
    -- ttd floor (survival:420 needs ttd >= 6). [27016] is the max-rank
    -- Serpent Sting id in SERPENT_STING_DEBUFF {27016,...} (BM:44, MM:79,
    -- survival:87). The map is primary-target-scoped (debuff_up/remains check
    -- unit == primary_target), and the primary is ctx.target (line ~2059).
    { name = "serpent_refresh", overrides = { debuff_remains_map = { [27016] = 2, [13555] = 2 }, on_cd = { [27065] = 6 }, ttd = 30, target_ttd = 30 } },
    -- Vanilla battery sweep (2026-08): BM/survival ArcaneShot gates on
    -- `if s.aimed_shot_ready then return false end` — the nil-lenient mock
    -- made AimedShot "always ready" so Arcane Shot could never fire. Seeding
    -- HunterSpells.AimedShot (ids[1]=27065) + putting it on CD here makes the
    -- lane observable; the debuff map gains the VANILLA Serpent Sting max rank
    -- (13555; 27016 is TBC-only) so the vanilla SerpentStingRefresh fires.
    -- clearcast_surge: holy ClearcastingGreaterHeal + SurgeOfLightSmite read
    -- per-buff state via has_player_buff (HOLY_CONCENTRATION_BUFF {34753,...}
    -- / SURGE_OF_LIGHT_BUFF {33151,...}) — the all-or-nothing buffs_up can't
    -- express "one buff up". buff_remains_map is map-first, so this is the
    -- only scenario where those two are up. Default injured friends
    -- {55,70,85} satisfy both lanes' lowest_hp bands (GH < 95, surge >= 50).
    { name = "clearcast_surge", overrides = { buff_remains_map = { [34753] = 1, [33151] = 1 } } },
    -- Phase 2.3 scenario modeling (2026-08-13, top-tier parsing campaign):
    -- per-buff / per-stack fidelity scenarios for the parse-critical proc and
    -- refresh mechanics. Each lane below ALREADY fired via the coarse buffs_up
    -- fallback (buffs_up marks every aura up); these scenarios drive the REAL
    -- aura ids through buff_remains_map / debuff_remains_map so the battery
    -- demonstrates the mechanic with per-aura precision (one proc up, others
    -- down), not the all-buffs-up posture. Ids are spec-scoped (12536 fire/
    -- frost/arcane clearcasting, 16864 cat Omen, 12043 PoM, 33745 Lacerate,
    -- 28595 Winter's Chill), so no other spec's gates change. Placement before
    -- the buffs_up/burst/burn scenarios keeps arcane's sticky burn phase out
    -- of these shapes (no player_mana/ttd keys set).
    -- bear Lacerate 5-stack refresh: stacks 5 (debuff_stacks + aura ids) with
    -- remains 2 inside LACERATE_REFRESH_WINDOW (3.0) — the refresh branch of
    -- the Lacerate DSL (stacks < 5 -> stack; remains <= 3 -> refresh) fires.
    { name = "bear_lacerate_refresh", overrides = { form = 1, in_combat = true, debuff_stacks = 5, debuff_aura_ids = { 33745 }, debuff_remains_map = { [33745] = 2 } } },
    -- cat Omen of Clarity proc: OMEN_OF_CLARITY_BUFF {16864} up via the map —
    -- ShredOmen (free Shred consume) fires while Rake/Rip/Mangle remain down
    -- (no buffs_up), proving the per-buff proc path of clearcasting_shred_matches.
    { name = "cat_omen_proc", overrides = { form = 3, in_combat = true, buff_remains_map = { [16864] = 1 }, energy = 80, combo_points = 2 } },
    -- fire Clearcasting consume: CLEARCASTING_BUFF {12536} up via the map —
    -- fireball_matches_fn's `has_clearcasting -> always Fireball` branch fires
    -- with the proc precisely modeled (Arcane Concentration talent).
    { name = "fire_clearcasting", overrides = { in_combat = true, buff_remains_map = { [12536] = 1 } } },
    -- fire Presence of Mind -> Pyroblast: PRESENCE_OF_MIND_BUFF {12043} up via
    -- the map — pyroblast_matches_fn's pom_active branch fires, and the PoM
    -- lane itself self-blocks (its DSL gate is buff 12043 invert), so the
    -- Pyroblast-on-PoM sequencing is demonstrated, not the PoM re-cast.
    { name = "fire_pom_pyro", overrides = { in_combat = true, buff_remains_map = { [12043] = 1 } } },
    -- frost Winter's Chill 5-stack refresh policy: WINTERS_CHILL_DEBUFF
    -- {28595} at 5 stacks (debuff_stacks + aura ids) with 2s remains — the
    -- WintersChill DSL's `stacks >= 5 and remains > 3` suppression passes
    -- (2 <= 3), so the refresh lane fires and the plain Frostbolt filler does
    -- not skip (its WC-aware gate uses the same remains read).
    { name = "frost_wc_refresh", overrides = { in_combat = true, debuff_stacks = 5, debuff_aura_ids = { 28595 }, debuff_remains_map = { [28595] = 2 } } },
    -- elem_shock_moving: EarthShockMoving gates is_moving + the
    -- elemental_interrupt_reserve setting DEFAULT true (elemental:250) — the
    -- plain `moving` scenario leaves the reserve on, so this is the only
    -- scenario where the filler is legal while moving.
    { name = "elem_shock_moving", overrides = { is_moving = true, setting_overrides = { elemental_interrupt_reserve = false } } },
    -- elem_shock_pvp: FrostShockMoving gates is_moving AND is_pvp
    -- (elemental:255-256) — no single existing scenario combines both.
    { name = "elem_shock_pvp",    overrides = { is_moving = true, is_pvp = true } },
    { name = "buffs_up",         overrides = { buffs_up = true, combo_points = 0 } },
    { name = "pull",             overrides = { in_combat = false, buffs_up = true, is_stealthed = true, combo_points = 0 } },
    { name = "short_ttd",        overrides = { target_ttd = 2, ttd = 2, target_hp = 20, combo_points = 5, energy = 60 } },
    { name = "mid_ttd",          overrides = { target_ttd = 30, ttd = 30 } },
    { name = "long_ttd",         overrides = { target_ttd = 120, ttd = 120 } },
    { name = "pvp_interrupt",    overrides = { is_pvp = true, target_is_casting = true, combo_points = 3 } },
    { name = "berserker_interrupt", overrides = { stance = 3, target_is_casting = true } },
    { name = "potions_ready",    overrides = { has_potions = true } },
    -- friends_afflicted: poison/disease/curse/magic affliction drives the
    -- cleanse/cure lanes. NOTE: CureDisease (528) is deliberately NOT on cd
    -- here (removed 2026-08-13): with the bank-aware spell_ready forwarding
    -- below, an on_cd entry would block the very lane this scenario exists to
    -- fire — CureDisease needs `ready AND has_disease`, and the disease flag
    -- is only set in this scenario. The pre-emptive AbolishDisease branch
    -- (fires when CureDisease is NOT ready) is driven by the holy_cure_on_cd
    -- scenario instead, so the two halves of the cure pair stay observable in
    -- BOTH eras (TBC holy + vanilla holy).
    { name = "friends_afflicted", overrides = { friends_afflicted = true, friends_hp = { 80, 90, 95 }, afflicted = { poison = true, disease = true, curse = true, magic = true } } },
    -- Healer group-damage scenarios (healer triage upgrade): friends_hp bands
    -- are tuned per lane family — group_light (62/72/85: GH + PreHeal + RenewTank),
    -- group_critical (30/45/60 + low self: BindingHeal + Emergency PWS),
    -- group_aoe (4 injured: PrayerOfHealing + CircleOfHealing + ChainHeal),
    -- group_healthy (100s: nobody injured → idle-DPS lanes fire),
    -- tank_low (entry[2] = tank at 30: disc PowerWordShieldTank + PainSuppression),
    -- mana_tide_window (healthy group + low mana: resto ManaTideTotem).
    { name = "group_healthy",   overrides = { friends_hp = { 100, 100, 100 }, friend_class = 11 } },
    -- Per-buff state (ranked #2): Light's Grace active at 1.5s remaining —
    -- paladin holy LightGraceChain gates on lights_grace_remains in (0, 2.5)
    -- (buff id 31834); the default injured group (55/70/85) satisfies the
    -- tank-deficit gate. General mechanism: any buff_remains_map entry.
    { name = "lights_grace",    overrides = { buff_remains_map = { [31834] = 1.5 } } },
    -- Seal-twist state (ranked #5): retri SealTwistBlood needs the Command seal
    -- up (buff 27170), no Blood seal, and swing <= twist window (0.45s);
    -- SealTwistPrepCommand needs the Blood seal up (31892), Judgement on CD
    -- > 1.5s (id 20271), and swing in (0.45, 1.2]. can_twist only flips on here
    -- (via setting_overrides) so both lanes stay silent in every other scenario.
    { name = "seal_twist_blood", overrides = { setting_overrides = { seal_twisting_enabled = true }, buff_remains_map = { [27170] = 5 }, swing_until = 0.4 } },
    { name = "seal_twist_prep",  overrides = { setting_overrides = { seal_twisting_enabled = true }, buff_remains_map = { [31892] = 5 }, swing_until = 0.9, on_cd = { [20271] = 2.0 } } },
    -- Friend class-id (ranked #4): the group scenarios present a healer ally
    -- (class 11) so druid/resto's innervate scan (is_healer_entry via
    -- unit_class_id -> get_class) can pick a non-self healer; mana_tide_window's
    -- low mana makes InnervateHealer fire. InnervateSelf stays observable via
    -- the non-group low-mana scenarios (low_mana/mana_critical), which keep
    -- friends class-less.
    { name = "group_light",     overrides = { friends_hp = { 62, 72, 85 }, friend_class = 11 } },
    { name = "group_critical",  overrides = { hp = 50, player_hp = 50, friends_hp = { 30, 45, 60 }, friend_class = 11 } },
    { name = "group_aoe",       overrides = { friends_hp = { 40, 55, 65, 75 }, friend_class = 11 } },
    { name = "tank_low",        overrides = { friends_hp = { 55, 30, 80 }, friend_class = 11 } },
    { name = "mana_tide_window", overrides = { friends_hp = { 100, 100, 100 }, mana_pct = 10, player_mana = 300, player_mana_pct = 10, friend_class = 11 } },
    -- FSR pause window (ranked #6): mid-Five-Second-Rule pause — inside FSR
    -- (fsr_inside), positive regen delta (fsr_regen_delta), healthy group
    -- (friends 100s so no triage heal fires first), mana 30 (<= the 35 gate
    -- but above the emergency floors). buffs_up=true is load-bearing: shaman
    -- WaterShield/LightningShield and paladin AuraManagement/BlessingRefresh
    -- all read "shield/aura already up" and would otherwise match before
    -- FSRPause. ManaTide (16190) + Innervate (29166) on cd — used in the
    -- window; without them ManaTideTotem (mana <= 60) / InnervateSelf /
    -- RebirthBattleRez (no dead-ally model — see report) steal the lane;
    -- Bloodlust (2825) fires on healthy groups. player_mana_pct drives holy's
    -- context.mana_pct (no NS.unit_mana_pct fallback — disc has one); the PoM
    -- buff id (33076) in the map blocks holy PrayerOfMending (position 5) via
    -- the map-aware ns.has_buff; holy_refresh_enabled/holy_blessing_light
    -- false block paladin BlessingRefresh + BlessingOfLightTank (blessings
    -- read "up" at exactly the 120s refresh boundary). buff_stacks (new)
    -- keeps shaman WaterShield from refreshing at 0 charges.
    -- Unblocks FSRPause x5 (holy/disc priest, holy paladin, resto
    -- druid/shaman) + retri Ret_JudgementWisdom_LowMana (incidental).
    { name = "fsr_pause",      overrides = { mana_pct = 30, player_mana_pct = 30, friends_hp = { 100, 100, 100 }, buffs_up = true, fsr_inside = true, fsr_seconds = 3.0, fsr_regen_delta = 20, fsr_pause_ok = true, buff_remains_map = { [33076] = 15 }, setting_overrides = { holy_refresh_enabled = false, holy_blessing_light = false }, on_cd = { [16190] = 60, [29166] = 60, [26994] = 60, [2825] = 600 } } },
    -- Emergency group + HoT buffs: druid resto SwiftmendEmergency /
    -- TranquilityEmergency (3 targets <= 25) / NaturesSwiftnessHealingTouch
    -- (buff present); NaturesSwiftness (buff absent) via group_critical's
    -- <= 30 target + short TTD.
    { name = "group_emergency", overrides = { buffs_up = true, friends_hp = { 18, 22, 24 } } },
    -- Pushback: enemy in range casting on the player. Unblocks the priest
    -- PreHeal lanes (disc + holy pre_heal_matches gate on _check_pushback,
    -- which scans NS.GetEnemiesInRange for a casting enemy). Tank band
    -- {62,72,85} puts entry[2] = 72 inside PreHeal's [60, 95] window.
    { name = "pushback",        overrides = { enemies_casting = true, target_is_casting = true, friends_hp = { 62, 72, 85 } } },
    -- Friendly target (ranked): NS.get_friendly_target_entry returns a
    -- friendly unit at 60% (below the 90 threshold) so the 5 healer
    -- FriendlyTarget lanes (disc + holy priest, holy paladin, resto druid +
    -- shaman) become observable. Group stays healthy so the spot-heal lanes
    -- don't steal the frame; hp must stay < 90 and > 0.
    { name = "friendly_target", overrides = { friendly_target_hp = 60, friends_hp = { 100, 100, 100 }, lowest_hp = 100 } },
    -- Vanilla battery sweep (2026-08): vanilla paladin/priest FriendlyTarget
    -- additionally gates on `can_help(s.lowest)` (priest versions also on
    -- _check_pushback — an enemy casting on the player) — with friends at
    -- 100hp the lane is dead. Present the friendly target (60%) alongside a
    -- lowest ally who needs help and a casting enemy so the vanilla gates
    -- pass; additive for TBC (never-shrink).
    { name = "friendly_target_low", overrides = { friendly_target_hp = 60, friends_hp = { 60, 100, 100 }, lowest_hp = 60, enemies_casting = true, target_is_casting = true } },
    -- Vanilla battery sweep (2026-08): priest holy/discipline Fade scans
    -- GetEnemiesInRange for an enemy whose get_target() is the player (the
    -- TBC sibling added a threat_pct/threat_status gate the vanilla files
    -- don't have). enemies_target_me makes the scan return one such enemy.
    { name = "enemies_target_me", overrides = { enemies_target_me = true, hp = 40, player_hp = 40 } },
    -- Healer (c) close-out (2026-08-09): the 13 TBC healer category-(c)
    -- never-lanes, mirroring the WotLK fixture campaign (battery fixtures
    -- only, no spec-file matcher changes). is_solo defaults true in the
    -- battery; holy solo-DPS lanes also need a healthy group so the
    -- solo_damage_enabled safe_hp gate (lowest < 88) can't veto them.
    { name = "holy_last_resort",       overrides = { friends_hp = { 10, 70, 85 } } },
    { name = "holy_jow_boss",          overrides = { target_hp = 100, buff_remains_map = { [20166] = 5 } } },
    { name = "holy_jol_boss",          overrides = { target_hp = 100, buff_remains_map = { [20165] = 5 } } },
    { name = "holy_solo_execute",      overrides = { target_hp = 8, friends_hp = { 96, 97, 98 } } },
    { name = "holy_solo_judge",        overrides = { buff_remains_map = { [20154] = 5 }, friends_hp = { 96, 97, 98 } } },
    { name = "holy_solo_aoe",          overrides = { enemy_count = 4, enemies_count = 4, friends_hp = { 96, 97, 98 } } },
    { name = "smite_solo_renew",       overrides = { hp = 15, player_hp = 15 } },
    { name = "shadow_holy_nova",       overrides = { setting_overrides = { shadow_combat_mode = "aoe" }, enemy_count = 4, enemies_count = 4 } },
    { name = "resto_lightning_shield", overrides = { setting_overrides = { restoration_shield_type = "lightning" } } },
    { name = "resto_chain_lightning",  overrides = { enemy_count = 4, enemies_count = 4, friends_hp = { 96, 97, 98 } } },
    { name = "resto_travel_reposition", overrides = { is_moving = true, in_combat = false, target_distance = 30 } },
    { name = "resto_lifebloom_bloom",  overrides = { friends_hp = { 100, 70, 85 }, lifebloom = { index = 1, stacks = 3, remains = 0.6 } } },
    { name = "enemy_buffed",     overrides = { enemy_buffed = true } },
    { name = "me_casting",       overrides = { me_casting = true, friends_hp = { 25, 60, 80 }, lowest_hp = 25 } },
    { name = "battle_stance",    overrides = { stance = 1 } },
    { name = "defensive_stance", overrides = { stance = 2 } },
    { name = "berserker_stance", overrides = { stance = 3 } },
    { name = "alliance",         overrides = { faction = "Alliance" } },
    { name = "pet_low",          overrides = { pet_hp = 25 } },
    { name = "pet_dead",         overrides = { pet_hp = 0, pet_dead = true } },
    { name = "friends_damaged",  overrides = { friends_hp = { 40, 60, 80 }, lowest_hp = 40 } },
    { name = "out_of_combat",    overrides = { in_combat = false }, no_target = true },
    { name = "ooc_buffs",        overrides = { in_combat = false }, no_target = true },
    { name = "pvp",              overrides = { is_pvp = true } },
    { name = "leveling",         overrides = { level = 25, player_level = 25, is_leveling = true } },
    -- Form scenarios (druid): cat/bear/moonkin/travel put the spec into the
    -- matching form so form-gated strategies become reachable.
    { name = "cat_form",            overrides = { form = 3, energy = 60, combo_points = 3 } },
    { name = "cat_form_5cp",        overrides = { form = 3, energy = 60, combo_points = 5 } },
    { name = "cat_form_low_energy", overrides = { form = 3, energy = 25, combo_points = 4, mana_pct = 30 } },
    { name = "cat_form_low_energy_5cp", overrides = { form = 3, energy = 25, combo_points = 5 } },
    { name = "cat_mangle_up",       overrides = { form = 3, energy = 80, combo_points = 2, buffs_up = true } },
    { name = "cat_stealth",         overrides = { form = 3, is_stealthed = true, combo_points = 0, in_combat = false, buffs_up = true } },
    -- (2026-08-11): map-aware stealth opener — buffs_up marks EVERY debuff up
    -- (pounce/faerie-fire remains 20), which self-blocks PounceOpener and
    -- FaerieFireStealthLock ('debuff already up' gates). This scenario puts
    -- ONLY the PROWL buff in the map (9913, cat_vanilla PROWL_BUFF), so
    -- buff_up(PROWL) is true (stealth) while pounce/ff remains read 0 and
    -- the opener lanes can fire.
    { name = "cat_stealth_clean",   overrides = { form = 3, buff_remains_map = { [9913] = 1 }, combo_points = 0, energy = 90, in_combat = false } },
    { name = "cat_stealth_pvp",     overrides = { form = 3, is_stealthed = true, combo_points = 0, in_combat = false, is_pvp = true } },
    { name = "cat_burst",           overrides = { form = 3, should_burst = true, combat_time = 3 } },
    { name = "cat_short_ttd",       overrides = { form = 3, target_ttd = 2, ttd = 2, target_hp = 20, combo_points = 5, energy = 60 } },
    { name = "cat_execute",         overrides = { form = 3, target_hp = 15, ttd = 4, combo_points = 5, energy = 25, has_potions = true } },
    { name = "cat_emergency",       overrides = { form = 3, energy = 8, combo_points = 2, mana_pct = 40 } },
    { name = "cat_gap",             overrides = { form = 3, target_distance = 15, energy = 70 } },
    { name = "cat_2target",         overrides = { form = 3, enemy_count = 2, enemies_count = 2, energy = 70, combo_points = 3 } },
    { name = "cat_target_casting",  overrides = { form = 3, target_is_casting = true, energy = 60, combo_points = 3 } },
    -- W3.3 druid wotlk (2026-08-13): resto_wotlk WildGrowth now gates on
    -- INJURED ALLIES (context.party_injured_count >= 2) instead of
    -- enemy_count — the old gate could never fire in the single-boss raid
    -- fight Wild Growth exists for. No other spec/lane reads
    -- party_injured_count, so the override is additive-safe.
    { name = "druid_wotlk_wildgrowth", overrides = { party_injured_count = 3, lowest_hp = 55, mana_pct = 90, friends_hp = { 55, 70, 85 }, friend_class = 11 } },
    -- W3.4 balance_wotlk (2026-08-13): lunar-phase Eclipse spell-switch — the
    -- Starfire lane reads eclipse_lunar (48518, buff_remains_map-aware NS.buff_up)
    -- mirroring the pinned wowsims APL's Starfire-on-lunar gate; the scenario
    -- proves the lunar-phase lane (Starfire) fires when eclipse_lunar is up,
    -- the mirror of the solar-phase Wrath pin in
    -- test_balance_wotlk_dsl_priority.lua. 48518 is balance-scoped; no other
    -- spec reads it, so the buff map is additive-safe. (Solar phase = Wrath:
    -- solar eclipse 48517 buffs Wrath; lunar phase = Starfire: lunar eclipse
    -- 48518 buffs Starfire — the W3.4 addendum documents the interpretation.)
    { name = "balance_eclipse_lunar", overrides = { in_combat = true, buff_remains_map = { [48518] = 5 } } },
    -- Vanilla battery sweep (2026-08): bear BashInterrupt is a DSL strategy
    -- with required_form="bear" + target_is_casting + target_interruptible;
    -- no scenario combined form=1 with a casting target (cat_target_casting
    -- uses form 3), so the lane was structurally dead.
    { name = "bear_target_casting", overrides = { form = 1, target_is_casting = true, rage = 50 } },
    -- Vanilla battery sweep (2026-08): subtlety Ambush needs stealth_up
    -- (buff_remains_map 1784) AND the opener auto-resolving to "ambush" — the
    -- constant-true try_interrupt stub makes is_caster_target always true in
    -- the battery, so the auto-resolve always picks garrote and Ambush stays
    -- unreachable (pinned as expected-absence; see the vanilla pin comment).
    { name = "stealth_ambush", overrides = { buff_remains_map = { [1784] = 10 }, target_class = 1 } },
    -- Vanilla sweep (2026-08): fury Overpower fires only inside a dodge window
    -- (fury_vanilla:302 reads state.overpower_window, derived from
    -- target:get_dodge_chance() at :181-185). The mock target had no
    -- get_dodge_chance, so the window was structurally false. The dodge_proc
    -- scenario drives it via target_dodge_chance; only fury_vanilla reads it.
    { name = "dodge_proc", overrides = { in_combat = true, target_dodge_chance = 5, rage = 40 } },
    -- Vanilla sweep (2026-08): holy AbolishDisease is the pre-emptive branch
    -- of the cure pair — it fires only when CureDisease is NOT ready
    -- (holy_vanilla:616). on_cd { [528] = 5 } (CureDisease) models the real
    -- live state (Cure just cast, on CD) while AbolishDisease (552) stays
    -- ready; only priest CureDisease reads id 528, so no other spec's lanes
    -- are affected. Since the 2026-08-13 spell_ready forwarding (import_helpers
    -- now delegates to the bank-aware ns.spell_ready), this scenario fires the
    -- pre-emptive AbolishDisease lane in BOTH eras (TBC holy_vanilla's sibling
    -- gates on the disease flag and fires via friends_afflicted instead).
    { name = "holy_cure_on_cd", overrides = { in_combat = true, on_cd = { [528] = 5 }, mana_pct = 80 } },
    { name = "cat_pvp_interrupt",   overrides = { form = 3, is_pvp = true, target_is_casting = true, energy = 60, combo_points = 3 } },
    { name = "pvp_ooc",             overrides = { in_combat = false, is_pvp = true } },
    { name = "bear_form",           overrides = { form = 1, rage = 50 } },
    { name = "bear_low_self",       overrides = { form = 1, rage = 60, hp = 15 } },
    { name = "bear_aoe",            overrides = { form = 1, rage = 60, enemy_count = 4, enemies_count = 4 } },
    { name = "moonkin_form",        overrides = { form = 2, mana_pct = 90 } },
    { name = "travel_form",         overrides = { form = 4, is_moving = true, in_combat = false, target_distance = 28 } },
    -- Enemy-buffed + PvP: purge / Shiv purge / Mass Dispel lanes.
    { name = "purge_buffed",        overrides = { enemy_buffed = true, is_pvp = true } },
    -- Dead pet, out of combat: Revive Pet / pet summon lanes.
    { name = "pet_dead_ooc",        overrides = { pet_hp = 0, pet_dead = true, in_combat = false }, no_target = true },
    -- No pet at all (never summoned): Call Pet / demon summoning lanes.
    { name = "pet_absent",          overrides = { in_combat = false }, no_target = true, no_pet = true },
    -- Destro pet-preference summons: SummonFelhunter/SummonVoidwalker/
    -- SummonFelguard only fire when destro_pet_preference is explicitly set to
    -- that pet (auto mode resolves to imp/succubus only). One scenario per
    -- pref so each lane is observable; no_target + in_combat=false match the
    -- OOC summon gates (dead/absent pet via pet_dead_ooc/pet_absent above).
    { name = "destro_pet_felhunter",  overrides = { in_combat = false, setting_overrides = { destro_pet_preference = "felhunter" } }, no_target = true, no_pet = true },
    { name = "destro_pet_voidwalker", overrides = { in_combat = false, setting_overrides = { destro_pet_preference = "voidwalker" } }, no_target = true, no_pet = true },
    { name = "destro_pet_felguard",   overrides = { in_combat = false, setting_overrides = { destro_pet_preference = "felguard" } }, no_target = true, no_pet = true },
    -- SummonSuccubus (the last (a) warlock lane): fires only when the pref is
    -- explicitly "succubus" (auto resolves to imp via the Incinerate-learned
    -- heuristic), so the succubus-pref scenario makes it observable.
    { name = "destro_pet_succubus",  overrides = { in_combat = false, setting_overrides = { destro_pet_preference = "succubus" } }, no_target = true, no_pet = true },
    -- Low rage: warrior executes / rage-gated finishers under pressure.
    { name = "low_rage",            overrides = { rage = 15 } },
    -- Burst windows: DamagePotion / cooldown lanes gated on should_burst.
    -- has_potions added (triage upgrade): DamagePotion lanes gate on
    -- context.has_damage_potion, which only has_potions=true sets — without it
    -- the potion lane was invisible in every spec (9 DamagePotion never-lanes).
    { name = "burst",               overrides = { should_burst = true, buffs_up = true, has_potions = true } },
    -- Gap close: warrior Charge / Intercept / sprint lanes need range.
    -- Vanilla battery sweep (2026-08): fury_vanilla Intercept gates on
    -- `not s.in_melee_range` but the gap scenarios set target_distance=15
    -- without flipping in_melee_range (base ctx true) — the lanes were
    -- contradictory-dead. prot_vanilla Intercept additionally needs is_pvp +
    -- berserker stance, so berserker_gap gains is_pvp (no other scenario had
    -- the combo).
    { name = "gap_close",           overrides = { target_distance = 15, in_melee_range = false } },
    { name = "berserker_gap",       overrides = { stance = 3, target_distance = 15, in_melee_range = false, is_pvp = true } },
    { name = "pull_gap",            overrides = { in_combat = false, target_distance = 15, in_melee_range = false } },
    -- Triage battery upgrades (2026-08-07): scenario COMBINATIONS the battery
    -- could not previously express — stance+execute (Recklessness), defensive+
    -- low-HP (ShieldWall), rage-capped (RageDumpSafetyNet), poison-stack
    -- (Envenom lanes), berserker+AoE (fury BattleStance), and melee-range
    -- targets (keeps me:get_distance-bound FrostNova/ConeOfCold reachable).
    { name = "berserker_execute",   overrides = { stance = 3, target_hp = 8, ttd = 6, target_ttd = 6 } },
    -- Recklessness (fury) refuses to fire below 20s TTD AND before 60s combat
    -- without a major-CD window — needs berserker + LONG fight, not execute.
    { name = "berserker_long",      overrides = { stance = 3, combat_time = 90, ttd = 60, target_ttd = 60 } },
    { name = "defensive_low_self",  overrides = { stance = 2, hp = 15 } },
    -- Close-out triage (2026-08-08, ranked #2): prot Disarm needs is_pvp
    -- (ACTIONS requires_pvp) + disarm_class_ok (target:get_class() melee id
    -- in DISARM_CLASS_IDS {1,2,4,7} — class 1 = warrior). The matcher's
    -- on_burst trigger needs disarm_burst_name (via enemy_buffed), so we use
    -- the cheaper `disarm_trigger = "always"` setting override instead — this
    -- avoids enemy_buffed entirely, so no purge-buffed lane collateral (the
    -- purge_buffed scenario keeps its exclusivity). target_class is only
    -- applied here, so warlock ShadowWard (needs 5/9) and hunter ViperSting
    -- middleware stay silent in every other scenario.
    { name = "pvp_disarm", overrides = { is_pvp = true, target_class = 1, setting_overrides = { disarm_trigger = "always" } } },
    -- Campaign ranked-(b) #1 (2026-08-08): warlock ShadowWard (affl + demo)
    -- needs hp <= shadow_ward_hp (default 70) + a shadow-caster target class
    -- in SHADOW_CASTER_CLASS_IDS {5,9} = Priest, Warlock
    -- (shared/warlock_shadow_ward_sylvanas.lua pcall's target:get_class()
    -- when enemy_shadow_caster is unset) + is_pvp for affliction's
    -- use_group_aware gate (demo skips it). Reuses the pvp_disarm
    -- target_class -> target:get_class() mechanism; class 9 is NOT in prot
    -- DISARM_CLASS_IDS {1,2,4,7}, so Disarm stays blocked here, and hunter
    -- ViperSting's string-class guard skips numeric ids.
    { name = "shadow_caster", overrides = { is_pvp = true, target_class = 9, hp = 50, player_hp = 50 } },
    -- Campaign follow-up (2026-08-08): shaman/enhancement TotemicCall. The
    -- real get_position contract is a vec3 TABLE (verified vs auto_loot /
    -- targeting / EaxESP), so the matcher's my_pos.x reads are CORRECT; the
    -- battery path needs a totem present (totem_active -> get_totem_info
    -- have_totem) + a distant totem object in the visible scan (totem_far ->
    -- mock at 30,30 = 1800 sq > 400 yd-sq gate).
    { name = "totem_far",     overrides = { totem_active = true, totem_far = true, visible_enemies = true } },
    -- Close-out triage (2026-08-08, ranked #3): prot Intervene needs is_group
    -- (protection:757) + is_pvp (warrior_intervene_pvp_only default true) + a
    -- low-hp in-range ally via the party scan (state.lowest_allied). The
    -- scenario presents the _friend(30, 5) ally through ctx.party_members —
    -- the ENGINE surface prot reads since the 2026-08-11 bare-value-read fix
    -- (the old ns.get_party_members mock stubs were never-defined members and
    -- are gone). The me + ally get_position mocks satisfy the 25-yard gate.
    { name = "group_ally_low", overrides = { is_group = true, is_pvp = true, party_members = { _friend(30, 5) } } },
    -- Defensive-casting PvP (warrior/rogue triage 2026-08-08): prot Pummel +
    -- SpellReflection read state.target_is_casting, which prot derives from
    -- target:is_casting_spell() (wired in build_scenario_target — arms reads
    -- ctx.target_is_casting, so only prot was blocked). SpellReflection's
    -- ACTIONS metadata is requires_pvp = true, so the scenario carries is_pvp
    -- (a tank reflecting under spell pressure); stance 2 + hp 15 mirror the
    -- defensive_low_self family. The is_pvp + hp flags incidentally clear
    -- rogue combat/subtlety Blind (hp 15 ≤ combat_blind_hp 40 / subtlety 35) —
    -- the pvp_low_hp combo from the triage, same gate family, not a leak.
    { name = "defensive_casting", overrides = { stance = 2, target_is_casting = true, hp = 15, player_hp = 15, is_pvp = true } },
    { name = "rage_capped",         overrides = { rage = 100 } },
    { name = "poison_stacks",       overrides = { debuff_stacks = 5, debuff_aura_ids = { 27187, 27186, 26968, 26967, 25349, 25347, 11356, 11355, 11354, 11353, 11352, 11351, 11350, 11349, 2819, 2837, 2818, 2835 }, buffs_up = true, combo_points = 5, energy = 60 } },
    { name = "berserker_aoe",       overrides = { stance = 3, enemy_count = 4, enemies_count = 4 } },
    -- Melee-range target: keeps me:get_distance-bound self-peel lanes reachable
    -- (mage FrostNova / ConeOfCold need dist<=10 AND the AoE cone gate needs
    -- enemy_count>=2, so this carries both).
    { name = "target_melee",        overrides = { target_distance = 5, enemy_count = 3, enemies_count = 3 } },
    -- Undead target (healer triage upgrade): creature-type 6 (undead) + 2
    -- enemies. Unblocks the ShackleUndead x4 (priest), TurnEvil x2,
    -- Exorcism + HolyWrath (prot), and Ret_HolyWrath_AoE lanes — all gate on
    -- state.target_creature_type in DEMON_OR_UNDEAD {3,6}; the HolyWrath lanes
    -- additionally need enemy_count >= 2. (Docs labeled this "classification=3";
    -- the specs read get_creature_type, and undead is 6.)
    { name = "undead_target",      overrides = { target_creature_type = 6, enemy_count = 2, enemies_count = 2, setting_overrides = { use_exorcism = true } } },
    -- Multi-DoT spread (ranked #1): the PRIMARY target carries the DoTs
    -- (debuff_remains_map → unit-aware debuff_up/debuff_remains) while the
    -- second enemy is clean, so warlock find_dot_target / shadow
    -- _find_multidot_target / balance _multidot_enemy_list pick the peer.
    -- ttd 30 selects Curse of Agony in auto curse mode (select_curse: ttd < 60
    -- → agony). balance spreads share this via balance_multidot_enabled.
    { name = "multidot",         overrides = { enemy_count = 2, enemies_count = 2, target_hp = 60, ttd = 30, target_ttd = 30, debuff_remains_map = { [27216] = 8, [27218] = 8, [30405] = 8, [30911] = 8, [27215] = 8, [26988] = 8, [27013] = 8 }, setting_overrides = { balance_multidot_enabled = true } } },
    -- shadow MultiDot maintenance (opt-in shadow_multidot_mode=2 via the
    -- settings fixture) — primary has SW:P/VT, peer is clean.
    { name = "shadow_multidot",  overrides = { enemy_count = 2, enemies_count = 2, target_hp = 60, debuff_remains_map = { [25368] = 8, [34917] = 8 }, setting_overrides = { shadow_multidot_mode = 2 } } },
    -- shadow cleave-mode SW:P/VT spread (shadow_combat_mode="cleave" + 3
    -- enemies — the Spread matchers require enemy_count >= 3).
    { name = "shadow_cleave",    overrides = { enemy_count = 3, enemies_count = 3, target_hp = 60, debuff_remains_map = { [25368] = 8, [34917] = 8 }, setting_overrides = { shadow_combat_mode = "cleave" } } },
    -- Low-mana Wand (ranked #3): warlock/affliction Wand fires only when mana
    -- < 30 AND hp < 35 (Life Tap unsafe) AND in_combat — no prior scenario
    -- combined all three. mana_pct 4 (< aff_wand_mana 30), hp 15 (<
    -- LIFE_TAP_SAFETY_HP 35). hp 100 correctly keeps it blocked (prefer Life
    -- Tap → Shadow Bolt), so the lane stays exclusive to this scenario.
    { name = "wand_low_mana",   overrides = { mana_pct = 4, hp = 15 } },
    -- AB-stack conserve (ranked #4): mage/arcane FrostboltConserve fires when
    -- phase == conserve AND ab_stacks >= 3 AND ab_remains > cast_time (~1.0).
    -- Arcane Blast's stack aura (36032) is a SELF BUFF — the spec reads the
    -- BUFF side only (NS.buff_stacks/NS.buff_remains) since 2026-08-11, so
    -- the scenario drives buff_remains_map { [36032] = 4 } (map-first: 4
    -- stacks + 4s remains; the map entry doubles as both values). mana_pct 15
    -- keeps phase conserve: with the ranked-#2 bank max_mana (15000), mtte_burn
    -- ≈ 14 ≥ 5 AND buffs_up=true sets bloodlust_active=true, whose burn-override
    -- needs mana_pct >= 20 — 15 stays under both, so can_burn stays false and
    -- the phase never flips to burn (mana 15 >= 10 also avoids the emergency
    -- branch, and FrostboltConserve has no mana gate).
    { name = "ab_stack_conserve", overrides = { mana_pct = 15, buffs_up = true, buff_remains_map = { [36032] = 4 } } },
    -- W3.3 mage live-fixes (2026-08-13): per-aura scenarios for the fixed
    -- WotLK mage gates. Ids are mage-wotlk-scoped (44545 FoF proc, 42917 Frost
    -- Nova max rank, 44549 Frostfire Bolt debuff, 55360 Living Bomb DoT) — no
    -- TBC-era spec reads them (verified), so no other era's fires_in changes.
    -- The [36032]-stack shape deliberately stays exclusive to ab_stack_conserve:
    -- TBC arcane's FrostboltConserve is pins-exclusive to that scenario
    -- (test_combat_battery_regression.lua), and WotLK ArcaneBarrage (4-stack
    -- dump, W3.3) fires right here through the same map entry.
    { name = "frost_fof_proc", overrides = { in_combat = true, buff_remains_map = { [44545] = 1 } } },
    { name = "frost_nova_freeze", overrides = { in_combat = true, debuff_remains_map = { [42917] = 5 } } },
    { name = "frost_ffb_debuff", overrides = { in_combat = true, debuff_remains_map = { [44549] = 2 } } },
    { name = "leveling_living_bomb_wotlk", overrides = { in_combat = true, debuff_remains_map = { [55360] = 2 } } },
    -- Battle-ready SnD (ranked #5): rogue/combat BladeFlurry needs Slice and
    -- Dice up (SND_BUFF {6774, 5171}) while Blade Flurry itself is DOWN
    -- (13877) — the map-aware ns.buff_up reads buff_remains_map so the two
    -- are independently observable. 3 enemies satisfies the min_targets gate
    -- (combat_blade_flurry_count default 1); cooldowns_enabled defaults true.
    { name = "battle_ready",    overrides = { buff_remains_map = { [6774] = 20, [5171] = 20 }, enemy_count = 3, enemies_count = 3 } },
    -- Settings-modeling (ranked #7): opt-in (a) lanes become observable by
    -- flipping their spec settings via the ctx.settings merge above. Each key
    -- is spec-scoped so shared scenarios never leak into other specs.
    -- auto_dispel: druid balance/cat RemoveCurse (balance reads
    -- ctx.settings.balance_auto_dispel DIRECTLY; cat via cat_auto_dispel).
    { name = "auto_dispel",      overrides = { setting_overrides = { balance_auto_dispel = true, cat_auto_dispel = true } } },
    -- blessings: retri Ret_BlessingKings_Self/Party (both default false); the
    -- party lane's find_ally falls back to self in the battery (candidate_members
    -- returns a number, not a table, so no party scan happens).
    { name = "blessings",        overrides = { setting_overrides = { blessing_of_kings_self = true, blessing_of_kings_party = true } } },
    -- Pre-classified (a) opt-in lanes (focused triage 2026-08-08, warrior/rogue
    -- pass): each previously never-firing lane is gated on a spec setting PLUS
    -- a state the battery's default context can't express. One scenario per
    -- lane, keys spec-scoped so nothing leaks across specs.
    -- fury Overpower: setting + BT/WW on CD (matcher delays when bt_cd/ww_cd
    -- < 1.5 — default context has both at 0, so the lane could never fire even
    -- with the setting flipped). on_cd ids are ACTION.Bloodthirst.ids[1]
    -- (30335) and ACTION.Whirlwind (1680); Battle stance + rage 70 are the
    -- defaults.
    { name = "fury_overpower",  overrides = { setting_overrides = { fury_overpower_weave = true }, on_cd = { [30335] = 6, [1680] = 10 } } },
    -- fury SwingDesync: setting + swing_until >= DESYNC_SLAM_WINDOW (1.6);
    -- default swing 0.5 < 1.6 blocks it. 2.0 also clears the bt/ww reserve +
    -- rage-cap windows (rage 70 default, no on_cd).
    { name = "fury_swing_desync", overrides = { setting_overrides = { fury_swing_desync = true }, swing_until = 2.0 } },
    -- kebab SunderMaintain: setting (read DIRECTLY from ctx.settings by
    -- kebab's settings_for) + defensive stance (matcher requires
    -- context.stance == DEFENSIVE; default battle 1 blocks it).
    { name = "kebab_sunder",    overrides = { setting_overrides = { sunder_armor_mode = "maintain" }, stance = 2 } },
    -- assn ColdBloodEnvenom: setting + SnD up + 5 deadly-poison stacks
    -- (debuff_aura_ids scoped) + combo 5 / energy 60. SnD must be up while
    -- Cold Blood is NOT (matcher: `if state.has_cold_blood then return false`)
    -- — so the buff_remains_map carries ONLY the SnD ids (6774/5171) and
    -- buffs_up stays false, otherwise Cold Blood looks already-active.
    -- combat_blade_flurry_count = 99 keeps combat's BladeFlurry (whose gate
    -- ALSO reads SnD up via the same 6774/5171 ids) exclusive to battle_ready
    -- — target_count 1 < 99 blocks it here; assassin never reads that key.
    { name = "cold_blood",      overrides = { setting_overrides = { assassin_cold_blood_auto = true, combat_blade_flurry_count = 99 }, buff_remains_map = { [6774] = 20, [5171] = 20 }, debuff_stacks = 5, debuff_aura_ids = { 27187, 27186, 26968, 26967, 25349, 25347, 11356, 11355, 11354, 11353, 11352, 11351, 11350, 11349, 2819, 2837, 2818, 2835 }, combo_points = 5, energy = 60 } },
    -- assn ThistleTea: setting + energy <= 40 + combo <= 3 (energy_low shape;
    -- the setting alone flips it on, verified match=true in energy_low).
    { name = "thistle_tea",     overrides = { setting_overrides = { assassin_thistle_tea = true }, energy = 30, combo_points = 0 } },
    -- hit_cap_deficit: the HitCapPriority lanes (combat/arms/fury — identical
    -- matcher: state.hit_cap_rating_needed - context.hit_rating, fires when
    -- the deficit exceeds 30) need a non-nil hit_rating. Caps: melee specs 142
    -- (hunter_ranged/paladin_melee also 142); mage_caster is 202 — still
    -- clears at rating 50 (deficit 152 > 30).
    { name = "hit_cap_deficit", overrides = { hit_rating = 50 } },
    -- mutilate_daggers: assassin Mutilate's has_daggers needs a dagger in BOTH
    -- hands (assn:234-240 reads get_equipped_item_id for MAIN_HAND/OFF_HAND +
    -- the is_dagger map). equipped_daggers=true makes the mock return 776 for
    -- both slots; energy 90 default keeps energy_low false (cost 60 gate).
    { name = "mutilate_daggers", overrides = { equipped_daggers = true } },
    -- Remaining (a) opt-in gates (2026-08-08 close-out): four scenarios clear
    -- the last 6 opt-in lanes. Keys are spec-scoped (arms reads
    -- use_sunder_armor; fury reads sunder_mode; arms+prot read
    -- use_commanding_shout; combat/subtlety read their own expose key).
    -- arms SunderArmor needs BATTLE stance (its build_action has
    -- required_stance = STANCE.BATTLE since 2026-08-12 — arms plays in Battle
    -- and no strategy swaps to Defensive for Sunder, so the old DEFENSIVE
    -- gate made the lane fire only from a non-default stance); prot
    -- SunderArmor is unaffected (dev_ready gate, no use_sunder_armor read).
    { name = "arms_sunder",     overrides = { setting_overrides = { use_sunder_armor = true }, stance = 1 } },
    -- Vanilla-era mirror (2026-08-12): arms_vanilla's SunderArmor build_action
    -- still requires DEFENSIVE stance (vanilla files are their own sweep), so
    -- the era-shared arms_sunder (stance=1 since the TBC BATTLE-stance fix)
    -- cannot fire the vanilla lane. This scenario re-supplies stance=2 for
    -- the vanilla battery only; arms_sylvanas ignores it (BATTLE required).
    { name = "arms_sunder_vanilla", overrides = { setting_overrides = { use_sunder_armor = true }, stance = 2 } },
    -- fury SunderArmor: sunder_mode "maintain" (default "off" blocks;
    -- "maintain" has no rage gate — the "low" branch requires rage >= 60,
    -- which rage 70 would satisfy anyway; min_rage 15 build_action passes).
    { name = "fury_sunder",     overrides = { setting_overrides = { sunder_mode = "maintain" } } },
    -- CommandingShout x2: arms (matcher: setting + rage >= 10, battle stance
    -- fine) and prot (DSL `{ type = "setting" }` condition — evaluated via
    -- spec_kit.setting, which reads ctx.settings first; has_commanding_shout /
    -- has_battle_shout falsy defaults + commanding_ready true all pass).
    { name = "commanding_shout", overrides = { setting_overrides = { use_commanding_shout = true } } },
    -- ExposeArmor x2: combat (expose_armor_ready true via spell_ready +
    -- expose_assigned from combat_expose_assigned) + subtlety (setting + combo
    -- 5 default >= 4 + ttd 60 default >= 20 + no sunder).
    { name = "expose_armor",    overrides = { setting_overrides = { combat_expose_assigned = true, subtlety_expose_assigned = true } } },
    -- Warlock opt-in fixture (ranked #11): the 9 CurseOf* lanes are gated on
    -- select_curse() which only returns elements/recklessness/weakness when
    -- warlock_curse_mode is set to that value (auto mode resolves to
    -- agony/doom). One scenario per mode so each lane is observable; the mode
    -- key is warlock-scoped so no other spec reads it. All 9 probe-verified
    -- to fire with the mode override.
    { name = "curse_mode_elements",     overrides = { setting_overrides = { warlock_curse_mode = "elements" } } },
    { name = "curse_mode_recklessness", overrides = { setting_overrides = { warlock_curse_mode = "recklessness" } } },
    { name = "curse_mode_weakness",     overrides = { setting_overrides = { warlock_curse_mode = "weakness" } } },
    -- Warlock affliction CurseFirst (guide-divergence opt-in, 2026-08-13):
    -- aff_curse_first (default false) lifts the selected curse ABOVE the DoT
    -- setup at combat start. Auto curse mode at long TTD resolves to Doom, so
    -- this reuses the long_ttd shape (ttd 120 clears the CoD 62s sanity gate)
    -- plus the setting flip. Curse mode is left auto ON PURPOSE: flipping it
    -- to elements/recklessness/weakness would fire the regular curse lanes in
    -- a second scenario and break their fires-in(1) exclusivity pins
    -- (test_warlock_opt_in_regression.lua); hp stays 100 so Healthstone
    -- (pinned to low_self_healthstone) is untouched. For non-warlock specs
    -- this ctx is identical to long_ttd (aff_curse_first is warlock-scoped),
    -- so no other spec's fires_in changes.
    { name = "aff_curse_first", overrides = { in_combat = true, ttd = 120, target_ttd = 120, setting_overrides = { aff_curse_first = true } } },
    -- Warlock Healthstone (affl/demo/destro, shared warlock_healthstone
    -- helper): the matcher gates on healthstone_hp > 0 AND hp <= threshold
    -- (default 0 -> never). hp 25 + healthstone_hp 40 makes all three
    -- observable; probe-verified. (low_self hp 15 already exists; this adds
    -- the warlock-specific threshold setting.)
    { name = "low_self_healthstone", overrides = { hp = 25, setting_overrides = { healthstone_hp = 40 } } },
    -- High-threat context (ranked #12): Soulshatter (shared
    -- warlock_soulshatter helper) gates on `(threat_pct or 0) >= 80` OR
    -- `has_aggro`; priest Fade (threshold 80) and rogue Feint (90) are the
    -- same threat-drop family and may legitimately clear too (realistic —
    -- they were only invisible because the battery never set threat).
    -- hunter FeignDeath reads state.threat_level via hunter_core, so it does
    -- NOT clear from these ctx keys (verified below).
    -- NOTE (2026-08-13): threat_pct stays 95. priest/leveling Fade gates on
    -- threat_pct >= 99, and the TBC Soulshatter lanes are pinned fires-ONLY-
    -- in-threat_high (test_threat_context_regression.lua) — any scenario
    -- with threat >= 99 fires Soulshatter in a second scenario and breaks
    -- that exclusivity contract. The leveling Fade lane is therefore
    -- classified (c) mock-limitation (see
    -- docs/never_strategy_triage_vanilla_2026-08-13.md).
    { name = "threat_high", overrides = { threat_pct = 95, threat_status = 3, has_aggro = true } },
    -- Retri seal choice = "command" (seal_preference drives should_use_blood →
    -- preferred_damage_seal): Ret_SealCommand_Primary fires when the Command
    -- seal is ABSENT; Ret_HotC_Opener_Judge needs the Crusader seal up (map
    -- 27158) with combat_time < 8 and no Crusader debuff on the target.
    { name = "seal_command_apply", overrides = { setting_overrides = { seal_preference = "command" }, buff_remains_map = { [27158] = 5 }, combat_time = 3 } },
    -- Command seal ACTIVE + a second melee enemy (context.enemies fixture):
    -- Ret_JudgeSecondary_CommandCleave (swing in the judge band, mana >= 30).
    -- Vanilla battery sweep (2026-08): ret CommandCleave reads has_command
    -- from SEAL_COMMAND_BUFF = {20920,...20375} — 27170 (Judgement of Command
    -- TBC id) alone never matched, so the vanilla lane was dead; 20375 is the
    -- vanilla top Command rank.
    { name = "seal_command_active", overrides = { setting_overrides = { seal_preference = "command" }, buff_remains_map = { [27170] = 5, [20375] = 5 }, swing_until = 0.9, enemy_count = 2, enemies_count = 2, mana_pct = 40 } },
    -- Hunter toggles: AdaptiveRotation x3 (use_adaptive_rotation + the
    -- NS.HunterAdaptive stub), Volley + ExplosiveTrap (use_volley /
    -- use_explosive_trap; 4 enemies for the AoE gates).
    { name = "hunter_toggles",   overrides = { setting_overrides = { use_adaptive_rotation = true, use_volley = true, use_explosive_trap = true }, enemy_count = 4, enemies_count = 4 } },
    -- Arcane burn phase (ranked #2): the battery's get_max_power now returns
    -- the bank max_mana (15000 default) so mage/arcane's burn phase is
    -- mathematically reachable (mtte_burn ≈ 50.6 ≥ 5). can_burn additionally
    -- needs available_mana ≥ burn_mana_needed = 760·ttd/1.5 = 30400 at ttd 60;
    -- available = current_mana + (regen+49)·ttd/2 = 45000 + 1470 → the
    -- scenarios drive current_mana via player_mana 45000 (base ctx defaults
    -- player_mana 100 → available 1570 < 30400 → can_burn stays false in
    -- every other scenario, so phase stays conserve there). ArcanePower
    -- (12042) on cd makes PresenceOfMind's ap_on_cd sync gate pass; IcyVeins
    -- NOT on cd so its own lane fires. Unblocks ArcanePower + PresenceOfMind
    -- + IcyVeins. NOTE: kept LAST in SCENARIOS — arcane's build_state
    -- mutates a module-level phase that carries across scenarios (real engine
    -- semantics: phase is a state machine), so placing the burn scenarios
    -- after hunter_toggles means no later scenario inherits a leaked burn
    -- phase. (buffs_up scenarios like burst also reach burn via the
    -- bloodlust_active override — realistic, not a leak.)
    { name = "burn_ready",      overrides = { player_mana = 45000, mana_pct = 100, ttd = 60, target_ttd = 60, on_cd = { [12042] = 180 } } },
    -- Burn + IcyVeins (12472) on cd > 3s: ColdSnapIVReset fires (its matcher
    -- needs icy_veins_remains > 3 AND ColdSnap ready); IcyVeins itself
    -- self-blocks here (its matcher requires IV not on cd), so each lane
    -- stays exclusive to its own scenario.
    { name = "burn_coldsnap",   overrides = { player_mana = 45000, mana_pct = 100, ttd = 60, target_ttd = 60, on_cd = { [12042] = 180, [12472] = 180 } } },
    -- =========================================================================
    -- WotLK Phase-1 triage (2026-08-09): the 38 remaining never-lanes after the
    -- resource/cooldown accessor fixes (149 -> 65 -> 38). ALL 38 are (c) mock/
    -- shape gaps — zero (d) dead lanes and zero order divergences, so no spec
    -- file changes; these scenarios + the DK stub upgrades clear the lanes.
    -- =========================================================================
    -- DK runic power (runic_power >= 60 DancingRuneWeapon blood; >= 100
    -- DeathCoil unholy). Base ctx defaults runic_power 50 — one flag short.
    { name = "dk_runic",        overrides = { runic_power = 100 } },
    -- DK unholy SummonGargoyle: boss flag truthy AND runic_power >= 60.
    -- W3.3 register: unholy build_state now reads the REAL dispatcher field
    -- context.target_is_boss (main_sylvanas.lua:1287 — the old ctx.is_boss
    -- was phantom). W3.4 mock-tightening (2026-08-13): the scenario now
    -- drives ONLY the real field; the legacy is_boss compat override is
    -- removed, and the unholy_wotlk:127 legacy context.is_boss read was
    -- DELETED in the W3.5 integration wave (mirrors arms_wotlk.lua:143).
    -- (Gargoyle is a boss-target DPS CD — realistic shape.)
    { name = "dk_boss",         overrides = { target_is_boss = true, runic_power = 100 } },
    -- DK ghoul pet commands (W3.3 register, unholy): the new GhoulGnaw /
    -- GhoulLeap lanes must be demonstrably fireable — has_pet presents a live
    -- ghoul (see the pets block: ctx.has_pet now materializes ctx.pet for
    -- non-pet-profile classes), target_casting drives Gnaw's real gate
    -- (context.target_casting, main_sylvanas.lua:759), target_distance 15
    -- drives Leap's gap-close gate (>= 8, main_sylvanas.lua:877).
    { name = "dk_ghoul_gnaw",   overrides = { has_pet = true, in_combat = true, target_casting = true } },
    { name = "dk_ghoul_leap",   overrides = { has_pet = true, in_combat = true, target_distance = 15 } },
    -- DK disease refresh (Pestilence x3 — blood/unholy/leveling): all three
    -- gate on frost_fever_remains > 0 AND blood_plague_remains > 0 with one
    -- below 3s (blood/unholy) or diseases_up (leveling: ff>0 or bp>0). The
    -- debuff_remains_map mechanism (frost fever 55095, blood plague 55078)
    -- marks the primary target. NOTE: the DK files install the REAL
    -- aoe_hit_volume (leveling/unholy Pestilence gate on aoe_target_meets(2)),
    -- which overrides the battery's always-true stub — its ctx fallback
    -- consults enemy_count/enemies_count, so the scenario must carry 2+ real
    -- enemies or the spread lane stays 0. Blood's Pestilence (no aoe gate)
    -- clears from the disease map alone.
    { name = "dk_disease",      overrides = { debuff_remains_map = { [55095] = 1, [55078] = 1 }, enemy_count = 3, enemies_count = 3 } },
    -- DK blood DeathStrike (W3.3 register): self-heal at hp < 80, gated on
    -- Frost Fever > 3s (the disease-uptime guard — DeathStrike burns the frost
    -- rune IcyTouch needs, so firing at hp<80 with FF down starves the
    -- disease). hp 60 + FF 5s is the ONLY shape that clears the lane:
    -- dk_disease (FF 1s) deliberately keeps blocking it (guard active) and no
    -- other scenario combines hp<80 with FF>3. 55095 = Frost Fever (DK-only).
    { name = "dk_death_strike", overrides = { hp = 60, debuff_remains_map = { [55095] = 5 } } },
    -- DK EmpowerRuneWeapon x2 (frost + unholy): both gate on total runes ready
    -- == 0; the rune bank defaults 2/2/2/0 (6 total), so an all-zero ready map
    -- is the only shape where the CD fires. rune_state is a new bank key
    -- consumed by the rune_manager stub getters.
    { name = "dk_runes_depleted", overrides = { rune_state = { ready = { blood = 0, frost = 0, unholy = 0, death = 0 } } } },
    -- DK presence switch x3 (blood Presence, unholy Presence, frost
    -- FrostPresence): all go through presence_manager.get_optimal_presence /
    -- should_switch_presence. optimal_presence is a new bank key; with it set
    -- and no presence buff up (state.presence nil/1), each lane fires here.
    { name = "dk_presence",     overrides = { optimal_presence = "blood" } },
    -- Druid leveling feral opt-in: CatForm gates on druid_leveling_feral=true
    -- (and druid_leveling_bear=false, the default) + in_combat + form ~= cat.
    -- The settings fixture makes this opt-in lane observable (mirrors the TBC
    -- (a) close-out: use_sunder_armor etc.).
    { name = "lvl_feral",       overrides = { setting_overrides = { druid_leveling_feral = true } } },
    -- Druid leveling bear opt-in: DireBearForm gates on druid_leveling_bear
    -- = true + in_combat + form ~= bear.
    { name = "lvl_bear",        overrides = { setting_overrides = { druid_leveling_bear = true } } },
    -- Druid leveling cat abilities x6 (Rip/FerociousBite/Rake/MangleCat/
    -- Shred/Claw): all gate `form == "cat"` (STRING — leveling_wotlk compares
    -- strings, unlike the numeric form ids TBC specs use). The battery context
    -- passes ctx.form through verbatim, so a string override lands in
    -- state.form and the string gates match. combo_points 4 satisfies both the
    -- >= 4 finishers (FerociousBite) and < 5 builders (MangleCat/Shred/Claw);
    -- the W3.3 5-CP Rip spend (2026-08-13) needs the sibling 5-CP scenario —
    -- default 5 blocks the builders, default 0 blocks the finishers.
    { name = "lvl_cat_form",    overrides = { form = "cat", combo_points = 4 } },
    { name = "lvl_cat_form_5cp", overrides = { form = "cat", combo_points = 5 } },
    -- Druid leveling bear abilities x3 (Swipe/Lacerate/MangleBear): form ==
    -- "bear" string; Swipe additionally needs enemy_count >= 2.
    { name = "lvl_bear_form",   overrides = { form = "bear", enemy_count = 3, enemies_count = 3 } },
    -- Druid resto Swiftmend: target_hp < 50 AND (rejuvenation_remains > 0 or
    -- regrowth_remains > 0). Rejuv id 26982 (first in REJUVENATION_BUFF) in
    -- the buff_remains_map marks the primary target as carrying the HoT;
    -- target_hp 30 satisfies the low-health gate. (buffs_up=false elsewhere so
    -- the lane stays silent in every other scenario.)
    { name = "resto_swiftmend", overrides = { target_hp = 30, buff_remains_map = { [26982] = 1 } } },
    -- Hunter survival ExplosiveShotProc (W3.3 live fix, 2026-08-13): the
    -- production lane reads the Lock and Load proc via NS.buff_up over
    -- LOCK_AND_LOAD_BUFF {56344,56343,56342} (context.lock_and_load is never
    -- set by production). The buff_remains_map entry for the max-rank aura
    -- 56344 drives the REAL API path. The map also flips the plain
    -- ExplosiveShot lane off (its gate is lock_and_load falsy), so the proc
    -- lane is the only Explosive Shot that fires here. No other scenario
    -- presents 56344.
    { name = "surv_lockload",   overrides = { in_combat = true, buff_remains_map = { [56344] = 1 } } },
    -- Hunter BestialWrath CD gate (W3.3 live fix, 2026-08-13): BM + leveling
    -- now derive bestial_wrath_ready from NS.cooldown_remains(ACTION.
    -- BestialWrath). This scenario puts 19574 on CD via the real on_cd bank,
    -- proving the gate is genuinely cooldown-driven (the lane fires in
    -- `standard` where the bank is empty). 19574 is hunter-scoped, so no other
    -- spec's gates change.
    { name = "hunter_wotlk_bw_cd", overrides = { in_combat = true, on_cd = { [19574] = 20 } } },
    -- Mage fire FireBlast (scorch-window weave): gates on scorch_cast_time > 0
    -- (number) AND state.ttd <= cast_time. scorch_cast_time is a new bank key;
    -- ttd 2 <= cast_time 3 makes the lane fire (base ttd 60 > 3 blocks it
    -- everywhere else). FireBlast is a real weaving lane, not a dead one.
    -- Vanilla battery sweep (2026-08): fire_vanilla Fireball gates on 5 Scorch
    -- stacks (scorch_stacks = get_debuff_stacks(target, SCORCH_DEBUFF {22959}))
    -- and has no clearcasting early-consume like the TBC sibling — debuff_stacks
    -- + the vanilla scorch id make the lane observable.
    { name = "fire_scorch",     overrides = { scorch_cast_time = 3, ttd = 2, target_ttd = 2, debuff_stacks = 5, debuff_aura_ids = { 22959 } } },
    -- Mage leveling ConjureManaGem: in_combat falsy + mana_pct < 80. The
    -- existing out_of_combat scenario has mana_pct 100 (never < 80); this is
    -- the OOC + low-mana combo (like low_mana but OOC — low_mana keeps
    -- in_combat=true, and the lane requires falsy).
    { name = "ooc_low_mana",    overrides = { in_combat = false, mana_pct = 70 } },
    -- Priest leveling Shadowform opt-in: eaxpriestlvl_use_shadowform=true +
    -- in_combat falsy + shadowform_up falsy. Settings fixture, like lvl_feral.
    { name = "lvl_shadowform",  overrides = { in_combat = false, setting_overrides = { eaxpriestlvl_use_shadowform = true } } },
    -- Shaman ready flags x4 (elem Bloodlust + ElementalMastery + FireElemental,
    -- enh Bloodlust): W3.3 moved the gates to REAL API —
    -- state.*_ready = NS.spell_ready(ACTION.*) (cooldown_remains-aware, ready
    -- unless on_cd), so the lanes fire through the production path in every
    -- scenario. W3.4 mock-tightening (2026-08-13): the phantom ctx overrides
    -- (bloodlust_ready / elemental_mastery_ready / fire_elemental_ready —
    -- never set by the dispatcher) are removed; this scenario remains as the
    -- regression row (the lanes must fire on the default ctx).
    { name = "shaman_ready",    overrides = {} },
    -- Shaman enh totem/proc lanes x2: LightningBolt gates maelstrom_stacks
    -- >= 5 — enh reads NS.buff_stacks(me, MAELSTROM_WEAPON_BUFF {53817,..}),
    -- which is buff_remains_map-aware, so the map entry [53817] = 5 supplies
    -- the stacks (buffs_up=false elsewhere keeps the lane silent).
    -- W3.4 mock-tightening (2026-08-13): CallOfTheElements now gates on the
    -- REAL water-slot occupancy (NS.get_totem_info — the phantom
    -- ctx.water_totem_remains key was never set by the engine and is removed).
    { name = "enh_procs",       overrides = { buff_remains_map = { [53817] = 5 } } },
    -- Shaman resto triage x2: W3.3 moved both gates to REAL API — ChainHeal
    -- gates on context.party_injured_count (engine field) + lowest_hp < 85 +
    -- mana >= 25; ManaTideTotem gates on NS.spell_ready(ManaTideTotem) +
    -- mana < 30. W3.4 mock-tightening (2026-08-13): the phantom overrides
    -- (injured_count / mana_tide_ready — never set by the dispatcher) are
    -- removed; the real overrides (lowest_hp 50, mana_pct 27) keep the
    -- ManaTideTotem mana band observable here (ChainHeal fires in
    -- resto_party_injured).
    { name = "resto_triage",    overrides = { lowest_hp = 50, mana_pct = 27 } },
    -- Wave 3.3 (2026-08-13) REAL-FIELD scenarios: the WotLK shaman fixes read
    -- production fields (party_injured_count, NS.get_totem_info slot
    -- occupancy) instead of the phantom/injected keys above, so these two
    -- scenarios prove the fixed lanes fire through the REAL API path:
    --   * resto ChainHeal gates on context.party_injured_count (the engine
    --     field) — 2 injured + lowest_hp 50 + mana 27 fires it.
    --   * enh Fire Nova (61657) requires an ACTIVE fire totem in WotLK —
    --     totem_active presents one through the bank-aware NS.get_totem_info,
    --     and the 3-enemy count clears the AoE gate.
    { name = "resto_party_injured", overrides = { party_injured_count = 2, lowest_hp = 50, mana_pct = 27 } },
    { name = "enh_fire_totem_up",    overrides = { enemy_count = 3, enemies_count = 3, totem_active = true } },
    -- W3.3 priest wotlk REAL-FIELD scenarios (2026-08-13): the four priest
    -- *_wotlk.lua fixes read production fields (context.mana_pct,
    -- context.party_injured_count) instead of phantom/mock-only paths, so these
    -- scenarios prove the newly-activated lanes fire through the real API:
    --   * shadow Shadowfiend (34433, APL priority 1): fires when in combat and
    --     mana < 60. mana 50 sits above the TBC shadow sibling's <= 45 gate and
    --     below the 60 threshold, so ONLY the WotLK lane fires here (TBC
    --     shadow Shadowfiend stays observable only via its own bands).
    --   * holy CircleOfHealing (48089, APL slot 3): fires on 2+ injured party
    --     members (context.party_injured_count) with the lowest ally below 85
    --     and mana >= 20 — the same engine field resto_wotlk WildGrowth uses.
    { name = "priest_wotlk_shadowfiend",    overrides = { in_combat = true, mana_pct = 50, player_mana = 5000, player_mana_pct = 50 } },
    { name = "priest_wotlk_circle_healing", overrides = { party_injured_count = 2, lowest_hp = 60, mana_pct = 90, friends_hp = { 60, 75, 85 }, friend_class = 11 } },

    -- (c) close-out batch 2 (2026-08-09): the 18 remaining TBC (c) lanes.
    -- druid/balance: HurricaneAoE (aoe + mana + Barkskin active so the
    -- ready-Barkskin deferral gate passes); RebirthBattleRez (dead player
    -- ally via find_dead_party_ally).
    { name = "hurricane_aoe",   overrides = { enemy_count = 4, enemies_count = 4, mana_pct = 60, buff_remains_map = { [22812] = 10 } } },
    { name = "rebirth_dead_ally", overrides = { in_combat = true, dead_ally = true } },
    -- druid/bear: Swipe (aoe + rage + short TTD so the Lacerate pre-stack gate
    -- passes); EnrageCombat (rage-starved, non-boss, single target).
    { name = "bear_swipe_aoe",  overrides = { form = 1, in_combat = true, enemy_count = 4, enemies_count = 4, rage = 40, ttd = 5 } },
    { name = "bear_enrage",     overrides = { form = 1, in_combat = true, rage = 10, hp = 100, enemy_count = 1, ttd = 60 } },
    -- druid/cat: ClawFallback (Mangle unlearned); MangleFiller (not behind so
    -- the Shred-preference gate passes).
    { name = "cat_claw_fallback", overrides = { form = 3, combo_points = 0, energy = 60, not_learned = { [33983] = true } } },
    { name = "cat_mangle_filler", overrides = { form = 3, combo_points = 0, energy = 60, is_behind = false } },
    -- hunter: BM Trinket (combat + equipped trinket + slot1 mode); MM
    -- InCombatAimedShot (fresh-combat opener, no Serpent Sting).
    { name = "bm_trinket",      overrides = { in_combat = true, has_trinket = true, setting_overrides = { trinket_mode = "slot1" } } },
    { name = "mm_aimed_opener", overrides = { in_combat = true, combat_time = 0.2 } },
    -- MM Aimed Shot weave (guide-divergence opt-in, 2026-08-13): mm_aimed_weave
    -- (default false) unlocks the in-combat Aimed Shot weave lane. The battery's
    -- settings fixture defaults unset, so without this scenario the lane would
    -- be a never-lane; flipping the opt-in keeps the never=16 contract
    -- non-vacuous. combat_time 5 clears the <=0.5s opener window owned by
    -- InCombatAimedShot; the swing-window gate is lenient (no ms_until_auto
    -- stub on the HunterClipTracker mock) and mana 90 > the 20 floor.
    { name = "mm_aimed_weave",  overrides = { in_combat = true, combat_time = 5, setting_overrides = { mm_aimed_weave = true } } },
    -- paladin/protection: AvengingWrath (use_cooldowns enabled, ttd above the
    -- 15s expiry gate); LayOnHands (self below the 10% threshold).
    { name = "prot_cd_window",  overrides = { in_combat = true, ttd = 60, setting_overrides = { use_cooldowns = true } } },
    { name = "prot_low_self",   overrides = { in_combat = true, hp = 5, player_hp = 5 } },
    -- paladin/retribution: cleanse/purify self + ally (player-debuff map).
    -- (589 is a magic DoT in discipline_vanilla's DISPEL_MAGIC_DEBUFF_IDS,
    -- so this scenario also drives the vanilla discipline DispelMagic lane via
    -- the map-aware ns.has_debuff).
    { name = "ret_cleanse_self", overrides = { player_debuff_remains_map = { [1330] = 5, [589] = 5 } } },
    -- shaman/elemental: ChainHeal (group injured); ElementalMastery (burst
    -- window + enabled); TotemicCall (moving + totems up).
    { name = "elem_group_injured", overrides = { in_combat = true, group_injured = true } },
    { name = "elem_burst_cd",   overrides = { in_combat = true, should_burst = true, setting_overrides = { elemental_use_elemental_mastery = true } } },
    { name = "elem_totemic_call", overrides = { in_combat = true, is_moving = true, has_totems = true } },
    -- shaman/elemental guide divergences (Phase 2.2a, opt-in pattern (a)):
    -- ChainLightningSingleTarget gates on elemental_cl_single_target (default
    -- false) AND the AoE gate FAILING (aoe_target_meets bank key flipped
    -- false — the regular ChainLightning lane stays silent here); the
    -- bank-aware stub defaults true so no other scenario changes.
    { name = "elem_cl_st",      overrides = { in_combat = true, aoe_target_meets = false, setting_overrides = { elemental_cl_single_target = true } } },
    -- FlameShockMaintain gates on elemental_fs_maintain (default false) AND
    -- flame_remains in the (1, 3) maintain window — 25457 (FS top rank) at 2s
    -- sits above the clip lane's <=1s cutoff, below the 3s refresh threshold.
    { name = "elem_fs_maintain", overrides = { in_combat = true, debuff_remains_map = { [25457] = 2 }, setting_overrides = { elemental_fs_maintain = true } } },
    -- shaman/enhancement: EarthShock interrupt (target casting in the kick
    -- window); ShamanisticRage (low mana defensive use + the per-CD toggle
    -- setting enabled — the DSL condition requires it, the battery settings
    -- fixture defaults to unset).
    { name = "enh_interrupt",   overrides = { in_combat = true, target_is_casting = true, target_cast_pct = 60 } },
    { name = "enh_low_mana",    overrides = { in_combat = true, mana_pct = 30, player_mana_pct = 30, ttd = 60, setting_overrides = { enhancement_cd_shamanistic_rage = true } } },

    -- (a) opt-in close-out (2026-08-10): the 14 remaining TBC category-(a)
    -- never-lanes are ALL gated on spec settings the battery's
    -- setting_overrides fixture can drive (plus a few state shapes). One
    -- scenario per lane, keys spec-scoped so nothing leaks across specs.
    -- druid/balance MoonkinForm: setting + OUT of combat (DSL
    -- `{ type = "in_combat", invert = true }` at balance:695) + spell ready.
    -- NOTE: named moonkin_form_OPTIN — a pre-existing `moonkin_form`
    -- scenario (form=2, mana_pct=90) already exists for the form-sync
    -- scenarios; build_scenario returns the FIRST match, so reusing the
    -- name would silently shadow this one.
    { name = "moonkin_form_optin", overrides = { in_combat = false, setting_overrides = { balance_moonkin_auto = true } } },
    -- druid/balance InnervateHealer (Pattern 13 split, P2.2b 2026-08-13):
    -- the smart-Innervate party scan (balance build_state, 2s throttle —
    -- battery clock 102+ clears it) reads NS.GetPartyMembers() and hands the
    -- first non-self healer-class member to the InnervateHealer lane. This
    -- scenario presents a priest ally (class 5 via the _friend class id) at
    -- bank mana 25 <= balance_innervate_mana(30)+5; the in_combat + group
    -- context comes from the base ctx (druid is a healer-class profile so
    -- ctx.is_group is true; druid_group_aware_utility defaults true).
    { name = "balance_innervate_healer", overrides = { in_combat = true, mana_pct = 25, player_mana_pct = 25, party_members = { _friend(100, 30, 5) } } },
    -- druid/balance Wrath filler divergence (P2.2b 2026-08-13):
    -- balance_wrath_conserve is an opt-OUT (default true = mana-tier gating;
    -- WrathFiller already fires at low mana). This scenario flips the opt-out
    -- at high mana so the divergence lane is observable: WrathFiller must
    -- ALSO fire when the gate is removed (aggressive parse filler).
    { name = "balance_wrath_divergence", overrides = { in_combat = true, mana_pct = 90, player_mana_pct = 90, setting_overrides = { balance_wrath_conserve = false } } },
    -- druid/bear Barkskin: setting + in combat + NOT bear form (TBC: casting
    -- it in bear breaks the form) + hp in (15, barkskin_hp=55] (15 reserved
    -- for Frenzied Regen) + no barkskin buff.
    { name = "bear_barkskin",   overrides = { in_combat = true, form = 0, hp = 40, player_hp = 40, setting_overrides = { bear_use_barkskin = true } } },
    -- druid/cat RipTrick: cat_use_rip_trick + would_rip_fire (ttd >= floor) +
    -- is_cat + mana >= 8 + combo >= 1 + rip NOT up + energy in the
    -- [RIP_COST=30, MANGLE_COST=40) window (energy 35 sits inside; next tick
    -- 55 exceeds the Mangle floor, so only the current-window branch passes).
    { name = "cat_rip_trick",   overrides = { in_combat = true, form = 3, combo_points = 1, energy = 35, mana_pct = 50, ttd = 30, target_ttd = 30, setting_overrides = { cat_use_rip_trick = true } } },
    -- druid/cat ShredTrick: cat_use_shred_trick + is_cat + behind + a bleed
    -- up (rip map 27008 -> bleed_active) + mana >= 16 + energy >= SHRED_COST
    -- (42; 80 leaves 58 >= MANGLE_COST after a tick) + next_tick_in > 1.0
    -- (energy_time_to_x 2.0, see _scenario_me) + combo < 5.
    { name = "cat_shred_trick", overrides = { in_combat = true, form = 3, is_behind = true, combo_points = 2, energy = 80, mana_pct = 50, debuff_remains_map = { [27008] = 8 }, energy_time_to_x = 2.0, setting_overrides = { cat_use_shred_trick = true } } },
    -- mage/frost x3: pure setting toggles (frost:400/432/440 read
    -- context.settings.<key> == true directly).
    { name = "frost_fire_blast",   overrides = { setting_overrides = { frost_use_fire_blast = true } } },
    { name = "frost_scorch",       overrides = { setting_overrides = { frost_use_scorch = true } } },
    { name = "frost_arcane_missiles", overrides = { setting_overrides = { frost_use_arcane_missiles = true } } },
    -- paladin/protection AvengerShield: setting + avenger_ready (spell_ready
    -- stub) + no CC nearby + normal in-combat mode (has_valid_enemy_target +
    -- in_combat, both base defaults).
    { name = "prot_avenger_shield", overrides = { in_combat = true, setting_overrides = { prot_avenger_shield = true } } },
    -- paladin/protection HammerOfWrath (DSL): prot_hammer_of_wrath + ready +
    -- target_hp <= prot_hammer_of_wrath_hp (default 20).
    { name = "prot_hammer_wrath",   overrides = { target_hp = 15, ttd = 30, target_ttd = 30, setting_overrides = { prot_hammer_of_wrath = true } } },
    -- paladin/protection Judgement: prot_judgement + ready + damage mode
    -- needs a damage seal up (Seal of Righteousness buff 27155 -> has_seal;
    -- mana 100 > jow_threshold+5 so wisdom mode is off).
    { name = "prot_judgement",      overrides = { buff_remains_map = { [27155] = 30 }, setting_overrides = { prot_judgement = true } } },
    -- paladin/protection SealOfCommandAoE: prot_seal_of_command + 3+ enemies
    -- + no seal up (no buff map) + spell ready + 3s throttle (module-local
    -- stamp starts 0; battery now 100 -> passes).
    { name = "prot_seal_command",   overrides = { enemy_count = 4, enemies_count = 4, setting_overrides = { prot_seal_of_command = true } } },
    -- paladin/retribution Consecration: use_consecration + not twist-window
    -- + not mana_emergency + mana >= 35 + 3+ enemies (aoe_self_meets stub).
    { name = "ret_consecration",    overrides = { enemy_count = 4, enemies_count = 4, mana_pct = 60, setting_overrides = { use_consecration = true } } },
    -- paladin/retribution Ret_Consecration_ManaDump: consecration_single_target
    -- + not mana_emergency + mana >= 75 (single-target; no enemy gate).
    { name = "ret_consec_dump",     overrides = { mana_pct = 80, setting_overrides = { consecration_single_target = true } } },
    -- W3.4 paladin wotlk mana-chain fixture (2026-08-13): retribution_wotlk
    -- DivinePlea gates on state.mana_pct < 40 (divine_plea_up falsy +
    -- divine_plea_cd <= 0 are the base defaults). mana_pct = 35 drives the
    -- lane through the REAL chain — context.mana_pct (dispatcher-set,
    -- main_sylvanas.lua:795) → state.mana_pct — with the mock unit now
    -- mana_pct-less (me:get_mana_percentage is a W3.4 tripwire), so any
    -- surviving sole-source read errors loudly instead of silently reading 100.
    { name = "ret_divine_plea",     overrides = { in_combat = true, mana_pct = 35 } },
    -- shaman/enhancement GraceOfAirTotemTwist: totem_twisting (default true)
    -- + in combat + not moving + gcd 0 + mana >= 40 + GoA ready + WF buff up
    -- (25587 > 2.0) + GoA buff expiring (25359 < 5.0) + no recent GoA cast
    -- (battery now_ms 100000 >> 1500ms window).
    { name = "enh_goa_twist",       overrides = { in_combat = true, mana_pct = 60, buff_remains_map = { [25587] = 4, [25359] = 4 } } },
    -- (b) close-out (2026-08-10): PvP mega-scenario. is_pvp + melee_on_you +
    -- enemy_healer + enemy_caster + cc_target + target_fleeing + a low-hp
    -- fleeing target drive the 9 PvP-gated lanes (balance Cyclone /
    -- EntanglingRoots / NaturesGrasp, affliction HowlOfTerror / CurseExhaustion
    -- / CurseTongues, retribution HammerWrath_FleeingPvP, arcane + fire
    -- Polymorph via cc_target).
    { name = "pvp_melee",          overrides = { is_pvp = true, melee_on_you = true, enemy_healer = true, enemy_caster = true, cc_target = true, target_fleeing = true, target_hp = 15 } },
    -- Resto PvP pressure: enemies_in_range feeds ns.GetEnemiesInRange so
    -- scan_pvp_pressure fills melee_pressure_count / enemy_healer / root_target
    -- → BearFormFocusedByMelee, NaturesGraspMelee, CycloneEnemyHealer,
    -- EntanglingRootsMelee.
    { name = "pvp_pressure_resto", overrides = { is_pvp = true, hp = 30, enemies_in_range = { melee = 1, healer = 1 } } },
    -- Fear tremor: fear_nearby drives TremorTotem in elemental/enhancement/
    -- restoration (each reads context.fear_nearby).
    { name = "fear_nearby",        overrides = { fear_nearby = true } },
    -- Snare: self_rooted_snared + a root-snare player debuff (122 ∈ COMMON_SNARES)
    -- drive Blink ×2, retribution BlessingOfFreedom Self + Ally, holy
    -- BlessingOfFreedomSnare (entry_needs_freedom → has_any_debuff → the
    -- player-debuff map via has_target_debuff fallback to me).
    { name = "snare_self",         overrides = { self_rooted_snared = true, player_debuff_remains_map = { [122] = 5 }, snared_friend = true } },
    -- SW:D CC break: a damage-breakable CC on the player (Polymorph 118 ∈
    -- BREAKABLE_CC_DEBUFFS) drives the has_breakable_cc fallback path of
    -- swd_cc_break_matches (offensive_dispel.is_breakable_cc_active →
    -- ns.debuff_up → debuff_remains_map).
    { name = "shadow_cc_break",    overrides = { player_debuff_remains_map = { [118] = 5 } } },
    -- BM Misdirection: opening-seconds window (combat_time ≤ 6) + the
    -- use_misdirection setting.
    { name = "bm_misdirection",    overrides = { combat_time = 2, setting_overrides = { use_misdirection = true } } },
    -- Bear Challenging Roar: dedicated toggle (bear_use_challenging_roar) +
    -- 3+ enemies (bear:610-616).
    { name = "bear_challenging_roar", overrides = { form = 1, enemy_count = 4, enemies_count = 4, setting_overrides = { bear_use_challenging_roar = true } } },
    -- Enh AutoAttack: the battery's is_auto_attacking stub defaults true
    -- (legacy posture); flip it so the lane's `not auto-attacking` gate passes.
    { name = "enh_autoattack",     overrides = { is_auto_attacking = false } },
    -- Demo Seduction: succubus pet (has_pet) with Lash of Pain 27274 known
    -- (pet_spells) + PvP. Starshards needs no scenario: the per-spec
    -- RACE_OVERRIDES loads smite as night elf (race 4), so it fires in the
    -- standard scenarios.
    { name = "pvp_succubus",       overrides = { is_pvp = true, has_pet = true, pet_spells = { 27274 } } },
    -- Threat-family close-out (2026-08-10): bear Growl needs a target-of-target
    -- unit that is a player/healer (target.get_target defaults to ctx.me → the
    -- already-tanking gate always blocks); now > TAUNT_COOLDOWN_WINDOW (8) so
    -- the throttle passes (state.now defaults 0 → 0 - 0 < 8 always throttles).
    { name = "bear_growl",         overrides = { form = 1, now = 1000, target_get_target = _friend(50, 30, nil, { role = "healer" }) } },
    -- prot peel: one party ally that is BOTH low-HP (<=35 → low_hp_ally, BoP)
    -- AND threatened (threat_status >= 2 → ally_threatened, RighteousDefense);
    -- target_classification feeds RighteousDefense's elite gate.
    { name = "prot_party_peel",    overrides = { target_classification = 1, party_members = { _friend(30, 5, nil, { threat_status = 2 }) } } },
    -- holy BoP focused-ally: heal-scan entry hp <= 38 + threat_status >= 2
    -- (entry_needs_protection holy:326-333) → protection_target set.
    { name = "holy_bop_focused",   overrides = { friends_hp = { 30, 70, 85 }, friendly_target_threat = 2 } },
    -- BM FeignDeath: fd_mode defaults "off" (use_threat_drop off); the setting
    -- override flips it so should_feign_death(threat 2, "high_threat") passes.
    { name = "bm_feign_death",     overrides = { threat_level = 2, setting_overrides = { fd_mode = "high_threat" } } },
    -- shadow DevouringPlague: NOT race-gated — the (b) audit's race-5-load
    -- claim was wrong (shadow never binds race at require time; only smite
    -- does). The real gate is _engaged_with_player (shadow:743-754), which
    -- needs target_hp < 100. No RACE_OVERRIDES extension needed.
    { name = "shadow_devouring_plague", overrides = { target_hp = 80 } },
    -- (b) PvP/OOC scenario family (2026-08-13, campaign phase 0.2): two
    -- context banks that run for EVERY class/spec like the rest of the
    -- battery. pvp_arena models an in-combat arena match — is_pvp + is_group
    -- + a hostile target (the base-ctx target: has_valid_enemy_target /
    -- has_target true, target_hp 100); ooc_idle models an out-of-combat idle
    -- state — in_combat false + no target. These are the two context shapes
    -- the 10 (b) correctly-silent lanes are documented against (OOC-only pull
    -- openers, OOC-only tracking/travel, OOC conjure, mounted/encounter
    -- safety nets); running them through the battery proves each lane either
    -- demonstrably fires (reclassify out of (b)) or stays correctly silent.
    { name = "pvp_arena", overrides = { is_pvp = true, is_group = true } },
    { name = "ooc_idle",  overrides = { in_combat = false }, no_target = true },
    -- WotLK warlock live-fix fixture (wave 3.3, 2026-08-13): the production
    -- debuff tables now carry the WotLK max-rank ids FIRST (Corruption 47813 /
    -- UA 47843 / CoA 47864 / Immolate 47811 / Haunt 59164). This scenario
    -- marks those EXACT ids on the primary target at 8s with low mana (25) +
    -- healthy HP (90): the DoT refresh lanes gate off (remains 8 >= 3), the
    -- Immolate-up shape satisfies Conflagrate, and the new LifeTap sustain
    -- lanes fire (mana below threshold, HP above the safety floor) — all via
    -- the REAL ids a max-level WotLK client applies. The ids are WotLK-scoped
    -- (TBC-era debuff tables contain none of them), so the TBC battery's
    -- never=13 pins are untouched; for non-warlock specs the keys are inert.
    { name = "wotlk_warlock_lifetap", overrides = { in_combat = true, mana_pct = 25, hp = 90, player_hp = 90, debuff_remains_map = { [47813] = 8, [47843] = 8, [47864] = 8, [47811] = 8, [59164] = 8 } } },
    -- WotLK rogue live-fix fixture (wave 3.3, 2026-08-13): assassination_wotlk
    -- Envenom now gates on Deadly Poison stacks (>= 3) tracked with the REAL
    -- WotLK application ids (57970/57969 — wowhead-verified Deadly Poison
    -- IX/VIII). This scenario marks those exact ids at 5 stacks with 5 combo
    -- points + energy 60: the Envenom lane fires via the real
    -- NS.get_debuff_stacks path (envenom buff down). The ids are WotLK-scoped
    -- (no TBC/vanilla debuff table contains them), so the TBC never=13 pins
    -- and the TBC-id poison_stacks scenario are untouched; for non-rogue
    -- specs the keys are inert.
    { name = "wotlk_rogue_dp_stacks", overrides = { in_combat = true, combo_points = 5, energy = 60, debuff_stacks = 5, debuff_aura_ids = { 57970, 57969 } } },
    -- WotLK rogue live-fix fixture (wave 3.3, 2026-08-13): subtlety_wotlk
    -- Ambush now gates on is_behind (real NS.is_behind_target) inside the
    -- Shadow Dance window (buff 51713). This scenario presents the Shadow
    -- Dance buff via the map (51713, map-first) with energy 60 — the Ambush
    -- lane fires through the real buff_up + is_behind path. 51713 is
    -- rogue-scoped (Shadow Dance is WotLK-only), so no TBC/vanilla spec's
    -- gates change; the buffs_up fallback still marks the buff up in the
    -- buffs_up/pull/burst scenarios, so the lane stays observable there too.
    { name = "wotlk_sub_dance_ambush", overrides = { in_combat = true, buff_remains_map = { [51713] = 5 }, energy = 60, combo_points = 0 } },
    -- =========================================================================
    -- Wave 1.4 leveling-vanilla fixtures (2026-08-13): the 9 leveling_vanilla
    -- specs joined the battery manifest (40 specs total). After the
    -- spell-table seeds (DruidSpells/.../WarriorSpells ladders), the remaining
    -- never-lanes are driven by these scenario shapes. Each is era-shared
    -- (every scenario runs in every era) — TBC never-count preservation was
    -- verified lane-for-lane after the batch (see the triage addendum).
    -- druid/leveling Claw: cat form + in combat + energy >= 45 + NOT behind
    -- (shred-preference gate reads the bank-aware NS.is_behind_target) + Rake
    -- remains > 3 (rake-refresh preference gate reads the primary-target
    -- debuff map; 9904 is the vanilla Rake rank-6 id in RAKE_DEBUFF).
    { name = "cat_lev_claw", overrides = { form = 3, energy = 60, combo_points = 0, is_behind = false, debuff_remains_map = { [9904] = 10 } } },
    -- shaman/leveling EarthShock + FrostShock: gated on the
    -- leveling_default_shock setting (default "flame") — one scenario per
    -- opt-in value (settings fixture, same pattern as the warlock curse modes).
    { name = "lev_shock_earth", overrides = { setting_overrides = { leveling_default_shock = "earth" } } },
    { name = "lev_shock_frost", overrides = { setting_overrides = { leveling_default_shock = "frost" } } },
    -- priest/leveling VampiricEmbrace: needs shadowform up (has_buff over
    -- SHADOWFORM_BUFF {15473} — map-only reader, so the buff_remains_map
    -- entry drives it) and VE NOT active (no 15286 entry in the map).
    { name = "priest_ve", overrides = { buff_remains_map = { [15473] = 30 } } },
    -- paladin/leveling Exorcism + HammerOfWrath: damage lanes gated on a live
    -- seal (has_any_seal via ANY_SEAL_BUFF — 20375 is the vanilla Command
    -- top rank) + undead/demon target (Exorcism) or execute range (HoW).
    -- target_hp 15 satisfies HoW's <= 20; creature-type 6 the Exorcism gate.
    { name = "pal_lev_seal", overrides = { target_creature_type = 6, target_hp = 15, buff_remains_map = { [20375] = 30 } } },
    -- rogue/subtlety Ambush: stealth-up + behind + opener_preference
    -- explicitly "ambush". The auto-resolve path is battery-dead (constant-
    -- true try_interrupt makes is_caster_target true → auto picks garrote),
    -- but the SETTING path (option("opener_preference")) is expressible —
    -- same settings fixture as stealth_opener's cheap_shot override.
    { name = "ambush_opener", overrides = { buff_remains_map = { [1784] = 10 }, setting_overrides = { opener_preference = "ambush" } } },
    -- warrior/leveling PvPCCGate: the gate strategy fires when a CC'd enemy
    -- is within the 15-yd radius (CCGateDB.is_any_nearby_enemy_under_cc,
    -- bank-driven on enemy_cc_nearby) + any AoE spell learned (lenient mock)
    -- + use_pvp_cc_gating default true. PvP context + enemies.
    { name = "pvp_cc_gate", overrides = { is_pvp = true, enemy_count = 3, enemies_count = 3, enemy_cc_nearby = true } },
    -- paladin/leveling Cleanse: OOC self-cure — needs in_combat false + a
    -- dispel-type affliction on self (has_dispel_type_debuff reads the
    -- friends_afflicted bank flag; the TBC healer cure/cleanse lanes all gate
    -- in_combat=true, so the OOC shape fires nothing in the TBC era).
    { name = "ooc_afflicted", overrides = { in_combat = false, friends_afflicted = true }, no_target = true },
    -- WotLK Phase-3 paladin sweep (2026-08-13): retribution SealSwitch — the
    -- opt-in (ret_seal_switch, default true) seal ST/AoE switch lane fires when
    -- Seal of Vengeance is up with 2+ enemies (adds arrived): SoV is re-cast
    -- to CANCEL (WotLK seal mechanic, no GCD) and SealOfCommand applies on the
    -- next GCD. buff_remains_map { [31801] = 5 } marks SoV up (map-first); no
    -- other scenario presents SoV, so the lane fires exclusively here. The
    -- reverse direction (SoC up + 1 enemy) is battery-shadowed by
    -- seal_command_active (2 enemies); both share the same cancel code path.
    { name = "ret_seal_switch", overrides = { in_combat = true, enemy_count = 3, enemies_count = 3, buff_remains_map = { [31801] = 5 }, setting_overrides = { ret_seal_switch = true } } },
    -- protection Holy Shield charge-refresh path: the shield is UP (48927 in
    -- the map) while the battery's buff_points returns nil (charges read 0 <=
    -- floor 2) — the lane must fire WITH the buff up, proving the charge floor
    -- drives the refresh and not just the absent-buff branch (which already
    -- fires in standard). 48927 is paladin-scoped; no other spec reads it.
    { name = "prot_hs_charges", overrides = { in_combat = true, buff_remains_map = { [48927] = 30 } } },
}

-- SoD-era scenario battery (W4.3, 2026-08-14): the full shared scenario set
-- (SoD lanes fire if they fire ANYWHERE, so every shared shape stays useful)
-- plus SoD-specific shapes that drive the REAL sod_context enrich outputs
-- through the map-aware mocks: buff_remains_map → metamorphosis_active /
-- maelstrom_stacks / S&D / Blade Dance remains, form → in_cat_form /
-- in_bear_form, debuff_remains_map → flame_shock / serpent / DoT remains,
-- debuff_stacks + debuff_aura_ids → poison / sunder stacks,
-- party_injured_count → injured_count, totem_active → fire/water_totem_active,
-- friendly_target_hp (+ debuff map) → the heal_target enrich blocks
-- (Riptide / Lifebloom / Weakened Soul on ctx.lowest_unit).
-- Shared entries are referenced, not copied: run_spec never mutates them.
M.SCENARIOS_SOD = {}
for _, sc in ipairs(M.SCENARIOS) do M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] = sc end
-- Warlock-tank Metamorphosis (10 of 11 tank_sod strategies gate on
-- metamorphosis_active). 47241 is the WotLK meta aura the SoD client's rune
-- mechanic reuses (sod_context_sylvanas.lua METAMORPHOSIS_BUFF). No shared
-- scenario presents it, so the meta-gated lanes fire exclusively here.
-- Superset shape (like elite_low_self): carries enemy 3 (ShadowCleave's
-- enemy_count >= 2), target_hp 20 (DrainLife's <= 35, via the enrich's
-- target_hp_pct alias) and pet_hp 25 (HealthFunnel's pet_hp_pct <= 35 with a
-- live pet). The meta-active Metamorphosis lane itself fires elsewhere
-- (standard — it gates on meta NOT active).
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_meta", overrides = { buff_remains_map = { [47241] = 60 }, enemy_count = 3, enemies_count = 3, target_hp = 20, target_ttd = 6, ttd = 6, pet_hp = 25 } }
-- Druid tank (bear) form: the shared set only drives cat form (form=3 in
-- cat_mangle_filler); tank_sod's bear-gated lanes (Lacerate, Maul) and
-- restoration's form-cancel lanes need form=1 → in_bear_form via the enrich.
-- LacerateRefresh additionally needs the LACERATE debuff (414644) up at
-- 0 < remains < 3 — same scenario, refresh window 2s.
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_bear_form", overrides = { form = 1, debuff_remains_map = { [414644] = 2 } } }
-- Rogue combat/tank poison-stack gates (PoisonedKnife: combo < 5 + stacks
-- >= 4 + energy <= 80 — the energy/combo overrides make the knife lane
-- reachable; the stacks bank is id-scoped to the deadly-poison ranks).
-- (deadly-poison ranks mirror combat_sylvanas:54)
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_poison", overrides = { debuff_stacks = 5, debuff_aura_ids = { 27187, 27186, 26968, 26967, 25349, 25347, 11356, 11355, 11354, 11353, 11352, 11351, 11350, 11349, 2819, 2837, 2818, 2835 }, energy = 60, combo_points = 0 } }
-- Shaman elemental/enhancement Flame Shock refresh: FLAME_SHOCK ids
-- (29228 max rank, sod_context_sylvanas.lua) in the primary-target dot map.
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_flame_shock", overrides = { debuff_remains_map = { [29228] = 4 } } }
-- Enhancement/warden Maelstrom-stack burst: MAELSTROM_WEAPON ids (53817 max
-- rank) in the buff map — the enrich falls back to NS.buff_stacks, which is
-- map-aware, so maelstrom_stacks becomes 5. Carries Rockbiter (25485) so the
-- warden's rockbiter-gated MaelstromChainLightning is observable too, and
-- enemy 3 for the chain's enemy_count >= 2 gate.
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_maelstrom", overrides = { buff_remains_map = { [53817] = 5, [25485] = 60 }, enemy_count = 3, enemies_count = 3 } }
-- Warden single-target Maelstrom bolt (stacks 5 + enemy_count == 1 + rockbiter).
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_maelstrom_single", overrides = { buff_remains_map = { [53817] = 5, [25485] = 60 } } }
-- Warden Molten Blast (enemy_count >= 5) + Magma Totem (>= 2 + fire slot
-- free): the shared aoe scenario caps at 4 enemies, so 5 is sod-only; no
-- totem_active key → the get_totem_info bank reports an empty fire slot.
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_molten", overrides = { buff_remains_map = { [25485] = 60 }, enemy_count = 5, enemies_count = 5 } }
-- Warrior dps Berserker Rage: berserker stance (3) + a rage-starved window
-- (matcher gates s.rage < 40 — the rage generator fires when the bar is
-- empty). No shared scenario sets stance 3 (warriors default to battle 1;
-- prot scenarios use defensive 2).
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_berserker", overrides = { stance = 3, rage = 20 } }
-- Warrior tank AoE lanes (Cleave/Shockwave/SweepingStrikes/ThunderClap):
-- tank_warrior's available() requires defensive stance (2) AND the AoE lanes
-- need enemy_count >= 2. No shared scenario combines stance 2 with 2+
-- enemies (elite_* have the enemies but stay battle-stance; prot_filler_cd
-- is stance 2 but single-target).
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_tank_aoe", overrides = { stance = 2, enemy_count = 3, enemies_count = 3 } }
-- Warrior tank Bloodrage (rage < 20 in defensive stance): no shared scenario
-- drops warrior rage below 20 (arms_execute_rage floors at 25).
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_tank_rage_low", overrides = { stance = 2, rage = 15 } }
-- Pet dismissed but NOT dead (hunter + warlock dps Call Pet): OOC with no
-- pet. The shared no_pet scenarios (low_level, pet_absent) present a DEAD
-- pet (pet_dead=true → RevivePet's lane); Call Pet's `not s.pet_dead` gate
-- needs the dismissed state the pet_dismissed branch provides.
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_pet_dismissed", overrides = { in_combat = false }, no_target = true, pet_dismissed = true }
-- Warlock dps MendPet (OOC + live pet at pet_hp_pct <= 35): the shared pet
-- scenarios keep pet_hp at 100; pet_hp 25 presents the mend window.
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_pet_low", overrides = { in_combat = false, pet_hp = 25 } }
-- Hunter Serpent Sting refresh (dps_hunter): SERPENT_STING ids
-- { 25295, 13555 } in the primary-target dot map (shared serpent_refresh
-- uses the TBC max-rank 27016, which the SoD file's id set does not carry).
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_serpent", overrides = { debuff_remains_map = { [25295] = 2, [13555] = 2 } } }
-- Warrior-tank Sunder stacks (tank_warrior): SUNDER ids (engine has_sunder
-- set, main_sylvanas.lua:1294) in the id-scoped stacks bank.
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_sunder", overrides = { debuff_stacks = 3, debuff_aura_ids = { 7386, 7405, 8380, 11596, 11597, 25225 } } }
-- Restoration-shaman Healing Stream (injured_count >= 2 gate via the enrich
-- party_injured_count alias) with a live fire-slot totem (get_totem_info
-- bank) for the warden/resto totem-gated lanes.
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_totem_heal", overrides = { totem_active = true, party_injured_count = 2, lowest_hp = 40, friends_hp = { 40, 60, 80 } } }
-- Priest Weakened Soul on the heal target (PW:S refresh gate in healing_sod):
-- friendly_target_hp presents ctx.lowest_unit (apply_sod_enrich) + the
-- 6788 debuff in the primary-target map.
M.SCENARIOS_SOD[#M.SCENARIOS_SOD + 1] =
    { name = "sod_weakened_soul", overrides = { friendly_target_hp = 60, debuff_remains_map = { [6788] = 3 } } }

-- Scenario-aware player unit: every health/power read reflects the CURRENT
-- scenario numeric values instead of fixed 100s.
local function _scenario_me(profile, ctx)
    local me = _me_unit(profile.class_id or 0)
    me.get_health_percentage = function(self) return ctx.hp or 100 end
    me.get_health = function(self) return (ctx.hp or 100) * 100 end
    -- W3.4 mock-tightening (2026-08-13): me:get_mana_percentage() is NOT a
    -- real game_object/IZI SDK member (the izi unit method is me:mana_pct();
    -- engine path is context.mana_pct / NS.mana_pct). The lenient injection is
    -- REMOVED (tripwire, see _scenario_me) — the W3.4 fixers migrated the
    -- paladin wotlk files (holy/leveling/retribution/protection) to the
    -- context-first chain, and the repo audit found no surviving SOLE-source
    -- reads: every remaining reader is a context-first tail fallback
    -- (priest/shaman/warlock wotlk + affliction_sylvanas + aspect_manager) or
    -- a pcall-guarded tail (druid middleware party-member scan, hunter
    -- target-mana reads) that the tripwire makes inert (same result as the
    -- nil method in production). A survivor would now error loudly per
    -- scenario in the battery report ("dispatch ERR").
    me.get_mana_percentage = function(self)
        error("mock-only member me:get_mana_percentage() removed in W3.4 (behavioral_audit.lua) "
            .. "— production must use context.mana_pct or me:mana_pct() or NS.unit_mana_pct(me)", 2)
    end
    me.is_in_combat = function(self) return ctx.in_combat == true end
    me.get_shapeshift_form_id = function(self)
        -- Coerce string forms (leveling_wotlk scenarios pass form="cat"/"bear")
        -- to 0 (caster) so numeric form-id consumers never see a string.
        local f = ctx.form
        return type(f) == "number" and f or 0
    end
    me.is_moving = function(self) return ctx.is_moving == true end
    me.get_power = function(self, p)
        if p == M.POWER.COMBO then return ctx.combo_points or 5 end
        if p == M.POWER.ENERGY then return ctx.energy or 100 end
        if p == M.POWER.RAGE then return ctx.rage or 70 end
        if p == M.POWER.FOCUS then return ctx.focus or 90 end
        if p == M.POWER.MANA then return ctx.player_mana or ctx.mana_pct or 100 end
        return 100
    end
    -- (a) opt-in close-out (2026-08-10): cat ShredTrick gates on
    -- state.next_tick_in > 1.0 (cat:1143), which derives from
    -- me:energy_time_to_x (cat:543). The legacy mock hardwired 0.4 (inside
    -- the pooling window), so the lane could never fire even with the
    -- cat_use_shred_trick setting on. Scenario-overridable via the
    -- energy_time_to_x ctx key (mirrors the batch-2 target_cast_pct stub);
    -- default 0.4 preserves every existing scenario's energy shape.
    me.energy_time_to_x = function(self, v) return ctx.energy_time_to_x or 0.4 end
    -- (b) close-out (2026-08-10): demo Seduction needs a live succubus pet
    -- (demonology:198-228: me:has_pet() + me:get_pet() + pet:is_valid/alive +
    -- pet spells). The pvp_succubus scenario sets has_pet; other scenarios
    -- keep the legacy no-pet posture (nil from get_pet → scan skipped).
    me.has_pet = function(self) return ctx.has_pet == true end
    me.get_pet = function(self)
        if not ctx.has_pet then return nil end
        return {
            is_valid = function() return true end,
            is_alive = function() return true end,
            is_dead = function() return false end,
            get_health_percentage = function() return 100 end,
        }
    end
    -- Arcane burn phase (ranked #2): the battery previously hardwired
    -- get_max_power to 100, so mage/arcane s.max_mana = 100 → mtte_burn ≈ 0.3
    -- < 5 → should_conserve always true → phase could never become "burn" and
    -- ArcanePower/PresenceOfMind/IcyVeins/ColdSnapIVReset could never fire.
    -- Realistic 15000 pool (scenario-overridable via `max_mana`) makes the
    -- burn phase reachable (mtte_burn ≈ 50.6 ≥ 5; can_burn needs a big
    -- current_mana, driven by the burn scenarios' player_mana 45000).
    -- Non-MANA power types (energy/rage/focus/combo) keep the legacy 100 so
    -- cat's ENERGY_CAP read and warrior rage math are unchanged.
    me.get_max_power = function(self, p)
        if p == M.POWER.MANA then -- M.POWER.MANA == 0 (power type 0 = mana)
            return ctx.max_mana or 15000
        end
        return 100
    end
    me.is_casting = function(self) return ctx.me_casting == true end
    me.is_channeling = function(self) return ctx.me_casting == true end
    -- Pet accessors (warlock specs read me:has_pet() / me:get_pet() directly;
    -- the NS-level pet binding alone left the whole warlock pet lane invisible).
    me.has_pet = function(self) return ctx.pet ~= nil and not (ctx.pet_dead == true) end
    me.get_pet = function(self) return ctx.pet end
    -- Range/stance reads bound to the scenario context (triage upgrade):
    -- me:get_distance() reflects ctx.target_distance so gap/melee gates see a
    -- realistic range instead of a hardwired 5 (unblocks mage Slow, makes
    -- FrostNova/ConeOfCold range-gated); get_player_stance reflects ctx.stance
    -- (warrior stance scenarios, druid form-as-stance).
    me.get_distance = function(self, t) return ctx.target_distance or ctx.target_range or 5 end
    me.get_player_stance = function(self) return ctx.stance or 0 end
    me.get_stance = function(self) return ctx.stance or 0 end
    -- WotLK era resource accessors (Phase 1 triage): the 41 *_wotlk.lua
    -- files resolve `local me = NS.me or NS.GetPlayer()` and read rage /
    -- energy / combo points / runic power DIRECTLY off the player unit, while
    -- TBC-era files read context.rage / ns.rage() etc. (bank-driven). Without
    -- these, every WotLK resource read fell back to 0 — warrior arms 18/19,
    -- fury 5/6, protection 6/6, rogue 4+5+8+3, cat 7/8, DK lanes all dead.
    -- W3.4 mock-tightening (2026-08-13): get_energy / get_combo_points /
    -- get_rage are REMOVED (tripwire) — the W3.3/W3.4 fixers migrated
    -- rogue/cat/warrior wotlk to context.energy / context.combo_points /
    -- context.rage + me:get_power(POWER_*); the repo audit found no live
    -- production reads (warrior wotlk arms/fury/protection/leveling now read
    -- context.rage first with a me:get_power(NS.POWER_RAGE) tail, mirroring
    -- bear_wotlk.lua:58; cat_sylvanas:363 keeps a pcall-guarded tail fallback
    -- that the tripwire makes inert). The tripwires FAIL LOUDLY if any
    -- (re)introduced production or test code calls these members on a battery
    -- unit — re-run the grep audits (get_rage / get_energy / get_combo_points)
    -- before ever removing or loosening them.
    me.get_rage = function(self)
        error("mock-only member me:get_rage() removed in W3.4 (behavioral_audit.lua) "
            .. "— production must use context.rage or me:get_power(NS.POWER_RAGE)", 2)
    end
    me.get_energy = function(self)
        error("mock-only member me:get_energy() removed in W3.4 (behavioral_audit.lua) "
            .. "— production must use context.energy or me:get_power(NS.POWER_ENERGY)", 2)
    end
    me.get_combo_points = function(self)
        error("mock-only member me:get_combo_points() removed in W3.4 (behavioral_audit.lua) "
            .. "— production must use context.combo_points or NS.get_combo_points", 2)
    end
    me.get_runic_power = function(self) return ctx.runic_power or 50 end
    return me
end

-- Scenario-aware target clone: HP reflects target_hp, casting reflects
-- target_is_casting, and get_target() reports the player (engaged target).
-- In PvP scenarios the target IS a player unit (unlocks Shiv purge player
-- checks, garrote/cheap-shot openers, PvP-only gates).
local function build_scenario_target(ctx)
    local target = _target()
    target.get_health_percentage = function(self) return ctx.target_hp or 100 end
    target.get_health = function(self) return (ctx.target_hp or 100) * 100 end
    target.is_casting = function(self) return ctx.target_is_casting == true end
    target.is_channeling = function(self) return ctx.target_is_casting == true end
    -- (c) close-out (2026-08-09, batch 2): enh EarthShock interrupt mode reads
    -- target:get_cast_pct() (enhancement:459-462) and gates on
    -- kick_min_pct..kick_max_pct (40..80 default). The legacy mock had no
    -- get_cast_pct, so cast_pct stayed 0 and the lane could never fire even
    -- with target_is_casting=true. Scenario-overridable via target_cast_pct;
    -- default 60 sits inside the kick window when the target is casting.
    target.get_cast_pct = function(self) return ctx.target_cast_pct or 60 end
    -- Vanilla sweep (2026-08): fury_vanilla build_state reads
    -- target:get_dodge_chance() via pcall (fury_vanilla:181-185) to derive
    -- state.overpower_window. Default 0 preserves the pre-fixture behavior
    -- (window false); the dodge_proc scenario flips it to fire Overpower.
    target.get_dodge_chance = function(self) return ctx.target_dodge_chance or 0 end
    -- Defensive-casting (warrior/rogue triage 2026-08-08): prot build_state
    -- derives state.target_is_casting from target:is_casting_spell()
    -- (protection_sylvanas.lua:310) while arms reads ctx.target_is_casting —
    -- that's why arms/fury Pummel fired in berserker_interrupt but prot
    -- Pummel/SpellReflection never could. Wire the same ctx flag here (the
    -- scenario target is built AFTER the overrides merge, so
    -- ctx.target_is_casting is final). Only prot + warrior middleware read
    -- is_casting_spell on the TARGET (affliction/demonology read the PET's,
    -- which has no method — unaffected), so collateral is confined to prot.
    target.is_casting_spell = function(self) return ctx.target_is_casting == true end
    -- get_target() reports the player (engaged target) unless the scenario
    -- overrides it: the elite_target/elite_taunt_cd scenarios set
    -- target_get_target = false ("nobody is currently being attacked") so
    -- Taunt's already-tanking gate passes (ranked #6). Default stays ctx.me.
    target.get_target = function(self)
        if ctx.target_get_target == false then return nil end
        return ctx.target_get_target or ctx.me
    end
    target.is_player = function(self) return ctx.is_pvp == true end
    -- get_class (close-out triage 2026-08-08): prot Disarm's disarm_class_ok
    -- (protection:358) pcall's target:get_class() and needs a melee class id
    -- in DISARM_CLASS_IDS {1,2,4,7}. Absent by default (mirrors the
    -- friend_class pattern) so no other get_class consumer changes — warlock
    -- ShadowWard wants {5,9}, and hunter ViperSting middleware only checks the
    -- class when `type(class_key) == "string"` (numeric ids skip that guard),
    -- so both stay untouched. Bonus: a future target_class = 5/9 scenario
    -- would make warlock ShadowWard observable with zero new wiring.
    if type(ctx.target_class) == "number" then
        target.get_class = function(self) return ctx.target_class end
    end
    -- Creature type reflects the scenario (undead_target scenario sets 6) so
    -- the ShackleUndead / TurnEvil / HolyWrath / Exorcism lanes are observable.
    -- NOTE: undead is creature-type 6 (WoW enum), not 3 — 3 is DEMON; the
    -- specs' DEMON_OR_UNDEAD / UNDEAD_OR_DEMON tables accept {3, 6}.
    target.get_creature_type = function(self) return ctx.target_creature_type or 7 end
    -- kebab build_state derives context.in_melee_range from target:is_in_melee_range();
    -- without it the DemoShout/melee gates always read false in the battery.
    target.is_in_melee_range = function(self) return (ctx.target_distance or ctx.target_range or 5) <= 5 end
    return target
end

-- Build the context table for one scenario descriptor + class profile.
function M.build_context_for(class_key, scenario, era)
    local profile = M.CLASS_PROFILE[class_key] or {}
    local ctx = _base_ctx(profile)
    local overrides = scenario.overrides or {}
    -- apply only known numeric/boolean keys
    local known = {
        enemy_count=true, enemies_count=true, target_hp=true, ttd=true,
        mana_pct=true, player_mana=true, player_mana_pct=true,
        hp=true, player_hp=true, in_combat=true, is_pvp=true,
        level=true, player_level=true, is_leveling=true, target_ttd=true,
        combo_points=true, energy=true, rage=true, focus=true,
        is_moving=true, is_stealthed=true, target_is_casting=true,
        -- W3.3 deathknight (2026-08-13): the REAL dispatcher fields the DK
        -- fixes read. Production sets context.target_casting
        -- (main_sylvanas.lua:759) and context.target_is_boss
        -- (main_sylvanas.lua:1287) — the W3.1 audit's is_boss /
        -- target_is_casting reads were phantom/mock-only. Whitelisted so the
        -- dk_boss / dk_ghoul_gnaw scenarios drive the REAL fields.
        target_casting=true, target_is_boss=true,
        stance=true, buffs_up=true, faction=true, pet_hp=true, pet_dead=true,
        lowest_hp=true, has_potions=true, friends_afflicted=true,
        -- W3.3 druid wotlk (2026-08-13): party_injured_count feeds resto_wotlk
        -- WildGrowth's injured-ally gate (context.party_injured_count is the
        -- engine party-scan field, main_sylvanas.lua:1237); only the new
        -- resto_wotlk lane reads it, so the key is additive-safe.
        party_injured_count=true,
        enemy_buffed=true, me_casting=true, on_cd=true, swing_until=true, afflicted=true,
        form=true, target_distance=true, should_burst=true,
        debuff_stacks=true, debuff_aura_ids=true, combat_time=true,
        target_creature_type=true, enemies_casting=true, buff_remains_map=true,
        debuff_remains_map=true, not_learned=true,
        -- Phase 2.2a (2026-08-13): aoe_target_meets feeds the bank-aware
        -- aoe_target_meets stub (elem_cl_st presents a single-target fight).
        aoe_target_meets=true,
        -- (c) close-out (2026-08-09, batch 2): cat MangleFiller reads
        -- context.is_behind (cat:514) so the battery target's always-true
        -- is_behind no longer blocks it; elem ChainHeal reads context.
        -- group_injured; elem TotemicCall reads context.has_totems; enh
        -- EarthShock reads target:get_cast_pct() via the scenario target;
        -- ret cleanse reads player_debuff_remains_map via has_player_debuff;
        -- balance Rebirth reads dead_ally via find_dead_party_ally; BM Trinket
        -- reads has_trinket via TrinketManager.get_equipped_trinkets.
        is_behind=true, group_injured=true, has_totems=true, target_cast_pct=true,
        player_debuff_remains_map=true, dead_ally=true, has_trinket=true,
        friend_class=true, setting_overrides=true,
        -- (a) opt-in close-out (2026-08-10): cat ShredTrick's next_tick_in
        -- gate reads me:energy_time_to_x; scenario-overridable (default 0.4).
        energy_time_to_x=true,
        -- Healer (c) close-out (2026-08-09): lifebloom feeds the heal-scan
        -- stub's Lifebloom let-bloom fields (resto druid LifebloomLetBloom).
        lifebloom=true,
        fsr_inside=true, fsr_seconds=true, fsr_regen_delta=true, fsr_pause_ok=true,
        -- Friendly-target context (ranked): friendly_target_hp presents a
        -- friendly unit via NS.get_friendly_target_entry so the 5 healer
        -- FriendlyTarget lanes (disc + holy priest, holy paladin, resto druid
        -- + shaman) become observable; it is the unit's pct (must be < the 90
        -- threshold). No separate boolean — the hp presence is the signal.
        friendly_target_hp=true, friendly_target_threat=true,
        max_mana=true,
        -- Threat context (ranked #12): high-threat scenarios make the threat-
        -- drop lanes (Soulshatter, priest Fade, rogue Feint) observable. These
        -- keys feed ctx.threat_pct / ctx.has_aggro / ctx.threat_status reads;
        -- lanes like hunter FeignDeath read state.threat_level instead (via
        -- hunter_core.should_feign_death) so they stay silent here.
        -- threat_level is currently forward-looking (no battery lane reads
        -- ctx.threat_level yet — hunter uses state.threat_level).
        threat_pct=true, threat_status=true, has_aggro=true, threat_level=true,
        -- Elite-target context (ranked #6): target_classification feeds the
        -- smart-taunt matchers (warrior Taunt/TauntSecondary/MockingBlow,
        -- paladin RighteousDefense, druid cat rip-elite gate); target_get_target
        -- models an un-tanked target (false = nobody). visible_enemies is
        -- consumed directly in build_context_for (mock unit list, not a scalar).
        target_classification=true, target_get_target=true,
        -- Close-out triage (2026-08-08): target_class feeds the scenario
        -- target's get_class (prot Disarm disarm_class_ok gate); only prot
        -- reads it, so it stays scoped.
        target_class=true,
        -- Close-out triage (2026-08-08, ranked #3): is_group drives prot
        -- Intervene's group gate (protection:757) and the group_ally_low
        -- scenario presents a low-hp ally through ctx.party_members (the
        -- engine surface) so the party scan populates lowest_allied.
        is_group=true,
        -- Threat-family close-out (2026-08-10): party_members / group_members
        -- present the ally scan for prot's peel lanes (protection:566 reads
        -- context.party_members OR context.group_members directly); now feeds
        -- bear build_state's clock so Growl's taunt throttle passes.
        party_members=true, group_members=true, now=true,
        -- Stat/weapon mocks (2026-08-08 focused triage): hit_rating feeds the
        -- HitCapPriority matchers (combat/arms/fury read context.hit_rating and
        -- gate on deficit = hit_cap_rating_needed - hit_rating > 30 — default
        -- ctx has no rating so they could never fire); equipped_daggers feeds
        -- the dagger mock above for assassin Mutilate.
        hit_rating=true, equipped_daggers=true,
        -- Totemic Call (2026-08-08): totem_active drives the
        -- core.spell_book.get_totem_info stub (has_totem gate); totem_far
        -- appends a distant totem mock to the visible-objects scan. Both are
        -- shaman/enhancement-scoped reads.
        totem_active=true, totem_far=true,
        -- WotLK Phase-1 triage (2026-08-09): resource/state banks for the
        -- *_wotlk.lua specs. runic_power feeds the DK rune stub (DancingRune
        -- Weapon >= 60 / DeathCoil >= 100); rune_state drives the rune bank
        -- (dk_runes_depleted → EmpowerRuneWeapon); optimal_presence drives
        -- the presence stub (dk_presence → blood/unholy Presence + frost
        -- FrostPresence); lock_and_load is RETIRED since W3.3 (2026-08-13):
        -- survival reads the Lock and Load proc via NS.buff_up over
        -- buff_remains_map 56344, not the ctx key — the key is kept
        -- whitelisted as inert; scorch_cast_time + ttd unlock fire
        -- FireBlast's scorch-window gate; maelstrom_stacks feeds the enh
        -- LightningBolt stacks bank; diseases/ff-bp remain handled by the
        -- existing debuff_remains_map (dk_disease scenario).
        -- W3.4 mock-tightening (2026-08-13): is_boss / bloodlust_ready /
        -- elemental_mastery_ready / fire_elemental_ready / water_totem_remains
        -- / injured_count / mana_tide_ready are REMOVED from the whitelist —
        -- phantom scenario-only keys the dispatcher never sets (production
        -- now reads target_is_boss / party_injured_count / NS.spell_ready /
        -- NS.get_totem_info). A scenario override using one of these names is
        -- now silently dropped (fail-closed via the audit table + W3.4
        -- addendum rather than fed to production).
        runic_power=true, rune_state=true, optimal_presence=true,
        lock_and_load=true, scorch_cast_time=true,
        maelstrom_stacks=true,
        -- W4.3 (2026-08-14): SoD-era scenario keys. Both are REAL engine
        -- fields the dispatcher sets for SoD clients (main_sylvanas.lua:
        -- 1256/1258 — sod_phase from settings, sod_runes from
        -- NS.get_sod_runes), consumed by spec_kit.sod_action_available /
        -- has_sod_rune. No TBC/WotLK/vanilla scenario uses these names, so
        -- whitelisting them is additive-safe; the sod scenarios drive them so
        -- rune/phase-gated SoD lanes stay observable.
        sod_runes=true, sod_phase=true,
        -- Wave 3.3 (2026-08-13): party_injured_count is the REAL engine field
        -- for the healer AoE-heal gate (main_sylvanas.lua:973/1225 populates
        -- context.party_injured_count, NOT the phantom injured_count the old
        -- shaman resto build_state read).
        party_injured_count=true,
        -- (b) close-out (2026-08-10): PvP/situational fixture keys. is_pvp /
        -- combat_time / player_debuff_remains_map / setting_overrides already
        -- whitelisted; these add the remaining ctx reads (balance/affliction
        -- PvP lanes, ret fleeing, mage polymorph cc_target, snare self-root,
        -- shaman tremor) and the stub-driven banks (enemies_in_range,
        -- is_auto_attacking, pet_spells, has_pet).
        melee_on_you=true, enemy_healer=true, enemy_caster=true, cc_target=true,
        target_fleeing=true, target_is_fleeing=true, self_rooted_snared=true,
        fear_nearby=true, enemies_in_range=true, is_auto_attacking=true,
        pet_spells=true, has_pet=true, snared_friend=true,
        -- Wave 1.4 (2026-08-13): is_behind feeds the bank-aware
        -- NS.is_behind_target (druid leveling Claw shred-preference gate);
        -- enemy_cc_nearby feeds CCGateDB.is_any_nearby_enemy_under_cc
        -- (warrior leveling PvPCCGate).
        is_behind=true, enemy_cc_nearby=true,
        -- Vanilla battery sweep (2026-08): in_melee_range feeds fury Intercept's
        -- `not in_melee_range` gate (gap scenarios set target_distance 15 but
        -- never flipped it); enemies_target_me drives the GetEnemiesInRange
        -- stub so the vanilla priest Fade lane (enemy get_target() == me) is
        -- observable.
        in_melee_range=true, enemies_target_me=true,
        -- Vanilla sweep (2026-08): target_dodge_chance feeds the mock
        -- target's get_dodge_chance so fury_vanilla's Overpower window
        -- (fury_vanilla:181-185 pcall path) is drivable; only fury_vanilla
        -- reads it.
        target_dodge_chance=true,
    }
    for k, v in pairs(overrides) do
        if k == "friends_hp" then
            ctx.friends_hp = v
        elseif k == "has_potions" then
            ctx.has_health_potion = true
            ctx.has_mana_potion = true
            ctx.has_damage_potion = true
            ctx.has_potions = true
        elseif known[k] then
            ctx[k] = v
        end
    end
    -- Settings-modeling fixture (ranked #7): merge setting_overrides into
    -- ctx.settings so ALL read channels see them — direct `ctx.settings[key]`
    -- reads (balance RemoveCurse, hunter AdaptiveRotation via
    -- NS.setting_bool), spec_kit.setting/setting_bool (context.settings is
    -- FIRST in the resolution chain), and the DSL `{ type = "setting" }`
    -- condition evaluator (spec_kit.setting). The scenario-aware
    -- ns.get_setting/get_any_setting stubs remain the fallback for callers
    -- that pass the ctx directly. Keys are spec-scoped, so an override never
    -- leaks into another spec's gates.
    if type(overrides.setting_overrides) == "table" then
        for k, v in pairs(overrides.setting_overrides) do
            ctx.settings[k] = v
        end
    end
    -- W4.3 (2026-08-14): SoD-era context defaults. Every _sod.lua strategy
    -- gates on context.is_sod (legacy-gate tests assert is_sod=false blocks),
    -- and spec_kit.sod_action_available reads context.sod_phase — the engine
    -- defaults phase to 8 (SOD_DEFAULT_PHASE, main_sylvanas.lua:1256) and
    -- leaves sod_runes unset when settings carry none (has_sod_rune then
    -- fails open — unknown rune state must not disable rune-only actions).
    -- Scenario overrides win when present; defaults only fill unset fields.
    if era == "sod" then
        if ctx.is_sod == nil then ctx.is_sod = true end
        if ctx.sod_phase == nil then ctx.sod_phase = 8 end
    end
    if ctx.target_distance then ctx.target_range = ctx.target_distance end
    -- Warriors start in Battle Stance (1); stance scenarios flip it.
    if class_key == "warrior" and ctx.stance == 0 then ctx.stance = 1 end
    -- Druids: stance IS form (bear=1, moonkin=2, cat=3, travel=4). Keep them
    -- in sync so shared scenarios that set stance (e.g. aoe→1) can't make a
    -- druid spec believe it is in bear form, and NUMERIC form scenarios
    -- actually flip stance-based checks. String forms ("cat"/"bear") are
    -- only consumed by leveling_wotlk via context.form and must NOT leak into
    -- ctx.stance — TBC druid files compare stance against numeric STANCE
    -- constants (bear_sylvanas:376, cat_sylvanas:737), and a string would
    -- silently read as 'not in form' (or crash on arithmetic if ever added).
    if class_key == "druid" and type(ctx.form) == "number" then
        ctx.stance = ctx.form
    end
    -- Scenario-aware player + target
    ctx.me = _scenario_me(profile, ctx)
    ctx.target = build_scenario_target(ctx)
    -- (b) close-out (2026-08-10): mage Polymorph reads context.cc_target and
    -- calls cc_t.is_cc() on it — a boolean scenario value crashes the matcher
    -- (attempt to index a boolean). Present a real unit: default to the
    -- scenario target so the PvP mega-scenario's cc_target=true resolves to a
    -- CC-able unit (is_cc absent → the SDK skip-gate is bypassed, which is the
    -- permissive-mock posture everywhere else).
    if ctx.cc_target == true then
        ctx.cc_target = ctx.target or build_scenario_target(ctx)
    end
    if scenario.no_target then
        ctx.target = nil
        ctx.has_target = false
        ctx.has_valid_enemy_target = false
        ctx.target_ttd = nil
        ctx.ttd = nil
        ctx.target_hp = 100
        ctx.range = 0
    end
    -- Secondary enemies (ranked #7): multi-enemy scenarios present the
    -- target's peers so lanes that scan `context.enemies` (retri
    -- find_secondary_enemy → Ret_JudgeSecondary_CommandCleave, multi-target
    -- DoT-spread lanes) see a realistic enemy list instead of the empty
    -- default. The clone is a fresh unit sharing the scenario's closures, so
    -- `enemy ~= context.target` holds and distance/HP reads are scenario-true.
    -- FOOTGUN: this fixture makes `enemies` non-empty in EVERY 2+ enemy
    -- scenario (aoe, group_aoe, undead_target, hunter_toggles, ...). Lanes
    -- that scan it will start firing battery-wide — the multi-DoT spread
    -- lanes (shadow MultiDot*/balance *Spread) must stay silent until a
    -- per-debuff afflictable-targets model exists; verify any future
    -- enemies-scanning lane fires ONLY in its intended scenario.
    if (ctx.enemy_count or ctx.enemies_count or 1) >= 2 then
        ctx.enemies = { ctx.target, build_scenario_target(ctx) }
    end

    -- Warrior threat-scan mocks (ranked #6): TauntSecondary's no_threat_target
    -- derives from the protection visible-objects scan (get_threat_targets,
    -- fed by core.object_manager.get_visible_objects and throttled by
    -- core.time — both stubbed in load_spec). Scenarios opt in via
    -- `visible_enemies = true`. Mocks must be enemies of the player
    -- (is_enemy_with → true) NOT currently targeting the player (get_target
    -- nil — the _target base already returns nil) or the scan treats them as
    -- already-tanked. No get_owner/get_position, so the shaman enhancement
    -- totem-recall scan (which skips owner-less objects) is unaffected.
    -- NOTE: TauntSecondary additionally requires prot_state.enemy_count >= 3
    -- (from ctx.enemy_count), so a visible_enemies scenario must also set
    -- enemy_count >= 3 — the two elite scenarios do (3).
    if overrides.visible_enemies then
        local count = ctx.enemy_count or ctx.enemies_count or 2
        local list = {}
        for i = 1, count do
            local e = _target()
            e.is_enemy_with = function() return true end
            -- Real game objects always expose get_owner() (nil for units) —
            -- the enh TotemicCall scan calls obj:get_owner() unconditionally
            -- (enhancement_sylvanas.lua:1265), so owner-less mocks must
            -- return nil here or the scan errors instead of skipping them.
            e.get_owner = function() return nil end
            list[i] = e
        end
        -- Totemic Call (campaign follow-up 2026-08-08): the enh totem-recall
        -- scan (enhancement_sylvanas.lua:1225-1277) iterates visible objects,
        -- keeps only those with get_owner() (summoned), and fires when one
        -- sits beyond TOTEM_CALL_DISTANCE (20 yd -> 400 sq). Enemy mocks have
        -- no get_owner (skipped); the totem_far flag appends a distant totem
        -- at (30, 30) -> 1800 sq > 400 so the recall fires.
        if overrides.totem_far then
            list[#list + 1] = {
                is_valid = function() return true end,
                get_owner = function() return {} end,
                get_position = function() return { x = 30, y = 30, z = 0, [1] = 30, [2] = 30 } end,
            }
        end
        ctx.visible_enemies = list
    end
    -- Pets (hunter + warlock) — skipped when the scenario says the pet was
    -- never summoned (no_pet) so Call Pet / summon lanes are reachable.
    -- W3.3 (2026-08-13): the dk_ghoul_* scenarios set has_pet=true for the
    -- death knight (no pet profile) so the new unholy ghoul command lanes are
    -- demonstrably fireable; warlock/hunter scenarios are unchanged (their
    -- ctx.pet already comes from profile.pet, and has_pet=true only ADDS a pet
    -- where none would exist).
    if (profile.pet or ctx.has_pet == true) and not scenario.no_pet and not scenario.pet_dismissed then
        local pet_hp = ctx.pet_hp or 100
        local pet = _target()
        pet.get_health_percentage = function(self) return pet_hp end
        pet.get_health = function(self) return pet_hp * 100 end
        pet.is_dead = function(self) return pet_hp <= 0 end
        -- Warlock specs gate pet state on pet:is_alive(); without it the live
        -- pet lane read pet_alive=false and pet_hp_pct=100 in every scenario.
        pet.is_alive = function(self) return pet_hp > 0 end
        pet.get_distance = function(self) return 20 end
        ctx.pet = pet
        ctx.pet_dead = ctx.pet_dead == true or pet_hp <= 0
    elseif scenario.pet_dismissed then
        -- W4.3 (2026-08-14): pet dismissed / never-summoned but NOT dead —
        -- the SoD Call Pet lanes (hunter + warlock dps) gate on `not
        -- s.pet_dead`, which the legacy no_pet branch (pet_dead=true) could
        -- never present. Distinct from no_pet: RevivePet's pet_dead semantic
        -- is untouched.
        ctx.pet = nil
        ctx.pet_dead = false
    else
        ctx.pet = nil
        ctx.pet_dead = true
    end
    local is_healer = class_key == "priest" or class_key == "shaman"
        or class_key == "paladin" or class_key == "druid"
    if is_healer then
        ctx.is_group = true
        if not scenario.no_target then
            local hps = ctx.friends_hp or { 55, 70, 85 }
            ctx.friends = {}
            ctx.party = {}
            for i, hp in ipairs(hps) do
                local f = _friend(hp, 30)
                ctx.friends[i] = f
                ctx.party[i] = f
            end
            local lo = ctx.lowest_hp or (hps[1] or 100)
            ctx.lowest = { unit = ctx.friends[1], hp = lo }
        else
            ctx.friends = {}
            ctx.party = {}
            ctx.lowest = { unit = nil, hp = 100 }
        end
    end
    return ctx
end

-- ---------------------------------------------------------------------------
-- Sync NS state bank + subsystem stubs to the current scenario context so
-- every match/state read reflects this scenario's realistic state.
-- ---------------------------------------------------------------------------
function M.apply_battery_state(ns, ctx, class_key)
    -- WotLK era (Phase 1 triage): *_wotlk.lua specs resolve the player unit
    -- via `NS.me or NS.GetPlayer()` (not `context.me` like TBC files), so the
    -- scenario-aware unit must be published as NS.me per scenario or every
    -- WotLK unit read (rage/energy/combo/runic) hits the raw mock and returns
    -- 0 — the root cause of the 149-lane WotLK never-firing inventory.
    if ctx.me then ns.me = ctx.me end
    -- Advance the scenario clock: module-level 1s scan caches (hunter_core pet
    -- scan, purge delay cache, swing gates) must see a fresh timestamp per
    -- scenario or they freeze on the first scenario's observations.
    _battery_now = _battery_now + 2.0
    ns._battery_now = _battery_now
    ns._battery = {
        power = {
            [M.POWER.MANA] = ctx.player_mana or ctx.mana_pct or 100,
            [M.POWER.RAGE] = ctx.rage or ((class_key == "warrior") and 70 or 100),
            [M.POWER.FOCUS] = ctx.focus or 90,
            [M.POWER.ENERGY] = ctx.energy or 100,
            [M.POWER.COMBO] = ctx.combo_points or 5,
        },
        stance = ctx.stance or 0,
        form = ctx.form or 0,
        buffs_up = ctx.buffs_up == true,
        faction = ctx.faction or 0,
        hp = ctx.hp or 100,
        mana_pct = ctx.mana_pct or 100,
        on_cd = ctx.on_cd,
        in_combat = ctx.in_combat == true,
        is_stealthed = ctx.is_stealthed == true,
        target_is_casting = ctx.target_is_casting == true,
        me_casting = ctx.me_casting == true,
        swing_until = ctx.swing_until,
        enemy_buffed = ctx.enemy_buffed == true,
        friends_afflicted = ctx.friends_afflicted == true,
        friends_hp = ctx.friends_hp,
        lifebloom = ctx.lifebloom,
        afflicted = ctx.afflicted or {},
        pet_hp = ctx.pet_hp or 100,
        pet_dead = ctx.pet_dead == true,
        has_potions = ctx.has_potions == true,
        level = ctx.level or ctx.player_level or 70,
        is_leveling = ctx.is_leveling == true,
        debuff_stacks = ctx.debuff_stacks or 0,
        debuff_aura_ids = ctx.debuff_aura_ids,
        not_learned = ctx.not_learned,
        target_creature_type = ctx.target_creature_type or 7,
        buff_remains_map = ctx.buff_remains_map,
        player_debuff_remains_map = ctx.player_debuff_remains_map,
        -- (c) close-out (2026-08-09): dead_ally feeds find_dead_party_ally
        -- (balance Rebirth); has_trinket feeds TrinketManager (BM Trinket).
        dead_ally = ctx.dead_ally == true,
        has_trinket = ctx.has_trinket == true,
        -- Multi-DoT spread model (ranked #1): the TSHelper stub returns this
        -- enemy list, and debuff_up/debuff_remains consult the primary-target
        -- dot map before the buffs_up fallback.
        enemies = ctx.enemies,
        primary_target = ctx.target,
        debuff_remains_map = ctx.debuff_remains_map,
        visible_enemies = ctx.visible_enemies,
        friend_class = ctx.friend_class,
        setting_overrides = ctx.setting_overrides,
        -- (b) close-out (2026-08-10): stub-driven banks for the PvP/situational
        -- fixtures (GetEnemiesInRange, is_auto_attacking, pet_spells). The
        -- is_auto_attacking default stays TRUE (legacy posture) unless a
        -- scenario explicitly sets it false.
        enemies_in_range = ctx.enemies_in_range,
        is_auto_attacking = ctx.is_auto_attacking ~= false,
        pet_spells = ctx.pet_spells,
        snared_friend = ctx.snared_friend == true,
        -- Wave 1.4 (2026-08-13): is_behind drives the bank-aware
        -- NS.is_behind_target (default true when unset — legacy posture);
        -- enemy_cc_nearby drives the CCGateDB under-CC scan stub.
        is_behind = ctx.is_behind ~= false,
        enemy_cc_nearby = ctx.enemy_cc_nearby == true,
        -- Equipped-weapon mock (2026-08-08): the mutilate_daggers scenario's
        -- equipped_daggers flag lands here so the get_equipped_item_id stub
        -- (which reads _bstate) returns a dagger id for both hands → assn
        -- has_daggers = true → Mutilate observable.
        equipped_daggers = ctx.equipped_daggers == true,
        -- Totemic Call (2026-08-08): ns.core.spell_book.get_totem_info reads
        -- this bank key (enh cached the stub at load time); the totem_far
        -- scenario sets it so the has_totem gate passes.
        totem_active = ctx.totem_active == true,
        fsr_inside = ctx.fsr_inside == true,
        fsr_seconds = ctx.fsr_seconds or 0,
        fsr_regen_delta = ctx.fsr_regen_delta or 0,
        fsr_pause_ok = ctx.fsr_pause_ok == true,
        -- WotLK Phase-1 triage (2026-08-09): resource/state banks for the DK
        -- stubs (rune_manager/presence_manager/interrupt_manager read these via
        -- ns._bstate) and the *_wotlk build_state context reads.
        runic_power = ctx.runic_power,
        rune_state = ctx.rune_state,
        optimal_presence = ctx.optimal_presence,
        lock_and_load = ctx.lock_and_load == true,
        scorch_cast_time = ctx.scorch_cast_time,
        maelstrom_stacks = ctx.maelstrom_stacks,
        -- W3.4 mock-tightening (2026-08-13): the phantom bank keys are
        -- REMOVED — bloodlust_ready / elemental_mastery_ready /
        -- fire_elemental_ready / water_totem_remains / injured_count /
        -- mana_tide_ready / is_boss were scenario-only overrides the
        -- dispatcher never sets; production now reads NS.spell_ready /
        -- NS.get_totem_info / context.party_injured_count / context.target_is_boss
        -- (the W3.1 audit's masked-member family). Any lane depending on them
        -- is a genuine production never-lane (see the W3.4 triage addendum).
        -- Friendly-target context (2026-08-08): friendly_target_hp feeds
        -- NS.get_friendly_target_entry so the healer FriendlyTarget lanes
        -- (disc + holy priest, holy paladin, resto druid + shaman) get a
        -- friendly unit below the 90 threshold. Keyed on the hp alone (no
        -- boolean — avoids colliding with context.friendly_target-as-unit).
        friendly_target_hp = ctx.friendly_target_hp,
        -- Threat-family close-out (2026-08-10): friendly_target_threat marks
        -- the lowest heal-scan ally threatened for holy BoPFocusedAlly.
        friendly_target_threat = ctx.friendly_target_threat,
    }
    -- Party members: holy MassDispel (holy_sylvanas.lua:1031) scans
    -- context.party_members for dangerous magic via Healing.has_dangerous_dispel.
    -- Present the scenario's friends as the party when the group carries magic
    -- affliction (the friends_afflicted scenario) so the scan finds a target;
    -- other scenarios keep party_members empty so the matcher stays silent (and
    -- ally-scanning paladin lanes keep their current battery behavior). Any
    -- healer module's scan returns identical entries (same _heal_entries factory
    -- + state bank), so ns.PriestHealing is just a convenient accessor.
    local _afflicted_t = ctx.afflicted or {}
    if _afflicted_t.magic == true then
        local heal_mod = ns.PriestHealing
        local entries = heal_mod and heal_mod.scan_healing_targets and heal_mod.scan_healing_targets()
        if type(entries) == "table" then
            ctx.party_members = {}
            for i = 1, #entries do ctx.party_members[i] = entries[i].unit end
        end
    end
    -- Scenario-aware unit_alive: pet reads reflect pet_dead so the dead-pet
    -- lane (Revive Pet, Call Pet, Mend Pet suppression) is observable.
    ns.unit_alive = function(unit)
        if unit == ctx.pet then return not (ctx.pet_dead == true) end
        return true
    end
    -- Enemy scan: priest pre_heal_matches gates on _check_pushback, which
    -- iterates NS.GetEnemiesInRange looking for a casting enemy. Absent this
    -- stub the scan is empty and PreHeal can never fire. Only the `pushback`
    -- scenario presents a casting enemy; everything else stays empty so other
    -- enemies-in-range consumers (fade fallback, defensive middleware) keep
    -- their current battery behavior.
    ns.GetEnemiesInRange = function(range)
        if ctx.enemies_casting == true then return { ctx.target } end
        -- Vanilla battery sweep (2026-08): priest holy/discipline Fade scans
        -- GetEnemiesInRange for an enemy whose get_target() is the player
        -- (the TBC siblings added a threat_pct gate the vanilla files don't
        -- have). _battery_enemy.get_target() is nil everywhere else, so this
        -- dedicated scenario is the only path that fires the vanilla Fade lane.
        if ctx.enemies_target_me == true then
            local e = _battery_enemy("melee")
            e.get_target = function() return ctx.me end
            return { e }
        end
        -- (b) close-out (2026-08-10): the pvp_pressure_resto scenario sets
        -- enemies_in_range = { melee = N, healer = N } so resto's
        -- scan_pvp_pressure fills melee_pressure_count / enemy_healer /
        -- root_target. Default (no key) stays {} — identical to the legacy
        -- empty scan, so no other spec's reads change.
        local spec = ctx.enemies_in_range
        if type(spec) ~= "table" then return {} end
        local out = {}
        for i = 1, (spec.melee or 0) do out[#out + 1] = _battery_enemy("melee") end
        for i = 1, (spec.healer or 0) do out[#out + 1] = _battery_enemy("healer") end
        return out
    end
    -- Party scan (P2.2b, 2026-08-13): druid balance/vanilla build_state's
    -- smart-Innervate scan reads NS.GetPartyMembers() directly — a LIVE
    -- engine API (main_sylvanas.lua:178/:949), unlike the bare-value
    -- party_members field (which is why the 2026-08-11 stub removal did not
    -- cover it). Scenario-provided party_members (friend units constructed
    -- with a class id carry get_class) drive the InnervateHealer lane;
    -- default nil keeps every other spec's reads unchanged.
    ns.GetPartyMembers = function()
        return ctx.party_members
    end
    -- Pets (hunter + warlock)
    if ctx.pet ~= nil then
        ns.has_pet = function() return not (ctx.pet_dead == true) end
        ns.get_pet = function() return ctx.pet end
        ns.GetPet = function() return ctx.pet end
        ns.get_pet_hp = function() return ctx.pet_hp or 100 end
        ns.pet_hp_pct = function() return ctx.pet_hp or 100 end
    else
        ns.has_pet = function() return false end
        ns.get_pet = function() return nil end
        ns.GetPet = function() return nil end
        ns.get_pet_hp = function() return 100 end
    end
    ns.has_health_potion = ctx.has_health_potion == true
    -- Heal-scan stubs live in build_ns and are driven by the state bank
    -- (_bstate "friends_hp" / "afflicted"): only scenarios that SET friends_hp
    -- (friends_damaged, me_casting, group_*, friends_afflicted) present injured
    -- allies, so solo/healthy scenarios keep the idle-DPS lanes observable and
    -- injured-group scenarios drive the *Heal/cleanse lanes. This replaces the
    -- earlier always-injured scan (every healer scenario reported 55/70/85 hp
    -- friends, which silenced every Idle*/Solo* DPS lane).
    -- Party access for scenarios that set ctx.party_members (holy MassDispel
    -- and prot's Intervene/peel scans read the engine field directly). The
    -- ns.get_party_members / ns.party_members mock stubs were REMOVED in the
    -- 2026-08-11 bare-value-read sweep — those members are never defined in
    -- live play (the engine writes context.party_members at main_sylvanas.lua
    -- :932) and were masking a dead scan path.
    if ns.HealerDeficit then
        ns.HealerDeficit.deficit_of = function(u) return math.max(0, 100 - (u and u.hp or 100)) end
    end
end

-- ---------------------------------------------------------------------------
-- Spec loader
-- ---------------------------------------------------------------------------
function M.load_spec(class_key, spec_key, era, race_override)
    era = era or "sylvanas"
    local path = "EaxRotations/classes/" .. class_key .. "/" .. spec_key .. "_" .. era .. ".lua"
    local f = io.open(path, "rb")
    if not f then return nil, "missing file " .. path end
    f:close()

    -- Death Knight shared-manager stubs (Phase 1): the real rune_manager /
    -- presence_manager / interrupt_manager load fine standalone but read live
    -- game state (rune APIs, presence settings) that the battery cannot
    -- reproduce; without stubs every DK rune read returns 0/{} and the
    -- presence lane can never fire. Scenario-driven where useful (see below).
    -- Restored after dofile: load_spec nils package.loaded for the six stubbed
    -- modules (rune/presence/interrupt/fsr/ts/stealth managers) in the dofile
    -- error-handler block so later suites get the real modules back.

    -- Seed binary-only game modules spec files require (present in the live
    -- client but absent from this repo). Without this, hunter specs' item
    -- lanes (Healthstone / potions / trinkets) silently read nil helpers and
    -- the battery reports them never-firing even though they work in game.
    package.loaded["common/utility/inventory_helper"] = {
        has_item = function(id) return true end,
        get_item_count = function(id) return 1 end,
        is_item_ready = function(id) return true end,
    }

    local ns = M.build_ns(class_key, era)
    _G.EaxRotations = ns
    local had_core = _G.core
    _G.core = {
        spell_book = {
            get_totem_info = function() return nil end,
        },
        -- Scenario-aware clock (ranked #6): protection's TauntSecondary threat
        -- scan throttles on core.time(). Wire it to the advancing _battery_now
        -- so the scan runs fresh per scenario instead of freezing on the first
        -- (constant 0 previously → scan never ran → no_threat_target nil).
        -- Module-level 1s caches (enhancement totem recall, aura_cache) now
        -- re-evaluate per scenario; their battery results are constant (false
        -- / empty), so never-lists are byte-identical and no exclusivity-pinned
        -- lane's fires_in changed (all 12 battery regression tests green).
        time = function() return _battery_now end,
        object_manager = {
            -- Visible enemies for the protection threat scan; empty everywhere
            -- except the elite_target/elite_taunt_cd scenarios (which populate
            -- ctx.visible_enemies). Other consumers (enhancement totem scan,
            -- aura_probe get_local_player, auto_loot get_all_objects) are
            -- pcall/owner-guarded and see {} / nil as before.
            get_visible_objects = function() return ns._bstate("visible_enemies", {}) end,
        },
    }
    if class_key == "deathknight" then
        -- Rune bank (Phase 1, second pass): the per-rune getters were hardcoded
        -- 2/2/2/0, so frost/unholy EmpowerRuneWeapon (gate: total_runes_ready
        -- == 0) could NEVER fire — the dk_runes_depleted scenario's rune_state
        -- override never reached them. All four now read the bank's ready map
        -- (default 2s, the original battery posture).
        local function _rune_bank()
            local rs = ns and ns._bstate and ns._bstate("rune_state", nil)
            if type(rs) == "table" and type(rs.ready) == "table" then return rs end
            return nil
        end
        package.loaded["shared/rune_manager_sylvanas"] = {
            get_runic_power = function(unit)
                return ns and ns._bstate and ns._bstate("runic_power", 50) or 50
            end,
            get_rune_state = function()
                return ns and ns._bstate and ns._bstate("rune_state", nil) or {
                    blood = 2, frost = 2, unholy = 2, death = 0,
                    ready = { blood = 2, frost = 2, unholy = 2, death = 0 },
                }
            end,
            get_blood_runes_ready = function()
                local rs = _rune_bank()
                return rs and rs.ready.blood or 2
            end,
            get_frost_runes_ready = function()
                local rs = _rune_bank()
                return rs and rs.ready.frost or 2
            end,
            get_unholy_runes_ready = function()
                local rs = _rune_bank()
                return rs and rs.ready.unholy or 2
            end,
            get_death_runes_ready = function()
                local rs = _rune_bank()
                return rs and rs.ready.death or 0
            end,
        }
        -- Presence (Phase 1, second pass): get_optimal_presence hardcoded nil and
        -- should_switch_presence hardcoded false, so the 3 presence lanes (blood
        -- Presence, unholy Presence, frost FrostPresence) could never fire. Now
        -- scenario-driven: the dk_presence scenario sets optimal_presence in the
        -- bank; the lanes fire wherever the bank's desired presence differs from
        -- the current state (nil in the battery — no presence buffs up).
        package.loaded["shared/presence_manager_sylvanas"] = {
            get_optimal_presence = function()
                return ns and ns._bstate and ns._bstate("optimal_presence", nil)
            end,
            should_switch_presence = function(ctx, st, desired)
                local want = ns and ns._bstate and ns._bstate("optimal_presence", nil)
                if not want or not desired then return false end
                local cur = st and st.presence
                return cur == nil or cur ~= desired
            end,
            presence_id = function(name) return name end,
            presence_name = function(id) return id end,
            presence_spell_id = function() return 0 end,
        }
        -- Interrupts (Phase 1, second pass): register_interrupt_spell returned a
        -- matches=false strategy, so MindFreeze (blood/frost/unholy) could never
        -- fire. Now bank-aware: matches on target_is_casting, so the existing
        -- target_casting scenario makes the 3 MindFreeze lanes observable.
        package.loaded["shared/interrupt_manager_sylvanas"] = {
            register_interrupt_spell = function()
                return {
                    name = "MindFreeze",
                    matches = function()
                        return ns and ns._bstate and ns._bstate("target_is_casting", false) == true
                    end,
                    execute = function() return false end,
                }
            end,
        }
    end
    -- (b) close-out (2026-08-10): smite binds _player_race from
    -- load_player:get_race_id() at require time (smite:30-32). RACE_OVERRIDES
    -- makes smite load as night elf (4) so Starshards is observable;
    -- run_spec passes an explicit race_override for RACE_VARIANTS (undead 5)
    -- so DevouringPlague is observable too. Other specs get nil → race 1
    -- (human), unchanged.
    -- Era-gated: the TBC and vanilla batteries each bind their own race
    -- override (smite loads as night elf 4 so Starshards is observable); a
    -- future WotLK-era smite load can't silently pick up a binding.
    local overrides = M.race_maps_for(era)
    M._race_override = race_override or (overrides and overrides[spec_key])
    local ok, result = pcall(dofile, path)
    M._race_override = nil
    -- Keep the stub installed when there was no pre-existing core: runtime
    -- reads during dispatch (protection's threat-scan throttle calls
    -- core.time() live) would otherwise see nil and freeze the scan at now=0,
    -- leaving no_threat_target nil forever. Restore a caller-provided core if
    -- one exists; otherwise leave the stub in place. The stub is benign
    -- (spell_book.get_totem_info nil, get_visible_objects {} unless a scenario
    -- sets visible_enemies) and the rotation runner snapshots/restores _G
    -- between suites, so no sibling test sees it.
    _G.core = had_core or _G.core
    -- The FSR/TSHelper stubs are captured by the spec module at require()
    -- time; restore the real modules for any later suite in the same process
    -- (all tests share one dofile process).
    package.loaded["shared/fsr_manager_sylvanas"] = nil
    package.loaded["shared/ts_helper_sylvanas"] = nil
    package.loaded["shared/stealth_helper_sylvanas"] = nil
    package.loaded["shared/rune_manager_sylvanas"] = nil
    package.loaded["shared/presence_manager_sylvanas"] = nil
    package.loaded["shared/interrupt_manager_sylvanas"] = nil
    -- Wave 1.4 (2026-08-13): the 9 leveling_vanilla specs require
    -- shared/leveling_sylvanas, which captures `local NS = _G.EaxRotations`
    -- at require time (leveling_sylvanas:21) — same pollution class as the
    -- stub modules above. Without eviction the FIRST leveling spec's mock-NS
    -- binding stays cached in package.loaded and the remaining 8 leveling
    -- specs would read a stale spec's state bank. Each load_spec must start
    -- the module virgin (bound to the CURRENT mock NS).
    package.loaded["shared/leveling_sylvanas"] = nil
    -- W4.3 (2026-08-14): sod_context_sylvanas captures `local NS =
    -- _G.EaxRotations` at require time (sod_context_sylvanas.lua:40) — the
    -- same require-time pollution class as the stub modules above. Evict it
    -- per load so each SoD spec's enrich binds to ITS mock NS and reads the
    -- CURRENT spec's state bank (stale binding → stale _battery reads).
    package.loaded["shared/sod_context_sylvanas"] = nil
    if not ok then
        return nil, tostring(result)
    end
    return result, nil, ns
end

-- ---------------------------------------------------------------------------
-- SoD enrich (W4.3, 2026-08-14): run the REAL shared/sod_context_sylvanas
-- enrich against the scenario context, after apply_battery_state has bound
-- the map-aware aura mocks. The enrich is fully pcall/type-guarded
-- internally, so a missing mock member degrades to nil instead of crashing.
-- heal_target: the enrich reads ctx.lowest_unit (the engine's lazy
-- party-scan field); the battery presents friendly units via
-- friendly_target_hp — mirror the engine's lowest-unit resolution so the
-- heal-target enrich blocks (Riptide / Lifebloom / Rejuvenation / Weakened
-- Soul on ctx.lowest) are observable in the friendly-target scenarios.
-- ---------------------------------------------------------------------------
function M.apply_sod_enrich(ns, ctx)
    if type(ctx) ~= "table" then return end
    if ctx.lowest_unit == nil and ns and type(ns.get_friendly_target_entry) == "function" then
        local ok_entry, entry = pcall(ns.get_friendly_target_entry)
        if ok_entry and type(entry) == "table" and entry.unit then
            ctx.lowest_unit = entry.unit
        end
    end
    local ok, enrich = pcall(require, "shared/sod_context_sylvanas")
    if ok and type(enrich) == "table" and type(enrich.enrich) == "function" then
        pcall(enrich.enrich, ctx)
    end
end

-- ---------------------------------------------------------------------------
-- Spec runner
-- ---------------------------------------------------------------------------
function M.run_spec(class_key, spec_key, scenarios, era, race_override)
    era = era or "sylvanas"
    scenarios = scenarios or M.SCENARIOS
    local result, load_err, ns = M.load_spec(class_key, spec_key, era, race_override)
    if not result then
        return nil, load_err
    end
    local strategies = (type(result) == "table") and (result.strategies or result) or nil
    if type(strategies) ~= "table" then
        return nil, "no strategies table returned for " .. class_key .. "/" .. spec_key
    end
    local build_state = (type(result) == "table") and result.build_state or nil
    -- Plain-style vanilla files return their bare strategies table and register
    -- get_state via the registry mock in build_ns; recover it here so stateful
    -- matchers see the real safe_state instead of the raw scenario ctx.
    if not build_state and ns and ns._registry and ns._registry.options
        and type(ns._registry.options.get_state) == "function" then
        build_state = ns._registry.options.get_state
    end
    -- Vanilla battery sweep (2026-08): kebab_vanilla registers
    -- `context_builder` (not get_state) — the engine dispatches it the same
    -- way (main_sylvanas.lua:1629-1630), so recover it here too or every
    -- kebab state read (target_below_20, sunder stacks) sees the raw ctx.
    if not build_state and ns and ns._registry and ns._registry.options
        and type(ns._registry.options.context_builder) == "function" then
        build_state = ns._registry.options.context_builder
    end

    local fired = {}
    local fired_in = {}
    local dispatch_errors = {}
    for _, s in ipairs(strategies) do
        if type(s) == "table" and type(s.name) == "string" then
            fired[s.name] = 0
            fired_in[s.name] = {}
        end
    end

    for _, sc in ipairs(scenarios) do
        local ctx = M.build_context_for(class_key, sc, era)
        M.apply_battery_state(ns, ctx, class_key)
        -- W4.3 (2026-08-14): SoD era runs the REAL sod_context enrich AFTER
        -- the state bank is applied so the map-aware mocks feed it — the
        -- battery exercises the production producer instead of hand-built
        -- fields (in_cat_form/in_bear_form from form, metamorphosis_active
        -- from buff_remains_map, flame_shock/serpent/DoT remains from
        -- debuff_remains_map, poison/sunder stacks from the id-scoped stacks
        -- bank, injured_count from party_injured_count, fire/water_totem_active
        -- from the get_totem_info bank, heal-target fields from the friendly
        -- unit when a friendly_target_hp scenario is active).
        if era == "sod" then M.apply_sod_enrich(ns, ctx) end
        local state = ctx
        if build_state then
            local ok, st = pcall(build_state, ctx)
            if not ok then
                -- build_state crashes were silently swallowed (state fell back
                -- to ctx); record them so the battery surfaces state-builder
                -- runtime bugs, not just match() errors.
                dispatch_errors[#dispatch_errors + 1] =
                    "build_state@" .. sc.name .. ": " .. tostring(st)
            elseif type(st) == "table" then
                state = st
            end
        end
        -- Dispatcher semantics: the real engine fires on any TRUTHY matcher
        -- return; the battery previously required `m == true`, which silently
        -- hid strategies whose matchers return an object (hunter MM/survival
        -- AdaptiveRotation return `c.target`). Truthy check mirrors the engine
        -- and can only shrink the never-list (pinned lanes all return boolean).
        for _, s in ipairs(strategies) do
            if type(s) == "table" and type(s.name) == "string" and type(s.matches) == "function" then
                local ok, m = pcall(s.matches, ctx, state)
                if not ok then
                    dispatch_errors[#dispatch_errors + 1] =
                        (s.name or "?") .. "@" .. sc.name .. ": " .. tostring(m)
                elseif m then
                    fired[s.name] = fired[s.name] + 1
                    fired_in[s.name][sc.name] = true
                end
            end
        end
    end

    local never = {}
    for name, count in pairs(fired) do
        if count == 0 then never[#never + 1] = name end
    end
    table.sort(never)
    return {
        fires_in = fired_in,
        fires = fired,
        never = never,
        dispatch_errors = dispatch_errors,
        strategy_count = #strategies,
    }, nil
end

-- ---------------------------------------------------------------------------
-- Run everything, return aggregate report
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Loud load-order guard (survey item #2): the require-time NS-caching hazard.
-- 79 shared/*_sylvanas.lua modules capture `local NS = _G.EaxRotations` at
-- require() time, and 8 write back into whatever NS is loaded (see the
-- _EAX_MOCK gates in auto_tremor/dot_refresh/execute_phase/melee_combat_math/
-- combat_forecast_gate/mf_tick_compute/purge_manager/ttd_tracker). If a tool
-- requires shared modules while a MOCK NS is installed (e.g. the scorecard's
-- compute() running before the battery, or a future tool dofiling specs), those
-- modules silently cache the mock — the pollution signature tracked by
-- tools/spec_scorecard.lua. The battery must ALWAYS see virgin shared modules:
-- this guard fails loudly at run_all entry if any shared module was already
-- loaded, and load_spec's restore block self-cleans after each spec so nothing
-- leaks to sibling suites in the same process.
function M.guard_shared_virgin()
    -- Only shared modules that bind to _G.EaxRotations AT REQUIRE TIME are a
    -- pollution hazard, in two forms:
    --   (1) top-level capture at column 0: `local X = _G.EaxRotations` (X is
    --       usually NS, but snapshot_sylvanas uses `_G_NS`) — the module is
    --       bound to whatever NS is installed when it loads, so a preloaded
    --       instance would keep referencing a discarded mock;
    --   (2) write-back binding: `_G.EaxRotations.FIELD = ...` (or an alias
    --       form `_G_NS.FIELD = ...`) at load time — the 8 gated modules'
    --       export blocks.
    -- LAZY references are harmless and must NOT trip the guard: spec_kit's
    -- `ns()` returns _G.EaxRotations at CALL time (spec_kit:48), and
    -- combat_forecast_gate captures it inside _is_boss() (line 15) — both
    -- resolve against the current _G at call time, so preloading them under a
    -- mock changes nothing. Pure utilities with zero NS references (e.g.
    -- shared/apl_parser, loaded by tools/apl_status.lua before the battery in
    -- the scorecard's process) are likewise exempt. The patterns below are
    -- column-anchored / write-form specific so lazy readers never false-
    -- positive, while a genuine require-time binder always fails loudly.
    local loaded = {}
    for k in pairs(package.loaded) do
        if type(k) == "string" and k:find("^shared/", 1) then
            local path = "EaxRotations/" .. k .. ".lua"
            local f = io.open(path, "rb")
            local hazardous = true  -- fail-closed: unreadable file is flagged
            if f then
                local src = f:read("*a")
                f:close()
                hazardous = false
                if src then
                    -- (1) top-level require-time capture at column 0, ANY
                    -- identifier (NS, _G_NS, ...): the capture line begins at
                    -- column 0 (`\nlocal` or file start), so lazy in-function
                    -- captures (indented) never match. File-start uses a real
                    -- PATTERN so `^` anchors (plain text would treat `^` as a
                    -- literal caret); the newline-prefixed form matches every
                    -- non-first line via plain text.
                    if src:find("\nlocal [%a_][%w_]* = _G.EaxRotations")
                        or src:find("^local [%a_][%w_]* = _G.EaxRotations") then
                        hazardous = true
                    end
                    -- (2) write-back binding: `_G.EaxRotations.FIELD = ...` at
                    -- load time (the 8 gated modules' export blocks). Matched
                    -- as an ASSIGNMENT (`=`) so doc comments like spec_kit:25's
                    -- "-- _G.EaxRotations. When NS is absent" never trip it.
                    -- The snapshot alias form `_G_NS.SnapshotHelper = M` is
                    -- caught via (1) (its top-level `_G_NS` capture).
                    if src:find("_G.EaxRotations%.[%a_][%w_]*%s*=") then
                        hazardous = true
                    end
                end
            end
            if hazardous then loaded[#loaded + 1] = k end
        end
    end
    if #loaded > 0 then
        table.sort(loaded)
        error("behavioral_audit: " .. #loaded .. " NS-capturing shared module(s) already "
            .. "loaded before the battery: " .. table.concat(loaded, ", ")
            .. " — these cache _G.EaxRotations at require() time, so a preloaded "
            .. "module would bind to whatever NS the caller installed (possibly a mock), "
            .. "the compute()-vs-battery pollution signature. Run the battery before any "
            .. "tool requires NS-capturing shared modules (see tools/spec_scorecard.lua "
            .. "POLLUTION_SIGNATURE).", 0)
    end
end

function M.run_all(era)
    era = era or "sylvanas"
    M.guard_shared_virgin()
    local manifest = M.ERA_MANIFESTS[era]
    if not manifest then
        error("behavioral_audit: unknown era '" .. tostring(era)
            .. "' (expected 'sylvanas', 'wotlk', 'vanilla' or 'sod')", 0)
    end
    -- W4.3 (2026-08-14): the SoD era runs the shared scenario set plus the
    -- SoD-specific shapes (M.SCENARIOS_SOD); every other era keeps the
    -- shared set (byte-identical to the pre-W4.3 runs).
    local scenarios = (era == "sod") and M.SCENARIOS_SOD or M.SCENARIOS
    local total = 0
    local reports = {}
    local load_failures = {}
    for class_key, specs in pairs(manifest) do
        for _, spec_key in ipairs(specs) do
            total = total + 1
            local report, err = M.run_spec(class_key, spec_key, scenarios, era)
            if not report then
                load_failures[#load_failures + 1] = class_key .. "/" .. spec_key .. ": " .. tostring(err)
            else
                -- Threat-family close-out (2026-08-10): race-variant merge.
                -- smite binds race at require time; RACE_VARIANTS loads the
                -- spec again per extra race and a lane stays never ONLY if it
                -- never fires under ANY variant (Starshards fires as night
                -- elf 4, DevouringPlague as undead 5 — both observable).
                -- Era-gated like RACE_OVERRIDES: a future WotLK-era smite load
                -- can't silently pick up the undead variant. If a variant load
                -- fails, never_set is left untouched (conservative: lanes stay
                -- never) and the failure surfaces via the load-failures pin.
                local _, variant_map = M.race_maps_for(era)
                local variants = variant_map and variant_map[spec_key]
                local never_set = {}
                for _, n in ipairs(report.never) do never_set[n] = true end
                local errs = {}
                for _, e in ipairs(report.dispatch_errors) do errs[#errs + 1] = e end
                if type(variants) == "table" then
                    for _, race in ipairs(variants) do
                        local vrep, verr = M.run_spec(class_key, spec_key, scenarios, era, race)
                        if not vrep then
                            load_failures[#load_failures + 1] = class_key .. "/" .. spec_key
                                .. " (race " .. tostring(race) .. "): " .. tostring(verr)
                        else
                            local vnever = {}
                            for _, n in ipairs(vrep.never) do vnever[n] = true end
                            for n in pairs(never_set) do
                                if not vnever[n] then never_set[n] = nil end
                            end
                            for _, e in ipairs(vrep.dispatch_errors) do errs[#errs + 1] = e end
                        end
                    end
                end
                local merged = {}
                for n in pairs(never_set) do merged[#merged + 1] = n end
                table.sort(merged)
                reports[#reports + 1] = {
                    class = class_key,
                    spec = spec_key,
                    never = merged,
                    strategy_count = report.strategy_count,
                    dispatch_errors = errs,
                }
            end
        end
    end
    -- Manifest drift: every *_<era>.lua under classes/ must appear in the era
    -- manifest, and every manifest entry must exist on disk. A new spec file
    -- that lands without a manifest row silently loses battery coverage —
    -- surface it as a load failure so the report AND verify_all's
    -- "Load failures: 0" pin catch it.
    local drift = M.check_manifest_drift(era)
    for _, rel in ipairs(drift.missing) do
        load_failures[#load_failures + 1] = "MANIFEST entry missing on disk: " .. rel
    end
    for _, rel in ipairs(drift.extra) do
        load_failures[#load_failures + 1] = "MANIFEST file not in " .. era .. " manifest: " .. rel
    end
    table.sort(reports, function(a, b)
        if a.class == b.class then return a.spec < b.spec end
        return a.class < b.class
    end)
    -- Self-cleaning battery (survey item #2): guard_shared_virgin() guarantees a
    -- virgin shared-module namespace at entry; evict everything we loaded so the
    -- NEXT run_all in the same process (the scorecard runs TBC then WotLK) also
    -- starts virgin, and so no sibling tool in the same process can reuse a
    -- shared module bound to one of our (discarded) mock NSes. Also drop the
    -- last mock from _G so a later tool that requires shared modules can't
    -- silently capture a battery mock (the compute()-vs-battery pollution bug).
    for k in pairs(package.loaded) do
        if type(k) == "string" and k:find("^shared/", 1) then
            package.loaded[k] = nil
        end
    end
    if _G.EaxRotations and _G.EaxRotations._EAX_MOCK then
        _G.EaxRotations = nil
    end
    return { total = total, era = era, reports = reports, class_failures = load_failures }
end

-- ---------------------------------------------------------------------------
-- Manifest drift check (reviewer-hardened): cross-check the era manifest
-- against the files actually on disk under classes/. Non-spec helper files
-- (class_/schema_/middleware_/healing_/cliptracker_/heal_helper_/shared_helpers_)
-- are excluded; TBC leveling files are covered by run_leveling_tests.lua, but
-- WotLK leveling files ARE battery specs, so the exclusion is era-aware.
-- ---------------------------------------------------------------------------
function M.check_manifest_drift(era)
    era = era or "sylvanas"
    local manifest = M.ERA_MANIFESTS[era] or M.SPEC_FILES
    local expected = {}
    for class_key, specs in pairs(manifest) do
        for _, spec_key in ipairs(specs) do
            expected[class_key .. "/" .. spec_key .. "_" .. era .. ".lua"] = true
        end
    end
    local non_spec = {
        "class_", "schema_", "middleware_", "healing_", "cliptracker_",
        "heal_helper_", "shared_helpers_",
    }
    if era == "sod" then
        -- W4.3 (2026-08-14): the SoD era has NO non-spec helper files under
        -- the _sod.lua suffix — priest/healing_sod.lua IS a spec (a real
        -- rotation, unlike the shared-module healing_sylvanas.lua), so the
        -- "healing_" exclusion must NOT apply or the manifest could silently
        -- drop the priest healing spec without drift complaining. Maximal
        -- strictness: every *_sod.lua file must have a manifest row.
        non_spec = {}
    end
    if era == "sylvanas" then
        -- TBC leveling files run via run_leveling_tests.lua, not the battery
        -- (WotLK AND vanilla leveling files ARE battery specs — WotLK by
        -- design, vanilla since the wave 1.4 coverage extension 2026-08-13).
        non_spec[#non_spec + 1] = "leveling_"
    end
    local drift = { missing = {}, extra = {} }
    local ok_lfs, lfs = pcall(require, "lfs")
    if not ok_lfs then return drift end
    local root = "EaxRotations/classes"
    for class_key in lfs.dir(root) do
        if class_key ~= "." and class_key ~= ".." then
            local dir = root .. "/" .. class_key
            local attrs = lfs.attributes(dir)
            if attrs and attrs.mode == "directory" then
                for fname in lfs.dir(dir) do
                    if fname:match("^.*_" .. era .. "%.lua$") then
                        local is_non_spec = false
                        -- Prefix match against the FULL filename (stem drops the
                        -- trailing _<era>, so a stem-based match would never see
                        -- e.g. "class_" inside "class_sylvanas").
                        for _, p in ipairs(non_spec) do
                            if fname:find(p, 1, true) == 1 then
                                is_non_spec = true
                                break
                            end
                        end
                        if not is_non_spec then
                            local rel = class_key .. "/" .. fname
                            if not expected[rel] then
                                drift.extra[#drift.extra + 1] = rel
                            end
                        end
                    end
                end
            end
        end
    end
    for rel in pairs(expected) do
        local f = io.open("EaxRotations/classes/" .. rel, "rb")
        if not f then
            drift.missing[#drift.missing + 1] = rel
        else
            f:close()
        end
    end
    return drift
end

-- ---------------------------------------------------------------------------
-- Printer
-- ---------------------------------------------------------------------------
function M.print_report(agg)
    local era_label = (agg.era == "wotlk") and "wotlk"
        or ((agg.era == "vanilla") and "vanilla"
        or ((agg.era == "sod") and "sod" or "sylvanas"))
    print("=============================================================================")
    print("  BEHAVIORAL BATTERY AUDIT (" .. tostring(agg.total) .. " " .. era_label .. " specs)")
    print("=============================================================================")
    for _, f in ipairs(agg.class_failures) do
        print("  [ LOAD FAIL ] " .. f)
    end
    for _, r in ipairs(agg.reports) do
        local header = string.format("  [ %-9s %-22s ] strategies=%d never-fires=%d",
            r.class, r.spec, r.strategy_count, #r.never)
        print(header)
        if #r.dispatch_errors > 0 then
            for _, e in ipairs(r.dispatch_errors) do
                print("      dispatch ERR: " .. e)
            end
        end
        for _, name in ipairs(r.never or {}) do
            print("      NEVER: " .. name)
        end
    end
    print("")
    print("  Total: " .. tostring(agg.total) .. " | Load failures: " .. tostring(#(agg.class_failures or {})))
    print("  NOTE: every 'never' strategy is a TRIAGE candidate (must be reviewed)")
    print("=============================================================================")
end

-- Standalone entry: `lua EaxRotations/tests/behavioral_audit.lua [wotlk|vanilla|sod]`
-- Direct runs are detected via arg[0] (the invoked script path), NOT via
-- select("#", ...): in Lua 5.1 the main chunk's `...` IS the CLI args, but the
-- spec scorecard loads this file via loadfile + chunk('scorecard'), which also
-- makes select("#", ...) == 1 — so a vararg-only guard would either skip the
-- direct run (typo'd era silently no-ops) or mis-fire under loadfile. arg[0]
-- contains "behavioral_audit" only for genuine direct runs. Unknown eras error
-- out with usage instead of silently producing no report.
if arg and arg[0] and arg[0]:find("behavioral_audit", 1, true) then
    local cli_era = arg[1]
    if cli_era and cli_era ~= "wotlk" and cli_era ~= "vanilla" and cli_era ~= "sod" then
        io.stderr:write("behavioral_audit: unknown era '" .. tostring(cli_era)
            .. "' — expected 'wotlk', 'vanilla', 'sod' or no argument (default sylvanas)\n")
        os.exit(1)
    end
    local era = (cli_era == "wotlk") and "wotlk"
        or ((cli_era == "vanilla") and "vanilla"
        or ((cli_era == "sod") and "sod" or "sylvanas"))
    local agg = M.run_all(era)
    M.print_report(agg)
end

return M