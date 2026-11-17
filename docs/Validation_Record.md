# Part C — Validation record

**Environment:** macOS, MATLAB R2026b Update 1 (`26.2.0.3433840`)  
**Evidence:** MATLAB Command Window output supplied by the user, 17 November 2026.  
**Commands:** `test_cb_integration`, `run_demo`, `validate_engine`.

## Scheduler and integration test

```text
=== C+B integration tests ===
[PASS] C scheduler unit and graph tests
[PASS] random: arrivals=750, completions=574, P95=420.9761, ctrl=0.0000
[PASS] rr: arrivals=750, completions=749, P95=5.1157, ctrl=0.0662
[PASS] queue: arrivals=750, completions=749, P95=4.5334, ctrl=0.0652
=== C+B integration checks passed ===
```

The scheduler test covers 8 labelled interference graphs × 64 queue states × 2 policies = **1,024 scheduler/graph/queue-state combinations**. It additionally tests deterministic examples and rotating priorities. These are not 1,024 full-network runs.

## Full-engine demonstration (same arrival trace)

| Policy | Arrivals | Completed | Unfinished | Balanced | Pooled P95 delay | Goodput (bits/time) | Control airtime fraction |
|---|---:|---:|---:|---|---:|---:|---:|
| random | 750 | 574 | 176 | Yes | 420.9761 | 6946.6667 | 0.0000 |
| rr | 750 | 749 | 1 | Yes | 5.1157 | 8920.0000 | 0.0662 |
| queue | 750 | 749 | 1 | Yes | 4.5334 | 8920.0000 | 0.0652 |

QA P95 is approximately **11.38% lower than RR** for this default configuration, calculated as `(5.1157 - 4.5334) / 5.1157`. This does not establish a general improvement across all loads.

## Engine validation

The user reported `[PASS]` for T1–T9, including empty queues, single AP, packet conservation, compatible and conflicting pairs, both coordinated policies, coordination airtime, and failed airtime. Final output:

```text
=== validate_engine: 9 passed, 0 failed ===
```

## Boundaries

- Test execution is reported by the user; this package was not independently executed in MATLAB by the assistant.
- The test checks that control airtime is positive, not an exhaustive timing proof for every boundary case.
- The baseline is simplified random access, not faithful IEEE 802.11 DCF/CSMA-CA.
- D's multi-scenario parameter sweeps and uncertainty estimates are not part of this record.
