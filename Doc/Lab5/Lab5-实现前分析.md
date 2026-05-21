# 仓库进展与 Lab 5 支持度评估报告

## 1. Lab 1-4 完成情况分析
从仓库的文件结构、规划文档（`.cursor/plans`）以及模块代码来看，当前项目已具备成熟的 CPU 架构与系统集成基础：

- **Lab 1（流水线架构与冒险处理）：[已完成]**
  - **架构实现**：已实现规范的五级流水线划分（IF, ID, EX, MEM, WB）。代码模块化清晰（`core_decode.sv`, `core_alu.sv`, `core_regfile.sv`）。
  - **冒险解决**：通过 `core_forwarding_unit.sv` 和 `core_hazard_unit.sv` 完整支持了数据旁路前推（Forwarding）和停顿控制（Stall），成功解决了基础的数据冒险和控制冒险。
- **Lab 2（存储系统与片上集成）：[已完成]**
  - **外设集成**：在 Vivado 环境中集成了 BRAM 等 IP（`bram_0.xci`, `clk_wiz_0.xci`），并通过封装模块（`bram_wrapper.sv`）完成了存储器对接。
  - **板级支持**：已添加 `Basys-3-Master.xdc` 约束文件，具备在 Basys-3 FPGA 上的综合与上板验证能力。
- **Lab 3（总线架构设计）：[已完成]**
  - **协议实现**：成功设计并实现了自定义 CBus 协议及多路复用与仲裁机制（`CBusArbiter.sv`, `CBusMultiplexer.sv`）。
  - **接口桥接**：实现了指令/数据总线到 CBus（`IBusToCBus.sv`, `DBusToCBus.sv`）以及对外标准 AXI 的桥接转换（`CBusToAXI.sv`），使得 CPU 具备了标准的总线交互能力。
- **Lab 4（仿真与系统级验证）：[已完成]**
  - **验证框架**：通过 `SimTop.sv`、`VTop.sv` 及 Verilator 测试台（`testbench.cpp`、`runner.h` 等），项目建立了一套完整的仿真系统，能够支撑复杂的软硬件协同调试。

## 2. 对 Lab 5 的支持情况分析
参考标准 Lab 5 的要求（核心涉及异常/中断处理、CSR 寄存器管理以及运行简易 OS Kernel），当前仓库不仅结构具备高度可扩展性，且已为 Lab 5 预留了关键的实现基础。

### 🟢 强支撑项 (Ready)

- **CSR 寄存器框架（核心支撑）**：
  - 仓库中已存在 `vsrc/include/csr.sv` 和 `vsrc/src/core_csr.sv`。这意味着控制与状态寄存器的文件结构和模块接口已初步划分，为后续实现特权级模式（Machine Mode）、异常向量表（`mtvec`）、断点保存（`mepc`）等提供了现成载体。
- **内核加载与执行环境**：
  - `ready-to-run/lab5/` 目录下已经备妥了 `kernel.asm` 及其对应的 `.bin`/`.coe` 文件。
  - 得益于 Lab 3 完善的总线架构，这套内核代码可以直接通过已有的 AXI/CBus 接口加载到 BRAM/内存中，外设的 MMIO（内存映射 I/O）寻址逻辑也可直接复用，无需重写访存底层。

### 🟡 需拓展与适配项 (Actionable Development)

- **异常级冲刷机制（Exception Flush）**：
  - 当前的 `core_hazard_unit.sv` 主要聚焦于数据与结构冲突的流水线停顿。为了支持 Lab 5，必须对其逻辑进行扩展：当发生中断/异常，或执行 `ecall`/`mret` 指令时，需要有能力发出 Flush 信号清空 IF、ID 和 EX 阶段，并强制重定向 PC。
- **特权指令译码与 CSR 数据通路**：
  - `core_decode.sv` 中需增加对系统指令（如 `CSRRW`, `CSRRS`, `CSRRC`, `ecall`, `mret`）的识别。同时，流水线中需增加从 ID 段到 CSR 模块，再将 CSR 读取数据前推回寄存器堆或 ALU 的数据通路。
- **外设中断路由机制**：
  - 系统需引入简易中断控制器（例如 Timer 定时器和外部中断引脚的逻辑判定），并将中断信号路由至 CPU 核心的控制单元，触发陷入（Trap）过程。

### 📝 总结
当前 `26-Arch` 仓库底层基础扎实、模块解耦良好。开展 Lab 5 **无需推翻重建**。可以直接在现有的流水线上以增量开发的形式，补全 CSR 读写通路并升级 Hazard Unit 的冲刷逻辑，当前状态已为 Lab 5 提供了极为优越的起点。

---

*Exported from [Voyager](https://github.com/Nagi-ovo/gemini-voyager)*  
*Generated on May 21, 2026 at 09:02 PM*