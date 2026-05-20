# Verify List
| Spec | Angle | Claim | Source that would resolve it |
|---|---|---|---|
| Druid Balance | A4 | SP breakpoints at 800/1000/1200 need sim/log confirmation before they become hard thresholds. | wowsims/tbc + combat logs |
| Druid Feral DPS | A4 | AP/energy-floor breakpoints around 1500/2000/2500 remain heuristics; DB2 cannot prove them, so they need sim/log confirmation before hard-coding. | wowsims/tbc + combat logs |
| Druid Bear Tank | A1 | Exact taunt recovery behavior during an in-flight form swap still needs runtime validation in Sylvanas. | live Bear-form taunt test |
| Druid Bear Tank | A2 | The encounter table is assembled from raid / dungeon matrices; boss-by-boss runtime priority still needs raid log confirmation. | encounter logs |
| Cross-Spec | A3 | VT mana return chain effect on Warlock Life Tap frequency needs sim confirmation. | wowsims/tbc |
| Cross-Spec | A3 | Judgement assignment table for all group compositions needs raid log validation. | raid logs |
| Cross-Spec | A3 | Totem range impact on specific melee specs needs encounter-specific testing. | encounter logs |
| Cross-Spec | A4 | All SP/AP breakpoints need sim confirmation against DB2 exports. | wowsims/tbc + wago DB2 |
