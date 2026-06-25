-- healing_sylvanas.lua — Re-export alias for paladin healing helpers.
-- WHAT:  thin re-export of heal_helper_sylvanas.lua for backward compatibility.
-- WHEN:  required by paladin specs that expect `classes/paladin/healing_sylvanas`.
-- WHY:   some callers require this path; the real implementation lives in heal_helper_sylvanas.lua.
-- SAFETY: no logic here; delegates entirely to heal_helper_sylvanas.lua.

return require("classes/paladin/heal_helper_sylvanas")
