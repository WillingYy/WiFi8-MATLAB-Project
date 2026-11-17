# Part C — Coordinated Scheduling Methods

## Coordinated scheduling model

We implement two coordinated scheduling policies for a simplified three-access-point (AP) network: round-robin (RR) and queue-aware (QA) scheduling. Each AP maintains a first-in-first-out (FIFO) packet queue. A symmetric interference graph represents which AP pairs cannot transmit simultaneously. An edge between two APs denotes a conflict, whereas two APs without an edge can be scheduled together. The model allows at most two APs to transmit in one coordinated data interval under the default configuration. This is a Wi-Fi 8-inspired scheduling abstraction rather than a complete implementation of the IEEE 802.11bn protocol.

The scheduling functions use the common interface `selectedAPs = schedule_rr(state, graph, cfg)` and `selectedAPs = schedule_queue(state, graph, cfg)`. The input state includes the current queue lengths, head-of-line waiting times and a rotating priority pointer. The graph is provided as `graph.adjMatrix`, and `cfg.maxConcurrentAPs` limits parallel transmissions. Both functions are read-only: they return a list of AP indices and do not modify queues, advance the clock, or record performance statistics. These responsibilities belong to the common simulation engine developed by Member B.

## Round-robin scheduling

The RR policy provides a simple coordination rule that does not rank nonempty APs by queue size. It maintains a rotating pointer, initially pointing to AP1. For each nonempty scheduling decision, the scheduler examines APs in cyclic order starting from the pointer, skips empty queues, and selects the first nonempty AP as the primary transmitter. It then scans the same cyclic order to add other nonempty APs that do not interfere with any AP already selected, stopping when the concurrency limit is reached. Following a nonempty decision, the engine advances the pointer to the AP immediately after the primary transmitter. This makes the primary scheduling opportunity rotate over time rather than repeatedly favouring the lowest-index AP.

## Queue-aware scheduling

The QA policy selects an AP with the largest current queue as its primary transmitter. When several APs share the maximum queue length, the policy breaks the tie by scanning them in cyclic order from a separate rotating tie pointer. The engine advances that pointer after the selected primary AP. Once the primary AP is chosen, the scheduler considers additional nonempty APs in cyclic order from the pre-decision tie pointer, adding only those compatible with all currently selected transmitters. The same concurrency limit and interference constraints apply to both policies. This implementation deliberately uses queue length, not head-of-line waiting time, as its primary priority measure. Queue-aware scheduling can serve congested APs earlier, but its effect on fairness and tail latency must be established through measurements rather than assumed.

## Coordination overhead and simulation integration

Both coordinated policies incur the same fixed control interval before every nonempty scheduling decision. Under the default configuration, `Tctrl = 0.1` and `Tdata = 1.0` in simulation time units. The common engine uses `snapshotTime = before_ctrl`: it takes the scheduler snapshot before the control interval, processes any new arrivals during control without serving data, then executes the selected transmissions over the data interval. Newly arriving packets are queued and contribute to waiting time, but they do not retroactively change the selected AP set. When all queues are empty, the engine advances without charging a coordination interval. A packet's delay is measured from enqueue time to successful transmission completion. The engine also measures per-AP and pooled 95th-percentile delay, goodput and coordination airtime. This explicit overhead model prevents the coordinated methods from receiving an unrealistically free scheduling decision.

## Validation and interpretation

The scheduler integration test checks deterministic examples, rotating priorities, all eight labelled undirected interference graphs for three APs, and 64 queue states per graph for each policy. For every selected set, it checks that no empty AP is scheduled, no AP is duplicated, all selected APs are pairwise compatible, and the two-AP limit is respected. The user executed the combined tests in MATLAB R2026b Update 1 and reported that all integration checks passed. The common engine's nine validation checks also passed. With the default arrival trace, the observed pooled P95 delays were 420.9761 for the simplified random-access baseline, 5.1157 for RR, and 4.5334 for QA; RR and QA both achieved 8920 bits per simulation time unit of goodput. These are single-configuration demonstration results, not evidence that QA always outperforms RR. In particular, the randomized baseline is a simplified Bernoulli-attempt/backoff model rather than a complete CSMA/CA implementation. Final performance conclusions require the parameter sweeps and uncertainty analysis performed by Member D.

## Algorithm pseudocode

```text
ROUND_ROBIN(state, graph, cfg):
    if every queue is empty: return []
    order = cyclic_order(start = state.rrPointer)
    primary = first nonempty AP in order
    selected = [primary]
    for ap in order:
        if selected reaches cfg.maxConcurrentAPs: break
        if ap is nonempty, not selected, and compatible with all selected:
            append ap
    return selected
    # Engine sets rrPointer = successor(primary)

QUEUE_AWARE(state, graph, cfg):
    if every queue is empty: return []
    order = cyclic_order(start = state.tiePointer)
    primary = first AP in order with maximum queue length
    selected = [primary]
    for ap in order:
        if selected reaches cfg.maxConcurrentAPs: break
        if ap is nonempty, not selected, and compatible with all selected:
            append ap
    return selected
    # Engine sets tiePointer = successor(primary)
```

**Scope note:** The code and validation record document the implementation and user-reported MATLAB execution. Broader sensitivity analysis and final comparative conclusions are outside Member C's assigned deliverables.
