# Exported experiment figures

This folder contains saved figure exports.
Analysis and plotting scripts are located in `experiments/`.

## Figure mapping

| Export | Content or report use |
| --- | --- |
| `delay_cdf_load_03.png` | Figure 6.1: high-load completed-packet delay CDF |
| `duration_load_03.png` | Figure 6.2: high-load duration sensitivity |
| `delay_cdf_load_01.png` | Completed-packet delay CDF at total load 0.15 |
| `delay_cdf_load_02.png` | Completed-packet delay CDF at total load 0.30 |
| `duration_load_01.png` | Duration comparison at total load 0.15 |
| `duration_load_02.png` | Duration comparison at total load 0.30 |
| `overhead_load_01.png` | Control-cost analysis at total load 0.15 |
| `overhead_load_02.png` | Control-cost analysis at total load 0.30 |
| `overhead_load_03.png` | Control-cost analysis at total load 0.45 |
| `imbalance_results.png` | Traffic-imbalance analysis |
| `hotspot_results.png` | Hotspot-location analysis |
| `graph_results.png` | Conflict-graph analysis |
| `load_diagnostics.png` | Balanced-load diagnostics |

## Regenerating figures

Run `setup_project`, then the corresponding analysis script.
The [main README](../README.md) lists the required commands and input batches.

Re-running an analysis saves new outputs in the location printed by that script.
It does not automatically replace the stored exports in this folder.

Report figures should retain readable English labels, units, legends,
and explanations of confidence intervals where applicable.
Delay values use normalized time units, not milliseconds.

All stored exports are retained as supporting material.
The report uses a selection of these figures.
