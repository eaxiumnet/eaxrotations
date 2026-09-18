-- frost_forever.lua — Mage Frost delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Day-1 frost delta over the vanilla baseline: the engraving-granted
--        ICE LANCE burst lane (301% damage on Frozen targets — fired inside
--        the Frost Nova root window), the ICY VEINS cooldown lane (the
--        client's own trainer-taught 3-min cast-speed CD, which the vanilla
--        file predates), and a WINTER'S CHILL replacement lane whose stack /
--        refresh read uses the APPLIED debuff row the bridge now carries
--        (the baseline read the talent id, so its stack gate always saw 0).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/mage.md (Icy Veins overview 2026-09-13; beta DBC
--        2026-09-17): "Ice Lance — instant, low damage, 300% vs frozen
--        targets" and "Winter's Chill: now benefits ONLY Frostbolt + Ice
--        Lance (was all crit-capable frost spells) — snapshot logic
--        narrows". DBC: Ice Lance 400640@28 … 1240047@56 ("Deals 146 Frost
--        damage ... Deals 301% increased damage to Frozen targets") is
--        ENGRAVING-granted ("Engrave Gloves - Ice Lance"), so the lane gates
--        on is_spell_learned (both mirror ids); Frost Nova 122/10230 (25s
--        category CD) supplies the Frozen window via its root debuff;
--        Winter's Chill's applied row is 12579 ("increases the chance your
--        Ice Lance and Frostbolt spells will critically hit ... Stacks up to
--        6 times") — pinned in the builder's BUFF_OVERRIDES because the
--        name's lowest-id row (11180) is the talent; Icy Veins 429125
--        ("Hastens your spellcasting, increasing spell casting speed by 21%
--        ... Lasts 20", RecoveryTime 180000) is trainer-taught under Frost,
--        and the class map's 12472 is COLD SNAP on this client, so the lane
--        resolves the name through the bridge instead.
--        FINGERS OF FROST (400647/400669/400670) is a real client mechanic
--        but every row is BaseLevel 0, so the bridge builder's level guard
--        excludes it — the proc's "treat as Frozen" window is NOT readable
--        by name yet (recorded as a probe; fixing the guard touches every
--        mirror and needs its own commit).
-- SAFETY: ZERO numeric spell-ID literals — Ice Lance / Icy Veins / Frost
--        Nova / Winter's Chill all resolve through the bridge mirrors (or the
--        class map for the Frostbolt cast and the Nova rank ids); nil
--        lookups leave the lane dormant — never a guessed ID. The vanilla
--        baseline is loaded through an intercepted registration (holy_forever
--        template) so this file edits nothing in frost_vanilla.lua and its
--        safe_state-backed get_state is reused unchanged. Splice geometry:
--        Icy Veins lands above the baseline's "PresenceOfMind" cooldown lane,
--        the Ice Lance burst above "Blizzard" (the top of the damage block),
--        and the Winter's Chill replacement takes the baseline lane's exact
--        position — no defensive/utility lane is shadowed.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.MageSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "frost" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("mage frost", "classes/mage/frost_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- Ice Lance cast resolves through the maxrank mirror (and the learned check
-- reads both mirrors: the engraving grants the rank-1 row); Icy Veins and
-- the Winter's Chill debuff resolve through the buff/maxrank mirrors. A nil
-- lookup leaves the lane dormant -- never a guessed ID.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_name, by_maxrank, by_buff = mirrors.name, mirrors.maxrank, mirrors.buff

local ICE_LANCE = resolve_id(by_maxrank, "Ice Lance")
local ICE_LANCE_R1 = resolve_id(by_name, "Ice Lance")
local ICY_VEINS = resolve_id(by_maxrank, "Icy Veins")
local WINTERS_CHILL_DEBUFF = resolve_id(by_buff, "Winter's Chill")
local FROST_NOVA_BRIDGE = resolve_id(by_maxrank, "Frost Nova")

-- The Frozen window = the Frost Nova root debuff; its applied id is the cast
-- rank, so read the whole class-map rank list (plus the bridge's resolution).
local FROST_NOVA_IDS = {}
local append_unique = forever.append_unique
append_unique(FROST_NOVA_IDS, SPELLS.FrostNova
    and SPELLS.FrostNova._meta and SPELLS.FrostNova._meta.ids or nil)
append_unique(FROST_NOVA_IDS, { FROST_NOVA_BRIDGE })

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local EMPTY_OPTS = {}
local SELF_OPTS = { skip_range = true }

-- DBC-confirmed: Icy Veins RecoveryTime 180000 (20s, +21% cast speed);
-- Winter's Chill holds at 5+ stacks while more than 3s remain (the
-- baseline's own gate).
local FOREVER_ICY_VEINS_CD = 180
local FOREVER_WC_HOLD_STACKS = 5
local FOREVER_WC_REFRESH = 3

local setting = forever.setting

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

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

local function debuff_remains(unit, ids)
    if not unit or type(ids) ~= "table" or #ids == 0 or not NS.debuff_remains then return 0 end
    return NS.debuff_remains(unit, ids) or 0
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Icy Veins joins the cooldown block; the Ice Lance burst leads
-- the damage block; the Winter's Chill replacement takes the baseline slot.
-- ---------------------------------------------------------------------------

local delta_head = {}

if ICY_VEINS and knows_any(ICY_VEINS, nil) then
    delta_head[#delta_head + 1] = {
        name = "Forever_IcyVeins",
        matches = function(context, s)
            if not s.in_combat then return false end
            if not has_valid_enemy(context) then return false end
            if NS.should_use_long_cd and not NS.should_use_long_cd(context, FOREVER_ICY_VEINS_CD) then return false end
            return NS.spell_ready(ICY_VEINS, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function()
            return NS.try_cast(ICY_VEINS, NS.PLAYER_UNIT,
                "[FOREVER-FROST] Icy Veins (cast-speed CD)", SELF_OPTS)
        end,
    }
end

local delta_burst = {}

if ICE_LANCE then
    delta_burst[#delta_burst + 1] = {
        name = "Forever_IceLanceBurst",
        matches = function(context, s)
            if not knows_any(ICE_LANCE, ICE_LANCE_R1) then return false end
            if not has_valid_enemy(context) then return false end
            if debuff_remains(context.target, FROST_NOVA_IDS) <= 0 then return false end
            return NS.spell_ready(ICE_LANCE, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(ICE_LANCE, context.target,
                "[FOREVER-FROST] Ice Lance (Frozen window)")
        end,
    }
end

local delta_wc = {}

if WINTERS_CHILL_DEBUFF then
    delta_wc[#delta_wc + 1] = {
        name = "Forever_WintersChill",
        matches = function(context, s)
            if not has_valid_enemy(context) then return false end
            if s.is_moving then return false end
            if not s.frostbolt_ready then return false end
            local stacks = 0
            if NS.debuff_stacks then
                stacks = NS.debuff_stacks(context.target, { WINTERS_CHILL_DEBUFF }) or 0
            end
            if stacks >= setting(context, "frost_forever_wc_stacks", FOREVER_WC_HOLD_STACKS) then
                local remains = debuff_remains(context.target, { WINTERS_CHILL_DEBUFF })
                if remains > setting(context, "frost_forever_wc_refresh", FOREVER_WC_REFRESH) then return false end
            end
            return NS.spell_ready(SPELLS.Frostbolt, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Frostbolt, context.target,
                "[FOREVER-FROST] Winter's Chill upkeep")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: Icy Veins above "PresenceOfMind", the Ice Lance
-- burst above "Blizzard" (fallback: above "Frostbolt"; then append), and the
-- Winter's Chill replacement in the baseline lane's position.
-- Re-registering the playstyle name replaces the baseline wholesale.
-- ---------------------------------------------------------------------------
local CD_ANCHORS = { PresenceOfMind = true, Evocation = true }
local BURST_ANCHORS = { Blizzard = true, Frostbolt = true }
local REPLACED_LANES = (#delta_wc > 0) and { WintersChill = true } or {}

local combined = {}
local cd_inserted = false
local burst_inserted = false
local wc_inserted = false
local function insert_cd()
    if cd_inserted then return end
    for j = 1, #delta_head do combined[#combined + 1] = delta_head[j] end
    cd_inserted = true
end
local function insert_burst()
    if burst_inserted then return end
    for j = 1, #delta_burst do combined[#combined + 1] = delta_burst[j] end
    burst_inserted = true
end
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    local name = type(st) == "table" and st.name or nil
    if name == "WintersChill" and REPLACED_LANES.WintersChill then
        for j = 1, #delta_wc do combined[#combined + 1] = delta_wc[j] end
        wc_inserted = true
    elseif not (name and REPLACED_LANES[name]) then
        if not cd_inserted and name and CD_ANCHORS[name] then insert_cd() end
        if not burst_inserted and name and BURST_ANCHORS[name] then insert_burst() end
        combined[#combined + 1] = st
    end
end
insert_cd()
insert_burst()
if not wc_inserted then
    for j = 1, #delta_wc do combined[#combined + 1] = delta_wc[j] end
end

baseline.register(combined)
if NS.log then NS.log("Mage frost Forever delta registered (" ..
    #delta_head .. " icy-veins + " .. #delta_burst .. " ice-lance + " ..
    #delta_wc .. " winter's-chill lane" ..
    ((#delta_wc > 0) and ", baseline WintersChill replaced" or "") ..
    " over " .. #baseline.strategies .. " baseline lanes)") end

return combined
