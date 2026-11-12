# WiFi8-MATLAB-Project
EEEN3008J group project on multi-AP coordination and tail delay using MATLAB。
# Wi-Fi 8-inspired Multi-AP Coordination
# Wi-Fi 8 启发的多接入点协调

EEEN3008J Wireless Communications — 2026/27 Autumn  
EEEN3008J 无线通信课程小组项目

## 1. Research Question / 研究问题

Can coordination between neighbouring access points reduce
95th-percentile packet delay enough to justify coordination overhead?

相邻接入点之间的协调，能否充分降低数据包的第 95 百分位延迟，
使其收益足以抵消协调开销？

## 2. Project Scope / 项目范围

We use MATLAB to simulate three AP queues and an interference graph.
Compatible APs may transmit simultaneously.

使用 MATLAB 仿真三个 AP 的数据包队列，并通过干扰图判断
哪些 AP 可以同时发送。

This is a Wi-Fi 8-inspired coordination abstraction,
not a compliant IEEE 802.11bn implementation.

本项目是受 Wi-Fi 8 启发的协调抽象模型，
并非符合 IEEE 802.11bn 标准的完整实现。

## 3. Methods / 对比方法

1. Independent randomized access / 独立随机接入
2. Coordinated round-robin / 协调式轮询
3. Queue-aware coordination / 队列感知协调

Access rules, scheduling interfaces and control-time accounting
must be agreed before the main experiments.

正式实验前，统一接入规则、调度接口和控制时间的计算方式。

## 4. Experiments / 实验内容

- Traffic imbalance with a fixed total arrival rate
  总到达率保持不变时，改变各 AP 的流量比例

- Interference graph density
  改变干扰图密度

- Coordination control time
  改变协调控制时间

- Light, medium and high offered load
  检查轻、中、高负载下的表现

## 5. Metrics / 评价指标

- Overall and per-AP 95th-percentile packet delay
  总体与逐 AP 的第 95 百分位数据包延迟

- Per-AP goodput
  各 AP 成功交付有效载荷的速率

- Coordination airtime
  协调控制占用的时间比例

- Queue backlog and unfinished packets
  队列积压与未完成数据包数量

## 6. Team Responsibilities / 成员分工

| Role / 角色 | Responsibility / 职责 |
| --- | --- |
| Team lead / 组长 | Shared assumptions, integration, report and submission / 统一假设、整合成果、报告与提交 |
| Member A / 成员 A | Literature review, background and references / 文献、背景与引用 |
| Member B / 成员 B | MATLAB engine and randomized-access baseline / MATLAB 引擎与随机接入基线 |
| Member C / 成员 C | Round-robin and queue-aware schedulers / 轮询与队列感知调度 |
| Member D / 成员 D | Experiments, metrics, figures and analysis / 实验、统计、图表与分析 |

Member names will be added later.  
后续补充成员姓名。

## 7. Planned Structure / 计划目录

| Path / 路径 | Purpose / 用途 |
| --- | --- |
| docs/ | Shared assumptions and report materials / 共同约定与报告材料 |
| config/ | Simulation configuration / 仿真参数 |
| src/engine/ | Engine and randomized access / 仿真引擎与随机接入 |
| src/schedulers/ | Coordinated scheduling policies / 协调调度策略 |
| experiments/ | Experiment runners and metric calculation / 批量实验与指标计算 |
| results/ | Results, configurations and seeds / 结果、配置与随机种子 |
| figures/ | Plotting scripts and exported figures / 绘图脚本与导出图片 |
| run_demo.m | Small demonstration entry point / 小规模示例运行入口 |

These components are planned and are not implemented yet.  
以上为计划结构，目前尚未完成实现。

## 8. MATLAB Environment / MATLAB 环境

- MATLAB release / MATLAB 版本：To be confirmed / 待确认
- Required toolboxes / 所需工具箱：To be confirmed / 待确认

Do not introduce additional toolbox dependencies without team agreement.  
未经团队确认，不新增工具箱依赖。

## 9. Collaboration Rules / 协作规则

1. Use one shared simulation engine.
   全组使用同一个仿真引擎。

2. Confirm function interfaces before implementation.
   编写代码前确认函数接口。

3. Keep parameter values in configuration files.
   参数集中放在配置文件中。

4. Record configurations, seeds and code versions for experiments.
   实验记录参数、随机种子与代码版本。

5. Notify affected members before changing shared interfaces.
   修改公共接口前通知相关成员。

6. Keep raw results separate from plotting scripts.
   原始结果与绘图脚本分开保存。

7. Record AI assistance and human verification.
   记录 AI 的使用情况与人工验证过程。

## 10. Internal Milestones / 内部关键节点

All times below are Beijing time, UTC+8.  
以下全部为北京时间。

| Deadline / 截止时间 | Deliverable / 必须完成 |
| --- | --- |
| 13 Nov 21:00 / 11 月 13 日 21:00 | Shared model and interfaces agreed / 统一模型与接口 |
| 14 Nov 20:00 / 11 月 14 日 20:00 | Three methods running in one engine / 三种方法在同一引擎跑通 |
| 15 Nov 22:00 / 11 月 15 日 22:00 | Validation passed / 验证通过 |
| 17 Nov 20:00 / 11 月 17 日 20:00 | Main results available / 主要实验结果齐全 |
| 18 Nov 22:00 / 11 月 18 日 22:00 | Complete report draft / 完整报告初稿 |
| 19 Nov 22:00 / 11 月 19 日 22:00 | Final materials ready / 最终材料齐全 |
| 20 Nov 20:00 / 11 月 20 日 20:00 | Target submission time / 计划提交时间 |

## 11. Submission / 提交要求

One PDF submission per group.  
每组提交一份 PDF。

The report must include:
报告必须包含：

- All member names and student numbers
  全部成员姓名与学号

- An AI-use disclosure statement
  AI 使用声明

- A code repository link or code appendix
  代码仓库链接或代码附录

Page limit: 15 pages in single-column format or 8 pages in
double-column format. Appendices are excluded.

页数限制：单栏最多 15 页，双栏最多 8 页，附录不计入页数。
