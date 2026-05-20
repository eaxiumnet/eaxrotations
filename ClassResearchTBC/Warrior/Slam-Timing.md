# Warrior Slam and Swing Timing

Sources: Icy Veins/Wowhead Warrior rotation guides, TBC community swing-timer discussion, local Warrior swing manager references.

## Slam Timing

| Rule | Meaning |
|---|---|
| Slam after white swing | Use Slam immediately after the auto attack lands |
| Slam before swing | Bad: delays or clips the white swing |
| Swing timer required | Arms Slam logic should be disabled or simplified without it |
| Haste threshold | Very fast swing speeds can make MS/WW priority stronger than trying to force Slam |

## Automation Conditions

- If `mainhand_swing_remaining <= safety_window`, wait for the swing instead of starting Slam.
- If `swing_just_landed` and rage is available, Slam can be used as filler.
- Mortal Strike and Whirlwind cooldowns still matter; do not Slam if it causes a major cooldown miss.
- During movement, skip Slam and use instant actions.
