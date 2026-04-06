-- Flux Compatibility Layer for Sylvanas
-- Bridges Flux framework patterns to Sylvanas IZI SDK
-- This is the foundation layer for all class conversions

local izi = require("common/izi_sdk")
local enums = require("common/enums")
local buff_db = require("common/buff_db")

-- ============================================================================
-- NAMESPACE SETUP (Replaces _G.FluxAIO)
-- ============================================================================
local FluxCompat = {}
_G.FluxCompat = FluxCompat  -- For debugging only, prefer local requires

-- ============================================================================
-- CORE ADAPTER (Replaces rotation_registry)
-- ============================================================================
FluxCompat.rotation_registry = {
    registered_classes = {},
    registered_strategies = {},
    registered_middleware = {},
    middleware = {},                    -- Added from core.lua: middleware registry
    strategy_maps = {},                 -- Added from core.lua: populated by register_class()
    playstyle_config = {},              -- Added from core.lua: playstyle configurations
    class_config = nil,                 -- Added from core.lua: set by register_class()
    
    -- Register a class configuration (converted to header.lua logic)
    register_class = function(self, config)
        -- Added from core.lua: full class registration
        self.class_config = config
        for _, ps in ipairs(config.playstyles or {}) do
            self.strategy_maps[ps] = self.strategy_maps[ps] or {}
        end
        table.insert(self.registered_classes, config)
        return config
    end,
    
    -- Register strategies for a playstyle (converted to spellCallbacks pattern)
    register = function(self, playstyle, strategies, config)
        -- Added from core.lua: full register with priority handling
        local map = self.strategy_maps[playstyle]
        if not map then
            print("|cFFFF0000[Flux Compat]|r ERROR: Unknown playstyle: " .. tostring(playstyle))
            return
        end
        
        if config then
            self.playstyle_config[playstyle] = config
        end
        
        local is_array = strategies[1] ~= nil and strategies.name == nil and strategies.matches == nil
        
        if is_array then
            for i, strategy in ipairs(strategies) do
                strategy.priority = 1000 - i
                strategy.name = strategy.name or (playstyle .. "_" .. i)
                map[#map + 1] = strategy
            end
        else
            strategies.priority = strategies.priority or 50
            map[#map + 1] = strategies
        end
        
        -- Sort by priority descending
        table.sort(map, function(a, b)
            return a.priority > b.priority
        end)
        
        self.registered_strategies[playstyle] = {
            strategies = map,
            config = config or {}
        }
        return strategies
    end,
    
    -- Register middleware (converted to pre-rotation logic)
    register_middleware = function(self, middleware)
        -- Added from core.lua: middleware registration with priority sorting
        if not middleware.priority then
            middleware.priority = 100
        end
        
        self.middleware[#self.middleware + 1] = middleware
        table.sort(self.middleware, function(a, b)
            return a.priority > b.priority
        end)
        
        table.insert(self.registered_middleware, middleware)
        return middleware
    end,
    
    -- Execute middleware (called before rotation)
    execute_middleware = function(self, icon, context)
        -- Sort by priority (higher first)
        table.sort(self.registered_middleware, function(a, b)
            return (a.priority or 50) > (b.priority or 50)
        end)
        
        for _, mw in ipairs(self.registered_middleware) do
            if (not context.on_gcd or mw.is_gcd_gated == false) then
                local forced = (context.force_burst and mw.is_burst) or 
                              (context.force_defensive and mw.is_defensive)
                
                local matches = forced or (mw.matches and mw.matches(context))
                
                if matches and mw.execute then
                    local result, log_msg = mw.execute(icon, context)
                    if result then
                        return result, log_msg
                    end
                end
            end
        end
        return nil
    end,
    
    -- Execute strategies for a playstyle
    execute_strategies = function(self, playstyle, icon, context)
        local data = self.registered_strategies[playstyle]
        if not data then return nil end
        
        for _, strategy in ipairs(data.strategies or {}) do
            if not context.on_gcd or strategy.is_gcd_gated == false then
                local forced = (context.force_burst and strategy.is_burst) or 
                              (context.force_defensive and strategy.is_defensive)
                
                local passes = forced or self:check_prerequisites(strategy, context)
                
                if passes and strategy.execute then
                    local result, log_msg = strategy.execute(icon, context)
                    if result then
                        return result, log_msg
                    end
                end
            end
        end
        return nil
    end,
    
    -- Check prerequisites for a strategy
    check_prerequisites = function(self, strategy, context)
        -- Added from core.lua: full prerequisite checking
        if strategy.requires_combat ~= nil and strategy.requires_combat ~= context.in_combat then return false end
        if strategy.requires_enemy ~= nil and strategy.requires_enemy ~= context.has_valid_enemy_target then return false end
        if strategy.requires_in_range ~= nil and strategy.requires_in_range ~= context.in_melee_range then return false end
        if strategy.requires_phys_immune ~= nil and strategy.requires_phys_immune ~= context.target_phys_immune then return false end
        if strategy.setting_key and not context.settings[strategy.setting_key] then return false end
        if strategy.spell then
            if FluxCompat.unavailable_spells and FluxCompat.unavailable_spells[strategy.spell] then return false end
            local target = strategy.spell_target or context.target
            if not strategy.spell:is_ready(target) then return false end
        end
        return true
    end,
    
    -- Added from core.lua: validate playstyle spells
    validate_playstyle_spells = function(self, playstyle)
        local cc = self.class_config
        if not cc or not cc.playstyle_spells then return end
        
        local entries = cc.playstyle_spells[playstyle]
        if not entries then return end
        
        local missing_spells = {}
        local optional_missing = {}
        
        FluxCompat.check_spell_availability(entries, missing_spells, optional_missing)
        
        if cc.validate_playstyle_extra then
            cc.validate_playstyle_extra(playstyle, missing_spells, optional_missing)
        end
        
        local label = (cc.playstyle_labels and cc.playstyle_labels[playstyle]) or playstyle
        print("|cFF00FF00[Flux Compat]|r Switched to " .. label .. " playstyle")
        
        if #missing_spells > 0 then
            print("|cFFFF0000[Flux Compat]|r MISSING REQUIRED SPELLS:")
            for _, spell_name in ipairs(missing_spells) do
                print("|cFFFF0000[Flux Compat]|r   - " .. spell_name)
            end
        end
        
        if #optional_missing > 0 then
            print("|cFFFF8800[Flux Compat]|r Optional spells not available (will be skipped):")
            for _, spell_name in ipairs(optional_missing) do
                print("|cFFFF8800[Flux Compat]|r   - " .. spell_name)
            end
        end
        
        if #missing_spells == 0 and #optional_missing == 0 then
            print("|cFF00FF00[Flux Compat]|r All spells available!")
        end
    end,
    
    -- Added from core.lua: get playstyle state
    get_playstyle_state = function(self, playstyle, context)
        local config = self.playstyle_config[playstyle]
        if config and config.context_builder then
            return config.context_builder(context)
        end
        return nil
    end,
}

-- ============================================================================
-- CONTEXT BUILDER (Replaces create_context in main.lua)
-- ============================================================================
function FluxCompat.build_context(custom_extend)
    local me = izi.me()
    local target = izi.target()
    
    if not me or not me:is_valid() then
        return nil
    end
    
    -- Calculate GCD state
    local gcd_remains = me:gcd_remains()
    local on_gcd = gcd_remains > 0.1
    
    -- Build base context (Flux-compatible field names)
    local ctx = {
        -- Core state
        me = me,
        target = target,
        on_gcd = on_gcd,
        gcd_remains = gcd_remains,
        icon = nil,  -- Set by caller if needed
        
        -- Player state
        in_combat = me:time_in_combat() > 0,
        hp = me:get_health_percentage(),
        mana_pct = me:mana_pct(),
        mana = me:mana_current(),
        
        -- Target state
        target_exists = target and target:is_valid() or false,
        target_dead = target and target:is_dead() or false,
        target_enemy = target and target:is_valid_enemy() or false,
        has_valid_enemy_target = target and target:is_valid() and target:is_valid_enemy() and not target:is_dead(),
        target_hp = target and target:get_health_percentage() or 0,
        target_range = target and target:distance() or 999,
        in_melee_range = target and target:distance() <= 5,
        target_phys_immune = false,  -- Set by class-specific extension
        is_boss = target and target:is_dummy() or false,  -- is_dummy as boss approximation
        ttd = target and target:time_to_die() or 999,
        
        -- Time
        combat_time = me:time_in_combat(),
    }
    
    -- Class-specific extensions
    if custom_extend then
        custom_extend(ctx, me, target)
    end
    
    return ctx
end

-- ============================================================================
-- SPELL HELPERS (Replaces A.Create and spell methods)
-- ============================================================================
FluxCompat.spell = {
    -- Create multi-rank spell (replaces A.Create with useMaxRank)
    create_ranked = function(base_id, num_ranks)
        local ids = {}
        for i = 0, num_ranks - 1 do
            table.insert(ids, base_id + i)
        end
        return izi.spell(table.unpack(ids))
    end,
    
    -- Create spell with explicit rank list
    create_multi = function(...)
        return izi.spell(...)
    end,
    
    -- Create single spell
    create = function(spell_id)
        return izi.spell(spell_id)
    end,
}

-- ============================================================================
-- CAST HELPERS (Replaces try_cast, safe_ability_cast)
-- ============================================================================
function FluxCompat.try_cast(spell, target, label)
    if not spell or not spell:is_learned() then
        return false
    end
    
    if not spell:is_usable() then
        return false
    end
    
    if target then
        if not spell:is_castable_to_unit(target) then
            return false
        end
    end
    
    return spell:cast(target, label or "")
end

function FluxCompat.try_cast_safe(spell, target, label, opts)
    opts = opts or {}
    
    if not spell or not spell:is_learned() then
        return false
    end
    
    -- Check GCD unless explicitly skipped
    if not opts.skip_gcd then
        local me = izi.me()
        if me:gcd_remains() > 0.1 then
            return false
        end
    end
    
    -- Check range unless explicitly skipped
    if not opts.skip_range and target then
        if not spell:is_in_range(target) then
            return false
        end
    end
    
    -- Check facing unless explicitly skipped
    if not opts.skip_facing and target then
        -- Facing check via spell:is_castable_to_unit
    end
    
    return spell:cast_safe(target, label or "", opts)
end

-- ============================================================================
-- BUFF/DEBUFF HELPERS (Replaces Unit:HasBuffs/HasDeBuffs)
-- ============================================================================
FluxCompat.buff = {
    -- Check if buff is present (replaces Unit:HasBuffs)
    has = function(unit, buff_id)
        return unit:buff_up(buff_id)
    end,
    
    -- Get buff remaining time
    remains = function(unit, buff_id)
        return unit:buff_remains(buff_id)
    end,
    
    -- Get buff stacks
    stacks = function(unit, buff_id)
        return unit:buff_stacks(buff_id)
    end,
}

FluxCompat.debuff = {
    -- Check if debuff is present (replaces Unit:HasDeBuffs)
    has = function(unit, debuff_id)
        return unit:debuff_up(debuff_id)
    end,
    
    -- Get debuff remaining time
    remains = function(unit, debuff_id)
        return unit:debuff_remains(debuff_id)
    end,
    
    -- Get debuff stacks
    stacks = function(unit, debuff_id)
        return unit:debuff_stacks(debuff_id)
    end,
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
function FluxCompat.time_to_die(unit)
    if not unit or not unit:is_valid() then
        return 999
    end
    return unit:time_to_die()
end

function FluxCompat.is_in_range(unit, range)
    if not unit or not unit:is_valid() then
        return false
    end
    return unit:distance() <= range
end

function FluxCompat.predict_incoming_damage(unit, seconds)
    if not unit or not unit:is_valid() then
        return 0
    end
    return unit:get_incoming_damage(core.game_time() + seconds * 1000)
end

-- ============================================================================
-- CONSTANTS (Common TBC spell IDs - extend per class)
-- ============================================================================
FluxCompat.constants = {
    -- Trinket slots
    TRINKET_SLOT_1 = 13,
    TRINKET_SLOT_2 = 14,
    
    -- Power types
    POWER_MANA = enums.power_type.MANA,
    POWER_RAGE = enums.power_type.RAGE,
    POWER_ENERGY = enums.power_type.ENERGY,
    POWER_FOCUS = enums.power_type.FOCUS,
    
    -- Common buffs from buff_db
    BUFFS = buff_db,
    
    -- PRIORITY CONSTANTS (from core.lua)
    Priority = {
        MIDDLEWARE = {
            FORM_RESHIFT = 500,
            EMERGENCY_HEAL = 400,
            PROACTIVE_HEAL = 390,
            DISPEL_CURSE = 350,
            DISPEL_POISON = 340,
            RECOVERY_ITEMS = 300,
            INNERVATE = 290,
            MANA_RECOVERY = 280,
            SELF_BUFF_MOTW = 150,
            SELF_BUFF_THORNS = 145,
            SELF_BUFF_OOC = 140,
            OFFENSIVE_COOLDOWNS = 100,
        },
    },
    
    -- IMMUNITY SPELL IDS (from LibAuraTypes.lua TBC section)
    IMMUNITY_TOTAL = { 642, 1020, 45438, 11958, 1022, 5599, 10278, 31224, 33786, 710, 18647, 498, 19263 },
    IMMUNITY_PHYS = { 1022, 5599, 10278, 642, 1020, 45438, 11958, 33786, 710, 18647, 3169, 19263 },
    IMMUNITY_MAGIC = { 31224, 8178, 642, 1020, 45438, 11958, 33786 },
    IMMUNITY_CC = { 19574, 34471, 18499, 1719, 31224, 642, 1020, 45438, 11958, 33786, 6346, 12328 },
    IMMUNITY_STUN = { 19574, 34471, 18499, 642, 1020, 45438, 11958, 33786, 6615, 24364 },
    IMMUNITY_KICK = { 31224, 642, 1020, 45438, 11958, 33786 },
    
    -- BLOODLUST/HEROISM IDS
    BLOODLUST_IDS = { 2825, 32182 },
    
    -- Added from core.lua: Unit constants
    PLAYER_UNIT = "player",
    TARGET_UNIT = "target",
    RACE_TROLL = "Troll",
    RACE_ORC = "Orc",
}

-- ============================================================================
-- FORCE COMMAND SYSTEM (from core.lua lines 61-86)
-- ============================================================================
local FORCE_DURATION = 3.0

FluxCompat.force_commands = {
    burst = { active = false, expires = 0 },
    defensive = { active = false, expires = 0 },
    gap = { active = false, expires = 0 },
}

function FluxCompat.set_force_flag(flag_name, duration)
    duration = duration or FORCE_DURATION
    FluxCompat.force_commands[flag_name] = { 
        active = true, 
        expires = core.game_time() + duration 
    }
    
    -- Show notification
    local notification = require("common/notification")
    if flag_name == "burst" then
        notification.show_notification("BURST", duration, {1.0, 0.5, 0.1})
    elseif flag_name == "defensive" then
        notification.show_notification("DEFENSIVE", duration, {0.3, 0.7, 1.0})
    elseif flag_name == "gap" then
        notification.show_notification("GAP CLOSER", duration, {0.7, 0.3, 1.0})
    end
end

function FluxCompat.is_force_active(flag_name)
    local cmd = FluxCompat.force_commands[flag_name]
    if not cmd then return false end
    if not cmd.active then return false end
    
    if core.game_time() > cmd.expires then
        cmd.active = false
        return false
    end
    return true
end

function FluxCompat.clear_force_flag(flag_name)
    if FluxCompat.force_commands[flag_name] then
        FluxCompat.force_commands[flag_name].active = false
    end
end

-- ============================================================================
-- NOTIFICATION SYSTEM (from core.lua lines 88-132)
-- ============================================================================
function FluxCompat.show_notification(text, duration, color)
    local notification = require("common/notification")
    notification.show_notification(text, duration, color)
end

-- ============================================================================
-- DEBUG LOG SYSTEM (from core.lua lines 346-621)
-- Added from core.lua: Full debug system implementation
-- ============================================================================
local DebugLogFrame
local debug_log_lines = {}
local MAX_LOG_LINES = 500

local DBG_THEME = {
    bg          = { 0.067, 0.067, 0.078, 0.75 },    -- #111114
    bg_widget   = { 0.118, 0.118, 0.141, 1 },       -- #1e1e24
    bg_hover    = { 0.133, 0.133, 0.157, 1 },       -- #222228
    border      = { 0.173, 0.173, 0.204, 1 },       -- #2c2c34
    accent      = { 0.424, 0.388, 1.0, 1 },         -- #6c63ff
    text        = { 0.863, 0.863, 0.894, 1 },       -- #dcdce4
    text_dim    = { 0.580, 0.580, 0.659, 1 },       -- #9494a8
}

local DBG_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local function create_debug_button(parent, text, width)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 22)
    btn:SetBackdrop(DBG_BACKDROP)
    btn:SetBackdropColor(DBG_THEME.bg_widget[1], DBG_THEME.bg_widget[2], DBG_THEME.bg_widget[3], 1)
    btn:SetBackdropBorderColor(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)
    
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
    
    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(DBG_THEME.bg_hover[1], DBG_THEME.bg_hover[2], DBG_THEME.bg_hover[3], 1)
        btn:SetBackdropBorderColor(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3], 1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(DBG_THEME.bg_widget[1], DBG_THEME.bg_widget[2], DBG_THEME.bg_widget[3], 1)
        btn:SetBackdropBorderColor(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)
    end)
    return btn
end

function FluxCompat.CreateDebugLogFrame()
    if DebugLogFrame then return DebugLogFrame end
    
    local UIParent = _G.UIParent
    local f = CreateFrame("Frame", "FluxCompatDebugFrame", UIParent, "BackdropTemplate")
    f:SetSize(500, 300)
    f:SetPoint("TOPLEFT", 50, -100)
    f:SetBackdrop(DBG_BACKDROP)
    f:SetBackdropColor(DBG_THEME.bg[1], DBG_THEME.bg[2], DBG_THEME.bg[3], DBG_THEME.bg[4])
    f:SetBackdropBorderColor(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], DBG_THEME.border[4])
    f:SetMovable(true)
    f:SetResizable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -8)
    title:SetText("Flux Compat Debug Log")
    title:SetTextColor(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3])
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeX:SetPoint("CENTER")
    closeX:SetText("x")
    closeX:SetTextColor(0.6, 0.6, 0.6)
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    closeBtn:SetScript("OnEnter", function() closeX:SetTextColor(1, 0.3, 0.3) end)
    closeBtn:SetScript("OnLeave", function() closeX:SetTextColor(0.6, 0.6, 0.6) end)
    
    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 1, -28)
    sep:SetPoint("TOPRIGHT", -1, -28)
    sep:SetHeight(1)
    sep:SetColorTexture(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)
    
    -- Action buttons
    local copyBtn = create_debug_button(f, "Copy", 60)
    copyBtn:SetPoint("TOPRIGHT", -70, -5)
    
    local clearBtn = create_debug_button(f, "Clear", 60)
    clearBtn:SetPoint("TOPRIGHT", -6, -5)
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, f)
    scrollFrame:SetPoint("TOPLEFT", 8, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 28)
    scrollFrame:EnableMouseWheel(true)
    f.scrollFrame = scrollFrame
    
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetWidth(scrollFrame:GetWidth() or 460)
    contentFrame:SetHeight(1)
    scrollFrame:SetScrollChild(contentFrame)
    f.contentFrame = contentFrame
    
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local mx = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(mx, cur - delta * 30)))
    end)
    
    local textDisplay = contentFrame:CreateFontString(nil, "OVERLAY")
    textDisplay:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
    textDisplay:SetPoint("TOPLEFT", 4, 0)
    textDisplay:SetPoint("TOPRIGHT", -4, 0)
    textDisplay:SetJustifyH("LEFT")
    textDisplay:SetJustifyV("TOP")
    textDisplay:SetWordWrap(true)
    textDisplay:SetSpacing(2)
    textDisplay:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
    f.textDisplay = textDisplay
    
    -- Copy popup
    local copyPopup = CreateFrame("Frame", "FluxCompatCopyPopup", UIParent, "BackdropTemplate")
    copyPopup:SetSize(450, 200)
    copyPopup:SetPoint("CENTER")
    copyPopup:SetBackdrop(DBG_BACKDROP)
    copyPopup:SetBackdropColor(DBG_THEME.bg[1], DBG_THEME.bg[2], DBG_THEME.bg[3], 0.98)
    copyPopup:SetBackdropBorderColor(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)
    copyPopup:SetFrameStrata("DIALOG")
    copyPopup:EnableMouse(true)
    copyPopup:Hide()
    f.copyPopup = copyPopup
    
    local copyTitle = copyPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    copyTitle:SetPoint("TOP", 0, -10)
    copyTitle:SetText("Press Ctrl+C to copy, then Escape to close")
    copyTitle:SetTextColor(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3])
    
    local copyCloseBtn = CreateFrame("Button", nil, copyPopup)
    copyCloseBtn:SetSize(22, 22)
    copyCloseBtn:SetPoint("TOPRIGHT", -6, -6)
    local copyCloseX = copyCloseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    copyCloseX:SetPoint("CENTER")
    copyCloseX:SetText("x")
    copyCloseX:SetTextColor(0.6, 0.6, 0.6)
    copyCloseBtn:SetScript("OnClick", function() copyPopup:Hide() end)
    copyCloseBtn:SetScript("OnEnter", function() copyCloseX:SetTextColor(1, 0.3, 0.3) end)
    copyCloseBtn:SetScript("OnLeave", function() copyCloseX:SetTextColor(0.6, 0.6, 0.6) end)
    
    local copySep = copyPopup:CreateTexture(nil, "ARTWORK")
    copySep:SetPoint("TOPLEFT", 1, -28)
    copySep:SetPoint("TOPRIGHT", -1, -28)
    copySep:SetHeight(1)
    copySep:SetColorTexture(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)
    
    local copyScrollFrame = CreateFrame("ScrollFrame", nil, copyPopup)
    copyScrollFrame:SetPoint("TOPLEFT", 8, -32)
    copyScrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)
    copyScrollFrame:EnableMouseWheel(true)
    
    copyScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local mx = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(mx, cur - delta * 30)))
    end)
    
    local copyEditBox = CreateFrame("EditBox", nil, copyScrollFrame)
    copyEditBox:SetMultiLine(true)
    copyEditBox:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
    copyEditBox:SetWidth(420)
    copyEditBox:SetAutoFocus(false)
    copyEditBox:EnableMouse(true)
    copyEditBox:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
    copyEditBox:SetScript("OnEscapePressed", function() copyPopup:Hide() end)
    copyScrollFrame:SetScrollChild(copyEditBox)
    f.copyEditBox = copyEditBox
    
    copyBtn:SetScript("OnClick", function()
        local logText = table.concat(debug_log_lines, "\n")
        copyEditBox:SetText(logText)
        copyPopup:Show()
        copyEditBox:SetFocus()
        copyEditBox:HighlightText()
    end)
    
    clearBtn:SetScript("OnClick", function()
        debug_log_lines = {}
        textDisplay:SetText("")
        contentFrame:SetHeight(1)
    end)
    
    -- Resize grip
    local resizeBtn = CreateFrame("Button", nil, f)
    resizeBtn:SetSize(12, 12)
    resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
    local resizeTex = resizeBtn:CreateTexture(nil, "OVERLAY")
    resizeTex:SetAllPoints()
    resizeTex:SetColorTexture(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 0.6)
    resizeBtn:SetScript("OnEnter", function()
        resizeTex:SetColorTexture(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3], 0.8)
    end)
    resizeBtn:SetScript("OnLeave", function()
        resizeTex:SetColorTexture(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 0.6)
    end)
    resizeBtn:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    resizeBtn:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        contentFrame:SetWidth(scrollFrame:GetWidth() - 10)
        textDisplay:SetWidth(scrollFrame:GetWidth() - 10)
    end)
    f:SetResizeBounds(300, 150, 800, 600)
    
    -- Hint text
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", 8, 8)
    hint:SetText("/fluxlog to toggle")
    hint:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
    
    f:Hide()
    DebugLogFrame = f
    FluxCompat.DebugLogFrame = f
    return f
end

function FluxCompat.AddDebugLogLine(text)
    table.insert(debug_log_lines, text)
    while #debug_log_lines > MAX_LOG_LINES do
        table.remove(debug_log_lines, 1)
    end
    
    if DebugLogFrame and DebugLogFrame:IsShown() then
        local logText = table.concat(debug_log_lines, "\n")
        DebugLogFrame.textDisplay:SetText(logText)
        local textHeight = DebugLogFrame.textDisplay:GetStringHeight() or 1
        DebugLogFrame.contentFrame:SetHeight(textHeight + 10)
        C_Timer.After(0.01, function()
            if DebugLogFrame and DebugLogFrame.scrollFrame then
                DebugLogFrame.scrollFrame:SetVerticalScroll(DebugLogFrame.scrollFrame:GetVerticalScrollRange())
            end
        end)
    end
end

function FluxCompat.RefreshDebugLogFrame()
    if DebugLogFrame and DebugLogFrame.textDisplay then
        local logText = table.concat(debug_log_lines, "\n")
        DebugLogFrame.textDisplay:SetText(logText)
        local textHeight = DebugLogFrame.textDisplay:GetStringHeight() or 1
        DebugLogFrame.contentFrame:SetHeight(textHeight + 10)
        C_Timer.After(0.05, function()
            if DebugLogFrame and DebugLogFrame.scrollFrame then
                DebugLogFrame.scrollFrame:SetVerticalScroll(DebugLogFrame.scrollFrame:GetVerticalScrollRange())
            end
        end)
    end
end

-- /fluxlog slash command
SLASH_FLUXCOMPATLOG1 = "/fluxlog"
SLASH_FLUXCOMPATLOG2 = "/flog"
SlashCmdList["FLUXCOMPATLOG"] = function()
    if not DebugLogFrame then
        FluxCompat.CreateDebugLogFrame()
    end
    if DebugLogFrame:IsShown() then
        DebugLogFrame:Hide()
    else
        FluxCompat.RefreshDebugLogFrame()
        DebugLogFrame:Show()
    end
end

local debug_print_cache = {}
local debug_string_args = {}

function FluxCompat.debug_print(...)
    local n = select('#', ...)
    for i = 1, n do
        debug_string_args[i] = tostring(select(i, ...))
    end
    for i = n + 1, #debug_string_args do
        debug_string_args[i] = nil
    end
    local key = table.concat(debug_string_args, "|")
    
    local now = core.game_time()
    local last_print = debug_print_cache[key]
    
    if not last_print or (now - last_print) >= 1.5 then
        local message = string.format("[%.1fs] %s", now, table.concat(debug_string_args, " "))
        FluxCompat.AddDebugLogLine(message)
        debug_print_cache[key] = now
    end
end

-- ============================================================================
-- SPELL VALIDATION SYSTEM (from core.lua lines 252-299)
-- Added from core.lua: Full spell validation system
-- ============================================================================
FluxCompat.unavailable_spells = {}

function FluxCompat.is_spell_known(spell)
    if not spell then return false, "nil" end
    local spell_id = spell.id or spell:get_spell_id()
    if not spell_id then return false, "no ID" end
    
    -- Sylvanas-native check: rely on framework's spell:is_learned()
    -- Do NOT use _G.GetSpellInfo or _G.IsSpellKnown (WoW APIs)
    local is_learned = spell:is_learned()
    if is_learned then
        return true, "Spell_" .. tostring(spell_id)
    end
    
    return false, "ID:" .. tostring(spell_id)
end

function FluxCompat.check_spell_availability(entries, missing_spells, optional_missing)
    for _, entry in ipairs(entries) do
        local known, name = FluxCompat.is_spell_known(entry.spell)
        if not known then
            if entry.spell then
                FluxCompat.unavailable_spells[entry.spell] = true
            end
            if entry.required then
                table.insert(missing_spells, entry.name .. (entry.note and " (" .. entry.note .. ")" or ""))
            else
                table.insert(optional_missing, entry.name .. (entry.note and " (" .. entry.note .. ")" or ""))
            end
        else
            if entry.spell then
                FluxCompat.unavailable_spells[entry.spell] = nil
            end
        end
    end
end

function FluxCompat.is_spell_available(spell)
    if not spell then return false end
    return not FluxCompat.unavailable_spells[spell]
end

-- ============================================================================
-- SETTINGS REFRESH MECHANISM (from core.lua lines 233-343)
-- Added from core.lua: Settings cache with 0.05s duration
-- ============================================================================
FluxCompat.cached_settings = {}
local last_settings_update = 0
local SETTINGS_CACHE_DURATION = 0.05
local settings_changed_list = {}

local function update_setting(key, value, changed_list, debug_mode)
    local old_value = FluxCompat.cached_settings[key]
    FluxCompat.cached_settings[key] = value
    
    if debug_mode and old_value ~= nil and old_value ~= value then
        changed_list[#changed_list + 1] = key .. ": " .. tostring(old_value) .. " -> " .. tostring(value)
    end
end

function FluxCompat.refresh_settings()
    local now = core.game_time()
    if now - last_settings_update < SETTINGS_CACHE_DURATION then return end
    
    local debug_mode = FluxCompat.cached_settings["debug_mode"] or false
    local changed_list = settings_changed_list
    for i = 1, #changed_list do changed_list[i] = nil end
    
    -- Schema-driven settings refresh (requires SETTINGS_SCHEMA to be defined)
    local SETTINGS_SCHEMA = _G.FluxCompat_SETTINGS_SCHEMA
    if SETTINGS_SCHEMA then
        for _, tab_def in ipairs(SETTINGS_SCHEMA) do
            for _, section in ipairs(tab_def.sections or {}) do
                for _, s in ipairs(section.settings or {}) do
                    local raw = FluxCompat.cached_settings[s.key]
                    local value
                    if s.type == "checkbox" then
                        if s.default == true then
                            value = raw ~= false
                        else
                            value = raw == true
                        end
                    else
                        value = raw or s.default
                    end
                    update_setting(s.key, value, changed_list, debug_mode)
                end
            end
        end
    end
    
    if debug_mode and #changed_list > 0 then
        print("|cFF00FFFF[Flux Compat]|r Settings changed at " .. string.format("%.1f", now))
        for _, change in ipairs(changed_list) do
            print("|cFF00FFFF[Flux Compat]|r   " .. change)
        end
    end
    
    last_settings_update = now
end

function FluxCompat.get_cached_setting(key)
    return FluxCompat.cached_settings[key]
end

-- ============================================================================
-- SPELL COST UTILITIES (from core.lua lines 157-184)
-- ============================================================================
function FluxCompat.get_spell_mana_cost(spell)
    -- TBC power types: 0=Mana, 1=Rage, 2=Focus, 3=Energy
    local cost, power_type = spell:get_spell_power_cost()
    return (cost and cost > 0 and power_type == 0) and cost or 0
end

function FluxCompat.get_spell_rage_cost(spell)
    local cost, power_type = spell:get_spell_power_cost()
    return (cost and cost > 0 and power_type == 1) and cost or 0
end

function FluxCompat.get_spell_energy_cost(spell)
    local cost, power_type = spell:get_spell_power_cost()
    return (cost and cost > 0 and power_type == 3) and cost or 0
end

function FluxCompat.get_spell_focus_cost(spell)
    local cost, power_type = spell:get_spell_power_cost()
    return (cost and cost > 0 and power_type == 2) and cost or 0
end

-- ============================================================================
-- IMMUNITY DETECTION (from core.lua lines 186-231)
-- ============================================================================
local function has_immunity_buff(unit, buff_ids)
    if not unit or not unit:is_valid() then return false end
    for _, buff_id in ipairs(buff_ids) do
        if unit:buff_up(buff_id) then
            return true
        end
    end
    return false
end

function FluxCompat.has_total_immunity(unit)
    return has_immunity_buff(unit, FluxCompat.constants.IMMUNITY_TOTAL)
end

function FluxCompat.has_phys_immunity(unit)
    return has_immunity_buff(unit, FluxCompat.constants.IMMUNITY_PHYS)
end

function FluxCompat.has_magic_immunity(unit)
    return has_immunity_buff(unit, FluxCompat.constants.IMMUNITY_MAGIC)
end

function FluxCompat.has_cc_immunity(unit)
    return has_immunity_buff(unit, FluxCompat.constants.IMMUNITY_CC)
end

function FluxCompat.has_stun_immunity(unit)
    return has_immunity_buff(unit, FluxCompat.constants.IMMUNITY_STUN)
end

function FluxCompat.has_kick_immunity(unit)
    return has_immunity_buff(unit, FluxCompat.constants.IMMUNITY_KICK)
end

-- ============================================================================
-- SWING TIMER UTILITIES (from core.lua lines 792-815, adapted to auto_attack_helper)
-- ============================================================================
function FluxCompat.is_swing_landing_soon(threshold)
    threshold = threshold or 0.4
    local me = izi.me()
    if not me then return false end
    
    local aa_helper = require("common/utility/auto_attack_helper")
    local next_swing = aa_helper:get_next_attack_game_time(me, 1)
    local now = core.game_time()
    local time_until = next_swing - now
    
    return time_until > 0 and time_until <= threshold
end

function FluxCompat.get_time_until_swing()
    local me = izi.me()
    if not me then return 0 end
    
    local aa_helper = require("common/utility/auto_attack_helper")
    local next_swing = aa_helper:get_next_attack_game_time(me, 1)
    local remaining = next_swing - core.game_time()
    
    return remaining > 0 and remaining or 0
end

-- ============================================================================
-- BURST CONTEXT SYSTEM (from core.lua lines 827-855)
-- ============================================================================
function FluxCompat.should_auto_burst(context)
    local s = context.settings
    if not s then return nil end
    
    -- If no burst conditions are configured, return nil (CDs fire freely)
    local any_configured = s["burst.in_combat"] or s["burst.on_pull"] or 
                          s["burst.on_execute"] or s["burst.on_bloodlust"]
    if not any_configured then return nil end
    
    -- At least one condition is configured; must be in combat with a target
    if not context.in_combat then return false end
    if not context.has_valid_enemy_target then return false end
    
    if s["burst.in_combat"] then return true end
    if s["burst.on_pull"] and context.combat_time and context.combat_time < 5 then return true end
    if s["burst.on_execute"] and context.target_hp and context.target_hp < 20 then return true end
    
    -- Check bloodlust
    if s["burst.on_bloodlust"] then
        local me = context.me
        for _, buff_id in ipairs(FluxCompat.constants.BLOODLUST_IDS) do
            if me:buff_up(buff_id) then
                return true
            end
        end
    end
    
    return false
end

-- ============================================================================
-- DEBUFF/BUFF HELPERS (from core.lua lines 769-790)
-- Added from core.lua: Extended buff/debuff utilities
-- ============================================================================
function FluxCompat.is_debuff_active(spell, target, source)
    if not target or not target:is_valid() then return false end
    return (target:debuff_remains(spell.id) or 0) > 0
end

function FluxCompat.get_debuff_state(spell, target, source)
    if not target or not target:is_valid() then return 0, 0 end
    return target:debuff_stacks(spell.id) or 0,
           target:debuff_remains(spell.id) or 0
end

function FluxCompat.is_buff_active(spell, target, source)
    if not target or not target:is_valid() then return false end
    return (target:buff_remains(spell.id) or 0) > 0
end

-- ============================================================================
-- CAST HELPERS (from core.lua lines 693-743)
-- Added from core.lua: Extended casting utilities
-- ============================================================================
-- Pre-allocated Click table for self-targeting (safe for combat use)
local self_target_click = { unit = "player" }

function FluxCompat.safe_self_cast(ability, label)
    if FluxCompat.unavailable_spells[ability] then return nil end
    if not ability:is_ready("player") then return nil end
    -- Note: Sylvanas may handle self-casts differently
    return ability:cast("player", label or "")
end

function FluxCompat.safe_heal_cast(ability, target_unit, label)
    if FluxCompat.unavailable_spells[ability] then return nil end
    if not ability:is_ready("player") then return nil end
    -- Note: Sylvanas healing engine handled separately
    return ability:cast(target_unit, label or "")
end

function FluxCompat.try_cast_fmt(spell, target, prefix, name, info_fmt, ...)
    if not FluxCompat.is_spell_available(spell) then return nil end
    if not spell:is_ready(target) then return nil end
    local result = FluxCompat.try_cast(spell, target)
    if result then
        if info_fmt then
            return result, string.format("%s %s - " .. info_fmt, prefix, name, ...)
        end
        return result, string.format("%s %s", prefix, name)
    end
    return nil
end

function FluxCompat.try_heal_cast(spell, target_unit, label)
    if not FluxCompat.is_spell_available(spell) then return nil end
    if not spell:is_ready("player") then return nil end
    return FluxCompat.safe_heal_cast(spell, target_unit, label)
end

function FluxCompat.try_heal_cast_fmt(spell, target_unit, prefix, name, info_fmt, ...)
    if not FluxCompat.is_spell_available(spell) then return nil end
    if not spell:is_ready("player") then return nil end
    local result = FluxCompat.safe_heal_cast(spell, target_unit)
    if result then
        if info_fmt then
            return result, string.format("%s %s - " .. info_fmt, prefix, name, ...)
        end
        return result, string.format("%s %s", prefix, name)
    end
    return nil
end

-- ============================================================================
-- HEAL PREDICTION (from core.lua lines 745-767)
-- Added from core.lua: Effective health deficit prediction
-- ============================================================================
function FluxCompat.predict_effective_deficit(unitID, castTime)
    castTime = castTime or 1.5
    local unit = unitID
    if type(unitID) == "string" then
        unit = unitID == "player" and izi.me() or izi.target()
    end
    if not unit or not unit:is_valid() then return 0 end
    
    local deficit = unit:health_deficit() or 0
    if deficit <= 0 then return 0 end
    
    local inc_heal = unit:get_incoming_heals(castTime) or 0
    local hot_hps = unit:get_heal_rate() or 0
    local hot_heal = hot_hps * castTime
    local absorb = unit:absorb() or 0
    local inc_dmg_dps = unit:get_incoming_damage_rate() or 0
    local inc_dmg = inc_dmg_dps * castTime
    
    local effective = deficit - inc_heal - hot_heal - absorb + inc_dmg
    return effective > 0 and effective or 0
end

-- ============================================================================
-- GENERIC UTILITIES (from core.lua lines 651-690)
-- Added from core.lua: Round and safe cast utilities
-- ============================================================================
function FluxCompat.round_half(num)
    if not num then return 0 end
    return math.floor(num * 2 + 0.5) / 2
end

function FluxCompat.safe_ability_cast(ability, target, label)
    if FluxCompat.unavailable_spells[ability] then return nil end
    if not ability:is_ready(target) then return nil end
    return ability:cast(target, label or "")
end

-- ============================================================================
-- COMBAT UTILITIES (from core.lua lines 816-825)
-- ============================================================================
function FluxCompat.get_time_to_die(unit_id)
    unit_id = unit_id or FluxCompat.constants.TARGET_UNIT
    local unit = unit_id == "player" and izi.me() or izi.target()
    if not unit or not unit:is_valid() then return 500 end
    return unit:time_to_die()
end

-- ============================================================================
-- STRATEGY FACTORY FUNCTIONS (from core.lua lines 985-1020)
-- ============================================================================
function FluxCompat.create_combat_strategy(config)
    local spell = config.spell
    local target = config.target or "target"
    local stance = config.stance
    local prefix = config.prefix or "[P?]"
    local log_name = config.log_name or config.name
    
    return {
        matches = function(context)
            if stance and context.stance ~= stance then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if config.setting_key and context.settings[config.setting_key] == false then return false end
            if config.extra_match and not config.extra_match(context) then return false end
            return spell:is_ready(target)
        end,
        execute = function(icon, context)
            if config.log_fmt and config.log_args then
                local args = config.log_args(context)
                local msg = string.format(config.log_fmt, table.unpack(args))
                return FluxCompat.try_cast(spell, target, prefix .. " " .. msg)
            end
            return FluxCompat.try_cast(spell, target, prefix .. " " .. log_name)
        end,
    }
end

function FluxCompat.named(name, strategy)
    strategy.name = name
    return strategy
end

-- ============================================================================
-- TRINKET MIDDLEWARE FACTORY (from core.lua lines 1021-1111)
-- Added from core.lua: Full trinket middleware with framework trinket support
-- ============================================================================
local DEFENSIVE_TRINKET_HP = 35

function FluxCompat.register_trinket_middleware()
    -- Get framework trinkets if available (A.Trinket1/A.Trinket2 pattern from core.lua)
    local Trinket1 = FluxCompat.A and FluxCompat.A.Trinket1
    local Trinket2 = FluxCompat.A and FluxCompat.A.Trinket2
    
    -- Fallback to equipped items
    if not Trinket1 or not Trinket2 then
        local me = izi.me()
        if me then
            local equipped = (me.get_equipped_items and me:get_equipped_items()) or {}
            Trinket1 = Trinket1 or equipped[13]  -- TRINKET_SLOT_1
            Trinket2 = Trinket2 or equipped[14]  -- TRINKET_SLOT_2
        end
    end
    
    if not Trinket1 and not Trinket2 then
        print("|cFFFF6600[Flux Trinket]|r No framework trinkets found")
        return
    end
    
    -- Offensive trinkets: fire during burst windows or /flux burst
    FluxCompat.rotation_registry:register_middleware({
        name = "Trinkets_Burst",
        priority = 80,
        is_burst = true,
        is_gcd_gated = false,
        
        matches = function(context)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if not FluxCompat.should_auto_burst(context) then return false end
            
            -- TTD gate: skip trinkets on dying mobs
            local min_ttd = context.settings["cd_min_ttd"] or 0
            if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
            
            local s = context.settings
            if s["trinkets.slot1_mode"] == "offensive" and Trinket1 and Trinket1:is_ready("player") then return true end
            if s["trinkets.slot2_mode"] == "offensive" and Trinket2 and Trinket2:is_ready("player") then return true end
            return false
        end,
        
        execute = function(icon, context)
            local s = context.settings
            if s["trinkets.slot1_mode"] == "offensive" and Trinket1 and Trinket1:is_ready("player") then
                return Trinket1:cast("player"), "[MW] Trinket 1 (Burst)"
            end
            if s["trinkets.slot2_mode"] == "offensive" and Trinket2 and Trinket2:is_ready("player") then
                return Trinket2:cast("player"), "[MW] Trinket 2 (Burst)"
            end
            return nil
        end,
    })
    
    -- Defensive trinkets: fire at low HP or /flux def
    FluxCompat.rotation_registry:register_middleware({
        name = "Trinkets_Defensive",
        priority = 290,
        is_defensive = true,
        is_gcd_gated = false,
        
        matches = function(context)
            if not context.in_combat then return false end
            if context.hp > DEFENSIVE_TRINKET_HP then return false end
            
            local s = context.settings
            if s["trinkets.slot1_mode"] == "defensive" and Trinket1 and Trinket1:is_ready("player") then return true end
            if s["trinkets.slot2_mode"] == "defensive" and Trinket2 and Trinket2:is_ready("player") then return true end
            return false
        end,
        
        execute = function(icon, context)
            local s = context.settings
            if s["trinkets.slot1_mode"] == "defensive" and Trinket1 and Trinket1:is_ready("player") then
                return Trinket1:cast("player"), "[MW] Trinket 1 (Defensive)"
            end
            if s["trinkets.slot2_mode"] == "defensive" and Trinket2 and Trinket2:is_ready("player") then
                return Trinket2:cast("player"), "[MW] Trinket 2 (Defensive)"
            end
            return nil
        end,
    })
    
    print("|cFF00FF00[Flux Trinket]|r Middleware registered")
end

-- ============================================================================
-- FRAME-RATE MANAGEMENT (from core.lua concepts)
-- Added from core.lua: Frame-rate utilities for rotation sensitive to FPS
-- ============================================================================
FluxCompat.frame_rate = {
    last_update = 0,
    update_interval = 0.1,  -- Minimum time between updates
    current_fps = 0,
    target_fps = 0,
}

function FluxCompat.update_frame_rate()
    local now = core.game_time()
    if now - FluxCompat.frame_rate.last_update < FluxCompat.frame_rate.update_interval then
        return FluxCompat.frame_rate.current_fps
    end
    
    FluxCompat.frame_rate.current_fps = GetFramerate() or 0
    FluxCompat.frame_rate.last_update = now
    return FluxCompat.frame_rate.current_fps
end

function FluxCompat.is_frame_rate_acceptable(min_fps)
    min_fps = min_fps or 20
    return FluxCompat.update_frame_rate() >= min_fps
end

-- ============================================================================
-- SETTINGS-CHANGED CALLBACK SYSTEM (from core.lua settings system)
-- Added from core.lua: Callback registration for settings changes
-- ============================================================================
FluxCompat.settings_callbacks = {}

function FluxCompat.on_settings_changed(callback)
    table.insert(FluxCompat.settings_callbacks, callback)
end

function FluxCompat.notify_settings_changed(key, old_value, new_value)
    for _, callback in ipairs(FluxCompat.settings_callbacks) do
        callback(key, old_value, new_value)
    end
end

-- ============================================================================
-- RETURN
-- ============================================================================
return FluxCompat