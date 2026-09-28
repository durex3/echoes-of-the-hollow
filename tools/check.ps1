param([string]$GodotPath = '', [switch]$Visual, [switch]$Full)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$godotExe = Resolve-ProjectGodot $GodotPath
$projectRoot = Split-Path $PSScriptRoot -Parent
$artifacts = Join-Path $projectRoot 'artifacts'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $artifacts '.gdignore') -Force | Out-Null
$version = (& $godotExe --headless --version | Out-String).Trim()
if ($version -notmatch '^4\.7\.2\.') { throw "Expected Godot 4.7.2; got $version" }
Write-Output "Engine: $version"
python (Join-Path $PSScriptRoot 'static_check.py')
if ($LASTEXITCODE -ne 0) { throw 'Static project checks failed.' }

function Invoke-CheckedGodot {
    param([string]$Name, [string[]]$Arguments)
    $log = Join-Path $artifacts ($Name + '.log')
    & $godotExe --path $projectRoot --log-file $log @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE; see $log" }
    $contents = Get-Content -LiteralPath $log -Raw
    if ($contents -match '(?m)^(SCRIPT ERROR:|ERROR:|FAIL:)') {
        throw "$Name reported an engine/test error; see $log"
    }
    if ($Name -in @('integration','visual','current','current_visual') -and $contents -notmatch 'TEST_RESULT: \d+ checks, 0 failures') {
        throw "$Name runner did not finish."
    }
}

Invoke-CheckedGodot -Name 'import' -Arguments @('--headless','--editor','--import')
$staggerArgs = @('--headless','--fixed-fps','60','res://tests/enemy_stagger_suite.tscn')
if ($Visual) { $staggerArgs = @('--fixed-fps','60','--max-fps','60','res://tests/enemy_stagger_suite.tscn','--','--visual') }
Invoke-CheckedGodot -Name 'enemy_stagger' -Arguments $staggerArgs
$staggerLog = Get-Content -LiteralPath (Join-Path $artifacts 'enemy_stagger.log') -Raw
if ($staggerLog -notmatch 'ENEMY_STAGGER_RESULT: \d+ checks, 0 failures') { throw 'Enemy interruption and retaliation checks must complete.' }
Invoke-CheckedGodot -Name 'counter_damage' -Arguments @('--headless','--fixed-fps','60','res://tests/counter_damage_suite.tscn')
$counterLog = Get-Content -LiteralPath (Join-Path $artifacts 'counter_damage.log') -Raw
if ($counterLog -notmatch 'COUNTER_DAMAGE_RESULT: \d+ checks, 0 failures') { throw 'Stationary close-range counter damage checks must complete.' }
$aiArgs = @('--headless','--fixed-fps','60','res://tests/bell_ai_suite.tscn')
if ($Visual) { $aiArgs = @('--fixed-fps','60','--max-fps','60','res://tests/bell_ai_suite.tscn','--','--visual') }
Invoke-CheckedGodot -Name 'bell_ai' -Arguments $aiArgs
$aiLog = Get-Content -LiteralPath (Join-Path $artifacts 'bell_ai.log') -Raw
if ($aiLog -notmatch 'BELL_AI_RESULT: \d+ checks, 0 failures') { throw 'Third-chapter enemy decision checks must complete.' }
$chapterAiArgs = @('--headless','--fixed-fps','60','res://tests/chapter_enemy_ai_suite.tscn')
if ($Visual) { $chapterAiArgs = @('--fixed-fps','60','--max-fps','60','res://tests/chapter_enemy_ai_suite.tscn','--','--visual') }
Invoke-CheckedGodot -Name 'chapter_enemy_ai' -Arguments $chapterAiArgs
$chapterAiLog = Get-Content -LiteralPath (Join-Path $artifacts 'chapter_enemy_ai.log') -Raw
if ($chapterAiLog -notmatch 'CHAPTER_ENEMY_AI_RESULT: \d+ checks, 0 failures') { throw 'Chapter I and II enemy decision checks must complete.' }
$wallArgs = @('--headless','--fixed-fps','60','res://tests/wall_echo_metrics.tscn')
if ($Visual) { $wallArgs = @('--fixed-fps','60','--max-fps','60','res://tests/wall_echo_metrics.tscn','--','--visual') }
Invoke-CheckedGodot -Name 'wall_echo' -Arguments $wallArgs
$wallLog = Get-Content -LiteralPath (Join-Path $artifacts 'wall_echo.log') -Raw
if ($wallLog -notmatch 'WALL_ECHO_RESULT: \d+ checks, 0 failures') { throw 'Wall echo metrics and the native teaching loop must complete.' }
$bellArgs = @('--headless','--fixed-fps','60','res://tests/bell_court_suite.tscn')
if ($Visual) { $bellArgs = @('--fixed-fps','60','--max-fps','60','res://tests/bell_court_suite.tscn','--','--visual') }
Invoke-CheckedGodot -Name 'bell_court' -Arguments $bellArgs
$bellLog = Get-Content -LiteralPath (Join-Path $artifacts 'bell_court.log') -Raw
if ($bellLog -notmatch 'BELL_COURT_RESULT: \d+ checks, 0 failures' -or $bellLog -notmatch 'BELL_ROUTE_PASS:') { throw 'Third-chapter component and front-half route checks must complete.' }
Invoke-CheckedGodot -Name 'bell_court_baseline' -Arguments @('--headless','--fixed-fps','60','res://tests/bell_court_suite.tscn','--','--baseline')
$bellBaselineLog = Get-Content -LiteralPath (Join-Path $artifacts 'bell_court_baseline.log') -Raw
if ($bellBaselineLog -notmatch 'BELL_COURT_RESULT: \d+ checks, 0 failures' -or $bellBaselineLog -notmatch 'BELL_ROUTE_PASS:.*baseline=true') { throw 'Five HP, no ward front-half route must complete.' }
Invoke-CheckedGodot -Name 'bell_branch' -Arguments @('--headless','--fixed-fps','60','res://tests/bell_branch_suite.tscn')
$branchLog = Get-Content -LiteralPath (Join-Path $artifacts 'bell_branch.log') -Raw
if ($branchLog -notmatch 'BELL_BRANCH_RESULT: \d+ checks, 0 failures') { throw 'Both weight branches and real bridges must complete.' }
Invoke-CheckedGodot -Name 'bell_heart' -Arguments @('--headless','--fixed-fps','60','res://tests/bell_heart_suite.tscn')
$heartLog = Get-Content -LiteralPath (Join-Path $artifacts 'bell_heart.log') -Raw
if ($heartLog -notmatch 'BELL_HEART_RESULT: \d+ checks, 0 failures') { throw 'Optional bell heart route must complete.' }
Invoke-CheckedGodot -Name 'confluence_bridge' -Arguments @('--headless','--fixed-fps','60','res://tests/confluence_bridge_suite.tscn')
$confluenceLog = Get-Content -LiteralPath (Join-Path $artifacts 'confluence_bridge.log') -Raw
if ($confluenceLog -notmatch 'CONFLUENCE_RESULT: \d+ checks, 0 failures') { throw 'Confluence bridge composition must complete.' }
Invoke-CheckedGodot -Name 'bell_warden' -Arguments @('--headless','--fixed-fps','60','res://tests/bell_warden_suite.tscn')
$wardenLog = Get-Content -LiteralPath (Join-Path $artifacts 'bell_warden.log') -Raw
if ($wardenLog -notmatch 'BELL_WARDEN_RESULT: \d+ checks, 0 failures') { throw 'Bell warden phases and echo marks must complete.' }
if (-not $Full) {
    if ($Visual) {
        Invoke-CheckedGodot -Name 'current_visual' -Arguments @('--fixed-fps','60','--max-fps','60','res://tests/test_runner.tscn','--','--current','--visual')
    } else {
        Invoke-CheckedGodot -Name 'current' -Arguments @('--headless','--fixed-fps','60','res://tests/test_runner.tscn','--','--current')
    }
    Write-Output 'Current chapter checks passed. Use -Full for complete regression.'
    return
}
Invoke-CheckedGodot -Name 'integration' -Arguments @('--headless','--fixed-fps','60','res://tests/test_runner.tscn')
Invoke-CheckedGodot -Name 'chapter_route' -Arguments @('--headless','--fixed-fps','60','res://tests/chapter_route.tscn')
$routeLog = Get-Content -LiteralPath (Join-Path $artifacts 'chapter_route.log') -Raw
if ($routeLog -notmatch 'ROUTE_PASS: combat_first' -or $routeLog -notmatch 'ROUTE_PASS: wind_first') { throw 'Both continuous chapter routes must complete.' }
Invoke-CheckedGodot -Name 'chapter_two_route' -Arguments @('--headless','--fixed-fps','60','res://tests/chapter_two_route.tscn')
$secondRouteLog = Get-Content -LiteralPath (Join-Path $artifacts 'chapter_two_route.log') -Raw
if ($secondRouteLog -notmatch 'CHAPTER_TWO_PASS: flow_first' -or $secondRouteLog -notmatch 'CHAPTER_TWO_PASS: pressure_first') { throw 'Both Chapter II branch orders must complete.' }
Invoke-CheckedGodot -Name 'cistern_exploration' -Arguments @('--headless','--fixed-fps','60','res://tests/cistern_exploration_route.tscn')
$explorationLog = Get-Content -LiteralPath (Join-Path $artifacts 'cistern_exploration.log') -Raw
if ($explorationLog -notmatch 'CISTERN_EXPLORATION_PASS:') { throw 'Optional exploration and return loop must complete.' }
Invoke-CheckedGodot -Name 'save_write' -Arguments @('--headless','--script','res://tests/save_process.gd','--','--write')
Invoke-CheckedGodot -Name 'save_read' -Arguments @('--headless','--script','res://tests/save_process.gd','--','--read')
Invoke-CheckedGodot -Name 'chapter_two_save_write' -Arguments @('--headless','--script','res://tests/chapter_two_save_process.gd','--','--write')
Invoke-CheckedGodot -Name 'chapter_two_save_read' -Arguments @('--headless','--script','res://tests/chapter_two_save_process.gd','--','--read')
Invoke-CheckedGodot -Name 'language_write' -Arguments @('--headless','--script','res://tests/settings_process.gd','--','--write')
Invoke-CheckedGodot -Name 'language_read' -Arguments @('--headless','--script','res://tests/settings_process.gd','--','--read')
if ($Visual) {
    Invoke-CheckedGodot -Name 'visual' -Arguments @('--fixed-fps','60','--max-fps','60','res://tests/test_runner.tscn','--','--visual')
}
Write-Output 'All required checks passed.'
