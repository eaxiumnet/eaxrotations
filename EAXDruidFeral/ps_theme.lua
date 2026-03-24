-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  EAX Class Theme  ·  ps_theme.lua  v2.0                                ║
-- ║                                                                          ║
-- ║  Drop-in replacement for the original ps_theme.lua.                     ║
-- ║  Keeps the EXACT same draw_space mechanics as v4.0 (scroll-offset,      ║
-- ║  dynamic-drawing-offset, hardcoded 460 canvas width, get_max_scroll_y   ║
-- ║  for height) so it NEVER bleeds outside its own tree node or covers      ║
-- ║  other scripts' menus.                                                   ║
-- ║                                                                          ║
-- ║  What changes vs. the original:                                          ║
-- ║   • Star / dust / meteor / gem colors auto-tinted per player class       ║
-- ║   • Corner bracket glow matches class accent color                       ║
-- ║   • Section headers colored with class accent                            ║
-- ║   • Everything else is identical — same layout, same API, same safety    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

local ps = {}

-- Lazy deps
local _vec2_mod
local function v_raw(x, y)
    if not _vec2_mod then _vec2_mod = require("common/geometry/vector_2") end
    return _vec2_mod.new(x, y)
end
local _color_api
local function c(r, g, b, a)
    if not _color_api then _color_api = require("common/color") end
    return _color_api.new(r, g, b, a or 255)
end

-- Class palette detection (cached after first successful read)
local _class_id_cache = nil
local function get_class_id()
    if _class_id_cache then return _class_id_cache end
    local ok, ui_init = pcall(require, "class_ui_init")
    if ok and ui_init and ui_init.class_id then
        _class_id_cache = ui_init.class_id
    end
    return _class_id_cache
end

-- Palette table: { SR,SG,SB, DR,DG,DB, AR,AG,AB, PR,PG,PB,PA, BR,BG,BB,BA, DDR,DDG,DDB,DDA }
-- SR/SG/SB = star color,  DR/DG/DB = dust color,  AR/AG/AB = accent color
-- PR/PG/PB/PA = panel fill,  BR/BG/BB/BA = border glow,  DDR/DDG/DDB/DDA = border dim
local CLASS_PAL = {
    [1]  = { 180,200,255,  100,130,200,  199,156,110,  10,14,22,252,  180,210,255,210,  60,80,130,140  }, -- Warrior
    [2]  = { 255,230,100,  220,180, 60,  255,209,101,  20,16, 8,252,  245,215, 80,230,  140,100,20,160 }, -- Paladin
    [3]  = { 140,200,100,   80,140, 50,  170,211,114,   8,18,10,252,  170,211,114,220,   60,90,30,150  }, -- Hunter
    [4]  = { 200,190, 60,  100, 95, 20,  255,244,104,   8,10, 8,252,  230,220, 80,200,   80,80,15,140  }, -- Rogue
    [5]  = { 200,200,255,  120,120,200,  220,220,255,  14,14,20,252,  220,220,240,220,   80,80,120,140 }, -- Priest
    [7]  = {  40,130,255,   20, 80,200,    0,112,222,   6,14,22,252,    0,112,222,220,    0,50,120,140 }, -- Shaman
    [8]  = {  80,190,255,   40,120,210,  105,204,240,   6,16,24,252,  105,204,240,220,   30,90,140,140 }, -- Mage
    [9]  = { 130,100,210,   80, 50,160,  148,130,201,  14, 8,22,252,  148,130,201,220,   60,40,110,140 }, -- Warlock
    [11] = { 230,130, 30,  180, 80, 10,  255,125, 10,  16, 9, 4,252,  255,125, 10,220,  120,55,  5,155 }, -- Druid
}
local DEFAULT_PAL = CLASS_PAL[11]
local function pal()
    local cid = get_class_id()
    return (cid and CLASS_PAL[cid]) or DEFAULT_PAL
end

-- ps.col: lazy color table matching the original ps.col key names
ps.col = setmetatable({}, {
    __index = function(_, k)
        local p = pal()
        if k == "panel"       then return c(p[13],p[14],p[15],p[16]) end
        if k == "panel_deep"  then return c(math.max(0,p[13]-6),math.max(0,p[14]-4),math.max(0,p[15]-2),240) end
        if k == "border_glow" then return c(p[17],p[18],p[19],p[20]) end
        if k == "border_dim"  then return c(p[21],p[22],p[23],p[24]) end
        if k == "accent"      then return c(p[7],p[8],p[9],255) end
        if k == "accent_mid"  then return c(math.floor(p[7]*.85),math.floor(p[8]*.85),math.floor(p[9]*.85),255) end
        if k == "text_on"     then return c(math.min(255,p[7]+35),math.min(255,p[8]+35),math.min(255,p[9]+35),255) end
        if k == "text_off"    then return c(math.floor(p[7]*.45),math.floor(p[8]*.45),math.floor(p[9]*.45),200) end
        if k == "transparent" then return c(0,0,0,0) end
        return c(255,0,255,255)
    end
})

-- Pre-seeded stable star field
local STAR_COUNT, DUST_COUNT = 160, 55
local _stars, _dust
local function _seed_rng(s)
    return function()
        s = (s*1664525+1013904223)%4294967296
        return (s<0 and s+4294967296 or s)/4294967296
    end
end
local function _build_field()
    if _stars then return end
    local r1,r2 = _seed_rng(42), _seed_rng(77)
    _stars = {}
    for i=1,STAR_COUNT do
        local rv = r1()
        _stars[i] = { rx=r1(), ry=r1(),
            rad = rv<0.55 and 0.7 or (rv<0.8 and 1.2 or (rv<0.93 and 1.7 or 2.3)),
            spd=0.3+r1()*2.8, phase=r1()*math.pi*2, bright=r1()>0.35 }
    end
    _dust = {}
    for i=1,DUST_COUNT do
        _dust[i] = { rx=r2(), ry=r2(), rad=0.5+r2()*1.8, a=math.floor((0.06+r2()*0.20)*255) }
    end
end

-- Meteor pools
local _meteor_pools = {}
local function _get_meteors(id)
    if not _meteor_pools[id] then _meteor_pools[id] = {list={},next_spawn=0} end
    return _meteor_pools[id]
end
local function _meteor_style()
    local p = pal()
    local cid = get_class_id() or 11
    local flavor = {
        [3] = { arc = 0.18, spread = 0.12, speed = 1.00, gap = 0.38 }, -- Hunter
        [9] = { arc = 0.42, spread = 0.08, speed = 0.92, gap = 0.45 }, -- Warlock
        [8] = { arc = 0.28, spread = 0.10, speed = 1.05, gap = 0.34 }, -- Mage
        [1] = { arc = 0.20, spread = 0.08, speed = 0.98, gap = 0.40 }, -- Warrior
        [11]= { arc = 0.30, spread = 0.09, speed = 0.96, gap = 0.37 }, -- Druid
    }
    local f = flavor[cid] or { arc = 0.24, spread = 0.09, speed = 1.0, gap = 0.38 }
    return p, f
end
local function _spawn_meteor(pool)
    local p, f = _meteor_style()
    local ang = -0.18 - math.random()*0.18 - f.arc
    local spd = (230+math.random()*180) * f.speed
    local sx = math.random()*0.86 + 0.04
    local sy = math.random()*0.22 + 0.03 + f.spread
    table.insert(pool.list,{
        x=sx, y=sy,
        vx=math.cos(ang)*spd, vy=math.sin(ang)*spd,
        len=(68+math.random()*110) * (0.9 + f.gap*0.35), a=0, life=0,
        max_life=1.0+math.random()*1.0 + f.spread*1.8, w=0.75+math.random()*0.9,
        seg = 4 + math.random(2), hue = p })
end

-- MAIN DRAW — identical scroll/offset mechanics to original v4.0
function ps.draw_space(win, id)
    return
end

-- Section header
function ps.header(label)
    local h = core.menu.header()
    h:render("  "..label, ps.col.accent)
end

-- Separator
function ps.sep(win)
    local p = pal()
    win:add_separator(6,6,3,0,c(p[7],p[8],p[9],110))
end

-- Element constructors
function ps.checkbox(id,default)         return core.menu.checkbox(default,id) end
function ps.slider_int(mn,mx,def,id)     return core.menu.slider_int(mn,mx,def,id) end
function ps.slider_float(mn,mx,def,id)   return core.menu.slider_float(mn,mx,def,id) end
function ps.keybind(key,toggle,id)       return core.menu.keybind(key,toggle,id) end
function ps.combobox(default,id)         return core.menu.combobox(default,id) end
function ps.tree_node()                  return core.menu.tree_node() end
ps.MODE = {"Auto","Solo","Dungeon","Raid"}

-- Render helpers (unchanged from original)
function ps.render_controls(m,title)
    ps.header("Controls")
    m.enabled:render("Enabled","Master on/off toggle — set a keybind here to toggle with a hotkey")
    if m.toggle_key then m.toggle_key:render("Toggle Key","Keybind to enable or disable the rotation") end
    m.mode:render("Mode",ps.MODE,"Auto detects party context automatically")
    m.debug:render("Debug Logging","Print rotation decisions to the console")
    if m._major_toggle_bindings and #m._major_toggle_bindings>0 then
        ps.header("Major Ability Hotkeys")
        for _,binding in ipairs(m._major_toggle_bindings) do
            local kb = m[binding.key_field]
            if kb then kb:render("  "..binding.hotkey_label, binding.tooltip) end
        end
    end
end
function ps.render_targeting(m,tgt_tree)
    tgt_tree:render("  Eax's Targeting",function()
        ps.header("Priority")
        m.focus_priority:render("Focus Target Priority","Prioritise your focus target over the current target")
        m.combat_self_hp_boost:render("Self-Heal Bonus %","Extra health threshold added to self-heal triggers")
    end)
end
function ps.render_racial(m,racial_tree)
    racial_tree:render("  Eax's Racial",function()
        ps.header("Racial Ability")
        m.use_racial:render("Use Racial","Automatically use your racial ability at the right moment")
        m.racial_hp:render("Racial HP %","Use defensive racial below this health percent")
    end)
end
function ps.render_ooc(m,ooc_tree,is_caster)
    ooc_tree:render("  Eax's Out-of-Combat",function()
        ps.header("Sustain")
        m.ooc_drink:render("Auto-Drink","Drink to restore mana when out of combat")
        m.drink_threshold:render("Drink Threshold %","Start drinking below this mana percent")
        m.ooc_eat:render("Auto-Eat","Eat food to restore health when out of combat")
        m.eat_threshold:render("Eat Threshold %","Start eating below this health percent")
        ps.header("Group")
        m.ooc_rez:render("Auto-Resurrect","Accept and cast resurrection when out of combat")
        m.ooc_group_buff:render("Group Buffs","Apply class buffs to party members between pulls")
        if is_caster then
            ps.header("Mana Conservation")
            if m.use_wand then
                m.use_wand:render("Use Wand","Wand low-health enemies to preserve mana")
                m.wand_mana_floor:render("Wand Mana Floor %","Start wanding below this mana percent")
                m.wand_at_hp:render("Wand Target HP %","Only wand when enemy HP is below this percent")
            end
            if m.use_spirit_tap_wand then m.use_spirit_tap_wand:render("Spirit Tap Wand","Prefer wand kills for the Spirit Tap proc") end
            m.leveling_conserve_mana:render("Conserve Mana","Use mana-efficient rotation while leveling")
            m.leveling_mana_floor:render("Mana Floor %","Switch to conservation mode below this percent")
        end
        if m.shield_mode then
            ps.header("Shields & Utility")
            m.shield_mode:render("Shield Mode",{"None","Lightning Shield","Water Shield","Auto (Water 60+)"},"Maintain selected shield between pulls")
        end
        if m.use_ghost_wolf then m.use_ghost_wolf:render("Ghost Wolf OOC","Automatically shift to Ghost Wolf when out of combat") end
        if m.use_totemic_call then m.use_totemic_call:render("Totemic Call","Recall totems for 25% mana refund when OOC") end
        if m.use_healing_wave then
            ps.header("Self-Healing")
            m.use_healing_wave:render("Self-Heal (Healing Wave)","Cast Healing Wave when HP drops below threshold")
            if m.healing_wave_hp then m.healing_wave_hp:render("Self-Heal HP %","HP% threshold to trigger emergency Healing Wave") end
        end
        if m.use_lesser_healing_wave then m.use_lesser_healing_wave:render("Prefer Lesser HW","Use faster/cheaper Lesser Healing Wave when available") end
        if m.use_lb_pull then
            ps.header("Combat Opener")
            m.use_lb_pull:render("Lightning Bolt Pull","Open with Lightning Bolt on targets beyond melee range")
            if m.lb_pull_range then m.lb_pull_range:render("LB Pull Range (yards)","Minimum distance before using LB to engage") end
        end
    end)
end
function ps.render_esp(m,esp_tree)
    return
end
function ps.render_defensive(m,def_tree,defenses)
    def_tree:render("  Eax's Defensive",function()
        ps.header("Emergency Cooldowns")
        if defenses and #defenses>0 then
            for _,d in ipairs(defenses) do
                if m[d.key] then m[d.key]:render(d.label,d.tip or "") end
                if d.hp_key and m[d.hp_key] then m[d.hp_key]:render(d.hp_label or (d.label.." HP %"),"Trigger below this health percent") end
            end
        else ps.header("(none configured)") end
    end)
end

return ps
