# Player guide

Current rules include Founding progression. Detailed implementation notes and historical measurements are indexed in [docs](docs/README.md). Future proposals belong in the [roadmap](ROADMAP.md).

## Modes and objective

You control Amber; Coral and Azure are independently hostile to both opponents. Skirmish starts 2,000 workers per colony with compact nests and equal local supplies. Founding starts 12 workers per colony with widely separated nests and varied local resources guaranteed to include sugar and protein. Starting seats follow the world seed independently of traits.

**Founding:** choose a specialization at 40 workers, then expand connected brood space and raise a daughter queen from 80 workers to win. Use the persistent objective tracker for the next requirement/action; press P for development. Rivals race to launch their own daughters; eliminating them alone does not finish the objective. See [Founding progression](PROGRESSION.md) for costs and physical feeding.

**Skirmish:** kill both rival queens to win. Losing your queen is defeat; simultaneous death of all queens is a draw. Eliminating one rival leaves the other in play. Results freeze the simulation, allowing inspection. Each colony can grow to 3,200 workers; connected brood capacity limits production, with a maximum of 80 young.

Changing mode starts a new match. New seed resets the match while retaining the mode and selected traits. Plans can be edited while paused.

## Controls

| Control | Action |
| --- | --- |
| Drag / wheel | Pan / zoom around the cursor |
| Click ant / C | Inspect / follow a worker across layers |
| H or Home / 0 / minimap | Focus home / fit world / navigate |
| Tab / Q | Toggle surface and underground / cycle nursery inspection |
| 4 / 5 / 6 / 7 | Forage / Guard / Avoid / Raid tool; click to place |
| Right-click marker / Escape | Remove marker / close overlays and return to inspection |
| R | Direct Raid against the nearest living rival; use 7 to choose another |
| O / L | Order results with blocking reasons / labor priorities |
| E / B | Clickable event history / work and logistics report |
| P (Founding) | Development choice and daughter queen objective |
| T / I | Scouting and territory / rival AI plan; switch the inspected rival in I |
| Raid warning banner | Focus the observed group or home-nest breach |
| G | Tunnel designation; left-drag queue, right-drag erase |
| 8 / 9 | Storage / brood chamber designation |
| 5 underground | Guard a connected corridor in your own nest |
| Middle-drag | Pan while designating tunnels or rooms |
| Space | Pause/resume |
| [ / ] / 1 / 2 / 3 | ¼× / ½× / 1× / 2× / 4× |
| F | Toggle pheromone display |

Worker cards show health, age, role, cargo, order, deliveries, kills and travel. Roles are assignments, not permanent castes. The FPS counter measures rendered frames.

## Orders and labor

Forage guides a bounded share of workers toward a site; local sensing and trails still determine actual pickups. Known depleted sites stop recruitment. Guard holds a patrol with a 110-pixel pursuit leash. Avoid marks a 100-pixel surface circle: workers detour, ignore its food and avoid chasing into it, but contact combat remains possible. Avoid cannot cover your own entrance.

Raid maintains a party at a target. Near a rival entrance, workers enter actual tunnels and reach the queen through open corridors. Player Raid orders are direct; rival strategic raids use the probe sequence below. Carriers finish delivery before security recruitment. Removing orders releases assignments; ants inside tunnels must walk out.

There are eight markers total, up to three per type and one Raid. Placing another Raid moves it. A conflicting Avoid can block a target. Press L to change labor; recruitment refreshes every 0.8 simulated seconds.

| Labor | Off | Low | Normal | High |
| --- | --- | --- | --- | --- |
| Marked forage | 0% | 10% | 25% | 50% of living workers total |
| Guard / raid | 0 | 6 | 12 | 24 workers per post |
| Excavation | 0 | 6 | 12 | 24 workers while plans are queued |

Forage allocations share their total budget using distance and nutrient demand. Unassigned foragers remain autonomous. Security also has a combined limit of 48 workers or 20% of living workers, whichever is smaller; earlier posts receive priority. Security Off stops player automatic raids; home defense still responds. Excavation Off preserves plans and progress.

E retains dated observations with click-to-focus positions. B explains excavation, storage, brood and worker availability. Both are read-only reports; old sightings may be stale. See [Clarity](CLARITY.md).

O shows actual assigned ants, sugar/protein delivered and recent combat/hunger losses for each order. Delivery credit follows the order held at pickup. Recent losses and flow rates use a rolling 30 simulated seconds. Depletion estimates reflect current trends, not guaranteed future arrivals. Loss hotspot focuses recent deaths on the appropriate layer.

## Food, brood and recovery

Fruit and nectar provide **sugar** for upkeep and healing. Insects provide **protein** for brood. Neither resource substitutes for the other. Foragers carry one unit, retain its nutrient type when killed, and physically deposit it in connected storage. Separate sugar/protein trails and cached demand weights help workers respond to shortages automatically.

| Rule | Standard value |
| --- | --- |
| Starting bank, Skirmish | 600 sugar, 120 protein per colony |
| Starting bank, Founding | 80 sugar, 96 protein per colony |
| Sugar upkeep per simulated second | 0.06 per queen + 0.004 per worker + 0.006 per brood |
| Egg interval; egg/larva/pupa duration | 3.5 seconds; 8 / 14 / 12 seconds |
| Protein per new worker | 8 normally; 7 for Stewards |
| Brood sugar reserve | Preserve max(8 sugar, 15 seconds of upkeep) before brood spending |

A mature Founding colony with 80 workers and expanded nursery capacity holds 20 free protein back from new nurse loads to make a daughter start possible. The hold releases on starting the daughter or losing readiness; committed loads remain assigned.

The starter brood-room buffers hold 72 protein already included in the bank, not extra resources. Unfed brood waits for physical protein delivery. Nurses carry up to four protein from storage to brood rooms; moving it internally does not count as newly collected food.

Founding can additionally specialize in unloaded foraging speed or producing new soldier brood. Soldiers have 5 HP and stronger bites, cost more protein/upkeep, and retain ordinary jobs.

Default Amber Stewards forage 8% faster and have 15% shorter egg/stage timing. Coral Raiders pay 15% more upkeep; their Invader/Guard/Warden roles gain 5% bite damage and a 34-pixel pursuit radius. Azure Balanced uses standard values. These are modest initial traits, not a skill tree.

Wounded security ants at or below 40% health (1.2/3 for workers, 2/5 for soldiers) retreat through real routes. At home they heal toward their own maximum at 0.6 HP/second for 0.05 sugar/HP; empty stores prevent recovery. Retreat remains vulnerable. They do not eat wild food instantly.

Food depletes. New/top-up waves have 30 simulated seconds of public notice and occur every two simulated minutes. Skirmish rotates three of six shared cycle sites per wave, capped at 6,000 each. Founding starts with nearby fruit, nectar and insect supplies at varied distances/quantities; local 360-unit cycle sites replenish protein first, then fruit and nectar, continuing after shared 1,200-unit sites begin at eight minutes. Top-ups respect site caps.

## Underground planning and terrain

G queues tunnels; 8 and 9 designate storage and brood chambers with a 3×3 brush. Real diggers excavate soil, route around stone and share work faces. Only connected, open rooms contribute capacity. A storage tile holds 2,000 combined sugar/protein; a brood tile supports two young. Starter nine-tile rooms provide 18,000 storage capacity and 18 brood slots.

Loads travel from the entrance to actual storage before banking. Nurses supply brood rooms; new workers hatch there and walk out. Length, walls, congestion and guard placement affect travel and defense. Rivals build rooms, dig routes and defend corridors using their own workers and reserves; Q and I expose their nests and planning reasons.

Bare soil gives 15% faster surface movement. Shade doubles pheromone lifetime. Other garden scenery currently provides visual variety without additional movement rules.

Each normal map adds a modest sugar source on a shorter exposed soil approach and richer protein along a longer shaded approach for each nest. Angles, distances and quantities vary by seed. These finite patches deplete normally; existing replenishment schedules remain in force. Founding keeps its varied guaranteed starters nearby. Shade preserves trails and gives no combat protection. See [strategic garden](STRATEGIC_GARDEN.md).

## Scouting, rivals and raids

T lists discovered food, nutrient purpose, remembered quantities, approximate surface round-trip seconds, soil/shade coverage and observed route danger. Travel includes loaded return and current colony speed, excluding wandering, fights and tunnel delivery. Workers watch nearby sectors; stale observations remain dated. Route reports sample a straight corridor, not a promised path. “No recent threats” means observed evidence is clear, not guaranteed safety. Forecasts disclose arrivals publicly without revealing unseen live stocks.

This is partial discovery, not full fog of war: live enemy ants remain visible and I/Q remain diagnostic inspection tools. Territory colors describe observation coverage and recent danger, not exclusive ownership.

Warnings use observed hostile motion or actual nest intruders. Up to six observed raiders are labeled SMALL RAID SIGHTING; that count does not prove the whole force is small. NEST BREACH takes priority. Scouts must see the approach to report it.

Rival strategies weigh travel time, nutrient demand, observed corridor threats and recent route combat losses to choose food and guide workers. I shows these food scores alongside target/nest explanations. They guard contested sources, compare targets and adjust labor using the same workers, resources and combat rules. Founding automatic attacks require at least five simulated minutes and 60 workers; direct player orders may act sooner.

Rivals first send 2–6 surface probe workers to a point outside the target nest. A completed approach/hold withdraws physically and leaves at least 45 simulated seconds before a larger invasion can be reconsidered. Failed probes wait 75 seconds. Food, home threats, strength and fresh target-specific reconnaissance still gate escalation; two repelled probes can justify a delayed invasion against a sufficiently weaker rival. Full campaigns have bounded replacements and recall rules. See [raid escalation](RAID_ESCALATION.md) for exact conditions and [rival strategy](RIVAL_AI.md) for diagnostics.
