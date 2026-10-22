# Performance at 1,000 workers per colony

> Historical experiment: results, suite counts and reproduction commands describe the milestone tested. Later systems can change outcomes; rerunning today does not reconstruct that version. Use [Gameplay](GAMEPLAY.md), [Performance](PERFORMANCE.md) and the [Roadmap](ROADMAP.md) for current guidance. See the [documentation index](docs/README.md) for context.

Each colony starts with **1,000 workers**, with room for growth to 1,600. The world remains 234 × 126 tiles. Each ant retains its own random stream, identity, movement, three pheromone sensors, cargo, health, combat cooldown, job, and lifetime statistics. Simulation stays at 30 ticks per simulated second for every worker, including off-screen workers.

Starting food reserves are 300 per colony, and map food quantities are ten times the earlier 100-worker setup. Workers still carry one food, pay the same individual upkeep, and follow the existing combat and brood rules. Raid and digging party sizes remain unchanged. Colony balance at this population has not been tuned.

## Local renderer measurements

Godot 4.7.2, GL Compatibility, NVIDIA GeForce RTX 4070 Ti SUPER, 1440 × 900, VSync requested off. Normal play retains its VSync setting. Short local measurements do not guarantee performance on other hardware or in every long-running match.

| Scene | Average FPS | Average ms | p95 ms | Workers (start to end) | Visible at end | Sim seconds / wall second |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Crowded startup | 274.0 | 3.65 | 9.81 | 2000 to 2000 | 1000 | 1.03 |
| Surface, 1x | 250.0 | 4.00 | 10.95 | 2000 to 2000 | 902 | 1.01 |
| Full-world overview, 1x | 123.7 | 8.08 | 14.88 | 2000 to 1994 | 1994 | 1.00 |
| Underground with diggers, 1x | 195.6 | 5.11 | 12.69 | 1953 to 1945 | 12 | 1.01 |
| Close inspection, 4x | 25.9 | 38.63 | 50.14 | 1923 to 1678 | 365 | 3.99 |
| Later overview, 1x | 130.3 | 7.67 | 15.38 | 1672 to 1659 | 1659 | 1.00 |

**4× speed is the remaining CPU stress limit.** Successive recent passes varied from approximately 26 to 41 FPS while maintaining the full simulation rate. The table records the last pass. It maintains four simulated seconds per wall second but falls below the 55 FPS target. Real-time scenes comfortably clear that target. No worker updates are skipped to improve FPS.

Each scene resets to 2,000 workers. Fresh cases pre-simulate 10 seconds; crowded startup has no simulated warmup; the later overview pre-simulates 60 seconds. Underground also pre-simulates eight seconds of digging. After 60 live warmup frames, 240 frames are measured. Brood and automatic raids are disabled to isolate the worker workload; combat remains active, so worker counts fall. Both nests and the surface continue simulating regardless of the visible layer. Average FPS is 1,000 divided by average measured frame milliseconds. Simulation-speed ratios separately detect a game clock that falls behind.

Raw results: [tests/performance_2000_optimized.json](tests/performance_2000_optimized.json). The script requires 55 average FPS for real-time cases and at least 90% of requested simulation speed for every case. It reports 4× FPS separately as a stress result.

```powershell

& 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/performance_test.gd --resolution 1440x900

```

The UI shows rendered FPS, smoothed frame milliseconds, and simulation CPU milliseconds. The FPS counter settles shortly after startup. Manual screenshot fixtures show an em dash because they do not run live frame processing.

## Bottlenecks and changes

The first unoptimized 2,000-worker run averaged 10.9 FPS on the surface and 17.8 FPS in overview, even after combat reduced the population to 1,376 and 1,294 respectively. At 4×, it managed only 2.85 simulated seconds per wall second. These exploratory results used a continuing match and the earlier food quantities, so they are diagnostic evidence rather than a controlled speedup ratio. Preserved in [tests/performance_2000_baseline.json](tests/performance_2000_baseline.json).

- **Drawing:** detailed ants previously issued many separate drawing commands. Three reusable MultiMesh batches now draw detailed bodies, overview bodies, and carried food with per-ant positions, headings, and colors. Selection, health bars, combat flashes, and job markers remain individual. The minimap uses a single batched line primitive and refreshes with visual overlays; camera navigation updates immediately.

- **Encounters:** friendly nest crowds previously entered every enemy scan. A packed bucket grid now separates colonies and layers, stores workers in linked lists, and caches nearby enemy candidates per bucket each tick. Every worker still chooses the exact nearest visible enemy inside its own detection radius. Bucket and worker tie order are preserved.

- **Food:** a spatial index replaces scanning all food patches, including accumulated dropped cargo, for every scout. Neighborhood candidates are shared, but each ant independently checks range, nearest distance, remaining amount, and original tie priority. Pickup stays exclusive.

- **Pheromones:** flat four-neighbor deposits avoid temporary coordinate arrays. A packed active-cell list and membership flags replace repeated dictionary writes; every active scent cell still decays with the existing timing and strengths.

- **Other work:** per-colony worker lists preserve alternating movement order without scanning both colonies twice. Idle cooldown and attack work is skipped. Static scenery remains cached and off-screen graphics culled.

Seven regression suites cover economy and conservation, digging, brood and replacement slots, combat and invasions, navigation and inspection, and the new scale checks. Dense and spread 2,000-worker target searches are compared against exhaustive scans. Food selection is checked against an exhaustive 1,200-patch fixture, including ties, depletion, dropped loads, and layer filtering. Earlier balance records describe smaller populations/maps.
