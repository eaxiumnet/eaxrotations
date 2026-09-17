-- holy_forever.lua — Priest Holy delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 holy delta over the vanilla baseline: PRAYER OF MENDING
--        (the reactive heal-on-damage buff that jumps — "Places a spell on
--        the target that heals them the next time they take damage or
--        receive non-periodic healing. When the heal occurs, Prayer of
--        Mending jumps to a party or raid member within $401880a1 yards.
--        Jumps up to $s2 times ... This spell can only be placed on one
--        target at a time per caster"), BINDING HEAL ("Heals a friendly
--        target and the caster for $s1. Low threat." — the pair-heal
--        self-preservation lane) and the LITANY OF LIGHT cast-variability
--        lane ("When you cast a healing spell, gain Mana equal to $m1% of
--        the base cost of the spell if your previous heal was a different
--        spell").
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/priest.md: "Prayer of Mending (Holy, via talent)
--        — heal-on-damage buff that jumps up to 5x — pre-cast reactive heal
--        lane (place on the tank before pulls; jump tracking)", "Binding
--        Heal (NEW to Holy) — heals target + caster (low threat): the
--        self-preservation lane for the healer (tank+healer simultaneous
--        damage coverage)", "Litany of Light: casting a DIFFERENT spell than
--        the previous heal refunds 5-10% of its base cost as mana —
--        rotation-shaping mana engine that PUNISHES spell repetition
--        (cast-variability lane)". DBC FINDINGS (1.60.1.69893): PoM cast
--        ladder 401859@40 / 1240826@50 / 1240827@60 with
--        CategoryRecoveryTime 10000 (the lane declares 10s); the applied
--        aura is 1240849 (@60, "Heals upon taking damage or receiving
--        healing") — pinned in the builder's BUFF_OVERRIDES (the baseline
--        resolves the @40 cast row). Binding Heal ladder 401937@25 ...
--        1240774@56, no cooldown, effect rows = two heal effects (target +
--        caster). Litany of Light 1317006 is a passive proc (effect aura
--        42); the lane's contribution is CAST VARIETY, not a buff read.
--        Twilight Focus 14913 (pushback protection) is a pure passive — no
--        lane, recorded as a probe.
-- SAFETY: ZERO numeric spell-ID literals — Prayer of Mending and Binding
--        Heal resolve BY NAME through the bridge mirrors (the PoM aura read
--        uses the pinned aura id plus the maxrank cast id as a fallback, so
--        both "the aura is its own row" and "the cast applies itself"
--        models hold); the variety lane alternates the class-map Flash
--        Heal / Greater Heal ladders. A nil lookup leaves the lane dormant
--        — never a guessed ID. The vanilla baseline is loaded through an
--        intercepted registration (affliction/demonology_forever template)
--        so this file edits nothing in holy_vanilla.lua and its
--        safe_state-backed get_state is reused unchanged. The variety lane
--        tracks its OWN last cast (the engine exposes no last-spell read —
--        core's _last_spell_cast is file-local), which is enough: every
--        alternation makes its next cast a "different spell". Splice
--        geometry: PoM leads the maintenance heal block ("RenewTank"),
--        the variety lane sits above "GreaterHeal" and Binding Heal above
--        "FlashHeal".

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PriestSpells or {}
local Healing = NS.PriestHealing
if type(Healing) ~= "table" then
    local ok_healing, mod = pcall(require, "classes/priest/healing_sylvanas")
    if ok_healing and type(mod) == "table" then Healing = mod end
end

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "holy" playstyle
-- is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] priest holy delta: rotation_registry unavailable", 0)
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
package.loaded["classes/priest/holy_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/priest/holy_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] priest holy delta: baseline load failed: " .. tostring(baseline_result))
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- casts resolve the maxrank mirror, the PoM aura read the buff mirror (plus
-- the maxrank cast id as a fallback). A nil lookup leaves the lane dormant
-- -- never a guessed ID. Sentinel stand-ins are seeded per mirror by the
-- battery's build_ns so mirror selection itself is pinned.
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

local POM = resolve_id(by_maxrank, "Prayer of Mending")
local POM_R1 = resolve_id(by_name, "Prayer of Mending")
local POM_AURA = resolve_id(by_buff, "Prayer of Mending")
local BINDING_HEAL = resolve_id(by_maxrank, "Binding Heal")
local BINDING_HEAL_R1 = resolve_id(by_name, "Binding Heal")
local FLASH_HEAL = SPELLS.FlashHeal or nil
local GREATER_HEAL = SPELLS.GreaterHeal or nil

local POM_AURA_IDS = { POM_AURA, POM }
local POM_OPTS = { expected_cooldown = 10 }

-- ---------------------------------------------------------------------------
-- Shared helpers. PoM's DBC cooldown is 10s (CategoryRecoveryTime), Binding
-- Heal has none; the thresholds are menu-tunable via spec_kit.setting.
-- ---------------------------------------------------------------------------
local BINDING_HEAL_HP = 65
local VARIETY_CEILING = 90
local VARIETY_MANA_FLOOR = 30

local _last_variety = nil  -- "FH" | "GH": the variety lane's own last cast

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
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

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function unit_has_aura(unit, ids)
    if not unit or type(NS.buff_up) ~= "function" then return false end
    local ok, up = pcall(NS.buff_up, unit, ids)
    return ok and up == true
end

-- PoM jump tracking: the aura sits on exactly one party member per caster,
-- so the lane holds while ANY scanned entry (or the player) carries it.
local function party_has_pom(context)
    if unit_has_aura(NS.PLAYER_UNIT, POM_AURA_IDS) then return true end
    if type(Healing) == "table" and type(Healing.scan_healing_targets) == "function" then
        local ok, entries, count = pcall(Healing.scan_healing_targets)
        if ok and type(entries) == "table" then
            local n = (type(count) == "number" and count) or #entries
            for i = 1, n do
                local entry = entries[i]
                if entry and entry.unit and unit_has_aura(entry.unit, POM_AURA_IDS) then
                    return true
                end
            end
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Delta lanes. PoM leads the maintenance heal block, the variety lane the
-- Greater Heal tier and Binding Heal the Flash Heal tier.
-- ---------------------------------------------------------------------------
local delta_maintenance = {}
local delta_binding = {}
local delta_variety = {}

if POM and knows_any(POM, POM_R1) then
    delta_maintenance[#delta_maintenance + 1] = {
        name = "Forever_PrayerOfMending",
        matches = function(context, s)
            local tank = s.tank or s.lowest
            if not tank or not tank.unit then return false end
            if party_has_pom(context) then return false end
            return NS.spell_ready(POM, tank.unit, POM_OPTS)
        end,
        execute = function(context, s)
            local tank = s.tank or s.lowest
            if not tank or not tank.unit then return false end
            return NS.try_cast(POM, tank.unit,
                string.format("[FOREVER-HOLY] Prayer of Mending %.0f%%", tank.effective_hp or 0))
        end,
    }
end

if BINDING_HEAL and knows_any(BINDING_HEAL, BINDING_HEAL_R1) then
    delta_binding[#delta_binding + 1] = {
        name = "Forever_BindingHeal",
        matches = function(context, s)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not s.lowest or not s.lowest.unit then return false end
            local hp = setting(context, "holy_forever_binding_hp", BINDING_HEAL_HP)
            if (s.lowest_hp or 100) > hp then return false end
            if (context.hp or 100) > hp then return false end  -- the pair-heal needs BOTH hurt
            return NS.spell_ready(BINDING_HEAL, s.lowest.unit)
        end,
        execute = function(context, s)
            if not s.lowest or not s.lowest.unit then return false end
            return NS.try_cast(BINDING_HEAL, s.lowest.unit,
                string.format("[FOREVER-HOLY] Binding Heal %.0f%% (self %.0f%%)",
                    s.lowest_hp or 0, context.hp or 0))
        end,
    }
end

if FLASH_HEAL and GREATER_HEAL then
    delta_variety[#delta_variety + 1] = {
        name = "Forever_LitanyVariety",
        matches = function(context, s)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not s.lowest or not s.lowest.unit then return false end
            if (s.lowest_hp or 100) >= setting(context, "holy_forever_variety_hp", VARIETY_CEILING) then return false end
            if (context.mana_pct or 100) < setting(context, "holy_forever_variety_mana", VARIETY_MANA_FLOOR) then return false end
            -- Alternate: the previous cast of THIS lane decides the pick, so
            -- the Litany's "different spell" condition is met on every cast.
            local pick = (_last_variety == "GH") and FLASH_HEAL or GREATER_HEAL
            return NS.spell_ready(pick, s.lowest.unit)
        end,
        execute = function(context, s)
            if not s.lowest or not s.lowest.unit then return false end
            local pick, tag
            if _last_variety == "GH" then
                pick, tag = FLASH_HEAL, "Flash Heal"
                _last_variety = "FH"
            else
                pick, tag = GREATER_HEAL, "Greater Heal"
                _last_variety = "GH"
            end
            if not pick then return false end
            return NS.try_cast(pick, s.lowest.unit,
                string.format("[FOREVER-HOLY] %s (Litany variety) %.0f%%", tag, s.lowest_hp or 0))
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: PoM immediately above the baseline's "RenewTank"
-- maintenance lane (fallback: "RenewSpread"), the variety lane immediately
-- above "GreaterHeal" and Binding Heal immediately above "FlashHeal"; then
-- append. Re-registering the playstyle name replaces the baseline wholesale
-- — the combined list IS the "holy" playstyle on Forever.
-- ---------------------------------------------------------------------------
local MAINTENANCE_ANCHORS = { RenewTank = true, RenewSpread = true }
local VARIETY_ANCHORS = { GreaterHeal = true }
local BINDING_ANCHORS = { FlashHeal = true }

local combined = {}
local maintenance_done = false
local variety_done = false
local binding_done = false
local function insert_maintenance()
    if maintenance_done then return end
    for j = 1, #delta_maintenance do combined[#combined + 1] = delta_maintenance[j] end
    maintenance_done = true
end
local function insert_variety()
    if variety_done then return end
    for j = 1, #delta_variety do combined[#combined + 1] = delta_variety[j] end
    variety_done = true
end
local function insert_binding()
    if binding_done then return end
    for j = 1, #delta_binding do combined[#combined + 1] = delta_binding[j] end
    binding_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and MAINTENANCE_ANCHORS[name] then insert_maintenance() end
    if name and VARIETY_ANCHORS[name] then insert_variety() end
    if name and BINDING_ANCHORS[name] then insert_binding() end
    combined[#combined + 1] = st
end
insert_maintenance()
insert_variety()
insert_binding()

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Priest holy Forever delta registered (" ..
    #delta_maintenance .. " prayer-of-mending + " .. #delta_binding ..
    " binding-heal + " .. #delta_variety .. " variety lanes over " ..
    #baseline.strategies .. " baseline lanes)") end

return combined
