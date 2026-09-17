-- resto_forever.lua — Druid Restoration delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 resto delta over the vanilla baseline: the WILD GROWTH party
--        HoT lane (the client's 6s-cooldown party heal), a broadened
--        SWIFTMEND spot-heal lane (non-consuming per the client text), and
--        the GIFT OF THE EARTHMOTHER Rejuvenation blanket lane (the talent's
--        1s GCD makes blanketing cheap). All three sit above the baseline's
--        own lanes for the same spell and reuse its healing-entry state.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/druid.md (Icy Veins overview 2026-09-15; beta DBC
--        2026-09-17): "Wild Growth (NEW): party-wide HoT on a short CD —
--        expected core raid/dungeon heal (cooldown-tracked lane)"; "Swiftmend
--        no longer consumes the HoT (still requires one active) — becomes a
--        spam-able spot heal"; "Gift of the Earthmother: Rejuv/Swiftmend/Wild
--        Growth GCD −0.5s (1s GCD) — blanket-the-group speed lane". DBC:
--        Wild Growth ladder 408120@40 / 1238214@50 / **1238215@60** ("Heals
--        the target and their party for 98 over 7 ... within $a1 yards",
--        cooldown_s 6.0, HoT aura row); Swiftmend 18562 ("Instantly heals a
--        target with an active Rejuvenation or Regrowth effect ...", 15s CD —
--        the text carries no consumption clause); Gift of the Earthmother
--        414673 ("Reduces the global cooldown by X sec on your Rejuvenation,
--        Swiftmend, and Wild Growth spells"); Rejuvenation 774/25299,
--        Regrowth 8936/9858 resolve. HoTs-can-crit and the Reflection regen
--        are passives (no lane).
--        TREE OF LIFE 439745 exists on the client ("Increased all healing
--        received by party members within $a1 yards by 11%") but the kit does
--        not claim it and its form semantics (does the shapeshift restrict
--        spells?) are not DBC-readable — recorded as a probe, not a lane.
--        Lifebloom / Nourish / Living Seed are absent (not backported).
-- SAFETY: ZERO numeric spell-ID literals — Wild Growth resolves BY NAME
--        through the maxrank mirror (dormant without it); Swiftmend /
--        Rejuvenation / the Gift talent come from the class map and the
--        bridge's maxrank mirror respectively; nil lookups leave the lane
--        dormant — never a guessed ID. The vanilla baseline is loaded
--        through an intercepted registration (holy_forever template) so this
--        file edits nothing in resto_vanilla.lua and its build_state is
--        reused unchanged. Splice geometry: Wild Growth lands above the
--        baseline's "SwiftmendEmergency" (the first heal lane below the
--        defensives), the Swiftmend spot-heal immediately after it, and the
--        Rejuv blanket above "PriorityRejuvenation" — no emergency lane is
--        shadowed.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.DruidSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "resto" playstyle
-- is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] druid resto delta: rotation_registry unavailable", 0)
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
package.loaded["classes/druid/resto_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/druid/resto_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] druid resto delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): Wild
-- Growth (cast) and Gift of the Earthmother (talent gate) resolve through
-- the maxrank mirror; a nil lookup leaves the lane dormant -- never a guessed
-- ID. Sentinel stand-ins are seeded per mirror by the battery's build_ns.
-- ---------------------------------------------------------------------------
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_maxrank = (ForeverBridge
    and type(ForeverBridge.spell_maxrank_by_name_forever) == "table")
    and ForeverBridge.spell_maxrank_by_name_forever or {}

local function resolve_id(map, client_name)
    local id = map[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local WILD_GROWTH = resolve_id(by_maxrank, "Wild Growth")
local GIFT_OF_THE_EARTHMOTHER = resolve_id(by_maxrank, "Gift of the Earthmother")

-- Healing-entry access: the baseline's state does not carry the scan arrays,
-- so the delta calls the same frame-cached druid healing scan directly (the
-- module decorates entries with has_rejuvenation/has_regrowth).
local Healing = NS.DruidHealing
if type(Healing) ~= "table" then
    local ok_healing, mod = pcall(require, "classes/druid/healing_sylvanas")
    if ok_healing and type(mod) == "table" then Healing = mod end
end

local function scan()
    if type(Healing) ~= "table" or type(Healing.scan_healing_targets) ~= "function" then
        return nil, 0
    end
    local ok, entries, count = pcall(Healing.scan_healing_targets)
    if not ok then return nil, 0 end
    return entries, (type(count) == "number" and count) or (type(entries) == "table" and #entries) or 0
end

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}

-- DBC-confirmed: Wild Growth cooldown_s 6.0; the party-hurt gate wants two
-- hurt members to be worth the cast; the Swiftmend spot-heal broadens the
-- baseline's emergency threshold; the Rejuv blanket tops the baseline's
-- 92/88 thresholds up towards full coverage while GotE is learned.
local FOREVER_WG_CD = 6
local FOREVER_WG_HURT_HP = 90
local FOREVER_WG_MIN_HURT = 2
local FOREVER_SWIFTMEND_SPOT_HP = 90
local FOREVER_BLANKET_HP = 95
local FOREVER_BLANKET_MANA_FLOOR = 35

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

local function knows(id)
    if not id or type(NS.is_spell_learned) ~= "function" then return false end
    local ok, learned = pcall(NS.is_spell_learned, id)
    return ok and learned == true
end

local function entry_hp(entry)
    if not entry then return 100 end
    if type(entry.effective_hp) == "number" then return entry.effective_hp end
    if type(entry.hp) == "number" then return entry.hp end
    return 100
end

-- HoT presence on a healing entry: the scan's flags first (production), then
-- the class map's own rank ids through the engine buff read (mirrors the
-- baseline's has_hot_for_swiftmend; kept nil-guarded for the battery).
local REJUV_IDS = (SPELLS.Rejuvenation and SPELLS.Rejuvenation._meta
    and SPELLS.Rejuvenation._meta.ids) or nil
local REGROWTH_IDS = (SPELLS.Regrowth and SPELLS.Regrowth._meta
    and SPELLS.Regrowth._meta.ids) or nil

local function has_hot(entry)
    if not entry or not entry.unit then return false end
    if entry.has_rejuvenation == true or entry.has_regrowth == true then return true end
    if NS.buff_up then
        if type(REJUV_IDS) == "table" and NS.buff_up(entry.unit, REJUV_IDS) then return true end
        if type(REGROWTH_IDS) == "table" and NS.buff_up(entry.unit, REGROWTH_IDS) then return true end
    end
    return false
end

local function count_hurt(entries, n, threshold)
    if type(entries) ~= "table" then return 0 end
    local hurt = 0
    for i = 1, n do
        local entry = entries[i]
        if entry and entry.unit and entry_hp(entry) <= threshold then
            hurt = hurt + 1
        end
    end
    return hurt
end

-- Party-heal anchor: the tank when hurt, otherwise the lowest-HP member.
local function pick_anchor(entries, count)
    local tank = NS.healing_get_tank and NS.healing_get_tank(entries, count) or nil
    if tank and entry_hp(tank) <= FOREVER_WG_HURT_HP then return tank end
    return NS.healing_get_lowest_hp and NS.healing_get_lowest_hp(entries, count, 100) or nil
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Wild Growth leads the heal block (it is a party HoT on a
-- short CD), then the Swiftmend spot-heal, then the blanket lane sits above
-- the baseline's own Rejuvenation lane.
-- ---------------------------------------------------------------------------

local delta_head = {}

if WILD_GROWTH then
    delta_head[#delta_head + 1] = {
        name = "Forever_WildGrowth",
        matches = function(context, s)
            if not s.in_combat and not context.in_combat then return false end
            if context.is_moving then return false end
            if (s.mana_pct or 100) < setting(context, "resto_forever_wg_mana_floor", FOREVER_BLANKET_MANA_FLOOR) then return false end
            local entries, count = scan()
            local hurt = count_hurt(entries, count,
                setting(context, "resto_forever_wg_hurt_hp", FOREVER_WG_HURT_HP))
            if hurt < setting(context, "resto_forever_wg_min_hurt", FOREVER_WG_MIN_HURT) then return false end
            local anchor = pick_anchor(entries, count)
            if not anchor or not anchor.unit then return false end
            return NS.spell_ready(WILD_GROWTH, anchor.unit, { expected_cooldown = FOREVER_WG_CD })
        end,
        execute = function(_, s)
            local entries, count = scan()
            local anchor = pick_anchor(entries, count)
            if not anchor or not anchor.unit then return false end
            return NS.try_cast(WILD_GROWTH, anchor.unit,
                string.format("[FOREVER-RESTO] Wild Growth party HoT %.0f%%", entry_hp(anchor)))
        end,
    }
end

local delta_swiftmend = {}

-- The client text has no consumption clause, so Swiftmend is a spot heal:
-- fire it on any HoT-carrying ally inside a broad hurt window (the baseline
-- emergency lane keeps the critical cases).
delta_swiftmend[#delta_swiftmend + 1] = {
    name = "Forever_SwiftmendSpotHeal",
    matches = function(context, s)
        if not s.in_combat and not context.in_combat then return false end
        if not SPELLS.Swiftmend then return false end
        local spot_hp = setting(context, "resto_forever_swiftmend_hp", FOREVER_SWIFTMEND_SPOT_HP)
        local entries, n = scan()
        if type(entries) ~= "table" then return false end
        for i = 1, n do
            local entry = entries[i]
            if entry and entry.unit and has_hot(entry) and entry_hp(entry) <= spot_hp then
                if NS.spell_ready(SPELLS.Swiftmend, entry.unit, EMPTY_OPTS) then
                    return true
                end
                return false
            end
        end
        return false
    end,
    execute = function(context, s)
        local spot_hp = setting(context, "resto_forever_swiftmend_hp", FOREVER_SWIFTMEND_SPOT_HP)
        local entries, n = scan()
        if type(entries) ~= "table" then return false end
        for i = 1, n do
            local entry = entries[i]
            if entry and entry.unit and has_hot(entry) and entry_hp(entry) <= spot_hp then
                return NS.try_cast(SPELLS.Swiftmend, entry.unit,
                    string.format("[FOREVER-RESTO] Swiftmend spot heal %.0f%%", entry_hp(entry)))
            end
        end
        return false
    end,
}

local delta_blanket = {}

-- Gift of the Earthmother: the 1s GCD makes blanketing the group with
-- Rejuvenation affordable, so the lane applies it up to a higher HP
-- threshold than the baseline's role-based gates.
if GIFT_OF_THE_EARTHMOTHER and knows(GIFT_OF_THE_EARTHMOTHER) then
    delta_blanket[#delta_blanket + 1] = {
        name = "Forever_RejuvBlanket",
        matches = function(context, s)
            if not s.in_combat and not context.in_combat then return false end
            if (s.mana_pct or 100) < setting(context, "resto_forever_blanket_mana_floor", FOREVER_BLANKET_MANA_FLOOR) then return false end
            local blanket_hp = setting(context, "resto_forever_blanket_hp", FOREVER_BLANKET_HP)
            local entries, n = scan()
            if type(entries) ~= "table" then return false end
            for i = 1, n do
                local entry = entries[i]
                if entry and entry.unit and not has_hot(entry) and entry_hp(entry) <= blanket_hp then
                    if NS.spell_ready(SPELLS.Rejuvenation, entry.unit, EMPTY_OPTS) then
                        return true
                    end
                    return false
                end
            end
            return false
        end,
        execute = function(context, s)
            local blanket_hp = setting(context, "resto_forever_blanket_hp", FOREVER_BLANKET_HP)
            local entries, n = scan()
            if type(entries) ~= "table" then return false end
            for i = 1, n do
                local entry = entries[i]
                if entry and entry.unit and not has_hot(entry) and entry_hp(entry) <= blanket_hp then
                    return NS.try_cast(SPELLS.Rejuvenation, entry.unit,
                        string.format("[FOREVER-RESTO] Rejuv blanket %.0f%%", entry_hp(entry)))
                end
            end
            return false
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: Wild Growth above "SwiftmendEmergency" (fallback:
-- above "NaturesSwiftness"; then append), the Swiftmend spot-heal right
-- after the emergency lane, and the blanket above "PriorityRejuvenation"
-- (fallback: after the spot-heal). Re-registering the playstyle name replaces
-- the baseline wholesale.
-- ---------------------------------------------------------------------------
local WG_ANCHORS = { NaturesSwiftness = true }
local BLANKET_ANCHORS = { PriorityRejuvenation = true, RegrowthSpotHeal = true }

local combined = {}
local wg_done = false
local swift_done = false
local blanket_done = false
local function insert_wg()
    if wg_done then return end
    for j = 1, #delta_head do combined[#combined + 1] = delta_head[j] end
    wg_done = true
end
local function insert_swift()
    if swift_done then return end
    for j = 1, #delta_swiftmend do combined[#combined + 1] = delta_swiftmend[j] end
    swift_done = true
end
local function insert_blanket()
    if blanket_done then return end
    for j = 1, #delta_blanket do combined[#combined + 1] = delta_blanket[j] end
    blanket_done = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name == "SwiftmendEmergency" then
        insert_wg()
        combined[#combined + 1] = st
        insert_swift()
    elseif name and BLANKET_ANCHORS[name] then
        insert_blanket()
        combined[#combined + 1] = st
    else
        if not wg_done and name and WG_ANCHORS[name] then insert_wg() end
        combined[#combined + 1] = st
    end
end
insert_wg()
insert_swift()
insert_blanket()

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Druid resto Forever delta registered (" ..
    #delta_head .. " wild-growth + " .. #delta_swiftmend .. " swiftmend-spot + " ..
    #delta_blanket .. " rejuv-blanket lane over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
