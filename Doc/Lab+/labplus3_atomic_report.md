# Lab+3：原子指令最小集合记录

## 要求

- 来源：Lab+3 `ready-to-run/lab+/3/atomicity.bin`。
- 目标：优先通过 `atomicity.S` 中实际出现的原子指令。
- 覆盖指令：
  - `amoswap.w`
  - `amoadd.w`
  - `lr.w`
  - `sc.w`

## 实现内容

### 译码

在 `vsrc/src/core_decode.sv` 中增加 AMO opcode `7'b0101111` 的最小译码。

当前只接受 `funct3 = 3'b010` 的 32-bit W 指令：

- `funct5 = 5'b00000`：`amoadd.w`
- `funct5 = 5'b00001`：`amoswap.w`
- `funct5 = 5'b00010`：`lr.w`
- `funct5 = 5'b00011`：`sc.w`

`aq/rl` 位暂按无额外行为处理。未实现的 AMO 编码保持 illegal，避免静默当成 NOP。

### 流水线与访存

在 `vsrc/include/common.sv` 中增加 AMO 元信息，并随 ID/EX、EX/MEM、MEM/WB 传递。

在 `vsrc/src/core.sv` 中实现：

- `amoswap.w` / `amoadd.w`：
  - MEM 阶段先发起 word load，取得旧值。
  - 根据旧值和 `rs2` 计算新值。
  - 再发起 word store 写回新值。
  - 写回 `rd` 的是旧 word 的符号扩展结果。
- `lr.w`：
  - 执行 word load。
  - 写回旧 word 的符号扩展结果。
  - 记录 word 粒度 reservation address。
- `sc.w`：
  - reservation 命中时执行 word store，写回 `rd = 0`。
  - reservation 未命中时不写内存，写回 `rd = 1`。
  - 每次 `sc.w` 后清除 reservation。

AMO RMW 期间通过 `mem_wait` 冻结流水线，避免中间读写状态被前端或后续指令打断。

### Difftest

在 `vsrc/src/core_difftest_adapter.sv` 中接入 `DifftestInstrCommit.scFailed`。

当前没有接入 `DifftestAtomicEvent`。本仓库当前单核 Lab+3 测试中，参考模型正常执行 AMO/LR/SC 指令即可保持寄存器和内存一致；`scFailed` 接入用于 SC 失败时同步参考模型 LR/SC 微结构状态。

## 验证结果

### Lab+3

命令：

```bash
make test-labplus-3
```

关键输出：

```text
The first instruction of core 0 has commited. Difftest enabled.
Core 0: HIT GOOD TRAP at pc = 0x800000dc
instrCnt = 55, cycleCnt = 270, IPC = 0.203704
```

结果：通过。

### 主线回归

已验证：

- `make sim`：构建通过。
- `make test-lab4`：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
- `timeout 45s make test-lab5 || true`：输出 `Return from init! Test passed`。
- `make test-lab6`：输出 `Privileged test finished.` / `Exit with code = 0`；命令随后被用户中断，但成功标志已出现。

说明：曾并行运行 `make test-lab4` 和 `timeout 45s make test-lab5 || true`，两个命令同时重建 `build/emu`，导致一次构建目录竞争和链接错误。随后已按顺序重跑 Lab4/Lab5 并通过。

## 未完成内容

- 未实现完整 32-bit AMO：
  - `amoxor.w`
  - `amoand.w`
  - `amoor.w`
  - `amomin.w` / `amomax.w`
  - `amominu.w` / `amomaxu.w`
- 未实现 64-bit AMO D 指令。
- 未接入 `DifftestAtomicEvent`。
- 未做多核或外部写入导致 reservation 失效的完整一致性处理。

## 结论

Lab+3 当前测试所需的原子指令最小集合已经完成，`atomicity.bin` 通过 Difftest。后续若继续补原子相关 Bonus，可做任务 7 的完整 32-bit AMO；若按 Lab+ 测试推进优先级，下一步更建议进入 Lab+4 的 PMP/access fault。
