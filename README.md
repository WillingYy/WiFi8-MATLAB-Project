# Wi-Fi 8-Inspired Multi-AP Coordination

**EEEN3008J Wireless Communications | Group 24 | 2026/27**

Members: Li Ziqi, Yao Minghua, Yuan Yi, Lian Yuhang, and Tai Junqi.

## Overview

This MATLAB project asks whether coordinating neighbouring access points reduces
95th-percentile packet delay enough to justify the control overhead. It compares
simplified random access, coordinated round-robin (RR), and queue-aware scheduling
(QA) for three FIFO queues connected by a conflict graph.

This is a Wi-Fi 8-inspired abstraction, not a standards-compliant IEEE 802.11bn
or complete DCF/CSMA/CA implementation.

## Environment and quick start

Reproduction checks were performed on macOS using MATLAB R2026b Update 1
(`26.2.0.3433840`) on 19 November 2026. The project is designed for base MATLAB.
Quantiles and bootstrap calculations use project code and base MATLAB functions.

Download and extract the repository, then set MATLAB's Current Folder to the
repository root, where `setup_project.m` is located. Run:

```matlab
setup_project
validate_engine
test_cb_integration
run_demo
```

`setup_project` adds the required directories and sets the working folder to the
repository root. The official schedulers are `src/schedule_rr.m` and
`src/schedule_queue.m`.

Expected single-run demonstration results:

| Policy | Completed-packet P95 | Goodput (bits/time unit) | End-of-run unfinished packets |
| --- | ---: | ---: | ---: |
| Random access | 420.9761 | 6946.6667 | 176 |
| RR | 5.1157 | 8920.0000 | 1 |
| QA | 4.5334 | 8920.0000 | 1 |

The demonstration uses a total arrival rate of 0.75, horizon 1000, warmup 100,
arrival seed 101, and access seed 202. Its results are integration checks;
the main report experiments use different configurations.

## Reproduce results from saved data

Run `setup_project` first. These analysis scripts read saved results; they do not
rerun the simulation. For scripts that open a folder-selection dialog, select the
batch folder listed below, not an `analysis_...` subfolder. All batch folders
listed here are under `results/`.

| Analysis command | Saved input batch | Report content |
| --- | --- | --- |
| `analyse_d_load` | `D_load_20261117_233652` | Load summaries, Table 6.1 mean run P95 |
| `analyse_d_delay_cdf` | `D_load_20261117_233652` | Figure 6.1 and Table 6.1 pooled quantiles |
| `analyse_d_imbalance` | `D_imbalance_20261117_235833` | Tables 6.2 and 6.3 |
| `analyse_d_hotspot` | `D_hotspot_20261118_003213` | Section 6.2 hotspot-location comparison |
| `analyse_d_graph` | `D_graph_20261118_000844` | Table 6.4 |
| `analyse_d_noedge_cap` | First `D_graph_20261118_000844`, then `D_noedge_cap3_20261118_002317` | Section 6.3 concurrency-cap comparison |
| `analyse_d_overhead` | `D_overhead_long_20261118_012128` | Table 6.5 and long-horizon overhead analysis |
| `compare_d_overhead_duration` | `D_overhead_refine_20261118_010109` and `D_overhead_long_20261118_012128` | Figure 6.2 and Table 6.6 |

For example:

```matlab
analyse_d_delay_cdf
compare_d_overhead_duration
analyse_d_overhead
% For the last command, select results/D_overhead_long_20261118_012128.
```

The balanced-load batch contains 180 per-run MAT files: three loads, 20
replications, and three policies. The CDF script checks these samples against
`run_metrics.csv`. Other batches include run-level CSV metrics, configurations,
and manifests; their full packet-level MAT traces are not bundled.
The supplied metrics support the listed aggregate analyses.

Existing submitted figures are in `figures/`. Re-running analyses creates
timestamped output directories or updates the load-summary outputs.
CDF and duration-comparison outputs are saved under `results/`; interactive
analyses save outputs inside the selected batch folder. The scripts print their
output locations.

## Generate new simulation batches

After `setup_project`, run the required experiment script:

| Command | Experiment |
| --- | --- |
| `run_d_batch` | Balanced offered-load sweep |
| `run_d_imbalance` | Traffic-imbalance sweep |
| `run_d_hotspot` | Hotspot-location comparison |
| `run_d_graph` | Conflict-graph sweep |
| `run_d_noedge_cap3` | No-conflict concurrency-cap check |
| `run_d_overhead` | Coarse control-cost sweep |
| `run_d_overhead_refine` | Refined control-cost sweep |
| `run_d_overhead_long` | Longer-horizon control-cost sweep |

New simulations create timestamped batch directories in `results/`.
To analyse new runs, select their new directories in interactive analyses.
`analyse_d_load`, `analyse_d_delay_cdf`, and
`compare_d_overhead_duration` reference the recorded batches explicitly;
update their input batch paths before using them for newly generated batches.

The main sweeps use 20 replications, arrival seeds 10001–10020, and access seeds
20001–20020. Standard horizons/warmups are 10000/1000; the long overhead
experiment uses 20000/2000. All policies share arrival traces within each
configuration and replication.

## Repository layout

| Path | Purpose |
| --- | --- |
| `setup_project.m` | Configure MATLAB paths and working folder |
| `run_demo.m` | Run the three-policy integration demonstration |
| `validate_engine.m` | Nine engine checks |
| `config/default_config.m` | Demonstration defaults |
| `src/engine/` | Shared engine and supporting functions |
| `src/schedule_rr.m`, `src/schedule_queue.m` | Official coordinated schedulers |
| `experiments/` | Experiment runners, integration tests, and analyses |
| `results/` | Recorded data, configurations, summaries, and analysis outputs |
| `figures/` | Previously exported experiment figures |
| `docs/` | Contribution documentation and validation records |

## Interpretation and verification

Time is normalized with Tdata = 1; it is not calibrated to milliseconds.
Offered load is the total arrival rate across all three APs.
The main delay statistic is the mean of 20 per-run P95 estimates.
Pooled quantiles combine completed-packet samples and are reported separately.

Delay samples are selected by recorded completion time within
[Twarmup, Tsim]. Unfinished packets do not enter the delay distribution.
Read delay together with goodput, unfinished counts, and backlog growth.
The model has infinite buffers, fixed payload duration, idealized queue visibility,
and an aggregate control interval. Endpoint-crossing service is recorded at the
simulation endpoint; control intervals crossing warmup are omitted from airtime
accounting. The report discusses these limitations.

Reproduction checks on the environment above confirmed:

- Engine validation: 9 passed, 0 failed.
- Scheduler and engine integration checks passed.
- Demonstration metrics matched the submitted integration log.
- All 180 balanced-load MAT results matched the run-level CSV metrics.
- Recomputed CDF, duration-comparison, and overhead-crossing values matched
  Tables 6.1, 6.6, and 6.5, respectively.

These checks used saved experiment data for the formal analyses.
The full batch simulations were not rerun during this packaging check.
