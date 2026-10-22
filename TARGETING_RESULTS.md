# Target selection: paired before/after results

> Historical experiment: results, suite counts and reproduction commands describe the milestone tested. Later systems can change outcomes; rerunning today does not reconstruct that version. Use [Gameplay](GAMEPLAY.md), [Performance](PERFORMANCE.md) and the [Roadmap](ROADMAP.md) for current guidance. See the [documentation index](docs/README.md) for context.

The same fifteen seeded, three-colony matches were replayed for up to 30 simulated minutes each. Starts remain 2,000 workers per colony. Map, food, traits, individual worker rules, brood and raid-loss thresholds are unchanged. This comparison changes colony target selection and adds explanations; it does not attempt endgame or map balance tuning.

## Outcomes

Wins require a sole surviving queen. An unresolved match is censored at the horizon, not a draw or a worker-lead win. These small deterministic samples do not estimate general win probabilities.

| Setup | Before wins A/C/Z | After wins A/C/Z | Before unresolved | After unresolved |
| --- | --- | --- | ---: | ---: |
| default_unattended | 0 / 3 / 0 | 0 / 3 / 0 | 0 | 0 |
| equal_ai_neutral | 1 / 1 / 0 | 3 / 0 / 0 | 1 | 0 |
| equal_ai_rotated_traits | 2 / 1 / 0 | 3 / 1 / 0 | 3 | 2 |
| equal_ai_neutral_mirrored | 0 / 2 / 0 | 1 / 1 / 0 | 1 | 1 |

First queen eliminated before: **{'Azure': 14}**, in 14 matches with a queen loss. After: **{'Azure': 9, 'Amber': 3, 'Coral': 2}**, in 14 such matches.

| Setup / seed / traits | Before winner / min | After winner / min | First eliminated before / after |
| --- | --- | --- | --- |
| default_unattended / 81923 / [1, 2, 0] | Coral / 16.96 | Coral / 15.87 | Azure / Azure |
| equal_ai_neutral / 81923 / [0, 0, 0] | Amber / 21.11 | Amber / 20.11 | Azure / Azure |
| default_unattended / 7 / [1, 2, 0] | Coral / 15.38 | Coral / 22.27 | Azure / Amber |
| equal_ai_neutral / 7 / [0, 0, 0] | Unresolved / 30.00 | Amber / 21.04 | Azure / Azure |
| default_unattended / 42 / [1, 2, 0] | Coral / 12.10 | Coral / 16.22 | Azure / Azure |
| equal_ai_neutral / 42 / [0, 0, 0] | Coral / 28.21 | Amber / 23.36 | Azure / Azure |
| equal_ai_rotated_traits / 7 / [1, 2, 0] | Unresolved / 30.00 | Unresolved / 30.00 | Azure / Azure |
| equal_ai_rotated_traits / 7 / [0, 1, 2] | Coral / 20.71 | Coral / 18.03 | Azure / Amber |
| equal_ai_rotated_traits / 7 / [2, 0, 1] | Unresolved / 30.00 | Unresolved / 30.00 | Azure / None |
| equal_ai_rotated_traits / 42 / [1, 2, 0] | Amber / 17.99 | Amber / 20.35 | Azure / Coral |
| equal_ai_rotated_traits / 42 / [0, 1, 2] | Unresolved / 30.00 | Amber / 19.04 | None / Coral |
| equal_ai_rotated_traits / 42 / [2, 0, 1] | Amber / 28.43 | Amber / 28.43 | Azure / Azure |
| equal_ai_neutral_mirrored / 81923 / [0, 0, 0] | Coral / 18.78 | Coral / 23.25 | Azure / Amber |
| equal_ai_neutral_mirrored / 7 / [0, 0, 0] | Unresolved / 30.00 | Unresolved / 30.00 | Azure / Azure |
| equal_ai_neutral_mirrored / 42 / [0, 0, 0] | Coral / 20.64 | Amber / 22.11 | Azure / Azure |

Target choice is less automatic, and Azure is no longer invariably eliminated first. However, Azure still wins none of these matches; this is an improvement to target selection, not a balanced-map claim. Coral still wins all three default unattended matches. Amber now sweeps the three neutral, equal-AI seeds, while the mirrored neutral cases split one win each between Amber and Coral plus one unresolved game. That sensitivity argues for continued position/route and endgame tests before tuning trait bonuses. The sample reuses three world seeds across configurations; the fifteen outcomes are not fifteen independent random worlds.

## What changed

The previous nearest-nest policy initially sent both upper colonies toward Azure, and Azure's exact distance tie selected Amber by colony ID. The new policy weighs threats at home, current observed competition on chosen food routes, public worker strength and queen health, with a smaller travel term. Comparable candidates use a separate seeded RNG; this never consumes worker random streams. Targets have a 30-second commitment and a 0.18 switching margin. Living active raid targets remain fixed, and eliminated targets cancel their raid with the existing cooldown.

Press I / Switch colony for target and holding/switching reason plus every candidate's score components. Preference does not imply a raid is currently affordable: the mode still reports defense/recovery/resource constraints. Details and weights are in RIVAL_AI.md.

Default unattended trials retain Amber's original nearest-nest automation and asymmetric traits. Equal-controller cases give all three colonies the new strategy. The physical map, food placement and ordinary forager contacts can still disadvantage the lower nest even when strategic raid targets are fairer. No protective bonuses or scripted win rotation were added.

All sampled worker ledgers, unique worker IDs and open-tunnel checks passed. Native/reference regressions preserve individual movement, cargo, scent, combat, recovery and RNG semantics. Target scores/reasons and preferences are included in each new 15-second census.

## Opening target choices

The first 15-second census below shows preferences, not necessarily active raids. The old policy's opening targets were A→Z, C→Z, Z→A in every case. Amber remains A→Z in default unattended trials.

| Setup / seed / traits | New preferred targets A / C / Z |
| --- | --- |
| default_unattended / 81923 / [1, 2, 0] | Azure / Amber / Amber |
| equal_ai_neutral / 81923 / [0, 0, 0] | Coral / Amber / Amber |
| default_unattended / 7 / [1, 2, 0] | Azure / Azure / Coral |
| equal_ai_neutral / 7 / [0, 0, 0] | Coral / Azure / Coral |
| default_unattended / 42 / [1, 2, 0] | Azure / Azure / Coral |
| equal_ai_neutral / 42 / [0, 0, 0] | Azure / Azure / Coral |
| equal_ai_rotated_traits / 7 / [1, 2, 0] | Coral / Azure / Coral |
| equal_ai_rotated_traits / 7 / [0, 1, 2] | Coral / Azure / Coral |
| equal_ai_rotated_traits / 7 / [2, 0, 1] | Coral / Azure / Coral |
| equal_ai_rotated_traits / 42 / [1, 2, 0] | Azure / Azure / Coral |
| equal_ai_rotated_traits / 42 / [0, 1, 2] | Azure / Azure / Coral |
| equal_ai_rotated_traits / 42 / [2, 0, 1] | Azure / Azure / Coral |
| equal_ai_neutral_mirrored / 81923 / [0, 0, 0] | Coral / Amber / Amber |
| equal_ai_neutral_mirrored / 7 / [0, 0, 0] | Coral / Azure / Coral |
| equal_ai_neutral_mirrored / 42 / [0, 0, 0] | Azure / Azure / Coral |

Both upper colonies preferred Azure in **15/15** openings under the old rule and **7/15** first censuses after the change. Azure now preferred Amber in 3 and Coral in 12; the old exact tie always preferred Amber. These are preferences at 15 seconds, not successful raid counts or a guarantee against later two-front pressure.

## Real renderer at 4×

Timing was run separately after all balance/regression jobs finished. Same renderer, resolution and workload harness as before. Natural checkpoints run all fixed ticks between live windows; stress fixtures explicitly provision/spawn real workers and arrange normal foragers around shared food. No skipped workers, invulnerability or population deletion.

| Workers/colony, workload | Before FPS | After FPS | After p95 ms | Actual speed | Target met |
| --- | ---: | ---: | ---: | ---: | --- |
| 2000, natural_0s | 99.6 | 107.4 | 13.65 | 4.00× | Yes |
| 2000, natural_60s | 104.8 | 109.8 | 13.88 | 4.01× | Yes |
| 2000, natural_180s | 148.6 | 167.2 | 9.31 | 4.01× | Yes |
| 2000, natural_360s | 206.9 | 219.9 | 6.81 | 4.01× | Yes |
| 2000, natural_600s | 251.7 | 251.1 | 5.83 | 4.00× | Yes |
| 2000, natural_900s | 240.4 | 259.6 | 5.35 | 4.00× | Yes |
| 2000, growth_cap_overview | 103.2 | 102.0 | 13.96 | 4.01× | Yes |
| 2000, growth_cap_battle_overview | 81.4 | 75.3 | 21.56 | 4.00× | Yes |
| 2000, growth_cap_battle_detail | 90.5 | 85.5 | 22.45 | 3.99× | Yes |
| 2400, growth_cap_overview | 96.0 | 86.6 | 17.18 | 4.01× | Yes |
| 2400, growth_cap_battle_overview | 68.9 | 59.8 | 24.97 | 4.01× | No |
| 2400, growth_cap_battle_detail | 78.6 | 69.7 | 25.86 | 4.01× | Yes |

At the default 2,000/colony population, **9/9 windows pass**. The optional 2,400/colony battle overview is borderline at 59.8 FPS in this batch and misses the strict 60 mean target, despite maintaining full simulation speed. Earlier historical timing was faster; no claim is made that target selection improves FPS. Keep the default at 2,000/colony for the validated margin.

Performance target: ≥60 mean FPS, p95 ≤33.3ms, actual speed ≥3.9×. Natural windows after time zero contain changed battles and populations and are not identical workloads; synthetic fixtures provide the closer capacity comparison. Historical 3,200/colony stress results remain below 60 FPS; this milestone makes no new claim at that cap.

## Reproduce

Use the supplied Godot console executable, --path . and an absolute writable --log-file. Run timing separately from other benchmarks:

```powershell
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --targeting
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --targeting --mirrors-only
Godot_console.exe --path . --script res://tests/long_performance.gd -- --targeting --target=2000
Godot_console.exe --path . --script res://tests/long_performance.gd -- --targeting --growth-only --target=2400
./play.ps1 -Test
python tests/analyze_targeting.py
```

The observer alone continues past the player's ordinary defeat to identify the last surviving queen. Each report retains the ordinary game result/time too. Original reports remain under long_balance* / long_performance*; new reports are targeting_balance* / targeting_performance*. The policy was fixed before the paired batch; no tuning to favor individual benchmark seeds was performed.
