"""Summarize paired earned-resource Founding runs; diagnostic continuation is separate."""
from pathlib import Path
import json, statistics, sys
ROOT = Path(__file__).resolve().parent

def median(values):
    values = [v for v in values if v >= 0]
    return round(statistics.median(values), 1) if values else None

def summarize(data):
    result = {"configurations": len(data["runs"]), "complete": data["complete"], "paths": {}, "rivals": {}, "invalid_samples": sum(r["invalid"] for r in data["runs"])}
    for path in (1, 2):
        runs = [r for r in data["runs"] if r["path"] == path]
        result["paths"][str(path)] = {
            "matches": len(runs), "wins": sum(0 in r["first_winners"] for r in runs),
            "unresolved": sum(not r["first_result"] for r in runs),
            "median_match_seconds": median([r["first_finish"] for r in runs]),
            "daughter_starts_by_horizon": sum(r["colonies"][0]["start"] >= 0 for r in runs),
            "diagnostic_launches_by_horizon": sum(r["colonies"][0]["launch"] >= 0 for r in runs),
            "median_start_seconds": median([r["colonies"][0]["start"] for r in runs]),
            "median_diagnostic_launch_seconds": median([r["colonies"][0]["launch"] for r in runs]),
            "mean_start_protein_wait_seconds": round(statistics.mean(r["colonies"][0]["development_wait"].get("Need 20 unallocated protein", 0) for r in runs), 1),
        }
    for colony in (1, 2):
        ants = [r["colonies"][colony] for r in data["runs"]]
        result["rivals"][str(colony)] = {
            "colonies": len(ants), "real_match_wins": sum(colony in r["first_winners"] for r in data["runs"]),
            "started_before_match_end": sum(0 <= r["colonies"][colony]["start"] <= r["first_finish"] for r in data["runs"]),
            "diagnostic_launches_by_horizon": sum(a["launch"] >= 0 for a in ants),
            "still_developing_at_horizon": sum(a["launch"] < 0 and a["start"] >= 0 and a["death"] < 0 for a in ants),
            "never_started_alive": sum(a["start"] < 0 and a["death"] < 0 for a in ants),
            "eliminated_before_launch": sum(a["launch"] < 0 and a["death"] >= 0 for a in ants),
            "median_start_seconds": median([a["start"] for a in ants]),
            "median_diagnostic_launch_seconds": median([a["launch"] for a in ants]),
        }
    result["total_start_protein_wait_seconds"] = sum(a["development_wait"].get("Need 20 unallocated protein", 0) for r in data["runs"] for a in r["colonies"])
    result["never_started_colonies"] = sum(a["start"] < 0 for r in data["runs"] for a in r["colonies"])
    return result

if __name__ == "__main__":
    prefix = "clarity_matches" if "--clarity" in sys.argv else "founding_progression"
    report = {"note": "First winner is actual match outcome; later launches are diagnostic observations sampled every 3 seconds, not additional wins. No-start or unfinished projects at 1800 seconds are censored, not guaranteed permanent stalls.", "summaries": {}}
    for label in ("before", "after"):
        path = ROOT / f"{prefix}_{label}.json"
        if path.exists(): report["summaries"][label] = summarize(json.loads(path.read_text(encoding="utf-8")))
    if set(report["summaries"]) == {"before", "after"} and all(v["complete"] for v in report["summaries"].values()):
        before = json.loads((ROOT / f"{prefix}_before.json").read_text(encoding="utf-8"))
        after = json.loads((ROOT / f"{prefix}_after.json").read_text(encoding="utf-8"))
        keyed = {(r["seed"], r["path"]): r for r in before["runs"]}
        assert set(keyed) == {(r["seed"],r["path"]) for r in after["runs"]}
        report["paired"] = {
            "same_first_winners": sum(r["first_winners"] == keyed[r["seed"],r["path"]]["first_winners"] for r in after["runs"]),
            "new_daughter_starts": sum(keyed[r["seed"],r["path"]]["colonies"][c]["start"] < 0 <= r["colonies"][c]["start"] for r in after["runs"] for c in range(3)),
            "lost_daughter_starts": sum(r["colonies"][c]["start"] < 0 <= keyed[r["seed"],r["path"]]["colonies"][c]["start"] for r in after["runs"] for c in range(3)),
        }
    (ROOT / ("clarity_comparison.json" if "--clarity" in sys.argv else "founding_progression_comparison.json")).write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
