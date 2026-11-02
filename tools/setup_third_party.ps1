# Windows PowerShell version of setup_third_party.sh
# Re-clones the 10 third-party repos (shallow) and installs the pixelfx Claude skill.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$tp = Join-Path $root "third_party"
New-Item -ItemType Directory -Force -Path $tp | Out-Null
Set-Location $tp
$repos = @("patch-gg/pixelfx","jrouwe/JoltPhysics","TokisanGames/Terrain3D","RodZill4/material-maker",
           "effekseer/Effekseer","Zylann/godot_voxel","recastnavigation/recastnavigation",
           "guillaumeblanc/ozz-animation","zeux/meshoptimizer","Auburn/FastNoise2")
foreach ($r in $repos) {
  $n = $r.Split("/")[1]
  if (Test-Path $n) { Write-Host "skip $n (exists)"; continue }
  git clone --depth 1 "https://github.com/$r.git" $n
}
Set-Location (Join-Path $tp "pixelfx")
npm install --silent
npm run check
$skills = Join-Path $env:USERPROFILE ".claude\skills"
New-Item -ItemType Directory -Force -Path $skills | Out-Null
Copy-Item -Recurse -Force (Join-Path $tp "pixelfx\skills\pixelfx") $skills
Set-Location $root
Write-Host "Done. third_party\ ready, pixelfx skill installed to $skills"
