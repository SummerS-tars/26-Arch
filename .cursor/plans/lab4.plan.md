---
name: Lab4 CSR
overview: 在现有五级流水 CPU 中加入 CSR 译码、寄存器状态、流水线刷新和 Difftest 连接，覆盖 Lab4 必需项与 S-mode CSR bonus；通过 `make test-lab4` 后整理学生视角报告，并为 Vivado 上板输出保留报告位置。
todos:
  - id: extend-decode
    content: 扩展 common/decode，支持 6 条 CSR 指令的控制信号和 WB_CSR 写回来源
    status: completed
  - id: implement-csr-file
    content: 新增或集成 CSR 状态逻辑，覆盖必需 CSR、S-mode bonus CSR、mask、mcycle 和 mhartid 语义
    status: completed
  - id: wire-pipeline-flush
    content: 把 CSR 读写数据通路接入 EX/MEM/WB，并复用 pc+4 重定向刷新流水线
    status: completed
  - id: wire-difftest
    content: 连接真实 DifftestCSRState，并把各 Difftest coreid 改为 mhartid[7:0]
    status: completed
  - id: validate-lab4
    content: 运行 lint 与 make test-lab4，按 GOOD TRAP 或首个 mismatch 迭代修复
    status: completed
  - id: write-report
    content: 编写 Lab4 report.md，生成 docs/report.pdf，并为 Vivado 上板输出预留实际材料位置
    status: completed
isProject: false
---

# Lab4 CSR 实施计划

## 范围与依据

本次按原始 Lab4 要求实现 6 条 CSR 指令：`CSRRW`、`CSRRS`、`CSRRC`、`CSRRWI`、`CSRRSI`、`CSRRCI`。必做 CSR 覆盖 `mstatus`、`mtvec`、`mip`、`mie`、`mscratch`、`mcause`、`mtval`、`mepc`、`mcycle`、`mhartid`、`satp`，并额外实现 `[vsrc/include/csr.sv](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/vsrc/include/csr.sv)` 中给出的 S-mode 与相关 bonus CSR，如 `sstatus`、`stvec`、`sscratch`、`sepc`、`scause`、`stval`、`sie`、`sip`、`medeleg`、`mideleg`、`pmpcfg0`、`pmpaddr0`。

当前代码中 `[vsrc/src/core_decode.sv](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/vsrc/src/core_decode.sv)` 尚未译码 `SYSTEM` opcode；`[vsrc/src/core.sv](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/vsrc/src/core.sv)` 的 `DifftestCSRState` 仍接常量 0，已有的 `redirect_fire_ex` 可复用为 CSR 指令的 `pc + 4` 冲刷路径。

## RTL 设计

推荐采用小模块方式实现，新增 `[vsrc/src/core_csr.sv](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/vsrc/src/core_csr.sv)` 管理 CSR 状态、读写、mask 和 Difftest 导出，避免把所有 CSR case 堆进 `core.sv`。

在 `[vsrc/include/common.sv](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/vsrc/include/common.sv)` 中扩展流水线控制类型：新增 `csr_op_t`、`WB_CSR` 写回来源，以及 `decode_out_t` 的 `is_csr`、`csr_op`、`csr_addr`、`csr_uses_imm` 等字段。`core_decode.sv` 负责识别 `opcode=7'b1110011` 且 `funct3` 为 001/010/011/101/110/111 的 CSR 指令，并保留 `rs1` 或 `zimm` 作为 CSR 写源。

CSR 数据通路放在 EX 到 WB 的提交链路中：EX 阶段组合读取旧 CSR 值并作为 `rd` 写回数据；同时用前递后的 `rs1` 或零扩展 `zimm` 计算候选新值。实际 CSR 写入在 WB 阶段随 `commit_valid_wb` 生效，保证和 GPR/Difftest 提交顺序一致。`CSRRS/CSRRC` 在 `rs1=x0` 或 `zimm=0` 时只读不写，`CSRRW/CSRRWI` 正常写入。

CSR 指令不做 CSR-to-CSR forwarding。只要 EX 阶段出现有效 CSR 指令，就复用现有跳转冲刷：产生重定向到 `pc_ex + 4`，清空 IF/ID 与 ID/EX，让后续指令重新从顺序下一条取指。这样与 Lab4 “CSR 改变刷新流水线”的要求一致，也不需要扩大 `[vsrc/src/core_forwarding_unit.sv](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/vsrc/src/core_forwarding_unit.sv)` 的职责。

CSR 写 mask 按 `csr.sv` 中定义执行：`mstatus` 用 `MSTATUS_MASK`，`mtvec` 用 `MTVEC_MASK`，`mip` 用 `MIP_MASK`，`medeleg/mideleg` 用对应 mask；未给 mask 的普通寄存器全位可写。`sstatus` 不单独存储，读出为 `mstatus & SSTATUS_MASK`，写入时只更新 `mstatus` 中对应字段。`mcycle` 每周期自增，CSR 写入时覆盖；`mhartid` 恒为 0 且忽略写入。

## Difftest 与集成

`DifftestCSRState` 改为连接真实 CSR 状态：`mstatus/sstatus/mepc/sepc/mtval/stval/mtvec/stvec/mcause/scause/satp/mip/mie/mscratch/sscratch/mideleg/medeleg`。`DifftestInstrCommit`、`DifftestArchIntRegState`、`DifftestTrapEvent`、`DifftestCSRState` 的 `coreid` 统一接 `mhartid[7:0]`，`priviledgeMode` 保持机器模式 `2'd3`。

如果新增模块在 Verilator include 顺序上需要显式引入，会同步调整 `[vsrc/SimTop.sv](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/vsrc/SimTop.sv)` 和 `[vsrc/VTop.sv](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/vsrc/VTop.sv)` 的 `ifdef VERILATOR` include 列表；若现有 `-y vsrc/src` 自动发现即可不做额外扰动。

## 验证与报告

实现后先跑 `ReadLints` 检查已改 RTL，再运行 `make test-lab4`。由于 Makefile 的测试命令带 `|| true`，判断通过不看退出码，而看输出中的 `Core 0: HIT GOOD TRAP`。若失败，按第一处编译错误或第一处 Difftest mismatch 定位，必要时补跑 `make test-lab4 VOPT="--dump-wave"`。

测试通过后编写 `[Doc/Lab4/report.md](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/Doc/Lab4/report.md)`，结构参考 `[Doc/Lab3/report.md](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/Doc/Lab3/report.md)`：实验目标、总体设计、主要实现、关键问题、测试结果、上板输出、总结和大模型使用说明。报告采用学生视角，语言简洁；上板输出章节先按实际材料留出位置，不伪造截图或串口日志。随后生成 `[docs/report.pdf](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/docs/report.pdf)`，如环境支持再运行 `make handin` 生成提交 zip。