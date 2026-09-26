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
