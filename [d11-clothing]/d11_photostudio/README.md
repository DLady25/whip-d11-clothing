# d11_photostudio (for WHIP)

A photo studio for saved outfits in the WHIP character editor: pick a pose, turn the character, take the photo, and
the outfit's card shows the real character wearing it instead of the top's picture.

- Opened from the editor: **Outfit photo** on the outfit you have on (Outfits tab). Needs whip-d11-clothing's
  `whip_core-creator-d11.patch` (the editor side and the `CreatorCamera` export).
- The studio: the SubUrban in Del Perro (`Config.Ponto`, `/fotospot` to move it), in a routing bucket of the player's
  own, with a fade there and back.
- Poses: whip_core's emote list (`shared/emote_list.lua`, loaded from whip_core, not copied): standing poses, gestures
  and dances, with search.
- Camera: the editor's, locked in the world while the character turns (A/D, the ⟲ ⟳ buttons or right-drag); left-drag
  turns and raises it, the wheel zooms, R faces the camera again.
- Photo: whip_core `TakeScreenshot` (game only, no interface), cropped to the 3:4 frame, 480x640 webp.
- Stored per character and outfit in `photos/<character>_<outfit>.txt` (the data URL). Keep the `photos` folder.
- Language: `setr d11_locale en | pt-BR` (default en).

License: MIT.
