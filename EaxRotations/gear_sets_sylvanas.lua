-- TBC armor/weapon set item IDs and set-bonus spell IDs.

local _G = _G
local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

local type, pairs = type, pairs

local M = {}

local SETS_BY_ID = {
    [620] = { key = "ASSASSINATION_ARMOR", name = "Assassination Armor", items = { 27509, 28414, 27908, 27776, 28204 }, bonuses = { { pieces = 2, spell = 37165 }, { pieces = 4, spell = 37166 } } },
    [621] = { key = "NETHERBLADE", name = "Netherblade", items = { 29046, 29045, 29044, 29048, 29047 }, bonuses = { { pieces = 2, spell = 37167 }, { pieces = 4, spell = 37168 } } },
    [622] = { key = "DEATHMANTLE", name = "Deathmantle", items = { 30144, 30145, 30146, 30148, 30149 }, bonuses = { { pieces = 2, spell = 37169 }, { pieces = 4, spell = 37170 } } },
    [623] = { key = "RIGHTEOUS_ARMOR", name = "Righteous Armor", items = { 28203, 27535, 28285, 27839, 27739 }, bonuses = { { pieces = 2, spell = 37180 }, { pieces = 4, spell = 37181 } } },
    [624] = { key = "JUSTICAR_RAIMENT", name = "Justicar Raiment", items = { 29062, 29061, 29065, 29063, 29064 }, bonuses = { { pieces = 2, spell = 37182 }, { pieces = 4, spell = 37183 } } },
    [625] = { key = "JUSTICAR_ARMOR", name = "Justicar Armor", items = { 29066, 29068, 29067, 29069, 29070 }, bonuses = { { pieces = 2, spell = 37184 }, { pieces = 4, spell = 37185 } } },
    [626] = { key = "JUSTICAR_BATTLEGEAR", name = "Justicar Battlegear", items = { 29071, 29073, 29072, 29074, 29075 }, bonuses = { { pieces = 2, spell = 37186 }, { pieces = 4, spell = 37187 } } },
    [627] = { key = "CRYSTALFORGE_RAIMENT", name = "Crystalforge Raiment", items = { 30134, 30135, 30136, 30137, 30138 }, bonuses = { { pieces = 2, spell = 37188 }, { pieces = 4, spell = 37189 } } },
    [628] = { key = "CRYSTALFORGE_ARMOR", name = "Crystalforge Armor", items = { 30123, 30125, 30124, 30126, 30127 }, bonuses = { { pieces = 2, spell = 37190 }, { pieces = 4, spell = 37191 } } },
    [629] = { key = "CRYSTALFORGE_BATTLEGEAR", name = "Crystalforge Battlegear", items = { 30129, 30130, 30132, 30133, 30131 }, bonuses = { { pieces = 2, spell = 37194 }, { pieces = 4, spell = 37195 } } },
    [630] = { key = "TIDEFURY_RAIMENT", name = "Tidefury Raiment", items = { 28231, 27510, 28349, 27909, 27802 }, bonuses = { { pieces = 2, spell = 37207 }, { pieces = 4, spell = 37209 } } },
    [631] = { key = "CYCLONE_RAIMENT", name = "Cyclone Raiment", items = { 29032, 29029, 29028, 29030, 29031 }, bonuses = { { pieces = 2, spell = 37210 }, { pieces = 4, spell = 37211 } } },
    [632] = { key = "CYCLONE_REGALIA", name = "Cyclone Regalia", items = { 29033, 29035, 29034, 29036, 29037 }, bonuses = { { pieces = 2, spell = 37212 }, { pieces = 4, spell = 37213 } } },
    [633] = { key = "CYCLONE_HARNESS", name = "Cyclone Harness", items = { 29038, 29039, 29040, 29043, 29042 }, bonuses = { { pieces = 2, spell = 37223 }, { pieces = 4, spell = 37224 } } },
    [634] = { key = "CATACLYSM_RAIMENT", name = "Cataclysm Raiment", items = { 30164, 30165, 30166, 30167, 30168 }, bonuses = { { pieces = 2, spell = 37225 }, { pieces = 4, spell = 37227 } } },
    [635] = { key = "CATACLYSM_REGALIA", name = "Cataclysm Regalia", items = { 30169, 30170, 30171, 30172, 30173 }, bonuses = { { pieces = 2, spell = 37228 }, { pieces = 4, spell = 37237 } } },
    [636] = { key = "CATACLYSM_HARNESS", name = "Cataclysm Harness", items = { 30185, 30189, 30190, 30192, 30194 }, bonuses = { { pieces = 2, spell = 37239 }, { pieces = 4, spell = 37241 } } },
    [637] = { key = "MOONGLADE_RAIMENT", name = "Moonglade Raiment", items = { 28348, 27468, 27873, 28202, 27737 }, bonuses = { { pieces = 2, spell = 37286 }, { pieces = 4, spell = 37287 } } },
    [638] = { key = "MALORNE_RAIMENT", name = "Malorne Raiment", items = { 29087, 29086, 29090, 29088, 29089 }, bonuses = { { pieces = 2, spell = 37288 }, { pieces = 4, spell = 37292 } } },
    [639] = { key = "MALORNE_REGALIA", name = "Malorne Regalia", items = { 29093, 29094, 29091, 29092, 29095 }, bonuses = { { pieces = 2, spell = 37295 }, { pieces = 4, spell = 37297 } } },
    [640] = { key = "MALORNE_HARNESS", name = "Malorne Harness", items = { 29096, 29097, 29099, 29100, 29098 }, bonuses = { { pieces = 2, spell = 37306 }, { pieces = 2, spell = 37311 }, { pieces = 4, spell = 37298 }, { pieces = 4, spell = 37299 } } },
    [641] = { key = "NORDRASSIL_HARNESS", name = "Nordrassil Harness", items = { 30222, 30223, 30228, 30229, 30230 }, bonuses = { { pieces = 2, spell = 37315 }, { pieces = 4, spell = 37333 } } },
    [642] = { key = "NORDRASSIL_RAIMENT", name = "Nordrassil Raiment", items = { 30216, 30217, 30219, 30220, 30221 }, bonuses = { { pieces = 2, spell = 37313 }, { pieces = 4, spell = 37314 } } },
    [643] = { key = "NORDRASSIL_REGALIA", name = "Nordrassil Regalia", items = { 30231, 30232, 30233, 30234, 30235 }, bonuses = { { pieces = 2, spell = 37324 }, { pieces = 4, spell = 37327 } } },
    [644] = { key = "OBLIVION_RAIMENT", name = "Oblivion Raiment", items = { 27537, 28415, 28232, 27778, 27948 }, bonuses = { { pieces = 2, spell = 37375 }, { pieces = 4, spell = 37376 } } },
    [645] = { key = "VOIDHEART_RAIMENT", name = "Voidheart Raiment", items = { 28963, 28968, 28966, 28967, 28964 }, bonuses = { { pieces = 2, spell = 37377 }, { pieces = 2, spell = 39437 }, { pieces = 4, spell = 37380 } } },
    [646] = { key = "CORRUPTOR_RAIMENT", name = "Corruptor Raiment", items = { 30211, 30212, 30213, 30215, 30214 }, bonuses = { { pieces = 2, spell = 37381 }, { pieces = 4, spell = 37384 } } },
    [647] = { key = "INCANTER_S_REGALIA", name = "Incanter's Regalia", items = { 28278, 27508, 27738, 28229, 27838 }, bonuses = { { pieces = 2, spell = 37423 }, { pieces = 4, spell = 37424 } } },
    [648] = { key = "ALDOR_REGALIA", name = "Aldor Regalia", items = { 29076, 29080, 29078, 29079, 29077 }, bonuses = { { pieces = 2, spell = 37438 }, { pieces = 4, spell = 37439 } } },
    [649] = { key = "TIRISFAL_REGALIA", name = "Tirisfal Regalia", items = { 30206, 30205, 30207, 30210, 30196 }, bonuses = { { pieces = 2, spell = 37441 }, { pieces = 4, spell = 37443 } } },
    [650] = { key = "BEAST_LORD_ARMOR", name = "Beast Lord Armor", items = { 28228, 27474, 28275, 27874, 27801 }, bonuses = { { pieces = 2, spell = 37481 }, { pieces = 4, spell = 37483 } } },
    [651] = { key = "DEMON_STALKER_ARMOR", name = "Demon Stalker Armor", items = { 29085, 29081, 29083, 29082, 29084 }, bonuses = { { pieces = 2, spell = 37484 }, { pieces = 4, spell = 37485 } } },
    [652] = { key = "RIFT_STALKER_ARMOR", name = "Rift Stalker Armor", items = { 30139, 30140, 30141, 30142, 30143 }, bonuses = { { pieces = 2, spell = 37381 }, { pieces = 4, spell = 37505 } } },
    [653] = { key = "BOLD_ARMOR", name = "Bold Armor", items = { 28205, 27475, 27977, 27803, 28350 }, bonuses = { { pieces = 2, spell = 37512 }, { pieces = 4, spell = 37513 } } },
    [654] = { key = "WARBRINGER_ARMOR", name = "Warbringer Armor", items = { 29012, 29011, 29017, 29015, 29016 }, bonuses = { { pieces = 2, spell = 37514 }, { pieces = 4, spell = 37516 } } },
    [655] = { key = "WARBRINGER_BATTLEGEAR", name = "Warbringer Battlegear", items = { 29021, 29019, 29020, 29022, 29023 }, bonuses = { { pieces = 2, spell = 37518 }, { pieces = 4, spell = 37519 } } },
    [656] = { key = "DESTROYER_ARMOR", name = "Destroyer Armor", items = { 30113, 30115, 30114, 30116, 30117 }, bonuses = { { pieces = 2, spell = 37522 }, { pieces = 4, spell = 37525 } } },
    [657] = { key = "DESTROYER_BATTLEGEAR", name = "Destroyer Battlegear", items = { 30120, 30118, 30119, 30121, 30122 }, bonuses = { { pieces = 2, spell = 37528 }, { pieces = 4, spell = 37535 } } },
    [658] = { key = "MANA_ETCHED_REGALIA", name = "Mana-Etched Regalia", items = { 28193, 27465, 27907, 28191, 27796 }, bonuses = { { pieces = 2, spell = 37607 }, { pieces = 4, spell = 37619 } } },
    [659] = { key = "WASTEWALKER_ARMOR", name = "Wastewalker Armor", items = { 28264, 27531, 28224, 27837, 27797 }, bonuses = { { pieces = 2, spell = 37608 }, { pieces = 4, spell = 37618 } } },
    [660] = { key = "DESOLATION_BATTLEGEAR", name = "Desolation Battlegear", items = { 27936, 28401, 27528, 28192, 27713 }, bonuses = { { pieces = 2, spell = 37609 }, { pieces = 4, spell = 37617 } } },
    [661] = { key = "DOOMPLATE_BATTLEGEAR", name = "Doomplate Battlegear", items = { 28403, 27497, 28225, 27870, 27771 }, bonuses = { { pieces = 2, spell = 37610 }, { pieces = 4, spell = 37611 } } },
    [662] = { key = "HALLOWED_RAIMENT", name = "Hallowed Raiment", items = { 28413, 28230, 27536, 27775, 27875 }, bonuses = { { pieces = 2, spell = 37556 }, { pieces = 4, spell = 37558 } } },
    [663] = { key = "INCARNATE_RAIMENT", name = "Incarnate Raiment", items = { 29055, 29049, 29054, 29050, 29053 }, bonuses = { { pieces = 2, spell = 37564 }, { pieces = 4, spell = 37568 } } },
    [664] = { key = "INCARNATE_REGALIA", name = "Incarnate Regalia", items = { 29057, 29059, 29056, 29058, 29060 }, bonuses = { { pieces = 2, spell = 37570 }, { pieces = 4, spell = 37571 } } },
    [665] = { key = "AVATAR_RAIMENT", name = "Avatar Raiment", items = { 30153, 30152, 30151, 30154, 30150 }, bonuses = { { pieces = 2, spell = 37594 }, { pieces = 4, spell = 26171 } } },
    [666] = { key = "AVATAR_REGALIA", name = "Avatar Regalia", items = { 30160, 30161, 30162, 30159, 30163 }, bonuses = { { pieces = 2, spell = 37600 }, { pieces = 4, spell = 37603 } } },
    [667] = { key = "THE_TWIN_STARS", name = "The Twin Stars", items = { 31339, 31338 }, bonuses = { { pieces = 2, spell = 41875 } } },
    [668] = { key = "SLAYER_S_ARMOR", name = "Slayer's Armor", items = { 31028, 31026, 31027, 31029, 31030, 34575, 34448, 34558 }, bonuses = { { pieces = 2, spell = 38388 }, { pieces = 4, spell = 38389 } } },
    [669] = { key = "GRONNSTALKER_S_ARMOR", name = "Gronnstalker's Armor", items = { 31004, 31001, 31003, 31005, 31006, 34549, 34443, 34570 }, bonuses = { { pieces = 2, spell = 38390 }, { pieces = 4, spell = 38392 } } },
    [670] = { key = "MALEFIC_RAIMENT", name = "Malefic Raiment", items = { 31050, 31051, 31053, 31054, 31052, 34564, 34436, 34541 }, bonuses = { { pieces = 2, spell = 38394 }, { pieces = 4, spell = 38393 } } },
    [671] = { key = "TEMPEST_REGALIA", name = "Tempest Regalia", items = { 31056, 31055, 31058, 31059, 31057, 34574, 34447, 34557 }, bonuses = { { pieces = 2, spell = 38396 }, { pieces = 4, spell = 38397 } } },
    [672] = { key = "ONSLAUGHT_BATTLEGEAR", name = "Onslaught Battlegear", items = { 30972, 30975, 30969, 30977, 30979, 34546, 34441, 34569 }, bonuses = { { pieces = 2, spell = 38398 }, { pieces = 4, spell = 38399 } } },
    [673] = { key = "ONSLAUGHT_ARMOR", name = "Onslaught Armor", items = { 30976, 30974, 30970, 30978, 30980, 34568, 34442, 34547 }, bonuses = { { pieces = 2, spell = 38408 }, { pieces = 4, spell = 38407 } } },
    [674] = { key = "ABSOLUTION_REGALIA", name = "Absolution Regalia", items = { 31061, 31064, 31067, 31070, 31065, 34434, 34528, 34563 }, bonuses = { { pieces = 2, spell = 38413 }, { pieces = 4, spell = 38412 } } },
    [675] = { key = "VESTMENTS_OF_ABSOLUTION", name = "Vestments of Absolution", items = { 31068, 31063, 31060, 31069, 31066, 34562, 34527, 34435 }, bonuses = { { pieces = 2, spell = 38410 }, { pieces = 4, spell = 38411 } } },
    [676] = { key = "THUNDERHEART_HARNESS", name = "Thunderheart Harness", items = { 31042, 31034, 31039, 31044, 31048, 34556, 34444, 34573 }, bonuses = { { pieces = 2, spell = 38447 }, { pieces = 4, spell = 38416 } } },
    [677] = { key = "THUNDERHEART_REGALIA", name = "Thunderheart Regalia", items = { 31043, 31035, 31040, 31046, 31049, 34572, 34446, 34555 }, bonuses = { { pieces = 2, spell = 38414 }, { pieces = 4, spell = 38415 } } },
    [678] = { key = "THUNDERHEART_RAIMENT", name = "Thunderheart Raiment", items = { 31041, 31032, 31037, 31045, 31047, 34571, 34445, 34554 }, bonuses = { { pieces = 2, spell = 38417 }, { pieces = 4, spell = 38420 } } },
    [679] = { key = "LIGHTBRINGER_ARMOR", name = "Lightbringer Armor", items = { 30991, 30987, 30985, 30995, 30998, 34488, 34433, 34560 }, bonuses = { { pieces = 2, spell = 38421 }, { pieces = 4, spell = 38422 } } },
    [680] = { key = "LIGHTBRINGER_BATTLEGEAR", name = "Lightbringer Battlegear", items = { 30990, 30982, 30993, 30997, 30989, 34561, 34431, 34485 }, bonuses = { { pieces = 2, spell = 38427 }, { pieces = 4, spell = 38424 } } },
    [681] = { key = "LIGHTBRINGER_RAIMENT", name = "Lightbringer Raiment", items = { 30992, 30983, 30988, 30994, 30996, 34432, 34487, 34559 }, bonuses = { { pieces = 2, spell = 38426 }, { pieces = 4, spell = 38425 } } },
    [682] = { key = "SKYSHATTER_HARNESS", name = "Skyshatter Harness", items = { 31018, 31011, 31015, 31021, 31024, 34567, 34439, 34545 }, bonuses = { { pieces = 2, spell = 38429 }, { pieces = 4, spell = 38432 } } },
    [683] = { key = "SKYSHATTER_RAIMENT", name = "Skyshatter Raiment", items = { 31016, 31007, 31012, 31019, 31022, 34543, 34438, 34565 }, bonuses = { { pieces = 2, spell = 38434 }, { pieces = 4, spell = 38435 } } },
    [684] = { key = "SKYSHATTER_REGALIA", name = "Skyshatter Regalia", items = { 31017, 31008, 31014, 31020, 31023, 34542, 34437, 34566 }, bonuses = { { pieces = 2, spell = 38443 }, { pieces = 4, spell = 38436 } } },
    [685] = { key = "GLADIATOR_S_REFUGE", name = "Gladiator's Refuge", items = { 31375, 31376, 31377, 31378, 31379 }, bonuses = { { pieces = 2, spell = 40043 }, { pieces = 4, spell = 46834 } } },
    [686] = { key = "GLADIATOR_S_WARTIDE", name = "Gladiator's Wartide", items = { 31396, 31397, 31400, 31406, 31407 }, bonuses = { { pieces = 2, spell = 40043 }, { pieces = 4, spell = 44299 } } },
    [687] = { key = "GLADIATOR_S_INVESTITURE", name = "Gladiator's Investiture", items = { 31409, 31410, 31411, 31412, 31413 }, bonuses = { { pieces = 2, spell = 40043 }, { pieces = 4, spell = 33333 } } },
    [688] = { key = "GRAND_MARSHAL_S_REFUGE", name = "Grand Marshal's Refuge", items = { 31589, 31590, 31591, 31592, 31593 }, bonuses = { { pieces = 2, spell = 40045 }, { pieces = 4, spell = 46834 } } },
    [689] = { key = "HIGH_WARLORD_S_REFUGE", name = "High Warlord's Refuge", items = { 31584, 31585, 31586, 31587, 31588 }, bonuses = { { pieces = 2, spell = 40049 }, { pieces = 4, spell = 46834 } } },
    [690] = { key = "GLADIATOR_S_REDEMPTION", name = "Gladiator's Redemption", items = { 31613, 31614, 31616, 31618, 31619 }, bonuses = { { pieces = 2, spell = 40043 }, { pieces = 4, spell = 46851 } } },
    [691] = { key = "GRAND_MARSHAL_S_INVESTITURE", name = "Grand Marshal's Investiture", items = { 31622, 31623, 31620, 31624, 31625 }, bonuses = { { pieces = 2, spell = 40045 }, { pieces = 4, spell = 33333 } } },
    [692] = { key = "HIGH_WARLORD_S_INVESTITURE", name = "High Warlord's Investiture", items = { 31626, 31627, 31621, 31628, 31629 }, bonuses = { { pieces = 2, spell = 40049 }, { pieces = 4, spell = 33333 } } },
    [693] = { key = "GRAND_MARSHAL_S_REDEMPTION", name = "Grand Marshal's Redemption", items = { 31630, 31631, 31632, 31633, 31634 }, bonuses = { { pieces = 2, spell = 40045 }, { pieces = 4, spell = 46851 } } },
    [694] = { key = "HIGH_WARLORD_S_REDEMPTION", name = "High Warlord's Redemption", items = { 31635, 31636, 31637, 31638, 31639 }, bonuses = { { pieces = 2, spell = 40049 }, { pieces = 4, spell = 46851 } } },
    [695] = { key = "GRAND_MARSHAL_S_WARTIDE", name = "Grand Marshal's Wartide", items = { 31640, 31641, 31642, 31643, 31644 }, bonuses = { { pieces = 2, spell = 40045 }, { pieces = 4, spell = 38499 } } },
    [696] = { key = "HIGH_WARLORD_S_WARTIDE", name = "High Warlord's Wartide", items = { 31646, 31647, 31648, 31649, 31650 }, bonuses = { { pieces = 2, spell = 40049 }, { pieces = 4, spell = 38499 } } },
    [697] = { key = "CHAMPION_S_REDOUBT", name = "Champion's Redoubt", items = { 29600, 29601, 29602, 29603, 29604, 29605 }, bonuses = { { pieces = 2, spell = 41705 }, { pieces = 3, spell = 23302 }, { pieces = 6, spell = 41704 } } },
    [698] = { key = "WARLORD_S_AEGIS", name = "Warlord's Aegis", items = { 29612, 29613, 29614, 29615, 29616, 29617 }, bonuses = { { pieces = 2, spell = 41886 }, { pieces = 3, spell = 23302 }, { pieces = 6, spell = 30778 } } },
    [699] = { key = "THE_TWIN_BLADES_OF_AZZINOTH", name = "The Twin Blades of Azzinoth", items = { 32838, 32837 }, bonuses = { { pieces = 2, spell = 41434 }, { pieces = 2, spell = 41433 } } },
    [717] = { key = "FIELD_MARSHAL_S_EARTHSHAKER", name = "Field Marshal's Earthshaker", items = { 29608, 29606, 29611, 29609, 29607, 29610 }, bonuses = { { pieces = 2, spell = 41896 }, { pieces = 3, spell = 22804 }, { pieces = 6, spell = 41895 } } },
    [718] = { key = "LIEUTENANT_COMMANDER_S_EARTHSHAKER", name = "Lieutenant Commander's Earthshaker", items = { 29599, 29595, 29597, 29596, 29598, 29594 }, bonuses = { { pieces = 2, spell = 41713 }, { pieces = 4, spell = 22804 }, { pieces = 6, spell = 41712 } } },
    [719] = { key = "THE_FISTS_OF_FURY", name = "The Fists of Fury", items = { 32946, 32945 }, bonuses = { { pieces = 2, spell = 41989 } } },
    [737] = { key = "LATRO_S_FLURRY", name = "Latro's Flurry", items = { 34703, 28189 }, bonuses = { { pieces = 2, spell = 9336 } } },
    [738] = { key = "DREADWEAVE_BATTLEGEAR", name = "Dreadweave Battlegear", items = { 35328, 35329, 35330, 35331, 35332 }, bonuses = { { pieces = 2, spell = 46412 }, { pieces = 4, spell = 23047 } } },
    [739] = { key = "MOONCLOTH_BATTLEGEAR", name = "Mooncloth Battlegear", items = { 35333, 35334, 35335, 35336, 35337 }, bonuses = { { pieces = 2, spell = 46413 }, { pieces = 4, spell = 33333 } } },
    [740] = { key = "SATIN_BATTLEGEAR", name = "Satin Battlegear", items = { 35338, 35339, 35340, 35341, 35342 }, bonuses = { { pieces = 2, spell = 46414 }, { pieces = 4, spell = 33333 } } },
    [741] = { key = "EVOKER_S_SILK_BATTLEGEAR", name = "Evoker's Silk Battlegear", items = { 35343, 35344, 35345, 35346, 35347 }, bonuses = { { pieces = 2, spell = 46415 }, { pieces = 4, spell = 23025 } } },
    [742] = { key = "DRAGONHIDE_BATTLEGEAR", name = "Dragonhide Battlegear", items = { 35356, 35357, 35358, 35360, 35359 }, bonuses = { { pieces = 2, spell = 46435 }, { pieces = 4, spell = 23218 } } },
    [743] = { key = "WYRMHIDE_BATTLEGEAR", name = "Wyrmhide Battlegear", items = { 35371, 35372, 35373, 35375, 35374 }, bonuses = { { pieces = 2, spell = 46436 }, { pieces = 4, spell = 46832 } } },
    [744] = { key = "KODOHIDE_BATTLEGEAR", name = "Kodohide Battlegear", items = { 35361, 35362, 35363, 35365, 35364 }, bonuses = { { pieces = 2, spell = 46437 }, { pieces = 4, spell = 46834 } } },
    [745] = { key = "OPPORTUNIST_S_BATTLEGEAR", name = "Opportunist's Battlegear", items = { 35366, 35367, 35368, 35369, 35370 }, bonuses = { { pieces = 2, spell = 46438 }, { pieces = 4, spell = 23048 } } },
    [746] = { key = "SEER_S_MAIL_BATTLEGEAR", name = "Seer's Mail Battlegear", items = { 35386, 35387, 35388, 35389, 35390 }, bonuses = { { pieces = 2, spell = 46454 }, { pieces = 4, spell = 22804 } } },
    [747] = { key = "SEER_S_RINGMAIL_BATTLEGEAR", name = "Seer's Ringmail Battlegear", items = { 35391, 35392, 35393, 35394, 35395 }, bonuses = { { pieces = 2, spell = 46455 }, { pieces = 4, spell = 38466 } } },
    [748] = { key = "SEER_S_LINKED_BATTLEGEAR", name = "Seer's Linked Battlegear", items = { 35381, 35382, 35383, 35384, 35385 }, bonuses = { { pieces = 2, spell = 46456 }, { pieces = 4, spell = 33018 } } },
    [749] = { key = "STALKER_S_CHAIN_BATTLEGEAR", name = "Stalker's Chain Battlegear", items = { 35376, 35377, 35378, 35379, 35380 }, bonuses = { { pieces = 2, spell = 46456 }, { pieces = 4, spell = 23158 } } },
    [750] = { key = "SAVAGE_PLATE_BATTLEGEAR", name = "Savage Plate Battlegear", items = { 35407, 35408, 35409, 35410, 35411 }, bonuses = { { pieces = 2, spell = 46528 }, { pieces = 4, spell = 22738 } } },
    [751] = { key = "CRUSADER_S_ORNAMENTED_BATTLEGEAR", name = "Crusader's Ornamented Battlegear", items = { 35402, 35403, 35404, 35405, 35406 }, bonuses = { { pieces = 2, spell = 46530 }, { pieces = 4, spell = 23302 } } },
    [752] = { key = "CRUSADER_S_SCALED_BATTLEGEAR", name = "Crusader's Scaled Battlegear", items = { 35412, 35413, 35414, 35415, 35416 }, bonuses = { { pieces = 2, spell = 46534 }, { pieces = 4, spell = 23302 } } },
}

local SETS_BY_KEY = {}
for id, set in pairs(SETS_BY_ID) do
    set.id = id
    SETS_BY_KEY[set.key] = set
end

M.sets_by_id = SETS_BY_ID
M.sets_by_key = SETS_BY_KEY

function M.get(key_or_id)
    if type(key_or_id) == "number" then return SETS_BY_ID[key_or_id] end
    if type(key_or_id) == "string" then return SETS_BY_KEY[key_or_id] end
    return nil
end

function M.count_equipped(key_or_id)
    local set = M.get(key_or_id)
    if not set or not NS.count_equipped_set then return 0 end
    return NS.count_equipped_set(set.items)
end

function M.has_bonus(key_or_id, pieces)
    local set = M.get(key_or_id)
    if not set or not NS.has_set_bonus then return false end
    return NS.has_set_bonus(set.items, pieces)
end

function M.get_bonus_spell_ids(key_or_id, pieces, out)
    out = out or {}
    for k in pairs(out) do out[k] = nil end
    local set = M.get(key_or_id)
    if not set or type(set.bonuses) ~= "table" then return out, 0 end

    local count = 0
    for i = 1, #set.bonuses do
        local bonus = set.bonuses[i]
        if bonus and (not pieces or bonus.pieces == pieces) then
            count = count + 1
            out[count] = bonus.spell
        end
    end
    return out, count
end

function M.get_active_bonuses(key_or_id, out)
    out = out or {}
    for k in pairs(out) do out[k] = nil end
    local set = M.get(key_or_id)
    if not set or type(set.bonuses) ~= "table" then return out, 0 end

    local equipped = M.count_equipped(key_or_id)
    local count = 0
    for i = 1, #set.bonuses do
        local bonus = set.bonuses[i]
        if bonus and equipped >= (bonus.pieces or 0) then
            count = count + 1
            out[count] = bonus
        end
    end
    return out, count
end

-- Wowhead data integration: load set item info on demand from wowhead_data JSON files.
-- These files are loaded once per set and cached. No io.open in on_update paths.

local function _parse_json_integers(str)
    local result = {}
    local n = 0
    for num in str:gmatch("(%d+)") do
        n = n + 1
        result[n] = tonumber(num)
    end
    return result
end

local function _parse_json_string(str)
    return str:gsub('^"', ""):gsub('"$', ""):gsub('\\"', '"'):gsub("\\n", "\n")
end

local function _parse_set_pieces(json)
    local pieces = {}
    local n = 0
    local brace_depth = 0
    local in_object = false
    local current_id, current_name

    local i = 1
    local len = #json
    while i <= len do
        local c = json:sub(i, i)
        if c == "{" then
            brace_depth = brace_depth + 1
            if brace_depth == 2 then in_object = true; current_id = nil; current_name = nil end
        elseif c == "}" then
            if brace_depth == 2 and in_object and current_id then
                n = n + 1
                pieces[n] = { id = current_id, name = current_name or "" }
            end
            brace_depth = brace_depth - 1
            if brace_depth < 1 then in_object = false end
        elseif in_object and brace_depth == 2 then
            local key_end = json:find(":%s*", i)
            if key_end and key_end < i + 40 then
                local key = json:sub(i + 1, key_end - 1):gsub('^"', ""):gsub('"$', "")
                local val_start = json:find("[^%s]", key_end + 1)
                if val_start then
                    if json:sub(val_start, val_start) == '"' then
                        local val_end = json:find('"', val_start + 1)
                        if val_end then
                            if key == "name" then current_name = json:sub(val_start + 1, val_end - 1) end
                            i = val_end
                        end
                    elseif json:sub(val_start, val_start):match("[%d%-]") then
                        local val_end = json:find("[^%d%-]", val_start + 1)
                        if val_end then
                            if key == "id" then current_id = tonumber(json:sub(val_start, val_end - 1)) end
                            i = val_end - 1
                        end
                    end
                end
            end
        end
        i = i + 1
    end

    return pieces
end

-- Cache: set_id -> { items = {id...}, item_names = {id=name}, classes = {...}, phase = N }
local _wowhead_set_cache = {}

local function _load_wowhead_set(set_id)
    if _wowhead_set_cache[set_id] then return _wowhead_set_cache[set_id] end

    -- Find a representative item for this set from existing data
    local set = SETS_BY_ID[set_id]
    if not set or not set.items or #set.items == 0 then return nil end

    local rep_id = set.items[1]
    local path = "wowhead_data/items/tbc/" .. rep_id .. ".json"
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    if not content or #content < 20 then return nil end

    local data = {}

    -- Extract set_id to verify match
    local wowhead_set_id = content:match('"set_id"%s*:%s*(%d+)')
    if wowhead_set_id and tonumber(wowhead_set_id) ~= set_id then
        return nil  -- Data mismatch, skip
    end

    -- Extract set_name
    local set_name = content:match('"set_name"%s*:%s*"([^"]*)"')
    if set_name then data.name = set_name end

    -- Extract classes
    local classes_str = content:match('"classes"%s*:%s*%[([^%]]*)%]')
    if classes_str then
        local classes = {}
        local cn = 0
        for cls in classes_str:gmatch('"([^"]*)"') do
            cn = cn + 1; classes[cn] = cls
        end
        data.classes = classes
    end

    -- Extract phase
    local phase = content:match('"phase"%s*:%s*(%d+)')
    if phase then data.phase = tonumber(phase) end

    -- Extract set_pieces
    local pieces_start = content:find('"set_pieces"%s*:%s*%[')
    if pieces_start then
        local bracket_start = content:find("%[", pieces_start)
        local depth = 0
        local pos = bracket_start
        while pos <= #content do
            local ch = content:sub(pos, pos)
            if ch == "[" then depth = depth + 1
            elseif ch == "]" then
                depth = depth - 1
                if depth == 0 then
                    local pieces_json = content:sub(bracket_start, pos)
                    local pieces = _parse_set_pieces(pieces_json)
                    data.items = {}
                    data.item_names = {}
                    for i = 1, #pieces do
                        data.items[i] = pieces[i].id
                        data.item_names[pieces[i].id] = pieces[i].name
                    end
                    break
                end
            end
            pos = pos + 1
        end
    end

    _wowhead_set_cache[set_id] = data
    return data
end

--- Get all item IDs in a set from wowhead_data (on-demand, cached).
-- @param key_or_id number set_id or string set key
-- @return table list of item IDs, or nil if wowhead data unavailable
function M.get_set_items(key_or_id)
    local set = M.get(key_or_id)
    if not set then return nil end
    local data = _load_wowhead_set(set.id)
    if not data or not data.items then return nil end
    return data.items
end

--- Cross-reference current set tracking with wowhead_data.
-- Returns a report of discrepancies (missing items, extra items, mismatches).
-- @return table report: { sets_checked, sets_with_wowhead, mismatches = { {set_id, set_key, wowhead_items, local_items, missing, extra} } }
function M.validate_set_tracking()
    local report = { sets_checked = 0, sets_with_wowhead = 0, mismatches = {} }
    local mm_n = 0

    for set_id, set in pairs(SETS_BY_ID) do
        report.sets_checked = report.sets_checked + 1
        local data = _load_wowhead_set(set_id)
        if data and data.items then
            report.sets_with_wowhead = report.sets_with_wowhead + 1

            -- Build lookup tables for comparison
            local wowhead_set = {}
            for i = 1, #data.items do wowhead_set[data.items[i]] = true end
            local local_set = {}
            for i = 1, #set.items do local_set[set.items[i]] = true end

            -- Find items in wowhead but not in local (missing)
            local missing = {}
            local mn = 0
            for i = 1, #data.items do
                if not local_set[data.items[i]] then
                    mn = mn + 1; missing[mn] = data.items[i]
                end
            end

            -- Find items in local but not in wowhead (extra)
            local extra = {}
            local en = 0
            for i = 1, #set.items do
                if not wowhead_set[set.items[i]] then
                    en = en + 1; extra[en] = set.items[i]
                end
            end

            if mn > 0 or en > 0 then
                mm_n = mm_n + 1
                report.mismatches[mm_n] = {
                    set_id = set_id,
                    set_key = set.key,
                    set_name = set.name,
                    wowhead_items = data.items,
                    local_items = set.items,
                    missing = mn > 0 and missing or nil,
                    extra = en > 0 and extra or nil,
                }
            end
        end
    end

    return report
end

--- Get set bonus effects for a set. Returns the bonus spell IDs already
-- tracked in gear_sets_sylvanas.lua. Wowhead item data contains individual
-- equip effects, not set bonuses, so this returns the curated local data.
-- @param key_or_id number set_id or string set key
-- @param pieces number optional piece count filter (2, 4, etc.)
-- @return table list of { pieces = N, spell = spell_id, description = "" }
function M.get_set_bonus_effects(key_or_id, pieces)
    local set = M.get(key_or_id)
    if not set or type(set.bonuses) ~= "table" then return {} end

    local result = {}
    local n = 0
    for i = 1, #set.bonuses do
        local bonus = set.bonuses[i]
        if bonus and (not pieces or bonus.pieces == pieces) then
            n = n + 1
            result[n] = { pieces = bonus.pieces, spell = bonus.spell, description = "" }
        end
    end
    return result
end

NS.TBCGearSets = M
NS.GEAR_SETS = SETS_BY_ID
NS.get_gear_set = M.get
NS.get_tbc_set_piece_count = M.count_equipped
NS.has_tbc_set_bonus = M.has_bonus
NS.get_tbc_set_bonus_spell_ids = M.get_bonus_spell_ids
NS.get_active_tbc_set_bonuses = M.get_active_bonuses
NS.get_wowhead_set_items = M.get_set_items
NS.validate_gear_set_tracking = M.validate_set_tracking
NS.get_set_bonus_effects = M.get_set_bonus_effects

if NS.log then NS.log("TBC gear set registry loaded") end

return M
