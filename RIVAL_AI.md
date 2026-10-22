# Rival colony strategy

> System reference and milestone evidence. [Gameplay](GAMEPLAY.md) owns current player rules; [Performance](PERFORMANCE.md) owns the latest benchmark baseline. Measurements and suite counts below belong to this milestone unless explicitly identified as current. See the [documentation index](docs/README.md) for related systems.

Each rival now makes colony decisions about every three simulated seconds. Between decisions it recruits replacements at the same 0.8-second cadence as player orders. Every ant still updates at 30 Hz, walks to its job, carries one food, uses local pheromone/food sensing, and fights with the existing rules. No extra food, health, speed or damage is awarded to the AI.

Click the **Rival** button or press **I** to inspect its current mode, reason, food knowledge, assigned workers and labor priorities. While the panel is open, coral map markers show its actual food targets, guard post and raid. Escape closes the panel. These are inspection tools for the sandbox, not fog of war.

Food scoring and recruitment use [terrain-adjusted travel and observed corridor risk](STRATEGIC_GARDEN.md). Food diagnostics in I show trip time, shortage weight and risk. The strategic garden reference owns the detailed rules; historical measurements below remain evidence for their original revision.

## Food knowledge and choices

Scouts share food discoveries within 190px; the nest also observes that radius. Remote food requires discovery or a public future forecast. A forecast exposes its announced supply, not unseen current stock or enemies. The strategy remembers quantity and coarse observed nearby worker counts, refreshes sites when observed, and forgets sites unseen for 60 simulated seconds. Observed depletion removes a source at the next decision. Dropped food participates in discovery like other surface food. Discovery processes at most 64 patches per decision, rotating through larger lists. Memory keeps at most 64 sites, favoring useful quantities when it fills.

Known sources are ranked by useful quantity, estimated surface round-trip time, nutrient demand, observed corridor enemy pressure, own recent route combat losses and observation age. Existing routes receive a 20% preference to reduce switching. Normally up to two sources receive guided workers; a third is included within 5% of the second. Alternatives below 30% of the best score are omitted, and route risk reduces individual guidance weight. The labor fraction is unchanged; remaining workers keep scouting and following trails. Danger weighs more heavily during recovery. Nearby food still takes priority for an individual worker, and loaded workers return home.

The strategic census uses 160px buckets and nearby bucket totals for inexpensive estimates of contested areas. Exact worker combat remains in the normal spatial encounter system. Colony populations and queen health are public sandbox information, also used to judge whether a raid is affordable.

## Responses

| Mode | Trigger and response |
| --- | --- |
| Scouting | No worthwhile known food: let workers discover routes. |
| Gathering | Favor useful known sources with Normal guided-forage labor. |
| Contesting | A chosen food source has at least three nearby enemies and the local balance is manageable: post guards to protect collectors. |
| Recovering | Under 35 seconds of current upkeep in reserves, heavy recent colony losses, or queen health below 60%: High guided-forage labor and cautious security. Committed raids continue unless an emergency requires recall; a healthy, well-funded finishing attack may launch despite loss-driven recovery. Reserves must recover above 65 seconds and queen health reach 70% to leave recovery; this gap prevents rapid switching. |
| Defending | Invaders in the nest or at least eight enemy surface ants within 240px of home: use High security and guard the entrance. Committed raids recall only on the serious dangers listed below. Existing tunnel defenders still respond. |
| Probing / Raiding | Begin with a 2-6-worker probe and a response interval before a qualified invasion; see [raid escalation](RAID_ESCALATION.md). Skirmish eligibility begins after 90 seconds; Founding requires five minutes and 60 workers. Full invasions also require at least 75 seconds of upkeep in reserve, at least 30 workers (12 for a finishing opportunity) and a viable population balance. |

Guard posts use 6/12/24 workers at Low/Normal/High security; guided forage uses the existing 10/25/50% labor shares. Security remains capped at 48 workers or 20% of population. Nearest available empty-handed workers take security jobs; carriers finish delivery. Guards patrol locally and do not pursue beyond 110px from their post, except contact combat. The rival uses the same job allocation code and packed individual order fields as the player, with independent ownership.

Full invasions track the identity of every recruited worker rather than using colony-wide casualty totals. Each campaign has a fixed initial party of up to 12 or 24, capped at 20% of the current population. It may recruit at most twice that many distinct workers across the whole campaign. A worker who withdraws to recover does not rejoin that campaign; reused worker slots cannot count as survivors. Normal player Raid markers retain their persistent recruitment behavior.

The initial time allowance includes estimated surface travel, 12 seconds for tunnel approach, and 40 seconds to press the attack (clamped to 50–100 simulated seconds). Queen health falling while party members are inside extends the deadline to at least 35 seconds from that observation, bounded by a planned 180-second limit from departure, checked at the normal strategy decision cadence. This observes shared queen damage and is not precise attribution of every bite. Healthy active targets remain fixed through the whole campaign.

Recall follows actual party losses (60% of the total recruitment budget, minimum two), an exhausted budget with no active raiders, lack of progress/time limit, food below 20 seconds of upkeep, disabled invasions, an eliminated target, or serious home danger. Serious danger includes enemies within 70px of the home queen, four nest intruders, a vulnerable queen under invasion, substantial surface pressure (at least 12 or 15% of population), or more than five queen-health points lost since launch. Incidental surface traffic and unrelated forager deaths do not automatically cancel a party. Raids reserve their security allocation before optional guard posts; automatic nest defenders still respond. Recall releases assignments normally, and underground survivors walk out through the shaft. The retry cooldown remains 45 seconds.

An enemy with no more than max(8, 35% of our workers), or a queen below 50% with a viable worker ratio, is a finishing opportunity. Such candidates gain a visible 0.35 score component. A fed colony with at least 12 workers can launch a small real party rather than waiting for 30; it can proceed through loss-driven recovery when its queen is at least 70% and reserves cover 75 seconds. Food/queen emergencies and the ordinary home-defense launch checks still block the attack. Worker movement, recovery, cargo and the commitment rules described here remain in force. Current role-specific trait values are described in the Coral balance follow-up.

Strategy freezes with pause and the match result. New seed clears its memory, plans, cooldowns and priorities. Rival digging now follows the [nest planner](NEST_PLANNING.md): real storage/brood projects and route improvements share labor with guided foraging, surface security and corridor posts. Existing colony traits and economic/brood rules remain in force. This is a first heuristic opponent; its thresholds do not establish a balanced win rate.

## Validation

`play.ps1 -Test` includes a dedicated rival suite for discovery limits, food ranking/depletion, player/rival assignment isolation, contested guards, cargo preservation, pursuit leashes in both kernels, raid entry/recall/cooldowns, reserve hysteresis, home and tunnel threats, loss response, pause, result freeze, reset and the inspection shortcut. Native/reference comparisons also run both leaders with active goals and require matching worker assignments, discrete outcomes and all individual random streams.

The renderer benchmark retains the previous workloads and adds full-population rival strategy and war fixtures. Live cases enable the new AI; isolation cases explicitly disable it. Metrics include decision count, maximum decision duration, rival mode and orders, frame times and actual simulation speed. See [PERFORMANCE.md](PERFORMANCE.md) for measurements and the preserved previous results.

The three-colony game gives Coral and Azure separate instances of this strategy and order allocator. Opponents treat each other as hostile, choose a surviving enemy nest, and stop new plans after their own queen dies. I / Switch colony exposes either plan. Population and queen-health comparisons use the selected enemy; local food pressure includes all other colonies.

## Target selection and explanations

Coral and Azure now score each surviving enemy queen at the ordinary decision cadence. The equal-controller diagnostic gives Amber exactly the same policy. The player still chooses Raid markers, and the R shortcut and Amber's legacy unattended timer retain their nearest-nest rule.

The score adds home threat (up to 1.20), competition on currently observed chosen food routes (up to 0.60), relative worker strength (up to 0.25), enemy queen damage (up to 0.20), and travel convenience (up to 0.15), plus a finishing-opportunity preference of 0.35 when applicable. Surface pressure counts hostiles within 240px of home, saturating at 24 workers; each hostile in the home tunnels contributes a quarter of full pressure. Threat memory decays exponentially with a 30-second time constant. Food pressure uses existing 160px neighborhood buckets and only sites observed in the current decision. Populations and queen health remain public sandbox information, as in the previous raid feasibility rule.

Candidates within 0.08 of the best score use a separate seeded strategy RNG. This removes colony-ID tie preference without altering any worker RNG stream. A target is held at least 30 simulated seconds; afterward a challenger must lead by at least 0.18. A living target stays fixed during an active raid. An eliminated target is removed immediately, the old raid is recalled, and the ordinary 45-second retry cooldown applies. Worker combat, travel, stats, traits, food and breeding remain unchanged; current commitment and party-loss rules are described above.

Press I and Switch colony to inspect the live target, selection/hold reason, and each candidate's score broken into threat, food, strength, queen, travel, and finishing opportunity. Raid status also shows active/inside/lost workers, recruitment budget and the last recall reason. Scores describe strategic preference; the displayed mode still explains why an actual raid may be delayed by defense, recovery, or reserves. Existing food routes and raid markers remain visible on the map.

Targeting tests cover deterministic ties across seeds, worker RNG isolation, commitment, changing threats, raid stability, eliminated targets, reset, tunnel attribution, and the actual UI text. The before/after investigation is in [TARGETING_RESULTS.md](TARGETING_RESULTS.md).

Skirmish gives all colonies equal nearby food and private route lengths; Founding intentionally varies local resources while guaranteeing both nutrients; the target policy above is unchanged. See [MAP_BALANCE_RESULTS.md](MAP_BALANCE_RESULTS.md) for the map/seat controls and remaining outcome imbalance.

The paired endgame-policy replay and fresh renderer results are in [ENDGAME_RESULTS.md](ENDGAME_RESULTS.md). Earlier targeting/map reports remain historical controls.

Current Coral investigation: [CORAL_BALANCE_RESULTS.md](CORAL_BALANCE_RESULTS.md). Raider bite/pursuit bonuses now apply to Invader, Guard and Warden jobs; collectors use standard bite and pursuit, and every colony follows the same role rule. Starting vertices are selected from an independent map RNG seeded by the world seed; colors no longer have permanent physical seats. Fixed-seat diagnostics remain available.
