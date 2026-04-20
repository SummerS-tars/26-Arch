# Lab3 上板适配分析与调试建议

## 1. 文档目的

本文档用于固化当前仓库在完成 Lab3 基线仿真后，对“是否需要额外上板代码改造、需要改哪些地方、还可能出现什么问题、应如何调试”的分析结论。

本文档的依据包括：

- 官方 Lab3 页面：[Lab 3 Wiki](https://github.com/26-Arch/26-Arch/wiki/Lab-3)
- 官方上板页面：[上板 Wiki](https://github.com/26-Arch/26-Arch/wiki/%E4%B8%8A%E6%9D%BF)
- 仓库当前代码结构
- 实际运行 `make test-lab3` 的通过结果

本文档只讨论当前仓库的真实实现状态，不把旧总结、泛化 CPU 经验或未验证假设当作结论。

---

## 2. 当前结论

### 2.1 一句话结论

当前仓库在 Lab3 基线仿真已通过的前提下，**仍然需要做少量上板适配**，但这些适配主要集中在**板级路径与 Vivado 兼容性**，而不是再次修改 Lab3 指令语义本身。

### 2.2 更具体的判断

- `make test-lab3` 已通过，说明当前 CPU 的 Lab3 基线功能在 Verilator/Difftest 路径下是成立的。
- 板级路径不是直接使用 `SimTop.sv`，而是经过：
  - `vivado/src/with_delay/basys3_top.sv`
  - `vivado/src/with_delay/soc_top.sv`
  - `vivado/src/with_delay/bram_wrapper.sv`
  - `vivado/src/device.sv`
  - `vsrc/mycpu_top.sv`
  - `vsrc/VTop.sv`
- 因此，上板失败时不能第一时间假设是 Lab3 指令实现错误，更可能是：
  - Vivado 对某些写法不兼容
  - 板级设备路径行为和仿真路径不完全一致
  - BRAM 初始化、串口、时钟、复位、时序或低地址 MMIO 交互出问题

---

## 3. 当前仓库中的板级路径

### 3.1 板级入口

- 顶层：`vivado/src/with_delay/basys3_top.sv`
- SoC 封装：`vivado/src/with_delay/soc_top.sv`
- BRAM 包装：`vivado/src/with_delay/bram_wrapper.sv`
- 设备路径：`vivado/src/device.sv`
- CPU 顶层桥接：`vsrc/mycpu_top.sv`
- CPU 与总线桥：`vsrc/VTop.sv`

### 3.2 当前板级行为的几个关键信息

- `soc_top.sv` 中，板上 CPU 使用 `clk_wiz_0` 生成的 `cpu_clk`
- `clk_wiz_0.xci` 显示 `cpu_clk` 目标频率为 **25 MHz**
- BRAM 包装模块不是理想零延迟内存，而是显式带延迟握手
- `device.sv` 负责：
  - UART 输出
  - 结束标志
  - LED 显示
  - Switch / Counter 等低地址设备读写

这与官方“低地址空间映射外设”的说明是一致的，因此 Lab3 中对 `DifftestInstrCommit.skip` 的 MMIO 跳过处理是必要的。

---

## 4. 已确认必须处理的上板风险

本节只记录已经通过代码检查确认的、不是主观猜测的问题。

### 4.1 `device.sv` 存在 Vivado 不稳定写法

官方上板 Wiki 明确提醒：

- 不要依赖 `initial`
- 不要使用“声明时直接赋值”的风格，例如：
  - `logic [6:0] opcode = instr[6:0];`

检查板级文件时发现 `vivado/src/device.sv` 中原本存在多处类似写法，例如：

- `logic [13:0] bitTmr = '0;`
- `logic txBit = '1;`
- `state_t txState = RDY;`
- `int idx = 14;`

这些写法在 Verilator 下常常没问题，但在 Vivado 中容易导致综合后寄存器上电值不可控，甚至出现 `X` 扩散。

### 4.2 `VTop` 的中断输入原本悬空

`vsrc/mycpu_top.sv` 中实例化 `VTop` 时，`trint`、`swint`、`exint` 原本没有明确绑定。

虽然当前 CPU 并未实际使用这些中断输入，但对综合后的板级设计来说，悬空输入不是良好状态，至少应该显式绑成 `0`。

### 4.3 板级设备 `ready` 需要更精确

`device.sv` 中 UART 状态机会影响设备返回握手。如果把所有低地址设备访问都统一绑定到 UART 是否空闲，可能会造成：

- 某些非串口 MMIO 访问被不必要地阻塞
- 板上“偶发卡住”或“输出不全”的问题更难定位

因此应当把设备 `ready` 收紧到真正需要 UART 回压的地址范围。

---

## 5. 已完成的代码改造

本节记录已经完成的上板适配，不再只是建议。

### 5.1 修复 `device.sv` 的声明初始化问题

已经将 `device.sv` 中依赖声明赋初值的信号，改为：

- 只做声明
- 在 `reset` 分支中显式初始化

同时还把不必要的 `int` 改成了更适合综合的定宽 `logic`。

这一修改的目的是让 Vivado 与 Verilator 看到更一致的时序和寄存器初始化方式。

### 5.2 将仿真打印限制在非综合路径

`device.sv` 中的 `$write` 已包裹在非综合条件下，仅保留仿真时输出，不让综合路径依赖系统任务。

这可以降低 Vivado 综合/实现阶段的干扰。

### 5.3 收紧板级 `ready` 逻辑

已将 `device.sv` 中的 `ready` 逻辑改为：

- 仿真模式下继续直接 `ready`
- 非仿真模式下，仅对 `TX_DATA` 地址真正使用 `tx_ready`
- 其他设备访问直接返回 `ready`

这样做的目的是避免 UART 忙时把无关 MMIO 一起拖住。

### 5.4 显式拉低未使用中断输入

`vsrc/mycpu_top.sv` 中已将：

- `trint`
- `swint`
- `exint`

显式绑定为 `1'b0`。

这属于小改动，但对板级稳定性是正向修正。

---

## 6. 当前判断：是否还需要继续改主功能 RTL

结论是：**当前不建议继续为了“预防上板失败”而盲目修改 Lab3 主功能 RTL。**

理由如下：

1. `make test-lab3` 已经通过
2. 板级路径最明显的 Vivado 兼容性问题已经处理
3. 继续修改 `core.sv` 主语义，反而可能引入新的仿真回归问题

因此更合理的下一步是：

1. 在本地 Vivado 中先跑 `Run behavioral simulation`
2. 再跑 `Run Synthesis`
3. 再看 `Run Implementation`
4. 最后生成 bitstream 并实际下载板卡

如果在这些步骤中暴露新的板级问题，再做定点修改，而不是继续做大范围猜测式改造。

---

## 7. 剩余的主要风险点

虽然当前已完成必要适配，但仍有一些需要重点关注的残余风险。

### 7.1 `device` 与 CPU 不在同一个时钟域

在 `soc_top.sv` 中：

- CPU 使用 `cpu_clk`（25 MHz）
- `device.sv` 仍然接收板上 `clk`

这意味着：

- CPU 总线请求从 `cpu_clk` 域发起
- 板级设备状态机在 `clk` 域里响应

当前代码不一定立刻失败，因为请求通常会保持若干拍，但这仍然是一个潜在 CDC 风险源。若后续出现：

- 串口偶发少字
- 板上偶发卡住
- 同样 bitstream 多次复位行为不完全一致

应优先怀疑这里。

### 7.2 BRAM 初始化或 `.coe` 配置错误

如果 `.coe` 没有正确导入 BRAM IP，即使逻辑正确，也会出现：

- 板上无输出
- PC 跑飞
- 程序早期异常

这类问题与 Lab3 指令实现正确与否并不等价。

### 7.3 复位与串口工具链问题

官方上板 Wiki 提醒：

- 板子复位按钮行为与仿真 reset 不同
- 串口软件、端口选择、板卡连接状态都可能影响结果

因此如果板上完全没输出，不要立刻认定 CPU 有 bug。

### 7.4 时序不过

Lab3 增加了：

- 分支比较
- `jal/jalr`
- `PC` 重定向
- 更丰富的 ALU 运算

如果在实现阶段出现 timing violation，应重点关注：

- `PC` 选择路径
- EX 阶段比较和分支目标计算
- 过多调试信号

---

## 8. 上板时最可能遇到的现象与含义

### 8.1 现象：Vivado 仿真正常，但板上无串口输出

更可能的原因：

- `.coe` 没加载正确
- 串口端口选错
- 板卡未正确下载 bitstream
- 复位没有真正触发
- CPU 根本没写到 `TX_DATA`

优先检查板级接线和 BRAM，不要先怀疑 Lab3 指令。

### 8.2 现象：能输出一部分，但后面卡住

更可能的原因：

- UART `ready` / 回压交互不稳定
- 时钟域问题
- 某次 MMIO 访问与板级设备时序不对齐

### 8.3 现象：LED 没亮，但串口有内容

更可能的原因：

- 没有真正写到 `FINISH_ADDR`
- 板级 LED 接线或 XDC 有问题
- 程序没有执行到 finish 逻辑

### 8.4 现象：Synthesis 过了，Implementation 不过

更可能的原因：

- Timing 违规
- 关键路径过长

此时不应继续盲改外围设备，而应先看 Timing Summary。

---

## 9. 建议的调试顺序

建议严格按下面顺序调试，避免把多个问题混在一起。

### 第一步：Vivado behavioral simulation

先在 Vivado 中运行行为级仿真，看是否能得到与 Verilator 接近的程序行为。

至少建议观察：

- `cpu_clk`
- `pc`
- `valid`
- `addr`
- `wstrobe`
- `ready`
- `last`

如果 Vivado 仿真都异常，那么上板一定异常。

### 第二步：Synthesis

检查：

- Error
- Critical Warning
- Warning

应尽量清理自己代码引入的警告。

### 第三步：Implementation

重点看 Timing Summary，确保关键时序指标为正。

### 第四步：Program Device

按官方流程：

- 打开串口工具
- 下载 bitstream
- 必要时按 `RESET` / `BTNC`
- 观察串口与 LED

---

## 10. 建议抓取的关键信号

如果使用 Vivado 波形或 ILA，建议优先抓以下信号。

### 10.1 板级接口信号

- `soc_top.cpu_clk`
- `mycpu_top.valid`
- `mycpu_top.addr`
- `mycpu_top.wstrobe`
- `mycpu_top.ready`
- `mycpu_top.last`
- `soc_top.ram_valid`
- `soc_top.device_valid`
- `soc_top.tx`

### 10.2 CPU 内部信号

如能继续下钻，建议重点看：

- `core.pc`
- `core.fetch_wait`
- `core.mem_wait`
- 与分支重定向相关的控制信号

### 10.3 各异常现象对应的优先观察项

- **PC 不动**：先看 `reset`、`cpu_clk`、`fetch_wait`
- **PC 在走但没串口**：看 `addr` 是否打到 `0x40600004`
- **串口输出不完整**：看 `ready` 与 `tx_ready`
- **程序似乎结束但 LED 不亮**：看是否写到 `FINISH_ADDR`

---

## 11. 当前已验证的事实

以下结论是有实际依据的：

### 11.1 基线仿真已通过

已实际运行：

```bash
make test-lab3
```

通过结果如下：

```text
AES benchmark + correctness
Running AES correctness checks...
[TEST] AES-128 test vector Encrypt
[PASS] AES-128 test vector Encrypt passed
[TEST] AES-128 test vector Decrypt
[PASS] AES-128 test vector Decrypt passed
[PASS] AES correctness checks passed
[RNG] heavy_rng_mod result=0, time(us)=227606
[RNG] heavy_rng_mod it/s=4405
Core 0: HIT GOOD TRAP at pc = 0x80000030
total guest instructions = 1,243,690
instrCnt = 1,243,690, cycleCnt = 6,596,649, IPC = 0.188534
```

### 11.2 无法在当前环境直接跑 Vivado

当前环境中未检测到 `vivado` 命令，因此：

- 无法在服务端替代你运行 Synthesis / Implementation
- 无法直接生成 bitstream
- 无法直接连接板卡进行 Hardware Manager 验证

因此，Vivado 相关步骤必须在你本地环境中完成。

---

## 12. 最终建议

当前最合理的策略不是继续大幅修改 RTL，而是：

1. 使用当前代码在本地 Vivado 中进行行为仿真
2. 检查 Synthesis 与 Implementation 报告
3. 若无关键警告和 timing 问题，再下载板卡
4. 若出现问题，按本文档第 8 节和第 10 节的顺序调试

简化成一句话就是：

**必要的上板代码适配已经完成，下一步应以 Vivado 真实结果为准进行定点调试，而不是继续猜测性改 RTL。**
