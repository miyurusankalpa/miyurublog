#!/usr/bin/env python3
"""Generate shiny, modern blog charts from ipv6_results.json."""

import collections
import ipaddress
import json
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LinearSegmentedColormap, to_rgb
from matplotlib.patches import Patch, Rectangle

_here = os.path.dirname(os.path.abspath(__file__))
RESULTS = next(
    (p for p in (
        os.path.join(_here, "ipv6_results.json"),
        os.path.join(_here, "lk_ipv6_results.json"),
    ) if os.path.exists(p)),
    os.path.join(_here, "ipv6_results.json"),
)
OWNERS = os.path.join(_here, "v6_owners.json")
OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    _here, "..", "content", "blog", "ipv6-on-lk-gov-websites"
)

# ---------------------------------------------------------------- style
INK = "#0F172A"
MUTED = "#64748B"
GRID = "#E2E8F0"
INDIGO = "#6366F1"
EMERALD = "#10B981"
ROSE = "#F43F5E"
AMBER = "#F59E0B"
SKY = "#0EA5E9"
SLATE = "#94A3B8"
SLATE_D = "#475569"

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 11,
    "text.color": INK,
    "axes.labelcolor": MUTED,
    "xtick.color": MUTED,
    "ytick.color": INK,
    "axes.edgecolor": GRID,
    "figure.facecolor": "white",
    "axes.facecolor": "white",
    "savefig.facecolor": "white",
})

results = json.load(open(RESULTS))["results"]
owners = json.load(open(OWNERS)) if os.path.exists(OWNERS) else {}

FRIENDLY = {
    "2606:4700": "Cloudflare",
    "2401:dd00": "LEARN (LK education network)",
    "2401:d00": "Bosch space — typo",
    "2a02:4780": "Hostinger",
    "2404:6800": "Google",
    "2600:9000": "Amazon CloudFront",
    "2603:1061": "Microsoft Azure",
    "2606:50c0": "GitHub",
    "2a07:7800": "20i Limited (UK)",
    "2620:cb": "ITRON",
    "2404:2f40": "XeonBD (Bangladesh)",
    "2607:f298": "DreamHost",
}


def lighten(hexc, f=0.55):
    r, g, b = to_rgb(hexc)
    return (r + (1 - r) * f, g + (1 - g) * f, b + (1 - b) * f)


def title(fig, text, sub=None):
    fig.text(0.01, 0.97, text, ha="left", va="top", fontsize=15,
             fontweight="bold", color=INK)
    if sub:
        fig.text(0.01, 0.915, sub, ha="left", va="top", fontsize=10.5, color=MUTED)


def grad_h(ax, x0, ymid, w, h, color, zorder=3):
    """Horizontal gradient bar (light -> color)."""
    cmap = LinearSegmentedColormap.from_list("g", [lighten(color, 0.6), color])
    arr = np.linspace(0, 1, 256).reshape(1, -1)
    ax.imshow(arr, extent=[x0, x0 + w, ymid - h / 2, ymid + h / 2],
              origin="lower", cmap=cmap, aspect="auto", zorder=zorder,
              interpolation="bilinear")


def grad_v(ax, xmid, y0, w, h, color, zorder=3):
    """Vertical gradient bar (color at top -> light at bottom)."""
    cmap = LinearSegmentedColormap.from_list("g", [lighten(color, 0.6), color])
    arr = np.linspace(0, 1, 256).reshape(-1, 1)
    ax.imshow(arr, extent=[xmid - w / 2, xmid + w / 2, y0, y0 + h],
              origin="lower", cmap=cmap, aspect="auto", zorder=zorder,
              interpolation="bilinear")


def clean(ax, xaxis=True):
    for s in ("top", "right", "left"):
        ax.spines[s].set_visible(False)
    ax.spines["bottom"].set_color(GRID)
    ax.tick_params(length=0)


def save(fig, name):
    path = os.path.join(OUT_DIR, name)
    fig.savefig(path, dpi=300, bbox_inches="tight", pad_inches=0.25,
                facecolor="white")
    plt.close(fig)
    print("wrote", path)


def group_of(r):
    cats = {e["category"] for e in r.get("entries", [])}
    if "Universities and Higher Education Institutions" in cats:
        return "universities"
    h = r["host"]
    if "gov.lk" in h:
        return "gov.lk"
    if h.endswith("ac.lk") or ".ac.lk" in h:
        return "ac.lk"
    if h.endswith(".lk"):
        return "other .lk"
    return "non-.lk"


def has_aaaa(r):
    return bool((r.get("dns") or {}).get("aaaa"))


# ---------------------------------------------------------------- 1. overall
n = len(results)
c = collections.Counter(r.get("verdict") for r in results.values())
rows = [
    ("No AAAA record", c["no_aaaa"], SLATE),
    ("AAAA works over IPv6", c["aaaa_ok"], EMERALD),
    ("Domain dead (NXDOMAIN)", c["domain_dead"], SLATE_D),
    ("AAAA present, broken", c["aaaa_tcp_fail"], ROSE),
]
fig, ax = plt.subplots(figsize=(9.5, 3.6))
fig.subplots_adjust(top=0.80, bottom=0.10, left=0.22, right=0.96)
ys = list(range(len(rows)))[::-1]
for y, (lab, val, col) in zip(ys, rows):
    grad_h(ax, 0, y, val, 0.58, col)
    ax.text(val + n * 0.012, y, f"{val}  ({100 * val / n:.1f}%)",
            va="center", fontsize=11.5, fontweight="bold", color=col)
ax.set_yticks(ys)
ax.set_yticklabels([r[0] for r in rows], fontsize=11.5, fontweight="bold")
ax.set_xlim(0, n * 1.16)
ax.set_ylim(-0.7, len(rows) - 0.3)
ax.set_xticks([])
clean(ax)
ax.spines["left"].set_visible(False)
ax.spines["bottom"].set_visible(False)
title(fig, "IPv6 support across 600 Sri Lankan government & university websites",
      f"every host checked: DNS AAAA → TCP :443 → TLS verify → HTTP, all over IPv6")
save(fig, "chart-overall.png")

# ---------------------------------------------------------------- 2. groups
groups = ["gov.lk", "ac.lk", "universities", "other .lk", "non-.lk"]
grows = []
for g in groups:
    members = [r for r in results.values() if group_of(r) == g]
    aaaa = [r for r in members if has_aaaa(r)]
    ok = [r for r in aaaa if r.get("verdict") == "aaaa_ok"]
    grows.append((g, len(members), len(aaaa), len(ok)))

fig, ax = plt.subplots(figsize=(9.5, 4.4))
fig.subplots_adjust(top=0.78, bottom=0.16)
x = np.arange(len(grows))
w = 0.26
series = [
    ("Has AAAA record", INDIGO, -w, lambda t, a, o: a),
    ("IPv6 fully works", EMERALD, 0, lambda t, a, o: o),
    ("IPv6 present but broken", ROSE, w, lambda t, a, o: a - o),
]
maxpct = max(100 * a / t for _, t, a, _ in grows)
for gi, row in enumerate(grows):
    t, a, o = row[1], row[2], row[3]
    used = []
    for lab, col, off, fn in series:
        v = 100 * fn(t, a, o) / t
        if v <= 0:
            continue
        lv = v
        for u in used:
            if abs(lv - u) < 2.4:
                lv = u + 2.4
        used.append(lv)
        grad_v(ax, x[gi] + off, 0, w * 0.92, v, col)
        ax.text(x[gi] + off, lv + 0.7, f"{v:.1f}%", ha="center",
                fontsize=9.5, fontweight="bold", color=col)
ax.set_xticks(x)
ax.set_xticklabels([f"{g}\n(n={t})" for g, t, _, _ in grows], fontsize=10.5,
                   fontweight="bold")
ax.set_ylabel("% of hosts")
ax.set_ylim(0, maxpct * 1.22)
ax.yaxis.grid(True, color=GRID, lw=0.9)
ax.set_axisbelow(True)
clean(ax)
ax.spines["left"].set_visible(False)
ax.tick_params(axis="y", length=0)
leg = [Patch(facecolor=lighten(col, 0.35), label=lab) for lab, col, _, _ in series]
ax.legend(handles=leg, loc="upper center", bbox_to_anchor=(0.5, 1.14), ncol=3,
          frameon=False, fontsize=10)
title(fig, "IPv6 deployment by group",
      "universities already in the gov dataset are counted under .ac.lk / .gov.lk")
save(fig, "chart-groups.png")

# ---------------------------------------------------------------- 3. broken
broken = [
    r for r in results.values()
    if str(r.get("verdict", "")).startswith("aaaa_") and r["verdict"] != "aaaa_ok"
]
broken.sort(key=lambda r: r["host"])
ERR_STYLE = {
    "refused": ("CONNECTION REFUSED", ROSE),
    "timed out": ("TIMEOUT", AMBER),
    "No route": ("NO ROUTE", SLATE),
}


def err_style(r):
    e = (r.get("tcp") or {}).get("error") or ""
    for k, v in ERR_STYLE.items():
        if k in e:
            return v
    return ("FAILED", SLATE)


fig, ax = plt.subplots(figsize=(11, 5.4))
fig.subplots_adjust(top=0.80, left=0.02, right=0.98, bottom=0.04)
ax.set_xlim(0, 1)
ax.set_ylim(-0.6, len(broken) - 0.2)
ax.axis("off")

COLX = {"host": 0.012, "aaaa": 0.30, "err": 0.60, "v4": 0.895}
HEAD_Y = len(broken) - 0.15
for key, head in (("host", "HOST"), ("aaaa", "AAAA"), ("err", "FAILURE"),
                  ("v4", "IPv4")):
    ax.text(COLX[key], HEAD_Y, head, fontsize=9, fontweight="bold",
            color=MUTED, ha="left" if key != "v4" else "center")

for i, r in enumerate(broken):
    y = len(broken) - 2 - i
    if i % 2 == 0:
        ax.axhspan(y - 0.42, y + 0.42, 0, 1, facecolor="#F8FAFC",
                   edgecolor="none", zorder=1)
    ax.text(COLX["host"], y, r["host"], fontsize=11, fontweight="bold",
            color=INK, va="center", ha="left", zorder=3,
            family="DejaVu Sans")
    aaaa = (r["dns"]["aaaa"])[0]
    ax.text(COLX["aaaa"], y, aaaa, fontsize=10, color=SLATE_D, va="center",
            ha="left", family="DejaVu Sans Mono", zorder=3)
    lab, col = err_style(r)
    ax.add_patch(Rectangle(
        (COLX["err"], y - 0.26), 0.245, 0.52,
        facecolor=lighten(col, 0.80), edgecolor=lighten(col, 0.30),
        lw=1.2, zorder=3, clip_on=False))
    ax.text(COLX["err"] + 0.122, y, lab, fontsize=9, fontweight="bold",
            color=col, va="center", ha="center", zorder=4)
    v4ok = bool((r.get("v4_tcp") or {}).get("ok"))
    v4col = EMERALD if v4ok else ROSE
    v4txt = "UP" if v4ok else "DOWN"
    ax.add_patch(Rectangle(
        (COLX["v4"] - 0.05, y - 0.26), 0.10, 0.52,
        facecolor=lighten(v4col, 0.82), edgecolor=lighten(v4col, 0.30),
        lw=1.2, zorder=3, clip_on=False))
    ax.text(COLX["v4"], y, v4txt, fontsize=9, fontweight="bold",
            color=v4col, va="center", ha="center", zorder=4)

title(fig, "AAAA records that do NOT work over IPv6 — 10 hosts",
      "9 of 10 are IPv6-only failures: the same site answers perfectly on IPv4")
save(fig, "chart-broken.png")

# ---------------------------------------------------------------- 4. origin
p32_counts = collections.Counter()
p32_verdict = collections.Counter()
for r in results.values():
    aaaa = (r.get("dns") or {}).get("aaaa") or []
    if not aaaa:
        continue
    p32 = str(ipaddress.ip_network(aaaa[0] + "/32", strict=False)).split("/")[0]
    p32_counts[p32] += 1
    if r.get("verdict") == "aaaa_ok":
        p32_verdict[p32] += 1

items = sorted(p32_counts.items(), key=lambda kv: -kv[1])
fig, ax = plt.subplots(figsize=(10, 5.6))
fig.subplots_adjust(top=0.80, bottom=0.08, left=0.30, right=0.97)
ys = list(range(len(items)))[::-1]
maxv = items[0][1]
for y, (p32, val) in zip(ys, items):
    short = ":".join(p32.split(":")[:2])
    owner = FRIENDLY.get(short) or (owners.get(p32, {}) or {}).get("name") or short
    domestic = short in ("2401:dd00",)
    col = AMBER if domestic else (ROSE if short == "2401:d00" else INDIGO)
    grad_h(ax, 0, y, val, 0.56, col)
    ok = p32_verdict.get(p32, 0)
    tag = f"  {val}" + (f"  ·  {ok} works" if ok != val else "")
    ax.text(val + maxv * 0.015, y, tag, va="center", fontsize=10.5,
            fontweight="bold", color=col)
ax.set_yticks(ys)
ax.set_yticklabels(
    [FRIENDLY.get(':'.join(p.split(':')[:2]), ':'.join(p.split(':')[:2]))
     for p, _ in items],
    fontsize=11, fontweight="bold")
ax.set_xlim(0, maxv * 1.34)
ax.set_xticks([])
clean(ax)
ax.spines["left"].set_visible(False)
ax.spines["bottom"].set_visible(False)
title(fig, "Who actually provides the IPv6? (owners via RDAP / WHOIS)",
      "of 92 hosts with an AAAA record — domestic ranges highlighted")
ax.legend(handles=[
    Patch(facecolor=lighten(INDIGO, 0.35), label="Foreign CDN / cloud"),
    Patch(facecolor=lighten(AMBER, 0.35), label="LEARN (Sri Lanka)"),
    Patch(facecolor=lighten(ROSE, 0.35), label="Bosch space — typo'd LEARN address"),
], loc="lower right", frameon=False, fontsize=9.5)
save(fig, "chart-v6-origin.png")

print("done")
