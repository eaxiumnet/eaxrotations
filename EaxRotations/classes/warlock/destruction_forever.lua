-- destruction_forever.lua — Warlock Destruction delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 destruction delta over the vanilla baseline: INCINERATE (the
--        Immolate-conditional Fire nuke — "Deals $s1 Fire damage to your
--        target and an additional $m2% damage if the target is afflicted by
--        Immolate", effect dummy +25%), the SHADOW AND FLAME cross-school
--        window lane (the talent's applied windows: "Hitting an enemy with
--        Conflagrate increases all Shadow damage you deal by $m3% for
--        $1293816d, and hitting an enemy with Shadowburn increases all Fire
--        damage you deal by $m4% for $426311d") and BANE OF HAVOC (the
--        two-target cleave placement).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/warlock.md: "Incinerate (NEW capstone): main Fire
--        nuke, +25% vs Immolate-kept targets — the Immolate dependency lane",
--        "Shadow and Flame: Conflagrate boosts Shadow damage; Shadowburn
--        boosts Fire damage — cross-school amplification windows; at max
--        rank Conflagrate no longer consumes Immolate and Shadowburn
--        auto-refunds its shard", "Bane of Havoc (NEW): 15% of damage to
--        OTHER targets mirrors onto the Baned target — the two-target cleave
--        lane (place-and-focus)". DBC FINDINGS (1.60.1.69893): Incinerate
--        412758@40 / 1293812@50 / 1293813@60 with the +25% dummy confirmed
--        (effect 3 base 25); Bane of Havoc 1225228 is the cast/aura row
--        (effect 6 dummy aura base 15 -> the 15% mirror; "limited to 1
--        target, and only one Bane per Warlock can be active on any one
--        target"); the two window rows 1293816 ("Shadow") and 426311
--        ("Flame") are CLASS-LESS aura rows (both aura 79 +10%, referenced
--        by the talent text) — now pinned in the builder's
--        CLASS_LESS_BUFF_NAMES. KIT CORRECTIONS: the max-rank Conflagrate
--        18932 STILL reads "consuming your Immolate effect" — the
--        no-consume effects are Backdraft 427713 ("no longer consumes
--        Immolate", plus the 427714 haste buff) and Shadow and Flame's 20%
--        chance; the Shadowburn shard refund is likewise an S&F *chance*,
--        not a max-rank guarantee. Neither needs a lane: the baseline's
--        Conflagrate/Shadowburn lanes already cast on their own gates.
-- SAFETY: ZERO numeric spell-ID literals — Incinerate, Bane of Havoc and the
--        two Shadow and Flame window auras resolve BY NAME through the
--        bridge mirrors (Incinerate/Bane also learn-gated through the rank-1
--        mirror so a mid-level character falls back to the baseline filler
--        instead of stalling on an unlearned max-rank cast); a nil lookup
--        leaves the lane dormant — never a guessed ID. The vanilla baseline
--        is loaded through an intercepted registration
--        (affliction/demonology_forever template) so this file edits nothing
--        in destruction_vanilla.lua and its safe_state-backed get_state is
--        reused unchanged. Splice geometry: Bane of Havoc lands immediately
--        above the curse block's head, "CurseOfDoom" (fallback
--        "CurseOfAgony"), and the window + Incinerate pair immediately above
--        "ShadowBolt" (fallback "RainOfFire"; then append) — both below the
--        survival/mana lanes. The window lane's FIRE branch requires
--        Incinerate known; its SHADOW branch (Shadow Bolt) stands alone.

local NS = _G.EaxRotations
if not NS then return nil end

local SPELLS = NS.WarlockSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "destruction"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] warlock destruction delta: rotation_registry unavailable", 0)
end
local original_register = registry.register
local baseline = nil
registry.register = function(self, name, strategies, options)
    registry.register = original_register
    baseline = { name = name, strategies = strategies, options = options or {} }
    return true
end
-- Force baseline re-execution so its registration always reaches the
-- interceptor above, even if some earlier require() cached the module.
package.loaded["classes/warlock/destruction_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/warlock/destruction_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] warlock destruction delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- cast lanes resolve the maxrank mirror (a level-60 warlock casts the top
-- rank), the learn gate reads both mirrors (a mid-level character has the
-- rank-1 row learned while the lane casts max rank), and the Shadow and
-- Flame windows resolve through the buff mirror. A nil lookup leaves the
-- lane dormant -- never a guessed ID. Sentinel stand-ins are seeded per
-- mirror by the battery's build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_name = (ForeverBridge
    and type(ForeverBridge.spell_index_by_name_forever) == "table")
    and ForeverBridge.spell_index_by_name_forever or {}
local by_maxrank = (ForeverBridge
    and type(ForeverBridge.spell_maxrank_by_name_forever) == "table")
    and ForeverBridge.spell_maxrank_by_name_forever or {}
local by_buff = (ForeverBridge
    and type(ForeverBridge.spell_buff_by_name_forever) == "table")
    and ForeverBridge.spell_buff_by_name_forever or {}

local function resolve_id(map, client_name)
    local id = map[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local INCINERATE = resolve_id(by_maxrank, "Incinerate")
local INCINERATE_R1 = resolve_id(by_name, "Incinerate")
local BANE_OF_HAVOC = resolve_id(by_maxrank, "Bane of Havoc")
local BANE_OF_HAVOC_R1 = resolve_id(by_name, "Bane of Havoc")
local FIRE_WINDOW = resolve_id(by_buff, "Flame")
local SHADOW_WINDOW = resolve_id(by_buff, "Shadow")
local SHADOW_BOLT = SPELLS.ShadowBolt or nil

-- ---------------------------------------------------------------------------
-- Shared helpers. KIT NOTE: the max-rank Conflagrate still consumes Immolate
-- (the no-consume sources are Backdraft 427713 and Shadow and Flame's 20%
-- chance), so Incinerate keeps the hard Immolate dependency gate and the
-- rotation never plans around a free refresh.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}

local function knows_any(id_a, id_b)
    if type(NS.is_spell_learned) ~= "function" then return false end
    for _, id in ipairs({ id_a, id_b }) do
        if type(id) == "number" then
            local ok, learned = pcall(NS.is_spell_learned, id)
            if ok and learned == true then return true end
        end
    end
    return false
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function aura_up(unit, id)
    if not unit or not id or type(NS.buff_up) ~= "function" then return false end
    local ok, up = pcall(NS.buff_up, unit, id)
    return ok and up == true
end

-- Shadow and Flame window pick: the Fire window wants the Fire nuke, the
-- Shadow window the Shadow one. Returns the spell action (or nil).
local function window_pick(context)
    if aura_up(context.me, FIRE_WINDOW) then
        if INCINERATE and knows_any(INCINERATE, INCINERATE_R1) then return INCINERATE end
        return nil
    end
    if aura_up(context.me, SHADOW_WINDOW) then
        return SHADOW_BOLT
    end
    return nil
end

-- Bane of Havoc placement: the off-target (damage dealt to others mirrors
-- onto the Baned target). The curse is limited to ONE target, so the scan
-- aborts entirely when any non-focus enemy already carries it.
local function havoc_target(context)
    local list = context.enemies
    if type(list) ~= "table" then return nil end
    local n = list.n or #list
    local chosen = nil
    for i = 1, n do
        local enemy = list[i]
        if type(enemy) == "table" then
            local is_focus = (enemy == context.target)
                or (NS.same_unit and context.target and NS.same_unit(enemy, context.target))
            if not is_focus then
                if NS.debuff_up and NS.debuff_up(enemy, BANE_OF_HAVOC) then
                    return nil
                end
                chosen = chosen or enemy
            end
        end
    end
    return chosen
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Bane of Havoc is cleave setup (sits with the curses); the
-- window + Incinerate pair is the filler selector (sits above Shadow Bolt).
-- ---------------------------------------------------------------------------
local delta_curse = {}
local delta_filler = {}

if BANE_OF_HAVOC and knows_any(BANE_OF_HAVOC, BANE_OF_HAVOC_R1) then
    delta_curse[#delta_curse + 1] = {
        name = "Forever_BaneOfHavoc",
        matches = function(context, s)
            if (context.enemy_count or context.enemies_count or 0) < 2 then return false end
            local enemy = havoc_target(context)
            if not enemy then return false end
            return NS.spell_ready(BANE_OF_HAVOC, enemy, EMPTY_OPTS)
        end,
        execute = function(context)
            local enemy = havoc_target(context)
            if not enemy then return false end
            return NS.try_cast(BANE_OF_HAVOC, enemy,
                "[FOREVER-DESTRO] Bane of Havoc (off-target cleave mirror)")
        end,
    }
end

-- Window lane first: while a Shadow and Flame window is up, the boosted
-- school outranks the plain Incinerate filler below.
if (FIRE_WINDOW or SHADOW_WINDOW) and (INCINERATE or SHADOW_BOLT) then
    delta_filler[#delta_filler + 1] = {
        name = "Forever_ShadowAndFlame",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if context.is_moving then return false end
            local spell = window_pick(context)
            if not spell then return false end
            return NS.spell_ready(spell, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            if aura_up(context.me, FIRE_WINDOW) and INCINERATE then
                return NS.try_cast(INCINERATE, context.target,
                    "[FOREVER-DESTRO] Incinerate (Shadow and Flame fire window)")
            end
            if SHADOW_BOLT then
                return NS.try_cast(SHADOW_BOLT, context.target,
                    "[FOREVER-DESTRO] Shadow Bolt (Shadow and Flame shadow window)")
            end
            return false
        end,
    }
end

if INCINERATE and knows_any(INCINERATE, INCINERATE_R1) then
    delta_filler[#delta_filler + 1] = {
        name = "Forever_Incinerate",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if context.is_moving then return false end
            if (s.immolate_remains or 0) <= 0 then return false end
            return NS.spell_ready(INCINERATE, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(INCINERATE, context.target,
                "[FOREVER-DESTRO] Incinerate (Immolate-kept fire nuke)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: Bane of Havoc goes immediately above the baseline's
-- "CurseOfAgony" lane (fallback: above "CurseOfDoom"; then append) and the
-- window lane leads the Incinerate lane immediately above "ShadowBolt"
-- (fallback: above "RainOfFire"; then append). Re-registering the playstyle
-- name replaces the baseline wholesale — the combined list IS the
-- "destruction" playstyle on Forever.
-- ---------------------------------------------------------------------------
local CURSE_ANCHORS = { CurseOfAgony = true, CurseOfDoom = true }
local FILLER_ANCHORS = { ShadowBolt = true, RainOfFire = true }

local combined = {}
local curse_done = false
local filler_done = false
local function insert_curse()
    if curse_done then return end
    for j = 1, #delta_curse do combined[#combined + 1] = delta_curse[j] end
    curse_done = true
end
local function insert_filler()
    if filler_done then return end
    for j = 1, #delta_filler do combined[#combined + 1] = delta_filler[j] end
    filler_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and CURSE_ANCHORS[name] then insert_curse() end
    if name and FILLER_ANCHORS[name] then insert_filler() end
    combined[#combined + 1] = st
end
insert_curse()
insert_filler()

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Warlock destruction Forever delta registered (" ..
    #delta_curse .. " bane-of-havoc + " .. #delta_filler ..
    " window/incinerate lanes over " .. #baseline.strategies .. " baseline lanes)") end

return combined
