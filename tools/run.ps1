param([string]$GodotPath = '', [switch]$Editor)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$godotExe = Resolve-ProjectGodot $GodotPath
$projectRoot = Split-Path $PSScriptRoot -Parent
if ($Editor) { & $godotExe --path $projectRoot --editor }
else { & $godotExe --path $projectRoot }
