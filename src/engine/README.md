# Shared simulation engine

This folder contains:

- `simulate_network.m`: shared clock, FIFO queues, random access, coordinated
  service, scheduling-state updates, and result collection.
- `generate_arrivals.m`: Poisson arrivals from the configured arrival stream.
- `is_independent_set.m`: conflict-graph compatibility check.
- `my_quantile.m`: quantiles using linear interpolation between sorted samples.
- `builtin_schedule_rr.m`, `builtin_schedule_queue.m`: fallback schedulers.

The official coordinated schedulers are in the parent `src/` directory.
Run `setup_project` so that these functions are available on the MATLAB path.

The engine initializes, supplies, and updates `rrPointer` and `tiePointer`.
The official schedulers read the snapshot without modifying queues or time.
The engine handles arrivals, control intervals, transmissions, packet removal,
and measurement-window statistics.

Run the following commands from the repository root:

```matlab
setup_project
validate_engine
test_cb_integration
```

See the [main README](../../README.md) for metrics, limitations, and verified
demonstration values.
