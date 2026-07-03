local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Horde" then return end
if ZGV:DoMutex("DailiesHCLASSIC") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\The Burning Crusade\\Shattered Sun Offensive\\Shattered Sun Dailies (Phase 1, Capturing Sanctum)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\The Burning Crusade\\Shattered Sun Offensive\\Shattered Sun Dailies (Phase 2, Capturing Armory, Activating Portal)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\The Burning Crusade\\Shattered Sun Offensive\\Shattered Sun Dailies (Phase 2, Capturing Armory, Portal Activated)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\The Burning Crusade\\Shattered Sun Offensive\\Shattered Sun Dailies (Phase 3, Recovering Harbor, Rebuilding Forge)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\The Burning Crusade\\Shattered Sun Offensive\\Shattered Sun Dailies (Phase 3, Recovering Harbor, Forge Rebuilt)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\The Burning Crusade\\Shattered Sun Offensive\\Shattered Sun Dailies (Phase 4, No Alchemy Lab or Monument)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\The Burning Crusade\\Shattered Sun Offensive\\Shattered Sun Dailies (Phase 4, Alchemy Lab Built)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\The Burning Crusade\\Shattered Sun Offensive\\Shattered Sun Dailies (Phase 4, Monument Built)")
ZygorGuidesViewer:RegisterGuidePlaceholder("Dailies Guides\\The Burning Crusade\\Shattered Sun Offensive\\Shattered Sun Dailies (Phase 4, Fully Built)")
