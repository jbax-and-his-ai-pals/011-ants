extends RefCounted
## Explicit format-1 schema. UI objects and recomputable render/spatial caches are excluded.
const SIM := [
	"colony_count", "legacy_map_layout", "wide_map_layout", "fixed_starting_seats", "map_sites", "starting_seat_offset",
	"game_mode", "workers_per_colony", "world_seed", "swapped_sides", "tick_number", "layers",
	"route_goals", "invasions_enabled", "next_raids", "nest_quiet", "queen_damage", "queen_flashes",
	"queen_death_causes", "match_result", "result_dismissed", "doctrines", "food_stores", "upkeep_spent",
	"brood_spent", "queen_health", "queen_hungry", "egg_clocks", "births", "starvation_losses",
	"brood", "reproduction_enabled", "inspected_colony", "positions", "headings", "carrying",
	"cargo_resource", "protein_stores", "resource_delivered", "nutrition_weights", "chambers_enabled", "chamber_tool",
	"chamber_rooms", "brood_buffers", "nurse_load", "nurse_targets", "storage_flow", "exit_flow",
	"nest_entries", "tunnel_occupancy", "storage_capacity", "brood_capacity", "storage_released", "roles",
	"trips", "targets", "paths", "colonies", "colony_workers", "castes",
	"max_health", "foraging_multipliers", "native_enabled", "health", "attack_cooldowns", "opponents",
	"hit_flashes", "combat_damage", "remains", "casualties", "rival_delivered", "combat_enabled",
	"food_scent", "home_scent", "rival_food_scent", "rival_home_scent", "third_food_scent", "third_home_scent",
	"protein_scent", "rival_protein_scent", "third_protein_scent", "third_delivered", "third_earth", "earth",
	"rival_earth", "orders", "excavation", "foods", "garden_effects_enabled", "surface_speed",
	"surface_shade", "food_cycles_enabled", "flecks", "stones", "delivered", "dug",
	"elapsed", "underground", "paused", "trails_visible", "speed", "accumulator",
	"scent_clock", "allocation_clock", "message", "camera_center", "camera_zoom", "active_camera_layer",
	"camera_centers", "camera_zooms", "dig_mode", "selected_ant", "selected_info", "following",
	"worker_ids", "born_at", "deliveries", "worker_kills", "walked", "last_attackers",
	"next_worker_id", "active_scent", "scent_active", "designated_cells", "rival_ai_enabled", "inspected_ai",
	"command_tool", "worker_order_ids", "worker_order_kinds", "worker_order_goals", "avoid_points", "show_loss_hotspot",
	"HOME_CELL", "HOME", "RIVAL_HOME", "THIRD_HOME",
]
const COMMANDS := [
	"markers", "next_id", "labor", "history", "losses", "loss_head",
	"next_sample", "report", "hotspot", "assignments_present", "cargo_orders", "order_delivered",
	"order_resources",
]
const AI := [
	"enemy_id", "known", "selected", "next_think", "patch_cursor", "decisions",
	"mode", "reason", "recovering", "raid_until", "next_attack", "raid_roster",
	"raid_started", "raid_hard_until", "raid_queen_checkpoint", "raid_home_queen", "raid_status", "raid_counts",
	"raid_living", "raid_dead", "raid_inside", "raid_size", "raid_budget", "raid_phase",
	"raid_goal", "raid_evidence", "probe_arrived_at", "probe_failures", "escalation", "phase_counts",
	"home_threat", "source_scores", "route_contacts", "route_losses", "target_scores", "target_reason",
	"target_since", "target_sample_time", "threat_memory",
]
const NEST := [
	"pending", "progress", "dug", "projects", "project", "reason",
	"next_project", "widened", "guard_cell",
]
const CHAMBERS := [
	"dirty", "room_tiles", "nurse_workers", "storage_cells", "brood_cells", "buffered",
	"reserved", "room_cursor", "populations",
]
const PROGRESSION := [
	"paths", "soldier_counts", "preparation_reserves", "egg_sequence", "daughters", "ai_clock",
]
const SCOUTING := [
	"visible", "explored", "foods", "contacts", "tracks", "activity",
	"warnings", "routes", "rows", "cursor", "page", "scans",
]
const CLARITY := [
	"events", "cooldowns", "order_reasons", "order_states", "work_rows", "workforce",
	"warning_states", "ready_seen", "queen_ready_seen", "queen_danger", "last_result", "next_id",
	"page", "objective_step", "objective_text",
]
const CYCLE := [
	"next_arrival", "wave", "pending", "sites", "added", "added_resources",
]
const MODES := [
	"home_sites", "local_amounts",
]
const GARDEN := [
	"ground", "details",
]
const STRATEGY_MAP := [
	"pairs",
]
