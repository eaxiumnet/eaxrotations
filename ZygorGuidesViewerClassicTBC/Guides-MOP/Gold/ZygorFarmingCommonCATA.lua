local ZygorGuidesViewer=ZygorGuidesViewer
if not ZygorGuidesViewer then return end
ZygorGuidesViewer.Gold.guides_loaded=true
if ZGV:DoMutex("GoldFarmC") then return end
ZygorGuidesViewer.GuideMenuTier = "CLA"
ZygorGuidesViewer:RegisterGuide("GOLD\\Farming\\Volatile Fire",{
cataready=true,
meta={goldtype="route",levelreq=85,itemtype="elemental"},
items={{52325,60}},
maps={"Twilight Highlands"},
},[[
step
label "Start_Farming_Volatile_Fire"
map Twilight Highlands/0
path	43.36,25.46	44.09,23.26	43.25,21.51	41.91,21.26	39.96,22.18
path	41.01,24.19	42.15,25.19
kill Unbound Emberfiend##48016+
goldcollect 60 Volatile Fire##52325
|goldtracker
|tip
_Ready to Sell?_
Click Here to Sell Your Items on the Auction House |confirm
]])
