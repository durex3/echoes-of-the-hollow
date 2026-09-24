function Resolve-ProjectGodot {
    param([string]$ExplicitPath = '')
    $candidates = @(
        $ExplicitPath,
        $env:GODOT_BIN,
        'E:\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe',
        'C:\Users\liuge\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'Godot not found. Pass -GodotPath or set GODOT_BIN to the Godot 4.7.2 executable.'
}
