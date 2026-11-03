#!/usr/bin/env bash
# Bakes every pixelfx effect listed in tools/fx_list.txt into game/assets/fx/<name>/.
# Usage: tools/bake_fx.sh [name...]   (no names = bake all)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
pixelfx="$root/third_party/pixelfx"
out_root="$root/game/assets/fx"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

[ -f "$pixelfx/tools/render.mjs" ] || { echo "pixelfx missing: run tools/setup_third_party.sh" >&2; exit 1; }

while read -r name id flags; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue
  if [ $# -gt 0 ] && [[ ! " $* " == *" $name "* ]]; then continue; fi
  # shellcheck disable=SC2086  # flags are intentionally word-split
  (cd "$pixelfx" && node tools/render.mjs "$id" --sheet --out "$tmp/$name" $flags) | tail -1
  base="${id##*/}"
  dest="$out_root/$name"
  mkdir -p "$dest"
  cp "$tmp/$name/$id/$base.png" "$dest/sheet.png"
  cp "$tmp/$name/$id/$base.json" "$dest/sheet.json"
  # Pixel-art import rules (docs/09_ART_PIPELINE.md §2): lossless, no mipmaps. Godot fills in the rest.
  [ -f "$dest/sheet.png.import" ] || printf '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\n' > "$dest/sheet.png.import"
  echo "  -> game/assets/fx/$name/"
done < "$root/tools/fx_list.txt"
