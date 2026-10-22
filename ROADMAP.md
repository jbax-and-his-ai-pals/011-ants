# Roadmap

Working plan, consolidated 2026-10-21. Updated through the strategic garden milestone. Remaining milestones are proposals, not a delivery schedule. Change their order as playtesting identifies the next useful decision. Current rules live in [Gameplay](GAMEPLAY.md); measurement requirements live in [Performance](PERFORMANCE.md).

## Direction

Build a readable colony strategy game where the player influences thousands of individual ants through routes, labor, nest design and timely responses. Preserve autonomous workers and physical logistics. Make the garden and opponents create changing decisions before adding large progression systems or chasing equal win rates.

## Completed foundation

| Area | Available now |
| --- | --- |
| Individual simulation | Three hostile colonies, ant inspection, pheromones, combat, recovery, queen invasions and outcomes |
| Scale and navigation | Large world, pan/zoom/follow/minimap, ¼×–4×, 2,000-worker Skirmish starts, native acceleration |
| Colony control | Forage/Guard/Avoid/Raid, labor priorities, per-order delivery/loss feedback |
| Economy | Depletion/top-ups, arrival forecasts, sugar upkeep, protein brood, shortage-aware collection |
| Nests | Real excavation, connected storage/brood capacity, courier/nurse trips, defensive corridors |
| Rivals | Resource/target selection, adaptive labor, nest expansion, small probes before committed invasions |
| Modes and information | Founding from 12 workers, varied guaranteed local food, discovery, route danger and raid warnings |
| Founding progression | Foraging or soldier brood specialization, paid caste births, physical daughter queen development and a launch race |
| Clarity | Bounded clickable event history, work/order explanations, actionable Founding tracker and earlier rival nursery preparation |
| Garden | Seeded sugar/protein route alternatives, faster soil, shaded trails, trip reports and observed rival corridor risk |

These systems have rule and renderer coverage. Their presence does not mean their pacing, interface or balance is finished. Strategic garden verification covers 28 rule suites, 24 seeded maps / 72 colony route pairs, three natural six-minute Founding openings and twelve renderer windows. See [the findings](STRATEGIC_GARDEN.md) and [Performance](PERFORMANCE.md). The earlier [clarity comparison](CLARITY_RESULTS.md) remains historical; cap-scale battles and broader balance remain open questions.

## Recommended sequence

### 1. Make the existing decisions easier to read — implemented

The [clarity milestone](CLARITY.md) implements the core feedback loop with observed events, stored focus locations, work/order reasons and a four-step Founding objective tracker. Specialized rivals begin actual nursery excavation from sixty workers with six diggers.

- Shipped: bounded dated history for food observations, raid sightings, breaches, queen danger and own development; click to focus the recorded location.
- Shipped: cached explanations for labor, conflicting orders, excavation access, storage, brood supplies and daughter progress.
- Shipped: a clickable Founding objective tracker for specialization, nursery capacity, paid preparation and fed development.
- Follow-up proposal: an optional resource-opening checklist and configurable pause on critical events, only if playtests show a need. Continue reviewing warning persistence at ¼×, 1× and 4×.

**Done when:** a player can identify a shortage, locate its cause, change an order and see the result; probe/breach notices are actionable without opening diagnostic AI inspection. No hidden intent leaks, unbounded event lists or per-ant UI polling.

### 2. Turn the garden into strategic choices — implemented

The [strategic garden milestone](STRATEGIC_GARDEN.md) adds finite modest sugar along shorter exposed soil approaches and richer protein along longer shaded approaches. Starting resources remain varied and guaranteed. Scouting compares nominal trips, terrain and observed danger; rivals account for those costs and recent route combat losses in source scoring and real worker guidance. Existing forecasts/top-up rules continue unchanged.

- Shipped: three seeded pairs of alternative destinations, physical corridor terrain and ordinary depletion.
- Shipped: nutrient purpose, round-trip estimates, soil/shade coverage and dated threat evidence in T; candidate score components in I.
- Shipped: bounded cached estimates and scout-observed rival route memory; no terrain combat bonuses or hidden route-enemy feed.
- Follow-up proposals: deliberately shaped choke points/wider approaches, more varied public wave geography, and human playtesting of route relocation. Current terrain remains entirely walkable; ants retain local steering rather than global path planning.

Accessibility evidence covers twelve seeds in each mode. Compare strategic choices through playtesting before adding more terrain effects or claiming balanced openings. Renderer and rule evidence belongs in [Performance](PERFORMANCE.md).

### 3. Add durable matches and reproducible scenarios

**Next recommended milestone.** Preserve longer Founding sessions and make reported matches reproducible before introducing more stateful systems.

- Add versioned save/load and autosave. Capture worker identities/RNG, tick state, all banks/cargo, room buffers, brood, terrain/food cycles, orders, scouting memory and AI campaign state.
- Restore selections/camera/speed appropriately; protect the previous save against an interrupted write. Define a clear policy for incompatible versions.
- Add a small match setup for seed, mode and existing trait choices, plus a restart-same-seed action. Keep diagnostic controls separate from ordinary setup.
- Reuse scenario configuration for tests so a reported match can be reproduced. Do not promise portable deterministic replays across native compiler versions.

**Done when:** save/load continuation matches an uninterrupted fixture for discrete outcomes and RNG, physical workers resume jobs correctly, and loading never grants food or duplicates ants. Round-trip both modes and active invasions.

### 4. Strengthen defenses and deliberate offensives

Depends on readable threats; use garden routes and nest logistics to create choices.

- Playtest probe response, guard relocation, corridor defense and recovery before adding another combat statistic.
- Consider a player raid staging/recall control and escorts for dangerous food routes, sharing existing security labor. Show the cost in lost foraging and exposed home defense.
- If necessary, add a limited entrance/corridor planning option with explicit counterplay; ensure queens remain reachable and do not create permanent stalemates.
- Give rival decisions clear difficulty presets through decision quality, reaction cadence or commitment. Document information access; keep resource/combat cheats out of the initial presets.

**Done when:** defense buys time but cannot lock a match forever; attacks require a visible resource/labor commitment; recalls return actual workers. Run long matches for stalls and both renderer stress cases for larger encounters.

### 5. Broaden scenarios and colony identity

Depends on the previous systems supporting a satisfying match. Prototype one addition at a time.

- Explore survival/growth objectives and handcrafted garden scenarios alongside queen elimination.
- Try small colony doctrines with tradeoffs in work allocation or logistics. Test changed play patterns before adding more percentage bonuses.
- Consider additional colonies only after profiling variable colony counts: hostility lookup, scent fields, UI, food geography, nest layers and win conditions all need support. Three is the current supported count.
- Explore predators, weather or garden disturbances only when they create a clear decision with fair warning and bounded simulation cost.

**Done when:** each scenario or doctrine changes a player's choices, explains its rules, and works in both modes where appropriate. Added colony count needs its own measured population/performance budget.

## Hold for later

Broader skill trees, persistent unlocks, campaign levels, additional castes, elaborate art and multiplayer remain exploratory. The first Founding loop now includes one exclusive specialization choice, soldier brood and daughter-queen launch; extending that into a campaign remains proposed. They multiply balance, save-state and UI work. Revisit progression after individual matches offer enough choices; prefer sidegrades and explicit tradeoffs over permanent numerical superiority. Full fog of war also needs a separate information-model decision: the current sandbox intentionally exposes live enemy ants and diagnostic nest/AI views.

## Ongoing checks and known gaps

- Founding progression and earlier nursery planning have eight paired seeds, with actual race outcomes and separate thirty-minute diagnostic continuation. Rivals now anticipate nursery expansion from sixty workers; some still struggle to maintain eighty under combat or fund a daughter in time. Broader strategy and trait/seat controls remain useful before concluding one color dominates. Historical win rates predate current systems. Tune obvious starvation/stalls without making perfect symmetry the goal.
- Keep 2,000 starting workers per colony and individual behavior at 4× as the regression target. Include natural Founding growth, dense supplied battles, open panels and underground activity. The 3,200-per-colony cap is a stretch workload, not a proven 60-FPS promise.
- Keep forecasts, observation age, route uncertainty and diagnostic knowledge explicit. Discovery coverage is not ownership or complete fog of war.
- Record acceptance evidence when completing a milestone: focused/full rule checks, native comparison if touched, both mode benchmarks, and a real UI capture when the interface changes. Reuse established harnesses.

## Keeping this plan useful

When selecting work, choose one milestone slice with a player-facing outcome, bounded scope and a verification plan. On completion, update the owning guide and this baseline, link evidence through the [documentation index](docs/README.md), and leave unfinished proposals visibly proposed. Avoid appending another “Latest” banner to every document. Dates and results belong to the report that measured them; current guidance belongs to the canonical guides.
