# Coral advantage: traits, seats and AI

> Historical experiment: results, suite counts and reproduction commands describe the milestone tested. Later systems can change outcomes; rerunning today does not reconstruct that version. Use [Gameplay](GAMEPLAY.md), [Performance](PERFORMANCE.md) and the [Roadmap](ROADMAP.md) for current guidance. See the [documentation index](docs/README.md) for context.

The same fifteen full matches are paired against the completed endgame-policy baseline, with 2,000 starting ants per colony and a 30-minute horizon. Additional fixed-seat/trait swaps, surface-only controls and unseen-seed tests distinguish color from location and decisions. Outcomes are not treated as proof of universally equal win rates.

## Findings and changes

Coral previously combined the right-hand starting vertex, Raider traits and a colony AI, while the default unattended Amber used simpler automatic raids. Those factors were confounded in the default sample. The neutral mirrored pairs changed the winner's color but retained the same winning physical seat for each of the three seeds.

Across nine neutral full-match seat controls (identical AI, Balanced traits, colors/RNG streams rotated), the old winners by seat were **{'Right': 7, 'Left': 2}**. The right seat is an observed location advantage, not a Coral-only stat. Full seat controls remap private terrain/queen chambers to the physical vertex and check open-tunnel state throughout.

Nine matched original-trait/direct-swap games yielded old winning profiles **{'Raiders': 6, 'Stewards': 2, 'Balanced': 1}**. Moving the Raider profile sometimes moved the winner, but it was not the sole cause. After the changes, the corresponding winning profiles are **{'Raiders': 3, 'Stewards': 3, 'Balanced': 3}**. These are partial, paired swaps across three seeds, not a complete factorial estimate of trait power. The post-change trait matrix combines the role and route changes, so it does not assign a precise share of the outcome shift to either one. The all-Balanced, fixed-seat matrix separately measures routing without the Raider change or seeded placement.

The old Raider bonus affected every collector as well as guards and raiders. A small bite increase can cross a discrete hit-count threshold: with independent uniform damage rolls from 0.85 to 1.15, three normal bites reach three health about 50% of the time; multiplying every bite by 1.05 raises that calculation to about 82.1%. This illustrates a damage breakpoint, not a measured duel win probability.

The shipped Raider profile specializes combat jobs: Invaders, Guards and Wardens retain ×1.05 bite and 34px pursuit. Collectors, diggers, returning and recovering workers use standard bite/pursuit. Health, cargo, cooldowns and the 15% upkeep premium remain unchanged. Inspector/trait text and native/reference rules agree. Traits keep a tactical distinction without giving every foraging contact a combat bonus.

The AI may use a third food site when its score is within 5% of the second. The labor fraction stays the same; nearby food, carriers, scent sensing and each ant's local combat remain individual. This removes automatic exclusion of one of three near-equivalent routes. It does not erase the physical location effect.

Starting vertices now vary deterministically with the map seed using a separate map RNG. This removes the permanent color-to-seat association. Physical food sites remain fixed; traits and ant RNG streams do not choose or pay for seats. Tunnel chambers, private grids, spawn locations, drawing, camera and digging follow the assigned nest. Legacy two-colony fixtures and fixed-seat diagnostic controls remain available. No winner is scripted or rotated based on game results.

## Same fifteen matches

| Stage | Amber wins | Coral wins | Azure wins | Unresolved |
| --- | ---: | ---: | ---: | ---: |
| Before | 4 | 9 | 2 | 0 |
| Role/route changes, fixed seats (retained trial) | 2 | 7 | 4 | 2 |
| Shipped: role/route changes + seeded seats | 6 | 4 | 3 | 2 |

Wins require a sole surviving queen. Unresolved games are censored at the horizon, not draws or worker-lead wins. Three world seeds recur across trait/controller/mirror configurations, so these fifteen matches are not fifteen independent random maps. Seat assignment is intentionally part of the changed map setup; it was fixed before the final replay, without tuning its RNG to individual winners.

| Setup | Before wins A/C/Z | After wins A/C/Z | Unresolved before / after |
| --- | --- | --- | --- |
| default_unattended | 0/3/0 | 0/1/1 | 0 / 1 |
| equal_ai_neutral | 1/2/0 | 2/1/0 | 0 / 0 |
| equal_ai_rotated_traits | 1/3/2 | 2/2/2 | 0 / 0 |
| equal_ai_neutral_mirrored | 2/1/0 | 2/0/0 | 0 / 1 |

| Setup / seed / traits | Before winner / min | After winner / min | Seed seat offset |
| --- | --- | --- | ---: |
| default_unattended / 81923 / [1, 2, 0] | Coral / 10.64 | Coral / 9.92 | 0 |
| equal_ai_neutral / 81923 / [0, 0, 0] | Coral / 17.09 | Amber / 10.04 | 0 |
| default_unattended / 7 / [1, 2, 0] | Coral / 8.99 | Azure / 14.30 | 0 |
| equal_ai_neutral / 7 / [0, 0, 0] | Coral / 11.09 | Coral / 10.63 | 0 |
| default_unattended / 42 / [1, 2, 0] | Coral / 10.49 | Unresolved / 30.00 | 1 |
| equal_ai_neutral / 42 / [0, 0, 0] | Amber / 10.75 | Amber / 8.85 | 1 |
| equal_ai_rotated_traits / 7 / [1, 2, 0] | Coral / 8.43 | Azure / 9.25 | 0 |
| equal_ai_rotated_traits / 7 / [0, 1, 2] | Azure / 10.11 | Azure / 8.71 | 0 |
| equal_ai_rotated_traits / 7 / [2, 0, 1] | Coral / 11.41 | Coral / 8.65 | 0 |
| equal_ai_rotated_traits / 42 / [1, 2, 0] | Coral / 6.75 | Amber / 9.95 | 1 |
| equal_ai_rotated_traits / 42 / [0, 1, 2] | Amber / 9.53 | Coral / 9.51 | 1 |
| equal_ai_rotated_traits / 42 / [2, 0, 1] | Azure / 8.08 | Amber / 10.01 | 1 |
| equal_ai_neutral_mirrored / 81923 / [0, 0, 0] | Amber / 13.36 | Amber / 13.54 | 0 |
| equal_ai_neutral_mirrored / 7 / [0, 0, 0] | Amber / 10.24 | Unresolved / 30.00 | 0 |
| equal_ai_neutral_mirrored / 42 / [0, 0, 0] | Coral / 8.77 | Amber / 11.78 | 1 |

Default unattended cases have unequal controllers; compare the equal-AI cohorts separately before attributing their winners to trait balance. The retained fixed-seat trial is included because the first color-win reduction alone did not reduce Coral's equal-AI win count. The remaining unresolved cases are reported as an endgame limitation rather than omitted.

## Fixed-seat controls after the changes

Neutral seat winners after: **{'Left': 4, 'Lower': 2, 'Right': 2}**, unresolved 1. These controls deliberately disable seeded placement so the actual physical-seat effect remains visible.

| Group / seed / offset / traits | Before winner | After winner |
| --- | --- | --- |
| neutral_seat_rotation / 81923 / 0 / [0, 0, 0] | Coral | Amber |
| direct_trait_swap / 81923 / 0 / [2, 1, 0] | Amber | Amber |
| neutral_seat_rotation / 7 / 1 / [0, 0, 0] | Azure | Azure |
| direct_trait_swap / 7 / 0 / [1, 0, 2] | Coral | Azure |
| neutral_seat_rotation / 42 / 2 / [0, 0, 0] | Azure | Amber |
| original_traits_equal_ai / 81923 / 0 / [1, 2, 0] | Coral | Amber |
| neutral_seat_rotation / 81923 / 1 / [0, 0, 0] | Amber | Azure |
| direct_trait_swap / 81923 / 0 / [1, 0, 2] | Azure | Amber |
| neutral_seat_rotation / 7 / 2 / [0, 0, 0] | Azure | Unresolved |
| neutral_seat_rotation / 42 / 0 / [0, 0, 0] | Amber | Azure |
| direct_trait_swap / 42 / 0 / [2, 1, 0] | Coral | Coral |
| original_traits_equal_ai / 7 / 0 / [1, 2, 0] | Coral | Azure |
| neutral_seat_rotation / 81923 / 2 / [0, 0, 0] | Azure | Coral |
| neutral_seat_rotation / 7 / 0 / [0, 0, 0] | Coral | Coral |
| direct_trait_swap / 7 / 0 / [2, 1, 0] | Coral | Azure |
| neutral_seat_rotation / 42 / 1 / [0, 0, 0] | Amber | Amber |
| direct_trait_swap / 42 / 0 / [1, 0, 2] | Azure | Coral |
| original_traits_equal_ai / 42 / 0 / [1, 2, 0] | Coral | Coral |

## Surface-foraging controls

Nine 300-second surface controls per condition rotate colors/RNG streams through each seat with Balanced traits, no births and no invasions. Guided cases retain the AI guard posts as well as food orders. Means below are living workers by physical seat, not wins. Unguided workers still use individual food sensing, pheromones and combat. Position differences persisting without colony orders rule out AI planning as the sole cause. The rectangular world, grid, route orientation and initial random streams remain interacting factors; this study does not isolate each one.

| Condition | Left | Right | Lower |
| --- | ---: | ---: | ---: |
| old_guided | 524.6 | 650.4 | 528.6 |
| unguided | 247.6 | 308.7 | 214.8 |
| three_route_guided | 445.7 | 556.7 | 488.8 |

The three-route guided cases have fewer mean survivors than the old guided cases in these surface controls. They remove an arbitrary source-selection exclusion and change match outcomes, but are not presented as a colony-survival improvement or an elimination of all spatial bias.

## Unseen-seed check

Seeds 23, 101 and 2026 were fixed before running the checks and not used to choose the changes. All colonies are Balanced with identical AI. Before uses saved two-route AI and fixed seats; after uses the shipped AI/seeded seats. The current native kernel is valid for both because Balanced combat is unchanged. These checks assess the combined AI/placement change without the Raider modification.

| Seed | Before winner / min | After winner / min | After offset |
| ---: | --- | --- | ---: |
| 23 | Azure / 9.31 | Amber / 10.82 | 0 |
| 101 | Coral / 9.36 | Coral / 8.08 | 2 |
| 2026 | Coral / 12.10 | Coral / 9.48 | 0 |

The unseen neutral controls retain a Coral edge in this small sample. Main-seed improvements should therefore be read alongside these holdouts and the remaining censored matches, rather than as proof of universal balance.

## Performance and verification

All fifteen regression suites pass. Dedicated tests cover role-specific damage and pursuit in native and reference implementations, the displayed bite value, identical labor budgets, seeded seat replay/coverage, unchanged worker RNG during map selection, actual nest spawns and connected tunnels at every seat. Existing per-ant movement/RNG, food, cargo, healing, combat, digging and invasion checks still run.

Timing runs occur after all diagnostic jobs finish. The same compact-map centroid battle fixture is used at 2,000 ants/colony, 1440×900, GL Compatibility, VSync off. Every ant still updates at 30Hz per simulated second. Natural windows have changed battles/populations; synthetic windows provide the closer capacity check.

| Workload | Before FPS | After FPS | After p95 ms | Actual speed | Target met |
| --- | ---: | ---: | ---: | ---: | --- |
| natural_0s | 105.6 | 104.2 | 14.03 | 4.00× | Yes |
| natural_60s | 132.6 | 126.2 | 12.48 | 4.00× | Yes |
| natural_180s | 186.7 | 158.8 | 10.90 | 4.00× | Yes |
| natural_360s | 272.8 | 262.6 | 5.49 | 4.00× | Yes |
| growth_cap_overview | 111.9 | 97.1 | 14.51 | 3.99× | Yes |
| growth_cap_battle_overview | 88.1 | 77.5 | 18.63 | 4.00× | Yes |
| growth_cap_battle_detail | 93.0 | 86.6 | 23.59 | 4.01× | Yes |

Targets: ≥60 mean FPS, p95 ≤33.3ms and actual speed ≥3.9× at requested 4×. No ants are aggregated, skipped off-screen, made invulnerable or removed for scores. Natural growth remains separate from provisioned stress fixtures. No new claim is made at 3,200/colony.

All recorded living-ID/open-tunnel checks and population ledgers pass. Source snapshots of the prior trait/AI rules are retained under tests/coral_baseline; raw prior endgame/map reports remain intact. The matrix reuses five previously measured identical configurations to complete its eighteen before-cases, with their source identified in the combined report.

## Reproduce current version

Use the supplied console executable with --path . and a writable absolute --log-file. Run timing alone after other jobs stop.

```powershell
./play.ps1 -Test
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --coral --shard=0/3
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --coral --shard=1/3
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --coral --shard=2/3
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --coral --mirrors-only
# Fixed seats/trait swaps; repeat with --shard=1 and --shard=2:
Godot_console.exe --headless --path . --script res://tests/coral_controls.gd -- --label=after --shard=0
Godot_console.exe --headless --path . --script res://tests/coral_guided_control.gd
Godot_console.exe --headless --path . --script res://tests/coral_holdouts.gd -- --baseline-ai
Godot_console.exe --headless --path . --script res://tests/coral_holdouts.gd
Godot_console.exe --path . --script res://tests/long_performance.gd -- --coral --target=2000
python tests/analyze_coral.py
```

Raw files: coral_balance*, coral_fixed_balance*, coral_controls_before/after*, coral_unguided_control.json, coral_guided_after.json, coral_holdouts_before/after.json and coral_performance_2000.json. The diagnostic observer continues past the player's ordinary defeat to identify the last surviving queen; ordinary game result/time are still retained.
