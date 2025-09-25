Param(
    [switch]$Run,
    [switch]$Editor,
    [string]$MapNumber,
    [string[]]$ExtraArgs
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$godotExe = Join-Path $root "Godot_v4.4.1-stable_win64.exe"
$projectDir = Join-Path $root "test_proj"
if (-not (Test-Path $godotExe)) { Write-Error "Godot executable not found: $godotExe"; exit 1 }
if (-not (Test-Path $projectDir)) { Write-Error "Project directory not found: $projectDir"; exit 1 }
$argsList = @("--path", $projectDir)
$mode = "Run"
if ($Editor) { $mode = "Editor" }
if ($Run) { $mode = "Run" }
if ($mode -eq "Editor") { $argsList += "--editor" }
if ($MapNumber) { $argsList += @("--", "--map=$MapNumber") }
if ($ExtraArgs) { $argsList += $ExtraArgs }
Start-Process -FilePath $godotExe -ArgumentList $argsList

