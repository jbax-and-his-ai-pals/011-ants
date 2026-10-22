# 4x simulation with 2,000 workers per colony

> Historical experiment: results, suite counts and reproduction commands describe the milestone tested. Later systems can change outcomes; rerunning today does not reconstruct that version. Use [Gameplay](GAMEPLAY.md), [Performance](PERFORMANCE.md) and the [Roadmap](ROADMAP.md) for current guidance. See the [documentation index](docs/README.md) for context.

The game starts with 4,000 individual workers across two colonies. The native Godot extension accelerates the existing foraging and enemy-detection loops. Every worker still updates at 30 Hz per simulated second, including off-screen workers: **4x executes 120 full simulation ticks per wall second**. Positions, headings, health, cargo, random streams, pheromone sensors, combat cooldowns, jobs, births, and deaths remain individual.

No simulation update throttling, reduced population, or off-screen behavior approximation was used. Normal play still starts at 1x; use the 4x button or key 3, or pass `-- --speed=4` to the Godot command line.

## Local renderer measurements

Godot 4.7.2, GL Compatibility, NVIDIA GeForce RTX 4070 Ti SUPER, 1440 x 900, VSync requested off. Normal play retains its VSync setting. These short measurements describe this machine and workload, not a hardware guarantee.

| Workload | Mean FPS | p95 frame ms | Workers start to end | Actual speed |
| --- | ---: | ---: | --- | ---: |
| Crowded startup, 1x | 209.8 | 7.41 | 4000 to 4000 | 1.00x |
| Surface close-up, 1x | 197.9 | 9.70 | 4000 to 3997 | 1.00x |
| Whole world, 1x | 108.1 | 13.46 | 4000 to 3988 | 1.00x |
| Underground with diggers, 1x | 220.6 | 8.19 | 3921 to 3909 | 1.00x |
| Close inspection, 4x | 170.4 | 8.41 | 3994 to 3935 | 4.00x |
| Whole world, 4x | 74.0 | 19.36 | 3981 to 3792 | 4.00x |
| Crowded startup, 4x | 148.1 | 8.86 | 4000 to 4000 | 4.02x |
| Established live colonies + rival AI, 4x | 69.7 | 21.62 | 3535 to 3458 | 4.00x |
| Brood + raids + digging + rival AI, 4x | 70.1 | 19.63 | 4000 to 3930 | 4.00x |
| Later overview, 1x | 111.1 | 15.82 | 3359 to 3340 | 1.00x |
| Four orders + High labor + rival AI, 4x | 61.3 | 22.98 | 4000 to 3930 | 4.01x |
| Eight orders + High labor + rival AI, 4x | 57.6 | 24.31 | 4000 to 3916 | 4.01x |
| Rival contested food strategy, 4x | 69.6 | 19.45 | 4000 to 3975 | 4.00x |
| Rival guards + raid wave, 4x | 71.4 | 19.37 | 3993 to 3950 | 3.99x |

All cases reset to 4,000 workers and warm up for 60 live frames, then measure 240 rendered frames. Combat remains active, so reported worker counts decline naturally. The crowded cases have no simulated pre-warmup; normal fresh cases pre-simulate 10 seconds; mature overview pre-simulates 60 seconds. Underground adds eight seconds of digging. `live_start_4x` enables food upkeep, brood, AI raids, two immediately ordered raid parties and tunnel designation from the full starting population. `live_colonies_4x` enables upkeep, brood and AI raids and pre-simulates 90 seconds to exercise an established live colony. The four/eight-marker cases also enable brood and invasions from full population, set all labor priorities High, and queue excavation. They exercise marked forage, Guard, Avoid and Raid together; the eight-marker case adds another forage/guard post and two more Avoid circles. The rival strategy/war fixtures also enable the full live simulation and place workers at a contested source without reducing starting population. The war case advances the simulation clock to raid readiness and provides reserves, then asserts both rival guards and raiders are assigned. Recruitment and combat remain normal; modes and peak assignment counts are recorded to show adaptation during sampling. All live cases enable the new strategy; worker isolation cases disable it along with brood and automatic raids.

All fourteen cases passed. With the new rival AI, four player markers averaged 61.3 FPS and eight averaged 57.6 FPS at full 4x progression. The contested-source fixture averaged 69.6 FPS; the war fixture averaged 71.4 FPS and recorded both 12 guards and 12 raiders, followed by withdrawal and changed labor plans. The longest rival decision measured 3.634 ms. The eight-marker workload remains close to the local 55 FPS floor, with limited room for additional systems. Established live colonies recorded 46 births and changed from Raiding through Gathering to Recovering during the sampled match.

The benchmark requires **55 average FPS**, **p95 frame time no worse than 33.3 ms**, and **at least 97.5% of requested simulation speed**, including every 4x case. It separately records simulation progression so rendering a slow simulation cannot pass. The speed ratio accounts for the fractional tick accumulator to avoid 30 Hz quantization in short, high-FPS samples; the completed-tick-only ratio is recorded separately. This fraction stays below one simulation step after processing, so it cannot mask sustained overload. Worker counts, diggers, raiders, brood and births are recorded in the raw JSON.

```powershell
& 'C:\Users\baxte\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/performance_test.gd --resolution 1440x900
```

Raw current results: [tests/performance_results.json](tests/performance_results.json). The benchmark requires the native class to load; it never silently measures the fallback.

## What changed

The final native surface tick totals about 3.08 ms versus 14.95 ms before. Free foraging/movement fell from 10.84 to 1.64 ms, and encounters from 2.79 to 0.15 ms. The formerly overloaded 4x close-up now renders about 170 FPS while maintaining the requested clock speed. Full-world 4x is more limited by drawing and remaining bookkeeping, but clears the frame-time targets.

The previous GDScript-only 4,000-worker trial measured 4.9 FPS at requested 4x and advanced only 2.61 simulated seconds per wall second. A normal-speed surface tick took about 14.95 ms, dominated by 10.84 ms of movement/foraging and 2.79 ms of encounters. Raw results are preserved in [tests/performance_4000_gdscript.json](tests/performance_4000_gdscript.json); the old notes are in [PERFORMANCE_4000_GDSCRIPT.md](PERFORMANCE_4000_GDSCRIPT.md).

- **Native foraging:** one batch reads/writes the existing packed arrays. Every eligible worker runs the same three-sensor steering, exploration, nearest-food search, exclusive pickup, delivery, healing, scent deposit, reflection, and speed rules. Each ant uses its original Godot RandomNumberGenerator. Shared food and scent updates keep their alternating-colony and slot order.
- **Native encounters:** packed bucket heads and linked slots select each ant's exact nearest enemy within its profile radius. Layer filtering and tie order are preserved. Underground candidates use the existing tunnel line-of-sight function. Movement snapshots and simultaneous attack resolution remain unchanged.
- **Mission ordering:** free surface foragers do not enter tunnels or read other workers' moved positions, and mission workers do not alter their eligibility within a tick. Foragers can therefore batch before the remaining mission movement while retaining all shared food/scent ordering. Fighters use the same pre-movement snapshot. Mixed-mission comparison tests check this dependency explicitly.
- **Nursery counting:** one living count per colony per nursery update replaces repeated full-population scans; local counts track births and starvation deaths for the existing reserve and cap rules.
- **Rendering:** existing MultiMesh bodies/cargo, culling, terrain/trail textures, cached grass and minimap batching remain in place.

The original GDScript functions remain available using `native_enabled = false`. The included Windows x64 DLL loads in direct CLI runs even without a Godot extension cache; other platforms need a native build or use the slower GDScript fallback. See [native/README.md](native/README.md) for reproducible, pinned build dependencies and licenses.

## Behavior verification

All ten suites cover food conservation and spending, connected digging, brood/replacement slots and population caps, combat, queen invasions and outcomes, camera/input/inspection, exhaustive enemy/food searches, and native/reference equivalence. Native comparisons cover all colony profiles, swapped nests, 4,000 separate random streams, delivery, pickup, healing, scent, reflection, repeated full-population ticks, and interleaved combat, portal, guard, queen-raid and digging missions. The measured repeated-run position difference is below 0.001 pixel; discrete state and random-stream consumption must match. Arithmetic across compilers is not promised bit-for-bit identical over indefinitely long chaotic matches.

Starting stores remain 600 per colony; food quantities remain twenty times the original 100-worker setup. Worker cargo, upkeep, brood timing and combat damage remain unchanged. The gameplay milestone adds explicit labor budgets, command steering, Guard posts, surface-only Avoid filtering, and persistent Raid intent; see [GAMEPLAY.md](GAMEPLAY.md).

## Order milestone verification

Native and GDScript comparisons include 180 full-population ticks with all four order types, mixed cargo and random worker positions. Discrete state, command assignments and all individual RNG streams match; repeated movement differs by at most 0.00024414 px in the existing comparison fixtures. A separate controlled carrier traverses around an Avoid circle and delivers in both implementations. Surface Avoid does not suppress encounters in tunnels beneath it. Viewport tests exercise order placement/removal and the labor buttons. Current screenshots were rendered and inspected at 1440x900.

Pre-order native results are retained in [tests/performance_pre_orders.json](tests/performance_pre_orders.json). Orders use bounded marker counts, periodic recruitment, packed worker goals and native per-ant steering; no workers are aggregated, skipped off-screen or updated at a lower frequency.

## Adaptive rival milestone

The rival shares the packed per-worker command fields and allocation code. Native foraging now applies command goals to both colonies, and guard pursuit limits apply to either colony. Strategy runs about every three simulated seconds; recruitment retains the existing 0.8-second cadence. A coarse census replaces pairwise strategic scans. Discovery and memory are capped at 64 patches/sites per decision, limiting growth from cargo drops. Normal movement, food sensing, cargo, scent, combat and 30 Hz updates remain individual.

The ten-suite test run passed, including a dedicated AI suite and full-population native/reference comparisons with both leaders active. Tests cover discovery, source ranking/depletion, independent ownership, guards, loaded workers, reserve/loss response, home threats, raid/recall/cooldowns, hysteresis and pause/result/reset. The command comparison's maximum movement discrepancy remains 0.00024414 px, with identical discrete outcomes and RNG streams. Rival captures use the actual scene and AI; raid/defense captures are controlled fixtures.

The prior order-milestone benchmark remains in [tests/performance_pre_rival_ai.json](tests/performance_pre_rival_ai.json). Current results include rival decision counts, maximum decision duration, modes and peak guard/raid assignments. These short local runs do not establish long-match balance or performance on other hardware.
