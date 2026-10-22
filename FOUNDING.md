# Skirmish and founding modes

> System reference and milestone evidence. [Gameplay](GAMEPLAY.md) owns current player rules; [Performance](PERFORMANCE.md) owns the latest benchmark baseline. Measurements and suite counts below belong to this milestone unless explicitly identified as current. See the [documentation index](docs/README.md) for related systems.

The objective is now to [raise a daughter queen](PROGRESSION.md): specialize at 40 workers, expand the nursery and begin the project from 80 workers. Skirmish retains queen-elimination victory.

Use the selector beside the title to start a new match. **Skirmish** keeps the original 2,000-worker contest. **Founding** starts 12 workers per colony, widely separated with guaranteed nearby food. Selecting a mode starts a new match; **New seed** keeps the selected mode. Skirmish is the launch default, or pass `-- --mode=founding` for Founding.

Each founding colony starts with 80 sugar and 96 protein; 72 of that protein is already in starter brood-room buffers. Local patches vary by seed and physical location: 160–220 fruit sugar, 110–170 nectar sugar and 220–300 insect protein, at varied angles and distances of 80–125 pixels. Terrain follows the seeded garden. Supplies are guaranteed without making every opening identical.

Local replenishment starts with insect protein at two simulated minutes, followed by fruit and nectar, then repeats. These 360-unit cycle sites continue supporting homes after shared 1,200-unit sites begin at eight minutes. Forecasts appear thirty seconds ahead; existing stocks are topped up rather than duplicated within a cycle site.

Nursing grows with the small workforce, and nurses favor hungry brood. Unassigned foragers prefer local food while establishing the colony, leaving a scouting minority and respecting explicit orders. Rivals avoid a standing garrison below 40 workers unless invaded. Normal combat still works. Automatic raids wait for five minutes and 60 workers; the player can choose an earlier expedition.

All workers, loads, brood, storage trips, digging and combat remain individual. Queens, chamber planning, traits and the 3,200-worker cap remain available in both modes. Player orders control how the colony expands and competes.

See [longer-match findings and next steps](FOUNDING_GROWTH_RESULTS.md) for the before/after runs and skirmish equivalence checks. Historical mode-launch measurements remain in `tests/game_modes_skirmish_performance.json` and `tests/founding_performance.json`; the founding-growth milestone samples are in `tests/founding_growth_performance.json`. The current baseline is linked from [Performance](PERFORMANCE.md).
