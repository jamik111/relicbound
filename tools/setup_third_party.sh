#!/usr/bin/env bash
# Re-clones the 10 third-party repos (shallow) and installs the pixelfx Claude skill.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p third_party && cd third_party
for r in patch-gg/pixelfx jrouwe/JoltPhysics TokisanGames/Terrain3D RodZill4/material-maker \
         effekseer/Effekseer Zylann/godot_voxel recastnavigation/recastnavigation \
         guillaumeblanc/ozz-animation zeux/meshoptimizer Auburn/FastNoise2; do
  n=${r#*/}
  [ -d "$n" ] && { echo "skip $n (exists)"; continue; }
  git clone --depth 1 "https://github.com/$r.git" "$n"
done
(cd pixelfx && npm install --silent && npm run check | tail -1)
mkdir -p ~/.claude/skills && cp -r pixelfx/skills/pixelfx ~/.claude/skills/
echo "Done. third_party/ ready, pixelfx skill installed globally (project copy is in .claude/skills/pixelfx)."
