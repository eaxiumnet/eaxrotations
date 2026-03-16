# EAX Priest Discipline

Mitigation-first Discipline Priest automation that keeps Power Word: Shield, Renew, Power Infusion, and Pain Suppression cycling through the right targets.

## Highlights

- **Mode aware:** Auto, Solo, Dungeon, and Raid modes let you force a context or let the addon detect your party size.
- **Shield queue:** Shield allies under the configured `Shield Threshold` and keep Renew afloat with the `Renew Threshold` plus `Renew Refresh Window` guards.
- **Burst tools:** Power Infusion fires when a party member dips beneath `Power Infusion Trigger`, and Pain Suppression steps in once a target drops below `Pain Suppression` percent.
- **Prayer of Mending:** Automated PoM spread ensures a second absorb on wounded allies without clipping Renew.

## Menu

Configure everything under `EAX Priest Discipline` in the Sylvannas menu:

- `Enabled` / `Debug Logging`
- `Mode` (`Auto`, `Solo`, `Dungeon`, `Raid`)
- `Shield Threshold`, `Renew Threshold`, `Renew Refresh Window`
- `Pain Suppression Threshold`
- `Power Infusion` toggle and `Power Infusion Trigger`
- `Prayer of Mending` toggle and `PoM Threshold`

## Usage

1. Open the control panel and expand the Discipline section.
2. Adjust thresholds so the addon only fires shields/heals when needed.
3. Leave `Mode` on `Auto` unless you want to force Solo, Dungeon, or Raid behavior.
4. Run the addon while logged in as a Discipline Priest (spec ID 1) to keep shields and cooldowns flowing.
