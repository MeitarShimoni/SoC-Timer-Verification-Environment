# SystemVerilog Verification Project: Timer Peripheral IP

## 📌 Overview
This project involves the design and implementation of a comprehensive **SystemVerilog (SV)** verification environment for a **Timer Peripheral IP**. The project demonstrates a **Layered Testbench Architecture** built from scratch using **Object-Oriented Programming (OOP)** principles, mimicking UVM methodologies without using the library itself.

The environment validates a slave peripheral that communicates via a **REQ/GNT handshake protocol**, featuring programmable countdowns, auto-reload capabilities, and status monitoring.

## 🛠️ Verification Environment Architecture
The testbench is structured using a modular, OOP-based approach to ensure reusability and scalability:

*   **Transaction Layer:** Polymorphic transaction classes (`bus_trans`, `read_trans`, `write_trans`) with constraints for **Randomization**.
*   **Driver:** Drives signals to the DUT via a `virtual interface`, handling the request-grant handshake timing.
*   **Monitor:** Passively observes bus activity, captures transactions, and broadcasts them to the scoreboard via mailboxes.
*   **Scoreboard:** Implements a **Golden Reference Model** to predict expected DUT behavior and compares it against actual monitor results.
*   **Coverage Collector:** Tracks functional coverage metrics using `covergroups`, bins, and cross-coverage.
*   **Interface:** Defines signal direction (Modports) and timing (Clocking Blocks).

## 🧪 Key Features Verified
The verification plan focused on validating the design specification [Source: Design Spec]:
1.  **Bus Protocol:** Validating the proprietary Request/Grant handshake (Slave must assert GNT within ≤3 cycles).
2.  **Register Map:** Correct read/write access to `CONTROL` (0x00), `LOAD` (0x04), and `STATUS` (0x08) registers.
3.  **Core Logic:**
    *   Countdown timing accuracy.
    *   **Auto-Reload** vs. **One-Shot** modes.
    *   **Zero Handling** (LOAD=0 treated as 1).
    *   **Sticky Status Flags** (EXPIRED bit must be manually cleared).

## 🔍 Verification Strategy
The project utilizes **Constrained Random Verification (CRV)** and **Coverage Driven Verification (CDV)**.

### 1. Functional Coverage
Implemented in `coverage_collector_timer.sv`:
*   **Address Coverage:** Ensuring all registers are accessed.
*   **Data Bins:** Corner cases (0, 1), Low values, and Max ranges.
*   **Cross Coverage:** Validating interactions, such as `LOAD` value × `Zero` handling and `Start` × `Reload` modes.

### 2. Assertions (SVA)
Implemented in `timer_sva.sv`:
*   `R1_GNT_ASSERT_3_CYCLES`: Checks that GNT is asserted within 1-3 cycles after REQ.
*   `R2_REQ_WAIT_2_GNT`: Ensures REQ remains stable until GNT is received.
*   `reset_clears_gnt_p`: Verifies asynchronous reset behavior.

### 3. Test Scenarios
Defined in `testbench_top.sv`:
*   **Smoke Test:** Basic sanity checks.
*   **Load Zero Test:** Verifying the specific edge case where 0 input is converted to 1.
*   **Auto-Reload Test:** Verifying continuous counting cycles.
*   **Stress Test:** Randomized traffic with maximum load values.

## 🐛 Bugs Detected
The verification environment successfully identified several injected bugs in the RTL design (`timer_periph.sv`):
1.  **Protocol Violation:** The DUT occasionally took 4 cycles to assert GNT (Spec requires ≤3).
2.  **Logic Error:** Mis-decoded `RELOAD_EN` bit (mapped to `CLR_STATUS` bit instead).
3.  **Edge Case Failure:** Loading `0` was not coerced to `1` as required by the spec.

## 📂 File Structure
```text
├── rtl/
│   ├── timer_periph.sv        # Design Under Test (Buggy version)
│   └── design_params_pkg.sv   # Design parameters
├── verif/
│   ├── bus_if.sv              # Interface with Clocking Blocks & Modports
│   ├── bus_trans.sv           # Transaction Classes
│   ├── Driver.sv              # Bus Driver
│   ├── Monitor.sv             # Bus Monitor
│   ├── Scoreboard.sv          # Reference Model & Checker
│   ├── coverage_collector.sv  # Functional Coverage
│   ├── timer_sva.sv           # SystemVerilog Assertions
│   └── testbench_top.sv       # Top-Level TB & Test Cases
└── README.md
