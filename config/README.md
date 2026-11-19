# Simulation configuration

`default_config.m` returns the shared configuration structure `cfg`.
These defaults describe the integration demonstration.

| Parameter | Default |
| --- | --- |
| AP queues | 3 |
| Per-AP arrival rates | [0.25, 0.25, 0.25] |
| Total arrival rate | 0.75 packets per time unit |
| Data transmission duration | 1 normalized time unit |
| Random-access slot duration | 1 normalized time unit |
| Control duration | 0.1 normalized time units |
| Packet payload | 12000 bits |
| Simulation horizon / warmup | 1000 / 100 |
| Arrival seed / access seed | 101 / 202 |
| Conflict edges | AP1–AP2 and AP2–AP3 |
| Coordinated concurrency cap | 2 |
| Random-access attempt probability | 0.5 |
| Maximum backoff counter | 5 |

Experiment runners in `experiments/` override these defaults for the formal
sweeps and save their actual configurations with the results.

The queue snapshot is taken before the control interval.
Time is normalized and is not calibrated to milliseconds.

Run `setup_project` from the repository root before using the code.
See the [main README](../README.md) for experiment settings and reproduction steps.
