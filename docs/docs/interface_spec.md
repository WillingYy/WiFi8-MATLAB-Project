# Interface Specification v1.1 for the Unified Engine

## Scheduler Function Signatures

Member C is required to implement the following functions:
selectedAPs = schedule_rr(state, graph, cfg)
selectedAPs = schedule_queue(state, graph, cfg)

The state input is a structure containing the following fields:
- state.t: Current simulation time
- state.queueLen: Array of current queue lengths for all APs
- state.headWait: Array of wait times for the head-of-line packet at each AP
- graph.adjMatrix: N by N binary adjacency matrix representing the conflict graph
- cfg: Global configuration structure

Schedulers must operate as read-only functions. They must not advance the global clock, delete packets, or modify queue states. All clock advancement, arrival processing, transmission execution, packet removal, and statistical recording are strictly handled by the central engine.

## Random-Access Baseline Naming

The baseline is formally defined as a time-slotted simplified random-access baseline with Bernoulli attempts and random backoff. It is explicitly not a faithful DCF or CSMA/CA implementation. 

## Delay Endpoint Definition

Delay is measured from enqueue to successful completion, incorporating both queuing delay and service time.

## Control Overhead

Both coordinated policies incur a fixed control interval c before every non-empty scheduling decision. During this interval, packet arrivals continue and queuing delays accumulate, but no data service occurs. Both policies are charged identically for this overhead.

## Pending Decisions for Members C and D

1. Snapshot timing: Whether the queue state is sampled before or after the control interval.
2. Concurrency limit: Whether the maximum number of simultaneous APs is capped at two.
3. Unfinished packets: Whether to use the window-completion mode or the cohort-drain mode.