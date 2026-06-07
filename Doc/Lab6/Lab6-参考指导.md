# Lab 6 参考指导 — 中断与异常

> 📅 生成于 2026-06-07 | 基于实验要求 + RISC-V Privileged Spec
> 截止：**6 月 9 日 23:59**（约 2 天）

---

## 一、任务概览

Lab 6 分两大板块：

| 板块 | 核心内容 | 难度 |
|------|---------|------|
| **异常（Exception）** | 指令/数据地址不对齐、非法指令、ecall | ⭐⭐⭐ 基础，必做 |
| **中断（Interrupt）** | 时钟中断、外部中断、软件中断 | ⭐⭐⭐ 基础，必做 |
| **Bonus** | MMU 缺页异常 + 时钟中断处理程序 | ⭐⭐⭐⭐ 加分 |

## 二、前置依赖

- **Lab 5 的 mode 寄存器 + difftest 连接**必须先完成
- 需要阅读 [特权架构 wiki](特权架构)
- 熟悉 CSR 寄存器：mepc、mtvec、mcause、mstatus、mip、mie

## 三、异常处理 — 核心要点

### 3.1 四种必做异常

| 异常类型 | mcause 编码 | 触发条件 |
|---------|-------------|---------|
| 指令地址不对齐 | 0x00000000 | PC 非 4 字节对齐 |
| 数据地址不对齐 | 0x00000006 | Load/Store 地址不对齐（按类型检查宽度对齐） |
| 非法指令 | 0x00000002 | opcode 无法识别 |
| ecall | 0x0000000B (M-mode) | 执行 ecall 指令 |

### 3.2 异常处理流程（关键！）

```
mepc    ← pc              // 保存当前 PC（异常指令地址）
next_pc ← mtvec           // 跳转到异常向量
mcause  ← {1'b0, exc_code} // bit[63]=0 表示异常
mstatus.mpie ← mstatus.mie // 保存中断使能位
mstatus.mie  ← 0           // 关闭中断
mstatus.mpp  ← mode        // 保存当前特权级
mode    ← M (2'b11)       // 进入 M Mode
清除流水线                   // flush
```

### 3.3 异常优先级

参考 [RISC-V Table 103](https://riscv.github.io/riscv-isa-manual/snapshot/spec/#norm:exc_priority)：

- 同周期可能同时触发多个异常（如：非法指令 + 地址不对齐）
- **按优先级取最高者**，不能随意取一个
- 通常：缺页 > 地址不对齐 > 非法指令 > 断点 > ecall

### 3.4 流水线清除的细节

- 取消当周期发起的 `dreq.valid`
- **已发起的 dreq 保留**，等到 `data_ok` 后再清除
- 这意味着异常处理和流水线 flush 有时序耦合，需要仔细处理

### 3.5 数据地址不对齐的检查

- **LB/LBU/LH/LHU/LW** — 各有不同的对齐要求
  - LB/LBU：任意地址（1 字节，永远对齐）
  - LH/LHU：2 字节对齐
  - LW：4 字节对齐
- 检查点：在 **EX 级或访存级** 检查地址

## 四、中断处理 — 核心要点

### 4.1 三种中断

| 中断 | 信号 | mip 位 |
|------|------|--------|
| 软件中断 | swint | mip[3] (MSIP) |
| 时钟中断 | trint | mip[7] (MTIP) |
| 外部中断 | exint | mip[11] (MEIP) |

### 4.2 中断使能条件（二选一满足即可）

```
条件 1：当前 mode == M && mstatus.mie == 1
条件 2：当前 mode != M（S/U Mode 下无条件可被 M-mode 中断打断）
```

### 4.3 中断实际发生条件（两个 AND）

```
(中断使能) AND (mip[i] == 1 AND mie[i] == 1)
```

### 4.4 中断 evaluate 时机

本 Lab **只要求**：**刚收到一个中断信号时**执行 evaluate。

也就是说不需要在 mret 后或 CSR 写入后重新 evaluate（那是完整实现的要求）。

**Hint：** 在 fetch 模块、流水线前进时有新指令要 fetch 时做 evaluate 是合理的，因为：
- fetch 是每个新指令的起点
- 中断应尽早检测，避免浪费已经进入流水线的工作

### 4.5 中断信号检测

> ⚠️ 不要用 posedge/negedge 检测！中断信号是电平敏感的。

即：检查 `trint == 1`（高电平有效），而不是上升沿触发。

### 4.6 中断处理流程

与异常几乎相同，**关键区别**：

1. `mcause[63] ← 1`（bit[63]=1 表示中断，不是异常）
2. mret 返回时的 mstatus 恢复不同：

```
mstatus.mie ← mstatus.mpie  // 恢复之前的中断使能
mstatus.mpie ← 1             // mpie 置 1
mode ← mstatus.mpp           // 恢复到之前的特权级
mstatus.mpp ← 0              // mpp 清零
mstatus.xs ← 0              // 扩展状态清零
```

## 五、CSR 寄存器速查

| CSR | 地址 | 作用 |
|-----|------|------|
| mstatus | 0x300 | 机器模式状态（MIE, MPIE, MPP 等） |
| mie | 0x304 | 机器中断使能（按位对应 mip） |
| mip | 0x344 | 机器中断待决（硬件设置） |
| mtvec | 0x305 | 异常/中断向量基址 |
| mepc | 0x341 | 异常/中断返回 PC |
| mcause | 0x342 | 异常/中断原因 |

### mstatus 关键字段

```
mstatus.mie  — 全局中断使能（M-mode）
mstatus.mpie — 进入 trap 前保存的 mie 值
mstatus.mpp  — 进入 trap 前的特权级 [1:0]
mstatus.xs   — 扩展状态（中断时清零）
```

### mcause 编码

```
bit [63]   : 0=异常, 1=中断
bits [62:0]: 异常码 / 中断码
  异常码（参考 Table 102）：
    0x00 — 指令地址不对齐
    0x02 — 非法指令
    0x06 — 数据地址不对齐
    0x0B — ecall (M-mode)
    0x0C — ecall (S-mode)
    0x0D — ecall (U-mode)
    0x0F — 缺页指令取指
    0x0D+ — 缺页读写（bonus）
  中断码：
    0x03 — M-mode 软件中断
    0x07 — M-mode 时钟中断
    0x0B — M-mode 外部中断
```

## 六、实现思路建议

### 6.1 总体架构

```
┌─────────┐   异常检测    ┌──────────────┐
│  Fetch   │─────────────→│ Exception    │
│  Stage   │              │ Decoder      │
└─────────┘              │ (优先级仲裁)  │
                         └──────┬───────┘
┌─────────┐   中断检测           │
│  中断    │────────────────────→│ Trap Controller
│  Evaluate│                    │ (统一的 trap 入口)
└─────────┘                    └──────┬───────┘
                                      │
                               ┌──────▼───────┐
                               │ CSR 写入      │
                               │ + 流水线 Flush │
                               │ + PC → mtvec   │
                               └──────────────┘
```

### 6.2 推荐实现顺序

1. **CSR 寄存器读写** — 确保能正确读写 mstatus/mepc/mtvec/mcause/mie/mip
2. **异常检测** — 先做非法指令（最简单），逐步加入地址不对齐、ecall
3. **异常优先级仲裁** — 同周期多异常时的裁决
4. **Trap 通用流程** — mepc/mtvec 赋值 + mstatus 保存 + mode 切换 + flush
5. **中断 evaluate** — 检查 mip & mie & mstatus.mie 条件
6. **中断处理** — 复用 trap 流程，mcause[63]=1
7. **（Bonus）** 缺页异常 + 中断处理程序编写

### 6.3 流水线 Flush 的陷阱

- 异常/中断发生时需要 flush 流水线
- **dreq 已经发起的情况**：不能直接丢弃，需要等 data_ok
- 这意味着 flush 信号可能需要持续到 data_ok 到来
- 或者：标记 "stall until data_ok then flush"

### 6.4 mret 指令实现

```
pc      ← mepc
mstatus.mie ← mstatus.mpie
mstatus.mpie ← 1
mode    ← mstatus.mpp
mstatus.mpp ← 0
mstatus.xs ← 0
```

## 七、常见踩坑点

1. **异常 PC 的保存**：mepc 应保存**触发异常的指令地址**，不是下一条
   - 但对于 ecall，RISC-V spec 要求 mepc = ecall 指令本身的地址
   - 对于地址不对齐，mepc = 对齐出错的指令地址

2. **中断信号是电平敏感**，不是边沿触发 — 不要用 `posedge` 检测

3. **异常优先级**：同周期多个异常必须按 Table 103 取最高优先级，不能随便选

4. **流水线中异常的处理**：如果在 EX/MEM 级检测到异常，已经流水线中有后续指令，需要正确 flush

5. **mstatus.mpie vs mstatus.mie**：
   - 进入 trap：`mpie ← mie; mie ← 0`
   - mret 返回：`mie ← mpie; mpie ← 1`
   - 注意这两个操作的**方向相反**

6. **测试中没有 difftest**：本次 Lab 用功能测试而非 difftest，看到 `Privileged test finished.` 即为通过

## 八、Bonus 提示

### MMU 缺页异常
- 需要在 TLB miss / PTE 无效时触发
- mcause 编码参考 spec 中的 page fault 类

### 中断处理程序
- mtimecmp: `0x38004000`
- mtime: `0x3800bff8`
- 流程：设置 mtimecmp → 等待时钟中断 → 中断处理程序打印内容 → 重设 mtimecmp
- 需要编写汇编/C/Cpp 代码（报告中展示即可）

## 九、知识点关联

```
RISC-V Privileged Architecture
├── M-mode / S-mode / U-mode 特权级
├── CSR 读写（csrrw, csrrs, csrrc）
├── Trap 机制（异常 + 中断统一框架）
│   ├── mepc / mtvec / mcause
│   ├── mstatus 状态保存与恢复
│   └── xRET 指令（mret, sret）
├── 中断控制器（mie / mip）
│   ├── 软件中断（MSIP）
│   ├── 时钟中断（MTIP）
│   └── 外部中断（MEIP）
└── MMU / TLB / 缺页异常（bonus）
```

与 **操作系统** 课程的关联：这就是 OS kernel trap 处理的硬件基础 — syscall (ecall)、timer interrupt、page fault 都是 OS 入口。

---

*Good luck! 🦞*
