"""The growing peach's stages: the title's peach, one drawing per rank and the
crown, as SVG path data in the peach's 100x100 box, absolute M, L, C and Z
only, as the costume table is written.

    python3 -I tools/growth-stages.py
        Writes Sources/PeachEngine/GrowthStages.swift, the engine's table,
        checks every point is inside the box less half of any stroke, and
        prints the table's SHA-256, which `GrowthStageTests` pins.

    python3 -I tools/growth-stages.py --preview <dir>
        Also writes stages.json and preview.html (every stage at the title's
        96pt and at 10.7pt, the smallest peach in the app) into <dir>.

    python3 -I tools/growth-stages.py --json <file>
        Also writes the table as JSON, each stage's raw value, its words and
        its parts, for the web's copy in `src/storeArt/growthStages.ts`.

These are the drawings Antoine approved on 24 October 2026, with Ripening's
blush made the ripe peach's own cheeks. The Swift table is generated from
them rather than transcribed, so the code cannot drift from what was
approved: change a drawing here, run this, and update the pinned hash.

They can also be edited in Inkscape, in the illustrations kept in the vault.
The web repo's `scripts/illustrations/import.ts` writes an edit back here,
runs this, writes the web's copy from `--json`, and moves both pinned hashes.
An edited stage comes back as literal path data in place of its formula. The
stages drawn from the peach follow an edit to the peach until one of them is
edited directly, and is then drawn on its own (Antoine, 4 November 2026).
"""
import hashlib
import json
import math
import os
import sys

K = 0.5523  # a circle's cubic control distance, as a fraction of the radius

LEAF = "#8FD3B6"
LEAF_DEEP = "#6FBF9C"
COCOA = "#7A4A33"
SOIL = "#C99A74"
SOIL_DEEP = "#B5835E"
PETAL = "#FFC4CF"
PETAL_DEEP = "#FF9DAE"
POLLEN = "#FFE08A"
PEACH = "#FFC27A"
PEACH_HI = "#FFD79B"
BLUSH = "#FF9DAE"
UNRIPE = "#CFE3A0"
UNRIPE_HI = "#E3EFC3"
CROWN = "#FF9E58"   # Cute.crown
CROWN_DEEP = "#F07F36"
SMALLEST = 10.7     # a found chip's peach at extra small text: 13pt scaled as body, 14/17


def f(x):
    s = f"{x:.1f}".rstrip("0").rstrip(".")
    return "0" if s == "-0" else s


def circle(cx, cy, r):
    k = K * r
    return (f"M{f(cx - r)} {f(cy)} "
            f"C{f(cx - r)} {f(cy - k)} {f(cx - k)} {f(cy - r)} {f(cx)} {f(cy - r)} "
            f"C{f(cx + k)} {f(cy - r)} {f(cx + r)} {f(cy - k)} {f(cx + r)} {f(cy)} "
            f"C{f(cx + r)} {f(cy + k)} {f(cx + k)} {f(cy + r)} {f(cx)} {f(cy + r)} "
            f"C{f(cx - k)} {f(cy + r)} {f(cx - r)} {f(cy + k)} {f(cx - r)} {f(cy)} Z")


def transform(d, sx, tx, ty):
    """Scale about the origin by sx, then move by (tx, ty), an absolute
    M/L/C/Z path."""
    out = []
    for tok in d.replace(",", " ").split():
        if tok[0] in "MLCZ":
            out.append(tok[0])
            tok = tok[1:]
            if not tok:
                continue
        out.append(tok)
    # Pair the numbers back up as x, y.
    res, nums = [], []
    for t in out:
        if t in "MLCZ":
            res.append(t)
        else:
            nums.append(float(t))
            if len(nums) == 2:
                res.append(f"{f(nums[0] * sx + tx)} {f(nums[1] * sx + ty)}")
                nums = []
    s = ""
    for t in res:
        s += t if t in "MLCZ" else (t + " ")
    return s.replace(" M", " M").strip().replace("Z", "Z ").strip()


# The peach, as the games draw it, in its 100x100 box: the leaf, the body and
# the highlight, then the face. Ripening, Sweet, Perfectly Peachy and the
# crowned stage are drawn from it for as long as they follow the peach.
#
# The illustrations' import (`scripts/illustrations/import.ts`, in the web
# repo) rewrites the lines between the two markers when peach.svg is edited,
# one part to a line, in this order: the leaf, the body and the highlight keep
# their places, since the stages below recolour and drop them by place.
# The peach: from here
PEACH_PARTS = [
    dict(d="M50 12 C54 4 64 3 68 8 C66 14 59 17 54 16 Z", fill=LEAF),  # leaf
    dict(d="M50 16 C70 16 84 32 84 52 C84 74 68 90 50 90 C32 90 16 74 16 52 C16 32 30 16 50 16 Z", fill=PEACH),  # body
    dict(d="M50 16 C41 16 33 20 27 27 C34 31 42 32 50 32 C58 32 66 31 73 27 C67 20 59 16 50 16 Z", fill=PEACH_HI, opacity=0.7),  # highlight
    dict(d=circle(40, 58, 3.4), fill=COCOA, faceOnly=True),  # eye, left
    dict(d=circle(60, 58, 3.4), fill=COCOA, faceOnly=True),  # eye, right
    dict(d=circle(34, 66, 4.5), fill=BLUSH, opacity=0.7, faceOnly=True),  # cheek, left
    dict(d=circle(66, 66, 4.5), fill=BLUSH, opacity=0.7, faceOnly=True),  # cheek, right
    dict(d="M45 67 C48 70 52 70 55 67", stroke=COCOA, strokeWidth=2.2, faceOnly=True),  # smile
]
# The peach: to here


def peach_parts(sx=1.0, tx=0.0, ty=0.0, body=None, high=None):
    """The peach scaled about the origin by sx, then moved by (tx, ty), with
    its body and its highlight recoloured where a colour is given. A stroke
    scales with it, to two places."""
    parts = []
    for i, p in enumerate(PEACH_PARTS):
        q = dict(p, d=transform(p["d"], sx, tx, ty))
        if i == 1 and body:
            q["fill"] = body
        if i == 2 and high:
            q["fill"] = high
        if q.get("strokeWidth") is not None:
            q["strokeWidth"] = round(p["strokeWidth"] * sx, 2)
        parts.append(q)
    return parts


def small_face(cx, cy, s):
    """Two eyes and a smile, centred on (cx, cy), at scale s of the peach's."""
    return [
        dict(d=circle(cx - 7 * s, cy, 2.4 * s), fill=COCOA, faceOnly=True),
        dict(d=circle(cx + 7 * s, cy, 2.4 * s), fill=COCOA, faceOnly=True),
        dict(d=f"M{f(cx - 3.5 * s)} {f(cy + 6 * s)} C{f(cx - 1.5 * s)} {f(cy + 8.5 * s)} "
               f"{f(cx + 1.5 * s)} {f(cy + 8.5 * s)} {f(cx + 3.5 * s)} {f(cy + 6 * s)}",
             stroke=COCOA, strokeWidth=round(1.8 * s, 2), faceOnly=True),
    ]


def petal(angle_deg, cx=50, cy=48, length=31, width=22):
    """One rounded petal from the centre outward, at the angle given."""
    a = math.radians(angle_deg)
    ux, uy = math.cos(a), math.sin(a)       # outward
    px, py = -uy, ux                        # across
    base = (cx + ux * 4, cy + uy * 4)
    tip = (cx + ux * length, cy + uy * length)
    w = width / 2
    c1 = (base[0] + px * w + ux * 6, base[1] + py * w + uy * 6)
    c2 = (tip[0] + px * w * 1.1, tip[1] + py * w * 1.1)
    c3 = (tip[0] - px * w * 1.1, tip[1] - py * w * 1.1)
    c4 = (base[0] - px * w + ux * 6, base[1] - py * w + uy * 6)
    return (f"M{f(base[0])} {f(base[1])} "
            f"C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(tip[0])} {f(tip[1])} "
            f"C{f(c3[0])} {f(c3[1])} {f(c4[0])} {f(c4[1])} {f(base[0])} {f(base[1])} Z")


# The stages drawn on their own, by raw value. Ripening, Sweet and the crowned
# stage are drawn from the peach, and stop following it only by being named
# here. The illustrations' import names one only when told to, with
# --draw-on-its-own, and says so; GrowthStageTests holds every stage drawn from
# the peach that isn't named here to today's peach (Antoine, 4 November 2026).
DRAWN_ON_THEIR_OWN = []

# The stages drawn from the peach, which DRAWN_ON_THEIR_OWN may name.
FOLLOWERS = ("ripening", "sweet", "crown")

SOIL_MOUND = "M16 88 C16 74 32 68 50 68 C68 68 84 74 84 88 C84 92 16 92 16 88 Z"

STAGES = [
    {
        "rank": "First Sprout",
        "spoken": "a first sprout",
        "parts": [
            dict(d="M50 72 C50 62 49 54 50 46", stroke=LEAF_DEEP, strokeWidth=4),
            dict(d="M50 54 C43 42 31 39 23 44 C29 53 41 57 50 54 Z", fill=LEAF),
            dict(d="M50 49 C56 35 70 30 79 35 C74 46 61 52 50 49 Z", fill=LEAF),
            dict(d=SOIL_MOUND, fill=SOIL),
            dict(d="M24 80 C34 75 66 75 76 80", stroke=SOIL_DEEP, strokeWidth=2, opacity=0.6),
        ] + small_face(50, 81, 0.9),
    },
    {
        "rank": "Little Bud",
        "spoken": "a little bud",
        "parts": [
            dict(d="M50 92 C50 80 50 66 50 54", stroke=LEAF_DEEP, strokeWidth=4),
            dict(d="M50 80 C42 70 30 70 24 76 C30 85 42 86 50 80 Z", fill=LEAF),
            dict(d="M50 74 C58 64 70 64 76 70 C70 79 58 80 50 74 Z", fill=LEAF),
            dict(d="M50 18 C61 26 67 37 65 46 C63 55 37 55 35 46 C33 37 39 26 50 18 Z", fill=PETAL),
            dict(d="M50 22 C47 31 46 40 47 52", stroke=PETAL_DEEP, strokeWidth=1.8, opacity=0.7),
            dict(d="M36 46 C40 54 46 57 50 57 C54 57 60 54 64 46 C60 50 55 52 50 52 C45 52 40 50 36 46 Z",
                 fill=LEAF_DEEP),
        ] + small_face(50, 37, 0.75),
    },
    {
        "rank": "Blossom",
        "spoken": "in blossom",
        "parts": [
            dict(d="M60 70 C72 72 80 82 78 94 C66 92 58 82 60 70 Z", fill=LEAF),
        ] + [dict(d=petal(-90 + 72 * i), fill=PETAL) for i in range(5)]
          + [dict(d=petal(-90 + 72 * i, length=22, width=9), fill=PETAL_DEEP, opacity=0.45)
             for i in range(5)]
          + [dict(d=circle(50, 48, 11), fill=POLLEN)]
          + small_face(50, 46, 0.8),
    },
    {
        "rank": "Ripening",
        "spoken": "ripening",
        # The ripe peach's own face, cheeks and all, on the green fruit: the
        # blush is the cheeks Sweet and the peach have, not a mark of its own,
        # which read as a spot (Antoine, 24 October).
        "parts": peach_parts(0.72, 14, 24, body=UNRIPE, high=UNRIPE_HI),
    },
    {
        "rank": "Sweet",
        "spoken": "ripe and sweet",
        "parts": peach_parts(0.86, 7, 12),
    },
    {
        "rank": "Perfectly Peachy",
        "spoken": "perfectly peachy",
        "the_peach": True,
        "parts": peach_parts(),
    },
    {
        # Today's peach, full size, crowned the way the witch's hat is worn:
        # on the head, over the top of the body, in the leaf's place.
        "rank": "Peachy Keen Supreme",
        "spoken": "wearing its crown",
        "parts": peach_parts()[1:] + [
            dict(d="M29 33 L26 11 L39 21 L50 5 L61 21 L74 11 L71 33 C62 36.5 38 36.5 29 33 Z",
                 fill=CROWN),
            dict(d="M29 33 C38 36.5 62 36.5 71 33 L70.4 28 C62 31.2 38 31.2 29.6 28 Z",
                 fill=CROWN_DEEP),
            dict(d=circle(26, 11, 3), fill=POLLEN, faceOnly=True),
            dict(d=circle(50, 5, 3.4), fill=PETAL, faceOnly=True),
            dict(d=circle(74, 11, 3), fill=POLLEN, faceOnly=True),
        ],
    },
]


def points(d):
    nums = [float(t) for t in d.replace(",", " ").replace("M", " ").replace("L", " ")
            .replace("C", " ").replace("Z", " ").split()]
    return list(zip(nums[0::2], nums[1::2]))


def check():
    wrong = [s for s in DRAWN_ON_THEIR_OWN if s not in FOLLOWERS]
    if wrong:
        sys.exit(f"DRAWN_ON_THEIR_OWN names {wrong}: only {list(FOLLOWERS)} follow the peach, "
                 "and Perfectly Peachy is the peach itself")
    bad = []
    for s in STAGES:
        for p in s["parts"]:
            half = (p.get("strokeWidth") or 0) / 2
            for x, y in points(p["d"]):
                if not (half <= x <= 100 - half and half <= y <= 100 - half):
                    bad.append((s["rank"], x, y))
    return bad


def svg(stage, face=True):
    out = []
    for p in stage["parts"]:
        if p.get("faceOnly") and not face:
            continue
        attrs = [f'd="{p["d"]}"']
        attrs.append(f'fill="{p["fill"]}"' if p.get("fill") else 'fill="none"')
        if p.get("stroke"):
            attrs += [f'stroke="{p["stroke"]}"', f'stroke-width="{p["strokeWidth"]}"',
                      'stroke-linecap="round"']
        if p.get("opacity") is not None:
            attrs.append(f'opacity="{p["opacity"]}"')
        out.append(f"<path {' '.join(attrs)}/>")
    return f'<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">{"".join(out)}</svg>'



# The enum's case for each rank, in `GrowthStage`'s order, and its raw value,
# which is what the title remembers.
CASES = [
    ("First Sprout", "firstSprout", "first-sprout"),
    ("Little Bud", "littleBud", "little-bud"),
    ("Blossom", "blossom", "blossom"),
    ("Ripening", "ripening", "ripening"),
    ("Sweet", "sweet", "sweet"),
    ("Perfectly Peachy", "perfectlyPeachy", "perfectly-peachy"),
    ("Peachy Keen Supreme", "crown", "crown"),
]


def js_number(n):
    """A number as JavaScript and `canonicalGrowthTable` print it: no ".0" on
    a whole one."""
    return str(int(n)) if float(n).is_integer() else repr(float(n))


def canonical():
    """The table as `canonicalGrowthTable()` writes it: the stage's own line,
    then one line per part, fields joined by `|`, empty where unset."""
    lines = []
    for (rank, _, raw), stage in zip(CASES, STAGES):
        assert stage["rank"] == rank, (stage["rank"], rank)
        lines.append(f"{raw}|{stage['spoken']}")
        for p in stage["parts"]:
            lines.append("|".join([
                raw,
                p["d"],
                p.get("fill") or "",
                js_number(p["opacity"]) if p.get("opacity") is not None else "",
                p.get("stroke") or "",
                js_number(p["strokeWidth"]) if p.get("strokeWidth") is not None else "",
                "true" if p.get("faceOnly") else "false",
            ]))
    return "\n".join(lines)


def swift():
    out = [
        "// Generated by tools/growth-stages.py from the drawings Antoine approved on",
        "// 24 October 2026. Change the drawings there, run it, and update the hash",
        "// `GrowthStageTests` pins; do not edit this file by hand.",
        "",
        "extension GrowthStage {",
        "    var table: GrowthTable {",
        "        switch self {",
    ]
    for _, case, _ in CASES:
        out.append(f"        case .{case}: return Self.{case}Table")
    out += ["        }", "    }"]
    own = [case for _, case, raw in CASES if raw in DRAWN_ON_THEIR_OWN]
    out += [
        "",
        "    /// The stages drawn from the peach that are drawn on their own, and no",
        "    /// longer follow it: `DRAWN_ON_THEIR_OWN` in the generator. Every other",
        "    /// stage drawn from the peach is today's peach, as `GrowthStageTests` holds.",
        f"    static let drawnOnTheirOwn: Set<GrowthStage> = [{', '.join('.' + c for c in own)}]",
    ]
    for (_, case, _), stage in zip(CASES, STAGES):
        out += ["", f"    static let {case}Table = GrowthTable(",
                f'        spoken: "{stage["spoken"]}",', "        parts: ["]
        for p in stage["parts"]:
            args = [f'"{p["d"]}"']
            if p.get("fill"):
                args.append(f'fill: "{p["fill"]}"')
            if p.get("opacity") is not None:
                args.append(f"opacity: {js_number(p['opacity'])}")
            if p.get("stroke"):
                args.append(f'stroke: "{p["stroke"]}"')
            if p.get("strokeWidth") is not None:
                args.append(f"strokeWidth: {js_number(p['strokeWidth'])}")
            if p.get("faceOnly"):
                args.append("faceOnly: true")
            out.append(f"            CostumePart({', '.join(args)}),")
        out += ["        ]", "    )"]
    out.append("}")
    return "\n".join(out) + "\n"


def main(argv):
    bad = check()
    if bad:
        sys.exit(f"outside the box: {bad}")
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(root, "Sources/PeachEngine/GrowthStages.swift"), "w") as f:
        f.write(swift())
    print("every point inside the box")
    print("sha256", hashlib.sha256(canonical().encode()).hexdigest())
    if len(argv) == 3 and argv[1] == "--preview":
        preview(argv[2])
    if len(argv) == 3 and argv[1] == "--json":
        with open(argv[2], "w") as out:
            json.dump(table(), out, indent=1)


def table():
    """The table as the web's copy holds it: the raw value, the words, and the
    parts with only the fields each one sets."""
    keys = ("d", "fill", "opacity", "stroke", "strokeWidth", "faceOnly")
    return [
        {"id": raw, "spoken": stage["spoken"],
         "parts": [{k: p[k] for k in keys if p.get(k) is not None and p.get(k) is not False}
                   for p in stage["parts"]]}
        for (_, _, raw), stage in zip(CASES, STAGES)
    ]


def preview(out):
    json.dump(STAGES, open(f"{out}/stages.json", "w"), indent=1)
    big = "".join(f'<figure><div class="big">{svg(s)}</div><figcaption>{s["rank"]}</figcaption></figure>'
                  for s in STAGES)
    small = "".join(f'<figure><div class="small">{svg(s, face=False)}</div></figure>' for s in STAGES)
    html = f"""<!doctype html><meta charset="utf-8"><style>
body{{margin:0;padding:24px;background:#FFF1EA;font:600 13px -apple-system,sans-serif;color:#7A4A33}}
.row{{display:flex;gap:18px;align-items:flex-end}} figure{{margin:0;text-align:center;width:128px;white-space:nowrap}}
.big svg{{width:96px;height:96px}} .small svg{{width:{SMALLEST}px;height:{SMALLEST}px}}
.small{{height:20px;display:flex;align-items:center;justify-content:center}}
h2{{font-size:13px;margin:18px 0 8px}}
</style><h2>At the title's 96pt</h2><div class="row">{big}</div>
<h2>At {SMALLEST}pt, the smallest peach in the app: a found chip's, at extra small text (faces dropped, as PeachMark drops its own)</h2>
<div class="row">{small}</div>"""
    open(f"{out}/preview.html", "w").write(html)


main(sys.argv)
