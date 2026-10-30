#!/usr/bin/env python3
"""The UI tests' shard map, what a change runs, and proof that every test ran.

    plan.py check                  every UI test class in exactly one shard
    plan.py choose CHANGED         the scope and the shard matrix, for CI
    plan.py verify SHARD BUNDLE CLASSES [--out FILE]
                                   the tests a result bundle ran, against the source
    plan.py summary DIR            the shards' counts added up, for `ui-tests`
    plan.py balance N              a proposed map for N shards, from its times
    plan.py classes LIST           a list's classes, one per line (smoke, data-only)

**Why a committed map rather than a split worked out at run time.** A split
computed on the runner is invisible: nobody can say from the repository which
shard ran a test, and a class that matches no rule is dropped without a word.
Committed, the map is read and reviewed like code, and `check` fails the run
when a class is in no shard or in two, or the map names a class that no longer
exists. Adding a UI test class therefore means adding a line to `shards.txt`.

**The source is read, and the result bundle is held to it.** Classes and test
methods come from `UITests/*.swift`, comments stripped first so a doc comment
quoting a declaration is not one. That parse is only as good as its regexes, so
every shard's `verify` compares the test IDs its bundle actually ran against
the ones parsed here, in both directions: a test the parse missed, or one that
never ran, fails the shard by name.

Standard library only, so it runs on the Ubuntu planner and the macOS shards
alike without installing anything.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
TESTS = ROOT / "UITests"
TARGET = "PeachOfAWordUITests"

# A change that touches nothing outside these runs the engine tests,
# `checkout-less-tests` and the data-only UI classes, not the whole suite.
# Nothing here is compiled: Data/ is copied into the bundles as resources, and
# the rest never reaches a build. Markdown anywhere, since none of it ships.
DATA_ONLY_PREFIXES = ("Data/", "TestFlight/", "docs/", "tools/")
DATA_ONLY_SUFFIXES = (".md",)

# A label on a pull request that runs the whole suite whatever it touches.
FULL_LABEL = "full-ui"

CLASS = re.compile(r"^(?:@\w+\s+)*(?:final\s+)?class\s+(\w+)\s*:\s*XCTestCase\b")
EXTENSION = re.compile(r"^extension\s+(\w+)\b")
TOP_LEVEL = re.compile(r"^(?:\S)")
TEST = re.compile(r"^\s+(?:@\w+\s+)*func\s+(test\w*)\s*\(\s*\)")


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def strip_comments(text):
    """The source with `//` and `/* */` comments blanked, line numbers kept.

    String literals are left alone, so a `//` inside one (a URL) does not cut
    the line short.
    """
    out, i, n = [], 0, len(text)
    in_string = in_block = False
    while i < n:
        c = text[i]
        if in_block:
            if text.startswith("*/", i):
                in_block = False
                i += 2
            else:
                out.append("\n" if c == "\n" else " ")
                i += 1
        elif in_string:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"' or c == "\n":
                in_string = False
            i += 1
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("/*", i):
            in_block = True
            i += 2
        else:
            if c == '"':
                in_string = True
            out.append(c)
            i += 1
    return "".join(out)


def source_tests():
    """{class: [test method, ...]} for every XCTestCase in UITests/.

    A test belongs to the top-level class or extension it is written in. An
    extension of a type that is not a test class contributes nothing.
    """
    classes, owner_of = {}, {}
    for path in sorted(TESTS.glob("*.swift")):
        context = None
        for line in strip_comments(path.read_text()).splitlines():
            m = CLASS.match(line)
            if m:
                context = m.group(1)
                if context in classes:
                    fail(f"{path.name}: class {context} is declared twice")
                classes[context] = []
                owner_of[context] = path.name
                continue
            m = EXTENSION.match(line)
            if m:
                context = m.group(1)
                continue
            if TOP_LEVEL.match(line) and not line.startswith("}"):
                context = None
                continue
            m = TEST.match(line)
            if m and context is not None:
                classes.setdefault(context, [])
                classes[context].append(m.group(1))
    # Tests in an extension of something that is not a test class do not run.
    return {c: sorted(t) for c, t in classes.items() if c in owner_of}


def read_list(name, columns):
    """The rows of a committed list, `#` lines and blank lines dropped.

    Each row is `columns` whitespace-separated fields, the last of which takes
    the rest of the line. A `#` later in a row is part of it.
    """
    rows = []
    path = HERE / name
    for number, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split(None, columns - 1)
        if len(fields) != columns:
            fail(f"{name}:{number}: expected {columns} fields, got {line!r}")
        rows.append((number, fields))
    return rows


def shard_map():
    """[(shard, class, seconds)] from shards.txt, in file order."""
    rows = []
    for number, (shard, klass, seconds) in read_list("shards.txt", 3):
        try:
            rows.append((shard, klass, int(seconds)))
        except ValueError:
            fail(f"shards.txt:{number}: seconds must be a whole number, got {seconds!r}")
    return rows


def class_list(name):
    """The classes a two-column list names: `Class  why it is here`."""
    return [fields[0] for _, fields in read_list(name, 2)]


def check():
    """Every class in exactly one shard, and every list naming real classes."""
    tests = source_tests()
    rows = shard_map()
    problems = []

    seen = {}
    for shard, klass, _ in rows:
        seen.setdefault(klass, []).append(shard)
    for klass in sorted(tests):
        if klass not in seen:
            problems.append(f"{klass} is in no shard: add it to .github/ui-tests/shards.txt")
    for klass, shards in sorted(seen.items()):
        if len(shards) > 1:
            problems.append(f"{klass} is in {len(shards)} shards ({', '.join(shards)}): keep one")
        if klass not in tests:
            problems.append(f"shards.txt names {klass}, which is not a test class in UITests/")
    for name in ("data-only.txt", "smoke.txt"):
        listed = class_list(name)
        for klass in listed:
            if klass not in tests:
                problems.append(f"{name} names {klass}, which is not a test class in UITests/")
        for klass in {k for k in listed if listed.count(k) > 1}:
            problems.append(f"{name} names {klass} twice")
    for klass, methods in sorted(tests.items()):
        if not methods:
            problems.append(f"{klass} has no test methods the parse could find")

    if problems:
        for p in problems:
            print(f"error: {p}", file=sys.stderr)
        sys.exit(1)

    data = set(class_list("data-only.txt"))
    by_shard = {}
    for shard, klass, seconds in rows:
        s = by_shard.setdefault(shard, [0, 0, 0, 0])
        s[0] += 1
        s[1] += len(tests[klass])
        s[2] += seconds
        s[3] += seconds if klass in data else 0
    print(f"{len(tests)} classes, {sum(len(t) for t in tests.values())} tests, "
          f"{len(by_shard)} shards, each class in exactly one")
    for shard, (n, t, secs, dsecs) in sorted(by_shard.items()):
        print(f"  shard {shard}: {n:2} classes, {t:3} tests, "
              f"about {secs / 60:4.1f} min, {dsecs / 60:4.1f} of it data-only")


def scope(changed, event, labels):
    """("full" or "data", why)."""
    if event != "pull_request":
        return "full", f"a {event} runs the whole suite"
    if FULL_LABEL in labels:
        return "full", f"the {FULL_LABEL} label is on the pull request"
    if not changed:
        return "full", "no changed files could be listed"
    code = [p for p in changed
            if not p.startswith(DATA_ONLY_PREFIXES) and not p.endswith(DATA_ONLY_SUFFIXES)]
    if code:
        more = f" and {len(code) - 1} more" if len(code) > 1 else ""
        return "full", f"{code[0]}{more} is outside the data-only paths"
    return "data", f"all {len(changed)} changed files are data, docs, tools or Markdown"


def choose(changed_path):
    """Writes scope, why, tests and the shard matrix as GitHub step outputs."""
    tests = source_tests()
    changed = []
    if changed_path and os.path.exists(changed_path):
        changed = [l.strip() for l in open(changed_path) if l.strip()]
    event = os.environ.get("EVENT", "")
    try:
        labels = json.loads(os.environ.get("LABELS") or "[]") or []
    except json.JSONDecodeError:
        labels = []
    kind, why = scope(changed, event, labels)
    keep = set(tests) if kind == "full" else set(class_list("data-only.txt"))

    shards = {}
    for shard, klass, seconds in shard_map():
        if klass in keep:
            s = shards.setdefault(shard, {"shard": shard, "classes": [], "tests": 0, "seconds": 0})
            s["classes"].append(klass)
            s["tests"] += len(tests[klass])
            s["seconds"] += seconds
    matrix = [dict(s, classes=" ".join(s["classes"])) for s in shards.values()]
    total = sum(s["tests"] for s in matrix)

    print(f"scope: {kind}, because {why}", file=sys.stderr)
    for s in matrix:
        print(f"  shard {s['shard']}: {s['tests']} tests, about {s['seconds'] / 60:.1f} min: "
              f"{s['classes']}", file=sys.stderr)
    print(f"scope={kind}")
    print(f"why={why}")
    print(f"tests={total}")
    print(f"shards={json.dumps(matrix, separators=(',', ':'))}")


def bundle_tests(bundle):
    """{"Class/test()": result} from a result bundle, through xcresulttool."""
    out = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", bundle],
                         check=True, capture_output=True, text=True).stdout
    found = {}

    def walk(node, klass):
        if node.get("nodeType") == "Test Suite":
            klass = node["name"]
        if node.get("nodeType") == "Test Case":
            found[f"{klass}/{node['name']}"] = node.get("result", "unknown")
            return
        for child in node.get("children", []):
            walk(child, klass)

    for node in json.loads(out).get("testNodes", []):
        walk(node, None)
    return found


def verify(shard, bundle, classes, out_path):
    """The bundle ran exactly the source's tests for these classes."""
    tests = source_tests()
    expected = {f"{k}/{t}()" for k in classes for t in tests.get(k, [])}
    unknown = [k for k in classes if k not in tests]
    ran = bundle_tests(bundle) if os.path.exists(bundle) else {}
    missing = sorted(expected - set(ran))
    unexpected = sorted(set(ran) - expected)
    results = {}
    for result in ran.values():
        results[result] = results.get(result, 0) + 1
    skips = sorted(i for i, r in ran.items() if r == "Skipped")
    summary = {"shard": shard, "classes": len(classes), "expected": len(expected), "ran": len(ran),
               "results": results, "skipped": skips, "missing": missing, "unexpected": unexpected}
    if out_path:
        with open(out_path, "w") as f:
            json.dump(summary, f, indent=1)
    print(f"shard {shard}: {len(ran)} of {len(expected)} tests ran: "
          + ", ".join(f"{n} {r.lower()}" for r, n in sorted(results.items())))
    for i in skips:
        print(f"  skipped: {i}")
    for k in unknown:
        print(f"error: {k} is not a test class in UITests/", file=sys.stderr)
    for i in missing:
        print(f"error: {i} never ran", file=sys.stderr)
    for i in unexpected:
        print(f"error: {i} ran, but the source has no such test in this shard", file=sys.stderr)
    if unknown or missing or unexpected:
        sys.exit(1)


def summary(counts_dir):
    """The shards' counts as a Markdown table, failing unless they add up.

    Reads the plan's scope, reason and test total from SCOPE, WHY and TESTS.
    The sum is the second line of defence after each shard's own `verify`: a
    shard that never reported is a missing file here, not a smaller total.
    """
    want = int(os.environ.get("TESTS") or 0)
    counts = []
    if os.path.isdir(counts_dir):
        for name in sorted(os.listdir(counts_dir)):
            if name.endswith(".json"):
                with open(os.path.join(counts_dir, name)) as f:
                    counts.append(json.load(f))
    counts.sort(key=lambda c: (len(c["shard"]), c["shard"]))
    ran = sum(c["ran"] for c in counts)
    totals = {}
    for c in counts:
        for result, n in c["results"].items():
            totals[result] = totals.get(result, 0) + n
    print(f"### UI tests: {os.environ.get('SCOPE') or 'no plan'}\n")
    print(f"{os.environ.get('WHY') or 'The plan did not run.'}\n")
    print("| shard | classes | ran | of | passed | skipped | failed |")
    print("|---|---|---|---|---|---|---|")
    for c in counts:
        r = c["results"]
        print(f"| {c['shard']} | {c['classes']} | {c['ran']} | {c['expected']} | "
              f"{r.get('Passed', 0)} | {r.get('Skipped', 0)} | {r.get('Failed', 0)} |")
    print(f"| **all** | | **{ran}** | **{want}** | {totals.get('Passed', 0)} | "
          f"{totals.get('Skipped', 0)} | {totals.get('Failed', 0)} |\n")
    for c in counts:
        for i in c["skipped"]:
            print(f"- skipped in shard {c['shard']}: `{i}`")
        for i in c["missing"]:
            print(f"- **never ran**, shard {c['shard']}: `{i}`")
        for i in c["unexpected"]:
            print(f"- **ran unplanned**, shard {c['shard']}: `{i}`")
    problems = any(c["missing"] or c["unexpected"] for c in counts)
    if not counts or ran != want or problems:
        print(f"\n**{ran} tests ran across the shards, and the plan has {want}.**")
        sys.exit(1)


def balance(n):
    """A shards.txt for n shards, balanced on the times in the current one.

    Two loads per shard: its whole time, which every code change waits on, and
    its data-only time, which a data-only change waits on. What is minimised
    is the slowest shard's whole time plus half the slowest shard's data-only
    time: code changes are the common case, and a data-only run left with one
    shard doing most of its work would gain little from the targeting. Longest
    first onto the lightest shard, then single moves and pairwise swaps while
    either helps. Deterministic, so the same times give the same map. Prints
    the file; nothing is written.
    """
    data = set(class_list("data-only.txt"))
    rows = sorted(((k, s) for _, k, s in shard_map()), key=lambda r: (-r[1], r[0]))
    seconds = dict(rows)
    where = {}
    for klass, secs in rows:
        def load(i):
            return (sum(seconds[k] for k, s in where.items() if s == i and k in data)
                    if klass in data else 0,
                    sum(seconds[k] for k, s in where.items() if s == i))
        where[klass] = min(range(n), key=lambda i: (load(i), i))

    def cost(placement):
        total = [0] * n
        dtotal = [0] * n
        for k, s in placement.items():
            total[s] += seconds[k]
            dtotal[s] += seconds[k] if k in data else 0
        return (max(total) + max(dtotal) / 2, sorted(total, reverse=True))

    best = cost(where)
    improved = True
    while improved:
        improved = False
        names = [k for k, _ in rows]
        for a in names:
            for target in range(n):
                if where[a] == target:
                    continue
                trial = dict(where, **{a: target})
                if cost(trial) < best:
                    where, best, improved = trial, cost(trial), True
            for b in names:
                if where[a] == where[b]:
                    continue
                trial = dict(where, **{a: where[b], b: where[a]})
                if cost(trial) < best:
                    where, best, improved = trial, cost(trial), True

    for i in range(n):
        total = sum(seconds[k] for k, s in where.items() if s == i)
        dtotal = sum(seconds[k] for k, s in where.items() if s == i and k in data)
        print(f"# shard {i + 1}: about {total / 60:.1f} min, {dtotal / 60:.1f} of it data-only")
    for klass, secs in sorted(rows, key=lambda r: (where[r[0]], -r[1], r[0])):
        print(f"{where[klass] + 1:<8} {klass:<34} {secs}")


def main(argv):
    if len(argv) < 2:
        fail(__doc__.strip().splitlines()[2])
    command, args = argv[1], argv[2:]
    if command == "check":
        check()
    elif command == "choose":
        choose(args[0] if args else None)
    elif command == "verify" and len(args) >= 3:
        out = None
        if "--out" in args:
            i = args.index("--out")
            out = args[i + 1]
            args = args[:i] + args[i + 2:]
        verify(args[0], args[1], args[2].split(), out)
    elif command == "summary" and args:
        summary(args[0])
    elif command == "balance" and args:
        balance(int(args[0]))
    elif command == "classes" and args:
        print("\n".join(class_list(args[0])))
    else:
        fail(f"unknown command: {' '.join(argv[1:])}")


if __name__ == "__main__":
    main(sys.argv)
