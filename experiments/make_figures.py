"""fig2, fig4a, fig4b, fig4c (PDF, single column) and table1.tex from experiments/results.

Run after run_experiments.py. Genomes are drawn as vector paths (polylines exported by the runner),
images that *are* pixels (targets, the 128px renders the evaluator compares, the overlay) stay raster.
"""
import csv
import os
import re
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import ListedColormap
from PIL import Image
from scipy.stats import mannwhitneyu

from common import (CONFIGS, EXP, FIGURES, RESULTS, TABLES, TARGET_FILES, TARGETS, runner)

CM = 1 / 2.54
COL_W = 8.5 * CM
BLUE, ORANGE, RED = "#2a78d6", "#eb6834", "#e34948"
INK, INK2, MUTED = "#0b0b0b", "#52514e", "#898781"
TARGET_LABEL = {"tsyn": "T-syn", "test8": "test8"}
CONFIG_LABEL = {
    "baseline": "Baseline",
    "raw_roulette": r"Raw roulette ($\mu$=100)",
    "ranking_no_trunc": r"Ranking, no trunc. ($\mu$=100)",
    "fixed_sigma": r"Fixed $\sigma$=0.05",
    "rmse": "RMSE fitness",
    "equal_weights": "Equal pyramid weights",
}
FIG2_TARGET = os.environ.get("FIG2_TARGET", "tsyn")
FIG4C_TARGETS = ["test8", "tsyn"]  # fig4c.pdf is the first, fig4c_<name>.pdf the others
DRIFT_SIGMA = 0.0497  # mean sigma of log-uniform drift over [0.02, 0.1], report section 6
INK_THRESHOLD = 0.02  # Evaluator.ink_threshold
CACHE = EXP / "build" / "figcache"
# Pixel window shown for each target (same window on every panel of a figure); T-syn is small, so zoom
VIEW = {"tsyn": (32, 96), "test8": (0, 128)}

plt.rcParams.update({
    "font.size": 7, "axes.titlesize": 7, "axes.labelsize": 7, "xtick.labelsize": 6.5, "ytick.labelsize": 6.5,
    "legend.fontsize": 6.5, "font.family": "DejaVu Sans", "pdf.fonttype": 42,
    "axes.edgecolor": MUTED, "axes.labelcolor": INK2, "xtick.color": MUTED, "ytick.color": MUTED,
    "axes.linewidth": 0.6, "xtick.major.width": 0.6, "ytick.major.width": 0.6,
    "axes.spines.top": False, "axes.spines.right": False, "lines.linewidth": 1.2,
    "savefig.bbox": "tight", "savefig.pad_inches": 0.02,
})


# ------------------------------------------------------------------ data

def load_log(path):
    return np.genfromtxt(path, delimiter=",", names=True)


def runs(target, config):
    d = RESULTS / target / config
    return sorted(p for p in d.glob("seed_*") if (p / "meta.txt").exists())


def stack(target, config, col):
    return np.array([load_log(r / "log.csv")[col] for r in runs(target, config)])


def final_ref(target, config):
    return stack(target, config, "best_dice_ref")[:, -1]


def median_run(target, config):
    rs = runs(target, config)
    finals = np.array([load_log(r / "log.csv")["best_dice_ref"][-1] for r in rs])
    return rs[int(np.argsort(finals)[len(finals) // 2])]


def snap_gens(run):
    return sorted(int(m.group(1)) for p in run.glob("gen_*.txt") if (m := re.match(r"gen_(\d+)\.txt", p.name)))


def cached(kind, genome, size, suffix):
    CACHE.mkdir(parents=True, exist_ok=True)
    key = re.sub(r"[^A-Za-z0-9]+", "_", str(Path(genome).relative_to(EXP)))
    out = CACHE / f"{key}_{kind}{size}{suffix}"
    if not out.exists():
        runner("--mode", kind, "--genome", genome, "--size", size, "--out", out)
    return out


def points(genome, size=128):
    path = cached("points", genome, size, ".pts")
    layers = []
    for line in path.read_text().splitlines():
        v = np.array(line.split(), dtype=float).reshape(-1, 2)
        layers.append(np.vstack([v, v[:1]]))  # endShape(CLOSE)
    return layers


def render(genome, size=128):
    return grey(cached("render", genome, size, ".png"))


def grey(path):
    img = np.asarray(Image.open(path).convert("RGB"), dtype=float)
    return img[..., 2] / 255.0  # the channel Evaluator.getInk reads


def ink(g):
    return (1 - g) > INK_THRESHOLD


def score(target_png, genome):
    r = runner("--mode", "score", "--target", target_png, "--genome", genome, capture=True)
    rmse, dice_ref, dice_k1 = map(float, r.stdout.strip().splitlines()[-1].split(","))
    return rmse, dice_ref, dice_k1


# ------------------------------------------------------------------ drawing helpers

def save(fig, path):
    fig.savefig(path)
    if os.environ.get("PREVIEW"):  # PNG copies for a quick look, not for the report
        (EXP / "build" / "preview").mkdir(parents=True, exist_ok=True)
        fig.savefig(EXP / "build" / "preview" / (Path(path).stem + ".png"), dpi=600)


def bare(ax):
    ax.set_xticks([])
    ax.set_yticks([])
    for s in ax.spines.values():
        s.set_visible(True)
        s.set_color("#d4d3cf")
        s.set_linewidth(0.5)


def show_image(ax, g, view=None):
    ax.imshow(g, cmap="gray", vmin=0, vmax=1, interpolation="nearest")
    if view:
        set_view(ax, view)
    bare(ax)


def set_view(ax, view):
    ax.set_xlim(view[0] - 0.5, view[1] - 0.5)
    ax.set_ylim(view[1] - 0.5, view[0] - 0.5)


def show_genome(ax, genome, view, size=128, lw=0.25):
    # pixel centres sit at integer coordinates in imshow, so shift by -0.5 to line up with the rasters
    for layer in points(genome, size):
        ax.plot(layer[:, 0] + size / 2 - 0.5, layer[:, 1] + size / 2 - 0.5, color=INK, lw=lw,
                solid_joinstyle="round")
    set_view(ax, view)  # y points down, as in Processing
    ax.set_aspect("equal")
    bare(ax)


def overlay(ax, target_grey, cand_grey, view):
    t, c = ink(target_grey), ink(cand_grey)
    codes = np.zeros(t.shape, int)  # 0 TN
    codes[t & c] = 1
    codes[t & ~c] = 2
    codes[~t & c] = 3
    ax.imshow(codes, cmap=ListedColormap(["white", INK, RED, BLUE]), vmin=0, vmax=3, interpolation="nearest")
    set_view(ax, view)
    bare(ax)


def caption(ax, text):
    ax.set_xlabel(text, labelpad=2, color=INK2, fontsize=6.3, linespacing=1.15)


# ------------------------------------------------------------------ figures

def fig2(summary):
    tpng = TARGET_FILES[FIG2_TARGET]
    run = median_run(FIG2_TARGET, "baseline")
    attempt = run / "gen_025.txt"
    blank = score(tpng, "blank")
    att = score(tpng, attempt)
    summary.append(["fig2", FIG2_TARGET, "blank", *blank])
    summary.append(["fig2", FIG2_TARGET, f"baseline {run.name} gen 25", *att])

    self_rows = {r["target"]: r for r in csv.DictReader(open(TARGETS / "selfscore.csv"))}
    fig = plt.figure(figsize=(COL_W, 7.4 * CM))
    gs = fig.add_gridspec(2, 6, height_ratios=[1, 1.35], hspace=0.75, wspace=0.45)
    axes = [fig.add_subplot(gs[0, 2 * i:2 * i + 2]) for i in range(3)]
    view = VIEW[FIG2_TARGET]
    show_image(axes[0], grey(tpng), view)
    caption(axes[0], f"(a) target\n{TARGET_LABEL[FIG2_TARGET]}\n ")
    show_image(axes[1], np.ones((128, 128)), view)
    caption(axes[1], f"(b) blank\nRMSE {blank[0]:.3f}\nDice {blank[1]:.3f}")
    show_image(axes[2], render(attempt), view)
    caption(axes[2], f"(c) gen 25\nRMSE {att[0]:.3f}\nDice {att[1]:.3f}")

    # Pipeline: the same genome's target rendered at 128 vs at 2000 and resized, as the evaluator sees it
    t128, t2000 = grey(TARGETS / "target128_as_seen.png"), grey(TARGETS / "target2000_as_seen.png")
    y0, x0, s = crop_window(t128)
    for i, (img, key, name) in enumerate([(t128, "target128", "rendered at 128 px"),
                                          (t2000, "target2000", "2000 px, resized to 128")]):
        ax = fig.add_subplot(gs[1, 3 * i:3 * i + 3])
        show_image(ax, img[y0:y0 + s, x0:x0 + s])
        d = float(self_rows[key]["dice_ref"])
        caption(ax, f"({'de'[i]}) {name}\nself-score Dice {d:.3f}")
    save(fig, FIGURES / "fig2.pdf")


def crop_window(g, s=32):
    """The s x s window with the most ink, so the zoom shows strokes rather than background."""
    k = ink(g).astype(float)
    c = np.pad(k.cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    best, arg = -1, (0, 0)
    for y in range(0, g.shape[0] - s + 1, 4):
        for x in range(0, g.shape[1] - s + 1, 4):
            v = c[y + s, x + s] - c[y, x + s] - c[y + s, x] + c[y, x]
            # prefer windows that are not solid ink either: stroke edges are what differs
            v = min(v, s * s - v)
            if v > best:
                best, arg = v, (y, x)
    return arg[0], arg[1], s


def band(ax, x, data, color, label, ls="-"):
    q1, med, q3 = np.percentile(data, [25, 50, 75], axis=0)
    ax.fill_between(x, q1, q3, color=color, alpha=0.18, lw=0)
    ax.plot(x, med, color=color, ls=ls, label=label)
    return med


def fig4a():
    fig, ax = plt.subplots(figsize=(COL_W, 4.4 * CM))
    for t, c in (("tsyn", BLUE), ("test8", ORANGE)):
        d = stack(t, "baseline", "best_dice_ref")
        x = np.arange(d.shape[1])
        med = band(ax, x, d, c, TARGET_LABEL[t])
        ax.annotate(f"{TARGET_LABEL[t]}  {med[-1]:.3f}", (x[-1], med[-1]), xytext=(3, 0),
                    textcoords="offset points", va="center", color=INK2, fontsize=6.3)
    ax.set_xlabel("generation")
    ax.set_ylabel("best weighted Dice")
    ax.set_xlim(0, x[-1])
    ax.grid(axis="y", color="#e6e5e1", lw=0.5)
    ax.legend(frameon=False, loc="lower right", title=f"baseline, median + IQR, {d.shape[0]} seeds",
              title_fontsize=6.3)
    save(fig, FIGURES / "fig4a.pdf")


def fig4b():
    fig, axes = plt.subplots(1, 2, figsize=(COL_W, 4.2 * CM), sharey=True)
    for ax, t in zip(axes, ("tsyn", "test8")):
        for cfg, c, lab in (("baseline", BLUE, r"$\mu$ = 50"), ("ranking_no_trunc", ORANGE, r"$\mu$ = 100")):
            d = stack(t, cfg, "mean_sigma")
            band(ax, np.arange(d.shape[1]), d, c, lab)
        ax.axhline(DRIFT_SIGMA, color=INK2, ls=(0, (3, 2)), lw=0.8)
        ax.set_title(TARGET_LABEL[t], color=INK2, pad=2)
        ax.set_xlabel("generation")
        ax.set_xlim(0, d.shape[1] - 1)
        ax.grid(axis="y", color="#e6e5e1", lw=0.5)
    axes[0].set_ylabel(r"population mean $\sigma$")
    axes[1].text(0.97, 0.2, "dashed: no-selection\ndrift, 0.0497", transform=axes[1].transAxes,
                 ha="right", va="center", color=INK2, fontsize=6)
    axes[0].legend(frameon=False, loc="lower right")
    save(fig, FIGURES / "fig4b.pdf")


def fig4c(target, out, summary):
    run = median_run(target, "baseline")
    log = load_log(run / "log.csv")
    gens = snap_gens(run)
    tpng = TARGET_FILES[target]
    n = len(gens) + 2
    fig, axes = plt.subplots(1, n, figsize=(COL_W, COL_W / n + 0.75 * CM))
    view = VIEW[target]
    show_image(axes[0], grey(tpng), view)
    caption(axes[0], f"target\n{TARGET_LABEL[target]}")
    for ax, g in zip(axes[1:], gens):
        show_genome(ax, run / f"gen_{g:03d}.txt", view)
        caption(ax, f"gen {g}\n{log['best_dice_ref'][g]:.3f}")
    final = run / f"gen_{gens[-1]:03d}.txt"
    overlay(axes[-1], grey(tpng), render(final), view)
    caption(axes[-1], "overlay\n(final)")
    fig.subplots_adjust(wspace=0.08)
    save(fig, out)
    summary.append(["fig4c", target, f"baseline {run.name}", "", float(log["best_dice_ref"][-1]),
                    float(log["best_dice_k1"][-1])])


def table1(stats_rows):
    lines = [
        "% generated by experiments/make_figures.py -- final best_dice_ref (baseline weighted Dice),",
        "% median [IQR = Q3-Q1] over seeds; p: two-sided Mann-Whitney U against the baseline on the same target",
        r"\begin{tabular}{@{}lcccc@{}}",
        r"\toprule",
        r" & \multicolumn{2}{c}{T-syn} & \multicolumn{2}{c}{test8} \\",
        r"\cmidrule(lr){2-3}\cmidrule(l){4-5}",
        r"Configuration & Dice & $p$ & Dice & $p$ \\",
        r"\midrule",
    ]
    base = {t: final_ref(t, "baseline") for t in TARGET_FILES}
    for cfg in CONFIGS:
        cells = [CONFIG_LABEL[cfg]]
        for t in ("tsyn", "test8"):
            v = final_ref(t, cfg)
            q1, med, q3 = np.percentile(v, [25, 50, 75])
            cells.append(f"{med:.3f} [{q3 - q1:.3f}]")
            if cfg == "baseline":
                cells.append("--")
                p = float("nan")
            else:
                p = mannwhitneyu(v, base[t], alternative="two-sided").pvalue
                cells.append(fmt_p(p))
            stats_rows.append([cfg, t, len(v), med, q1, q3, v.min(), v.max(), p])
        lines.append(" & ".join(cells) + r" \\")
        if cfg == "baseline":
            lines.append(r"\addlinespace")
    lines += [r"\bottomrule", r"\end{tabular}"]
    (TABLES / "table1.tex").write_text("\n".join(lines) + "\n")


def fmt_p(p):
    if p < 0.001:
        return r"$<$0.001"
    return f"{p:.3f}" if p < 0.1 else f"{p:.2f}"


def main():
    FIGURES.mkdir(parents=True, exist_ok=True)
    TABLES.mkdir(parents=True, exist_ok=True)
    summary = []
    stats_rows = []
    table1(stats_rows)
    fig2(summary)
    fig4a()
    fig4b()
    for i, t in enumerate(FIG4C_TARGETS):
        fig4c(t, FIGURES / ("fig4c.pdf" if i == 0 else f"fig4c_{t}.pdf"), summary)

    with open(TABLES / "final_stats.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["config", "target", "n", "median", "q1", "q3", "min", "max", "p_vs_baseline"])
        w.writerows(stats_rows)
    # Pipeline check: self-scores and the single baseline run on each render of T-syn
    with open(TABLES / "pipeline_check.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["target_render", "self_score_dice_ref", "self_score_dice_k1", "baseline_run_final_dice_ref",
                    "final_genome_vs_128_target_dice_ref"])
        sr = {r["target"]: r for r in csv.DictReader(open(TARGETS / "selfscore.csv"))}
        for key, rdir in (("target128", RESULTS / "tsyn" / "baseline" / "seed_00"),
                          ("target2000", RESULTS / "tsyn2000" / "baseline" / "seed_00")):
            final = rdir / f"gen_{snap_gens(rdir)[-1]:03d}.txt"
            w.writerow([key, sr[key]["dice_ref"], sr[key]["dice_k1"], load_log(rdir / "log.csv")["best_dice_ref"][-1],
                        score(TARGET_FILES["tsyn"], final)[1]])
    with open(TABLES / "figure_scores.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["figure", "target", "what", "rmse", "dice_ref", "dice_k1"])
        w.writerows(summary)
    print("figures in", FIGURES, "tables in", TABLES)


if __name__ == "__main__":
    main()
