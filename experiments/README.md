# Experiment runners and analyses

Run `setup_project` from the repository root before using these scripts.

## Script groups

- `test_cb_integration.m`: scheduler unit checks and engine integration checks.
- `run_d_*.m`: generate new simulation batches for offered load, traffic
  imbalance, hotspot location, conflict graphs, concurrency limits, and
  coordination overhead.
- `analyse_d_*.m`: analyse recorded results and export figures and summary tables.
- `compare_d_overhead_duration.m`: compare the recorded 10000- and
  20000-time-unit overhead batches.

## Using saved results

Analysis scripts read existing data without rerunning the simulation.
Keep the required CSV files, saved configurations, and MAT samples together.

Interactive analyses ask for an input batch folder under `results/`.
Select the batch folder itself, not an `analysis_...` subfolder.

The balanced-load CDF analysis requires the 180 original per-run MAT files
in `results/D_load_20261117_233652/`.

## Generating new results

Experiment runners create timestamped batch directories under `results/`.
All policies share the same arrival trace within each configuration and replication.

When analysing newly generated batches, select their new directories in the
interactive analyses. The following scripts reference the recorded report
batches explicitly, so update their input paths when using new batches:

- `analyse_d_load.m`
- `analyse_d_delay_cdf.m`
- `compare_d_overhead_duration.m`

See the [main README](../README.md) for the complete command-to-batch mapping,
report figure and table mapping, experimental settings, and verification results.
