# Lab+3：完整 32-bit AMO 扩展记录

## 要求

- 来源：Lab+ Bonus 中的原子指令扩展方向。
- 目标：在任务 6 已通过 `atomicity.bin` 的基础上，补全 32-bit AMO RMW 指令。
- 本阶段只扩展 W 指令，不实现 64-bit AMO D 指令。

## 实现内容

任务 6 已实现：

- `amoswap.w`
- `amoadd.w`
- `lr.w`
- `sc.w`

本阶段新增：

- `amoxor.w`
- `amoand.w`
- `amoor.w`
- `amomin.w`
- `amomax.w`
- `amominu.w`
- `amomaxu.w`

`aq/rl` 位继续按无额外行为处理。

## RTL 改动

- `vsrc/include/common.sv`
  - 扩展 `amo_op_t`，加入 `AMO_XOR`、`AMO_AND`、`AMO_OR`、`AMO_MIN`、`AMO_MAX`、`AMO_MINU`、`AMO_MAXU`。
- `vsrc/src/core_decode.sv`
  - 补全 AMO opcode `7'b0101111` 下对应 `funct5` 的 W 指令译码。
- `vsrc/src/core.sv`
  - 复用任务 6 的 MEM 阶段两步 RMW 框架。
  - 在 `amo_new_word_mem` 计算中加入 xor/and/or/signed min/signed max/unsigned min/unsigned max。
  - 写回仍为旧 word 的 RV64 符号扩展结果。

## 自测输入

由于当前环境未发现 RISC-V 汇编器，本阶段加入一个 Python 生成器直接输出机器码：

- `ready-to-run/lab+/3/gen_atomic_full_w_test.py`
- `ready-to-run/lab+/3/atomic_full_w.bin`
- `ready-to-run/lab+/3/atomic_full_w.S`

自测覆盖 9 条 32-bit AMO RMW 指令：

- `amoswap.w`
- `amoadd.w`
- `amoxor.w`
- `amoand.w`
- `amoor.w`
- `amomin.w`
- `amomax.w`
- `amominu.w`
- `amomaxu.w`

每条测试都会检查：

- `rd` 写回的旧 word 符号扩展结果。
- 内存中的新 word 符号扩展读回结果。

说明：第一次自测曾把 scratch word 放在 `0x80000100`，覆盖了后续测试代码；已改为 `0x80000700` 后通过。

## 验证

### 完整 AMO W 自测

命令：

```bash
python3 ready-to-run/lab+/3/gen_atomic_full_w_test.py
TEST= ./build/emu --diff ./ready-to-run/riscv64-nemu-interpreter-so -i ./ready-to-run/lab+/3/atomic_full_w.bin
```

关键输出：

```text
The first instruction of core 0 has commited. Difftest enabled.
Core 0: HIT GOOD TRAP at pc = 0x800001c4
instrCnt = 113, cycleCnt = 573, IPC = 0.197208
```

### 原有 Lab+3

命令：

```bash
make test-labplus-3
```

关键输出：

```text
Core 0: HIT GOOD TRAP at pc = 0x800000dc
instrCnt = 55, cycleCnt = 270, IPC = 0.203704
```

### 主线回归

已验证：

- `make sim`：构建通过。
- `make test-lab4`：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
- `timeout 45s make test-lab5 || true`：输出 `Return from init! Test passed`。
- `make test-lab6`：输出 `Privileged test finished.` / `Exit with code = 0`；命令随后被用户中断，但成功标志已出现。

## 未完成内容

- 未实现 64-bit AMO D 指令。
- 未接入 `DifftestAtomicEvent`。
- 未实现多核或外部写入导致 reservation 失效的完整一致性处理。

## 结论

完整 32-bit AMO RMW 指令已经补齐，并通过新增裸机自测和原有 Lab+3 测试。后续若继续推进 Lab+，更建议转向 Lab+4 的 PMP/access fault。
