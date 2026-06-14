# Lab+ Cache / 性能优化实现报告

## 目标

任务 12 的目标是尝试 cache 或更复杂性能优化。结合当前仓库状态，本轮选择风险最低、收益最直接的方案：

- 实现只读 I-cache。
- 插入在 MMU 之后、RAMHelper 之前，使用物理地址索引/标记。
- 只缓存 `MEM_ACCESS_FETCH` 请求。
- load/store、AMO、页表遍历和 MMIO 全部 bypass。
- 暂不实现 D-cache、复杂预取和完整 `fence.i` 语义。

这样可以优先降低 `fetch_waits`，同时避免 D-cache 对 store、MMIO、AMO、LR/SC 和一致性带来的高风险。

## 实现内容

### I-cache 模块

新增 `vsrc/util/ICache.sv`：

- 直接映射结构。
- 默认 128 行，每行缓存一个 64-bit RAM word。
- tag/index 使用物理地址。
- 命中时直接返回 cached word。
- miss 时向下游 RAMHelper 透传请求，并在响应返回时填充 cache。
- 仅当请求满足以下条件才缓存：
  - `valid = 1`
  - `is_write = 0`
  - `access == MEM_ACCESS_FETCH`
  - 地址位 `addr[31] = 1`，即当前 RAM 区间。
- 其他请求全部直通：
  - load/store
  - AMO
  - MMIO
  - MMU 页表 walk

### 顶层接入

在 `vsrc/SimTop.sv` 和 `vsrc/VTop.sv` 中，将原路径：

```text
MMU -> RAMHelper / 外部 CBus
```

改为：

```text
MMU -> ICache -> RAMHelper / 外部 CBus
```

I-cache 在 `satp` 或特权级变化时 flush。虽然当前实现是物理 I-cache，原则上不依赖虚拟地址 tag，但在任务 12 的安全边界下，遇到地址空间或特权上下文切换时全清可以减少页表/权限变化后的隐患。

## 为什么不做 D-cache

D-cache 会引入明显更高的正确性风险：

- store 写策略与写缓冲。
- MMIO 必须严格 bypass。
- AMO RMW 两阶段需要和 cache 一致。
- LR/SC reservation 与 cache 命中/写回交互复杂。
- page fault、access fault 与 cache miss/fill 需要对齐提交边界。
- 未来若支持 `fence.i`，还要处理 I/D 一致性。

当前性能计数显示取指等待是更大的瓶颈，因此先做 I-cache 更适合本仓库当前阶段。

## 验证

### 构建与静态检查

- `ReadLints`：未发现新增诊断。
- `make sim`：构建通过。

### 功能回归

- Lab4：
  - `HIT GOOD TRAP at pc = 0x8001fff8`
  - `cycleCnt = 124,690`
- Lab5：
  - `Return from init! Test passed`
  - 后续在显式 cycle cap 下停止，符合既有现象。
- Lab5 extra：
  - `HIT GOOD TRAP at pc = 0x800002b4`
- Lab6：
  - `Single test passed.`
  - `Privileged test finished.`
  - `Exit with code = 0`
- Lab+3：
  - `HIT GOOD TRAP at pc = 0x800000dc`
- Lab+4：
  - 前置 privileged/PMP 子测仍输出 `Single test passed.`
  - 80M-cycle cap 下可继续跑过 paint、CoreMark、Dhrystone，并进入 stream。

### 性能样本

命令：

```bash
make sim BENCHMARK=1
TEST= ./build/emu --diff ./ready-to-run/riscv64-nemu-interpreter-so \
  -i ./ready-to-run/lab+/2/microbench-riscv64-nutshell.bin \
  -C 50000000 --force-dump-result
```

50M-cycle 样本关键输出：

```text
[perf] cycles=49999999 instr=15355980 ipc_x1000=307 ... fetch_waits=18538887 mem_waits=9399151
EXCEEDING CYCLE/INSTR LIMIT at pc = 0x80002008
```

与此前状态快照中的 50M-cycle 样本相比：

- IPC 从约 `0.190` 提升到约 `0.307`。
- `fetch_waits` 从约 `31.2M / 50M` 降到约 `18.5M / 50M`。

该结果说明 I-cache 对当前 microbench 的取指等待有明显改善。

## 边界

- 当前 I-cache line 为 64-bit word，不是 64B cache line；实现更简单、风险更低，但空间局部性收益有限。
- 暂未实现 prefetch。
- 暂未实现 D-cache。
- 暂未实现完整 `fence.i` 语义。
- 当前 flush 采用保守策略：`satp` 或特权级变化时全清。

## 结论

任务 12 已完成一个可验证的最小 I-cache 性能优化。它保持了 Lab4/Lab5/Lab6/Lab+3/Lab+4 的功能边界，并在 Lab+2 microbench 50M-cycle 样本中显著降低 `fetch_waits`、提升 IPC。后续若继续优化，可以在此基础上扩展更大的 cache line、顺序 prefetch 或更完整的 cache 性能计数；D-cache 建议继续后置。
