# Founding progression across eight seeds

Current investigation: 16 matched configurations before and after the royal preparation reserve, with real first-match outcomes and separately labeled diagnostic continuation. This is a small strategy/pacing sample, not evidence of equal branch or colony win rates. Current rules are in [Progression](PROGRESSION.md); renderer requirements are in [Performance](PERFORMANCE.md).

## Method

Seeds **81923, 404, 9973, 17, 73, 2026, 1337, 9001**, each with Amber choosing Foraging or Soldier brood. All start from twelve real workers per colony with the usual seeded local food, traits and independent rival strategies. A scripted player buys the chosen specialization when affordable, designates one actual brood chamber after reaching 80 workers, and starts the daughter when requirements are met. It issues no raids. Ordinary foraging, nursing, excavation, combat, rival construction and replenishment remain active. No workers, room cells or food are granted in these match runs.

The observer records the real first outcome at the normal fixed tick, then continues without ending the diagnostic until thirty simulated minutes or every colony has launched/lost its queen. Later launches describe feasibility, not extra wins. Completed colonies stop laying new workers under the existing rules, so continued matches are not a prediction of ordinary play beyond its actual end. Individual start/launch observations and blocking reasons are sampled every three seconds; colony snapshots/accounting are sampled every thirty seconds.

## Actual match comparison

| Measure | Before | After |
| --- | ---: | ---: |
| Foraging player wins | 5/8 | 5/8 |
| Soldier player wins | 4/8 | 4/8 |
| Unresolved matches | 0/16 | 0/16 |
| Median match length, Foraging | 713.0s | 713.0s |
| Median match length, Soldiers | 722.9s | 721.9s |
| Rival projects started before the actual match ended | 18/32 | 21/32 |

All sixteen first-winner identities stayed the same. Foraging has a modest edge in this sample; soldiers remain a viable choice. Eight seeds and a single scripted player policy cannot rank optimal human strategies. Traits and rival path choices remain linked to their usual colony/seed setup; these are not isolated trait or color experiments.

## Bottleneck and change

Nurses could continually allocate incoming protein to ordinary brood rooms, leaving too little free to pay the daughter start cost. On seed 404 with Foraging, Amber grew beyond 140 workers but never began a daughter within thirty minutes. It spent 1,083 sampled seconds waiting for twenty unallocated protein while brood continued consuming deliveries.

A specialized Founding colony with **80 living workers and 24 connected brood slots** now holds **20 existing free protein** back from new nurse loads. Surplus can still be carried; already committed loads/buffers are untouched. The hold releases when the daughter starts or workforce/nursery readiness is lost. It is cached at the three-second progression cadence and reads as a scalar in nurse allocation. No food is created, worker updates skipped, stats changed or project time shortened. The player and both rivals follow the same rule. Development shows how much start protein nurses are saving.

| Diagnostic observation through 30 minutes | Before | After |
| --- | ---: | ---: |
| Amber launches | 15/16 | 16/16 |
| Coral launches | 15/16 | 16/16 |
| Azure launches | 12/16 | 13/16 |
| Colonies never starting a daughter | 2/48 | 1/48 |
| Total sampled wait for start protein | 2,535s | 837s |
| Mean Amber start-protein wait, Foraging | 138.4s | 17.2s |
| Mean Amber start-protein wait, Soldiers | 74.6s | 11.6s |

The total start-protein wait fell **67%**. The formerly stuck seed-404 Foraging colony now began at 831s and launched at 1125s. On seed 73 with Soldiers, Amber's diagnostic launch moved from 1680s to 1194s; its actual loss to Azure remained unchanged. Seed 2026 with Foraging also let Azure finish at 1362s rather than remaining unfinished at the horizon. Conditional medians exclude unlaunched projects; use the denominators and raw records when comparing them.

## Remaining constraints

Azure has three unfinished diagnostic cases. Two began at 1680s and 1710s, leaving less than the minimum 240 fed seconds before the 1800s cutoff. The other, seed 404 with a Foraging player, repeatedly fell below 80 workers: peak workforce 82, 71 at the last snapshot, 214 combat losses and zero hunger losses. Its nursery remained at starter capacity; the brief workforce crossing did not produce a completed expansion. These are growth/construction and territorial-pressure limitations, not the fixed free-protein lock. Late projects are censored, not proven permanently stalled.

A useful later AI improvement is to anticipate nursery requirements while approaching maturity, rather than treating every brief crossing of 80 workers as enough time to plan, dig and fund the project. That should still cost actual labor and preserve the risk of losing territory. This investigation does not grant guaranteed rival growth or force equal outcomes.

## Verification and performance

All **26 rule suites** passed with no errors, including new checks that real nurse loads respect the reserve, use surplus, preserve already assigned protein, release the hold on starting/losses, and leave opening/Skirmish allocation unchanged in both kernels. Three seeded Skirmish traces at 6,000 starting workers, each 1,200 ticks / forty simulated seconds, retain **identical SHA-256 fingerprints** before/after.

All sampled match population and protein/storage accounting checks passed. All **12 full five-wall-second renderer windows** passed at requested 4x on the local RTX 4070 Ti SUPER, Godot 4.7.2 GL at 1440x900. Founding 2,000-per-colony soldier battle/detail averaged **210.1/125.8 FPS**, p95 **8.84/17.61 ms**, actual **4.00/4.01x**. The new preparation workload averaged **341.5 FPS** with p95 **6.18 ms** at **4.00x**. Skirmish battle/detail controls averaged **142.3/142.0 FPS** at **4.00/4.01x**. This meets the established mean >=60, p95 <=33.3ms and actual speed >=3.9x gate; it does not guarantee every frame at 60 FPS or performance at the growth cap.

The provided renderer fixtures explicitly supply 2,000 workers per colony and legal room/stocks to test load; natural Founding windows use earned populations. All measured windows reconcile worker states, births/losses, assigned protein and room capacity. Timing varies between sessions; the earlier eleven-window report is retained as context, not a controlled speedup claim.

## Evidence and reproduction

- [Before match data](tests/founding_progression_before.json), [after match data](tests/founding_progression_after.json), [comparison](tests/founding_progression_comparison.json).
- [Prior renderer baseline](tests/founding_progression_performance_before.json), [current renderer windows](tests/founding_progression_performance_after.json).
- [Skirmish before traces](tests/founding_progression_skirmish_before.json), [Skirmish after traces](tests/founding_progression_skirmish_after.json).
- [Preparation UI capture](screenshots/founding_progression_reserve.png): a staged fixture with supplied workers/rooms/food, separate from natural matches.

```powershell
.\play.ps1 -Test
# Use the provided Godot console executable, with --path . and a writable log:
Godot_console.exe --headless --path . --script res://tests/founding_progression_matches.gd -- --after
python tests/analyze_founding_progression.py
Godot_console.exe --path . --script res://tests/progression_performance.gd
```

The after harness and renderer overwrite their corresponding report files. Running the before command on current code cannot reconstruct the old rules; the saved before JSON is the control. Keep benchmarks separate from headless suites/other heavy workloads.
