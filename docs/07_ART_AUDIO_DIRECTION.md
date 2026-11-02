# 07 — Art & Audio Direction

## Visual pillars
1. **Diorama ruins:** every room looks like a lit museum diorama. Chunky low-poly geometry, hand-painted
   texture accents and strong silhouettes.
2. **Torchlight drama:** warm point lights against cool ambient. Darkness is part of the gameplay (the Lantern).
3. **Crisp pixel juice:** VFX are deliberately pixel art (pixelfx), which bridges nostalgia and modern 3D.
4. **Readable first:** gameplay objects (boulders, gems, keys, hazards) have saturated, unique silhouettes.
   Decoration stays muted.

## Palette per world (base / accent / danger)
| World | Base | Accent | Danger |
|---|---|---|---|
| Jade Cenote | moss green, limestone | jade, turquoise water | red snake bands |
| Qadir | sandstone, ochre | lapis blue, gold | scarab teal-black |
| Hrimfjall | slate, snow white | aurora green/violet | blood-red runes |
| Ember Forge | basalt black | molten orange, brass | white-hot yellow |
| Meridian Core | verdigris bronze | sun gold, deep blue | pulsing magenta time-field |

## Asset specs
- Tile grid unit = 1 m. Tiles ≤ 300 tris, characters ≤ 3k tris, bosses ≤ 12k.
- Textures: a 512² atlas per world (1024² on the High tier), KTX2/Basis. Materials are authored in Material Maker.
- Characters are rigged in Blender with ≤ 40 bones. Clips: idle, walk, push, pull, grapple, dig, crushed, drown, celebrate.
- All glTF goes through `gltfpack -cc -tc -si 0.6` for LOD1.
- Pixel VFX: 1 VFX pixel = 1/48 of a tile. Use the pixelfx palettes (`PAL.fire`, `PAL.gold`, `PAL.water`…) recoloured per world.

## VFX shopping list (pixelfx first, Effekseer for big moments)
| Event | Source |
|---|---|
| Gem pickup sparkle | pixelfx `pickups/*` recoloured to gem colours |
| Boulder landing dust | pixelfx `impacts/heavy-landing`, earth palette |
| Torch / brazier | pixelfx `fire/torch`, `fire/brazier` |
| Water splash / drips | pixelfx `water/*` |
| Freeze bridge | pixelfx `ice/freeze` |
| Dart trap hit | pixelfx `projectiles/arrow` + `impacts/*` |
| Death poof / respawn | pixelfx `spawn & death/*` |
| Boss slams, Sunstone reveal | Effekseer (3D) + Jolt debris |

## UI
A field-journal look: parchment, ink lines and stamp-style buttons. The HUD stays minimal (gems, tool, hourglass
charges). Fonts must be readable at 14 px on phones, e.g. "IM Fell English" for titles and "Inter" for body text.

## Audio
- **Music:** an orchestral-adventure theme for Nadia that is reworked per world with regional instruments
  (marimba, oud, hardanger fiddle, tabla, a music-box/clock ensemble). Adaptive stems: explore → danger → chase.
- **SFX:** stone grinding (pushes), deep thuds (landings, which double as audio warnings), glassy gem chimes
  that rise in pitch over a combo, and a whip crack.
- **Gameplay audio cues:** every falling object makes a short "creak" one tick before it falls. Players who
  can't see the screen well can still react.
- Haptics on mobile: a light tap on pushes, heavy on a landing nearby, a pattern on death.
