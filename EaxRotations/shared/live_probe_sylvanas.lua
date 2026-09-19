-- live_probe_sylvanas.lua — the live-beta probe harness facade (NS.LiveProbe).
-- WHAT:  publishes the one module the menus and the suites consume: installs
--        NS.LiveProbe and re-exports the operations owned by its parts
--        (report/sample/arm/disarm/status/flush/reader_report/integrity_report),
--        the menu action wrappers, and menu_buttons() -- the published operation
--        list both menu implementations iterate; wires the 0.5 integrity probe
--        into the capture ring's arm/flush moments.
-- WHEN:  loaded at startup (inert until a Diagnostics action calls it: no
--        registration, no work).
-- WHY:   the engine has no console, so a menu entry is the only way a session
--        runs a probe. One stable entry point is what lets each probe live in
--        its own file (live_probe_kit/truth/sample/capture/readers/integrity/
--        menu_sylvanas.lua) without changing what a session does -- the engine-
--        truth report, the snapshot line, the CLEU capture ring, the Block 0.4
--        reader inventory and the Block 0.5 integrity capture are each readable
--        alone.
-- SAFETY: never guesses an id (watch ids come from the caller, bridge/DBC
--        derived); every surface read is pcall/nil-guarded in the parts; the
--        capture is off by default; no banned APIs (no ffi/io/os.execute/debug).
local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end
local M = {}
NS.LiveProbe = M
local kit = require("shared/live_probe_kit_sylvanas")
local truth = require("shared/live_probe_truth_sylvanas")
local sample = require("shared/live_probe_sample_sylvanas")
local capture = require("shared/live_probe_capture_sylvanas")
local readers = require("shared/live_probe_readers_sylvanas")
local integrity = require("shared/live_probe_integrity_sylvanas")
local menu = require("shared/live_probe_menu_sylvanas")

-- The 0.5 probe observes the capture ring's two moments; the ring itself
-- knows nothing about it.
capture.on_arm(integrity.note_arm)
capture.on_flush(integrity.emit_flush_comparison)

-- Public surface: exactly the operations the menus publish and the suites
-- pin. Each one is owned by the file named above.
M.report = truth.report
M.sample = sample.sample
M.reader_report = readers.reader_report
M.integrity_report = integrity.integrity_report
M.arm = capture.arm
M.disarm = capture.disarm
M.status = capture.status
M.flush = capture.flush
M.menu_buttons = menu.menu_buttons
M.action_report = menu.action_report
M.action_sample = menu.action_sample
M.action_readers = menu.action_readers
M.action_integrity = menu.action_integrity
M.action_arm = menu.action_arm
M.action_flush = menu.action_flush
M.action_disarm = menu.action_disarm

function M.get_last_report()
    return truth.last_report(), kit.lines()
end
return M
