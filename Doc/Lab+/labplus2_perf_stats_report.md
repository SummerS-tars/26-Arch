# Lab+2：轻量性能统计记录

## 要求

- 来源：Lab+ 官方 Bonus 中的“简单性能优化”。
- 目标：为后续分支预测、cache 等优化提供可解释的基线数据。
- 本阶段只做统计，不引入真正的分支预测或 cache。

## 实现内容

在 `vsrc/src/core.sv` 中加入 Verilator 仿真期性能计数器。

统计项包括：

- `cycles`：运行周期数。
- `instr`：提交指令数。
- `ipc_x1000`：放大 1000 倍的 IPC。
- `branches`：进入 EX 并被处理的分支指令数。
- `taken`：实际跳转的分支数。
- `nt_pred_ok`：默认“不跳转预测”下方向预测正确的分支数。
- `jumps`：`jal` / `jalr` 总数。
- `jalr`：间接跳转数量。
- `ex_redirects`：EX 阶段控制流重定向次数。
- `system_redirects`：trap / `mret` 等系统级重定向次数。
- `load_use_stalls`：load-use 冒险停顿次数。
- `fetch_waits`：取指等待次数。
- `mem_waits`：数据访存等待次数。

统计逻辑只在 Verilator 路径下编译，并且由 `BENCHMARK` 宏控制输出。默认 `make sim` 不打印统计信息。

## 启用方式

构建带统计输出的仿真器：

```bash
make sim BENCHMARK=1
```

运行 Lab+2：

```bash
./build/emu --diff ./ready-to-run/riscv64-nemu-interpreter-so -i ./ready-to-run/lab+/2/microbench-riscv64-nutshell.bin
```

统计信息每 10,000,000 cycle 打印一次，格式示例：

```text
[perf] cycles=9999999 instr=1839173 ipc_x1000=183 branches=93883 taken=93497 nt_pred_ok=386 jumps=173443 jalr=86711 ex_redirects=266940 system_redirects=0 load_use_stalls=229 fetch_waits=6332094 mem_waits=941543
```

## 采样结果

使用固定 50,000,000 cycle 窗口采样：

```bash
timeout 90s env TEST= ./build/emu --diff ./ready-to-run/riscv64-nemu-interpreter-so -i ./ready-to-run/lab+/2/microbench-riscv64-nutshell.bin -C 50000000 --force-dump-result
```

关键输出：

```text
[perf] cycles=49999999 instr=9099437 ipc_x1000=181 branches=1116352 taken=898155 nt_pred_ok=218197 jumps=415789 jalr=207881 ex_redirects=1313944 system_redirects=0 load_use_stalls=233 fetch_waits=31247451 mem_waits=5116753
Core 0: EXCEEDING CYCLE/INSTR LIMIT at pc = 0x80002034
instrCnt = 9,099,437, cycleCnt = 49,999,999, IPC = 0.181989
```

## 分析

从 50M cycle 采样看：

- IPC 约为 0.182，整体效率较低。
- `fetch_waits` 约 31.25M，占周期比例很高，说明取指等待是主要性能开销之一。
- `mem_waits` 约 5.12M，数据访存等待也较明显。
- 分支总数约 1.12M，其中 taken 约 0.90M。
- 默认“不跳转预测”的分支方向正确数约 0.22M，方向正确率约 19.5%。
- `ex_redirects` 约 1.31M，说明控制流重定向非常频繁。

这些数据说明：后续分支预测很有价值。仅采用默认“不跳转预测”时，大量 taken branch 会在 EX 阶段触发 redirect 和 flush，带来明显控制冒险开销。

## 验证

已验证：

- `make sim BENCHMARK=1`：构建通过。
- Lab+2 50M cycle 采样：能输出统计信息，未出现 Difftest mismatch。
- 普通 `make sim`：构建通过，默认不输出统计信息。
- Lab4 默认回归：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。

## 结论

轻量性能统计已完成。下一步可以基于这些数据实现简单分支预测，并比较优化前后的 `ipc_x1000`、分支方向命中率和 `ex_redirects` 变化。
