"""Summarize recorded matches and renderer windows; never infer a winner from workers."""
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"
NAMES = ["Amber", "Coral", "Azure"]
TRAITS = ["Balanced", "Stewards", "Raiders"]


def main():
    runs = []
    for name in ("long_balance_results.json", "long_balance_mirrors.json"):
        data = json.loads((TESTS / name).read_text(encoding="utf-8"))
        assert data["complete"], f"Incomplete batch: {name}"
        assert not data.get("invalid_state"), name
        runs.extend(data["runs"])
    perf = json.loads((TESTS / "long_performance_results.json").read_text(encoding="utf-8"))
    assert perf["complete"] and "natural_final" in perf, "Complete longitudinal renderer run required"
    baseline_path = TESTS / "long_performance_baseline.json"
    if baseline_path.exists():
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
        assert perf["natural_winner"] == baseline["natural_winner"]
        assert perf["eliminations"] == baseline["eliminations"], "Rendering change altered the observed match"
        assert perf["natural_final"]["population"] == baseline["natural_final"]["population"]
    for extra in sorted(TESTS.glob("long_performance_*_results.json")):
        measured = json.loads(extra.read_text(encoding="utf-8"))
        assert measured["complete"], str(extra)
        for window in measured["windows"]:
            window["scenario"] += f" ({measured['growth_target_per_colony']}/colony)"
        perf["windows"].extend(measured["windows"])
    groups = defaultdict(list)
    for run in runs:
        groups[run["group"]].append(run)
        for state in [*run["samples"], run["final"]]:
            assert state["invalid_state"] == 0
            for c in range(3):
                assert state["population"][c] == 2000 + state["births"][c] - state["combat_losses"][c] - state["hunger_losses"][c], (run["group"], run["seed"], c)
        alive = [c for c, hp in enumerate(run["final"]["queens"]) if hp > 0]
        if run["winner"] >= 0:
            assert alive == [run["winner"]]
        elif run["winner"] == -1:
            assert not alive
        else:
            assert len(alive) >= 2
    summary = {"matches": len(runs), "groups": {}, "first_eliminated": dict(Counter(NAMES[r["eliminations"][0]["colony"]] for r in runs if r["eliminations"])), "all_invariants_pass": True}
    lines = ["# Long three-colony investigation", "", "Fifteen seeded matches with a 30-simulated-minute horizon, plus real-renderer 4x windows at later match states and explicit growth/battle fixtures. No game balance settings were changed during this investigation.", "", "## Winners", "", "| Setup | Matches | Amber wins | Coral wins | Azure wins | Unresolved at 30 min |", "| --- | ---: | ---: | ---: | ---: | ---: |"]
    labels = {"default_unattended": "Default unattended (original automation/traits)", "equal_ai_neutral": "Identical AI, all Balanced", "equal_ai_rotated_traits": "Identical AI, rotated traits", "equal_ai_neutral_mirrored": "Identical AI, Balanced, upper nests swapped"}
    for group, entries in groups.items():
        counts = Counter(r["winner"] for r in entries)
        summary["groups"][group] = {"runs": len(entries), "wins": [counts[c] for c in range(3)], "censored": counts[-2], "draws": counts[-1]}
        lines.append(f"| {labels[group]} | {len(entries)} | {counts[0]} | {counts[1]} | {counts[2]} | {counts[-2]} |")
    lines += ["", "A win requires one surviving queen. Unresolved games are not draws or worker-lead wins. These are small, deterministic seed samples, not estimates of a population-wide win probability. Mirroring swaps Amber/Coral's physical nests and reflects steering; Azure remains at the lower nest. Trait rotations use each profile once per game, across two seeds.", "", "| Setup | Seed | Traits A / C / Z | Winner | Minutes | First queen lost |", "| --- | ---: | --- | --- | ---: | --- |"]
    for r in runs:
        winner = NAMES[r["winner"]] if r["winner"] >= 0 else ("Unresolved" if r["winner"] == -2 else "Draw")
        first = NAMES[r["eliminations"][0]["colony"]] if r["eliminations"] else "None"
        lines.append(f"| {r['group']} | {r['seed']} | {' / '.join(TRAITS[t] for t in r['traits'])} | {winner} | {r['final']['seconds']/60:.2f} | {first} |")
    lines += ["", "## Interpretation", "", "The default unattended sample favors Coral (3/3), while equal-controller games split between Amber and Coral with several unresolved outcomes. The most repeatable concern is Azure's lower-nest disadvantage: it was first eliminated in all fourteen matches that had a queen death, including neutral and mirrored controls. The one remaining match retained all three queens at the horizon.", "", "The current nearest-hostile-nest policy makes both upper colonies target the lower nest initially (about 723px away versus 1022px to each other). Azure's equal-distance tie chooses Amber because the candidate loop visits it first. This is a concrete two-front pressure mechanism consistent with the results; these trials do not isolate it as the only cause. Rotated profiles did not establish one universally winning trait.", "", "Five games remained unresolved at 30 simulated minutes. One kept all queens alive; four retained Amber and Coral. Their large food reserves and continued births support prolonged skirmishing, while recovery and raid-recall decisions can interrupt attempts to finish a queen. A worker lead is insufficient evidence of an eventual winner.", "", "Next balance experiments should address target choice/threat splitting and tie handling first, then rerun these controls before changing trait stats. Endgame tests should separately examine raid recall based on colony-wide casualties and whether stronger colonies can finish a weakened queen. No target, trait, food, brood, combat or population tuning was applied here."]
    default = groups["default_unattended"]
    lines += ["", "## Population and pressure", "", "| Default-match time | Mean Amber workers | Mean Coral workers | Mean Azure workers | Games observed |", "| --- | ---: | ---: | ---: | ---: |"]
    for t in (0, 60, 180, 300, 600):
        states = [state for r in default for state in r["samples"] if abs(state["seconds"] - t) < 0.1]
        if states:
            means = [round(sum(s["population"][c] for s in states) / len(states)) for c in range(3)]
            lines.append(f"| {t/60:g} min | {means[0]} | {means[1]} | {means[2]} | {len(states)} |")
    peak = max(sum(s["population"]) for r in runs for s in r["samples"])
    max_fights = max(r["peak_fighting_sampled"] for r in runs)
    first_counts = summary["first_eliminated"]
    causes = Counter(e["cause"] for r in runs for e in r["eliminations"])
    summary.update({"natural_peak_total_workers": peak, "largest_fighting_sample": max_fights, "queen_death_causes": dict(causes)})
    lines += ["", f"Peak sampled natural population: **{peak}**. Largest battle sampled every 15 simulated seconds: **{max_fights} workers engaged**, not a guaranteed instantaneous maximum. First queen eliminated: {dict(first_counts)}. Queen death causes: {dict(causes)}.", "", "All recorded samples passed living-worker identity/open-tunnel checks and the population ledger: initial workers + births - combat deaths - hunger deaths = living workers. Natural trials did not establish performance at simultaneous population caps; the synthetic tests below cover that separately.", "", "## 4x renderer windows", "", "| Workload | Actual simulated minutes at start | Workers start/end | Mean FPS | p95 / p99 ms | Actual speed | Target met |", "| --- | ---: | --- | ---: | ---: | ---: | --- |"]
    for w in perf["windows"]:
        assert not w["start"]["invalid_state"] and not w["end"]["invalid_state"]
        before, after = sum(w["start"]["population"]), sum(w["end"]["population"])
        lines.append(f"| {w['scenario']} | {w['start']['seconds']/60:.2f} | {before} / {after} | {w['mean_fps']:.1f} | {w['p95_ms']:.2f} / {w['p99_ms']:.2f} | {w['actual_speed']:.2f}x | {'Yes' if w['target_met'] else 'No'} |")
    lines += ["", "Rendering-only follow-up batches minimap dots and fallen-ant markers and builds the pheromone texture in native code. All workers, corpses, fading and scent fields retain their existing semantics; the appearance tests check individual positions/colors and texture quantization. Baseline frame reports before these changes are retained in long_performance_baseline.json, long_performance_2000_baseline.json and long_performance_2400_baseline.json."]
    lines += ["", "Targets: 60 mean FPS, p95 <=33.3ms, and >=3.9 simulated seconds per wall second at requested 4x. Each live window lasts at least five wall seconds, unless the match resolves first (complete_window records this). Natural checkpoints advance using every fixed simulation tick between renderer windows, so this is longitudinal sampling, not a continuous real-time recording of the whole match.", "", "Growth fixtures explicitly spawn through the real worker-creation path to the stated target (up to 3,200 workers per colony / 9,600 total) and provision food; they are not natural growth observations. The battle fixture arranges 600 foragers per colony approaching shared food and retains normal sensing, cargo, damage, retreat and deaths. No invulnerability or population deletion is used. View and population changes during sampling are recorded.", "", "These local measurements use Godot 4.7.2 GL Compatibility, RTX 4070 Ti SUPER, 1440x900, VSync requested off. Other test/game sessions from this chat were stopped before timing. Frame-time summaries, tick phase timings and state samples are in the raw reports.", "", "## Reproduce", "", "```powershell", "# Use the provided Godot_console.exe with --path . and a writable --log-file.", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --mirrors-only", "# Run timing separately from all other test processes:", "Godot_console.exe --path . --script res://tests/long_performance.gd --resolution 1440x900", "Godot_console.exe --path . --script res://tests/long_performance.gd --resolution 1440x900 -- --growth-only --target=2000", "Godot_console.exe --path . --script res://tests/long_performance.gd --resolution 1440x900 -- --growth-only --target=2400", "python tests/analyze_long_runs.py", "```", "", "The observer harness continues after Amber's ordinary defeat only to determine the last surviving queen. game_result/game_end_seconds preserve the normal player's end point; no product outcome rules change. The equal-AI control gives Amber the existing rival strategy and suppresses its separate legacy automatic raid timer. There is no scripted human player or strategic digging in these matches.", "", "Raw reports: tests/long_balance_results.json, tests/long_balance_mirrors.json, tests/long_performance_results.json, long_performance_2000_results.json and long_performance_2400_results.json. Worker/queen timelines and frame-time summaries are retained in JSON; compact per-match/window CSVs and long_match_summary.json are generated alongside this report."]
    summary["performance_windows"] = [{k: w[k] for k in ("scenario", "mean_fps", "p95_ms", "p99_ms", "actual_speed", "target_met")} for w in perf["windows"]]
    (TESTS / "long_match_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    (ROOT / "LONG_MATCH_RESULTS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    with (TESTS / "long_matches.csv").open("w", newline="", encoding="utf-8") as f:
        out = csv.writer(f)
        out.writerow(["group", "seed", "traits", "winner", "seconds", "amber", "coral", "azure", "first_queen_lost"])
        for r in runs:
            out.writerow([r["group"], r["seed"], r["traits"], r["winner"], r["final"]["seconds"], *r["final"]["population"], r["eliminations"][0]["colony"] if r["eliminations"] else ""])
    with (TESTS / "long_performance.csv").open("w", newline="", encoding="utf-8") as f:
        keys = ["scenario", "synthetic", "mean_fps", "p95_ms", "p99_ms", "max_frame_ms", "actual_speed", "target_met"]
        out = csv.DictWriter(f, keys, extrasaction="ignore")
        out.writeheader()
        out.writerows(perf["windows"])
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
