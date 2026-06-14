# Lab1 Extra：乘除法实现记录

## 要求

- 来源：Lab+ “之前的 Bonus 列表”中的“任意 Lab 完成：乘除法”。
- 评定方式：通过 `lab1-extra` 测试。
- 目标：在现有 RV64I 基础上补齐整数乘除法指令，使 CPU 支持 RV64M 中本项目测试涉及的乘除法语义。

## 实现基础

实现前 CPU 已有：

- 五级流水线基础数据通路。
- `core_decode.sv` 负责指令译码。
- `core_alu.sv` 负责 ALU 组合运算。
- `common.sv` 中统一定义 `alu_op_t`。
- Lab4/Lab5/Lab6 主线功能已通过既有回归。

这次实现没有改流水线结构，只是在译码和 ALU 运算集合中扩展 M 扩展指令。

## 实现内容

本次补齐了 RV64M 整数乘除法：

- 64 位指令：
  - `mul`
  - `mulh`
  - `mulhsu`
  - `mulhu`
  - `div`
  - `divu`
  - `rem`
  - `remu`
- 32 位 W 指令：
  - `mulw`
  - `divw`
  - `divuw`
  - `remw`
  - `remuw`

主要修改：

- `vsrc/include/common.sv`
  - 扩展 `alu_op_t`，加入 M 扩展对应 ALU 操作。
- `vsrc/src/core_decode.sv`
  - 在 R-type / R-type W 指令中识别 `funct7 = 7'b0000001`。
  - 按 `funct3` 区分具体乘除法指令。
- `vsrc/src/core_alu.sv`
  - 实现乘法低位、高位、有符号/无符号组合。
  - 实现有符号/无符号除法和取余。
  - 处理除零、`INT_MIN / -1` 溢出、W 指令结果符号扩展。

## 实现思路

M 扩展仍作为普通 ALU 类指令处理：

1. 译码阶段识别 `opcode = 0110011` 或 `0111011`。
2. 若 `funct7 = 0000001`，进入 M 扩展译码分支。
3. EX 阶段由 `core_alu.sv` 组合计算结果。
4. 后续沿用原有 WB 路径写回通用寄存器。

这样做的好处是改动范围小，不影响访存、CSR、trap 和 Difftest 提交流程。

## 边界语义

已按 RISC-V M 扩展常见语义处理：

- 除数为 0：
  - `div/divu/divw/divuw` 返回全 1。
  - `rem/remu/remw/remuw` 返回被除数。
- 有符号溢出：
  - `INT_MIN / -1` 返回 `INT_MIN`。
  - `INT_MIN % -1` 返回 0。
- W 指令：
  - 只使用低 32 位参与运算。
  - 结果按 32 位符号扩展到 64 位。

## 验证结果

已运行：

```bash
make sim
```

结果：通过。

已运行 Lab1 extra：

```bash
./build/emu --diff ./ready-to-run/riscv64-nemu-interpreter-so -i ./ready-to-run/lab1/lab1-extra-test.bin
```

结果：通过。

关键输出：

```text
Core 0: HIT GOOD TRAP at pc = 0x8002001c
```

已运行主线回归：

- Lab4：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
- Lab5：通过，输出 `Return from init! Test passed`。
- Lab6：通过，输出 `Privileged test finished.` / `Exit with code = 0`。

已运行 Lab+2 初步验证：

```bash
./build/emu --diff ./ready-to-run/riscv64-nemu-interpreter-so -i ./ready-to-run/lab+/2/microbench-riscv64-nutshell.bin
```

结果：已越过原先 `mulw` mismatch，`qsort` 显示通过；后续在 `queen` 阶段因 90 秒 wall timeout 停止，留待后续 Lab+2 microbench 任务继续分析。

## 当前结论

乘除法 Bonus 已完成。后续 Lab+ 主报告可以将本文件内容汇总到“任意 Lab：乘除法”条目中。
