# D11 Clothing for WHIP

The clothing stores and the clothes-as-items we run on District 11 (D11), built on [WHIP](https://github.com/WHIPFX/whip_core)'s
own character editor and inventory. Built and tested on whip_core 1.0.1; works on 1.1.x with the patch and on 1.2.0
without any patch.

> **English and Brazilian Portuguese.** One line in server.cfg picks the language of every D11 resource:
> `setr d11_locale en` (the default) or `setr d11_locale pt-BR`.

## What's inside

`[d11-clothing]/`: drop this folder into your `resources/`. The two resources work on their own or together.

| Resource | What it does |
| --- | --- |
| `d11_stores` | Clothing store, barber, tattoo studio and plastic surgeon. Each store **type** opens WHIP's character editor on only the tabs it unlocks and charges for what changed, cash or bank. Store types, prices and locations are edited in game at **/whip → Settings → Clothing stores**. 25 stores on GTA's own spots out of the box. |
| `d11_clothing` | Every piece the character wears is a real item in the inventory's **Equipped** strip: take it off, store it, give it, drop it, get it stolen, put it on again. Clothes from the editor or a store become items by themselves. |

`whip_core-patches/`: **only for whip_core 1.0.1 and 1.1.x**, and only for `d11_stores`.

| Patch | For |
| --- | --- |
| `whip_core-appearance-policy-1.0.1.patch` | whip_core 1.0.1 |
| `whip_core-appearance-policy-1.1.x.patch` | whip_core 1.1.0 and 1.1.1 |

From your `resources/` folder (back up `whip_core` first, restart it after):

```
patch -p1 --dry-run < whip_core-appearance-policy-1.0.1.patch   # check first
patch -p1 < whip_core-appearance-policy-1.0.1.patch
```

### Do I need the patch? (whip_core 1.2.0)

**No, not on whip_core 1.2.0 or newer.** 1.2.0 ships its own store editor (`EditAppearance`, `GetAppearanceChanges`,
`SetPlayerAppearance`) and, since its "checkout in the store's editor" change, a Cash / Bank checkout on Save.
`d11_stores` reads whip_core's version at start and uses that when it is there. Same stores, same settings page, same
prices, nothing to patch. What you get on each:

| | whip_core 1.2.0+ (no patch) | 1.0.1 / 1.1.x + patch |
| --- | --- | --- |
| Only the store's tabs, server checks and charges | yes | yes |
| Cash or bank, with the balances | WHIP's checkout on Save | in the cart |
| A cart line per item, with **×** to put that item back | no: Save shows the total | yes |
| "Face and skin" price | per changed part | once, whatever changed |
| Taking off a hat or glasses | free | charged as a change |
| Editor camera stops at walls (small stores) | no | yes |
| WHIP's plain "save look" closed while at a store | no | yes |

Without the patch on 1.0.1 / 1.1.x the store says "This store is not available" and the server console says why.

## Requirements

- whip_core 1.0.1 or newer (1.0.1 / 1.1.x: with the patch above, for `d11_stores`).
- `d11_clothing`: **`Config.ContainerSlots.accessory = 16`** in `whip_core/config.lua` (default 5). Slots 6 to 16 hold
  the clothes. It is a config value, not a code change.
- Optional:
  - [`d11_theme`](https://github.com/DLady25/whip-d11-theme): our dark look for WHIP, including the editor and the
    patch's cart. Without it the cart uses whip_core's own styles.
  - [`d11_inventory`](https://github.com/DLady25/whip-d11-inventory): shows a "Clothing" row in Equipped and the
    real picture of each piece.

## server.cfg

After the `ensure whip_*` lines (and after your clothing packs):

```cfg
setr d11_locale en
ensure d11_clothing
ensure d11_stores
```

Restart the server: the Equipped strip only changes size when whip_core restarts. No SQL: WHIP keeps the pieces in
the inventory.

## d11_stores

### Settings page

**/whip → Settings → Clothing stores**. Only permanent admins see it. Saved values apply right away for everyone.

- **One tab per store type** (clothing store, barber, tattoo studio, plastic surgeon): the name on the blip and the
  prompt, what it **unlocks**, the **price** of each unlocked group, the blip and the clerk's ped model. A type with
  nothing unlocked is closed.
- **Locations:** the stores on the map (name, type, clerk position, heading). Drag on the map, rename, remove, or add
  one where you stand.
- **Payment:** cash or bank (the player picks), cash only, or bank only.

| Group | What it unlocks in the editor | Charged |
|---|---|---|
| Clothes | mask, top, undershirt, arms, legs, shoes, accessory, vest, decal, bag | per piece (arms and decal are free) |
| Accessories | hat, glasses, ears, watch, bracelet | per item |
| Saved looks | the saved-looks tab | what it puts on counts as clothes / accessories |
| Hair and eyebrows | hair (with fade), eyebrows | per item |
| Beard and body hair | beard, chest hair | per item |
| Makeup | makeup, blush, lipstick | per item |
| Tattoos | every tattoo zone | per new tattoo (removing is free) |
| Face and skin | heritage, features, eyes, skin | see the table above |

Defaults: clothing store clothes $120 and accessories $60; barber hair $80, beard $40, makeup $40; tattoo studio $250
per new tattoo; surgeon $5,000 (no locations by default: add them on the settings page). 12 clothing stores, 7 barbers
and 6 tattoo studios on the map. Everything is in `d11_stores/config.lua` too.

### In game

- The clerk's **Shop** prompt opens the editor on the unlocked tabs only. The server checks that the player is at the
  counter, drops anything the store does not unlock, prices it again and charges before the look is kept. If the
  payment fails, the editor stays open and says why.
- In a vehicle the prompt asks you to get out first.

### For other resources

- `exports.d11_stores:InStore(source)`: `true` while that player is at a store.
- Server event `d11_stores:paid(source, look)`: fired after a purchase was paid and kept. `d11_clothing` uses it.

## d11_clothing

| Equipped slot | Item | Body parts |
|---|---|---|
| 6 | `d11_clothing_shirt` | top (11), undershirt (8), arms (3), decal (10) |
| 7 | `d11_clothing_pants` | 4 |
| 8 | `d11_clothing_shoes` | 6 |
| 9 | `d11_clothing_mask` | 1 |
| 10 | `d11_clothing_neck` | 7 |
| 11 | `d11_clothing_vest` | 9 |
| 12 | `d11_clothing_hat` | prop 0 |
| 13 | `d11_clothing_glasses` | prop 1 |
| 14 | `d11_clothing_ears` | prop 2 |
| 15 | `d11_clothing_watch` | prop 6 |
| 16 | `d11_clothing_bracelet` | prop 7 |

- **Put on:** drag the piece to its slot in Equipped, or **Use** it. What was in that slot goes to the pockets.
- **Take off:** drag it out of the strip, or **Use** a worn piece. That body part gets WHIP's own "undressed" look:
  underwear, bare feet, no hat.
- **Editor / store:** on save, every slot that changed gets a new piece; the old one is gone.
- **First login:** the clothes of the saved look become items, once per character (character metadata
  `d11_clothing`). From then on the body wears exactly what is in the strip.
- **Body:** a piece is male or female and only fits that body; one for the other body goes back to the pockets.
- **Uniforms:** clothes put on by another script (a job locker) stay. Moving one piece only changes that slot.
- **Clothing packs:** each piece keeps its **collection** and its number inside it, not the game's global index, so
  changing the order of clothing packs or the game build does not break what is in the inventory.
- **Weight:** 0, because the strip only holds 10 kg.
- **Pictures:** the items ship without icons. `d11_inventory` shows the real picture of each piece (item metadata
  `foto`, from WHIP's clothing photos); other inventories show WHIP's placeholder. To add icons, put
  `d11_clothing/html/img/items/d11_clothing_<slot>.png` (shirt, pants, ...) and a `files { 'html/img/items/*.png' }`
  line in its fxmanifest.

Known limits:
- Do not sell `d11_clothing_*` in a shop or pawn for more than a store charges, or it becomes a money source.
- Every change saves the look through the editor's path, so WHIP's "Appearance saved" notice shows. Quick changes are
  batched, one save every 2 seconds.
- Opening the editor less than ~2 s after changing a piece can show the previous clothes.

## Quick test

1. At the Binco in Textile City, change the top, the pants and a hat: $300 (with the patch, the cart shows 3 lines;
   press × on the pants and it drops to $180).
2. Pay by bank: the bank is charged, the editor closes, and Equipped shows the new shirt, pants and hat.
3. The barber shows only hair, eyebrows, beard, makeup and chest hair; the tattoo studio only tattoos.
4. Settings page: turn off "Unlocks: Clothes" for the clothing store: the group is gone from the editor.
5. Drag the pants to the pockets: the character is in underwear. **Use** them: worn again.
6. Log out and in: the body wears exactly the Equipped strip. No `SCRIPT ERROR` in F8 or the server console.

## License

The resources are MIT (see `LICENSE`). The files in `whip_core-patches/` change whip_core and are under whip_core's
own license (LGPL-3.0).

## Credits

Built on WHIP by Whippy and the WHIP contributors. Not affiliated with or endorsed by WHIP or Rockstar Games.
