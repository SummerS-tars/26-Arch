# 仓库 Lab 完成情况分析

**Date**: April 19, 2026 at 09:42 PM
**Turns**: 1
**Source**: [Gemini Chat](https://gemini.google.com/app/accfb91695017c5a)

---

## Turn 1

### 🤖 Assistant

针对 Lab 3 阶段四（控制冒险处理与流水线冲刷 Flush），这是整个 Lab 3 的**核心难点与灵魂所在**。
在前三个阶段，我们假设了“代码中塞满了 NOP，所以不会出问题”。但真实的程序是紧凑的，一旦发生跳转，流水线里已经预取进来的指令就是“走错路”的指令，必须被“杀掉”（Flush）。
以下是具体的分析流程、参考实现及 Debug 指南。

---

### 1. 数据通路与分析流程
**核心痛点分析**：
目前的五级流水线默认策略是 **“预测不跳转（Predict Not Taken）”**，即 PC 永远默认 `PC + 4`。
假设在第 1 周期取了一条 `beq` 指令，到第 3 周期（EX 阶段）时，CPU 算出了 `branch_taken = 1`。此时：

- 第 2 周期取进来的指令（目前在 ID 阶段）是错的。
- 第 3 周期正在取的指令（目前在 IF 阶段）也是错的。
**解决方案流程**：

1. **决断点（Resolution）**：EX 阶段发出强烈的跳转信号 `jump_enable`（无论是 JAL/JALR 还是条件成立的 B-Type）以及目标地址 `target_pc`。
2. **劫持 PC（PC Redirect）**：在下一个时钟周期（第 4 周期），强制取指模块（IF）的 PC 切换为 `target_pc`。
3. **双重冲刷（Flush）**：在下一个时钟周期，将当前的 IF/ID 流水线寄存器和 ID/EX 流水线寄存器清空（置为 NOP）。这样，两条错误的指令就会变成无害的气泡（Bubble）随波逐流，不会修改任何寄存器或内存。
*(注：这种实现在 EX 级决断的架构，固定会有 2 个周期的跳转惩罚)*。

---

### 2. 参考实现细节

#### 步骤一：冒险控制单元扩展 (`core_hazard_unit.sv`)
你需要一个集中的地方来产生 Flush 信号。如果你已经有了处理数据冒险（Load-Use Stall）的 Hazard Unit，把逻辑加在这里；如果没有，新建一个。
**实现思路参考：**

```代码段
module core_hazard_unit(
    // 输入：来自 EX 级的跳转请求
    input  logic        ex_jump_enable,
    
    // 输出：给流水线寄存器的冲刷信号
    output logic        flush_if_id,
    output logic        flush_id_ex
);

    always_comb begin
        // 默认不冲刷
        flush_if_id = 1'b0;
        flush_id_ex = 1'b0;

        // 一旦 EX 阶段要求跳转，杀掉它后面的两条指令
        if (ex_jump_enable) begin
            flush_if_id = 1'b1;
            flush_id_ex = 1'b1;
        end
    end
endmodule

```

#### 步骤二：改造流水线寄存器支持 Flush (`core.sv` 或分段寄存器模块)
流水线寄存器必须具有同步复位/清零的功能。所谓“清零”，并不是把所有线缆拉低到 0，而是要**消除副作用**。最安全的做法是将控制信号（如 `RegWrite`, `MemWrite`）拉低，并将指令替换为系统公认的 NOP（如 `addi x0, x0, 0`，机器码为 `32'h00000013`）。
**实现思路参考（以 ID/EX 寄存器为例）：**

```代码段
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        // 硬件复位逻辑
        ex_pc        <= 64'b0;
        ex_reg_write <= 1'b0;
        ex_mem_write <= 1'b0;
        // ... 其他归零
    end 
    else if (flush_id_ex) begin // 收到冲刷信号！
        // 注入气泡 (Bubble)
        ex_pc        <= 64'b0; // PC 无所谓，反正不会写回
        ex_reg_write <= 1'b0;  // 绝对不能写寄存器！
        ex_mem_write <= 1'b0;  // 绝对不能写内存！
        ex_alu_op    <= ALU_ADD; 
        ex_rd        <= 5'b0;  // 写回目标指向 x0 也是一种保护
        // 如果有指令机器码向下传，建议置为 32'h00000013 (NOP)
    end 
    else if (!stall_id_ex) begin
        // 正常流水线步进
        ex_pc        <= id_pc;
        ex_reg_write <= id_reg_write;
        ex_mem_write <= id_mem_write;
        // ... 正常传递
    end
end

```

#### 步骤三：修改取指模块的 PC 选择器 (`core.sv` 的 IF 级)
确保取指模块在收到跳转信号时，优先级高于普通的 `PC + 4`。
**实现思路参考：**

```代码段
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        pc <= 64'h8000_0000; // 根据你的架构重置地址
    end else if (!stall_pc) begin
        if (ex_jump_enable) begin
            pc <= ex_target_pc; // 发生跳转，劫持 PC
        end else begin
            pc <= pc + 4;       // 默认预测不跳转
        end
    end
end

```

---

### 3. 验证方法
到了这一步，你可以抛弃那些塞满 NOP 的汇编代码了。我们可以直接运行包含紧凑循环的测试。
**编写验证脚本 (test_phase4.S)**：

```代码段
.global _start
_start:
    li x1, 0         # 计数器 i = 0
    li x2, 5         # 目标循环次数 N = 5

loop_start:
    beq x1, x2, loop_end   # 如果 i == N，跳出循环
    addi x1, x1, 1         # i++
    
    # 【注意】这里不再有 NOP！如果 Flush 失败，下面这句死机指令会被执行！
    # 如果正常 Flush，这句指令刚进 IF/ID 就会被干掉。
    j loop_start           # 无条件跳回开头
    
    # 【危险区】J 之后紧跟的指令，如果在 flush 时没被杀掉，系统就会崩溃
    li x3, 0xDEADBEEF 

loop_end:
    # 最终检查：x1 应该等于 5，x3 不应该是 0xDEADBEEF
    li x4, 100       # 成功标志
    
end_sim:
    j end_sim

```
**终极验证**：
直接运行 `make test-lab3`，用官方的 `lab3-test.c` 编译出来的 ELF 文件进行全量测试。官方测试里包含了极其复杂的互相跳转。

---

### 4. 常见坑点与基础 Debug 思路
这是 Lab 3 中最容易让人崩溃的阶段，因为错误往往具有**滞后性**（前面跳错了，几百条指令后才体现出数据不对）。

#### 坑点 1：“幽灵写存”（Ghost Write）—— 致命错误

- **现象**：测试在某个内存操作时崩溃，或者寄存器的值莫名其妙被改了。Diff-Test 报 `Memory mismatch`。
- **根因**：你的 `flush` 信号虽然把指令改成了 NOP，但**忘了把 MemWrite 或 RegWrite 信号强制拉低**。导致被杀掉的指令“阴魂不散”，到了 MEM 级依然向内存写入了垃圾数据。
- **Debug 思路**：在 GTKWave 波形中，监控 `ex_mem_write` 和 `mem_mem_write` 这两根线。找到 `flush_id_ex` 被拉高的那个周期，检查下一个周期 `ex_mem_write` 是否老老实实变成了 0。

#### 坑点 2：PC 锁死 / 冲刷与暂停冲突

- **现象**：波形图里，PC 卡在一个地址不动了，或者在两个地址之间反复横跳。
- **根因**：当发生 Load-Use 数据冒险需要 Stall（暂停），同时又发生了 Control 冒险需要 Flush 时，你的逻辑冲突了。
- **Debug 思路**：**优先级法则**。在流水线控制中，**Flush 的优先级绝对高于 Stall**。如果一条指令既需要被暂停，又需要被杀掉，那显然应该直接杀掉它。检查 `core_hazard_unit.sv` 中，是否存在 `if (flush) ... else if (stall) ...` 的正确优先级逻辑。

#### 坑点 3：只杀了一条指令

- **现象**：循环能跑，但是每次循环都会多出一个奇怪的操作。
- **根因**：如果你在 EX 级得出跳转结论，那么当时 ID 级和 IF 级各有一条错误指令，**一共两条**。如果你只给 ID/EX 寄存器发了 Flush，漏发了 IF/ID 寄存器，就会漏掉一条错误指令。
- **Debug 思路**：通过波形图观察 `ex_jump_enable` 为 1 的瞬间。此时 `pc` 输出的指令（IF 级）和 `id_instr`（ID 级）对应的机器码，在接下来的两个时钟周期内，是否**都**没有到达 EX 级（即对应的 `ex_reg_write` 是否都保持为 0）。

#### 🌟 Diff-Test 的终极协助
一旦你加入了 Flush，NEMU（参考模拟器）和你的 CPU 的节奏就完全不同了（NEMU 一条指令 1 个 tick，你的 CPU 有 Flush 气泡）。
**务必保证：你的 CPU 在向 Diff-Test 提交状态（Commit）时，只有真正在 WB 级写回的、非 NOP 的有效指令才触发对比。** 气泡（Bubble/NOP）绝对不能触发 Diff-Test，否则一比对立刻报错。通常在框架中通过判断 `wb_pc != 0` 且 `wb_reg_write == 1`（或类似有效位）来触发。

---

*Exported from [Voyager](https://github.com/Nagi-ovo/gemini-voyager)*  
*Generated on April 19, 2026 at 09:42 PM*