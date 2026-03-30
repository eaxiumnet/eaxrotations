-- +------------------------------------------------------------------+
-- |  Eax's Priest Shadow
-- |  Space Theme v4.0  -  Stars drawn inside the panel background
-- +------------------------------------------------------------------+
local mana_conservator = require("libraries/mana_conservator")

local ps   = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- -- Tree nodes ----------------------------------------------------------------
local root_tree    = ps.tree_node()
local main_tree    = ps.tree_node()
local def_tree     = ps.tree_node()
local tgt_tree     = ps.tree_node()
local racial_tree  = ps.tree_node()
local ooc_tree     = ps.tree_node()
-- local esp_tree     = ps.tree_node()

-- -- Shared plugin controls + shared fields ------------------------------------
-- Controls
menu.enabled                             = core.menu.checkbox(true, "eaxpriestshadow_enabled")
menu.toggle_key                          = core.menu.keybind(7, false, "eaxpriestshadow_toggle_key")
menu.mode                                = core.menu.combobox(1, "eaxpriestshadow_mode")
menu.debug                               = core.menu.checkbox(false, "eaxpriestshadow_debug")
-- Targeting
menu.focus_priority                      = core.menu.checkbox(false, "eaxpriestshadow_focus_priority")
menu.combat_self_hp_boost                = core.menu.slider_int(0, 30, 10, "eaxpriestshadow_combat_self_hp_boost")
-- Racial
menu.use_racial                          = core.menu.checkbox(true, "eaxpriestshadow_use_racial")
menu.racial_hp                           = core.menu.slider_int(10, 80, 40, "eaxpriestshadow_racial_hp")
-- OOC
menu.ooc_drink                           = core.menu.checkbox(true,  "eax_ooc_drink")
menu.ooc_eat                             = core.menu.checkbox(true,  "eax_ooc_eat")
menu.ooc_rez                             = core.menu.checkbox(true,  "eax_ooc_rez")
menu.ooc_group_buff                      = core.menu.checkbox(true,  "eax_ooc_group_buff")
menu.drink_threshold                     = core.menu.slider_int(50, 100, 80, "eax_drink_threshold")
menu.eat_threshold                       = core.menu.slider_int(50, 100, 80, "eax_eat_threshold")

-- menu.auto_repair                        = core.menu.checkbox(true, "eaxpriestshadow_auto_repair")
-- menu.auto_sell_greys                    = core.menu.checkbox(true, "eaxpriestshadow_auto_sell_greys")
-- menu.auto_mount                         = core.menu.checkbox(true, "eaxpriestshadow_auto_mount")
-- menu.auto_dismount                      = core.menu.checkbox(true, "eaxpriestshadow_auto_dismount")
menu.auto_ooc_food_drink                = core.menu.checkbox(true, "eaxpriestshadow_auto_ooc_food_drink")
menu.auto_flask                         = core.menu.checkbox(false, "eaxpriestshadow_auto_flask")
-- Leveling
menu.leveling_conserve_mana              = core.menu.checkbox(true, "eaxpriestshadow_lev_conserve")
menu.leveling_mana_floor                 = core.menu.slider_int(5, 50, 20, "eaxpriestshadow_lev_mana_floor")
menu.use_wand                            = core.menu.checkbox(true,  "eaxpriestshadow_use_wand")
menu.wand_mana_floor                     = core.menu.slider_int(5, 80, 25, "eaxpriestshadow_wand_mana_floor")
menu.wand_at_hp                          = core.menu.slider_int(5, 60, 20, "eaxpriestshadow_wand_at_hp")
menu.use_spirit_tap_wand                 = core.menu.checkbox(true,  "eaxpriestshadow_spirit_tap_wand")
-- ESP
-- menu.esp_show_hud                        = core.menu.checkbox(true,  "eax_esp_show_hud")
-- menu.esp_show_target                     = core.menu.checkbox(true,  "eax_esp_show_target")
-- menu.esp_hud_x                           = core.menu.slider_int(0, 3840, 20,  "eax_esp_hud_x")
-- menu.esp_hud_y                           = core.menu.slider_int(0, 2160, 200, "eax_esp_hud_y")
-- -- Class-specific elements ---------------------------------------------------
menu.dot_refresh_window                   = core.menu.slider_int(1, 5, 3, "eax_priest_shadow_dot_window")
menu.use_shadow_weaving                   = core.menu.checkbox(true, "eax_priest_shadow_use_shadow_weaving")
menu.shadow_weaving_refresh_window        = core.menu.slider_int(1, 5, 3, "eax_priest_shadow_shadow_weaving_window")
menu.mind_blast_burst                     = core.menu.checkbox(true, "eax_priest_shadow_mb_burst")
menu.mind_blast_burst_window              = core.menu.slider_float(0.5, 3, 1.4, "eax_priest_shadow_mb_burst_window")
menu.shadowfiend_enabled                  = core.menu.checkbox(true, "eax_priest_shadow_shadowfiend")
menu.shadowfiend_cooldown_seconds         = core.menu.slider_int(12, 30, 18, "eax_priest_shadow_shadowfiend_cd")
menu.keep_shadowform                      = core.menu.checkbox(true, "eax_priest_shadow_shadowform")
menu.use_dispel_magic                     = core.menu.checkbox(false, "eax_priest_shadow_dispel_magic")
menu.use_flash_heal                       = core.menu.checkbox(true, "eax_priest_shadow_use_flash_heal")
menu.flash_heal_hp_pct                    = core.menu.slider_int(0, 100, 30, "eax_priest_shadow_flash_heal_hp_pct")

mana_conservator.register_menu_items(menu, "eax_priest_shadow")

-- ----------------------------------------------------------------------------
-- RENDER  - called every frame by core.register_on_render_menu_callback
-- The window object is injected via menu.set_window(win) in main.lua
-- ----------------------------------------------------------------------------

settings.setup_major_toggle_keybinds(menu, {
    { toggle = "mind_blast_burst", label = "Mind Blast Burst" },
    { toggle = "shadowfiend_enabled", label = "Shadowfiend" },
    { toggle = "keep_shadowform", label = "Keep Shadowform" },
    { toggle = "use_flash_heal", label = "Flash Heal" },
    { toggle = "use_psychic_scream", label = "Psychic Scream" },
}, {
    namespace = "eaxpriestshadow",
    log_prefix = "[Eax Priest Shadow] ",
})

local _win  -- set once from main.lua via menu.set_window(win)

function menu.set_window(win)
    _win = win
end

function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "EAXPriestShadow")
    end
    
    root_tree:render("Eax's Priest Shadow", function()

        ps.render_controls(menu, "Eax's Priest Shadow")

        -- -- Class-specific settings -------------------------------------------
        main_tree:render("Eax's Rotation Settings", function()
            ps.header("Spells & Abilities")
            menu.dot_refresh_window:render("DoT Refresh Window", "Refresh Vampiric Touch / Shadow Word: Pain when only this many seconds remain")
            menu.use_shadow_weaving:render("Shadow Weaving", "Maintain the Shadow Weaving debuff on the target")
            menu.shadow_weaving_refresh_window:render("Shadow Weaving Refresh", "Refresh Shadow Weaving when this many seconds or less remain")
            menu.mind_blast_burst:render("Burst Mind Blast", "Allow Mind Blast even when the DoTs are nearing expiry")
            menu.mind_blast_burst_window:render("Burst Window", "Force Mind Blast if one DoT has this many seconds or less remaining")
            menu.shadowfiend_enabled:render("Shadowfiend", "Summon Shadowfiend on cooldown for mana return")
            menu.shadowfiend_cooldown_seconds:render("Shadowfiend Cooldown", "Seconds between forced Shadowfiend summons")
            menu.keep_shadowform:render("Keep Shadowform", "Maintain Shadowform when available")
            menu.use_dispel_magic:render("Dispel Magic", "Conservative hostile dispel for forced-dispel encounters")
            menu.use_flash_heal:render("Flash Heal", "")
            menu.flash_heal_hp_pct:render("Flash Heal Hp Percent", "")
        end)

        -- -- Defensive cooldowns -----------------------------------------------
        ps.render_defensive(menu, def_tree, {
        { key = "use_psychic_scream_def", label = "Psychic Scream", tip = "AoE fear when overwhelmed", hp_key = "use_psychic_scream_def_hp_pct", hp_label = "Psychic Scream HP %" },
        })

        -- -- Targeting --------------------------------------------------------
        ps.render_targeting(menu, tgt_tree)

        -- -- Racial ------------------------------------------------------------
        ps.render_racial(menu, racial_tree)

        -- -- Out-of-combat -----------------------------------------------------
--         menu.auto_repair:render("Auto Repair", "Automatically repair gear at vendors")
--         menu.auto_sell_greys:render("Auto Sell Greys", "Automatically sell poor-quality items at vendors")
--         menu.auto_mount:render("Auto Mount", "Automatically mount when traveling out of combat")
--         menu.auto_dismount:render("Auto Dismount", "Automatically dismount when entering combat")
        menu.auto_ooc_food_drink:render("Auto OOC Food/Drink", "Use food and drink out of combat when needed")
        menu.auto_flask:render("Auto Flask", "Maintain flask buff automatically when enabled")
        ps.render_ooc(menu, ooc_tree, true)

        -- -- Display & HUD -----------------------------------------------------
    -- ps.render_esp(menu, esp_tree) -- DISABLED
    end)
end

menu.use_psychic_scream = core.menu.checkbox(true, "eaxpriestshadow_psychic_scream")
menu.use_fade          = core.menu.checkbox(true, "eaxpriestshadow_fade")
menu.use_psychic_scream_def = core.menu.checkbox(true, "eaxpshadow_ps_def")
menu.use_psychic_scream_def_hp_pct = core.menu.slider_int(0, 100, 40, "eaxpshadow_ps_hp")
return menu
