# Simulation Engine / 仿真引擎

Owner: Member B.
负责人：成员 B。

This folder contains the shared MATLAB simulation engine
and the independent randomized-access baseline.

本文件夹存放全组共用的 MATLAB 仿真引擎，
以及独立随机接入基线。

## Responsibilities / 主要功能

- Generate and process packet arrivals.
  生成并处理数据包到达。

- Maintain three FIFO AP queues.
  维护三个 AP 的先进先出队列。

- Advance simulation time and process transmission events.
  推进仿真时间，处理发送事件。

- Enforce interference constraints.
  执行干扰约束。

- Implement randomized access.
  实现随机接入。

- Call the coordinated schedulers provided by Member C.
  调用成员 C 提供的协调调度器。

- Record packet completion, backlog and control time.
  记录数据包完成情况、队列积压与控制时间。

## Planned functions / 计划函数

- generate_arrivals.m
- simulate_network.m

Function names and interfaces must be confirmed with Members C and D.
函数名称与接口须与成员 C、D 确认。

## Validation / 验证要求

- No transmission from an empty queue.
  空队列不发送。

- Compatible APs may transmit simultaneously.
  兼容 AP 可以同时发送。

- Conflicting APs cannot be successfully served simultaneously.
  存在干扰关系的 AP 不能同时成功服务。

- Coordination time advances the simulation clock.
  协调时间必须计入仿真时钟。

- Arrivals continue during control and transmission periods.
  控制和发送期间，数据包仍可继续到达。

- Packet counts must balance.
  到达包数应等于完成包数、丢弃包数与剩余包数之和。

## Status / 当前状态

Folder structure only; implementation has not started.
目前仅建立目录，尚未实现功能。
