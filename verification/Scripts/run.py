import subprocess
import shutil
import glob
import os
import argparse
import sys

# === CONFIG ===
TB   = "testbench_top"      # top-level module name
SNAP = f"{TB}_opt"          # must match elaborate.do

def run_command(command, step_name):
    """Runs a shell command and exits if it fails."""
    print(f"\n--- INFO: Starting Step: {step_name} ---")
    print(f"Executing: {command}")
    
    return_code = subprocess.call(command, shell=True)
    
    if return_code != 0:
        print(f"\n--- ERROR: Step '{step_name}' failed with code {return_code} ---")
        sys.exit(1) # Exit the script with an error
    
    print(f"--- INFO: Step '{step_name}' finished OK ---")

def cleanup():
    print("INFO: Cleaning up previous run files...")
    # Clean directories
    for d in ["work", SNAP]:
        shutil.rmtree(d, ignore_errors=True)

    # Clean files
    for pattern in ["*.log", "*.wlf", "transcript", "*.ucdb", "covdb*"]:
        for f in glob.glob(pattern):
            try:
                os.remove(f)
            except OSError:
                pass
    print("INFO: Cleanup completed.")

# --- Main script execution ---
if __name__ == "__main__":
    
    try:
        # 1. Define and Parse Arguments
        parser = argparse.ArgumentParser(description="Run QuestaSim simulation")
        
        parser.add_argument('--gui', action='store_true', help="Run simulation in GUI mode for debugging.")
        parser.add_argument('--seed', type=int, default=1, help="Set the random number seed for simulation.")
        parser.add_argument('--test', type=str, default='test', help="Name of the test. Used for log/wlf filenames.")

        args = parser.parse_args()

        # 2. Clean up
        cleanup()

        # 3. Run Compile and Elaborate
        run_command('vsim -c -do "do compile.do"', "Compile")
        run_command('vsim -c -do "do elaborate.do"', "Elaborate")

        # 4. Build the Simulate Command
        
        log_file = f"{args.test}_{args.seed}.log"
        wlf_file = f"{args.test}_{args.seed}.wlf"
        

        cmd = f"vsim -coverage -L work -voptargs=+acc -sv_seed {args.seed} {SNAP} "

        if args.gui:
            # GUI Mode
            print("INFO: GUI mode detected. Opening GUI...")
            cmd += " -gui" 
            
            tcl_cmds = [
                f"add wave -r sim:/{TB}/DUT/*",
                "onfinish stop",
                "run -all",
                "coverage save covdb.ucdb"
            ]
            
            cmd += f' -do "{"; ".join(tcl_cmds)}"'
            
        else:
            # Batch Mode
            print("INFO: Batch mode detected. Running in Batch...")
            cmd += " -c" 
            cmd += f" -logfile {log_file} -wlf {wlf_file}"
            
            tcl_cmds = [
                "run -all",
                "coverage save covdb.ucdb",
                "coverage report -file coverage_summary.txt -byfile -detail -noannot",
                "quit -f"
            ]
            
            cmd += f' -do "{"; ".join(tcl_cmds)}"'

        # Run the final command
        run_command(cmd, "Simulate")
        
        if not args.gui:
            print(f"\n--- INFO: All steps completed. Check {log_file} and coverage_summary.txt ---")

    except Exception as e:
        print(f"--- ERROR: An unexpected error occurred: {e} ---")
        sys.exit(1)
