"""Paired policy comparison. Keep the original investigation's reports intact."""
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"
NAMES = ["Amber", "Coral", "Azure"]


def read(name):
    return json.loads((TESTS / name).read_text(encoding="utf-8"))


def load_runs(prefix):
    runs = []
    for suffix in ("results", "mirrors"):
        report = read(f"{prefix}_{suffix}.json")
        assert report["complete"] and not report["invalid_state"]
        assert report["simulated_horizon_seconds"] == 1800
        assert report["starting_workers_per_colony"] == 2000
        runs += report["runs"]
    for run in runs:
        for state in [*run["samples"], run["final"]]:
            assert not state["invalid_state"]
            for c in range(3):
                assert state["population"][c] == 2000 + state["births"][c] - state["combat_losses"][c] - state["hunger_losses"][c]
        living = [c for c, hp in enumerate(run["final"]["queens"]) if hp > 0]
        assert living == [run["winner"]] if run["winner"] >= 0 else (len(living) >= 2 if run["winner"] == -2 else not living)
    return runs


def key(run):
    return run["group"], run["seed"], tuple(run["traits"]), run.get("swapped", False)


def outcome(run):
    return NAMES[run["winner"]] if run["winner"] >= 0 else ("Unresolved" if run["winner"] == -2 else "Draw")


def tally(runs):
    wins = Counter(r["winner"] for r in runs)
    first = Counter(NAMES[r["eliminations"][0]["colony"]] for r in runs if r["eliminations"])
    return {"wins": [wins[c] for c in range(3)], "unresolved": wins[-2], "draws": wins[-1], "first_eliminated": dict(first), "games_with_elimination": sum(first.values())}


def main():
    before = load_runs("long_balance")
    after = load_runs("targeting_balance")
    old = {key(r): r for r in before}
    assert len(old) == len(before) == len(after) == 15
    assert set(old) == {key(r) for r in after}, "Paired seeds, traits, controllers and mirrors required"
    summary = {"before": tally(before), "after": tally(after), "groups": {}}
    opening = [next(s for s in r["samples"] if s["seconds"] >= 15)["ai_targets"] for r in after]
    summary["first_census_targets"] = {
        "both_upper_prefer_azure_before": 15,
        "both_upper_prefer_azure_after": sum(t[0] == 2 and t[1] == 2 for t in opening),
        "azure_prefers_amber_after": sum(t[2] == 0 for t in opening),
        "azure_prefers_coral_after": sum(t[2] == 1 for t in opening),
    }
    lines = ["# Target selection: paired before/after results", "", "The same fifteen seeded, three-colony matches were replayed for up to 30 simulated minutes each. Starts remain 2,000 workers per colony. Map, food, traits, individual worker rules, brood and raid-loss thresholds are unchanged. This comparison changes colony target selection and adds explanations; it does not attempt endgame or map balance tuning.", "", "## Outcomes", "", "Wins require a sole surviving queen. An unresolved match is censored at the horizon, not a draw or a worker-lead win. These small deterministic samples do not estimate general win probabilities.", "", "| Setup | Before wins A/C/Z | After wins A/C/Z | Before unresolved | After unresolved |", "| --- | --- | --- | ---: | ---: |"]
    for group in dict.fromkeys(r["group"] for r in before):
        b = tally([r for r in before if r["group"] == group])
        a = tally([r for r in after if r["group"] == group])
        summary["groups"][group] = {"before": b, "after": a}
        lines.append(f"| {group} | {' / '.join(map(str,b['wins']))} | {' / '.join(map(str,a['wins']))} | {b['unresolved']} | {a['unresolved']} |")
    lines += ["", f"First queen eliminated before: **{summary['before']['first_eliminated']}**, in {summary['before']['games_with_elimination']} matches with a queen loss. After: **{summary['after']['first_eliminated']}**, in {summary['after']['games_with_elimination']} such matches.", "", "| Setup / seed / traits | Before winner / min | After winner / min | First eliminated before / after |", "| --- | --- | --- | --- |"]
    for r in after:
        b = old[key(r)]
        first = lambda x: NAMES[x["eliminations"][0]["colony"]] if x["eliminations"] else "None"
        lines.append(f"| {r['group']} / {r['seed']} / {r['traits']} | {outcome(b)} / {b['final']['seconds']/60:.2f} | {outcome(r)} / {r['final']['seconds']/60:.2f} | {first(b)} / {first(r)} |")
    lines += ["", "Target choice is less automatic, and Azure is no longer invariably eliminated first. However, Azure still wins none of these matches; this is an improvement to target selection, not a balanced-map claim. Coral still wins all three default unattended matches. Amber now sweeps the three neutral, equal-AI seeds, while the mirrored neutral cases split one win each between Amber and Coral plus one unresolved game. That sensitivity argues for continued position/route and endgame tests before tuning trait bonuses. The sample reuses three world seeds across configurations; the fifteen outcomes are not fifteen independent random worlds."]
    lines += ["", "## What changed", "", "The previous nearest-nest policy initially sent both upper colonies toward Azure, and Azure's exact distance tie selected Amber by colony ID. The new policy weighs threats at home, current observed competition on chosen food routes, public worker strength and queen health, with a smaller travel term. Comparable candidates use a separate seeded RNG; this never consumes worker random streams. Targets have a 30-second commitment and a 0.18 switching margin. Living active raid targets remain fixed, and eliminated targets cancel their raid with the existing cooldown.", "", "Press I / Switch colony for target and holding/switching reason plus every candidate's score components. Preference does not imply a raid is currently affordable: the mode still reports defense/recovery/resource constraints. Details and weights are in RIVAL_AI.md.", "", "Default unattended trials retain Amber's original nearest-nest automation and asymmetric traits. Equal-controller cases give all three colonies the new strategy. The physical map, food placement and ordinary forager contacts can still disadvantage the lower nest even when strategic raid targets are fairer. No protective bonuses or scripted win rotation were added.", "", "All sampled worker ledgers, unique worker IDs and open-tunnel checks passed. Native/reference regressions preserve individual movement, cargo, scent, combat, recovery and RNG semantics. Target scores/reasons and preferences are included in each new 15-second census.", "", "## Opening target choices", "", "The first 15-second census below shows preferences, not necessarily active raids. The old policy's opening targets were A→Z, C→Z, Z→A in every case. Amber remains A→Z in default unattended trials.", "", "| Setup / seed / traits | New preferred targets A / C / Z |", "| --- | --- |"]
    for r in after:
        first = next(s for s in r["samples"] if s["seconds"] >= 15)
        targets = " / ".join(NAMES[c] if c >= 0 else "Undecided" for c in first["ai_targets"])
        lines.append(f"| {r['group']} / {r['seed']} / {r['traits']} | {targets} |")
    choices = summary["first_census_targets"]
    lines += ["", f"Both upper colonies preferred Azure in **15/15** openings under the old rule and **{choices['both_upper_prefer_azure_after']}/15** first censuses after the change. Azure now preferred Amber in {choices['azure_prefers_amber_after']} and Coral in {choices['azure_prefers_coral_after']}; the old exact tie always preferred Amber. These are preferences at 15 seconds, not successful raid counts or a guarantee against later two-front pressure."]
    lines += ["", "## Real renderer at 4×", "", "Timing was run separately after all balance/regression jobs finished. Same renderer, resolution and workload harness as before. Natural checkpoints run all fixed ticks between live windows; stress fixtures explicitly provision/spawn real workers and arrange normal foragers around shared food. No skipped workers, invulnerability or population deletion.", "", "| Workers/colony, workload | Before FPS | After FPS | After p95 ms | Actual speed | Target met |", "| --- | ---: | ---: | ---: | ---: | --- |"]
    windows = []
    for target in (2000, 2400):
        measured = read(f"targeting_performance_{target}.json")
        assert measured["complete"]
        historical = read(f"long_performance_{target}_results.json")["windows"]
        natural = read("long_performance_results.json")["windows"]
        for w in measured["windows"]:
            assert not w["start"]["invalid_state"] and not w["end"]["invalid_state"]
            match = next((b for b in (natural if not w["synthetic"] else historical) if b["scenario"] == w["scenario"]), None)
            baseline = f"{match['mean_fps']:.1f}" if match else "—"
            lines.append(f"| {target}, {w['scenario']} | {baseline} | {w['mean_fps']:.1f} | {w['p95_ms']:.2f} | {w['actual_speed']:.2f}× | {'Yes' if w['target_met'] else 'No'} |")
            windows.append({"target": target, **{k: w[k] for k in ("scenario", "mean_fps", "p95_ms", "actual_speed", "target_met")}})
    summary["performance"] = windows
    default_windows = [w for w in windows if w["target"] == 2000]
    summary["default_population_performance_pass"] = all(w["target_met"] for w in default_windows)
    lines += ["", f"At the default 2,000/colony population, **{sum(w['target_met'] for w in default_windows)}/{len(default_windows)} windows pass**. The optional 2,400/colony battle overview is borderline at 59.8 FPS in this batch and misses the strict 60 mean target, despite maintaining full simulation speed. Earlier historical timing was faster; no claim is made that target selection improves FPS. Keep the default at 2,000/colony for the validated margin."]
    lines += ["", "Performance target: ≥60 mean FPS, p95 ≤33.3ms, actual speed ≥3.9×. Natural windows after time zero contain changed battles and populations and are not identical workloads; synthetic fixtures provide the closer capacity comparison. Historical 3,200/colony stress results remain below 60 FPS; this milestone makes no new claim at that cap.", "", "## Reproduce", "", "Use the supplied Godot console executable, --path . and an absolute writable --log-file. Run timing separately from other benchmarks:", "", "```powershell", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --targeting", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --targeting --mirrors-only", "Godot_console.exe --path . --script res://tests/long_performance.gd -- --targeting --target=2000", "Godot_console.exe --path . --script res://tests/long_performance.gd -- --targeting --growth-only --target=2400", "./play.ps1 -Test", "python tests/analyze_targeting.py", "```", "", "The observer alone continues past the player's ordinary defeat to identify the last surviving queen. Each report retains the ordinary game result/time too. Original reports remain under long_balance* / long_performance*; new reports are targeting_balance* / targeting_performance*. The policy was fixed before the paired batch; no tuning to favor individual benchmark seeds was performed."]
    (ROOT / "TARGETING_RESULTS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (TESTS / "targeting_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
