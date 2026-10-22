# Underground planning

> System reference and milestone evidence. [Gameplay](GAMEPLAY.md) owns current player rules; [Performance](PERFORMANCE.md) owns the latest benchmark baseline. Measurements and suite counts below belong to this milestone unless explicitly identified as current. See the [documentation index](docs/README.md) for related systems.

Storage and brood designations now change how the colony works. Loaded foragers enter the nest and walk to connected storage before their deliveries count. Nurses take protein from storage to brood chambers. New workers hatch in those chambers and walk out through the tunnels. All three colonies use the same logistics rules.

## Controls

- **G**: tunnel excavation. The existing brush widens tunnels; automatically connected remote designations begin with a narrow access route.
- **8**: storage chamber. Left-drag paints a 3×3 room brush; workers excavate dirt through the usual digging priority. Each connected, excavated storage tile adds **2,000 units** of shared sugar/protein capacity.
- **9**: brood chamber. Each connected, excavated tile supports **two brood**, up to **80** per colony. Nurses must deliver protein locally before egg laying and stage feeding can use it.
- **5 while viewing your underground nest**: place a Guard post on an open, connected tunnel. Guards walk inside and hold that location using the existing security labor budget. A surface Guard order remains a surface patrol.
- **Right-drag in a chamber planning mode** removes room designations and queued work in the brush. Excavated tunnels stay open. Occupied brood tiles cannot be removed until their brood mature; storage cannot be removed below the space occupied by current reserves. Right-click a guard marker in inspection/order mode to remove it; released guards walk out.

The underground toolbar selects these planning tools and shows used storage, usable storage capacity, brood slots, protein buffered beside brood and protein carried by nurses. Selecting a nurse shows its actual load. Surface and underground Guard orders appear only on their own layer, and the Orders panel focuses the right layer when a row is clicked.

## Rooms and individual workers

Each colony starts with nine storage tiles near its entrance and nine brood tiles beside the queen: **18,000 storage and 18 brood slots**. These are prebuilt starter facilities, not free capacity granted by later designations. Planned, unexcavated or disconnected rooms add no usable capacity. Queens retain their existing location.

The colony assigns up to **six nurses**, with a smaller crew for a small surviving workforce. Nurses carry up to **four protein units** per trip and fill local brood buffers of at most eight per tile. This internal transfer reserves existing protein; it does not create food or count as a new foraging delivery. Protein is finally spent when eggs or stage transitions consume it. A killed nurse drops its exact load, which is removed from the colony's reserves. Couriers can locally recover dropped loads inside their own tunnels and bring them to storage again. The release and recovery are included in the stock ledger.

Starter buffers are full enough to mature a first generation even if all workers are lost. A very small surviving colony keeps at least one nurse when resources allow; that worker returns to foraging during a resource emergency.

The initial 120 protein includes 72 already buffered in the starter brood chambers. The HUD's protein total includes free stock, buffers and nurse loads; the toolbar breaks out those allocations. Nutrition remains pooled across the colony rather than tracked as separate per-room inventories. An unused brood designation releases its buffer back into that pool when removed; an in-flight nurse returns a cancelled delivery to storage.

Foraging workers still carry one unit and retain its sugar/protein identity. A full store leaves arriving cargo on its carrier rather than destroying it. Brood without a connected room or enough local feed waits. Paid pupae still mature under the existing rules, and their individual newborn workers follow the real exit route.

Rival controllers use individual couriers and nursing crews, and now expand their rooms and improve routes through [automatic nest planning](NEST_PLANNING.md). Player room planning remains explicit.

## Travel and defense

Walls and stone block real movement and attacks. Storage near the entrance shortens unloading trips but sits closer to an invasion; deeper storage lengthens delivery travel. Keeping storage and brood close shortens nurse trips. Shortcuts and widened access routes change the paths ants actually walk.

Crowded tunnel cells limit incoming loaded traffic and combat movement at a threshold of **six occupants**. This is a movement/crowding rule, not rigid-body collision or a cap on every ant already sharing a tile. Empty friendly couriers, excavation crews, nurses and idle guards may squeeze past friendly queues; otherwise opposing traffic could permanently deadlock a one-cell corridor. Combatants and loaded workers still wait for space. Nest guards let the player hold a corridor or protect a vulnerable chamber approach. Narrow, protected routes and fast, broad delivery corridors have different uses.

## Implementation and validation

Workers remain individual packed-array agents. Cached multi-source route maps are shared by workers, while each worker keeps its own position, load, layer, health, opponent and job. The native kernel moves free couriers through tunnels and maintains occupancy; the GDScript reference uses the same phase ordering. Small nursing and excavation crews use real tunnel routes. Room/topology edits invalidate the shared routes; normal per-worker movement does not run a global path search.

The default remains **2,000 ants per colony / 6,000 workers**, with the existing 3,200-per-colony population cap. Storage and brood capacity are separate limits. No off-screen simulation skipping or aggregate ants were added.

`play.ps1 -Test` includes the chamber suite alongside the earlier regression suites. It checks physical sugar/protein storage trips in both kernels and all colonies; full and sealed storage; actual excavation before capacity activates; brood designation/erasure; nurse transport, local feeding and death accounting; underground hatching; crowding and queue escape; underground guards; and shorter routes after a real shortcut. The longer native/reference test covers 600 ticks with all three colonies, nursing and actual delivery trips, comparing cargo, buffers, occupancy and existing state. The main simulation ledger includes reserved nurse stock and released/recovered loads. Four older direct nutrient/combat fixtures explicitly isolate pre-chamber mechanics; the new suite and full simulation/native comparisons exercise physical logistics.

The capture test plans and completes additional rooms with real diggers, then places a nest guard post and inspects a working nurse. The recorded sample completed 22 excavated tiles, raised Amber's capacity from 18,000/18 to **36,000/36**, and produced 20 new workers by 90 simulated seconds. These are one seeded demonstration, not a balance result.

Rendered checks use the existing five-second, 1440×900 GL windows at 4×, plus an underground logistics view and a synthetic large invasion. Provisioned tests keep reserves within actual starter storage capacity (12,000 sugar and 3,000 protein), rather than bypassing the capacity rules. The invasion timing begins immediately so its real attack burst is included; the previous settled control is retained separately. The observer harness may continue after the player queen dies, and records that status. Targets remain mean at least 60 FPS, p95 at most 33.3 ms and actual simulation speed at least 3.9×.

```powershell
.\play.ps1 -Test
Godot_console.exe --path . --script res://tests/chambers_performance.gd -- --food-cycle --chambers
Godot_console.exe --path . --script res://tests/chambers_underground_performance.gd -- --food-cycle
```

## Final checks and measurements

All **19 regression suites** passed. The completed construction capture and inspector screenshots were reviewed. Full-colony native/reference checks retained a maximum observed position error of 0.000252 pixels and matching discrete worker/logistics state.

All **12 renderer windows** passed on the local RTX 4070 Ti SUPER at 1440×900 GL, VSync off, requested 4×. Each uses normal individual movement, care, excavation and combat; populations can decline through actual deaths.

| Workload | Mean FPS | p95 ms | Actual speed |
| --- | ---: | ---: | ---: |
| food_natural_0s | 176.9 | 9.64 | 4.00× |
| food_natural_90s | 176.0 | 10.48 | 4.00× |
| food_natural_120s | 190.8 | 9.57 | 4.00× |
| food_natural_240s | 198.6 | 8.81 | 3.99× |
| food_natural_360s | 213.0 | 8.34 | 4.00× |
| food_2000_panel_overview | 134.1 | 13.03 | 3.99× |
| food_2000_panel_battle | 102.1 | 18.99 | 4.00× |
| food_2000_panel_detail | 79.6 | 30.74 | 4.01× |
| food_2000_panel_arrival | 143.9 | 12.07 | 4.00× |
| underground_couriers_and_nurses | 302.4 | 5.14 | 4.00× |
| underground_active_construction | 198.4 | 8.05 | 4.01× |
| underground_large_invasion | 196.3 | 9.04 | 4.05× |

The active-construction window excavated 9 of 22 planned tiles while all three colonies continued simulating. The synthetic invasion begins with all 6,000 workers present, including 600 loaded friendly couriers and 200 enemy invaders in the same nest; the measured window includes the actual attack burst and its aftermath. It is intentionally more crowded than normal traffic, and is not a claim of five continuous seconds of unchanged combat. Its first-frame catch-up is included in the recorded 4.05× speed. The earlier control with a settled, already-resolved invasion is retained as `tests/chambers_underground_settled_control.json` and excluded from the twelve final pass windows.

These are short local workload measurements, not a guarantee that every frame stays below 16.67 ms or that another machine achieves the same result. No new win-rate balance claim is made. Screenshot files: `screenshots/chambers_planned.png`, `chambers_working.png`, and `chambers_nurse.png`.
