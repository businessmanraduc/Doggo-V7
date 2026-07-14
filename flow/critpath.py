# critpath.py -- Fmax + critical path from a nextpnr log (clock-agnostic).
# usage: python3 critpath.py <nextpnr.log> [--brief]

import sys

def short(name):
    if name.startswith("$nextpnr"):
        return "carry"
    for cut in ("_TRELLIS", "_LUT", "_PFUMX", "_L6MUX", "_CCU2", "_MULT", "_DI_", "$", "["):
        if cut in name:
            name = name[:name.index(cut)]
    return name.strip(".") or "?"

def clkname(raw):
    return raw.replace("$glbnet$", "").replace("$TRELLIS_IO_IN", "")

path  = sys.argv[1]
brief = "--brief" in sys.argv[2:]
lines = open(path).read().splitlines()

fmax = {}
for line in lines:
    if "Max frequency for clock" in line:
        fmax[clkname(line.split("'")[1])] = float(line.split(":")[-1].split("MHz")[0].split()[-1])

if not fmax:
    print("no clock found in log")
    sys.exit(1)

bind = min(fmax, key=fmax.get)

hops, inside = [], False
for line in lines:
    if "Critical path report for clock" in line:
        inside = bind in clkname(line)
        continue
    if inside:
        if "ns logic," in line:
            break
        w = line.split()
        if len(w) >= 6 and w[1] in ("clk-to-q", "routing", "logic", "setup"):
            hops.append((w[1], float(w[2]), float(w[3]), short(w[5])))

rows = []
for kind, delay, total, name in hops:
    endpoint = kind in ("clk-to-q", "setup")
    if not endpoint and rows and not rows[-1][3] and rows[-1][2] == name:
        rows[-1][0] += delay
        rows[-1][1]  = total
    else:
        rows.append([delay, total, name, endpoint])

start = rows[0][2]  if rows else "?"
end   = rows[-1][2] if rows else "?"
ns    = rows[-1][1] if rows else 0.0

if brief:
    print("%6.2f MHz  %-20s -> %s" % (fmax[bind], start, end))
    sys.exit()

print()
print("clock %s : %.2f MHz  (%.2f ns critical)" % (bind, fmax[bind], ns))
print("path  %s -> %s" % (start, end))
print()
worst = max((r[0] for r in rows if not r[3]), default=0)
print("    ns   cumul   signal")
for i, (delay, total, name, ep) in enumerate(rows):
    tag = "  (start)" if i == 0 else "  (end)" if i == len(rows) - 1 else ("  <= worst" if delay == worst else "")
    print("  %5.2f  %6.2f   %s%s" % (delay, total, name, tag))

