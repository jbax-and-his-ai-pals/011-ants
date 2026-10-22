# The garden overworld

> System reference and milestone evidence. [Gameplay](GAMEPLAY.md) owns current player rules; [Performance](PERFORMANCE.md) owns the latest benchmark baseline. Measurements and suite counts below belong to this milestone unless explicitly identified as current. See the [documentation index](docs/README.md) for related systems.

The meadow now has connected bare-soil paths, grass, fallen leaves, damp earth, shaded plant cover and scattered stones. The surface minimap uses the same ground texture. Scenery stays behind ants and every ground type remains walkable.

Current garden generation also includes [strategic source alternatives](STRATEGIC_GARDEN.md): shorter exposed sugar approaches, longer shaded protein approaches, nominal trip reports and observed rival route risk. The original makeover evidence below predates that addition and the sugar/protein split.

## Two terrain effects

- **Bare soil: +15% surface movement.** The light tan paths link nest areas and run outward toward food sectors. The multiplier applies to individual scouts, loaded carriers, guards, raiders, recovering workers and fighters, for all three colonies. Existing colony speed traits multiply with it. Workers sample the cell under their feet; they keep their local sensing, orders, avoidance and pheromone behavior. The AI does not gain a new global route planner.
- **Shade: twice the pheromone half-life.** Cool, dark patches around plant cover reduce evaporation for all six food/home scent fields. The per-decay retention is the square root of the ordinary retention, so two shaded decays retain the same amount as one ordinary decay. Soil and shade can overlap. Deposition strength, scent caps, sampling, and underground movement retain their existing rules.

Leaf litter, damp ground, leaves, plants and stones are decorative in this milestone. There are no new terrain attack bonuses, obstacles, nutrition resources or penalties. A small surface legend explains the effects; hovering it gives the full rules. Selecting an ant shows its ground and terrain-adjusted speed. Underground inspectors show Tunnel and the existing underground movement speed.

## Food appearances

Fruit appears as red-orange berries with leaves; nectar as a pale flower with an amber center; insect food as a segmented carcass with legs and antennae. Each source has a name and remaining quantity. All still use exactly the same food resource, one-unit pickup, physical carrying, colony stores, brood/upkeep spending and replenishment schedule. The two alternating forecast groups each include all three appearances. Dropped loads retain their small cargo marker.

## Implementation and checks

`scripts/garden.gd` builds the seeded garden once per reset with its own RNG. It does not consume world-generation or worker RNG or change food positions or quantities. Ground colors use a small interpolated texture. A private viewport paints the complete static garden, including plants, leaves and stones, once per reset into a 3276×1764 texture (about 23 MB of RGBA pixels). Its update mode then disables rendering; the normal surface draws one textured rectangle. Scenery has no individual nodes, physics bodies or per-frame procedural generation. Soil speed and shade are packed cell arrays read by the native simulation and the retained GDScript reference.

The default remains **2,000 ants per colony / 6,000 individual workers**, with the existing 3,200-per-colony growth cap. No off-screen simulation skipping or aggregate worker behavior was added.

All **17 regression suites** passed via `play.ps1 -Test`. New garden checks cover deterministic generation, worker/world RNG independence, unchanged food, each colony's actual loaded/unloaded movement in both kernels, shaded retention in all six fields, security movement and underground isolation. Existing native/reference checks also passed: maximum observed position difference was 0.000252 pixels. Overview, detail/inspector and underground screenshots were inspected at 1440×900.

Reproduce the renderer check with the provided Godot console executable:

```powershell
Godot_console.exe --path . --script res://tests/food_performance.gd -- --food-cycle --garden
```

Results go to `tests/garden_performance.json`, preserving the previous food-cycle benchmark files. These are the same five-second 1440×900 GL workloads at 4×, with eight active orders and the order panel open in provisioned workloads. Natural checkpoints advance with complete fixed simulation ticks between live renderer windows. Provisioned battle fixtures begin near 2,000 per colony and sustain real combat losses. Targets remain mean at least 60 FPS, p95 no more than 33.3 ms, and actual simulation speed at least 3.9×. Performance at the larger growth cap is not claimed by this check.

## Rendered result

Local RTX 4070 Ti SUPER, GL Compatibility, 1440×900, VSync off. All nine workloads passed at 2,000 starting ants per colony. Actual deaths continue during each window; population growth limits are unchanged.

| Workload | Mean FPS | p95 ms | Actual speed |
| --- | ---: | ---: | ---: |
| food_natural_0s | 208.6 | 7.74 | 4.00× |
| food_natural_90s | 225.5 | 7.67 | 4.00× |
| food_natural_120s | 244.6 | 6.23 | 4.00× |
| food_natural_240s | 309.9 | 4.50 | 4.00× |
| food_natural_360s | 359.0 | 3.75 | 4.00× |
| food_2000_panel_overview | 164.4 | 10.83 | 4.00× |
| food_2000_panel_battle | 130.5 | 12.62 | 4.00× |
| food_2000_panel_detail | 101.2 | 23.50 | 4.00× |
| food_2000_panel_arrival | 161.3 | 10.73 | 3.99× |

The first garden pass cached drawing commands but still drew the scenery geometry each frame. The dense battle detail failed at 52.9 FPS (p95 36.05 ms). Baking that same scenery once per reset raised this workload to 101.2 FPS (p95 23.50 ms); battle overview rose from 60.1 to 130.5 FPS. The failed pass is retained in `tests/garden_performance_before_bake.json`. Simulation rules and scenery detail stayed the same during that optimization. Frame-driven settling means exact start timestamps and surviving counts differ slightly; these are local workload measurements, not a controlled win-rate study or a promise that every frame stays below 16.67 ms.

The screenshot/cache check also verifies that the baked texture stops updating after its reset frame, remains identical across pan/zoom/layer changes, and changes after resetting to another seed. Screenshots are in `screenshots/garden_overview.png`, `garden_detail.png`, `garden_underground.png` and `garden_seed42_overview.png`.
