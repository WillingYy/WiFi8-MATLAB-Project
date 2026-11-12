# Experiments and Metrics / 实验与指标统计

Owner: Member D.
负责人：成员 D。

This folder contains MATLAB scripts for running experiments
and calculating performance metrics.

本文件夹存放批量运行实验与计算性能指标的 MATLAB 脚本。

## Planned files / 计划文件

- run_experiments.m
  Run the agreed experiment scenarios.
  执行团队约定的实验场景。

- compute_metrics.m
  Calculate delay, goodput and coordination airtime.
  计算延迟、有效吞吐率与协调时间占比。

## Experiment factors / 实验因素

- Traffic imbalance with the total arrival rate held constant.
  保持总到达率不变，改变各 AP 的流量比例。

- Interference graph density.
  改变干扰图密度。

- Coordination control time.
  改变协调控制时间。

- Light, medium and high offered load.
  检查轻、中、高负载。

For the chain graph, compare a hotspot at the middle AP
with a hotspot at an endpoint AP.

对于链形干扰图，分别比较中间 AP 和端点 AP 为热点的情况。

## Metrics / 指标

- Overall and per-AP 95th-percentile packet delay.
  总体与逐 AP 的第 95 百分位数据包延迟。

- Per-AP goodput.
  各 AP 成功交付有效载荷的速率。

- Coordination airtime fraction.
  协调控制占用的时间比例。

- Backlog, unfinished packets and packet drops.
  队列积压、未完成包与丢包。

## Reproducibility / 可复现要求

Use the same arrival trace across methods in each scenario.
同一场景下，三种方法使用相同的到达轨迹。

Record configuration, random seeds and code version.
记录配置、随机种子和代码版本。

Document warm-up, measurement windows and aggregation methods.
说明预热期、测量窗口与多次运行的汇总方法。

Report unfinished packets and growing queues.
Do not assess overloaded systems using completed-packet delay alone.

报告未完成包和持续增长的队列。
不能只用已完成包的延迟评价过载系统。

Save raw outputs in results/ and plotting scripts in figures/.
原始输出保存在 results/，绘图脚本保存在 figures/。

## Status / 当前状态

Folder structure only; experiments have not been run.
目前仅建立目录，尚未运行实验。
