-- ooc_manager_sylvanas.lua -- mount/buff/vendor/regen behaviours when not in combat.
-- WHAT:   mount/buff/vendor/regen behaviours when not in combat
-- WHEN:   called per-tick when not in_combat and not mounted
-- WHY:    centralises 11 different OOC strategies into one dispatcher
-- SAFETY: calls api only outside combat; nil-guarded player check
-- DECISION: consumed by specs via require(); no on_update side-effects.

-- What:     Automates pre-combat setup: class buff refreshes, pet summons, and
--           food/flask consumption while out of combat.
-- When:     Called by main_sylvanas.lua's on_rotation_update() ONLY when
--           in_combat == false and has_valid_enemy_target == false. The 1s
--           throttle via _last_check keeps the actual spell work at 1Hz even
--           though the function entry happens at the dispatch rate.
-- Why:      Prevents downtime from missing class buffs (e.g. Battle Shout,
--           Arcane Intellect, Fel Armor), unsummoned pets, or missing
--           food/flask when entering combat. The throttle chain prevents
--           per-frame retry spam when spells fail due to GCD, cooldown, or
--           broken spell-book APIs on private server builds.
-- Decision: Historically this module self-registered into the shared
--           NS.register_on_update_callback (20Hz) dispatcher AND was also
--           called directly from main_sylvanas.lua's OOC branch. That
--           double-fired the function entry at ~40Hz even though the
--           internal 1s throttle kept the actual cast work at 1Hz. Now
--           register_ooc_manager() is a no-op for backwards compat and the
--           sole entry point is main_sylvanas.lua.
-- Safety:   Five-layer throttle chain prevents infinite retry loops:
--             1. on_update fires at most 1/s via _last_check timer
--             2. GCD gate — skips entirely when gcd_remains > 0
--             3. broken_api_throttled — per-spell lockout after a successful
--                cast (buffs: 300s / pets: 10s). buff_remains often returns 0
--                on PS when auras are broken, so without a long lockout MotW/
--                Thorns re-queue every GCD.
--             4. Buff threshold — only recast when buff_remains <
--                ooc_buff_threshold (default 30s)
--             5. Healer mana floor — skips buffs when mana < threshold
-- Decision:  Buff entries define their full rank array; get_spell resolves
--           the highest known rank via NS.spell_action. Mutually exclusive
--           groups (Fel Armor/Demon Armor, Water Shield/Lightning Shield)
--           share a combined buff-remains check to prevent endless toggling.
--           Pet summon uses expected_cooldown to track server-side cooldown.
--           Food/flask uses a setting-defined spell ID with per-spawn
--           throttling.
--
-- Buff refresh flow (try_self_buffs):
--   1. should_handle_buff filters by opt-in, level gating, setting override
--   2. reset_work_ids copies buff rank IDs into reusable _work_ids table
--   3. NS.buff_remains checks all buff IDs; nil = API unavailable, skip
--   4. If remains <= threshold, resolve spell action via get_spell/NS.spell_action
--   5. broken_api_throttled guard: skip for SELF_BUFF_LOCKOUT (300s) after cast
--   6. NS.try_cast with skip_range=true
--
-- Throttle chain detail (single entry point now: main_sylvanas.lua dispatch):
--   main_sylvanas on_rotation_update (20Hz) -> not in_combat && no enemy
--     -> M.on_update(context) -> 1s internal throttle -> GCD guard
--     -> per-path logic:
--       try_pet_summon  -> broken_api_throttled(10s) -> NS.try_cast(cooldown)
--       try_self_buffs  -> healer mana floor -> for each entry:
--         should_handle_buff -> buff_remains <= threshold -> get_spell ->
--         broken_api_throttled(300s) -> NS.try_cast(skip_range)
--       try_buff_upgrades -> buff_rank position > 1 -> NS.try_cast (rank upgrade)
--       try_food_flask  -> broken_api_throttled(3s) -> NS.try_cast (numeric ID, no rank mismatch)

-- Long-duration class self-buffs (MotW 30m, Thorns 10m, AI, Fort, etc.).
-- When aura APIs lie (buff_remains=0 while buff is up), only recent-cast
-- history can stop recast spam. 5 minutes is well under real durations.
local SELF_BUFF_LOCKOUT = 300.0
local PET_SUMMON_LOCKOUT = 10.0
local _throttle_log_at = {}

local _G = _G
local NS = _G.EaxRotations
local spec_kit = require("shared/spec_kit_sylvanas")

local M = {}

local type, tostring = type, tostring
local EMPTY = {}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { BUFFS = {} } end
local _rbf_ok, RBF = pcall(require, "shared/ranked_buff_families_sylvanas")
if not _rbf_ok or type(RBF) ~= "table" then RBF = nil end

local _last_check = -1000
local _spell_cache = {}
local _work_ids = { n = 0 }
local _buff_upgrade_ok, _buff_upgrade = pcall(require, "shared/buff_upgrade_sylvanas")

local CLASS = NS and NS.CLASS_ID or {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

-- Buff detect/cast ladders: single source in ranked_buff_families_sylvanas.lua
-- (Vanilla ∪ TBC ∪ WotLK, best-first detect, high→low cast).
local function rbf_detect(key)
    return (RBF and RBF.detect_n and RBF.detect_n(key)) or { n = 0 }
end
local function rbf_cast(key)
    return (RBF and RBF.cast and RBF.cast(key)) or {}
end
local function rbf_label(key, fallback)
    return (RBF and RBF.label and RBF.label(key)) or fallback
end

local BUFFS = {
    battle_shout = rbf_detect("battle_shout"),
    commanding_shout = rbf_detect("commanding_shout"),
    aspect_hawk = rbf_detect("aspect_hawk"),
    mage_armor = rbf_detect("mage_armor"),
    arcane_intellect = rbf_detect("arcane_intellect"),
    righteous_fury = rbf_detect("righteous_fury"),
    inner_fire = rbf_detect("inner_fire"),
    power_word_fortitude = rbf_detect("power_word_fortitude"),
    water_shield = rbf_detect("water_shield"),
    lightning_shield = rbf_detect("lightning_shield"),
    mark_of_the_wild = rbf_detect("mark_of_the_wild"),
    thorns = rbf_detect("thorns"),
    fel_armor = rbf_detect("fel_armor"),
    demon_armor = rbf_detect("demon_armor"),
}

-- Combined exclusive families (same detect table for both sides of the pair).
local ALL_WARLOCK_ARMOR = rbf_detect("fel_armor")
local ALL_SHAMAN_SHIELDS = rbf_detect("water_shield")
local ALL_MAGE_ARMOR = rbf_detect("mage_armor")

local DEFAULT_BUFFS_BY_CLASS = {
    [CLASS.WARRIOR] = {
        { key = "battle_shout", label = rbf_label("battle_shout", "Battle Shout"), buff = BUFFS.battle_shout, spell = rbf_cast("battle_shout") },
    },
    [CLASS.HUNTER] = {
        { key = "aspect_hawk", label = rbf_label("aspect_hawk", "Aspect of the Hawk"), buff = BUFFS.aspect_hawk, spell = rbf_cast("aspect_hawk") },
    },
    [CLASS.MAGE] = {
        { key = "mage_armor", label = "Armor (Mage/Frost/Ice)", buff = ALL_MAGE_ARMOR, spell = rbf_cast("mage_armor") },
        { key = "arcane_intellect", label = rbf_label("arcane_intellect", "Arcane Intellect"), buff = BUFFS.arcane_intellect, spell = rbf_cast("arcane_intellect") },
    },
    [CLASS.PALADIN] = {
        { key = "righteous_fury", label = rbf_label("righteous_fury", "Righteous Fury"), buff = BUFFS.righteous_fury, spell = 25780 },
    },
    [CLASS.PRIEST] = {
        { key = "inner_fire", label = rbf_label("inner_fire", "Inner Fire"), buff = BUFFS.inner_fire, spell = rbf_cast("inner_fire") },
        { key = "power_word_fortitude", label = rbf_label("power_word_fortitude", "Power Word: Fortitude"), buff = BUFFS.power_word_fortitude, spell = rbf_cast("power_word_fortitude") },
    },
    [CLASS.SHAMAN] = {
        {
            key = "water_shield",
            label = rbf_label("water_shield", "Water Shield"),
            buff = ALL_SHAMAN_SHIELDS,
            spell = { name = "Water Shield", ids = rbf_cast("water_shield"), power_type = "none" },
            min_level = 60,
        },
        {
            key = "lightning_shield",
            label = rbf_label("lightning_shield", "Lightning Shield"),
            buff = ALL_SHAMAN_SHIELDS,
            spell = { name = "Lightning Shield", ids = rbf_cast("lightning_shield") },
            opt_in = true,
            default_below_level = 60,
        },
    },
    [CLASS.WARLOCK] = {
        { key = "fel_armor", label = rbf_label("fel_armor", "Fel Armor"), buff = ALL_WARLOCK_ARMOR, spell = rbf_cast("fel_armor") },
        { key = "demon_armor", label = rbf_label("demon_armor", "Demon Armor"), buff = ALL_WARLOCK_ARMOR, spell = rbf_cast("demon_armor"), fallback = true },
    },
    [CLASS.DRUID] = {
        -- spell = MotW ranks only (no Gift reagents). buff detect includes GotW.
        { key = "mark_of_the_wild", label = rbf_label("mark_of_the_wild", "Mark of the Wild"), buff = BUFFS.mark_of_the_wild, spell = rbf_cast("mark_of_the_wild") },
        { key = "thorns", label = rbf_label("thorns", "Thorns"), buff = BUFFS.thorns, spell = rbf_cast("thorns") },
    },
}

local PET_SUMMON_BY_CLASS = {
    [CLASS.HUNTER] = { key = "hunter_call_pet", label = "Call Pet", spell = 883, cooldown = 10 },
    -- Warlock pet summoning is handled by spec files (affliction/demonology/destruction/leveling)
    -- which choose Imp / Felhunter / Felguard / Succubus based on learned spells and destro_pet_preference.
    -- Hardcoding Imp here caused repeated "Summon Imp throttled" spam + wrong pet when API detection flaky.
}

local FOOD_BUFFS = { n = 0 }
do
    local food_buffs = (TBC.BUFFS and TBC.BUFFS.food) or EMPTY
    for i = 1, #food_buffs do
        FOOD_BUFFS.n = FOOD_BUFFS.n + 1
        FOOD_BUFFS[FOOD_BUFFS.n] = food_buffs[i]
    end
end

local HEALING_PLAYSTYLES = {
    holy = true,
    discipline = true,
    restoration = true,
    resto = true,
}

-- Pull safe / safe_field from NS (installed by core_sylvanas.lua via
-- shared/safe_helpers_sylvanas). Local fallbacks for tests whose NS
-- mock does not supply the helpers. Use pcall to handle NS=nil at load
-- (some tests dofile this shared/ before setting _G.EaxRotations).
local safe
pcall(function() safe = NS and NS.safe end)
if type(safe) ~= "function" then
    safe = function(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, a, b = pcall(fn, ...)
        return ok and a or nil, ok and b or nil
    end
end
local safe_field
pcall(function() safe_field = NS and NS.safe_field end)
if type(safe_field) ~= "function" then
    safe_field = function(obj, key)
        if obj == nil then return nil end
        local ok, value = pcall(function() return obj[key] end)
        return ok and value or nil
    end
end

local function get_setting(settings, key, default)
    if settings and settings[key] ~= nil then return settings[key] end
    if NS and NS.get_setting then return NS.get_setting(key, default) end
    return default
end

local function enabled(settings, key, default)
    return get_setting(settings, key, default) ~= false
end

local function get_player()
    if NS and type(NS.get_player) == "function" then return NS.get_player() end
    return NS and NS.GetPlayer and NS.GetPlayer() or nil
end

local function get_class_id(me)
    if NS and type(NS.player_class_id) == "number" then return NS.player_class_id end
    local get_class = safe_field(me, "get_class")
    local class_id = get_class and safe(get_class, me) or nil
    return type(class_id) == "number" and class_id or nil
end

local function get_player_level(me)
    local get_effective_level = safe_field(me, "get_effective_level")
    local level = get_effective_level and safe(get_effective_level, me) or nil
    if type(level) ~= "number" then
        local get_level = safe_field(me, "get_level")
        level = get_level and safe(get_level, me) or nil
    end
    return type(level) == "number" and level or 70
end

local function get_spell(entry)
    local key = entry and entry.key
    if not key then return nil end
    local spell = _spell_cache[key]
    if not spell and NS and NS.spell_action then
        spell = NS.spell_action(entry.spell, entry.label)
        _spell_cache[key] = spell
    end
    return spell
end

local function reset_work_ids(source)
    local old_n = _work_ids.n or 0
    _work_ids.n = 0
    if type(source) ~= "table" then
        for i = 1, old_n do _work_ids[i] = nil end
        return _work_ids
    end
    local n = source.n or #source
    for i = 1, n do
        local id = source[i]
        if type(id) == "number" then
            _work_ids.n = _work_ids.n + 1
            _work_ids[_work_ids.n] = id
        end
    end
    for i = _work_ids.n + 1, old_n do _work_ids[i] = nil end
    return _work_ids
end

local function context_or_default(context)
    if type(context) == "table" then return context end
    context = NS and NS.GetCurrentContext and NS.GetCurrentContext() or nil
    if type(context) == "table" then return context end

    local me = get_player()
    if not me then return nil end
    local is_in_combat = safe_field(me, "is_in_combat")
    return {
        me = me,
        settings = NS and NS.settings or EMPTY,
        in_combat = is_in_combat and safe(is_in_combat, me) == true or false,
        mana_pct = NS and NS.mana_pct and NS.mana_pct(me) or 100,
        active_playstyle = spec_kit.setting(nil, "active_playstyle", nil),
    }
end

local function is_healer_context(context)
    local active = tostring(context and context.active_playstyle or ""):lower()
    if HEALING_PLAYSTYLES[active] then return true end
    local settings = context and context.settings or EMPTY
    return settings.healing_enabled == true and settings.damage_enabled == false
end

local function below_healer_mana_floor(context, settings)
    if not is_healer_context(context) then return false end
    local threshold = get_setting(settings, "ooc_mana_threshold", 30)
    local mana = context and (context.mana_pct or context.player_mana_pct) or nil
    if type(mana) ~= "number" and NS and NS.mana_pct then mana = NS.mana_pct(context and context.me) end
    return type(mana) == "number" and mana < threshold
end

local function should_handle_buff(settings, entry, player_level)
    if not entry then return false end
    local explicit = get_setting(settings, "ooc_buff_" .. entry.key, nil)
    if explicit == false then return false end
    -- Respect class self-buff / OOC-buff toggles (and per-buff autos) so OOC manager doesn't bypass menu settings.
    -- These are the primary toggles defined in class schemas.
    if (entry.key == "mark_of_the_wild" or entry.key == "thorns" or entry.key == "battle_shout" or entry.key == "arcane_intellect" or entry.key == "mage_armor") and get_setting(settings, "use_self_buffs", true) == false then
        return false
    end
    if (entry.key == "water_shield" or entry.key == "lightning_shield" or entry.key == "aspect_hawk") and get_setting(settings, "use_ooc_buffs", true) == false then
        return false
    end
    if entry.key == "aspect_hawk" and get_setting(settings, "hunter_auto_aspect", true) == false then
        return false
    end
    if (entry.key == "inner_fire" or entry.key == "power_word_fortitude") and get_setting(settings, "auto_" .. (entry.key == "inner_fire" and "inner_fire" or "fortitude"), true) == false then
        return false
    end
    if (entry.key == "fel_armor" or entry.key == "demon_armor") and get_setting(settings, "auto_demon_armor", true) == false then
        return false
    end
    if entry.key == "lightning_shield" and get_setting(settings, "auto_lightning_shield", true) == false then
        return false
    end
    if entry.min_level and player_level < entry.min_level then return false end
    if entry.max_level and player_level > entry.max_level then return false end
    if entry.opt_in and explicit ~= true then
        if entry.default_below_level and player_level < entry.default_below_level then return true end
        return false
    end
    return true
end

local function try_self_buffs(context, settings, me, class_id)
    if below_healer_mana_floor(context, settings) then return false end

    -- Druid form guard: MotW/Thorns require caster form — never break Cat/Bear/
    -- Moonkin/Travel form to rebuff. Wait until player is in humanoid form.
    if class_id == CLASS.DRUID then
        local in_form = (NS.has_form and (NS.has_form("cat") or NS.has_form("bear") or NS.has_form("moonkin") or NS.has_form("travel")))
        if in_form then return false end
        -- Fallback: stance-based detection (0 = caster, anything else = shifted)
        if not NS.has_form and NS.get_player_stance then
            local stance = NS.get_player_stance()
            if type(stance) == "number" and stance ~= 0 then return false end
        end
    end

    local entries = DEFAULT_BUFFS_BY_CLASS[class_id]
    if type(entries) ~= "table" then return false end
    local threshold = get_setting(settings, "ooc_buff_threshold", 30)
    local player_level = get_player_level(me)

    for i = 1, #entries do
        local entry = entries[i]
        if should_handle_buff(settings, entry, player_level) then
            local ids = reset_work_ids(entry.buff)
            local spell = get_spell(entry)
            -- Never cast a worse rank over Gift / higher MotW / higher Thorns, etc.
            if spell and NS.buff_would_downgrade and NS.buff_would_downgrade(me, ids, spell) then
                -- Already have equal-or-better family buff; leave it alone.
            else
            local remains = NS and NS.buff_remains and NS.buff_remains(me, ids)
            if remains == nil then
                -- buff API unavailable, skip to avoid recast spam
                remains = threshold + 1
            end
            if remains <= threshold then
                if spell then
                    -- On rage-based classes, skip if not enough rage to cast
                    -- (avoids "not enough rage" game errors when OOC with 0 rage)
                    if class_id == CLASS.WARRIOR then
                        local rage = NS.power_current and NS.power_current(NS.POWER_RAGE) or 0
                        if rage < 10 then return false end
                    end
                    local should_cast = true
                    -- Long lockout after a successful cast: aura APIs often return
                    -- remains=0 on PS, which would otherwise re-queue every GCD.
                    -- Pass the resolved spell object so NS.broken_api_throttled
                    -- resolves the correct cast ID via NS.get_spell_id.
                    if NS.broken_api_throttled and NS.broken_api_throttled(spell, SELF_BUFF_LOCKOUT) then
                        should_cast = false
                        local now_t = NS.time_now and NS.time_now() or 0
                        local last_log = _throttle_log_at[entry.key] or 0
                        if NS.log and (now_t - last_log) >= 30 then
                            _throttle_log_at[entry.key] = now_t
                            NS.log("[OOC] " .. entry.label .. " throttled (recent cast / broken aura API)")
                        end
                    end
                    if should_cast and NS.try_cast(spell, me, "[OOC] " .. entry.label, { skip_range = true }) then
                        return true
                    end
                end
            end
            end
        end
    end
    return false
end

local function try_pet_summon(settings, me, class_id)
    if not enabled(settings, "ooc_summon_pet", true) then return false end
    local entry = PET_SUMMON_BY_CLASS[class_id]
    if not entry then return false end
    -- Check if pet already exists (multi-layer detection for broken API builds)
    if NS and NS.GetPet and NS.GetPet() then return false end
    if me and me.has_pet then
        local ok, has = pcall(function() return me:has_pet() end)
        if ok and has then return false end
    end
    local spell = get_spell(entry)
    if not spell then return false end
    -- Throttle retries when spell-book API is broken on private servers
    if NS.broken_api_throttled and NS.broken_api_throttled(spell, PET_SUMMON_LOCKOUT) then
        local now_t = NS.time_now and NS.time_now() or 0
        local last_log = _throttle_log_at[entry.key] or 0
        if NS.log and (now_t - last_log) >= 30 then
            _throttle_log_at[entry.key] = now_t
            NS.log("[OOC] " .. entry.label .. " throttled (recent cast / broken aura API)")
        end
        return false
    end
    return NS.try_cast(spell, me, "[OOC] " .. entry.label, { skip_range = true, expected_cooldown = entry.cooldown }) == true
end

local function try_food_flask(settings, me)
    -- Skip if consumable_manager handles this
    if settings.use_auto_consumables ~= false and (settings.use_food ~= false or settings.use_flasks ~= false) then return false end
    if get_setting(settings, "use_food_flask", false) ~= true then return false end
    if NS and NS.has_player_buff and NS.has_player_buff(FOOD_BUFFS) then return false end

    local spell_id = get_setting(settings, "ooc_food_flask_spell", nil)
    if type(spell_id) ~= "number" then return false end
    -- Throttle retries when spell-book API is broken on private servers
    if NS.broken_api_throttled and NS.broken_api_throttled(spell_id, 3.0) then
        if NS.log then NS.log("[OOC] Food/Flask throttled (broken API, spell " .. spell_id .. ")") end
        return false
    end
    local entry = { key = "food_flask_" .. tostring(spell_id), label = "Food/Flask", spell = spell_id }
    local spell = get_spell(entry)
    if not spell then return false end
    return NS.try_cast(spell, me, "[OOC] Food/Flask", { skip_range = true }) == true
end

function M.on_update(context)
    if not NS then return false end
    context = context_or_default(context)
    if not context or context.in_combat then return false end

    local settings = context.settings or NS.settings or EMPTY
    if get_setting(settings, "use_ooc_manager", true) == false then return false end

    local now = NS.time_now and NS.time_now() or 0
    if now - _last_check < 1 then return false end
    _last_check = now

    -- Skip if GCD is still active (prevents per-frame spam when retrying spells)
    local gcd = NS.gcd_remains and NS.gcd_remains() or 0
    if gcd and gcd > 0 then return false end

    local me = context.me or get_player()
    if not me then return false end
    local class_id = get_class_id(me)
    if not class_id then return false end

    if try_pet_summon(settings, me, class_id) then return true end
    if try_self_buffs(context, settings, me, class_id) then return true end
    if _buff_upgrade_ok and _buff_upgrade and _buff_upgrade.try_buff_upgrades(context, settings, me) then return true end
    if try_food_flask(settings, me) then return true end
    return false
end

-- Backwards-compatible no-op. Historically this self-registered into the
-- shared on_update dispatcher, which caused OOC work to fire TWICE per cycle
-- (once from the shared 20Hz dispatcher, once from main_sylvanas.lua's OOC
-- branch in on_rotation_update). Now main_sylvanas.lua owns the single entry
-- point so we always know exactly who is calling on_update and at what rate.
-- Kept as a no-op so any external callers (third-party plugins, custom user
-- scripts) don't crash if they still invoke NS.register_ooc_manager().
function M.register_ooc_manager()
    return true
end

if NS then
    NS.OOCManager = M
    NS.ooc_manager = M
    NS.register_ooc_manager = M.register_ooc_manager
end

return M

-- PERSISTENCE_SENTINEL_1782803371
