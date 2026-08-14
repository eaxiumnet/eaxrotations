-- sod_context_sylvanas.lua — SoD-era context enrichment for the dispatcher.
-- WHAT:  pure enrich(ctx) that extends the engine context with the rotation
--        state fields the _sod spec files read (form, pet hp, poison stacks,
--        shield/totem/imbue/HoT state, Maelstrom stacks, swing timers).
-- WHEN:  called from main_sylvanas.lua only on SoD clients (is_sod), after
--        the base context build; never on TBC/vanilla/wotlk clients.
-- WHY:   the 2026-08 read-side audit flagged ~25 SOD context fields as read
--        but produced by nothing — every _sod rotation degraded to defaults,
--        several to a fully-dead rotation (druid bear/cat form, shaman warden
--        Rockbiter gate, warlock-tank Metamorphosis gate, rogue Envenom).
-- SAFETY: pure function over ctx + cached NS helpers; every read is
--         nil-guarded; non-SoD eras never call it (zero behavior change).
--         Spell ids are mirrored from the repo's own class data (the era's
--         data): rogue poison tables (assassination_sylvanas:53,
--         combat_sylvanas:54, assassination_vanilla:23), shaman imbue/shield
--         tables (enhancement_sylvanas:60/99/104), druid HoT ids
--         (healing_sylvanas:26/28), Maelstrom ids (enhancement_wotlk:32),
--         and the _sod files' own ACTION rune ids.
-- DECISION: fields with a working fallback (pet_alive/has_pet via ctx.pet,
--         heal_target via ctx.lowest, holy_shield_charges via NS.buff_points,
--         remaining_time via ctx.target_ttd) stay allowlisted in the audit,
--         not wired here. Fields needing data the API does not expose
--         (offhand_imbue per-weapon, dual_daggers weapon type, fire/water
--         totem slot index) also stay allowlisted with evidence.

local NS = _G.EaxRotations

-- Druid forms (NS.has_form FORMS table: cat = {768}, bear = {5487, 9634}).
-- Metamorphosis: WotLK meta aura 47241 (borrowed by the SoD client's rune
-- mechanic) + the SoD rune cast id 403789 (the file's own ACTION id).
-- Best-effort: if the SoD aura id differs from both, the lane stays dark
-- (no worse than today) until SoD client data lands in-repo.
local CAT_FORM = { 768 }
local BEAR_FORM = { 5487, 9634 }
local METAMORPHOSIS_BUFF = { 47241, 403789 }

-- Deadly Poison debuff ranks (repo rogue tables, both eras).
local DEADLY_POISON = {
    27187, 27186, 26968, 26967, 25349, 25347, 11356, 11355, 11354, 11353,
    11352, 11351, 11350, 11349, 2819, 2837, 2818, 2835,
}

-- Self-buffs / target debuffs (ids from the _sod files' own ACTION tables
-- and the TBC siblings' buff tables).
local SND_BUFF = { 6774, 5171 }
local CRIMSON_TEMPEST = { 412096 }
local BLADE_DANCE = { 400012 }
local FLAME_SHOCK = { 29228, 10448, 10447, 8053, 8052, 8050 }
local MAELSTROM_WEAPON = { 53817, 53816, 53815, 53814, 53813 }
local LIGHTNING_SHIELD = { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local WATER_SHIELD = { 33736, 24398 }
local RIPTIDE = { 408521 }
-- Lifebloom: the SoD rune spell (409824) applies its own aura, so the buff
-- table must carry the rune id — Riptide precedent directly above (rune
-- 408521 tracked as 408521). 33763 is the TBC rank-3 id; buff_up against it
-- never matched live, so has_lifebloom stayed false and the restoration_sod
-- Lifebloom lane re-cast every tick (fix 2026-08-14).
local LIFEBLOOM = { 409824 }
-- Weakened Soul debuff id (mirrors healing_sylvanas.lua:41 WEAKENED_SOUL_DEBUFF_IDS).
local WEAKENED_SOUL = { 6788 }
-- Totem slots (player:get_totem_info): 1 = fire, 2 = earth, 3 = water, 4 = air
-- (mirrors elemental_wotlk.lua:42).
local TOTEM_SLOT_FIRE = 1
local TOTEM_SLOT_WATER = 3
local REJUVENATION = { 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }
local ROCKBITER = { 25485, 25479, 16316, 16315, 16314, 10399, 8019, 8018, 8017 }

-- Feral / feral-tank / warlock / hunter refresh-state ids (from the _sod
-- files' own ACTION tables: feral_sod, tank_sod, warlock dps/tank, hunter dps).
local SAVAGE_ROAR = { 407988 }
local MANGLE_CAT = { 409828 }
local RIP = { 9896, 9493 }
local RAKE = { 9904, 1824 }
local LACERATE = { 414644 }
local CURSE_RECKLESSNESS_TANK = { 11717 }
local CURSE_RECKLESSNESS_DPS = { 7658 }
local SHADOW_CLEAVE = { 403851 }
local IMMOLATE_TANK = { 11668 }
local IMMOLATE_DPS = { 11665 }
local CORRUPTION = { 11672 }
local SERPENT_STING = { 25295, 13555 }
local SUNDER = { 7386, 7405, 8380, 11596, 11597, 25225 } -- engine has_sunder ids (main_sylvanas:1294)
local DEMO_SHOUT = { 25203, 25202, 11556, 11555, 11554, 6190, 1160 } -- arms_sylvanas:79

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

--- Extend an engine context with the SoD rotation state fields.
---@param ctx table the engine _context (me/target/pet/pet_dead/is_moving/
---        lowest_unit already populated by main_sylvanas).
---@return table ctx (same table, mutated in place for zero-allocation reuse)
function M_enrich(ctx)
    if type(ctx) ~= "table" then return ctx end
    local me = ctx.me
    local target = ctx.target
    local pet = ctx.pet
    local heal_target = ctx.lowest_unit

    -- Aliases from fields the engine already computes (zero API cost).
    -- _context.hp / _context.target_hp are health PERCENTAGES (unit_health_pct).
    ctx.moving = ctx.is_moving == true
    ctx.hp_pct = ctx.hp
    ctx.target_hp_pct = ctx.target_hp

    -- Healer-injury alias: the engine's lazy party_scan produces
    -- party_injured_count (main_sylvanas.lua:1237); the _sod resto files read
    -- context.injured_count (druid/restoration_sod:29 + shaman/restoration_sod:31).
    -- Without this alias, WildGrowth / Chain Heal / Healing Stream Totem lanes
    -- gated on injured_count >= 2/3 never fired in production (the guarded
    -- fallback degrades to 0). Wired 2026-08-14 (W4.1).
    ctx.injured_count = type(ctx.party_injured_count) == "number" and ctx.party_injured_count or 0

    -- Druid / warlock forms.
    if me then
        if NS and type(NS.has_form) == "function" then
            ctx.in_cat_form = call(NS.has_form, "cat") == true
            ctx.in_bear_form = call(NS.has_form, "bear") == true
        end
        if type(ctx.metamorphosis_active) ~= "boolean" and NS and type(NS.buff_up) == "function" then
            ctx.metamorphosis_active = call(NS.buff_up, me, METAMORPHOSIS_BUFF) == true
        end
    end

    -- Feral cat refresh state (buff/debuff remains).
    if me and NS and type(NS.buff_remains) == "function" then
        ctx.savage_roar_remains = call(NS.buff_remains, me, SAVAGE_ROAR) or 0
    end
    if target and NS and type(NS.debuff_remains) == "function" then
        ctx.mangle_remains = call(NS.debuff_remains, target, MANGLE_CAT) or 0
        ctx.rip_remains = call(NS.debuff_remains, target, RIP) or 0
        ctx.rake_remains = call(NS.debuff_remains, target, RAKE) or 0
        ctx.lacerate_remains = call(NS.debuff_remains, target, LACERATE) or 0
    end
    if target and NS and type(NS.debuff_stacks) == "function" then
        ctx.lacerate_stacks = call(NS.debuff_stacks, target, LACERATE) or 0
    end

    -- Warlock (tank + dps) DoT refresh state on the target.
    if target and NS and type(NS.debuff_remains) == "function" then
        ctx.curse_remains = math.max(
            call(NS.debuff_remains, target, CURSE_RECKLESSNESS_TANK) or 0,
            call(NS.debuff_remains, target, CURSE_RECKLESSNESS_DPS) or 0)
        ctx.shadow_cleave_remains = call(NS.debuff_remains, target, SHADOW_CLEAVE) or 0
        ctx.immolate_remains = math.max(
            call(NS.debuff_remains, target, IMMOLATE_TANK) or 0,
            call(NS.debuff_remains, target, IMMOLATE_DPS) or 0)
        ctx.corruption_remains = call(NS.debuff_remains, target, CORRUPTION) or 0
    end

    -- Hunter serpent sting on the target.
    if target and NS and type(NS.debuff_remains) == "function" then
        ctx.serpent_sting_remains = call(NS.debuff_remains, target, SERPENT_STING) or 0
    end

    -- Warrior (SoD tank) sunder stacks + demoralizing-shout refresh state.
    if target and NS and type(NS.debuff_stacks) == "function" then
        ctx.sunder_stacks = call(NS.debuff_stacks, target, SUNDER) or 0
    end
    if target and NS and type(NS.debuff_remains) == "function" then
        ctx.demoralizing_remains = call(NS.debuff_remains, target, DEMO_SHOUT) or 0
    end

    -- Pet health percentage (MendPet / HealthFunnel gates).
    if pet and NS and type(NS.unit_health_pct) == "function" then
        ctx.pet_hp_pct = call(NS.unit_health_pct, pet)
    end

    -- Rogue: poison stacks on target, S&D / Crimson Tempest / Blade Dance.
    if target and NS and type(NS.debuff_stacks) == "function" then
        local ps = call(NS.debuff_stacks, target, DEADLY_POISON) or 0
        ctx.poison_stacks = ps
        ctx.deadly_poison_stacks = ps
        ctx.target_poisoned = ps > 0
    end
    if me and NS and type(NS.buff_remains) == "function" then
        ctx.snd_remains = call(NS.buff_remains, me, SND_BUFF) or 0
        ctx.blade_dance_remains = call(NS.buff_remains, me, BLADE_DANCE) or 0
    end
    if target and NS and type(NS.debuff_remains) == "function" then
        ctx.crimson_tempest_remains = call(NS.debuff_remains, target, CRIMSON_TEMPEST) or 0
        ctx.flame_shock_remains = call(NS.debuff_remains, target, FLAME_SHOCK) or 0
    end

    -- Shaman: Maelstrom stacks, shields, weapon imbue, Riptide on heal target.
    if me and NS then
        if type(NS.buff_points) == "function" then
            local pts = call(NS.buff_points, me, MAELSTROM_WEAPON)
            -- Fall back to NS.buff_stacks (defined in core_sylvanas 2026-08-11;
            -- buff_points returns aura POINTS, stacks need the stacks reader).
            ctx.maelstrom_stacks = (pts and pts[1])
                or (NS.buff_stacks and NS.buff_stacks(me, MAELSTROM_WEAPON))
                or 0
        end
        if type(NS.buff_up) == "function" then
            ctx.lightning_shield_up = call(NS.buff_up, me, LIGHTNING_SHIELD) == true
            ctx.water_shield_up = call(NS.buff_up, me, WATER_SHIELD) == true
            local rock = call(NS.buff_up, me, ROCKBITER) == true
            ctx.has_rockbiter_imbue = rock
            if rock then ctx.mainhand_imbue = "rockbiter" end
        end
    end
    if heal_target and NS and type(NS.buff_remains) == "function" then
        ctx.riptide_remains = call(NS.buff_remains, heal_target, RIPTIDE) or 0
    end

    -- Druid resto HoT flags on the heal target.
    if heal_target and NS and type(NS.buff_up) == "function" then
        ctx.has_lifebloom = call(NS.buff_up, heal_target, LIFEBLOOM) == true
        ctx.has_rejuvenation = call(NS.buff_up, heal_target, REJUVENATION) == true
    end

    -- Priest: Weakened Soul on the heal target (PW:S refresh gate in
    -- healing_sod reads lowest.has_weakened_soul — previously mock-only; the
    -- audit allowlist pin is removed W4.2 and this is the real writer).
    -- Mutates the engine's `lowest` table (same table the spec reads), so
    -- the chained subfield read wakes up in production.
    if heal_target and NS and type(NS.debuff_up) == "function" then
        local weakest = ctx.lowest
        if type(weakest) == "table" then
            weakest.has_weakened_soul = call(NS.debuff_up, heal_target, WEAKENED_SOUL) == true
        end
    end

    -- Shaman: fire/water totem slot occupancy (warden Magma/Searing totem
    -- gates + restoration_sod HealingStream gate). Mirrors the wotlk slot
    -- mapping (elemental_wotlk.lua:42: 1 = fire, 2 = earth, 3 = water,
    -- 4 = air) via NS.get_totem_info — the allowlist pins (previously
    -- "totem-slot index ambiguous") are removed W4.2.
    if NS and type(NS.get_totem_info) == "function" then
        local fire_info = call(NS.get_totem_info, TOTEM_SLOT_FIRE)
        ctx.fire_totem_active = type(fire_info) == "table" and fire_info.have_totem == true or false
        local water_info = call(NS.get_totem_info, TOTEM_SLOT_WATER)
        ctx.water_totem_active = type(water_info) == "table" and water_info.have_totem == true or false
    end

    -- Enhancement LavaBurst swing window (time until next mainhand/offhand swing).
    if NS then
        if type(NS.get_time_until_swing) == "function" then
            ctx.auto_swing_remains = call(NS.get_time_until_swing) or 0
        end
        if type(NS.get_time_until_oh_swing) == "function" then
            ctx.melee_swing_remains = call(NS.get_time_until_oh_swing) or 0
        end
    end

    return ctx
end

-- Canonical export shape (callable via require("shared/sod_context_sylvanas")).
local M = { enrich = M_enrich }
return M

