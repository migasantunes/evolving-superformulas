"""Run every configuration on both targets, one Java process per core.

Resumable: a run whose meta.txt already exists is skipped. Environment overrides:
SEEDS (default 10), GENS (default 300), JOBS (default: number of logical cores).
On a Linux box without a display nothing extra is needed (the runner never opens a window);
wrap in `xvfb-run -a` only if your Java/AWT build insists on one.
"""
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

from common import CONFIGS, GENS, RESULTS, SEEDS, TARGET_FILES, TARGETS, TSYN_SEED, runner


def jobs():
    out = []
    for target, path in TARGET_FILES.items():
        for config, args in CONFIGS.items():
            for seed in range(SEEDS):
                out.append((RESULTS / target / config / f"seed_{seed:02d}", path, seed, args))
    # Pipeline check: one baseline run on the 2000px render of T-syn
    out.append((RESULTS / "tsyn2000" / "baseline" / "seed_00", TARGETS / "tsyn_2000.png", 0, []))
    return out


def run(job):
    out, target, seed, args = job
    if (out / "meta.txt").exists():
        return f"skip {out}"
    r = runner("--target", target, "--seed", seed, "--gens", GENS, "--out", out, *args, check=False, capture=True)
    if r.returncode != 0:
        return f"FAILED {out}\n{r.stderr}"
    return r.stdout.strip()


def main():
    assert TSYN_SEED >= SEEDS, "TSYN_SEED collides with the run seeds (see common.py)"
    todo = jobs()
    n = int(os.environ.get("JOBS", os.cpu_count() or 1))
    print(f"{len(todo)} runs, {SEEDS} seeds x {GENS} gens, {n} parallel", flush=True)
    t0 = time.time()
    failed = 0
    with ThreadPoolExecutor(max_workers=n) as pool:
        futures = [pool.submit(run, j) for j in todo]
        for i, f in enumerate(as_completed(futures), 1):
            msg = f.result()
            failed += msg.startswith("FAILED")
            print(f"[{i}/{len(todo)} {time.time() - t0:.0f}s] {msg}", flush=True)
    print(f"total wall time {time.time() - t0:.0f}s, {failed} failed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
