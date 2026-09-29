param([string]$GodotPath = '', [switch]$Baseline, [switch]$Boss)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$godotExe = Resolve-ProjectGodot $GodotPath
$projectRoot = Split-Path $PSScriptRoot -Parent
$arguments = @('--path', $projectRoot, 'res://features/world/prototypes/bell_court_preview.tscn')
if ($Baseline) { $arguments += @('--', '--baseline') }
if ($Boss) {
	if ($Baseline) { $arguments = @('--path', $projectRoot, 'res://features/world/prototypes/bell_court_preview.tscn', '--', '--baseline', '--boss') }
	else { $arguments += @('--', '--boss') }
}
& $godotExe @arguments
