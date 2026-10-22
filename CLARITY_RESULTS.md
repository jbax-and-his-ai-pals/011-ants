# Clarity milestone verification

The shared history/work panels observe existing behavior. Only Founding rival nursery anticipation changes strategy: a specialized rival can plan from sixty workers, using a six-worker preparation crew. Skirmish rules and individual simulation remain unchanged. See [Clarity](CLARITY.md) for current controls and implementation bounds.

## Rule and interface checks

The full **27-suite** run passed without errors. Focused checks cover bounded 96-event/128-key memory, unseen-food/depletion privacy, stable recorded event focus and nest layers, objective actions, paused planning, visible order explanations, overlay input and result-dialog priority. Both kernels exercise actual early rival excavation and the six-digger limit. Three seeded, 1,200-tick Skirmish traces at 6,000 initial workers retain identical SHA-256 fingerprints: [before](tests/clarity_skirmish_before.json), [after](tests/clarity_skirmish_after.json).

Screenshots are staged UI fixtures with explicitly supplied workers/stores and example observations, separate from natural matches: [history](screenshots/clarity_events.png), [work report](screenshots/clarity_work.png), [all eight orders](screenshots/clarity_orders.png), [Founding tracker](screenshots/clarity_objective.png).

## Eight-seed Founding comparison

The baseline is the previous royal-preparation revision. The final version repeats seeds **81923, 404, 9973, 17, 73, 2026, 1337, 9001**, each with a scripted Amber choosing Foraging or Soldiers. The player queues one real brood chamber at eighty workers and starts its daughter when affordable; it issues no raids. All growth, food, construction, nursing and combat are earned. Both rivals remain independently active. No workers, room cells, resources or stat bonuses are granted.

The real first outcome is recorded, then an explicitly diagnostic continuation watches other colonies through thirty simulated minutes or until all launch/lose their queens. Later launches are not additional wins and are sampled every three seconds. Completed colonies stop worker egg laying, so post-match continuation is a feasibility check with changing pressure, not ordinary gameplay after its end. The methods match the [preceding progression investigation](FOUNDING_PROGRESSION_RESULTS.md).

| Measure | Before | Final clarity version |
| --- | ---: | ---: |
| Player Foraging wins | 5/8 | 7/8 |
| Player Soldier wins | 4/8 | 5/8 |
| Unresolved actual matches | 0/16 | 0/16 |
| Coral projects started before match ended | 11/16 | 12/16 |
| Azure projects started before match ended | 10/16 | 11/16 |
| Coral diagnostic launches by 30 minutes | 16/16 | 16/16 |
| Azure diagnostic launches by 30 minutes | 13/16 | 14/16 |
| Coral median diagnostic launch | 963.0s | 882.0s |
| Azure median diagnostic launch | 936.0s | 859.5s |

Thirteen first-winner identities stayed the same; three changed. Nursery preparation makes rivals ready sooner on average, but does not establish stronger AI or equal branch/color win rates. Earlier construction changes real foraging and encounter timing, including opportunities for Amber. Eight seeds and one scripted player policy are a small sample, not optimal human play or isolated trait controls.

One Azure colony (seed 404, Foraging player) built its nursery but repeatedly fell below eighty workers and could not fund a daughter start by the horizon. It had zero hunger losses and 202 combat losses at the last snapshot. Another (seed 2026, Foraging player) only started at 1788 seconds, too late for the minimum 240 fed seconds before the cutoff. Late/incomplete projects are censored, not proven permanently stalled.

All **32** before/after configurations reconcile sampled population, allocated protein and storage capacity. Histories never exceeded 96 entries. In the final natural runs, the largest recorded clarity observation pass was **0.252 ms**; this is not the full-population renderer cost.

Evidence: [before](tests/clarity_matches_before.json), [final runs](tests/clarity_matches_after.json), [comparison](tests/clarity_comparison.json). The incomplete [full-crew rehearsal](tests/clarity_fullcrew_trial.json) is retained separately; it is not included in the paired table. The existing High excavation setting could divert 24 of sixty founders, so the final anticipatory project uses Low/six diggers.

## Renderer checks

Renderer evidence and the current table are maintained in [Performance](PERFORMANCE.md). The clarity harness opens a full 96-entry history or the work report during supplied stress fixtures, with the Founding tracker visible where appropriate. All workers retain 30 updates per simulated second at requested 4x; no offscreen skipping or population reduction is used. Natural checkpoints are 0/180/360/540 seconds to avoid measuring a daughter launch boundary as a shortened window.

An initial overview battle window failed (41.3 mean FPS, p95 80.04 ms); its [raw report](tests/clarity_performance_initial.json) remains available. Inspection also found the harness showing Orders and History simultaneously, unlike normal exclusive-panel interaction; that setup was corrected. The slow spike did not reproduce in four isolated battle windows: closed panels 163.7 FPS, history 156.3 FPS, work 163.1 FPS, repeated history 162.5 FPS. All four passed frame-time and actual-speed gates. [Diagnostic report](tests/clarity_diagnostic.json). This does not attribute the original spike to a proven cause or guarantee every frame at 60 FPS.

The final complete renderer rerun passed **all twelve windows**: dense battle views averaged **134.1–228.5 FPS**, worst p95 across all windows was **19.70 ms**, and actual progression ranged **3.99–4.03x**. The largest recorded observation pass was **1.145 ms**. See [clarity_performance.json](tests/clarity_performance.json). Hardware, measured populations and gate limits are documented in Performance.

## Reproduce

```powershell
.\play.ps1 -Test
# Use the supplied Godot console executable, --path ., and a writable log:
Godot_console.exe --headless --path . --script res://tests/founding_progression_matches.gd -- --clarity
python tests/analyze_founding_progression.py --clarity
Godot_console.exe --path . --script res://tests/progression_performance.gd -- --clarity
Godot_console.exe --path . --script res://tests/clarity_diagnostic.gd
```

These overwrite their respective current after/renderer reports. The saved baseline is the earlier code's evidence; rerunning current code cannot reconstruct it. Keep renderer measurements separate from headless suites and other heavy work. Other Godot projects are left untouched.
