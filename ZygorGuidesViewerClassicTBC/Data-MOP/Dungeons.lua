local Dungeons = ZGV.Dungeons

Dungeons.ExpansionsLimits = {
	[0] = 60, -- vanilla
	[1] = 70, -- tbc
	[2] = 80, -- wotlk
	[3] = 85, -- cata
	[4] = 90, -- mop
}

Dungeons.Phases = {
	["wotlk1"] = true,
	["wotlk2"] = true,
	["wotlk3"] = true,
	["wotlk4"] = true,
	["wotlk5"] = true,
}



-- Timewalks and legion mythics do not have any lfg entry, so we need to hardcode basic data for them
Dungeons.hardcoded_dungeons = {
	["e_330_5"] = {expansionLevel=4, minLevel=90, difficulty=5, name="Heart of Fear (Heroic 10)"},
	["e_330_6"] = {expansionLevel=4, minLevel=90, difficulty=6, name="Heart of Fear (Heroic 25)"},
	["e_317_5"] = {expansionLevel=4, minLevel=90, difficulty=5, name="Mogu'shan Vaults (Heroic 10)"},
	["e_317_6"] = {expansionLevel=4, minLevel=90, difficulty=6, name="Mogu'shan Vaults (Heroic 25)"},
	["e_369_5"] = {expansionLevel=4, minLevel=90, difficulty=5, name="Siege of Orgrimmar (Heroic 10)"},
	["e_369_6"] = {expansionLevel=4, minLevel=90, difficulty=6, name="Siege of Orgrimmar (Heroic 25)"},
	["e_320_5"] = {expansionLevel=4, minLevel=90, difficulty=5, name="Terrace of Endless Spring (Heroic 10)"},
	["e_320_6"] = {expansionLevel=4, minLevel=90, difficulty=6, name="Terrace of Endless Spring (Heroic 25)"},
	["e_362_5"] = {expansionLevel=4, minLevel=90, difficulty=5, name="Throne of Thunder (Heroic 10)"},
	["e_362_6"] = {expansionLevel=4, minLevel=90, difficulty=6, name="Throne of Thunder (Heroic 25)"},

}

Dungeons.max_levels = {
}

Dungeons.add_flags = {
}
