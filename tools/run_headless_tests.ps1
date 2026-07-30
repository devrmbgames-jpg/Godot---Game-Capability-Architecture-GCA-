$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$GodotBin = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "godot" }
& $GodotBin --headless --path $ProjectRoot
exit $LASTEXITCODE
