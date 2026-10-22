# Balance investigation and initial colony traits

> Historical experiment: results, suite counts and reproduction commands describe the milestone tested. Later systems can change outcomes; rerunning today does not reconstruct that version. Use [Gameplay](GAMEPLAY.md), [Performance](PERFORMANCE.md) and the [Roadmap](ROADMAP.md) for current guidance. See the [documentation index](docs/README.md) for context.

Before/after target-selection follow-up: [TARGETING_RESULTS.md](TARGETING_RESULTS.md). The earlier fixed-policy baseline remains below.

Original three-colony findings (15 matches, including identical-AI, trait-rotation and mirrored controls): [LONG_MATCH_RESULTS.md](LONG_MATCH_RESULTS.md). Coral won 3/3 default unattended games; Azure was first eliminated in all 14 games with a queen death. Five games were unresolved at 30 simulated minutes. No balance tuning was applied in that investigation.

These measurements describe the **pre-invasion, original 78 × 42 map** combat and nursery pass. They are historical data, not balance measurements for the new 234 × 126 map or its 2,000-worker colonies. The diagnostic disables invasions but uses the current map if re-run. Recorded whole-match invasion results in `tests/warfare_results.json` also predate the enlargement; they are smoke checks, not a balance study.

The original repeat-win observation was reproducible. With the old rules, six seeds were run for six simulated minutes without digging. Red had more workers in **five** runs; one tied. The original default seed (81923) ended with **0 amber workers and 38 red workers**. Raw historical results are in `tests/balance_baseline.json`.

## Concrete issues corrected

1. **Reset replayed seed 81923.** The interactive New seed button now starts a different seeded world. The current seed appears under the surface view. Tests still accept explicit seeds for repeatable runs.
2. **Attack reach was tested against mixed-time positions.** Ants moved one by one; red normally processed after amber, so a red ant could move into reach and attack after amber had already tested its range. Simultaneous damage alone did not fix that. Workers now choose encounters from one starting snapshot, move, then test attack reach for both sides, followed by simultaneous damage. A regression test covers the exact first-contact distance that previously gave the later ant the only hit.
3. **Sequential antenna comparisons favored one turn in near ties.** Both antenna strengths are now compared together; near ties preserve heading. A left/right reflection property test guards the steering rule.
4. **One shared random stream coupled the colonies.** Workers now have independent seeded streams. Colony order alternates for shared food pickup, including workers born into new array slots.

No difficulty scaling, hidden red-only handicap, or forced outcome is used. Color and doctrine are separate properties. Both trait buttons can be edited live.

## Diagnostic runs

The optional neutral batch uses six seeds (81923, 81924, 7, 42, 137, 2026), normal and swapped nest positions, Balanced traits, and disabled nursery/upkeep simulation to isolate the original foraging/combat contest. Each run lasts 360 simulated seconds. Results are saved in `tests/balance_after.json`.

| Worker lead after six minutes | Amber | Red | Tied |
| --- | ---: | ---: | ---: |
| Original rules, six unswapped runs | 0 | 5 | 1 |
| Corrected rules, twelve paired neutral runs | 5 | 6 | 1 |

This is a small diagnostic sample, **not proof of equal win rates**. In the neutral sample, the right-hand nest led nine runs, the left-hand nest two, with one tie. That is a reason for larger position-stratified trials before claiming positional balance. Mirrored runs can diverge over time through floating-point movement and thresholded scent sensing; the simulation is stochastic and has strong recruitment/combat feedback. The measured color totals alone should not be used to dismiss possible remaining map effects.

The initial ecology batch adds queens, brood, upkeep, amber Stewards and red Raiders. It uses seeds 81923, 81924, and 7 with both nest positions for six runs. **Amber led three and red led three** at six minutes. Results, including births and queen health, are in `tests/balance_ecology.json`. A worker lead is not a final victory: a surviving queen and brood can still rebuild.

Run either diagnostic separately from the ordinary test suite:

```powershell
& 'C:\path\to\Godot_console.exe' --headless --path . --script res://tests/balance_trial.gd
& 'C:\path\to\Godot_console.exe' --headless --path . --script res://tests/balance_trial.gd -- --ecology
```

## Distinct colony identities

**Stewards** prioritize food delivery and nursery investment: +8% foraging speed, 15% shorter egg-laying/development times, and 7 food per worker instead of 8. Loaded carriers only engage within contact range, continuing home rather than chasing nearby enemies. They have standard bite damage and upkeep.

**Raiders** pursue enemies farther (34px instead of 30px), including while carrying food, and bite 5% harder. They pay 15% higher upkeep and use standard brood timing and feeding costs. The bite bonus is deliberately modest: health thresholds make even small damage changes matter.

**Balanced** uses the baseline values. Set both buttons to Balanced to remove doctrine differences, or swap Stewards/Raiders between the colonies. Live profile changes affect current behavior and development rates; they do not retroactively refund food.

This pass establishes testable economic and behavioral tradeoffs. Further tuning should compare harvest, time spent carrying versus fighting, replacement rate, starvation, and queen survival across more seeds and positions. The newer invasion system lets both colonies raid through tunnel entrances and ends the match on queen death; the older worker-lead measurements do not establish balance for that new objective.

The default three-colony map now uses a compact equilateral nest layout with equal local supplies and pairwise contested food sites. The paired map investigation, including mixed balance outcomes, the retained wide-layout trial, seat controls, and fresh 4× measurements is in [MAP_BALANCE_RESULTS.md](MAP_BALANCE_RESULTS.md).
