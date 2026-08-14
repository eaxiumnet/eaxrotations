-- run_read_side_audit_tests.lua -- Static audit: no rotation field may be READ
-- if NO producer anywhere writes it.
-- WHAT:  Scans every class file (sylvanas / vanilla / wotlk / sod / leveling)
--        plus shared/ for READS of rotation-context fields (context./ctx./c.)
--        and per-frame state fields (state./st./s./<x>_state./safe_state arg)
--        and fails if a read field has NO WRITER of the same class ANYWHERE in
--        the tracked tree — the engine (main_sylvanas lazy context + static
--        writes), the battery mock's ctx construction (behavioral_audit.lua),
--        middleware, shared modules, and other class files. This is the
--        read-side complement of run_state_field_audit_tests.lua (which can
--        only see WRITES): the read-side catches the computed-nowhere defect
--        class — a matcher/strategy reading a field no producer ever sets.
--        Three of the 2026-08-11 vanilla-sweep live defects were exactly this
--        shape:
--          * assassination_vanilla read context.combo while the engine sets
--            ctx.combo_points (main_sylvanas.lua:856)
--          * balance_vanilla + elemental_vanilla gated on (s.spell_damage or
--            0) / (state.spell_damage or 0) — nothing in the tree writes
--            spell_damage (the engine never populates ctx.spell_damage)
--          * warlock affliction/demonology read context.enemy_shadow_caster,
--            which the engine never sets (fixed via target:get_class()
--            fallback mirroring shared/warlock_shadow_ward_sylvanas.lua)
--        The write-side audit cannot see these (the fields were never written,
--        so "written-but-unread" did not apply); nothing guarded the read side.
-- Resolver rules (validated against the real tree):
--   Receiver classes:
--     CONTEXT class: context / ctx / _context / c  (the rotation context
--       passed to build_state + matchers; produced by the engine and the
--       battery mock).
--     STATE class:   state / st / s / every written ident ending in `_state`
--       (per-frame state tables) / every spec_kit.safe_state(...) first arg.
--       Bare `s` is included because vanilla matchers read state through the
--       `(c, s)` signature; the strategy-table contract fields it collides
--       with are allowlisted below with evidence (STRATEGY_CONTRACT).
--   Writes:
--     `RECV.field =` (a trailing `==` is a comparison, not a write) for both
--     classes, PLUS the engine's lazy-context producers:
--       main_sylvanas.lua `_context.X =` static writes and
--       `_context._register("X", ...)` string keys, PLUS the battery mock's
--       ctx-construction surface (tests/behavioral_audit.lua): the static
--       `ctx.X =` writes in build_context_for and every key of its `known`
--       whitelist table (`ctx[k] = v` dynamic write). The battery counts as a
--       producer because it must be able to construct every ctx field a spec
--       reads in CI (a battery-only field is mock-only and documented, not a
--       defect).
--   Reads: every `RECV.field` token in the comment-stripped content PLUS the
--     declarative DSL condition reads (shared/strategy_dsl_sylvanas.lua
--     condition_evaluators):
--       { type = "state",   field = "X" } -> state-class read of X
--       { type = "context", field = "X" } -> context-class read of X
--       implicit conditions (in_combat / enemy_count / distance / stance /
--       is_pvp / execute_phase / hp_threshold) evaluate `state.X or
--       context.X` (strategy_dsl:136-181), so they count as reads of BOTH
--       classes (permissive — either producer satisfies them).
--   Method calls (target:is_casting(), target:get_class(), NS.buff_up(...))
--     are NOT field reads — their receivers (target / NS / me / unit ...) are
--     not in either receiver class, so they never match.
--   Comment text and SCHEMA bare keys never count (no leading dot).
--   A read field is UNPRODUCED iff its class has ZERO writers of that field
--   name across the whole tracked writer set (engine + battery + shared +
--   middleware + every class file).
--   Cross-class aliasing is NOT allowed: a context read needs a context
--   writer (state.combo does not satisfy context.combo — that exact aliasing
--   was the assassination defect).
--   Findings must be triaged with evidence before acting: a genuine defect
--   (read of a field nothing produces, like the three above) -> fix per
--   precedent (provide the field at the source or change the read to the
--   real field/helper) with a non-vacuity test; legitimately dynamic or
--   mock-only -> document in the NO_WRITER_ALLOWLIST with the evidence.
-- WHEN:  Run manually, in CI (verify_all), and in the pre-commit gate.
-- WHY:   A matcher reading a field no producer sets silently evaluates the
--        nil default every frame (Pattern 14 makes that nil-guarded, so the
--        strategy is quietly DEAD in live play and the battery may report it
--        never-firing for reasons that look like scenario shape).
-- SAFETY: Read-only text scan + static classification; --self-test has no
--        filesystem writes (synthetic in-memory content only).
--
-- ALLOWLIST: verified dynamic / mock-only / strategy-contract reads. Each
-- entry is pinned with the evidence so it cannot silently drift.
local NO_WRITER_ALLOWLIST = {
    -- context.settings: read by every spec_kit.setting/setting_bool call and
    -- direct ctx.settings[...] matcher reads. The engine's lazy context never
    -- registers 'settings' (main_sylvanas.lua) — spec_kit.setting resolves
    -- context.settings FIRST and falls back to NS.get_setting when nil, so a
    -- nil context.settings is the documented live path, not a defect. The
    -- battery materializes it via ctx.settings[k] = v (behavioral_audit.lua
    -- setting_overrides). Dynamic-by-design.
    context = {
        settings = "engine never sets context.settings (spec_kit.setting falls back to NS.get_setting); battery materializes via setting_overrides",

        -- spell_damage (10 sites: shadow/elemental/affliction/demonology/
        -- destruction, both eras): the state writes `X_state.spell_damage =
        -- context.spell_damage or 0` are a designed extension point. Phase 2.1
        -- (2026-08-13) wired the producer: main_sylvanas.lua populates
        -- context.spell_damage ONLY when the player_spell_damage menu setting
        -- is > 0 (2s-throttled read). Default 0 = field absent = byte-identical
        -- to the pre-Phase-2.1 behavior (0-degradation documented); with 0 the
        -- snapshot-upgrade thresholds degenerate to the documented
        -- no-snapshot-refresh behavior, and the min-SP gates (balance/
        -- elemental/destruction Immolate) stay inert. Entry retained as the
        -- 0-degradation contract note (inert while the field is produced).
        spell_damage = "engine produces it only when player_spell_damage setting > 0 (Phase 2.1); 0-degradation contract note",

        -- enemy_shadow_caster (shared/warlock_shadow_ward:36 + affliction/
        -- demonology vanilla:769/686): the engine never sets it; every read
        -- is `context.enemy_shadow_caster or (target:get_class()==5/9)` — the
        -- 2026-08 sweep-fixed fallback contract (ShadowWard now works via
        -- get_class when the context field is absent).
        enemy_shadow_caster = "sweep-fixed fallback contract (target:get_class()); engine never sets it",

        -- physical_dps_count (affliction/demonology/destruction sylvanas):
        -- opt-in curse auto-selection (warlock_curse_group_aware, default
        -- OFF). The Recklessness branch degrades to Curse of Elements when
        -- the count is absent — a documented degraded feature, not a defect.
        physical_dps_count = "opt-in curse feature; degrades to CoE when absent",

        -- friendly_target / friendly_target_deficit (paladin/priest/shaman
        -- healing): the engine never writes context.friendly_target, and the
        -- battery DELIBERATELY does not materialize it (behavioral_audit.lua
        -- :725-733 documents the collision with healing_sylvanas:454). The
        -- friendly-target feature lives on NS.get_friendly_target_entry
        -- (state.friendly_target in resto/holy); these direct reads are a
        -- dead-but-harmless legacy path.
        friendly_target = "battery-documented collision; feature lives on get_friendly_target_entry",
        friendly_target_deficit = "same battery-documented legacy path as friendly_target",

        -- has_feral_druid (balance sylvanas + vanilla): a party feral-druid
        -- scan the engine never wires; nil means the FaerieFire armor check
        -- may over-cast when a feral druid is present — minor, degrades
        -- gracefully (extension point).
        has_feral_druid = "extension point (party feral scan not wired); nil degrades gracefully",

        -- is_target_player / cp (cat sylvanas + vanilla + druid leveling):
        -- legacy aliases with documented fallbacks — is_target_player falls
        -- through to context.target_is_player then target:is_player(); cp
        -- falls back after context.combo_points (cat_sylvanas:349-353).
        is_target_player = "legacy alias with target:is_player() method terminal",
        cp = "legacy alias for combo_points (produced sibling read first)",

        -- pyroblast_ready (fire): legacy fallback — state.pyroblast_ready is
        -- always computed (fire_sylvanas:146); the context read sits mid-chain
        -- and is unreachable live.
        pyroblast_ready = "legacy fallback behind always-computed state.pyroblast_ready",

        -- time_to_swing (retribution sylvanas + vanilla): last link of the
        -- CLEU -> NS.get_time_until_swing -> context.time_to_swing -> 0 swing
        -- chain; engine never writes it, so it always falls to 0.
        time_to_swing = "legacy fallback tail of the CLEU swing-timer chain",

        -- target_phys_immune (smite sylvanas + vanilla): defensive optional
        -- check; nil means the check never blocks (smite is holy damage).
        target_phys_immune = "defensive optional check; nil-safe false",

        -- distance (hunter BM/survival sylvanas): legacy fallback behind the
        -- always-written state.distance_sq (`s.distance_sq or (context.distance
        -- ...) or 10000`) — unreachable live, benign.
        distance = "legacy fallback behind always-written state.distance_sq",

        -- WotLK hunter aspects (viper_up / dragonhawk_up / target_remaining_time,
        -- BM/MM/SV): optional context enrichment — every read is gated by
        -- `context and context.X ~= nil then ... else <buff/debuff fallback>`
        -- (beast_mastery_wotlk:62-70), so absent context degrades to the
        -- buff check. Same pattern as elemental_wotlk totems.
        viper_up = "optional context enrichment with buff fallback (wotlk hunters)",
        dragonhawk_up = "optional context enrichment with buff fallback (wotlk hunters)",
        target_remaining_time = "optional context enrichment with 100 default (wotlk hunters)",

        -- elemental_wotlk / enhancement_wotlk: optional context enrichment
        -- with NS.buff_up fallback (`if context and context.X ~= nil then ...
        -- else <buff check>`).
        fire_elemental_active = "optional context enrichment with buff fallback (elemental_wotlk)",
        totem_of_wrath_up = "optional context enrichment with buff fallback (elemental_wotlk)",
        searing_totem_up = "optional context enrichment with buff fallback (elemental_wotlk)",
        lightning_shield_up = "optional context enrichment with buff fallback (enhancement_wotlk)",
        in_melee = "optional context enrichment with distance fallback (protection_sylvanas:671-678)",

        -- is_boss (warrior/arms_wotlk:143 + deathknight/unholy_wotlk:127):
        -- W3.3-era legacy compat reads KEPT FOR BATTERY MOCKS; both files read
        -- the REAL engine field context.target_is_boss (main_sylvanas.lua:1287)
        -- FIRST, so the legacy line is inert live and (since W3.4, 2026-08-13)
        -- inert in the battery too — behavioral_audit.lua no longer feeds
        -- ctx.is_boss (the arms_retaliation/dk_boss scenarios drive
        -- target_is_boss). The engine never produces context.is_boss. Targeted
        -- fix (W3.4 triage addendum): delete the legacy line in both files.
        is_boss = "legacy battery-mock compat read behind produced context.target_is_boss; inert live (W3.4 addendum)",

        -- SOD context contract: the _sod files' rotation-state fields. The
        -- 2026-08 read-side audit flagged ~25 as read-but-unproduced (every
        -- _sod rotation degraded to defaults, several to a fully-dead
        -- rotation); the SOD-context wiring unit (2026-08-11) closed it by
        -- adding shared/sod_context_sylvanas.lua (enrich() wired into
        -- main_sylvanas:1239 is_sod block) which now produces form, pet hp,
        -- poison stacks, shield/imbue/HoT/refresh-remains, Maelstrom stacks,
        -- and swing-timer fields. The audit's string-key resolver was also
        -- extended to see value(context,"X")/number(context,"X") reads
        -- (feral/tank/warlock/hunter/warrior refresh-state family). Remaining
        -- pins below are fields with a WORKING fallback or no API source.
        pet_alive = "SOD: working fallback (ctx.pet ~= nil and not ctx.pet_dead) in dps_hunter/warlock files",
        heal_target_hp_pct = "SOD: working fallback (ctx.lowest.hp) in druid resto build_state",
        holy_shield_charges = "SOD: working fallback (NS.buff_points) in protection_sod build_state",
        dual_daggers = "SOD: no weapon-type API; fail-open gate (nil ~= false allows Mutilate)",
        -- W4.2: offhand_imbue / water_totem_active / fire_totem_active pins
        -- REMOVED — the reads are now produced: offhand_imbue gate dropped in
        -- enhancement_sod (W4.2), totem slots wired in sod_context enrich via
        -- NS.get_totem_info (elemental_wotlk.lua:42 slot map 1=fire/3=water).
    },
    -- Per-file allowlist: module-internal records / settings aliases that the
    -- state/context receiver name collision surfaces (the `state`/`s`/`c`
    -- locals in shared modules are module records, not rotation state).
    ["EaxRotations/shared/aura_probe_sylvanas.lua"] = {
        context = {
            raw = "probe-result record fields (c = loop var over checks[])",
            unit_buff = "probe-result record fields (c = loop var over checks[])",
            unit_aura = "probe-result record fields (c = loop var over checks[])",
            bm_buff = "probe-result record fields (c = loop var over checks[])",
            bm_aura = "probe-result record fields (c = loop var over checks[])",
        },
    },
    ["EaxRotations/shared/hot_tick_tracker_sylvanas.lua"] = {
        state = {
            bloom_in = "hot-state record field (st = M.get() result; written via constructor at :230)",
        },
    },
    ["EaxRotations/shared/interrupt_manager_sylvanas.lua"] = {
        state = {
            detected_at = "humanize-cache record field (constructor-written :233-238)",
            jitter = "humanize-cache record field (constructor-written :233-238)",
        },
    },
    ["EaxRotations/shared/menu_theme_sylvanas.lua"] = {
        context = {
            new = "c is the local color module (common/color); c.new is the color constructor, not a context read",
        },
    },
    ["EaxRotations/shared/rune_manager_sylvanas.lua"] = {
        state = {
            ready = "rune-state record field (return-constructor at :88-94)",
        },
    },
    ["EaxRotations/shared/presence_manager_sylvanas.lua"] = {
        context = {
            role = "defaults chain (state.role or context.role or 'dps'); explicit presence targets drive switching",
            spec = "defaults chain (state.spec or context.spec or 'blood'); explicit presence targets drive switching",
            movement = "defaults chain (state.movement or context.movement or {}); explicit presence targets drive switching",
            presence = "defaults chain (state.presence or context.presence or PRESENCE.BLOOD)",
        },
        state = {
            role = "defaults chain (state.role or context.role or 'dps'); explicit presence targets drive switching",
            spec = "defaults chain (state.spec or context.spec or 'blood'); explicit presence targets drive switching",
            movement = "defaults chain (state.movement or context.movement or {}); explicit presence targets drive switching",
        },
    },
    ["EaxRotations/shared/stealth_helper_sylvanas.lua"] = {
        state = {
            stealth_enabled = "s = context.settings alias; undeclared setting read with default (DEFAULT enabled)",
            stealth_max_yd = "s = context.settings alias; undeclared setting read with DEFAULT_MAX_YD fallback",
            stealth_min_yd = "s = context.settings alias; undeclared setting read with DEFAULT_MIN_YD fallback",
        },
    },
    ["EaxRotations/classes/paladin/heal_helper_sylvanas.lua"] = {
        state = {
            -- has_illumination: a talent check the healer state never computes.
            -- Always-false makes expected mana costs conservative (no discount),
            -- which is safe; wiring get_talent_info is a separate unit.
            has_illumination = "talent check never computed by healing state; always-false is conservative (safe)",
        },
    },
}

-- Strategy-table contract fields: read when code iterates the strategies
-- table (`for _, s in ipairs(strategies)` / DSL compiler reads), but written
-- by TABLE CONSTRUCTOR bare keys (`{ name = "X", matches = fn }`), which are
-- invisible to the dot-write scanner. These are reads of the strategies
-- table, not of the rotation state, and are never flagged.
local STRATEGY_CONTRACT = {
    name = true, matches = true, execute = true, spell = true, target = true,
    kind = true, form = true, required_form = true, required_stance = true,
    min_rage = true, min_energy = true, min_mana = true, ooc = true,
    requires_target = true, requires_in_combat = true,
    requires_not_in_combat = true, debuff = true, refresh = true,
    buff = true, is_burst = true, is_gcd_gated = true, position = true,
    hit_radius = true, hit_origin = true, not_moving = true, cooldown = true,
    ids = true, opts = true, rank = true, label = true, unit = true, op = true,
    value = true, invert = true, conditions = true, condition = true,
    field = true, type = true, key = true, default = true, reason = true,
}

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local WRITER_ROOTS = {
    "EaxRotations/classes", "EaxRotations/shared",
    "EaxRotations/main_sylvanas.lua", "EaxRotations/core_sylvanas.lua",
    "EaxRotations/main.lua", "EaxRotations/helpers_sylvanas.lua",
    "EaxRotations/common_sylvanas.lua", "EaxRotations/gear_sets_sylvanas.lua",
    "EaxRotations/tests/behavioral_audit.lua",
}
local READER_ROOTS = { "EaxRotations/classes", "EaxRotations/shared" }

-- ---------------------------------------------------------------------------
-- Comment stripping: same implementation as the write-side audit.
-- ---------------------------------------------------------------------------
local function strip_comments(content)
    local pieces = {}
    local pos = 1
    local len = #content
    while pos <= len do
        local s = content:find("%-%-", pos)
        if not s then
            pieces[#pieces + 1] = content:sub(pos)
            break
        end
        pieces[#pieces + 1] = content:sub(pos, s - 1)
        local eq = content:match("^%-%-%[(=*)%[", s)
        if eq then
            local close = content:find("%]" .. eq .. "%]", s + 3 + #eq)
            if close then
                pieces[#pieces + 1] = content:sub(s, close + #eq + 1):gsub(".", " ")
                pos = close + #eq + 2
            else
                pieces[#pieces + 1] = content:sub(s):gsub(".", " ")
                pos = len + 1
            end
        else
            local nl = content:find("\n", s + 2)
            if nl then
                pieces[#pieces + 1] = content:sub(s, nl - 1):gsub(".", " ")
                pos = nl
            else
                pieces[#pieces + 1] = content:sub(s):gsub(".", " ")
                pos = len + 1
            end
        end
    end
    return table.concat(pieces)
end

local CTX_RECV = { context = true, ctx = true, _context = true, c = true }
local STATE_RECV = { state = true, st = true, s = true }

-- Safe-state-arg + written *_state idents: resolved per file.
local function collect_file_state_names(stripped)
    local names = {}
    for n in stripped:gmatch("spec_kit%.safe_state%(([%a_][%w_]*)") do
        if n and n ~= "nil" then names[n] = true end
    end
    for ident in stripped:gmatch("([%a_][%w_]*)%.[%a_][%w_]*%s*=") do
        if ident:sub(-6) == "_state" and ident:sub(1, 1) ~= "_" then names[ident] = true end
    end
    -- multi-assignment writes also signal *_state names
    for ident in stripped:gmatch("([%a_][%w_]*)%.[%a_][%w_]*(?:%s*,%s*[%a_][%w_]*%.[%a_][%w_]*)*%s*=") do
        if ident:sub(-6) == "_state" and ident:sub(1, 1) ~= "_" then names[ident] = true end
    end
    return names
end

local function is_ctx_recv(name) return CTX_RECV[name] == true end
local function is_state_recv(name, state_names)
    return STATE_RECV[name] == true or state_names[name] == true
end

-- ---------------------------------------------------------------------------
-- Settings producers: a state-class read of a settings key (the `local s =
-- context.settings` alias pattern in build_state — `s.enhancement_combat_mode`
-- is a SETTINGS read, not a state read) is satisfied when a setting with that
-- id is declared anywhere (declarative menu `{ id = "key" }` entries, or a
-- settings-accessor call referencing the key). Collected across all writer
-- files; menu ids and accessor keys are the settings system's writers.
-- ---------------------------------------------------------------------------
local function collect_settings_writers(content)
    local stripped = strip_comments(content)
    local writers = {}
    local function add(key)
        if key and key:match("^[a-z][%w_]*$") then writers[key] = true end
    end
    -- Declarative menu entries: { id = "key", ... }
    for key in stripped:gmatch('id%s*=%s*"([%w_]+)"') do add(key) end
    -- Schema menu declarations: { key = "...", type = ... } (all 687 schema keys)
    for key in stripped:gmatch('key%s*=%s*"([%w_]+)"') do add(key) end
    -- settings-accessor calls (key is 1st arg for get_*, 2nd for setting*)
    for key in stripped:gmatch('get_setting%(%s*"([%w_]+)"') do add(key) end
    for key in stripped:gmatch('get_any_setting%(%s*"([%w_]+)"') do add(key) end
    for key in stripped:gmatch('setting_bool%(%s*[%w_.]+%s*,%s*"([%w_]+)"') do add(key) end
    for key in stripped:gmatch('setting_number%(%s*[%w_.]+%s*,%s*"([%w_]+)"') do add(key) end
    for key in stripped:gmatch('setting_float%(%s*[%w_.]+%s*,%s*"([%w_]+)"') do add(key) end
    for key in stripped:gmatch('%.setting%(%s*[%w_.]+%s*,%s*"([%w_]+)"') do add(key) end
    for key in stripped:gmatch('^setting%(%s*[%w_.]+%s*,%s*"([%w_]+)"') do add(key) end
    -- plain `setting(context, "key"` local-helper form (Pattern 8) without
    -- a dot prefix on the same line
    for key in stripped:gmatch('setting%(%s*context%s*,%s*"([%w_]+)"') do add(key) end
    -- battery setting_overrides table keys
    for key in stripped:gmatch('setting_overrides%s*=%s*%{[^}]*%b""') do end
    for key in stripped:gmatch('%[%s*"([%w_]+)"%s*%]%s*=%s*') do add(key) end
    return writers
end

-- ---------------------------------------------------------------------------
-- Writer extraction: { context = { field = true }, state = { field = true } }
-- ---------------------------------------------------------------------------
local function collect_writers(content, is_battery)
    local stripped = strip_comments(content)
    local state_names = collect_file_state_names(stripped)
    local writers = { context = {}, state = {} }

    -- Line-based writes: every dot-token on the LHS of a real assignment in a
    -- line is a WRITE. Handles single + multi assignment (a.b, c.d = v),
    -- MULTIPLE statements on one line (protection_sylvanas.lua:316
    -- `prot_state.shield_block_ready = ... prot_state.dev_ready = ...` — the
    -- dev_ready write was missed by the old first-`=`-only scan), excludes
    -- == / >= / <= / ~= comparisons, and lets constructor bare keys pass
    -- through (no dot receiver).
    local s2 = stripped
    if s2:sub(-1) == "\n" then s2 = s2:sub(1, -2) end
    local lines = {}
    for line in (s2 .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line:gsub("\r$", "")
    end
    local function add_write(recv, field)
        if field:sub(1, 1) == "_" then return end
        if is_ctx_recv(recv) then
            writers.context[field] = true
        elseif is_state_recv(recv, state_names) then
            writers.state[field] = true
        end
    end
    -- Every `ident.ident` token on the LHS of a REAL `=` is a write:
    -- multi-assignment (`s.ab_stacks, s.ab_remains = ...`), multi-statement
    -- lines (protection_sylvanas.lua:316 `a = ... b = ...`), and plain single
    -- assignments. A real `=` is one whose previous char is not =/</>/~ AND
    -- whose next char is not `=` (so `==`, `<=`, `>=`, `~=` comparisons never
    -- produce writes).
    for _, line in ipairs(lines) do
        local pos = 1
        while pos <= #line do
            local eq = nil
            for p = pos, #line do
                if line:sub(p, p) == "=" then
                    local prev = line:sub(p - 1, p - 1)
                    local next = line:sub(p + 1, p + 1)
                    if prev ~= "=" and prev ~= "<" and prev ~= ">" and prev ~= "~"
                        and next ~= "=" then
                        eq = p
                        break
                    end
                end
            end
            if not eq then break end
            for recv, field in line:sub(pos, eq - 1):gmatch("([%a_][%w_]*)%.([%a_][%w_]*)") do
                add_write(recv, field)
            end
            pos = eq + 1
        end
    end
    -- SOD safe_state constructors: the FIRST argument of
    -- `spec_kit.safe_state({ key = value, ... }, schema)` is the per-frame
    -- state write (feral_sod.lua:32 `in_cat_form = value(context, ...)`).
    -- These bare keys are real state producers (unlike the Pattern-4
    -- pre-allocated defaults tables, which this audit deliberately does NOT
    -- count — a defaulted-but-never-refreshed field is exactly the defect
    -- class it exists to catch).
    local pos = 1
    while true do
        local start = stripped:find("spec_kit.safe_state(", pos, true)
        if not start then break end
        pos = start + #"spec_kit.safe_state("
        local open = stripped:find("{", pos)
        if open then
            local depth, i = 1, open
            while depth > 0 do
                i = stripped:find("[{}]", i + 1)
                if not i then break end
                if stripped:sub(i, i) == "{" then depth = depth + 1 else depth = depth - 1 end
            end
            if i then
                local block = stripped:sub(open, i)
                for key in block:gmatch("([%a_][%w_]*)%s*=") do
                    if key:sub(1, 1) ~= "_" and not STRATEGY_CONTRACT[key] then
                        writers.state[key] = true
                    end
                end
            end
        end
    end
    -- Settings producers for this file (merged into the state-class writers
    -- by the caller: a settings key read via the settings alias is produced).
    writers.settings = collect_settings_writers(content)
    -- Engine lazy-context producers: _context._register("X", ...) string keys
    -- and _context.X = static writes (the latter already captured above via
    -- the `_context` receiver; the _register strings need explicit capture).
    for field in stripped:gmatch("_context%._register%(\"([%a_][%w_]*)\"") do
        writers.context[field] = true
    end
    -- Battery mock: build_context_for known-keys whitelist (`ctx[k] = v`
    -- dynamic write) + static ctx.X = writes (captured above via `ctx`).
    if is_battery then
        local known_start = stripped:find("local known = {", 1, true)
        if known_start then
            local depth, i = 1, known_start + #"local known = {"
            local _, close = stripped:find("{", known_start, true)
            while depth > 0 do
                i = stripped:find("[{}]", i + 1)
                if not i then break end
                if stripped:sub(i, i) == "{" then depth = depth + 1 else depth = depth - 1 end
            end
            if i then
                local block = stripped:sub(known_start, i)
                for key in block:gmatch("([%a_][%w_]*)%s*=%s*true") do
                    writers.context[key] = true
                end
            end
        end
    end
    return writers
end

-- ---------------------------------------------------------------------------
-- Read extraction per file: { context = { field = {line} }, state = {...} }
-- ---------------------------------------------------------------------------
local function collect_reads(content)
    local stripped = strip_comments(content)
    local state_names = collect_file_state_names(stripped)
    local lines = {}
    if stripped:sub(-1) == "\n" then stripped = stripped:sub(1, -2) end
    for line in (stripped .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line:gsub("\r$", "")
    end

    local reads = { context = {}, state = {} }
    -- by_line[cls][line][field] = true : every field READ on that line, used
    -- for the legacy-fallback sibling rule (an unproduced read is accepted
    -- when the same line reads a PRODUCED field of the same class and the
    -- expression is an `or` chain — `ctx.mana_pct or ctx.mana or 100`).
    local by_line = { context = {}, state = {} }
    -- implicit[field] = true : fields read by IMPLICIT DSL conditions, which
    -- the evaluator resolves as `state.X or context.X` (either class
    -- producer satisfies them — strategy_dsl:136-181).
    local implicit = {}
    local function add(cls, field, line)
        reads[cls][field] = reads[cls][field] or {}
        local list = reads[cls][field]
        if list[#list] ~= line then list[#list + 1] = line end
        by_line[cls][line] = by_line[cls][line] or {}
        by_line[cls][line][field] = true
    end

    -- Write-target exclusion: an `ident.ident` token immediately followed by
    -- a REAL `=` is an assignment TARGET (a write, not a read) — same
    -- positional scan as collect_writers (handles multi-assignment LHS and
    -- multi-statement lines; skips == / <= / >= / ~=).
    local function is_write_target(line, token_start, token_end)
        local p = token_end + 1
        while p <= #line and line:sub(p, p):match("%s") do p = p + 1 end
        if line:sub(p, p) ~= "=" then return false end
        local prev = line:sub(p - 1, p - 1)
        local next = line:sub(p + 1, p + 1)
        return prev ~= "=" and prev ~= "<" and prev ~= ">" and prev ~= "~" and next ~= "="
    end

    for i = 1, #lines do
        local line = lines[i]
        for s, recv, field, e in line:gmatch("()([%a_][%w_]*)%.([%a_][%w_]*)()") do
            if is_write_target(line, s, e) then
                -- LHS of a real assignment — a write, not a read
            elseif is_ctx_recv(recv) then
                if field:sub(1, 1) ~= "_" then add("context", field, i) end
            elseif is_state_recv(recv, state_names) then
                if field:sub(1, 1) ~= "_" then add("state", field, i) end
            end
        end
    end

    -- Declarative DSL condition reads (strategy_dsl condition_evaluators).
    local function read(field)
        implicit[field] = true
        add("context", field, 0)
        add("state", field, 0)
    end
    for f in stripped:gmatch('type%s*=%s*"state"%s*,%s*field%s*=%s*"([%a_][%w_]*)"') do
        add("state", f, 0)
    end
    for f in stripped:gmatch('field%s*=%s*"([%a_][%w_]*)"%s*,%s*type%s*=%s*"state"') do
        add("state", f, 0)
    end
    for f in stripped:gmatch('type%s*=%s*"context"%s*,%s*field%s*=%s*"([%a_][%w_]*)"') do
        add("context", f, 0)
    end
    for f in stripped:gmatch('field%s*=%s*"([%a_][%w_]*)"%s*,%s*type%s*=%s*"context"') do
        add("context", f, 0)
    end
    -- Implicit conditions evaluate `state.X or context.X` (both classes).
    for _ in stripped:gmatch('type%s*=%s*"in_combat"') do read("in_combat") end
    for _ in stripped:gmatch('type%s*=%s*"enemy_count"') do read("enemy_count") end
    for _ in stripped:gmatch('type%s*=%s*"enemy_count"') do read("enemies_count") end
    for _ in stripped:gmatch('type%s*=%s*"distance"') do read("target_distance") end
    for _ in stripped:gmatch('type%s*=%s*"stance"') do read("stance") end
    for _ in stripped:gmatch('type%s*=%s*"is_pvp"') do read("is_pvp") end
    for _ in stripped:gmatch('type%s*=%s*"execute_phase"') do read("execute_phase") end
    for unit in stripped:gmatch('type%s*=%s*"hp_threshold"%s*,%s*unit%s*=%s*"([a-z]+)"') do
        if unit == "self" then read("hp") elseif unit == "target" then read("target_hp") else read("lowest_hp") end
    end

    -- SOD string-key state reads: feral_sod `value(context, "X", default)`
    -- and the tank/warlock/hunter files' `number(context, "X", default)`
    -- helpers read rotation-context fields through a string key, not a
    -- recv.field token. Without this the whole feral/tank refresh-state
    -- family was invisible to the audit (2026-08 SOD context wiring unit).
    -- A non-identifier char must precede `number(`/`value(` so that
    -- spec_kit.setting_number(...) / setting_bool(...) (settings reads, not
    -- rotation-context reads) are NOT captured.
    for pre, f in stripped:gmatch('([^%w_])value%s*%(%s*context%s*,%s*"([%a_][%w_]*)"') do
        if pre ~= "_" then add("context", f, 0) end
    end
    for pre, f in stripped:gmatch('([^%w_])number%s*%(%s*context%s*,%s*"([%a_][%w_]*)"') do
        if pre ~= "_" then add("context", f, 0) end
    end

    return { reads = reads, by_line = by_line, implicit = implicit, lines = lines }
end

-- ---------------------------------------------------------------------------
-- Full writer pass: aggregate context/state writers across every tracked
-- engine/battery/shared/class file.
-- ---------------------------------------------------------------------------
local function collect_all_writers()
    local writers = { context = {}, state = {}, settings = {} }
    local files = {}
    for _, root in ipairs(WRITER_ROOTS) do
        if root:match("%.lua$") then
            files[#files + 1] = root
        else
            local pipe = io.popen("find " .. root .. " -name '*.lua'")
            for line in pipe:lines() do
                files[#files + 1] = line:gsub("\\", "/")
            end
            pipe:close()
        end
    end
    -- de-dup (a file under classes/ is only in one root)
    local seen = {}
    for _, path in ipairs(files) do
        if not seen[path] then
            seen[path] = true
            local f = io.open(path, "rb")
            if f then
                local content = f:read("*a")
                f:close()
                local w = collect_writers(content, path:find("behavioral_audit%.lua") ~= nil)
                for k in pairs(w.context) do writers.context[k] = true end
                for k in pairs(w.state) do writers.state[k] = true end
                for k in pairs(w.settings or {}) do writers.settings[k] = true end
            end
        end
    end
    return writers
end

-- ---------------------------------------------------------------------------
-- Core scan: content -> { reads = {context=..., state=...}, error }
-- ---------------------------------------------------------------------------
local function scan_content(content)
    if type(content) ~= "string" then
        return { error = "content must be a string", reads = { context = {}, state = {} } }
    end
    return collect_reads(content)
end

local function scan_file(rel_path)
    local f = io.open(rel_path, "rb")
    if not f then return { skipped = true } end
    local content = f:read("*a")
    f:close()
    local res = scan_content(content)
    res.file = rel_path
    return res
end

local function run_scan(writers)
    local files = {}
    for _, root in ipairs(READER_ROOTS) do
        local pipe = io.popen("find " .. root .. " -name '*.lua'")
        for line in pipe:lines() do
            files[#files + 1] = line:gsub("\\", "/")
        end
        pipe:close()
    end
    table.sort(files)

    local results = {}
    local total_files = 0
    local total_reads = 0
    for _, path in ipairs(files) do
        local res = scan_file(path)
        if not res.skipped then
            local r = res.reads
            local n = 0
            for _ in pairs(r.context) do n = n + 1 end
            for _ in pairs(r.state) do n = n + 1 end
            if n > 0 then
                total_files = total_files + 1
                total_reads = total_reads + n
            end
        end
        results[#results + 1] = { path = path, res = res }
    end
    return { results = results, total_files = total_files, total_reads = total_reads }
end

-- findings: { {file, cls, field, line} }
local function unproduced_reads(res, writers)
    local findings = {}
    local function produced_in(cls, field)
        if writers[cls] and writers[cls][field] then return true end
        if cls == "state" and writers.settings and writers.settings[field] then return true end
        return false
    end
    local function sibling_produced(cls, field, line)
        -- Legacy-fallback rule: accept an unproduced read when the SAME line
        -- reads a PRODUCED field of the same class and the line is an `or`
        -- chain (`ctx.mana_pct or ctx.mana or 100`). The `or` requirement
        -- keeps `a and b` shapes visible (an unproduced field in an `and`
        -- chain is a genuine dead-read, not a fallback).
        if line <= 0 then return false end
        local line_text = res.lines and res.lines[line]
        if not line_text or not line_text:find("%sor%s") then return false end
        local same_line = res.by_line and res.by_line[cls] and res.by_line[cls][line]
        if not same_line then return false end
        for other in pairs(same_line) do
            if other ~= field and produced_in(cls, other) then return true end
        end
        return false
    end
    for cls, fields in pairs(res.reads) do
        for field, lines in pairs(fields) do
            if not produced_in(cls, field) and not STRATEGY_CONTRACT[field] then
                for _, line in ipairs(lines) do
                    -- Implicit-condition reads (line 0) resolve `state.X or
                    -- context.X`, so EITHER class producer satisfies them.
                    if line == 0 and res.implicit and res.implicit[field] then
                        if writers.context and writers.context[field] then
                            -- satisfied by the context-class writer
                        elseif writers.state and writers.state[field] then
                            -- satisfied by the state-class writer
                        else
                            findings[#findings + 1] = { file = res.file, cls = cls, field = field, line = line }
                        end
                    elseif sibling_produced(cls, field, line) then
                        -- legacy fallback chain — accepted, not a finding
                    else
                        findings[#findings + 1] = { file = res.file, cls = cls, field = field, line = line }
                    end
                end
            end
        end
    end
    return findings
end

local function allowlisted(res_file, cls, field)
    local entry = NO_WRITER_ALLOWLIST[res_file]
    if entry and entry[cls] and entry[cls][field] then return true end
    local global = NO_WRITER_ALLOWLIST[cls]
    return global and global[field] ~= nil
end

-- ---------------------------------------------------------------------------
-- Duplicate allowlist-key detection (the write-side audit's mana_low footgun).
-- ---------------------------------------------------------------------------
local function dup_allowlist_keys(src)
    local stripped = src:gsub('%-%-[^\n]*', '')
    local dups, seen = {}, {}
    for k in stripped:gmatch('%["([^"]+)"%]%s*=') do
        if seen[k] then dups[#dups + 1] = k else seen[k] = true end
    end
    return dups
end

local function extract_allowlist_block(src)
    local start = src:find('local NO_WRITER_ALLOWLIST = {', 1, true)
    if not start then return "" end
    start = src:find('{', start, true)
    local depth, i = 1, start
    while depth > 0 do
        i = src:find('[{}]', i + 1)
        if not i then return "" end
        if src:sub(i, i) == "{" then depth = depth + 1 else depth = depth - 1 end
    end
    return src:sub(start, i)
end

local function check_own_allowlist(path)
    local f = io.open(path, "rb")
    if not f then
        print("  Cannot read own source for allowlist dup check: " .. tostring(path))
        os.exit(1)
    end
    local src = f:read("*a")
    f:close()
    local dups = dup_allowlist_keys(extract_allowlist_block(src))
    if #dups > 0 then
        print("  DUPLICATE NO_WRITER_ALLOWLIST keys (later entry silently overrides")
        print("  the earlier one — the mana_low footgun): " .. table.concat(dups, ", "))
        os.exit(1)
    end
end

-- ---------------------------------------------------------------------------
-- Self-tests (non-vacuity): every resolver rule behaves correctly on
-- synthetic in-memory fixtures, plus real-file probes proving the audit
-- catches the three pre-fix defect shapes.
-- ---------------------------------------------------------------------------
local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end

    expect(scan_content(nil).error, "content must be a string", "malformed nil content")
    expect(scan_content(123).error, "content must be a string", "malformed numeric content")

    -- Minimal writer set for fixtures (battery/engine surface not needed).
    local function writers_for(content)
        return collect_writers(content, false)
    end
    local empty_writers = { context = {}, state = {} }

    -- Fixture 1: a context read with no writer is flagged (the assassination
    -- context.combo shape).
    local combo = scan_content(
        "local function build_state(context)\n"
        .. "    assassin_state.combo = context.combo or 0\n"
        .. "    return assassin_state\n"
        .. "end\n")
    local f1 = unproduced_reads(combo, empty_writers)
    expect(#f1, 1, "context.combo with no writer flags once")
    expect(f1[1].field, "combo", "flagged field name")
    expect(f1[1].cls, "context", "flagged class is context")

    -- Fixture 2: state-class read with no state writer (the spell_damage /
    -- demon_armor_ready shape).
    local sd = scan_content(
        "local function m(context, s)\n"
        .. "    if (s.spell_damage or 0) < 800 then return false end\n"
        .. "    return true\n"
        .. "end\n")
    local f2 = unproduced_reads(sd, empty_writers)
    expect(#f2, 1, "s.spell_damage with no writer flags once")
    expect(f2[1].field, "spell_damage", "spell_damage field name")
    expect(f2[1].cls, "state", "spell_damage is a state-class read")

    -- Fixture 3: a read WITH a writer (same class) is not flagged. The
    -- writer set is the fixture's own content (write-target tokens are no
    -- longer double-counted as reads).
    local ok_src =
        "local state = {}\n"
        .. "state.hp = 100\n"
        .. "local function m(c, s) return s.hp < 50 end\n"
    local ok_read = scan_content(ok_src)
    expect(#unproduced_reads(ok_read, writers_for(ok_src)), 0, "state.hp written in-file is produced")

    -- Fixture 4: a context read satisfied by an ENGINE writer is not flagged
    -- (_context._register string key + _context.X = static write).
    local engine_src =
        "local _context = lazy_context.create()\n"
        .. "_context._register(\"ttd\", {}, function(c) return 5 end)\n"
        .. "_context.in_combat = true\n"
    local eng_writers = writers_for(engine_src)
    expect(eng_writers.context["ttd"], true, "engine _register key is a context writer")
    expect(eng_writers.context["in_combat"], true, "engine static _context write is a context writer")
    local ttd_read = scan_content(
        "local function m(context) return context.ttd or 0 end\n")
    expect(#unproduced_reads(ttd_read, eng_writers), 0, "context.ttd produced by engine _register")

    -- Fixture 5: the aliasing trap — state.combo must NOT satisfy
    -- context.combo (cross-class aliasing is the assassination defect).
    local alias_writers = { context = {}, state = { combo = true } }
    local combo2 = scan_content(
        "local function m(context) return context.combo or 0 end\n")
    local f5 = unproduced_reads(combo2, alias_writers)
    expect(#f5, 1, "state.combo does not satisfy context.combo")

    -- Fixture 6: method calls are not FIELD reads of the METHOD name —
    -- `context.target:is_casting()` reads context.target (the receiver, a
    -- produced field in the real tree) but never reads `is_casting` as a
    -- context field. With the engine writers present, neither receiver flags;
    -- with NO writers, the receivers flag (they are genuine field reads whose
    -- producer is the engine, exactly like the fixed assassination defect).
    local methods = scan_content(
        "local function m(context, state)\n"
        .. "    if context.target:is_casting() then return false end\n"
        .. "    if NS.buff_up(context.me, 123) then return true end\n"
        .. "    local h = context.me.get_health_percentage()\n"
        .. "    return h > 50\n"
        .. "end\n")
    local engine_w = { context = { target = true, me = true }, state = {} }
    local mf = unproduced_reads(methods, engine_w)
    local flag_target, flag_buff, flag_me = false, false, false
    for _, f in ipairs(mf) do
        if f.field == "target" then flag_target = true end
        if f.field == "me" then flag_me = true end
        if f.field == "is_casting" or f.field == "get_health_percentage" then flag_buff = true end
    end
    expect(flag_target, false, "context.target produced by the engine is not flagged")
    expect(flag_me, false, "context.me produced by the engine is not flagged")
    expect(flag_buff, false, "method names (is_casting/get_health_percentage) are never field reads")
    -- Non-vacuity: with NO writers the `me` receiver IS flagged (proving the
    -- audit catches a missing producer — the method-call exclusion is only
    -- about the METHOD name, not the receiver). `target` is a strategy-table
    -- CONTRACT field (STRATEGY_CONTRACT.target), so it is never flagged even
    -- without a writer — by design.
    local mf0 = unproduced_reads(methods, empty_writers)
    local t0, m0 = false, false
    for _, f in ipairs(mf0) do
        if f.field == "target" then t0 = true end
        if f.field == "me" then m0 = true end
    end
    expect(t0, false, "context.target is a strategy-contract field, never flagged")
    expect(m0, true, "context.me with no writer flags (receiver is a field read)")

    -- Fixture 7: comment text never counts as a read.
    local commented = scan_content(
        "local function m(context)\n"
        .. "    -- context.fake_field is consumed somewhere\n"
        .. "    return true\n"
        .. "end\n")
    expect(#unproduced_reads(commented, empty_writers), 0, "comment mention is not a read")

    -- Fixture 8: DSL declarative reads are counted ({type=\"state\",...}).
    local decl = scan_content(
        'local function build()\n'
        .. '    local D = { { type = "state", field = "hp", op = "<", value = 40 } }\n'
        .. '    return D\n'
        .. 'end\n')
    local f8 = unproduced_reads(decl, empty_writers)
    expect(#f8, 1, "declarative state read of unproduced hp flags")
    expect(f8[1].field, "hp", "declarative field name")

    -- Fixture 9: implicit DSL conditions read BOTH classes — satisfied by
    -- either producer (in_combat written by engine -> no flag).
    local imp = scan_content(
        'local function build()\n'
        .. '    local D = { { type = "in_combat" }, { type = "enemy_count", op = ">", value = 3 } }\n'
        .. '    return D\n'
        .. 'end\n')
    local imp_writers = { context = { in_combat = true }, state = {} }
    local f9 = unproduced_reads(imp, imp_writers)
    local enemy_flags = 0
    for _, f in ipairs(f9) do if f.field == "enemy_count" then enemy_flags = enemy_flags + 1 end end
    expect(enemy_flags, 2, "unproduced enemy_count flags in both classes (state + context)")
    local in_combat_flags = 0
    for _, f in ipairs(f9) do if f.field == "in_combat" then in_combat_flags = in_combat_flags + 1 end end
    expect(in_combat_flags, 0, "in_combat produced by the engine is not flagged")

    -- Fixture 10: leading-underscore fields are out of scope.
    local us = scan_content(
        "local function m(context)\n"
        .. "    return context._balance_mf_spread_target\n"
        .. "end\n")
    expect(#unproduced_reads(us, empty_writers), 0, "leading-underscore field is out of scope")

    -- Fixture 11: strategy-contract reads (s.name in an ipairs loop) are
    -- never flagged (constructor bare keys write them).
    local loop = scan_content(
        "local function run()\n"
        .. "    for _, s in ipairs(strategies) do\n"
        .. "        if s.name == \\\"X\\\" and s.matches then s.execute() end\n"
        .. "    end\n"
        .. "end\n")
    expect(#unproduced_reads(loop, empty_writers), 0, "strategy-contract loop reads are never flagged")

    -- Fixture 12: duplicate allowlist keys are detected loudly.
    local dup_src = "local NO_WRITER_ALLOWLIST = {\n"
        .. '  ["context"] = { a = "x" },\n'
        .. '  ["state"] = { b = "y" },\n'
        .. '  ["context"] = { c = "z" },\n'
        .. "}\n"
    local dups = dup_allowlist_keys(dup_src)
    expect(#dups, 1, "one duplicate allowlist key detected")
    expect(dups[1], "context", "duplicate key name")

    -- Fixture 13: SOD string-key state reads (value(context,"X") / number(
    -- context,"X")) are flagged when unproduced and resolved when produced;
    -- spec_kit.setting_number is a SETTINGS read and is never captured.
    local sk = scan_content(
        "local function value(context, key, fb)\n"
        .. "    return type(context[key]) == type(fb) and context[key] or fb\n"
        .. "end\n"
        .. "local function build_state(context)\n"
        .. "    context = type(context) == 'table' and context or {}\n"
        .. "    return { in_cat_form = value(context, \"in_cat_form\", false),\n"
        .. "             sunder_stacks = number(context, \"sunder_stacks\", 0) }\n"
        .. "end\n")
    local f13 = unproduced_reads(sk, empty_writers)
    local cat_flags, sunder_flags = 0, 0
    for _, f in ipairs(f13) do
        if f.field == "in_cat_form" then cat_flags = cat_flags + 1 end
        if f.field == "sunder_stacks" then sunder_flags = sunder_flags + 1 end
    end
    expect(cat_flags, 1, "value(context,\"X\") string-key read is a context read")
    expect(sunder_flags, 1, "number(context,\"X\") string-key read is a context read")
    local sk_writers = { context = { in_cat_form = true, sunder_stacks = true }, state = {} }
    expect(#unproduced_reads(sk, sk_writers), 0, "produced string-key fields do not flag")
    local sk2 = scan_content(
        "local t = spec_kit.setting_number(context, \"fsr_mana_threshold\", 35)\n")
    expect(#unproduced_reads(sk2, empty_writers), 0, "spec_kit.setting_number is a settings read, never a context read")

    -- Real-file probes: the pre-fix defect shapes must each be classified
    -- correctly under the writer set of the CURRENT tree:
    --   * context.combo has no context-class writer (engine writes
    --     ctx.combo_points, main_sylvanas.lua:856) -> still unproduced -> 1
    --   * context.spell_damage is PRODUCED since Phase 2.1 (player_spell_damage
    --     setting wiring, main_sylvanas.lua) -> 0 unproduced
    --   * enemy_shadow_caster has no context-class writer -> still unproduced -> 1
    local writers = collect_all_writers()
    local def1 = scan_content("local function m(context) return context.combo or 0 end\n")
    expect(#unproduced_reads(def1, writers), 1, "context.combo is unproduced in the real tree (assassination defect)")
    local def2 = scan_content("local function m(context) return (context.spell_damage or 0) end\n")
    -- Phase 2.1 (2026-08-13): main_sylvanas.lua now PRODUCES
    -- context.spell_damage when the player_spell_damage setting is > 0, so the
    -- field must NOT flag as unproduced (the 2026-08 "unproduced" real-tree pin
    -- is superseded — the allowlist entry above carries the 0-degradation note).
    expect(#unproduced_reads(def2, writers), 0, "context.spell_damage is produced in the real tree (main_sylvanas.lua Phase 2.1 player_spell_damage setting)")
    local def3 = scan_content("local function m(context) if not context.enemy_shadow_caster then return false end end\n")
    expect(#unproduced_reads(def3, writers), 1, "context.enemy_shadow_caster is unproduced in the real tree (warlock defect)")

    -- The current tree must have ZERO real unproduced reads (every live read
    -- is produced or allowlisted) — this is the tree-level clean pin.
    local total_findings = 0
    for _, entry in ipairs(run_scan(writers).results) do
        local res = entry.res
        if not res.skipped then
            for _, f in ipairs(unproduced_reads(res, writers)) do
                if not allowlisted(res.file, f.cls, f.field) then
                    total_findings = total_findings + 1
                end
            end
        end
    end
    expect(total_findings, 0, "real tree has no unproduced reads (allowlist covers verified dynamic fields)")

    -- The real committed allowlist must itself be duplicate-free.
    check_own_allowlist(arg[0])

    print("[PASS] Read-side audit self-tests: ctx/state read detection, " 
        .. "cross-class aliasing trap, engine _register/static writers, "
        .. "battery known-keys, method-call exclusion, comment exclusion, "
        .. "declarative + implicit DSL reads, leading-underscore scope, "
        .. "strategy-contract exclusion, allowlist dup detection, real-tree "
        .. "probes (combo / enemy_shadow_caster unproduced, spell_damage produced since Phase 2.1)")
    os.exit(0)
end

-- ---------------------------------------------------------------------------
-- CLI
-- ---------------------------------------------------------------------------
if arg and arg[1] == "--self-test" then
    run_self_tests()
end

local writers = collect_all_writers()

print("=============================================================================")
print("  READ-SIDE AUDIT (fields read but produced by nothing)")
print("=============================================================================")
local failures = {}
local clean = 0
local scan = run_scan(writers)
for _, entry in ipairs(scan.results) do
    local res = entry.res
    if not res.skipped then
        local findings = unproduced_reads(res, writers)
        if #findings == 0 then
            clean = clean + 1
        else
            for _, f in ipairs(findings) do
                if allowlisted(res.file, f.cls, f.field) then
                    -- allowlisted findings are reported, not failures
                else
                    failures[#failures + 1] = f
                end
            end
        end
    end
end
print(string.format("  Total:     %d read-bearing files (%d distinct field reads)", 
    scan.total_files, scan.total_reads))
print(string.format("  Clean:     %d files with zero unproduced reads", clean))
print(string.format("  Invalid:   %d unproduced reads", #failures))
print("=============================================================================")

if #failures > 0 then
    print("  Fields read but produced by NOTHING in the tracked tree:")
    for _, f in ipairs(failures) do
        print(string.format("    %s  line %d: %s.%s  (no %s-class writer anywhere)",
            f.file, f.line, (f.cls == "context" and "context" or "state"), f.field, f.cls))
    end
    print("")
    print("  Fix: provide the field at its source (engine context / build_state)")
    print("  or change the read to the real field/helper — the three 2026-08-11")
    print("  fixes are the precedent (context.combo -> combo_points, spell_damage")
    print("  gates dropped, enemy_shadow_caster -> target:get_class()). If a")
    print("  finding is a verified dynamic/mock-only read, pin it in")
    print("  NO_WRITER_ALLOWLIST with the evidence rather than suppressing it.")
    os.exit(1)
end

check_own_allowlist(arg[0])

print("  Every read field is produced by a writer in the tracked tree.")
os.exit(0)
