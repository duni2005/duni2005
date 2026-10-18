"""Summarize recorded executable battles; never modify or emulate game rules."""
import csv
import json
import math
import os
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "migration"


def read(name):
    return json.loads((OUT / name).read_text())


def fmt(value):
    return "—" if value is None else f"{value:.2f}"


web = read("phase105-web-comparison.json")
before = read("phase105-godot-before.json")
after = read("phase105-godot-after.json")
metrics = ["first_attack", "first_hit", "gap", "travel", "target_changes", "attacks", "hits", "parry", "dodge", "clash", "idle", "danger_time", "escape"]
summary = {"scenarios": len(web), "horizon_seconds": 20, "aggregate_mae": {}, "divergences": [], "stance_means": {}}
for key in metrics:
    source_key = "hit_ticks" if key == "hits" else key
    errors = []
    for group in (before, after):
        pairs = [(w.get(source_key, 0), g.get(key)) for w, g in zip(web, group)]
        errors.append(statistics.mean(abs(w-g) for w, g in pairs if w is not None and g is not None))
    summary["aggregate_mae"][key] = dict(before=errors[0], after=errors[1])

for w, g in zip(web, after):
    assert (w["name"], w["seed"]) == (g["name"], g["seed"])
    divergent = None
    for sw, sg in zip(w["trace"], g["trace"]):
        # Diagnostic threshold, not an acceptance threshold or tuning target.
        distance = math.hypot(sw["actors"][0]["x"]-sg["actors"][0]["x"], sw["actors"][0]["y"]-sg["actors"][0]["y"])
        if distance >= 80:
            divergent = dict(time=sw["time"], distance=distance, web=sw["actors"][0], godot=sg["actors"][0]); break
    summary["divergences"].append(dict(name=w["name"], seed=w["seed"], first_80px=divergent))

for stance in ("normal", "cautious", "rush", "cover"):
    summary["stance_means"][stance] = {}
    for name, group in (("web", web), ("before", before), ("after", after)):
        values = [r for r in group if r["name"] == "stance_"+stance]
        summary["stance_means"][stance][name] = {key: statistics.mean(r.get("hit_ticks" if name == "web" and key == "hits" else key, 0) for r in values) for key in metrics}

lines = ["# Recorded AI comparison", "", "Source / before / after. Twenty simulation seconds, or natural battle completion. No cross-engine seed equivalence.", "", "## First engagement and motion", "", "| Scenario (seed) | First attack s | First HP loss s | Mean nearest enemy px | Total travel px | Target changes |", "| --- | --- | --- | --- | --- | --- |"]
for w, b, a in zip(web, before, after):
    vals = [" / ".join(fmt(r[key]) for r in (w, b, a)) for key in ("first_attack", "first_hit", "gap", "travel", "target_changes")]
    lines.append(f"| {w['name']} ({w['seed']}) | " + " | ".join(vals) + " |")
lines += ["", "## Activity", "", "| Scenario (seed) | Attack starts | HP-loss ticks | Parry starts | Threat dodge decisions | Clash | Idle unit-seconds | Danger unit-seconds | Escape decisions |", "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
for w, b, a in zip(web, before, after):
    vals = []
    for key in ("attacks", "hits", "parry", "dodge", "clash", "idle", "danger_time", "escape"):
        vals.append(" / ".join(fmt(r.get("hit_ticks" if r is w and key == "hits" else key, 0)) for r in (w, b, a)))
    lines.append(f"| {w['name']} ({w['seed']}) | " + " | ".join(vals) + " |")

lines += ["", "## Aggregate absolute error", "", "| Metric | Before | After |", "| --- | --- | --- |"]
for key, values in summary["aggregate_mae"].items():
    lines.append(f"| {key} | {fmt(values['before'])} | {fmt(values['after'])} |")

lines += ["", "## Endpoints", "", "Ninety-second cap; >90 means censored, not a finished fight.", "", "| Scenario | Web end s | Godot end s |", "| --- | --- | --- |"]
for w, a in zip(read("phase105-web-endpoints.json"), read("phase105-godot-endpoints.json")):
    lines.append(f"| {w['name']} | {fmt(w['duration']) if w['completed'] else '>90'} | {fmt(a['duration']) if a['completed'] else '>90'} |")
lines += ["", "## FPS diagnostics", "", "| Engine / Scenario | First attack s | Attacks | Parry | Dodge | Travel px | Mean gap px |", "| --- | --- | --- | --- | --- | --- | --- |"]
for engine, file in (("Web", "phase105-web-fps.json"), ("Godot", "phase105-godot-fps.json")):
    for r in read(file):
        lines.append(f"| {engine} / {r['name']} | " + " | ".join(fmt(r[k]) for k in ("first_attack", "attacks", "parry", "dodge", "travel", "gap")) + " |")

(OUT / "phase105-comparison-summary.json").write_text(json.dumps(summary, indent=2)+"\n")
(OUT / "phase105-comparison-tables.md").write_text("\n".join(lines)+"\n")
with (OUT / "phase105-trajectories.csv").open("w") as file:
    writer = csv.writer(file); writer.writerow(["engine", "scenario", "seed", "time", "actor", "x", "y", "target", "plan", "intent", "state"])
    for name, group in (("web", web), ("before", before), ("after", after)):
        for r in group:
            for tick in r["trace"]:
                for i, u in enumerate(tick["actors"]):
                    writer.writerow([name, r["name"], r["seed"], tick["time"], i, *[u.get(k) for k in ("x", "y", "target", "plan", "intent", "state")]])

os.environ.setdefault("MPLCONFIGDIR", "/tmp/duni-matplotlib")
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, axes = plt.subplots(2, 3, figsize=(14, 9), constrained_layout=True)
for col, (scenario, seed) in enumerate((("warrior_duel", 29), ("front_rear", 29), ("stance_cover", 101))):
    for label, group, color in (("HTML", web, "#258158"), ("Godot before", before, "#ac7969"), ("Godot after", after, "#6253ac")):
        r = next(r for r in group if r["name"] == scenario and r["seed"] == seed)
        x = [s["actors"][0]["x"] for s in r["trace"]]; y = [s["actors"][0]["y"] for s in r["trace"]]; t = [s["time"] for s in r["trace"]]
        axes[0, col].plot(x, y, color=color, label=label, alpha=.85)
        axes[0, col].scatter([x[0]], [y[0]], color=color, s=15)
        distance = [math.hypot(s["actors"][0]["x"]-s["actors"][len(s["actors"])//2]["x"], s["actors"][0]["y"]-s["actors"][len(s["actors"])//2]["y"]) for s in r["trace"]]
        axes[1, col].plot(t, distance, color=color, label=label)
        if r["first_attack"] is not None: axes[1, col].axvline(r["first_attack"], color=color, ls=":", alpha=.65)
    axes[0, col].set(xlim=(0,800), ylim=(800,0), xlabel="x (logical px)", ylabel="y (logical px)", title=scenario+f" / seed {seed}", aspect="equal")
    axes[1, col].set(xlabel="simulation seconds", ylabel="Actor 0 to first opponent (px)", xlim=(0,20));axes[1,col].grid(alpha=.2)
axes[0,0].legend(fontsize=8);axes[1,0].legend(fontsize=8)
fig.suptitle("Executable battle traces at 0.25 s intervals; dotted lines = first team attack\nIndependent RNG algorithms. This is a diagnostic comparison, not matched stochastic trajectories.", fontsize=12)
fig.savefig(OUT / "phase105-trajectories.png", dpi=150)
fig.savefig(OUT / "phase105-trajectories.svg")
print("Comparison tables, summary, CSV and trajectory figures generated.")
