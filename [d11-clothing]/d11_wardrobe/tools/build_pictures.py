"""Builds data/textures-<body>.js from whip_media_clothing_male/_female pictures, and the extra packs' pictures
(resources with d11_clothing_photos 'yes', e.g. d11_clothing_photos): `photos` says which ITEMS are there (per item:
a collection can be split between packs), { key: { res, items: '0-3,11' } }, keyed '<c|p><slot>:<collection>' ('c4:onxgovt', 'c0:base' for the heads), where whip_core's
clothingIconUrl looks for them (patch clothing-photos-d11).

For every apparel/accessory item that has pictures, lists the colours (textures) worth offering:
  - the colour has a picture (the picture tool skips what the game cannot draw);
  - the picture is not empty (an invisible item renders as nothing);
  - it is not a copy of an earlier colour of the same item (a broken texture shows another one's
    picture again: the same thing twice).

Output: { "components": { "11": { "mp_m_vinewood_004": "0-3,5" } }, "props": { "0": {...} },
          "invisible": { "components": { "8": ["mp_m_x_000"] } } }
Keys are the picture name without the body prefix: <collection>_<item>, as whip_core names cards.

Run: python -I tools/build_pictures.py <resources dir>
"""
import json
import os
import re
import sys
from collections import defaultdict

from PIL import Image, ImageChops

BODIES = {'male': 'whip_media_clothing_male', 'female': 'whip_media_clothing_female'}
NAME = re.compile(r'^(male|female)_(p?\d+)_(.+)_(\d{3})_(\d{2})\.webp$')
PROP_NAME = re.compile(r'^(?:male|female)_prop(\d+)_(.+)_(\d{3})_\d{2}\.webp$')
MIN_COVER = 0.004          # under 0.4% of the picture opaque: nothing to see
NEAR = 0.5                 # mean difference (0-255) over the item's own pixels: under it, the same picture.
                           # Real colours of one item measured 2+; the copies a broken texture makes, ~0.


def write_js(path, name, data):
    """data/<name>.js: the editor page loads it with a <script> (another resource's JSON would need CORS)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write('(window.D11_WARDROBE = window.D11_WARDROBE || {})[%s] = ' % json.dumps(name))
        json.dump(data, f, separators=(',', ':'), sort_keys=True)
        f.write(';' + chr(10))


def find_media(root, name):
    for dp, dn, _ in os.walk(root):
        if os.path.basename(dp) == name:
            return dp
        if dp.count(os.sep) - root.count(os.sep) > 3:
            dn[:] = []
    return None


def ranges(nums):
    nums = sorted(set(nums))
    out, i = [], 0
    while i < len(nums):
        j = i
        while j + 1 < len(nums) and nums[j + 1] == nums[j] + 1:
            j += 1
        out.append(str(nums[i]) if i == j else f'{nums[i]}-{nums[j]}')
        i = j + 1
    return ','.join(out)


def thumb(path):
    im = Image.open(path).convert('RGBA')
    alpha = im.getchannel('A')
    hist = alpha.histogram()
    cover = sum(hist[17:]) / (im.width * im.height)
    return cover, im.resize((128, 128))


def diff(a, b):
    """Mean colour difference over the pixels either picture covers (the background would hide a small item)."""
    mask = ImageChops.lighter(*(x.getchannel('A').point(lambda v: 255 if v > 16 else 0) for x in (a, b)))
    n = mask.histogram()[255]
    if not n:
        return 0.0
    d = ImageChops.multiply(ImageChops.difference(a.convert('RGB'), b.convert('RGB')).convert('L'), mask)
    return sum(i * c for i, c in enumerate(d.histogram())) / n


def _marked(root):
    """Resources with d11_clothing_photos 'yes' in their fxmanifest, here and in [category] folders."""
    out = {}
    for e in sorted(os.listdir(root)):
        full = os.path.join(root, e)
        if not os.path.isdir(full):
            continue
        if e.startswith('['):
            out.update(_marked(full))
            continue
        m = os.path.join(full, 'fxmanifest.lua')
        if os.path.isfile(m):
            with open(m, encoding='utf-8', errors='replace') as f:
                if re.search(r'^\s*d11_clothing_photos\s', f.read(), re.M):
                    out[e] = full
    return out


def extra_packs(root):
    """The extra packs' pictures (resources with d11_clothing_photos 'yes'): {name: dir}."""
    return _marked(root)


def build(media, body, extras=None):
    roots = [(None, os.path.join(media, 'img', 'clothing', body))]
    roots += [(name, os.path.join(d, 'img', 'clothing', body)) for name, d in (extras or {}).items()]
    items = defaultdict(dict)       # (group, slot, key) -> {tex: (cover, small)}
    photos = defaultdict(lambda: [None, set()])   # '<c|p><slot>:<collection>' -> [resource, items in it]
    for owner, root in roots:
        if not os.path.isdir(root):
            continue
        for folder in sorted(os.listdir(root)):
            for f in os.listdir(os.path.join(root, folder)):
                prop = PROP_NAME.match(f)
                if owner and prop:   # props (prop<N>): so a rota da foto; as cores dos props nao sao listadas aqui
                    r = photos[f'p{prop.group(1)}:{prop.group(2).lower()}']
                    r[0] = owner
                    r[1].add(int(prop.group(3)))
                m = NAME.match(f)
                if not m:
                    continue
                _, slot, coll, item, tex = m.groups()
                group = 'props' if slot.startswith('p') else 'components'
                if owner:   # por slot: 'base' tambem e colecao do WHIP (so os rostos 0:base vem do pack D11)
                    r = photos[f"{group[0]}{slot.lstrip('p')}:{coll.lower()}"]
                    r[0] = owner
                    r[1].add(int(item))
                items[(group, slot.lstrip('p'), f'{coll}_{item}')][int(tex)] = os.path.join(root, folder, f)

    # Por PECA, nao por colecao: o pack D11 pode ter so algumas pecas de uma colecao que o WHIP fotografou
    # (as que faltavam); as outras continuam nos whip_media_*.
    photos = {k: {'res': v[0], 'items': ranges(v[1])} for k, v in photos.items()}
    out = {'components': {}, 'props': {}, 'invisible': {'components': {}, 'props': {}}, 'photos': photos}
    stats = defaultdict(int)
    for (group, slot, key), texs in sorted(items.items()):
        keep, seen = [], []
        for t in sorted(texs):
            cover, small = thumb(texs[t])
            stats['pictures'] += 1
            if cover < MIN_COVER:
                stats['empty'] += 1
                continue
            if any(diff(small, s) < NEAR for s in seen):
                stats['duplicate'] += 1
                continue
            seen.append(small)
            keep.append(t)
        if keep:
            out[group].setdefault(slot, {})[key] = ranges(keep)
        else:
            out['invisible'][group].setdefault(slot, []).append(key)
            stats['invisible items'] += 1
    return out, stats


def main():
    res = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else '..')
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for body, pack in BODIES.items():
        media = find_media(res, pack)
        if not media:
            print(f'{body}: {pack} not found under {res}')
            continue
        data, stats = build(media, body, extra_packs(res))
        path = os.path.join(here, 'data', f'textures-{body}.js')
        write_js(path, f'textures-{body}', data)
        print(body, dict(stats), '->', os.path.relpath(path, here))


if __name__ == '__main__':
    main()
