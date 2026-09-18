-- combat_forever.lua — Rogue Combat delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 combat delta over the vanilla baseline: the RESTLESS BLADES
--        spender-timing lane ("Your damaging finishing moves reduce the
--        remaining cooldown of your Adrenaline Rush, Blade Flurry, Evasion,
--        Sprint, and Vanish abilities by $m1 sec per combo point" — 1241797)
--        and the PUNCTURING WOUNDS dagger-generator lane ("Increases the
--        critical strike chance of your Backstab by $m1% and your Mutilate
--        by $m3%, and gives Backstab a $m2% chance to add an additional
--        Combo Point" — 1224716).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/rogue.md: "Restless Blades: each combo point SPENT
--        reduces the CD of Adrenaline Rush, Blade Flurry, Evasion, Sprint,
--        Vanish by 2s — CD lanes become rotation-coupled (spenders now
--        actively recharge cooldowns; defensive CDs can be used
--        pre-emptively)" and "Puncturing Wounds (NEW, tier 2): benefits
--        dagger/fist CP generation — weapon-agnostic Combat builds become
--        viable (breaks the slow-sword assumption baked into combat lanes)".
--        DBC FINDINGS (1.60.1.69893): Restless Blades 1241797 names the five
--        tracked cooldowns exactly; the baseline's Eviscerate lane holds to
--        the 5-CP rule, so the shave window (2s per point, spent on a
--        DAMAGING finisher — Slice and Dice does not shave) is a real,
--        separate lane: with a tracked CD inside 2 x combo seconds the
--        rotation spends at 3-4 CP to finish it. Puncturing Wounds 1224716
--        confirms the Backstab crit + CP-proc; the baseline's Backstab lane
--        sits BELOW Hemorrhage (the cheap 35-energy filler), so the talent
--        lane promotes the dagger generator above it when learned. The
--        per-weapon talent (13960: "Axe/Sword: extra attack; Dagger/Fist:
--        +crit; Mace: armor ignore") is a CLASS-LESS row (no
--        SpellClassOptions) and a pure passive either way — recorded as a
--        bridge-gap probe, no lane.
--        Blade Dance 400012 is rune-granted ("Engrave Pants - Blade Dance")
--        and is not laned by the kit — recorded for the close-out report.
-- SAFETY: ZERO numeric spell-ID literals — Restless Blades and Puncturing
--        Wounds resolve BY NAME through the rank-1 mirror; the tracked CDs
--        and the generators reuse the class-map actions the baseline already
--        casts. A nil lookup leaves the lane dormant — never a guessed ID.
--        The vanilla baseline is loaded through an intercepted registration
--        (affliction/demonology_forever template) so this file edits nothing
--        in combat_vanilla.lua and its safe_state-backed get_state is reused
--        unchanged. Splice geometry: the Restless Blades lane goes
--        immediately above the baseline's "Eviscerate" and the Puncturing
--        Wounds lane immediately above its "Hemorrhage".

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.RogueSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "combat" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("rogue combat", "classes/rogue/combat_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- two talents resolve the rank-1 mirror; the tracked cooldowns and the
-- generators reuse the class map. A nil lookup leaves the lane dormant --
-- never a guessed ID. Sentinel stand-ins are seeded per mirror by the
-- battery's build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_name = mirrors.name

local RESTLESS_BLADES = resolve_id(by_name, "Restless Blades")
local PUNCTURING_WOUNDS = resolve_id(by_name, "Puncturing Wounds")
local EVISCERATE = SPELLS.Eviscerate or nil
local BACKSTAB = SPELLS.Backstab or nil

-- The five cooldowns Restless Blades shaves (DBC text).
local TRACKED_CDS = {}
for _, key in ipairs({ "AdrenalineRush", "BladeFlurry", "Evasion", "Sprint", "Vanish" }) do
    if SPELLS[key] then TRACKED_CDS[#TRACKED_CDS + 1] = SPELLS[key] end
end

-- ---------------------------------------------------------------------------
-- Shared helpers. The shave is 2s per combo point (the kit's number; the
-- DBC text leaves $m1 to the aura), so a spend "finishes" a CD when its
-- remaining time sits inside 2 x combo seconds.
-- ---------------------------------------------------------------------------
local RB_SECONDS_PER_CP = 2
local RB_MIN_COMBO = 3
local EVISCERATE_ENERGY = 35
local BACKSTAB_ENERGY = 60

local setting = forever.setting

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function knows_any(id_a, id_b)
    if type(NS.is_spell_learned) ~= "function" then return false end
    for _, id in ipairs({ id_a, id_b or id_a }) do
        if type(id) == "number" then
            local ok, learned = pcall(NS.is_spell_learned, id)
            if ok and learned == true then return true end
        end
    end
    return false
end

local function cooldown_remains(spell)
    if not spell then return 0 end
    if type(NS.cooldown_remains) == "function" then
        local ok, remains = pcall(NS.cooldown_remains, spell)
        if ok and type(remains) == "number" then return remains end
    end
    if type(NS.get_spell_cooldown) == "function" then
        local ok, remains = pcall(NS.get_spell_cooldown, spell)
        if ok and type(remains) == "number" then return remains end
    end
    return 0
end

-- True when spending the current combo points would finish one of the five
-- Restless Blades cooldowns.
local function shave_finishes_cd(context, s)
    local combo = s.combo_points or 0
    local window = setting(context, "combat_forever_rb_per_cp", RB_SECONDS_PER_CP) * combo
    if window <= 0 then return false end
    for i = 1, #TRACKED_CDS do
        local remains = cooldown_remains(TRACKED_CDS[i])
        if remains > 0 and remains <= window then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The Restless Blades lane leads the finisher block, the
-- Puncturing Wounds lane the generator block.
-- ---------------------------------------------------------------------------
local delta_finisher = {}
local delta_builder = {}

if RESTLESS_BLADES and EVISCERATE and knows_any(RESTLESS_BLADES) and #TRACKED_CDS > 0 then
    delta_finisher[#delta_finisher + 1] = {
        name = "Forever_RestlessBlades",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if s.energy_pool_finisher then return false end
            if (s.energy or 0) < EVISCERATE_ENERGY then return false end
            if (s.combo_points or 0) < RB_MIN_COMBO then return false end
            if not shave_finishes_cd(context, s) then return false end
            return NS.spell_ready(EVISCERATE, context.target)
        end,
        execute = function(context, s)
            return NS.try_cast(EVISCERATE, context.target,
                string.format("[FOREVER-COMBAT] Eviscerate (Restless Blades shave, %d cp)",
                    s.combo_points or 0))
        end,
    }
end

if PUNCTURING_WOUNDS and BACKSTAB and knows_any(PUNCTURING_WOUNDS) then
    delta_builder[#delta_builder + 1] = {
        name = "Forever_PuncturingWounds",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if not s.has_daggers then return false end
            if not s.is_behind then return false end
            if s.has_stealth then return false end  -- the stealth opener is preferred
            if (s.energy or 0) < BACKSTAB_ENERGY then return false end
            return NS.spell_ready(BACKSTAB, context.target)
        end,
        execute = function(context)
            return NS.try_cast(BACKSTAB, context.target,
                "[FOREVER-COMBAT] Backstab (Puncturing Wounds generator)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the Restless Blades lane immediately above the
-- baseline's "Eviscerate" finisher — and BELOW "Rupture", so a needed bleed
-- refresh still outranks the shave spend — the Puncturing Wounds lane
-- immediately above "Hemorrhage" (fallback: "Backstab"); then append. Re-registering the playstyle name replaces the baseline wholesale
-- — the combined list IS the "combat" playstyle on Forever.
-- ---------------------------------------------------------------------------
local FINISHER_ANCHORS = { Eviscerate = true }
local BUILDER_ANCHORS = { Hemorrhage = true, Backstab = true }

local combined = {}
local finisher_done = false
local builder_done = false
local function insert_finisher()
    if finisher_done then return end
    for j = 1, #delta_finisher do combined[#combined + 1] = delta_finisher[j] end
    finisher_done = true
end
local function insert_builder()
    if builder_done then return end
    for j = 1, #delta_builder do combined[#combined + 1] = delta_builder[j] end
    builder_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and FINISHER_ANCHORS[name] then insert_finisher() end
    if name and BUILDER_ANCHORS[name] then insert_builder() end
    combined[#combined + 1] = st
end
insert_finisher()
insert_builder()

baseline.register(combined)
if NS.log then NS.log("Rogue combat Forever delta registered (" ..
    #delta_finisher .. " restless-blades + " .. #delta_builder ..
    " puncturing-wounds lanes over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
