# Lab6 实验报告

姓名：朱文凯  
学号：23307110192  

## 1. 实验目标

本次 Lab6 在 Lab5 已有特权级切换和 CSR 支持基础上，补充机器模式下的异常与中断处理。实现内容包括：

- `ecall`
- 指令地址不对齐异常
- load/store 地址不对齐异常
- 非法指令异常
- 机器软件中断、时钟中断、外部中断
- trap 相关 CSR 更新，包括 `mepc`、`mcause`、`mtval`、`mstatus`

本次没有实现 Bonus 的缺页异常。

## 2. 总体设计

我采用的实现方式是把异常和中断统一收敛到 WB 提交边界处理。前级只负责检测异常并生成 trap 信息，包括 `valid`、`cause` 和 `tval`，这些信息随流水线向后传递。到 WB 阶段后，再统一决定当前指令是普通提交、进入 trap，还是执行 `mret` 返回。

这样做的好处是可以保持精确异常：触发异常的指令之前的指令已经提交，之后的年轻指令会被清除，不会继续写寄存器或访存。

## 3. 异常处理

非法指令在译码阶段识别，并通过 `is_illegal` 传入流水线。对于当前项目需要使用的 `sfence.vma`，我将其作为 no-op 放行，因为现有简单 MMU 模型不需要额外维护 TLB 状态。

指令地址不对齐在 EX 阶段检查。只有跳转或分支实际发生时才检查目标地址，若目标不是 4 字节对齐，则设置：

- `mcause = 0`
- `mtval = 错误跳转目标`
- `mepc = 当前跳转指令 PC`

数据地址不对齐也在 EX 阶段检查。根据访存宽度判断地址是否满足 2/4/8 字节对齐要求。若 load/store 地址不对齐，则产生对应异常，并在 MEM 阶段屏蔽 `dreq.valid`，避免错误访存产生副作用。

## 4. 中断处理

三类中断信号分别映射到：

- `swint -> MSIP`
- `trint -> MTIP`
- `exint -> MEIP`

中断是否响应由 `(mip | hw_mip) & mie` 和 `mstatus.MIE` 共同决定。为了避免影响 Lab4/Lab5 的 Difftest CSR 比对，硬件 pending 只在 core 内部参与中断仲裁，不直接写入 Difftest 可见的 `mip` 输出。

当 WB 阶段提交普通指令且中断条件满足时，当前指令先完成提交，然后进入中断 trap：

- `mepc = pc + 4`
- `mcause[63] = 1`
- `mstatus.MPIE = mstatus.MIE`
- `mstatus.MIE = 0`
- `mstatus.MPP = 当前特权级`
- `priv_mode = M`

中断 cause 的选择优先级为外部中断、时钟中断、软件中断。

## 5. 关键问题

实现过程中遇到的主要问题有：

1. 错位 load/store 被识别为异常后，不能继续让 `mem_access_mem` 为真，否则会因为没有发出 `dreq.valid` 而永远等不到 `dresp.data_ok`。
2. 中断 pending 不能直接污染 CSR `mip` 的 Difftest 可见值，否则 Lab4/Lab5 的 CSR 比对会失败。
3. trap/mret 提交时需要等待前端和访存状态稳定，否则 PC 重定向可能和未完成的取指、访存响应交叉。
4. Lab5 中的 PMP CSR 对参考模型不完全兼容，因此在 Difftest 提交时跳过 PMP CSR 指令；`sfence.vma` 在本实现中作为 no-op。

## 6. 验证结果

运行结果如下：

- `make sim`：构建通过。
- `make test-lab4`：通过，输出 `HIT GOOD TRAP`。
- `timeout 25s make test-lab5`：通过，输出 `Return from init! Test passed`。
- `TEST=sys ./build/emu --no-diff -i ./ready-to-run/lab6/lab6-test.bin -C 8000000 --force-dump-result`：通过，输出包括：
  - `Test ecall_u [OK]`
  - `Test instr_misalign [OK]`
  - `Test load_misalign [OK]`
  - `Test store_misalign [OK]`
  - `Test timer_intr [OK]`
  - `Test software_intr [OK]`
  - `Test m_trap [OK]`
  - `Privileged test finished.`
  - `Exit with code = 0`

Lab6 测试结束后仍可能继续运行到 cycle limit，这是测试框架行为；判断通过主要看 `Privileged test finished.` 和 `Exit with code = 0`。

## 7. 总结

本次实验完成了基本异常和中断处理，并保持 Lab4、Lab5 回归通过。整体上，WB 统一提交 trap 的方式比在前级直接修改 CSR 更稳定，也更容易保证流水线中的异常精确性。
