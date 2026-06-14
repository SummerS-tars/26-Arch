# Lab+ TODO

本文用于梳理 Lab+ 可选内容，并按“依赖在前、低成本在前、可验证优先”的原则安排后续迭代。

当前判断基于仓库代码检查、`Makefile`、`ready-to-run/lab+/`、既有报告和项目状态记录。实际通过情况仍需以后续测试运行为准。

## 排序原则

- 优先做能快速形成报告材料的内容。
- 优先做已有代码基础上补齐的小闭环。
- 优先做有现成测试目标的内容：`test-labplus-2/3/4`。
- 依赖项必须排在被依赖项之前。
- 完整 xv6、cache、上板这类大任务放最后，作为时间充裕时的探索项。

## 当前基线

- Lab1-Lab6 主线已形成模块化五级流水线实现。
- Lab4/Lab5/Lab6 在重构后曾记录为通过。
- `Makefile` 已有 `test-labplus-2/3/4` 目标。
- `ready-to-run/lab+/` 已有 Lab+2/3/4 的 `.bin` 输入和对应反汇编文本。
- `docs/report.md` 当前仍是 Lab6 报告，不是 Lab+ 报告。
- 当前代码中未见 M 扩展乘除法、A 扩展原子指令、PMP 权限检查、page fault、分支预测、cache、完整 xv6 磁盘 MMIO 支持。

## 已完成记录

### 2026-06-14：完成任务 0-1

- 已确认 Lab+ 测试输入存在：
  - `ready-to-run/lab+/2/microbench-riscv64-nutshell.bin`
  - `ready-to-run/lab+/3/atomicity.bin`
  - `ready-to-run/lab+/4/all-test-privfull.bin`
- 已建立 Lab+ 初始失败基线：
  - Lab+2：运行到 microbench qsort 后 Difftest mismatch，首个关键点为 `pc = 0x80000bc4`，`a5` 期望 `0x343fd`，实际 `0x343fe`；该指令为 `mulw`，指向 M 扩展缺失。
  - Lab+3：首个原子指令 `amoswap.w` 处 Difftest mismatch，关键点为 `pc = 0x80000028`，`t3` 期望 `0x12345678`，实际 `0x0`；指向 A 扩展缺失。
  - Lab+4：no-diff 运行未通过，显式 cycle cap 下停在 `EXCEEDING CYCLE/INSTR LIMIT at pc = 0x0`；后续需结合 PMP/access fault 与特权测试路径继续定位。
- 已整理已有 Bonus 材料：
  - Lab4：S-mode CSR、`medeleg/mideleg`、`pmpcfg0/pmpaddr0` 基本读写，以及 CSR 作用说明。
  - Lab5：Sv39 MMU 和上级 leaf PTE 地址拼接，可作为巨页支持说明。
  - Lab6：异常/中断主线已完成；缺页异常和单独“时钟中断处理程序打印内容”未完成。

### 2026-06-14：完成任务 2

- 已实现 RV64M 乘除法：
  - 64-bit：`mul`、`mulh`、`mulhsu`、`mulhu`、`div`、`divu`、`rem`、`remu`。
  - 32-bit W 版本：`mulw`、`divw`、`divuw`、`remw`、`remuw`。
  - 已处理除零、`INT_MIN / -1` 溢出、W 指令结果符号扩展等语义。
- 已验证：
  - `make sim`：构建通过。
  - Lab1 extra 直连运行：通过，`HIT GOOD TRAP at pc = 0x8002001c`。
  - Lab4 直连运行：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
  - Lab5 直连运行：通过，输出 `Return from init! Test passed`。
  - Lab6 直连运行：通过，输出 `Privileged test finished.` / `Exit with code = 0`。
  - Lab+2 直连运行：已越过原先 `mulw` mismatch，`qsort` 显示 `* Passed.`；后续在 `queen` 阶段因 90 秒 wall timeout 停止，留给任务 3 继续处理。

### 2026-06-14：完成任务 3

- 分文档：`Doc/Lab+/labplus2_microbench_report.md`。
- 已确认 Lab+2 的首个正确性阻塞已经清除：
  - 默认随机延迟下，600 秒内未出现 Difftest mismatch，`qsort`、`queen` 通过，停在 `bf`。
  - 使用 `make sim DELAY=0` 关闭仿真 RAM 随机等待后，600 秒内未出现 Difftest mismatch，`qsort`、`queen`、`bf` 通过，停在 `fib`。
- 当前结论：
  - microbench 已能正确进入并连续通过多个 benchmark。
  - 尚未完整跑完 `ref` 输入，主要瓶颈是现有 CPU 缺少性能优化。
  - 后续应进入任务 4/5，先做性能统计，再考虑分支预测。

## TODO 顺序

### 0. 确认 Lab+ 测试输入并建立失败基线（已完成）

- 成本：低
- 优先级：最高
- 依赖：无
- 目标：让后续每个功能都有明确的起点和验证结果。
- 当前状态：`Makefile` 引用的 Lab+2/3/4 `.bin` 均已存在，初始失败基线已记录。
- 要做：
  - 已确认 `ready-to-run/lab+/2/microbench-riscv64-nutshell.bin`。
  - 已确认 `ready-to-run/lab+/3/atomicity.bin`。
  - 已确认 `ready-to-run/lab+/4/all-test-privfull.bin`。
  - 已运行三个 Lab+ 目标并记录第一处关键失败。
- 验证：
  - 等价直连命令：`./build/emu --diff ./ready-to-run/riscv64-nemu-interpreter-so -i ./ready-to-run/lab+/2/microbench-riscv64-nutshell.bin`
  - 等价直连命令：`./build/emu --diff ./ready-to-run/riscv64-nemu-interpreter-so -i ./ready-to-run/lab+/3/atomicity.bin`
  - 等价直连命令：`./build/emu --no-diff -i ./ready-to-run/lab+/4/all-test-privfull.bin -C 8000000 --force-dump-result`
- 产出：
  - 已得到一段基线记录，可写入后续 Lab+ 报告。

### 1. 整理已有 Bonus 材料（已完成）

- 成本：低
- 优先级：很高
- 依赖：无
- 目标：先确认哪些内容已经能作为 Lab+ 报告材料，不重复实现。
- 当前状态：
  - Lab4 报告已说明 S 模式 CSR、`medeleg/mideleg`、`pmpcfg0/pmpaddr0` 的基本读写。
  - Lab4 报告已回答 CSR 作用相关内容。
  - Lab5 报告写到 MMU 支持上级 leaf PTE，也就是巨页地址拼接。
  - Lab6 报告明确缺页异常未实现。
  - Lab6 报告没有单独写“时钟中断处理程序打印内容”的 Bonus。
- 要做：
  - 已列出“已完成/已有基础”的 Bonus。
  - 已确认巨页支持说明应重点对应 `MMU.sv` 的 `leaf_addr()`。
  - 已确认 PMP CSR 只能写“基本读写”，不能写成“已实现 PMP 权限保护”。
- 验证：
  - 代码检查为主。
  - 若能运行 Lab5 回归，保留 `Return from init! Test passed`。
- 产出：
  - 已形成 Lab+ 报告中“已有工作整理”章节的要点。

### 2. 实现 M 扩展乘除法（已完成）

- 成本：中低
- 优先级：高
- 依赖：无
- 目标：补齐旧 Bonus 中最独立、最容易验证的一项。
- 当前状态：
  - `core_decode.sv` 已区分 `funct7 = 7'b0000001` 的 M 扩展。
  - `core_alu.sv` 已实现 `mul/div/rem` 及 W 版本语义。
  - `lab1-extra` 已通过。
  - Lab+2 已越过原先 `mulw` 失败点。
- 要做：
  - 已在公共 ALU op 中加入 `mul/mulh/mulhsu/mulhu/div/divu/rem/remu`。
  - 已加入 `mulw/divw/divuw/remw/remuw`。
  - 已在 `core_decode.sv` 中按 opcode、funct3、funct7 正确译码。
  - 已处理除零、溢出、W 指令符号扩展等 RISC-V 语义。
- 验证：
  - Lab1 extra 直连运行通过。
  - Lab4/Lab5/Lab6 直连回归通过。
  - Lab+2 已推进到 qsort 通过，完整 microbench 留给任务 3。
- 产出：
  - 可在 Lab+ 报告中明确写“实现乘除法 Bonus”。

### 3. 让 Lab+2 microbench 先正确跑起来（阶段完成）

- 成本：中
- 优先级：高
- 依赖：任务 0、任务 2
- 目标：先追求正确运行，再考虑性能优化。
- 当前状态：
  - 仿真 RAM 已有 UART、CLINT timer 等基础 MMIO。
  - CPU 已有五级流水线、hazard、forwarding。
  - 尚未实现专门性能优化。
  - microbench 依赖的 M 扩展指令已实现。
  - Lab+2 已在 Difftest 下连续通过 `qsort`、`queen`、`bf`，没有出现新的正确性 mismatch。
- 要做：
  - 已运行 Lab+2。
  - 已确认原先的 M 扩展正确性失败已消除。
  - 已确认当前主要问题是运行时间过长，不急于在本任务中加入分支预测或 cache。
- 验证：
  - 默认随机延迟直连运行：`qsort`、`queen` 通过，600 秒停在 `bf`。
  - `DELAY=0` 直连运行：`qsort`、`queen`、`bf` 通过，600 秒停在 `fib`。
- 产出：
  - 已形成 microbench 正确性基线记录。
  - 完整 IPC/cycle 性能基线留给任务 4。

### 4. 增加轻量性能统计

- 成本：低到中
- 优先级：中高
- 依赖：任务 3
- 目标：为性能优化提供可解释的报告数据。
- 当前状态：
  - 当前代码没有分支预测准确率统计。
  - Lab+ 官方给了分支/跳转统计参考代码。
- 要做：
  - 统计总分支数、跳转数、flush 次数、可能的预测命中率。
  - 当前尚无预测器时，可先记录“默认预测不跳转”的基线。
  - 统计逻辑应避免影响提交语义和 Difftest。
- 验证：
  - `make test-labplus-2`
  - Lab4/Lab5/Lab6 回归不应受影响。
- 产出：
  - 报告中的性能基线数据。

### 5. 实现简单分支预测

- 成本：中到中高
- 优先级：中
- 依赖：任务 3、任务 4
- 目标：完成 Lab+2 的“简单性能优化”方向，优先选择低风险方案。
- 当前状态：
  - 现在 PC 默认 `pc + 4`。
  - branch/jal/jalr 在 EX 阶段决断。
  - 没有 BTB、BHT、RAS。
- 推荐路线：
  - 第一阶段：静态预测，例如 backward branch taken、forward branch not taken。
  - 第二阶段：小型 BHT，两位饱和计数器。
  - 第三阶段：BTB 记录目标地址。
  - RAS 和 cache 暂不优先。
- 风险：
  - 需要调整 IF 取指 PC 选择和错误预测恢复。
  - 容易破坏现有 flush/stall 时序。
- 验证：
  - `make test-labplus-2`
  - `make test-lab4`
  - `make test-lab5`
  - `make test-lab6`
- 产出：
  - 优化前后 cycle/IPC/预测命中率对比。

### 6. 实现 Lab+3 原子指令的最小集合

- 成本：中高
- 优先级：中
- 依赖：任务 0
- 目标：优先通过 `atomicity.S` 中实际出现的指令。
- 当前状态：
  - `atomicity.S` 明确包含 `amoswap.w`、`amoadd.w`、`lr.w`、`sc.w`。
  - `core_decode.sv` 没有 AMO opcode `7'b0101111`。
  - 当前没有 reservation set。
  - `core_difftest_adapter.sv` 的 `scFailed` 固定为 `1'b0`。
  - 未见 `DifftestAtomicEvent` 连接。
- 要做：
  - 增加 AMO/LR/SC 译码。
  - 先实现 `amoswap.w`、`amoadd.w`、`lr.w`、`sc.w`。
  - 32-bit 结果写回时按 RV64 规则符号扩展。
  - `lr.w` 记录 reservation address。
  - `sc.w` 成功写内存并写 `rd=0`，失败不写内存并写 `rd=1`。
  - `sc.w` 后清除 reservation。
  - 原子指令执行期间避免异常/中断打断中间状态。
  - 视 Difftest 行为接入 `DifftestAtomicEvent` 或调整 skip/commit 策略。
- 验证：
  - `make test-labplus-3`
  - `make test-lab4`
  - `make test-lab5`
  - `make test-lab6`
- 产出：
  - 原子指令 Bonus 的实现说明。

### 7. 扩展完整 32-bit AMO 指令

- 成本：中
- 优先级：中低
- 依赖：任务 6
- 目标：从最小集合扩展到官方列出的全部 32-bit AMO。
- 当前状态：
  - 任务 6 完成后，AMO 数据通路已有基础。
- 要做：
  - 增加 `amoxor.w`。
  - 增加 `amoand.w`。
  - 增加 `amoor.w`。
  - 增加 `amomin.w` / `amomax.w`。
  - 增加 `amominu.w` / `amomaxu.w`。
  - `aq/rl` 字段可按要求忽略。
- 验证：
  - `make test-labplus-3`
  - 可额外自写小汇编覆盖所有 AMO op。
- 产出：
  - 更完整的 A 扩展说明。

### 8. 实现 PMP 权限检查

- 成本：中高
- 优先级：中低
- 依赖：任务 0、现有 CSR 基础
- 目标：从“PMP CSR 可读写”升级为“PMP 真正参与取指/访存权限判断”。
- 当前状态：
  - `core_csr.sv` 已保存 `pmpaddr0_q`、`pmpcfg0_q`。
  - 取指、load、store 路径未见 PMP check。
  - `trap.sv` 未见 instruction/load/store access fault cause。
  - Lab+4 中有 `pmp_nr`、`pmp_nw`、`pmp_nx` 相关测试。
- 要做：
  - 从 CSR 模块导出 `pmpaddr0/pmpcfg0`。
  - 实现至少 `pmpaddr0` + `pmpcfg0` 对应的权限区域。
  - 根据 R/W/X 权限分别检查 load/store/fetch。
  - 违规时产生 access fault：
    - instruction access fault
    - load access fault
    - store/AMO access fault
  - 设置正确的 `mcause` 和 `mtval`。
- 验证：
  - `make test-labplus-4`
  - `make test-lab4`
  - `make test-lab5`
  - `make test-lab6`
- 产出：
  - PMP Bonus 的核心报告材料。

### 9. 实现 MMU page fault

- 成本：高
- 优先级：低到中
- 依赖：现有 MMU、trap 路径；若和 S-mode 配合，则依赖任务 10
- 目标：补齐 Lab5/Lab6 相关 Bonus，并为更完整 xv6 做准备。
- 当前状态：
  - `MMU.sv` 对 invalid PTE 当前采用虚拟地址直通回退。
  - 未见 page fault cause 常量。
  - 报告中已明确写“未实现缺页异常”。
- 要做：
  - 无效 PTE 触发 instruction/load/store page fault。
  - 检查 PTE R/W/X/U/A/D 等权限位。
  - 区分取指、load、store 的 fault cause。
  - 将 MMU fault 反馈给 core，并在 WB 或合适提交边界进入 trap。
  - 避免 page fault 后仍发起错误的最终访存。
- 验证：
  - Lab5 回归。
  - 若有自测，构造 invalid PTE / 权限错误 PTE。
  - `make test-labplus-4` 视测试覆盖情况观察。
- 产出：
  - 缺页异常 Bonus 报告材料。

### 10. 完善 S-mode trap / delegation / sret

- 成本：高
- 优先级：低
- 依赖：任务 9；若目标是完整 xv6，则必需
- 目标：从“有 S-mode CSR”升级为“真正支持 S-mode trap 生态”。
- 当前状态：
  - CSR 中已有 `stvec/sepc/scause/stval/sstatus/sie/sip/medeleg/mideleg`。
  - 当前 trap 控制主要进入 M-mode，重定向到 `mtvec`。
  - `core_decode.sv` 未见 `sret` 译码。
- 要做：
  - 增加 `sret`。
  - 根据 `medeleg/mideleg` 决定 trap 进入 M-mode 还是 S-mode。
  - S-mode trap 写 `sepc/scause/stval`，跳转 `stvec`。
  - `sret` 恢复 `sstatus.SPP/SPIE/SIE` 和特权级。
  - 重新检查中断 pending 与 delegation 的关系。
- 验证：
  - 自写 S-mode trap 测试。
  - Lab4/Lab5/Lab6 回归。
  - 为完整 xv6 运行做准备。
- 产出：
  - 特权架构扩展说明。

### 11. 尝试完整 xv6 主 Track

- 成本：很高
- 优先级：低
- 依赖：任务 6、任务 9、任务 10；若不做 A 扩展，则需要修改 xv6 spinlock
- 目标：让 difftest 环境下输出 xv6 启动信息并尽量进入用户终端。
- 当前状态：
  - Lab5 已能跑课程裁剪内核。
  - 未见 virtio 或磁盘 MMIO 支持。
  - difftest 侧有 sdcard 相关代码，但 RAMHelper 当前没有接成 xv6 可用的块设备 MMIO。
- 要做：
  - 决定方案：
    - 实现简单 MMIO 磁盘读写。
    - 或改 xv6 磁盘驱动为自定义 MMIO。
  - 处理 xv6 对 S-mode、page fault、`sret`、原子指令的依赖。
  - 如不完整实现 A 扩展，则修改 xv6 spinlock 规避多核原子依赖。
  - 先追求启动输出，再追求 shell。
- 验证：
  - 自定义 xv6 启动命令。
  - 记录能输出到哪一行。
- 产出：
  - 即使未完整跑通，也可写“尝试了什么、卡在哪里、如何分析”的 Lab+ 报告材料。

### 12. Cache 或更复杂性能优化

- 成本：很高
- 优先级：低
- 依赖：任务 3、任务 4
- 目标：作为性能优化的高级项。
- 当前状态：
  - 当前总线路径是 IBus/DBus 到 CBus，再到 MMU/RAM。
  - 未见 I-cache/D-cache 模块。
- 要做：
  - 优先考虑 I-cache，因为实现面小于 D-cache。
  - 明确 cache 与 MMU 的前后位置。
  - 处理 flush、fence、异常、中断与总线握手。
  - D-cache 需要处理 store、MMIO bypass、一致性等问题，风险明显更高。
- 验证：
  - `make test-labplus-2`
  - Lab4/Lab5/Lab6 全回归。
- 产出：
  - 性能对比报告。

### 13. Lab+ 上板扩展

- 成本：很高
- 优先级：最低
- 依赖：对应功能在仿真中稳定
- 目标：把 Lab+ 功能迁移到 FPGA 板端。
- 当前状态：
  - 仿真路径和板端路径需要分开看。
  - Lab5 报告中已有上板时序与 BRAM 初始化差异的经验。
- 要做：
  - 先确保仿真通过。
  - 同步 `.bin` / `.coe` / BRAM 初始化。
  - 检查 MMIO 地址是否适合板端。
  - 用串口输出确认进度。
- 验证：
  - Vivado 综合实现。
  - 板端串口日志。
- 产出：
  - 上板 Bonus 报告材料。

## 推荐迭代批次

### 第一批：最稳妥

- 任务 0：确认测试输入和失败基线。（已完成）
- 任务 1：整理已有 Bonus 材料。（已完成）
- 任务 2：实现 M 扩展乘除法。（已完成）
- 任务 3：让 microbench 先正确跑起来。（阶段完成）

目标：快速形成 Lab+ 报告基础，并争取拿到乘除法和 microbench 正确性进展。

### 第二批：有明确测试目标

- 任务 4：性能统计。
- 任务 5：简单分支预测。
- 任务 6：Lab+3 原子指令最小集合。
- 任务 8：PMP 权限检查。

目标：围绕 `test-labplus-2/3/4` 做可验证功能。

### 第三批：高成本探索

- 任务 7：完整 32-bit AMO。
- 任务 9：page fault。
- 任务 10：S-mode trap / delegation / sret。
- 任务 11：完整 xv6 主 Track。

目标：为高分 Bonus 或更完整系统能力做准备。

### 第四批：时间充裕再做

- 任务 12：cache 或复杂性能优化。
- 任务 13：Lab+ 上板扩展。

目标：只在主线功能稳定后尝试，避免破坏已有 Lab1-Lab6 回归。

## 当前最推荐的下一步

任务 0-3 已完成。下一步优先做任务 4：增加轻量性能统计。

理由：Lab+2 已经不再卡在正确性 mismatch，默认随机延迟和零随机延迟下都能连续通过多个 benchmark。剩余问题是运行时间过长，需要先量化分支、跳转、flush 等性能数据，再决定是否做分支预测。
