# d11_wardrobe (for WHIP)

Wardrobe data for the WHIP character editor:

- **Real colours only.** `data/textures-<body>.js` lists, per item, the colours that exist: the ones with a
  picture in `whip_media_clothing_male/_female` that is not empty and not a copy of another colour of the
  same item (a broken texture shows another colour again). Built by `tools/build_pictures.py`.
- **Gloves.** `data/gloves-<body>.js` says, per arms item, which base arms it is shaped like, whether its
  hands are gloved and which glove it is across the arm types. GTA keeps no such data, so it is read off the
  arms pictures by `tools/build_gloves.py` (`--sheet` writes a check picture per body).
- **Pieces that go together.** `data/wardrobe-<body>.js` says which arms and undershirts GTA's shop pairs
  with each top. Built by `tools/build_wardrobe.py` from an in-game scan. The shop's generic entries are read as
  "no undershirt" (never as drawable 33, a utility vest, as before), and each top is marked `closed` (dress,
  corset, tee: no undershirt, no Camisetas tab) or `open` (jacket, blazer: the undershirt worn stays) from its
  game name in `whip_core/dev/editor_names.json`.

The editor side is a whip_core patch (`docs/patches/whip_core-creator-wardrobe-d11.patch`): the Tops tab
becomes "Parte de cima", with the undershirts that fit under "Combinações" in the item's card, and the
correct arms put on automatically. The Arms tab becomes Gloves: only the gloves that fit the arms worn, and a
glove stays on (in the new arm type) when the top changes. Without this resource the editor behaves as before.

## Scan

1. `ensure d11_wardrobe` and join with an admin (ace `command`).
2. On a male freemode character, `/roupascan`; then on a female one. The server writes `data/scan-<body>.json`.
3. `python -I tools/build_wardrobe.py` → `data/wardrobe-<body>.js`; restart the resource.

Re-run `python -I tools/build_pictures.py <resources dir>` when the clothing pictures change.

License: MIT.
