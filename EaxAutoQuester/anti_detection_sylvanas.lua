-- What: Retired anti-detection compatibility surface for EaxAutoQuester.
-- When: Loaded only by legacy or module-hygiene callers; the quest loop has no live caller.
-- Why: The former members were dead or relied on an undocumented `core.input.turn` member.
-- Safety: No game actions, randomization, timing state, or per-tick work.
-- Decision: Keep the require path harmless; do not reintroduce evasion behavior here.

local M = {}

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.anti_detection = M

return M
