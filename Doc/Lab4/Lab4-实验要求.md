# Lab 4 — CSR 寄存器实现

> 来源：[GitHub Wiki](https://github.com/26-Arch/26-Arch/wiki/Lab-4) · [eLearning 作业页](https://elearning.fudan.edu.cn/courses/110019/assignments/129972)
> 截止日期：**2026-05-09 23:59**

## 一、实验目标

实现 RISC-V CSR（Control and Status Register）相关的 6 条指令和 11 个寄存器，并连接到 Difftest 进行正确性验证。

## 二、需要实现的指令

| 指令 | 说明 |
|------|------|
| CSRRW | 原子读-写 CSR |
| CSRRS | 原子读-置位 CSR |
| CSRRC | 原子读-清位 CSR |
| CSRRWI | CSRRW 的立即数版本 |
| CSRRSI | CSRRS 的立即数版本 |
| CSRRCI | CSRRC 的立即数版本 |

## 三、需要实现的 CSR 寄存器

所有寄存器均为 **64 位宽**：

| 寄存器 | 说明 |
|--------|------|
| mstatus | 机器模式状态寄存器 |
| mtvec | 机器模式 trap 向量基地址 |
| mip | 机器模式中断待处理 |
| mie | 机器模式中断使能 |
| mscratch | 机器模式临时寄存器 |
| mcause | 机器模式 trap 原因 |
| mtval | 机器模式 trap 值 |
| mepc | 机器模式异常 PC |
| mcycle | CPU 已运行时钟周期数 |
| mhartid | CPU 核心编号（单核恒为 0） |
| satp | 地址转换和保护 |

### 特殊说明

- **mcycle**：每周期自动加一，溢出则从 0 重新开始；支持写入覆盖。
- **mhartid**：当前只有单核，恒为 0，**不需要考虑写入**。
- **sstatus**：是 mstatus 中部分位的抽象，不需要单独存储物理寄存器，DifftestCSRState 中连接为 `mstatus & SSTATUS_MASK`。

### Difftest 连接

- 上述寄存器需要对应连接到 `DifftestCSRState`（DifftestCSRState 中没有的寄存器不需要连接）。
- `core.sv` 中 `DifftestInstrCommit`、`DifftestArchIntRegState`、`DifftestTrapEvent` 和 `DifftestCSRState` 的 `coreid` 都连接为 `mhartid[7:0]`。

## 四、CSR 寄存器的读写特性

CSR 与普通寄存器的一大区别：**一些 CSR 寄存器并非每一位都可写**。

- 例如 `mip` 寄存器 64 位宽，但在实验设定下只有 `[0][1][4][5][8][9]` 这 6 位允许读写，其余位禁止写入，读取时恒为 0。
- `vsrc/include/csr.sv` 中提供了部分 mask，表示对应寄存器允许写入的位。如果没有提供 mask，则说明该寄存器每一位都可写。

使用示例：

```systemverilog
unique case (csr_op)
  WRITE: begin
    unique case (csr_id)
      CSR_MIE:  regs.mie = csr_write_data;
      CSR_MIP:  regs.mip = csr_write_data & MIP_MASK;
      // ......
    endcase
  endcase
```

## 五、流水线处理

CSR 指令**不应该转发**，每次 CSR 改变都应**刷新流水线**（从 `pc + 4` 继续执行）。

> **Hint**：对于使用静态分支预测的方案，可以认为 CSR 指令同时是一个"跳转到 pc+4"的跳转指令，并永远分支预测失败，从而复用跳转指令的气泡/冲刷逻辑。

## 六、测试与验证

```bash
make test-lab4
```

输出中看到 **HIT GOOD TRAP** 即为测试通过。

### 波形调试

```bash
# 生成波形
make test-lab4 VOPT="--dump-wave"

# 截取指定范围波形
make test-lab4 VOPT="--dump-wave -b <begin> -e <end>"
```

波形文件位于 `build/` 目录下，使用 `gtkwave` 打开。

## 七、Bonus

1. **参考英文指令集手册，简述本次 Lab 中各个 CSR 寄存器的作用。**
2. **实现 `csr.sv` 给定的所有寄存器，包括 S 模式寄存器**（如 `stvec` 等）。
3. **思考为什么 CSR 写入后一定要刷新流水线？**

## 八、提交要求

### 提交内容

- 包含代码和报告的 **zip 压缩包**
- 实验报告为 **PDF 格式**
- 报告中应包含 **Vivado 上板输出**

### 打包方式

```bash
# 在主目录下新建 docs 文件夹
mkdir -p docs
# 将报告放入其中并命名为 report.pdf
cp report.pdf docs/
# 运行打包命令
make handin
```

生成的 zip 文件位于 `docs/` 目录下，**直接提交且仅提交这个 zip 文件**。

### 提交信息

- **提交平台**：eLearning
- **截止日期**：2026-05-09 23:59
- 迟交会扣除部分分数，代码无法运行可能被扣除大部分分数
- 代码/报告抄袭将导致该次实验零分

## 九、背景知识

CSR 寄存器为特权架构服务，本次实验只需支持这些寄存器及其读写指令。本次 Lab **不会切换 CPU 状态**（CPU 一直在 M 模式），也不会真正触发中断和异常（尚未实现 `mret` 和 `ecall`），但需要正确实现寄存器的读写指令并连接 Difftest。

各 CSR 寄存器的具体含义可参考：
- RISC-V 英文指令集手册
- `vsrc/include/csr.sv`（包含各寄存器的编号）
