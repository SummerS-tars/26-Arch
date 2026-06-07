# 26-Arch 渐进式重构 TODO

> 目标：在已经通过 Lab6 的基础上，小步整理架构，为后续 lab+ 内容降低修改风险。  
> 原则：每一步都保持功能等价；每完成一小步就跑回归，不把重构和新功能混在同一个提交里。

## 0. 重构前基线

- [ ] 确认当前代码已经通过 Lab6。
- [ ] 确认工作区干净，单独创建重构分支，例如 `refactor-before-lab-plus`。
- [ ] 记录基线验证命令和关键输出。

建议基线命令：

```bash
make sim
make test-lab4
timeout 25s make test-lab5 || true
TEST=sys ./build/emu --no-diff -i ./ready-to-run/lab6/lab6-test.bin -C 8000000 --force-dump-result
```

通过判据：

- Lab4: `HIT GOOD TRAP`
- Lab5: `Return from init! Test passed`
- Lab6: `Privileged test finished.` 和 `Exit with code = 0`

## 1. 只整理公共类型和常量

目标：先减少 `core.sv` 顶部常量和 helper 的噪声，不改变行为。

- [ ] 将 trap cause 常量、`MIP_MSIP/MTIP/MEIP` 等移动到统一位置，例如 `vsrc/include/csr.sv` 或新增 `vsrc/include/trap.sv`。
- [ ] 保留原有数值不变，只替换引用位置。
- [ ] 不改流水线控制、不改 CSR 行为。

验证：

- [ ] `make sim`
- [ ] Lab4/Lab6 快速回归。

建议提交：

```text
refactor(trap): centralize trap constants
```

## 2. 抽出访存工具函数

目标：让 `core.sv` 中 MEM 相关函数更独立，便于后续支持更多访存异常或 page fault。

- [ ] 将 `mem_size_from_funct3`、`store_strobe_from_funct3`、`align_store_data`、`extend_load_data`、`mem_addr_misaligned` 整理到独立 helper 文件或公共 package。
- [ ] 保持函数签名和返回值语义不变。
- [ ] 只修改调用位置，不重写 MEM 阶段控制。

验证：

- [ ] `make sim`
- [ ] `make test-lab2`
- [ ] Lab6 load/store misalign 测试输出仍为 `[OK]`。

建议提交：

```text
refactor(mem): extract load store helpers
```

## 3. 引入流水线 packet struct

目标：减少 `ID_EX`、`EX_MEM`、`MEM_WB` 的重复字段和重复 bubble 赋值。

建议分三小步做，不要一次全改：

- [ ] 先新增 `id_ex_t`，只替换 ID/EX 寄存器。
- [ ] 再新增 `ex_mem_t`，替换 EX/MEM 寄存器。
- [ ] 最后新增 `mem_wb_t`，替换 MEM/WB 寄存器。

每一步要求：

- [ ] 提供 `*_bubble` 默认值。
- [ ] 替换后立即跑回归。
- [ ] 不同时修改 trap 或 hazard 语义。

验证：

- [ ] `make sim`
- [ ] `make test-lab4`
- [ ] Lab6 direct run。

建议提交：

```text
refactor(core): introduce id ex pipeline packet
refactor(core): introduce ex mem pipeline packet
refactor(core): introduce mem wb pipeline packet
```

## 4. 拆出 Trap Controller

目标：把 WB 阶段的异常、中断、`ecall`、`mret` 判定从 `core.sv` 中分离出来。

建议新增模块：

```text
vsrc/src/core_trap_ctrl.sv
```

输入建议：

- WB 阶段指令有效、PC、异常 packet
- `is_ecall_wb`、`is_mret_wb`
- 当前 privilege mode
- `mstatus`、`mie`、`mip`
- `swint/trint/exint`
- `fetch_wait_q/mem_wait_q`

输出建议：

- `commit_fire`
- `reg_write_allow`
- `csr_write_allow`
- `trap_wen`
- `mret_wen`
- `trap_mepc/mcause/mtval`
- `redirect_fire/redirect_target`
- `priv_mode_next`
- `system_flush_front`

拆分顺序：

- [ ] 先只移动组合判断，不改信号含义。
- [ ] 保留原信号名，降低 diff 阅读成本。
- [ ] 通过后再考虑重命名和整理接口。

验证：

- [ ] `make sim`
- [ ] Lab4/Lab5/Lab6 全回归。

建议提交：

```text
refactor(core): extract trap controller
```

## 5. 拆出 Difftest Adapter

目标：把 Difftest 相关特判从 `core.sv` 中移走，避免功能逻辑和测试适配混在一起。

- [ ] 新增 `core_difftest_adapter.sv` 或至少新增专门的 helper 信号块。
- [ ] 将 GPR bypass、CSR state、trap event、skip 条件集中管理。
- [ ] 明确记录当前 skip 条件：
  - 低地址 MMIO load/store
  - PMP CSR 指令
- [ ] 不改变 Difftest 输出时序。

验证：

- [ ] `make test-lab4`
- [ ] `timeout 25s make test-lab5 || true`

建议提交：

```text
refactor(difftest): isolate commit adapter
```

## 6. 整理 CSR 文件

目标：为 lab+ 可能的更多 privilege 行为留空间。

- [ ] 将 CSR 地址合法性、读写 mask、trap/mret 状态更新函数分区整理。
- [ ] 保持 `mstatus_on_trap`、`mstatus_on_mret` 的行为不变。
- [ ] 为后续 S-mode delegation 或 page fault 留出清晰入口，但不要提前实现。
- [ ] 检查 `mip` 的“Difftest 可见值”和“硬件 pending 仲裁值”不要混淆。

验证：

- [ ] `make test-lab4`
- [ ] Lab6 interrupt 测试。

建议提交：

```text
refactor(csr): clarify trap and mask helpers
```

## 7. 清理总线与 MMU 边界

目标：在 lab+ 前明确 simulation path 和 board path 的差异，避免再次把上板时序修复和功能实现混在一起。

- [ ] 单独审查 `IBusToCBus.sv` 的响应地址选择是否需要 latch。
- [ ] 单独审查 `CBusArbiter.sv` 是否应保持已发出的 request 稳定。
- [ ] 单独审查 `MMU.sv` 的 `STATE_WAIT_CLEAR` 和 context change 行为。
- [ ] 每个修改都单独提交，不和 core 功能混合。

验证：

- [ ] Lab5 kernel simulation。
- [ ] 如果目标是上板，再单独记录 Vivado/串口输出结果。

建议提交：

```text
fix(bus): latch instruction response address
fix(bus): hold issued cbus request stable
fix(mmu): flush walk state on context change
```

## 8. lab+ 前最终检查

- [ ] `core.sv` 是否明显变短，trap 和 Difftest 是否已经有独立边界。
- [ ] 每个重构提交是否都能单独通过基本回归。
- [ ] `Doc/Refactor_TODO.md` 中已完成项是否更新。
- [ ] Lab4/Lab5/Lab6 是否仍通过。
- [ ] 再开始 lab+ 新功能，不在同一提交中继续重构。

## 推荐执行顺序

最稳妥路线：

1. 公共常量整理
2. 访存 helper 提取
3. pipeline packet struct
4. trap controller
5. Difftest adapter
6. CSR 文件整理
7. 总线/MMU 边界清理

如果时间有限，建议至少完成第 3 和第 4 步。它们对后续 lab+ 的收益最大：一个降低字段重复，一个降低系统控制复杂度。
