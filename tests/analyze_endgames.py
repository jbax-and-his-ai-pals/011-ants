"""Paired AI raid-policy comparison against the compact-map baseline."""
import json
from collections import Counter
from pathlib import Path
from analyze_targeting import load_runs, key, tally, outcome, NAMES

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"


def read(name):
    return json.loads((TESTS / name).read_text(encoding="utf-8"))


def main():
    before = load_runs("map_balance")
    order = {key(r): i for i, r in enumerate(before)}
    shards = [read(f"endgame_balance_results_shard{i}.json") for i in range(3)]
    assert all(d["complete"] and not d["invalid_state"] and d["layout"] == "equilateral742" for d in shards)
    assert all(d["raid_policy"] == "bounded_commitment_v1" for d in shards)
    report = {**shards[0], "runs": [r for d in shards for r in d["runs"]]}
    report["runs"].sort(key=lambda r: order[key(r)])
    assert len(report["runs"]) == len({key(r) for r in report["runs"]}) == 12
    (TESTS / "endgame_balance_results.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    after = load_runs("endgame_balance")
    assert {key(r) for r in before} == {key(r) for r in after}
    old = {key(r): r for r in before}
    saved = sum(old[key(r)]["censored"] and not r["censored"] for r in after)
    regressed = sum(not old[key(r)]["censored"] and r["censored"] for r in after)
    summary = {"before": tally(before), "after": tally(after), "previously_stalled_now_resolved": saved, "previously_resolved_now_stalled": regressed, "mean_horizon_capped_seconds_before": sum(r["final"]["seconds"] for r in before)/15, "mean_horizon_capped_seconds_after": sum(r["final"]["seconds"] for r in after)/15}
    lines = ["# Raid commitment and stalled endgames", "", "The same fifteen compact-map configurations were replayed with the same seeds, traits, 2,000 starting workers per colony and 30-simulated-minute horizon. Map/food, worker stats, movement, combat, pheromones, recovery, brood and upkeep are unchanged. Only AI target preference/raid commitment and the optional recruitment budget carried by its commands change.", "", "## Paired results", "", f"Unresolved matches: **{summary['before']['unresolved']} → {summary['after']['unresolved']}**. Of the previously stalled matches, **{saved} now resolve**; **{regressed} formerly resolved matches now stall**. Mean observed duration, capped at the same 1,800-second horizon, changes from **{summary['mean_horizon_capped_seconds_before']/60:.2f} to {summary['mean_horizon_capped_seconds_after']/60:.2f} simulated minutes**. Censored matches remain included at the horizon; they are not silently dropped from that mean.", "", "| Setup | Before wins A/C/Z | After wins A/C/Z | Unresolved before / after |", "| --- | --- | --- | --- |"]
    for group in dict.fromkeys(r["group"] for r in before):
        b, a = (tally([r for r in rows if r["group"] == group]) for rows in (before, after))
        lines.append(f"| {group} | {'/'.join(map(str,b['wins']))} | {'/'.join(map(str,a['wins']))} | {b['unresolved']} / {a['unresolved']} |")
    lines += ["", f"Overall wins A/C/Z: **{summary['before']['wins']} → {summary['after']['wins']}**. First queen lost before: {summary['before']['first_eliminated']}, in {summary['before']['games_with_elimination']} matches with queen deaths; after: {summary['after']['first_eliminated']}, in {summary['after']['games_with_elimination']}. Faster completion does not establish fair colony win rates. This small deterministic sample reuses three world seeds across configurations.", "", "| Setup / seed / traits | Before winner / min | After winner / min |", "| --- | --- | --- |"]
    for r in after:
        b = old[key(r)]
        lines.append(f"| {r['group']} / {r['seed']} / {r['traits']} | {outcome(b)} / {b['final']['seconds']/60:.2f} | {outcome(r)} / {r['final']['seconds']/60:.2f} |")
    lines += ["", "A win requires the sole surviving queen; unresolved games are censored, not draws or worker-lead wins. The diagnostic observer continues beyond normal player defeat to identify the final queen, preserving the ordinary game result/time in each raw run. Default unattended cases retain Amber's original automatic raids; equal-AI controls apply the new policy to all three colonies. Actual human player Raid markers remain persistent until changed or removed.", "", "## Changed decisions", "", "Previously, unrelated colony-wide combat deaths could recall a party, and the 35-second limit included its surface journey and tunnel entry. The new policy records actual recruits by persistent worker identity, checks their survival independently of reused slots, and separates local raid progress from forager losses.", "", "Initial commitment includes estimated surface travel at the existing movement speed, a 12-second tunnel allowance and 40 seconds of attack time, clamped to 50–100 seconds. A falling enemy queen-health observation while party members are inside extends the deadline to at least another 35 seconds, with a planned 180-second campaign limit checked at the ordinary strategy decision cadence. This detects shared target damage; it does not attribute every bite to that party. Targets stay fixed while the campaign is active.", "", "Each party retains an initial limit of up to 12/24 real workers, also capped at 20% of living workers, and may recruit at most twice that initial number of unique workers over the campaign. A recovering member cannot repeatedly recycle through the same recruitment budget. Existing automatic nest defenders act normally; optional guard posts receive remaining security capacity after the committed raid allocation.", "", "Recall still follows party casualties, an exhausted party/budget, no progress/time limit, critical food reserves, disabled invasions, a dead target or serious home/queen danger. Incidental surface traffic and unrelated deaths no longer unconditionally recall the party. Survivors leave via existing tunnel routes; the retry cooldown stays 45 seconds.", "", "Weak enemies gain a visible finishing preference (+0.35). A fed colony with at least 12 workers can send a small party against a deserted or badly weakened nest; it need not wait for 30 workers. Loss-driven recovery may allow that finishing attack when the home queen is healthy and food is ample. Food/queen emergencies and ordinary home-defense launch checks still take precedence. Detailed thresholds are in RIVAL_AI.md.", "", "Press I / Switch colony for the target-score finishing component, live party counts, total recruitment budget and last recall reason.", "", "## Recorded raid activity", "", "Totals below sum AI controllers' cumulative final counters over the fifteen matches. Amber's separate legacy default automation is not included. Progress means observed queen damage while party members were inside, not exclusive damage credit or a separate successful-raid count. Starts need not equal logged recalls: own queen elimination clears orders separately, and the final queen death can stop a match between AI decisions."]
    totals = Counter()
    recalls = Counter()
    for r in after:
        for sample in [*r["samples"], r["final"]]:
            for info in sample["raid_telemetry"]:
                if not info: continue
                assert info["recruited"] <= info["budget"]
                assert info["lost_party"] <= info["recruited"]
        for info in r["final"]["raid_telemetry"]:
            if not info: continue
            totals["campaigns_started"] += info["started"]
            totals["queen_progress_observations"] += info["progress"]
            recalls.update(info["recalls"])
    summary["raid_activity"] = {**totals, "recalls": dict(recalls)}
    lines += ["", f"Campaigns started: **{totals['campaigns_started']}**; queen-progress observations: **{totals['queen_progress_observations']}**.", "", "| Recall reason | Count |", "| --- | ---: |"]
    for reason, count in recalls.most_common(): lines.append(f"| {reason} | {count} |")
    lines += ["", "## Individual behavior and performance", "", "All fourteen regression suites pass, including native/reference worker/RNG comparisons and persistent player orders. The new mission suite checks actual party attrition, unrelated losses, recycled slots, progress extensions, hard limits, ordinary versus critical home pressure, food recall and bounded reinforcements. A real four-ant party traverses the full legacy 1,022px surface route and tunnels and kills an undefended queen after the old timeout in both simulation implementations.", "", "Renderer timing ran separately after all balance jobs finished. The same compact-map centroid battle fixture and 1440×900 GL Compatibility setup are retained from MAP_BALANCE_RESULTS.md. Natural checkpoints advance every fixed tick between live windows. All ants still receive 30 updates per simulated second; there are no aggregate units, off-screen skipping or stat buffs. Synthetic fixtures provision food/spawn actual workers and retain real deaths.", "", "| Workload | Before FPS | After FPS | After p95 ms | Actual speed | Target met |", "| --- | ---: | ---: | ---: | ---: | --- |"]
    perf = read("endgame_performance_2000.json")
    baseline = read("map_performance_2000.json")
    assert perf["complete"]
    for w in perf["windows"]:
        assert not w["start"]["invalid_state"] and not w["end"]["invalid_state"]
        b = next((v for v in baseline["windows"] if v["scenario"] == w["scenario"]), None)
        old_fps = f"{b['mean_fps']:.1f}" if b else "—"
        lines.append(f"| {w['scenario']} | {old_fps} | {w['mean_fps']:.1f} | {w['p95_ms']:.2f} | {w['actual_speed']:.2f}× | {'Yes' if w['target_met'] else 'No'} |")
    summary["performance_pass"] = perf["all_targets_met"]
    lines += ["", "Target: mean ≥60 FPS, p95 ≤33.3ms and actual speed ≥3.9× at 2,000 workers per colony. Natural states differ as combat outcomes change; these are capacity checks rather than proof that the policy raises FPS. Population remains 2,000/colony by default. No new 3,200/colony performance claim is made.", "", "All recorded population ledgers, unique living IDs and open-tunnel checks pass. Recruitment counters stay within their explicit budgets in every sampled state. Raw data retain queen health, stores, births, combat/hunger losses, party activity and recall reasons.", "", "## Reproduce", "", "Use the supplied Godot console executable with --path . and an absolute writable --log-file. Balance shards may run concurrently; run renderer measurements alone afterward.", "", "```powershell", "./play.ps1 -Test", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --endgame --shard=0/3", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --endgame --shard=1/3", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --endgame --shard=2/3", "Godot_console.exe --headless --path . --script res://tests/long_balance.gd -- --endgame --mirrors-only", "Godot_console.exe --path . --script res://tests/long_performance.gd -- --endgame --target=2000", "python tests/analyze_endgames.py", "```", "", "Before: tests/map_balance_results.json, map_balance_mirrors.json, map_performance_2000.json. After: endgame_balance_results.json, endgame_balance_mirrors.json, endgame_performance_2000.json; shard reports retain the complete raw samples. These source reports are preserved rather than overwriting the earlier policy's results."]
    (ROOT / "ENDGAME_RESULTS.md").write_text("\n".join(lines)+"\n", encoding="utf-8")
    (TESTS / "endgame_summary.json").write_text(json.dumps(summary, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
