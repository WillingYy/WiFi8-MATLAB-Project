# Coordinated Schedulers / 协调调度器

Owner: Member C.
负责人：成员 C。

This folder contains the coordinated round-robin
and queue-aware scheduling policies.

本文件夹存放协调轮询与队列感知调度策略。

## Planned functions / 计划函数

- schedule_rr.m
  Coordinated round-robin scheduler.
  协调轮询调度器。

- schedule_queue.m
  Queue-aware scheduler.
  队列感知调度器。

## Shared interface / 共同接口

Inputs should include:
输入应包含：

- Current simulation time / 当前仿真时间
- Queue lengths / 各 AP 队列长度
- Head-of-line waiting times / 各 AP 队首包等待时间
- Interference graph / 干扰图
- Configuration / 参数配置

Output:
输出：

- Selected AP identifiers / 本轮选中的 AP 编号

Exact function signatures and data dimensions must be agreed
with Members B and D before implementation.

具体函数接口与数据维度，须在实现前与成员 B、D 确认。

## Scheduling rules / 调度规则

- Select only nonempty AP queues.
  只选择非空队列。

- All selected APs must be pairwise compatible.
  所有被选中的 AP 必须两两兼容。

- Define tie-breaking and round-robin pointer updates.
  明确并列处理与轮询指针更新规则。

- Use the same compatible-group expansion rule for both policies.
  两种策略使用相同的兼容组扩展规则。

- Both policies use the same control-time accounting.
  两种策略使用相同的控制时间计算方式。

The shared engine handles arrivals, timing and packet removal.
Schedulers only select APs; they must not duplicate engine functions.

到达、计时和移除数据包由公共引擎负责。
调度器只选择 AP，不重复实现引擎功能。

## Status / 当前状态

Folder structure only; implementation has not started.
目前仅建立目录，尚未实现功能。
