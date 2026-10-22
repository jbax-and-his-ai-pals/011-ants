# Raid commitment and stalled endgames

> Historical experiment: results, suite counts and reproduction commands describe the milestone tested. Later systems can change outcomes; rerunning today does not reconstruct that version. Use [Gameplay](GAMEPLAY.md), [Performance](PERFORMANCE.md) and the [Roadmap](ROADMAP.md) for current guidance. See the [documentation index](docs/README.md) for context.

The same fifteen compact-map configurations were replayed with the same seeds, traits, 2,000 starting workers per colony and 30-simulated-minute horizon. Map/food, worker stats, movement, combat, pheromones, recovery, brood and upkeep are unchanged. Only AI target preference/raid commitment and the optional recruitment budget carried by its commands change.

## Paired results

Unresolved matches: **6 → 0**. Of the previously stalled matches, **6 now resolve**; **0 formerly resolved matches now stall**. Mean observed duration, capped at the same 1,800-second horizon, changes from **20.72 to 10.38 simulated minutes**. Censored matches remain included at the horizon; they are not silently dropped from that mean.

| Setup | Before wins A/C/Z | After wins A/C/Z | Unresolved before / after |
| --- | --- | --- | --- |
| default_unattended | 0/3/0 | 0/3/0 | 0 / 0 |
| equal_ai_neutral | 0/1/0 | 1/2/0 | 2 / 0 |
| equal_ai_rotated_traits | 0/3/1 | 1/3/2 | 2 / 0 |
| equal_ai_neutral_mirrored | 0/1/0 | 2/1/0 | 2 / 0 |

Overall wins A/C/Z: **[0, 8, 1] → [4, 9, 2]**. First queen lost before: {'Amber': 6, 'Azure': 5}, in 11 matches with queen deaths; after: {'Azure': 10, 'Amber': 4, 'Coral': 1}, in 15. Faster completion does not establish fair colony win rates. This small deterministic sample reuses three world seeds across configurations.

| Setup / seed / traits | Before winner / min | After winner / min |
| --- | --- | --- |
| default_unattended / 81923 / [1, 2, 0] | Coral / 12.98 | Coral / 10.64 |
| equal_ai_neutral / 81923 / [0, 0, 0] | Coral / 21.38 | Coral / 17.09 |
| default_unattended / 7 / [1, 2, 0] | Coral / 14.31 | Coral / 8.99 |
| equal_ai_neutral / 7 / [0, 0, 0] | Unresolved / 30.00 | Coral / 11.09 |
| default_unattended / 42 / [1, 2, 0] | Coral / 25.88 | Coral / 10.49 |
| equal_ai_neutral / 42 / [0, 0, 0] | Unresolved / 30.00 | Amber / 10.75 |
| equal_ai_rotated_traits / 7 / [1, 2, 0] | Coral / 14.62 | Coral / 8.43 |
| equal_ai_rotated_traits / 7 / [0, 1, 2] | Unresolved / 30.00 | Azure / 10.11 |
| equal_ai_rotated_traits / 7 / [2, 0, 1] | Coral / 12.55 | Coral / 11.41 |
| equal_ai_rotated_traits / 42 / [1, 2, 0] | Coral / 9.26 | Coral / 6.75 |
| equal_ai_rotated_traits / 42 / [0, 1, 2] | Unresolved / 30.00 | Amber / 9.53 |
| equal_ai_rotated_traits / 42 / [2, 0, 1] | Azure / 10.70 | Azure / 8.08 |
| equal_ai_neutral_mirrored / 81923 / [0, 0, 0] | Unresolved / 30.00 | Amber / 13.36 |
| equal_ai_neutral_mirrored / 7 / [0, 0, 0] | Unresolved / 30.00 | Amber / 10.24 |
| equal_ai_neutral_mirrored / 42 / [0, 0, 0] | Coral / 9.11 | Coral / 8.77 |

A win requires the sole surviving queen; unresolved games are censored, not draws or worker-lead wins. The diagnostic observer continues beyond normal player defeat to identify the final queen, preserving the ordinary game result/time in each raw run. Default unattended cases retain Amber's original automatic raids; equal-AI controls apply the new policy to all three colonies. Actual human player Raid markers remain persistent until changed or removed.

## Changed decisions

Previously, unrelated colony-wide combat deaths could recall a party, and the 35-second limit included its surface journey and tunnel entry. The new policy records actual recruits by persistent worker identity, checks their survival independently of reused slots, and separates local raid progress from forager losses.

Initial commitment includes estimated surface travel at the existing movement speed, a 12-second tunnel allowance and 40 seconds of attack time, clamped to 50–100 seconds. A falling enemy queen-health observation while party members are inside extends the deadline to at least another 35 seconds, with a planned 180-second campaign limit checked at the ordinary strategy decision cadence. This detects shared target damage; it does not attribute every bite to that party. Targets stay fixed while the campaign is active.

Each party retains an initial limit of up to 12/24 real workers, also capped at 20% of living workers, and may recruit at most twice that initial number of unique workers over the campaign. A recovering member cannot repeatedly recycle through the same recruitment budget. Existing automatic nest defenders act normally; optional guard posts receive remaining security capacity after the committed raid allocation.

Recall still follows party casualties, an exhausted party/budget, no progress/time limit, critical food reserves, disabled invasions, a dead target or serious home/queen danger. Incidental surface traffic and unrelated deaths no longer unconditionally recall the party. Survivors leave via existing tunnel routes; the retry cooldown stays 45 seconds.

Weak enemies gain a visible finishing preference (+0.35). A fed colony with at least 12 workers can send a small party against a deserted or badly weakened nest; it need not wait for 30 workers. Loss-driven recovery may allow that finishing attack when the home queen is healthy and food is ample. Food/queen emergencies and ordinary home-defense launch checks still take precedence. Detailed thresholds are in RIVAL_AI.md.

Press I / Switch colony for the target-score finishing component, live party counts, total recruitment budget and last recall reason.

## Recorded raid activity

Totals below sum AI controllers' cumulative final counters over the fifteen matches. Amber's separate legacy default automation is not included. Progress means observed queen damage while party members were inside, not exclusive damage credit or a separate successful-raid count. Starts need not equal logged recalls: own queen elimination clears orders separately, and the final queen death can stop a match between AI decisions.

Campaigns started: **58**; queen-progress observations: **117**.

| Recall reason | Count |
| --- | ---: |
| Party losses | 25 |
| Target eliminated | 16 |
| Party exhausted | 2 |

## Individual behavior and performance

All fourteen regression suites pass, including native/reference worker/RNG comparisons and persistent player orders. The new mission suite checks actual party attrition, unrelated losses, recycled slots, progress extensions, hard limits, ordinary versus critical home pressure, food recall and bounded reinforcements. A real four-ant party traverses the full legacy 1,022px surface route and tunnels and kills an undefended queen after the old timeout in both simulation implementations.

Renderer timing ran separately after all balance jobs finished. The same compact-map centroid battle fixture and 1440×900 GL Compatibility setup are retained from MAP_BALANCE_RESULTS.md. Natural checkpoints advance every fixed tick between live windows. All ants still receive 30 updates per simulated second; there are no aggregate units, off-screen skipping or stat buffs. Synthetic fixtures provision food/spawn actual workers and retain real deaths.

| Workload | Before FPS | After FPS | After p95 ms | Actual speed | Target met |
| --- | ---: | ---: | ---: | ---: | --- |
| natural_0s | 132.5 | 105.6 | 13.53 | 3.99× | Yes |
| natural_60s | 162.6 | 132.6 | 11.67 | 4.00× | Yes |
| natural_180s | 213.6 | 186.7 | 8.62 | 4.00× | Yes |
| natural_360s | 304.2 | 272.8 | 5.13 | 4.00× | Yes |
| natural_600s | 341.2 | 314.8 | 4.12 | 3.99× | Yes |
| growth_cap_overview | 119.5 | 111.9 | 13.03 | 4.01× | Yes |
| growth_cap_battle_overview | 97.8 | 88.1 | 16.22 | 4.00× | Yes |
| growth_cap_battle_detail | 111.5 | 93.0 | 21.03 | 4.00× | Yes |

Target: mean ≥60 FPS, p95 ≤33.3ms and actual speed ≥3.9× at 2,000 workers per colony. Natural states differ as combat outcomes change; these are capacity checks rather than proof that the policy raises FPS. Population remains 2,000/colony by default. No new 3,200/colony performance claim is made.

All recorded population ledgers, unique living IDs and open-tunnel checks pass. Recruitment counters stay within their explicit budgets in every sampled state. Raw data retain queen health, stores, births, combat/hunger losses, party activity and recall reasons.

## Reproduce

Use the supplied Godot console executable with --path . and an absolute writable --log-file. Balance shards may run concurrently; run renderer measurements alone afterward.

```powershell
./play.ps1 -Test
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --endgame --shard=0/3
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --endgame --shard=1/3
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --endgame --shard=2/3
Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --endgame --mirrors-only
Godot_console.exe --path . --script res://tests/long_performance.gd -- --endgame --target=2000
python tests/analyze_endgames.py
```

Before: tests/map_balance_results.json, map_balance_mirrors.json, map_performance_2000.json. After: endgame_balance_results.json, endgame_balance_mirrors.json, endgame_performance_2000.json; shard reports retain the complete raw samples. These source reports are preserved rather than overwriting the earlier policy's results.
