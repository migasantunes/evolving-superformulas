"""fig3: the top-rated individual of up to 8 generations of a logged step 11 session, from its PDFs.

usage: python make_fig3.py [session_dir]
Default: the most recent folder in step_11_interactive_evolution/sessions/. Sessions are recorded by
setting log_session = true at the top of step_11_interactive_evolution.pde.
When there are more than 8 generations, 8 evenly spaced ones are taken (first and last included).
"""
import csv
import subprocess
import sys
from pathlib import Path

import numpy as np

from common import FIGURES, STEP11, classpath, java_bin

MAX_GENS = 8
WIDTH_PT = 8.5 / 2.54 * 72  # single column


def main():
    if len(sys.argv) > 1:
        session = Path(sys.argv[1])
    else:
        sessions = sorted(p for p in (STEP11 / "sessions").iterdir() if p.is_dir())
        if not sessions:
            sys.exit("no sessions found; set log_session = true in step 11 and rate a few generations")
        session = sessions[-1]
    with open(session / "session.csv", newline="") as f:
        rows = {int(r["gen"]): r for r in csv.DictReader(f)}
    gens = sorted(g for g in rows if (session / f"gen_{g:02d}.pdf").exists())
    if len(gens) > MAX_GENS:
        idx = np.unique(np.round(np.linspace(0, len(gens) - 1, MAX_GENS)).astype(int))
        gens = [gens[i] for i in idx]
    args = []
    for g in gens:
        top = rows[g]["ratings"].split(";")[0]
        args += [str(session / f"gen_{g:02d}.pdf"), f"gen {g}  ({top}/10)"]
    FIGURES.mkdir(parents=True, exist_ok=True)
    out = FIGURES / "fig3.pdf"
    cols = min(len(gens), 4)
    subprocess.run([java_bin(), "-cp", classpath(), "PdfStrip", str(out), f"{WIDTH_PT:.2f}", str(cols), *args],
                   check=True)
    print(f"wrote {out} from {session.name}: generations {gens}")


if __name__ == "__main__":
    main()
