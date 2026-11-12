# Simulation Results / 仿真结果

Owner: Member D.
负责人：成员 D。

This folder stores simulation outputs and the information
needed to reproduce each experiment.

本文件夹保存仿真输出，以及复现实验所需的信息。

## Required records / 必须保存的记录

- Experiment identifier / 实验编号
- Configuration / 参数配置
- Random seeds / 随机种子
- Code commit identifier / 代码提交编号
- Raw outputs and calculated metrics / 原始输出与统计指标
- Unfinished packets and backlog / 未完成包与队列积压

Use MAT files for MATLAB data and CSV files for summary tables.
MATLAB 数据使用 MAT 文件，汇总表可使用 CSV 文件。

## Rules / 保存规则

Do not overwrite results from different configurations.
不同配置的结果不得相互覆盖。

Mark failed, incomplete or superseded runs clearly.
明确标记失败、未完成或已被替代的运行。

If a code correction affects results, record which experiments
were rerun and why.

代码修正影响结果时，记录重跑了哪些实验及原因。

Keep large temporary outputs outside Git.
Commit compact results and configurations needed for the report.

大型临时输出不放入 Git。
仓库保留报告所需的精简结果与配置。

## Status / 当前状态

No experimental results have been generated yet.
目前尚未生成实验结果。
