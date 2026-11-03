# Windows PowerShell version of bake_fx.sh.
# Bakes every pixelfx effect listed in tools/fx_list.txt into game/assets/fx/<name>/.
# Usage: tools\bake_fx.ps1 [name...]   (no names = bake all)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$pixelfx = Join-Path $root "third_party\pixelfx"
$outRoot = Join-Path $root "game\assets\fx"
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("bake_fx_" + [Guid]::NewGuid())

if (-not (Test-Path (Join-Path $pixelfx "tools\render.mjs"))) {
  throw "pixelfx missing: run tools\setup_third_party.ps1"
}

$importText = "[remap]`n`nimporter=`"texture`"`ntype=`"CompressedTexture2D`"`n`n[params]`n`ncompress/mode=0`nmipmaps/generate=false`n"

try {
  Push-Location $pixelfx
  foreach ($line in Get-Content (Join-Path $root "tools\fx_list.txt")) {
    $line = $line.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { continue }
    $parts = $line -split "\s+"
    $name = $parts[0]; $id = $parts[1]
    $flags = @(); if ($parts.Count -gt 2) { $flags = $parts[2..($parts.Count - 1)] }
    # Windows PowerShell (legacy native arg passing) drops embedded quotes, which breaks --opts JSON.
    if ($PSVersionTable.PSVersion.Major -lt 7 -or $PSNativeCommandArgumentPassing -eq "Legacy") {
      $flags = @($flags | ForEach-Object { $_ -replace '"', '\"' })
    }
    if ($args.Count -gt 0 -and $args -notcontains $name) { continue }

    $out = Join-Path $tmp $name
    & node tools/render.mjs $id --sheet --out $out @flags | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) { throw "render failed for $id" }

    $base = $id.Split("/")[-1]
    $src = Join-Path $out $id
    $dest = Join-Path $outRoot $name
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item (Join-Path $src "$base.png") (Join-Path $dest "sheet.png") -Force
    Copy-Item (Join-Path $src "$base.json") (Join-Path $dest "sheet.json") -Force
    # Pixel-art import rules (docs/09_ART_PIPELINE.md §2): lossless, no mipmaps. Godot fills in the rest.
    $importFile = Join-Path $dest "sheet.png.import"
    if (-not (Test-Path $importFile)) { [IO.File]::WriteAllText($importFile, $importText) }
    Write-Host "  -> game/assets/fx/$name/"
  }
} finally {
  Pop-Location
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
