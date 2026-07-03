local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
if UnitFactionGroup("player")~="Alliance" then return end
if ZGV:DoMutex("ReputationsAMOP") then return end
ZygorGuidesViewer.GuideMenuTier = "TRI"
ZGV.BETASTART()
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\The Anglers")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\The August Celestials")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\The Order of the Cloud Serpent")
ZygorGuidesViewer:RegisterGuide("Reputation Guides\\Mists of Pandaria Reputations\\Shado-Pan Assault",{
mopready=true,
description="This guide will walk you through becoming exalted with the Shado-Pan faction.",
achieveid={6366},
patch='50004',
},[[
step
Earn Exalted with the "Shado-Pan" Reputation |complete rep('Shado-Pan')==Exalted
|tip Refer to the dailies guide to accomplish this.
|loadguide "Daily Guides\\Mists of Pandaria Dailies\\The Shado-Pan Dailies"
]])
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\The Tillers")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\The Golden Lotus")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\The Klaxxi")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Pearlfin Jinyu")
ZGV.BETAEND()
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Tiller's Union\\Chee Chee")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Tiller's Union\\Ella")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Tiller's Union\\Farmer Fung")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Tiller's Union\\Fish Fellreed")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Tiller's Union\\Gina Mudclaw")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Tiller's Union\\Haohan Mudclaw")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Tiller's Union\\Jogu the Drunk")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Tiller's Union\\Old Hillpaw")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Tiller's Union\\Sho")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Tiller's Union\\Tina Mudclaw")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Nat Pagle")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Lorewalkers")
ZygorGuidesViewer:RegisterGuidePlaceholder("Reputation Guides\\Mists of Pandaria Reputations\\Tushui Pandaren")
