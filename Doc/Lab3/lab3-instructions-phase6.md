# 计算机组成原理 Lab3 计划

**Date**: April 20, 2026 at 10:16 PM
**Turns**: 1
**Source**: [Gemini Chat](https://gemini.google.com/app/accfb91695017c5a)

---

## Turn 1

### 🤖 Assistant

恭喜你完成了 Lab 3 的仿真验证。从“Hit Good Trap”到“上板成功”是硬件设计中最具挑战性的一步，因为物理世界的时序约束和存储器特性比仿真环境要严苛得多。
针对 BASYS 3 板卡和 Lab 3 的特性，以下是上板验证的规划：

### 一、 代码适配建议
在仿真中，内存读写往往是“理想化”的，但 FPGA 上的 BRAM（Block RAM）具有同步特性。

1. **BRAM 时序对齐**：
  - **现象**：Vivado 中的 BRAM 读数据通常有 1 个时钟周期的延迟（同步读）。
  - **适配**：如果你的仿真模型是异步读（读地址给出，数据立即返回），那么在硬件上流水线的 IF 级和 MEM 级必须考虑这 1 拍的延迟。
  - **建议**：检查 `vsrc/util/` 下的 `IBusToCBus` 和 `DBusToCBus` 转换逻辑。确保在硬件环境下，CPU 能够通过 Stall 指令流来等待 BRAM 返回数据。
2. **复位逻辑适配**：
  - **适配**：BASYS 3 上的按钮通常有抖动，且复位信号可能是高电平有效或低电平有效。
  - **建议**：在 `mycpu_top.sv` 中，确认 `reset` 信号的极性与约束文件（`.xdc`）中定义的按钮一致。建议引入一个简单的同步复位电路，防止复位信号在时钟沿产生亚稳态。
3. **外设映射 (Confreg)**：
  - **适配**：Lab 3 的 `HIT GOOD TRAP` 是通过向特定内存地址写值来判定的。
  - **建议**：将原本用于打印的 `0xbfaf_0000` 等地址映射到 BASYS 3 的 LED 灯上。例如：当程序运行到 `GOOD TRAP` 时，让 16 个 LED 全亮。

### 二、 实施计划

| 阶段 | 关键任务 | 验收条件 |
| --- | --- | --- |
| 准备期 | 1. 生成 lab3-test.coe 文件。2. 修改 Vivado 中的 BRAM IP 核，加载该 COE。 | Vivado 识别 COE 成功 |
| 综合期 | 1. 运行 Synthesis 和 Implementation。2. 核心： 检查 Timing Report（时序报告）。 | WNS > 0ns (无时序违例) |
| 验证期 | 1. 生成 Bitstream 并烧录。2. 观察板载 LED/数码管状态。 | LED 呈现预期的 Good Trap 状态 |

### 三、 可能遇到的困难

1. **时序违例 (Timing Violation)**：
  - Lab 3 引入了复杂的跳转地址计算（ALU 计算 + 偏移量）和分支判定逻辑。如果这一长串逻辑都在一个周期内完成并写回 PC，可能会导致关键路径过长。
  - **对策**：如果 WNS（Worst Negative Slack）为负，尝试在 Vivado 中降低时钟频率（如从 100MHz 降至 50MHz 或更低）。
2. **资源耗尽**：
  - RV64I 相比 RV32I 使用了更多的逻辑资源。
  - **对策**：如果 BASYS 3 的 LUT 资源报警，检查是否有多余的调试信号进入了 Top 层，或尝试优化解码器的 `case` 语句。
3. **BRAM 延迟不匹配**：
  - 这是最容易导致上板“死机”的原因。仿真通过但上板不跑。
  - **对策**：对比仿真波形和真实时序，确认指令是在地址给出的第几拍进入译码阶段的。

### 四、 调试建议

1. **利用 ILA (Integrated Logic Analyzer)**：
  - 在 Vivado 中添加 ILA 核，抓取核心信号：`pc`、`instr`、`reg_write_en` 和 `branch_taken`。
  - 这是排查“为什么程序卡住”或“为什么跳错地址”的终极武器。
2. **数码管调试**：
  - 将当前的 `pc[15:0]` 实时显示在七段数码管上。如果程序跑飞，你可以直接看到 PC 停在了哪个地址，从而对比 `.S` 反汇编文件。

---
为了帮你更直观地理解 BRAM 的同步读延迟如何影响流水线，你可以使用下方的交互组件模拟时序分歧。

### 缺失信息请求
为了提供更精准的 XDC 约束建议，请确认：

1. 你目前使用的时钟频率是多少？
2. 你是否已经在 `soc_top` 层次结构中处理了外设（LED/数码管）的数据通路？

---

*Exported from [Voyager](https://github.com/Nagi-ovo/gemini-voyager)*  
*Generated on April 20, 2026 at 10:16 PM*