# Lab+2：microbench 正确性基线记录

## 要求

- 来源：Lab+ 官方 Bonus 中的“简单性能优化”。
- 测试目标：`make test-labplus-2`。
- 官方方向：通过 `microbench` 对比优化前后的性能表现，后续可实现分支预测、cache 等优化。

本文件只记录“先让 microbench 正确跑起来”的阶段性工作。性能统计和分支预测留给后续任务。

## 实现基础

当前 CPU 已具备：

- 五级流水线。
- 基础 forwarding / hazard 处理。
- UART、CLINT timer 等仿真 MMIO。
- RV64M 乘除法支持。
- Lab1 extra、Lab4、Lab5、Lab6 回归通过。

在实现 RV64M 之前，Lab+2 会在 `mulw` 处出现 Difftest mismatch：

- `pc = 0x80000bc4`
- `a5` 期望 `0x343fd`
- 实际 `0x343fe`

该失败点说明 microbench 的正确运行依赖 M 扩展。

## 当前处理

本阶段没有引入分支预测或 cache，只做两件事：

1. 补齐 RV64M，使 microbench 不再因为 `mulw/div/rem` 等指令语义错误而失败。
2. 用 Difftest 运行 Lab+2，确认程序能持续推进并通过已有 benchmark。

为了区分“正确性失败”和“运行太慢”，额外使用了 `DELAY=0` 重建仿真器。该参数只关闭仿真 RAM 的随机等待，不改变 CPU RTL 功能。

## 验证结果

### 默认随机延迟

运行命令：

```bash
timeout 600s env TEST= ./build/emu --diff ./ready-to-run/riscv64-nemu-interpreter-so -i ./ready-to-run/lab+/2/microbench-riscv64-nutshell.bin
```

结果：

- 未出现 Difftest mismatch。
- `qsort` 通过。
- `queen` 通过。
- 停在 `bf`，由 600 秒 wall timeout 结束。

关键输出：

```text
[qsort] Quick sort: * Passed.
[queen] Queen placement: * Passed.
[bf] Brainf**k interpreter:
```

### 零随机延迟

构建命令：

```bash
make sim DELAY=0
```

运行命令：

```bash
timeout 600s env TEST= ./build/emu --diff ./ready-to-run/riscv64-nemu-interpreter-so -i ./ready-to-run/lab+/2/microbench-riscv64-nutshell.bin
```

结果：

- 未出现 Difftest mismatch。
- `qsort` 通过。
- `queen` 通过。
- `bf` 通过。
- 停在 `fib`，由 600 秒 wall timeout 结束。

关键输出：

```text
[qsort] Quick sort: * Passed.
  min time: 3 ms [170466]
[queen] Queen placement: * Passed.
  min time: 4 ms [117675]
[bf] Brainf**k interpreter: * Passed.
  min time: 28 ms [84546]
[fib] Fibonacci number:
```

## 结论

Lab+2 的首个正确性阻塞已经清除。microbench 能在 Difftest 下持续运行，并连续通过多个 benchmark。

当前尚未完整跑完 `ref` 输入，主要原因是现有 CPU 没有分支预测、cache 等性能优化，运行时间过长。后续应进入性能统计和简单分支预测任务，而不是继续把性能问题归入本阶段。
