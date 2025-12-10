import subprocess, shutil, glob, os

# === CONFIG ===
TB   = "testbench_top"          # top-level module name
SNAP = f"{TB}_opt"              # must match elaborate.do

def cleanup():
    print("INFO: Cleaning up previous run files...")
    for d in ["work", SNAP]:
        shutil.rmtree(d, ignore_errors=True)

    for pattern in ["*.log", "*.wlf", "transcript", "*.ucdb", "covdb*"]:
        for f in glob.glob(pattern):
            try:
                os.remove(f)
            except OSError:
                pass
    print("INFO: Cleanup completed.")

def run_step(cmd, name):
    print(f"\n--- INFO: Starting Step '{name}' ---")
    rc = subprocess.call(cmd, shell=True)
    if rc != 0:
        raise SystemExit(f"ERROR: Step '{name}' failed with code {rc}")
    print(f"--- INFO: Step '{name}' finished OK ---")

if __name__ == "__main__":
    # make sure you're running this from verification/scripts
    print("INFO: CWD =", os.getcwd())

    cleanup()

    # 1) Compile
    run_step('vsim -c -do "do compile.do"', "Compile")

    # 2) Elaborate
    run_step('vsim -c -do "do elaborate.do"', "Elaborate")

    # 3) Open GUI and simulate with coverage
    print("\n--- INFO: Opening GUI simulation ---")
    gui_cmd = (
        'vsim -gui -L work -do '
        f'"vsim -coverage {SNAP}; '                 # <<< -coverage here
        f'add wave -r sim:/{TB}/DUT/*; '
        'onfinish stop; '
        'run -all; '
        # 'coverage save covdb.ucdb; '               # optional: save coverage DB
        '"'
    )
    subprocess.call(gui_cmd, shell=True)
