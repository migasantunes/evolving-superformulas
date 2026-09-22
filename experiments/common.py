"""Paths and helpers shared by the experiment scripts."""
import os
import platform
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXP = ROOT / "experiments"
BUILD = EXP / "build"
RESULTS = EXP / "results"
TARGETS = EXP / "targets"
FIGURES = ROOT / "report" / "figures"
TABLES = ROOT / "report" / "tables"
STEP10 = ROOT / "step_10_automatic_evolution"
STEP11 = ROOT / "step_11_interactive_evolution"
TEST8 = STEP10 / "data" / "glyphs_1693591751539" / "test8.png"

SEEDS = int(os.environ.get("SEEDS", 10))
GENS = int(os.environ.get("GENS", 300))
# Fixed seed of the synthetic target genome. make_target does randomSeed(TSYN_SEED); new SuperFormula(),
# which is exactly individual 0 of a run seeded with TSYN_SEED, so it must lie outside the run seeds.
TSYN_SEED = 1007

# One change from the baseline each. mu=100 is the whole population, i.e. no truncation.
CONFIGS = {
    "baseline": [],
    "raw_roulette": ["--selection", "raw", "--mu", "100"],
    "ranking_no_trunc": ["--mu", "100"],
    "fixed_sigma": ["--sigma_fixed", "0.05"],
    "rmse": ["--fitness", "rmse"],
    "equal_weights": ["--weights", "equal"],
}
TARGET_FILES = {
    "tsyn": TARGETS / "tsyn_128.png",
    "test8": TEST8,
}


def processing_home() -> Path:
    if "PROCESSING_HOME" in os.environ:
        return Path(os.environ["PROCESSING_HOME"])
    if platform.system() == "Windows":
        return Path("C:/Program Files/Processing")
    if platform.system() == "Darwin":
        return Path("/Applications/Processing.app/Contents")
    return Path("/opt/processing")


def resources() -> Path:
    home = processing_home()
    for cand in (home / "app" / "resources", home / "lib" / "app" / "resources", home / "app", home):
        if (cand / "core" / "library").exists():
            return cand
    raise FileNotFoundError(f"Processing resources not found under {home}; set PROCESSING_HOME")


def java_bin(tool: str = "java") -> str:
    exe = tool + (".exe" if platform.system() == "Windows" else "")
    bundled = resources() / "jdk" / "bin" / exe
    return str(bundled) if bundled.exists() else tool


def classpath() -> str:
    res = resources()
    jars = [BUILD / "classes"]
    jars += sorted((res / "core" / "library").glob("core-*.jar"))
    jars += sorted((res / "modes" / "java" / "libraries" / "pdf" / "library").glob("*.jar"))
    return os.pathsep.join(str(j) for j in jars)


def runner(*args, check=True, capture=False):
    cmd = [java_bin(), "-Djava.awt.headless=true", "-Xmx512m", "-XX:+UseSerialGC", "-XX:ActiveProcessorCount=1", "-cp", classpath(), "Runner", *map(str, args)]
    return subprocess.run(cmd, check=check, capture_output=capture, text=True)
