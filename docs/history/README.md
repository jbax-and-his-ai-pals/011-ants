> Historical guide snapshot, preserved during the 2026-10-21 consolidation. Contains superseded rules and measurements. Use the [current documentation](../../README.md) for play and development.

# Formic - ant colony sandbox

Latest: [Raid escalation](../../RAID_ESCALATION.md). Rivals send small surface probes, withdraw, allow a response interval, then reconsider larger invasions. T shows observed threats; I explains the current raid phase.

Latest: [Scouting and territory](../../SCOUTING.md). Press T for discovered food, last-seen enemy activity, route danger and explored sectors. Incoming-raid reports focus observed threats and nest breaches.

Latest founding work: [Longer growth runs and varied local starts](../../FOUNDING_GROWTH_RESULTS.md). Guaranteed starter sugar/protein now varies by seed; founding nursing, local replenishment and early labor were improved. Skirmish traces remain identical.

New: [Skirmish and founding modes](../../FOUNDING.md). Use the mode selector to keep the 2,000-worker contest or start with 12 workers per colony, widely separated nests and local food. Selecting a mode starts a new match; New seed keeps it.

Latest: [Rival nest planning](../../NEST_PLANNING.md) — real rival storage/brood construction, tunnel route improvements and corridor guards. Press Q to inspect nests and I for the current construction reason. Earlier benchmark snapshots below are historical.

Latest: [Underground planning](../../CHAMBERS.md) — storage trips, excavated room capacity, local brood feeding by nurses, and underground Guard posts. G / 8 / 9 select tunnels / storage / brood; 5 places a nest guard while underground. Earlier performance and economy snapshots below are historical.

Current economy: [Sugar and protein](../../NUTRITION.md). Fruit/nectar support sugar upkeep; insects feed protein brood costs. Individual foragers, marked routes and rival AI respond automatically to resource shortages. Earlier single-food results below are historical.

Latest: [Garden overworld](../../GARDEN.md) — varied scenery, +15% movement on soil paths, shaded pheromones lasting twice as long, and fruit/nectar/insect appearances with the existing food rules.

Current gameplay: [Food cycles and order feedback](../../FOOD_CYCLES.md). Public replenishment arrives every two simulated minutes with 30 seconds of notice. Press **O** for per-order assignments, deliveries and recent losses.

Latest traits/position/AI investigation: [CORAL_BALANCE_RESULTS.md](../../CORAL_BALANCE_RESULTS.md). Starting seats now follow the world seed, Raider combat bonuses belong to security roles, and near-equivalent food routes can share the existing labor budget. Earlier results below are historical controls.

Latest raid-commitment results: [ENDGAME_RESULTS.md](../../ENDGAME_RESULTS.md). In the same 15 configurations, unresolved matches fell from six to zero; all 2,000-per-colony 4× renderer windows passed. Earlier reports below remain historical controls.

A minimal Godot simulation with **three colonies and 2,000 individual workers each**. Direct your Amber colony's food routes, guard posts, Avoid areas, raids and excavation while Coral and Azure pursue independent strategies. All workers sense, carry, move, fight and age individually.

## Run

Open project.godot in Godot and press F5, or run from PowerShell:

```powershell
.\play.ps1
.\play.ps1 -Editor
.\play.ps1 -GodotPath 'C:\path\to\Godot_console.exe'
```

The launcher defaults to the provided Godot 4.7.2 executable in Downloads. The included Windows x64 native extension loads automatically; building it is unnecessary to play. To launch directly at 4x, append `-- --speed=4` to the Godot command. Normal play defaults to 1x.

## Controls

| Control | Action |
| --- | --- |
| Drag / wheel | Pan / cursor-centered zoom |
| Click ant / C | Inspect / follow the selected worker across layers |
| H / 0 / minimap | Focus home / fit world / navigate |
| Tab / Q | Toggle underground / cycle all three nurseries |
| 4 / 5 / 6 / 7 | Forage / Guard / Avoid / Raid; click to place a marker |
| Right-click marker / Escape | Remove marker / restore inspection and close overlays |
| R | Raid the nearest surviving rival nest; use the Raid tool to choose another |
| O | Order panel: assigned ants, food delivered, recent combat/hunger losses; click a row to focus |
| L | Labor priorities for marked forage, security and excavation |
| I | AI plan inspection; Switch colony chooses Coral or Azure |
| T | Scouting reports, explored sectors, food routes and recent danger |
| Raid report banner | Focus observed approaching raiders or a home-nest breach |
| 8 / 9 | Designate storage / brood chambers; only excavated connected tiles count |
| 5 underground | Hold a connected nest corridor with a Guard post |
| G | Open your tunnels in Dig mode; left-drag designate, right-drag erase |
| Middle-drag | Pan while digging |
| Space | Pause/resume; plans can be edited while paused |
| [ / ] | Quarter / half speed |
| 1 / 2 / 3 | Normal / double / quadruple speed |
| F | Toggle pheromone display |
| New seed | Reset all populations, queens, food, tunnels, orders and AI memory |

The camera remembers each surface/nest view. Worker cards show real health, age, job, movement speed, delivered food, kills, distance, cargo and current order. Dead workers retain a frozen record; new workers have new identities even when reusing a dead slot.

## Three colonies and recovery

Amber starts with Stewards traits, Coral with Raiders, and Azure with Balanced. Each has a queen, 600 food, its own food/home pheromones and an independent tunnel layer. Food patches are finite; individual workers carry one unit home. The triangular nest/food layout has equal local supplies. Starting vertices vary deterministically by map seed independently of colony traits. Equal win rates are still being investigated. All colonies are hostile to each other.

Only your nest accepts digging plans. Rivals still use their starting tunnels. Invaders must reach an enemy entrance and route through actual open tunnels to attack a queen; defenders respond through the same shaft. Destroying one rival queen leaves the other in play. Victory requires both rival queens dead; losing your queen causes defeat, or a draw if all queens die together. Results freeze the simulation while inspection remains available.

Badly wounded guards and raiders now retreat home and heal using stored food, then rejoin the available workforce. Troops at or below 1.2/3 health enter Recovering; healing near home restores 0.6 health/second and costs 0.05 food per health. Empty stores provide no healing. Workers leave enemy tunnels through the entrance and remain vulnerable during retreat. Wild food is carried home by foragers; there is no instant field-food healing. Existing free-forager healing near a supplied home remains available.

See [THREE_COLONIES.md](../../THREE_COLONIES.md) for new speed, recovery, inspection and elimination rules, and [GAMEPLAY.md](../../GAMEPLAY.md) for order/labor budgets.

## Economy and strategy

The sidebar separates current reserves from recent deliveries, upkeep/brood spending and net flow, estimates depletion, and distinguishes combat from hunger losses. Loss hotspot focuses the largest recent cluster on the appropriate layer. Forecasts use simulated time and recent trends, not guaranteed future deliveries.

Standard upkeep is 0.06 food/second per living queen, 0.004 per worker and 0.006 per brood. A standard queen lays every 3.5 seconds; eggs, larvae and pupae take 8/14/12 seconds, with 8 food total per new worker. Brood spending preserves a reserve. Stewards forage 8% faster, develop 15% faster and cost 7 food per worker; Raider security roles bite 5% harder and pursue farther; collectors use standard combat, and the colony pays 15% more upkeep. These remain initial profile values. Each colony can grow to 3,200 workers; brood is capped at 20 per colony.

Each rival shares scout food discoveries, ranks useful food by travel/danger, guards contested sources and shifts forage/security labor. It recalls timed raid waves when reserves, losses or home threats demand it. The rivals can target each other as well as you, using the same jobs and no resource/combat bonuses. See [RIVAL_AI.md](../../RIVAL_AI.md). [BALANCE.md](../../BALANCE.md) preserves historical two-colony experiments; those results do not establish three-colony balance.

## Verification and performance

```powershell
.\play.ps1 -Test
& 'C:\path\to\Godot_console.exe' --path . --script res://tests/performance_three_test.gd --resolution 1440x900
```

The launcher runs **eleven suites** covering economy, combat, brood, invasions, input/camera, optimized lookup, native/reference equivalence, player orders, rival strategy and the third colony/recovery. Original isolated fixtures explicitly use two colonies; the native comparison and new third-colony suite also check the full 6,000-worker setup, hostility, independent state, visuals, slow speeds, recovery and elimination.

All eight current renderer workloads pass **60 mean FPS**, **p95 frame time <=33.3ms** and **97.5% of requested 4x progression** on this machine. The eight-marker case averaged 78.6 FPS with 6,000 starting workers; no population reduction was needed. Every worker still updates at 30 Hz per simulated second, or 120 ticks per wall second at 4x. The FPS counter uses actual rendered frames. These short local tests are not a hardware or long-match guarantee; see [PERFORMANCE.md](../../PERFORMANCE.md) for populations, timing and limits.

## Implementation

Godot owns the scene, UI, camera, tunnels, missions, orders, strategy and nursery. Packed arrays store ant identity, health, job, layer, cargo, goals and independent RNGs; ants have no per-worker scene nodes or physics bodies. The GDExtension accelerates surface sensing/movement, all-hostile encounter lookup, active scent decay, attack/walked-distance bookkeeping, population counts and MultiMesh buffer construction. The retained GDScript paths can be selected with native_enabled=false and are checked for equivalent outcomes.

[Native build and licenses](../../native/README.md). Native arithmetic may differ slightly across compilers; discrete outcomes and RNG streams must match in comparison fixtures. Screenshots use the actual engine; paused manual captures display an em dash for FPS.

Current captures: [three colonies](../../screenshots/three_colonies.png), [Azure nursery](../../screenshots/azure_nursery.png), [recovering worker](../../screenshots/soldier_recovery.png). Re-render with tests/three_capture.gd.

## Long-match investigation

[LONG_MATCH_RESULTS.md](../../LONG_MATCH_RESULTS.md) records fifteen seeded 30-minute-horizon games, controlled trait/nest comparisons, later 4x renderer windows and growth/battle capacity tests. The default unattended configuration favored Coral; Azure had a consistent early-elimination disadvantage. Rendering-only changes retain the full individual simulation and bring the tested large-battle cases above 60 FPS through 2,400 workers per colony, while the current 3,200-per-colony cap still needs more optimization. No balance or population settings were changed.

Target selection now weighs home threats, observed food competition, relative strength, queen damage and travel, with seeded ties and stable commitments. Press **I / Switch colony** for target reasons and score breakdowns. See [RIVAL_AI.md](../../RIVAL_AI.md) for the policy and [TARGETING_RESULTS.md](../../TARGETING_RESULTS.md) for the paired 15-match comparison and 4× frame measurements.

The default three-colony map now uses a compact equilateral nest layout with equal local supplies and pairwise contested food sites. The paired map investigation, including mixed balance outcomes, the retained wide-layout trial, seat controls, and fresh 4× measurements is in [MAP_BALANCE_RESULTS.md](../../MAP_BALANCE_RESULTS.md).
