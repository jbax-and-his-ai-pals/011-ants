"""Paired balance study with fixed-seat/trait, surface and holdout controls."""
import json
from collections import Counter
from pathlib import Path
from analyze_targeting import load_runs, key, tally, outcome, NAMES

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"
TRAITS = ["Balanced", "Stewards", "Raiders"]


def read(name):
    return json.loads((TESTS / name).read_text(encoding="utf-8"))


def write(name, data):
    (TESTS / name).write_text(json.dumps(data, indent=2)+"\n", encoding="utf-8")


def validate(rows):
    for r in rows:
        states = [*r.get("samples", []), r.get("final", r.get("state"))]
        for state in states:
            assert state["invalid_state"] == 0
            for c in range(3):
                assert state["population"][c] == 2000 + state["births"][c] - state["combat_losses"][c] - state["hunger_losses"][c]
        if "winner" in r:
            alive = [c for c, hp in enumerate(r["final"]["queens"]) if hp > 0]
            assert alive == [r["winner"]] if r["winner"] >= 0 else len(alive) >= 2


def combine(prefix):
    shards = [read(f"{prefix}_results_shard{i}.json") for i in range(3)]
    assert all(d["complete"] and not d["invalid_state"] for d in shards)
    d = {**shards[0], "runs": [r for s in shards for r in s["runs"]]}
    order = {key(r): i for i, r in enumerate(load_runs("endgame_balance"))}
    d["runs"].sort(key=lambda r: order[key(r)])
    assert len(d["runs"]) == len({key(r) for r in d["runs"]}) == 12
    write(f"{prefix}_results.json", d)
    return load_runs(prefix)


def ctrl_key(r):
    return r["group"], r["seed"], r["offset"], tuple(r["traits"])


def controls(label, standard_before):
    shards = [read(f"coral_controls_{label}_shard{i}.json") for i in range(3)]
    assert all(d["complete"] for d in shards)
    rows = [r for d in shards for r in d["runs"]]
    if label == "before":
        # Reuse previously measured identical configurations, never invented outcomes.
        for r in standard_before:
            if r["group"] == "equal_ai_neutral":
                rows.append({**r, "group": "neutral_seat_rotation", "offset": 0, "source": "endgame_balance_results.json"})
            elif r["group"] == "equal_ai_rotated_traits" and r["traits"] == [1, 2, 0]:
                rows.append({**r, "group": "original_traits_equal_ai", "offset": 0, "source": "endgame_balance_results.json"})
    assert len(rows) == len({ctrl_key(r) for r in rows}) == 18
    validate(rows)
    write(f"coral_controls_{label}_combined.json", {"complete": True, "runs": rows})
    return rows


def neutral_seats(rows):
    r = [x for x in rows if x["group"] == "neutral_seat_rotation"]
    return {"color_wins": dict(Counter(NAMES[x["winner"]] for x in r if x["winner"] >= 0)), "seat_wins": dict(Counter(["Left", "Right", "Lower"][(x["winner"]+x["offset"])%3] for x in r if x["winner"] >= 0)), "unresolved": sum(x["winner"] == -2 for x in r)}


def trait_wins(rows):
    return dict(Counter(TRAITS[r["traits"][r["winner"]]] for r in rows if r["group"] != "neutral_seat_rotation" and r["winner"] >= 0))


def surface(name):
    d = read(name)
    assert d["complete"]
    validate(d["runs"])
    values = [[], [], []]
    for r in d["runs"]:
        for c, p in enumerate(r["state"]["population"]): values[(c+r["offset"])%3].append(p)
    return [round(sum(v)/len(v),1) for v in values]


def main():
    before = load_runs("endgame_balance")
    fixed, after = combine("coral_fixed_balance"), combine("coral_balance")
    assert {key(r) for r in before} == {key(r) for r in fixed} == {key(r) for r in after}
    pre, post = controls("before", before), controls("after", before)
    assert {ctrl_key(r) for r in pre} == {ctrl_key(r) for r in post}
    summary = {"before": tally(before), "fixed_seat_trial": tally(fixed), "after": tally(after), "neutral_seat_controls_before": neutral_seats(pre), "neutral_seat_controls_after": neutral_seats(post), "trait_wins_before": trait_wins(pre), "trait_wins_after": trait_wins(post), "surface_mean_survivors_by_left_right_lower": {"old_guided": surface("map_seat_results.json"), "unguided": surface("coral_unguided_control.json"), "three_route_guided": surface("coral_guided_after.json")}}
    lines = ["# Coral advantage: traits, seats and AI", "", "The same fifteen full matches are paired against the completed endgame-policy baseline, with 2,000 starting ants per colony and a 30-minute horizon. Additional fixed-seat/trait swaps, surface-only controls and unseen-seed tests distinguish color from location and decisions. Outcomes are not treated as proof of universally equal win rates.", "", "## Findings and changes", "", "Coral previously combined the right-hand starting vertex, Raider traits and a colony AI, while the default unattended Amber used simpler automatic raids. Those factors were confounded in the default sample. The neutral mirrored pairs changed the winner's color but retained the same winning physical seat for each of the three seeds.", "", f"Across nine neutral full-match seat controls (identical AI, Balanced traits, colors/RNG streams rotated), the old winners by seat were **{summary['neutral_seat_controls_before']['seat_wins']}**. The right seat is an observed location advantage, not a Coral-only stat. Full seat controls remap private terrain/queen chambers to the physical vertex and check open-tunnel state throughout.", "", f"Nine matched original-trait/direct-swap games yielded old winning profiles **{summary['trait_wins_before']}**. Moving the Raider profile sometimes moved the winner, but it was not the sole cause. After the changes, the corresponding winning profiles are **{summary['trait_wins_after']}**. These are partial, paired swaps across three seeds, not a complete factorial estimate of trait power. The post-change trait matrix combines the role and route changes, so it does not assign a precise share of the outcome shift to either one. The all-Balanced, fixed-seat matrix separately measures routing without the Raider change or seeded placement.", "", "The old Raider bonus affected every collector as well as guards and raiders. A small bite increase can cross a discrete hit-count threshold: with independent uniform damage rolls from 0.85 to 1.15, three normal bites reach three health about 50% of the time; multiplying every bite by 1.05 raises that calculation to about 82.1%. This illustrates a damage breakpoint, not a measured duel win probability.", "", "The shipped Raider profile specializes combat jobs: Invaders, Guards and Wardens retain ×1.05 bite and 34px pursuit. Collectors, diggers, returning and recovering workers use standard bite/pursuit. Health, cargo, cooldowns and the 15% upkeep premium remain unchanged. Inspector/trait text and native/reference rules agree. Traits keep a tactical distinction without giving every foraging contact a combat bonus.", "", "The AI may use a third food site when its score is within 5% of the second. The labor fraction stays the same; nearby food, carriers, scent sensing and each ant's local combat remain individual. This removes automatic exclusion of one of three near-equivalent routes. It does not erase the physical location effect.", "", "Starting vertices now vary deterministically with the map seed using a separate map RNG. This removes the permanent color-to-seat association. Physical food sites remain fixed; traits and ant RNG streams do not choose or pay for seats. Tunnel chambers, private grids, spawn locations, drawing, camera and digging follow the assigned nest. Legacy two-colony fixtures and fixed-seat diagnostic controls remain available. No winner is scripted or rotated based on game results.", "", "## Same fifteen matches", "", "| Stage | Amber wins | Coral wins | Azure wins | Unresolved |", "| --- | ---: | ---: | ---: | ---: |"]
    for label, data in (("Before", summary["before"]), ("Role/route changes, fixed seats (retained trial)", summary["fixed_seat_trial"]), ("Shipped: role/route changes + seeded seats", summary["after"])):
        lines.append(f"| {label} | {' | '.join(map(str,data['wins']))} | {data['unresolved']} |")
    lines += ["", "Wins require a sole surviving queen. Unresolved games are censored at the horizon, not draws or worker-lead wins. Three world seeds recur across trait/controller/mirror configurations, so these fifteen matches are not fifteen independent random maps. Seat assignment is intentionally part of the changed map setup; it was fixed before the final replay, without tuning its RNG to individual winners.", "", "| Setup | Before wins A/C/Z | After wins A/C/Z | Unresolved before / after |", "| --- | --- | --- | --- |"]
    for group in dict.fromkeys(r["group"] for r in before):
        b,a=(tally([r for r in rows if r["group"]==group]) for rows in (before,after))
        lines.append(f"| {group} | {'/'.join(map(str,b['wins']))} | {'/'.join(map(str,a['wins']))} | {b['unresolved']} / {a['unresolved']} |")
    old={key(r):r for r in before}
    lines += ["", "| Setup / seed / traits | Before winner / min | After winner / min | Seed seat offset |", "| --- | --- | --- | ---: |"]
    for r in after:
        b=old[key(r)]
        lines.append(f"| {r['group']} / {r['seed']} / {r['traits']} | {outcome(b)} / {b['final']['seconds']/60:.2f} | {outcome(r)} / {r['final']['seconds']/60:.2f} | {r['samples'][0]['starting_seat_offset']} |")
    lines += ["", "Default unattended cases have unequal controllers; compare the equal-AI cohorts separately before attributing their winners to trait balance. The retained fixed-seat trial is included because the first color-win reduction alone did not reduce Coral's equal-AI win count. The remaining unresolved cases are reported as an endgame limitation rather than omitted.", "", "## Fixed-seat controls after the changes", "", f"Neutral seat winners after: **{summary['neutral_seat_controls_after']['seat_wins']}**, unresolved {summary['neutral_seat_controls_after']['unresolved']}. These controls deliberately disable seeded placement so the actual physical-seat effect remains visible.", "", "| Group / seed / offset / traits | Before winner | After winner |", "| --- | --- | --- |"]
    pc={ctrl_key(r):r for r in pre}
    for r in post: lines.append(f"| {r['group']} / {r['seed']} / {r['offset']} / {r['traits']} | {outcome(pc[ctrl_key(r)])} | {outcome(r)} |")
    lines += ["", "## Surface-foraging controls", "", "Nine 300-second surface controls per condition rotate colors/RNG streams through each seat with Balanced traits, no births and no invasions. Guided cases retain the AI guard posts as well as food orders. Means below are living workers by physical seat, not wins. Unguided workers still use individual food sensing, pheromones and combat. Position differences persisting without colony orders rule out AI planning as the sole cause. The rectangular world, grid, route orientation and initial random streams remain interacting factors; this study does not isolate each one.", "", "| Condition | Left | Right | Lower |", "| --- | ---: | ---: | ---: |"]
    for label,v in summary["surface_mean_survivors_by_left_right_lower"].items(): lines.append(f"| {label} | {' | '.join(map(str,v))} |")
    lines += ["", "The three-route guided cases have fewer mean survivors than the old guided cases in these surface controls. They remove an arbitrary source-selection exclusion and change match outcomes, but are not presented as a colony-survival improvement or an elimination of all spatial bias.", "", "## Unseen-seed check", "", "Seeds 23, 101 and 2026 were fixed before running the checks and not used to choose the changes. All colonies are Balanced with identical AI. Before uses saved two-route AI and fixed seats; after uses the shipped AI/seeded seats. The current native kernel is valid for both because Balanced combat is unchanged. These checks assess the combined AI/placement change without the Raider modification.", "", "| Seed | Before winner / min | After winner / min | After offset |", "| ---: | --- | --- | ---: |"]
    holds={label:read(f"coral_holdouts_{label}.json") for label in ("before","after")}
    assert all(d["complete"] for d in holds.values())
    for d in holds.values(): validate(d["runs"])
    summary["holdouts"]={label:{"wins":[sum(r["winner"]==c for r in d["runs"]) for c in range(3)], "unresolved":sum(r["winner"]==-2 for r in d["runs"])} for label,d in holds.items()}
    hb={r['seed']:r for r in holds['before']['runs']}
    for r in holds['after']['runs']:
        b=hb[r['seed']]
        lines.append(f"| {r['seed']} | {outcome(b)} / {b['final']['seconds']/60:.2f} | {outcome(r)} / {r['final']['seconds']/60:.2f} | {r['samples'][0]['starting_seat_offset']} |")
    lines += ["", "The unseen neutral controls retain a Coral edge in this small sample. Main-seed improvements should therefore be read alongside these holdouts and the remaining censored matches, rather than as proof of universal balance.", "", "## Performance and verification", "", "All fifteen regression suites pass. Dedicated tests cover role-specific damage and pursuit in native and reference implementations, the displayed bite value, identical labor budgets, seeded seat replay/coverage, unchanged worker RNG during map selection, actual nest spawns and connected tunnels at every seat. Existing per-ant movement/RNG, food, cargo, healing, combat, digging and invasion checks still run.", "", "Timing runs occur after all diagnostic jobs finish. The same compact-map centroid battle fixture is used at 2,000 ants/colony, 1440×900, GL Compatibility, VSync off. Every ant still updates at 30Hz per simulated second. Natural windows have changed battles/populations; synthetic windows provide the closer capacity check.", "", "| Workload | Before FPS | After FPS | After p95 ms | Actual speed | Target met |", "| --- | ---: | ---: | ---: | ---: | --- |"]
    perf=read('coral_performance_2000.json');base=read('endgame_performance_2000.json');assert perf['complete']
    for w in perf['windows']:
        assert not w['start']['invalid_state'] and not w['end']['invalid_state']
        b=next((x for x in base['windows'] if x['scenario']==w['scenario']),None)
        fps=f"{b['mean_fps']:.1f}" if b else '—'
        lines.append(f"| {w['scenario']} | {fps} | {w['mean_fps']:.1f} | {w['p95_ms']:.2f} | {w['actual_speed']:.2f}× | {'Yes' if w['target_met'] else 'No'} |")
    summary['performance_pass']=perf['all_targets_met']
    lines += ["", "Targets: ≥60 mean FPS, p95 ≤33.3ms and actual speed ≥3.9× at requested 4×. No ants are aggregated, skipped off-screen, made invulnerable or removed for scores. Natural growth remains separate from provisioned stress fixtures. No new claim is made at 3,200/colony.", "", "All recorded living-ID/open-tunnel checks and population ledgers pass. Source snapshots of the prior trait/AI rules are retained under tests/coral_baseline; raw prior endgame/map reports remain intact. The matrix reuses five previously measured identical configurations to complete its eighteen before-cases, with their source identified in the combined report.", "", "## Reproduce current version", "", "Use the supplied console executable with --path . and a writable absolute --log-file. Run timing alone after other jobs stop.", "", "```powershell", "./play.ps1 -Test", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --coral --shard=0/3", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --coral --shard=1/3", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --coral --shard=2/3", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --coral --mirrors-only", "# Fixed seats/trait swaps; repeat with --shard=1 and --shard=2:", "Godot_console.exe --headless --path . --script res://tests/coral_controls.gd -- --label=after --shard=0", "Godot_console.exe --headless --path . --script res://tests/coral_guided_control.gd", "Godot_console.exe --headless --path . --script res://tests/coral_holdouts.gd -- --baseline-ai", "Godot_console.exe --headless --path . --script res://tests/coral_holdouts.gd", "Godot_console.exe --path . --script res://tests/long_performance.gd -- --coral --target=2000", "python tests/analyze_coral.py", "```", "", "Raw files: coral_balance*, coral_fixed_balance*, coral_controls_before/after*, coral_unguided_control.json, coral_guided_after.json, coral_holdouts_before/after.json and coral_performance_2000.json. The diagnostic observer continues past the player's ordinary defeat to identify the last surviving queen; ordinary game result/time are still retained."]
    (ROOT/'CORAL_BALANCE_RESULTS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    write('coral_summary.json',summary)
    print(json.dumps(summary,indent=2))


if __name__=='__main__': main()
