# Founding progression

Founding now races to raise and launch a daughter queen. Skirmish retains its existing population, economy, traits, orders, AI raid rules and queen-elimination objective. Press **P** or **Development** in Founding to choose a specialization and track the objective. Planning and purchases work while paused; development advances only with simulation time.

## Choose a path

At 40 living workers, choose one specialization for this match. Both cost **40 sugar + 12 unallocated protein**, while preserving 30 seconds of ordinary upkeep. Protein already assigned to room buffers or nurse loads cannot be spent twice.

| Path | Benefit | Tradeoff |
| --- | --- | --- |
| Foraging | +15% unloaded surface forage speed, stacking with existing traits and terrain | No benefit while carrying, fighting or doing other jobs |
| Soldier brood | Every fifth egg laid after choosing is a soldier | Four extra protein at pupation and +0.004 sugar upkeep/second per living soldier, before trait multipliers |

Soldiers hatch from paid brood at its actual nursery tile. Existing workers and existing eggs do not convert. Soldiers have **5 HP and x1.5 bite**, retain individual identity/RNG, and appear 35% larger. Their caste is independent of their current job: they can work while idle and receive Guard/Raid/other assignments. Security recruitment prefers available soldiers; carriers finish delivery. Recovery begins at 40% of maximum health and restores the soldier's own five-HP maximum using the existing home healing rules. The ant inspector identifies caste, maximum health and bite.

The automatic production mix keeps a general workforce; there is no individual ant upgrade menu or additional permanent caste tree yet. The specialization resets with the match.

## Raise a daughter queen

Starting requires the specialization, **80 living workers**, **24 connected brood slots**, one empty brood tile, no nest intruders, **60 sugar plus 60 seconds of upkeep**, and **20 unallocated protein**. Expand with the existing **9** chamber tool; workers must really excavate and connect the room.

Once a specialized colony has 80 living workers and 24 connected brood slots, nurses leave up to 20 unallocated protein for the start payment. They can carry any surplus and retain all loads already committed. This hold is cached every three simulated seconds, releases when the project starts or readiness is lost, and creates no food. The panel shows progress toward the 20-protein reserve.

The daughter occupies an actual nursery tile, reserving its two worker-brood slots. The interface prevents removing that occupied designation. New worker egg laying pauses while raising her; existing worker brood continues developing. This makes the project a commitment of resources and growth, not an extra free production queue.

Development needs **240 fed simulated seconds**, in thirty eight-second installments. Each installment consumes **6 sugar and 4 protein physically delivered to her tile by nurses**. Total project spending is **240 sugar and 140 protein**, including the start payment, plus ordinary colony upkeep. Local buffers and carried nurse loads remain included in the global protein bank.

Sugar reserves below the installment plus 30 seconds of upkeep (minimum eight sugar), a disconnected/removed room, or an actual nest breach pause development. Missing local protein waits for a nurse. These pauses do not accumulate a burst of catch-up progress. Previously earned progress remains. The nest view shows the daughter and development ring; the panel names egg, larva, pupa and launch stages and the current blocking reason.

The first daughter launch wins. A living rival launching first loses the match for Amber; simultaneous launches draw. Home queen death still loses; all home queens dying together draws. Killing the rival queens alone does not finish Founding: the surviving colony still needs to launch its daughter. Results freeze the simulation as before.

## Rivals and information

Both rivals buy a specialization, begin planning a needed nursery from 60 workers with a six-digger preparation crew, expand brood rooms and begin their own daughter when they meet the same requirements. Their path choice is deterministic from the map seed and colony, without consuming worker RNG. Nest expansion uses the existing planner, real diggers and shared labor. The Development panel shows rival path and daughter stage as public sandbox information, consistent with existing queen/AI diagnostics; this is not a full fog-of-war mode.

## Verification

`play.ps1 -Test` includes `tests/progression_test.gd`: purchase gates/accounting, exclusivity, paid soldier births, both-kernel worker movement/RNG, contact combat, larger-body rendering, recovery, royal room reservation, real nurse-fed launch, interrupted development, rival outcomes and reset/Skirmish isolation.

`tests/progression_skirmish_trace.gd` records three seeds x 1,200 ticks / 40 simulated seconds at the full 6,000-worker start. The before/after SHA-256 fingerprints match exactly, covering simulation arrays, food, brood, rooms, orders, strategy and individual RNG streams. Data: [before](tests/progression_skirmish_before.json), [after](tests/progression_skirmish_after.json).

[Two natural runs](tests/progression_natural_runs.json) use seed 81923 and a scripted player choosing each branch, designating one real room and starting the daughter as soon as ready. All workers, food and excavation are earned; no resource grants or artificial population increases. The player does not issue raids. Foraging chose at 183s, began its daughter at 345s and won at 634.3s. Soldier production chose at 183s, began at 348s and lost to Coral at 708.0s with Amber at 232/240 fed seconds. These demonstrate an attainable, contested loop, not balanced branch win rates.

Reproduce those runs with `Godot_console.exe --headless --path . --script res://tests/progression_long.gd`. The harness overwrites its JSON report. Renderer measurements and their limits belong in [Performance](PERFORMANCE.md).

[Development choice](screenshots/progression_choice.png), [daughter nursery](screenshots/progression_daughter.png) and [soldier inspector](screenshots/progression_soldier.png) are staged UI fixtures with explicitly supplied workers, food and room cells; they are separate from the natural runs above.

The original progression milestone passed 25 suites and 11 full renderer windows. Current cross-seed verification is recorded in [Founding progression results](FOUNDING_PROGRESSION_RESULTS.md) and [Performance](PERFORMANCE.md). In the provisioned 2,000-per-colony Founding battle/detail cases, mean FPS was 227.8/136.4 with p95 7.50/16.80 ms at actual 4.00x. Reproduce with `Godot_console.exe --path . --script res://tests/progression_performance.gd`. Full workload populations and limits are in [Performance](PERFORMANCE.md).
