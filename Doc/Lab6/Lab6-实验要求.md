# Lab 6 — 支持中断与异常

> 来源：<https://github.com/26-Arch/26-Arch/wiki/Lab-6>
> 截止日期：**6 月 9 日 23:59**

---

你必须先阅读[特权架构](特权架构)。

实际上在 Lab 5 我们已经讲了一遍特权级切换。请查看 lab 5，实现 mode 寄存器并连接到 difftest。

## 实现下列异常

- 指令地址不对齐
- 数据地址不对齐
- 非法指令
- ecall

**Bonus：** 实现 MMU 的缺页异常

### 发生异常时的操作

- mepc ← pc
- next_pc ← mtvec
- mcause[63] ← 0 表示异常（而不是中断），mcause[62:0] ← 对应的异常类型
- mstatus.mpie ← mstatus.mie
- mstatus.mie ← 0
- mstatus.mpp ← mode
- mode ← 2'b11
- 清除流水线。取消当周期发起的 dreq.valid。已发起的 dreq 保留，等到 data_ok 后再清除流水线。

具体异常类型见 [Table 102](https://riscv.github.io/riscv-isa-manual/snapshot/spec/#norm:mcause_exccode_enc_img)。

异常存在优先级（见 [Table 103](https://riscv.github.io/riscv-isa-manual/snapshot/spec/#norm:exc_priority)）。

## 实现时钟中断、外部中断、软件中断

我们提供的 trint, exint, swint 分别表示三种中断信号。

与异常不同，中断的处理是有条件的。

> An interrupt i will trap to M-mode (causing the privilege mode to change to Mmode) if all of the following are true: (a) either the current privilege mode is M and the MIE bit in the mstatus register is set, or the current privilege mode has less privilege than M-mode; (b) bit i is set in both mip and mie. These conditions for an interrupt trap to occur must be evaluated in a bounded amount of time from when an interrupt becomes, or ceases to be, pending in mip, and must also be evaluated immediately following the execution of an xRET instruction or an explicit write to a CSR on which these interrupt trap conditions expressly depend (including mip, mie, mstatus).

省流：中断处理实际发生的条件是以下二者均满足：

- (1) 中断是否启用：【如果当前是 M Mode，要求 mstatus.mie=1】 或者 【当前不是 M Mode】
- (2) mip[i]=1 且 mie[i]=1

需要进行中断处理 evaluate（即进行上面的检查，来确定要不要跳转到中断向量）的条件可以总结为满足下面之一（只有这三种条件才会产生新的中断）：

- (1) 刚收到一个中断信号
- (2) 刚执行过 mret
- (3) mip, mie, mstatus 刚被 CSR 写入修改过。

**本次 Lab 我们只要求在 (1) 刚收到一个中断信号 时执行中断 evaluate。**

> hint（非 bonus）思考：每次流水线前进，有新的指令要 fetch 时，在 fetch 模块进行 evaluate 是否有合理性？

> hint: 由于理论上中断并不与 CPU 时钟同步。你不应该检测中断信号的 posedge/negedge。

### 中断时的操作

中断时，除了第三步要将 mcause[63] 赋值为 1 外，其他进行的操作与异常处理相同。

- mstatus.mie ← mstatus.mpie
- mstatus.mpie ← 1
- mode ← mstatus.mpp
- mstatus.mpp ← 0
- mstatus.xs ← 0

## Bonus

观察 difftest 代码，你会发现 mtimecmp 在 0x38004000，mtime 在 0x3800bff8。请利用给出的测试程序构建框架，利用这两个寄存器，编写中断处理程序，在时钟中断时打印一些内容，并重设 mtimecmp。你需要在报告中额外包含 c/cpp/汇编 代码，不需要提供文件。

## 测试

运行 `make test-lab6`，出现以下输出。

出现多于 50 次也是正常的。

本次测试暂时没有 Difftest，能看到 `Privileged test finished.` 输出就算正确。

后面循环输出 `m_trap_test [X] ---TEST FAILED---` 是正常的，Ctrl+C 退出即可。

请查看 [测试](实验讲解#测试)。

本次 Lab 我们不要求上板测试。

## 提交

需要提交包含代码、报告的 zip 压缩包。

实验报告应为 **pdf 格式** 或 **md 格式（更好）**。如果你有图片，请确定图片也在 docs 目录下。

虽然如此，但我们仍建议留一个 pdf 版本。

打包方式：在主目录下新建 docs 文件夹，将报告放入其中并命名为 report.pdf / report.md（图片必须也在 docs 下），命令行运行 `make handin`。

将会有一个 zip 文件出现在你的 docs 中，请直接提交且仅提交这个 zip 文件。

- **提交平台：** Elearning
- **截止日期：** 6 月 9 日 23:59

每个实验满分均为 100 分，迟交会被扣除部分分数，代码无法运行则可能被扣除大部分分数。

评分不参考报告的长度、字数、美观程度，但是应尽量让报告清晰易读。

代码、报告抄袭将导致该次实验零分，并可能面临更严重的惩罚，请独立完成实验任务。
