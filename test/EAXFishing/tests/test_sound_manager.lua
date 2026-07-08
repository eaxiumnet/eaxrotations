-- test_sound_manager.lua — Unit tests for the sound manager module.

local SoundMgr = require("core/sound_manager")

local assertions = 0
local failures = 0

local function CHECK(cond, msg)
    assertions = assertions + 1
    if not cond then
        failures = failures + 1
        print("  FAIL: " .. msg)
    end
end

-- TS1: module exposes expected API
CHECK(type(SoundMgr) == "table", "SoundMgr is a table")
CHECK(type(SoundMgr.play_for_event) == "function", "play_for_event is a function")

-- TS2: sound IDs are defined
CHECK(SoundMgr.SOUND_RARE_CATCH == 6294, "SOUND_RARE_CATCH is 6294")
CHECK(SoundMgr.SOUND_BAGS_FULL == 6193, "SOUND_BAGS_FULL is 6193")
CHECK(SoundMgr.SOUND_LURE_EXPIRING == 11742, "SOUND_LURE_EXPIRING is 11742")
CHECK(SoundMgr.SOUND_WHISPER == 1031, "SOUND_WHISPER is 1031")
CHECK(SoundMgr.SOUND_DISCONNECT == 8192, "SOUND_DISCONNECT is 8192")

-- TS3: play_for_event does not crash with nil config
SoundMgr.play_for_event({ deps = { config = { menu = nil } } }, "rare")
CHECK(true, "play_for_event does not crash with nil menu")

-- TS4: play_for_event does not crash with unknown event
SoundMgr.play_for_event({ deps = { config = { menu = {} } } }, "nonexistent_event")
CHECK(true, "play_for_event does not crash with unknown event")

-- TS5: play_for_event does not crash with nil event name
SoundMgr.play_for_event({ deps = { config = { menu = {} } } }, nil)
CHECK(true, "play_for_event does not crash with nil event name")

print(string.format("PASS test_sound_manager (%d assertions, %d failures)", assertions, failures))
return { assertions = assertions, failures = failures }
