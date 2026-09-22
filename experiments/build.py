"""Preprocess the step 10 sketch with Processing's own CLI and compile Runner.java against it.

The sketch is not copied or edited: Processing turns it into step_10_automatic_evolution.java exactly as
the IDE would, and Runner extends that class.
"""
import platform
import shutil
import subprocess

from common import BUILD, EXP, STEP10, classpath, java_bin, processing_home


def processing_cli():
    home = processing_home()
    for name in ("Processing.exe", "Processing", "bin/Processing", "MacOS/Processing", "processing-java"):
        if (home / name).exists():
            return str(home / name)
    raise FileNotFoundError(f"Processing executable not found in {home}; set PROCESSING_HOME")


def main():
    sketch_out = BUILD / "sketch"
    classes = BUILD / "classes"
    shutil.rmtree(BUILD, ignore_errors=True)
    classes.mkdir(parents=True)
    exe = processing_cli()
    cmd = [exe, "cli"] if not exe.endswith("processing-java") else [exe]
    cmd += [f"--sketch={STEP10}", f"--output={sketch_out}", "--force", "--build"]
    subprocess.run(cmd, check=True)
    src = sketch_out / "source" / "step_10_automatic_evolution.java"
    subprocess.run([java_bin("javac"), "-nowarn", "-encoding", "UTF-8", "-cp", classpath(), "-d", str(classes),
                    str(src), str(EXP / "runner" / "Runner.java"), str(EXP / "runner" / "PdfStrip.java")], check=True)
    print("built", classes, "on", platform.system())


if __name__ == "__main__":
    main()
