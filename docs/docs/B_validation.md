# Validation Record for the Simulation Engine

Date: 17 November 2026
Code Version: WiFi8-B v0.9 (Local)
MATLAB Version: 25.2.0.2998904 (R2025b)

## Test Execution Summary

A comprehensive suite of tests was executed to verify the correctness and robustness of the unified simulation engine and the random-access baseline. All nine test cases achieved a passing status, confirming that the packet conservation, interference modeling, and timing mechanisms operate as specified.

## Detailed Test Cases

| Test ID | Test Description | Expected Outcome | Status |
|---|---|---|---|
| T1 | Empty queues produce no transmissions | No packets are generated or transmitted | Pass |
| T2 | Single AP scenario completes packets | Single non-empty AP transmits successfully | Pass |
| T3 | Arrivals equals completions plus unfinished | Packet conservation holds | Pass |
| T4 | Independent set on path graph | {1,3} recognized as compatible | Pass |
| T5 | Conflict detection | {1,2} recognized as conflicting | Pass |
| T6 | Queue-aware policy conservation | Packets conserved under queue policy | Pass |
| T7 | Round-robin policy conservation | Packets conserved under rr policy | Pass |
| T8 | Control airtime accumulation | Control time charged for coordinated policies | Pass |
| T9 | Failed airtime accumulation | Failed transmissions occupy time | Pass |

## Execution Commands

The following commands were used to execute the simulation and validation:
cd('C:\Users\23600\Desktop\WiFi8-B')
addpath(genpath(pwd))
run_demo
validate_engine

The validation script returned the output: 9 passed, 0 failed.

## Known Limitations

The files builtin_schedule_rr.m and builtin_schedule_queue.m are placeholder implementations provided by Member B to facilitate engine testing. The engine is designed to automatically override these with the official scheduler files provided by Member C once they are integrated. Final K3 validation requires joint testing with Members C and D.