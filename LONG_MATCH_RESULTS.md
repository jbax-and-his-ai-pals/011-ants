# Long three-colony investigation

> Historical experiment: results, suite counts and reproduction commands describe the milestone tested. Later systems can change outcomes; rerunning today does not reconstruct that version. Use [Gameplay](GAMEPLAY.md), [Performance](PERFORMANCE.md) and the [Roadmap](ROADMAP.md) for current guidance. See the [documentation index](docs/README.md) for context.

Fifteen seeded matches with a 30-simulated-minute horizon, plus real-renderer 4x windows at later match states and explicit growth/battle fixtures. No game balance settings were changed during this investigation.

## Winners

| Setup | Matches | Amber wins | Coral wins | Azure wins | Unresolved at 30 min |
| --- | ---: | ---: | ---: | ---: | ---: |
| Default unattended (original automation/traits) | 3 | 0 | 3 | 0 | 0 |
| Identical AI, all Balanced | 3 | 1 | 1 | 0 | 1 |
| Identical AI, rotated traits | 6 | 2 | 1 | 0 | 3 |
| Identical AI, Balanced, upper nests swapped | 3 | 0 | 2 | 0 | 1 |

A win requires one surviving queen. Unresolved games are not draws or worker-lead wins. These are small, deterministic seed samples, not estimates of a population-wide win probability. Mirroring swaps Amber/Coral's physical nests and reflects steering; Azure remains at the lower nest. Trait rotations use each profile once per game, across two seeds.

| Setup | Seed | Traits A / C / Z | Winner | Minutes | First queen lost |
| --- | ---: | --- | --- | ---: | --- |
| default_unattended | 81923 | Stewards / Raiders / Balanced | Coral | 16.96 | Azure |
| equal_ai_neutral | 81923 | Balanced / Balanced / Balanced | Amber | 21.11 | Azure |
| default_unattended | 7 | Stewards / Raiders / Balanced | Coral | 15.38 | Azure |
| equal_ai_neutral | 7 | Balanced / Balanced / Balanced | Unresolved | 30.00 | Azure |
| default_unattended | 42 | Stewards / Raiders / Balanced | Coral | 12.10 | Azure |
| equal_ai_neutral | 42 | Balanced / Balanced / Balanced | Coral | 28.21 | Azure |
| equal_ai_rotated_traits | 7 | Stewards / Raiders / Balanced | Unresolved | 30.00 | Azure |
| equal_ai_rotated_traits | 7 | Balanced / Stewards / Raiders | Coral | 20.71 | Azure |
| equal_ai_rotated_traits | 7 | Raiders / Balanced / Stewards | Unresolved | 30.00 | Azure |
| equal_ai_rotated_traits | 42 | Stewards / Raiders / Balanced | Amber | 17.99 | Azure |
| equal_ai_rotated_traits | 42 | Balanced / Stewards / Raiders | Unresolved | 30.00 | None |
| equal_ai_rotated_traits | 42 | Raiders / Balanced / Stewards | Amber | 28.43 | Azure |
| equal_ai_neutral_mirrored | 81923 | Balanced / Balanced / Balanced | Coral | 18.78 | Azure |
| equal_ai_neutral_mirrored | 7 | Balanced / Balanced / Balanced | Unresolved | 30.00 | Azure |
| equal_ai_neutral_mirrored | 42 | Balanced / Balanced / Balanced | Coral | 20.64 | Azure |

## Interpretation

The default unattended sample favors Coral (3/3), while equal-controller games split between Amber and Coral with several unresolved outcomes. The most repeatable concern is Azure's lower-nest disadvantage: it was first eliminated in all fourteen matches that had a queen death, including neutral and mirrored controls. The one remaining match retained all three queens at the horizon.

The current nearest-hostile-nest policy makes both upper colonies target the lower nest initially (about 723px away versus 1022px to each other). Azure's equal-distance tie chooses Amber because the candidate loop visits it first. This is a concrete two-front pressure mechanism consistent with the results; these trials do not isolate it as the only cause. Rotated profiles did not establish one universally winning trait.

Five games remained unresolved at 30 simulated minutes. One kept all queens alive; four retained Amber and Coral. Their large food reserves and continued births support prolonged skirmishing, while recovery and raid-recall decisions can interrupt attempts to finish a queen. A worker lead is insufficient evidence of an eventual winner.

Next balance experiments should address target choice/threat splitting and tie handling first, then rerun these controls before changing trait stats. Endgame tests should separately examine raid recall based on colony-wide casualties and whether stronger colonies can finish a weakened queen. No target, trait, food, brood, combat or population tuning was applied here.

## Population and pressure

| Default-match time | Mean Amber workers | Mean Coral workers | Mean Azure workers | Games observed |
| --- | ---: | ---: | ---: | ---: |
| 0 min | 2000 | 2000 | 2000 | 3 |
| 1 min | 1629 | 1724 | 1532 | 3 |
| 3 min | 993 | 1181 | 739 | 3 |
| 5 min | 573 | 868 | 393 | 3 |
| 10 min | 178 | 565 | 55 | 3 |

Peak sampled natural population: **6000**. Largest battle sampled every 15 simulated seconds: **200 workers engaged**, not a guaranteed instantaneous maximum. First queen eliminated: {'Azure': 14}. Queen death causes: {'invaders': 24}.

All recorded samples passed living-worker identity/open-tunnel checks and the population ledger: initial workers + births - combat deaths - hunger deaths = living workers. Natural trials did not establish performance at simultaneous population caps; the synthetic tests below cover that separately.

## 4x renderer windows

| Workload | Actual simulated minutes at start | Workers start/end | Mean FPS | p95 / p99 ms | Actual speed | Target met |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| natural_0s | 0.03 | 6000 / 5472 | 99.6 | 14.11 / 20.71 | 4.00x | Yes |
| natural_60s | 1.04 | 4854 / 4398 | 104.8 | 14.55 / 19.91 | 4.00x | Yes |
| natural_180s | 3.03 | 2901 / 2712 | 148.6 | 10.46 / 14.78 | 4.00x | Yes |
| natural_360s | 6.03 | 1501 / 1368 | 206.9 | 7.07 / 10.70 | 4.00x | Yes |
| natural_600s | 10.03 | 807 / 783 | 251.7 | 5.67 / 9.15 | 4.01x | Yes |
| natural_900s | 15.03 | 457 / 460 | 240.4 | 6.19 / 9.09 | 3.99x | Yes |
| growth_cap_overview | 0.05 | 9600 / 8621 | 59.2 | 23.66 / 38.27 | 4.01x | No |
| growth_cap_battle_overview | 0.05 | 9345 / 7387 | 42.7 | 36.38 / 46.99 | 4.02x | No |
| growth_cap_battle_detail | 0.04 | 9485 / 7403 | 54.6 | 38.63 / 51.25 | 4.01x | No |
| growth_cap_overview (2000/colony) | 0.03 | 6000 / 5476 | 103.2 | 14.37 / 19.86 | 4.00x | Yes |
| growth_cap_battle_overview (2000/colony) | 0.02 | 5990 / 4141 | 81.4 | 20.58 / 26.08 | 3.99x | Yes |
| growth_cap_battle_detail (2000/colony) | 0.01 | 6000 / 4145 | 90.5 | 20.40 / 26.45 | 4.01x | Yes |
| growth_cap_overview (2400/colony) | 0.03 | 7200 / 6582 | 96.0 | 15.19 / 22.85 | 4.00x | Yes |
| growth_cap_battle_overview (2400/colony) | 0.04 | 7150 / 5094 | 68.9 | 20.81 / 30.47 | 4.01x | Yes |
| growth_cap_battle_detail (2400/colony) | 0.03 | 7185 / 5097 | 78.6 | 25.75 / 31.98 | 4.00x | Yes |

Rendering-only follow-up batches minimap dots and fallen-ant markers and builds the pheromone texture in native code. All workers, corpses, fading and scent fields retain their existing semantics; the appearance tests check individual positions/colors and texture quantization. Baseline frame reports before these changes are retained in long_performance_baseline.json, long_performance_2000_baseline.json and long_performance_2400_baseline.json.

Targets: 60 mean FPS, p95 <=33.3ms, and >=3.9 simulated seconds per wall second at requested 4x. Each live window lasts at least five wall seconds, unless the match resolves first (complete_window records this). Natural checkpoints advance using every fixed simulation tick between renderer windows, so this is longitudinal sampling, not a continuous real-time recording of the whole match.

Growth fixtures explicitly spawn through the real worker-creation path to the stated target (up to 3,200 workers per colony / 9,600 total) and provision food; they are not natural growth observations. The battle fixture arranges 600 foragers per colony approaching shared food and retains normal sensing, cargo, damage, retreat and deaths. No invulnerability or population deletion is used. View and population changes during sampling are recorded.

These local measurements use Godot 4.7.2 GL Compatibility, RTX 4070 Ti SUPER, 1440x900, VSync requested off. Other test/game sessions from this chat were stopped before timing. Frame-time summaries, tick phase timings and state samples are in the raw reports.

## Reproduce

```powershell
# Use the provided Godot_console.exe with --path . and a writable --log-file.
Godot_console.exe --headless --path . --script res://tests/long_balance.gd
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --mirrors-only
# Run timing separately from all other test processes:
Godot_console.exe --path . --script res://tests/long_performance.gd --resolution 1440x900
Godot_console.exe --path . --script res://tests/long_performance.gd --resolution 1440x900 -- --growth-only --target=2000
Godot_console.exe --path . --script res://tests/long_performance.gd --resolution 1440x900 -- --growth-only --target=2400
python tests/analyze_long_runs.py
```

The observer harness continues after Amber's ordinary defeat only to determine the last surviving queen. game_result/game_end_seconds preserve the normal player's end point; no product outcome rules change. The equal-AI control gives Amber the existing rival strategy and suppresses its separate legacy automatic raid timer. There is no scripted human player or strategic digging in these matches.

Raw reports: tests/long_balance_results.json, tests/long_balance_mirrors.json, tests/long_performance_results.json, long_performance_2000_results.json and long_performance_2400_results.json. Worker/queen timelines and frame-time summaries are retained in JSON; compact per-match/window CSVs and long_match_summary.json are generated alongside this report.
