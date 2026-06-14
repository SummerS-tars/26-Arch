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
- 当前代码已支持 RV64M 乘除法、第一阶段静态分支预测、Lab+3 需要的 LR/SC、完整 32-bit AMO RMW 指令、`pmpaddr0/pmpcfg0` entry0 NAPOT R/W/X 权限检查、MMU page fault 核心路径，以及 S-mode trap/delegation/`sret` 核心闭环；仍未实现 cache、完整 xv6 磁盘 MMIO 支持。

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

### 2026-06-14：完成任务 4

- 分文档：`Doc/Lab+/labplus2_perf_stats_report.md`。
- 已在 `core.sv` 中加入 Verilator 仿真期轻量性能计数器。
- 统计输出由 `BENCHMARK` 编译宏控制：
  - 默认 `make sim` 不输出统计信息。
  - `make sim BENCHMARK=1` 启用统计输出。
- 已统计：
  - 周期数、提交指令数、`ipc_x1000`。
  - 分支总数、taken 分支数、默认不跳转预测正确数。
  - `jal/jalr` 数量。
  - EX 控制流重定向、系统重定向。
  - load-use stall、fetch wait、mem wait。
- 50M cycle Lab+2 采样结果：
  - `instr = 9,099,437`
  - `IPC = 0.181989`
  - `branches = 1,116,352`
  - `taken = 898,155`
  - `nt_pred_ok = 218,197`
  - `jumps = 415,789`
  - `ex_redirects = 1,313,944`
  - `fetch_waits = 31,247,451`
  - `mem_waits = 5,116,753`
- 当前结论：
  - 默认“不跳转预测”下分支方向正确率约 19.5%。
  - 控制流重定向和取指等待都很重，后续简单分支预测有明确优化价值。

### 2026-06-14：完成任务 5

- 分文档：`Doc/Lab+/labplus2_branch_prediction_report.md`。
- 已实现静态分支预测：
  - backward branch 预测 taken。
  - forward branch 预测 not taken。
  - 预测目标在 ID 阶段计算，EX 阶段判断误判并恢复。
  - 暂未引入 BHT、BTB、RAS，也未提前处理 `jal/jalr`。
- 50M cycle Lab+2 对比采样结果：
  - `instr = 9,505,052`，相对任务 4 基线 `9,099,437` 提升约 4.46%。
  - `IPC = 0.190101`，相对任务 4 基线 `0.181989` 提升约 4.46%。
  - `pred_ok = 869,083`，`pred_miss = 315,950`，分支预测正确率约 73.3%。
  - `ex_redirects = 734,777`，相对任务 4 基线 `1,313,944` 下降约 44.1%。
- 已验证：
  - `make sim`：构建通过。
  - `make test-lab4`：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
  - Lab+2 50M cycle 采样：无 Difftest mismatch，达到 cycle cap。
  - `timeout 45s make test-lab5 || true`：输出 `Return from init! Test passed`。
  - `make test-lab6`：输出 `Privileged test finished.` / `Exit with code = 0`。

### 2026-06-14：完成任务 6

- 分文档：`Doc/Lab+/labplus3_atomic_report.md`。
- 已实现 Lab+3 `atomicity.S` 覆盖的最小 A 扩展集合：
  - `amoswap.w`
  - `amoadd.w`
  - `lr.w`
  - `sc.w`
- 实现要点：
  - AMO W 指令按 RV64 规则将 32-bit 旧值符号扩展写回。
  - `amoswap.w` / `amoadd.w` 在 MEM 阶段用两步 RMW：先读旧值，再写新值。
  - `lr.w` 记录 word-granularity reservation address。
  - `sc.w` 成功时写内存并写回 `rd=0`，失败时不写内存并写回 `rd=1`，随后清除 reservation。
  - `DifftestInstrCommit.scFailed` 已接入 WB 阶段的 SC 失败状态。
- 已验证：
  - `make sim`：构建通过。
  - `make test-labplus-3`：通过，`HIT GOOD TRAP at pc = 0x800000dc`。
  - `make test-lab4`：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
  - `timeout 45s make test-lab5 || true`：输出 `Return from init! Test passed`。
  - `make test-lab6`：输出 `Privileged test finished.` / `Exit with code = 0`；命令随后被用户中断，但成功标志已出现。

### 2026-06-14：完成任务 7

- 分文档：`Doc/Lab+/labplus3_full_amo32_report.md`。
- 已从任务 6 的最小 A 扩展集合继续补全 32-bit AMO RMW 指令：
  - `amoxor.w`
  - `amoand.w`
  - `amoor.w`
  - `amomin.w` / `amomax.w`
  - `amominu.w` / `amomaxu.w`
- 已新增可重复生成的裸机自测：
  - `ready-to-run/lab+/3/gen_atomic_full_w_test.py`
  - `ready-to-run/lab+/3/atomic_full_w.bin`
  - `ready-to-run/lab+/3/atomic_full_w.S`
- 已验证：
  - `make sim`：构建通过。
  - `atomic_full_w.bin`：通过，`HIT GOOD TRAP at pc = 0x800001c4`。
  - `make test-labplus-3`：通过，`HIT GOOD TRAP at pc = 0x800000dc`。
  - `make test-lab4`：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
  - `timeout 45s make test-lab5 || true`：输出 `Return from init! Test passed`。
  - `make test-lab6`：输出 `Privileged test finished.` / `Exit with code = 0`；命令随后被用户中断，但成功标志已出现。

### 2026-06-14：完成任务 8

- 分文档：`Doc/Lab+/labplus4_pmp_report.md`。
- 已实现 `pmpaddr0/pmpcfg0` entry0 的 NAPOT 区域权限检查：
  - CSR 模块导出 `pmpaddr0` / `pmpcfg0`。
  - `pmpcfg0[7:0]` 按 R/W/X 和 `A=NAPOT` 解析。
  - U/S-mode 取指无 X 权限时产生 instruction access fault。
  - U/S-mode load 无 R 权限时产生 load access fault。
  - U/S-mode store/AMO 无 W 权限时产生 store/AMO access fault。
  - M-mode 默认不受该 entry 限制；暂不实现 TOR/NA4/L-bit。
- 已验证：
  - `make sim`：构建通过。
  - Lab+4 no-diff 直连运行：通过前置特权/PMP 子测，输出 `Single test passed.`；零延迟 80M cycle cap 下继续跑过 paint、compress、coremark、dhrystone、stream，停在 conway 后续负载，未再出现 PMP/access fault 失败。
  - Lab+3：通过，`HIT GOOD TRAP at pc = 0x800000dc`。
  - Lab4：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
  - Lab5：输出 `Return from init! Test passed`。
  - Lab6：输出 `Privileged test finished.` / `Exit with code = 0`，采用显式 cycle cap，避免命令长时间占住终端。

### 2026-06-14：完成任务 9

- 分文档：`Doc/Lab+/labplus_mmu_page_fault_report.md`。
- 已实现 MMU page fault 核心路径：
  - 增加 instruction/load/store page fault cause。
  - IBus/DBus/CBus 请求增加访问类型，响应增加 `page_fault` 标志。
  - `MMU.sv` 对 invalid PTE、`W && !R`、非叶子走到底、R/W/X/A/D 权限、基本 U-mode 权限和 superpage 对齐错误产生 page fault。
  - page fault 时不发起最终访存，而是向 core 返回 fault 响应。
  - `core.sv` 在 IF/MEM 侧分别转成 instruction/load/store page fault，并写入虚拟地址作为 `mtval`。
- 已新增诊断型裸机自测生成器：
  - `ready-to-run/lab+/4/gen_page_fault_test.py`
  - `ready-to-run/lab+/4/page_fault_load.bin/.S`
  - `ready-to-run/lab+/4/page_fault_store.bin/.S`
  - `ready-to-run/lab+/4/page_fault_inst.bin/.S`
- 已验证：
  - `make sim`：构建通过。
  - Lab4：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
  - Lab5：输出 `Return from init! Test passed`。
  - Lab6：输出 `Privileged test finished.` / `Exit with code = 0`。
  - Lab+3：通过，`HIT GOOD TRAP at pc = 0x800000dc`。
  - Lab+4：前置特权/PMP 子测仍输出 `Single test passed.`。
  - 诊断型 load page fault 自测在 Difftest 下可见 DUT 于 `ld` 处写出 `mcause=13`、`mepc=0x80000084`、`mtval=0x40000000`；no-diff good-trap 收尾仍不稳定，暂不作为通过判据。

### 2026-06-14：完成任务 10

- 分文档：`Doc/Lab+/labplus_smode_trap_report.md`。
- 已实现 S-mode trap/delegation/`sret` 核心闭环：
  - `core_decode.sv` 增加 `sret` 译码。
  - 流水线 packet 增加 `is_sret` 并从 ID 透传到 WB。
  - `csr.sv` 放开 `SSTATUS_MASK`、`MEDELEG_MASK`、`MIDELEG_MASK`。
  - `core_trap_ctrl.sv` 根据 `medeleg/mideleg` 和当前特权级决定 trap 进入 M-mode 或 S-mode。
  - S-mode trap 写 `sepc/scause/stval` 并重定向到 `stvec`。
  - `sret` 从 `sepc` 返回，并按 `SPP/SPIE/SIE` 恢复特权级和状态位。
- 已验证：
  - `make sim`：构建通过。
  - Lab5 extra S-mode bonus：`HIT GOOD TRAP at pc = 0x800002b4`，覆盖 `mret -> S-mode -> sret -> U-mode ecall -> delegated S-trap -> sret`。
  - Lab4：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
  - Lab5：输出 `Return from init! Test passed`。
  - Lab6：输出 `Privileged test finished.` / `Exit with code = 0`。
  - Lab+3：通过，`HIT GOOD TRAP at pc = 0x800000dc`。
  - Lab+4：前置 privileged/PMP 子测仍输出 `Single test passed.`。
- 边界：
  - 暂未实现 `TSR/TW/TVM` 的完整非法化语义。
  - 暂未完整实现 `SUM/MXR` 对 MMU 权限的影响。
  - `mideleg` 路径已接入，但现有硬件中断源仍以 machine interrupt cause 为主，完整 S-level interrupt pending/priority 可后续细化。

### 2026-06-14：完成任务 11 启动尝试

- 分文档：`Doc/Lab+/labplus_xv6_main_track_report.md`。
- 已按“只基于仓库现有内容 + RAM disk 优先方向”完成一次完整 xv6 主 Track 启动尝试和缺口定位：
  - 当前仓库未发现完整 xv6 源码、完整 `kernel.bin` 或 `fs.img`。
  - `Makefile` 无完整 xv6 target；最接近入口是 `make test-lab5` 的裁剪内核和 `make test-lab5-extra` 的 S-mode 小测。
  - `ready-to-run/lab5/kernel.asm` 未见 `virtio` / `disk` / `fsinit` / `bread` / `bwrite` / `binit` 等完整文件系统路径。
  - `plicinit()` 是空实现，`initcode` 仅触发自定义 `SYS_INIT` 并打印 `Return from init! Test passed`。
  - `RAMHelper2` 当前只支持 RAM、UART、CLINT 和测试寄存器；未接入 xv6 可用块设备或 RAM disk。
  - `sdcard.cpp` 有 C++ 桩，但 `SDCARD_IMAGE` 默认注释，且没有 RTL/DPI 地址解码接入。
- 已验证护栏：
  - `make sim`：构建通过。
  - Lab5：输出 `xv6 kernel is booting` 和 `Return from init! Test passed`。
  - Lab5 extra：`HIT GOOD TRAP at pc = 0x800002b4`。
  - Lab6：输出 `Privileged test finished.` / `Exit with code = 0`。
  - Lab+3：`HIT GOOD TRAP at pc = 0x800000dc`。
- 结论：
  - 当前仓库可以稳定运行裁剪 xv6，但没有足够软件和块设备条件直接进入完整 xv6 shell。
  - 后续若继续推进，建议先提供/引入可修改 xv6 源码，再做 RAM disk 驱动与镜像加载；暂不优先实现完整 virtio-mmio。

### 2026-06-14：完成任务 12

- 分文档：`Doc/Lab+/labplus_cache_perf_report.md`。
- 已实现最小 I-cache 性能优化：
  - 新增 `vsrc/util/ICache.sv`。
  - 在 `SimTop.sv` / `VTop.sv` 中接入 `MMU -> ICache -> RAMHelper/外部 CBus`。
  - I-cache 位于 MMU 之后，使用物理地址。
  - 仅缓存 `MEM_ACCESS_FETCH` 且 `addr[31] = 1` 的 RAM 取指请求。
  - load/store、AMO、页表 walk 和 MMIO 全部 bypass。
  - `satp` 或特权级变化时保守 flush。
- 已验证：
  - `ReadLints`：无新增诊断。
  - `make sim`：构建通过。
  - Lab4：`HIT GOOD TRAP at pc = 0x8001fff8`。
  - Lab5：输出 `Return from init! Test passed`。
  - Lab5 extra：`HIT GOOD TRAP at pc = 0x800002b4`。
  - Lab6：输出 `Privileged test finished.` / `Exit with code = 0`。
  - Lab+3：`HIT GOOD TRAP at pc = 0x800000dc`。
  - Lab+4：前置 privileged/PMP 子测仍输出 `Single test passed.`，80M-cycle cap 下可继续跑到 stream。
  - Lab+2 50M-cycle 性能样本：IPC 约 `0.307`，`fetch_waits` 约 `18.5M/50M`；此前状态快照样本 IPC 约 `0.190`，`fetch_waits` 约 `31.2M/50M`。
- 边界：
  - 当前 line 为 64-bit word，不是 64B cache line。
  - 暂未实现 prefetch、D-cache 和完整 `fence.i` 语义。

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

### 4. 增加轻量性能统计（已完成）

- 成本：低到中
- 优先级：中高
- 依赖：任务 3
- 目标：为性能优化提供可解释的报告数据。
- 当前状态：
  - 已加入轻量性能统计。
  - 当前仍未实现真正分支预测，统计的是默认“不跳转预测”基线。
  - Lab+ 官方给了分支/跳转统计参考代码；当前实现已按本项目流水线信号适配。
- 要做：
  - 已统计总分支数、跳转数、控制流重定向次数、默认不跳转预测命中情况。
  - 已记录“默认预测不跳转”的基线。
  - 统计逻辑由 `BENCHMARK` 宏控制，避免影响普通回归输出。
- 验证：
  - `make sim BENCHMARK=1` 通过。
  - Lab+2 50M cycle 采样成功输出统计信息。
  - 默认 `make sim` 通过。
  - Lab4 默认回归通过。
- 产出：
  - 已形成报告中的性能基线数据。

### 5. 实现简单分支预测（已完成）

- 成本：中到中高
- 优先级：中
- 依赖：任务 3、任务 4
- 目标：完成 Lab+2 的“简单性能优化”方向，优先选择低风险方案。
- 当前状态：
  - 已完成第一阶段静态预测：backward branch taken、forward branch not taken。
  - branch 预测在 ID 阶段产生重定向，EX 阶段做实际结果校验和误判恢复。
  - `jal/jalr` 仍在 EX 阶段决断。
  - 暂无 BTB、BHT、RAS。
- 推荐路线：
  - 第一阶段：静态预测，例如 backward branch taken、forward branch not taken。（已完成）
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
  - 已得到优化前后 cycle/IPC/预测命中率对比。

### 6. 实现 Lab+3 原子指令的最小集合（已完成）

- 成本：中高
- 优先级：中
- 依赖：任务 0
- 目标：优先通过 `atomicity.S` 中实际出现的指令。
- 当前状态：
  - `atomicity.S` 明确包含 `amoswap.w`、`amoadd.w`、`lr.w`、`sc.w`。
  - 已实现 AMO opcode `7'b0101111` 的最小 W 指令集合。
  - 已实现单 hart reservation set。
  - `core_difftest_adapter.sv` 的 `scFailed` 已接入。
  - 未接入 `DifftestAtomicEvent`，当前单核 Lab+3 测试通过不依赖该事件。
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
  - 已形成原子指令 Bonus 的实现说明。

### 7. 扩展完整 32-bit AMO 指令（已完成）

- 成本：中
- 优先级：中低
- 依赖：任务 6
- 目标：从最小集合扩展到官方列出的全部 32-bit AMO。
- 当前状态：
  - 已完成完整 32-bit AMO RMW 指令扩展。
  - 仍未实现 64-bit AMO D 指令。
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
  - 已形成更完整的 A 扩展说明。

### 8. 实现 PMP 权限检查（已完成）

- 成本：中高
- 优先级：中低
- 依赖：任务 0、现有 CSR 基础
- 目标：从“PMP CSR 可读写”升级为“PMP 真正参与取指/访存权限判断”。
- 当前状态：
  - `core_csr.sv` 已保存并导出 `pmpaddr0_q`、`pmpcfg0_q`。
  - `trap.sv` 已补齐 instruction/load/store access fault cause。
  - `core.sv` 已实现 `pmpaddr0/pmpcfg0` entry0 NAPOT 区域匹配。
  - 已按 R/W/X 权限检查 U/S-mode fetch、load、store/AMO。
  - Lab+4 中 `pmp_nr`、`pmp_nw`、`pmp_nx` 所在前置特权/PMP 子测已通过。
- 要做：
  - 已从 CSR 模块导出 `pmpaddr0/pmpcfg0`。
  - 已实现 `pmpaddr0` + `pmpcfg0` 对应的 NAPOT 权限区域。
  - 已根据 R/W/X 权限分别检查 load/store/fetch。
  - 违规时已产生 access fault：
    - instruction access fault
    - load access fault
    - store/AMO access fault
  - 已设置对应的 `mcause` 和 `mtval`。
- 验证：
  - Lab+4 no-diff 直连运行：输出 `Single test passed.`；80M cycle cap 下后续性能负载仍未完整结束。
  - Lab+3、Lab4、Lab5、Lab6 回归通过关键成功线。
- 产出：
  - PMP Bonus 的核心报告材料：`Doc/Lab+/labplus4_pmp_report.md`。

### 9. 实现 MMU page fault（已完成核心路径）

- 成本：高
- 优先级：低到中
- 依赖：现有 MMU、trap 路径；若和 S-mode 配合，则依赖任务 10
- 目标：补齐 Lab5/Lab6 相关 Bonus，并为更完整 xv6 做准备。
- 当前状态：
  - `MMU.sv` 已不再对 invalid PTE 做虚拟地址直通回退，而是返回 page fault。
  - 已补齐 instruction/load/store page fault cause 常量。
  - 已通过总线 fault 标志把 MMU fault 反馈给 core。
  - 已在 IF/MEM 侧接入 page fault 异常，并设置 `mcause` / `mtval`。
- 要做：
  - 已让无效 PTE 触发 instruction/load/store page fault。
  - 已检查 PTE R/W/X/U/A/D 等权限位。
  - 已区分取指、load、store 的 fault cause。
  - 已将 MMU fault 反馈给 core，并在 IF/MEM 到 WB 的既有异常路径进入 trap。
  - 已避免 page fault 后发起错误的最终访存。
- 验证：
  - Lab5 回归：输出 `Return from init! Test passed`。
  - Lab4/Lab6/Lab+3 回归通过关键成功线。
  - Lab+4 前置特权/PMP 子测仍输出 `Single test passed.`。
  - 新增 page fault 诊断型自测，Difftest 可见 DUT 产生预期 load page fault 状态；no-diff good-trap 收尾仍需后续完善。
- 产出：
  - 缺页异常 Bonus 报告材料：`Doc/Lab+/labplus_mmu_page_fault_report.md`。

### 10. 完善 S-mode trap / delegation / sret（已完成核心闭环）

- 成本：高
- 优先级：低
- 依赖：任务 9；若目标是完整 xv6，则必需
- 目标：从“有 S-mode CSR”升级为“真正支持 S-mode trap 生态”。
- 当前状态：
  - CSR 中已有并已接入 `stvec/sepc/scause/stval/sstatus/sie/sip/medeleg/mideleg`。
  - trap 控制已能根据 `medeleg/mideleg` 选择进入 M-mode 或 S-mode。
  - `core_decode.sv` 已支持 `sret` 译码。
- 要做：
  - 已增加 `sret`。
  - 已根据 `medeleg/mideleg` 决定 trap 进入 M-mode 还是 S-mode。
  - 已支持 S-mode trap 写 `sepc/scause/stval`，跳转 `stvec`。
  - 已支持 `sret` 恢复 `sstatus.SPP/SPIE/SIE` 和特权级。
  - 已接入 interrupt delegation 判断；完整 S-level interrupt pending/priority 后续可继续细化。
- 验证：
  - 已用 Lab5 extra S-mode bonus 覆盖 S-mode trap 闭环。
  - Lab4/Lab5/Lab6 回归通过关键成功线。
  - 为完整 xv6 运行做准备。
- 产出：
  - 特权架构扩展说明：`Doc/Lab+/labplus_smode_trap_report.md`。

### 11. 尝试完整 xv6 主 Track（已完成启动尝试、缺口定位与 RAM disk 加载链路微测）

- 成本：很高
- 优先级：低
- 依赖：任务 6、任务 9、任务 10；若不做 A 扩展，则需要修改 xv6 spinlock
- 目标：让 difftest 环境下输出 xv6 启动信息并尽量进入用户终端。
- 当前状态：
  - Lab5 已能跑课程裁剪内核。
  - 已确认仓库内没有完整 xv6 源码、完整 `kernel.bin` 或 `fs.img`。
  - 未见 virtio 或磁盘 MMIO 支持。
  - difftest 侧有 sdcard 相关代码，但 RAMHelper 当前没有接成 xv6 可用的块设备 MMIO。
  - 仿真器现已支持 `--fs-image`，可把第二镜像加载到 `0x8700_0000`，作为后续 RAM disk 路线的基础。
- 要做：
  - 已决定本轮采用“仓库现有内容 + RAM disk 优先”的方向，不引入外部完整 xv6。
  - 已定位完整 xv6 的主要阻塞点是缺少完整软件输入和块设备/RAM disk 入口。
  - 已确认 S-mode、page fault、`sret`、32-bit 原子指令护栏仍通过。
  - 已进一步调研 xv6 引入方式：上游 xv6 需要 `kernel.bin` + `fs.img`，标准 `virtio_disk.c` 不适配当前平台；最低风险路线是先做 RAM disk 加载链路。
  - 已实现 RAM disk/第二镜像加载微测：`ramdisk_magic.img` 被加载到 `0x8700_0000`，裸机程序读取 magic 后 good trap。
  - 已新增 S-mode timer delegation 诊断资产，但当前 no-diff 运行未形成 clean good/bad trap，说明 S-level timer interrupt 仍需后续专门处理。
  - 后续若继续推进，需要提供/引入可修改 xv6 源码，再实现 xv6 侧 RAM disk 驱动。
- 验证：
  - 已重跑 Lab5 裁剪 xv6：输出 `xv6 kernel is booting` 和 `Return from init! Test passed`。
  - 已重跑 Lab5 extra、Lab6、Lab+3 护栏。
  - 已记录当前无法进入完整 shell 的原因。
  - 已验证 RAM disk 加载链路：
    - `make sim`
    - `./build/emu --no-diff -i ./ready-to-run/lab+/11/ramdisk_magic_test.bin --fs-image ./ready-to-run/lab+/11/ramdisk_magic.img -C 20000 -I 1000`
    - 输出 `Loaded 4 bytes ... to 0x87000000` 和 `HIT GOOD TRAP at pc = 0x80000028`。
  - 已运行 Lab1 基础回归：输出 `HIT GOOD TRAP at pc = 0x80010004`。
  - 已尝试 `ready-to-run/lab+/11/smode_timer_diag.bin`，当前在 cycle cap 下停于早期 PC，暂作为诊断记录。
- 产出：
  - “尝试了什么、卡在哪里、如何分析”的 Lab+ 报告材料：`Doc/Lab+/labplus_xv6_main_track_report.md`。

### 12. Cache 或更复杂性能优化（已完成最小 I-cache）

- 成本：很高
- 优先级：低
- 依赖：任务 3、任务 4
- 目标：作为性能优化的高级项。
- 当前状态：
  - 当前总线路径已变为 IBus/DBus 到 CBus，再到 MMU，最后经过 I-cache 到 RAM。
  - 已实现 MMU 后物理只读 I-cache。
  - 未实现 D-cache。
- 要做：
  - 已优先实现 I-cache，因为实现面小于 D-cache。
  - 已明确 cache 位于 MMU 之后，使用物理地址。
  - 已处理 `satp` / 特权级变化时的保守 flush。
  - 已保持异常、中断与总线握手路径不变；非 fetch 请求全部 bypass。
  - D-cache 需要处理 store、MMIO bypass、一致性等问题，风险明显更高，本轮不做。
- 验证：
  - 已运行 Lab+2 50M-cycle 性能样本。
  - 已运行 Lab4/Lab5/Lab5-extra/Lab6/Lab+3/Lab+4 回归关键路径。
- 产出：
  - 性能对比报告：`Doc/Lab+/labplus_cache_perf_report.md`。

### 13. Lab+ 上板扩展（不支持）

- 成本：很高
- 优先级：最低
- 依赖：对应功能在仿真中稳定
- 目标：把 Lab+ 功能迁移到 FPGA 板端。
- 当前状态：
  - 仿真路径和板端路径需要分开看。
  - Lab5 报告中已有上板时序与 BRAM 初始化差异的经验。
  - 本轮 Lab+ 迭代明确不支持继续做上板扩展，避免把验证范围扩大到 Vivado/板端外设差异。
- 要做：
  - 不再推进。
- 验证：
  - 不适用。
- 产出：
  - 记录为不支持项。

## 推荐迭代批次

### 第一批：最稳妥

- 任务 0：确认测试输入和失败基线。（已完成）
- 任务 1：整理已有 Bonus 材料。（已完成）
- 任务 2：实现 M 扩展乘除法。（已完成）
- 任务 3：让 microbench 先正确跑起来。（阶段完成）

目标：快速形成 Lab+ 报告基础，并争取拿到乘除法和 microbench 正确性进展。

### 第二批：有明确测试目标

- 任务 4：性能统计。（已完成）
- 任务 5：简单分支预测。（已完成）
- 任务 6：Lab+3 原子指令最小集合。（已完成）
- 任务 8：PMP 权限检查。（已完成）

目标：围绕 `test-labplus-2/3/4` 做可验证功能。

### 第三批：高成本探索

- 任务 7：完整 32-bit AMO。（已完成）
- 任务 9：page fault。（已完成核心路径）
- 任务 10：S-mode trap / delegation / sret。（已完成核心闭环）
- 任务 11：完整 xv6 主 Track。（已完成启动尝试与缺口定位）

目标：为高分 Bonus 或更完整系统能力做准备。

### 第四批：时间充裕再做

- 任务 12：cache 或复杂性能优化。（已完成最小 I-cache）
- 任务 13：Lab+ 上板扩展。（不支持）

目标：只在主线功能稳定后尝试，避免破坏已有 Lab1-Lab6 回归。

## 当前最推荐的下一步

任务 0-12 已完成到当前可验证边界，任务 13 明确不支持。若继续按小步推进 xv6，下一步建议先做 RAM disk 加载链路微型自测：让 `emu` 或拼镜像脚本把一个 magic 文件放到固定物理地址，再用裸机程序读出并 good trap。

理由：完整 xv6 需要 `kernel.bin` + `fs.img`，而当前仓库既没有完整 xv6 软件输入，也没有块设备入口；先验证 RAM disk 加载链路，比直接引入上游 xv6 或实现 virtio-mmio 风险更低。
