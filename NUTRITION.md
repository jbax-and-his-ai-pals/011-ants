# Sugar and protein

> System reference and milestone evidence. [Gameplay](GAMEPLAY.md) owns current player rules; [Performance](PERFORMANCE.md) owns the latest benchmark baseline. Measurements and suite counts below belong to this milestone unless explicitly identified as current. See the [documentation index](docs/README.md) for related systems.

Fruit and nectar now yield **sugar**. Insect sources yield **protein**. Each worker still picks up one unit, physically carries it home, and deposits it in its own colony's matching store. Dropped cargo keeps its nutrient type and can be recovered by another colony. Distinct cargo colors and the worker inspector identify the load.

## What the colony consumes

- Sugar pays worker/queen upkeep, the existing small brood maintenance charge, and paid soldier recovery. Running out produces the existing starvation damage and eventual deaths. Protein cannot substitute for sugar.
- Protein pays egg laying and brood stage transitions: one to lay, three to enter the larval stage, and three/four to enter pupation depending on the colony doctrine. Sugar cannot substitute for protein. Unfed stages wait, then resume when protein arrives. Already-paid pupae can still mature under the existing rules.
- Breeding still requires a modest sugar reserve, so it does not expand an actively starving colony. Existing traits, health, healing rates, population limits and worker behavior remain in place.

Each colony starts with 600 sugar and **120 protein** at the default 2,000-worker start. New seed clears both stores and all nutrient counters. No saved-match migration is required.

## Automatic collection

Workers now leave separate sugar and protein food trails, plus the existing home trail. Every 0.8 simulated seconds, the colony updates two bounded demand weights. The sugar target is one minute of current upkeep; the protein target covers a short brood pipeline and is bounded between 8 and 80. Dead queens and colonies at their population cap reduce protein demand. Weights vary from 0.25 to 4; collecting a less-needed resource remains possible.

Individual foragers weight their three local antenna samples toward the resource running short. Among visible food within the existing 86-pixel sensing radius, they compare squared distance divided by the corresponding demand weight. Sight does not expand, worker RNG stays individual, and workers do not receive undiscovered food coordinates. Loaded workers finish bringing their existing cargo home before choosing again.

Marked forage routes use the same demand weights when assigning the existing bounded labor share. Player markers persist; low-frequency rival AI also multiplies its existing distance/quantity/danger score by nutrient demand. No extra workers, free deliveries, resource conversion, or automatic cancellation of player orders is introduced. Free scouts remain available outside marked routes.

Soil speed and shaded pheromone retention apply as before. All nine food/home trail fields participate in the same sparse scent lifecycle; the combined overlay keeps colony colors. Resource identity remains separate in sensing, cargo and accounting.

## Reading the display

The left panel shows **S** sugar and **P** protein for Amber and Coral/Azure. Separate incoming/outgoing rates use up to 30 simulated seconds; the sugar runway assumes no further deliveries at current upkeep. Shortage messages explain whether ants are favoring fruit/nectar or insects. The **O** order panel separates sugar and protein actually delivered, retaining pickup-order attribution after reassignment. A row can deliver some of both because marked foragers still collect locally rather than teleporting to a specific patch.

Food quantities, initial source positions, one-unit carrying, and the forecast schedule remain unchanged. Each fully empty replenishment group supplies 12,000 sugar and 6,000 protein across three sites; partially full sites only top up the missing quantity. Forecasts remain public to all colonies.

## Validation

All **18 regression suites** passed. New nutrition checks exercise both kernels, all three colonies, both load types, actual home banking, order credits, actual local pickup/antenna responses, typed cargo drops and enemy recovery, upkeep/recovery separation, blocked/resumed brood, rival ranking, refills and reset. The longer simulation check conserves sugar and protein independently across patches, cargo, drops, arrivals, stores and expenditure. Native/reference checks compare the new cargo, stores, delivered counters, demand weights and all nine scent fields alongside existing worker state; maximum observed position error remains 0.000252 pixels.

Screenshots in `screenshots/nutrition_orders.png` and `nutrition_protein_carrier.png` show an actual seeded match. The sugar/protein shortage screenshots deliberately set a store to zero as UI fixtures, rather than representing naturally measured match outcomes.

The native hot loop uses packed per-worker cargo types, cached colony demand, and three additional sparse scent fields. The baked garden and existing ant batches remain in use. The default is still **2,000 workers per colony / 6,000 individuals**, with no off-screen simulation skipping or population reduction.

Rendered results are recorded in `tests/nutrition_performance.json`, using the same nine garden/food-cycle workloads, five-second windows, 1440×900 GL, VSync off, requested 4×, and an eight-order panel in provisioned scenarios. Targets remain mean at least 60 FPS, p95 at most 33.3 ms, and actual speed at least 3.9×. Provisioned windows start near 2,000 per colony and retain actual combat deaths. Natural checkpoints use complete fixed ticks between live windows. This milestone does not establish new colony win rates or performance at the larger growth cap.

```powershell
.\play.ps1 -Test
Godot_console.exe --path . --script res://tests/food_performance.gd -- --food-cycle --nutrition
```

## Measured performance

Local RTX 4070 Ti SUPER, GL Compatibility, 1440×900, VSync off. All nine matched workload windows and the extra shortage stress window passed the existing thresholds. Individual combat and population losses remain active.

| Workload | Mean FPS | p95 ms | Actual speed |
| --- | ---: | ---: | ---: |
| food_natural_0s | 207.5 | 8.01 | 4.00× |
| food_natural_90s | 218.4 | 8.31 | 4.00× |
| food_natural_120s | 228.9 | 7.68 | 4.00× |
| food_natural_240s | 306.2 | 4.77 | 3.99× |
| food_natural_360s | 343.5 | 4.02 | 3.99× |
| food_2000_panel_overview | 156.9 | 11.14 | 4.00× |
| food_2000_panel_battle | 111.1 | 16.05 | 4.01× |
| food_2000_panel_detail | 89.1 | 26.33 | 4.00× |
| food_2000_panel_arrival | 162.7 | 10.80 | 4.00× |
| protein_shortage_2000_panel_battle | 124.7 | 13.62 | 3.99× |

The extra `tests/nutrition_shortage_performance.json` starts all three colonies with zero protein and 40 seconds of sugar, keeps eight orders and the current resource HUD visible, and runs dense individual combat. It measured 124.7 FPS, p95 13.62 ms, and 3.99×. Measured protein deliveries during that fixture were [368, 575, 1386] for Amber/Coral/Azure.

The nine garden-baseline workloads remain recorded separately in `tests/garden_performance.json`; their battle overview/detail were 130.5/101.2 FPS, compared with 111.1/89.1 FPS for the nutrient milestone. The simulation and battle outcomes now differ because resource decisions changed, so this is a workload comparison rather than a rendering-only benchmark. All current workloads stay above the mean 60 FPS target. Short local runs do not guarantee that every frame stays below 16.67 ms or that other hardware will match these results.
