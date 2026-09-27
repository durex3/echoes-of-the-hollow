param([string]$GodotPath = '', [switch]$Baseline)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$godotExe = Resolve-ProjectGodot $GodotPath
$projectRoot = Split-Path $PSScriptRoot -Parent
$arguments = @('--path', $projectRoot, 'res://features/world/prototypes/bell_court_preview.tscn')
if ($Baseline) { $arguments += @('--', '--baseline') }
& $godotExe @arguments
