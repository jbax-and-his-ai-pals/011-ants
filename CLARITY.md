# Colony clarity

Shared observation panels explain the existing simulation in both modes. Founding also has a persistent objective tracker and earlier rival nursery preparation. Skirmish simulation rules remain unchanged.

## Events [E]

The history retains the latest **96** dated events, five per page. Click an entry to focus its recorded position and surface/nest layer. It never follows an unseen moving enemy. Entries may be stale; current raid warnings remain in the existing scouting banner.

Events cover observed food discoveries/depletion, public forecast locations and scheduled arrivals, observed incoming raids and home-nest breaches, your queen dropping below half health, specialization readiness/choice, daughter readiness/start/stages/launch and the actual match outcome. Hidden food quantities and unobserved rival intentions are not added. Enemy daughter milestones are not streamed as private intelligence. Forecast notices report the public schedule, not unseen live stock.

Repeated conditions are coalesced. Deduplication keeps at most 128 keys; history is bounded even during long matches. Events use simulated time, freeze with simulation, and reset on a new match. Player planning while paused can still create development events at the frozen timestamp.

## Work report [B] and Orders [O]

B summarizes available workers, loaded foragers, nurses and unallocated protein. Click a logistics/order row to inspect its actual location. O keeps all eight possible orders, their assigned ants, delivered sugar/protein and recent losses, with a visible third line explaining current work. Hover for the full explanation.

Explanations distinguish priority Off, Avoid conflicts, depleted sites, announced supplies, a tiny marked-forage budget, a shared security budget consumed by earlier posts, competing routes, and workers busy carrying/fighting/doing other jobs. Active guards do not become stalled simply because there is no enemy nearby.

Excavation reports queued tiles, assigned diggers and soil targets; it distinguishes paused digging, unavailable crews, travelling workers and missing connected work faces. Storage reports real connected capacity, full stores and sampled plans still awaiting excavation/connection. Brood reports connected slots, sugar/protein shortages, nurse delivery delays, the worker-egg pause during daughter development and the daughter's actual local protein buffer.

These are explanations, not new allocation rules or guaranteed completion estimates. Normal sensing and orders continue unchanged. Work-face and extra-room checks inspect at most **128** queued/designated tiles per observation; a large plan's message explicitly refers to the checked section rather than claiming a full reachability proof. O exposes explanations for every order; B shows up to six logistics/order rows.

## Founding objective tracker

The persistent clickable tracker shows the next requirement:

1. **Specialize:** workforce progress toward 40 and the current purchase requirement. Click opens Development [P].
2. **Expand nursery:** actual connected brood slots toward 24 and workforce toward 80. Click focuses your nest and selects brood designation [9]. Soil plans grant no capacity until workers dig and connect them.
3. **Prepare daughter:** living workers, unallocated start protein and the specific blocking requirement. Click opens Development.
4. **Raise daughter:** fed seconds/percentage and current development status. Click focuses her real tile and opens Development.

The tracker updates for paused planning too. It yields to overlapping order/scouting/labor panels and the result dialog. E/B/P/T/I/L/O panels close conflicting overlays; Escape restores inspection.

## Rival nursery anticipation

A specialized Founding rival can plan its 24-slot daughter nursery from **60 workers**, using the existing project cooldown, sugar/protein checks, connected routing and stone avoidance. This preparation project uses **Low excavation: at most six real diggers** until completion, preserving the small colony's foraging workforce. It still needs 80 workers and all ordinary resources/space to begin a daughter.

Other construction policies remain available. Skirmish does not use this anticipation or the special crew cap. No population, food, stats, chamber capacity or construction completion is granted.

## Implementation and checks

`colony_clarity.gd` samples at the existing 0.8-simulated-second allocation/observation boundary; UI refreshes use cached summaries. It scans the player's worker slots once per sample, not every ant every tick. Food/development lifecycle hooks append bounded events without changing worker state or RNG. Paused panels may refresh read-only summaries while simulation time remains frozen.

`tests/clarity_test.gd` checks simulation/RNG isolation, bounded memory, hidden-food/depletion privacy, actual history-row focus/layers, tracker actions, stalled-work explanations, overlays, and real six-digger nursery construction in both kernels. UI captures are staged fixtures, separate from natural match evidence: [events](screenshots/clarity_events.png), [work](screenshots/clarity_work.png), [eight orders](screenshots/clarity_orders.png), [objective](screenshots/clarity_objective.png).

Current measured evidence belongs in [Clarity results](CLARITY_RESULTS.md) and [Performance](PERFORMANCE.md).
