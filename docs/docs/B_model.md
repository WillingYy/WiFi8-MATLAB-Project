# System Model and Random-Access Baseline

## 1. System Model

We consider a network of three Access Points (APs), each maintaining a first-in-first-out (FIFO) queue. The initial model assumes a fixed packet size and a constant transmission duration Tdata. Packets arrive independently at each AP following a Poisson process with rate lambda. The physical layer and interference conditions are abstracted using an undirected conflict graph. An edge between two APs indicates that they cannot successfully transmit simultaneously, while the absence of an edge allows for concurrent transmission. A unified discrete-event clock governs the simulation. The delay metric is defined as the enqueue-to-successful-completion time, which encompasses all waiting and service intervals. We evaluate both the overall and per-AP 95th percentile (P95) delay and goodput.

## 2. Random-Access Baseline

The baseline employs a time-slotted simplified random-access model with independent Bernoulli attempts and random backoff. It is important to note that this is an abstraction and does not represent a faithful DCF or CSMA/CA implementation. At each time slot, non-empty APs whose backoff counter has expired attempt to transmit with a fixed probability p. Let A be the set of attempting APs. An AP i in A succeeds if and only if there is no AP in A that shares a conflict edge with i. If a conflict occurs, the failing APs draw a new random backoff from a uniform distribution and the failed transmission occupies the channel for Tdata. Compatible APs, however, may succeed concurrently.

## 3. Coordinated Policies and Control Overhead

For coordinated policies, namely round-robin and queue-aware, a fixed control interval c precedes every non-empty coordinated decision. During this control interval, packet arrivals continue to be processed and queuing delays accumulate, but no data service occurs. Both coordinated policies are charged identically for this overhead. The queue snapshot utilized by the scheduler is taken either before or after this interval, according to the locked interface specification. 

## 4. Scope and Limitations

This model utilizes graph compatibility and deterministic service times to abstract away physical-layer details such as RSSI, SINR, power control, MCS adaptation, and ACK losses. Perfect knowledge of queue states at the central scheduler serves as an idealization. The results are interpreted strictly within the boundaries of this simplified abstraction.