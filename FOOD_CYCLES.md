# Food cycles and order feedback

> System reference and milestone evidence. [Gameplay](GAMEPLAY.md) owns current player rules; [Performance](PERFORMANCE.md) owns the latest benchmark baseline. Measurements and suite counts below belong to this milestone unless explicitly identified as current. See the [documentation index](docs/README.md) for related systems.

The initial meadow patches still hold finite food. Workers take one unit, carry it physically home, and leave pheromone trails. No replenishment goes directly into a colony's stores.

Every **120 simulated seconds**, three public sites top up to **6,000 food each**. Sites alternate between two groups of three, distributed around the middle of the colony triangle. A dedicated seeded RNG rotates the arrangement without changing any worker's random stream. Six reusable sites keep the event system bounded; surviving food is retained and a wave only adds the missing amount up to the site's cap. Initial patches do not regenerate.

At **30 simulated seconds before arrival**, gold rings and countdowns appear on the surface and minimap. The notice at the top of the map focuses one announced location. Place Forage or Guard orders there before the food arrives. A known empty Forage site stops recruiting, but a forecast at that site allows workers to prepare again. After replenishment, existing orders resume through the normal allocation path. Each rival receives the same public information and uses its existing route selection and labor budget to prepare. Ordinary food discovery still needs scouts.

All timers use simulation time: at 4×, a two-minute food cycle takes 30 real seconds; pausing freezes the countdown. Queen death still ends a normal match and stops future arrivals.

**Orders [O]** opens a panel with up to eight current surface orders. Click a row to focus its marker. It shows:

- Current living ants assigned, sampled once per simulated second.
- Total food actually delivered home for that order, credited to the order held when the worker picked it up. Reassignment on the return trip preserves the credit. Cancelled orders disappear and late carriers do not recreate their statistics.
- Combat and hunger deaths in the last 30 simulated seconds, attributed to the order held at death. Autonomous losses remain in the colony totals. Avoid zones assign no workers, so their row does not claim nearby deaths.

Orders, priorities and AI inspection panels close one another. Escape closes them. There is no saved-match migration; New seed resets forecasts, orders, counters and the map together.

## Validation

`play.ps1 -Test` runs 16 suites, including `tests/food_cycle_test.gd`. The new checks exercise actual pickup and home delivery in both the native and reference kernels, reassignment credit, cancelled orders, rolling combat/hunger windows, warning and arrival boundaries, capped replenishment, bounded site reuse, seeded reset, worker RNG independence and equal AI forecast access. The existing conservation test now includes explicitly recorded food introduced by waves.

The native extension adds player pickup/delivery event callbacks; movement, local sensing, combat, carried loads and individual RNG behavior are unchanged. Counters are event based, with no new per-frame worker scan. A bounded worker scan updates assignment counts once per simulated second; the UI refreshes on its existing cadence.

Rendered performance results are recorded in `tests/food_cycle_performance.json`, using the existing five-second 1440×900 GL renderer windows at requested 4×. The dedicated harness includes natural matches across forecasts and arrivals and provisioned 2,000-per-colony overview/battle/detail workloads with eight orders and the panel open. The synthetic battle retains actual individual combat and deaths. Thresholds remain mean 60 FPS, p95 at most 33.3 ms, actual speed at least 3.9×.

Run with the provided Godot console executable:

```powershell
Godot_console.exe --path . --script res://tests/food_performance.gd -- --food-cycle
```

This milestone changes the match economy; earlier balance reports describe the previous finite-supply rules. No new win-rate balance claim is made.

## Measured result

All **16 regression suites** and **9 rendered windows** passed. Local RTX 4070 Ti SUPER, 1440×900 GL, VSync off; all windows requested 4×. Worker counts can decline through actual combat during each window.

| Workload | Mean FPS | p95 ms | Actual speed |
| --- | ---: | ---: | ---: |
| food_natural_0s | 114.9 | 12.89 | 4.00× |
| food_natural_90s | 129.3 | 12.66 | 4.00× |
| food_natural_120s | 135.7 | 12.21 | 4.00× |
| food_natural_240s | 179.1 | 9.32 | 4.01× |
| food_natural_360s | 192.7 | 8.22 | 4.00× |
| food_2000_panel_overview | 84.8 | 17.95 | 4.00× |
| food_2000_panel_battle | 72.0 | 23.84 | 4.00× |
| food_2000_panel_detail | 78.0 | 26.86 | 4.00× |
| food_2000_panel_arrival | 90.5 | 16.38 | 4.00× |

The dedicated arrival window (separate `tests/food_cycle_arrival_performance.json`) crossed t=120 live with all 6,000 workers present at its start, eight orders, and the order panel open. It measured 90.5 FPS, p95 16.38 ms and 4.00×; three supplies totaling 18,000 new food arrived. The remaining windows are in `tests/food_cycle_performance.json`. No population reduction, aggregate ant behavior or off-screen update skipping was introduced. These are short local measurements, not a guarantee of every frame staying below 16.67 ms or of the same results on other hardware.
