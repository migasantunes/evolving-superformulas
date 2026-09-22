# Experiments for the report

Everything here is opt-in: the step 10 and step 11 sketches behave exactly as before when run from the
Processing IDE. Outputs go to `report/figures/` (PDF) and `report/tables/`.

## Requirements

- Processing 4 (tested with 4.5.6). Its bundled JDK, `core` jar and PDF library are used.
  Set `PROCESSING_HOME` if it is not in the default place
  (`C:/Program Files/Processing`, `/Applications/Processing.app/Contents`, `/opt/processing`).
- Python 3 with `numpy`, `scipy`, `matplotlib`, `pillow` (on this machine: `C:/Python312/python`).

No display is needed: the runner never opens a window (offscreen JAVA2D + PDF only, `java.awt.headless`),
so `xvfb-run` is unnecessary even on a headless Linux box.

## Rerunning

```sh
cd experiments
python build.py            # Processing CLI preprocesses step 10 -> Java, then compiles runner/*.java
python make_targets.py     # T-syn genome + renders, pipeline self-scores
python run_experiments.py  # 121 runs, one process per core; resumable (finished runs are skipped)
python make_figures.py     # fig2, fig4a/b/c, table1.tex and the CSV summaries
python make_fig3.py [step_11_interactive_evolution/sessions/<timestamp>]   # fig3 from a logged session
```

`run_experiments.py` reads `SEEDS` (default 10), `GENS` (default 300) and `JOBS` (default: logical cores)
from the environment, e.g. `SEEDS=5 GENS=200 python run_experiments.py`. Delete `results/` first
when changing them, otherwise finished runs are kept.

Timing on the machine used (20 logical cores): one 300-generation run takes 253 s alone and 340–480 s
when 20 run at once (hyperthreading), so the full 121-run design takes about 42 min (measured: 2492 s).

`PREVIEW=1 python make_figures.py` also writes 600-dpi PNG copies to `build/preview/` for a quick look.
T-syn is small in its canvas, so its panels (fig2 top row, `fig4c_tsyn`) show the central 64 px
(`VIEW` in `make_figures.py`); the same window is used on every panel of a figure.

## How the runner reuses the sketch

`build.py` runs `Processing cli --build` on `step_10_automatic_evolution/`, which produces
`step_10_automatic_evolution.java` exactly as the IDE would. `runner/Runner.java` **extends** that
class, so `Population`, `Evaluator` and `SuperFormula` are the sketch's own code and every global keeps
the sketch's value unless an argument overrides it. The ablations are either global overrides or one
small subclass each:

| config (`common.py`) | change from the baseline | how |
|---|---|---|
| `baseline` | none (linear ranking sp=1.8, mu=50, self-adaptive sigma in [0.02, 0.1], weighted Dice) | – |
| `raw_roulette` | fitness-proportional roulette on raw fitness, mu=100 | `ExpPopulation` overrides the wheel |
| `ranking_no_trunc` | linear ranking over the whole population (mu=100) | `mu` |
| `fixed_sigma` | sigma fixed at 0.05, no self-adaptation | `sigma_min = sigma_max = 0.05` |
| `rmse` | fitness = 1 − RMSE of grey levels at 128px | `RmseEvaluator` |
| `equal_weights` | pyramid weights {1, 1, 1, 1} | `level_weights` |

Every run seeds Processing's RNG with `randomSeed(seed)` just before `initialize()`, so seed *s* gives
the same initial population in every config.

### Per-run output (`results/<target>/<config>/seed_XX/`)

- `log.csv`, one row per generation: `gen, best_fitness` (the config's own fitness), `best_dice_ref`
  (the **baseline** weighted Dice of that same best individual, so configs are comparable),
  `best_dice_k1` (unweighted Dice at k=1), `mean_fitness`, `mean_sigma` (over individuals and genes).
- `gen_000/025/100/300.{png,pdf,txt}`: best individual as PNG (512px), PDF (same drawing as
  `export()`) and genome (+ sigmas and fitness).
- `meta.txt`: effective parameters and runtime.

`results/tsyn2000/baseline/seed_00` is the pipeline-check run on the 2000px render of T-syn.

### Targets (`targets/`)

- `tsyn.txt`: random 5-layer genome, `randomSeed(1007)` then `new SuperFormula()`. That is exactly
  individual 0 of a run seeded 1007, so the T-syn seed must stay outside the run seeds (asserted).
- `tsyn_128.png`: its render at the evaluation size (what step 11 exports now);
  `tsyn_2000.png`: at 2000px (what step 11 used to export).
- `selfscore.csv`: the genome scored against each render;
  `target*_as_seen.png`: the renders after `Evaluator`'s own resize to 128.
- test8 is `step_10_automatic_evolution/data/glyphs_1693591751539/test8.png`, unchanged.

### Other runner modes

`java -cp <classpath> Runner --mode <m> ...` with `m` in `make_target`, `selfscore`,
`score` (RMSE / weighted Dice / k=1 Dice of a genome or `blank` against a target), `points` (polyline,
used for the vector drawings in the figures) and `render` (PNG at a given size). See the header of
`runner/Runner.java`.

## Figures and tables

| file | content |
|---|---|
| `fig2.pdf` | T-syn target / blank canvas / baseline gen-25 attempt (RMSE and weighted Dice under each); zoomed crops of T-syn rendered at 128 vs 2000→128 with self-scores |
| `fig3.pdf` | top-rated individual of up to 8 generations of a step 11 session (from its PDFs) |
| `fig4a.pdf` | baseline convergence, best weighted Dice, median + IQR over seeds, both targets |
| `fig4b.pdf` | population mean sigma, mu=50 vs mu=100, dashed line at 0.0497 |
| `fig4c.pdf` | test8 strip: target, best at gen 0/25/100/300 (median-seed baseline run), overlay of the final best (TP black, FN red, FP blue); `fig4c_tsyn.pdf` is the same for T-syn |
| `table1.tex` | final `best_dice_ref`, median [IQR] per target, two-sided Mann-Whitney U p vs baseline (booktabs; `\input` it inside a `table`) |
| `final_stats.csv` | the numbers behind table 1, plus Q1/Q3/min/max |
| `pipeline_check.csv` | T-syn self-scores at 128 vs 2000→128, and the final score of one baseline run on each |
| `figure_scores.csv` | the RMSE / Dice values printed in fig2 and fig4c |

## Step 11 session logging

Set `log_session = true` at the top of `step_11_interactive_evolution.pde`. On every evolve, before
breeding, the top-rated individual is exported with the sketch's own `export()` to
`sessions/<timestamp>/gen_XX.{png,pdf,txt}`, and a row `gen, ratings, genomes` is appended to
`sessions/<timestamp>/session.csv` (ratings `;`-separated in sorted order, genomes `;`-separated with
genes space-separated, same order). `r` (reset) starts a new session folder.

Note: the repository `.gitignore` ignores `*.pdf`, so the generated figures are not committed unless
you add an exception such as `!report/figures/*.pdf`.
