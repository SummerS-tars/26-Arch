# Lab+ 之前 Bonus 汇总骨架

本文按 Lab+ 官方页面中“之前的 Bonus 列表”整理，用作后续主文档骨架。后续每完成一个分任务，先写对应分文档，再把摘要汇总到本文。

官方要求来源：[Lab+ & Bonus](https://github.com/26-Arch/26-Arch/wiki/Lab--)。

## 状态说明

- 已实现：当前代码或既有报告中已有明确依据。
- 未实现：当前没有实现或报告中明确说明未完成。
- 待确认：需要进一步查证、补充实测或补报告材料。
- 不补做：回答类 Bonus 若未在当次报告中出现，按官方说明通常不能再补计；本文仍保留骨架。

## 任意 Lab

### 乘除法

- 状态：已实现。
- 评定方式：`lab1-extra`。
- 分文档：`Doc/Lab+/lab1-extra_report.md`。
- 当前依据：
  - 已实现 RV64M 乘除法。
  - `lab1-extra` 已通过，关键输出为 `HIT GOOD TRAP at pc = 0x8002001c`。
  - Lab4/Lab5/Lab6 回归通过。
- 汇总草稿：
  - 本项目在现有五级流水线基础上扩展 `alu_op_t`、译码和 ALU 组合逻辑，支持 `mul/div/rem` 及 W 版本指令。实现中处理除零、`INT_MIN / -1` 溢出和 W 指令符号扩展。该项已经通过 `lab1-extra` 验证。

## Lab 3

### 使用非 Basys3 板子

- 状态：未实现 / 未选择。
- 评定方式：Lab3 报告或 Lab+ 报告。
- 分文档：待需要时新增。
- 当前依据：
  - 当前仓库未见非 Basys3 板卡验证记录。
- 后续若要补：
  - 需要说明板卡型号、约束/顶层适配、上板流程和串口/波形验证结果。

## Lab 4

### 简述各个 CSR 寄存器的作用

- 状态：已实现。
- 评定方式：Lab4 报告。
- 分文档：可选，当前可直接从 `Doc/Lab4/report.md` 汇总。
- 当前依据：
  - `Doc/Lab4/report.md` 已有“CSR 寄存器作用简述”章节。
- 汇总草稿：
  - Lab4 报告已经说明 `mstatus`、`mtvec/stvec`、`mip/sip`、`mie/sie`、`mepc/sepc`、`mcause/scause`、`mtval/stval`、`mcycle`、`mhartid`、`satp`、`medeleg/mideleg`、`pmpcfg0/pmpaddr0` 等寄存器作用。

### 思考为什么一定要刷新流水线

- 状态：已实现。
- 评定方式：Lab4 报告。
- 分文档：可选，当前可直接从 `Doc/Lab4/report.md` 汇总。
- 当前依据：
  - `Doc/Lab4/report.md` 已说明 CSR 指令后刷新流水线的原因。
- 汇总草稿：
  - CSR 会改变处理器全局可见状态，后续指令若沿用旧状态执行，可能出现错误行为。当前 CPU 不对 CSR 状态做普通 forwarding，因此 CSR 指令后通过重定向到 `pc + 4` 并清空年轻指令，保证后续指令重新在正确 CSR 状态下取指和执行。

### 实现 `csr.sv` 给定的所有寄存器，包括 S 模式寄存器

- 状态：已实现基础读写。
- 评定方式：Lab4 报告或 Lab+ 报告。
- 分文档：可选，当前可直接从 `Doc/Lab4/report.md` 汇总。
- 当前依据：
  - `Doc/Lab4/report.md` 说明已实现 `sstatus`、`stvec`、`sscratch`、`sepc`、`scause`、`stval`、`sie`、`sip`。
  - 也补充了 `medeleg`、`mideleg`、`pmpcfg0`、`pmpaddr0` 的基本读写。
- 注意：
  - 这里的 `pmpcfg0/pmpaddr0` 当前只是 CSR 基本读写，不等同于 PMP 权限检查。
- 汇总草稿：
  - Lab4 在必做 M 模式 CSR 外，补充实现了 S 模式相关 CSR 及 delegation/PMP CSR 的基本读写，并通过 Difftest CSR 状态导出保持提交时序一致。

## Lab 5

### MMU 支持巨页

- 状态：已实现。
- 评定方式：Lab5 报告或 Lab+ 报告。
- 分文档：待需要时新增 `lab5-hugepage_report.md`。
- 当前依据：
  - `Doc/Lab5/report.md` 写明支持上级页表项直接作为叶子项。
  - `MMU.sv` 的 `leaf_addr()` 会按 level 拼接 1GB / 2MB / 4KB 映射地址。
- 汇总草稿：
  - MMU 页表遍历过程中，只要当前 PTE 是 leaf PTE，即按当前 level 拼接物理地址。因此当第一级或第二级 PTE 为叶子项时，低级 VPN 会与页内偏移一起来自虚拟地址，从而支持 1GB / 2MB 巨页映射。

### 实现 MMU 的缺页异常

- 状态：未实现。
- 评定方式：Lab5 报告或 Lab+ 报告。
- 分文档：待实现后新增 `lab5-page-fault_report.md`。
- 当前依据：
  - `Doc/Lab6/report.md` 明确写到“本次没有实现 Bonus 的缺页异常”。
  - 当前 `trap.sv` 未见 page fault cause。
  - 当前 `MMU.sv` 对 invalid PTE 仍是直通回退，不是产生 page fault。
- 后续若要实现：
  - 增加 instruction/load/store page fault cause。
  - MMU 将 PTE invalid、权限错误、A/D 位等异常反馈给 core。
  - 在提交边界进入 trap，并设置 `mcause` / `mtval`。

## Lab 6

### 编写中断处理程序，在时钟中断时打印一些内容

- 状态：未作为 Bonus 单独完成。
- 评定方式：Lab6 报告。
- 分文档：待需要时新增 `lab6-timer-handler_report.md`。
- 当前依据：
  - Lab6 主线已支持机器时钟中断。
  - Lab6 测试输出中有 timer interrupt 测试信息。
  - 但当前报告未单独给出“编写中断处理程序并打印内容”的 Bonus 代码材料。
- 后续若要补：
  - 需要给出中断处理程序代码片段。
  - 说明如何设置 `mtimecmp`、响应 MTIP、打印内容并重新设置下一次时钟中断。

### 思考时钟中断为什么使用 MMIO 计时器

- 状态：不补做 / 未在报告中发现。
- 评定方式：Lab6 报告。
- 分文档：不建议单独补，除非确认课程允许 Lab+ 报告补充回答类 Bonus。
- 当前依据：
  - 当前 `Doc/Lab6/report.md` 未发现该问题的专门回答。
  - 官方说明中回答类 Bonus 通常要求当次报告中包含。
- 骨架回答占位：
  - MMIO 计时器让 CPU 通过普通 load/store 访问外设寄存器，硬件实现简单，也便于仿真环境和真实 SoC/FPGA 外设统一建模。计时器作为外设独立维护 `mtime/mtimecmp`，到期后通过中断线通知 CPU，CPU 无需把计时逻辑耦合进核心流水线。

## 后续汇总规则

每个 Bonus 项后续按以下流程整理：

1. 先写分文档，例如 `lab1-extra_report.md`。
2. 分文档中记录：
   - 要求
   - 当前实现基础
   - 实现内容
   - 实现思路
   - 验证结果
3. 验证通过后，把摘要同步到本文对应条目。
4. 最终再从本文提炼到正式 `docs/report.md` 或 `docs/report/report.md`。
