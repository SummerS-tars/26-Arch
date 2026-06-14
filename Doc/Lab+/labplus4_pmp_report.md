# Lab+4 PMP 权限检查报告

## 任务目标

本任务将原先“只支持 `pmpaddr0/pmpcfg0` CSR 基本读写”的状态，推进到 PMP 真正参与取指和访存权限判断。

本轮实现范围保持为 Lab+4 当前测试所需的最小闭环：

- 支持 `pmpaddr0` + `pmpcfg0[7:0]` 的 entry0。
- 支持 NAPOT 区域匹配。
- 支持 R/W/X 权限检查。
- PMP 仅约束 U/S-mode；M-mode 默认不受限。
- 暂不实现 TOR、NA4、多个 PMP entry、L-bit 锁定语义。

## 实现内容

### Access Fault Cause

在 `trap_pkg` 中补齐三类 access fault cause：

- instruction access fault：`mcause = 1`
- load access fault：`mcause = 5`
- store/AMO access fault：`mcause = 7`

异常仍沿用现有 WB 阶段 trap 提交流程，因此 `mepc`、`mcause`、`mtval` 的写入时序与已有 illegal/misaligned/ecall/mret 路径保持一致。

### CSR 导出

`core_csr.sv` 原本已经保存 `pmpaddr0_q` 和 `pmpcfg0_q`，本任务新增导出口：

- `pmpaddr0`
- `pmpcfg0`

`core.sv` 直接使用这两个 CSR 值参与 PMP 权限判断。

### NAPOT 匹配

`core.sv` 中新增 PMP helper：

- 统计 `pmpaddr0` 低位连续 `1`，得到 NAPOT 区域掩码。
- 用物理地址 `addr[63:2]` 与 `pmpaddr0` 按掩码比较。
- 仅当 `pmpcfg0[4:3] == 2'b11` 时认为 entry0 处于 NAPOT 模式。

Lab+4 初始化中使用的配置形式是：

- `pmpaddr0 = (user_text_begin >> 2) | 0x1ff`
- `pmpcfg0 = 31/30/29/27`

这些值分别覆盖测试用户段附近的 NAPOT 区域，并切换 RWX、不可读、不可写、不可执行权限组合。

### 取指检查

IF 阶段对当前 `pc` 做 X 权限检查。

若 U/S-mode 取指地址命中 PMP entry0 且 X 权限关闭：

- 不发起 IBus 请求。
- 在 IF/ID 中合成一条有效异常。
- 进入 ID/EX 后设置：
  - `exception_valid = 1`
  - `exception_cause = CAUSE_INST_ACCESS`
  - `exception_tval = pc`

这样可以复用现有流水线异常提交路径。

### 访存检查

EX 阶段在 ALU 计算出访存地址后检查 R/W 权限。

- load 或 `lr.w` 无 R 权限时产生 load access fault。
- store、`sc.w`、AMO RMW 无 W 权限时产生 store/AMO access fault。
- AMO RMW 同时要求 R/W 权限；若任一权限不满足，按 store/AMO access fault 处理。

由于 `regular_mem_access_mem` 和 `amo_access_mem` 已经要求 `!exception_valid`，PMP 违规指令不会继续向 DBus 发起真实访存请求。

## 验证结果

### 构建

`make sim` 通过。

### Lab+4

使用显式 cycle cap 运行：

```text
TEST=all ./build/emu --no-diff -i ./ready-to-run/lab+/4/all-test-privfull.bin -C 80000000 --force-dump-result
```

结果：

- 前置特权/PMP 子测通过，输出 `Single test passed.`。
- 默认延迟下已继续跑过 paint、compress、coremark，进入 dhrystone。
- `DELAY=0` 重建后，80M cycle cap 内已继续跑过 paint、compress、coremark、dhrystone、stream，停在 conway 后续负载。
- 未再出现任务 0 基线中的早期 `pc = 0x0` 卡死。

说明：当前 Lab+4 的 PMP/access fault 阻塞已解除；完整跑完全部后续 benchmark 仍受性能和 cycle cap 影响。

### 回归

使用 `DELAY=0` 构建后的模拟器运行关键回归：

- Lab+3：通过，`HIT GOOD TRAP at pc = 0x800000dc`。
- Lab4：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
- Lab5：输出 `Return from init! Test passed`。
- Lab6：输出 `Privileged test finished.` / `Exit with code = 0`。

Lab6 使用显式 `-C 8000000 --force-dump-result`，避免测试成功后继续占住终端。

## 当前边界

本任务只实现 Lab+4 当前测试所需的 PMP 最小集合。尚未支持：

- 多个 PMP entry。
- TOR / NA4 模式。
- L-bit 锁定后对 M-mode 的约束。
- PMP 与 page fault/MMU fault 的完整优先级组合。

下一步若继续推进异常完整性，建议进入任务 9：MMU page fault。
