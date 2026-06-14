# Lab+2：简单分支预测记录

## 要求

- 来源：Lab+ 官方 Bonus 中的“简单性能优化”。
- 目标：在任务 4 的性能统计基础上，加入低风险分支预测，并用 microbench 采样对比效果。

## 实现内容

本阶段实现静态方向预测：

- backward branch 预测 taken。
- forward branch 预测 not taken。
- 预测仅作用于条件分支。
- 预测目标在 ID 阶段由 `pc_id + imm_id` 计算。
- EX 阶段重新计算真实分支结果，若预测 next PC 与真实 next PC 不一致，则触发 redirect 并 flush 前端。

当前暂未实现：

- BHT 两位饱和计数器。
- BTB 目标缓存。
- RAS。
- `jal` / `jalr` 的提前重定向。

## RTL 改动

- `vsrc/include/common.sv`
  - 在 `id_ex_t` 中加入 `pred_taken` 和 `pred_target`。
- `vsrc/src/core.sv`
  - PC 选择增加 ID 阶段预测重定向路径。
  - IF/ID 在预测 taken 时 flush 掉已取到的顺序下一条。
  - ID/EX 保存预测信息。
  - EX 阶段只在 branch 预测错误时触发 branch redirect。
  - Verilator 性能统计增加：
    - `pred_taken`
    - `pred_ok`
    - `pred_miss`
    - `id_redirects`

## 采样结果

采样命令：

```bash
make sim BENCHMARK=1
timeout 90s env TEST= ./build/emu --diff ./ready-to-run/riscv64-nemu-interpreter-so -i ./ready-to-run/lab+/2/microbench-riscv64-nutshell.bin -C 50000000 --force-dump-result
```

关键输出：

```text
[perf] cycles=49999999 instr=9505052 ipc_x1000=190 branches=1185033 taken=944374 nt_pred_ok=240659 pred_taken=660496 pred_ok=869083 pred_miss=315950 jumps=418827 jalr=209398 id_redirects=660496 ex_redirects=734777 system_redirects=0 load_use_stalls=231 fetch_waits=30956130 mem_waits=5408074
Core 0: EXCEEDING CYCLE/INSTR LIMIT at pc = 0x0
instrCnt = 9,505,052, cycleCnt = 49,999,999, IPC = 0.190101
```

该采样窗口内未出现 Difftest mismatch，结束原因是显式 50M cycle 上限。

## 与任务 4 基线对比

- `instr`：从 `9,099,437` 提升到 `9,505,052`，提升约 4.46%。
- `IPC`：从 `0.181989` 提升到 `0.190101`，提升约 4.46%。
- 分支预测正确率：`869,083 / 1,185,033`，约 73.3%。
- `ex_redirects`：从 `1,313,944` 降到 `734,777`，下降约 44.1%。

## 验证

已验证：

- `make sim`：构建通过。
- `make test-lab4`：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
- Lab+2 50M cycle 采样：无 Difftest mismatch，达到 cycle cap。
- `timeout 45s make test-lab5 || true`：输出 `Return from init! Test passed`。
- `make test-lab6`：输出 `Privileged test finished.` / `Exit with code = 0`。

说明：第一次并行运行 `make test-lab4` 与 `make sim BENCHMARK=1` 时出现过 `Text file busy`，因为两个命令同时写同一个 `build/emu`。随后已按顺序重跑 `make test-lab4` 并通过。

## 结论

静态 backward-taken / forward-not-taken 对 Lab+2 microbench 有可见收益，主要体现在 EX 阶段控制流重定向明显减少。当前收益约为 4.46% IPC 提升，说明后续若继续优化性能，可以考虑 BHT/BTB；但从 Lab+ 整体推进看，下一步更建议转向 Lab+3 的 A 扩展最小集合。
