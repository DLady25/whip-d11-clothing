"""Builds data/wardrobe-<body>.js (the creator's combinations) from data/scan-<body>.json (/roupascan).

Output, keyed as whip_core names cards (<collection>_<NNN>):
  { "tops": { "<top>": { "arms": "<arms item>", "armsTex": 0, "under": ["<undershirt>", ...] } },
    "unders": { "<undershirt>": { "arms": "<arms item>", "armsTex": 0 } } }
  arms   the arms the shop forces with the piece (its "correct arms")
  under  the undershirts the shop pairs with the top, through its forced and variant components.
         Absent when the shop says nothing: the editor then offers every undershirt.
  alt    per colour of the top, its other versions (open/closed, hood up/down...): [[top, colour], ...]
  fit    'closed' (takes no undershirt: dress, corset, tank, tee...) or 'open' (jacket, blazer...), read off
         the game's name (whip_core/dev/editor_names.json); absent when the name says neither.
  The shop's generic entries (name '0') are not drawables for undershirts or tops: an undershirt one is the
  top's "no undershirt" (base_015 male / base_014 female), a top one is dropped. A top paired with itself as
  an undershirt (the same tank, bikini, dress shirt) is dropped too.

Run: python -I tools/build_wardrobe.py   (prints what the scan held, to check the reading)
"""
import json
import os
import re
import sys
from collections import Counter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARMS, UNDER, TOP = '3', '8', '11'
GAME = ('base_', 'mp_m_', 'mp_f_', 'male_', 'female_')   # the game's own collections; the rest are added-on packs


def write_js(path, name, data):
    """data/<name>.js: the editor page loads it with a <script> (another resource's JSON would need CORS)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write('(window.D11_WARDROBE = window.D11_WARDROBE || {})[%s] = ' % json.dumps(name))
        json.dump(data, f, separators=(',', ':'), sort_keys=True)
        f.write(';' + chr(10))


HASH_ZERO = 1849449579                  # joaat('0'): the shop's generic name, "no particular item"
NO_UNDERSHIRT = {'male': 'base_015', 'female': 'base_014'}   # as whip_core's undressedFor (appearance.lua)


def resolve(scan, entry):
    """[nameHash, enum, compType] -> (comp, key, tex) or None."""
    name_hash, enum, comp_type = entry
    hit = scan['byHash'].get(str(name_hash)) if name_hash else None
    if hit:
        return str(hit[0]), hit[1].lower(), hit[2]
    if name_hash != HASH_ZERO:
        return None
    # The generic name '0': its enum is NOT the drawable for every slot.
    #  - arms: it is (always a base item 0-15; checked in game, phase 1-2).
    #  - undershirt: it is the shop's "no undershirt" of a closed piece, in a numbering of its own
    #    (female 32/33/66/119/120, male 240/33/34/43/112, on dresses, corsets, hoodies...). Read as the
    #    drawable it put the female 33, a heavy utility vest, under every dress. It is "none".
    #  - anything else (a top's versions): the drawable it points at is unrelated (a shirt's "version"
    #    came out as a biker cut). Dropped.
    if str(comp_type) == ARMS:
        keys = [k for k in scan['keys'].get(ARMS) or [] if k.lower().startswith(GAME)]
        if 0 <= enum < len(keys):
            return ARMS, keys[enum].lower(), 0
        return None
    if str(comp_type) == UNDER:
        return UNDER, NO_UNDERSHIRT[scan['body']], 0
    return None


def load_names():
    """The game's item names (whip_core/dev/editor_names.json), or {} without it."""
    path = os.path.join(HERE, '..', '..', 'whip_core', 'dev', 'editor_names.json')
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except OSError:
        return {}


def same_piece(names, body, top, top_tex, under, under_tex):
    """The undershirt is the top itself, made for the undershirt slot (a tank, a bikini, a dress shirt):
    the shop lists it so the piece can go under a jacket, not under itself (it would be worn twice)."""
    a = names.get('%s_11_%s_%02d' % (body, top, int(top_tex)))
    b = names.get('%s_8_%s_%02d' % (body, under, int(under_tex)))
    return bool(a) and a == b


# A top's fit, from the game's name (GTA's shop keeps the undershirts a top takes in restriction tags the
# natives do not list): "closed" takes no undershirt (dresses, corsets, tanks, tees, sweaters...), "open" shows
# one (jackets, blazers, cardigans...). "Open"/"Closed" in the name decide; else the LAST garment word does, as
# English names end in the garment ("Leather Hoodie" is a hoodie, "Sweater Vest" a vest). No name, or no
# garment word: unknown, and the editor offers every undershirt as before.
FIT_SAID = [('open', r'BopenB|unbuttoned|unzipped|track(suit)? top'), ('closed', r'BclosedB|BzippedB')]
FIT_WORDS = [
    ('open', r'jacket|blazer|BcoatB|overcoat|peacoat|tailcoat|parka|bomber|cardigan|waistcoat|BvestB|gilet|BcutB|'
             r'varsity|windbreaker|tracksuit top|track top|BtrackB|BrobeB|kimono|overshirt|BchoreB|BsuitB|BtuxB|'
             r'tuxedo|trench|poncho|duster|harrington|letterman|BbikerB|BfieldB|BflightB|BracerB|BracingB|blouson|'
             r'waterproof|midlength|BvinylB|armor|armour|double breasted|BfittedB|leather fur'),
    ('closed', r'dress|gown|corset|bustier|romper|bikini|swim|leotard|bodysuit|catsuit|jumpsuit|coverall|BtankB|'
               r'BteeB|t-shirt|BpoloB|sweater|hoodie|sweatshirt|jersey|blouse|BcropB|BbraB|pajama|tunic|turtleneck|'
               r'camisole|halter|BtopB|shirt|BshellB|pullover|puffer|racerback|singlet|Bv neckB|scrub|shortsleeve|'
               r'BtuckedB|untucked|revere collar|BofficeB|motocross|babydoll|BshortB|BrelaxedB|BsleevelessB|'
               r'BcheckB'),
]
BS = chr(92) + 'b'
FIT_SAID = [(f, re.compile(r.replace('B', BS))) for f, r in FIT_SAID]
FIT_WORDS = [(f, re.compile(r.replace('B', BS))) for f, r in FIT_WORDS]


def top_name(names, body, key):
    for t in range(0, 26):
        n = names.get('%s_11_%s_%02d' % (body, key, t))
        if n:
            return n
    return ''


def top_fit(names, body, key):
    n = top_name(names, body, key).lower()
    if not n:
        return None
    for fit, rx in FIT_SAID:
        if rx.search(n):
            return fit
    last, out = -1, None
    for fit, rx in FIT_WORDS:
        for m in rx.finditer(n):
            if m.start() > last:
                last, out = m.start(), fit
    return out


def build(scan, names):
    out = {'tops': {}, 'unders': {}}
    seen = Counter()
    same = set()   # undershirts dropped as the top itself
    body = scan['body']
    for slot, target in ((TOP, 'tops'), (UNDER, 'unders')):
        for key, rec in scan['items'].get(slot, {}).items():
            arms, unders, alt = Counter(), [], {}
            for field in ('forced', 'variants'):
                for tex, entries in (rec.get(field) or {}).items():
                    for e in entries:
                        r = resolve(scan, e)
                        seen[(slot, field, r[0] if r else 'unresolved', e[2])] += 1
                        if not r:
                            continue
                        comp, k, t = r
                        if comp == ARMS and field == 'forced':
                            arms[(k, t)] += 1
                        elif comp == UNDER and slot == TOP and k not in unders:
                            if same_piece(names, body, key.lower(), tex, k, t):
                                same.add(k)
                                continue
                            unders.append(k)
                        elif comp == TOP and slot == TOP and field == 'variants' and k != key.lower():
                            pair = [k, t]
                            if pair not in alt.setdefault(tex, []):
                                alt[tex].append(pair)
            item = {}
            if arms:
                (k, t), _ = arms.most_common(1)[0]
                item['arms'], item['armsTex'] = k, t
            if unders:
                item['under'] = unders
            if alt:
                item['alt'] = alt
            fit = top_fit(names, body, key.lower()) if slot == TOP else None
            if fit:
                item['fit'] = fit
            if item:
                out[target][key.lower()] = item   # GTA names some collections in capitals; the pictures do not
    out_same = sorted(same)
    return out, seen, out_same


def main():
    names = load_names()
    if not names:
        print('warning: no whip_core/dev/editor_names.json; a top paired with itself as undershirt is kept')
    for body in ('male', 'female'):
        path = os.path.join(HERE, 'data', f'scan-{body}.json')
        if not os.path.exists(path):
            print(f'{body}: no scan yet ({os.path.relpath(path, HERE)}); run /roupascan in game')
            continue
        with open(path, encoding='utf-8') as f:
            scan = json.load(f)
        data, seen, same = build(scan, names)
        print(body, 'scan stats', scan.get('stats'))
        for (slot, field, comp, ctype), n in sorted(seen.items(), key=lambda x: -x[1])[:20]:
            print(f'  slot {slot} {field}: -> comp {comp} (type {ctype}) x{n}')
        print(f'  tops with arms {sum("arms" in v for v in data["tops"].values())}, with undershirts '
              f'{sum("under" in v for v in data["tops"].values())}; undershirts with arms '
              f'{sum("arms" in v for v in data["unders"].values())}; tops with versions '
              f'{sum("alt" in v for v in data["tops"].values())}')
        print(f'  undershirts dropped as the top itself: {len(same)}')
        fits = Counter(v.get('fit', 'unknown') for v in data['tops'].values())
        print(f'  top fit by name: {dict(fits)}')
        dest = os.path.join(HERE, 'data', f'wardrobe-{body}.js')
        write_js(dest, f'wardrobe-{body}', data)
        print('  ->', os.path.relpath(dest, HERE))


if __name__ == '__main__':
    sys.exit(main())
