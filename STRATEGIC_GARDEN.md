# Strategic garden

Each normal three-colony map now adds a pair of finite food opportunities per nest. These are alternative destinations with distinct approach corridors, rather than two globally planned paths to the same patch. All ground remains walkable; ants still steer individually using nearby food, pheromones and orders.

## Choosing a source

| Opportunity | Founding | Skirmish | Approach |
| --- | --- | --- | --- |
| Modest sugar | 110–150 units, 330–360px from home | 2,200–3,000 units, 225–245px | Mostly exposed bare soil: +15% movement |
| Richer protein | 400–540 units, 490–530px from home | 8,000–10,800 units, 345–375px | Mostly shaded meadow: twice the pheromone lifetime |

Angles, handedness, distances, sugar appearance and quantities vary from a separate seeded stream tied to the physical starting site. Colors rotate among starting seats as before. The new corridors point toward the interior garden, creating increasing opportunities for encounters as workers leave home. Shade preserves real trails; it does not reduce damage, hide ants or guarantee safety. Nearby incidental paths and shade can overlap small sections.

Founding retains its three guaranteed fruit/nectar/insect starters at varied 80–125px distances and their existing quantity ranges. New opportunities begin beyond the 300px early local-guidance area. Skirmish retains its eighteen base food patches and adds six opportunities. Founding retains its nine starters and adds six. Legacy two-colony, legacy-map and wide-layout diagnostics retain their original food geometry. The original equal-resource map audit still checks the eighteen base patches separately; the new finite opportunities intentionally vary.

The new sources deplete normally and do not refill automatically. Existing two-minute top-ups, thirty-second public forecasts, six shared cycle locations and Founding local support continue unchanged. Sugar pays upkeep/recovery; protein feeds brood and daughter development. No new nutrient, terrain combat bonus or colony statistic is introduced.

## Scouting [T]

Each remembered source shows nutrient purpose, last observed stock and age, distance, approximate **surface round-trip seconds**, soil/shade coverage and current observed danger. Click to focus, then use ordinary Forage/Guard/Avoid controls. Six rows fit per page; Next/Previous retain access to other discoveries.

Travel estimates sample 32 evenly spaced points along a straight corridor. They include the actual soil multiplier, colony forage trait, unloaded specialization and the slower loaded return. They exclude wandering, combat, Avoid detours and underground storage travel. They are nominal simulated seconds, not promises about an ant's arrival or a measured delivery rate. Longer shade routes preserve trails through the existing evaporation simulation; no artificial shade score is added.

Danger and coverage retain the scouting model: observed hostile sectors persist up to twenty simulated seconds, own losses for thirty, and unexplored sections remain uncertain. Quiet shade can still be dangerous; an unexplored corridor is not reported as safe. Stock changes require a scout revisit. Public forecasts do not reveal unseen current quantities. This remains partial discovery, with live enemy ants and diagnostic I/Q views available.

## Rival decisions [I]

Rivals score at most 64 remembered sources at their existing three-simulated-second cadence. Ranking combines capped useful quantity, current nutrient demand, estimated round-trip travel, observed pressure, own recent corridor combat losses, age and the existing 20% route commitment preference. Recovery doubles the risk coefficient from 1.5 to 3. A third route still requires a score within 5% of second place; alternatives below 30% of the best score do not receive guided orders.

Coarse 160px hostile-sector memories require visibility from the rival's own scouts and expire after twenty seconds or when watched empty. Corridor queries use a 130px radius and peak sector count rather than adding a traveling enemy repeatedly. Own surface combat losses contribute for thirty seconds. Existing public population/queen information still supports invasion decisions; it is not used as hidden food-route danger.

A public future forecast may enter food memory with its announced quantity. Unwatched current stock and remote enemy counts no longer refresh from a cycle patch merely because it has a public site ID. Scouting still learns real quantities on arrival. Estimated future supply remains a plan, not confirmed live stock.

Risk also reduces the selected rival marker's guidance weight, within the existing labor budget and individual nearest-weighted-goal allocator. Player marker allocation retains its existing rules. Loaded carriers, individual local sensing and the unguided scouting workforce remain active; a risky route is not an invisible movement barrier. The inspection panel shows candidate trip time, shortage weight and observed risk alongside the existing target and nest explanations.

## Cost and verification

Terrain is generated and baked once per reset. Worker movement and pheromone decay use the same packed speed/shade fields and native/reference code. No worker update, offscreen simulation or population is removed. The geometry cache holds at most 384 exact home/destination keys; dynamic colony speed is applied outside the cache. At most 64 scouting and 64 sources per rival use estimates; observed risk is queried at existing report/strategy cadences, never per ant per tick.

[Accessibility evidence](tests/strategic_garden_accessibility.json) covers twelve seeds in each mode: 24 maps / 72 colony pairs, bounds, terrain proportions, trip ordering, varied guaranteed starters and reproducibility. The focused suite also checks bounded read-only estimation, loaded/unloaded specialization, shortage/risk/loss scoring, actual guided-worker recruitment, forecast privacy, observed threat expiry and real pickup/return in both kernels. Existing native/reference, Founding opening, food conservation and control suites remain active.

Staged screenshots use real scout positions, with supplied workers for observation coverage; they are interface fixtures rather than natural growth evidence: [scouting](screenshots/strategic_garden_reports.png), [corridors](screenshots/strategic_garden_routes.png), [rival explanation](screenshots/strategic_garden_rival.png).

All **28 rule suites passed** without errors. The retained individual native/reference comparison stayed within **0.000252px**. Three natural six-minute Founding openings (81923, 404, 9973) grew every colony to 66–85 workers with no hunger losses, while every colony physically delivered both nutrients. Their first combat losses were at 189.3s, 319.6s and 319.0s; all retained a peaceful first two minutes. These are opening checks, not a balance or daughter-race study. [Verification summary](tests/strategic_garden_verification.json).

All **12 renderer windows passed** with the expanded scouting panel and territory overlay open. Dense battles averaged **133.2–193.4 FPS**; worst p95 across all windows was **16.71ms**, actual progression **3.99–4.02x**. Samples reconciled individual validity, births/losses, protein buffers/nurse loads, storage and final soldier counts. [Raw renderer report](tests/strategic_garden_performance.json). Hardware, workload methods and limitations belong in [Performance](PERFORMANCE.md).

Reproduce separately from heavy work:

```powershell
.\play.ps1 -Test
Godot_console.exe --path . --script res://tests/strategic_garden_performance.gd
Godot_console.exe --path . --script res://tests/strategic_garden_capture.gd
```

These commands overwrite their own current reports/captures. Historical clarity and progression results remain at their existing paths. This milestone does not establish equal colony win rates or optimal human route choices.
