extends SceneTree
const SEEDS := [81923, 404, 9973, 17, 73, 2026, 1337, 9001]
var output := "res://tests/founding_progression_before.json"
var report := {"seeds": SEEDS, "horizon": 1800, "complete": false, "runs": [], "method": "Paired scripted Amber development paths. Actual first outcome recorded; diagnostic continuation after the match observes rival feasibility. No resource/worker grants. Player queues a real brood chamber at 80 workers and issues no raids. Both rival strategic controllers remain active."}
func _initialize() -> void: call_deferred("run")
func save() -> void: FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--after": output = "res://tests/founding_progression_after.json"
	if "--clarity" in OS.get_cmdline_user_args(): output = "res://tests/clarity_matches_after.json"
	var s = load("res://tests/founding_progression_observer.gd").new(); root.add_child(s); s.set_process(false)
	for seed_value in SEEDS:
		for path in [1,2]:
			s.game_modes.start(1,seed_value); s.next_raids[0] = INF
			var colonies := []
			for c in 3: colonies.append({"choice": -1.0, "start": -1.0, "launch": -1.0, "death": -1.0, "peak_workers": 12, "peak_soldiers": 0, "blocked_seconds": {}, "development_wait": {}, "snapshots": []})
			var row := {"seed": seed_value, "path": path, "colonies": colonies, "invalid": 0}
			var planned := false
			for tick in 54000:
				if tick % 90 == 0:
					if s.progression.paths[0] == 0: s.progression.choose(0,path)
					if not planned and s.living_count(0) >= 80:
						s.chambers.designate(s.chamber_cell(0)+Vector2i(7,0),s.chambers.BROOD,true,false); planned = true
					if s.progression.daughters[0].is_empty(): s.progression.start_daughter(0)
				s.simulate(s.STEP)
				if tick % 90 == 0:
					for c in 3:
						var a: Dictionary = colonies[c]; var d: Dictionary = s.progression.daughters[c]
						var pop: int = s.living_count(c)
						a.peak_workers = maxi(a.peak_workers,pop); a.peak_soldiers = maxi(a.peak_soldiers,s.progression.soldier_counts[c])
						if a.choice < 0 and s.progression.paths[c] != 0: a.choice = s.elapsed
						if a.start < 0 and not d.is_empty(): a.start = s.elapsed
						if a.launch < 0 and d.get("complete",false): a.launch = s.elapsed
						if a.death < 0 and s.queen_health[c] <= 0: a.death = s.elapsed
						if s.queen_health[c] > 0 and a.launch < 0:
							var bucket: Dictionary = a.development_wait if d.is_empty() else a.blocked_seconds
							var reason: String = s.progression.queen_reason(c) if d.is_empty() else d.status
							bucket[reason] = bucket.get(reason,0.0) + 3.0
						if tick % 900 == 0:
							a.snapshots.append({"time": s.elapsed, "workers": pop, "soldiers": s.progression.soldier_counts[c], "sugar": s.food_stores[c], "protein": s.protein_stores[c], "free_protein": s.progression.free_protein(c), "buffered": s.chambers.buffered[c], "reserved": s.chambers.reserved[c], "capacity": s.brood_capacity[c], "brood": s.brood[c].size(), "delivered": [s.resource_delivered[c*2],s.resource_delivered[c*2+1]], "combat": s.casualties[c], "hunger": s.starvation_losses[c], "daughter": d.duplicate(true)})
							if pop != 12+s.births[c]-s.casualties[c]-s.starvation_losses[c] or s.protein_stores[c]+.01 < s.chambers.buffered[c]+s.chambers.reserved[c] or s.food_stores[c]+s.protein_stores[c] > s.storage_capacity[c]+.01: row.invalid += 1
					if colonies.all(func(a): return a.launch >= 0 or a.death >= 0): break
			row["events_retained"] = s.clarity.events.size(); row["max_clarity_ms"] = s.clarity.max_sample_usec/1000.0
			row["seconds"] = s.elapsed; row["first_result"] = s.first_result; row["first_finish"] = s.first_finish; row["first_winners"] = s.first_winners.duplicate(); row["first_snapshot"] = s.first_snapshot.duplicate(true)
			row["paths"] = Array(s.progression.paths)
			report.runs.append(row); save()
			print("MATCH seed=%d path=%d finish=%.1f winners=%s starts=%s launches=%s deaths=%s invalid=%d" % [seed_value,path,s.first_finish,s.first_winners,colonies.map(func(a):return snappedf(a.start,.1)),colonies.map(func(a):return snappedf(a.launch,.1)),colonies.map(func(a):return snappedf(a.death,.1)),row.invalid])
	report.complete = true; save(); quit()
