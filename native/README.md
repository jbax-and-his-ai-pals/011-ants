# Native ant simulation

[Current performance and verification](../PERFORMANCE.md) owns benchmark claims and regression requirements. [Gameplay](../GAMEPLAY.md) owns player rules; [system references and history](../docs/README.md) index milestone evidence.

The included `bin/ant_kernel.dll` is a Windows x64 Godot GDExtension. The game loads it automatically, including direct command-line runs without an editor cache. No compiler, .NET runtime, or Python installation is needed to play.

The extension accelerates nearest-enemy detection, surface foraging, scent decay, simultaneous attack/walked-distance bookkeeping, population/intruder counts and visual buffer construction. It reads and writes the same packed simulation arrays as GDScript. Each worker keeps its identity, health, cargo, cooldowns, individual Godot `RandomNumberGenerator`, three scent sensors, and 30 updates per simulated second. All shared food and scent updates keep their alternating-colony and worker-slot order. Fighting movement uses the existing snapshot; tunnel missions and digging remain in GDScript. Free foragers never enter tunnels or depend on other workers' moved positions, so their batch can run before mission movement without changing those rules.

The original implementations remain in `scripts/colony.gd`. Set `native_enabled = false` on the scene to use them. If the native class is unavailable, the game falls back to GDScript. The benchmark and native comparison test require the extension and fail explicitly if it did not load.

`tests/native_test.gd` checks native results against GDScript with all profiles, swapped nests, full worker populations, shared food, deliveries, healing, pheromones, reflection, and random-stream consumption, plus interleaved combat, portals, guards, queen raids and digging. A further full-population scenario compares marked forage, Guard/Raid parties, Avoid detours and encounter filtering, including assignment identities and all individual random streams. Native arithmetic is not guaranteed bit-for-bit identical across compilers; repeated comparison currently allows under 0.002 pixel position error while requiring identical discrete outcomes and RNG states. Ordinary economy, brood, digging, combat, invasion, and navigation tests also run with the extension.

## Rebuild

Close game/editor instances using **this project** before replacing the DLL. Other Godot projects can remain open.

```powershell
.\native\setup.ps1
python .\native\build.py
.\play.ps1 -Test
```

Setup downloads a portable Zig 0.13.0 compiler and official godot-cpp 4.4 bindings, pinned to revision `b0e3b1e4b78a606f48d162898afb5eeda533d2a9`, into the ignored `.tools` directory. Both archives have pinned SHA-256 checksums. This uses Godot's compatible GDExtension C ABI and runs in the existing Godot 4.7.2 executable. The binding profile generates only the required classes. Python is required only to build and generate bindings. No machine-wide compiler installation is performed.

Builds use optimization with floating-point contraction disabled and no fast-math. Generated objects and compiler caches stay inside `.tools`. The checked-in DLL is the runtime artifact; `.pdb` and import-library files are ignored. The kernel's map constants currently mirror the 234 x 126, 14-pixel tile layout in `colony.gd`; update and rerun comparison tests together when changing that layout.

## Licenses

Godot C++ bindings are MIT licensed; see [GODOT_CPP_LICENSE.md](GODOT_CPP_LICENSE.md). Static runtime notices are in `licenses/`: LLVM libc++, libc++abi, libunwind and mingw-w64 runtime notices, plus the Zig compiler license.

The kernel reads persistent command goals and up to three Avoid centers from the existing packed arrays. It applies local steering and nearest-enemy filters per worker; it does not aggregate populations or reduce the 30 Hz update rate. The retained GDScript uses the same formulas. Guard/Raid movement and tunnel behavior remain in Godot.

Rival workers now use the same packed forage goals and Guard post pursuit leash as player workers. Player Avoid zones remain player-only. A further full-population native/reference fixture runs both leaders, food selection, guided workers, guard assignments and a rival raid, requiring matching strategy modes, source choices, assignments and every worker RNG stream.

Three-colony support uses nine independent pheromone fields, colony-indexed stores and tunnel buckets, and checks every hostile colony. Colony food-pickup order rotates across all three. Native visual batches preserve every visible worker and cargo instance and are compared to the retained drawing path. Death lists still invoke Godot cargo/loss handling; nursery and retreat/recovery jobs remain in GDScript. Comparison fixtures cover 6,000 workers, both AI instances and all three colony fields.

The long-match performance pass also batches minimap worker dots, fading surface-corpse strokes, and pheromone RGBA8 texture construction. It caches body/cargo colors per visual batch. Position/color/geometry/culling tests compare against the retained drawing rules; pheromone appearance is checked within one 8-bit color quantization level. Simulation rules and individual RNG streams are unchanged. See [the historical long-match report](../LONG_MATCH_RESULTS.md) for larger-population limits; the full 9,600-worker battle fixture remains below the 60 FPS target.
Current food/order milestone: [FOOD_CYCLES.md](../FOOD_CYCLES.md). The forage batch sends player pickup and home-delivery events to the script's order ledger. These callbacks do not alter worker arrays or consume RNG. Forecasts and bounded replenishment run outside the hot loop; each worker still senses and carries food individually.

Founding progression adds packed caste/maximum-health arrays and three cached colony foraging multipliers. Native movement, local healing, bite resolution and body transforms use the same stats as GDScript. Ordinary Skirmish workers retain the original values and RNG consumption. See [Founding progression](../PROGRESSION.md).
