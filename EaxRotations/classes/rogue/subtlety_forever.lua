-- subtlety_forever.lua — Rogue Subtlety delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 subtlety delta over the vanilla baseline: the THOUSAND CUTS
--        energy engine ("When your Rupture ability deals periodic damage,
--        the Energy cost of your next Hemorrhage or Backstab ability within
--        $1310723d is reduced by $1310723s1, stacking up to $1310723u
--        times" — the applied stack buff 1310723, effect aura 107 base -3)
--        and the CUTTHROAT stealth-free Ambush ("Your Backstab has a $m1%
--        chance to cause your next Ambush within $462707d to not require
--        Stealth" — the proc buff 462707).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/rogue.md: "Thousand Cuts: Rupture ticks reduce
--        the energy cost of Hemorrhage or Backstab by 3, stacking to 5 —
--        keep-Rupture-up is now the energy engine (stack read, Pattern 11)"
--        and "Cutthroat: Backstab procs a stealth-free Ambush (chance
--        scales) — burst-window lane; Backstab becomes the default Subtlety
--        generator". DBC FINDINGS (1.60.1.69893): Thousand Cuts 1310721
--        (talent) applies 1310723 (stack aura, -3 energy per stack) — the
--        rank-1 baseline resolves the TALENT row, so the stack read would
--        always return 0 without the builder's BUFF_OVERRIDES pin (now
--        pinned, with a permanent audit self-test). Cutthroat 462708
--        (talent text) applies 462707 (the proc); the baseline 424980 is
--        the "Gain the Cutthroat ability" grant row — also pinned. Hemorrhage
--        16511 carries the +Rupture-damage amplifier ("causes the target to
--        take $m3% increased Rupture damage") and the baseline already
--        maintains it (HemorrhageDebuff lane) — no delta. Quietus 1310728
--        ("Your Sinister Strike, Ghostly Strike, and Hemorrhage abilities
--        cause $m1% more damage against targets below $m2% health") is a
--        passive on the generators the rotation already casts — no lane,
--        recorded as a probe.
-- SAFETY: ZERO numeric spell-ID literals — the Thousand Cuts stacks and the
--        Cutthroat proc resolve BY NAME through the buff mirror; the Ambush
--        cast reuses the class-map ladder the baseline already casts. A nil
--        lookup leaves the lane dormant — never a guessed ID. The vanilla
--        baseline is loaded through an intercepted registration
--        (affliction/demonology_forever template) so this file edits nothing
--        in subtlety_vanilla.lua and its safe_state-backed get_state is
--        reused unchanged. The TC lane fires the discounted HEMORRHAGE (the
--        any-position builder) earlier than the baseline's flat 40-energy
--        pooling floor; Backstab's burst gate stays the baseline's. Splice
--        geometry: the TC lane goes immediately above the baseline's
--        "Hemorrhage" lane and the Cutthroat lane immediately above its
--        "Ambush" opener.

local NS = _G.EaxRotations
if not NS then return nil end

local SPELLS = NS.RogueSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "subtlety"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] rogue subtlety delta: rotation_registry unavailable", 0)
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
package.loaded["classes/rogue/subtlety_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/rogue/subtlety_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] rogue subtlety delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- TC stack read and the Cutthroat proc resolve the buff mirror; the Ambush
-- cast reuses the class map. A nil lookup leaves the lane dormant -- never a
-- guessed ID. Sentinel stand-ins are seeded per mirror by the battery's
-- build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_buff = (ForeverBridge
    and type(ForeverBridge.spell_buff_by_name_forever) == "table")
    and ForeverBridge.spell_buff_by_name_forever or {}

local function resolve_id(map, client_name)
    local id = map[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local THOUSAND_CUTS = resolve_id(by_buff, "Thousand Cuts")
local CUTTHROAT = resolve_id(by_buff, "Cutthroat")
local HEMORRHAGE = SPELLS.Hemorrhage or nil
local AMBUSH = SPELLS.Ambush or nil

-- ---------------------------------------------------------------------------
-- Shared helpers. Baseline constants mirrored: Hemorrhage costs 35, the
-- pooling floor is 40, Ambush costs 60; Thousand Cuts discounts 3 per stack
-- (the aura's own value).
-- ---------------------------------------------------------------------------
local TC_ENERGY_PER_STACK = 3
local HEMORRHAGE_ENERGY = 35
local POOL_FLOOR = 40
local AMBUSH_ENERGY = 60

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

local function buff_stacks(unit, id)
    if not unit or not id then return 0 end
    if type(NS.buff_stacks) == "function" then
        local ok, stacks = pcall(NS.buff_stacks, unit, id)
        if ok and type(stacks) == "number" then return stacks end
    end
    return 0
end

local function buff_up(unit, id)
    if not unit or not id then return false end
    if type(NS.buff_up) == "function" then
        local ok, up = pcall(NS.buff_up, unit, id)
        if ok then return up == true end
    end
    return false
end

local function is_behind(target)
    if not target or type(NS.is_behind_target) ~= "function" then return false end
    local ok, behind = pcall(NS.is_behind_target, target)
    return ok and behind == true
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The TC lane leads the builder, the Cutthroat lane the opener.
-- ---------------------------------------------------------------------------
local delta_builder = {}
local delta_opener = {}

if THOUSAND_CUTS and HEMORRHAGE then
    delta_builder[#delta_builder + 1] = {
        name = "Forever_ThousandCuts",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            local stacks = buff_stacks(context.me, THOUSAND_CUTS)
            if stacks <= 0 then return false end
            -- The discount is what makes the generator affordable: energy
            -- plus the stack discount must cover both the cost and the
            -- baseline's pooling floor.
            local effective = (s.energy or 0) + TC_ENERGY_PER_STACK * stacks
            if effective < HEMORRHAGE_ENERGY or effective < POOL_FLOOR then return false end
            return NS.spell_ready(HEMORRHAGE, context.target)
        end,
        execute = function(context, s)
            local stacks = buff_stacks(context.me, THOUSAND_CUTS)
            return NS.try_cast(HEMORRHAGE, context.target,
                string.format("[FOREVER-SUBTLETY] Hemorrhage (Thousand Cuts x%d)", stacks))
        end,
    }
end

if CUTTHROAT and AMBUSH then
    delta_opener[#delta_opener + 1] = {
        name = "Forever_CutthroatAmbush",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if not buff_up(context.me, CUTTHROAT) then return false end
            if s.mh_dagger_ok == false then return false end
            if not is_behind(context.target) then return false end
            if (s.energy or 0) < AMBUSH_ENERGY then return false end
            return NS.spell_ready(AMBUSH, context.target)
        end,
        execute = function(context)
            return NS.try_cast(AMBUSH, context.target,
                "[FOREVER-SUBTLETY] Ambush (Cutthroat proc, stealth-free)")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the TC lane immediately above the baseline's
-- "Hemorrhage" builder (fallback: "SinisterStrikeFallback"), the Cutthroat
-- lane immediately above "Ambush" (fallback: "Backstab"); then append.
-- Re-registering the playstyle name replaces the baseline wholesale — the
-- combined list IS the "subtlety" playstyle on Forever.
-- ---------------------------------------------------------------------------
local BUILDER_ANCHORS = { Hemorrhage = true, SinisterStrikeFallback = true }
local OPENER_ANCHORS = { Ambush = true, Backstab = true }

local combined = {}
local builder_done = false
local opener_done = false
local function insert_builder()
    if builder_done then return end
    for j = 1, #delta_builder do combined[#combined + 1] = delta_builder[j] end
    builder_done = true
end
local function insert_opener()
    if opener_done then return end
    for j = 1, #delta_opener do combined[#combined + 1] = delta_opener[j] end
    opener_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name and OPENER_ANCHORS[name] then insert_opener() end
    if name and BUILDER_ANCHORS[name] then insert_builder() end
    combined[#combined + 1] = st
end
insert_builder()
insert_opener()

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Rogue subtlety Forever delta registered (" ..
    #delta_builder .. " thousand-cuts + " .. #delta_opener ..
    " cutthroat-ambush lanes over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
