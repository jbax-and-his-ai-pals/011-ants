> Historical guide snapshot, preserved during the 2026-10-21 consolidation. Contains superseded rules and measurements. Use the [current documentation](../../README.md) for play and development.

# Colony orders and labor

Latest: [Scouting and territory](../../SCOUTING.md). Press T for discovered food, last-seen enemy activity, route danger and explored sectors. Incoming-raid reports focus observed threats and nest breaches.

New: [Skirmish and founding modes](../../FOUNDING.md). Use the mode selector to keep the 2,000-worker contest or start with 12 workers per colony, widely separated nests and local food. Selecting a mode starts a new match; New seed keeps it.

Latest: [Underground planning](../../CHAMBERS.md) — storage trips, excavated room capacity, local brood feeding by nurses, and underground Guard posts. G / 8 / 9 select tunnels / storage / brood; 5 places a nest guard while underground. Earlier performance and economy snapshots below are historical.

Current economy: [Sugar and protein](../../NUTRITION.md). Fruit/nectar support sugar upkeep; insects feed protein brood costs. Individual foragers, marked routes and rival AI respond automatically to resource shortages. Earlier single-food results below are historical.

Latest: [Garden overworld](../../GARDEN.md) — varied scenery, +15% movement on soil paths, shaded pheromones lasting twice as long, and fruit/nectar/insect appearances with the existing food rules.

Current gameplay: [Food cycles and order feedback](../../FOOD_CYCLES.md). Public replenishment arrives every two simulated minutes with 30 seconds of notice. Press **O** for per-order assignments, deliveries and recent losses.

The player directs persistent colony intent. Workers still walk, smell trails, carry one food, fight, dig, and enter nests individually. Orders do not teleport workers or grant stat bonuses.

| Tool | Key | Behavior |
| --- | --- | --- |
| Forage | 4 | Guide a share of workers toward a food site. Nearby food and pheromone sensing still apply; loaded workers return home. Known depleted sites stop recruiting. Unexplored sites keep searching. |
| Guard | 5 | Maintain a small patrol at a point, replace casualties from available workers, and engage nearby enemies. Guards stop pursuing enemies beyond 110px from the post. |
| Avoid | 6 | Mark a 100px danger circle. Your surface workers detour around it, ignore its food and avoid pursuing enemies into it. Workers already inside can escape. Contact combat is still possible; enemies ignore your markers. |
| Raid | 7 | Maintain a party at a target. Within 90px of the rival entrance, the party enters the actual tunnels and attacks the queen using existing invasion rules. R places this marker at the nearest surviving hostile entrance; click another entrance with Raid to choose it explicitly. |

Select a tool, then click the surface. Drag to pan; scroll to zoom. Right-click a marker to remove it; Escape returns to inspection. Markers show assignment counts and status on the map and dots on the minimap. There are eight markers total, up to three of each type and one Raid; placing another Raid moves it. Avoid cannot cover your own entrance. A target covered by a later Avoid becomes Blocked until the conflict is removed.

Orders persist while paused. Clear orders releases surface assignments; raiders already underground return through the entrance. New seed resets markers and labor priorities. Finished matches freeze orders with the simulation.

## Labor

Press L or Priorities to cycle each category through Off, Low, Normal, High. Assignment updates immediately when possible, and recruitment refreshes every 0.8 simulated seconds.

| Category | Off | Low | Normal | High |
| --- | --- | --- | --- | --- |
| Marked forage | 0% | 10% | 25% | 50% of living workers |
| Guard / raid | 0 | 6 | 12 | 24 workers per post |
| Excavation | 0 | 6 | 12 | 24 workers while plans are queued |

Marked forage is a total budget across active food markers; workers choose the closest marker. Unassigned foragers continue scouting and following trails. Security has an additional combined cap of 48 workers or 20% of your living population, whichever is smaller. Existing posts receive their budget in placement order. Empty-handed, unengaged surface foragers nearest each security target are recruited first; carriers finish delivery. Security Off pauses player automatic raids as well. Home defenders still respond automatically.

Excavation Off preserves queued tiles and existing progress. Lowering priority releases excess excavators; underground workers walk out. The rival now adapts its own forage/security priorities and orders using scout discoveries, reserves, threats and losses. Press I to inspect its plan; see RIVAL_AI.md. Existing trait rules still apply. These priorities express effort; they are not new worker castes or upgrades.

## Food and losses

The sidebar separates reserves from recent flow. After five simulated seconds, it shows deliveries per simulated minute, spending (upkeep plus brood), net flow and an estimated empty time. The trend uses up to 30 simulated seconds. The separate No deliveries estimate uses current upkeep alone; it excludes future brood spending. Forecasts change with travel times, fighting, food depletion and births.

Combat and hunger losses appear separately as lifetime totals and a rolling 30-second window. Loss hotspot focuses the cluster with the most recent deaths, switching nest layers if necessary. Its ring expires when the losses leave that window. The ant card also shows the worker's current order or Autonomous.

## Verification

`play.ps1 -Test` runs eleven suites. The gameplay suite checks real viewport shortcuts, placement/removal, priority controls, recruitment, replacement, carrier protection, exhausted patches, actual tunnel entry, cancellation, digging limits, telemetry and native/fallback carrier detours. Native comparison also runs a full 4,000-worker command scenario and requires matching assignments, food, health, scent and individual random streams.

The renderer benchmark includes four-marker and eight-marker 4x workloads at full starting population, all labor priorities High, active combat, brood and digging. See PERFORMANCE.md for local measurements. Render the current interface with `tests/gameplay_capture.gd`; captures are saved as `screenshots/orders.png`, `screenshots/labor.png`, and `screenshots/guard_order.png`.

Three colonies now start by default. Quarter/half speed, soldier recovery, all-hostile battles and multi-rival victory are described in [THREE_COLONIES.md](../../THREE_COLONIES.md).
