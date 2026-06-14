# Lab+ S-mode trap / delegation / sret 实现报告

## 目标

本次任务目标是把已有的 S-mode CSR 从“可读写”推进到“可参与 trap 生态”：

- 支持 `sret` 指令译码和提交。
- 支持 `medeleg/mideleg` 控制 trap 进入 M-mode 或 S-mode。
- S-mode trap 写入 `sepc/scause/stval`，并跳转 `stvec`。
- `sret` 根据 `sstatus.SPP/SPIE/SIE` 恢复特权级和中断使能位。

本轮优先完成可验证闭环；`TSR/TW/TVM`、完整 MXR/SUM 语义和复杂 S/U 中断优先级不作为本次通过条件。

## 实现内容

### CSR 与 delegation mask

- `vsrc/include/csr.sv` 放开 S-mode 相关状态位：
  - `SSTATUS_MASK` 覆盖 `SIE/SPIE/SPP/SUM/MXR/UXL/SD` 等位。
  - `MEDELEG_MASK = 64'h000000000000B3FF`。
  - `MIDELEG_MASK = 64'h0000000000000222`。
- `core_csr.sv` 新增：
  - `trap_to_s` 输入，用于区分 M-mode trap 和 S-mode trap。
  - `sret_wen/sret_priv`，用于 `sret` 返回。
  - S-mode trap 状态更新：
    - `SPIE <- SIE`
    - `SIE <- 0`
    - `SPP <- previous privilege`
    - `sepc/scause/stval <- trap epc/cause/tval`
  - `sret` 状态恢复：
    - `SIE <- SPIE`
    - `SPIE <- 1`
    - `SPP <- U`
    - 返回特权级由旧 `SPP` 决定。

### sret 译码与流水线透传

- `core_decode.sv` 识别 `32'h10200073` 为 `sret`。
- `common.sv` 在 `decode_out_t/id_ex_t/ex_mem_t/mem_wb_t` 中增加 `is_sret`。
- `core.sv` 将 `is_sret` 从 ID 透传到 WB，并将其纳入 system event flush/等待路径。

### Trap 目标选择

`core_trap_ctrl.sv` 在 WB 提交边界统一决定 trap 行为：

- 先得到最终 trap cause：
  - interrupt 使用 interrupt cause。
  - exception 使用流水线异常 cause。
  - ecall 使用当前特权级生成的 ecall cause。
- 若当前特权级不是 M-mode，且对应 cause 在 `medeleg/mideleg` 中置位，则进入 S-mode：
  - redirect 到 `stvec`。
  - CSR 写 `sepc/scause/stval`。
  - 下一特权级为 S。
- 否则保持原 M-mode trap 路径：
  - redirect 到 `mtvec`。
  - CSR 写 `mepc/mcause/mtval`。
  - 下一特权级为 M。
- `mret` 仍从 `mepc` 返回；`sret` 从 `sepc` 返回。

## 验证

### 构建

- `make sim`：通过。

### S-mode 闭环测试

使用已有 `ready-to-run/lab5_yzy/kernel_bonus.bin`：

```text
BVhHhSPCore 0: HIT GOOD TRAP at pc = 0x800002b4
total guest instructions = 167
```

该测试覆盖：

- M-mode 配置 `stvec`。
- M-mode 写 `medeleg=0x100`，将 U-mode ecall 委托给 S-mode。
- `mret` 进入 S-mode。
- S-mode 写 `sepc` 后执行 `sret` 进入 U-mode。
- U-mode `ecall` 进入 S-mode trap handler。
- S-mode handler 检查 `scause=8`，更新 `sepc += 4` 后再次 `sret`。
- 返回 U-mode 后触发 good trap。

### 回归

- Lab4：`HIT GOOD TRAP at pc = 0x8001fff8`。
- Lab5：打印 `Return from init! Test passed`，随后在显式 cycle cap 下停于 `pc = 0x0`，与既有现象一致。
- Lab5 extra：`HIT GOOD TRAP at pc = 0x800002b4`。
- Lab6：打印 `Privileged test finished.` / `Exit with code = 0`，随后在显式 cycle cap 下停于 `pc = 0x0`，与既有现象一致。
- Lab+3：`HIT GOOD TRAP at pc = 0x800000dc`。
- Lab+4：前置 privileged/PMP 阶段仍输出 `Single test passed.`；80M cycle cap 下继续跑到后续 benchmark，并停在 Dhrystone 过程，属于既有长测边界。

## 边界

- 当前实现优先覆盖 S-mode trap/delegation/`sret` 的功能闭环。
- 暂未实现 `TSR/TW/TVM` 的非法化语义。
- 暂未完整实现 `SUM/MXR` 对 MMU 权限判断的影响。
- 现有硬件中断源仍以 machine interrupt cause 为主；`mideleg` 路径已接入，但更完整的 S-level interrupt pending/enable 优先级仍可后续细化。
