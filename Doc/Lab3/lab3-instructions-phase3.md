# 仓库 Lab 完成情况分析

**Date**: April 19, 2026 at 09:42 PM
**Turns**: 1
**Source**: [Gemini Chat](https://gemini.google.com/app/accfb91695017c5a)

---

## Turn 1

### 🤖 Assistant

针对 Lab 3 阶段三（条件分支 B-Type 指令的全面实现），核心目标是**精准判定分支条件（是否跳转）并计算出正确的分支目标地址**。
本阶段依然暂时不处理流水线冲刷（Flush），我们将重点放在“比较器”和“地址加法器”的逻辑构建上。
以下是具体的分析流程、参考实现及 Debug 指南。

---

### 1. 数据通路与分析流程
B-Type（条件分支）指令包含 6 条（`beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`），它们的数据流向如下：

1. **ID（译码）阶段**：
  - **识别指令**：通过 `opcode == 7'b1100011` 识别为 B-Type。
  - **提取立即数（极易错）**：B-Type 的立即数位序被打乱，需要将其重组并进行符号扩展。
  - **提取操作数**：读取寄存器 `rs1` 和 `rs2`。
  - **传递 PC**：必须将当前分支指令的 PC 值（我们称之为 `ID_PC`）随着流水线寄存器传递给下一级，用于计算目标地址。
2. **EX（执行）阶段**：
  - **条件决断（Branch Resolution）**：根据指令的 `funct3`，对 `rs1` 和 `rs2` 进行有符号/无符号比较。如果条件成立，输出 `branch_taken = 1`。
  - **计算目标地址**：`Branch_Target = Current_PC + sext(imm)`。
  - *架构设计抉择*：为了降低跳转惩罚，有些高级设计会将上述逻辑前移到 ID 阶段。但对于初学者，**强烈建议先在 EX 阶段实现**，复用已有的 ALU 操作数通路。
3. **后续阶段（MEM / WB）**：
  - 分支指令**没有**向寄存器堆或内存写回数据的副作用。因此，在 MEM 和 WB 阶段，它的行为等同于 NOP（`RegWrite = 0`, `MemWrite = 0`）。

---

### 2. 参考实现细节

#### 步骤一：译码阶段与 B-Type 立即数拼接 (`core_decode.sv`)
B-Type 的立即数重组非常反直觉。RISC-V 这样设计是为了在硬件层面上尽可能复用各个指令类型的连线（如 S-Type 和 B-Type 的高位极其相似）。
**实现思路参考：**

```代码段
// 1. 扩充控制信号
logic is_branch;
logic [2:0] branch_type; // 直接传递 funct3 给 EX 级用于判定

// 2. 解码与立即数提取
always_comb begin
    is_branch   = 1'b0;
    branch_type = 3'b000;
    imm         = 64'b0;
    
    case (opcode)
        // ... 之前的指令
        
        7'b1100011: begin // B-Type (Branch)
            is_branch   = 1'b1;
            branch_type = funct3;
            // 拼接 B-Type 立即数: imm[12|10:5|4:1|11]
            // 注意：最低位隐式为0，最高位(第31位)需符号扩展
            imm = {{52{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
        end
    endcase
end

```

#### 步骤二：执行阶段的条件判定与地址计算 (`core_branch.sv` 或直接在 `core_alu.sv` 中)
这里我们需要根据传入的 `branch_type` (`funct3`) 来决定具体的比较逻辑。
**实现思路参考：**

```代码段
// 假设这些信号从 ID 级流水线寄存器传入 EX 级
input logic [63:0] current_pc; // 必须是这条分支指令自己的 PC
input logic [63:0] srca;       // rs1 数据
input logic [63:0] srcb;       // rs2 数据
input logic [63:0] imm;
input logic        is_branch;
input logic [2:0]  branch_type;

output logic [63:0] target_pc;
output logic        branch_taken; // 告诉后续逻辑：条件成立，需要跳转！

always_comb begin
    target_pc    = current_pc + imm; // 默认计算目标地址
    branch_taken = 1'b0;

    if (is_branch) begin
        case (branch_type)
            3'b000: branch_taken = (srca == srcb);                      // BEQ
            3'b001: branch_taken = (srca != srcb);                      // BNE
            3'b100: branch_taken = ($signed(srca) <  $signed(srcb));    // BLT (有符号)
            3'b101: branch_taken = ($signed(srca) >= $signed(srcb));    // BGE (有符号)
            3'b110: branch_taken = (srca <  srcb);                      // BLTU (无符号)
            3'b111: branch_taken = (srca >= srcb);                      // BGEU (无符号)
            default: branch_taken = 1'b0;
        endcase
    end
end

```
*注意：你可以将这部分逻辑与上一阶段的 jal/jalr 逻辑合并，统一输出一个 jump_enable 信号给取指（IF）模块。*

---

### 3. 验证方法（带 NOP 的防碰撞测试）
由于我们依然没有实现冲刷（Flush）机制，如果发生真实的跳转，流水线里已经取出的错误指令会被执行。因此，验证测试中不仅需要插入 NOP，还需要**针对“跳转”和“不跳转”两种情况分别测试**。
**编写验证脚本 (test_phase3.S)**：

```代码段
.global _start
_start:
    li x1, 5
    li x2, -5         # x2 = 0xFFFFFFFFFFFFFFFB

    # 测试 1: 应该发生跳转 (BLT)
    blt x2, x1, jump_target_1  # 有符号比较: -5 < 5，应该跳转
    nop
    nop
    li x3, 999        # 如果跳失败了，x3 会被置为 999 (错误标志)

jump_target_1:
    li x3, 111        # x3 = 111 表示成功跳转到了这里

    # 测试 2: 不应该发生跳转 (BLTU)
    bltu x2, x1, bad_target    # 无符号比较:极大正数 不小于 5，不该跳
    nop
    nop
    li x4, 222        # x4 = 222 表示成功没有跳转，正常顺序执行
    j end_loop        # 跳过错误目标

bad_target:
    li x4, 999        # 如果跳到了这里，说明判定逻辑错了

end_loop:
    j end_loop

```

---

### 4. 常见坑点与基础 Debug 思路

#### 坑点 1：把“下一个 PC”当成了“当前 PC”

- **现象**：程序确实跳转了，但是总是跳到目标地址的后面 4 个字节或 8 个字节处。
- **根因**：计算 `target_pc = current_pc + imm` 时，你可能误用了全局的 `PC` 寄存器（此时由于流水线推进，全局 PC 早已变成了 `PC+8` 或 `PC+12`）。
- **Debug 思路**：在 EX 阶段抓取加法器的两个输入信号。检查 `current_pc` 是否等于正在执行的这条 `beq` 指令本身的地址。**流水线中每一级的 PC 必须由上一级的流水线寄存器严格传递下来。**

#### 坑点 2：B-Type 立即数位序混淆

- **现象**：跳转到了完全不认识的地址（甚至是非法对齐地址）。
- **根因**：在 ID 阶段拼接立即数时，位序出错。B-Type 和 S-Type 虽然很像，但 B-Type 的 `imm[11]` 被放到了指令的第 7 位（最低位）。
- **Debug 思路**：在 ID 阶段抓取 `imm` 波形。手工计算汇编代码中的跳转偏移量（注意是相对于 PC 的偏移量），看波形中的 `imm` 是否与手工计算出的二进制补码一致。

#### 坑点 3：有符号数判定的永恒痛点

- **现象**：`blt`（有符号小于）表现得像 `bltu`（无符号小于），负数和正数比较时结果颠倒。
- **根因**：Verilog 中未加 `$signed()` 修饰。
- **Debug 思路**：通过波形查看比较器的输入。在 Vivado/GTKWave 中，右键将 `srca` 和 `srcb` 的格式更改为 **Decimal (Signed)**。如果波形显示的是正确的负数，但 `branch_taken` 信号为 0，说明比较器没有被综合成有符号比较。检查 `($signed(srca) < $signed(srcb))` 的语法是否正确敲击。

#### 体系结构级 Debug 手段（前瞻）：
在这个阶段，Diff-Test 可能会**频繁报错**。因为 NOP 只能规避你测试代码里的状态污染，无法向 NEMU（基准模拟器）解释你为什么要插入这些 NOP。建议在此阶段主要**依赖波形图肉眼验证**`branch_taken` 和 `target_pc` 的正确性，直到完成阶段四（Flush 机制）后，再全面开启 Diff-Test 进行终极验证。

---

*Exported from [Voyager](https://github.com/Nagi-ovo/gemini-voyager)*  
*Generated on April 19, 2026 at 09:42 PM*