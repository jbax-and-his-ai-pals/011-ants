# Performance and verification

Current measured baseline: strategic garden sources, scouting trip reports and observed rival route risk, three colonies, both modes. Historical experiments are indexed in [docs](docs/README.md); their results describe the version tested, not current balance or performance guarantees.

## Simulation contract

Keep individual worker identities, health, cargo, roles and RNG streams. All ants update at 30 ticks per simulated second, requiring 120 ticks per wall second at 4×. Offscreen workers remain simulated. Orders, digging, carrying, nursing and combat use actual ants and physical travel.

The 234×126-tile world uses 14-pixel tiles. Workers live in packed arrays without individual nodes or physics bodies. Godot handles UI, camera, missions, planning, nursery and strategy. The C++ GDExtension accelerates surface sensing/movement, spatial encounters, scent decay, damage/bookkeeping, courier flows and visual batches. MultiMeshes preserve visible individuals. Nine scent fields cover home, sugar and protein for each colony. Expensive planning and report work is cached or runs at bounded intervals.

The GDScript reference remains selectable with `native_enabled = false`. Comparison fixtures require matching discrete outcomes and individual RNG states; movement permits less than 0.002 pixels of floating-point difference. See [native development](native/README.md) for builds and boundaries.

## Latest recorded measurements

Strategic garden verification passed **28 rule suites**, **24 seeded map checks / 72 colony route pairs**, three natural six-minute Founding openings and **12 complete renderer windows**. Renderer: Godot 4.7.2, RTX 4070 Ti SUPER, GL Compatibility at 1440×900, VSync off. The gate remains mean >=60 FPS, p95 <=33.3 ms and actual progression >=3.9x at requested 4x.

| Workload | Mean FPS | p95 ms | Actual speed |
| --- | ---: | ---: | ---: |
| Skirmish orders control | 219.5 | 8.15 | 4.00x |
| Skirmish battle / detail controls | 156.2 / 152.7 | 12.23 / 15.46 | 4.00 / 4.02x |
| Natural Founding, 0/180/360/540s | 687.2–1022.9 | worst 2.12 | 3.99–4.00x |
| Founding 2,000-per-colony preparation reserve | 332.5 | 5.93 | 4.00x |
| Founding 2,000-per-colony queen overview | 278.7 | 6.42 | 4.00x |
| Founding 2,000-per-colony soldier battle / detail | 193.4 / 133.2 | 9.82 / 16.71 | 3.99 / 4.01x |
| Founding 2,000-per-colony underground queen | 264.2 | 6.29 | 4.01x |

[Current renderer evidence](tests/strategic_garden_performance.json), [rule/opening summary](tests/strategic_garden_verification.json), [seeded accessibility](tests/strategic_garden_accessibility.json). Full methods and interface captures are in [Strategic garden](STRATEGIC_GARDEN.md).

Each window lasts five wall seconds after settling with full 30-Hz individual simulation. The expanded scouting panel and territory overlay remain open, with bounded route estimates/risk active. Natural Founding uses a scripted player buying Foraging, queuing a real brood room and starting the daughter when ready; populations are much smaller than 6,000. Supplied stress cases begin with 2,000 workers per colony, roughly 20% soldiers in each rival, connected extra room cells and legal stored food. The preparation fixture begins with eight free protein per colony to exercise the twenty-protein nurse hold; other stress fixtures have active daughter projects. Live combat reduces populations during settling and measurement.

All sampled worker states, population births/losses, protein buffers/nurse loads, room capacity and final stress-case soldier counts reconciled. Scouting scans peaked at 3.996 ms; the largest whole rival decision was 8.540 ms at its existing three-simulated-second cadence, including census, construction and invasion planning. The geometry cache remained below its 384-entry cap. Terrain is still baked once per reset. No individual movement code, update cadence or starting population was reduced.

These short local measurements do not guarantee every frame at 60 FPS, growth-cap performance, controlled improvements over earlier sessions, or balanced human openings. New resources and route choices intentionally change encounters; the prior Skirmish trace equality claim applies only to the clarity revision. Retained native/reference tests passed with a maximum observed position difference of 0.000252px.

The preceding [clarity investigation](CLARITY_RESULTS.md) retains its [final twelve-window rerun](tests/clarity_performance.json), [four isolated diagnostics](tests/clarity_diagnostic.json) and [initial failed outlier](tests/clarity_performance_initial.json), whose cause was not established. The earlier [progression investigation](FOUNDING_PROGRESSION_RESULTS.md) retains its [renderer results](tests/founding_progression_performance_after.json) and [baseline](tests/founding_progression_performance_before.json). Those reports describe their measured revisions.

## Prior baseline: raid escalation

Godot 4.7.2, GL Compatibility, RTX 4070 Ti SUPER, 1440×900, VSync disabled for measurement. Normal play retains VSync. The scouting panel/territory overlay was open. Five-wall-second live windows measure actual simulation progression; checkpoint gaps advance through full fixed ticks.

All **14 windows** passed: mean ≥60 FPS, p95 frame time ≤33.3 ms, actual speed ≥3.9× at requested 4×. This is an established regression gate, not a promise that every frame meets 16.7 ms. Raw results retain populations and phase telemetry.

| Workload group | Windows | Mean FPS range | Worst p95 ms | Actual speed range |
| --- | ---: | ---: | ---: | ---: |
| Natural Skirmish, 0–360 simulated seconds | 5 | 147.0–193.8 | 12.75 | 3.99–4.00× |
| Provisioned 2,000-per-colony overview/battle/detail/arrival | 4 | 89.5–149.8 | 30.30 | 4.00–4.02× |
| Natural Founding, 0/180/600/1200/1800 seconds | 5 | 440.2–922.4 | 5.38 | 4.00–4.01× |

Reports: [Skirmish JSON](tests/raid_escalation_skirmish_performance.json), [Founding JSON](tests/raid_escalation_founding_performance.json). The full table and physical raid timing fixtures are in [raid escalation](RAID_ESCALATION.md).

Provisioned cases begin with 2,000 workers per colony; live combat reduces populations during measurement. Natural Founding populations are much smaller and do not validate 6,000-worker growth. Historical 3,200-per-colony cap battles failed the 60 FPS gate; current cap-scale performance remains unproven. Short local windows do not establish long-session pacing, win rates or behavior on other hardware.

## Reproduce

Run from the project root. Rule verification currently runs **28 suites**:

```powershell
.\play.ps1 -Test
```

Coverage includes economy, combat, brood, invasions, controls/camera, native/reference equivalence, orders, rival strategy, three-colony recovery, targeting, map/trait controls, food cycles, terrain, nutrition, rooms, rival construction, both modes, founding logistics, scouting raid escalation, Founding progression, royal preparation reserves, bounded event history, objective input, work explanations, earlier rival nursery planning and strategic source/travel/risk decisions.

Run renderer benchmarks separately from rule tests and other heavy workloads:

```powershell
$godot = Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Path .godot -Force | Out-Null
& $godot --path . --log-file "$PWD/.godot/strategic_renderer.log" --script res://tests/strategic_garden_performance.gd
# Previous clarity workload (overwrites its report):
& $godot --path . --log-file "$PWD/.godot/clarity_renderer.log" --script res://tests/progression_performance.gd -- --clarity
# Earlier raid-escalation workload comparison:
& $godot --path . --log-file "$PWD/.godot/raid_skirmish.log" --script res://tests/chambers_performance.gd -- --raid-escalation
& $godot --path . --log-file "$PWD/.godot/raid_founding.log" --script res://tests/founding_performance.gd -- --raid-escalation --logistics
```

These commands overwrite the corresponding JSON reports. The strategic garden harness runs both modes and the soldier/daughter stress fixtures with scouting open; the older commands keep their original output names. Preserve a baseline copy before a comparison. Other Godot projects may stay open, but competing workloads affect timing; record that context. Never close unrelated Godot instances to run this project.

For simulation changes, run relevant focused checks and the full rule suite, native/reference checks when applicable, then both renderer workloads. Record seed, mode, traits/seats, populations, simulated age, overlays/camera, actual speed and frame timing. Distinguish natural growth from supplied battle fixtures. Audit worker validity, population births/losses, food accounting, room capacity and real raid budgets. Documentation-only edits need link/source checks, not a benchmark rerun.
