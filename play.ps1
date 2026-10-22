param(
    [switch]$Editor,
    [switch]$Test,
    [string]$GodotPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot executable not found. Supply its location with -GodotPath C:\path\to\Godot_console.exe'
}
$logRoot = Join-Path $projectRoot '.godot'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$engineArguments = @('--path', $projectRoot, '--log-file', (Join-Path $logRoot 'play.log'))
if ($Test) {
    foreach ($testScript in @('res://tests/simulation_test.gd', 'res://tests/combat_test.gd', 'res://tests/nursery_test.gd', 'res://tests/invasion_test.gd', 'res://tests/input_test.gd', 'res://tests/navigation_test.gd', 'res://tests/scale_test.gd', 'res://tests/native_test.gd', 'res://tests/gameplay_test.gd', 'res://tests/rival_ai_test.gd', 'res://tests/three_colony_test.gd', 'res://tests/targeting_test.gd', 'res://tests/map_layout_test.gd', 'res://tests/raid_commitment_test.gd', 'res://tests/coral_balance_test.gd', 'res://tests/food_cycle_test.gd', 'res://tests/garden_test.gd', 'res://tests/nutrition_test.gd', 'res://tests/chambers_test.gd', 'res://tests/nest_planner_test.gd', 'res://tests/game_modes_test.gd', 'res://tests/founding_logistics_test.gd', 'res://tests/scouting_test.gd', 'res://tests/raid_escalation_test.gd', 'res://tests/progression_test.gd', 'res://tests/founding_progression_reserve_test.gd', 'res://tests/clarity_test.gd', 'res://tests/strategic_garden_test.gd', 'res://tests/save_load_test.gd')) {
        & $GodotPath @engineArguments --headless --script $testScript --quit-after 600
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    exit 0
} elseif ($Editor) {
    $engineArguments += '--editor'
}
& $GodotPath @engineArguments
exit $LASTEXITCODE
