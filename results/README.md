# Recorded simulation results

Simulation batch directories contain run-level metrics (`run_metrics.csv`),
saved configurations (`batch_config.mat`), and, where applicable,
scenario manifests. Analysis subdirectories contain derived summaries
and comparisons.

## Recorded batches

| Batch directory | Experiment |
| --- | --- |
| `D_load_20261117_233652` | Balanced offered loads |
| `D_imbalance_20261117_235833` | Traffic imbalance |
| `D_hotspot_20261118_003213` | Hotspot location |
| `D_graph_20261118_000844` | Conflict graphs, coordinated cap two |
| `D_noedge_cap3_20261118_002317` | No-conflict coordinated cap three |
| `D_overhead_20261118_003903` | Coarse overhead sweep |
| `D_overhead_refine_20261118_010109` | Refined overhead sweep |
| `D_overhead_long_20261118_012128` | Long-horizon overhead sweep |

## Data availability

The balanced-load batch contains 180 original `load_*.mat` run files:
three loads, 20 replications, and three policies.
These files provide the packet-level samples required by the CDF analysis.

Full packet-level MAT traces for the other batches are not bundled.
Their supplied CSV metrics and configurations support the aggregate
analyses described in the main README.

A summary CSV cannot replace packet-level samples when reconstructing
a delay distribution.

## Output handling

New simulations and most analyses create timestamped directories.
Preserve the recorded batches used by the report.

The load analysis updates `load_summary.csv` and its diagnostic figures
inside the recorded load batch. Other analyses print their output locations.

Mean per-run P95 and pooled packet P95 are different statistics.
Unfinished packets are excluded from completion-window delay samples
and must be considered separately when interpreting congested cases.

See the [main README](../README.md) for reproduction commands,
input-folder selection, and report figure and table mappings.
