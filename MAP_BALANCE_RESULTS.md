# Three-colony map balance

> Historical experiment: results, suite counts and reproduction commands describe the milestone tested. Later systems can change outcomes; rerunning today does not reconstruct that version. Use [Gameplay](GAMEPLAY.md), [Performance](PERFORMANCE.md) and the [Roadmap](ROADMAP.md) for current guidance. See the [documentation index](docs/README.md) for context.

Paired against the latest target-selection baseline: the same fifteen configurations, world seeds, traits, mirrored controls, 2,000 starting workers per colony and 30-simulated-minute horizon. Target selection, labor policy, raid timing, worker movement/combat/pheromones, food costs and brood rules remain fixed. No Azure-specific stat bonus was added.

## Map audit

The original map grew from two upper nests plus a third lower nest. Azure was not short of food: it had more nearby supplies and the largest nearest-nest territory share. It was, however, much closer to both rivals and closer to the world boundary. Its supplies and the old central source drew traffic toward the lower nest.

| Measure | Before Amber / Coral / Azure | New, each colony |
| --- | --- | --- |
| Food within 240px | 8,800.0 / 8,800.0 / 13,200.0 | 13,200.0 |
| Food uniquely nearest to nest | 24,800.0 / 24,800.0 / 29,200.0 | 21,200.0 |
| Nearest-territory share, splitting shared sites | 24,800.0 / 24,800.0 / 29,200.0 | 26,300.0 |
| Nearest border, pixels | 875.0 / 875.0 / 364.0 | 560.7 |

Old pair distances: 1022.0, 722.7, 722.7px. New pair distances: 742.0, 742.0, 742.0px. The compact triangle is equilateral. Each colony has three near private sites at 190px, two outer private sites at 360px, and two adjacent pairwise shared sites at 371px. Private paths stay in their own nearest-nest territory; every pair has one equally stocked shared site.

The map retains eighteen initial patches. Total food changes from **78,800 to 78,900** (+0.13%) to divide integer food equally across three colonies; the extra 100 is global and symmetric. Surface size remains 3276×1764. Nest chambers/shafts, spawn positions, camera bookmarks and drawings follow the moved nests. Two-colony regression fixtures retain their old map.

## Route observation

A separate fixed-tick default-seed capture measures the first 120 simulated seconds. Foreign-forager proximity is sampled every five simulated seconds within 240px of each entrance; these approximate worker-seconds describe early route exposure, not the entire match or raid traffic.

| Layout | Foreign forager seconds near A / C / Z | Living workers A / C / Z at 120s | Combat losses A / C / Z |
| --- | --- | --- | --- |
| before | 0 / 15 / 760 | 1252 / 1421 / 1051 | 778 / 603 / 973 |
| after | 0 / 10 / 20 | 1340 / 1287 / 1138 | 690 / 737 / 886 |

Screenshots at the same simulated time: [original layout](screenshots/map_before.png), [compact equal-access layout](screenshots/map_after.png). Individual ants still follow nearby food and pheromones, deliver one unit, choose their own combat target, and recover using the existing rules. Safer routes result from placement rather than scripted ant paths.

## Same fifteen matches

A win requires one surviving queen. Unresolved matches are censored, not counted as draws or worker-lead wins. The same three seeds recur across configurations; this is a small controlled sample, not fifteen independent random worlds.

| Setup | Before wins A/C/Z | After wins A/C/Z | Unresolved before / after |
| --- | --- | --- | --- |
| default_unattended | 0/3/0 | 0/3/0 | 0 / 0 |
| equal_ai_neutral | 3/0/0 | 0/1/0 | 0 / 2 |
| equal_ai_rotated_traits | 3/1/0 | 0/3/1 | 2 / 2 |
| equal_ai_neutral_mirrored | 1/1/0 | 0/1/0 | 1 / 2 |

First queen eliminated before: **{'Azure': 9, 'Amber': 3, 'Coral': 2}** in 14 matches with queen deaths. After: **{'Amber': 6, 'Azure': 5}** in 11 such matches. Overall wins before/after: [7, 5, 0] / [0, 8, 1] (Amber/Coral/Azure). Unresolved: 3 / 6.

| Setup / seed / traits | Before winner / min | After winner / min | First queen lost before / after |
| --- | --- | --- | --- |
| default_unattended / 81923 / [1, 2, 0] | Coral / 15.87 | Coral / 12.98 | Azure / Amber |
| equal_ai_neutral / 81923 / [0, 0, 0] | Amber / 20.11 | Coral / 21.38 | Azure / Azure |
| default_unattended / 7 / [1, 2, 0] | Coral / 22.27 | Coral / 14.31 | Amber / Amber |
| equal_ai_neutral / 7 / [0, 0, 0] | Amber / 21.04 | Unresolved / 30.00 | Azure / None |
| default_unattended / 42 / [1, 2, 0] | Coral / 16.22 | Coral / 25.88 | Azure / Amber |
| equal_ai_neutral / 42 / [0, 0, 0] | Amber / 23.36 | Unresolved / 30.00 | Azure / None |
| equal_ai_rotated_traits / 7 / [1, 2, 0] | Unresolved / 30.00 | Coral / 14.62 | Azure / Azure |
| equal_ai_rotated_traits / 7 / [0, 1, 2] | Coral / 18.03 | Unresolved / 30.00 | Amber / Azure |
| equal_ai_rotated_traits / 7 / [2, 0, 1] | Unresolved / 30.00 | Coral / 12.55 | None / Amber |
| equal_ai_rotated_traits / 42 / [1, 2, 0] | Amber / 20.35 | Coral / 9.26 | Coral / Amber |
| equal_ai_rotated_traits / 42 / [0, 1, 2] | Amber / 19.04 | Unresolved / 30.00 | Coral / None |
| equal_ai_rotated_traits / 42 / [2, 0, 1] | Amber / 28.43 | Azure / 10.70 | Azure / Amber |
| equal_ai_neutral_mirrored / 81923 / [0, 0, 0] | Coral / 23.25 | Unresolved / 30.00 | Amber / Azure |
| equal_ai_neutral_mirrored / 7 / [0, 0, 0] | Unresolved / 30.00 | Unresolved / 30.00 | Azure / None |
| equal_ai_neutral_mirrored / 42 / [0, 0, 0] | Amber / 22.11 | Coral / 9.11 | Azure / Azure |

The result is mixed. Azure now wins one rotated-trait match and is first eliminated less often, but Coral wins eight, Amber wins none, and six matches remain unresolved versus three in the prior baseline. Equal geometric access therefore improves a documented map issue without establishing overall match balance. The new default is a neutral resource layout for further testing; it should not be described as a solved balance pass. Endgame completion and the remaining position/strategy effects need separate investigation, with no trait buffs inferred from this small sample.

## Wide-layout trial retained

The first candidate kept the upper pair's ~1,022px distance and moved the lower nest to match, with the same symmetric food sectors. Its fifteen matches yielded wins [2, 3, 0] and **10 unresolved games**. It reduced sampled early entrance traffic but greatly prolonged endgames. The shipped candidate therefore uses a compact 742px equilateral triangle, closer to the original ~723px rival distance, while retaining equal access. No raid timer or combat thresholds were retuned. The wide trial is retained rather than omitted from the results.

## Surface-only seat controls

Nine additional 300-second controls rotate colors and their worker RNG streams through all three physical seats for each seed. All colonies use identical AI and Balanced traits; births and invasions are disabled to isolate surface activity. These are not full-match winner tests, and their absolute worker counts should not be compared with the reproducing full matches.

| Seed / seat offset | Living A / C / Z | Living left / right / lower |
| --- | --- | --- |
| 81923 / 0 | [546, 660, 478] | [546, 660, 478] |
| 81923 / 1 | [636, 673, 502] | [502, 636, 673] |
| 81923 / 2 | [536, 648, 715] | [648, 715, 536] |
| 7 / 0 | [133, 438, 402] | [133, 438, 402] |
| 7 / 1 | [585, 596, 680] | [680, 585, 596] |
| 7 / 2 | [443, 472, 765] | [472, 765, 443] |
| 42 / 0 | [603, 742, 420] | [603, 742, 420] |
| 42 / 1 | [654, 608, 543] | [543, 654, 608] |
| 42 / 2 | [601, 594, 659] | [594, 659, 601] |

Mean living workers by color A/C/Z: [526.3, 603.4, 573.8]. By physical left/right/lower seat: [524.6, 650.4, 528.6]. The rectangular world, axis-aligned scent grid, coarse AI census and local combat still permit position/orientation effects despite equal geometric resources. These controls diagnose residual effects rather than guarantee equal win rates.

## Full renderer at 4×

Timing runs follow all balance/seat jobs, with those processes stopped. The existing live-window harness measures natural checkpoints plus full-population and dense-battle fixtures at 2,000 workers/colony. The artificial battle is centered at the new triangle's centroid, equally far from every nest, with the detail camera following that center. Historical battle fixtures used (1638,1050), so the new fixture is a capacity check rather than an identical-position causal FPS comparison.

| Workload | Workers at start | Mean FPS | p95 ms | Actual speed | Target met |
| --- | --- | ---: | ---: | ---: | --- |
| natural_0s | 6000 | 132.5 | 11.61 | 4.00× | Yes |
| natural_60s | 4646 | 162.6 | 10.43 | 4.00× | Yes |
| natural_180s | 3032 | 213.6 | 8.03 | 4.00× | Yes |
| natural_360s | 886 | 304.2 | 4.25 | 3.99× | Yes |
| natural_600s | 475 | 341.2 | 3.78 | 4.00× | Yes |
| growth_cap_overview | 6000 | 119.5 | 12.56 | 4.00× | Yes |
| growth_cap_battle_overview | 5996 | 97.8 | 15.32 | 3.99× | Yes |
| growth_cap_battle_detail | 6000 | 111.5 | 17.37 | 3.99× | Yes |

Target: mean ≥60 FPS, p95 ≤33.3ms and actual speed ≥3.9×. The benchmark uses 1440×900, GL Compatibility, VSync off, and the local RTX 4070 Ti SUPER. Natural populations change over the match; synthetic fixtures spawn real workers without fake immortality or deleting populations. Every worker still updates at 30Hz per simulated second. No claim is made at 3,200/colony.

All sampled full-match ledgers satisfy initial workers + births - combat losses - hunger losses = living workers. Unique IDs/open-tunnel checks pass. The 13 regression suites include native/reference individual RNG and behavior checks plus geometric/private-route/mirrored-access tests.

## Reproduce

Use the supplied console executable with --path . and an absolute writable --log-file. Run FPS measurements after other diagnostics finish.

```powershell
./play.ps1 -Test
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --map-balance --shard=0/3
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --map-balance --shard=1/3
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --map-balance --shard=2/3
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --map-balance --mirrors-only
Godot_console.exe --headless --path . --script res://tests/map_seats.gd
Godot_console.exe --path . --script res://tests/map_capture.gd
Godot_console.exe --path . --script res://tests/long_performance.gd -- --map-balance --target=2000
python tests/analyze_map_balance.py
```

The full-match observer continues past ordinary player defeat to determine the last surviving queen; ordinary game result/time remain in each report. Raw paired records are targeting_balance* and map_balance*. The wide trial is map_wide_balance* (add --wide-map to reproduce). Static/early-route audits are map_layout_audit.json and map_route_audit.json. Seat controls are map_seat_results.json and renderer windows map_performance_2000.json. Earlier reports remain intact.
