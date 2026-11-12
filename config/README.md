# Simulation Configuration / 仿真参数配置

This folder stores the shared MATLAB simulation configuration.
本文件夹存放全组统一使用的 MATLAB 仿真参数。

Owner: Member B, with input from Members C and D.
负责人：成员 B；成员 C、D 共同确认。

## Planned file / 计划文件

default_config.m

This function will return a configuration structure named cfg.
此函数将返回名为 cfg 的参数结构体。

## Parameters to agree / 待统一参数

- Packet size / 数据包长度
- Data transmission duration / 数据发送时长
- Coordination control duration / 协调控制时长
- Arrival rates for each AP / 各 AP 到达率
- Interference graph / 干扰图
- Random-access parameters / 随机接入参数
- Simulation duration and warm-up / 仿真时长与预热期
- Random seeds / 随机种子

## Rules / 使用规则

Use consistent units and document each parameter.
统一单位，并说明每个参数的含义。

Avoid hard-coded experimental parameters in algorithm files.
避免将实验参数直接写死在算法文件中。

Save the configuration used for each experiment with its results.
每次实验使用的配置必须随结果保存。

Parameter values and field names are not final yet.
具体参数数值和字段名称尚未确定。
