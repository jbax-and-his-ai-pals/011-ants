# Three colonies, slower speeds and recovery

> System reference and milestone evidence. [Gameplay](GAMEPLAY.md) owns current player rules; [Performance](PERFORMANCE.md) owns the latest benchmark baseline. Measurements and suite counts below belong to this milestone unless explicitly identified as current. See the [documentation index](docs/README.md) for related systems.

The game now starts with **2,000 workers in each of three colonies**. Amber is yours; Coral and Azure are independent opponents. Their queens, brood, reserves, pheromones, tunnels, workers and strategies are separate. Both rivals can fight and raid either other colony. Azure starts Balanced, Coral Raiders and Amber Stewards. The triangular nest layout and nearby Azure food are initial tuning; equal win rates are not established.

## Speeds and inspection

The toolbar has **quarter, half, normal, double and quadruple** speed. Keys **[** and **]** select quarter and half; **1 / 2 / 3** still select 1x / 2x / 4x. Pause remains Space. Fractions change the simulation clock, including combat, pheromones, brood, AI decisions and recovery; camera and UI stay responsive.

Press **Q** to cycle the three nurseries. You can also click an unoccupied nest. The ant inspector, following, minimap, queen/brood counts and population display support Azure. **I** opens AI inspection; **Switch colony** chooses Coral or Azure, with both opponents' actual map targets visible while inspection is open. R places a raid at the nearest surviving hostile nest; use the Raid tool to choose another entrance explicitly.

Killing one rival queen leaves the match running against the other. Victory requires both rival queens dead; your queen's death causes defeat, or a draw if all queens are dead together. An eliminated AI stops issuing plans. Surviving workers remain individual ants; they do not disappear with their queen. A raid marker at a dead queen's nest stops recruiting, and invaders walk out of a cleared enemy nest.

## Soldier recovery

Workers are assigned jobs rather than permanent soldier castes. Before this change, only free foragers healed near their own nest when stores contained food; guards and raiders did not actively seek recovery. That forager rule remains.

Now guards and raiders at **1.2 health or less out of 3** switch to **Recovering**, release their duty and head home. If underground, they leave through the actual shaft before walking to their own surface entrance. They avoid pursuing enemies outside contact range but can still be attacked and killed. Recovery does not teleport or grant invulnerability.

Within 30px of their own nest, stored food heals **0.6 health per simulated second**, costing **0.05 food per health**. Spending appears in upkeep/food-flow accounting. With empty stores, they wait without healing. At full health they return to the available workforce and can be recruited again. Replacement guards/raiders can fill their old assignment while they recover. The inspector shows Recovering and the home recovery order.

Wild food is collected and brought home by foragers; troops do not consume field patches for instant healing. There is no separate medics, supply-carrier or field hospital system yet.

## Performance

The complete eight-workload renderer run passed a 60 FPS mean target at full requested 4x with 6,000 starting workers. The eight-marker stress case averaged **78.6 FPS**, with a **20.45ms p95 frame**. The guard/raid case averaged **88.5 FPS**. No population dial-down was needed on this machine. See [PERFORMANCE.md](PERFORMANCE.md) for populations during sampling, actual clock speed, hardware and limits.

Native rendering and bookkeeping were expanded alongside the third colony. All workers retain their individual simulation, including off-screen ants. The eleven-suite regression run includes native/reference comparisons at the full population and explicit recovery, multi-opponent combat and elimination cases.
