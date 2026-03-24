-- class_ui_init.lua  (auto-generated for EAXShamanEnhancement)
-- Wires the correct class and spec identity into the EAX Class UI system.
-- require() this file ONCE at the top of menu.lua, before any theme calls.
--
-- To apply manually:
--   local ui_init = require("class_ui_init")
--   ui_init.apply()   -- or it auto-applies on require

local _done = false
local CLASS_ID
local SPEC_ID

local function apply()
    if _done then return end
    _done = true
    local ok_t, theme    = pcall(require, "class_theme")
    local ok_i, identity = pcall(require, "class_identity")
    if not (ok_t and ok_i) then return end
    CLASS_ID = identity.CLASS_IDS.SHAMAN
    SPEC_ID = identity.SPEC_IDS.SHAMAN_ENHANCE
    theme.init(
        CLASS_ID,
        SPEC_ID
    )
end

apply()   -- auto-apply on require

return { apply = apply, display_name = "Shaman Enhancement", class_id = CLASS_ID, spec_id = SPEC_ID }
