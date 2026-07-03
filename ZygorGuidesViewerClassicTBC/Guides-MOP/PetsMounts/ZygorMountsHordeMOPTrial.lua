local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Horde" then return end
if ZGV:DoMutex("PetsMountsHMOP") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Crimson Primal Direhorn")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Black Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Blue Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Brown Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Great Black Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Great Blue Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Great Brown Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Great Green Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Great Purple Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Great Red Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Green Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Purple Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Ground Mounts\\Reputation Mounts\\Red Dragon Turtle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Flying Mounts\\Achievement Mounts\\Armored Red Dragonhawk")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Flying Mounts\\Achievement Mounts\\Grand Wyvern")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Flying Mounts\\Reputation Mounts\\Grand Armored Wyvern")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Flying Mounts\\Achievement Mounts\\Pandaren Kite")
ZygorGuidesViewer:RegisterGuidePlaceholder("Pets & Mounts Guides\\Mounts\\Flying Mounts\\Dropped Mounts\\Heavenly Onyx Cloud Serpent")
