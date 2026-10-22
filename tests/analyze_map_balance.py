"""Map geometry and paired colony outcomes; retain both investigated layouts."""
import json
from pathlib import Path
from collections import Counter
from analyze_targeting import load_runs, key, tally, outcome, NAMES

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"


def read(name):
    return json.loads((TESTS / name).read_text(encoding="utf-8"))


def combine_shards():
    reports = [read(f"map_balance_results_shard{i}.json") for i in range(3)]
    assert all(r["complete"] and not r["invalid_state"] for r in reports)
    assert all(r["layout"] == "equilateral742" for r in reports)
    combined = {**reports[0], "runs": [row for r in reports for row in r["runs"]]}
    order = {key(r): i for i, r in enumerate(load_runs("targeting_balance"))}
    combined["runs"].sort(key=lambda r: order[key(r)])
    assert len(combined["runs"]) == len({key(r) for r in combined["runs"]}) == 12
    (TESTS / "map_balance_results.json").write_text(json.dumps(combined, indent=2) + "\n", encoding="utf-8")


def main():
    combine_shards()
    before, wide, after = [load_runs(prefix) for prefix in ("targeting_balance", "map_wide_balance", "map_balance")]
    assert {key(r) for r in before} == {key(r) for r in wide} == {key(r) for r in after}
    old = {key(r): r for r in before}
    summary = {"before": tally(before), "wide_trial": tally(wide), "after": tally(after)}
    audit = read("map_layout_audit.json")
    routes = read("map_route_audit.json")
    perf = read("map_performance_2000.json")
    seats = read("map_seat_results.json")
    assert perf["complete"] and seats["complete"]
    lines = ["# Three-colony map balance", "", "Paired against the latest target-selection baseline: the same fifteen configurations, world seeds, traits, mirrored controls, 2,000 starting workers per colony and 30-simulated-minute horizon. Target selection, labor policy, raid timing, worker movement/combat/pheromones, food costs and brood rules remain fixed. No Azure-specific stat bonus was added.", "", "## Map audit", "", "The original map grew from two upper nests plus a third lower nest. Azure was not short of food: it had more nearby supplies and the largest nearest-nest territory share. It was, however, much closer to both rivals and closer to the world boundary. Its supplies and the old central source drew traffic toward the lower nest.", "", "| Measure | Before Amber / Coral / Azure | New, each colony |", "| --- | --- | --- |"]
    for field, title in (("near_food_240px", "Food within 240px"), ("exclusive_nearest_food", "Food uniquely nearest to nest"), ("food_share_with_ties", "Nearest-territory share, splitting shared sites"), ("nearest_border", "Nearest border, pixels")):
        values = " / ".join(f"{r[field]:,.1f}" for r in audit["before"]["resources"])
        new = audit["after"]["resources"][0][field]
        lines.append(f"| {title} | {values} | {new:,.1f} |")
    lines += ["", f"Old pair distances: {', '.join(f'{d:.1f}' for d in audit['before']['pair_distances'])}px. New pair distances: {', '.join(f'{d:.1f}' for d in audit['after']['pair_distances'])}px. The compact triangle is equilateral. Each colony has three near private sites at 190px, two outer private sites at 360px, and two adjacent pairwise shared sites at 371px. Private paths stay in their own nearest-nest territory; every pair has one equally stocked shared site.", "", "The map retains eighteen initial patches. Total food changes from **78,800 to 78,900** (+0.13%) to divide integer food equally across three colonies; the extra 100 is global and symmetric. Surface size remains 3276×1764. Nest chambers/shafts, spawn positions, camera bookmarks and drawings follow the moved nests. Two-colony regression fixtures retain their old map.", "", "## Route observation", "", "A separate fixed-tick default-seed capture measures the first 120 simulated seconds. Foreign-forager proximity is sampled every five simulated seconds within 240px of each entrance; these approximate worker-seconds describe early route exposure, not the entire match or raid traffic.", "", "| Layout | Foreign forager seconds near A / C / Z | Living workers A / C / Z at 120s | Combat losses A / C / Z |", "| --- | --- | --- | --- |"]
    for label in ("before", "after"):
        row = routes[label]
        fmt = lambda values: " / ".join(map(str, values))
        lines.append(f"| {label} | {fmt(row['sampled_foreign_forager_seconds_near_nest'])} | {fmt(row['census']['population'])} | {fmt(row['census']['combat_losses'])} |")
    lines += ["", "Screenshots at the same simulated time: [original layout](screenshots/map_before.png), [compact equal-access layout](screenshots/map_after.png). Individual ants still follow nearby food and pheromones, deliver one unit, choose their own combat target, and recover using the existing rules. Safer routes result from placement rather than scripted ant paths.", "", "## Same fifteen matches", "", "A win requires one surviving queen. Unresolved matches are censored, not counted as draws or worker-lead wins. The same three seeds recur across configurations; this is a small controlled sample, not fifteen independent random worlds.", "", "| Setup | Before wins A/C/Z | After wins A/C/Z | Unresolved before / after |", "| --- | --- | --- | --- |"]
    for group in dict.fromkeys(r["group"] for r in before):
        b, a = (tally([r for r in rows if r["group"] == group]) for rows in (before, after))
        lines.append(f"| {group} | {'/'.join(map(str,b['wins']))} | {'/'.join(map(str,a['wins']))} | {b['unresolved']} / {a['unresolved']} |")
    lines += ["", f"First queen eliminated before: **{summary['before']['first_eliminated']}** in {summary['before']['games_with_elimination']} matches with queen deaths. After: **{summary['after']['first_eliminated']}** in {summary['after']['games_with_elimination']} such matches. Overall wins before/after: {summary['before']['wins']} / {summary['after']['wins']} (Amber/Coral/Azure). Unresolved: {summary['before']['unresolved']} / {summary['after']['unresolved']}.", "", "| Setup / seed / traits | Before winner / min | After winner / min | First queen lost before / after |", "| --- | --- | --- | --- |"]
    for r in after:
        b = old[key(r)]
        first = lambda row: NAMES[row["eliminations"][0]["colony"]] if row["eliminations"] else "None"
        lines.append(f"| {r['group']} / {r['seed']} / {r['traits']} | {outcome(b)} / {b['final']['seconds']/60:.2f} | {outcome(r)} / {r['final']['seconds']/60:.2f} | {first(b)} / {first(r)} |")
    lines += ["", "The result is mixed. Azure now wins one rotated-trait match and is first eliminated less often, but Coral wins eight, Amber wins none, and six matches remain unresolved versus three in the prior baseline. Equal geometric access therefore improves a documented map issue without establishing overall match balance. The new default is a neutral resource layout for further testing; it should not be described as a solved balance pass. Endgame completion and the remaining position/strategy effects need separate investigation, with no trait buffs inferred from this small sample."]
    lines += ["", "## Wide-layout trial retained", "", f"The first candidate kept the upper pair's ~1,022px distance and moved the lower nest to match, with the same symmetric food sectors. Its fifteen matches yielded wins {summary['wide_trial']['wins']} and **{summary['wide_trial']['unresolved']} unresolved games**. It reduced sampled early entrance traffic but greatly prolonged endgames. The shipped candidate therefore uses a compact 742px equilateral triangle, closer to the original ~723px rival distance, while retaining equal access. No raid timer or combat thresholds were retuned. The wide trial is retained rather than omitted from the results.", "", "## Surface-only seat controls", "", "Nine additional 300-second controls rotate colors and their worker RNG streams through all three physical seats for each seed. All colonies use identical AI and Balanced traits; births and invasions are disabled to isolate surface activity. These are not full-match winner tests, and their absolute worker counts should not be compared with the reproducing full matches.", "", "| Seed / seat offset | Living A / C / Z | Living left / right / lower |", "| --- | --- | --- |"]
    by_seat = [[], [], []]
    by_color = [[], [], []]
    for r in seats["runs"]:
        assert r["state"]["invalid_state"] == 0
        for c in range(3):
            state = r["state"]
            assert state["births"][c] == 0
            assert state["population"][c] == 2000 - state["combat_losses"][c] - state["hunger_losses"][c]
        p = r["state"]["population"]
        physical = [0, 0, 0]
        for c in range(3):
            physical[(c + r["offset"]) % 3] = p[c]
            by_color[c].append(p[c])
            by_seat[(c + r["offset"]) % 3].append(p[c])
        lines.append(f"| {r['seed']} / {r['offset']} | {p} | {physical} |")
    summary["seat_controls"] = {"mean_living_by_color": [round(sum(v)/len(v),1) for v in by_color], "mean_living_by_seat": [round(sum(v)/len(v),1) for v in by_seat]}
    lines += ["", f"Mean living workers by color A/C/Z: {summary['seat_controls']['mean_living_by_color']}. By physical left/right/lower seat: {summary['seat_controls']['mean_living_by_seat']}. The rectangular world, axis-aligned scent grid, coarse AI census and local combat still permit position/orientation effects despite equal geometric resources. These controls diagnose residual effects rather than guarantee equal win rates.", "", "## Full renderer at 4×", "", "Timing runs follow all balance/seat jobs, with those processes stopped. The existing live-window harness measures natural checkpoints plus full-population and dense-battle fixtures at 2,000 workers/colony. The artificial battle is centered at the new triangle's centroid, equally far from every nest, with the detail camera following that center. Historical battle fixtures used (1638,1050), so the new fixture is a capacity check rather than an identical-position causal FPS comparison.", "", "| Workload | Workers at start | Mean FPS | p95 ms | Actual speed | Target met |", "| --- | --- | ---: | ---: | ---: | --- |"]
    for w in perf["windows"]:
        assert not w["start"]["invalid_state"] and not w["end"]["invalid_state"]
        lines.append(f"| {w['scenario']} | {sum(w['start']['population'])} | {w['mean_fps']:.1f} | {w['p95_ms']:.2f} | {w['actual_speed']:.2f}× | {'Yes' if w['target_met'] else 'No'} |")
    summary["performance_pass"] = perf["all_targets_met"]
    lines += ["", "Target: mean ≥60 FPS, p95 ≤33.3ms and actual speed ≥3.9×. The benchmark uses 1440×900, GL Compatibility, VSync off, and the local RTX 4070 Ti SUPER. Natural populations change over the match; synthetic fixtures spawn real workers without fake immortality or deleting populations. Every worker still updates at 30Hz per simulated second. No claim is made at 3,200/colony.", "", "All sampled full-match ledgers satisfy initial workers + births - combat losses - hunger losses = living workers. Unique IDs/open-tunnel checks pass. The 13 regression suites include native/reference individual RNG and behavior checks plus geometric/private-route/mirrored-access tests.", "", "## Reproduce", "", "Use the supplied console executable with --path . and an absolute writable --log-file. Run FPS measurements after other diagnostics finish.", "", "```powershell", "./play.ps1 -Test", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --map-balance --shard=0/3", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --map-balance --shard=1/3", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --map-balance --shard=2/3", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --map-balance --mirrors-only", "Godot_console.exe --headless --path . --script res://tests/map_seats.gd", "Godot_console.exe --path . --script res://tests/map_capture.gd", "Godot_console.exe --path . --script res://tests/long_performance.gd -- --map-balance --target=2000", "python tests/analyze_map_balance.py", "```", "", "The full-match observer continues past ordinary player defeat to determine the last surviving queen; ordinary game result/time remain in each report. Raw paired records are targeting_balance* and map_balance*. The wide trial is map_wide_balance* (add --wide-map to reproduce). Static/early-route audits are map_layout_audit.json and map_route_audit.json. Seat controls are map_seat_results.json and renderer windows map_performance_2000.json. Earlier reports remain intact."]
    (ROOT / "MAP_BALANCE_RESULTS.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    (TESTS / "map_balance_summary.json").write_text(json.dumps(summary,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(summary,indent=2))


if __name__ == "__main__":
    main()
