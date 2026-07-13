param(
  [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$bin = Join-Path $env:USERPROFILE ".rokit\bin"
$artifacts = Join-Path $root "artifacts"

Set-Location $root

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Tool,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
  )

  & (Join-Path $bin "$Tool.exe") @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Tool failed with exit code $LASTEXITCODE"
  }
}

if (-not $SkipInstall) {
  Invoke-Checked "wally" "install"
}

Invoke-Checked "rojo" "sourcemap" "default.project.json" "--include-non-scripts" "--output" "sourcemap.json"
Invoke-Checked "stylua" "--check" "src" "tests"
Invoke-Checked "selene" "src" "tests"
Invoke-Checked "luau-lsp" "analyze" "--platform=roblox" "--definitions=types/roblox.d.luau" "--sourcemap=sourcemap.json" "src" "tests"

Get-ChildItem -Path (Join-Path $root "tests") -Filter "*.spec.luau" | ForEach-Object {
  Invoke-Checked "lune" "run" $_.FullName
}

New-Item -ItemType Directory -Force -Path $artifacts | Out-Null
Invoke-Checked "rojo" "build" "default.project.json" "--output" (Join-Path $artifacts "roblox_game.rbxl")

Write-Host "Validation complete. Build: artifacts/roblox_game.rbxl"
