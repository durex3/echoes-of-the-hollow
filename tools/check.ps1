param([string]$GodotPath = '', [switch]$Visual)
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
    if ($Name -in @('integration','visual') -and $contents -notmatch 'TEST_RESULT: \d+ checks, 0 failures') {
        throw "$Name runner did not finish."
    }
}

Invoke-CheckedGodot -Name 'import' -Arguments @('--headless','--editor','--import')
Invoke-CheckedGodot -Name 'integration' -Arguments @('--headless','--fixed-fps','60','res://tests/test_runner.tscn')
Invoke-CheckedGodot -Name 'save_write' -Arguments @('--headless','--script','res://tests/save_process.gd','--','--write')
Invoke-CheckedGodot -Name 'save_read' -Arguments @('--headless','--script','res://tests/save_process.gd','--','--read')
if ($Visual) {
    Invoke-CheckedGodot -Name 'visual' -Arguments @('--fixed-fps','60','--max-fps','60','res://tests/test_runner.tscn','--','--visual')
}
Write-Output 'All required checks passed.'
