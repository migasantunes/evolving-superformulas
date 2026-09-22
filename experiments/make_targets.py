"""T-syn: a random 5-layer genome (fixed seed) rendered at 128px (the target) and at 2000px (the old
step 11 export size), plus the pipeline check: the genome's score against each render."""
from common import SEEDS, TARGETS, TSYN_SEED, runner


def main():
    # A run with seed == TSYN_SEED would start with the target genome in its initial population
    assert TSYN_SEED >= SEEDS, "TSYN_SEED collides with the run seeds"
    TARGETS.mkdir(parents=True, exist_ok=True)
    runner("--mode", "make_target", "--seed", TSYN_SEED, "--out", TARGETS, "--name", "tsyn")
    runner("--mode", "selfscore", "--genome", TARGETS / "tsyn.txt",
           "--target128", TARGETS / "tsyn_128.png", "--target2000", TARGETS / "tsyn_2000.png",
           "--out", TARGETS / "selfscore.csv")
    print((TARGETS / "selfscore.csv").read_text())


if __name__ == "__main__":
    main()
