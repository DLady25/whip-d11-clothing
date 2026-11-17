"""Builds data/gloves-<body>.js from the arms pictures (whip_media_clothing_<body>/img/clothing/<body>/03_arms_gloves).

GTA has no gloves slot: a glove is an "arms" item, the bare arms of one type with gloved hands. The shop data
says nothing about which glove goes with which arms, so it is read off the pictures (colour 0 of each item):
  type   the base arms (base_000..base_015) whose shape matches best (pictures are framed to their content,
         so the whole shape is compared, not a fixed wrist line)
  glove  its hands are (mostly) not skin. Pictures are framed to their content, so the hands are the lowest rows of
         the item; skin is told by its warm tone (red over green over blue, some blue), which no glove colour has.
  style  the same glove across the arm types (the packs list each glove once per type, in order)

Output: { "types": { "<base arms>": { "hands": true } },
          "arms":  { "<arms item>": { "type": "<base arms>", "glove": true, "style": 12 } },
          "styles": { "12": { "<base arms>": "<arms item>", ... } } }

Run: python -I tools/build_gloves.py <resources dir>   (--sheet writes a check picture per style)
"""
import json
import os
import re
import sys

from PIL import Image, ImageChops, ImageDraw

BODIES = {'male': 'whip_media_clothing_male', 'female': 'whip_media_clothing_female'}
NAME = re.compile(r'^(male|female)_3_(.+)_(\d{3})_00\.webp$')
SIZE = 128
HANDS = 0.22            # the lowest share of the item's height that is its hands (and wrists)
GLOVED = 0.3            # share of those pixels that are not skin above which the hands are gloved
                        # (fingerless gloves leave the fingertips bare: a share, not "all of it")
MIN_FIT = 0.8           # shape match under which the arm type is not trusted (the glove is not offered)


def find_media(root, name):
    for dp, dn, _ in os.walk(root):
        if os.path.basename(dp) == name:
            return dp
        if dp.count(os.sep) - root.count(os.sep) > 3:
            dn[:] = []
    return None


def write_js(path, name, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write('(window.D11_WARDROBE = window.D11_WARDROBE || {})[%s] = ' % json.dumps(name))
        json.dump(data, f, separators=(',', ':'), sort_keys=True)
        f.write(';' + chr(10))


class Pic:
    def __init__(self, key, path):
        self.key, self.path = key, path
        im = Image.open(path).convert('RGBA').resize((SIZE, SIZE))
        self.im = im
        self.mask = im.getchannel('A').point(lambda v: 255 if v > 32 else 0)
        self.rgb = im.convert('RGB')
        self.px = self.mask.histogram()[255]

    def gloved_share(self):
        """Share of the hands' pixels (the item's lowest rows) that are not skin; None without hands."""
        box = self.mask.getbbox()
        if not box:
            return None
        top = max(box[1], box[3] - max(8, int((box[3] - box[1]) * HANDS)))
        n = not_skin = 0
        rgb, mask = self.rgb.load(), self.mask.load()
        for y in range(top, box[3]):
            for x in range(box[0], box[2]):
                if mask[x, y]:
                    r, g, b = rgb[x, y]
                    n += 1
                    # Skin: red over green over blue, with some blue (yellow gloves have almost none).
                    if not (r > 80 and r > g + 12 and g >= b - 5 and b > 0.38 * r and g < 0.92 * r):
                        not_skin += 1
        return not_skin / n if n > 20 else None


def iou(a, b):
    inter = ImageChops.multiply(a, b).histogram()[255]
    union = ImageChops.lighter(a, b).histogram()[255]
    return inter / union if union else 0.0


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


def extra_folders(root, body):
    """The arms folders of the extra packs (resources with d11_clothing_photos 'yes')."""
    dirs = (os.path.join(d, 'img', 'clothing', body, '03_arms_gloves') for d in _marked(root).values())
    return [d for d in dirs if os.path.isdir(d)]


def build(folders, body):
    pics = []
    for folder in folders:
        for f in sorted(os.listdir(folder)):
            m = NAME.match(f)
            if m:
                pics.append(Pic(f'{m[2].lower()}_{m[3]}', os.path.join(folder, f)))
    base = [p for p in pics if p.key.startswith('base_')]

    # Every pictured base arms is a type a glove can go on (the ones with nothing to draw have no picture).
    out = {'types': {b.key: {} for b in base}, 'arms': {}, 'styles': {}}

    gloves = []
    for p in pics:
        if p.key.startswith('base_'):
            continue
        best = max(base, key=lambda b: iou(p.mask, b.mask))
        fit = iou(p.mask, best.mask)
        share = p.gloved_share()
        glove = share is not None and share > GLOVED
        rec = {'type': best.key if fit >= MIN_FIT else None, 'fit': round(fit, 3), 'glove': glove}
        out['arms'][p.key] = rec
        if glove and rec['type']:
            gloves.append(p)

    # Styles: the same glove across arm types. Each pack lists a glove once per arm type, in the base types'
    # order (type 0, 1, 2, 4, ...), then the next glove: a run of rising types is one style. (Matching the
    # hands' pictures does not work: the hands stand in another place on each arm type.)
    order = {t: i for i, t in enumerate(sorted(out['types']))}
    style_of = {}
    sid, run_coll, last = 0, None, None
    seen = set()
    for g in sorted(gloves, key=lambda g: (g.key.rsplit('_', 1)[0], g.key)):
        coll, t = g.key.rsplit('_', 1)[0], out['arms'][g.key]['type']
        if coll != run_coll or t in seen or order[t] <= last:
            sid += 1
            run_coll, seen = coll, set()
            out['styles'][str(sid)] = {}
        seen.add(t)
        last = order[t]
        out['styles'][str(sid)][t] = g.key
        style_of[g.key] = sid
    for k, s in style_of.items():
        out['arms'][k]['style'] = s
    return out, pics


def sheet(out, pics, path):
    byk = {p.key: p for p in pics}
    types = sorted(out['types'])
    styles = sorted(out['styles'].items(), key=lambda x: -len(x[1]))[:24]
    W = Image.new('RGBA', (90 + 64 * len(types), 70 * len(styles) + 20), (60, 60, 60, 255))
    d = ImageDraw.Draw(W)
    for j, t in enumerate(types):
        d.text((90 + 64 * j, 2), t[-3:], fill=(255, 255, 0, 255))
    for i, (sid, mem) in enumerate(styles):
        y = 20 + 70 * i
        d.text((2, y + 20), f'style {sid}', fill=(255, 255, 255, 255))
        for j, t in enumerate(types):
            if t in mem:
                W.alpha_composite(byk[mem[t]].im.resize((64, 64)), (90 + 64 * j, y))
    W.save(path)


def main():
    res = os.path.abspath(next((a for a in sys.argv[1:] if not a.startswith('--')), '..'))
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for body, pack in BODIES.items():
        media = find_media(res, pack)
        if not media:
            print(f'{body}: {pack} not found')
            continue
        folder = os.path.join(media, 'img', 'clothing', body, '03_arms_gloves')
        out, pics = build([folder] + extra_folders(res, body), body)
        n = len(out['arms'])
        g = sum(1 for v in out['arms'].values() if v['glove'])
        sizes = sorted((len(m) for m in out['styles'].values()), reverse=True)
        low = sum(1 for v in out['arms'].values() if v['fit'] < 0.6)
        print(f'{body}: {n} arms items, {g} gloves in {len(out["styles"])} styles (sizes {sizes[:12]}...), {low} poor shape fits')
        write_js(os.path.join(here, 'data', f'gloves-{body}.js'), f'gloves-{body}', out)
        if '--sheet' in sys.argv:
            sheet(out, pics, os.path.join(here, 'tools', f'_gloves-{body}.png'))


if __name__ == '__main__':
    main()
