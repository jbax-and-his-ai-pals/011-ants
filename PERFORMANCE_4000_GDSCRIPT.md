> Historical snapshot before the native kernel. Benchmark commands with current code produce current results.

> Historical experiment: results, suite counts and reproduction commands describe the milestone tested. Later systems can change outcomes; rerunning today does not reconstruct that version. Use [Gameplay](GAMEPLAY.md), [Performance](PERFORMANCE.md) and the [Roadmap](ROADMAP.md) for current guidance. See the [documentation index](docs/README.md) for context.

# Performance at 2,000 workers per colony

Each colony starts with **2,000 workers**, with room for growth to 3,200. The world remains 234 × 126 tiles. Each ant retains its own random stream, identity, movement, three pheromone sensors, cargo, health, combat cooldown, job, and lifetime statistics. Simulation stays at 30 ticks per simulated second for every worker, including off-screen workers.

Starting food reserves are 600 per colony, and map food quantities are twenty times the earlier 100-worker setup. Workers still carry one food, pay the same individual upkeep, and follow the existing combat and brood rules. Raid and digging party sizes remain unchanged. Colony balance at this population has not been tuned.

## Local renderer measurements

Godot 4.7.2, GL Compatibility, NVIDIA GeForce RTX 4070 Ti SUPER, 1440 × 900, VSync requested off. Normal play retains its VSync setting. Short local measurements do not guarantee performance on other hardware or in every long-running match.

| Scene | Average FPS | Average ms | p95 ms | Workers (start to end) | Visible at end | Sim seconds / wall second |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Crowded startup | 131.0 | 7.64 | 18.91 | 4000 to 4000 | 2000 | 1.00 |
| Surface, 1x | 108.8 | 9.19 | 20.98 | 4000 to 3988 | 1772 | 1.00 |
| Full-world overview, 1x | 62.2 | 16.08 | 27.30 | 3999 to 3972 | 3972 | 1.00 |
| Underground with diggers, 1x | 136.4 | 7.33 | 20.40 | 3920 to 3895 | 12 | 1.00 |
| Close inspection, requested 4x | 4.9 | 204.91 | 233.81 | 3580 to 2452 | 468 | 2.61 |
| Later overview, 1x | 68.0 | 14.70 | 25.07 | 3356 to 3325 | 3325 | 1.00 |

**Normal speed passes; requested 4x overloads the CPU.** The normal-speed cases all clear the local 55 average FPS target and maintain real time. The 4x case averages 4.9 FPS and only 2.61 simulated seconds per wall second, so the benchmark correctly exits with failure for that stress case. It does not sustain 4x at this population. The full overview is about 62 FPS with nearly 4,000 workers, leaving little headroom for slower hardware. No worker behavior or update frequency was reduced for this trial. The surface profile totals 14.95 ms per simulation tick: 10.84 ms for movement/foraging, 2.79 ms for encounters, and the remainder for scent/jobs and resolution. At 30 ticks per simulated second, that consumes about 45% of one CPU thread at normal speed and would require 179% at 4x, before rendering. This explains the CPU limit; fewer survivors reduce the later workload.

Each scene resets to 4,000 workers. Fresh cases pre-simulate 10 seconds; crowded startup has no simulated warmup; the later overview pre-simulates 60 seconds. Underground also pre-simulates eight seconds of digging. After 60 live warmup frames, 240 frames are measured. Brood and automatic raids are disabled to isolate the worker workload; combat remains active, so worker counts fall. Both nests and the surface continue simulating regardless of the visible layer. Average FPS is 1,000 divided by average measured frame milliseconds. Simulation-speed ratios separately detect a game clock that falls behind.

Raw results: [tests/performance_4000_gdscript.json](tests/performance_4000_gdscript.json). The script requires 55 average FPS for real-time cases and at least 90% of requested simulation speed for every case. It reports 4× FPS separately as a stress result, but still fails if the requested simulation speed cannot be maintained.

```powershell

& 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/performance_test.gd --resolution 1440x900

```

The UI shows rendered FPS, smoothed frame milliseconds, and simulation CPU milliseconds. The FPS counter settles shortly after startup. Manual screenshot fixtures show an em dash because they do not run live frame processing.

## Existing optimizations and comparison

The preceding 1,000-per-colony run measured 250 FPS on the surface and 123.7 FPS in full overview. Its 4x stress result was 25.9 FPS and 3.99 simulated seconds per wall second. The earlier measured population was about 2,000; this run starts with 4,000. Preserved results: [tests/performance_2000_optimized.json](tests/performance_2000_optimized.json), [previous performance notes](PERFORMANCE_2000.md). No worker behavior or update frequency was reduced for this scaling trial.

The first unoptimized 2,000-worker run averaged 10.9 FPS on the surface and 17.8 FPS in overview, even after combat reduced the population to 1,376 and 1,294 respectively. At 4×, it managed only 2.85 simulated seconds per wall second. These exploratory results used a continuing match and the earlier food quantities, so they are diagnostic evidence rather than a controlled speedup ratio. Preserved in [tests/performance_2000_baseline.json](tests/performance_2000_baseline.json).

- **Drawing:** detailed ants previously issued many separate drawing commands. Three reusable MultiMesh batches now draw detailed bodies, overview bodies, and carried food with per-ant positions, headings, and colors. Selection, health bars, combat flashes, and job markers remain individual. The minimap uses a single batched line primitive and refreshes with visual overlays; camera navigation updates immediately.

- **Encounters:** friendly nest crowds previously entered every enemy scan. A packed bucket grid now separates colonies and layers, stores workers in linked lists, and caches nearby enemy candidates per bucket each tick. Every worker still chooses the exact nearest visible enemy inside its own detection radius. Bucket and worker tie order are preserved.

- **Food:** a spatial index replaces scanning all food patches, including accumulated dropped cargo, for every scout. Neighborhood candidates are shared, but each ant independently checks range, nearest distance, remaining amount, and original tie priority. Pickup stays exclusive.

- **Pheromones:** flat four-neighbor deposits avoid temporary coordinate arrays. A packed active-cell list and membership flags replace repeated dictionary writes; every active scent cell still decays with the existing timing and strengths.

- **Other work:** per-colony worker lists preserve alternating movement order without scanning both colonies twice. Idle cooldown and attack work is skipped. Static scenery remains cached and off-screen graphics culled.

Seven regression suites cover economy and conservation, digging, brood and replacement slots, combat and invasions, navigation and inspection, and the new scale checks. Dense and spread 4,000-worker target searches are compared against exhaustive scans. Food selection is checked against an exhaustive 1,200-patch fixture, including ties, depletion, dropped loads, and layer filtering. Earlier balance records describe smaller populations/maps.
