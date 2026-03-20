local M = {}

M.MIN_LIVE_RUNS = 3
M.MAX_VARIANCE_PCT = 0.05
M.NEAR_FAIL_MARGIN_PCT = 0.03
M.MIN_SAMPLE_COUNT = 30
M.MAX_FAIL_SAFE_TICKS = 0
M.MAX_NOOP_UNSUPPORTED = 0
M.MAX_UNSAFE_SKIP = 0

M.MIN_PRIMARY_METRIC = {
    dps = 100,
    hps = 100,
    tps = 100,
}

M.CANONICAL_SPEC_ROLE_MAP = {
    EAXDruidBalance = { role = "dps", primary_metric = "dps" },
    EAXDruidFeral = { role = "tank", primary_metric = "tps" },
    EAXDruidRestoration = { role = "healer", primary_metric = "hps" },
    EAXHunterBeastMastery = { role = "dps", primary_metric = "dps" },
    EAXHunterMarksmanship = { role = "dps", primary_metric = "dps" },
    EAXHunterSurvival = { role = "dps", primary_metric = "dps" },
    EAXMageArcane = { role = "dps", primary_metric = "dps" },
    EAXMageFire = { role = "dps", primary_metric = "dps" },
    EAXMageFrost = { role = "dps", primary_metric = "dps" },
    EAXPaladinHoly = { role = "healer", primary_metric = "hps" },
    EAXPaladinProtection = { role = "tank", primary_metric = "tps" },
    EAXPaladinRetribution = { role = "dps", primary_metric = "dps" },
    EAXPriestDiscipline = { role = "healer", primary_metric = "hps" },
    EAXPriestHoly = { role = "healer", primary_metric = "hps" },
    EAXPriestShadow = { role = "dps", primary_metric = "dps" },
    EAXRogueAssassination = { role = "dps", primary_metric = "dps" },
    EAXRogueCombat = { role = "dps", primary_metric = "dps" },
    EAXRogueSubtlety = { role = "dps", primary_metric = "dps" },
    EAXShamanElemental = { role = "dps", primary_metric = "dps" },
    EAXShamanEnhancement = { role = "dps", primary_metric = "dps" },
    EAXShamanRestoration = { role = "healer", primary_metric = "hps" },
    EAXWarlockAffliction = { role = "dps", primary_metric = "dps" },
    EAXWarlockDemonology = { role = "dps", primary_metric = "dps" },
    EAXWarlockDestruction = { role = "dps", primary_metric = "dps" },
    EAXWarriorArms = { role = "dps", primary_metric = "dps" },
    EAXWarriorFury = { role = "dps", primary_metric = "dps" },
    EAXWarriorProtection = { role = "tank", primary_metric = "tps" },
}

return M
