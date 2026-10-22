> Historical guide snapshot, preserved during the 2026-10-21 consolidation. Contains superseded rules and measurements. Use the [current documentation](../../README.md) for play and development.

# Three colonies at 4x

Latest: [Raid escalation](../../RAID_ESCALATION.md). Rivals send small surface probes, withdraw, allow a response interval, then reconsider larger invasions. T shows observed threats; I explains the current raid phase.

Latest: [Scouting and territory](../../SCOUTING.md). Press T for discovered food, last-seen enemy activity, route danger and explored sectors. Incoming-raid reports focus observed threats and nest breaches.

Latest founding work: [Longer growth runs and varied local starts](../../FOUNDING_GROWTH_RESULTS.md). Guaranteed starter sugar/protein now varies by seed; founding nursing, local replenishment and early labor were improved. Skirmish traces remain identical.

Latest mode verification: [Founding and preserved skirmish](../../FOUNDING.md). The mode selector keeps the original 2,000-worker setup available alongside a 12-worker founding opening.

Latest: [Rival nest planning](../../NEST_PLANNING.md) — real rival storage/brood construction, tunnel route improvements and corridor guards. Press Q to inspect nests and I for the current construction reason. Earlier benchmark snapshots below are historical.

Latest: [Underground planning](../../CHAMBERS.md) — storage trips, excavated room capacity, local brood feeding by nurses, and underground Guard posts. G / 8 / 9 select tunnels / storage / brood; 5 places a nest guard while underground. Earlier performance and economy snapshots below are historical.

Current economy: [Sugar and protein](../../NUTRITION.md). Fruit/nectar support sugar upkeep; insects feed protein brood costs. Individual foragers, marked routes and rival AI respond automatically to resource shortages. Earlier single-food results below are historical.

Latest: [Garden overworld](../../GARDEN.md) — varied scenery, +15% movement on soil paths, shaded pheromones lasting twice as long, and fruit/nectar/insect appearances with the existing food rules.

Current gameplay: [Food cycles and order feedback](../../FOOD_CYCLES.md). Public replenishment arrives every two simulated minutes with 30 seconds of notice. Press **O** for per-order assignments, deliveries and recent losses.

Latest traits/position/AI investigation: [CORAL_BALANCE_RESULTS.md](../../CORAL_BALANCE_RESULTS.md). Starting seats now follow the world seed, Raider combat bonuses belong to security roles, and near-equivalent food routes can share the existing labor budget. Earlier results below are historical controls.

Latest raid-commitment results: [ENDGAME_RESULTS.md](../../ENDGAME_RESULTS.md). In the same 15 configurations, unresolved matches fell from six to zero; all 2,000-per-colony 4× renderer windows passed. Earlier reports below remain historical controls.

The default game starts with **2,000 ants per colony: 6,000 individual workers**. All eight renderer workloads passed the **60 FPS mean**, **p95 frame time at most 33.3 ms**, and **97.5% of requested simulation speed** requirements. No starting-population reduction was needed.

Current target-selection replay and fresh 4× measurements: [TARGETING_RESULTS.md](../../TARGETING_RESULTS.md). Historical rendering-optimization results remain below.

## Long-run follow-up

See [LONG_MATCH_RESULTS.md](../../LONG_MATCH_RESULTS.md) for later match states and explicit growth/battle stress tests. Natural 4x windows averaged 100-252 FPS as populations declined. After rendering-only batching of minimap dots, corpse markers and pheromone pixels, the large-battle overview measured **81.4 FPS at 2,000 per colony**, **68.9 FPS at 2,400**, and **42.7 FPS at 3,200**. The cap overview measured 59.2 FPS and cap battle detail 54.6 FPS. All maintained about 4x simulation speed, but the 3,200-per-colony workloads failed the 60 FPS target. Population limits and balance rules remain unchanged.

The table below retains the earlier eight-workload snapshot. Current long-run frame summaries, before/after baselines and reproducible harnesses are linked in the follow-up report.

Godot 4.7.2, GL Compatibility, NVIDIA RTX 4070 Ti SUPER, 1440x900, VSync requested off. Normal play retains VSync. Short local measurements are not a hardware guarantee.

| Workload, all at requested 4x | Mean FPS | p95 ms | Workers at measurement start/end | Actual speed |
| --- | ---: | ---: | --- | ---: |
| Startup overview | 99.0 | 16.18 | 6000 / 5825 | 4.02x |
| Surface overview | 88.1 | 17.81 | 5802 / 5408 | 4.01x |
| Close inspection | 163.8 | 11.39 | 5837 / 5606 | 4.01x |
| Underground + excavation | 133.8 | 11.36 | 5509 / 5329 | 3.99x |
| Fresh colonies + ordered raids/digging | 90.2 | 17.18 | 6000 / 5783 | 4.01x |
| Eight markers + High labor | 78.6 | 20.45 | 6000 / 5699 | 3.99x |
| Contested source + guard/raid wave | 88.5 | 18.86 | 6000 / 5743 | 4.00x |
| Established live colonies | 96.9 | 18.78 | 4183 / 4015 | 3.98x |

Each case resets to 6,000 workers. Both independent AIs, combat, brood, upkeep and recovery stay enabled. Sixty rendered frames settle each case before 240 measured frames. Ordinary cases have ten simulated seconds of prior activity; startup/order/war cases begin fresh; the established case pre-simulates 90 seconds. Underground adds eight seconds of excavation. Deaths during warmup and sampling account for lower populations in the table; the benchmark does not delete ants to meet its target.

The eight-marker case finished with 24 diggers and 24 raiders and averaged 78.6 FPS. The war fixture assigned 12 Coral guards and 12 raiders and changed plans during sampling. The established match recorded 62 births. The benchmark checks actual simulated time, including fractional tick phase, so a slow simulation cannot pass by drawing smoothly.

## What made 6000 viable

The first three-colony order stress run averaged about 13 FPS before the extra batching. The optimized quick run reached 71 FPS; the final complete run measured 78.6 FPS in that workload. Timing varies between short runs; the raw final report is [tests/performance_three_results.json](../../tests/performance_three_results.json).

- Drawing now builds each visible ant transform and cargo instance in a native MultiMesh batch. Every visible worker is still rendered; the same detailed/overview geometry and colors are retained.
- Native scent decay updates all six independent fields, retaining active-cell pruning and clearing expired texture pixels.
- Native bookkeeping updates walked distance, attack reach/cooldowns, simultaneous damage and death lists. Actual deaths, cargo drops, colony orders and brood remain in Godot.
- Native living/intruder counts replace repeated GDScript scans. Mission dispatch returns only unprocessed worker IDs in the existing rotating colony order.
- Foraging and encounter batches now support three independent colonies, all hostile opponents, distinct tunnel layers, food stores and random streams. Each worker still receives **30 updates per simulated second, or 120 at 4x**.

The final order-case tick measured approximately 0.32 ms encounters, 2.42 ms movement, 0.27 ms resolution/nursery and 0.44 ms scent/jobs. No off-screen simulation approximation or aggregate population model was used.

## Verification and reproduction

`play.ps1 -Test` runs eleven suites. Existing two-colony fixtures explicitly set colony_count=2 to retain their original isolation scenarios. New coverage checks three-colony hostility, independent food/scent/AI/tunnels, fractional speeds, paid soldier recovery through full ticks in both kernels, enemy elimination and inspection. Full 6,000-worker native/reference fixtures preserve discrete outcomes and every individual RNG stream. Native transforms/colors match the retained GDScript drawing path; movement and lifetime-distance comparisons allow below 0.002px floating-point error, while food/health fields retain strict tolerances.

Run the current benchmark:

```powershell
& 'C:\path\to\Godot_console.exe' --path . --script res://tests/performance_three_test.gd --resolution 1440x900
```

Append `-- --quick` for just the eight-marker stress case. It writes performance_three_quick.json; the complete report stays separate. This is a local eight-workload check, not a long-match balance guarantee.

Previous two-colony results and optimization history remain in [PERFORMANCE_TWO_COLONIES.md](../../PERFORMANCE_TWO_COLONIES.md). The old tests/performance_test.gd remains an explicit two-colony benchmark. Native build instructions are in [native/README.md](../../native/README.md).

The default three-colony map now uses a compact equilateral nest layout with equal local supplies and pairwise contested food sites. The paired map investigation, including mixed balance outcomes, the retained wide-layout trial, seat controls, and fresh 4× measurements is in [MAP_BALANCE_RESULTS.md](../../MAP_BALANCE_RESULTS.md).
