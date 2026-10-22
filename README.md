# Formic — ant colony sandbox

A Godot game about directing a colony of individual ants. Lead Amber against Coral and Azure: find food, follow pheromones, excavate chambers, protect routes and invade rival nests. Workers physically move, carry, fight, nurse brood and dig; orders guide their work.

## Play

Open `project.godot` in Godot 4.7.2 and press F5, or use PowerShell from this folder:

```powershell
.\play.ps1
.\play.ps1 -Editor
# Override the executable when needed:
.\play.ps1 -GodotPath 'C:\path\to\Godot_console.exe'
```

The launcher defaults to the supplied Godot console executable under Downloads. The included Windows x64 native extension loads automatically; playing requires no rebuild. Other Godot projects may remain open.

| Mode | Opening |
| --- | --- |
| Skirmish (default) | 2,000 workers per colony, nearby rivals and equal starting supplies |
| Founding | 12 workers per colony, varied local supplies; specialize, expand and raise a daughter queen to win |

The mode selector starts a new match. **New seed** retains the selected mode. Launch defaults to 1×; pause and ¼×, ½×, 1×, 2× and 4× are available. For direct launch arguments, call Godot rather than `play.ps1`:

```powershell
$godot = Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $godot --path . -- --mode=founding --speed=4
```

Drag to pan, wheel to zoom, click an ant to inspect, **Tab** to enter the nest. **4–7** place Forage/Guard/Avoid/Raid orders; **G/8/9** designate tunnels/storage/brood. **O/L/T/I** open orders, labor, scouting and rival AI explanations. **E/B** open clickable event history and the work report. **P** opens Founding development; the objective tracker links to the next step. See the complete [player guide](GAMEPLAY.md).

## Documentation

| Document | Owns |
| --- | --- |
| [Gameplay](GAMEPLAY.md) | Current controls, modes, economy, planning, scouting and combat |
| [Roadmap](ROADMAP.md) | Proposed next milestones, dependencies and completion criteria |
| [Performance](PERFORMANCE.md) | Simulation constraints, latest measured baseline and verification commands |
| [Reference and history index](docs/README.md) | Detailed system notes, past experiments and preserved guide snapshots |
| [Native development](native/README.md) | Kernel boundaries, build procedure and licenses |

The current baseline includes rival nest construction, sugar/protein logistics, founding growth, staged raids, [Founding progression](PROGRESSION.md), [clarity tools](CLARITY.md) and [strategic garden routes](STRATEGIC_GARDEN.md). Verification passed 28 rule suites, 24 seeded map accessibility checks and 12 renderer windows at requested 4×. Dense battle views averaged 133.2–193.4 FPS with scouting open on the test machine; local measurement limits are explained in [Performance](PERFORMANCE.md).

Run rule verification with `.\play.ps1 -Test`. Documentation-only changes do not require engine tests.
