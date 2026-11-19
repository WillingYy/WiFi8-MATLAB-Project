# Coordinated schedulers

The executable scheduler functions are located in the parent `src/` directory:

- [schedule_rr.m](../schedule_rr.m): round-robin priority.
- [schedule_queue.m](../schedule_queue.m): longest-queue priority with rotating ties.

This directory retains scheduling documentation; it does not contain another
copy of the scheduler implementation.

Both functions use the interface:

```matlab
selectedAPs = schedule_rr(state, graph, cfg);
selectedAPs = schedule_queue(state, graph, cfg);
```

They select nonempty, pairwise compatible APs within the concurrency limit.
Compatible additional APs are examined in cyclic pointer order.
The shared engine manages pointer updates, packet arrivals, control time, and
packet completion.

Run `setup_project` followed by `test_cb_integration`.
See the [main README](../../README.md) for the full reproduction procedure.
